const mysql = require('mysql2/promise');
async function test() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat',
  });

  // 逐个测试每个子句
  const tests = [
    'ALTER TABLE admin MODIFY COLUMN id int unsigned NOT NULL',
    'ALTER TABLE admin MODIFY COLUMN id int unsigned',
    'ALTER TABLE admin MODIFY COLUMN id int NOT NULL',
    'ALTER TABLE admin CHANGE COLUMN id id2 int unsigned NOT NULL',
    'ALTER TABLE admin MODIFY id int unsigned NOT NULL',
  ];

  for (const sql of tests) {
    console.log(`"${sql}"`);
    try {
      await conn.query(sql);
      console.log('  SUCCESS');
    } catch (e) {
      console.log('  ERROR:', e.message.substring(0, 120));
    }
    // 恢复原状
    try {
      await conn.query('ALTER TABLE admin CHANGE COLUMN id2 id int unsigned NOT NULL auto_increment');
    } catch(e) {}
  }

  await conn.end();
}
test().catch(console.error);
