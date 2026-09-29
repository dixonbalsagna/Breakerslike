# S3b: Combat's data, spaced timing, stage penalties and the struggle

Owner: Encounter Systems Director. Status: checkpoint 1 committed (e214eab); checkpoint 2 landed in the GDScript sim, goldens regenerated. Inputs: `docs/design/spec-wounds.md` §1; `docs/architecture/wounds-plan.md` (S3b); `docs/combat/s3b-loader-note.md` and `data-fields.md` §10 (Combat); `docs/controls/rulings.md` §3, §5 and §8 (Controls). Events: `docs/architecture/fx-events.md`.

## Checkpoint 1: the loader (e214eab)

Exchanges, chain links, signatures and finishers are planned from `data/combat/templates.json` and `finishers.json` by `sim/director/data.gd` (`DirData`). The code planners it replaced are gone. `sim/director/tools/loader_check.gd` stays as a regression: every plan is made twice from the same RNG state, once with the live data and once with the frozen parity copy in `sim/director/test/combat-parity/`, and the two must match bit for bit (beats, times, argument key types, tag, RNG state after). Run it with `godot --headless --path . --script res://sim/director/tools/loader_check.gd -- 200 1`.

## Checkpoint 2: what the director does now

| Rule | Where | Notes |
| :--- | :--- | :--- |
| **Spaced timing and authored finishers.** `templates.json` runs the `spaced` profile and `finishers.json` the `authored` one | `data/combat/*.json` (one line each) | Same outcomes, damage, forces and draws as parity, re-timed to §10: exchanges of about 2.7 s |
| **Stances are frozen per exchange (R8).** `requestAttack` stores both fighters' stances; `hit()` reads them for the stance multiplier, the guard-ki drain and the hit family | `exchange.gd`, `sim/core/damage.gd`, `wounds.gd` `family()` | Outside an exchange the live stance is used, as before |
| **Who lost.** The exchange records its loser: the branch's `favours` (attacker or defender), a decisive result, a parry (the attacker), a beam HIT or GUARD (the defender), DODGE or ESCAPE (the attacker) | `exchange.gd`, `beam.gd`, `melee.gd` | Used by the daze. Neutral branches have no loser |
| **Daze.** A fighter with a broken head who lost the exchange is dazed 0.4 s when it ends | `exchange.gd` `endEx` calls `SimWounds.daze` | |
| **Head battered: narrower parry window.** Its first 20% stops counting | `melee.gd` `opWind` | `SimWounds.HEAD_PARRY_NARROW` |
| **Head broken: -0.08 on the defender's rolls.** Every template selector and beam rule, toward the side that gains | `data.gd` `_penalties`, `_adjust` | Threshold selectors by the branch's `favours`; gated selectors lower the defender's chance; bands and the beam's ESCAPE rule raise the attacker's |
| **Legs battered: -0.10 on escape.** The pursuit's slip and the beam's ESCAPE | `data.gd` | `SimWounds.LEGS_SLIP` |
| **Arms battered: weaker guard.** DEFENSIVE takes x0.55 instead of x0.38 | `sim/core/damage.gd` | `SimWounds.ARMS_GUARD_MUL` |
| **Arms broken: x0.8 on the attacker's heavies and signatures** | `sim/core/damage.gd` | No BRACE penalty: BRACE is not in the game yet |
| **No window without a cue.** In the spaced profile a parry window (its start, and the AI's press draw) exists only when a parryable strike follows, and always with `window_open` | `melee.gd` `opWind` | Parity keeps the old behaviour for the loader check |
| **Parry block.** Controls' buffer (4 ticks early), clean ticks (6 light, 8 heavy), Combat's rewards (damage 18, ki 8 or 12 when clean, hit-stop 9 or 12 ticks, pushback 520) and cues `parry` / `clean_parry` | `melee.gd` `strike` | The anti-mash lockout waits for Game Design |
| **Finisher struggle.** `contestOpen` opens a contest window 66 ticks before the contest; presses score against beats at 18, 36 and 54 ticks (±4, debounce 4); chance = 0.15 + 0.10 per hit - 0.05 per miss and per stray, less the tilt past 8:00, floor 0. Still one draw | `exchange.gd` `_opContestOpen`, `_struggleTick`, `_opContestBranch` | The AI on the brink hits each beat with 0.60 (Combat's `aiHitChance`). Rally's penalty waits for S4 |
| **Authored finisher ops.** `cue`, `contestOpen`, `contest` in branch mode, `finalBlow`, `fixedLaunch`, `separate` | `exchange.gd` `runBeat` | `cue` is render-only: no state, no draw |
| **AI parry-press delay** from data, [0.05, 0.54] s | `melee.gd`, `data.gd` `aiParryDelay` | |
| **Blind swings.** A hunting AGGRESSIVE AI swings at a target out of lock with 0.25 per attack beat, paying the lock-lost cost | `ai.gd` `BLIND_SWING` | `lock_lost` now fires (QA's item) |
| **The lull clock is the exchange's.** `GAP_URGE` counts from the last exchange (`exT`), not the last press | `ai.gd` | A press at a launched target is refused but stamped `lastAtkT`, which held the urge off through long flights |
| **Events.** `window_open.n` (chain count), `finisher_start.dur`, `searching.kind` (lock or sweep), new `cue` and `struggle_press` | `sim/core/fx.gd`, `hash.gd`, `view/fx.gd` | fx-events.md lists the fields each type sets |

## Tuning

k (wear per damage) moves from 0.06 to **0.065** (`WEAR_PER_DAMAGE` 390). The spaced timing cuts exchanges per minute by a fifth, so the S2 value ran long. The k sweep (spaced, before the lull-clock change, default arm, seeds 1 to 100):

| k | Median | p90 | p99 | Timeouts | First brink | Contests survived |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.06 (20 matches) | 7:48 | | | | 7:39 | |
| **0.065** | 6:37 | 8:50 | 10:33 | 0 | 6:24 | 21.9% |
| 0.07 | 5:55 | | | 1 | 5:42 | 31.7% |
| 0.075 | 5:36 | | | | | |

## Results

Before is e214eab (S3a behaviour, parity data, k 0.06); after is this checkpoint. Seeds 1 to 100, default arm, `tempo.gd` and `batch.gd`, unless a row says otherwise.

| Spec §5 / §10 measure | Target | Before | After |
| :--- | :--- | ---: | ---: |
| Match length median | 6:00 to 8:00 | 5:34 | 7:06 (6:29 to 7:06 over six blocks of 100 seeds) |
| p90; p99 | at most 10:00; at most 12:00 | 7:45; 8:51 | 9:20; 11:33 |
| Timeouts at 12 minutes | | 0 | 2 (7 in 2,400 across default and swap) |
| First brink, median | 4:30 to 7:00 | 5:27 | 6:51 (6:08 on seeds 101 to 200) |
| First break, median | 1:30 to 2:30 | 3:37 | 4:21 |
| Finisher contests survived | about 30% (QA 20 to 35%) | 23.1% | 25.2% |
| KAI win rate | 45 to 55% | 51% (P1, 100) | 46.3% [43.4, 49.1] over both slots, 1,200 matches (47.5% [44.7, 50.4] before the lull-clock change) |
| Exchanges per minute | 8 to 12 | **12.53** | 9.69 |
| Exchange length, median | 2.5 to 4.0 s | **1.45 s** | 2.75 s |
| Breathing room, median | 1.5 to 4.0 s | 2.58 s | 2.80 s |
| Matches with no gap over 10 s | at least 95% | **88%** | 100% (also swap and both mirrors) |
| Launches per minute | 4 to 6 | 6.11 | 4.52 |
| Largest launch type | at most 40% | SMASH ACROSS 36.6% | SMASH ACROSS 37.2% |
| Long hauls (planner) | at least 30% | 27.6% | 32.0% |
| Slides among ground landings | 60 to 85% | 71.9% | 70.7% |
| Fight time underwater | at most 10% | 1.0% | 1.1% |
| Parries per match (clean) | | 4.93 | 4.54 (about half clean) |
| Building brunts, share of planner launches | 8 to 20% (QA §5b) | 6.6% | **7.9%** |
| Brunts per match: villain mirror; hero mirror | above default; at most 0.6 | | 5.04 and 0.81 against 2.49 |
| Civilians lost, mean | 25 to 50% (QA §4) | 46.9% | **55.8%** |
| `lock_lost` per match | fires | 0 | 0.16 |

Stage-penalty exposure (after, share of exchanges): the defender's arms battered 27%, the attacker's arms broken 16%, the defender's legs battered 8%, the defender's head broken 5%.

## The hero-mirror spawn effect

QA measured -5.6 points, then -3.6, in the hero mirror's spawn-side effect. Two confounds in the arms produce it, and neither is START_X:

1. **The `-flip` arms spawn at pre-scale coordinates.** `SimGolden.applyArm` (`sim/core/tools/golden_recipes.gd`) sets x to 2900 and 2150, the positions before the world scale (x16). That is the western ocean, not the plains by the city: the villain mirror's flip spends 28% of fight time over the ocean against 6% unflipped. The "spawn side" compares two different fights. The fix is `fs[0].x = SimConst.START_X + SimConst.START_GAP` and `fs[1].x = SimConst.START_X`.
2. **Only the first hero gets anguish (QA-003).** `WorldStructures.casualty` feeds anguish to the first fighter with role hero. In a hero mirror slot 0 carries all the anguish (composure lost, ki regen cut) and slot 1 none.

Measured at 400 matches per arm (seeds 1 to 400):

| Hero mirror | Slot effect | Spawn effect |
| :--- | ---: | ---: |
| As the tree is | -0.6 [-4.0, 2.9] | -2.9 [-6.4, 0.5] |
| Flip spawns scaled | **-5.1 [-8.6, -1.7]** | 1.6 [-1.8, 5.1] |
| Flip spawns scaled and anguish to every hero | 1.6 [-1.9, 5.0] | -0.9 [-4.4, 2.5] |

With the flip fixed, the anguish asymmetry shows as a slot effect; with both fixed, both effects are inside ±3 points. The villain mirror is clean either way (spawn 0.4 and 0.5 points).

## Open items

- **Civilians lost rose to 56%** with 7-minute matches (QA's band is 25 to 50%). This is the world budget, like S2's note (World, Game Design).
- **Brunts.** The default share is 7.9% (band 8 to 20%) and the hero mirror 0.81 per match (at most 0.6). Raising the personality weight (`CARE_W`) would move both the right way, but it would also raise collateral, which is already over its band. That needs a ruling first.
- **Slides per match.** QA's 6 to 12 band cannot hold with §10's launch rate (4 to 6 a minute over 6 to 8 minutes is 24 to 48 launches) and the 60 to 85% slide share. The bands need reconciling (QA, Game Design).
- **The first break comes late (4:21)**, as in S2. It meets its band once Rally (S4) lengthens the tail.
- **Mirror arms rename fighters** ("KAI-A"), so Combat's `byFighter` finisher lookup falls back to the generic finisher in mirrors. A stable roster id on fighters would fix it (Simulation, Combat).
- **The parry anti-mash lockout** waits for Game Design. **BRACE** is not in the game.
- **Hiding timers as integer ticks** (optional in the brief) are not done: they belong to `sim/core/hiding.gd` and are inactive for KAI and VORR.
- **The replay header** could carry `DirData.dataHash()`, so a replay names the combat data it was made with (Simulation).
