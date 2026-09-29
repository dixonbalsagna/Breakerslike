// Origin: procedural round-2 overview sheet for the Anti-hero (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-09-29. Human direction: Orb, via the EP.
// Run from the repo root:  node art/concepts/anti-hero/round2.mjs          (writes round2-overview.svg and round2-silhouettes.svg)
//                          node art/concepts/anti-hero/round2.mjs contrast (prints value and contrast checks)

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeCtx, figure, CIVILIAN, CIV_POSES } from './kit.mjs';
import { CONCEPTS2, PALETTES2 } from './concepts2.mjs';

const OUT = dirname(fileURLToPath(import.meta.url));
const F = n => n.toFixed(2);
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family=\"'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif\"";
const text = (x, y, t, { size = 14, weight = 400, fill = '#1b1428', anchor = 'start', op = 1, style = 'normal' } = {}) =>
  `<text x="${F(x)}" y="${F(y)}" ${FONT} font-size="${size}" font-weight="${weight}" font-style="${style}" fill="${fill}" text-anchor="${anchor}" opacity="${op}">${esc(t)}</text>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fill}" ${extra}/>`;
const wrap = (t, n) => { const w = t.split(' '), out = []; let line = ''; for (const x of w) { if ((line + ' ' + x).trim().length > n) { out.push(line.trim()); line = x; } else line += ' ' + x; } if (line.trim()) out.push(line.trim()); return out; };

const hex2rgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const lin = v => { v /= 255; return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; };
const lum = h => { const [r, g, b] = hex2rgb(h).map(lin); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
const Lstar = h => { const y = lum(h); return y > 0.008856 ? 116 * Math.cbrt(y) - 16 : 903.3 * y; };
const contrast = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };

const NEUTRAL = {
  line: '#101014', skin: { light: '#e7c9ad', mid: '#c99a78', shadow: '#8f6448' }, hair: { light: '#5a4a3a', mid: '#3b3128', shadow: '#221b15' },
  base: { light: '#8a93a3', mid: '#6c7079', shadow: '#4a4f57' }, gear: { light: '#c7ccd6', mid: '#9aa1ad', shadow: '#6c7079' }, accent: { light: '#c7ccd6', mid: '#9aa1ad', shadow: '#6c7079' },
};
const CIV_SHIRTS = ['#8a93a3', '#a8794a', '#6a8f7a', '#9c6b7b', '#6d7fa8'];
const civ = i => ({ ...CIVILIAN, cfg: pal => ({ ...CIVILIAN.cfg(pal), torso: CIV_SHIRTS[i % 5], sleeve: CIV_SHIRTS[i % 5], torsoShade: '#00000030' }) });

function place(concept, pal, pose, st, x, groundY, s, { flat = false, swMul = 1 } = {}) {
  const ctx = makeCtx({ flat, pal, swMul });
  const { svg } = figure(ctx, concept, pose, st);
  return `<g transform="translate(${F(x)} ${F(groundY)}) scale(${F(s)} ${F(-s)})">${svg}</g>`;
}
const stFor = (k, extra = {}) => ({ expression: 'proud', sway: CONCEPTS2[k].sway ?? 6, open: 0, wear: 0, forms: 6, ...extra });
const civPlace = (i, x, y, s, pal = NEUTRAL, o = {}) => place(civ(i), pal, CIV_POSES[i % 4], { expression: 'neutral' }, x, y, s, o);

