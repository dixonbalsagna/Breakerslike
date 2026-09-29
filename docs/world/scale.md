# World scale: making the world life-size against the fighters

Owner: World and Environment. Status: proposal, docs only (2026-09-29). Nothing here is in the sim. It answers Orb's note: "right now everything looks very small compared to the fighters, I'd like to see a much larger world with buildings and civilians scaled up to be life-size compared to the fighters."

Numbers are read from `sim/core/constants.gd`, `sim/world/*`, `sim/director/*`, `sim/core/fighter.gd`, `sim/core/view/camera.gd` and `render/core/*`. "bh" means a fighter's body height, 75 units (section 1). Speeds and times come from the sim's own constants, and the tempo figures from `tempo.gd` over 100 seeds.

## 1. The numbers today

| Thing | Units | Body heights (bh) | Where |
| :--- | ---: | ---: | :--- |
| Fighter, feet to head top | about 75 (legs 26, torso 32, head 20; chest at about 36) | 1.0 | `fighter_view.gd`; the sim aims beams at y + 36 to 38 |
| Fighter hitbox | none: hits are decided by distance and state, not by a box. The one body-size constant is the building collision (`w/2 + 16`) | | `fighter.gd` |
| Civilian, as drawn | 17 (the sim has counts only) | 0.23 | `look.gd`, drawn at about twice its real size against the buildings (a person would be 7 units) |
| House | w 28 to 50, h 36 to 72 | 0.4 to 0.7 wide, 0.5 to 1.0 tall | `terrain.gd` `_row` |
| Tower | w 30 to 64, h 120 to 660 (tallest in the seeded planet: 533) | 1.6 to 8.8 tall | `terrain.gd` `_row` |
| Tree | h 46 to 110 | 0.6 to 1.5 | `terrain.gd` |
| Mountain peaks | up to about 890 | 11.9 | `genWorld` |
| Sea depth | about -340 | 4.5 | `genWorld` |
| Crater radius by source | 26 (a slow impact) to 260 (the cap); power-up tier 4: 208 | 0.35 to 3.5 | `crater.gd` |
| Planet | W = 9,600, 1,200 columns of 8 | 128 around; a column is 0.11 | `constants.gd` |
| Flight ceiling | 2,600 (the camera clamps at 2,400) | 35 | `fighter.gd`, `camera.gd` |
| Walk, dash | 430; 430 x 2.4 = 1,032 (tier 4: about 1,340) | 5.7; 13.8 (17.9) bh per second | `fighter.gd` |
| Launch speed | force 2,600, x (1 + 0.16 per tier above 1); SMASH ACROSS x 2 | up to about 51 (nominal, before the drag) | `launch.gd` |
| Typical fight separation | start 750; hiding needs more than 170 and is "found" inside 240 | 10; 2.3 and 3.2 | `newMatch`, `hiding.gd` |
| Flight distance | median 710 to 780; 33 to 36% of flights are 1,500 or more | 9.5 to 10.4; 20 or more | `tempo.gd` |
| Lap of the planet | 9.3 s dashing, 22 s walking | | 9,600 / 1,032 |
| Camera zoom | 0.06 to 1.15 pixels per unit; 0.3 to 0.7 in real fights. View 1,113 to 21,333 units wide at 1,280 px | 14.8 to 284 bh across; a fighter is 86 to 4.5 px tall | `camera.gd` |
| Distances that are about the fighters | roughly 120 lines across melee, exchange, ai, launch, beam, fighter, hiding and camera (ranges, offsets, rush lengths, the chest offsets, the cover heights, the camera margins) | | grep of the director and core |

Why it looks small: a house is shorter than the fighter, a tower is at most nine fighters, and the whole planet is 128 fighters around. Against a human, a fighter is 1.8 m: the planet is 230 m around, a house 1.8 m tall, a tower at most 16 m, a tier-4 crater 5 m across.

## 2. The target

Life-size means one fighter is one human, so everything else is in body heights.

| Thing | Target (bh) | In units at 75 per bh | Notes |
| :--- | :--- | :--- | :--- |
| Civilian | 1 (the same as a fighter) | 75 | Ordinary human height, fighters are humanoid |
| House | 4 to 6 tall, 4 to 8 wide | 300 to 450 tall | Two or three storeys |
| Tower | 20 to 40 tall | 1,500 to 3,000 | Ten to twenty storeys |
| Skyscraper | 60 to 150 tall | 4,500 to 11,000 | A new archetype, in the city core only |
| Tree | 5 to 14 | 375 to 1,050 | 9 to 25 m |
| Mountain | 100 to 500 | 7,500 to 37,000 | Bigger than a skyscraper. Needs its own factor |
| Craters | tier 1: 2 to 6; tier 2: 8 to 15; tier 3: 20 to 50; tier 4: 60 to 100 (a city block to a district); the finisher: the planet | R of 150 to 450; 600 to 1,100; 1,500 to 3,750; 4,500 to 7,500 | Orb's "km-scale" (about 550 bh at 1.8 m) is bigger than a 1,000-bh planet, so it is the planet-destruction moment and nothing smaller |
| Planet | 1,000 to 10,000 around (Orb decides, section 5) | 75,000 to 750,000 | 1.8 to 18 km at human scale; see the lap times below |
| Fight separation | 1 to 60 bh, as now | unchanged | Fighters stay at fighter scale |

