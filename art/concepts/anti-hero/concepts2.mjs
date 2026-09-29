// Origin: round-2 Anti-hero silhouette concepts as procedural garment models (deterministic, no randomness).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-09-29. Human direction: Orb, via the EP.
// Four new bodies (a lean duelist, a heavy brawler, a compact coil, a long-haired upright) and the Standard revised.
// Forms F1 to F6 read through a growing gauntlet, scars, spine plates, hair cuffs or a slim plate frame. No shedding kit.

import { V, add, sub, mul, lerp, norm, dirDown, limb, limbShade, along } from './kit.mjs';
import { STANDARD } from './concepts.mjs';

const zig = (p0, p1, n, amp, up) => {
  const o = [p0];
  for (let i = 1; i < n; i++) {
    const b = lerp(p0, p1, i / n), k = 0.35 + 0.65 * (((i * 7) % 5) / 4);
    o.push(add(b, mul(up, amp * (i % 2 ? k : 0.12))));
  }
  o.push(p1);
  return o;
};
const T2 = (sk, arr) => arr.map(([x, y]) => sk.T(x, y));
function ring(c, r, n) { const o = []; for (let i = 0; i < n; i++) { const a = (i / n) * Math.PI * 2 + Math.PI / n; o.push(V(c.x + Math.cos(a) * r, c.y + Math.sin(a) * r)); } return o; }
const perp = d => V(-d.y, d.x);

const baseCfg = (pal, over = {}) => ({
  sleeve: pal.base.mid, sleeveFar: pal.base.shadow, sleeveShade: pal.base.shadow, foreSkin: false,
  trouser: pal.base.mid, trouserFar: pal.base.shadow, trouserShade: pal.base.shadow,
  boot: pal.base.shadow, bootFar: '#120b1e', bootShade: '#0d0816', bootTrim: pal.gear.mid,
  torso: pal.base.mid, torsoShade: pal.base.shadow, scuff: pal.gear.light, tearFill: pal.skin.shadow,
  ...over,
});
const bareArms = pal => ({ sleeve: pal.skin.mid, sleeveFar: pal.skin.shadow, sleeveShade: pal.skin.shadow, foreSkin: true });

