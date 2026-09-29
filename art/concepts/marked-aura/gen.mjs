// Origin: procedural generator for the Marked plus Aura sheets (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-09-29. Human direction: Orb, via the EP.
// Run from the repo root:  node art/concepts/marked-aura/gen.mjs   (writes ma-1-style.svg, ma-2-flashes.svg, ma-3-staging.svg, ma-4-flash-rules.svg, flashes.json)
// The staging mock-ups embed the repo's own greybox renders in docs/rendering/img by relative path (not copies).

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeCtx, figure, CIVILIAN, CIV_POSES, POSES, V } from '../anti-hero/kit.mjs';
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

export const YAW = 32;
const NAMES = { P: 'Protagonist', A: 'Anti-hero', E: 'Empress', C: 'Cyborg' };

// ---------------------------------------------------------------------------------------------------------- palettes and mask tones
const CALM = {
  P: { hair: { light: '#8fd6c8', mid: '#3fae9c', shadow: '#22705f' }, accent: { light: '#8fd6c8', mid: '#4fb9a8', shadow: '#2a7568' } },
  A: { accent: { light: '#c2adf0', mid: '#9a80d8', shadow: '#5b479a' } },
  E: { base: { light: '#3a4029', mid: '#2a2f1e', shadow: '#191d11' }, accent: { light: '#dfe8a8', mid: '#b8c96a', shadow: '#6d7d30' } },
  C: { accent: { light: '#f0b4a8', mid: '#d8705f', shadow: '#8a3a30' } },
};
export const PAL = Object.fromEntries(ORDER.map(k => [k, { ...BASE_PALETTES[k], ...CALM[k] }]));
// Mask tone per fighter, by personality and by readability. Dark masks carry an emissive sigil; pale masks a painted one.
export const MASK = {
  P: { tone: 'pale', fill: '#e8f1ee', shadow: '#b9cfc9', why: 'Earnest, open, approachable. A pale mask is a small beacon over the dark tunic at 40 px.' },
  A: { tone: 'dark', fill: '#2b2444', shadow: '#1a1530', why: 'Guarded and formal: the face is a closed front. The emissive sigil cracks with the facade. Dark reads well against sky.' },
  E: { tone: 'pale', fill: '#e6e0c4', shadow: '#bdb692', why: 'Image-focused and theatrical: a polished bone mask, warm not white. No horns, and the rest of her is dark olive.' },
  C: { tone: 'dark', fill: '#34313d', shadow: '#221f29', why: 'A machine wearing politeness: a dark display face with a lit sigil grid. It is the polite menace, and a lit screen is its expression.' },
};
const NEUTRAL = {
  line: '#101014', skin: { light: '#e7c9ad', mid: '#c99a78', shadow: '#8f6448' }, hair: { light: '#5a4a3a', mid: '#3b3128', shadow: '#221b15' },
  base: { light: '#8a93a3', mid: '#6c7079', shadow: '#4a4f57' }, gear: { light: '#c7ccd6', mid: '#9aa1ad', shadow: '#6c7079' }, accent: { light: '#c7ccd6', mid: '#9aa1ad', shadow: '#6c7079' },
};

// ---------------------------------------------------------------------------------------------------------- geometry helpers
const curve = (p0, p1, p2, n = 8) => Array.from({ length: n + 1 }, (_, i) => { const t = i / n; return [(1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]]; });
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
const FACE = { P: { x0: 1.2, x1: 6.2, ey: 10, my: 5.2 }, A: { x0: 1.4, x1: 6.4, ey: 9.8, my: 5 }, E: { x0: 0.8, x1: 4.4, ey: 12.6, my: 7 }, C: { x0: 1.6, x1: 6.2, ey: 10.2, my: 4.8 } };

// ---------------------------------------------------------------------------------------------------------- the sigil (identity and small expression)
const SIGIL = {
  P: () => [{ pts: circ([0, 0], 3.4, 16), fill: 'acc' }, { pts: circ([0, 0], 2.0, 14), fill: 'mask' }, { pts: circ([0, 0], 0.9, 10), fill: 'acc' }],
  A: () => [{ pts: [[-0.55, -5], [0.55, -5], [0.3, 5], [-0.3, 5]], fill: 'acc' }, { pts: circ([1.6, 3.8], 0.7, 8), fill: 'acc' }],
  E: () => [{ pts: [[-2.6, 1.4], [0, 4], [2.6, 1.4], [2.6, 0.2], [0, 2.8], [-2.6, 0.2]], fill: 'acc' }, { pts: [[-2.6, -1.2], [0, 1.4], [2.6, -1.2], [2.6, -2.4], [0, 0.2], [-2.6, -2.4]], fill: 'acc' }],
  C: () => [{ pts: [[-3, -3], [3, -3], [3, 3], [-3, 3]], fill: 'acc' }, { pts: [[-2.2, -2.2], [2.2, -2.2], [2.2, 2.2], [-2.2, 2.2]], fill: 'mask' }, { pts: [[-0.4, -2.2], [0.4, -2.2], [0.4, 2.2], [-0.4, 2.2]], fill: 'acc' }, { pts: [[-2.2, -0.4], [2.2, -0.4], [2.2, 0.4], [-2.2, 0.4]], fill: 'acc' }],
};
const yawMap = (fk, yaw) => { const f = FACE[fk], xm = (f.x0 + f.x1) / 2, a = yaw * Math.PI / 180, c = Math.cos(a), s = Math.sin(a), m = s; return ([u, y]) => [(1 - m) * u + m * (c * 5.4 + s * 1.5 * (u - xm)), y]; };

function sigilMarks(fk, pal, e, mask) {
  const f = FACE[fk], c = [(f.x0 + f.x1) / 2 + 0.2, f.ey - 0.6], dark = mask.tone === 'dark', out = [];
  let k = 1, r = 0, dy = 0, col = dark ? pal.accent.light : pal.accent.mid, glow = 0;
  if (e === 'pride') { k = 1.08; }
  if (e === 'taunt') { r = 18; dy = 0.9; }
  if (e === 'hurt') { k = 0.85; col = dark ? pal.accent.mid : pal.accent.shadow; }
  if (e === 'brink') { k = 0.78; col = pal.accent.shadow; }
  if (e === 'rage') { k = 1.3; col = pal.accent.light; glow = 1; }
  if (e === 'triumph') { k = 1.12; col = pal.accent.light; glow = 1; }
  if (e === 'transform') { k = 1.4; col = pal.accent.light; glow = 1; }
  const cc = [c[0], c[1] + dy];
  const place = pts => scl(rot(pts.map(([x, y]) => [c[0] + x, c[1] + y + dy]), r, cc), k, cc);
  const parts = SIGIL[fk](pal);
  if (dark || glow) for (const part of parts) if (part.fill === 'acc') out.push({ poly: scl(place(part.pts), 1.5, cc), fill: pal.accent.light, op: dark ? 0.26 : 0.34, line: false });
  for (const part of parts) out.push({ poly: place(part.pts), fill: part.fill === 'mask' ? mask.fill : col, line: false });
  if (e === 'hurt') out.push({ poly: band([[cc[0] - 1.6, cc[1] + 3.4], [cc[0] - 0.2, cc[1] + 0.4], [cc[0] + 0.6, cc[1] - 3.6]], 0.42), fill: '#1c1626', line: false });
  if (e === 'brink') { out.push({ poly: band([[cc[0] - 2.2, cc[1] + 3.8], [cc[0] - 0.4, cc[1] + 0.6], [cc[0] + 0.8, cc[1] - 4]], 0.7), fill: '#1c1626', line: false }); out.push({ poly: band([[cc[0] + 1.6, cc[1] + 3], [cc[0] + 0.2, cc[1] - 0.6]], 0.5), fill: '#1c1626', line: false }); }
  if (e === 'rage' || e === 'transform') for (let i = 0; i < 6; i++) out.push({ poly: rot([[cc[0] + 4.2, cc[1] - 0.5], [cc[0] + 6.6, cc[1]], [cc[0] + 4.2, cc[1] + 0.5]], -70 + i * 28, cc), fill: col, line: false });
  if (e === 'triumph') for (let i = 0; i < 7; i++) out.push({ poly: band([[cc[0] + 4.6, cc[1]], [cc[0] + 6.4, cc[1]]].map(p => rot([p], -80 + i * 26, cc)[0]), 0.5), fill: pal.accent.light, line: false });
  return out;
}

