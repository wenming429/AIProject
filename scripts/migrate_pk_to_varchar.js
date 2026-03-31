/**
 * migrate_pk_to_varchar.js
 *
 * 将 users, organize, organize_dept, organize_position 的主键从 int 改为 varchar(36)
 * 以及所有关联外键字段也一并修改。
 *
 * 核心原则：所有 ID 映射在修改前就已生成，修改时直接用映射值替换。
 */

const mysql = require('mysql2/promise');

const connConfig = {
  host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
};

// 全局 ID 映射（key 是字符串形式的旧 int 值）
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

async function migrate() {
  console.log('========================================');
  console.log('主键类型迁移: int -> varchar(36)');
  console.log('========================================\n');

  const conn = await mysql.createConnection({ ...connConfig, multipleStatements: false });

  // ============================================================
  // Step 1: 收集所有原始值并生成 UUID 映射
  // ============================================================
  console.log('[Step 1] 生成 ID 映射...');

  const [usersRows] = await conn.query('SELECT id, mobile FROM users ORDER BY id');
  for (const r of usersRows) {
    idMap.users[String(r.id)] = { newId: detUUID(r.id, 'usr'), oldId: r.id, mobile: r.mobile };
  }
  console.log(`  users: ${usersRows.length} 条`);

  const [deptRows] = await conn.query('SELECT dept_id, dept_name FROM organize_dept ORDER BY dept_id');
  for (const r of deptRows) {
    idMap.organize_dept[String(r.dept_id)] = { newId: detUUID(r.dept_id, 'dpt'), oldId: r.dept_id };
  }
  console.log(`  organize_dept: ${deptRows.length} 条`);

  const [posRows] = await conn.query('SELECT position_id, post_name FROM organize_position ORDER BY position_id');
  for (const r of posRows) {
    idMap.organize_position[String(r.position_id)] = { newId: detUUID(r.position_id, 'pos'), oldId: r.position_id };
  }
  console.log(`  organize_position: ${posRows.length} 条`);

  // organize 需要按唯一字段（phone）做行标识
  const [orgRows] = await conn.query(
    'SELECT o.id, o.user_id, o.dept_id, o.position_id ' +
    'FROM organize o ORDER BY o.id'
  );
  for (const r of orgRows) {
    idMap.organize[String(r.id)] = {
      newId: detUUID(r.id, 'org'),
      newUserId: idMap.users[String(r.user_id)].newId,
      newDeptId: idMap.organize_dept[String(r.dept_id)].newId,
      newPosId: idMap.organize_position[String(r.position_id)].newId,
      oldId: r.id
    };
  }
  console.log(`  organize: ${orgRows.length} 条\n`);
  console.log('  样本 UUID:', Object.values(idMap.users)[0]?.newId);

  // ============================================================
  // Step 2: 将所有外键引用字段改为 VARCHAR
  // ============================================================
  console.log('[Step 2] 修改外键引用字段类型...');

  const fkSQLs = [
    [`ALTER TABLE organize          MODIFY COLUMN user_id    VARCHAR(36) NOT NULL COMMENT '用户id'`],
    [`ALTER TABLE article           MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE article_annex     MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '上传文件的用户ID'`],
    [`ALTER TABLE article_class     MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE article_history   MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE article_tag       MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE contact           MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户id'`],
    [`ALTER TABLE contact_apply     MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '申请人ID'`],
    [`ALTER TABLE contact_group     MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE emoticon_item     MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE file_upload       MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '上传的用户ID'`],
    [`ALTER TABLE group             MODIFY COLUMN creator_id VARCHAR(36) NULL COMMENT '群主ID'`],
    [`ALTER TABLE group_apply       MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '申请人ID'`],
    [`ALTER TABLE group_member      MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '群成员ID'`],
    [`ALTER TABLE group_notice      MODIFY COLUMN creator_id VARCHAR(36) NULL COMMENT '公告创建者ID'`],
    [`ALTER TABLE group_vote        MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '投票发起人ID'`],
    [`ALTER TABLE group_vote_answer MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '投票用户ID'`],
    [`ALTER TABLE robot             MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '关联用户ID'`],
    [`ALTER TABLE talk_group_message    MODIFY COLUMN from_id VARCHAR(36) NULL COMMENT '消息发送者ID'`],
    [`ALTER TABLE talk_group_message_del MODIFY COLUMN user_id VARCHAR(36) NULL COMMENT '删除人ID'`],
    [`ALTER TABLE talk_session      MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE talk_user_message MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE talk_user_message MODIFY COLUMN from_id   VARCHAR(36) NULL COMMENT '发送者ID'`],
    [`ALTER TABLE udmjob            MODIFY COLUMN USERID    VARCHAR(36) NULL`],
    [`ALTER TABLE udmjob_temp       MODIFY COLUMN USERID    VARCHAR(36) NULL`],
    [`ALTER TABLE users_emoticon    MODIFY COLUMN user_id   VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE organize_dept    MODIFY COLUMN parent_id  VARCHAR(36) NULL COMMENT '父部门id'`],
  ];

  for (const [sql] of fkSQLs) {
    const tbl = sql.match(/ALTER TABLE `?(\w+)`?/)[1];
    try {
      await mig(conn, sql);
      console.log(`  OK  ${tbl}`);
    } catch (e) {
      console.error(`  ERR ${tbl}: ${e.message}`);
    }
  }

  // ============================================================
  // Step 3: 填充所有外键引用表的 FK 值（基于旧 INT ID -> 新 UUID）
  // organize.user_id 除外（它在 organize 表中，organize 本身将在 Step 6 处理）
  // ============================================================
  console.log('\n[Step 3] 填充外键引用表的 UUID 值...');

  const fkUpdateSQLs = [
    // 注意：不包括 organize.user_id（organize 在 Step 6 处理）
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
      } catch (e) {
        // ignore (may be 0 rows affected)
      }
    }
  }
  console.log(`  OK  共执行 ${totalUpdated} 条 UPDATE`);

  // organize_dept.parent_id（引用本表 dept_id）
  for (const [oldIdStr, entry] of Object.entries(idMap.organize_dept)) {
    const oldId = parseInt(oldIdStr);
    const newId = entry.newId;
    try {
      await conn.query('UPDATE organize_dept SET parent_id=? WHERE parent_id=?', [newId, oldId]);
      totalUpdated++;
    } catch (e) { /* ignore */ }
  }
  console.log(`  OK  organize_dept.parent_id 更新完成`);

  // ============================================================
  // Step 4: 迁移 organize_dept 主键
  // ============================================================
  console.log('\n[Step 4] 迁移 organize_dept 主键...');
  await mig(conn, `ALTER TABLE organize_dept DROP PRIMARY KEY`);
  await mig(conn, `ALTER TABLE organize_dept MODIFY COLUMN dept_id VARCHAR(36) NOT NULL`);
  console.log('  OK  dept_id -> varchar(36)');

  // 填充 dept_id
  for (const [oldIdStr, entry] of Object.entries(idMap.organize_dept)) {
    const oldId = parseInt(oldIdStr);
    await conn.query('UPDATE organize_dept SET dept_id=? WHERE dept_id=?', [entry.newId, oldId]);
  }
  console.log(`  OK  dept_id 填充 ${Object.keys(idMap.organize_dept).length} 条`);

  await mig(conn, `ALTER TABLE organize_dept ADD PRIMARY KEY(dept_id)`);
  console.log('  OK  ADD PRIMARY KEY(dept_id)');

  // ============================================================
  // Step 5: 迁移 organize_position 主键
  // ============================================================
  console.log('\n[Step 5] 迁移 organize_position 主键...');
  await mig(conn, `ALTER TABLE organize_position DROP PRIMARY KEY`);
  await mig(conn, `ALTER TABLE organize_position MODIFY COLUMN position_id VARCHAR(36) NOT NULL`);
  console.log('  OK  position_id -> varchar(36)');

  for (const [oldIdStr, entry] of Object.entries(idMap.organize_position)) {
    const oldId = parseInt(oldIdStr);
    await conn.query('UPDATE organize_position SET position_id=? WHERE position_id=?', [entry.newId, oldId]);
  }
  console.log(`  OK  position_id 填充 ${Object.keys(idMap.organize_position).length} 条`);

  await mig(conn, `ALTER TABLE organize_position ADD PRIMARY KEY(position_id)`);
  console.log('  OK  ADD PRIMARY KEY(position_id)');

  // ============================================================
  // Step 6: 迁移 organize 表（复合主键: id, dept_id, position_id）
  // ============================================================
  console.log('\n[Step 6] 迁移 organize 表...');

  // 6a: 删除复合主键
  await mig(conn, `ALTER TABLE organize DROP PRIMARY KEY`);
  console.log('  - 删除复合主键 (id, dept_id, position_id)');

  // 6b: 删除旧列并添加新 VARCHAR 列（一步完成，避免多次 PK 相关报错）
  await mig(conn,
    `ALTER TABLE organize
     DROP COLUMN id,           ADD COLUMN id          VARCHAR(36) NOT NULL,
     DROP COLUMN dept_id,      ADD COLUMN dept_id     VARCHAR(36) NOT NULL,
     DROP COLUMN position_id,  ADD COLUMN position_id VARCHAR(36) NOT NULL`
  );
  console.log('  OK  所有旧主键列 -> varchar(36)');

  // 6c: 填充 organize 的所有列（id, dept_id, position_id, user_id）
  // user_id: 此时仍是旧 INT 值（Step 2 改为 VARCHAR 但未更新），一并更新为新 UUID
  for (const [oldIdStr, entry] of Object.entries(idMap.organize)) {
    const oldId = entry.oldId;
    await conn.query(
      'UPDATE organize SET id=?, dept_id=?, position_id=?, user_id=? WHERE id=?',
      [entry.newId, entry.newDeptId, entry.newPosId, entry.newUserId, oldId]
    );
  }
  console.log(`  OK  填充 ${Object.keys(idMap.organize).length} 条（包含 user_id）`);

  // 6d: 添加主键
  await mig(conn, `ALTER TABLE organize ADD PRIMARY KEY(id)`);
  console.log('  OK  ADD PRIMARY KEY(id)');

  // ============================================================
  // Step 7: 迁移 users 主键（最后执行）
  // ============================================================
  console.log('\n[Step 7] 迁移 users 主键...');
  await mig(conn, `ALTER TABLE users DROP PRIMARY KEY`);
  await mig(conn, `ALTER TABLE users MODIFY COLUMN id VARCHAR(36) NOT NULL`);
  console.log('  OK  id -> varchar(36)');

  for (const [oldIdStr, entry] of Object.entries(idMap.users)) {
    const oldId = entry.oldId;
    await conn.query('UPDATE users SET id=? WHERE id=?', [entry.newId, oldId]);
  }
  console.log(`  OK  id 填充 ${Object.keys(idMap.users).length} 条`);

  await mig(conn, `ALTER TABLE users ADD PRIMARY KEY(id)`);
  console.log('  OK  ADD PRIMARY KEY(id)');

  // ============================================================
  // 最终验证
  // ============================================================
  console.log('\n========================================');
  console.log('验证结果');
  console.log('========================================');

  async function showPK(table) {
    const [r] = await conn.query(
      `SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE, COLUMN_KEY
       FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME=? AND COLUMN_KEY='PRI'`, [table]
    );
    return r;
  }

  for (const tbl of ['users', 'organize_dept', 'organize_position', 'organize']) {
    const pk = await showPK(tbl);
    console.log(`\n  ${tbl} PK:`, JSON.stringify(pk));
  }

  // UUID 格式验证
  const [sUsers] = await conn.query('SELECT id FROM users LIMIT 3');
  const [sDept] = await conn.query('SELECT dept_id FROM organize_dept LIMIT 3');
  const [sPos] = await conn.query('SELECT position_id FROM organize_position LIMIT 3');
  const [sOrg] = await conn.query('SELECT id FROM organize LIMIT 3');
  console.log('\n  UUID 样本:');
  console.log('    users:', sUsers.map(r => r.id));
  console.log('    organize_dept:', sDept.map(r => r.dept_id));
  console.log('    organize_position:', sPos.map(r => r.position_id));
  console.log('    organize:', sOrg.map(r => r.id));

  // 外键字段类型验证
  const [fkType] = await conn.query(
    `SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE
     FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA='go_chat' AND COLUMN_NAME IN ('user_id','creator_id','from_id','parent_id')
     AND TABLE_NAME NOT IN ('users','organize_dept','organize_position')
     ORDER BY TABLE_NAME LIMIT 8`
  );
  console.log('\n  外键字段类型样本:');
  for (const r of fkType) console.log(`    ${r.TABLE_NAME}.${r.COLUMN_NAME}: ${r.COLUMN_TYPE}`);

  // 数据完整性：验证外键引用是否存在
  console.log('\n  数据完整性检查:');
  const [orphanUserId] = await conn.query(
    `SELECT COUNT(*) as cnt FROM article a
     LEFT JOIN users u ON a.user_id = u.id
     WHERE u.id IS NULL AND a.user_id IS NOT NULL`
  );
  console.log(`    article.user_id 孤立记录: ${orphanUserId[0].cnt}`);

  const [orphanOrg] = await conn.query(
    `SELECT COUNT(*) as cnt FROM organize o
     LEFT JOIN users u ON o.user_id = u.id
     WHERE u.id IS NULL AND o.user_id IS NOT NULL`
  );
  console.log(`    organize.user_id 孤立记录: ${orphanOrg[0].cnt}`);

  await conn.end();
  console.log('\n=== 迁移完成 ===');
}

migrate().catch(e => {
  console.error('Fatal:', e.message, e.stack);
  process.exit(1);
});
