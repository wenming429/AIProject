const mysql = require('mysql2/promise');

async function main() {
  const pool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: process.env.MY_PASSWORD || 'root',
    database: 'go_chat'
  });
  
  console.log('\n========== UDMOrganization 表结构 ==========\n');
  const [cols] = await pool.query('SHOW FULL COLUMNS FROM UDMOrganization');
  cols.forEach(c => console.log(`${c.Field}: ${c.Type}`));
  
  console.log('\n========== 样本数据 (3条) ==========\n');
  const [rows] = await pool.query('SELECT * FROM UDMOrganization LIMIT 3');
  console.log(JSON.stringify(rows, null, 2));
  
  await pool.end();
}

main().catch(e => console.error(e.message));
