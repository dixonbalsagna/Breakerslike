# Buildings in depth, and the director's building impact

Owner: World and Environment. Status: design, docs only (2026-09-29). Updated the same day for Orb's rulings: no rooftop cover, personality-weighted targeting, and brunt chains (section 4b). Nothing here is in the sim yet. Simulation holds the sim for the Wounds slices, so this note also says where the work slots in (section 8). It answers Orb's direction in `docs/ep/vision.md`, "Rims and buildings".

Read first: `sim/world/structures.gd`, `sim/director/launch.gd`, `sim/core/fighter.gd` (`stepLaunched`), `render/core/look.gd` and `planet_view.gd` (`Z_BUILDING_FRONT`, `_set_building`), `docs/world/craters-scorch-water.md`.

## 0. Where things stand

- The sim is flat. A building is `{x, w, h, hp, pop, ...}` on the fighter plane, and the fighters have no depth. The renderer already puts every building behind the plane (its front face at z = -44, footprint depth `0.8 w` for a tower and `0.9 w` for a house, chosen render-side) and every tree and civilian at a render-side depth.
- Collision is incidental today: any launched fighter whose x comes within `w/2 + 16` of a standing building, below its top, hits it (`stepLaunched`), damages it for `speed * (0.55 + 0.25 tier)`, is thrown back 25 percent of its speed, and takes `speed * 0.006` damage. Free flight (walking, dashing, rushes) never collides. The planner's BUILDING SMASH launch is a candidate that aims along the plane at the nearest building on one side within 1,100 units.
- BUILDING SMASH is 4.6 to 6.1 percent of launches (tempo.gd, 100 matches, before and after the crater work).

Orb wants three things: buildings in front of and behind the fighters, no incidental collision, and the director often picking one building to take the brunt of a launch.

## 1. Rim height scales with impact (next sim window)

Orb: harder hits throw up taller rims. The EP proposed the rim and apron volume fraction (today 0.60 of the bowl, for every E) to scale with E, about 0.4 at low E up to about 1.0 at the top tiers.
- Rule: `f(E) = lerp(0.4, 1.0, smoothstep(E, 1, 16))`, and the rim height is `rim = depth * f(E) * (0.5 / 0.6)`, because rim height 0.5 of the depth gives volume 0.60 (measured, `probe.gd`). At E = 1 the rim is 0.33 of the depth; at E = 16 it is 0.83 of the depth (a 51-deep bowl gets a 42-high rim).
- Constants: `RIM_VOL_LOW = 0.4`, `RIM_VOL_HIGH = 1.0`, `RIM_E_LOW = 1.0`, `RIM_E_HIGH = 16.0`, and `RIM_VOL_PER_HEIGHT = 0.6 / 0.5`. The shape and the cap logic stay.
- Two things to check in that window: `DEFORM_CEIL` (60) will clip stacked tall rims (raise it to 90), and a tall rim lifts the ground under a building by up to 42 units; the depth layout below makes that worse for the front rows, so building footings should be flattened under the footprint (section 2, "footing").
- Cost: a golden regeneration and no other behaviour. It has no dependency on the rest of this note and can go in any window.

## 2. The depth layout

### Bands

z is in world units along +z, toward the camera. The fighter plane is z = 0 and stays empty of buildings. The ground band runs from z = +140 (its front face) to z = -520.

