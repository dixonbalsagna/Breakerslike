// Origin: procedural sheet writer for the launch pair's look (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-10-03. Human direction: Orb, via the EP.
// Run from the repo root:  node art/concepts/refine/gen-launch-pair.mjs
// Writes glasses-compare.svg (the lead frame, its chamfers changed and dropped, side by side), launch-pair-protagonist.svg and launch-pair-rival.svg.
// The launch pair is the Protagonist and the rival (the Anti-hero). No masks; the faces are the unmasked refined faces.

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { portrait } from '../closeups/engine.mjs';
import * as FA from './faces.mjs';
import { FRAMES, glassedFace, profileGlasses } from './glasses.mjs';
import { OTHER_OPTS, drawFigure, POSE0, PAL } from './figures.mjs';
import { markedConcept } from '../shared/styled.mjs';

const OUT = dirname(fileURLToPath(import.meta.url));
const F = n => n.toFixed(2);
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family=\"'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif\"";
const text = (x, y, t, { size = 14, weight = 400, fill = '#1b1428', anchor = 'start', op = 1 } = {}) => `<text x="${F(x)}" y="${F(y)}" ${FONT} font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}" opacity="${op}">${esc(t)}</text>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fill}" ${extra}/>`;
const wrap = (t, n) => { const w = t.split(' '), out = []; let line = ''; for (const x of w) { if ((line + ' ' + x).trim().length > n) { out.push(line.trim()); line = x; } else line += ' ' + x; } if (line.trim()) out.push(line.trim()); return out; };
const paras = (x, y, t, n, size = 12, gap = 15, o = {}) => wrap(t, n).map((l, i) => text(x, y + i * gap, l, { size, ...o })).join('');
const header = (title, sub, W) => rect(0, 0, W, 104, '#1b1428') + text(30, 46, title, { size: 30, weight: 700, fill: '#f4f0fa' }) + paras(30, 72, sub, 210, 14, 18, { fill: '#cfc6e6' });
const BG = '#e8e5ee';
const FILTERS = '<defs><filter id="grey"><feColorMatrix type="saturate" values="0"/></filter>' +
  '<filter id="tealf"><feColorMatrix type="matrix" values="0 0 0 0 0.10  0 0 0 0 0.62  0 0 0 0 0.56  0 0 0 1 0"/></filter>' +
  '<filter id="violetf"><feColorMatrix type="matrix" values="0 0 0 0 0.45  0 0 0 0 0.22  0 0 0 0 0.78  0 0 0 1 0"/></filter></defs>';
let uid = 0;
const EXPR_OF = { clear: 'neutral', glare: 'smirk', glint: 'neutral' };
const face = (key, state, x, y, size, o = {}) => `<svg x="${F(x)}" y="${F(y)}" width="${size}" height="${size}" viewBox="0 0 512 512" overflow="hidden">${portrait('X', 'A', o.expr ?? EXPR_OF[state], `p${uid++}`, { draw: glassedFace(key, state, o.stage ?? 0, 0.4) })}</svg>`;
const plainFace = (fk, expr, x, y, size, refined) => `<svg x="${F(x)}" y="${F(y)}" width="${size}" height="${size}" viewBox="0 0 512 512" overflow="hidden">${refined ? portrait('X', fk, expr, `p${uid++}`, { draw: FA.refined }) : portrait('C', fk, expr, `p${uid++}`)}</svg>`;

// concepts: the rival is the long-tail option with the lead glasses; the Protagonist is the big-fist option
const rival = (key, state) => { const c = scaled(OTHER_OPTS.A.options[0].make(), [0.92, 0.94]), prev = c.after, add = key ? profileGlasses(key, state) : null; return add ? { ...c, after: (ctx, sk, st, cfg) => (prev ? prev(ctx, sk, st, cfg) : '') + add(ctx, sk) } : c; };
// the build change that makes the silhouettes read apart: the Protagonist broader (torso and limbs), the rival slimmer
const scaled = (c, k) => ({ ...c, build: { tw: 1, tl: 1, lw: 1, hs: 1, leg: 1, arm: 1, ...(c.build ?? {}), tw: (c.build?.tw ?? 1) * k[0], lw: (c.build?.lw ?? 1) * k[1] } });
const hero = () => scaled(OTHER_OPTS.P.options[1].make(), [1.2, 1.14]);
const fig = (c, pal, pose, x, g, s, flat, extra = '') => `<g ${extra}>${drawFigure({ concept: c, pal, pose, flat, bg: BG, x, ground: g, s })}</g>`;
const mirrorAbout = (x, inner) => `<g transform="translate(${F(2 * x)} 0) scale(-1 1)">${inner}</g>`;
// a crop of the head of the rival at a large scale (the glasses at fight size, enlarged for reading)
const headCrop = (key, state, x, y, w = 140, h = 100, s = 5) => `<svg x="${F(x)}" y="${F(y)}" width="${w}" height="${h}" viewBox="${F(18 * s - w / 2)} ${F(-69 * s - h / 2)} ${w} ${h}" overflow="hidden">${rect(18 * s - w / 2, -69 * s - h / 2, w, h, '#f3f0f8')}${drawFigure({ concept: rival(key, state), pal: PAL.A, pose: POSE0('A'), flat: false, bg: BG, x: 0, ground: 0, s })}</svg>`;

