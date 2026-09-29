// Canonical state view and hash. The same walk runs over the port's S and over the prototype's internals, so the parity
// tools can compare the two field by field, and replays can checkpoint the port with one short hash.
// Two lanes: gameplay (everything the rules read or write) and presentation (particles, damage numbers, banner, shake).

// Two 32-bit lanes over the raw IEEE-754 bits of every value (exact, order sensitive). Same algorithm as QA's Hasher.
const f64 = new Float64Array(1), u32 = new Uint32Array(f64.buffer);
export class Hasher {
  constructor() { this.a = 0x811c9dc5 | 0; this.b = 0x9e3779b9 | 0; }
  u(w) { this.a = Math.imul(this.a ^ w, 16777619); let b = Math.imul((this.b ^ w) + 0x7f4a7c15 | 0, 0x85ebca6b); this.b = b ^ (b >>> 13); }
  num(x) { f64[0] = x; this.u(u32[0]); this.u(u32[1]); }
  str(s) { for (let i = 0; i < s.length; i++) this.u(s.charCodeAt(i)); this.u(0xff); }
  hex() { return (this.a >>> 0).toString(16).padStart(8, '0') + (this.b >>> 0).toString(16).padStart(8, '0'); }
}

const FIGHTER = ['name', 'title', 'role', 'col', 'aura', 'hair', 'care', 'dmgMul', 'spd', 'maxhp', 'sigName', 'hp', 'x', 'y', 'vx', 'vy', 'face', 'ki', 'power', 'tier', 'stance', 'state', 'stateT',
  'hidden', 'hideT', 'hiddenFor', 'menace', 'anguish', 'ambush', 'rot', 'spin', 'bounces', 'lastAtkT', 'hurtT', 'keys', 'beamCharge', 'wet', 'ambushUntil', 'dPrev'];
const INTENT = ['mx', 'my', 'dash', 'charge', 'light', 'heavy', 'sig', 'stance'];
const BUILDING = ['x', 'w', 'h', 'maxhp', 'hp', 'alive', 'kind', 'pop', 'seed', 'popAlive'];
const TREE = ['x', 'h', 'alive', 'burn'];
const BEAM = ['ox', 'oy', 'ux', 'uy', 'len', 'p', 't', 'life', 'w', 'variant', 'col'];
const PART = ['type', 'x', 'y', 'vx', 'vy', 'life', 'age', 'grav', 'drag', 'size', 'col', 'r', 'gr', 'face'];
const FLOAT = ['x', 'y', 'txt', 't', 'col'];

// Emits every leaf in a fixed order. `out` is an array (values) or null; `paths` is an array when a caller wants the path of
// each value (only used to explain a mismatch). Types are tagged so that null, 0, false and '' never collide.
function walker(out, paths) {
  const stack = [];
  const at = k => paths && stack.push(k);
  const up = () => paths && stack.pop();
  const leaf = v => {
    if (v === undefined) v = null;                         // prototype leaves some fields undefined where the port has null
    out.push(v); if (paths) paths.push(stack.join('.'));
  };
  const obj = (o, fields, name) => { at(name); if (o == null) leaf(null); else for (const k of fields) { at(k); leaf(o[k]); up(); } up(); };
  return { at, up, leaf, obj };
}