| Row | Name | z (centre of the front face line) | Targetable | What is in it |
| :--- | :--- | :--- | :--- | :--- |
| 0 | Foreground | +70 | Yes | Low buildings only: height at most 80 (about a fighter's height plus a little). Sparse |
| 1 | Front street | -60 | Yes | The main row. Today's buildings move here, so nothing changes for the fight |
| 2 | Mid street | -170 | Yes | Fills the gaps behind row 1; taller than row 1 so they read over it |
| 3 | Back street | -290 | Yes | The furthest a launch will fly to; heights up to the tallest towers |
| 4 | Backdrop | -420 and further | No (render-side decoration) | Silhouette blocks, not in the sim: Rendering generates them from the biome and the seed, like the far land |

A row's z is where its front face sits (`z_front`); the building's centre is `z_front - d/2`. Footprint depth `d` is in the sim (today only Rendering has it).

Why the cuts: fighters are about 60 to 70 tall and 30 thick, so row 0 at +70 clears the plane with a margin. A row-0 building in front of the fight hides what matters, so it is height-capped and Rendering fades it (section 7). Rows 1 to 3 cost more flight time the further back they are, which is the drama of hitting one. Row 4 is scenery.

### Per biome

Names are Narrative's (`docs/narrative/places.md`): the city is Bellgate, the harbour village Netmend. All generic and original; the counts are the design, and the generator (below) makes them.

| Place | Buildings today | Rows used | Split by row (0 / 1 / 2 / 3) | Heights | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Bellgate (city, 1,500 units) | 27 towers, 351 people | 0, 1, 2, 3 | 5% / 35% / 35% / 25% | Row 0: shopfronts to 80. Rows 1 to 3: tower heights 120 to 660, +20% per row back so the skyline reads | Tallest at x = 3,100 stays the tallest. Roughly 70 to 80 buildings in all |
| Netmend (harbour village, 600) | 7 houses, 25 people | 0, 1, 2 | 15% / 55% / 30% | Houses 36 to 72 | Row 0 holds the quay sheds. Boats are Rendering's |
| Outskirts village (650), far village (400) | 8 and 5 houses | 1, 2 | 0% / 60% / 40% | Houses 36 to 72 | Sparser, wider spacing |
| Farms, if Narrative or Art adds them | none | 1, 2 | | Barns to 90 | Not needed now |
| Everything else | none | none | | | Plains, forest, desert, mountains, sea: no buildings. Rendering may decorate row 4 |

**Population is conserved.** Splitting into rows multiplies the number of buildings (47 becomes about 110) but not the people: each settlement's population (425 in total, 351 in Bellgate) is divided by footprint area across its buildings, so `pop0` and the civilian bands in `balance-targets.md` §4 are unchanged, and each building holds fewer people. Structures lost is a percentage of a bigger set. Game Design should confirm that the structure band (§4, 10 to 19 of 47) is meant as a share; if not, restate it as a share or a count of "primary" (row 1) buildings.

### What stays on the fighter plane

- Terrain (the heightfield, craters, water), fighters, beams, particles. Nothing solid else.
- No buildings, no walls, no signage. A fighter walking, dashing or being rushed at z = 0 can never touch one. Pillar 3 (never out of range) stays intact because there is nothing to be cornered by.
- Trees and civilians stay Rendering's decoration at their render-side depths (trees at z = -30 to -120, civilians -8 to -40, in the gap between the plane and row 1). The sim still owns counts, casualties and felled trees.

### How settlements are generated (procedural planets)

`W1` (variable planet circumference) needs this generator to take a planet record. Design it now so the fixed planet is just one record.
- A **settlement archetype** is data in `data/biomes/`: `{kind: city | village | harbour, rows: [{row, share, height_min, height_max, width_min, width_max, gap_min, gap_max, kind}], density, centre_bias}`. The tower row spawn formula in `terrain.gd` (`w`, `h`, the `mid` bump toward the centre, spacing) becomes the row's data; the house formula the same.
- The planet record lists **settlement spans** (start, end, archetype, name). Each span is filled row by row, front to back, from the world stream with fixed draw order per row. The existing first row keeps the current draw order and results, so the current planet reproduces its 47 buildings in row 1 unchanged, and the extra rows draw after them from the same stream, so nothing moves.
- `z_front` is the row's fixed value plus a small per-building jitter (up to +-12 for rows 1 to 3, none for row 0) so a street is not a ruler line; `d` follows the kind (tower `0.8 w`, house `0.9 w`, both clamped to 30..80).
- Overlap: buildings in different rows may share x but not the same (x, z) footprint. A row-2 building is set behind a row-1 gap, not directly behind a row-1 building, where the generator can (it checks a `gap` mask per row and shifts up to half a width), so the skyline shows.
- **Footing.** Where a building's footprint meets sloped or cratered ground, the footing is the maximum of the ground over its width, so it never floats. The sim keeps `groundY(b.x)` for the base as today; Rendering extends the footing down.

### Data the sim gets

Per building: `z` (front face), `d` (depth), `row`, plus the existing `x, w, h, maxhp, hp, alive, kind, pop, popAlive, seed`. `hp` scale is unchanged: `h * 6` for a tower and `h * 3` for a house. Add a stable id (its index in `S.buildings`, which never reorders). All new fields go into the gameplay hash and change the goldens once.

## 3. Collision rules

1. **Normal movement never collides.** Already true in free flight; it stays true.
2. **A launch does not collide incidentally.** The block in `stepLaunched` that checks every standing building on the x axis is removed. A launched fighter flies past the buildings on the plane; visually they are behind it (rows 1 to 3) or in front of it (row 0).
3. **A launch collides destructively only with the building the director chose, and with the buildings its burst-through carries on into** (sections 4 and 4b). The fighter carries `aimB` (the building id or -1); only that building is tested, and only when the fighter's depth has reached the building. When a hit is passed through, `aimB` moves to the next building on the line.
4. **Non-launch damage is unchanged.** Beams, craters, explosions and blasts still call `damageArea` by x distance and height, and they do not care about z, except that a blast's reach now also tests `|z_front - d/2|` so a blast on the plane does not reach a building 400 units behind (Encounter or World decides a reach of about 260 in z; see risks).
5. **Cover and hiding do not use buildings.** `coverAt` stays ocean, forest, mountains. Buildings give no cover, do not block lock-on, and hidden fighters stay on the plane. This keeps hiding readable and keeps the hero's flight from populated ground (pillar 5) a choice.
   - **Decided (Orb): no rooftop cover.** Buildings never count as hiding.
6. **Civilians.** They stand at their building's row: Rendering places `popAlive` figures around each building at its z. They neither block nor are blocked by anyone. Casualties come from damage exactly as now (`casualty()`, menace and anguish unchanged).

## 4. The director-chosen building impact ("the brunt")

### When a building is a candidate

At a launch beat, for the target D and the launcher A (the same moment `chooseLaunch` runs today):
- The reach: standing buildings in rows 0 to 3 whose horizontal distance from D is between 90 and 1,300 units on either side (today: 60 to 1,100 on one side per sign), with top above D's height minus 40 (today's test). Every row counts, so a tower behind three others can be chosen.
- Preselect the best 2 per side by a cheap score (height, occupancy, freshness) so the flight aiming below runs at most 4 times per launch. The planner already runs one flight prediction per candidate, about 6; this adds about 4.
- **Aiming.** The launch needs a vector that brings the flight into the building's footprint. The sim keeps x and y physics exactly as today and adds depth as a kinematic slave (next section). For each preselected building, try `uy` from a short fixed list (0.05, 0.12, 0.25, 0.4) with `ux = sign`; run the extended predictor (`predictFlight` that stops when x enters `[b.x - b.w/2, b.x + b.w/2]` and reports y and speed there); keep the first `uy` whose y is between the ground and the top and whose arrival speed is above 500. A building with no aimable `uy` is dropped.

