// Origin: procedural generator for the Blank variation sheets (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-09-29. Human direction: Orb, via the EP.
// Run from the repo root:  node art/concepts/blank/gen.mjs   (writes blank-1-seam.svg ... blank-5-aura.svg and blank-comparison.svg)
// The greybox mock-up embeds docs/rendering/img/civilians-after.png by relative path (the repo's own render, not a copy).

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeCtx, figure, CIVILIAN, CIV_POSES, POSES, V, add, mul } from '../anti-hero/kit.mjs';

// Fighters are staged in three-quarter view, turned about this many degrees from profile toward the camera.
export const YAW = 32;
import { FIGHTERS, ORDER, PALETTES as BASE_PALETTES, LANE } from '../directions/fighters.mjs';

const OUT = dirname(fileURLToPath(import.meta.url));
const F = n => n.toFixed(2);
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family=\"'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif\"";
const text = (x, y, t, { size = 14, weight = 400, fill = '#1b1428', anchor = 'start', op = 1, style = 'normal' } = {}) =>
  `<text x="${F(x)}" y="${F(y)}" ${FONT} font-size="${size}" font-weight="${weight}" font-style="${style}" fill="${fill}" text-anchor="${anchor}" opacity="${op}">${esc(t)}</text>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fill}" ${extra}/>`;
const wrap = (t, n) => { const w = t.split(' '), out = []; let line = ''; for (const x of w) { if ((line + ' ' + x).trim().length > n) { out.push(line.trim()); line = x; } else line += ' ' + x; } if (line.trim()) out.push(line.trim()); return out; };
const paras = (x, y, t, n, size = 13, gap = 17, o = {}) => wrap(t, n).map((l, i) => text(x, y + i * gap, l, { size, ...o })).join('');

// ---------------------------------------------------------------------------------------------------------- calm palettes
// The same fighters as the directions sheets, with calmer accents: muted, dusty and related, none of them jarring.
const CALM = {
  P: { hair: { light: '#8fd6c8', mid: '#3fae9c', shadow: '#22705f' }, accent: { light: '#8fd6c8', mid: '#4fb9a8', shadow: '#2a7568' } },
  A: { accent: { light: '#c2adf0', mid: '#9a80d8', shadow: '#5b479a' } },
  E: { base: { light: '#3a4029', mid: '#2a2f1e', shadow: '#191d11' }, accent: { light: '#dfe8a8', mid: '#b8c96a', shadow: '#6d7d30' } },
  C: { accent: { light: '#f0b4a8', mid: '#d8705f', shadow: '#8a3a30' } },
};
export const PAL = Object.fromEntries(ORDER.map(k => [k, { ...BASE_PALETTES[k], ...CALM[k] }]));
const SPOT = { P: PAL.P.accent.mid, A: PAL.A.accent.mid, E: PAL.E.accent.mid, C: PAL.C.accent.mid };
const NEUTRAL = {
  line: '#101014', skin: { light: '#e7c9ad', mid: '#c99a78', shadow: '#8f6448' }, hair: { light: '#5a4a3a', mid: '#3b3128', shadow: '#221b15' },
  base: { light: '#8a93a3', mid: '#6c7079', shadow: '#4a4f57' }, gear: { light: '#c7ccd6', mid: '#9aa1ad', shadow: '#6c7079' }, accent: { light: '#c7ccd6', mid: '#9aa1ad', shadow: '#6c7079' },
};

// ---------------------------------------------------------------------------------------------------------- geometry helpers
const lerp2 = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
const curve = (p0, p1, p2, n = 8) => Array.from({ length: n + 1 }, (_, i) => { const t = i / n; return [(1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]]; });
// A polyline turned into a filled band. w is a number or a function of t (0 to 1) for tapered brush strokes.
function band(pts, w) {
  const n = pts.length, L = [], R = [];
  for (let i = 0; i < n; i++) {
    const a = pts[Math.max(0, i - 1)], b = pts[Math.min(n - 1, i + 1)];
    let dx = b[0] - a[0], dy = b[1] - a[1]; const l = Math.hypot(dx, dy) || 1; dx /= l; dy /= l;
    const ww = (typeof w === 'function' ? w(i / (n - 1)) : w) / 2;
    L.push([pts[i][0] - dy * ww, pts[i][1] + dx * ww]); R.push([pts[i][0] + dy * ww, pts[i][1] - dx * ww]);
  }
  return [...L, ...R.reverse()];
}
const rot = (pts, deg, c) => { const a = deg * Math.PI / 180, ca = Math.cos(a), sa = Math.sin(a); return pts.map(([x, y]) => [c[0] + (x - c[0]) * ca - (y - c[1]) * sa, c[1] + (x - c[0]) * sa + (y - c[1]) * ca]); };
const scl = (pts, k, c) => pts.map(([x, y]) => [c[0] + (x - c[0]) * k, c[1] + (y - c[1]) * k]);
const circ = (c, r, n = 14) => Array.from({ length: n }, (_, i) => { const a = (i / n) * Math.PI * 2; return [c[0] + Math.cos(a) * r, c[1] + Math.sin(a) * r]; });

// where each blank head has its face: eye line, mouth line, front and back of the face zone (head-local units)
const FACE = { P: { x0: 1.2, x1: 6.2, ey: 10, my: 5.2 }, A: { x0: 1.4, x1: 6.4, ey: 9.8, my: 5 }, E: { x0: 0.8, x1: 4.4, ey: 12.6, my: 7 }, C: { x0: 1.6, x1: 6.2, ey: 10.2, my: 4.8 } };
export const EXPRS = ['neutral', 'taunt', 'hurt', 'rage', 'triumph'];

