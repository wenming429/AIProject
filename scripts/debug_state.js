const mysql = require('mysql2/promise');

(async () => {
  const db = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
  });

  // Check organize_position
  const [posRows] = await db.query('SELECT * FROM organize_position ORDER BY 1');
  console.log('organize_position rows:', posRows.length);
  for (const r of posRows) {
    console.log(JSON.stringify({ position_id: r.position_id, post_name: r.post_name }));
  }

  // Check organize
  const [orgRows] = await db.query('SELECT * FROM organize ORDER BY 1');
  console.log('\norganize rows:', orgRows.length);
  for (const r of orgRows) {
    console.log(JSON.stringify({ id: r.id, user_id: r.user_id, dept_id: r.dept_id, position_id: r.position_id }));
  }

  // Check users
  const [userRows] = await db.query('SELECT id FROM users ORDER BY id LIMIT 5');
  console.log('\nusers sample (first 5):');
  for (const r of userRows) {
    console.log('  id:', r.id, 'len:', r.id.length);
  }

  // Check foreign key tables for data type
  const fkTables = ['article', 'contact', 'group', 'group_member', 'talk_session'];
  for (const tbl of fkTables) {
    const [cols] = await db.query(
      `SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME=? AND COLUMN_NAME IN ('user_id','creator_id','from_id')`,
      [tbl]
    );
    console.log(`\n${tbl}:`, cols.map(c => `${c.COLUMN_NAME} ${c.COLUMN_TYPE}`).join(', '));
  }

  await db.end();
})().catch(e => console.error(e.message));
