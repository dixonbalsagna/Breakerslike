# Living destruction: a landscape that pushes back

Owner: World and Environment. Status: pitch, docs only (2026-09-29). Nothing here is in the sim. Game Design sets the gameplay numbers after; numbers below are placeholders to size the work, and every constant would be named and live in data or in `sim/world/`.

Orb: "as the fighters power up, the destructiveness should keep scaling. Implement novel ways to keep this interesting so the players don't just see it as 'map painting' but rather interfering and actively engaging with a real landscape." And on scale: fighters should launch each other through the landscape and into different biomes several times in a fight (`scale.md`).

Today destruction is paint: a crater or a scorch groove changes the ground, a building loses height, and nothing reacts. The fight neither uses the result nor is changed by it, except for a few tens of units of ground height. The pitch below is twelve ways to make the land react, so that wrecking it changes what the next ten seconds of the fight can do.

## 0. What makes an idea good here

1. **The land answers.** The result of a blow is a process that keeps going for seconds (a slide, a fire, a flood, a quake), so one impact becomes several beats.
2. **It changes play.** It creates or removes cover, makes a hazard or a weapon, or makes a place worth fighting near or away from. The hero and the villain read it differently (pillar 5).
3. **It scales with tier.** Small things at tier 1, planet-scale things at tier 4, so escalation is legible and never instant (pillars 4 and 7). The tiers are the 25, 50 and 75 power thresholds.
4. **It is cheap and deterministic.** The sim's world is a wrapped 1D heightfield plus a few arrays. Every idea below uses the same pattern the water model uses: state arrays, small active windows around what changed, fixed step, bounded caps, no reading of render state, no draw from the gameplay RNG. Where an idea needs randomness it takes it from a stream derived from the match seed (`world.fire`, `world.quake`) that never touches `S.rng`, so a new effect cannot shift an old fight. Every new state array goes into the gameplay hash.
5. **It is not paint.** It shows in the pictures (Rendering, VFX) but the important part is in the sim, so replays, the AI and QA see it.

## 1. The twelve ideas

Ordered by area, ranked in section 3. "bh" is a fighter's body height. Costs: **S** small (under 150 lines, no visible tick cost), **M** (150 to 400 lines, a few microseconds a tick), **L** (larger, or needs new generator data).

### 1. Landslides and collapsing cliffs
- **See.** A mountainside gives way: the slope shears off, a river of rock and dust pours to the valley floor, and a new, lower, raw slope is left behind. At tier 4 a whole peak falls.
- **Play.** The slide is a moving front that carries anyone in it, so a launch into MOUNTAINSIDE becomes a ride and a burial: the front pushes fighters downhill (velocity added along the slope), damages what it reaches (rubble hits buildings and trees at the foot: the far village at x = 7,600, or a new village at the foot of a range on a procedural planet), and leaves the ridge lower, so `ridge` cover is lost where it fell and made where it piled up. The hero can lure a fight to a cliff and bring the ridge down on the villain, or avoid it above a town.
- **Tier.** Scree at tier 1 (a small slip under any hit on a steep slope), real slides at tier 2 to 3, a peak collapse at tier 4.
- **How.** Angle of repose on the heightfield: where the height difference between neighbouring columns is over `REPOSE` (in bh per column) the excess moves downhill by a fixed share per step. It runs in active windows around what changed, exactly like `water.gd`, until it settles. A hit on a steep slope, a crater that leaves a cliff, or a beam trench opens a window. The moving front is the window's transferred mass per step, taken as a velocity push on fighters and a damage source for buildings in its path.
- **Cost.** Sim **M**: one window pass, about the cost of the water step, capped. Render **M**: the dust and rock river, the raw slope colour.
- **Determinism.** Fixed arithmetic on `S.deform`, no draws. The slide's velocity push and damage are plain sums.

### 2. Fire that spreads, and the cover that burns
- **See.** A beam or a blast over the forest leaves a burn front that walks through the trees, faster with the wind and on dry ground, then a black ash bed. Village roofs catch. At tier 4 the firestorm makes its own wind.
- **Play.** Trees stop being binary. A burning tree lights neighbours within `IGNITE_R` after `IGNITE_T`, and burnt trees are gone, so **canopy cover is destroyed by the fight and cannot be hidden in again**. Smoke (idea 3) is the flip side. Villages and houses catch too, so a hero who fights over a village risks a fire he cannot stop and a villain uses it. The fire is a hazard: standing in it costs a little per second and a launch through it burns.
- **Tier.** Sparks at tier 1, a spreading fire from tier 2, a self-feeding firestorm at tier 4 (higher ignition and faster spread).
- **How.** `tree.burn` already exists in the state and is unused; use it as a timer. Per-tree ignition resistance comes from the world seed (fixed at generation), and wind is a seeded per-match direction with a slow drift. Spread is a deterministic threshold on distance and resistance, no draw. Houses use the same rule with their own resistance.
- **Cost.** Sim **S**. Render **M** (flames, embers, the ash bed).
- **Determinism.** State is the burn timer per tree and per house; spread is a pure function of positions, resistance and time.

