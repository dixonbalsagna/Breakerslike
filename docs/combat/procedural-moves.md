# Procedural moves

Owner: Combat and Choreography. Status: design, P2 onward. Date: 2026-09-29.

How the fight director composes attacks from generative parts, so that each fighter's moveset is vast, each fight feels unique, and every beat still reads as an authored, choreographed moment.

**Orb's brief** (questionnaire 3, `docs/ep/vision.md`):
- procedural systems that create near-limitless sets of attacks, very large movesets for each fighter, and unique specials;
- dynamic combos, so a player never sees the same series of attacks twice;
- more attacks that launch fighters across the map;
- a fighter-specific finisher always ends the fight.

The feel reference is brutal, readable, choreographed flash-animation fights.

**What this builds on:**
- `move-grammar.md`: the prototype's atoms, which become the first parts;
- `exchange-templates.md`: the outcome skeletons;
- `signature-variants.md`: the signature layers;
- `data-fields.md`: the field list;
- Game Design's `docs/design/stance-matrix.md`: stance intent and rules R1 to R8.

**Ownership:**
- Encounter Systems owns the director code in `sim/director/`. This design runs inside it.
- Game Design owns the numbers and the damage model (`docs/design/damage-model.md`, in progress). The damage model is reached through the interface in section 8 and not decided here.
- Controls and Game Feel owns window widths and hit-stop.
- Animation owns the clips.

---

## 1. The idea in one page

Three layers, each with a different owner of truth:

| Layer | What it decides | Authored or generated | Exists today as |
| :--- | :--- | :--- | :--- |
| **Exchange** (scene) | Who wins, what windows open, when the contacts land. Stance × attack kind × defender state picks the template and branch (`stance-matrix.md`) | **Authored** (outcome logic, windows, player agency) | `planMelee` and `planBeam` in `sim/director/` |
| **Phrase** (move) | *How* each beat of the scene looks and moves: approach, strike shape, contact, reaction, launch vector, follow-up, camera and fx cues | **Generated** from authored parts, by grammar and scoring | hard-coded, one look per template |
| **Part** (atom) | One authored unit of motion with a clip, timing, reach and tags | **Authored** (animation, timing, tags) | the atoms in `move-grammar.md` |

- **The exchange stays the judge; the phrase is the choreography.** The template fixes the outcome and the anchor ticks: contact times, window opens and closes. The composer fills each beat with parts that fit those anchors, the context and the fighter.
- **Gameplay timing stays authored.** Parry windows, chain windows and hit-stop are the template's and Controls'. Only the look of the move varies.
- **Pillar 2 survives.** The player still chooses intent (stance, attack kind, and a few window inputs); the choreography is generated.

Vastness comes from multiplication. Take one fighter with 12 approaches, 30 strike shapes, 10 reactions, 14 launch vectors and 8 follow-ups, with context bends on each. That gives tens of thousands of distinct phrases, and a chain of three phrases gives billions of series. The authoring cost grows with the *sum* of parts, not the product.

---

## 2. What a move is made of: the part grammar

### 2.1 Slots

A phrase is an ordered set of slots. Each slot is filled by one part, or by none if the slot is optional.

| Slot | What it is | Example parts (common vocabulary) | From the prototype |
| :--- | :--- | :--- | :--- |
| **Approach** | How the striker closes the gap. Always succeeds (pillar 3) | straight dash, arcing dive, rising uppercut-approach, circle-behind, ground skim, ripple-step teleport (tell: a ripple in the air, per Orb), burst through terrain | `rush`, `rush.chain`, `rush.rise` |
| **Setup** (optional) | 0 to 3 lead-in strikes or feints that build rhythm | jab, feint, shoulder check, low kick, guard-crack palm | the exchanged blows in TRADE BLOWS, the three PRESSURE strikes |
| **Key strike** | The blow the beat is about; its contact lands on the template's anchor tick | hook, straight, knee, elbow, axe kick, roundhouse, spinning heel, double-fist hammer, headbutt, grab-and-throw, tail lash (fighter parts) | `strike` |
| **Contact** | How the blow meets the body; set by the outcome branch | clean, guarded, deflected, glancing, clash (both strikes meet), parried | parry, guard, clash |
| **Reaction** | What the struck body does | flinch, stagger, spin-out, crumple, fold, knock-away, embed (in a wall or the ground), bounce | knockback, `down`, bounce |
| **Launch vector** (optional) | Where the body is sent; the fight moves with it | up, spike down, across, **long haul (across the map)**, into a structure, into terrain, skim along water, orbit throw (at top tiers) | UPPERCUT, SLAM DOWN, SMASH ACROSS, BUILDING SMASH, MOUNTAINSIDE |
| **Follow-up** (optional) | What the striker does after contact; also the hook for the next chain link | pursue, overtake and meet (relay), pin, taunt pause (bark), disengage, beam follow-up | the chain window and `rush.chain` |
| **Camera cue** | Framing for the phrase: render only, never read by the simulation | tight contact, whip-pan on launch, follow-cam for long launches, impact freeze, wide establishing shot | none (fixed camera logic) |
| **Fx cue** | Impact class and world effects: render only | impact tier 1 to 4, shock ring, debris burst, water geyser, glass spray, ripple | the fx event stream (QA-002 fix) |

