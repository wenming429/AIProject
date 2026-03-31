const mysql = require('mysql2/promise');
async function test() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat',
  });

  // 模拟实际的 fixComments 逻辑
  const [colRows] = await conn.query(
    `SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA
     FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME='admin' ORDER BY ORDINAL_POSITION`
  );

  const avatar = colRows.find(r => r.COLUMN_NAME === 'avatar');
  console.log('avatar row:', JSON.stringify(avatar));

  const nullableClause = avatar.IS_NULLABLE === 'YES' ? '' : 'NOT NULL';
  let defaultClause = '';
  if (avatar.COLUMN_DEFAULT !== null) {
    defaultClause = ` DEFAULT ${avatar.COLUMN_DEFAULT}`;
  }
  const extraClause = avatar.EXTRA ? ` ${avatar.EXTRA}` : '';
  const colDef = `${avatar.COLUMN_TYPE} ${nullableClause}${defaultClause}${extraClause}`.trim().replace(/\s+/g, ' ');

  console.log('colDef:', JSON.stringify(colDef));
  console.log('colDef bytes:', Buffer.from(colDef, 'utf8').toString('hex'));

  const safeComment = '用户头像';
  const sql = `ALTER TABLE admin MODIFY COLUMN avatar ${colDef} COMMENT '${safeComment}'`;
  console.log('\nFinal SQL:', sql);
  console.log('SQL hex:', Buffer.from(sql, 'utf8').toString('hex'));

  try {
    await conn.query(sql);
    console.log('SUCCESS');
  } catch (e) {
    console.log('ERROR:', e.message);
  }

  await conn.end();
}
test().catch(console.error);
