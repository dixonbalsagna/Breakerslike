// Origin: procedural chart of the building shapes, the district looks and the five landmarks (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-09-30. Human direction: Orb, via the EP. Every design is an original, generic, faceted building.
// Run from the repo root:  node art/concepts/world/gen.mjs   (writes docs/art/district-shapes.svg). Brief: docs/art/district-looks.md. Reads data/biomes/settlements.json for the look's real heights and widths.

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const DATA = JSON.parse(readFileSync(join(ROOT, 'data', 'biomes', 'settlements.json'), 'utf8'));
const F = n => n.toFixed(2);
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family=\"'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif\"";
const text = (x, y, t, { size = 13, weight = 400, fill = '#1b1428', anchor = 'start', op = 1 } = {}) => `<text x="${F(x)}" y="${F(y)}" ${FONT} font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}" opacity="${op}">${esc(t)}</text>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fill}" ${extra}/>`;
const wrap = (t, n) => { const w = t.split(' '), out = []; let line = ''; for (const x of w) { if ((line + ' ' + x).trim().length > n) { out.push(line.trim()); line = x; } else line += ' ' + x; } if (line.trim()) out.push(line.trim()); return out; };
const paras = (x, y, t, n, size = 12, gap = 15, o = {}) => wrap(t, n).map((l, i) => text(x, y + i * gap, l, { size, ...o })).join('');

