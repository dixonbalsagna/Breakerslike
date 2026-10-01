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

**The contact block** (`profiles.dynamic.contact`): `reach` 68 u, `offset` 58 u (where an approach, lunge or step-in ends), `minSeparation` 45 u (no overlap), `sameHeight` true, `placementReaches` 3, and the sides rule in words. `placementReaches` is Encounter's placement limit (`docs/director/contact-plan.md`, rule 2): a damaging strike places its striker at the offset when the target is within 3 reaches (204 u).

**The step-in.** A 6-tick move (`tempo.stepIn`) that closes the striker to 58 u on its own side, at the target's height, **ending on the strike's contact tick**. It is a `rush` for the attacker and a `finRush` for the defender, both with `"side": "own"`. It is the strike's anticipation: the step is the tell.

| Template | Change | Each strike's spacing source |
| :--- | :--- | :--- |
| TRADE BLOWS | a step-in before the second, third and fourth blows (the defender, the attacker, the defender) | the opener: the approach. The deciding blow: the 18-tick lunge (2b) |
| PRESSURE | a step-in before the second and third strikes (and before the old counter) | the opener: the approach |
| GUARD BREAK | a step-in before the second strike and before the breaking strike | the opener: the approach |
| HEAVY CLASH | none | the 20-tick lunge already ends on the deciding blow |
| DODGE & COUNTER | a step-in by the defender before its counter | closes the 74 u and the height difference |
| DODGE & READ, DODGE — CLEAN | the attacker's turn is marked `"side": "own"` | it closes on its new side, never through the defender |
| All three DODGE branches | the `dodge` beat is a step-around, with its numbers on the beat: `dur` 8 ticks (`tempo.stepAround`), `rise` 98 u over the attacker, `off` 74 u behind it | they were Encounter's code constants. 74 u is outside reach on purpose: the next strike has its own step-in or turn |
| PURSUIT — CAUGHT, CHARGE INTERRUPT, CLEAN HIT, RIPOSTE | none | the approach ends on the strike |
| Chain link | the catch (`tempo.chainClose`, 12 ticks) now ends on the chain strike, at 58 u | was 60 u, ending 3 ticks early |
| Finishers (generic, KAI, VORR) | a 6-tick step-in before every strike and before the final blow. VORR's grab and drop close to 48 u (was 40 and 30, inside the bodies), and the drop ends on the stomp | the loser is often still moving when a finisher strike lands |

