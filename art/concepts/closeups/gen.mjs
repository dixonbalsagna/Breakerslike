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
let uid = 0, BLANK = false;
const place = (dir, fk, expr, x, y, size, extra = '', stage = 0) => `<svg x="${F(x)}" y="${F(y)}" width="${size}" height="${size}" viewBox="0 0 512 512" overflow="hidden" ${extra}>${portrait(dir, fk, expr, `u${uid++}`, { stage, blank: BLANK })}</svg>`;
// Camera's panel: a slanted strip, 56% of the width by 20% of the height (about 5.2 to 1), the ends slanted. The face is cropped to the band of the eyes and the brow.
function strip(dir, fk, expr, x, y, w) {
  const h = w / 5.2, s = w / 512, slant = h * 0.22, id = `u${uid++}`;
  return `<clipPath id="sp-${id}"><polygon points="${F(slant)},0 ${F(w)},0 ${F(w - slant)},${F(h)} 0,${F(h)}"/></clipPath><g transform="translate(${F(x)} ${F(y)})"><g clip-path="url(#sp-${id})"><g transform="translate(0 ${F(h / 2 - 232 * s)}) scale(${F(s)})">${portrait(dir, fk, expr, id, { blank: BLANK })}</g></g><polygon points="${F(slant)},0 ${F(w)},0 ${F(w - slant)},${F(h)} 0,${F(h)}" fill="none" stroke="${PALS[fk].frame}" stroke-width="3"/></g>`;
}
function header(title, sub, W) {
  return rect(0, 0, W, 104, '#1b1428') + text(30, 48, title, { size: 32, weight: 700, fill: '#f4f0fa' }) + text(30, 80, sub, { size: 14, fill: '#cfc6e6' });
}
function sheetOne(dir, fk) {
  const W = 1800, H = 1250;
  let b = rect(0, 0, W, H, '#dcd8e6') + header(`${NAMES[fk]} close-ups, direction ${DIRS[dir]}${BLANK ? ', blank mask half' : ''} (round ${round})`, 'Four expressions at 420, 200 and 120 px, in colour and in greyscale, and in Camera\'s slanted panel (the eye band). Working labels, pending Legal review.', W);
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

// ---------------------------------------------------------------------------------------------------------- the one-page comparison for Orb
function comparison() {
  const W = 1800, cs = 188;
  let b = rect(0, 0, W, 1500, '#dcd8e6') + header('Close-ups: three directions, one page', 'A the mask as a face, B the mask partly off or broken, C no mask. Neutral and hurt for each fighter, at the size of the 200 px cut-in. Round 6. Working labels, pending Legal review.', W);
  ['A', 'B', 'C'].forEach((d, i) => { b += text(190 + i * 2 * (cs + 6) + cs, 134, DIRS[d], { size: 14, weight: 700, anchor: 'middle' }); });
  [['A', 'Anti-hero'], ['P', 'Protagonist'], ['E', 'Empress'], ['C', 'Cyborg']].forEach(([fk, nm], r) => {
    const y0 = 146 + r * (cs + 8);
    b += text(24, y0 + cs / 2, nm, { size: 14, weight: 700 });
    ['A', 'B', 'C'].forEach((d, i) => ['neutral', 'hurt'].forEach((e, j) => { b += place(d, fk, e, 150 + i * 2 * (cs + 6) + j * (cs + 6), y0, cs); }));
  });
  const y = 146 + 4 * (cs + 8) + 24;
  b += text(24, y, 'How each direction does against the test: memorable and recognizable at a glance, four fighters never confused, expression readable at 120 px', { size: 16, weight: 700 });
  const rows = [
    ['Memorable at a glance', 4, 5, 3, 'B: every fighter has a break nobody else has (a vertical crack, a diagonal chunk, a jaw plate, a display half), so you know who it is from the break alone'],
    ['Four never confused (120 px, greyscale)', 4, 5, 4, 'The hair and head silhouettes already separate them (tail, swept tuft, topknot and diadem, box); B adds the break'],
    ['Expression at 120 px', 3, 4, 4, 'A reads from lit eyes and brows but the mouth is tiny; B and C have a real eye and brow'],
    ['Camera\'s slanted panel (the eye band)', 4, 4, 4, 'All three read from the eyes and brow alone; the Protagonist\'s lifted mask hides one eye in B, so his lit eye carries it'],
    ['Keeps who they are (masks, sigils, flashes)', 5, 4, 2, 'C drops the masks, which are the fighters\' identity and Legal-cleared look; B and A keep them'],
    ['Carries the damage stages', 3, 5, 4, 'In B the mask retreats and the face comes out as they are hurt (see the damage ladder)'],
    ['Legal risk', 'medium', 'medium; low if blank', 'low on masks', 'A and B put lit eye shapes on the masks, which meets Legal\'s earlier "no eye or mouth slots or dots" condition on the dome: re-screen. B with a blank mask half keeps the masked side free of eyes and mouth'],
    ['Art cost per expression', 'low', 'medium', 'low to medium', 'All SVG from one engine; B has a break per fighter'],
  ];
  const cx = [24, 520, 640, 760, 930];
  ['', 'A', 'B', 'C', 'why'].forEach((h, i) => { if (h) b += text(cx[i] + (i > 0 && i < 4 ? 40 : 0), y + 26, h, { size: 12.5, weight: 700 }); });
  rows.forEach(([label, a, bb, c, why], r) => {
    const yy = y + 36 + r * 38;
    b += `<line x1="24" y1="${yy}" x2="1776" y2="${yy}" stroke="#1b1428" stroke-opacity="0.15"/>` + text(24, yy + 22, label, { size: 12.5, weight: 600 });
    [a, bb, c].forEach((v, i) => { b += text(cx[i + 1] + 40, yy + 22, typeof v === 'number' ? '#'.repeat(0) + '*'.repeat(v) + ` ${v}` : v, { size: 12, anchor: 'start' }); });
    b += paras(cx[4], yy + 16, why, 120, 11, 13, { op: 0.85 });
  });
  const yr = y + 36 + rows.length * 38 + 24;
  b += text(24, yr, 'Recommendation', { size: 18, weight: 700 });
  b += paras(24, yr + 24, 'Take B as the standard close-up. It gives Orb the talking character\'s real face (an eye, a brow, a mouth that move), keeps every fighter masked and recognisable by the way their mask is broken, and it is the one that makes the battle damage stages show on the face: the mask retreats and the face comes out as a fight goes on. Use A as the fresh, composed state where a face would be wrong (the Anti-hero\'s Proud front, before his facade cracks), so one Anti-hero reads composed to cracked to broken. C is the safe fallback if Legal will not accept lit eyes on masks, but it loses the masks and is the least ownable.', 190, 13, 17);
  b += paras(24, yr + 110, 'Open for Orb: B or A for the default; whether the Anti-hero\'s composed state uses A. Open for Legal: lit eye shapes on the masks (A, and B\'s masked half) against the earlier condition; B with a blank mask half is the fallback. The damage ladder is `damage-ladder-B.svg`.', 190, 12.5, 16, { op: 0.9 });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${yr + 170}" viewBox="0 0 ${W} ${yr + 170}">${GREY}${b.replace('height="1500.00"', `height="${yr + 170}.00"`)}</svg>`;
}
const STAGE_NAMES = ['fresh', 'stage 1: scuffed', 'stage 2: torn', 'stage 3: ruined'];
function ladder(dir) {
  const W = 1800, ps = 330, H = 124 + 4 * (ps + 60) + 40;
  let b = rect(0, 0, W, H, '#dcd8e6') + header(`The damage stages on the face, direction ${DIRS[dir]} (round ${round})`, 'Fresh, then stage 1 scuffed, stage 2 torn, stage 3 ruined, neutral expression and (small) hurt. The mask retreats a little at each stage, with cracks, scuffs, a cut, a loose strand and a swollen eye. The damage stays and builds.', W);
  [['A', 'Anti-hero'], ['P', 'Protagonist'], ['E', 'Empress'], ['C', 'Cyborg']].forEach(([fk, nm], r) => {
    const y0 = 124 + r * (ps + 60);
    b += text(24, y0 + 14, nm, { size: 16, weight: 700 });
    [0, 1, 2, 3].forEach(n => { const x = 24 + n * (ps + 10); b += place(dir, fk, 'neutral', x, y0 + 22, ps, '', n) + text(x + 4, y0 + 22 + ps + 16, STAGE_NAMES[n], { size: 12, weight: 600, op: 0.8 }); });
    [0, 1, 2, 3].forEach(n => { b += place(dir, fk, 'hurt', 24 + 4 * (ps + 10) + 20 + (n % 2) * 130, y0 + 22 + Math.floor(n / 2) * 130, 124, '', n) + place(dir, fk, 'hurt', 24 + 4 * (ps + 10) + 20 + 2 * 130 + 16 + (n % 2) * 130, y0 + 22 + Math.floor(n / 2) * 130, 124, 'filter="url(#grey)"', n); });
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
if (!only || only === 'ladder' || only === 'all') { const s = ORIGIN + ladder('B'); writeFileSync(join(dir0, 'damage-ladder-B.svg'), s); if (FINAL) writeFileSync(join(OUT, 'damage-ladder-B.svg'), s); }
if (!only || only === 'compare' || only === 'all') { const s = ORIGIN + comparison(); writeFileSync(join(dir0, 'comparison.svg'), s); if (FINAL) writeFileSync(join(OUT, 'closeups-comparison.svg'), s); }
if (!only || only === 'blank' || only === 'all') { BLANK = true; const s = ORIGIN + sheetOne('B', 'A'); writeFileSync(join(dir0, 'anti-hero-B-blank.svg'), s); if (FINAL) writeFileSync(join(OUT, 'anti-hero-B-blank.svg'), s); const s2 = ORIGIN + sheetOthers('B'); writeFileSync(join(dir0, 'others-B-blank.svg'), s2); if (FINAL) writeFileSync(join(OUT, 'others-B-blank.svg'), s2); BLANK = false; }
if (!engineArg) copyFileSync(join(OUT, 'engine.mjs'), join(dir0, 'engine.snapshot.mjs'));
console.log(`wrote round ${round}${FINAL ? ' (and final)' : ''}`);