// ---------------------------------------------------------------------------------------------------------
// D. THE DUELIST. Lean and tall, upright and arrogant. A knee-length coat, and one oversized gauntlet that
// grows with every form: a ring, a segment and a size. Feature at 12 px: one arm ends in a big mass.
// ---------------------------------------------------------------------------------------------------------
export const DUELIST = {
  id: 'D', name: 'The Duelist', sway: 9, hideNearHand: true,
  build: { tw: 0.9, tl: 1.06, lw: 0.88, hs: 0.96, leg: 1.1, arm: 1.06 },
  poses: { base: { lean: -4, head: -9, nearArm: [24, 50], farArm: [-14, -6], nearLeg: [6, 2], farLeg: [-9, -4], handNear: 'fist', handFar: 'fist' } },
  cfg: pal => baseCfg(pal, { coat: '#33254f', coatShade: '#241a3a' }),
  back(ctx, sk, st, cfg) {
    const { pal } = ctx, sway = st.sway ?? 9;
    const len = st.wear >= 3 ? 18 : 33;
    const wb = sk.T(-5.4, 9), wf = sk.T(1.4, 8);
    const hb = add(wb, mul(dirDown(-sway), len)), hf = add(wf, mul(dirDown(-sway * 0.5 + 2), len - 3));
    const up = norm(sub(wb, hb));
    const edge = st.wear >= 2 ? zig(hb, hf, st.wear >= 3 ? 6 : 5, st.wear >= 3 ? 5 : 3, up) : [hb, hf];
    let s = ctx.poly([sk.T(-6.3, 27), sk.T(-6.8, 19), wb, ...edge, wf], cfg.coat);
    s += ctx.shade([wb, hb, lerp(hb, hf, 0.35), lerp(wb, wf, 0.4)], cfg.coatShade);
    s += ctx.poly([hf, wf, lerp(wf, wb, 0.26), lerp(hf, hb, 0.14)], pal.accent.mid, { line: false });
    s += ctx.line([hb, ...edge.slice(1)], pal.gear.shadow, 1.3);
    return s;
  },
  over(ctx, sk, st, cfg) {
    const { pal } = ctx, sway = st.sway ?? 9;
    let s = ctx.poly(T2(sk, [[5.2, 8], [6.6, 16], [7.2, 21], [5.6, 27.2], [-3, 28.2], [-6.6, 27], [-7.2, 20], [-6.1, 9], [-5.8, 8]]), cfg.coat);
    s += ctx.shade(T2(sk, [[-5.8, 8], [-6.1, 9], [-7.2, 20], [-6.6, 27], [-4.6, 27.6], [-4.6, 20], [-3.6, 9]]), cfg.coatShade);
    const wf0 = sk.T(1.6, 8.5), wf1 = sk.T(5.4, 8.5);
    const h0 = add(wf0, mul(dirDown(5 + sway * 0.2), st.wear >= 3 ? 12 : 24)), h1 = add(wf1, mul(dirDown(12 + sway * 0.2 + (st.open ?? 0) * 20), st.wear >= 3 ? 11 : 26));
    const edge = st.wear >= 2 ? zig(h0, h1, 4, 2.6, norm(sub(wf0, h0))) : [h0, h1];
    s += ctx.poly([wf0, ...edge, wf1], cfg.coat);
    s += ctx.line(edge, pal.gear.shadow, 1.3);
    // a plain rose lapel line, and a thin belt
    s += ctx.line(T2(sk, [[4.6, 27], [3.2, 18], [4.4, 9]]), pal.accent.mid, 1.4);
    s += ctx.poly(T2(sk, [[-6.4, 8], [5.6, 8], [5.4, 10.6], [-6.6, 10.6]]), pal.gear.shadow, { sw: 1.1 });
    return s;
  },
  front(ctx, sk, st) {
    const { pal } = ctx;
    return ctx.poly(T2(sk, [[-4.4, 28], [-4.2, 32.4], [3.6, 32.8], [4.6, 28.6]]), cfg0(pal).coat, { sw: 1.2 });
  },
  armGear(ctx, sk, st, cfg) {
    const { pal } = ctx, n = st.forms ?? 6, A = sk.nearArm;
    const d = norm(sub(A.W, A.E));
    const start = along(A.E, A.W, 0.1), end = add(A.W, mul(d, 2.4 + 0.8 * n));
    const w = 5.8 + 0.6 * (n - 1);
    let s = ctx.poly(limb(start, A.W, w * 0.92, w * 1.05, 1.05), pal.base.light);
    s += ctx.shade(limbShade(start, A.W, w * 0.92, w * 1.05, 1.05), pal.base.shadow);
    s += ctx.poly(limb(A.W, end, w * 1.08, w * 1.3, 1.08), pal.base.light);
    s += ctx.shade(limbShade(A.W, end, w * 1.08, w * 1.3, 1.08), pal.base.shadow);
    for (let i = 1; i <= n; i++) {
      const t = i / (n + 1), c0 = along(start, A.W, t);
      s += ctx.poly([add(c0, mul(perp(d), w * 0.62)), add(add(c0, mul(d, 1.5)), mul(perp(d), w * 0.62)), sub(add(c0, mul(d, 1.5)), mul(perp(d), w * 0.62)), sub(c0, mul(perp(d), w * 0.62))], pal.accent.mid, { sw: 1 });
    }
    s += ctx.poly(limb(add(A.W, mul(d, 1.2)), end, w * 1.16, w * 1.36, 1.02), pal.gear.mid, { sw: 1.1, op: 0.0 });
    s += ctx.line([add(add(A.W, mul(d, 2.0)), mul(perp(d), w * 0.55)), add(add(end, mul(d, -0.6)), mul(perp(d), w * 0.62))], pal.gear.mid, 1.4);
    s += ctx.line([add(add(A.W, mul(d, 2.0)), mul(perp(d), -w * 0.55)), add(add(end, mul(d, -0.6)), mul(perp(d), -w * 0.62))], pal.gear.mid, 1.4);
    if (st.wear >= 2) s += ctx.line([along(start, A.W, 0.3, w * 0.5), along(start, A.W, 0.5, 0), along(start, A.W, 0.62, w * 0.3)], pal.line, 1.4);
    if (st.wear >= 3) s += ctx.poly([along(A.W, end, 0.2, w * 0.7), along(A.W, end, 0.6, w * 0.7), along(A.W, end, 0.5, w * 0.1), along(A.W, end, 0.25, w * 0.2)], pal.skin.shadow, { line: false });
    return s;
  },
  hair(ctx, sk, st) {
    const { pal } = ctx; const H = a => a.map(([x, y]) => sk.Hd(x, y));
    let s = ctx.poly(H([[5.6, 12.9], [4.2, 15.9], [0.4, 17.2], [-4.6, 15.8], [-6.6, 11.5], [-6.4, 6.5], [-4.6, 7.8], [-3.4, 10.6], [-1.4, 12.4], [2.4, 13]]), pal.hair.mid);
    if (st.hairLoose) s += ctx.poly(H([[1.6, 16.4], [6.6, 14.2], [7.6, 9.8], [6.4, 11.4], [4.0, 13.2]]), pal.hair.mid);
    return s;
  },
};
const cfg0 = pal => baseCfg(pal, { coat: '#33254f' });

