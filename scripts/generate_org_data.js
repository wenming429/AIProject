/**
 * 生成组织架构数据
 * 20个部门（树形层级）+ 100个用户 + 岗位分配
 */

const mysql = require('mysql2/promise');

const mysqlConfig = {
  host: 'localhost',
  port: 3306,
  user: 'root',
  password: 'wenming429',
  database: 'go_chat',
  charset: 'utf8mb4',
  connectTimeout: 30000
};

// 部门数据结构（树形）
const deptTree = [
  {
    name: '集团总部',
    leader: '张总',
    children: [
      {
        name: '研发中心',
        leader: '李总监',
        children: [
          { name: '前端开发部', leader: '王经理' },
          { name: '后端开发部', leader: '赵经理' },
          { name: '测试部', leader: '孙经理' },
          { name: '运维部', leader: '周经理' }
        ]
      },
      {
        name: '产品中心',
        leader: '吴总监',
        children: [
          { name: '产品设计部', leader: '郑经理' },
          { name: '用户研究部', leader: '钱经理' }
        ]
      },
      {
        name: '运营中心',
        leader: '陈总监',
        children: [
          { name: '市场部', leader: '冯经理' },
          { name: '销售部', leader: '沈经理' },
          { name: '客服部', leader: '韩经理' }
        ]
      },
      {
        name: '管理中心',
        leader: '杨总监',
        children: [
          { name: '人力资源部', leader: '朱经理' },
          { name: '财务部', leader: '秦经理' },
          { name: '行政部', leader: '尤经理' }
        ]
      },
      {
        name: '华北分公司',
        leader: '许总监',
        children: [
          { name: '北京办事处', leader: '何经理' },
          { name: '天津办事处', leader: '吕经理' }
        ]
      },
      {
        name: '华东分公司',
        leader: '施总监',
        children: [
          { name: '上海办事处', leader: '张经理' },
          { name: '杭州办事处', leader: '孔经理' }
        ]
      },
      {
        name: '华南分公司',
        leader: '曹总监',
        children: [
          { name: '深圳办事处', leader: '严经理' },
          { name: '广州办事处', leader: '华经理' }
        ]
      },
      {
        name: '西南分公司',
        leader: '彭总监',
        children: [
          { name: '成都办事处', leader: '金经理' },
          { name: '重庆办事处', leader: '魏经理' }
        ]
      }
    ]
  }
];

// 岗位列表
const positions = [
  { code: 'CEO', name: '首席执行官' },
  { code: 'CTO', name: '首席技术官' },
  { code: 'CPO', name: '首席产品官' },
  { code: 'COO', name: '首席运营官' },
  { code: 'CFO', name: '首席财务官' },
  { code: 'GM', name: '总经理' },
  { code: 'DIRECTOR', name: '总监' },
  { code: 'MANAGER', name: '经理' },
  { code: 'TECH_LEAD', name: '技术主管' },
  { code: 'SENIOR_DEV', name: '高级开发工程师' },
  { code: 'DEV', name: '开发工程师' },
  { code: 'JUNIOR_DEV', name: '初级开发工程师' },
  { code: 'SENIOR_TEST', name: '高级测试工程师' },
  { code: 'TEST', name: '测试工程师' },
  { code: 'SENIOR_UI', name: '高级UI设计师' },
  { code: 'UI', name: 'UI设计师' },
  { code: 'UX', name: 'UX设计师' },
  { code: 'PRODUCT', name: '产品经理' },
  { code: 'SALES', name: '销售专员' },
  { code: 'MARKETING', name: '市场专员' },
  { code: 'HR', name: '人力资源专员' },
  { code: 'FINANCE', name: '财务专员' },
  { code: 'ADMIN', name: '行政专员' },
  { code: 'CS', name: '客服专员' },
  { code: 'OPS', name: '运维工程师' }
];

