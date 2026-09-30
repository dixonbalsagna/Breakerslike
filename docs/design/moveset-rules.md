# Moveset rules: specials, signatures, world changes, secrets, transformations and style

Owner: Game Design. Status: rulings for questionnaire 6 (`docs/ep/vision.md`). Date: 2026-09-30. Combat is designing the move-building grammar in parallel (the hand-made pieces plus a composed fill). This page sets the **game rules** that grammar serves. Names are placeholders, and every number is a starting value for QA.

**Holds from earlier rulings:**
- The player sets intent, weight, specials and when to transform; the director times everything (`stance-matrix.md` §4b).
- Transformations are respected: the fill can be stopped, the cinematic cannot (`spec-wounds.md` §8).
- 2 to 4 signatures a match, with a 120 s cooldown (`balance-targets.md` §13).

## 1. Specials

- **Loadout.** **3 specials** per fighter, chosen from that fighter's pool at character select. Each fighter has a default loadout.
- **Contextual variants.** Each special has variants, and the director picks one from context: biome and surface (air, ground, wall, water), altitude, distance, the opponent's stance and injuries, and the fighter's form and mood. It uses the same selector grammar as Combat's styles. The player never picks a variant.
- **The control.** Hold **Special** plus a direction to choose the slot (for example up, forward or down). That queues the special, and the director fires it at the next opening, within 180 ticks, as with the signature queue.
- **Cost:** 15 to 30 ki each, set by power class. **Cooldown:** 25 s per special.
- Specials never count toward the signature band.
- **Kept apart from specials:** the fighter mechanics (stoke, Press, Drop the Act, the fold, the Encore) keep their own inputs and prompts (`stance-matrix.md` R9).
- **Bands:**
  - 8 to 16 specials fired per fighter per match;
  - no single special above 50% of a fighter's specials;
  - specials' damage counts in the damage rate that k is tuned against, so length holds.

## 2. Signatures

A fighter has a small pool of signatures. **Which one fires** follows this priority:
1. **Form-tied.** Each form or stage has its own signature: the Empress's final revision, the Cyborg's docked form, the Protagonist's final form in the fold, the Anti-hero's unrestrained state.
2. **Revealed.** Unlocked mid-fight by a story moment, and from then on it replaces the base signature. Triggers (Narrative writes the moments):
   - the fighter's first region break, or the first brink;
   - the first transformation;
   - reaching act 3;
   - a rivalry line thread completing in that matchup;
   - the fold.
   Each fighter has 1 or 2 revealed signatures, and each has its own trigger.
3. **Place-driven.** The base signature's variants by biome, altitude and the defender's stance (pillar 7).

**Limits.** All of a fighter's signatures share the **120 s cooldown** and the 45 ki cost. The match band stays 2 to 4 beams, so a typical match shows a place variant early, a revealed one mid-fight and a form signature late. Signature names show on screen (Orb: names for specials, signatures and finishers only).

## 3. World-changing abilities

- **Who and when:** each fighter has **one**, usable **once per match**, and **permanent** for the rest of it.
  - *Available* from act 3, or from tier 3.
  - *Never* during the opponent's finisher.
  - *Kinds:* the two fighters' abilities in one match are always different kinds.
- **Cost:**
  - *The fill:* a 4 s channel costing **all ki (at least 80 needed)**. The opponent can stop the channel with a decisive exchange, and half the ki is lost.
  - *Then* a respected cinematic of up to 5 s.
- **Effects:** they apply to both fighters. The user chose the moment and the place, and their style is built to suit the change: that is the edge, and the counter-play.

| Kind | Proposed owner | What it does to play | Counter-play |
| :--- | :--- | :--- | :--- |
| **Land** | Protagonist | Raises a ring of ridges around the fight: new sight blockers, mountainside launches, and a barrier that cuts lure routes. It pulls the fight away from towns | The rival uses the new cover to break lock, or leaves the ring (flight is unaffected) |
| **Sky** | Anti-hero | A storm sky for the rest of the match: lock-on range falls by 30%, lock breaks come easier (any cloud counts), and lightning strikes as hazard wear (limbs capped at battered). His barrages gain +20% in the storm | The rival gets the same easier lock breaks, and the storm hurts both |
| **Water** | Cyborg | Floods the lowlands through his portals. Low ground becomes sea, where movement is ×0.55 and launched fighters skim. Towns evacuate uphill within the collateral budgets, herding civilians toward him | The rival fights above the water line, or relocates (the fold) |
| **The planet itself** | Empress | By decree her fleet shifts the planet's gravity: launches travel ×1.3 and stay airborne ×1.5, and impact wear drops ×0.7. Her ranged work and her guard's volleys suit it | Everyone flies further, so the rival can use long launches to escape or chase |