// src: {T, rngState, rngFxState, game:{ko,koT,ts,seed,clash}, banner, shake, dirS, fighters, world, buildings, trees, deform,
//       beams, parts, floats, beatDetail}
export function collect(src, lane, out = [], paths = null) {
  const w = walker(out, paths), fs = src.fighters, idx = f => (f == null ? -1 : fs.indexOf(f));
  if (lane === 'presentation') {
    w.at('rngFx'); w.leaf(src.rngFxState); w.up();
    w.at('shake'); w.leaf(src.shake); w.up();
    w.obj(src.banner, ['text', 'col', 't', 'dur'], 'banner');
    w.at('floats'); w.leaf(src.floats.length); src.floats.forEach((f, i) => w.obj(f, FLOAT, i)); w.up();
    w.at('parts'); w.leaf(src.parts.length); src.parts.forEach((p, i) => w.obj(p, PART, i)); w.up();
    return out;
  }
  w.at('T'); w.leaf(src.T); w.up();
  w.at('rng'); w.leaf(src.rngState); w.up();
  const g = src.game;
  w.at('game'); w.at('ko'); w.leaf(idx(g.ko)); w.up();
  w.obj(g, ['koT', 'ts', 'seed'], 'v');
  w.at('clash'); if (g.clash) { w.leaf(idx(g.clash.A)); w.leaf(idx(g.clash.D)); w.obj(g.clash, ['t0', 'dur', 'aw'], 'v'); } else w.leaf(null); w.up();
  w.up();
  const d = src.dirS;
  w.at('dirS'); w.obj(d, ['cool', 'stop', 'lastLaunch'], 'v'); w.at('lastLaunch2'); w.leaf(d.lastLaunch2 === undefined ? '' : d.lastLaunch2); w.up();
  const ex = d.ex;
  w.at('ex');
  if (ex) {
    w.at('A'); w.leaf(idx(ex.A)); w.up(); w.at('D'); w.leaf(idx(ex.D)); w.up();
    w.obj(ex, ['kind', 't', 'combo', 'tag', 'windowStart', 'cancel'], 'v');
    w.obj(ex.ext, ['start', 'until'], 'ext');
    w.at('beats'); w.leaf(ex.beats.length);
    ex.beats.forEach((b, i) => { w.obj(b, ['t', 'done'], i); if (src.beatDetail) { w.at(i); w.leaf(b.op); w.leaf(JSON.stringify(b.args)); w.up(); } });
    w.up();
  } else w.leaf(null);
  w.up(); w.up();
  fs.forEach((f, i) => {
    w.at('f' + i);
    w.obj(f, FIGHTER, 'v');
    w.at('rush'); const r = f.rush;
    if (!r) w.leaf(null); else if (r.tgt) { w.leaf('tgt'); w.leaf(idx(r.tgt)); w.leaf(r.off); w.leaf(r.end); } else { w.leaf('pt'); w.leaf(r.px); w.leaf(r.py); w.leaf(r.end); }
    w.up();
    w.at('launchBy'); w.leaf(idx(f.launchBy)); w.up();
    w.obj(f.ai, ['t', 'atk', 'sT', 'sOff'], 'ai');
    w.obj(f.lastSeen, ['x', 'y'], 'lastSeen');
    w.obj(f.in, INTENT, 'in');
    w.up();
  });
  w.obj(src.world, ['pop0', 'casualties', 'structuresLost', 'craters'], 'world');
  w.at('buildings'); w.leaf(src.buildings.length); src.buildings.forEach((b, i) => w.obj(b, BUILDING, i)); w.up();
  w.at('trees'); w.leaf(src.trees.length); src.trees.forEach((t, i) => w.obj(t, TREE, i)); w.up();
  w.at('beams'); w.leaf(src.beams.length); src.beams.forEach((b, i) => { w.at(i); w.leaf(idx(b.A)); w.up(); w.obj(b, BEAM, i); }); w.up();
  w.at('deform'); for (let i = 0; i < src.deform.length; i++) { w.at(i); w.leaf(src.deform[i]); w.up(); } w.up();
  return out;
}

export function hashValues(vals) {
  const h = new Hasher();
  for (const v of vals) {
    if (typeof v === 'number') { h.u(1); h.num(v); } else if (typeof v === 'string') { h.u(2); h.str(v); }
    else if (typeof v === 'boolean') h.u(v ? 4 : 3); else h.u(5);
  }
  return h.hex();
}

// First index where two value lists differ (Object.is, so -0 against 0 and NaN count), or -1.
export function firstDiff(a, b) {
  const n = Math.max(a.length, b.length);
  for (let i = 0; i < n; i++) if (!Object.is(a[i], b[i])) return i;
  return -1;
}

// Path of the i-th value of a lane, for error messages.
export function pathAt(src, lane, i) { const paths = []; collect(src, lane, [], paths); return paths[i] || '(past end)'; }

export function portSrc(S, beatDetail = true) {
  return { T: S.T, rngState: S.rng.a | 0, rngFxState: S.rngFx === S.rng ? null : S.rngFx.a | 0, game: S.game, banner: S.fx.banner, shake: S.fx.shake,
    dirS: S.dirS, fighters: S.fighters, world: S.world, buildings: S.buildings, trees: S.trees, deform: S.deform, beams: S.beams,
    parts: S.fx.parts, floats: S.fx.floats, beatDetail };
}

// Hash of the whole port state, one hex string per lane (replay checkpoints use the gameplay lane).
export function stateHash(S) {
  const src = portSrc(S);
  return { gameplay: hashValues(collect(src, 'gameplay')), presentation: hashValues(collect(src, 'presentation')) };
}
