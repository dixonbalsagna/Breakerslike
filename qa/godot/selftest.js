#!/usr/bin/env node
// Self-test for the Godot QA tooling, no Godot needed: node qa/godot/selftest.js
// Feeds synthetic records to the acceptance-test skeletons and the band evaluator to prove that (1) a skeleton stays
// PENDING while its events are absent, (2) it PASSes on records that satisfy the spec and FAILs on records that break it
// once the events exist, so the wiring is known to work before the slices land.
const assert = require('assert');
const { runTests } = require('./pending-tests');
const { evaluate } = require('./bands');

let pass = 0, fail = 0;
const t = async (name, fn) => { try { await fn(); pass++; console.log('  ok    ' + name); } catch (e) { fail++; console.log('  FAIL  ' + name + '\n        ' + e.message.split('\n')[0]); } };

// A minimal record with the fields the tests read.
const rec = (o = {}) => ({ seed: 1, arm: 'default', names: ['KAI', 'VORR'], timeout: false, winner: 0, koAt: 100, tierT: [0, -1, 20, 40, -1], maxTier: [3, 2], fronts: 0, wear: [null, null], events: [], fxCounts: {}, launches: {}, melee: {}, beams: [], parries: [0, 0], chains: [], hides: [0, 0], hiddenSec: [0, 0], fightSec: { plains: 10 }, exLens: [], exGaps: [], flights: [], underSec: 0, lowSec: 1, lowCas: 0, pop0: 425, civPct: 30, ambush: 0, rows: { 1: { lost: 10, n: 47 } }, menace: [0, 0], ...o });
const withEvents = (r, evs) => { const fx = { ...r.fxCounts }; for (const e of evs) fx[e.type] = (fx[e.type] || 0) + 1; return { ...r, events: evs, fxCounts: fx }; };
const byId = res => Object.fromEntries(res.map(r => [r.id, r]));
const ctx = A => ({ A, runRecords: async () => [rec()] });

