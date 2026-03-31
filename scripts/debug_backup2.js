const mysql = require('mysql2/promise');
(async () => {
  const db = await mysql.createConnection({ host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat' });
  const [r] = await db.query('SHOW CREATE TABLE organize_dept_backup');
  console.log('organize_dept_backup schema:', r[0]['Create Table'].slice(0, 400));
  const [r2] = await db.query('SELECT dept_id, dept_name FROM organize_dept_backup ORDER BY dept_id');
  console.log('organize_dept_backup:');
  for (const x of r2) console.log(`  ${typeof x.dept_id} ${x.dept_id} ${x.dept_name}`);
  // Also check organize_dept
  const [r3] = await db.query('SELECT dept_id, dept_name FROM organize_dept ORDER BY dept_id');
  console.log('\norganize_dept:');
  for (const x of r3) console.log(`  ${typeof x.dept_id} ${x.dept_id} ${x.dept_name}`);
  await db.end();
})().catch(e => console.error(e.message));
