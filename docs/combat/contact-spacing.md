# Contact spacing and sides: the data side

Owner: Combat and Choreography. Date: 2026-10-01. Status: a parked data change (`pending/templates.contact.json`, `pending/finishers.contact.json`), measured on the live sim. No live data was edited. Encounter has the sim side.

**Why.** Orb wants full contact on every hit and no passing through. Animation measured the fault (`docs/animation/pose-pipeline.md` section 9.3):
- 41% of hits land farther apart than a hand, the hips' lunge and a step-in can reach (about 68 u centre to centre), or at another height;
- the fighters swap sides inside exchanges.

The rule this note makes data: **on every damaging strike's contact tick, the two fighters are within 68 u, at the same height, on known sides.**

---

## 1. What causes the gaps today
From the beats (`data/combat/templates.json`, `dynamic` profile) and the sim:

| Cause | Effect | Where |
| :--- | :--- | :--- |
| **Knockback is never re-closed.** Each strike pushes its target 35 to 60 u over the next quarter second, and the next strike lands with nobody stepping back in | the gap grows through a string | TRADE BLOWS, PRESSURE, GUARD BREAK |
| **The dodge places the defender 74 u behind the attacker,** at a height up to 70 u off | the counter strikes from 74 u and from above or below | DODGE & COUNTER |
| **The chain link stops closing 3 ticks before its strike,** while the body is still flying | the strike lands on a body that has moved on | every chain link |
| **Finisher strikes come up to 21 ticks after the catch,** with the loser still moving | the same | the authored finishers |
| **Offsets are taken from the mover's facing, which goes stale** after a dodge or a swap | a "turn" or re-close goes *through* the opponent | sim side (Encounter) |

## 2. The measurement
A read-only probe on the live GDScript sim: 12 AI-vs-AI matches, seeds 1 to 12. It checks every damaging strike inside a melee exchange (about 5,500 strikes), leaving out impacts and signatures. The second column runs the same sim reading the parked contact data.

| Template | Live data: beyond 68 u | Live: at another height | Contact data: beyond 68 u | Contact: at another height |
| :--- | ---: | ---: | ---: | ---: |
| TRADE BLOWS | 61% | 16% | 0% | 0% |
| PRESSURE — GUARD HOLDS | 53% | 10% | 1% | 1% |
| PRESSURE → COUNTER | 64% | 12% | 0% | 1% |
| GUARD BREAK | 61% | 14% | 2% | 0% |
| DODGE & COUNTER | 80% | 37% | 0% | 0% |
| DODGE & READ | 19% | 11% | 6% | 2% |
| HEAVY CLASH — WON | 30% | 18% | 13% | 0% |
| PURSUIT — CAUGHT | 32% | 12% | 12% | 2% |
| HEAVY CLASH — COUNTERED, CLASH SHOCKWAVE | 0% | 0% | 0% | 0% |
| **All melee strikes** | **52%** | | **2%** | |

