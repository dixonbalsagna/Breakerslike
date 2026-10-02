// Origin: procedural unmasked face close-ups for the refinement sheets (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-10-02. Human direction: Orb, via the EP.
// Orb's art direction (2026-10-02): masks are for one future character, not the house style; the unmasked faces and the silhouettes are the base to refine, the Cyborg first.
// Faces are drawn in the close-up engine's coordinates (y down, centred on 0,0 of a 512 portrait, the art facing right) and use its eyes, brows, mouths and frame.

import { H } from '../closeups/engine.mjs';
const { poly, line, ell, rotp, pts, eye, brow, mouth, shade, HEAD, RIG, LITC, LITC_EDGE } = H;

const ST = (P, w = 6) => `stroke="${P.line}" stroke-width="${w}" stroke-linejoin="round"`;
// draw with a fighter's eye rig changed for the duration of one call (restored after)
function withRig(fk, patch, fn) {
  const old = { ...RIG[fk] };
  Object.assign(RIG[fk], patch);
  try { return fn(); } finally { for (const k of Object.keys(patch)) { if (k in old) RIG[fk][k] = old[k]; else delete RIG[fk][k]; } }
}
const shadeOf = (arr, fill, id, from = 40) => `<clipPath id="sx-${id}"><polygon points="${from},-300 320,-300 320,300 ${from + 42},300"/></clipPath><g clip-path="url(#sx-${id})">${poly(arr, fill, 'opacity="0.55"')}</g>`;
const clipTo = (arr, id, inner) => `<clipPath id="cp-${id}"><polygon points="${pts(arr)}"/></clipPath><g clip-path="url(#cp-${id})">${inner}</g>`;
const nose = (P, x = 0, y = 0) => poly([[x - 4, y - 6], [x + 16, y + 30], [x - 12, y + 38]], P.skinSh, 'opacity="0.55"');
const readout = (x, y, P, n = 3) => Array.from({ length: n }, (_, i) => poly([[x, y + i * 20], [x + 20, y + i * 20], [x + 20, y + 12 + i * 20], [x, y + 12 + i * 20]], LITC, `stroke="${LITC_EDGE}" stroke-width="2"`)).join('');
const paleEye = (cx, cy, w, h, P) => poly([[cx - w, cy - h], [cx + w, cy - h], [cx + w, cy + h], [cx - w, cy + h]], LITC, `stroke="${LITC_EDGE}" stroke-width="3" stroke-linejoin="round"`);

// =================================================================================================================== the Cyborg: six directions
// Shared: the current Cyborg is the dark box-headed soldier with a half-and-half face and a lit eye. The directions keep what is his (a heavy, boxy, stepped fighter in a dark red lane)
// or change it on purpose. Lit parts are the pale cream-peach tone; no lone red eye, no bolts, no stitches, no goggles.

// 0. the current face is the engine's own portrait('C'), drawn in gen.mjs for the comparison

// 1. THE STEPPER (the same fighter, refined): a stepped crown, a stair split, a stepped collar. The stair is the whole language.
const STEPPER = [[-168, -236], [-98, -236], [-98, -204], [-30, -204], [-30, -172], [150, -172], [168, -124], [168, 108], [132, 172], [-132, 172], [-168, 108]];
export function cyStepper(fk, e, id, P) {
  const { pg, edge } = H.breakPoly('C', 0);
  let o = poly(STEPPER, P.skin, ST(P, 6)) + shadeOf(STEPPER, P.skinSh, id);
  o += clipTo(STEPPER, id, `${clipTo(pg, id + 'b', poly(STEPPER, '#38343f', ST(P, 4)) + poly([[16, -300], [60, -300], [60, 300], [16, 300]], '#4a4552', 'opacity="0.35"'))}${line(edge, P.line, 8)}${line(edge, LITC, 2.6)}`);
  o += withRig('C', { ex: 96, ew: 38 }, () => eye('C', -1, e, 'skin', P) + eye('C', 1, e, 'lit', P) + brow('C', -1, e, P) + brow('C', 1, e, P, 'mask'));
  o += nose(P, -20, 0) + mouth('C', e, P, 'skin') + readout(136, 100, P);
  // the collar: three steps down the near side of the neck (the stair again)
  o += poly([[-132, 172], [132, 172], [132, 196], [96, 196], [96, 220], [60, 220], [60, 244], [-132, 244]], '#38343f', ST(P, 5)) + line([[96, 196], [132, 196]], LITC, 2.5) + line([[60, 220], [96, 220]], LITC, 2.5);
  return o;
}

