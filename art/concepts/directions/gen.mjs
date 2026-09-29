// Origin: procedural generator for the character art direction sheets (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-09-29. Human direction: Orb, via the EP.
// Run from the repo root:  node art/concepts/directions/gen.mjs   (writes dir-1-blank.svg ... dir-4-poster.svg and directions-comparison.svg)

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeCtx, figure, CIVILIAN, CIV_POSES, POSES } from '../anti-hero/kit.mjs';
import { FIGHTERS, GUARD, ORDER, PALETTES, LANE } from './fighters.mjs';

const OUT = dirname(fileURLToPath(import.meta.url));
const F = n => n.toFixed(2);
const esc = t => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family=\"'Segoe UI', system-ui, -apple-system, Helvetica, Arial, sans-serif\"";
const text = (x, y, t, { size = 14, weight = 400, fill = '#1b1428', anchor = 'start', op = 1, style = 'normal' } = {}) =>
  `<text x="${F(x)}" y="${F(y)}" ${FONT} font-size="${size}" font-weight="${weight}" font-style="${style}" fill="${fill}" text-anchor="${anchor}" opacity="${op}">${esc(t)}</text>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${F(x)}" y="${F(y)}" width="${F(w)}" height="${F(h)}" fill="${fill}" ${extra}/>`;
const wrap = (t, n) => { const w = t.split(' '), out = []; let line = ''; for (const x of w) { if ((line + ' ' + x).trim().length > n) { out.push(line.trim()); line = x; } else line += ' ' + x; } if (line.trim()) out.push(line.trim()); return out; };
const paras = (x, y, t, n, size = 13, gap = 17, o = {}) => wrap(t, n).map((l, i) => text(x, y + i * gap, l, { size, ...o })).join('');

// ---------------------------------------------------------------------------------------------------------- styles
const INK = '#14101c', PAPER = '#f3ecda';
const SPOT = { P: '#22c7a9', A: '#a36cf0', E: '#a8d820', C: '#ff6b63' };
const NEUTRAL = {
  line: '#101014', skin: { light: '#e7c9ad', mid: '#c99a78', shadow: '#8f6448' }, hair: { light: '#5a4a3a', mid: '#3b3128', shadow: '#221b15' },
  base: { light: '#8a93a3', mid: '#6c7079', shadow: '#4a4f57' }, gear: { light: '#c7ccd6', mid: '#9aa1ad', shadow: '#6c7079' }, accent: { light: '#c7ccd6', mid: '#9aa1ad', shadow: '#6c7079' },
};
const flatPal = (col, line) => ({ line, skin: { light: col, mid: col, shadow: col }, hair: { light: col, mid: col, shadow: col }, base: { light: col, mid: col, shadow: col }, gear: { light: col, mid: col, shadow: col }, accent: { light: col, mid: col, shadow: col } });

export const STYLES = {
  blank: {
    key: 'blank', n: 1, title: 'Blank', file: 'dir-1-blank.svg', faceless: true, toy: false, bg: '#eeeaf4',
    tagline: 'Faceless masks. Identity from head shape, silhouette, colour and one signature feature.',
    sw: px => (px < 9 ? 0 : px < 28 ? 0.6 : px < 80 ? 1 : 1.3), build: {},
    pal: k => PALETTES[k], civPal: () => NEUTRAL,
  },
  ink: {
    key: 'ink', n: 2, title: 'Ink', file: 'dir-2-ink.svg', faceless: false, toy: false, bg: '#f2ecdc',
    tagline: 'Heavy brush line, a dry edge and an offset ink shadow. Painted, printed, hand-made.',
    sw: px => (px < 9 ? 0.3 : px < 28 ? 1.0 : px < 80 ? 2.2 : 4.2), build: {},
    pal: k => PALETTES[k], civPal: () => NEUTRAL,
  },
  toy: {
    key: 'toy', n: 3, title: 'Toy', file: 'dir-3-toy.svg', faceless: false, toy: true, bg: '#e6e1f0',
    tagline: 'Sculpted, chunky, vinyl-toy proportions with ball joints and a glossy highlight.',
    sw: px => (px < 14 ? 0.5 : 1), build: { hs: 1.5, lw: 1.3, leg: 0.82, tl: 0.92, arm: 0.92, tw: 1.05 },
    pal: k => PALETTES[k], civPal: () => NEUTRAL,
  },
  poster: {
    key: 'poster', n: 4, title: 'Poster', file: 'dir-4-poster.svg', faceless: false, toy: false, bg: null,
    tagline: 'Stark two-tone print: ink, paper and one spot colour per fighter. White-line edges.',
    sw: px => (px < 14 ? 0 : px < 80 ? 0.8 : 1.2), build: {},
    pal: k => ({ line: PAPER, skin: { light: PAPER, mid: PAPER, shadow: SPOT[k] ?? '#a36cf0' }, hair: { light: INK, mid: INK, shadow: INK }, base: { light: INK, mid: INK, shadow: INK }, gear: { light: PAPER, mid: PAPER, shadow: SPOT[k] ?? '#a36cf0' }, accent: { light: SPOT[k] ?? '#a36cf0', mid: SPOT[k] ?? '#a36cf0', shadow: INK } }),
    civPal: () => flatPal('#8f889c', PAPER),
  },
};
const STYLE_ORDER = ['blank', 'ink', 'toy', 'poster'];

