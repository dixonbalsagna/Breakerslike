// Origin: procedural generator for the battle-damage stage sheet and data (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-10-01. Human direction: Orb, via the EP.
// Run from the repo root:  node art/concepts/damage/gen.mjs   (writes art/concepts/damage/damage-stages.svg and data/art/damage.json)
// Orb's picks (docs/ep/vision.md, questionnaires 11 and 12): torn clothing, scuffs and bruises, a broken limb that hangs or drags, aura flicker when worn, heavy breathing and
// stagger; damage on a transformation stays and keeps building. Brief: docs/art/rule-of-cool-art.md.

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeCtx, figure, along, add, mul, lerp, dirDown } from '../anti-hero/kit.mjs';
import { FIGHTERS } from '../directions/fighters.mjs';
import { PAL, NAMES } from '../shared/marks.mjs';
import { markedConcept } from '../shared/styled.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const OUT = dirname(fileURLToPath(import.meta.url));
const F = n => n.toFixed(2);
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family=\"'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif\"";
const text = (x, y, t, { size = 14, weight = 400, fill = '#1b1428', anchor = 'start', op = 1 } = {}) => `<text x="${F(x)}" y="${F(y)}" ${FONT} font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}" opacity="${op}">${esc(t)}</text>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fill}" ${extra}/>`;
const wrap = (t, n) => { const w = t.split(' '), out = []; let line = ''; for (const x of w) { if ((line + ' ' + x).trim().length > n) { out.push(line.trim()); line = x; } else line += ' ' + x; } if (line.trim()) out.push(line.trim()); return out; };
const paras = (x, y, t, n, size = 12, gap = 15, o = {}) => wrap(t, n).map((l, i) => text(x, y + i * gap, l, { size, ...o })).join('');

const IDS = { P: 'protagonist', A: 'anti_hero', E: 'empress', C: 'cyborg' };
// the stages map onto the existing wear stages (docs/design/spec-wounds.md, style-guide.md section 6): bruised, battered, broken
const STAGES = [
  { n: 1, name: 'scuffed', wear: 'bruised, 30 to 59', pick: 'scuffs and bruises' },
  { n: 2, name: 'torn', wear: 'battered, 60 to 89', pick: 'torn clothing' },
  { n: 3, name: 'ruined', wear: 'broken, 90 and above', pick: 'a broken limb that hangs, stagger' },
];
// what each fighter's outfit shows, added stage by stage (each stage keeps the ones below). decals are shader layers, geometry is a mesh swap, silhouette changes the body shape.
const LAYERS = {
  P: {
    1: { decals: ['scuff_tunic', 'scuff_wrap', 'bruise_arm', 'bruise_neck'], geometry: [], silhouette: [] },
    2: { decals: ['bruise_arm_large'], geometry: ['tunic_torn_shoulder', 'apron_frayed', 'wrap_trailing', 'mask_chip'], silhouette: [] },
    3: { decals: [], geometry: ['tunic_torn_open', 'knot_loose'], silhouette: ['arm_near_hang', 'leg_near_drag', 'mask_crack'] },
  },
  A: {
    1: { decals: ['scuff_jacket', 'scuff_guard', 'bruise_arm', 'bruise_neck'], geometry: [], silhouette: [] },
    2: { decals: ['bruise_arm_large'], geometry: ['skirt_torn_hem', 'plate_2_cracked', 'plate_3_cracked', 'mask_chip'], silhouette: [] },
    3: { decals: [], geometry: ['jacket_torn_open', 'guard_gone'], silhouette: ['arm_near_hang', 'leg_near_drag', 'plate_4_missing', 'plate_6_missing', 'mask_crack'] },
  },
  E: {
    1: { decals: ['scuff_tabard', 'scuff_mantle', 'bruise_arm', 'bruise_neck'], geometry: [], silhouette: [] },
    2: { decals: ['bruise_arm_large'], geometry: ['mantle_torn_notch', 'tabard_torn_hem', 'blades_chipped_3', 'mask_chip'], silhouette: [] },
    3: { decals: [], geometry: ['mantle_torn_wide', 'tunic_torn_open', 'bracer_gone'], silhouette: ['arm_near_hang', 'leg_near_drag', 'mantle_strip_hanging', 'blades_missing_5', 'mask_crack'] },
  },
  C: {
    1: { decals: ['scuff_plating', 'dent_chest', 'scuff_mail', 'bruise_arm'], geometry: [], silhouette: [] },
    2: { decals: [], geometry: ['mail_holes_2', 'hatch_dented', 'cable_loose', 'mask_chip'], silhouette: [] },
    3: { decals: [], geometry: ['mail_holes_5', 'plating_torn_open', 'vent_cracked'], silhouette: ['arm_near_hang', 'leg_near_drag', 'cable_hanging', 'mask_crack'] },
  },
};
// body behaviour, for Animation, the same for every fighter (proposal)
const BODY = {
  1: { breathing: 'quick', breath_rate: 1.3, chest_rise_bh: 0.01, stagger: 'none', aura: 'steady', limb: 'none' },
  2: { breathing: 'heavy', breath_rate: 1.7, chest_rise_bh: 0.02, stagger: 'light', aura: 'flicker', limb: 'none' },
  3: { breathing: 'ragged', breath_rate: 2.2, chest_rise_bh: 0.03, stagger: 'heavy', aura: 'gaps', limb: 'near arm hangs, near leg drags' },
};

