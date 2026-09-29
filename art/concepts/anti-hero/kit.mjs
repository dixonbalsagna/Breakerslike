// Origin: procedural concept-sheet figure kit (deterministic: no randomness, no external images, no fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-09-29. Human direction: Orb, via the EP.
// Geometry is a side-on stick skeleton with faceted polygon limbs. Angles are degrees from straight down,
// positive toward the facing direction (+x). Torso lean and head angle are clockwise (forward) positive.

export const rad = d => d * Math.PI / 180;
export const V = (x, y) => ({ x, y });
export const add = (a, b) => V(a.x + b.x, a.y + b.y);
export const sub = (a, b) => V(a.x - b.x, a.y - b.y);
export const mul = (a, k) => V(a.x * k, a.y * k);
export const dot = (a, b) => a.x * b.x + a.y * b.y;
export const len = a => Math.hypot(a.x, a.y);
export const norm = a => { const l = len(a) || 1; return V(a.x / l, a.y / l); };
export const lerp = (a, b, t) => V(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
export const dirDown = a => V(Math.sin(rad(a)), -Math.cos(rad(a)));
export const rotCW = (p, phi) => {
  const c = Math.cos(rad(phi)), s = Math.sin(rad(phi));
  return V(p.x * c + p.y * s, -p.x * s + p.y * c);
};

// Segment lengths in body units (one fighter is about 100 units tall, feet to hair).
export const DIM = { thigh: 21, shin: 21, upperArm: 15, foreArm: 14, hand: 5.5, torso: 30, neck: 3 };

// Light comes from the upper front. Shade bands sit on the side away from it.
const LIGHT = norm(V(0.5, 0.85));

const TORSO = [[5, -3.5], [4.2, 12], [6.8, 21], [5.2, 28.5], [2.4, 31], [-2.6, 31], [-5.8, 27], [-6.5, 20], [-4.6, 11], [-5.4, -3.5]];
const TORSO_SHADE = [[-5.4, -3.5], [-4.6, 11], [-6.5, 20], [-5.8, 27], [-2.6, 31], [-0.4, 31], [-2.8, 27], [-3.9, 20], [-2.4, 11], [-2.6, -3.5]];
const HEAD = [[-4.2, 1.5], [-5.4, 6], [-5.9, 11.5], [-4.4, 15.3], [-0.8, 16.6], [3.6, 15.6], [5.6, 12.8], [6.0, 10.6], [7.9, 8.2], [6.1, 7.3], [6.3, 5.6], [5.7, 4.5], [5.9, 3.2], [4.6, 0.6], [1.8, -0.3], [-1.6, 0.6]];
const HEAD_SHADE = [[-4.2, 1.5], [-5.4, 6], [-5.9, 11.5], [-4.4, 15.3], [-2.4, 15.9], [-3.6, 11], [-3.2, 6], [-1.6, 0.6]];
const BOOT = [[-3.2, 2.6], [2.9, 2.6], [3.2, -1.4], [9.2, -3.4], [9.8, -5], [-3.6, -5], [-3.8, -1.4]];

export function limb(p0, p1, w0, w1, belly = 1.12) {
  const d = norm(sub(p1, p0)), n = V(-d.y, d.x), L = len(sub(p1, p0));
  const m = Math.max(w0, w1) * belly, pm = add(p0, mul(d, L * 0.38));
  return [add(p0, mul(n, w0 / 2)), add(pm, mul(n, m / 2)), add(p1, mul(n, w1 / 2)), sub(p1, mul(n, w1 / 2)), sub(pm, mul(n, m / 2)), sub(p0, mul(n, w0 / 2))];
}
export function limbShade(p0, p1, w0, w1, belly = 1.12) {
  const d = norm(sub(p1, p0)), n = V(-d.y, d.x), L = len(sub(p1, p0));
  const sg = dot(n, LIGHT) < 0 ? 1 : -1, m = Math.max(w0, w1) * belly, pm = add(p0, mul(d, L * 0.38));
  const q = (p, w, k) => add(p, mul(n, sg * w * k));
  return [q(p0, w0, 0.5), q(pm, m, 0.5), q(p1, w1, 0.5), q(p1, w1, 0.12), q(pm, m, 0.12), q(p0, w0, 0.12)];
}
export const along = (a, b, t, off = 0) => {
  const d = norm(sub(b, a)), n = V(-d.y, d.x);
  return add(add(a, mul(sub(b, a), t)), mul(n, off));
};

export const pts = a => a.map(p => `${p.x.toFixed(2)},${p.y.toFixed(2)}`).join(' ');

// Skeleton: forward kinematics, with the lowest boot point put on the ground line (y = 0).
export const BUILD0 = { tw: 1, tl: 1, lw: 1, hs: 1, leg: 1, arm: 1 };
export function solve(pose, build = {}) {
  const bd = { ...BUILD0, ...build };
  const lean = pose.lean ?? 0;
  const bs = bd.lw;
  const bootAt = (A, foot) => BOOT.map(([x, y]) => add(A, rotCW(V(x * bs, y * bs), foot)));
  const legPts = (t1, t2, foot = 0) => {
    const K = mul(dirDown(t1), DIM.thigh * bd.leg), A = add(K, mul(dirDown(t2), DIM.shin * bd.leg));
    return { K, A, foot, boot: bootAt(A, foot) };
  };
  const nl0 = legPts(...pose.nearLeg), fl0 = legPts(...pose.farLeg);
  const minY = Math.min(...nl0.boot.map(p => p.y), ...fl0.boot.map(p => p.y));
  const P = V(0, -minY);
  const legAt = (t1, t2, foot = 0) => {
    const K = add(P, mul(dirDown(t1), DIM.thigh * bd.leg)), A = add(K, mul(dirDown(t2), DIM.shin * bd.leg));
    return { K, A, foot, boot: bootAt(A, foot) };
  };
  const T = (x, y) => add(P, rotCW(V(x * bd.tw, y * bd.tl), lean));
  const S = T(0, 27), N = T(0, 30);
  const headAng = lean + (pose.head ?? 0);
  const HB = add(N, mul(V(Math.sin(rad(headAng)), Math.cos(rad(headAng))), DIM.neck));
  const Hd = (x, y) => add(HB, rotCW(V(x * bd.hs, y * bd.hs), headAng));
  const arm = (a1, a2) => {
    const E = add(S, mul(dirDown(a1), DIM.upperArm * bd.arm)), W = add(E, mul(dirDown(a2), DIM.foreArm * bd.arm));
    return { E, W, F: add(W, mul(dirDown(a2), DIM.hand * bs)), a2 };
  };
  return { pose, b: bd, P, lean, T, S, N, HB, Hd, headAng, nearArm: arm(...pose.nearArm), farArm: arm(...pose.farArm), nearLeg: legAt(...pose.nearLeg), farLeg: legAt(...pose.farLeg) };
}

// Drawing context. In flat mode everything is solid black with no lines, shade bands or decals (the silhouette test).
export function makeCtx({ flat = false, pal, swMul = 1 }) {
  const C = c => (flat ? '#000' : c);
  const ctx = {
    flat, pal,
    poly(points, colour, o = {}) {
      if (flat && o.decal) return '';
      const stroke = !flat && swMul > 0 && o.line !== false ? ` stroke="${pal.line}" stroke-width="${(o.sw ?? 1.5) * swMul}" stroke-linejoin="round" vector-effect="non-scaling-stroke"` : '';
      return `<polygon points="${pts(points)}" fill="${C(colour)}"${o.op ? ` opacity="${o.op}"` : ''}${stroke}/>`;
    },
    shade(points, colour) { return flat ? '' : `<polygon points="${pts(points)}" fill="${colour}" opacity="0.9"/>`; },
    line(points, colour, sw = 1.2, o = {}) {
      if (flat || swMul === 0) return '';
      return `<polyline points="${pts(points)}" fill="none" stroke="${colour}" stroke-width="${sw * swMul}" stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke"${o.op ? ` opacity="${o.op}"` : ''}/>`;
    },
    dot(p, r, colour) { return flat ? '' : `<circle cx="${p.x.toFixed(2)}" cy="${p.y.toFixed(2)}" r="${r}" fill="${colour}"/>`; },
  };
  return ctx;
}

const torsoPoly = (sk, pts0, grow = 0) => pts0.map(([x, y]) => sk.T(x + Math.sign(x) * grow, y));
export const torsoLocal = (sk, list, grow = 0) => torsoPoly(sk, list, grow);

// Expressions: brow (inner end height, outer end height), eyelid, mouth shape.
const EXPR = {
  proud: { brow: [0.2, 0.7], lid: 0.55, mouth: 'flat', pupil: [0.4, 0], sweat: false },
  humbled: { brow: [1.6, -0.2], lid: 0.75, mouth: 'grit', pupil: [-0.5, -0.5], sweat: true },
  dropped: { brow: [-1.5, 0.9], lid: 0.05, mouth: 'roar', pupil: [0.5, 0], sweat: false },
  neutral: { brow: [0, 0.4], lid: 0.35, mouth: 'flat', pupil: [0.4, 0], sweat: false },
};

export function drawHead(ctx, sk, st, hair) {
  const { pal } = ctx, out = [];
  const H = (arr, g = 0) => arr.map(([x, y]) => sk.Hd(x, y));
  out.push(ctx.poly(limb(sk.N, sk.HB, 5.2 * sk.b.lw, 4.6 * sk.b.lw), pal.skin.mid));
  out.push(ctx.shade(limbShade(sk.N, sk.HB, 5.2 * sk.b.lw, 4.6 * sk.b.lw), pal.skin.shadow));
  out.push(ctx.poly(H(HEAD), pal.skin.mid));
  out.push(ctx.shade(H(HEAD_SHADE), pal.skin.shadow));
  // ear
  out.push(ctx.poly([sk.Hd(-1.2, 9.2), sk.Hd(-0.2, 9.8), sk.Hd(0.2, 7.6), sk.Hd(-1.0, 6.4), sk.Hd(-2.1, 7.8)], pal.skin.shadow, { sw: 1 }));
  out.push(hair(ctx, sk, st));
  if (!ctx.flat) {
    const e = EXPR[st.expression ?? 'neutral'];
    const browIn = sk.Hd(2.3, 11.1 + e.brow[0] * 0.5), browOut = sk.Hd(6.0, 11.4 + e.brow[1] * 0.4);
    // eye: white almond, pupil, lid
    const eyeC = [sk.Hd(2.5, 9.9), sk.Hd(4.0, 10.7), sk.Hd(5.6, 10.0), sk.Hd(4.0, 9.1)];
    out.push(ctx.poly(eyeC, '#f3efe8', { sw: 0.8 }));
    out.push(ctx.dot(sk.Hd(4.2 + e.pupil[0], 9.9 + e.pupil[1] * 0.4), 0.75, '#120c1e'));
    if (e.lid > 0.05) out.push(ctx.poly([sk.Hd(2.3, 10.05), sk.Hd(4.0, 10.85 + 0.0), sk.Hd(5.8, 10.15), sk.Hd(5.8, 10.15 - 0.9 * e.lid * 0.3 + 0.7 * (1 - e.lid)), sk.Hd(4.0, 10.8 - 1.6 * e.lid), sk.Hd(2.3, 10.05 - 0.6 * e.lid)], pal.skin.shadow, { sw: 0.6, op: 0.95 }));
    out.push(ctx.line([browIn, browOut], pal.hair.mid, 2.2));
    // mouth
    if (e.mouth === 'flat') out.push(ctx.line([sk.Hd(5.6, 4.7), sk.Hd(2.6, 4.5)], pal.line, 1.1));
    if (e.mouth === 'grit') {
      out.push(ctx.poly([sk.Hd(5.5, 5.0), sk.Hd(2.8, 4.9), sk.Hd(2.8, 3.7), sk.Hd(5.3, 3.9)], '#f3efe8', { sw: 0.8 }));
      out.push(ctx.line([sk.Hd(4.6, 5.0), sk.Hd(4.6, 3.8)], pal.line, 0.6));
      out.push(ctx.line([sk.Hd(3.7, 5.0), sk.Hd(3.7, 3.8)], pal.line, 0.6));
    }
    if (e.mouth === 'roar') {
      out.push(ctx.poly([sk.Hd(5.7, 5.5), sk.Hd(2.6, 5.4), sk.Hd(2.8, 2.6), sk.Hd(5.0, 2.4)], '#3a0d1c', { sw: 0.9 }));
      out.push(ctx.poly([sk.Hd(5.5, 5.4), sk.Hd(2.9, 5.3), sk.Hd(2.9, 4.6), sk.Hd(5.4, 4.7)], '#f3efe8', { sw: 0.5 }));
    }
    if (e.sweat) out.push(ctx.poly([sk.Hd(-2.0, 13.4), sk.Hd(-1.4, 12.2), sk.Hd(-2.6, 12.2)], '#bfe6f5', { sw: 0.6 }));
    if (st.expression === 'humbled') out.push(ctx.line([sk.Hd(1.6, 0.2), sk.Hd(2.6, -1.2)], pal.skin.shadow, 1.3)); // the swallow
  }
  return out.join('');
}

// Common torso, limbs and boots. `sleeve`: colour of the limb covering ('full' sleeves) or short sleeves to the elbow.
export function drawArm(ctx, sk, arm, side, cfg) {
  const { pal } = ctx, out = [];
  const far = side === 'far';
  const cs = far ? cfg.sleeveFar : cfg.sleeve, csh = cfg.sleeveShade;
  const w = [5.6, 4.7, 4.1].map(v => v * sk.b.lw);
  out.push(ctx.poly(limb(sk.S, arm.E, w[0], w[1]), cs));
  out.push(ctx.shade(limbShade(sk.S, arm.E, w[0], w[1]), csh));
  const foreCol = cfg.foreSkin ? pal.skin.mid : cs;
  out.push(ctx.poly(limb(arm.E, arm.W, w[1], w[2]), far && !cfg.foreSkin ? cfg.sleeveFar : foreCol));
  out.push(ctx.shade(limbShade(arm.E, arm.W, w[1], w[2]), cfg.foreSkin ? pal.skin.shadow : csh));
  return out;
}
export function drawHand(ctx, sk, arm, kind, far) {
  const { pal } = ctx;
  const skin = far ? pal.skin.shadow : pal.skin.mid;
  const d = norm(sub(arm.F, arm.W)), n = V(-d.y, d.x);
  let out;
  if (kind === 'fist') {
    out = ctx.poly(limb(arm.W, arm.F, 4.0 * sk.b.lw, 5.4 * sk.b.lw, 1.15), skin);
  } else {
    out = ctx.poly(limb(arm.W, add(arm.F, mul(d, 2)), 3.8 * sk.b.lw, 4.6 * sk.b.lw, 1.1), skin)
      + ctx.poly([add(arm.W, mul(d, 2)), add(add(arm.W, mul(d, 6.5)), mul(n, -3.6)), add(add(arm.W, mul(d, 3.2)), mul(n, -1.6))], skin, { sw: 1 });
  }
  return out;
}
export function drawBoot(ctx, sk, leg, colour, shadow, trim) {
  const bs = sk.b.lw;
  const bp = BOOT.map(([x, y]) => add(leg.A, rotCW(V(x * bs, y * bs), leg.foot)));
  const cuff = [[-3.4, 4.6], [3.1, 4.6], [3.2, 1.4], [-3.5, 1.4]].map(([x, y]) => add(leg.A, rotCW(V(x * bs, y * bs), leg.foot)));
  let s = ctx.poly(bp, colour) + ctx.shade([bp[0], bp[6], bp[5], add(bp[5], V(3.4, 0)), add(bp[6], V(2.2, 1.2)), add(bp[0], V(1.6, 0))], shadow);
  if (trim) s += ctx.poly(cuff, trim, { sw: 1.1 });
  return s;
}
export function drawLeg(ctx, sk, leg, cfg, far) {
  const cs = far ? cfg.trouserFar : cfg.trouser;
  const w = [8.6, 6.6, 5.4].map(v => v * sk.b.lw);
  let s = ctx.poly(limb(sk.P, leg.K, w[0], w[1]), cs) + ctx.shade(limbShade(sk.P, leg.K, w[0], w[1]), cfg.trouserShade);
  s += ctx.poly(limb(leg.K, leg.A, w[1], w[2]), cs) + ctx.shade(limbShade(leg.K, leg.A, w[1], w[2]), cfg.trouserShade);
  s += drawBoot(ctx, sk, leg, far ? cfg.bootFar : cfg.boot, cfg.bootShade, cfg.bootTrim);
  return s;
}
export function drawTorso(ctx, sk, cfg) {
  return ctx.poly(torsoPoly(sk, TORSO), cfg.torso) + ctx.shade(torsoPoly(sk, TORSO_SHADE), cfg.torsoShade)
    + ctx.poly([sk.T(-5.4, -3.5), sk.T(5, -3.5), sk.T(4.8, 1.2), sk.T(-5.2, 1.2)], cfg.trouser, { line: false });
}

// Wear decals: st.wear is 0 fresh, 1 bruised, 2 battered, 3 broken. Marks follow the region rules in the style guide.
export function drawWear(ctx, sk, st, cfg) {
  if (ctx.flat || !st.wear) return '';
  const { pal } = ctx, w = st.wear, o = [];
  const blood = '#b3202f', bruise = '#6d3a78', scuff = cfg.scuff ?? pal.gear.light;
  // head: bruise at the cheek, split lip, brow cut and a run of blood
  if (w >= 1) o.push(ctx.poly([sk.Hd(3.0, 6.9), sk.Hd(4.6, 7.2), sk.Hd(5.0, 6.1), sk.Hd(3.6, 5.5)], bruise, { line: false, op: 0.7 }));
  if (w >= 2) {
    o.push(ctx.line([sk.Hd(4.6, 12.0), sk.Hd(4.8, 9.4)], blood, 1.5));
    o.push(ctx.line([sk.Hd(5.6, 4.6), sk.Hd(5.7, 3.6)], blood, 1.6));
    o.push(ctx.poly([sk.Hd(2.6, 9.6), sk.Hd(5.9, 9.8), sk.Hd(5.8, 8.6), sk.Hd(3.0, 8.4)], bruise, { line: false, op: 0.5 }));
  }
  if (w >= 3) {
    o.push(ctx.poly([sk.Hd(4.6, 12.0), sk.Hd(5.4, 12.0), sk.Hd(6.6, 4.4), sk.Hd(5.0, 1.0), sk.Hd(4.2, 4.8)], blood, { line: false, op: 0.85 }));
    o.push(ctx.line([sk.Hd(-3.2, 8.4), sk.Hd(-3.0, 3.4)], blood, 1.3));
  }
  // core: scuffs, a tear and stains
  if (w >= 1) { o.push(ctx.line([sk.T(1, 20), sk.T(4.5, 17.6)], scuff, 1.5)); o.push(ctx.line([sk.T(-1, 14), sk.T(2.4, 11.8)], scuff, 1.5)); }
  if (w >= 2) o.push(ctx.poly([sk.T(4.6, 16), sk.T(6.3, 15.2), sk.T(5.0, 13), sk.T(3.6, 13.6)], blood, { line: false, op: 0.7 }));
  if (w >= 3) {
    o.push(ctx.poly([sk.T(-4, 22), sk.T(2.2, 19), sk.T(5.8, 12), sk.T(3.8, 8), sk.T(-3.6, 15)], cfg.tearFill ?? pal.skin.shadow, { line: false, op: 0.9 }));
    o.push(ctx.poly([sk.T(0.4, 18), sk.T(4.6, 14.4), sk.T(3.4, 10.6), sk.T(-0.6, 13.6)], blood, { line: false, op: 0.75 }));
  }
  // arms and legs, near side
  const A = sk.nearArm, L = sk.nearLeg;
  if (w >= 1) {
    o.push(ctx.line([along(A.E, A.W, 0.3, 1.0), along(A.E, A.W, 0.55, -0.6)], scuff, 1.5));
    o.push(ctx.line([along(sk.P, L.K, 0.5, -1.4), along(sk.P, L.K, 0.72, 0.9)], scuff, 1.5));
  }
  if (w >= 2) {
    o.push(ctx.poly([along(A.E, A.W, 0.35, -1.6), along(A.E, A.W, 0.75, -1.4), along(A.E, A.W, 0.72, 0.8), along(A.E, A.W, 0.38, 1.0)], bruise, { line: false, op: 0.45 }));
    o.push(ctx.line([along(A.E, A.W, 0.2, 2.0), along(A.E, A.W, 0.5, 0.2), along(A.E, A.W, 0.6, 1.4), along(A.E, A.W, 0.85, -0.6)], blood, 1.2));
  }
  if (w >= 3) {
    o.push(ctx.poly([along(L.K, L.A, 0.2, -2.6), along(L.K, L.A, 0.7, -2.2), along(L.K, L.A, 0.75, 1.2), along(L.K, L.A, 0.3, 2.4)], blood, { line: false, op: 0.7 }));
    o.push(ctx.line([along(A.E, A.W, 0.05, 2.2), along(A.E, A.W, 0.95, -1.6)], blood, 1.8));
  }
  return o.join('');
}

// The whole figure. `concept` supplies `cfg`, `back`, `over`, `front` and `armGear` layers.
export function figure(ctx, concept, pose, st) {
  const sk = solve(pose, concept.build), cfg = concept.cfg(ctx.pal, st), o = [];
  o.push(...drawArm(ctx, sk, sk.farArm, 'far', cfg));
  o.push(drawHand(ctx, sk, sk.farArm, pose.handFar ?? 'fist', true));
  o.push(drawLeg(ctx, sk, sk.farLeg, cfg, true));
  o.push(concept.back(ctx, sk, st, cfg));
  o.push(drawTorso(ctx, sk, cfg));
  o.push(drawLeg(ctx, sk, sk.nearLeg, cfg, false));
  o.push(concept.over(ctx, sk, st, cfg));
  o.push(drawHead(ctx, sk, st, concept.hair));
  o.push(concept.front(ctx, sk, st, cfg));
  o.push(...drawArm(ctx, sk, sk.nearArm, 'near', cfg));
  o.push(concept.armGear(ctx, sk, st, cfg));
  if (!concept.hideNearHand) o.push(drawHand(ctx, sk, sk.nearArm, pose.handNear ?? 'fist', false));
  o.push(drawWear(ctx, sk, st, cfg));
  o.push(concept.after ? concept.after(ctx, sk, st, cfg) : '');
  return { svg: o.join(''), sk };
}

// A plain civilian (the reference for "fighter or bystander?" at 5 px). Same skeleton, no regalia.
export const CIVILIAN = {
  cfg: pal => ({ sleeve: '#6c7079', sleeveFar: '#565b63', sleeveShade: '#4a4f57', foreSkin: true, trouser: '#3d4553', trouserFar: '#2f3641', trouserShade: '#252b34', boot: '#2b2b2f', bootFar: '#222226', bootShade: '#1c1c20', torso: '#8a93a3', torsoShade: '#68707f', scuff: '#c7ccd6' }),
  back: () => '', over: () => '', front: () => '', armGear: () => '',
  hair: (ctx, sk) => ctx.poly([[5.4, 12.6], [3.4, 16.2], [-1, 17], [-5, 14.6], [-6.2, 10], [-5.2, 6.4], [-3.4, 9.6], [0.4, 12], [3, 12.6]].map(([x, y]) => sk.Hd(x, y)), '#3b3128'),
};

// Poses shared by every concept. Angles: torso lean and head tilt clockwise-positive; limbs from straight down.
export const POSES = {
  // Proud: upright, chin up, hands clasped behind, feet together. The front.
  proud: { lean: -3, head: -7, nearArm: [-24, -8], farArm: [-16, -4], nearLeg: [3, 1], farLeg: [-4, -2], handNear: 'fist', handFar: 'fist' },
  // Humbled: folded forward, chin down, a hand clutching the ribs, knees soft.
  humbled: { lean: 25, head: 20, nearArm: [24, -112], farArm: [10, 16], nearLeg: [30, -4], farLeg: [-12, -24], handNear: 'open', handFar: 'fist' },
  // Act dropped: wide stance, chin out, arms open, weight forward. Nothing held back.
  dropped: { lean: 20, head: 12, nearArm: [58, 98], farArm: [-34, -80], nearLeg: [42, 16], farLeg: [-38, -14], handNear: 'open', handFar: 'fist' },
};

// Bystander reference pose: relaxed, arms at the sides.
export const CIV_POSES = [
  { lean: 0, head: 0, nearArm: [6, 8], farArm: [-4, -2], nearLeg: [3, 1], farLeg: [-3, -1], handNear: 'fist', handFar: 'fist' },
  { lean: 4, head: 3, nearArm: [22, 30], farArm: [-18, -20], nearLeg: [16, 2], farLeg: [-14, -8], handNear: 'fist', handFar: 'fist' },
  { lean: 2, head: 6, nearArm: [-30, 40], farArm: [12, 20], nearLeg: [2, 0], farLeg: [-2, -1], handNear: 'fist', handFar: 'fist' },
  { lean: -2, head: -4, nearArm: [40, 110], farArm: [-10, -6], nearLeg: [8, 0], farLeg: [-6, -2], handNear: 'open', handFar: 'fist' },
];
