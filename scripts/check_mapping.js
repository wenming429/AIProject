const mysql = require('mysql2/promise');

async function main() {
  const conn = await mysql.createConnection({
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: 'wenming429',
    database: 'go_chat'
  });

  // 查看 users 表完整数据
  console.log('=== users 表 ===');
  const [users] = await conn.query('SELECT id, phone FROM users ORDER BY id');
  console.log('UUID | Phone');
  users.forEach(u => console.log(`${u.id} | ${u.phone}`));

  // 根据原始 SQL，原始 INT ID 和手机号对应关系：
  // 4531 -> 13800000001 (XiaoMing)
  // 4540 -> 13800000002 (XiaoHong)
  // 4541 -> 13800000003 (ZhangSan)
  // 4542 -> 13800000004 (LiSi)
  // 4543 -> 13800000005 (WangWu)
  // 4544 -> 13800000006 (ZhaoLiu)
  // 4545 -> 13800000007 (SunQi)
  // 4546 -> 13800000008 (ZhouBa)

  console.log('\n=== 建立的映射关系 ===');
  const phoneToUserId = new Map();
  users.forEach(u => {
    phoneToUserId.set(u.phone, u.id);
    console.log(`phone=${u.phone} -> user_id=${u.id}`);
  });

  await conn.end();
}

main().catch(console.error);
