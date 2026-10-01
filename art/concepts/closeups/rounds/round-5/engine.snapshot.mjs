// Origin: procedural close-up face engine for the three style directions (deterministic, no randomness, no external images or fonts).
// Written by the Art Director session (Claude, claude-sonnet-5-5), 2026-10-02. Human direction: Orb, via the EP. Every face is original: big flat shapes, our own frame.
// Directions: A the mask as a face (an expressive mask), B the mask partly off or broken (a real face framed by the mask), C no mask (a full stylized face).
// Coordinates: y down, the face centred on (0, 0) of a 512 x 512 portrait, the art faces right (the gaze goes to the opponent).

const f2 = n => n.toFixed(1);
const pts = a => a.map(([x, y]) => `${f2(x)},${f2(y)}`).join(' ');
const poly = (a, fill, extra = '') => `<polygon points="${pts(a)}" fill="${fill}" ${extra}/>`;
const ell = (cx, cy, rx, ry, n = 20) => Array.from({ length: n }, (_, i) => { const a = (i / n) * Math.PI * 2; return [cx + Math.cos(a) * rx, cy + Math.sin(a) * ry]; });
const rotp = (a, deg, c = [0, 0]) => { const r = deg * Math.PI / 180, co = Math.cos(r), si = Math.sin(r); return a.map(([x, y]) => [c[0] + (x - c[0]) * co - (y - c[1]) * si, c[1] + (x - c[0]) * si + (y - c[1]) * co]); };
const line = (a, stroke, w, extra = '') => `<polyline points="${pts(a)}" fill="none" stroke="${stroke}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round" ${extra}/>`;
const mirrorPts = a => a.map(([x, y]) => [-x, y]).reverse();

// ---------------------------------------------------------------------------------------------------------- palettes: few values, one accent each
export const PALS = {
  P: { skin: '#bb7d54', skinSh: '#8a5538', hair: '#3fae9c', hairSh: '#22705f', mask: '#e8f1ee', maskSh: '#b9cfc9', line: '#0c1c20', acc: '#4fb9a8', accL: '#8fd6c8', bg: '#2e6470', bgShape: '#3d7c88', frame: '#8fd6c8', white: '#f3efe8' },
  A: { skin: '#dcc7ba', skinSh: '#a08a85', hair: '#1d1630', hairSh: '#3a2f56', mask: '#2b2444', maskB: '#3d3270', maskSh: '#1a1530', line: '#120c1e', acc: '#9664d8', accL: '#d3baf2', bg: '#cbbdf0', bgShape: '#b7a3e8', frame: '#5b479a', white: '#f3efe8' },
  E: { skin: '#eccb98', skinSh: '#b08a52', hair: '#1e2413', hairSh: '#3b4726', mask: '#e6e0c4', maskSh: '#bdb692', line: '#0f1206', acc: '#b8c96a', accL: '#dfe8a8', bg: '#4a5a2a', bgShape: '#5b6d35', frame: '#dfe8a8', white: '#f3efe8', band: '#f4f3dc' },
  C: { skin: '#c4aaa4', skinSh: '#85706c', hair: '#3a161c', hairSh: '#220b10', mask: '#34313d', maskSh: '#221f29', line: '#14070a', acc: '#d8705f', accL: '#f0b4a8', bg: '#e8c9c2', bgShape: '#f0b4a8', frame: '#8a3a30', white: '#f3efe8', steel: '#8c8187', plate: '#3a161c' },
};
// the head shapes: strong silhouettes of jaw, brow and crown. Each fighter's shape language: round and open (P), sharp and narrow (A), tall and severe (E), boxed (C).
const HEAD = {
  P: [[-152, -36], [-144, -132], [-92, -186], [0, -204], [92, -186], [144, -132], [152, -36], [140, 62], [98, 132], [44, 170], [-44, 170], [-98, 132], [-140, 62]],
  A: [[-120, -58], [-114, -148], [-56, -198], [42, -204], [112, -150], [126, -52], [104, 58], [54, 150], [0, 188], [-54, 150], [-100, 58]],
  E: [[-104, -50], [-100, -150], [-52, -206], [30, -216], [96, -160], [110, -60], [124, -14], [92, 50], [56, 134], [4, 182], [-46, 140], [-92, 50], [-122, -14]],
  C: [[-150, -170], [150, -170], [168, -122], [168, 108], [132, 172], [-132, 172], [-168, 108], [-168, -122]],
};
// eye rig per fighter: centre, size, shape family, brow style
const RIG = {
  P: { ex: 74, ey: -30, ew: 35, fam: 'round', browIn: 26, browOut: 120, browY: -84, browTh: 26, mouthY: 100, mouthW: 48 },
  A: { lid: 0.8, ex: 62, ey: -36, ew: 46, fam: 'blade', browIn: 20, browOut: 108, browY: -90, browTh: 16, mouthY: 96, mouthW: 40 },
  E: { lid: 0.88, ex: 58, ey: -50, ew: 42, fam: 'wedge', browIn: 16, browOut: 106, browY: -100, browTh: 15, mouthY: 106, mouthW: 36 },
  C: { ex: 84, ey: -28, ew: 40, fam: 'square', browIn: 34, browOut: 130, browY: -78, browTh: 24, mouthY: 106, mouthW: 58 },
};
// the expressions: eyebrow inner and outer heights (offsets from the rest line), eye openness for each side, tilt, the head's own tilt, and the mouth
const PALEMASK = { P: true, E: true };
export const EXPR = {
  neutral: { browL: [0, 0], browR: [0, 0], oL: 1, oR: 1, tilt: 0, head: 0, dy: 0, k: 1, gaze: [10, 0], mouth: 'flat' },
  smirk: { browL: [4, 6], browR: [-14, -28], oL: 0.55, oR: 0.9, tilt: 4, head: -6, dy: -4, k: 1, gaze: [14, 4], mouth: 'smirk' },
  strain: { browL: [22, -12], browR: [22, -12], oL: 0.55, oR: 0.55, tilt: -15, head: 4, dy: 10, k: 1.04, gaze: [8, 2], mouth: 'grit' },
  hurt: { browL: [-34, 10], browR: [-34, 10], oL: 0.12, oR: 0.5, tilt: 13, head: 15, dy: 14, k: 0.98, gaze: [-6, 14], mouth: 'hurt' },
};

