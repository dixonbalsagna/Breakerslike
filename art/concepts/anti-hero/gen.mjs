// Origin: procedural generator for the Anti-hero concept sheets and the silhouette test (deterministic, no randomness).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-09-29. Human direction: Orb, via the EP.
// Run from the repo root:  node art/concepts/anti-hero/gen.mjs         (writes the SVGs next to this file)
//                          node art/concepts/anti-hero/gen.mjs contrast (prints the palette-versus-backdrop table)

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeCtx, figure, POSES, CIVILIAN, CIV_POSES } from './kit.mjs';
import { CONCEPTS, PALETTES } from './concepts.mjs';

const OUT = dirname(fileURLToPath(import.meta.url));
const F = n => n.toFixed(2);
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family=\"'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif\"";
const text = (x, y, t, { size = 14, weight = 400, fill = '#1b1428', anchor = 'start', op = 1 } = {}) =>
  `<text x="${F(x)}" y="${F(y)}" ${FONT} font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}" opacity="${op}">${esc(t)}</text>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fill}" ${extra}/>`;

// Backdrops that fighters are read against: sky and sea for the ocean (most of the fight time), plus one for each other world.
export const BACKDROPS = [
  { id: 'day-sea', label: 'Day, sea', top: '#cfe6f0', bottom: '#2f86ad' },
  { id: 'deep-sea', label: 'Under the sea', top: '#1d5b80', bottom: '#123f5e' },
  { id: 'dusk', label: 'Dusk', top: '#f3a77a', bottom: '#34407f' },
  { id: 'night', label: 'Night', top: '#24365f', bottom: '#0d1430' },
  { id: 'city', label: 'City, day', top: '#cfe6f0', bottom: '#7f8896' },
  { id: 'forest', label: 'Forest, day', top: '#cfe6f0', bottom: '#2e6a35' },
];

const NEUTRAL_PAL = {
  line: '#101014', skin: { light: '#e7c9ad', mid: '#c99a78', shadow: '#8f6448' }, hair: { light: '#5a4a3a', mid: '#3b3128', shadow: '#221b15' },
  base: { light: '#8a93a3', mid: '#6c7079', shadow: '#4a4f57' }, gear: { light: '#c7ccd6', mid: '#9aa1ad', shadow: '#6c7079' }, accent: { light: '#c7ccd6', mid: '#9aa1ad', shadow: '#6c7079' },
};
const CIV_PALS = [
  { ...NEUTRAL_PAL },
  { ...NEUTRAL_PAL, skin: { light: '#efd3b8', mid: '#d9ad8b', shadow: '#9a6f52' }, hair: { light: '#8a6a3f', mid: '#5b4326', shadow: '#33260f' } },
  { ...NEUTRAL_PAL, skin: { light: '#a97a5b', mid: '#86583b', shadow: '#5a3a26' }, hair: { light: '#2a2220', mid: '#161211', shadow: '#0b0908' } },
];
const CIV_SHIRTS = ['#8a93a3', '#a8794a', '#6a8f7a', '#9c6b7b', '#6d7fa8'];
const civilian = (i) => ({
  ...CIVILIAN,
  cfg: (pal) => ({ ...CIVILIAN.cfg(pal), torso: CIV_SHIRTS[i % 5], sleeve: CIV_SHIRTS[i % 5], torsoShade: '#00000030' }),
});

// Place one figure. (x, groundY) is where its feet touch; s is pixels per body unit (100 units is one body height).
export function place(concept, pal, pose, st, x, groundY, s, { flat = false, swMul = 1 } = {}) {
  const ctx = makeCtx({ flat, pal, swMul });
  const { svg } = figure(ctx, concept, pose, st);
  return `<g transform="translate(${F(x)} ${F(groundY)}) scale(${F(s)} ${F(-s)})">${svg}</g>`;
}

const STATE = {
  proud: { expression: 'proud', sway: 6, open: 0, wear: 0, forms: 6 },
  humbled: { expression: 'humbled', sway: 2, open: 0.6, wear: 0, forms: 6, hairLoose: true },
  dropped: { expression: 'dropped', sway: 46, open: 1, wear: 0, forms: 6, hairLoose: true },
};
const swayFor = (key, pose) => (key === 'C' ? { proud: 0.15, humbled: 0.05, dropped: 0.95 }[pose] : STATE[pose].sway);
export const stateFor = (key, pose, extra = {}) => ({ ...STATE[pose], sway: swayFor(key, pose), ...extra });

