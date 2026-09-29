// Origin: procedural generator for the Marked plus Aura sheets (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-09-29. Human direction: Orb, via the EP.
// Run from the repo root:  node art/concepts/marked-aura/gen.mjs   (writes ma-1-style.svg, ma-2-flashes.svg, ma-3-staging.svg, ma-4-flash-rules.svg, and data/art/flashes.json)
// The staging mock-ups embed the repo's own greybox renders in docs/rendering/img by relative path (not copies).

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeCtx, figure, CIVILIAN, CIV_POSES, POSES, V } from '../anti-hero/kit.mjs';
import { FIGHTERS, ORDER, LANE } from '../directions/fighters.mjs';
import { PAL, MASK, NAMES, NEUTRAL, curve, band, rot, scl, circ, FACE, yawMap, sigilMarks, maskHead, SIGPOS, pWraps, empressBack } from '../shared/marks.mjs';

const OUT = dirname(fileURLToPath(import.meta.url));
const F = n => n.toFixed(2);
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family=\"'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif\"";
const text = (x, y, t, { size = 14, weight = 400, fill = '#1b1428', anchor = 'start', op = 1, style = 'normal' } = {}) =>
  `<text x="${F(x)}" y="${F(y)}" ${FONT} font-size="${size}" font-weight="${weight}" font-style="${style}" fill="${fill}" text-anchor="${anchor}" opacity="${op}">${esc(t)}</text>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fill}" ${extra}/>`;
const wrap = (t, n) => { const w = t.split(' '), out = []; let line = ''; for (const x of w) { if ((line + ' ' + x).trim().length > n) { out.push(line.trim()); line = x; } else line += ' ' + x; } if (line.trim()) out.push(line.trim()); return out; };
const paras = (x, y, t, n, size = 13, gap = 17, o = {}) => wrap(t, n).map((l, i) => text(x, y + i * gap, l, { size, ...o })).join('');

export const YAW = 32;
export { PAL, MASK, NAMES };


// ---------------------------------------------------------------------------------------------------------- the flashes (emanata at the head)
// A brief, iconic pop at the head that says what a fighter senses or feels. At rest there is nothing. Each flash is drawn in the
// fighter's shape family (circles: Protagonist, blades: Anti-hero, wedges: Empress, steps: Cyborg) and comes in two classes:
//   info    (danger, found, searching): solid, crisp, keylined, at full opacity. Gameplay information.
//   emotion (the rest): translucent, softer, a rim and a lighter core. Feeling and state.
const LAY = {
  taunt: [{ a: 125, d: 10, s: 30, op: 0.42 }, { a: 152, d: 9, s: 22, op: 0.38 }, { a: 100, d: 8, s: 16, op: 0.34 }],
  hurt: [{ a: 205, d: 15, s: 9, op: 0.42 }, { a: 250, d: 20, s: 7, op: 0.36 }, { a: 165, d: 22, s: 8, op: 0.36 }, { a: 300, d: 16, s: 6, op: 0.32 }],
  brink: [{ a: 230, d: 18, s: 7, op: 0.34 }, { a: 190, d: 24, s: 6, op: 0.3 }, { a: 265, d: 22, s: 5, op: 0.26 }],
  rage: [{ a: 0, d: 10, s: 44, op: 0.55 }, { a: 24, d: 10, s: 56, op: 0.55 }, { a: 48, d: 10, s: 66, op: 0.55 }, { a: 74, d: 10, s: 56, op: 0.55 }, { a: 100, d: 10, s: 46, op: 0.5 }, { a: -24, d: 10, s: 36, op: 0.48 }, { a: 126, d: 10, s: 32, op: 0.46 }],
  triumph: [20, 40, 60, 80, 100, 120, 140, 160].map((a, i) => ({ a, d: 11, s: 42 + (i % 2) * 12, op: 0.5 })),
  pride: [{ a: 90, d: 10, s: 60, op: 0.46 }, { a: 78, d: 9, s: 44, op: 0.42 }, { a: 102, d: 9, s: 44, op: 0.42 }, { a: 66, d: 8, s: 28, op: 0.38 }, { a: 114, d: 8, s: 28, op: 0.38 }],
  fear: [{ a: 40, d: 30, s: 14, op: 0.42, inward: true }, { a: 90, d: 32, s: 16, op: 0.42, inward: true }, { a: 140, d: 30, s: 14, op: 0.42, inward: true }, { a: 15, d: 24, s: 10, op: 0.36, inward: true }, { a: 165, d: 24, s: 10, op: 0.36, inward: true }],
  resolve: [{ a: 20, d: 22, s: 13, op: 0.44, inward: true }, { a: 90, d: 26, s: 15, op: 0.44, inward: true }, { a: 160, d: 22, s: 13, op: 0.44, inward: true }, { a: 90, d: 6, s: 22, op: 0.5 }],
  // Danger sense is a pointer train: three aligned shapes, growing along one ray above and behind the head. The ray (a) is the default
  // and is rotated to the threat's bearing at run time (clamped to 60 to 200 degrees, so it is always above or behind, never around the head).
  danger: [{ a: 132, d: 12, s: 17, op: 0.95 }, { a: 132, d: 32, s: 24, op: 0.95 }, { a: 132, d: 57, s: 34, op: 0.95 }],
  surge: [...[60, 75, 90, 105, 120].map(a => ({ a, d: 10, s: 96, op: 0.55 })), ...[0, 30, 150, 180].map(a => ({ a, d: 12, s: 56, op: 0.5 })), ...[186, 196, 344, 354].map(a => ({ a, d: 50, s: 30, op: 0.42, ground: true }))],
};
// timing t = [attack, hold, fade] in seconds; pri 1 is the highest priority; cool is the per-fighter cooldown for the same flash.
export const FLASHES = {
  danger: { name: 'Danger sense', cls: 'info', kind: 'layout', t: [0.05, 0.15, 0.15], pri: 2, cool: 0.5, layout: LAY.danger, moment: 'A telegraphed heavy or beam, or an attack from off screen or behind. A parry window keeps the crown\'s ring, because a flash would double it.', sound: 'A low dry tick with a short upward sweep. No chirp, no stinger.', event: 'ambush, attack telegraph (Encounter)' },
  found: { name: 'Found', cls: 'info', kind: 'glyph', glyph: 'bang', t: [0.06, 0.3, 0.24], pri: 4, cool: 1.5, moment: 'A lost lock-on is regained: the rival is back in line of sight.', sound: 'One bright rising note, in the fighter\'s own pitch.', event: 'found, lock regained' },
  searching: { name: 'Searching', cls: 'info', kind: 'glyph', glyph: 'question', t: [0.1, 0.5, 0.3], pri: 5, cool: 3.0, moment: 'Lock-on lost: the rival has dropped out of line of sight and the fighter looks for it. It re-pops at most every 3 s while the search lasts.', sound: 'A wavering low two-note phrase.', event: 'lock lost, hunting (Encounter)' },
  brink: { cut: true, name: 'Brink', cls: 'emotion', kind: 'layout', t: [0.08, 0.35, 0.55], pri: 0, cool: 0, layout: LAY.brink, moment: 'The fighter enters the brink. Once per entry.', sound: 'A slow heartbeat thump.', event: 'brink_enter' },
  fear: { name: 'Fear', cls: 'emotion', kind: 'layout', t: [0.08, 0.35, 0.37], pri: 6, cool: 2.0, layout: LAY.fear, moment: 'An opponent starts a finisher, or the fighter watches a rival transform.', sound: 'A shiver: a quick tremolo on a held breath.', event: 'finisher_start against the fighter, cinematic_start of the rival' },
  rage: { name: 'Rage', cls: 'emotion', kind: 'layout', t: [0.12, 0.45, 0.35], pri: 7, cool: 1.5, layout: LAY.rage, moment: 'Drop the Act, a wrath spike, a boil-over, a humiliating parry.', sound: 'A growl that swells and cuts off.', event: 'drop_act, facade_crack, boil_over, shame_stack' },
  hurt: { name: 'Hurt', cls: 'emotion', kind: 'layout', t: [0.04, 0.16, 0.3], pri: 8, cool: 6.0, layout: LAY.hurt, moment: 'A heavy hit or a break launch, when the crown is not up. A flurry gives one flash: a six-second cooldown per fighter keeps it from being busy (AI play fired it about 9 times a minute).', sound: 'The fighter\'s pain grunt.', event: 'damage kind heavy, region_broken' },
  resolve: { sequence: { after: 'crown_wear_pop', delay_after_crown_down: 0.1, wait_max: 2.0, never_dropped: true }, name: 'Resolve', cls: 'emotion', kind: 'layout', t: [0.1, 0.35, 0.35], pri: 9, cool: 2.0, layout: LAY.resolve, moment: 'A Rally or Second Wind: the fighter gathers itself. It fires just after the crown\'s wear pop fades, and it is never dropped by arbitration.', sound: 'A breath in, then a low held note.', event: 'rally' },
  triumph: { name: 'Triumph', cls: 'emotion', kind: 'layout', t: [0.14, 0.5, 0.36], pri: 10, cool: 3.0, layout: LAY.triumph, moment: 'A finisher lands, or a KO for the winner.', sound: 'A bright chime with the fighter\'s laugh.', event: 'ko (winner), finisher landed' },
  pride: { name: 'Pride', cls: 'emotion', kind: 'layout', t: [0.2, 0.5, 0.2], pri: 11, cool: 4.0, layout: LAY.pride, moment: 'After a decisive exchange won, before the next one. The Anti-hero\'s front.', sound: 'A slow exhale and a held soft chord.', event: 'decisive exchange won' },
  taunt: { name: 'Taunt', cls: 'emotion', kind: 'layout', t: [0.1, 0.35, 0.3], pri: 13, cool: 2.0, layout: LAY.taunt, moment: 'A taunt line or gesture.', sound: 'The fighter\'s sneer or dry laugh.', event: 'taunt bark' },
  surge: { name: 'Surge', cls: 'emotion', kind: 'layout', t: [0.25, 3.0, 1.2], pri: 1, cool: 0, layout: LAY.surge, moment: 'A transformation: held for the respected cinematic (up to 3 s), then it fades in 1.2 s. The one flash that lasts.', sound: 'A rising swell that resolves on the new form\'s chord.', event: 'cinematic_start and cinematic_end', rare: true },
};
export const FLASH_ORDER = ['danger', 'hazard', 'found', 'searching', 'fear', 'rage', 'hurt', 'resolve', 'triumph', 'pride', 'respect', 'taunt', 'surge'];

