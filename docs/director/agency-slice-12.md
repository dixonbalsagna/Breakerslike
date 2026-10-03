# Agency, slice 12: the barrage counts every clean shot

Owner: Encounter Systems Director. Date: 2026-10-03. Status: in the tree on HEAD `1950a50`, waiting for the EP's commit. Rule: `docs/design/agency-pass.md` §21 (QA's GB-009, `qa/known-bugs.md`).

Everything here runs only in the `dynamic` profile.

## What changed

| Part | Rule | Where |
| :--- | :--- | :--- |
| **Any kind of shot counts** | A clean hit of any kind of shot counts toward the barrage's ender: a bolt, or a charged shot at any charge. It was bolts only. Clean is as before: not guarded, not shrugged off, not a deflected shot | `blast.gd` `_barrage` |
| **The window** | 4 clean hits inside 120 ticks close it (was 90). `enderAfter` 4, `immune` 90 and the two distances are unchanged, and so is measured against spammed | `interrupts.json` `blast.barrage.window` |
| **Each shot once** | Every pressed bolt and every bolt of the AI's volley counts once, as before. Bolts fired 20 ticks or less apart share a group for the perfect block; that group is not the barrage's | `blast.gd` `_barrage` |
| **Once for a group** | The shots of a group that is not a run of pressed bolts (one press that makes several shots: a split, a rain) count once for the group. No such kind exists yet, so this is dormant | `blast.gd` `_barrage`; `interrupt.gd` `BAR_GROUP` |
| **The full charged shot** | It still knocks back by itself and is decisive. It also counts as one hit, and the barrage does not close on that same shot | `blast.gd` `_knock`, `hit` |

**State:** the unused integer `BURY_E` is now `BAR_GROUP`; the count of integers is unchanged. **No new event, cue, feed tag or data key.** `BARRAGE ENDER` now says "clean shots". **No core lines.**

## Results

**QA's scripts,** on the build with this slice (before is slice 11's build):

| Row | Before | After | Band |
| :--- | ---: | ---: | :--- |
| E4 pair (a light, light, tapped heavy blaster against a timed melee player), matches that finish before the cap | 0 of 40 (QA, GB-009) | 40 of 40 | at least 95% |
| The same pair: the blaster's wins | | 38 of 40 | E5's band is 40 to 60% |
| Bolt-only player against the medium AI | 30 of 100 | 32 of 100 | 20 to 40% |
| Mixed blaster (light, light, tapped heavy every 24 ticks) against the medium AI | | 45 of 100 | 25 to 45% (starting band) |

The E4 pair's matches now end at a median of 180 s, 7 s after the first brink.

**QA's harness** (`node qa/run-godot.js`, four arms, 100 matches an arm; before is slice 11's build):

| Row | Before | After | Band |
| :--- | ---: | ---: | :--- |
| Blasts' share of damage | 11.4% | 11.6% | 10 to 25% |
| Brink to KO, median | 70.4 s | 75.2 s | 45 to 90 s |
| First brink, median | 398.1 s | 397.2 s | 270 to 420 s |
| KAI over both slots | 49.5% | 47.0% (46.0% from P1, 48.0% from P2) | 45 to 55% |
| Match length, median | 489.1 s | 484.2 s | 360 to 480 s |
| Match length, 90th percentile | 580.7 s | 602.7 s | at most 600 s |
| Front-row structures lost | 52.1% | 52.7% | 25 to 50% |
| The masher against the medium AI | 42 of 100 | 40 of 100 | 35 to 50% |
| Bolt-only against the medium AI (QA's 40-match row) | 9 of 40 | 11 of 40 | 20 to 40% |
| Lights-only mirror, brink to KO | 49.6 s | 49.6 s | 45 to 55 s |
| Finisher survival rate | 33.3% | 28.6% | 25 to 40% |
| Arms' share of limb breaks | 56.8% | 70.3% | 35 to 65% |
| Perfect blocks per 100 melee exchanges | 15.9 | 16.3 | 5 to 15 |

91 bands pass, 17 fail, 21 pending (89, 18 and 21 before). **Outside their bands:** the match median by 4 s, the 90th percentile by 3 s (new), front-row structures by 3 points, perfect blocks by 1.3, and the arms' share of limb breaks by 5 points (new: it moved 13 points between the two builds; the cause was not traced).

**Gates** on a clean copy of HEAD `5c33b4a` with exactly the tree's changes (no sim or data file changed between it and `1950a50`; parity again in the tree): goldens regenerated (9 matches, 174,493 ticks; 177,829 before); parity, the loader check at 200 matches, `npm test` 5 of 5, determinism, seam, the animation check, the cue check, Controls' input tests and its mash probe pass. The validator has no errors and no warnings.

## Notes

- **E5 is now out the other way.** The blaster wins 38 of 40 against the timed melee script. In the trace for GB-009 that script stayed in the far band for the whole time after its brink, so it takes every shot and never closes in. QA's note on a `chase` option for the melee script stands.
- **The mixed blaster sits at the top of its starting band** (45 of 100 against 25 to 45).

## Left for later

- The splitting shot, the rain and the curving shot (§15.5): new kinds in the core first. The once-for-a-group count is ready for them.
