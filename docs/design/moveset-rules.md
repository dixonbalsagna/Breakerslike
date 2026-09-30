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

*The owners below are superseded by the option pool in §7.1: each fighter picks one of three at character select.*

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

**Orb's pick: the Cyborg only.** His hidden weapons come with his final form: his technology isn't fully online until he docks, and generating those weapons is his distinct power-up (§7.2). No other fighter has hidden weapons or secret abilities. The Empress's seal-device and the Anti-hero's secret technique are withdrawn.

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

## 7. For Orb: world changes and transformations, second pass

Orb's picks so far:
- broken limbs, A;
- the time cap, A (the crust);
- hidden weapons for the Cyborg only, coming online with his final form.

This section is the second pass Orb asked for. Nothing here is locked.

### 7.1 World-changing abilities: three options per fighter

**How it works.** Each fighter **picks one of their three at character select**, as part of the loadout, so the player gets range. It stays once per match and permanent, with the same cost and counter-play as §3.
- *Categories:* land, sky and light, water and climate, orbit and gravity, fields, pathways, technology.
- *No duplicates:* if both fighters pick the same category, the second pick is greyed out at select.

| Fighter | Option | Category | What it does to the fight |
| :--- | :--- | :--- | :--- |
| **Protagonist** | **Proving Ring** | Land | Raises a ring of ridges: new sight blockers and mountainsides, and a natural arena that pulls the fight away from towns |
| | **Heat Wave** | Climate | His blood heats the world. The sea partly evaporates into fog banks (sight blockers), the lowlands dry out, and his heat cools half as fast. More power, and more of his own internal wear |
| | **Break the Clouds** | Sky and light | He tears the sky open: permanent clear daylight, no cloud cover, and lock-on range +30%. An honest duel with nowhere to break lock. It hard-counters a storm |
| **Anti-hero** | **Storm Crown** | Sky | A permanent storm: lock-on range −30%, easier lock breaks and lightning hazards. His barrages gain +20% |
| | **Scorched Plain** | Land | He flattens a region: ridges fall, cover burns and settlements in the zone take damage, within the budgets. "Nowhere to hide from me" |
| | **Crushing Presence** | Field | His aura presses down on the world: the flight ceiling drops by half, launches travel ×0.8 and impacts wear ×1.2. It becomes a ground brawl, where his shed forms are fastest |
| **Empress** | **Gravity Decree** | Orbit and gravity | Her fleet shifts the planet's gravity: launches ×1.3, airborne time ×1.5, impact wear ×0.7 |
| | **The Annexed Moon** | Orbit | She drags a moon close. Tides flood the lowlands for 20 s in every minute and then drain, on a fixed, telegraphed cycle. Moon-shadow eclipses darken the sky |
| | **Blockade** | Sky | Her fleet fills the upper sky: anyone flying above 60% of the ceiling draws fire (hazard wear), which pushes the fight low, where her guard and volleys work best |
| **Cyborg** | **Floodgate** | Water | His portals flood the lowlands: movement ×0.55 underwater, and civilians are herded uphill toward him |
| | **Shortcut Network** | Pathways | Permanent portal pairs link distant parts of the planet. Flying through one exits at its twin, so the map folds into shortcuts, and his portals spew sandwiches as hazards |
| | **Wired World** | Technology | His cabling spreads across the ground: on wired ground he regenerates +2 ki per second, and wired water becomes an electrified hazard. It is strongest once his tech is online (§7.2) |

### 7.2 Transformations: the four refined, with one alternative each

| Fighter | Refined mechanic and its signature feel | Alternative |
| :--- | :--- | :--- |
| **Empress: a ladder** | *Bureaucratic escalation.* Revisions 1 to 8 are tiny jokes; revisions 9 to 12 are dramatic. Each real revision adds its **own signature** to her pool and grows her mantle, and refits patch her up. The feel: absurd, then terrifying | **Branching ladder:** at revisions 9 and 11 she picks one of two amendments, armour or artillery. The player chooses her build mid-fight |
| **Protagonist: a draining meter** | *Pushing past his limits.* The heat track (Heated, Simmering, Boiling) is his transformation, with glowing seams and a heartbeat. Its price is internal wear. The capstone is his final form, allowed only in the fold, where nobody else can be hurt. The feel: a man burning himself for the fight | **A ladder his rival feeds:** his forms unlock from Respect, which he earns when the rival gives everything. The opponent literally powers him up by fighting hard |
| **Anti-hero: shedding** | *Stripping down to raw power.* Three sheds, each a respected cinematic with no way back: **regalia** (armour off: guard weaker, +speed), **the front** (Drop the Act: hidden wear shows, +damage), **restraint** (no guard at all, top speed and damage). The feel: every shed is a humiliation he turns into power | **Pride ascension:** forms that raise his power while his Pride is high, and are *lost* when it crashes. It keeps the original "power and self-importance" idea: a higher ceiling, and a risk of falling |
| **Cyborg: evolution by consumption** | *Growing into the machine.* Wired (Hunger), then Kitchen (sandwich portals), then **Docked**: the final form, where his technology comes online. Only then does he **generate his hidden weapons**, which join his loadout as specials (Combat and Narrative design them). Before that, they show as dark, sparking ports: a visible promise. The feel: something unfinished, becoming whole | **Assimilation:** he feeds on wreckage (destroyed structures) instead of people. It is less dark and ties him to destruction rather than civilians, if the tone ever needs it |