// ---------------------------------------------------------------------------------------------------------- eyes, brows, mouths
function eyeShape(fam, w, o) {
  if (fam === 'round') return ell(0, 0, w * 0.95, Math.max(3, w * 0.86 * o), 18);
  if (fam === 'blade') return [[-w, 4], [-w * 0.3, -w * 0.5 * o - 2], [w * 0.55, -w * 0.5 * o - 4], [w * 1.08, -2], [w * 0.3, w * 0.34 * o + 2], [-w * 0.5, w * 0.3 * o + 2]];
  if (fam === 'wedge') return [[-w, 6], [-w * 0.2, -w * 0.46 * o - 2], [w * 1.12, -w * 0.52 * o - 8], [w * 0.7, w * 0.04], [-w * 0.1, w * 0.34 * o + 2]];
  return [[-w * 0.9, -w * 0.6 * o - 1], [w * 0.9, -w * 0.6 * o - 1], [w * 0.9, w * 0.5 * o + 1], [-w * 0.9, w * 0.5 * o + 1]];
}
// one eye. s is -1 for the viewer's left and 1 for the right. mode: 'skin' (a white with a dark pupil) or 'lit' (an emissive shape, no pupil)
function eye(fk, s, e, mode, P, cx = 0, cy = 0) {
  const R = RIG[fk], o = (s < 0 ? e.oL : e.oR) * (R.lid ?? 1), w = R.ew, ox = R.ex * s + cx, oy = R.ey + cy;
  const tilt = e.tilt * (s < 0 ? 1 : 1);
  const place = a => rotp(a.map(([x, y]) => [x * s, y]), -s * tilt, [0, 0]).map(([x, y]) => [x + ox, y + oy]);
  const shape = place(eyeShape(R.fam, w, o));
  if (o < 0.2) return line(place([[-w, 0], [w, 0]]), mode === 'lit' && !PALEMASK[fk] ? P.accL : P.line, mode === 'lit' ? 8 : 7);   // shut: one thick line
  if (mode === 'lit') return PALEMASK[fk] ? poly(shape, P.acc, `stroke="${P.line}" stroke-width="6" stroke-linejoin="round"`) : poly(shape, P.accL, `stroke="${P.acc}" stroke-width="3" stroke-linejoin="round"`);
  const g = e.gaze, pr = w * (fk === 'P' ? 0.4 : 0.5) * Math.min(1, 0.5 + o), pc = [ox + g[0] * 0.6 * 1, oy + g[1] * 0.35];
  const pupil = R.fam === 'square' ? [[-pr, -pr * o - 2], [pr, -pr * o - 2], [pr, pr * o + 2], [-pr, pr * o + 2]].map(([x, y]) => [x + pc[0], y + pc[1]]) : R.fam === 'blade' ? [[-pr * 0.5, -pr * o - 4], [pr * 0.5, -pr * o - 4], [pr * 0.45, pr * o + 4], [-pr * 0.45, pr * o + 4]].map(([x, y]) => [x + pc[0], y + pc[1]]) : ell(pc[0], pc[1], pr, Math.min(pr, w * 0.8 * o), 14);
  return poly(shape, P.white, `stroke="${P.line}" stroke-width="7" stroke-linejoin="round"`) + poly(pupil, P.line) + line(place(eyeShape(R.fam, w, o).slice(0, Math.ceil(eyeShape(R.fam, w, o).length / 2) + 1)), P.line, 12);
}
function brow(fk, s, e, P, kind = 'skin') {
  const R = RIG[fk], b = s < 0 ? e.browL : e.browR, yi = R.browY + b[0], yo = R.browY + b[1] - 4, th = R.browTh;
  const col = kind === 'mask' ? (PALEMASK[fk] ? P.line : P.acc) : P.hair;
  const quad = [[s * R.browIn, yi - th * 0.5], [s * R.browOut, yo - th * 0.2], [s * R.browOut, yo + th * (fk === 'E' || fk === 'A' ? 0.0 : 0.4)], [s * R.browIn, yi + th * 0.5]];
  return poly(quad, col, `stroke="${P.line}" stroke-width="3" stroke-linejoin="round"`);
}
function mouth(fk, e, P, mode, cx = 0) {
  const R = RIG[fk], y = R.mouthY, w = R.mouthW, ink = mode === 'lit' && !PALEMASK[fk] ? P.accL : P.line, lw = fk === 'P' ? 9 : fk === 'C' ? 10 : 7;
  const X = x => x + cx;
  if (e.mouth === 'flat') return line([[X(-w), y], [X(w), y]], ink, lw);
  if (e.mouth === 'smirk') return line([[X(-w), y + 6], [X(0), y + 2], [X(w * 1.1), y - 20]], ink, lw) + line([[X(w * 1.1), y - 20], [X(w * 1.1 + 8), y - 30]], ink, lw * 0.7);
  if (e.mouth === 'grit') {
    const m = [[X(-w * 1.15), y - 18], [X(w * 1.15), y - 18], [X(w * 0.95), y + 22], [X(-w * 0.95), y + 22]];
    let o = poly(m, mode === 'lit' && !PALEMASK[fk] ? P.maskSh : P.line, `stroke="${P.line}" stroke-width="3" stroke-linejoin="round"`);
    o += poly([[X(-w * 1.1), y - 16], [X(w * 1.1), y - 16], [X(w * 1.0), y + 2], [X(-w * 1.0), y + 2]], mode === 'lit' && !PALEMASK[fk] ? P.accL : P.white);
    for (let i = -2; i <= 2; i++) o += line([[X(i * w * 0.42), y - 16], [X(i * w * 0.42), y + 2]], P.line, 3.5);
    return o;
  }
  return line([[X(-w), y + 14], [X(-w * 0.5), y + 2], [X(0), y + 10], [X(w * 0.5), y], [X(w), y + 16]], ink, lw) + (mode === 'lit' ? '' : poly([[X(-w * 0.2), y + 12], [X(w * 0.2), y + 12], [X(w * 0.1), y + 26], [X(-w * 0.1), y + 26]], P.line));
}