const DEFS = `<defs>
<pattern id="mail" width="3.2" height="3.2" patternUnits="userSpaceOnUse"><circle cx="1.6" cy="1.6" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/><circle cx="0" cy="0" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/><circle cx="3.2" cy="3.2" r="1.15" fill="none" stroke="#f4dede" stroke-width="0.5"/></pattern>
<pattern id="hatch" width="2.2" height="2.2" patternUnits="userSpaceOnUse" patternTransform="rotate(35)"><line x1="0" y1="0" x2="0" y2="2.2" stroke="#14101c" stroke-width="0.75" opacity="0.85"/></pattern>
<filter id="rough1" x="-15%" y="-15%" width="130%" height="130%"><feTurbulence type="fractalNoise" baseFrequency="0.22" numOctaves="1" seed="3" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="0.9" xChannelSelector="R" yChannelSelector="G"/></filter>
<filter id="rough2" x="-15%" y="-15%" width="130%" height="130%"><feTurbulence type="fractalNoise" baseFrequency="0.09" numOctaves="2" seed="3" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="2.4" xChannelSelector="R" yChannelSelector="G"/></filter>
<filter id="rough3" x="-15%" y="-15%" width="130%" height="130%"><feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="3" seed="3" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="4.6" xChannelSelector="R" yChannelSelector="G"/></filter>
</defs>`;

// A fighter styled for a direction: the build is scaled and, for the toy look, joints and highlights are added.
const civConcept = (style) => ({
  ...CIVILIAN,
  cfg: pal => ({ ...CIVILIAN.cfg(pal), torso: style === 'poster' ? '#8f889c' : '#8a93a3', sleeve: style === 'poster' ? '#8f889c' : '#8a93a3', torsoShade: '#00000030' }),
  blankHead: pal => ({ poly: [[-4.6, 1], [-5.4, 8], [-4.4, 14], [0, 16.4], [4.6, 14], [5.6, 8], [4, 1.5]], fill: pal.skin.mid, shadow: pal.skin.shadow, shade: [[-4.6, 1], [-5.4, 8], [-4.4, 14], [0, 16.4], [1, 16], [-2.4, 12], [-2.4, 6], [-1, 0.6]] }),
});
function styled(concept, style) {
  const st = STYLES[style], b0 = concept.build ?? {}, m = st.build;
  const build = { tw: (b0.tw ?? 1) * (m.tw ?? 1), tl: (b0.tl ?? 1) * (m.tl ?? 1), lw: (b0.lw ?? 1) * (m.lw ?? 1), hs: (b0.hs ?? 1) * (m.hs ?? 1), leg: (b0.leg ?? 1) * (m.leg ?? 1), arm: (b0.arm ?? 1) * (m.arm ?? 1) };
  const c = { ...concept, build };
  if (st.toy) {
    const prev = concept.after;
    c.after = (ctx, sk, s2, cfg) => {
      const { pal } = ctx; if (ctx.flat) return prev ? prev(ctx, sk, s2, cfg) : '';
      let o = prev ? prev(ctx, sk, s2, cfg) : '';
      for (const p of [sk.S, sk.nearArm.E, sk.farArm.E, sk.nearLeg.K, sk.farLeg.K]) o += `<circle cx="${p.x.toFixed(2)}" cy="${p.y.toFixed(2)}" r="${(2.9 * build.lw).toFixed(2)}" fill="${pal.gear.shadow}" stroke="${pal.line}" stroke-width="0.9"/>`;
      const h = sk.Hd(2.6, 14.2);
      o += `<ellipse cx="${h.x.toFixed(2)}" cy="${h.y.toFixed(2)}" rx="${(2.1 * build.hs).toFixed(2)}" ry="${(1.0 * build.hs).toFixed(2)}" fill="#fff" opacity="0.75" transform="rotate(${(-(sk.headAng) + 20).toFixed(1)} ${h.x.toFixed(2)} ${h.y.toFixed(2)})"/>`;
      const sh = sk.T(2.4, 27), w = sk.nearArm.W;
      o += `<ellipse cx="${sh.x.toFixed(2)}" cy="${sh.y.toFixed(2)}" rx="1.9" ry="1" fill="#fff" opacity="0.6"/>`;
      o += `<ellipse cx="${(w.x + 1).toFixed(2)}" cy="${(w.y - 0.5).toFixed(2)}" rx="1.6" ry="0.9" fill="#fff" opacity="0.6"/>`;
      return o;
    };
  }
  return c;
}

