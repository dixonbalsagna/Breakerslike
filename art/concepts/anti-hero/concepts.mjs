// Origin: the three Anti-hero silhouette concepts as procedural garment models (deterministic, no randomness).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-09-29. Human direction: Orb, via the EP.
// Each concept is a set of layers over the shared skeleton in kit.mjs. Six regalia pieces, added one per form
// (F1 to F6) and shed in the reverse order under Shed Regalia if Orb picks it.

import { V, add, sub, mul, lerp, norm, dirDown, limb, limbShade, along, torsoLocal } from './kit.mjs';

const have = (st, n) => (st.forms ?? 6) >= n;
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

// ---------------------------------------------------------------------------------------------------------
// A. THE COLUMN. Tall and narrow. A long split coat, a standing collar, a sash, a chain of rank bars, bracers.
// Silhouette feature (5 px): a vertical rectangle with a trailing coat tail. 40 px: the standing collar and the tail.
// ---------------------------------------------------------------------------------------------------------
export const COLUMN = {
  id: 'A', name: 'The Column',
  pieces: [
    { form: 1, id: 'seal', label: 'Seal pin', weight: 'S' },
    { form: 2, id: 'bars', label: 'Rank bars', weight: 'S' },
    { form: 3, id: 'sash', label: 'Rank sash', weight: 'M' },
    { form: 4, id: 'collar', label: 'Standing collar', weight: 'M' },
    { form: 5, id: 'bracers', label: 'Bracers', weight: 'M' },
    { form: 6, id: 'coat', label: 'Long split coat', weight: 'L' },
  ],
  cfg: (pal) => ({
    sleeve: pal.base.mid, sleeveFar: pal.base.shadow, sleeveShade: pal.base.shadow, foreSkin: false,
    trouser: pal.base.mid, trouserFar: pal.base.shadow, trouserShade: pal.base.shadow,
    boot: pal.base.shadow, bootFar: '#1d1430', bootShade: '#150e24', bootTrim: pal.gear.mid,
    torso: pal.base.mid, torsoShade: pal.base.shadow, scuff: pal.gear.light, tearFill: pal.skin.shadow,
    coat: '#3a2957', coatShade: '#2a1d41',
  }),
  back(ctx, sk, st, cfg) {
    const { pal } = ctx; let s = '';
    const sway = st.sway ?? 6;
    if (have(st, 5)) s += bracer(ctx, sk, sk.farArm, st, true);
    if (have(st, 6)) {
      const len = st.wear >= 3 ? 24 : 41;
      const wb = sk.T(-5.6, 8), wf = sk.T(1.5, 7);
      const hb = add(wb, mul(dirDown(-sway), len)), hf = add(wf, mul(dirDown(-sway * 0.55 + 2), len - 3));
      const up = norm(sub(wb, hb));
      const edge = st.wear >= 2 ? zig(hb, hf, st.wear >= 3 ? 7 : 5, st.wear >= 3 ? 6 : 3.4, up) : [hb, hf];
      const panel = [sk.T(-6.4, 27), sk.T(-6.9, 19), wb, ...edge, wf];
      s += ctx.poly(panel, cfg.coat);
      s += ctx.shade([wb, ...edge.slice(0, 1), lerp(hb, hf, 0.35), lerp(wb, wf, 0.4)], cfg.coatShade);
      // accent lining showing on the inside edge
      s += ctx.poly([lerp(hf, wf, 0.0), wf, lerp(wf, wb, 0.28), lerp(hf, hb, 0.16)], pal.accent.mid, { line: false });
      s += ctx.line([hb, ...edge.slice(1)], pal.gear.mid, 1.4);
    }
    return s;
  },
  over(ctx, sk, st, cfg) {
    const { pal } = ctx; let s = '';
    const sway = st.sway ?? 6, open = st.open ?? 0;
    if (have(st, 6)) {
      // jacket over the torso, waist to shoulder line
      s += ctx.poly(T2(sk, [[5.2, 6], [6.6, 16], [7.2, 21], [5.6, 27.2], [-3, 28.2], [-6.6, 27], [-7.2, 20], [-6.1, 8], [-5.8, 6]]), cfg.coat);
      s += ctx.shade(T2(sk, [[-5.8, 6], [-6.1, 8], [-7.2, 20], [-6.6, 27], [-4.6, 27.6], [-4.6, 20], [-3.6, 8]]), cfg.coatShade);
      // front skirt, open in front so the legs show
      const wf0 = sk.T(1.4, 7), wf1 = sk.T(5.4, 7);
      const h0 = add(wf0, mul(dirDown(5 + sway * 0.18), st.wear >= 3 ? 16 : 30)), h1 = add(wf1, mul(dirDown(13 + sway * 0.2 + open * 26), st.wear >= 3 ? 14 : 33));
      const up = norm(sub(wf0, h0));
      const edge = st.wear >= 2 ? zig(h0, h1, 4, 3.2, up) : [h0, h1];
      s += ctx.poly([wf0, ...edge, wf1], cfg.coat);
      s += ctx.line(edge, pal.gear.mid, 1.4);
    }
    if (have(st, 3)) {
      const band = T2(sk, [[3.2, 28.4], [6.4, 25.6], [-3.2, 8.4], [-6.6, 11.4]]);
      s += ctx.poly(band, pal.accent.mid, { sw: 1.2 });
      s += ctx.shade(T2(sk, [[-6.6, 11.4], [-3.2, 8.4], [-2.4, 9.8], [-5.4, 12.6]]), pal.accent.shadow);
      const tail = T2(sk, [[-6.4, 11.2], [-3.4, 8.6], [-1.6, 2.4 - sway * 0.08], [-6.2, 3.4 - sway * 0.06]]);
      s += ctx.poly(tail, pal.accent.shadow, { sw: 1.1 });
    }
    return s;
  },
  front(ctx, sk, st, cfg) {
    const { pal } = ctx; let s = '';
    const open = st.open ?? 0;
    if (have(st, 4)) {
      const out = 1.6 * open;
      const broken = st.wear >= 3;
      const col = broken
        ? T2(sk, [[-4.6, 27.4], [-4.8, 31.5], [-1.2, 34.6], [1, 32], [3.8, 34.4], [4.8 + out, 28.6]])
        : T2(sk, [[-4.6, 27.4], [-4.6 - out, 35.8], [3.4 + out, 36.2 - open * 1.2], [4.8 + out, 28.6]]);
      s += ctx.poly(col, pal.gear.mid);
      s += ctx.shade(T2(sk, [[-4.6, 27.4], [-4.6 - out, 35.8], [-1.6, 36], [-1.4, 27.8]]), pal.gear.shadow);
      s += ctx.line(T2(sk, [[-4.4, 33.2], [4.2 + out, 33.6]]), pal.gear.shadow, 1);
      if (st.wear >= 2 && !broken) s += ctx.poly(T2(sk, [[1.6, 36.2], [3.4 + out, 36.2], [3.9 + out, 33.8], [2.6, 34.6]]), pal.skin.shadow, { line: false });
    }
    if (have(st, 2)) {
      s += ctx.line(T2(sk, [[5.4, 18.4], [5.7, 8.4]]), pal.gear.mid, 1.1);
      for (let i = 0; i < 5; i++) {
        const y = 17.4 - i * 2.2;
        s += ctx.poly(T2(sk, [[5.0, y], [7.4, y], [7.4, y - 1.5], [5.0, y - 1.5]]), pal.accent.light, { sw: 1 });
      }
    }
    if (have(st, 1)) {
      const c = sk.T(4.6, 21);
      s += ctx.poly(ring(c, 2.5, 8), pal.gear.mid, { sw: 1.2 }) + ctx.poly(ring(c, 1.2, 8), pal.accent.mid, { sw: 0.8 });
    }
    return s;
  },
  armGear(ctx, sk, st, cfg) { return have(st, 5) ? bracer(ctx, sk, sk.nearArm, st, false) : ''; },
  hair(ctx, sk, st) {
    const { pal } = ctx; const H = a => a.map(([x, y]) => sk.Hd(x, y));
    let s = ctx.poly(H([[5.6, 12.9], [4.2, 15.9], [0.4, 17.4], [-4.2, 16.2], [-6.6, 12.8], [-7.2, 8], [-6.2, 3.8], [-4.4, 5.6], [-3.4, 9.5], [-1.4, 12], [2.4, 13]]), pal.hair.mid);
    // one long swept lock with a round tip, never a point
    s += ctx.poly(H([[-3.6, 15.6], [-8.6, 14.6], [-12.4, 11.2], [-13.4, 7.2], [-11.4, 4.4], [-8.6, 6.0], [-6.4, 8.4]]), pal.hair.mid);
    s += ctx.shade(H([[-6.6, 12.8], [-10.4, 11.4], [-12.2, 8], [-11.4, 4.4], [-8.6, 6], [-6.4, 8.4]]), pal.hair.light);
    if (st.hairLoose) s += ctx.poly(H([[1.6, 16.4], [6.6, 14.2], [7.6, 9.8], [6.4, 11.4], [4.0, 13.2]]), pal.hair.mid);
    return s;
  },
};

