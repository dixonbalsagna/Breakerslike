// Origin: the four fighters (and one guard of honour) as procedural concept models for the character art directions.
// Deterministic, no randomness, no external images. Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-09-29.
// Human direction: Orb, via the EP. Every design is a proposal. Names and looks are placeholders pending Orb and Legal.

import { V, add, sub, mul, lerp, norm, dirDown, limb, limbShade, along } from '../anti-hero/kit.mjs';
import { COIL, PALETTES2 } from '../anti-hero/concepts2.mjs';

const T2 = (sk, arr) => arr.map(([x, y]) => sk.T(x, y));
const F2 = (sk, arr) => arr.map(([x, y]) => (sk.TF ?? sk.T)(x, y)); // front-surface features: at yaw 0 the same as T2
const perp = d => V(-d.y, d.x);
function ring(c, r, n) { const o = []; for (let i = 0; i < n; i++) { const a = (i / n) * Math.PI * 2 + Math.PI / n; o.push(V(c.x + Math.cos(a) * r, c.y + Math.sin(a) * r)); } return o; }
const zig = (p0, p1, n, amp, up) => {
  const o = [p0];
  for (let i = 1; i < n; i++) { const b = lerp(p0, p1, i / n), k = 0.35 + 0.65 * (((i * 7) % 5) / 4); o.push(add(b, mul(up, amp * (i % 2 ? k : 0.12)))); }
  o.push(p1); return o;
};
const baseCfg = (pal, over = {}) => ({
  sleeve: pal.base.mid, sleeveFar: pal.base.shadow, sleeveShade: pal.base.shadow, foreSkin: false,
  trouser: pal.base.mid, trouserFar: pal.base.shadow, trouserShade: pal.base.shadow,
  boot: pal.base.shadow, bootFar: '#100a14', bootShade: '#0b060f', bootTrim: pal.gear.mid,
  torso: pal.base.mid, torsoShade: pal.base.shadow, scuff: pal.gear.light, tearFill: pal.skin.shadow, ...over,
});
const bareArms = pal => ({ sleeve: pal.skin.mid, sleeveFar: pal.skin.shadow, sleeveShade: pal.skin.shadow, foreSkin: true });
const cyl = (ctx, a, b, w, fill) => ctx.poly(limb(a, b, w, w, 1.0), fill, { sw: 1 });

// ------------------------------------------------------------------------------------------------ Protagonist
// Round, open, forward-leaning. Sleeveless dark tunic, a wide light belt with a big round knot at the back, wrapped fists,
// a swept-back rounded hair mass (teal is QA's placeholder). Shape lane: circles.
export const PROTAGONIST = {
  id: 'P', name: 'Protagonist', sway: 8,
  build: { tw: 1.1, tl: 1.0, lw: 1.12, hs: 1.08, leg: 1.0, arm: 1.05 },
  poses: { base: { lean: 10, head: -4, nearArm: [58, 92], farArm: [-28, 18], nearLeg: [30, 8], farLeg: [-26, -6], handNear: 'open', handFar: 'fist' } },
  cfg: pal => baseCfg(pal, bareArms(pal)),
  back() { return ''; },
  over(ctx, sk, st) {
    const { pal } = ctx, sway = st.sway ?? 8; let s = '';
    const wb = sk.T(-5.8, 9.4), wf = sk.T(5.4, 9.4);
    const hb = add(wb, mul(dirDown(-(12 + sway)), 13)), hf = add(wf, mul(dirDown(8), 12));
    s += ctx.poly([wb, hb, hf, wf], pal.base.light);
    s += ctx.line(F2(sk, [[3.4, 28.4], [0.8, 20.4]]), pal.gear.shadow, 1.5);
    s += ctx.poly(T2(sk, [[-6.6, 4.6], [6.0, 4.6], [5.8, 9.8], [-6.8, 9.8]]), pal.gear.mid, { sw: 1.2 });
    const k = sk.T(-8.6, 8);
    s += ctx.poly([add(k, V(-0.6, -2)), add(k, V(-2.6 - sway * 0.05, -13)), add(k, V(1.6, -13.6)), add(k, V(2.4, -1.4))], pal.gear.shadow, { sw: 1 });
    s += ctx.poly(ring(k, 5.2, 10), pal.gear.mid, { sw: 1.3 }) + ctx.poly(ring(k, 2.2, 8), pal.gear.shadow, { sw: 0.8 });
    return s;
  },
  front() { return ''; },
  armGear(ctx, sk, st) {
    const { pal } = ctx, A = sk.nearArm; let s = '';
    for (const [t0, t1] of [[0.28, 0.44], [0.5, 0.66], [0.72, 0.9]]) s += ctx.poly(limb(along(A.E, A.W, t0), along(A.E, A.W, t1), 5.4 * sk.b.lw, 5.2 * sk.b.lw, 1.05), pal.gear.mid, { sw: 1 });
    return s;
  },
  hair(ctx, sk) {
    const { pal } = ctx; const H = a => a.map(([x, y]) => sk.Hd(x, y));
    return ctx.poly(H([[5.8, 13], [4.4, 17.2], [0.6, 19.2], [-4.4, 17.8], [-8.4, 14.6], [-12.4, 11.6], [-14, 8.4], [-12, 6.4], [-8.4, 8.2], [-5.8, 6.8], [-5.8, 11], [-3.4, 12.8], [1, 13.6]]), pal.hair.mid);
  },
  blankHead: pal => ({
    poly: [[-5, 1], [-6.4, 7], [-5.8, 13], [-2.2, 17], [2.6, 17.2], [6.2, 13.6], [7, 8], [5.4, 2.6], [2, 0], [-2, 0.2]],
    shade: [[-5, 1], [-6.4, 7], [-5.8, 13], [-2.2, 17], [-1.2, 16.6], [-3.6, 12], [-3.4, 6], [-1.6, 0.4]],
    fill: pal.gear.mid, shadow: pal.gear.shadow, neck: pal.gear.shadow,
  }),
};