// ---------------------------------------------------------------------------------------------------------- hair and head dress
function hairBack(fk, P) {
  if (fk === 'P') return poly([[-160, -50], [-214, -112], [-286, -96], [-318, -24], [-262, -44], [-204, -4], [-166, 24]], P.hairSh, `stroke="${P.line}" stroke-width="7" stroke-linejoin="round"`) + poly([[-172, -40], [-172, -142], [-112, -222], [0, -252], [112, -234], [170, -164], [152, -92], [100, -140], [30, -170], [-40, -160], [-110, -130], [-152, -72]], P.hair, `stroke="${P.line}" stroke-width="7" stroke-linejoin="round"`);
  if (fk === 'A') return poly([[-90, -170], [-150, -130], [-196, -40], [-228, 70], [-246, 170], [-206, 108], [-158, 30], [-116, -50]], P.hair, `stroke="${P.line}" stroke-width="7" stroke-linejoin="round"`) + line([[-176, -40], [-206, 60], [-222, 130]], P.hairSh, 6);
  if (fk === 'E') return poly(ell(-8, -254, 46, 46, 14), P.hair, `stroke="${P.line}" stroke-width="7" stroke-linejoin="round"`);
  return '';
}
function hairFront(fk, P) {
  if (fk === 'A') return poly([[-122, -112], [-108, -190], [-44, -226], [52, -224], [114, -184], [134, -112], [124, -44], [104, -86], [88, -128], [30, -148], [-30, -142], [-88, -112]], P.hair, `stroke="${P.line}" stroke-width="7" stroke-linejoin="round"`) + line([[-70, -206], [-30, -164], [20, -150]], P.hairSh, 6) + line([[60, -206], [90, -160], [112, -110]], P.hairSh, 6);
  if (fk === 'E') return poly([[-108, -138], [-62, -208], [40, -214], [102, -158], [108, -112], [0, -132], [-104, -112]], P.hair, `stroke="${P.line}" stroke-width="7" stroke-linejoin="round"`) + poly([[-118, -134], [118, -134], [120, -100], [26, -102], [0, -66], [-26, -102], [-120, -100]], P.band, `stroke="${P.line}" stroke-width="5" stroke-linejoin="round"`);
  if (fk === 'C') return poly([[-130, -196], [130, -196], [158, -150], [-158, -150]], P.plate, `stroke="${P.line}" stroke-width="7" stroke-linejoin="round"`) + poly([[-60, -184], [60, -184], [60, -160], [-60, -160]], P.maskSh);
  return poly([[152, -100], [146, -178], [78, -230], [-26, -238], [-112, -194], [-156, -112], [-150, -84], [-112, -138], [-60, -154], [-8, -104], [38, -156], [104, -142]], P.hair, `stroke="${P.line}" stroke-width="7" stroke-linejoin="round"`) + line([[-80, -214], [-40, -170], [-8, -124]], P.hairSh, 6) + line([[70, -220], [100, -180], [118, -150]], P.hairSh, 6);
}
// what the mask carries: the sigil, always in its place and never with the slash and ring together
function sigil(fk, P, dim = false) {
  const c = dim ? P.acc : P.accL;
  if (fk === 'P') { const a = []; for (let d = 70; d <= 350; d += 12) a.push([-96 + 26 * Math.cos(d * Math.PI / 180), -106 - 26 * Math.sin(d * Math.PI / 180)]); return line(a, c, 12); }
  if (fk === 'A') return poly([[-96, -4], [-76, -4], [-86, 100], [-106, 100]], c, `stroke="${P.acc}" stroke-width="3"`) + poly(ell(-64, 100, 8, 8, 8), c);
  if (fk === 'E') return [[-62, -118, 0.7], [-6, -122, 0.95], [58, -126, 1.25]].map(([x, y, k]) => poly([[x - 17 * k, y - 6 * k], [x, y + 8 * k], [x + 17 * k, y - 6 * k], [x + 17 * k, y - 15 * k], [x, y - 1 * k], [x - 17 * k, y - 15 * k]], P.acc, `stroke="${P.line}" stroke-width="2.5"`)).join('');
  return [[-132, -40, 20], [-106, -14, 26], [-76, 14, 32], [-40, 46, 38]].map(([x, y, s]) => poly([[x - s / 2, y - s / 2], [x + s / 2, y - s / 2], [x + s / 2, y + s / 2], [x - s / 2, y + s / 2]], c)).join('');
}
function rim(fk, P) { if (PALEMASK[fk]) return ''; const a = HEAD[fk].filter(([x]) => x > 60).map(([x, y]) => [x * 0.97, y * 0.97]); return line(a, P.acc, 6, 'opacity="0.95"'); }
// the head's flat shading: one plane on the right (the light is from the left)
function shade(fk, fill, id) { return `<clipPath id="sh-${id}"><polygon points="40,-260 300,-260 300,260 82,260"/></clipPath><g clip-path="url(#sh-${id})">${poly(HEAD[fk], fill, 'opacity="0.55"')}</g>`; }
function nose(fk, P) { return poly([[-4, -6], [16, 30], [-12, 38]], P.skinSh, 'opacity="0.55"'); }

