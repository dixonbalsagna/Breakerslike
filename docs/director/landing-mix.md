# The landing mix: the drive and the gated crater slam

Owner: Encounter Systems Director. Date: 2026-10-01. Status: built and measured on a scratch copy (HEAD `13540bf` plus step 2b); applied to the tree when the EP opens the slot.

**Why.** Orb wants landings "weighted towards skidding to a halt", with craters kept as events. Game Design ruled the steps in `docs/design/balance-targets.md` §19, and Combat wrote the vectors in `docs/combat/launch-vectors.md`. This slice is steps 1 and 2. Step 3 (more forward carry on UPPERCUT) is not in it.

## What changed

| Part | Change | Where |
| :--- | :--- | :--- |
| **The slam threshold** | A contact slams when 94% of its velocity is vertical (about 70 degrees). It was 85% | `sim/world/slide.gd` `SLAM_VERT` (World's constant, granted) |
| **SLAM DOWN is a drive** | Down and forward. 25 degrees below level when the target is within 2 bh of the ground, rising evenly to 50 degrees at 12 bh and above. No draw. Its score is unchanged | `launch.gd` `driveDir`; `launch.json` `drive` |
| **CRATER SLAM** (working label; Narrative names it) | The old straight-down vector (0.2, -1.25), as its own candidate. Offered only when a gate is open | `launch.gd` `craterOffered`; `launch.json` `craterSlam` |
| Gate 1: a rival directly below | The target is within 1 bh sideways of the launcher and at least 3 bh lower | `craterSlam.below` |
| Gate 2: the crater set piece | The launcher is at tier 3 or above and has thrown no CRATER SLAM in the last 30 s | `craterSlam.setPiece`; `S.dirS.craterT` |
| Its score | 12 + 4 per tier, + 18 when the target is over 140 units up, then the planner's shared terms. So the hero avoids slamming into a town and the villain seeks it, as for any launch | `craterSlam.score` |
| **Break and finisher launches** | Unchanged. They keep their authored vectors, and the planner's long-haul list is as it was | |
| **The numbers are data** | `data/director/launch.json`, hashed with the combat data | `launch.gd` `data` |

The planner adds CRATER SLAM after SLAM DOWN in its candidate list, so the noise draws keep their order when the gates are shut.

## Results

30 AI matches per column, seeds 1 to 30, one class per launch by its first contact. Before is step 2b.

| Class | Band (§20) | Before | After |
| :--- | :--- | ---: | ---: |
| **Slide** (the first contact starts a slide) | 40 to 55% | 47.9% | **60.3%** |
| ... runs 2 bh or more in the open | | 23.5% | 32.1% |
| ... ends against a rise (a wall stop) | | 22.1% | 24.3% |
| ... under 2 bh in the open | | 2.3% | 3.9% |
| **Slam** (a crater at the first contact) | 8 to 15% | 21.5% | **13.3%** |
| Weak landing (350 or slower) | | 3.5% | 4.8% |
| Caught in the air | 10 to 25% | 17.7% | 14.8% |
| Water | 5 to 15% | 4.5% | 3.8% |
| Brunt | 4 to 10% | 4.9% | 2.9% |

| By vector, after | Share of launches | Slides | Crater | Caught |
| :--- | ---: | ---: | ---: | ---: |
| SMASH ACROSS | 30.7% (was 40.3%) | 75% | 2% | 18% |
| MOUNTAINSIDE | 24.3% | 78% | 1% | 8% |
| SLAM DOWN, the drive | 21.7% (was 14.3%) | 72% | **2%** (was 82%) | 17% |
| CRATER SLAM | 8.2% | 3% | 82% | 5% |
| UPPERCUT | 8.1% | 3% | 61% | 29% |
| BUILDING SMASH | 4.0% (was 7.1%) | | | 26% (74% brunt) |

| Match level (200 matches, seeds 1 to 100 per arm) | Before | After |
| :--- | ---: | ---: |
| Match median, default / swap | 10:25 / 9:59 | 9:22 / 9:35 |
| KAI, default / swap arm | 67% / 54% | 66% / 58% |
| Launches per minute | 11.1 | 13.4 |
| Structures lost at the KO | 28 to 29% | 23 to 25% |
| Chain links per match | 81 to 83 | 78 |

## Notes for QA, World and Game Design

- **QA's landing rule counts three kinds of slide as slams.** In `qa/godot/records.gd` a launch is a slam if a crater comes first. A slide that ends against a rise digs its stop dent before its `slide` event, so it is counted as a slam: 22 to 24% of all launches. Short slides and weak landings are counted as slams too. By that rule this slice reads slide 22% to about 32% and slam 50% to about 46%. World's `land` events (kind skid, tumble, slam or stop) will class the first contact directly.
- **Half of the wall stops are short.** 12.3% of launches slide under 2 bh into a rise, mostly MOUNTAINSIDE (22% of its launches) and SMASH ACROSS (11%). They read as a stop, not a skid. That is terrain, not the vector.
- **Brunt and water are under their bands** (2.9% and 3.8%). The drive takes launches that went to buildings before. The B2 pity counter is unchanged.
- **Launches rose** from 11.1 to 13.4 a minute, and matches are about 45 s shorter. A slide's recovery is 0.35 s against a slam's 0.75 s, so the fight restarts sooner.
- **UPPERCUT is still a slam** when nobody catches the fall (61%). That is step 3.
- **The crater set piece** comes at most once per 30 s per fighter from tier 3. In play CRATER SLAM was 8.2% of launches. With a base score of 20 it was 10.8%, and slams 15.8%.