// ---------------------------------------------------------------------------------------------------------- the five variations
// Each is a function (concept key, palette, state) -> extra marks for the blank head, and hooks for the body and aura.
const seamMarks = (fk, pal, st) => {
  const f = FACE[fk], xm = (f.x0 + f.x1) / 2, e = st.expression ?? 'neutral';
  let eye, mouth = null, dim = false, w = 1.5;
  if (e === 'neutral') eye = [[f.x0, f.ey], [f.x1, f.ey]];
  if (e === 'taunt') { eye = [[f.x0 + 0.4, f.ey - 0.7], [f.x1, f.ey + 0.9]]; mouth = curve([f.x0 + 1.0, f.my], [xm, f.my - 0.8], [f.x1 - 0.2, f.my + 1.7]); }
  if (e === 'hurt') { eye = null; dim = true; }
  if (e === 'rage') { eye = [[f.x0, f.ey + 1.5], [f.x1, f.ey - 1.0]]; w = 2.4; mouth = [[f.x0 + 0.8, f.my], [f.x0 + 1.8, f.my + 1.1], [f.x0 + 2.8, f.my - 0.1], [f.x0 + 3.8, f.my + 1.1], [f.x1 - 0.2, f.my]]; }
  if (e === 'triumph') { eye = curve([f.x0, f.ey - 0.8], [xm, f.ey + 2.0], [f.x1, f.ey - 0.8]); w = 1.6; mouth = curve([f.x0 + 0.6, f.my + 1.3], [xm, f.my - 1.4], [f.x1 - 0.2, f.my + 1.3]); }
  const col = dim ? pal.accent.shadow : pal.accent.light, out = [];
  const add1 = (pts, ww) => { ww = Math.max(ww, 1.1); out.push({ poly: band(pts, ww * 2.9), fill: pal.accent.light, op: 0.28, line: false }); out.push({ poly: band(pts, ww), fill: col, line: false }); };
  if (eye) add1(eye, w);
  if (e === 'hurt') { add1([[f.x0, f.ey + 0.5], [f.x0 + 1.8, f.ey + 0.1]], 0.8); add1([[f.x0 + 3.2, f.ey - 0.4], [f.x1, f.ey - 1.0]], 0.7); }
  if (mouth) add1(mouth, 0.8);
  return out;
};

const porcelainMarks = (fk, pal, st) => {
  const f = FACE[fk], xm = (f.x0 + f.x1) / 2, e = st.expression ?? 'neutral', out = [];
  const shade = (pts, op) => out.push({ poly: pts, fill: '#3a2f4a', op, line: false });
  const brow = (y0, y1, thick, op) => shade(band([[f.x0 - 0.4, y0], [xm, (y0 + y1) / 2], [f.x1 + 0.2, y1]], thick), op);
  if (e === 'neutral') brow(f.ey + 1.0, f.ey + 1.0, 1.6, 0.22);
  if (e === 'taunt') { brow(f.ey + 1.6, f.ey + 0.2, 2.2, 0.34); out.push({ poly: band(curve([f.x0 + 0.8, f.my + 2.6], [xm, f.my + 3.6], [f.x1 - 0.4, f.my + 2.4]), 1.1), fill: '#fff', op: 0.75, line: false }); }
  if (e === 'hurt') { brow(f.ey + 0.2, f.ey + 2.0, 2.4, 0.34); out.push({ poly: band([[xm + 0.4, f.ey - 0.6], [xm + 0.8, f.ey - 2.4], [xm + 0.4, f.my + 1.6]], 0.55), fill: '#4a3b5a', op: 0.7, line: false }); }
  if (e === 'rage') { brow(f.ey + 2.4, f.ey - 0.8, 3.0, 0.5); shade(band([[f.x0, f.my - 0.4], [f.x1, f.my + 0.4]], 1.6), 0.3); }
  if (e === 'triumph') { brow(f.ey + 1.8, f.ey + 1.8, 0.9, 0.12); out.push({ poly: band(curve([f.x0 + 0.6, f.my + 3.0], [xm, f.my + 4.4], [f.x1 - 0.4, f.my + 3.0]), 1.5), fill: '#fff', op: 0.85, line: false }); }
  // glaze cracks grow with wear: hairlines first, then open cracks
  const w = st.wear ?? 0;
  const cracks = [[[f.x0 + 0.6, f.ey + 4], [f.x0 + 1.4, f.ey + 2.4], [f.x0 + 1.2, f.ey + 0.6]], [[xm + 1.0, f.my + 2], [xm + 1.6, f.my], [xm + 1.2, f.my - 1.6]], [[f.x1 - 0.6, f.ey - 1], [f.x1 - 1.6, f.ey - 2.4], [f.x1 - 1.2, f.ey - 4]]];
  cracks.slice(0, w).forEach((c, i) => out.push({ poly: band(c, 0.28 + 0.2 * (w - 1 - i)), fill: '#2a2233', line: false }));
  out.push({ poly: circ([f.x0 + 1.6, f.ey + 3.4], 0.9, 10), fill: '#fff', op: 0.85, line: false });
  return out;
};

