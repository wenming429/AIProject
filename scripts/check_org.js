const mysql = require('mysql2/promise');

async function main() {
  const conn = await mysql.createConnection({
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: 'wenming429',
    database: 'go_chat'
  });

  console.log('=== organize 表结构 ===');
  const [orgRows] = await conn.query('DESCRIBE organize');
  orgRows.forEach(r => console.log(r.Field, r.Type, r.Key, r.Extra));

  console.log('\n=== 引用 organize.id 的外键 ===');
  const [fks] = await conn.query(`
    SELECT TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
    FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = 'go_chat'
    AND REFERENCED_TABLE_NAME = 'organize'
  `);
  fks.forEach(f => console.log(f.TABLE_NAME, '.', f.COLUMN_NAME, '->', f.REFERENCED_TABLE_NAME, '.', f.REFERENCED_COLUMN_NAME));

  await conn.end();
}

main().catch(console.error);
