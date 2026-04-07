/**
 * 重新计算 organize_dept 表的 ancestors 字段
 * ancestors 格式: 逗号分隔，存储 dept_id 路径
 */

const mysql = require('mysql2/promise');

const DB_CONFIG = {
  host: 'localhost',
  user: 'root',
  password: 'wenming429',
  database: 'go_chat'
};

async function fixAncestors() {
  const pool = mysql.createPool(DB_CONFIG);
  const conn = await pool.getConnection();
  
  try {
    console.log('============================================================');
    console.log('🔄 重新计算 organize_dept.ancestors');
    console.log('============================================================\n');
    
    // 1. 获取所有记录
    const [depts] = await conn.execute(`
      SELECT dept_id, udm_org_id, udm_org_parent_id 
      FROM organize_dept 
      ORDER BY dept_id
    `);
    
    // 2. 构建映射
    const deptByUdmId = new Map();
    const deptById = new Map();
    depts.forEach(d => {
      deptByUdmId.set(d.udm_org_id, d);
      deptById.set(d.dept_id, d);
    });
    
    // 3. 递归计算 ancestors
    function getAncestors(dept) {
      const path = [];
      let current = dept;
      while (current) {
        path.unshift(current.dept_id);
        if (current.udm_org_parent_id) {
          current = deptByUdmId.get(current.udm_org_parent_id);
        } else {
          current = null;
        }
      }
      return path.join(',');
    }
    
    // 4. 更新所有记录的 ancestors
    console.log('📥 更新 ancestors...');
    let count = 0;
    for (const dept of depts) {
      const ancestors = getAncestors(dept);
      await conn.execute(
        'UPDATE organize_dept SET ancestors = ? WHERE dept_id = ?',
        [ancestors, dept.dept_id]
      );
      count++;
      if (count % 500 === 0) {
        console.log(`   已更新 ${count}/${depts.length} 条`);
      }
    }
    console.log(`✅ 更新完成: ${count} 条\n`);
    
    // 5. 验证
    console.log('📋 验证结果:');
    const [roots] = await conn.execute(`
      SELECT dept_id, dept_name, ancestors 
      FROM organize_dept 
      WHERE parent_id = 0 
      LIMIT 3
    `);
    console.log('\n根节点:');
    roots.forEach(r => console.log(`   [${r.dept_id}] ${r.dept_name} (ancestors: ${r.ancestors})`));
    
    const [l1] = await conn.execute(`
      SELECT d.dept_id, d.dept_name, d.ancestors, d.order_num 
      FROM organize_dept d 
      WHERE d.parent_id = (SELECT dept_id FROM organize_dept WHERE parent_id = 0 LIMIT 1)
      ORDER BY d.order_num 
      LIMIT 5
    `);
    console.log('\n第1级子节点:');
    l1.forEach(r => console.log(`   [${r.dept_id}] ${r.dept_name} (ancestors: ${r.ancestors}, order: ${r.order_num})`));
    
    console.log('\n============================================================');
    console.log('🎉 完成！');
    console.log('============================================================');
    
  } finally {
    conn.release();
    await pool.end();
  }
}

fixAncestors().catch(err => {
  console.error('失败:', err.message);
  process.exit(1);
});
