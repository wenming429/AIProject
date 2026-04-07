/**
 * 修复 lumenim.sql 表/字段备注乱码问题
 * 解析 SQL 文件中的正确 UTF-8 备注，用 ALTER TABLE 更新到数据库
 * 不删除表、不改变表结构，只修改 COMMENT
 */
const fs = require('fs');
const mysql = require('mysql2/promise');

const mysqlConfig = {
  host: 'localhost', port: 3306,
  user: 'root', password: 'wenming429',
  database: 'go_chat',
  charset: 'utf8mb4'
};

// ============================
// 第一步：解析 SQL 文件，提取正确备注
// ============================
function parseSQLFile(filepath) {
  const content = fs.readFileSync(filepath, 'utf8');
  const tableMap = {};

  const createTableRegex = /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`?(\w+)`?\s*\(([\s\S]*?)\)\s*(?:ENGINE\s*=\s*\w+\s*)?(?:DEFAULT\s+CHARSET\s*=\s*\w+\s*)?(?:COLLATE\s*=\s*\w+\s*)?(?:AUTO_INCREMENT\s*=\s*\d+\s*)?(?:ROW_FORMAT\s*=\s*\w+\s*)?COMMENT\s*=\s*'([^']*)'\s*;?/gi;

  let match;
  while ((match = createTableRegex.exec(content)) !== null) {
    const tableName = match[1];
    const body = match[2];
    const tableComment = match[3] || '';
    const columns = [];

    const lines = body.split(/\n/);
    let currentCol = null;

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed === ',') continue;
      const colMatch = trimmed.match(/^`?(\w+)`?\s+\w+(?:\([^)]+\))?(?:\s+\w+)*\s*(?:COMMENT\s+'([^']*)')?/i);
      if (colMatch) {
        if (currentCol) columns.push(currentCol);
        currentCol = { name: colMatch[1], comment: colMatch[2] || '' };
      }
    }
    if (currentCol) columns.push(currentCol);

    tableMap[tableName] = { comment: tableComment, columns };
  }
  return tableMap;
}

async function getCurrentComments(conn, tableName) {
  const [tableRows] = await conn.query(
    `SELECT TABLE_COMMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME=?`,
    [tableName]
  );
  const [colRows] = await conn.query(
    `SELECT COLUMN_NAME, COLUMN_COMMENT, COLUMN_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME=? ORDER BY ORDINAL_POSITION`,
    [tableName]
  );
  return {
    tableComment: tableRows[0]?.TABLE_COMMENT || '',
    columns: colRows.map(r => ({ name: r.COLUMN_NAME, comment: r.COLUMN_COMMENT || '', type: r.COLUMN_TYPE }))
  };
}

function isGarbled(str) {
  if (!str) return false;
  const hasHighBytes = /[À-ÿ]/.test(str);
  const isNormalChinese = /[\u4e00-\u9fa5]/.test(str);
  return hasHighBytes && !isNormalChinese;
}

async function fixComments(conn, tableName, correctData) {
  const fixes = [];
  const current = await getCurrentComments(conn, tableName);

  // 修复表备注
  const needsTableFix = isGarbled(current.tableComment) ||
    (correctData.comment && current.tableComment !== correctData.comment);

  if (needsTableFix && correctData.comment) {
    const safeComment = correctData.comment.replace(/'/g, "''");
    await conn.query(`ALTER TABLE \`${tableName}\` COMMENT='${safeComment}'`);
    const oldPreview = current.tableComment.substring(0, 20);
    const newPreview = correctData.comment.substring(0, 20);
    fixes.push(`  表备注: "${oldPreview}..." → "${newPreview}..."`);
  }

  // 修复列备注
  for (const col of correctData.columns) {
    const dbCol = current.columns.find(c => c.name === col.name);
    if (!dbCol) continue;

    const needsFix = isGarbled(dbCol.comment) ||
      (col.comment && dbCol.comment !== col.comment);

    if (needsFix && col.comment !== undefined) {
      const safeComment = col.comment.replace(/'/g, "''");
      const colType = dbCol.type;
      await conn.query(
        `ALTER TABLE \`${tableName}\` MODIFY COLUMN \`${col.name}\` ${colType} COMMENT='${safeComment}'`
      );
      const oldPreview = dbCol.comment.substring(0, 20);
      const newPreview = col.comment.substring(0, 20);
      fixes.push(`  ${col.name}: "${oldPreview}..." → "${newPreview}..."`);
    }
  }

  return fixes;
}

async function main() {
  console.log('=== 开始修复表/字段备注乱码 ===\n');

  const sqlFile = './backend/sql/lumenim.sql';
  const parsed = parseSQLFile(sqlFile);
  console.log(`从 SQL 文件解析出 ${Object.keys(parsed).length} 张表的备注信息`);

  const conn = await mysql.createConnection(mysqlConfig);
  await conn.query('SET NAMES utf8mb4');

  let fixedTables = 0;
  let totalTableFixes = 0;
  let totalColFixes = 0;

  for (const [tableName, data] of Object.entries(parsed)) {
    const fixes = await fixComments(conn, tableName, data);
    if (fixes.length > 0) {
      console.log(`\n[${tableName}] 修复了以下备注:`);
      fixes.forEach(f => console.log(f));
      fixedTables++;
      totalTableFixes += fixes.filter(f => f.startsWith('  表备注')).length;
      totalColFixes += fixes.filter(f => !f.startsWith('  表备注')).length;
    }
  }

  await conn.end();

  console.log(`\n=== 修复完成 ===`);
  console.log(`涉及表数: ${fixedTables}`);
  console.log(`表备注修复: ${totalTableFixes}`);
  console.log(`字段备注修复: ${totalColFixes}`);
}

main().catch(e => {
  console.error('错误:', e.message);
  process.exit(1);
});
