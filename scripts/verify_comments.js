const mysql = require('mysql2/promise');
async function verify() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
  });

  const [tables] = await conn.query(
    "SELECT TABLE_NAME, TABLE_COMMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA='go_chat' ORDER BY TABLE_NAME"
  );
  console.log('=== 表备注验证 ===');
  for (const t of tables) {
    if (t.TABLE_COMMENT) console.log(t.TABLE_NAME.padEnd(40), '|', t.TABLE_COMMENT);
  }

  const [colSample] = await conn.query(
    `SELECT TABLE_NAME, COLUMN_NAME, COLUMN_COMMENT FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA='go_chat' AND COLUMN_COMMENT != '' ORDER BY TABLE_NAME, ORDINAL_POSITION LIMIT 20`
  );
  console.log('\n=== 字段备注示例 ===');
  for (const c of colSample) {
    console.log(`${c.TABLE_NAME}.${c.COLUMN_NAME}`.padEnd(45), '|', c.COLUMN_COMMENT);
  }

  const [total] = await conn.query(
    `SELECT COUNT(*) as cnt FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat' AND COLUMN_COMMENT != ''`
  );
  console.log(`\n有字段备注的列: ${total[0].cnt} 个`);

  await conn.end();
}
verify().catch(console.error);