// ---------------------------------------------------------------------------------------------------------- shapes, in fighter heights (bh), y up
// A polygon is { p: [[x, y], ...], t: tone }. Tones: front (wall), side (the shaded facet), roof, glass, dark, band1, band2, accent.
const P = (t, ...p) => ({ t, p });
function prism(x0, x1, y0, y1, d) {
  d = d ?? Math.min((x1 - x0) * 0.22, 1.2);
  return [P('front', [x0, y0], [x1 - d, y0], [x1 - d, y1], [x0, y1]), P('side', [x1 - d, y0], [x1, y0], [x1, y1], [x1 - d, y1])];
}
function gable(x0, x1, y, ph, d) {   // a gable roof: a front facet and a side facet
  d = d ?? Math.min((x1 - x0) * 0.22, 1.2); const xm = (x0 + x1 - d) / 2;
  return [P('roof', [x0, y], [x1 - d, y], [xm, y + ph]), P('side', [x1 - d, y], [x1, y], [xm + d * 0.5, y + ph], [xm, y + ph])];
}
const SHAPES = {
  shaft: (w, h) => [...prism(-w / 2, w / 2, 0, h), ...prism(-w * 0.2, w * 0.2, h, h + Math.max(1.2, h * 0.025))],
  stepped: (w, h) => [...prism(-w / 2, w / 2, 0, h * 0.5), ...prism(-w * 0.4, w * 0.4, h * 0.5, h * 0.8), ...prism(-w * 0.3, w * 0.3, h * 0.8, h)],
  crown: (w, h) => { const d = w * 0.22; return [...prism(-w / 2, w / 2, 0, h * 0.88), P('roof', [-w / 2, h * 0.88], [-w / 2 + w * 0.25, h], [w / 2 - d - w * 0.25, h], [w / 2 - d, h * 0.88]), P('side', [w / 2 - d, h * 0.88], [w / 2 - d - w * 0.25, h], [w / 2 - w * 0.25, h], [w / 2, h * 0.88])]; },
  spire: (w, h) => [...prism(-w * 0.4, w * 0.4, 0, h * 0.72), P('roof', [-w * 0.4, h * 0.72], [w * 0.4 - w * 0.18, h * 0.72], [-w * 0.05, h]), P('side', [w * 0.4 - w * 0.18, h * 0.72], [w * 0.4, h * 0.72], [-w * 0.05, h])],
  slab: (w, h) => [...prism(-w / 2, w / 2, 0, h, w * 0.1), ...prism(-w * 0.2, w * 0.05, h, h + 1.6, 0.4)],
  block: (w, h) => [...prism(-w / 2, w / 2, 0, h), P('side', [-w / 2, h], [w / 2, h], [w / 2, h + 0.8], [-w / 2, h + 0.8]), ...prism(-w * 0.2, w * 0.15, h + 0.8, h + 2.4, 0.5)],
  warehouse: (w, h) => [...prism(-w / 2, w / 2, 0, h * 0.85), ...gable(-w / 2, w / 2, h * 0.85, h * 0.25, 0.8), P('dark', [-w * 0.3, 0], [-w * 0.12, 0], [-w * 0.12, h * 0.5], [-w * 0.3, h * 0.5]), P('dark', [w * 0.02, 0], [w * 0.2, 0], [w * 0.2, h * 0.5], [w * 0.02, h * 0.5])],
  sawtooth: (w, h) => { const o = prism(-w / 2, w / 2, 0, h * 0.7), n = 4, tw = w / n; for (let i = 0; i < n; i++) o.push(P('roof', [-w / 2 + i * tw, h * 0.7], [-w / 2 + i * tw, h], [-w / 2 + (i + 1) * tw, h * 0.7])); return o; },
  chimney: (w, h) => [P('front', [-w / 2, 0], [0, 0], [0, h * 0.88], [-w * 0.34, h * 0.88]), P('side', [0, 0], [w / 2, 0], [w * 0.34, h * 0.88], [0, h * 0.88]), P('band2', [-w * 0.46, h * 0.88], [w * 0.46, h * 0.88], [w * 0.56, h], [-w * 0.56, h])],
  house: (w, h) => [...prism(-w / 2, w / 2, 0, h * 0.62), ...gable(-w / 2, w / 2, h * 0.62, h * 0.38), P('dark', [-w * 0.1, 0], [w * 0.1, 0], [w * 0.1, h * 0.36], [-w * 0.1, h * 0.36])],
  thatch: (w, h) => [...prism(-w / 2, w / 2, 0, h * 0.45), ...gable(-w * 0.64, w * 0.64, h * 0.45, h * 0.55, 0.9)],
  terrace: (w, h) => { const o = []; for (let i = 0; i < 3; i++) { const x0 = -w / 2 + i * w * 0.3, y1 = h * (0.4 + i * 0.3); o.push(...prism(x0, x0 + w * 0.42, 0, y1, 0.5)); } o.push(...gable(-w / 2 + w * 0.6, w / 2 + w * 0.12, h * 0.4 + h * 0.6 * 0.99, h * 0.2, 0.5)); return o; },
  shop: (w, h) => [...prism(-w / 2, w / 2, 0, h * 0.62), ...gable(-w / 2, w / 2, h * 0.62, h * 0.38), P('accent', [-w * 0.46, h * 0.36], [w * 0.3, h * 0.36], [w * 0.36, h * 0.26], [-w * 0.52, h * 0.26])],
  shed: (w, h) => [...prism(-w / 2, w / 2, 0, h * 0.7), P('roof', [-w / 2, h * 0.7], [w / 2 - 0.6, h], [w / 2 - 0.6, h * 0.7])],
  hall: (w, h) => [...prism(-w / 2, w / 2, 0, h * 0.55), ...gable(-w / 2, w / 2, h * 0.55, h * 0.45, 1), ...prism(-w * 0.12, w * 0.12, 0, h * 0.3, 0.4)],
  chapel: (w, h) => [...prism(-w / 2, w / 2, 0, h * 0.5), ...gable(-w / 2, w / 2, h * 0.5, h * 0.28, 0.8), ...prism(-w / 2, -w * 0.18, h * 0.5, h * 0.78, 0.5), P('roof', [-w / 2, h * 0.78], [-w * 0.18 - 0.5, h * 0.78], [-w * 0.34, h])],
  quay: (w, h) => { const o = prism(-w / 2, w / 2, 0, h, 0.6); for (let i = 0; i < 5; i++) o.push(...prism(-w / 2 + 0.6 + i * (w - 1.2) / 4 - 0.2, -w / 2 + 0.6 + i * (w - 1.2) / 4 + 0.2, h, h + 0.9, 0.1)); return o; },
  crane: (w, h) => [...prism(-0.25, 0.25, 0, h, 0.1), P('roof', [-0.25, h * 0.92], [w * 3.2, h * 0.88], [w * 3.2, h * 0.92], [0.25, h]), ...prism(-w * 0.6, w * 0.6, 0, h * 0.12, 0.3)],
  mast: (w, h) => [...prism(-0.15, 0.15, 0, h, 0.06), P('front', [-w * 1.6, h * 0.72], [w * 1.6, h * 0.72], [w * 1.6, h * 0.72 + 0.25], [-w * 1.6, h * 0.72 + 0.25])],
  lighthouse: (w, h) => [P('front', [-w / 2, 0], [0, 0], [0, h * 0.78], [-w * 0.3, h * 0.78]), P('side', [0, 0], [w / 2, 0], [w * 0.3, h * 0.78], [0, h * 0.78]), P('band2', [-w * 0.42, h * 0.3], [w * 0.42, h * 0.3], [w * 0.36, h * 0.52], [-w * 0.36, h * 0.52]), P('glass', [-w * 0.3, h * 0.78], [w * 0.3, h * 0.78], [w * 0.3, h * 0.9], [-w * 0.3, h * 0.9]), P('roof', [-w * 0.36, h * 0.9], [w * 0.36, h * 0.9], [0, h])],
};
const SHAPE_INFO = {
  shaft: ['a plain tall prism, a low plant box on top', 90, 4], stepped: ['two or three setbacks, the top tier 60 percent wide', 70, 5], crown: ['the top corners chamfered in one facet: a cut gem', 80, 4], spire: ['a shaft under a four-sided pyramid; rare, never a needle', 120, 5],
  slab: ['a wide, flat-fronted mid-rise', 35, 7], block: ['a near-square mid-rise, parapet and plant box', 30, 5], warehouse: ['a long low box, shallow gable, door panels', 7, 10], sawtooth: ['a long low building under a run of saw teeth', 6, 11],
  chimney: ['a tall octagonal stack, tapered, flared cap', 20, 2], house: ['a box under a 35 to 40 degree gable', 4.5, 4], thatch: ['a house under a steep (55 degree), deep-eaved roof', 5.5, 4], terrace: ['a house in three stone steps up a slope', 5, 5],
  shop: ['a house with a wide front and a flat awning facet', 4.5, 4], shed: ['a lean-to with one roof facet', 3, 5], hall: ['a long gable with a stepped porch', 8, 8], chapel: ['a gable with a three-sided belfry at one end', 12, 5],
  quay: ['a long low platform with post stubs', 1, 12], crane: ['a mast with a long faceted jib, off centre', 18, 2], mast: ['a thin pole with a yard arm', 12, 0.8], lighthouse: ['an octagonal tapering tower, lantern room, cone', 40, 4],
};
const SHAPE_ORDER = ['shaft', 'stepped', 'crown', 'spire', 'slab', 'block', 'warehouse', 'sawtooth', 'chimney', 'house', 'thatch', 'terrace', 'shop', 'shed', 'hall', 'chapel', 'quay', 'crane', 'mast', 'lighthouse'];
const NEW = new Set(['crown', 'terrace', 'sawtooth', 'thatch', 'quay', 'mast']);

