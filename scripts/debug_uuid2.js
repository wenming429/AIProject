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
  const p1 = (u & 0xFFFFFFFF).toString(16).padStart(8, '0');
  const p2 = (h1 & 0xFFFF).toString(16).padStart(4, '0');
  const p3 = ((4 << 12) | (h2 & 0xFFF)).toString(16).padStart(4, '0');
  const p4 = ((0x8000 | (h2 & 0x3FFF))).toString(16).padStart(4, '0');
  const p5 = (u & 0xFFFFFFFFFFFF).toString(16).padStart(12, '0');
  const uuid = `${p1}-${p2}-${p3}-${p4}-${p5}`;
  return uuid;
}

async function debug() {
  const conn = await mysql.createConnection({
    host: 'localhost', port: 3306, user: 'root', password: 'wenming429', database: 'go_chat'
  });

  // 直接测试 UPDATE
  const uuid = detUUID(1, 'dpt');
  console.log('UUID for 1,dpt:', uuid, 'len:', uuid.length);

  try {
    await conn.query('UPDATE organize_dept SET parent_id=? WHERE dept_id=?', [uuid, '2']);
    console.log('UPDATE 成功！');
    const [r] = await conn.query('SELECT dept_id, parent_id FROM organize_dept ORDER BY 1');
    console.log(JSON.stringify(r));
  } catch (e) {
    console.error('UPDATE 失败:', e.message);
  }

  // 恢复原状
  try {
    await conn.query('UPDATE organize_dept SET parent_id=? WHERE dept_id=?', ['1', '2']);
    console.log('恢复成功');
  } catch(e) { console.error('恢复失败:', e.message); }

  await conn.end();
}
debug().catch(e => { console.error(e.message); process.exit(1); });