// ------------------------------------------------------------------------------------------------------------ the glasses side by side
const VARS = [
  ['blade', 'A  As drawn (the lead)', 'Blade lenses with the lit plate line along the top edge: the cleanest read, a blade line even when clear.'],
  ['bladebevel', 'B  Chamfers changed', 'Bevelled corners at the nose and the temple, a heavier top plate and a small chamfered hinge tab on each lens: more plate, more weight.'],
  ['bladebare', 'C  Chamfers dropped', 'A bare wedge: four sides, a thin even rim, no lit line, no tabs: the plainest, and the quietest until the glare.'],
];
function glassesCompare() {
  const W = 1800, CW = 580, H = 1180;
  let b = rect(0, 0, W, H, '#dcd8e6') + header('The rival\'s glasses: the lead, with its chamfers changed and dropped', 'Side by side at close-up and at gameplay size, glare off and on. Drawn to Legal\'s rules (RL-066): thin violet frame, dark violet tint, one hard-edged pale wedge for the glare, held 0.4 s at most. No masks. Working labels, pending Legal review.', W);
  VARS.forEach(([k, name, line], i) => {
    const x0 = 24 + i * (CW + 8), y0 = 124;
    const xi = x0 + 70;
    b += rect(x0, y0, CW, 880, BG, 'stroke="#1b1428" stroke-opacity="0.2"') + text(x0 + 12, y0 + 26, name, { size: 15, weight: 700 }) + (k === 'blade' ? text(x0 + CW - 12, y0 + 26, 'the lead', { size: 12, weight: 700, anchor: 'end', fill: '#6b3fa8' }) : '');
    b += text(xi + 12, y0 + 50, 'close-up: glare off, then on', { size: 11, op: 0.65 }) + face(k, 'clear', xi + 10, y0 + 56, 206) + face(k, 'glare', xi + 222, y0 + 56, 206);
    b += text(xi + 12, y0 + 288, 'gameplay size (the figure is 100 px tall): off, then on', { size: 11, op: 0.65 });
    b += fig(rival(k, 'clear'), PAL.A, POSE0('A'), xi + 90, y0 + 410, 1.0, false) + fig(rival(k, 'glare'), PAL.A, POSE0('A'), xi + 260, y0 + 410, 1.0, false);
    b += text(xi + 12, y0 + 430, 'the same, the head enlarged 5 times to read the lens', { size: 11, op: 0.65 });
    b += headCrop(k, 'clear', xi + 10, y0 + 438) + headCrop(k, 'glare', xi + 160, y0 + 438);
    b += text(xi + 12, y0 + 558, '72 px and 24 px (colour, then grey)', { size: 11, op: 0.65 });
    b += face(k, 'clear', xi + 10, y0 + 566, 72) + face(k, 'glare', xi + 88, y0 + 566, 72) + face(k, 'clear', xi + 166, y0 + 566, 72, {}) ;
    b += `<g filter="url(#grey)">${face(k, 'clear', xi + 244, y0 + 566, 72)}${face(k, 'glare', xi + 322, y0 + 566, 72)}</g>`;
    b += face(k, 'clear', xi + 10, y0 + 650, 24) + face(k, 'glare', xi + 40, y0 + 650, 24);
    b += paras(xi + 12, y0 + 700, line, 62, 12, 15, { op: 0.9 });
  });
  // verdict
  const y = 124 + 880 + 24;
  b += text(24, y, 'The pick, and the one question', { size: 16, weight: 700 });
  b += paras(24, y + 24, 'Pick: A, the lead as drawn. At gameplay size the lens is about 6 px across, so the shape that survives is the long tapered wedge with its pointed tip; A and C both have it, and A\'s lit top line is the only thing that keeps the frame visible when the lens is clear, so A reads best. B\'s extra tabs and bevels turn to noise at that size and look more like armour than glasses; C is the cleanest if Orb wants the glasses to almost vanish until the glare. In the glare, A and C show one clear pale-violet wedge (still violet in colour at 24 px, not white); B\'s heavier top plate makes the wedge harder to see. The earlier chamfer-plates frame is not available (Legal: avoid), so it is no longer shown.', 230, 12.5, 17);
  b += paras(24, y + 100, 'The question for Orb: A, B or C? And the earlier two: does the glare hide his eyes completely (as drawn), and are the glasses always on?', 230, 12.5, 17, { weight: 600 });
  b += paras(24, y + 134, 'Note on "chamfer plates": A is the lead as it was drawn; B adds the plate cuts (bevelled corners, a heavier top plate, hinge tabs); C removes the lit plate line and the fifth corner. If a different reading of "chamfer plates" was meant, say so and I will redraw.', 230, 11.5, 15, { op: 0.8 });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${y + 180}" viewBox="0 0 ${W} ${y + 180}">${FILTERS}${b}</svg>`;
}

