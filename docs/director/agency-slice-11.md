# Agency, slice 11: the blur's cadence and lock, flow and the string's ender (A4 and A3)

Owner: Encounter Systems Director. Date: 2026-10-03. Status: in the tree on HEAD `307b4fc`, waiting for the EP's commit. Plan: `docs/director/alchemy-plan.md` (A3, A4). Rules: `docs/design/agency-pass.md` §2, §18 and §20; Controls' `docs/controls/agency-input.md`; Combat's `docs/combat/alchemist-recipes.md` §6.

Everything here runs only in the `dynamic` profile.

## What changed

| Part | Rule | Where |
| :--- | :--- | :--- |
| **A blur string has a cadence** | A string that starts on a light press in the blur style draws its cadence from 7, 8, 9 or 10 ticks, by a keyed draw on the match seed and the exchange. The chain window opens on the blow. A link whose press is waiting lands its blow exactly one cadence after the last; a press that comes later lands 5 ticks after it. A heavy press ends the blur and plays on the template's timing | `blur.gd` `onStart`, `onLink`, `onBlow`; `exchange.gd` `_start`, `chain`; `alchemy.json` `blur` |
| **And a pattern** | The same draw picks one of Combat's patterns that is open (`patternGates`: the stick toward, both on the ground, the fighter). Each light of the string takes the pattern's next step, filled from his blur pieces with that limb and target, and not one the string has used while another fits. The closing blow comes from the ender pool and lands where the last light did, when the pool has such a piece | `blur.gd` `_open`, `piece`, `ender`; `recipe.gd` `dress` |
| **The lock (the perfect blur)** | Controls' steady read: four presses in a row, each within 2 ticks of a different blow's contact. From that press the blur is locked for the string: each strike does a full light's damage (a plain blur's does ×0.8), and the ender goes the full distance and is a full set-up (plain: 0.6 and half). Neither form launches. Cue `blur_locked` | `alchemy.gd` `log`; `blur.gd` `onPress`, `perfect`; `melee.gd` `strike`, `launchBeat`; `launch.json` `blur.perfectDist` |
| **A string is five blows** | The fifth landed blow is the ender, as before. So the four presses are the four link presses, and the lock arrives at the fourth blow: the fourth and fifth blows are full | Unchanged |
| **Timed presses and the flow** | A press is timed when it is within Controls' beat window (4 ticks; in a blur string, 2) of a blow of the exchange, either fighter's. A timed press adds 1 to the flow, up to 5. A press off the beat sets it to 0, and so do 90 ticks with no press. The press that starts an exchange leaves it as it is | `alchemy.gd` `log`, `tick`; `alchemy.json` `flow` |
| **Flow gates the string's ender** (§18) | A heavy that lands after one or more landed strikes of his in the exchange is the string's ender: it launches at flow 3 or more, and otherwise knocks back; the stick only aims. A heavy with nothing landed before it is its own exchange and keeps the stick earner. The held heavy and the won clash are unchanged | `launch.gd` `earned` |
| **The showcase cue** | A string's ender launched at flow 5 sends the cue `showcase_ender`. The extra impact wear is not built: there is no wear multiplier on a launch | `melee.gd` `launchBeat` |
| **Clean and hard** | In the combo style a strike from a timed press does ×1.15 | `melee.gd` `strike`; `alchemy.json` `timing.comboMul` |
| **The window and the style** | The last five presses stay until 90 ticks pass with no press, then clear as a whole. The style is Controls' read of the share of heavies in it: none is blur, up to 60% combo, over it power, so a lone heavy is power | `alchemy.gd` `window`; `recipe.gd` `_row` |
| **The AI times its presses** | Each of its presses inside an exchange is timed on a draw at its level's rate: 0.4, 0.65, 0.85. In a blur string a timed link press comes with the blow, so its next blow lands on the cadence; an untimed one comes at its old delay. Its blur locks after four timed presses in a row. With the flow gate its ender is a heavy once one strike has landed and its flow is 3 or more | `alchemy.gd` `log`; `blur.gd` `aiPress`; `launch.gd` `aiEnder`; `exchange.gd` `openWindow`, `runBeat`; `ai.json` `timedPress` |
| **A press's beat is exact** | The contact tick of a pending blow is counted on the exchange's own clock, as the director will run it. The earlier estimate could be one tick off | `alchemy.gd` `_blows` |
| **The medium AI, re-tuned** | `guardRepeat` 5.0 to 6.5: a blur's blows now land about twice as fast | `ai.json` |
| **Combat's recipes** | `data/combat/recipes.json` is Combat's slice 11 file (the `pieces` block, two more patterns, `patternGates`), placed by the EP's grant | `data/combat/recipes.json` |

