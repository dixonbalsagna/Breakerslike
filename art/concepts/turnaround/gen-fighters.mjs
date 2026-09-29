// Origin: procedural generator for the Protagonist, Empress and Cyborg turnaround sheets (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-09-29. Human direction: Orb, via the EP.
// Run from the repo root:  node art/concepts/turnaround/gen-fighters.mjs   (writes protagonist-turnaround.svg, empress-turnaround.svg, cyborg-turnaround.svg)
// Same format as the Coil's sheet (gen.mjs): front, three-quarter right and left, back, the pose in play, wear, mask close-ups, read sizes, a part list, palette and rig.
// The sigils, dome mask and palettes come from ../shared/marks.mjs, which carries Legal's conditions.

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeCtx, figure, limb, V, add, sub, mul, lerp, norm, rotCW } from '../anti-hero/kit.mjs';
import { FIGHTERS, GUARD, PALETTES } from '../directions/fighters.mjs';
import { PAL, MASK, NAMES, circ, band, scl, sigilMarks, maskHead, pWraps, empressBack } from '../shared/marks.mjs';

const OUT = dirname(fileURLToPath(import.meta.url));
const F = n => n.toFixed(2);
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family=\"'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif\"";
const text = (x, y, t, { size = 14, weight = 400, fill = '#1b1428', anchor = 'start', op = 1 } = {}) =>
  `<text x="${F(x)}" y="${F(y)}" ${FONT} font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}" opacity="${op}">${esc(t)}</text>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fill}" ${extra}/>`;
const wrap = (t, n) => { const w = t.split(' '), out = []; let line = ''; for (const x of w) { if ((line + ' ' + x).trim().length > n) { out.push(line.trim()); line = x; } else line += ' ' + x; } if (line.trim()) out.push(line.trim()); return out; };
const paras = (x, y, t, n, size = 13, gap = 17, o = {}) => wrap(t, n).map((l, i) => text(x, y + i * gap, l, { size, ...o })).join('');
const V2 = arr => arr.map(([x, y]) => V(x, y));

// lateral points on the front surface (a = 5.4) and the back surface (a = -5.8), and any depth a: b is sideways, y is height
const LAT = (sk, b, y, a) => add(sk.P, rotCW(V((sk.yaw.c * a - b * sk.yaw.s) * sk.b.tw, y * sk.b.tl), sk.lean));
const LF = (sk, b, y) => LAT(sk, b, y, 5.4);
const LB = (sk, b, y) => LAT(sk, b, y, -5.8);
const NEUTRAL_UP = { lean: 0, head: 0, nearArm: [10, 8], farArm: [-10, -8], nearLeg: [3, 1], farLeg: [-3, -1], handNear: 'fist', handFar: 'fist' };

// A hem of blades (the Empress's mantle): triangles along a line from p0 to p1, pointing away from `up`
function blades(ctx, p0, p1, n, len, cols, sw = 1) {
  let o = '';
  const dir = sub(p1, p0), out = norm(V(dir.y, -dir.x)), down = out.y < 0 ? out : mul(out, -1);
  for (let i = 0; i < n; i++) {
    const a = lerp(p0, p1, i / n), b = lerp(p0, p1, (i + 1) / n), tip = add(lerp(a, b, 0.5), mul(down, len + (i % 2) * len * 0.34));
    o += ctx.poly([a, tip, b], cols[i % cols.length], { sw });
  }
  return o;
}

