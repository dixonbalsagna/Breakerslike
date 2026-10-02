// Joins raw RGB clips of the same size (the files tools/anim_reel.gd and match_close.gd write) into one clip, in order, so one GIF can show several windows.
//   node render/anim/tools/rgb_join.mjs out.rgb a.rgb b.rgb c.rgb
import { readFileSync, writeFileSync } from 'node:fs';
const [out, ...ins] = process.argv.slice(2);
const clips = ins.map(f => readFileSync(f));
const w = clips[0].readInt32LE(0), h = clips[0].readInt32LE(4);
let n = 0;
const body = [];
for (const c of clips) {
  if (c.readInt32LE(0) !== w || c.readInt32LE(4) !== h) { console.error('size differs: ' + c.readInt32LE(0) + 'x' + c.readInt32LE(4)); process.exit(1); }
  n += c.readInt32LE(8);
  body.push(c.subarray(12));
}
const head = Buffer.alloc(12);
head.writeInt32LE(w, 0); head.writeInt32LE(h, 4); head.writeInt32LE(n, 8);
writeFileSync(out, Buffer.concat([head, ...body]));
console.log(out + ': ' + clips.length + ' clips, ' + n + ' frames, ' + w + 'x' + h);