// 2. THE STACK (the same fighter, bolder): the head is three blocks that slide. Expression is the blocks moving, and the stair becomes the way he is built.
export function cyStack(fk, e, id, P) {
  const sh = e.mouth === 'hurt' ? [-26, 2, 24] : e.mouth === 'laugh' ? [12, 0, -12] : [6, 0, -6], gap = e.mouth === 'hurt' ? 16 : 8;
  const top = [[-158 + sh[0], -206], [158 + sh[0], -206], [158 + sh[0], -92], [-158 + sh[0], -92]], mid = [[-136 + sh[1], -92 + gap], [140 + sh[1], -92 + gap], [140 + sh[1], 40], [-136 + sh[1], 40]];
  const bot = [[-120 + sh[2], 40 + gap], [128 + sh[2], 40 + gap], [112 + sh[2], 170], [-104 + sh[2], 170]];
  let o = poly(top, '#38343f', ST(P)) + poly(mid, P.skin, ST(P)) + poly(bot, '#6f666d', ST(P));
  o += shadeOf(mid, P.skinSh, id) + line([[top[0][0] + 14, -120], [top[1][0] - 14, -120]], LITC, 3) + readout(top[1][0] - 70, -184, P, 1).replace(/20,/g, '20,');
  o += withRig('C', { ex: 76, ey: -28 + gap, ew: 36, browY: -78 + gap, mouthY: 118 }, () => eye('C', -1, e, 'skin', P, sh[1]) + eye('C', 1, e, 'skin', P, sh[1]) + brow('C', -1, e, P) + brow('C', 1, e, P));
  o += nose(P, sh[1], gap) + line([[-50 + sh[2], 112 + gap], [50 + sh[2], 112 + gap + (e.mouth === 'hurt' ? 10 : 0)]], LITC, 6);
  o += poly([[-30 + sh[2], 150 + gap], [30 + sh[2], 150 + gap], [30 + sh[2], 156 + gap], [-30 + sh[2], 156 + gap]], '#4a4552');
  return o;
}

// 3. THE FURNACE (bolder): a heavy, sunk, anvil head with a brow shelf, deep eyes lit from below by heat seams, a vent for a mouth.
const ANVIL = [[-124, -150], [124, -150], [160, -108], [168, 20], [148, 120], [66, 176], [-66, 176], [-148, 120], [-168, 20], [-160, -108]];
export function cyFurnace(fk, e, id, P) {
  const soot = '#8a7673', sootSh = '#5e4f4d', plate = '#3c3a42';
  let o = poly(ANVIL, soot, ST(P, 7)) + shadeOf(ANVIL, sootSh, id);
  o += poly([[-166, -112], [166, -112], [150, -52], [-150, -52]], plate, ST(P, 5)) + line([[-150, -104], [150, -104]], '#6c6772', 3);   // the brow shelf
  o += withRig('C', { fam: 'square', ex: 76, ey: -22, ew: 30, browY: -120, browTh: 10, mouthY: 140 }, () => eye('C', -1, e, 'skin', P) + eye('C', 1, e, 'skin', P));
  // heat vents on the cheeks: three short bars each side, stepping outward
  const bars = s => [0, 1, 2].map(i => poly([[s * (128 + i * 8) - 14, 30 + i * 24], [s * (128 + i * 8) + 14, 30 + i * 24], [s * (128 + i * 8) + 14, 38 + i * 24], [s * (128 + i * 8) - 14, 38 + i * 24]], LITC)).join('');
  o += bars(-1) + bars(1) + nose(P, 0, 6);
  // the vent: four slats, which jam and tilt when he is hurt
  const hurt = e.mouth === 'hurt' || e.mouth === 'grit';
  o += poly([[-90, 104], [90, 104], [76, 168], [-76, 168]], plate, ST(P, 5));
  for (let i = 0; i < 5; i++) o += poly([[-60 + i * 30 - 6, 114 + (hurt && i % 2 ? 6 : 0)], [-60 + i * 30 + 6, 114 + (hurt && i % 2 ? 6 : 0)], [-60 + i * 30 + 6 + (hurt ? (i - 2) * 3 : 0), 156], [-60 + i * 30 - 6 + (hurt ? (i - 2) * 3 : 0), 156]], hurt && i === 3 ? '#4a4552' : LITC);
  o += poly([[-166, 20], [-130, 20], [-130, 60], [-166, 60]], plate, ST(P, 3));
  return o;
}

