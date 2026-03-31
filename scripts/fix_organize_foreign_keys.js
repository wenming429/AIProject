/**
 * fix_organize_foreign_keys.js
 * 修复 organize 表的外键引用
 */

const mysql = require('mysql2/promise');

async function main() {
  const conn = await mysql.createConnection({
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: 'wenming429',
    database: 'go_chat',
    multipleStatements: true
  });

  console.log('=== 开始修复 organize 表外键 ===\n');

  // Step 1: 获取 users 表的 mobile -> UUID 映射
  console.log('Step 1: 获取 users.mobile -> users.id(UUID) 映射');
  const [users] = await conn.query('SELECT id, mobile FROM users');
  const mobileToUserId = new Map();
  users.forEach(u => {
    mobileToUserId.set(u.mobile, u.id);
  });
  console.log('  映射结果:');
  users.forEach(u => console.log(`    mobile=${u.mobile} -> UUID=${u.id}`));

  // Step 2: 获取 organize_dept 表数据
  console.log('\nStep 2: 获取 organize_dept 数据');
  const [depts] = await conn.query('SELECT dept_id, dept_name FROM organize_dept');
  const deptNameToDeptId = new Map();
  depts.forEach(d => {
    deptNameToDeptId.set(d.dept_name, d.dept_id);
  });
  console.log('  映射结果:');
  depts.forEach(d => console.log(`    dept_name=${d.dept_name} -> UUID=${d.dept_id}`));

  // Step 3: 获取 organize_position 表数据
  console.log('\nStep 3: 获取 organize_position 数据');
  const [positions] = await conn.query('SELECT position_id, post_name FROM organize_position');
  const postNameToPositionId = new Map();
  positions.forEach(p => {
    postNameToPositionId.set(p.post_name, p.position_id);
  });
  console.log('  映射结果:');
  positions.forEach(p => console.log(`    post_name=${p.post_name} -> UUID=${p.position_id}`));

  // Step 4: 定义正确的映射关系
  const correctMappings = [
    { phone: '13800000001', deptName: 'Headquarters', postName: 'CTO' },
    { phone: '13800000002', deptName: 'Product Dept', postName: 'Product Manager' },
    { phone: '13800000003', deptName: 'Technology Dept', postName: 'Tech Lead' },
    { phone: '13800000004', deptName: 'Frontend Team', postName: 'Developer' },
    { phone: '13800000005', deptName: 'Backend Team', postName: 'Developer' },
    { phone: '13800000006', deptName: 'UI Design Team', postName: 'Designer' },
    { phone: '13800000007', deptName: 'UX Research Team', postName: 'Designer' },
    { phone: '13800000008', deptName: 'UI Design Team', postName: 'Designer' },
  ];

  // Step 5: 获取当前 organize 数据
  console.log('\nStep 5: 更新 organize 表');
  const [orgData] = await conn.query('SELECT * FROM organize');
  console.log(`  当前有 ${orgData.length} 条记录`);

  // Step 6: 更新每条记录
  for (const m of correctMappings) {
    const userId = mobileToUserId.get(m.phone);
    const deptId = deptNameToDeptId.get(m.deptName);
    const positionId = postNameToPositionId.get(m.postName);

    if (!userId || !deptId || !positionId) {
      console.log(`  跳过 ${m.phone}: 映射不完整 (userId=${userId}, deptId=${deptId}, positionId=${positionId})`);
      continue;
    }

    // 查找 organize 表中 dept_id 和 position_id 匹配当前映射的记录
    const [matches] = await conn.query(
      'SELECT id FROM organize WHERE dept_id = ? AND position_id = ?',
      [deptId, positionId]
    );

    if (matches.length === 0) {
      console.log(`  警告: 未找到 dept=${deptId}, position=${positionId} 的记录`);
      continue;
    }

    for (const match of matches) {
      await conn.query(
        'UPDATE organize SET user_id = ? WHERE id = ?',
        [userId, match.id]
      );
      console.log(`  更新: organize.id=${match.id} -> user=${userId} (${m.phone}), dept=${deptId} (${m.deptName}), position=${positionId} (${m.postName})`);
    }
  }

  // Step 7: 验证更新结果
  console.log('\nStep 6: 验证更新结果');
  const [updatedOrg] = await conn.query('SELECT * FROM organize ORDER BY id');

  console.log('\n  organize 表最终数据:');
  for (const row of updatedOrg) {
    // 查找对应的用户手机号
    const user = users.find(u => u.id === row.user_id);
    const dept = depts.find(d => d.dept_id === row.dept_id);
    const position = positions.find(p => p.position_id === row.position_id);
    
    console.log(`    用户: ${user ? user.mobile : '未知'} (UUID: ${row.user_id})`);
    console.log(`    部门: ${dept ? dept.dept_name : '未知'} (UUID: ${row.dept_id})`);
    console.log(`    岗位: ${position ? position.post_name : '未知'} (UUID: ${row.position_id})`);
    console.log('');
  }

  await conn.end();
  console.log('=== 修复完成 ===');
}

main().catch(err => {
  console.error('修复失败:', err);
  process.exit(1);
});