function ring(c, r, n) { const o = []; for (let i = 0; i < n; i++) { const a = (i / n) * Math.PI * 2 + Math.PI / n; o.push(V(c.x + Math.cos(a) * r, c.y + Math.sin(a) * r)); } return o; }

function bracer(ctx, sk, arm, st, far) {
  const { pal } = ctx; let s = '';
  const a = along(arm.E, arm.W, 0.1), b = along(arm.E, arm.W, 1.0);
  const col = far ? pal.gear.shadow : pal.gear.mid;
  s += ctx.poly(limb(a, b, 5.6, 4.8, 1.06), col);
  s += ctx.shade(limbShade(a, b, 5.6, 4.8, 1.06), pal.gear.shadow);
  for (const t of [0.3, 0.5, 0.7]) s += ctx.line([along(a, b, t, -2.7), along(a, b, t, 2.7)], pal.gear.shadow, 1);
  if (!far && st.wear >= 2) s += ctx.line([along(a, b, 0.4, 2.7), along(a, b, 0.55, 0.6), along(a, b, 0.5, -0.8), along(a, b, 0.7, -2.7)], pal.line, 1.4);
  if (!far && st.wear >= 3) s += ctx.poly([along(a, b, 0.3, 2.9), along(a, b, 0.62, 2.9), along(a, b, 0.5, 0.6), along(a, b, 0.66, -1.4), along(a, b, 0.34, -1.2)], pal.skin.shadow, { line: false });
  return s;
}