// 4. THE FRAME (bolder): a human face held in an open frame. A person inside a machine; the cables are the spine.
export function cyFrame(fk, e, id, P) {
  const bone = '#d8d0c8', boneSh = '#9c948f';
  let o = poly([[-96, 170], [-150, 252], [-110, 252], [-60, 176]], '#38343f', ST(P, 4)) + line([[-70, 176], [-100, 220], [-90, 270]], LITC, 3);
  o += poly([[-168, -200], [168, -200], [168, 150], [112, 196], [-112, 196], [-168, 150]], bone, ST(P, 7)) + shadeOf([[-168, -200], [168, -200], [168, 150], [112, 196], [-112, 196], [-168, 150]], boneSh, id);
  const face = [[-132, -160], [132, -160], [132, 110], [88, 160], [-88, 160], [-132, 110]];
  o += poly(face, P.skin, ST(P, 6)) + shadeOf(face, P.skinSh, id + 'f');
  o += withRig('C', { fam: 'round', lid: 0.78, ex: 64, ey: -34, ew: 28, browIn: 24, browOut: 100, browY: -84, browTh: 18, mouthY: 90, mouthW: 40 }, () => eye('C', -1, e, 'skin', P) + eye('C', 1, e, 'skin', P) + brow('C', -1, e, P) + brow('C', 1, e, P) + mouth('C', e, P, 'skin'));
  o += nose(P, 0, 10);
  o += poly([[120, -196], [164, -196], [164, -150], [120, -150]], '#38343f', ST(P, 3)) + paleEye(142, -173, 12, 8, P);   // a status chip on the frame, not on the face
  o += line([[-168, -60], [-168, 40]], LITC, 4);
  return o;
}

// 5. THE PROSTHETIC (the same fighter, humane): a working man's face with one plate set into the cheekbone. The machine is a tool he wears, not what he is.
const MAN = [[-130, -176], [130, -176], [152, -130], [156, 60], [120, 150], [60, 176], [-60, 176], [-120, 150], [-156, 60], [-152, -130]];
export function cyWorker(fk, e, id, P) {
  const hair = '#3a161c';
  let o = poly(MAN, P.skin, ST(P, 7)) + shadeOf(MAN, P.skinSh, id) + poly([[-110, 110], [110, 110], [60, 176], [-60, 176]], P.skinSh, 'opacity="0.5"');
  o += poly([[-154, -178], [150, -178], [158, -120], [118, -120], [118, -140], [40, -140], [40, -152], [-40, -152], [-40, -140], [-120, -140], [-120, -120], [-158, -120]], hair, ST(P, 6)) + poly([[-156, -122], [-124, -122], [-132, -40], [-156, -40]], hair);   // a hairline that steps   // a flat-topped head of hair and a sideburn
  const plate = [[26, -86], [156, -86], [156, -6], [112, -6], [112, 26], [26, 26]];
  o += poly(plate, '#8c8187', ST(P, 5)) + paleEye(88, -34, 34, 20, P) + line([[26, 26], [26, -86]], '#c9c0c4', 3);
  o += withRig('C', { fam: 'round', ex: 64, ey: -34, ew: 30, browIn: 24, browOut: 110, browY: -84, browTh: 24, mouthY: 112, mouthW: 46 }, () => eye('C', -1, e, 'skin', P) + brow('C', -1, e, P) + brow('C', 1, e, P, 'dark') + mouth('C', e, P, 'skin'));
  o += nose(P, -6, 6);
  return o;
}

