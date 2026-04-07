/**
 * 基于 init_organization_dept 视图初始化 organize_dept 表（最终版）
 * ancestors 格式: 逗号分隔
 * - 根节点: ancestors = "0"
 * - 子节点: ancestors = "0,父节点dept_id"
 */

const mysql = require('mysql2/promise');

const DB_CONFIG = {
  host: 'localhost',
  user: 'root',
  password: 'wenming429',
  database: 'go_chat'
};

async function syncOrganizeDept() {
  const pool = mysql.createPool(DB_CONFIG);
  const conn = await pool.getConnection();
  
  try {
    console.log('============================================================');
    console.log('🏢 init_organization_dept → organize_dept 同步程序');
    console.log('ancestors 格式: 逗号分隔 (0,1,2)');
    console.log('============================================================\n');
    
    const startTime = Date.now();
    
    // 1. 清空并重置
    console.log('📡 阶段1: 清空目标表...');
    await conn.execute('DELETE FROM organize_dept');
    await conn.execute('ALTER TABLE organize_dept AUTO_INCREMENT = 1');
    console.log('✅ 完成\n');
    
    // 2. 查询源数据
    console.log('🔍 阶段2: 查询源数据...');
    const [orgs] = await conn.execute(`
      SELECT ID, PARENTID, FULLNAME, FULLPATHCODE, INNERORDER
      FROM init_organization_dept
      ORDER BY FULLPATHCODE ASC
    `);
    console.log(`   查询到 ${orgs.length} 条数据\n`);
    
    // 3. 构建树结构
    console.log('🌳 阶段3: 构建树结构...');
    
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
    
    // 递归插入并计算 ancestors
    const allNodes = [];
    let globalIdx = 0;
    
    function processNode(node, ancestors, parentId) {
      globalIdx++;
      const currentId = globalIdx;
      
      // ancestors 格式：
      // - 根节点: "0"
      // - 子节点: "0,父节点dept_id"
      const nodeAncestors = parentId === 0 ? '0' : `${ancestors},${parentId}`;
      
      allNodes.push({
        udm_id: node.udm_id,
        parent_udm_id: node.parent_udm_id,
        name: node.name,
        order: node.order,
        ancestors: nodeAncestors,
        parent_id: parentId
      });
      
      // 按 INNERORDER 排序子节点
      node.children.sort((a, b) => a.order - b.order);
      node.children.forEach(child => {
        processNode(child, nodeAncestors, currentId);
      });
    }
    
    // 处理所有根节点
    roots.sort((a, b) => a.order - b.order);
    roots.forEach(root => {
      processNode(root, '0', 0);
    });
    
    console.log(`   构建完成，共 ${allNodes.length} 个节点\n`);
    
    // 4. 批量插入
    console.log('📥 阶段4: 插入数据...');
    for (const node of allNodes) {
      await conn.execute(
        `INSERT INTO organize_dept (udm_org_id, udm_org_parent_id, dept_name, ancestors, parent_id, order_num, leader, phone, email, status, is_deleted) 
         VALUES (?, ?, ?, ?, ?, ?, '', '', '', 1, 2)`,
        [node.udm_id, node.parent_udm_id, node.name, node.ancestors, node.parent_id, node.order]
      );
    }
    console.log(`   ✅ 插入完成: ${allNodes.length} 条\n`);
    
    // 5. 验证
    console.log('📊 阶段5: 验证结果...');
    const [cnt] = await conn.execute('SELECT COUNT(*) as cnt FROM organize_dept');
    console.log(`   总记录数: ${cnt[0].cnt}`);
    
    const [rootsResult] = await conn.execute('SELECT dept_id, dept_name, ancestors FROM organize_dept WHERE parent_id = 0');
    console.log('\n📋 根节点:');
    rootsResult.forEach(r => console.log(`   [${r.dept_id}] ${r.dept_name} (ancestors: ${r.ancestors})`));
    
    const [l1] = await conn.execute(`
      SELECT d.dept_id, d.dept_name, d.ancestors, d.order_num 
      FROM organize_dept d 
      WHERE d.parent_id = 1
      ORDER BY d.order_num 
      LIMIT 5
    `);
    console.log('\n📋 第1级子节点 (父节点 dept_id=1):');
    l1.forEach(r => console.log(`   [${r.dept_id}] ${r.dept_name} (ancestors: ${r.ancestors}, order: ${r.order_num})`));
    
    const [l2] = await conn.execute(`
      SELECT d.dept_id, d.dept_name, d.ancestors 
      FROM organize_dept d 
      WHERE d.parent_id = 2
      ORDER BY d.order_num 
      LIMIT 3
    `);
    console.log('\n📋 第2级子节点 (父节点 dept_id=2):');
    l2.forEach(r => console.log(`   [${r.dept_id}] ${r.dept_name} (ancestors: ${r.ancestors})`));
    
    const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
    console.log(`\n============================================================`);
    console.log(`🎉 同步完成！耗时: ${elapsed}s`);
    console.log(`============================================================`);
    
  } finally {
    conn.release();
    await pool.end();
  }
}

syncOrganizeDept().catch(err => {
  console.error('失败:', err.message);
  process.exit(1);
});