// ------------------------------------------------------------------------------------------------------------ the read-apart panel
function readApart(x0, y0, W, title) {
  let b = rect(x0, y0, W, 330, BG, 'stroke="#1b1428" stroke-opacity="0.2"') + text(x0 + 12, y0 + 24, title, { size: 15, weight: 700 });
  const pc = hero(), rc = rival('blade', 'clear'), g = y0 + 270;
  // flat black at three sizes, one after the other
  [[1.0, 'gameplay size (100 px)'], [0.5, '50 px'], [0.25, '25 px']].forEach(([s, label], i) => {
    const bx = x0 + 70 + [0, 250, 410][i] * 1;
    b += fig(pc, PAL.P, POSE0('P'), bx, g, s, true) + fig(rc, PAL.A, POSE0('A'), bx + 62 + 40 * s, g, s, true) + text(bx - 20, g + 24, label, { size: 10.5, op: 0.65 });
  });
  // facing each other, flat, the way they stand in a fight
  b += fig(pc, PAL.P, POSE0('P'), x0 + 640, g, 1.3, true) + mirrorAbout(x0 + 840, fig(rc, PAL.A, POSE0('A'), x0 + 840, g, 1.3, true)) + text(x0 + 620, g + 24, 'facing each other, flat black (as in a fight)', { size: 10.5, op: 0.65 });
  // one on top of the other, tinted, to see where they differ
  b += `<g opacity="0.6" filter="url(#tealf)">${fig(pc, PAL.P, POSE0('P'), x0 + 1010, g, 1.3, true)}</g><g opacity="0.6" filter="url(#violetf)">${fig(rc, PAL.A, POSE0('A'), x0 + 1010, g, 1.3, true)}</g>` + text(x0 + 940, g + 24, 'laid over each other (teal: Protagonist, violet: rival)', { size: 10.5, op: 0.65 });
  b += paras(x0 + 1170, y0 + 60, 'What tells them apart without colour: the Protagonist is broader (torso and limbs about 15 to 20 percent wider) with round masses (big dark plated fists, round shoulders, a short swept tuft); the rival is slimmer with one long diagonal slash behind him (the tail to the knee, the flat coat plates). Honest note: both are upright humanoids and their hair trails the same way, so at 25 px they differ mostly by the broad round body against the slim body with the long diagonal line; the fist ball and the tail are the two features that carry it.', 36, 11.5, 15, { op: 0.9 });
  return b;
}