// ------------------------------------------------------------------------------------------------ Anti-hero (the Coil)
export const ANTIHERO = {
  ...COIL, id: 'A', name: 'Anti-hero',
  blankHead: pal => ({
    poly: [[-4.6, 1], [-5.8, 8], [-4.6, 14.6], [0, 17.4], [4.8, 15.6], [7.6, 9], [6, 3], [2.2, 0]],
    shade: [[-4.6, 1], [-5.8, 8], [-4.6, 14.6], [0, 17.4], [1.2, 17], [-2.6, 12.4], [-2.6, 6], [-1.2, 0.4]],
    fill: pal.gear.mid, shadow: pal.gear.shadow, neck: pal.gear.shadow,
  }),
};

// ------------------------------------------------------------------------------------------------ Empress
// Wide, sweeping, asymmetric. A dark tunic under a bladed mantle worn as a cape-train: a stiff crescent behind the head,
// a long train, and a hem of blade shapes. Shape lane: a triangle. No horns, not pale, no purple.
export const EMPRESS = {
  id: 'E', name: 'Empress', sway: 10,
  build: { tw: 0.95, tl: 1.08, lw: 0.86, hs: 0.98, leg: 1.08, arm: 1.02 },
  poses: { base: { lean: -4, head: -10, nearArm: [30, 60], farArm: [-14, -8], nearLeg: [4, 1], farLeg: [-6, -3], handNear: 'open', handFar: 'fist' } },
  cfg: pal => baseCfg(pal),
  back(ctx, sk, st) {
    const { pal } = ctx, sway = st.sway ?? 10; let s = '';
    const S1 = sk.T(-5.8, 28), W = sk.T(-6.4, 6);
    const hemB = add(S1, mul(dirDown(-(46 + sway * 1.2)), 66)), hemA = add(W, mul(dirDown(-(14 + sway)), 62));
    s += ctx.poly([sk.T(-3, 30.5), sk.T(-9.5, 45), sk.T(-15, 37.5), sk.T(-12.4, 28)], pal.base.mid);
    s += ctx.line(T2(sk, [[-3.4, 31], [-9.4, 44.6], [-14.6, 37.6]]), pal.accent.mid, 1.6);
    s += ctx.poly([S1, hemB, hemA, W], pal.base.mid);
    s += ctx.shade([S1, lerp(S1, hemB, 0.5), lerp(W, hemA, 0.5), W], pal.base.shadow);
    s += ctx.poly([S1, lerp(S1, hemB, 0.34), lerp(W, hemA, 0.34), W], pal.accent.mid, { line: false, op: 0.9 });
    // the blades: a hem of sharp shapes on the trailing edge
    const N = 8, e0 = hemB, e1 = hemA, out = norm(perp(sub(e1, e0)));
    const outward = out.x < 0 || (out.x === 0 && out.y < 0) ? out : mul(out, -1);
    for (let i = 0; i < N; i++) {
      const p0 = lerp(e0, e1, i / N), p1 = lerp(e0, e1, (i + 1) / N), tip = add(lerp(p0, p1, 0.5), mul(outward, 6.4 + (i % 2) * 2.2));
      s += ctx.poly([p0, tip, p1], i % 2 ? pal.gear.light : pal.gear.mid, { sw: 1 });
    }
    return s;
  },
  over(ctx, sk, st) {
    const { pal } = ctx, sway = st.sway ?? 10; let s = '';
    s += ctx.poly(T2(sk, [[5.2, 8], [6.6, 16], [7, 21], [5.4, 27.2], [-3, 28.2], [-6.4, 27], [-7, 20], [-6, 9], [-5.8, 8]]), pal.base.light);
    const wf0 = sk.T(1.6, 8.5), wf1 = sk.T(5.6, 8.5);
    const h0 = add(wf0, mul(dirDown(4 + sway * 0.3), 36)), h1 = add(wf1, mul(dirDown(10 + sway * 0.3 + (st.open ?? 0) * 20), 38));
    s += ctx.poly([wf0, h0, h1, wf1], pal.base.light);
    s += ctx.line([h0, h1], pal.gear.mid, 1.6);
    s += ctx.poly(T2(sk, [[-6.4, 7.6], [5.6, 7.6], [5.4, 11], [-6.6, 11]]), pal.gear.mid, { sw: 1.1 });
    s += ctx.poly(T2(sk, [[5.6, 10.4], [7.4, 10.4], [7, 2.4], [5.2, 2.6]]), pal.accent.mid, { sw: 1 });
    return s;
  },
  front(ctx, sk) {
    const { pal } = ctx;
    return ctx.poly(T2(sk, [[-4.4, 28], [-4.4, 34], [3.4, 34.2], [4.6, 28.6]]), pal.base.mid, { sw: 1.2 })
      + ctx.poly([sk.Hd(-5.8, 14.2), sk.Hd(6.2, 14.6), sk.Hd(6.2, 16.2), sk.Hd(-5.8, 15.9)], pal.gear.light, { sw: 1 });
  },
  armGear(ctx, sk) {
    const { pal } = ctx, A = sk.nearArm;
    return ctx.poly(limb(along(A.E, A.W, 0.6), along(A.E, A.W, 1.0), 5.0 * sk.b.lw, 4.4 * sk.b.lw, 1.02), pal.accent.mid, { sw: 1 });
  },
  hair(ctx, sk) {
    const { pal } = ctx; const H = a => a.map(([x, y]) => sk.Hd(x, y));
    return ctx.poly(H([[5.8, 13], [4.4, 17.2], [0.6, 19.2], [-4, 17.6], [-6.6, 13], [-6.2, 7], [-4.4, 8.6], [-3.4, 11.6], [-1, 12.6], [3, 13]]), pal.hair.mid)
      + ctx.poly(ring(sk.Hd(-2.6, 21.4), 3.6, 9), pal.hair.mid);
  },
  blankHead: pal => ({
    poly: [[-3.8, 1], [-5, 7], [-4.6, 14], [-2, 20.5], [2, 21], [4.4, 15], [5.6, 8.6], [4.4, 2.4], [1.4, 0]],
    shade: [[-3.8, 1], [-5, 7], [-4.6, 14], [-2, 20.5], [-0.8, 20.6], [-3, 13], [-3, 7], [-1.6, 0.4]],
    fill: pal.gear.mid, shadow: pal.gear.shadow, neck: pal.gear.shadow,
    marks: [{ poly: [[-4.8, 12.6], [5.2, 13.2], [5.4, 14.6], [-4.8, 14.2]], fill: pal.accent.mid }],
  }),
};