// ---------------------------------------------------------------------------------------------------------- the three concepts
// Each keeps the fighter's own three-quarter and profile features (from directions/fighters.mjs) and adds front and back features on the
// front and back surfaces. `st.face` is 'front' or 'back' for those two views, and undefined for three-quarter and profile.
function tConcept(fk) {
  const BASE = fk === 'E' ? { ...FIGHTERS.E, back: empressBack } : FIGHTERS[fk], mask = MASK[fk];
  const c = { ...BASE, id: fk + '-T', name: NAMES[fk] };
  c.blankHead = (p, st) => {
    const yaw = st.yaw ?? 0, mh = maskHead(fk, BASE.blankHead(p), p, mask, yaw);
    if (st.face === 'back') return { ...mh, marks: fk === 'C' ? [] : [] };
    return { ...mh, marks: [...mh.marks, ...sigilMarks(fk, p, st.state ?? 'neutral', mask, yaw)] };
  };
  if (fk === 'P') {
    c.back = () => '';
    c.armGear = (ctx, sk) => pWraps(ctx, sk);
    c.over = (ctx, sk, st, cfg) => {
      const { pal } = ctx; let o = '';
      if (st.face === 'front') {
        o += ctx.poly([LF(sk, -5.8, 9.6), LF(sk, 5.8, 9.6), LF(sk, 5.0, -2.4), LF(sk, -5.0, -2.4)], pal.base.light, { sw: 1.1 });
        o += ctx.poly([LF(sk, -6.6, 4.6), LF(sk, 6.0, 4.6), LF(sk, 5.8, 9.8), LF(sk, -6.8, 9.8)], pal.gear.mid, { sw: 1.2 });
        o += ctx.poly(V2(circ([LF(sk, 0, 7.2).x, LF(sk, 0, 7.2).y], 2.3, 12)), pal.gear.light, { sw: 1.1 });
        o += ctx.line([LF(sk, -4.2, 28.2), LF(sk, 0, 22.6), LF(sk, 4.2, 28.2)], pal.gear.shadow, 1.4);
      } else if (st.face === 'back') {
        o += ctx.poly([LB(sk, -5.8, 9.6), LB(sk, 5.8, 9.6), LB(sk, 5.0, -2.4), LB(sk, -5.0, -2.4)], pal.base.light, { sw: 1.1 });
        o += ctx.poly([LB(sk, -6.6, 4.6), LB(sk, 6.0, 4.6), LB(sk, 5.8, 9.8), LB(sk, -6.8, 9.8)], pal.gear.mid, { sw: 1.2 });
        o += ctx.poly(limb(LB(sk, -1.2, 6.6), LB(sk, -2.8, -8), 3.4, 3.0, 1.0), pal.gear.shadow, { sw: 1 });
        o += ctx.poly(limb(LB(sk, 1.2, 6.6), LB(sk, 3.4, -6.4), 3.4, 3.0, 1.0), pal.gear.shadow, { sw: 1 });
        const k = LB(sk, 0, 8);
        o += ctx.poly(V2(circ([k.x, k.y], 4.4, 14)), pal.gear.mid, { sw: 1.3 });
        o += ctx.shade(V2(circ([k.x, k.y], 4.4, 14).filter(([x]) => x <= k.x + 0.2).concat([[k.x, k.y - 4.4]])), pal.gear.shadow);
      } else {
        // three-quarter and profile: the fighter's own features, with the back knot as one disc (no concentric rings)
        const o0 = BASE.over(ctx, sk, st, cfg), i = o0.lastIndexOf('<polygon');
        o += i > 0 ? o0.slice(0, i) : o0;
      }
      return o;
    };
    c.hair = (ctx, sk, st) => {
      const { pal } = ctx, H = a => a.map(([x, y]) => sk.Hd(x, y));
      if (st.face === 'back') {
        const bh = BASE.blankHead(pal), hc = sk.Hd(0, 9), u = sk.b.hs;
        const pts = scl(H(bh.poly).map(p => [p.x, p.y]), 1.06, [hc.x, hc.y]).map(([x, y]) => V(x, y));
        let s = ctx.poly(pts, pal.hair.mid);
        const p0 = sk.Hd(0, 2);
        s += ctx.poly(band([[p0.x, p0.y + 3 * u], [p0.x + 0.2 * u, p0.y - 5 * u], [p0.x - 0.6 * u, p0.y - 12 * u]], t => (7.4 - 3.4 * t) * u).map(([x, y]) => V(x, y)), pal.hair.mid);
        s += ctx.shade(band([[p0.x - 1.2 * u, p0.y + 1 * u], [p0.x - 1.4 * u, p0.y - 9 * u]], 1.3 * u).map(([x, y]) => V(x, y)), pal.hair.light);
        return s;
      }
      // the fringe sits high so the temple ring shows
      return ctx.poly(H([[5.8, 16.2], [4.4, 18.3], [0.6, 19.8], [-4.4, 18.4], [-8.4, 14.8], [-12.4, 11.6], [-14, 8.4], [-12, 6.4], [-8.4, 8.2], [-5.8, 6.8], [-5.8, 12.6], [-3.4, 15.6], [1, 16.4]]), pal.hair.mid);
    };
  }
  if (fk === 'E') {
    const mantle = (ctx, sk, a, top) => {
      const { pal } = ctx; let o = '';
      const L = LAT(sk, -8.2, top, a), R = LAT(sk, 8.2, top, a), hl = LAT(sk, -17, -32, a), hr = LAT(sk, 17, -32, a);
      o += ctx.poly([L, R, hr, hl], pal.base.mid, { sw: 1.2 });
      o += ctx.shade([lerp(L, hl, 0.5), lerp(R, hr, 0.5), hr, hl], pal.base.shadow);
      o += ctx.poly([L, R, lerp(R, hr, 0.34), lerp(L, hl, 0.34)], pal.accent.mid, { line: false, op: 0.9 });
      o += ctx.line([lerp(L, R, 0.5), lerp(hl, hr, 0.5)], pal.base.shadow, 1.3);
      o += blades(ctx, hl, hr, 9, 6.4, [pal.gear.mid, pal.gear.light]);
      return o;
    };
    const wings = (ctx, sk, a) => {
      const { pal } = ctx; let o = '';
      for (const sg of [-1, 1]) o += ctx.poly([LAT(sk, sg * 3.2, 30.5, a), LAT(sk, sg * 8.0, 37.2, a), LAT(sk, sg * 13.6, 33.4, a), LAT(sk, sg * 10.4, 27.4, a)], pal.base.mid, { sw: 1.1 }) + ctx.line([LAT(sk, sg * 3.6, 31, a), LAT(sk, sg * 8.0, 36.8, a), LAT(sk, sg * 13.2, 33.6, a)], pal.accent.mid, 1.5);
      return o;
    };
    c.back = (ctx, sk, st, cfg) => (st.face === 'front' ? mantle(ctx, sk, -6.4, 28.4) + wings(ctx, sk, -6.4) : st.face === 'back' ? '' : BASE.back(ctx, sk, st, cfg));
    c.over = (ctx, sk, st, cfg) => {
      const { pal } = ctx; let o = '';
      if (st.face === 'front') {
        o += ctx.poly([LF(sk, -6.4, 27.6), LF(sk, 6.4, 27.6), LF(sk, 6.8, 9), LF(sk, -6.8, 9)], pal.base.light, { sw: 1.2 });
        o += ctx.poly([LF(sk, -2.8, 8.6), LF(sk, 2.8, 8.6), LF(sk, 3.6, -27), LF(sk, -3.6, -27)], pal.base.light, { sw: 1.1 });
        o += ctx.line([LF(sk, -3.6, -27), LF(sk, 3.6, -27)], pal.gear.mid, 1.6);
        o += ctx.poly([LF(sk, -6.6, 7.6), LF(sk, 6.6, 7.6), LF(sk, 6.4, 11), LF(sk, -6.6, 11)], pal.gear.mid, { sw: 1.1 });
        for (const sg of [-1, 1]) o += ctx.poly([LF(sk, sg * 5.8, 27.6), LF(sk, sg * 7.4, 27.6), LF(sk, sg * 7.0, 20), LF(sk, sg * 5.4, 20)], pal.accent.mid, { sw: 1 });
      } else if (st.face === 'back') {
        o += mantle(ctx, sk, -6.6, 28.4) + wings(ctx, sk, -6.6);
      } else o += BASE.over(ctx, sk, st, cfg);
      return o;
    };
    c.hair = (ctx, sk, st) => {
      const { pal } = ctx;
      if (st.face === 'back') {
        const bh = BASE.blankHead(pal), H = a => a.map(([x, y]) => sk.Hd(x, y)), hc = sk.Hd(0, 10);
        let s = ctx.poly(scl(H(bh.poly).map(p => [p.x, p.y]), 1.04, [hc.x, hc.y]).map(([x, y]) => V(x, y)), pal.hair.mid);
        const k = sk.Hd(0, 21.4);
        return s + ctx.poly(V2(circ([k.x, k.y], 3.8 * sk.b.hs, 10)), pal.hair.mid);
      }
      return BASE.hair(ctx, sk, st);
    };
  }
  if (fk === 'C') {
    c.back = (ctx, sk, st, cfg) => (st.face ? '' : BASE.back(ctx, sk, st, cfg));
    c.over = (ctx, sk, st, cfg) => {
      const { pal } = ctx; let o = '';
      if (st.face === 'front') {
        // the mail apron, the rail, the chest and hip hatches, the shoulder cables
        const hem = []; for (let i = 0; i <= 7; i++) hem.push(LF(sk, 5.8 - i * (11.6 / 7), -8 - (i % 2 ? 2.4 : 0)));
        o += ctx.poly([LF(sk, -5.8, 7), LF(sk, 5.8, 7), ...hem], pal.gear.shadow, { sw: 1.1 });
        if (!ctx.flat) o += ctx.poly([LF(sk, -5.8, 7), LF(sk, 5.8, 7), LF(sk, 5.6, -8), LF(sk, -5.6, -8)], 'url(#mail)', { line: false, op: 0.7 });
        o += ctx.poly([LF(sk, -6.4, 27), LF(sk, 6.4, 27), LF(sk, 6.6, 8), LF(sk, -6.6, 8)], pal.base.light, { sw: 1.2 });
        if (!ctx.flat) o += ctx.poly([LF(sk, -6.4, 27), LF(sk, 6.4, 27), LF(sk, 6.6, 8), LF(sk, -6.6, 8)], 'url(#mail)', { line: false, op: 0.5 });
        o += ctx.poly([LF(sk, -1.3, 28.4), LF(sk, 1.3, 28.4), LF(sk, 1.3, 8), LF(sk, -1.3, 8)], pal.gear.mid, { sw: 1 });
        o += ctx.poly([LF(sk, -3.6, 25), LF(sk, 3.6, 25), LF(sk, 3.6, 19.6), LF(sk, -3.6, 19.6)], pal.base.shadow, { sw: 1.3 });
        o += ctx.poly([LF(sk, -1.2, 23.6), LF(sk, 1.2, 23.6), LF(sk, 1.2, 21), LF(sk, -1.2, 21)], pal.accent.light, { sw: 0.9 });
        o += ctx.poly([LF(sk, -3.6, 13), LF(sk, 3.6, 13), LF(sk, 3.6, 9.6), LF(sk, -3.6, 9.6)], pal.base.shadow, { sw: 1.2 });
        if (!ctx.flat) for (const sg of [-1, 1]) o += ctx.line([LF(sk, sg * 7.2, 28), LF(sk, sg * 4.6, 31), LF(sk, sg * 2.2, 27)], pal.base.shadow, 3.4) + ctx.line([LF(sk, sg * 7.2, 28), LF(sk, sg * 4.6, 31), LF(sk, sg * 2.2, 27)], pal.accent.mid, 1.1);
      } else if (st.face === 'back') {
        o += ctx.poly([LB(sk, -6.6, 27.6), LB(sk, 6.6, 27.6), LB(sk, 6.6, 9), LB(sk, -6.6, 9)], pal.base.light, { sw: 1.4 }) + ctx.poly([LB(sk, -6.6, 27.6), LB(sk, 6.6, 27.6), LB(sk, 6.6, 25.4), LB(sk, -6.6, 25.4)], pal.gear.shadow, { sw: 1.1 });
        for (let i = 0; i < 4; i++) o += ctx.poly([LB(sk, -5.4, 25 - i * 3.6), LB(sk, -2.2, 25 - i * 3.6), LB(sk, -2.2, 23.6 - i * 3.6), LB(sk, -5.4, 23.6 - i * 3.6)], pal.accent.mid, { sw: 0.8 });
        o += ctx.poly([LB(sk, 0.4, 24), LB(sk, 5.4, 24), LB(sk, 5.4, 17.6), LB(sk, 0.4, 17.6)], pal.gear.mid, { sw: 1.2 });
        o += ctx.poly([LB(sk, 1.4, 22.6), LB(sk, 4.4, 22.6), LB(sk, 4.4, 19), LB(sk, 1.4, 19)], pal.base.shadow, { sw: 1 });
        o += ctx.poly([LB(sk, -6.4, 8.4), LB(sk, 6.4, 8.4), LB(sk, 6.2, 4.6), LB(sk, -6.2, 4.6)], pal.gear.shadow, { sw: 1.1 });
        if (!ctx.flat) for (const sg of [-1, 1]) o += ctx.line([LB(sk, sg * 5.6, 27.6), LB(sk, sg * 7.8, 31), LB(sk, sg * 7.6, 24)], pal.base.shadow, 3.4) + ctx.line([LB(sk, sg * 5.6, 27.6), LB(sk, sg * 7.8, 31), LB(sk, sg * 7.6, 24)], pal.accent.mid, 1.1);
      } else o += BASE.over(ctx, sk, st, cfg);
      return o;
    };
  }
  return c;
}
const CONCEPTS = { P: tConcept('P'), E: tConcept('E'), C: tConcept('C') };
const DEFS = `<defs>
<pattern id="mail" width="3.2" height="3.2" patternUnits="userSpaceOnUse"><circle cx="1.6" cy="1.6" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/><circle cx="0" cy="0" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/><circle cx="3.2" cy="3.2" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/></pattern>
</defs>`;