// ---------------------------------------------------------------------------------------------------------- drawing
const NEUTRAL = { front: '#b8c0cc', side: '#8a93a3', roof: '#5b6474', glass: '#9fd6e4', dark: '#2a2f3a', band1: '#dfe3ea', band2: '#6b7280', accent: '#c9a55a', line: '#20282e' };
function poly(pl, pal, x, ground, sx, sy = sx) {
  return pl.map(q => `<polygon points="${q.p.map(([a, b]) => `${F(x + a * sx)},${F(ground - b * sy)}`).join(' ')}" fill="${pal[q.t] ?? pal.front}" stroke="${pal.line ?? '#20282e'}" stroke-width="0.7" stroke-linejoin="round"/>`).join('');
}
function person(x, ground, s) {   // one fighter height, for scale
  const h = s, w = s * 0.42;
  return `<g fill="#1b1428" opacity="0.75"><rect x="${F(x - w / 2)}" y="${F(ground - h * 0.78)}" width="${F(w)}" height="${F(h * 0.52)}"/><circle cx="${F(x)}" cy="${F(ground - h * 0.87)}" r="${F(h * 0.11)}"/><rect x="${F(x - w * 0.42)}" y="${F(ground - h * 0.28)}" width="${F(w * 0.34)}" height="${F(h * 0.28)}"/><rect x="${F(x + w * 0.08)}" y="${F(ground - h * 0.28)}" width="${F(w * 0.34)}" height="${F(h * 0.28)}"/></g>`;
}

// a deterministic stream (a linear congruential generator seeded from a string): the chart never uses Math.random
function stream(seed) { let h = 2166136261; for (const c of seed) { h ^= c.charCodeAt(0); h = Math.imul(h, 16777619) >>> 0; } return () => { h = (Math.imul(h, 1664525) + 1013904223) >>> 0; return h / 4294967296; }; }