### Scoring (Encounter owns this; numbers are a proposal)

`BUILDING SMASH` becomes one candidate per surviving building, with

`score = BRUNT_BASE (14) + h / 32 + 3 * tier + fresh (+4 if hp = maxhp) - care * CARE_W * clamp(b.popAlive / POP_REF, 0, 1) - REPEAT_B (12 if it is the last building hit) + noise`

- `care` is +1 for the hero and -0.8 for the villain, and `CARE_W` is 34 (the existing constants). So a building with 60 or more people costs the hero 34 and pays the villain about 27: **the hero avoids occupied buildings and the villain seeks them.** An empty or nearly empty building (a shop, a wrecked house) is neutral, so the hero can still choose one, and a hero with only occupied buildings around chooses NONE or another launch, which is the story.
- Row depth adds `+2 per row` for the villain (further is more dramatic and takes more time in flight, so more in the wreckage) and nothing for the hero. Game Design agrees, as a personality tell kept inside the rate band.
- **Personality first, drama on top (Orb).** The personality term is the occupancy term above (range about -34 for the hero to +27 for the villain) plus a tallness term for the villain, `+ (-care) * TALL_W * clamp(h / 400, 0, 1)` with `TALL_W = 12` (positive for the villain only: he seeks tall, occupied towers; the hero gets nothing from height). The drama terms are the row bonus, the height term `h / 32`, freshness and the chain terms (4b). Cap the drama terms together at `DRAMA_CAP = 14`, against a personality swing of about 60 between the two fighters, so personality decides which building and drama decides among near equals.
- **Pity rate.** To make it "often", a counter `sinceBrunt` in the director state grows by one on every planner launch that had a candidate in reach and picked something else, and adds `BRUNT_RAMP (5)` per count to every building candidate. It resets on a building hit. It only counts when a candidate is in reach, so open ground is untouched. This gives a tunable rate without a hard rule, and it is deterministic.

