// Origin: procedural glasses for the Anti-hero's unmasked face and figure (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-10-02. Human direction: Orb, via the EP ("the rival should have glasses: our resident scary shiny glasses character").
// Six frame shapes in his blade and plate language, each with three lens states (clear, glare, glint) and four damage stages. Lit parts stay in his violet range: the glare is a pale violet, never white.

import { H } from '../closeups/engine.mjs';
import * as FA from './faces.mjs';
const { poly, line, ell, pts } = H;

const FRAME_INK = '#4a3a86', FRAME_LIT = '#b79af0', TINT = '#2f2358', GLARE = '#c0a0ee', GLARE_HI = '#d8c2f8', GLARE_HALO = '#a47ee8';
// Legal's rules (RL-066): angular, tapered or hexagonal lenses cut asymmetrically, a thin frame in his violet; never thin round wire, never narrow tinted rectangles or a half-rim,
// no bar or visor, no readout or scan bar on a lens. Normal lenses are a dark violet tint; the glare is one hard-edged pale-violet wedge, never white, held 0.4 s at most.
const C = [68, -36];   // the centre of the right lens in face coordinates (the art faces right; the eyes are at x = +-62, y = -36)

// right-lens outlines, relative to C (the left lens is the mirror)
export const FRAMES = {
  cuthex: { name: 'Cut hex', sw: 5, lens: [[-54, -4], [-30, -28], [32, -30], [60, 0], [26, 22], [-40, 22]] },
  blade: { name: 'Blade lenses', sw: 5, lens: [[-54, -14], [10, -30], [74, -26], [36, 14], [-44, 18]] },
  chamfer: { name: 'Chamfer plates', sw: 5, lens: [[-54, -24], [36, -24], [54, -6], [54, 22], [-36, 22], [-54, 4]] },
  shard: { name: 'Shard', sw: 5, lens: [[-56, -22], [62, -30], [24, 20], [-40, 24]] },
  slash: { name: 'Slash cut', sw: 5, lens: [[-50, -26], [46, -30], [58, -8], [34, 22], [-58, 18]] },
  kite: { name: 'Kite', sw: 5, lens: [[-56, -6], [-8, -30], [56, -18], [30, 18], [-20, 22]] },
  // the lead with its chamfers (the plate cuts on the frame) changed, and dropped: for the side-by-side
  bladebevel: { name: 'Blade lenses, chamfers changed', sw: 5, lens: [[-54, -6], [-42, -20], [10, -31], [68, -28], [76, -22], [36, 14], [-34, 19], [-52, 10]], tabs: true, topplate: true },
  bladebare: { name: 'Blade lenses, chamfers dropped', sw: 4, lens: [[-52, -12], [74, -28], [36, 14], [-46, 16]], lit: false },
};

const abs = key => FRAMES[key].lens.map(([x, y]) => [x * 1.12 + C[0], y * 1.28 + C[1]]);
const mirror = a => a.map(([x, y]) => [-x, y]).reverse();
const centroid = a => a.reduce((s, [x, y]) => [s[0] + x / a.length, s[1] + y / a.length], [0, 0]);
// a shard missing from a lens: the second-to-last corner is bitten in toward the centre
function bite(a) {
  const n = a.length, k = n - 2, c = centroid(a), v = a[k], p = a[k - 1], q = a[k + 1];
  const apex = [v[0] + (c[0] - v[0]) * 0.5, v[1] + (c[1] - v[1]) * 0.5], m1 = [(v[0] + p[0]) / 2, (v[1] + p[1]) / 2], m2 = [(v[0] + q[0]) / 2, (v[1] + q[1]) / 2];
  return [...a.slice(0, k), m1, apex, m2, ...a.slice(k + 1)];
}
// the glint: one hard-edged wedge (a flat sweep cut in his blade language), pointed at the lower left and widening toward the upper right
const wedge = (cx, cy, k = 1) => poly([[cx - 44 * k, cy + 30], [cx + 14 * k, cy - 46], [cx + 40 * k, cy - 46], [cx - 20 * k, cy + 30]], GLARE_HI);

