# Balance baseline, phase P0

Owner: QA and Balance. Subject: `prototype/index.html` as of the seeded `newMatch()` change, on Node v24.19.0.

Sample: 8,000 seeded AI-vs-AI matches (eight arms of 1,000, seeds in section 1) plus 1,000 clock-seeded matches for the equivalence check in section 11. There is one AI at one skill level, so "equal skill" holds by construction. These numbers describe how the AI plays the prototype, not how people will.

Everything between the `GENERATED` markers is written by `node qa/balance-report.js --matches=1000 --unseeded=1000` (about a minute) and can be regenerated. Everything outside them is hand-written and is kept when the report is regenerated. Section numbers below refer to the generated tables.

## Where the charter's "done when" stands

| Criterion | Baseline | Status |
| :--- | :--- | :--- |
| Win rate 45 to 55% for every pairing at equal skill | KAI 41.8% (95% CI 39.7 to 44.0), VORR 58.2% | **Fails** |
| Average match length within target range | 55.4 s mean to KO (CI ±1.2), p10 37 s, p90 77 s. No target exists yet. | Passes the provisional band below |
| CI runs the suite on every change | The suite is one command, `node qa/run-all.js`, about 20 s. | Waiting on Tools and Pipeline |

Provisional length band (my call as owner of the release quality bar, until Game Design sets one): mean 40 to 70 s to KO, p90 at most 100 s, no match reaching the 300 s cap. Game Design can replace it through the EP.

## Findings, most important first