// ---------------------------------------------------------------------------------------------------------- the overlays, drawn after the whole figure
function overlay(fk, ctx, sk, stage) {
  const { pal } = ctx, T = (x, y) => sk.T(x, y), Hd = (x, y) => sk.Hd(x, y);
  const scuff = pal.gear.light, bruise = '#6d3a78', under = pal.base.shadow, skin = fk === 'C' || fk === 'A' ? pal.base.shadow : pal.skin.shadow;
  const L = (pts, c, w) => ctx.line(pts.map(p => T(...p)), c, w), Q = (pts, c, op = 1) => ctx.poly(pts.map(p => T(...p)), c, { line: false, op });
  const A = sk.nearArm, LG = sk.nearLeg; let o = '';
  const bite = (x, y, w, h) => Q([[x - w, y], [x, y - h], [x + w, y], [x + w * 0.2, y + h * 0.3]], under, 0.95);
  if (stage >= 1) {
    o += L([[1, 22], [4.5, 19.6]], scuff, 1.5) + L([[-1, 16], [2.4, 13.6]], scuff, 1.5);
    o += ctx.line([along(A.E, A.W, 0.3, 1.0), along(A.E, A.W, 0.55, -0.6)], scuff, 1.5) + ctx.line([along(sk.P, LG.K, 0.5, -1.4), along(sk.P, LG.K, 0.72, 0.9)], scuff, 1.5);
    o += ctx.poly([along(A.E, A.W, 0.35, -1.6), along(A.E, A.W, 0.75, -1.4), along(A.E, A.W, 0.72, 0.8), along(A.E, A.W, 0.38, 1.0)], bruise, { line: false, op: 0.5 });
    o += ctx.poly([Hd(-1.2, 2.2), Hd(1.4, 2.6), Hd(1.2, 1.2), Hd(-0.8, 0.8)], bruise, { line: false, op: 0.45 });
  }
  if (stage >= 2) {
    o += bite(-3.4, 9.6, 1.2, 2.2) + bite(0.2, 9.4, 1.4, 2.8) + bite(3.6, 9.8, 1.1, 2.0);
    o += Q([[-4.4, 26], [-1.2, 24.4], [-2.2, 21.4], [-4.8, 22.4]], skin, 0.95) + L([[-4.4, 26], [-1.2, 24.4], [-2.2, 21.4], [-4.8, 22.4], [-4.4, 26]], '#14101f', 0.8);
    o += ctx.poly([along(A.E, A.W, 0.3, -2.4), along(A.E, A.W, 0.62, -2.2), along(A.E, A.W, 0.55, 2.0), along(A.E, A.W, 0.26, 2.2)], skin, { line: false, op: 0.9 });
    o += ctx.poly([Hd(5.4, 13.6), Hd(6.9, 12.4), Hd(6.1, 11.4), Hd(5.2, 12.2)], '#14101f', { line: false, op: 0.9 });   // a chip at the mask's front corner
    o += ctx.poly([along(A.E, A.W, 0.35, -1.9), along(A.E, A.W, 0.9, -1.8), along(A.E, A.W, 0.88, 1.2), along(A.E, A.W, 0.4, 1.6)], bruise, { line: false, op: 0.55 });
  }
  if (stage >= 3) {
    o += Q([[-5.2, 25], [3.4, 21.4], [6.0, 13], [3.8, 9], [-4.2, 16]], skin, 0.95) + L([[-5.2, 25], [3.4, 21.4], [6.0, 13], [3.8, 9], [-4.2, 16], [-5.2, 25]], '#14101f', 0.9);
    o += bite(-4.6, 9.8, 1.6, 3.2) + bite(-1.6, 9.4, 1.5, 3.6) + bite(2.2, 9.6, 1.8, 3.4) + bite(5.0, 10, 1.2, 2.6);
    o += ctx.line([Hd(-1.6, 14.6), Hd(0.8, 11.8), Hd(2.8, 9.4)], '#14101f', 1.6) + ctx.line([Hd(-1.2, 14.6), Hd(1.2, 11.8), Hd(3.2, 9.4)], pal.gear.light, 0.7);   // one crack across the mask, never crossed
  }
  const mk = pts => pts.map(p => ({ x: p.x, y: p.y }));
  // ---- the outfit's own damage
  if (fk === 'P') {
    if (stage >= 2) { const a = A.W; o += ctx.poly([a, add(a, { x: -2.4, y: -7 }), add(a, { x: -0.4, y: -12 }), add(a, { x: 1.4, y: -6.6 })], pal.base.light, { sw: 0.8 }); }
    if (stage >= 3) o += ctx.poly([T(-8.4, 8), T(-10.6, 3), T(-8.2, 0), T(-6.6, 4)], pal.gear.shadow, { sw: 0.9 });
  }
  if (fk === 'A') {
    const plate = i => { const y = 27 - i * 4.3, bx = -5.8; return [[bx + 1.2, y + 2.3], [bx - 4.6, y + 2.1], [bx - 5.8, y + 0.3], [bx - 5.0, y - 2.0], [bx + 1.2, y - 2.3]]; };
    if (stage >= 2) { o += L([[-6.6, 23.4], [-9.2, 21.6], [-8, 20.6]], '#14101f', 1.3) + L([[-6.4, 19.2], [-8.8, 17.6], [-7.8, 16.2]], '#14101f', 1.3); }
    if (stage >= 3) { o += Q(plate(3), pal.base.mid, 1) + Q(plate(5), pal.base.mid, 1); }
  }
  if (fk === 'E') {
    const sway = 10, S1 = T(-5.8, 28), W = T(-6.4, 6), hemB = add(S1, mul(dirDown(-(46 + sway * 1.2)), 66)), hemA = add(W, mul(dirDown(-(14 + sway)), 62));
    if (stage >= 1) o += ctx.line([lerp(S1, hemB, 0.55), lerp(S1, hemB, 0.8)], scuff, 1.4);
    if (stage >= 2) { const a = lerp(hemB, hemA, 0.45), b = lerp(hemB, hemA, 0.58); o += ctx.poly([a, b, lerp(a, S1, 0.22)], pal.base.shadow, { line: false }); }
    if (stage >= 3) { const a = lerp(hemB, hemA, 0.3), b = lerp(hemB, hemA, 0.78); o += ctx.poly([a, b, lerp(b, S1, 0.34), lerp(a, S1, 0.3)], pal.base.shadow, { line: false, op: 0.95 }) + ctx.poly([lerp(hemB, hemA, 0.8), add(lerp(hemB, hemA, 0.9), { x: 3, y: -9 }), lerp(hemB, hemA, 0.98)], pal.base.mid, { sw: 0.8 }); }
  }
  if (fk === 'C') {
    const hole = (x, y) => Q([[x - 0.9, y - 0.9], [x + 0.9, y - 0.9], [x + 0.9, y + 0.9], [x - 0.9, y + 0.9]], under, 1);
    if (stage >= 1) o += Q([[1, 24], [4, 23.4], [3.6, 21.6], [0.6, 22.2]], pal.base.shadow, 0.55);
    if (stage >= 2) o += hole(-2, 3) + hole(1.6, -1.4);
    if (stage >= 3) o += hole(-3.6, -3.6) + hole(3.2, 3.8) + hole(-0.4, -6) + ctx.line([T(4, 28), T(7.4, 21), T(8.6, 12)], pal.base.shadow, 3.2) + ctx.line([T(4, 28), T(7.4, 21), T(8.6, 12)], pal.accent.mid, 1.1);
    if (stage === 2) o += ctx.line([T(4, 28), T(6.4, 24)], pal.accent.mid, 1.4);
  }
  return o;
}
function figureFor(fk, stage, px, x, ground, extra = {}) {
  const concept = markedConcept(fk), prev = concept.after;
  concept.after = (ctx, sk, st, cfg) => (prev ? prev(ctx, sk, st, cfg) : '') + (ctx.flat ? '' : overlay(fk, ctx, sk, stage));
  const s = px / 100, pal = PAL[fk], ctx = makeCtx({ flat: !!extra.flat, pal, swMul: px < 80 ? 1 : 1.3, faceless: true });
  const up = { lean: 0, head: 0, nearArm: [10, 8], farArm: [-10, -8], nearLeg: [3, 1], farLeg: [-3, -1], handNear: 'fist', handFar: 'fist' };
  const pose = stage === 0 ? up : stage === 1 ? { ...up, lean: 3, head: 4, nearArm: [14, 14] } : stage === 2 ? { ...up, lean: 7, head: 9, nearArm: [18, 22], farArm: [-16, -30], handNear: 'open', handFar: 'open' }
    : { ...up, lean: 15, head: 20, nearArm: [3, 6], farArm: [-34, -112], nearLeg: [16, -14], farLeg: [-8, -6], handNear: 'open', handFar: 'fist' };
  const st = { yaw: 32, state: 'neutral', sigil: stage === 0 ? 'neutral' : stage === 1 ? 'neutral' : stage === 2 ? 'hurt' : 'brink', sway: FIGHTERS[fk].sway ?? 6, expression: 'neutral', open: stage * 0.3, forms: 6, wear: 0, hairLoose: stage >= 2 };
  const { svg } = figure(ctx, concept, pose, st, { yaw: 32 });
  return `<g transform="translate(${F(x)} ${F(ground)}) scale(${F(s)} ${F(-s)})">${svg}</g>`;
}

