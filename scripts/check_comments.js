const mysql = require('mysql2/promise');

async function check() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
  });

  // 查看表备注
  const [tables] = await conn.query(
    "SELECT TABLE_NAME, TABLE_COMMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA='go_chat' ORDER BY TABLE_NAME"
  );
  console.log('=== 表备注情况 ===');
  let withComment = 0, noComment = 0;
  for (const t of tables) {
    if (t.TABLE_COMMENT) {
      withComment++;
      console.log(t.TABLE_NAME.padEnd(40), '|', t.TABLE_COMMENT);
    } else {
      noComment++;
    }
  }
  console.log(`\n有备注: ${withComment} 个 | 无备注: ${noComment} 个`);

  // 查看乱码示例（找字段备注非空但包含乱码字符的）
  const [cols] = await conn.query(`
    SELECT TABLE_NAME, COLUMN_NAME, COLUMN_COMMENT
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA='go_chat' AND COLUMN_COMMENT != ''
    LIMIT 20
  `);
  console.log('\n=== 字段备注示例 ===');
  for (const c of cols) {
    console.log(`${c.TABLE_NAME}.${c.COLUMN_NAME}`.padEnd(50), '|', c.COLUMN_COMMENT);
  }

  await conn.end();
}
check().catch(console.error);
