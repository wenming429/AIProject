/**
 * 基于 init_organization_dept 视图初始化 organize_dept 表
 * ancestors 格式: 逗号分隔 (0,1,2)
 * 根节点: ancestors = "0"
 * 子节点: ancestors = "0,1" (根节点dept_id,父节点dept_id)
 */

const mysql = require('mysql2/promise');

const DB_CONFIG = {
  host: 'localhost',
  user: 'root',
  password: 'wenming429',
  database: 'go_chat',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

async function syncOrganizeDept() {
  const pool = mysql.createPool(DB_CONFIG);
  const connection = await pool.getConnection();
  
  try {
    console.log('============================================================');
    console.log('🏢 init_organization_dept → organize_dept 同步程序');
    console.log('ancestors 格式: 逗号分隔 (0,1,2)');
    console.log('============================================================\n');
    
    // 1. 清空目标表并重置
    console.log('📡 阶段1: 准备同步环境...');
    await connection.execute('DELETE FROM organize_dept');
    await connection.execute('ALTER TABLE organize_dept AUTO_INCREMENT = 1');
    console.log('✅ 目标表已清空，自增 ID 已重置\n');
    
    // 2. 查询所有源数据（按 INNERORDER 排序）
    console.log('🔍 阶段2: 查询源数据...');
    const [orgs] = await connection.execute(`
      SELECT 
        ID,
        PARENTID,
        FULLNAME,
        FULLPATHCODE,
        INNERORDER,
        MASTERDATA_DATASTATUS,
        EFFECTIVESTATUS
      FROM init_organization_dept
      ORDER BY INNERORDER ASC
    `);
    console.log(`   查询到 ${orgs.length} 条组织数据\n`);
    
    // 3. 构建 ID 到索引的映射
    console.log('🌳 阶段3: 构建树结构...');
    const idIndexMap = new Map();
    orgs.forEach((org, index) => {
      idIndexMap.set(org.ID, index);
    });
    
    // 4. 递归构建节点关系
    const nodes = [];
    
    function buildTree(parentId, level, ancestors) {
      const children = orgs.filter(org => org.PARENTID === parentId);
      
      children.forEach((org, index) => {
        // 计算当前节点的 ancestors
        // ancestors 存储的是 dept_id（本地自增ID），不是 udm_org_id
        // 由于我们使用 INSERT...SELECT 方式，需要先构建映射关系
        
        nodes.push({
          udm_org_id: org.ID,
          udm_org_parent_id: org.PARENTID || null,
          dept_name: org.FULLNAME,
          level: level,
          inner_order: org.INNERORDER,
          ancestors: ancestors, // 将在插入后更新
          parent_udm_id: parentId
        });
        
        // 递归处理子节点
        const newAncestors = ancestors === '0' ? `${ancestors},${nodes.length}` : `${ancestors},${nodes.length}`;
        buildTree(org.ID, level + 1, newAncestors);
      });
    }
    
    // 5. 先插入所有根节点和子节点（ancestors 暂时用临时值）
    console.log('📥 阶段4: 插入数据...');
    
    // 使用批量插入，先不处理 ancestors
    const insertSQL = `
      INSERT INTO organize_dept (
        udm_org_id, udm_org_parent_id, dept_name, level, ancestors, 
        parent_id, order_num, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    `;
    
    // 重新组织：按层级插入，确保 ancestors 正确
    nodes.length = 0;
    
    // 第一步：找出根节点
    const rootNodes = orgs.filter(org => !org.PARENTID);
    console.log(`   找到 ${rootNodes.length} 个根节点\n`);
    
    // 构建完整树结构
    function processNode(orgId, level, ancestorPath) {
      const children = orgs.filter(org => org.PARENTID === orgId);
      
      // 处理当前节点
      const idx = nodes.length + 1;
      const newPath = ancestorPath === '0' ? `${ancestorPath},${idx}` : ancestorPath;
      
      nodes.push({
        udm_org_id: orgId,
        parent_udm_id: orgs.find(o => o.ID === orgId)?.PARENTID || null,
        dept_name: orgs.find(o => o.ID === orgId)?.FULLNAME || '',
        inner_order: orgs.find(o => o.ID === orgId)?.INNERORDER || 0,
        level: level,
        temp_ancestors: ancestorPath // 临时 ancestors
      });
      
      // 按 INNERORDER 排序处理子节点
      children.sort((a, b) => a.INNERORDER - b.INNERORDER);
      children.forEach(child => {
        processNode(child.ID, level + 1, newPath);
      });
    }
    
    // 处理所有根节点
    rootNodes.sort((a, b) => a.INNERORDER - b.INNERORDER);
    rootNodes.forEach(root => {
      processNode(root.ID, 0, '0');
    });
    
    console.log(`   总共 ${nodes.length} 个节点\n`);
    
    // 6. 批量插入数据
    let inserted = 0;
    const batchSize = 500;
    
    for (let i = 0; i < nodes.length; i += batchSize) {
      const batch = nodes.slice(i, i + batchSize);
      const values = batch.map(node => [
        node.udm_org_id,
        node.parent_udm_id,
        node.dept_name,
        node.level,
        node.temp_ancestors, // 临时值
        0, // parent_id 稍后更新
        node.inner_order || 1,
      ]);
      
      for (const v of values) {
        await connection.execute(insertSQL, v);
        inserted++;
      }
      
      if ((i + batchSize) % 1000 === 0 || i + batchSize >= nodes.length) {
        console.log(`   已插入 ${inserted}/${nodes.length} 条`);
      }
    }
    
    // 7. 更新 ancestors 和 parent_id
    console.log('\n🔗 阶段5: 更新 ancestors 和 parent_id...');
    
    // 更新 ancestors（基于实际的 dept_id）
    await connection.execute(`
      UPDATE organize_dept od1
      SET od1.ancestors = (
        SELECT GROUP_CONCAT(t.id ORDER BY t.level)
        FROM (
          SELECT @ids :=
            CASE 
              WHEN od1.parent_id = 0 THEN CAST(od1.id AS CHAR)
              ELSE CONCAT(@ids, ',', od1.id)
            END AS id,
            @ids AS all_ids,
            od1.level
          FROM organize_dept od1
          CROSS JOIN (SELECT @ids := '') AS vars
          WHERE od1.udm_org_id = od1.udm_org_id
          ORDER BY od1.level DESC
        ) AS sub
      )
    `);
    
    // 更简单的方式：重新构建
    console.log('   重新计算 ancestors...');
    
    // 获取所有记录，按 udm_org_id 建立映射
    const [allDepts] = await connection.execute(`
      SELECT dept_id, udm_org_id, udm_org_parent_id 
      FROM organize_dept 
      ORDER BY level, id
    `);
    
    const deptMap = new Map();
    allDepts.forEach(d => deptMap.set(d.udm_org_id, d));
    
    // 构建 ancestors
    async function updateAncestors(orgId, path) {
      const dept = deptMap.get(orgId);
      if (!dept) return;
      
      const newPath = path === '0' ? `0,${dept.dept_id}` : `${path},${dept.dept_id}`;
      
      // 更新当前节点的 ancestors 和 parent_id
      await connection.execute(
        'UPDATE organize_dept SET ancestors = ?, parent_id = ? WHERE dept_id = ?',
        [newPath, path === '0' ? 0 : (path.split(',').pop()), dept.dept_id]
      );
      
      // 更新所有子节点
      for (const [id, d] of deptMap) {
        if (d.udm_org_parent_id === orgId) {
          await updateAncestors(id, newPath);
        }
      }
    }
    
    // 从根节点开始更新
    for (const [id, dept] of deptMap) {
      if (!dept.udm_org_parent_id) {
        await connection.execute(
          'UPDATE organize_dept SET ancestors = "0", parent_id = 0 WHERE dept_id = ?',
          [dept.dept_id]
        );
        // 更新其子节点
        for (const [cid, cdept] of deptMap) {
          if (cdept.udm_org_parent_id === id) {
            await updateAncestors(cid, '0');
          }
        }
      }
    }
    
    console.log('✅ ancestors 和 parent_id 更新完成\n');
    
    // 8. 验证结果
    console.log('📊 阶段6: 验证结果...');
    const [countResult] = await connection.execute('SELECT COUNT(*) as cnt FROM organize_dept');
    console.log(`   总记录数: ${countResult[0].cnt}`);
    
    // 层级分布
    const [levelDist] = await connection.execute(`
      SELECT level, COUNT(*) as cnt 
      FROM organize_dept 
      GROUP BY level 
      ORDER BY level
    `);
    console.log('\n📋 层级分布:');
    console.log('┌────────┬──────────┐');
    console.log('│  层级  │   数量   │');
    console.log('├────────┼──────────┤');
    levelDist.forEach(row => {
      console.log(`│   ${row.level}级   │   ${String(row.cnt).padStart(4)}    │`);
    });
    console.log('└────────┴──────────┘');
    
    // 根节点验证
    const [rootResult] = await connection.execute(`
      SELECT dept_id, dept_name, parent_id, ancestors 
      FROM organize_dept 
      WHERE parent_id = 0 
      LIMIT 5
    `);
    console.log('\n📋 根节点:');
    rootResult.forEach(r => {
      console.log(`   [${r.dept_id}] ${r.dept_name} (ancestors: ${r.ancestors})`);
    });
    
    // 第一层子节点验证
    const [level1Result] = await connection.execute(`
      SELECT od.dept_id, od.dept_name, od.parent_id, od.ancestors, od.order_num
      FROM organize_dept od
      WHERE od.parent_id = (SELECT dept_id FROM organize_dept WHERE parent_id = 0 LIMIT 1)
      ORDER BY od.order_num
      LIMIT 5
    `);
    console.log('\n📋 第1级子节点（按 INNERORDER 排序）:');
    level1Result.forEach(r => {
      console.log(`   [${r.dept_id}] ${r.dept_name} (parent: ${r.parent_id}, ancestors: ${r.ancestors}, order: ${r.order_num})`);
    });
    
    console.log('\n============================================================');
    console.log('🎉 同步任务完成！');
    console.log('============================================================');
    
  } catch (error) {
    console.error('执行失败:', error.message);
    throw error;
  } finally {
    connection.release();
    await pool.end();
  }
}

syncOrganizeDept().catch(console.error);
