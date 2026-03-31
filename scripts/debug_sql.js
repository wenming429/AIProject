const mysql = require('mysql2/promise');
async function test() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
  });

  const [rows] = await conn.query(
    `SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA
     FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME='admin' ORDER BY ORDINAL_POSITION`
  );

  for (const r of rows.slice(0, 2)) {
    const nullableClause = r.IS_NULLABLE === 'YES' ? '' : 'NOT NULL';
    let defaultClause = '';
    if (r.COLUMN_DEFAULT !== null) {
      defaultClause = ` DEFAULT ${r.COLUMN_DEFAULT}`;
    }
    const extraClause = r.EXTRA ? ` ${r.EXTRA}` : '';
    const colDef = `${r.COLUMN_TYPE} ${nullableClause}${defaultClause}${extraClause}`.trim().replace(/\s+/g, ' ');
    const safeComment = '用户ID';
    const sql = `ALTER TABLE \`admin\` MODIFY COLUMN \`${r.COLUMN_NAME}\` ${colDef} COMMENT='${safeComment}'`;
    console.log('Generated SQL:');
    console.log(sql);
    console.log('---');
    try {
      await conn.query(sql);
      console.log('SUCCESS');
    } catch (e) {
      console.log('ERROR:', e.message);
    }
  }

  await conn.end();
}
test().catch(console.error);