A single ratio takes the current numbers most of the way. A world factor of 8 makes houses 288 to 576 (3.8 to 7.7 bh), towers 960 to 2,240 (13 to 30), the tallest tower 5,280 (70), trees 370 to 880 (5 to 12), and craters of E = 1 to 16 with R = 464 to 1,856 (6 to 25 bh). What it does not make on its own: skyscrapers of 60 to 150 (that is the new archetype), mountains of 100 or more (their own factor of about 12 to 16), and tier-4 craters of 60 to 100 bh (the energy law needs a steeper tier term; section 3).

## 3. The ways there

**The idea that makes the options comparable.** Options (a) and (b) draw the same picture at two sizes. What matters is the ratio of the world to the fighter (8) and how fast the fighters cross it. (a) shrinks the fighters, their combat ranges and the camera zoom to 1/8 and leaves the world and every speed in units per second alone; the world's distances in seconds are unchanged, so the fighters move 8 times faster in body lengths ("anime-fast"). (b) grows the world 8 times and leaves the fighters and their speeds; the fighters move at the same body lengths per second, and the world takes 8 times as long to cross.

| | (a) Shrink the fighters | (b) Grow the world | (c) Grow the world, and speed up traversal |
| :--- | :--- | :--- | :--- |
| **Sim constants that change** | About 120 distance literals in the director and core (`fighter.gd` chest offsets and the building collision, cover heights, hiding ranges 170 and 240, melee and exchange ranges and rush lengths, beam origin, the camera margins 700 and 500 and its zoom clamps). Fighter and civilian size. The world constants stay | `W`, `NC`, `COL`; `SEG`; `genWorld` amplitudes, building sizes and spacing; the crater, scorch and water constants (`R_BASE`, `R_MAX`, the sea and shore -30, the groove sizes); the flight ceiling 2,600 and the camera y clamp; the damage radii (`damageArea` and the blast radii); the world-side AI distances (`popNear` 900, `LURE_STEP` 200, `CARE_R` 700, `nearestBuilding` 1,100) | (b), plus a traversal factor on free flight and launch |
| **Render only** | Fighter mesh, the camera zoom range (0.5 to 9 for the same fighter size on screen) | Nothing much: the planet mesh and the far land rebuild from the sim; civilian figures, the ground band's depth | Same as (b) |
| **Speeds** | Unchanged in units, so 8 times faster in bh per second. A lap is 9 s, as now | Unchanged; a lap is 74 s at dash. Traversal takes 8 times longer | Chosen, from Orb's lap time |
| **Terrain resolution** | A column is 8 units = 0.85 bh. Terrain reads as coarse at fighter scale. Needs a column of 1 to 2 units (NC 4,800 to 9,600) | Keep NC 1,200 and a column of 64 = 0.85 bh (coarse, and a tier-1 crater is 3 columns wide), or take NC 4,800 with a column of 16 (0.21 bh) | As (b) |
| **Tick cost** | Arrays 4 to 8 times bigger. Crater, scorch and water loops go with them | NC 4,800: arrays 4 times bigger, crater and scorch loops 4 times longer, water windows 4 times (the +8% of the crater work becomes about +20 to 30% unless the water step is coarsened or its window capped). NC 1,200: no change | As (b) |
| **Camera and pillar 3** | Zoom 0.5 to 9. A 2,000-unit beam duel needs zoom 0.36, which is a 3-pixel fighter | Fighters at their usual pixels (zoom 0.3 to 0.7). Buildings are 8 times taller than the screen at that zoom, which is the point. A separated pair is 8 times harder to keep in frame only if the fight itself spreads 8 times | As (b) |
| **Launches and long hauls** | Unchanged in units. Long hauls are 20 bh no more, and now 160 bh in a body's terms | The same 700 to 780 units is now one eighth of a biome. Fights stay in one place unless launches, chases or a boost carry them. Encounter must retune the tempo rows (relocation, new-biome share, fight time by biome) | The boost or the launch force is scaled so biome changes stay at today's rate |
| **Civilians and density** | Same population, smaller figures (1 bh = 9 units) | Pop stays abstract "crowd units" (425). The sim's casualty rule, and the anguish and menace coefficients that assume 425, do not change. Rendering draws several figures per unit (about 5 to 10) for life-size density | Same as (b) |
| **Hiding and cover** | Fighter-relative rules (submerged 60 and 100, canopy 70, ridge 40) shrink by 8 with the fighter, so they need retuning | The cover heights are world features: canopy and ridge heights and the tree radius scale by the world factor; submerged depth stays fighter-relative (a body plus margin), and the sea gets deeper | Same as (b) |
| **Goldens and QA** | Every distance-based test moves: every golden regenerates; combat balance should be identical if the similarity is exact, and QA has to prove it. Tempo, launch and hiding bands are unchanged in units | Every golden regenerates. The bands in per cent hold on paper; the distance bands (tempo, "long haul at 1,500 units", biome fight time) need re-expressing in bh and re-baselining | As (b), with one more knob |
| **Wounds** | Wear from impacts uses speeds, unchanged | Same | Same |
| **Buildings in depth (B1, B2)** | B1's rows and heights are already at today's numbers. The building rows stay as written in `buildings-in-depth.md` | Every number in `buildings-in-depth.md` (rows at z +70 to -290, heights, chain gaps 260, `CHAIN_DZ` 180, aim reach 90 to 1,300) is multiplied by the world factor, or written in bh from the start | Same as (b) |

