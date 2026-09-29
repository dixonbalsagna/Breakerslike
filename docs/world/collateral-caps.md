# The collateral cap and the casualty ramp: how they are built

Owner: World and Environment. Status: plan, docs only (2026-09-29); built after Encounter's S2, in the same sim window as B1. The numbers are Game Design's (`docs/design/balance-targets.md` §4b); this note is the mechanism.

**What has to be true.** After the scale window, the villain mirror loses 61% of the civilians (10.5% of matches lose 90% or more) and the default arm's low-tier bleed is 19.9% of the population per minute. Game Design's rules: a rolling 60 s budget by the higher fighter's tier, a cumulative ceiling by the highest tier reached, set-piece borrowing at tier 3 and above, and every per-casualty gain normalised by `425 / pop0`. Over budget, people evacuate instead of dying, and structures still take their damage. It has to apply to every source, and evacuation has to read as people fleeing, not as immortal civilians.

## 1. One choke point

Every civilian death today goes through `damageBuilding` (`dead = min(popAlive, pop * frac * 1.3)`, then everyone left when the building falls) into `WorldStructures.casualty`. Impacts, blasts, beams, slides, launch collisions, brunts and chains all reach it through `damageArea` or `damageBuilding`. Later hazards (fire, landslides, quakes, lava, floods) will reach it the same way if they damage buildings, and through a new call if they hit people outside buildings.

The rule that makes the cap apply to everything:
- **No code counts a casualty except through `WorldCollateral.kill`.** `WorldStructures.casualty` becomes the private step that feeds the meters, and only `kill` calls it.
- `kill(S, b, want, cause)` is what `damageBuilding` calls in place of subtracting and counting. `want` is the number who would die. It removes them all from the building, counts the allowed number as casualties, and counts the rest as evacuated (section 4).
- Hazards outside buildings call `WorldCollateral.kill(S, null, want, cause)` with the position in an event, so they are capped the same way.
- A check in `probe.gd` (and a lint in the parity gate) fails if `casualty(` appears anywhere but `collateral.gd`.

New file `sim/world/collateral.gd` (`WorldCollateral`): the tables, `kill`, `beginEvent` and `endEvent`, `tick`, and the readouts. Structures keeps `damageBuilding` and `damageArea`; it just delegates the deaths.

## 2. The rolling budget

- **The limit.** In any rolling 60 s, casualties may not exceed `budget = BUDGET[tier - 1] * pop0`, where the tier is the higher of the two fighters' tiers at that moment and `BUDGET = [0.02, 0.04, 0.08, 0.15]`.
- **The window.** 60 buckets of one second of match time each (a `PackedFloat32Array`), indexed by `int(floor(S.T)) % 60`. When the second advances, the buckets it skips are cleared. `cbSum` is the sum. Time is `S.T`, so hit-stop and the slow-motion after a KO do not count. Cost: a few operations per tick and 60 additions once a second.
- **Room.** `room = max(0, budget - cbSum)`. A casualty request `want` gets `min(want, room)` from the window.
- **Falling tier.** Tiers only rise, so the budget only rises; the window is never above a newly lower budget.
- **Set pieces borrow** (tier 3 and above only). See section 3.

## 3. Set pieces and borrowing

