// Seam crossing: nothing may jump, go NaN, leave [0, W), or take the long way round when it crosses x = 0 / x = W.
// Scripted scenarios drive human-controlled fighters through the seam with real key events; AI matches are then
// started astride it. Distances use the same shortest-arc math as the prototype.
const assert = require('assert');
const { createHarness, runMatch, sdx, W, HALF, DT } = require('../../prototype/tools/match-runner');
const t = require('../lib/check')('seam');

function scene(seed) {
  const h = createHarness(), wf = h.wf;
  wf.newMatch(seed);
  wf.toggleAI(0); wf.toggleAI(1);                                   // both human, no keys held = both still
  const [a, b] = wf.fighters();
  const key = (type, code) => { for (const fn of h.listeners[type] || []) fn({ code, preventDefault() {}, repeat: false, metaKey: false, ctrlKey: false }); };
  return { h, wf, a, b, down: c => key('keydown', c), up: c => key('keyup', c) };
}
const finite = (...v) => v.every(Number.isFinite);

// Fly fighter A through the seam and check every step against the physics it should obey.
function fly({ from, keys, other, seconds = 20, minCross = 1 }) {
  const s = scene(3), { wf, a, b } = s;
  a.x = from; a.y = 60; b.x = other; b.y = 60;
  keys.forEach(k => s.down(k));
  let crossings = 0, maxCamJump = 0, worstKin = 0;
  for (let i = 0; i < seconds * 60; i++) {
    const px = a.x, pcx = wf.cam.x;
    wf.step(DT);
    assert.ok(finite(a.x, a.y, a.vx, a.vy, b.x, b.y, wf.cam.x, wf.cam.y, wf.cam.z), `non-finite state at step ${i}`);
    assert.ok(a.x >= 0 && a.x < W, `fighter x ${a.x} outside [0, ${W}) at step ${i}`);
    assert.ok(wf.cam.x >= 0 && wf.cam.x < W, `camera x ${wf.cam.x} outside [0, ${W}) at step ${i}`);
    if (Math.abs(a.x - px) > HALF) crossings++;
    const move = sdx(px, a.x), expect = a.vx * DT;                    // shortest-arc move must equal velocity * dt
    worstKin = Math.max(worstKin, Math.abs(move - expect));
    assert.ok(Math.abs(move - expect) < 1e-6, `step ${i}: moved ${move} but vx*dt is ${expect} (seam jump)`);
    maxCamJump = Math.max(maxCamJump, Math.abs(sdx(pcx, wf.cam.x)));
    assert.ok(Math.abs(sdx(pcx, wf.cam.x)) < 0.1 * HALF, `camera jumped ${sdx(pcx, wf.cam.x)} in one step`);
    assert.ok(Math.abs(sdx(a.x, b.x)) <= HALF + 1e-9, 'shortest-arc separation exceeded half the world');
  }
  assert.ok(crossings >= minCross, `fighter never crossed the seam (${crossings} crossings)`);
  // camera should have followed the short way: it ends near the midpoint of the pair
  const mid = a.x + sdx(a.x, b.x) / 2;
  assert.ok(Math.abs(sdx(wf.cam.x, mid)) < 600, `camera ended ${sdx(wf.cam.x, mid).toFixed(0)} units from the pair`);
  return `${crossings} crossing, camera max step ${maxCamJump.toFixed(1)}`;
}
t.test('fly east across the seam', () => fly({ from: W - 500, keys: ['KeyD'], other: 100 }));
t.test('fly west across the seam', () => fly({ from: 500, keys: ['KeyA'], other: W - 100 }));
t.test('dash east across the seam while climbing', () => fly({ from: W - 900, keys: ['KeyD', 'Space', 'KeyW'], other: 200, seconds: 10 }));
t.test('dash west across the seam while diving', () => fly({ from: 900, keys: ['KeyA', 'Space', 'KeyS'], other: W - 200, seconds: 10 }));

// Launched (knock-back) fighters cross the seam with high speed and hit the ground on the far side.
function launched(x0, vx) {
  const s = scene(4), { wf, a, b } = s;
  b.x = 5000; b.y = 60;
  a.x = x0; a.y = 300; a.vx = vx; a.vy = 200; a.state = 'launched'; a.launchBy = null; a.stateT = 0;
  let crossings = 0;
  for (let i = 0; i < 6 * 60; i++) {
    const px = a.x, sp = Math.hypot(a.vx, a.vy);
    wf.step(DT);
    assert.ok(finite(a.x, a.y, a.vx, a.vy), `non-finite state at step ${i}`);
    assert.ok(a.x >= 0 && a.x < W, `x ${a.x} outside [0, ${W})`);
    if (Math.abs(a.x - px) > HALF) crossings++;
    assert.ok(Math.abs(sdx(px, a.x)) <= sp * DT * 1.05 + 1e-6, `step ${i}: moved ${sdx(px, a.x)} at speed ${sp}`);
  }
  assert.ok(crossings >= 1, 'launch never reached the seam');
  return crossings + ' crossing';
}
t.test('launched fighter crosses the seam eastward', () => launched(W - 300, 2500));
t.test('launched fighter crosses the seam westward', () => launched(300, -2500));

