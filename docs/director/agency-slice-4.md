# Agency, slice 4: a light-only player can always finish

Owner: Encounter Systems Director. Date: 2026-10-03. Status: in the tree on HEAD `d9e8fa5`, waiting for the EP's commit. Rules: `docs/design/agency-pass.md` §13 (Game Design's urgent ruling on QA's baseline, `docs/qa/baseline-agency1.md`).

Everything of the director's here runs only in the `dynamic` profile. The old profiles are unchanged.

## What changed

| # | Rule | As built | Where |
| ---: | :--- | :--- | :--- |
| 1 | **A knock-back is a decisive exchange** | Every knock-back calls the decisive rule: the brink's set-up, the finisher, Spite. The kind is the exchange's own clause when it has one (a clash won, a guard break, a charge interrupt), and otherwise `knockback`. A guard break had stopped being decisive in slice 1; it is again | `melee.gd` `_knockDecisive`, `launchBeat`; `sim/core/wounds.gd` `BY_HAND` |
| 2 | **A blur always closes** | The light that follows 4 landed strikes of the string is the blur's own ender: a knock-back, never a launch. If no press comes, the chain window's end plays it as one more link, free of ki and of the link cap. A heavy pressed there is still the earned ender (earner 2) | `melee.gd` `launchBeat`; `exchange.gd` `_blurDue`, `_blurEnder` |
| 3 | **The plain blur's ender is the weak one** | 0.6 of the tier's distance: 2.1, 3, 3.9 and 4.8 bh. A skid's speed scales by the square root, so its length follows | `launch.gd` `knock` |
| 4 | **A knock-back hurts** | A knock-back the director carries (the upright slide, the drift in the air) costs half of a launch's impact at the speed he is carried: 0.5 × 0.018 × distance over its time. The skid of 4 bh and over is World's journey and pays World's slide wear (see Notes) | `launch.gd` `knock`; `knockBack.wear`, `knockBack.impactPerSpeed` |
| 5 | **Mashed lights do ×0.8** | The blow of a light press that was mashed (three presses inside 20 ticks) | `melee.gd` `strike` |
| 6 | **A light ender never launches** | No change: a light at a launch decision stays in reach, or is the blur's ender | |
| 7 | **The AI's earner use by difficulty** | `earnerUse` 0.25, 0.6, 1.0 multiplies its launch intent, its held heavy and the chance a far heavy stays a heavy charge, and is the chance its chain press is the heavy ender once the string is full | `alchemy.gd` `log`; `exchange.gd` (the press beat); `ai.gd` |
| | **The medium AI against a masher** | To reach the band it guards a repeated attack a little less and punishes a blocked string less often and less hard: `guardRepeat` 8.75 to 8, `punish` 0.6 to 0.4, `punishHeavy` 1 to 0.5 | `ai.json` `levels.medium` |