// ------------------------------------------------------------------------------------------------ Guard of honour
export const GUARD = {
  id: 'g', name: 'Guard of honour', sway: 6,
  build: { tw: 1.0, tl: 1.0, lw: 1.0, hs: 1.0, leg: 1.0, arm: 1.0 },
  poses: { base: { lean: 0, head: 0, nearArm: [8, 34], farArm: [-6, -2], nearLeg: [3, 1], farLeg: [-3, -1], handNear: 'fist', handFar: 'fist' } },
  cfg: pal => baseCfg(pal),
  back() { return ''; },
  over(ctx, sk) {
    const { pal } = ctx;
    return ctx.poly(T2(sk, [[3.6, 27], [5.6, 6], [-5.8, 6], [-5.6, 27]]), pal.base.light) + ctx.poly(T2(sk, [[3.2, 28.4], [6.4, 25.6], [-3.2, 8.4], [-6.6, 11.4]]), pal.gear.mid, { sw: 1 });
  },
  front(ctx, sk) {
    const { pal } = ctx; const H = a => a.map(([x, y]) => sk.Hd(x, y));
    return ctx.poly(H([[-6.6, 6], [-6.8, 14.4], [-3, 19.6], [2.4, 20.2], [6.6, 15.6], [6.8, 12.4], [4.4, 10], [4.4, 5]]), pal.base.mid, { sw: 1.3 })
      + ctx.poly(H([[-6.6, 6], [4.4, 5], [4.4, 7], [-6.6, 8]]), pal.gear.mid, { sw: 1 })
      + ctx.poly(H([[-2.4, 19.8], [-6, 26], [-11.6, 27], [-9.4, 21.2], [-6.2, 19]]), pal.accent.mid, { sw: 1 });
  },
  armGear(ctx, sk) {
    const { pal } = ctx, A = sk.nearArm, top = sk.Hd(0, 30).y + 6;
    return ctx.poly(limb(V(A.F.x, 0), V(A.F.x, top), 1.5, 1.3, 1.0), pal.gear.mid, { sw: 1 })
      + ctx.poly([V(A.F.x - 2.2, top - 1), V(A.F.x, top + 9), V(A.F.x + 2.2, top - 1)], pal.gear.light, { sw: 1 });
  },
  hair() { return ''; },
};

