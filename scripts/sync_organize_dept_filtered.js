/**
 * UDMOrganization → Organize_Dept 同步脚本 (按条件筛选+递归处理)
 * 
 * 功能：基于 udmorganization 表中满足以下条件的根节点数据初始化 organize_dept 表
 *   条件: MASTERDATA_DATASTATUS='A', EFFECTIVESTATUS='A', PARENTID IS NULL
 * 
 * 特点：
 *   1. 仅同步满足条件的根节点及其所有后代节点
 *   2. ID 映射为 udm_org_id，PARENTID 映射为 udm_org_parent_id
 *   3. 递归处理父子层级关系
 *   4. 构建 ancestors 祖级字段 (格式: "0/1/2/3")
 *   5. 初始化前清空 organize_dept 表并重置自增 ID
 * 
 * 使用方法：
 *   node sync_organize_dept_filtered.js [--dry-run]
 *     --dry-run : 仅模拟执行，不写入数据库
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
  
  // 同步配置
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
    if (RESULT.errors.length > 10) {
      console.log(`   ... 还有 ${RESULT.errors.length - 10} 条错误`);
    }
  }
  console.log('='.repeat(60));
  return RESULT.errorCount === 0;
}

// ==================== 数据库连接 ====================
let mysqlPool = null;

async function connectMySQL() {
  logger.info('正在连接 MySQL...', {
    host: CONFIG.mysql.host,
    database: CONFIG.mysql.database
  });
  
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
  if (mysqlPool) {
    await mysqlPool.end();
    logger.debug('MySQL 连接池已关闭');
  }
}

// ==================== 步骤1: 查询符合条件的数据 ====================
async function fetchFilteredSourceData() {
  logger.info('步骤1: 查询 udmorganization 中满足条件的数据...');
  
  const connection = await mysqlPool.getConnection();
  
  try {
    // 查询符合筛选条件的根节点
    const rootQuery = `
      SELECT ID, PARENTID, FULLNAME, SHORTNAME, FULLPATHCODE, INNERORDER,
             EFFECTIVEDATE, MASTERDATA_BATCHTIME
      FROM UDMOrganization 
      WHERE MASTERDATA_DATASTATUS = 'A' 
        AND EFFECTIVESTATUS = 'A' 
        AND PARENTID IS NULL
    `;
    
    const [rootNodes] = await connection.query(rootQuery);
    
    if (rootNodes.length === 0) {
      logger.warn('⚠️ 没有找到符合条件的根节点数据');
      addStep('查询源数据', '✅', { rootCount: 0, totalCount: 0 });
      connection.release();
      return { roots: [], allNodes: new Map() };
    }
    
    logger.info(`找到 ${rootNodes.length} 个符合条件的根节点`);
    RESULT.rootNodesCount = rootNodes.length;
    
    // 获取所有根节点的 ID
    const rootIds = rootNodes.map(r => r.ID);
    
    // 查询所有后代节点（使用 FULLPATHCODE 前缀匹配）
    // 对于每个根节点，查询其 FULLPATHCODE 作为前缀的所有子节点
    let allNodes = new Map();
    let totalCount = 0;
    
    for (const root of rootNodes) {
      // 查询根节点本身
      allNodes.set(root.ID, {
        ...root,
        isRoot: true
      });
      totalCount++;
      
      // 使用递归查询后代节点
      const descendants = await fetchDescendants(connection, root.ID, root.FULLPATHCODE);
      for (const node of descendants) {
        allNodes.set(node.ID, {
          ...node,
          isRoot: false
        });
        totalCount++;
      }
    }
    
    RESULT.totalSyncedCount = totalCount;
    logger.info(`总共生效 ${totalCount} 条数据（包括根节点和后代）`);
    
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

/**
 * 递归查询后代节点
 */
