# Districts, streets, landmarks and the two big cities: the build plan

Owner: World and Environment. Status: plan, docs only (2026-09-30). Nothing here is in the sim yet. The pitch and Orb's answers are in `cities.md` (sections 2 to 5); this note turns them into slices, a data shape, a generator, sim state, tests and an order of work, and lists what each other director has to give or take. It follows B2 (`b2-plan.md`): brunts, floors and chains already read `Building.floors`, `row`, `z`, `h` and `pop`, and nothing below changes how they work.

The EP's order: the sim window for this follows M1b and Encounter's location slice. Section 8 lists the work that does not need the window and can start now.

## 1. Two slices

| Slice | What | Planet layout | Goldens | Sim window |
| :--- | :--- | :--- | :--- | :--- |
| **D1** | Districts, streets, landmarks, the new building fields, the data file and the generator that reads it; population re-based. | Unchanged: Netmend, Bellgate, the outskirts and the far village stay where they are. | regenerated once | yes |
| **D2** | The planet's segments become data (the planet record's `SEG`, W1's first step) and the second city, a harbour metropolis on the far coast, goes in; the terrain's hard-coded positions become derived. | Changed: the tail of the planet (from the mountains' end) is re-laid, and the forest, desert and ocean shares shrink a little (section 5). | regenerated once | yes, after D1 and after Encounter's rerun of the location bands |

D1 first, because D2 is the same generator given a second archetype. Each slice lands whole (code, data, schema, probe, docs) and regenerates the goldens once, after the EP's "tree clean".

## 2. D1: data

`data/biomes/settlements.json`, one entry per archetype, read once at `newMatch` (a loader in `sim/world/settlements.gd` parses and validates it, caches the result, and draws nothing). Every number below is in the file; none is in code.

```
{ "settlements": [
  { "id": "bellgate", "archetype": "city", "span": [x0, x1], "pop_share": 0.62,
    "districts": [
      { "name": "downtown", "share": 0.40, "from": "centre", "rows": [1, 2, 3],
        "kinds": [ { "kind": "tower", "shape": "tower", "w": 1.0 }, { "kind": "tower", "shape": "stepped", "w": 0.4 },
                   { "kind": "tower", "shape": "spire", "w": 0.15 } ],
        "height_bh": { "median": 90, "spread": 0.45, "max": 260, "centre_bump": 0.5 },
        "width_bh": [3, 8], "depth_aspect": [0.6, 1.1],
        "block": { "min": 8, "max": 12, "avenue_bh": [10, 14] }, "gap_bh": [0.4, 1.6],
        "pop_density": 1.0, "landmarks": [ { "key": "bell_tower", "count": 1, "place": "centre", "hp_mult": 1.8, "pop_mult": 1.5 } ] },
      { "name": "mid_rise", ... }, { "name": "suburb", ... }, { "name": "industrial", ... } ] } ] }
```

- **Kinds stay `tower` and `house`** in the sim (the two box types the brunt, floors and collateral already know); a district adds a `shape` hint (an int from a list in the file: slab, shaft, stepped, spire, warehouse, chimney, house, shop, hall, quay, crane, lighthouse) that only Rendering reads. New sim kinds are not needed.
- **Units.** Heights, widths and gaps in fighter heights (bh = 75 units) so Art and Camera read them; the loader converts once.
- **Span.** In D1 the span is the current one (original coordinates, then the platform trim of `_platforms`). In D2 it comes from the planet record.
- **Schema and validator.** `tools/schemas/settlements.schema.json` and a check in `tools/validate.js` (Tools' files: a grant, section 7). The validator checks ranges, that district shares sum to 1, that `rows` are in 0 to 3, that every `shape` is known, and that landmark counts fit.

## 3. D1: the generator

It replaces `_row` and the `SETTLEMENTS` constant in `terrain.gd` (mine). The platform, the footprint rule (`_footOk`), the spatial index and the depth row centres (`ROW_Z_BH`) are kept as they are.

1. **Streams.** One derived stream per settlement, district and row: `SimRng.deriveSeed(4242, "settle:<id>:<district>:<row>")`. A district added later, or a number changed in another district, never shifts the draws of the rest. (This breaks draw-for-draw equality with today's layout on purpose: D1 regenerates the goldens anyway, and the front street no longer needs to be special.)
2. **Districts along the span.** The file lists a settlement's districts west to east; each takes its `share` of the trimmed span in order (as built in the scratch generator: explicit order is simpler than "from the centre"). Height's centre bump uses the settlement's centre, not the hard-coded 3100.
3. **Blocks and avenues.** A district is cut into blocks of `block_bh` (a length, as built) with an avenue of `avenue_bh` between them. The avenue x positions are decided once per district (from the district's stream) and used by **every row**, so an avenue is a gap through the whole depth of the city, and a row-2 building never stands in an avenue. Between blocks inside a row, gaps are drawn from `gap_bh`.
4. **Rows.** Each district lists the rows it fills (`rows`); a harbour fills 0 and 1, an industrial edge 1 and 2, a downtown 1 to 3. Row offsets (`xoff`) come from the district's stream so the back rows show the gap pattern of the front ones. Row 0 keeps its low-height cap.
5. **Heights.** Drawn from the district's log-normal (median, spread) and clamped to `max` and to `CEILING / 1.25`; the centre bump raises downtown toward the middle so the skyline has a silhouette. Floors are derived from `h` by `WorldBrunt.floorCount` as now.
6. **People.** `pop_density` times footprint area gives a weight per building; the settlement's population is `pop_share` of `pop0`, and the weights are turned into whole people by the largest-remainder rule (so the sum is exact, and industrial buildings may hold 0). `pop0` itself is raised (section 6).
7. **hp** as now: from the unscaled height (`h / WS * 6` for towers, `* 3` for houses), times the landmark's `hp_mult`.
8. **Landmarks** are placed by rule, not by draw: `centre` puts it on the building nearest the district's centre; `edge` at a district end; `shore` at the coast end of a harbour. The chosen building is overridden (height at least `1.3 x` the district median, `landmark` set, hp and pop multiplied) and never replaced by a later candidate. A plaza (no building in front, in rows 0 and 1) is cleared in front of a landmark.
9. **Rejected candidates** (footprint not dry or too steep) still consume their draws and their people, as now.

## 4. D1: sim state, events, planner

- **Building fields** (granted lines in `sim/core/state.gd` and `hash.gd`, Simulation's files): `district:int` (index into the settlement's list), `shape:int`, `landmark:int` (0 none, otherwise 1 plus the index into the file's landmark list; the key is data). All three are set at generation and hashed; nothing in the tick reads `shape`.
- **Events** (`fx.gd`, `view/fx.gd`, grants): `building_fall` gains `landmark` (the int) so Narrative's and Audio's barks and Camera's hold can react to "the bell tower falls"; no new event. The M1 mood inputs do not change. **Decided (Game Design): a landmark's fall is a +10 mood input, once per landmark**, on top of the launch and casualty impulses. `building_fall.landmark` feeds M1's impulses through a new `mood.json` key, which Simulation's M1b shape needs to take (and Tools' schema for `mood.json` lists it).
- **Planner** (`launch.gd`, Encounter's review): `bruntScore` gains `BRUNT_LANDMARK_W * landmark * (-A.care)` so the villain seeks a landmark and the hero does not choose one; the brunt candidates already cover any row, and a landmark stays a candidate by the cheap score (`_cheap` gains a term for it so it is not cut by `BR_PRESELECT`).
- **Collateral, brunts and floors** need no change. Checked points: a 260 bh tower has 62 floors, each band 4.2 bh, so a fighter's body (1 bh) clears one or two whole bands, a hole larger than the body (section 9, risk 2); the flight ceiling (24,000 units) is above the tallest allowed building (19,500).

## 5. D2: the planet layout

The hard-coded positions in `terrain.gd` (the mountain envelope 6500 to 7600, the forest's trees 4530 to 5470, the tower height's centre 3100) and `WorldBiomes.SEG` become data read from the planet record, with the derived values computed from the segments. The proposed layout keeps everything up to the mountains where it is and re-lays the tail, so the terrain, the existing biomes' coordinates and the settled west half do not move; the shares in `cities.md` section 4 are the target, and this is the smallest change that reaches them:

| Span (original units of 9,600) | Today | D2 |
| :--- | :--- | :--- |
| 0 to 1200 ocean; 1200 to 1800 Netmend; 1800 to 2350 plains; 2350 to 3850 Bellgate; 3850 to 4500 outskirts; 4500 to 6500 forest and desert; 6500 to 7600 mountains | as is | as is |
| 7600 to 8000 far village | 4.2% | 7600 to 7900 (3%) |
| 8000 to 8300 plains | 3.1% | 7900 to 8150 (2.6%) |
| the second city | none | 8150 to 9300 (12%): **a city of the same length as Bellgate scaled to 1,150 units; the doc's 17% needs the forest or the desert to shrink**, see the question in section 9 |
| ocean | 8300 to 9600 (13.5%) | 9300 to 9600, then across the seam 0 to 1200: 15.6% in all |

The decision this needs from Orb, through the EP: a 17% second city (the doc's table, 1,630 units) needs about 5 points more of the planet than the tail has, so the forest and the desert each shrink from 10.4% to about 8% and the mountains move with them; a 12% city (as above) leaves the west half untouched but is smaller than Bellgate. My recommendation: the 12% version first (a city that can be tuned without re-laying the planet), then grow it if Orb wants. The settled share becomes about 44% with the 12% city and about 49% with the 17% one (from 26%).

The second city is a **harbour metropolis**: `archetype: city_harbour`, districts harbour (coast end, rows 0 to 1, cranes, sheds, a lighthouse landmark), industrial (next to the harbour, few people), downtown (the big skyline, a supertall landmark), mid-rise and suburb. It gives the hero's lure and the villain's seeking two different places (a harbour with few people, a downtown with many). Narrative names it and its landmarks.

## 6. Population and scale

- **Count.** With four depth rows and downtown footprints of 2 to 5 bh, a city of 23,000 units holds about 140 buildings (measured, section 11). D1 is therefore about variety, height and structure, not count: the planet goes from 196 buildings to about 190, with a much taller skyline and whole districts. The count roughly doubles in D2 (a second city, about 330 in all), and `cities.md`'s 500 to 700 needs a fifth row or a longer second city, which is held for Camera. The generator prints the counts per district; a cap `BUILDING_CAP` = 800 makes the probe fail if a data edit overshoots.
- **Pop.** `pop0` is about 390 today, and with 300 to 500 buildings each holds about one person or fewer. The meters and the collateral bands are shares (`425 / pop0`, budgets as shares of `pop0`), so a larger `pop0` changes nothing the player feels except the casualty counter. **Decided (Game Design, via the EP): `pop0` about 1,800 whole people**, set by `pop0`, `pop_share` and the density in the file. At D1's 190 buildings that is about 9 a building (downtown towers up to 40, a house 1 to 3); about 4 after D2. The mood module's casualties-per-person input (`cas_perPerson * cas_popRef * casualties / pop0`) is already normalised.
- **Cost.** Generation is about 20 ms more at `newMatch`; the tick is unchanged (the spatial index; `WorldCollateral.tick` loops buildings only once a second at most and I will measure it); the hash grows by a few hundred building records (measured in D1).

## 7. Who gives what, who takes what

- **Tools:** the `settlements.json` schema and its check in `validate.js` (before the window: I supply the field list in section 2). **Art:** the district looks, the shape list, the landmark silhouettes (before D1 lands, because the shapes are a closed list in the file). **Narrative:** the second city's name, district names and the landmark keys with their barks. **Rendering and Camera:** the shape, district and landmark fields arrive in `Building` (section 4); Camera on framing a 260 bh skyline and the far rows; nothing changes in the sim's rows (a fifth row stays out until Camera's answer). **Encounter:** `LANDMARK_W` in `bruntScore` and `_cheap` (a review); in D2, the location bands and `tempo.gd` rerun for two cities. **Game Design:** `pop0`; whether a landmark's fall is a mood input; whether the harbour and industrial districts should be the places to fight without collateral (as proposed). **QA:** the building-count and district-coverage rows, and the brunt share with the denser city. **Simulation:** reviews the granted lines in `state.gd`, `hash.gd`, `fx.gd` and `view/fx.gd`.

## 8. Order of work

Before the window (no golden, nothing in the tick): (1) the schema field list to Tools; (2) `settlements.json` and its loader, unused, so the data and the validator land first; (3) a scratch generator run that prints building counts, heights and the skyline per district, so Art and Camera see the city before the sim changes.

In the D1 window: (4) the generator behind the data, with the new fields, hashed; (5) the landmark rule and the `building_fall.landmark` event; (6) population re-based and `pop0` set; (7) probe (below), `probe.gd` reruns, batch of 100 matches for collateral, brunts, length and KAI; (8) docs and the one golden regeneration after "tree clean". D2 window: (9) the segments as data and the derived values; (10) the harbour archetype and the second city; (11) the same tests and the location rerun.

## 9. Tests, acceptance and risks

**Probe checks (hard):** every building's footprint passes `_footOk` and none is in `S.water`; the sum of `pop` equals `pop0` (exactly); every district's building count and heights are inside its data ranges; every avenue x is a gap in every row that uses it; landmarks exist once each, tall enough, with their multipliers; no building above `CEILING / 1.25`; the count is at most `BUILDING_CAP`; the layout is identical on two runs and one district's edit leaves the others' buildings unchanged; `building_fall` carries `landmark`. Plus the existing B2 checks on the new city (plan equals outcome over 200 launches; chains cross avenues), parity, determinism, seam sweep, `npm test`, the validator.

**Acceptance for D1:** the above, the 100-match default-arm probe (collateral, brunt share, building pick, length, KAI) with the change reported against B2's numbers, and Art and Camera shown the scratch skyline before the window. **For D2:** the same, plus two cities' worth of settled share (about 44%), Encounter's location bands rerun, and the seam unchanged.

**Risks.** (1) The layout changes every stream-dependent golden and the location and tempo numbers (Encounter's floors assume one city). (2) Floor bands of 4.2 bh on supertalls make a brunt's hole bigger than a fighter; the fix, if it reads badly, is a two-word floor mask (124 floors) or scaling `HIT_FLOORS` by band height; decided after the probe and a look. (3) More buildings in reach raise the brunt share and the collateral; that is the intent for the brunt band (8 to 20%) but it moves the collateral band, so Game Design re-checks it. (4) `pop0` changes what the HUD counter shows. (5) The derived-stream change makes every seed's layout differ from today's; any QA baseline built on seeds 1 to 100 re-baselines. (6) The 17% city means shrinking the forest and desert; held for Orb.

## 10. Open questions for the EP

1. Second city at 12% (recommended first) or 17% (moves the forest, desert and mountains)?
2. (Answered: `pop0` about 1,800 whole people.)
3. (Answered: a landmark's fall is a +10 mood input, once each.) Does Audio or Narrative want a flag beyond `building_fall.landmark`?
4. Do the harbour and industrial districts stay the no-collateral places to fight (Orb, open in `cities.md`)?

## 11. Scratch results (2026-09-30, seed 1, before the window)

`data/biomes/settlements.json` and `sim/world/settlements.gd` (`WorldSettle`: load, validate, generate; unused by the sim, plain dictionaries, no `S.rng`) exist, and `sim/world/tools/skyline.gd` prints the report and writes `docs/world/d1-skyline-bellgate.svg` and `d1-skyline-planet.svg` (true-scale front elevations: row 0 to 3 in greys, landmarks red). Run: `godot --headless --path . --script res://sim/world/tools/skyline.gd`.

- **Buildings:** 188 (196 today): Netmend 12, Bellgate 138, the outskirts 26, the far village 12; 1,800 people. Bellgate by district: suburbs 17 and 30, industrial 5, mid-rise 10 and 16, downtown 60 (20 a row, rows 1 to 3).
- **Skyline:** downtown median 88 bh, tallest 245 bh (the ceiling share is 272); mid-rise median 35; suburbs 4; the bell tower 150 bh, the chimney stack 45 bh, the lighthouse 40. A run of tight towers with avenue gaps reads as a skyline in the SVG.
- **People:** downtown holds about 740 of Bellgate's 1,260 (up to 42 in a tower); suburb houses 1 to 3. The hero's "avoid populated areas" term and the villain's seeking now have a clear centre of mass.
- **What the data check does:** shares sum to 1, rows 0 to 3, kinds tower or house, every shape on the closed list, landmark keys, places and rows valid, heights under the ceiling share, `pop_share` sums to 1.
- **Not yet in the scratch:** fdmg/fmask, the hash, the Building fields, the `building_fall.landmark` event and the planner term (the D1 window); Tools' schema (`data/biomes` has none: the validator warns).

## 12. Orb's playtest 8: formations, islands, vehicles (folded into D1 and D2, 2026-09-30)

Orb: (a) large mountains become background decoration, and fighters careen through small hills, mesas, rock formations, large trees and other natural formations, which can be brunt targets like buildings; (b) one big ocean with small islands and small island villages; (c) locals on bikes and in cars where the scale allows, vehicles as fast-evacuating civilians, parked cars as throwable objects for the context button. The generator, data pattern, depth rows, brunts and floors from D1 and B2 carry all three. New slices: **N1 formations** (shares D2's window and its one golden regeneration), **I1 islands** (in D2), **V1 vehicles and props** (after D2).

### (a) Formations as brunt targets (N1)

- **Same box, new kinds.** A formation is an entry in `S.buildings` with a natural kind: `mesa`, `rock` (a stack or boulder group), `spire` (a hoodoo or sea stack), `bigtree`, and later `knoll`. It has `x`, `w`, `d`, `h`, `row`, `z`, `maxhp`, `floors`, and `pop` 0. B2 needs no change: `WorldBrunt.candidates`, `aim`, `chainPlan`, `hit`, splash and the floors all read those fields. A mesa's floors are **strata** (a hard cap layer, soft layers below), so a brunt punches, cracks or dents a mesa exactly as it does a tower; a boulder has one floor; a big tree has a few and snaps rather than punches (low hp, a high keep); a spire is thin and chains like a row of towers.
- **Hero and villain.** Formations hold no people: the hero's care term finds them the best brunt targets (no casualties, so the hero can take brunts the city denied him) and the villain scores them below a populated tower but above nothing. This is the lever for the brunt band: only about 9% of launches have a building in reach today, because fights happen in the forest, the desert and the mountains where there are none.
- **Data.** `data/biomes/formations.json` (schema in Tools' pattern, `biomes.formations/1`): per biome a density per 1,000 units, size distributions in bh (height, width, depth, aspect), the kinds and weights, clusters (a run of 3 to 12 near each other), the depth rows used, hp per bh, strata count, and a rubble weight. The generator is D1's: one derived stream per biome and row, a fixed number of draws per candidate, a footprint rule (`_footOk`), no S.rng. Formations are placed after settlements and never inside a settlement span.
- **What falls.** A felled formation uses the `building_fall` event with its kind (rock burst, tree snap, mesa slump) and leaves a heap by the repose-limited rule of the terrain audit (T1 to T3, `terrain-audit.md`); the heap's material can later spawn throwable chunks (V1).
- **Mountains.** The mountain relief leaves the fighter plane: the biome becomes `highlands`, with a base relief capped at about 8 bh (hills and plateaus), and the tall ranges become a backdrop that Rendering and Camera draw from a profile in the planet record (no sim state, no hash). In the sim: the MOUNTAINSIDE launch candidate and `RIDGE BORE` keep their biome key but land on hills and rock rather than a 140 bh wall (Encounter's call whether MOUNTAINSIDE stays or becomes a rock target); hiding in ridge cover stays held with the stealth fighter. Small hills are heightfield relief, smooth by the repose rule: a launched fighter slides up and over them as now. "Careening through" a hill is done by the formations on and around it.
- **Cost.** Terrain and a `WorldFormations` module (about 300 lines, the settlements generator generalised), the data and its schema, a probe, a golden regeneration. Count: about 150 to 300 formations on the planet (a forest of 40 big trees, 30 mesas in the desert, 60 rocks and spires on the highlands, sea stacks), each a 20-field struct like a building, so the index and tick cost are unchanged and the hash grows by a few hundred records. Rendering and Art draw the kinds (a closed list, as for shapes); Camera needs no new row. Encounter reruns the location and brunt bands (the brunt share should rise well above 5%).

### (b) One ocean, islands and island villages (I1)

- The sea is already one arc across the seam. D2 keeps it as one and sets its share (26% today; I would not grow it unless Orb asks, because the settled share and the second city compete for the same length).
- `data/biomes/islands.json`: a list of `{x (original units), radius_bh, height_bh, shape (round, long, crescent), village (settlement id or none), formations (a recipe id or none)}`. The generator raises the base ground in a smooth cone over the sea floor, steep enough that the shallows (the -19 unit limit) are crossed within a few columns, to a flat top at `SETTLE_FLOOR` for a village. Six to ten islands from 6 to 40 bh across, three with a village of 4 to 10 buildings (a harbour district, a lighthouse landmark, a few boats as dressing), the rest bare or with rocks and a tree.
- A village on an island is a `settlements.json` entry with `archetype: island_village` and its `span` at the island; the D1 generator and its footing rule need nothing new. The water model needs nothing new either: the base ground is dry above `SHORE_WET`, and the sea fills around it by the flood fill.
- It gives the ocean fights, which dominate the hero's lure, something to fight over (islands are brunt targets and set pieces) and it spreads the villain's seeking beyond the two cities.
- **Cost.** A terrain pass and the data, probe checks (every island dry, every village above the shore, no island closes a sea route), and Encounter's location bands (the ocean biome gains land). Island depth rows are not needed.

### (c) Vehicles and props (V1)

- **Where the scale allows.** The front street between row 0 (z +10 bh) and row 1 (z -8 bh) is a road along x, and the fighter plane (z 0) runs down it. A car is about 2.5 bh long and 1.2 bh tall (190 by 90 units), a bike 1 bh: big enough to see and to throw. Vehicles belong on the front street of every district whose data gives them a `vehicle_density`; the avenues between blocks are cross streets, where they queue.
- **Fast evacuees (sim, small).** A district's data gets `vehicle_share` (the share of its people who leave by car or bike). The collateral module's district flight (FLIGHT_MAX 0.4 and the shelter relocation) uses a faster flight for that share, and the `evacuate` event carries a `vehicle` count so Rendering can draw cars driving off the avenue; the people count and the budgets are unchanged. Cost: a few lines in `collateral.gd` and one event field. All other traffic, bikes, boats and trams stay dressing (`cities.md` section 4), scattering from `evacuate` and `crater` events.
- **Parked cars as throwable props (a new system).** `S.props`: a list of `{kind (car, bike, boulder, trunk, lamp), x, z, y, vx, vy, mass, alive, held}` placed by data along the front street (parked cars at about 2 per 100 bh in a city, fewer in a village) and spawned from destruction (a boulder from a felled rock, a trunk from a snapped tree, a car wrecked into the road by a collapse). The context button picks the nearest prop within reach, holds it, and throws it as a launch-like object: a ballistic flight (the same integration as a launched fighter), damage to a fighter it hits (by mass and speed), a brunt on the building or formation it hits (as a `hit` with the prop's damage), and casualties through `WorldCollateral.kill` when it lands among people. `WorldProps` (mine) owns the state, flight and damage; Combat and Controls own the button and the grab-and-throw choreography; the director's planner and the mood module get a `prop_hit` event to consume if they want.
- **Cost.** Larger than (a) and (b): a new sim system (about 300 lines), hashed state (a few hundred props, mostly asleep), a per-tick step only for held and thrown props, a probe, one golden regeneration, and cross-director work (Combat's context-button spec, Controls' mapping, Rendering's and Art's prop models, Audio). It should wait for Combat's grab-and-throw design; I can build the prop state, placement and flight first, with the data and the probe, so Combat has something to call.

### Order and where it lands

| Slice | Needs | Window |
| :--- | :--- | :--- |
| D1 districts, streets, landmarks (with `vehicle_density` and `vehicle_share` fields in the data, unused until V1) | grants in section 4 | D1 window |
| Terrain fixes T1 to T4 (`terrain-audit.md`) | only `sim/world` files (mine) | D1 window (one regeneration with D1) |
| D2 planet layout and second city; I1 islands; mountains to highlands | Encounter's location rerun; Camera and Rendering for the backdrop | D2 window |
| N1 formations | Art and Rendering for the kinds; grants as D1 (kind in `fx.gd` events) | D2 window (same regeneration) |
| V1 props and fast evacuees | Combat and Controls (the button), Art, Audio | after D2 |

Open questions: (1) does Orb want the tall ranges as a pure backdrop (my reading) or as a visible but unreachable far row; (2) should MOUNTAINSIDE stay as a launch candidate (landing on highland rock) or be replaced by the formation brunts (Encounter); (3) V1's context-button choreography is Combat's call.

## 13. Revision for fight lanes (ADR 0009, 2026-10-01)

`fight-lanes-world.md` is the lane plan. It changes this plan as follows; sections 2 to 4 and 11 above are superseded where they disagree.

- **Blocks on real footprints (section 3).** A district is laid in the four lanes of the band, not on today's four row centres: block row 1 (z -4 to -12 bh, flush to the front street), block row 2 (z -18 to -27, flush to the back street), the foreground and background rows as scenery (z +10 and -38). A building's `z` is its footprint centre inside its lane (no random jitter), its `d` is `lane width x depth_fill`, and its footprint always lies inside its lane, so **the two streets (z +5 to -4 and -12 to -18) are free of footprints along the whole district**. Avenues are the same x intervals in both block rows and are the cross streets. Data: `depth_aspect` becomes `depth_fill`; `frontage` (front, back, free) is new; `rows` name lanes. `row_h` stays.
- **State (section 4):** no new field. `z`, `d` and `row` carry the lane; the building's lane is derived from `z`. The lane table is derived data (`S.lanes`), not hashed. **Brunt candidates are limited to rows 1 and 2** (the band); rows 0 and 3 are scenery that blasts and beams still damage.
- **Planner (section 4):** unchanged beyond the candidate filter; the `LANDMARK_W` term stands.
- **Traffic (section 12c and `cities.md` section 4) is cosmetic and lives in the streets:** vehicles drive in the carriageways (front street 4.6 bh wide, back street 4 bh), foot traffic on the sidewalks (1 bh at each street edge), both placed by Rendering from the lane table, scattering on `evacuate`, `crater`, `building_fall` and `launch_depth`, and never in the sim or the hash. Data per district: `traffic`, `vehicle_density`, `vehicle_share`.
- **Props (V1)** have footprints and `z`: **parked cars and bikes stand in the kerb strips** (1.2 bh wide on each side of the front street, z centres +3.4 and -2.4), clear of the fighters' corridor and of the buildings, and are blockers the director can target and the context button can throw. Debris props land wherever they fall in the band. Formations (N1) stand anywhere in the band outside settlements and are blockers like buildings.
- **Terrain rows** are a separate track (T1 storage, T2 local writes); D1 and D2 do not wait for them. The heap rule (only row 1 leaves a sim heap) stands until T2.
- **Cost to D1:** the generator rules, the lane data and the probe checks; no new state; one regeneration (D1's own). L1 therefore rides with D1.
- **Scratch generator:** `WorldSettle.generate` and `skyline.gd` still lay the old four rows; they move to lanes in the D1 window.

## 14. Orb's answers, Questionnaire 10 (2026-10-01)

- **The second city is 12% of the planet** (my recommendation, section 5): original units 8150 to 9300, the west half of the planet unchanged. Section 10's question 1 and section 5's "decision this needs from Orb" are answered; the 17% version is dropped.
- **Harbour and industrial districts have few civilians, mostly workers who evacuate fast.** Data per district (`pop_density` already low): a new `worker_share` (the share of its people who are workers, who leave at the fast evacuation rate of V1's `vehicle_share` path) and the existing `vehicle_share`, with Game Design supplying the numbers. A harbour or industrial building holds 0 to 3 people; when a beam, a blast or a brunt reaches the district they evacuate in a fraction of the usual flight time, so these are the places to fight without collateral and the hero's lure reads them (`popNear` low). No new sim state: the per-district shares are data read by `WorldCollateral`'s district flight.
- **The tall mountains are a visible far row that beams can scar and fighters cannot reach**, not a pure backdrop (this answers section 12's open question 1). Plan, with the lanes plan (`fight-lanes-world.md` section 11): the `highlands` biome stays in the fighter plane (relief capped at about 8 bh); the tall range becomes a **ridge row** far behind the band, at a depth outside it, drawn by Rendering from a height profile in the planet record. The sim holds two derived or small arrays for it: `S.ridge` (the profile, derived, not hashed) and `S.ridgeDmg` (the depth a beam has scarred into it, one float per column, hashed as its non-zero columns). A beam whose ray reaches the ridge row (L5's `oz` and `zs`) scars it by the scorch rule (`RIDGE BORE` digs deepest); nothing else touches it, and no fighter, launch, prop or blast reaches it (the band clamp). One event, `ridge_scar`, for Rendering and Audio. Cost: a column loop per beam sample that reaches the row, and 4,800 floats. The MOUNTAINSIDE question (Combat) stays: it lands on highland rock in the band.
- **30 fps with reduced effects is acceptable on old laptops and phones**: the sim's tick budget at 30 fps is 33 ms, so the costs in `terrain-audit.md` and slice T (8 to 15% on the tick, dig spikes of a few ms) are comfortably inside it; no change of plan.