const SIGIL = {
  P: (pal) => [{ pts: circ([0, 0], 3.4, 16), fill: 'acc' }, { pts: circ([0, 0], 2.0, 14), fill: 'mask' }, { pts: circ([0, 0], 0.9, 10), fill: 'acc' }],
  A: () => [{ pts: [[-0.55, -5], [0.55, -5], [0.3, 5], [-0.3, 5]], fill: 'acc' }, { pts: circ([1.6, 3.8], 0.7, 8), fill: 'acc' }],
  E: () => [{ pts: [[-2.6, 1.4], [0, 4], [2.6, 1.4], [2.6, 0.2], [0, 2.8], [-2.6, 0.2]], fill: 'acc' }, { pts: [[-2.6, -1.2], [0, 1.4], [2.6, -1.2], [2.6, -2.4], [0, 0.2], [-2.6, -2.4]], fill: 'acc' }],
  C: () => [{ pts: [[-3, -3], [3, -3], [3, 3], [-3, 3]], fill: 'acc' }, { pts: [[-2.2, -2.2], [2.2, -2.2], [2.2, 2.2], [-2.2, 2.2]], fill: 'mask' }, { pts: [[-0.4, -2.2], [0.4, -2.2], [0.4, 2.2], [-0.4, 2.2]], fill: 'acc' }, { pts: [[-2.2, -0.4], [2.2, -0.4], [2.2, 0.4], [-2.2, 0.4]], fill: 'acc' }],
};
const markedMarks = (fk, pal, st, maskFill) => {
  const f = FACE[fk], e = st.expression ?? 'neutral', c = [(f.x0 + f.x1) / 2 + 0.2, f.ey - 0.6], out = [];
  let k = 1, r = 0, dy = 0, col = pal.accent.mid;
  if (e === 'taunt') { r = 18; dy = 0.9; } if (e === 'hurt') { k = 0.85; col = pal.accent.shadow; } if (e === 'rage') { k = 1.3; col = pal.accent.mid; } if (e === 'triumph') { k = 1.1; col = pal.accent.light; }
  for (const part of SIGIL[fk](pal)) {
    let pts = part.pts.map(([x, y]) => [c[0] + x, c[1] + y + dy]);
    pts = scl(rot(pts, r, [c[0], c[1] + dy]), k, [c[0], c[1] + dy]);
    out.push({ poly: pts, fill: part.fill === 'mask' ? maskFill : col, line: false });
  }
  const cc = [c[0], c[1] + dy];
  if (e === 'hurt') out.push({ poly: band([[cc[0] - 1.6, cc[1] + 3.4], [cc[0] - 0.2, cc[1] + 0.4], [cc[0] + 0.6, cc[1] - 3.6]], 0.42), fill: '#2a2233', line: false });
  if (e === 'rage') for (let i = 0; i < 6; i++) { const a = -70 + i * 28; out.push({ poly: rot([[cc[0] + 4.2, cc[1] - 0.5], [cc[0] + 6.6, cc[1]], [cc[0] + 4.2, cc[1] + 0.5]], a, cc), fill: col, line: false }); }
  if (e === 'triumph') for (let i = 0; i < 7; i++) { const a = -80 + i * 26; out.push({ poly: band([[cc[0] + 4.6, cc[1]], [cc[0] + 6.4, cc[1]]].map(p => rot([p], a, cc)[0]), 0.5), fill: pal.accent.light, line: false }); }
  return out;
};

const brushMarks = (fk, pal, st) => {
  const f = FACE[fk], xm = (f.x0 + f.x1) / 2, e = st.expression ?? 'neutral', out = [];
  const stroke = (pts, w) => out.push({ poly: band(pts, t => w * Math.sin(Math.PI * Math.min(1, t * 0.9 + 0.1)) + 0.15), fill: '#14101c', line: false });
  if (e === 'neutral') stroke([[f.x0 - 0.2, f.ey], [xm, f.ey + 0.1], [f.x1, f.ey]], 1.5);
  if (e === 'taunt') { stroke(curve([f.x0 - 0.2, f.ey - 0.4], [xm, f.ey + 0.2], [f.x1 + 0.4, f.ey + 1.6]), 1.5); stroke(curve([f.x0 + 1, f.my + 0.4], [xm, f.my - 0.6], [f.x1, f.my + 1.6]), 0.9); }
  if (e === 'hurt') { stroke(curve([f.x0 - 0.2, f.ey + 1.4], [xm, f.ey + 1.4], [f.x1, f.ey - 0.4]), 1.4); out.push({ poly: circ([xm + 0.6, f.my + 1.4], 0.6, 8), fill: '#14101c', line: false }); }
  if (e === 'rage') { stroke([[f.x0 - 0.4, f.ey + 1.8], [xm, f.ey + 0.4], [f.x1 + 0.2, f.ey - 1.2]], 2.6); stroke([[f.x0 + 0.6, f.my], [f.x0 + 1.6, f.my + 1.2], [f.x0 + 2.6, f.my - 0.2], [f.x0 + 3.6, f.my + 1.2], [f.x1 - 0.2, f.my + 0.2]], 1.1); }
  if (e === 'triumph') { stroke(curve([f.x0 - 0.2, f.ey - 0.6], [xm, f.ey + 2.4], [f.x1, f.ey - 0.6]), 1.5); stroke(curve([f.x0 + 0.8, f.my + 1.4], [xm, f.my - 1.2], [f.x1 - 0.2, f.my + 1.4]), 0.9); }
  return out;
};

