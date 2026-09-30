# Clip list: atoms to key sets

Owner: Animation. Status: design plus the A1 runtime, 2026-09-30. Supersedes the wave-1 brief's per-atom clip list (EP ruling: `pose-pipeline.md` replaces the clip-per-atom idea; a clip becomes a **key set** of two to five poses that the in-betweener plays between). **Every timing here is provisional until Combat's move grammar and moveset system settle it**; the atoms' own timings are Combat's (`docs/combat/move-grammar.md`, canonical) and animation never changes them.

**Sources.** `move-grammar.md` (atom names and beats, cited to `prototype/index.html` at 7233c96), `moveset-system.md` (piece types), `exchange-templates.md`, `data-fields.md`, `pose-pipeline.md` (the plan and §9.1, what A1 runs), `data/anim/` (the poses that exist).

**Units.** Seconds and 60 Hz frames (ticks); one frame is 0.0167 s. "Load" is the anticipation (the wind-up seen), "contact" the frame the blow lands, "recovery" the return. Load and recovery lengths are the timing profile's (`data/anim/profiles.json`): snappy 10 ticks (light) and 16 (heavy) of load, 2 ticks of snap, 5 of follow-through and 8 of recovery; fluid 14 and 22, 6, 9 and 14. They fit inside the gap the sim leaves before the next beat, and a shorter gap shortens the load, never the contact.

**How to read the "beats" columns.** The prototype fixes when the sim acts (`beat t`). Animation fits its clip to that time: contact on the beat, load before it, recovery after it. A blank beat means the sim does nothing then and animation owns the time.

---

## 1. One row per atom

Atom names are the prototype's (`move-grammar.md` §2). "Key set" names are the ones in `data/anim/` (A1) or planned. Status: **A1** built and running, **stand-in** a placeholder pose reused, **planned** not yet authored.