// 姓氏和名字
const surnames = '张王李赵刘陈杨黄周吴徐孙马朱胡郭何林罗高郑梁谢宋唐许邓韩冯曹彭曾肖田董潘袁蔡蒋于余杜叶程苏魏吕丁任沈姚卢姜崔钟谭陆汪范金石贾韦夏付方白邹孟熊秦邱江尹薛闫段雷侯龙史黎贺顾毛郝龚邵万钱严覃武戴'.split('');
const names = '伟芳娜敏静丽强磊军洋勇艳杰娟涛明超秀霞平刚桂玲嘉伟慧秀英华明辉斌莉红金飞建梅婷宇鹏雪建华文国平志东晓光林小勇杰涛超秀娟军磊明辉健桂芳敏静丽涛明娜秀霞平刚桂玲建华文国志东晓光宇鹏雪梅婷'.split('');

// 生成随机姓名
function generateName() {
  const surname = surnames[Math.floor(Math.random() * surnames.length)];
  const name = names[Math.floor(Math.random() * names.length)];
  const name2 = Math.random() > 0.5 ? names[Math.floor(Math.random() * names.length)] : '';
  return surname + name + name2;
}

// 生成手机号
function generatePhone() {
  const prefix = ['138', '139', '136', '137', '135', '150', '151', '152', '157', '158', '159', '182', '183', '187', '188'][Math.floor(Math.random() * 15)];
  const suffix = Math.floor(Math.random() * 100000000).toString().padStart(8, '0');
  return prefix + suffix;
}

// 生成邮箱
function generateEmail(name) {
  const domains = ['@company.com', '@lumenim.com', '@work.com'];
  const pinyin = name.charCodeAt(0).toString(36).substring(0, 6);
  return pinyin + Math.floor(Math.random() * 1000) + domains[Math.floor(Math.random() * domains.length)];
}

// 递归生成部门数据
function generateDepts(tree, parentId = 0, ancestors = '0', result = [], startId = 100) {
  let currentId = startId;
  
  for (const node of tree) {
    const dept = {
      dept_id: currentId,
      parent_id: parentId,
      ancestors: ancestors,
      dept_name: node.name,
      leader: node.leader,
      phone: generatePhone(),
      email: generateEmail(node.leader),
      order_num: currentId - startId + 1
    };
    result.push(dept);
    
    if (node.children && node.children.length > 0) {
      const childAncestors = ancestors + ',' + currentId;
      currentId = generateDepts(node.children, currentId, childAncestors, result, currentId + 1);
    } else {
      currentId++;
    }
  }
  
  return currentId;
}

// 生成用户数据
function generateUsers(count, startId = 5000) {
  const users = [];
  const usedPhones = new Set();
  
  for (let i = 0; i < count; i++) {
    let phone;
    do {
      phone = generatePhone();
    } while (usedPhones.has(phone));
    usedPhones.add(phone);
    
    const name = generateName();
    users.push({
      id: startId + i,
      mobile: phone,
      nickname: name,
      password: '',
      avatar: '',
      gender: Math.random() > 0.5 ? 1 : 2,
      motto: '',
      email: generateEmail(name)
    });
  }
  
  return users;
}

