# Moveset system

Owner: Combat and Choreography. Implementation: Encounter Systems (the composer), Animation and Rendering (poses and in-betweens), Tools (schemas). Numbers: Game Design. Date: 2026-09-30. Status: plan, system first, content after (Orb, questionnaire 6).

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
| **M0. Contract** | Schemas (pieces, phrases, moveset, composer); the composer skeleton in `sim/director/` calling keyed draws; the structured event log with fingerprints | none: today's templates as a single fixed "piece" per slot | Bit-identical to the current build on the golden seeds (as S3b was) |
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

## 7. What each team needs

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
