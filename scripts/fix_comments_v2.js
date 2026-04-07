/**
 * 修复 lumenim.sql 表/字段备注乱码问题 v2
 * 改进解析逻辑，覆盖所有 SQL 格式
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
// 解析 SQL 文件，提取所有表的正确备注
// ============================
function parseSQLFile(filepath) {
  const content = fs.readFileSync(filepath, 'utf8');
  const tableMap = {};

  // 匹配 CREATE TABLE 语句 (可能有换行)
  const createRegex = /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?[`"']?(\w+)[`"']?\s*\(([\s\S]*?)\)\s*ENGINE/gi;
  let match;
  while ((match = createRegex.exec(content)) !== null) {
    const tableName = match[1];
    const body = match[2];

    // 提取表级别的 COMMENT
    const tableCommentMatch = body.match(/COMMENT\s*=\s*['"]([^'"]*)['"]/i);
    const tableComment = tableCommentMatch ? tableCommentMatch[1] : '';

    const columns = [];

    // 逐行解析列定义
    const lines = body.split(/\n/);
    let buffer = '';

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;

      // 跳过表级别的约束语句 (PRIMARY KEY, UNIQUE KEY, KEY, CONSTRAINT 等)
      if (/^(PRIMARY|UNIQUE|FULLTEXT|CHECK|CONSTRAINT|KEY)\s+KEY/i.test(trimmed)) {
        continue;
      }

      buffer += ' ' + trimmed;

      // 列定义结束条件：COMMENT 'xxx' 后有逗号，或者以 PRIMARY/UNIQUE/KEY 开头
      const endsHere = trimmed.endsWith(',') || /^(PRIMARY|UNIQUE|KEY)\s+KEY/i.test(trimmed);

      if (buffer.trim()) {
        // 提取列名和 COMMENT
        const colMatch = buffer.match(/^`?(\w+)`?\s+\S+(?:\([^)]+\))?(?:\s+(?:UNSIGNED|SIGNED|ZEROFILL))*[^,]*\s*(?:COMMENT\s+['"]([^'"]*)['"])?/i);
        if (colMatch && !/^(PRIMARY|UNIQUE|KEY|CONSTRAINT|INDEX)$/i.test(colMatch[1])) {
          columns.push({ name: colMatch[1], comment: colMatch[2] || '' });
        }
        buffer = '';
      }
    }

    // 处理最后一列（可能没有逗号结尾）
    if (buffer.trim()) {
      const colMatch = buffer.match(/^`?(\w+)`?\s+\S+(?:\([^)]+\))?(?:\s+(?:UNSIGNED|SIGNED|ZEROFILL))*[^,]*\s*(?:COMMENT\s+['"]([^'"]*)['"])?/i);
      if (colMatch && !/^(PRIMARY|UNIQUE|KEY|CONSTRAINT|INDEX)$/i.test(colMatch[1])) {
        const exists = columns.find(c => c.name === colMatch[1]);
        if (!exists) {
          columns.push({ name: colMatch[1], comment: colMatch[2] || '' });
        }
      }
    }

    tableMap[tableName] = { comment: tableComment, columns };
    console.log(`解析: ${tableName} -> 表备注:"${tableComment}", ${columns.length} 列`);
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
    fixes.push(`  表备注: "${current.tableComment.substring(0,25)}..." → "${correctData.comment}"`);
  }

  // 修复列备注
  for (const col of correctData.columns) {
    const dbCol = current.columns.find(c => c.name === col.name);
    if (!dbCol) continue;

    const needsFix = isGarbled(dbCol.comment) ||
      (col.comment && dbCol.comment !== col.comment);

    if (needsFix && col.comment !== undefined) {
      const safeComment = col.comment.replace(/'/g, "''");
      await conn.query(
        `ALTER TABLE \`${tableName}\` MODIFY COLUMN \`${col.name}\` ${dbCol.type} COMMENT='${safeComment}'`
      );
      const oldP = dbCol.comment.substring(0, 15);
      const newP = col.comment.substring(0, 15);
      fixes.push(`  ${col.name}: "${oldP}..." → "${newP}..."`);
    }
  }

  return fixes;
}

async function main() {
  console.log('=== 开始修复表/字段备注乱码 v2 ===\n');

  const sqlFile = './backend/sql/lumenim.sql';
  const parsed = parseSQLFile(sqlFile);
  console.log(`\n共解析 ${Object.keys(parsed).length} 张表\n`);

  const conn = await mysql.createConnection(mysqlConfig);
  await conn.query('SET NAMES utf8mb4');

  let fixedTables = 0;
  let totalTableFixes = 0;
  let totalColFixes = 0;

  for (const [tableName, data] of Object.entries(parsed)) {
    const fixes = await fixComments(conn, tableName, data);
    if (fixes.length > 0) {
      console.log(`\n[${tableName}] 修复:`);
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
  console.error('错误:', e.message, e.stack);
  process.exit(1);
});