// ---------------------------------------------------------------------------------------------------------
// E. THE BRAWLER. Heavy and low, predatory, knuckles near the knees. Bare arms, a dark sleeveless top, a belt,
// a scar across the face and one ash-white slash scar across the chest per form. Feature at 12 px: a wide, low mass.
// ---------------------------------------------------------------------------------------------------------
export const BRAWLER = {
  id: 'E', name: 'The Brawler', sway: 3,
  build: { tw: 1.3, tl: 1.0, lw: 1.32, hs: 1.02, leg: 0.92, arm: 1.08 },
  poses: { base: { lean: 34, head: -22, nearArm: [34, 14], farArm: [22, 8], nearLeg: [54, -14], farLeg: [-16, -42], handNear: 'fist', handFar: 'fist' } },
  cfg: pal => baseCfg(pal, bareArms(pal)),
  back() { return ''; },
  over(ctx, sk, st) {
    const { pal } = ctx; let s = '';
    s += ctx.poly(T2(sk, [[-6.4, 3.4], [6.0, 3.4], [5.8, 8.6], [-6.6, 8.6]]), pal.gear.shadow, { sw: 1.2 });
    s += ctx.poly(T2(sk, [[3.4, 4.2], [7.2, 4.2], [7.2, 8], [3.4, 8]]), pal.gear.mid, { sw: 1.1 });
    s += ctx.poly(T2(sk, [[-6.6, 6], [-9.5, 3.2 - (st.sway ?? 3) * 0.1], [-8, -1.4], [-5.4, 3.4]]), pal.gear.shadow, { sw: 1.0 });
    const n = st.forms ?? 6;
    const SCARS = [[[4.8, 24], [1.6, 19.4], [-0.6, 15.5]], [[1.2, 27], [-1.6, 23], [-4.2, 19.5]], [[5.2, 17.5], [2.2, 14.6], [-1.5, 11]], [[-1.0, 26.5], [1.6, 23.2], [3.8, 19]], [[-3.8, 16], [-0.6, 12.6], [2.2, 9.5]], [[3.5, 12.5], [0, 10.6], [-3.5, 8]]];
    for (let i = 0; i < Math.min(n, 6); i++) s += ctx.line(T2(sk, SCARS[i]), pal.gear.light, 1.5);
    return s;
  },
  front() { return ''; },
  armGear(ctx, sk, st) {
    const { pal } = ctx, A = sk.nearArm; let s = '';
    const a = along(A.E, A.W, 0.3), b = along(A.E, A.W, 1.0);
    for (const [t0, t1] of [[0, 0.22], [0.3, 0.52], [0.6, 0.86]]) s += ctx.poly(limb(along(a, b, t0), along(a, b, t1), 5.6 * sk.b.lw, 5.3 * sk.b.lw, 1.02), pal.gear.mid, { sw: 1 });
    return s;
  },
  hair() { return ''; },
  after(ctx, sk, st) {
    const { pal } = ctx; if (ctx.flat) return '';
    return ctx.line([sk.Hd(2.2, 14.6), sk.Hd(4.2, 10.4), sk.Hd(6.2, 6.4)], '#5a2a3a', 1.7)
      + ctx.line([sk.Hd(3.0, 12.6), sk.Hd(4.6, 13.2)], '#5a2a3a', 1.1) + ctx.line([sk.Hd(4.0, 10.2), sk.Hd(5.6, 10.9)], '#5a2a3a', 1.1)
      + ctx.line([sk.Hd(5.0, 8.2), sk.Hd(6.4, 8.9)], '#5a2a3a', 1.1);
  },
};

