const mysql = require('mysql2/promise');
(async () => {
  const db = await mysql.createConnection({ host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat' });
  const [r] = await db.query('SELECT COUNT(*) as total, SUM(ancestors IS NULL) as null_anc FROM organize_dept');
  console.log('organize_dept null ancestors:', r[0]);
  const [r2] = await db.query("SELECT COLUMN_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME='organize_dept' AND COLUMN_NAME='ancestors'");
  console.log('ancestors col type:', r2[0]);
  const [r3] = await db.query('SELECT dept_id, parent_id, ancestors FROM organize_dept ORDER BY dept_id');
  for (const x of r3) console.log(`${x.dept_id} parent=${x.parent_id} ancestors=${JSON.stringify(x.ancestors)} ancestors_len=${String(x.ancestors).length}`);
  await db.end();
})().catch(e => console.error(e.message));