const stateOf = (c, extra = {}) => ({ expression: 'proud', sway: c.sway ?? 6, open: 0, wear: 0, forms: 6, ...extra });
const roughFor = px => (px < 20 ? 'rough1' : px < 120 ? 'rough2' : 'rough3');

// Draw one figure in a style. px is body height in pixels; (x, ground) is where its feet are.
function fig(fk, style, px, x, ground, { flat = false, pose = null, state = {}, civ = false, gen = null } = {}) {
  const st = STYLES[style], s = px / 100;
  const base = civ ? civConcept(style) : (gen ?? FIGHTERS[fk]);
  const concept = styled(base, style);
  const pal = civ ? st.civPal() : st.pal(fk);
  const swMul = st.sw(px);
  const ctx = makeCtx({ flat, pal, swMul, toy: st.toy, faceless: st.faceless, shadeFill: style === 'ink' && px >= 90 ? 'url(#hatch)' : null });
  const p = pose ?? (civ ? CIV_POSES[0] : base.poses.base);
  const { svg } = figure(ctx, concept, p, civ ? { expression: 'neutral' } : stateOf(base, state));
  const g = `<g transform="translate(${F(x)} ${F(ground)}) scale(${F(s)} ${F(-s)})">${svg}</g>`;
  if (style !== 'ink') return g;
  const off = Math.max(0.7, px / 26);
  const shadowFig = (() => { const c2 = makeCtx({ flat: true, pal, swMul: 0, toy: false, faceless: st.faceless }); return figure(c2, concept, p, civ ? { expression: 'neutral' } : stateOf(base, state)).svg; })();
  return `<g filter="url(#${roughFor(px)})"><g transform="translate(${F(x + off)} ${F(ground + off)}) scale(${F(s)} ${F(-s)})" opacity="0.92">${shadowFig}</g>${g}</g>`;
}

const SEA = { top: '#cfe6f0', bottom: '#2f86ad' };
function chip(x, y, w, h, style, big = false) {
  return rect(x, y, w, h, SEA.top) + rect(x, y + h * 0.5, w, h * 0.5, SEA.bottom, 'opacity="1"');
}

const IDENT = {
  blank: {
    P: 'A smooth dome mask, a teal hair mass swept back, round fists and a round belt knot.',
    A: 'A wedge mask, a crouch, a spine of plates. The shape does the talking.',
    E: 'A tall crowned oval mask over a bladed cape-train. The widest, sharpest thing on screen.',
    C: 'A square mask with one visor slot, a square body, a lit chip in its chest hatch.',
  },
  ink: {
    P: 'Brush-drawn, warm and loose: round shapes with a fat, friendly line.',
    A: 'A tight, coiled brush drawing. The line is thickest on the spine and fists.',
    E: 'Long calligraphic sweeps for the mantle and hard flicks for the blades.',
    C: 'Angular, scratchy ink. The chain-mail is cross-hatched, the hatches are cut with a knife.',
  },
  toy: {
    P: 'A big-headed action figure with wrapped fists and ball joints. Lovable at once.',
    A: 'A compact vinyl crouch with a plate spine. Small, dense and menacing.',
    E: 'A collectible with a huge sweeping cape-train. Regal and a little absurd.',
    C: 'A chunky robot toy with a lit chip window. The joke is its politeness.',
  },
  poster: {
    P: 'Ink, cream and teal. A bold round sticker of a man.',
    A: 'Ink, cream and violet. The spine plates become a cream rack on black.',
    E: 'Ink, cream and chartreuse. The train is a black wedge with cream blades.',
    C: 'Ink, cream and red. Black squares, cream chain-mail, one red chip.',
  },
};
const SIG = { P: 'round fists, round belt knot, swept hair', A: 'the crouch and the spine of plates', E: 'the bladed cape-train and crescent collar', C: 'square body, chest rail and chip hatch' };
const NAMES = { P: 'Protagonist', A: 'Anti-hero', E: 'Empress', C: 'Cyborg' };

