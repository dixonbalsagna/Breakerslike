# Design pillars

Owner: Game Design. Status: P0, draft for EP review. Date: 2026-09-29.

The seven pillars decide what Meridian (working title) is. Every feature, tuning change and cut is judged against them. For each pillar this page gives what it means in play, how we test it, what breaks it (anti-examples), and where the prototype stands today.

**Sources.** `index.html:L123` is a line of `prototype/index.html` at commit `7233c96`. "QA §n" is a section of `qa/baseline-p0.md` (8,000 seeded AI-vs-AI matches). Numeric bands live in `balance-targets.md`, so they are set in one place; this page names the metric and points there. The hero is called KAI in the prototype and in QA's data. KAI is a placeholder that will not ship (Legal RL-002), so rules text says "the hero".

**Orb's vision** (`docs/ep/vision.md`) sets the frame for every pillar:
- **The match** is the finale of a season-long rivalry: 5 minutes or more, felt as about 7. It is choreographed, destructive and funny, never two fighters jabbing from opposite corners.
- **The roster** is four fighters: the Protagonist, the Anti-hero, the Galactic Tyrant and the Demon Cyborg. Their systems are in `systems-sketch.md`.
- **The world:** planets are procedural, shown 2.5D side-on.
- **The tone** is mature destruction with a humorous voice. The homage follows "staples yes, signatures no".

The prototype's two fighters are placeholders for that roster.

## How to use the pillars

- **A proposal names the pillars it serves.** A proposal that weakens a pillar says so, and why the trade is worth it. The EP rules on it.
- **Test with numbers and with people.** Each pillar has an automated check that QA's harness can run, and a playtest question. A pillar passes only when both agree.
- **Tie-breaks when pillars pull apart:**
  1. The player's intent beats the director's flourish. A window the player earned is never taken away for spectacle.
  2. Legibility beats depth. A rule that only works if the player reads the wiki is a bug (charter anti-goal).
  3. Systems beat scripts. If a moment can emerge, do not author it as a cutscene.
  4. Originality beats homage. Anything the originality rules exclude is out, however well it fits (`docs/legal/originality-rules.md`).

## At a glance

| # | Pillar | Prototype today | Main evidence |
| :--- | :--- | :--- | :--- |
| 1 | The planet is the arena | **At risk.** The wrap is solid, but fights collapse onto the ocean | Ocean holds 64.6% of fight time on 26% of the planet (QA §6) |
| 2 | Stances, not combos | **At risk.** DEFENSIVE looks dominant for a human, and the attacker's stance barely matters | `stance-matrix.md`, dominance section |
| 3 | Never out of range | **Holds.** Every attack closes the gap; escape is a gamble | Rush time `clamp(dist/2600, 0.18, 0.65)` (`index.html:L420`); pursuits slip away 50% of the time (QA §7) |
| 4 | Power has weight | **Holds, unmeasured by tier.** Damage grows with tier; per-tier collateral has not been measured yet | `economy.md`, collateral scaling |
| 5 | Characters are personalities | **Broken on balance.** The identity reads, but it decides the winner | VORR wins 58.2% (QA §2); villain mirror loses 64% of civilians, hero mirror 32% (QA §4) |
| 6 | Fights tell stories | **At risk.** Chains and clashes are common; ambush almost never happens | 0.061 ambush attacks per match (QA §8) |
| 7 | Signatures adapt | **At risk.** Variants exist but one dominates | HORIZON CLEAVE is 69% of beams; FIRESTORM and GLASS TRENCH are 1% each (QA §6) |

---

## 1. The planet is the arena

The world wraps. There are no walls, no corners and no side of the screen to be cornered on. Fly either way and you loop the planet.

**In play**
- The planet is a ring 9,600 units around, stored as 1,200 columns of 8 units (`index.html:L115`), with eleven biome segments from ocean to mountains (`index.html:L118`). Flying either way loops it. The seam at 0/9,600 has no meaning in play. In the game, every match generates its own wrapped planet from a seed (`systems-sketch.md` §6), and every one keeps the ring.
- Space is never a trap. Nobody gets pinned against an edge, so position is about *where* you fight, not how close you are to a wall.
- Where you fight is a strategic choice, because each biome changes what happens:
  - The ocean, forest and mountains give cover for hiding.
  - Each biome picks its own signature variant.
  - Population density feeds menace and anguish.
  - Buildings and mountainsides open launch options.
