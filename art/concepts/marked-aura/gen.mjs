// Origin: procedural generator for the Marked plus Aura sheets (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-09-29. Human direction: Orb, via the EP.
// Run from the repo root:  node art/concepts/marked-aura/gen.mjs   (writes ma-1-style.svg, ma-2-aura-rules.svg, ma-3-staging.svg)
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

// ---------------------------------------------------------------------------------------------------------- the aura (state and exaggeration)
// A filled, cel-shaded mantle anchored to the head and upper back. One layout per state, drawn in each fighter's shape family:
// circles (Protagonist), blades (Anti-hero), wedges (Empress), steps (Cyborg). Never a thin line, never a ring, never full-body.
const LAYOUT = {
  neutral: [{ a: 90, d: 12, s: 14, op: 0.12 }],
  pride: [{ a: 90, d: 10, s: 60, op: 0.4 }, { a: 78, d: 9, s: 44, op: 0.36 }, { a: 102, d: 9, s: 44, op: 0.36 }, { a: 66, d: 8, s: 28, op: 0.32 }, { a: 114, d: 8, s: 28, op: 0.32 }],
  taunt: [{ a: 125, d: 10, s: 30, op: 0.36 }, { a: 152, d: 9, s: 22, op: 0.32 }, { a: 100, d: 8, s: 16, op: 0.3 }],
  hurt: [{ a: 205, d: 15, s: 9, op: 0.3 }, { a: 250, d: 20, s: 7, op: 0.26 }, { a: 165, d: 22, s: 8, op: 0.26 }, { a: 300, d: 16, s: 6, op: 0.24 }],
  brink: [{ a: 230, d: 18, s: 6, op: 0.22 }, { a: 190, d: 24, s: 5, op: 0.18 }],
  rage: [{ a: 0, d: 10, s: 44, op: 0.5 }, { a: 24, d: 10, s: 56, op: 0.5 }, { a: 48, d: 10, s: 66, op: 0.5 }, { a: 74, d: 10, s: 56, op: 0.5 }, { a: 100, d: 10, s: 46, op: 0.46 }, { a: -24, d: 10, s: 36, op: 0.44 }, { a: 126, d: 10, s: 32, op: 0.42 }],
  triumph: [20, 40, 60, 80, 100, 120, 140, 160].map((a, i) => ({ a, d: 11, s: 42 + (i % 2) * 12, op: 0.44 })),
  transform: [...[60, 75, 90, 105, 120].map(a => ({ a, d: 10, s: 96, op: 0.52 })), ...[0, 30, 150, 180].map(a => ({ a, d: 12, s: 56, op: 0.46 })), ...[186, 196, 344, 354].map(a => ({ a, d: 50, s: 30, op: 0.4, ground: true }))],
};
function auraPolys(fk, state, hc, u, ground) {
  const L = LAYOUT[state] ?? LAYOUT.neutral, out = [];
  for (const it of L) {
    const a = it.a * Math.PI / 180, ux = Math.cos(a), uy = Math.sin(a);
    const base = it.ground ? [hc[0] + ux * it.d * u, ground] : [hc[0] + ux * it.d * u, hc[1] + 2 + uy * it.d * u];
    for (const [k, layer] of [[1, 'rim'], [0.58, 'core']]) {
      const s = it.s * u * k, w = (fk === 'A' ? 3.8 : fk === 'E' ? 8.5 : 4) * u * (k === 1 ? 1 : 0.6);
      let pts;
      if (fk === 'P') pts = circ([base[0] + ux * s * 0.5, base[1] + uy * s * 0.5], Math.max(2.5, s * 0.3), 14);
      else if (fk === 'C') { const q = Math.max(3, s * 0.3); pts = [[base[0] - q, base[1] - q + uy * s * 0.4], [base[0] + q, base[1] - q + uy * s * 0.4], [base[0] + q, base[1] + q + uy * s * 0.4], [base[0] - q, base[1] + q + uy * s * 0.4]].map(([x, y]) => [Math.round(x / 3) * 3 + ux * s * 0.5, Math.round(y / 3) * 3 + uy * s * 0.2]); }
      else { const tip = [base[0] + ux * s, base[1] + uy * s], nx = -uy, ny = ux; pts = [[base[0] + nx * w, base[1] + ny * w], tip, [base[0] - nx * w, base[1] - ny * w]]; }
      out.push({ pts, layer, op: it.op });
    }
  }
  return out;
}

