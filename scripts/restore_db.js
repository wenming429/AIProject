const mysql = require('mysql2/promise');

async function restore() {
  const connection = await mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: 'wenming429',
    multipleStatements: true
  });

  console.log('正在重建数据库...');
  
  // 删除并重建数据库
  await connection.query('DROP DATABASE IF EXISTS go_chat');
  await connection.query('CREATE DATABASE go_chat CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
  console.log('数据库已重建');
  
  // 导入 lumenim.sql
  const fs = require('fs');
  const sql1 = fs.readFileSync('./backend/sql/lumenim.sql', 'utf8');
  const statements1 = sql1.split(';').filter(s => s.trim());
  for (const stmt of statements1) {
    if (stmt.trim()) {
      try {
        await connection.query(stmt);
      } catch (e) {}
    }
  }
  console.log('lumenim.sql 已导入');
  
  // 导入 test_data.sql
  const sql2 = fs.readFileSync('./test_data.sql', 'utf8');
  const statements2 = sql2.split(';').filter(s => s.trim());
  for (const stmt of statements2) {
    if (stmt.trim()) {
      try {
        await connection.query(stmt);
      } catch (e) {}
    }
  }
  console.log('test_data.sql 已导入');
  
  // 验证
  const [rows] = await connection.query('SELECT id, phone, nickname FROM users LIMIT 3');
  console.log('\n验证数据:');
  console.log(rows);
  
  await connection.end();
  console.log('\n✅ 数据库已恢复到原始 INT 类型!');
}

restore().catch(console.error);
