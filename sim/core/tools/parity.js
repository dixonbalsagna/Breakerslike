#!/usr/bin/env node
// Parity: proves the port reproduces the prototype (prototype/index.html, pinned at 7233c96). One command:
//   node sim/core/tools/parity.js [--quick] [--arm=NAME] [--seeds=N]
// Stages
//   probe     the instrumented prototype (proto-harness.js) gives the same QA hashes as the plain one: the probes are inert
//   lockstep  prototype and port step side by side; after every tick the whole state is compared field by field: the
//             gameplay lane, the presentation lane (damage numbers, banner, shake: particles use their own cosmetic
//             streams since the QA-002 split), the camera, and the feed lines of that tick. The port runs in
//             prototype-parity mode ({math: 'native', fxRng: 'shared'}). Stops at the first difference and prints where it is.
//   keys      scripted key presses on both (P1 human, both human, AI toggled mid-match): the input layer and the
//             human-only paths of the director, which AI-vs-AI matches never reach
//   records   QA's own runMatch (invariants on) gives JSON-identical records on both, so every QA statistic agrees
//   golden    the port reproduces qa/golden-hashes.json
// Default plan: arm 'default' seeds 1..100, every other arm seeds 1..10. Exit 0 only if every stage passes.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { QA, ROOT, createProtoHarness, createPlainHarness, protoSrc, protoCam } from './proto-harness.js';
import { createPortHarness } from './port-harness.js';
import { collect, hashValues, firstDiff, pathAt, portSrc, Hasher } from '../hash.js';
import { DT } from '../constants.js';

const MAX_STEPS = 60 * 300, KO_TAIL = QA.KO_TAIL;        // runMatch's stop rule
const ARM_NAMES = Object.keys(QA.ARMS);

export function plan({ quick = false, arm = null, seeds = null } = {}) {
  const out = [];
  for (const a of arm ? [arm] : ARM_NAMES) {
    const n = seeds || (a === 'default' ? (quick ? 12 : 100) : (quick ? 2 : 10));
    for (let s = 1; s <= n; s++) out.push([a, s]);
  }
  return out;
}

// Mirrors runMatch's setup on either harness. The prototype carries cosmetic camera shake into the next match (the port
// resets it, module-spec section 7), so the prototype's is zeroed first.
function setup(h, arm, seed) {
  if (h.bind) h.bind();
  h.wf.game.paused = false;
  h.feedLog.length = 0;
  if (h.wf.__int) h.wf.cam.shake = 0;
  h.wf.newMatch(seed);
  QA.ARMS[arm](h.wf.fighters());
}

const LANES = ['gameplay', 'presentation'];
// Particles are left out: since the QA-002 split the port's come from their own cosmetic streams. Banner, damage numbers
// and shake are deterministic and still compared.
function compareTick(P, Q, arm, seed, tick, feedFrom) {
  const ps = protoSrc(P), qs = portSrc(Q.S, false, Q.V);
  ps.parts = null; qs.parts = null;
  for (const lane of LANES) {
    const a = collect(ps, lane), b = collect(qs, lane), i = firstDiff(a, b);
    if (i >= 0) return { lane, path: pathAt(ps, lane, i), proto: a[i], port: b[i], a };
  }
  const pc = protoCam(P), qc = Q.cam;
  for (const k of ['x', 'y', 'z']) if (!Object.is(pc[k], qc[k])) return { lane: 'camera', path: 'cam.' + k, proto: pc[k], port: qc[k] };
  const pf = P.feedLog.slice(feedFrom), qf = Q.feedLog.slice(feedFrom);
  if (JSON.stringify(pf) !== JSON.stringify(qf)) return { lane: 'feed', path: 'feed', proto: JSON.stringify(pf), port: JSON.stringify(qf) };
  return null;
}

