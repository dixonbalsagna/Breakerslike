# Wounds S2: matches end through finishers

Owner: Encounter Systems Director. Status: landed in the GDScript sim, goldens regenerated. Inputs: `docs/design/spec-wounds.md` §1, §1b and §1c; `docs/architecture/wounds-plan.md` (S2). Events: `docs/architecture/fx-events.md`.

## What the director does now

| Rule | Where | Notes |
| :--- | :--- | :--- |
| **HP no longer ends a match.** `SimWounds.HP_ENDS_MATCH` is false and a KO happens only through a lost finisher contest | `sim/core/wounds.gd`, `sim/core/damage.gd` | `hp` stays as a readout that floors at 0, for the HUD bar until UI retires it. The director has no HP guards left: a KO (`S.game.ko`) is the only "done" check |
| **Decisive exchange.** The loser is launched (any launch, however it lands), a heavy clash is won, a GUARD BREAK lands, or a beam hits or wins its clash. A "no launch" shove counts only when the exchange is a heavy clash won, a GUARD BREAK or a CHARGE INTERRUPT | `exchange.gd` `decisive()`, called from `melee.gd` `launchBeat` and `beam.gd` | Emits `decisive` |
| **Finisher.** When the loser of a decisive exchange is on the brink, the rest of the exchange is dropped and the winner's finisher plays: rush 0.35 s, strikes at 0.4 s (40) and 0.75 s (55), a break launch at 0.8 s, the contest at 1.6 s | `exchange.gd` `startFinisher`, ops `finisher`, `finRush`, `breakLaunch`, `contest` | A placeholder set piece until Combat's finisher templates arrive as data |
| **Contest.** Survive with 30%, less 10 points per minute past 8:00, floor 0; one `S.rng` draw. Losing is a KO. Rally (S4) will lower the chance per Rally used | `exchange.gd` `_opContest` | Emits `finisher_start` and `finisher_contest` |
| **Breaks are chapters.** A strike that breaks a region drops the exchange's pending launch and chain window and ends it with a break launch 0.1 s later | `melee.gd` `strike`, `_breakChapter` | |
| **Break and finisher launches are long.** The planner's long-only mode offers SMASH ACROSS (always), BUILDING SMASH and MOUNTAINSIDE, and never "no launch" | `launch.gd` `chooseLaunch(..., longOnly)` | |
| **Region choice.** Go for the wound with (1 + wear / 30), but a broken region keeps its base weight | `sim/core/wounds.gd` `pickRegion` | At the cap, hits spent on a region that cannot worsen stalled matches; the focus now moves to the next wound |
| **The AI reads wounds.** Where it read hp / maxhp it reads `SimWounds.vitality()`: 1 minus the core's wear, or the second most worn of head, arms and legs, over the broken threshold, whichever is higher | `ai.gd`, `melee.gd` (trade-blows score), `damage.gd` (comeback bonus) | |
| **Lock-on and line of sight (§1c).** Hiding is the future stealth fighter's kit behind `canHide` (false for KAI and VORR). Everyone else breaks the opponent's lock only in ESCAPE, after 0.9 s out of line of sight (terrain line test, or low under unburnt canopy). Lock comes back on sight, within 240, when the target attacks, or after 4 s, with no new break for 6 s. No healing and no ambush | `sim/core/hiding.gd`, `exchange.gd` | Clouds and rubble join with World (LD1, B1). Emits `searching` and `found` |
| **Second breath.** After 4 s with no exchange involving the fighter, battered regions fade 1 per second, down to 59 | `sim/core/wounds.gd` `step` | Replaces the hidden fade, which stays for `canHide` |
| **Escape cover.** The AI heads for forest or mountains (what breaks sight); the sea no longer counts | `ai.gd` `COVER_KINDS` | |

## Tuning (spec §1b levers, in order)

| Lever | S1 | S2 | Why |
| :--- | ---: | ---: | :--- |
| k (wear per damage) | 0.08 | **0.06** | The 6 to 8 minute median, given the current exchange rate. §1b's 0.20 gave 90 s matches |
| Bruised fade | 1 per second | 0.25 per second | §1b |
| Focus weight | 1 + wear/50 | 1 + wear/30, broken regions excluded | §1b, plus the stall fix above |
| AI attack chance per beat (AGGRESSIVE, DEFENSIVE, EVASIVE) | 0.62, 0.5, 0.56 | 0.52, 0.43, 0.48 | Exchanges back to about 12 a minute without hiding |
| SMASH ACROSS base score, "no launch" threshold | 18, 23 | 8, 25 | Break and finisher launches are long-only, so SMASH ACROSS needed room under the 40% cap |

The k sweep (default arm, 200 matches each):

| k | Median | p90 | p99 | Timeouts | First break | First brink |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.055 | 6:42 | 9:29 | 11:26 | 1.5% | 4:38 | 6:38 |
| **0.06** | 6:10 | 8:34 | 10:02 | 0.5% | 4:00 | 6:01 |
| 0.065 | 5:34 | 7:28 | 10:04 | 0% | 3:38 | 5:21 |

## Results (seeds 1 to 100, default arm, `tempo.gd` and `batch.gd`)

| Spec §5 / §10 measure | Target | S2 |
| :--- | :--- | ---: |
| KOs through a finisher | 100% | 100% |
| Match length median, p90, p99 | 6:00 to 8:00; at most 10:00; at most 12:00 | 6:01; 8:15; 9:46 |
| Timeouts at 12 minutes | | 0 |
| First brink, median | 4:30 to 7:00 | 5:51 |
| First break, median | 1:30 to 2:30 | **3:45** |
| Region breaks per match, median | 4 to 6 (with Rally) | **2** |
| Largest region's share of wear | at most 45% | arms 32.5% |
| Finisher contests survived | about 30% | 28.1% |
| KAI win rate | 45 to 55% | 53% (P1); 45% in the swap arm at 200 matches |
| Exchanges per minute | 8 to 12 | 12.06 |
| Launches per minute | 4 to 6 | 5.6 |
| Largest launch type | at most 40% | SMASH ACROSS 37% |
| Long hauls (planner / all flights) | at least 30% | 28.1% / 32.6% (30.8 to 33.2% at 200 matches) |
| Slides among ground landings | 60 to 85% | 65% |
| Fight time underwater | at most 10% | 6.1% |
| Matches with no gap over 10 s | at least 95% | **45%** |
| Exchange length, median | 2.5 to 4.0 s | **1.45 s** |
| Civilians lost, mean | 25 to 50% (QA §4) | **51%** |

## Open items

- **Gaps over 10 s come from water physics.** Every sampled long gap had a fighter "launched" for 5 s or more, and 44 of 48 were sinking. In deep water the drag holds a launched fighter near 430 units per second, above the 200 at which it is freed, so it sinks to the seabed (about 2,700 down) while no exchange can start on it. The fix is a rule in `sim/core/fighter.gd`: buoyancy, a lower free speed in water, or the skim. It belongs to World and Simulation.
- **The first break comes late (3:45)** because k is set for the match length. The two bands meet once Rally (S4) mends breaks and lengthens the tail. Breaks per match (4 to 6) also needs Rally.
- **Exchange length** is the templates' beat spacing (Combat). The director's finisher and break chapters are the only long set pieces so far.
- **Collateral per match rose** with 6-minute matches (51% of civilians; the villain mirror loses about 92%). That is the world budget (World, Game Design).
- `hp` is kept as a vestigial readout; deleting it touches UI's HUD and Simulation's state.
- Taunts and the Drop the Act family wait for F1. `ambush_ready` and `cinematic_*` wait for the stealth fighter and F1.