### 3. Dust and smoke that fights make and that hide people
- **See.** Big impacts and fires throw up clouds that hang and drift downwind for several seconds, thick near the ground. A collapsing tower buries its street in a grey wall.
- **Play.** A cloud is temporary cover: a fighter inside one is hidden from lock-on and the power signature just as in a normal hide (the hidden rules and the ambush window are unchanged), and a hunter has to enter to find it. So **the fight makes its own cover anywhere, at the price of the noise**. A heavy blast defended against becomes a hiding place for the defender; the attacker's own dust can lose him his target.
- **Tier.** Small puffs at tier 1 (too small to hide in), body-sized at tier 2, a street or a valley at tier 3, a bank you can lose a fight in at tier 4.
- **How.** A short list of clouds `{x, y, r, ttl}` (cap 16), spawned by craters (radius and time from E), collapses and burning, drifting with the wind, shrinking with time. `coverAt` gains one more branch: inside a cloud, "dust" (or "smoke" from a fire). No rooftop cover is added, and the cloud is not a building.
- **Cost.** Sim **S** (a capped list, one branch in `coverAt`). Render **S** (a billboard cloud or a particle volume).
- **Determinism.** Wind and spawn are functions of the event and the seeded wind. No draws.

### 4. Towers that topple, and skylines that fall like dominoes
- **See.** A tall building that is wrecked does not just shrink: it leans, and falls, sweeping a wedge of the street in the direction it was hit, taking the buildings in its path down with it.
- **Play.** The fall is a scripted arc that starts on the collapse and reaches as far as the building is tall. Every building in the fall's path in x and in row depth takes damage falling off with distance, and the people under it are casualties by the existing rule. The fall direction is away from the blow, so a fighter picks where the skyline falls: onto the villain's chosen block, or away from the crowd. It is what a chain of brunts (`buildings-in-depth.md` 4b) feels like from the street, and a single tall tower can start it.
- **Tier.** Houses fall in place at tier 1; towers topple from tier 2; at tier 3 and above a collapse can take a whole row.
- **How.** On a collapse of a building over `TOPPLE_H` bh, set a direction (the last hit's) and apply a damage sweep along a fixed arc (a pure function of height and direction): damage to buildings within the swept wedge with falloff.
- **Cost.** Sim **S** to **M** (a small sweep, once per collapse). Render **M** (the tilt and fall animation, dust).
- **Determinism.** Direction and damage are functions of the collapse event.

### 5. Blast shadows: mountains that shield towns
- **See.** A shockwave rolls outward from a big impact at finite speed and stops at a ridge: the town behind the mountain is not hit, the town in the open is flattened, in order of distance.
- **Play.** Damage now depends on terrain. A blast reaches a building only if the line from the centre to it is not blocked by ground higher than the line (a cheap horizon test on the heightfield), and it arrives late in proportion to distance, so fighters can see it coming and use the timing (dodge, shield). **Fighting with the mountain between you and the city is a real choice**: the hero fights over the sea and behind a ridge; the villain drags the fight into the open valley. Terrain matters where it did not before.
- **Tier.** Localised at tier 1 (no wave), a wave from tier 2, a wave that circles the planet at tier 4 (the shadow of the far side is the only shelter).
- **How.** For a blast at (x, y) with energy E, each building or civilian group within reach takes damage after `dist / WAVE_SPEED` seconds, scaled by a shadow factor `1 - blocked`. `blocked` is the horizon test over the heightfield columns between them (an early-out scan over at most a few hundred columns, once per blast per target, with a small cache per window). A pending list of scheduled damages (cap 32) plays out over the next seconds.
- **Cost.** Sim **M**. Render **S** (a visible ring that stops at the ridge).
- **Determinism.** Pure geometry of the heightfield and the blast's energy; the schedule is a list ordered by time and index.

### 6. Coastal flooding and the wave it sends
- **See.** A heavy blow in the sea or on a beach raises a wall of water that runs to the shore, over the beach and into the lowlands, then drains. Craters at the coast fill and connect to the sea.
- **Play.** The wave is a hazard and a weapon. It carries anyone in it inland at speed, damages buildings by how high the water gets against their height, drowns civilians in the flooded strip, and washes away trees. A village at the shore (Netmend) is exposed to a blast at sea. It also gives the fighter in the water something to ride and the hero a reason to fight over open land instead. A flooded lowland stays wet for a while, then drains, which makes coastal ground slower to fight on.
- **Tier.** A wash at tier 2 (a low wave to a few bh), a real run-up at tier 3, a wave that goes a long way inland at tier 4 (up to the first ridge).
- **How.** An analytic travelling wave with amplitude falling with distance from the source and rising with E, moving at `WAVE_SPEED_SEA`. When it reaches a shoreline column, `run-up` height drives a temporary flooded extent: the same `water.gd` windows carry the water inland and back, over ground below the run-up height rather than the -30 rule. The flood counts for the -30 rule only while the wave is active.
- **Cost.** Sim **M** (the wave is a formula, the flood reuses the water windows). Render **M** (the wave, the runoff).
- **Determinism.** The wave is a function of the event; the flood is the existing deterministic flow.

### 7. Stress and quakes: the ground that gets tired
- **See.** Ground that has been hit again and again cracks: fissures spread across a region, and then the region gives way in a quake: a fault line steps, a section subsides, towers shake down by height, and a gap opens.
- **Play.** The land pushes back on someone who keeps hitting the same place, so a fight that stays in one spot ends up in a different, damaged place. The stress is visible (cracks) and the quake is a warned event (a few seconds of rumble), which the AI and the player can use: run the fight over the fault line, or lure the other away from where the crack is. High-tier fighters could deliberately trigger a quake with a slam.
- **Tier.** Cracks from tier 1 (nothing happens), a small quake from tier 2 (rumble, a few tall buildings hurt), a big quake from tier 3 (a fault steps 1 to 3 bh, buildings fall by height), a rift that opens across the region at tier 4.
- **How.** A coarse grid of stress cells (say 64 cells of 4,000 units at scale 8) accumulates each blow's energy with a slow decay. Crossing `QUAKE_THRESHOLD` starts a countdown; the quake applies a deterministic step to `S.deform` along a fault line placed by the region's hash, and a shaking damage to buildings by height and resonance. Stress and the countdown are state.
- **Cost.** Sim **M**. Render **M** (the cracks, the shake, the rift).
- **Determinism.** Threshold and fault placement are functions of the world seed and the accumulated energy.

### 8. Cover the fight makes, and cover the fight takes away
- **See.** A deep crater's bowl and rim, a fallen tower's rubble heap, a heap of slide debris: the wreck of a place leaves new shapes in it. And a burnt forest, a fallen ridge, are places you can no longer hide.
- **Play.** `coverAt` reads the changed land. A fighter low in a bowl with relief of at least 1.5 bh, or behind a rubble heap higher than his head, counts as covered ("pit"), so the wreck of a town gives more places to hide than the town did: the fight makes the terrain it will play on. Cover that burnt or fell is gone, which the AI knows (it already scores the nearest cover: `nearestCover` uses the static layout; it needs to read the changed state). This is not rooftop cover: a heap of rubble is ground, not a building.
- **Tier.** Bowls from tier 2 (deep enough), heaps from tier 3.
- **How.** A bowl test using the same relief measure as the crater dig (`ring - centre`), plus a rubble height per column (a small array, raised when a building falls). `nearestCover` reads the current state instead of the static layout.
- **Cost.** Sim **S**. Render **S** (already draws the bowls).
- **Determinism.** Pure functions of `S.deform` and the rubble array.

### 9. Lava: what the deepest blows open
- **See.** A tier-4 blow digs through the crust and the bowl fills with glowing magma, which flows down the crater's slope into low ground, cools slowly to black rock, and raises a new hill where it sets.
- **Play.** Lava is a hazard: standing in or skimming it burns, and it ignites trees, houses and civilians along its path. It is also a weapon, because a launch that lands in lava is a real punishment, and lava cooling into rock builds a barrier that shuts off a valley or a road (a "ridge" made by the fight). The finisher-class blows are the only things that can open it, so it marks a fight as having gone to the top.
- **Tier.** Tier 4 only, and the planet-destruction sequence (the crust cracks all round and the magma rises).
- **How.** The crust: each column has a `crust` thickness from the generator (the biome data: thick in mountains, thin in ocean and desert). A crater whose depth exceeds the crust at a column exposes magma there. Magma is a second fluid layer using the water windows with a high viscosity (slow flow), a heat value that cools per tick, and a hardening step that converts cooled magma into ground height.
- **Cost.** Sim **L** (a second fluid layer, crust data). Render **M** (glow, heat haze, cooling colours).
- **Determinism.** As water; the crust is fixed at generation.

### 10. Dams and lakes: the flood in the valley
- **See.** A lake sits behind a rock ridge in the mountains. Break the ridge and the lake pours down the valley into the village below, a real flood with a front.
- **Play.** A ready-made trap. The villain who wants a town's people can breach the dam; the hero has to keep the fight away from the ridge. The flood front is a moving hazard that takes anyone caught in the valley and damages the buildings by depth. Lakes and dams are also just a reason for the landscape to have a shape, and a place worth fighting over.
- **Tier.** Tier 2 and up (a hit on the dam).
- **How.** Lakes are pre-filled dynamic basins in the generator (the biome data adds a `lake` feature with a level and a natural dam). The existing water windows carry the flood. `WET_GROUND` and the reservoir rule extend to "any lake basin that is full".
- **Cost.** Sim **M** to **L** (generator data, a bigger water window). Render **M**.
- **Determinism.** As water. A fixed number of lakes per planet, placed by the generator.

### 11. Debris that flies, and that a fighter can throw
- **See.** Collapses and blasts throw big chunks (not particles): a block of wall, a boulder from a slope, a length of steel. They fly, bounce and land.
- **Play.** Chunks are ballistic bodies in the sim (a bounded pool, say 48). One that hits a fighter does damage and staggers him, so falling debris is a hazard in a collapse. A fighter can also grab a big one and throw it (a new move for Combat and Controls: an object as a weapon, using the pool), or kick a boulder. The debris is what a blast leaves for the next exchange.
- **Tier.** Small chunks at tier 1, body-sized at tier 2, building-sized at tier 3, mountain-sized at tier 4.
- **How.** A pool of bodies `{x, y, vx, vy, mass, alive}` with gravity and the same ground and water rules as a launched fighter. Hits use a simple distance test. Spawns come from events (collapse, crater, slide).
- **Cost.** Sim **M** to **L** (the pool, and Combat's design of the grab and the throw). Render **M**.
- **Determinism.** Fixed step; spawn counts and velocities are functions of the events (a `world.debris` derived stream where a spread is needed).

### 12. Scars that tell the story of the match
- **See.** By the end, the planet looks like this fight: a burnt forest, a glassed stretch of desert, a cratered plain, a city with a hole in it, and a report that names them.
- **Play.** Region conversion: a region whose burn, crater and collapse totals cross thresholds is marked burnt, glassed, cratered or ruined. That changes small things in play: burnt forest has no canopy cover, glass desert is slick (a fighter skidding on it keeps its speed) and sharp (debris), ruined city gives rubble cover (8). Narrative reads the scar list for barks and the end-of-match report ("Furrowlea will not grow back"); Camera can end on the worst scar; a rematch on the same planet could start with the scars (a Story mode option).
- **Tier.** Every tier adds scars, and the top tiers make whole regions.
- **How.** A per-region tally (the coarse grid from 7) with thresholds, and a scar list for events. Nothing in the sim depends on it beyond the small effects above.
- **Cost.** Sim **S**. Render **S** to **M** (region tints, the report).
- **Determinism.** Tallies are sums.

## 2. How it escalates

| Tier | The land does |
| :--- | :--- |
| 1 | Dust, scree, sparks, small craters. Nothing to hide in yet; nothing to fear |
| 2 | Cover appears (bowls, small clouds) and disappears (first fires); small slides; houses topple; a wave at sea; cracks start to show |
| 3 | Real slides, spreading fire, blast waves that ridges shield against, a run-up on the coast, tall towers topple, small quakes; big clouds as cover |
| 4 | Peaks fall, firestorms, waves inland, quakes and rifts, lava, and the run at the pinned planet destruction (rifts round the planet, the crust opens) |

The point of the ladder is that each step introduces a new behaviour, not only a bigger circle. At tier 1 destruction is decoration; from tier 2 the land starts to answer, and from tier 3 it starts to decide where the fight can go.

## 3. Ranking and the first two

Scored on the five tests in section 0, with cost.

| Rank | Idea (number in section 1) | Player-visible | Changes play | Uses what exists | Cost |
| ---: | :--- | :--- | :--- | :--- | :--- |
| 1 | 1 Landslides | high | high (a ride, a burial, ridge cover lost) | window pattern from water; `MOUNTAINSIDE` launch | M |
| 2 | 2 Fire that spreads | high | high (canopy gone, hazard) | `tree.burn`, FIRESTORM variant | S |
| 3 | 3 Dust and smoke cover | medium | high (the fight makes cover) | `coverAt`, craters | S |
| 4 | 5 Blast shadows | medium | high (terrain matters) | heightfield, blast energy | M |
| 5 | 4 Towers topple | high | medium (skyline dominoes) | B1 rows, B2 chains | S to M |
| 6 | 8 Cover made and taken | low | high | `coverAt`, crater relief | S |
| 7 | 6 Coastal flood | high | medium | water windows | M |
| 8 | 7 Stress and quakes | medium | medium | grid state | M |
| 9 | 12 Scars | medium | low | tallies | S |
| 10 | 9 Lava | high | medium (top tier only) | needs a second fluid | L |
| 11 | 10 Dams and lakes | medium | medium | needs generator data | M to L |
| 12 | 11 Debris as weapon | medium | medium | needs Combat design | M to L |

**Build first (proposal): fire that spreads (2) with dust and smoke cover (3), then landslides (1).** The first pair is the cheapest and does the most to answer Orb: fire makes the land act on the fight, and burning cover changes what hides you; dust and smoke make the same fight produce new cover. Both use state that exists (`tree.burn`) or a capped list, and both are tiny sim changes with a big visible result. **Landslides are the second build**, the first "terrain that reacts" moment, and the one that turns MOUNTAINSIDE into a set piece. If Orb wants the biggest single wow at the smallest cost, blast shadows (idea 5) are the strategic one: mountains matter.

The three form a foundation: 2 and 3 share the wind and the cloud list; 1 shares the window pass with water; 8 (cover made and taken) is cheap to fold in with 2 and 3 because all of them change `coverAt`.

## 4. Fit with the queue

The idea order assumes `scale.md`'s SC slice, W-R and B1 land first, since fire, dust and slides are tuned in bh.

| Slice | Owner | What | When |
| :--- | :--- | :--- | :--- |
| LD1 | World, with Encounter for the AI's reading of fire and smoke and `nearestCover` | Fire spread and smoke or dust clouds, and cover changes (8) | After B1 (so the burn can catch buildings in rows), before or with B2; needs the world seed's streams |
| LD2 | World | Landslides | After LD1 |
| LD3 | World, Rendering | Blast shadows, towers toppling (with B2's chains) | With B2 |
| Later | World | 6, 7, 12, then 9 and 10 with the planet record (W1) | After W1 and the fold |

All of them are behaviour changes: goldens regenerate in each slice, and QA re-checks the collateral and tempo bands each time (the collateral cap and casualty ramp are still to come, and must count fire, quakes and floods as sources).

## 5. What everyone else does

- **Game Design:** set the numbers (ignition, spread rates, the hazard damage, the cover thresholds, quake stress), and the bands (how much of a match burns, how often a slide reaches a village), and the hero and villain reading of each.
- **Encounter:** the AI knows fire, clouds and slides (a hero avoids a burning forest, a villain fights in his own dust, `nearestCover` reads the changed cover), and the planner's launch scoring can consider a slope or a burning target.
- **Rendering and VFX:** flames, smoke and dust volumes, the slide river, the fissures, the lava, the region tints. They read the state arrays and events.
- **Audio:** rumble before a quake, the fire's crackle by extent, the rock river.
- **QA:** a determinism test per new state array, bounded-cost tests (a worst case fire, a worst case slide), and the collateral bands with each source counted.
- **Legal:** none of this uses a franchise's specific look, but "firestorm" and "lava" names should be generic, and Narrative names the scars.

## 6. Risks

- **Too much noise.** Twelve effects at once can bury the fight. The tier ladder and the caps (clouds 16, pending blasts 32, debris 48, windows 8) are there to keep the screen readable; Game Design sets how often each one triggers.
- **Cost.** Each idea adds a window or a small list and they can overlap. The rule is one shared budget for the world's active windows, and the worst case is tested.
- **Balance.** Cover that appears and disappears changes hiding, which is a band Game Design set (hides at least 1.5 a match); each cover change needs a re-baseline of the hiding rows.
- **Collateral.** Fire, floods, quakes and topples add casualties from new sources. The tier-scaled collateral cap and casualty ramp have to be designed to count all of them.
- **Determinism discipline.** The one real danger is a draw from `S.rng` in a new system. The rule is derived world streams only, with a test that a new system does not change the gameplay RNG position.