// ---------------------------------------------------------------------------------------------------------- the looks
const dist = (sid, name) => DATA.settlements.find(s => s.id === sid).districts.find(d => d.name === name);
const LOOKS = [
  { id: 'downtown', dist: dist('bellgate', 'downtown'), mix: [['shaft', 0.4], ['stepped', 0.3], ['crown', 0.25], ['spire', 0.05]], pal: { front: '#b8c0cc', side: '#7f8896', roof: '#4a5261', glass: '#6aa0c0', dark: '#2c4a63', band1: '#dfe3ea', band2: '#7f8896' }, win: 'vbands', note: 'Uneven and tall, rising to the middle: continuous glass bands between pale piers, flat roofs with plant boxes, setbacks and chamfers.' },
  { id: 'mid_rise', dist: dist('bellgate', 'mid_rise_west'), mix: [['slab', 0.7], ['block', 0.3]], pal: { front: '#c6ccd6', side: '#8a93a3', roof: '#5b6474', glass: '#6aa0c0', dark: '#4a5261', band1: '#dfe3ea', band2: '#7f8896' }, win: 'hstrips', note: 'A wall of slabs with regular gaps: two horizontal window strips a storey, pale sills, a parapet.' },
  { id: 'suburb', dist: dist('bellgate', 'suburb_west'), mix: [['house', 0.85], ['shop', 0.15]], pal: { front: '#d9cfc0', side: '#b9ac8f', roof: '#5b6474', glass: '#9fd6e4', dark: '#7a5a3c', band1: '#eee6d6', band2: '#7a5a3c', accent: '#7a5a3c' }, win: 'grid', note: 'Low, small and rhythmic: repeated gables with small windows, two or three to a facade, one direction per block.' },
  { id: 'industrial', dist: dist('bellgate', 'industrial'), mix: [['warehouse', 0.45], ['sawtooth', 0.4], ['chimney', 0.15]], pal: { front: '#8a8f98', side: '#6b7280', roof: '#4a4a4f', glass: '#9fd6e4', dark: '#2f2a2a', band1: '#a9aeb7', band2: '#8a5a48' }, win: 'clerestory', note: 'Long and low, broken by tall stacks: a clerestory strip under the roof, big door panels, sawtooth or shallow gable.' },
  { id: 'harbour', dist: dist('netmend', 'harbour'), mix: [['shed', 0.35], ['house', 0.15], ['quay', 0.2], ['crane', 0.1], ['mast', 0.2]], pal: { front: '#eee6d6', side: '#b9ac8f', roof: '#4c6f8e', glass: '#9fd6e4', dark: '#7a5a3c', band1: '#f4efe4', band2: '#7a5a3c' }, win: 'doors', note: 'Low sheds along a quay, with crane and mast verticals and one lighthouse: few windows, wide doors, a loft hatch.' },
  { id: 'village_harbour', dist: dist('netmend', 'village_core'), mix: [['house', 0.6], ['shop', 0.2], ['mast', 0.2]], pal: { front: '#eee6d6', side: '#c9bfa8', roof: '#4c6f8e', glass: '#9fd6e4', dark: '#4c6f8e', band1: '#f4efe4', band2: '#7a5a3c' }, win: 'squares', note: 'Cool white cottages stepping down to the quay: small square windows with blue shutters, a horizontal rhythm.' },
  { id: 'village_workshop', dist: dist('bellgate', 'suburb_east'), mix: [['sawtooth', 0.4], ['house', 0.35], ['chimney', 0.25]], pal: { front: '#a5533f', side: '#7d3f30', roof: '#4a4a4f', glass: '#d9c9a0', dark: '#2f2a2a', band1: '#c98a70', band2: '#a07d55' }, win: 'squares', note: 'Brick and soot: sawtooth sheds and kiln stacks, small square windows in dark frames, repeated verticals with smoke.' },
  { id: 'village_hill', dist: dist('far_village', 'village_core'), mix: [['thatch', 0.45], ['terrace', 0.4], ['house', 0.15]], pal: { front: '#8a8f7a', side: '#666b58', roof: '#c9a55a', glass: '#d9c9a0', dark: '#3a3f33', band1: '#a7ac95', band2: '#6f8a4a' }, win: 'tiny', note: 'Stone and straw on a slope: tiny windows in thick walls, steep thatch, stepped diagonals.' },
];
function windows(kind, x0, x1, y0, y1, pal, sx, sy) {   // window overlays on a facade rectangle in bh (sx and sy: pixels per bh across and up)
  const o = [], c = pal.glass, w = x1 - x0, h = y1 - y0;
  const r = (a, b, c2, d) => o.push(`<rect x="${F(a * sx)}" y="${F(-(b + d) * sy)}" width="${F(Math.max(0.5, c2 * sx))}" height="${F(Math.max(0.5, d * sy))}" fill="${c}" opacity="0.85"/>`);
  if (kind === 'vbands') for (let i = 0; i < Math.floor(w / 0.9); i++) r(x0 + 0.25 + i * 0.9, y0 + 0.6, 0.5, h - 1.2);
  if (kind === 'hstrips') for (let j = 0; j < Math.floor(h / 4); j++) { const b = y0 + 1.2 + j * 4; r(x0 + 0.5, b + 1.4, w - 1, 0.8); r(x0 + 0.5, b + 0.3, w - 1, 0.5); }
  if (kind === 'grid') for (let i = 0; i < 2; i++) r(x0 + w * (0.2 + i * 0.4), y0 + h * 0.3, w * 0.2, h * 0.22);
  if (kind === 'clerestory') r(x0 + 0.4, y1 - 1.4, w - 0.8, 0.7);
  if (kind === 'doors') { r(x0 + w * 0.2, y0, w * 0.16, h * 0.5); r(x0 + w * 0.6, y0, w * 0.14, h * 0.2); }
  if (kind === 'squares' || kind === 'tiny') for (let i = 0; i < 2; i++) r(x0 + w * (0.22 + i * 0.4), y0 + h * 0.34, kind === 'tiny' ? 0.35 : w * 0.14, kind === 'tiny' ? 0.35 : h * 0.16);
  return o.join('');
}
function strip(look, x, y, W, H) {
  const rnd = stream(look.id), d = look.dist, hb = d.height_bh, wb = d.width_bh;
  // the buildings: heights and widths from the district's data (median, spread, min and max), drawn in order
  const items = []; let cursor = 0;
  const cap = look.id === 'downtown' ? 160 : look.id === 'mid_rise' ? 50 : look.id === 'industrial' ? 26 : 18;
  while (cursor < (look.id === 'downtown' ? 235 : 120)) {
    const u = rnd(); let acc = 0, shape = look.mix[0][0]; for (const [sh, wgt] of look.mix) { acc += wgt; if (u <= acc) { shape = sh; break; } }
    const info = SHAPE_INFO[shape], spread = hb.spread ?? 0.3;
    let h = Math.min(cap, Math.max(hb.min ?? 2, hb.median * Math.exp((rnd() - 0.5) * spread * 3)));
    let w = wb[0] + rnd() * (wb[1] - wb[0]);
    if (['chimney', 'crane', 'mast', 'lighthouse', 'quay', 'spire'].includes(shape)) { h = info[1] * (0.85 + rnd() * 0.3); w = info[2]; }
    if (shape === 'quay') { h = 1; w = 14; }
    if (look.id === 'downtown' && ['shaft', 'stepped', 'crown'].includes(shape)) h = Math.max(hb.min ?? 30, Math.min(cap, 40 + Math.abs(Math.sin(cursor / 14 + 1)) * 110 * (0.6 + rnd() * 0.4)));
    items.push({ shape, h, w, x: cursor + w / 2 }); cursor += w + (look.id === 'downtown' ? 1 : 2) + rnd() * 1.5;
  }
  const maxH = Math.max(...items.map(i => i.h)), stretch = look.id === 'downtown' ? 3 : 1, s = Math.min((H - 40) / maxH, (W - 20) / cursor / stretch), sx = s * stretch, ground = y + H - 16;
  let o = rect(x, y, W, H, '#dfe8ee', 'stroke="#1b1428" stroke-opacity="0.25"');
  o += `<clipPath id="c-${look.id}"><rect x="${x}" y="${y}" width="${W}" height="${H}"/></clipPath><g clip-path="url(#c-${look.id})">`;
  o += rect(x, ground, W, 16, look.id === 'village_hill' ? look.pal.band2 : '#b9b39f', 'opacity="0.9"');
  const ox = x + (W - cursor * sx) / 2;
  for (const it of items) {
    const pl = SHAPES[it.shape](it.w, it.h), pal = { ...NEUTRAL, ...look.pal };
    o += poly(pl, pal, ox + it.x * sx, ground, sx, s);
    if (['shaft', 'stepped', 'crown', 'slab', 'block', 'house', 'shop', 'warehouse', 'thatch'].includes(it.shape) && sx * it.w > 4) o += `<g transform="translate(${F(ox + it.x * sx)} ${F(ground)})">${windows(look.win, -it.w / 2, it.w / 2 - Math.min(it.w * 0.22, 1.2), 0, it.h * (['house', 'shop', 'thatch'].includes(it.shape) ? 0.55 : 0.95), pal, sx, s)}</g>`;
  }
  o += person(ox - 3 * sx, ground, s) + '</g>';
  o += text(x + 10, y + 20, look.id, { size: 15, weight: 700 });
  o += text(x + W - 10, y + 20, `${d.height_bh.median} bh median, up to ${d.height_bh.max ?? '?'}  (one fighter for scale${stretch > 1 ? `; widths drawn ${stretch} times wider` : ''})`, { size: 10.5, anchor: 'end', op: 0.75 });
  return o;
}

