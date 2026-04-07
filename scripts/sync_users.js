/**
 * 同步 init_users 到 users 表
 * - 按照 EEMPLOYEEID, ORDERBY 升序插入
 * - 清空 users 表并重置自增 ID
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

async function syncUsers() {
  const pool = mysql.createPool(DB_CONFIG);
  const connection = await pool.getConnection();
  
  try {
    console.log('=== 开始同步 users 表 ===\n');
    
    // 1. 清空 users 表
    console.log('1. 清空 users 表...');
    await connection.execute('DELETE FROM users');
    await connection.execute('ALTER TABLE users AUTO_INCREMENT = 1');
    console.log('   ✓ users 表已清空，自增 ID 已重置\n');
    
    // 2. 直接使用 INSERT ... SELECT（最高效的方式）
    console.log('2. 执行 INSERT ... SELECT...');
    const startTime = Date.now();
    
    await connection.execute(`
      INSERT INTO users (
        userid, username, mobile, nickname, avatar, gender, 
        password, motto, email, birthday, status, is_robot,
        created_at, updated_at
      )
      SELECT 
        EEMPLOYEEID as userid,
        LOGINNAME AS username,
        IFNULL(PHONE, '') AS mobile,
        FULLNAME AS nickname,
        '' AS avatar,
        CASE IFNULL(UPPER(Gender), 'U')
          WHEN 'M' THEN 1
          WHEN 'F' THEN 2
          ELSE 3
        END AS gender,
        '$2a$10$MDkzvCBC4rSxfUFR81lZGu3EqiYBLRP4t6UoYoWmcqovZZc4PkDTW' AS password,
        '心有理想，鲜花盛开~~' AS motto,
        IFNULL(EMAIL, '') AS email,
        IFNULL(DATE_FORMAT(BIRTHDAY, '%Y-%m-%d'), '1970-01-01') AS birthday,
        1 AS status,
        2 AS is_robot,
        NOW() AS created_at,
        NOW() AS updated_at
      FROM init_users
      ORDER BY EEMPLOYEEID, ORDERBY
    `);
    
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);
    
    // 3. 验证结果
    const [result] = await connection.execute('SELECT COUNT(*) as cnt FROM users');
    console.log(`   ✓ 插入完成，耗时 ${duration}s\n`);
    
    console.log('=== 同步完成 ===');
    console.log(`总记录数: ${result[0].cnt}`);
    
    // 显示前10条数据验证排序
    const [samples] = await connection.execute(`
      SELECT id, userid, username, nickname, gender, status, is_robot 
      FROM users 
      ORDER BY id 
      LIMIT 10
    `);
    console.log('\n前10条数据（验证排序）:');
    console.table(samples);
    
    // 显示最后5条数据
    const [lastSamples] = await connection.execute(`
      SELECT id, userid, username, nickname, gender, status, is_robot 
      FROM users 
      ORDER BY id DESC
      LIMIT 5
    `);
    console.log('\n最后5条数据:');
    console.table(lastSamples);
    
  } catch (error) {
    console.error('执行失败:', error.message);
    throw error;
  } finally {
    connection.release();
    await pool.end();
  }
}

syncUsers().catch(console.error);
