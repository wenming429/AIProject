/**
 * 修复 lumenim.sql 表/字段备注乱码问题 v3
 * 逐句解析 SQL，正确处理嵌套括号
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
// 查找 body 中最后一对 () 内的内容（表定义部分）
// ============================
function findTableBody(createStmt) {
  const start = createStmt.indexOf('(');
  if (start === -1) return '';
  let depth = 0;
  let end = start;
  for (let i = start; i < createStmt.length; i++) {
    if (createStmt[i] === '(') depth++;
    else if (createStmt[i] === ')') {
      depth--;
      if (depth === 0) { end = i; break; }
    }
  }
  return createStmt.substring(start + 1, end);
}

// ============================
// 解析 SQL 文件，提取所有表的正确备注
// ============================
function parseSQLFile(filepath) {
  const content = fs.readFileSync(filepath, 'utf8');
  const tableMap = {};

  // 按 CREATE TABLE 分割
  const createPattern = /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?/gi;
  const parts = content.split(createPattern).filter(s => s.trim());

  let idx = 0;
  const matches = [...content.matchAll(/CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?[`"']?(\w+)[`"']?\s*\(/gi)];

  for (const m of matches) {
    const tableName = m[1];
    // 找到这个 CREATE TABLE 语句的完整范围
    const stmtStart = m.index;
    const openParen = stmtStart + m[0].length;
    // 找匹配的闭括号
    let depth = 0, stmtEnd = openParen;
    for (let i = openParen; i < content.length; i++) {
      if (content[i] === '(') depth++;
      else if (content[i] === ')') {
        if (depth === 0) { stmtEnd = i; break; }
        depth--;
      }
    }
    // 往后找 ENGINE 或分号
    let enginePos = content.indexOf('ENGINE', stmtEnd);
    if (enginePos === -1) enginePos = stmtEnd;
    const stmt = content.substring(stmtStart, enginePos + 300);

    // 提取表定义 body
    const body = findTableBody(stmt);

    // 表级别 COMMENT（在 body 最后或 ENGINE 后）
    const tableCommentMatch = stmt.match(/COMMENT\s*=\s*['"]([^'"]*)['"]/i);
    const tableComment = tableCommentMatch ? tableCommentMatch[1] : '';

    const columns = [];
    // 逐行解析
    const lines = body.split(/\n/);

    for (const rawLine of lines) {
      let line = rawLine.trim();
      if (!line) continue;

      // 跳过约束行
      if (/^(PRIMARY|UNIQUE|FULLTEXT|CHECK|CONSTRAINT|KEY)\s+KEY/i.test(line)) continue;

      // 列定义行：必须有列名（反引号或字母开头）+ 类型 + 可能的 COMMENT
      // 移除末尾逗号
      if (line.endsWith(',')) line = line.slice(0, -1);

      const colMatch = line.match(/^`?(\w+)`?\s+\S+/i);
      if (!colMatch) continue;
      const colName = colMatch[1];

      // 提取 COMMENT
      const commentMatch = line.match(/COMMENT\s+['"]([^'"]*)['"]/i);
      const colComment = commentMatch ? commentMatch[1] : '';

      columns.push({ name: colName, comment: colComment });
    }

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
    `SELECT COLUMN_NAME, COLUMN_COMMENT, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA
     FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME=? ORDER BY ORDINAL_POSITION`,
    [tableName]
  );
  return {
    tableComment: tableRows[0]?.TABLE_COMMENT || '',
    columns: colRows.map(r => ({
      name: r.COLUMN_NAME,
      comment: r.COLUMN_COMMENT || '',
      type: r.COLUMN_TYPE,
      nullable: r.IS_NULLABLE,
      defaultVal: r.COLUMN_DEFAULT,
      extra: r.EXTRA || ''
    }))
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
    fixes.push(`  表备注修复: "${current.tableComment.substring(0,30)}" → "${correctData.comment}"`);
  }

  // 修复列备注
  let colFixCount = 0;
  for (const col of correctData.columns) {
    const dbCol = current.columns.find(c => c.name === col.name);
    if (!dbCol) continue;

    const needsFix = isGarbled(dbCol.comment) ||
      (col.comment && dbCol.comment !== col.comment);

    if (needsFix && col.comment !== undefined) {
      const safeComment = col.comment.replace(/'/g, "''");
      // COLUMN_DEFAULT: DEFAULT NULL -> string "null"; DEFAULT 'x' -> string "'x'"; 无默认值 -> null; 空字符串 DEFAULT '' -> string ""
      const nullableClause = dbCol.nullable === 'YES' ? '' : 'NOT NULL';
      let defaultClause = '';
      if (dbCol.defaultVal !== null && dbCol.defaultVal !== '') {
        defaultClause = ` DEFAULT ${dbCol.defaultVal}`;
      }
      // EXTRA 可能包含 "DEFAULT_GENERATED on update CURRENT_TIMESTAMP"
      // "DEFAULT_GENERATED" 是 MySQL 元数据标记，不可指定，只需保留 "on update ..."
      let extraClause = '';
      if (dbCol.extra) {
        const onUpdate = dbCol.extra.match(/on update (\S+)/i);
        extraClause = onUpdate ? ` ON UPDATE ${onUpdate[1]}` : '';
      }
      const colDef = `${dbCol.type} ${nullableClause}${defaultClause}${extraClause}`.trim().replace(/\s+/g, ' ');
      await conn.query(
        `ALTER TABLE \`${tableName}\` MODIFY COLUMN \`${col.name}\` ${colDef} COMMENT '${safeComment}'`
      );
      colFixCount++;
    }
  }

  if (colFixCount > 0) {
    fixes.push(`  字段备注修复: ${colFixCount} 个字段`);
  }

  return fixes;
}

async function main() {
  console.log('=== 修复表/字段备注乱码 v3 ===\n');

  const sqlFile = 'd:/学习资料/AI_Projects/LumenIM/backend/sql/lumenim.sql';
  const parsed = parseSQLFile(sqlFile);

  // 打印解析结果（验证）
  console.log('解析结果:');
  for (const [name, data] of Object.entries(parsed)) {
    const colWithComment = data.columns.filter(c => c.comment).length;
    console.log(`  ${name.padEnd(35)} 表备注:"${data.comment}" 列备注:${colWithComment}/${data.columns.length}`);
  }
  console.log(`共 ${Object.keys(parsed).length} 张表\n`);

  const conn = await mysql.createConnection(mysqlConfig);
  await conn.query('SET NAMES utf8mb4');

  let fixedTables = 0;
  let totalTableFixes = 0;
  let totalColFixes = 0;

  for (const [tableName, data] of Object.entries(parsed)) {
    const fixes = await fixComments(conn, tableName, data);
    if (fixes.length > 0) {
      console.log(`[${tableName}]`);
      fixes.forEach(f => console.log(f));
      fixedTables++;
      if (fixes.some(f => f.startsWith('  表备注'))) totalTableFixes++;
      const colFix = fixes.find(f => f.startsWith('  字段备注'));
      if (colFix) totalColFixes += parseInt(colFix.match(/(\d+)/)[1]);
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