**State:** nine more integers a fighter (`DirAlchemy.BLUR_*`). **Feed lines:** `BLUR` (the cadence and the pattern), `BLUR LOCKED IN`, `SHOWCASE ENDER`; `BLUR ENDER` says when it is the full one. **Cues:** `blur_locked`, `showcase_ender`. **No core lines.**

## Results

**Two scripted humans in the close band** (P1 presses by a script, P2 does nothing; 6 seeds):

| Script | Result |
| :--- | :--- |
| A light on the tick each of his blows lands | 72 of 73 strings lock; the gaps between blows are exactly the drawn cadence (51, 54, 48 and 63 gaps of 7, 8, 9 and 10) |
| The same, 2 ticks early or 1 tick late | 72 and 71 of 73 lock |
| A light every 8 live ticks, blind | 13 of 78 lock |
| A light 4 ticks after each blow | None lock; blows 9 or 10 ticks apart |
| Three lights then a heavy, on the contacts | Launches once his flow is 3; the showcase cue at flow 5 |
| A heavy every 30 ticks | The power style from the first press |
| Light, heavy, light, heavy | The combo style |

A locked string does 24.7, 56.2, 68.8, 103.4 and 122.3 over its five blows; a plain one 24.7, 56.2, 68.8, 82.7 and about 98.

**Against the medium AI,** 100 matches each (QA's masher script; the contact and metronome scripts are mine, on the same loop):

| Row | Result | Band |
| :--- | ---: | :--- |
| Blind 8-tick masher, wins | 42 of 100 | 35 to 50% |
| Blind 8-tick masher, locks of five-blow strings | 130 of 1,176 (11%) | at most 20% |
| Contact script, enders of five-blow strings | 1,083 full, 0 weak | at least 80% full |
| Contact script, wins | 54 of 100 | |
| Bolt-only player, wins | 30 of 100 | 20 to 40% |
| A metronome on the real clock, every 10 / 12 / 14 ticks: locks of five-blow strings | 9% / 27% / 26% | (the masher's band is 20%) |
| The same: wins | 43 / 40 / 45 of 100 | |

`guardRepeat`: 5.0 gave the masher 52 of 100, 5.5 gave 50, 6.0 gave 45, 6.5 gave 42, 7.0 gave 35.

**QA's harness** (`node qa/run-godot.js`, four arms, 100 matches an arm; before is slice 10's build):

| Row | Before | After | Band |
| :--- | ---: | ---: | :--- |
| KAI over both slots | 48.5% | 49.5% (50.0% from P1, 49.0% from P2) | 45 to 55% |
| Match length, median | 506 s | 489.1 s | 360 to 480 s |
| First brink, median | 427 s | 398.1 s | 270 to 420 s |
| Brink to KO, median | | 70.4 s | 45 to 90 s |
| Lights-only mirror, brink to KO | 78 to 91 s | 49.6 s | 45 to 55 s |
| Blasts' share of damage | 12.0% | 11.4% | 10 to 25% |
| Front-row structures lost | 57.1% | 52.1% | 25 to 50% |
| Exchanges that end in a knock-back | | 32.4% | 25 to 35% |
| Launches of the exchanges that separate | | 39.1% | 25 to 40% |
| The masher against the easy / medium / hard AI | | 100 / 42 / 1 of 100 | at least 60 / 35 to 50 / at most 15 |
| Perfect blocks per 100 melee exchanges | 17.2 | 15.9 | 5 to 15 |

89 bands pass, 18 fail, 21 pending (86, 20 and 22 before). **Still outside their bands:** the match median by 9 s, front-row structures by 2 points, perfect blocks by 0.9.

**QA's timing mirrors** (`node qa/timing-edge.js --plan=core`, 40 matches a row; before is slice 10's build):

