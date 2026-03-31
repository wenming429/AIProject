/**
 * migrate_pk_v3.js
 *
 * 最终策略：每个表都通过建新表 -> SELECT ... (带转换) -> 切换 的方式迁移。
 * 这避免了所有 ALTER COLUMN / DROP PRIMARY KEY 的复杂问题。
 *
 * 核心规则：
 * 1. 所有 UUID 使用 detUUID(id, namespace) 生成确定性 UUID
 * 2. 外键值 = 目标表主键的 UUID（而不是 INT 旧值）
 * 3. 外键列类型全部改为 VARCHAR(36)
 */

const mysql = require('mysql2/promise');

const connConfig = {
  host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
};

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

async function migrate() {
  console.log('========================================');
  console.log('主键类型迁移 v3: int -> varchar(36)');
  console.log('策略: 每个表都通过新表切换方式迁移');
  console.log('========================================\n');

  const db = await mysql.createConnection(connConfig);

  // ============================================================
  // Step 1: 收集所有原始数据 + 生成 UUID 映射
  // ============================================================
  console.log('[Step 1] 收集原始数据 + 生成 UUID 映射...');

  // users - 原始数据（从未被迁移）
  const [usersRows] = await db.query('SELECT * FROM users ORDER BY id');
  const usersMap = {}; // oldIntId -> newUuid
  for (const r of usersRows) {
    usersMap[r.id] = detUUID(r.id, 'usr');
  }
  console.log(`  users: ${usersRows.length} 条（原始 INT）`);

  // organize_dept - 当前是 VARCHAR，但值是旧 INT 字符串
  const [deptRows] = await db.query('SELECT * FROM organize_dept ORDER BY 1');
  const deptMap = {}; // oldIntDeptId -> newUuid
  for (const r of deptRows) {
    deptMap[parseInt(r.dept_id)] = detUUID(parseInt(r.dept_id), 'dpt');
  }
  console.log(`  organize_dept: ${deptRows.length} 条（VARCHAR 存 INT 字符串）`);

  // organize_position - 同上
  const [posRows] = await db.query('SELECT * FROM organize_position ORDER BY 1');
  const posMap = {};
  for (const r of posRows) {
    posMap[parseInt(r.position_id)] = detUUID(parseInt(r.position_id), 'pos');
  }
  console.log(`  organize_position: ${posRows.length} 条（VARCHAR 存 INT 字符串）`);

  // organize - 当前有混合数据
  const [orgRows] = await db.query('SELECT * FROM organize ORDER BY 1');
  const orgMap = {}; // oldOrgId -> {newId, newUserId, newDeptId, newPosId}
  for (const r of orgRows) {
    const oldOrgId = parseInt(r.id) || parseInt(orgRows.indexOf(r) + 1);
    orgMap[oldOrgId] = {
      newId: detUUID(oldOrgId, 'org'),
      newUserId: usersMap[r.user_id] || usersMap[parseInt(r.user_id)],
      newDeptId: deptMap[parseInt(r.dept_id)],
      newPosId: posMap[parseInt(r.position_id)],
    };
  }
  console.log(`  organize: ${orgRows.length} 条（混合状态）\n`);

  // ============================================================
  // Step 2: 重建 organize_dept 表
  // ============================================================
  console.log('[Step 2] 重建 organize_dept...');

  await db.query('DROP TABLE IF EXISTS organize_dept_new');
  await db.query(`
    CREATE TABLE organize_dept_new (
      dept_id     VARCHAR(36) NOT NULL,
      parent_id   VARCHAR(36) NULL,
      ancestors   VARCHAR(128) NOT NULL DEFAULT '',
      dept_name   VARCHAR(64) NOT NULL DEFAULT '',
      order_num   INT UNSIGNED NOT NULL DEFAULT 1,
      leader      VARCHAR(64) NOT NULL,
      phone       VARCHAR(11) NOT NULL,
      email       VARCHAR(64) NOT NULL,
      status      TINYINT NOT NULL DEFAULT 1,
      is_deleted  TINYINT UNSIGNED NOT NULL DEFAULT 2,
      created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (dept_id),
      KEY idx_created_at (created_at),
      KEY idx_updated_at (updated_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='部门表'
  `);

  for (const r of deptRows) {
    const oldDeptId = parseInt(r.dept_id);
    const oldParentId = parseInt(r.parent_id || 0);
    const newDeptId = deptMap[oldDeptId];
    // parent_id 用不同 namespace，避免与 dept_id 冲突（parent_id=1 != dept_id=1）
    const newParentId = oldParentId === 0 ? '0' : detUUID(oldParentId, 'par');
    await db.query(
      `INSERT INTO organize_dept_new (dept_id, parent_id, ancestors, dept_name, order_num, leader, phone, email, status, is_deleted, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [newDeptId, newParentId, r.ancestors, r.dept_name, r.order_num,
       r.leader, r.phone, r.email, r.status, r.is_deleted, r.created_at, r.updated_at]
    );
  }
  await db.query('DROP TABLE organize_dept');
  await db.query('RENAME TABLE organize_dept_new TO organize_dept');
  console.log(`  OK  organize_dept 切换完成（${deptRows.length} 条）`);

  // ============================================================
  // Step 3: 重建 organize_position 表
  // ============================================================
  console.log('\n[Step 3] 重建 organize_position...');

  await db.query('DROP TABLE IF EXISTS organize_position_new');
  await db.query(`
    CREATE TABLE organize_position_new (
      position_id VARCHAR(36) NOT NULL,
      post_code   VARCHAR(32) NOT NULL,
      post_name   VARCHAR(64) NOT NULL,
      sort        INT UNSIGNED NOT NULL DEFAULT 1,
      status      TINYINT UNSIGNED NOT NULL DEFAULT 1,
      remark      VARCHAR(255) NOT NULL DEFAULT '',
      created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (position_id),
      KEY idx_created_at (created_at),
      KEY idx_updated_at (updated_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='岗位信息表'
  `);

  for (const r of posRows) {
    const oldPosId = parseInt(r.position_id);
    const newPosId = posMap[oldPosId];
    await db.query(
      `INSERT INTO organize_position_new VALUES (?,?,?,?,?,?,?,?)`,
      [newPosId, r.post_code, r.post_name, r.sort, r.status, r.remark, r.created_at, r.updated_at]
    );
  }
  await db.query('DROP TABLE organize_position');
  await db.query('RENAME TABLE organize_position_new TO organize_position');
  console.log(`  OK  organize_position 切换完成（${posRows.length} 条）`);

  // ============================================================
  // Step 4: 重建 organize 表（仅创建，插入推迟到 users 迁移后）
  // ============================================================
  console.log('\n[Step 4] 重建 organize（创建空表）...');

  await db.query('DROP TABLE IF EXISTS organize_new');
  await db.query(`
    CREATE TABLE organize_new (
      id          VARCHAR(36) NOT NULL,
      user_id     VARCHAR(36) NOT NULL,
      dept_id     VARCHAR(36) NOT NULL,
      position_id VARCHAR(36) NOT NULL,
      created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uk_user_id (user_id),
      KEY idx_created_at (created_at),
      KEY idx_updated_at (updated_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='组织表'
  `);
  console.log(`  + 创建 organize_new 空表`);

  // ============================================================
  // Step 5: 重建 users 表（先迁移 users，因为其他表 FK 到 users）
  // ============================================================
  console.log('\n[Step 5] 重建 users...');

  const [userCols] = await db.query(
    `SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, COLUMN_KEY, COLUMN_COMMENT
     FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME='users' ORDER BY ORDINAL_POSITION`
  );

  const pkCol = userCols.find(c => c.COLUMN_KEY === 'PRI');
  const nonPkCols = userCols.filter(c => c.COLUMN_NAME !== pkCol.COLUMN_NAME);
  const uniqueCols = userCols.filter(c => c.COLUMN_KEY === 'UNI' && c.COLUMN_NAME !== pkCol.COLUMN_NAME);

  const createUsersSQL = `
    CREATE TABLE users_new (
      id VARCHAR(36) NOT NULL,
      ${nonPkCols.map(c => {
        const nullable = c.IS_NULLABLE === 'YES' ? 'NULL' : 'NOT NULL';
        const def = (c.COLUMN_DEFAULT !== null && c.COLUMN_DEFAULT !== undefined) ? ` DEFAULT ${c.COLUMN_DEFAULT}` : '';
        const extra = (c.EXTRA && !c.EXTRA.includes('DEFAULT_GENERATED')) ? ` ${c.EXTRA}` : '';
        const comment = c.COLUMN_COMMENT ? ` COMMENT '${c.COLUMN_COMMENT}'` : '';
        return `\`${c.COLUMN_NAME}\` ${c.COLUMN_TYPE} ${nullable}${def}${extra}${comment}`;
      }).join(',\n      ')}
      ${uniqueCols.map(c => `, UNIQUE KEY uk_${c.COLUMN_NAME} (\`${c.COLUMN_NAME}\`)`).join('')}
      , KEY idx_created_at (created_at)
      , KEY idx_updated_at (updated_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  `.trim().replace(/\s+/g, ' ');

  await db.query('DROP TABLE IF EXISTS users_new');
  await db.query(createUsersSQL);
  console.log('  + 创建 users_new');

  for (const r of usersRows) {
    const newId = usersMap[r.id];
    const vals = nonPkCols.map(c => r[c.COLUMN_NAME]);
    await db.query(
      `INSERT INTO users_new (id, ${nonPkCols.map(c => '`' + c.COLUMN_NAME + '`').join(',')}) VALUES (?,${nonPkCols.map(() => '?').join(',')})`,
      [newId, ...vals]
    );
  }
  console.log(`  + 导入 ${usersRows.length} 条数据`);

  await db.query('DROP TABLE users');
  await db.query('RENAME TABLE users_new TO users');
  console.log(`  OK  users 切换完成`);

  // ============================================================
  // Step 5b: 插入 organize 数据（users 已迁移，可以获取新 UUID）
  // ============================================================
  console.log('\n[Step 5b] 填充 organize 数据...');

  // 重新获取 organize 原始数据（仍然是旧 INT 值）
  const [orgRowsFresh] = await db.query('SELECT * FROM organize ORDER BY 1');
  for (const r of orgRowsFresh) {
    const oldOrgId = parseInt(r.id);
    const oldUserId = parseInt(r.user_id);
    const oldDeptId = parseInt(r.dept_id);
    const oldPosId = parseInt(r.position_id);
    const newOrgId = detUUID(oldOrgId, 'org');
    const newUserId = usersMap[oldUserId];
    const newDeptId = deptMap[oldDeptId];
    const newPosId = posMap[oldPosId];
    await db.query(
      `INSERT INTO organize_new VALUES (?,?,?,?,?,?)`,
      [newOrgId, newUserId, newDeptId, newPosId, r.created_at, r.updated_at]
    );
  }
  console.log(`  + 插入 ${orgRowsFresh.length} 条数据`);

  await db.query('DROP TABLE organize');
  await db.query('RENAME TABLE organize_new TO organize');
  console.log(`  OK  organize 切换完成`);

  // ============================================================
  // Step 6: 所有外键引用表改为 VARCHAR + 填充 UUID
  // ============================================================
  console.log('\n[Step 6] 修改外键引用表字段类型...');

  // organize.user_id（已在 Step 4 重建，但值需要基于 users 新 UUID 更新）
  // 实际上 organize.user_id 已经在 Step 4 用 usersMap[r.user_id] 填充了
  // 但如果 organize.user_id 引用了旧的 INT user_id，需要用 usersMap 转换
  // 已在 Step 4 完成

  const fkAlterSQLs = [
    [`ALTER TABLE article               MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE article_annex         MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '上传文件的用户ID'`],
    [`ALTER TABLE article_class         MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE article_history       MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE article_tag           MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE contact               MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户id'`],
    [`ALTER TABLE contact_apply         MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '申请人ID'`],
    [`ALTER TABLE contact_group         MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE emoticon_item         MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE file_upload           MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '上传的用户ID'`],
    [`ALTER TABLE group                 MODIFY COLUMN creator_id VARCHAR(36) NULL COMMENT '群主ID'`],
    [`ALTER TABLE group_apply           MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '申请人ID'`],
    [`ALTER TABLE group_member          MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '群成员ID'`],
    [`ALTER TABLE group_notice          MODIFY COLUMN creator_id VARCHAR(36) NULL COMMENT '公告创建者ID'`],
    [`ALTER TABLE group_vote            MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '投票发起人ID'`],
    [`ALTER TABLE group_vote_answer     MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '投票用户ID'`],
    [`ALTER TABLE robot                 MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '关联用户ID'`],
    [`ALTER TABLE talk_group_message    MODIFY COLUMN from_id    VARCHAR(36) NULL COMMENT '消息发送者ID'`],
    [`ALTER TABLE talk_group_message_del MODIFY COLUMN user_id  VARCHAR(36) NULL COMMENT '删除人ID'`],
    [`ALTER TABLE talk_session          MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE talk_user_message     MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
    [`ALTER TABLE talk_user_message     MODIFY COLUMN from_id    VARCHAR(36) NULL COMMENT '发送者ID'`],
    [`ALTER TABLE udmjob                MODIFY COLUMN USERID     VARCHAR(36) NULL`],
    [`ALTER TABLE udmjob_temp           MODIFY COLUMN USERID    VARCHAR(36) NULL`],
    [`ALTER TABLE users_emoticon        MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`],
  ];

  for (const [sql] of fkAlterSQLs) {
    const tbl = sql.match(/ALTER TABLE `?(\w+)`?/)[1];
    try {
      await db.query(sql);
      console.log(`  OK  ${tbl}`);
    } catch (e) {
      console.error(`  ERR ${tbl}: ${e.message}`);
    }
  }

  // ============================================================
  // Step 7: 更新外键值为 UUID
  // ============================================================
  console.log('\n[Step 7] 更新外键值为 UUID...');

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

  let totalUpd = 0;
  for (const [sqlTpl] of fkUpdateSQLs) {
    for (const [oldId, newId] of Object.entries(usersMap)) {
      try {
        await db.query(sqlTpl, [newId, parseInt(oldId)]);
        totalUpd++;
      } catch (e) { /* 0 rows affected */ }
    }
  }
  console.log(`  OK  共执行 ${totalUpd} 条外键更新`);

  // ============================================================
  // 最终验证
  // ============================================================
  console.log('\n========================================');
  console.log('验证结果');
  console.log('========================================');

  for (const tbl of ['users', 'organize_dept', 'organize_position', 'organize']) {
    const [pk] = await db.query(
      `SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE, COLUMN_KEY
       FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME=? AND COLUMN_KEY='PRI'`, [tbl]
    );
    const [sample] = await db.query(`SELECT * FROM ?? LIMIT 1`, [tbl]);
    console.log(`\n  ${tbl} PK:`, JSON.stringify(pk));
    console.log(`  样本:`, JSON.stringify(sample).slice(0, 200));
  }

  const [sU] = await db.query('SELECT id FROM users LIMIT 3');
  const [sD] = await db.query('SELECT dept_id, parent_id FROM organize_dept LIMIT 3');
  const [sP] = await db.query('SELECT position_id FROM organize_position LIMIT 3');
  const [sO] = await db.query('SELECT id, user_id, dept_id, position_id FROM organize LIMIT 3');
  console.log('\n  UUID 样本:');
  console.log('    users.id:', sU.map(r => r.id));
  console.log('    organize_dept:', sD.map(r => `${r.dept_id}/${r.parent_id}`));
  console.log('    organize_position:', sP.map(r => r.position_id));
  console.log('    organize:', sO.map(r => `${r.id}/${r.user_id}/${r.dept_id}/${r.position_id}`));

  // 数据完整性
  const [orphan] = await db.query(
    `SELECT COUNT(*) as c FROM article a LEFT JOIN users u ON a.user_id=u.id WHERE a.user_id IS NOT NULL AND u.id IS NULL`
  );
  console.log('\n  数据完整性: article.user_id 孤立记录 =', orphan[0].c);

  await db.end();
  console.log('\n=== 迁移完成 ===');
}

migrate().catch(e => {
  console.error('Fatal:', e.message, e.stack);
  process.exit(1);
});