// ---------------------------------------------------------------------------------------------------------
// B. THE BELL. Narrow shoulders over a flared, tiered robe. Each form adds a tier and the hem steps outward.
// Silhouette feature (5 px): a triangle. 40 px: the stepped hem. Closest to the Empress' sweeping mantle: see the doc.
// ---------------------------------------------------------------------------------------------------------
export const BELL = {
  id: 'B', name: 'The Bell',
  pieces: [
    { form: 1, id: 'seal', label: 'Seal pin', weight: 'S' },
    { form: 2, id: 'cord', label: 'Weighted cord belt', weight: 'S' },
    { form: 3, id: 'tier1', label: 'First tier (knee)', weight: 'M' },
    { form: 4, id: 'tier2', label: 'Second tier (shin)', weight: 'M' },
    { form: 5, id: 'ruff', label: 'Pleated back collar', weight: 'M' },
    { form: 6, id: 'tier3', label: 'Third tier (floor)', weight: 'L' },
  ],
  cfg: (pal) => ({
    sleeve: pal.base.mid, sleeveFar: pal.base.shadow, sleeveShade: pal.base.shadow, foreSkin: false,
    trouser: pal.base.shadow, trouserFar: '#1c162d', trouserShade: '#150f24',
    boot: '#20172f', bootFar: '#180f26', bootShade: '#120a1e', bootTrim: pal.gear.mid,
    torso: pal.base.mid, torsoShade: pal.base.shadow, scuff: pal.gear.light, tearFill: pal.skin.shadow,
  }),
  back(ctx, sk, st, cfg) {
    const { pal } = ctx; let s = '';
    if (have(st, 5)) {
      const base = sk.T(-3, 29);
      const fan = [[-12, 33], [-14.5, 40], [-9, 45], [-4, 43]];
      for (let i = 0; i < 4; i++) {
        const a = sk.T(-3 - i * 0.6, 29 + i * 1.1), b = sk.T(fan[i][0], fan[i][1]), c = sk.T(fan[i][0] + 3.6, fan[i][1] + (i === 3 ? 0.4 : -0.8));
        s += ctx.poly([a, b, c], i % 2 ? pal.gear.mid : pal.gear.light, { sw: 1.1 });
      }
    }
    return s;
  },
  over(ctx, sk, st, cfg) {
    const { pal } = ctx; let s = '';
    const sway = st.sway ?? 4, open = st.open ?? 0;
    const tiers = [
      { f: 6, len: 46, spread: 26, col: pal.base.shadow, trim: pal.accent.mid },
      { f: 4, len: 38, spread: 22, col: pal.gear.shadow, trim: pal.accent.mid },
      { f: 3, len: 29, spread: 18, col: pal.gear.mid, trim: pal.accent.light },
    ];
    for (const t of tiers) {
      if (!have(st, t.f)) continue;
      const len = st.wear >= 3 ? t.len * 0.7 : t.len;
      const wb = sk.T(-5, 8), wf = sk.T(5, 8);
      const hb = add(wb, mul(dirDown(-(t.spread + sway)), len)), hf = add(wf, mul(dirDown(t.spread - sway * 0.25 + open * 14), len));
      const up = norm(sub(wb, hb));
      const edge = st.wear >= 2 ? zig(hb, hf, st.wear >= 3 ? 8 : 6, st.wear >= 3 ? 5 : 3, up) : [hb, hf];
      s += ctx.poly([wb, ...edge, wf], t.col);
      s += ctx.shade([wb, hb, lerp(hb, hf, 0.3), lerp(wb, wf, 0.3)], '#00000033');
      s += ctx.line(edge, t.trim, 1.6);
    }
    if (have(st, 2)) {
      s += ctx.poly(T2(sk, [[-5.6, 5.4], [5.6, 5.4], [5.4, 9.2], [-5.8, 9.2]]), pal.accent.mid, { sw: 1.1 });
      s += ctx.line(T2(sk, [[5.6, 7.2], [6.4, 1.8]]), pal.accent.shadow, 1.4) + ctx.poly(T2(sk, [[5.4, 2.6], [7.6, 2.6], [7.4, -0.4], [5.6, -0.4]]), pal.accent.light, { sw: 0.9 });
    }
    return s;
  },
  front(ctx, sk, st) {
    const { pal } = ctx; let s = '';
    if (have(st, 1)) {
      const c = sk.T(4.6, 21);
      s += ctx.poly(ring(c, 2.5, 8), pal.gear.mid, { sw: 1.2 }) + ctx.poly(ring(c, 1.2, 8), pal.accent.mid, { sw: 0.8 });
    }
    return s;
  },
  armGear() { return ''; },
  hair(ctx, sk, st) {
    const { pal } = ctx; const H = a => a.map(([x, y]) => sk.Hd(x, y));
    let s = ctx.poly(H([[5.8, 13], [4.4, 16.2], [0, 17.6], [-4.6, 16.4], [-6.8, 12], [-6.6, 5], [-4.6, 6.4], [-3.6, 10], [-1.4, 12.4], [2.4, 13.2]]), pal.hair.mid);
    if (st.hairLoose) s += ctx.poly(H([[1.6, 16.4], [6.6, 14.2], [7.6, 9.8], [6.4, 11.4], [4.0, 13.2]]), pal.hair.mid);
    return s;
  },
};

