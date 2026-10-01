// Origin: procedural generator for the ragdoll and hit-reaction silhouette reference sheet (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-10-02. Human direction: Orb, via the EP (Animation's ragdoll and hit-reaction overhaul asked for reference).
// Run from the repo root:  node art/concepts/silhouettes/gen.mjs   (writes art/concepts/silhouettes/ragdoll-silhouettes.svg)
// Four key body shapes (a tumble, a braced bounce, a skid on the side, a crumple) for each fighter, in profile, each in colour and as the flat silhouette,
// in the fighter's own shape language: circles (Protagonist), blades (Anti-hero), wedges (Empress), steps (Cyborg). The pose is a rigid turn of an authored base pose.

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeCtx, figure } from '../anti-hero/kit.mjs';
import { FIGHTERS } from '../directions/fighters.mjs';
import { PAL, NAMES } from '../shared/marks.mjs';
import { markedConcept } from '../shared/styled.mjs';

const OUT = dirname(fileURLToPath(import.meta.url));
const F = n => n.toFixed(2);
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family=\"'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif\"";
const text = (x, y, t, { size = 14, weight = 400, fill = '#1b1428', anchor = 'start', op = 1 } = {}) => `<text x="${F(x)}" y="${F(y)}" ${FONT} font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}" opacity="${op}">${esc(t)}</text>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fill}" ${extra}/>`;
const wrap = (t, n) => { const w = t.split(' '), out = []; let line = ''; for (const x of w) { if ((line + ' ' + x).trim().length > n) { out.push(line.trim()); line = x; } else line += ' ' + x; } if (line.trim()) out.push(line.trim()); return out; };
const paras = (x, y, t, n, size = 12, gap = 15, o = {}) => wrap(t, n).map((l, i) => text(x, y + i * gap, l, { size, ...o })).join('');

// A pose is authored in the standing frame (angles from straight down, positive toward the facing side; lean and head are clockwise) and then turned
// as one rigid piece by phi degrees clockwise: lean and foot gain phi, arm and leg angles lose it.
function turn(p, phi) {
  const t = a => [a[0] - phi, a[1] - phi, ...(a.length > 2 ? [a[2] + phi] : [phi])];
  return { ...p, lean: (p.lean ?? 0) + phi, nearArm: [p.nearArm[0] - phi, p.nearArm[1] - phi], farArm: [p.farArm[0] - phi, p.farArm[1] - phi], nearLeg: t(p.nearLeg), farLeg: t(p.farLeg) };
}
const base = (o) => ({ lean: 0, head: 0, nearArm: [10, 8], farArm: [-10, -8], nearLeg: [3, 1, 0], farLeg: [-3, -1, 0], handNear: 'open', handFar: 'open', ...o });