- **Collateral:** floods, ridges and lightning count toward the ramp and the ceiling, and can borrow at tier 3 and above (`balance-targets.md` §4b).
- **Bands:**
  - a world change in 40 to 70% of matches;
  - both fighters using theirs in at most 25%;
  - the user's win rate after using it: 50 to 60%.

## 4. Hidden weapons and secret abilities

- **Who:** only **the Empress** and **the Anti-hero**. The Protagonist is open and earnest. The Cyborg's secrets are his body (the Rail chip, the drive), which are already on show.
  - *The Empress:* a hidden weapon, a concealed seal-device of state (Narrative names it), revealed at her first real revision (9).
  - *The Anti-hero:* a secret technique, "ancient knowledge" he has never shown, revealed when his Pride first crashes (the facade crack) or when he Drops the Act.
- **The reveal:** a respected beat of about 1.5 s with a line. The weapon or technique joins that fighter's loadout as a fourth special for the rest of the match.
- **Learnable:** the triggers are fixed and readable, so players learn to expect them. The reveal is a set piece, not a random surprise.

## 5. Transformations: one mechanic per fighter

| Fighter | Mechanic | How it works (existing rules) | Trade-off |
| :--- | :--- | :--- | :--- |
| **Empress** | **A ladder of forms** | 12 revisions: jokes 1 to 8, then real revisions 9 to 12 through the processing fill, with refits (`spec-wounds.md` §3) | Slow to peak and exposed while processing. Strong late, and heals a little on the way |
| **Protagonist** | **A meter-fed state that drains** | The heat track: stoked, then Heated, Simmering and Boiling, cooling back down, with internal wear as the price. His final form in the fold is the capstone | Burst power now, paid in health later. A boil-over is the risk. The fold is the only place he can go all out |
| **Anti-hero** | **Shedding power to go faster** | Drop the Act, plus shed regalia: each shed layer (his front, pieces of regalia, his guard) trades protection for speed and damage. It builds on Humbled and B1 as notes | Faster and harder-hitting but more fragile. His hidden wear shows and counts. There is no way back |
| **Cyborg** | **Evolution by consumption** | Hunger-fed, irreversible molts: Press, then sandwiches, then docking the drive. His final form is the fastest in the game | Needs people: exposed while feeding, and countered by protecting civilians and by the fold |

Each is unique: a ladder, a drain, a shedding and an evolution. The universal rules still hold: a stoppable fill and a respected cinematic, the 15 s surge after a completed form (`balance-targets.md` §13), and forms that never heal (except the Empress's refit and Rallies).

## 6. Style shift mid-match

A fighter's **style** is the set of weights the composer uses to choose pieces: which limb, air or ground, rhythm, flourish. It shifts with three inputs, multiplied together:
- **Mood band:**
  - *Calm:* measured and technical, with more feints and footwork;
  - *Tense:* aggressive, with more links;
  - *Frenzied:* wild, big swings and blitzes.
- **Injury:**
  - *A battered or broken arm:* kicks and one-handed pieces;
  - *Battered or broken legs:* planted, upper-body work;
  - *A battered head:* sloppier, with more heavies and fewer feints.
- **Form:** each form or stage carries its own style weights.

Rules:
- The shift applies at exchange boundaries only, never mid-exchange.
- Style changes what the fighter *does*, not the numbers. Damage and odds come only from the rules already written (injury penalties, forms, stance).
- It is visible: a player should see a hurt or frenzied fighter move differently.

**Band** (Orb's recognisability of 3 out of 10): the same three-piece sequence repeats in under 10% of exchanges. In a blind review, 70% of reviewers can tell a Calm stretch of a fighter from a Frenzied one.
