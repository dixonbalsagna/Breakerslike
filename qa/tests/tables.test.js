// Guards the assumptions the QA tools make about the prototype: world constants, biome table, roster, and the
// director feed format the event statistics are parsed from. If one of these fails, the tools (not the sim) are stale.
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { createHarness, runMatch, SEG, SPAWN, STANCES, W } = require('../../prototype/tools/match-runner');
const t = require('../lib/check')('tables');

const src = fs.readFileSync(process.env.QA_HTML || path.join(__dirname, '..', '..', 'prototype', 'index.html'), 'utf8');

t.test('world size and biome table match the prototype', () => {
  const m = /const W = (\d+), COL = (\d+)/.exec(src);
  assert.ok(m, 'could not find "const W = ..., COL = ..." in index.html');
  assert.strictEqual(+m[1], W, 'world width differs from the tools');
  const seg = /const SEG = (\[\[.*?\]\]);/.exec(src);
  assert.ok(seg, 'could not find SEG in index.html');
  assert.deepStrictEqual(JSON.parse(seg[1].replace(/'/g, '"')), SEG, 'biome table (SEG) in index.html differs from prototype/tools/match-runner.js');
});

t.test('stance names match the prototype', () => {
  const m = /const STN = (\[.*?\]),/.exec(src);
  assert.ok(m, 'could not find STN in index.html');
  assert.deepStrictEqual(JSON.parse(m[1].replace(/'/g, '"')), STANCES);
});

t.test('the roster is KAI (hero, P1) and VORR (villain, P2) at 1600 hp', () => {
  const h = createHarness(); h.wf.newMatch(1);
  const [a, b] = h.wf.fighters();
  assert.deepStrictEqual([a.name, a.role, a.maxhp, b.name, b.role, b.maxhp], ['KAI', 'hero', 1600, 'VORR', 'villain', 1600]);
  assert.deepStrictEqual([a.x, b.x], SPAWN, 'spawn positions changed: update SPAWN in prototype/tools/match-runner.js (the -flip arms depend on it)');
});

t.test('no fighter has gold or yellow hair (Legal RL-014)', () => {
  const h = createHarness(); h.wf.newMatch(1);
  for (const f of h.wf.fighters()) {
    const [r, g, b] = [1, 3, 5].map(i => parseInt(f.hair.slice(i, i + 2), 16) / 255);
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
    const hue = d === 0 ? 0 : 60 * (mx === r ? ((g - b) / d + 6) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4);
    const gold = d / (mx || 1) > 0.3 && mx > 0.55 && hue >= 30 && hue <= 70;
    assert.ok(!gold, `${f.name} hair ${f.hair} reads as gold/yellow (hue ${hue.toFixed(0)}): Legal ruling RL-014 asked for a clearly non-gold colour`);
  }
});

t.test('the feed parser recognises every director event it is meant to', () => {
  const h = createHarness(), seen = { attacks: 0, launches: 0, beams: 0, biomes: 0, parries: 0, chains: 0, hides: 0, tiers: 0, ko: 0 }, unknown = {};
  for (let s = 1; s <= 40; s++) {
    const r = runMatch(h, s);
    seen.attacks += r.attacks.light + r.attacks.heavy + r.attacks.sig;
    seen.launches += Object.keys(r.launches).length; seen.beams += r.beams.length; seen.biomes += r.beams.filter(b => b.bio && b.variant && b.out).length;
    seen.parries += r.parries[0] + r.parries[1]; seen.chains += r.chains.length; seen.hides += r.hides[0] + r.hides[1];
    seen.tiers += r.tierUps[0] + r.tierUps[1]; seen.ko += r.timeout ? 0 : 1;
    for (const [k, v] of Object.entries(r.unparsed)) unknown[k] = (unknown[k] || 0) + v;
  }
  for (const [k, v] of Object.entries(seen)) assert.ok(v > 0, `parser saw no "${k}" events in 40 matches: the feed text format probably changed`);
  const u = Object.keys(unknown);
  if (u.length) t.info('feed lines the QA parser does not classify (add them to onFeed in match-runner.js): ' + u.join(' | '));
  return JSON.stringify(seen);
});

t.done();
