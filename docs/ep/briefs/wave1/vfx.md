# P0 wave 1 brief: vfx

From the Executive Producer, 2026-09-28. Prototype line references are pinned to commit 7233c96.

Brief from the EP (P0 wave 1): tonight you write the VFX paper foundation: effect inventory, style options, draft effect budgets and readability rules. No render code.

GOAL: Give the project a complete, cited map of every prototype effect and its trigger, plus options, draft budgets and readability rules that later render work can build on.

CONTEXT (read first):
- CLAUDE.md, docs/directors/vfx.md, docs/legal/originality-rules.md and review-log.md (RL-014).
- prototype/index.html, read only. Lines after 216 moved down by one tonight, so anchor on names.
  - Particle emitters: P() (hard cap 2400, silently drops), spark, ring, debris, dust, splash, fire, afterimage (lines about 235 to 257).
  - stepParts (858); drawParts, drawBeams, drawFighter and drawWater (about 984 to 1095).
- Effect triggers:
  - hit() (spark plus damage float), explode(), impact() (launch landing over speed 350), tierUp(), clashWave(), the strike() parry ring;
  - planBeam, startClash, fireBeam, sampleBeam and beamStep (the variant map by biomeAt, about 581 to 664);
  - crater(), damageBuilding(), damageArea() (tree fire), stepFighter (ground dust, about 785), and the water-entry splash (about 724).
  - Beam widths use 24 + tier*9. The aura radius uses 46 + tier*20, and tier >= 3 adds streaks.
- qa/baseline-p0.md: 69.4% of beams are HORIZON CLEAVE, and FIRESTORM and GLASS TRENCH are about 1% each. Say in the docs that the rare variants will be seen least, so they must be the most recognisable.
- QA-002: spark, debris, dust, splash, fire and the charge sparks draw from the sim RNG (R()/rng()), so any VFX change rewrites gameplay. Hit-stop slows particles to 0.1x (step(): dirS.stop).
- Legal: no hair-colour transformations, no 'power level' text (tiers as bars or pips), original poses, and attack names follow 'place or material plus effect'. Show tiers by aura, silhouette, markings or eyes.
- Tonight, and invisible to you:
  - Performance defines the canonical worst-case scene and the total particle budget in docs/perf/budgets.md.
  - Simulation's docs/architecture/overview.md sets the RNG policy, including the cosmetic stream.
  - Art owns the palette and gives semantic colour roles.
  - Camera sets the shake caps. Combat defines the impact events.
  Phrase every dependency as a request for the EP. Pairing with Art's three directions stays loose.

YOU OWN: docs/vfx/. Tonight's writes go only here; render/vfx/ and art/vfx/ stay untouched. Nothing outside them.

ACCEPTANCE CRITERIA:
1. docs/vfx/inventory.md has one row per effect: auras (tiers 1-4, charge, beam-charge orb, hidden ring), afterimage, hit spark, damage float, parry ring, tier-up ring, clash and clashWave, explode, impact shockwave, crater, debris, dust, splash, fire, tree fire, and the six beam variants plus beam clash. Each row gives the trigger event, the emitter or draw function, the current constants (counts, sizes, life) and file:line.
2. A QA-002 section classifies every R()/rng() draw in an emitter or effect as cosmetic or sim-affecting (for example the ground dust in stepFighter). It then states the requirements for Simulation's cosmetic stream: seeded from the match seed by a fixed derivation, a separate stream per effect class, never read by sim code, never advancing the sim stream. Simulation's RNG policy is the rule, and the fix is Simulation's, not yours.
3. docs/vfx/style-options.md gives three VFX treatments paired loosely with Art's three directions, each with trade-offs and a sound-off recognition test for the six variants. Mark anything that depends on presentation (2D, 2.5D, 3D) or art style 'Orb decides'.
4. docs/vfx/effect-budgets.md (named so it is not confused with docs/perf/budgets.md) has a draft table per effect: max live particles, max concurrent instances, draw or overdraw notes, and degrade order under load. Per-effect pools replace the flat 2400 cap, never silently drop gameplay-critical effects, and must sum within Performance's particle row. For the worst case, use Performance's canonical scene (tier 4, full collateral, beam clash in the city, zoomed out, particles at the cap) and list the load your effects add to it, including a building collapse. Mark the file 'to align with Performance'.
5. docs/vfx/readability.md has numbered rules, each with a test:
   - effects never obscure hit or parry windows (max alpha and radius near fighters);
   - tier is readable at a glance at minimum zoom;
   - fixed colour lanes for tiers, stances and beams, as semantic roles with hex provisional pending Art, and each cue also carried by shape or motion;
   - an accessibility note covering colour blindness and reduced flashing.
6. Every rule names its dependency on Combat, Camera, Performance or Art, phrased as a request for the EP.

CONSTRAINTS: No git state changes. No render code tonight. Cosmetic effects must never read or advance the sim RNG. Everything original, with no franchise-coded looks or names.

RETURN: the standard report (SUMMARY, CHANGES, DECISIONS, NEEDS FROM EP, RISKS, NEXT), sent to me with SendMessage.

## Since this brief was drafted

Narrative's glossary proposes renamed beam variants: TIDE CLEAVE, CANOPY BURN, FURROW SCAR, and a new LANE SWEEP for villages. LANE SWEEP is a design change still pending with Combat and Game Design. All the names are pending Legal and Orb, so use the current names and note the proposals.
