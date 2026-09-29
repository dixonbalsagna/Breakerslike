// Seeded single-match runner for the browser prototype, shared by sim-stats.js and the qa/ suite.
// Runs one AI-vs-AI match headlessly and returns a plain record: outcome, collateral, director events parsed from
// the feed, a per-step state hash for determinism checks, and seam/NaN observations.
// Node built-ins only. Deterministic: the record depends only on (seed, arm), never on wall-clock time.
const { load } = require('./headless');

const DT = 1 / 60;
const W = 9600, HALF = W / 2;                 // world width; must match the prototype
const MAX_STEPS = 60 * 300;                   // same hard cap sim-stats has always used
const KO_TAIL = 3;                            // sim-seconds of KO tail sim-stats waits for after the KO
// Biome table, copied from SEG in prototype/index.html (qa/tests/tables.test.js fails if the two drift apart).
const SEG = [[0, 1200, 'ocean'], [1200, 1800, 'village'], [1800, 2350, 'plains'], [2350, 3850, 'city'], [3850, 4500, 'village'], [4500, 5500, 'forest'], [5500, 6500, 'desert'], [6500, 7600, 'mountains'], [7600, 8000, 'village'], [8000, 8300, 'plains'], [8300, 9600, 'ocean']];
const biomeAt = x => { for (const s of SEG) if (x >= s[0] && x < s[1]) return s[2]; return 'plains'; };
const sdx = (a, b) => { let d = (b - a) % W; if (d > HALF) d -= W; else if (d < -HALF) d += W; return d; };

// ---- hashing: two 32-bit lanes over the raw IEEE-754 bits of every value (exact, order sensitive)
const f64 = new Float64Array(1), u32 = new Uint32Array(f64.buffer);
class Hasher {
  constructor() { this.a = 0x811c9dc5 | 0; this.b = 0x9e3779b9 | 0; }
  u(w) { this.a = Math.imul(this.a ^ w, 16777619); let b = Math.imul((this.b ^ w) + 0x7f4a7c15 | 0, 0x85ebca6b); this.b = b ^ (b >>> 13); }
  num(x) { f64[0] = x; this.u(u32[0]); this.u(u32[1]); }
  str(s) { for (let i = 0; i < s.length; i++) this.u(s.charCodeAt(i)); this.u(0xff); }
  hex() { return (this.a >>> 0).toString(16).padStart(8, '0') + (this.b >>> 0).toString(16).padStart(8, '0'); }
}
const STATE_ID = { free: 1, locked: 2, launched: 3, down: 4, charging: 5 };

// ---- arms: which character sits in which slot. Used to separate slot bias from character bias.
const CHAR_KEYS = ['name', 'title', 'role', 'col', 'aura', 'hair', 'care', 'dmgMul', 'spd', 'maxhp', 'sigName'];
const pick = f => Object.fromEntries(CHAR_KEYS.map(k => [k, f[k]]));
const put = (f, c) => { Object.assign(f, c); f.hp = f.maxhp; };
const SPAWN = [2150, 2900];                                          // P1 and P2 start x in newMatch()
const flipSpawn = fs => { fs[0].x = SPAWN[1]; fs[1].x = SPAWN[0]; fs[0].face = -1; fs[1].face = 1; };   // P1 starts east, P2 west
const ARMS = {
  'default': () => {},                                              // KAI in P1 (west spawn), VORR in P2 (east spawn): the shipped setup
  'swap': fs => { const a = pick(fs[0]), b = pick(fs[1]); put(fs[0], b); put(fs[1], a); },   // VORR in P1, KAI in P2
  'mirror-villain': fs => { const v = pick(fs[1]); put(fs[0], { ...v, name: v.name + '-A' }); put(fs[1], { ...v, name: v.name + '-B' }); },
  'mirror-hero': fs => { const k = pick(fs[0]); put(fs[0], { ...k, name: k.name + '-A' }); put(fs[1], { ...k, name: k.name + '-B' }); },
};
// Same four, with the spawn sides exchanged. Separates "which slot" from "which side of the map you start on".
for (const a of ['default', 'swap', 'mirror-villain', 'mirror-hero']) ARMS[a + '-flip'] = fs => { ARMS[a](fs); flipSpawn(fs); };

// ---- harness: one loaded prototype instance, reused across matches
function createHarness(opts) {
  const { wf, feedLog, listeners, bind } = load(opts);
  return { wf, feedLog, listeners, bind };
}

