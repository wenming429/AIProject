// 直接在 Node 中测试 UUID 生成
const uuid = (() => {
  const id = 1, ns = 'dpt';
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
  console.log('h1:', h1, '-> hex:', (h1 >>> 0).toString(16), 'h1&FFFF:', (h1 & 0xFFFF).toString(16));
  console.log('h2:', h2, '-> hex:', h2.toString(16));
  console.log('u:', u, '-> hex:', u.toString(16));
  console.log('p1:', p1, 'len:', p1.length);
  console.log('p2:', p2, 'len:', p2.length);
  console.log('p3:', p3, 'len:', p3.length);
  console.log('p4:', p4, 'len:', p4.length);
  console.log('p5:', p5, 'len:', p5.length);
  console.log('uuid:', uuid);
  console.log('total len:', uuid.length);
  return uuid;
})();
