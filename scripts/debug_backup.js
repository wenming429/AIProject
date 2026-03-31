const mysql = require('mysql2/promise');
(async () => {
  const db = await mysql.createConnection({ host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat' });
  const [r] = await db.query('SELECT dept_id, ancestors FROM organize_dept_backup ORDER BY dept_id');
  console.log('organize_dept_backup:');
  for (const x of r) console.log(`  ${x.dept_id}: ancestors=${JSON.stringify(x.ancestors)}`);
  const [r2] = await db.query('SELECT COLUMN_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA="go_chat" AND TABLE_NAME="organize_dept_backup" AND COLUMN_NAME="ancestors"');
  console.log('ancestors type:', r2[0]);
  // Check organize_position_backup
  const [r3] = await db.query('SELECT position_id, post_name FROM organize_position_backup ORDER BY position_id');
  console.log('\norganize_position_backup:');
  for (const x of r3) console.log(`  ${x.position_id}: ${x.post_name}`);
  await db.end();
})().catch(e => console.error(e.message));
