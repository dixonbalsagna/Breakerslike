// Origin: procedural sheet writer for the Anti-hero's glasses (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-10-02. Human direction: Orb, via the EP.
// Run from the repo root:  node art/concepts/refine/gen-glasses.mjs   (writes anti-hero-glasses.svg)

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { portrait } from '../closeups/engine.mjs';
import { FRAMES, glassedFace, profileGlasses } from './glasses.mjs';
import { drawFigure, POSE0, PAL } from './figures.mjs';
import { markedConcept } from '../shared/styled.mjs';

const OUT = dirname(fileURLToPath(import.meta.url));
const F = n => n.toFixed(2);
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family=\"'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif\"";
const text = (x, y, t, { size = 14, weight = 400, fill = '#1b1428', anchor = 'start', op = 1 } = {}) => `<text x="${F(x)}" y="${F(y)}" ${FONT} font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}" opacity="${op}">${esc(t)}</text>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fill}" ${extra}/>`;
const wrap = (t, n) => { const w = t.split(' '), out = []; let line = ''; for (const x of w) { if ((line + ' ' + x).trim().length > n) { out.push(line.trim()); line = x; } else line += ' ' + x; } if (line.trim()) out.push(line.trim()); return out; };
const paras = (x, y, t, n, size = 12, gap = 15, o = {}) => wrap(t, n).map((l, i) => text(x, y + i * gap, l, { size, ...o })).join('');
const header = (title, sub, W) => rect(0, 0, W, 104, '#1b1428') + text(30, 46, title, { size: 30, weight: 700, fill: '#f4f0fa' }) + paras(30, 72, sub, 210, 14, 18, { fill: '#cfc6e6' });
const BG = '#e8e5ee';
const GREY = '<defs><filter id="grey"><feColorMatrix type="saturate" values="0"/></filter></defs>';
let uid = 0;
const EXPR_OF = { clear: 'neutral', glare: 'smirk', glint: 'neutral' };
const face = (key, state, x, y, size, o = {}, extra = '') => `<svg x="${F(x)}" y="${F(y)}" width="${size}" height="${size}" viewBox="0 0 512 512" overflow="hidden" ${extra}>${portrait('X', 'A', o.expr ?? EXPR_OF[state], `q${uid++}`, { draw: glassedFace(key, state, o.stage ?? 0, o.t ?? 0.4) })}</svg>`;
// a 12 px high read of the eye band (the HUD portrait's smallest size)
const band = (key, state, x, y, h, extra = '') => { const id = `q${uid++}`; return `<svg x="${F(x)}" y="${F(y)}" width="${F(h * 4.46)}" height="${h}" viewBox="96 226 330 74" overflow="hidden" ${extra}><clipPath id="bc-${id}"><rect x="96" y="226" width="330" height="74"/></clipPath><g clip-path="url(#bc-${id})">${portrait('X', 'A', EXPR_OF[state], id, { draw: glassedFace(key, state, 0, 0.4) })}</g></svg>`; };
function glassedFigure(key, state, x, ground, s, flat = false) {
  const c = markedConcept('A'), prev = c.after, add = profileGlasses(key, state);
  const concept = { ...c, after: (ctx, sk, st, cfg) => (prev ? prev(ctx, sk, st, cfg) : '') + add(ctx, sk) };
  return drawFigure({ concept, pal: PAL.A, pose: POSE0('A'), flat, bg: BG, x, ground, s });
}

