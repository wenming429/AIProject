/**
 * UDMOrganization → Organize_Dept 同步脚本 (修正版)
 * 
 * 修复内容：
 * 1. ancestors 格式修正：根节点="0"，子节点继承父节点+"自己ID"
 *    - 0级: 0
 *    - 1级: 0/1  
 *    - 2级: 0/1/2
 *    - 3级: 0/1/2/3
 * 2. 按 INNERORDER 字段对同父部门排序（整数升序）
 * 
 * 筛选条件: MASTERDATA_DATASTATUS='A', EFFECTIVESTATUS='A', PARENTID IS NULL
 */

const mysql = require('mysql2/promise');

// ==================== 配置参数 ====================
const CONFIG = {
  mysql: {
    host: process.env.MY_HOST || 'localhost',
    port: parseInt(process.env.MY_PORT || '3306'),
    user: process.env.MY_USER || 'root',
    password: process.env.MY_PASSWORD || 'wenming429',
    database: process.env.MY_DATABASE || 'go_chat',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
  },
  
  sync: {
    batchSize: 500,
    mappingTableName: '_dept_org_mapping',
    logLevel: 'info'
  }
};

// ==================== 日志工具 ====================
class Logger {
  constructor(level = 'info') {
    this.level = level;
    this.levels = { debug: 0, info: 1, warn: 2, error: 3 };
  }
  
  _log(level, message, data = null) {
    if (this.levels[level] >= this.levels[this.level]) {
      const timestamp = new Date().toISOString();
      const prefix = `[${timestamp}] [${level.toUpperCase()}]`;
      console.log(`${prefix} ${message}`);
      if (data) console.log(JSON.stringify(data, null, 2));
    }
  }
  
  debug(msg, data) { this._log('debug', msg, data); }
  info(msg, data) { this._log('info', msg, data); }
  warn(msg, data) { this._log('warn', msg, data); }
  error(msg, data) { this._log('error', msg, data); }
}

const logger = new Logger(CONFIG.sync.logLevel);

// ==================== 执行结果收集 ====================
const RESULT = {
  startTime: null,
  endTime: null,
  rootNodesCount: 0,
  totalSyncedCount: 0,
  successCount: 0,
  errorCount: 0,
  errors: [],
  steps: []
};

function addStep(name, status, details = {}) {
  RESULT.steps.push({ name, status, timestamp: new Date().toISOString(), ...details });
}

function printSummary() {
  const duration = RESULT.endTime - RESULT.startTime;
  console.log('\n' + '='.repeat(60));
  console.log('📊 同步执行结果汇总');
  console.log('='.repeat(60));
  console.log(`⏱️  执行耗时: ${(duration / 1000).toFixed(2)} 秒`);
  console.log(`🌳 根节点数量: ${RESULT.rootNodesCount} 个`);
  console.log(`📥 总处理量: ${RESULT.totalSyncedCount} 条`);
  console.log(`📤 成功写入: ${RESULT.successCount} 条`);
  console.log(`❌ 错误数量: ${RESULT.errorCount} 条`);
  console.log('\n📝 执行步骤:');
  RESULT.steps.forEach((step, i) => {
    const icon = step.status === '✅' ? '✅' : step.status === '❌' ? '❌' : '⏳';
    console.log(`   ${i + 1}. ${icon} ${step.name} - ${step.status}`);
  });
  if (RESULT.errors.length > 0) {
    console.log('\n❌ 错误详情:');
    RESULT.errors.slice(0, 10).forEach((err, i) => {
      console.log(`   ${i + 1}. ${err}`);
    });
  }
  console.log('='.repeat(60));
  return RESULT.errorCount === 0;
}

// ==================== 数据库连接 ====================
let mysqlPool = null;

async function connectMySQL() {
  logger.info('正在连接 MySQL...');
  try {
    mysqlPool = await mysql.createPool(CONFIG.mysql);
    const conn = await mysqlPool.getConnection();
    conn.release();
    logger.info('✅ MySQL 连接成功');
    return true;
  } catch (err) {
    logger.error('❌ MySQL 连接失败', { error: err.message });
    throw err;
  }
}

async function closeConnections() {
  if (mysqlPool) await mysqlPool.end();
}