// a small chamfered hinge tab on the outer end of a lens (the 'plates' of the changed variant)
function tab(a, s) {
  const o = a.reduce((m, p) => (s * p[0] > s * m[0] ? p : m), a[0]), d = s;
  return poly([[o[0] - d * 2, o[1] - 7], [o[0] + d * 14, o[1] - 7], [o[0] + d * 20, o[1] - 1], [o[0] + d * 20, o[1] + 7], [o[0] - d * 2, o[1] + 7]], FRAME_INK);
}

// the glasses layer, drawn over the face. state: 'clear' | 'glare' | 'glint'; stage: 0 to 3 (the battle damage); t: the glint's place, 0 to 1
export function glassesLayer(key, state, stage, t, id) {
  const F = FRAMES[key];
  let R = abs(key), L = mirror(R);
  if (stage >= 3) R = bite(R);
  // bent frame: the far lens turns and drops a little more at each stage
  const trR = stage >= 3 ? 'translate(2 10) rotate(-10 10 -34)' : stage >= 2 ? 'rotate(-5 10 -34)' : '';
  const trL = stage >= 3 ? 'translate(0 2) rotate(2 -10 -34)' : '';
  const lenses = [[L, trL, -1], [R, trR, 1]];
  let o = '';
  if (state === 'glare') for (const [a, tr] of lenses) o += `<g transform="${tr}">${poly(a, 'none', `stroke="${GLARE_HALO}" stroke-width="20" stroke-linejoin="round" opacity="0.26"`)}</g>`;
  lenses.forEach(([a, tr, s], i) => {
    const c = centroid(a), cid = `gl-${id}-${i}`;
    let inner;
    if (state === 'glare') inner = poly(a, GLARE) + `<clipPath id="${cid}"><polygon points="${pts(a)}"/></clipPath><g clip-path="url(#${cid})">${wedge(c[0] + 6 * s, c[1], s)}</g>`;
    else {
      inner = poly(a, TINT, 'opacity="0.46"') + `<clipPath id="${cid}"><polygon points="${pts(a)}"/></clipPath><g clip-path="url(#${cid})">`;
      if (state === 'glint') inner += `<g transform="translate(${-150 + t * 300} 0)">${wedge(0, c[1], 1)}</g>`;
      inner += '</g>';
    }
    // the lens, then the thin rim and its lit top edge
    o += `<g transform="${tr}">${inner}${poly(a, 'none', `stroke="${FRAME_INK}" stroke-width="${F.sw}" stroke-linejoin="round"`)}${F.topplate ? line([...a.slice(0, 2)], FRAME_INK, 10) : ''}${F.lit === false ? '' : line([...a.slice(0, 2)], FRAME_LIT, 2, 'opacity="0.9"')}${F.tabs ? tab(a, s) : ''}`;
    // damage on the lens: a scratch, then one crack, then two parallel cracks (never crossing)
    if (stage >= 1) o += line([[c[0] - 20, c[1] - 12], [c[0] + 12, c[1] + 8]], '#efe6fc', 2.4, 'opacity="0.8"');
    if (stage >= 2 && s === 1) o += line([[c[0] + 24, c[1] - 26], [c[0] + 6, c[1] - 6], [c[0] + 14, c[1] + 12]], FRAME_INK, 3.4) + line([[c[0] + 24, c[1] - 26], [c[0] + 6, c[1] - 6], [c[0] + 14, c[1] + 12]], '#efe6fc', 1.2);
    if (stage >= 3 && s === -1) o += line([[c[0] - 10, c[1] - 26], [c[0] - 22, c[1] - 4], [c[0] - 12, c[1] + 18]], FRAME_INK, 3.4) + line([[c[0] + 22, c[1] - 24], [c[0] + 14, c[1] - 2], [c[0] + 24, c[1] + 16]], FRAME_INK, 3.4);
    o += '</g>';
  });
  // a thin bridge, and thin arms
  const br = stage >= 3 ? 'translate(1 5) rotate(5 0 -40)' : '';
  o += `<g transform="${br}">${poly([[-12, -46], [12, -46], [12, -40], [-12, -40]], FRAME_INK)}</g>`;
  o += line([[124, -44], [152, -48]], FRAME_INK, 4) + line([[-128, -44], [-166, -50]], FRAME_INK, 4);
  return o;
}