// the aura does the face's job: shapes hugging the head, drawn behind the figure
const auraShapes = (fk, sk, st, pal) => {
  const e = st.expression ?? 'neutral', H = (x, y) => sk.Hd(x, y), c = [3.6, 9.4], hs = sk.b.hs, R = 13.5;
  const P = arr => arr.map(([x, y]) => H(x, y));
  const light = pal.accent.light, mid = pal.accent.mid;
  const layer = (pts, fill, op) => ({ pts: P(pts), fill, op });
  const out = [];
  if (e === 'neutral') { out.push(layer(circ(c, R, 24), mid, 0.22), layer(circ(c, R - 2.4, 24), light, 0.3)); }
  if (e === 'taunt') { const arc = []; for (let i = 0; i <= 12; i++) { const a = -0.3 + i * 0.32; arc.push([c[0] - 4 + Math.cos(a) * (R + 1) * 0.9, c[1] + 4 + Math.sin(a) * (R + 6)]); } out.push(layer(band(curve([-2, 1], [-9, 8], [-4, 22], 10), 4.2), mid, 0.4), layer(circ([c[0] + 2, c[1] + 1], R - 1, 24), light, 0.24), layer(band(curve([2, 20], [8, 28], [16, 26], 8), 2.4), light, 0.55)); }
  if (e === 'hurt') { for (let i = 0; i < 4; i++) { const a0 = i * 1.6 + 0.2, pts = []; for (let k = 0; k <= 6; k++) { const a = a0 + k * 0.16; pts.push([c[0] + Math.cos(a) * (R + (i % 2)), c[1] + Math.sin(a) * (R + (i % 2))]); } out.push(layer(band(pts, 1.8), mid, 0.5)); } }
  if (e === 'rage') { const pts = []; for (let i = 0; i < 18; i++) { const a = (i / 18) * Math.PI * 2, rr = i % 2 ? R - 1 : R + 8 + (i % 4 === 0 ? 4 : 0); pts.push([c[0] + Math.cos(a) * rr, c[1] + Math.sin(a) * rr]); } out.push(layer(pts, mid, 0.42), layer(circ(c, R - 3, 20), light, 0.34)); }
  if (e === 'triumph') { for (let i = 0; i < 9; i++) { const a = Math.PI * (0.12 + i * 0.095), L = 24 + (i % 2) * 7; out.push(layer([[c[0] + Math.cos(a) * 8, c[1] + Math.sin(a) * 8], [c[0] + Math.cos(a - 0.07) * L, c[1] + Math.sin(a - 0.07) * L], [c[0] + Math.cos(a + 0.07) * L, c[1] + Math.sin(a + 0.07) * L]], i % 2 ? mid : light, 0.5)); } out.push(layer(circ(c, R - 1, 22), light, 0.3)); }
  return out;
};