// The sixteen shapes. Each fighter's language shapes the same four beats.
const SHAPES = {
  P: {   // circles: compact, rolled, hugged, round masses
    note: 'Circles. He balls up: a tumble that reads as a rolling disc, a bounce that is a low curled crouch, a skid with the knees up and the hands cupped in, a crumple that folds into one round heap.',
    tumble: [base({ lean: 30, head: 25, nearArm: [60, 150], farArm: [30, 130], nearLeg: [105, -20, 0], farLeg: [95, -40, 0], handNear: 'fist', handFar: 'fist' }), 140],
    bounce: [base({ lean: 55, head: 35, nearArm: [70, 120], farArm: [55, 110], nearLeg: [78, -30, 0], farLeg: [60, -45, 0], handNear: 'fist', handFar: 'fist' }), 0],
    skid: [base({ lean: 0, head: -10, nearArm: [40, 110], farArm: [30, 120], nearLeg: [70, -40, 0], farLeg: [55, -60, 0], handNear: 'fist', handFar: 'fist' }), -84],
    crumple: [base({ lean: 85, head: 45, nearArm: [25, 15], farArm: [10, 0], nearLeg: [20, -125, 0], farLeg: [30, -130, 0] }), 0],
  },
  A: {   // blades: long straight lines, a trailing tail, the body a slash
    note: 'Blades. He stays long: arms and legs fly out as straight lines and the tail streams, a tumble that reads as a thrown blade, a bounce that skims low with one arm cutting the ground, a skid laid out flat and narrow, a crumple that drops to one knee and one hand.',
    tumble: [base({ lean: 10, head: -15, nearArm: [155, 160], farArm: [-150, -140], nearLeg: [40, 30, 0], farLeg: [-55, -60, 0] }), 118],
    bounce: [base({ lean: 62, head: -5, nearArm: [112, 108], farArm: [-30, -25], nearLeg: [88, 60, 0], farLeg: [-50, -62, 0], handNear: 'open' }), 0],
    skid: [base({ lean: 0, head: 5, nearArm: [-20, -10], farArm: [165, 170], nearLeg: [8, 0, 0], farLeg: [-6, -2, 0] }), -88],
    crumple: [base({ lean: 48, head: 32, nearArm: [75, 85], farArm: [-8, -14], nearLeg: [92, -16, 0], farLeg: [-30, -58, 0] }), 0],
  },
  E: {   // wedges: the body a single point, the mantle a hinge
    note: 'Wedges. She stays narrow and pointed: a tumble that falls as one wedge with the legs together, a bounce that braces on one leg with the other swept back like a brace, a skid with the heels dug in and the mantle fanning, a crumple that folds to one side as a triangle.',
    tumble: [base({ lean: 8, head: -8, nearArm: [-18, -22], farArm: [-26, -30], nearLeg: [-4, -6, 0], farLeg: [6, 4, 0] }), 98],
    bounce: [base({ lean: 28, head: -14, nearArm: [-48, -60], farArm: [-40, -64], nearLeg: [64, 4, 0], farLeg: [-58, -66, 0] }), 0],
    skid: [base({ lean: 0, head: -6, nearArm: [-28, -34], farArm: [-20, -30], nearLeg: [24, 30, 0], farLeg: [18, 22, 0] }), -80],
    crumple: [base({ lean: 66, head: 40, nearArm: [-14, -22], farArm: [-32, -44], nearLeg: [88, -2, 0], farLeg: [-10, -102, 0] }), 0],
  },
  C: {   // steps: right angles, stiff, a block that stops in stages
    note: 'Steps. He stays boxy and stiff: a tumble that turns in square quarter-steps, a bounce that lands as a squat block, a skid flat on the back with the elbows and knees at right angles, a crumple that sags in three stages (knees, hips, chest).',
    tumble: [base({ lean: 0, head: 0, nearArm: [90, 0], farArm: [90, 0], nearLeg: [90, 0, 0], farLeg: [90, 0, 0], handNear: 'fist', handFar: 'fist' }), 90],
    bounce: [base({ lean: 45, head: -20, nearArm: [90, 90], farArm: [90, 90], nearLeg: [90, 0, 0], farLeg: [90, 0, 0], handNear: 'fist', handFar: 'fist' }), 0],
    skid: [base({ lean: 0, head: 0, nearArm: [90, 0], farArm: [-10, -10], nearLeg: [90, 0, 0], farLeg: [0, 0, 0] }), -90],
    crumple: [base({ lean: 90, head: 0, nearArm: [0, 0], farArm: [0, 0], nearLeg: [0, -90, 0], farLeg: [0, -90, 0] }), 0],
  },
};
const BEATS = [['tumble', 'A tumble (airborne, turning)', 18], ['bounce', 'A braced bounce (the landing that rebounds)', 0], ['skid', 'A skid on the side (sliding on the back)', 0], ['crumple', 'A crumple (the fall that stays down)', 0]];