// 6. THE SPRINTER (bolder): a lean runner's head, swept hair, a headset slab over the ear, a stair strip on the cheek.
const LEAN = [[-110, -150], [-60, -190], [70, -190], [118, -150], [124, -40], [96, 100], [50, 172], [-50, 172], [-96, 100], [-124, -40]];
export function cyRunner(fk, e, id, P) {
  let o = poly([[-118, -120], [-196, -102], [-232, -66], [-190, -80], [-126, -56]], '#3a161c', ST(P, 6));
  o += poly(LEAN, P.skin, ST(P, 7)) + shadeOf(LEAN, P.skinSh, id);
  o += poly([[-122, -118], [-98, -192], [22, -204], [122, -152], [114, -118], [40, -152], [-40, -150], [-118, -70]], '#3a161c', ST(P, 6));
  o += withRig('C', { fam: 'square', ex: 54, ey: -34, ew: 28, browIn: 20, browOut: 100, browY: -78, browTh: 16, mouthY: 108, mouthW: 38 }, () => eye('C', -1, e, 'skin', P) + eye('C', 1, e, 'skin', P) + brow('C', -1, e, P) + brow('C', 1, e, P) + mouth('C', e, P, 'skin'));
  o += nose(P, 0, 8);
  o += poly([[-158, -76], [-108, -76], [-108, 14], [-158, 14]], '#38343f', ST(P, 5)) + [0, 1, 2].map(i => poly([[-150, -62 + i * 24], [-116, -62 + i * 24], [-116, -52 + i * 24], [-150, -52 + i * 24]], LITC)).join('');
  o += poly([[70, 60], [104, 40], [100, 52], [66, 74]], '#8c8187', ST(P, 3)) + poly([[60, 78], [96, 58], [92, 70], [56, 92]], '#8c8187', ST(P, 3));   // a stair strip on the cheek
  return o;
}

// =================================================================================================================== the other three: refined unmasked faces
// Built from the close-up engine's own unmasked faces (the ones Orb liked) with the refinements added: the eyes and brows tuned, and one new feature each.
export function refined(fk, e, id, P, v = 'r') {
  const tune = { P: { lid: 0.8, ew: 32, browTh: 30, browIn: 22 }, A: { lid: 0.68, ew: 50, browTh: 13 }, E: { lid: 0.78, ew: 46, browTh: 17 } }[fk];
  return withRig(fk, tune, () => {
    let o = H.hairBack(fk, P) + poly(HEAD[fk], P.skin, ST(P, 6)) + shade(fk, P.skinSh, id) + H.nose?.(fk, P);
    o += eye(fk, -1, e, 'skin', P) + eye(fk, 1, e, 'skin', P) + brow(fk, -1, e, P) + brow(fk, 1, e, P) + mouth(fk, e, P, 'skin') + H.hairFront(fk, P);
    if (fk === 'P') {
      o += poly(ell(-120, -50, 20, 20, 14), 'none', `stroke="${P.acc}" stroke-width="12" stroke-dasharray="90 30"`);
      // a forelock that falls across the brow and curls forward: his hair has a direction
      o += poly([[40, -170], [100, -150], [136, -104], [128, -64], [106, -90], [76, -112], [30, -130]], P.hair, ST(P, 6)) + line([[60, -156], [100, -126], [114, -92]], P.hairSh, 5);
      o += line([[-60, 10], [-30, 28]], P.skinSh, 5, 'opacity="0.7"');
    }
    if (fk === 'A') {
      o += H.sigil('A', P);
      // a long lock that falls past the cheek on the open side
      o += poly([[96, -150], [150, -90], [158, 10], [140, 90], [128, 20], [124, -60]], P.hair, ST(P, 6)) + line([[130, -60], [142, 0], [138, 50]], P.hairSh, 5);
    }
    if (fk === 'E') {
      o += H.sigil('E', P, true);
      // one large chevron on the cheekbone, in her moss: the diadem's mark worn on the face
      o += poly([[34, 12], [62, 44], [90, 12], [90, 30], [62, 62], [34, 30]], P.acc, `stroke="${P.line}" stroke-width="4" stroke-linejoin="round"`);
      // a thick lash that sweeps out from the corner of each eye
      o += poly([[96, -54], [134, -78], [118, -46]], P.line) + poly([[-96, -54], [-134, -78], [-118, -46]], P.line);
    }
    return o;
  });
}
