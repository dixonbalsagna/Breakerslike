// Origin: shared geometry, palettes, mask tones and sigils for the Marked plus flashes style (deterministic, no randomness).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-09-29. Human direction: Orb, via the EP.
// Legal's conditions (docs/legal/q3-screen.md, "Marked plus Aura") are applied here:
//   ring: a single ring, no concentric rings, no centre dot, never with the slash, never centred on the forehead (it sits off-centre at the temple, above the brow ridge);
//   no rays around any sigil in any state (Legal, second pass);
//   the Cyborg's four squares are a diagonal stair, never a 2 by 2 block;
//   slash: never crossed into an X, and never with the ring (hurt shows a break, not a crossing line);
//   chevrons: three, of different sizes and offset, in moss green (not a car or oil brand's colours);
//   grid: not a line grid: lit stepped squares, no plus or cross;
//   dome: a designed dome with a brow ridge, a jaw plane and a crown seam; no eye or mouth slots or dots, and the sigil sits on the forehead.

import { ORDER, PALETTES as BASE_PALETTES } from '../directions/fighters.mjs';

export { ORDER };
export const NAMES = { P: 'Protagonist', A: 'Anti-hero', E: 'Empress', C: 'Cyborg' };

// ---------------------------------------------------------------------------------------------------------- palettes and mask tones
const CALM = {
  P: { hair: { light: '#8fd6c8', mid: '#3fae9c', shadow: '#22705f' }, accent: { light: '#8fd6c8', mid: '#4fb9a8', shadow: '#2a7568' } },
  A: { accent: { light: '#c2adf0', mid: '#9a80d8', shadow: '#5b479a' } },
  E: { base: { light: '#3a4029', mid: '#2a2f1e', shadow: '#191d11' }, accent: { light: '#dfe8a8', mid: '#b8c96a', shadow: '#6d7d30' } },
  C: { accent: { light: '#f0b4a8', mid: '#d8705f', shadow: '#8a3a30' } },
};
export const PAL = Object.fromEntries(ORDER.map(k => [k, { ...BASE_PALETTES[k], ...CALM[k] }]));
// Mask tone per fighter (approved by Orb): dark masks carry an emissive sigil, pale masks a painted one.
export const MASK = {
  P: { tone: 'pale', fill: '#e8f1ee', shadow: '#b9cfc9', why: 'Earnest, open, approachable. A pale mask is a small beacon over the dark tunic at 40 px.' },
  A: { tone: 'dark', fill: '#2b2444', shadow: '#1a1530', why: 'Guarded and formal: the face is a closed front. The emissive sigil breaks with the facade. Dark reads well against sky.' },
  E: { tone: 'pale', fill: '#e6e0c4', shadow: '#bdb692', why: 'Image-focused and theatrical: a polished bone mask, warm not white. No horns, and the rest of her is dark olive.' },
  C: { tone: 'dark', fill: '#34313d', shadow: '#221f29', why: 'A machine wearing politeness: a dark display face with lit stepped squares. The polite menace, and a lit screen is its expression.' },
};
export const NEUTRAL = {
  line: '#101014', skin: { light: '#e7c9ad', mid: '#c99a78', shadow: '#8f6448' }, hair: { light: '#5a4a3a', mid: '#3b3128', shadow: '#221b15' },
  base: { light: '#8a93a3', mid: '#6c7079', shadow: '#4a4f57' }, gear: { light: '#c7ccd6', mid: '#9aa1ad', shadow: '#6c7079' }, accent: { light: '#c7ccd6', mid: '#9aa1ad', shadow: '#6c7079' },
};

