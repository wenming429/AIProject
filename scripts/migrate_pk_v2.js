/**
 * migrate_pk_v2.js
 *
 * 策略（最安全）：
 * 1. 为每张主键表创建一个新的同名表（含新 varchar(36) 主键）
 * 2. 从原表 INSERT INTO 新表（自动完成 ID 映射转换）
 * 3. 删除原表，重命名新表
 * 4. 外键表同样处理：创建新表 -> 导入数据 -> 切换
 *
 * 这样完全不涉及 ALTER COLUMN 和 DROP PRIMARY KEY 的复杂操作。
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

async function conn(config) {
  return mysql.createConnection(config);
}

async function migrate() {
  console.log('========================================');
  console.log('主键类型迁移 v2: int -> varchar(36)');
  console.log('策略: 创建新表 -> 导入 -> 切换');
  console.log('========================================\n');

  const db = await conn(connConfig);

  // ============================================================
  // Step 1: 生成 ID 映射
  // ============================================================
  console.log('[Step 1] 生成 ID 映射...');

  const [usersRows] = await db.query('SELECT id FROM users ORDER BY id');
  const usersMap = {};
  for (const r of usersRows) {
    usersMap[r.id] = detUUID(r.id, 'usr');
  }
  console.log(`  users: ${usersRows.length} 条`);

  const [deptRows] = await db.query('SELECT dept_id FROM organize_dept ORDER BY dept_id');
  const deptMap = {};
  for (const r of deptRows) {
    deptMap[r.dept_id] = detUUID(r.dept_id, 'dpt');
  }
  console.log(`  organize_dept: ${deptRows.length} 条`);

  const [posRows] = await db.query('SELECT position_id FROM organize_position ORDER BY position_id');
  const posMap = {};
  for (const r of posRows) {
    posMap[r.position_id] = detUUID(r.position_id, 'pos');
  }
  console.log(`  organize_position: ${posRows.length} 条`);

  const [orgRows] = await db.query('SELECT id, user_id, dept_id, position_id FROM organize ORDER BY id');
  const orgMap = {};
  for (const r of orgRows) {
    orgMap[r.id] = {
      newId: detUUID(r.id, 'org'),
      newUserId: usersMap[r.user_id],
      newDeptId: deptMap[r.dept_id],
      newPosId: posMap[r.position_id],
    };
  }
  console.log(`  organize: ${orgRows.length} 条\n`);

  // ============================================================
  // Step 2: 重建 organize_dept 表
  // ============================================================
  console.log('[Step 2] 重建 organize_dept...');

  // 2a: 创建新表
  await db.query(`
    CREATE TABLE organize_dept_new (
      dept_id     VARCHAR(36) NOT NULL,
      parent_id   VARCHAR(36) NULL COMMENT '父部门id',
      ancestors   VARCHAR(128) NOT NULL DEFAULT '',
      dept_name   VARCHAR(64) NOT NULL DEFAULT '',
      order_num   INT UNSIGNED NOT NULL DEFAULT 1 COMMENT '显示顺序',
      leader      VARCHAR(64) NOT NULL COMMENT '负责人',
      phone       VARCHAR(11) NOT NULL COMMENT '联系电话',
      email       VARCHAR(64) NOT NULL COMMENT '邮箱',
      status      TINYINT NOT NULL DEFAULT 1 COMMENT '部门状态[1:正常;2:停用]',
      is_deleted  TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT '是否删除[1:是;2:否;]',
      created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
      updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
      PRIMARY KEY (dept_id),
      KEY idx_created_at (created_at),
      KEY idx_updated_at (updated_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='部门表'
  `);
  console.log('  + 创建 organize_dept_new');

  // 2b: 导入数据
  for (const r of deptRows) {
    const newDeptId = deptMap[r.dept_id];
    const newParentId = r.parent_id === 0 ? '0' : deptMap[r.parent_id];
    await db.query(
      `INSERT INTO organize_dept_new (dept_id, parent_id, ancestors, dept_name, order_num, leader, phone, email, status, is_deleted, created_at, updated_at)
       SELECT ?, ?, ancestors, dept_name, order_num, leader, phone, email, status, is_deleted, created_at, updated_at
       FROM organize_dept WHERE dept_id = ?`,
      [newDeptId, newParentId || '0', r.dept_id]
    );
  }
  console.log(`  + 导入 ${deptRows.length} 条数据`);

  // 2c: 切换
  await db.query('DROP TABLE organize_dept');
  await db.query('RENAME TABLE organize_dept_new TO organize_dept');
  console.log('  OK  organize_dept 切换完成');

  // ============================================================
  // Step 3: 重建 organize_position 表
  // ============================================================
  console.log('\n[Step 3] 重建 organize_position...');

  await db.query(`
    CREATE TABLE organize_position_new (
      position_id VARCHAR(36) NOT NULL,
      post_code   VARCHAR(32) NOT NULL COMMENT '岗位编码',
      post_name   VARCHAR(64) NOT NULL COMMENT '岗位名称',
      sort        INT UNSIGNED NOT NULL DEFAULT 1 COMMENT '显示顺序',
      status      TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '状态[1:正常;2:停用;]',
      remark      VARCHAR(255) NOT NULL DEFAULT '' COMMENT '备注',
      created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
      updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
      PRIMARY KEY (position_id),
      KEY idx_created_at (created_at),
      KEY idx_updated_at (updated_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='岗位信息表'
  `);

  for (const r of posRows) {
    const newPosId = posMap[r.position_id];
    await db.query(
      `INSERT INTO organize_position_new (position_id, post_code, post_name, sort, status, remark, created_at, updated_at)
       SELECT ?, post_code, post_name, sort, status, remark, created_at, updated_at
       FROM organize_position WHERE position_id = ?`,
      [newPosId, r.position_id]
    );
  }
  await db.query('DROP TABLE organize_position');
  await db.query('RENAME TABLE organize_position_new TO organize_position');
  console.log('  OK  organize_position 切换完成');

  // ============================================================
  // Step 4: 重建 organize 表（复合主键 -> 单一主键）
  // ============================================================
  console.log('\n[Step 4] 重建 organize...');

  await db.query(`
    CREATE TABLE organize_new (
      id          VARCHAR(36) NOT NULL,
      user_id     VARCHAR(36) NOT NULL COMMENT '用户id',
      dept_id     VARCHAR(36) NOT NULL COMMENT '部门ID',
      position_id VARCHAR(36) NOT NULL COMMENT '岗位ID',
      created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
      updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
      PRIMARY KEY (id),
      UNIQUE KEY uk_user_id (user_id),
      KEY idx_created_at (created_at),
      KEY idx_updated_at (updated_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='组织表'
  `);

  for (const r of orgRows) {
    const entry = orgMap[r.id];
    await db.query(
      `INSERT INTO organize_new (id, user_id, dept_id, position_id, created_at, updated_at)
       SELECT ?, ?, ?, ?, created_at, updated_at
       FROM organize WHERE id = ?`,
      [entry.newId, entry.newUserId, entry.newDeptId, entry.newPosId, r.id]
    );
  }
  console.log(`  + 导入 ${orgRows.length} 条数据`);

  await db.query('DROP TABLE organize');
  await db.query('RENAME TABLE organize_new TO organize');
  console.log('  OK  organize 切换完成');

  // ============================================================
  // Step 5: 重建 users 表
  // ============================================================
  console.log('\n[Step 5] 重建 users...');

  // 先获取完整的列定义
  const [userCols] = await db.query(
    `SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, COLUMN_KEY, COLUMN_COMMENT
     FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME='users' ORDER BY ORDINAL_POSITION`
  );
  const pkCol = userCols.find(c => c.COLUMN_KEY === 'PRI');
  const nonPkCols = userCols.filter(c => c.COLUMN_NAME !== pkCol.COLUMN_NAME);

  // 构建新表创建语句
  const pkDef = `id VARCHAR(36) NOT NULL`;
  const colDefs = nonPkCols.map(c => {
    const nullable = c.IS_NULLABLE === 'YES' ? 'NULL' : 'NOT NULL';
    const def = c.COLUMN_DEFAULT !== null ? ` DEFAULT ${c.COLUMN_DEFAULT}` : '';
    const extra = c.EXTRA && !c.EXTRA.includes('DEFAULT_GENERATED') ? ` ${c.EXTRA}` : '';
    const comment = c.COLUMN_COMMENT ? ` COMMENT '${c.COLUMN_COMMENT}'` : '';
    return `\`${c.COLUMN_NAME}\` ${c.COLUMN_TYPE} ${nullable}${def}${extra}${comment}`;
  }).join(',\n      ');

  const uniqueKeys = userCols
    .filter(c => c.COLUMN_KEY === 'UNI')
    .map(c => `UNIQUE KEY uk_${c.COLUMN_NAME} (\`${c.COLUMN_NAME}\`)`)
    .join(',\n      ');

  const createUsersSQL = `
    CREATE TABLE users_new (
      ${pkDef},
      ${colDefs}
      ${uniqueKeys ? ',' + uniqueKeys : ''},
      KEY idx_created_at (created_at),
      KEY idx_updated_at (updated_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  `.trim().replace(/\s+/g, ' ');

  await db.query(createUsersSQL);
  console.log('  + 创建 users_new');

  // 导入数据
  for (const r of usersRows) {
    const newId = usersMap[r.id];
    await db.query(
      `INSERT INTO users_new (id, ${nonPkCols.map(c => '`' + c.COLUMN_NAME + '`').join(',')})
       SELECT ?, ${nonPkCols.map(c => '`' + c.COLUMN_NAME + '`').join(',')}
       FROM users WHERE id = ?`,
      [newId, r.id]
    );
  }
  console.log(`  + 导入 ${usersRows.length} 条数据`);

  await db.query('DROP TABLE users');
  await db.query('RENAME TABLE users_new TO users');
  console.log('  OK  users 切换完成');

  // ============================================================
  // Step 6: 更新所有外键引用表
  // ============================================================
  console.log('\n[Step 6] 更新外键引用表...');

  // 先把所有 INT 外键列改为 VARCHAR
  const alterFKSQLs = [
    `ALTER TABLE organize          MODIFY COLUMN user_id    VARCHAR(36) NOT NULL COMMENT '用户id'`,
    `ALTER TABLE article           MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`,
    `ALTER TABLE article_annex     MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '上传文件的用户ID'`,
    `ALTER TABLE article_class     MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`,
    `ALTER TABLE article_history   MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`,
    `ALTER TABLE article_tag       MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`,
    `ALTER TABLE contact           MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户id'`,
    `ALTER TABLE contact_apply     MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '申请人ID'`,
    `ALTER TABLE contact_group    MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`,
    `ALTER TABLE emoticon_item     MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '用户ID'`,
    `ALTER TABLE file_upload       MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '上传的用户ID'`,
    `ALTER TABLE group             MODIFY COLUMN creator_id VARCHAR(36) NULL COMMENT '群主ID'`,
    `ALTER TABLE group_apply       MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '申请人ID'`,
    `ALTER TABLE group_member      MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '群成员ID'`,
    `ALTER TABLE group_notice      MODIFY COLUMN creator_id VARCHAR(36) NULL COMMENT '公告创建者ID'`,
    `ALTER TABLE group_vote        MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '投票发起人ID'`,
    `ALTER TABLE group_vote_answer MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '投票用户ID'`,
    `ALTER TABLE robot             MODIFY COLUMN user_id    VARCHAR(36) NULL COMMENT '关联用户ID'`,
    `ALTER TABLE talk_group_message    MODIFY COLUMN from_id VARCHAR(36) NULL COMMENT '消息发送者ID'`,
    `ALTER TABLE talk_group_message_del MODIFY COLUMN user_id VARCHAR(36) NULL COMMENT '删除人ID'`,
    `ALTER TABLE talk_session       MODIFY COLUMN user_id  VARCHAR(36) NULL COMMENT '用户ID'`,
    `ALTER TABLE talk_user_message  MODIFY COLUMN user_id  VARCHAR(36) NULL COMMENT '用户ID'`,
    `ALTER TABLE talk_user_message  MODIFY COLUMN from_id  VARCHAR(36) NULL COMMENT '发送者ID'`,
    `ALTER TABLE udmjob             MODIFY COLUMN USERID   VARCHAR(36) NULL`,
    `ALTER TABLE udmjob_temp        MODIFY COLUMN USERID  VARCHAR(36) NULL`,
    `ALTER TABLE users_emoticon     MODIFY COLUMN user_id  VARCHAR(36) NULL COMMENT '用户ID'`,
  ];

  for (const sql of alterFKSQLs) {
    const tbl = sql.match(/ALTER TABLE `?(\w+)`?/)[1];
    try {
      await db.query(sql);
      console.log(`  OK  ${tbl}`);
    } catch (e) {
      console.error(`  ERR ${tbl}: ${e.message}`);
    }
  }

  // 更新所有外键值为 UUID
  console.log('\n[Step 7] 更新外键值...');
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
      } catch (e) { /* ignore 0 rows */ }
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
    console.log(`\n  ${tbl} PK:`, JSON.stringify(pk));
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
  console.log('\n  数据完整性 - article.user_id 孤立记录:', orphan[0].c);

  await db.end();
  console.log('\n=== 迁移完成 ===');
}

migrate().catch(e => {
  console.error('Fatal:', e.message, e.stack);
  process.exit(1);
});