const CARDS = {
  C2: {
    tags: 'upright and arrogant, medium build. A slim spine frame, one slat per form',
    read: 'Ranks everyone and carries the ranking on his back, upright and unbothered.',
    forms: 'One slat per form on a slim rigid frame. The slat count reads at 40 px. Wear: slats fray, the frame snaps at the core.',
  },
  D: {
    tags: 'lean and tall, arrogant upright. Knee-length coat, one oversized gauntlet',
    read: 'A fencer’s stillness: he does not hurry because he does not need to.',
    forms: 'The gauntlet gains a ring, a length and a width every form until the arm is the weapon. The coat never changes.',
  },
  E: {
    tags: 'heavy and low, predatory. Bare arms, dark top, a scar on the face',
    read: 'A wall that leans in, patient and heavy, happy to be hit so he can answer.',
    forms: 'One ash-white slash scar across the chest per form (reads in colour, not in silhouette). The aura gets heavier at the shoulders.',
  },
  F: {
    tags: 'compact and coiled, predatory crouch. A spine of armour plates, a short tied hair tail',
    read: 'Small, watchful and all spring: he waits low and answers in one move.',
    forms: 'One armour plate down the spine per form. The serrated back counts them. From form 4 the forearm gets guards.',
  },
  G: {
    tags: 'tall, upright and aloof. Sleeveless tunic, hair to the calves',
    read: 'Immaculate and aloof, the hair is the banner: he never hurries, the hair does.',
    forms: 'One metal cuff on the long hair per form, so cuffs count up the hair. Aura shape carries the far read.',
  },
};
const ORDER = ['D', 'E', 'F', 'G', 'C2'];