// ---------------------------------------------------------------------------------------------------------
// C. THE STANDARD. A rigid pole on the back, taller than his head, with one rank plate hung on it per form.
// Silhouette feature (5 px): a vertical line above the head. 40 px: the count and stagger of plates.
// The plates are the stage readout at the widest zoom. The pole rides the core: battered tears plates, broken snaps it.
// ---------------------------------------------------------------------------------------------------------
export const STANDARD = {
  id: 'C', name: 'The Standard',
  pieces: [
    { form: 1, id: 'plate1', label: 'Plate 1, harness, seal', weight: 'S' },
    { form: 2, id: 'plate2', label: 'Plate 2', weight: 'S' },
    { form: 3, id: 'plate3', label: 'Plate 3', weight: 'M' },
    { form: 4, id: 'plate4', label: 'Plate 4', weight: 'M' },
    { form: 5, id: 'plate5', label: 'Plate 5', weight: 'M' },
    { form: 6, id: 'plate6', label: 'Plate 6 (largest)', weight: 'L' },
  ],
  cfg: (pal) => ({
    sleeve: pal.base.mid, sleeveFar: pal.base.shadow, sleeveShade: pal.base.shadow, foreSkin: true,
    trouser: pal.base.mid, trouserFar: pal.base.shadow, trouserShade: pal.base.shadow,
    boot: pal.base.shadow, bootFar: '#150f24', bootShade: '#0f0a1a', bootTrim: pal.gear.mid,
    torso: pal.base.mid, torsoShade: pal.base.shadow, scuff: pal.gear.light, tearFill: pal.skin.shadow,
  }),
  back(ctx, sk, st, cfg) {
    const { pal } = ctx; let s = '';
    const top = st.wear >= 3 ? 49 : 72;
    // far forearm binding
    s += bindings(ctx, sk, sk.farArm, true);
    // pole and its two brackets
    const p0 = sk.T(-9.6, -2), p1 = sk.T(-9.6, top);
    s += ctx.poly(limb(p0, p1, 2.1, 1.7, 1.0), pal.gear.mid, { sw: 1.3 });
    s += ctx.shade(limbShade(p0, p1, 2.1, 1.7, 1.0), pal.gear.shadow);
    for (const y of [8, 24]) s += ctx.poly([sk.T(-6.4, y - 1.5), sk.T(-9.6, y - 1.5), sk.T(-9.6, y + 1.5), sk.T(-6.4, y + 1.5)], pal.gear.shadow, { sw: 1 });
    if (st.wear >= 3) {
      const hinge = sk.T(-9.6, 49), tip = add(hinge, mul(dirDown(-38), 14));
      s += ctx.poly(limb(hinge, tip, 1.9, 1.6, 1.0), pal.gear.mid, { sw: 1.2 });
      s += ctx.poly([add(tip, mul(dirDown(-38), 4.4)), add(tip, V(1.5, -0.6)), add(tip, V(-1.4, 0.6))], pal.accent.mid, { sw: 1 });
    }
    else s += ctx.poly([sk.T(-9.6, top + 4.6), sk.T(-8.1, top), sk.T(-9.6, top - 1.6), sk.T(-11.1, top)], pal.accent.mid, { sw: 1.1 });
    // plates: signal-flag tablets on the pole, all streaming the same way. Alternating colours, square ends.
    const sway = st.sway ?? 0.2;
    const droop = 78 - 66 * sway;
    for (let i = 1; i <= 6; i++) {
      if (!have(st, i)) continue;
      const y = 69 - (i - 1) * 8.6;
      if (st.wear >= 3 && y > 50) continue;
      const a = sk.T(-9.6, y), L = (10 + 1.0 * (i - 1)) * (st.wear >= 2 ? 0.82 : 1), h = 2.3;
      const flut = 5 * Math.sin(i * 1.7) * (0.3 + sway);
      const d = V(-Math.cos((droop + flut) * Math.PI / 180), -Math.sin((droop + flut) * Math.PI / 180));
      const n = V(-d.y, d.x);
      const e = add(a, mul(d, L));
      let poly = [add(a, mul(n, h)), add(e, mul(n, h)), sub(e, mul(n, h)), sub(a, mul(n, h))];
      if (st.wear >= 2) poly = [add(a, mul(n, h)), add(e, mul(n, h * 0.9)), add(add(a, mul(d, L - 2.6)), mul(n, h * 0.1)), add(e, mul(n, -h * 0.4)), sub(a, mul(n, h))];
      const col = i % 2 ? pal.accent.shadow : pal.gear.light;
      s += ctx.poly(poly, col, { sw: 1.1 });
      s += ctx.poly([add(a, mul(n, h)), add(add(a, mul(d, 2.4)), mul(n, h)), sub(add(a, mul(d, 2.4)), mul(n, h)), sub(a, mul(n, h))], pal.gear.shadow, { sw: 0.9 });
    }
    return s;
  },
  over(ctx, sk, st, cfg) {
    const { pal } = ctx; let s = '';
    const sway = st.sway ?? 0.2;
    // short jacket skirts to the hip
    const wb = sk.T(-5.8, 10), wf = sk.T(5.4, 10);
    const hb = add(wb, mul(dirDown(-(12 + sway * 26)), st.wear >= 3 ? 11 : 17)), hf = add(wf, mul(dirDown(6 + (st.open ?? 0) * 18), 15));
    const up = norm(sub(wb, hb));
    const edge = st.wear >= 2 ? zig(hb, hf, 5, 2.6, up) : [hb, hf];
    s += ctx.poly([wb, ...edge, wf], pal.base.light);
    s += ctx.line(edge, pal.gear.mid, 1.3);
    // harness: two straps crossing the chest to the back plate
    s += ctx.poly(T2(sk, [[3.6, 28.2], [6.2, 25.8], [-4.4, 10.6], [-6.6, 13.6]]), pal.gear.mid, { sw: 1.1 });
    s += ctx.poly(T2(sk, [[-4.2, 28], [-6.6, 24.4], [3.8, 10.4], [6.2, 12.8]]), pal.gear.shadow, { sw: 1.1 });
    return s;
  },
  front(ctx, sk, st) {
    const { pal } = ctx;
    const c = sk.T(4.4, 19);
    return ctx.poly(ring(c, 2.6, 8), pal.gear.mid, { sw: 1.2 }) + ctx.poly(ring(c, 1.3, 8), pal.accent.mid, { sw: 0.8 });
  },
  armGear(ctx, sk, st) { return bindings(ctx, sk, sk.nearArm, false); },
  hair(ctx, sk, st) {
    const { pal } = ctx; const H = a => a.map(([x, y]) => sk.Hd(x, y));
    let s = ctx.poly(H([[5.6, 12.9], [4.2, 15.7], [0.4, 16.9], [-3.8, 15.8], [-5.8, 12.2], [-3.6, 12.4], [0.6, 13.4], [3.6, 13]]), pal.hair.mid);
    if (st.hairLoose) s += ctx.poly(H([[1.6, 16.6], [6.6, 14.2], [7.6, 9.8], [6.4, 11.4], [4.0, 13.2]]), pal.hair.mid);
    return s;
  },
};

