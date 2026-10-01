# Moveset system

Owner: Combat and Choreography. Implementation: Encounter Systems (the composer), Animation and Rendering (poses and in-betweens), Tools (schemas). Numbers: Game Design. Date: 2026-09-30. Status: plan, system first, content after (Orb, questionnaire 6). Section 9 revises the grammar for the control scheme in ADR 0008: physical and energy modes, direction-shaped entries, context actions, and the revised counts. **The first real fighter's moveset is now planned at the rich end in `m0-rich.md`** (Orb, 2026-10-01): its counts replace sections 6 and 9.6 for the Anti-hero, and its pose costs follow Animation's overhaul.

**Orb's ask** (`docs/ep/vision.md`, questionnaire 6), per fighter:
- hundreds to thousands of basic attacks, dozens to hundreds of specials, and dozens of signatures;
- built as a **hybrid**: hand-made showcase moves on top of a composed fill made from a smaller set of hand-made pieces;
- basic attacks differ by **limb**, **situation** (air, ground, wall, water), **impact and reaction**, and **rhythm and speed**;
- **recognisability 3 of 10**: exchanges mostly look new;
- style **shifts mid-match** with mood, injury and form;
- **animation:** hand-made key poses with procedural in-betweens.

**What this plan builds on.** It is the concrete version of `procedural-moves.md`, adding the counts, the specials, the signatures and the milestones. It fits the layers already in the data:
- templates decide outcomes (`templates.json`);
- styles decide the choreography family (`styles.json`, `variety-pass.md`);
- the composer decides the pieces (this document).

The player's control split is unchanged: the player sets intent (stance, weight, specials and transformations), and the director times and composes (R9).

---

## 1. The composition grammar

### 1.1 Piece types (hand-made)
A **piece** is one authored unit: 3 to 5 hand-made **key poses** (anticipation, contact, follow-through, and a recovery or hold), a contact tick, a reach and a set of tags. Rendering fills the in-betweens procedurally, from the key poses and a rhythm curve.

| Piece type | What it is | Hand-made per fighter (launch target) |
| :--- | :--- | ---: |
| **Key strike** | The blow a beat is about, by limb: fist 8 (jab, cross, hook, uppercut, hammer, backfist, palm, spear hand), elbow 3, knee 3, foot 6 (front kick, roundhouse, axe, spinning heel, sweep, stomp), head 1, shoulder and body 2, fighter-own 1 (a tail, a blade arm...) | **24** |
| **Entry** | How the striker gets there: dash, arc dive, rising, skid, circle, lunge, feint step, wall kick-off, water breach, and a fighter trait (blink, portal...) | **10** |
| **Feint** | A lead-in that doesn't land: a shoulder dip, a half kick, a false start, a glance | **4** |
| **Reaction** | The fighter's own reaction when struck: flinch, stagger, spin-out, fold, crumple, knock-away, embed, bounce, skid, splash, guard shove, guard crack | **12** |
| **Situation layer** | An additive posture layer that bends any piece to its situation: air (tuck), ground (planted), wall (braced off a surface), water (dragged, slowed). One layer for attacking and one for being hit | **8** (4 situations × 2) |
| **Follow-up** | What comes after contact: pursue, overtake (relay), pin, taunt pause, disengage, recover | **6** |
| **Rhythm curve** | The timing profile the in-betweens follow: snap, steady, heavy, delayed (hesitation), flurry. Data curves, not animation | 5 (data) |

That is **64 hand-made pieces** per fighter for the basic attacks, plus 5 curves shared by everyone. Many entries, reactions and layers can be shared across fighters of similar build and re-posed per rig.

### 1.2 How the axes combine
A basic attack is a **phrase**: entry, then an optional lead-in (a feint or a light key strike), then the key strike, the contact, the reaction and the follow-up. All of it is set in a situation and played at a rhythm. The four axes Orb named map one to one:

| Orb's axis | The grammar's axis |
| :--- | :--- |
| limb or body part | key strike (24, by limb family) |
| situation (air, ground, wall, water) | situation layer, plus the situation gates on each piece |
| impact and reaction | impact class (light, heavy, crushing, from the weight and the template) × the defender's reaction (12) |
| rhythm and speed | rhythm curve (5), plus the stretch range of each piece |

**Joins.** Each piece has an in-state and an out-state (pose family, height, facing, momentum). Two pieces join only when they match. That is what keeps a composed phrase flowing like a choreographed one (`procedural-moves.md` section 2.2).

### 1.3 The count, with the arithmetic
We count **distinct attacks as distinct fingerprints**: what a viewer can tell apart without reading the feed. The fingerprint is the entry, the lead-in, the key strike, the situation and the rhythm. Reactions are counted separately, because they belong to the fighter being hit.

1. **Raw combinations:** 10 entries × 24 key strikes × 4 situations × 5 rhythms = **4,800**.
2. **Valid combinations.** A sweep needs ground; a stomp needs a surface or a downed target; wall pieces need a wall; water slows the snap rhythm; some joins fail. We estimate about 45% survive: 4,800 × 0.45 ≈ **2,160 distinct basic attacks**.
3. **With lead-ins:** none, feint or a light lead strike (3 classes) ≈ **6,500 distinct basic phrases**.
4. **As seen, with the reaction.** Each phrase lands with about 3 plausible reactions for its impact class ≈ 19,000 phrase-and-reaction pairs.