- The camera keeps both fighters readable at any separation up to half the planet (Camera's done-when).

**How we test it**
- *Seam:* QA's seam suite passes (`qa/tests/seam.test.js`): no NaN, no jump, shortest-arc movement, and the camera takes the short way round. This is the P1 exit criterion "no visual or logic pop at the seam at any separation".
- *Location spread:* each biome's share of fight time and of signature beams, compared with its share of the planet (QA §6). The band is in `balance-targets.md`, "Location and signature variety".
- *Playtest:*
  - "Did you ever feel cornered?" The answer should be no.
  - "Name a place you would rather fight in, and why." The answer should name a biome and a reason.

**Anti-examples**
- An invisible wall, a ring-out, or a stage edge.
- A seam that behaves differently from anywhere else: a camera pop, a lost lock-on, a missed hit.
- Fights that always end up in one biome, so the planet shrinks to one arena. This is the prototype today: 64.6% of fight time over the ocean (QA §6).
- Swapping the planet for small, bounded arenas in any mode. The Protagonist's sealed arena is a small *wrapped* planetoid, so it keeps the rule.

**Prototype today.** The wrap works: 76% of matches cross the seam, and the largest single-step move is 186 units against a 300-unit alarm (QA §10). Location variety fails, because the hero AI's lure and cover-seeking carry fights to the western ocean (QA §6, finding 3). The city holds 5.4% of fight time, the forest 1.2% and the desert 1.1%. The fix belongs to Encounter Systems (AI behaviour); the target is set in `balance-targets.md`.

---

## 2. Stances, not combos

The player chooses intent: aggressive, defensive, evasive or escape. A procedural director choreographs the exchange that results.

**In play**
- **Intent, not inputs.** The player picks a stance (AGGRESSIVE, DEFENSIVE, EVASIVE, ESCAPE), an attack kind (light, heavy, signature) and whether to charge. There are no input strings or motion inputs.
- **The director composes the exchange.** It turns attack kind against defender stance into an authored exchange: gap-close, strikes, launch and windows (`index.html:L418-622`).
- **Stance is a commitment read at one moment.** The defender's stance when the attack starts picks the template (`index.html:L410-421`). Holding a stance is a prediction of what the opponent will throw next.
- **Where skill lives:**
  - reads: which stance to hold, and which attack to throw into the opponent's stance;
  - timing: the parry window during a wind-up and the chain window after a hit;
  - resource timing: ki for a signature, or ki held back to meet a beam with a clash;
  - position: biome, cover and population.
- **Every stance has a job, a counter and a cost** (`stance-matrix.md`):
  - AGGRESSIVE presses and trades.
  - DEFENSIVE absorbs and punishes.
  - EVASIVE reads and slips.
  - ESCAPE disengages, hides, recovers and ambushes.

**How we test it**
- *Comprehension:* after two matches, a new player can explain what each stance is for (charter done-when). QA or the playtest lead runs a scripted interview.
- *No dominant stance:* in a mirror with identical fighters, no fixed stance beats the standard stance mix above the band in `balance-targets.md`, "Stance balance", and every stance loses to at least one other.
- *Authored variety:* every stance pairing has at least two authored outcomes, and each outcome is visible in the director feed (P2 exit; see `stance-matrix.md`).

**Anti-examples**
- Input strings, motion inputs or combo trees that the director merely plays back.
- One stance that is right against everything. The prototype's DEFENSIVE is the candidate: it takes 0.38× damage, and nothing in the rules makes a DEFENSIVE fighter's own attacks weaker or slower (`stance-matrix.md`).
- A choice that never matters. Inside an exchange today, the attacker's own stance changes one read chance and the damage the attacker takes from counters, and nothing else (`index.html:L458`, `L326`).
- Outcomes that are pure dice, with no read behind them.
- The director overriding player intent where a window should exist (Encounter Systems' anti-goal).

**Orb decided:** keep stances and the fight director (`docs/ep/vision.md`). Transformations and each fighter's systems add moves and change numbers, but never this grammar (`stance-matrix.md`).

---

## 3. Never out of range

Distance never blocks drama. Attacks always close the gap, and the escape stance is a real gamble rather than a range check.

**In play**
- **Any attack from any distance starts an exchange.** The director flies the attacker in over 0.18 to 0.65 s, scaled by distance (`index.html:L420`). Nothing whiffs because of distance.
- **Only a hidden target is out of reach.** Attacking one costs 2 ki and loses the lock-on (`index.html:L397-401`). Hiding needs the ESCAPE stance, cover and distance, so it is a state the player chose and can lose, not a range check.
- **Distance tilts a gamble but never settles it:**
  - Fleeing a melee attack from ESCAPE works about half the time. Being more than 800 units away adds 12 points (`index.html:L441`).
  - A signature fired from inside 500 units adds 30 points to its hit chance against ESCAPE (`index.html:L589`).
- **Movement is for position, not spacing:** which biome, which cover, how far from people.

**How we test it**
- *No whiffs:* every attack on a target that is not hidden produces an exchange with contact or an authored evasion. A harness check counts exchanges with no strike, no evasion and no clash; the count must be zero.
- *Escape is a gamble:* the rate at which pursuits slip away and beams are escaped stays inside the band in `balance-targets.md`, "Stance balance". Today 50% of pursuits slip away (1,063 of 2,122) and 28% of beams against ESCAPE are escaped (QA §7).
- *Playtest:* "Did an attack ever miss because you were too far away?" The answer should be no.

**Anti-examples**
- Projectiles that miss by distance. Footsies and spacing as the core skill.
- Escape that is a pure range check ("far enough is safe").
- A zoning character who wins by never letting the opponent close.
- Hiding that makes someone untouchable indefinitely, with no way for the hunter to find them.

**Prototype today.** The pillar holds. One defect bends it: the signature's hit chance against ESCAPE falls as the attacker's tier rises, the opposite of every other tier term (`prototype-bugs.md`, GD-B01).

---

## 4. Power has weight

Terrain, buildings and civilians are damaged by fights, and damage escalates with power tier.

**In play**
- **Every heavy event leaves a mark.** Blows, launches, beams, clashes and power-ups crater terrain, damage buildings and cost civilians. A fighter launched into a building damages it (`index.html:L727-740`).
- **Damage grows with tier.** From tier 1 to tier 4:
  - a beam explosion's area damage goes from 240 to 570 (`130 + 110·tier`, `index.html:L307`);
  - a beam's damage along its path goes from 185 to 410 (`110 + 75·tier`, `index.html:L653`);
  - launch force rises 48% (`1 + 0.16·(tier−1)`, `index.html:L378`).
- **Powering up near the ground scars it.** A tier-up within 140 units of the ground craters the terrain and damages the area; one in the air does not (`index.html:L697-701`). Where you power up is a choice.
- **The damage stays.** At the KO, the planet shows the history of the fight.

**How we test it**
- *Escalation reads:* collateral per minute rises with tier, and a tier-4 event is visibly bigger than a tier-1 event (P3 exit, "escalation reads clearly across tiers").
- *Low tiers do not end the world:* collateral while both fighters are at tier 1 or 2 stays under the cap in `balance-targets.md`, "Collateral" (P3 exit, "no fight destroys the planet at low tiers").
- *Water stays honest:* craters never flood inland. Water exists only where the base terrain is below sea level (`index.html:L179`; World's done-when).
- *Playtest:* "Could you tell each fighter's tier from the damage around them?"

**Anti-examples**
- Cosmetic destruction that feeds no system.
- A tier-1 fight that levels the city in under a minute.
- A tier-up that changes a number and nothing on screen.
- A numeric "power level" readout. It is also barred by the originality rules; tiers show as bars or pips.

**Prototype today.** The scaling exists, but how much collateral each tier causes has not been measured. The baseline reports collateral per match (38.7% of civilians and 14.1 of 47 structures, QA §4), not per tier. `economy.md` adds the per-tier measurement, and `balance-targets.md` sets its band.

---

## 5. Characters are personalities

The hero and the villain do different things to the world. The hero is pressured by collateral damage (anguish). The villain feeds on it (menace).

**For the roster.** Each of Orb's four fighters has its own relationship to the world and its own visible ego meter (`economy.md` §4.2):
- The Protagonist wrecks through fixation, then moves the fight somewhere empty.
- The Anti-hero is proud and indifferent.
- The Tyrant is cruel for show.
- The Cyborg consumes people.

The prototype's menace and anguish, below, are the first working example.

**In play**
- **The villain feeds.** Every casualty the villain causes raises menace (+0.9) and power (+0.09) (`index.html:L272`). Menace adds up to +25% damage (`index.html:L322`), up to +3 ki per second of regen (`index.html:L759`) and up to +8 on the beam-clash roll (`index.html:L625`). VORR wants the fight where people are.
- **The hero is pressured.** Every casualty raises the hero's anguish: +0.5 if the villain caused it, +0.9 if the hero did (`index.html:L274`). Anguish cuts ki regen by up to 2.5 per second (`index.html:L759`) and fades at 0.6 per second (`index.html:L760`). The hero wants the fight away from people.
- **The director plays each personality.** The launch planner steers the hero's launches away from populated ground and the villain's toward it (`index.html:L371`). Personality also shows in behaviour and barks (Narrative).
- **Asymmetry colours a match; it never decides one.** Every pairing sits inside the win-rate band.

**How we test it**
- *Balance:* every pairing's win rate is inside the band in `balance-targets.md`, "Win rate", with slot and spawn effects separated as QA does (QA §2b).
- *Personality shows in the world:* in mirrors, the villain pair destroys far more than the hero pair (64.2% against 32.2% of civilians, QA §4). The gap must stay clearly visible after any balance fix.
- *Personality shows in the feed:* every personality term is visible in the director's debug feed (Narrative's and Encounter Systems' done-when).
- *Playtest:* "Describe each fighter in one sentence after one match" (Narrative's done-when).

**Anti-examples**
- Personality that lives only in dialogue or colour.
- An asymmetry that wins the matchup by itself. This is the prototype today (VORR 58.2%).
- Pressure with no counterplay. The hero must always be able to act on anguish: lure the fight away, end it faster, or protect.
- Two fighters whose rules are identical under different skins.

**Prototype today.** The identity reads, and it decides the winner. The diagnosis, and the lessons for the roster, are in `balance-targets.md` §9.

---

## 6. Fights tell stories

Hiding to recover, ambushing from cover, comebacks, chains and clashes emerge from systems, not scripts.

**In play**
- **A fight has an arc: a season finale in four acts** across 5 to 7 minutes (`economy.md` §7):
  - the meeting, in base forms;
  - escalation through transformations and collateral;
  - the turn: top forms, relocation, comebacks;
  - the finale: final forms, finishers and the biggest clashes.
- **Losing has a way back.** You can go to ground:
  - Being hidden in cover restores 40 HP and 25 extra ki per second (`index.html:L758`, `L762`).
  - Striking after 1.8 s or more in cover gives an ambush worth ×1.5 damage (`index.html:L324`, `L402-403`, `L687`).
- **Momentum can swing:**
  - chains of up to five linked hits (`index.html:L548-557`);
  - parries timed in the wind-up (`index.html:L525-532`);
  - heavy and beam clashes that either side can win (`index.html:L502-506`, `L623-641`).
- **The feed tells the story.** Every beat can be explained in the director feed, so a match can be retold.

**How we test it**
- *Beats happen:* the rate per match of hides, ambushes, comebacks, lead changes, clashes, parries and chains stays inside `balance-targets.md`, "Story beats". A comeback is a win by a fighter who was at or below 25% HP.
- *Nothing is scripted:* no cutscene or quick-time event decides an outcome.
- *Playtest:* "Tell the story of your last match in three sentences." Stories should name a turn, such as a hide, a clash or a comeback, not only damage traded.

**Anti-examples**
- Scripted sequences that play the same every time.
- Mechanics that exist but never fire. The prototype's ambush fires 0.061 times a match, after about one hide in ten (QA §8).
- Invisible rubber-banding: a bonus for whoever is behind, with no cue on screen. The hero's comeback bonus (up to +50% damage at low HP, `index.html:L322`) needs a visible cue.
- Dead air: long stretches where nothing can happen. One example is a hunt for a hidden fighter with no way to find them.

**Prototype today.** Chains and clashes are frequent: 3.8 chains a match, and 40% of signatures meet a clash (QA §6, §8). Hiding is occasional: 0.63 hides a match. Ambush barely exists: 0.061 a match. `economy.md` covers the hiding and ambush levers.

---

## 7. Signatures adapt

One signature move plays out differently by biome, altitude and the defender's stance.

**In play**
- **One signature per fighter, many variants.** The biome under the defender picks the variant (`index.html:L584`):
  - HORIZON CLEAVE over the ocean;
  - BOULEVARD RAZE over the city and villages;
  - FIRESTORM in the forest;
  - RIDGE BORE in the mountains;
  - GLASS TRENCH in the desert;
  - MERIDIAN SCAR on the plains.
- **The defender's stance picks the outcome:** CLASH, GUARD, DODGE, HIT or ESCAPE (`index.html:L586-590`).
- **The land keeps the mark.** A beam carves along its path, and each variant marks it differently: deeper craters on RIDGE BORE, fire on FIRESTORM, glassing on GLASS TRENCH (`index.html:L646-656`).
- **Planned, not built:** altitude and collateral state also shape the variant (Combat's variant matrix).
- **Names follow our own pattern:** a place or material, then what the beam does to the land. They are never franchise names (originality rules).

**How we test it**
- *Variety:* no variant is above the cap, and every variant appears in AI play (`balance-targets.md`, "Location and signature variety").
- *Context changes the play:* no signature plays the same way in two contexts (P4 exit; Combat's done-when).
- *Playtest:* with the sound off, a viewer can name the place from the beam alone (VFX's done-when).

**Anti-examples**
- A palette swap as the only difference between variants.
- Fights that stay in one biome, so one variant is all anyone sees. This is the prototype today: HORIZON CLEAVE is 69% of beams (QA §6).
- An outcome that ignores the defender's choice.
- A name, pose or sound that echoes a franchise move (originality rules, "Attack-name patterns" and "Iconic poses").

**Prototype today.** Six variants exist, but beams follow the fight to the ocean. The outcome logic works, and clashes are the most common outcome (40.4% of beams, QA §6). Two defects affect variants and outcomes: CC-012, where FIRESTORM's fire spreads along the whole path, and GD-B01, the inverted tier term against ESCAPE. Both are listed in `prototype-bugs.md`.