// PITCH candidates (not in the canonical set or in flashes.json until Orb picks). Drawn with the same shape families and rules.
const CAND_ORDER = ['winded', 'smug', 'respect', 'bored', 'hazard', 'primed'];   // primed is held: hiding was removed from the base game
const CAND = {
  winded: { name: 'Winded', cls: 'emotion', kind: 'layout', t: [0.15, 0.5, 0.4], cool: 6, layout: [{ a: 238, d: 14, s: 10, op: 0.42 }, { a: 258, d: 22, s: 8, op: 0.38 }, { a: 214, d: 22, s: 7, op: 0.34 }] },
  smug: { name: 'Smug', cls: 'emotion', kind: 'layout', t: [0.15, 0.4, 0.3], cool: 5, layout: [{ a: 16, d: 12, s: 36, op: 0.45 }, { a: 38, d: 12, s: 20, op: 0.4 }] },
  respect: { name: 'Respect', cls: 'emotion', kind: 'layout', t: [0.2, 0.4, 0.3], pri: 12, cool: 6, moment: 'A clash ends in a draw, a finisher is blocked, or a rival gets back up after a heavy hit: the fighter acknowledges the other.', sound: 'A low, short two-note nod.', event: 'clash_draw, finisher_blocked, rally of the rival', layout: [{ a: 166, d: 12, s: 30, op: 0.45 }, { a: 14, d: 12, s: 30, op: 0.45 }, { a: 90, d: 10, s: 12, op: 0.4 }] },
  bored: { name: 'Bored', cls: 'emotion', kind: 'layout', t: [0.3, 0.4, 0.3], cool: 8, layout: [{ a: 90, d: 16, s: 18, op: 0.3 }, { a: 100, d: 30, s: 12, op: 0.26 }] },
  hazard: { name: 'Hazard', cls: 'info', kind: 'glyph', glyph: 'bang2', t: [0.05, 0.25, 0.15], pri: 3, cool: 1.0, moment: 'The world is about to hit the fighter: a falling building, a collapsing crater rim, a beam path, rising water. Not a fighter attack (that is danger sense).', sound: 'Two quick low ticks.', event: 'hazard_telegraph (new, World and Encounter)' },
  primed: { name: 'Primed', cls: 'info', kind: 'layout', t: [0.06, 0.34, 0.2], pri: 5, cool: 3, moment: 'Leaving cover with the ambush window open (x1.5 damage for 2.5 s): the fighter can strike hard now. It points forward, where danger sense points back.', sound: 'A soft rising click.', event: 'ambush_ready (Encounter; the rule exists in the prototype)', layout: [{ a: 36, d: 12, s: 14, op: 0.95 }, { a: 36, d: 30, s: 20, op: 0.95 }, { a: 36, d: 52, s: 28, op: 0.95 }] },
};
Object.assign(FLASHES, CAND);
const totalT = f => f.t[0] + f.t[1] + f.t[2];
// The envelope: an eased attack, a hold, and an eased fade. 0 at rest, 1 at the peak.
const env = (f, t) => { const [a, h, d] = f.t; if (t <= 0) return 0; if (t < a) return 1 - (1 - t / a) ** 2; if (t < a + h) return 1; if (t < a + h + d) return 1 - ((t - a - h) / d) ** 2; return 0; };

// triangle with an optional round tip (the Legal fallback for tall pointed shapes)
function tri(base, ux, uy, s, w, round) {
  const nx = -uy, ny = ux;
  if (!round) return [[base[0] + nx * w, base[1] + ny * w], [base[0] + ux * s, base[1] + uy * s], [base[0] - nx * w, base[1] - ny * w]];
  const r = w * 0.95, c = [base[0] + ux * (s - r), base[1] + uy * (s - r)], pts = [[base[0] + nx * w, base[1] + ny * w], [c[0] + nx * r, c[1] + ny * r]];
  for (const ph of [60, 30, 0, -30, -60]) { const p = ph * Math.PI / 180; pts.push([c[0] + (ux * Math.cos(p) + nx * Math.sin(p)) * r, c[1] + (uy * Math.cos(p) + ny * Math.sin(p)) * r]); }
  pts.push([c[0] - nx * r, c[1] - ny * r], [base[0] - nx * w, base[1] - ny * w]);
  return pts;
}
for (const [id, f] of Object.entries(FLASHES)) f.id = id;
// Legal conditions on the tall upward flashes. The Anti-hero's upward flashes are round-tipped (his rage may stay pointed, it sweeps forward).
// The Empress's upward flashes are a wide, low crest behind the head: the angles are flattened, turned back and shortened.
let LEGACY = false;   // draws the shapes as they were before Legal's conditions, for the comparison frames only
const A_ROUND = new Set(['pride', 'triumph', 'surge', 'danger']);
const E_CREST = new Set(['pride', 'triumph', 'surge', 'resolve']);
function crest(it) {
  const a = it.a * Math.PI / 180, x = Math.cos(a), y = Math.sin(a) * 0.4, sq = Math.atan2(y, x) * 180 / Math.PI;
  return { ...it, a: sq + 42, s: it.s * 0.7, d: it.d + 4 };
}
function layoutPolys(fk, f, hc, u, k, round, ground) {
  const out = [], info = f.cls === 'info';
  if (fk === 'A' && A_ROUND.has(f.id) && !LEGACY) round = true;
  for (let it of f.layout) {
    if ((fk === 'E' && E_CREST.has(f.id) || fk === 'A' && f.id === 'surge') && !it.ground && !LEGACY) it = crest(it);
    const a = it.a * Math.PI / 180, ux = Math.cos(a), uy = Math.sin(a), dir = it.inward ? -1 : 1;
    const base = it.ground ? [hc[0] + ux * it.d * u, ground] : [hc[0] + ux * it.d * u, hc[1] + 2 + uy * it.d * u];
    const size = (0.55 + 0.45 * k);
    // Info flashes are solid with a thin keyline (the core fills 84% of the rim). Emotion flashes are a rim and a smaller, lighter core.
    for (const [kk, layer] of [[1, 'rim'], [info ? 0.84 : 0.58, 'core']]) {
      const s = it.s * u * kk * size, w = (fk === 'A' ? 3.8 : fk === 'E' ? 8.5 : 4) * u * (kk === 1 ? 1 : info ? 0.84 : 0.6);
      let pts;
      if (fk === 'P') pts = circ([base[0] + ux * dir * s * 0.5, base[1] + uy * dir * s * 0.5], Math.max(2.5, s * 0.3), 14);
      else if (fk === 'C') { const q = Math.max(3, s * 0.3); pts = [[base[0] - q, base[1] - q], [base[0] + q, base[1] - q], [base[0] + q, base[1] + q], [base[0] - q, base[1] + q]].map(([x, y]) => [Math.round(x / 3) * 3 + ux * dir * s * 0.5, Math.round(y / 3) * 3 + uy * dir * s * 0.5]); }
      else pts = tri(base, ux * dir, uy * dir, s, w, round);
      out.push({ pts, layer, op: it.op * k, info });
    }
  }
  return out;
}
// The "!" and the "?" in each fighter's own shapes: capsule and dot (circles), blade and diamond (blades), wedge and triangle (wedges), squares (steps).
function glyphPolys(fk, kind, cx, cy, u, k, round) {
  const out = [], P = (pts, layer) => out.push({ pts, layer, op: 0.97 * Math.min(1, k * 1.4), info: true });
  const sc = (0.7 + 0.3 * k) * u * 1.7;
  const dotAt = (x, y, r) => (fk === 'P' ? circ([x, y], r * 1.05, 10) : fk === 'C' ? [[x - r, y - r], [x + r, y - r], [x + r, y + r], [x - r, y + r]] : fk === 'A' ? [[x, y - r * 1.2], [x + r * 0.9, y], [x, y + r * 1.2], [x - r * 0.9, y]] : [[x - r * 1.2, y - r * 0.8], [x + r * 1.2, y - r * 0.8], [x, y + r * 1.2]]);
  if (kind === 'bang') {
    for (const [pad, layer] of [[1.1, 'rim'], [0, 'core']]) {
      const g = pad * sc * 0.6;
      let stem;
      if (fk === 'P') stem = band([[cx, cy + 5.4 * sc], [cx, cy + 12.6 * sc]], 3.4 * sc + g * 2).concat([]);
      else if (fk === 'A') stem = [[cx - 2.6 * sc - g, cy + 14 * sc + g], [cx + 2.6 * sc + g, cy + 14 * sc + g], [cx, cy + 4.6 * sc - g]];
      else if (fk === 'E') stem = [[cx - 3.8 * sc - g, cy + 14 * sc + g], [cx + 3.8 * sc + g, cy + 14 * sc + g], [cx, cy + 4.6 * sc - g]];
      else stem = [[cx - 2 * sc - g, cy + 14 * sc + g], [cx + 2 * sc + g, cy + 14 * sc + g], [cx + 2 * sc + g, cy + 5.4 * sc - g], [cx - 2 * sc - g, cy + 5.4 * sc - g]];
      P(stem, layer === 'rim' ? 'rim' : 'core');
      if (fk === 'P') P(circ([cx, cy + 5.4 * sc], 1.7 * sc + g, 10), layer === 'rim' ? 'rim' : 'core'), P(circ([cx, cy + 12.6 * sc], 1.7 * sc + g, 10), layer === 'rim' ? 'rim' : 'core');
      P(dotAt(cx, cy + 1.4 * sc, (fk === 'C' ? 1.6 : 1.9) * sc + g), layer === 'rim' ? 'rim' : 'core');
    }
  } else {
    const path = fk === 'E' ? [[-3.6, 10.6], [-2.4, 14.8], [2.6, 14.8], [3.6, 10.8], [0, 7.4], [0, 5]] : [[-3.6, 10.6], [-3.4, 13.6], [-0.8, 15.4], [2.4, 14.2], [3.2, 11.6], [1.6, 9.2], [0, 7.2], [0, 5]];
    for (const [pad, layer] of [[1.1, 'rim'], [0, 'core']]) {
      const g = pad * sc * 0.6, pts = path.map(([x, y]) => [cx + x * sc, cy + y * sc]);
      if (fk === 'P') for (const p of pts) P(circ(p, 1.8 * sc + g, 10), layer);
      else if (fk === 'C') for (const p of pts) { const q = 1.7 * sc + g, gx = Math.round(p[0] / 3) * 3, gy = Math.round(p[1] / 3) * 3; P([[gx - q, gy - q], [gx + q, gy - q], [gx + q, gy + q], [gx - q, gy + q]], layer); }
      else P(band(pts, t => (fk === 'A' ? (1.4 + 2.6 * Math.sin(Math.PI * t)) : 3.4) * sc + g * 2), layer);
      P(dotAt(cx, cy + 1.4 * sc, (fk === 'C' ? 1.6 : 1.9) * sc + g), layer);
    }
  }
  return out;
}
function flashPolys(fk, id, hc, u, { k = 1, round = false, ground = 0 } = {}) {
  const f = FLASHES[id]; if (!f || k <= 0) return [];
  if (f.kind === 'glyph' && f.glyph === 'bang2') return [...glyphPolys(fk, 'bang', hc[0] - 5.5 * u, hc[1] + 7 * u, u, k, round), ...glyphPolys(fk, 'bang', hc[0] + 9 * u, hc[1] + 7 * u, u, k, round)];
  if (f.kind === 'glyph') return glyphPolys(fk, f.glyph, hc[0] + 2 * u, hc[1] + 7 * u, u, k, round);
  return layoutPolys(fk, f, hc, u, k, round, ground);
}

