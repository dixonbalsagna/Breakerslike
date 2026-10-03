# Go-live step 1: wave 1's long and mid-range strikes in today's game

Owner: Combat and Choreography. Date: 2026-10-01. Status: a parked change, for Animation to apply and Encounter to know about. **To be switched on after Orb's review of the wave 1 pack.** The data is `golive-step1.picks.json` in this folder. It is step 1 of the order in `waves-index.md`.

**What it does.** Today every blow in a fight is one of six placeholder key sets, picked by weight. This puts 23 of wave 1's posed strikes in their place. It changes no sim file and no combat data, so replays, goldens and the data hash are untouched: `data/anim/` is outside the hash.

**What it does not do.** The director still does not choose the blow; the animator does, by a hash. So the broken-limb rules and the no-repeat rules of `wave1-strikes.md` are only approximated here (section 4). The 11 close strikes (elbows, knees, the headbutt, the shoulder) stay out: at today's one distance of 58 u they are out of reach.

## 1. The change (Animation's files)
1. **Load wave 1 in live matches:** the key sets and poses of `data/anim/waves/wave1.*`, which today load only with `--waves`.
2. **Replace the two pick lists** in `data/anim/keysets.json`:

| List | Today | Step 1 |
| :--- | :--- | :--- |
| `light` | jab, cross, hook, kick | 11: jab, cross, hook, backfist, palm heel, spear hand, twin spear, front kick, side kick, low kick, snap round |
| `heavy` | upper, round, hook, cross | 10: uppercut, hammer, overhand, haymaker, double palm, double hammer, roundhouse, axe kick, spinning heel, stomp |

3. **Two more behind a gate** the animator can read from the fighters' state: the sweep (light) only when both fighters are on the ground, and the drop kick (heavy) only when the striker is in the air.

That is 23 strikes: 21 in the lists and 2 gated.

## 2. The seven that need a small step in at 58 u
The sim places every striker at 58 u. Sixteen of the 23 land there on the hips' lunge alone. Seven need the contact solve's whole-body step, which reads as a short lunge of the whole fighter. All seven are inside their measured reach.

| Strike | Lands on the lunge to | Step in at 58 u | Reach with the step | Note |
| :--- | ---: | ---: | ---: | :--- |
| side kick | 56 u | 2 u | 70 u |  |
| hammer | 56 u | 2 u | 86 u |  |
| sweep | 52 u | 6 u | 72 u |  |
| roundhouse | 50 u | 8 u | 78 u |  |
| spinning heel | 50 u | 8 u | 70 u |  |
| drop kick | 50 u | 8 u | 64 u |  |
| axe kick | 48 u | 10 u | 68 u | at the foot's default limit of 10: give the key set a `step_max` of 12 |

Six of them are kicks, and the seventh is the hammer by 2 u. They sit properly when each strike has its own distance (`../contact-spacing.md` section 8).

## 3. Which templates they suit
The animator calls a blow heavy when the exchange is heavy, the blow is marked big, or its damage is 40 or more. Everything else takes the light list.

| Template | Its blows | List today's code would use |
| :--- | :--- | :--- |
| CLEAN HIT (light) | one opener | light |
| TRADE BLOWS | the attacker's opener, three exchanged blows from both fighters, the deciding blow | light, for both fighters |
| PRESSURE | an opener and two more; the defender's counter in one branch | light |
| GUARD BREAK | an opener, a second blow, the breaking blow | heavy, all three |
| HEAVY CLASH | the deciding blow, from either side | heavy |
| CLEAN HIT (heavy) | one opener | heavy |
| DODGE (read, counter), PURSUIT (caught), CHARGE INTERRUPT, RIPOSTE | one blow | by the exchange's weight |
| A chain link | each link | light |
| The finishers | the winner's two or three blows | heavy |

**Better, with one more read (step 1b).** Each strike beat in the live data carries its class since 2b. If the animator reads it, the lists can follow the class as well as the weight. Still no sim change.

| The blow | List |
| :--- | :--- |
| A light opener | jab, cross, spear hand, front kick |
| A mid-string blow or a chain link, in any exchange | the light list |
| A heavy opener | uppercut, overhand, haymaker, double palm, roundhouse (and the drop kick, in the air) |
| An ender or a heavy: TRADE BLOWS' deciding blow, GUARD BREAK's breaking blow, HEAVY CLASH's | the heavy list |

With 1b, TRADE BLOWS' deciding blow becomes a real ender, sized by its damage through Animation's blow weight, and GUARD BREAK's second blow becomes a quick one between two heavies.

## 4. Three small render-side rules that would make it read as intended
None is needed to switch step 1 on. Each is Animation's call.
1. **No repeat inside an exchange.** Today's pick is a hash of the blow's number, so the same key set can come up twice running. Walk the list instead: start at a hash of the exchange and the fighter, and take every third entry. Three shares no factor with 11 or 10, so nothing repeats inside ten blows.
2. **A broken limb, as drawn.** The animator already moves a blow off a limb it is drawing as broken. With these lists it should also skip a two-limb key set (the twin spear, the double palm, the double hammer; the drop kick) and take the next in the walk.
3. **His strikes on his shape.** Wave 1 is the Anti-hero's. Today the placeholder with his shape key (A) is VORR. I recommend these lists for shape A only and today's lists for the rest, as `shapes.json` already does for idles and flinches. The fallback is to give both fighters the lists.

## 5. Known limits until the director picks the blows
- **Direction.** A blow with a clear direction (the uppercut up; the hammer, the axe kick, the stomp and the double hammer down) may be followed by a launch that goes another way. The launch is planned three ticks after the blow, so the animator cannot know it.
- **Target and wound.** The key set names a socket and the sim draws the wound region after the hit, so a blow to the head may wear the arms.
- **Classes.** Without step 1b, an ender-only strike such as the hammer can play as an opener.
- **Seven strikes lunge** (section 2).

## 6. Before it is switched on
| Step | Who |
| :--- | :--- |
| Orb's review of the wave 1 pack, with a letter for each of the five A/B pairs (the uppercut, the double palm, the roundhouse, the axe kick; the headbutt's is not in this step) | Orb |
| The list takes the chosen version of each: `w1.<strike>` or `w1.<strike>~b` | Animation |
| `anim_check` on the live seeds with the new lists: every contact within reach, the gameplay hash unchanged | Animation |
| A look at the first reel for the seven that lunge | Animation, then Orb |

## 7. For Encounter
- **Nothing to change.** No beat, op, tempo or contact value moves, and the data hash is the same.
- **What you will see:** the same exchanges with different blows drawn, and seven strikes whose attacker slides in by 2 to 10 u on the contact tick. That slide is the animator's, not the sim's: positions in the sim are unchanged.
- **When your per-strike distance and the piece choice land (M0),** these lists go away: the part cue names the piece, and the step-in ends at the piece's own distance.