// ---------------------------------------------------------------------------------------------------------- the flashes (emanata at the head)
// A brief, iconic pop at the head that says what a fighter senses or feels. At rest there is nothing. Each flash is drawn in the
// fighter's shape family (circles: Protagonist, blades: Anti-hero, wedges: Empress, steps: Cyborg) and comes in two classes:
//   info    (danger, found, searching): solid, crisp, keylined, at full opacity. Gameplay information.
//   emotion (the rest): translucent, softer, a rim and a lighter core. Feeling and state.
const LAY = {
  taunt: [{ a: 125, d: 10, s: 30, op: 0.42 }, { a: 152, d: 9, s: 22, op: 0.38 }, { a: 100, d: 8, s: 16, op: 0.34 }],
  hurt: [{ a: 205, d: 15, s: 9, op: 0.42 }, { a: 250, d: 20, s: 7, op: 0.36 }, { a: 165, d: 22, s: 8, op: 0.36 }, { a: 300, d: 16, s: 6, op: 0.32 }],
  brink: [{ a: 230, d: 18, s: 7, op: 0.34 }, { a: 190, d: 24, s: 6, op: 0.3 }, { a: 265, d: 22, s: 5, op: 0.26 }],
  rage: [{ a: 0, d: 10, s: 44, op: 0.55 }, { a: 24, d: 10, s: 56, op: 0.55 }, { a: 48, d: 10, s: 66, op: 0.55 }, { a: 74, d: 10, s: 56, op: 0.55 }, { a: 100, d: 10, s: 46, op: 0.5 }, { a: -24, d: 10, s: 36, op: 0.48 }, { a: 126, d: 10, s: 32, op: 0.46 }],
  triumph: [20, 40, 60, 80, 100, 120, 140, 160].map((a, i) => ({ a, d: 11, s: 42 + (i % 2) * 12, op: 0.5 })),
  pride: [{ a: 90, d: 10, s: 60, op: 0.46 }, { a: 78, d: 9, s: 44, op: 0.42 }, { a: 102, d: 9, s: 44, op: 0.42 }, { a: 66, d: 8, s: 28, op: 0.38 }, { a: 114, d: 8, s: 28, op: 0.38 }],
  fear: [{ a: 40, d: 30, s: 14, op: 0.42, inward: true }, { a: 90, d: 32, s: 16, op: 0.42, inward: true }, { a: 140, d: 30, s: 14, op: 0.42, inward: true }, { a: 15, d: 24, s: 10, op: 0.36, inward: true }, { a: 165, d: 24, s: 10, op: 0.36, inward: true }],
  resolve: [{ a: 20, d: 22, s: 13, op: 0.44, inward: true }, { a: 90, d: 26, s: 15, op: 0.44, inward: true }, { a: 160, d: 22, s: 13, op: 0.44, inward: true }, { a: 90, d: 6, s: 22, op: 0.5 }],
  danger: [{ a: -26, d: 14, s: 24, op: 0.95 }, { a: 0, d: 14, s: 34, op: 0.95 }, { a: 26, d: 14, s: 24, op: 0.95 }],
  surge: [...[60, 75, 90, 105, 120].map(a => ({ a, d: 10, s: 96, op: 0.55 })), ...[0, 30, 150, 180].map(a => ({ a, d: 12, s: 56, op: 0.5 })), ...[186, 196, 344, 354].map(a => ({ a, d: 50, s: 30, op: 0.42, ground: true }))],
};
// timing t = [attack, hold, fade] in seconds; pri 1 is the highest priority; cool is the per-fighter cooldown for the same flash.
export const FLASHES = {
  danger: { name: 'Danger sense', cls: 'info', kind: 'layout', t: [0.05, 0.15, 0.15], pri: 2, cool: 0.5, layout: LAY.danger, moment: 'An ambush from hiding, a telegraphed heavy or beam, or an attack from off screen. A parry window keeps the crown\'s ring, because a flash would double it.', sound: 'A low dry tick with a short upward sweep. No chirp, no stinger.', event: 'ambush, attack telegraph (Encounter)' },
  found: { name: 'Found', cls: 'info', kind: 'glyph', glyph: 'bang', t: [0.06, 0.3, 0.24], pri: 3, cool: 1.5, moment: 'A hidden rival is found, or a lost lock-on is regained.', sound: 'One bright rising note, in the fighter\'s own pitch.', event: 'found, lock regained' },
  searching: { name: 'Searching', cls: 'info', kind: 'glyph', glyph: 'question', t: [0.1, 0.5, 0.3], pri: 4, cool: 3.0, moment: 'Lock-on lost, hunting a hidden rival. It re-pops at most every 3 s while the search lasts.', sound: 'A wavering low two-note phrase.', event: 'lock lost, hunting (Encounter)' },
  brink: { name: 'Brink', cls: 'emotion', kind: 'layout', t: [0.08, 0.35, 0.55], pri: 5, cool: 0, layout: LAY.brink, moment: 'The fighter enters the brink. Once per entry.', sound: 'A slow heartbeat thump.', event: 'brink_enter' },
  fear: { name: 'Fear', cls: 'emotion', kind: 'layout', t: [0.08, 0.35, 0.37], pri: 6, cool: 2.0, layout: LAY.fear, moment: 'An opponent starts a finisher, or the fighter watches a rival transform.', sound: 'A shiver: a quick tremolo on a held breath.', event: 'finisher_start against the fighter, cinematic_start of the rival' },
  rage: { name: 'Rage', cls: 'emotion', kind: 'layout', t: [0.12, 0.45, 0.35], pri: 7, cool: 1.5, layout: LAY.rage, moment: 'Drop the Act, a wrath spike, a boil-over, a humiliating parry.', sound: 'A growl that swells and cuts off.', event: 'drop_act, facade_crack, boil_over, shame_stack' },
  hurt: { name: 'Hurt', cls: 'emotion', kind: 'layout', t: [0.04, 0.16, 0.3], pri: 8, cool: 0.4, layout: LAY.hurt, moment: 'A heavy hit or a break launch, when the crown is not up.', sound: 'The fighter\'s pain grunt.', event: 'damage kind heavy, region_broken' },
  resolve: { name: 'Resolve', cls: 'emotion', kind: 'layout', t: [0.1, 0.35, 0.35], pri: 9, cool: 2.0, layout: LAY.resolve, moment: 'A Rally or Second Wind: the fighter gathers itself.', sound: 'A breath in, then a low held note.', event: 'rally' },
  triumph: { name: 'Triumph', cls: 'emotion', kind: 'layout', t: [0.14, 0.5, 0.36], pri: 10, cool: 3.0, layout: LAY.triumph, moment: 'A finisher lands, or a KO for the winner.', sound: 'A bright chime with the fighter\'s laugh.', event: 'ko (winner), finisher landed' },
  pride: { name: 'Pride', cls: 'emotion', kind: 'layout', t: [0.2, 0.5, 0.2], pri: 11, cool: 4.0, layout: LAY.pride, moment: 'After a decisive exchange won, before the next one. The Anti-hero\'s front.', sound: 'A slow exhale and a held soft chord.', event: 'decisive exchange won' },
  taunt: { name: 'Taunt', cls: 'emotion', kind: 'layout', t: [0.1, 0.35, 0.3], pri: 12, cool: 2.0, layout: LAY.taunt, moment: 'A taunt line or gesture.', sound: 'The fighter\'s sneer or dry laugh.', event: 'taunt bark' },
  surge: { name: 'Surge', cls: 'emotion', kind: 'layout', t: [0.25, 3.0, 1.2], pri: 1, cool: 0, layout: LAY.surge, moment: 'A transformation: held for the respected cinematic (up to 3 s), then it fades in 1.2 s. The one flash that lasts.', sound: 'A rising swell that resolves on the new form\'s chord.', event: 'cinematic_start and cinematic_end', rare: true },
};
export const FLASH_ORDER = ['danger', 'found', 'searching', 'brink', 'fear', 'rage', 'hurt', 'resolve', 'triumph', 'pride', 'taunt', 'surge'];
const totalT = f => f.t[0] + f.t[1] + f.t[2];
// The envelope: an eased attack, a hold, and an eased fade. 0 at rest, 1 at the peak.
const env = (f, t) => { const [a, h, d] = f.t; if (t <= 0) return 0; if (t < a) return 1 - (1 - t / a) ** 2; if (t < a + h) return 1; if (t < a + h + d) return 1 - ((t - a - h) / d) ** 2; return 0; };

