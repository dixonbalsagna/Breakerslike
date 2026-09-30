# Cities: varied, expansive, busy

Owner: World and Environment. Status: pitch and plan, docs only (2026-09-30), updated for Orb's answers (Questionnaire 4): two big cities, a huge skyline, busy life as render dressing, and cities covering more of the planet. Nothing here is in the sim. It answers Orb's playtest 2: "cities should be more varied, expansive, busy-looking", and the bug where buildings appear underwater, often in villages (section 6, which is a sim fix). Depth rows and floors are in `buildings-in-depth.md` and `b2-plan.md`; this note is about what settlements are made of and how they are generated.

**The rule that keeps it cheap:** the sim owns *layout and population* (which building stands where, how big, how many people, what it is worth), which are gameplay. Rendering owns *dressing* (window lights, signs, roofs, vehicles, smoke, crowds' density and animation), which is cosmetic, is derived from the building's `seed`, `kind`, `district` and `shape` and never enters the sim or its hash.

## 1. Today

A settlement is a span of the planet with one building kind on the front street (towers or houses) and up to three extra rows (`SETTLEMENTS` in `terrain.gd`). Heights and widths are uniform random inside one range; the only shape is a taller centre in Bellgate (`mid`). Seed 1: Bellgate 154 buildings (141 towers, 24,000 units long: 16 percent of the planet), Netmend 25, the outskirts 24, the far village 13; 216 buildings and 389 people in all, about two people a building, which reads as sparse. There is one kind of tower, no landmark, no street pattern, and no difference between a downtown and a suburb.

## 2. Districts

A settlement is a list of **districts** along its span; each district is a set of parameters, and the generator lays the rows of the settlement district by district. A district is data (`data/biomes/settlements.json`, schema in section 5):

| District | Where | Rows | Buildings | Height | Footprint | Gaps | People per building |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Downtown | the city centre | 0 to 4 | towers, skyscrapers, supertalls, one or two landmarks | 40 to 200 bh (median about 90), a few supertalls to 260, taller at the centre | narrow to medium (3 to 8 bh) | tight, avenues every 8 to 12 buildings | many |
| Mid-rise | around downtown | 0 to 3 | slabs and blocks, some towers | 12 to 45 bh | wide (5 to 10 bh) | medium | medium |
| Industrial | the city's edge, one side | 0 to 2 | warehouses, factories, chimneys (thin and tall, few people) | 3 to 10 bh, chimneys to 25 | very wide (8 to 20 bh) | wide | few |
| Harbour | at the coast | 0 to 1 | quays, sheds, cranes, a lighthouse | 2 to 10 bh, lighthouse 40 | mixed | irregular, along the shore line | few, some houses |
| Suburb | beyond mid-rise | 0 to 2 | houses, in short streets | 3 to 6 bh | small (3 to 5 bh) | regular | few |
| Village core | in a village | 0 to 2 | houses, a well or hall, a church-like landmark | 3 to 7 bh | small | irregular | few |
| Ruin | a district a fight has destroyed | (runtime) | rubble heaps | | | | none |

Generic names (Narrative names the places: Bellgate, Netmend); no franchise architecture. A city is downtown plus one or two mid-rise and suburb bands and an industrial edge; a harbour village is a harbour district plus a village core; the outskirts and the far village are village cores and suburbs.

### Variety inside a district

- **Height** is drawn from a district's log-normal (median, spread), with a per-district ceiling and the `mid` bump (`downtown` taller at its centre), not a flat range; a skyline needs a few outliers.
- **Footprint** has an aspect (width against depth): a slab is wide and shallow, a tower narrow and deep.
- **Shape** is a render hint on the building: `slab`, `tower`, `stepped` (setbacks), `spire`, `warehouse`, `chimney`, `house`, `shop`, `hall`. It does not change the sim's box; it lets Rendering build a stepped tower or a chimney from the same numbers, and it chooses which dressing applies.
- **Landmarks:** at most one or two per settlement, unique: a bell tower in Bellgate (the name's bells), a lighthouse in Netmend, a hall in a village core, a chimney stack in the industrial edge. A landmark is a building with `landmark = true`, a name key (for Narrative's barks), extra hit points (1.5 to 2 times) and a larger pop; its loss is a story beat ("the bell tower falls") and an event flag. Landmarks are where a villain would go for drama and a hero would defend; the planner's tallness and drama terms already see height, and a landmark adds a `LANDMARK_W` term.

## 3. Streets and depth

- **A street grid across the depth rows.** The x axis has **avenues** (wide gaps every N buildings, N by district) and the depth axis has **cross streets**: a row is a street's frontage, and the gaps between rows (the rows are 14 to 16 bh apart in depth) are the streets, so the city reads as blocks in the 2.5D view. In the generator, a district lays each row in *blocks* of `block_min` to `block_max` buildings with an avenue-sized gap between blocks, and the avenues line up across rows (the same x gap in rows 1, 2 and 3, so the skyline shows the gap and the fighters can fly down an avenue).
- **Alignment.** The shift between rows (`xoff`) and the gap alignment mask replace today's fixed offsets, so a row-2 building sits behind a gap in row 1 where it can (`buildings-in-depth.md` section 2). Plazas: a block with no building at a landmark's front.
- **Depth rows are unchanged** (`ROW_Z_BH`: +10, -8, -22, -38 bh); a district may use fewer rows (harbour: 0 to 1) and, for a large city, a fifth row (`-54 bh`) for a farther skyline (the back-row size and Camera risk in `b2-plan.md` applies: it is decoration-grade, not targetable, until Camera and the aim's cap are settled).

## 4. Size and busyness

**Two major cities, and more of the planet settled (Orb).** Orb's priorities are a huge skyline, busy life and cities covering more of the planet, with two big cities. The planet is 153,600 units (about 2,050 bh) around; the proposed layout, as shares of the length (the planet record's `SEG`, W1 makes it data):

| Span | Share | Notes |
| :--- | ---: | :--- |
| Ocean, west of the seam | 9% | one sea across the seam (12% east of it), 21% in all |
| Netmend, the harbour village | 5% | a harbour district and a village core |
| **Bellgate, the first city** | **17%** (26,000 units) | downtown, mid-rise, suburb, industrial edge, one or two landmarks |
| Plains | 3% | |
| Outskirts village | 4% | |
| Forest | 8% | canopy cover |
| Desert | 8% | |
| Mountains | 11% | ridge cover, the range between the cities |
| Far village | 3% | |
| **The second city, a harbour metropolis on the far coast** | **17%** | a big harbour and industrial district, its own downtown and skyline; Narrative names it |
| Plains, then ocean | 3% + 12% | |

**The settled share is about 46 percent of the length** (two cities 34 percent, villages 12 percent), up from about 26 percent today; each city is 15 to 20 percent (17 in the table, so 34 together). The two cities face each other across the mountains and the sea, so a launch or a chase from one to the other crosses the whole planet's variety, and the fights near a coast can be at either end of the sea. The second city also gives the hero's lure and the villain's seeking two very different places (the harbour's industrial edge has few people; the far downtown many).

