# Agency, slice 5: blasts (the first energy slice, 3a) and the provisional signature limit

Owner: Encounter Systems Director. Date: 2026-10-03. Status: in the tree on HEAD `3bcb5e3`, waiting for the EP's commit. Rules: `docs/design/agency-pass.md` §5 and §11 item 6; `docs/design/moveset-rules.md` §11 (f) and (i); `docs/architecture/shots.md` (Simulation's shots).

Everything here runs only in the `dynamic` profile. The old profiles are unchanged.

## What changed

| Part | Rule | Where |
| :--- | :--- | :--- |
| **An energy press fires** | With the energy family held, an attack press outside an exchange fires a blast from where he stands, in any band. It never becomes a rush, a taunt or a charge. Inside an exchange of his it is a link, as before | `blast.gd` `press`; `exchange.gd` `requestAttack` |
| **A light: a bolt** | It leaves 6 ticks after the press, for 1 ki, and seeks the rival: it arrives within 45 ticks. Taps while one winds up queue up to 3 more. Bolts fired within 20 ticks of each other are one volley (one group) | `blast.gd` `tick`, `_fire` |
| **A heavy: a charged shot** | It charges while the button is held and leaves when it is let go, for 8 ki. A tap does 0.6 of the kind's damage; 30 ticks of charge does all of it. Held on, it leaves by itself at 45 ticks (the short beam is 3b) | `blast.gd` `tick`, `_fire` |
| **Nobody is locked** | The shooter keeps flying while he winds up. An exchange that takes him, a stagger or a launch cancels the blast | `blast.gd` `tick` |
| **Trades** | The core's: opposing shots that meet cancel power for power | `sim/core/shots.gd` |
| **The dodge** | A fighter inside his dodge window lets the shot pass; it flies on and hits the ground | `blast.gd` `hit` |
| **The perfect block** | A fresh guard press with the shot inside its window (8 ticks for a bolt, 10 for a charged shot, plus 4 early) sends it back at the one who fired it. One press answers a whole volley. A shot sent back and returned needs a new press | `blast.gd` `mark`, `hit`; `interrupt.gd` `guardPress` |
| **The lockout** | A shot on its way is a wind-up he can see: a guard press before its window is a miss and starts the lockout, as with a strike | `interrupt.gd` `guardPress` |
| **A held guard** | It takes the blast at the guard's rate, like a strike | `blast.gd` `hit` (`SimDamage.hit`) |
| **Against a charge** | Any blast stops a light charge. A heavy charge shrugs off a shot of power 1 at half its damage and keeps coming; a shot of power 2 or more stops it | `blast.gd` `hit` |
| **Firing is not pressing to meet a blow** | A defender who fired in the last 20 ticks is not read as pressing: a blow that reaches him finds him open | `data.gd` `_flags` |
| **A layout's hold** | A light still held waits for its release (up to 14 ticks), so a Simple layout's hold turns it into the charged shot with no stray bolt | `blast.gd` `tick`, `upgrade` |
| **The signature limit** (§5, provisional: Orb's to revisit) | Data behind a switch, on by default: a signature recharges in 15 s (not the fighter's 120) and does 0.6 of its damage. It still costs 45 ki. Off, both are as they were | `beam.gd` `sigCooldown`, `sigDamageMul`; `exchange.gd`; `interrupts.json` `signature` |
| **The AI** | Outside the close band its attack beat is a blast 20% of the time (medium): a volley of 3 bolts for a light, a charged shot for a heavy, charged for a random part of the full time. It perfect-blocks a shot at its usual rates | `ai.gd`; `blast.gd` `_aiBlock`; `ai.json` `blastShare` |

**Two places in Simulation's `sim/core/shots.gd`** (the hooks its design names; by the EP's grant, for Simulation's review):
- `hitFighter` (line 207): its body begins `if DirBlast.rules(S): return DirBlast.hit(S, sh, f)` and keeps the plain rule below it. `rules` is true once a blast press has been made in the match, so a shot fired with no press at all keeps the plain rule: Simulation's parity proof of the shots fires them that way and checks the plain damage, and it passes unchanged.
- `step` (line 353): `else:` becomes `elif sh.owner != k:` where a shot that was not ended is marked as passed. A deflect inside `hitFighter` makes the shot the blocker's own; without the condition the core then released it as a passed shot and it flew on straight.

**Cues:** `blast_windup`, `blast_charge`, `blast_full` (the charge is complete), `blast_cancel`, `charge_stopped`. `shot_hit` outcomes: `hit`, `guard`, `dodge`, `deflect`, `shrug`, `stop`. Damage of kind `blast`.

**Not in this slice:** the other shapes (the shard spread, the arc, the burst, the lob), the short beam (3b), the beam plays (3c), a guard at range deflecting for ki, and what a blast pays in mood and meters.

## Results

**Two scripted humans, 17 cases** (P1 fires from 20 bh with full ki):

