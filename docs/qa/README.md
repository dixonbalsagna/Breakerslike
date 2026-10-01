# QA on the GDScript sim

Owner: QA and Balance. Since ADR 0006 the GDScript sim is the source of truth. QA measures it in headless Godot; the Node prototype suite (`node qa/run-all.js`) is the **legacy** guard for the pinned prototype and the frozen JS core, and stays as it is.

## Commands (repo root)

| Command | What it does | Time |
| :--- | :--- | :--- |
| `node qa/run-godot.js` | 400 matches in each of the 8 arms, all band checks, the acceptance-test skeletons, the slice S0 re-test | about 25 min on 6 jobs (the machine rule: at most 6 Godot processes) |
| `node qa/run-godot.js --quick` | default and swap arms, 100 matches | about 30 s |
| `node qa/run-godot.js --md=docs/qa/baseline-g0.md` | also writes the report | |
| `node qa/godot/selftest.js` | proves the skeletons and the evaluator work on synthetic records (no Godot) | 1 s |
| `node qa/run-all.js` | legacy: prototype and frozen-core suite (tables, determinism, seam, soak, diff, known bugs, self-test) | about 90 s |

The run also executes Combat's dynamic-feel probe (`qa/godot/feel/feel_probe.gd`, 40 default-arm matches, one Godot process; `--feel=N`, `--feel=0` skips) and reports the §10 dynamic-feel targets: melee idle share, still stretches, first strike, strike gaps, strikes per minute, release to next request, standoffs, time inside exchanges, hit-stop share. `qa/godot/feel/proto_probe.js` is the same probe on the prototype. `--save-records=file` / `--load-records=file` keep the records so bands can be re-evaluated without replaying.

Options: `--matches=N --jobs=N --arms=a,b --scale=testbed|game --capsec=900 (sim seconds, S.T) --seed=BASE --fail --json=file --only=bands|tests|s0`. Godot is found through `$GODOT`, then `godot` on the PATH, then the Windows install folder. `QA_GODOT_ROOT=<dir>` points the run at another checkout, for example a `git archive <commit> | tar -x -C <dir>` export of an earlier or a clean commit (copy `qa/godot/` in and run `godot --headless --path <dir> --import` once). That is how a run is made against committed code while the working tree is in flux, and how before-and-after comparisons are made.

**Exit code.** 0, unless the run itself broke (no Godot, NaN, a fighter outside the world) or a hard acceptance test failed. Band FAILs are what a baseline is for, so they fail the run only with `--fail`.

## How it measures

`qa/godot/records.gd` plays seeded AI-vs-AI matches with the sim's own arms (default, swap, mirrors, each with the spawns flipped) and writes one record per match: outcome, collateral, highest tier reached and when, casualties by tier, fight time by biome and underwater, every exchange's length and the gaps between them, launch flights (travel, new biome), the director events read from the feed (as `batch.gd` does), every fx event type counted, and the wounds and hazard events kept in order with their fields. `qa/godot/godot.js` runs blocks of seeds in parallel Godot processes and returns the records in seed order, so the result does not depend on the job count. `qa/godot/bands.js` turns records into pass/fail rows; `qa/godot/pending-tests.js` holds the acceptance skeletons.

Pass rules are the ones in `balance-targets.md` ("How to measure"): a rate passes when the point estimate is in the band and the 95% interval (Wilson, or match-clustered for shares of events) lies inside the band widened by 2 points; a mean or median passes on the point estimate. At 400 matches per arm a timeout or wipe-out rate near its cap can show FAIL on the interval alone; the note says so.

## The band map

