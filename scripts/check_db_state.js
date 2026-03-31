const mysql = require('mysql2/promise');
async function check() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
  });
  const tables = ['users', 'organize_dept', 'organize_position', 'organize'];
  for (const t of tables) {
    const [cols] = await conn.query(
      `SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE, COLUMN_KEY FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME=? ORDER BY ORDINAL_POSITION`,
      [t]
    );
    const pk = cols.filter(c => c.COLUMN_KEY === 'PRI');
    const [rows] = await conn.query(`SELECT * FROM ?? ORDER BY 1 LIMIT 3`, [t]);
    console.log(`\n${t} [PK: ${pk.map(p=>p.COLUMN_NAME).join(',') || 'none'}]:`);
    console.log('  列:', cols.map(c => `${c.COLUMN_NAME}(${c.DATA_TYPE})`).join(', '));
    console.log('  数据:', JSON.stringify(rows));
  }
  await conn.end();
}
check().catch(e => { console.error(e.message); process.exit(1); });
