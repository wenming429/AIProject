const mysql = require('mysql2/promise');

async function main() {
  const conn = await mysql.createConnection({
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: 'wenming429',
    database: 'go_chat'
  });

  // 查看 users 表的原始 ID 和 UUID
  console.log('=== users 表 (id + 手机号) ===');
  const [users] = await conn.query('SELECT id, phone FROM users ORDER BY id');
  users.forEach(u => console.log(`原始INT: ?, UUID: ${u.id}, 手机: ${u.phone}`));
  
  // 哦等等，我们不知道原始 INT ID
  // 需要找到一种方式关联 organize 和 users

  // 查看 organize 表数据 (应该已经被迁移了)
  console.log('\n=== organize 表当前数据 ===');
  const [org] = await conn.query('SELECT * FROM organize');
  org.forEach(o => console.log(o));

  // 让我查看一下原始数据
  // 先查看看下 organize 表是否有其他线索
  // 如果没有，可能需要通过某种方式来重建关系

  // 检查原始 SQL 文件看能否找到映射
  console.log('\n=== 分析原始数据 ===');
  console.log('organize.user_id 原始值:');
  org.forEach(o => {
    // 这是已经被转换后的 UUID，但我们需要知道原始的 INT 值
    console.log(`  user_id=${o.user_id} (这是UUID，原始可能是某个INT)`);
  });

  await conn.end();
}

main().catch(console.error);
