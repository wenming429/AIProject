const mysql = require('mysql2/promise');

async function analyze() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
  });

  // 获取所有表的所有列
  const [allCols] = await conn.query(
    `SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, COLUMN_TYPE, COLUMN_KEY, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, COLUMN_COMMENT
     FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat'
     ORDER BY TABLE_NAME, ORDINAL_POSITION`
  );

  // 目标表的主键字段（去重后的外键候选名）
  // users.id -> 所有 user_id, uid, create_user, creator_id, from_id 等
  // organize_dept.dept_id -> dept_id, parent_id（组织树）
  // organize_position.position_id -> position_id
  // organize.id -> 其他 id

  // 按表分组
  const byTable = {};
  for (const c of allCols) {
    if (!byTable[c.TABLE_NAME]) byTable[c.TABLE_NAME] = [];
    byTable[c.TABLE_NAME].push(c);
  }

  const targets = ['users', 'organize', 'organize_dept', 'organize_position'];
  const targetFields = new Set(['id', 'dept_id', 'position_id']);

  console.log('=== 需要修改的表和字段 ===\n');

  const changes = {}; // table -> [column info]

  for (const [tbl, cols] of Object.entries(byTable)) {
    if (targets.includes(tbl)) {
      // 主键表本身
      for (const c of cols) {
        if (c.COLUMN_KEY === 'PRI') {
          if (!changes[tbl]) changes[tbl] = [];
          changes[tbl].push({ ...c, reason: 'PRIMARY KEY' });
        }
      }
    } else {
      // 其他表，检查是否引用了目标表
      for (const c of cols) {
        const lowerName = c.COLUMN_NAME.toLowerCase();
        // 精确匹配
        if (targetFields.has(lowerName)) {
          // 进一步判断是否真的引用了目标表
          if (!changes[tbl]) changes[tbl] = [];
          changes[tbl].push({ ...c, reason: 'references target' });
        }
        // user_id / creator_id / create_user / from_id / owner_id 等 -> users
        else if (lowerName === 'user_id' || lowerName === 'uid' || lowerName === 'create_user' ||
                 lowerName === 'creator_id' || lowerName === 'from_id' || lowerName === 'owner_id' ||
                 lowerName === 'userid' || lowerName === 'send_user_id') {
          if (!changes[tbl]) changes[tbl] = [];
          changes[tbl].push({ ...c, reason: 'references users' });
        }
        // parent_id -> organize_dept (组织树)
        else if (lowerName === 'parent_id' || lowerName === 'belong_dept') {
          if (!changes[tbl]) changes[tbl] = [];
          changes[tbl].push({ ...c, reason: 'references organize_dept' });
        }
      }
    }
  }

  for (const [tbl, cols] of Object.entries(changes)) {
    console.log(`表: ${tbl} (${cols.length} 个字段)`);
    for (const c of cols) {
      console.log(`  ${c.COLUMN_NAME.padEnd(25)} ${c.COLUMN_TYPE.padEnd(30)} -> varchar(36)  [${c.reason}] ${c.COLUMN_COMMENT ? '(' + c.COLUMN_COMMENT + ')' : ''}`);
    }
    console.log();
  }

  // 汇总
  let totalCols = 0;
  let totalTables = Object.keys(changes).length;
  for (const v of Object.values(changes)) totalCols += v.length;
  console.log(`\n总计: ${totalTables} 张表, ${totalCols} 个字段需要修改`);

  await conn.end();
}
analyze().catch(console.error);