// ------------------------------------------------------------------------------------------------ colour helpers
const hex2rgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const lin = v => { v /= 255; return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; };
const lum = h => { const [r, g, b] = hex2rgb(h).map(lin); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
export const Lstar = h => { const y = lum(h); return y > 0.008856 ? 116 * Math.cbrt(y) - 16 : 903.3 * y; };
export const contrast = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };

// Three flat colours: every colour snaps to the nearest of the three masses (base, gear, accent).
const nearest = (h, opts) => opts.reduce((best, o) => { const d = hex2rgb(h).reduce((s, v, i) => s + (v - hex2rgb(o)[i]) ** 2, 0); return d < best.d ? { d, o } : best; }, { d: 1e12, o: opts[0] }).o;
export function threeColour(pal) {
  const masses = [pal.base.mid, pal.gear.mid, pal.accent.mid];
  const q = h => nearest(h, masses);
  const step = () => ({ light: pal.gear.mid, mid: pal.gear.mid, shadow: pal.gear.mid });
  return { line: pal.line, skin: step(pal.skin), hair: { light: pal.base.mid, mid: pal.base.mid, shadow: pal.base.mid }, base: { light: pal.base.mid, mid: pal.base.mid, shadow: pal.base.mid }, gear: { light: pal.gear.mid, mid: pal.gear.mid, shadow: pal.gear.mid }, accent: { light: pal.accent.mid, mid: pal.accent.mid, shadow: pal.accent.mid } };
}

const DEFS = `<defs>
<filter id="grey" color-interpolation-filters="linearRGB"><feColorMatrix type="saturate" values="0"/></filter>
<filter id="protan" color-interpolation-filters="linearRGB"><feColorMatrix type="matrix" values="0.152286 1.052583 -0.204868 0 0  0.114503 0.786281 0.099216 0 0  -0.003882 -0.048116 1.051998 0 0  0 0 0 1 0"/></filter>
<filter id="deutan" color-interpolation-filters="linearRGB"><feColorMatrix type="matrix" values="0.367322 0.860646 -0.227968 0 0  0.280085 0.672501 0.047413 0 0  -0.011820 0.042940 0.968881 0 0  0 0 0 1 0"/></filter>
<filter id="tritan" color-interpolation-filters="linearRGB"><feColorMatrix type="matrix" values="1.255528 -0.076749 -0.178779 0 0  -0.078411 0.930809 0.147602 0 0  0.004733 0.691367 0.303900 0 0  0 0 0 1 0"/></filter>
</defs>`;

const swatch = (x, y, hex, label, w = 74, h = 38) =>
  rect(x, y, w, h, hex, 'stroke="#1b1428" stroke-opacity="0.35" stroke-width="1"') + text(x + w / 2, y + h + 13, label ?? hex, { size: 11, anchor: 'middle', op: 0.85 });

