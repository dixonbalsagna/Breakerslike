// Origin: procedural generator for the face cut-in portraits (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-10-01. Human direction: Orb, via the EP. Everything is original: blank-mask heads, our own frame.
// Run from the repo root:  node art/concepts/faces/gen.mjs   (writes faces-1-anti-hero.svg, faces-2-others.svg and portraits/<id>_<expression>.svg, 16 square SVGs of 512 units)
// Brief: docs/art/rule-of-cool-art.md. UI draws these at the side of the screen when a fighter speaks (docs/ui/hud-spec.md section 29).

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeCtx, figure } from '../anti-hero/kit.mjs';
import { PAL, MASK, NAMES } from '../shared/marks.mjs';
import { markedConcept } from '../shared/styled.mjs';

const OUT = dirname(fileURLToPath(import.meta.url));
const F = n => n.toFixed(2);
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family=\"'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif\"";
const text = (x, y, t, { size = 14, weight = 400, fill = '#1b1428', anchor = 'start', op = 1 } = {}) => `<text x="${F(x)}" y="${F(y)}" ${FONT} font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}" opacity="${op}">${esc(t)}</text>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fill}" ${extra}/>`;
const wrap = (t, n) => { const w = t.split(' '), out = []; let line = ''; for (const x of w) { if ((line + ' ' + x).trim().length > n) { out.push(line.trim()); line = x; } else line += ' ' + x; } if (line.trim()) out.push(line.trim()); return out; };
const paras = (x, y, t, n, size = 13, gap = 17, o = {}) => wrap(t, n).map((l, i) => text(x, y + i * gap, l, { size, ...o })).join('');

export const IDS = { P: 'protagonist', A: 'anti_hero', E: 'empress', C: 'cyborg' };
const EXPR = ['neutral', 'smirk', 'strain', 'hurt'];
// Expression comes from the head tilt and the sigil, never a drawn face (the masks have none): neutral level and still; smirk chin up and back with the sigil
// tilted; strain the head forward and low with the sigil flared and lit; hurt the head down and turned away with the sigil dim and broken.
const POSE = {
  neutral: { lean: 2, head: 0, sigil: 'neutral' },
  smirk: { lean: -5, head: -13, sigil: 'taunt' },
  strain: { lean: 13, head: 11, sigil: 'rage' },
  hurt: { lean: 17, head: 27, sigil: 'hurt' },
};
// the frame: our own, a chamfered square (two opposite corners cut, so it is an angular facet and not a rounded screen), a flat lane-colour ground
// with a few large flat shapes of the fighter's family, an inner keyline and one short accent bar. No scanlines, no static, no green tint.
const FRAME = {
  P: { bg: '#2e6470', shape: '#3d7c88', line: '#8fd6c8', bar: '#8fd6c8', family: 'circles' },
  A: { bg: '#cbbdf0', shape: '#b7a3e8', line: '#5b479a', bar: '#9a80d8', family: 'blades' },
  E: { bg: '#4a5a2a', shape: '#5b6d35', line: '#dfe8a8', bar: '#b8c96a', family: 'wedges' },
  C: { bg: '#e8c9c2', shape: '#f0b4a8', line: '#8a3a30', bar: '#d8705f', family: 'steps' },
};
const HEADC = { P: [3.2, 9.4], A: [3.2, 9.4], E: [1.6, 12.2], C: [3.2, 9.4] };
const YAW = 50, S = 15;