// ---------------------------------------------------------------------------------------------------------- drawing
function draw(fk, px, x, ground, pose, { yaw = 32, face = null, back = false, flip = false, state = 'neutral', wear = 0, flat = false, spread = false } = {}) {
  const s = px / 100, pal = PAL[fk], ctx = makeCtx({ flat, pal, swMul: px < 9 ? 0 : px < 28 ? 0.6 : px < 80 ? 1 : 1.3, faceless: true });
  const sway = FIGHTERS[fk].sway ?? 6;
  const st = { yaw, face, state, forms: 6, wear, sway, expression: 'neutral', open: state === 'rage' ? 1 : 0, hairLoose: state === 'rage' || state === 'hurt' };
  const view = { yaw, back, armSpread: spread ? 7 : 0, legSpread: spread ? 3 : 0 };
  const { svg, sk } = figure(ctx, CONCEPTS[fk], pose, st, view);
  const fl = flip ? ` transform="translate(${F(x)} 0) scale(-1 1) translate(${F(-x)} 0)"` : '';
  return { svg: `<g${fl}><g transform="translate(${F(x)} ${F(ground)}) scale(${F(s)} ${F(-s)})">${svg}</g></g>`, sk, s };
}
function head(fk, state, x, y, size, opts = {}) {
  const pose = opts.pose ?? NEUTRAL_UP, s = (opts.px ?? 480) / 100, pal = PAL[fk];
  const ctx = makeCtx({ flat: false, pal, swMul: 1, faceless: true });
  const yaw = opts.yaw ?? 32, face = opts.face ?? null, sway = FIGHTERS[fk].sway ?? 6;
  const st = { yaw, face, state, forms: 6, wear: 0, sway, expression: 'neutral', open: state === 'rage' ? 1 : 0, hairLoose: state === 'rage' || state === 'hurt' };
  const { svg, sk } = figure(ctx, CONCEPTS[fk], pose, st, { yaw, back: !!opts.back, armSpread: opts.back || face === 'front' ? 7 : 0, legSpread: 0 });
  const h = fk === 'E' ? sk.Hd(1.6, 12.6) : sk.Hd(3.2, 9.4);
  return `<svg x="${F(x)}" y="${F(y)}" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" overflow="hidden">${rect(0, 0, size, size, '#f3f0f8')}<g transform="translate(${F(size / 2 - h.x * s)} ${F(size / 2 + h.y * s - 36)}) scale(${F(s)} ${F(-s)})">${svg}</g></svg>` + rect(x, y, size, size, 'none', 'stroke="#1b1428" stroke-opacity="0.35"');
}

