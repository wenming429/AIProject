const mysql = require('mysql2/promise');

async function analyze() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
  });

  // 获取所有表的列
  const [allCols] = await conn.query(
    `SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, COLUMN_TYPE, COLUMN_KEY, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, COLUMN_COMMENT
     FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat'
     ORDER BY TABLE_NAME, ORDINAL_POSITION`
  );

  const byTable = {};
  for (const c of allCols) {
    if (!byTable[c.TABLE_NAME]) byTable[c.TABLE_NAME] = [];
    byTable[c.TABLE_NAME].push(c);
  }

  const targets = ['users', 'organize', 'organize_dept', 'organize_position'];
  const targetFields = new Set(['id', 'dept_id', 'position_id']);

  // 规则函数：给定表名+列名，判断它是否引用了目标表，返回被引用表名或null
  function getRefTarget(tbl, col) {
    const lower = col.toLowerCase();
    const lowerTbl = tbl.toLowerCase();

    // 4张目标表本身的主键
    if (targets.includes(tbl) && targetFields.has(col)) {
      if (tbl === 'users' && col === 'id') return 'users';
      if (tbl === 'organize_dept' && col === 'dept_id') return 'organize_dept';
      if (tbl === 'organize_position' && col === 'position_id') return 'organize_position';
      if (tbl === 'organize' && targetFields.has(col)) return 'organize';
    }

    // users.id -> user_id, creator_id, from_id, uid 等
    if (lower === 'user_id' || lower === 'uid' || lower === 'create_user' ||
        lower === 'creator_id' || lower === 'from_id' || lower === 'owner_id' ||
        lower === 'userid' || lower === 'send_user_id' || lower === 'apply_user_id') {
      return 'users';
    }

    // organize_dept.dept_id -> dept_id, parent_id
    if (lower === 'dept_id' || lower === 'parent_id' || lower === 'belong_dept') {
      return 'organize_dept';
    }

    // organize_position.position_id -> position_id
    if (lower === 'position_id') return 'organize_position';

    // organize.id -> 其他id字段（模糊匹配）
    // 但注意：article.id, group.id, chat.id 等是它们自己的主键，不引用任何外键
    // 只有那些实际上 FK 到 organize 的字段才需要改
    // 从 lumenim.sql 的结构来看，其他表的主键(id)是自增主键，不引用任何外键
    return null;
  }

  const changes = {}; // table -> [{col, target, currentType}]

  for (const [tbl, cols] of Object.entries(byTable)) {
    for (const c of cols) {
      const ref = getRefTarget(tbl, c.COLUMN_NAME);
      if (ref) {
        if (!changes[tbl]) changes[tbl] = [];
        changes[tbl].push({ col: c.COLUMN_NAME, target: ref, currentType: c.COLUMN_TYPE, key: c.COLUMN_KEY, comment: c.COLUMN_COMMENT });
      }
    }
  }

  // 打印完整清单
  console.log('需要修改的字段完整清单:\n');
  const sortedTables = Object.keys(changes).sort();
  let totalFields = 0;
  for (const tbl of sortedTables) {
    const cs = changes[tbl];
    totalFields += cs.length;
    console.log(`${tbl} (${cs.length}):`);
    for (const c of cs) {
      console.log(`  ${c.col} (${c.currentType}) -> varchar(36) [${c.target}]`);
    }
  }
  console.log(`\n总计: ${sortedTables.length} 张表, ${totalFields} 个字段`);

  // 打印按目标表分组
  console.log('\n=== 按被引用目标表分组 ===');
  const byTarget = { users: [], organize: [], organize_dept: [], organize_position: [] };
  for (const [tbl, cs] of Object.entries(changes)) {
    for (const c of cs) {
      byTarget[c.target].push({ table: tbl, col: c.col });
    }
  }
  for (const [t, items] of Object.entries(byTarget)) {
    console.log(`\n${t} (${items.length} 个字段):`);
    for (const i of items) {
      console.log(`  ${i.table}.${i.col}`);
    }
  }

  await conn.end();
}
analyze().catch(console.error);