// ---------------------------------------------------------------------------------------------------------- styling a fighter
const civC = {
  ...CIVILIAN,
  cfg: pal => ({ ...CIVILIAN.cfg(pal), torso: '#8a93a3', sleeve: '#8a93a3', torsoShade: '#00000030' }),
  blankHead: pal => ({ poly: [[-4.6, 1], [-5.4, 8], [-4.4, 14], [0, 16.4], [4.6, 14], [5.6, 8], [4, 1.5]], fill: pal.skin.mid, shadow: pal.skin.shadow, shade: [[-4.6, 1], [-5.4, 8], [-4.4, 14], [0, 16.4], [1, 16], [-2.4, 12], [-2.4, 6], [-1, 0.6]] }),
};
// Info flashes: a pale core inside a thin keyline in the lane's dark step. No yellow or red-orange, and no thick black outline. The Cyborg's are neutral steel.
const INFO = { P: { core: '#e6f7f3', line: '#2a7568' }, A: { core: '#eee6fc', line: '#5b479a' }, E: { core: '#eaf3d4', line: '#5d6c2a' }, C: { core: '#e3e7ee', line: '#4a4f57' } };
// Emotion flash colours. The Protagonist's teal accent sits on his teal hair, so his rim steps up to the light step and his core to a near-white,
// which keeps the flash readable where it overlaps the hair (Rendering, 2026-09-29). The others use mid for the rim and light for the core.
const EMO = { P: { rim: p => p.accent.light, core: () => '#e6f7f3' }, A: { rim: p => p.accent.mid, core: p => p.accent.light }, E: { rim: p => p.accent.mid, core: p => p.accent.light }, C: { rim: p => p.accent.mid, core: p => p.accent.light } };
// which sigil pose goes with each state
const SIGIL_STATE = { pride: 'pride', danger: 'pride', found: 'triumph', searching: 'taunt', fear: 'hurt', resolve: 'pride', surge: 'transform', clash: 'rage', neutral: 'neutral', taunt: 'taunt', hurt: 'hurt', brink: 'brink', rage: 'rage', triumph: 'triumph' };
function styled(fk) {
  const base = fk === 'E' ? { ...FIGHTERS.E, back: empressBack } : FIGHTERS[fk], mask = MASK[fk];
  const c = { ...base };
  if (fk === 'P') c.armGear = (ctx, sk) => pWraps(ctx, sk);
  c.blankHead = (p, st) => {
    const yaw = st.yaw ?? 0, mh = maskHead(fk, base.blankHead(p), p, mask, yaw);
    return { ...mh, marks: [...mh.marks, ...sigilMarks(fk, p, SIGIL_STATE[st.state ?? 'neutral'] ?? 'neutral', mask, yaw)] };
  };
  // The Protagonist's hair sits back off the forehead so the dome and its ring show (the fringe line moves up about 2 units).
  if (fk === 'P') c.hair = (ctx, sk) => {
    const H = a => a.map(([x, y]) => sk.Hd(x, y));
    return ctx.poly(H([[5.8, 16.2], [4.4, 18.3], [0.6, 19.8], [-4.4, 18.4], [-8.4, 14.8], [-12.4, 11.6], [-14, 8.4], [-12, 6.4], [-8.4, 8.2], [-5.8, 6.8], [-5.8, 12.6], [-3.4, 15.6], [1, 16.4]]), ctx.pal.hair.mid);
  };
  const prevBack = base.back;
  c.back = (ctx, sk, st, cfg) => {
    let o = '';
    const id = st.state === 'clash' ? 'rage' : st.state;
    if (!ctx.flat && !st.noFlash && FLASHES[id] && (!FLASHES[id].cut || st.showCut)) {
      const hc = sk.Hd(3, 9), u = sk.b.hs * 0.95, pal = ctx.pal;
      for (const a of flashPolys(fk, id, [hc.x, hc.y], u, { k: st.k ?? 1, round: st.round, ground: 0 })) {
        const info = a.info;
        const ic = INFO[fk];
        const ec = EMO[fk], col = info ? (a.layer === 'rim' ? ic.line : ic.core) : (a.layer === 'rim' ? ec.rim(pal) : ec.core(pal));
        const op = info ? a.op : a.op * (a.layer === 'rim' ? 0.85 : 1);
        const pts = a.pts.map(p => (Array.isArray(p) ? `${p[0].toFixed(2)},${p[1].toFixed(2)}` : `${p.x.toFixed(2)},${p.y.toFixed(2)}`)).join(' ');
        o += `<polygon points="${pts}" fill="${col}" opacity="${op.toFixed(2)}"/>`;
      }
    }
    return o + prevBack(ctx, sk, st, cfg);
  };
  const prevAfter = base.after;
  c.after = (ctx, sk, st, cfg) => {
    let o = prevAfter ? prevAfter(ctx, sk, st, cfg) : ''; if (ctx.flat) return o;
    const { pal: p } = ctx, n = st.forms ?? 6;
    for (let i = 0; i < Math.min(n, 6); i++) {
      const t = 0.18 + i * 0.13, a = sk.nearArm;
      const p0 = V(a.E.x + (a.W.x - a.E.x) * t, a.E.y + (a.W.y - a.E.y) * t);
      o += `<circle cx="${p0.x.toFixed(2)}" cy="${p0.y.toFixed(2)}" r="0.9" fill="${p.accent.mid}"/>`;
    }
    return o;
  };
  return c;
}

const DEFS = `<defs>
<pattern id="mail" width="3.2" height="3.2" patternUnits="userSpaceOnUse"><circle cx="1.6" cy="1.6" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/><circle cx="0" cy="0" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/><circle cx="3.2" cy="3.2" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/></pattern>
</defs>`;

// Poses for the states. Neutral is the base pose. Pride for the Anti-hero is the upright front; the others lean back and lift the chin.
function poseFor(fk, s) {
  const b = FIGHTERS[fk].poses.base;
  if (s === 'neutral') return b;
  if (s === 'pride') return fk === 'A' ? { ...POSES.proud } : { ...b, lean: b.lean - 8, head: b.head - 10 };
  if (s === 'taunt') return { ...b, lean: b.lean - 8, head: b.head - 16, nearArm: [58, 138], farArm: [-8, -64], handNear: 'open' };
  if (s === 'hurt') return { ...POSES.humbled, nearLeg: [26, -6], farLeg: [-12, -22] };
  if (s === 'brink') return { lean: 34, head: 26, nearArm: [20, -100], farArm: [14, 10], nearLeg: [40, -30], farLeg: [-10, -50], handNear: 'open', handFar: 'fist' };
  if (s === 'rage') return { ...POSES.dropped };
  if (s === 'clash') return { lean: 22, head: 6, nearArm: [84, 90], farArm: [-40, -90], nearLeg: [42, 14], farLeg: [-36, -12], handNear: 'fist', handFar: 'fist' };
  if (s === 'surge') return { lean: -6, head: -20, nearArm: [98, 122], farArm: [-98, -122], nearLeg: [20, 6], farLeg: [-20, -6], handNear: 'open', handFar: 'open' };
  if (s === 'winded') return { ...b, lean: b.lean + 16, head: b.head + 10, nearArm: [30, 50], farArm: [-20, -40], handNear: 'open' };
  if (s === 'smug') return { ...b, lean: b.lean - 6, head: b.head - 10, nearArm: [20, 130], farArm: [-10, -60], handNear: 'fist' };
  if (s === 'respect') return { ...b, lean: b.lean + 14, head: b.head + 8, nearArm: [10, 20], farArm: [-6, -12], handNear: 'fist' };
  if (s === 'bored') return { ...b, lean: b.lean - 2, head: b.head + 4, nearArm: [16, 30], farArm: [-6, -8], handNear: 'open' };
  if (s === 'hazard') return { ...b, lean: b.lean + 2, head: b.head - 8, nearArm: [50, 118], farArm: [-6, -70], handNear: 'open', handFar: 'fist' };
  if (s === 'primed') return { ...b, lean: b.lean + 10, head: b.head - 6, nearArm: [60, 110], farArm: [-24, -60], handNear: 'fist' };
  if (s === 'danger') return { ...b, lean: b.lean + 4, head: b.head - 6, nearArm: [50, 118], farArm: [-6, -70], handNear: 'open', handFar: 'fist' };
  if (s === 'found') return { ...b, lean: b.lean - 4, head: b.head - 12, nearArm: [84, 88], handNear: 'open' };
  if (s === 'searching') return { ...b, lean: b.lean - 2, head: b.head + 6, nearArm: [40, 142], farArm: [-8, -30], handNear: 'open' };
  if (s === 'fear') return { ...b, lean: b.lean - 14, head: b.head - 4, nearArm: [56, 146], farArm: [-30, -110], handNear: 'open', handFar: 'open' };
  if (s === 'resolve') return { ...b, lean: b.lean + 12, head: b.head - 8, nearArm: [34, 72], farArm: [-30, -60], handNear: 'fist' };
  return { lean: -8, head: -22, nearArm: [152, 172], farArm: [-150, -170], nearLeg: [18, 4], farLeg: [-16, -4], handNear: 'fist', handFar: 'fist' }; // triumph
}
const stateOf = (state, yaw, k, round, extra = {}) => ({ yaw, state, k, round, expression: 'neutral', open: state === 'rage' || state === 'clash' ? 1 : state === 'hurt' || state === 'brink' ? 0.4 : 0, forms: 6, hairLoose: ['rage', 'hurt', 'brink', 'clash', 'fear'].includes(state), ...extra });

// state: a flash id, or neutral (at rest: no flash). k: 0 to 1 envelope of the flash (1 is the peak).
function fig(fk, px, x, ground, { flat = false, state = 'neutral', civ = false, flip = false, yaw = YAW, noFlash = false, wear = 0, k = 1, round = false, legacy = false, showCut = false } = {}) {
  LEGACY = legacy;
  const s = px / 100, pal = civ ? NEUTRAL : PAL[fk];
  const concept = civ ? civC : styled(fk);
  const ctx = makeCtx({ flat, pal, swMul: px < 9 ? 0 : px < 28 ? 0.6 : px < 80 ? 1 : 1.3, faceless: true });
  const p = civ ? CIV_POSES[0] : poseFor(fk, state);
  const st = civ ? { expression: 'neutral', yaw } : { ...stateOf(state, yaw, k, round), sway: FIGHTERS[fk].sway ?? 6, wear, noFlash, showCut };
  const { svg } = figure(ctx, concept, p, st, { yaw });
  LEGACY = false;
  const fl = flip ? ` transform="translate(${F(x)} 0) scale(-1 1) translate(${F(-x)} 0)"` : '';
  return `<g${fl}><g transform="translate(${F(x)} ${F(ground)}) scale(${F(s)} ${F(-s)})">${svg}</g></g>`;
}
function closeup(fk, state, x, y, size, px = 118) {
  const s = px / 100, pal = PAL[fk], concept = styled(fk);
  const ctx = makeCtx({ flat: false, pal, swMul: 1, faceless: true });
  const p = poseFor(fk, state);
  const st = { ...stateOf(state, YAW, 1, false), sway: FIGHTERS[fk].sway ?? 6, wear: 0 };
  const { svg, sk } = figure(ctx, concept, p, st, { yaw: YAW });
  const h = sk.Hd(3.2, 9.4);
  return `<svg x="${F(x)}" y="${F(y)}" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" overflow="hidden">${rect(0, 0, size, size, '#f3f0f8')}<g transform="translate(${F(size / 2 - h.x * s)} ${F(size / 2 + h.y * s)}) scale(${F(s)} ${F(-s)})">${svg}</g></svg>` + rect(x, y, size, size, 'none', 'stroke="#1b1428" stroke-opacity="0.35"');
}

