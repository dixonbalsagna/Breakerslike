// Origin: procedural sheet writer for the refinement sheets (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-10-02. Human direction: Orb, via the EP.
// Run from the repo root:  node art/concepts/refine/gen.mjs   (writes cyborg-directions.svg, protagonist-refine.svg, anti-hero-refine.svg, empress-refine.svg)
// Orb's art direction (2026-10-02): masks and broken masks are for one future character, not the house style; the unmasked faces and the silhouettes are the base to refine, the Cyborg first.

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { portrait } from '../closeups/engine.mjs';
import * as FA from './faces.mjs';
import { CYBORG_DIRS, OTHER_OPTS, drawFigure, POSE0, PAL } from './figures.mjs';
import { markedConcept } from '../shared/styled.mjs';

const OUT = dirname(fileURLToPath(import.meta.url));
const F = n => n.toFixed(2);
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family=\"'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif\"";
const text = (x, y, t, { size = 14, weight = 400, fill = '#1b1428', anchor = 'start', op = 1 } = {}) => `<text x="${F(x)}" y="${F(y)}" ${FONT} font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}" opacity="${op}">${esc(t)}</text>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fill}" ${extra}/>`;
const wrap = (t, n) => { const w = t.split(' '), out = []; let line = ''; for (const x of w) { if ((line + ' ' + x).trim().length > n) { out.push(line.trim()); line = x; } else line += ' ' + x; } if (line.trim()) out.push(line.trim()); return out; };
const paras = (x, y, t, n, size = 12, gap = 15, o = {}) => wrap(t, n).map((l, i) => text(x, y + i * gap, l, { size, ...o })).join('');
const header = (title, sub, W) => rect(0, 0, W, 104, '#1b1428') + text(30, 46, title, { size: 30, weight: 700, fill: '#f4f0fa' }) + paras(30, 72, sub, 200, 14, 18, { fill: '#cfc6e6' });
const MAIL = '<pattern id="mail" width="3.2" height="3.2" patternUnits="userSpaceOnUse"><circle cx="1.6" cy="1.6" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/><circle cx="0" cy="0" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/><circle cx="3.2" cy="3.2" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/></pattern>';
const BG = '#e8e5ee';
let uid = 0;
const face = (kind, fk, expr, x, y, size, draw) => `<svg x="${F(x)}" y="${F(y)}" width="${size}" height="${size}" viewBox="0 0 512 512" overflow="hidden">${draw ? portrait('X', fk, expr, `r${uid++}`, { draw }) : portrait('C', fk, expr, `r${uid++}`)}</svg>`;
const fig = (c, pal, pose, x, ground, s, flat) => drawFigure({ concept: c, pal, pose, flat, bg: BG, x, ground, s });
const cy = k => { const d = CYBORG_DIRS[k], pal = d.pal(); return { pal, concept: d.concept(pal), pose: d.pose ?? POSE0('C'), name: d.name }; };
const other = fk => ({ pal: PAL[fk], concept: OTHER_OPTS[fk].base(), pose: POSE0(fk) });

