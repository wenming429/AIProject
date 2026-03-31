const mysql = require('mysql2/promise');
(async () => {
  const db = await mysql.createConnection({ host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat' });

  const tables = ['organize_dept', 'organize_position', 'organize'];
  for (const tbl of tables) {
    const [r] = await db.query(`SHOW CREATE TABLE ${tbl}`);
    const schema = r[0]['Create Table'];
    const hasUUID = schema.includes('varchar(36)') || schema.includes('VARCHAR(36)');
    const hasINT = schema.includes('int') || schema.includes('INT');
    console.log(`${tbl}: UUID=${hasUUID} INT=${hasINT}`);
    const [sample] = await db.query(`SELECT * FROM ${tbl} LIMIT 3`);
    console.log('  Sample:', sample.map(x => JSON.stringify(x).slice(0,100)).join('\n  '));
  }

  // Check organize_backup
  const [rb] = await db.query('SHOW CREATE TABLE organize_backup');
  console.log('organize_backup UUID:', rb[0]['Create Table'].includes('varchar'));
  const [rb2] = await db.query('SELECT id, user_id, dept_id, position_id FROM organize_backup LIMIT 3');
  console.log('organize_backup sample:', rb2.map(x => `${x.id}/${x.user_id}/${x.dept_id}/${x.position_id}`).join(', '));

  await db.end();
})().catch(e => console.error(e.message));
