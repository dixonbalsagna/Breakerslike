// Soak: many seeded AI-vs-AI matches with per-step rule checks. P0 exit criterion: 1000 matches, no NaN, no crash.
// Any failure prints the seed, so it can be replayed with: node prototype/tools/sim-stats.js 1 <seed> --arm=<arm>
const assert = require('assert');
const { createHarness, runMatch } = require('../../prototype/tools/match-runner');
const { aggregate, pct } = require('../../prototype/tools/stats');
const t = require('../lib/check')('soak');

const N = parseInt(process.env.QA_SOAK_MATCHES || '1000', 10);
const EXTRA = Math.max(1, Math.round(N / 10));                       // matches per non-default arm
const plan = [['default', 1, N], ['swap', 20001, EXTRA], ['mirror-villain', 30001, EXTRA], ['mirror-hero', 40001, EXTRA]];

for (const [arm, base, count] of plan) {
  t.test(`${count} matches, arm ${arm}, seeds ${base}..${base + count - 1}`, () => {
    const h = createHarness(), recs = [];
    for (let i = 0; i < count; i++) {
      const seed = base + i;
      let r;
      try { r = runMatch(h, seed, { arm, invariants: true }); }
      catch (e) { throw new Error(`crash at seed ${seed}: ${e && e.stack || e}\nreplay: node prototype/tools/sim-stats.js 1 ${seed} --arm=${arm}`); }
      assert.ok(!r.nan, `NaN in ${r.nan && r.nan.fighter} ${r.nan && r.nan.key} at ${r.nan && r.nan.t.toFixed(2)}s, seed ${seed}\nreplay: node prototype/tools/sim-stats.js 1 ${seed} --arm=${arm}`);
      assert.strictEqual(r.xBad, 0, `fighter left [0, W) at seed ${seed}`);
      assert.deepStrictEqual(r.violations, [], `rule violation at seed ${seed}: ${r.violations.join('; ')}\nreplay: node prototype/tools/sim-stats.js 1 ${seed} --arm=${arm}`);
      recs.push(r);
    }
    const a = aggregate(recs);
    assert.ok(a.timeouts <= Math.ceil(count * 0.01), `${a.timeouts} of ${count} matches hit the 300 s cap without a KO (stalemate?)`);
    const late = recs.filter(r => r.timeout).map(r => r.seed);
    return `P1 ${pct(a.slotRate[0].rate, 0)}, avg ${a.len.mean.toFixed(0)}s, ${a.timeouts} timeouts${late.length ? ' (seeds ' + late.join(',') + ')' : ''}, ${a.seam.matchesWithCrossing} crossed the seam`;
  });
}

t.done();
