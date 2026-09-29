// Acceptance-test skeletons for slices that have not landed: the Wounds acceptance tests (docs/design/spec-wounds.md §5),
// the living-destruction hard tests (balance-targets.md §11, living-destruction-numbers.md) and the §5b chain hard tests.
// A test whose `needs` (fx event types the sim must emit; a trailing * matches a prefix) are absent from the records is
// reported PENDING with the slice that unblocks it; it never fails. The moment the events appear, the body runs for real.
// A test with no body is a checklist item: it stays PENDING until someone writes the body against the event fields that
// slice defines. The event contract assumed here is the one in spec-wounds §4 and wounds-plan.md:
//   region_stage {actor, region, stage}   region_broken {actor, region, cause?}   brink_enter/brink_exit {actor}
//   rally {actor, region}   finisher_start {actor, target}   finisher_contest {target, chance, survived}   ko {winner, loser}
//   hazard* events {cause, n (casualties), front?}; records carry `tierT` (when the higher tier first reached 2..4),
//   `wear` (per-region wear per fighter, from f.wear) and `fronts` (max hazard fronts in frame, from S.frontsInFrame).
// If a slice names a field differently, change the contract here and in qa/godot/records.gd (KEEP_FIELDS), not in the test.
const assert = require('assert');
const { hasEvent, median, q } = require('./bands');

const evs = (r, type) => (r.events || []).filter(e => e.type === type);
const failing = (recs, pred) => recs.filter(r => !pred(r)).map(r => r.seed);
const noBad = (label, seeds) => assert.deepStrictEqual(seeds, [], `${label}: seeds ${seeds.slice(0, 8).join(', ')}${seeds.length > 8 ? ` and ${seeds.length - 8} more` : ''}`);