// ------------------------------------------------------------------------------------------------ the concept sheet
const RIM = '#b9a9e6'; // outline colour on dark backdrops: the rim rule from the style guide
function sheet(key) {
  const concept = CONCEPTS[key], pal = PALETTES[key];
  const W = 1600, H = 1740;
  const hr = (y, x2 = 1090) => `<line x1="40" y1="${y}" x2="${x2}" y2="${y}" stroke="#1b1428" stroke-opacity="0.25"/>`;
  let b = '';
  b += rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 86, '#1b1428');
  b += text(40, 46, `Anti-hero concept ${concept.id}: ${concept.name}`, { size: 32, weight: 700, fill: '#f4f0fa' });
  b += text(40, 71, 'Working label and placeholder design for Orb. Side-on, faceted low-poly look. Status: proposal, pending Legal review. Generated by gen.mjs (procedural, no external images).', { size: 14, fill: '#cfc6e6' });

  // Row 1: posture states
  const g1 = 604;
  b += hr(g1);
  [['proud', 'PROUD: the front holds', 190], ['humbled', 'HUMBLED: struck, swallowing it', 520], ['dropped', 'ACT DROPPED: nothing held back', 870]].forEach(([p, cap, x]) => {
    b += place(concept, pal, POSES[p], stateFor(key, p), x, g1, 3.3);
    b += text(x, g1 + 28, cap, { size: 15, weight: 600, anchor: 'middle' });
  });

  // Palette panel
  const px = 1140;
  b += text(px, 122, 'Palette (light, mid, shadow)', { size: 16, weight: 700 });
  const roles = [['Body base', pal.base], ['Gear', pal.gear], ['Accent', pal.accent], ['Skin', pal.skin], ['Hair (never changes)', pal.hair]];
  roles.forEach(([n, c], i) => {
    const y = 140 + i * 74;
    b += text(px, y + 10, n, { size: 12, weight: 600 });
    ['light', 'mid', 'shadow'].forEach((k, j) => { b += swatch(px + j * 84, y + 16, c[k], c[k]); });
  });
  b += text(px, 530, 'Outline ' + pal.line + ', never pure black. Rim ' + RIM + ' on dark backdrops.', { size: 12, op: 0.85 });
  const eff = effectsFor(pal);
  b += text(px, 566, 'Effects (proposal for VFX)', { size: 16, weight: 700 });
  b += text(px, 588, 'Aura, core to rim', { size: 12, weight: 600 });
  eff.aura.forEach((c, j) => { b += swatch(px + j * 84, 596, c, c, 74, 22); });
  b += text(px, 658, 'Barrage bolt, core to rim', { size: 12, weight: 600 });
  eff.beam.forEach((c, j) => { b += swatch(px + j * 84, 666, c, c, 74, 22); });
  // Three-colour reduction
  b += text(px, 742, 'Three-colour test', { size: 16, weight: 700 });
  b += place(concept, threeColour(pal), POSES.proud, stateFor(key, 'proud'), px + 70, 1020, 2.0);
  b += place(concept, pal, POSES.proud, stateFor(key, 'proud'), px + 230, 1020, 2.0);
  b += text(px + 70, 1040, 'three flat colours', { size: 11, anchor: 'middle', op: 0.85 });
  b += text(px + 230, 1040, 'as designed', { size: 11, anchor: 'middle', op: 0.85 });

  // Row 2: wear progression (proud pose: the front hides the posture, decals still show)
  b += hr(g1 + 46);
  b += text(40, 676, 'WEAR under the proud front: decals and regalia damage show, posture and face stay composed', { size: 14, weight: 700 });
  const g2 = 1036;
  [['FRESH (under 30)', 0], ['BRUISED (30 to 59)', 1], ['BATTERED (60 to 89)', 2], ['BROKEN (90 and up)', 3]].forEach(([cap, w], i) => {
    const x = 140 + i * 255;
    b += place(concept, pal, POSES.proud, stateFor(key, 'proud', { wear: w }), x, g2, 2.7);
    b += text(x, g2 + 22, cap, { size: 13, weight: 600, anchor: 'middle' });
  });

  // Row 3: form ladder
  b += hr(1072);
  b += text(40, 1098, 'FORMS F1 to F6 add one regalia piece each, left to right. Shed Regalia strips them right to left, coarse to fine.', { size: 14, weight: 700 });
  const g3 = 1350;
  concept.pieces.forEach((pc, i) => {
    const x = 90 + i * 170;
    b += place(concept, pal, POSES.proud, stateFor(key, 'proud', { forms: pc.form }), x, g3, 1.95);
    b += text(x, g3 + 20, `F${pc.form}`, { size: 14, weight: 700, anchor: 'middle' });
    b += text(x, g3 + 36, pc.label, { size: 11, anchor: 'middle', op: 0.9 });
  });

  // Right column, lower: colour-vision test
  b += text(px, 1076, 'Colour-vision and value test', { size: 16, weight: 700 });
  [['normal', null], ['greyscale', 'grey'], ['protan', 'protan'], ['deutan', 'deutan'], ['tritan', 'tritan']].forEach(([n, f], i) => {
    const x = px + 34 + i * 88;
    b += `<g${f ? ` filter="url(#${f})"` : ''}>${rect(x - 40, 1092, 84, 150, '#bcd3e0')}${rect(x - 40, 1180, 84, 62, '#2f86ad')}${place(concept, pal, POSES.proud, stateFor(key, 'proud'), x, 1234, 1.1)}</g>`;
    b += text(x, 1258, n, { size: 11, anchor: 'middle', op: 0.9 });
  });

  // Row 4: backdrops
  b += hr(1398, 1560);
  b += text(40, 1424, 'BACKDROP TEST: proud and dropped over each world the fighter is seen against. Dark backdrops switch the outline to the rim colour.', { size: 14, weight: 700 });
  BACKDROPS.forEach((bd, i) => {
    const x = 40 + i * 254, y = 1442;
    const dark = Lstar(bd.bottom) < 35 && Lstar(bd.top) < 45;
    const p2 = dark ? { ...pal, line: RIM } : pal;
    b += rect(x, y, 240, 200, bd.top) + rect(x, y + 110, 240, 90, bd.bottom);
    b += place(concept, p2, POSES.proud, stateFor(key, 'proud'), x + 64, y + 190, 1.2);
    b += place(concept, p2, POSES.dropped, stateFor(key, 'dropped'), x + 168, y + 190, 1.2);
    b += rect(x, y + 200, 240, 22, '#1b1428') + text(x + 8, y + 216, bd.label + (dark ? ' (rim outline)' : ''), { size: 12, fill: '#f4f0fa' });
  });
  b += text(40, 1696, `Palette masses: body ${pal.base.mid}, gear ${pal.gear.mid}, accent ${pal.accent.mid}. Six regalia pieces are added one per form.`, { size: 12, op: 0.85 });
  b += text(40, 1714, 'Regalia and postures are concept art for Orb to choose from, not a locked design. Name, face and skin tone are placeholders too.', { size: 12, op: 0.85 });

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