const NOTES = {
  blank: {
    striking: 'Nothing on screen looks like anything else. With no faces, each fighter is one shape and one colour, and the four shapes (circle, wedge, triangle, square) are the identity. It is also cheap to read at any speed.',
    recognizable: 'At 12 px the head shape and the posture carry it: a dome, a wedge, a tall oval, a box. The far beacon and the two-tone edge still apply. Emotion comes from head tilt and posture, so poses must be authored with care (the pose strip shows it).',
    godot: 'Lowest cost: a mask mesh per fighter, the standard three-band cel shader, inverted-hull outline, palette masks. No face rig, no eye or mouth animation, no lip sync. Head tilt and spine are the acting tools.',
    risk: 'Blank faces can read as lifeless or as a copy of other faceless-figure work. Guard against it: masks are shaped and coloured (never grey and round), heads are designed silhouettes, and no eyes or crosses are drawn. Fights need strong head tilt to sell emotion. One-liners lose the face beat, so the words and grunts carry more.',
  },
  ink: {
    striking: 'A hand-made, painted look nobody in the genre has. The brush line thickens on impact, the edge is dry and broken, and every frame looks like an ink drawing that a person made.',
    recognizable: 'Line weight and edge roughness are the signature, and shape lanes still work under it. At 12 px the ink shadow gives a strong dark mass. The risk is that a heavy black line on small figures becomes mush, so line width scales down and fades below 9 px.',
    godot: 'Inverted hull with per-vertex width from a noise map (brush taper), an offset dark hull for the ink shadow, and a noise-cut alpha edge for the dry brush. One 128 x 128 noise map. Two extra passes per fighter, so it costs more fill than Blank.',
    risk: 'Closest to a generic heavy-black-outline cartoon look, so it needs the most care: tinted inks per fighter, tapered variable strokes and coloured fills, never a uniform black outline on flat figures. Legal to screen it hardest. Busy line work can fight the destruction effects.',
  },
  toy: {
    striking: 'The most lovable and the easiest to merchandise. Big heads, chunky limbs, ball joints and a hard highlight make each fighter a collectible, and it pairs the violence with charm, which is Orb\'s funny and sincere tone.',
    recognizable: 'Proportion is the identity: heavy heads and short limbs read at 12 px better than any other direction, and the silhouettes stay distinct. Faces stay, so emotion is direct. The cost is that grimness has to come from the world and the wounds, not the bodies.',
    godot: 'Rounded meshes with smooth normals (about 30% more triangles), a two-band soft-terminator cel, a hard specular band, and separate ball-joint meshes. The rig shows its joints, which suits low-poly animation. No new shader tricks.',
    risk: 'It can undercut a mature, graphic tone: wounds on toys may read as either comic or disturbing. Big heads shrink the space for regalia and armour. The look invites comparison with vinyl-toy brands, so avoid a specific brand style.',
  },
  poster: {
    striking: 'The boldest. Two colours and cream: black bodies, a cream line and one spot colour per fighter. It looks like a screen print or a stencil, and it makes destruction and effects pop against it.',
    recognizable: 'The spot colour makes each fighter unmistakable at any zoom, and the black-and-cream value split works on the sea, the sky and at night. The cost is that everything must be re-thought in two tones: skin, faces and wear all lose their middle values.',
    godot: 'A palette-lookup shader: ink, paper and spot. Hard shadow threshold, white-line outline pass, no ramp needed. The cheapest fill of the four. The world must be limited to a few colours too, or figures will not sit in it.',
    risk: 'It commits the whole game to a restricted palette, including biomes and effects, which is a large decision. Wounds and blood lose their colour language (blood becomes the spot colour or cream). Procedural planets need a two-tone version.',
  },
};

