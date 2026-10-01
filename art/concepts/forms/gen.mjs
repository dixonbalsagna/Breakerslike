// Origin: procedural generator for the Anti-hero's three forms, his aura colours and the stacking-rule audit (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-10-01. Human direction: Orb, via the EP.
// Run from the repo root:  node art/concepts/forms/gen.mjs   (writes art/concepts/forms/anti-hero-forms.svg and data/art/auras.json)
// Legal's aura rule (docs/legal/rule-of-cool-screen.md): hue 260 to 320 degrees, a lighter tint of the same hue for the core, never pure white, no red, orange, gold or yellow, a thin outline or rings, not a flame.
// The staging is moveset-rules.md 10.8 (gather, break, settle). Brief: docs/art/rule-of-cool-art.md.

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeCtx, figure, along, limb, add } from '../anti-hero/kit.mjs';
import { PAL } from '../shared/marks.mjs';
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

// ---------------------------------------------------------------------------------------------------------- colour
function hsl(h, s, l) {
  s /= 100; l /= 100; const k = n => (n + h / 30) % 12, a = s * Math.min(l, 1 - l), f = n => l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
  return '#' + [f(0), f(8), f(4)].map(v => Math.round(v * 255).toString(16).padStart(2, '0')).join('');
}
const rgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const lin = c => { c /= 255; return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4; };
const lum = h => { const [r, g, b] = rgb(h).map(lin); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
const lstar = h => { const y = lum(h); return y > 0.008856 ? 116 * Math.cbrt(y) - 16 : 903.3 * y; };
const hueOf = h => { const [r, g, b] = rgb(h).map(v => v / 255), mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn; if (!d) return 0; let hh = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4; hh *= 60; return (hh + 360) % 360; };
const M = [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]];   // Machado deuteranopia
const dlum = h => { const l = rgb(h).map(lin), s = M.map(r => Math.max(0, Math.min(1, r[0] * l[0] + r[1] * l[1] + r[2] * l[2]))); return 0.2126 * s[0] + 0.7152 * s[1] + 0.0722 * s[2]; };
const cr = (a, b, f = lum) => { const x = f(a), y = f(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };

// The three forms' colours. Hue 266 (Regalia, the deep violet base), 290 (Sovereign, shifting toward magenta) and 272 (Apex, colder and quieter). All inside 260 to 320.
const FORMS = {
  regalia: { name: 'Regalia', hue: 266, rim: [60, 62], core: [68, 84], shadow: [42, 34], key: [50, 20], sig: [78, 86], info: [70, 94], pieces: 'a high collar and two forearm guards' },
  sovereign: { name: 'Sovereign', hue: 290, rim: [56, 60], core: [62, 84], shadow: [40, 33], key: [48, 20], sig: [74, 86], info: [66, 94], pieces: 'the collar and guards, a low faceted crest on the mask, and three floating plates behind the shoulders' },
  apex: { name: 'Apex', hue: 272, rim: [48, 54], core: [52, 80], shadow: [38, 30], key: [45, 18], sig: [70, 86], info: [60, 94], pieces: 'the guards fall away and the sound cuts out; the collar, the crest and the plates stay, hanging still' },
};
for (const f of Object.values(FORMS)) {
  f.c = { rim: hsl(f.hue, ...f.rim), core: hsl(f.hue, ...f.core), shadow: hsl(f.hue, ...f.shadow), keyline: hsl(f.hue, ...f.key), sigil: hsl(f.hue, ...f.sig), info_core: hsl(f.hue, ...f.info) };
}
const BACKDROPS = { 'sky horizon': '#cfe6f0', 'sea': '#2f86ad', 'grass': '#6da043', 'dusk rock': '#7e766a', 'night': '#10142b' };

// ---------------------------------------------------------------------------------------------------------- the figure, with the form's pieces
const T2 = (sk, a) => a.map(([x, y]) => sk.T(x, y));
function pieces(ctx, sk, form, where, col) {
  const { pal } = ctx; let o = '';
  const A = sk.nearArm, B = sk.farArm, lw = sk.b.lw;
  if (where === 'back' && (form === 'sovereign' || form === 'apex')) {
    // three floating plates behind the shoulders, faceted rhomboids with a gap to the body
    for (const [x, y, k] of [[-14, 33, 1], [-17.5, 27.5, 0.85], [-14.5, 22, 0.7]]) o += ctx.poly(T2(sk, [[x, y + 2.4 * k], [x + 2.2 * k, y], [x, y - 2.4 * k], [x - 2.2 * k, y]]), col.core, { sw: 1 }) + ctx.line(T2(sk, [[x, y + 2.4 * k], [x, y - 2.4 * k]]), col.shadow, 0.8);
  }
  if (where === 'front') {
    o += ctx.poly(T2(sk, [[-4.4, 28], [-4.4, 33.4], [3.4, 33.6], [4.6, 28.6]]), pal.base.light, { sw: 1.2 }) + ctx.line(T2(sk, [[-4.2, 33.2], [3.2, 33.4]]), col.rim, 1.1);
    if (form === 'sovereign' || form === 'apex') o += ctx.poly([sk.Hd(-4.2, 16.4), sk.Hd(5.6, 16.8), sk.Hd(5.0, 19.4), sk.Hd(-1.6, 19.6), sk.Hd(-4.6, 18)], col.rim, { sw: 1 }) + ctx.line([sk.Hd(-4, 17), sk.Hd(5.2, 17.4)], col.shadow, 0.9);   // a low faceted crest, never upswept
  }
  if (where === 'arm' && form !== 'apex') {
    for (const arm of [A]) o += ctx.poly(limb(along(arm.E, arm.W, 0.1), along(arm.E, arm.W, 0.64), 6.4 * lw, 5.8 * lw, 1.04), pal.gear.mid, { sw: 1.1 }) + ctx.line([along(arm.E, arm.W, 0.18, 2.4), along(arm.E, arm.W, 0.58, 2.1)], col.rim, 1.0);
  }
  return o;
}
function conceptFor(form) {
  const c = markedConcept('A'), col = form ? FORMS[form].c : null, prevBack = c.back, prevFront = c.front, prevArm = c.armGear;
  if (!form) return c;
  c.back = (ctx, sk, st, cfg) => pieces(ctx, sk, form, 'back', col) + prevBack(ctx, sk, st, cfg);
  c.front = (ctx, sk, st, cfg) => prevFront(ctx, sk, st, cfg) + pieces(ctx, sk, form, 'front', col);
  c.armGear = (ctx, sk, st, cfg) => prevArm(ctx, sk, st, cfg) + pieces(ctx, sk, form, 'arm', col);
  return c;
}
const UP = { lean: 0, head: 0, nearArm: [10, 8], farArm: [-10, -8], nearLeg: [3, 1], farLeg: [-3, -1], handNear: 'fist', handFar: 'fist' };
const POSES = {
  rest: UP,
  attack: { lean: 14, head: 4, nearArm: [84, 90], farArm: [-30, -80], nearLeg: [30, 6], farLeg: [-22, -12], handNear: 'fist', handFar: 'fist' },
  // 10.8: gather: he rises out of the crouch, lifts his chin and goes still, one hand palm-up as if being dressed. break: one dismissive flick of that hand. settle: composed, checks that the rival saw.
  gather: { lean: -2, head: -10, nearArm: [44, 150], farArm: [-6, -10], nearLeg: [4, 1], farLeg: [-4, -1], handNear: 'open', handFar: 'fist' },
  break: { lean: 1, head: -8, nearArm: [76, 104], farArm: [-8, -12], nearLeg: [5, 1], farLeg: [-5, -2], handNear: 'open', handFar: 'fist' },
  settle: { lean: -3, head: -6, nearArm: [14, 10], farArm: [-10, -12], nearLeg: [4, 1], farLeg: [-4, -1], handNear: 'fist', handFar: 'fist' },
};
function draw(form, pose, px, x, ground, { aura = null, sigil = 'neutral', flat = false } = {}) {
  const s = px / 100, concept = conceptFor(form), ctx = makeCtx({ flat, pal: PAL.A, swMul: px < 80 ? 1 : 1.3, faceless: true });
  const st = { yaw: 32, state: 'neutral', sigil, sway: 12, expression: 'neutral', open: 0, forms: 6, wear: 0 };
  const { svg, sk } = figure(ctx, concept, pose, st, { yaw: 32 });
  return { svg: `<g transform="translate(${F(x)} ${F(ground)}) scale(${F(s)} ${F(-s)})">${svg}</g>`, sk, s };
}
// The aura: a thin outline of the whole silhouette in the form's colour (and rings), only while charging or attacking. Never a flame, never upward streaming.
function auraLayer(form, pose, px, x, ground, kind, bg = '#e8e5ee') {
  const c = FORMS[form].c, s = px / 100, flat = draw(form, pose, px, x, ground, { flat: true }), bare = flat.svg.replace(/ opacity="[^"]*"/g, '');
  const paint = (w, col, op) => bare.replace(/fill="#000"/g, `fill="${col}" stroke="${col}" stroke-width="${w}" stroke-linejoin="round" opacity="${op}"`);
  const hollow = () => bare.replace(/fill="#000"/g, `fill="${bg}"`);   // the silhouette in the ground colour, so only a thin outline is left
  let o = '';
  if (kind === 'regalia') o += paint(2.6, c.rim, 0.5) + paint(1.4, c.rim, 0.9);
  if (kind === 'sovereign') o += paint(4.4, c.rim, 0.25) + paint(2.4, c.rim, 0.55) + paint(1.2, c.rim, 0.95);
  if (kind === 'apex') o += paint(3.4, c.keyline, 0.4) + paint(1.0, c.rim, 0.95);
  o += hollow();
  const cx = x + 0.2 * px * 0.1, cy = ground - flat.sk.T(0, 16).y * s;
  const ring = (rx, ry, a0, a1, w) => { const p = (a) => `${F(cx + rx * Math.cos(a * Math.PI / 180))},${F(cy - ry * Math.sin(a * Math.PI / 180))}`; return `<path d="M${p(a0)} A${F(rx)} ${F(ry)} 0 0 1 ${p(a1)}" fill="none" stroke="${c.rim}" stroke-width="${w}" stroke-linecap="round" opacity="0.85"/>`; };
  if (kind === 'regalia') o += ring(px * 0.3, px * 0.16, 200, 340, 2);
  if (kind === 'sovereign') o += ring(px * 0.34, px * 0.18, 200, 340, 2.2) + ring(px * 0.42, px * 0.22, 30, 150, 1.8) + ring(px * 0.26, px * 0.12, 20, 140, 1.6);
  return o;
}

// ---------------------------------------------------------------------------------------------------------- the audit
const MARKS = ['a crouch with fists clenched at the sides', 'a scream or a drawn-out chant', 'a flame-shaped body aura streaming upward', 'rubble rising in a ring, ground cracking and wind under a changing sky', 'crackling lightning on the body', 'hair rising or changing colour', 'a gold, white or red flash with a form name shouted'];
const AUDIT = [
  ['The transformation, new staging (gather, break, settle; this sheet)', [4], 'The ground cracks at the break only when he stands on it (part of mark 4); there is no crouch (he rises), no scream, a violet thin outline, no lightning, his hair is fixed, the flash is violet and he speaks a line, not a form name.', 'pass'],
  ['ma-3 staging, moment 3 (the old surge pose, before this pass)', [4], 'The pose was arms thrown wide with the head back, which 10.8 forbids (the snap is never that), and the blade crest rose over the head. Fixed in this pass: the surge now uses the settled, composed pose, and the crest is the low wide crest. Marks present now: only the ground shards at the feet (part of mark 4).', 'fixed'],
  ['Head flashes (any), the surge flash', [], 'A small pulse of shapes up and back of the head in the lane colour: no flame, no flash of gold, white or red, no form name. At most one mark in any frame.', 'pass'],
  ['The aura (this sheet, and the HUD crown)', [], 'A thin outline and rings in the lane colour, only while charging or attacking, never at rest, never upward streaming. It stands for no mark by itself; with a crouch and a scream it would be three, so the staging keeps the crouch and the scream out.', 'pass'],
  ['Damage sheet, the old Aura variant of round 3 (blank-variations.md)', [3], 'The round-3 "Aura" variant (not chosen) drew a standing aura of tall slabs. It is not in use: Orb chose Marked plus flashes, which has no standing aura.', 'retired'],
];

// ---------------------------------------------------------------------------------------------------------- the sheet
function sheet() {
  const W = 1800; let b = '', y = 0;
  const H = 2200;
  b += rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'The Anti-hero\'s three forms: Regalia, Sovereign, Apex', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'The pieces each form adds, the aura colours (hue 260 to 320, a lighter tint of the same hue for the core, never white), the three beats of the transformation, and the check against the stacking rule. Working labels, pending Legal review.', { size: 14, fill: '#cfc6e6' });
  y = 130;
  b += text(24, y, 'A. The three forms, at rest (no aura) and charging or attacking (the thin outline and rings)', { size: 17, weight: 700 });
  ['regalia', 'sovereign', 'apex'].forEach((f, i) => {
    const x0 = 24 + i * 592, form = FORMS[f];
    b += rect(x0, y + 12, 580, 440, '#e8e5ee', 'stroke="#1b1428" stroke-opacity="0.2"');
    b += text(x0 + 12, y + 34, form.name, { size: 16, weight: 700 }) + text(x0 + 568, y + 34, `hue ${form.hue}`, { size: 11, anchor: 'end', op: 0.7 });
    b += draw(f, POSES.rest, 260, x0 + 150, y + 420, { sigil: 'neutral' }).svg;
    b += auraLayer(f, POSES.attack, 260, x0 + 430, y + 420, f) + draw(f, POSES.attack, 260, x0 + 430, y + 420, { sigil: 'rage' }).svg;
    b += text(x0 + 150, y + 444, 'at rest', { size: 11, anchor: 'middle', op: 0.7 }) + text(x0 + 430, y + 444, 'attacking', { size: 11, anchor: 'middle', op: 0.7 });
    b += paras(x0 + 12, y + 60, form.pieces, 60, 11.5, 14, { op: 0.9 });
  });
  y += 480;
  b += text(24, y, 'B. The transformation beats (moveset-rules.md 10.8): he rises out of the crouch and goes still, one flick of the hand and the regalia locks on with a clack, then he settles and checks that the rival saw', { size: 17, weight: 700 });
  [['gather', 'The gather: rises, chin up, still, one hand palm-up. The aura is pulled in to the sigil; no regalia yet', null], ['break', 'The break: one dismissive flick, the collar and guards lock on in this frame, one thin ring leaves the body in his colour', 'regalia'], ['settle', 'The settle: composed, the new aura holds steady and thin, the line is spoken', 'regalia']].forEach(([k, cap, form], i) => {
    const x0 = 24 + i * 592, cx = x0 + 290;
    b += rect(x0, y + 12, 580, 400, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.2"');
    if (k === 'gather') {
      b += draw(null, POSES.gather, 250, cx, y + 380, { sigil: 'pride' }).svg;
      const hc = draw(null, POSES.gather, 250, cx, y + 380).sk.Hd(3, 10), px = cx + hc.x * 2.5, py = y + 380 - hc.y * 2.5;
      b += `<circle cx="${F(px)}" cy="${F(py)}" r="46" fill="none" stroke="${FORMS.regalia.c.rim}" stroke-width="1.6" opacity="0.8"/><circle cx="${F(px)}" cy="${F(py)}" r="30" fill="none" stroke="${FORMS.regalia.c.rim}" stroke-width="1.2" opacity="0.6"/>`;
    }
    if (k === 'break') {
      b += `<ellipse cx="${F(cx)}" cy="${F(y + 260)}" rx="170" ry="52" fill="none" stroke="${FORMS.regalia.c.rim}" stroke-width="3" opacity="0.8"/>`;
      b += draw('regalia', POSES.break, 250, cx, y + 380, { sigil: 'transform' }).svg;
    }
    if (k === 'settle') b += auraLayer('regalia', POSES.settle, 250, cx, y + 380, 'regalia', '#eeeaf4') + draw('regalia', POSES.settle, 250, cx, y + 380, { sigil: 'pride' }).svg;
    b += paras(x0 + 12, y + 36, cap, 70, 11.5, 14, { op: 0.9 });
  });
  y += 430;
  b += text(24, y, 'C. The colour values: the aura, the flashes and the power-stage glow for each form', { size: 17, weight: 700 });
  const rows = [['aura rim', 'rim'], ['aura core (a tint, never white)', 'core'], ['aura shadow', 'shadow'], ['keyline (the thin dark edge)', 'keyline'], ['sigil glow', 'sigil'], ['info flash core (keyline is the shadow)', 'info_core']];
  const x0 = 24, cw = 560; y += 16;
  ['regalia', 'sovereign', 'apex'].forEach((f, i) => {
    const form = FORMS[f], x = x0 + 250 + i * cw;
    b += text(x, y + 12, `${form.name} (hue ${form.hue})`, { size: 13, weight: 700 });
  });
  rows.forEach(([label, key], r) => {
    const yy = y + 24 + r * 30;
    b += text(x0, yy + 16, label, { size: 12, weight: 600 }) + `<line x1="24" y1="${yy + 24}" x2="1776" y2="${yy + 24}" stroke="#1b1428" stroke-opacity="0.12"/>`;
    ['regalia', 'sovereign', 'apex'].forEach((f, i) => { const x = x0 + 250 + i * cw, c = FORMS[f].c[key]; b += rect(x, yy + 2, 70, 20, c, 'stroke="#1b1428" stroke-opacity="0.35"') + text(x + 80, yy + 16, `${c}   hue ${Math.round(hueOf(c))}, L* ${Math.round(lstar(c))}`, { size: 11.5 }); });
  });
  y += 24 + rows.length * 30 + 8;
  b += text(24, y + 8, 'Deutan contrast of the aura rim against five backdrops (WCAG ratio; the keyline carries the rest, 3.0 reads):', { size: 12.5, weight: 700 });
  ['regalia', 'sovereign', 'apex'].forEach((f, i) => { const x = x0 + 250 + i * cw; b += text(x, y + 30, Object.entries(BACKDROPS).map(([k, v]) => `${k} ${cr(FORMS[f].c.rim, v, dlum).toFixed(1)}`).join(', '), { size: 10.5 }); });
  b += paras(24, y + 54, 'The rim alone is mid-value (L* 46 to 56), so it does not separate from the dusk rock or the grass by value: the thin dark keyline (L* 14 to 18) and the two-tone edge do, as for the fighter\'s body. The core is the lightest step and sits inside the outline. All three hues are inside Legal\'s 260 to 320 degrees; none is red, orange, gold, yellow or white, and none is a mid blue (water) or the Protagonist\'s teal.', 190, 12, 15, { op: 0.9 });
  y += 130;
  b += text(24, y, 'D. The stacking rule (Legal): no single moment shows more than two of the seven marks', { size: 17, weight: 700 });
  MARKS.forEach((m, i) => { b += text(24, y + 22 + i * 15, `${i + 1}. ${m}`, { size: 11, op: 0.85 }); });
  y += 22 + MARKS.length * 15 + 10;
  AUDIT.forEach(([moment, marks, why, verdict], i) => {
    const yy = y + i * 64;
    b += rect(24, yy, 1752, 58, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"') + text(34, yy + 18, moment, { size: 12, weight: 700 }) + text(1766, yy + 18, `marks present (by number above): ${marks.length ? marks.join(', ') : 'none'}  |  ${verdict}`, { size: 11.5, weight: 700, anchor: 'end' });
    b += paras(34, yy + 36, why, 230, 11, 13.5, { op: 0.9 });
  });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${y + AUDIT.length * 64 + 20}" viewBox="0 0 ${W} ${y + AUDIT.length * 64 + 20}">${b.replace(`height="${H}.00"`, `height="${y + AUDIT.length * 64 + 20}.00"`)}</svg>`;
}
const ORIGIN = '<!-- Origin: procedural concept sheet written by art/concepts/forms/gen.mjs (deterministic, no external images or fonts), Art Director session (Claude, claude-sonnet-5-5), 2026-10-01; prompt record art/prompts/ART-0010-rule-of-cool-art.md -->' + String.fromCharCode(10);
writeFileSync(join(OUT, 'anti-hero-forms.svg'), ORIGIN + sheet());
const data = {
  version: 1,
  note: 'The Anti-hero\'s aura, flash and glow colours for his three forms (Regalia, Sovereign, Apex), within Legal\'s aura rule: hue 260 to 320 degrees, a lighter tint of the same hue for the core, never pure white, no red, orange, gold or yellow (docs/legal/rule-of-cool-screen.md). Written by art/concepts/forms/gen.mjs (Art owns data/art/). Proposals pending Orb\'s preference and Legal.',
  hue_range: [260, 320],
  rules: { aura: 'Only while charging or attacking, never at rest. A thin outline of the silhouette and rings in the form\'s rim colour; never a flame, never streaming upward, no lightning. Core is the tint, never white (L* at most 86).', flashes: 'Emotion flashes use rim (mid) and core (light) of the current form; info flashes use info_core with the shadow as the keyline. The shapes, pulses and keep-out zone never change with the form.', glow: 'The sigil\'s emissive colour. It is brightest at Apex.' },
  anti_hero: { forms: Object.fromEntries(Object.entries(FORMS).map(([id, f]) => [id, { name: f.name, hue: f.hue, pieces: f.pieces, aura: { rim: f.c.rim, core: f.c.core, shadow: f.c.shadow, keyline: f.c.keyline }, flashes: { mid: f.c.rim, light: f.c.core, shadow: f.c.shadow, info_core: f.c.info_core, info_line: f.c.shadow }, glow: { sigil: f.c.sigil, halo: f.c.rim, halo_alpha: 0.35 } }])) },
};
writeFileSync(join(ROOT, 'data', 'art', 'auras.json'), JSON.stringify(data, null, 2) + String.fromCharCode(10));
console.log('wrote art/concepts/forms/anti-hero-forms.svg and data/art/auras.json');
