// Acceptance-test skeletons for slices that have not landed: the Wounds acceptance tests (docs/design/spec-wounds.md §5),
// the living-destruction hard tests (balance-targets.md §11, living-destruction-numbers.md) and the §5b chain hard tests.
// A `soft` test measures a tuning target (length, spread, balance): its FAIL is reported but does not fail the run, like a band. Hard tests (determinism, no KO without a finisher, no loops, hazards, ramp) do.
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
  { id: 'W3', spec: 'spec-wounds §5.3', title: 'Length and chapters: 4 to 6 region breaks (median); first brink median 4:30 to 7:00; length median 6:00 to 8:00, p90 at most 10:00, p99 at most 12:00', soft: true, slice: 'S2 (run with --cap=43200)', needs: ['region_broken', 'brink_enter', 'finisher_start'],
    run({ A }) {
      const D = A.default; assert.ok(!D.some(r => r.timeout), 'matches hit the cap: run with --cap=43200 (12 min)');
      const breaks = median(D.map(r => evs(r, 'region_broken').length)), brink = median(D.map(r => Math.min(...evs(r, 'brink_enter').map(e => e.t)) ).filter(Number.isFinite)), lens = D.map(r => r.koAt);
      assert.ok(breaks >= 4 && breaks <= 6, `region breaks median ${breaks}`); assert.ok(brink >= 270 && brink <= 420, `first brink median ${brink.toFixed(0)} s`);
      assert.ok(median(lens) >= 360 && median(lens) <= 480 && q(lens, 0.9) <= 600 && q(lens, 0.99) <= 720, `length median ${median(lens).toFixed(0)}, p90 ${q(lens, 0.9).toFixed(0)}, p99 ${q(lens, 0.99).toFixed(0)}`);
      return `breaks ${breaks}, first brink ${brink.toFixed(0)} s, median length ${median(lens).toFixed(0)} s`;
    } },
  { id: 'W4', spec: 'spec-wounds §5.4', title: 'No loops: 0.5 to 2.0 rallies per match; no region rallied twice; finisher survival 0 after a third rally and after 11:00', soft: true, slice: 'S4 (rate is a tuning target: Game Design rules)', needs: ['rally', 'finisher_contest'],
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
  { id: 'W5', spec: 'spec-wounds §5.5', title: 'Spread: no region above 45% of all wear; each of head, arms and legs is the first region broken in at least 10% of matches (measured and reported from S1, banded once S2 lands)', soft: true, slice: 'S1 (measured), banded from S2', needs: ['region_broken'],
    run({ A }) {
      const D = A.default, first = {};
      for (const r of D) { const b = evs(r, 'region_broken')[0]; if (b) first[b.region] = (first[b.region] || 0) + 1; }
      const dmg = {}; let all = 0;
      for (const r of D) for (const [reg, v] of Object.entries(r.dmgByRegion || {})) { dmg[reg] = (dmg[reg] || 0) + v; all += v; }
      const share = Object.fromEntries(Object.entries(dmg).map(([k, v]) => [k, +(v / all * 100).toFixed(1)]));
      const firstPct = Object.fromEntries(['head', 'core', 'arms', 'legs'].map(g => [g, +(((first[g] || 0) / D.length) * 100).toFixed(1)]));
      const detail = `damage share by region ${JSON.stringify(share)}%; first region broken in % of matches ${JSON.stringify(firstPct)} (${D.filter(r => !evs(r, 'region_broken').length).length} of ${D.length} matches broke no region)`;
      if (!hasEvent(A, 'finisher_start')) return { status: 'INFO', detail };
      for (const g of ['head', 'arms', 'legs']) assert.ok(firstPct[g] >= 10, `${g} is first broken in ${firstPct[g]}% of matches; ${detail}`);
      for (const [reg, v] of Object.entries(share)) assert.ok(v <= 45, `${reg} takes ${v}% of all wear`);
      return detail;
    } },
  { id: 'W6', spec: 'spec-wounds §5.6', title: 'Profiles: Cyborg chip takes 0 while the hatch is closed; Anti-hero penalties follow Pride and facade; refit mends shrink; no finisher while Boiling; core wear never decreases', slice: 'F1 (roster fighters)', needs: ['hatch_open', 'facade_crack', 'boil_over'], run: null },
  { id: 'W7', spec: 'spec-wounds §5.7', title: 'Balance: every pairing 45 to 55%; pacing bands still pass; heat-track bands (Boiling reached in 40 to 80%, at most 5% of time, boil-overs at most 0.5 a match, boil-over matches won 35 to 55%, internal wear 10 to 35% of brinks)', soft: true, slice: 'S2 for pairings, F1 for heat', needs: ['region_broken', 'heat_stage'], run: null },
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
  // ---------------------------------------------------------------- casualty ramp and ceiling (balance-targets §4b), World's wave 1
  { id: 'C1', spec: '§4b rolling budget', title: 'Rolling 60 s casualty budget by the higher tier: 2%, 4%, 8%, 15% of the starting population. No borrowing at tier 1 or 2; at tier 3 and above a set piece may borrow its own per-event budget', slice: 'World collateral ramp (after S2)', needs: ['evacuat*'],
    run({ A }) {
      const BUDGET = [0, 0.02, 0.04, 0.08, 0.15], bad = [], borrow = [];
      for (const recs of Object.values(A)) for (const r of recs) {
        const tl = r.casTimeline;
        for (let i = 0; i < tl.length; i++) {
          const j = tl.findIndex(x => x[0] >= tl[i][0] - 60), back = j >= 0 && tl[i][0] >= 60 ? tl[j][1] : 0, over = tl[i][1] - back - BUDGET[tl[i][2]];
          if (over > 1e-9) (tl[i][2] <= 2 ? bad : borrow).push(r.seed);
        }
      }
      noBad('a rolling 60 s window over budget at tier 1 or 2 (no borrowing allowed)', [...new Set(bad)]);
      return `tier 3+ windows over budget (set-piece borrowing, to be bounded by per-event budgets): ${borrow.length}`;
    } },
  { id: 'C2', spec: '§4b ceiling', title: 'Cumulative ceiling by the highest tier reached so far: 10%, 30%, 60%, 90% of the starting population', slice: 'World collateral cap (after S2)', needs: ['evacuat*'],
    run({ A }) {
      const CEIL = [0, 0.10, 0.30, 0.60, 0.90], bad = [];
      for (const recs of Object.values(A)) for (const r of recs) { let mt = 1; for (const [, cas, top] of r.casTimeline) { mt = Math.max(mt, top); if (cas > CEIL[mt] + 1e-9) { bad.push(r.seed); break; } } }
      noBad('cumulative casualties above the ceiling for the highest tier so far', bad); return 'no match over its ceiling';
    } },
  { id: 'C3', spec: '§4b split', title: 'Per-tier casualty split: casualties by the higher tier at the time, checked against the ramp (tier 1 and 2 together at most about a third of the losses of a match once the ramp exists)', slice: 'World collateral ramp (after S2)', needs: ['evacuat*'], run: null },
];