export const VARIANTS = {
  seam: {
    n: 1, key: 'seam', file: 'blank-1-seam.svg', title: 'Seam', line: 'A dark matte mask with one glowing seam that changes shape with emotion. In three-quarter the seam wraps the front of the mask.',
    expression: 'The seam is the whole face: a flat line at rest, a slanted line and a smirk arc for the taunt, broken dashes for hurt, a hard angled slash and a jagged mouth for rage, and two joyful arcs for triumph.',
    oneliner: 'The seam pulses on the beat of the line, brighter on stressed syllables. The mouth seam appears only while a fighter speaks, so speech has a visible rhythm.',
    hurt: 'The seam breaks into dim dashes and the head drops.',
    transform: 'The seam thickens and splits into more lines with each form, and the glow spreads. Lane colour is the seam colour.',
    godot: 'Cheapest of the five. One emissive seam strip per fighter (or a few thin quads) driven by an expression uniform. No face rig. Seam glow is a flat wider quad behind, so no bloom is needed.',
    risk: 'A glowing visor can read as a robot or as another game\'s masked character. Keep the mask matte and the seam thin. Emissive seams overlap the Protagonist\'s planned heat seams, so the Protagonist\'s seam must stay teal and the heat effect must sit on the body.',
    marks: (fk, pal, st) => seamMarks(fk, pal, st),
  },
  porcelain: {
    n: 2, key: 'porcelain', file: 'blank-2-porcelain.svg', title: 'Porcelain', line: 'A glazed porcelain mask that acts through shadow, as a carved theatre mask does, and cracks with wear.',
    expression: 'No drawn features. The face is shadow shapes on a smooth mask: a soft brow shadow at rest, a heavy brow with a cheek highlight for the taunt, a drooping brow and a tear crack for hurt, a hard V shadow for rage, and a lifted brow and bright cheek for triumph. Head tilt does the rest.',
    oneliner: 'The jaw-side highlight sweeps with the line, and the mask tilts a few degrees on each beat, as a stage mask is turned to speak.',
    hurt: 'Hurt opens hairline cracks. The cracks stay and spread with wear, which is the wear readout on the head.',
    transform: 'The glaze cracks and a lane-coloured light shows through the cracks with each form.',
    godot: 'A mask mesh with a baked carved relief and a two-band cel, so the expression comes from moving the key light or one shadow-shape mesh. Cracks are decals driven by the head wear float, which the style guide already defines.',
    risk: 'Very subtle at 12 px: the expressions are shadow shapes and disappear far away. It leans on head tilt and close-ups. Porcelain can read as fragile, which needs Orb\'s approval for heavy hitters.',
    marks: (fk, pal, st) => porcelainMarks(fk, pal, st),
  },
  marked: {
    n: 3, key: 'marked', file: 'blank-3-marked.svg', title: 'Marked', line: 'A bold graphic sigil on the mask, different for each fighter, that bends with emotion and grows with form.',
    expression: 'One sigil per fighter (a ring, a slash, a crown of chevrons, a square grid). At rest it is clean. For the taunt it tilts and slides, for hurt it shrinks, dims and cracks, for rage it swells and grows spikes, and for triumph it brightens and throws rays.',
    oneliner: 'The sigil pulses in size with the line. Barks and taunts make it flick, so speech is a small animation of the mark.',
    hurt: 'The sigil dims and a crack runs through it. The crack is the head wear readout.',
    transform: 'The sigil grows and gains a ring per form, and matching bands appear on the arms and chest. Transformation is the mark spreading across the body.',
    godot: 'A sigil mesh or decal on the mask with an expression uniform for scale, rotation, tint and spikes. Body bands are decals from the same palette mask. The cheapest way to add form-by-form identity.',
    risk: 'Bold marks can read as clan symbols or tattoos with unintended meaning; each needs a Legal check. The Protagonist\'s ring and the Cyborg\'s square must not echo any franchise sign.',
    marks: (fk, pal, st, mask) => markedMarks(fk, pal, st, mask),
  },
  inked: {
    n: 4, key: 'inked', file: 'blank-4-inked.svg', title: 'Inked Blank', line: 'A blank body drawn with a heavy brush line, a dry edge and an ink shadow, with one brush stroke for a face.',
    expression: 'One painted brush stroke across the mask: level at rest, raised with a flick and a small mouth stroke for the taunt, drooping with a drip for hurt, a thick hard slash and a jagged mouth for rage, and an arch for triumph.',
    oneliner: 'The stroke twitches on stressed syllables and a mouth stroke appears while the fighter speaks. It reads like ink lettering.',
    hurt: 'The brush stroke droops and a drip falls. Wear adds ink splatter to the body.',
    transform: 'The line gets thicker and the ink shadow deeper with each form, and lane colour washes into the fill.',
    godot: 'Blank plus the Ink pipeline: inverted hull with per-vertex width from a noise map, an offset dark hull, a noise-cut edge, one 128 x 128 noise map. The brush stroke is a decal. Highest cost of the five.',
    risk: 'It carries Ink\'s risk: nearest to a generic heavy-outline look. Keep the line tinted, tapered and rough, over shaded coloured figures. Heavy lines also eat 12 px detail, so line width fades below 9 px. Legal to screen hardest.',
    marks: (fk, pal, st) => brushMarks(fk, pal, st),
  },
  aura: {
    n: 5, key: 'aura', file: 'blank-5-aura.svg', title: 'Aura', line: 'A plain blank mask. The aura around the head does the face\'s job.',
    expression: 'The mask never changes. The aura around the head is the expression: a calm ring at rest, a lopsided drifting curl for the taunt, broken arcs for hurt, a spiked flare for rage, and a fan of rays for triumph.',
    oneliner: 'The aura ring pulses on the beat of the line. A quiet ring for a soft line, a flare for a shout. The line and the aura share one envelope.',
    hurt: 'The ring breaks into arcs and the head drops.',
    transform: 'The aura grows and gains layers and shapes with each form, in the fighter\'s own colour. It is already planned as the tier and wound readout.',
    godot: 'No face work at all. The aura is a flat cel-shaded quad or ring mesh behind the head, driven by an expression uniform. It shares the planned aura crown and its VFX budget.',
    risk: 'It overlaps the aura crown, which is already the wound readout, so emotion and wear could clash. It also makes fighters unreadable when the aura is hidden or suppressed (hiding, cinematics). Aura colours must stay clear of gold and red for the Anti-hero and Protagonist.',
    marks: () => [],
    aura: true,
  },
};
export const VORDER = ['seam', 'porcelain', 'marked', 'inked', 'aura'];

// ---------------------------------------------------------------------------------------------------------- styling a fighter
const civC = {
  ...CIVILIAN,
  cfg: pal => ({ ...CIVILIAN.cfg(pal), torso: '#8a93a3', sleeve: '#8a93a3', torsoShade: '#00000030' }),
  blankHead: pal => ({ poly: [[-4.6, 1], [-5.4, 8], [-4.4, 14], [0, 16.4], [4.6, 14], [5.6, 8], [4, 1.5]], fill: pal.skin.mid, shadow: pal.skin.shadow, shade: [[-4.6, 1], [-5.4, 8], [-4.4, 14], [0, 16.4], [1, 16], [-2.4, 12], [-2.4, 6], [-1, 0.6]] }),
};

// Marks are drawn in profile face coordinates. In three-quarter they are moved onto the face plane: the face centre slides toward
// the middle of the head and the marks spread across it.
function yawMap(fk, yaw) {
  const f = FACE[fk], xm = (f.x0 + f.x1) / 2, a = yaw * Math.PI / 180, c = Math.cos(a), s = Math.sin(a), m = s;
  return ([u, y]) => [(1 - m) * u + m * (c * 5.4 + s * 1.5 * (u - xm)), y];
}