const tests = [
  // ---------------------------------------------------------------- active today
  { id: 'W1', spec: 'spec-wounds §5.1', title: 'Determinism: the same seed gives an identical record and event log, whatever the job count', slice: 'active', needs: [],
    async run({ runRecords }) {
      const a = await runRecords({ arm: 'default', base: 1, count: 6, jobs: 1, quiet: true }), b = await runRecords({ arm: 'default', base: 1, count: 6, jobs: 3, quiet: true });
      assert.deepStrictEqual(a.map(r => r.hash), b.map(r => r.hash), 'state hashes differ between runs');
      assert.strictEqual(JSON.stringify(a.map(r => [r.events, r.fxCounts, r.exLens])), JSON.stringify(b.map(r => [r.events, r.fxCounts, r.exLens])), 'event streams differ between runs');
      return '6 seeds, 1 and 3 jobs';
    } },
  // ---------------------------------------------------------------- Wounds S1 to S4
  { id: 'W2', spec: 'spec-wounds §5.2', title: 'No KO without a finisher: 100% of KOs follow the loser\'s brink_enter and a finisher_start', slice: 'S2', needs: ['ko', 'finisher_start', 'brink_enter'],
    run({ A }) {
      const ko = A.default.filter(r => !r.timeout);
      noBad('KO without brink_enter then finisher_start then ko', failing(ko, r => {
        const k = evs(r, 'ko')[0]; if (!k) return false;
        const b = evs(r, 'brink_enter').find(e => e.actor === k.loser), f = evs(r, 'finisher_start').find(e => e.target === k.loser);
        return b && f && b.t <= f.t && f.t <= k.t;
      }));
      return `${ko.length} KOs`;
    } },
  { id: 'W3', spec: 'spec-wounds §5.3', title: 'Length and chapters: 4 to 6 region breaks (median); first brink median 4:30 to 7:00; length median 6:00 to 8:00, p90 at most 10:00, p99 at most 12:00', slice: 'S2 (run with --cap=43200)', needs: ['region_broken', 'brink_enter'],
    run({ A }) {
      const D = A.default; assert.ok(!D.some(r => r.timeout), 'matches hit the cap: run with --cap=43200 (12 min)');
      const breaks = median(D.map(r => evs(r, 'region_broken').length)), brink = median(D.map(r => Math.min(...evs(r, 'brink_enter').map(e => e.t)) ).filter(Number.isFinite)), lens = D.map(r => r.koAt);
      assert.ok(breaks >= 4 && breaks <= 6, `region breaks median ${breaks}`); assert.ok(brink >= 270 && brink <= 420, `first brink median ${brink.toFixed(0)} s`);
      assert.ok(median(lens) >= 360 && median(lens) <= 480 && q(lens, 0.9) <= 600 && q(lens, 0.99) <= 720, `length median ${median(lens).toFixed(0)}, p90 ${q(lens, 0.9).toFixed(0)}, p99 ${q(lens, 0.99).toFixed(0)}`);
      return `breaks ${breaks}, first brink ${brink.toFixed(0)} s, median length ${median(lens).toFixed(0)} s`;
    } },
  { id: 'W4', spec: 'spec-wounds §5.4', title: 'No loops: 0.5 to 2.0 rallies per match; no region rallied twice; finisher survival 0 after a third rally and after 11:00', slice: 'S4', needs: ['rally', 'finisher_contest'],
    run({ A }) {
      const D = A.default, per = D.reduce((s, r) => s + evs(r, 'rally').length, 0) / D.length;
      assert.ok(per >= 0.5 && per <= 2.0, `rallies per match ${per.toFixed(2)}`);
      noBad('a fighter rallied the same region twice', failing(D, r => { const seen = new Set(); return evs(r, 'rally').every(e => { const k = e.actor + ':' + e.region; if (seen.has(k)) return false; seen.add(k); return true; }); }));
      noBad('finisher survival chance above 0 after a third rally or after 11:00', failing(D, r => evs(r, 'finisher_contest').every(c => {
        const rallies = evs(r, 'rally').filter(e => e.actor === c.target && e.t < c.t).length;
        return !(rallies >= 3 || c.t >= 660) || !c.chance;
      })));
      return `${per.toFixed(2)} rallies per match`;
    } },
  { id: 'W5', spec: 'spec-wounds §5.5', title: 'Spread: no region above 45% of all wear; each of head, arms and legs is the first region broken in at least 10% of matches', slice: 'S3a', needs: ['region_broken'],
    run({ A }) {
      const D = A.default, first = {};
      for (const r of D) { const b = evs(r, 'region_broken')[0]; if (b) first[b.region] = (first[b.region] || 0) + 1; }
      for (const g of ['head', 'arms', 'legs']) assert.ok((first[g] || 0) / D.length >= 0.10, `${g} is first broken in ${(((first[g] || 0) / D.length) * 100).toFixed(1)}% of matches`);
      const w = D.map(r => r.wear).filter(x => x && x[0]);
      if (w.length) {
        const tot = {}; let all = 0;
        for (const per of w) for (const f of per) for (const [reg, v] of Object.entries(f)) { tot[reg] = (tot[reg] || 0) + v; all += v; }
        for (const [reg, v] of Object.entries(tot)) assert.ok(v / all <= 0.45, `${reg} takes ${((v / all) * 100).toFixed(0)}% of all wear`);
      }
      return 'first-broken shares ' + JSON.stringify(first) + (w.length ? '' : ' (wear share not checked: records carry no f.wear)');
    } },
  { id: 'W6', spec: 'spec-wounds §5.6', title: 'Profiles: Cyborg chip takes 0 while the hatch is closed; Anti-hero penalties follow Pride and facade; refit mends shrink; no finisher while Boiling; core wear never decreases', slice: 'F1 (roster fighters)', needs: ['hatch_open', 'facade_crack', 'boil_over'], run: null },
  { id: 'W7', spec: 'spec-wounds §5.7', title: 'Balance: every pairing 45 to 55%; pacing bands still pass; heat-track bands (Boiling reached in 40 to 80%, at most 5% of time, boil-overs at most 0.5 a match, boil-over matches won 35 to 55%, internal wear 10 to 35% of brinks)', slice: 'S2 for pairings, F1 for heat', needs: ['region_broken', 'heat_stage'], run: null },
  // ---------------------------------------------------------------- living destruction hard tests (balance-targets §11)
  { id: 'H1', spec: '§11 hard test', title: 'Hazards never break a region: hazard wear stops at 89', slice: 'LD1 with Wounds S1', needs: ['hazard*', 'region_broken'],
    run({ A }) {
      const bad = [];
      for (const recs of Object.values(A)) for (const r of recs) for (const e of evs(r, 'region_broken')) if (e.cause && /hazard|fire|slide|quake|rift|lava/.test(e.cause)) bad.push(r.seed);
      noBad('a region was broken by a hazard', bad); return 'no region_broken carries a hazard cause';
    } },
  { id: 'H2', spec: '§11 hard test', title: 'Zero casualties from living-destruction effects while the higher tier is 1', slice: 'LD1', needs: ['hazard*'],
    run({ A }) {
      const bad = [];
      for (const recs of Object.values(A)) for (const r of recs) for (const e of (r.events || []).filter(e => e.type.startsWith('hazard') && (e.n || 0) > 0)) if (!(r.tierT[2] >= 0 && e.t >= r.tierT[2])) bad.push(r.seed);
      noBad('hazard casualties at tier 1', bad); return 'no hazard event with casualties before tier 2';
    } },
  { id: 'H3', spec: '§11 hard test', title: 'At most 3 active hazard fronts inside the camera framing at once', slice: 'LD1 (needs S.frontsInFrame from the view side)', needs: ['hazard*'],
    run({ A }) {
      const bad = [];
      for (const recs of Object.values(A)) for (const r of recs) if (r.fronts > 3) bad.push(r.seed);
      noBad('more than 3 fronts in frame', bad); return 'max fronts in frame <= 3';
    } },
  { id: 'H4', spec: '§11', title: 'Effects are credited to the fighter whose event started them; knock-on effects keep the cause; no hazard starts during a finisher or a cinematic', slice: 'LD1 and Wounds S2', needs: ['hazard*', 'finisher_start'], run: null },
  { id: 'H5', spec: '§5b hard tests', title: 'A chain never exceeds the launcher\'s tier cap (2 at tiers 1 and 2, 3 at tier 3, 4 at tier 4; 5 only for a scripted finisher) and the planner drops any chain over its casualty budget (4% at tier 2 or below, 12% at 3, 20% at 4)', slice: 'World buildings-in-depth §4b', needs: ['brunt_chain'], run: null },
];

// Run every test: returns [{ id, spec, title, slice, status: PASS|FAIL|PENDING, detail }].
async function runTests(ctx, only = null) {
  const out = [];
  for (const t of tests) {
    if (only && !only.includes(t.id)) continue;
    const missing = t.needs.filter(n => !hasEvent(ctx.A, n));
    const base = { id: t.id, spec: t.spec, title: t.title, slice: t.slice };
    if (missing.length) { out.push({ ...base, status: 'PENDING', detail: `waiting for ${t.slice}: no ${missing.join(', ')} event in the sim` }); continue; }
    if (!t.run) { out.push({ ...base, status: 'PENDING', detail: `events present, but the check has no body yet: write it against ${t.slice}'s fields` }); continue; }
    try { out.push({ ...base, status: 'PASS', detail: (await t.run(ctx)) || '' }); } catch (e) { out.push({ ...base, status: 'FAIL', detail: String(e.message || e).split('\n')[0] }); }
  }
  return out;
}

module.exports = { tests, runTests };
