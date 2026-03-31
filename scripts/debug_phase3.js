const mysql = require('mysql2/promise');

function detUUID(id, ns) {
  const s = `${ns}:${id}`;
  let h1 = 0xdeadbeef;
  for (let i = 0; i < s.length; i++) {
    h1 = Math.imul(h1 ^ s.charCodeAt(i), 2654435761);
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507);
  h1 ^= Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  const u = Math.imul(h1 ^ (h1 >>> 16), 2246822507) >>> 0;
  const h2 = (Math.imul(h1, 2654435761) ^ (h1 >>> 15)) >>> 0;
  const p1 = u.toString(16).padStart(8, '0');
  const p2 = (h1 >>> 0).toString(16).padStart(4, '0');
  const p3 = ((h2 | 0x4000) >>> 0).toString(16).padStart(4, '0');
  const p4 = ((h2 | 0x8000) >>> 0).toString(16).slice(0, 4).padStart(4, '0');
  const p5 = (u >>> 0).toString(16).slice(0, 12).padStart(12, '0');
  return `${p1}-${p2}-${p3}-${p4}-${p5}`;
}

async function debug() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
  });

  // 查询 organize_dept
  const [deptRows] = await conn.query('SELECT dept_id, parent_id FROM organize_dept ORDER BY 1');
  console.log('organize_dept rows:', JSON.stringify(deptRows));

  // 测试 UUID 生成
  console.log('\nUUID for dpt:1 =', detUUID(1, 'dpt'), 'len=', detUUID(1, 'dpt').length);
  console.log('UUID for dpt:2 =', detUUID(2, 'dpt'), 'len=', detUUID(2, 'dpt').length);

  // 测试直接 UPDATE（用硬编码值）
  const uuid = detUUID(1, 'dpt');
  console.log('\n尝试 UPDATE organize_dept SET parent_id=? WHERE dept_id=?');
  console.log('  newParentId:', uuid, 'len:', uuid.length);
  console.log('  dept_id: 2');
  try {
    await conn.query('UPDATE organize_dept SET parent_id=? WHERE dept_id=?', [uuid, 2]);
    console.log('  成功！');
    const [after] = await conn.query('SELECT dept_id, parent_id FROM organize_dept WHERE dept_id IN (1,2,3)');
    console.log('更新后:', JSON.stringify(after));
  } catch (e) {
    console.error('失败:', e.message);
  }

  await conn.end();
}
debug().catch(e => { console.error(e.message); process.exit(1); });