function styledConcept(fk, v, pal) {
  const base = FIGHTERS[fk], V0 = VARIANTS[v];
  const c = { ...base };
  c.blankHead = (p, st) => {
    const bh = base.blankHead(p);
    let marks = (bh.marks ?? []);
    if (fk === 'C' && v !== 'seam') marks = marks.map((m, i) => (i === 0 ? { ...m, fill: p.base.shadow } : m));
    if (fk === 'C' && v === 'seam') marks = marks.slice(1);
    let extra = V0.marks(fk, p, st, bh.fill);
    if ((st.yaw ?? 0) > 0) { const m = yawMap(fk, st.yaw); marks = marks.map(q => ({ ...q, poly: q.poly.map(m) })); extra = extra.map(q => ({ ...q, poly: q.poly.map(m) })); }
    if (v === 'seam') return { ...bh, fill: p.base.light, shadow: p.base.mid, neck: p.base.mid, marks: [...marks, ...extra] };
    if (v === 'porcelain') return { ...bh, fill: '#efe9e0', shadow: '#c9c0d0', neck: '#c9c0d0', marks: [...marks, ...extra] };
    if (v === 'inked') return { ...bh, fill: p.gear.light, marks: [...marks, ...extra] };
    return { ...bh, marks: [...marks, ...extra] };
  };
  if (V0.aura) {
    const prev = base.back;
    c.back = (ctx, sk, st, cfg) => (ctx.flat ? prev(ctx, sk, st, cfg) : auraShapes(fk, sk, st, ctx.pal).map(a => `<polygon points="${a.pts.map(p => `${p.x.toFixed(2)},${p.y.toFixed(2)}`).join(' ')}" fill="${a.fill}" opacity="${a.op}"/>`).join('') + prev(ctx, sk, st, cfg));
  }
  if (v === 'marked') {
    const prev = base.after;
    c.after = (ctx, sk, st, cfg) => {
      let o = prev ? prev(ctx, sk, st, cfg) : ''; if (ctx.flat) return o;
      const { pal: p } = ctx, n = st.forms ?? 6;
      // body bands, one more per form, in the sigil colour
      for (let i = 0; i < Math.min(n, 6); i++) {
        const t = 0.18 + i * 0.13, a = sk.nearArm;
        const p0 = V(a.E.x + (a.W.x - a.E.x) * t, a.E.y + (a.W.y - a.E.y) * t);
        o += `<circle cx="${p0.x.toFixed(2)}" cy="${p0.y.toFixed(2)}" r="0.9" fill="${p.accent.mid}"/>`;
      }
      const s1 = sk.T(4.6, 20), s2 = sk.T(2.4, 12);
      o += `<polyline points="${s1.x.toFixed(2)},${s1.y.toFixed(2)} ${s2.x.toFixed(2)},${s2.y.toFixed(2)}" stroke="${p.accent.mid}" stroke-width="1.6" fill="none" stroke-linecap="round"/>`;
      return o;
    };
  }
  return c;
}

const INK = '#14101c';
const DEFS = `<defs>
<pattern id="mail" width="3.2" height="3.2" patternUnits="userSpaceOnUse"><circle cx="1.6" cy="1.6" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/><circle cx="0" cy="0" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/><circle cx="3.2" cy="3.2" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/></pattern>
<pattern id="hatch" width="2.2" height="2.2" patternUnits="userSpaceOnUse" patternTransform="rotate(35)"><line x1="0" y1="0" x2="0" y2="2.2" stroke="#14101c" stroke-width="0.75" opacity="0.85"/></pattern>
<filter id="rough1" x="-15%" y="-15%" width="130%" height="130%"><feTurbulence type="fractalNoise" baseFrequency="0.22" numOctaves="1" seed="3" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="0.9" xChannelSelector="R" yChannelSelector="G"/></filter>
<filter id="rough2" x="-15%" y="-15%" width="130%" height="130%"><feTurbulence type="fractalNoise" baseFrequency="0.09" numOctaves="2" seed="3" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="2.4" xChannelSelector="R" yChannelSelector="G"/></filter>
<filter id="rough3" x="-15%" y="-15%" width="130%" height="130%"><feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="3" seed="3" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="4.6" xChannelSelector="R" yChannelSelector="G"/></filter>
<clipPath id="scene"><rect x="0" y="0" width="760" height="560"/></clipPath>
</defs>`;

const swFor = (v, px) => (v === 'inked' ? (px < 9 ? 0.3 : px < 28 ? 1.0 : px < 80 ? 2.2 : 4.0) : (px < 9 ? 0 : px < 28 ? 0.6 : px < 80 ? 1 : 1.3));
const roughFor = px => (px < 20 ? 'rough1' : px < 120 ? 'rough2' : 'rough3');

// The five emotions as poses. Neutral is the fighter's base pose.
function poseFor(fk, e) {
  const b = FIGHTERS[fk].poses.base;
  if (e === 'neutral') return b;
  if (e === 'taunt') return { ...b, lean: b.lean - 8, head: b.head - 16, nearArm: [58, 138], farArm: [-8, -64], handNear: 'open' };
  if (e === 'hurt') return { ...POSES.humbled, nearLeg: [26, -6], farLeg: [-12, -22] };
  if (e === 'rage') return { ...POSES.dropped };
  return { lean: -8, head: -22, nearArm: [152, 172], farArm: [-150, -170], nearLeg: [18, 4], farLeg: [-16, -4], handNear: 'fist', handFar: 'fist' }; // triumph
}