// ==================== 步骤1: 递归查询所有后代节点 ====================
async function fetchAllDescendants(connection, parentId) {
  const descendants = [];
  
  // 查询直接子节点，按 INNERORDER 升序排序
  const [children] = await connection.query(`
    SELECT ID, PARENTID, FULLNAME, SHORTNAME, FULLPATHCODE, INNERORDER,
           EFFECTIVEDATE, MASTERDATA_BATCHTIME
    FROM UDMOrganization 
    WHERE PARENTID = ?
      AND MASTERDATA_DATASTATUS = 'A' 
      AND EFFECTIVESTATUS = 'A'
    ORDER BY INNERORDER ASC
  `, [parentId]);
  
  for (const child of children) {
    descendants.push(child);
    // 递归查询后代
    const grandChildren = await fetchAllDescendants(connection, child.ID);
    descendants.push(...grandChildren);
  }
  
  return descendants;
}

// ==================== 步骤2: 查询源数据 ====================
async function fetchFilteredSourceData() {
  logger.info('步骤1: 查询 udmorganization 中满足条件的数据...');
  
  const connection = await mysqlPool.getConnection();
  
  try {
    // 查询符合条件的根节点（按 INNERORDER 排序）
    const [rootNodes] = await connection.query(`
      SELECT ID, PARENTID, FULLNAME, SHORTNAME, FULLPATHCODE, INNERORDER,
             EFFECTIVEDATE, MASTERDATA_BATCHTIME
      FROM UDMOrganization 
      WHERE MASTERDATA_DATASTATUS = 'A' 
        AND EFFECTIVESTATUS = 'A' 
        AND PARENTID IS NULL
      ORDER BY INNERORDER ASC
    `);
    
    if (rootNodes.length === 0) {
      logger.warn('⚠️ 没有找到符合条件的根节点数据');
      addStep('查询源数据', '✅', { rootCount: 0, totalCount: 0 });
      connection.release();
      return { roots: [], allNodes: new Map() };
    }
    
    logger.info(`找到 ${rootNodes.length} 个符合条件的根节点`);
    RESULT.rootNodesCount = rootNodes.length;
    
    let allNodes = new Map();
    let totalCount = 0;
    
    // 收集所有根节点及其后代
    for (const root of rootNodes) {
      // 添加根节点
      allNodes.set(root.ID, { ...root, level: 0, sortOrder: root.INNERORDER || 0 });
      totalCount++;
      
      // 递归获取所有后代（已按 INNERORDER 排序）
      const descendants = await fetchAllDescendants(connection, root.ID);
      
      // 为每个后代设置层级（通过 FULLPATHCODE 计算）
      for (const node of descendants) {
        const level = (node.FULLPATHCODE.match(/\w/g) || []).length > 0 
          ? (node.FULLPATHCODE.split('||').length - 1)
          : 0;
        allNodes.set(node.ID, { ...node, level, sortOrder: node.INNERORDER || 0 });
        totalCount++;
      }
    }
    
    RESULT.totalSyncedCount = totalCount;
    logger.info(`总共生效 ${totalCount} 条数据`);
    
    addStep('查询源数据', '✅', { rootCount: rootNodes.length, totalCount });
    connection.release();
    
    return { roots: rootNodes, allNodes };
    
  } catch (err) {
    logger.error('查询源数据失败', { error: err.message });
    addStep('查询源数据', '❌', { error: err.message });
    connection.release();
    throw err;
  }
}

// ==================== 步骤3: 创建映射表 ====================
async function createMappingTable() {
  const tableName = CONFIG.sync.mappingTableName;
  logger.info(`步骤2: 创建映射表 ${tableName}...`);
  
  try {
    await mysqlPool.query(`DROP TABLE IF EXISTS \`${tableName}\``);
    await mysqlPool.query(`
      CREATE TABLE IF NOT EXISTS \`${tableName}\` (
        \`source_id\`        VARCHAR(38) NOT NULL,
        \`target_id\`        INT UNSIGNED NOT NULL,
        \`source_parent_id\` VARCHAR(38) DEFAULT NULL,
        \`target_parent_id\` INT UNSIGNED DEFAULT 0,
        \`ancestors\`        VARCHAR(500) DEFAULT NULL,
        \`level\`            INT UNSIGNED DEFAULT 0,
        \`sort_order\`       DOUBLE DEFAULT 0,
        PRIMARY KEY (\`source_id\`),
        KEY \`idx_target_id\` (\`target_id\`),
        KEY \`idx_parent\` (\`source_parent_id\`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    `);
    logger.info('✅ 映射表创建成功');
    addStep('创建映射表', '✅');
    return true;
  } catch (err) {
    logger.error('创建映射表失败', { error: err.message });
    addStep('创建映射表', '❌', { error: err.message });
    return false;
  }
}

