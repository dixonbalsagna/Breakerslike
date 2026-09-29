# Tempo and fight location: director and AI changes

Owner: Encounter Systems Director. Status: landed in the GDScript sim (ADR 0006), goldens regenerated. Targets: `docs/design/balance-targets.md` section 10. Code: `sim/director/*.gd`. The frozen JS twins are unchanged.

## What changed

| Area | Before | Now | Where |
| :--- | :--- | :--- | :--- |
| Director cooldown after an exchange | 0.22 s flat | 0.8 s + 0.3 x the exchange's length, capped at 1.5 s | `exchange.gd` `cooldownAfter` |
| AI attack cadence (timer per stance) | AGGRESSIVE 0.35 to 1.0 s, DEFENSIVE 1.2 to 2.5 s, others 0.9 to 1.8 s | 1.2 to 2.5 s, 2.0 to 3.6 s, 1.6 to 3.0 s. The timer runs only between exchanges and is held at the stance minimum during one | `ai.gd` |
| AI attack beats | Always attack | Attack with probability 0.55 (AGGRESSIVE), 0.45 (DEFENSIVE), 0.5 (EVASIVE). Otherwise hold, keep repositioning and charge | `ai.gd` `P_ATTACK` |
| Hero lure | Away from x = 3100 while population near the hero is above 0.2, ending in the western ocean | Also triggers over the sea. Heads for the nearest empty land (not sea, population at most 0.1) by the cheaper route (distance plus 2 x population crossed), searched over the whole planet. A DEFENSIVE hero low on ki charges first | `ai.gd` `heroLure` |
| Height over the sea | AGGRESSIVE matched the opponent's height; hunting always descended | Fighters who are not hiding hold at or above y = 30 over the sea. Underwater is for hiding only | `ai.gd` `SURFACE_Y` |
| ESCAPE cover | Nearest ocean, forest or mountain column | Nearest of each type in each direction. Water costs 1,500 units extra, and running past the opponent costs 1,200 | `ai.gd` `chooseCover` |
| Launch scoring | Fixed terms, with SLAM DOWN +12 over the ocean and +16 in the city | A flight predictor estimates landing and travel. Distance term +12 per 1,000 units (cap 3,000) and new-biome term +10, both only when the landing is open ground (population at most 0.2). Water-landing term -10. SLAM DOWN's ocean and city bonuses removed | `launch.gd` |
| SMASH ACROSS | Flat push (uy 0.18), template force | Long haul: rising arc (uy 0.32) at 2.0 x the template force | `launch.gd` |
| No launch | Every launch beat launched | "NONE" competes at 34 plus noise, scored with the personality term at the target's position. When it wins, the strike shoves the target back 700 units per second and the feed prints `NO LAUNCH` with the top three scores | `launch.gd`, `melee.gd` `launchBeat` |

All numbers are named constants at the top of each file, ready to move to `data/director/` once Tools has a schema.

## Results

The brief's command, `godot --headless --path . --script res://sim/core/tools/batch.gd -- 100 1 --json`, gave these results. Rows the batch runner does not report come from the director tool on the same seeds, `godot --headless --path . --script res://sim/director/tools/tempo.gd -- 100 1`.

| Measure | Target (section 10) | Before | After |
| :--- | :--- | ---: | ---: |
| Exchanges started per minute | 8 to 12 | 21.7 | 11.7 |
| Breathing room, release to next request, median | 1.5 to 4.0 s | 0.75 s | 2.58 s |
| Launches per minute | 4 to 6 | 16.1 | 5.3 |
| Long hauls (1,500+ units from launch to landing) | at least 30% | 0.1% | 32.6% |
| Launches landing in a different biome | at least 25% | 16.5% | 76.6% |
| Fight time underwater | at most 10% | 58.1% | 3.6% |
| Fight time over the ocean | | 68.6% | 10.5% |
| Beams over the ocean | | 71.7% | 11.6% |
| Largest launch type | at most 40% | SLAM DOWN 47.3% | SMASH ACROSS 36.0% |
| Civilians lost, mean (to the KO) | | 37.0% | 31.5% |
| Match length to KO, mean | QA's provisional 40 to 70 s | 57.7 s | 102.0 s |
| Batch digest | | 8452e930e4702fbb | 0ce804f49e96be17 |

Beams by biome after the change: mountains 38%, forest 21%, desert 15%, ocean 12%, village 8%, plains 5%, city 2%.

## Side effects to watch

- **KAI's win rate fell about 7 points** (400 matches per arm, seeds 1 to 400, both slots averaged): 42.2% before and 34.9% after. The cause is location. The ocean was a place where nothing could be destroyed, and on land the villain earns menace.
  - Ablations on the default arm: original 41.3%, tempo changes alone 42.4%, plus the AI location changes (lure, surface hold, cover) 38.3%, plus the final launch planner 35.5%.
  - An early version of the planner cost about 11 points. Its flat long hauls through villages tripled the casualties credited to the villain during the hero's flights (from 16 to 52 a match).
  - Two changes brought the planner's share down to about 3 points: counting distance and new-biome only on open ground, and scoring "no launch" with the personality term.
  - The rules that turn collateral into power (menace, anguish) are Game Design's.