async function fetchDescendants(connection, parentId, parentPath) {
  const descendants = [];
  
  // 查询直接子节点
  const childQuery = `
    SELECT ID, PARENTID, FULLNAME, SHORTNAME, FULLPATHCODE, INNERORDER,
           EFFECTIVEDATE, MASTERDATA_BATCHTIME
    FROM UDMOrganization 
    WHERE PARENTID = ?
      AND MASTERDATA_DATASTATUS = 'A' 
      AND EFFECTIVESTATUS = 'A'
  `;
  
  const [children] = await connection.query(childQuery, [parentId]);
  
  for (const child of children) {
    descendants.push(child);
    // 递归查询当前子节点的子节点
    const grandChildren = await fetchDescendants(connection, child.ID, child.FULLPATHCODE);
    descendants.push(...grandChildren);
  }
  
  return descendants;
}

// ==================== 步骤2: 创建映射表 ====================
async function createMappingTable() {
  const tableName = CONFIG.sync.mappingTableName;
  logger.info(`步骤2: 创建/重建映射表 ${tableName}...`);
  
  const createSQL = `
    CREATE TABLE IF NOT EXISTS \`${tableName}\` (
      \`source_id\`        VARCHAR(38) NOT NULL COMMENT 'UDM Organization ID',
      \`target_id\`        INT UNSIGNED NOT NULL COMMENT 'Organize_Dept dept_id',
      \`source_parent_id\` VARCHAR(38) DEFAULT NULL COMMENT 'UDM Parent ID',
      \`target_parent_id\` INT UNSIGNED DEFAULT 0 COMMENT '目标 parent_id',
      \`ancestors\`        VARCHAR(500) DEFAULT NULL COMMENT 'ancestors 路径',
      \`level\`            INT UNSIGNED DEFAULT 0 COMMENT '层级深度',
      \`created_at\`      DATETIME DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (\`source_id\`),
      KEY \`idx_target_id\` (\`target_id\`),
      KEY \`idx_parent\` (\`source_parent_id\`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  `;
  
  try {
    await mysqlPool.query(`DROP TABLE IF EXISTS \`${tableName}\``);
    await mysqlPool.query(createSQL);
    logger.info(`✅ 映射表 ${tableName} 创建成功`);
    addStep('创建映射表', '✅');
    return true;
  } catch (err) {
    logger.error('创建映射表失败', { error: err.message });
    addStep('创建映射表', '❌', { error: err.message });
    return false;
  }
}

