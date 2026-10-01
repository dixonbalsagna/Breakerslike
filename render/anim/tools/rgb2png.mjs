// A frame (or several, stacked) of a raw reel file (tools/anim_reel.gd) as a PNG, to look at one moment without a GIF viewer.
//   node render/anim/tools/rgb2png.mjs out.png in.rgb 0 100 200
import { readFileSync, writeFileSync } from 'node:fs';
import { deflateSync } from 'node:zlib';
const [out, inp, ...fr] = process.argv.slice(2);
const b = readFileSync(inp);
const w = b.readInt32LE(0), h = b.readInt32LE(4);
const idx = fr.length ? fr.map(Number) : [0];
const H = h * idx.length;
const raw = Buffer.alloc((w * 3 + 1) * H);
idx.forEach((f, k) => {
  for (let y = 0; y < h; y++) {
    const o = (k * h + y) * (w * 3 + 1);
    raw[o] = 0;
    b.copy(raw, o + 1, 12 + (f * h + y) * w * 3, 12 + (f * h + y + 1) * w * 3);
  }
});
const crcT = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
const crc = buf => { let c = -1; for (const x of buf) c = crcT[(c ^ x) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; };
const chunk = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 2;
writeFileSync(out, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
console.log(out, w + 'x' + H);