// ---------------------------------------------------------------------------------------------------------
// F. THE COIL. Compact and low, all spring. A line of armour plates runs down the spine, one more per form,
// and a long low tail of hair. Feature at 12 px: a small, dense mass with a serrated back.
// ---------------------------------------------------------------------------------------------------------
export const COIL = {
  id: 'F', name: 'The Coil', sway: 12,
  build: { tw: 1.12, tl: 0.87, lw: 1.05, hs: 1.06, leg: 0.84, arm: 0.95 },
  poses: { base: { lean: 26, head: -15, nearArm: [6, 120], farArm: [44, 104], nearLeg: [56, -8], farLeg: [-30, -46], handNear: 'fist', handFar: 'fist' } },
  cfg: pal => baseCfg(pal),
  back() { return ''; },
  over(ctx, sk, st) {
    const { pal } = ctx; let s = '';
    const n = st.forms ?? 6;
    for (let i = 0; i < n; i++) {
      const y = 27 - i * 4.3, bx = -5.8;
      const plate = T2(sk, [[bx + 1.2, y + 2.3], [bx - 4.6, y + 2.1], [bx - 5.8, y + 0.3], [bx - 5.0, y - 2.0], [bx + 1.2, y - 2.3]]);
      const broken = st.wear >= 3 && i % 2 === 1;
      if (broken) continue;
      s += ctx.poly(plate, i % 2 ? pal.gear.mid : pal.gear.light, { sw: 1.1 });
      s += ctx.shade(T2(sk, [[bx + 1.2, y - 0.1], [bx - 5.2, y - 0.4], [bx - 5.0, y - 2.0], [bx + 1.2, y - 2.3]]), pal.gear.shadow);
    }
    s += ctx.poly(T2(sk, [[-5.6, 4.6], [5.4, 4.6], [5.2, 8], [-5.8, 8]]), pal.gear.shadow, { sw: 1.1 });
    if (st.wear >= 2) s += ctx.line(T2(sk, [[4.8, 20], [1.8, 15.4]]), pal.gear.light, 1.5);
    return s;
  },
  front() { return ''; },
  armGear(ctx, sk, st) {
    const { pal } = ctx, n = st.forms ?? 6, A = sk.nearArm; let s = '';
    const count = n >= 6 ? 3 : n >= 4 ? 2 : 0;
    for (let i = 0; i < count; i++) {
      const t0 = 0.3 + i * 0.24;
      s += ctx.poly(limb(along(A.E, A.W, t0), along(A.E, A.W, t0 + 0.18), 5.2 * sk.b.lw, 4.8 * sk.b.lw, 1.02), pal.gear.mid, { sw: 1 });
    }
    return s;
  },
  hair(ctx, sk, st) {
    const { pal } = ctx; const H = a => a.map(([x, y]) => sk.Hd(x, y));
    let s = ctx.poly(H([[5.6, 12.9], [4.2, 15.9], [0.4, 17.2], [-4.4, 15.6], [-6.2, 11.2], [-5.4, 7.6], [-3.8, 9.4], [-1.4, 12], [2.4, 13]]), pal.hair.mid);
    const c = sk.Hd(-5.8, 12.4), dir = dirDown(-(52 + (st.sway ?? 12) * 0.8)), tip = add(c, mul(dir, 15)), nn = perp(dir);
    s += ctx.poly([add(c, mul(nn, 2.6)), add(lerp(c, tip, 0.5), mul(nn, 2.9)), add(tip, mul(nn, 0.8)), sub(tip, mul(nn, 0.8)), sub(lerp(c, tip, 0.5), mul(nn, 2.3)), sub(c, mul(nn, 2.6))], pal.hair.mid);
    if (st.hairLoose) s += ctx.poly(H([[1.6, 16.4], [6.6, 14.2], [7.6, 9.8], [6.4, 11.4], [4.0, 13.2]]), pal.hair.mid);
    return s;
  },
};