So **64 hand-made pieces give roughly 2,000 to 6,500 distinct basic attacks per fighter**, inside Orb's "hundreds to thousands". The 45% validity factor is the one number to measure: QA reports the true valid count from the data (Tools can enumerate it statically).

**Growth is additive.** One more key strike adds about 90 valid attacks (10 × 4 × 5 × 0.45); one more entry adds about 216. That is why the fill grows cheaply after launch.

---

## 2. Showcase moves on top

A **showcase move** is a complete, hand-made move: a whole phrase, or a short multi-beat sequence of 4 to 10 key poses, authored as one piece of choreography. It is the fighter's trademark look.
- **How many:** about 20 per fighter at launch, growing to 40 to 60.
- **How they are used.** They are phrase candidates, just larger ones. The composer considers a showcase when its gates pass (template branch, situation, weight, form and mood), and fits it to the template's anchor ticks like any phrase.
- **How often:** at most **12% of exchanges**, with a per-showcase cooldown (not the same showcase twice within about 2 minutes), and never twice in a row. Recognisability 3 of 10 means the showcases plus the fighter's favourite pieces make up about 30% of what you see (section 4).
- **Where they matter most:** chain enders, decisive blows, the moments after a transformation, and the first exchange of a new act. That is where a trademark move reads as a payoff, not a repeat.

---

## 3. Specials and signatures

### 3.1 Terms (Game Design's `docs/design/moveset-rules.md`)
- **Fighter mechanics** (stoke, Press, Drop the Act, the fold, the Encore) keep their own inputs and prompts. They are Game Design's, and are not in this document.
- **Specials** are the flashy attacks between basics and signatures: energy blasts, advanced footwork, and anything unique to a fighter. The player queues them; the director times them and picks their variant.