1. **VORR beats KAI about 58 to 42, and it is the characters, not the slots.** With the slots swapped the result follows the character: KAI wins 42.3% from P1 and 41.3% from P2 (section 2). Separating three factors with spawn-flipped arms (2b): character -8.5 points against KAI (95% CI -10.1 to -7.0), slot +0.7 (not significant), spawn side -0.2 (not significant). The levers in the code that tilt this: the villain's `menace` bonus to damage (up to +25%) and to ki regeneration, against the hero's comeback bonus (up to +50% at low HP) and `anguish` penalty to regeneration, plus VORR moving at 0.95 of KAI's speed. Tuning belongs to Game Design and Simulation; QA will re-run the same seeds after every change.
2. **SLAM DOWN is 46.4% of launches (cap 40%; 95% CI 45.6 to 47.2 clustered by match).** It is over the cap in 3 of 4 arms (section 5). This confirms the EP's 42% from the 60-match run and says it is a little worse. The scoring gives SLAM DOWN +12 over the ocean, +16 in the city and +8 in forest, and the AI fights mostly over the ocean (finding 3).
3. **Fights drift to the ocean, so signature variety collapses.** 69.4% of beams (CI 67.4 to 71.5) fire over the ocean, which is 26% of the planet, and the fighters spend 64.6% of their time there while the city gets 5.4%, the forest 1.2% and the desert 1.1% (section 6). FIRESTORM and GLASS TRENCH are 1% of beams each and RIDGE BORE 3%, so pillar 7 ("signatures adapt") is barely visible in AI play. Beam biome simply follows fight location. The cause is positional: in the villain mirror, where nobody flees the city, ocean beams drop to 23% and city beams rise to 43%. The hero AI's population-avoiding lure and its cover-seeking in the ESCAPE stance carry the fight to the western ocean.
4. **Collateral is on target for the shipped pairing but the spread is wide.** 38.7% of civilians (±1.7) and 14.1 of 47 structures are lost on average, matching the earlier 35 to 40% and 12 to 14 (section 4). One match in twenty (5%) loses 90% or more of the civilians and the worst lose all of them. Without the hero's lure (villain mirror) the mean is 64% and 20% of matches lose 90% or more, which is what the "no fight destroys the planet at low tiers" P3 criterion will have to be checked against.
5. **Match length is healthy and never stalls.** Mean 55.4 s to KO (58.4 s with the 3.0 s KO tail the older tools included, matching the EP's 59 s), median 51 s, 6% of matches over 90 s, and no match hit the 300 s cap in 8,000. The longest, 274 s in the default-flip arm, came within 26 s of it, so a stalemate is possible and the suite fails if more than 1% of matches time out (section 3).
6. **The director does not yet meet the P2 exit criterion "at least two authored outcomes per stance pairing".** A DEFENSIVE defender gets exactly one outcome for each attack kind (guard holds, guard break, guard). TRADE BLOWS is the only outcome against an AGGRESSIVE defender's light attack, although the code has two branches (attacker wins or defender wins) that the feed does not distinguish. CHARGING defenders are almost never attacked (73 of 19,670 exchanges, melee and beams together) and always get one outcome. An attacker in the ESCAPE stance never attacks at all, because the AI does not attack from ESCAPE, so 5 of the 20 attacker-and-defender pairings are never exercised (section 7).
7. **Parry, chain, hide and ambush rates** (section 8): 9.1 parries per 100 melee exchanges (1.46 a match, split evenly between P1 and P2), 24% of exchanges chain (mean length 2.4, five-hit chains are 13 in 1,000 matches), 0.63 hides a match with 38% of matches containing one, 2 to 3 hidden seconds a fighter, and 0.061 ambush attacks a match, about one hide in ten. Ambush is the least exercised mechanic.
8. **Aggression wins.** Winners spend 55% of the match in AGGRESSIVE against 43% for losers, and losers spend 13% in ESCAPE against 7% for winners (section 9). If the stances are meant to be a real choice, the current numbers make aggressive play the dominant strategy for this AI.
9. **The seam is a hot path.** 76% of default matches cross it, because the ocean straddles it. The largest single-step move anywhere is 186 units (section 10), across all eight arms, well inside the 300-unit alarm the suite uses.

## Defects and risks found while building the baseline

| ID | Finding | Owner to fix | Severity |
| :--- | :--- | :--- | :--- |
| QA-001 | `newMatch()` does not reset `dirS.lastLaunch` and `dirS.lastLaunch2`, so a match depends on the one played before it. In a test of 40 seeds, 38 played out differently when another match had run first. The harness clears them, so the baseline is unaffected, but a browser match started with N cannot be replayed from its seed, and replay is a P2 exit criterion. A two-line fix inside `newMatch()`. | Simulation | Medium |
| QA-002 | Cosmetic effects draw from the simulation RNG (`spark`, `debris`, `dust`, `splash`, `fire`, and the charge sparks all call `R()` or `rng()`). Demonstration: making `spark()` draw one extra random number changed the trajectory of 100 of 100 seeded matches and the winner of 56 of them. Any VFX change therefore rewrites gameplay, and rollback netcode and replays would desync. Cosmetic effects need their own RNG. | Simulation, VFX | High for P5 netcode, low today |
| QA-003 | `casualty()` gives anguish to the first `hero` in the fighter list only. In a hero mirror only P1 accrues anguish. Not significant in the data (slot -1.4 points, CI -3.6 to +0.8) and irrelevant while there is one hero. | Simulation | Low |
| QA-004 | Event statistics are parsed from the text of the director feed, because the sim exposes no structured event log. A reworded feed line silently zeroes a statistic. `qa/tests/tables.test.js` fails loudly if a core event stops parsing, and lists any unclassified new lines. A structured log (event type, actor, target, outcome) would remove the dependency. | Simulation, Tools | Medium |
| QA-005 | Golden hashes and any float-exact comparison depend on the JavaScript engine's `Math.sin`, `Math.pow` and friends. They were recorded on Node v24.19.0 and the golden test is skipped, with a notice, on a different Node major version. CI should pin the Node version. | Tools and Pipeline | Low |

## What was checked for "no behaviour change beyond seeding"

The seed argument is the only change to `prototype/index.html`. With no argument `newMatch()` runs the same clock-based line as before. Two checks: the original file from commit 111b1a1 with the clock forced to a value S produced the same result hash as the edited file called as `newMatch(S)` for 200 of 200 odd S (bit-identical trajectories, feed and world state). And 1,000 clock-seeded matches match the seeded baseline on every statistic tested, all |z| < 3 (section 11). Differences under about 2 points in civilians lost between two independent 1,000-match blocks are sampling noise at this size.


<!-- BEGIN GENERATED -->
### 1. Runs
| Arm | Slots | Seeds | Matches | Decided | Timeouts | Batch digest |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| default | KAI in P1, VORR in P2 (as shipped) | 100001..101000 | 1000 | 1000 | 0 | `70142afa31be898c` |
| swap | VORR in P1, KAI in P2 | 200001..201000 | 1000 | 1000 | 0 | `86738d600130e80e` |
| mirror-villain | VORR-A in P1, VORR-B in P2 | 300001..301000 | 1000 | 1000 | 0 | `daa96ee4f9845c4b` |
| mirror-hero | KAI-A in P1, KAI-B in P2 | 400001..401000 | 1000 | 1000 | 0 | `ec30f985e2b9d9bd` |
| default-flip | KAI in P1 starting east, VORR in P2 starting west | 500001..501000 | 1000 | 1000 | 0 | `5e260644d1e8bb29` |
| swap-flip | VORR in P1 starting east, KAI in P2 starting west | 600001..601000 | 1000 | 1000 | 0 | `383eb99df5a5226d` |
| mirror-villain-flip | VORR-A in P1 starting east, VORR-B in P2 starting west | 700001..701000 | 1000 | 1000 | 0 | `df6936eec44a113e` |
| mirror-hero-flip | KAI-A in P1 starting east, KAI-B in P2 starting west | 800001..801000 | 1000 | 1000 | 0 | `350c4e0a9c52c60b` |

Reproduce any row: `node prototype/tools/sim-stats.js 1000 <first seed> --arm=<arm>` prints the same digest. Full command for this report: `node qa/balance-report.js --matches=1000 --unseeded=1000`. Node v24.19.0.

### 2. Win rate, with slot bias separated from character bias
Intervals are Wilson 95% and use decided matches only (timeouts excluded).

| Arm | P1 wins | P1 win rate | 95% CI | In 45 to 55%? |
| :--- | ---: | ---: | ---: | ---: |
| default (KAI in P1) | 423 of 1000 | 42.3% | 39.3% to 45.4% | **FAIL** |
| swap (VORR in P1) | 587 of 1000 | 58.7% | 55.6% to 61.7% | **FAIL** |
| mirror-villain (VORR-A in P1) | 555 of 1000 | 55.5% | 52.4% to 58.6% | **FAIL** |
| mirror-hero (KAI-A in P1) | 480 of 1000 | 48.0% | 44.9% to 51.1% | watch |

| Measure | Value | 95% CI | Reading |
| :--- | ---: | ---: | ---: |
| **KAI win rate, averaged over both slots** | 41.8% | 39.7% to 44.0% | **FAIL**  (character balance; slot bias cancels out) |
| **VORR win rate, averaged over both slots** | 58.2% | 56.0% to 60.3% |  |
| P1 slot and west spawn together, both characters averaged (inseparable in these two arms, see 2b) | +0.5% | -1.7% to 2.7% | not significant |
| Character effect: KAI edge over VORR | -8.2% | -10.4% to -6.0% | significant character bias |
| Mirror, villain vs villain: P1 win rate | 55.5% | 52.4% to 58.6% | pure slot test (identical fighters, identical role) |
| Mirror, hero vs hero: P1 win rate | 48.0% | 44.9% to 51.1% | slot test, but see the anguish note in the findings |

Model for the two shipped arms: P(KAI wins from P1) = 0.5 + character + slot, and P(VORR wins from P1) = 0.5 - character + slot. Averaging the two arms gives the slot term; half their difference gives the character term.

### 2b. Three factors separated: character, slot, and spawn side
Each arm is repeated with the spawn points exchanged: in the shipped arms P1 starts at x = 2150 (plains, west of the city) and P2 at x = 2900 (inside the city); in the -flip arms P1 starts at 2900 and P2 at 2150. Effects are percentage points of win probability; bold means the 95% interval excludes zero.

| Factor | KAI vs VORR (4 arms) | VORR vs VORR (2 arms) | KAI vs KAI (2 arms) |
| :--- | ---: | ---: | ---: |
| Character: KAI over VORR | -8.5% (**-10.1% to -7.0%**) | n/a | n/a |
| Slot: P1 over P2, spawn held fixed | +0.7% (-0.8% to 2.3%) | +1.4% (-0.8% to 3.6%) | -1.4% (-3.6% to 0.8%) |
| Spawn: west (x = 2150) over east (x = 2900), slot held fixed | -0.2% (-1.8% to 1.3%) | +4.1% (**1.9% to 6.3%**) | -0.6% (-2.8% to 1.6%) |

| Arm | P1 win rate | 95% CI |
| :--- | ---: | ---: |
| default-flip | 42.1% | 39.1% to 45.2% |
| swap-flip | 59.8% | 56.7% to 62.8% |
| mirror-villain-flip | 47.3% | 44.2% to 50.4% |
| mirror-hero-flip | 49.2% | 46.1% to 52.3% |

Additive model: P(P1 wins) = 0.5 + slot + spawn (+ character when the fighters differ). In the villain mirror there is no character term, so the two arms give slot and spawn directly.

### 3. Match length (sim-seconds from start to KO; older tools also counted a 3.0 s KO tail)
| Arm | Mean | SD | Min | p10 | Median | p90 | Max |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| default | 55.4 ±1.2 | 19.9 | 22.8 | 37.1 | 51.0 | 76.6 | 193.9 |
| swap | 55.9 ±1.2 | 19.8 | 19.7 | 36.9 | 52.0 | 77.6 | 206.1 |
| mirror-villain | 46.2 ±1.0 | 16.9 | 18.0 | 29.5 | 43.2 | 63.7 | 136.1 |
| mirror-hero | 59.1 ±1.4 | 22.8 | 23.0 | 39.8 | 53.2 | 84.7 | 218.5 |

Distribution, default arm (10 s bins):
```
  0-10  s    0 
 10-20  s    0 
 20-30  s   21 ██
 30-40  s  134 ████████████
 40-50  s  314 ████████████████████████████
 50-60  s  257 ███████████████████████
 60-70  s  132 ████████████
 70-80  s   55 █████
 80-90  s   27 ██
 90-100 s   22 ██
100-110 s   13 █
110-120 s    5 
120-130 s    7 █
130-140 s    6 █
140+    s    7 █
```

### 4. Collateral
| Arm | Civilians lost, mean | p10 | Median | p90 | Max | Structures lost, mean (of 47) | p10 | p90 | Craters, mean |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| default | 38.7% ±1.7 | 6.4% | 35.0% | 79.3% | 100.0% | 14.1 | 5.0 | 24.1 | 218.1 |
| swap | 43.1% ±1.7 | 8.9% | 40.4% | 85.4% | 100.0% | 15.6 | 7.0 | 27.0 | 221.6 |
| mirror-villain | 64.2% ±1.6 | 23.3% | 70.7% | 94.1% | 100.0% | 23.1 | 11.0 | 37.1 | 197.3 |
| mirror-hero | 32.2% ±1.6 | 4.9% | 24.6% | 72.8% | 100.0% | 12.1 | 5.0 | 20.0 | 241.1 |
Population at start: 425 civilians in 47 structures. Matches that lose at least 90% of the civilians: default 5%, swap 7%, mirror-villain 20%, mirror-hero 3%.

### 5. Launch types (share of all launches; flag above 40%)
| Launch | default | swap | mirror-villain | mirror-hero | Flag |
| :--- | ---: | ---: | ---: | ---: | ---: |
| SLAM DOWN | 46.4% | 43.5% | 36.0% | 52.0% | **OVER 40%** (3 arms) |
| UPPERCUT | 33.3% | 34.4% | 29.4% | 36.3% |  |
| BUILDING SMASH | 13.4% | 16.0% | 31.2% | 4.6% |  |
| SMASH ACROSS | 4.7% | 4.6% | 2.8% | 5.0% |  |
| MOUNTAINSIDE | 2.3% | 1.5% | 0.7% | 2.1% |  |
| launches counted | 14419 | 14428 | 11550 | 15228 |  |

SLAM DOWN, default arm: 46.4% of 14419 launches (95% CI 45.6% to 47.2%, clustered by match).

### 6. Signature beams by biome (biome under the defender when the beam is planned)
| Biome | Share of planet | default | swap | mirror-villain | mirror-hero | Default arm vs planet share |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| ocean | 26% | 69.4% | 60.6% | 23.4% | 77.6% | **2.7x** |
| village | 17% | 12.7% | 17.3% | 13.4% | 11.0% | 0.7x |
| plains | 9% | 8.8% | 12.0% | 15.3% | 5.1% | 1.0x |
| city | 16% | 3.9% | 6.0% | 43.0% | 1.2% | 0.2x |
| mountains | 11% | 3.3% | 2.3% | 1.0% | 3.2% | 0.3x |
| forest | 10% | 1.1% | 1.3% | 3.5% | 1.0% | 0.1x |
| desert | 10% | 0.8% | 0.5% | 0.4% | 0.9% | 0.1x |

Beams per match: default 3.65, swap 3.68, mirror-villain 3.16, mirror-hero 3.93. Ocean share of beams, default arm: 69.4% (95% CI 67.4% to 71.5%, clustered by match).

Where the fighters actually are (share of fight time, both fighters, until KO or the cap), for comparison with the beam table:
| Biome | Share of planet | default | swap | mirror-villain | mirror-hero |
| :--- | ---: | ---: | ---: | ---: | ---: |
| ocean | 26% | 64.6% | 58.9% | 24.1% | 73.7% |
| village | 17% | 15.0% | 17.0% | 12.9% | 13.0% |
| plains | 9% | 8.6% | 11.5% | 15.4% | 5.4% |
| city | 16% | 5.4% | 7.7% | 41.4% | 2.1% |
| mountains | 11% | 4.0% | 2.7% | 1.5% | 3.7% |
| forest | 10% | 1.2% | 1.5% | 3.7% | 1.1% |
| desert | 10% | 1.1% | 0.7% | 1.0% | 0.9% |

| Beam outcome (default arm) | HIT | GUARD | DODGE | ESCAPE | CLASH |
| :--- | ---: | ---: | ---: | ---: | ---: |
| count | 850 | 730 | 457 | 139 | 1472 |
| share | 23.3% | 20.0% | 12.5% | 3.8% | 40.4% |

Beam variants, default arm: HORIZON CLEAVE 69%, BOULEVARD RAZE 17%, MERIDIAN SCAR 9%, RIDGE BORE 3%, FIRESTORM 1%, GLASS TRENCH 1%.

### 7. Director coverage, default arm
Exchanges by attacker stance (rows, read from the fighter when the attack is requested) and defender state (columns):

| Attacker vs defender | AGGRESSIVE | DEFENSIVE | EVASIVE | ESCAPE | CHARGING |
| :--- | ---: | ---: | ---: | ---: | ---: |
| AGGRESSIVE | 4787 | 2284 | 2705 | 1564 | 27 |
| DEFENSIVE | 1648 | 859 | 927 | 514 | 20 |
| EVASIVE | 1795 | 925 | 1041 | 548 | 26 |
| ESCAPE | 0 | 0 | 0 | 0 | 0 |

Outcomes the director produced for each defender state and attack kind (share of that cell). The P2 exit criterion asks for at least two authored outcomes per stance pairing.

| Defender state | Light attack | Heavy attack | Signature |
| :--- | ---: | ---: | ---: |
| AGGRESSIVE | TRADE BLOWS 100% [1] | HEAVY CLASH — COUNTERED 39%; HEAVY CLASH — WON 37%; CLASH SHOCKWAVE 24% [3] | CLASH 95%; HIT 5% [2] |
| DEFENSIVE | PRESSURE — GUARD HOLDS 100% [1] | GUARD BREAK 100% [1] | GUARD 100% [1] |
| EVASIVE | DODGE & COUNTER 54%; DODGE & READ 46% [2] | DODGE & COUNTER 60%; DODGE & READ 40% [2] | DODGE 54%; HIT 46% [2] |
| ESCAPE | PURSUIT — TARGET SLIPS AWAY 51%; PURSUIT — CAUGHT 49% [2] | PURSUIT — CAUGHT 51%; PURSUIT — TARGET SLIPS AWAY 49% [2] | HIT 72%; ESCAPE 28% [2] |
| CHARGING | CHARGE INTERRUPT 100% [1] | CHARGE INTERRUPT 100% [1] | HIT 100% [1] |

The bracketed number is how many distinct outcomes were seen. Light attacks that end in a defender counter are counted under their base outcome.

| Melee outcome (default arm) | Count | Share |
| :--- | ---: | ---: |
| TRADE BLOWS | 4142 | 25.9% |
| DODGE & COUNTER | 2160 | 13.5% |
| PRESSURE — GUARD HOLDS | 2041 | 12.7% |
| DODGE & READ | 1667 | 10.4% |
| GUARD BREAK | 1297 | 8.1% |
| PURSUIT — TARGET SLIPS AWAY | 1063 | 6.6% |
| PURSUIT — CAUGHT | 1059 | 6.6% |
| HEAVY CLASH — COUNTERED | 993 | 6.2% |
| HEAVY CLASH — WON | 926 | 5.8% |
| CLASH SHOCKWAVE | 612 | 3.8% |
| CHARGE INTERRUPT | 62 | 0.4% |

### 8. Parry, chain, hide and ambush rates
| Rate | default | swap | mirror-villain | mirror-hero |
| :--- | ---: | ---: | ---: | ---: |
| Melee exchanges per match | 16.0 | 16.2 | 13.2 | 17.0 |
| Parries per match | 1.46 | 1.45 | 1.22 | 1.51 |
| Parries per 100 melee exchanges | 9.1 | 8.9 | 9.2 | 8.9 |
| Chains per match (2+ linked hits) | 3.82 | 3.91 | 3.14 | 4.09 |
| Chains per 100 melee exchanges | 23.8 | 24.1 | 23.8 | 24.0 |
| Mean chain length | 2.41 | 2.39 | 2.39 | 2.38 |
| Hides per match | 0.63 | 0.66 | 0.31 | 0.80 |
| Matches with at least one hide | 38% | 39% | 18% | 43% |
| Hidden seconds per match (P1 / P2) | 2.2 / 2.5 | 2.3 / 2.3 | 1.2 / 1.2 | 3.2 / 3.1 |
| "Found" events per match | 0.49 | 0.52 | 0.25 | 0.61 |
| Ambush attacks per match | 0.061 | 0.057 | 0.017 | 0.079 |
| Ambush attacks per hide | 0.097 | 0.086 | 0.054 | 0.099 |
| Parries by P1 / P2 (total) | 730 / 730 | 715 / 732 | 601 / 616 | 736 / 773 |
| Highest tier reached, mean (P1 / P2) | 2.3 / 2.5 | 2.6 / 2.3 | 2.6 / 2.4 | 2.4 / 2.3 |

Chain length histogram, default arm: x2: 2516, x3: 1051, x4: 237, x5: 13.

### 9. Where winners and losers spend their time, default arm (share of match time by stance)
|  | AGGRESSIVE | DEFENSIVE | EVASIVE | ESCAPE |
| :--- | ---: | ---: | ---: | ---: |
| Winners | 55.3% | 16.7% | 21.1% | 6.9% |
| Losers | 43.3% | 23.5% | 20.0% | 13.1% |

### 10. Seam exposure
| Arm | Matches where a fighter crossed the seam | Crossings per match | Largest single-step move (units) |
| :--- | ---: | ---: | ---: |
| default | 76% | 4.0 | 185.6 |
| swap | 72% | 3.7 | 166.7 |
| mirror-villain | 38% | 1.3 | 153.1 |
| mirror-hero | 86% | 5.6 | 155.1 |

### 11. Unseeded batch against the seeded baseline (clock-seeded, 1000 matches, not reproducible)
Run as the old tool ran: one long-lived instance, no seed, no carry-over reset. The comparison is against the seeded default arm. |z| below 3 counts as matching (eight tests, so about a 2% chance of a false alarm).

| Measure | Unseeded | Seeded default | z | Matches? |
| :--- | ---: | ---: | ---: | ---: |
| P1 (KAI) win rate | 42.5% | 42.3% | 0.09 | yes |
| Length to KO, mean (s) | 56.1 | 55.4 | 0.77 | yes |
| Civilians lost, mean (%) | 40.3 | 38.7 | 1.31 | yes |
| Structures lost, mean | 14.7 | 14.1 | 1.68 | yes |
| SLAM DOWN share of launches | 45.6% | 46.4% | -1.31 | yes |
| Ocean share of beams | 69.2% | 69.4% | -0.22 | yes |
| Parries per match | 1.48 | 1.46 | 0.31 | yes |
| Hides per match | 0.68 | 0.63 | 1.10 | yes |

Unseeded launches: SLAM DOWN 46%, UPPERCUT 33%, BUILDING SMASH 14%, SMASH ACROSS 5%, MOUNTAINSIDE 2%.
Bit-for-bit check (run once, not part of the suite because it needs the old file from git): the original `prototype/index.html` from commit 111b1a1 with the clock forced to S, against the edited file called as `newMatch(S)`, gave the same result hash for 200 of 200 odd seeds S.
<!-- END GENERATED -->

## Method notes

- **Seeds and slots.** Match i of an arm uses seed base+i (bases in section 1). Arms differ only in who occupies which slot and where each spawns: `swap` exchanges the two characters, `mirror-villain` and `mirror-hero` give both slots the same character (named -A and -B so the feed stays readable), and the `-flip` arms exchange the spawn points. Arms edit the two fighter objects after `newMatch(seed)` and consume no random numbers, so an arm is a pure function of its seed.
- **Between matches.** The harness clears `dirS.lastLaunch` and `dirS.lastLaunch2` before each match (QA-001). The unseeded check in section 11 deliberately does not, to reproduce how the old tool ran.
- **Events.** Attacks, launches, beams, parries, chains, hides, finds and tier-ups are read from the director feed as it is written (QA-004). Attacker stance is read from the fighter at that moment. A beam's biome is the biome under the defender, which is what the feed reports. Fight-time-by-biome samples both fighters every step.
- **Length.** Sim-seconds from the start to the first KO. The older tools ran until 3.0 s after the KO and printed that, so their figures are 3.0 s higher.
- **Intervals.** Win rates use Wilson 95% intervals on decided matches. Shares of launches and beams use match-clustered standard errors, because events within a match are not independent. Means use the normal approximation. The equivalence tests in section 11 use pooled two-proportion and Welch z statistics; the pooled version ignores clustering, which makes the test stricter, not looser.
- **Timeouts.** A match is stopped at 300 sim-seconds; none of the 8,000 reached it.
- **Not covered.** Hidden information is not modelled (the prototype shows both players everything). Human play is not modelled. Only two fighters exist, so there is one real pairing.

## Reproduce

```
node qa/balance-report.js --matches=1000 --unseeded=1000      # this file and qa/baseline-p0.json
node prototype/tools/sim-stats.js 1000 100001                  # the default arm, prints digest 70142afa31be898c
node prototype/tools/sim-stats.js 1000 100001 --arm=swap       # any arm; seed bases are in section 1
node qa/run-all.js                                             # the regression suite
```