// ---------------------------------------------------------------------------------------------------------- the three directions
function dirC(fk, e, id, P) {   // no mask: a full stylized face
  let o = hairBack(fk, P) + poly(HEAD[fk], P.skin, `stroke="${P.line}" stroke-width="6" stroke-linejoin="round"`) + shade(fk, P.skinSh, id) + nose(fk, P);
  if (fk === 'C') o += poly([[-168, -122], [8, -122], [8, 172], [-132, 172], [-168, 108]], P.steel, `stroke="${P.line}" stroke-width="4"`) + eye(fk, 1, e, 'skin', P) + poly(eyeShape('square', 36, e.oL).map(([x, y]) => [x - RIG.C.ex, y + RIG.C.ey]), P.accL, `stroke="${P.acc}" stroke-width="4"`) + sigil(fk, P);
  else o += eye(fk, -1, e, 'skin', P) + eye(fk, 1, e, 'skin', P);
  o += brow(fk, -1, e, P) + brow(fk, 1, e, P) + mouth(fk, e, P, 'skin') + hairFront(fk, P);
  if (fk === 'P') o += poly([[-86, -118], [-58, -118], [-72, -64]], P.acc, 'opacity="0"');
  if (fk === 'A') o += sigil('A', P);   // his sigil as a lit slash inlaid on the cheek
  if (fk === 'E') o += sigil('E', P, true);
  if (fk === 'P') o += poly(ell(-120, -50, 20, 20, 14), 'none', `stroke="${P.acc}" stroke-width="10" stroke-dasharray="90 30"`);
  return o;
}
function dirA(fk, e, id, P) {   // the mask as a face: eyes, brow and mouth are lit shapes that change
  let o = hairBack(fk, P) + poly(HEAD[fk], P.mask, `stroke="${P.line}" stroke-width="6" stroke-linejoin="round"`) + shade(fk, P.maskSh, id);
  o += rim(fk, P) + brow(fk, -1, e, P, 'mask') + brow(fk, 1, e, P, 'mask') + eye(fk, -1, e, 'lit', P) + eye(fk, 1, e, 'lit', P) + mouth(fk, e, P, 'lit') + (fk === 'E' ? '' : sigil(fk, P)) + hairFront(fk, P) + (fk === 'E' ? sigil('E', P) : '');
  return o;
}
// Direction B: the mask partly off or broken. Each fighter's mask breaks a different way, so the break itself is part of who they are:
// the Anti-hero's loses its left half (a vertical, lit crack), the Protagonist's a diagonal chunk (the face shows at the lower right), the Empress's is a veil over the lower face
// (the eyes are free), and the Cyborg's display covers the right half. The damage stages retreat the mask a little more each time.
const BREAK = {
  A: { cover: 'left', pts: [[10, -300], [26, -250], [4, -200], [30, -150], [2, -90], [28, -30], [0, 40], [24, 100], [2, 160], [20, 220]], retreat: [-22, 0], maskPt: [-70, 10], skinPt: [74, 50], eye: [62, -36] },
  P: { cover: 'above', pts: [[300, -130], [150, -112], [110, -82], [60, -98], [10, -60], [-10, -20], [-50, 0], [-80, 50], [-130, 60], [-300, 120]], retreat: [-16, -14], maskPt: [-70, -70], skinPt: [60, 50], eye: [74, -30] },
  E: { cover: 'below', pts: [[-300, 50], [-120, 40], [-60, 70], [0, 30], [60, 70], [120, 40], [300, 48]], retreat: [0, 18], maskPt: [0, 110], skinPt: [0, -20], eye: [58, -50] },
  C: { cover: 'right', pts: [[18, -190], [-4, -120], [20, -60], [-8, 0], [18, 60], [-4, 120], [20, 180], [-6, 240], [16, 300]], retreat: [20, 0], maskPt: [90, 10], skinPt: [-80, 40], eye: [-84, -28] },
};
function breakPoly(fk, stage) {
  const B = BREAK[fk], pp = B.pts.map(([x, y]) => [x + B.retreat[0] * stage, y + B.retreat[1] * stage]);
  if (B.cover === 'left') return { pg: [...pp, [-300, 300], [-300, -300]], edge: pp };
  if (B.cover === 'right') return { pg: [...pp, [300, 300], [300, -300]], edge: pp };
  if (B.cover === 'above') return { pg: [[300, -300], ...pp, [-300, -300]], edge: pp };
  return { pg: [[-300, 300], ...pp, [300, 300]], edge: pp };
}
// the damage on the face: scuffs on the mask and a bruise on the skin, then a crack in the mask, a cut and a loose strand, then a swollen eye and a second crack
function faceDamage(fk, stage, P) {
  if (!stage) return '';
  const B = BREAK[fk], [mx, my] = B.maskPt, [sx, sy] = B.skinPt, [ex, ey] = B.eye, bruise = '#6d3a78'; let o = '';
  const sc = (x, y, l, a) => line([[x, y], [x + Math.cos(a) * l, y + Math.sin(a) * l]], PALEMASK[fk] ? P.maskSh : P.accL, 4, 'opacity="0.9"');
  o += sc(mx - 20, my - 30, 36, 0.5) + sc(mx + 10, my + 20, 28, 0.6) + sc(mx - 30, my + 50, 24, 0.4);
  o += poly(ell(sx, sy, 34, 22, 14), bruise, 'opacity="0.5"');
  if (stage >= 2) {
    const c1 = [[mx + 40, my - 70], [mx + 10, my - 30], [mx + 30, my], [mx - 10, my + 40]];
    o += line(c1, P.line, 7) + line(c1, P.accL, 2.5);
    o += line([[sx - 20, sy + 6], [sx + 30, sy - 12]], P.line, 5) + line([[sx - 4, sy - 2], [sx - 6, sy + 12]], P.line, 3) + line([[sx + 14, sy - 8], [sx + 12, sy + 6]], P.line, 3);
    o += line([[ex - 6, -130], [ex - 20, -90], [ex - 10, -58]], PALS[fk].hair, 7);
  }
  if (stage >= 3) {
    const c2 = [[mx - 50, my - 40], [mx - 20, my - 10], [mx - 40, my + 24], [mx - 8, my + 60]];
    o += poly(ell(ex, ey + 4, 54, 38, 16), bruise, 'opacity="0.7"') + line([[ex - 44, ey + 6], [ex + 44, ey - 2]], P.line, 8);
    o += line(c2, P.line, 7) + line(c2, P.accL, 2.5) + line([[sx + 18, sy + 54], [sx + 40, sy + 66]], P.line, 5);
  }
  return o;
}
function dirB(fk, e, id, P, stage = 0) {
  const { pg, edge } = breakPoly(fk, stage), mk = P.maskB ?? P.mask;
  let o = hairBack(fk, P) + poly(HEAD[fk], P.skin, `stroke="${P.line}" stroke-width="7" stroke-linejoin="round"`) + shade(fk, P.skinSh, id) + nose(fk, P);
  o += (fk === 'C' ? eye(fk, -1, e, 'skin', P) + brow(fk, -1, e, P) : eye(fk, -1, e, 'skin', P) + eye(fk, 1, e, 'skin', P) + brow(fk, -1, e, P) + brow(fk, 1, e, P)) + mouth(fk, e, P, 'skin');
  const maskFeatures = fk === 'C' ? eye(fk, 1, e, 'lit', P) + brow(fk, 1, e, P, 'mask') + mouth(fk, e, P, 'lit') + sigil(fk, P)
    : fk === 'A' ? eye(fk, -1, e, 'lit', P) + brow(fk, -1, e, P, 'mask') + mouth(fk, e, P, 'lit') + sigil(fk, P)
      : fk === 'P' ? eye(fk, -1, e, 'lit', P) + brow(fk, -1, e, P, 'mask') + sigil(fk, P)
        : mouth(fk, e, P, 'lit');
  o += `<clipPath id="m-${id}"><polygon points="${pts(pg)}"/></clipPath><clipPath id="hc-${id}"><polygon points="${pts(HEAD[fk])}"/></clipPath>` +
    `<g clip-path="url(#hc-${id})"><g clip-path="url(#m-${id})">${poly(HEAD[fk], mk, `stroke="${P.line}" stroke-width="7"`)}${shade(fk, P.maskSh, id + 'm')}${maskFeatures}</g>${line(edge, P.line, 9)}${line(edge, PALEMASK[fk] ? P.maskSh : P.accL, 3.2)}</g>`;
  o += faceDamage(fk, stage, P) + hairFront(fk, P) + (fk === 'E' ? sigil('E', P) : '');
  return o;
}