// ---------------------------------------------------------------------------------------------------------- the three sheets
const SHEETS = {
  P: {
    file: 'protagonist-turnaround.svg', title: 'Protagonist: turnaround',
    sub: 'Front, three-quarter right, three-quarter left, back. Pale designed dome with an open temple arc, swept-back teal hair, dark tunic, light belt and knot. Working labels, placeholder design, pending Legal review.',
    poseLabel: 'The pose in play (forward-leaning, open)', pose: FIGHTERS.P.poses.base,
    notes: [
      'Build: round, open, forward-leaning. Torso 1.0 of the standard height and 1.1 wide, legs 1.0, arms 1.05, head 1.08.',
      'Staging: three-quarter in play, mirrored when the fighter faces left, so the left view is the right view mirrored. The front and back are for modelling and are not staged in play.',
      'The value rule: dark tunic, light gear and mask. Tunic #1a3d46, gear #c4ece6, mask #e8f1ee, hair #3fae9c, accent #4fb9a8. Hair never changes colour.',
      'The mask is a designed dome: a faceted crown, a brow ridge, a jaw plane and a crown seam. No eye or mouth slots or dots. The sigil is a single open arc (a \"C\" with a gap facing forward), off-centre at the temple above the brow ridge: never a closed ring, no dot, never with the slash. Hurt widens the gap.',
      'Front features (belt, buckle, collar trim, sash apron) sit on the front surface. Back features (knot, sash tails, apron) sit on the back surface. The back knot is one disc: no concentric rings.',
      'Legal conditions kept: the hair is a swept-back cap, never spiky or upswept, and never gold; no red or gold glow; the heat (Hot Blood) is steam and veins on the body, never a body aura.',
    ],
    parts: [['Mask (head)', 'A designed dome with brow ridge, jaw plane and crown seam. A sigil decal slot (an open arc, off-centre). No face rig.', 180], ['Hair', 'A swept-back cap and a rounded tuft on a 3-bone spring chain. Never changes colour or shape.', 80], ['Neck and torso', 'A sleeveless dark tunic with a light collar trim.', 320], ['Belt, knot and sash tails', 'A wide light belt, a solid disc knot at the back and two sash tails on a 2-bone spring chain each.', 110], ['Sash apron', 'A light cloth panel to the hip, front and back.', 60], ['Arms, two', 'Bare upper arm and forearm each.', 240], ['Forearm wraps, three', 'Tone-on-tone wraps with a diagonal edge on the near forearm, toggled by stage. Not contrasting wristbands.', 90], ['Hands, two', 'Wrapped fists. Open variants for taunt and guard.', 140], ['Legs, two', 'Thigh and shin each.', 240], ['Boots, two', 'Dark, with a light cuff.', 140]],
    rig: 'Bones, about 26: root, pelvis, two spine, neck, head, three hair tuft (spring), two sash tails of two (spring), two shoulders, upper arms, forearms, hands, thighs, shins, feet. Palette masks: red channel tunic, green gear, blue accent, alpha the emissive sigil (the arc). Wear is five floats (head, core, arms, legs, crown). Steam and veins are separate decals and particles.',
    swatches: [['tunic', PAL.P.base.mid], ['gear', PAL.P.gear.mid], ['accent', PAL.P.accent.mid], ['mask', MASK.P.fill], ['skin', PAL.P.skin.mid], ['hair', PAL.P.hair.mid]],
  },
  E: {
    file: 'empress-turnaround.svg', title: 'Empress: turnaround',
    sub: 'Front, three-quarter right, three-quarter left, back. Pale bone mask with three offset chevrons, dark olive tunic, a bladed mantle worn as a cape-train, a low collar flare. Working labels, placeholder design, pending Legal review.',
    poseLabel: 'The pose in play (upright, sweeping)', pose: FIGHTERS.E.poses.base,
    notes: [
      'Build: wide, sweeping, upright. Torso 0.95 wide and 1.08 tall, legs 1.08, arms 1.02, head 0.98. Taller than the others by a topknot.',
      'Staging: three-quarter in play, mirrored when the fighter faces left. The mantle trails behind, so the front stays clear. The front and back are for modelling and are not staged in play.',
      'The value rule: dark olive body, light gear and mask. Tunic #2a2f1e, gear #e0deb8, mask #e6e0c4, accent #b8c96a. No horns, no purple, not pale overall.',
      'The mantle is a stiff cape-train with a hem of eight to nine blades and an accent band across the shoulders. It is a cloth sim on two spring chains of three. It is not a flame or hair shape.',
      'The mask is a polished bone shape. The sigil is three chevrons of different sizes, offset, in moss: an odd count, never a tidy double chevron, never in a car or oil brand\'s colours.',
      'Front features (tunic panel, tabard, belt, bracers) sit on the front surface. Back features (mantle, collar flare) sit on the back surface. Her flashes are a wide, low crest behind the head, so nothing tall stands above the topknot.',
      'The guard of honour is a separate retinue figure, not a fighter (see the small row): one shared model with a tabard and a helm, and no sigil.',
    ],
    parts: [['Mask and topknot', 'A polished bone mask with a chevron decal slot, and a topknot ball on the hair. No face rig.', 200], ['Headband', 'A light band across the brow, over the hair line.', 30], ['Hair', 'A cap over the skull, tucked. The topknot is a ball on a 1-bone spring.', 60], ['Neck and torso', 'A dark olive tunic with a high collar.', 300], ['Tabard and belt', 'A long light tabard to the shin and a wide belt.', 90], ['Mantle (cape-train)', 'A stiff cloth panel on two spring chains of three, with an accent band across the shoulders.', 200], ['Hem blades, nine', 'Sharp shapes along the trailing hem, alternate two shades. Rigid, parented to the mantle.', 90], ['Collar flare', 'Two low stiff flares at shoulder height, below the eye line, rigid on the upper spine. They never rise beside the head, so they never read as horns.', 50], ['Arms, two', 'Sleeved upper arm and forearm each.', 240], ['Bracer and hands', 'An accent bracer on the near forearm, open and closed hands.', 180], ['Legs and boots', 'Long legs (1.08) and boots with a light cuff.', 400]],
    rig: 'Bones, about 30: root, pelvis, two spine, neck, head, topknot, six mantle (two chains of three, spring), two shoulders, upper arms, forearms, hands, thighs, shins, feet. Palette masks: red channel body, green gear, blue accent, alpha the emissive sigil (the chevrons). Wear is five floats (head, core, arms, legs, crown). The mantle has an intact and a torn variant.',
    swatches: [['body', PAL.E.base.mid], ['gear', PAL.E.gear.mid], ['accent', PAL.E.accent.mid], ['mask', MASK.E.fill], ['skin', PAL.E.skin.mid], ['hair', PAL.E.hair.mid]],
  },
  C: {
    file: 'cyborg-turnaround.svg', title: 'Cyborg: turnaround',
    sub: 'Front, three-quarter right, three-quarter left, back. Dark display face with a stair of lit squares, dark red plating and chain-mail, a rail down the chest with four hatches, a squared backpack unit and looping cables. Working labels, placeholder design, pending Legal review.',
    poseLabel: 'The pose in play (heavy, planted)', pose: FIGHTERS.C.poses.base,
    notes: [
      'Build: heavy and blocky. Torso 1.36 wide, legs 0.95, arms 1.02 with 1.38 wide limbs, head 1.12 (a boxy head).',
      'Staging: three-quarter in play, mirrored when the fighter faces left. The front and back are for modelling and are not staged in play.',
      'The value rule: dark red plating, light gear and mail. Plating #3a161c, gear #cfc7cb, mask #34313d, accent #d8705f. No black-and-red look: the plating is dark red, the mask is a cool dark grey, the sigil is soft coral.',
      'The mask is a dark display face. The sigil is a stair of four lit squares of growing size on a diagonal: never a line grid, never a cross or plus, never a 2 by 2 block. Hurt and brink drop a step.',
      'Four hatches: head (a bar on the mask), chest (open, the chip shows there), back (behind the backpack) and hip. The rail runs down the chest between them.',
      'Front features (rail, chest and hip hatches, mail apron, shoulder cables) sit on the front surface. Back features (backpack unit with four vents, back hatch, belt) sit on the back surface.',
      'The mail is a tiled pattern in the shader (a normal-map look), not geometry. The cables are two spring chains. Its flashes are steel for information and coral for emotion.',
    ],
    parts: [['Mask (head)', 'A boxy head with a display face. A sigil decal slot (a stair of squares) and a head hatch bar.', 140], ['Neck and torso', 'Heavy plating over a dark under-suit.', 380], ['Chain-mail apron', 'A mail apron to the thigh with a zig hem. The mail is a tiled shader pattern.', 80], ['Rail and four hatches', 'A rail down the chest, chest and hip hatches on the front, a back hatch, the head hatch bar.', 120], ['Backpack unit', 'A squared unit with four vents and a back hatch.', 220], ['Cables, two', 'Two looping cables from the pack over the shoulders to the rail and hip, on spring chains.', 100], ['Arms, two', 'Heavy mail upper arm and plated forearm each.', 300], ['Shoulder plates', 'Two plates, rigid on the shoulders.', 60], ['Hands, two', 'Heavy closed fists.', 160], ['Legs, two', 'Thigh and shin each, short (0.95).', 260], ['Boots, two', 'Heavy dark boots with a light cuff.', 160]],
    rig: 'Bones, about 26: root, pelvis, two spine, neck, head, backpack, four cable (two chains of two, spring), two shoulders, upper arms, forearms, hands, thighs, shins, feet. Palette masks: red channel plating, green gear, blue accent, alpha the emissive sigil (the squares). Wear is five floats (head, core, arms, legs, crown). The chest hatch has a closed and an open variant with the chip.',
    swatches: [['plating', PAL.C.base.mid], ['gear', PAL.C.gear.mid], ['accent', PAL.C.accent.mid], ['mask', MASK.C.fill], ['skin', PAL.C.skin.mid], ['hair', PAL.C.hair.mid]],
  },
};

