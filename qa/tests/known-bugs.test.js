// Known bugs: one check per confirmed prototype bug, asserting that the bug is STILL PRESENT. These pass today. When
// the prototype behaviour changes, the matching check fails with "KB-00x appears fixed": mark the entry fixed in
// qa/known-bugs.md, then turn the check into a normal regression test (assert the corrected behaviour) or delete it.
// The scenarios are in qa/lib/probes.js and run on the shipped code path with real key events; KB-006 also uses a
// scratch copy with a groundY hook (qa/lib/instrument.js). The register is qa/known-bugs.md.
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { createHarness, runMatch } = require('../../prototype/tools/match-runner');
const { instrumentedHarness } = require('../lib/instrument');
const P = require('../lib/probes');
const t = require('../lib/check')('known-bugs');

const REGISTER = path.join(__dirname, '..', 'known-bugs.md');
const ONLY = process.env.QA_KB_ONLY || null;                            // run just one bug's check (qa/tests/selftest.test.js uses this)
const kbTest = (id, title, fn) => { if (!ONLY || ONLY === id) t.test(title, fn); };
const fixed = (id, what) => { throw new Error(`${id} appears fixed: ${what}\nUpdate qa/known-bugs.md (verdict: fixed, with the commit) and turn this check into a regression test for the corrected behaviour, or delete it.`); };
const broke = (id, what) => { throw new Error(`${id} scenario no longer sets up: ${what}\nThe prototype changed under the check. Update the scenario in qa/lib/probes.js.`); };
const near = (a, b, eps = 1e-6) => Math.abs(a - b) < eps;

if (!ONLY) t.test('the instrumented scratch copy plays out bit-for-bit like the real prototype', () => {
  const real = createHarness(), inst = instrumentedHarness();
  for (const seed of [1, 2, 3, 4, 5, 6]) assert.strictEqual(runMatch(inst, seed).hash, runMatch(real, seed).hash, `seed ${seed}: the hooks changed the simulation`);
});

kbTest('KB-001', 'KB-001 present: a signature vs an ESCAPE defender hits LESS often as the attacker out-tiers it', () => {
  const h = createHarness();
  const lead = P.beamVsEscape(h, { aTier: 4, dTier: 1, trials: 500 }), trail = P.beamVsEscape(h, { aTier: 1, dTier: 4, trials: 500 });
  if (trail.rate - lead.rate < 0.15) fixed('KB-001', `HIT rate is ${(lead.rate * 100).toFixed(1)}% when the attacker leads by 3 tiers and ${(trail.rate * 100).toFixed(1)}% when it trails by 3; the bug made the leader miss more (about 35% vs 65%).`);
  assert.ok(near(lead.rate, 0.35, 0.08) && near(trail.rate, 0.65, 0.08), `rates ${lead.rate} / ${trail.rate} do not match the coded formula 0.5 - 0.05 * (attacker tier - defender tier)`);
  return `attacker leads by 3: ${(lead.rate * 100).toFixed(1)}% hit, trails by 3: ${(trail.rate * 100).toFixed(1)}%`;
});

kbTest('KB-002', 'KB-002 present: the 1.35x damage against a charging defender never applies', () => {
  const h = createHarness();
  const light = P.chargingStrike(h, 'light'), sig = P.chargingStrike(h, 'sig');
  for (const r of [light, sig]) if (!r.chargingBefore || !r.attackerFullHp || r.dmg === null) broke('KB-002', JSON.stringify(r));
  if (light.stateAfterRequest === 'charging') fixed('KB-002', 'the defender is still in the charging state when the exchange starts.');
  if (!near(light.dmg, 36.4) || !near(sig.dmg, 230)) fixed('KB-002', `damage to a charging defender is ${light.dmg} (light) and ${sig.dmg} (signature), no longer the flat 36.4 and 230.`);
  assert.strictEqual(light.stateAfterRequest, 'locked'); assert.strictEqual(light.dPrev, 'charging');
  return `defender is "${light.stateAfterRequest}" when hit; light ${light.dmg.toFixed(1)} = 26 x 1.4, signature ${sig.dmg}, no x1.35`;
});

kbTest('KB-003', 'KB-003 present: a parried exchange still opens a chain window; the chain costs ki, shows a banner and deals nothing', () => {
  const r = P.parryThenChain(createHarness());
  if (!r.parries) broke('KB-003', 'no parry could be staged in seeds 1 to 60');
  if (!r.windows) fixed('KB-003', `${r.parries} parried exchange(s) and none offered a chain window.`);
  const c = r.result;
  if (c.combo < 2) fixed('KB-003', 'a chain window still opens after a parry but pressing attack no longer chains.');
  assert.ok(c.cancelled, 'exchange should be cancelled by the parry');
  assert.ok(c.kiSpent > 5, `chain cost ${c.kiSpent} ki, expected about 6`);
  assert.strictEqual(c.defenderHpLoss, 0, 'the phantom chain should deal no damage');
  assert.ok(/HIT CHAIN/.test(c.banner), `banner was ${c.banner}`);
  assert.ok(/^CHAIN x2 ended$/.test(c.chainLine), 'the feed should record the chain (which is what the harness counts)');
  return `seed ${c.seed}: parried, then "${c.banner}", -${c.kiSpent.toFixed(1)} ki, 0 damage, feed "${c.chainLine}"`;
});

