// Origin: procedural generator for the Anti-hero (the Coil) turnaround sheet (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-09-29. Human direction: Orb, via the EP.
// Run from the repo root:  node art/concepts/turnaround/gen.mjs   (writes coil-turnaround.svg)
// Views: front, three-quarter right, three-quarter left (the mirror), back, plus the crouch, forms, wear, mask close-ups and a part list.

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeCtx, figure, limb, V, add, rotCW } from '../anti-hero/kit.mjs';
import { FIGHTERS, PALETTES as BASE_PALETTES } from '../directions/fighters.mjs';

const OUT = dirname(fileURLToPath(import.meta.url));
const F = n => n.toFixed(2);
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family=\"'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif\"";
const text = (x, y, t, { size = 14, weight = 400, fill = '#1b1428', anchor = 'start', op = 1 } = {}) =>
  `<text x="${F(x)}" y="${F(y)}" ${FONT} font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}" opacity="${op}">${esc(t)}</text>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fill}" ${extra}/>`;
const wrap = (t, n) => { const w = t.split(' '), out = []; let line = ''; for (const x of w) { if ((line + ' ' + x).trim().length > n) { out.push(line.trim()); line = x; } else line += ' ' + x; } if (line.trim()) out.push(line.trim()); return out; };
const paras = (x, y, t, n, size = 13, gap = 17, o = {}) => wrap(t, n).map((l, i) => text(x, y + i * gap, l, { size, ...o })).join('');

// ---------------------------------------------------------------------------------------------------------- the Coil
const PAL = { ...BASE_PALETTES.A, accent: { light: '#c2adf0', mid: '#9a80d8', shadow: '#5b479a' } };
const MASK = { fill: '#2b2444', shadow: '#1a1530' };
const BASE = FIGHTERS.A;
const NEUTRAL_UP = { lean: 0, head: 0, nearArm: [10, 8], farArm: [-10, -8], nearLeg: [3, 1], farLeg: [-3, -1], handNear: 'fist', handFar: 'fist' };
const CROUCH = BASE.poses.base;

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
const V2 = arr => arr.map(([x, y]) => V(x, y));
const circ = (c, r, n = 14) => Array.from({ length: n }, (_, i) => { const a = (i / n) * Math.PI * 2; return [c[0] + Math.cos(a) * r, c[1] + Math.sin(a) * r]; });

// the Anti-hero's sigil: a slash and a dot, lit (the mask is dark), bending with emotion
const FACEA = { x0: 1.4, x1: 6.4, ey: 9.8 };
const yawMap = yaw => { const xm = (FACEA.x0 + FACEA.x1) / 2, a = yaw * Math.PI / 180, c = Math.cos(a), s = Math.sin(a), m = s; return ([u, y]) => [(1 - m) * u + m * (c * 5.4 + s * 1.5 * (u - xm)), y]; };
function sigilMarks(state, pal) {
  const c = [(FACEA.x0 + FACEA.x1) / 2 + 0.2, FACEA.ey - 0.6], out = [];
  let k = 1, r = 0, dy = 0, col = pal.accent.light;
  if (state === 'taunt') { r = 18; dy = 0.9; } if (state === 'hurt') { k = 0.85; col = pal.accent.mid; } if (state === 'rage') k = 1.3; if (state === 'triumph') k = 1.12;
  const cc = [c[0], c[1] + dy];
  const parts = [[[-0.55, -5], [0.55, -5], [0.3, 5], [-0.3, 5]], circ([1.6, 3.8], 0.7, 8)];
  const place = pts => scl(rot(pts.map(([x, y]) => [c[0] + x, c[1] + y + dy]), r, cc), k, cc);
  for (const p of parts) out.push({ poly: scl(place(p), 1.5, cc), fill: pal.accent.light, op: 0.26, line: false });
  for (const p of parts) out.push({ poly: place(p), fill: col, line: false });
  if (state === 'hurt') out.push({ poly: band([[cc[0] - 1.6, cc[1] + 3.4], [cc[0] - 0.2, cc[1] + 0.4], [cc[0] + 0.6, cc[1] - 3.6]], 0.42), fill: '#1c1626', line: false });
  if (state === 'rage') for (let i = 0; i < 6; i++) out.push({ poly: rot([[cc[0] + 4.2, cc[1] - 0.5], [cc[0] + 6.6, cc[1]], [cc[0] + 4.2, cc[1] + 0.5]], -70 + i * 28, cc), fill: col, line: false });
  if (state === 'triumph') for (let i = 0; i < 7; i++) out.push({ poly: band([[cc[0] + 4.6, cc[1]], [cc[0] + 6.4, cc[1]]].map(p => rot([p], -80 + i * 26, cc)[0]), 0.5), fill: pal.accent.light, line: false });
  return out;
}