**Buildings and people.** About 500 to 700 buildings on the current planet (from 216), with the spatial index (B1) making that free and the per-building cost a struct of about 20 fields. It is not a population change: the sim's people stay abstract crowd units (`pop0` about 400; the collateral bands are shares; Game Design has not asked for more), so the extra buildings hold fewer or emptier units, and industrial and harbour districts hold almost none (the places to fight without collateral, which the hero's lure reads: `popNear` is low there). Each district type sets a `pop_density` and each settlement is rescaled to its population share (as `terrain.gd` does today), so `pop0` stays put. A skyline of 300 towers holds a handful of people each; the crowds Orb wants to see are dressing (below).

**A huge skyline.** Downtown heights are pushed up (the table): 40 to 200 bh with supertalls to 260 bh (about 19,500 units), against today's 13 to 91 bh. Consequences: (1) the flight ceiling is 24,000 units, so supertalls stay under it (raise it if they go higher); (2) a tower of 200 bh has a hit-point value from its unscaled height (`h / WS * 6`, about 11,000) so it is tough, which is what floors and the brunt's punch-through are for; (3) floors: `floors = min(62, round(h / FLOOR_H))`, so above 124 bh a floor is a band of more than 2 bh (a 260 bh tower has 62 bands of 4.2 bh); (4) the back rows and the skyline need Camera's and Rendering's depth budget (a fifth row at -54 bh is proposed); (5) `F` is state (`Building.floors`), so nothing copies the formula.

