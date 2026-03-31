const mysql = require('mysql2/promise');
async function test() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat',
  });

  const tests = [
    `ALTER TABLE admin MODIFY COLUMN id int unsigned NOT NULL COMMENT='test'`,
    `ALTER TABLE admin MODIFY COLUMN id int unsigned NOT NULL COMMENT='测试'`,
    `ALTER TABLE admin MODIFY COLUMN username varchar(20) NOT NULL COMMENT '用户名'`,
    `ALTER TABLE admin MODIFY COLUMN username varchar(20) NOT NULL COMMENT='用户名'`,
    // ASCII only
    `ALTER TABLE admin MODIFY COLUMN username varchar(20) NOT NULL COMMENT='username field'`,
  ];

  for (const sql of tests) {
    // 打印原始 bytes
    const buf = Buffer.from(sql, 'utf8');
    console.log(`SQL bytes: ${buf.slice(-30).toString('hex')}`);
    console.log(`"${sql}"`);
    try {
      await conn.query(sql);
      console.log('  SUCCESS');
    } catch (e) {
      console.log('  ERROR:', e.message.substring(0, 150));
    }
    // 恢复
    try {
      await conn.query(`ALTER TABLE admin MODIFY COLUMN username varchar(20) COLLATE utf8mb4_general_ci NOT NULL COMMENT '鐢ㄦ埛鏄电О'`);
    } catch(e) {}
    try {
      await conn.query(`ALTER TABLE admin MODIFY COLUMN id int unsigned NOT NULL auto_increment`);
    } catch(e) {}
  }

  await conn.end();
}
test().catch(console.error);