// ---------------------------------------------------------------------------------------------------------- styling a fighter
const civC = {
  ...CIVILIAN,
  cfg: pal => ({ ...CIVILIAN.cfg(pal), torso: '#8a93a3', sleeve: '#8a93a3', torsoShade: '#00000030' }),
  blankHead: pal => ({ poly: [[-4.6, 1], [-5.4, 8], [-4.4, 14], [0, 16.4], [4.6, 14], [5.6, 8], [4, 1.5]], fill: pal.skin.mid, shadow: pal.skin.shadow, shade: [[-4.6, 1], [-5.4, 8], [-4.4, 14], [0, 16.4], [1, 16], [-2.4, 12], [-2.4, 6], [-1, 0.6]] }),
};
function styled(fk) {
  const base = FIGHTERS[fk], mask = MASK[fk];
  const c = { ...base };
  c.blankHead = (p, st) => {
    const bh = base.blankHead(p);
    let marks = bh.marks ?? [];
    if (fk === 'C') marks = marks.slice(1);
    let extra = sigilMarks(fk, p, st.aura ?? st.expression ?? 'neutral', mask);
    if ((st.yaw ?? 0) > 0) { const m = yawMap(fk, st.yaw); marks = marks.map(q => ({ ...q, poly: q.poly.map(m) })); extra = extra.map(q => ({ ...q, poly: q.poly.map(m) })); }
    return { ...bh, fill: mask.fill, shadow: mask.shadow, neck: mask.shadow, marks: [...marks, ...extra] };
  };
  const prevBack = base.back;
  c.back = (ctx, sk, st, cfg) => {
    let o = '';
    const state = st.aura ?? st.expression ?? 'neutral';
    if (!ctx.flat && !st.noAura) {
      const hc = sk.Hd(3, 9), u = sk.b.hs * 0.95, gy = 0;
      for (const a of auraPolys(fk, state, [hc.x, hc.y], u, gy)) {
        const col = a.layer === 'rim' ? ctx.pal.accent.mid : ctx.pal.accent.light;
        o += `<polygon points="${a.pts.map(p => `${p[0].toFixed(2)},${p[1].toFixed(2)}`).join(' ')}" fill="${col}" opacity="${(a.op * (a.layer === 'rim' ? 0.85 : 1)).toFixed(2)}"/>`;
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
  if (s === 'transform') return { lean: -6, head: -20, nearArm: [98, 122], farArm: [-98, -122], nearLeg: [20, 6], farLeg: [-20, -6], handNear: 'open', handFar: 'open' };
  return { lean: -8, head: -22, nearArm: [152, 172], farArm: [-150, -170], nearLeg: [18, 4], farLeg: [-16, -4], handNear: 'fist', handFar: 'fist' }; // triumph
}

function fig(fk, px, x, ground, { flat = false, state = 'neutral', civ = false, flip = false, yaw = YAW, noAura = false, wear = 0 } = {}) {
  const s = px / 100, pal = civ ? NEUTRAL : PAL[fk];
  const concept = civ ? civC : styled(fk);
  const ctx = makeCtx({ flat, pal, swMul: px < 9 ? 0 : px < 28 ? 0.6 : px < 80 ? 1 : 1.3, faceless: true });
  const p = civ ? CIV_POSES[0] : poseFor(fk, state);
  const st = civ ? { expression: 'neutral', yaw } : { yaw, expression: state === 'pride' || state === 'clash' || state === 'brink' || state === 'transform' ? 'neutral' : state, aura: state === 'clash' ? 'rage' : state, sway: FIGHTERS[fk].sway ?? 6, open: state === 'rage' || state === 'clash' ? 1 : state === 'hurt' || state === 'brink' ? 0.4 : 0, wear, forms: 6, noAura, hairLoose: state === 'rage' || state === 'hurt' || state === 'brink' };
  const { svg } = figure(ctx, concept, p, st, { yaw });
  const fl = flip ? ` transform="translate(${F(x)} 0) scale(-1 1) translate(${F(-x)} 0)"` : '';
  return `<g${fl}><g transform="translate(${F(x)} ${F(ground)}) scale(${F(s)} ${F(-s)})">${svg}</g></g>`;
}
function closeup(fk, state, x, y, size, px = 118) {
  const s = px / 100, pal = PAL[fk], concept = styled(fk);
  const ctx = makeCtx({ flat: false, pal, swMul: 1, faceless: true });
  const p = poseFor(fk, state);
  const st = { yaw: YAW, expression: state === 'pride' || state === 'transform' ? 'neutral' : state, aura: state, sway: FIGHTERS[fk].sway ?? 6, open: state === 'rage' ? 1 : 0, wear: 0, forms: 6, hairLoose: state === 'rage' || state === 'hurt' };
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
  b += text(30, 48, 'Marked plus Aura: the style', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'The sigil carries identity and small expression. The aura exaggerates emotion and state. Three-quarter, calm colour, mask tone per fighter.', { size: 15, fill: '#cfc6e6' });
  b += text(W - 30, 80, 'Working labels, placeholder looks. Status: proposal, pending Legal review.', { size: 12, fill: '#cfc6e6', anchor: 'end' });
  // showcase
  b += rect(24, 124, W - 48, 470, '#e8e5ee', 'stroke="#1b1428" stroke-opacity="0.2"');
  const xs = { P: 250, A: 700, E: 1180, C: 1600 };
  for (const fk of ORDER) {
    b += fig(fk, 250, xs[fk], 540, { state: 'pride' });
    b += text(xs[fk], 566, `${NAMES[fk]}: ${MASK[fk].tone} mask`, { size: 13, weight: 600, anchor: 'middle', op: 0.85 });
  }
  b += text(40, 150, 'The four fighters, showcase size, three-quarter, in the pride state (the aura stands tall)', { size: 12, weight: 700, op: 0.85 });
  // mask tones
  b += text(24, 630, 'Mask tone per fighter', { size: 18, weight: 700 });
  ORDER.forEach((fk, i) => {
    const x0 = 24 + i * 444;
    b += rect(x0, 640, 432, 116, MASK[fk].fill, 'stroke="#1b1428" stroke-opacity="0.25"');
    const tc = MASK[fk].tone === 'dark' ? '#f4f0fa' : '#1b1428';
    b += text(x0 + 14, 664, `${NAMES[fk]}: ${MASK[fk].tone}`, { size: 16, weight: 700, fill: tc });
    b += paras(x0 + 14, 686, MASK[fk].why, 62, 12.5, 16, { fill: tc });
  });
  // gameplay size
  b += text(24, 790, 'Gameplay size: 40 px and 12 px with a civilian, the aura in pride and in rage', { size: 13, weight: 700 });
  ORDER.forEach((fk, i) => {
    const x0 = 24 + i * 444;
    [[40, 'pride', 0], [40, 'rage', 1], [12, 'pride', 2], [12, 'rage', 3]].forEach(([px, st, j]) => {
      const cx = x0 + j * 108, cy = 802;
      b += rect(cx, cy, 100, 100, '#cfe6f0') + rect(cx, cy + 50, 100, 50, '#2f86ad');
      b += fig(fk, px, cx + 66, cy + 88, { state: st }) + fig(fk, px, cx + 20, cy + 88, { civ: true });
    });
    b += text(x0, 922, NAMES[fk], { size: 12, weight: 600, op: 0.85 });
  });
  // expression strips
  b += text(24, 960, 'Expression: neutral, taunt, hurt, rage, triumph (the mask sigil plus the aura, with a head close-up)', { size: 13, weight: 700 });
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

// ---------------------------------------------------------------------------------------------------------- sheet 2: aura vocabulary and rules
const RULES = [
  ['Shape', 'The aura is filled, cel-shaded shapes in two steps (a rim and a lighter core), in the fighter\'s shape family: circles (Protagonist), blades (Anti-hero), wedges (Empress), steps (Cyborg). It is never a thin line and never a closed ring. The HUD crown is thin arcs and rings only, so the two cannot be confused: filled against outline, irregular against round.'],
  ['Place', 'Anchored to the head and upper back, in the scene, behind the fighter. It rises above the head (up to about one body height) and sweeps back with movement. The crown is centred on the chest and drawn on the HUD layer over the fighter. Legal: the aura is never body-wide and never a power-stage signature.'],
  ['Colour', 'The fighter\'s own accent, two steps, at 12 to 55% opacity. No red, red-orange or gold for the Protagonist and Anti-hero. The crown uses UI\'s neutral role colours in thin strokes, never the fighter\'s accent. Suggested UI change: keep it that way.'],
  ['Motion', 'The aura changes shape, it does not blink. Hurt jitters irregularly and gutters low and small. A rage flare swells over 0.15 s and settles. Triumph blooms outward. Pride is steady. The crown pops for about 1 to 1.5 s and its flicker is a regular 4 Hz on and off, so an irregular, sustained shape is always the aura.'],
  ['Time', 'The aura is a state: it lasts as long as the emotion or the state. At neutral it is only a faint hint (12% opacity) so the fight stays clean. The crown is an event: it pops, then fades. The brink ring is the one persistent HUD cue: thin, faint and round.'],
  ['Transformation', 'The surge is a burst of tall shapes and ground shards from the head and shoulders, during the respected cinematic, then it settles to the new form\'s pride aura. It is not a body glow. The Protagonist\'s heat is steam and veins on the body (Hot Blood), never the aura.'],
];
function rulesSheet() {
  const W = 1800, H = 1660;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'The aura: vocabulary and rules', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'How it exaggerates and conveys, and how it stays distinct from the HUD aura crown.', { size: 15, fill: '#cfc6e6' });
  const states = ['neutral', 'pride', 'taunt', 'hurt', 'rage', 'triumph', 'transform'];
  const gloss = { neutral: 'a faint hint', pride: 'stands tall, steady', taunt: 'a lopsided drift', hurt: 'fragments, low, jittering', rage: 'flares forward, jagged', triumph: 'blooms outward', transform: 'surges: tall shapes and ground shards' };
  b += text(24, 140, 'Aura states, in each fighter\'s shape family', { size: 18, weight: 700 });
  states.forEach((s, j) => { b += text(24 + 112 + j * 232 + 116, 164, s, { size: 14, weight: 700, anchor: 'middle' }) + text(24 + 112 + j * 232 + 116, 180, gloss[s], { size: 11, anchor: 'middle', op: 0.75 }); });
  ORDER.forEach((fk, r) => {
    const y0 = 188 + r * 214;
    b += text(24, y0 + 90, NAMES[fk], { size: 13, weight: 700 });
    b += text(24, y0 + 108, { P: 'circles', A: 'blades', E: 'wedges', C: 'steps' }[fk], { size: 11, op: 0.75 });
    states.forEach((s, j) => {
      const x0 = 24 + 112 + j * 232;
      b += rect(x0, y0, 226, 206, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"');
      b += fig(fk, 108, x0 + (fk === 'E' ? 138 : 108), y0 + 198, { state: s });
    });
  });
  // aura vs HUD crown
  const y1 = 1060;
  b += text(24, y1, 'Aura against the HUD crown, on the same figure', { size: 18, weight: 700 });
  const demo = [['Aura only (diegetic, in the scene)', 'rage', false, false], ['HUD crown only (UI, on the HUD layer)', 'neutral', true, false], ['Both at once, a hit during rage', 'rage', true, false], ['HUD brink ring and a hurt aura', 'hurt', false, true]];
  demo.forEach(([cap, st, crown, brink], i) => {
    const x0 = 24 + i * 444;
    b += rect(x0, y1 + 14, 432, 250, '#cfe0ea', 'stroke="#1b1428" stroke-opacity="0.2"');
    b += fig('P', 150, x0 + 210, y1 + 254, { state: st, noAura: st === 'neutral' && crown });
    if (crown) b += hudCrown(x0 + 216, y1 + 254 - 88, 78);
    if (brink) b += hudCrown(x0 + 216, y1 + 254 - 70, 78, true).replace(/<polyline[^>]*\/>/g, '').replace(/<circle cx="[\d.]+" cy="[\d.]+" r="39.0"[^>]*\/>/, '');
    b += text(x0 + 10, y1 + 32, cap, { size: 12, weight: 600 });
  });
  b += text(24, y1 + 290, 'The crown is drawn here as UI\'s spec describes it (docs/ui/hud-spec.md): thin arcs at 1.0 R and an inner ring at 0.5 R, a faint dashed brink ring at 1.1 R. The aura never draws a ring or an outline arc.', { size: 12, op: 0.85 });
  // rules
  const y2 = 1390;
  b += text(24, y2, 'Rules', { size: 18, weight: 700 });
  RULES.forEach(([h, t], i) => {
    const col = i % 3, row = Math.floor(i / 3), x = 24 + col * 592, y = y2 + 26 + row * 118;
    b += text(x, y, h, { size: 14, weight: 700 }) + paras(x, y + 18, t, 92, 11.5, 15);
  });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

// ---------------------------------------------------------------------------------------------------------- sheet 3: staging
// Blocking rules: three-quarter cheat-out, the front to camera and mirrored when a fighter swaps sides, downstage (nearer the camera) reads as commanding.
function stagingSheet() {
  const W = 1800, H = 1730;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'Marked plus Aura: staged in the greybox scene', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'Three-quarter cheat-out, front to camera, mirrored when a fighter swaps sides, downstage reads as commanding. The four fighters together.', { size: 15, fill: '#cfc6e6' });
  const f = (fk, px, x, y, o = {}) => fig(fk, px, x, y, o);
  const rows = [
    { title: '1. Pre-fight face-off', note: 'The Protagonist and the Cyborg are downstage (bigger, nearer the camera, commanding), the Anti-hero and the Empress upstage. Everyone turns three-quarter toward the middle. The Anti-hero stands tall in his pride aura, the Empress taunts, the Protagonist and Cyborg wait with only a faint hint of aura.', scene: 'village', x: 24, y: 124, w: 880, h: 560,
      draw: () => f('A', 78, 250, 372, { state: 'pride' }) + f('E', 82, 640, 350, { state: 'taunt', flip: true }) + f('P', 122, 150, 520, { state: 'neutral' }) + f('C', 124, 770, 530, { state: 'neutral', flip: true }) },
    { title: '2. Mid-exchange clash', note: 'The Protagonist and the Anti-hero meet in the centre, both leaning in, both in rage, the auras flaring forward and overlapping at the contact. The Empress watches and taunts from upstage, the Cyborg waits. Nobody shows their back: the clash pair are three-quarter to camera, one mirrored.', scene: 'craters', x: 916, y: 124, w: 860, h: 560,
      draw: () => f('P', 128, 360, 510, { state: 'clash' }) + f('A', 122, 540, 512, { state: 'clash', flip: true }) + f('E', 74, 130, 380, { state: 'taunt' }) + f('C', 74, 770, 384, { state: 'neutral', flip: true }) },
    { title: '3. Transformation (a respected cinematic)', note: 'The Anti-hero surges alone, centred and downstage. A tall aura and ground shards rise from his head and shoulders, the sigil is fully lit and swollen, and the others stand back, three-quarter, watching. The letterbox is the cinematic\'s, not drawn here.', scene: 'high', x: 24, y: 780, w: 880, h: 560,
      draw: () => f('A', 178, 450, 540, { state: 'transform' }) + f('P', 84, 130, 470, { state: 'neutral' }) + f('E', 84, 760, 470, { state: 'neutral', flip: true }) + f('C', 84, 250, 420, { state: 'neutral' }) },
    { title: '4. Hurt and brink', note: 'The Protagonist is on the brink: folded, sigil dim and cracked, the aura down to a few guttering fragments. With it, UI\'s thin dashed brink ring (drawn as UI specifies) so the two are visibly different things. The Anti-hero stands over him, tall in pride. The Empress and the Cyborg close in.', scene: 'village', x: 916, y: 780, w: 860, h: 560,
      draw: () => f('P', 130, 340, 530, { state: 'brink' }) + `<g><circle cx="342" cy="466" r="62" fill="none" stroke="#5b5866" stroke-width="1.4" stroke-dasharray="6 5" opacity="0.7"/></g>` + f('A', 118, 560, 524, { state: 'pride', flip: true }) + f('E', 76, 720, 410, { state: 'neutral', flip: true }) + f('C', 76, 120, 400, { state: 'neutral' }) },
  ];
  rows.forEach(r => {
    b += scene(r.scene, r.x, r.y, r.w, r.h, r.draw());
    b += text(r.x + 12, r.y + 26, r.title, { size: 18, weight: 700, fill: '#f4f0fa' }).replace('<text', `<text stroke="#1b1428" stroke-width="3" paint-order="stroke"`);
    b += paras(r.x, r.y + r.h + 22, r.note, 132, 12.5, 16, { op: 0.92 });
  });
  // blocking notes
  const y = 1420;
  b += text(24, y, 'Blocking rules used on this sheet', { size: 18, weight: 700 });
  const notes = [
    ['Cheat out', 'Torso, hips and head turn about 32 degrees toward the camera. The near arm crosses the chest and the far arm sits beyond it, so the chest design and the mask face show.'],
    ['Mirror on side-swap', 'A fighter facing left is the mirror image of the same figure, so the front and the sigil face the camera and the back is never shown. The sigil is drawn on the face plane, so it reads either way.'],
    ['Downstage', 'The fighter nearer the camera is larger and lower in frame, and reads as commanding. In the face-off the leads are downstage, and the sneering pair is upstage.'],
    ['Aura and blocking', 'The aura sits behind the head and shoulders, so it never hides the mask, the sigil or the chest. It leans forward in rage and away from the camera-facing side so contact points stay clear.'],
    ['What is not staged here', 'Camera, the letterbox, the HUD and the crown pops. The crown pops are shown only in the brink example. Rendering owns the hybrid projection.'],
  ];
  notes.forEach(([h, t], i) => { const col = i % 3, row = Math.floor(i / 3), x = 24 + col * 592, yy = y + 30 + row * 110; b += text(x, yy, h, { size: 14, weight: 700 }) + paras(x, yy + 18, t, 92, 11.5, 15); });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

const ORIGIN = '<!-- Origin: procedural concept sheet written by art/concepts/marked-aura/gen.mjs (deterministic, no external images or fonts; the staging sheet embeds the repo\'s own renders in docs/rendering/img by reference), Art Director session (Claude, claude-sonnet-5-5), 2026-09-29; prompt record art/prompts/ART-0005-marked-aura.md -->' + String.fromCharCode(10);
writeFileSync(join(OUT, 'ma-1-style.svg'), ORIGIN + styleSheet());
writeFileSync(join(OUT, 'ma-2-aura-rules.svg'), ORIGIN + rulesSheet());
writeFileSync(join(OUT, 'ma-3-staging.svg'), ORIGIN + stagingSheet());
console.log('wrote ma-1-style.svg, ma-2-aura-rules.svg, ma-3-staging.svg');
