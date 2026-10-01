# Rule of cool: the rationed feature list

Owner: Game Design. This turns Orb's picks from questionnaires 11 and 12 (`docs/ep/vision.md`) into a list the directors can build from: one row per feature, with its trigger, tier gate, frequency, cost in play, owners and build order. Legal has screened the list: its constraints are in §3b, and its stacking rule is in §1. Every name is a working label, and every number is a proposal for data.

Orb has picked all three items from `pitches.md` §8: the two-level impact treatment, one last signature for the last stand, and taunts that feed meters. Orb also accepted Legal's stacking rule.

## 1. The rationing rules

Orb set spectacle at **4 of 10** and the top-tier finisher at **7 of 10**.

1. **Planet-scale launches are rare.** Orbit, through the mountain and round the world share a budget of **3 a match**, with each kind at most once per fighter.
2. **One big live set piece every 20 s** at most. This covers the clashes, the beam answers and the planet-scale launches. A second one inside 20 s plays as its ordinary version.
3. **Pauses** stay within 2 s a minute (`spec-wounds.md` §8b). Nothing in this list pauses the fight.
4. **The tier gates escalation** (pillar 4). Below tier 3 the world doesn't react and nothing leaves the atmosphere.
5. **A finisher at 7 of 10** wrecks a district at tier 4 and a block at tiers 1 and 2. It never scars the planet. The beam cap by tier still holds (`balance-targets.md` §15).
6. **Nothing here is the only cue for a gameplay event.** On old laptops and phones every effect has a reduced version, and the sim is the same on every device.
7. **Everything is deterministic.** Where "the game picks", it scores candidates with no random draw beyond the sim's seeded keys.
8. **No teleports.** They stay on hold.
9. **The stacking rule** (Legal). A known franchise's power-up scene is a stack of seven marks. **No single moment in our game may show more than two of them:**
   1. a crouch with fists clenched at the sides;
   2. a scream, or a drawn-out chant;
   3. a flame-shaped body aura streaming upward;
   4. rubble rising in a ring, with the ground cracking and wind under a changing sky;
   5. crackling lightning on the body;
   6. hair rising or changing colour;
   7. a gold, white or red flash with a form name shouted.

   VFX, Animation, Camera and Audio review their work against it.

## 2. Two rules this plan adds

**Clashes are decided on the pulse** (Orb: timed presses, "hit the pulse to surge"). This covers the beam struggle, the fist clash, the blur exchange and the grapple lock.
- A clash has **3 pulses.** Each is shown and heard, with an 8-tick window (10 on touch).
- A press on the pulse is a **surge:** +10 to that fighter's clash score. A press off the pulse misses that pulse and locks the next press out for 20 ticks, so mashing loses.
- The score still starts from state (tier, ki and meters), as today. The pulses swing it by up to 30 either way.
- The AI hits 40%, 65% or 85% of pulses (easy, medium, hard).

**Answering a beam costs tight timing only.** The three answers Orb picked are the three looks of a perfect block against a signature, which is already a DEFLECT (`control-rules.md` §1). The direction held on the press picks the look:

| Held | Answer | What happens |
| :--- | :--- | :--- |
| Away | **Swat it into the scenery** | The beam is knocked aside and carves where it lands. The game picks the direction: a protector swats it at the sky or empty ground, and a fighter who feeds on collateral swats it at buildings. The damage counts against the beam's tier cap and is credited to the swatter |
| Neutral | **Split it around the body** | The beam parts and scars the ground on both sides behind him |
| Toward | **Walk through it** | He advances through the beam and arrives in front of the attacker, who is 20 ticks into recovery |

- All three cost no ki and take no damage, as a perfect block does.
- **This is different from the rival's On the Chin.** That is a held stance with no timing, in which he takes 30% of a signature's damage and builds Pride. A perfect block is tight timing, takes nothing and builds nothing.

## 3. The feature list

"Presentation" means it only reads sim state. "Sim" means the simulation changes.