// ---------------------------------------------------------------------------------------------------------- the five landmarks
const LAND = {
  bell_tower: { w: 5, h: 150, note: 'The Gatebell: a stone shaft with an open four-arch belfry, a dark bell cone, an eight-sided spire and an off-centre stair bump.', legal: 'Legal (RL-040): no clock face, and never a spire over four clock faces.', build: (w, h) => {
    const o = [...prism(-w * 0.4, w * 0.4, 0, h * 0.62), ...prism(w * 0.4 - 0.2, w * 0.4 + 1.2, 0, h * 0.3, 0.4)];
    const bx0 = -w * 0.44, bx1 = w * 0.44, by0 = h * 0.62, by1 = h * 0.78;
    o.push(...prism(bx0, bx1, by0, by1, 0.9));
    for (let i = 0; i < 4; i++) { const a = bx0 + 0.25 + i * ((bx1 - bx0 - 1.4) / 4); o.push(P('dark', [a, by0 + 0.6], [a + 0.55, by0 + 0.6], [a + 0.55, by1 - 1.2], [a + 0.27, by1 - 0.4], [a, by1 - 1.2])); }
    o.push(P('band2', [-0.6, by0 + 0.8], [0.6, by0 + 0.8], [0, by0 + 3.6]));
    o.push(P('roof', [bx0, by1], [bx1 - 0.9, by1], [-0.05, h]), P('side', [bx1 - 0.9, by1], [bx1, by1], [-0.05, h]));
    return o; } },
  chimney_stack: { w: 3, h: 45, note: 'A banded octagonal stack in pale stone and soot grey bands, a wide flared cap and a short side flue.', legal: 'Legal (RL-040): no red-and-white stripes, no cooling-tower shape.', build: (w, h) => {
    const o = [P('front', [-w / 2, 0], [0, 0], [0, h * 0.9], [-w * 0.36, h * 0.9]), P('side', [0, 0], [w / 2, 0], [w * 0.36, h * 0.9], [0, h * 0.9])];
    o.push(P('band2', [-w / 2 + 0.05, h * 0.18], [w / 2 - 0.05, h * 0.18], [w * 0.47, h * 0.36], [-w * 0.47, h * 0.36]), P('band2', [-w * 0.42, h * 0.54], [w * 0.42, h * 0.54], [w * 0.4, h * 0.7], [-w * 0.4, h * 0.7]));
    o.push(P('band1', [-w * 0.52, h * 0.9], [w * 0.52, h * 0.9], [w * 0.64, h], [-w * 0.64, h]), ...prism(w * 0.3, w * 0.3 + 0.9, 0, h * 0.22, 0.3));
    return o; } },
  lighthouse: { w: 4, h: 40, note: 'An octagonal tapering tower in two plain wide bands (pale stone, slate), a faceted lantern room of pale cyan glass under a low cone.', legal: 'Legal (RL-040): plain wide bands only; no spiral, diagonal or black-and-white banding; no beam.', build: (w, h) => [
    P('front', [-w / 2, 0], [0, 0], [0, h * 0.76], [-w * 0.3, h * 0.76]), P('side', [0, 0], [w / 2, 0], [w * 0.3, h * 0.76], [0, h * 0.76]),
    P('band2', [-w * 0.44, h * 0.26], [w * 0.44, h * 0.26], [w * 0.37, h * 0.5], [-w * 0.37, h * 0.5]),
    P('front', [-w * 0.36, h * 0.76], [w * 0.36, h * 0.76], [w * 0.36, h * 0.8], [-w * 0.36, h * 0.8]),
    P('glass', [-w * 0.28, h * 0.8], [w * 0.28, h * 0.8], [w * 0.28, h * 0.9], [-w * 0.28, h * 0.9]), P('roof', [-w * 0.36, h * 0.9], [w * 0.36, h * 0.9], [0, h])] },
  village_hall: { w: 8, h: 9, note: 'A long timber hall with a steep central gable, a stepped porch and a small faceted lantern on the ridge.', legal: 'Legal (RL-040): stays generic.', build: (w, h) => [
    ...prism(-w / 2, w / 2, 0, h * 0.5, 0.9), ...gable(-w / 2, w / 2, h * 0.5, h * 0.42, 0.9),
    ...prism(-w * 0.14, w * 0.14, 0, h * 0.3, 0.4), ...gable(-w * 0.17, w * 0.17, h * 0.3, h * 0.16, 0.4),
    ...prism(-w * 0.06, w * 0.06, h * 0.9, h * 1.0, 0.25), P('roof', [-w * 0.08, h], [w * 0.08 - 0.2, h], [0, h * 1.12]),
    P('dark', [-w * 0.4, h * 0.14], [-w * 0.3, h * 0.14], [-w * 0.3, h * 0.36], [-w * 0.4, h * 0.36]), P('dark', [w * 0.22, h * 0.14], [w * 0.32, h * 0.14], [w * 0.32, h * 0.36], [w * 0.22, h * 0.36])] },
  hill_chapel: { w: 5, h: 14, note: 'A stone chapel on a terrace step with a steep thatch roof and a small three-sided belfry at one end; the bell is one dark facet.', legal: 'Legal (RL-040): stays generic.', build: (w, h) => [
    P('band2', [-w * 0.8, -0.5], [w * 0.8, -0.5], [w * 0.8, 0], [-w * 0.8, 0]),
    ...prism(-w / 2, w / 2, 0, h * 0.42, 0.7), ...gable(-w * 0.58, w * 0.58, h * 0.42, h * 0.36, 0.7),
    ...prism(-w / 2, -w * 0.16, h * 0.42, h * 0.8, 0.5), P('dark', [-w * 0.4, h * 0.56], [-w * 0.26, h * 0.56], [-w * 0.26, h * 0.7], [-w * 0.4, h * 0.7]), P('roof', [-w / 2, h * 0.8], [-w * 0.16 - 0.5, h * 0.8], [-w * 0.33, h]),
    P('dark', [-w * 0.05, 0], [w * 0.1, 0], [w * 0.1, h * 0.24], [-w * 0.05, h * 0.24])] },
};
const LAND_PAL = { bell_tower: { front: '#aab0bb', side: '#7f8896', roof: '#4a5261', dark: '#2a2f3a', band2: '#3a3f48' }, chimney_stack: { front: '#c4bcb0', side: '#8f877b', roof: '#4a4a4f', band1: '#4a4a4f', band2: '#3a3430' }, lighthouse: { front: '#eee6d6', side: '#b9ac8f', roof: '#4c6f8e', band2: '#4c6f8e', glass: '#9fd6e4' }, village_hall: { front: '#a9835a', side: '#7a5a3c', roof: '#4c6f8e', dark: '#3a2a1c' }, hill_chapel: { front: '#8a8f7a', side: '#666b58', roof: '#c9a55a', dark: '#2a2f24', band2: '#6f8a4a' } };

