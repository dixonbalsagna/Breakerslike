# Intro-phase re-tune: mood and wound spread (QA, 2026-10-02)

Owner: QA and Balance. Data only, applied by Simulation at `5e784ac`. This is the record of how the five values were picked and what the committed result reads. The full report of the applied set is `baseline-intro.md` (four arms at 800 on a clean export of `5e784ac`, with the level runs and the masher); earlier baselines are `baseline-contact.md` (`bc857b4`, before the change) and `baseline-step3.md`.

## The values

| File | Key | Before | Now |
| :--- | :--- | :--- | :--- |
| `data/fight/mood.json` | `impulses.form` | 900 | **300** (`rates.decay` stays 3) |
| `data/fighters/KAI/wounds.json` and `VORR/wounds.json` | `cripple.legWeight` | 1.8 | **0.8** |
| same, both fighters | `guardWearSplit.arms` / `.legs` | 0.4 / 0.6 | **0.7 / 0.3** |
| same, both fighters | `cripple.base` | 0.032 | **0.020** |

## Why

**Mood.** Once the form impulse was wired (a `tier_up` event adds `impulses.form` in `mood.gd`'s tick), a form step moved the mood by the impulse and Frenzied rose. On the intro base (`74ede76`, default and swap, 300 per arm):

| `impulses.form` (decay 3) | Calm | Tense | Frenzied | Frenzied in act 4 |
| :--- | :--- | :--- | :--- | :--- |
| 900 (Simulation's sample) | 26.7% (under 30) | 50.7% | 22.5% (over 20) | |
| 600 | 28.0% (under 30) | 52.9% | 19.0% | 24.8% |
| **300** | **30.1%** | 54.3% | 15.6% | 21.7% |

Decay 4 starves Frenzied on this base (4% on step 3), so decay stays 3. Calm is borderline at 300 (30.1%); a lower impulse is the safe direction. The impulse moves only the mood: lengths, wear and results are identical across the three.

**Wound spread.** Step 3 made the AI's best openings heavies (the punish after a blocked string, the reversal, the launching riposte), which wear legs and core, so limb breaks rose and arms fell. Measured on the intro base (default and swap, 300 per arm):

| Set | Limb breaks (0.3 to 0.5) | Arms share (35 to 65%) | Length median | KAI | Survival |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 74ede76 as it was (cripple.base 0.032, legWeight 1.8, split 0.4/0.6) | about 0.64 (Simulation's sample), 0.59 on `bc857b4` | 20% | 446 s (Simulation's sample) | | |
| split 0.6/0.4, legWeight 1.0, base 0.024 | 0.58 | 31.2% | 440 s | 54.8% | 28.2% |
| the same with base 0.020 | 0.55 | 31.1% | 440 s | 54.0% | 28.7% |
| **split 0.7/0.3, legWeight 0.8, base 0.020 (the pick)** | **0.47** | **39.7%** | 440 s | 53.2% | 29.4% |
| split 0.7/0.3, legWeight 0.8, base 0.016 | 0.43 | 39.5% | 440 s | 52.5% | 29.1% |
| the pick plus Encounter's AI lever (punishHeavy 0.5, breakGuard 0.375) | 0.49 | 47.6% | 460 s | 54.3% | 26.7% |

Game Design's order (legWeight 1.0, split 0.5/0.5, base down a fifth) read 0.53 and 32.9% on step 3, just short on both; the arms need the 0.7/0.3 split and legWeight 0.8, and the rate then needs the base at 0.020. The AI lever alone moved limb breaks from 0.62 to 0.57 and the arms from 21.7 to 27.8% on step 3, and stretched the match; added to the pick it changes nothing useful, so it is not in the list. Simulation's 100-match sample of the applied set read arms 33% (two points under); the 800-match figure is 39.3%.

## The result at `5e784ac` (four arms at 800)

Bands 88 pass, 7 fail, 21 pending; hard tests 7 pass, 0 fail.

| Row (band) | `bc857b4` (before) | `5e784ac` |
| :--- | :--- | :--- |
| KAI win rate (45 to 55%) | 51.4% | 47.8% [45.3, 50.2] (48.0% P1, 47.5% P2): no dmgMul change |
| Length median / p10 / p90 | 431 / 320 / 556 s | 445 / 335 / 562 s; no timeouts |
| Limb breaks (0.3 to 0.5) | 0.59 | 0.49 |
| Arms share of limb breaks (35 to 65%) | 20.1% | 39.3% |
| Mood Calm / Tense / Frenzied | 45 / 52 / 3.2% | 31.1 / 54.6 / 14.3% |
| Frenzied in act 4 (at least 15%) | 6.9% | 20.6% |
| Civilians / front-row structures (§21) | 16.9% / 33.5% | 18.8% / 40.8% |
| First brink / brink to KO / survival / rallies | 342 s / 81 s / 31.8% / 0.40 | 352 s / 80 s / 28.6% / 0.35 |
| Perfect blocks per 100: easy / medium / hard | 6.1 / 10.0 / 15.9 | 5.95 / 10.0 / 15.5 (all in band) |
| Exchanges a minute (15 to 26) | | 23.8 |
| Masher, takes forms, 100 matches: easy / medium / hard | 100 / 60 / 5% (40 matches) | 99 / **37** / 8% (all in band: at least 60, 35 to 50, at most 15) |
| Masher, no forms (INFO): easy / medium / hard | 75 / 7.5 / 0% | 83 / 10 / 1% |

Landings (the second landing ruling): halted 43.2% (largest class, band 40 to 60), wall 15.2% (5 to 15: **0.2 over**), slam 17.1%, caught in the air 19.6%, halted as a share of ground endings 57.2%, bounced launches 35.2% (20 to 40), bounces per bounced journey 1.34, crater-lip flights 1.47 a minute, all terrain 3.31, capped journeys 0.0%, journeys over 4,000 units 5.2%, **seen tumbles 30.7% of halted journeys (30 to 60: the row is live and passes by 0.7)**. Water landings 1.8% (2 to 10) and brunt landings 2.6% / planner brunt share 3.6% (4 to 10) fail; launches over 9,000 units of travel 24.1% (30) fails; lock-break median 0.9 s (soft).

**Reach.** 19 of 821,456 damaging strikes beyond 68 units (0.002%, longest 328, down from 31 and 609 on `bc857b4`): default 31 (328), 449 (219), 721 (279); swap 35, 240, 375, 424, 464, 520, 550, 567, 603, 628, 758, 795 (215 to 325); mirror-villain 497, 615; mirror-hero 163, 191. Height beyond 68 only on sloped ground: 4,820 strikes over 68 high, none on flat ground (it was 4 on `bc857b4`).

## The masher

The masher presses light every 8 ticks; `masher.gd` holds the press through hit-stop. Encounter's finding (`docs/director/masher-probes.md`): without transforming a tier-1 fighter takes a tier-3 fighter's blows, so the band is judged on the masher who takes forms (`transform` whenever a form is ready) and the pure masher is INFO. At 200 matches against the medium AI with forms: ground contact off 55 of 200 (27.5%), on 86 of 200 (43.0%); the masher caught the AI in the air on 77% / 78% of its launches in both, so a held attack starts a follow-up on nearly every launch with or without contact; contact added about 4 masher launches and removed about 3 launches against him. At 100 matches the medium row reads 37% on `5e784ac`: inside the band, near its floor (the 95% interval at 100 matches is about 19 points).

## Method

Clean `git archive` exports of each commit with the working tree's `qa/godot/` copied in; variants are patched copies; `QA_GODOT_ROOT` and `QA_SIM_COMMIT` set; seeds 1..N per arm; every Godot launch is `--headless --script` (an `--import` once per export). From here QA uses at most 3 jobs, because each job shows as two Windows processes (the console launcher and the engine).
