const mysql = require('mysql2/promise');
(async () => {
  const db = await mysql.createConnection({ host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat' });
  // Check what tables exist
  const [tbls] = await db.query("SHOW TABLES");
  console.log('Tables:', tbls.map(t => Object.values(t)[0]).join(', '));
  // Check organize_dept_new
  try {
    const [r] = await db.query('SELECT * FROM organize_dept_new LIMIT 1');
    console.log('\norganize_dept_new:', r.length > 0 ? r[0] : 'empty');
  } catch(e) { console.log('\norganize_dept_new does not exist'); }
  // Check organize_dept
  const [dr] = await db.query('SELECT dept_id, ancestors FROM organize_dept ORDER BY dept_id');
  console.log('\norganize_dept sample:', dr.map(r => `${r.dept_id}/${r.ancestors}`).join(', '));
  await db.end();
})().catch(e => console.error(e.message));