| Row | Before | After | Band |
| :--- | ---: | ---: | :--- |
| T1 timed against a masher | 67.5% | 72.5% | 72 to 82% |
| T2 timed against a style-only player | 55.0% | 50.0% | 62 to 70% |
| T3 style-only against a masher | 77.5% | 65.0% | 55 to 62% |
| T4 mirror, both timed | 50.0% | 45.0% | 45 to 55% |
| T5 mirror, both style-only | 52.5% | 65.0% | 45 to 55% |
| T6 timed mash against a plain mash | 52.5% | 35.0% | 62 to 82% |
| T7 timed hold against a plain hold | 17.5% | 22.5% | 62 to 82% |
| T8 timed against the medium AI | 85.0% | 97.5% | 70 to 90% |
| T10 timed against the hard AI | 27.5% | 27.5% | 40 to 60% |
| T9 masher against the medium AI (this script) | 62.5% | 35.0% | 35 to 50% |

T1, T4 and T9 are in their bands; T2, T3, T5, T6, T7, T8 and T10 are not. Two of them have a known cause outside this slice's rules:
- **T6 (and T2) under-read the timing.** QA's timed scripts plan their presses from the opener's `strike` beats when the exchange starts. A link's blow is a `chainStrike` beat planned when the link is taken, so the scripts never press on it, and the timed masher throws shorter strings than the plain one. Against the medium AI a script that does press on every contact wins 54 of 100 where the blind masher wins 42.
- **T7** waits for the power style's upgrade, which is not built.

T8 is over its band by 7.5 points at 40 matches: a timed player gains the ×1.15 strikes and the flow's launches against the medium AI.

**Gates** on a clean copy of HEAD `307b4fc` with exactly the tree's changes (parity again in the tree): goldens regenerated (9 matches, 177,829 ticks; 175,559 before); parity, the loader check at 200 matches, `npm test` 5 of 5, determinism, seam, the animation check, the cue check, Controls' input tests (hub 50, touch 167, agency input 79, press read 162 checks) and its mash probe (6 of 6) pass. The validator shows 10 errors, all of them this slice's new keys and Combat's `pieces` and `patternGates`, until Tools' `apply-pieces.cjs` and `apply-slice11.cjs` are run.

## Notes

- **The metronome on the real clock.** Controls' loophole is real in live play: at 12 and 14 ticks it locks 297 of 1,111 and 309 of 1,167 five-blow strings, and at 10 ticks 101 of 1,177. Its win rate stays inside the masher's band. The likely cause, read from the code and not measured on its own: a press made during a hit-stop arrives on the first live tick and is graded just after the blow, so the whole hit-stop counts as on the beat; a period of 12 is cadence 7 plus the hit-stop and 14 is cadence 9 plus it, and one string in four has each cadence. The lever is Controls' (how a press in a freeze is graded) or the cadence set.
- **The lock can carry from one string to the next.** Controls' read looks at the last four presses in the log, whichever string they were in. So a press on the last string's closing blow that is queued and starts the next exchange counts, and a player who stays on the contacts can lock the next string before its fourth blow. This is read from the rule; it fits the contact script's 1,122 locks against 1,104 five-blow strings, and was not measured on its own.
- **TRADE BLOWS.** Its opener lands three of the attacker's blows on Combat's rhythm before the links. Under the earlier evenly-spaced test no such string could lock (0 of 118); under the rule as built they lock like the others.
- **The AI's light strings do less.** A plain blur's link strikes do ×0.8 whoever throws them, and the AI's blur locks only after four timed presses in a row.

## Data keys for Tools

| File | Keys |
| :--- | :--- |
| `data/director/alchemy.json` | `flow` {`enabled` (boolean), `max`, `lapseTicks`, `enderAfter`, `launchAt`, `showcaseAt` (integers), `_note`}; `timing` {`comboMul` (number), `_note`}; `blur` {`enabled` (boolean), `cadences` (array of integers), `minLeadTicks` (integer), `_note`} |
| `data/director/launch.json` | `blur.perfectDist` (number) |
| `data/director/ai.json` | per level `timedPress` (number, 0 to 1); note `_timedPress` |
| `data/combat/recipes.json` | Combat's slice 11 file; Tools' `apply-pieces.cjs` |

## Left for later

- The showcase ender's 20% more impact wear (a wear multiplier on a launch: World and Simulation) and Combat's showcase rows.
- The power style's upgrade: a release on the flash breaks a guard, and unguarded it earns a launch (the melee power blow has no flash yet).
- A5 the running mix, A6 pulse clashes, A7 Blow for Blow.
