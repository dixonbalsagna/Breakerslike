// SHA-256 of a float64 vector as little-endian bytes, lowercase hex (the golden.json format), with WebCrypto.
// Works in the browser (secure context: 127.0.0.1 counts) and in Node 24 (globalThis.crypto).
export async function sha256F64(v: Float64Array): Promise<string> {
  const buf = new ArrayBuffer(v.length * 8);
  const dv = new DataView(buf);
  for (let i = 0; i < v.length; i++) dv.setFloat64(i * 8, v[i], true);   // explicit little-endian
  const d = new Uint8Array(await crypto.subtle.digest('SHA-256', buf));
  let s = '';
  for (let i = 0; i < d.length; i++) s += d[i].toString(16).padStart(2, '0');
  return s;
}