// Ground height at any x, read by parking fighter B on the terrain (the prototype exposes no groundY).
function prober(wf) {
  const p = wf.fighters()[1];
  return x => { p.x = x; p.y = -1e5; p.vx = p.vy = 0; p.state = 'free'; for (let i = 0; i < 10 && p.y === -1e5; i++) wf.step(DT); return p.y; };
}
t.test('terrain is continuous across the seam', () => {
  const s = scene(5), g = prober(s.wf);
  const xs = []; for (let x = W - 800; x < W; x += 8) xs.push(x); for (let x = 0; x <= 800; x += 8) xs.push(x);
  const ys = xs.map(g);
  let seamStep = 0, maxStep = 0;
  for (let i = 1; i < xs.length; i++) {
    const d = Math.abs(ys[i] - ys[i - 1]);
    if (xs[i - 1] === W - 8 && xs[i] === 0) seamStep = d; else maxStep = Math.max(maxStep, d);
  }
  assert.ok(seamStep <= Math.max(2 * maxStep, 1), `height step across the seam is ${seamStep.toFixed(2)} vs ${maxStep.toFixed(2)} elsewhere nearby`);
  return `seam step ${seamStep.toFixed(2)}, worst nearby ${maxStep.toFixed(2)}`;
});

t.test('a crater straddling the seam is symmetric about it', () => {
  const s = scene(6), { wf, a } = s, g = prober(wf);
  const offs = []; for (let d = 8; d <= 200; d += 8) offs.push(d);
  a.x = 0; a.y = -300; a.power = 24;                                // seabed is about -330: under the tier-up crater threshold
  const before = {}; for (const d of [0, ...offs]) { before['+' + d] = g(d); before['-' + d] = g((W - d) % W); }
  a.x = 0; a.y = -300; a.power = 24.9999;                           // next step crosses tier 2 and craters the ground under A
  let guard = 0; while (a.tier < 2 && guard++ < 10) wf.step(DT);
  assert.ok(a.tier >= 2, 'tier-up did not happen');
  const dep = {}; for (const d of [0, ...offs]) { dep['+' + d] = g(d) - before['+' + d]; dep['-' + d] = g((W - d) % W) - before['-' + d]; }
  assert.ok(dep['+0'] < -5, `no crater at the seam (depth ${dep['+0']})`);
  for (const d of offs) assert.ok(Math.abs(dep['+' + d] - dep['-' + d]) < 1e-6, `crater not symmetric at ±${d}: ${dep['+' + d]} vs ${dep['-' + d]}`);
  return `centre depth ${(-dep['+0']).toFixed(1)}`;
});

// AI matches started on either side of the seam: the fight has to be able to cross it.
t.test('AI vs AI matches started astride the seam stay finite and continuous', () => {
  const h = createHarness();
  let crossings = 0, worst = 0, n = 0;
  for (let s = 1; s <= 24; s++) {
    const flip = s % 2;
    const r = runMatch(h, 700 + s, { invariants: true, setup: fs => { fs[0].x = flip ? 300 : W - 300; fs[1].x = flip ? W - 300 : 300; fs[0].y = fs[1].y = 60; } });
    assert.ok(!r.nan, `seed ${700 + s}: NaN in ${r.nan && r.nan.fighter} ${r.nan && r.nan.key}`);
    assert.strictEqual(r.xBad, 0, `seed ${700 + s}: a fighter left [0, ${W})`);
    assert.deepStrictEqual(r.violations, [], `seed ${700 + s}: ` + r.violations.join('; '));
    assert.ok(r.maxDisp < 300, `seed ${700 + s}: a fighter moved ${r.maxDisp.toFixed(0)} units in one step`);
    crossings += r.seamCrossings; worst = Math.max(worst, r.maxDisp); n++;
  }
  assert.ok(crossings >= 5, `only ${crossings} seam crossings in ${n} matches: the scenario is not exercising the seam`);
  return `${n} matches, ${crossings} crossings, max step ${worst.toFixed(0)} units`;
});

t.done();