// lateral points on the front surface (a = 5.4) and the back surface (a = -5.8): b is sideways, y is height
const LAT = (sk, b, y, a) => add(sk.P, rotCW(V((sk.yaw.c * a - b * sk.yaw.s) * sk.b.tw, y * sk.b.tl), sk.lean));
const LF = (sk, b, y) => LAT(sk, b, y, 5.4);
const LB = (sk, b, y) => LAT(sk, b, y, -5.8);

const COIL_T = {
  ...BASE, id: 'A-T', name: 'Anti-hero (the Coil)',
  blankHead(p, st) {
    const bh = BASE.blankHead(p);
    let marks = [];
    if (st.face !== 'back') { const m = yawMap(st.yaw ?? 0); marks = sigilMarks(st.state ?? 'neutral', p).map(q => ({ ...q, poly: q.poly.map(m) })); }
    return { ...bh, fill: MASK.fill, shadow: MASK.shadow, neck: MASK.shadow, marks };
  },
  over(ctx, sk, st, cfg) {
    const { pal } = ctx, n = st.forms ?? 6, deg = sk.yaw.deg; let o = '';
    if (st.face === 'back') {
      for (let i = 0; i < n; i++) {
        const y = 27 - i * 4.3;
        o += ctx.poly([LB(sk, -3.6, y + 1.9), LB(sk, 3.6, y + 1.9), LB(sk, 4.2, y + 0.3), LB(sk, 3.6, y - 1.9), LB(sk, -3.6, y - 1.9), LB(sk, -4.2, y + 0.3)], i % 2 ? pal.gear.mid : pal.gear.light, { sw: 1.1 });
        o += ctx.shade([LB(sk, -3.6, y - 0.1), LB(sk, 3.6, y - 0.1), LB(sk, 3.6, y - 1.9), LB(sk, -3.6, y - 1.9)], pal.gear.shadow);
      }
      o += ctx.poly([LB(sk, -5.6, 4.6), LB(sk, 5.6, 4.6), LB(sk, 5.4, 8), LB(sk, -5.6, 8)], pal.gear.shadow, { sw: 1.1 });
      return o;
    }
    if (st.face === 'front') {
      o += ctx.poly([LF(sk, -5.6, 4.6), LF(sk, 5.6, 4.6), LF(sk, 5.4, 8), LF(sk, -5.6, 8)], pal.gear.shadow, { sw: 1.1 });
    } else {
      o += BASE.over(ctx, sk, st, cfg);
    }
    if (deg > 15) {
      const strap = (b0, y0, b1, y1) => ctx.poly(limb(LF(sk, b0, y0), LF(sk, b1, y1), 2.6, 2.6, 1.0), pal.gear.mid, { sw: 1.1 });
      o += strap(4.8, 27.6, -4.4, 12.4) + strap(-4.8, 27.6, 4.4, 12.4);
      const c0 = LF(sk, 0, 19.6);
      o += ctx.poly(V2(circ([c0.x, c0.y], 2.6, 10)), pal.gear.mid, { sw: 1.1 });
      const sl = [[-0.35, -1.7], [0.35, -1.7], [0.22, 1.7], [-0.22, 1.7]].map(([x, y]) => [c0.x + x, c0.y + y]);
      o += ctx.poly(V2(sl), pal.accent.mid, { sw: 0.6, line: false });
    }
    return o;
  },
  hair(ctx, sk, st) {
    const { pal } = ctx, H = a => a.map(([x, y]) => sk.Hd(x, y));
    if (st.face === 'back') {
      const bh = BASE.blankHead(pal), hc = sk.Hd(0, 9);
      const pts = scl(H(bh.poly).map(p => [p.x, p.y]), 1.05, [hc.x, hc.y]).map(([x, y]) => V(x, y));
      let s = ctx.poly(pts, pal.hair.mid);
      const p0 = sk.Hd(0, 1), u = sk.b.hs;
      s += ctx.poly(band([[p0.x, p0.y + 1.5 * u], [p0.x + 0.3 * u, p0.y - 12 * u], [p0.x, p0.y - 27 * u]], t => (5 - 2.6 * t) * u).map(([x, y]) => V(x, y)), pal.hair.mid);
      s += ctx.shade(band([[p0.x - 0.8 * u, p0.y - 1 * u], [p0.x - 0.6 * u, p0.y - 22 * u]], 1.1 * u).map(([x, y]) => V(x, y)), pal.hair.light);
      return s;
    }
    if (st.face === 'front') {
      return ctx.poly(H([[5.6, 12.9], [4.2, 15.9], [0.4, 17.4], [-4.2, 16.2], [-6.6, 12.8], [-6, 12], [-3.4, 13.4], [0.6, 14], [4, 13.4]]), pal.hair.mid);
    }
    return BASE.hair(ctx, sk, st);
  },
};