// ------------------------------------------------------------------------------------------------ Cyborg
// Heavy, blocky. Dark red plating and chain-mail, a rail down the chest with four hatches (head, chest, back, hip) and the
// chip showing in one, a squared backpack unit and looping cables. A boxy head with a visor slit. Shape lane: squares.
export const CYBORG = {
  id: 'C', name: 'Cyborg', sway: 4, machineHead: true,
  build: { tw: 1.36, tl: 1.0, lw: 1.38, hs: 1.12, leg: 0.95, arm: 1.02 },
  poses: { base: { lean: 8, head: 0, nearArm: [38, 44], farArm: [-26, -2], nearLeg: [18, 4], farLeg: [-16, -6], handNear: 'fist', handFar: 'fist' } },
  cfg: pal => baseCfg(pal),
  back(ctx, sk, st) {
    const { pal } = ctx; let s = '';
    s += ctx.poly(T2(sk, [[-6.2, 27.6], [-11.4, 27.6], [-11.4, 10], [-6.2, 10]]), pal.base.shadow, { sw: 1.3 });
    for (let i = 0; i < 4; i++) s += ctx.poly(T2(sk, [[-7.2, 25 - i * 3.6], [-10.4, 25 - i * 3.6], [-10.4, 23.6 - i * 3.6], [-7.2, 23.6 - i * 3.6]]), pal.accent.mid, { sw: 0.8 });
    return s;
  },
  over(ctx, sk, st) {
    const { pal } = ctx; let s = '';
    if (!ctx.flat) {
      s += ctx.poly(T2(sk, [[4.6, 27], [6.6, 16], [5.0, 6], [-5.6, 6], [-6.4, 20], [-5.8, 27]]), 'url(#mail)', { line: false, op: 0.55 });
    }
    // chain-mail apron
    const wb = sk.T(-5.6, 7), wf = sk.T(5.6, 7);
    const hb = add(wb, mul(dirDown(-6 - (st.sway ?? 4) * 0.5), 15)), hf = add(wf, mul(dirDown(8), 15));
    s += ctx.poly([wb, ...zig(hb, hf, 6, 2.4, norm(sub(wb, hb))), wf], pal.gear.shadow);
    if (!ctx.flat) s += ctx.poly([wb, hb, hf, wf], 'url(#mail)', { line: false, op: 0.7 });
    // the rail and its four hatches: chest is open and the chip shows there
    s += ctx.poly(F2(sk, [[4.0, 28.4], [6.2, 28.4], [6.6, 8], [4.4, 8]]), pal.gear.mid, { sw: 1 });
    s += ctx.poly(F2(sk, [[3.4, 25], [7.4, 25], [7.4, 19.6], [3.4, 19.6]]), pal.base.shadow, { sw: 1.3 });
    s += ctx.poly(F2(sk, [[4.4, 23.6], [6.6, 23.6], [6.6, 21], [4.4, 21]]), pal.accent.light, { sw: 0.9 });
    s += ctx.poly(F2(sk, [[3.6, 13], [7.2, 13], [7.2, 9.6], [3.6, 9.6]]), pal.base.shadow, { sw: 1.2 });
    s += ctx.poly(T2(sk, [[-6.8, 20.4], [-4, 20.4], [-4, 16.6], [-6.8, 16.6]]), pal.base.shadow, { sw: 1.2 });
    // cables looping from the backpack over the shoulder and down to the hip
    if (!ctx.flat) {
      const cab = pts => ctx.line(pts, pal.base.shadow, 3.4) + ctx.line(pts, pal.accent.mid, 1.1);
      s += cab(T2(sk, [[-9, 27], [-2, 32], [4, 28.6], [5.6, 20]]));
      s += cab(T2(sk, [[-10, 12], [-3, 4], [4, 5.4], [5.4, 9]]));
    }
    return s;
  },
  front() { return ''; },
  armGear(ctx, sk) {
    const { pal } = ctx, A = sk.nearArm; let s = '';
    s += ctx.poly(limb(along(A.E, A.W, 0.05), along(A.E, A.W, 0.5), 6.4 * sk.b.lw, 5.8 * sk.b.lw, 1.06), pal.gear.shadow, { sw: 1.1 });
    if (!ctx.flat) s += ctx.poly(limb(along(A.E, A.W, 0.05), along(A.E, A.W, 0.5), 6.4 * sk.b.lw, 5.8 * sk.b.lw, 1.06), 'url(#mail)', { line: false, op: 0.7 });
    s += ctx.poly(limb(along(A.E, A.W, 0.55), along(A.E, A.W, 1.0), 6.6 * sk.b.lw, 6.2 * sk.b.lw, 1.05), pal.gear.mid, { sw: 1.2 });
    return s;
  },
  hair() { return ''; },
  blankHead: pal => ({
    poly: [[-5.8, 0.6], [-5.8, 15.6], [6.6, 15.6], [6.8, 0.6]],
    shade: [[-5.8, 0.6], [-5.8, 15.6], [-3.2, 15.6], [-3.2, 0.6]],
    fill: pal.gear.mid, shadow: pal.gear.shadow, neck: pal.gear.shadow,
    marks: [{ poly: [[1.2, 9.2], [6.8, 9.2], [6.8, 11.4], [1.2, 11.4]], fill: pal.accent.mid }, { poly: [[-1.6, 13.4], [4.4, 13.4], [4.4, 14.6], [-1.6, 14.6]], fill: pal.base.shadow }],
  }),
};

