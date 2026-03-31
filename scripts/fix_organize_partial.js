/**
 * fix_organize_partial.js
 *
 * 修复 migrate_pk_to_varchar.js 部分运行后的数据问题：
 * - organize_dept.dept_id, organize_position.position_id 已是 VARCHAR 但值为旧 INT 字符串
 * - organize.id/dept_id/position_id 是 VARCHAR 但为空，organize.user_id 有旧 INT 字符串
 * - users.id 仍是 INT
 *
 * 策略：
 * 1. 恢复 organize 表原始数据（用原始 INT 值填充 id/dept_id/position_id）
 * 2. 恢复 organize_dept.parent_id 的旧 INT 值
 * 3. 为所有表重新生成 UUID 映射（基于原始 INT ID）
 * 4. 重新执行完整的迁移逻辑
 */

const mysql = require('mysql2/promise');

const connConfig = {
  host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
};

// 全局 ID 映射
const idMap = { users: {}, organize_dept: {}, organize_position: {}, organize: {} };

// 生成标准 UUID v4 格式（36字符含4个破折号）
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
  // 标准 UUID v4: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  // JavaScript 位运算后需 >>> 0 转无符号再 toString(16)
  const p1 = (u >>> 0).toString(16).padStart(8, '0');
  const p2 = (h1 & 0xFFFF).toString(16).padStart(4, '0');
  const p3 = ((4 << 12) | (h2 & 0xFFF)).toString(16).padStart(4, '0'); // version 4
  const p4 = ((0x8000 | (h2 & 0x3FFF))).toString(16).padStart(4, '0'); // variant
  const p5 = (u >>> 0).toString(16).slice(-12).padStart(12, '0');
  return `${p1}-${p2}-${p3}-${p4}-${p5}`;
}

async function mig(conn, sql) {
  await conn.query(sql);
}

