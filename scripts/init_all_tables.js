/**
 * 一键初始化 go_chat 数据库核心表
 * 执行顺序：users -> organize_dept -> organize_position -> organize
 * 
 * 数据源：
 *   - users: init_users 视图
 *   - organize_dept: init_organization_dept 视图
 *   - organize_position: init_organize_position 视图
 *   - organize: init_organize 视图
 */

const mysql = require('mysql2/promise');

const DB_CONFIG = {
  host: 'localhost',
  user: 'root',
  password: 'wenming429',
  database: 'go_chat',
  charset: 'utf8mb4',
  connectTimeout: 30000,
  multipleStatements: false
};

const BATCH_SIZE = 500;

async function truncateAndReset(conn, table) {
  await conn.execute(`DELETE FROM ${table}`);
  await conn.execute(`ALTER TABLE ${table} AUTO_INCREMENT = 1`);
  console.log(`  ✓ ${table} 表已清空并重置自增ID`);
}

async function syncUsers(conn) {
  console.log('\n========================================');
  console.log('📋 步骤1: 初始化 users 表');
  console.log('========================================');
  console.log('数据源: init_users 视图');
  console.log('排序: EEMPLOYEEID, ORDERBY 升序\n');

  await truncateAndReset(conn, 'users');

  const startTime = Date.now();

  await conn.execute(`
    INSERT INTO users (
      userid, username, mobile, nickname, avatar, gender,
      password, motto, email, birthday, status, is_robot,
      created_at, updated_at
    )
    SELECT
      EEMPLOYEEID as userid,
      LOGINNAME AS username,
      IFNULL(PHONE, '') AS mobile,
      FULLNAME AS nickname,
      '' AS avatar,
      CASE IFNULL(UPPER(Gender), 'U')
        WHEN 'M' THEN 1
        WHEN 'F' THEN 2
        ELSE 3
      END AS gender,
      '$2a$10$MDkzvCBC4rSxfUFR81lZGu3EqiYBLRP4t6UoYoWmcqovZZc4PkDTW' AS password,
      '心有理想，鲜花盛开~~' AS motto,
      IFNULL(EMAIL, '') AS email,
      IFNULL(DATE_FORMAT(BIRTHDAY, '%Y-%m-%d'), '1970-01-01') AS birthday,
      1 AS status,
      2 AS is_robot,
      NOW() AS created_at,
      NOW() AS updated_at
    FROM init_users
    ORDER BY EEMPLOYEEID, ORDERBY
  `);

  const [result] = await conn.execute('SELECT COUNT(*) as cnt FROM users');
  const duration = ((Date.now() - startTime) / 1000).toFixed(2);

  console.log(`\n  ✓ 插入完成: ${result[0].cnt} 条记录，耗时 ${duration}s`);
  return result[0].cnt;
}

async function syncOrganizeDept(conn) {
  console.log('\n========================================');
  console.log('📋 步骤2: 初始化 organize_dept 表');
  console.log('========================================');
  console.log('数据源: init_organization_dept 视图');
  console.log('处理: 构建层级关系 (ancestors 格式: 0,父ID,当前ID)\n');

  await truncateAndReset(conn, 'organize_dept');

  const startTime = Date.now();

  // 1. 查询源数据
  const [orgs] = await conn.execute(`
    SELECT ID, PARENTID, FULLNAME, FULLPATHCODE, INNERORDER
    FROM init_organization_dept
    ORDER BY FULLPATHCODE ASC
  `);
  console.log(`  - 查询到 ${orgs.length} 条数据`);

  // 2. 构建树结构
  const nodesMap = new Map();
  const roots = [];

  orgs.forEach(org => {
    nodesMap.set(org.ID, {
      udm_id: org.ID,
      parent_udm_id: org.PARENTID || null,
      name: org.FULLNAME,
      order: org.INNERORDER > 2147483647 ? 1 : (org.INNERORDER || 1),
      children: []
    });
  });

  nodesMap.forEach(node => {
    if (node.parent_udm_id && nodesMap.has(node.parent_udm_id)) {
      nodesMap.get(node.parent_udm_id).children.push(node);
    } else if (!node.parent_udm_id) {
      roots.push(node);
    }
  });

  // 3. 递归处理节点
  const allNodes = [];
  let globalIdx = 0;

  function processNode(node, ancestors, parentId) {
    globalIdx++;
    const currentId = globalIdx;
    const nodeAncestors = parentId === 0 ? '0' : `${ancestors},${parentId}`;

    allNodes.push({
      udm_id: node.udm_id,
      parent_udm_id: node.parent_udm_id,
      name: node.name,
      order: node.order,
      ancestors: nodeAncestors,
      parent_id: parentId
    });

    node.children.sort((a, b) => a.order - b.order);
    node.children.forEach(child => {
      processNode(child, nodeAncestors, currentId);
    });
  }

  roots.sort((a, b) => a.order - b.order);
  roots.forEach(root => {
    processNode(root, '0', 0);
  });

  console.log(`  - 构建完成: ${allNodes.length} 个节点`);

  // 4. 批量插入
  for (let i = 0; i < allNodes.length; i += BATCH_SIZE) {
    const batch = allNodes.slice(i, i + BATCH_SIZE);
    for (const node of batch) {
      await conn.execute(
        `INSERT INTO organize_dept (dept_name, ancestors, parent_id, order_num, udm_org_id, udm_org_parent_id, leader, phone, email, status, is_deleted)
         VALUES (?, ?, ?, ?, ?, ?, '', '', '', 1, 1)`,
        [node.name, node.ancestors, node.parent_id, node.order, node.udm_id, node.parent_udm_id || '']
      );
    }
    const progress = Math.min(i + BATCH_SIZE, allNodes.length);
    process.stdout.write(`\r  - 插入进度: ${progress}/${allNodes.length}`);
  }
  console.log();

  const [result] = await conn.execute('SELECT COUNT(*) as cnt FROM organize_dept');
  const duration = ((Date.now() - startTime) / 1000).toFixed(2);

  console.log(`\n  ✓ 插入完成: ${result[0].cnt} 条记录，耗时 ${duration}s`);
  return result[0].cnt;
}