function fig(fk, v, px, x, ground, { flat = false, expr = 'neutral', civ = false, wear = 0, pose = null, yaw = YAW, flip = false } = {}) {
  const s = px / 100, pal = civ ? NEUTRAL : PAL[fk];
  const concept = civ ? civC : styledConcept(fk, v, pal);
  const swMul = swFor(v, px);
  const ctx = makeCtx({ flat, pal, swMul, faceless: true, shadeFill: v === 'inked' && px >= 90 ? 'url(#hatch)' : null });
  const p = pose ?? (civ ? CIV_POSES[0] : poseFor(fk, expr));
  const st = civ ? { expression: 'neutral', yaw } : { yaw, expression: expr, sway: FIGHTERS[fk].sway ?? 6, open: expr === 'rage' ? 1 : expr === 'hurt' ? 0.4 : 0, wear, forms: 6, hairLoose: expr === 'rage' || expr === 'hurt' };
  const { svg } = figure(ctx, concept, p, st, { yaw });
  const fl = flip ? `translate(${F(x)} 0) scale(-1 1) translate(${F(-x)} 0)` : '';
  const g = `<g${flip ? ` transform="${fl}"` : ''}><g transform="translate(${F(x)} ${F(ground)}) scale(${F(s)} ${F(-s)})">${svg}</g></g>`;
  if (v !== 'inked') return g;
  const off = Math.max(0.7, px / 26);
  const sh = figure(makeCtx({ flat: true, pal, swMul: 0, faceless: true }), concept, p, st, { yaw }).svg;
  return `<g filter="url(#${roughFor(px)})"><g${flip ? ` transform="${fl}"` : ''}><g transform="translate(${F(x + off)} ${F(ground + off)}) scale(${F(s)} ${F(-s)})" opacity="0.92">${sh}</g></g>${g}</g>`;
}

// A head-and-shoulders close-up: the same figure, drawn large and clipped to a square around the head.
function closeup(fk, v, e, x, y, size, px = 230) {
  const s = px / 100, pal = PAL[fk], concept = styledConcept(fk, v, pal);
  const ctx = makeCtx({ flat: false, pal, swMul: swFor(v, px), faceless: true, shadeFill: null });
  const p = poseFor(fk, e);
  const st = { yaw: YAW, expression: e, sway: FIGHTERS[fk].sway ?? 6, open: e === 'rage' ? 1 : 0, wear: v === 'porcelain' && e === 'hurt' ? 2 : 0, forms: 6, hairLoose: e === 'rage' || e === 'hurt' };
  const { svg, sk } = figure(ctx, concept, p, st, { yaw: YAW });
  const h = sk.Hd(3.2, 9.4);
  const cx = size / 2, cy = size / 2;
  return `<svg x="${F(x)}" y="${F(y)}" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" overflow="hidden">${rect(0, 0, size, size, '#f3f0f8')}<g transform="translate(${F(cx - h.x * s)} ${F(cy + h.y * s)}) scale(${F(s)} ${F(-s)})">${svg}</g></svg>` + rect(x, y, size, size, 'none', 'stroke="#1b1428" stroke-opacity="0.35"');
}

const SEA = { top: '#cfe6f0', bottom: '#2f86ad' };
const chip = (x, y, w, h) => rect(x, y, w, h, SEA.top) + rect(x, y + h * 0.5, w, h * 0.5, SEA.bottom);
const NAMES = { P: 'Protagonist', A: 'Anti-hero', E: 'Empress', C: 'Cyborg' };
const SCENE = '../../../docs/rendering/img/civilians-after.png';

// A mock-up in the actual greybox scene: the repo's own render as the backdrop (crop clear of the HUD and the placeholder fighters).
function mockup(v, x, y, scale = 1.18) {
  let b = `<g transform="translate(${F(x)} ${F(y)}) scale(${F(scale)})"><g clip-path="url(#scene)"><image href="${SCENE}" x="-250" y="-130" width="1280" height="720"/>`;
  const spots = [['P', 108, 350, 'neutral'], ['A', 300, 418, 'rage'], ['E', 512, 330, 'taunt'], ['C', 680, 424, 'neutral']];
  for (const [fk, px, py, e] of spots) b += fig(fk, v, 72, px, py, { expr: e, flip: fk === 'E' || fk === 'A' });
  b += '</g></g>';
  return b + rect(x, y + 560 * scale + 6, 1, 1, 'none');
}

