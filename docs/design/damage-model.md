# Damage model: fights without health bars

Owner: Game Design. Status: proposal for Orb to react to. Date: 2026-09-29.

Orb's questionnaire 3 (`docs/ep/vision.md`) asks for:
- **no health meters**: location-based damage, where each fighter handles incoming damage slightly differently, and tension without traditional bars;
- **a fighter-specific finisher** as the last blow of every match;
- **transformations that are respected.** This was "long ones can be interrupted" in questionnaire 3, and Orb later replaced it: the fill can be stopped, but the cinematic is respected (`spec-wounds.md` §8).

This page proposes how damage is tracked and read, how each fighter differs, how chapters, finishers and comebacks emerge, and what the sim must store. It offers three variants, recommends one, and ends with the legibility risks. The pacing targets that go with it are in `balance-targets.md` §10.

**Sources.** `index.html:L123` is a line of `prototype/index.html` at commit `7233c96`. The Godot greybox sim is a bit-identical port of it (commit `26479d5`), so the same line numbers describe the greybox. "QA §n" is a section of `qa/baseline-p0.md`. Mechanics are written to survive a re-skin; names are working names.

**What it replaces.** The prototype's single HP pool (1,600, `L185-186`), the KO at 0 (`L318`), and the HP segments proposed in `economy.md` §1.

---

## 1. Recommendation in one paragraph

Use **Variant A, "Wounds"**:
- **Regions.** Every fighter has four body regions (head, core, arms, legs), plus one signature region for some fighters.
- **Wear.** Each region takes wear through four visible stages: fresh, bruised, battered, broken.
- **Stages change play.** A battered leg slows your escape; a broken arm weakens your guard.
- **Brink.** When a fighter's core breaks, or any two regions break, that fighter is on the **brink**. The next decisive exchange the opponent wins becomes that opponent's **finisher**, which is the only way a match ends.
- **Breaks are chapters.** Each break is a set piece: a sting, a bark, and a long launch across the map. It moves the fight to new ground.
- **What the player reads:** the body (wear and posture), the aura, the camera, the sound and the feed. There is never a bar.

Variant B hides a bar behind the same cues. Variant C makes wear discrete and countable. Both are kept as fallbacks (section 7).

## 2. How damage is tracked (Variant A)

**Regions.**

| Region | Hit by (the director picks within these) | What its stages do |
| :--- | :--- | :--- |
| Head | Lights, uppercuts, the finishing strikes of chains | *Battered:* stagger after heavy hits and a slightly narrower parry window. *Broken:* dazed beats, and the fighter's next defence roll is worse |
| Core | Heavies, body blows, beam hits, launch impacts | *Battered:* slower ki regen. *Broken:* the fighter is on the brink at once, and long transformations cannot start |
| Arms | Guard hits (PRESSURE, GUARD BREAK), clashes | *Battered:* weaker DEFENSIVE multiplier. *Broken:* heavies and signatures deal less, and BRACE is unavailable (`stance-matrix.md` R3) |
| Legs | Sweeps, SLAM DOWN and ground impacts, pursuits | *Battered:* lower move speed and ESCAPE slip chance. *Broken:* no dash, and hiding takes longer to start |

**Wear.**
- Each region holds wear from 0 to 100. Stages start at 30 (bruised), 60 (battered) and 90 (broken).
- Wear comes from the same numbers the prototype uses for damage today: every `hit()` (`L319-338`), launch impact (`L713`) and collision with a building (`L734`). The same multipliers apply: tier, combo, ambush and stance. They are simply routed to a region instead of one pool.
- **Choosing the region.**
  - The atom sets which regions a strike may land on.
  - The director picks among them with seeded weights that favour the most-worn region: *the director goes for the wound*. Damage focuses, and breaks arrive.
  - The player steers where damage lands through attack kind and stance, not through an aiming input. Heavies go to the body, lights to the head, and guard hits to the arms.
- **Recovery.**
  - Bruised wear fades while a fighter is out of exchanges (working value 2 per second).
  - Battered wear fades through "second breath" after 4 s without an exchange. Hiding is removed (`spec-wounds.md` §1c).
  - Broken regions stay broken, except through a Rally (section 5).

**Brink and the end.**
- **Entering brink:** the core breaks, or any two regions break.
- **The finisher.** When the opponent of a fighter on the brink wins a *decisive exchange*, the director composes that opponent's **finisher template** in place of the normal ending. Decisive exchanges are the ones that end with the loser launched, a heavy clash won, or a beam clash won.
- **The finisher can still be contested.** It carries its own clash or escape odds. A fighter on the brink who wins that roll survives, and the match goes on.
- **KO only by finisher.** A match can end only through a finisher. Stray damage can never end it.

## 3. How the player and the camera read "how close to the end"

No bars. Six channels carry the same information, so no one channel has to be read alone:

1. **Posture.** Animation blends by region stage: a limping trail when flying (legs), an arm held in or hanging (arms), a hunch (core), a wobble after impacts (head). A fighter on the brink flies low and heavy (Animation).
2. **Visible wear on the body.** Three decal stages per region in the cel-shaded style: torn cloth, cracks, scorch marks and dents. They must read at the widest zoom (Art's silhouette rule). For the Cyborg: sparks and exposed wiring.
3. **The aura.**
   - Steady when fresh.
   - Flickering once any region is battered.
   - Guttering and unstable on the brink.
   - Each fighter keeps its own aura colour; the stability carries the state (VFX).
4. **The camera.**
   - A short "break" shot when a region breaks.
   - Tighter framing and a slow-motion beat when a fighter enters the brink.
   - The finisher's cinematic may run longer than 3 s (Orb).
5. **Audio.**
   - Grunts and growls per fighter scale with wear (Orb: distinct grunts in place of voice acting).
   - Breathing becomes audible from battered.
   - The music adds a layer at the first break and another at the brink (Audio).
6. **Feed and barks.**
   - Every stage change is a feed line: `LEFT ARM BROKEN`, `ON THE BRINK`, `RALLY`.
   - Every stage change can also trigger a line, such as a taunt at a broken arm (Narrative; Orb wants a large, situational line set).

**Readout options** are pitched in `pitches.md` §1, pending Orb's pick. The baseline accessibility fallback is an optional **wear readout**, off by default: a small body silhouette whose regions are tinted by stage. It shows the four regions and their stages, never a number and never a bar. It is on by default in `training` (Accessibility, UI).

## 4. How each fighter handles damage

Each profile is a small set of data values over the shared regions, so a re-skin changes the look and keeps the rule.

| Fighter | Working name | Rule | What the opponent learns to do |
| :--- | :--- | :--- | :--- |
| Protagonist | **Rolls with it** | A quarter of each hit's wear spreads evenly to his other regions. He is slow to break anywhere, but wears everywhere. His first brink of the match triggers a Rally chance at once (section 5). His Respect meter fills faster while he is battered, because he loves a real fight | Spread pressure fails, so commit to breaking two regions fast before the Rally. Or push him to the brink twice |
| Anti-hero | **Proud front** | While his Pride meter is above half, battered stages carry no mechanical penalty and his posture stays upright. He refuses to show it, and only the decals give it away. When Pride drops below half, every hidden penalty lands at once in one visible slump: "the facade cracks" | Humble him (parry, guard-break, break a region) to drop his Pride, and his hidden wear hits all at once |
| Tyrant | **Refit** | Each revision repairs one stage of his most-worn region. The repair shrinks with each revision, and the full-power form repairs nothing. His redesigned tail is a fifth region: breaking it removes the tail attacks and slows his next revision. His three goons are simple bodies with one region each, and one break takes a goon out | Break the tail early. Save big damage for his late revisions, when refits are small |
| Cyborg | **Regrowth and the hatch** | His regions regrow fast (working value 8 wear per second out of exchanges), and consuming speeds it up. His flesh never counts toward the brink. His brink comes only from **core-chip damage**. A heavy, a GUARD BREAK or a signature hit pops his chest hatch open for 1.5 s, and only strikes that land in that window hurt the chip. Chip damage never regrows. Three chip breaks put him on the brink | Commit: open the hatch with a heavy, then chain into it. Fighting from the edges does nothing. His finisher counterpart must land on the open hatch |

**Superseded by Orb's picks.** The Tyrant's fifth region is the **bladed mantle**, not a tail. The Cyborg's weak point is the **Rail chip**, which moves between hatches, not one fixed chest hatch. The binding rules are in `spec-wounds.md` §3.

## 5. How chapters, finishers and comebacks emerge

- **Chapters are region breaks.** Each break is a set piece of 1 to 2 s: the camera's break shot, a bark, then a **break launch**. The break launch is a long launch across the map, chosen by the launch planner with a distance term. It lands the fight somewhere new. A 1v1 has four to six breaks before the finisher, so the fight tours the planet in chapters. That answers Orb's "more attacks launching each other across the map" and the ocean problem together (`balance-targets.md` §10).
- **Finishers are earned twice:** first the brink, then a decisive exchange. Each fighter has one finisher template per form tier, so the ending matches the form (Combat):
  - the Protagonist's all-out energy finisher;
  - the Anti-hero's barrage, then an end by hand;
  - the Tyrant's final-revision technique;
  - the Cyborg's opponent must land the finisher on the open hatch.
- **Comebacks come from three sources:**
  - *Rally.* A fighter on the brink mends one broken region by one stage and leaves the brink. The per-fighter Rally rules and their limits are pitched in `pitches.md` §2, pending Orb's pick.
  - *Second breath.* After 4 s without an exchange, battered wear fades, but breaks never do (`spec-wounds.md` §1c; hiding is removed).
  - *Desperation.* On the brink, a fighter's damage rises, which is today's comeback bonus (`L322`) made visible through the unstable aura. Narrative's "Resolve" cue is exactly this.
- **Transformations are respected.** An opponent stops the *fill* before a transformation. The cinematic itself is never interrupted (`spec-wounds.md` §8, which supersedes the earlier interrupt rule here).

## 6. What the sim needs (data, for Simulation and Tools)

- **Per fighter (data file):**
  - regions: id, wear, stage thresholds, recovery rates by context, stage penalties as data keys;
  - a damage-profile block: spread share, pride mask, refit rule, regrowth rate, hatch window and chip-break count;
  - the brink rule;
  - finisher template ids per form tier.
- **Per atom:** allowed regions with weights, a wear multiplier, an impact class (for hit-stop and camera), and whether it opens the hatch.
- **Per exchange:** whether it is decisive, and the finisher substitution hook.
- **State per fighter:**
  - wear per region (fixed-point, for rollback);
  - stage per region;
  - brink flag and Rally count;
  - hatch timer;
  - derived posture and aura-stability values for rendering (render reads them and never writes them).
- **Events:** `region_stage`, `region_broken`, `brink_enter`, `brink_exit`, `rally`, `hatch_open`, `finisher_start`, `ko`. These go into the fx event stream Simulation built (commit `9ac1ea9`), so Audio, Camera and barks hook onto them.
- **Determinism:** region picks come from the seeded sim RNG, never from the fx RNG (QA-002).
- **QA harness:** it needs the same events to measure the bands: breaks per match, time to brink, rally rate, finisher outcomes.

## 7. Variants

| | A. Wounds (recommended) | B. Hidden vitality | C. Break points |
| :--- | :--- | :--- | :--- |
| Tracking | Wear from 0 to 100 per region, in four stages | One hidden vitality pool; regions are only cosmetic plus penalties | Each region has 3 break points; a decisive exchange lost removes one from the region the director targets |
| End | Core broken or two regions broken, then brink, then a finisher | Vitality at 0, then brink, then a finisher | Two regions emptied, then brink, then a finisher |
| Fighter differences | Rich: each profile rewrites a rule (section 4) | Weak: mostly multipliers on one pool | Medium: per-region point counts and refills |
| Legibility | Good: many cues, focused damage, clear chapter breaks | Poorest: it is a bar the player cannot see, so endings feel arbitrary | Best: countable and board-game clear, but coarse |
| Balance and tuning | Harder (many values); QA's bands cover it | Easiest (one pool) | Easy |
| Risk | Complexity for a new player (section 8) | Players feel cheated: "where did that finisher come from?" | Lumpy pacing; a drawn-out fight between breaks |

Variant C is the fallback if playtests show A's continuous wear cannot be read. Its three points per region map onto A's stages.

## 8. Readability risks (a meter-less fight must stay legible to a new player)

| Risk | Why it matters | Mitigation | Test |
| :--- | :--- | :--- | :--- |
| A new player cannot tell who is winning | No bar to glance at | Six redundant channels (section 3). The feed calls out every stage change. The wear readout exists as a fallback | After one match, the playtester says who was closer to losing at the midpoint: 80% correct |
| A finisher feels like it came from nowhere | A KO with no build-up breaks trust | Brink is a big, loud state (camera, aura, music, a line) and always precedes a finisher. There is no finisher from fresh | 100% of finishers follow a brink call-out (a QA harness check) |
| The Anti-hero's hidden wear confuses | Proud front hides penalties by design | Decals still show; his Pride meter is visible; the facade crack is a loud beat | Playtest: players predict his slump after a humbling |
| The Cyborg feels unkillable | Regrowth erases damage | The hatch has a loud open tell and a hit-window sound; the feed says `HATCH OPEN`; chip damage leaves a visible scar that never heals | Every pairing still passes the win-rate band (`balance-targets.md` §1) |
| Too many cues become noise | Six channels at once | Priority: the feed and camera fire only on stage changes. Posture and decals are ambient. Audio layers change only at the first break and at brink | Feel review of a full match with Controls, Camera and Audio |
| Small, far-away fighters lose their decals | 2.5D at a planet-scale zoom | Posture and aura carry the state at distance, and decals only at mid zoom (Art's widest-zoom rule) | Screenshot review at the widest zoom |
| Colour-blind players lose the tints | Tint-based readout | Stages differ by shape and texture as well as colour (Accessibility) | Accessibility checklist |

## 9. What this changes elsewhere

- **`economy.md` §1:** HP segments give way to regions and breaks. Hiding recovers battered wear, not breaks.
- **`balance-targets.md`:** comebacks are defined by Rally. Pacing targets are in §10.
- **Combat:**
  - region weights per atom;
  - break-launch and finisher templates;
  - a finisher per fighter per form tier.
- **Encounter:**
  - the director's region weights (focus the wound);
  - the decisive-exchange rule;
  - the distance term for break launches.
- **Animation, Art, VFX, Audio, Camera:** the six channels in section 3.
- **UI:** the wear readout (optional); no health bars on the HUD.
