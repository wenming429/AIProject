const mysql = require('mysql2/promise');
(async () => {
  const db = await mysql.createConnection({ host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat' });
  const [r] = await db.query("SHOW CREATE TABLE users");
  console.log('CREATE TABLE users:');
  console.log(r[0]['Create Table']);
  await db.end();
})().catch(e => console.error(e.message));