// ---------------------------------------------------------------------------------------------------------- the frame and the portrait
const GROUND = {
  P: s => `<circle cx="120" cy="150" r="150" fill="${s}"/><circle cx="430" cy="380" r="110" fill="${s}"/><circle cx="360" cy="60" r="46" fill="${s}"/>`,
  A: s => `<polygon points="330,0 400,0 190,512 110,512" fill="${s}"/><polygon points="470,0 512,0 512,120 330,512 290,512" fill="${s}"/><polygon points="0,260 60,200 60,512 0,512" fill="${s}"/>`,
  E: s => `<polygon points="0,512 260,120 380,512" fill="${s}"/><polygon points="512,512 512,150 330,512" fill="${s}"/><polygon points="0,0 170,0 0,200" fill="${s}"/>`,
  C: s => [[300, 400, 212, 112], [372, 328, 140, 72], [444, 256, 68, 72], [20, 20, 90, 90], [110, 110, 60, 60]].map(([x, y, w, h]) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${s}"/>`).join(''),
};
export const IDS = { P: 'protagonist', A: 'anti_hero', E: 'empress', C: 'cyborg' };
// A portrait: a 512 x 512 group (our own frame: a chamfered square with two opposite corners cut, a flat lane ground with large flat shapes of the family, a keyline).
export function portrait(dir, fk, expr, id, o = {}) {
  const P = PALS[fk], e = EXPR[expr], cid = `fc-${id}`, framePoly = '30,0 512,0 512,482 482,512 0,512 0,30';
  const draw = { A: dirA, B: dirB, C: dirC }[dir];
  const face = draw(fk, e, id, P, o.stage ?? 0);
  const scale = 0.96 * e.k, tx = 256 + (fk === 'A' || fk === 'P' ? 18 : 0), ty = 302 + e.dy;
  return `<defs><clipPath id="${cid}"><polygon points="${framePoly}"/></clipPath></defs><g clip-path="url(#${cid})">` +
    `<rect width="512" height="512" fill="${P.bg}"/>${GROUND[fk](P.bgShape)}<g transform="translate(${f2(tx)} ${f2(ty)}) rotate(${e.head}) scale(${f2(scale)})">${face}</g>${o.damage ? o.damage(P) : ''}</g>` +
    `<polygon points="${framePoly}" fill="none" stroke="${P.frame}" stroke-width="10" stroke-linejoin="miter"/><polygon points="${framePoly}" fill="none" stroke="#14101f" stroke-width="2"/>` +
    `<rect x="360" y="470" width="118" height="12" fill="${P.acc}" stroke="#14101f" stroke-width="2"/>`;
}
