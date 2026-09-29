// Scripted scenarios that reproduce the reported prototype bugs (see qa/known-bugs.md). Each returns a plain
// observation object; qa/tests/known-bugs.test.js turns those into "the bug is still present" assertions.
// Scenarios drive real key events through the prototype's own input handlers, so they exercise the shipped code path.
// Fighter 0 is P1 (KAI, keys F G R Q), fighter 1 is P2 (VORR, keys , . / ;). Both are human-controlled and idle
// unless a scenario presses a key.
const { sdx, DT } = require('../../prototype/tools/match-runner');

const KEYS = { p1: { light: 'KeyF', heavy: 'KeyG', sig: 'KeyR', charge: 'KeyQ' }, p2: { light: 'Comma', heavy: 'Period', sig: 'Slash', charge: 'Semicolon' } };
const TIER_POWER = [0, 26, 51, 76];                                   // power at which the prototype's tier formula gives tier 1..4

// Start seed `seed` on harness `h` with both fighters human and idle, spawned at the given x and altitude.
function sceneOn(h, seed, { ax = 2500, bx = 3400, y = 60 } = {}) {
  h.bind(); h.feedLog.length = 0;
  const wf = h.wf; wf.game.paused = false;
  wf.newMatch(seed);
  const [a, b] = wf.fighters();
  if (a.ai) wf.toggleAI(0);
  if (b.ai) wf.toggleAI(1);
  a.x = ax; b.x = bx; a.y = b.y = y; a.face = 1; b.face = -1;
  const key = (type, code) => { for (const fn of h.listeners[type] || []) fn({ code, preventDefault() {}, repeat: false, metaKey: false, ctrlKey: false }); };
  const s = {
    h, wf, a, b, feed: h.feedLog,
    tap(code) { key('keydown', code); key('keyup', code); },
    hold(code) { key('keydown', code); },
    release(code) { key('keyup', code); },
    step(n = 1) { for (let i = 0; i < n; i++) wf.step(DT); },
    stepUntil(cond, max = 300) { let i = 0; while (!cond() && i++ < max) wf.step(DT); return cond(); },
    waitCool() { s.stepUntil(() => wf.dirS.cool <= 0, 200); },          // the director will not take a request for the first 0.6 s
    lastFeed(re) { for (let i = s.feed.length - 1; i >= 0; i--) if (re.test(s.feed[i][1])) return s.feed[i]; return null; },
  };
  return s;
}
const setTier = (f, t) => { f.tier = t; f.power = TIER_POWER[t - 1]; };

// ---- KB-001: signature against an ESCAPE defender. Returns how often the beam HIT, for a given tier pairing.
function beamVsEscape(h, { aTier, dTier, dist = 1000, trials = 500, base = 1 }) {
  let hit = 0, escaped = 0;
  for (let i = 0; i < trials; i++) {
    const s = sceneOn(h, base + i, { bx: 2500 + dist });
    setTier(s.a, aTier); setTier(s.b, dTier);
    s.b.stance = 3; s.a.ki = 100;
    s.waitCool(); s.tap(KEYS.p1.sig); s.step(1);
    const e = s.lastFeed(/ SIG vs ESCAPE$/);
    if (!e) throw new Error(`KB-001 scenario: no signature was requested (seed ${base + i})`);
    const out = /→ (\w+)/.exec(e[2] || '')[1];
    if (out === 'HIT') hit++; else if (out === 'ESCAPE') escaped++;
  }
  return { hit, escaped, n: trials, rate: hit / trials, tierGap: aTier - dTier };
}

// ---- KB-002: damage against a charging defender. Returns the defender's state after the request and the first hit's damage.
function chargingStrike(h, kind, seed = 1) {
  const s = sceneOn(h, seed);
  s.b.stance = 0; s.a.ki = 100;
  s.hold(KEYS.p2.charge); s.step(2);
  const before = s.b.state;
  s.waitCool();
  const stateWhileWaiting = s.b.state;
  s.tap(KEYS.p1[kind]); s.step(1);
  const stateAfterRequest = s.b.state, dPrev = s.b.dPrev, tag = (s.lastFeed(/ vs CHARGING$/) || [])[2] || null;
  const hp0 = s.b.hp, aHp0 = s.a.hp;
  const hitStep = s.stepUntil(() => s.b.hp < hp0, 200);
  s.release(KEYS.p2.charge);
  return { chargingBefore: before === 'charging' && stateWhileWaiting === 'charging', stateAfterRequest, dPrev, tag, dmg: hitStep ? hp0 - s.b.hp : null, attackerFullHp: aHp0 === s.a.maxhp && s.a.tier === 1 };
}

