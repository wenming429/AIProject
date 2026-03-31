const mysql = require('mysql2/promise');
async function debug() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
  });
  const [rows] = await conn.query(
    `SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, COLUMN_COMMENT
     FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME='admin' ORDER BY ORDINAL_POSITION`
  );
  for (const r of rows) {
    console.log(`${r.COLUMN_NAME}: type="${r.COLUMN_TYPE}" nullable=${r.IS_NULLABLE} default=${r.COLUMN_DEFAULT} extra=${r.EXTRA} comment="${r.COLUMN_COMMENT}"`);
  }
  await conn.end();
}
debug().catch(console.error);
