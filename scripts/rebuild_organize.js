/**
 * rebuild_organize.js
 * 完全重建 organize 表数据
 */

const mysql = require('mysql2/promise');

// 确定性的 UUID 生成函数
function detUUID(id, ns) {
  const s = `${ns}:${id}`;
  let h1 = 0xdeadbeef;
  for (let i = 0; i < s.length; i++) {
    h1 = Math.imul(h1 ^ s.charCodeAt(i), 2654435761);
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507);
  h1 ^= Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  const u = Math.imul(h1 ^ (h1 >>> 16), 2246822507) >>> 0;
  const h2 = (Math.imul(h1, 2654435761) ^ (h1 >>> 15)) >>> 0;
  const p1 = (u >>> 0).toString(16).padStart(8, '0');
  const p2 = (h1 & 0xFFFF).toString(16).padStart(4, '0');
  const p3 = ((4 << 12) | (h2 & 0xFFF)).toString(16).padStart(4, '0');
  const p4 = ((0x8000 | (h2 & 0x3FFF))).toString(16).padStart(4, '0');
  const p5 = (u >>> 0).toString(16).slice(-12).padStart(12, '0');
  return `${p1}-${p2}-${p3}-${p4}-${p5}`;
}

async function main() {
  const conn = await mysql.createConnection({
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: 'wenming429',
    database: 'go_chat',
    multipleStatements: true
  });

  console.log('=== 完全重建 organize 表 ===\n');

  // Step 1: 获取映射数据
  console.log('Step 1: 获取映射数据...');

  const [users] = await conn.query('SELECT id, mobile FROM users');
  const mobileToUserId = new Map();
  users.forEach(u => mobileToUserId.set(u.mobile, u.id));
  console.log(`  - users: ${users.length} 条`);

  const [depts] = await conn.query('SELECT dept_id, dept_name FROM organize_dept');
  const deptNameToDeptId = new Map();
  depts.forEach(d => deptNameToDeptId.set(d.dept_name, d.dept_id));
  console.log(`  - organize_dept: ${depts.length} 条`);

  const [positions] = await conn.query('SELECT position_id, post_name FROM organize_position');
  const postNameToPositionId = new Map();
  positions.forEach(p => postNameToPositionId.set(p.post_name, p.position_id));
  console.log(`  - organize_position: ${positions.length} 条`);

  // Step 2: 原始数据
  const originalData = [
    { phone: '13800000001', deptName: 'Headquarters', postName: 'CTO' },
    { phone: '13800000002', deptName: 'Product Dept', postName: 'Product Manager' },
    { phone: '13800000003', deptName: 'Technology Dept', postName: 'Tech Lead' },
    { phone: '13800000004', deptName: 'Frontend Team', postName: 'Developer' },
    { phone: '13800000005', deptName: 'Backend Team', postName: 'Developer' },
    { phone: '13800000006', deptName: 'UI Design Team', postName: 'Designer' },
    { phone: '13800000007', deptName: 'UX Research Team', postName: 'Designer' },
    { phone: '13800000008', deptName: 'UI Design Team', postName: 'Designer' },
  ];

  // Step 3: 清空并重建
  console.log('\nStep 2: 清空并重建 organize 表...');

  await conn.query('DROP TABLE IF EXISTS _organize_backup2');
  await conn.query('CREATE TABLE _organize_backup2 AS SELECT * FROM organize');
  console.log('  - 已备份');

  await conn.query('DELETE FROM organize');
  console.log('  - 已清空数据');

  let insertCount = 0;
  for (const item of originalData) {
    const userId = mobileToUserId.get(item.phone);
    const deptId = deptNameToDeptId.get(item.deptName);
    const positionId = postNameToPositionId.get(item.postName);

    if (!userId || !deptId || !positionId) {
      console.log(`  警告: ${item.phone} 映射不完整 (user=${!!userId}, dept=${!!deptId}, pos=${!!positionId})`);
      continue;
    }

    const organizeId = detUUID(item.phone, 'organize');

    await conn.query(
      'INSERT INTO organize (id, user_id, dept_id, position_id, created_at, updated_at) VALUES (?, ?, ?, ?, NOW(), NOW())',
      [organizeId, userId, deptId, positionId]
    );
    console.log(`  插入: ${item.phone} -> ${organizeId}`);
    insertCount++;
  }

  // Step 4: 验证 - 分开查询避免字符集问题
  console.log('\nStep 3: 验证结果...');
  
  const [finalData] = await conn.query('SELECT * FROM organize');
  console.log(`\n  organize 表: ${finalData.length} 条`);
  
  // 单独验证每个外键
  let allValid = true;
  for (const row of finalData) {
    const user = users.find(u => u.id === row.user_id);
    const dept = depts.find(d => d.dept_id === row.dept_id);
    const pos = positions.find(p => p.position_id === row.position_id);
    
    if (!user || !dept || !pos) {
      console.log(`  错误: ${row.user_id} 外键无效`);
      allValid = false;
    } else {
      console.log(`    ${user.mobile} -> ${dept.dept_name} - ${pos.post_name}`);
    }
  }
  
  if (allValid) {
    console.log('\n  - 所有外键引用有效!');
  }

  // Step 5: 清理
  await conn.query('DROP TABLE IF EXISTS _organize_backup2');
  console.log('\nStep 4: 清理完成');

  await conn.end();
  console.log(`\n=== 重建完成! 共 ${insertCount} 条记录 ===`);
}

main().catch(err => {
  console.error('重建失败:', err);
  process.exit(1);
});