// 分配部门和岗位
function assignOrg(users, depts, positions) {
  const orgs = [];
  
  // 岗位权重（某些岗位人数多，某些少）
  const positionWeights = [
    1, 1, 1, 1, 1,  // CEO, CTO, CPO, COO, CFO - 各1人
    4,              // GM - 4个分公司总经理
    8,              // DIRECTOR - 8个总监
    20,             // MANAGER - 20个部门经理
    4,              // TECH_LEAD - 4个技术主管
    10,             // SENIOR_DEV - 10个高级开发
    20,             // DEV - 20个开发
    10,             // JUNIOR_DEV - 10个初级开发
    4,              // SENIOR_TEST - 4个高级测试
    6,              // TEST - 6个测试
    2,              // SENIOR_UI - 2个高级UI
    4,              // UI - 4个UI
    2,              // UX - 2个UX
    4,              // PRODUCT - 4个产品经理
    8,              // SALES - 8个销售
    6,              // MARKETING - 6个市场
    4,              // HR - 4个HR
    4,              // FINANCE - 4个财务
    4,              // ADMIN - 4个行政
    6,              // CS - 6个客服
    4               // OPS - 4个运维
  ];
  
  // 按权重分配岗位
  let userIndex = 0;
  for (let i = 0; i < positions.length && userIndex < users.length; i++) {
    const weight = positionWeights[i] || 1;
    const pos = positions[i];
    
    for (let j = 0; j < weight && userIndex < users.length; j++) {
      // 根据岗位选择部门
      let deptId;
      if (['CEO', 'CFO'].includes(pos.code)) {
        deptId = 100; // 集团总部
      } else if (['CTO', 'TECH_LEAD', 'SENIOR_DEV', 'DEV', 'JUNIOR_DEV', 'OPS'].includes(pos.code)) {
        deptId = depts.filter(d => d.dept_name.includes('开发') || d.dept_name.includes('研发') || d.dept_name.includes('测试') || d.dept_name.includes('运维')).map(d => d.dept_id)[Math.floor(Math.random() * 4)] + 100;
      } else if (['CPO', 'PRODUCT', 'SENIOR_UI', 'UI', 'UX'].includes(pos.code)) {
        deptId = depts.filter(d => d.dept_name.includes('产品') || d.dept_name.includes('设计')).map(d => d.dept_id)[Math.floor(Math.random() * 2)] + 100;
      } else if (['COO', 'SALES', 'MARKETING', 'CS'].includes(pos.code)) {
        deptId = depts.filter(d => d.dept_name.includes('运营') || d.dept_name.includes('市场') || d.dept_name.includes('销售') || d.dept_name.includes('客服')).map(d => d.dept_id)[Math.floor(Math.random() * 3)] + 100;
      } else if (['GM', 'DIRECTOR', 'MANAGER'].includes(pos.code)) {
        deptId = depts[Math.floor(Math.random() * depts.length)].dept_id;
      } else if (['HR'].includes(pos.code)) {
        deptId = depts.find(d => d.dept_name === '人力资源部')?.dept_id || 116;
      } else if (['FINANCE'].includes(pos.code)) {
        deptId = depts.find(d => d.dept_name === '财务部')?.dept_id || 117;
      } else if (['ADMIN'].includes(pos.code)) {
        deptId = depts.find(d => d.dept_name === '行政部')?.dept_id || 118;
      } else if (['SENIOR_TEST', 'TEST'].includes(pos.code)) {
        deptId = depts.find(d => d.dept_name === '测试部')?.dept_id || 103;
      } else {
        deptId = depts[Math.floor(Math.random() * depts.length)].dept_id;
      }
      
      orgs.push({
        user_id: users[userIndex].id,
        dept_id: deptId,
        position_id: i + 1
      });
      
      userIndex++;
    }
  }
  
  // 剩余用户随机分配
  while (userIndex < users.length) {
    const randomPos = Math.floor(Math.random() * positions.length);
    const randomDept = depts[Math.floor(Math.random() * depts.length)].dept_id;
    
    orgs.push({
      user_id: users[userIndex].id,
      dept_id: randomDept,
      position_id: randomPos + 1
    });
    
    userIndex++;
  }
  
  return orgs;
}