// ==================== 步骤3: 清空并重置目标表 ====================
async function truncateAndResetTarget() {
  logger.info('步骤3: 清空 organize_dept 表并重置自增 ID...');
  
  const connection = await mysqlPool.getConnection();
  
  try {
    await connection.beginTransaction();
    
    // 清空目标表
    await connection.query('DELETE FROM organize_dept');
    logger.debug('已清空 organize_dept 表');
    
    // 重置自增 ID
    await connection.query('ALTER TABLE organize_dept AUTO_INCREMENT = 1');
    logger.debug('已重置 organize_dept 自增 ID');
    
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

// ==================== 步骤4: 构建树结构并分配 ID ====================
function buildTreeAndAssignIds(roots, allNodes) {
  logger.info('步骤4: 构建树结构并分配 dept_id...');
  
  // 构建 ID → 节点 的映射
  const nodeMap = new Map();
  
  // 第一遍：分配 target_id（按处理顺序）
  let targetId = 1;
  
  // 处理根节点
  for (const root of roots) {
    const node = allNodes.get(root.ID);
    nodeMap.set(root.ID, {
      ...node,
      targetId: targetId++,
      level: 0
    });
  }
  
  // 处理后代节点 - 递归分配
  for (const root of roots) {
    assignChildIds(root.ID, nodeMap, allNodes, targetId);
  }
  
  // 计算 ancestors（需要第二次遍历）
  for (const [id, node] of nodeMap) {
    const ancestors = calculateAncestors(id, nodeMap);
    node.ancestors = ancestors;
  }
  
  logger.info(`✅ 分配完成，共 ${nodeMap.size} 个节点`);
  addStep('构建树结构', '✅', { nodeCount: nodeMap.size });
  
  return nodeMap;
}

function assignChildIds(parentId, nodeMap, allNodes, idCounter) {
  // 查找所有子节点
  for (const [id, node] of allNodes) {
    if (node.PARENTID === parentId && !nodeMap.has(id)) {
      const parentNode = nodeMap.get(parentId);
      nodeMap.set(id, {
        ...node,
        targetId: idCounter++,
        level: parentNode.level + 1
      });
      // 递归处理子节点
      assignChildIds(id, nodeMap, allNodes, idCounter);
    }
  }
}

/**
 * 计算 ancestors 路径
 * 递归向上查找父节点，构建形如 "0/1/2/3" 的路径
 */
function calculateAncestors(nodeId, nodeMap) {
  const ancestors = [0];  // 根节点从 0 开始
  
  let currentId = nodeId;
  const visited = new Set();
  
  while (currentId) {
    if (visited.has(currentId)) break;  // 防止循环引用
    visited.add(currentId);
    
    const node = nodeMap.get(currentId);
    if (!node) break;
    
    if (node.targetId) {
      ancestors.push(node.targetId);
    }
    
    if (!node.PARENTID) break;
    currentId = node.PARENTID;
  }
  
  return ancestors.join('/');
}

// ==================== 步骤5: 批量插入数据 ====================
async function batchInsertData(nodeMap, isDryRun) {
  logger.info(`步骤5: 插入数据到 organize_dept 表...${isDryRun ? '(模拟运行)' : ''}`);
  
  if (isDryRun) {
    logger.info('模拟运行模式，跳过实际插入');
    RESULT.successCount = nodeMap.size;
    addStep('插入数据', '✅', { count: nodeMap.size, dryRun: true });
    return true;
  }
  
  const connection = await mysqlPool.getConnection();
  
  try {
    await connection.beginTransaction();
    
    const batchSize = CONFIG.sync.batchSize;
    let batchCount = 0;
    let totalInserted = 0;
    const batchData = [];
    
    // 按 targetId 排序插入
    const sortedNodes = Array.from(nodeMap.values())
      .filter(n => n.targetId !== undefined)
      .sort((a, b) => a.targetId - b.targetId);
    
    for (const node of sortedNodes) {
      // 计算 parent_id
      let parentTargetId = 0;
      if (node.PARENTID && nodeMap.has(node.PARENTID)) {
        parentTargetId = nodeMap.get(node.PARENTID).targetId || 0;
      }
      
      // 计算状态
      const status = node.EFFECTIVESTATUS === 'A' ? 1 : 2;
      
      batchData.push([
        parentTargetId,                    // parent_id
        node.ancestors || '0',           // ancestors
        node.FULLNAME || '',              // dept_name
        1,                                // order_num (使用默认值)
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
        batchCount++;
        logger.debug(`已处理第 ${batchCount} 批，${batchData.length} 条`);
        batchData.length = 0;
      }
    }
    
    // 处理剩余数据
    if (batchData.length > 0) {
      await executeBatchInsert(connection, batchData);
      totalInserted += batchData.length;
      batchCount++;
    }
    
    // 写入映射表
    const mappingData = [];
    for (const [id, node] of nodeMap) {
      mappingData.push([
        id,
        node.targetId,
        node.PARENTID || null,
        node.targetId === 0 ? 0 : (nodeMap.get(node.PARENTID)?.targetId || 0),
        node.ancestors,
        node.level || 0
      ]);
    }
    
    if (mappingData.length > 0) {
      await connection.query(`
        INSERT INTO \`${CONFIG.sync.mappingTableName}\`
        (source_id, target_id, source_parent_id, target_parent_id, ancestors, level)
        VALUES ?
      `, [mappingData]);
      logger.info(`已写入 ${mappingData.length} 条映射记录`);
    }
    
    await connection.commit();
    
    RESULT.successCount = totalInserted;
    logger.info(`✅ 数据插入完成: ${totalInserted} 条记录`);
    addStep('插入数据', '✅', { count: totalInserted, batches: batchCount });
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
  const insertSQL = `
    INSERT INTO organize_dept (
      parent_id, ancestors, dept_name, order_num,
      leader, phone, email, status, is_deleted,
      udm_org_id, udm_org_parent_id, created_at, updated_at
    ) VALUES ?
  `;
  await connection.query(insertSQL, [batchData]);
}

// ==================== 步骤6: 验证结果 ====================
async function validateResult() {
  logger.info('步骤6: 验证同步结果...');
  
  try {
    // 检查数据量
    const [countResult] = await mysqlPool.query(
      'SELECT COUNT(*) as cnt FROM organize_dept'
    );
    logger.info(`目标表数据量: ${countResult[0].cnt}`);
    
    // 检查根节点数量
    const [rootCount] = await mysqlPool.query(
      'SELECT COUNT(*) as cnt FROM organize_dept WHERE parent_id = 0'
    );
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
    
    logger.info('层级分布:');
    levelStats.forEach(row => {
      logger.info(`  层级 ${row.level}: ${row.cnt} 个部门`);
    });
    
    // 抽样检查
    const [samples] = await mysqlPool.query(`
      SELECT dept_id, dept_name, parent_id, ancestors, udm_org_id, udm_org_parent_id
      FROM organize_dept
      WHERE parent_id = 0
      LIMIT 5
    `);
    
    logger.info('根节点抽样:');
    samples.forEach(row => {
      logger.info(`  [${row.dept_id}] ${row.dept_name}`);
      logger.info(`      ancestors: ${row.ancestors}`);
      logger.info(`      udm_org_id: ${row.udm_org_id}`);
    });
    
    addStep('验证结果', '✅', {
      totalCount: countResult[0].cnt,
      rootCount: rootCount[0].cnt
    });
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
  console.log('🏢 UDMOrganization → Organize_Dept 同步程序');
  console.log('筛选条件: MASTERDATA_DATASTATUS=A, EFFECTIVESTATUS=A, PARENTID IS NULL');
  console.log('='.repeat(60) + '\n');
  
  // 解析命令行参数
  const args = process.argv.slice(2);
  const isDryRun = args.includes('--dry-run');
  
  if (isDryRun) {
    logger.warn('⚠️ 模拟运行模式: 不会写入数据库');
  }
  
  RESULT.startTime = Date.now();
  
  try {
    // ========== 阶段1: 数据库连接 ==========
    console.log('\n📡 阶段1: 数据库连接...\n');
    await connectMySQL();
    
    // ========== 阶段2: 查询源数据 ==========
    console.log('\n🔍 阶段2: 查询源数据...\n');
    const { roots, allNodes } = await fetchFilteredSourceData();
    
    if (roots.length === 0) {
      logger.warn('没有符合条件的数据，退出');
      RESULT.endTime = Date.now();
      printSummary();
      process.exit(0);
    }
    
    // ========== 阶段3: 准备同步环境 ==========
    console.log('\n🗄️ 阶段3: 准备同步环境...\n');
    await createMappingTable();
    await truncateAndResetTarget();
    
    // ========== 阶段4: 构建树结构 ==========
    console.log('\n🌳 阶段4: 构建树结构...\n');
    const nodeMap = buildTreeAndAssignIds(roots, allNodes);
    
    // ========== 阶段5: 插入数据 ==========
    console.log('\n📥 阶段5: 插入数据...\n');
    await batchInsertData(nodeMap, isDryRun);
    
    // ========== 阶段6: 验证结果 ==========
    console.log('\n✅ 阶段6: 验证结果...\n');
    await validateResult();
    
    RESULT.endTime = Date.now();
    
    // ========== 最终结果 ==========
    console.log('\n');
    const success = printSummary();
    
    if (success) {
      console.log('🎉 同步任务完成！\n');
      process.exit(0);
    } else {
      console.log('⚠️ 同步任务完成，但存在一些错误。\n');
      process.exit(1);
    }
    
  } catch (err) {
    RESULT.endTime = Date.now();
    logger.error('同步过程发生错误', { error: err.message, stack: err.stack });
    addStep('主流程', '❌', { error: err.message });
    printSummary();
    process.exit(1);
  } finally {
    await closeConnections();
  }
}

// 执行入口
main().catch(err => {
  console.error('未捕获的异常:', err);
  process.exit(1);
});