| Atom | Sim beat (seconds, ticks), cited | Load / contact / recovery (animation) | Key set or poses | Status |
| :--- | :--- | :--- | :--- | :--- |
| `rush` (gap close) | starts at beat 0, lasts `rt = clamp(dist/2600, 0.18, 0.65)`, 11 to 39 ticks, 58 u standoff (`index.html:420, 423`) | Load: launch-off, first `min(4 ticks, 25%)`. Flight: the middle. Arrival: last 25%, brace, on the arrival tick | `approach.launch`, `move.dash`, brace = the next strike's chamber | **A1** |
| `rush.far` (pursuit) | 260 u offset, `0.8 rt` (`index.html:444`) | As `rush`, ending open-handed (no brace) | `move.dash` plus `cue.pursue` | A1 (stand-in for the tail) |
| `rush.chain` | 60 u, 0.24 s = 14 ticks (`index.html:553`) | Launch-off 3 ticks, flight, arrival on the strike | as `rush` | A1 |
| `rush.rise` (beam charge rise) | to `min(2400, D.y + rise)`, 0.55 s = 33 ticks (`index.html:595`) | Rise with the charge pose growing | `beam.charge` (weight 0 to 1 over 0.35 of the charge) | A1 |
| `windup` | `rt - 0.1` = 6 ticks before contact (`index.html:497`); `rt - 0.12` in the dodge templates | This is the tell: the chamber pose, at full read by the window's opening | the strike's chamber key | A1 |
| `strike` (light or heavy) | on its beat `t` (`index.html:521`); templates put them at `t`, `t+0.16/0.32` (PRESSURE), `t+0.2/0.42` (GUARD BREAK), `t+0.17/0.34/0.51/0.72` (TRADE BLOWS), `t+0.28` (HEAVY CLASH) | Load to the chamber, snap (2 to 6 ticks) to the contact key, hold through hit-stop, follow-through with overshoot, recover | `strike.jab`, `strike.cross`, `strike.hook`, `strike.upper`, `strike.kick`, `strike.round` (chamber, contact, follow) | **A1** (6 of the planned 24) |
| `block` | no atom: the DEFENSIVE stance's 0.38 multiplier, 0.8 speed (`index.html:326, 771`) | Stand-in beat: the guard held from the stance, and Combat's `guard_set` cue | `stance.defensive`, `cue.guard_set`, guard-hit reaction | A1 (guard hit: planned) |
| `guard.drain` (guard break) | `rt + 0.4` (`index.html:485`), the finishing strike at `+0.42` | Guard visibly gives way: arms fly apart on the break strike | `react.arms` (additive) plus a stagger; a dedicated `guard.break` key set | stand-in; planned |
| `parry` | on the defender's press inside the window, at the first parryable strike (`index.html:525`), 0.12 s freeze | Defender: deflect pose on the beat. Attacker: recoil, the exchange's remaining parts drop | deflect pose (planned); the attacker uses `react.flinch_f` | stand-in; planned |
| `dodge.warp` | at `rt`: the defender teleports to `A.x - face*74` (`index.html:462`) | Vanish and reappear behind: no in-between; afterimage (VFX). The arrival pose is a crouch turning back | `cue.turn_read` as the arrival pose | stand-in; planned (`blink_out`, `blink_in`) |
| `slip` (escape) | at `0.55 rt` (`index.html:445`) | A burst away: coil then stream | `approach.launch` to `move.dash` reversed | stand-in |
| `counter` (defender strikes) | strike beats by the defender, `rt+0.24`, `+0.55`, `+0.72`, `+0.28` (`move-grammar.md` §2.3) | Same as `strike`, thrown by the defender; the attacker reacts | the same key sets; the layer picks by the beat's role | **A1** |
| `launch` | `0.04 to 0.05 s` after contact (`index.html:377`); force 800 to 2600 times `(1 + 0.16 (tier - 1))`; spin `R(8,16)` rad/s | The struck body leaves: flight pose by vector and speed. The striker's follow-through sells the send-off | `launch.spread`, `launch.stream`, `launch.tuck`; follow keys | **A1** (5 vector-specific sets planned, `warping-rules.md` §3) |
| `flight` | gravity 1,000 u/s², drag to 55%/s (`index.html:720`) | Pose blended by speed; limbs trail; spin is the sim's `rot`, not animation's | as above | A1 |
| `water-catch` | slower than 200 u/s and 0.3 s in the water, the fighter is freed (`index.html:726`) | Submerged: limbs lag more, no overshoot; breach on exit | planned (situation layer: water) | planned |
| `wall-hit` (building) | speed × (0.55 + 0.25 tier) building damage, 60% and 85% velocity kept (`index.html:736`) | Embed: limbs splayed to the surface normal, held until `recover` | `embedded` family, wall layer | planned |
| `impact` | on ground contact, above 350 u/s (`index.html:704`); shake, dust, crater | Crumple or slide brake; the hold is the sim's hit-stop 0.06 s | `slide.brake` (A1), crumple, embed | A1 (slide); planned |
| `bounce` | above 700 u/s, up to two (`index.html:716`) | Compress and extend pulse per bounce | planned | planned |
| `down`, `recover` | lies 0.75 s, then `free` (`index.html:788`) | Prone, then get up over the last 0.3 s | `down.prone`, `down.getup` | **A1** |
| `ko-launch` | on KO, `game.ts` 0.35 for 2.2 s, launch at 1,800 (`index.html:339`) | Loser: launch pose at slow motion (dt 0.35). Winner: a held final pose | launch poses; a finisher key set | A1 (launch); planned |
| `chain-window` | opens on a WIN beat, 0.6 s (`index.html:544`) | The attacker holds the follow-through with a moving hold (no dead air) | follow key plus drift | A1 |
| `chain-link` | rush 0.24 s, strike at `+0.26`, launch at `+0.30`, new window at `+0.55` (`index.html:553`) | A short approach, one strike (heavy weight), catch pose | strike key sets with `o.big` weight, `cue.catch` | A1 |
| `clash.shockwave` | at `rt + 0.28`, both pushed at 900 u/s (`index.html:506`) | Both fighters meet at the contact key and are thrown apart | strike contact keys, then `react.flinch_f` | A1 (stand-in) |
| `clash.beam` | 1.6 s struggle, winner's beam after (`index.html:623`) | Both hold the beam pose braced, leaning into it; the loser's pose fails toward the end | `beam.fire` held, a brace variant | stand-in; planned |
| `beam.charge` | 0.8 s, orb grows (`index.html:593`) | Charge pose weight up over 0.35 of it, then held with a tremble | `beam.charge` (original: fist along the shoulder line, rear forearm under the elbow, RL-038) | **A1** |
| `beam.fire` | at 0.8 s, sweeps its length in 0.22 s, life 0.95 s (`index.html:598, 660`) | Full extension on the fire beat, hold to 0.55 of the beam's life, relax | `beam.fire` | **A1** |
| `beam.connect`, `beam.dodge`, `beam.escape` | at `0.8 + reach`, `0.82`, `0.82` | Defender: hit reaction (beam kind), a hop and hang (dodge), a burst (escape). Attacker holds `beam.fire` | reaction poses; dodge and escape stand-ins | stand-in |
| `explode` | hit-stop 0.08 s | The struck body's reaction | as `beam.connect` | stand-in |
| `charge` (holding) | velocity 0.85 per frame, +30 ki/s (`index.html:780`) | Crouch, fist to the breastbone, tremble | `charge.hold` (original, RL-038) | **A1** |
| `tier-up` | at 25, 50, 75 power (`index.html:692`) | A burst pose and a rise; the ground crater is the sim's | planned (a power-up beat) | planned |
| `hide` | removed from the base game (EP ruling); the stealth fighter later | none until that fighter | none | none |
| `hitstop` | 0.05 s default, 0.06 to 0.16 s by class (`index.html:334`) | Freeze at the pose, hit-shiver, slow springs (§3 below) | n/a | **A1** |

