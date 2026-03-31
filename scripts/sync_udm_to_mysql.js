/**
 * 同步 SQL Server UDM 表数据到本地 MySQL go_chat
 * 
 * SQL Server: 10.90.102.66 / CFLDCN_PMS20230905
 * MySQL: localhost / go_chat
 * 
 * 功能：
 * 1. 根据 SQL Server 表结构自动在 MySQL 中创建对应表
 * 2. 分批迁移数据（每批 500 条），支持大数据量
 * 3. 自动处理 SQL Server -> MySQL 数据类型转换
 * 4. 支持断点续传（重新运行时会先清空目标表再重新同步）
 */

const sql = require('mssql');
const mysql = require('mysql2/promise');

// ==================== 配置 ====================
const MSSQL_CONFIG = {
  user: 'sa',
  password: 'df3**@F@!!@l3**@F@!!@ldcc',
  server: '10.90.102.66',
  database: 'CFLDCN_PMS20230905',
  options: {
    encrypt: false,
    trustServerCertificate: true,
    connectTimeout: 30000,
    requestTimeout: 120000,
  },
  port: 1433,
};

const MYSQL_CONFIG = {
  host: 'localhost',
  port: 3306,
  user: 'root',
  password: 'wenming429',
  database: 'go_chat',
  charset: 'utf8mb4',
  connectTimeout: 30000,
  multipleStatements: true,
};

const BATCH_SIZE = 500;  // 每批插入条数

// ==================== 数据类型映射 ====================
function mssqlTypeToMysql(dataType, maxLength, precision, scale) {
  const t = dataType.toLowerCase();
  switch (t) {
    case 'nvarchar':
    case 'nchar':
      if (maxLength === -1) return 'LONGTEXT';
      if (maxLength > 16383) return 'MEDIUMTEXT';
      if (maxLength > 4000) return 'TEXT';
      return `VARCHAR(${maxLength})`;
    case 'varchar':
    case 'char':
      if (maxLength === -1) return 'LONGTEXT';
      if (maxLength > 16383) return 'MEDIUMTEXT';
      if (maxLength > 65535) return 'LONGTEXT';
      return `VARCHAR(${Math.min(maxLength, 16383)})`;
    case 'ntext':
    case 'text':
      return 'LONGTEXT';
    case 'int':
      return 'INT';
    case 'bigint':
      return 'BIGINT';
    case 'smallint':
      return 'SMALLINT';
    case 'tinyint':
      return 'TINYINT UNSIGNED';
    case 'bit':
      return 'TINYINT(1)';
    case 'decimal':
    case 'numeric':
      return `DECIMAL(${precision || 18},${scale || 0})`;
    case 'float':
      return 'DOUBLE';
    case 'real':
      return 'FLOAT';
    case 'money':
    case 'smallmoney':
      return 'DECIMAL(19,4)';
    case 'datetime':
    case 'datetime2':
      return 'DATETIME(3)';
    case 'smalldatetime':
      return 'DATETIME';
    case 'date':
      return 'DATE';
    case 'time':
      return 'TIME(3)';
    case 'uniqueidentifier':
      return 'VARCHAR(36)';
    case 'varbinary':
    case 'binary':
    case 'image':
      return 'LONGBLOB';
    case 'xml':
      return 'LONGTEXT';
    default:
      return 'TEXT';
  }
}