async function syncOrganizePosition(conn) {
  console.log('\n========================================');
  console.log('📋 步骤3: 初始化 organize_position 表');
  console.log('========================================');
  console.log('数据源: init_organize_position 视图');
  console.log('字段映射: ID -> post_code, POSITIONNAME -> post_name');
  console.log('处理: DISTINCT 去重\n');

  await truncateAndReset(conn, 'organize_position');

  const startTime = Date.now();

  await conn.execute(`
    INSERT INTO organize_position (post_code, post_name, sort, status, remark)
    SELECT DISTINCT
      ID as post_code,
      POSITIONNAME as post_name,
      1 as sort,
      1 as status,
      '' as remark
    FROM init_organize_position
    WHERE ID IS NOT NULL AND ID != ''
    ORDER BY post_code
  `);

  const [result] = await conn.execute('SELECT COUNT(*) as cnt FROM organize_position');
  const duration = ((Date.now() - startTime) / 1000).toFixed(2);

  console.log(`\n  ✓ 插入完成: ${result[0].cnt} 条记录，耗时 ${duration}s`);
  return result[0].cnt;
}

async function syncOrganize(conn) {
  console.log('\n========================================');
  console.log('📋 步骤4: 初始化 organize 表');
  console.log('========================================');
  console.log('数据源: init_organize 视图');
  console.log('处理: 跳过 user_id/dept_id/position_id 为空的数据\n');

  await truncateAndReset(conn, 'organize');

  const startTime = Date.now();

  await conn.execute(`
    INSERT INTO organize (user_id, dept_id, position_id)
    SELECT
      user_id,
      dept_id,
      position_id
    FROM init_organize
    WHERE user_id IS NOT NULL
      AND user_id != ''
      AND dept_id IS NOT NULL
      AND position_id IS NOT NULL
    ORDER BY user_id
  `);

  const [result] = await conn.execute('SELECT COUNT(*) as cnt FROM organize');
  const duration = ((Date.now() - startTime) / 1000).toFixed(2);

  console.log(`\n  ✓ 插入完成: ${result[0].cnt} 条记录，耗时 ${duration}s`);
  return result[0].cnt;
}

async function verifyTables(conn) {
  console.log('\n========================================');
  console.log('📊 数据验证');
  console.log('========================================\n');

  const tables = ['users', 'organize_dept', 'organize_position', 'organize'];

  for (const table of tables) {
    const [result] = await conn.execute(`SELECT COUNT(*) as cnt FROM ${table}`);
    console.log(`  ${table}: ${result[0].cnt} 条`);
  }

  // 验证 organize_dept 的 udm_org_id 和 udm_org_parent_id
  console.log('\n--- organize_dept 字段验证 ---');
  const [deptSamples] = await conn.execute(`
    SELECT dept_id, dept_name, udm_org_id, udm_org_parent_id, ancestors
    FROM organize_dept
    ORDER BY dept_id
    LIMIT 5
  `);
  console.log('udm_org_id 和 udm_org_parent_id 映射:');
  console.table(deptSamples);

  // 验证 organize_position 的 post_code
  console.log('\n--- organize_position 字段验证 ---');
  const [posSamples] = await conn.execute(`
    SELECT position_id, post_code, post_name
    FROM organize_position
    ORDER BY position_id
    LIMIT 5
  `);
  console.log('post_code (来自 init_organize_position.ID):');
  console.table(posSamples);

  // 显示 organize 表样例数据
  console.log('\n--- organize 表样例数据 ---');
  const [samples] = await conn.execute(`
    SELECT o.id, o.user_id, o.dept_id, o.position_id, u.nickname
    FROM organize o
    LEFT JOIN users u ON o.user_id = u.userid
    ORDER BY o.id
    LIMIT 10
  `);
  console.table(samples);
}

async function main() {
  console.log('╔════════════════════════════════════════╗');
  console.log('║   LumenIM 数据库核心表一键初始化脚本     ║');
  console.log('╚════════════════════════════════════════╝');
  console.log(`\n开始时间: ${new Date().toLocaleString()}`);

  const pool = mysql.createPool({
    ...DB_CONFIG,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
  });

  const conn = await pool.getConnection();
  const globalStart = Date.now();

  try {
    // 执行初始化
    await syncUsers(conn);
    await syncOrganizeDept(conn);
    await syncOrganizePosition(conn);
    await syncOrganize(conn);

    // 验证
    await verifyTables(conn);

    const totalDuration = ((Date.now() - globalStart) / 1000).toFixed(2);
    console.log('\n╔════════════════════════════════════════╗');
    console.log('║         ✅ 全部初始化完成!             ║');
    console.log('╚════════════════════════════════════════╝');
    console.log(`总耗时: ${totalDuration}s`);

  } catch (error) {
    console.error('\n❌ 初始化失败:', error.message);
    throw error;
  } finally {
    conn.release();
    await pool.end();
  }
}

main().catch(err => {
  console.error('\n❌ 错误:', err.message);
  process.exit(1);
});
