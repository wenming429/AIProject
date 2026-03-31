const mysql = require('mysql2/promise');

async function main() {
  const conn = await mysql.createConnection({
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: 'wenming429',
    database: 'go_chat'
  });

  console.log('=== 验证所有表的主键类型 ===\n');

  const tables = ['users', 'organize', 'organize_dept', 'organize_position'];

  for (const t of tables) {
    const [rows] = await conn.query(`DESCRIBE ${t}`);
    const pk = rows.filter(r => r.Key === 'PRI');
    console.log(`=== ${t} ===`);
    pk.forEach(r => console.log(`  PK: ${r.Field} - ${r.Type}`));
    
    // 显示数据量
    const [cnt] = await conn.query(`SELECT COUNT(*) as c FROM ${t}`);
    console.log(`  数据量: ${cnt[0].c}`);
    console.log('');
  }

  // 验证外键引用完整性
  console.log('=== 验证 organize 表外键完整性 ===');
  
  const [users] = await conn.query('SELECT id FROM users');
  const [depts] = await conn.query('SELECT dept_id FROM organize_dept');
  const [positions] = await conn.query('SELECT position_id FROM organize_position');
  const [org] = await conn.query('SELECT * FROM organize');
  
  const userIds = new Set(users.map(u => u.id));
  const deptIds = new Set(depts.map(d => d.dept_id));
  const positionIds = new Set(positions.map(p => p.position_id));

  let valid = true;
  for (const o of org) {
    if (!userIds.has(o.user_id)) {
      console.log(`  错误: organize.user_id=${o.user_id} 在 users 表中不存在`);
      valid = false;
    }
    if (!deptIds.has(o.dept_id)) {
      console.log(`  错误: organize.dept_id=${o.dept_id} 在 organize_dept 表中不存在`);
      valid = false;
    }
    if (!positionIds.has(o.position_id)) {
      console.log(`  错误: organize.position_id=${o.position_id} 在 organize_position 表中不存在`);
      valid = false;
    }
  }
  
  if (valid) {
    console.log('  所有外键引用有效!');
  }

  await conn.end();
}

main().catch(console.error);