async function main() {
  console.log('=== 组织架构数据生成开始 ===');
  console.log(`时间: ${new Date().toLocaleString()}\n`);

  let mysqlConn;

  try {
    console.log('连接 MySQL...');
    mysqlConn = await mysql.createConnection(mysqlConfig);
    await mysqlConn.query('SET NAMES utf8mb4');
    console.log('MySQL 连接成功\n');

    // 1. 生成部门数据
    console.log('生成部门数据...');
    const depts = [];
    generateDepts(deptTree, 0, '0', depts, 100);
    console.log(`✅ 生成了 ${depts.length} 个部门\n`);

    // 2. 生成岗位数据
    console.log('生成岗位数据...');
    const positionData = positions.map((p, i) => ({
      position_id: i + 1,
      post_code: p.code,
      post_name: p.name,
      sort: i + 1,
      status: 1,
      remark: p.name,
      created_at: new Date(),
      updated_at: new Date()
    }));
    console.log(`✅ 生成了 ${positionData.length} 个岗位\n`);

    // 3. 生成用户数据
    console.log('生成用户数据...');
    const users = generateUsers(100, 5000);
    console.log(`✅ 生成了 ${users.length} 个用户\n`);

    // 4. 分配组织关系
    console.log('分配组织关系...');
    const orgs = assignOrg(users, depts, positions);
    console.log(`✅ 分配了 ${orgs.length} 条组织关系\n`);

    // 5. 清空并插入数据
    console.log('清空旧数据...');
    await mysqlConn.query('DELETE FROM organize WHERE user_id >= 5000');
    await mysqlConn.query('DELETE FROM users WHERE id >= 5000');
    await mysqlConn.query('DELETE FROM organize_dept WHERE dept_id >= 100');
    await mysqlConn.query('DELETE FROM organize_position WHERE position_id >= 1 AND position_id <= 25');
    console.log('✅ 旧数据已清空\n');

    // 6. 插入岗位
    console.log('插入岗位数据...');
    for (const pos of positionData) {
      await mysqlConn.query(
        `INSERT INTO organize_position (position_id, post_code, post_name, sort, status, remark, created_at, updated_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [pos.position_id, pos.post_code, pos.post_name, pos.sort, pos.status, pos.remark, pos.created_at, pos.updated_at]
      );
    }
    console.log(`✅ 插入 ${positionData.length} 个岗位\n`);

    // 7. 插入部门
    console.log('插入部门数据...');
    for (const dept of depts) {
      await mysqlConn.query(
        `INSERT INTO organize_dept (dept_id, parent_id, ancestors, dept_name, order_num, leader, phone, email, status, is_deleted, created_at, updated_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, 2, NOW(), NOW())`,
        [dept.dept_id, dept.parent_id, dept.ancestors, dept.dept_name, dept.order_num, dept.leader, dept.phone, dept.email]
      );
    }
    console.log(`✅ 插入 ${depts.length} 个部门\n`);

    // 8. 插入用户
    console.log('插入用户数据...');
    for (const user of users) {
      await mysqlConn.query(
        `INSERT INTO users (id, mobile, nickname, password, avatar, gender, motto, email) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [user.id, user.mobile, user.nickname, user.password, user.avatar, user.gender, user.motto, user.email]
      );
    }
    console.log(`✅ 插入 ${users.length} 个用户\n`);

    // 9. 插入组织关系
    console.log('插入组织关系...');
    for (const org of orgs) {
      await mysqlConn.query(
        `INSERT INTO organize (user_id, dept_id, position_id, created_at, updated_at) 
         VALUES (?, ?, ?, NOW(), NOW())`,
        [org.user_id, org.dept_id, org.position_id]
      );
    }
    console.log(`✅ 插入 ${orgs.length} 条组织关系\n`);

    // 10. 显示部门树
    console.log('=== 部门架构 ===');
    function printDeptTree(parentId = 0, indent = '') {
      const children = depts.filter(d => d.parent_id === parentId);
      for (const child of children) {
        const userCount = orgs.filter(o => o.dept_id === child.dept_id).length;
        console.log(`${indent}${child.dept_id}. ${child.dept_name} (${userCount}人) - ${child.leader}`);
        printDeptTree(child.dept_id, indent + '  ');
      }
    }
    printDeptTree();

    // 11. 统计
    console.log('\n=== 数据统计 ===');
    const [deptCount] = await mysqlConn.query('SELECT COUNT(*) as cnt FROM organize_dept');
    const [posCount] = await mysqlConn.query('SELECT COUNT(*) as cnt FROM organize_position');
    const [userCount] = await mysqlConn.query('SELECT COUNT(*) as cnt FROM users WHERE id >= 5000');
    const [orgCount] = await mysqlConn.query('SELECT COUNT(*) as cnt FROM organize WHERE user_id >= 5000');

    console.log(`部门总数: ${deptCount[0].cnt}`);
    console.log(`岗位总数: ${posCount[0].cnt}`);
    console.log(`用户总数: ${userCount[0].cnt}`);
    console.log(`组织关系: ${orgCount[0].cnt}`);

    console.log('\n=== 生成完成 ===');

  } catch (err) {
    console.error('\n❌ 错误:', err.message);
    console.error(err.stack);
    process.exit(1);
  } finally {
    if (mysqlConn) await mysqlConn.end();
  }
}

main();
