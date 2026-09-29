# P0 wave 1 brief: world-environment

From the Executive Producer, 2026-09-28. Prototype line references are pinned to commit 7233c96.

Brief from the EP (P0 wave 1): tonight you document the prototype's world rules exactly as they are, analyse how collateral scales with tier, and prepare the biome schema field list.

GOAL: Turn the prototype's destruction, planet layout and cover behaviour into precise docs with constants, so Simulation's port and Encounter Systems can rely on them, and say whether 'no fight destroys the planet at low tiers' holds.

CONTEXT (read first):
- CLAUDE.md (pillars 4 and 7, world layer, P3 exit criterion) and your charter docs/directors/world-environment.md.
- prototype/index.html, read only. QA's edit tonight moved every line after 216 down by one.
  - genWorld (126); groundY, seaAt, biomeAt and SEG (118).
  - crater, casualty, damageBuilding, damageArea, explode, popNear (260 to 318).
  - coverAt, nearestCover, nearTree, updateHidden (667 to 689).
  - Callers: tierUp (crater 60+tier*28 at 698), impact (crater and damageArea, 704-711), clashWave (516-517), the explode calls in planBeam and startClash (612, 637), the beam carve (649, 653), and the AI's use of popNear and nearestCover (chooseLaunch 371; aiInput 823 and 837).
  - Cite line numbers and constants: W 9600, COL 8, NC 1200, deform floor -260, sea rule base < -30.
- qa/baseline-p0.md sections 4 to 6 and finding 4: 38.7% civilians lost (default), 64.2% in the villain mirror, 5% of default matches lose 90% or more (20% in the mirror), 218 craters a match, 69.4% of beams over the ocean.
  - Reproduce with 'node prototype/tools/sim-stats.js <matches> <seed> [--arm=NAME]'. To force a tier, use runMatch(h, seed, {setup}) from prototype/tools/match-runner.js.
  - Do not edit anything in prototype/ or qa/.
- Tonight, through the EP:
  - Game Design sets collateral targets in docs/design/balance-targets.md. Your caps and ramps are mechanisms against those targets.
  - Tools drafts a biome schema from SEG and BCOL; your field list refines it.
  - Art writes biome look notes.
- docs/legal/originality-rules.md and review-log.md (grey-zone defaults: no franchise nods; keep biome and landmark names generic).
- Dependency: Simulation is porting sim/world/ tonight, and ownership passes to you afterwards. Write no code there. data/biomes/*.json waits until I forward Tools' schema.

YOU OWN: docs/world/ (including docs/world/tools/ for any analysis script) and, once I say so, data/biomes/ and sim/world/. Nothing else tonight.

ACCEPTANCE CRITERIA:
1. docs/world/destruction-rules.md: every formula for crater, damageBuilding, damageArea, casualty, explode and popNear, plus each call site's arguments, in one table with constants and units. Include the anguish and menace side-effects and the known gaps: no rim or water flow, trees only destroyed, QA-003.
2. docs/world/planet-layout.md:
   - biome order and widths from SEG, the terrain formula per biome, the smoothing pass and the sea-level rules;
   - per-settlement structure counts, sizes and population (425 civilians, 47 structures);
   - a text or ASCII map;
   - confirmation from the code or a headless run that craters cannot flood inland, with the proof stated.
3. docs/world/cover-and-hiding.md:
   - the coverAt and nearestCover conditions with numbers;
   - a table of biome against cover type against altitude band against what the player sees;
   - a list of readability gaps (nearestCover ignores trees and altitude) with fixes.
4. docs/world/escalation-analysis.md:
   - damage per tier for each source (power-up, slam or impact, beam, explode);
   - the time a match takes to reach 25%, 50% and 90% of civilians lost, and of structures lost, per tier 1 to 4, from the default and mirror-villain arms at seeds you name (tier-forced runs through the setup hook are fine);
   - a verdict on 'no fight destroys the planet at low tiers', with the threshold you used;
   - a pass or fail test with numbers QA can run;
   - a tier-scaled collateral cap and a casualty ramp as options, marked 'Orb decides' where they change feel and 'to align with Game Design's targets'.
5. docs/world/biome-schema-fields.md: a draft field list for Tools (terrain, sea, cover rule, structure and tree spawn, palette slot, signature-variant hook, ambience and audio hooks). Each field cites its prototype source. Palette, audio and signature entries are named hooks that Art, Audio and Combat fill.
6. An open-questions list, with Orb-dependent items (2D or 3D, art style, tone) given as options with trade-offs.

CONSTRAINTS: No git state changes. Scripts live only in docs/world/tools/ or your scratchpad; they read the prototype through prototype/tools and never change it. Stay original: generic biome and landmark names, no franchise nods. Numbers must match the code and be reproducible from the seeds you cite; nothing may change determinism.

RETURN: the standard report (SUMMARY, CHANGES, DECISIONS, NEEDS FROM EP, RISKS, NEXT), sent to me with SendMessage.

## Since this brief was drafted

1. Simulation's module map for sim/world/:
- biomes.js: SEG, biomeAt
- terrain.js: genWorld, groundY, seaAt, crater
- structures.js: curH, damageBuilding, damageArea, explode, popNear, casualty, nearestBuilding
- cover.js: nearTree, coverAt, nearestCover
Map your docs to these files.

2. Narrative has named the places (docs/narrative/places.md): the planet Everhold, the sea Longwater, the city Bellgate, and the rest. Its seeded replay gives 47 structures and 425 civilians, 351 of them in the city. Narrative asks for a place_name per region, so include it in your biome field list.