function ground(fk) {
  const f = FRAME[fk]; let o = '';
  if (f.family === 'circles') o += `<circle cx="120" cy="150" r="150" fill="${f.shape}"/><circle cx="430" cy="380" r="110" fill="${f.shape}"/><circle cx="360" cy="60" r="46" fill="${f.shape}"/>`;
  if (f.family === 'blades') o += `<polygon points="330,0 400,0 190,512 110,512" fill="${f.shape}"/><polygon points="470,0 512,0 512,120 330,512 290,512" fill="${f.shape}"/><polygon points="0,260 60,200 60,512 0,512" fill="${f.shape}"/>`;
  if (f.family === 'wedges') o += `<polygon points="0,512 260,120 380,512" fill="${f.shape}"/><polygon points="512,512 512,150 330,512" fill="${f.shape}"/><polygon points="0,0 170,0 0,200" fill="${f.shape}"/>`;
  if (f.family === 'steps') o += [[300, 400, 212, 112], [372, 328, 140, 72], [444, 256, 68, 72], [20, 20, 90, 90], [110, 110, 60, 60]].map(([x, y, w, h]) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${f.shape}"/>`).join('');
  return o;
}
// one portrait as a 512 x 512 SVG group
export function portrait(fk, expr, id) {
  const pal = PAL[fk], p = POSE[expr], f = FRAME[fk], sway = 6;
  const ctx = makeCtx({ flat: false, pal, swMul: 1.6, faceless: true });
  const pose = { lean: p.lean, head: p.head, nearArm: [10, 8], farArm: [-10, -8], nearLeg: [3, 1], farLeg: [-3, -1], handNear: 'fist', handFar: 'fist' };
  const st = { yaw: YAW, state: 'neutral', sigil: p.sigil, sway, expression: 'neutral', open: expr === 'strain' ? 1 : expr === 'hurt' ? 0.4 : 0, forms: 6, wear: 0, hairLoose: expr === 'strain' || expr === 'hurt' };
  const { svg, sk } = figure(ctx, markedConcept(fk), pose, st, { yaw: YAW });
  const h = sk.Hd(HEADC[fk][0], HEADC[fk][1]);
  const cid = `fc-${id}-${expr}`;
  const poly = '30,0 512,0 512,482 482,512 0,512 0,30';
  return `<defs><clipPath id="${cid}"><polygon points="${poly}"/></clipPath></defs>` +
    `<g clip-path="url(#${cid})">${rect(0, 0, 512, 512, f.bg)}${ground(fk)}<g transform="translate(${F(256 - h.x * S + (fk === 'E' ? 20 : 0))} ${F(262 + h.y * S)}) scale(${S} ${-S})">${svg}</g>` +
    `${rect(0, 478, 512, 34, '#000', 'opacity="0.0"')}</g>` +
    `<polygon points="${poly}" fill="none" stroke="${f.line}" stroke-width="10" stroke-linejoin="miter"/>` +
    `<polygon points="${poly}" fill="none" stroke="#14101f" stroke-width="2" stroke-linejoin="miter" transform="translate(0 0)"/>` +
    rect(360, 470, 118, 12, f.bar, 'stroke="#14101f" stroke-width="2"');
}
const svgOf = (fk, expr, id) => `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">${portrait(fk, expr, id)}</svg>`;
const place = (fk, expr, x, y, size, id, extra = '') => `<svg x="${F(x)}" y="${F(y)}" width="${size}" height="${size}" viewBox="0 0 512 512" overflow="hidden" ${extra}>${portrait(fk, expr, id)}</svg>`;
const ORIGIN = '<!-- Origin: procedural face cut-in portrait written by art/concepts/faces/gen.mjs (deterministic, no external images or fonts), Art Director session (Claude, claude-sonnet-5-5), 2026-10-01; prompt record art/prompts/ART-0010-rule-of-cool-art.md -->' + String.fromCharCode(10);

const GREY = '<defs><filter id="grey"><feColorMatrix type="saturate" values="0"/></filter></defs>';
function sheet1() {
  const W = 1800, H = 1120;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'Face cut-in portraits: the Anti-hero', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'Four expressions, 512 units square, face centred and the shoulders cropped by the frame. The mask has no face, so the head, the sigil and the frame carry the line. Working labels, pending Legal review.', { size: 15, fill: '#cfc6e6' });
  b += text(24, 138, 'The four expressions at 420 px (the sheet), each a 512-unit square', { size: 17, weight: 700 });
  EXPR.forEach((e, i) => { const x = 24 + i * 442; b += place('A', e, x, 150, 420, `a${i}`) + text(x + 8, 590, e, { size: 15, weight: 700 }); });
  b += text(24, 626, 'Readable at 200 px and at 120 px (the cut-in is about 200 px at 1080p), in colour and in greyscale', { size: 17, weight: 700 });
  EXPR.forEach((e, i) => { const x = 24 + i * 222; b += place('A', e, x, 640, 200, `b${i}`) + place('A', e, x + 4 * 222 - 24 + 24, 640, 200, `c${i}`, 'filter="url(#grey)"'); });
  EXPR.forEach((e, i) => { const x = 24 + i * 132; b += place('A', e, x, 856, 120, `d${i}`); });
  b += paras(24, 1000, 'How the expression reads with no face. Neutral: head level, the sigil upright. Smirk: chin up and back, the sigil tilted and sitting low (the same flick as his taunt). Strain: head forward and low, the sigil flared and lit. Hurt: head down and turned away, the sigil dim with a gap in it. At 120 px the head angle and the sigil still separate all four.', 150, 12.5, 16);
  b += paras(24, 1050, 'The frame is our own: a chamfered square with two opposite corners cut, a flat lane-colour ground with large flat blades (his shape family), a thin inner keyline and one short accent bar. There is no scanline, no static and no green tint. The art faces right (toward the middle of the screen from the left side); UI mirrors it for the right-hand speaker.', 150, 12.5, 16);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${GREY}${b}</svg>`;
}
function sheet2() {
  const W = 1800, ps = 320, H = 130 + 3 * (ps + 76) + 120;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'Face cut-in portraits: the Protagonist, the Empress and the Cyborg', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'The same four expressions and the same frame, in each fighter\'s own lane and shape family. Pale masks sit on a dark lane ground and dark masks on a light one, so the mask always separates. KAI and VORR use these as their stand-ins.', { size: 15, fill: '#cfc6e6' });
  ['P', 'E', 'C'].forEach((fk, r) => {
    const y0 = 130 + r * (ps + 76);
    b += text(24, y0 + 14, `${NAMES[fk]} (${IDS[fk]})`, { size: 17, weight: 700 });
    EXPR.forEach((e, i) => { const x = 24 + i * (ps + 10); b += place(fk, e, x, y0 + 24, ps, `${fk}${i}`) + text(x + 6, y0 + 24 + ps + 16, e, { size: 12.5, weight: 600, op: 0.8 }); });
    EXPR.forEach((e, i) => { b += place(fk, e, 24 + 4 * (ps + 10) + 20 + i * 98, y0 + 24, 92, `${fk}s${i}`); b += place(fk, e, 24 + 4 * (ps + 10) + 20 + i * 98, y0 + 124, 92, `${fk}g${i}`, 'filter="url(#grey)"'); });
    b += text(24 + 4 * (ps + 10) + 20, y0 + 238, 'at 92 px, colour and greyscale', { size: 11, op: 0.7 });
  });
  const y = 130 + 3 * (ps + 76) + 10;
  b += paras(24, y, 'Readable at 200 px: yes for all twelve, by the head angle, the sigil state and the frame lane. At 100 px the four expressions of each fighter still differ (the chin and the sigil), and in greyscale the mask still separates from the ground. The Cyborg is a box head, so his expressions lean on a hard tilt and the sigil together.', 150, 12.5, 16);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${GREY}${b}</svg>`;
}
mkdirSync(join(OUT, 'portraits'), { recursive: true });
for (const fk of Object.keys(IDS)) for (const e of EXPR) writeFileSync(join(OUT, 'portraits', `${IDS[fk]}_${e}.svg`), ORIGIN + svgOf(fk, e, `${fk}${e}`));
writeFileSync(join(OUT, 'faces-1-anti-hero.svg'), ORIGIN + sheet1());
writeFileSync(join(OUT, 'faces-2-others.svg'), ORIGIN + sheet2());
console.log('wrote faces-1-anti-hero.svg, faces-2-others.svg and 16 portraits');