const STANCES = ['AGGRESSIVE', 'DEFENSIVE', 'EVASIVE', 'ESCAPE'];
const NUMERIC = ['x', 'y', 'vx', 'vy', 'hp', 'ki', 'power', 'menace', 'anguish', 'rot', 'spin'];

// Run one match. seed === undefined keeps the prototype's time-based seeding (non-reproducible).
function runMatch(h, seed, opt = {}) {
  const { wf, feedLog } = h;
  if (h.bind) h.bind();                              // several harnesses can coexist; make this one the live one
  const arm = opt.arm || 'default';
  if (!ARMS[arm]) throw new Error('unknown arm ' + arm);
  wf.game.paused = false;                            // newMatch() leaves the pause flag alone; steps ignore it anyway
  feedLog.length = 0;
  if (seed === undefined) wf.newMatch(); else wf.newMatch(seed);
  const fs = wf.fighters();
  ARMS[arm](fs);
  if (opt.setup) opt.setup(fs, wf);                  // scenario hook: reposition fighters, force state, etc.
  const slotOf = {}; fs.forEach((f, i) => { slotOf[f.name] = i; });
  const startNames = fs.map(f => f.name);

  const hs = new Hasher();
  const rec = {
    seed: wf.game.seed, arm, names: startNames,
    launches: {}, melee: {}, beams: [], attacks: { light: 0, heavy: 0, sig: 0 }, ambush: 0,
    atkMatrix: {},                       // "ATT-STANCE>DEF-STANCE kind tag" -> count, for director coverage
    parries: [0, 0], chains: [], hides: [0, 0], found: 0, tierUps: [0, 0], counters: 0, unparsed: {},
    hiddenSec: [0, 0], stanceSec: [[0, 0, 0, 0], [0, 0, 0, 0]], biomeSec: {},
    seamCrossings: 0, maxDisp: 0, xBad: 0, violations: [], nan: null, koAt: null, koWinner: null,
  };
  const bs0 = wf.buildings(), w0 = wf.world();
  let prevCas = 0, prevStr = 0; const prevBhp = bs0.map(b => b.hp), prevAlive = bs0.map(b => b.alive);
  const violate = msg => { if (rec.violations.length < 5) rec.violations.push(msg + ' @' + wf.T().toFixed(2)); };
  let fi = 0, prevT = 0;
  const prevX = fs.map(f => f.x);
  let steps = 0;

  const onFeed = e => {
    const [, tag, sub] = e;
    let m;
    if ((m = /^([A-Z][A-Z0-9-]*) (LIGHT|HEAVY|SIG) vs (\w+)$/.exec(tag))) {
      const slot = slotOf[m[1]], kind = m[2].toLowerCase(), ds = m[3], amb = /\(ambush\)\s*$/.test(sub || '');
      rec.attacks[kind]++; if (amb) rec.ambush++;
      const as = STANCES[fs[slot].stance];
      if (kind === 'sig') {
        const b = /^(.+) over (\w+) \((.+)\) → (\w+)/.exec(sub || '');
        if (b) { rec.beams.push({ by: slot, bio: b[2], variant: b[3], out: b[4], amb }); rec.atkMatrix[as + '>' + ds + ' sig ' + b[4]] = (rec.atkMatrix[as + '>' + ds + ' sig ' + b[4]] || 0) + 1; }
      } else {
        const full = (sub || '').replace(/\s*\(ambush\)\s*$/, '');
        const base = full.replace(/ → COUNTER$/, '');
        if (base !== full) rec.counters++;
        rec.melee[base] = (rec.melee[base] || 0) + 1;
        const k = as + '>' + ds + ' ' + kind + ' ' + base;
        rec.atkMatrix[k] = (rec.atkMatrix[k] || 0) + 1;
      }
    } else if ((m = /^LAUNCH: (.+)$/.exec(tag))) rec.launches[m[1]] = (rec.launches[m[1]] || 0) + 1;
    else if ((m = /^([A-Z][A-Z0-9-]*) PARRIES$/.exec(tag))) rec.parries[slotOf[m[1]]]++;
    else if ((m = /^CHAIN x(\d+) ended$/.exec(tag))) rec.chains.push(+m[1]);
    else if ((m = /^([A-Z][A-Z0-9-]*) goes to ground$/.exec(tag))) rec.hides[slotOf[m[1]]]++;
    else if (/^[A-Z][A-Z0-9-]* found$/.test(tag)) rec.found++;
    else if ((m = /^([A-Z][A-Z0-9-]*) reaches tier (\d)$/.exec(tag))) rec.tierUps[slotOf[m[1]]] = Math.max(rec.tierUps[slotOf[m[1]]], +m[2]);
    else if (!/^K\.O\. — /.test(tag)) rec.unparsed[tag] = (rec.unparsed[tag] || 0) + 1;    // feed lines this parser does not know
  };

  const game = wf.game;
  while (steps < MAX_STEPS && !(game.ko && game.koT > KO_TAIL)) {
    wf.step(DT); steps++;
    const T = wf.T(), dT = T - prevT; prevT = T;
    if (game.ko && rec.koAt === null) { rec.koAt = T; rec.koWinner = fs.findIndex(f => f !== game.ko); }
    for (let i = 0; i < 2; i++) {
      const f = fs[i];
      for (const k of NUMERIC) if (!Number.isFinite(f[k])) { rec.nan = { fighter: f.name, key: k, t: T }; break; }
      if (rec.nan) break;
      const raw = Math.abs(f.x - prevX[i]);
      if (raw > HALF) rec.seamCrossings++;
      const disp = Math.abs(sdx(prevX[i], f.x));
      if (disp > rec.maxDisp) rec.maxDisp = disp;
      prevX[i] = f.x;
      if (f.x < 0 || f.x >= W) rec.xBad++;
      if (opt.invariants) {
        if (f.ki < 0 || f.ki > 100) violate(f.name + ' ki ' + f.ki);
        if (f.power < 0 || f.power > 100) violate(f.name + ' power ' + f.power);
        if (f.hp > f.maxhp + 1e-9) violate(f.name + ' hp above max');
        if (f.y > 2600) violate(f.name + ' y ' + f.y);
      }
      if (f.hidden) rec.hiddenSec[i] += dT;
      const bm = biomeAt(f.x); rec.biomeSec[bm] = (rec.biomeSec[bm] || 0) + dT;
      rec.stanceSec[i][f.stance] += dT;
      for (const k of NUMERIC) hs.num(f[k]);
      hs.u(f.tier); hs.u(f.stance); hs.u(STATE_ID[f.state] || 9); hs.u(f.hidden ? 1 : 0);
    }
    if (rec.nan) break;
    if (opt.invariants) {
      const w = wf.world();
      if (w.casualties < prevCas - 1e-9) violate('casualties went down'); if (w.casualties > w.pop0 * (1 + 1e-9)) violate('casualties above population');
      if (w.structuresLost < prevStr) violate('structures lost went down'); if (w.structuresLost > bs0.length) violate('structures lost above total');
      prevCas = w.casualties; prevStr = w.structuresLost;
      for (let b = 0; b < bs0.length; b++) {
        if (bs0[b].hp > prevBhp[b] + 1e-9) violate('building ' + b + ' hp went up'); if (!prevAlive[b] && bs0[b].alive) violate('building ' + b + ' came back');
        prevBhp[b] = bs0[b].hp; prevAlive[b] = bs0[b].alive;
      }
    }
    const c = wf.cam; if (!Number.isFinite(c.x + c.y + c.z)) { rec.nan = { fighter: 'camera', key: 'xyz', t: T }; break; }
    while (fi < feedLog.length) onFeed(feedLog[fi++]);
  }
  while (fi < feedLog.length) onFeed(feedLog[fi++]);

  const w = wf.world(), bs = wf.buildings();
  rec.steps = steps; rec.len = wf.T();
  if (rec.koAt === null) rec.koAt = rec.len;            // timeout: no KO
  rec.timeout = !game.ko;
  rec.winner = game.ko ? rec.koWinner : -1;
  rec.pop0 = w.pop0; rec.casualties = w.casualties; rec.civPct = w.casualties / w.pop0;
  rec.structs = w.structuresLost; rec.nStructs = bs.length; rec.craters = w.craters;
  rec.finalHp = fs.map(f => f.hp);
  // fold end-of-match world state and the whole feed into the hash
  hs.num(w.casualties); hs.num(w.structuresLost); hs.num(w.craters); hs.num(steps);
  for (const b of bs) { hs.num(b.hp); hs.u(b.alive ? 1 : 0); }
  for (const e of feedLog) { hs.str(e[0]); hs.str(e[1]); hs.str(e[2] || ''); }
  rec.hash = hs.hex();
  return rec;
}

module.exports = { createHarness, runMatch, Hasher, ARMS, SPAWN, STANCES, SEG, biomeAt, sdx, W, HALF, DT, KO_TAIL };