// ==================== 获取表列结构 ====================
async function getTableColumns(mssqlPool, tableName) {
  const result = await mssqlPool.request().query(`
    SELECT 
      c.COLUMN_NAME,
      c.DATA_TYPE,
      c.CHARACTER_MAXIMUM_LENGTH,
      c.NUMERIC_PRECISION,
      c.NUMERIC_SCALE,
      c.IS_NULLABLE,
      c.COLUMN_DEFAULT,
      CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN 1 ELSE 0 END AS IS_PRIMARY_KEY,
      c.ORDINAL_POSITION
    FROM INFORMATION_SCHEMA.COLUMNS c
    LEFT JOIN (
      SELECT ku.TABLE_NAME, ku.COLUMN_NAME
      FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
      JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE ku 
        ON tc.CONSTRAINT_NAME = ku.CONSTRAINT_NAME
      WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
    ) pk ON pk.TABLE_NAME = c.TABLE_NAME AND pk.COLUMN_NAME = c.COLUMN_NAME
    WHERE c.TABLE_NAME = '${tableName}'
    ORDER BY c.ORDINAL_POSITION
  `);
  return result.recordset;
}

// ==================== 生成 MySQL 建表 DDL ====================
function buildCreateTableSQL(tableName, columns) {
  const colDefs = columns.map(col => {
    const mysqlType = mssqlTypeToMysql(
      col.DATA_TYPE,
      col.CHARACTER_MAXIMUM_LENGTH,
      col.NUMERIC_PRECISION,
      col.NUMERIC_SCALE
    );
    const nullable = col.IS_NULLABLE === 'YES' ? 'NULL' : 'NOT NULL';
    let def = `  \`${col.COLUMN_NAME}\` ${mysqlType} ${nullable}`;
    return def;
  });

  const primaryKeys = columns
    .filter(col => col.IS_PRIMARY_KEY)
    .map(col => `\`${col.COLUMN_NAME}\``);

  if (primaryKeys.length > 0) {
    colDefs.push(`  PRIMARY KEY (${primaryKeys.join(', ')})`);
  }

  return `CREATE TABLE IF NOT EXISTS \`${tableName}\` (\n${colDefs.join(',\n')}\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;`;
}

// ==================== 值转换 ====================
function convertValue(val) {
  if (val === null || val === undefined) return null;
  if (val instanceof Date) {
    // 转为 MySQL datetime 格式
    const d = val;
    if (isNaN(d.getTime())) return null;
    return d.toISOString().slice(0, 23).replace('T', ' ');
  }
  if (Buffer.isBuffer(val)) return val;
  return val;
}

// ==================== 同步单张表 ====================
async function syncTable(mssqlPool, mysqlConn, tableName) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`开始同步: ${tableName}`);
  console.log(`${'='.repeat(60)}`);

  // 1. 获取列结构
  const columns = await getTableColumns(mssqlPool, tableName);
  console.log(`  列数: ${columns.length}`);

  // 2. 在 MySQL 中创建表
  const createSQL = buildCreateTableSQL(tableName, columns);
  await mysqlConn.execute(`DROP TABLE IF EXISTS \`${tableName}\``);
  await mysqlConn.execute(createSQL);
  console.log(`  MySQL 表已创建/重建`);

  // 3. 统计总行数
  const countResult = await mssqlPool.request().query(
    `SELECT COUNT(*) AS cnt FROM [dbo].[${tableName}]`
  );
  const totalRows = countResult.recordset[0].cnt;
  console.log(`  总行数: ${totalRows}`);

  if (totalRows === 0) {
    console.log(`  无数据，跳过`);
    return { table: tableName, total: 0, synced: 0 };
  }

  // 4. 分批读取并插入
  const colNames = columns.map(c => `[${c.COLUMN_NAME}]`).join(', ');
  const mysqlColNames = columns.map(c => `\`${c.COLUMN_NAME}\``).join(', ');
  const placeholders = columns.map(() => '?').join(', ');
  const insertSQL = `INSERT INTO \`${tableName}\` (${mysqlColNames}) VALUES (${placeholders})`;

  let offset = 0;
  let synced = 0;
  const startTime = Date.now();

  // MySQL 批量插入性能优化
  await mysqlConn.execute('SET FOREIGN_KEY_CHECKS=0');
  await mysqlConn.execute('SET autocommit=0');

  try {
    while (offset < totalRows) {
      const batchSQL = `
        SELECT ${colNames} FROM [dbo].[${tableName}]
        ORDER BY (SELECT NULL)
        OFFSET ${offset} ROWS FETCH NEXT ${BATCH_SIZE} ROWS ONLY
      `;

      const batchResult = await mssqlPool.request().query(batchSQL);
      const rows = batchResult.recordset;

      if (rows.length === 0) break;

      // 批量插入
      for (const row of rows) {
        const values = columns.map(col => convertValue(row[col.COLUMN_NAME]));
        await mysqlConn.execute(insertSQL, values);
      }

      await mysqlConn.execute('COMMIT');

      offset += rows.length;
      synced += rows.length;

      const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
      const progress = ((synced / totalRows) * 100).toFixed(1);
      const rate = (synced / ((Date.now() - startTime) / 1000)).toFixed(0);
      process.stdout.write(`\r  进度: ${synced}/${totalRows} (${progress}%) | 速度: ${rate}行/秒 | 耗时: ${elapsed}s`);
    }
  } finally {
    await mysqlConn.execute('SET autocommit=1');
    await mysqlConn.execute('SET FOREIGN_KEY_CHECKS=1');
  }

  const totalTime = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log(`\n  完成！共同步 ${synced} 行，耗时 ${totalTime}s`);
  return { table: tableName, total: totalRows, synced };
}