### What I recommend: (c), built as one knob on (b), not (a)

Reasons:
1. **(b) and (c) change data and world constants; (a) changes the fight.** About 120 combat distances are the fighters' own feel, tuned for the last several slices, and a mistake in any is a balance regression that is hard to see. The world constants are a small set, most of them mine, and they move together.
2. **The tempo and location work is already about relocation.** `docs/director/tempo-and-location.md` and Encounter's long-haul work carry the fight across the planet on purpose. (c) lets Encounter decide how a fight covers 8 times more ground: chase flights (a "break launch and chase" set piece) and a traversal speed. That work happens anyway.
3. **It rides on B1 and W1.** B1 already rewrites the generator as data with row and archetype tables; the world factor is a parameter of that data. W1 (the planet record) already makes the circumference a parameter. Doing scale first, as one `WORLD_SCALE` constant, means B1 is built at the right size and W1 inherits a scaled world.

**The knob.** `SimConst.WORLD_SCALE`, at 8 to start (Orb can change it without touching the code): `W = 9,600 * WORLD_SCALE`, the columns `NC = 4,800` at `COL = W / NC`, the biome spans, the world-generation amplitudes, the building and tree dimensions, the crater, scorch and water constants and the world-side ranges, all as `constant * WORLD_SCALE`. The hp formula uses the building's unscaled height, so a 5,000-unit tower is not 8 times harder to knock over; only its size and the dust it makes scale.

**Traversal.** Pick a lap time, then a factor for free flight and launch speed. At the current dash a lap of the scaled planet is 74 s; at 4 times the dash it is 18 s; at 8 times it is 9 s again (that is (a)). A middle value keeps crossing a biome to a few seconds. It is a factor on the free-flight dash speed and the launch force only: melee, exchanges and the beam stay at fighter scale. This is Encounter's tuning.

**Crater energy law.** At factor 8, tier 1 to 3 craters come out at 6 to 25 bh with the current law. Tier 4 needs a steeper term: `E(power-up) = 1.6 * tier^1.5` becomes about `1.6 * tier^3` (tier 4: 102, R = 4,700 = 63 bh); `R_MAX` rises with the factor, to 20,000 or so. Planet destruction is a separate finisher energy, not a tier.

**Flight ceiling.** 2,600 stays fighter-scale (35 bh) and would put the roof below a 5,000-unit tower. It becomes the tallest building plus a margin (about 12,000 at factor 8), with the camera clamp, and the beam rise clamp (2,400) with it.

### Costs of the recommendation

- One big golden regeneration and QA baseline reset. Do it once, at the front of the queue (below).
- Terrain at NC = 4,800: sim tick about +20 to 30% until the water step is coarsened (windows capped to 30 columns, `STEP_TICKS` 4), which brings it back to about +10%.
- Rendering: the terrain texture is 4 times wider, planet copies are 8 times longer, and the far land, ridges and horizon curvature retune (`CURVE_*`, `Z_*`). Buildings and civilians are sized from the sim and `CROWD_*` retunes (a real 75-unit person at the far zoom is 4 px; the existing boost handles it).
- Encounter: the tempo rows and the launch and lure constants move (a real workload, but it is the work Encounter has queued).

## 4. Where it goes in the queue