// triangle with an optional round tip (the Legal fallback for tall pointed shapes)
function tri(base, ux, uy, s, w, round) {
  const nx = -uy, ny = ux;
  if (!round) return [[base[0] + nx * w, base[1] + ny * w], [base[0] + ux * s, base[1] + uy * s], [base[0] - nx * w, base[1] - ny * w]];
  const r = w * 0.95, c = [base[0] + ux * (s - r), base[1] + uy * (s - r)], pts = [[base[0] + nx * w, base[1] + ny * w], [c[0] + nx * r, c[1] + ny * r]];
  for (const ph of [60, 30, 0, -30, -60]) { const p = ph * Math.PI / 180; pts.push([c[0] + (ux * Math.cos(p) + nx * Math.sin(p)) * r, c[1] + (uy * Math.cos(p) + ny * Math.sin(p)) * r]); }
  pts.push([c[0] - nx * r, c[1] - ny * r], [base[0] - nx * w, base[1] - ny * w]);
  return pts;
}
function layoutPolys(fk, f, hc, u, k, round, ground) {
  const out = [], info = f.cls === 'info';
  for (const it of f.layout) {
    const a = it.a * Math.PI / 180, ux = Math.cos(a), uy = Math.sin(a), dir = it.inward ? -1 : 1;
    const base = it.ground ? [hc[0] + ux * it.d * u, ground] : [hc[0] + ux * it.d * u, hc[1] + 2 + uy * it.d * u];
    const size = (0.55 + 0.45 * k);
    for (const [kk, layer] of [[1, 'rim'], [0.58, 'core']]) {
      const s = it.s * u * kk * size, w = (fk === 'A' ? 3.8 : fk === 'E' ? 8.5 : 4) * u * (kk === 1 ? 1 : 0.6);
      let pts;
      if (fk === 'P') pts = circ([base[0] + ux * dir * s * 0.5, base[1] + uy * dir * s * 0.5], Math.max(2.5, s * 0.3), 14);
      else if (fk === 'C') { const q = Math.max(3, s * 0.3); pts = [[base[0] - q, base[1] - q], [base[0] + q, base[1] - q], [base[0] + q, base[1] + q], [base[0] - q, base[1] + q]].map(([x, y]) => [Math.round(x / 3) * 3 + ux * dir * s * 0.5, Math.round(y / 3) * 3 + uy * dir * s * 0.5]); }
      else pts = tri(base, ux * dir, uy * dir, s, w, round);
      out.push({ pts, layer, op: it.op * k, info });
    }
  }
  return out;
}
// The "!" and the "?" in each fighter's own shapes: capsule and dot (circles), blade and diamond (blades), wedge and triangle (wedges), squares (steps).
function glyphPolys(fk, kind, cx, cy, u, k, round) {
  const out = [], P = (pts, layer) => out.push({ pts, layer, op: 0.97 * Math.min(1, k * 1.4), info: true });
  const sc = (0.7 + 0.3 * k) * u * 1.7;
  const dotAt = (x, y, r) => (fk === 'P' ? circ([x, y], r * 1.05, 10) : fk === 'C' ? [[x - r, y - r], [x + r, y - r], [x + r, y + r], [x - r, y + r]] : fk === 'A' ? [[x, y - r * 1.2], [x + r * 0.9, y], [x, y + r * 1.2], [x - r * 0.9, y]] : [[x - r * 1.2, y - r * 0.8], [x + r * 1.2, y - r * 0.8], [x, y + r * 1.2]]);
  if (kind === 'bang') {
    for (const [pad, layer] of [[1.5, 'rim'], [0, 'core']]) {
      const g = pad * sc * 0.6;
      let stem;
      if (fk === 'P') stem = band([[cx, cy + 5.4 * sc], [cx, cy + 12.6 * sc]], 3.4 * sc + g * 2).concat([]);
      else if (fk === 'A') stem = [[cx - 2.6 * sc - g, cy + 14 * sc + g], [cx + 2.6 * sc + g, cy + 14 * sc + g], [cx, cy + 4.6 * sc - g]];
      else if (fk === 'E') stem = [[cx - 3.8 * sc - g, cy + 14 * sc + g], [cx + 3.8 * sc + g, cy + 14 * sc + g], [cx, cy + 4.6 * sc - g]];
      else stem = [[cx - 2 * sc - g, cy + 14 * sc + g], [cx + 2 * sc + g, cy + 14 * sc + g], [cx + 2 * sc + g, cy + 5.4 * sc - g], [cx - 2 * sc - g, cy + 5.4 * sc - g]];
      P(stem, layer === 'rim' ? 'rim' : 'core');
      if (fk === 'P') P(circ([cx, cy + 5.4 * sc], 1.7 * sc + g, 10), layer === 'rim' ? 'rim' : 'core'), P(circ([cx, cy + 12.6 * sc], 1.7 * sc + g, 10), layer === 'rim' ? 'rim' : 'core');
      P(dotAt(cx, cy + 1.4 * sc, (fk === 'C' ? 1.6 : 1.9) * sc + g), layer === 'rim' ? 'rim' : 'core');
    }
  } else {
    const path = fk === 'E' ? [[-3.6, 10.6], [-2.4, 14.8], [2.6, 14.8], [3.6, 10.8], [0, 7.4], [0, 5]] : [[-3.6, 10.6], [-3.4, 13.6], [-0.8, 15.4], [2.4, 14.2], [3.2, 11.6], [1.6, 9.2], [0, 7.2], [0, 5]];
    for (const [pad, layer] of [[1.5, 'rim'], [0, 'core']]) {
      const g = pad * sc * 0.6, pts = path.map(([x, y]) => [cx + x * sc, cy + y * sc]);
      if (fk === 'P') for (const p of pts) P(circ(p, 1.8 * sc + g, 10), layer);
      else if (fk === 'C') for (const p of pts) { const q = 1.7 * sc + g, gx = Math.round(p[0] / 3) * 3, gy = Math.round(p[1] / 3) * 3; P([[gx - q, gy - q], [gx + q, gy - q], [gx + q, gy + q], [gx - q, gy + q]], layer); }
      else P(band(pts, t => (fk === 'A' ? (1.4 + 2.6 * Math.sin(Math.PI * t)) : 3.4) * sc + g * 2), layer);
      P(dotAt(cx, cy + 1.4 * sc, (fk === 'C' ? 1.6 : 1.9) * sc + g), layer);
    }
  }
  return out;
}
function flashPolys(fk, id, hc, u, { k = 1, round = false, ground = 0 } = {}) {
  const f = FLASHES[id]; if (!f || k <= 0) return [];
  if (f.kind === 'glyph') return glyphPolys(fk, f.glyph, hc[0] + 2 * u, hc[1] + 7 * u, u, k, round);
  return layoutPolys(fk, f, hc, u, k, round, ground);
}