**Floors and people (Orb).** People on each floor evacuate or are lost: a floor's occupants (`pop / F`) go through `WorldCollateral.kill`, so when a floor is punched or falls they die within the budget and flee past it (the `evacuate` event, which carries the floor for Rendering to run them out of that floor's windows and doors); otherwise the floors are mostly visual spectacle (windows, tunnels, pancakes), as Orb says.

**Busy-looking is dressing.** All render-only, from `seed`, `kind`, `district`, `shape` and the sim's `popAlive` and `alive`:
- **Crowd density.** Render draws several figures per crowd unit (Rendering's `CROWD` multiplier; the `evacuate` runners already work from the sim's counts), more in downtown and mid-rise streets, fewer in industrial ones; figures come out of doors and stand at crossings; the count follows `popAlive`, so an evacuated district visibly empties.
- **Traffic.** Vehicles on the avenues, trains or trams on a fixed line through the city, boats in the harbour, all cosmetic, deterministic from the planet seed and `S.T`, not in the sim; they scatter from an `evacuate` or a `crater` event near them and leave wrecks only if Rendering wants.
- **Lights and windows.** Window lights by floor occupancy and a day-night dressing (Art); broken windows from the sim's floor damage (`b2-plan.md` section 9); signs and billboards on downtown fronts; smoke from chimneys; cranes in the harbour.
- **Roofs, props, greenery** by district (Art).
None of it is in `S`, in the hash or in the goldens.

## 5. The generator and its data

