# Cities: varied, expansive, busy

Owner: World and Environment. Status: pitch and plan, docs only (2026-09-30). Nothing here is in the sim. It answers Orb's playtest 2: "cities should be more varied, expansive, busy-looking", and the bug where buildings appear underwater, often in villages (section 6, which is a sim fix). Depth rows and floors are in `buildings-in-depth.md` and `b2-plan.md`; this note is about what settlements are made of and how they are generated.

**The rule that keeps it cheap:** the sim owns *layout and population* (which building stands where, how big, how many people, what it is worth), which are gameplay. Rendering owns *dressing* (window lights, signs, roofs, vehicles, smoke, crowds' density and animation), which is cosmetic, is derived from the building's `seed`, `kind`, `district` and `shape` and never enters the sim or its hash.

## 1. Today

A settlement is a span of the planet with one building kind on the front street (towers or houses) and up to three extra rows (`SETTLEMENTS` in `terrain.gd`). Heights and widths are uniform random inside one range; the only shape is a taller centre in Bellgate (`mid`). Seed 1: Bellgate 154 buildings (141 towers, 24,000 units long: 16 percent of the planet), Netmend 25, the outskirts 24, the far village 13; 216 buildings and 389 people in all, about two people a building, which reads as sparse. There is one kind of tower, no landmark, no street pattern, and no difference between a downtown and a suburb.

## 2. Districts

A settlement is a list of **districts** along its span; each district is a set of parameters, and the generator lays the rows of the settlement district by district. A district is data (`data/biomes/settlements.json`, schema in section 5):

| District | Where | Rows | Buildings | Height | Footprint | Gaps | People per building |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Downtown | the city centre | 0 to 3 | towers, skyscrapers, one landmark | 20 to 90 bh, taller at the centre | narrow to medium (3 to 7 bh) | tight, avenues every 8 to 12 buildings | many |
| Mid-rise | around downtown | 0 to 2 | slabs and blocks, some towers | 6 to 20 bh | wide (5 to 10 bh) | medium | medium |
| Industrial | the city's edge, one side | 0 to 2 | warehouses, factories, chimneys (thin and tall, few people) | 3 to 10 bh, chimneys to 25 | very wide (8 to 20 bh) | wide | few |
| Harbour | at the coast | 0 to 1 | quays, sheds, cranes, a lighthouse | 2 to 8 bh, lighthouse 25 | mixed | irregular, along the shore line | few, some houses |
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

**City size relative to the planet.** Bellgate is 16 percent of the length now. Proposal: a planet's settled share is a planet-record parameter (default 25 to 35 percent of the length in settlements, up from 26 percent) with the city 15 to 20 percent alone, so the world has more places to fight. That means about 400 to 600 buildings on the current planet (from 216), with the spatial index (B1) making that free and the per-building cost in the sim a struct of about 20 fields. It is not a population change: the sim's people are abstract crowd units (`pop0` about 400; the collateral bands are shares), so the extra buildings hold fewer or emptier units, and industrial and harbour districts hold almost none (they are the places to fight without collateral, which the hero's lure reads: `popNear` is low there). Each district type sets a `pop_density` and the settlement is rescaled to its population share (as `terrain.gd` does today), so `pop0` stays put.

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
3. **Coasts get a beach.** The blur made the shore slope gentle over 6,000 units; an optional `shore_steep` step (a local sharpening of the sea-to-land transition around the sea threshold) restores a clean waterline. This is a terrain look change, so Art and Rendering see it first.
4. **Rows and crater bowls.** A crater's 3D bowl lowers the ground at depth (`sqrt(dx^2 + z^2) < R`), which only matters for special craters (R up to about 1,500 units) reaching the front street; footings take the highest ground under the footprint (`buildings-in-depth.md` section 2), which is Rendering's placement (it owns the drawn ground). If Rendering finds the rows still float or sink, the sim can provide a per-row ground query.
5. **Test.** No building's footprint has ground below `BUILD_MIN_GROUND` at generation; no building stands in `S.water`; population conserved per settlement; the front street's building order unchanged from the seed except for rejections. The count of rejected candidates is reported (Netmend loses most of its west half).

## 7. Slot and cost

- **Placement fix (section 6)** is small and independent: first in the next world window; it changes the layout, so it regenerates the goldens.
- **Districts, streets and landmarks (sections 2, 3, 5)** are a generator rewrite plus data: an M-to-L slice after B2 (they do not touch the fight), best done before W1 so the planet record gets it; Tools' schema and Art's district looks first.
- **Dressing (section 4)** is Rendering's and Art's, in parallel from the data (no sim dependency beyond the new hint fields).
- **Cost:** generation time (a 500-building city is about 20 ms at `newMatch`), the tick unchanged (the index), hash size up by a few hundred building records.

## 8. Open questions

- **Orb:** how large should cities be against the planet (section 4: 15 to 20 percent for the biggest, 25 to 35 percent settled)? Should there be one big city or two? Should the harbour and industrial districts be places to fight without collateral, as proposed?
- **Game Design:** the collateral bands are shares, so more buildings holding fewer people is neutral; do they want more people (a larger `pop0`, hence the meters' `425 / pop0` rule doing real work)?
- **Art and Narrative:** district looks and names; the landmarks' names (a bell tower for Bellgate).
- **Camera:** a fifth row at -54 bh and the fighter's on-screen size in the deep rows.