function effectsFor(pal) {
  const map = {
    A: { aura: ['#f1e9ff', '#a98cf0', '#5b3fb0'], beam: ['#fff0f7', '#ff86b3', '#d0508c'] },
    B: { aura: ['#f4ecff', '#c9a3ff', '#7442c9'], beam: ['#f6ecff', '#c98cff', '#8a55c7'] },
    C: { aura: ['#f1e9ff', '#a98cf0', '#5b3fb0'], beam: ['#fff0f7', '#ff86b3', '#e0407f'] },
  };
  const key = Object.entries(PALETTES).find(([, v]) => v === pal)?.[0] ?? 'A';
  return map[key];
}

// ------------------------------------------------------------------------------------------------ the silhouette test
// Flat black, drawn at true pixel size when the SVG is viewed at 100%. Body height means feet to hair; the Standard's pole adds about 30%.
// Fighters in real fights are 22 to 52 px tall (zoom 0.3 to 0.7); the widest fight zoom of 0.06 gives about 5 px.
export const FIND_SLOTS = { A: { 5: 3, 12: 7 }, B: { 5: 8, 12: 2 }, C: { 5: 5, 12: 10 } };
function silhouetteTest() {
  const W = 1500, H = 1180;
  let b = rect(0, 0, W, H, '#f3f1f6');
  b += text(30, 40, 'Silhouette test: the three Anti-hero concepts and a bystander, flat black at true size', { size: 24, weight: 700 });
  b += text(30, 64, 'View at 100% zoom. Sizes are body height (feet to hair). Left block: flat black. Middle: the same figure in colour over day sky and sea. Right: find the fighter among bystanders. Status: results pending Legal review.', { size: 13, op: 0.85 });
  const X = { s5: 220, s12: 262, s20: 306, s40: 360, s160: 460, h40: 590, d40: 660, f1: 750, f3: 810, f6: 870, c5: 960, c12: 1020, c20: 1080 };
  const heads = [['5 px', X.s5], ['12', X.s12], ['20', X.s20], ['40', X.s40], ['160 px', X.s160], ['humbled 40', X.h40], ['dropped 40', X.d40], ['F1 40', X.f1], ['F3 40', X.f3], ['F6 40', X.f6], ['colour 5', X.c5], ['colour 12', X.c12], ['colour 20', X.c20]];
  const rowY = { civ: 290, A: 540, B: 790, C: 1040 };
  heads.forEach(([t, x]) => { b += text(x, 100, t, { size: 12, weight: 600, anchor: 'middle' }); });
  b += text(1170, 100, 'Find the fighter (5 px, then 12 px)', { size: 12, weight: 600 });
  const seaChip = (x, y, s) => rect(x - 22, y - 34 * (s / 0.2) * 0 - 46, 44, 52, '#cfe6f0') + rect(x - 22, y - 16, 44, 22, '#2f86ad');
  const cv = civilian(0);
  const cs = (pose, x, y, s, pal = CIV_PALS[0]) => place(cv, pal, CIV_POSES[pose], { expression: 'neutral' }, x, y, s, { flat: true });
  b += text(30, rowY.civ - 60, 'Bystander', { size: 15, weight: 700 });
  b += text(30, rowY.civ - 40, 'same height as a fighter', { size: 12, op: 0.8 });
  [[0.05, X.s5], [0.12, X.s12], [0.2, X.s20], [0.4, X.s40], [1.6, X.s160]].forEach(([s, x]) => { b += cs(0, x, rowY.civ, s); });
  b += cs(1, X.h40, rowY.civ, 0.4) + cs(3, X.d40, rowY.civ, 0.4);
  [[0.05, X.c5, 0], [0.12, X.c12, 0], [0.2, X.c20, 0.4]].forEach(([s, x, m]) => {
    b += seaChip(x, rowY.civ, s) + place(civilian(0), CIV_PALS[0], CIV_POSES[0], { expression: 'neutral' }, x, rowY.civ, s, { swMul: m });
  });
  ['A', 'B', 'C'].forEach((k) => {
    const con = CONCEPTS[k], pal = PALETTES[k], y = rowY[k];
    b += text(30, y - 60, `${con.id}: ${con.name}`, { size: 15, weight: 700 });
    b += text(30, y - 40, k === 'A' ? 'tall column, long coat tail' : k === 'B' ? 'triangle, stepped hem' : 'pole above the head, plate stack', { size: 12, op: 0.8 });
    const pr = (pose, x, s, extra = {}, flat = true) => place(con, pal, POSES[pose], stateFor(k, pose, extra), x, y, s, { flat });
    [[0.05, X.s5], [0.12, X.s12], [0.2, X.s20], [0.4, X.s40], [1.6, X.s160]].forEach(([s, x]) => { b += pr('proud', x, s); });
    b += pr('humbled', X.h40, 0.4) + pr('dropped', X.d40, 0.4);
    b += pr('proud', X.f1, 0.4, { forms: 1 }) + pr('proud', X.f3, 0.4, { forms: 3 }) + pr('proud', X.f6, 0.4, { forms: 6 });
    [[0.05, X.c5, 0], [0.12, X.c12, 0], [0.2, X.c20, 0.4]].forEach(([s, x, m]) => { b += seaChip(x, y, s) + place(con, pal, POSES.proud, stateFor(k, 'proud'), x, y, s, { swMul: m }); });
    // find the fighter: twelve at 5 px, and twelve at 12 px, one of them the Anti-hero
    [[5, 0.05, y], [12, 0.12, y - 26]].forEach(([px, s, yy]) => {
      const slot = FIND_SLOTS[k][px];
      for (let i = 0; i < 12; i++) {
        const x = 1170 + i * 27;
        if (i === slot) b += place(con, pal, POSES.proud, stateFor(k, 'proud'), x, yy, s, { flat: true });
        else b += cs((i * 7 + 1) % 4, x, yy, s);
      }
    });
  });
  b += text(1170, rowY.C + 44, 'Slots (5 px, 12 px): A 4th, 8th. B 9th, 3rd. C 6th, 11th.', { size: 11, op: 0.8 });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${b}</svg>`;
}

// ------------------------------------------------------------------------------------------------ the overview
function overview() {
  const W = 1500, H = 760;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 76, '#1b1428');
  b += text(40, 44, 'Anti-hero: three silhouettes, side by side', { size: 30, weight: 700, fill: '#f4f0fa' });
  b += text(40, 66, 'Proud front, act dropped, and the full regalia at form 6. Working labels. Pending Legal review. Orb picks.', { size: 14, fill: '#cfc6e6' });
  ['A', 'B', 'C'].forEach((k, i) => {
    const con = CONCEPTS[k], pal = PALETTES[k], x0 = 40 + i * 490;
    b += rect(x0, 96, 470, 620, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.2"');
    b += text(x0 + 16, 128, `${con.id}. ${con.name}`, { size: 22, weight: 700 });
    b += place(con, pal, POSES.proud, stateFor(k, 'proud'), x0 + 165, 560, 3.6);
    b += place(con, pal, POSES.dropped, stateFor(k, 'dropped'), x0 + 370, 560, 3.0);
    ['base', 'gear', 'accent'].forEach((r, j) => { b += swatch(x0 + 40 + j * 130, 600, pal[r].mid, `${r} ${pal[r].mid}`, 110, 30); });
    b += text(x0 + 16, 692, k === 'A' ? 'Feature at 5 px: a vertical rectangle with a coat tail.' : k === 'B' ? 'Feature at 5 px: a triangle.' : 'Feature at 5 px: a pole above the head.', { size: 12, op: 0.9 });
  });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

// ------------------------------------------------------------------------------------------------ contrast table
function contrastTable() {
  const rows = [];
  for (const k of ['A', 'B', 'C']) {
    const pal = PALETTES[k];
    for (const bd of BACKDROPS) {
      const masses = { base: pal.base.mid, gear: pal.gear.mid, accent: pal.accent.mid, line: pal.line };
      const cells = Object.entries(masses).map(([n, h]) => `${n} ${contrast(h, bd.top).toFixed(1)}/${contrast(h, bd.bottom).toFixed(1)}`);
      rows.push(`${k} vs ${bd.label} (${bd.top}/${bd.bottom}): ${cells.join('; ')}`);
    }
  }
  console.log(rows.join('\n'));
  for (const k of ['A', 'B', 'C']) console.log(k, 'L*', Object.fromEntries(Object.entries({ base: PALETTES[k].base.mid, gear: PALETTES[k].gear.mid, accent: PALETTES[k].accent.mid, line: PALETTES[k].line }).map(([n, h]) => [n, Math.round(Lstar(h))])));
  for (const bd of BACKDROPS) console.log(bd.id, 'L*', Math.round(Lstar(bd.top)), Math.round(Lstar(bd.bottom)));
}

const mode = process.argv[2];
if (mode === 'contrast') contrastTable();
else if (mode === 'test') {
  let body = '';
  ['A', 'B', 'C'].forEach((k, i) => ['proud', 'humbled', 'dropped'].forEach((p, j) => { body += place(CONCEPTS[k], PALETTES[k], POSES[p], stateFor(k, p), 180 + j * 330, 400 + i * 440, 3.6); }));
  writeFileSync(join(OUT, '_test.svg'), `<svg xmlns="http://www.w3.org/2000/svg" width="1100" height="1350" viewBox="0 0 1100 1350"><rect width="1100" height="1350" fill="#dcd8e6"/>${body}</svg>`);
  console.log('wrote _test.svg');
} else {
  const ORIGIN = '<!-- Origin: procedural concept sheet written by art/concepts/anti-hero/gen.mjs (deterministic, no external images or fonts), Art Director session (Claude, claude-sonnet-5-5), 2026-09-29; prompt record art/prompts/ART-0001-anti-hero-concepts.md -->' + String.fromCharCode(10);
  writeFileSync(join(OUT, 'a-column.svg'), ORIGIN + sheet('A'));
  writeFileSync(join(OUT, 'b-bell.svg'), ORIGIN + sheet('B'));
  writeFileSync(join(OUT, 'c-standard.svg'), ORIGIN + sheet('C'));
  writeFileSync(join(OUT, 'silhouette-test.svg'), ORIGIN + silhouetteTest());
  writeFileSync(join(OUT, 'overview.svg'), ORIGIN + overview());
  console.log('wrote a-column.svg, b-bell.svg, c-standard.svg, silhouette-test.svg, overview.svg');
}