// battle damage on the face itself (the unmasked skin): a bruise, a cut above the brow and a loose strand, then a split lip; never red, never crossing
function skinDamage(stage, P) {
  if (!stage) return '';
  const bruise = '#6d3a78'; let o = poly(ell(86, 52, 34, 22, 14), bruise, 'opacity="0.5"');
  o += line([[-20, 6], [-4, 24]], P.skinSh, 4, 'opacity="0.8"');
  if (stage >= 2) o += line([[96, -102], [118, -92]], P.line, 5) + line([[20, -120], [14, -102]], P.hair, 6) + poly(ell(-74, 60, 24, 15, 12), bruise, 'opacity="0.5"');
  if (stage >= 3) o += poly(ell(86, 52, 44, 28, 14), bruise, 'opacity="0.65"') + line([[30, 112], [46, 122]], P.line, 4);
  return o;
}

// the face with the glasses on: a draw function for portrait('X', 'A', expr, id, { draw })
export const glassedFace = (key, state, stage = 0, t = 0.4) => (fk, e, id, P) => state === 'off'
  ? FA.refined('A', e, id, P) + skinDamage(stage, P) + `<g transform="translate(150 -140) rotate(28) scale(0.78)">${glassesLayer(key, 'clear', 2, 0, id)}</g>`
  : FA.refined('A', e, id, P) + skinDamage(stage, P) + glassesLayer(key, state, stage, t, id);

// the glasses in profile, for the figure kit: a lens and an arm at the eye, in the frame's own shape (head units)
const PROF = {
  cuthex: [[1.2, 9.8], [2.8, 11.6], [5.6, 11.8], [7.2, 9.9], [5.4, 8.2], [2.6, 8.3]],
  blade: [[1.2, 9.2], [7.6, 10.8], [3.4, 11.2], [1.4, 10.4]],
  chamfer: [[1.4, 8.6], [5.6, 8.6], [7.0, 9.6], [7.0, 11.0], [2.8, 11.0], [1.4, 10.0]],
  shard: [[1.0, 8.8], [7.2, 9.4], [4.4, 11.2], [1.4, 11.0]],
  slash: [[1.2, 8.6], [6.6, 9.0], [7.2, 10.0], [5.4, 11.2], [1.2, 10.8]],
  kite: [[1.0, 9.6], [3.6, 8.4], [7.2, 9.0], [5.6, 10.8], [3.0, 11.2]],
  bladebevel: [[1.0, 9.6], [1.6, 9.0], [7.8, 10.5], [8.5, 10.9], [3.6, 11.3], [1.2, 10.7]],
  bladebare: [[1.2, 9.4], [7.6, 10.8], [3.4, 11.2], [1.4, 10.6]],
};
export function profileGlasses(key, state) {
  return (ctx, sk) => {
    const a = PROF[key].map(([x, y]) => sk.Hd(x, y)), arm = [sk.Hd(1.2, 9.7), sk.Hd(-3.6, 9.2)];
    let s = ctx.line(arm, FRAME_INK, 1.1) + ctx.poly(a, state === 'glare' ? GLARE : TINT, { sw: 1.2, op: state === 'glare' ? 1 : 0.6 });
    return s;
  };
}
export const INK = { FRAME_INK, FRAME_LIT, GLARE, GLARE_HI };