const SHORT = {
  blank: { striking: 'Four shapes, four colours, no faces: nothing else looks like it.', risk: 'Can read as lifeless or as other faceless-figure work.', godot: 'Lowest cost: mask meshes and the standard cel shader.' },
  ink: { striking: 'A hand-painted look the genre does not have.', risk: 'Nearest to a generic heavy-outline cartoon. Legal to screen hardest.', godot: 'Noise-width hull outline, offset ink hull, noise edge. Most fill.' },
  toy: { striking: 'The most lovable and the easiest to merchandise.', risk: 'Undercuts a mature tone. Invites toy-brand comparison.', godot: 'Rounded meshes, soft two-band cel, joint meshes.' },
  poster: { striking: 'The boldest: ink, cream and one spot colour each.', risk: 'Commits the whole game, world and effects to two tones.', godot: 'Palette-lookup shader. Cheapest fill. The world must match.' },
};
// ---------------------------------------------------------------------------------------------------------- sheets
function directionSheet(sk) {
  const st = STYLES[sk], W = 1800, H = 1330;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, `Direction ${st.n}: ${st.title}`, { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, st.tagline, { size: 15, fill: '#cfc6e6' });
  b += text(W - 30, 80, 'Working labels, placeholder looks. Status: proposal, pending Legal review.', { size: 12, fill: '#cfc6e6', anchor: 'end' });
  ORDER.forEach((fk, i) => {
    const x0 = 24 + i * 444, y0 = 124, cw = 432;
    // showcase panel
    const bg = st.bg ?? SPOT[fk];
    b += rect(x0, y0, cw, 500, bg, 'stroke="#1b1428" stroke-opacity="0.25"');
    b += rect(x0 + 268, y0, cw - 268, 500, st.bg ? '#f7f5fa' : '#14101c', 'opacity="0.55"');
    b += text(x0 + 14, y0 + 28, NAMES[fk], { size: 22, weight: 700, fill: st.bg || fk === 'A' || fk === 'C' || fk === 'P' ? '#1b1428' : '#1b1428' });
    b += text(x0 + 14, y0 + 46, `${LANE[fk]} lane`, { size: 12, op: 0.8 });
    const gY = y0 + 470;
    b += fig(fk, sk, 290, x0 + 186, gY);
    // silhouette (top right) and civilian (bottom right)
    b += fig(fk, sk, 150, x0 + 352, y0 + 232, { flat: true });
    b += text(x0 + 268 + 82, y0 + 254, 'silhouette', { size: 11, anchor: 'middle', op: 0.75 });
    if (fk === 'E') {
      b += fig('E', sk, 110, x0 + 330, y0 + 470 - 4, { gen: GUARD, state: {} }).replace(/<g /, '<g ');
      b += fig(fk, sk, 110, x0 + 386, y0 + 470 - 4, { civ: true });
      b += text(x0 + 268 + 82, y0 + 492, 'guard of honour, civilian', { size: 11, anchor: 'middle', op: 0.75 });
    } else {
      b += fig(fk, sk, 100, x0 + 352, y0 + 470 - 4, { civ: true });
      b += text(x0 + 268 + 82, y0 + 492, 'civilian, same height', { size: 11, anchor: 'middle', op: 0.75 });
    }
    // gameplay strip
    const cy = y0 + 520, ch = 100;
    b += text(x0, cy - 4, 'Gameplay size: 40 px, then 12 px, colour and silhouette, with a civilian', { size: 11, weight: 600, op: 0.9 });
    [[40, false, 0], [40, true, 1], [12, false, 2], [12, true, 3]].forEach(([px, flat, j]) => {
      const cx = x0 + j * 108, w = 100;
      b += flat ? rect(cx, cy + 4, w, ch, '#f7f5fa', 'stroke="#1b1428" stroke-opacity="0.15"') : chip(cx, cy + 4, w, ch, sk);
      const g = cy + 4 + ch - 14;
      b += fig(fk, sk, px, cx + 66, g, { flat }) + fig(fk, sk, px, cx + 20, g, { flat, civ: true });
    });
    // emotion strip
    const ey = cy + 138;
    b += text(x0, ey, 'Posture and head tilt: proud, hurt, enraged', { size: 11, weight: 600, op: 0.9 });
    [['proud', POSES.proud], ['hurt', POSES.humbled], ['enraged', POSES.dropped]].forEach(([n, pose], j) => {
      const cx = x0 + 50 + j * 142;
      b += fig(fk, sk, 96, cx, ey + 122, { pose, state: { expression: n === 'hurt' ? 'humbled' : n === 'enraged' ? 'dropped' : 'proud', open: n === 'enraged' ? 1 : 0.3, sway: n === 'enraged' ? 40 : undefined } });
      b += text(cx, ey + 138, n, { size: 11, anchor: 'middle', op: 0.8 });
    });
    b += paras(x0, ey + 162, IDENT[sk][fk], 62, 12.5, 16, { op: 0.95 });
  });
  // direction text
  const n = NOTES[sk], ty = 1010;
  [['What makes it striking', n.striking], ['What makes it recognizable', n.recognizable], ['How it builds in Godot', n.godot], ['Risks', n.risk]].forEach(([h, t], i) => {
    const x = 30 + i * 444;
    b += text(x, ty, h, { size: 17, weight: 700 });
    b += paras(x, ty + 24, t, 60, 13, 18);
  });
  b += text(30, H - 22, 'Common rules kept in every direction: the value rule (dark bodies, light gear), the two-tone edge, the far beacon, the violet Anti-hero lane, and no borrowed look. See docs/art/directions.md.', { size: 12, op: 0.8 });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

function comparisonSheet() {
  const W = 1800, H = 1500;
  let b = rect(0, 0, W, H, '#dcd8e6') + rect(0, 0, W, 104, '#1b1428');
  b += text(30, 48, 'Character art directions: comparison', { size: 34, weight: 700, fill: '#f4f0fa' });
  b += text(30, 80, 'Four directions, four fighters each. Colour at showcase size, then 40 px and 12 px with a civilian. Orb decides. Status: pending Legal review.', { size: 15, fill: '#cfc6e6' });
  STYLE_ORDER.forEach((sk, r) => {
    const st = STYLES[sk], y0 = 120 + r * 316, rh = 304;
    b += rect(24, y0, W - 48, rh, '#eeeaf4', 'stroke="#1b1428" stroke-opacity="0.2"');
    b += text(40, y0 + 34, `${st.n}. ${st.title}`, { size: 26, weight: 700 });
    b += paras(40, y0 + 58, st.tagline, 22, 12.5, 16, { op: 0.9 });
    ORDER.forEach((fk, i) => {
      const cx = 250 + i * 300;
      b += rect(cx - 10, y0 + 12, 290, 280, st.bg ?? SPOT[fk], 'opacity="0.9"');
      b += fig(fk, sk, 172, cx + 112, y0 + 244);
      const cy = y0 + 156;
      b += chip(cx + 186, cy - 30, 98, 90, sk);
      b += fig(fk, sk, 40, cx + 250, cy + 44) + fig(fk, sk, 40, cx + 206, cy + 44, { civ: true });
      b += chip(cx + 186, cy + 66, 98, 60, sk);
      b += fig(fk, sk, 12, cx + 244, cy + 118) + fig(fk, sk, 12, cx + 218, cy + 118, { civ: true });
      b += text(cx + 4, y0 + 30, NAMES[fk], { size: 13, weight: 700, fill: st.bg ? '#1b1428' : '#1b1428' });
    });
    b += text(1470, y0 + 34, 'Striking', { size: 12, weight: 700 }) + paras(1470, y0 + 52, SHORT[sk].striking, 46, 12, 15);
    b += text(1470, y0 + 122, 'Risk', { size: 12, weight: 700 }) + paras(1470, y0 + 140, SHORT[sk].risk, 46, 12, 15);
    b += text(1470, y0 + 212, 'Godot', { size: 12, weight: 700 }) + paras(1470, y0 + 230, SHORT[sk].godot, 46, 12, 15);
  });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${DEFS}${b}</svg>`;
}

const ORIGIN = '<!-- Origin: procedural concept sheet written by art/concepts/directions/gen.mjs (deterministic, no external images or fonts), Art Director session (Claude, claude-sonnet-5-5), 2026-09-29; prompt record art/prompts/ART-0003-character-directions.md -->' + String.fromCharCode(10);
const only = process.argv[2];
if (!only || only === 'all') {
  for (const k of STYLE_ORDER) writeFileSync(join(OUT, STYLES[k].file), ORIGIN + directionSheet(k));
  writeFileSync(join(OUT, 'directions-comparison.svg'), ORIGIN + comparisonSheet());
  console.log('wrote dir-1-blank.svg, dir-2-ink.svg, dir-3-toy.svg, dir-4-poster.svg, directions-comparison.svg');
} else if (STYLES[only]) {
  writeFileSync(join(OUT, STYLES[only].file), ORIGIN + directionSheet(only));
  console.log('wrote', STYLES[only].file);
}
