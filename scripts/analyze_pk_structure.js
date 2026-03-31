const mysql = require('mysql2/promise');
async function analyze() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
  });

  // 1. 目标表的当前主键类型
  const targets = ['users', 'organize', 'organize_dept', 'organize_position'];
  console.log('=== 目标表的当前主键类型 ===');
  for (const t of targets) {
    const [rows] = await conn.query(
      `SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, COLUMN_KEY, COLUMN_COMMENT
       FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME=? AND COLUMN_KEY='PRI'`,
      [t]
    );
    console.log(t + ':', JSON.stringify(rows, null, 2));
  }

  // 2. 查找所有引用这4张表的外键
  console.log('\n=== 所有外键引用 ===');
  const [fks] = await conn.query(
    `SELECT TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
     FROM information_schema.KEY_COLUMN_USAGE
     WHERE TABLE_SCHEMA='go_chat' AND REFERENCED_TABLE_NAME IN ('users','organize','organize_dept','organize_position')
     ORDER BY REFERENCED_TABLE_NAME, TABLE_NAME`
  );
  console.log(JSON.stringify(fks, null, 2));

  // 3. 统计各表行数
  console.log('\n=== 行数统计 ===');
  for (const t of targets) {
    const [r] = await conn.query('SELECT COUNT(*) as cnt FROM ??', [t]);
    console.log(t + ':', r[0].cnt, '行');
  }

  await conn.end();
}
analyze().catch(console.error);