// ---------------------------------------------------------------------------------------------------------- drawing
const DEFS = '<defs></defs>';
function draw(px, x, ground, pose, { yaw = 32, face = null, back = false, flip = false, state = 'neutral', forms = 6, wear = 0, flat = false, spread = false } = {}) {
  const s = px / 100, ctx = makeCtx({ flat, pal: PAL, swMul: px < 80 ? 1 : 1.3, faceless: true });
  const st = { yaw, face, state, forms, wear, sway: BASE.sway ?? 12, expression: 'neutral', open: state === 'rage' ? 1 : 0, hairLoose: state === 'rage' || state === 'hurt' };
  const view = { yaw, back, armSpread: spread ? 7 : 0, legSpread: spread ? 3 : 0 };
  const { svg, sk } = figure(ctx, COIL_T, pose, st, view);
  const fl = flip ? ` transform="translate(${F(x)} 0) scale(-1 1) translate(${F(-x)} 0)"` : '';
  return { svg: `<g${fl}><g transform="translate(${F(x)} ${F(ground)}) scale(${F(s)} ${F(-s)})">${svg}</g></g>`, sk, s };
}
function head(state, x, y, size, opts = {}) {
  const pose = opts.pose ?? NEUTRAL_UP, s = (opts.px ?? 480) / 100;
  const ctx = makeCtx({ flat: false, pal: PAL, swMul: 1, faceless: true });
  const yaw = opts.yaw ?? 32, face = opts.face ?? null;
  const st = { yaw, face, state, forms: 6, wear: 0, sway: 12, expression: 'neutral', open: state === 'rage' ? 1 : 0, hairLoose: state === 'rage' || state === 'hurt' };
  const { svg, sk } = figure(ctx, COIL_T, pose, st, { yaw, back: !!opts.back, armSpread: opts.back || face === 'front' ? 7 : 0, legSpread: 0 });
  const h = sk.Hd(3.2, 9.4);
  return `<svg x="${F(x)}" y="${F(y)}" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" overflow="hidden">${rect(0, 0, size, size, '#f3f0f8')}<g transform="translate(${F(size / 2 - h.x * s)} ${F(size / 2 + h.y * s)}) scale(${F(s)} ${F(-s)})">${svg}</g></svg>` + rect(x, y, size, size, 'none', 'stroke="#1b1428" stroke-opacity="0.35"');
}

const PARTS = [
  ['Mask (head)', 'Blank wedge mask, dark obsidian. A sigil decal slot (an emissive slash and dot). No face rig.', 190],
  ['Hair', 'A cap over the skull and a short tied tail on a 3-bone spring chain. Never changes colour or shape with form.', 70],
  ['Neck and torso', 'A dark bodysuit. Compact: torso 0.87 of the standard height.', 330],
  ['Chest harness', 'Two crossing straps and a round buckle carrying the slash mark. Front only.', 70],
  ['Spine plates, six', 'Six rounded slabs down the spine, one per form (F1 nape to F6 hip). Rigid, parented to the spine bones. Each toggles by form and swaps to a cracked variant with core wear.', 150],
  ['Belt plate', 'A wide plate at the hip. Front and back.', 30],
  ['Arms, two', 'Upper arm and forearm each. From form 4 the near forearm takes two guards, from form 6 three.', 240],
  ['Forearm guards, three', 'Small rounded plates, toggled by form.', 90],
  ['Hands, two', 'Closed fists. Open variants for taunt and guard.', 140],
  ['Legs, two', 'Thigh and shin each, short (0.84 of standard).', 240],
  ['Boots, two', 'Dark, with a light cuff.', 140],
];

