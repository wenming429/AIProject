/**
 * 查看数据库表结构
 * 用于分析 UDMOrganization 和 organize_dept 的字段映射
 */

const mysql = require('mysql2/promise');

const MYSQL_CONFIG = {
  host: 'localhost',
  port: 3306,
  user: 'root',
  password: 'wenming429',
  database: 'go_chat',
  charset: 'utf8mb4',
};

async function checkTableStructure() {
  const conn = await mysql.createConnection(MYSQL_CONFIG);

  try {
    // 查看 UDMOrganization 表结构
    console.log('\n========== UDMOrganization 表结构 ==========\n');
    const [udmCols] = await conn.execute('SHOW FULL COLUMNS FROM `UDMOrganization`');
    console.log('字段名            | 类型              | 可空  | 默认值              | 注释');
    console.log('-'.repeat(85));
    for (const col of udmCols) {
      console.log(
        `${String(col.Field).padEnd(18)} | ${String(col.Type).padEnd(18)} | ${String(col.Null).padEnd(5)} | ${String(col.Default || '').padEnd(20)} | ${col.Comment || ''}`
      );
    }

    // 查看 organize_dept 表结构
    console.log('\n\n========== organize_dept 表结构 ==========\n');
    const [deptCols] = await conn.execute('SHOW FULL COLUMNS FROM `organize_dept`');
    console.log('字段名            | 类型              | 可空  | 默认值              | 注释');
    console.log('-'.repeat(85));
    for (const col of deptCols) {
      console.log(
        `${String(col.Field).padEnd(18)} | ${String(col.Type).padEnd(18)} | ${String(col.Null).padEnd(5)} | ${String(col.Default || '').padEnd(20)} | ${col.Comment || ''}`
      );
    }

    // 查看数据统计
    console.log('\n\n========== 数据统计 ==========\n');
    const [udmCount] = await conn.execute('SELECT COUNT(*) as cnt FROM `UDMOrganization`');
    const [deptCount] = await conn.execute('SELECT COUNT(*) as cnt FROM `organize_dept`');
    const [activeDept] = await conn.execute("SELECT COUNT(*) as cnt FROM `organize_dept` WHERE is_deleted = 2");
    console.log(`UDMOrganization: ${udmCount[0].cnt} 条记录`);
    console.log(`organize_dept: ${deptCount[0].cnt} 条记录 (有效: ${activeDept[0].cnt})`);

    // 查看样本数据
    console.log('\n\n========== UDMOrganization 样本数据 ==========\n');
    const [udmSample] = await conn.execute('SELECT * FROM `UDMOrganization` LIMIT 5');
    console.table(udmSample);

    console.log('\n\n========== organize_dept 样本数据 ==========\n');
    const [deptSample] = await conn.execute('SELECT * FROM `organize_dept` LIMIT 5');
    console.table(deptSample);

  } finally {
    await conn.end();
  }
}

checkTableStructure().catch(console.error);
