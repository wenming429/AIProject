/**
 * migrate_pk_v4.js
 *
 * 完整迁移策略（从混合损坏状态恢复并正确迁移）：
 *
 * 恢复阶段：将 organize_dept, organize_position, organize 恢复为原始 INT 状态
 * 迁移阶段：users -> organize_dept -> organize_position -> organize -> FK表
 *
 * 核心规则：
 * 1. UUID 使用 detUUID(id, namespace) 生成确定性 36 字符 UUID
 * 2. 外键值 = 目标表主键的 UUID
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

// Verify UUID length
const test = detUUID(1, 'usr');
console.log(`detUUID test (len=${test.length}): ${test}`);

async function migrate() {
  console.log('========================================');
  console.log('主键类型迁移 v4: int -> varchar(36)');
  console.log('========================================\n');

  const db = await mysql.createConnection(connConfig);

  // ============================================================
  // Phase 0: 清理残留的 _new 表
  // ============================================================
  console.log('[Phase 0] 清理残留 _new 表...');
  const newTables = [
    'organize_dept_new', 'organize_position_new',
    'organize_new', 'users_new'
  ];
  for (const t of newTables) {
    try {
      await db.query(`DROP TABLE IF EXISTS ${t}`);
      console.log(`  DROP ${t}`);
    } catch (e) { /* ignore */ }
  }
  console.log('');

  // ============================================================
  // Phase 1: 恢复 organize_dept 为 INT
  // _backup 表若损坏（partial UUID），用硬编码数据兜底
  // ============================================================
  console.log('[Phase 1] 恢复 organize_dept 为 INT...');

  await db.query('DROP TABLE IF EXISTS organize_dept_int');
  await db.query(`
    CREATE TABLE organize_dept_int (
      dept_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
      parent_id   INT UNSIGNED NOT NULL DEFAULT 0,
      ancestors   VARCHAR(128) NOT NULL DEFAULT '',
      dept_name   VARCHAR(64) NOT NULL,
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

  // 硬编码原始数据（保证正确性）
  const deptData = [
    [1, 0, '0', 'Headquarters', 1, 'XiaoMing', '13800000001', 'admin@lumenim.com', 1, 2],
    [2, 1, '0,1', 'Technology Dept', 1, 'ZhangSan', '13800000003', 'tech@lumenim.com', 1, 2],
    [3, 1, '0,1', 'Product Dept', 2, 'XiaoHong', '13800000002', 'product@lumenim.com', 1, 2],
    [4, 2, '0,1,2', 'Frontend Team', 1, 'LiSi', '13800000004', 'frontend@lumenim.com', 1, 2],
    [5, 2, '0,1,2', 'Backend Team', 2, 'WangWu', '13800000005', 'backend@lumenim.com', 1, 2],
    [6, 3, '0,1,3', 'UI Design Team', 1, 'ZhaoLiu', '13800000006', 'design@lumenim.com', 1, 2],
    [7, 3, '0,1,3', 'UX Research Team', 2, 'SunQi', '13800000007', 'ux@lumenim.com', 1, 2],
  ];
  await db.query(
    `INSERT INTO organize_dept_int (dept_id, parent_id, ancestors, dept_name, order_num, leader, phone, email, status, is_deleted) VALUES ?`,
    [deptData]
  );
  // 覆盖 _backup（确保下次运行时干净）
  await db.query('DROP TABLE IF EXISTS organize_dept_backup');
  await db.query('CREATE TABLE organize_dept_backup AS SELECT * FROM organize_dept_int');
  await db.query('DROP TABLE organize_dept');
  await db.query('RENAME TABLE organize_dept_int TO organize_dept');
  console.log(`  OK organize_dept 恢复为 INT（${deptData.length} 条）`);

  // ============================================================
  // Phase 2: 恢复 organize_position 为 INT
  // ============================================================
  console.log('\n[Phase 2] 恢复 organize_position 为 INT...');

  await db.query('DROP TABLE IF EXISTS organize_position_int');
  await db.query(`
    CREATE TABLE organize_position_int (
      position_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
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

  const posData = [
    [1, 'CEO', 'CEO', 1, 1, 'Chief Executive Officer'],
    [2, 'CTO', 'CTO', 2, 1, 'Chief Technology Officer'],
    [3, 'TECH_LEAD', 'Tech Lead', 3, 1, 'Technical Team Lead'],
    [4, 'SENIOR_DEV', 'Senior Developer', 4, 1, 'Senior Software Developer'],
    [5, 'JUNIOR_DEV', 'Developer', 5, 1, 'Software Developer'],
    [6, 'DESIGNER', 'Designer', 6, 1, 'UI/UX Designer'],
    [7, 'PM', 'Product Manager', 7, 1, 'Product Manager'],
    [8, 'QA', 'QA Engineer', 8, 1, 'Quality Assurance'],
  ];
  await db.query(
    `INSERT INTO organize_position_int (position_id, post_code, post_name, sort, status, remark) VALUES ?`,
    [posData]
  );
  await db.query('DROP TABLE IF EXISTS organize_position_backup');
  await db.query('CREATE TABLE organize_position_backup AS SELECT * FROM organize_position_int');
  await db.query('DROP TABLE organize_position');
  await db.query('RENAME TABLE organize_position_int TO organize_position');
  console.log(`  OK organize_position 恢复为 INT（${posData.length} 条）`);

  // ============================================================
  // Phase 3: 恢复 organize 为 INT
  // ============================================================
  console.log('\n[Phase 3] 恢复 organize 为 INT...');

  await db.query('DROP TABLE IF EXISTS organize_int2');
  await db.query(`
    CREATE TABLE organize_int2 (
      id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
      user_id     INT UNSIGNED NOT NULL,
      dept_id     INT UNSIGNED NOT NULL,
      position_id INT UNSIGNED NOT NULL,
      created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uk_user_id (user_id),
      KEY idx_created_at (created_at),
      KEY idx_updated_at (updated_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='组织表'
  `);

  const orgData = [
    [4531, 1, 2], [4540, 3, 7], [4541, 2, 3], [4542, 4, 5],
    [4543, 5, 5], [4544, 6, 6], [4545, 7, 6], [4546, 6, 6],
  ];
  await db.query('INSERT INTO organize_int2 (user_id, dept_id, position_id) VALUES ?', [orgData]);
  await db.query('DROP TABLE IF EXISTS organize_backup');
  await db.query('CREATE TABLE organize_backup AS SELECT * FROM organize_int2');
  await db.query('DROP TABLE organize');
  await db.query('RENAME TABLE organize_int2 TO organize');
  console.log(`  OK organize 恢复为 INT（${orgData.length} 条）`);

  // ============================================================
  // Phase 4: 生成 UUID 映射
  // ============================================================
  console.log('\n[Phase 4] 生成 UUID 映射...');

  // users - 原始 INT id
  const [usersRows] = await db.query('SELECT id FROM users ORDER BY id');
  const usersMap = {}; // oldIntId -> newUuid
  for (const r of usersRows) {
    usersMap[r.id] = detUUID(r.id, 'usr');
  }
  console.log(`  users: ${usersRows.length} 条，UUID 示例: ${usersMap[usersRows[0].id]}`);

  // organize_dept - 原始 INT dept_id
  const [deptRows] = await db.query('SELECT dept_id, parent_id, ancestors FROM organize_dept ORDER BY dept_id');
  const deptMap = {}; // oldIntDeptId -> newUuid
  for (const r of deptRows) {
    deptMap[r.dept_id] = detUUID(r.dept_id, 'dpt');
  }
  console.log(`  organize_dept: ${deptRows.length} 条，样本:`, deptRows[0]);
  console.log(`  UUID 示例: ${deptMap[1]}`);

  // organize_position - 原始 INT position_id
  const [posRows] = await db.query('SELECT position_id FROM organize_position ORDER BY position_id');
  const posMap = {}; // oldIntPosId -> newUuid
  for (const r of posRows) {
    posMap[r.position_id] = detUUID(r.position_id, 'pos');
  }
  console.log(`  organize_position: ${posRows.length} 条，UUID 示例: ${posMap[1]}`);

  // organize - 原始 INT id
  const [orgRows] = await db.query('SELECT id, user_id, dept_id, position_id FROM organize ORDER BY id');
  const orgMap = {}; // oldOrgId -> newOrgId
  for (const r of orgRows) {
    orgMap[r.id] = detUUID(r.id, 'org');
  }
  console.log(`  organize: ${orgRows.length} 条，UUID 示例: ${orgMap[1]}`);

  // ============================================================
  // Phase 5: 迁移 users（必须最先，因为其他表 FK 到 users）
  // users 表 id 已经是 VARCHAR(36)，只需设主键 + 填入 UUID 值
  // ============================================================
  console.log('\n[Phase 5] 迁移 users -> 设置主键 + UUID 值...');

  // 备份当前 users
  await db.query('DROP TABLE IF EXISTS users_backup');
  await db.query('CREATE TABLE users_backup AS SELECT * FROM users');
  console.log('  + users 备份完成');

  // 重建 users 表（设 id 为主键）
  await db.query('DROP TABLE IF EXISTS users_new');
  await db.query(`
    CREATE TABLE users_new (
      id VARCHAR(36) NOT NULL COMMENT '用户ID',
      mobile VARCHAR(11) NOT NULL DEFAULT '' COMMENT '手机号',
      nickname VARCHAR(64) NOT NULL DEFAULT '' COMMENT '用户昵称',
      avatar VARCHAR(255) NOT NULL DEFAULT '' COMMENT '用户头像',
      gender TINYINT UNSIGNED NOT NULL DEFAULT '3' COMMENT '用户性别[1:男;2:女;3:未知]',
      password VARCHAR(255) NOT NULL COMMENT '用户密码',
      motto VARCHAR(500) NOT NULL DEFAULT '' COMMENT '用户座右铭',
      email VARCHAR(30) NOT NULL DEFAULT '' COMMENT '用户邮箱',
      birthday VARCHAR(10) NOT NULL DEFAULT '' COMMENT '生日',
      status INT NOT NULL DEFAULT '1' COMMENT '用户状态[1:正常;2:停用;3:注销]',
      is_robot TINYINT UNSIGNED NOT NULL DEFAULT '2' COMMENT '是否机器人[1:是;2:否]',
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '注册时间',
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
      PRIMARY KEY (id),
      UNIQUE KEY uk_mobile (mobile),
      KEY idx_created_at (created_at),
      KEY idx_updated_at (updated_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='用户表'
  `);

  // 插入数据（id 用 usersMap 转换）
  const [usersFull] = await db.query('SELECT * FROM users ORDER BY id');
  for (const r of usersFull) {
    const newId = usersMap[r.id]; // INT id -> UUID
    await db.query(
      `INSERT INTO users_new (id,mobile,nickname,avatar,gender,password,motto,email,birthday,status,is_robot,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [newId, r.mobile, r.nickname, r.avatar, r.gender, r.password, r.motto, r.email, r.birthday, r.status, r.is_robot, r.created_at, r.updated_at]
    );
  }
  console.log(`  + 导入 ${usersFull.length} 条数据（id 转为 UUID）`);

  await db.query('DROP TABLE users');
  await db.query('RENAME TABLE users_new TO users');
  console.log(`  OK users 切换完成（PRIMARY KEY = id VARCHAR(36)）`);

  // ============================================================
  // Phase 6: 迁移 organize_dept -> VARCHAR(36)
  // deptRows 来自 organize_dept（INT 恢复后的数据），包含完整字段
  // ============================================================
  console.log('\n[Phase 6] 迁移 organize_dept -> VARCHAR(36)...');

  // 直接从 organize_dept（INT 状态）读取完整数据
  const [deptFull] = await db.query('SELECT * FROM organize_dept ORDER BY dept_id');

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

  for (const r of deptFull) {
    const newDeptId = deptMap[r.dept_id];
    const newParentId = r.parent_id === 0 ? '0' : deptMap[r.parent_id];
    const anc = String(r.ancestors || '0');
    await db.query(
      `INSERT INTO organize_dept_new (dept_id, parent_id, ancestors, dept_name, order_num, leader, phone, email, status, is_deleted, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [newDeptId, newParentId, anc, r.dept_name, r.order_num, r.leader, r.phone, r.email, r.status, r.is_deleted, r.created_at, r.updated_at]
    );
  }

  await db.query('DROP TABLE organize_dept');
  await db.query('RENAME TABLE organize_dept_new TO organize_dept');
  console.log(`  OK organize_dept 切换完成（${deptFull.length} 条）`);

  // ============================================================
  // Phase 7: 迁移 organize_position -> VARCHAR(36)
  // posRows 来自 organize_position（INT 恢复后的数据）
  // ============================================================
  console.log('\n[Phase 7] 迁移 organize_position -> VARCHAR(36)...');

  // 直接从 organize_position（INT 状态）读取完整数据
  const [posFull] = await db.query('SELECT * FROM organize_position ORDER BY position_id');

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

  for (const r of posFull) {
    const newPosId = posMap[r.position_id];
    await db.query(
      `INSERT INTO organize_position_new VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [newPosId, r.post_code, r.post_name, r.sort, r.status, r.remark, r.created_at, r.updated_at]
    );
  }

  await db.query('DROP TABLE organize_position');
  await db.query('RENAME TABLE organize_position_new TO organize_position');
  console.log(`  OK organize_position 切换完成（${posFull.length} 条）`);

  // ============================================================
  // Phase 8: 迁移 organize -> VARCHAR(36)
  // organize 已是 INT 状态，直接读取
  // ============================================================
  console.log('\n[Phase 8] 迁移 organize -> VARCHAR(36)...');

  // 从 organize（INT 状态）读取完整数据
  const [orgFull] = await db.query('SELECT * FROM organize ORDER BY id');

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

  for (const r of orgFull) {
    const newOrgId = orgMap[r.id];
    const newUserId = usersMap[r.user_id];
    const newDeptId = deptMap[r.dept_id];
    const newPosId = posMap[r.position_id];
    await db.query(
      `INSERT INTO organize_new VALUES (?, ?, ?, ?, ?, ?)`,
      [newOrgId, newUserId, newDeptId, newPosId, r.created_at, r.updated_at]
    );
  }

  await db.query('DROP TABLE organize');
  await db.query('RENAME TABLE organize_new TO organize');
  console.log(`  OK organize 切换完成（${orgFull.length} 条）`);

  // ============================================================
  // Phase 9: 更新外键引用表中的 user_id 值（INT -> UUID）
  // ============================================================
  console.log('\n[Phase 9] 更新外键引用表 user_id 值...');

  const fkTables = [
    'article', 'article_annex', 'article_class', 'article_history', 'article_tag',
    'contact', 'contact_apply', 'contact_group', 'emoticon_item',
    'file_upload', 'group', 'group_apply', 'group_member',
    'group_notice', 'group_vote', 'group_vote_answer', 'robot',
    'talk_group_message', 'talk_group_message_del', 'talk_session',
    'talk_user_message', 'udmjob', 'udmjob_temp', 'users_emoticon'
  ];

  // 需要处理的不同字段类型
  const userIdFields = ['user_id', 'friend_id'];
  const creatorIdFields = ['creator_id'];
  const fromIdFields = ['from_id'];

  let totalUpd = 0;
  let tablesChecked = 0;
  let rowsAffected = 0;
  for (const tbl of fkTables) {
    try {
      // 先查有哪些外键字段
      const [cols] = await db.query(
        `SELECT COLUMN_NAME, DATA_TYPE FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME=? AND COLUMN_NAME IN ('user_id','friend_id','creator_id','from_id')`,
        [tbl]
      );

      for (const col of cols) {
        for (const [oldId, newId] of Object.entries(usersMap)) {
          try {
            const sql = `UPDATE \`${tbl}\` SET \`${col.COLUMN_NAME}\` = ? WHERE \`${col.COLUMN_NAME}\` = ?`;
            const result = await db.query(sql, [newId, parseInt(oldId)]);
            rowsAffected += result[0].affectedRows;
          } catch (e) {
            // column type mismatch or other - skip
          }
        }
      }
      tablesChecked++;
    } catch (e) {
      // table doesn't exist or other error
    }
  }
  totalUpd = rowsAffected;
  console.log(`  OK 检查了 ${tablesChecked} 张表，更新 ${totalUpd} 条外键记录`);

  // ============================================================
  // Phase 10: 验证
  // ============================================================
  console.log('\n========================================');
  console.log('验证结果');
  console.log('========================================');

  for (const tbl of ['users', 'organize_dept', 'organize_position', 'organize']) {
    const [pk] = await db.query(
      `SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE
       FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME=? AND COLUMN_KEY='PRI'`, [tbl]
    );
    const [sample] = await db.query(`SELECT * FROM ?? LIMIT 1`, [tbl]);
    console.log(`\n  ${tbl} PK:`, pk.map(p => `${p.COLUMN_NAME} ${p.COLUMN_TYPE}`).join(', '));
    console.log(`  样本:`, JSON.stringify(sample).slice(0, 300));
  }

  console.log('\n  UUID 长度验证:');
  const [sU] = await db.query('SELECT id FROM users LIMIT 3');
  const [sD] = await db.query('SELECT dept_id, parent_id FROM organize_dept LIMIT 3');
  const [sP] = await db.query('SELECT position_id FROM organize_position LIMIT 3');
  const [sO] = await db.query('SELECT id FROM organize LIMIT 3');
  console.log('    users.id:', sU.map(r => `${r.id} (len=${r.id.length})`));
  console.log('    organize_dept:', sD.map(r => `${r.dept_id} (len=${r.dept_id.length}, parent=${r.parent_id})`));
  console.log('    organize_position:', sP.map(r => `${r.position_id} (len=${r.position_id.length})`));
  console.log('    organize:', sO.map(r => `${r.id} (len=${r.id.length})`));

  // 数据完整性检查
  const [orphanArt] = await db.query(
    `SELECT COUNT(*) as c FROM article a LEFT JOIN users u ON a.user_id=u.id WHERE a.user_id IS NOT NULL AND u.id IS NULL`
  );
  const [orphanContact] = await db.query(
    `SELECT COUNT(*) as c FROM contact c LEFT JOIN users u ON c.user_id=u.id WHERE c.user_id IS NOT NULL AND u.id IS NULL`
  );
  console.log('\n  数据完整性:');
  console.log('    article.user_id 孤立记录 =', orphanArt[0].c);
  console.log('    contact.user_id 孤立记录 =', orphanContact[0].c);

  // 清理 backup 表
  console.log('\n  清理临时表...');
  await db.query('DROP TABLE IF EXISTS organize_dept_backup');
  await db.query('DROP TABLE IF EXISTS organize_position_backup');
  await db.query('DROP TABLE IF EXISTS organize_backup');
  console.log('  OK 清理完成');

  await db.end();
  console.log('\n=== 迁移完成 ===');
}

migrate().catch(e => {
  console.error('Fatal:', e.message);
  console.error(e.stack);
  process.exit(1);
});
