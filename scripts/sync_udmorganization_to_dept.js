/**
 * UDMOrganization -> OrganizeDept 数据同步方案
 * 
 * 功能说明：
 * 1. 从 SQL Server UDMOrganization 表同步数据到 MySQL organize_dept 表
 * 2. 处理 varchar(36) -> int 自增 的 ID 转换
 * 3. 处理层级关系（ancestors 依赖 ID 映射）
 * 4. 支持增量同步（基于 LastUpdateTime）
 * 5. 事务保障数据一致性
 */

const sql = require('mssql');
const mysql = require('mysql2/promise');

// ==================== 配置 ====================
const MSSQL_CONFIG = {
  user: 'sa',
  password: 'df3**@F@!!@l3**@F@!!@ldcc',
  server: '10.90.102.66',
  database: 'CFLDCN_PMS20230905',
  options: {
    encrypt: false,
    trustServerCertificate: true,
    connectTimeout: 30000,
    requestTimeout: 120000,
  },
  port: 1433,
};

const MYSQL_CONFIG = {
  host: 'localhost',
  port: 3306,
  user: 'root',
  password: 'wenming429',
  database: 'go_chat',
  charset: 'utf8mb4',
  connectTimeout: 30000,
};

// 同步配置
const SYNC_CONFIG = {
  sourceTable: 'UDMOrganization',      // SQL Server 源表
  idMappingTable: '_dept_id_mapping',   // ID映射表（临时）
  batchSize: 500,
  enableIncremental: true,              // 启用增量同步
  lastSyncTimeKey: 'last_sync_dept',    // Redis/文件存储最后同步时间
};

// ==================== 字段映射配置 ====================
const FIELD_MAPPING = {
  // MySQL organize_dept 字段 -> SQL Server UDMOrganization 字段
  'dept_id': {
    sourceField: 'ID',
    type: 'VARCHAR(36)',
    description: '部门ID（源系统主键）'
  },
  'parent_id': {
    sourceField: 'PARENTID',
    type: 'VARCHAR(36)',
    description: '父部门ID'
  },
  'dept_name': {
    sourceField: 'FULLNAME',
    type: 'VARCHAR(64)',
    description: '部门名称'
  },
  'short_name': {
    sourceField: 'SHORTNAME',
    type: 'VARCHAR(50)',
    description: '部门简称'
  },
  'ancestors': {
    sourceField: 'FULLPATHCODE',
    type: 'VARCHAR(128)',
    description: '祖级列表'
  },
  'order_num': {
    sourceField: 'SORT',
    type: 'INT',
    description: '显示顺序'
  },
  'status': {
    sourceField: 'ISDEL',
    type: 'TINYINT',
    transform: (val) => val === 0 ? 1 : 2,  // 0=正常(1), 1=删除(2)
    description: '状态'
  },
  'is_deleted': {
    sourceField: 'ISDEL',
    type: 'TINYINT',
    transform: (val) => val === 1 ? 1 : 2,  // 1=已删除, 2=未删除
    description: '是否删除'
  },
  'create_time': {
    sourceField: 'CREATETIME',
    type: 'DATETIME',
    transform: formatDateTime,
    description: '创建时间'
  },
  'update_time': {
    sourceField: 'UPDATETIME',
    type: 'DATETIME',
    transform: formatDateTime,
    description: '更新时间'
  }
};

// ==================== 工具函数 ====================
function formatDateTime(val) {
  if (!val) return null;
  if (val instanceof Date) {
    return val.toISOString().slice(0, 19).replace('T', ' ');
  }
  return val;
}

// ==================== Step 1: 创建ID映射表 ====================
async function createIdMappingTable(mysqlConn) {
  console.log('\n【Step 1】创建ID映射表...');
  
  const createSQL = `
    CREATE TABLE IF NOT EXISTS \`${SYNC_CONFIG.idMappingTable}\` (
      \`source_id\`     VARCHAR(36) NOT NULL COMMENT '源系统部门ID',
      \`target_id\`     INT UNSIGNED NOT NULL COMMENT '目标系统部门ID(自增)',
      \`fullpathcode\`  VARCHAR(500) DEFAULT NULL COMMENT '完整路径编码',
      \`fullname\`      VARCHAR(300) DEFAULT NULL COMMENT '部门全名',
      \`created_at\`    DATETIME DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (\`source_id\`),
      KEY \`idx_target_id\` (\`target_id\`),
      KEY \`idx_fullpathcode\` (\`fullpathcode\`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='部门ID映射表(临时)';
  `;
  
  await mysqlConn.execute(`DROP TABLE IF EXISTS \`${SYNC_CONFIG.idMappingTable}\``);
  await mysqlConn.execute(createSQL);
  console.log('  ID映射表创建完成');
}