| `balance-targets.md` | Checked now | Pending, and what unblocks it |
| :--- | :--- | :--- |
| §1 win rate | KAI over both slots; slot and spawn effects of both mirrors | |
| §2 length | mean, p90, timeouts (testbed); median and percentiles with `--scale=game` | game-scale length needs S2 finishers and the 900 s cap |
| §3 escalation | tier 3 and tier 4 reach | transformations, finisher in the last 60 s: roster and S2 |
| §4 collateral | civilians mean, worst pairing, 90% wipe-outs, low-tier bleed, **structures as a share of row 1** | **the split by row** appears by itself once buildings carry a `row` (the records already group by it, and the report adds the all-rows watch metric and one line per row); civilians left at 4:00 needs game-length matches |
| §5 launch variety | cap and clustered upper bound in every arm, the 4-types-at-5% floor | |
| §5b building brunts | share of launches, brunts per match, villain above default, hero mirror at most 0.6 | the planner's candidate list (ask Encounter for a `launch_plan` record), brunt-chain events (World) |
| §6 location and variants | biome share and floor, beam variant cap and floor | the 20-planet set: W1 |
| §7 stance | parries, chains, slip rate, beam escape rate | the fixed-stance probe (stance-matrix §6) is not in the sim |
| §8 story beats | hides, ambush, clashes | comebacks, region breaks, finisher call-outs, lead changes: Wounds S1 and S2 |
| §9 KAI gap | KAI at 42% or better (slice S0 target) | |
| §10 tempo | exchanges per minute, exchange length, breathing room and gaps over 10 s, launches per minute, long hauls, new-biome landings, underwater time | strike spacing, wind-up width, hit-stop floors: read from data and atoms once the composer has its event log |
| §11 living destruction | low-tier bleed with all sources | fires, forest burnt, clouds, slides, quakes, lava, hazard share of wear: LD1 to LD3 |

## Acceptance-test skeletons

`qa/godot/pending-tests.js` defines the Wounds tests (spec §5: W1 to W7), the living-destruction hard tests (H1 to H4) and the §5b chain hard test (H5). Each names the fx event types it needs. While they are absent the test is PENDING and says which slice unblocks it; when they appear the body runs for real, with no edit to the file. W1 (determinism) is live today. A test with no body (W6, W7, H4, H5) stays PENDING until it is written against the fields its slice defines. `qa/godot/selftest.js` proves the wiring: each body passes on records that satisfy the spec and fails on records that break it.

The event contract the skeletons assume is written at the top of that file (spec-wounds §4 and `wounds-plan.md`): `region_stage`, `region_broken`, `brink_enter`, `brink_exit`, `rally`, `finisher_start`, `finisher_contest`, `ko`, hazard events with `cause` and `n`, plus two record fields the sim must supply: `f.wear` (per-region wear, for the spread test) and `S.frontsInFrame` (hazard fronts in the camera framing, for H3). If a slice names something differently, change the contract in that file and in `records.gd`.

| Test | Unblocked by |
| :--- | :--- |
| W2 no KO without a finisher; W3 length and chapters | S2 (W3 with the 900 s cap) |
| W4 no loops | S4 |
| W5 spread | S1 and S3a (wear and first-broken region) |
| W6 profiles, W7 heat-track bands | F1 (roster fighters) |
| H1 hazards never break a region; H2 zero tier-1 hazard casualties; H3 three-front cap; H4 attribution | LD1 with Wounds S1 |
| H5 chain tier cap and casualty budget | World buildings-in-depth §4b |

## Slice S0 re-test

Every run ends with the S0 check: KAI at 42% or better, at least 400 matches per arm, both slots. On the committed sim (a clean export of HEAD `78334e7`, which includes S0 from `a46cd90`): **KAI 40.8% [37.4, 44.2]** (43.0% from P1, 38.5% from P2), 400 per arm. Before S0 the same seeds gave 35.5% [32.2, 38.8]. The point estimate misses 42% by 1.2 points; the interval straddles it, so more matches would be needed to say whether it is really under. This matches Simulation's own measurement exactly (same seeds, same sim, same result). The §10 pacing rows still pass except two that the tempo report did not cover: exchange length (median 1.4 s against 2.5 to 4.0) and matches with no gap over 10 s (62% against 95%).

## The baseline

`baseline-g0.md` is the first baseline on the GDScript sim, generated by `node qa/run-godot.js --md=...`. Regenerate it after any intended sim change, in the same commit as the golden update, and diff it against the previous one: the digests change with any behaviour change, and the rows show what moved.