// ---------------------------------------------------------------------------------------------------------- styling a fighter
const civC = {
  ...CIVILIAN,
  cfg: pal => ({ ...CIVILIAN.cfg(pal), torso: '#8a93a3', sleeve: '#8a93a3', torsoShade: '#00000030' }),
  blankHead: pal => ({ poly: [[-4.6, 1], [-5.4, 8], [-4.4, 14], [0, 16.4], [4.6, 14], [5.6, 8], [4, 1.5]], fill: pal.skin.mid, shadow: pal.skin.shadow, shade: [[-4.6, 1], [-5.4, 8], [-4.4, 14], [0, 16.4], [1, 16], [-2.4, 12], [-2.4, 6], [-1, 0.6]] }),
};
// which sigil pose goes with each state
const SIGIL_STATE = { pride: 'pride', danger: 'pride', found: 'triumph', searching: 'taunt', fear: 'hurt', resolve: 'pride', surge: 'transform', clash: 'rage', neutral: 'neutral', taunt: 'taunt', hurt: 'hurt', brink: 'brink', rage: 'rage', triumph: 'triumph' };
function styled(fk) {
  const base = FIGHTERS[fk], mask = MASK[fk];
  const c = { ...base };
  c.blankHead = (p, st) => {
    const bh = base.blankHead(p);
    let marks = bh.marks ?? [];
    if (fk === 'C') marks = marks.slice(1);
    let extra = sigilMarks(fk, p, SIGIL_STATE[st.state ?? 'neutral'] ?? 'neutral', mask);
    if ((st.yaw ?? 0) > 0) { const m = yawMap(fk, st.yaw); marks = marks.map(q => ({ ...q, poly: q.poly.map(m) })); extra = extra.map(q => ({ ...q, poly: q.poly.map(m) })); }
    return { ...bh, fill: mask.fill, shadow: mask.shadow, neck: mask.shadow, marks: [...marks, ...extra] };
  };
  const prevBack = base.back;
  c.back = (ctx, sk, st, cfg) => {
    let o = '';
    const id = st.state === 'clash' ? 'rage' : st.state;
    if (!ctx.flat && !st.noFlash && FLASHES[id]) {
      const hc = sk.Hd(3, 9), u = sk.b.hs * 0.95, pal = ctx.pal;
      for (const a of flashPolys(fk, id, [hc.x, hc.y], u, { k: st.k ?? 1, round: st.round, ground: 0 })) {
        const info = a.info;
        const col = info ? (a.layer === 'rim' ? pal.accent.shadow : pal.accent.light) : (a.layer === 'rim' ? pal.accent.mid : pal.accent.light);
        const op = info ? a.op : a.op * (a.layer === 'rim' ? 0.85 : 1);
        const pts = a.pts.map(p => (Array.isArray(p) ? `${p[0].toFixed(2)},${p[1].toFixed(2)}` : `${p.x.toFixed(2)},${p.y.toFixed(2)}`)).join(' ');
        o += `<polygon points="${pts}" fill="${col}" opacity="${op.toFixed(2)}"/>`;
      }
    }
    return o + prevBack(ctx, sk, st, cfg);
  };
  const prevAfter = base.after;
  c.after = (ctx, sk, st, cfg) => {
    let o = prevAfter ? prevAfter(ctx, sk, st, cfg) : ''; if (ctx.flat) return o;
    const { pal: p } = ctx, n = st.forms ?? 6;
    for (let i = 0; i < Math.min(n, 6); i++) {
      const t = 0.18 + i * 0.13, a = sk.nearArm;
      const p0 = V(a.E.x + (a.W.x - a.E.x) * t, a.E.y + (a.W.y - a.E.y) * t);
      o += `<circle cx="${p0.x.toFixed(2)}" cy="${p0.y.toFixed(2)}" r="0.9" fill="${p.accent.mid}"/>`;
    }
    return o;
  };
  return c;
}

const DEFS = `<defs>
<pattern id="mail" width="3.2" height="3.2" patternUnits="userSpaceOnUse"><circle cx="1.6" cy="1.6" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/><circle cx="0" cy="0" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/><circle cx="3.2" cy="3.2" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/></pattern>
</defs>`;

