# Systems sketch

Owner: Game Design. Status: P0, first sketch for EP review. Date: 2026-09-29.

Six systems that Orb's four fighters and the new match length need (`docs/ep/vision.md`). Each gets a short design and its open questions for Orb.

**Originality.** Orb's line is "staples yes, signatures no". Legal rated all four fighters CONDITIONAL (`docs/legal/fighter-concepts-review.md`): the staples stay, and each signature needs an original replacement. This sketch uses Legal's first recommended replacement as the working default, marked *(default, pending Orb's pick)*. Every mechanic is described so it survives a re-skin: rules first, then names from Narrative screened by Legal, then looks from Art.

**Orb's answers in questionnaire 3 override the defaults below** (`docs/ep/vision.md`):
- **Transformations.**
  - Long transformations can be interrupted; the Tyrant's revisions are safe.
  - Timing is per fighter.
  - Forms are permanent except drain states.
  - Orb wants a replacement pitched for the multiplier stage, and wants transformations explored beyond the beast stage.
- **The Tyrant:**
  - the **bladed mantle**, a cape with blade hems used like a tail (Orb's later pick);
  - the "revision" joke;
  - three goons: bruiser, marksman, speedster;
  - while the goons fight, a human Tyrant snipes support shots and taunts.
- **Fusion** may be replaced by an Anti-hero power-up that keeps "sacrifice pride for power". **Swallow It** is the default. Full Circle is the optional merge, which Legal screens (`spec-wounds.md` §3).
- **The Protagonist's power stage is Overcommit**, a region loan (`spec-wounds.md` §3).
- **Relocation uses fragments**, not keystones, within Legal's conditions (`docs/legal/q3-screen.md` §a):
  - the planet sheds them when damaged, and they are contested;
  - a heavy hit scatters one;
  - the fold unlocks on the total mass held, never on a set count;
  - no search, no radar and no wish.
  The design is in `pitches.md` §4. It replaces section 4's keystones.
- **The Cyborg:**
  - a backup drive he catches and docks;
  - the weak point is the **Rail chip** (Orb's pick);
  - the food mechanic is **Press** (Orb's pick), with the rules in `spec-wounds.md` §3.
- **Planets:** earth-like and alien biomes, day, night and weather, and bigger for 2v2.
- **Damage** is location-based with no health bar (`damage-model.md`). Wherever this page says "HP", read "wear".

**Shared grammar.** Nothing here replaces stances or the director (Orb: keep both). Each system feeds the existing grammar:
- the ego meters in `economy.md` §4;
- the tiers that scale damage and collateral (`economy.md` §3);
- exchanges composed from stance and attack kind (`stance-matrix.md`).

---

## 1. Transformations: per-fighter tracks and their triggers

**Shared framework.**
- **Tracks and forms.** Each fighter has one or more *tracks*, each an ordered list of *forms*.
- **A form**, stored as data, has:
  - a trigger (a condition on the fighter's ego meter, the match state or time);
  - a tier (1 to 4), which sets damage, speed and collateral scaling;
  - a small moveset change (template and signature variants, authored by Combat);
  - an aura shape, markings, eyes and posture. There is no hair-colour change, and no fighter's hair reads as gold (Legal).
- **The transformation beat.** A 1 to 3 s set piece that craters the ground if it happens low, as today's tier-up does (`index.html:L697-701`). It does not heal.
- **A time floor.** Every track has one, so no fighter goes past about 3:00 without a form.
- **Pace:** top forms tend to arrive in act 3 or 4 (`economy.md` §7; bands in `balance-targets.md` §3).
- **Modding:** a new fighter is a new track file, not new code.

**The four tracks:**
- **The Protagonist.**
  - *Structure:* parallel tracks. Each advances when he spends **Respect**, a meter that fills when his challenger commits fully: transforms, fires a finisher, clashes at full ki, or keeps fighting below 25% HP (Legal's suggested framing).
  - *Choice:* the player chooses which track to push, so two matches can escalate differently.
  - *Working tracks:*
    - an ascension ladder of a few forms;
    - a **Push** state that trades health for speed, in our own colour and callout *(default, pending Orb's pick)*;
    - a **Runaway** stage. When anguish and charge both spike, he loses control: he becomes big and slow, and the player steers with a wobbling aim. It replaces the franchise's beast stage *(default, pending Orb's pick)*.
  - *Blink-strikes:* mid-attack teleports with their own tell, such as a stamped footfall or a ripple in the air, never a forehead pose.
  - *Final form:* it unlocks only after relocation (section 4).
- **The Anti-hero.**
  - *Structure:* two or three forms, triggered by **Pride**. Self-importance shows in regalia and posture.
  - *Identity cost:* each form raises his damage and pride gain, and weakens his guard. His DEFENSIVE multiplier worsens with each form, because pride won't block.
- **The Tyrant: the "revised" tyrant** *(default, pending Orb's pick)*.
  - *Structure:* ten or more numbered revisions of one body. Each changes one or two data values and one visible tell, and none of them echoes the franchise's form shapes.
  - *Triggers and beats:* **Wrath** triggers them. Each beat is under 1 s, comic and barked.
  - *Tiers:* revisions map three to a tier, so escalation stays readable.
  - *Why it works:* the joke is the idea of too many transformations, and a data-driven ladder suits modding.
  - *The final revision* adds unique abilities.
- **The Cyborg.**
  - *Structure:* a three-step track through **Hunger**: consume and molt; takeout and molt; dock the backup drive for the final form (section 5).

**Open questions for Orb**
1. Can a fighter be attacked while transforming? Options:
   - A. Yes, as a CHARGE INTERRUPT: a risky beat.
   - B. No, and the opponent gets a free recovery beat (a comic staple).
   - C. Only in the second half of the beat.
   - Recommendation: A for long transformations and B for the Tyrant's sub-second revisions.
2. Do forms end? For example, Push drains HP and ends when HP reaches a floor. Or is every form permanent for the match?
3. How many forms and tracks does the Protagonist have? The sketch has three tracks.
4. Once a trigger is met, does the player choose when to transform, or does it happen automatically?
5. Legal's replacements:
   - Runaway, or a storm-front trigger, for the beast stage?
   - Push for the multiplier stage?
   - The "revised" joke for the Tyrant?

## 2. Minions: the Tyrant's goons

**Sketch.**
- **The minion phase.** The Tyrant opens the match with two or three autonomous goons. They fight one at a time and tag in when one is knocked back; the others taunt from the side.
- **The goons.** Each is a simplified fighter: base form only, a smaller moveset, the same stance grammar, and a distinct role (a bruiser, a marksman, a speedster).
- **The Tyrant watches from range.** He can be attacked, but it costs the attacker, because he retreats to ESCAPE with a lock-on penalty. Attacking him also feeds his **Wrath**, which starts his revisions sooner. That is a real choice for the opponent: clear the goons, or provoke the boss.
- **HP budget.** The goons' HP counts toward the Tyrant's match budget. The minion phase should fill most of act 1 (about 1:00 to 2:00).
- **When the last goon falls**, the Tyrant steps in and the revisions begin.
- **His ranged tool** is a **surveyor line**: a ruler-straight thin beam that draws a cut across the land, with no disc and no finger pose *(default, pending Orb's pick)*.
- **His appendage attack** uses a **cable whip** in place of a tail *(default, pending Orb's pick; Legal rates the tail grey, default replace)*.
- **In 2v2,** goons count as the Tyrant's fighters, not extra team members.

**Open questions for Orb**
1. When a human plays the Tyrant, what do they control? Options:
   - A. The active goon directly.
   - B. The Tyrant, who gives the goons stance orders.
   - C. Both: goon early, Tyrant late.
   - Recommendation: A.
2. Two goons or three?
3. Can a fallen goon come back, for example summoned by a later revision?
4. Do goons cause collateral and count toward casualties?
5. Cable whip, cape or mechanical arm in place of the tail?

## 3. Fusion: optional, and deferred

**Status.** Legal rates the thrown fusion item a signature beat. It recommends that a true merge be a post-launch mod, or be dropped. So fusion is **deferred**. What ships in its place keeps the part Legal calls the best: the Anti-hero's choice between pride and help.

**Working default: Tandem** *(default, pending Orb's pick)*.
- **The offer.** At a trigger, such as the Anti-hero's second region breaking, the Protagonist offers help:
  - as his teammate in `team-2v2`;
  - as an AI cameo in 1v1, unless he is the opponent.
- **Refuse.** A **Pride** surge, and the win counts as "by his own strength" (a distinct result and bark set).
- **Accept.** For a short window (working value 30 s), the Protagonist fights beside him as an AI partner, and they share one finisher.
  - The cost is pride: the Anti-hero's meter drops to zero.
  - There is no merge and no shared body.

**Alternative for two players: Unison line.** Both channel into one beam. It needs two inputs at once, so two players can do it together as couch co-op.

**Open questions for Orb**
1. Tandem, Unison line, both, or something else?
2. A true fusion: a post-launch mod, or dropped (Legal's question 3)?
3. Can the Protagonist offer help to anyone else, or only the Anti-hero?

## 4. Relocating the fight: keystones (the Protagonist)

**Sketch** *(default, pending Orb's pick)*.
- **Keystones.** Three or five different objects are set in different biomes at procedural spots (section 6) and shown on the planet strip. They are not orbs, they come in no set of seven, and nothing grants a wish (Legal).
- **Gathering.** The Protagonist collects them by flying through them. The fight follows him everywhere (pillar 3), so gathering is a race under pressure. The opponent can't take them but can knock him away from them.
- **Relocation.** Once he holds them all, he can **fold the fight into a sealed arena** as a set piece: a small wrapped planetoid with no civilians. Both fighters go, or all four in 2v2.
- **Consequences:**
  - Collateral on the home planet stops.
  - The empty arena is the reason his final form is allowed. It unlocks there.
- **Counterplay against other fighters.** It hard-counters the Cyborg, who has no one left to consume. So relocation opens only after act 2 (about 4:00), and the Cyborg keeps his Hunger meter across the fold.
- **Legal's alternative: the long throw.** No items: he "carries" the opponent far off, to a barren biome.

**Open questions for Orb**
1. Keystones or the long throw? If keystones, three or five, and what are they?
2. Is relocation his win condition, or only his path to the final form?
3. Can an opponent scatter the keystones again?
4. What is the sealed arena: one fixed place or a procedural planetoid? Does any fighter gain or lose there?

## 5. Civilian consumption: the Cyborg

**Sketch.**
- **Consume (step 1).**
  - Near people, the Cyborg's charge input becomes *consuming*. It is vulnerable exactly as charging is: CHARGE INTERRUPT (`index.html:L435-438`).
  - Each civilian consumed adds a small multiplicative bonus to damage and regen, with a cap. It also counts as a casualty.
  - This is Narrative's "Savour" made mechanical: the collateral fantasy turned into a risk.
- **Molt, then Takeout (step 2)** *(default, pending Orb's pick)*.
  - He molts at a Hunger threshold.
  - In his second form he scoops civilians into an oversized bag. Opening it later gives sandwiches, each kind a small bonus such as speed, regen or guard.
  - The joke is bureaucratic, not a transformation beam.
  - Enough sandwiches trigger the next molt.
- **The backup drive (step 3)** *(default, pending Orb's pick)*.
  - His companion is a small backup drive that runs and hides around the planet. It reuses the hiding rules in reverse (`economy.md` §5).
  - Catching it is a chase. He **docks** it; he does not eat it. That gives the final form: the fastest fighter, blitzing through portals that spew monstrous sandwiches, with our own portal design and sound.
- **His weak point** *(default, pending Orb's pick)*.
  - A microchip behind a hatch that flips open.
  - The rest of his body regenerates slowly.
  - Heavies, guard breaks and finishers open the hatch, and only hits on the open chip deal damage that does not regenerate. Hitting it is the only way to finish him.
  - This rewards committing, and it works with the finisher rule (`open-questions.md`, G2).

**Counterplay for opponents:**
- keep the fight away from people;
- interrupt his consuming;
- Interpose, for a protector;
- relocate, for the Protagonist.

**Open questions for Orb**
1. How graphic is consuming? It sits between mature violence and humour. Options: off-screen with a comic cut, on screen but stylised, or in full. Legal notes it may affect store ratings, especially on mobile.
2. Takeout, or "Order up" (a sandwich barrage that hits civilians and enemies alike)?
3. Backup drive, or Legal's decoy option: whoever finds it first, the Cyborg or the opponent, gets the bonus?
4. The hatch chip, or a cartridge that pops out and scampers? Does the core get its own HUD bar (recommended: yes)?

## 6. Procedural planets

**Sketch.** Each match generates its wrapped planet from a seed, keeping today's model: a ring of columns with a heightfield, biomes, structures, civilians and cover (`index.html:L114-173`).
- **The generator.**
  - It lays out biome segments from a biome grammar with constraints.
  - It places settlements with populations, and places landmarks, keystone spots (section 4) and backup-drive hiding spots (section 5).
- **Fairness checks before a seed is accepted:**
  - cover within reach of every region;
  - at least one city and two villages;
  - no biome above a share cap;
  - measured-fair spawn pairs.
- **Determinism.** Same seed, same planet (ADR 0004).
- **Recipes and modding.** Biomes, settlement kits and generation rules are data "recipes" (Modding and Extensibility), so a mod can add a biome.
- **Testing.** QA measures every band over a fixed set of at least 20 seeded planets (`balance-targets.md` §6).
- **Performance.** Column and structure budgets come from Performance, for old laptops.
- **The sealed arena.** The relocation arena is a small generated planetoid with no population.

**Open questions for Orb**
1. Should planet size scale with the mode, for example larger for `team-2v2`?
2. Only earth-like worlds, or alien biomes too (crystal fields, lava seas)?
3. Can players type or share a planet seed?
4. Day and night, or weather that changes cover?