// ---------------------------------------------------------------------------------------------------------- the sheet
function sheet() {
  const W = 1800;
  let b = '', y = 0;
  b += rect(0, 0, W, 104, '#1b1428') + text(30, 48, 'Buildings, districts and landmarks: the silhouette chart', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'Twenty faceted shapes, eight district looks and five landmarks, all original and generic. Every building is a prism with at most three roof facets. Working labels, pending Legal review. Brief: docs/art/district-looks.md.', { size: 14, fill: '#cfc6e6' });
  y = 130;
  b += text(24, y, 'A. The twenty shapes (new shapes are marked; each is drawn at its own scale, with one fighter for scale)', { size: 18, weight: 700 });
  y += 14;
  const cw = 352, ch = 260;
  SHAPE_ORDER.forEach((id, i) => {
    const col = i % 5, row = Math.floor(i / 5), x0 = 24 + col * (cw + 6), y0 = y + row * (ch + 6), [note, h, w] = SHAPE_INFO[id];
    b += rect(x0, y0, cw, ch, '#e6e9ee', 'stroke="#1b1428" stroke-opacity="0.2"');
    const squat = h > w * 3.4 && !['crane', 'mast', 'quay'].includes(id), hd = squat ? w * 3.4 : h;
    const ground = y0 + 172, extent = id === 'crane' ? w * 3.4 : w, s = Math.min(150 / Math.max(hd, 1), (cw - 80) / Math.max(extent, 1) * 0.9, 40);
    b += rect(x0, ground, cw, 2, '#7d7264', 'opacity="0.5"');
    b += poly(SHAPES[id](w, hd), NEUTRAL, x0 + cw / 2 - (id === 'crane' ? w * 1.2 * s : 0), ground, s) + (squat ? '' : person(x0 + 26, ground, s));
    b += text(x0 + 10, y0 + 20, id + (NEW.has(id) ? '  (new)' : id === 'shaft' ? '  (was tower)' : ''), { size: 15, weight: 700 });
    b += text(x0 + cw - 10, y0 + 20, `${h} bh tall, ${w} wide${squat ? ' (drawn squat)' : ''}`, { size: 10.5, anchor: 'end', op: 0.7 });
    b += paras(x0 + 10, y0 + 198, note, 54, 11.5, 14.5, { op: 0.9 });
  });
  y += 4 * (ch + 6) + 24;
  b += text(24, y, 'B. The eight looks, as a street of the district\'s own shapes at the district\'s data heights (the window pattern and the palette lane are the look)', { size: 18, weight: 700 });
  y += 14;
  const sw = 884, sh = 232;
  LOOKS.forEach((l, i) => {
    const col = i % 2, row = Math.floor(i / 2), x0 = 24 + col * (sw + 8), y0 = y + row * (sh + 52);
    b += strip(l, x0, y0, sw, sh);
    b += paras(x0 + 2, y0 + sh + 16, l.note, 150, 11.5, 14, { op: 0.9 });
    [l.pal.front, l.pal.side, l.pal.roof, l.pal.glass ?? l.pal.dark].forEach((c, k) => { b += rect(x0 + sw - 4 - (4 - k) * 26, y0 + 28, 22, 14, c, 'stroke="#1b1428" stroke-opacity="0.3"'); });
  });
  y += 4 * (sh + 52) + 16;
  b += text(24, y, 'C. The five landmarks (one fighter for scale; heights from settlements.json)', { size: 18, weight: 700 });
  y += 14;
  const lw = 352, lh = 400;
  Object.keys(LAND).forEach((key, i) => {
    const L = LAND[key], x0 = 24 + i * (lw + 6), ground = y + 300, s = Math.min(270 / L.h, 40), stretch = L.h > L.w * 3 ? Math.min(3.5, (lw - 120) / (L.w * s * 1.4)) : 1, sx = s * stretch;
    b += rect(x0, y, lw, lh, '#dfe8ee', 'stroke="#1b1428" stroke-opacity="0.25"') + rect(x0, ground, lw, 2, '#7d7264', 'opacity="0.6"');
    b += poly(L.build(L.w, L.h), { ...NEUTRAL, ...LAND_PAL[key] }, x0 + lw / 2, ground, sx, s) + person(x0 + 24, ground, s);
    b += text(x0 + 10, y + 20, key, { size: 15, weight: 700 }) + text(x0 + lw - 10, y + 20, `${L.h} bh tall${stretch > 1 ? `, widths x${stretch.toFixed(1)}` : ''}`, { size: 10.5, anchor: 'end', op: 0.7 });
    b += paras(x0 + 10, y + 324, L.note, 56, 11.5, 14.5, { op: 0.9 });
    b += paras(x0 + 10, y + 324 + 14.5 * 3 + 6, L.legal, 56, 10.5, 13.5, { op: 0.75, fill: '#5a2a2a' });
  });
  y += lh + 30;
  b += text(30, y, 'Faceted rule kept: prisms, octagonal stacks and three roof facets at most. Nothing here reproduces a real landmark, and no fighter lane hue (teal, orchid, moss, coral) or mid blue is a building mass.', { size: 12, op: 0.8 });
  const H = y + 30;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${rect(0, 0, W, H, '#dcd8e6')}${b}</svg>`;
}
const ORIGIN = '<!-- Origin: procedural chart written by art/concepts/world/gen.mjs (deterministic, no external images or fonts), Art Director session (Claude, claude-sonnet-5-5), 2026-09-30; prompt record art/prompts/ART-0009-district-chart.md -->' + String.fromCharCode(10);
writeFileSync(join(ROOT, 'docs', 'art', 'district-shapes.svg'), ORIGIN + sheet());
console.log('wrote docs/art/district-shapes.svg');