// ---- KB-003: a parried exchange still opens a chain window. Searches seeds for a parry followed by a window, then chains.
// Returns { parries, windows, result }: how many seeds parried, how many of those offered a window, and the chain observation.
function parryThenChain(h, seedFrom = 1, seedTo = 60) {
  let parries = 0, windows = 0;
  for (let seed = seedFrom; seed <= seedTo; seed++) {
    const s = sceneOn(h, seed);
    s.b.stance = 1; s.a.ki = 100; s.b.ki = 60;
    s.waitCool(); s.tap(KEYS.p1.light);
    if (!s.stepUntil(() => s.wf.dirS.ex && s.wf.dirS.ex.windowStart >= 0, 120)) continue;
    s.tap(KEYS.p2.light);                                              // defender presses attack inside the wind-up: a parry
    if (!s.stepUntil(() => s.lastFeed(/PARRIES$/), 60)) continue;
    const ex = s.wf.dirS.ex;
    if (!ex || !ex.cancel) continue;
    parries++;
    if (!s.stepUntil(() => ex.ext, 120)) continue;                    // does the cancelled exchange still offer a chain window?
    windows++;
    const ki0 = s.a.ki, hp0 = s.b.hp;
    s.tap(KEYS.p1.light); s.step(1);
    const combo = ex.combo, banner = s.wf.game.banner && s.wf.game.banner.text, kiAfter = s.a.ki;
    s.stepUntil(() => !s.wf.dirS.ex, 300);
    const chainLine = s.lastFeed(/^CHAIN x\d+ ended$/);
    return { parries, windows, result: { seed, cancelled: ex.cancel, combo, banner, kiSpent: ki0 - kiAfter, defenderHpLoss: hp0 - s.b.hp, chainLine: chainLine && chainLine[1] } };
  }
  return { parries, windows, result: null };
}

// ---- KB-004: the chain strike after GUARD HOLDS. Returns damage of each guarded strike and of the chain strike.
function guardChain(h, seedFrom = 1, seedTo = 60) {
  for (let seed = seedFrom; seed <= seedTo; seed++) {
    const s = sceneOn(h, seed);
    s.b.stance = 1; s.a.ki = 100; s.b.ki = 60;
    s.waitCool(); s.tap(KEYS.p1.light); s.step(1);
    const tag = (s.lastFeed(/ LIGHT vs DEFENSIVE$/) || [])[2] || '';
    if (!/^PRESSURE — GUARD HOLDS\s*$/.test(tag)) continue;           // skip the seeds where the defender counters instead
    const ex = s.wf.dirS.ex;
    const drops = []; let last = s.b.hp, chainStep = null;
    const watch = () => { if (s.b.hp < last - 1e-9) drops.push({ dmg: last - s.b.hp, afterChain: chainStep !== null }); last = s.b.hp; };
    if (!s.stepUntil(() => { watch(); return ex.ext; }, 200)) continue;
    s.tap(KEYS.p1.light); s.step(1); watch();
    if (ex.combo < 2) continue;
    chainStep = 0;
    for (let i = 0; i < 90 && !drops.some(d => d.afterChain); i++) { s.step(1); watch(); }
    const guarded = drops.filter(d => !d.afterChain).map(d => d.dmg), chain = drops.find(d => d.afterChain);
    if (guarded.length !== 3 || !chain) continue;
    return { seed, guarded, chain: chain.dmg, combo: ex.combo, ratio: chain.dmg / (guarded.reduce((x, y) => x + y, 0) / guarded.length) };
  }
  return null;
}

// ---- KB-005: a dodged signature. Returns how far the defender jumps and how long it hangs motionless afterwards.
function dodgeFreeze(h, seedFrom = 1, seedTo = 80) {
  for (let seed = seedFrom; seed <= seedTo; seed++) {
    const s = sceneOn(h, seed);
    s.b.stance = 2; s.a.ki = 100;
    s.waitCool(); s.tap(KEYS.p1.sig); s.step(1);
    const e = s.lastFeed(/ SIG vs EVASIVE$/);
    if (!e || !/→ DODGE/.test(e[2] || '')) continue;
    const t0 = s.wf.T(); let prevY = s.b.y, jump = null, jumpT = null, frozen = 0, still = true;
    for (let i = 0; i < 400 && s.wf.dirS.ex; i++) {
      s.step(1);
      const dy = s.b.y - prevY;
      if (jump === null) { if (dy > 100) { jump = dy; jumpT = s.wf.T(); } }
      else if (still && s.b.state === 'locked' && Math.abs(dy) < 1e-9 && s.b.vx === 0 && s.b.vy === 0) frozen++;
      else still = false;
      prevY = s.b.y;
    }
    return { seed, jump, frozenSteps: frozen, frozenSeconds: frozen * DT, jumpAt: jumpT - t0, exchangeSeconds: s.wf.T() - t0 };
  }
  return null;
}

// ---- KB-006: a rush across terrain. Needs the instrumented harness (groundY). Returns depth below the ground and time inside it.
function rushThrough(h, { ax, bx, y = 60 }) {
  const s = sceneOn(h, 5, { ax, bx, y });
  s.b.stance = 0; s.a.ki = 100;
  const wf = s.wf; let steps = 0, below = 0, maxDepth = 0, inBuilding = 0, maxBuilding = 0;
  global.__rushProbe = (f, dt, ground) => {
    if (f !== s.a) return;
    steps++;
    const depth = ground - f.y;
    if (depth > 1) { below++; if (depth > maxDepth) maxDepth = depth; }
    for (const b of wf.buildings()) {
      if (!b.alive || Math.abs(sdx(f.x, b.x)) >= b.w / 2) continue;
      const gy = wf.groundY(b.x);
      if (f.y < gy + wf.curH(b) && f.y > gy - 10) { inBuilding++; maxBuilding = Math.max(maxBuilding, gy + wf.curH(b) - f.y); break; }
    }
  };
  try {
    s.waitCool(); s.tap(KEYS.p1.light);
    s.step(90);
  } finally { global.__rushProbe = undefined; }
  return { steps, below, maxDepth, inBuilding, maxBuilding, dist: Math.abs(sdx(ax, bx)) };
}

module.exports = { sceneOn, setTier, beamVsEscape, chargingStrike, parryThenChain, guardChain, dodgeFreeze, rushThrough, KEYS };