// ---------------------------------------------------------------------------------------------------------- geometry helpers
export const curve = (p0, p1, p2, n = 8) => Array.from({ length: n + 1 }, (_, i) => { const t = i / n; return [(1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]]; });
export function band(pts, w) {
  const n = pts.length, L = [], R = [];
  for (let i = 0; i < n; i++) {
    const a = pts[Math.max(0, i - 1)], b = pts[Math.min(n - 1, i + 1)];
    let dx = b[0] - a[0], dy = b[1] - a[1]; const l = Math.hypot(dx, dy) || 1; dx /= l; dy /= l;
    const ww = (typeof w === 'function' ? w(i / (n - 1)) : w) / 2;
    L.push([pts[i][0] - dy * ww, pts[i][1] + dx * ww]); R.push([pts[i][0] + dy * ww, pts[i][1] - dx * ww]);
  }
  return [...L, ...R.reverse()];
}
export const rot = (pts, deg, c) => { const a = deg * Math.PI / 180, ca = Math.cos(a), sa = Math.sin(a); return pts.map(([x, y]) => [c[0] + (x - c[0]) * ca - (y - c[1]) * sa, c[1] + (x - c[0]) * sa + (y - c[1]) * ca]); };
export const scl = (pts, k, c) => pts.map(([x, y]) => [c[0] + (x - c[0]) * k, c[1] + (y - c[1]) * k]);
export const circ = (c, r, n = 14) => Array.from({ length: n }, (_, i) => { const a = (i / n) * Math.PI * 2; return [c[0] + Math.cos(a) * r, c[1] + Math.sin(a) * r]; });
export const FACE = { P: { x0: 1.2, x1: 6.2, ey: 10, my: 5.2 }, A: { x0: 1.4, x1: 6.4, ey: 9.8, my: 5 }, E: { x0: 0.8, x1: 4.4, ey: 12.6, my: 7 }, C: { x0: 1.6, x1: 6.2, ey: 10.2, my: 4.8 } };
// where each sigil sits on the mask, in head-local units: the forehead for the dome and the Empress, the middle of the face for the wedge and the display
const EXP = { P: 1.1, A: 1.6, E: 1.15, C: 1.0 };   // horizontal stretch of a sigil at three-quarter, so it stays on the mask and stays legible
export const SIGPOS = { P: [-2.1, 13.7], A: [4.1, 9.2], E: [2.6, 10.2], C: [2.4, 9.8] };
// Face-on (yaw 90): the kit collapses head x into two edges, so sigils and mask marks are placed in its input units (about +-3.2 across the face).
// Sigil centre (cx) and scale (k) per fighter; the Protagonist's ring stays off-centre at the temple.
const FRONT = { P: { cx: -1.5, k: 0.7 }, A: { cx: 0.25, k: 0.85 }, E: { cx: 0, k: 0.8 }, C: { cx: 0, k: 0.62 } };
export const yawMap = (fk, yaw) => { const f = FACE[fk], xm = (f.x0 + f.x1) / 2, a = yaw * Math.PI / 180, c = Math.cos(a), s = Math.sin(a), m = s; return ([u, y]) => [(1 - m) * u + m * (c * 5.4 + s * 1.5 * (u - xm)), y]; };

// ---------------------------------------------------------------------------------------------------------- the sigils
// gap is true in hurt and brink: the sigil shows a break (a gap in the ring, a split slash, a missing chevron or step), never a line across it.
function sigilParts(fk, gap) {
  if (fk === 'P') {
    if (!gap) return [{ pts: circ([0, 0], 1.65, 20), fill: 'acc' }, { pts: circ([0, 0], 1.0, 18), fill: 'mask' }];
    const arc = []; for (let a = 40; a <= 325; a += 15) arc.push([Math.cos(a * Math.PI / 180) * 2.6, Math.sin(a * Math.PI / 180) * 2.6]);
    return [{ pts: band(arc, 1.2), fill: 'acc' }];
  }
  if (fk === 'A') {
    const lean = pts => rot(pts, -12, [0, 0]);   // the slash leans, so it reads as a slash and not a bar
    if (!gap) return [{ pts: lean([[-0.8, -5], [0.8, -5], [0.45, 5], [-0.45, 5]]), fill: 'acc' }, { pts: circ([1.9, 3.6], 0.7, 8), fill: 'acc' }];
    return [{ pts: lean([[-1.3, -5], [0.3, -5], [0.05, -0.6], [-1.05, -0.6]]), fill: 'acc' }, { pts: lean([[0.3, 0.6], [1.1, 0.6], [0.95, 5], [0.15, 5]]), fill: 'acc' }, { pts: circ([2.2, 3.6], 0.7, 8), fill: 'acc' }];
  }
  if (fk === 'E') {
    const chev = (cx, cy, w) => { const h = w * 0.8, t = Math.max(0.9, w * 0.42); return { pts: [[cx - w, cy], [cx, cy + h], [cx + w, cy], [cx + w, cy - t], [cx, cy + h - t], [cx - w, cy - t]], fill: 'acc' }; };
    const all = [chev(-0.4, -1.9, 1.3), chev(0.4, -0.2, 1.9), chev(0, 1.7, 2.6)];
    return gap ? [all[0], all[2]] : all;
  }
  const K = 0.8, sq = (cx, cy, s) => { cx *= K; cy *= K; s *= K; return { pts: [[cx - s / 2, cy - s / 2], [cx + s / 2, cy - s / 2], [cx + s / 2, cy + s / 2], [cx - s / 2, cy + s / 2]], fill: 'acc' }; };
  const all = [sq(-3, -3, 1.7), sq(-1.2, -1.2, 2.1), sq(1.2, 0.9, 2.5), sq(3.9, 3.2, 2.9)];
  return gap ? [all[0], all[1], all[3]] : all;
}