### 3.2 Special moves: a loadout of a few, each with contextual variants
- **Library.** About **10 special skeletons** per fighter. Each is a hand-made skeleton of 3 to 5 pieces fixing the move's identity (its silhouette moment, anchors, cost and trigger), for about 40 pieces.
- **Loadout** (Game Design's rule). **3 specials**, chosen from the fighter's pool at character select, with a default loadout in the fighter's data. The player queues one by holding **Special** plus a direction for the slot, and the director fires it at the next opening, within 180 ticks. Cost 15 to 30 ki by power class; cooldown 25 s.
- **A fourth special from a secret.** When the Empress's hidden weapon or the Anti-hero's secret technique is revealed (a beat of about 1.5 s, with a line), it joins that fighter's loadout as a fourth special for the rest of the match. Only those two fighters have secrets.
- **Forms change the variants, not the loadout.** Form is one of the variant keys below, so a transformation still visibly changes how each special plays.
- **Variants.** Each skeleton varies by layers, as the signature beam does (`signature-variants.md` section 5): situation (4) × range (close, mid, far: 3) × form stage (about 2 on average) = 24 potential variants. About half are valid, so **about 12 per special**, and about **120 distinct special plays per fighter** across the library. That is inside "dozens to hundreds".
- **Use.** The player picks *which* special (the slot); the director picks *when* (the next opening) and *which variant*. The variant comes from context: biome and surface, altitude, distance, the opponent's stance and injuries, and the fighter's form and mood. This uses the same selector grammar as `styles.json`, and the player never picks a variant. Game Design's bands: 8 to 16 specials fired per fighter per match, and no single special above 50% of a fighter's specials.

### 3.3 Signatures: dozens per fighter, chosen three ways
Signatures are the flashiest moves: energy attacks, hidden weapons, secret abilities, ancient knowledge and world-changing abilities.

| How it is chosen | What it means | Per fighter (launch target) |
| :--- | :--- | ---: |
| **By place** | Each signature is a layered move (approach, path, material, outcome, follow-up). Biome material, altitude band and stance pick its variant (`signature-variants.md` section 5) | 6 skeletons, each with about 6 distinct place variants in reach |
| **Revealed mid-fight** | Hidden signatures unlock once, at a story moment: the first act change, the brink, a rival's taunt landing, or a region break on a special opponent. The reveal is a set piece and a Narrative line, then the signature joins the rotation | 2 |
| **Tied to form** | Each transformation stage adds or replaces a signature (form deltas). The top form has its own | about 1 per form (4 to 6) |
| **World-changing** | Reshape the land, change the sky, move water, alter the planet. Permanent for the rest of the match, **at most once per match**, gated by act 3 or more and a form or story trigger (Game Design). World builds the permanent state | 1 (some fighters) |
| **Hidden weapons and secret abilities** | Only fighters with the trait have them. They ride the same layers | by trait |

That is about 11 to 15 signature skeletons per fighter, each playing about 6 ways by place: **about 60 to 90 distinct signature plays**, which is "dozens". The layer tables (material, band, outcome, personality and tier rows, about two dozen) are shared by every signature.

---

## 4. Freshness without randomness: identity rules

Recognisability 3 of 10 means mostly fresh, but still unmistakably *this* fighter. These rules keep composition from looking random.

1. **Two-level choice** (`procedural-moves.md` section 3).
   - The situation and the template pick the **class** of each slot, for example "an overhead heavy on a grounded target".
   - Novelty picks the **realisation**: which kick, which entry, which rhythm.
   - The same situation reads the same way; the same fighter never looks canned.
2. **An identity core, about 30% of what you see.** Each fighter has favourite pieces: 6 key strikes, 3 entries and 1 rhythm curve, weighted ×2 in their slots. Together with showcases (at most 12% of exchanges), that holds recognisability near 3 of 10. The rest, about 70%, is fresh fill.
3. **Coherence inside a phrase.**
   - At most 2 limb-family changes per phrase.
   - One rhythm curve per phrase.
   - Joins must match.
   - A fighter never switches style mid-phrase: style changes land between exchanges.
4. **Style drift** (Orb: style shifts with mood, injury and form) moves the weights, never the grammar:
   - **Mood** (Calm, Tense, Frenzied): Calm favours steady rhythms and clean entries; Tense favours pressure lead-ins and feints; Frenzied favours flurry rhythms, blinks and blitz chains.
   - **Injury** (Wounds regions): a battered or broken arm shifts weight to kicks and knees; hurt legs shift weight to hand strikes, aerial entries and slower rhythms. Hurt fighters use heavier reaction classes. The fighter's own injuries show in how they attack.
   - **Form:** form deltas add, remove and reweight pieces and swap specials, so each transformation stage visibly changes how the fighter moves.
5. **Variety memory** (`procedural-moves.md` section 6), which is part of the sim state:
   - penalties for repeating recent fingerprints;
   - hard blocks on the same key strike three times running and on repeating any three-phrase series;
   - showcase cooldowns.
6. **Tests.** QA runs T1 to T8 from `procedural-moves.md` section 13, plus:
   - **identity:** a classifier tells the fighters apart from fingerprints at 90% or better;
   - **recognisability:** the share of exchanges containing a showcase or an identity-core piece is 25 to 35%;
   - **drift:** the fingerprint distribution shifts measurably between Calm and Frenzied, and between healthy and injured, in forced scenarios;
   - **Game Design's bands** (`moveset-rules.md`): the same three-piece sequence repeats in under 10% of exchanges, and in a blind review 70% of reviewers can tell a Calm stretch of a fighter from a Frenzied one.

---

## 5. Data shapes and determinism

**Files.** Proposed; Tools owns the schemas and names.

| File | Holds |
| :--- | :--- |
| `data/combat/pieces/common/*.json` | shared pieces: entries, reactions and situation layers usable by any rig |
| `data/fighters/<id>/pieces/*.json` | the fighter's own pieces |
| `data/fighters/<id>/moveset.json` | the fighter's vocabulary: which pieces, their weights, the identity core, drift rules (mood, injury, form), the special pool and default loadout of 3 (plus the secret's fourth, where the fighter has one), the signature list (place, revealed and form), showcase references and traits |
| `data/fighters/<id>/showcases/*.json` | the showcase moves |
| `data/combat/phrases.json` | phrase classes: slots, rules and joins |
| `data/combat/composer.json` | scoring weights, the freshness and memory settings, showcase rate and cooldowns, rhythm curves |

**A piece has two blocks:**
- **`sim`** (read by the simulation): ticks (anticipation, contact, recovery), stretch range, reach, band and situation gates, in-state and out-state, tags (limb, weight, style, the location hint for Wounds), cost.
- **`render`** (never read by the simulation): key poses, the contact frame, cue sets.

This follows `data-fields.md` section 9.

**Determinism:**
- **Keyed draws (D1a).** Every composition choice is a stateless draw: `SimRng.keyed(seed, "compose/<slot>", ex.n)`, with `ex.combo` folded in for chain links. Showcase and special checks use their own keys. Keyed draws never touch `S.rng`, so adding a piece, a showcase or a whole fighter changes only the choices it takes part in, never another draw.
- **Fixed draw counts.** Each slot makes a fixed number of draws, even when there is only one candidate.
- **Inputs from state only.** Style drift reads sim state (mood value, wound stages, form); render state never feeds it.
- **Memory in the state.** The variety memory (fingerprint ring, part counts, series table, showcase cooldowns) is part of the sim state and the hash, so replays and goldens cover it.
- **Integer ticks.** All timing is in ticks. Stretching a piece to its anchor uses integer arithmetic, so the result is identical on every machine.

**Validation** (Tools, `procedural-moves.md` section 10), which rejects:
- dead-end pieces (no join out);
- anticipation shorter than the weight's minimum;
- a phrase class that cannot be filled in a reachable situation;
- a showcase that cannot fit its template's anchors.

It also enumerates the valid attack count per fighter, the real figure behind section 1.3's estimate.

---

## 6. Milestones: the system first, the first fighter as the proof