// ------------------------------------------------------------------------------------------------------------ the two launch sheets
function pairSheet(who) {
  const W = 1800, ps = 250, H = 124 + 2 * ps + 40 + 330 + 130;
  const isP = who === 'P';
  let b = rect(0, 0, W, H, '#dcd8e6') + header(isP ? 'The Protagonist: refined face and silhouette' : 'The rival: refined face and silhouette, with the glasses', isP ? 'No mask. The face from the unmasked set, refined (heavier lids, an angled brow, a swept tuft), and the silhouette of the big-fist option; below, he and the rival flat black, to show they read apart. Working labels, pending Legal review.' : 'No mask. The refined unmasked face with the lead glasses (blade lenses, A), glare off and on, and the long-tail silhouette; below, he and the Protagonist flat black, to show they read apart. Working labels, pending Legal review.', W);
  if (isP) {
    ['neutral', 'hurt', 'laugh'].forEach((e, c) => { b += text(24 + c * (ps + 10), 134, c === 2 ? 'laugh (his signature)' : e, { size: 13, weight: 700 }) + plainFace('P', e, 24 + c * (ps + 10), 144, ps, true); });
    b += text(24, 144 + ps + 16, 'today (the engine\'s unmasked face), for comparison', { size: 11, op: 0.65 });
    ['neutral', 'hurt', 'laugh'].forEach((e, c) => { b += plainFace('P', e, 24 + c * 100 + 24 * 0, 144 + ps + 24, 94, false); });
  } else {
    [['clear', 'neutral'], ['glare', 'smirk'], ['clear', 'hurt'], ['clear', 'contempt']].forEach(([st, e], c) => { b += text(24 + c * (ps + 10), 134, `${st === 'glare' ? 'glare on (smirk)' : e + ', glasses clear'}`, { size: 13, weight: 700 }) + face('blade', st, 24 + c * (ps + 10), 144, ps, { expr: e }); });
    b += text(24, 144 + ps + 16, 'the same face, glasses off (neutral, hurt, contempt), for comparison', { size: 11, op: 0.65 });
    ['neutral', 'hurt', 'contempt'].forEach((e, c) => { b += plainFace('A', e, 24 + c * 100, 144 + ps + 24, 94, true); });
  }
  // the silhouette at gameplay size: today, the pick
  const sx = 1100, g = 144 + 230;
  b += rect(sx - 20, 124, W - sx - 4, 2 * ps + 30, BG, 'stroke="#1b1428" stroke-opacity="0.2"') + text(sx - 8, 146, isP ? 'Silhouette at gameplay size: today, then the pick (big plated fists)' : 'Silhouette at gameplay size: today, then the pick (long tail, coat blades, glasses)', { size: 13, weight: 700 });
  const today = isP ? OTHER_OPTS.P.base() : OTHER_OPTS.A.base(), pick = isP ? hero() : rival('blade', 'clear');
  b += fig(today, isP ? PAL.P : PAL.A, POSE0(isP ? 'P' : 'A'), sx + 90, g + 160, 2.0, false) + text(sx + 40, g + 184, 'today', { size: 11, op: 0.7 });
  b += fig(pick, isP ? PAL.P : PAL.A, POSE0(isP ? 'P' : 'A'), sx + 330, g + 160, 2.0, false) + text(sx + 280, g + 184, 'the pick', { size: 11, op: 0.7 });
  b += fig(pick, isP ? PAL.P : PAL.A, POSE0(isP ? 'P' : 'A'), sx + 520, g + 160, 1.0, false) + fig(pick, isP ? PAL.P : PAL.A, POSE0(isP ? 'P' : 'A'), sx + 580, g + 160, 1.0, true) + text(sx + 480, g + 184, 'at gameplay size, colour and flat', { size: 11, op: 0.7 });
  b += paras(sx - 8, g + 210, isP ? 'The pick: big solid plated fists and shoulders in his dark tunic value (never pale), and a short swept tuft. It gives him mass where the rival has length (a body about 20 percent broader than today), so he does not share the rival\'s long trailing line. The long ribbon tuft (the other option) was set aside for that reason.' : 'The pick: the tail to the knee and three flat coat plates hanging straight from the belt, with the lead blade-lens glasses. It makes him narrow and long (a body slightly slimmer than today). The swept shoulder blade (the other option) is held as an alternative.', 70, 11.5, 15, { op: 0.9 });
  b += readApart(24, 144 + 2 * ps + 40, W - 48, 'Do they read apart in silhouette alone? The Protagonist and the rival, flat black');
  const yq = 144 + 2 * ps + 40 + 346;
  b += text(24, yq, 'The one question for Orb', { size: 15, weight: 700 });
  b += paras(24, yq + 22, isP ? 'Is this the Protagonist: the big plated-fist silhouette with the refined face and the swept tuft (and does he read as a different shape from the rival)? Or would you rather the long swept tuft?' : 'Is this the rival: the long-tail silhouette with the lead blade-lens glasses (see glasses-compare.svg for the frame pick)? Or the swept shoulder blade instead of the coat plates?', 230, 12.5, 17);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${FILTERS}${b}</svg>`;
}

const ORIGIN = '<!-- Origin: procedural launch-pair sheet written by art/concepts/refine/gen-launch-pair.mjs (deterministic, no external images or fonts), Art Director session (Claude, claude-sonnet-5-5), 2026-10-03; prompt record art/prompts/ART-0015-launch-pair-look.md -->' + String.fromCharCode(10);
writeFileSync(join(OUT, 'glasses-compare.svg'), ORIGIN + glassesCompare());
writeFileSync(join(OUT, 'launch-pair-protagonist.svg'), ORIGIN + pairSheet('P'));
writeFileSync(join(OUT, 'launch-pair-rival.svg'), ORIGIN + pairSheet('A'));
console.log('wrote glasses-compare.svg, launch-pair-protagonist.svg, launch-pair-rival.svg');