// HUD crown, drawn as UI's spec describes it (thin arcs and a faint ring around the whole body), for the comparison diagram only.
function hudCrown(cx, cy, R, brink = false) {
  const arcs = [[-20, 60], [70, 150], [160, 240], [250, 330]].map(([a0, a1]) => {
    const pts = []; for (let a = a0; a <= a1; a += 6) pts.push(`${(cx + Math.cos(a * Math.PI / 180) * R).toFixed(1)},${(cy - Math.sin(a * Math.PI / 180) * R).toFixed(1)}`);
    return `<polyline points="${pts.join(' ')}" fill="none" stroke="#5b5866" stroke-width="2" stroke-linecap="round"/>`;
  }).join('');
  const inner = `<circle cx="${cx}" cy="${cy}" r="${(R * 0.5).toFixed(1)}" fill="none" stroke="#5b5866" stroke-width="1.6" opacity="0.7"/>`;
  const ring = brink ? `<circle cx="${cx}" cy="${cy}" r="${(R * 1.1).toFixed(1)}" fill="none" stroke="#5b5866" stroke-width="1.2" stroke-dasharray="5 4" opacity="0.5"/>` : '';
  return arcs + inner + ring;
}

// The greybox scenes: the repo's own renders as backdrops, cropped clear of the HUD and the placeholder fighters.
const IMG = '../../../docs/rendering/img/';
const SCENES = {
  village: { href: IMG + 'civilians-after.png', sx: 250, sy: 130, sw: 760, sh: 560 },
  craters: { href: IMG + 'craters-after.png', sx: 380, sy: 130, sw: 520, sh: 560 },
  high: { href: IMG + 'world-high-after.png', sx: 0, sy: 300, sw: 1280, sh: 390 },
};
let clipN = 0;
function scene(key, x, y, w, h, content) {
  const sc = SCENES[key], k = Math.max(w / sc.sw, h / sc.sh), id = `sc${clipN++}`;
  const iw = 1280 * k, ih = 720 * k, ix = -sc.sx * k - (sc.sw * k - w) / 2, iy = -sc.sy * k - (sc.sh * k - h) / 2;
  return `<clipPath id="${id}"><rect x="0" y="0" width="${w}" height="${h}"/></clipPath><g transform="translate(${x} ${y})"><g clip-path="url(#${id})"><image href="${sc.href}" x="${F(ix)}" y="${F(iy)}" width="${F(iw)}" height="${F(ih)}"/>${content}</g></g>` + rect(x, y, w, h, 'none', 'stroke="#1b1428" stroke-opacity="0.4"');
}


