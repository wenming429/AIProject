const mysql = require('mysql2/promise');
async function verify() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root',
    password: 'wenming429', database: 'go_chat'
  });
  const [rows] = await conn.execute(
    "SELECT TABLE_NAME, TABLE_ROWS FROM information_schema.TABLES WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME LIKE 'UDM%' ORDER BY TABLE_NAME"
  );
  console.log('\n=== MySQL go_chat 中 UDM 表验证 ===');
  console.log('表名'.padEnd(35), '行数(近似)');
  console.log('-'.repeat(50));
  let total = 0;
  for (const r of rows) {
    console.log(r.TABLE_NAME.padEnd(35), r.TABLE_ROWS);
    total += parseInt(r.TABLE_ROWS || 0);
  }
  console.log('-'.repeat(50));
  console.log('共', rows.length, '张表，约', total, '行\n');
  await conn.end();
}
verify().catch(console.error);
