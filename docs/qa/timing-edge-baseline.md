# Timing-edge baseline on today's sim (QA, 2026-10-02)

HEAD `43f5f21`, no timing rules in the sim (the agency pass is not built). Core matchups from `docs/qa/timing-edge-plan.md`, 40 matches each (so each win share is about ±15 points), scripted players taking their forms, medium AI where an AI plays. Command: `node qa/timing-edge.js --matches=40 --plan=core`. What this shows is the sim before the rules: any timed script should be near 50% against its untimed twin, and the bands in the Band column are the targets once the rules land.


| ID | Matchup | A wins | 95% interval | Band | Verdict | Damage per exchange A / B | Launches earned A / B | Turn-taking | A on-beat |
| :--- | :--- | ---: | :--- | :--- | :--- | :--- | :--- | ---: | ---: |
| T1 | timed (80% of beats) against a masher | 32.5% (13 of 40) | 20.1% to 48.0% | 72 to 82% | FAIL | 251.8 / 390.4 | 33.2 / 39.5 | 61.5% | 77.8% |
| T2 | timed against a style-only player (same mix, never on the beat) | 60.0% (24 of 40) | 44.6% to 73.7% | 62 to 70% | FAIL | 265.8 / 262.5 | 43.3 / 38.6 | 69.2% | 76.8% |
| T3 | style-only against a masher | 20.0% (8 of 40) | 10.5% to 34.8% | 55 to 62% | FAIL | 264.5 / 400.1 | 35 / 41 | 59.4% | 35.9% |
| T4 | mirror: both timed (all else equal) | 62.5% (25 of 40) | 47.0% to 75.8% | 45 to 55% | FAIL | 262.8 / 244.4 | 42.5 / 38.1 | 71.3% | 77.0% |
| T5 | mirror: both style-only | 45.0% (18 of 40) | 30.7% to 60.2% | 45 to 55% | in band, interval wide | 254.7 / 269.3 | 39.3 / 41.5 | 70.0% | 35.1% |
| T6 | timed mash (within 3 ticks) against a plain mash | 35.9% (14 of 39) | 22.7% to 51.6% | 62 to 82% | FAIL | 325.3 / 481.5 | 33.8 / 34.3 | 57.0% | 82.8% |
| T7 | timed hold (released within 6 ticks of the flash) against a plain hold | 67.5% (27 of 40) | 52.0% to 79.9% | 62 to 82% | in band, interval wide | 117.1 / 247.6 | 35.7 / 32.3 | 54.7% | 8.7% |
| T8 | timed against the medium AI | 92.5% (37 of 40) | 80.1% to 97.4% | 60 to 80% | FAIL | 104 / 138.4 | 50.9 / 26 | 38.4% | 75.8% |
| T9 | masher against the medium AI (control-rules 6: 35 to 50%) | 40.0% (16 of 40) | 26.3% to 55.4% | 35 to 50% | in band, interval wide | 119 / 133.5 | 40.7 / 35.5 | 64.9% | 0.0% |

## Reading it

- **No timing edge exists today, as expected.** Timed against its untimed twin: taps 60.0% (T2, 44.6 to 73.7), mash 35.9% (T6), hold 67.5% (T7); the mirrors read 62.5% (T4, both timed) and 45.0% (T5): all inside their intervals around 50%, so these are noise, not an edge. The harness has no bias between the two sides (slot and spawn alternate by seed).
- **Today's sim rewards quantity, not rhythm.** The masher presses about 1,180 times a match against a tapper's 240 and beats every tapper: against the timed tapper 67.5%, against the style-only tapper 80% (T3 reads the style-only player winning 20%), with about 1.5 times the damage per exchange (390 against 252). So on today's rules the band "style-only beats a masher 55 to 62%" starts 35 points short; the agency pass changes this on purpose (a mash is faster and weaker, no ender), so the slice that makes a mash weaker is the one that must carry T1 to T3.
- **Against the medium AI** the timed tapper wins 92.5% (37 of 40; band 60 to 80) and the plain masher 40.0% (band 35 to 50: in band). A skilled input already beats the AI by a wide margin; if the agency pass adds the timing edge on top, T8 will rise further, and the medium AI's levers (`ai.json` guardRepeat, riposte, punish) will need to move to keep it under 80%.
- **Launches:** about half the exchanges end in a launch on today's sim (39.2% of melee exchanges in the 40-match endings check, against the new band 25 to 35%).
- **The scripts read as intended:** the timed taps land on the beat 77 to 83% of the time; the style-only tapper 35% (the beat window is wide, so a random press often lands inside it); the timed hold registers as a hold; the masher reads mash. The timed hold's on-beat share is low (8.7%) because a hold's release, not its press, is what lands on the beat and the on-beat share is taken at the press.

