// Determinism: the same seed must give the same match, whatever ran before it and however it was started.
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { createHarness, runMatch } = require('../../prototype/tools/match-runner');
const t = require('../lib/check')('determinism');

const GOLDEN = path.join(__dirname, '..', 'golden-hashes.json');
const SEEDS = [0, 1, 2, 3, 42, 1000, 123456, 4294967295];

t.test('same seed twice in one process gives identical records', () => {
  const h = createHarness();
  for (const s of SEEDS) {
    const a = runMatch(h, s), b = runMatch(h, s);
    assert.strictEqual(a.hash, b.hash, `seed ${s}: hash ${a.hash} vs ${b.hash}`);
    assert.strictEqual(JSON.stringify(a), JSON.stringify(b), `seed ${s}: hash matches but the records differ`);
  }
  return SEEDS.length + ' seeds';
});

t.test('a match does not depend on the ones played before it (newMatch resets all carry-over state)', () => {
  for (const s of [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]) {
    const fresh = runMatch(createHarness(), s).hash;
    const warm = createHarness();
    runMatch(warm, 7000 + s); runMatch(warm, 8000 + s);           // other matches first
    const after = runMatch(warm, s).hash;
    assert.strictEqual(after, fresh, `seed ${s}: result depends on what was played before it`);
  }
  return '12 seeds';
});

t.test('different seeds give different matches', () => {
  const h = createHarness(), seen = new Map();
  for (let s = 1; s <= 30; s++) {
    const r = runMatch(h, s);
    assert.ok(!seen.has(r.hash), `seeds ${seen.get(r.hash)} and ${s} produced the same match`);
    seen.set(r.hash, s);
  }
  return '30 distinct';
});

t.test('adjacent seeds 2k and 2k+1 are not merged (old clock seeding forced the low bit)', () => {
  const h = createHarness();
  for (const s of [2, 4, 100]) assert.notStrictEqual(runMatch(h, s).hash, runMatch(h, s + 1).hash, `seed ${s} and ${s + 1} are the same match`);
});

t.test('the game reports the seed it was given', () => {
  const h = createHarness();
  for (const s of [0, 5, 6, 99999]) { runMatch(h, s); assert.strictEqual(h.wf.game.seed, s); }
});

t.test('unseeded newMatch() is the same code path as newMatch(clockSeed)', () => {
  const h = createHarness(), real = Date.now;
  try {
    for (const clock of [4242423, 4242422, 987654321]) {            // odd, even, and above 24 bits
      Date.now = () => clock;
      const viaClock = runMatch(h, undefined);
      Date.now = real;
      const explicit = runMatch(h, (clock & 0xffffff) | 1);
      assert.strictEqual(viaClock.hash, explicit.hash, `clock ${clock}: unseeded and explicit seed differ`);
    }
  } finally { Date.now = real; }
  return '3 clock values';
});

t.test('every arm is deterministic', () => {
  const h = createHarness();
  for (const arm of ['default', 'swap', 'mirror-villain', 'mirror-hero']) {
    assert.strictEqual(runMatch(h, 17, { arm }).hash, runMatch(h, 17, { arm }).hash, arm);
  }
  assert.notStrictEqual(runMatch(h, 17, { arm: 'default' }).hash, runMatch(h, 17, { arm: 'swap' }).hash, 'swap arm changed nothing');
});

// Golden hashes: a tripwire for any change to simulation behaviour. Regenerate on purpose with
//   node qa/run-all.js --update-golden     (then re-run the balance report)
const GOLD_KEYS = [['default', 1], ['default', 2], ['default', 3], ['default', 4], ['default', 5], ['default', 6], ['default', 7], ['default', 8], ['swap', 1], ['mirror-villain', 1], ['mirror-hero', 1]];
function goldenNow() {
  const h = createHarness(), out = {};
  for (const [arm, s] of GOLD_KEYS) out[arm + ':' + s] = runMatch(h, s, { arm }).hash;
  return out;
}
t.test('golden hashes match (simulation behaviour unchanged)', () => {
  const now = goldenNow();
  if (process.env.QA_UPDATE_GOLDEN) {
    fs.writeFileSync(GOLDEN, JSON.stringify({ node: process.version, note: 'Result hashes of fixed seeds. Regenerate with: node qa/run-all.js --update-golden', entries: now }, null, 2) + '\n');
    return 'golden file rewritten';
  }
  if (!fs.existsSync(GOLDEN)) throw new Error('qa/golden-hashes.json is missing. Create it with: node qa/run-all.js --update-golden');
  const g = JSON.parse(fs.readFileSync(GOLDEN, 'utf8'));
  const major = v => String(v).replace(/^v/, '').split('.')[0];
  if (major(g.node) !== major(process.version)) return `skipped: goldens recorded on Node ${g.node}, running ${process.version} (Math.* may differ across majors)`;
  const bad = Object.keys(now).filter(k => now[k] !== g.entries[k]);
  assert.ok(!bad.length, `simulation output changed for ${bad.join(', ')}.\nIf the change is intended (numbers or behaviour were edited), run: node qa/run-all.js --update-golden\nand re-run the balance report. If not, something broke determinism or behaviour.`);
  return Object.keys(now).length + ' matches';
});

t.done();