- **Matches are longer** because half as many exchanges means half the damage rate. Game Design's damage model (Wounds) will set the final length.
- **Sim tick cost** rose from 37 to 57 µs mean (`parity.gd` bench), mostly from the lure's route scan, which runs every tick while the hero is off empty land. It is small against a 16.6 ms frame, but it is a cost if rollback replays many ticks.
- Launched fighters still stop dead in water (`sim/core/fighter.gd`), so the planner steers away from water landings rather than using them.

## How to measure

`sim/director/tools/tempo.gd` only observes. It steps matches as `batch.gd` does and reads state and feed lines, so it cannot change behaviour. Arguments: `[matches=100] [baseSeed=1] [--arm=NAME] [--json]`.

## Re-pass at the life-size scale (after World's SC, de1bb05)

The world grew 8 times against the fighters (`WS` 8, planet `PS` 16, `docs/world/scale.md`). Fights drifted back to the sea, BUILDING SMASH took over the planner, and the tick cost rose. What changed in `sim/director`:

| Change | Why |
| :--- | :--- |
| BUILDING SMASH scores height as `h / (32 x WS)`, and its base drops from 12 to 7 | Buildings are 8 times taller, so the old `h / 32` made it win about half of all launches |
| The flight predictor stops at the first standing building, for the flight and for the slide | A throw into a town is scored as the short crash it will be |
| SMASH ACROSS is "long haul or nothing": its force rises (up to 3 x) so the predicted flight reaches 13,200 units, and it drops out below 9,600 | The long haul should actually be long |
| MOUNTAINSIDE aims at the nearest slope ahead, out to 12,480 units (it used to probe one point) | A second throw that can cross real distance |
| Water-landing term -45 (was -10); "no launch" 23 (was 34); UPPERCUT 10 + 12 near the ground (was 14 + 14); SLAM DOWN 18 or 0 plus tier (was 24 or 6); repeat penalties 20 and 10 (were 14 and 5) | Fewer vertical slams and fewer throws into the sea, with launches kept at 4 to 6 a minute |
| No chain window when the launched target is more than 2,500 units away | A chain rush is a 0.24 s blink; catching a long haul in mid-air cut it short |
| AI attack chance per beat 0.62 / 0.5 / 0.56 (was 0.55 / 0.45 / 0.5); after 6 s with no attack from either fighter, beats stop holding | Fewer lulls over 10 s |
| Fighters hold 150 units above the sea (was 30) and dash back up when underwater and not hiding | Less time underwater |
| The hero's lure reads one population histogram per tick, with no helper calls in its loops; escape cover is computed from the biome table | Recovers the tick cost |

Results over 400 matches per arm (seeds 1 to 400), from `tempo.gd`, before (de1bb05) → after:

| Measure | Target | Default | Swap | Villain mirror (after) |
| :--- | :--- | :--- | :--- | ---: |
| Exchanges per minute | 8 to 12 | 10.7 → 12.0 | 10.8 → 12.2 | 13.6 |
| Launches per minute | 4 to 6 | 4.6 → 4.1 | 4.9 → 4.3 | 4.4 |
| Largest launch type | at most 40% | BUILDING SMASH 49.3% → SMASH ACROSS 32.0% | 52.5% → 32.9% | BUILDING SMASH 38.6% |
| BUILDING SMASH share | 8 to 20% (§5b) | 49.3% → 19.6% | 52.5% → 19.0% | 38.6% |
| Long hauls (9,000 units, 120 bh) | at least 30% | 27.0% → 27.3% | 24.7% → 27.9% | 18.8% |
| New-biome landings | at least 25% | 42.6% → 41.5% | 42.7% → 43.5% | 41.2% |
| Slides among ground landings | 60 to 85% | 52.7% → 57.6% | 53.5% → 58.4% | 51.2% |
| Fight time underwater | at most 10% | 13.9% → 9.7% | 11.6% → 9.9% | 7.3% |
| Gaps over 10 s (count per 400 matches) | | 492 → 296 | 483 → 272 | 129 |
| Timeouts at 300 s | at most 1% | 11 → 2 | 13 → 3 | 2 |
| Match length, mean | | 127 s → 109 s | 122 s → 108 s | 94 s |
| KAI win rate | | 43.4% → 38.9% | 38.5% → 39.3% | |

KAI over both slots: 41.0% before and 39.1% after, a change within noise at this sample size. Sim tick (`parity.gd` bench, run alone): 81 µs mean after SC (EP's figure) → 61.2 µs, p99.9 766 µs, max 1.4 ms.

Two bands stay just short:
- **Long hauls** are 27 to 28% against 30%. SMASH ACROSS is about a third of launches and about 80% of them now go long. More would push it toward the 40% cap. S2's break launches are long by rule and will add to the share.
- **Slides** are 57 to 58% against 60%. SLAM DOWN and UPPERCUT are vertical by design and still about a third of launches.
