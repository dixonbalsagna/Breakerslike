# Q10 re-tune: recommended data (QA, 2026-10-02)

Owner: QA and Balance. Data only: Simulation applies these on top of 21390f6. Measured on clean exports of 21390f6 (Simulation's Q10 slice) with the values below patched in; seeds 1..N, cap 900 sim-seconds. Reports: `baseline-q10.md` (21390f6 as committed, 400 per arm), `candidate-q10.md` (the set below, 600 per arm), `baseline-g0.md` (3051c10, before Q10).

## Recommended values

| File | Key | Now (21390f6) | Recommended |
| :--- | :--- | :--- | :--- |
| `data/fighters/KAI/wounds.json` and `VORR/wounds.json` | `wearPerDamage` | 216 (k 0.036) | **312** (k 0.052) |
| same, both fighters | `act1Damping` | 1.30 | **1.00** |
| same, both fighters | `cripple.base` | 0.036 | **0.032** |
| same, both fighters | `cripple.legWeight` | 1.5 | **1.8** |
| `data/fight/mood.json` | `impulses.form` | 600 | **300** |
| `data/fight/mood.json` | `rates.decay` | 3 | **4** |
| `data/director/location.json` | `prowlAfter` | 60.0 | **30.0** |
| same | `prowlTier` | 3 | **2** |
| same | `popW` | 2.0 | **1.0** |
| `data/fighters/KAI/fighter.json` | `stats.dmgMul` | 1.0 | **0.95** |
| `data/fighters/VORR/fighter.json` | `stats.dmgMul` | 1.0 | **1.02** |

`actFloors` stay 0, 600, 1800, 2700 and style stays revision 3. The two `dmgMul` values are placeholders that centre KAI; they go away with the real roster.

Why these move: the slower ladder cuts damage per blow, so everything after the first form stretches (median 600 s, first brink 538 s). Raising k by half (0.036 to 0.052) brings the match back to 7:20 and the first brink to 6:10; `act1Damping` no longer sets act 2 (acts now follow the forms: 99, 211, 305 s), so it goes back to 1.0, and the lower cripple base and heavier leg weight hold limb breaks at 0.49 and the arms share at 61%. The mood sources grew (six form impulses of 600), so the form impulse halves and the decay rises by one; that puts Calm, Tense and Frenzied back at 34, 55 and 11%.

## Result (default, swap, mirror-villain and mirror-hero; KAI from default and swap)

| Row (band) | 3051c10 (before Q10) | 21390f6 as committed (400 per arm) | Recommended (600 per arm) |
| :--- | :--- | :--- | :--- |
| KAI win rate (45 to 55%) | 47.7% | **54.1%** [50.7, 57.6] | 48.5% [45.7, 51.3] |
| Length median (6 to 8 min) | 408 s | **600 s** | 456 s |
| Length p10 (at least 300 s) | 298 s | 482 s | 363 s |
| Length p90 (at most 600 s) | 542 s | **670 s** | 590 s |
| Matches at the 11:00 time-cap event | 0% | **21.9%** | 2.6% |
| Timeouts at 900 s (at most 1%) | 0.0% | 0.0% | 0.0% |
| First brink (4:30 to 7:00) | 341 s | **538 s** | 373 s |
| Brink to KO (45 to 90 s) | 54 s | 44 s | 77 s |
| Finisher survival (25 to 40%) | 34.2% | **13.6%** | 31.8% |
| Rallies per match (0.3 to 0.7) | 0.37 | **0.14** | 0.38 |
| Region breaks (1.5 to 2.5) | 2.06 | 1.76 | 2.17 |
| Limb breaks (0.3 to 0.5) | 0.50 | 0.48 | 0.49 |
| Arms share of limb breaks (35 to 65%) | 57% | **68%** | 61% |
| Mood: Calm / Tense / Frenzied (30 to 55 / 35 to 60 / 5 to 20%) | 60 / 37 / 2.5% | **13 / 40 / 47%** | 34 / 55 / 11% |
| Calm in act 1 (at least 60%) | 91% | 57% | 84% |
| Frenzied in act 4 (at least 15%) | 4.4% | 56% | 17.6% |
| Act 2 / 3 / 4 start (90 to 150, 150 to 240, 270 to 345 s) | 174 / 240 / 296 | 99 / 212 / 315 | 101 / 213 / 309 |
| Style entries / events per fighter (at most 3 / 5) | 4 / 7 | 1 / 1 | 1 / 1 |
| Civilians lost at the KO (25 to 50%) | 28.7 | 22.0 | **16.3 FAIL** |
| Front-row structures lost (40 to 75%) | 52.0 (all rows) | 35.5 | **27.8 FAIL** |
| Landing: slide / slam / caught / water / brunt (§19) | 25 / 54 / 14 / 3 / 4 (old rule) | 54 / 21 / 15 / 3 / 4 (first-contact rule) | 54.0 / 21.5 / 15.4 / 3.0 / 4.1 |

Bands: 21390f6 as committed 58 pass, 19 fail; recommended **73 pass, 5 fail, 23 pending** (hard tests 7 pass, 0 fail). The five that fail: civilians lost, front-row structures lost, the water landing share (3.0% against 5 to 15), MERIDIAN SCAR under the 3% beam floor (2.3% in one run, a location effect), and the lock-break median (0.9 to 1.1 s against 2 to 3, soft since G0).

## What does not move with data

**Collateral is the open question.** Civilians and structures at the KO were 28.7% and 52% at 3051c10 with a 7-minute match; with the slower ladder tier 4 arrives at 5:20 (median) and the fight ends at about 7:30, so the casualty-producing phase is about 2:20 instead of 4:30. In 21390f6 as committed the long match hides this (22%); once the match is the right length it falls to 15 to 16%. I tried every data lever that touches it (800 matches per variant, default and swap):

| Variant | Civilians | Front-row structures | What else |
| :--- | :--- | :--- | :--- |
| the tuned set without a collateral lever | 13.6% | 22.6% | |
| beam structure factor [0.5, 1, 2, 3] (was 0.25 to 1.5) | 13.7% | 22.6% | no effect |
| plus power-up area damage x2 | 13.6% | 22.6% | no effect |
| plus level cap [0.02, 0.06, 0.16, 0.4] | 13.6% | 24.0% | little |
| villain prowls from 30 s at tier 2, hero care halved (the set above) | 15.4% | 26.3% | KAI -3 points |
| ladder thresholds [30, 60, 90] or charge 0.62 | 16.8% and 15.1% | 27.8% and 26.0% | act 4 moves earlier |
| thresholds [30, 55, 80] | 16.7% | 27.9% | act 4 at 256 s: fails its band |
| hero care 0, prowl from the start, variety weight halved | 15.2% | 25.9% | removes the hero's lure (pillar 5) |
| launch force +0.30 per tier | 15.6% | 26.4% | survival and rallies drop under band |
| both of those together | 19.3% | 31.7% | length 474 s, survival 26.7%, at the edge |

The best combination of data levers reaches about 19%, not 25%, and spends the hero's avoidance (pillar 5) and the length band to do it. So this is for Game Design: **re-band civilians lost at the KO to about 12 to 25% and front-row structures to about 20 to 45% for the slower ladder**, or ask World for a code-side lever (casualty and structure damage at tiers 3 and 4, or the time the fight spends over towns). Both bands were set when tier 4 came at about 2:00. I did not touch the bands.

**KAI.** Menace levers (damage cap 0.05 to 0.10, beam power 0.08 to 0.11) did not move it. Direct damage multipliers did: KAI 0.96 alone 54.1%, VORR 1.04 alone 52.9%, 0.94 and 1.03 together 47.8%, the set above (0.95 and 1.02) 48.5% [45.7, 51.3] over 1,200 decided matches.

## Landing rule fixed (Encounter's note)

`records.gd` now classes a launch by its first contact: a launched fighter whose slide has begun took a slide at the first contact, whatever its length and even if it ends against a rise (the stop dent digs its crater before the `slide` event, which is why the event order misread 22 to 24% of launches); a crater at the first contact is a slam; a landing at 350 or slower is a stop (its own class, 2.5%). CRATER SLAM is in the selftest launch list. On 21390f6 as committed the mix is slide 54%, slam 21%, caught 15%, water 3%, brunt 4%, against Encounter's 47.9 and 21.5 on 2b by hand; it now passes the §19 slide, slam, slides-of-ground, caught and brunt bands, and fails water. World's `land` events replace the slide-state read when they exist.

## Style mixer re-check

On 21390f6 (with the mixer's `leaveMaxStancePct` 55 and `leaveHoldS` 15 added) the style rows pass: entries and events 1 and 1 per fighter, shortest label 27 to 30 s, unlabelled 17%. Labels across 400 default matches: rusher 1,400 events, turtle 270, mixer 40, runner a handful, sniper none. My M1b measurements ran the draft as it was, without those two keys (3 entries and 5 events per fighter then, against 1 and 1 now), so those rows probably came from the loader's missing-key default rather than the text. With the fixed label the AI sits in one label for most of a match. The rows pass either way; Narrative should know the AI is now almost always a rusher.

## Method

Clean `git archive` of 21390f6 with the working tree's `qa/godot/` copied in; variants patched from it; `QA_GODOT_ROOT` and `QA_SIM_COMMIT` set; 5 jobs at a time; seeds 1..N per arm. Variant comparisons use default and swap at 300 or 400 per arm (KAI half-width about 3.5 points); the recommended set ran four arms at 600.