### The "often" rate (proposal for Game Design's numbers)

- Of the launches that start with at least one building candidate in reach: **35 to 60 percent** choose a building. The villain sits at the top of the band (40 to 60), the hero at the bottom (20 to 35, because occupied buildings are penalised).
- Of all planner launches: **8 to 20 percent**, up from about 5 percent today. This is bounded by how much fight time is spent in settlements (about 15 percent now, `tempo.gd` `fightTimeByBiome`: city 3.5, villages 11.5), so the second number moves with Encounter's location work.
- The cap in `balance-targets.md` §5 holds: no launch type above 40 percent of all launches (95 percent bound 42). The floor (four types each at 5 percent or more) is helped.
- Test QA can run: `batch.gd` per arm, count building brunts per match: default arm 0.5 to 2 a match, villain mirror higher, hero mirror at most 0.6 (checks the personality term), and none in a match that stays away from every settlement.

### How the vector bends into depth

The sim's flight stays two-dimensional. The fighter gets a depth `z` that is a function of how far along its x path it is:

`p = clamp((x travelled) / (distance to the building's near edge), 0, 1)`, `z = b.z_front * smoothstep(p)`, and it is `0` when not aimed.

So the fighter leaves the plane when launched, and arrives at the building face at the row's z just as its x reaches the footprint. `z` is set every tick from x, so it needs only two extra fields on the fighter (`aimB`, and the launch x `aimX0`, plus the derived `z`) and no new integration. When the flight ends (a hit, a miss, water) `z` returns to 0 over 0.3 s. It is sim state (the hash sees it) and Rendering and Camera read it.

Depth costs nothing physically: gravity, drag and the water rules are unchanged. What changes is what the launch is aimed at.

### What the hit does

