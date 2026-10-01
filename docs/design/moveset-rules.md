# Moveset rules: specials, signatures, world changes, secrets, transformations and style

Owner: Game Design. Status: rulings for questionnaire 6 (`docs/ep/vision.md`). Date: 2026-09-30. Combat is designing the move-building grammar in parallel (the hand-made pieces plus a composed fill). This page sets the **game rules** that grammar serves. Names are placeholders, and every number is a starting value for QA.

**Holds from earlier rulings:**
- The player sets intent, weight, specials and when to transform; the director times everything (`stance-matrix.md` §4b).
- Transformations are respected: the fill can be stopped, the cinematic cannot (`spec-wounds.md` §8).
- 2 to 4 signatures a match, with a 120 s cooldown (`balance-targets.md` §13).

## 1. Specials

- **Loadout.** **3 specials** per fighter, chosen from that fighter's pool at character select. Each fighter has a default loadout.
- **Contextual variants.** Each special has variants, and the director picks one from context: biome and surface (air, ground, wall, water), altitude, distance, the opponent's stance and injuries, and the fighter's form and mood. It uses the same selector grammar as Combat's styles. The player never picks a variant.
- **The control** (ADR 0008). Hold the power trigger and press a face button for that slot. A funded press fires at the next exchange boundary, and an unfunded one is refused (`control-rules.md` §3). On the Simple layout the director picks the slot.
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

*Triggers, the Transform input and the look of each form: §10.*

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

This merges Narrative's character pitches (`docs/narrative/world-abilities.md`) with Game Design's mechanics.

**How it works.** Each fighter **picks one of their three at character select**, as part of the loadout. It stays once per match and permanent, with the same cost and counter-play as §3. Each option has a category, and if both fighters pick the same category, the second pick is greyed out at select.