// ---------------------------------------------------------------------------------------------------------- sheets
function variantSheet(vk) {
  const V1 = VARIANTS[vk], W = 1800, H = 1680;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, `Blank variation ${V1.n}: ${V1.title}`, { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, V1.line, { size: 15, fill: '#cfc6e6' });
  b += text(W - 30, 80, 'Working labels, placeholder looks. Status: proposal, pending Legal review.', { size: 12, fill: '#cfc6e6', anchor: 'end' });
  // the four fighters together
  b += rect(24, 124, W - 48, 420, '#e8e5ee', 'stroke="#1b1428" stroke-opacity="0.2"');
  const xs = { P: 250, A: 690, E: 1180, C: 1600 };
  for (const fk of ORDER) {
    b += fig(fk, vk, 300, xs[fk], 510);
    b += text(xs[fk], 536, `${NAMES[fk]}  (${LANE[fk]})`, { size: 13, weight: 600, anchor: 'middle', op: 0.85 });
  }
  b += text(40, 150, 'The four fighters together, showcase size, three-quarter view', { size: 12, weight: 700, op: 0.85 });
  // gameplay size
  b += text(24, 580, 'Gameplay size: 40 px and 12 px, colour and flat black, each with a civilian', { size: 13, weight: 700 });
  ORDER.forEach((fk, i) => {
    const x0 = 24 + i * 444;
    [[40, false, 0], [40, true, 1], [12, false, 2], [12, true, 3]].forEach(([px, flat, j]) => {
      const cx = x0 + j * 108, w = 100, cy = 596;
      b += flat ? rect(cx, cy, w, 100, '#f7f5fa', 'stroke="#1b1428" stroke-opacity="0.15"') : chip(cx, cy, w, 100);
      b += fig(fk, vk, px, cx + 66, cy + 88, { flat }) + fig(fk, vk, px, cx + 20, cy + 88, { flat, civ: true });
    });
    b += text(x0, 716, NAMES[fk], { size: 12, weight: 600, op: 0.85 });
  });
  // expression strips
  b += text(24, 752, 'Expression: neutral, taunt, hurt, rage, triumph', { size: 13, weight: 700 });
  ORDER.forEach((fk, r) => {
    const y0 = 764 + r * 176;
    b += text(24, y0 + 14, NAMES[fk], { size: 12, weight: 700 });
    EXPRS.forEach((e, j) => {
      const x0 = 24 + j * 162;
      b += rect(x0, y0 + 20, 156, 148, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"');
      b += fig(fk, vk, 104, x0 + (fk === 'E' ? 76 : 56), y0 + 160, { expr: e, wear: vk === 'porcelain' && e === 'hurt' ? 2 : 0 });
      b += closeup(fk, vk, e, x0 + 80, y0 + 22, 72, 118);
      b += text(x0 + 6, y0 + 36, e, { size: 11, op: 0.75 });
    });
  });
  // the greybox mock-up
  b += text(850, 752, 'In the greybox scene (the repo\'s own render as the backdrop)', { size: 13, weight: 700 });
  b += rect(848, 762, 900, 663, '#000', 'opacity="0"');
  b += mockup(vk, 850, 764, 1.18);
  b += paras(850, 1442, 'Protagonist (neutral), Anti-hero (rage, mirrored), Empress (taunt, mirrored), Cyborg (neutral). Three-quarter, mirrored when facing left so the front always faces the camera. Drawn at 72 px, the size of the greybox fighters.', 118, 11.5, 15, { op: 0.8 });
  // text blocks
  const ty = 1480, cols = [['How emotion reads', V1.expression], ['One-liners, hurt and transformation', `${V1.oneliner} ${V1.hurt} ${V1.transform}`], ['How it builds in Godot', V1.godot], ['Risks', V1.risk]];
  cols.forEach(([h, t], i) => { const x = 30 + i * 444; b += text(x, ty, h, { size: 16, weight: 700 }) + paras(x, ty + 24, t, 60, 12.5, 17); });
  b += text(30, H - 22, 'Common rules kept: the value rule, the two-tone edge, the far beacon, calm harmonious colour, and no borrowed look (masks are designed shapes, never grey and round, with no cross-mark or dot eyes).', { size: 12, op: 0.8 });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

function comparisonSheet() {
  const W = 1800, H = 1500;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'Blank variations: comparison', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'Five ways to push Blank somewhere unique. Four fighters each, then the Protagonist through five emotions. Orb decides. Pending Legal review.', { size: 15, fill: '#cfc6e6' });
  VORDER.forEach((vk, r) => {
    const V1 = VARIANTS[vk], y0 = 120 + r * 276, rh = 266;
    b += rect(24, y0, W - 48, rh, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.2"');
    b += text(40, y0 + 34, `${V1.n}. ${V1.title}`, { size: 24, weight: 700 });
    b += paras(40, y0 + 56, V1.line, 26, 12, 15, { op: 0.9 });
    const CX = { P: 330, A: 500, E: 730, C: 930 }; ORDER.forEach((fk) => { b += fig(fk, vk, 170, CX[fk], y0 + 236); });
    EXPRS.forEach((e, j) => { const x = 1046 + j * 132; b += fig('P', vk, 92, x, y0 + 236, { expr: e }) + text(x, y0 + 252, e, { size: 10.5, anchor: 'middle', op: 0.75 }); });
  });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

const ORIGIN = '<!-- Origin: procedural concept sheet written by art/concepts/blank/gen.mjs (deterministic, no external images or fonts; the mock-up embeds the repo\'s own render docs/rendering/img/civilians-after.png by reference), Art Director session (Claude, claude-sonnet-5-5), 2026-09-29; prompt record art/prompts/ART-0004-blank-variations.md -->' + String.fromCharCode(10);
const only = process.argv[2];
if (!only || only === 'all') {
  for (const k of VORDER) writeFileSync(join(OUT, VARIANTS[k].file), ORIGIN + variantSheet(k));
  writeFileSync(join(OUT, 'blank-comparison.svg'), ORIGIN + comparisonSheet());
  console.log('wrote 5 variant sheets and blank-comparison.svg');
} else if (VARIANTS[only]) {
  writeFileSync(join(OUT, VARIANTS[only].file), ORIGIN + variantSheet(only));
  console.log('wrote', VARIANTS[only].file);
}
