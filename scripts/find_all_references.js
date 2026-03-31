const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

async function analyze() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
  });

  // 目标主键列
  const pkCols = {
    'users': 'id',
    'organize': ['id', 'dept_id', 'position_id'],
    'organize_dept': 'dept_id',
    'organize_position': 'position_id'
  };

  // 收集所有可能的关联字段名（基于常见命名约定）
  const possibleFieldNames = [];
  for (const [tbl, pks] of Object.entries(pkCols)) {
    if (Array.isArray(pks)) {
      for (const pk of pks) {
        possibleFieldNames.push(pk);
        possibleFieldNames.push(pk.replace('_id', ''));
      }
    } else {
      possibleFieldNames.push(pks);
      possibleFieldNames.push(pks.replace('_id', ''));
    }
  }
  const uniqueFields = [...new Set(possibleFieldNames)];
  console.log('可能的关联字段名:', uniqueFields);

  // 查找 lumenim.sql 中的所有 CREATE TABLE 语句
  const sql = fs.readFileSync(path.join(__dirname, '../backend/sql/lumenim.sql'), 'utf8');
  const tableStmts = sql.split(';').filter(s => s.trim().toUpperCase().startsWith('CREATE TABLE'));
  console.log('\n共', tableStmts.length, '个 CREATE TABLE');

  const refPattern = /REFERENCES\s+`?(\w+)`?\s*\(/gi;
  const colPattern = /`?(\w+)`?\s+(?:bigint|int(?:eger)?|tinyint|varchar)/gi;

  // 分析每个表
  for (const stmt of tableStmts) {
    const tblMatch = stmt.match(/CREATE TABLE `?(\w+)`?/i);
    if (!tblMatch) continue;
    const tblName = tblMatch[1];
    if (['users', 'organize', 'organize_dept', 'organize_position'].includes(tblName)) continue;

    // 找 REFERENCES 子句
    const refs = [...stmt.matchAll(refPattern)].map(m => m[1]);
    const relevantRefs = refs.filter(r => ['users', 'organize', 'organize_dept', 'organize_position'].includes(r));

    // 找列定义中的所有字段
    const allCols = [...stmt.matchAll(colPattern)].map(m => m[1]);

    // 检查是否有字段名类似 id / user_id / dept_id / position_id 等
    const hasRef = allCols.some(c => {
      const lower = c.toLowerCase();
      return lower === 'id' || lower === 'user_id' || lower === 'dept_id' ||
             lower === 'position_id' || lower === 'creator_id' ||
             lower === 'create_user' || lower === 'owner_id' ||
             lower === 'belong_id' || lower.includes('_uid') || lower.endsWith('_id');
    });

    if (relevantRefs.length > 0 || hasRef) {
      console.log('\n表:', tblName);
      console.log('  REFERENCES:', relevantRefs);
      console.log('  关联字段(推断):', allCols.filter(c => {
        const lower = c.toLowerCase();
        return lower === 'id' || lower === 'user_id' || lower === 'dept_id' ||
               lower === 'position_id' || lower === 'creator_id' ||
               lower === 'create_user' || lower === 'owner_id' ||
               lower === 'belong_id' || lower.includes('_uid') || lower.endsWith('_id');
      }));
    }
  }

  await conn.end();
}
analyze().catch(console.error);