function sheet(fk) {
  const S = SHEETS[fk], W = 1800, H = 1990;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, S.title, { size: 34, weight: 700, fill: '#f4f0fa' });
  b += paras(30, 76, S.sub, 220, 14, 17, { fill: '#cfc6e6' });
  // row 1: the four neutral views with guides
  const g1 = 660, px = 470, s = px / 100;
  b += rect(24, 124, W - 48, 580, '#e8e5ee', 'stroke="#1b1428" stroke-opacity="0.2"');
  const views = [['Front', { yaw: 90, face: 'front', spread: true }, 250], ['Three-quarter right', { yaw: 32 }, 640], ['Three-quarter left (the mirror)', { yaw: 32, flip: true }, 1030], ['Back', { yaw: 90, face: 'back', back: true, spread: true }, 1420]];
  let ref = null;
  views.forEach(([cap, o, x]) => {
    const d = draw(fk, px, x, g1, NEUTRAL_UP, o);
    if (cap === 'Front') ref = d.sk;
    b += d.svg + text(x, g1 + 28, cap, { size: 14, weight: 600, anchor: 'middle' });
  });
  const guide = (yv, label) => { const y = g1 - yv * s; return `<line x1="24" y1="${F(y)}" x2="${W - 24}" y2="${F(y)}" stroke="#1b1428" stroke-opacity="0.22" stroke-dasharray="6 5"/>` + text(30, y - 4, label, { size: 10.5, op: 0.7 }); };
  const topY = ref.Hd(0, fk === 'E' ? 21 : 17.4).y, chinY = ref.Hd(0, 0.6).y;
  b += guide(topY, 'top of the head') + guide(chinY, 'chin') + guide(ref.S.y, 'shoulders') + guide(ref.T(0, 20).y, 'chest') + guide(ref.T(0, 9).y, 'waist') + guide(ref.P.y, 'hip') + guide(ref.nearLeg.K.y, 'knee') + guide(0, 'ground');
  const headH = topY - chinY, heads = topY / headH;
  b += text(1776, 150, `Body ${topY.toFixed(0)} units to the top of the head, head ${headH.toFixed(1)} units: about ${heads.toFixed(1)} heads tall`, { size: 12, weight: 600, anchor: 'end', op: 0.85 });
  // row 2: the pose in play
  b += rect(24, 720, 1150, 400, '#e8e5ee', 'stroke="#1b1428" stroke-opacity="0.2"');
  b += text(38, 744, S.poseLabel, { size: 14, weight: 700 });
  const pp = fk === 'E' ? 250 : 300, px3 = fk === 'E' ? [200, 590, 1000] : [230, 620, 990];
  [['Three-quarter right', { yaw: 32 }, px3[0]], ['Three-quarter left', { yaw: 32, flip: true }, px3[1]], ['Profile', { yaw: 0 }, px3[2]]].forEach(([cap, o, x]) => {
    const d = draw(fk, pp, x, 1080, S.pose, o);
    b += d.svg + text(x, 1104, cap, { size: 13, weight: 600, anchor: 'middle' });
  });
  b += text(1198, 744, 'Notes for the modeller', { size: 16, weight: 700 });
  let ny = 766; S.notes.forEach(t => { const ls = wrap(t, 84); b += paras(1198, ny, t, 84, 12, 16); ny += ls.length * 16 + 8; });
  // row 3: read sizes and wear
  b += text(24, 1140, 'Read at play sizes: 80, 40, 24 and 12 px, in full colour and as a silhouette', { size: 14, weight: 700 });
  b += rect(24, 1150, 590, 232, '#cfe6f0', 'stroke="#1b1428" stroke-opacity="0.2"');
  [[80, 70, 0], [40, 150, 0], [24, 210, 0], [12, 250, 0]].forEach(([p, dx]) => { b += draw(fk, p, 24 + dx, 1360, NEUTRAL_UP, { yaw: 32 }).svg; });
  [[80, 340], [40, 420], [24, 480], [12, 520]].forEach(([p, dx]) => { b += draw(fk, p, 24 + dx, 1360, NEUTRAL_UP, { yaw: 32, flat: true }).svg; });
  b += text(30, 1170, 'colour', { size: 11, op: 0.7 }) + text(340, 1170, 'silhouette', { size: 11, op: 0.7 });
  b += text(24, 1410, 'Wear: fresh, bruised, battered, broken (three-quarter, upright)', { size: 14, weight: 700 });
  [['Fresh', 0], ['Bruised', 1], ['Battered', 2], ['Broken', 3]].forEach(([cap, w], i) => {
    const x = 90 + i * 150;
    b += rect(x - 70, 1420, 140, 232, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"') + draw(fk, fk === 'E' ? 150 : 190, x, 1636, NEUTRAL_UP, { yaw: 32, wear: w }).svg + text(x, 1646, cap, { size: 12, weight: 700, anchor: 'middle' });
  });
  // mask close-ups
  b += text(960, 1140, 'The mask: neutral, taunt, hurt, rage, triumph (three-quarter), and the back of the head', { size: 14, weight: 700 });
  [['neutral', {}], ['taunt', {}], ['hurt', {}], ['rage', {}], ['triumph', {}], ['back', { yaw: 90, face: 'back', back: true }]].forEach(([cap, o], i) => {
    const x = 960 + (i % 3) * 272, y = 1152 + Math.floor(i / 3) * 250;
    b += head(fk, cap === 'back' ? 'neutral' : cap, x, y, 260, { ...o, px: fk === 'E' ? 420 : 480 }) + text(x + 6, y + 18, cap, { size: 12, op: 0.8 });
  });
  // part list and palette
  const y0 = 1690, total = S.parts.reduce((a, p) => a + p[2], 0);
  b += text(24, y0, `Part list for the model (near LOD, about ${total.toLocaleString('en-US')} triangles against the 2,500 budget)`, { size: 16, weight: 700 });
  S.parts.forEach(([n, t, tri], i) => {
    const y = y0 + 22 + i * 24;
    b += `<line x1="24" y1="${y - 14}" x2="1150" y2="${y - 14}" stroke="#1b1428" stroke-opacity="0.12"/>` + text(24, y, n, { size: 12, weight: 700 }) + text(200, y, t.length > 165 ? t.slice(0, 163) + '..' : t, { size: 11.5 }) + text(1140, y, `${tri}`, { size: 12, anchor: 'end' });
  });
  b += text(1198, y0, 'Palette and rig', { size: 16, weight: 700 });
  S.swatches.forEach(([n, c], i) => {
    const x = 1198 + i * 96;
    b += rect(x, y0 + 12, 88, 34, c, 'stroke="#1b1428" stroke-opacity="0.3"') + text(x + 44, y0 + 60, `${n} ${c}`, { size: 10, anchor: 'middle', op: 0.85 });
  });
  b += paras(1198, y0 + 90, S.rig, 92, 12, 16);
  if (fk === 'E') {
    // the guard of honour, the retinue figure: three-quarter right and left, no sigil
    b += text(640, 1410, 'The guard of honour (retinue, not a fighter)', { size: 14, weight: 700 });
    b += rect(640, 1420, 300, 232, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"');
    [[730, false], [860, true]].forEach(([x, flip]) => {
      const gs = 150 / 100, ctx = makeCtx({ flat: false, pal: PALETTES.g, swMul: 1 }), { svg } = figure(ctx, GUARD, GUARD.poses.base, { yaw: 32, expression: 'neutral', sway: 6, forms: 6, wear: 0 }, { yaw: 32 });
      const fl = flip ? ` transform="translate(${F(x)} 0) scale(-1 1) translate(${F(-x)} 0)"` : '';
      b += `<g${fl}><g transform="translate(${F(x)} 1620) scale(${F(gs)} ${F(-gs)})">${svg}</g></g>`;
    });
    b += paras(646, 1640, 'One shared model: a tabard, a helm and a tall staff, and no sigil.', 60, 10.5, 13, { op: 0.8 });
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

const origin = f => `<!-- Origin: procedural turnaround sheet written by art/concepts/turnaround/gen-fighters.mjs (deterministic, no external images or fonts), Art Director session (Claude, claude-sonnet-5-5), 2026-09-29; prompt record art/prompts/ART-0008-fighter-turnarounds.md -->` + String.fromCharCode(10);
for (const fk of ['P', 'E', 'C']) writeFileSync(join(OUT, SHEETS[fk].file), origin() + sheet(fk));
console.log('wrote protagonist-turnaround.svg, empress-turnaround.svg, cyborg-turnaround.svg');