// ==================== 主函数 ====================
async function main() {
  const startAll = Date.now();
  console.log('================================================================');
  console.log('  SQL Server -> MySQL 数据同步工具');
  console.log('  源库: 10.90.102.66 / CFLDCN_PMS20230905');
  console.log('  目标: localhost / go_chat');
  console.log('  范围: 所有 UDM 开头的表');
  console.log('================================================================\n');

  let mssqlPool, mysqlConn;

  try {
    // 连接数据库
    console.log('正在连接 SQL Server...');
    mssqlPool = await sql.connect(MSSQL_CONFIG);
    console.log('SQL Server 连接成功 ✓');

    console.log('正在连接本地 MySQL...');
    mysqlConn = await mysql.createConnection(MYSQL_CONFIG);
    console.log('MySQL 连接成功 ✓\n');

    // 获取所有 UDM 表
    const tablesResult = await mssqlPool.request().query(`
      SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
      WHERE TABLE_NAME LIKE 'UDM%' AND TABLE_SCHEMA = 'dbo'
      ORDER BY TABLE_NAME
    `);
    const tableNames = tablesResult.recordset.map(r => r.TABLE_NAME);
    console.log(`共找到 ${tableNames.length} 张 UDM 表:\n${tableNames.map(n => '  - ' + n).join('\n')}\n`);

    // 逐表同步
    const results = [];
    for (const tableName of tableNames) {
      const result = await syncTable(mssqlPool, mysqlConn, tableName);
      results.push(result);
    }

    // 汇总报告
    const totalTime = ((Date.now() - startAll) / 1000).toFixed(1);
    console.log('\n\n================================================================');
    console.log('  同步完成！汇总报告');
    console.log('================================================================');
    console.log(`${'表名'.padEnd(35)} ${'总行数'.padStart(10)} ${'同步行数'.padStart(10)}`);
    console.log('-'.repeat(60));
    let totalSynced = 0;
    for (const r of results) {
      const ok = r.total === r.synced ? '✓' : '!';
      console.log(`${ok} ${r.table.padEnd(33)} ${String(r.total).padStart(10)} ${String(r.synced).padStart(10)}`);
      totalSynced += r.synced;
    }
    console.log('-'.repeat(60));
    console.log(`  总计: ${results.length} 张表，${totalSynced} 行数据，总耗时 ${totalTime}s`);
    console.log('================================================================\n');

  } catch (err) {
    console.error('\n❌ 错误:', err.message);
    if (err.stack) console.error(err.stack);
    process.exit(1);
  } finally {
    if (mysqlConn) await mysqlConn.end();
    if (mssqlPool) await mssqlPool.close();
  }
}

main();
