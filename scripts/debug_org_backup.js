const mysql = require('mysql2/promise');
(async () => {
  const db = await mysql.createConnection({ host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat' });
  const [r] = await db.query('SHOW CREATE TABLE organize_backup');
  console.log('organize_backup schema:', r[0]['Create Table'].slice(0, 300));
  const [r2] = await db.query('SELECT * FROM organize_backup ORDER BY id');
  console.log('organize_backup rows:', r2.length);
  for (const x of r2) console.log(`  ${JSON.stringify({id:x.id,user_id:x.user_id,dept_id:x.dept_id,position_id:x.position_id})}`);
  await db.end();
})().catch(e => console.error(e.message));