// ---------------------------------------------------------------------------------------------------------- sheet 1: the style
function styleSheet() {
  const W = 1800, H = 1775;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'Marked plus Flashes: the style', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'The sigil carries identity and small expression. A brief head flash conveys what the mask cannot. At rest there is nothing. Three-quarter, calm colour, mask tone per fighter.', { size: 15, fill: '#cfc6e6' });
  b += text(W - 30, 80, 'Working labels, placeholder looks. Status: proposal, pending Legal review.', { size: 12, fill: '#cfc6e6', anchor: 'end' });
  b += rect(24, 124, W - 48, 470, '#e8e5ee', 'stroke="#1b1428" stroke-opacity="0.2"');
  const xs = { P: 250, A: 700, E: 1180, C: 1600 };
  for (const fk of ORDER) {
    b += fig(fk, 300, xs[fk], 540, { state: 'neutral' });
    b += text(xs[fk], 566, `${NAMES[fk]}: ${MASK[fk].tone} mask`, { size: 13, weight: 600, anchor: 'middle', op: 0.85 });
  }
  b += text(40, 150, 'The four fighters at rest, showcase size, three-quarter. No flash: the fight area is clean', { size: 12, weight: 700, op: 0.85 });
  b += text(24, 630, 'Mask tone per fighter (approved by Orb)', { size: 18, weight: 700 });
  ORDER.forEach((fk, i) => {
    const x0 = 24 + i * 444;
    b += rect(x0, 640, 432, 116, MASK[fk].fill, 'stroke="#1b1428" stroke-opacity="0.25"');
    const tc = MASK[fk].tone === 'dark' ? '#f4f0fa' : '#1b1428';
    b += text(x0 + 14, 664, `${NAMES[fk]}: ${MASK[fk].tone}`, { size: 16, weight: 700, fill: tc });
    b += paras(x0 + 14, 686, MASK[fk].why, 62, 12.5, 16, { fill: tc });
  });
  b += text(24, 790, 'Gameplay size: 40 px and 12 px with a civilian, a "found" flash and a rage flash at their peak', { size: 13, weight: 700 });
  ORDER.forEach((fk, i) => {
    const x0 = 24 + i * 444;
    [[40, 'found', 0], [40, 'rage', 1], [12, 'found', 2], [12, 'rage', 3]].forEach(([px, st, j]) => {
      const cx = x0 + j * 108, cy = 802;
      b += rect(cx, cy, 100, 100, '#cfe6f0') + rect(cx, cy + 50, 100, 50, '#2f86ad');
      b += fig(fk, px, cx + 66, cy + 88, { state: st }) + fig(fk, px, cx + 20, cy + 88, { civ: true });
    });
    b += text(x0, 922, NAMES[fk], { size: 12, weight: 600, op: 0.85 });
  });
  b += text(24, 960, 'Expression: neutral, taunt, hurt, rage, triumph (the sigil, the flash at its peak, and a head close-up)', { size: 13, weight: 700 });
  const S5 = ['neutral', 'taunt', 'hurt', 'rage', 'triumph'];
  ORDER.forEach((fk, r) => {
    const y0 = 972 + r * 186;
    b += text(24, y0 + 14, NAMES[fk], { size: 12, weight: 700 });
    S5.forEach((e, j) => {
      const x0 = 24 + j * 356;
      b += rect(x0, y0 + 20, 348, 158, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"');
      b += fig(fk, 120, x0 + (fk === 'E' ? 140 : 100), y0 + 170, { state: e });
      b += closeup(fk, e, x0 + 216, y0 + 26, 126, 150);
      b += text(x0 + 8, y0 + 38, e, { size: 12, op: 0.75 });
    });
  });
  b += text(30, H - 22, 'Kept: the value rule, the two-tone edge, the far beacon, calm harmonious colour, three-quarter staging, and no borrowed look (designed masks, never grey and round, no cross-mark or dot eyes).', { size: 12, op: 0.8 });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

// ---------------------------------------------------------------------------------------------------------- sheet 2: the flash vocabulary
const fmtT = f => `${f.t[0].toFixed(2)} + ${f.t[1].toFixed(2)} + ${f.t[2].toFixed(2)} = ${totalT(f).toFixed(2)} s`;
function vocabSheet() {
  const W = 1800, cw = 134;
  let b = rect(0, 0, W, 2000, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'The head flashes: thirteen, each tied to a game moment', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'Brief pops at the head, in each fighter\'s own shapes. Each cell is the flash at its peak. At rest there is nothing.', { size: 15, fill: '#cfc6e6' });
  b += text(24, 136, 'Every flash in each shape family: circles (Protagonist), blades (Anti-hero), wedges (Empress), steps (Cyborg)', { size: 16, weight: 700 });
  FLASH_ORDER.forEach((id, j) => {
    const f = FLASHES[id], x0 = 24 + j * cw;
    b += text(x0 + cw / 2 - 4, 162, f.name, { size: 13, weight: 700, anchor: 'middle' });
    b += text(x0 + cw / 2 - 4, 177, `${f.cls === 'info' ? 'info: solid' : 'emotion: soft'}`, { size: 10.5, anchor: 'middle', op: 0.75 });
  });
  ORDER.forEach((fk, r) => {
    const y0 = 184 + r * 214;
    FLASH_ORDER.forEach((id, j) => {
      const x0 = 24 + j * cw;
      b += rect(x0, y0, cw - 4, 208, FLASHES[id].cls === 'info' ? '#e3eef5' : '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"');
      b += fig(fk, 74, x0 + (fk === 'E' ? 98 : 70), y0 + 200, { state: id });
    });
    b += text(30, y0 + 16, NAMES[fk], { size: 11, weight: 700, op: 0.7 });
  });
  // table
  let y = 184 + 4 * 214 + 30;
  b += text(24, y, 'What each flash is for', { size: 18, weight: 700 });
  y += 24;
  const cols = [['Flash', 24], ['Class', 150], ['Moment and sim event', 232], ['Attack + hold + fade', 800], ['Priority', 960], ['Sound pairing (with Audio)', 1032]];
  cols.forEach(([h, x]) => { b += text(x, y, h, { size: 12, weight: 700 }); });
  y += 8;
  FLASH_ORDER.forEach(id => {
    const f = FLASHES[id], m = wrap(`${f.moment} (Event: ${f.event}.)`, 92), s = wrap(f.sound, 80), n = Math.max(m.length, s.length, 1);
    b += `<line x1="24" y1="${y}" x2="1776" y2="${y}" stroke="#1b1428" stroke-opacity="0.15"/>`;
    b += text(24, y + 16, f.name, { size: 12.5, weight: 700 }) + text(150, y + 16, f.cls, { size: 12 }) + text(800, y + 16, fmtT(f), { size: 12 }) + text(960, y + 16, String(f.pri), { size: 12 });
    m.forEach((l, i) => { b += text(232, y + 16 + i * 15, l, { size: 12 }); });
    s.forEach((l, i) => { b += text(1032, y + 16 + i * 15, l, { size: 12 }); });
    y += 10 + n * 15 + 8;
  });
  y += 20;
  b += paras(24, y, 'Shape rules: circles use round-ended bars, dots and arcs; blades use tapered blades and diamonds; wedges use wedge triangles; steps use squares snapped to a grid. Info flashes (danger, found, searching) are solid, at full opacity, with a dark keyline in the lane colour. Emotion flashes are translucent, with a rim and a lighter core. Priority 1 wins.', 220, 12, 16);
  const H = y + 70;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b.replace('<rect x="0.00" y="0.00" width="1800.00" height="2000.00"', `<rect x="0.00" y="0.00" width="1800.00" height="${H}.00"`)}</svg>`;
}

// ---------------------------------------------------------------------------------------------------------- sheet 4: timing, priority and the crown
function rulesSheet() {
  const W = 1800, H = 1900;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'The flashes: timing, priority, and the HUD crown', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'How long they last, which wins when several fire, how they stay clear of the crown, and the Legal fallback.', { size: 15, fill: '#cfc6e6' });
  // timelines
  b += text(24, 136, 'A flash in time (frames at 0 s to the end; each is the envelope at that moment)', { size: 18, weight: 700 });
  const tl = [['P', 'found', 'Protagonist: found'], ['A', 'danger', 'Anti-hero: danger sense'], ['E', 'rage', 'Empress: rage'], ['C', 'fear', 'Cyborg: fear']];
  tl.forEach(([fk, id, cap], r) => {
    const f = FLASHES[id], y0 = 148 + r * 176, T = totalT(f), fr = [0.03, 0.12, 0.3, 0.55, 0.8, 0.97];
    b += text(24, y0 + 14, `${cap}  (${fmtT(f)})`, { size: 12.5, weight: 700 });
    fr.forEach((q, j) => {
      const t = q * T, k = env(f, t), x0 = 24 + j * 292;
      b += rect(x0, y0 + 20, 284, 150, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"');
      b += fig(fk, 96, x0 + (fk === 'E' ? 170 : 130), y0 + 164, { state: id, k: Math.max(0.001, k) });
      b += text(x0 + 8, y0 + 36, `${t.toFixed(2)} s  (${Math.round(k * 100)}%)`, { size: 11, op: 0.8 });
    });
  });
  // priority and arbitration
  const ya = 148 + 4 * 176 + 20;
  b += text(24, ya, 'Priority and arbitration (one channel per fighter)', { size: 18, weight: 700 });
  const pr = FLASH_ORDER.slice().sort((a, c) => FLASHES[a].pri - FLASHES[c].pri).map(id => `${FLASHES[id].pri} ${FLASHES[id].name}`).join('   >   ');
  b += paras(24, ya + 24, `Priority, highest first: ${pr}.`, 230, 12.5, 17);
  const arb = [
    'One flash at a time per fighter, and never a flash and a crown together. The crown owns wear (a stage change, brink, Rally, facade crack, boil-over). A flash owns emotion and sense. If a wear event arrives while a flash is up, the flash fades out in 0.1 s and the crown takes the fighter. If a flash is due while the crown is up, it waits up to 0.25 s and is then dropped.',
    'A higher priority preempts a lower one (the lower fades in 0.1 s). The same priority extends the hold and never replays the attack. A lower priority waits up to 0.25 s and is then dropped. Each flash has its own cooldown per fighter (in the table), so the same beat never chatters.',
    'A flash is never up while a fighter is hidden. During a transformation cinematic the surge owns the fighter and the crown stays down. No flash covers the mask, the sigil or the chest: they are drawn behind the head and above it.',
    'Info flashes (danger, found, searching) are never dropped for an emotion flash. They can only be preempted by the surge. Suggested UI change: the crown pops only for a stage change, brink, Rally, facade crack, boil-over, and not for every hit, so the hurt flash and the crown do not compete for the same moment.',
  ];
  arb.forEach((t, i) => { b += paras(24 + (i % 2) * 888, ya + 62 + Math.floor(i / 2) * 100, t, 104, 12, 16); });
  // flash vs crown
  const yc = ya + 62 + 210;
  b += text(24, yc, 'A flash against the HUD crown, on the same figure', { size: 18, weight: 700 });
  const demo = [['Flash only (in the scene): rage', 'rage', false, false], ['HUD crown only (UI): a stage change', 'neutral', true, false], ['Never both: the crown wins a wear event', 'neutral', true, false], ['HUD brink ring with a brink flash', 'brink', false, true]];
  demo.forEach(([cap, st, crown, brink], i) => {
    const x0 = 24 + i * 444;
    b += rect(x0, yc + 14, 432, 250, '#cfe0ea', 'stroke="#1b1428" stroke-opacity="0.2"');
    b += fig('P', 150, x0 + 210, yc + 254, { state: st });
    if (crown) b += hudCrown(x0 + 216, yc + 254 - 88, 78);
    if (brink) b += `<circle cx="${x0 + 216}" cy="${yc + 254 - 60}" r="${(78 * 1.1).toFixed(1)}" fill="none" stroke="#5b5866" stroke-width="1.2" stroke-dasharray="5 4" opacity="0.5"/>`;
    b += text(x0 + 10, yc + 32, cap, { size: 12, weight: 600 });
  });
  b += text(24, yc + 290, 'The crown is drawn as UI\'s spec describes it (docs/ui/hud-spec.md): thin arcs and an inner ring, a faint dashed brink ring. A flash never draws a ring or an outline arc, and the crown never draws a filled shape.', { size: 12, op: 0.85 });
  // Legal fallback
  const yl = yc + 320;
  b += text(24, yl, "Legal conditions applied: the Anti-hero's upward flashes are round-tipped, and the Empress's are a wide, low crest (before, then now)", { size: 18, weight: 700 });
  [['A', 'pride'], ['A', 'triumph'], ['E', 'pride'], ['E', 'triumph']].forEach(([fk, id], i) => {
    const x0 = 24 + i * 444;
    b += rect(x0, yl + 14, 432, 200, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"');
    b += fig(fk, 96, x0 + 90, yl + 208, { state: id, legacy: true }) + fig(fk, 96, x0 + 300, yl + 208, { state: id });
    b += text(x0 + 8, yl + 32, `${NAMES[fk]} ${id}: before (tall), now`, { size: 11.5, op: 0.8 });
  });
  b += paras(24, yl + 240, "Legal found a tall pointed flash too close to an upswept spiky aura. So the Anti-hero's pride, triumph, surge and danger sense are round-tipped, and the Empress's pride, triumph, surge and resolve are flattened into a wide, low crest behind the head, shorter than before. The shapes stay in their families. Circles and steps are unchanged. The Anti-hero's rage stays pointed, because it sweeps forward, not up.", 230, 12.5, 17);
  b += text(24, yl + 285, 'Legal notes on the set', { size: 16, weight: 700 });
  b += paras(24, yl + 306, 'Exclamation and question marks are general comics staples and are drawn here in each fighter\'s own shapes with a keyline, not as a font glyph. Danger sense is short straight bursts in the fighter\'s family, not a wavy squiggle. The sounds are described in words and must be original: no stealth-game alert sting, no spider-sense chirp. No red, red-orange or gold flash for the Protagonist or the Anti-hero. The Protagonist\'s heat stays steam and veins on the body.', 230, 12.5, 17);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

// ---------------------------------------------------------------------------------------------------------- sheet 3: staging
function stagingSheet() {
  const W = 1800, H = 1730;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'Marked plus Flashes: staged in the greybox scene', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'Three-quarter cheat-out, front to camera, mirrored on side-swap, downstage commanding. Each flash is drawn at its peak: 1 s later the same frame is clean.', { size: 15, fill: '#cfc6e6' });
  const f = (fk, px, x, y, o = {}) => fig(fk, px, x, y, o);
  const rows = [
    { title: '1. Pre-fight face-off', note: 'The Protagonist and the Cyborg are downstage (bigger, nearer, commanding), the Anti-hero and the Empress upstage, all turned three-quarter to the middle. Four flashes at their peak: the Protagonist spots the rival (found), the Anti-hero stands tall (pride), the Empress taunts, the Cyborg is at rest. A second later everything is clean again.', scene: 'village', x: 24, y: 124, w: 880, h: 560,
      draw: () => f('A', 78, 250, 372, { state: 'pride' }) + f('E', 82, 640, 350, { state: 'taunt', flip: true }) + f('P', 122, 150, 520, { state: 'found' }) + f('C', 124, 770, 530, { state: 'neutral', flip: true }) },
    { title: '2. Mid-exchange clash', note: 'The Protagonist and the Anti-hero meet in the centre, both in rage, the flares sweeping forward and overlapping at the contact. The Empress watches from upstage with a danger-sense flash (something is coming), and the Cyborg searches. Nobody shows their back.', scene: 'craters', x: 916, y: 124, w: 860, h: 560,
      draw: () => f('P', 128, 360, 510, { state: 'clash' }) + f('A', 122, 540, 512, { state: 'clash', flip: true }) + f('E', 74, 130, 380, { state: 'danger' }) + f('C', 74, 770, 384, { state: 'searching', flip: true }) },
    { title: '3. Transformation (a respected cinematic)', note: 'The Anti-hero surges alone, centred and downstage: the one flash that lasts, held for the cinematic and then faded. A wide crest of round-tipped blades and ground shards spread from the head and shoulders and the sigil is fully lit. The Protagonist watches with fear, the others stand at rest.', scene: 'high', x: 24, y: 780, w: 880, h: 560,
      draw: () => f('A', 178, 450, 540, { state: 'surge' }) + f('P', 84, 130, 470, { state: 'fear' }) + f('E', 84, 760, 470, { state: 'neutral', flip: true }) + f('C', 84, 250, 420, { state: 'neutral' }) },
    { title: '4. Hurt and brink', note: 'The Protagonist has just entered the brink: folded, sigil dim and cracked, a few guttering fragments. UI\'s thin dashed brink ring is drawn as UI specifies, so the two are visibly different (in play the crown would own this moment and the flash would wait). The Anti-hero stands over him in pride, the Empress triumphs, the Cyborg is at rest.', scene: 'village', x: 916, y: 780, w: 860, h: 560,
      draw: () => f('P', 130, 340, 530, { state: 'brink' }) + `<g><circle cx="342" cy="466" r="62" fill="none" stroke="#5b5866" stroke-width="1.4" stroke-dasharray="6 5" opacity="0.7"/></g>` + f('A', 118, 560, 524, { state: 'pride', flip: true }) + f('E', 76, 720, 410, { state: 'triumph', flip: true }) + f('C', 76, 120, 400, { state: 'neutral' }) },
  ];
  rows.forEach(r => {
    b += scene(r.scene, r.x, r.y, r.w, r.h, r.draw());
    b += text(r.x + 12, r.y + 26, r.title, { size: 18, weight: 700, fill: '#f4f0fa' }).replace('<text', `<text stroke="#1b1428" stroke-width="3" paint-order="stroke"`);
    b += paras(r.x, r.y + r.h + 22, r.note, 132, 12.5, 16, { op: 0.92 });
  });
  const y = 1420;
  b += text(24, y, 'Blocking rules used on this sheet', { size: 18, weight: 700 });
  const notes = [
    ['Cheat out', 'Torso, hips and head turn about 32 degrees toward the camera. The near arm crosses the chest and the far arm sits beyond it, so the chest design and the mask face show.'],
    ['Mirror on side-swap', 'A fighter facing left is the mirror image of the same figure, so the front and the sigil face the camera and the back is never shown. The sigil is on the face plane, so it reads either way.'],
    ['Downstage', 'The fighter nearer the camera is larger and lower in frame, and reads as commanding. In the face-off the leads are downstage, and the sneering pair is upstage.'],
    ['Flashes and blocking', 'A flash sits at and above the head, behind it, so it never hides the mask, the sigil or the chest. Rage sweeps forward, away from the camera-facing side, so contact points stay clear.'],
    ['What is not staged here', 'Camera, the letterbox, the HUD and the crown pops (only the brink ring is drawn, to show the difference). Rendering owns the hybrid projection.'],
  ];
  notes.forEach(([h, t], i) => { const col = i % 3, row = Math.floor(i / 3), x = 24 + col * 592, yy = y + 30 + row * 110; b += text(x, yy, h, { size: 14, weight: 700 }) + paras(x, yy + 18, t, 92, 11.5, 15); });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

// ---------------------------------------------------------------------------------------------------------- sheet 5: the checks Legal asked Art to run
// Legal cannot view SVGs (docs/legal/q3-screen.md, "Marked plus Aura"), so these are run here: the masks in full colour, in three flat
// colours and as silhouettes; each sigil beside the generic patterns to avoid; the flashes beside the two patterns to avoid.
// The "avoid" drawings are generic geometry only (a slashed ring, a target, a double chevron, a line grid, an X, radiating short lines,
// a thick-outlined bang). They are not copies of any logo or graphic.
const GREY = '#6f6b7c';
function closeup2(fk, x, y, size, { yaw = YAW, mode = 'full', px = 620, state = 'neutral' } = {}) {
  const s = px / 100, pal = PAL[fk], concept = styled(fk);
  const ctx = makeCtx({ flat: mode === 'sil', pal, swMul: mode === 'flat3' ? 0 : 1, faceless: true });
  const st = { ...stateOf(state, yaw, 1, false), sway: FIGHTERS[fk].sway ?? 6, wear: 0, noFlash: true };
  const { svg, sk } = figure(ctx, concept, poseFor(fk, state), st, { yaw });
  const h = sk.Hd(3.2, 9.4);
  let body = svg;
  if (mode === 'flat3') {
    const acc = new Set([...Object.values(pal.accent), ...(fk === 'P' ? Object.values(pal.hair) : [])].map(c => c.toLowerCase()));
    const dark = '#221c33', light = '#efece4', sig = pal.accent.mid;
    body = body.replace(/<[a-z]+ [^>]*?opacity="0\.[0-4][0-9]*"[^>]*?\/>/g, '')
      .replace(/ stroke="[^"]*"/g, '').replace(/ stroke-[a-z]+="[^"]*"/g, '').replace(/ vector-effect="[^"]*"/g, '').replace(/ opacity="[^"]*"/g, '')
      .replace(/fill="(#[0-9a-fA-F]{6})"/g, (m, c) => {
        if (acc.has(c.toLowerCase())) return `fill="${sig}"`;
        const r = parseInt(c.slice(1, 3), 16), g = parseInt(c.slice(3, 5), 16), b = parseInt(c.slice(5, 7), 16);
        return `fill="${0.299 * r + 0.587 * g + 0.114 * b > 140 ? light : dark}"`;
      });
  }
  const bg = mode === 'full' ? '#f3f0f8' : mode === 'flat3' ? '#a9a6b3' : '#f3f0f8';
  return `<svg x="${F(x)}" y="${F(y)}" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" overflow="hidden">${rect(0, 0, size, size, bg)}<g transform="translate(${F(size / 2 - h.x * s)} ${F(size / 2 + h.y * s)}) scale(${F(s)} ${F(-s)})">${body}</g></svg>` + rect(x, y, size, size, 'none', 'stroke="#1b1428" stroke-opacity="0.35"');
}
// a sigil on a swatch of its own mask, alone, at a scale
function sigilTile(fk, x, y, size, state, sc) {
  const c = SIGPOS[fk], mask = MASK[fk], polys = sigilMarks(fk, PAL[fk], state, mask, 0);
  const pts = p => p.map(([a, b]) => `${a.toFixed(2)},${b.toFixed(2)}`).join(' ');
  const inner = polys.map(q => `<polygon points="${pts(q.poly)}" fill="${q.fill}" opacity="${q.op ?? 1}"/>`).join('');
  return rect(x, y, size, size, mask.fill, 'stroke="#1b1428" stroke-opacity="0.35"') + `<g transform="translate(${F(x + size / 2)} ${F(y + size / 2)}) scale(${F(sc)} ${F(-sc)}) translate(${F(-c[0])} ${F(-c[1])})">${inner}</g>`;
}
// generic patterns to avoid, drawn in grey on a light tile (cx, cy is the centre, r the radius)
function avoid(kind, cx, cy, r) {
  const st = `fill="none" stroke="${GREY}" stroke-width="${F(r * 0.14)}" stroke-linecap="round" stroke-linejoin="round"`;
  const ring = (rr) => `<circle cx="${F(cx)}" cy="${F(cy)}" r="${F(rr)}" ${st}/>`;
  if (kind === 'prohibit') return ring(r * 0.8) + `<line x1="${F(cx - r * 0.56)}" y1="${F(cy - r * 0.56)}" x2="${F(cx + r * 0.56)}" y2="${F(cy + r * 0.56)}" ${st}/>`;
  if (kind === 'target') return ring(r * 0.85) + ring(r * 0.55) + `<circle cx="${F(cx)}" cy="${F(cy)}" r="${F(r * 0.18)}" fill="${GREY}"/>`;
  if (kind === 'linked') return [-0.9, -0.3, 0.3, 0.9].map((k, i) => `<circle cx="${F(cx + k * r * 0.62)}" cy="${F(cy + (i % 2 ? 0.16 : -0.16) * r)}" r="${F(r * 0.38)}" ${st}/>`).join('');
  if (kind === 'double') { const ch = dy => `<polyline points="${F(cx - r * 0.7)},${F(cy + dy + r * 0.3)} ${F(cx)},${F(cy + dy - r * 0.3)} ${F(cx + r * 0.7)},${F(cy + dy + r * 0.3)}" ${st}/>`; return ch(-r * 0.32) + ch(r * 0.32); }
  if (kind === 'x') return `<line x1="${F(cx - r * 0.6)}" y1="${F(cy - r * 0.6)}" x2="${F(cx + r * 0.6)}" y2="${F(cy + r * 0.6)}" ${st}/><line x1="${F(cx + r * 0.6)}" y1="${F(cy - r * 0.6)}" x2="${F(cx - r * 0.6)}" y2="${F(cy + r * 0.6)}" ${st}/>`;
  if (kind === 'linegrid') { let o = ''; for (let i = -2; i <= 2; i++) o += `<line x1="${F(cx + i * r * 0.32)}" y1="${F(cy - r * 0.64)}" x2="${F(cx + i * r * 0.32)}" y2="${F(cy + r * 0.64)}" ${st.replace(F(r * 0.14), F(r * 0.06))}/><line x1="${F(cx - r * 0.64)}" y1="${F(cy + i * r * 0.32)}" x2="${F(cx + r * 0.64)}" y2="${F(cy + i * r * 0.32)}" ${st.replace(F(r * 0.14), F(r * 0.06))}/>`; return o; }
  if (kind === 'plus') return `<line x1="${F(cx - r * 0.6)}" y1="${F(cy)}" x2="${F(cx + r * 0.6)}" y2="${F(cy)}" ${st}/><line x1="${F(cx)}" y1="${F(cy - r * 0.6)}" x2="${F(cx)}" y2="${F(cy + r * 0.6)}" ${st}/>`;
  if (kind === 'egg') return `<ellipse cx="${F(cx)}" cy="${F(cy)}" rx="${F(r * 0.55)}" ry="${F(r * 0.72)}" fill="#e9e6ef" stroke="${GREY}" stroke-width="${F(r * 0.06)}"/><circle cx="${F(cx + r * 0.1)}" cy="${F(cy - r * 0.12)}" r="${F(r * 0.09)}" fill="${GREY}"/><circle cx="${F(cx - r * 0.2)}" cy="${F(cy - r * 0.12)}" r="${F(r * 0.09)}" fill="${GREY}"/>`;
  if (kind === 'radiate') {
    let o = `<circle cx="${F(cx)}" cy="${F(cy)}" r="${F(r * 0.34)}" fill="#dcd9e4" stroke="${GREY}" stroke-width="${F(r * 0.05)}"/>`;
    for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI * 2; o += `<line x1="${F(cx + Math.cos(a) * r * 0.5)}" y1="${F(cy + Math.sin(a) * r * 0.5)}" x2="${F(cx + Math.cos(a) * r * 0.86)}" y2="${F(cy + Math.sin(a) * r * 0.86)}" ${st}/>`; }
    return o;
  }
  if (kind === 'wavy') { let d = ''; for (let i = 0; i <= 12; i++) d += `${i ? 'L' : 'M'}${F(cx - r * 0.9 + i * r * 0.15)},${F(cy + Math.sin(i * 1.4) * r * 0.12)} `; return `<path d="${d}" ${st}/>` + `<path d="${d.replace(/,(-?[0-9.]+) /g, (m, y) => `,${(+y + r * 0.28).toFixed(2)} `)}" ${st}/>`; }
  if (kind === 'bang') { const w = r * 0.24; return `<g stroke="#111" stroke-width="${F(r * 0.2)}" stroke-linejoin="round" fill="#f2c230"><polygon points="${F(cx - w)},${F(cy - r * 0.8)} ${F(cx + w)},${F(cy - r * 0.8)} ${F(cx + w * 0.55)},${F(cy + r * 0.2)} ${F(cx - w * 0.55)},${F(cy + r * 0.2)}"/><circle cx="${F(cx)}" cy="${F(cy + r * 0.62)}" r="${F(w * 0.85)}"/></g>`; }
  return '';
}
const AVOID_NAME = { prohibit: 'ring with a slash (a prohibition sign)', target: 'concentric rings and a centre dot (a target)', linked: 'four linked rings', double: 'a tidy double chevron (car and oil logos)', x: 'two strokes crossed into an X', linegrid: 'a glowing line grid', plus: 'a cross or plus', egg: 'a plain egg with dot eyes', radiate: 'a ring of short lines around the head', wavy: 'wavy lines', bang: 'a yellow bang with a thick black outline' };

