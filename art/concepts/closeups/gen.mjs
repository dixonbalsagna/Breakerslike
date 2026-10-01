// Origin: procedural sheet writer for the close-up style directions (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-10-02. Human direction: Orb, via the EP.
// Run from the repo root:  node art/concepts/closeups/gen.mjs <round> [--final]
//   writes rounds/round-<n>/ (the Anti-hero's three direction sheets and the other three fighters' three sheets, and a copy of the engine of that round);
//   --final also writes the same sheets to this folder.

import { copyFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { pathToFileURL } from 'node:url';
const engineArg = process.argv.find(a => a.startsWith('--engine='))?.slice(9);
const { portrait, PALS, IDS } = await import(engineArg ? pathToFileURL(join(dirname(fileURLToPath(import.meta.url)), engineArg)).href : './engine.mjs');

const OUT = dirname(fileURLToPath(import.meta.url));
const round = process.argv[2] ?? '1', FINAL = process.argv.includes('--final');
const F = n => n.toFixed(2);
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family=\"'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif\"";
const text = (x, y, t, { size = 14, weight = 400, fill = '#1b1428', anchor = 'start', op = 1 } = {}) => `<text x="${F(x)}" y="${F(y)}" ${FONT} font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}" opacity="${op}">${esc(t)}</text>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fill}" ${extra}/>`;
const wrap = (t, n) => { const w = t.split(' '), out = []; let line = ''; for (const x of w) { if ((line + ' ' + x).trim().length > n) { out.push(line.trim()); line = x; } else line += ' ' + x; } if (line.trim()) out.push(line.trim()); return out; };
const paras = (x, y, t, n, size = 12, gap = 15, o = {}) => wrap(t, n).map((l, i) => text(x, y + i * gap, l, { size, ...o })).join('');
const EXPR = ['neutral', 'smirk', 'strain', 'hurt'];
const NAMES = { P: 'Protagonist', A: 'Anti-hero', E: 'Empress', C: 'Cyborg' };
const DIRS = { A: 'A: the mask as a face', B: 'B: the mask partly off or broken', C: 'C: no mask, a full stylized face' };
const GREY = '<defs><filter id="grey"><feColorMatrix type="saturate" values="0"/></filter></defs>';
let uid = 0;
const place = (dir, fk, expr, x, y, size, extra = '') => `<svg x="${F(x)}" y="${F(y)}" width="${size}" height="${size}" viewBox="0 0 512 512" overflow="hidden" ${extra}>${portrait(dir, fk, expr, `u${uid++}`)}</svg>`;
// Camera's panel: a slanted strip, 56% of the width by 20% of the height (about 5.2 to 1), the ends slanted. The face is cropped to the band of the eyes and the brow.
function strip(dir, fk, expr, x, y, w) {
  const h = w / 5.2, s = w / 512, slant = h * 0.22, id = `u${uid++}`;
  return `<clipPath id="sp-${id}"><polygon points="${F(slant)},0 ${F(w)},0 ${F(w - slant)},${F(h)} 0,${F(h)}"/></clipPath><g transform="translate(${F(x)} ${F(y)})"><g clip-path="url(#sp-${id})"><g transform="translate(0 ${F(h / 2 - 232 * s)}) scale(${F(s)})">${portrait(dir, fk, expr, id)}</g></g><polygon points="${F(slant)},0 ${F(w)},0 ${F(w - slant)},${F(h)} 0,${F(h)}" fill="none" stroke="${PALS[fk].frame}" stroke-width="3"/></g>`;
}
function header(title, sub, W) {
  return rect(0, 0, W, 104, '#1b1428') + text(30, 48, title, { size: 32, weight: 700, fill: '#f4f0fa' }) + text(30, 80, sub, { size: 14, fill: '#cfc6e6' });
}
function sheetOne(dir, fk) {
  const W = 1800, H = 1250;
  let b = rect(0, 0, W, H, '#dcd8e6') + header(`${NAMES[fk]} close-ups, direction ${DIRS[dir]} (round ${round})`, 'Four expressions at 420, 200 and 120 px, in colour and in greyscale, and in Camera\'s slanted panel (the eye band). Working labels, pending Legal review.', W);
  b += text(24, 134, '420 px', { size: 14, weight: 700 });
  EXPR.forEach((e, i) => { const x = 24 + i * 442; b += place(dir, fk, e, x, 146, 420) + text(x + 6, 584, e, { size: 14, weight: 700 }); });
  b += text(24, 618, '200 px, colour then greyscale', { size: 14, weight: 700 });
  EXPR.forEach((e, i) => { b += place(dir, fk, e, 24 + i * 214, 628, 200) + place(dir, fk, e, 24 + i * 214 + 4 * 214 + 20, 628, 200, 'filter="url(#grey)"'); });
  b += text(24, 852, '120 px', { size: 14, weight: 700 }) + text(24 + 4 * 130 + 40, 852, 'greyscale', { size: 14, weight: 700 });
  EXPR.forEach((e, i) => { b += place(dir, fk, e, 24 + i * 130, 862, 120) + place(dir, fk, e, 24 + 4 * 130 + 40 + i * 130, 862, 120, 'filter="url(#grey)"'); });
  b += text(24 + 8 * 130 + 80, 852, 'in Camera\'s slanted panel (56 percent by 20 percent)', { size: 14, weight: 700 });
  EXPR.forEach((e, i) => { b += strip(dir, fk, e, 24 + 8 * 130 + 80 + (i % 2) * 330, 866 + Math.floor(i / 2) * 80, 320); });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${GREY}${b}</svg>`;
}
function sheetOthers(dir) {
  const W = 1800, ps = 300, H = 120 + 3 * (ps + 110);
  let b = rect(0, 0, W, H, '#dcd8e6') + header(`The other three fighters, direction ${DIRS[dir]} (round ${round})`, 'Four expressions each at 300 px, then at 120 px in colour and greyscale, and in Camera\'s panel (the eye band). Working labels, pending Legal review.', W);
  ['P', 'E', 'C'].forEach((fk, r) => {
    const y0 = 124 + r * (ps + 110);
    b += text(24, y0 + 14, NAMES[fk], { size: 16, weight: 700 });
    EXPR.forEach((e, i) => { b += place(dir, fk, e, 24 + i * (ps + 8), y0 + 22, ps) + text(24 + i * (ps + 8) + 4, y0 + 22 + ps + 14, e, { size: 12, weight: 600, op: 0.8 }); });
    EXPR.forEach((e, i) => { b += place(dir, fk, e, 24 + 4 * (ps + 8) + 20 + (i % 2) * 124, y0 + 22 + Math.floor(i / 2) * 124, 120) + place(dir, fk, e, 24 + 4 * (ps + 8) + 20 + 2 * 124 + 12 + (i % 2) * 124, y0 + 22 + Math.floor(i / 2) * 124, 120, 'filter="url(#grey)"'); });
    EXPR.forEach((e, i) => { b += strip(dir, fk, e, 24 + 4 * (ps + 8) + 20 + (i % 2) * 130, y0 + 22 + 252 + Math.floor(i / 2) * 36, 124); });
  });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${GREY}${b}</svg>`;
}
const ORIGIN = '<!-- Origin: procedural close-up sheet written by art/concepts/closeups/gen.mjs (deterministic, no external images or fonts), Art Director session (Claude, claude-sonnet-5-5), 2026-10-02; prompt record art/prompts/ART-0011-closeup-directions.md -->' + String.fromCharCode(10);
const dir0 = join(OUT, 'rounds', `round-${round}`);
mkdirSync(dir0, { recursive: true });
const only = process.argv.find(a => a.startsWith('--only='))?.slice(7);
for (const d of ['A', 'B', 'C']) {
  if (!only || only === 'anti' || only === 'all') { const s = ORIGIN + sheetOne(d, 'A'); writeFileSync(join(dir0, `anti-hero-${d}.svg`), s); if (FINAL) writeFileSync(join(OUT, `anti-hero-${d}.svg`), s); }
  if (!only || only === 'others' || only === 'all') { const s = ORIGIN + sheetOthers(d); writeFileSync(join(dir0, `others-${d}.svg`), s); if (FINAL) writeFileSync(join(OUT, `others-${d}.svg`), s); }
}
if (!engineArg) copyFileSync(join(OUT, 'engine.mjs'), join(dir0, 'engine.snapshot.mjs'));
console.log(`wrote round ${round}${FINAL ? ' (and final)' : ''}`);
