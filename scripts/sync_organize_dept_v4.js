/**
 * 基于 init_organization_dept 视图初始化 organize_dept 表
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
    
    // 3. 构建 ID → 索引映射
    const idToIdx = new Map();
    orgs.forEach((org, idx) => idToIdx.set(org.ID, idx));
    
    // 4. 计算 ancestors
    console.log('🌳 阶段3: 构建树结构...');
    const nodes = orgs.map((org, idx) => {
      const parts = (org.FULLPATHCODE || '').split('||').filter(p => p.trim());
      let ancestors = '0';
      if (parts.length > 1) {
        const pos = parts.indexOf(org.ID);
        if (pos > 0) {
          const parentIds = parts.slice(0, pos);
          const ancestorIndices = parentIds
            .map(pid => idToIdx.get(pid))
            .filter(i => i !== undefined)
            .map(i => i + 1);
          if (ancestorIndices.length > 0) {
            ancestors = '0,' + ancestorIndices.join(',');
          }
        }
      }
      return {
        id: org.ID,
        parentId: org.PARENTID || null,
        name: org.FULLNAME,
        innerOrder: org.INNERORDER || 0,
        ancestors: ancestors
      };
    });
    console.log(`   构建完成，共 ${nodes.length} 个节点\n`);
    
    // 5. 逐条插入（设置默认值，处理 order_num 溢出）
    console.log('📥 阶段4: 插入数据...');
    let totalInserted = 0;
    
    for (const node of nodes) {
      // 处理 order_num：如果超过 int 范围则设为 1
      const orderNum = node.innerOrder > 2147483647 ? 1 : (node.innerOrder || 1);
      await conn.execute(
        `INSERT INTO organize_dept (udm_org_id, udm_org_parent_id, dept_name, ancestors, order_num, leader, phone, email, status, is_deleted) 
         VALUES (?, ?, ?, ?, ?, '', '', '', 1, 2)`,
        [node.id, node.parentId, node.name, node.ancestors, orderNum]
      );
      totalInserted++;
      if (totalInserted % 500 === 0) {
        console.log(`   已插入 ${totalInserted}/${nodes.length} 条`);
      }
    }
    console.log(`   ✅ 插入完成: ${totalInserted} 条\n`);
    
    // 6. 更新 parent_id
    console.log('🔗 阶段5: 更新 parent_id...');
    await conn.execute(`
      UPDATE organize_dept od1
      INNER JOIN organize_dept od2 ON od1.udm_org_parent_id = od2.udm_org_id
      SET od1.parent_id = od2.dept_id
    `);
    console.log('✅ parent_id 更新完成\n');
    
    // 7. 验证
    console.log('📊 阶段6: 验证结果...');
    const [cnt] = await conn.execute('SELECT COUNT(*) as cnt FROM organize_dept');
    console.log(`   总记录数: ${cnt[0].cnt}`);
    
    const [roots] = await conn.execute('SELECT dept_id, dept_name, ancestors FROM organize_dept WHERE parent_id = 0');
    console.log('\n📋 根节点:');
    roots.forEach(r => console.log(`   [${r.dept_id}] ${r.dept_name} (ancestors: ${r.ancestors})`));
    
    const [l1] = await conn.execute(`
      SELECT d.dept_id, d.dept_name, d.ancestors, d.order_num 
      FROM organize_dept d WHERE d.parent_id IN (SELECT dept_id FROM organize_dept WHERE parent_id = 0)
      ORDER BY d.order_num LIMIT 5
    `);
    console.log('\n📋 第1级子节点:');
    l1.forEach(r => console.log(`   [${r.dept_id}] ${r.dept_name} (ancestors: ${r.ancestors}, order: ${r.order_num})`));
    
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
  console.error('执行失败:', err.message);
  process.exit(1);
});