---

## 2. Combat's piece types (the composed fill)

`moveset-system.md` §1.1 counts the pieces a first fighter needs. Animation's poses for them, against A1:

| Piece type | Combat's launch target | Poses per piece | Poses needed (with sharing and derived chambers) | In `data/anim/` now |
| :--- | ---: | ---: | ---: | ---: |
| Key strike (fist 8, elbow 3, knee 3, foot 6, head 1, shoulder and body 2, own 1) | 24 | 3 (chamber, contact, follow) | about 60 (30 shapes in `pose-pipeline.md`; 24 pieces map to about 45 after sharing) | 18 (6 strikes) |
| Entry (dash, arc dive, rising, skid, circle, lunge, feint step, wall kick-off, water breach, trait) | 10 | 2 (launch-off, arrival) | about 16 | 2 |
| Feint | 4 | 1 (reuses a chamber) | about 4 | 0 |
| Reaction (flinch, stagger, spin-out, fold, crumple, knock-away, embed, bounce, skid, splash, guard shove, guard crack) | 12 | 2 (front, back) | about 20 | 8 (4 poses, 4 additive) |
| Situation layer (air, ground, wall, water; attacking and being hit) | 8 | additive, 1 to 2 | about 8 to 10 additive poses | 0 |
| Follow-up | 6 | 1 to 2 | about 10 | 0 |
| Foundation (stances, flight, guard, down, slide, launch, charge, beam) | not in Combat's list | | about 26 | 24 |
| Cue poses (Combat's 15 cues) | | 1 | 15 | 15 |
| **Basic set** | **64 pieces** | | **about 170** | **57** |

**Reconciling with Combat's total.** Combat estimates 500 to 900 key poses per fighter at launch size: 64 basic pieces, about 40 special pieces, about 40 signature pieces and about 20 showcases, at 3 to 5 poses per piece and 4 to 10 per showcase. `pose-pipeline.md` §3.2 counted the basic set at about 170 poses (sharing and derived chambers) and put only about 100 showcase poses on top. **That understates the specials and signatures.** Combat's 80 special and signature pieces are another 240 to 400 poses (they are showcase-grade poses, authored by directors and reviewed by Orb under ADR 0007), and the 20 showcases another 80 to 200. The honest first-fighter total is **about 500 to 800 poses**, of which about 170 are the shared basic set. The cost is director usage plus Orb's review time, not human authoring hours; `pose-pipeline.md` §6.4 has the scope table (lean, middle, full) and the estimates. This is a scope fact for the EP and Orb, and the lever is the number of specials and signatures, not the tooling.

---

## 3. Hit-pause data

Hit-stop is the sim's (`dirS.stop`, Controls' table, `data/input/feel.json`); animation freezes with it and never changes it. What animation does inside it:

| Impact class | Sim hit-stop (prototype, seconds and ticks) | Animation during the freeze |
| :--- | :--- | :--- |
| Light strike | 0.05 (3 ticks); proposed floor 0.07 (`templates.json`, not adopted) | Hold the contact key; shiver 0.9 u (snappy) or 0.4 u (fluid); springs at 0.1 speed |
| Heavy strike, guard break, heavy clash | 0.12 (7 ticks) | As above; the follow key's overshoot starts on release |
| Chain link | 0.08 (5 ticks) | As light |
| Impact (landing) | 0.06 (4 ticks) | Hold the crumple or brake pose |
| Explosion | 0.08 | Hold the reaction peak |
| Beam connect | 0.14 (8 ticks) | Hold the beam hit reaction |
| Beam clash resolution | 0.16 (10 ticks) | Hold both braced poses |
| Parry | 0.12 (9 to 12 ticks in the data) | Hold deflect and recoil |
| Finisher | proposed floor 0.3 (18 ticks) | Hold the final pose; the impact frame and camera are VFX's and Camera's |
| KO slow motion | dt × 0.35 for 2.2 s | Animation and springs use the tick's dt, so they slow with it |

