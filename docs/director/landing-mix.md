# The landing mix: the drive and the gated crater slam

Owner: Encounter Systems Director. Date: 2026-10-01. Status: in the tree on HEAD `75ecefc` (after Simulation's `08f5cd0`), goldens regenerated.

**Why.** Orb wants landings "weighted towards skidding to a halt", with craters kept as events. Game Design ruled the steps in `docs/design/balance-targets.md` §19, and Combat wrote the vectors in `docs/combat/launch-vectors.md`. This slice is steps 1 and 2. Step 3 (more forward carry on UPPERCUT) is not in it.

## What changed

| Part | Change | Where |
| :--- | :--- | :--- |
| **The slam threshold** | A contact slams when 94% of its velocity is vertical (about 70 degrees). It was 85% | `sim/world/slide.gd` `SLAM_VERT` (World's constant, granted) |
| **DRIVE DOWN** (it was SLAM DOWN; Legal cleared the name) | Down and forward. 25 degrees below level when the target is within 2 bh of the ground, rising evenly to 50 degrees at 12 bh and above. No draw. Its score is unchanged | `launch.gd` `driveDir`; `launch.json` `drive` |
| **CRATER SLAM** | The old straight-down vector (0.2, -1.25), as its own candidate. Offered only when a gate is open | `launch.gd` `craterOffered`; `launch.json` `craterSlam` |
| Gate 1: a rival directly below | The target is within 1 bh sideways of the launcher and at least 3 bh lower | `craterSlam.below` |
| Gate 2: the crater set piece | The launcher is at tier 3 or above and has thrown no CRATER SLAM in the last 30 s | `craterSlam.setPiece`; `S.dirS.craterT` (Simulation's granted lines) |
| Its score | 12 + 4 per tier, + 18 when the target is over 140 units up, then the planner's shared terms. So the hero avoids slamming into a town and the villain seeks it, as for any launch | `craterSlam.score` |
| **Break and finisher launches** | Unchanged. They keep their authored vectors, and the planner's long-haul list is as it was | |
| **The numbers are data** | `data/director/launch.json`, hashed with the combat data. Schema `director-launch.schema.json` (Tools, `apply-launch.cjs`) | `launch.gd` `data` |

The planner adds CRATER SLAM after DRIVE DOWN in its candidate list, so the noise draws keep their order when the gates are shut.

## Results

30 AI matches per column, seeds 1 to 30, one class per launch by its first contact. Before is HEAD `75ecefc` (QA's retune).

| Class | Band (§20) | Before | After |
| :--- | :--- | ---: | ---: |
| **Slide** (the first contact starts a slide) | 40 to 55% | 46.8% | **59.0%** |
| ... runs 2 bh or more in the open | | 23.6% | 31.9% |
| ... ends against a rise (a wall stop) | | 20.8% | 23.2% |
| ... under 2 bh in the open | | 2.4% | 3.9% |
| **Slam** (a crater at the first contact) | 8 to 15% | 20.5% | **13.2%** |
| Weak landing (350 or slower) | | 3.3% | 3.7% |
| Caught in the air | 10 to 25% | 19.8% | 17.7% |
| Water | 5 to 15% | 3.4% | 2.6% |
| Brunt | 4 to 10% | 6.2% | 3.8% |

| By vector, after | Share of launches | Slides | Crater | Caught |
| :--- | ---: | ---: | ---: | ---: |
| SMASH ACROSS | 32.4% (was 41.5%) | 71% | 3% | 23% |
| MOUNTAINSIDE | 23.4% | 82% | 1% | 9% |
| DRIVE DOWN | 20.0% (SLAM DOWN was 11.9%) | 73% | **2%** (was 84%) | 18% |
| UPPERCUT | 8.9% | 4% | 59% | 29% |
| CRATER SLAM | 7.0% | 4% | 87% | 4% |
| BUILDING SMASH | 5.5% (was 7.9%) | | | 30% (70% brunt) |

| Match level (200 matches, seeds 1 to 100 per arm) | Before | After |
| :--- | ---: | ---: |
| Match median, default / swap | 7:30 / 8:08 | 7:24 / 7:14 |
| KAI, default / swap arm | 45% / 53% | 64% / 50% |
| Launches per minute | 11.3 | 13.1 |
| Structures lost at the KO | 22 to 24% | 18 to 19% |
| Chain links per match | 62 to 64 | 59 to 61 |
| Signatures per match, mean | 2.5 to 2.6 | 2.3 to 2.5 |
| Matches losing over 10% of structures before tier 3 | 8 of 200 | 12 of 200 |

## Notes for QA, World and Game Design

- **KAI rose** from 49% to 57% over both arms. One arm moved 19 points and the other fell 3, so part of it is noise at 100 matches an arm. On the old base the same slice moved it 1.5 points. QA should re-measure.
- **QA's landing rule counts three kinds of slide as slams.** In `qa/godot/records.gd` a launch is a slam if a crater comes first. A slide that ends against a rise digs its stop dent before its `slide` event, so it is counted as a slam: 21 to 23% of all launches. Short slides and weak landings are counted as slams too. World's `land` events (kind skid, tumble, slam or stop) will class the first contact directly.
- **Half of the wall stops are short.** 12.1% of launches slide under 2 bh into a rise, mostly MOUNTAINSIDE (25% of its launches). They read as a stop, not a skid. That is terrain, not the vector.
- **Brunt and water are under their bands** (3.8% and 2.6%). The drive takes launches that went to buildings before. The B2 pity counter is unchanged.
- **Launches rose** from 11.3 to 13.1 a minute. A slide's recovery is 0.35 s against a slam's 0.75 s, so the fight restarts sooner.
- **UPPERCUT is still a slam** when nobody catches the fall (59%). That is step 3.
- **The crater set piece** comes at most once per 30 s per fighter from tier 3. In play CRATER SLAM is 7.0% of launches.
- **Names.** QA's lists and Narrative's glossary still say SLAM DOWN; the planner, the feed and the `launch_plan` event now say DRIVE DOWN.
