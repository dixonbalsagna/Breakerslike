# Agency, slice 8: the beam plays

Owner: Encounter Systems Director. Date: 2026-10-02. Status: measured in scratch on HEAD `cf0466f` (slice 7 in); parked in `docs/director/pending/agency8/`, to apply after Simulation's and World's windows. Rules: `docs/design/agency-pass.md` §5 (which beam plays come first; beam defence); `docs/design/rule-of-cool.md` §2 (the three looks of a perfect block); Combat's `docs/combat/pending/wave5-clashes.md` §3; Legal's screens RL-041 and RL-050.

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

**AI matches.** Before is slice 7.

| | Before (seeds 1 to 100) | After | Before (seeds 101 to 200) | After |
| :--- | ---: | ---: | ---: | ---: |
| Match mean | 8:13 | 8:02 | 8:10 | 8:05 |
| Structures lost | 44.9% | 42.5% | 40.6% | 41.9% |
| KAI | 60% | 44% | 46% | 51% |
| Beams' share of damage | 4.4% | 4.7% | | |

KAI's share moved 16 points one way on the first seeds and 5 the other way on the second: 53% before and 47.5% after over 200 matches, inside the noise.

How signatures end, 50 matches (306 signatures before, 316 after):

| | Before | After |
| :--- | ---: | ---: |
| Hit | 106 | 87 |
| Guard (after: 23 of them wades) | 65 | 51 |
| Deflect (after: 8 walks, 6 swats, 5 splits) | 0 | 19 |
| Dodge | 20 | 21 |
| Escape | 14 | 11 |
| Clash (after: 18 late answers) | 101 | 127 |
| Clashes won by the attacker | 62 of 101 | 88 of 127 |

The masher against the medium AI: 35 of 100 (41 on slice 7), at the bottom of the band.

**Gates** on a clean copy of HEAD with the slice: goldens regenerated (9 matches, 181,272 ticks); parity, the loader check at 200 matches, `npm test` 5 of 5, determinism, seam, the animation check, the cue check, Controls' input tests and its mash probe (6 of 6) pass.

## Data keys for Tools

| File | Keys |
| :--- | :--- |
| `data/director/interrupts.json` | `perfectBlock.windows.beam` (ticks); `beamPlays` {`enabled`, `travelTicks`, `afterTicks`, `dodge` {`beforeTicks`, `afterTicks`}, `late` {`ticks`, `scoreAdd`}, `walk` {`speed`, `minTicks`, `maxTicks`, `recoverTicks`}, `split` {`spreadDeg`, `lenBh`, `widthMul`, `powerMul`}, `swat` {`lenBh`, `skyDeg`, `groundDeg`}, `_note`} |
| `data/director/ai.json` | per level `beamDodge`, `beamWade`, `beamLate` (chances); `beamLook` {`split`, `walk`, `swat`} (weights); note `_beam` |

## Left for later

- The struggle on the pulse (`rule-of-cool.md` §2): the beam clash is still a draw (the alchemy plan's A6).
- Block then push back, and feeding a struggle a second charge (§5, "later").
- Camera: a swatted or split beam is a new beam in the state, and the panel rig asks for a signature panel for each new beam.