A set piece declares itself so that the casualties it causes can draw on its own allowance in addition to the window's room.
- `beginEvent(S, kind, cause)` sets `S.world.evtKind`, `evtLeft` (its per-event budget times `pop0`) and the fighter; `endEvent(S)` clears them.
- While an event is open at tier 3 or above, `kill` grants `min(want, room + evtLeft)`, taking from the room first and then from `evtLeft`. What it takes is added to the window, so `cbSum` can go over the budget. It stays over until the old buckets expire, so **nothing else can be killed until the window has refilled below the budget**: the average rate holds and the spectacle is paid for.
- At tier 1 and 2 borrowing is off: `evtLeft` is ignored, so a single event still has to fit in the room, and the low-tier band is firm.
- **Per-event allowances** (share of `pop0`; Game Design's rules in §5b, §5c and `living-destruction-numbers.md`):

| Set piece | Tier 3 | Tier 4 | Opened by |
| :--- | ---: | ---: | :--- |
| Brunt chain (`buildings-in-depth.md` 4b) | 12% | 20% | B2: the launch beat that starts the chain, closed at the last hit |
| Knockback slide | 5% | 10% | `WorldSlide.begin`, closed by `finish` or a cliff release |
| Landslide (LD2) | 5% | 10% (one collapse a match) | LD2 |
| Quake (LD3) | per its section, tier 4 only | | LD3 |

- A single brunt (one building) is not a set piece: it draws on the window only.
- **Scoping.** The event is credited to its fighter. A casualty from the same fighter's other source during the event (a beam at the same moment) can also use the allowance; it is a small leak and is documented. It could be tightened by tagging the source (`kill` gets an `evt` token from the caller) if QA sees abuse.
- **The planner.** The chain planner (B2) reads the room and `evtLeft` and drops a chain that would be over budget, as `buildings-in-depth.md` already says, so the plan and the outcome agree. `WorldCollateral.room(S)` is the shared readout.

## 4. The ceiling

- **The limit.** `S.world.casualties` may not exceed `CEILING[maxTier - 1] * pop0`, with `CEILING = [0.10, 0.30, 0.60, 0.90]` and `maxTier` the highest tier either fighter has reached so far in the match (`S.world.maxTier`, raised in `tierUp`).
- **Applied last.** `granted = min(want, room + evtLeft, ceilingLeft)`; the ceiling also limits borrowing, so a set piece cannot break it.
- At the ceiling the rest survive: they are sheltered, and count as evacuated with reason `ceiling`.

## 5. Evacuation: people fleeing, not immortal civilians

The design goal is that an over-budget blow visibly empties a place, so that the cap reads as a crowd escaping, never as civilians who take a hit and do not die.

**What the sim does.**
1. **The ones who would have died flee.** In `kill`, `want - granted` people are taken out of the building (`popAlive` falls by all of `want`), added to `S.world.evacuated` and reported with an `evacuate` event. They are alive and gone from that district for the rest of the match: they do not return, so the same building cannot be farmed for casualties again, and `popNear` and the AI see the emptier street (the hero's lure treats it as empty land; the villain finds less to feed on, which is the intended pressure).
2. **The district empties while it is over budget.** While `cbSum >= budget` (or the ceiling is reached), `WorldCollateral.tick` evacuates each standing building within `EVAC_R = 3,000 * WS / 8` units of the most recent heavy event (the last crater, slide sample, brunt or fall) at `EVAC_RATE = 0.30` of its remaining people per second. This is the visible flight: the people who were not hit run too, because the place is under attack. It costs a loop over the 91 buildings once per tick while over budget, and stops when the window refills. The rate is bounded (`EVAC_MAX_PER_TICK` events).
3. **Nobody is evacuated at random.** The pick is by distance to the event, nearest first, so the fleeing crowd comes from where the blow fell.

**What Rendering does (through the EP).** The `evacuate` event `{b, x, z, n, cx, reason, owner}` carries the building, the number who fled, the direction away from the event (`cx` is the event's x), and the reason (`budget` or `ceiling`). Rendering makes the figures that were at that building run away from `cx`, at a run, and fade or despawn them at the edge of the district or as they pass behind the row of buildings behind them; a stream of runners from a district that is being emptied reads as a flight. Figures for people still alive stay put. The number of figures follows `popAlive`, so when people evacuate the crowd thins. Suggested look: bunching at street corners, a few looking back; the closer to the event, the faster. A district that has been evacuated stays empty, with the occasional straggler.

**What Narrative does (through the EP).** Barks from the same event, by role: the hero relieved ("They're getting out"), the villain contemptuous or frustrated ("Run, then"; "Where are they going?"), and a narrator line for the first evacuation of a match. Reasons matter: `budget` is a moment ("the streets are emptying"), `ceiling` is a state ("there's no one left to lose"). A feed line once per district per minute.

**What the player must not see.** A person struck by a blast, alive, standing in a collapsing building. The rule is: people who would die are removed from the building in the same tick and appear as runners; buildings that fall do so empty of anyone who is over budget.

## 6. Normalising the meters

`CASUALTY_NORM = 425 / pop0` multiplies every per-casualty gain, so meters read the share of the population lost and planets of different sizes are equivalent (the scale window left 379 people on seed 1 against 425).
- In `casualty()`: menace `n * 0.9 * norm`, the villain's power `n * 0.09 * norm`, anguish `n * (0.9 if hero caused it else 0.5) * norm`.
- The roster's collateral-fed meters (the Cyborg's Hunger per civilian and his molt thresholds, and any later meter) take `norm` in the same place; the roster loader (D1) applies it, so data files state per-425-people values.
- `popNear`'s divisor (`POP_NEAR_REF`) already carries the scale factor; it does not take `norm`.
- The count `S.world.casualties` stays a raw head count. Every band is a share of `pop0`, so tools divide by it (they already do).

## 7. State, events and cost

- **State** (`S.world`, all in the hash): `evacuated` (head count), `cbBuckets` (60 floats), `cbSec` (the last second index), `cbSum`, `maxTier`, `evtKind`, `evtLeft`, and per building nothing new (`popAlive` carries it). `pop0` is unchanged.
- **Events:** `evacuate {b, x, z, n, cx, reason, owner}`, emitted only when a building's evacuees since the last event total at least half a person (`EVAC_MIN 0.5`) and at most `EVAC_MAX_PER_TICK` (12) per tick. `collateral_state` `{room, budget, ceilingLeft, over}` once a second for the UI and QA (the UI can show a subtle "the streets are emptying" cue, Game Design's and UI's call).
- **Cost:** the window is a few operations per tick; `kill` adds a few comparisons per building damage; the district loop runs only while over budget.
- **Determinism:** no draw from `S.rng`. All arithmetic is on fixed tables and the state above. The building order for the district loop is the array order, and the nearest-first pick uses distance with the index as the tie-break.

## 8. How it is tested (numbers QA can run)

1. **The window** (hard): over every 60 s window of every batch match, casualties at or below `budget(tier)` plus the borrowed amount of any open set piece. Outside set pieces they never exceed the budget, at every tier. A synthetic test drives casualties at 10 times the budget and checks the grant.
2. **The ceiling** (hard): the cumulative share never exceeds the ceiling for the highest tier reached; at tier 1 or 2 it can never exceed 30%.
3. **Borrowing** (hard): none at tier 1 or 2; at tier 3 and above one set piece can take at most its allowance, and the window then admits nothing until it refills.
4. **Low-tier bleed** (band, `balance-targets.md` §4): at most 4% of the population per minute while both fighters are at tier 2 or below, measured from the same casualty stream (this is now guaranteed by the 4% budget; the test guards a regression).
5. **The 90%-loss share** (band): at most 10% of game-scale matches; the testbed's 7% on the villain mirror is the acceptance test for this work (it is 10.5% today).
6. **Every source** (hard): a probe forces each source in turn (blast, beam sample, slide, launch collision, brunt, chain when B2 lands) at ten times its normal strength with the budget at zero, and checks casualties stay zero and evacuations account for the rest (`casualties + evacuated` equals what would have died).
7. **The choke point** (hard): no call to `casualty(` outside `collateral.gd`.
8. **Normalisation** (hard): with `pop0` doubled (a synthetic planet) the menace and anguish after the same share of the population lost are equal, to a tolerance.
9. **Evacuation reads** (Rendering and QA together): a district that has been over budget for 5 s has no figure standing under a blast; the number of runners equals the events' `n`.

## 9. Fit with the queue and open points

- **Slot:** the sim window after Encounter's S2, with B1: the cap needs `damageBuilding` in the state B1 rewrites (rows, rubble), and B1's `building_fall` events must carry the evacuated count. If B1 slips, the cap can go first because it touches only `structures.gd`, `damageBuilding`, `casualty` and `tierUp`.
- **Golden and QA:** one regeneration; the testbed's mean-at-KO band retires as Game Design says.
- **Encounter:** the planner's chain and slide scoring read `room` and `evtLeft`; the hero and villain AI can read `over` (a villain over budget has nothing to gain from a populated district and should leave; a hero can use the emptied districts).
- **Open for Orb, through Game Design:** whether evacuees can return after a long quiet (proposed: no); whether the district-emptying rate (30% a second) reads as a flight or as a teleport (Rendering decides in a look-dev pass); whether the UI shows the budget at all.
- **Risk:** civilians can be seen to survive a hit if the crowd behaviour is late. The event is emitted in the same tick as the damage; Rendering must start the runners from that tick, not after.