| Milestone | Build | Content | Exit |
| :--- | :--- | :--- | :--- |
| **M0. Contract** | Schemas (pieces, phrases, moveset, composer) with the canonical names (section 7.1); the composer skeleton in `sim/director/` calling keyed draws; the part cue and `part_end` events (section 7.4, Simulation); anticipation-minimum validation (section 7.2); the structured event log with fingerprints | none: today's templates as a single fixed "piece" per slot | Bit-identical to the current build on the golden seeds (as S3b was) |
| **M1. The grammar on greybox** | Slots, joins, anchor fitting, rhythm curves, variety memory, the debug feed ("why this piece") | 12 greybox key strikes and 4 entries for the placeholder KAI, as placeholder key poses | A composed phrase in every melee exchange; no dead air (feel targets hold); T4 with no repeated series in 95% of matches |
| **M2. Situations and style drift** | Situation layers and gates (air, ground, wall, water); reactions; mood, injury and form weights; the identity core | greybox: 4 situation layers, 12 reactions, 6 favourites | Forced-context scenarios give distinct fingerprints (T1); the drift test passes; the valid count is enumerated |
| **M3. The hybrid top** | Showcase injection and cooldowns; special skeletons with variant layers and the loadout; signature selection by place, reveal and form; the once-per-match world-changing gate (with World) | 3 greybox showcases, 2 specials and 2 signatures | Showcase share of 12% or less; each selection rule fires in its scenario; the world-changing ability happens at most once |
| **M4. The first fighter (the proof)** | Tuning only | The first real fighter at launch size: 64 basic pieces, about 20 showcases, about 10 special skeletons, about 12 signature skeletons, all with final key poses | Orb plays it. QA: 2,000 or more valid basic attacks enumerated; identity and recognisability tests pass; the feel targets hold |
| **M5. The second fighter, as data only** | none | The second fighter's data and poses | No code change (the modding proof); the two fighters are told apart at 90% |

**The honest cost is key poses, not code.** At launch size one fighter needs about 144 authored pieces plus about 20 showcases:
- 64 basic pieces;
- about 40 special pieces;
- about 40 signature pieces;
- about 20 showcases.

At 3 to 5 key poses per piece, and 4 to 10 per showcase, that is **roughly 500 to 900 key poses per fighter**. The system makes each pose go far, since the fill multiplies it by the grammar, but Animation and Art must plan the pose pipeline around that number. Orb allows AI-generated assets (questionnaire 1), which is Art's decision under Legal's AI policy.

---

## 7. The M0 contract (Animation's requests, `docs/animation/clip-list.md` section 5)

### 7.1 Names (the canonical vocabulary from M0 on)
`move-grammar.md` is the canonical source for names. From M0, the piece schema, the part cue and Animation's key-set ids use the names on the right. Today's op names in `templates.json` and the code stay as they are until the M0 schema replaces them.

| Today (op or prototype term) | From M0 |
| :--- | :--- |
| `rush`, `finRush` | **entry** (a pursuit is an entry after a launch) |
| `strike` | **key strike** |
| `counter` | a **role** flag on a key strike: `attack`, `counter` or `parry` |
| `launch`, flight | **launch vector** (SLAM DOWN and the rest are launch-vector classes) |
| block | none: **guard** is a stance multiplier, shown by guard reactions |
| chase | **follow-up** (pursue, relay, pin) |
| slam | the SLAM DOWN **launch vector**, or the ground-slam reaction |
| beam, clash | **signature layers** (approach, path, material, outcome, follow-up) |
| KO | **finisher** |
| air, ground, wall, water postures | **situation layers** |

### 7.2 Anticipation minimums (agreed with Animation; Game Design's readability view)
Every key strike shows a visible anticipation: the pose run from the striker's last contact, or the entry, to the contact tick. Its minimum is:

| Weight | Anticipation (ticks) | Notes |
| :--- | ---: | :--- |
| light | **6** | fits the dynamic profile's 14-tick contact spacing; the recovery overlaps the next load |
| heavy | **10** | HEAVY CLASH's 20-tick lunge and GUARD BREAK's finishing strike (23 ticks after the last contact) already exceed it |
| finisher (final blow) | **20** | the authored finishers give 30 to 36 ticks after `last_look` |
| any pose | at least **4 ticks on screen** | no pose flashes by |

- **Separate from the parry window.** Controls' parry windows (15 light, 20 heavy) are gameplay; these minimums are what the eye needs. A window is never shorter than the anticipation it contains. Under ADR 0008, strikes that can be perfect-blocked need the longer wind-ups in section 9.7; these minimums remain the floor for the rest.
- **Guaranteed by the composer.** Anchor fitting never compresses a piece below its weight's minimum. A piece that cannot fit is not a candidate.
- **Checked by Tools.** Validation flags any authored beat list, and any fitted part, below the minimum.
- **Readability targets.** These numbers are the readability floor Game Design's section 10 readability target (a readable wind-up) asks for; Game Design confirms them.