function legalSheet() {
  const W = 1800, H = 2330;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'Legal checks on the Marked plus flashes set', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'The checks Legal asked Art to run (docs/legal/q3-screen.md), because Legal cannot view SVGs. Generic patterns to avoid are drawn in grey, and are not copies of any logo or graphic.', { size: 15, fill: '#cfc6e6' });
  b += text(W - 30, 80, 'Status: run by Art, for Legal to confirm.', { size: 12, fill: '#cfc6e6', anchor: 'end' });

  // 1. masks: full colour, three flat colours, silhouette, at large and small size
  let y = 136;
  b += text(24, y, '1. The four masks: full colour, three flat colours (dark, light, sigil), and silhouette, at three-quarter and closer to the face', { size: 18, weight: 700 });
  const col1 = [['full colour, three-quarter (32)', { yaw: 32, mode: 'full' }], ['full colour, face-on (60)', { yaw: 60, mode: 'full' }], ['three flat colours (32)', { yaw: 32, mode: 'flat3' }], ['three flat colours (60)', { yaw: 60, mode: 'flat3' }], ['silhouette (32)', { yaw: 32, mode: 'sil' }], ['silhouette (60)', { yaw: 60, mode: 'sil' }]];
  col1.forEach(([cap, o], j) => { b += text(24 + j * 245 + 2, y + 20, cap, { size: 11.5, weight: 600, op: 0.85 }); });
  ORDER.forEach((fk, r) => {
    col1.forEach(([cap, o], j) => { b += closeup2(fk, 24 + j * 245, y + 28 + r * 236, 232, o); });
    b += text(24 + 6 * 245 + 6, y + 48 + r * 236, NAMES[fk], { size: 14, weight: 700 });
  });
  const xr = 24 + 6 * 245 + 6;
  b += paras(xr, y + 48 + 22, 'Protagonist: the pale dome with a brow ridge, a jaw plane and a crown seam is a designed shape. At three flat colours the open arc still reads as a single mark at the temple, off-centre, and it is never a closed ring; the silhouette is a faceted dome with a fringe of hair, not an egg.', 44, 11.5, 15);
  b += paras(xr, y + 48 + 22 + 236, 'Anti-hero: the lit slash leans, so it reads as a slash in three colours. Silhouette: a wedge head with the tail.', 44, 11.5, 15);
  b += paras(xr, y + 48 + 22 + 472, 'Empress: three offset chevrons on the brow, in moss on bone. In three flat colours the pale mask and moss chevrons hold. Silhouette: the topknot and the taller head.', 44, 11.5, 15);
  b += paras(xr, y + 48 + 22 + 708, 'Cyborg: a stair of lit squares on a dark display face, no line grid. Silhouette: a box head.', 44, 11.5, 15);
  // small-size silhouettes
  y = y + 28 + 4 * 236 + 20;
  b += text(24, y, 'Silhouette at play sizes (whole body, 80, 40, 24 and 12 px), against the light sky: each fighter stays a distinct shape', { size: 14, weight: 700 });
  ORDER.forEach((fk, i) => {
    const x0 = 24 + i * 444;
    b += rect(x0, y + 10, 432, 130, '#cfe6f0', 'stroke="#1b1428" stroke-opacity="0.25"');
    [[80, 60], [40, 150], [24, 220], [12, 280]].forEach(([px, dx]) => { b += fig(fk, px, x0 + dx, y + 132, { flat: true, state: 'neutral' }); });
    b += fig(fk, 40, x0 + 350, y + 132, { state: 'neutral' }) + fig(fk, 24, x0 + 400, y + 132, { state: 'neutral' });
    b += text(x0 + 8, y + 28, NAMES[fk], { size: 11.5, weight: 600, op: 0.8 });
  });

  // 2. sigils beside the symbols to avoid
  y += 176;
  b += text(24, y, '2. Each sigil beside the generic symbols Legal named (large, hurt, and thumbnail at 24 px, then the pattern to avoid)', { size: 18, weight: 700 });
  const avoids = { P: ['prohibit', 'target', 'linked'], A: ['prohibit', 'x', 'plus'], E: ['double', 'plus', 'x'], C: ['linegrid', 'plus', 'x'] };
  const sx = ['ours (at rest)', 'ours (hurt: a break, never a crossing line)', 'ours at 24 px', 'avoid', 'avoid', 'avoid'];
  sx.forEach((t, j) => { b += text(24 + j * 218 + 2, y + 20, t, { size: 11.5, weight: 600, op: 0.85 }); });
  ORDER.forEach((fk, r) => {
    const y0 = y + 28 + r * 196, sc = fk === 'P' ? 15 : fk === 'E' ? 14 : fk === 'C' ? 12 : 11;
    b += sigilTile(fk, 24, y0, 160, 'neutral', sc) + sigilTile(fk, 242, y0, 160, 'hurt', sc) + sigilTile(fk, 508, y0 + 48, 64, 'neutral', sc * 0.4);
    avoids[fk].forEach((k, j) => { b += rect(24 + (3 + j) * 218, y0, 160, 160, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.25"') + avoid(k, 24 + (3 + j) * 218 + 80, y0 + 80, 64) + text(24 + (3 + j) * 218 + 4, y0 + 174, AVOID_NAME[k], { size: 10.5, op: 0.75 }); });
    b += text(24 + 2, y0 + 174, NAMES[fk] + ': ' + { P: 'an open arc at the temple, no dot', A: 'a leaning slash and a dot', E: 'three chevrons, three sizes, offset', C: 'a stair of lit squares' }[fk], { size: 10.5, weight: 600, op: 0.85 });
  });
  y += 28 + 4 * 196 + 10;
  b += paras(24, y, 'Rules checked: the Protagonist\'s sigil is a single open arc (a "C" with a gap), with no dot and no inner ring, never a closed ring, and never sits with the slash on any fighter; the slash never crosses another stroke, and in hurt it splits with a gap instead of a crack drawn across it; the chevrons are three, of different sizes and offset, in moss (never a car or oil brand\'s colours); the grid is a stair of lit squares, with no lines and no cross bars. No sigil is placed as an eye or a mouth: the arc sits off-centre at the temple above the brow ridge, the chevrons on the brow, and the slash and the steps are mid-face marks with no pair and no line beneath them. The Coil\'s chest carries one diagonal sash, not two crossing straps, so nothing on the chest lines up into an X with the face slash.', 230, 12, 16);

  // 3. flashes beside the two reference patterns
  y += 96;
  b += text(24, y, '3. The flashes beside the two patterns to avoid: a ring of short lines around the head (with wavy lines), and a yellow bang with a thick black outline', { size: 18, weight: 700 });
  y += 14;
  b += rect(24, y, 872, 330, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.2"') + rect(904, y, 872, 330, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.2"');
  b += text(34, y + 20, 'Danger sense: ours, in the four families (a pointer train above and behind the head)', { size: 12, weight: 700 });
  ORDER.forEach((fk, i) => { b += fig(fk, 150, 100 + i * 200, y + 322, { state: 'danger' }); });
  b += `<g>${rect(736, y + 40, 150, 150, '#f6f4fa', 'stroke="#1b1428" stroke-opacity="0.2"')}${avoid('radiate', 811, y + 115, 64)}${avoid('wavy', 811, y + 215, 36)}${text(740, y + 206, 'avoid: ' + AVOID_NAME.radiate, { size: 10, op: 0.75 })}${text(740, y + 220, 'and ' + AVOID_NAME.wavy, { size: 10, op: 0.75 })}</g>`;
  b += text(914, y + 20, 'Found "!": ours (solid, thin keyline in the lane colour, no yellow, no thick black outline)', { size: 12, weight: 700 });
  ORDER.forEach((fk, i) => { b += fig(fk, 150, 990 + i * 200, y + 322, { state: 'found' }); });
  b += `<g>${rect(1626, y + 40, 140, 150, '#f6f4fa', 'stroke="#1b1428" stroke-opacity="0.2"')}${avoid('bang', 1696, y + 115, 60)}${text(1630, y + 206, 'avoid: ' + AVOID_NAME.bang, { size: 10, op: 0.75 })}</g>`;
  y += 346;
  b += paras(24, y, 'Danger sense is three shapes of growing size along one ray, up and behind the head, and its ray is turned to the threat\'s bearing at run time (kept above or behind, never around the head). It is not a ring of short lines and not wavy. Info flashes ("!", "?", danger) are a pale core inside a thin keyline in the lane\'s dark step; the Cyborg\'s are neutral steel, so no yellow and no red-orange, and no thick black outline appears anywhere in the set. The sigil has no rays in any state.', 230, 12, 16);

  // 4. dome, fan and round tips
  y += 84;
  b += text(24, y, '4. The dome mask against a plain egg, the round-tipped Anti-hero pride, and the Empress fan wide and low', { size: 18, weight: 700 });
  y += 14;
  b += closeup2('P', 24, y, 240, { yaw: 32, mode: 'full', px: 700 }) + closeup2('P', 276, y, 240, { yaw: 60, mode: 'full', px: 700 });
  b += rect(528, y, 240, 240, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.25"') + avoid('egg', 648, y + 120, 100) + text(534, y + 232, 'avoid: ' + AVOID_NAME.egg, { size: 10.5, op: 0.75 });
  b += rect(780, y, 300, 300, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"') + fig('A', 150, 900, y + 292, { state: 'pride', legacy: true }) + fig('A', 150, 1010, y + 292, { state: 'pride' });
  b += rect(1092, y, 340, 300, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"') + fig('E', 150, 1200, y + 292, { state: 'pride', legacy: true }) + fig('E', 150, 1340, y + 292, { state: 'pride' });
  b += rect(1444, y, 332, 300, '#e3eef5', 'stroke="#1b1428" stroke-opacity="0.15"') + fig('A', 150, 1520, y + 292, { state: 'surge' }) + fig('E', 150, 1660, y + 292, { state: 'surge' });
  b += paras(30, y + 262, 'The dome: brow ridge, jaw plane, crown seam, faceted crown, raised hairline. No eye or mouth slots or dots. Hair is a swept-back cap, teal, never upswept or gold. The plain egg on the right is the shape to avoid.', 88, 11.5, 15, { op: 0.85 });
  b += text(790, y + 318, 'Anti-hero pride: before (pointed), now (round-tipped).', { size: 11, op: 0.85 });
  b += text(1100, y + 318, 'Empress pride: before (a tall fan), now (a wide, low crest).', { size: 11, op: 0.85 });
  b += text(1452, y + 318, 'Surge (Anti-hero, Empress): held for a cinematic.', { size: 11, op: 0.85 });
  y += 350;
  // the Coil harness against the face slash
  b += text(24, y, '5. The Coil\'s chest against the face slash: one diagonal sash, no X', { size: 18, weight: 700 });
  b += `<svg x="24" y="${y + 12}" width="230" height="290" viewBox="138 225 230 290"><image href="../turnaround/coil-turnaround.svg" x="0" y="0" width="1800" height="2010"/></svg>` + rect(24, y + 12, 230, 290, 'none', 'stroke="#1b1428" stroke-opacity="0.3"');
  b += paras(276, y + 40, 'The face slash leans one way, the sash on the chest leans the other, and they are a whole head apart, with the neck between them. The chest has one sash and a round buckle with a small diamond stud, and no slash on the chest. Nothing on the figure crosses another stroke into an X. See docs/art/coil-turnaround.md for the part list.', 96, 12.5, 17);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${Math.max(H, y + 320)}" viewBox="0 0 ${W} ${Math.max(H, y + 320)}">${DEFS}${b.replace(`<rect x="0.00" y="0.00" width="${W}.00" height="${H}.00"`, `<rect x="0.00" y="0.00" width="${W}.00" height="${Math.max(H, y + 320)}.00"`)}</svg>`;
}

// ---------------------------------------------------------------------------------------------------------- sheet 6: the pitch (Orb picks)
const PITCH = {
  winded: { moment: 'Ki is nearly gone, or a long chase or a heavy guard has drained the fighter. Hands on the knees.', event: 'ki below 15 percent (exists today)', why: 'Cheap. It is the "I am spent" beat that makes a comeback or a hide-and-recover read. The ki bar already says it, so this is colour more than fact.', sound: 'A ragged breath.' },
  smug: { moment: 'A clean parry, a dodge-and-counter or a slipped pursuit: the fighter knows it just outplayed the other.', event: 'exchange outcome (exists today)', why: 'Sits between Pride (a decisive win) and Taunt (deliberate). It is the involuntary beat, so a quick read of who is winning the mind game.', sound: 'A short exhale through the nose.' },
  respect: { moment: 'A clash ends in a draw, a finisher is blocked, or a rival takes a hit and gets back up: the fighter acknowledges the other.', event: 'clash draw, finisher blocked, rally of the rival (partly exists)', why: 'The only kind flash. It gives the rivalry a second colour next to rage and pride, and suits the Protagonist and the Empress. Costs one slot.', sound: 'A low, short two-note nod.' },
  bored: { moment: 'A long lull: a stalled hide-and-seek, or waiting on a rival who is charging or hiding.', event: 'idle for more than 6 s (new, Encounter)', why: 'Comedy and character in dead time. At most once every 8 s, under a second. The weakest for gameplay, so a nice-to-have.', sound: 'A dry, flat sigh.' },
  hazard: { moment: 'The world is about to hit the fighter: a falling building, a collapsing crater rim, a beam path, water rising. Not a fighter attack (that is danger sense).', event: 'hazard telegraph (new, World and Encounter)', why: 'Power has weight and the planet is the arena, so the environment attacking you needs its own word. A double "!" says "the ground, not the rival". Info, solid.', sound: 'Two quick low ticks.' },
  primed: { moment: 'Leaving cover with the ambush window open (x1.5 damage for 2.5 s): the fighter knows it can strike hard now.', event: 'ambush_ready (new, exists in the prototype rules)', why: 'The hide-and-ambush pillar has a game rule with no signal. A pointer train pointing forward (danger sense points back) tells the player "hit now". It also tells the rival to expect it. Info, solid.', sound: 'A soft rising click.' },
};
function pitchSheet() {
  const W = 1800;
  let b = rect(0, 0, W, 4000, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'The flash set: a pitch for Orb', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'Before we settle on twelve. Six candidate additions and three cuts or merges, each with its game moment and whether it is information or emotion. Orb picks. Info flashes are a setting, on by default.', { size: 15, fill: '#cfc6e6' });
  let y = 136;
  b += text(24, y, 'A. Six candidate additions, in the four shape families (each at its peak)', { size: 18, weight: 700 });
  const cw = 290;
  CAND_ORDER.forEach((id, j) => {
    const f = FLASHES[id], x0 = 24 + j * cw;
    b += text(x0 + 4, y + 26, f.name, { size: 15, weight: 700 }) + text(x0 + 4, y + 42, `${f.cls === 'info' ? 'info: solid, keylined' : 'emotion: soft'}  ${fmtT(f)}`, { size: 10.5, op: 0.75 });
    ORDER.forEach((fk, r) => {
      const y0 = y + 50 + r * 196;
      b += rect(x0, y0, cw - 6, 190, f.cls === 'info' ? '#e3eef5' : '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"');
      b += fig(fk, 110, x0 + (fk === 'E' ? 170 : 140), y0 + 184, { state: id });
      if (j === 0) b += text(x0 + 6, y0 + 16, NAMES[fk], { size: 10.5, weight: 700, op: 0.7 });
    });
  });
  y += 50 + 4 * 196 + 24;
  b += text(24, y, 'What each is for', { size: 16, weight: 700 });
  y += 22;
  CAND_ORDER.forEach(id => {
    const f = FLASHES[id], p = PITCH[id], lines = wrap(`${p.moment}  Event: ${p.event}.  ${p.why}  Sound: ${p.sound}`, 205), n = lines.length;
    b += `<line x1="24" y1="${y}" x2="1776" y2="${y}" stroke="#1b1428" stroke-opacity="0.15"/>`;
    b += text(24, y + 16, f.name, { size: 13, weight: 700 }) + text(24, y + 32, f.cls === 'info' ? 'info' : 'emotion', { size: 11, op: 0.75 });
    lines.forEach((l, i) => { b += text(150, y + 16 + i * 15, l, { size: 12 }); });
    y += Math.max(44, 14 + n * 15) + 4;
  });
  // cuts and merges
  y += 24;
  b += text(24, y, 'B. Three candidate cuts or merges', { size: 18, weight: 700 });
  y += 14;
  const cuts = [
    { title: 'Cut Brink (the crown already owns it)', body: 'UI\'s HUD crown draws a dashed brink ring and owns wear events. A brink flash doubles it, and the arbitration rule would drop it whenever the crown is up. What we lose: a small dip in the fighter\'s own face. The Hurt flash and the dim, gapped sigil still carry the beat. Info or emotion: emotion. Frees a slot.', draws: [['P', 'brink'], ['P', 'hurt']], crown: true },
    { title: 'Cut Resolve (the crown owns the Rally)', body: 'A Rally or Second Wind already pops the crown, and the flash would wait for it and then be dropped. What we lose: the fighter\'s own beat of gathering itself, which Pride and the sigil lighting up can carry. Info or emotion: emotion. Frees a slot.', draws: [['P', 'resolve'], ['P', 'pride']], crown: false },
    { title: 'Merge Pride into Triumph (one "I won" beat)', body: 'Pride (a decisive exchange won) and Triumph (a finisher lands or a KO) are both winning beats that differ only in size. Merging keeps Triumph and adds a small version for the exchange. What we lose: the Anti-hero\'s standing-tall look and the Empress\'s crest before a KO. Info or emotion: emotion. Frees a slot but loses a character beat, so this is the one I would keep if a slot is not needed.', draws: [['A', 'pride'], ['A', 'triumph']], crown: false },
  ];
  cuts.forEach((c, j) => {
    const x0 = 24 + j * 592;
    b += rect(x0, y, 580, 290, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.15"');
    c.draws.forEach(([fk, id], i) => { b += fig(fk, 100, x0 + 100 + i * 200, y + 172, { state: id }); });
    if (c.crown) b += hudCrown(x0 + 100, y + 172 - 56, 56, true);
    b += text(x0 + 6, y + 18, c.title, { size: 12.5, weight: 700 });
    b += paras(x0 + 6, y + 196, c.body, 118, 10.5, 13.5, { op: 0.85 });
  });
  y += 316;
  // recommendation
  b += text(24, y, 'C. What I recommend', { size: 18, weight: 700 });
  y += 24;
  b += paras(24, y, 'Twelve, plus Hazard, Primed and Respect, minus Brink and Resolve: thirteen flashes, five of them info. The two cuts are the two the HUD crown already owns, so no moment loses its signal. Hazard and Primed give the planet-as-arena and the hide-and-ambush pillars a word each, and both are information a player can use. Respect gives the rivalry a second colour. Winded, Smug and Bored are cheap and can join later without touching the rest, so I would hold them until the twelve are proven in the prototype.', 230, 13, 18);
  y += 90;
  b += paras(24, y, 'Lock-on acquired is not a separate flash: Found already covers a lock regained. The info set is Danger sense, Hazard, Primed, Found and Searching, and they are one setting ("info flashes"), on by default, so a player can turn all of them off together. Each new flash gets a row in data/art/flashes.json, a sound word for Audio and an event name for Encounter and Game Design; none of them changes the arbitration rules.', 230, 13, 18);
  y += 90;
  b += text(24, y, 'The question for Orb: which of these do you want? A yes or no per flash is enough.', { size: 14, weight: 700 });
  const H = y + 40;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b.replace('<rect x="0.00" y="0.00" width="1800.00" height="4000.00"', `<rect x="0.00" y="0.00" width="1800.00" height="${H}.00"`)}</svg>`;
}

const ORIGIN = '<!-- Origin: procedural concept sheet written by art/concepts/marked-aura/gen.mjs (deterministic, no external images or fonts; the staging sheet embeds the repo\'s own renders in docs/rendering/img by reference), Art Director session (Claude, claude-sonnet-5-5), 2026-09-29; prompt record art/prompts/ART-0005-marked-aura.md -->' + String.fromCharCode(10);
writeFileSync(join(OUT, 'ma-1-style.svg'), ORIGIN + styleSheet());
writeFileSync(join(OUT, 'ma-2-flashes.svg'), ORIGIN + vocabSheet());
writeFileSync(join(OUT, 'ma-3-staging.svg'), ORIGIN + stagingSheet());
writeFileSync(join(OUT, 'ma-4-flash-rules.svg'), ORIGIN + rulesSheet());
writeFileSync(join(OUT, 'ma-5-legal-checks.svg'), ORIGIN + legalSheet());
writeFileSync(join(OUT, 'ma-6-flash-pitch.svg'), ORIGIN + pitchSheet());
// The flash data, for Rendering, UI and Audio: ids, class, timing, priority, cooldown, shape family and the layouts.
const json = { version: 2, decision: 'Orb added Hazard, Primed and Respect; the EP cut Brink (the crown\'s brink ring covers it), kept Resolve (sequenced after the crown\'s wear pop) and kept Pride apart from Triumph. Then Orb removed hiding from the base game (held for a future stealth fighter), so Primed (the ambush window) moves to held with Winded, Smug and Bored. Thirteen active flashes, four of them info (danger, hazard, found, searching). Found and Searching stay, for lock-on regained and lost through line of sight.', held: Object.fromEntries(['winded', 'smug', 'bored', 'primed'].map(id => [id, { name: FLASHES[id].name, class: FLASHES[id].cls, attack: FLASHES[id].t[0], hold: FLASHES[id].t[1], fade: FLASHES[id].t[2], kind: FLASHES[id].kind, glyph: FLASHES[id].glyph ?? null, layout: FLASHES[id].layout ?? null, note: id === 'primed' ? 'Held: the ambush window needs hiding, which the base game no longer has. Points forward and up, a single direction.' : 'Held from the pitch.' }])), arbitration: { default_wait_max: 0.25, note: 'A flash due while the crown is up waits up to default_wait_max and is then dropped, except a flash with a sequence block: Resolve starts delay_after_crown_down seconds after the crown goes down (crown_up() false), waits up to wait_max, and is never dropped by arbitration (only the surge can preempt it).' }, note: 'Canonical data, written by art/concepts/marked-aura/gen.mjs (Art owns data/art/). Angles are degrees (0 forward, 90 up), d and s are in units of head size / 12. Names and looks are placeholders.', families: { P: 'circles', A: 'blades', E: 'wedges', C: 'steps' }, accents: Object.fromEntries(ORDER.map(k => [k, { light: PAL[k].accent.light, mid: PAL[k].accent.mid, shadow: PAL[k].accent.shadow }])), emotion_colours: { rule: 'Emotion flashes: rim is the accent mid step and core the accent light step, except where the accent sits on the fighter\'s own hair. The Protagonist\'s teal flashes overlap his teal hair, so his rim is the accent light step and his core is near-white. The rim must be lighter than the hair mid step by at least 15 L*.', overrides: { P: { rim: PAL.P.accent.light, core: '#e6f7f3' } }, hair_mid: { P: PAL.P.hair.mid } }, legal_rules: { round_tip: { A: [...A_ROUND] }, low_crest: { E: [...E_CREST], A: ['surge'], note: 'Wide and low behind the head: angle a becomes atan2(sin(a) * 0.4, cos(a)) + 42 degrees, size x 0.7, distance + 4. Ground shards are unchanged.' }, danger_ray: { default_angle: 132, clamp: [60, 200], note: 'Rotate the whole pointer train to the threat bearing at run time (facing frame, 0 forward, 90 up). Always above or behind the head, never around it.' }, info_colours: INFO, info_keyline: 'The core fills 84 percent of the rim. Emotion flashes keep a rim and a 58 percent core.' }, flashes: Object.fromEntries(FLASH_ORDER.map(id => { const f = FLASHES[id]; return [id, { name: f.name, class: f.cls, attack: f.t[0], hold: f.t[1], fade: f.t[2], priority: f.pri, cooldown: f.cool, kind: f.kind, glyph: f.glyph ?? null, layout: f.layout ?? null, moment: f.moment, event: f.event, sound: f.sound, rare: !!f.rare, sequence: f.sequence ?? null }]; })) };
writeFileSync(join(OUT, '..', '..', '..', 'data', 'art', 'flashes.json'), JSON.stringify(json, null, 2) + String.fromCharCode(10));
console.log('wrote ma-1 to ma-6 sheets and data/art/flashes.json');