The shiver is keyed to `S.tick` (which counts frozen ticks), so it is repeatable, and reduced motion turns it off.

---

## 4. Pose data fields

Two parts, because a change to the second is a sim change and re-baselines QA's golden hashes.

**Render-only, never read by the sim** (`data/anim/`, outside the sim's data hash; `data-fields.md` §9's `anim.*` block):

| Field | Meaning |
| :--- | :--- |
| `poses[].fk`, sketch fields (`lean`, `spine`, `head`, `hips`), `hand_r`, `hand_l`, `foot_r`, `foot_l` | The pose (model space, degrees; targets are wrist and ankle joints) |
| `poses[].hands` | Fist, open, claw, relaxed, point |
| `poses[]._orig`, `_note` | The originality line and a note (RL-038) |
| `keysets[].keys[]` (role, pose) | Load, contact, follow |
| `keysets[].weight`, `picks` | Which weight class may pick it |
| `profiles[]` | Snap, load, follow and recovery ticks, ease, overshoot, lag, shiver, solve rate |
| `cues.json` | Cue kind to key pose |
| `anim.keySet`, `anim.contactKey` (in Combat's part record, `render` block) | The reference from a part to its key set (renamed from `anim.clip`; requested of Combat) |
| Sigil deltas, spring settings, socket offsets | Render channels (later slices) |

**Read by the sim (Animation authors none of them; Combat records):**

| Field | Author | Rule |
| :--- | :--- | :--- |
| Part ticks (anticipation, active, recovery, contact), stretch range, reach, band, tags | Combat | I validate against them; if animation cannot meet them I file a Combat request through the EP |
| `poseIn`, `poseOut` family names and the can-follow table | Animation proposes | A change alters what the composer may join: **a sim change** |
| The silhouette-clarity flag on a part | The lint reports, Combat records | Set once and frozen; a change is a sim change |

---

## 5. Timing fit, and requests to Combat

**Clips fit the prototype's beat times unchanged.** Contact lands on the beat; load and recovery live in the gaps. The gaps that are tight in the dynamic profile (contacts every 14 ticks, `dynamic-feel.md`) shorten the load below the profile's nominal (down to the snap plus 2 ticks) and the recovery overlaps the next load. Where a key set cannot fit (a heavy strike's 16-tick load into a 10-tick gap), the fit compresses it and a **request goes to Combat**, not a change to the beat.

| # | Request to Combat (through the EP) | Why |
| :--- | :--- | :--- |
| 1 | Anticipation minimums by weight: I propose 6 ticks visible for a light, 10 for a heavy, 20 for a finisher, and a pose visible at least 4 ticks | The profiles' load lengths are provisional |
| 2 | A `windup` beat (or a `tell` cue) for every attack, including the dodge templates, whose parry window opens at `rt - 0.12` and can never parry (CC-009) | The tell is what the defender reads; a window with no visible motion has nothing to read |
| 3 | Names: `rush` to entry, `strike` to key strike, `counter` to a role flag on `strike`, `launch` and `flight` to launch vector, the situation layers | List any rename so key-set ids follow |
| 4 | The `part` cue with anchor ticks, and a cancel signal | Replaces the beat-reading stand-in |
| 5 | The dodge templates' 0.9 s hang after a dodged signature (CC-005) | It reads as a stall; a pose cannot fix a frozen state |

**Names I expect Combat to rename** (prototype, grammar, moveset): `rush` (entry), `strike` (key strike), `block` (none, guard from stance), `counter` (a strike by the defender), `chase` (pursuit, follow-up), `slam` (a launch vector, SLAM DOWN), `beam` and `clash` (signature layers), `KO` (finisher).

---

## 6. Five open questions

| Question | Owner |
| :--- | :--- |
| Is the scope of about 500 to 800 poses per fighter (§2) what Orb wants, or should specials and signatures shrink first? | Orb |
| How does Orb want to review showcase-grade poses (contact-sheet batches, motion reels per part)? | Orb |
| Do the dodge templates (CC-009) get a real window, so the wind-up read matters? | Combat |
| Are 6 ticks (light) and 10 ticks (heavy) the minimum visible anticipation? | Combat, Controls |
| Does a dodged or guarded signature get its own aftermath beat (CC-005) so the pose has something to play? | Combat, Game Design |
