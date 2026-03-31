const mysql = require('mysql2/promise');
(async () => {
  const db = await mysql.createConnection({ host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat' });

  const [dept] = await db.query('SELECT dept_id, parent_id, dept_name FROM organize_dept ORDER BY dept_id');
  console.log('organize_dept (new):');
  for (const x of dept) console.log(`  ${x.dept_id} parent=${x.parent_id} name=${x.dept_name}`);

  const [pos] = await db.query('SELECT position_id, post_name FROM organize_position ORDER BY position_id');
  console.log('\norganize_position (new):');
  for (const x of pos) console.log(`  ${x.position_id} name=${x.post_name}`);

  // Check users UUID for user 4531
  const [u] = await db.query("SELECT id, mobile FROM users WHERE mobile='13800000001'");
  console.log('\nusers mobile=13800000001:', u[0]);

  await db.end();
})().catch(e => console.error(e.message));