**Sides.**
- **Default:** every move keeps the mover on its own side.
- **The one cross-over in the data** is the `dodge` beat, marked `"side": "cross"` (the defender goes behind the attacker). While teleporting is on hold it is a step-around, not a blink: over the attacker and down behind it (Encounter's contact plan, rule 7).
- **Each branch states where the pair ends** in `endSides`: `swapped` for the three DODGE branches, `same` for every other.
- TRADE BLOWS' "circle", which crossed through the opponent, is already gone in 2b.

**Timing.** No contact tick moves. The step-ins sit inside existing gaps, and VORR's drop onto the foe now lasts 21 ticks so that it ends on the stomp. The step-around takes 8 ticks where the blink took none, and it fits: DODGE & COUNTER's step-in starts 9 ticks after the dodge beat, and in the other two branches the attacker's turn ends 12 ticks after it. Keep `tempo.stepAround` at 9 ticks or under.

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
6. **A parry ends the string.** Pending beats are dropped when the parry lands, so no strike or step-in runs after it (section 7).
7. **No launch goes back through the launcher** (Encounter's rule 8). A target behind the launcher is no longer offered; the turn throw that brings it back is in `launch-vectors.md` section 5.
8. **The contact distance becomes per strike at M0** (section 8).

## 6. Schema changes for Tools (with the contact files)
Found by validating the parked files against the 2b schemas in a scratch copy:

| # | Change |
| ---: | :--- |
| 1 | a branch's `endSides`: `same` or `swapped` |
| 2 | `profiles.dynamic.tempo.stepIn` and `tempo.chainClose` |
| 3 | `profiles.dynamic.contact` (`reach`, `offset`, `minSeparation`, `sameHeight`) |
| 4 | `profiles.dynamic.tempo.stepAround`: ticks, required |
| 5 | `profiles.dynamic.contact.placementReaches`: a number above 0, required |

Rows 4 and 5 came after Tools' `apply-contact.cjs` (`32e0271`), which needs them added. Checked in a scratch copy: with those two keys the parked files give 0 errors and self-test 903 of 903; without them, exactly those two errors. The dodge beat's `dur`, `rise` and `off` pass as they are. A check worth adding: a dynamic `dodge` beat with `side` `cross` gives all three, with `rise` above 0 and `off` not below `minSeparation`.

The `side` argument on `rush`, `finRush` and `dodge` already passes, because beat arguments are open. `finishers.contact.json` passes as it is. The `_lead` note in the contact block (section 7) needs no schema change: keys that start with `_` are notes.

## 7. Blows "announced late": the cause is the parry, not the schedule
Animation asked for every TRADE BLOWS strike to be scheduled at least 6 ticks before it lands: its check counts blows that first reach the animator under 4 ticks ahead and pop to their contact pose (7 or 8 of 78 in `docs/animation/pose-pipeline.md` section 9.4; 10 of 41 in seed 4 at HEAD `5923c29`).

**The schedule already meets it.** Every strike beat is put in the exchange's list when the exchange, chain link or finisher is planned.

| Measured on a clean copy of HEAD `5923c29` (12 AI matches, seeds 1 to 12, read-only probe) | Live data | Parked contact data |
| :--- | ---: | ---: |
| Strike beats in the list under 6 ticks before they land | 0 of 4,776 | 0 of 4,604 |
| Chain strikes in the list under 6 ticks before they land | 0 of 660 | 0 of 544 |
| Shortest lead, template and finisher strikes | 15 ticks | 15 ticks |
| Shortest lead, chain strikes | 12 ticks | 12 ticks |

A static check of the parked files agrees: 34 strike beats, the shortest lead 12 ticks (the chain link), every exchange's first strike at `approach.min` (15 ticks) or later. So **no beat moves**. The rule is recorded in the contact file (`profiles.dynamic.contact._lead`).

**What Animation is seeing.** The 10 blows its check flags in seed 4 are, tick for tick, the 10 strike beats left over in three parried exchanges (parries at ticks 871, 3,182 and 4,027). Traced on the first:

1. Tick 871: the defender parries the TRADE BLOWS opener. The sim sets `ex.cancel`.
2. The other four strike beats stay in the list. Each comes due on its own tick (895, 908, 922, 939), is marked done, and does nothing: no damage, no event.
3. The animator hides a cancelled exchange's strikes until they are done, then shows them. So each one appears on its "contact" tick, with no wind-up, for a blow that never happened.

They are **phantom blows**, not late ones. Scheduling them earlier cannot help: they are already 13 to 58 ticks ahead when the parry lands. The two in HEAVY CLASH are chain strikes after a parried deciding blow (defect CC-001, `move-grammar.md`: a parried exchange still opens its chain window).

**How much.** On live data, 167 of 2,163 exchanges are parried (8%).

| After a parry (live data) | Count |
| :--- | ---: |
| Strike beats that come due and do nothing | 536 (9% of all strike beats that come due) |
| Moves that still run (backstep, lunge, pursuit) | 344 |
| Time the exchange stays open after the parry | 56 to 101 ticks on average by template (about 1 to 1.7 s) |

That last row is also part of Orb's "they lock together and do nothing": for over a second after a parry the pair is held in an exchange in which nothing can land.

**The fix is in two places, neither in the data.**
- **Render (Animation), now:** a strike beat of a cancelled exchange is drawn only if it had already landed when the parry came. Remember the exchange time at which `ex.cancel` was first seen, and skip strike beats timed after it.
- **Sim (Encounter):** a parry ends the string. Drop the pending beats when the parry lands (as the finisher takeover already does) and end the exchange, or play a short parry takeover (`control-scheme-data.md`, interrupts as branch takeovers). Gate it to the profiles that have a `parry` block, as the parry rewards already are, so `parity` stays bit-identical. It changes the goldens for `dynamic`.

**Order matters for the contact data.** The contact file adds step-ins before the second, third and fourth blows. Step-ins are moves, and moves still run after a parry. With today's sim, a parried TRADE BLOWS on the contact data would show three step-ins, a backstep and a lunge with no blows between them. Measured with today's sim: 2.5 moves run after each parried TRADE BLOWS on live data, 5.4 on the contact data. So the sim fix should land with the contact data or before it.

## 8. The per-strike contact rule (canonical)
This is the rule the other documents point to (Game Design: `docs/design/moveset-rules.md` section 11(l)). It takes effect at M0, when a strike beat names a slot and the director fills it with a piece. Until then every strike uses the one distance in section 3.

1. **Each strike piece carries three measured distances** (Animation's pack, `art/animation/review/wave1/reach-table.md`): *clear*, the nearest at which nothing but the striking limb touches the rival; *lunge*, the farthest it lands at on the hips' lunge alone; *reach*, the farthest with a whole-body step-in as well.
2. **Its contact distance is the smaller of 58 u and its lunge, and never under its clear distance.** So every blow lands on the lunge alone and nothing else passes into the rival. The posed strikes run from 28 u (the short knee) to 58 u.
3. **The clinch floor is 28 u.** A strike's own step-in, and a grab's hold (36 u), may end that close. Every other move keeps `minSeparation` 45, and after a close blow two resting bodies are moved back apart.
4. **The step before a strike is a range step:** it ends at the strike's own distance, on the striker's own side, and may open the distance as well as close it.
5. **The data:** `profiles.dynamic.contact.clinch` 28; `contact.offset` 58 and `contact.reach` 68 stay as the defaults for a strike with no piece; each piece carries `range.clear`, `range.lunge`, `range.reach` and `range.offset`. The pieces are in `pending/strikes.antihero.wave1.json`.