// ==================== Step 2: 同步部门基础数据（第一阶段：生成ID映射）====================
async function syncDeptBasicData(mssqlPool, mysqlConn) {
  console.log('\n【Step 2】同步部门基础数据（生成ID映射）...');
  
  // 查询所有有效部门
  const querySQL = `
    SELECT 
      ID,
      PARENTID,
      FULLNAME,
      SHORTNAME,
      FULLPATHCODE,
      SORT,
      ISDEL,
      CREATETIME,
      UPDATETIME
    FROM [dbo].[${SYNC_CONFIG.sourceTable}]
    WHERE ISDEL = 0
    ORDER BY ISNULL(FULLPATHCODE, ''), SORT
  `;
  
  const result = await mssqlPool.request().query(querySQL);
  const deptList = result.recordset;
  
  console.log(`  查询到 ${deptList.length} 条部门数据`);
  
  if (deptList.length === 0) {
    console.log('  无数据需要同步');
    return new Map();
  }
  
  // 开启事务
  await mysqlConn.beginTransaction();
  
  try {
    const idMapping = new Map();  // source_id -> {target_id, fullpathcode, fullname}
    let targetId = 1;
    
    // 按 FULLPATHCODE 排序，确保父节点先处理
    deptList.sort((a, b) => {
      const pathA = a.FULLPATHCODE || '';
      const pathB = b.FULLPATHCODE || '';
      return pathA.localeCompare(pathB);
    });
    
    // 第一遍：插入数据获取自增ID，建立映射关系
    for (const dept of deptList) {
      const sourceId = dept.ID;
      const fullpathcode = dept.FULLPATHCODE || '';
      const fullname = dept.FULLNAME || '';
      
      // 插入 organize_dept
      const insertSQL = `
        INSERT INTO \`organize_dept\` (
          dept_id, parent_id, dept_name, short_name, ancestors,
          order_num, status, is_deleted, created_at, updated_at
        ) VALUES (
          ?, ?, ?, ?, ?,
          ?, ?, ?, ?, ?
        )
      `;
      
      const params = [
        targetId,                          // dept_id (自增主键)
        null,                              // parent_id (待更新)
        fullname.substring(0, 64),         // dept_name
        (dept.SHORTNAME || '').substring(0, 50),  // short_name
        fullpathcode,                      // ancestors
        dept.SORT || 1,                   // order_num
        1,                                // status (正常)
        2,                                // is_deleted (未删除)
        formatDateTime(dept.CREATETIME),  // created_at
        formatDateTime(dept.UPDATETIME)  // updated_at
      ];
      
      await mysqlConn.execute(insertSQL, params);
      
      // 记录ID映射
      idMapping.set(sourceId, {
        targetId: targetId,
        fullpathcode: fullpathcode,
        fullname: fullname
      });
      
      targetId++;
    }
    
    // 第二遍：更新 parent_id（基于ID映射）
    console.log('  更新父部门ID关系...');
    for (const dept of deptList) {
      const sourceParentId = dept.PARENTID;
      const sourceId = dept.ID;
      
      if (sourceParentId && idMapping.has(sourceParentId)) {
        const childTargetId = idMapping.get(sourceId).targetId;
        const parentTargetId = idMapping.get(sourceParentId).targetId;
        
        await mysqlConn.execute(
          'UPDATE `organize_dept` SET `parent_id` = ? WHERE `dept_id` = ?',
          [parentTargetId, childTargetId]
        );
        
        // 更新 ancestors 路径（使用目标系统ID）
        const parentMapping = idMapping.get(sourceParentId);
        const newAncestors = parentMapping.fullpathcode 
          ? `${parentMapping.fullpathcode}/${childTargetId}`
          : `0/${childTargetId}`;
        
        await mysqlConn.execute(
          'UPDATE `organize_dept` SET `ancestors` = ? WHERE `dept_id` = ?',
          [newAncestors, childTargetId]
        );
        
        idMapping.get(sourceId).fullpathcode = newAncestors;
      } else if (!sourceParentId || sourceParentId === sourceId) {
        // 顶级部门
        const childTargetId = idMapping.get(sourceId).targetId;
        await mysqlConn.execute(
          'UPDATE `organize_dept` SET `parent_id` = 0, `ancestors` = ? WHERE `dept_id` = ?',
          [`0/${childTargetId}`, childTargetId]
        );
        idMapping.get(sourceId).fullpathcode = `0/${childTargetId}`;
      }
    }
    
    // 保存映射表
    console.log('  保存ID映射关系...');
    for (const [sourceId, mapping] of idMapping) {
      await mysqlConn.execute(
        `INSERT INTO \`${SYNC_CONFIG.idMappingTable}\` (source_id, target_id, fullpathcode, fullname) VALUES (?, ?, ?, ?)`,
        [sourceId, mapping.targetId, mapping.fullpathcode, mapping.fullname]
      );
    }
    
    await mysqlConn.commit();
    console.log(`  基础数据同步完成，共 ${idMapping.size} 条记录`);
    
    return idMapping;
    
  } catch (error) {
    await mysqlConn.rollback();
    throw error;
  }
}

