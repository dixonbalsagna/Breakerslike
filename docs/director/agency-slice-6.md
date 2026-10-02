# Agency, slice 6: the buried fighter, and the hook for the slide's bump

Owner: Encounter Systems Director. Date: 2026-10-02. Status: in the tree on HEAD `42cbd5f`, waiting for the EP's commit. Rules: `docs/design/agency-pass.md` §7; World's embed (`docs/world/ground-contact.md` §19) and its asks for the bump (§24).

Everything here runs only in the `dynamic` profile. The old profiles are unchanged.

## What changed

| Part | Rule | Where |
| :--- | :--- | :--- |
| **The free follow-up** | While World holds a fighter in his crater, his rival's first attack press in the first 40 ticks is one blow he cannot answer: a heavy's damage whatever was pressed, free of ki, landing clean through a guard. It starts at once, through the cooldown and from any distance (the attacker flies there). No launch and no chain window | `bury.gd` `followUp`, `plan`; `exchange.gd` `_start` |
| **A blast into the crater** | A shot that reaches him while he is helpless is the follow-up too: no dodge, no guard, no deflect | `blast.gd` `hit`; `bury.gd` `blasted` |
| **One to a burial** | The follow-up is used once. After it he can guard | `bury.gd` |
| **It deepens the crater** | The blow digs a bowl 1.2 times as deep as the one that buried him. World's dig leaves ground alone that is already dented deeper than the bowl asked for, so the director asks for the embed's own energy times 1.44 | `bury.gd` `opDeepen` |
| **His guard** | It counts only from tick 40, or once the follow-up is used. Buried, he never dodges or presses: an attack on him finds a guard or nothing | `bury.gd` `stance`; `exchange.gd`; `data.gd` `planMelee` |
| **His burst** | It throws him out of the crater, not before tick 40 | `interrupt.gd` `_canBurst`, `burst`; `bury.gd` `burstOut` |
| **His safety** | Out of the crater he is safe for 10 ticks: no exchange starts on him and a shot passes. The safety also covers World's get-up after its 60 ticks, when he is still down | `bury.gd` `safe`, `tick`; `exchange.gd` `_start`; `blast.gd` `hit` |
| **The burial ends with an exchange** | An exchange that takes him out of the crater clears World's hold | `bury.gd` `onEnd` |
| **The AI** | It takes the free blow on 80% of the rivals it buries (medium), 14 ticks after the burial | `bury.gd` `tick`, `aiFollow`; `ai.gd`; `ai.json` `buriedFollowUp` |
| **The slide's bump: a hook** | When World's `slideObstacle` and `bump` exist, an upright slide is cut short a body before the obstacle, the `knockback` event's kind is `bump`, and World's `bump` pays the light brunt when the slide ends. When World's `slideFeet` field exists, `doLaunch` sets it from the plan. Until then none of it runs | `launch.gd` `knock`, `tick`, `doLaunch` |
| **The medium AI against a masher** | `guardRepeat` 8 to 8.75, to bring the masher back into his band | `ai.json` `levels.medium` |

**The follow-up's piece is the director's interim** (`BURIED: FOLLOW-UP`): a rush, the cue `buried_followup`, one blow of class none (no perfect-block window), the dig, and a 9-tick recovery. Combat has no piece for it yet.

**No core lines.** The director writes `Fighter.embedT` (to 0, when an exchange or a burst takes him out), as World's design says it should.

**Cues:** `buried_followup` (the attacker), `buried_rise` (he is out). `shot_hit` outcomes `buried` and `safe`. The `attack` event's defender state is `BURIED` for the follow-up. Feed lines: `IS BURIED`, `BURSTS OUT`.

## Results