Arrival speed `sp` at the face, launcher tier `T`.
- **Damage:** `sp * (0.55 + 0.25 T) * BRUNT_MUL`, with `BRUNT_MUL = 1.8` (today's incidental formula times 1.8, so the chosen building takes the brunt).
- **Outcome by damage over the building's `maxhp`, `r`:**
  - `r >= 1`: **collapse.** The building falls (`structuresLost`), its remaining people are casualties (existing rule: everyone left when it falls), big debris and dust, camera shake 10 for tall ones (existing). The fighter bursts through with the speed kept by the rule in 4b (about 0.35 to 0.8 of it, by building size) and carries on: into the next building on its line if there is one (4b), otherwise it lands at the building's foot.
  - `0.6 <= r < 1`: **heavy wreck.** As a partial wreck below, but the fighter is going fast enough to punch through the ruined wall: it carries on as in 4b at a further 0.7 of the kept speed.
  - `0.4 <= r < 0.6`: **partial wreck.** `curH` shrinks (existing: standing height is 30 to 100 percent of full), casualties `pop * frac * 1.3` (existing). The fighter rebounds (existing 25 percent reversal). The chain ends.
  - `r < 0.4`: **cracked.** Dust, a few casualties, the fighter drops at the base.
- **Splash:** buildings within `0.9 w` in x and 120 in z take 25 percent of the damage (spray of rubble), so a brunt on a house in a row hurts its neighbours a little.
- **The fighter** takes `sp * 0.012` damage (today 0.006), routed as an impact under the Wounds model (`damage-model.md`: launch impacts and building collisions are wear sources), and the hit-stop 0.06 s the ground impacts use.
- **Size on the bands.** A tower in Bellgate holds about 13 people, 3.1 percent of the civilians; a collapse costs that. At 0.5 to 2 brunts a match the extra loss is at most a few percent of the population per match, and it grows with tier through `T` (which is what the tier-scaled cap should shape). **A casualty ramp or cap will apply to brunts too** (the collateral work is on hold behind the Wounds slices). Orb decides whether a brunt on an occupied building should also add to the hero's anguish beyond the existing rule (`n * 0.5`, or `0.9` if the hero himself caused it): a single event that costs 13 lives is a natural anguish spike.

## 4b. Brunt chains: through several buildings in one attack

Orb: "a classic villain trope is to send the hero careening through multiple skyscrapers in one attack." A chain is one launch that bursts through a building and carries on into the next building on its line, up to a cap. It is not a separate launch type: it is what a BUILDING SMASH does when there is enough momentum and a building in the way. The planner looks ahead so it can choose it deliberately.

### The line and the carry-on rule

- **The line** is the flight's own 2D path (x and y, exactly today's physics). The next building is the nearest one ahead whose footprint the path will enter, whose top is above the path there, whose gap from the last building's far edge is at most `CHAIN_GAP = 260` units of x, and whose row depth differs from the last building's by at most `CHAIN_DZ = 180` (so the fighter can weave, but not leap from the foreground row to the back street). It may be in any row.
- **Depth through the chain.** The fighter's `z` runs piecewise: from each building's depth to the next building's, by the same smoothstep over the x distance between them (section 4, "how the vector bends"). A chain through a front row, a mid row and a back row is a weave into the distance: the "careening".
- **Carry-on.** After a hit with `r >= 1` (collapse), or `0.6 <= r < 1` (heavy wreck, at a further 0.7), the fighter continues with speed `sp' = sp * keep`, where `keep = clamp(0.8 - 0.45 * maxhp / 3000, 0.35, 0.8)`. A house (maxhp 100 to 220) keeps about 0.77; a 1,200-hp tower 0.62; a 3,000-hp skyscraper 0.35. It continues while `sp' >= CHAIN_MIN_SP (500)` and the chain is under its cap; below that, or with no next building, it drops at the foot of the last building. A partial wreck or a crack ends the chain.
- **Speed and damage fall together:** each next building sees a lower `sp`, so its damage (`sp * (0.55 + 0.25 T) * 1.8`) is lower. A tier-2 launch at 2,600 units per second through three 1,200-hp towers arrives at 2,600, 1,610 and 1,000, with damages of about 4,900, 3,000 and 1,900: all three collapse. Through five houses it barely slows. It takes a tall tower to stop it, which is the physics Orb's trope needs.
- **Cap on chain length:** by the launcher's tier, `CHAIN_MAX = 2` at tiers 1 and 2, 3 at tier 3, 4 at tier 4, and an absolute limit of 5 that only a scripted finisher may use. A stronger fighter can wreck a longer street, and at low tier the chain is short so the "no fight destroys the planet at low tiers" rule and the low-tier bleed band hold.

### Damage and casualties per building

- Each building in the chain takes the brunt damage for its own arrival speed and follows the outcome table in section 4. Casualties are per building by the existing rule (`pop * frac * 1.3`, and everyone left when it falls), credited to the launcher (`launchBy`), feeding menace and anguish per casualty as today. Game Design's default stands: no extra anguish multiplier.
- Splash (25 percent within `0.9 w` in x and 120 in z) applies once per building per launch, at the highest value it would get, and never to a building that is itself in the chain, so a chain does not double-hit its own neighbours.
- **The fighter's damage.** Each building costs the fighter `sp * 0.012` and one wear hit as an impact source (the Wounds model routes it; region spread as for launch impacts). A chain cannot end the match: the sum of a launch's building damage is capped at `CHAIN_SELF_CAP = 12` percent of max HP, and its wear cannot by itself take a region past battered (Encounter and Simulation set the exact wear cap in B2 against `spec-wounds.md`); the end still comes through finishers.
- **Casualty budget.** A chain is the biggest single collateral event in the game: four Bellgate towers are about 50 people, 12 percent of all civilians. The planner declines a chain whose expected casualties exceed `CHAIN_POP_CAP` of the starting population: 8 percent at tier 2 or below, 12 at tier 3 and 20 at tier 4. This is a placeholder for World's tier-scaled collateral cap; **Orb decides** the values, **to align with Game Design's targets.** The cap applies to the villain and the hero alike; the hero would in practice never approach it (below).

