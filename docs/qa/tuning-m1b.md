# M1b tuning: recommended data (QA, 2026-10-01)

Owner: QA and Balance. Data only: Simulation applies these after I1. Measured on clean exports of 3051c10 with the values below patched in; seeds 1..800, cap 900 sim-seconds (S.T). The full report of the final set is `candidate-m1b.md`; the untouched baseline is `baseline-g0.md`.

## Recommended values

| File | Key | Now | Recommended |
| :--- | :--- | :--- | :--- |
| `data/fight/mood.json` | `rates.decay` | 4 | **3** |
| `data/fight/mood.json` | `actFloors` | 0, 600, 1500, 2400 | **0, 600, 1800, 2700** |
| `data/fight/style.json` | whole file | revision 2 | **Narrative's revision 3** (`docs/narrative/style.draft.json`, copied over as it is) |
| `data/fighters/KAI/wounds.json` and `VORR/wounds.json` | `act1Damping` | 0.85 | **1.30** |
| same, both fighters | `wearPerDamage` | 270 (k 0.045) | **216** (k 0.036) |
| same, both fighters | `cripple.base` | 0.048 | **0.036** |

Optional KAI lever (not needed for the 42% gate): `data/fighters/VORR/meters.json`, menace effect `beam_power`, `perPoint` 0.08 to 0.06. It gave 47.0% against 45.5% on the same seeds; the difference is inside the noise (about 2.4 points at 800 per arm), so it is a coin-flip to take. Skip it unless Game Design wants KAI nearer 47%.

Update the `_note` strings with the values (the loader pins nothing here). Why the three wound numbers move together: the act is 1 plus the beats, and the first beats come from wear in act 1, so `k x act1Damping` sets when act 2 starts (0.85 x 0.045 = 0.038 gave 174 s, 1.30 x 0.036 = 0.047 gives 128 s), while `k` alone sets how long the later acts run. A higher damping with a lower k brings act 2 in without shortening the match.

## Result (800 per arm, four arms; KAI from default and swap)

| Row (band) | HEAD 3051c10 | Recommended (f1) | Recommended + beam lever (f2, default and swap) |
| :--- | :--- | :--- | :--- |
| KAI win rate (at least 42%; 45 to 55% for the real roster) | 47.7% | 45.5% [43.1, 47.9] | 47.0% |
| Length median (6 to 8 min) | 408 s | 415 s | 415 s |
| Length p10 (at least 300 s) | **298 s FAIL** | 306 s | 307 s |
| Length p90 (at most 600 s) | 542 s | 557 s | 560 s |
| Timeouts at 900 s (at most 1%) | 0.0% | 0.0% | 0.0% |
| Brink to KO (45 to 90 s) | 54 s | 52 s | 52 s |
| First brink (4:30 to 7:00) | 341 s | 355 s | 355 s |
| Finisher survival (25 to 40%) | 34.2% | 31.2% | 31.4% |
| Rallies per match (0.3 to 0.7) | 0.37 | 0.32 | 0.32 |
| Region breaks (1.5 to 2.5) | 2.06 | 1.94 | 1.96 |
| Limb breaks (0.3 to 0.5) | **0.50 FAIL** | 0.48 | 0.49 |
| Arms share of limb breaks (35 to 65%) | 57% | 54% | 55% |
| Mood: Calm (30 to 55%) | **60.4% FAIL** | 31.3% | 31.4% |
| Mood: Tense (35 to 60%) | 37.1% | 53.0% | 53.1% |
| Mood: Frenzied (5 to 20%) | **2.5% FAIL** | 15.7% | 15.5% |
| Calm in act 1 (at least 60%) | 90.7% | 69.8% | 69.8% |
| Frenzied in act 4 (at least 15%) | **4.4% FAIL** | 17.2% | 16.9% |
| Act 2 starts (90 to 150 s) | **174 s FAIL** | 128 s | 128 s |
| Act 3 starts (150 to 240 s) | 240 s | 219 s | 220 s |
| Act 4 starts (270 to 345 s) | 296 s | 291 s | 292 s |
| Act 4 before the first brink (at least 80%) | 89.5% | 87.9% | 88.3% |
| Style entries per fighter (at most 3) | **4 FAIL** | 3 | 3 |
| Style events per fighter (at most 5) | **7 FAIL** | 5 | 5 |
| Shortest label held (at least 12 s) | 12.0 s | 25.9 s | 25.9 s |
| Unlabelled share (at most 40%) | 19.4% | 29.0% | 29.0% |