| # | Feature | Trigger | Tier | How often | Cost in play | Kind | Owners |
| ---: | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | **Battle damage on fighters** (torn clothing, scuffs, a broken limb that hangs or drags, a flickering aura, heavy breathing and stagger) | The wear stages: scuffs at bruised, torn clothing and heavy breathing at battered, the hanging limb at a crippling blow, the flicker at a battered core, the stagger on the brink | Any | Always on. It stays and keeps building through transformations | None | Presentation | Art, Animation, VFX |
| 2 | **Face cut-in for every line** | Any quip, one-liner, banter line or taunt | Any | At most 6 a minute, and never two on one side at once | None | Presentation | UI, Narrative, Art |
| 3 | **Shouted move names, no card** | A signature, special or finisher starts | Any | With the move | None. This replaces the on-screen name card in `moveset-rules.md` §2 | Presentation | Audio, Narrative, UI |
| 4 | **Silence before a huge hit** | 8 ticks before a finisher, a crippling blow or a signature lands | Any | With those hits | None. The sim doesn't slow | Presentation | Audio |
| 5 | **The fighter's theme on transformation** | A transformation's break beat | Any | Each transformation | None | Presentation | Audio |
| 6 | **A delayed boom from far-off impacts** | An impact off screen, or beyond 30 bh | Any | With those impacts. The delay is capped at 1.5 s | None | Presentation | Audio |
| 7 | **The crater-landing entrance and the staredown** | The match intro, before the clock starts | Any | Once. Both can be skipped | None. The entrance craters are real, on open ground, with no collateral | Sim (small) | Camera, World, Animation |
| 8 | **The winner stands in the wreckage** | The KO | Any | Once | None. The camera pulls back over the match's real scars | Presentation | Camera, Rendering |
| 9 | **Land scars stay; water closes** | Any crater, trench or beam scar | Any | Always | None. Water closes within seconds by the existing flow | Already in the sim | World |
| 10 | **Crowds watch, then flee** | The mood bands and the evacuation rules | Any | Always | None | Already in the sim | World, Rendering, Narrative |
| 11 | **Speed lines and panel cut-ins** (Orb's pick: two levels) | Speed lines alone on every launch and every heavy that lands, as a 6-tick streak. The panel on signatures, finishers, crippling blows and the KO, and on earned hits (a clash won, a riposte that launches, a ping-pong's ender), which share one panel every 12 s | Any | About 2.4 panels a minute at QA's measured rates (8.3 landed heavies and 0.69 heavy clash wins a minute). Speed lines on about 15 to 20 hits a minute | None | Presentation | Camera, VFX, UI |
| 12 | **The world reacts** (the sky pales or parts, rubble lifts gently, cracks spread under a standing fighter, windows blow out for blocks; changed by Legal, §3b) | A fighter reaches tier 3; stronger at tier 4 | 3 and up | Continuous while at that tier. Windows blow out as the visible form of the wider structure reach in `balance-targets.md` §21 | None beyond that reach | Presentation, on a sim value | VFX, Rendering, World |
| 13 | **The ping-pong rally** | `control-rules.md` §11 | Any; longer with tier | 2 to 6 blitzes a minute in Tense and Frenzied | 6 ki a bounce | Sim | Combat, Encounter, Animation |
| 14 | **Beam struggle on the pulse** | A beam answered by a beam | Any | 30 to 60% of signatures (2 to 5 a match, with the last stand) | The answer's ki, as today | Sim | Encounter, Controls, UI, Audio |
| 15 | **Fist clash shockwave** | A heavy meets a heavy, on the pulse | Any. The shockwave damages structures from tier 3 | About 1.5 a minute; the big version under rule 2 | A heavy's ki. The shockwave's damage counts against the collateral budgets | Sim | Combat, Encounter, World, VFX |
| 16 | **Swat, split or walk through a beam** | A perfect block against a signature (§2) | Any | Up to the 2 to 5 signatures a match | Timing only | Sim (small) | Encounter, Combat, VFX |
| 17 | **Throwable vehicles and ships** | The context button's pick-up | Cars at any tier, lorries and boats from tier 2, ships from tier 3 | As the props allow. At tone 6 of 10 the people bail out first, and it is played for comedy | None. The throw's damage is by size | Sim | World, Combat, Art |
| 18 | **Through the mountain** | A launch aimed at a rock formation or mesa | Small formations from tier 2, mesas from tier 3 | In the shared budget of 3 a match | A normal launch. The tunnel stays all match, and later launches can pass through it | Sim | World, Encounter, Rendering |
| 19 | **Orbit and re-entry** | An upward launch at high power: a break or finisher launch, or the crater set piece | 3 and up | In the shared budget of 3 | One impact of wear. The game picks the most dramatic landing spot within the collateral budget (below) | Sim | Encounter, World, Camera, VFX |
| 20 | **Blur exchange across the sky** | Both fighters attacking with strings queued, in Tense or Frenzied, on the pulse | 2 and up | About 1 a minute in Tense and Frenzied, under rule 2 | The strings' own ki | Sim | Combat, Encounter, Camera |
| 21 | **Mid-air grapple lock** | Two grabs meet in the air, or a dive grab meets a grab, on the pulse | Any | Rare: under 1 a match | None. The winner slams the loser | Sim | Combat, Encounter, Animation |
| 22 | **The round-the-world hit** | A ping-pong's ender or a finisher launch, in Frenzied | **4 only** | In the shared budget of 3, once per fighter | 20 ki. He flies above everything, so there is no collateral on the way | Sim | Encounter, Simulation, Camera, VFX |
| 23 | **The last stand** (Orb's pick: one last signature; **Legal's re-screen is pending**) | The first time a fighter reaches the brink: a camera cut, his face cut-in and a line, and his signature is free and ready at once for 20 s | Any | Once per fighter per match | A free signature. The rival answers it like any other | Sim (small) | Encounter, Narrative, Camera |
| 24 | **The taunt feeds the meter** (Orb's pick: meter only) | A completed taunt: Pride +6, heat +10, Wrath +8 or Hunger +5, with mood +3 and the face cut-in | Any | 1 to 3 per fighter per match, with a 15 s cooldown | 1 s of exposure: a hit during it is a clean hit at ×1.2 | Sim (small) | Combat, Narrative, Encounter |
| 25 | **A highlight reel at the match end** | The KO | Any | Once: 3 to 5 clips of 3 to 4 s | None. It replays from the seed and the input log | Needs the replay system | Tools, Camera, UI |

**How "the most dramatic landing spot" is picked** (feature 19). The game scores the candidates inside the re-entry's reach, and takes the best one that fits the collateral budget for the tier:
- a landmark or a skyline in view: high;
- water, for the splash and the wave: high;
- a place that already has scars: medium;
- open ground: low;
- personality: a protector avoids people, and a fighter who feeds on collateral seeks them.

**The aura after a transformation** shows only while charging or attacking (Orb). So at a distance a form reads by its silhouette and colour mass, not by a standing aura (`moveset-rules.md` §10.2).

## 3b. Legal's constraints, by feature

From Legal's screen (`docs/legal/rule-of-cool-screen.md`). A feature not listed here is clear as written. The stacking rule in §1 applies to all of them.

| # | Feature | What the build must keep |
| ---: | :--- | :--- |
| 2 | Face cut-in | Our own frame and type. It must not look like a static-filled radio screen or copy a known game's portrait layout |
| 3 | Shouted move names | The names are ours. A name is never broken into drawn-out syllables across a charge |
| 5 | The theme on transformation | Original themes only, with no sound-alike |
| 7 | Entrance and staredown | Our own staging. No wind-blown cape and no silhouette reveal |
| 12 | The world reacts | **Changed.** Rubble lifts gently and with weight, never as a ring of rocks around the fighter. No lightning. The sky pales or parts and never darkens. It never plays together with a crouch, a scream and a body aura |
| 15 | Fist clash shockwave | No cracked-sky or shattered-space effect |
| 16 | Swat, split or walk through | No named technique and no borrowed hand pose. A swatted beam doesn't end in a mushroom cloud staged like a known scene |
| 20 | Blur exchange | The bodies stay readable. It is not invisible fighters with only shock rings, a freeze on locked fists, or a cut to an onlooker who can't follow |
| 22 | Round-the-world hit | Our own name for it, and no shouted name or borrowed pose |
| 23 | The last stand | Screened again when Orb picks. No glowing-blood look and no final speech |
| 24 | The taunt | No beckoning fingers |
| | On the Chin (`spec-wounds.md` §3) | Clear. Its bravado line gets an exact-phrase search before it is locked, like any line |
| | The transformation's break (`moveset-rules.md` §10.8) | The snap is not arms thrown wide with the head back, and there is no shrieking sound. The flash is never gold, white or red |
| | The aura | Only while charging or attacking, never at rest. A thin outline or rings in the fighter's lane colour: not a flame streaming upward, with no gold, white or red and no lightning. Never together with a crouching, fists-at-the-sides charge pose and a scream |

Legal re-screens features 12, 20 and 22 and the aura when Art's and VFX's first versions exist, and reviews the first transformation cinematic.

## 4. The build order

| Wave | What | Why now, or what it waits for |
| :--- | :--- | :--- |
| **0. Cheap presentation** | Features 1 to 6, 8, 11 and 12 | They only read sim state. Feature 11 waits for Orb's pick |
| **1. With Encounter's agency and variety work** | Features 13 to 16, and the entrance (7) | Orb's priorities are the agency fixes, then variety. The pulse rule lands with the beam struggle |
| **2. After fight lanes and ground contact** | Features 17 to 21 | Props and formations need real footprints and depth (ADR 0009). Orbit needs the new landing rules (`balance-targets.md` §20) |
| **3. Top tier, and the first real moveset** | Features 22 to 24 | The round-the-world hit needs tier 4 to be worth reaching. The taunt and the last stand need the roster's meters |
| **4. With replays** | Feature 25 | It needs seeded replays from the input log |

## 5. What each director should know

- **Legal:** the screen is done, and its constraints are in §3b and rule 9 of §1. The staging must be ours: no franchise shots, poses or names.
- **QA:** new counts to measure are panels a minute, planet-scale launches a match (at most 3), big set pieces (at most one per 20 s), and the pulse hit rate by AI difficulty.
- **Controls:** the pulse window and its lockout match the perfect block's.
- **Rendering and VFX:** every effect needs a reduced version for 30 frames a second.
