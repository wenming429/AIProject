const mysql = require('mysql2/promise');
(async () => {
  const db = await mysql.createConnection({ host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat' });
  const [r] = await db.query("SELECT COLUMN_NAME, COLUMN_KEY, EXTRA FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME='users' ORDER BY ORDINAL_POSITION");
  for (const c of r) console.log(`${c.COLUMN_NAME}  key=${c.COLUMN_KEY || '-'}  extra=${c.EXTRA || '-'}`);
  await db.end();
})().catch(e => console.error(e.message));