(async () => {
  console.log('== godot qa selftest');
  await t('every slice-dependent skeleton is PENDING on records with no wounds or hazard events', async () => {
    const r = byId(await runTests(ctx({ default: [rec()] }), ['W2', 'W3', 'W4', 'W5', 'W6', 'W7', 'H1', 'H2', 'H3', 'H4', 'H5']));
    assert.ok(Object.values(r).every(x => x.status === 'PENDING'), JSON.stringify(Object.values(r).map(x => x.id + ':' + x.status)));
  });
  await t('W2 passes when a KO follows brink_enter then finisher_start, and fails when there is no finisher', async () => {
    const ok = withEvents(rec(), [{ type: 'brink_enter', t: 50, actor: 1 }, { type: 'finisher_start', t: 60, actor: 0, target: 1 }, { type: 'ko', t: 62, winner: 0, loser: 1 }]);
    assert.strictEqual(byId(await runTests(ctx({ default: [ok] }), ['W2'])).W2.status, 'PASS');
    const bad = withEvents(rec(), [{ type: 'brink_enter', t: 50, actor: 1 }, { type: 'finisher_start', t: 60, actor: 0, target: 0 }, { type: 'ko', t: 62, winner: 0, loser: 1 }]);
    assert.strictEqual(byId(await runTests(ctx({ default: [bad] }), ['W2'])).W2.status, 'FAIL');
  });
  await t('W4 fails when a region is rallied twice, and when survival stays above 0 after a third rally', async () => {
    const twice = withEvents(rec(), [{ type: 'rally', t: 10, actor: 1, region: 'legs' }, { type: 'rally', t: 40, actor: 1, region: 'legs' }, { type: 'finisher_contest', t: 50, target: 1, chance: 0 }]);
    assert.strictEqual(byId(await runTests(ctx({ default: [twice] }), ['W4'])).W4.status, 'FAIL');
    const three = withEvents(rec(), [{ type: 'rally', t: 10, actor: 1, region: 'legs' }, { type: 'rally', t: 40, actor: 1, region: 'arms' }, { type: 'rally', t: 70, actor: 1, region: 'head' }, { type: 'finisher_contest', t: 90, target: 1, chance: 0.1 }]);
    const r = byId(await runTests(ctx({ default: [three] }), ['W4'])).W4;
    assert.strictEqual(r.status, 'FAIL'); assert.ok(/survival|rallies per match/.test(r.detail), r.detail);
  });
  await t('H1 fails on a hazard-caused break; H2 fails on a tier-1 hazard casualty; H3 fails on 4 fronts in frame', async () => {
    const h1 = withEvents(rec(), [{ type: 'hazard_fire', t: 5, cause: 'fire', n: 0 }, { type: 'region_broken', t: 9, actor: 1, region: 'legs', cause: 'fire' }]);
    assert.strictEqual(byId(await runTests(ctx({ default: [h1] }), ['H1'])).H1.status, 'FAIL');
    const h2 = withEvents(rec(), [{ type: 'hazard_fire', t: 5, cause: 'fire', n: 3 }]);
    assert.strictEqual(byId(await runTests(ctx({ default: [h2] }), ['H2'])).H2.status, 'FAIL');
    assert.strictEqual(byId(await runTests(ctx({ default: [withEvents(rec(), [{ type: 'hazard_fire', t: 30, cause: 'fire', n: 3 }])] }), ['H2'])).H2.status, 'PASS');
    const h3 = withEvents(rec({ fronts: 4 }), [{ type: 'hazard_front', t: 5 }]);
    assert.strictEqual(byId(await runTests(ctx({ default: [h3] }), ['H3'])).H3.status, 'FAIL');
  });
  await t('W3 stays PENDING until finisher_start exists; W5 reports INFO from S1 events and bands once S2 lands', async () => {
    const s1 = withEvents(rec({ dmgByRegion: { head: 10, core: 10, arms: 10, legs: 10 } }), [{ type: 'region_broken', t: 20, actor: 1, region: 'head' }, { type: 'brink_enter', t: 25, actor: 1 }]);
    const r = byId(await runTests(ctx({ default: [s1] }), ['W3', 'W5']));
    assert.strictEqual(r.W3.status, 'PENDING'); assert.strictEqual(r.W5.status, 'INFO');
    const s2 = withEvents(s1, [{ type: 'finisher_start', t: 30, actor: 0, target: 1 }]);
    assert.strictEqual(byId(await runTests(ctx({ default: [s2] }), ['W5'])).W5.status, 'PASS');
    const skew = withEvents(rec({ dmgByRegion: { head: 90, core: 10, arms: 5, legs: 5 } }), [{ type: 'region_broken', t: 20, actor: 1, region: 'core' }, { type: 'finisher_start', t: 30, actor: 0, target: 1 }]);
    assert.strictEqual(byId(await runTests(ctx({ default: [skew] }), ['W5'])).W5.status, 'FAIL');   // one region takes over 45% of the damage
  });
  await t('C1 and C2 stay PENDING until an evacuation event exists, then fail on an over-budget window and an over-ceiling match', async () => {
    const tl = []; for (let i = 0; i <= 100; i++) tl.push([i, Math.min(0.5, i * 0.01), 1]);          // 1% a second at tier 1: far over 2% per minute and past the 10% ceiling
    const base = rec({ casTimeline: tl });
    const r0 = byId(await runTests(ctx({ default: [base] }), ['C1', 'C2']));
    assert.strictEqual(r0.C1.status, 'PENDING'); assert.strictEqual(r0.C2.status, 'PENDING');
    const r1 = byId(await runTests(ctx({ default: [withEvents(base, [{ type: 'evacuate', t: 5 }])] }), ['C1', 'C2']));
    assert.strictEqual(r1.C1.status, 'FAIL'); assert.strictEqual(r1.C2.status, 'FAIL');
    const ok = rec({ casTimeline: [[0, 0, 1], [30, 0.01, 1], [60, 0.015, 1], [90, 0.02, 2]] });
    const r2 = byId(await runTests(ctx({ default: [withEvents(ok, [{ type: 'evacuate', t: 5 }])] }), ['C1', 'C2']));
    assert.strictEqual(r2.C1.status, 'PASS'); assert.strictEqual(r2.C2.status, 'PASS');
  });
  await t('lock-break rows: one 2.5 s break passes, a 5 s break and a repeat inside 6 s fail; hazard_telegraph alone does not switch on the hazard tests', async () => {
    const mk = evs => evaluate({ default: [withEvents(rec(), evs)] });
    const ok = mk([{ type: 'searching', t: 9, actor: 0, target: 1, kind: 'sweep' }, { type: 'searching', t: 10, actor: 0, target: 1, kind: 'lock' }, { type: 'found', t: 12.5, actor: 1 }]);
    assert.strictEqual(ok.find(r => r.id === '8.lock.median').status, 'PASS'); assert.strictEqual(ok.find(r => r.id === '8.lock.max').status, 'PASS');
    const long = mk([{ type: 'searching', t: 10, actor: 0, target: 1 }, { type: 'found', t: 15, actor: 1 }]);
    assert.strictEqual(long.find(r => r.id === '8.lock.max').status, 'FAIL');
    const rep = mk([{ type: 'searching', t: 10, actor: 0, target: 1 }, { type: 'found', t: 12, actor: 1 }, { type: 'searching', t: 16, actor: 0, target: 1 }, { type: 'found', t: 18, actor: 1 }]);
    assert.strictEqual(rep.find(r => r.id === '8.lock.gap').status, 'FAIL');
    const tele = byId(await runTests(ctx({ default: [withEvents(rec(), [{ type: 'hazard_telegraph', t: 5 }])] }), ['H2', 'H3']));
    assert.strictEqual(tele.H2.status, 'PENDING'); assert.strictEqual(tele.H3.status, 'PENDING');
  });
  await t('Stage C: 22 script tests and 6 batch checks exist, PENDING without press_ack; with the event but no script file they stay PENDING', async () => {
    const { tests } = require('./pending-tests');
    assert.strictEqual(tests.filter(x => x.stageC).length, 22); assert.strictEqual(tests.filter(x => /^SB[1-6]$/.test(x.id)).length, 6);
    const ids = tests.filter(x => x.stageC || /^SB[1-6]$/.test(x.id)).map(x => x.id);
    const none = await runTests(ctx({ default: [rec()] }), ids);
    assert.ok(none.every(r => r.status === 'PENDING'));
    const ev = await runTests(ctx({ default: [withEvents(rec(), [{ type: 'press_ack', t: 1, actor: 0 }, { type: 'availability', t: 1, actor: 0 }])] }), tests.filter(x => x.stageC).map(x => x.id));
    assert.ok(ev.every(r => r.status === 'PENDING' && /not written yet/.test(r.detail)), JSON.stringify(ev.filter(r => r.status !== 'PENDING').map(r => r.id + ':' + r.status + ' ' + r.detail)));
  });
  await t('mood and style rows: PENDING without M1 events; with them the act, band and label maths give PASS on a good match and FAIL on a bad one', async () => {
    assert.strictEqual(evaluate({ default: [rec()] }).find(r => r.id === 'mood').status, 'PENDING');
    const good = withEvents(rec({ koAt: 400 }), [
      { type: 'mood_band', t: 100, kind: 'tense', n: 1 }, { type: 'act_change', t: 120, n: 2 }, { type: 'act_change', t: 200, n: 3 }, { type: 'act_change', t: 300, n: 4 },
      { type: 'mood_band', t: 310, kind: 'frenzied', n: 4 }, { type: 'mood_band', t: 360, kind: 'tense', n: 4 }, { type: 'brink_enter', t: 350, actor: 1 },
      { type: 'style_label', t: 40, actor: 0, kind: 'rusher', text: '' }, { type: 'style_label', t: 200, actor: 0, kind: '', text: 'rusher' }]);
    const r = Object.fromEntries(evaluate({ default: Array.from({ length: 60 }, () => good) }).map(x => [x.id, x]));
    assert.strictEqual(r['mood.act2'].status, 'PASS'); assert.strictEqual(r['mood.act3'].status, 'PASS'); assert.strictEqual(r['mood.act4'].status, 'PASS');
    assert.strictEqual(r['mood.act4beforeBrink'].status, 'PASS'); assert.strictEqual(r['mood.frenzied'].status, 'PASS');
    assert.strictEqual(r['style.entries'].status, 'PASS'); assert.strictEqual(r['style.shortest'].status, 'PASS');
    const bad = withEvents(rec({ koAt: 400 }), [{ type: 'act_change', t: 60, n: 2 }, { type: 'act_change', t: 70, n: 3 }, { type: 'mood_band', t: 80, kind: 'tense', n: 3 },
      { type: 'style_label', t: 10, actor: 0, kind: 'sniper', text: '' }, { type: 'style_label', t: 15, actor: 0, kind: '', text: 'sniper' }]);
    const b = Object.fromEntries(evaluate({ default: [bad] }).map(x => [x.id, x]));
    assert.strictEqual(b['mood.act2'].status, 'FAIL'); assert.strictEqual(b['style.shortest'].status, 'FAIL');
  });
  await t('a test with events present but no body stays PENDING, never PASS', async () => {
    const r = byId(await runTests(ctx({ default: [withEvents(rec(), [{ type: 'brunt_chain', t: 5 }])] }), ['H5'])).H5;
    assert.strictEqual(r.status, 'PENDING');
  });
  await t('the band evaluator marks KAI below 45% as FAIL and 50% as PASS, and lists structures by row once rows exist', async () => {
    const mk = (kaiWins, n) => Array.from({ length: n }, (_, i) => rec({ seed: i, winner: i < kaiWins ? 0 : 1 }));
    const swapMk = (kaiWins, n) => Array.from({ length: n }, (_, i) => rec({ seed: i, winner: i < kaiWins ? 1 : 0 }));
    const low = evaluate({ default: mk(30, 100), swap: swapMk(30, 100) }).find(r => r.id === '1.kai');
    assert.strictEqual(low.status, 'FAIL');
    const mid = evaluate({ default: mk(200, 400), swap: swapMk(200, 400) }).find(r => r.id === '1.kai');
    assert.strictEqual(mid.status, 'PASS');
    const rows = evaluate({ default: Array.from({ length: 10 }, () => rec({ rows: { 1: { lost: 10, n: 47 }, 2: { lost: 20, n: 60 } } })) });
    assert.ok(rows.find(r => r.id === '4.struct.row2'), 'no per-row line');
    assert.ok(!rows.find(r => r.id === '4.struct.rows'), 'the pending row should be gone once rows exist');
  });
  await t('landing rows: the 19 bands judge slide, slam, caught, water, brunt; the 20 rows (bounce class, lips, bounces, tumbles) stay PENDING until bounce, lip or tumble events exist, then judge', async () => {
    const lm = (landings, fx = {}, extra = {}) => rec({ koAt: 360, fxCounts: { slide: 4, ...fx }, slides: [], impactCraters: 0, skims: 0, launches: { 'SLAM DOWN': 40, 'UPPERCUT': 30, 'BUILDING SMASH': 7, 'SMASH ACROSS': 23 }, landings, landingsAll: landings, slideShort: 0, slideShortPl: 0, journeys: { n: 0, bounced: 0, bounces: 0, tumbled: 0, lips: 0 }, ...extra });
    const good = { slide: 50, slam: 15, caught: 15, water: 10, brunt: 7, bounce: 0, other: 3 };
    const rows = evaluate({ default: Array.from({ length: 40 }, () => lm(good)) }), id = k => rows.find(r => r.id === k);
    assert.strictEqual(id('5c.mix.slide').status, 'PASS'); assert.strictEqual(id('5c.mix.slam').status, 'PASS'); assert.strictEqual(id('5c.mix.caught').status, 'PASS');
    assert.strictEqual(id('5c.mix.water').status, 'PASS'); assert.strictEqual(id('5c.mix.brunt').status, 'PASS'); assert.strictEqual(id('5c.slideOfGround').status, 'PASS');
    for (const k of ['5c.lip', '5c.bounces', '5c.tumble', '5c.tech']) assert.strictEqual(id(k).status, 'PENDING', k);
    const slammy = evaluate({ default: Array.from({ length: 40 }, () => lm({ slide: 25, slam: 55, caught: 10, water: 4, brunt: 4, bounce: 0, other: 2 })) });
    assert.strictEqual(slammy.find(r => r.id === '5c.mix.slide').status, 'FAIL'); assert.strictEqual(slammy.find(r => r.id === '5c.slideOfGround').status, 'FAIL');
    const g5 = { slide: 45, bounce: 10, slam: 10, caught: 15, water: 10, brunt: 7, other: 3 };
    const r5 = evaluate({ default: Array.from({ length: 40 }, () => lm(g5, { bounce: 4, lip: 3, tumble: 8 }, { journeys: { n: 40, bounced: 5, bounces: 8, tumbled: 18, lips: 3 } })) }), id5 = k => r5.find(r => r.id === k);
    assert.strictEqual(id5('5c.mix.bounce').status, 'PASS'); assert.strictEqual(id5('5c.largest').status, 'PASS'); assert.strictEqual(id5('5c.lip').status, 'PASS');
    assert.strictEqual(id5('5c.bounces').status, 'PASS'); assert.strictEqual(id5('5c.tumble').status, 'PASS'); assert.strictEqual(id5('5c.tech').status, 'PENDING');
  });
  console.log(`godot qa selftest: ${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
})();