- **The step-ins fix the strings.** The median spacing at contact is 58 u in every template.
- **The remaining 2% needs the sim** (section 5). They are strikes on a fast-moving body: chain links after a launch (counted under their exchange's tag), and openers on a sprinting defender. A one-tick slip between the closing move's last step and the strike beat leaves a launched body 100 u or more away.
- **Side swaps** inside exchanges fall from 1,729 to 1,223 (in about 2,200 exchanges) from the data alone. The rest are the dodge's own cross-over and the stale-facing offsets, which are the sim's.

The current loader ignores the 2b selector changes in the parked file, so the second column measures spacing, not balance.

## 3. The data change

Built on the parked 2b files, so it applies after 2b. Only the `dynamic` profile and the authored finishers change.

**The contact block** (`profiles.dynamic.contact`): `reach` 68 u, `offset` 58 u (where an approach, lunge or step-in ends), `minSeparation` 45 u (no overlap), `sameHeight` true, and the sides rule in words.

**The step-in.** A 6-tick move (`tempo.stepIn`) that closes the striker to 58 u on its own side, at the target's height, **ending on the strike's contact tick**. It is a `rush` for the attacker and a `finRush` for the defender, both with `"side": "own"`. It is the strike's anticipation: the step is the tell.

| Template | Change | Each strike's spacing source |
| :--- | :--- | :--- |
| TRADE BLOWS | a step-in before the second, third and fourth blows (the defender, the attacker, the defender) | the opener: the approach. The deciding blow: the 18-tick lunge (2b) |
| PRESSURE | a step-in before the second and third strikes (and before the old counter) | the opener: the approach |
| GUARD BREAK | a step-in before the second strike and before the breaking strike | the opener: the approach |
| HEAVY CLASH | none | the 20-tick lunge already ends on the deciding blow |
| DODGE & COUNTER | a step-in by the defender before its counter | closes the 74 u and the height difference |
| DODGE & READ, DODGE — CLEAN | the attacker's turn is marked `"side": "own"` | it closes on its new side, never through the defender |
| PURSUIT — CAUGHT, CHARGE INTERRUPT, CLEAN HIT, RIPOSTE | none | the approach ends on the strike |
| Chain link | the catch (`tempo.chainClose`, 12 ticks) now ends on the chain strike, at 58 u | was 60 u, ending 3 ticks early |
| Finishers (generic, KAI, VORR) | a 6-tick step-in before every strike and before the final blow. VORR's grab and drop close to 48 u (was 40 and 30, inside the bodies), and the drop ends on the stomp | the loser is often still moving when a finisher strike lands |

**Sides.**
- **Default:** every move keeps the mover on its own side.
- **The one cross-over in the data** is the `dodge` beat, marked `"side": "cross"` (the defender goes behind the attacker). Whether the dodge stays a blink while teleporting is on hold is still open with the EP and Orb.
- **Each branch states where the pair ends** in `endSides`: `swapped` for the three DODGE branches, `same` for every other.
- TRADE BLOWS' "circle", which crossed through the opponent, is already gone in 2b.

**Timing.** No contact tick moves. The step-ins sit inside existing gaps, and VORR's drop onto the foe now lasts 21 ticks so that it ends on the stomp.

## 4. Animation's key sets: limb and target
Animation's key sets (`data/anim/keysets.json`, render-only) name a striking `limb` (`hand_r`, `foot_r`, mirrored for the left) and a `target` (head, chest, gut). Checked against Combat's pieces (`moveset-system.md` section 1.1 and the part cue, section 7.4):

| | Animation today | Combat's plan | Agreed form |
| :--- | :--- | :--- | :--- |
| Limb | an effector id: `hand_r`, `foot_r` | a limb family (fist, elbow, knee, foot, head, shoulder) plus `side` | the part cue carries Animation's effector id as `limb`. Later pieces need more effectors: elbow, knee, head, shoulder, and a fighter's own |
| Target | a socket: head, chest, gut | the Wounds `region`: head, core, arms, legs | the piece names a `target` socket, and the region follows from it: head is head; chest and gut are core; an arm socket is arms; a leg socket is legs |
| The six key sets | jab, cross, hook, upper, kick, round | jab, cross, hook, uppercut, front kick, roundhouse | the same strikes. Combat uses Animation's ids: `strike.upper`, `strike.kick`, `strike.round` |

**One real disagreement, in the sim today.** The wound region is drawn after the hit, by attack weight: lights go to the head and arms, heavies to the core and legs. The key set is picked on the render side, by weight alone. So a jab can show a hit to the head while the wear goes to the arms, and no key set targets an arm or a leg at all.

- **Now, on the render side:** pick the key set from the damage event's region where one matches (head: jab, hook, upper; core: cross, kick, round).
- **At M0:** the composer picks the piece (limb and target) when the exchange is planned, and the wound follows the target. "Go for the wound" becomes a weight on which piece is chosen, not a separate hidden draw. That is Encounter's and Game Design's change.
- **Animation:** add arm and leg targets when low kicks and guard strikes are authored.

## 5. What the sim side must do (Encounter)
1. **Offsets by side, not by facing.** A `rush` or `finRush` offset is measured on the mover's current side of its target along the shortest arc. Only `"side": "cross"` may change sides.
2. **The closing move lands before the strike, in the same tick.** A strike's striker is at the contact offset on the contact tick: either the move's last step is guaranteed to run before the strike beat, or the strike itself places the striker. This closes the remaining 2%.
3. **No overlap.** Bodies never come closer than `minSeparation`.
4. **Facing follows the opponent every tick** while in an exchange (`blitz.md` section 3).
5. **A reach check for QA.** On every damaging strike, emit or assert the centre-to-centre distance and the height difference. Target: 100% within 68 u and the same height.

## 6. Schema changes for Tools (with the contact files)
Found by validating the parked files against the 2b schemas in a scratch copy:

| # | Change |
| ---: | :--- |
| 1 | a branch's `endSides`: `same` or `swapped` |
| 2 | `profiles.dynamic.tempo.stepIn` and `tempo.chainClose` |
| 3 | `profiles.dynamic.contact` (`reach`, `offset`, `minSeparation`, `sameHeight`) |

The `side` argument on `rush`, `finRush` and `dodge` already passes, because beat arguments are open. `finishers.contact.json` passes as it is.