The proposal: **a scale slice, SC, right after S1 with W-R, in one golden regeneration, before B1.** Your instinct is right, and I would not put it first:
- S0 and S1 do not depend on scale. S1 (wear) measures its statistics in percentages and in wear per hit.
- SC must land before S2. S2 (the end) and everything after it tunes finishers and exchanges against tempo at the final size, and re-tuning them after a scale change would mean tuning twice.
- SC must land before B1, so B1's rows, heights, chain gaps and reach are built at the target size.
- Steps inside SC, one editor at a time: (1) World: the knob, the constants, terrain resolution and the crater law (with W-R); (2) Simulation: the ceiling, the camera constants and the goldens; (3) Encounter: a short tempo pass (the launch force and a traversal boost) so relocation still happens at today's rate; (4) QA: re-baseline; (5) Rendering, in parallel from step 1: terrain and planet rebuild, civilians life-size.
- Size: about the size of the crater slice plus a tempo pass (M to L).

## 5. Questions for Orb (three)

1. **How big should the planet feel, as travel time?** At life size the planet is: **small** (about 1,000 bh, W 76,800; a lap takes about 75 s at the current dash, or 18 s at 4 times); **medium** (about 4,000 bh, W 300,000; 5 min at the current dash, 75 s at 4 times); **large** (about 10,000 bh, W 750,000; 12 min at the current dash). Small is the cheapest, keeps the biomes near each other, and makes planet destruction literal (a tier-4 crater is a large slice of it). Large is the most planet-like and costs terrain resolution and tick time, and takes long flights to see it. I recommend small to medium, at 8 times to start.
2. **How fast should fighters cross it?** Choose the lap time when dashing flat out. At the current speeds a lap of the small planet is 75 s; anime-fast (the fighters ripping across it in 10 to 20 s) needs a boost of 4 to 8 times on free flight, which gives the "shrunk fighters" feel of (a) without the cost. Melee stays as it is either way.
3. **How big are tier-4 craters, and does a km-scale crater end the planet?** Recommendation: tier 4 is a district (60 to 100 bh across), and a km-scale blow is the pinned planet-destruction finisher, which on a small planet is a planet-sized crater. If Orb wants km craters as ordinary blows, the planet must be large (10,000 bh or more), which is expensive.

## 6. As built (SC window, 2026-09-29)

Built as one set of knobs in `sim/core/constants.gd`, and everything below in one golden regeneration (with W-R and the knockback slide).

| Knob | Value | Effect |
| :--- | :--- | :--- |
| `WS` | 8 | Feature scale: buildings, trees, terrain relief (sea depth, plains, forest, desert), craters, scorch, the damage radii of blasts and beams, beam length and sample spacing, the sea and shore thresholds, the water constants, cover heights |
| `PS` | 16 | Planet scale: `W = 9,600 * 16 = 153,600` (2,048 fighter heights around), biome spans, settlement spans, terrain wavelengths, the AI's planet-scale distances (lure step, cover search) |
| `MS` | 12 | Mountain relief (peaks up to about 7,400: 98 fighter heights) |
| `COL`, `NC` | 32, 4,800 | Terrain columns (0.43 fighter heights; 4 times as many columns as before) |
| `TRAV_FREE`, `BOOST_NEAR/FAR` | 10, 1,500 / 12,000 | A dash is up to 10 times faster when the opponent is farther than 1,500 units, full at 12,000: a lap in about 15 s flat out; close in it is the melee dash it was |
| `TRAV_LAUNCH` | 6 | The horizontal part of a launch is multiplied by `1 + 5 * (|ux| / (|ux| + |uy|))`, so vertical launches (slam, uppercut) stay vertical and horizontal ones cross the map. Impact damage, energy and the slide use the unboosted speed |
| `CEILING` | 24,000 | Flight ceiling (was 2,600) |

Resulting world (seed 1): 91 buildings (54 towers, 37 houses; was 47), the tallest tower 4,242 (57 fighter heights), 379 people (was 425; the per-building population is scaled by `WS / PS`), 67 trees, terrain from -2,810 to +7,357, 1,412 wet columns (the sea). Crater radii: tier 2 power-up 1,407 (19 bh), tier 3 2,691 (36 bh), tier 4 4,264 (57 bh); rims scale with energy (W-R). Distances that are about the fighters (melee, hiding 170 and 240, cover heights against the fighter, the launch force) did not change. `newMatch` takes 19 ms (the terrain blur is a running sum).

Not done here (by design): Encounter's tempo pass (fights now drift to the sea and last longer; see the numbers in the report), skyscraper and depth rows (B1), the renderer's adaptation (its far-land, horizon curvature, camera zoom range and the seam sweep's 0.001 tolerance were tuned for W = 9,600; `SimCamera.ZOOM_MIN` is now 0.006). B1 must be written in body heights (75 units) against this.