function bindings(ctx, sk, arm, far) {
  const { pal } = ctx; let s = '';
  const a = along(arm.E, arm.W, 0.35), b = along(arm.E, arm.W, 1.0);
  const col = far ? pal.gear.shadow : pal.gear.light;
  for (const [t0, t1] of [[0, 0.22], [0.3, 0.52], [0.6, 0.86]]) s += ctx.poly(limb(along(a, b, t0), along(a, b, t1), 4.6, 4.3, 1.02), col, { sw: 1 });
  return s;
}

export const CONCEPTS = { A: COLUMN, B: BELL, C: STANDARD };

// Palettes: one shared identity (skin, hair, line) and per-concept masses. Every colour has a light, mid and shadow step.
const SHARED = {
  line: '#120c1e',
  skin: { light: '#d6a381', mid: '#b98462', shadow: '#7d5238' },
  hair: { light: '#3a2f56', mid: '#1d1630', shadow: '#120c1e' },
};
export const PALETTES = {
  A: { ...SHARED, base: { light: '#6b4f97', mid: '#4a3568', shadow: '#2c1f44' }, gear: { light: '#edf1f8', mid: '#c9d2e0', shadow: '#8996ac' }, accent: { light: '#ee8bb8', mid: '#d0508c', shadow: '#7d1745' } },
  B: { ...SHARED, base: { light: '#5e5087', mid: '#3f3560', shadow: '#261f3d' }, gear: { light: '#ece8f6', mid: '#cfc9e2', shadow: '#8f88ad' }, accent: { light: '#e2c2ff', mid: '#c98cff', shadow: '#8a55c7' } },
  C: { ...SHARED, base: { light: '#55427a', mid: '#33264f', shadow: '#1f1633' }, gear: { light: '#efeaf6', mid: '#d3cde3', shadow: '#8d86a8' }, accent: { light: '#ff86b3', mid: '#e0407f', shadow: '#7d1745' } },
};