// ==================== 步骤4: 清空并重置目标表 ====================
async function truncateAndResetTarget() {
  logger.info('步骤3: 清空 organize_dept 表并重置自增 ID...');
  
  const connection = await mysqlPool.getConnection();
  
  try {
    await connection.beginTransaction();
    await connection.query('DELETE FROM organize_dept');
    await connection.query('ALTER TABLE organize_dept AUTO_INCREMENT = 1');
    await connection.commit();
    logger.info('✅ 目标表已清空并重置');
    addStep('清空目标表', '✅');
    return true;
  } catch (err) {
    await connection.rollback();
    logger.error('清空目标表失败', { error: err.message });
    addStep('清空目标表', '❌', { error: err.message });
    return false;
  } finally {
    connection.release();
  }
}

// ==================== 步骤5: 构建树结构并分配 ID ====================
function buildTreeAndAssignIds(roots, allNodes) {
  logger.info('步骤4: 构建树结构并分配 dept_id（按 INNERORDER 排序）...');
  
  // 构建 parentId -> children 的映射
  const childrenMap = new Map();  // parentId -> [childId, childId, ...]
  
  for (const [id, node] of allNodes) {
    const parentId = node.PARENTID || 'ROOT';
    if (!childrenMap.has(parentId)) {
      childrenMap.set(parentId, []);
    }
    childrenMap.get(parentId).push(id);
  }
  
  // 验证根节点顺序
  const rootIds = roots.map(r => r.ID);
  logger.info(`根节点顺序: ${rootIds.join(', ')}`);
  
  // 按 INNERORDER 排序根节点下的子节点
  for (const [parentId, childIds] of childrenMap) {
    if (parentId === 'ROOT') continue;
    childIds.sort((a, b) => {
      const nodeA = allNodes.get(a);
      const nodeB = allNodes.get(b);
      return (nodeA.INNERORDER || 0) - (nodeB.INNERORDER || 0);
    });
  }
  
  // 分配 target_id（深度优先，按 INNERORDER 顺序）
  const nodeMap = new Map();  // sourceId -> { ...node, targetId, ancestors }
  let targetId = 1;
  
  // 递归分配 ID
  function assignIds(parentId, ancestorsStr) {
    // 获取该父节点的所有子节点（已排序）
    const childIds = childrenMap.get(parentId) || [];
    
    for (const childId of childIds) {
      const node = allNodes.get(childId);
      
      // 构建 ancestors：父节点的 ancestors + 父节点的 targetId
      // 根节点的 ancestors = "0"
      // 子节点的 ancestors = 父节点 ancestors + "/" + 父节点 targetId
      let ancestors;
      if (parentId === 'ROOT') {
        ancestors = '0';  // 根节点
      } else {
        const parentNode = nodeMap.get(parentId);
        ancestors = parentNode ? `${parentNode.ancestors}/${parentNode.targetId}` : '0';
      }
      
      nodeMap.set(childId, {
        ...node,
        targetId: targetId++,
        ancestors: ancestors,
        level: ancestors.split('/').length - 1  // 计算层级
      });
      
      // 递归处理子节点
      assignIds(childId, ancestors);
    }
  }
  
  // 从根节点开始分配
  for (const root of roots) {
    // 根节点的 ancestors = "0"
    nodeMap.set(root.ID, {
      ...root,
      targetId: targetId++,
      ancestors: '0',
      level: 0
    });
    
    // 递归分配子节点
    assignIds(root.ID, '0');
  }
  
  logger.info(`✅ 分配完成，共 ${nodeMap.size} 个节点`);
  
  // 验证 ancestors 格式
  let levelCounts = {};
  for (const [id, node] of nodeMap) {
    const level = node.ancestors.split('/').length - 1;
    levelCounts[level] = (levelCounts[level] || 0) + 1;
  }
  logger.info('层级分布:', levelCounts);
  
  addStep('构建树结构', '✅', { nodeCount: nodeMap.size });
  
  return nodeMap;
}

