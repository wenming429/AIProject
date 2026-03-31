const mysql = require('mysql2/promise');
(async () => {
  const db = await mysql.createConnection({ host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat' });
  const [r] = await db.query('SELECT * FROM organize ORDER BY id');
  console.log('organize current:');
  for (const x of r) console.log(JSON.stringify(x));

  // Check usersMap sample
  const [u] = await db.query('SELECT id, mobile FROM users LIMIT 3');
  console.log('\nusers:', u.map(x => `${x.id}/${x.mobile}`).join(', '));

  await db.end();
})().catch(e => console.error(e.message));