function sheet() {
  const W = 1800, H = 2010;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'Anti-hero (the Coil): turnaround', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'Front, three-quarter right, three-quarter left, back. Dark mask, lit slash sigil, six spine plates. Working labels, placeholder design, pending Legal review.', { size: 15, fill: '#cfc6e6' });
  // row 1: the four neutral views with guides
  const g1 = 660, px = 470, s = px / 100;
  b += rect(24, 124, W - 48, 580, '#e8e5ee', 'stroke="#1b1428" stroke-opacity="0.2"');
  const views = [['Front', { yaw: 90, face: 'front', spread: true }, 250], ['Three-quarter right', { yaw: 32 }, 640], ['Three-quarter left (the mirror)', { yaw: 32, flip: true }, 1030], ['Back', { yaw: 90, face: 'back', back: true, spread: true }, 1420]];
  let ref = null;
  views.forEach(([cap, o, x]) => {
    const d = draw(px, x, g1, NEUTRAL_UP, o);
    if (cap === 'Front') ref = d.sk;
    b += d.svg + text(x, g1 + 28, cap, { size: 14, weight: 600, anchor: 'middle' });
  });
  const guide = (yv, label) => { const y = g1 - yv * s; return `<line x1="24" y1="${F(y)}" x2="${W - 24}" y2="${F(y)}" stroke="#1b1428" stroke-opacity="0.22" stroke-dasharray="6 5"/>` + text(30, y - 4, label, { size: 10.5, op: 0.7 }); };
  const topY = ref.Hd(0, 17.4).y, chinY = ref.Hd(0, 0.6).y;
  b += guide(topY, 'top of the head') + guide(chinY, 'chin') + guide(ref.S.y, 'shoulders') + guide(ref.T(0, 20).y, 'chest') + guide(ref.T(0, 9).y, 'waist') + guide(ref.P.y, 'hip') + guide(ref.nearLeg.K.y, 'knee') + guide(0, 'ground');
  const headH = topY - chinY, heads = topY / headH;
  b += text(1776, 150, `Body ${topY.toFixed(0)} units to the top of the head, head ${headH.toFixed(1)} units: about ${heads.toFixed(1)} heads tall`, { size: 12, weight: 600, anchor: 'end', op: 0.85 });
  // row 2: the crouch
  b += rect(24, 720, 1150, 400, '#e8e5ee', 'stroke="#1b1428" stroke-opacity="0.2"');
  b += text(38, 744, 'The signature crouch (the Coil), the pose in play', { size: 14, weight: 700 });
  [['Three-quarter right', { yaw: 32 }, 230], ['Three-quarter left', { yaw: 32, flip: true }, 620], ['Profile', { yaw: 0 }, 990]].forEach(([cap, o, x]) => {
    const d = draw(300, x, 1080, CROUCH, o);
    b += d.svg + text(x, 1104, cap, { size: 13, weight: 600, anchor: 'middle' });
  });
  // notes
  b += text(1198, 744, 'Notes for the modeller', { size: 16, weight: 700 });
  const notes = [
    'Build: compact and coiled. Torso 0.87, legs 0.84, arms 0.95, head 1.06 of the standard figure, torso width 1.12.',
    'Staging: the game shows three-quarter, mirrored when the fighter faces left, so the left view is the right view mirrored. The front and back are for modelling and turnarounds and are not staged in play. In the crouch the front view is foreshortened, so it is left to the real model.',
    'The value rule: dark body, light gear. Body #2a2043, gear #cbd3e2, accent #9a80d8, mask #2b2444. Hair #1d1630 and never changes.',
    'Front features (harness, buckle, belt plate) sit on the front surface. Back features (spine plates, belt, tail) sit on the back surface. The sigil is the only face.',
    'Legal conditions kept: no shoulder pads with white gloves and boots, no flame or upswept hair, no hair-colour change, no gold or red glow, no cape.',
  ];
  let ny = 766; notes.forEach(t => { const ls = wrap(t, 84); b += paras(1198, ny, t, 84, 12, 16); ny += ls.length * 16 + 8; });
  // row 3: forms
  b += text(24, 1140, 'Forms F1 to F6: one spine plate per form (three-quarter, upright)', { size: 14, weight: 700 });
  for (let i = 1; i <= 6; i++) {
    const x = 90 + (i - 1) * 150, d = draw(190, x, 1366, NEUTRAL_UP, { yaw: 32, forms: i });
    b += rect(x - 70, 1150, 140, 232, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"') + d.svg + text(x, 1376, `F${i}`, { size: 12, weight: 700, anchor: 'middle' });
  }
  // wear
  b += text(24, 1410, 'Wear: fresh, bruised, battered, broken (three-quarter, upright)', { size: 14, weight: 700 });
  [['Fresh', 0], ['Bruised', 1], ['Battered', 2], ['Broken', 3]].forEach(([cap, w], i) => {
    const x = 90 + i * 150, d = draw(190, x, 1636, NEUTRAL_UP, { yaw: 32, wear: w });
    b += rect(x - 70, 1420, 140, 232, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"') + d.svg + text(x, 1646, cap, { size: 12, weight: 700, anchor: 'middle' });
  });
  // mask close-ups
  b += text(960, 1140, 'The mask: neutral, taunt, hurt, rage, triumph (three-quarter), and the back of the head', { size: 14, weight: 700 });
  [['neutral', {}], ['taunt', {}], ['hurt', {}], ['rage', {}], ['triumph', {}], ['back', { yaw: 90, face: 'back', back: true }]].forEach(([cap, o], i) => {
    const x = 960 + (i % 3) * 272, y = 1152 + Math.floor(i / 3) * 250;
    b += head(cap === 'back' ? 'neutral' : cap, x, y, 260, o) + text(x + 6, y + 18, cap, { size: 12, op: 0.8 });
  });
  // part list and palette
  const y0 = 1690;
  b += text(24, y0, 'Part list for the model (near LOD, about 1,700 triangles against the 2,500 budget)', { size: 16, weight: 700 });
  PARTS.forEach(([n, t, tri], i) => {
    const y = y0 + 22 + i * 26;
    b += `<line x1="24" y1="${y - 14}" x2="1150" y2="${y - 14}" stroke="#1b1428" stroke-opacity="0.12"/>` + text(24, y, n, { size: 12, weight: 700 }) + text(200, y, t.length > 165 ? t.slice(0, 163) + '..' : t, { size: 11.5 }) + text(1140, y, `${tri}`, { size: 12, anchor: 'end' });
  });
  b += text(1198, y0, 'Palette and rig', { size: 16, weight: 700 });
  [['body', PAL.base.mid], ['gear', PAL.gear.mid], ['accent', PAL.accent.mid], ['mask', MASK.fill], ['skin', PAL.skin.mid], ['hair', PAL.hair.mid]].forEach(([n, c], i) => {
    const x = 1198 + i * 96;
    b += rect(x, y0 + 12, 88, 34, c, 'stroke="#1b1428" stroke-opacity="0.3"') + text(x + 44, y0 + 60, `${n} ${c}`, { size: 10, anchor: 'middle', op: 0.85 });
  });
  b += paras(1198, y0 + 90, 'Palette masks: red channel body, green gear, blue accent, alpha the emissive sigil. Bones, about 24: root, pelvis, two spine, neck, head, three tail (spring), two shoulders, upper arms, forearms, hands, thighs, shins, feet. The plates are rigid children of the spine bones. Wear is five floats (head, core, arms, legs, crown). Regalia pieces are separate meshes with an intact and a broken variant.', 92, 12, 16);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

const ORIGIN = '<!-- Origin: procedural turnaround sheet written by art/concepts/turnaround/gen.mjs (deterministic, no external images or fonts), Art Director session (Claude, claude-sonnet-5-5), 2026-09-29; prompt record art/prompts/ART-0006-coil-turnaround.md -->' + String.fromCharCode(10);
writeFileSync(join(OUT, 'coil-turnaround.svg'), ORIGIN + sheet());
console.log('wrote coil-turnaround.svg');