### 2.2 What a part carries

Every part is authored once, as data plus a clip:
- **Timing in ticks** (60 per second): anticipation, active (the contact tick is marked), recovery. It also carries a *stretch range*, the playback-speed band it may be fitted into, for example 0.85 to 1.2×.
- **Spatial envelope:** reach, height band (ground, low, high), direction (forward, up, down, behind) and the height at which it makes contact.
- **In-state and out-state:** pose family, height band, facing, and momentum (still, forward, rising, falling). Two parts may be joined only when the out-state of the first matches the in-state of the second. This is symbolic motion matching; it is what keeps a generated phrase flowing like a choreographed one.
- **Tags:** limb (fist, foot, knee, elbow, head, tail, energy), weight (light, heavy, special, finisher), style (clean, brutal, showy, precise, feral), and the damage-location hint (head, torso, arm, leg) that is passed to the damage model.
- **Readability rules:** minimum anticipation ticks for its weight, and silhouette clarity (a flag from Animation).
- **Cue sets:** the camera and fx cues it allows.
- **Gates:** tier minimum, form or fighter, context requirements (for example, *ground only*).

### 2.3 How parts combine: phrase classes

A **phrase class** is the grammar for one kind of beat. It lists its slots, their constraints and the parts allowed in each. Examples:

| Phrase class | Used by | Grammar |
| :--- | :--- | :--- |
| `strike.clean` | an attacker-favoured beat | Approach → Setup (0 to 2) → Key strike (heavy or light by the attack kind) → Contact: clean → Reaction → Launch? → Follow-up |
| `strike.guarded` | GUARD HOLDS, the first beats of GUARD BREAK | Approach → Setup (1 to 3) → Key strike → Contact: guarded → Reaction: flinch or skid |
| `trade` | TRADE BLOWS | Approach → 4 alternating exchanged strikes (A, D, A, D), no limb repeated back to back → the deciding strike → Launch |
| `counter` | DODGE — COUNTER, COUNTERED | Evade part (for the defender) → Key strike (for the defender) → Reaction (for the attacker) → Launch |
| `chase` | PURSUIT, chain links | Approach (pursuit variant) → Catch → Key strike → Launch |
| `clash` | heavy clash, beam clash | twin Key strikes meeting → shockwave cue → push-apart or overpower |
| `special.<fighter>.<id>` | fighter specials | authored skeleton with generative slots (section 4) |
| `finisher.<fighter>` | the last blow | authored skeleton with context bends (section 7) |

**How the template maps onto phrases.** Each template branch lists its beats and a phrase class for each; its anchor ticks stay authored. Examples:
- GUARD BREAK is `strike.guarded` (two blows) → guard-break cue → `strike.clean` with a launch, whose contact lands on the break tick.
- The chain window and the parry window keep their template positions.

**Fitting to anchors.** The composer lays the chosen parts on the timeline so that:
- the key strike's contact tick lands on the template's contact anchor;
- anticipation fits before it, stretched within each part's range;
- the phrase fits the beat's time budget.

A part that cannot fit is not a candidate. Gameplay timing therefore never depends on which part was picked.

---

## 3. How the composer chooses: scoring