// Poses for the states. Neutral is the base pose. Pride for the Anti-hero is the upright front; the others lean back and lift the chin.
function poseFor(fk, s) {
  const b = FIGHTERS[fk].poses.base;
  if (s === 'neutral') return b;
  if (s === 'pride') return fk === 'A' ? { ...POSES.proud } : { ...b, lean: b.lean - 8, head: b.head - 10 };
  if (s === 'taunt') return { ...b, lean: b.lean - 8, head: b.head - 16, nearArm: [58, 138], farArm: [-8, -64], handNear: 'open' };
  if (s === 'hurt') return { ...POSES.humbled, nearLeg: [26, -6], farLeg: [-12, -22] };
  if (s === 'brink') return { lean: 34, head: 26, nearArm: [20, -100], farArm: [14, 10], nearLeg: [40, -30], farLeg: [-10, -50], handNear: 'open', handFar: 'fist' };
  if (s === 'rage') return { ...POSES.dropped };
  if (s === 'clash') return { lean: 22, head: 6, nearArm: [84, 90], farArm: [-40, -90], nearLeg: [42, 14], farLeg: [-36, -12], handNear: 'fist', handFar: 'fist' };
  if (s === 'surge') return { lean: -6, head: -20, nearArm: [98, 122], farArm: [-98, -122], nearLeg: [20, 6], farLeg: [-20, -6], handNear: 'open', handFar: 'open' };
  if (s === 'danger') return { ...b, lean: b.lean + 4, head: b.head - 6, nearArm: [50, 118], farArm: [-6, -70], handNear: 'open', handFar: 'fist' };
  if (s === 'found') return { ...b, lean: b.lean - 4, head: b.head - 12, nearArm: [84, 88], handNear: 'open' };
  if (s === 'searching') return { ...b, lean: b.lean - 2, head: b.head + 6, nearArm: [40, 142], farArm: [-8, -30], handNear: 'open' };
  if (s === 'fear') return { ...b, lean: b.lean - 14, head: b.head - 4, nearArm: [56, 146], farArm: [-30, -110], handNear: 'open', handFar: 'open' };
  if (s === 'resolve') return { ...b, lean: b.lean + 12, head: b.head - 8, nearArm: [34, 72], farArm: [-30, -60], handNear: 'fist' };
  return { lean: -8, head: -22, nearArm: [152, 172], farArm: [-150, -170], nearLeg: [18, 4], farLeg: [-16, -4], handNear: 'fist', handFar: 'fist' }; // triumph
}
const stateOf = (state, yaw, k, round, extra = {}) => ({ yaw, state, k, round, expression: 'neutral', open: state === 'rage' || state === 'clash' ? 1 : state === 'hurt' || state === 'brink' ? 0.4 : 0, forms: 6, hairLoose: ['rage', 'hurt', 'brink', 'clash', 'fear'].includes(state), ...extra });

// state: a flash id, or neutral (at rest: no flash). k: 0 to 1 envelope of the flash (1 is the peak).
function fig(fk, px, x, ground, { flat = false, state = 'neutral', civ = false, flip = false, yaw = YAW, noFlash = false, wear = 0, k = 1, round = false } = {}) {
  const s = px / 100, pal = civ ? NEUTRAL : PAL[fk];
  const concept = civ ? civC : styled(fk);
  const ctx = makeCtx({ flat, pal, swMul: px < 9 ? 0 : px < 28 ? 0.6 : px < 80 ? 1 : 1.3, faceless: true });
  const p = civ ? CIV_POSES[0] : poseFor(fk, state);
  const st = civ ? { expression: 'neutral', yaw } : { ...stateOf(state, yaw, k, round), sway: FIGHTERS[fk].sway ?? 6, wear, noFlash };
  const { svg } = figure(ctx, concept, p, st, { yaw });
  const fl = flip ? ` transform="translate(${F(x)} 0) scale(-1 1) translate(${F(-x)} 0)"` : '';
  return `<g${fl}><g transform="translate(${F(x)} ${F(ground)}) scale(${F(s)} ${F(-s)})">${svg}</g></g>`;
}
function closeup(fk, state, x, y, size, px = 118) {
  const s = px / 100, pal = PAL[fk], concept = styled(fk);
  const ctx = makeCtx({ flat: false, pal, swMul: 1, faceless: true });
  const p = poseFor(fk, state);
  const st = { ...stateOf(state, YAW, 1, false), sway: FIGHTERS[fk].sway ?? 6, wear: 0 };
  const { svg, sk } = figure(ctx, concept, p, st, { yaw: YAW });
  const h = sk.Hd(3.2, 9.4);
  return `<svg x="${F(x)}" y="${F(y)}" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" overflow="hidden">${rect(0, 0, size, size, '#f3f0f8')}<g transform="translate(${F(size / 2 - h.x * s)} ${F(size / 2 + h.y * s)}) scale(${F(s)} ${F(-s)})">${svg}</g></svg>` + rect(x, y, size, size, 'none', 'stroke="#1b1428" stroke-opacity="0.35"');
}

// HUD crown, drawn as UI's spec describes it (thin arcs and a faint ring around the whole body), for the comparison diagram only.
function hudCrown(cx, cy, R, brink = false) {
  const arcs = [[-20, 60], [70, 150], [160, 240], [250, 330]].map(([a0, a1]) => {
    const pts = []; for (let a = a0; a <= a1; a += 6) pts.push(`${(cx + Math.cos(a * Math.PI / 180) * R).toFixed(1)},${(cy - Math.sin(a * Math.PI / 180) * R).toFixed(1)}`);
    return `<polyline points="${pts.join(' ')}" fill="none" stroke="#5b5866" stroke-width="2" stroke-linecap="round"/>`;
  }).join('');
  const inner = `<circle cx="${cx}" cy="${cy}" r="${(R * 0.5).toFixed(1)}" fill="none" stroke="#5b5866" stroke-width="1.6" opacity="0.7"/>`;
  const ring = brink ? `<circle cx="${cx}" cy="${cy}" r="${(R * 1.1).toFixed(1)}" fill="none" stroke="#5b5866" stroke-width="1.2" stroke-dasharray="5 4" opacity="0.5"/>` : '';
  return arcs + inner + ring;
}

// The greybox scenes: the repo's own renders as backdrops, cropped clear of the HUD and the placeholder fighters.
const IMG = '../../../docs/rendering/img/';
const SCENES = {
  village: { href: IMG + 'civilians-after.png', sx: 250, sy: 130, sw: 760, sh: 560 },
  craters: { href: IMG + 'craters-after.png', sx: 380, sy: 130, sw: 520, sh: 560 },
  high: { href: IMG + 'world-high-after.png', sx: 0, sy: 300, sw: 1280, sh: 390 },
};
let clipN = 0;
function scene(key, x, y, w, h, content) {
  const sc = SCENES[key], k = Math.max(w / sc.sw, h / sc.sh), id = `sc${clipN++}`;
  const iw = 1280 * k, ih = 720 * k, ix = -sc.sx * k - (sc.sw * k - w) / 2, iy = -sc.sy * k - (sc.sh * k - h) / 2;
  return `<clipPath id="${id}"><rect x="0" y="0" width="${w}" height="${h}"/></clipPath><g transform="translate(${x} ${y})"><g clip-path="url(#${id})"><image href="${sc.href}" x="${F(ix)}" y="${F(iy)}" width="${F(iw)}" height="${F(ih)}"/>${content}</g></g>` + rect(x, y, w, h, 'none', 'stroke="#1b1428" stroke-opacity="0.4"');
}