// ---------------------------------------------------------------- Stage C scripts (docs/controls/stage-c-tests.md)
// Controls writes the 22 scripts as SceneTree scripts in sim/input/test/c01_*.gd and so on (each exits 0 on pass and runs its
// scenario twice for determinism); QA runs them here. A script test is PENDING until its fx events exist (press_ack for the
// press scripts, availability for C19 and C20) AND its script file exists; then it runs for real, one Godot process at a time,
// and passes on exit code 0. The six batch checks (B1 to B6) need bodies written against the events Stage C defines.
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { godot, ROOT } = require('./godot');
const STAGE_C = [
  ['SC1', 'Weight starts light', 'press_ack'], ['SC2', 'Weight sticks across exchanges', 'press_ack'], ['SC3', 'No-op on the current weight (press_ack weight_light once)', 'press_ack'],
  ['SC4', 'Same-tick light and heavy: heavy wins', 'press_ack'], ['SC5', 'Heavy fallback to light when ki is short (press_ack weight_fallback)', 'press_ack'],
  ['SC6', 'Signature queue and cancel (sig_queued, sig_cancelled)', 'press_ack'], ['SC7', 'Unfunded signature waits', 'press_ack'], ['SC8', 'Expiry after 600 ticks (sig_expired once)', 'press_ack'],
  ['SC9', 'Funded signature fires within 180 ticks of sig_funded', 'press_ack'], ['SC10', 'The 180-tick cap pauses during charge', 'press_ack'], ['SC11', 'The cap pauses inside an exchange', 'press_ack'],
  ['SC12', 'A signature has no fallback', 'press_ack'], ['SC13', 'Presses are accepted while charging', 'press_ack'], ['SC14', 'Queue cleared by a KO or a decisive launch', 'press_ack'],
  ['SC15', 'Determinism under press timing', 'press_ack'], ['SC16', 'The AI uses the same input path', 'press_ack'], ['SC17', 'No timing dependence for parry, chain or struggle outcomes', 'press_ack'],
  ['SC18', 'Holds pause attacks', 'press_ack'], ['SC19', 'Transform confirm: 30-tick hold', 'availability'], ['SC20', 'Encore offer: 18-tick hold, 180-tick lapse', 'availability'],
  ['SC21', 'Stance always accepted, debounce 4 and repeat 12', 'press_ack'], ['SC22', 'Acknowledgement on the same tick (press_ack)', 'press_ack'],
];
const scriptFiles = id => { const dir = path.join(ROOT, 'sim', 'input', 'test'), re = new RegExp('^c' + id.slice(2).padStart(2, '0') + '_.*[.]gd$'); try { return fs.readdirSync(dir).filter(f => re.test(f)).map(f => path.join(dir, f)); } catch (e) { return []; } };
for (const [id, title, needs] of STAGE_C) {
  tests.push({ id, spec: 'stage-c-tests §2', title, slice: 'Controls Stage C', needs: [needs], stageC: true,
    run() {
      const files = scriptFiles(id);
      if (!files.length) return { status: 'PENDING', detail: `events present, but sim/input/test/c${id.slice(2).padStart(2, '0')}_*.gd is not written yet` };
      const g = godot(); assert.ok(g, 'Godot not found');
      for (const f of files) {
        const r = spawnSync(g.exe, ['--headless', '--path', ROOT, '--script', 'res://sim/input/test/' + path.basename(f)], { encoding: 'utf8', timeout: 300000 });
        assert.strictEqual(r.status, 0, `${path.basename(f)} exited ${r.status}: ${(r.stdout || '').split('\n').filter(l => /FAIL|ERROR/i.test(l)).slice(0, 2).join(' | ')}`);
      }
      return `${files.length} script(s) passed`;
    } });
}
const BATCH = [
  ['SB1', 'Funded-to-fired: p99 and max at most 180 ticks (paused ticks excluded), 1,000 matches with a scripted queuer', ['sig_funded', 'sig_fired']],
  ['SB2', 'Queue never wedges: no sigQueued older than 600 unfunded or 180 funded ticks, 1,000 matches with random presses', ['sig_queued']],
  ['SB3', 'Weight mix follows the latched weight (within fallbacks), 400 matches per arm', ['press_ack']],
  ['SB4', 'Stance-flick arm wins at most 55% (rulings §12 risk 5)', ['press_ack']],
  ['SB5', 'Ki fairness: sticky heavy against sticky light, neither above 55%; ki-starved fallbacks per match reported', ['press_ack']],
  ['SB6', 'Determinism: 100 seeds with random queue presses, run twice, identical hashes', ['press_ack']],
];
for (const [id, title, needs] of BATCH) tests.push({ id, spec: 'stage-c-tests §3', title, slice: 'Controls Stage C (+ Encounter scheduler for B1, B2)', needs, run: null });
tests.push({ id: 'C-human', spec: 'stage-c-tests §4', title: 'Human checks: readability (80% say what the next attack is and why it has not fired), weightlessness (each "nothing happened" is a missing ack), agency survey against the prototype baseline', slice: 'playtest', needs: ['playtest'], run: null });

// Run every test: returns [{ id, spec, title, slice, status: PASS|FAIL|PENDING, detail }].
async function runTests(ctx, only = null) {
  const out = [];
  for (const t of tests) {
    if (only && !only.includes(t.id)) continue;
    const missing = t.needs.filter(n => !hasEvent(ctx.A, n));
    const base = { id: t.id, spec: t.spec, title: t.title, slice: t.slice, soft: !!t.soft };
    if (missing.length) { out.push({ ...base, status: 'PENDING', detail: `waiting for ${t.slice}: no ${missing.join(', ')} event in the sim` }); continue; }
    if (!t.run) { out.push({ ...base, status: 'PENDING', detail: `events present, but the check has no body yet: write it against ${t.slice}'s fields` }); continue; }
    try { const got = await t.run(ctx); out.push(got && got.status ? { ...base, status: got.status, detail: got.detail } : { ...base, status: 'PASS', detail: got || '' }); } catch (e) { out.push({ ...base, status: 'FAIL', detail: String(e.message || e).split('\n')[0] }); }
  }
  return out;
}

module.exports = { tests, runTests };