// ---------------------------------------------------------------------------------------------------------
// G. THE MANE. Tall, upright, aloof. Long straight hair down to the calves, cinched by one metal cuff per form.
// Sleeveless high-collar tunic and a sash. Feature at 12 px: a long dark mass behind the back.
// ---------------------------------------------------------------------------------------------------------
export const MANE = {
  id: 'G', name: 'The Mane', sway: 14,
  build: { tw: 1.0, tl: 1.03, lw: 0.98, hs: 1.0, leg: 1.05, arm: 1.0 },
  poses: { base: { lean: -2, head: -9, nearArm: [12, 24], farArm: [-10, -5], nearLeg: [5, 1], farLeg: [-7, -3], handNear: 'fist', handFar: 'fist' } },
  cfg: pal => baseCfg(pal, bareArms(pal)),
  back() { return ''; },
  over(ctx, sk, st) {
    const { pal } = ctx, sway = st.sway ?? 14;
    const wb = sk.T(-5.6, 10), wf = sk.T(5.4, 10);
    const hb = add(wb, mul(dirDown(-(10 + sway * 0.5)), 15)), hf = add(wf, mul(dirDown(6 + (st.open ?? 0) * 16), 14));
    const edge = st.wear >= 2 ? zig(hb, hf, 5, 2.4, norm(sub(wb, hb))) : [hb, hf];
    let s = ctx.poly([wb, ...edge, wf], pal.base.light);
    s += ctx.line(edge, pal.gear.shadow, 1.3);
    s += ctx.poly(T2(sk, [[-5.8, 6], [5.6, 6], [5.4, 10.4], [-6, 10.4]]), pal.gear.mid, { sw: 1.1 });
    s += ctx.poly(T2(sk, [[5.6, 8.6], [7.4, 8.6], [6.6, 0.2 - sway * 0.03], [5.0, 0.4]]), pal.accent.mid, { sw: 1 });
    return s;
  },
  front(ctx, sk) {
    const { pal } = ctx;
    return ctx.poly(T2(sk, [[-4.4, 28], [-4.4, 33.4], [3.4, 33.6], [4.6, 28.6]]), pal.base.light, { sw: 1.2 })
      + ctx.line(T2(sk, [[-4.2, 31.4], [4.2, 31.6]]), pal.gear.shadow, 1);
  },
  armGear() { return ''; },
  hair(ctx, sk, st) {
    const { pal } = ctx; const n = st.forms ?? 6;
    const H = a => a.map(([x, y]) => sk.Hd(x, y));
    let s = ctx.poly(H([[5.6, 12.9], [4.2, 15.9], [0.4, 17.4], [-4.4, 16.2], [-6.4, 12.4], [-6.2, 6], [-4.4, 7.2], [-3.4, 10.4], [-1.4, 12.2], [2.4, 13]]), pal.hair.mid);
    const c = sk.Hd(-5.4, 11), dir = dirDown(-(4 + (st.sway ?? 14) * 0.6)), len = 56, tip = add(c, mul(dir, len)), nn = perp(dir);
    const pt = (t, w) => add(add(c, mul(dir, len * t)), mul(nn, w));
    const wAt = t => 3.2 - 1.2 * Math.sin(t * Math.PI) * 0 + (t > 0.7 ? (t - 0.7) * 5 : 0) - t * 1.4;
    const left = [0, 0.25, 0.5, 0.75, 1].map(t => pt(t, wAt(t) + 0.8)), right = [1, 0.75, 0.5, 0.25, 0].map(t => pt(t, -(wAt(t) + 0.4)));
    s += ctx.poly([...left, ...right], pal.hair.mid);
    s += ctx.shade([pt(0, -1), pt(0.3, -1.4), pt(0.6, -1.1), pt(0.6, -(wAt(0.6) + 0.4)), pt(0.3, -(wAt(0.3) + 0.4)), pt(0, -(wAt(0) + 0.4))], pal.hair.light);
    for (let i = 0; i < n; i++) {
      const t = 0.12 + i * 0.13, p = pt(t, 0), w = wAt(t) + 1.4;
      s += ctx.poly([add(p, mul(nn, w)), add(add(p, mul(dir, 2.4)), mul(nn, w)), sub(add(p, mul(dir, 2.4)), mul(nn, w)), sub(p, mul(nn, w))], pal.gear.light, { sw: 1 });
    }
    if (st.hairLoose) s += ctx.poly(H([[1.6, 16.4], [6.6, 14.2], [7.6, 9.8], [6.4, 11.4], [4.0, 13.2]]), pal.hair.mid);
    return s;
  },
};

