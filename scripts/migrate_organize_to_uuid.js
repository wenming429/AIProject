/**
 * migrate_organize_to_uuid.js
 * 将 organize 表的主键和外键从 INT 迁移到 VARCHAR(36)
 * 
 * 迁移逻辑：
 * 1. users.id 已经是 VARCHAR -> organize.user_id 需要改为 VARCHAR 并建立映射
 * 2. organize_dept.dept_id 已经是 VARCHAR -> organize.dept_id 需要改为 VARCHAR 并建立映射
 * 3. organize_position.position_id 已经是 VARCHAR -> organize.position_id 需要改为 VARCHAR 并建立映射
 * 4. organize.id 需要从 INT 改为 VARCHAR
 */

const mysql = require('mysql2/promise');

// 确定性的 UUID 生成函数 (与之前迁移 users/organize_dept/organize_position 保持一致)
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

  console.log('=== 开始迁移 organize 表 ===\n');

  // Phase 1: 建立 ID 映射表
  console.log('Phase 1: 建立 ID 映射...');

  // 1.1 获取 users 表的 UUID 映射 (id -> UUID)
  const [users] = await conn.query('SELECT id FROM users');
  const userIdMap = new Map();
  users.forEach(u => {
    userIdMap.set(u.id, u.id); // users.id 已经是 UUID
  });
  console.log(`  - users 映射: ${userIdMap.size} 条`);

  // 1.2 获取 organize_dept 的 UUID 映射 (dept_id -> UUID)
  const [depts] = await conn.query('SELECT dept_id FROM organize_dept');
  const deptIdMap = new Map();
  depts.forEach(d => {
    deptIdMap.set(d.dept_id, d.dept_id); // organize_dept.dept_id 已经是 UUID
  });
  console.log(`  - organize_dept 映射: ${deptIdMap.size} 条`);

  // 1.3 获取 organize_position 的 UUID 映射 (position_id -> UUID)
  const [positions] = await conn.query('SELECT position_id FROM organize_position');
  const positionIdMap = new Map();
  positions.forEach(p => {
    positionIdMap.set(p.position_id, p.position_id); // organize_position.position_id 已经是 UUID
  });
  console.log(`  - organize_position 映射: ${positionIdMap.size} 条`);

  // 1.4 获取 organize 表数据
  const [organizeRows] = await conn.query('SELECT * FROM organize ORDER BY id');
  console.log(`  - organize 数据: ${organizeRows.length} 条\n`);

  // Phase 2: 创建 organize 表的 UUID 映射
  console.log('Phase 2: 生成 organize.id 的 UUID 映射...');
  const organizeIdMap = new Map();
  organizeRows.forEach(row => {
    const oldId = row.id;
    const newId = detUUID(oldId, 'organize');
    organizeIdMap.set(oldId, newId);
    console.log(`  organize.id: ${oldId} -> ${newId}`);
  });
  console.log();

  // Phase 3: 备份并重建 organize 表
  console.log('Phase 3: 重建 organize 表 (VARCHAR(36))...');

  // 3.1 备份原始数据到临时表
  await conn.query('DROP TABLE IF EXISTS _organize_backup');
  await conn.query('CREATE TABLE _organize_backup AS SELECT * FROM organize');
  console.log('  - 已备份到 _organize_backup');

  // 3.2 删除 organize 表
  await conn.query('DROP TABLE IF EXISTS organize');
  console.log('  - 已删除旧 organize 表');

  // 3.3 创建新 organize 表 (VARCHAR)
  await conn.query(`
    CREATE TABLE organize (
      id VARCHAR(36) NOT NULL PRIMARY KEY COMMENT '组织ID',
      user_id VARCHAR(36) NOT NULL COMMENT '用户ID',
      dept_id VARCHAR(36) NOT NULL COMMENT '部门ID',
      position_id VARCHAR(36) NOT NULL COMMENT '岗位ID',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='组织关系表'
  `);
  console.log('  - 已创建新 organize 表 (VARCHAR)');

  // 3.4 插入转换后的数据
  console.log('\nPhase 4: 插入转换后的数据...');

  for (const row of organizeRows) {
    const newId = organizeIdMap.get(row.id);
    const newUserId = userIdMap.get(row.user_id) || detUUID(row.user_id, 'users');
    const newDeptId = deptIdMap.get(row.dept_id) || detUUID(row.dept_id, 'organize_dept');
    const newPositionId = positionIdMap.get(row.position_id) || detUUID(row.position_id, 'organize_position');

    await conn.query(
      'INSERT INTO organize (id, user_id, dept_id, position_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
      [newId, newUserId, newDeptId, newPositionId, row.created_at, row.updated_at]
    );
    console.log(`  INSERT: id=${newId}`);
  }

  // Phase 5: 验证
  console.log('\nPhase 5: 验证迁移结果...');
  const [newOrganize] = await conn.query('SELECT * FROM organize ORDER BY id');
  console.log(`  organize 表现有 ${newOrganize.length} 条记录`);
  console.log('\n  示例数据:');
  newOrganize.forEach(row => {
    console.log(`    id=${row.id}, user_id=${row.user_id}, dept_id=${row.dept_id}, position_id=${row.position_id}`);
  });

  // 验证外键引用的 ID 存在于目标表
  console.log('\nPhase 6: 验证外键引用...');

  // 验证 users 引用
  for (const row of newOrganize) {
    const [users2] = await conn.query('SELECT id FROM users WHERE id = ?', [row.user_id]);
    if (users2.length === 0) {
      console.log(`  警告: organize.user_id=${row.user_id} 在 users 表中不存在!`);
    }
  }
  console.log('  - users 引用验证完成');

  // 验证 organize_dept 引用
  for (const row of newOrganize) {
    const [depts2] = await conn.query('SELECT dept_id FROM organize_dept WHERE dept_id = ?', [row.dept_id]);
    if (depts2.length === 0) {
      console.log(`  警告: organize.dept_id=${row.dept_id} 在 organize_dept 表中不存在!`);
    }
  }
  console.log('  - organize_dept 引用验证完成');

  // 验证 organize_position 引用
  for (const row of newOrganize) {
    const [pos2] = await conn.query('SELECT position_id FROM organize_position WHERE position_id = ?', [row.position_id]);
    if (pos2.length === 0) {
      console.log(`  警告: organize.position_id=${row.position_id} 在 organize_position 表中不存在!`);
    }
  }
  console.log('  - organize_position 引用验证完成');

  // Phase 7: 清理
  console.log('\nPhase 7: 清理...');
  await conn.query('DROP TABLE IF EXISTS _organize_backup');
  console.log('  - 已删除备份表 _organize_backup');

  await conn.end();

  console.log('\n=== 迁移完成 ===');
  console.log('总结:');
  console.log('  - organize.id: INT -> VARCHAR(36)');
  console.log('  - organize.user_id: INT -> VARCHAR(36)');
  console.log('  - organize.dept_id: INT -> VARCHAR(36)');
  console.log('  - organize.position_id: INT -> VARCHAR(36)');
}

main().catch(err => {
  console.error('迁移失败:', err);
  process.exit(1);
});
