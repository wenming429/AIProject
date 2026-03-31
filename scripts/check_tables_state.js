const mysql = require('mysql2/promise');
async function check() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
  });
  const [r] = await conn.query(
    `SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY
     FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME IN ('organize','organize_dept','organize_position','users')
     ORDER BY TABLE_NAME, ORDINAL_POSITION`
  );
  console.log(JSON.stringify(r, null, 2));
  const [data] = await conn.query('SELECT * FROM organize LIMIT 3');
  console.log('\norganize data:', JSON.stringify(data));
  await conn.end();
}
check().catch(e => { console.error(e.message); process.exit(1); });