**Three values outside the director's data, by the EP's grant:**
- `sim/core/wounds.gd` line 274 (Simulation's): `BY_HAND` gains `"knockback"`, so Spite reads a knock-back as it reads a launch.
- `data/combat/finishers.json` (Combat's): `brinkSetups` 2 to 1, Game Design's fallback for the brink.
- `data/fighters/KAI/wounds.json` and `VORR/wounds.json` (Simulation's): `wearPerDamage` 312 to 336, QA's k +8%.

**Feed lines:** `BLUR ENDER`, `BLUR CLOSES`. The `decisive` event has a new kind, `knockback`.

## Results

**The bands of §13:**

| Measure | Band | Before | After |
| :--- | :--- | ---: | ---: |
| A masher (a light every 8 ticks, takes forms) beats the easy AI | at least 60% | 0 of 100 (QA) | 50 of 50 |
| ... the medium AI | 35 to 50% | 0 of 100 (QA) | 40 of 100 |
| ... the hard AI | at most 15% | 0 of 100 (QA) | 2 of 50 |
| Two lights-only players finish before the 15:00 cap | at least 95% | 0 of 40 (QA) | 40 of 40, median 2:41 |
| AI against AI: first brink to KO, median | 45 to 90 s | 142 s | 66 s |
| AI against AI: match median | 7:00 to 7:30 | 9:02 | 7:25 |

**100 AI matches,** seeds 1 to 100. Before is slice 3 (`ac3e6b7`).

| | Before | After |
| :--- | ---: | ---: |
| Of exchanges reaching a launch decision: a launch | 26.9% | 20.5% |
| ... a knock-back | 24.0% | 31.1% |
| ... both stay in reach | 49.2% | 48.4% |
| Knock-backs a match | 27.1 | 30.5 |
| Match median (10th to 90th percentile) | 9:02 (6:48 to 11:06) | 7:25 (6:00 to 9:04) |
| KAI | 51% | 47% |
| Civilians lost, mean | 25.5% | 18.8% |
| Structures lost, mean | 45.6% | 32.2% |
| Melee exchanges a minute | 24.6 | 25.8 |
| Damage by lights / by heavies | 27.2% / 42.5% | 38.9% / 32.3% |

**The steps on the way** (each on 100 AI matches, with the masher against medium beside it):

| Build | Brink to KO | Match median | KAI | Masher against medium |
| :--- | ---: | ---: | ---: | ---: |
| Rules 1 to 7, medium untuned | 109 s | 8:21 | 44% | 18 of 100 |
| ... medium at `guardRepeat` 7, `punish` 0.4, `punishHeavy` 0.5 | 97 s | 8:53 | 43% | 43 of 100 |
| ... with `brinkSetups` 1 and k at 336 | 67 s | 7:24 | 46% | 52 of 100 |
| ... medium at `guardRepeat` 8 (as built) | 66 s | 7:25 | 47% | 40 of 100 |

**The medium level against the masher** (40 to 100 matches each). With `punish` 0.6 and `punishHeavy` 1, `guardRepeat` did not help: 8.75 gave 18%, 8 gave 5%, 6 gave 18%. With `punish` 0.4 and `punishHeavy` 0.5 it is steep: 8.75 gave 28%, 7.5 gave 39%, 7 gave 41%, 6.5 gave 51%, 5.5 gave 56%, 4 gave 70% (at k 312, `brinkSetups` 2); and 7 gave 52%, 7.5 gave 49%, 8 gave 40% (at k 336, `brinkSetups` 1).

**Gates** (on a clean copy of HEAD with exactly the tree's changes; parity again in the tree): goldens regenerated (9 matches, 178,686 ticks); parity, the loader check at 200 matches, `npm test` 5 of 5, determinism, seam, the animation check, the cue check, Controls' input tests and its mash probe (6 of 6) pass. The validator shows 0 errors with Tools' schemas.

## Notes

- **Two lights-only players' brink to KO is 26 s,** under the band's 45. With `brinkSetups` 1 one knock-back opens a fighter on the brink, and a blur gives one every four lights. The band is met between two AIs (66 s).
- **The endings are out of QA's bands on AI play:** launches 20.5% (band 25 to 35) and knock-backs 31.1% (band 20 to 30). Both follow from the ruling: the medium AI now uses its earners 0.6 of the time, and every full string ends in a knock-back.
- **The skid's wear is not halved.** A knock-back of 4 bh and over is a journey in World's contact model, which pays its own slide wear (by its formula about 0.7 of one impact, capped at one; not measured here). Halving it needs World's flag for a feet slide (`slideFeet`, its next window) and one line in `sim/world/contact.gd` `_pay`. The carried knock-backs (most of them: the air drift and the upright slide) pay the ruled half.
- **The easy AI loses every match to the masher** (50 of 50). The band is "at least 60%".
- **The medium AI is weaker at punishing a blocked string for every player,** not only a masher.
- **A met charge:** §13 says "10 points off the charger's chance". As built (and as §12 c rules), the 10 points come off the answerer's chance: the fighter who was charging has the edge.
- **Combat's note beside `brinkSetups`** in `finishers.json` still describes 2; the value is 1.

## Data keys for Tools

| File | Keys |
| :--- | :--- |
| `data/director/launch.json` | `knockBack.wear`, `knockBack.impactPerSpeed` (numbers, 0 or more), `knockBack._wear`; `blur` {`enderAfter` (integer, 1 or more), `enderDist` (0 to 1), `strikeMul` (0 to 1), `_note`} |
| `data/director/ai.json` | per level `earnerUse` (a chance, 0 to 1); notes `_earnerUse`, `_medium` |