- **Data:** `data/biomes/settlements.json`, one entry per archetype (city, harbour village, village, ...): the span (as a share of the planet or an absolute span for the fixed planet), a district list `{name, share_of_span, rows, kinds: [{kind, shape, weight}], height: {median, spread, max, centre_bump}, width: {min, max}, depth_aspect, block: {min, max, avenue_gap}, gap: {min, max}, pop_density, landmark: {name_key, hp_mult, pop_mult} or none}`, and the settlement's population share. Tools' schema and validator (D1's pattern) check it; every number is in the file, none in code.
- **Generation:** the same deterministic world stream as now (`SimRng.new(4242)` for the fixed planet; the planet record's seed later, W1), districts in order, rows front to back, blocks left to right. The front street keeps drawing first so its layout is stable when districts are added; extra rows draw after every front street (as now); landmarks are placed by rule, not by draw. Placement rejects (section 6) consume their draws, so accepting or rejecting a spot never shifts the rest.
- **Per building** (sim state; B1's fields plus): `district` (index), `shape` (render hint, an int), `landmark` (bool), floors `F` (derived from `h`). Hash the new fields; nothing else changes in the tick.
- **Procedural planets (W1).** The planet record lists settlement spans by archetype and the generator fills them; the same code makes a village or a metropolis from a different data entry.

## 6. Buildings appear underwater: the sim fix

**Diagnosis (seed 1, measured).** The scale window blurred the terrain across 4 x 97 columns (about 12,000 units), which moved the sea's edge inland of the biome boundary, and the settlement spans were not moved with it:
- **Netmend** (20,160 to 28,160): the ground is -773 at the west end, -434 at 20,960, -202 at 21,760 and rises to 0 only at about x = 24,000. **All 25 of its buildings have part of their footprint below sea level**, 9 of them by more than half a fighter height, and 3 buildings stand in the sea proper (`S.water` above zero). That is the "villages underwater" Orb saw.
- **Bellgate:** 28 of 154 dip a few units below 0 at the edges (the blend with the plains' noise); none by half a bh. **The far village:** 7 of 13 slightly. The outskirts: none.
The sim's ground is one heightfield for every row (the depth rows share it), so the depth rows are not the cause; Rendering's separate diagnosis (the drawn depth ground and water differing from the profile) may add to it.

**The fix (mine, in `terrain.gd`, in the next world window):**
1. **Placement rule.** A candidate building is accepted only if the minimum base ground over its footprint (its columns plus one either side) is at least `BUILD_MIN_GROUND` = 0.25 bh (19 units) above sea level, and the slope across the footprint is at most `BUILD_MAX_SLOPE` = 0.35 of its width. A rejected candidate still consumes its draws and the row's x advances by its width, so the layout of the others does not shift.
2. **The settlement platform.** Inside a settlement span the base ground is raised to at least `SETTLE_FLOOR` = 0.5 bh, with a smooth blend at the span's ends, so the towns sit on a shore that is above the water and flat enough to build on. Where the natural ground is deeper than that at a span's end (Netmend's west end), the span is **trimmed** to the first x where the ground reaches the floor (a coast inset), not filled in: a village never turns a sea into land.
3. **The waterline** is the sea filling to the shore: see the next subsection. The steeper-shore alternative (`shore_steep`) is held until Art and Rendering have seen a picture.
4. **Rows and crater bowls.** A crater's 3D bowl lowers the ground at depth (`sqrt(dx^2 + z^2) < R`), which only matters for special craters (R up to about 1,500 units) reaching the front street; footings take the highest ground under the footprint (`buildings-in-depth.md` section 2), which is Rendering's placement (it owns the drawn ground). If Rendering finds the rows still float or sink, the sim can provide a per-row ground query.
5. **Test.** No building's footprint has ground below `BUILD_MIN_GROUND` at generation; no building stands in `S.water`; population conserved per settlement; the front street's building order unchanged from the seed except for rejections. The count of rejected candidates is reported (Netmend loses most of its west half).

### The waterline: the sea fills to the shore (route chosen, 2026-09-30)

Rendering's diagnosis: the sea floods only where the base ground is below -240 (`WorldWater.RESERVOIR_BASE`) but its surface is at 0, so land beside the sea's edge sits up to 240 units below the water surface: 22,144 units of dry land below sea level on the east coast (50 buildings) and 4,512 on the west (6), the same for every seed (the layout stream is fixed): the drawn "slab". Two routes were on the table: a steep shore (the ground crosses from -240 to above 0 within a column or two) or filling every sea-connected column below 0. I measured the second (`shore.gd`, connected flood fill from the sea at several thresholds):

| Wet limit (sea-connected ground below this floods) | Extra sea (units) | Where |
| ---: | ---: | :--- |
| -240 (today) | 0 | |
| -75 | 2,208 | village 31 columns, plains 38 |
| -37 | 3,456 | village 45, plains 63 |
| **-19 (0.25 bh)** | **4,800** | village 87, plains 63 |
| 0 | 26,656 | village 303, plains 338, **city 192** |

**Decision: the sea fills every sea-connected column below `SHORE_WET` = -0.25 bh (-19 units).** A limit of 0 would flood 6,144 units of Bellgate's west end (the city ground dips below 0 where the blur meets the plains); a steep shore changes the terrain's look for Art to judge first. At -19 the sea gains 4.8 km of shallows, and the step between the water surface and the dry ground beside it is at most 19 units (a quarter of a fighter height, invisible against a 240-unit slab). Land above -19 and below 0 is a mud flat the sea does not reach; it keeps its 0.25 bh of "below sea level", which is what the test allows.
- **Rule.** `WET_GROUND` becomes `SHORE_WET` (-19). `RESERVOIR_BASE` stays -240 (the deep sea, instantly full by the ground; `seaAt`, the AI and the launch predictor keep reading it). Everything else of the water model is unchanged: water enters a column only from a wet neighbour, and only where the ground is below `SHORE_WET`.
- **Start of a match.** `WorldWater.init` fills the dynamic columns that are connected to the reservoir through ground below `SHORE_WET` to depth `-ground` (the 150 columns above), as the first version of the model did before the scale window.
- **Craters** at the coast flood a little more easily (any dig below -19 that connects to the sea), which is the natural rule; inland pits are still dry (no wet neighbour), and the flood test still applies.
- **Build first, with the placement and platform fix.** Settlements sit on a platform of at least 0.5 bh, so no building is ever below the new shoreline.
- **Tests (`probe.gd`).** (1) After generation, no dry column with ground below `SHORE_WET` is connected to the sea by ground below `SHORE_WET` (the flood fill is empty); (2) the step from a water surface to the dry column beside it is at most 19 units; (3) the initial wet set equals the connected flood fill; (4) the inland-crater and flood-connectivity tests of `craters-scorch-water.md` still pass with the new limit; (5) no building's footprint ground is below `BUILD_MIN_GROUND`.
- **Cost.** Coastal digs open water windows more often (the shallows are wider); the tick is measured before and after. Rendering's shore rule draws the result from `S.water` and needs no change.

## 7. Slot and cost

- **Placement fix (section 6)** is small and independent: first in the next world window; it changes the layout, so it regenerates the goldens.
- **Districts, streets and landmarks (sections 2, 3, 5)** are a generator rewrite plus data: an M-to-L slice after B2 (they do not touch the fight), best done before W1 so the planet record gets it; Tools' schema and Art's district looks first.
- **Dressing (section 4)** is Rendering's and Art's, in parallel from the data (no sim dependency beyond the new hint fields).
- **Cost:** generation time (a 500-building city is about 20 ms at `newMatch`), the tick unchanged (the index), hash size up by a few hundred building records.

## 8. Open questions

- **Orb (answered):** two big cities, each 15 to 20 percent of the planet, about 46 percent settled, a huge skyline. Still open: whether the harbour and industrial districts should be places to fight without collateral, as proposed.
- **Game Design:** pop stays abstract unless they ask; the bands are shares, so more buildings holding fewer people is neutral. A larger `pop0` would make the meters' `425 / pop0` rule do real work.
- **Art and Narrative:** district looks and names; the landmarks' names (a bell tower for Bellgate).
- **Camera:** a fifth row at -54 bh, the fighter's on-screen size in the deep rows, and framing a 260 bh skyline.
- **Narrative:** the second city's name and its districts.
- **Encounter:** two cities change the lure and the fight-location rows (the location bands assume one city); rerun `tempo.gd` when the layout lands.

## 9. As built: the fixes slice (2026-09-30)

Code: `terrain.gd` (`_platforms`, `_footOk`, `_row`), `water.gd` (`SHORE_WET`, `init`), `collateral.gd`, checks in `sim/world/tools/probe.gd` ("placement and the shore").
- **Platforms and trimmed spans.** Each settlement's span is trimmed from both ends to where the natural ground first reaches `TRIM_G` = -1 bh (the sea is never filled in), and the ground inside is lifted to at least `SETTLE_FLOOR` = 0.5 bh, blended smoothly over 24 columns at each end.
- **Placement rule.** A candidate building is accepted only if the ground under its footprint (and one column either side) is at least `BUILD_MIN_GROUND` = 0.25 bh and varies by at most 0.35 of its width. A rejected candidate still consumes its draws and its people stay in the settlement's total (rescaled onto the buildings that remain), so `pop0` is unchanged: 390. Seed 1: 196 buildings (was 216): Netmend 15 (was 25), Bellgate 146, the outskirts 24, the far village 11. The lowest ground under any building is 22.5 units (0.3 bh); none stands in the water.
- **The waterline.** The sea fills every sea-connected column below `SHORE_WET` = -0.25 bh: the start water is the deep reservoir plus the 102 connected shallow columns. Measured: 0 dry columns below the limit are connected to the sea, the start water equals the connected flood fill, and the largest step from the water's surface to the dry ground beside it is 18.2 units (0.24 bh), down from 240. The steep-shore alternative stays held.
- **Rendering's shore rule** draws from `S.water` and needs no change; the terrain under the settlements is now flat at 0.5 bh, so the platforms have a visible plateau and a blended edge.