const FR = [
  ['cuthex', 'A hexagonal lens cut asymmetrically (one corner chopped long, the outer corner a point): his hexagon in its smallest, most ordinary form.'],
  ['blade', 'Tapered wedge lenses with a sharp outer tip, the tips level, never upswept: the most blade-like, and the best at fight size.'],
  ['chamfer', 'Chamfered plates (the portrait frame\'s own cut corners, opposite corners cut): quiet and generous; the least dramatic glare.'],
  ['shard', 'A tapered shard, wide at the nose and pointed at the temple: the coldest silhouette; reads almost as a slash of tint at 12 px.'],
  ['slash', 'A five-sided slash cut, no two sides parallel: the most unusual, and the one least like any ordinary glasses.'],
  ['kite', 'A kite with the high point toward the nose: a different rhythm to the others; the glare wedge sits well in it.'],
];
const LEAD = ['blade', 'cuthex'];
const DROPPED = 'Dropped for Legal (RL-066): thin round wire lenses, narrow tinted rectangles (my slits), a half-rim with a brow bar, and the single bar across both eyes (a visor). Lenses are never a display: no readout, scan bar or overlay, and the earlier scan-like streaks are gone.';
const WHERE = [
  ['The staredown (the round intro, the camera push-in)', 'a single glint sweeps across the lenses once, eyes dimly visible: he is watching you.'],
  ['His taunt', 'the glare for 0.4 s with the smirk as the only face, then it clears.'],
  ['Entering On the Chin', 'the glare on the entry beat (he reads the blow), 0.4 s, then it clears.'],
  ['A signature or a finisher', 'a glint at the very start of the wind-up only; never a glare during the charge, a rubble ring or lightning (that would stack marks).'],
  ['Pride thresholds', 'each threshold crossed gives a glint, then a one-lens flash, then a full glare at the top: more Pride, more glare. Each is 0.4 s at most.'],
  ['The seal break (the Proud front breaks)', 'the lens cracks (stage 2 below) and the glare falters. Never at a transformation break, and never with a shouted form name.'],
];
const RULES = 'Rules for VFX (RL-066): a quick attack and a hold of 0.4 s at most, then clear; key moments only (reading a move, pride, a taunt, the seal break), never every exchange; at most one glare in any 3 s. The glare is one hard-edged wedge in a pale violet, never white, gold, orange or red, never a round disc with a star. One slow fade in and out, no strobing (photosensitivity); with reduced motion it is a held tint with no sweep.';

