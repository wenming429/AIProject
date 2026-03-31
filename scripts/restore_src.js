const mysql = require('mysql2/promise');
(async () => {
  const db = await mysql.createConnection({ host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat' });

  // Check organize_position_backup
  const [r] = await db.query('SHOW CREATE TABLE organize_position_backup');
  console.log('organize_position_backup schema:', r[0]['Create Table'].slice(0, 300));
  const [r2] = await db.query('SELECT position_id, post_name FROM organize_position_backup ORDER BY position_id');
  console.log('organize_position_backup:');
  for (const x of r2) console.log(`  ${typeof x.position_id} ${x.position_id} ${x.post_name}`);

  // Check organize_backup
  const [r3] = await db.query('SHOW CREATE TABLE organize_backup');
  console.log('\norganize_backup schema:', r3[0]['Create Table'].slice(0, 300));
  const [r4] = await db.query('SELECT id, user_id, dept_id, position_id FROM organize_backup ORDER BY id');
  console.log('organize_backup:');
  for (const x of r4) console.log(`  ${typeof x.id} ${x.id} ${typeof x.user_id} ${x.user_id} ${x.dept_id} ${x.position_id}`);

  await db.end();
})().catch(e => console.error(e.message));