| Case | Result |
| :--- | :--- |
| A bolt, the rival does nothing | Fired at 6 ticks, arrives 25 later, 9.2 damage |
| Three taps | Three bolts 6 ticks apart, one group, 27.7 damage |
| A heavy tap | A charged shot at 8 ticks, 44 damage (0.6) |
| A heavy held 30 ticks | 70.2 damage (full); the `blast_full` cue at 30 |
| A heavy held 80 ticks | Leaves by itself at 45 ticks |
| A bolt into a held guard | 3.1 damage, outcome `guard` |
| The rival dodges as it arrives | No damage; the bolt flies on and ends on the ground |
| The rival's guard press 3 ticks before it arrives | Deflected; it returns and hits the shooter (9.9; a charged shot 75.4) |
| A guard press 18 ticks before, and again at 3 | The first is a miss and locks him out; the bolt lands on his guard |
| Both fire a bolt | They meet and cancel |
| A charged shot against three bolts | It eats them and ends |
| A bolt into a light charge | The charge stops |
| A bolt into a heavy charge | Half damage (4.6); the charge arrives and lands clean |
| A charged shot into a heavy charge | The charge stops, 47.8 damage |
| A bolt from 2 bh | Fires and lands in 3 ticks |
| A Simple layout's hold | No bolt; a charged shot at 96% |

**100 AI matches,** seeds 1 to 100. Before is slice 4.

| | Slice 4 | Blasts, the signature limit off | Blasts, the limit on (as built) |
| :--- | ---: | ---: | ---: |
| Blasts' share of match damage (QA's starting band: 15 to 30%) | 0 | 4.6% | 4.4% |
| Signatures' share of match damage (at most 30%) | 4.5% | 4.9% | 4.2% |
| Signatures a match | 3.6 | 3.8 | 5.6 |
| Match median | 7:25 | 7:39 | 8:14 |
| KAI | 47% | 54% | 42% |
| Civilians lost, mean | 18.8% | 19.8% | 23.0% |
| Structures lost, mean | 32.2% | 32.3% | 41.7% |
| Melee exchanges a minute | 25.8 | 24.4 | 24.1 |
| Launch share of exchanges reaching a launch decision | 20.5% | 20.9% | 20.8% |
| A masher against the medium AI (50 matches; band 35 to 50%) | 40 of 100 | 21 of 50 | 23 of 50 |

A match with the limit on (50 matches): 54 bolts in 19 volleys and 12 charged shots fired. Of the bolts that met a fighter, 19 hit, 11 landed on a guard, 10.5 were dodged, 2.2 were sent back, 2.8 stopped a charge and 2 were shrugged off by one. Of the charged shots, 4.4 hit, 2.8 were dodged, 2.1 landed on a guard, 1.6 stopped a charge and 1.2 were sent back. 6.3 pairs of shots traded.

**Gates** (on a clean copy of HEAD with exactly the tree's changes; parity again in the tree): goldens regenerated (9 matches, 171,590 ticks); parity, the loader check at 200 matches, `npm test` 5 of 5, determinism, seam, the animation check, the cue check, Controls' input tests and its mash probe (6 of 6) pass. The validator shows five errors, the new keys below.

**The AI's blast share, measured on 50 matches:**

| `blastShare` (medium) | Blast share of damage | Match median | Structures lost | Shots a match |
| ---: | ---: | ---: | ---: | ---: |
| 0 (slice 4) | 0 | 7:20 | 30.0% | 0 |
| 0.2 (as built) | 4.7% | 7:39 | 32.5% | 65 |
| 0.5 | 13.9% | 8:42 | 45.4% | 250 |

## Notes

- **The signature limit costs pace and buildings on AI play.** With it on the AI fires 5.6 signatures a match, not 3.8: matches are 35 s longer and structures lost rise 9 points, though each beam does less and their share of damage falls. It is on by default as the EP asked; `signature.provisional` false restores the 120 s and the full damage.
- **Blast damage is 4.4% of a match's, under QA's starting band of 15 to 30%.** Reaching it by the AI's use alone costs about 80 s of match length and 15 points of structures (dodged and passed shots hit the ground with the tier factor). The AI's share stays at 0.2; the band needs Game Design's eye: a bolt's damage, the collateral of a missed shot, or the band itself.
- **A mark that outlived its shot** made two AIs bounce one charged shot between them without pressing again (10 deflects a match). The mark is now for one arrival.
- **A volley counts as one landed strike** only by its group id on the events. Mood and meters read nothing from blasts yet.
- **The shooter can be struck during his wind-up.** That is the rule (nobody is locked); the blast is then cancelled.

## Data keys for Tools

| File | Keys |
| :--- | :--- |
| `data/director/interrupts.json` | `signature` {`provisional` (boolean), `cooldownSec`, `damageMul` (0 to 1), `_note`}; `blast` {`enabled`; `light` {`kind`, `ki`, `windupTicks`, `holdTicks`, `queueMax`, `groupTicks`, `aiVolley`}; `heavy` {`kind`, `ki`, `windupTicks`, `chargeTicks`, `tapShare`, `holdMaxTicks`}; `stopTicks`; `charge` {`shrugPower`, `shrugMul`}; `_note`} |
| `data/director/ai.json` | per level `blastShare` (a chance, 0 to 1); note `_blastShare` |
