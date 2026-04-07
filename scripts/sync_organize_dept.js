/**
 * UDMOrganization → Organize_Dept 数据同步脚本 (MySQL Only Version)
 * 
 * 功能：同步已存在于 MySQL go_chat 库中的 UDMOrganization 表到 organize_dept 表
 * 特点：
 *   1. 直接从 MySQL 读取 UDMOrganization（无需 SQL Server 连接）
 *   2. GUID → INT ID 映射关系表
 *   3. 自动处理父子层级关系
 *   4. 支持增量同步和全量同步
 *   5. 完整的执行日志和错误处理
 * 
 * 使用方法：
 *   node sync_organize_dept.js [--full] [--dry-run]
 *     --full    : 执行全量同步（先清空目标表）
 *     --dry-run : 仅模拟执行，不写入数据库
 */

const mysql = require('mysql2/promise');

// ==================== 配置参数 ====================
const CONFIG = {
  // MySQL 配置（源和目标都在 MySQL）
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
    batchSize: 1000,                    // 每批处理数量
    mappingTableName: '_dept_id_mapping',  // ID映射表名
    logLevel: 'info'                   // 日志级别: debug, info, warn, error
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
  sourceCount: 0,
  targetCount: 0,
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
  console.log(`📥 源数据量: ${RESULT.sourceCount} 条`);
  console.log(`📤 目标写入: ${RESULT.successCount} 条`);
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

// ==================== 工具函数: 格式化日期 ====================
function formatDate(date, format = 'yyyyMMdd_HHmmss') {
  const pad = (n) => String(n).padStart(2, '0');
  return format
    .replace('yyyy', date.getFullYear())
    .replace('MM', pad(date.getMonth() + 1))
    .replace('dd', pad(date.getDate()))
    .replace('HH', pad(date.getHours()))
    .replace('mm', pad(date.getMinutes()))
    .replace('ss', pad(date.getSeconds()));
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
    // 测试连接
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

// ==================== 步骤1: 查询源表结构 ====================
async function checkSourceTableStructure() {
  logger.info('步骤1: 检查 UDMOrganization 源表结构...');
  
  try {
    // 检查源表是否存在
    const [tables] = await mysqlPool.query(`
      SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
      WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'UDMOrganization'
    `, [CONFIG.mysql.database]);
    
    if (tables.length === 0) {
      throw new Error('UDMOrganization 表不存在！请先同步数据到 MySQL。');
    }
    
    // 查询源表数据量
    const [countResult] = await mysqlPool.query(`
      SELECT COUNT(*) as total FROM UDMOrganization
    `);
    RESULT.sourceCount = countResult[0].total;
    logger.info(`源表数据量: ${RESULT.sourceCount} 条`);
    
    // 查询字段信息
    const [columns] = await mysqlPool.query(`
      SHOW FULL COLUMNS FROM UDMOrganization
    `);
    
    logger.info('源表字段列表:');
    columns.forEach(col => {
      logger.debug(`  - ${col.Field}: ${col.Type}`);
    });
    
    addStep('检查源表结构', '✅', { rowCount: RESULT.sourceCount });
    return true;
  } catch (err) {
    logger.error('检查源表结构失败', { error: err.message });
    addStep('检查源表结构', '❌', { error: err.message });
    return false;
  }
}

// ==================== 步骤2: 检查目标表结构 ====================
async function checkTargetTableStructure() {
  logger.info('步骤2: 检查 organize_dept 目标表结构...');
  
  try {
    const [columns] = await mysqlPool.query(`
      SHOW FULL COLUMNS FROM organize_dept
    `);
    
    logger.info('目标表字段列表:');
    columns.forEach(col => {
      logger.debug(`  - ${col.Field}: ${col.Type} (${col.Null === 'YES' ? 'NULL' : 'NOT NULL'})`);
    });
    
    addStep('检查目标表结构', '✅');
    return true;
  } catch (err) {
    logger.error('检查目标表结构失败', { error: err.message });
    addStep('检查目标表结构', '❌', { error: err.message });
    return false;
  }
}

// ==================== 步骤3: 备份目标表 ====================
async function backupTargetTables() {
  const timestamp = formatDate(new Date());
  const backupSuffix = `_backup_${timestamp}`;
  
  logger.info(`步骤3: 备份目标表...`);
  
  const connection = await mysqlPool.getConnection();
  
  try {
    await connection.beginTransaction();
    
    // 检查目标表是否有数据
    const [dataCount] = await connection.query('SELECT COUNT(*) as cnt FROM organize_dept');
    
    if (dataCount[0].cnt === 0) {
      logger.info('目标表为空，跳过备份');
      await connection.commit();
      connection.release();
      return { backedUp: false, reason: 'empty_table' };
    }
    
    // 创建备份表（包含数据和结构）
    const backupMappingTable = CONFIG.sync.mappingTableName + backupSuffix;
    
    // 1. 备份 organize_dept 表
    await connection.query(`
      CREATE TABLE IF NOT EXISTS \`organize_dept${backupSuffix}\` 
      SELECT * FROM organize_dept
    `);
    logger.info(`✅ 已备份 organize_dept 表 → organize_dept${backupSuffix}`);
    logger.info(`   备份数据量: ${dataCount[0].cnt} 条`);
    
    // 2. 备份映射表（如果存在）
    try {
      const [mappingCount] = await connection.query(`
        SELECT COUNT(*) as cnt FROM \`${CONFIG.sync.mappingTableName}\`
      `);
      
      if (mappingCount[0].cnt > 0) {
        await connection.query(`
          CREATE TABLE IF NOT EXISTS \`${backupMappingTable}\` 
          SELECT * FROM \`${CONFIG.sync.mappingTableName}\`
        `);
        logger.info(`✅ 已备份映射表 → ${backupMappingTable}`);
      }
    } catch (e) {
      // 映射表可能不存在
    }
    
    // 3. 记录备份信息到备份日志表
    await connection.query(`
      CREATE TABLE IF NOT EXISTS _backup_history (
        id INT AUTO_INCREMENT PRIMARY KEY,
        table_name VARCHAR(64) NOT NULL,
        backup_table_name VARCHAR(128) NOT NULL,
        row_count INT DEFAULT 0,
        backup_time DATETIME DEFAULT CURRENT_TIMESTAMP,
        note VARCHAR(255) DEFAULT '',
        INDEX idx_backup_time (backup_time)
      )
    `);
    
    await connection.query(`
      INSERT INTO _backup_history (table_name, backup_table_name, row_count, note)
      VALUES ('organize_dept', 'organize_dept${backupSuffix}', ?, '全量同步前备份')
    `, [dataCount[0].cnt]);
    
    await connection.commit();
    logger.info('✅ 备份记录已写入 _backup_history 表');
    
    connection.release();
    return { backedUp: true, backupSuffix, rowCount: dataCount[0].cnt };
    
  } catch (err) {
    await connection.rollback();
    logger.error('备份目标表失败', { error: err.message });
    throw err;
  } finally {
    connection.release();
  }
}

// ==================== 步骤4: 创建ID映射表 ====================
async function createIdMappingTable() {
  const tableName = CONFIG.sync.mappingTableName;
  logger.info(`步骤4: 创建/重建ID映射表 ${tableName}...`);
  
  const createSQL = `
    CREATE TABLE IF NOT EXISTS \`${tableName}\` (
      \`source_id\`        VARCHAR(36) NOT NULL COMMENT '源系统ID (GUID)',
      \`target_id\`        INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '目标系统ID (自增INT)',
      \`source_parent_id\` VARCHAR(36) DEFAULT NULL COMMENT '源父部门ID',
      \`fullpathcode\`     VARCHAR(500) DEFAULT NULL COMMENT '原始层级路径',
      \`ancestors\`        VARCHAR(500) DEFAULT NULL COMMENT '目标系统 ancestors 路径',
      \`created_at\`      DATETIME DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (\`source_id\`),
      KEY \`idx_target_id\` (\`target_id\`),
      KEY \`idx_source_parent\` (\`source_parent_id\`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  `;
  
  try {
    // 先删除旧表（如果存在），确保使用最新的表结构
    await mysqlPool.query(`DROP TABLE IF EXISTS \`${tableName}\``);
    logger.debug(`已删除旧映射表 ${tableName}`);
    
    await mysqlPool.query(createSQL);
    logger.info(`✅ 映射表 ${tableName} 创建成功`);
    addStep('创建ID映射表', '✅');
    return true;
  } catch (err) {
    logger.error('创建映射表失败', { error: err.message });
    addStep('创建ID映射表', '❌', { error: err.message });
    return false;
  }
}

// ==================== 步骤5: 全量同步 - 清空数据 ====================
async function truncateTargetTables(isFullSync, backupResult = null) {
  if (!isFullSync) {
    logger.info('步骤5: 跳过清空操作（增量同步模式）');
    addStep('清空目标表', '⏭️', { reason: '增量同步模式' });
    return true;
  }
  
  logger.warn('⚠️ 全量同步模式: 将清空目标表');
  
  const connection = await mysqlPool.getConnection();
  try {
    await connection.beginTransaction();
    
    // 清空映射表
    await connection.query(`DELETE FROM \`${CONFIG.sync.mappingTableName}\``);
    logger.debug(`已清空映射表 ${CONFIG.sync.mappingTableName}`);
    
    // 清空目标表
    await connection.query('DELETE FROM organize_dept');
    logger.debug('已清空 organize_dept 表');
    
    // 重置自增ID
    await connection.query('ALTER TABLE organize_dept AUTO_INCREMENT = 1');
    logger.debug('已重置 organize_dept 自增ID');
    
    await connection.commit();
    logger.info('✅ 目标表清空完成');
    addStep('清空目标表', '✅', { 
      clearedTables: ['organize_dept', CONFIG.sync.mappingTableName],
      backupSuffix: backupResult?.backedUp ? 'organize_dept_backup_' + backupResult.backupSuffix : null
    });
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

// ==================== 步骤6: 提取源数据并生成ID映射 ====================
async function extractAndMapIds(isFullSync) {
  logger.info('步骤6: 提取源数据并生成ID映射...');
  
  const connection = await mysqlPool.getConnection();
  
  try {
    await connection.beginTransaction();
    
    // 从 MySQL 的 UDMOrganization 表查询数据（按 FULLPATHCODE 排序确保父节点在前）
    const sourceQuery = `
      SELECT ID, PARENTID, FULLNAME, SHORTNAME, FULLPATHCODE, INNERORDER, 
             EFFECTIVESTATUS, DATASOURCE, EFFECTIVEDATE, MASTERDATA_BATCHTIME
      FROM UDMOrganization 
      ORDER BY FULLPATHCODE ASC
    `;
    
    const [sourceData] = await connection.query(sourceQuery);
    
    if (sourceData.length === 0) {
      logger.warn('⚠️ 没有需要同步的数据');
      addStep('提取源数据', '✅', { rowCount: 0 });
      await connection.commit();
      connection.release();
      return new Map();
    }
    
    logger.info(`将处理 ${sourceData.length} 条源数据`);
    
    // 构建ID映射关系
    const idMapping = new Map();  // source_id -> { target_id, source_parent_id }
    let targetId = 1;
    
    // 建立基础映射
    for (const row of sourceData) {
      // 状态转换: EFFECTIVESTATUS I=有效(1), A=无效(2)
      // DATASOURCE: 0=正常数据
      const effectiveStatus = row.EFFECTIVESTATUS === 'I' ? 1 : 2;
      const isDeleted = (row.DATASOURCE === 1 || row.DATASOURCE === 2) ? 1 : 2;
      
      idMapping.set(row.ID, {
        source_parent_id: row.PARENTID || null,
        fullpathcode: row.FULLPATHCODE,
        sort: row.INNERORDER || 0,
        fullname: row.FULLNAME,
        shortname: row.SHORTNAME || '',
        effective_status: effectiveStatus,
        is_deleted: isDeleted,
        effective_date: row.EFFECTIVEDATE,
        update_time: row.MASTERDATA_BATCHTIME
      });
    }
    
    // 按 FULLPATHCODE 排序确保父节点先处理
    const orderedIds = sourceData.map(row => row.ID);
    
    // 分配 target_id
    for (const sourceId of orderedIds) {
      idMapping.get(sourceId).target_id = targetId++;
    }
    
    // 批量写入映射表
    const mappingValues = [];
    for (const [sourceId, mapping] of idMapping) {
      // 计算 ancestors
      const ancestors = calculateAncestors(sourceId, idMapping);
      
      mappingValues.push([
        sourceId,
        mapping.target_id,
        mapping.source_parent_id,
        mapping.fullpathcode,
        ancestors
      ]);
    }
    
    if (mappingValues.length > 0) {
      const insertMappingSQL = `
        INSERT INTO \`${CONFIG.sync.mappingTableName}\` 
        (source_id, target_id, source_parent_id, fullpathcode, ancestors)
        VALUES ?
      `;
      await connection.query(insertMappingSQL, [mappingValues]);
      logger.info(`已写入 ${mappingValues.length} 条映射记录`);
    }
    
    await connection.commit();
    
    RESULT.mappedCount = idMapping.size;
    logger.info(`✅ ID映射完成，共 ${idMapping.size} 条记录`);
    addStep('提取源数据并生成ID映射', '✅', { mappedCount: idMapping.size });
    
    return idMapping;
    
  } catch (err) {
    await connection.rollback();
    logger.error('提取源数据失败', { error: err.message });
    addStep('提取源数据并生成ID映射', '❌', { error: err.message });
    return null;
  } finally {
    connection.release();
  }
}

/**
 * 计算 ancestors 路径
 * 递归向上查找父节点，构建形如 "0/1/2/3" 的路径
 */
function calculateAncestors(sourceId, idMapping) {
  const ancestors = [0];  // 从0开始
  let currentId = sourceId;
  const visited = new Set();
  
  while (currentId) {
    if (visited.has(currentId)) break;  // 防止循环引用
    visited.add(currentId);
    
    const mapping = idMapping.get(currentId);
    if (!mapping) break;
    
    if (mapping.target_id) {
      ancestors.push(mapping.target_id);
    }
    
    if (!mapping.source_parent_id) break;
    currentId = mapping.source_parent_id;
  }
  
  return ancestors.join('/');
}

// ==================== 步骤7: 同步数据到目标表 ====================
async function syncToTargetTable(idMapping) {
  logger.info('步骤7: 同步数据到 organize_dept 表...');
  
  if (!idMapping || idMapping.size === 0) {
    logger.warn('⚠️ 没有数据需要同步');
    addStep('同步数据到目标表', '✅', { syncedCount: 0 });
    return true;
  }
  
  const connection = await mysqlPool.getConnection();
  
  try {
    await connection.beginTransaction();
    
    const batchSize = CONFIG.sync.batchSize;
    const batchInserts = [];
    let batchCount = 0;
    let totalSuccess = 0;
    
    // 批量构建插入数据
    for (const [sourceId, mapping] of idMapping) {
      // 计算 parent_id（根节点为0）
      let parentTargetId = 0;
      if (mapping.source_parent_id && idMapping.has(mapping.source_parent_id)) {
        parentTargetId = idMapping.get(mapping.source_parent_id).target_id;
      }
      
      // 状态转换: EFFECTIVESTATUS I=有效(1), A=无效(2)
      const status = mapping.effective_status || 1;
      // 是否删除: DATASOURCE 0=正常(2), 1/2=已删除(1)
      const isDeleted = mapping.is_deleted || 2;
      
      batchInserts.push([
        mapping.target_id,           // dept_id
        parentTargetId,              // parent_id
        mapping.fullname || '',      // dept_name
        calculateAncestors(sourceId, idMapping),  // ancestors
        mapping.sort || 0,           // order_num
        '',                          // leader
        '',                          // phone
        '',                          // email
        status,                      // status
        isDeleted,                   // is_deleted
        mapping.effective_date || new Date(),  // created_at
        mapping.update_time || new Date()       // updated_at
      ]);
      
      if (batchInserts.length >= batchSize) {
        await executeBatchInsert(connection, batchInserts);
        totalSuccess += batchInserts.length;
        batchCount++;
        logger.debug(`已处理第 ${batchCount} 批，${batchInserts.length} 条`);
        batchInserts.length = 0;
      }
    }
    
    // 处理剩余数据
    if (batchInserts.length > 0) {
      await executeBatchInsert(connection, batchInserts);
      totalSuccess += batchInserts.length;
      batchCount++;
    }
    
    await connection.commit();
    
    RESULT.successCount = totalSuccess;
    RESULT.targetCount = totalSuccess;
    
    logger.info(`✅ 数据同步完成: ${totalSuccess} 条记录`);
    addStep('同步数据到目标表', '✅', { syncedCount: totalSuccess });
    return true;
    
  } catch (err) {
    await connection.rollback();
    logger.error('同步数据失败', { error: err.message });
    RESULT.errors.push(err.message);
    addStep('同步数据到目标表', '❌', { error: err.message });
    return false;
  } finally {
    connection.release();
  }
}

async function executeBatchInsert(connection, batchData) {
  const insertSQL = `
    INSERT INTO organize_dept (
      dept_id, parent_id, dept_name, ancestors,
      order_num, leader, phone, email, status, is_deleted,
      created_at, updated_at
    ) VALUES ?
  `;
  await connection.query(insertSQL, [batchData]);
}

// ==================== 步骤8: 数据验证 ====================
async function validateData() {
  logger.info('步骤8: 验证同步结果...');
  
  try {
    // 1. 检查目标表数据量
    const [targetCountResult] = await mysqlPool.query(
      'SELECT COUNT(*) as cnt FROM organize_dept'
    );
    logger.info(`目标表数据量: ${targetCountResult[0].cnt}`);
    
    // 2. 检查映射表数据量
    const [mappingCountResult] = await mysqlPool.query(
      `SELECT COUNT(*) as cnt FROM \`${CONFIG.sync.mappingTableName}\``
    );
    logger.info(`映射表数据量: ${mappingCountResult[0].cnt}`);
    
    // 3. 检查数据一致性（parent_id 对应的部门是否存在）
    const [orphanResult] = await mysqlPool.query(`
      SELECT COUNT(*) as cnt FROM organize_dept d
      WHERE d.parent_id != 0 
        AND NOT EXISTS (
          SELECT 1 FROM organize_dept p WHERE p.dept_id = d.parent_id
        )
    `);
    
    if (orphanResult[0].cnt > 0) {
      logger.warn(`⚠️ 发现 ${orphanResult[0].cnt} 条记录的 parent_id 在目标表中不存在`);
    } else {
      logger.info('✅ 所有 parent_id 关系验证通过');
    }
    
    // 4. 验证 ancestors 路径格式
    const [invalidAncestors] = await mysqlPool.query(`
      SELECT COUNT(*) as cnt FROM organize_dept 
      WHERE ancestors IS NULL OR ancestors = '' OR ancestors NOT REGEXP '^0(/[0-9]+)*$'
    `);
    
    if (invalidAncestors[0].cnt > 0) {
      logger.warn(`⚠️ 发现 ${invalidAncestors[0].cnt} 条记录的 ancestors 格式异常`);
    } else {
      logger.info('✅ ancestors 路径格式验证通过');
    }
    
    // 5. 抽样检查
    const [samples] = await mysqlPool.query(`
      SELECT d.dept_id, d.dept_name, d.parent_id, d.ancestors, m.source_id
      FROM organize_dept d
      LEFT JOIN \`${CONFIG.sync.mappingTableName}\` m ON d.dept_id = m.target_id
      ORDER BY d.dept_id
      LIMIT 5
    `);
    
    logger.info('抽样数据（前5条）:');
    samples.forEach(row => {
      logger.info(`  [${row.dept_id}] ${row.dept_name} | parent: ${row.parent_id} | ancestors: ${row.ancestors}`);
      logger.debug(`    源ID: ${row.source_id}`);
    });
    
    const isValid = orphanResult[0].cnt === 0 && invalidAncestors[0].cnt === 0;
    addStep('数据验证', isValid ? '✅' : '⚠️', {
      targetCount: targetCountResult[0].cnt,
      mappingCount: mappingCountResult[0].cnt,
      orphanCount: orphanResult[0].cnt,
      invalidAncestorsCount: invalidAncestors[0].cnt
    });
    
    return isValid;
    
  } catch (err) {
    logger.error('数据验证失败', { error: err.message });
    addStep('数据验证', '❌', { error: err.message });
    return false;
  }
}

// ==================== 步骤9: 生成同步报告 ====================
async function generateReport() {
  logger.info('步骤9: 生成同步报告...');
  
  try {
    const [deptStats] = await mysqlPool.query(`
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN parent_id = 0 THEN 1 ELSE 0 END) as rootCount,
        SUM(CASE WHEN is_deleted = 1 THEN 1 ELSE 0 END) as deletedCount,
        SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) as disabledCount,
        MAX(LENGTH(ancestors) - LENGTH(REPLACE(ancestors, '/', ''))) as maxLevel
      FROM organize_dept
    `);
    
    // 获取备份历史
    let backupHistory = [];
    try {
      const [history] = await mysqlPool.query(`
        SELECT * FROM _backup_history ORDER BY backup_time DESC LIMIT 10
      `);
      backupHistory = history;
    } catch (e) {
      // 备份历史表可能不存在
    }
    
    const report = {
      syncTime: new Date().toISOString(),
      sourceCount: RESULT.sourceCount,
      targetCount: RESULT.targetCount,
      successCount: RESULT.successCount,
      errorCount: RESULT.errorCount,
      statistics: deptStats[0],
      backup: RESULT.backupInfo || null,
      backupHistory: backupHistory,
      steps: RESULT.steps,
      duration: `${((RESULT.endTime - RESULT.startTime) / 1000).toFixed(2)}s`
    };
    
    logger.info('\n📊 同步报告:');
    console.log(JSON.stringify(report, null, 2));
    
    addStep('生成同步报告', '✅');
    return report;
    
  } catch (err) {
    logger.error('生成报告失败', { error: err.message });
    addStep('生成同步报告', '❌', { error: err.message });
    return null;
  }
}

// ==================== 辅助功能: 查看备份历史 ====================
async function showBackupHistory() {
  logger.info('查询备份历史...');
  
  try {
    const [history] = await mysqlPool.query(`
      SELECT * FROM _backup_history ORDER BY backup_time DESC LIMIT 20
    `);
    
    if (history.length === 0) {
      logger.info('暂无备份记录');
      return;
    }
    
    console.log('\n📜 备份历史记录:');
    console.log('='.repeat(80));
    console.log('| 序号 | 原始表名           | 备份表名                     | 数据量 | 备份时间              |');
    console.log('-' .repeat(80));
    
    history.forEach((row, i) => {
      const timeStr = row.backup_time ? row.backup_time.toISOString().slice(0, 19).replace('T', ' ') : '-';
      console.log(`| ${(i + 1).toString().padStart(4)} | ${row.table_name.padEnd(17)} | ${row.backup_table_name.padEnd(25)} | ${String(row.row_count).padStart(6)} | ${timeStr} |`);
    });
    
    console.log('='.repeat(80));
    
    // 显示可用备份表
    const [backupTables] = await mysqlPool.query(`
      SELECT TABLE_NAME, TABLE_ROWS, CREATE_TIME 
      FROM INFORMATION_SCHEMA.TABLES 
      WHERE TABLE_SCHEMA = ? AND TABLE_NAME LIKE 'organize_dept_backup_%'
      ORDER BY CREATE_TIME DESC
    `, [CONFIG.mysql.database]);
    
    if (backupTables.length > 0) {
      console.log('\n📦 可用的备份表:');
      backupTables.forEach(t => {
        console.log(`  - ${t.TABLE_NAME} (${t.TABLE_ROWS} 条记录)`);
      });
    }
    
  } catch (err) {
    logger.error('查询备份历史失败', { error: err.message });
  }
}

// ==================== 主执行流程 ====================
async function main() {
  console.log('\n' + '='.repeat(60));
  console.log('🏢 UDMOrganization → Organize_Dept 同步程序');
  console.log('(MySQL Only Version - UDMOrganization 已在 MySQL 中)');
  console.log('='.repeat(60) + '\n');
  
  // 解析命令行参数
  const args = process.argv.slice(2);
  const isFullSync = args.includes('--full');
  const isDryRun = args.includes('--dry-run');
  const showBackups = args.includes('--show-backups');
  
  if (isFullSync) {
    logger.warn('⚠️ 全量同步模式: 将备份并清空目标表');
  }
  if (isDryRun) {
    logger.warn('⚠️ 模拟运行模式: 不会写入数据库');
  }
  if (showBackups) {
    logger.info('📜 查看备份历史模式');
    RESULT.startTime = Date.now();
    await connectMySQL();
    await showBackupHistory();
    RESULT.endTime = Date.now();
    console.log(`\n查询完成，耗时 ${((RESULT.endTime - RESULT.startTime) / 1000).toFixed(2)}s`);
    await closeConnections();
    return;
  }
  
  RESULT.startTime = Date.now();
  
  try {
    // ========== 阶段1: 数据库连接 ==========
    console.log('\n📡 阶段1: 数据库连接...\n');
    
    await connectMySQL();
    
    // ========== 阶段2: 表结构检查 ==========
    console.log('\n🔍 阶段2: 表结构检查...\n');
    
    await checkSourceTableStructure();
    await checkTargetTableStructure();
    
    // ========== 阶段3: 备份目标表（仅全量同步） ==========
    console.log('\n💾 阶段3: 备份目标表...\n');
    
    let backupResult = null;
    if (isFullSync) {
      backupResult = await backupTargetTables();
      RESULT.backupInfo = backupResult;
    } else {
      logger.info('增量同步模式: 跳过备份');
    }
    
    // ========== 阶段4: 准备同步环境 ==========
    console.log('\n🗄️ 阶段4: 准备同步环境...\n');
    
    await createIdMappingTable();
    await truncateTargetTables(isFullSync, backupResult);
    
    // ========== 阶段5: 数据同步 ==========
    console.log('\n📥 阶段5: 执行数据同步...\n');
    
    if (!isDryRun) {
      const idMapping = await extractAndMapIds(isFullSync);
      if (idMapping === null) {
        throw new Error('ID映射生成失败');
      }
      await syncToTargetTable(idMapping);
    } else {
      logger.info('模拟运行: 跳过数据写入');
      RESULT.successCount = RESULT.sourceCount;
    }
    
    // ========== 阶段6: 验证和报告 ==========
    console.log('\n✅ 阶段6: 验证和报告...\n');
    
    if (!isDryRun) {
      await validateData();
    }
    await generateReport();
    
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
