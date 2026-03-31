const sql = require('mssql');

const config = {
  user: 'sa',
  password: 'df3**@F@!!@l3**@F@!!@ldcc',
  server: '10.90.102.66',
  database: 'CFLDCN_PMS20230905',
  options: { encrypt: false, trustServerCertificate: true }
};

async function inspect() {
  await sql.connect(config);

  // 模糊搜索包含 user 或 department 的表名（大小写不敏感）
  const tables = await sql.query(`
    SELECT t.TABLE_NAME, COUNT(c.COLUMN_NAME) as COL_COUNT
    FROM INFORMATION_SCHEMA.TABLES t
    JOIN INFORMATION_SCHEMA.COLUMNS c ON t.TABLE_NAME = c.TABLE_NAME
    WHERE t.TABLE_TYPE='BASE TABLE' 
      AND (
        LOWER(t.TABLE_NAME) LIKE '%sysuser%'
        OR LOWER(t.TABLE_NAME) LIKE '%sysdepartment%'
        OR LOWER(t.TABLE_NAME) LIKE '%sys_user%'
        OR LOWER(t.TABLE_NAME) LIKE '%sys_department%'
      )
    GROUP BY t.TABLE_NAME
    ORDER BY t.TABLE_NAME
  `);
  
  console.log('=== 找到的匹配表 ===');
  for (const t of tables.recordset) {
    console.log(`  ${t.TABLE_NAME} (${t.COL_COUNT} 列)`);
  }

  // 如果没找到，列出所有Sys开头的表
  if (tables.recordset.length === 0) {
    console.log('\n未找到精确匹配，列出所有 Sys 开头的表：');
    const allSys = await sql.query(`
      SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
      WHERE TABLE_TYPE='BASE TABLE' AND LOWER(TABLE_NAME) LIKE 'sys%'
      ORDER BY TABLE_NAME
    `);
    for (const t of allSys.recordset) {
      console.log(`  ${t.TABLE_NAME}`);
    }
  }

  // 针对找到的表获取列结构和行数
  for (const t of tables.recordset) {
    console.log(`\n=== ${t.TABLE_NAME} 列结构 ===`);
    const cols = await sql.query(`
      SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE, COLUMN_DEFAULT
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_NAME = '${t.TABLE_NAME}'
      ORDER BY ORDINAL_POSITION
    `);
    for (const c of cols.recordset) {
      const len = c.CHARACTER_MAXIMUM_LENGTH ? `(${c.CHARACTER_MAXIMUM_LENGTH})` : '';
      console.log(`  ${c.COLUMN_NAME.padEnd(30)} ${c.DATA_TYPE}${len} ${c.IS_NULLABLE === 'YES' ? 'NULL' : 'NOT NULL'}`);
    }
    
    const countRes = await sql.query(`SELECT COUNT(*) as cnt FROM [${t.TABLE_NAME}]`);
    console.log(`  --> 行数: ${countRes.recordset[0].cnt}`);
  }

  await sql.close();
}

inspect().catch(e => {
  console.error('错误:', e.message);
  process.exit(1);
});