function sheet() {
  const W = 1800, CW = 590, CH = 452, S2 = 340, H = 124 + 2 * CH + 40 + 2 * S2 + 30 + 340 + 250 + 2 * 214 + 160 + 80;
  let b = rect(0, 0, W, H, '#dcd8e6') + header('The Anti-hero\'s glasses: scary shiny glasses', 'Orb: the rival is our resident scary shiny glasses character. Six frames in his blade and plate language; the best two in three lens states (clear, glare, glint); where the glare fires; and what battle damage does. Unmasked faces (the masks stay parked). Working labels, pending Legal review.', W);
  // 1. six frames
  b += text(24, 142, '1. Six frames to Legal\'s rules (clear and glare; at 72, 24 and 12 px; and in profile at fight size)', { size: 15, weight: 700 }) + paras(740, 142, DROPPED, 200, 11, 14, { op: 0.8, fill: '#7a3b3b' });
  FR.forEach(([k, line], i) => {
    const x0 = 24 + (i % 3) * (CW + 6), y0 = 174 + Math.floor(i / 3) * CH;
    b += rect(x0, y0, CW, CH - 8, BG, 'stroke="#1b1428" stroke-opacity="0.2"') + text(x0 + 12, y0 + 24, `${i + 1}  ${FRAMES[k].name}`, { size: 16, weight: 700 }) + (LEAD.includes(k) ? text(x0 + CW - 12, y0 + 24, 'one of the best two', { size: 12, weight: 700, anchor: 'end', fill: '#6b3fa8' }) : '');
    b += face(k, 'clear', x0 + 10, y0 + 34, 200) + face(k, 'glare', x0 + 216, y0 + 34, 200);
    b += glassedFigure(k, 'clear', x0 + 452, y0 + 230, 1.2) + glassedFigure(k, 'glare', x0 + 540, y0 + 230, 1.2);
    b += text(x0 + 430, y0 + 248, 'profile, clear and glare', { size: 10, op: 0.65 });
    const ry = y0 + 252;
    b += text(x0 + 12, ry + 14, '72 and 24 px', { size: 10, op: 0.65 }) + face(k, 'clear', x0 + 12, ry + 20, 72) + face(k, 'glare', x0 + 90, ry + 20, 72) + face(k, 'clear', x0 + 168, ry + 56, 36) + face(k, 'glare', x0 + 210, ry + 56, 36);
    b += text(x0 + 260, ry + 14, '12 px eye band: clear, glare (and in grey)', { size: 10, op: 0.65 });
    b += band(k, 'clear', x0 + 260, ry + 24, 12) + band(k, 'glare', x0 + 320, ry + 24, 12) + band(k, 'clear', x0 + 260, ry + 44, 12, 'filter="url(#grey)"') + band(k, 'glare', x0 + 320, ry + 44, 12, 'filter="url(#grey)"');
    b += paras(x0 + 260, ry + 86, line, 50, 11.5, 14.5);
  });
  // 2. the best two in three states
  let y = 174 + 2 * CH + 24;
  b += text(24, y, '2. The best two: clear, glare, glint (the glint sweeps left to right across both lenses in about 0.5 s; three moments are shown)', { size: 15, weight: 700 });
  LEAD.forEach((k, r) => {
    const y0 = y + 14 + r * S2;
    b += rect(24, y0, W - 48, S2 - 10, BG, 'stroke="#1b1428" stroke-opacity="0.2"') + text(40, y0 + 24, `${FRAMES[k].name}${r === 0 ? ' (the lead)' : ' (the second)'}`, { size: 16, weight: 700 });
    ['clear', 'glare', 'glint'].forEach((st, c) => { b += face(k, st, 40 + c * 262, y0 + 36, 250) + paras(46 + c * 262, y0 + 306, { clear: 'clear: a dark violet tint, eyes dimly visible', glare: 'glare: the lens opaque, one hard-edged pale wedge, eyes hidden; the smirk carries the face (0.4 s at most)', glint: 'glint: one moving wedge on the clear lens, eyes dimly visible' }[st], 44, 11, 13, { weight: 600, op: 0.8 }); });
    [0.15, 0.5, 0.85].forEach((t, c) => { b += face(k, 'glint', 840 + c * 160, y0 + 36, 150, { t }); });
    b += text(840, y0 + 202, 'the glint sweep: start, middle, end', { size: 10, op: 0.65 });
    b += glassedFigure(k, 'clear', 1400, y0 + 270, 2.3) + glassedFigure(k, 'glare', 1560, y0 + 270, 2.3) + text(1360, y0 + 292, 'profile at fight size: clear, then glare', { size: 10, op: 0.65 });
    b += paras(840, y0 + 224, r === 0 ? 'The lead: tapered wedge lenses with level tips, cut asymmetrically. The glare wedge follows the lens, and the tips give the face a blade line even when the lenses are clear.' : 'The second: a hexagon cut asymmetrically: his lit hexagon in its quietest form. If Orb wants the glasses to look almost ordinary until the glare, this is it.', 70, 12, 15, { op: 0.9 });
  });
  // his gesture
  y = y + 14 + 2 * S2 + 6;
  b += text(24, y + 8, 'His gesture (Legal: a nudge at the temple arm, or with the back of the forearm plate; never one finger at the bridge, never folded or steepled hands before the face)', { size: 15, weight: 700 });
  const gst = (k, st, pose, x, label) => { const c = markedConcept('A'), prev = c.after, add = profileGlasses(k, st); const concept = { ...c, after: (ctx, sk, stt, cfg) => (prev ? prev(ctx, sk, stt, cfg) : '') + add(ctx, sk) }; return drawFigure({ concept, pal: PAL.A, pose, flat: false, bg: BG, x, ground: y + 250, s: 2.1 }) + text(x - 80, y + 272, label, { size: 11, op: 0.8 }); };
  const base = POSE0('A');
  b += gst('blade', 'glare', { ...base, nearArm: [55, 172], handNear: 'open' }, 120, 'a nudge at the temple arm (glare)');
  b += gst('blade', 'glare', { ...base, nearArm: [95, 195], handNear: 'fist' }, 380, 'the back of the forearm plate (glare)');
  b += paras(520, y + 60, 'The glare fires on the nudge: the hand or forearm comes up to the temple, the lens flashes for 0.4 s, and the arm drops. The same gesture without the glare is his idle tell when Pride is rising. It is never done with a finger at the bridge, and the hands are never folded or steepled in front of the face or mouth. Lines said with it come from Narrative\'s bank in his own voice: none of the stock lines that go with the trope.', 120, 12.5, 17, { op: 0.9 });
  y += 300;
  // 3. where the glare fires
  b += text(24, y + 14, '3. Where the glare fires (for Game Design and VFX)', { size: 15, weight: 700 });
  WHERE.forEach(([a, t], i) => { b += text(24, y + 38 + i * 30, a, { size: 12.5, weight: 700 }) + paras(420, y + 38 + i * 30, t, 170, 12, 15, { op: 0.9 }); });
  b += paras(24, y + 38 + WHERE.length * 30 + 4, RULES, 230, 12, 16, { op: 0.85, fill: '#6b3fa8' });
  // 4. damage
  y = y + 38 + WHERE.length * 30 + 52;
  b += text(24, y, '4. What battle damage does to them (the lead above, the second below): fresh, stage 1 scuffed, stage 2 torn, stage 3 ruined, each in clear and in glare; and glasses knocked off by a hit (both allowed)', { size: 15, weight: 700 });
  LEAD.forEach((k, r) => {
    const y0 = y + 14 + r * 214;
    [0, 1, 2, 3].forEach(st => { b += face(k, 'clear', 24 + st * 316, y0, 150, { stage: st }) + face(k, 'glare', 24 + st * 316 + 156, y0, 150, { stage: st }); b += text(24 + st * 316 + 4, y0 + 168, ['fresh', 'stage 1: scuffed', 'stage 2: torn', 'stage 3: ruined'][st], { size: 11, weight: 600, op: 0.8 }); });
    b += face(k, 'off', 24 + 4 * 316 + 6, y0, 150, { stage: 1, expr: 'hurt' }) + text(24 + 4 * 316 + 10, y0 + 168, 'knocked off by a hit', { size: 11, weight: 600, op: 0.8 });
  });
  b += paras(24, y + 14 + 2 * 214 + 4, 'Stage 1: a hairline scratch across one lens and a nick on the rim; the glare still works. Stage 2: a single crack runs across the far lens and the far half of the frame bends and tilts; the glare gets a dark line in it. Stage 3: the near lens cracks twice, a shard is gone from the far lens (the eye shows through the gap even in glare), the frame is bent and dropped, the bridge twists. Cracks never cross, and the glare falters: it is the first thing a beaten Pride loses. A cracked lens and glasses knocked off by a hit are both fine under the rules and count as no mark.', 230, 12, 15, { op: 0.9 });
  // 5. legal and questions
  y = y + 14 + 2 * 214 + 52;
  b += text(24, y, 'For Legal, and for Orb', { size: 15, weight: 700 });
  b += paras(24, y + 22, 'Legal (RL-066), how each rule is met: angular, tapered and hexagonal lenses cut asymmetrically in a thin violet frame (none round, none a narrow rectangle, no half-rim, no visor bar); normal lenses a dark violet tint; no goatee or beard; no readout, scan bar or overlay on any lens; the glare is one hard-edged wedge in a pale violet (not white, never gold, orange or red) with no disc and no star, held 0.4 s at most, at key moments only, never at a transformation break; the gesture is a nudge at the temple arm or the back of the forearm, never one finger at the bridge and never folded hands. Legal looks at the six frames, the glare wedge and the gesture sketch.', 230, 12, 16, { op: 0.9 });
  b += paras(24, y + 118, 'Orb: which frame (the lead blade lenses, the cut hex, or one of the other four)? Should the glare hide his eyes completely (as drawn) or leave a faint eye shape? Are the glasses always on, or do they appear for the taunt and the seal break only? The face stays recognisably him: the tail, the lit slash, the sharp eyes.', 230, 12, 16, { op: 0.9 });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${GREY}${b}</svg>`;
}
const ORIGIN = '<!-- Origin: procedural glasses sheet written by art/concepts/refine/gen-glasses.mjs (deterministic, no external images or fonts), Art Director session (Claude, claude-sonnet-5-5), 2026-10-02; prompt record art/prompts/ART-0014-anti-hero-glasses.md -->' + String.fromCharCode(10);
writeFileSync(join(OUT, 'anti-hero-glasses.svg'), ORIGIN + sheet());
console.log('wrote anti-hero-glasses.svg');