// ---------------------------------------------------------------------------------------------------------- the sheet
function sheet() {
  const W = 1800, rowH = 330, H = 140 + 4 * rowH + 420;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'Battle damage: three stages per outfit', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'Orb\'s picks: torn clothing, scuffs and bruises, a broken limb that hangs or drags, aura flicker, heavy breathing and stagger. Fresh, then stage 1 scuffed, 2 torn, 3 ruined. The damage stays and builds. Working labels, pending Legal review.', { size: 14, fill: '#cfc6e6' });
  const colx = [0, 1, 2, 3].map(i => 60 + i * 300);
  ['fresh', 'stage 1: scuffed', 'stage 2: torn', 'stage 3: ruined'].forEach((t, i) => { b += text(colx[i] + 100, 130, t, { size: 14, weight: 700, anchor: 'middle' }); });
  ['P', 'A', 'E', 'C'].forEach((fk, r) => {
    const y0 = 142 + r * rowH;
    b += rect(24, y0, 1240, rowH - 8, '#e8e5ee', 'stroke="#1b1428" stroke-opacity="0.2"');
    b += text(34, y0 + 20, NAMES[fk], { size: 15, weight: 700 });
    [0, 1, 2, 3].forEach(n => { b += figureFor(fk, n, 232, colx[n] + 100, y0 + rowH - 24); });
    // what each stage adds
    const lines = [1, 2, 3].map(n => `${n}: ${[...LAYERS[fk][n].decals, ...LAYERS[fk][n].geometry, ...LAYERS[fk][n].silhouette].map(s => s.replace(/_/g, ' ')).join(', ')}`);
    b += text(1284, y0 + 20, `${NAMES[fk]}: what each stage adds`, { size: 13, weight: 700 });
    lines.forEach((l, i) => { b += paras(1284, y0 + 44 + i * 78, l, 52, 11.5, 14.5, { op: 0.9 }); });
  });
  const y = 142 + 4 * rowH + 16;
  b += text(24, y, 'The body behaviour that goes with each stage (for Animation; the numbers are proposals)', { size: 16, weight: 700 });
  [1, 2, 3].forEach((n, i) => { const x = 24 + i * 592, d = BODY[n]; b += rect(x, y + 12, 580, 120, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"') + text(x + 10, y + 32, `stage ${n}: ${STAGES[n - 1].name} (${STAGES[n - 1].wear})`, { size: 13, weight: 700 }) + paras(x + 10, y + 54, `Breathing ${d.breathing}, ${d.breath_rate} times the rest rate, the chest rising ${d.chest_rise_bh * 100} percent of a body height. Stagger: ${d.stagger}. The aura: ${d.aura}.${d.limb !== 'none' ? ` ${d.limb}.` : ''}`, 80, 12, 15); });
  b += paras(24, y + 160, 'It stays and keeps building through a transformation: the wear is a property of the body and not of the form, so a new form adds its regalia above the damage and the torn parts stay torn on it. Nothing resets when a fighter transforms, only a rest at the end of a match. Damage here is neutral (scuffs, tint, torn cloth, a hanging limb). The blood decals of the kit\'s wear layer stay behind the graphic dial and are separate layers in the data.', 160, 12.5, 16);
  b += paras(24, y + 232, 'How it draws on the mannequin (for Rendering). Decals are shader layers keyed by the wear stage, geometry rows are small mesh swaps for the outfit (a torn hem, a cracked plate, a frayed apron) merged at equip, and silhouette rows change the body (the arm and leg poses, a missing plate, a hanging mantle strip). The stage-3 silhouette change is at least 10 percent of a body height, so it reads at 20 px. The data is data/art/damage.json.', 160, 12.5, 16);
  b += paras(24, y + 304, 'Legal and the stacking rule: damage is on the body and the outfit only. It adds no glow, no aura flame and no gold, white or red flash. A flickering aura is a shape change in the fighter\'s lane colour, only while charging or attacking.', 160, 12.5, 16);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${b}</svg>`;
}
const ORIGIN = '<!-- Origin: procedural concept sheet written by art/concepts/damage/gen.mjs (deterministic, no external images or fonts), Art Director session (Claude, claude-sonnet-5-5), 2026-10-01; prompt record art/prompts/ART-0010-rule-of-cool-art.md -->' + String.fromCharCode(10);
writeFileSync(join(OUT, 'damage-stages.svg'), ORIGIN + sheet());
const data = {
  version: 1,
  note: 'Battle damage stages per fighter outfit (Orb, docs/ep/vision.md questionnaires 11 and 12). Written by art/concepts/damage/gen.mjs (Art owns data/art/). Stages map onto the existing wear stages (docs/design/spec-wounds.md). Each stage keeps the layers of the stages below. The wear is a property of the body, so it stays and keeps building through a transformation: a new form adds regalia above the damage.',
  persist_through_forms: true,
  stages: Object.fromEntries(STAGES.map(s => [String(s.n), { name: s.name, wear_stage: s.wear, orb_pick: s.pick, body: BODY[s.n] }])),
  layers_note: 'decals: shader layers keyed by wear. geometry: small mesh swaps merged at equip (docs/animation/pose-pipeline.md 2.8). silhouette: body shape changes (poses, a missing or hanging part), at least 10 percent of a body height by stage 3. Blood decals are separate and stay behind the graphic dial.',
  fighters: Object.fromEntries(Object.entries(IDS).map(([k, id]) => [id, Object.fromEntries([1, 2, 3].map(n => [String(n), LAYERS[k][n]]))])),
};
writeFileSync(join(ROOT, 'data', 'art', 'damage.json'), JSON.stringify(data, null, 2) + String.fromCharCode(10));
console.log('wrote art/concepts/damage/damage-stages.svg and data/art/damage.json');