// ==================== 步骤6: 批量插入数据 ====================
async function batchInsertData(nodeMap, isDryRun) {
  logger.info(`步骤5: 插入数据到 organize_dept 表...${isDryRun ? '(模拟运行)' : ''}`);
  
  if (isDryRun) {
    RESULT.successCount = nodeMap.size;
    addStep('插入数据', '✅', { count: nodeMap.size, dryRun: true });
    return true;
  }
  
  const connection = await mysqlPool.getConnection();
  
  try {
    await connection.beginTransaction();
    
    // 按 ancestors 路径排序（确保父节点先插入）
    const sortedNodes = Array.from(nodeMap.values())
      .sort((a, b) => {
        // 首先按 ancestors 长度（层级）排序
        const levelA = a.ancestors.split('/').length;
        const levelB = b.ancestors.split('/').length;
        if (levelA !== levelB) return levelA - levelB;
        
        // 同层级按 ancestors 字典序排序
        return a.ancestors.localeCompare(b.ancestors);
      });
    
    const batchSize = CONFIG.sync.batchSize;
    let totalInserted = 0;
    const batchData = [];
    
    for (const node of sortedNodes) {
      // 计算 parent_id
      let parentTargetId = 0;
      if (node.PARENTID && nodeMap.has(node.PARENTID)) {
        parentTargetId = nodeMap.get(node.PARENTID).targetId || 0;
      }
      
      // 状态：EFFECTIVESTATUS='A' -> status=1 (正常)
      const status = 1;
      
      // 使用 INNERORDER 作为 order_num（转为整数）
      let orderNum = parseInt(node.INNERORDER) || 0;
      // 如果 order_num 太大或为0，使用序号
      if (orderNum > 10000000 || orderNum === 0) {
        orderNum = node.targetId * 10;  // 按 dept_id 分配序号
      }
      
      batchData.push([
        parentTargetId,                    // parent_id
        node.ancestors,                    // ancestors (格式: 0, 0/1, 0/1/2, 0/1/2/3)
        node.FULLNAME || '',              // dept_name
        orderNum,                         // order_num (整数)
        '',                               // leader
        '',                               // phone
        '',                               // email
        status,                           // status
        1,                                // is_deleted (1=否)
        node.ID,                          // udm_org_id
        node.PARENTID || null,           // udm_org_parent_id
        node.EFFECTIVEDATE || new Date(), // created_at
        node.MASTERDATA_BATCHTIME || new Date() // updated_at
      ]);
      
      if (batchData.length >= batchSize) {
        await executeBatchInsert(connection, batchData);
        totalInserted += batchData.length;
        batchData.length = 0;
      }
    }
    
    if (batchData.length > 0) {
      await executeBatchInsert(connection, batchData);
      totalInserted += batchData.length;
    }
    
    // 写入映射表
    const mappingData = [];
    for (const [id, node] of nodeMap) {
      mappingData.push([
        id,
        node.targetId,
        node.PARENTID || null,
        node.PARENTID && nodeMap.has(node.PARENTID) ? nodeMap.get(node.PARENTID).targetId : 0,
        node.ancestors,
        node.level || 0,
        node.INNERORDER || 0
      ]);
    }
    
    await connection.query(`
      INSERT INTO \`${CONFIG.sync.mappingTableName}\`
      (source_id, target_id, source_parent_id, target_parent_id, ancestors, level, sort_order)
      VALUES ?
    `, [mappingData]);
    
    await connection.commit();
    
    RESULT.successCount = totalInserted;
    logger.info(`✅ 数据插入完成: ${totalInserted} 条`);
    addStep('插入数据', '✅', { count: totalInserted });
    return true;
    
  } catch (err) {
    await connection.rollback();
    logger.error('插入数据失败', { error: err.message });
    RESULT.errors.push(err.message);
    RESULT.errorCount++;
    addStep('插入数据', '❌', { error: err.message });
    return false;
  } finally {
    connection.release();
  }
}

async function executeBatchInsert(connection, batchData) {
  await connection.query(`
    INSERT INTO organize_dept (
      parent_id, ancestors, dept_name, order_num,
      leader, phone, email, status, is_deleted,
      udm_org_id, udm_org_parent_id, created_at, updated_at
    ) VALUES ?
  `, [batchData]);
}

