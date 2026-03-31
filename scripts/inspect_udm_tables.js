/**
 * 探查 SQL Server 中以 UDM 开头的表
 */
const sql = require('mssql');

const config = {
  user: 'sa',
  password: 'df3**@F@!!@l3**@F@!!@ldcc',
  server: '10.90.102.66',
  database: 'CFLDCN_PMS20230905',
  options: {
    encrypt: false,
    trustServerCertificate: true,
    connectTimeout: 30000,
    requestTimeout: 60000,
  },
  port: 1433,
};

async function main() {
  let pool;
  try {
    console.log('正在连接 SQL Server...');
    pool = await sql.connect(config);
    console.log('连接成功!\n');

    // 查询所有 UDM 开头的表
    const tablesResult = await pool.request().query(`
      SELECT 
        t.TABLE_NAME,
        t.TABLE_TYPE,
        p.rows AS ROW_COUNT
      FROM INFORMATION_SCHEMA.TABLES t
      LEFT JOIN sys.partitions p 
        ON p.object_id = OBJECT_ID(t.TABLE_SCHEMA + '.' + t.TABLE_NAME)
        AND p.index_id IN (0, 1)
      WHERE t.TABLE_NAME LIKE 'UDM%'
        AND t.TABLE_SCHEMA = 'dbo'
      ORDER BY t.TABLE_NAME
    `);

    const tables = tablesResult.recordset;
    console.log(`找到 ${tables.length} 张 UDM 开头的表:\n`);
    console.log('表名'.padEnd(50), '类型'.padEnd(10), '行数');
    console.log('-'.repeat(70));
    
    let totalRows = 0;
    for (const t of tables) {
      console.log(t.TABLE_NAME.padEnd(50), t.TABLE_TYPE.padEnd(10), (t.ROW_COUNT || 0).toString());
      totalRows += (t.ROW_COUNT || 0);
    }
    console.log('-'.repeat(70));
    console.log(`共 ${tables.length} 张表，约 ${totalRows} 行数据\n`);

    // 查询每张表的列信息
    console.log('\n=== 表结构详情 ===\n');
    for (const t of tables) {
      const colResult = await pool.request().query(`
        SELECT 
          c.COLUMN_NAME,
          c.DATA_TYPE,
          c.CHARACTER_MAXIMUM_LENGTH,
          c.NUMERIC_PRECISION,
          c.NUMERIC_SCALE,
          c.IS_NULLABLE,
          c.COLUMN_DEFAULT,
          CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN 'YES' ELSE 'NO' END AS IS_PRIMARY_KEY
        FROM INFORMATION_SCHEMA.COLUMNS c
        LEFT JOIN (
          SELECT ku.TABLE_NAME, ku.COLUMN_NAME
          FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
          JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE ku 
            ON tc.CONSTRAINT_NAME = ku.CONSTRAINT_NAME
          WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
        ) pk ON pk.TABLE_NAME = c.TABLE_NAME AND pk.COLUMN_NAME = c.COLUMN_NAME
        WHERE c.TABLE_NAME = '${t.TABLE_NAME}'
        ORDER BY c.ORDINAL_POSITION
      `);
      
      console.log(`\n[${t.TABLE_NAME}] (${t.ROW_COUNT || 0} 行)`);
      console.log('  列名'.padEnd(35), '类型'.padEnd(20), '可空', '主键');
      console.log('  ' + '-'.repeat(65));
      for (const col of colResult.recordset) {
        let typeStr = col.DATA_TYPE;
        if (col.CHARACTER_MAXIMUM_LENGTH) typeStr += `(${col.CHARACTER_MAXIMUM_LENGTH})`;
        else if (col.NUMERIC_PRECISION) typeStr += `(${col.NUMERIC_PRECISION},${col.NUMERIC_SCALE || 0})`;
        console.log(
          `  ${col.COLUMN_NAME.padEnd(33)}`,
          typeStr.padEnd(20),
          col.IS_NULLABLE.padEnd(5),
          col.IS_PRIMARY_KEY
        );
      }
    }

    // 输出表名列表，方便后续使用
    console.log('\n\n=== 表名列表 (JSON) ===');
    console.log(JSON.stringify(tables.map(t => ({ name: t.TABLE_NAME, rows: t.ROW_COUNT || 0 }))));

  } catch (err) {
    console.error('错误:', err.message);
    if (err.code) console.error('错误代码:', err.code);
  } finally {
    if (pool) await pool.close();
  }
}

main();