// state: neutral, pride, taunt, hurt, brink, rage, triumph, transform. yaw > 0 maps the sigil onto the face plane.
export function sigilMarks(fk, pal, state, mask, yaw = 0) {
  const dark = mask.tone === 'dark', out = [], c = SIGPOS[fk];
  let k = 1, r = 0, dy = 0, col = dark ? pal.accent.light : pal.accent.mid, glow = 0;
  if (state === 'pride') k = 1.08;
  if (state === 'taunt') { r = 18; dy = 0.9; }
  if (state === 'hurt') { k = 0.85; col = dark ? pal.accent.mid : pal.accent.shadow; }
  if (state === 'brink') { k = 0.78; col = pal.accent.shadow; }
  if (state === 'rage') { k = 1.3; col = pal.accent.light; glow = 1; }
  if (state === 'triumph') { k = 1.12; col = pal.accent.light; glow = 1; }
  if (state === 'transform') { k = 1.4; col = pal.accent.light; glow = 1; }
  const cc = [c[0], c[1] + dy];
  const place = pts => scl(rot(pts.map(([x, y]) => [c[0] + x, c[1] + y + dy]), r, cc), k, cc);
  const parts = sigilParts(fk, state === 'hurt' || state === 'brink');
  if (dark || glow) for (const part of parts) if (part.fill === 'acc') out.push({ poly: scl(place(part.pts), 1.5, cc), fill: pal.accent.light, op: dark ? 0.26 : 0.34, line: false });
  for (const part of parts) out.push({ poly: place(part.pts), fill: part.fill === 'mask' ? mask.fill : col, line: false });
  if (yaw >= 85) { const f = FRONT[fk]; return out.map(q => ({ ...q, poly: q.poly.map(([x, y]) => [f.cx + (x - cc[0]) * f.k, y]) })); }
  if (yaw > 0) { const m = yawMap(fk, yaw), ex = ([x, y]) => [cc[0] + (x - cc[0]) * (yaw >= 60 ? 0.7 : EXP[fk]), y]; return out.map(q => ({ ...q, poly: q.poly.map(ex).map(m) })); }
  return out;
}

// ---------------------------------------------------------------------------------------------------------- the mask shapes
// The Protagonist's mask is a designed dome, not a plain egg: a faceted crown, a raised brow ridge, a jaw plane and a crown seam. It has
// no eye or mouth slots or dots. The other masks keep their fighter's shape.
export function maskHead(fk, bh, pal, mask, yaw = 0) {
  let poly = bh.poly, shade = bh.shade, marks = bh.marks ?? [];
  if (fk === 'C') marks = marks.slice(1);
  if (fk === 'E') marks = [];   // the painted headband mark goes: the chevrons take the brow, and the gear band stays over the hair line
  if (fk === 'P') {
    poly = [[-5.4, 1.2], [-6.8, 6.2], [-6.6, 12], [-3.8, 16.4], [1.2, 18], [5.8, 15.6], [7.4, 10.4], [6.6, 4.4], [3.4, 0.2], [-1.4, 0.2]];
    shade = [[-5.4, 1.2], [-6.8, 6.2], [-6.6, 12], [-3.8, 16.4], [-2.2, 17.2], [-4, 11.6], [-3.6, 5.6], [-1.6, 0.4]];
    marks = [
      { poly: [[-6.5, 9.4], [7.2, 9.4], [7.3, 8.5], [-6.6, 8.5]], fill: mask.shadow, op: 0.55, line: false },   // brow ridge
      { poly: [[-4.4, 1.6], [5.4, 1.6], [3.4, 0.25], [-1.4, 0.25]], fill: mask.shadow, op: 0.5, line: false },      // jaw plane
      { poly: [[-1.4, 17.7], [-0.4, 17.9], [0.5, 12.6], [-0.3, 12.6]], fill: mask.shadow, op: 0.6, line: false },   // crown seam
    ];
  }
  if (yaw >= 85) marks = marks.map(q => ({ ...q, poly: q.poly.map(([x, y]) => [(x - 0.4) * 0.42, y]) }));
  else if (yaw > 0) { const m = yawMap(fk, yaw); marks = marks.map(q => ({ ...q, poly: q.poly.map(m) })); }
  return { ...bh, poly, shade, marks, fill: mask.fill, shadow: mask.shadow, neck: mask.shadow };
}