// ==================== Step 3: 增量同步（基于更新时间）====================
async function incrementalSync(mssqlPool, mysqlConn, lastSyncTime) {
  console.log(`\n【Step 3】增量同步（自 ${lastSyncTime} 后的更新）...`);
  
  if (!lastSyncTime) {
    console.log('  未提供上次同步时间，执行全量同步');
    return;
  }
  
  const querySQL = `
    SELECT 
      ID, PARENTID, FULLNAME, SHORTNAME, FULLPATHCODE,
      SORT, ISDEL, CREATETIME, UPDATETIME
    FROM [dbo].[${SYNC_CONFIG.sourceTable}]
    WHERE UPDATETIME > ?
    ORDER BY UPDATETIME
  `;
  
  const result = await mssqlPool.request()
    .input('lastSync', sql.DateTime, new Date(lastSyncTime))
    .query(querySQL);
  
  const updatedDepts = result.recordset;
  console.log(`  发现 ${updatedDepts.length} 条更新数据`);
  
  if (updatedDepts.length === 0) return;
  
  // 获取现有映射
  const [mappingRows] = await mysqlConn.execute(
    `SELECT source_id, target_id FROM \`${SYNC_CONFIG.idMappingTable}\``
  );
  const existingMapping = new Map(mappingRows.map(r => [r.source_id, r.target_id]));
  
  await mysqlConn.beginTransaction();
  
  try {
    for (const dept of updatedDepts) {
      const isDeleted = dept.ISDEL === 1;
      
      if (existingMapping.has(dept.ID)) {
        // 更新现有记录
        const targetId = existingMapping.get(dept.ID);
        
        if (isDeleted) {
          await mysqlConn.execute(
            'UPDATE `organize_dept` SET is_deleted = 1 WHERE dept_id = ?',
            [targetId]
          );
        } else {
          await mysqlConn.execute(
            `UPDATE \`organize_dept\` SET 
              dept_name = ?, short_name = ?, order_num = ?, 
              update_time = ? WHERE dept_id = ?`,
            [
              (dept.FULLNAME || '').substring(0, 64),
              (dept.SHORTNAME || '').substring(0, 50),
              dept.SORT || 1,
              formatDateTime(dept.UPDATETIME),
              targetId
            ]
          );
        }
      } else if (!isDeleted) {
        // 新增记录
        // 注意：新增记录的 parent_id 需要特殊处理
        const newTargetId = await insertNewDept(mysqlConn, dept);
        existingMapping.set(dept.ID, newTargetId);
      }
    }
    
    await mysqlConn.commit();
    console.log('  增量同步完成');
    
  } catch (error) {
    await mysqlConn.rollback();
    throw error;
  }
}