export const FIGHTERS = { P: PROTAGONIST, A: ANTIHERO, E: EMPRESS, C: CYBORG };
export const ORDER = ['P', 'A', 'E', 'C'];
export const LANE = { P: 'teal', A: 'violet', E: 'chartreuse', C: 'dark red' };

const SKIN0 = { light: '#d6a381', mid: '#b98462', shadow: '#7d5238' };
export const PALETTES = {
  P: {
    line: '#0c1c20', skin: { light: '#c98f6d', mid: '#a56d4d', shadow: '#6d4530' }, hair: { light: '#7cf0d8', mid: '#22c7a9', shadow: '#128070' },
    base: { light: '#2e6470', mid: '#1a3d46', shadow: '#10262c' }, gear: { light: '#e6faf6', mid: '#c4ece6', shadow: '#7fb8b0' }, accent: { light: '#7cf0d8', mid: '#22c7a9', shadow: '#128070' },
  },
  A: { ...PALETTES2.F, skin: SKIN0 },
  E: {
    line: '#0f1206', skin: { light: '#f0cfae', mid: '#d9a67f', shadow: '#9b6c4c' }, hair: { light: '#3b4726', mid: '#1e2413', shadow: '#10140a' },
    base: { light: '#3a4420', mid: '#252d12', shadow: '#161b09' }, gear: { light: '#f4f3dc', mid: '#e0deb8', shadow: '#9a9870' }, accent: { light: '#d8ff5c', mid: '#a8d820', shadow: '#5f8010' },
  },
  C: {
    line: '#14070a', skin: { light: '#cfc7cb', mid: '#a99fa5', shadow: '#6d6369' }, hair: { light: '#3a161c', mid: '#3a161c', shadow: '#220b10' },
    base: { light: '#5a2a30', mid: '#3a161c', shadow: '#220b10' }, gear: { light: '#e9e4e6', mid: '#cfc7cb', shadow: '#8c8187' }, accent: { light: '#ffb0a8', mid: '#ff6b63', shadow: '#a02c2a' },
  },
  g: {
    line: '#0f1206', skin: { light: '#e0b592', mid: '#c48f68', shadow: '#8a5f42' }, hair: { light: '#3b4726', mid: '#1e2413', shadow: '#10140a' },
    base: { light: '#3a4420', mid: '#252d12', shadow: '#161b09' }, gear: { light: '#f4f3dc', mid: '#e0deb8', shadow: '#9a9870' }, accent: { light: '#d8ff5c', mid: '#a8d820', shadow: '#5f8010' },
  },
};