## Next

100 matches per matchup and the accuracy sweep (`--plan=all`) once the agency-pass slice is in (a run of the full plan takes about 25 minutes on 3 jobs). Anything outside its band then points at the slice, and the accuracy curve shows whether the edge is smooth.

# Second baseline: after agency slice 1 (`9e2cbab`)

Encounter's slice 1 (earned launches, knock-backs, STAY) is in; the timing rules are not, so this is still a baseline. 40 matches each, scripted players now throw their heavies with the stick up and toward the rival (`:stick=1`, the way Orb's earned launch is thrown), taking their forms. `node qa/timing-edge.js --matches=40 --plan=core`.


| ID | Matchup | A wins | 95% interval | Band | Verdict | Damage per exchange A / B | Launches earned A / B | Turn-taking | A on-beat |
| :--- | :--- | ---: | :--- | :--- | :--- | :--- | :--- | ---: | ---: |
| T1 | timed (80% of beats) against a masher | 67.5% (27 of 40) | 52.0% to 79.9% | 72 to 82% | FAIL | 231.8 / 438.5 | 31.3 / 9.6 | 73.2% | 77.9% |
| T2 | timed against a style-only player (same mix, never on the beat) | 45.0% (18 of 40) | 30.7% to 60.2% | 62 to 70% | FAIL | 228.3 / 234 | 26.2 / 27.4 | 76.8% | 77.9% |
| T3 | style-only against a masher | 75.0% (30 of 40) | 59.8% to 85.8% | 55 to 62% | FAIL | 246.2 / 445.5 | 29 / 7.9 | 69.8% | 35.5% |
| T4 | mirror: both timed (all else equal) | 52.5% (21 of 40) | 37.5% to 67.1% | 45 to 55% | in band, interval wide | 226.1 / 231.7 | 25.3 / 25.1 | 79.8% | 77.2% |
| T5 | mirror: both style-only | 45.0% (18 of 40) | 30.7% to 60.2% | 45 to 55% | in band, interval wide | 243.2 / 235.9 | 23.9 / 24.8 | 76.0% | 35.6% |
| T6 | timed mash (within 3 ticks) against a plain mash | NaN% (0 of 0) | NaN% to NaN% | 62 to 82% | FAIL | 372 / 599.6 | 1 / 1 | 65.4% | 83.0% |
| T7 | timed hold (released within 6 ticks of the flash) against a plain hold | 55.0% (22 of 40) | 39.8% to 69.3% | 62 to 82% | FAIL | 118.7 / 223.8 | 51.4 / 50.7 | 50.1% | 8.7% |
| T8 | timed against the medium AI | 95.0% (38 of 40) | 83.5% to 98.6% | 60 to 80% | FAIL | 87 / 158.6 | 35.4 / 17 | 36.2% | 76.1% |
| T9 | masher against the medium AI (control-rules 6: 35 to 50%) | 0.0% (0 of 40) | -0.0% to 8.8% | 35 to 50% | FAIL | 95.6 / 128.6 | 2 / 34.4 | 60.9% | 0.0% |

## Reading it