// ==================== 步骤7: 验证结果 ====================
async function validateResult() {
  logger.info('步骤6: 验证同步结果...');
  
  try {
    const [countResult] = await mysqlPool.query('SELECT COUNT(*) as cnt FROM organize_dept');
    logger.info(`目标表数据量: ${countResult[0].cnt}`);
    
    const [rootCount] = await mysqlPool.query('SELECT COUNT(*) as cnt FROM organize_dept WHERE parent_id = 0');
    logger.info(`根节点数量: ${rootCount[0].cnt}`);
    
    // 检查层级分布
    const [levelStats] = await mysqlPool.query(`
      SELECT 
        LENGTH(ancestors) - LENGTH(REPLACE(ancestors, '/', '')) as level,
        COUNT(*) as cnt
      FROM organize_dept
      GROUP BY level
      ORDER BY level
    `);
    
    console.log('\n📊 层级分布:');
    console.log('┌────────┬──────────┐');
    console.log('│  层级  │   数量   │');
    console.log('├────────┼──────────┤');
    levelStats.forEach(row => {
      console.log(`│   ${row.level}级   │   ${String(row.cnt).padStart(4)}    │`);
    });
    console.log('└────────┴──────────┘');
    
    // 验证 ancestors 格式
    const [formatCheck] = await mysqlPool.query(`
      SELECT 
        SUM(CASE WHEN ancestors REGEXP '^0(/[0-9]+)*$' THEN 1 ELSE 0 END) as valid,
        SUM(CASE WHEN ancestors NOT REGEXP '^0(/[0-9]+)*$' THEN 1 ELSE 0 END) as invalid
      FROM organize_dept
    `);
    logger.info(`格式验证: 有效 ${formatCheck[0].valid}, 无效 ${formatCheck[0].invalid}`);
    
    // 抽样检查根节点及子节点
    console.log('\n📋 根节点及第1级子节点抽样:');
    const [samples] = await mysqlPool.query(`
      SELECT dept_id, dept_name, parent_id, ancestors, order_num
      FROM organize_dept
      WHERE parent_id = 0 OR ancestors LIKE '0/%'
      ORDER BY parent_id, order_num
      LIMIT 15
    `);
    samples.forEach(row => {
      const indent = row.parent_id === 0 ? '' : '  └─ ';
      console.log(`  ${indent}[${row.dept_id}] ${row.dept_name} (ancestors: ${row.ancestors}, order: ${row.order_num})`);
    });
    
    // 验证排序
    console.log('\n📋 同父节点排序验证 (第2级):');
    const [sortCheck] = await mysqlPool.query(`
      SELECT d1.dept_id as parent_id, d1.dept_name as parent_name,
             d2.dept_id, d2.dept_name, d2.order_num
      FROM organize_dept d1
      JOIN organize_dept d2 ON d2.parent_id = d1.dept_id
      WHERE d1.parent_id IN (SELECT dept_id FROM organize_dept WHERE parent_id = 0 LIMIT 1)
      ORDER BY d2.parent_id, d2.order_num
      LIMIT 10
    `);
    sortCheck.forEach(row => {
      console.log(`  ${row.parent_name} → [${row.dept_id}] ${row.dept_name} (order_num: ${row.order_num})`);
    });
    
    addStep('验证结果', '✅', { totalCount: countResult[0].cnt, rootCount: rootCount[0].cnt });
    return true;
    
  } catch (err) {
    logger.error('验证失败', { error: err.message });
    addStep('验证结果', '❌', { error: err.message });
    return false;
  }
}

// ==================== 主执行流程 ====================
async function main() {
  console.log('\n' + '='.repeat(60));
  console.log('🏢 UDMOrganization → Organize_Dept 同步程序 (修正版)');
  console.log('筛选: MASTERDATA_DATASTATUS=A, EFFECTIVESTATUS=A, PARENTID IS NULL');
  console.log('排序: 按 INNERORDER 升序 | ancestors 格式: 0/1/2/3');
  console.log('='.repeat(60) + '\n');
  
  const args = process.argv.slice(2);
  const isDryRun = args.includes('--dry-run');
  
  if (isDryRun) logger.warn('⚠️ 模拟运行模式');
  
  RESULT.startTime = Date.now();
  
  try {
    console.log('\n📡 阶段1: 数据库连接...\n');
    await connectMySQL();
    
    console.log('\n🔍 阶段2: 查询源数据...\n');
    const { roots, allNodes } = await fetchFilteredSourceData();
    
    if (roots.length === 0) {
      logger.warn('没有符合条件的数据，退出');
      RESULT.endTime = Date.now();
      printSummary();
      process.exit(0);
    }
    
    console.log('\n🗄️ 阶段3: 准备同步环境...\n');
    await createMappingTable();
    await truncateAndResetTarget();
    
    console.log('\n🌳 阶段4: 构建树结构...\n');
    const nodeMap = buildTreeAndAssignIds(roots, allNodes);
    
    console.log('\n📥 阶段5: 插入数据...\n');
    await batchInsertData(nodeMap, isDryRun);
    
    console.log('\n✅ 阶段6: 验证结果...\n');
    await validateResult();
    
    RESULT.endTime = Date.now();
    
    const success = printSummary();
    console.log(success ? '\n🎉 同步任务完成！\n' : '\n⚠️ 同步任务完成，但存在错误。\n');
    process.exit(success ? 0 : 1);
    
  } catch (err) {
    RESULT.endTime = Date.now();
    logger.error('同步失败', { error: err.message, stack: err.stack });
    addStep('主流程', '❌', { error: err.message });
    printSummary();
    process.exit(1);
  } finally {
    await closeConnections();
  }
}

main().catch(err => {
  console.error('未捕获的异常:', err);
  process.exit(1);
});