**Two scripted humans** (P2 is put in a crater as World's embed does, 5 bh from P1 unless said):

| Case | Result |
| :--- | :--- |
| A heavy at tick 10 | The follow-up: 62.7 damage at tick 29; the crater 14 units deeper; no launch; he is out at tick 38 |
| A light at tick 10, into a held guard | The same heavy blow, through the guard |
| A second heavy 4 ticks after he is out | It waits; the next exchange starts 18 ticks later |
| A heavy at tick 45, he does nothing | No follow-up: an ordinary lunge and a clean hit |
| A heavy at tick 45, he holds guard | His guard counts: a guard break |
| A bolt fired at tick 2 from 20 bh | It lands at tick 32 as the follow-up (outcome `buried`) |
| He bursts at tick 20, and at tick 45 | The first is refused; the second throws him out |
| Nobody presses; a heavy at tick 62 | He is up at tick 80 and safe to tick 90; the lunge starts then |
| A heavy at tick 10 from 50 bh | The follow-up, after a 72-tick flight: the blow lands at tick 82 |

**100 AI matches,** seeds 1 to 100. Before is slice 5 (`992f56c`; nothing in the sim changed between it and `42cbd5f`). The burial rows are from 50 of the matches.

| | Before | After |
| :--- | ---: | ---: |
| Burials a match | not counted | 2.0 |
| ... with the free follow-up taken | 0 | 1.3 |
| ... the crater deepened by, median | | 33 units (0.44 bh); not at all in 27 of 65 |
| The rival's distance at the burial, median | | 137 to 160 bh |
| Match median | 8:14 | 7:42 |
| KAI | 42% | 43% |
| Civilians lost, mean | 23.0% | 21.5% |
| Structures lost, mean | 41.7% | 36.5% |
| Signatures a match | 5.6 | 5.5 |
| Blasts' share of damage | 4.4% | 4.4% |
| Launch share of exchanges reaching a launch decision | 20.8% | 20.7% |

**The masher** (a light every 8 ticks, takes forms): against the easy AI 50 of 50, the medium AI 40 of 100 (band 35 to 50%), the hard AI 0 of 50.

**Gates** (on a clean copy of HEAD with exactly the tree's changes; parity again in the tree): goldens regenerated (9 matches, 173,020 ticks); parity, the loader check at 200 matches, `npm test` 5 of 5, determinism, seam, the animation check, the cue check, Controls' input tests and its mash probe (6 of 6) pass. The validator shows the new keys below as errors until Tools' schema lands.

## Notes

- **The follow-up reaches any distance.** A fighter is buried 137 to 160 bh from his rival in the median case, because it is long launches that bury. Within 35 bh the AI got no follow-up in 6 matches of 11 burials. The attacker's flight is the old pursuit's (up to 2 s), and the buried fighter is held for it.
- **The crater is not always deeper.** In about a third of follow-ups World's dig does nothing: the bowl asked for is no deeper than the ground already is (a capped radius, or a special's crater). A "deepen by" call in World would make it certain.
- **What moved the masher against medium.** On the same 50 seeds he won 20 at slice 4, 23 at slice 5 and 29 at slice 6 (56 of 100). In slice 5 the medium AI spends a fifth of its beats outside the close band firing, which does him little harm. In slice 6 any press of his on a buried AI is a free heavy, and the safety after his own burials protects him; the AI's damage on him fell about 8%. `guardRepeat` 8.75 gives 40 of 100.
- **A buried fighter attacked after tick 40** is pulled out by that exchange and gets the safety when it ends.

## Left for later

- Combat's piece for the follow-up, and its camera.
- The bump itself and the long skid's halved wear: World's next window (`slideObstacle`, `bump`, `slideFeet`).
- The AI's burst out of a crater: it never does.

## Data keys for Tools

| File | Keys |
| :--- | :--- |
| `data/director/interrupts.json` | `buried` {`enabled`, `followTicks`, `guardFromTick`, `burstFromTick`, `safeTicks` (integers, 0 or more), `reachBh`, `damage` (numbers, over 0), `deepen` (a number, 1 or more), `_note`} |
| `data/director/ai.json` | per level `buriedFollowUp` (a chance, 0 to 1); note `_buriedFollowUp` |