### How the planner scores a chain

- Each surviving first-building candidate is run through a **lookahead**: the extended predictor with the carry-on rule, stopping at the cap. It returns the chain `[b1 .. bn]`, arrival speeds, and expected casualties (from each building's `popAlive` and the damage fractions). The predictor cost per link is one more run; only the best first-building candidate per side gets a second run with a force multiplier of 1.4 (`CHAIN_FORCE`), so the planner can choose "more force to get through", like SMASH ACROSS.
- **Score.** The single-building score of section 4, plus for each further building `i` in the chain (`i = 2 .. n`):
  - personality: `- care * CARE_W * clamp(b_i.popAlive / POP_REF, 0, 1)` and, for the villain, the tallness term. The villain gains up to about 27 per occupied tower he sends the hero through; **the hero loses up to 34 per occupied building**, so a hero chain only appears through empty or evacuated buildings (a building with `popAlive <= 4`), which are rare in a settlement. **Chains are the villain's signature and rare for the hero** because of this term, not because of a rule;
  - drama: `+ CHAIN_DRAMA = 5` per extra building, inside the `DRAMA_CAP` of 14 for all drama terms together;
  - a chain that would exceed `CHAIN_POP_CAP` is dropped, not just penalised.
- **Variety.** The repeat penalty applies to the launch type (BUILDING SMASH) as today; a chain does not add a new type. A chain right after a chain gets `REPEAT_CHAIN = 12`, so the villain cannot only do them.
- The `sinceBrunt` pity counter (section 4) counts a chain as one brunt.

### Events and camera per hit

- `launch_depth` carries `n` (the planned chain length from the lookahead) and the first building; it is emitted at the launch beat as before.
- `building_hit` gains `link` (1 for the first building), `n`, `sp` (arrival speed) and `keep`. One event per building, in order, each on the tick the fighter reaches it.
- New `chain_link` `{from, to, x0, y0, z0, x1, y1, z1, dur, link}` on each burst-through: the segment the fighter is about to fly to the next building. Camera uses it to look ahead; Rendering to bend the fighter's trail; Audio to build the crescendo.
- `building_fall` fires as each one falls, so each collapse animates and the dust chain reads.
- **Camera (proposal for the Camera director):** a hold of 0.35 s on the first hit and 0.12 s on each further one (the hit-stop uses the existing `dirS.stop`, so a four-building chain adds at most about 0.7 s of freeze in total, capped at 0.8 s), lead the framing along the fighter's velocity so the next building is in shot, zoom out one notch when `n >= 3`, and add shake per link (`10 + 4 * (link - 1)`, at most 26). The last collapse is held in frame for a beat as the dust settles.
- **Rendering:** the chain shows as a dust-and-debris tunnel through the buildings: the collapse animation of each building begins on its `building_hit`, staggered by the flight time between them.

### The QA band for chains

Game Design's base bands are in `balance-targets.md` §5b (brunts). Proposed additions, **to align with Game Design's targets**, pooled over a default-arm run plus both mirrors:

| Measure | Band |
| :--- | :--- |
| Chains (two or more buildings in one launch) out of all brunts | 15 to 35% pooled. Villain-side fighters 25 to 45%. Hero side 0 to 10% |
| Chain length among chains | length 2: 55 to 75%; 3: 20 to 35%; 4 or more: at most 10%. Never above the tier's `CHAIN_MAX` (a hard test) |
| Chains per match, P2 testbed | default arm 0.1 to 0.6; villain mirror above the default; hero mirror at most 0.1 |
| Casualties in one chain | mean at most 12% of the starting population; no chain above its tier's `CHAIN_POP_CAP` (hard test); no chain at tier 2 or below above 8% |
| The fighter's building damage in one launch | at most 12% of max HP (hard test) |
| Hero chains through an occupied building (`popAlive > 4`) | none (hard test) |
| Collateral bands (§4) | Chains and brunts count toward all of them, including the low-tier bleed, and are never exempt |

## 5. Data and events

### Sim state

- `Building`: `z`, `d`, `row` (new); `pop` and `popAlive` per building (exist).
- `Fighter`: `aimB` (building index or -1), `aimX0`, `aimZ0` (the depth at the last building, for the piecewise `z`), `chainN` (buildings hit so far this launch) and `z`. `f.z` is 0 unless aimed.
- Director state: `sinceBrunt`.
- New constants (World and Encounter, named, in `sim/world/` and `sim/director/`): the row table, `BRUNT_MUL`, `BRUNT_BASE`, `BRUNT_RAMP`, `POP_REF` (60), `REPEAT_B`, `SPLASH_R`, `SPLASH_Z`, `SPLASH_FRAC`, `TALL_W`, `DRAMA_CAP`, and for chains `CHAIN_GAP`, `CHAIN_DZ`, `CHAIN_MIN_SP`, `CHAIN_MAX` by tier, `CHAIN_FORCE`, `CHAIN_DRAMA`, `REPEAT_CHAIN`, `CHAIN_SELF_CAP`, `CHAIN_POP_CAP` by tier, and the `keep` formula's constants.

### Events for Rendering, Camera and Audio

New fields on existing fx events: `debris`, `dust` and `ring` gain `z` (default 0), so a collapse's debris is at the building's depth.

| Event | Fields | When | Used by |
| :--- | :--- | :--- | :--- |
| `launch_depth` | x0, y0, x1, y1, z, b, dur, owner | a launch is aimed at a building (at the launch beat) | Camera (frame the flight and the building), Rendering (the fighter leaves the plane), Audio |
| `building_hit` | b, x, y, z, damage, ratio, outcome (`crack`, `wreck`, `collapse`), owner, link, n, sp, keep | the chosen building is hit | Rendering (the collapse animation, damage state), VFX, Camera (a 0.3 to 0.4 s hold), Audio |
| `building_fall` | b, x, z, w, h | a building's hp reaches 0 by any source | Rendering (any collapse), Audio |
| `chain_link` | from, to, x0, y0, z0, x1, y1, z1, dur, link | the fighter bursts through a building and is heading for the next (4b) | Camera (look ahead), Rendering (trail), Audio |

`building_fall` exists so a collapse from a beam or a blast animates the same way as a brunt.

The persistent state for a seek or a snapshot is `S.buildings` (hp, alive, popAlive), which Rendering already reads.

## 6. What changes for each system

| Owner | Work |
| :--- | :--- |
| **World** | The row table and archetype data in `data/biomes/`; the settlement generator (`terrain.gd` `genWorld` and `_row`); `z`, `d`, `row` on buildings; pop distribution; footing; the brunt damage function, the carry-on `keep` rule and the splash in `structures.gd`; the `building_fall` event; rim scaling |
| **Encounter** | The planner: extended predictor and the aiming search, the candidate scoring, the chain lookahead and its scoring, `sinceBrunt`, the `launch_depth` and `chain_link` events; the `stepLaunched` change (collision only with `aimB`, and the carry-on); removing the old plane-only BUILDING SMASH candidate and its nearest-building call |
| **Simulation** | The fighter fields (`aimB`, `aimX0`, `z`), the hash, the golden regeneration, the fx event records |
| **Rendering** | Buildings from the sim's `z` and `d` in place of `Z_BUILDING_FRONT`; the foreground row and its fade; the fighter mesh at `f.z`; collapse and damage animations from `building_hit` and `building_fall`; civilians at their row; row 4 backdrop; the footing |
| **Camera** | The flight into depth: frame the fighter, the building and the target, hold on each hit, look ahead along a chain; nothing more (depth barely changes the projected size: at zoom 0.5 and 720 px a fighter 170 units back is only about 6 percent smaller) |
| **QA** | The brunt-rate and personality tests (section 4) and the chain bands (4b); a test that no launch hits a building it was not aimed at or chained into; the collateral bands |
| **VFX, Audio** | Bursts and sounds from the three events; the `z` on debris and dust |

## 7. Readability rules for Rendering

- Row 0 (foreground) buildings fade to 35 percent opacity (dithered) when their screen rectangle overlaps either fighter's, so the fight is never hidden. They stay height-capped at 80 in the sim.
- Rows are drawn back to front with the fighters between rows 0 and 1. Beams (z = 6) are drawn over rows 1 to 3 and under row 0, which is faded anyway.
- A building marked as `aimB` (someone is flying at it) gets a subtle warning tint on its face during the flight, so the player can read that the wall is about to go. Optional; Art's call.
- The crater rim and the footing: a rim can lift a building's ground. Rendering extends the footing down to the building's lowest terrain.

## 8. Where it slots into the Wounds order

`docs/architecture/wounds-plan.md` has one sim editor at a time, each slice regenerating the goldens. Proposal (three small slices, none a Wounds dependency):

| Slice | Owner | What | Goes |
| :--- | :--- | :--- | :--- |
| **W-R** rim scaling | World (with Simulation holding the tree) | Section 1: XS, constants and one function | Any window, best right after S0 or S1 so it shares a golden regeneration |
| **B1** depth data | World (Simulation reviews) | `z`, `d`, `row`; the settlement generator with the row table; population split; no behaviour change to fights except that `damageArea` gains the z reach test. Goldens change because the state and world change | After S1 (Simulation is in `state.gd` and `hash.gd` there), before S2 |
| **B2** the brunt | Encounter (planner) with World (damage) and Simulation (fighter fields) | Sections 3 and 4: the collision rule change, aiming, scoring, `sinceBrunt`, events. Rates tuned by `batch.gd` | After S4 (Encounter is free; S2 and S3b sit in `sim/director/` and `launch.gd` will move for the region-break launches) |
| **B3** presentation | Rendering, Camera | Sections 5 to 7. Can start against B1's data before B2 lands, since the depth data is enough for the rows | In parallel with B2 |

B1 is safe to do early because it changes data and not choices. B2 must come after S2 and S3b because both edit the launch decision, and the region-break launches ("break launch and chase", `balance-targets.md` §10) must be designed together with the building choice: a break launch should be able to be a brunt.

`W1` (variable circumference) interacts with B1: the generator takes a planet record, so if B1 lands first, W1 gets it for free. If W1 lands first, B1 is written against the planet record and needs no rework.

## 9. Risks and open questions

- **Cost.** The aiming search adds up to about 4 flight predictions per building launch (the current predictor is a 240-step loop). At roughly 5 launches a minute this is a small spike per launch; Encounter should measure it against the tick budget and shrink the preselect to 1 per side if needed.
- **Blast reach in z.** `damageArea` ignores z today. If it keeps ignoring it, a beam over a city can wreck a row-3 tower 290 units behind the fight as easily as one on the plane, which is right for a beam through a city and wrong for a fist. Proposal: attacks that are hits or impacts test `|z|` with a reach of 260; beams do not.
- **Row 0 versus readability.** The fade is a fix, not a guarantee. If it still reads badly, drop row 0 to a sparse decorative row (no sim building), which costs the "in front of the fight" building and nothing else.
- **Population per building.** Splitting people over about twice the buildings lowers each building's population, so a brunt on a single building costs fewer lives than the current towers. That is part of why the casualty ramp is needed and why the 13-person tower is the number to watch.
- **Structure count.** 47 becomes about 110, and the structure-share band in `balance-targets.md` §4 needs Game Design's confirmation that it is a share.
- **Decided by Orb:** no rooftop cover; targeting weighted toward personality with drama on top; chains allowed; no extra anguish multiplier (Game Design's default). **Still with Orb:** the "often" band (Game Design's §5b), the chain casualty budget (`CHAIN_POP_CAP`) and the length caps by tier.
- **A chain is the biggest collateral event in the game.** Four towers in one attack is about 12 percent of the civilians. The tier caps and the casualty budget exist so that it stays a set piece at high tier and cannot happen at low tier; the collateral ramp must be designed with chains in mind.
- **Chain determinism and cost.** The runtime finds the next building with the same rule as the planner's lookahead (one predictor run per link, at most 3 links), so the plan and the outcome agree. Encounter measures the cost in B2.
- **Not in this note:** interiors, building types beyond tower and house, enterable buildings, and any destruction shape beyond height shrinking and collapse (Art and VFX own the look of a wreck).