// One match in lockstep. Returns {ticks, digest} or throws with the first difference.
export function lockstep(P, Q, arm, seed, { beforeTick = null, maxSteps = MAX_STEPS } = {}) {
  setup(P, arm, seed); setup(Q, arm, seed);
  const digest = new Hasher();
  let steps = 0;
  const check = feedFrom => {
    const d = compareTick(P, Q, arm, seed, steps, feedFrom);
    if (d) {
      const e = new Error(`parity: ${arm} seed ${seed} differs at tick ${steps} (T=${P.wf.T()}), ${d.lane} lane, ${d.path}: prototype ${fmt(d.proto)} vs port ${fmt(d.port)}`);
      e.detail = d; throw e;
    }
    digest.str(hashValues(collect(portSrc(Q.S, false), 'gameplay')));
  };
  const g = P.wf.game;
  check(0);
  while (steps < maxSteps && !(g.ko && g.koT > KO_TAIL)) {
    if (beforeTick) beforeTick(steps);
    const feedFrom = P.feedLog.length;
    P.wf.step(DT); Q.wf.step(DT); steps++;
    check(feedFrom);
  }
  const qg = Q.wf.game;
  if (!(qg.ko && qg.koT > KO_TAIL) && steps < maxSteps) throw new Error(`parity: ${arm} seed ${seed}: the prototype stopped at tick ${steps} but the port would not`);
  return { ticks: steps, digest: digest.hex() };
}
// Scripted players for the keyboard stage: the same key events go to the prototype's listeners and the port harness's.
// Its own mulberry32 stream, so the script is fixed. Keys are pressed and released at random, auto-repeat events are
// mixed in, and T/Y (toggle P2/P1 AI) are pressed now and then. N (new match with a clock seed) is never pressed.
const P1KEYS = ['KeyA', 'KeyD', 'KeyW', 'KeyS', 'Space', 'KeyF', 'KeyG', 'KeyR', 'KeyQ', 'Digit1', 'Digit2', 'Digit3', 'Digit4'];
const P2KEYS = ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Enter', 'Comma', 'Period', 'Slash', 'Semicolon', 'Digit7', 'Digit8', 'Digit9', 'Digit0'];
const PRESS = { KeyQ: 0.004, Semicolon: 0.004, KeyF: 0.03, Comma: 0.03, KeyG: 0.02, Period: 0.02, KeyR: 0.01, Slash: 0.01 };
function keyScript(seed, keys, toggles) {
  let a = seed >>> 0;
  const rnd = () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
  const down = new Set();
  return tick => {
    const ev = [];
    for (const k of keys) {
      if (down.has(k)) { if (rnd() < 0.12) { down.delete(k); ev.push(['keyup', k, false]); } else if (rnd() < 0.05) ev.push(['keydown', k, true]); }
      else if (rnd() < (PRESS[k] || (k.startsWith('Digit') ? 0.004 : 0.04))) { down.add(k); ev.push(['keydown', k, false]); }
    }
    if (toggles && tick > 0 && tick % 900 === 0) ev.push(['keydown', rnd() < 0.5 ? 'KeyT' : 'KeyY', false], ['keyup', 'KeyT', false], ['keyup', 'KeyY', false]);
    return ev;
  };
}
const send = (h, [type, code, repeat]) => { for (const fn of h.listeners[type] || []) fn({ code, repeat, metaKey: false, ctrlKey: false, preventDefault() {} }); };
export const KEY_SCENARIOS = [
  { name: 'P1 human (takeover on first key) vs AI', seeds: [1, 2, 3, 4, 5, 6], keys: P1KEYS, both: false, toggles: false },
  { name: 'both human', seeds: [7, 8, 9], keys: [...P1KEYS, ...P2KEYS], both: true, toggles: false },
  { name: 'human with AI toggles (T/Y) mid-match', seeds: [10, 11, 12], keys: [...P1KEYS, ...P2KEYS], both: false, toggles: true },
];
// Directed: the one branch random play never reached. P1 presses light while P2 is (set) hidden, so the attack meets
// requestAttack's lock-lost branch (ki cost, cooldown, the human-only banner).
KEY_SCENARIOS.push({ name: 'human attacks a hidden opponent (lock lost)', seeds: [13], directed: true });
function lockLostScript(P, Q) {
  return tick => {
    if (tick % 45 === 0) { for (const h of [P, Q]) { h.wf.fighters()[1].hidden = true; } return [['keydown', 'KeyF', false]]; }
    if (tick % 45 === 1) return [['keyup', 'KeyF', false]];
    return [];
  };
}
export function keyLockstep(sc, seed, { P = createProtoHarness(), Q = createPortHarness() } = {}) {
  const script = sc.directed ? lockLostScript(P, Q) : keyScript(seed * 7919 + (sc.both ? 1 : 0) + (sc.toggles ? 2 : 0), sc.keys, sc.toggles);
  let primed = false;
  return lockstep(P, Q, 'default', seed, { maxSteps: sc.directed ? 1200 : 7200, beforeTick: tick => {
    if (!primed) { primed = true; if (sc.both) for (const h of [P, Q]) send(h, ['keydown', 'KeyT', false]), send(h, ['keyup', 'KeyT', false]); }
    for (const e of script(tick)) { send(P, e); send(Q, e); }
  } });
}