// ------------------------------------------------------------------------------------------------------------------- the Cyborg
const CY = [
  ['stepper', 'The Stepper', 'Same fighter, sharpened', FA.cyStepper, 'He is a staircase: a stepped crown, a stair-split face, a flight of steps rising behind him, light plates on a dark body (the value split he lacks today).', 'Screen: the lit pale eye on the display third (the cleared pattern); the stair split stays diagonal.'],
  ['stack', 'The Stack', 'Same fighter, bolder build', FA.cyStack, 'He is built from blocks that slide. The face is three plates that shift with feeling, so a hit visibly knocks him out of true; steps become how he is made.', 'Screen: nothing new (flat blocks, no eye on metal); check the human band reads as a person, not a robot mask.'],
  ['furnace', 'The Furnace', 'A heavier cousin', FA.cyFurnace, 'A mountain with a small sunk head, humped shoulders and gauntlets like anvils; heat is his motif and the pale vents glow when he is pushed. Slow, huge, unmistakable at 24 px.', 'Screen: the vent mouth and sunk eyes against any known heavy robot; no red glow (pale only).'],
  ['frame', 'The Frame', 'Bolder: a person in a machine', FA.cyFrame, 'A person held in an open frame: you see the world through his chest, and his face is a human face in a window. Tall, lean, nothing like the box soldier.', 'Screen: a face in a rectangular frame (a monitor or a photo frame): low risk; no visor, no goggles.'],
  ['worker', 'The Prosthetic', 'Same fighter, humane', FA.cyWorker, 'A working man with one enormous hydraulic arm and a plate leg. The lopsided silhouette is the hook, and the face is warm. The machine is a tool he wears.', 'Screen: the pale eye in the cheek plate (small, on a human face, not a metal half); no bolts or stitches.'],
  ['runner', 'The Sprinter', 'Bolder: a tempo change', FA.cyRunner, 'A lean runner on spring legs with blade feet and swept hair: the one fast Cyborg. It changes how he fights, not only how he looks.', 'Screen: blade legs (a generic athlete prosthetic); the swept hair is smooth, never spiky.'],
];
function cyborgSheet() {
  const W = 1800, CW = 590, CH = 590, why = 400, H = 124 + why + 2 * CH + 150;
  let b = rect(0, 0, W, H, '#dcd8e6') + header('The Cyborg: why he reads as generic, and six directions', 'Orb: the Cyborg looks generic and is the least compelling of the launch fighters; focus here first. Each direction shows the silhouette at fight size (colour, then flat black at 120 and 40 px), and the face at cut-in size (neutral and hurt). Working labels, pending Legal review. Orb picks, or mixes.', W);
  // why generic
  const cur = cy('current'), y0 = 124;
  b += rect(24, y0, W - 48, why - 14, BG, 'stroke="#1b1428" stroke-opacity="0.2"') + text(40, y0 + 28, 'Why he reads as generic', { size: 18, weight: 700 });
  b += fig(cur.concept, cur.pal, cur.pose, 90, y0 + 290, 2.4, false) + fig(cur.concept, cur.pal, cur.pose, 230, y0 + 290, 2.4, true);
  b += face('C', 'C', 'neutral', 330, y0 + 50, 190) + face('C', 'C', 'hurt', 530, y0 + 50, 190);
  b += text(335, y0 + 252, 'his face today: neutral and hurt', { size: 11, op: 0.7 });
  // the silhouette test: the four at 90 px flat
  [['P', 'Protagonist'], ['A', 'Anti-hero'], ['E', 'Empress'], ['C', 'Cyborg']].forEach(([fk, nm], i) => {
    const o = fk === 'C' ? cur : other(fk); b += fig(o.concept, o.pal, o.pose, 380 + i * 110, y0 + 370, 0.8, true) + text(380 + i * 110, y0 + 384, nm, { size: 10, anchor: 'middle', op: 0.7 });
  });
  b += text(335, y0 + 280, 'the four fighters flat black at 80 px: three have a hook, one is a box', { size: 11, op: 0.7 });
  const reasons = [
    ['Silhouette.', 'A rectangle on a rectangle: a box head on a wide box torso. His extras (a backpack, a mail apron) are small and sit inside the outline, so flat black at 40 px he is a block with arms. The others each have a shape that sticks out (a tuft, a tail, a topknot and mantle).'],
    ['Face.', 'He has none: a display box. The close-up work gave him the half-human, half-metal face with one lit eye, which is the most common cyborg face there is.'],
    ['Palette and value.', 'Dark maroon plating, dark limbs, grey gear, a coral accent: the stock dark-armoured soldier, and dark on dark so the figure has no value structure. The others each have one clear light and one clear dark.'],
    ['Motif.', 'The stair of squares says "digital", which every robot says. It is not tied to what he does, how he moves or who he is.'],
    ['No hook in the story.', 'Nothing says what kind of person or machine he is, or how he fights. The Protagonist is bright and open, the Anti-hero is a cold slash, the Empress is a regal wedge. He is a heavy soldier.'],
  ];
  let ry = y0 + 52; reasons.forEach(([h, t]) => { b += text(760, ry, h, { size: 13, weight: 700 }) + paras(760, ry + 16, t, 150, 12, 15, { op: 0.9 }); ry += 18 + wrap(t, 150).length * 15 + 8; });
  // the six
  CY.forEach(([k, name, tag, faceFn, line, legal], i) => {
    const x0 = 24 + (i % 3) * (CW + 6), y1 = y0 + why + Math.floor(i / 3) * CH, d = cy(k);
    b += rect(x0, y1, CW, CH - 8, BG, 'stroke="#1b1428" stroke-opacity="0.2"') + text(x0 + 14, y1 + 26, `${i + 1}  ${name}`, { size: 17, weight: 700 }) + text(x0 + CW - 14, y1 + 26, tag, { size: 12, weight: 600, anchor: 'end', fill: ['Same fighter, sharpened', 'Same fighter, bolder build', 'Same fighter, humane'].includes(tag) ? '#2f6f4f' : '#7a4a9a' });
    b += fig(d.concept, d.pal, d.pose, x0 + 120, y1 + 290, 2.5, false) + fig(d.concept, d.pal, d.pose, x0 + 330, y1 + 290, 1.2, true) + fig(d.concept, d.pal, d.pose, x0 + 450, y1 + 290, 0.5, true);
    b += text(x0 + 330, y1 + 306, 'flat at 120 and 40 px', { size: 10, op: 0.65 });
    b += face('X', 'C', 'neutral', x0 + 10, y1 + 320, 190, faceFn) + face('X', 'C', 'hurt', x0 + 206, y1 + 320, 190, faceFn);
    b += paras(x0 + 410, y1 + 338, line, 26, 11.5, 14.5) + paras(x0 + 410, y1 + 338 + 14.5 * wrap(line, 26).length + 8, legal, 26, 10.5, 13, { op: 0.7, fill: '#7a3b3b' });
  });
  const yn = y0 + why + 2 * CH + 8;
  b += text(24, yn + 18, 'For Orb: what to look at', { size: 16, weight: 700 });
  b += paras(24, yn + 40, 'Three directions keep him recognisably the same fighter (1 Stepper, 2 Stack, 5 Prosthetic: heavy, boxy, stepped, the dark red lane). 3 Furnace is a heavier cousin; 4 Frame and 6 Sprinter change what he is. Questions: is he a heavy brawler, a person in a machine, or something quicker and stranger? Which one hook (a staircase, sliding blocks, vents, a window chest, one huge arm, blade legs) do you want to see on the screen at 40 px? Any two can be combined (for example the Stepper\'s staircase on the Prosthetic\'s lopsided build).', 230, 13, 17);
  b += paras(24, yn + 112, 'Rules kept: every lit part is the pale cream-peach tone (never saturated coral, no lone red eye); no bolts, no stitches, no goggles, no gold, no spiky hair; no franchise names or looks. Screening notes are under each direction.', 230, 12, 16, { op: 0.8 });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}"><defs>${MAIL}</defs>${b}</svg>`;
}

