const mysql = require('mysql2/promise');
async function check() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
  });
  const [r] = await conn.query("SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME='organize_dept' AND COLUMN_NAME IN ('dept_id','parent_id')");
  console.log(JSON.stringify(r, null, 2));
  const [sample] = await conn.query("SELECT dept_id, parent_id FROM organize_dept LIMIT 5");
  console.log(JSON.stringify(sample));
  await conn.end();
}
check().catch(e => { console.error(e.message); process.exit(1); });
