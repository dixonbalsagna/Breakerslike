# Agency, slice 8: the beam plays

Owner: Encounter Systems Director. Date: 2026-10-03. Status: in the tree on HEAD `ea919bb`, waiting for the EP's commit. Rules: `docs/design/agency-pass.md` §5 (which beam plays come first; beam defence); `docs/design/rule-of-cool.md` §2 (the three looks of a perfect block); Combat's `docs/combat/pending/wave5-clashes.md` §3; Legal's screens RL-041 and RL-050.

Everything here runs only in the `dynamic` profile, behind `interrupts.json` `beamPlays.enabled`. Off, a beam is decided at its fire beat, as before.

## What changed

| Part | Rule | Where |
| :--- | :--- | :--- |
| **The beam takes time to arrive** | A signature that is not answered in its tell leaves at the fire beat and reaches the defender 20 ticks later, at any distance. The outcome is read on that tick, from what he did and what he holds then. The beam's front is slowed to match, then goes on at its own speed | `beamplay.gd` `fire`, `travel`, `front`, `opReach`; `beam.gd` `opBeamFire`, `beamStep` |
| **The late answer** | His own signature, or a heavy energy attack, in the first 20 ticks after the beam leaves stops it in a struggle. He starts 10 down, on top of the heavy blast's own 10 | `beamplay.gd` `lateTick` |
| **The perfect block has three looks** | A fresh guard press in the last 12 ticks of the tell (was 10) is a DEFLECT. The stick as the beam reaches him picks the look: away, the swat; level, the split; toward, the walk. None costs ki or takes damage; each gives the perfect block's 8 ki | `interrupt.gd` `_windowBeat`; `beamplay.gd` `opReach` |
| **The swat** | The beam ends at him and a new one leaves from where he stands. A fighter with an anguish meter sends it at the sky; one with a menace meter at the nearest standing building within 30 bh; anyone else, or with no building near, into the ground beyond him. It is the swatter's beam: it uses what is left of the beam's cap on buildings and its damage is credited to him | `beamplay.gd` `_swat` |
| **The split** | The beam ends at him and two lesser beams leave 14 degrees either side of its line, 12 bh long, at half the width and 0.6 of the power. They are the attacker's and share what is left of the cap | `beamplay.gd` `_split` |
| **The walk** | He advances through the beam to contact distance (3,000 units a second, 24 to 54 ticks). The beam lasts as long as his walk. When he arrives the attacker has 20 ticks of recovery left, and there is no pause before the next exchange | `beamplay.gd` `opReach`, `opArrive`, `onEnd` |
| **The wade** | A held guard with the stick toward: guard damage, no launch, and the walk | `beamplay.gd` `opReach` |
| **The dodge is a timed tap** | A dodge tap in the last 14 ticks of the tell or the first 6 ticks of the beam avoids it. No roll. The tap is kept when it comes, so a later tap does not undo it | `beamplay.gd` `fire`, `lateTick`, `opReach`; `data.gd` `beamOutcome` |
| **A held guard** | Unchanged: guard damage and the launch. The guard counted is the one he holds as the beam reaches him (it was his state when the tell began) | `beamplay.gd` `opReach` |
| **The AI defender** | Drawn once as the charge starts: its perfect block (its usual rates) and the look; whether its dodge is in time; whether it holds toward when guarding; a late answer | `beamplay.gd` `aiPlan`, `aiMayDodge`, `aiDir`; `ai.gd`; `ai.json` |
| **The medium AI, re-tuned** | `guardRepeat` 6.5 to 5.5 (the masher's band) and `barrageGuard` 0.5 to 0.7 (the bolt-only band), both measured with QA's own scripts | `ai.json` `levels.medium` |

**The outcome names do not change.** The three looks are `DEFLECT` and the wade is `GUARD` in the `beam_outcome` event. The look is a cue.

**Cues:** `beam_fire` (the attacker, as it leaves), `beam_swat`, `beam_split`, `beam_walk`, `beam_wade` (the defender, as it reaches him), `beam_arrive` (the defender, at the end of the walk), `beam_late` (the defender's late answer). The `beam_outcome` event now comes when the beam reaches him, 20 ticks after the fire beat, except for a clash in the tell.

**No core lines.** The beam's travel is kept in the director's per-fighter state.

## Results

**Two scripted humans** (P1 fires his signature from 20 bh at tick 0; the beam leaves at 47 and reaches P2 at 67), the same with either fighter attacking:

| P2 | Result |
| :--- | :--- |
| Nothing | HIT at 67 |
| Guard held | GUARD: guard damage and the launch |
| Guard held, the stick toward | The wade: guard damage, no launch; he arrives at 98 and the attacker has 20 ticks of recovery |
| A guard press at 40, the stick level | The split: two lesser beams leave him; no damage |
| A guard press at 40, the stick away | The swat: KAI (anguish) sends it at the sky, VORR (menace) at a building in reach, else into the ground |
| A guard press at 40, the stick toward | The walk: no damage; he arrives at 98, the attacker 20 ticks in recovery |
| A guard press at 30 (too early), held | GUARD |
| A dodge at 30 / 36 / 53 / 58 | HIT / DODGE / DODGE / HIT |
| His own signature at 20 | CLASH at the fire beat |
| His own signature at 56, or at 66 | CLASH, he starts 10 down |
| A heavy energy attack at 56 | CLASH, he starts 20 down |

**QA's harness** (`node qa/run-godot.js`, four arms, 100 matches an arm, with the masher rows), on a clean copy of HEAD with the slice:

| Row | Result | Band |
| :--- | ---: | :--- |
| KAI over both slots | 54.0% (54.0% from P1, 54.0% from P2; 108 of 200) | 45 to 55% |
| The masher (takes forms) against the easy / medium / hard AI | 99 / 45 / 0 of 100 | medium 35 to 50% |
| A bolt-only player finishes against a melee masher | 40 of 40 | at least 95% |
| A bolt-only player against the medium AI | 12 of 40 (31 of 100 on the same script) | 20 to 40% |
| Match length, median | 500 s | 360 to 480 s |
| Blasts' share of damage | 11.1% | 10 to 25% |
| Front-row structures lost | 55.7% | 25 to 50% |
| Lights-only mirror, brink to KO | 78.4 s | 45 to 55 s expected; the overall band is 45 to 90 s |

91 bands pass, 15 fail, 22 pending. Outside their bands and not this slice's: the match median (495 s on slice 7 by QA's count), the front-row structures (55.5% on slice 7), brunts a minute, halted launches, flights off terrain, the lock-break length, the Frenzied share of act 4, and the medium AI's perfect blocks (15.1 per 100 against a ceiling of 15).

**100 AI matches** (my own probe, seeds 1 to 100). Before is HEAD.

| | Before | After |
| :--- | ---: | ---: |
| Match median (mean) | 7:59 (7:55) | 8:23 (8:17) |
| KAI | 50% | 54% |
| Civilians lost, mean | 22.7% | 24.0% |
| Structures lost, mean | 38.6% | 42.8% |
| Beams' share of damage | 4.4% | 4.9% |
| Launch / knock-back / stay | 20.3 / 31.2 / 48.5 | 20.8 / 32.1 / 47.2 |

The lengths carry about 8 s of standard error and the structures about 2.3 points. On the earlier HEAD, before the retunes, the same slice measured the other way (8:13 to 8:02; 44.9% to 42.5%), and KAI's share moved 16 points one way on one set of seeds and 5 the other way on the next.

How signatures end, 50 matches (299 signatures before, 340 after):

| | Before | After |
| :--- | ---: | ---: |
| Hit | 89 | 101 |
| Guard (after: 17 of them wades) | 63 | 46 |
| Deflect (after: 10 swats, 9 splits, 7 walks) | 0 | 26 |
| Dodge | 32 | 21 |
| Escape | 15 | 13 |
| Clash (after: 21 late answers) | 100 | 133 |
| Clashes won by the attacker | 63 of 100 | 92 of 133 |

**The retunes,** with QA's scripts, 100 matches each. The masher against medium: `guardRepeat` 6.5 gave 33, 6.0 gave 35, 5.0 gave 45, 4.0 gave 55; 5.5 is in the tree (45 on the final build). The bolt-only player against medium, the script in both slots: `barrageGuard` 0.5 gave 54, 0.6 gave 37, 0.7 gave 31; 0.7 is in the tree. With the script in slot 0 only he wins less (37 of 100 at 0.5, 24 at 0.7), which is why slice 7's own probe, slot 0 only, read 34 where QA's script reads 54.

**Gates** on a clean copy of HEAD with exactly the tree's changes (parity again in the tree): goldens regenerated (9 matches, 181,802 ticks); parity, the loader check at 200 matches, `npm test` 5 of 5, determinism, seam, the animation check, the cue check, Controls' input tests and its mash probe (6 of 6) pass. The validator shows the keys below as its only errors until Tools' schema script is applied.

## Data keys for Tools

| File | Keys |
| :--- | :--- |
| `data/director/interrupts.json` | `perfectBlock.windows.beam` (ticks); `beamPlays` {`enabled`, `travelTicks`, `afterTicks`, `dodge` {`beforeTicks`, `afterTicks`}, `late` {`ticks`, `scoreAdd`}, `walk` {`speed`, `minTicks`, `maxTicks`, `recoverTicks`}, `split` {`spreadDeg`, `lenBh`, `widthMul`, `powerMul`}, `swat` {`lenBh`, `skyDeg`, `groundDeg`}, `_note`} |
| `data/director/ai.json` | per level `beamDodge`, `beamWade`, `beamLate` (chances); `beamLook` {`split`, `walk`, `swat`} (weights); note `_beam` |

## Left for later

- The struggle on the pulse (`rule-of-cool.md` §2): the beam clash is still a draw (the alchemy plan's A6).
- Block then push back, and feeding a struggle a second charge (§5, "later").
- Camera: a swatted or split beam is a new beam in the state, and the panel rig asks for a signature panel for each new beam.