// ------------------------------------------------------------------------------------------------------------------- the other three
const OTHERS = {
  P: { name: 'Protagonist', file: 'protagonist-refine.svg', sig: 'laugh', sigName: 'a laugh',
    changes: 'Heavier lids and an angled brow so the eyes are determined, not wide; a swept tuft along the crown that sweeps back (his hair has a direction, and never curls on the forehead); the temple arc kept.',
    ask: 'Is this still the face you liked? Is the swept tuft right, and which silhouette option (the long ribbon tuft or the big plated fists) is more him?' },
  A: { name: 'Anti-hero', file: 'anti-hero-refine.svg', sig: 'contempt', sigName: 'contempt',
    changes: 'Sharper, longer-lidded eyes and thinner brows; a long lock that falls past the cheek on the open side; the lit slash on the cheek kept (it is the one mark of him).',
    ask: 'Is he colder and sharper in the right way? Which option adds more to the silhouette, the longer tail with coat blades or the swept shoulder blade?' },
  E: { name: 'Empress', file: 'empress-refine.svg', sig: 'smirk', sigName: 'a cold smile',
    changes: 'Narrower eyes with a thick lash that sweeps out from each corner; one large moss chevron on the cheekbone (the diadem\'s mark worn on the face); diadem tabs kept short.',
    ask: 'Does the cheek chevron help or crowd the face? Which option reads as more regal, the wide mantle or the crown and train?' },
};
function otherSheet(fk) {
  const o = OTHERS[fk], W = 1800, H = 124 + 2 * 340 + 330 + 90, opt = OTHER_OPTS[fk];
  let b = rect(0, 0, W, H, '#dcd8e6') + header(`${o.name}: unmasked faces and silhouette, refined`, 'From the faces and silhouettes Orb liked. Top: today (the close-up engine\'s unmasked face). Below: refined. Neutral, hurt and the signature expression. Right: the silhouette today and two small options. Working labels, pending Legal review.', W);
  const ps = 300; ['neutral', 'hurt', o.sig].forEach((e, c) => { b += text(24 + c * (ps + 8) + 4, 134, c === 2 ? `${e} (his signature: ${o.sigName})` : e, { size: 13, weight: 700 }); });
  b += text(24, 148, '', {});
  ['neutral', 'hurt', o.sig].forEach((e, c) => { b += face('C', fk, e, 24 + c * (ps + 8), 150, ps) + face('X', fk, e, 24 + c * (ps + 8), 150 + ps + 14, ps, FA.refined); });
  [['today', 150], ['refined', 150 + ps + 14]].forEach(([t, y]) => { b += rect(34, y + 10, t === 'today' ? 62 : 74, 22, '#1b1428', 'opacity="0.8"') + text(42, y + 26, t, { size: 12, weight: 700, fill: '#f4f0fa' }); });
  b += text(24, 150 + ps + 10, '', {}); b += text(4, 400, '', {});
  b += text(960, 134, 'Silhouette at fight size: today, then two options (colour, then flat black at 90 px)', { size: 13, weight: 700 });
  const items = [{ name: 'Today', note: '', concept: opt.base() }, ...opt.options.map(p => ({ name: p.name, note: p.note, concept: p.make() }))];
  items.forEach((it, i) => {
    const px = 960 + i * 280, pal = PAL[fk], pose = POSE0(fk);
    b += rect(px, 150, 272, 614, BG, 'stroke="#1b1428" stroke-opacity="0.2"') + text(px + 10, 172, it.name, { size: 13, weight: 700 });
    b += fig(it.concept, pal, pose, px + (fk === 'E' ? 185 : 150), 520, 2.4, false) + fig(it.concept, pal, pose, px + 240, 520, 0.9, true) + paras(px + 10, 560, it.note || 'The figure today, for comparison.', 40, 11, 14, { op: 0.8 });
  });
  const yb = 150 + 2 * ps + 40;
  b += text(24, yb + 14, 'What changed in the face', { size: 15, weight: 700 }) + paras(24, yb + 36, o.changes, 120, 13, 17);
  b += text(24, yb + 90, 'The question for Orb', { size: 15, weight: 700 }) + paras(24, yb + 112, o.ask, 120, 13, 17);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${Math.max(790, yb + 150)}" viewBox="0 0 ${W} ${Math.max(790, yb + 150)}"><defs>${MAIL}</defs>${b}</svg>`;
}

const ORIGIN = '<!-- Origin: procedural refinement sheet written by art/concepts/refine/gen.mjs (deterministic, no external images or fonts), Art Director session (Claude, claude-sonnet-5-5), 2026-10-02; prompt record art/prompts/ART-0013-refine-faces-silhouettes.md -->' + String.fromCharCode(10);
writeFileSync(join(OUT, 'cyborg-directions.svg'), ORIGIN + cyborgSheet());
for (const fk of ['P', 'A', 'E']) writeFileSync(join(OUT, OTHERS[fk].file), ORIGIN + otherSheet(fk));
console.log('wrote the refinement sheets');
