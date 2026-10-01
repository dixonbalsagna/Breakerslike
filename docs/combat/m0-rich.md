# M0 at the rich end: the Anti-hero's first real moveset

Owner: Combat and Choreography. Date: 2026-10-01. Status: plan, with a parked piece list (`pending/moveset.antihero.m0.json`). The waves authored so far are in `pending/`: `wave1-strikes.md`, `wave2-entries.md`, `wave3-pingpong.md` (with the one definition of the flight paths), `wave4-grabs.md` (the grab family, wave 7 in section 11's table, brought forward by the EP), `wave5-clashes.md` (the pulse clashes and the beam answers), `wave6-energy.md` (the energy family) and `wave7-first-kit.md` (3 specials, 2 place signatures, 6 showcases). `waves-index.md` is the one-page index. Animation's review plan (`docs/animation/review-plan.md`) has since cut section 10's pose estimate to about 295 and section 11's review to about 3 hours. No live data and no code. It replaces the Lean target for the first real fighter and revises the counts in `moveset-system.md` sections 6 and 9.6 for him. The grammar in that document is unchanged.

**Why.** Orb withdrew the Lean choice (`docs/ep/vision.md`, last section): "work towards an optimistic overhaul of the current animation system: try to maximize the dynamic animations". Lean was 3 specials, 4 signatures and 6 showcases on the basic set. This plan sizes every piece family so that he does not repeat himself, including with a broken arm or leg (`docs/design/spec-wounds.md` section 1d).

**Who he is, for the pieces.** The Coil: a low crouch, a tail, plated forearms and spine. Brutal and showy, barrages of shards, finishes by hand, the Proud front, Pride and three forms (Regalia, Sovereign, Apex), and Abdicate. Art's design is not final. Every tail piece is in a slot called "own limb", so a design change swaps the limb and keeps the count.

Every name here is a working label. Narrative names what shows on screen and Legal screens it.

---

## 1. The counts at a glance

| Family | Earlier plan (Lean at the top of the kit) | Rich M0 | Why this many |
| :--- | ---: | ---: | :--- |
| Key strikes (physical) | 24 | **38** | section 2: no repeat inside a string after any one broken limb, with room to spare |
| Energy strikes | about 36, estimated | **31, listed** | 13 of the strikes also emit, plus 4 energy poses, across 7 emission shapes |
| Entries | 11 | **15** | rush 6, stand 5, retreat 4; one of each direction survives a broken leg on the ground |
| Feints | 4 | **6** | one per limb family, one for energy |
| Grab, throw, tackle, dive grab, reversal | 6 | **16** | 7 throws: 3 per direction held, 2 per direction with one arm |
| Taunts | 1 | **4** | at most 3 a match, so none repeats in a match |
| Beam answers | 0 | **3** | swat, split, walk through |
| Pulse clashes | 0 | **3** | fist clash, blur exchange, grapple lock |
| Finisher shapes | 1 | **3** | by form: base, Abdicate, Apex |
| Specials in the pool | 3 | **8** | the loadout is 3, so 8 gives 56 loadouts where Lean gave 1 |
| Signatures | 4 | **8** | 3 by place, 3 by form, 2 revealed (one of them later) |
| Showcases | 6 | **16** | section 9: each plays about once a match, where Lean's 6 played twice a match, every match |

Not in M0: props (lift, carry, two throws, a slam: 5 pieces, with World's liftables) and the civilians action (Game Design's rules and Legal's screen first).

## 2. Strike pieces by limb and weight, and the broken limb

**The 38 key strikes.** A light fills an opener, a mid-string hit or a return blow. A heavy fills a heavy opener or an ender. An ender is not a separate piece: Animation's blow weight plays the same heavy with a longer load and a deeper follow-through.

| Limb | Light | Heavy | Pieces |
| :--- | ---: | ---: | :--- |
| Fist (one arm) | 6 | 4 | jab, cross, hook, backfist, palm heel, spear hand; uppercut, hammer, overhand, haymaker |
| Elbow (one arm) | 2 | 2 | short, rising; spinning, dropping |
| Two arms | 1 | 3 | twin spear; double palm, double hammer, cross-arm ram |
| Foot | 5 | 5 | front, side, low, snap round, sweep; roundhouse, axe, spinning heel, stomp, drop kick |
| Knee | 1 | 2 | short; rising, driving |
| Head | 0 | 1 | headbutt (not with a battered head) |
| Torso | 1 | 1 | shoulder check; body ram |
| Own limb (the tail) | 2 | 2 | tail jab, tail sweep; tail whip, tail spike |
| **All** | **18** | **20** | **38** |

**Limb tags** (in the parked file, per piece): `uses` (arms 1 or 2, legs 1 or 2, head, own) and `ground` (plays anywhere; needs the other leg to stand on when grounded; ground only; air only). Left and right are one piece: the mirror is free, so a one-arm piece plays on whichever arm is good.

**The rules a break applies** (spec-wounds 1d, as a filter on the tags):
- *A broken arm:* two-arm pieces are dropped. One-arm pieces play on the good arm, and two arm strikes never run back to back.
- *A broken leg:* two-leg pieces are dropped. In the air a kick or knee plays on the good leg. On the ground every piece that needs a standing leg is dropped, so he fights with fists, elbows, his head and the tail.

**What is left** (computed from the parked file):

| | Lights | Heavies | Enders | Return blows | Energy lights / heavies | Lights off the hurt pair |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| Healthy, in the air | 17 | 20 | 16 | 7 | 16 / 15 | |
| Healthy, on the ground | 18 | 19 | 16 | 7 | 16 / 15 | |
| Broken arm, in the air | 16 | 17 | 14 | 7 | 14 / 13 | 8 |
| Broken arm, on the ground | 17 | 16 | 14 | 7 | 14 / 13 | 9 |
| Broken leg, in the air | 17 | 19 | 16 | 7 | 16 / 15 | 12 |
| **Broken leg, on the ground** (the worst case) | **12** | **10** | 10 | 5 | 16 / 12 | 12 |

**The three tests, and how the counts meet them.**
1. **No key strike twice in a string.** The longest run of blows by one fighter is 8: three in an exchange and five chain links. So he needs 8 distinct lights and 4 distinct heavies in every row. The worst row has 12 and 10.
2. **Never the same limb twice running when one of the pair is broken.** That needs 4 lights that use neither arm (or neither leg) in a string of 8. The worst row has 8.
3. **Three-strike series stay under Game Design's 10%.** By chance alone, before the variety memory steers: with n lights there are about n(n−1)(n−2) × 0.45 valid series, and about 100 attacking strings a match. That gives about 3% of strings repeating a series when healthy (17 lights) and about 8% in the worst row (12 lights). The 24-strike list would have given about 6% healthy and about 22% in the worst row (13 and 9 lights by my reading of it). Both the 0.45 and the 100 are estimates; Tools' enumerator and QA replace them.

So the reason for 38 is test 3 in the worst row, and the margin in test 1. The cheapest pieces for it are the four tail strikes and the two that use neither arm nor leg (headbutt, shoulder check), because they survive every break.

## 3. Entries by direction held and by mode

The same 15 body entries serve both modes. In energy mode Animation's aim layer turns the arms and the fire rides on top, so energy adds no entry poses.

| Direction held | Physical | Energy | Entries |
| :--- | :--- | :--- | :--- |
| Toward: **rush** (6) | close and strike | advancing fire, a point-blank burst on arrival | dash, arc dive, rising, skid, spiral (the blitz flight), coil spring (his own) |
| Neutral: **stand** (5) | plant and strike | turret: planted volleys and charged shots | step-in, pivot, plant-and-coil (his own), lane step, rooted |
| Away: **retreat** (4) | a counter as the rival follows | kiting blasts | backstep counter, fade, hop back, drop back (his own) |

- **A broken leg on the ground** leaves dash and rising (after the 20-tick slower take-off), rooted and fade: one of each direction at least.
- **Feints (6):** shoulder dip, half kick, false start, glance, false charge (energy), tail.
- Out-of-reach stand and retreat follow Game Design's ruling (`control-rules.md` section 8).

## 4. The energy family

- **Shapes (7, VFX):** bolt, volley, shard (his own barrage shards) are lights; arc, burst, lob (a lobbed slab, never a sphere), charged shot are heavies. Ranges, travel and looks: `pending/wave6-energy.md`.
- **Emitters:** 13 of the 38 strikes also emit (palm heel, spear hand, backfist, uppercut, hammer, overhand, twin spear, double hammer, roundhouse, axe kick, rising knee, tail jab, tail whip), plus four energy poses: charged brace, channel (two hands), kiting turn, crown release (from the shards that circle him, no hands, from Regalia). The shove is the context fallback and does no damage.
- **Hand variants (6):** open palm, pinch (thumb to forefinger), clawed palm, fist glow, blade hand, crossed forearms.
- **Legal's verdict** (`docs/legal/rule-of-cool-screen.md`, the wave 1 section): no two-finger point and no single pointing finger as an energy hand, so the pinch replaced it. The double palm is a melee strike only and no longer emits; the overhand took its two shapes, so the count stays 31. The open palm is never at the hip, and there is no palm-forward charge pose with a scream.
- **31 energy strikes** in all, each listed as an emitter and a shape. A broken arm removes the two-hand emitters and leaves 14 lights and 13 heavies.

## 5. Grab and throw, with the turning throw

| Piece | Count | Notes |
| :--- | ---: | :--- |
| Grab | 2 | a standing reach and a lunging reach, both one-handed |
| Hold | 1 | the lock; also the grapple clash's pose |
| Throws | 7 | toward: hurl (two hands), sling (one). Neutral: drive down (two), spike (one). Away: back throw (two), **turn throw** (one). Any direction: tail throw (no arm) |
| Tackle | 2 | the hit and the carry |
| Dive grab | 2 | the catch and the spike |
| Reversal | 2 | a throw, and the sweep a one-armed guard keeps |

- **Timings** (`moveset-system.md` section 9.9, unchanged): reach 10 ticks, hold 8, then the throw. The outcome table is Game Design's (`control-rules.md` section 9).
- **The turn throw** is the away throw, and also the director's throw at a brunt target behind him (`launch-vectors.md` section 5): 2 more ticks of hold, 8 of turn carrying the body round him, then the release. The pair swaps sides. It is the same piece in both uses.
- **One arm:** every direction keeps two throws (the one-hand throw and the tail throw). The throw does ×0.8 (spec-wounds 1d).
- **The thrown fighter** needs no authored poses: he is the ragdoll, pinned at the grip.

## 6. The three beam answers

A perfect block against a signature is already DEFLECT in the live data (`beam.outcomeByProfile.dynamic`). The direction held on that press picks the look (`docs/design/rule-of-cool.md` section 2). Each look is 3 poses: in, hold while the beam passes, out.

| Held | Answer | His look | Arms needed |
| :--- | :--- | :--- | ---: |
| Away | Swat | a backhand sweep; the beam is knocked aside and carves where Encounter's rule sends it | 1 |
| Neutral | Split | he turns side-on and the beam parts on his plated spine and shoulder | 0 |
| Toward | Walk through | he walks through it upright, hands open, and arrives at contact distance in front of the attacker, who is 20 ticks into recovery | 0 |

All three work one-armed. `moveset-system.md` section 9.7 said a signature cannot be perfect-blocked; Game Design has since ruled that it can, and that row is corrected.

## 7. Pulse clashes

Game Design's rule: 3 pulses, each with an 8-tick window (10 on touch); a press on the pulse is +10; a press off it misses and locks the next press out for 20 ticks. At most one big set piece every 20 s; inside that, the clash plays as its ordinary version. Game Design confirmed the spacing and the resolve ticks, and amended the tie rule to a difference under 10 (`docs/design/moveset-rules.md` section 11).

| Clash | Trigger | Pulses at (ticks) | Resolves at | What plays | New poses |
| :--- | :--- | :--- | ---: | :--- | ---: |
| **Fist clash** | a heavy meets a heavy | 24, 48, 72 | 84 | each fighter's own heavy piece meets; the lock; the winner's blow goes through as an ender and launches. Scores that differ by less than 10: both are thrown back | 3 (meet, pressing, giving) |
| **Blur exchange** | both attacking with strings queued, Tense or Frenzied, tier 2 and up | 24, 48, 72 | 84 | three bursts. Each is three alternating lights at 6-tick spacing while the pair travels, then the pulse blow. The winner's ender launches | 2 (the break apart, both sides) |
| **Grapple lock** | two grabs meet in the air, or a dive grab meets a grab | 30, 60, 90 | 102 | both holds connect; three strains; the winner throws the loser down | 4 (three strains, a one-arm lock) |

- **They are composed, not canned.** The fist clash's opening blows and ender come from the heavy pool, and the blur exchange's nine blows from the light pool, so two clashes rarely look alike. Fist clashes run at about 1.5 a minute, so this matters most there.
- **Between pulses the strain is computed:** Animation blends the pressing and giving poses by the running clash score. That needs the score in an event or a readable state value.
- The beam struggle on the pulse is Encounter's and Controls'; its six shapes are in `variety-pass.md` section 2.6.

## 8. The ping-pong rally and its ender

Rules: `control-rules.md` section 11. Choreography: `blitz.md`.

| Beat | Ticks | Piece |
| :--- | ---: | :--- |
| The intercept | 30 (24 in Frenzied) | the spiral entry: he arrives ahead of the body and turns. One new pose, the turn |
| A return blow | the last 6 of the flight are its anticipation | a light tagged `return`: jab, hook, backfist, rising elbow, side kick, snap round, tail jab. 7 healthy, 5 in the worst row, for at most 4 a rally |
| The ender | the last 18 of the flight are its wind-up | a heavy from the 16 enders; the only blow that may be a targeted smash |

- No return blow repeats inside a rally, and with a broken limb they alternate between the good arm, the legs and the tail.
- The body being hit is the ragdoll throughout: no authored poses.
- A return blow's window is its whole 6-tick anticipation. That is a new strike class, `return` (section 12).

## 9. The taunt, On the Chin, the last stand, finishers, and the top of the kit

| Piece | Rule (Game Design) | Pieces and poses | Legal |
| :--- | :--- | :--- | :--- |
| **Taunt** | meter only: Pride +6, mood +3, the face cut-in. 60 ticks exposed; a hit during it is a clean hit at ×1.2. 1 to 3 a match, 15 s apart | 4 taunts at 2 poses: a slow head tilt from the crouch; his back turned; brushing a shoulder plate; open stillness (Apex). Three need no arm | no beckoning fingers |
| **On the Chin** | hold the context button 12 ticks at Pride 60 or more; up to 4 s; absorbs 3 hits or 1 signature; nothing moves him | 6 poses: plant, hold, the absorbed signature's three (in the beam, out of it, the bravado hold), the completed absorb. The three absorbed hits are computed reactions at low strength, so they differ without poses | clear; its line gets an exact-phrase search |
| **The last stand** | the first time at the brink: a cut, the face, a line; his signature is free and ready for 20 s. No pause | 2 poses: gather, set. The signature is whichever his priority picks, aimed through the wear layers, so it reads as ragged without new poses | no glowing-blood look, no speech with a body aura, no lightning |
| **Built after his first moveset** | On the Chin and the taunt's Pride need his meter (questionnaire 8) | | |

**Finisher shapes (3).** Each keeps the contest and the two outcomes, and each one's last blow is drawn from the heavies he can still throw, so a finisher never uses a broken limb.

| Shape | When | Fixed | Composed |
| :--- | :--- | :--- | :--- |
| The verdict (in `finishers.json` today as a shape) | any form | the barrage until the loser gives way (volleys scale with Pride), the slow walk in, the contest, the last blow by hand | the barrage pattern, the last blow |
| The feral finish | after Abdicate | no barrage: a scramble of four or five blows, the contest, a drive into the ground | the scramble's pieces; the drive is one-handed with a broken arm |
| The single blow | Apex | he stands still for a long beat, the contest, one blow | which blow, and the launch |

**Specials (8), signatures (8), showcases (16).** The lists with one line each are in the parked file. The sizes come from play rates:
- **Showcases.** At most 12% of exchanges, and he attacks in about 100 a match: about 12 showcase plays a match. With 6 each plays twice a match, every match. With 16, of which about 12 are open in a typical match (four are gated by form, Abdicate or a broken arm), each plays about once. One is reserved for a broken arm: he tucks it behind his back and fights with the other as if by choice, which is the Proud front.
- **Specials.** 8 to 16 fired a match from a loadout of 3, so each fires 3 to 5 times; its dozen context variants carry that. The pool of 8 is for choice between matches. His secret technique is a ninth, joining as the fourth slot when revealed.
- **Signatures.** 2 to 5 a match. Three by place (the sweeping line, the ground shatter, a falling fan), three by form (Regalia's, Sovereign's, Abdicate's), and two revealed (at Apex; a rivalry thread, later).

## 10. What each piece needs from Animation, and how its new layers change the counts

> **Real numbers from wave 1** (Animation's pack, `art/animation/review/wave1/`): 34 strikes posed from 23 authored contact sketches and 11 derived; 117 poses in the pack, the wind-ups and follow-throughs generated; about 2 minutes of machine time and about 25 minutes of Orb's review. So the estimates below overstate both the authoring and the review. Count authored sketches, as the wave sheets and `pending/waves-index.md` now do, and reckon Orb's review at about 25 minutes a wave.

Animation now has an active ragdoll, hit reactions computed from the blow, per-fighter shapes, look-at and aim, blow weight, ground feet and inertialisation (`docs/animation/pose-pipeline.md` sections 9.8 and 9.9). So a piece needs fewer authored poses than the earlier plans assumed. Pose counts are Combat's estimates, for Animation to confirm.

| Piece type | Authored | Now computed | New asks |
| :--- | :--- | :--- | :--- |
| Key strike | contact and follow-through; a chamber for about 6 in 10 (2 to 3 poses) | the weight (load, follow-through, overshoot), the reach to the target, the side (mirror), aerial and low variants | effectors for elbow, knee, head, shoulder and tail; target sockets on arms and legs; the broken side read from the sim |
| Reaction | none | direction, force, region, wear, a variant per hit | a strength input per situation: guarded (exists), On the Chin, held in a grab |
| Launch, flight, landing | none (a tech flip: 1) | flail, tuck, brace, crumple, skid, skip; his own shapes from the table | none |
| Entry | 1 launch-off pose | the lean into speed, the arrival | none |
| Throw | 1 or 2 for the thrower | the thrown body | a pin: the ragdoll held at a socket, and hands that follow the other fighter |
| Clash | the lock and two strain poses | the strain between pulses | the clash score as a value it can read |
| Beam answer | 3 per look | the aim along the beam | none beyond VFX's parted and deflected beam |
| Taunt, On the Chin, last stand | 2, 6, 2 | the absorbed hits, the ragged aim | a low reaction strength for the stance |
| Special, signature, showcase, finisher | about 10, 9, 5 and 10 (were 16, 14, 7 and 14) | the victim, the aftermath, the recovery, place and height variants | none |

**How the counts change.**

| | Poses |
| :--- | ---: |
| The basic and system pieces of sections 2 to 9 | about **170 to 220** (about 20 exist in sketch form) |
| Specials 8, signatures 8, showcases 16 | about 190 to 270 |
| Finisher shapes 3; three forms, Abdicate and the crash with their break beats | about 70 |
| **The rich M0** | **about 440 to 570** |
| The same list at the earlier per-piece costs | about 700 |
| For reference, Animation's table (`pose-pipeline.md` section 6.4): Lean, Full | 471, 793 |

- The new layers remove about 50 basic poses outright: 20 reactions, 14 flight and landing poses, 12 aerial and low variants, 4 arrival braces.
- They remove about a third of each special, signature, showcase and finisher: the struck fighter, the aftermath and the recovery.
- So the rich list costs between what Lean was costed at and a fifth more, and well under Full. Animation's foundation and control-scheme poses (stances, flight, guard, dodge, sprint, power) are not counted here; most exist.

## 11. The order to author in, and the reviewer time

Each wave ends with something Orb can see in play. Review is Animation's format: contact sheets of 12 poses and a motion reel per piece, at its rate of about 3 minutes a pose with a second look.

| # | Wave | Pieces | New poses | Orb's review (poses and reels) | Waits for |
| ---: | :--- | :--- | ---: | ---: | :--- |
| 1 | **Strikes and the broken-limb filter** | 38 key strikes with limb tags | 55 to 95 | 3 to 5 h | the M0 contract (the part cue, the composer's skeleton); the broken side in the sim |
| 2 | Entries and feints | 15 and 6 | about 20 | 1 h | wave 1 |
| 3 | The ping-pong and its ender | tags, 1 pose | 1 | under 0.5 h | wave 1; Encounter's blitz |
| 4 | Fist clash and the three beam answers | 2 set pieces | 12 | about 1 h | the pulse rule; step 3's per-strike windows |
| 5 | The energy family | hands, energy poses; VFX's 7 shapes | 11 | about 1 h | VFX's shapes |
| 6 | **A first kit** (the old Lean slice) | 3 specials, 2 place signatures, 6 showcases | about 80 | 4 to 5 h | waves 1, 2 and 5 |
| 7 | Grab and throw, the turn throw, the grapple lock, the blur exchange | 16 pieces, 2 set pieces | about 35 | 2 h | fight lanes and ground contact; the pin |
| 8 | The rest of the kit | 5 specials, 5 signatures, 10 showcases | about 150 | 7 to 9 h | his forms |
| 9 | Taunts, On the Chin, the last stand | 4, 1, 1 | 16 | 1 h | his Pride meter |
| 10 | Finisher shapes and the form cinematics | 3 and 5 | about 70 | 4 h | his forms; Legal's review of the first cinematic |

**Orb's review, honestly: about 30 to 36 hours** for the whole rich M0. That is 21 to 27 hours of poses, about 4 of reels (about 155 of them) and about 5 of play checks, half an hour a wave. Lean was costed at about 24. The first two waves, 4 to 6 hours, already show the strings, the entries and the broken-limb behaviour.

**Director usage** is Animation's to state. At its rate of 3 to 6 thousand tokens a pose with rework, 440 to 570 poses is about 2 to 5 million tokens, spread over many usage windows (ADR 0005). Waves 1 to 5 are about a quarter of it.

**What can slip without hurting the claim.** Wave 8 is the largest and the least needed for "he does not repeat": the strings, entries, throws and clashes carry that. If review time is short, wave 8 can land in halves.

## 12. Constraints

**Legal's stacking rule** (`rule-of-cool.md` section 1, rule 9: no moment shows more than two of the seven marks). His default posture is a crouch, which is mark 1 only with fists clenched at the sides. So:
- his crouch keeps the hands open and forward, or one hand to the ground, in every piece;
- no piece combines a crouch, a shout and an aura: the charge, the taunts, the last stand and the form cinematics each show at most two marks, and the shouted move name counts as one;
- the aura is a thin outline or rings in his lane colour, only while charging or attacking.

**Per-feature constraints** (`rule-of-cool.md` section 3b) are carried in sections 6 to 9: no named technique or borrowed hand pose in the beam answers; no cracked sky in the fist clash; readable bodies in the blur exchange (every blow is a drawn contact pose held at least 4 ticks, no freeze on locked fists, no cut to an onlooker); no beckoning fingers.

**Originality.** Strike names are plain descriptions. Specials, signatures, showcases and finishers carry working labels until Narrative names them and Legal screens them. The split on the spine plates, the tail pieces and the tucked-arm showcase are ours; each authored pose keeps Animation's `_orig` line.

**Data shapes after 2b.** Nothing here changes a live file.
- A piece lists the strike classes it can fill. They are 2b's classes (opener, heavy, ender, blast, mid), plus **one new class, `return`**, for the ping-pong's return blow. Template beats keep `o.class`. At M0 a strike beat names a slot and the composer fills it from the pool.
- Times use 2b's tick form and `tempo` names. New names when each set piece is built: the pulse spacing per clash, `grabReach` 10, `grabHold` 8, `turnHold` 2 (the turn reuses `stepAround` 8), `intercept` 30 and 24, `returnAnticipation` 6, `tauntExposure` 60, `chinEnter` 12.
- Sides: the turn throw is the planner's cross, marked on the launch event. The `dodge` beat stays the only cross in the data.
- New beat ops for Encounter, one per set piece: `pulse`, `hold`, `throw`, `answer`, `meter`, `stance`.
- The moveset file has no schema yet. Tools writes `combat-moveset` at M0, with the checks in section 13.

## 13. What others need from this

| Team | Needs |
| :--- | :--- |
| **Encounter** | the limb filter in the composer's choice; the alternate-limb rule under a break; the new ops; the clash score as readable state; the `return` class |
| **Simulation** | the broken limb's side in the wounds state, hashed |
| **Animation** | section 10's asks; confirm the pose estimates; effectors and sockets |
| **VFX** | 7 emission shapes in his style; the parted and the deflected beam; the shard crown |
| **Game Design** | All ruled in `moveset-rules.md` section 11: a revealed signature outranks the forms below it; the `return` class; the pulse spacing and the tie rule; the turn throw's gates, at no ki cost. The questions were: (1) with Regalia and Sovereign getting their own signatures, does his revealed signature still outrank them once revealed? Today a form-tied signature always wins, which would hide it below Apex. (2) The `return` class's window. (3) The turn throw's gates and cost (`launch-vectors.md` section 5) |
| **Tools** | the `combat-moveset` schema; checks: every row of section 2's table meets the minimums; each direction keeps an entry and two throws after a break; a static count of valid series |
| **QA** | no blow uses a broken limb (a hard test); no key strike twice in a string; series repeats under 10% in forced broken-limb matches; showcase plays per match |
| **Narrative** | names for 8 specials, 8 signatures, 3 finishers; the taunt and last-stand lines; the On the Chin line |
| **Legal** | a screen of the lists in the parked file; the stacking review of the charge, the taunts and the last stand |
| **Art** | whether the tail stays. If not, the "own limb" slot needs its replacement before wave 1 |