function allPoints(sk) {
  const o = [sk.P, sk.S, sk.N, sk.HB, sk.Hd(0, 17), sk.Hd(7, 9), sk.Hd(-5, 9)];
  for (const a of [sk.nearArm, sk.farArm]) o.push(a.E, a.W, a.F);
  for (const l of [sk.nearLeg, sk.farLeg]) o.push(l.K, l.A, ...l.boot);
  return o;
}
function fig(fk, beat, x, ground, s, flat, hover) {
  const [pose0, phi] = SHAPES[fk][beat], pose = turn(pose0, phi);
  const concept = markedConcept(fk), pal = PAL[fk], ctx = makeCtx({ flat, pal, swMul: 1.3, faceless: true });
  const st = { yaw: 0, state: 'neutral', sigil: beat === 'crumple' ? 'brink' : 'hurt', sway: FIGHTERS[fk].sway ?? 6, expression: 'neutral', open: 0.5, forms: 6, wear: 0, hairLoose: true };
  const { svg, sk } = figure(ctx, concept, pose, st, { yaw: 0 });
  const pts = allPoints(sk), minY = Math.min(...pts.map(p => p.y)), minX = Math.min(...pts.map(p => p.x)), maxX = Math.max(...pts.map(p => p.x));
  // the body drops so its lowest point touches the ground (a tumble hovers); the figure is centred on its own width
  const cx = (minX + maxX) / 2;
  return { g: `<g transform="translate(${F(x - cx * s)} ${F(ground - (hover - minY) * s)}) scale(${F(s)} ${F(-s)})">${svg}</g>`, w: (maxX - minX) * s };
}
// motion marks, in grey: a turning arrow, a bounce arc, skid lines and dust, slump lines
function cue(beat, x, g, s) {
  const ink = '#1b1428', o = 'opacity="0.5"';
  if (beat === 'tumble') return `<path d="M ${F(x - 52)} ${F(g - 168)} A 62 62 0 1 1 ${F(x + 58)} ${F(g - 150)}" fill="none" stroke="${ink}" stroke-width="3" stroke-dasharray="8 6" ${o}/> <polygon points="${F(x + 58)},${F(g - 150)} ${F(x + 44)},${F(g - 160)} ${F(x + 72)},${F(g - 162)}" fill="${ink}" ${o}/>`;
  if (beat === 'bounce') return `<path d="M ${F(x - 150)} ${F(g - 6)} Q ${F(x - 90)} ${F(g - 90)} ${F(x - 40)} ${F(g - 6)}" fill="none" stroke="${ink}" stroke-width="3" stroke-dasharray="8 6" ${o}/><polygon points="${F(x - 40)},${F(g - 6)} ${F(x - 52)},${F(g - 26)} ${F(x - 28)},${F(g - 22)}" fill="${ink}" ${o}/>`;
  if (beat === 'skid') return [0, 1, 2].map(i => `<line x1="${F(x + 70 + i * 6)}" y1="${F(g - 14 - i * 12)}" x2="${F(x + 150 + i * 14)}" y2="${F(g - 14 - i * 12)}" stroke="${ink}" stroke-width="3" ${o}/>`).join('') + [0, 1, 2].map(i => `<polygon points="${F(x - 130 - i * 24)},${F(g)} ${F(x - 124 - i * 24)},${F(g - 14 - i * 5)} ${F(x - 112 - i * 24)},${F(g)}" fill="${ink}" opacity="0.28"/>`).join('');
  return [0, 1, 2].map(i => `<line x1="${F(x - 60 + i * 60)}" y1="${F(g - 150)}" x2="${F(x - 60 + i * 60)}" y2="${F(g - 112)}" stroke="${ink}" stroke-width="3" ${o}/><polygon points="${F(x - 68 + i * 60)},${F(g - 112)} ${F(x - 52 + i * 60)},${F(g - 112)} ${F(x - 60 + i * 60)},${F(g - 98)}" fill="${ink}" ${o}/>`).join('');
}
function sheet() {
  const W = 1800, rowH = 330, H = 130 + 4 * rowH + 150, s = 1.9;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'Ragdoll and hit-reaction silhouettes, one sheet per fighter set', { size: 32, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'A tumble, a braced bounce, a skid on the side and a crumple, in profile, in colour and as the flat silhouette, each in the fighter\'s own shape language. Reference for Animation\'s overhaul, not final poses. Working labels, pending Legal review.', { size: 14, fill: '#cfc6e6' });
  BEATS.forEach(([k, label], c) => { b += text(24 + c * 440 + 6, 128, label, { size: 14, weight: 700 }); });
  ['P', 'A', 'E', 'C'].forEach((fk, r) => {
    const y0 = 140 + r * rowH, ground = y0 + 250;
    b += rect(24, y0, W - 48, rowH - 14, '#e8e5ee', 'stroke="#1b1428" stroke-opacity="0.2"');
    b += text(36, y0 + 24, NAMES[fk], { size: 16, weight: 700 });
    BEATS.forEach(([k, , hover], c) => {
      const cx = 24 + c * 440 + 190, gy = ground;
      b += `<line x1="${24 + c * 440 + 10}" y1="${gy}" x2="${24 + c * 440 + 430}" y2="${gy}" stroke="#1b1428" stroke-opacity="0.35" stroke-width="2"/>`;
      b += cue(k, cx, gy - (k === 'tumble' ? 30 : 0), s);
      const colour = fig(fk, k, cx, gy, s, false, hover), flat = fig(fk, k, 24 + c * 440 + 366, y0 + 118, 0.8, true, 0);
      // a cloth that trails below the body (the mantle) rests on the ground line, so each cell is cut there
      b += `<clipPath id="cl-${fk}${c}"><rect x="${24 + c * 440}" y="${y0 + 28}" width="440" height="${gy - y0 - 28 + 3}"/></clipPath><g clip-path="url(#cl-${fk}${c})">${colour.g}</g>` + flat.g;
    });
    b += paras(36, y0 + 280, SHAPES[fk].note, 220, 12, 15, { op: 0.85 });
  });
  const yn = 140 + 4 * rowH + 12;
  b += text(24, yn + 16, 'What Animation can take from this', { size: 16, weight: 700 });
  b += paras(24, yn + 38, 'Each beat has a base pose and one rigid turn, so the same four shapes can be the targets a ragdoll settles toward or the key silhouettes a hit reaction passes through. The silhouette test: at 80 px, flat black, the four fighters\' tumbles are still four different shapes (a disc, a slash, a wedge, a block). Keep the cosmetic chains (the Anti-hero\'s tail, the Empress\'s mantle, the Protagonist\'s tuft) trailing opposite the motion; they are what make the silhouette. The sockets and chain bones of the cosmetics plan carry them; no new bones.', 230, 13, 17);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${b}</svg>`;
}
const ORIGIN = '<!-- Origin: procedural silhouette reference sheet written by art/concepts/silhouettes/gen.mjs (deterministic, no external images or fonts), Art Director session (Claude, claude-sonnet-5-5), 2026-10-02; prompt record art/prompts/ART-0012-ragdoll-silhouettes.md -->' + String.fromCharCode(10);
writeFileSync(join(OUT, 'ragdoll-silhouettes.svg'), ORIGIN + sheet());
console.log('wrote ragdoll-silhouettes.svg');