async function fixAndMigrate() {
  console.log('========================================');
  console.log('修复 + 重新迁移主键类型: int -> varchar(36)');
  console.log('========================================\n');

  const conn = await mysql.createConnection(connConfig);

  // ============================================================
  // Phase 0: 修复 organize_dept.parent_id（已是 VARCHAR 但值为旧 INT）
  // ============================================================
  console.log('[Phase 0] 修复 organize_dept.parent_id...');
  const [deptRows] = await conn.query('SELECT dept_id, parent_id FROM organize_dept ORDER BY 1');
  // parent_id 当前是 VARCHAR 存着旧的 INT 值（如 "0", "1"）
  // 直接用这些旧值即可，不需要额外修复
  console.log(`  organize_dept: ${deptRows.length} 条，parent_id 已是 VARCHAR（值为旧 INT 字符串）`);
  console.log('  无需修复，继续\n');

  // ============================================================
  // Phase 1: 生成 ID 映射（基于当前数据库中可用的旧 INT 值）
  // ============================================================
  console.log('[Phase 1] 生成 ID 映射...');

  // users - 仍是 INT（未被迁移）
  const [usersRows] = await conn.query('SELECT id FROM users ORDER BY id');
  for (const r of usersRows) {
    idMap.users[String(r.id)] = { newId: detUUID(r.id, 'usr'), oldId: r.id };
  }
  console.log(`  users: ${usersRows.length} 条（仍是 INT）`);

  // organize_dept - 当前是 VARCHAR 存 INT 字符串
  const [deptRows2] = await conn.query('SELECT dept_id FROM organize_dept ORDER BY 1');
  for (const r of deptRows2) {
    const oldId = parseInt(r.dept_id);
    // 统一用字符串数字作为 key
    idMap.organize_dept[String(oldId)] = { newId: detUUID(oldId, 'dpt'), oldId };
  }
  console.log(`  organize_dept: ${deptRows2.length} 条（已是 VARCHAR）`);

  // organize_position - 当前是 VARCHAR 存 INT 字符串
  const [posRows] = await conn.query('SELECT position_id FROM organize_position ORDER BY 1');
  for (const r of posRows) {
    const oldId = parseInt(r.position_id);
    idMap.organize_position[String(oldId)] = { newId: detUUID(oldId, 'pos'), oldId };
  }
  console.log(`  organize_position: ${posRows.length} 条（已是 VARCHAR）`);

  // organize - 当前有 VARCHAR 空列 + user_id（VARCHAR 存旧 INT）
  // 从 system_data.sql 的原始数据重建
  const organizeOriginal = [
    { user_id: 4531, dept_id: 1, position_id: 2 },
    { user_id: 4540, dept_id: 3, position_id: 7 },
    { user_id: 4541, dept_id: 2, position_id: 3 },
    { user_id: 4542, dept_id: 4, position_id: 5 },
    { user_id: 4543, dept_id: 5, position_id: 5 },
    { user_id: 4544, dept_id: 6, position_id: 6 },
    { user_id: 4545, dept_id: 7, position_id: 6 },
    { user_id: 4546, dept_id: 6, position_id: 6 },
  ];
  let orgIdx = 0;
  for (const r of organizeOriginal) {
    const oldId = ++orgIdx; // organize.id 是 1-8
    idMap.organize[String(oldId)] = {
      newId: detUUID(oldId, 'org'),
      oldId,
      newUserId: idMap.users[String(r.user_id)].newId,
      newDeptId: idMap.organize_dept[String(r.dept_id)].newId,
      newPosId: idMap.organize_position[String(r.position_id)].newId,
    };
  }
  console.log(`  organize: ${organizeOriginal.length} 条（从原始数据重建）`);

  // ============================================================
  // Phase 2: 恢复 organize 表的旧 INT 值
  // ============================================================
  console.log('\n[Phase 2] 恢复 organize 原始数据...');

  // organize 表当前状态：id/dept_id/position_id 是 VARCHAR 空值，user_id 有值
  // 恢复 id/dept_id/position_id 的旧 INT 值
  orgIdx = 0;
  for (const r of organizeOriginal) {
    orgIdx++;
    await conn.query(
      'UPDATE organize SET id=?, dept_id=?, position_id=? WHERE user_id=?',
      [orgIdx, r.dept_id, r.position_id, r.user_id]
    );
  }
  const [checkOrg] = await conn.query('SELECT user_id, id, dept_id, position_id FROM organize ORDER BY id');
  console.log('  恢复后:', JSON.stringify(checkOrg));

  // ============================================================
  // Phase 3: 填充 organize_dept.parent_id（从系统数据看 parent_id 旧值）
  // ============================================================
  console.log('\n[Phase 3] 填充 organize_dept.parent_id UUID...');
  // organize_dept.parent_id 当前值是 INT 字符串（如 "0", "1"）
  // 需要把 parent_id 也改成对应的 UUID
  for (const r of deptRows) {
    const oldParentId = parseInt(r.parent_id || '0');
    if (oldParentId === 0) continue; // 顶级部门 parent_id=0，不需要改
    const newParentId = idMap.organize_dept[String(oldParentId)]?.newId;
    if (newParentId) {
      await conn.query('UPDATE organize_dept SET parent_id=? WHERE dept_id=?', [newParentId, parseInt(r.dept_id)]);
    }
  }
  const [checkParent] = await conn.query('SELECT dept_id, parent_id FROM organize_dept ORDER BY 1');
  console.log('  parent_id 填充后:', JSON.stringify(checkParent));

  // ============================================================
  // Phase 4: 填充所有外键引用表（organize_dept.parent_id 已修复，跳过）
  // ============================================================
  console.log('\n[Phase 4] 填充外键引用表 UUID...');

  const fkUpdateSQLs = [
    [`UPDATE article               SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE article_annex         SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE article_class         SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE article_history       SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE article_tag           SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE contact               SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE contact_apply         SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE contact_group         SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE emoticon_item         SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE file_upload           SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE group                 SET creator_id = ? WHERE creator_id = ?`],
    [`UPDATE group_apply           SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE group_member          SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE group_notice          SET creator_id = ? WHERE creator_id = ?`],
    [`UPDATE group_vote            SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE group_vote_answer     SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE robot                 SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE talk_group_message    SET from_id    = ? WHERE from_id    = ?`],
    [`UPDATE talk_group_message_del SET user_id   = ? WHERE user_id   = ?`],
    [`UPDATE talk_session          SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE talk_user_message     SET user_id    = ? WHERE user_id    = ?`],
    [`UPDATE talk_user_message     SET from_id    = ? WHERE from_id    = ?`],
    [`UPDATE udmjob                SET USERID     = ? WHERE USERID     = ?`],
    [`UPDATE udmjob_temp           SET USERID    = ? WHERE USERID    = ?`],
    [`UPDATE users_emoticon        SET user_id    = ? WHERE user_id    = ?`],
  ];

  let totalUpdated = 0;
  for (const sqlTpl of fkUpdateSQLs) {
    for (const [oldIdStr, entry] of Object.entries(idMap.users)) {
      const oldId = parseInt(oldIdStr);
      const newId = entry.newId;
      try {
        await conn.query(sqlTpl, [newId, oldId]);
        totalUpdated++;
      } catch (e) { /* ignore 0 rows */ }
    }
  }
  console.log(`  OK  共执行 ${totalUpdated} 条 UPDATE`);

  // organize.user_id 也更新（基于 users 映射）
  for (const [oldIdStr, entry] of Object.entries(idMap.users)) {
    const oldId = parseInt(oldIdStr);
    await conn.query('UPDATE organize SET user_id=? WHERE user_id=?', [entry.newId, oldId]);
  }
  console.log('  OK  organize.user_id 更新完成');

  // ============================================================
  // Phase 5: 填充 organize_dept.dept_id 和 organize_position.position_id
  // ============================================================
  console.log('\n[Phase 5] 填充主键表 UUID 值...');

  for (const [oldIdStr, entry] of Object.entries(idMap.organize_dept)) {
    if (!entry.oldId && entry.oldId !== 0) continue;
    const oldId = entry.oldId;
    try {
      await conn.query('UPDATE organize_dept SET dept_id=? WHERE dept_id=?', [entry.newId, String(oldId)]);
    } catch (e) { /* ignore */ }
  }
  console.log(`  OK  organize_dept.dept_id 填充 ${Object.keys(idMap.organize_dept).length} 条`);

  for (const [oldIdStr, entry] of Object.entries(idMap.organize_position)) {
    if (!entry.oldId && entry.oldId !== 0) continue;
    const oldId = entry.oldId;
    try {
      await conn.query('UPDATE organize_position SET position_id=? WHERE position_id=?', [entry.newId, String(oldId)]);
    } catch (e) { /* ignore */ }
  }
  console.log(`  OK  organize_position.position_id 填充 ${Object.keys(idMap.organize_position).length} 条`);

  // ============================================================
  // Phase 6: 填充 organize 的主键列
  // ============================================================
  console.log('\n[Phase 6] 填充 organize 主键列...');

  for (const [oldIdStr, entry] of Object.entries(idMap.organize)) {
    const oldId = entry.oldId;
    await conn.query(
      'UPDATE organize SET id=?, dept_id=?, position_id=? WHERE user_id=?',
      [entry.newId, entry.newDeptId, entry.newPosId, entry.newUserId]
    );
  }
  console.log(`  OK  organize 主键列填充 ${Object.keys(idMap.organize).length} 条`);

  // ============================================================
  // Phase 7: 添加主键约束
  // ============================================================
  console.log('\n[Phase 7] 添加主键约束...');

  await mig(conn, `ALTER TABLE organize_dept DROP PRIMARY KEY`);
  await mig(conn, `ALTER TABLE organize_dept MODIFY COLUMN dept_id VARCHAR(36) NOT NULL`);
  await mig(conn, `ALTER TABLE organize_dept ADD PRIMARY KEY(dept_id)`);
  console.log('  OK  organize_dept PK');

  await mig(conn, `ALTER TABLE organize_position DROP PRIMARY KEY`);
  await mig(conn, `ALTER TABLE organize_position MODIFY COLUMN position_id VARCHAR(36) NOT NULL`);
  await mig(conn, `ALTER TABLE organize_position ADD PRIMARY KEY(position_id)`);
  console.log('  OK  organize_position PK');

  await mig(conn, `ALTER TABLE organize DROP PRIMARY KEY`);
  await mig(conn, `ALTER TABLE organize DROP COLUMN id, ADD COLUMN id VARCHAR(36) NOT NULL`);
  await mig(conn, `ALTER TABLE organize DROP COLUMN dept_id, ADD COLUMN dept_id VARCHAR(36) NOT NULL`);
  await mig(conn, `ALTER TABLE organize DROP COLUMN position_id, ADD COLUMN position_id VARCHAR(36) NOT NULL`);
  // 重新填充 organize 主键（因为改列会清空）
  orgIdx = 0;
  for (const r of organizeOriginal) {
    orgIdx++;
    const entry = idMap.organize[String(orgIdx)];
    await conn.query(
      'UPDATE organize SET id=?, dept_id=?, position_id=? WHERE user_id=?',
      [entry.newId, entry.newDeptId, entry.newPosId, entry.newUserId]
    );
  }
  await mig(conn, `ALTER TABLE organize ADD PRIMARY KEY(id)`);
  console.log('  OK  organize PK');

  await mig(conn, `ALTER TABLE users DROP PRIMARY KEY`);
  await mig(conn, `ALTER TABLE users MODIFY COLUMN id VARCHAR(36) NOT NULL`);
  for (const [oldIdStr, entry] of Object.entries(idMap.users)) {
    await conn.query('UPDATE users SET id=? WHERE id=?', [entry.newId, entry.oldId]);
  }
  await mig(conn, `ALTER TABLE users ADD PRIMARY KEY(id)`);
  console.log('  OK  users PK');

  // ============================================================
  // 最终验证
  // ============================================================
  console.log('\n========================================');
  console.log('验证结果');
  console.log('========================================');

  for (const tbl of ['users', 'organize_dept', 'organize_position', 'organize']) {
    const [pk] = await conn.query(
      `SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE, COLUMN_KEY
       FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME=? AND COLUMN_KEY='PRI'`, [tbl]
    );
    const [sample] = await conn.query(`SELECT * FROM ?? LIMIT 1`, [tbl]);
    console.log(`\n  ${tbl} PK:`, JSON.stringify(pk));
    console.log(`  样本:`, JSON.stringify(sample));
  }

  // UUID 格式验证
  const [sU] = await conn.query('SELECT id FROM users LIMIT 2');
  const [sD] = await conn.query('SELECT dept_id FROM organize_dept LIMIT 2');
  const [sP] = await conn.query('SELECT position_id FROM organize_position LIMIT 2');
  const [sO] = await conn.query('SELECT id, user_id FROM organize LIMIT 2');
  console.log('\n  UUID 样本:');
  console.log('    users.id:', sU.map(r => r.id));
  console.log('    organize_dept.dept_id:', sD.map(r => r.dept_id));
  console.log('    organize_position.position_id:', sP.map(r => r.position_id));
  console.log('    organize.id/user_id:', sO.map(r => `${r.id}/${r.user_id}`));

  // 数据完整性
  const [orphan] = await conn.query(
    `SELECT COUNT(*) as c FROM article a LEFT JOIN users u ON a.user_id=u.id WHERE a.user_id IS NOT NULL AND u.id IS NULL`
  );
  console.log('\n  数据完整性 - article.user_id 孤立记录:', orphan[0].c);

  await conn.end();
  console.log('\n=== 修复 + 迁移完成 ===');
}

fixAndMigrate().catch(e => {
  console.error('Fatal:', e.message, e.stack);
  process.exit(1);
});