| Fighter | Option | Category | What it does to the fight |
| :--- | :--- | :--- | :--- |
| **Protagonist** | **Proving Ground** (Narrative) | Land | He asks everyone to leave and presses a wide region (about 3,000 units across) into a flat arena. Its people relocate safely, so they are never casualties. Inside it there is no cover, no buildings and no sight blockers, and the escape odds count it as open ground. A fair, big fight |
| | **Shelter Ridge** (Narrative) | Land | A stone wall rises between the fight and the nearest town. That town takes no collateral for the rest of the match, and the wall is a strong sight blocker. The rival can only take the fight to another town |
| | **Heat Wave** (Game Design) | Climate | His blood heats the world. The sea partly boils into fog banks (sight blockers), and his heat cools half as fast. More power, and more of his own internal wear. It fits his heat-track transformation |
| **Anti-hero** | **The Dais** (Narrative) | Land | Terraced steps rise, and he stands on the top. The fighter higher on the Dais gets +0.05 on outcome rolls: height is rank. The rival must take the high ground from him |
| | **The Gallery** (Narrative) | Structure | Empty stone seats ring the fight, because he needs a witness. Inside it the mood gains ×1.5, and his Pride gains and losses ×1.5: dominance is witnessed, and so is humiliation. It cuts both ways |
| | **The Mirror** (Narrative) | Water | He freezes the sea into a flat sheet of ice. There is no underwater slowdown and no skipping, and slides go ×1.5 further on the ice, making huge knockback skids. A duelling floor that suits his fast shed forms |
| **Empress** | **Golden Hour** (Narrative) | Sky and light | She stops the sun low and gold. Long shadows break lock more easily for everyone, and her Wrath gains +25%, because she looks her best |
| | **The Palace** (Narrative) | Structure | A symmetrical palace complex rises, uninhabited. In its grounds her Encore guard hit +25% and her guard's tag-ins are faster. It is also a huge brunt and chain set piece with no casualties |
| | **Gravity Decree** (Game Design) | Orbit and gravity | Her fleet shifts the planet's gravity: launches ×1.3, airborne time ×1.5, impact wear ×0.7. It suits her ranged work |
| **Cyborg** | **Central Kitchen** (Narrative) | Structure | One district becomes a factory kitchen. There his Hunger gains ×2 and sandwiches appear by themselves. It speeds his evolution toward the final form |
| | **Harvest** (Narrative) | Land | He strips a biome bare into tidy rows. It loses all its cover, and standing on the rows feeds his Hunger slowly (+1 per second): feeding without people |
| | **The Delivery Network** (Narrative, merged with Game Design's Shortcut Network) | Pathways | A ring of permanent portal frames. Flying through one exits at another, his blitzes can come through them, and sandwiches spew out as hazards |

**Kept as notes** (not in Orb's three per fighter):
- Protagonist: Land Bridge, Break the Clouds.
- Anti-hero: Storm Crown, Scorched Plain, Crushing Presence.
- Empress: The Border, the Annexed Moon, Blockade.
- Cyborg: Floodgate, Wired World.

### 7.2 Transformations: the four refined, with one alternative each

| Fighter | Refined mechanic and its signature feel | Alternative |
| :--- | :--- | :--- |
| **Empress: a ladder** | *Bureaucratic escalation.* Revisions 1 to 8 are tiny jokes; revisions 9 to 12 are dramatic. Each real revision adds its **own signature** to her pool and grows her mantle, and refits patch her up. The feel: absurd, then terrifying | **Branching ladder:** at revisions 9 and 11 she picks one of two amendments, armour or artillery. The player chooses her build mid-fight |
| **Protagonist: a draining meter** | *Pushing past his limits.* The heat track (Heated, Simmering, Boiling) is his transformation, with glowing seams and a heartbeat. Its price is internal wear. The capstone is his final form, allowed only in the fold, where nobody else can be hurt. The feel: a man burning himself for the fight | **A ladder his rival feeds:** his forms unlock from Respect, which he earns when the rival gives everything. The opponent literally powers him up by fighting hard |
| **Anti-hero: shedding** | *Stripping down to raw power.* Three sheds, each a respected cinematic with no way back: **regalia** (armour off: guard weaker, +speed), **the front** (Drop the Act: hidden wear shows, +damage), **restraint** (no guard at all, top speed and damage). The feel: every shed is a humiliation he turns into power | **Pride ascension:** forms that raise his power while his Pride is high, and are *lost* when it crashes. It keeps the original "power and self-importance" idea: a higher ceiling, and a risk of falling |
| **Cyborg: evolution by consumption** | *Growing into the machine.* Wired (Hunger), then Kitchen (sandwich portals), then **Docked**: the final form, where his technology comes online. Only then does he **generate his hidden weapons**, which join his loadout as specials (Combat and Narrative design them). Before that, they show as dark, sparking ports: a visible promise. The feel: something unfinished, becoming whole. Narrative's line: "the kitchen opens and the order is produced" | **Assimilation:** he feeds on wreckage (destroyed structures) instead of people. It is less dark and ties him to destruction rather than civilians, if the tone ever needs it |

## 8. For Orb: third pass (merged into §9; read §9)

Orb liked two world changes per fighter. The transformations are the main mechanic for the Empress and the Protagonist, and the alternative for the Anti-hero and the Cyborg. Each world change below gets one line of fantasy and one line of mechanic. The rules in §3 hold throughout: once per match, permanent, a stoppable channel, a respected cinematic, and every collateral budget.

### 8.1 World changes: four more per fighter

**Protagonist.** *Liked: Heat Wave, Proving Ground.* **What they share:** he turns his inner fire outward, and remakes the world into a fair place where he can go all out without anyone getting hurt.

| Idea | Kind | Fantasy | Mechanic |
| :--- | :--- | :--- | :--- |
| **Magma Ring** | Escalation (arena plus heat) | The arena's rim cracks open into a moat of lava, and the fight is sealed in | A ring arena whose edge is a lava hazard. No collateral is possible inside, and his heat cools half as fast there |
| **High Summer** | Variation (Heat Wave) | The sun blazes, the seas steam and the forests are tinder | Fire spreads ×1.5 across the planet, and his stoking is 25% faster |
| **Evacuation Gale** | Protector twist | A hot wind sweeps the planet and carries everyone clear | Any district within 3,000 of the fight relocates at once, so collateral is near zero, and all clouds are swept away |
| **Training Peak** | Combo (land plus endurance) | A single towering peak rises for the two of them to fight up | A peak about 100 fighter heights tall: mountainside launches weigh ×2, and slides are possible from tier 2. At Simmering or above he gains +5 on rolls on its slopes |

**Anti-hero.** *Liked: Storm Crown, Scorched Plain.* **What they share:** domination by ruin. He strips the world of comfort, cover and light, so only strength counts, and he makes it a spectacle.

| Idea | Kind | Fantasy | Mechanic |
| :--- | :--- | :--- | :--- |
| **Thunderhead Throne** | Escalation (Storm Crown) | The storm gathers into one eye over him, and the lightning hunts his rival | Every 8 s a lightning strike falls on the rival's position, telegraphed 1 s ahead (hazard wear, capped at battered). His barrages gain +20% |
| **Salted Earth** | Variation (Scorched Plain) | The scorched land stays glassy and burning hot | Standing on the ground costs 1 wear per second to the legs (capped at battered). The fight goes airborne, where his barrages rule |
| **Blackout** | Variation (sky) | He swallows the light, and only the fighters' auras still shine | Lock-on range is capped at 2,000. Beyond it, attacks need the fighter to close in first (a pursuit flight) |
| **Tempest Wasteland** | Combo (storm plus scorch) | A smaller zone, burned bare with a storm locked above it | Both effects at full strength inside a 4,000-unit zone, with the rest of the planet untouched |

**Empress.** *Liked: Blockade, Golden Hour.* **What they share:** imperial staging. She rearranges the sky to frame herself and to dictate where the fight may happen.

| Idea | Kind | Fantasy | Mechanic |
| :--- | :--- | :--- | :--- |
| **Searchlights** | Escalation (Blockade) | Her fleet's searchlights sweep the planet and pin her rival in light | The rival can never break lock. She can, in the fleet's shadow |
| **Portrait Sky** | Variation (Golden Hour) | The whole sky becomes her portrait, watching | Each decisive exchange she wins adds +10 mood and +10 Wrath: applause |
| **Tariff Zone** | Bureaucratic | The lowlands are declared a taxed province | Below 30% of the ceiling, the rival's ki costs are +10%: a tariff on energy |
| **Gilded Eclipse** | Combo (Blockade plus Golden Hour) | The fleet eclipses the sun into a gold ring | Both effects at half strength |

**Cyborg.** *Liked: Wired World, Harvest.* **What they share:** industrial conversion. The world becomes infrastructure that feeds him, so he eats the planet rather than its people. This fits the assimilation mechanic below.

| Idea | Kind | Fantasy | Mechanic |
| :--- | :--- | :--- | :--- |
| **Scrap Tide** | Escalation (Harvest) | Wreckage everywhere animates and crawls toward him | Rubble within 3,000 converts to Hunger over time (+2 per ruined building), and the heaps shrink away |
| **Power Grid** | Variation (Wired World) | Pylons march across the land | On the grid, his specials cost 30% less ki, and the rival charges ×0.75 (interference) |
| **Assembly Line** | Combo | Conveyors carry harvested stock to him wherever he fights | A passive Hunger stream of +0.5 per second for the rest of the match |
| **Recycling Plant** | Final-form tie-in | A district becomes a plant that manufactures parts | After his final form, his hidden weapons recharge 50% faster |

### 8.2 Transformations: deeper

**Empress: escalating revisions** (main).
1. **Every revision adds one tell and never removes one:** a hat, a louder voice, one pixel taller, a second pair of eyes, a cape, the anger. So her silhouette is a visible history of the fight.
2. **Each real revision adds its signature moment:**
   - *9, Field Revision:* armour snaps on, and her decree line doubles into twin lines;
   - *10, Executive Revision:* the mantle unfurls into blade-wings with +50% reach;
   - *11, Council Revision:* the fleet's shadow passes over, and her volleys become barrages;
   - *12, Final Approved:* the sun dims, and her finisher is a "seal of approval".
3. **Refits show:** a patched region keeps a visible mend, and her voice lines list what changed, as the comedy.
4. **Her revision number is worn on her regalia:** tiny, in-world, and readable.

**Protagonist: heat, past his limits** (main).
1. **The stages, how they look and play, and their signature moments:**
   - *Heated:* seams glow at the joints and his footwork quickens; the moment is a stamp-and-ripple step;
   - *Simmering:* steam rises from his skin, his blows hit heavier and chain more; the moment is a steam burst that clears nearby dust;
   - *Boiling:* his skin cracks with light and he goes reckless and blitz-prone; the moment is a roar that knocks the rival back, a warning of the boil-over.
2. **Last push:** at Boiling on the brink, his finisher gets its own all-out variant, and his contest bonus stands.
3. **Limit Unbound,** the final form in the fold: heat is locked at Boiling with **no internal wear** for 20 s. It is his capstone.
4. **Heat memory:** each boil-over leaves a permanent glowing scar, and after two, his heat never cools below Heated. He runs hotter as the match goes on.

**Anti-hero: pride ascension** (the alternative, in full).
- **Three forms,** unlocked at Pride 60, 80 and 100 (working names Ascendant, Exalted and Sovereign). Each adds damage, speed and regalia, and each has a signature moment:
  - *Ascendant:* a contemptuous one-handed parry;
  - *Exalted:* a crown of barrage fire;
  - *Sovereign:* he finishes only by hand.
- **Pride** rises with dominance (clashes won, chains, finishers, witnessed by the mood) and falls with humblings (being parried, guard-broken, having a region broken).
- **The crash:** when Pride drops below 50, he loses **one** form in a humiliating, respected cinematic as his regalia shatters. He can climb back. The Proud front and the facade crack still apply.
- **Combined with Drop the Act,** which becomes **Abdicate:** at any form, he can voluntarily drop every form and his front at once to become unrestrained, once per match. The desperate card joins the pride ladder.

**Cyborg: assimilation** (the alternative, in full).
- **What he eats:** wreckage feeds his Hunger. Structures destroyed within 2,000 of him give Hunger by size. **Press** now clamps on rubble and reopens on sandwiches, so the gag stays.
- **Civilians are no longer his food.** That lightens the tone, and it retires the Cyborg's civilian floor and the Press-and-evacuation rules (`balance-targets.md` §4b).
- **The stages:**
  - *Wired* (first Hunger threshold): cables sprout, and he gets faster;
  - *Kitchen* (second threshold): portal frames open, with sandwich hazards;
  - *Docked* (the drive caught): the final form. **His technology comes online**, "the kitchen opens and the order is produced", and he **generates hidden weapons from what he ate**:
    - tower steel becomes a lance;
    - wrecked vehicles become a wheel-saw;
    - power lines become an arc whip.
    So every match's arsenal is different, and each weapon joins his loadout as a special.
- **Counter-play:** keep the fight in open country (less to eat), or fold into the proving ground, where he can still press loose fragments.

## 9. For Orb: the merged list (Game Design plus Narrative's pass 2)

This is one list per fighter. It merges §8 with Narrative's `docs/narrative/worlds-and-forms-pass-2.md`: Narrative's ideas get Game Design's mechanics, and the form stages take Narrative's names. **Read this section rather than §8.** All the §3 rules hold: once per match, permanent, a stoppable channel, a respected cinematic, and every budget.

### 9.1 World changes (Orb's two liked ones, plus six more each)

**Protagonist.** *Liked:* Heat Wave, Proving Ground. *The spirit:* his fire turned outward, making a world where he can go all out and nobody gets hurt.

| Idea | Source | Mechanic |
| :--- | :--- | :--- |
| **Beacon** | Narrative, with Game Design's Gale | A stone beacon rises, and every district within 5,000 of the fight relocates at once. Collateral is near zero for the match |
| **Hot Spring** | Narrative | Craters become springs and geysers. In a spring, second breath starts after 2 s instead of 4, for both fighters. Geysers periodically throw anyone above them upward |
| **Green Up** | Narrative | Growth follows him: scorched and burnt ground regrows canopy behind him, sight blockers return, fresh growth won't burn, and his anguish fades twice as fast |
| **Tide Wall** | Narrative | The sea stands up as a wall around the fight. Shore towns take no flood or water collateral, the wall blocks sight, and launched fighters skim along it |
| **Magma Ring** | Game Design | The arena's rim becomes a lava moat. No collateral is possible inside, and his heat cools half as fast there |
| **High Summer** | Game Design | Fire spreads ×1.5 across the planet, and he stokes 25% faster |

**Anti-hero.** *Liked:* Storm Crown, Scorched Plain. *The spirit:* domination by ruin and spectacle. The world loses its comforts, and everyone must watch.

| Idea | Source | Mechanic |
| :--- | :--- | :--- |
| **Obelisk of Names** | Narrative | While the obelisk stands, his Pride can't fall below 40. It can be destroyed as a heavy set piece, and if it falls his Pride drops by 20: a witness that can be turned against him |
| **The Long Silence** | Narrative | The world goes still: clouds stop drifting, no new dust or smoke clouds form (no lock breaks from dust), and the mood stops decaying, so tension holds |
| **The Circle** | Narrative | A circular chasm rings the fight, about 4,000 units across. Crossing it costs 20 ki (the world still wraps; leaving is only punished), bodies launched into it take a fall, and the ESCAPE slip chance is −0.15 inside |
| **The Watch Fire** | Narrative | A bonfire the whole world can see: every moment counts as witnessed (Pride gains and humblings ×1.5), and the ridge burns as a hazard |
| **Thunderhead Throne** | Game Design | Telegraphed lightning hunts the rival every 8 s. His barrages gain +20% |
| **Salted Earth** | Game Design | The glassy ground burns the legs (1 wear per second, capped at battered), so the fight goes airborne |

**Empress.** *Liked:* Blockade, Golden Hour. *The spirit:* imperial staging. She frames herself and dictates where the fight may happen.

| Idea | Source | Mechanic |
| :--- | :--- | :--- |
| **Grand Avenue** | Narrative | A straight avenue lined with statues. Her decree line gains +30% reach and damage along it, the statues are destructible sight blockers, and launches along it travel ×1.3 |
| **The Throne Hall** | Narrative | A roofed hall over the fight: the flight ceiling is capped at the hall's height, sky effects are cancelled inside (so it counters storms and blackouts), and her guard tag in without the salute delay |
| **Portrait Clouds** | Narrative, with Game Design's Portrait Sky | Each decisive exchange she wins adds +10 mood and +10 Wrath: the sky applauds |
| **Gilded Coast** | Narrative | Shores turn to gold. Beams fired along the coast ricochet once, knockback slides go ×1.5 on the gold, and there is no water skip there |
| **Searchlights** | Game Design | The rival can never break lock. She can, in the fleet's shadow |
| **Tariff Zone** | Game Design | Below 30% of the ceiling, the rival's ki costs are +10% |

**Cyborg.** *Liked:* Wired World, Harvest. *The spirit:* industrial conversion. He eats the planet, not its people, which fits assimilation.

| Idea | Source | Mechanic |
| :--- | :--- | :--- |
| **Drive-Thru** | Narrative | A ring road around the planet. He flies ×1.3 along it, and sandwich pickups spawn at its windows (Hunger) |
| **Kitchen Weather** | Narrative | Steam and oil: low steam blocks sight across the planet, slides go ×1.3 on the oiled ground, and fire spreads faster on it |
| **Pantry Mountain** | Narrative | A hollow warehouse mountain. Wreckage he absorbs beyond his molt thresholds is banked, and he can draw on it inside the mountain. The halls block sight |
| **The Stockpot** | Narrative | A sea simmers: being submerged or launched into it causes hazard wear, and steam fogs it. The fight is pushed onto land, where the wreckage is |
| **Scrap Tide** | Game Design | Rubble within 3,000 converts to Hunger over time, and the heaps shrink away |
| **Recycling Plant** | Game Design | After his final form, his hidden weapons recharge 50% faster |

### 9.2 Form stages, aligned to Narrative's names

| Fighter | Stages, each with its mechanic and signature moment (Narrative's defining moments are kept) |
| :--- | :--- |
| **Empress** (revisions) | **1, the form on file**, bored under the salute. **2, louder**. **4, the hat**, and the guard check whether to salute it. **6, smaller**, with the train too long. **9, Field Revision:** armour, and her decree line doubles into twin lines. **10, Council Revision:** the fleet's shadow, and her volleys become barrages. **11, Executive Revision:** the train becomes the weapon, as blade-wings with +50% reach. **12, Final Approved:** she smiles, and finishes with the "seal of approval". Each revision adds one tell and never removes one, and her revision number is worn on her regalia |
| **Protagonist** (Hot Blood) | **Heated:** seams glow, faster footwork, and he grins at his own steam. **Simmering:** heavier blows and more chains; he takes a hit to shelter a wall. **Boiling:** reckless and blitz-prone, a roar, hands shaking. **Boiled over:** the stagger and vent, and he looks round for who he might have hurt (heat memory: after two, he never cools below Heated). **Open Hand** (the reveal on the proving ground): locked at Boiling with no internal wear for 20 s, and the fragments spin out into a ring |
| **Anti-hero** (pride ascension) | *Folded to three forms by Orb's pick of the Heavy Crown (`spec-wounds.md` §3): Regalia at Pride 60, Sovereign at 80 and Apex at 95, with the Heavy Crown's numbers replacing the per-form bonuses.* As first written: five forms at Pride 55, 65, 75, 85 and 95, each adding +5% damage and +3% speed. **Poise:** the noise drops out, and he parries one-handed. **Regalia:** a piece forms, and he checks they saw. **Hierarchy:** he talks *about* the rival, and a crown of barrage fire. **Sovereign:** he stands above the fight, with the height bonus of the Dais. **Apex:** he finishes only by hand, with a terrible smile. **The crash** (Pride below 50): he loses one form as the regalia flakes away, and he can climb back. **Abdicate** (Drop the Act): he sheds every form for unrestrained, once per match |
| **Cyborg** (assimilation) | **Base:** the bow. **Scavenger** (first Hunger threshold): a girder bolted onto his arm, harder and faster. **Kitchen** (second threshold): the table set mid-fight, portal frames and sandwich hazards. **Assembled** (third threshold): a building block worn as a shawl, wreckage armour taking incoming wear ×0.85, and the hunt for the drive begins. **Online** (the drive docked): lights come on like a restaurant opening, the tech is online, and hidden weapons appear on trays, generated from what he ate |

## 10. For Orb: transformations you can't miss

Orb's direction: a bigger visual change per form, and clearer triggers. The rules in §5 and `spec-wounds.md` §8 hold: a fill the rival can stop, then a respected cinematic, with the player choosing when to transform. The looks below are Game Design's brief. Art and Narrative refine them, and Legal's screen notes hold throughout (§10.7).

### 10.1 One trigger, the same for every fighter

Players learn it once.

1. **Ready.** When a form becomes available, three cues fire together:
   - *on the body:* the fighter's own ready tell (below), followed by a slow pulse for as long as the form stays ready;
   - *in sound and feel:* a short sting unique to the fighter, a rumble pulse on controllers, and a one-line bark (text with a grunt);
   - *on the HUD:* one "ready" icon beside the fighter's portrait, showing the Transform button.
2. **The input: hold both triggers for 0.5 s** (ADR 0008; the chord rules are in `control-rules.md` §3). It is the same for every fighter, and on touch the ready icon is the button. The hold prevents accidents. A hold made mid-exchange goes in at the next exchange boundary.
3. **Losing it.** Where the rival can still take the form away (for example by draining Pride), the pulse flickers when the form is close to being lost.
4. **The change lands in one beat.** The 2 to 3 s cinematic ends on a held pose that shows the new form clearly, then play resumes.
5. **Both players see both fighters' cues,** and the AI uses the same ones. The rival's ready pulse is your signal to press them.

### 10.2 A bigger change per form: the rule for Art

Every form changes at least three of the following, always including the first two:
- the silhouette at 40 px: a new part, or a big change of size or shape;
- the posture and the idle;
- the aura's shape;
- the markings, or the mask's lit sigil;
- the colour mass, which is the far read at 12 px.

The Empress's joke revisions stay small on purpose, because they are the comedy.

### 10.3 The Anti-hero (the first real fighter): pride ascension

- **The fill:** Pride reaches 60, 80 and 95: three forms, since Orb's pick of the Heavy Crown (`spec-wounds.md` §3). Humbling him drains it. In the table below, **Regalia** now takes the Poise and Regalia rows together, **Sovereign** takes the Hierarchy and Sovereign rows, and **Apex** is unchanged.
- **The ready tell:** he rises out of his crouch for a beat and looks straight at the rival. The slash sigil on his mask burns brighter, and his violet ring aura snaps tight at his feet. The sting is a single low tone.
- **The forms.** Art's Coil today adds one spine plate per form, which is too small a change.

| Form | Silhouette | Posture and aura |
| :--- | :--- | :--- |
| **Poise** (55) | Forearm guards lock on, and the first spine plates flare | The crouch drops lower and goes perfectly still. The ring aura stops flickering |
| **Regalia** (65) | A stiff, low collar rises behind his head, round-tipped | He checks that they saw. The ring doubles |
| **Hierarchy** (75) | The spine plates fan into a short, round-tipped crest, and the sash drops into a floor-length panel | He stands upright for the first time, and a slow crown of barrage shards circles him |
| **Sovereign** (85) | The plates lift off and hang behind him in a fixed arc | His idle floats, feet never quite touching the ground. His palette inverts within its lane (a light body with dark marks), which reads from across the planet |
| **Apex** (95) | The guards fall away, and lit lines run down his bare forearms | Utterly still, and the air around him warps |

- **The crash** (Pride below 50): the last form's pieces flake off as ash, and his posture drops back one step.
- **Abdicate** (Drop the Act): every piece bursts off at once, the sigil dims to a thin line, and he fights feral in the crouch. It keeps its own input (`stance-matrix.md` R9).
- **His revealed signature (Lean slot G4).**
  - *The trigger* is the first time he takes Apex. The reveal is the held pose at the end of the Apex cinematic, and its name shows on screen.
  - *Why not Abdicate:* Abdicate already has its own form-tied signature (G3), and a form-tied signature always wins over a revealed one (§2), so a reveal there would never be seen.
  - Once revealed, it replaces his place signatures for the rest of the match, including after a crash below Apex.
  - *QA band:* he reveals it in 25 to 50% of his matches. If it falls under 25%, the trigger moves down to Sovereign.
  - At Lean it is his only revealed signature. A second, from a rivalry thread (§2), can come as his moveset grows.

### 10.4 The Protagonist: heat, then Open Hand

- **Heat stages are power states,** driven by his stoke hold, so his own input is their trigger. Each stage crossing gets a 0.3 s beat that doesn't pause play:
  - *Heated:* the seams at his joints light, and a stamp sends a ripple out;
  - *Simmering:* steam vents from the seams on his limbs, and a burst clears nearby dust;
  - *Boiling:* light cracks spread along his limbs and steam jets out. He hunches forward with his hands shaking, and roars.
- **The boil-over warning:** the Boiling cracks strobe for a second before heat reaches 100.
- **Open Hand,** the transformation:
  - *The fill* is the fold.
  - *The ready tell:* the ring of fragments he has gathered closes and hums in time with his seams. Hold Transform.
  - *The change* is the reverse of Boiling. The steam stops dead, and the cracks close into clean, calm markings across his limbs and mask. He stands upright with one open hand forward, and the fragments spin out into a ring on the ground.

### 10.5 The Empress: revisions

- **Joke revisions** (1, 2, 4 and 6) stay automatic and small.
- **Real revisions** (9 to 12):
  - *The fill* is Wrath, then the 8 s processing that her guard reads out in three protocol gestures (no text).
  - *The ready tell:* the third gesture is held, and the revision number worn on her regalia turns over to the next number and lights. The sting is a deep chime. Hold Transform.
- **The changes,** each one large:
  - *Field Revision:* armour snaps on and bulks out her silhouette, and her decree line doubles;
  - *Council Revision:* the fleet's shadow falls across the screen and stays over her, and her volleys become barrages;
  - *Executive Revision:* her train rises into blade-wings, the biggest silhouette change on the roster;
  - *Final Approved:* the sun dims, her regalia is complete, and she smiles.

### 10.6 The Cyborg: assimilation

- **The fill:** Hunger thresholds, fed by wreckage. For the final form, it is catching the backup drive.
- **The ready tell:** an order-up bell rings, and a lamp on his chest lights. With the drive in hand, the dock port on his back opens and glows instead. Hold Transform.
- **The changes:**
  - *Scavenger:* a girder bolted along one arm;
  - *Kitchen:* portal frames mounted on his shoulders;
  - *Assembled:* a whole building block worn as a shawl, which doubles his mass on screen;
  - *Online:* lights come on across his body, and trays fold out carrying the weapons generated from what he ate.

### 10.7 What the looks avoid (Legal's notes stay)

- No form changes hair colour or hair shape, and nothing goes golden, white, or spiky and upswept.
- No body-wide glow. The Protagonist's heat stays on his limbs, seams and steam, and is never red or gold.
- No form names built on "Super", "Ultra" or "God", or on colours, and no "x" multiplier call-outs.
- No tall, pointed, flame-shaped aura or crest above the head. The Anti-hero's shapes are round-tipped.
- The Anti-hero's regalia is his own: no shoulder-pad armour with white gloves and boots.
- Every look goes through Legal's screen before it is final.

### 10.8 What the body does in each version (for Animation)

The sim plays a transformation in one of three versions (`spec-wounds.md` §8b). All three use the same three beats, and the effect in play is the same.

**The staging rule.** The body draws **in**, snaps **once**, and then holds still. The tell is the silhouette, the posture and the aura's shape. There is no scream, no fists at the hips with the feet apart, no flame flaring upward, no crackling lightning, and no hair change.

| Beat | Full (3 s pause) | Short (1.5 s pause) | Live (0.8 s, no pause) |
| :--- | :--- | :--- | :--- |
| **The gather** | 60 ticks. He compresses: knees bend, limbs come to the centreline, head down. The aura is pulled in to his sigil, and the sound drops away | 24 ticks. The same compression, faster | 10 ticks. A flinch inward |
| **The break** | 30 ticks. One snap to full extension. The new parts lock on in this frame, and the silhouette changes here and nowhere else | 18 ticks. The snap and the lock | 14 ticks. The snap, with the burst that pushes the rival back |
| **The settle** | 90 ticks. He holds the new pose for 45, turns to face the rival, and says his line | 48 ticks. He holds for 30, then turns. A grunt, no line | 24 ticks. The upper body holds the pose while he is already drifting back into the fight |

**What must read at fight distance.**
1. The silhouette change lands on the break and is visible at 40 px.
2. The posture after is different from the posture before: he gathers low and settles tall, or the reverse.
3. The aura changes shape, and the colour mass shifts. That is the read at 12 px, when the body is too small to see.

**Camera and VFX, one line each.**

| Beat | Camera | VFX |
| :--- | :--- | :--- |
| Gather | Full: push in to a close-up. Short: half the push. Live: stay on the fight framing | The aura and loose dust are drawn inward to the sigil, and the light around him dims. Nothing flares outward |
| Break | Full: one hard cut to a low, wide angle with the whole silhouette against the sky. Short: a snap zoom out. Live: a 6-tick punch-in with a light shake | One ring leaves the body, the aura swaps to its new shape in a single frame, and the ground cracks if he is on it. The flash is in his own colour, never gold or white |
| Settle | Full: hold on the pose, then pull back until both fighters are framed. Short: pull straight back. Live: already there | The new aura holds steady, dust settles, and the form's own trail begins |

**The placeholders now.** KAI and VORR have no new art, so they use what exists:
- *the gather* is the charge pose, compressed;
- *the break* is the existing power-up burst and its crater;
- *the settle* is a taller idle for each tier.

What reads is the 10% size step, the aura's shape for the tier and the crater.

**The Anti-hero's Pride forms later.** His gather is the opposite of a crouch, because the crouch is his normal stance.
- *The gather:* he rises out of the crouch, lifts his chin and goes still, one hand palm-up as if being dressed.
- *The break:* one dismissive flick of that hand. The regalia locks on from behind with a single clack: the collar and guards at Regalia, and the crest and floating plates at Sovereign.
- *The settle:* he checks that the rival saw, then that the camera did.
- *Apex* inverts it: at the break the guards fall away and the sound cuts out, and the settle is utter stillness.
- *The live version* is only the flick and the lock.

He is masked, so there is no face to scream with. His sigil brightens instead.
