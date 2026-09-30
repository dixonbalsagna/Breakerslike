// Raw RGB frames (tools/anim_reel.gd) to an animated GIF, no dependencies. One input, or two side by side.
//   node render/anim/tools/gif.mjs out.gif in.rgb [in2.rgb] [--delay 3]
// Palette: median cut over a sample of the frames (256 colours), no dithering (the art is flat colour).
import { readFileSync, writeFileSync } from 'node:fs';
const args = process.argv.slice(2);
const dIdx = args.indexOf('--delay');
const delay = dIdx >= 0 ? Number(args[dIdx + 1]) : 3;
const files = args.filter((a, i) => !a.startsWith('--') && !(dIdx >= 0 && i === dIdx + 1));
const out = files[0];
const ins = files.slice(1);
const clips = ins.map(f => { const b = readFileSync(f); return { w: b.readInt32LE(0), h: b.readInt32LE(4), n: b.readInt32LE(8), b }; });
const n = Math.min(...clips.map(c => c.n));
const h = clips[0].h;
const gap = clips.length > 1 ? 4 : 0;
const W = clips.reduce((s, c) => s + c.w, 0) + gap * (clips.length - 1);

function frame(i) {                                  // RGB of frame i, clips side by side
  const px = Buffer.alloc(W * h * 3, 16);
  let x0 = 0;
  for (const c of clips) {
    const off = 12 + i * c.w * c.h * 3;
    for (let y = 0; y < h; y++) c.b.copy(px, (y * W + x0) * 3, off + y * c.w * 3, off + (y + 1) * c.w * 3);
    x0 += c.w + gap;
  }
  return px;
}

const sample = [];
for (let i = 0; i < n; i += Math.max(1, Math.floor(n / 12))) {
  const f = frame(i);
  for (let p = 0; p < f.length; p += 3 * 7) sample.push([f[p], f[p + 1], f[p + 2]]);
}
function medianCut(boxes) {
  while (boxes.length < 256) {
    let bi = -1, bs = 0, ba = 0;
    boxes.forEach((bx, k) => {
      if (bx.length < 2) return;
      for (let a = 0; a < 3; a++) {
        let lo = 255, hi = 0;
        for (const p of bx) { lo = Math.min(lo, p[a]); hi = Math.max(hi, p[a]); }
        const s = (hi - lo) * Math.sqrt(bx.length);
        if (s > bs) { bs = s; bi = k; ba = a; }
      }
    });
    if (bi < 0) break;
    const bx = boxes[bi].sort((p, q) => p[ba] - q[ba]);
    const m = bx.length >> 1;
    boxes.splice(bi, 1, bx.slice(0, m), bx.slice(m));
  }
  return boxes.map(bx => { const s = [0, 0, 0]; for (const p of bx) for (let a = 0; a < 3; a++) s[a] += p[a]; return s.map(v => Math.round(v / bx.length)); });
}
const pal = medianCut([sample]);
while (pal.length < 256) pal.push([0, 0, 0]);
const lut = new Int16Array(32768).fill(-1);
function idx(r, g, b) {
  const k = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
  if (lut[k] >= 0) return lut[k];
  const rr = (r & 0xf8) | 4, gg = (g & 0xf8) | 4, bb = (b & 0xf8) | 4;
  let best = 0, bd = 1e9;
  for (let i = 0; i < 256; i++) {
    const d = (pal[i][0] - rr) ** 2 + (pal[i][1] - gg) ** 2 + (pal[i][2] - bb) ** 2;
    if (d < bd) { bd = d; best = i; }
  }
  return (lut[k] = best);
}
function lzw(ix) {                                    // GIF LZW, minimum code size 8
  const bytes = [];
  let cur = 0, nb = 0;
  const put = (code, size) => { cur |= code << nb; nb += size; while (nb >= 8) { bytes.push(cur & 255); cur >>= 8; nb -= 8; } };
  let size = 9, next = 258, dict = new Map();
  put(256, size);
  let prefix = ix[0];
  for (let i = 1; i < ix.length; i++) {
    const c = ix[i], key = prefix * 256 + c, v = dict.get(key);
    if (v !== undefined) { prefix = v; continue; }
    put(prefix, size);
    if (next < 4096) { dict.set(key, next++); if (next > (1 << size) && size < 12) size++; }
    else { put(256, size); dict = new Map(); next = 258; size = 9; }
    prefix = c;
  }
  put(prefix, size);
  put(257, size);
  if (nb > 0) bytes.push(cur & 255);
  return bytes;
}
const parts = [
  Buffer.from('GIF89a'),
  Buffer.from([W & 255, W >> 8, h & 255, h >> 8, 0xf7, 0, 0]),
  Buffer.from(pal.flat()),
  Buffer.from([0x21, 0xff, 0x0b, ...Buffer.from('NETSCAPE2.0'), 3, 1, 0, 0, 0]),
];
for (let i = 0; i < n; i++) {
  const f = frame(i), ix = new Uint8Array(W * h);
  for (let p = 0; p < W * h; p++) ix[p] = idx(f[p * 3], f[p * 3 + 1], f[p * 3 + 2]);
  parts.push(Buffer.from([0x21, 0xf9, 4, 0, delay & 255, delay >> 8, 0, 0]));
  parts.push(Buffer.from([0x2c, 0, 0, 0, 0, W & 255, W >> 8, h & 255, h >> 8, 0, 8]));
  const data = lzw(ix);
  for (let o = 0; o < data.length; o += 255) { const ch = data.slice(o, o + 255); parts.push(Buffer.from([ch.length, ...ch])); }
  parts.push(Buffer.from([0]));
}
parts.push(Buffer.from([0x3b]));
const all = Buffer.concat(parts);
writeFileSync(out, all);
console.log(`${out}: ${n} frames, ${W}x${h}, ${(all.length / 1e6).toFixed(2)} MB`);