Every row in the tuning scope passes with the recommended set: bands 65 pass, 12 fail, 19 pending (HEAD: 58, 19, 19). The twelve that still fail are not in this tuning's scope (list below).

## The path (800 matches, default and swap, each variant)

| Variant | act1Damping | k | cripple | KAI | p10 | Limb | Act 2 | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| t0 mood and style only | 0.85 | 0.045 | 0.048 | 46.4% | 299 s | 0.53 | 174 s | mood and style pass, act 2 and limb not |
| t1 | 1.00 | 0.044 | 0.048 | 45.6% | 271 s | 0.54 | 142 s | too short |
| t2 | 1.15 | 0.040 | 0.048 | 46.4% | 295 s | 0.53 | 131 s | p10 just under |
| t3 | 1.25 | 0.038 | 0.048 | 46.5% | 299 s | 0.58 | 128 s | limb high |
| u1 | 1.25 | 0.037 | 0.040 | 42.4% | 299 s | 0.53 | 132 s | KAI dipped (noise and k) |
| u2 | 1.30 | 0.036 | 0.040 | 44.6% | 316 s | 0.49 | 132 s | passes, KAI 44.6% |
| u3 | 1.25 | 0.038 | 0.040 | 46.6% | 299 s | 0.53 | 128 s | p10 and limb just out |
| u4 | 1.35 | 0.035 | 0.038 | 45.1% | 310 s | 0.52 | 129 s | limb just out |
| **f1 (recommended)** | 1.30 | 0.036 | 0.036 | 45.5% | 306 s | 0.48 | 128 s | all rows in scope pass |

Limb breaks move by about 0.03 from seed noise alone, so do not read the 0.01 steps. KAI at 800 per arm has a 95% half-width of 2.4 points: a single 100-seed block runs from 44% to 55% on the same sim (HEAD blocks: 44.0, 46.5, 46.5, 48.5, 55.0, 50.0, 47.0, 44.0). That is why World's seeds 1 to 100 showed 44% and why nothing here chases KAI below 400 per slot.

## Why KAI looked lower than 48.7%

Default and swap, 600 per arm each, same seeds, clean exports: M1 (4123f3a) 49.1%; B2 (607b826) 46.0%; M1b (f9d94ab) 46.9%; location variety (bcc7976) 46.8%; HEAD (3051c10), 800 per arm, 47.7% [45.2, 50.1]. The earlier 48.7% on fbff4a8 and M1's 49.1% are within a point or two of the rest; if anything moved KAI it was B2 (about 2 points, inside the interval). Not M1b's earlier act 1, not the location slice, not the terrain fixes. The 40 to 44% from the 100-seed check is sampling.

## What still fails on HEAD (not tuning, new since fbff4a8)

1. **Lock breaks that run for minutes.** The hard test "no lock break longer than 4 s" reads the default arm only and passes at HEAD; read over all four arms the same events show long searches: HEAD swap 542 (41 s), mirror-hero 383 (23 s), mirror-hero 700 (**260 s**, from 106 s to 366 s). In the recommended set 7 of 3,019 episodes run 50 to 254 s (default 352 and 363). The episode is a `searching` (kind lock) with no `found` for the target until minutes later. None at M1b (f9d94ab, 0 of 1,115), three at the location slice (bcc7976, up to 67 s). Looks like a hunter that cannot reacquire. For Encounter and Simulation. Repro on a clean HEAD: `node qa/run-godot.js --arms=mirror-hero --matches=1 --seed=700`.
2. **Brunts and landings (B2 and location).** Brunts 0.49 a minute (band 0.10 to 0.35), 5.0% of planner launches (8 to 20%), hero mirror 0.45 a minute (at most 0.15); water skims 13% of launches (3 to 10%); SMASH ACROSS 40.8% of launches (cap 40%). The slide and slam rows read 81% and 63% per launch because they overlap (a slam ends in a slide); those two rows need re-banding on a one-landing-per-launch measure, an open G0 triage item.
3. **W4 (soft):** finisher survival chance above 0 after a third rally or after 11:00 in seeds 55, 161, 190 at HEAD (10 seeds in the recommended set): a rule the sim does not yet apply, or a spec to relax. For Wounds and Game Design.
4. **Lock-break median** 1.0 s against 2 to 3 s (soft since G0), **C1** rolling casualty budget 58.8% of matches over (the ramp is World's, pending).

## Method

Clean `git archive` exports of each commit with the working-tree `qa/godot/` copied in; variants are patched copies of the 3051c10 export; every run on `QA_GODOT_ROOT`, at most 6 Godot processes; seeds 1..N per arm; records saved for re-evaluation.
