// The fixed arm plan (which arm uses which seed block) and the batch runner shared by balance-report.js and baseline-diff.js.
// Changing a base seed changes what "the baseline" means, so treat this table as part of the baseline.
const { createHarness, runMatch, Hasher } = require('../../prototype/tools/match-runner');
const S = require('../../prototype/tools/stats');

const PLAN = [
  { arm: 'default', base: 100001, core: true, label: 'KAI in P1, VORR in P2 (as shipped)' },
  { arm: 'swap', base: 200001, core: true, label: 'VORR in P1, KAI in P2' },
  { arm: 'mirror-villain', base: 300001, core: true, label: 'VORR-A in P1, VORR-B in P2' },
  { arm: 'mirror-hero', base: 400001, core: true, label: 'KAI-A in P1, KAI-B in P2' },
  // The same four with the spawn sides exchanged, to separate the slot (P1 or P2) from the side of the map a fighter starts on.
  { arm: 'default-flip', base: 500001, label: 'KAI in P1 starting east, VORR in P2 starting west' },
  { arm: 'swap-flip', base: 600001, label: 'VORR in P1 starting east, KAI in P2 starting west' },
  { arm: 'mirror-villain-flip', base: 700001, label: 'VORR-A in P1 starting east, VORR-B in P2 starting west' },
  { arm: 'mirror-hero-flip', base: 800001, label: 'KAI-A in P1 starting east, KAI-B in P2 starting west' },
];

// Run `count` matches of one arm from seed `base` (plus an optional shift). Returns { recs, agg } with agg.digest, agg.base, agg.label.
function runArm(h, plan, count, seedShift = 0) {
  const recs = [], dg = new Hasher();
  for (let i = 0; i < count; i++) {
    const r = runMatch(h, plan.base + seedShift + i, { arm: plan.arm });
    if (r.nan) throw new Error(`NaN in ${r.nan.fighter} ${r.nan.key} at ${r.nan.t.toFixed(2)}s, arm ${plan.arm} seed ${r.seed}`);
    recs.push(r); dg.str(r.hash);
  }
  const agg = S.aggregate(recs);
  agg.digest = dg.hex(); agg.base = plan.base + seedShift; agg.label = plan.label;
  return { recs, agg };
}

module.exports = { PLAN, runArm, createHarness };
