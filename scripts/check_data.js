const mysql = require('mysql2/promise');

async function main() {
  const conn = await mysql.createConnection({
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: 'wenming429',
    database: 'go_chat'
  });

  // 检查各表数据量
  console.log('=== 各表数据量 ===');
  const tables = ['users', 'organize', 'organize_dept', 'organize_position', 'sys_user', 'sys_department'];
  for (const t of tables) {
    try {
      const [rows] = await conn.query(`SELECT COUNT(*) as cnt FROM ${t}`);
      console.log(`${t}: ${rows[0].cnt} 条`);
    } catch(e) {
      console.log(`${t}: 不存在或查询失败 - ${e.message}`);
    }
  }

  // 查看 organize 表数据
  console.log('\n=== organize 表数据 ===');
  const [orgData] = await conn.query('SELECT * FROM organize LIMIT 10');
  console.log(orgData);

  // 查看 users 表 id 类型
  console.log('\n=== users 表的 id 示例 ===');
  const [usersData] = await conn.query('SELECT id FROM users LIMIT 5');
  console.log(usersData);

  // 查看 organize_dept 表 id 类型
  console.log('\n=== organize_dept 表的 dept_id 示例 ===');
  const [deptData] = await conn.query('SELECT dept_id FROM organize_dept LIMIT 5');
  console.log(deptData);

  await conn.end();
}

main().catch(console.error);