// 插入新部门
async function insertNewDept(mysqlConn, dept) {
  const [result] = await mysqlConn.execute(
    `INSERT INTO \`organize_dept\` (
      dept_name, short_name, ancestors, order_num,
      status, is_deleted, created_at, update_time
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      (dept.FULLNAME || '').substring(0, 64),
      (dept.SHORTNAME || '').substring(0, 50),
      dept.FULLPATHCODE || '',
      dept.SORT || 1,
      1, 2,
      formatDateTime(dept.CREATETIME),
      formatDateTime(dept.UPDATETIME)
    ]
  );
  
  return result.insertId;
}

// ==================== Step 4: 数据验证 ====================
async function validateData(mysqlConn) {
  console.log('\n【Step 4】数据验证...');
  
  // 统计验证
  const [total] = await mysqlConn.execute('SELECT COUNT(*) as cnt FROM `organize_dept`');
  const [active] = await mysqlConn.execute('SELECT COUNT(*) as cnt FROM `organize_dept` WHERE is_deleted = 2');
  const [deleted] = await mysqlConn.execute('SELECT COUNT(*) as cnt FROM `organize_dept` WHERE is_deleted = 1');
  
  console.log(`  总记录数: ${total[0].cnt}`);
  console.log(`  有效部门: ${active[0].cnt}`);
  console.log(`  已删除: ${deleted[0].cnt}`);
  
  // 层级验证
  const [orphanDepts] = await mysqlConn.execute(`
    SELECT COUNT(*) as cnt FROM \`organize_dept\` 
    WHERE parent_id != 0 
    AND parent_id NOT IN (SELECT dept_id FROM \`organize_dept\` WHERE parent_id = 0 OR dept_id != parent_id)
  `);
  
  if (orphanDepts[0].cnt > 0) {
    console.warn(`  ⚠️ 发现 ${orphanDepts[0].cnt} 条孤儿记录（父部门不存在）`);
  } else {
    console.log('  ✅ 层级关系验证通过');
  }
  
  // 样本数据
  const [samples] = await mysqlConn.execute(`
    SELECT dept_id, parent_id, dept_name, ancestors 
    FROM \`organize_dept\` 
    ORDER BY ancestors 
    LIMIT 10
  `);
  
  console.log('\n  样本数据（前10条）:');
  console.log('  +---------+-----------+--------------------------------+------------------------------------');
  console.log('  | dept_id | parent_id | dept_name                      | ancestors');
  console.log('  +---------+-----------+--------------------------------+------------------------------------');
  for (const row of samples) {
    const name = (row.dept_name || '').substring(0, 30).padEnd(30);
    const ancestors = (row.ancestors || '').substring(0, 36).padEnd(36);
    console.log(`  | ${String(row.dept_id).padStart(7)} | ${String(row.parent_id).padStart(9)} | ${name} | ${ancestors}`);
  }
  console.log('  +---------+-----------+--------------------------------+----');
}

// ==================== Step 5: 清理临时表 ====================
async function cleanup(mysqlConn, keepMappingTable = false) {
  console.log('\n【Step 5】清理...');
  
  if (!keepMappingTable) {
    await mysqlConn.execute(`DROP TABLE IF EXISTS \`${SYNC_CONFIG.idMappingTable}\``);
    console.log('  已删除临时ID映射表');
  }
  
  console.log('  清理完成');
}

// ==================== 主函数 ====================
async function main() {
  const startTime = Date.now();
  
  console.log('=' .repeat(70));
  console.log('  UDMOrganization -> OrganizeDept 数据同步工具');
  console.log('=' .repeat(70));
  console.log(`\n  源表: SQL Server [dbo].${SYNC_CONFIG.sourceTable}`);
  console.log(`  目标: MySQL go_chat.organize_dept`);
  console.log(`  增量模式: ${SYNC_CONFIG.enableIncremental ? '启用' : '禁用'}`);
  console.log('');
  
  let mssqlPool, mysqlConn;
  
  try {
    // 连接 SQL Server
    console.log('▶ 连接 SQL Server...');
    mssqlPool = await sql.connect(MSSQL_CONFIG);
    console.log('  ✓ SQL Server 连接成功\n');
    
    // 连接 MySQL
    console.log('▶ 连接 MySQL...');
    mysqlConn = await mysql.createConnection(MYSQL_CONFIG);
    await mysqlConn.execute('SET NAMES utf8mb4');
    await mysqlConn.execute('SET FOREIGN_KEY_CHECKS=0');
    console.log('  ✓ MySQL 连接成功\n');
    
    // 执行同步流程
    await createIdMappingTable(mysqlConn);
    await syncDeptBasicData(mssqlPool, mysqlConn);
    
    // 增量同步（如果启用）
    if (SYNC_CONFIG.enableIncremental) {
      // 这里可以从配置文件或Redis读取上次同步时间
      const lastSyncTime = null; // 或指定时间，如 '2026-01-01 00:00:00'
      if (lastSyncTime) {
        await incrementalSync(mssqlPool, mysqlConn, lastSyncTime);
      }
    }
    
    // 数据验证
    await validateData(mysqlConn);
    
    // 清理（保留映射表以便增量同步使用）
    await cleanup(mysqlConn, true);
    
    // 恢复外键检查
    await mysqlConn.execute('SET FOREIGN_KEY_CHECKS=1');
    
    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    console.log(`\n✓ 同步完成！总耗时: ${elapsed}s`);
    
  } catch (error) {
    console.error('\n✗ 同步失败:', error.message);
    if (mysqlConn) {
      await mysqlConn.rollback();
      await mysqlConn.execute('SET FOREIGN_KEY_CHECKS=1');
    }
    process.exit(1);
  } finally {
    if (mysqlConn) await mysqlConn.end();
    if (mssqlPool) await mssqlPool.close();
  }
}

// 导出模块供外部调用
module.exports = {
  syncOrganizeDept,
  FIELD_MAPPING,
  SYNC_CONFIG
};

// 如果直接运行此脚本
if (require.main === module) {
  main();
}