For each slot, in order, the composer:
1. filters the fighter's vocabulary to the parts that satisfy the phrase class, the joining rule (in-state and out-state), the gates, and the fit;
2. scores each candidate:
   `score = fit·w_fit + style·w_style + context·w_ctx + novelty·w_nov + drama·w_arc`
3. picks by a **seeded weighted draw among the top K** (K about 4), never the argmax (which is predictable) and never a uniform draw (which is incoherent).

| Term | What it measures |
| :--- | :--- |
| `fit` | how naturally the part joins the previous one (stretch needed, momentum match) |
| `style` | the fighter's vocabulary weight for the part, moved by ego meters and form (section 4) |
| `context` | how well the part suits biome, altitude, terrain, stances, damage state and tier (section 5) |
| `novelty` | how unlike the fighter's recent choices it is (section 6) |
| `drama` | fit to the match's arc: lighter phrases early, bigger set pieces as the acts escalate (`economy.md` §7); cross-map launches favoured when the fight has stayed in one place too long |

**Two-level choice keeps identity readable.** Context picks the *class* of each slot, for example "spike down into water". Novelty varies the *realisation*: which kick, which angle, which camera. The same situation therefore reads the same way (identity, test T2 in section 9), while the same fighter never looks canned.

The weights (`w_*`) are data, tuned by Game Design with QA's metrics.

---

## 4. Per-fighter vocabularies, specials and signatures

### 4.1 Vocabulary

A fighter's vocabulary is data:
- **Common parts it uses.** The shared library, re-skinned by the fighter's animation set.
- **Its own parts.** For example, tail parts for the Galactic Tyrant, or portal approaches for the Demon Cyborg.
- **A weight per part, and style weights per tag.**
- **Meter bends.** How each ego meter shifts style weights (section 5).
- **Form deltas.** What each transformation form adds, removes or reweights. The Tyrant's many "revisions" are small deltas on one vocabulary, not ten movesets.
- **Specials, the signature and the finisher.**

Sketch of the four fighters, as archetypes from `docs/ep/vision.md`:

| Fighter | Vocabulary shape | Distinct parts | Specials (examples, working labels) |
| :--- | :--- | :--- | :--- |
| Protagonist | The largest hand-to-hand library; clean, athletic style | ripple-step teleports mid-phrase (tell: the air ripples); relay strikes that overtake a launched body | **Ripple flurry**: a chain of teleport strikes, angles from context. **All-out finisher**: energy, section 7 |
| Anti-hero | Brutal and showy; drags fights out | energy barrages (multi-projectile phrase class); taunt pauses; "toying" phrases that deliberately don't launch | **Barrage until submission**: a projectile phrase with volume scaled by Pride. **Finisher**: by hand |
| Galactic Tyrant | Precise and dominant, fights from range; forms change it subtly | cutting-beam parts (thin, exact paths); tail parts, redesigned per Legal; power slams | **Cutting beam**: a ranged phrase with path shape chosen from terrain and the defender's stance. The minions have small shared vocabularies |
| Demon Cyborg | The fastest; feral | portal approaches; grabs; consume beats near civilians | **Portal blitz**: approaches from several portals in one phrase. Consume specials (Game Design's mechanic) |

The goon minions (bruiser, marksman, speedster) use small subsets of the common library plus one special each. That makes them cheap to author and quick to read.

### 4.2 Specials

A special is an authored skeleton with generative slots. The skeleton fixes what makes it that fighter's move: its silhouette moment, its timing anchors, its cost and trigger (Game Design). The slots vary everything else. For example, the Ripple flurry's skeleton is "3 to 5 teleport strikes then a launch". Its slots pick:
- each teleport's angle, from the terrain and the defender's position;
- each strike's shape, from the vocabulary;
- the launch vector and the finish, from context.

### 4.3 Signatures

The signature is the special every fighter has. It uses the layered model already worked out for the signature beam:

| Layer | What it decides |
| :--- | :--- |
| L1 approach and charge | where it fires from and for how long |
| L2 path | profile, pitch, reach, where it ends |
| L3 material response | what it does to each ground material it touches, with a tier-scaled "bite" budget, so a beam stops razing underground and along foreign biomes (CC-012) |
| L4 outcome resolution | CLASH, GUARD, DODGE, HIT, ESCAPE, plus Game Design's DEFLECT and OVERCHARGE CLASH |
| L5 follow-up | launch vector, residue hazard, the next window |

Each layer is a small table keyed by material, altitude band, outcome, personality and tier. About two dozen authored rows cover every biome × band × outcome combination, instead of one hand-made move per cell. Section 5 of `signature-variants.md` records the variant names and the LANE SWEEP assessment.

---

## 5. Context inputs, and how they bend a move

Each input bends one or more slots, by filtering candidates (hard) or scoring them (soft):

| Input | Bends | How |
| :--- | :--- | :--- |
| **Biome and ground material** (water, sand, rock, soil, timber, city) | Launch vector, reaction, fx, the signature's L3 | Spike into water raises a geyser and sinks; into sand leaves a glassed crater; into rock embeds; into a city smashes through floors. Material also picks environmental parts (wall bounce, pillar snap) |
| **Altitude band** (submerged, ground, low air, high air; space later) | Approach, key strike, launch | Sweeps and ground slams only near the ground; dives only from above; air juggles only when airborne; slowed, heavier parts when submerged |
| **Terrain features** (a structure, cliff or crater nearby) | Launch vector, reaction, follow-up | "Into a structure" is offered only with a standing structure in the path; embed reactions need a surface; a crater edge offers a bounce |
| **Attacker's stance** (Game Design's R2 profiles) | Phrase class and setup count | AGGRESSIVE: longer setup strings, pressure. DEFENSIVE: short, measured, punish-shaped. EVASIVE: angled approaches, cross-ups, feints. ESCAPE: one strike, then vanish (hit and run) |
| **Defender's stance** | Contact and reaction (the outcome is the template's) | Guard reactions, evade parts, slip parts |
| **Damage state** (interface to Game Design's damage model, section 8) | Reactions, approach, target choice | A hurt limb changes the owner's parts (for example, a limp approach, favouring the other hand) and invites attackers to target it; heavier reaction classes as condition worsens |
| **Ego meters** (Respect, Pride, Wrath, Hunger) | Style weights, follow-ups | High Pride: showy parts, taunt pauses, toying. High Wrath: brutal, heavy parts. High Hunger: grabs, consume beats near civilians. Respect: cleaner, bigger committed strikes. Each fighter maps its own meter in data |
| **Tier and form** | Gates and scale | Higher tiers unlock bigger reactions (embed, crater), orbit throws and cross-map launches; bigger reach, force and fx class |
| **Collateral and personality** | Launch vector, the signature's L1 and L2 | A carer avoids vectors and paths into populated areas; a villain seeks them. The launch planner already does this for launches (`popNear` term); here it extends to every slot with a collateral footprint |
| **Match arc** | Drama term | Early acts lighter, later acts bigger set pieces; long launches favoured when the fight has stagnated in one biome, which is a direct answer to the "always in the ocean" greybox note |

---

## 6. Anti-repetition: variety memory and novelty scoring

**The memory** is part of the simulation state, so it is hashed, replayed and deterministic. It holds:
- per fighter, the last N phrase fingerprints (N about 12), with recency weights (half-life of about 4 exchanges);
- per fighter, counts of each part in each slot, decaying over about 60 s;
- per match, an n-gram table of *series*: the fingerprints of the last three phrases (a trigram), and the chain sequence inside each exchange;
- per match, launch-vector class counts. They carry what the prototype's two-deep launch penalty (−14 for the last launch, −5 for the one before) tried to do and did not: SLAM DOWN still made up 46% of launches.

**The fingerprint** is what a viewer can see without reading the feed:
- approach class
- setup length and the limbs used
- key-strike shape
- contact
- reaction class
- launch-vector class
- distance bin (how far the body travelled)
- follow-up class
- biome material
- altitude band

**The novelty score** for a candidate:
- a penalty for similarity to recent fingerprints (a weighted feature overlap, stronger for more recent ones);
- a bonus for parts unused this match;
- a hard block on the same key strike three times in a row, and on the same launch-vector class twice in a row within a chain;
- a hard block on any candidate that would repeat an existing trigram series.

**Limits on novelty:**
- It never overrides the outcome, the gates or fit.
- It never forces an unreadable choice; readability rules are hard filters.
- Identity is protected by the two-level choice (section 3): novelty acts inside the class that context chose.

---

## 7. Combos that chain dynamically, and the finisher

**Chains stay a player input.** The chain window remains the attacker's choice (agency), and the content of each link is composed:
- **From the previous link's end state.**
  - Defender high and rising: an air chase and an overtake.
  - Defender embedded in a wall: a pull-out strike.
  - Defender skimming water: a skim catch.
  - Defender grounded: a bounce follow-up.
- **By escalation.** Each link is heavier than the last, and the camera widens. From link 3 the link may **cash out**:
  - a cross-map launch;
  - a terrain slam;
  - a beam follow-up;
  - a fighter special.
- **Steered by the press.** Light **extends** (keep juggling). Heavy **cashes out** (ender). A held direction biases the launch vector: up, down, forward, back. Simple inputs choose intent, and there is still no combo list.
- **Answered by the defender.** In long chains the defender gets a **break-out** window, from link 3 onward, that costs a resource; the numbers are Game Design's. This caps length with a choice rather than a hard limit alone.
- **Bounded.** No chain after a parry or after GUARD HOLDS (Game Design's R6, fixing CC-001 and CC-002). The maximum length is data (5 today).

**Across the map.** Long-haul launch vectors are a first-class class, not a rare side effect:
- the body travels 1,500 u or more, and the camera follows;
- the attacker pursues and can **relay**: overtake the flying body and meet it with the next link;
- the world wraps, so a launch can loop the planet;
- the drama term favours these when a fight has stayed in one biome. Game Design sets the target share; a starting suggestion is at least a quarter of launches.

**The finisher always ends the fight.**
- The killing blow can only come from a finisher phrase.
- When the damage model reports that a fighter is *finishable* (section 8), that fighter's opponent's next winning beat is composed as their finisher.
- The finisher is an authored skeleton (a set piece with a bark pause; over 3 s is fine) with context bends: biome, altitude, whether the planet is crumbling, the loser's condition.
- Whether a finishable fighter gets a last desperate answer is a Game Design rule, for example a final clash. The composer supports it as an ordinary branch.

---

## 8. Interfaces to other systems

**To Game Design's damage model** (meter-less, location-based; not decided here). The contract is narrow: events out, descriptors in.
- *The composer sends* one `contact` event per landed or blocked strike:
  - attacker, defender, part id;
  - weight class (light, heavy, special, finisher);
  - location hint (head, torso, arm, leg), force and direction;
  - environment (into a wall, into terrain, into water);
  - the exchange's outcome.
- *The damage model returns*, for each fighter:
  - a `condition` descriptor: named zones with severity from 0 to 1, and flags such as `staggered` and `finishable`;
  - optionally, a suggested reaction class.
- The composer reads these only as tags and scoring inputs. It never computes damage, and it assumes no health number.

**To Encounter Systems.**
- The composer is a function called by the exchange planner once the template and branch are chosen.
- It returns the beat list in the existing format (`SimState.Beat` with `op` and `args`, dispatched by `DirExchange.runBeat`). The first slice therefore needs no new runtime path.
- The template stays Encounter Systems' selection, and its content stays Combat's.

**To Animation, VFX and Camera.**
- Parts reference clips with a marked contact frame. Cues go to the render-side fx stream and camera.
- Every part field is marked **sim-read** (timing, reach, gates, tags the composer scores on) or **render-only** (clip, pose data, cue sets).
- Nothing render-only can change the simulation.

---

## 9. What stays authored, and what is generated

| Authored (by people, reviewed) | Generated (at runtime, deterministic) | Never generated |
| :--- | :--- | :--- |
| Every part: clip, timing, reach, tags, cues | Which parts fill the slots, and in what order within the grammar | Animation poses (anti-goal: no free-form animation) |
| Phrase classes (the grammar) and readability rules | Parameter bends within authored ranges (angle, reach, stretch, launch force band) | Outcomes and branch choice (templates and Game Design's rules) |
| Exchange templates, windows, branch rules | Chain-link content from end states | Damage and condition (the damage model) |
| Vocabularies, weights, meter bends, form deltas | Camera and fx picks from authored cue sets | Player-facing names (Narrative proposes, Legal screens) |
| Specials, signature layers, finishers (skeletons) | Special and signature slot fills | |
| Scoring weights and novelty settings | | |

---

## 10. Deterministic, data-driven and moddable

- **Pure function.** The composer is `compose(template beat, context snapshot, vocabulary, memory, rng)`, which returns parts and beats. The context snapshot is read from the simulation state at plan time, never from rendering.
- **Its own random stream.** Composition draws come from a counter-based stream keyed by (match seed, exchange index, slot index, draw index), not from the shared sequence. Adding a part to a vocabulary then changes only the exchanges where that part was a candidate, not every later random event in the match. That keeps mods, balance edits and replays tractable. A slot always makes the same number of draws, even when there is one candidate.
- **Integer ticks.** All part timings are in ticks at 60 Hz, so fitting and stretching are integer arithmetic and bit-identical between the JS reference and GDScript (ADR 0001 parity).
- **Memory in the state.** It is hashed with the rest, so the determinism and golden tests cover it.
- **Data validation** (Tools) rejects:
  - a part without a contact tick;
  - anticipation below its weight's readability minimum;
  - unmatched in-states or out-states (a dead-end part);
  - a phrase class that cannot be filled for some reachable context;
  - a vocabulary missing a slot needed by a template it can trigger.
- **New fighters are data.** A fighter pack holds:
  - vocabulary
  - own parts (clips plus part files)
  - specials
  - signature layers
  - finisher
  - meter bends
  - form deltas
  New *part types*, meaning new engine behaviour, need code and are expected to be rare. The modding test at stage 5 is adding a fighter with no code change.

---

## 11. Data schema sketch

Shapes only; Tools owns the schema and the names. Numbers are placeholders for Game Design.

```json
// data/parts/strike.axe_kick.json
{ "id": "strike.axe_kick", "slot": "key_strike",
  "sim":    { "ticks": { "anticipation": 14, "active": 4, "recovery": 12, "contact": 16 },
              "stretch": [0.85, 1.2], "reach": 70, "band": ["ground", "low"], "dir": "down",
              "in":  { "pose": "upright", "momentum": ["still", "forward"] },
              "out": { "pose": "grounded_follow", "momentum": "still" },
              "tags": { "limb": "foot", "weight": "heavy", "style": ["brutal"], "location": "head" },
              "gates": { "tierMin": 1 } },
  "render": { "clip": "common/axe_kick", "contactFrame": 16, "cues": ["impact.heavy", "cam.tight_contact"] } }

// data/phrases/strike.clean.json
{ "id": "strike.clean",
  "slots": [ { "slot": "approach" }, { "slot": "setup", "min": 0, "max": 2 },
             { "slot": "key_strike", "anchor": "contact" }, { "slot": "contact", "value": "clean" },
             { "slot": "reaction" }, { "slot": "launch", "optional": true }, { "slot": "follow_up" } ],
  "rules": { "noRepeatLimb": true, "maxHitsBeforeHold": 3 } }

// data/fighters/protagonist/vocabulary.json
{ "fighter": "protagonist", "uses": ["common/*"], "own": ["protagonist/*"],
  "weights": { "strike.axe_kick": 1.2, "approach.ripple_step": 1.5 },
  "style": { "clean": 1.3, "brutal": 0.8 },
  "meterBends": { "respect": { "style.clean": "+0.5*respect" } },
  "forms": { "form2": { "add": ["approach.ripple_step_double"], "reweight": { "style.showy": 1.2 } } },
  "specials": ["protagonist.ripple_flurry"], "signature": "protagonist.signature", "finisher": "protagonist.finisher" }

// data/composer.json
{ "weights": { "fit": 1.0, "style": 1.0, "context": 1.4, "novelty": 1.2, "drama": 0.6 },
  "topK": 4, "memory": { "fingerprints": 12, "halfLifeExchanges": 4, "partDecaySeconds": 60 },
  "hardBlocks": { "sameKeyStrikeInARow": 3, "sameLaunchClassInChain": 2, "repeatTrigram": true } }
```

---

## 12. Staged build plan (smallest slice first)

Each stage ends with QA's metrics (section 13) and a slow-motion readability review.

| Stage | What | Exit |
| :--- | :--- | :--- |
| **0. Measure** | A structured event log per exchange: template, branch, the parts of each slot, fingerprint, context, contact events (also fixes QA-004). A baseline of the metrics on today's greybox | Metrics computed for the current build; the repetition baseline recorded |
| **1. Parity as data** | Today's templates expressed as data, with one fixed part per slot, producing the same beat lists | Bit-identical to the current director on the golden seeds |
| **2. One slot generative** | The launch-vector slot and the key-strike look, for one fighter (the first real fighter): 6 or more strikes and 8 or more launch vectors, including long-haul. Variety memory switched on | No launch class above 30%; long-haul share on target; no exact trigram repeats in 95% of matches; readability review passed |
| **3. Full phrase grammar** | All slots, 30 to 40 parts for that fighter, joining rules, anchor fitting, chain composition from end states, light/heavy/direction steering in chain windows | T1 to T5 pass (section 13); window widths unchanged |
| **4. Context bends** | Material, altitude, terrain, stance profiles, meter bends; the damage-state stub on the section 8 interface | Every context input measurably changes the fingerprint distribution in forced scenarios |
| **5. Specials, signature and a second fighter** | Specials and signature layers; a second fighter added as data only | The second fighter needs no code; the two vocabularies are distinguishable (T3) |
| **6. Finisher** | Finisher skeletons, wired to the damage model's `finishable` | 100% of matches end on a finisher; each fighter's finisher varies by context |
| **7. Polish** | Camera and fx cue composition, novelty tuning from playtests, pace | Playtest: a player describes fights as "different every time" and can still read who is winning |

---

## 13. How QA measures "never the same series twice"

All of these are computed offline from the stage 0 event log, over headless batches: the standard arms plus forced-context scenarios through the runner's setup hook.

| Test | What it checks | Starting target (Game Design and QA set the final) |
| :--- | :--- | :--- |
| **T1 Distinct contexts** | Any two reachable context classes have modal fingerprints that differ in at least 2 features | 100% of pairs |
| **T2 Identity** | Within one context class, the modal *class* choice is stable, so variety comes from realisation and context, not noise | Modal class at 60% of plays or more |
| **T3 Fighter identity** | Two fighters in the same context produce distinguishable fingerprint distributions | A classifier tells them apart at 90% or better |
| **T4 No repeated series** | Exact repeats of a three-phrase series (a trigram of fingerprints) within a match, and between two random matches | 0 in 95% of matches; between matches, under 1% |
| **T5 Natural variety** | Normalised entropy of part use per slot; the largest share of any launch class; every authored part used | Entropy 0.7 or more; no launch class above 30%; every part used at least once in 100 matches |
| **T6 Readability** | Anticipation at or above the weight minimum on every beat; no dead air beyond `maxDeadAir`; at most 3 contacts between holds; slow-motion review | 100% by static check; the review signed off |
| **T7 Across the map** | Share of launches that travel 1,500 u or more; share of fight time outside the ocean | Targets from Game Design; watches the greybox's ocean drift |
| **T8 Finisher** | Share of matches whose last blow is a finisher | 100% |

"Never the same series twice" is operationalised as T4: no exact repeat of any three consecutive phrase fingerprints within a match (95% of matches), and under 1% overlap between matches. T1, T2 and T6 keep it from being bought with noise.

---

## 14. Open questions

| Question | Owner (through the EP) |
| :--- | :--- |
| The damage model's condition descriptor and `finishable` rule; whether a finishable fighter gets a last answer | Game Design |
| Numbers: scoring weights, chain costs, break-out cost, long-haul launch share | Game Design |
| Chain-window steering inputs (light or heavy to extend or cash out; direction to aim) and their widths | Controls and Game Feel |
| The part library for the first real fighter, with contact frames and stretch ranges; the clip budget | Animation, with Art |
| Where the composer lives in `sim/director/` and how it is called from the planner | Encounter Systems |
| Part, phrase, vocabulary and composer schemas; the validation listed in section 10 | Tools and Pipeline |
| Names of specials and finishers | Narrative, then Legal |
| Pace (Orb: "too fast"): a global beat-spacing scale per act, or per phrase class | Game Design with Controls and Game Feel; Combat keeps readability minimums |
