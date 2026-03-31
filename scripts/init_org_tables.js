/**
 * 初始化组织、部门、岗位表
 */

const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

const mysqlConfig = {
  host: 'localhost',
  port: 3306,
  user: 'root',
  password: 'wenming429',
  database: 'go_chat',
  charset: 'utf8mb4',
  connectTimeout: 30000,
  multipleStatements: true
};

async function main() {
  console.log('=== 组织、部门、岗位表初始化开始 ===');
  console.log(`时间: ${new Date().toLocaleString()}\n`);

  let mysqlConn;

  try {
    console.log('连接 MySQL...');
    mysqlConn = await mysql.createConnection(mysqlConfig);
    await mysqlConn.query('SET NAMES utf8mb4');
    console.log('MySQL 连接成功\n');

    // 读取SQL文件
    const sqlFile = path.join(__dirname, '..', 'system_data.sql');
    const sqlContent = fs.readFileSync(sqlFile, 'utf8');
    console.log(`SQL文件读取成功: ${sqlFile}`);

    // 执行SQL
    console.log('执行数据初始化...\n');
    await mysqlConn.query(sqlContent);

    // 查询结果验证
    console.log('验证数据...\n');
    
    const [deptRows] = await mysqlConn.query('SELECT COUNT(*) as cnt FROM organize_dept');
    console.log(`✅ organize_dept (部门表): ${deptRows[0].cnt} 条记录`);

    const [positionRows] = await mysqlConn.query('SELECT COUNT(*) as cnt FROM organize_position');
    console.log(`✅ organize_position (岗位表): ${positionRows[0].cnt} 条记录`);

    const [organizeRows] = await mysqlConn.query('SELECT COUNT(*) as cnt FROM organize');
    console.log(`✅ organize (组织关系表): ${organizeRows[0].cnt} 条记录`);

    // 显示部门详情
    console.log('\n--- 部门列表 ---');
    const [depts] = await mysqlConn.query('SELECT dept_id, dept_name, parent_id FROM organize_dept ORDER BY dept_id');
    depts.forEach(d => {
      const indent = d.parent_id === 0 ? '' : '  ';
      console.log(`${indent}${d.dept_id}. ${d.dept_name}`);
    });

    // 显示岗位详情
    console.log('\n--- 岗位列表 ---');
    const [positions] = await mysqlConn.query('SELECT position_id, post_name FROM organize_position ORDER BY position_id');
    positions.forEach(p => {
      console.log(`${p.position_id}. ${p.post_name}`);
    });

    console.log('\n=== 初始化完成 ===');

  } catch (err) {
    console.error('\n❌ 错误:', err.message);
    process.exit(1);
  } finally {
    if (mysqlConn) await mysqlConn.end();
  }
}

main();
