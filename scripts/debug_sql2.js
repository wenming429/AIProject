const mysql = require('mysql2/promise');
async function test() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat',
    charset: 'UTF8_GENERAL_CI'
  });

  // 测试不同的写法
  const tests = [
    `ALTER TABLE admin MODIFY COLUMN id int unsigned NOT NULL COMMENT='用户ID'`,
    `ALTER TABLE admin MODIFY COLUMN id int(10) unsigned NOT NULL COMMENT='用户ID'`,
    `ALTER TABLE admin MODIFY COLUMN id int unsigned NOT NULL auto_increment COMMENT='用户ID'`,
    // 使用双引号
    `ALTER TABLE admin MODIFY COLUMN id int unsigned NOT NULL COMMENT="用户ID"`,
  ];

  for (const sql of tests) {
    console.log('Testing:', sql.substring(0, 60));
    try {
      await conn.query(sql);
      console.log('  SUCCESS');
    } catch (e) {
      console.log('  ERROR:', e.message.substring(0, 100));
    }
  }

  // 检查当前 id 列的精确类型
  const [rows] = await conn.query(
    `SHOW FULL COLUMNS FROM admin WHERE Field='id'`
  );
  console.log('\n当前 id 列定义:', JSON.stringify(rows[0], null, 2));

  await conn.end();
}
test().catch(console.error);