### 7.3 A tell for every attack (CC-009)
- **The weight tell.** Every exchange shows the attacker's weight (`tell_light` or `tell_heavy`) through the approach, driven by the `attack` event (`variety-pass.md` section 4).
- **The anticipation.** Every key strike, including the attacker's whiffed strike in the DODGE templates, gets its anticipation pose (7.2) through the part cue.
- **The DODGE templates get a tell, not a window.** Under R5 an EVASIVE defender never parries (0%): it dodges. The dead wind-up beat stays dropped (CC-009, closed that way in the dynamic profile). The defender reads the attacker's tell and blinks, and that is what the viewer sees.
- **Signatures and finishers** already telegraph: the charge orb, and `finisher_tell_<kind>`.

### 7.4 The part cue (Simulation lands the event with M0)
One render-only fx event per composed part, emitted when the exchange schedules it. Render and Animation play the key set against it. It replaces the beat-reading stand-in.

| Field | Meaning |
| :--- | :--- |
| `actor` | the fighter performing the part |
| `part` | the piece id (for example `strike.axe_kick`) |
| `keyset` | Animation's key-set id for this fighter and piece (the rig's version of it) |
| `start`, `contact`, `end` | absolute sim ticks; `contact` is -1 for a part with no contact (an entry, a feint) |
| `stretch` | the fit ratio in per-mille (an integer, so replays stay bit-identical); 1000 is the authored length |
| `slot` | entry, lead, key strike, reaction, evade, guard, launch vector, follow-up, showcase, special, signature layer |
| `target` | the other fighter |
| `region` | the Wounds region hint for a key strike (head, core, arms, legs; the Empress's mantle) |
| `side` | left or right, relative to the actor's facing (which limb) |
| `weight` | light, heavy, crushing or finisher |
| `role` | attack, counter or parry |
| `n` | the exchange index (D1a), so parts can be grouped per exchange |

**`part_end`** `{actor, part, tick, reason}` fires when a part ends, with `reason` one of:
- `done`: it played out;
- `cancel`: a parry, a break chapter, a finisher taking over, or a KO dropped it.

A cancelled part's key set blends out from its current pose, never snaps.

### 7.5 Closed or answered
- **CC-005, the beam-dodge hang:** closed in `da5fb09`. The dodger is freed at the dodge and drifts up and away (`beam.gd` `opBeamDodge`, no draw), so the evade pose plays over motion. From M0 the dodge is an `evade` part in the part cue.
- **Animation's open questions for Combat:**
  - the DODGE templates get a tell, not a window (7.3);
  - the anticipation minimums are 6, 10 and 20 ticks (7.2; Controls and Game Design confirm);
  - a dodged or guarded signature's aftermath is the drift (dodge) or the guard reaction and launch (guard), both now in motion.

## 8. What each team needs

| Team | Needs |
| :--- | :--- |
| **Animation** | A key-pose authoring pipeline per piece: 3 to 5 poses, the contact frame, in-states and out-states as pose families. The per-fighter budget above (roughly 500 to 900 key poses at launch; greybox placeholders first). The situation layers as additive poses. The showcase format (4 to 10 poses) |
| **Rendering** | The procedural in-between runtime: blend key poses along a rhythm curve, stretch to the sim's ticks, and apply situation layers additively. Cue consumers (already planned). A readable hit pose on the contact tick every time |
| **Encounter** | The composer in `sim/director/`: slot filling with keyed draws, joins, anchor fitting, the variety memory in state, and style drift from mood, wounds and form. Showcase injection. The special queue (3 slots, plus the secret's fourth) with variant selection. Signature selection (place, reveal, form) and the world-changing gate. The fingerprint event log. A performance budget (composition at exchange start only) |
| **Game Design** | Numbers: scoring weights, the identity-core weight, the showcase rate and cooldowns, special costs and cooldowns (ruled: 15 to 30 ki, 25 s; loadout 3, picked at character select), signature gates and costs, and the world-changing ability's trigger, cost and rules. The injury-drift mapping. The identity and recognisability targets |
| **Tools** | Schemas for pieces, phrases, moveset, showcases and composer. The join, fit and coverage validation. A static enumerator of valid attacks per fighter |
| **World** | Permanent world-changing states (reshaped land, changed sky, moved water), once per match |
| **Narrative** | Names only for what shows on screen (showcases if named, specials, signatures and finishers, per questionnaire 4). Story-moment hooks for revealed signatures |
| **Legal** | Screening for special and signature concepts (hidden weapons, ancient knowledge), and the showcase silhouettes (the originality checklist) |
| **QA** | The fingerprint metrics (T1 to T8), the identity classifier, and the recognisability and drift tests |

---

## 9. The control scheme (ADR 0008): what changes in the grammar

Plan only; no data changes until Orb gives the go. ADR 0008 (`docs/decisions/0008-control-scheme.md`) makes inputs into modifiers:
- the **mode** (physical or energy) swaps the piece family;
- the **direction** held (toward, neutral, away) swaps the entry;
- the **button** sets the weight;
- the defender's **held state** (Press, Guard, Dodge, Escape) picks the outcome.

The grammar already has those axes. This section adds the families and revises the counts.

### 9.1 Two piece families: physical and energy
- **Physical** is the family in section 1: 24 key strikes by limb.
- **Energy reuses the body.** An energy strike is a body pose the fighter already has, plus a **hand variant** and an **emission shape**. Animation authors hands; VFX authors the emissions in the fighter's own energy style.

| Energy piece | What it is | Hand-made per fighter |
| :--- | :--- | ---: |
| Emitter pose | a key-strike body pose reused for energy: palm thrust, backhand sweep, overhead chop, low scoop, blade thrust, knee burst, kick arc and others | 0 new: 12 of the 24 poses are flagged as emitters |
| Hand variant | open palm, pinch (thumb to forefinger), clawed palm, crossed forearms, fist glow, flat blade hand. Legal: no pointing finger or two-finger point as an energy hand, and a double palm never emits (`docs/legal/rule-of-cool-screen.md`) | 6 |
| Energy-only pose | charged-shot brace, channel pose, shove, kiting turn | 4 |
| Emission shape | bolt, volley, arc slash, burst, lobbed orb, charged shot (VFX, in the fighter's style and colour) | 6 (VFX) |

- **Energy strikes:** 12 emitter poses × 6 emission shapes = 72 pairs. About half make sense (a knee burst does not lob an orb), so **about 36 energy strikes**.
- **Mixups.** A phrase may lead in one mode and land in the other: a blast into a rush, a feint into a point-blank burst, a scatter and then one heavy shot. The lead-in classes go from 3 to 4: none, feint, same-mode lead, other-mode lead.
- **Ordinary blasts carry ranged play.** Energy basics are the "more ordinary energy blasts" Orb asked for: light is a bolt or volley; heavy is a charged shot, arc slash or burst. Signature beams become rarer (9.4).

### 9.2 Direction-shaped entries
The entry axis is now chosen by the player's held direction. The same body entries serve both modes, with the energy hands and emissions on top.

| Direction | Entry class | Physical | Energy | Hand-made entries |
| :--- | :--- | :--- | :--- | ---: |
| toward | **rush** | close the gap and strike: dash, arc dive, skid, circle, the fighter's trait (blink, portal) | advancing fire: blasts while closing, a point-blank burst on arrival | 5 |
| neutral | **stand** | plant and strike: a step-in, a pivot, a sidestep in place | turret: planted volleys and charged shots | 3 |
| away | **retreat** | a **backstep counter**: give ground, and strike as the opponent follows | **kiting blasts**: fire while backing away | 3 |

That is 11 body entries, where section 1 had 10.

**Pillar 3 is unchanged for the two ranged cases:** energy reaches at any range, and a rush always closes.

**Open for Game Design and Encounter:** a physical *stand* or *retreat* against an opponent who is out of reach. Combat's recommendation:
- stand takes a short closing step (the minimum approach), so a physical press never whiffs for range;
- retreat is a counter stance that needs no reach: it pays off only if the opponent comes.

### 9.3 Context actions: a small set per fighter
The context button's actions are short authored phrases (one or two pieces each), with situation variants like any other piece. The on-screen icon comes from the same priority rule the sim uses.

| Action | When (ADR 0008 priority and modifiers) | Pieces | What it is for |
| :--- | :--- | :--- | :--- |
| **Grab and throw** | the opponent within grab range | grab; 2 throw poses (the throw reuses launch vectors) | beats a held Guard; loses to a strike in progress; misses a Dodge |
| **Pick-up** | a liftable object in reach (boulder, tree, wreckage) | lift; swing or hurl | arms the next attack: an object swing or throw, with World's liftables |
| **Civilians action** | civilians in reach | 1 or 2, the fighter's own | the fighter's personality made playable: shield or carry clear for a carer, make an example for a villain (Game Design's rules, Legal's screening) |
| **Provoke or feint** (physical fallback) | nothing else in reach, physical mode | reuses the feints; 1 provoke | a taunt that feeds mood and meters, or a feint that baits a dodge or a block |
| **Energy shove** (energy fallback) | nothing else in reach, energy mode | reuses the shove pose and a burst emission | pushback with no damage: makes space |
| **Reversal** | while guarding, close | 1 | after a blocked strike, turns the attacker's momentum into a throw or sweep |
| **Deflect** | while guarding, at range | reuses the guard pose and an emission | swats a blast or angles a beam away |
| **Tackle** | while sprinting | 1 | a running grab that carries both fighters (a long-haul launch vector) |
| **Dive grab** | in the air | 1 | a grab from above into a spike or ground slam |

That is about **12 new pieces per fighter**, several of them reused poses. The outcome table for each action against each held state is template work for Combat with Game Design, once the scheme has Orb's go.

### 9.4 Fewer beams, each fighter's own beam, and beam against beam
- **A beam style per fighter.** The signature layers (section 3.3) gain a style family that sets the beam's shape. The placeholders: KAI a thin piercing lance, VORR a wide rolling wave. The four real fighters get their own (the precise cut, the barrage-fed beam and so on), named by Narrative and screened by Legal.
- **Fewer beams.** Signatures stay within Game Design's band (2 to 4 a match). Ordinary energy blasts and mixups fill the ranged game.
- **The director never fires a beam on its own.** A struggle starts only when a beam is **answered by a beam**: during the attacker's charge (the visible tell), the defender fires their own signature. Then the six clash shapes play (`variety-pass.md` section 2.6).
- **Without an answering beam,** the defender's held state decides:
  - held Guard: GUARD;
  - a perfect block: DEFLECT;
  - a dodge tap: DODGE (for its energy cost);
  - sprinting away: the ESCAPE gamble;
  - anything else: HIT.
- **AI and the Simple layout.** There the director presses for the player. It may answer a beam with a beam, by Game Design's rule.

### 9.5 What the player can do inside an exchange
ADR 0008 allows four actions inside an exchange, at defined windows. Every template branch and every composed phrase must expose them, and every part must be cancellable at its boundaries (`part_end`, section 7.4, gains the reasons `dodge`, `burst` and `reversal`).

| Action | Window | Grammar consequence |
| :--- | :--- | :--- |
| **Perfect block** | the visible wind-up of a blockable strike. A mistimed tap still blocks | the anticipation minimums (section 7.2) are now gameplay as well as readability: the wind-up is the window. Controls sets the widths |
| **Dodge cancel** | the gaps between contacts, for an energy cost and a cooldown | phrases mark their cancel points; a cancelled phrase ends cleanly at the next part boundary |
| **Burst** | while under pressure: pressure strings and chain links | replaces the chain break-out window proposed in `variety-pass.md` |
| **Reversal** | after a blocked strike, while guarding close | a defender-favoured branch on the templates where the guard holds |

**Combos are queued presses.** Each press is one exchange request, and repeated presses queue a short combo. So the queue sets the chain's length; the director still times the links and plays the ender on the last one. `chainP` (`styles.json`) remains for the AI and the Simple layout.

### 9.6 Revised counts and cost
| | Section 1 | With ADR 0008 |
| :--- | ---: | ---: |
| Hand-made basic pieces | 64 | **about 87**: 64, plus 1 entry, 10 energy hands and poses, and 12 context pieces. VFX adds 6 emission shapes |
| Physical attacks | 10 × 24 × 4 × 5 = 4,800 raw, about 2,160 valid | 11 × 24 × 4 × 5 = 5,280 raw. About 40% are valid (retreat and stand entries join fewer strikes): **about 2,100** |
| Energy attacks | none | 11 × 36 × 4 × 5 = 7,920 raw, about 40% valid: **about 3,200** |
| **Distinct basic attacks** | about 2,160 | **about 5,300** |
| With lead-ins | ×3: about 6,500 | ×4 (mixups): **about 21,000** |
| Key poses per fighter at launch | roughly 500 to 900 | **roughly 550 to 1,000** (energy mostly reuses the body poses) |

The energy family more than doubles the fill (about 2,160 to about 5,300) for about a third more hand-made pieces, because it reuses the body poses. The validity factors are estimates until Tools' enumerator runs on real data.

**Milestones.** M0 and M1 are unchanged. M2 adds the mode and direction axes. M3 adds the context actions and the in-exchange windows. The order waits on Orb's go for ADR 0008.

### 9.7 Wind-up tells and which strikes can be perfect-blocked
Controls and Game Design need a visible wind-up of at least **15 ticks for a light and 20 for a heavy**, with the perfect-block window in its **last 8 to 10 ticks** (`docs/design/control-rules.md` section 1 sets 10). The anticipation minimums in section 7.2 (6 and 10 ticks) remain the floor for strikes that have **no** window.

| Strike class | Wind-up | Perfect block? | In today's templates |
| :--- | ---: | :--- | :--- |
| **Opener** (the attacker's first strike of an exchange) | 15 light, 20 heavy | yes | TRADE BLOWS, PRESSURE and GUARD BREAK's first strikes; a DODGE read's strike; a caught pursuit's strike |
| **Heavy** (any heavy-weight strike) | 20 | yes | HEAVY CLASH's deciding blow (either side), GUARD BREAK's breaking strike, heavy counters |
| **Ender** (the last blow of a string or chain) | 18 (Game Design), at least 15 | yes | TRADE BLOWS' deciding blow, the chain ender |
| **Ordinary energy blast** | 15 light, 20 charged | yes: a perfect block deflects it | the energy family (9.1) |
| **Mid-string hit** | 6 (the section 7.2 floor) | no: a held guard still blocks it normally | PRESSURE's second and third strikes, TRADE BLOWS' exchanged blows, chain links |
| **Signature** | the charge (0.8 s) | yes: a perfect block deflects it (Game Design, `control-rules.md` section 1), with three looks by the direction held (`m0-rich.md` section 6). It can also be guarded, dodged, escaped, or answered with a beam | all signatures |
| **Grab, tackle, dive grab** | 10 | no: a grab beats Guard, loses to an attack and misses a dodge | context actions (9.3) |
| **Strikes on a fighter who cannot guard** | as its weight | none to give | CHARGE INTERRUPT (the channel drops the guard), strikes on a launched or downed body |

What this changes in the data, when it lands:
- **Each strike carries its class** in place of today's `noParry` flag: opener, heavy, ender, blast, mid or none.
- **The dynamic profile's timings move.**
  - Heavy exchanges need an approach of at least 20 ticks (15 today), so the heavy opener's wind-up fits inside the flight.
  - The chain ender's wind-up grows from 12 to 18 ticks.
  - TRADE BLOWS' deciding blow gets a 15-tick wind-up after the circle.
- **The window is data per strike:** its start and end ticks, the last 10 ticks of the wind-up. Controls owns the width.

### 9.8 MOUNTAINSIDE: replaced by formation brunts
World is moving the mountains to a backdrop and adding natural formations as brunt targets: mesa, rock, spire and bigtree (`docs/world/districts-plan.md` section 12).

**Decision: MOUNTAINSIDE is retired as a launch vector, and formation brunts take its place.**
- **Why.** With the relief capped at about 8 bh, a "mountainside" is just a hillside, which SMASH ACROSS already lands on. The thing MOUNTAINSIDE was for, a hard natural surface to be driven into, is exactly what a formation is, and there will be 150 to 300 of them across every wild biome instead of one range.
- **The launch-vector vocabulary becomes:** UPPERCUT, SLAM DOWN, SMASH ACROSS, and **BRUNT**, with a target kind. BUILDING SMASH is a brunt on a structure. The new kinds are a brunt on a mesa, a rock, a spire or a big tree, each with its own reaction cue from World's fall kinds: strata burst, rock burst, snap, tree snap.
- **Personality comes for free.** Formations hold no people. The hero's care term makes them his preferred brunt targets, and the villain still prefers a populated tower. The hero finally gets brunts of his own.
- **Staging.** MOUNTAINSIDE stays in the data until World's D2 lands (it keeps working, landing on hills and rock). The brunt-by-kind vectors replace it in the same slice. Scoring stays Encounter's.
- **RIDGE BORE** (the signature variant) keeps its key, on the highlands' rock.
- **Names.** Narrative's proposed INTO THE MOUNTAIN no longer applies; a label for formation brunts is Narrative's to propose.

### 9.9 Grab, throw and props (with Controls' context button)
This is the choreography for the context actions that seize something. The rules, costs and priorities are Game Design's (`docs/design/control-rules.md` section 4); the prop state, flight and damage are World's (`WorldProps`, V1).

**Grab and throw (the rival within 1.5 bh):**
| Beat | Ticks | What happens |
| :--- | ---: | :--- |
| Reach | 10 | the grab's wind-up. An attack in progress beats it; a dodge makes it whiff (a 1.5 s cooldown); a held Guard does not stop it |
| Hold | 8 | the grab connects: both fighters lock, with a grab cue |
| Throw | on the next tick | the held direction picks the vector. Toward: a hurl across (the planner's long-haul candidates, brunts included). Neutral: a slam down. Away: a back throw, over the shoulder |

**Tackle (while sprinting).** A running grab with a 12-tick reach that carries the rival along the ground for 30 to 60 ticks (World's knockback slide), then releases them into whatever lies ahead: a brunt target if one is in the path.

**Dive grab (airborne, the rival below within 3 bh).** A 10-tick reach from above, then a slam straight down: a ground slam with World's crater rules.

**Reversal (Guard held, close, just after a normal block).** An 8-tick turn and counter-strike that starts the defender's own exchange with the roles swapped. It has no perfect-block window: its wind-up is under 10 ticks.

**Props (a liftable object within 2 bh: parked cars, bikes, boulders, trunks, lamps).**
| Step | Ticks | What happens |
| :--- | ---: | :--- |
| Lift | 12 (reach 4, hoist 8) | the fighter is committed and can be hit. The prop becomes held (`S.props`). The power tier caps the size: tier 1 a bike, a lamp or a small boulder; tier 2 a car or a trunk; tier 3 and up, wreckage and large boulders |
| Carry | while held | a carry posture layer over normal movement. A Guard press, a dodge or taking a hit drops the prop. The mode is ignored while a prop is held |
| **Light press: throw** | wind-up 15, release | an opener, so it can be perfect-blocked (the prop is batted aside) or normally blocked. The direction shapes it: toward is a running hurl, neutral a standing throw, away a retreating lob. Then World's ballistic flight takes over, with damage by mass and speed |
| **Heavy press: slam** | wind-up 20 | within 2 bh, the prop is swung down on the rival as a crushing key strike. It breaks, and the ground dents by World's rules. Beyond 2 bh, an overhead hurl: slower and heavier |

- **What a hit does.** A prop that hits the rival launches them along its path, and World's `prop_hit` event tells the director. Whether that counts as a decisive exchange is Game Design's call. A prop that hits a structure or formation is a brunt on it; among people, World's collateral rules apply.
- **Events Combat needs from Simulation and World:** `prop_grab`, `prop_throw` (with the vector and force class) and `prop_slam` out; `prop_hit` in.
- **Pieces per fighter:** lift, carry layer, two throws (one hand and two hands, by size) and the slam, plus grab, two throw poses, tackle, dive grab and reversal. With the civilians action, the provoke and the shove, the context set is about **14 pieces** (9.3 estimated 12; the basic total becomes about 89).
- **Cues for Rendering:** `grab`, `grab_throw`, `tackle`, `dive_grab`, `reversal`, `lift`, `carry`, `prop_throw`, `prop_slam`.