kbTest('KB-004', 'KB-004 present: the chain strike after GUARD HOLDS ignores the guard', () => {
  const r = P.guardChain(createHarness());
  if (!r) broke('KB-004', 'no GUARD HOLDS exchange with three guarded hits and a chain could be staged in seeds 1 to 60');
  if (r.ratio < 5) fixed('KB-004', `the chain strike now deals ${r.chain.toFixed(1)} against guarded hits of ${r.guarded[0].toFixed(1)} (ratio ${r.ratio.toFixed(1)}); unguarded it was 73.9 against 9.9 (ratio 7.5).`);
  assert.ok(r.guarded.every(g => near(g, 9.88, 0.01)), `guarded hits ${r.guarded}`);
  assert.ok(near(r.chain, 73.92, 0.01), `chain strike ${r.chain}`);
  return `seed ${r.seed}: guarded hits ${r.guarded[0].toFixed(2)} each, chain strike ${r.chain.toFixed(2)} (x${r.ratio.toFixed(1)}, no x0.38)`;
});

kbTest('KB-005', 'KB-005 present: a dodged signature teleports the defender up 300 units and leaves it frozen for about 0.9 s', () => {
  const r = P.dodgeFreeze(createHarness());
  if (!r) broke('KB-005', 'no dodged signature found in seeds 1 to 80');
  if (r.jump === null || !near(r.jump, 300, 1e-6)) fixed('KB-005', `the defender no longer jumps exactly 300 units in one step (jump ${r.jump}).`);
  if (r.frozenSeconds < 0.75) fixed('KB-005', `the defender is motionless for only ${r.frozenSeconds.toFixed(2)} s after the dodge (was 0.87 s).`);
  assert.ok(r.frozenSeconds < 1.0, `frozen ${r.frozenSeconds} s`);
  return `seed ${r.seed}: +${r.jump} units in one step at ${r.jumpAt.toFixed(2)} s, then motionless for ${r.frozenSeconds.toFixed(2)} s (${r.frozenSteps} steps)`;
});

kbTest('KB-006', 'KB-006 present: a rush flies through mountains and through standing buildings', () => {
  const h = instrumentedHarness();
  const mountain = P.rushThrough(h, { ax: 6200, bx: 7800 }), city = P.rushThrough(h, { ax: 2100, bx: 4000 }), flat = P.rushThrough(h, { ax: 1500, bx: 1900 });
  if (!mountain.steps || !city.steps) broke('KB-006', 'no rush was observed');
  if (mountain.below < 5) fixed('KB-006', `terrain part: the rush no longer dips below the ground (${mountain.below} of ${mountain.steps} steps).`);
  if (city.inBuilding < 5) fixed('KB-006', `buildings part: the rush no longer passes through standing buildings (${city.inBuilding} of ${city.steps} steps).`);
  assert.ok(mountain.below >= 10 && mountain.maxDepth > 300, `mountain rush: ${mountain.below} of ${mountain.steps} steps below ground, deepest ${mountain.maxDepth.toFixed(0)} (expected at least 10 steps and more than 300 deep)`);
  assert.ok(city.inBuilding >= 10 && city.maxBuilding > 200, `city rush: ${city.inBuilding} steps inside a building, deepest ${city.maxBuilding.toFixed(0)}`);
  assert.strictEqual(flat.below, 0, 'a rush over flat ground should stay above it (control)');
  return `mountains: ${mountain.below} of ${mountain.steps} steps up to ${mountain.maxDepth.toFixed(0)} units inside the ground; city: ${city.inBuilding} of ${city.steps} steps inside towers, up to ${city.maxBuilding.toFixed(0)} units deep`;
});

// The register and the checks must agree: every bug the register calls confirmed or partly has a check, and vice versa.
if (!ONLY) t.test('qa/known-bugs.md and these checks list the same bugs', () => {
  const md = fs.readFileSync(REGISTER, 'utf8');
  const entries = [...md.matchAll(/^## (KB-\d+)[^\n]*\n[\s\S]*?\*\*Verdict:\*\*\s*(\w+)/gm)].map(m => ({ id: m[1], verdict: m[2].toLowerCase() }));
  assert.ok(entries.length >= 6, `register has ${entries.length} parseable entries`);
  const present = entries.filter(e => e.verdict === 'confirmed' || e.verdict === 'partly').map(e => e.id).sort();
  const checked = ['KB-001', 'KB-002', 'KB-003', 'KB-004', 'KB-005', 'KB-006'];
  const wanted = present.filter(id => !checked.includes(id)), stale = checked.filter(id => !present.includes(id));
  assert.deepStrictEqual(wanted, [], `register entries with no check in known-bugs.test.js: ${wanted.join(', ')}`);
  assert.deepStrictEqual(stale, [], `checks whose register entry is not confirmed/partly any more: ${stale.join(', ')}`);
  return entries.map(e => `${e.id} ${e.verdict}`).join(', ');
});

t.done();
