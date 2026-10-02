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