const fmt = v => (typeof v === 'number' ? (Object.is(v, -0) ? '-0' : String(v)) : JSON.stringify(v));

function readGolden() {
  const file = path.join(ROOT, 'qa', 'golden-hashes.json');
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}
const major = v => String(v).replace(/^v/, '').split('.')[0];

export function run(opts = {}, log = console.log) {
  const t = {}, clock = () => performance.now();
  const matches = plan(opts);
  let failures = 0;
  const stage = (name, fn) => { const t0 = clock(); try { fn(); } catch (e) { failures++; log(`FAIL  ${name}: ${e.message}`); } t[name] = (clock() - t0) / 1000; };

  stage('probe', () => {
    const probe = createProtoHarness(), plain = createPlainHarness();
    for (const [arm, s] of [['default', 1], ['default', 2], ['swap', 3], ['mirror-hero', 4]]) {
      const a = QA.runMatch(plain, s, { arm }).hash, b = QA.runMatch(probe, s, { arm }).hash;
      if (a !== b) throw new Error(`instrumented prototype differs from the plain one: ${arm} seed ${s} ${a} vs ${b}`);
    }
    log('ok    probe: the instrumented prototype matches the plain one (4 matches)');
  });

  let ticks = 0;
  const run = new Hasher();
  stage('lockstep', () => {
    const P = createProtoHarness(), Q = createPortHarness();
    for (const [arm, s] of matches) {
      const r = lockstep(P, Q, arm, s);
      ticks += r.ticks; run.str(r.digest);
      if (opts.verbose) log(`      ${arm.padEnd(20)} seed ${String(s).padStart(4)}  ticks ${String(r.ticks).padStart(6)}  ${r.digest}`);
    }
    log(`ok    lockstep: ${matches.length} matches, ${ticks} ticks, every tick identical (gameplay, banner, damage numbers, shake, camera, feed); digest ${run.hex()}`);
  });

  stage('keys', () => {
    let n = 0, kt = 0;
    for (const sc of KEY_SCENARIOS) for (const s of opts.quick ? sc.seeds.slice(0, 1) : sc.seeds) { kt += keyLockstep(sc, s).ticks; n++; }
    ticks += kt;
    log(`ok    keys: ${n} matches driven by scripted key events (${kt} ticks), every tick identical`);
  });

  stage('records', () => {
    const P = createProtoHarness(), Q = createPortHarness();
    for (const [arm, s] of matches) {
      const a = QA.runMatch(P, s, { arm, invariants: true }), b = QA.runMatch(Q, s, { arm, invariants: true });
      if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`QA record differs: ${arm} seed ${s}: prototype hash ${a.hash} vs port ${b.hash}`);
      if (a.violations.length || a.nan) throw new Error(`invariant broken in ${arm} seed ${s}: ${a.violations.join('; ') || JSON.stringify(a.nan)}`);
    }
    log(`ok    records: QA runMatch records identical for ${matches.length} matches`);
  });

  stage('golden', () => {
    const g = readGolden();
    if (major(g.node) !== major(process.version)) { log(`skip  golden: recorded on Node ${g.node}, running ${process.version}`); return; }
    const Q = createPortHarness();
    const bad = [];
    for (const [key, want] of Object.entries(g.entries)) {
      const i = key.lastIndexOf(':'), arm = key.slice(0, i), s = +key.slice(i + 1);
      const got = QA.runMatch(Q, s, { arm }).hash;
      if (got !== want) bad.push(`${key} ${got} (want ${want})`);
    }
    if (bad.length) throw new Error('port does not reproduce golden hashes: ' + bad.join(', '));
    log(`ok    golden: ${Object.keys(g.entries).length} golden hashes reproduced by the port`);
  });

  log(`time  ` + Object.entries(t).map(([k, v]) => `${k} ${v.toFixed(1)}s`).join('   '));
  return { failures, matches: matches.length, ticks };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2), val = k => { const a = args.find(x => x.startsWith('--' + k + '=')); return a ? a.split('=')[1] : null; };
  console.log(`Meridian parity: port vs prototype/index.html   node ${process.version}`);
  const r = run({ quick: args.includes('--quick'), arm: val('arm'), seeds: val('seeds') ? +val('seeds') : null, verbose: args.includes('--verbose') });
  console.log(r.failures ? `\nparity FAILED` : `\nparity passed`);
  process.exit(r.failures ? 1 : 0);
}