function card(k, x0, y0, W = 570, H = 770) {
  const con = CONCEPTS2[k], pal = PALETTES2[k], pose = con.poses.base, c = CARDS[k];
  let b = rect(x0, y0, W, H, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.2"');
  b += text(x0 + 18, y0 + 34, `${k === 'C2' ? 'C, revised' : k}. ${con.name}`, { size: 24, weight: 700 });
  wrap(c.tags, 64).forEach((l, i) => { b += text(x0 + 18, y0 + 56 + i * 16, l, { size: 12.5, op: 0.85 }); });
  const g = y0 + 385, s = 2.5;
  b += rect(x0 + 14, y0 + 84, 262, g - y0 - 84 + 8, '#f7f5fa', 'stroke="#1b1428" stroke-opacity="0.08"');
  b += rect(x0 + 288, y0 + 84, 268, g - y0 - 84 + 8, '#cfe6f0') + rect(x0 + 288, y0 + 260, 268, g - y0 - 260 + 8, '#2f86ad');
  b += place(con, pal, pose, stFor(k), x0 + 150, g, s, { flat: true });
  b += place(con, pal, pose, stFor(k), x0 + 422, g, s);
  b += text(x0 + 150, g + 26, 'silhouette', { size: 12, anchor: 'middle', op: 0.8 });
  b += text(x0 + 422, g + 26, 'colour, over day sky and sea', { size: 12, anchor: 'middle', op: 0.8 });
  // 40 and 12 px flat, beside a bystander
  const g2 = y0 + 480;
  b += text(x0 + 18, g2 - 52, 'Flat black at true size, with a bystander', { size: 12, weight: 600 });
  b += civPlace(0, x0 + 40, g2, 0.4, NEUTRAL, { flat: true }) + place(con, pal, pose, stFor(k), x0 + 90, g2, 0.4, { flat: true });
  b += civPlace(1, x0 + 150, g2, 0.12, NEUTRAL, { flat: true }) + civPlace(2, x0 + 166, g2, 0.12, NEUTRAL, { flat: true }) + place(con, pal, pose, stFor(k), x0 + 182, g2, 0.12, { flat: true }) + civPlace(3, x0 + 198, g2, 0.12, NEUTRAL, { flat: true }) + civPlace(0, x0 + 214, g2, 0.12, NEUTRAL, { flat: true });
  b += text(x0 + 65, g2 + 18, '40 px', { size: 11, anchor: 'middle', op: 0.8 }) + text(x0 + 182, g2 + 18, '12 px, third from left', { size: 11, anchor: 'middle', op: 0.8 });
  // palette
  b += text(x0 + 300, g2 - 52, 'Body, gear, accent', { size: 12, weight: 600 });
  ['base', 'gear', 'accent'].forEach((r, i) => { b += rect(x0 + 300 + i * 84, g2 - 42, 76, 30, pal[r].mid, 'stroke="#1b1428" stroke-opacity="0.3"') + text(x0 + 338 + i * 84, g2 + 4, pal[r].mid, { size: 10.5, anchor: 'middle', op: 0.85 }); });
  b += text(x0 + 300, g2 + 24, `Body L* ${Math.round(Lstar(pal.base.mid))}, gear L* ${Math.round(Lstar(pal.gear.mid))}`, { size: 11, op: 0.8 });
  // forms and wear
  const g3 = y0 + 655;
  b += text(x0 + 18, g3 - 132, 'Forms F1, F3, F6, then F6 battered and broken', { size: 12, weight: 600 });
  [['F1', { forms: 1 }], ['F3', { forms: 3 }], ['F6', {}], ['battered', { wear: 2 }], ['broken', { wear: 3 }]].forEach(([cap, ex], i) => {
    const x = x0 + 60 + i * 110;
    b += place(con, pal, pose, stFor(k, ex), x, g3, 1.1);
    b += text(x, g3 + 16, cap, { size: 11.5, anchor: 'middle', op: 0.85 });
  });
  wrap(c.read, 78).forEach((l, i) => { b += text(x0 + 18, y0 + 706 + i * 16, l, { size: 13, weight: 600, style: 'italic' }); });
  wrap('Forms: ' + c.forms, 84).forEach((l, i) => { b += text(x0 + 18, y0 + 738 + i * 14, l, { size: 11.5, op: 0.88 }); });
  return b;
}

function overview() {
  const W = 1800, H = 1730;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 92, '#1b1428');
  b += text(30, 46, 'Anti-hero, round 2: four new bodies and the Standard revised', { size: 32, weight: 700, fill: '#f4f0fa' });
  b += text(30, 74, 'Working labels and placeholder designs for Orb. Silhouette, colour thumbnail, forms and wear per card. No shedding kit. Status: proposal, pending Legal review.', { size: 14, fill: '#cfc6e6' });
  ORDER.forEach((k, i) => {
    const col = i % 3, row = Math.floor(i / 3);
    b += card(k, 30 + col * 600, 112 + row * 790);
  });
  // legend panel
  const lx = 1230, ly = 902;
  b += rect(lx, ly, 570 - 0, 770, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.2"');
  b += text(lx + 18, ly + 34, 'How to read this sheet', { size: 22, weight: 700 });
  const lines = [
    'Every body follows the value rule: dark body, light gear, so it reads on sea, sky and night.',
    'All stay in the violet lane. Hair is dark and never changes. No gold, red or orange glow.',
    'No shoulder pads, no white gloves and boots, no flame or upswept hair, no cape.',
    'The 12 px strip hides the fighter among bystanders of the same height. In each strip the fighter is the third from the left.',
    'Forms F1 to F6 read through one growing feature each: gauntlet (D), scars (E), spine plates (F), hair cuffs (G), slats (C).',
    'Wear uses the same four stages as the wounds spec. Colour thumbnails use the outline rule from the style guide.',
    'Body build: D lean and tall, E heavy and short-legged, F compact, G tall, C medium.',
    'Posture: D, G and C upright and arrogant. E and F low and predatory.',
  ];
  let y = ly + 64;
  lines.forEach(t => { wrap(t, 62).forEach(l => { b += text(lx + 18, y, l, { size: 13 }); y += 18; }); y += 8; });
  b += text(lx + 18, ly + 700, 'Generated by round2.mjs. Nothing here is a locked design.', { size: 12, op: 0.8 });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${b}</svg>`;
}

// The flat-black test at true size for round 2: 5, 12, 20, 40 px and find-the-fighter lines.
export const SLOTS = { D: { 5: 2, 12: 6 }, E: { 5: 7, 12: 3 }, F: { 5: 4, 12: 9 }, G: { 5: 9, 12: 1 }, C2: { 5: 6, 12: 8 } };
function silhouettes() {
  const W = 1500, H = 1230;
  let b = rect(0, 0, W, H, '#f3f1f6');
  b += text(30, 40, 'Round 2 silhouette test: flat black at true size, with a bystander', { size: 24, weight: 700 });
  b += text(30, 64, 'View at 100% zoom. Sizes are body height. Right: find the fighter (5 px, then 12 px). Results pending Legal review.', { size: 13, op: 0.85 });
  const X = { s5: 210, s12: 252, s20: 296, s40: 350, s160: 460, f1: 620, f3: 690, f6: 760 };
  [['5 px', X.s5], ['12', X.s12], ['20', X.s20], ['40', X.s40], ['160 px', X.s160], ['F1 40', X.f1], ['F3 40', X.f3], ['F6 40', X.f6]].forEach(([t, x]) => { b += text(x, 100, t, { size: 12, weight: 600, anchor: 'middle' }); });
  b += text(900, 100, 'Find the fighter (5 px, then 12 px)', { size: 12, weight: 600 });
  const rows = { civ: 250 };
  ORDER.forEach((k, i) => { rows[k] = 250 + (i + 1) * 165; });
  b += text(30, rows.civ - 40, 'Bystander', { size: 15, weight: 700 });
  [[0.05, X.s5], [0.12, X.s12], [0.2, X.s20], [0.4, X.s40], [1.3, X.s160]].forEach(([s, x]) => { b += civPlace(0, x, rows.civ, s, NEUTRAL, { flat: true }); });
  ORDER.forEach(k => {
    const con = CONCEPTS2[k], pal = PALETTES2[k], y = rows[k], pose = con.poses.base;
    b += text(30, y - 40, `${k === 'C2' ? 'C, revised' : k}. ${con.name}`, { size: 15, weight: 700 });
    const pr = (x, s, ex = {}) => place(con, pal, pose, stFor(k, ex), x, y, s, { flat: true });
    [[0.05, X.s5], [0.12, X.s12], [0.2, X.s20], [0.4, X.s40], [1.3, X.s160]].forEach(([s, x]) => { b += pr(x, s); });
    b += pr(X.f1, 0.4, { forms: 1 }) + pr(X.f3, 0.4, { forms: 3 }) + pr(X.f6, 0.4, { forms: 6 });
    [[5, 0.05, y], [12, 0.12, y - 24]].forEach(([px, s, yy]) => {
      for (let i = 0; i < 12; i++) {
        const x = 900 + i * 27;
        b += i === SLOTS[k][px] ? place(con, pal, pose, stFor(k), x, yy, s, { flat: true }) : civPlace((i * 7 + 1) % 4, x, yy, s, NEUTRAL, { flat: true });
      }
    });
  });
  b += text(30, H - 24, 'Fighter slots left to right (5 px, 12 px): D 3rd, 7th. E 8th, 4th. F 5th, 10th. G 10th, 2nd. C 7th, 9th.', { size: 11, op: 0.8 });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${b}</svg>`;
}

const ORIGIN = '<!-- Origin: procedural concept sheet written by art/concepts/anti-hero/round2.mjs (deterministic, no external images or fonts), Art Director session (Claude, claude-sonnet-5-5), 2026-09-29; prompt record art/prompts/ART-0002-anti-hero-round2.md -->' + String.fromCharCode(10);
const mode = process.argv[2];
if (mode === 'contrast') {
  const seas = { 'day sea': '#2f86ad', 'deep sea': '#123f5e', night: '#0d1430', 'day sky': '#cfe6f0' };
  for (const k of ORDER) {
    const p = PALETTES2[k];
    console.log(k, 'L*', { base: Math.round(Lstar(p.base.mid)), gear: Math.round(Lstar(p.gear.mid)), accent: Math.round(Lstar(p.accent.mid)) },
      Object.entries(seas).map(([n, h]) => `${n}: body ${contrast(p.base.mid, h).toFixed(1)}, gear ${contrast(p.gear.mid, h).toFixed(1)}`).join(' | '));
  }
} else {
  writeFileSync(join(OUT, 'round2-overview.svg'), ORIGIN + overview());
  writeFileSync(join(OUT, 'round2-silhouettes.svg'), ORIGIN + silhouettes());
  console.log('wrote round2-overview.svg, round2-silhouettes.svg');
}
