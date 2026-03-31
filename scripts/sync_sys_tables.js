/**
 * 同步 SQL Server -> MySQL
 * 表: SysUser, SysDepartment
 */

const sql = require('mssql');
const mysql = require('mysql2/promise');

const mssqlConfig = {
  user: 'sa',
  password: 'df3**@F@!!@l3**@F@!!@ldcc',
  server: '10.90.102.66',
  database: 'CFLDCN_PMS20230905',
  options: { encrypt: false, trustServerCertificate: true },
  pool: { max: 5, min: 0, idleTimeoutMillis: 30000 },
  requestTimeout: 120000,
  connectionTimeout: 30000
};

const mysqlConfig = {
  host: 'localhost',
  port: 3306,
  user: 'root',
  password: 'wenming429',
  database: 'go_chat',
  charset: 'utf8mb4',
  connectTimeout: 30000
};

// 表定义：SQL Server 表名 -> MySQL 建表语句
const TABLE_DEFS = {
  SysUser: {
    createSQL: `CREATE TABLE IF NOT EXISTS \`SysUser\` (
      \`ID\`           varchar(36)   NOT NULL,
      \`UserName\`     varchar(50)   DEFAULT NULL,
      \`UserPwd\`      varchar(50)   DEFAULT NULL,
      \`EmpName\`      varchar(180)  DEFAULT NULL,
      \`Gender\`       tinyint(1)    DEFAULT NULL,
      \`EMail\`        varchar(100)  DEFAULT NULL,
      \`CellPhoneNo\`  varchar(50)   DEFAULT NULL,
      \`DefaultIndex\` varchar(100)  DEFAULT NULL,
      \`IsInitData\`   tinyint(1)    NOT NULL DEFAULT 0,
      \`IsEnable\`     tinyint(1)    NOT NULL DEFAULT 0,
      \`IsDel\`        tinyint(1)    NOT NULL DEFAULT 0,
      \`CreateTime\`   datetime      DEFAULT NULL,
      \`UpdateTime\`   datetime      DEFAULT NULL,
      \`HrUpdateTime\` datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (\`ID\`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
    columns: ['ID','UserName','UserPwd','EmpName','Gender','EMail','CellPhoneNo','DefaultIndex','IsInitData','IsEnable','IsDel','CreateTime','UpdateTime','HrUpdateTime']
  },
  SysDepartment: {
    createSQL: `CREATE TABLE IF NOT EXISTS \`SysDepartment\` (
      \`ID\`           varchar(50)   NOT NULL,
      \`ParentID\`     varchar(50)   DEFAULT NULL,
      \`FullName\`     varchar(300)  NOT NULL,
      \`ShortName\`    varchar(50)   DEFAULT NULL,
      \`Path\`         varchar(500)  DEFAULT NULL,
      \`FullPath\`     varchar(500)  DEFAULT NULL,
      \`CreateUserID\` varchar(36)   DEFAULT NULL,
      \`CreateTime\`   datetime      DEFAULT NULL,
      \`UpdateTime\`   datetime      DEFAULT NULL,
      \`UpdateUserID\` varchar(36)   DEFAULT NULL,
      \`IsVisible\`    tinyint(1)    NOT NULL DEFAULT 1,
      \`is_intree\`    tinyint(1)    DEFAULT NULL,
      \`IsDel\`        tinyint(1)    NOT NULL DEFAULT 0,
      PRIMARY KEY (\`ID\`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
    columns: ['ID','ParentID','FullName','ShortName','Path','FullPath','CreateUserID','CreateTime','UpdateTime','UpdateUserID','IsVisible','is_intree','IsDel']
  }
};

const BATCH_SIZE = 1000;

function formatValue(val) {
  if (val === null || val === undefined) return null;
  if (val instanceof Date) {
    return val.toISOString().slice(0, 19).replace('T', ' ');
  }
  if (typeof val === 'boolean') return val ? 1 : 0;
  return val;
}

async function syncTable(tableName, mssqlConn, mysqlConn) {
  const def = TABLE_DEFS[tableName];
  const cols = def.columns;
  const colList = cols.map(c => `[${c}]`).join(', ');
  const mySQLCols = cols.map(c => `\`${c}\``).join(', ');
  const placeholders = cols.map(() => '?').join(', ');

  console.log(`\n[${tableName}] 开始同步...`);

  // 1. 重建 MySQL 表
  await mysqlConn.query(`DROP TABLE IF EXISTS \`${tableName}\``);
  await mysqlConn.query(def.createSQL);
  console.log(`[${tableName}] 表已重建`);

  // 2. 查询 SQL Server 总行数
  const countRes = await mssqlConn.request().query(`SELECT COUNT(*) as cnt FROM [${tableName}]`);
  const totalRows = countRes.recordset[0].cnt;
  console.log(`[${tableName}] 总行数: ${totalRows}`);

  // 3. 分批读取并写入
  let offset = 0;
  let inserted = 0;
  const startTime = Date.now();

  while (offset < totalRows) {
    const res = await mssqlConn.request().query(
      `SELECT ${colList} FROM [${tableName}] ORDER BY (SELECT NULL) OFFSET ${offset} ROWS FETCH NEXT ${BATCH_SIZE} ROWS ONLY`
    );
    const rows = res.recordset;
    if (rows.length === 0) break;

    const values = rows.map(row => cols.map(c => formatValue(row[c])));
    const insertSQL = `INSERT INTO \`${tableName}\` (${mySQLCols}) VALUES ?`;
    await mysqlConn.query(insertSQL, [values]);

    inserted += rows.length;
    offset += rows.length;

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    const pct = ((inserted / totalRows) * 100).toFixed(1);
    process.stdout.write(`\r[${tableName}] 进度: ${inserted}/${totalRows} (${pct}%) 耗时: ${elapsed}s`);
  }

  const totalElapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log(`\n[${tableName}] 完成！共插入 ${inserted} 行，耗时 ${totalElapsed}s`);
  return inserted;
}

async function main() {
  console.log('=== SysUser + SysDepartment 同步开始 ===');
  console.log(`时间: ${new Date().toLocaleString()}\n`);

  let mssqlPool, mysqlConn;
  const globalStart = Date.now();

  try {
    console.log('连接 SQL Server...');
    mssqlPool = await sql.connect(mssqlConfig);
    console.log('SQL Server 连接成功');

    console.log('连接 MySQL...');
    mysqlConn = await mysql.createConnection(mysqlConfig);
    await mysqlConn.query('SET NAMES utf8mb4');
    await mysqlConn.query('SET FOREIGN_KEY_CHECKS=0');
    console.log('MySQL 连接成功\n');

    const summary = {};

    for (const tableName of ['SysDepartment', 'SysUser']) {
      const count = await syncTable(tableName, mssqlPool, mysqlConn);
      summary[tableName] = count;
    }

    await mysqlConn.query('SET FOREIGN_KEY_CHECKS=1');

    const totalSec = ((Date.now() - globalStart) / 1000).toFixed(1);
    console.log('\n=== 同步汇总 ===');
    for (const [tbl, cnt] of Object.entries(summary)) {
      console.log(`  ${tbl.padEnd(20)} ${cnt} 行`);
    }
    const total = Object.values(summary).reduce((a, b) => a + b, 0);
    console.log(`  ${'合计'.padEnd(20)} ${total} 行`);
    console.log(`  总耗时: ${totalSec}s`);

  } catch (err) {
    console.error('\n错误:', err.message);
    process.exit(1);
  } finally {
    if (mysqlConn) await mysqlConn.end();
    await sql.close();
  }
}

main();