// ---------------------------------------------------------------------------------------------------------- sheet 1: the style
function styleSheet() {
  const W = 1800, H = 1775;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'Marked plus Flashes: the style', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'The sigil carries identity and small expression. A brief head flash conveys what the mask cannot. At rest there is nothing. Three-quarter, calm colour, mask tone per fighter.', { size: 15, fill: '#cfc6e6' });
  b += text(W - 30, 80, 'Working labels, placeholder looks. Status: proposal, pending Legal review.', { size: 12, fill: '#cfc6e6', anchor: 'end' });
  b += rect(24, 124, W - 48, 470, '#e8e5ee', 'stroke="#1b1428" stroke-opacity="0.2"');
  const xs = { P: 250, A: 700, E: 1180, C: 1600 };
  for (const fk of ORDER) {
    b += fig(fk, 300, xs[fk], 540, { state: 'neutral' });
    b += text(xs[fk], 566, `${NAMES[fk]}: ${MASK[fk].tone} mask`, { size: 13, weight: 600, anchor: 'middle', op: 0.85 });
  }
  b += text(40, 150, 'The four fighters at rest, showcase size, three-quarter. No flash: the fight area is clean', { size: 12, weight: 700, op: 0.85 });
  b += text(24, 630, 'Mask tone per fighter (approved by Orb)', { size: 18, weight: 700 });
  ORDER.forEach((fk, i) => {
    const x0 = 24 + i * 444;
    b += rect(x0, 640, 432, 116, MASK[fk].fill, 'stroke="#1b1428" stroke-opacity="0.25"');
    const tc = MASK[fk].tone === 'dark' ? '#f4f0fa' : '#1b1428';
    b += text(x0 + 14, 664, `${NAMES[fk]}: ${MASK[fk].tone}`, { size: 16, weight: 700, fill: tc });
    b += paras(x0 + 14, 686, MASK[fk].why, 62, 12.5, 16, { fill: tc });
  });
  b += text(24, 790, 'Gameplay size: 40 px and 12 px with a civilian, a "found" flash and a rage flash at their peak', { size: 13, weight: 700 });
  ORDER.forEach((fk, i) => {
    const x0 = 24 + i * 444;
    [[40, 'found', 0], [40, 'rage', 1], [12, 'found', 2], [12, 'rage', 3]].forEach(([px, st, j]) => {
      const cx = x0 + j * 108, cy = 802;
      b += rect(cx, cy, 100, 100, '#cfe6f0') + rect(cx, cy + 50, 100, 50, '#2f86ad');
      b += fig(fk, px, cx + 66, cy + 88, { state: st }) + fig(fk, px, cx + 20, cy + 88, { civ: true });
    });
    b += text(x0, 922, NAMES[fk], { size: 12, weight: 600, op: 0.85 });
  });
  b += text(24, 960, 'Expression: neutral, taunt, hurt, rage, triumph (the sigil, the flash at its peak, and a head close-up)', { size: 13, weight: 700 });
  const S5 = ['neutral', 'taunt', 'hurt', 'rage', 'triumph'];
  ORDER.forEach((fk, r) => {
    const y0 = 972 + r * 186;
    b += text(24, y0 + 14, NAMES[fk], { size: 12, weight: 700 });
    S5.forEach((e, j) => {
      const x0 = 24 + j * 356;
      b += rect(x0, y0 + 20, 348, 158, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"');
      b += fig(fk, 120, x0 + (fk === 'E' ? 140 : 100), y0 + 170, { state: e });
      b += closeup(fk, e, x0 + 216, y0 + 26, 126, 150);
      b += text(x0 + 8, y0 + 38, e, { size: 12, op: 0.75 });
    });
  });
  b += text(30, H - 22, 'Kept: the value rule, the two-tone edge, the far beacon, calm harmonious colour, three-quarter staging, and no borrowed look (designed masks, never grey and round, no cross-mark or dot eyes).', { size: 12, op: 0.8 });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

// ---------------------------------------------------------------------------------------------------------- sheet 2: the flash vocabulary
const fmtT = f => `${f.t[0].toFixed(2)} + ${f.t[1].toFixed(2)} + ${f.t[2].toFixed(2)} = ${totalT(f).toFixed(2)} s`;
function vocabSheet() {
  const W = 1800, cw = 143;
  let b = rect(0, 0, W, 2000, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'The head flashes: twelve, each tied to a game moment', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'Brief pops at the head, in each fighter\'s own shapes. Each cell is the flash at its peak. At rest there is nothing.', { size: 15, fill: '#cfc6e6' });
  b += text(24, 136, 'Every flash in each shape family: circles (Protagonist), blades (Anti-hero), wedges (Empress), steps (Cyborg)', { size: 16, weight: 700 });
  FLASH_ORDER.forEach((id, j) => {
    const f = FLASHES[id], x0 = 24 + j * cw;
    b += text(x0 + cw / 2 - 4, 162, f.name, { size: 13, weight: 700, anchor: 'middle' });
    b += text(x0 + cw / 2 - 4, 177, `${f.cls === 'info' ? 'info: solid' : 'emotion: soft'}`, { size: 10.5, anchor: 'middle', op: 0.75 });
  });
  ORDER.forEach((fk, r) => {
    const y0 = 184 + r * 214;
    FLASH_ORDER.forEach((id, j) => {
      const x0 = 24 + j * cw;
      b += rect(x0, y0, cw - 4, 208, FLASHES[id].cls === 'info' ? '#e3eef5' : '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"');
      b += fig(fk, 78, x0 + (fk === 'E' ? 104 : 74), y0 + 200, { state: id });
    });
    b += text(30, y0 + 16, NAMES[fk], { size: 11, weight: 700, op: 0.7 });
  });
  // table
  let y = 184 + 4 * 214 + 30;
  b += text(24, y, 'What each flash is for', { size: 18, weight: 700 });
  y += 24;
  const cols = [['Flash', 24], ['Class', 150], ['Moment and sim event', 232], ['Attack + hold + fade', 800], ['Priority', 960], ['Sound pairing (with Audio)', 1032]];
  cols.forEach(([h, x]) => { b += text(x, y, h, { size: 12, weight: 700 }); });
  y += 8;
  FLASH_ORDER.forEach(id => {
    const f = FLASHES[id], m = wrap(`${f.moment} (Event: ${f.event}.)`, 92), s = wrap(f.sound, 80), n = Math.max(m.length, s.length, 1);
    b += `<line x1="24" y1="${y}" x2="1776" y2="${y}" stroke="#1b1428" stroke-opacity="0.15"/>`;
    b += text(24, y + 16, f.name, { size: 12.5, weight: 700 }) + text(150, y + 16, f.cls, { size: 12 }) + text(800, y + 16, fmtT(f), { size: 12 }) + text(960, y + 16, String(f.pri), { size: 12 });
    m.forEach((l, i) => { b += text(232, y + 16 + i * 15, l, { size: 12 }); });
    s.forEach((l, i) => { b += text(1032, y + 16 + i * 15, l, { size: 12 }); });
    y += 10 + n * 15 + 8;
  });
  y += 20;
  b += paras(24, y, 'Shape rules: circles use round-ended bars, dots and arcs; blades use tapered blades and diamonds; wedges use wedge triangles; steps use squares snapped to a grid. Info flashes (danger, found, searching) are solid, at full opacity, with a dark keyline in the lane colour. Emotion flashes are translucent, with a rim and a lighter core. Priority 1 wins.', 220, 12, 16);
  const H = y + 70;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b.replace('<rect x="0.00" y="0.00" width="1800.00" height="2000.00"', `<rect x="0.00" y="0.00" width="1800.00" height="${H}.00"`)}</svg>`;
}

// ---------------------------------------------------------------------------------------------------------- sheet 4: timing, priority and the crown
function rulesSheet() {
  const W = 1800, H = 1900;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'The flashes: timing, priority, and the HUD crown', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'How long they last, which wins when several fire, how they stay clear of the crown, and the Legal fallback.', { size: 15, fill: '#cfc6e6' });
  // timelines
  b += text(24, 136, 'A flash in time (frames at 0 s to the end; each is the envelope at that moment)', { size: 18, weight: 700 });
  const tl = [['P', 'found', 'Protagonist: found'], ['A', 'danger', 'Anti-hero: danger sense'], ['E', 'rage', 'Empress: rage'], ['C', 'fear', 'Cyborg: fear']];
  tl.forEach(([fk, id, cap], r) => {
    const f = FLASHES[id], y0 = 148 + r * 176, T = totalT(f), fr = [0.03, 0.12, 0.3, 0.55, 0.8, 0.97];
    b += text(24, y0 + 14, `${cap}  (${fmtT(f)})`, { size: 12.5, weight: 700 });
    fr.forEach((q, j) => {
      const t = q * T, k = env(f, t), x0 = 24 + j * 292;
      b += rect(x0, y0 + 20, 284, 150, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"');
      b += fig(fk, 96, x0 + (fk === 'E' ? 170 : 130), y0 + 164, { state: id, k: Math.max(0.001, k) });
      b += text(x0 + 8, y0 + 36, `${t.toFixed(2)} s  (${Math.round(k * 100)}%)`, { size: 11, op: 0.8 });
    });
  });
  // priority and arbitration
  const ya = 148 + 4 * 176 + 20;
  b += text(24, ya, 'Priority and arbitration (one channel per fighter)', { size: 18, weight: 700 });
  const pr = FLASH_ORDER.slice().sort((a, c) => FLASHES[a].pri - FLASHES[c].pri).map(id => `${FLASHES[id].pri} ${FLASHES[id].name}`).join('   >   ');
  b += paras(24, ya + 24, `Priority, highest first: ${pr}.`, 230, 12.5, 17);
  const arb = [
    'One flash at a time per fighter, and never a flash and a crown together. The crown owns wear (a stage change, brink, Rally, facade crack, boil-over). A flash owns emotion and sense. If a wear event arrives while a flash is up, the flash fades out in 0.1 s and the crown takes the fighter. If a flash is due while the crown is up, it waits up to 0.25 s and is then dropped.',
    'A higher priority preempts a lower one (the lower fades in 0.1 s). The same priority extends the hold and never replays the attack. A lower priority waits up to 0.25 s and is then dropped. Each flash has its own cooldown per fighter (in the table), so the same beat never chatters.',
    'A flash is never up while a fighter is hidden. During a transformation cinematic the surge owns the fighter and the crown stays down. No flash covers the mask, the sigil or the chest: they are drawn behind the head and above it.',
    'Info flashes (danger, found, searching) are never dropped for an emotion flash. They can only be preempted by the surge. Suggested UI change: the crown pops only for a stage change, brink, Rally, facade crack, boil-over, and not for every hit, so the hurt flash and the crown do not compete for the same moment.',
  ];
  arb.forEach((t, i) => { b += paras(24 + (i % 2) * 888, ya + 62 + Math.floor(i / 2) * 100, t, 104, 12, 16); });
  // flash vs crown
  const yc = ya + 62 + 210;
  b += text(24, yc, 'A flash against the HUD crown, on the same figure', { size: 18, weight: 700 });
  const demo = [['Flash only (in the scene): rage', 'rage', false, false], ['HUD crown only (UI): a stage change', 'neutral', true, false], ['Never both: the crown wins a wear event', 'neutral', true, false], ['HUD brink ring with a brink flash', 'brink', false, true]];
  demo.forEach(([cap, st, crown, brink], i) => {
    const x0 = 24 + i * 444;
    b += rect(x0, yc + 14, 432, 250, '#cfe0ea', 'stroke="#1b1428" stroke-opacity="0.2"');
    b += fig('P', 150, x0 + 210, yc + 254, { state: st });
    if (crown) b += hudCrown(x0 + 216, yc + 254 - 88, 78);
    if (brink) b += `<circle cx="${x0 + 216}" cy="${yc + 254 - 60}" r="${(78 * 1.1).toFixed(1)}" fill="none" stroke="#5b5866" stroke-width="1.2" stroke-dasharray="5 4" opacity="0.5"/>`;
    b += text(x0 + 10, yc + 32, cap, { size: 12, weight: 600 });
  });
  b += text(24, yc + 290, 'The crown is drawn as UI\'s spec describes it (docs/ui/hud-spec.md): thin arcs and an inner ring, a faint dashed brink ring. A flash never draws a ring or an outline arc, and the crown never draws a filled shape.', { size: 12, op: 0.85 });
  // Legal fallback
  const yl = yc + 320;
  b += text(24, yl, 'Legal fallback, ready: round-tipped shapes (pointed, then round-tipped)', { size: 18, weight: 700 });
  [['A', 'pride'], ['A', 'rage'], ['E', 'pride'], ['E', 'rage']].forEach(([fk, id], i) => {
    const x0 = 24 + i * 444;
    b += rect(x0, yl + 14, 432, 200, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"');
    b += fig(fk, 96, x0 + 90, yl + 208, { state: id }) + fig(fk, 96, x0 + 300, yl + 208, { state: id, round: true });
    b += text(x0 + 8, yl + 32, `${NAMES[fk]} ${id}: pointed, round-tipped`, { size: 11.5, op: 0.8 });
  });
  b += paras(24, yl + 240, 'If Legal finds a tall pointed flash too close to an upswept spiky aura, the blades and wedges switch to round tips, and the shapes stay in their families. Circles and steps are unchanged.', 230, 12.5, 17);
  b += text(24, yl + 285, 'Legal notes on the set', { size: 16, weight: 700 });
  b += paras(24, yl + 306, 'Exclamation and question marks are general comics staples and are drawn here in each fighter\'s own shapes with a keyline, not as a font glyph. Danger sense is short straight bursts in the fighter\'s family, not a wavy squiggle. The sounds are described in words and must be original: no stealth-game alert sting, no spider-sense chirp. No red, red-orange or gold flash for the Protagonist or the Anti-hero. The Protagonist\'s heat stays steam and veins on the body.', 230, 12.5, 17);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

// ---------------------------------------------------------------------------------------------------------- sheet 3: staging
function stagingSheet() {
  const W = 1800, H = 1730;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'Marked plus Flashes: staged in the greybox scene', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'Three-quarter cheat-out, front to camera, mirrored on side-swap, downstage commanding. Each flash is drawn at its peak: 1 s later the same frame is clean.', { size: 15, fill: '#cfc6e6' });
  const f = (fk, px, x, y, o = {}) => fig(fk, px, x, y, o);
  const rows = [
    { title: '1. Pre-fight face-off', note: 'The Protagonist and the Cyborg are downstage (bigger, nearer, commanding), the Anti-hero and the Empress upstage, all turned three-quarter to the middle. Four flashes at their peak: the Protagonist spots the rival (found), the Anti-hero stands tall (pride), the Empress taunts, the Cyborg is at rest. A second later everything is clean again.', scene: 'village', x: 24, y: 124, w: 880, h: 560,
      draw: () => f('A', 78, 250, 372, { state: 'pride' }) + f('E', 82, 640, 350, { state: 'taunt', flip: true }) + f('P', 122, 150, 520, { state: 'found' }) + f('C', 124, 770, 530, { state: 'neutral', flip: true }) },
    { title: '2. Mid-exchange clash', note: 'The Protagonist and the Anti-hero meet in the centre, both in rage, the flares sweeping forward and overlapping at the contact. The Empress watches from upstage with a danger-sense flash (something is coming), and the Cyborg searches. Nobody shows their back.', scene: 'craters', x: 916, y: 124, w: 860, h: 560,
      draw: () => f('P', 128, 360, 510, { state: 'clash' }) + f('A', 122, 540, 512, { state: 'clash', flip: true }) + f('E', 74, 130, 380, { state: 'danger' }) + f('C', 74, 770, 384, { state: 'searching', flip: true }) },
    { title: '3. Transformation (a respected cinematic)', note: 'The Anti-hero surges alone, centred and downstage: the one flash that lasts, held for the cinematic and then faded. Tall shapes and ground shards rise from the head and shoulders and the sigil is fully lit. The Protagonist watches with fear, the others stand at rest.', scene: 'high', x: 24, y: 780, w: 880, h: 560,
      draw: () => f('A', 178, 450, 540, { state: 'surge' }) + f('P', 84, 130, 470, { state: 'fear' }) + f('E', 84, 760, 470, { state: 'neutral', flip: true }) + f('C', 84, 250, 420, { state: 'neutral' }) },
    { title: '4. Hurt and brink', note: 'The Protagonist has just entered the brink: folded, sigil dim and cracked, a few guttering fragments. UI\'s thin dashed brink ring is drawn as UI specifies, so the two are visibly different (in play the crown would own this moment and the flash would wait). The Anti-hero stands over him in pride, the Empress triumphs, the Cyborg is at rest.', scene: 'village', x: 916, y: 780, w: 860, h: 560,
      draw: () => f('P', 130, 340, 530, { state: 'brink' }) + `<g><circle cx="342" cy="466" r="62" fill="none" stroke="#5b5866" stroke-width="1.4" stroke-dasharray="6 5" opacity="0.7"/></g>` + f('A', 118, 560, 524, { state: 'pride', flip: true }) + f('E', 76, 720, 410, { state: 'triumph', flip: true }) + f('C', 76, 120, 400, { state: 'neutral' }) },
  ];
  rows.forEach(r => {
    b += scene(r.scene, r.x, r.y, r.w, r.h, r.draw());
    b += text(r.x + 12, r.y + 26, r.title, { size: 18, weight: 700, fill: '#f4f0fa' }).replace('<text', `<text stroke="#1b1428" stroke-width="3" paint-order="stroke"`);
    b += paras(r.x, r.y + r.h + 22, r.note, 132, 12.5, 16, { op: 0.92 });
  });
  const y = 1420;
  b += text(24, y, 'Blocking rules used on this sheet', { size: 18, weight: 700 });
  const notes = [
    ['Cheat out', 'Torso, hips and head turn about 32 degrees toward the camera. The near arm crosses the chest and the far arm sits beyond it, so the chest design and the mask face show.'],
    ['Mirror on side-swap', 'A fighter facing left is the mirror image of the same figure, so the front and the sigil face the camera and the back is never shown. The sigil is on the face plane, so it reads either way.'],
    ['Downstage', 'The fighter nearer the camera is larger and lower in frame, and reads as commanding. In the face-off the leads are downstage, and the sneering pair is upstage.'],
    ['Flashes and blocking', 'A flash sits at and above the head, behind it, so it never hides the mask, the sigil or the chest. Rage sweeps forward, away from the camera-facing side, so contact points stay clear.'],
    ['What is not staged here', 'Camera, the letterbox, the HUD and the crown pops (only the brink ring is drawn, to show the difference). Rendering owns the hybrid projection.'],
  ];
  notes.forEach(([h, t], i) => { const col = i % 3, row = Math.floor(i / 3), x = 24 + col * 592, yy = y + 30 + row * 110; b += text(x, yy, h, { size: 14, weight: 700 }) + paras(x, yy + 18, t, 92, 11.5, 15); });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

const ORIGIN = '<!-- Origin: procedural concept sheet written by art/concepts/marked-aura/gen.mjs (deterministic, no external images or fonts; the staging sheet embeds the repo\'s own renders in docs/rendering/img by reference), Art Director session (Claude, claude-sonnet-5-5), 2026-09-29; prompt record art/prompts/ART-0005-marked-aura.md -->' + String.fromCharCode(10);
writeFileSync(join(OUT, 'ma-1-style.svg'), ORIGIN + styleSheet());
writeFileSync(join(OUT, 'ma-2-flashes.svg'), ORIGIN + vocabSheet());
writeFileSync(join(OUT, 'ma-3-staging.svg'), ORIGIN + stagingSheet());
writeFileSync(join(OUT, 'ma-4-flash-rules.svg'), ORIGIN + rulesSheet());
// The flash data, for Rendering, UI and Audio: ids, class, timing, priority, cooldown, shape family and the layouts.
const json = { version: 1, note: 'Draft data from art/concepts/marked-aura/gen.mjs. Angles are degrees (0 forward, 90 up), d and s are in units of head size / 12. Names and looks are placeholders.', families: { P: 'circles', A: 'blades', E: 'wedges', C: 'steps' }, flashes: Object.fromEntries(FLASH_ORDER.map(id => { const f = FLASHES[id]; return [id, { name: f.name, class: f.cls, attack: f.t[0], hold: f.t[1], fade: f.t[2], priority: f.pri, cooldown: f.cool, kind: f.kind, glyph: f.glyph ?? null, layout: f.layout ?? null, moment: f.moment, event: f.event, sound: f.sound, rare: !!f.rare }]; })) };
writeFileSync(join(OUT, 'flashes.json'), JSON.stringify(json, null, 2) + String.fromCharCode(10));
console.log('wrote ma-1-style.svg, ma-2-flashes.svg, ma-3-staging.svg, ma-4-flash-rules.svg, flashes.json');