// ---------------------------------------------------------------------------------------------------------
// C2. THE STANDARD, REVISED. Same idea as round 1, straight-faced: a slim spine frame, shorter, with narrow dark
// slats instead of the bright flags. The slat count is still the form count.
// ---------------------------------------------------------------------------------------------------------
export const STANDARD2 = {
  ...STANDARD,
  id: 'C2', name: 'The Standard, revised', sway: 0.15,
  poses: { base: { lean: -3, head: -7, nearArm: [-24, -8], farArm: [-16, -4], nearLeg: [3, 1], farLeg: [-4, -2], handNear: 'fist', handFar: 'fist' } },
  back(ctx, sk, st) {
    const { pal } = ctx; let s = '';
    const n = st.forms ?? 6, sway = st.sway ?? 0.15;
    const top = st.wear >= 3 ? 46 : 64;
    s += ctx.poly(limb(sk.T(-9.2, -2), sk.T(-9.2, top), 1.7, 1.4, 1.0), pal.gear.mid, { sw: 1.2 });
    for (const y of [8, 22]) s += ctx.poly([sk.T(-6.2, y - 1.3), sk.T(-9.2, y - 1.3), sk.T(-9.2, y + 1.3), sk.T(-6.2, y + 1.3)], pal.gear.shadow, { sw: 1 });
    if (st.wear >= 3) s += ctx.poly(limb(sk.T(-9.2, 46), add(sk.T(-9.2, 46), mul(dirDown(-38), 12)), 1.5, 1.3, 1.0), pal.gear.mid, { sw: 1.1 });
    else s += ctx.poly([sk.T(-9.2, top + 3.6), sk.T(-8.0, top), sk.T(-9.2, top - 1.4), sk.T(-10.4, top)], pal.gear.light, { sw: 1 });
    const droop = 76 - 64 * sway;
    for (let i = 1; i <= n; i++) {
      const y = 57 - (i - 1) * 6.4;
      if (st.wear >= 3 && y > 44) continue;
      const a = sk.T(-9.2, y), L = (9 + 1.0 * (i - 1)) * (st.wear >= 2 ? 0.85 : 1), h = 1.6;
      const flut = 4 * Math.sin(i * 1.7) * (0.3 + sway);
      const d = V(-Math.cos((droop + flut) * Math.PI / 180), -Math.sin((droop + flut) * Math.PI / 180)), nn = perp(d);
      const e = add(a, mul(d, L));
      s += ctx.poly([add(a, mul(nn, h)), add(e, mul(nn, h)), sub(e, mul(nn, h)), sub(a, mul(nn, h))], pal.base.light, { sw: 1.0 });
      s += ctx.line([add(a, mul(nn, h * 0.9)), add(e, mul(nn, h * 0.9))], pal.gear.mid, 1.1);
      s += ctx.poly([sub(add(e, mul(d, -1.3)), mul(nn, h)), add(add(e, mul(d, -1.3)), mul(nn, h)), add(e, mul(nn, h)), sub(e, mul(nn, h))], pal.accent.mid, { sw: 0.8 });
    }
    return s;
  },
  armGear(ctx, sk) {
    const { pal } = ctx, A = sk.nearArm; let s = '';
    const a = along(A.E, A.W, 0.35), b = along(A.E, A.W, 1.0);
    for (const [t0, t1] of [[0, 0.22], [0.3, 0.52], [0.6, 0.86]]) s += ctx.poly(limb(along(a, b, t0), along(a, b, t1), 4.6, 4.3, 1.02), pal.gear.shadow, { sw: 1 });
    return s;
  },
};