- **The quantity advantage is gone, and the mash with it.** Before the slice the masher beat every tapper (T3 20%); now the style-only tapper beats it 75.0% (Game Design's band for style-only against a masher is 55 to 62) and the timed tapper 67.5% (T1; band 72 to 82). The masher earns about 8 launches a match against the tappers' 25 to 31 and deals nearly twice the damage per exchange (440 against 230), so lights alone no longer launch. The slice did what the agency pass asked; the bands for the masher's own rows now sit on the wrong side.
- **The masher cannot win against the AI at any level.** Masher against the medium AI is 0 of 40 here and 0 of 100 in the baseline's masher rows (easy 0 of 100, medium 0 of 100, hard 0 of 100), where `control-rules.md` section 6 wants at least 60% against the easy AI and 35 to 50% against the medium. It earns 1.5 to 2 launches a match against the AI's 17 to 35, and the easy-AI matches run 626 s because nobody wins. The timed tapper with the stick beats the medium AI 95.0% (T8; band 60 to 80). So a player who throws a stick-directed heavy beats the AI easily, and one who only presses light loses to it by a wide margin: Game Design must say whether a beginner's mash still has to beat the easy AI (it was a standing band) and, if so, which light-only path earns a launch.
- **Two light-only players do not finish a match.** T6 (timed mash against a plain mash) decided 0 of 40: with no earned launch a lights-only match runs to the 15:00 cap. The agency pass allows it (a mash is faster and weaker), but two beginners pressing one button would sit in a stalemate; a brink and finisher path for light-only fights, or the time-cap event, is worth a look.
- **No timing edge yet, as expected.** Timed against its untimed twin reads taps 45.0% (T2), hold 55.0% (T7), the mirrors 52.5% (T4) and 45.0% (T5), all noise around 50%.
- The timed tapper's launches earned per match (25 to 35) are about 3 times the masher's; once timing rules exist the launch-earning edge should widen further.

# Third baseline: after agency slice 4 (`7408870`)

Slice 4 is in (the blur's knock-back ender, knock-backs decisive, the AI's earner use by difficulty, brinkSetups 1, k +8%); the timing rules are still not built. 40 matches each, scripts throw heavies with the stick up and toward the rival and take their forms. `node qa/timing-edge.js --matches=40 --plan=core`.


| ID | Matchup | A wins | 95% interval | Band | Verdict | Damage per exchange A / B | Launches earned A / B | Turn-taking | A on-beat |
| :--- | :--- | ---: | :--- | :--- | :--- | :--- | :--- | ---: | ---: |
| T1 | timed (80% of beats) against a masher | 57.5% (23 of 40) | 42.2% to 71.5% | 72 to 82% | FAIL | 213.7 / 215.8 | 16.5 / 7 | 89.9% | 77.4% |
| T2 | timed against a style-only player (same mix, never on the beat) | 50.0% (20 of 40) | 35.2% to 64.8% | 62 to 70% | FAIL | 208.2 / 199.4 | 21.8 / 20.4 | 81.8% | 76.6% |
| T3 | style-only against a masher | 55.0% (22 of 40) | 39.8% to 69.3% | 55 to 62% | in band, interval wide | 210.9 / 214.4 | 15 / 6.9 | 89.2% | 36.1% |
| T4 | mirror: both timed (all else equal) | 52.5% (21 of 40) | 37.5% to 67.1% | 45 to 55% | in band, interval wide | 199.9 / 202 | 20.9 / 20.6 | 82.2% | 77.1% |
| T5 | mirror: both style-only | 57.5% (23 of 40) | 42.2% to 71.5% | 45 to 55% | FAIL | 213.6 / 204.6 | 20.2 / 20.4 | 82.7% | 35.1% |
| T6 | timed mash (within 3 ticks) against a plain mash | 52.5% (21 of 40) | 37.5% to 67.1% | 62 to 82% | FAIL | 261.1 / 233.3 | 2 / 1.5 | 95.8% | 82.5% |
| T7 | timed hold (released within 6 ticks of the flash) against a plain hold | 30.0% (12 of 40) | 18.1% to 45.4% | 62 to 82% | FAIL | 157.7 / 229.9 | 38 / 45.4 | 62.4% | 7.9% |
| T8 | timed against the medium AI | 85.0% (34 of 40) | 70.9% to 92.9% | 60 to 80% | FAIL | 89.3 / 128.2 | 27.8 / 13.4 | 48.5% | 75.9% |
| T9 | masher against the medium AI (control-rules 6: 35 to 50%) | 45.0% (18 of 40) | 30.7% to 60.2% | 35 to 50% | in band, interval wide | 82.7 / 123.2 | 3.5 / 18.5 | 57.5% | 0.0% |

## Reading it

- **The masher is back inside its AI bands** (T9 45.0% against the medium AI; the baseline's 100-match masher rows read easy 99%, medium 37%, hard 0%), and style-only against a masher is 55.0% (T3; band 55 to 62). The quantity advantage is gone: the masher now deals the same damage per exchange as the others (about 215 each) and earns 3 launches a match against the tappers' 15 to 21.
- **Still no timing edge**, as expected: timed against its untimed twin reads taps 50.0% (T2), mash 52.5% (T6), hold 30.0% (T7); the mirrors 52.5% and 57.5%. Timed against the masher 57.5% (band 72 to 82).
- **Timed against the medium AI 85.0%** (band 60 to 80): a skilled input still beats the medium AI by more than the band allows, before any timing rule exists; the medium AI's levers (earnerUse, guardRepeat, punish) are what to move if the timing edge adds to it.
- Two lights-only players now finish: 60 of 60 matches, median 2:44 (it was 0 of 4 on the slice 3 tree).
