const mysql = require('mysql2/promise');

(async () => {
  const db = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
  });

  // Check organize_dept current state
  const [deptRows] = await db.query('SELECT * FROM organize_dept ORDER BY 1');
  console.log('organize_dept rows:');
  for (const r of deptRows) {
    console.log(JSON.stringify({ dept_id: r.dept_id, parent_id: r.parent_id, dept_name: r.dept_name }));
  }

  // Check for duplicate dept_ids
  const ids = deptRows.map(r => r.dept_id);
  const seen = new Set();
  const dupes = new Set();
  for (const id of ids) {
    if (seen.has(id)) dupes.add(id);
    seen.add(id);
  }
  console.log('\nDuplicate dept_ids:', [...dupes]);
  console.log('Total rows:', deptRows.length, '  Unique dept_ids:', seen.size);

  // Check existing _new tables
  const [tbls] = await db.query("SHOW TABLES LIKE '%_new'");
  console.log('\nExisting _new tables:', tbls.map(t => Object.values(t)[0]));

  // Also show current organize_dept PK and columns
  const [cols] = await db.query(
    "SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE, COLUMN_KEY FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='go_chat' AND TABLE_NAME='organize_dept' ORDER BY ORDINAL_POSITION"
  );
  console.log('\norganize_dept columns:');
  for (const c of cols) {
    console.log(`  ${c.COLUMN_NAME} ${c.COLUMN_TYPE} key=${c.COLUMN_KEY}`);
  }

  await db.end();
})().catch(e => console.error(e.message));