export const CONCEPTS2 = { C2: STANDARD2, D: DUELIST, E: BRAWLER, F: COIL, G: MANE };

const SHARED = {
  line: '#120c1e',
  skin: { light: '#d6a381', mid: '#b98462', shadow: '#7d5238' },
  hair: { light: '#3a2f56', mid: '#1d1630', shadow: '#120c1e' },
};
export const PALETTES2 = {
  C2: { ...SHARED, base: { light: '#55427a', mid: '#33264f', shadow: '#1f1633' }, gear: { light: '#efeaf6', mid: '#d3cde3', shadow: '#8d86a8' }, accent: { light: '#ff86b3', mid: '#e0407f', shadow: '#7d1745' } },
  D: { ...SHARED, base: { light: '#4a3868', mid: '#2b2140', shadow: '#1a1229' }, gear: { light: '#e7ecf7', mid: '#c3cde0', shadow: '#8592ab' }, accent: { light: '#ee8bb8', mid: '#d0508c', shadow: '#7d1745' } },
  E: { ...SHARED, base: { light: '#4a3a70', mid: '#30244f', shadow: '#1d1533' }, gear: { light: '#f1edf8', mid: '#d6d0e6', shadow: '#8f88ad' }, accent: { light: '#e2c2ff', mid: '#b56bd8', shadow: '#6e3c95' } },
  F: { ...SHARED, base: { light: '#453764', mid: '#2a2043', shadow: '#181228' }, gear: { light: '#eef2f8', mid: '#cbd3e2', shadow: '#8a95ac' }, accent: { light: '#c9a6ff', mid: '#a36cf0', shadow: '#5a35a8' } },
  G: { ...SHARED, base: { light: '#5a4682', mid: '#3b2a55', shadow: '#231836' }, gear: { light: '#f0ecf7', mid: '#dcd6ea', shadow: '#948dae' }, accent: { light: '#ff9cc2', mid: '#ee6ba0', shadow: '#8c1d55' } },
};
