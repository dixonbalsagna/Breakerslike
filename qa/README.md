# QA and balance

Owner: QA and Balance director. Everything here runs on Node built-ins only, with no install step. Written and recorded on Node v24.19.0; use Node 18 or newer.

## Run the regression suite

From the repo root:

```
node qa/run-all.js
```

It takes about 25 seconds (about 10 with `--quick`), prints one line per check, and exits 0 only if everything passes (1 on any failure, 2 on a usage error). That exit code is what CI should use.

| Option | Effect |
| :--- | :--- |
| `--quick` | Soak with 100 matches instead of 1000 (about 10 seconds in total) |
| `--only=seam,soak` | Run only the named test files |
| `--update-golden` | Rewrite `qa/golden-hashes.json` after an intended simulation change (see below) |

## What it checks

| File | Checks |
| :--- | :--- |
| `tests/tables.test.js` | The QA tools' copies of the world width, biome table, stance names, roster and spawn points match `prototype/index.html`, and the director feed still parses (attacks, launches, beams, parries, chains, hides, tier-ups, KO). If this fails the tools are stale, not the sim. |
| `tests/determinism.test.js` | The same seed gives the same result hash and record: back to back, on a fresh prototype instance versus a warmed-up one, in every arm. Different seeds give different matches. An unseeded `newMatch()` equals `newMatch(clockSeed)`. Golden hashes for 11 fixed seeds are unchanged. |
| `tests/seam.test.js` | Fighters flying and dashing across the seam east and west, launched fighters crossing it, the terrain height and a crater straddling it, and AI matches started astride it. Per step: no NaN, x stays in [0, 9600), the shortest-arc move equals velocity times dt, the camera never jumps and follows the short way round. |
| `tests/soak.test.js` | 1000 seeded AI-vs-AI matches (plus 100 in each of the other three arms) with per-step rule checks: no NaN, no crash, no fighter outside the world, ki and power within 0 to 100, HP never above max, casualties never fall or exceed the population, structures lost never fall or exceed the total, building HP never rises, destroyed buildings never return, at most 1% of matches hit the 300 s cap. P0 exit criterion. |
| `tests/selftest.test.js` | Proves the checks above can fail: seven deliberately broken copies of the prototype (no wrap, negative x, clock-seeded RNG, `Math.random` in the sim, NaN, casualties above population, self-healing buildings) must each be caught by the right test, and the real prototype must pass. If a mutation target is rewritten in `index.html` this test fails; update the pattern in the file. |

A failing soak or seam test prints the seed. Replay it with `node prototype/tools/sim-stats.js 1 <seed> --arm=<arm>`.

## Golden hashes

`golden-hashes.json` holds the result hash of 11 fixed matches. It is a tripwire: any change to simulation numbers or behaviour changes a hash and fails the determinism test. When the change is intended, run `node qa/run-all.js --update-golden`, commit the new file with the change, and re-run the balance report. The hashes were recorded on Node v24.19.0. On a different Node major version the golden check is skipped with a notice, because `Math.sin` and friends can differ in the last bit between engines. CI should pin the Node version.

## Balance report

```
node qa/balance-report.js --matches=1000 --unseeded=1000
```

Runs eight arms of 1000 seeded matches (about a minute) and rewrites the region between the `GENERATED` markers of `baseline-p0.md`, plus `baseline-p0.json`. Text outside the markers is hand-written and kept. `--print` shows the tables without touching files. `--unseeded=0` (the default) skips the clock-seeded comparison, which is the only non-reproducible part. Publish one report per phase gate as `qa/baseline-<phase>.md` by passing `--out=qa/baseline-p1.md --json=qa/baseline-p1.json`.

## Batch runner

```
node prototype/tools/sim-stats.js [matches=60] [baseSeed] [--arm=NAME] [--json]
```

With a base seed, match i uses seed baseSeed+i and the output is identical on every run: no timing and no clock appear in it. The `digest` on the first line hashes every match's whole trajectory, so a one-line `diff` of two runs is a complete comparison. Without a base seed the prototype seeds itself from the clock, as before. `--json` prints the full aggregate.

Arms say who sits where. `default` is KAI in P1 and VORR in P2. `swap` exchanges them. `mirror-villain` and `mirror-hero` give both slots the same character. Each has a `-flip` variant that exchanges the spawn points. Together they separate character bias from slot bias from spawn-side bias.

## Files

```
qa/
  run-all.js               one-command suite
  balance-report.js        report generator
  baseline-p0.md / .json   the P0 baseline (report and data)
  golden-hashes.json       tripwire hashes
  lib/check.js             tiny test helper
  tests/*.test.js          the checks above
prototype/tools/
  headless.js              loads prototype/index.html against a mock DOM (QA_HTML env var swaps the file)
  match-runner.js          runs one seeded match and returns a record (outcome, events, hash, invariants)
  stats.js                 confidence intervals, aggregation
  sim-stats.js             batch runner
  screenshot.js            PNG at a given sim time (needs @napi-rs/canvas)
```

## Adding a check

Create `qa/tests/<name>.test.js`, use `require('../lib/check')('name')`, call `t.test(title, fn)` (throw or `assert` to fail) and end with `t.done()`. It is picked up by `run-all.js` automatically. Use `createHarness()` and `runMatch(h, seed, options)` from `prototype/tools/match-runner.js`. Options: `arm`, `invariants: true` for per-step rule checks, `setup(fighters)` to stage a scenario.

## Known issues the harness works around

See the defects table in `baseline-p0.md` (QA-001 to QA-005). The one that matters when reading a result: `newMatch()` leaves `dirS.lastLaunch` and `lastLaunch2` alone, so the harness clears them before each match. Until that is fixed in the simulation, a match started with N in the browser cannot be replayed from its seed.
