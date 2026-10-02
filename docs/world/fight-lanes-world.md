# Fight lanes: World's section (ADR 0009)

Owner: World and Environment. Status: plan, docs only (2026-10-01). It answers the World asks in `docs/architecture/fight-lanes.md` section 8, and ADR 0009's "believable city blocks, with cars, bikes and foot traffic". Nothing here is in the sim. Lane geometry is data; the sim keeps B2's fields (`z`, `d`, `row`) and adds none for L1.

## 1. Short answers

| Simulation's ask | Answer |
| :--- | :--- |
| 1. The lane table | Section 2: `data/biomes/lanes.json`, one band table plus per-archetype lane use; streets are guaranteed clear of building footprints by construction and by a probe. |
| 2. Confirm the band | Confirmed: +5 to -27 bh (2,400 units), two streets and two block rows; rows 0 and 3 are scenery. Two edits: street strips (sidewalk, kerb, carriageway) inside the streets, and brunt targets limited to the band's rows. |
| 3. Terrain rows | Confirm **8 rows of 300 units** across the band, as data. Water needs **no flow between rows** (section 5). The base relief stays one row. |
| 4. The swept test | Section 6: `WorldStructures.sweep` with a body box, an earliest-hit result, and a candidate list made once per flight. |
| 5. The free-fighter contact rule | World supplies the helpers (`blocked`, the wall normal, `clearLane`); the rule itself is a feel call for Orb (section 6). |
| 6. Can L1 be part of D1? | **Yes.** L1 needs no state field and no L0; D1's generator is the rewrite that lays footprints in lanes. It costs D1 one data table, a few generator rules and probe checks (section 7). |

## 2. The lane table (L1)

**The band.** From the camera side: z in bh (1 bh = 75 units), z positive toward the camera.

| Lane | Kind | z (bh) | Width | Row | What stands in it |
| :--- | :--- | :--- | ---: | :--- | :--- |
| Foreground | scenery | +7.5 to +12.5 | 5 | 0 | low buildings, trees, fences: dressing that blasts and beams still damage; no fighter goes there |
| **Front street** | street | +5 to -4 | 9 | none | no footprint; sidewalks, kerbs, carriageway (below); the fighter plane is its centre line |
| **Block row 1** | block | -4 to -12 | 8 | 1 | buildings, frontage on the front street |
| **Back street** | street | -12 to -18 | 6 | none | no footprint; sidewalks and a narrow carriageway |
| **Block row 2** | block | -18 to -27 | 9 | 2 | buildings, frontage on the back street |
| Background | scenery | -34 to -42 | 8 | 3 | the far skyline: tall, decoration-grade, still damageable |

The sim's band is `Z_FRONT = +5` to `Z_BACK = -27`. Today's `ROW_Z_BH` (+10, -8, -22, -38) become the lane centres of the four rows, so nothing in Camera's or Rendering's present depth work moves by more than a building depth.

**The guarantee that a street is clear.** A building's footprint is `[z - d/2, z + d/2]`. The generator places every row 1 and row 2 building so that this interval lies inside its block lane, which makes every street free of footprints along the whole district. No random jitter in z (today's `ROW_JITTER_BH` of 1 bh would break it): variety comes from depth (below). Probe (hard): over every seed, no building of rows 1 and 2 overlaps a street interval, and none lies outside the band.

**Footprints.** A building's depth is `d = clamp(lane width x fill, d_min, lane width)` with `fill` from the district's data (`depth_fill`, for example 0.7 to 1.0), and `d <= 8 bh` in row 1. The thick industrial buildings (today's 8 to 20 bh wide, aspect to 0.9) are limited by the lane, so a warehouse is wide and as deep as its lane. **Frontage:** row 1 is flush to the front street's edge (z = -4) and row 2 to the back street's edge (z = -18), so the street wall is straight and the ragged side is the back. The `z` in state is the footprint centre; `d` the depth; nothing else changes.

**Blocks and cross streets.** A block is an x interval of a block lane between two avenues (`block_bh` long, `avenue_bh` wide, as in D1) and **the avenues are the same x intervals in both block rows**, so they are real cross streets: a gap through the whole band, where a fighter can change street and where traffic turns. Within a block the buildings stand party-wall tight (`gap_bh` 0.2 to 1.6 downtown, wider in suburbs), with corner lots at each end and a plaza (no building in front of a landmark) cleared in the lane it faces.

**Street strips** (all in the street's interval; geometry for Rendering and for props, in `lanes.json`):

| | Front street (9 bh) | Back street (6 bh) |
| :--- | :--- | :--- |
| Sidewalk, each edge | 1.0 bh | 1.0 bh |
| Kerb parking, each side | 1.2 bh (props only: parked cars and bikes; z centre +3.4 and -2.4) | none |
| Carriageway | 4.6 bh, z +2.8 to -1.8, contains the fighter plane | 4 bh |

A parked car (V1: 2.5 by 1.0 bh) therefore stands in a kerb strip and never in the fighters' corridor; it is a blocker the director can target.

**Per archetype.** The file lists which lanes a district uses and how thickly:
- downtown and mid-rise: both block rows full, both streets;
- suburb and village: block row 1 with houses, a back lane (the back street, narrow), block row 2 sparse;
- industrial: block row 1 only (long warehouses), the back street as a service road;
- harbour: the front street along the quay, a single row 1, the sea or a second row behind;
- open country: the whole band is open ground (formations stand on footprints anywhere in it, N1).

**Scenery rows.** Rows 0 and 3 stay in `S.buildings` as today (damaged by blasts and beams, holding people if their district says so), generated with their own lane (`scenery`), but they are **not brunt targets and not collision candidates**: a flight that leaves the band is a bug. In D1 the brunt candidate filter (`WorldBrunt.candidates`, mine) restricts to rows 1 and 2. Row 3 is the decoration the camera sees past the fight.

**Periodic in x.** The lane table is made from the settlement spans and the district tables, none of which crosses the seam (the sea is there); D2's second city ends before it. Every x difference in the table uses `SimWrap.sdx`.

**Where it lives.** `data/biomes/lanes.json` (`schema: biomes.lanes/1`): the band (`z_front`, `z_back`), the lanes (name, kind, z range, row), the street strips, and the per-archetype use. `settlements.json` keeps the districts; a district's `rows` become lanes, `depth_aspect` is replaced by `depth_fill`, and `frontage` is `front`, `back` or `free`. The table is **derived** (data plus the trimmed spans): store it as `S.lanes` and leave it out of the hash, with a probe that regenerating from the data reproduces it bit for bit. The depth-collision flag (L3) is Simulation's (`data/combat/depth.json`); lanes only carry geometry.

## 3. Traffic, foot traffic and the believable block (cosmetic)

All of it is Rendering's dressing, placed from the lane table and the buildings, deterministic from the planet seed and `S.T`, **outside the sim and the hash** (as in `cities.md` section 4).

- **Vehicles drive in the carriageways** of both streets: cars, vans and buses in the front street, bikes and small vans in the back street; they turn at avenues, queue at crossings, stop at the kerb. Density from the district (`traffic`). They scatter on `evacuate` events (the V1 `vehicle` count says how many drive off) and on `crater`, `building_fall` and `launch_depth` near them, and they never stop a fighter (no collision).
- **Foot traffic** on the sidewalks and across the avenues, count following `popAlive` of the buildings it belongs to, flowing out of doors; it empties as a district evacuates.
- **Parked vehicles** in the kerb strips are the V1 props (real, hashed, throwable); the moving ones are dressing and are never props.
- **What World supplies:** the table (street polylines, carriageway widths, avenue x intervals, kerb centres), the buildings' doors (derived from `seed`, `shape` and `kind`), and the `vehicle_density`, `vehicle_share`, `traffic` fields per district. Art and Rendering choose models.

## 4. Props and formations on lanes

Props (V1) have a footprint (`w`, `d`, `h`) and `z`. Parked ones stand in kerb strips; scattered ones (boulders from a felled rock, trunks from a snapped tree, a wrecked car) land wherever they fall, inside the band. Formations (N1) stand anywhere in the band outside settlements; inside a settlement the only formation is a landmark's own footprint. A prop or a formation is a blocker exactly as a building is: the swept test sees all three through one candidate list.

## 5. Terrain rows

*Superseded in part by section 10 (the ruling of 2026-10-01: heights only, water on the lowest ground, rows at +300, 0, -300 ... -1,800, local writes behind `S.depthOn`). Where they disagree, section 10 stands.*

- **Count.** 8 rows of 300 units (4 bh) across the 2,400 unit band, as Simulation proposes, and as **data** (`rows`, `spacing`), so the phone build can try 6 rows of 400. A 300 unit row matches a block row's footprint (600 to 675 units, two rows) and the smallest crater bowl (160 to 600 units, one to four rows). The scenery rows use the ground of the nearest band row.
- **The base relief stays one row**, so generation, biomes, platforms and the sea rule do not change. A hill is therefore a ridge across the whole band, which reads as a wall; if Art finds that wrong, a second noise octave in depth (`base_z_noise`, one extra generator pass, still a function of `(x, z)`) can be added without touching state.
- **Water between rows: none, and none needed.** The sea is the same on every row (the reservoir columns are full on every row, and the shallows flood from them by the same x rule), and a crater floods only when it is connected to the sea in its own row, which puts its surface at the sea level on every row. An inland pit stays dry, as now. So every wet column's surface is the sea level (plus a settling transient inside a window), the rows agree, and no cross-row flow is needed. Probe (hard): after any run, wet columns on neighbouring rows have equal surfaces within the settling tolerance. Windows are shared across rows (one window steps all of them), so `MAX_WINDOWS` still bounds the cost.
- **A quay or a riverbank** is a structure (shape `quay`), not terrain: a straight coast across the band is fine.
- **The T1 to T4 fixes carry over by row:** a collapsed building leaves its heap on the rows its footprint spans (the heap rule "rows 0 and 1 only" becomes "the band", once rows exist; until then, with one row, only row 1 leaves a heap, as now), the relaxation limits the step between neighbouring rows to `REPOSE_SLOPE x spacing` (375 units), and `baseY(S, b)` becomes the highest ground over the footprint in x and z.
- **My cost estimate for T1 and T2 (World's part):** five terrain files (`terrain.gd`, `crater.gd`, `water.gd`, `slide.gd` and the heap in `structures.gd`) loop over rows; a dig is about 1 to 4 rows' worth of today's 0.13 to 0.41 ms; Rendering draws eight strips (their question). The T1 storage slice is neutral and lands first; T2 changes behaviour a little while fights stay in one street.

## 6. The swept test (L3) and the contact rule

All functions are pure, draw nothing, use `SimWrap.sdx` in x and plain subtraction in z, and reach the buildings, the formations and the props through one candidate list.

```
# the candidate boxes along a flight: standing buildings, formations and props whose footprint can meet a path from xa to xb
WorldStructures.along(S, xa, xb, pad) -> Array          # indices, sorted ascending, built from the x buckets; once per flight

# the earliest crossing of the segment (x0,y0,z0) -> (x1,y1,z1) by a body of half extents (rx, ry, rz)
WorldStructures.sweep(S, list, x0, y0, z0, x1, y1, z1, rx, ry, rz) -> Dictionary
	{ "hit": bool, "b": index, "t": 0..1, "x": x, "y": y, "z": z, "face": "front"|"back"|"end"|"top", "nx": nx, "nz": nz }

WorldStructures.blocked(S, x, y, z, rx, ry, rz) -> int   # the index of a blocker overlapping the body now, or -1
WorldLanes.laneAt(z) -> int                              # which lane a depth is in
WorldLanes.clearLane(S, x, z) -> float                   # the nearest depth, at this x, in a street that no footprint overlaps
```

- **Method.** The box of a footprint `[x +- w/2] x [base, base + curH] x [z +- d/2]` is grown by the body's half extents and the segment is clipped against it by the slab method: one division per axis, no trigonometry. The earliest `t` wins, ties go to the lower index (Simulation's rule). A box already overlapped at `t = 0` is reported at `t = 0` with the face of least penetration.
- **Candidate list.** `along` is called once per flight (the predictor, `flightTo` and the runtime both) with the x extent of the flight, so a step costs a handful of box tests, not a bucket query. 240 predicted steps times 16 flights stay in Simulation's budget.
- **Body.** A fighter's `rx = rz = 0.3 bh`, `ry = 0.5 bh` (data); a prop's from its record.
- **B2 carries over.** `WorldBrunt.hit` is unchanged: the sweep says which building and where; floors, chains, splash and the collateral token run as now. A chain is a repeat of the sweep from the far face, so `chainPlan` and the runtime stay one function. The "only the aimed building is hit" rule goes with L3: with the streets clear, a flight in a street never touches a building, and a flight whose waypoint passes through a block hits what it really crosses, which the predictor already knew.
- **Blasts** reach a building by plan distance from its centre `(x, z)` instead of `Z_REACH`; beams by their ray and width.
- **The free-fighter contact rule** (Simulation's question 2; Orb's call): World provides `blocked` (is the fighter inside a footprint?), the wall normal from `sweep` (to slide along it) and `clearLane` (the nearest clear street). Prototype rule, my recommendation: stopped, slides along the wall; attacks plough through. In a city it only happens after a flight ends inside a block, and then `clearLane` gives the director the lane to return to.

## 7. L1 inside D1: what changes in D1

1. **Data:** `lanes.json`; `settlements.json` gains `depth_fill`, `frontage` and per-district `traffic`, and loses `depth_aspect`. The schema and validator are Tools'.
2. **Generator** (`terrain.gd` and `settlements.gd`, mine): `z` from the lane (centre plus a frontage offset inside the lane, no jitter), `d` from `depth_fill`, avenues the same in both block rows, scenery rows in their own lanes, plazas, corner lots.
3. **Brunt candidates** restricted to rows 1 and 2 (`brunt.gd`, mine).
4. **State:** none. `z`, `d` and `row` exist and are hashed; a `lane` is derived from `z`.
5. **Probe:** footprints inside lanes, streets clear (including kerb strips for props), avenues equal across rows, the table reproducible, the existing B2 plan-equals-outcome test on the new layout.
6. **No dependence on L0:** D1 can land before or after it.
7. **Cost to D1:** the generator rules above and the probe, a modest addition to the slice as planned (the generator rules are a few dozen lines and the probe checks are cheap); one golden regeneration, D1's own.

## 8. Asks back, risks

- **Simulation:** the band constants and `S.lanes` unhashed; the flag in `data/combat/depth.json`; the order L1 (with D1), then L0, then L3.
- **Camera:** confirm -27 bh as the deepest readable depth; if it is shallower, the data shrinks block row 2 and the back street, and downtown loses its second row.
- **Rendering:** the street strips and the avenue list are the traffic and crowd layout; the eight terrain strips are their cost question.
- **Art:** district looks per lane (street wall, back alley).
- **Risks:** (1) block row 2 sits 18 to 27 bh behind the fighters, so the second row is seen past the first; occlusion is Rendering's and Camera's. (2) D1's footprints become thicker than today's (deeper, aligned), which changes blast and beam reach to the second row and the brunt candidates; the 100-match probe at D1 reports it. (3) A footprint deeper than its lane is impossible by construction, but a collapsing building's heap spills past it (the heap rule handles that). (4) Row 3 (about a third of downtown's buildings) becomes scenery: the skyline stays, the targets drop.

## 9. Notes from Simulation's merged plan (2026-10-01)

- **The depth flag.** `enabled` in `data/director/depth.json` is copied by `newMatch` into `S.depthOn` (hashed). Everything of mine that depends on depth (the swept test, blasts by plan distance, the lane-aware layout checks) reads only `S.depthOn`, never the file.
- **Replay data hash.** `lanes.json` and `settlements.json` join the replay header's data hash: World supplies `WorldSettle.dataHash()` (a hash of both files' parsed content, in the pattern of `FighterData.dataHash`); Simulation adds the `replay.gd` line in L0. Written in the D1 window with the data.
- **Water windows across rows (T2).** A window that steps all 8 rows costs about 0.7 ms a tick while open (2.9 ms worst). A window will record the rows it covers (a row range with its x range), so a crater that touches rows 3 to 5 steps three rows: 200 to 350 us a tick. `MAX_WINDOWS` still bounds the worst case. Rows outside a window are not stepped and not read.
- **Order.** I2c, then L1 with D1, then L0 and L2, then L3 (World), L4, L5. T1 and T2 may move earlier (Rendering found that L4 before T2 leaves trenches across the band); Simulation may ask for an estimate, which section 5's cost note already gives: T1 (storage, neutral) is the smaller slice, T2 (local writes in five files) the larger.

## 10. Slice T on the reduced scope (EP ruling, 2026-10-01)

**Scope.** Rows for the heights only (`deform`, `rubble`); `scorch`, `crack`, the base relief and `water` stay one row. Eight rows at z = +300, 0, -300 ... -1,800 (a row exactly on 0, so the plane row is today's ground bit for bit). `groundY(S, x, z = 0.0)` blends the two nearest rows and clamps to the edge rows (so every existing call keeps its meaning). Water runs unchanged on a derived array `low[i]`, the lowest ground across the rows at each column, kept by every writer; the surface is one value per column and a row's depth is the surface less its own ground, so water is level across the band. Local writes (a dig on the rows inside its plan radius, its depth centre snapped to the nearest row) sit behind `S.depthOn`; with it off every writer writes the whole band, rows stay identical, and the slice is neutral.

**(1) Size.**
- **Files:** `terrain.gd` (the row arrays, `groundY(S, x, z)`, `low`), `crater.gd` (dig by plan distance on the rows inside the footprint, relaxation per row, the slide trench, the scorch's height part), `structures.gd` (heaps by rows, `baseY` over the footprint's rows, `pinned` per row), `water.gd` (reads `low` where it read `deform`: a few lines, no change of logic), `brunt.gd` and `slide.gd` (the ground reads), and the probe. Granted lines: `state.gd` (the arrays and `low`), `hash.gd` (rows hashed as their non-zero columns). Rendering's ground field reads the rows (theirs).
- **Effort:** a medium slice, about one and a half times T1 to T4: roughly 500 changed lines and 12 to 15 new probe checks. One window, one hash-only regeneration, and the neutrality proof (the light digests identical with `S.depthOn` off; the rows identical bit for bit after every dig, heap and groove; `groundY(S, x, 0)` equal to today's).
- **How it stays cheap off:** a writer computes its window once on the plane row and copies it to the other rows (a copy of about 100 columns each); the relaxation runs once.
- **With `S.depthOn` on (probe, forced):** the dig by plan distance; relaxation between rows limited to `REPOSE_SLOPE x 300 = 375` units a row; the cost per dig is one to four rows' worth of today's 0.13 to 0.41 ms.
- **Risks:** `low` must be updated by every deform write (a missed writer floods wrongly: the probe compares `low` to a recomputation after every kind of write); the heap and the hash lines are granted ones.

**(2) Does rubble spill into the street? No, by design.** A collapsed building's heap is written on the rows **strictly inside its footprint's depth interval** (or, for a footprint that contains none, the nearest row inside its lane), never on a row inside a street or on a street edge. The block row 1 footprint (z -300 to -900) therefore gets the row at -600; block row 2 (-1,350 to -2,025) gets -1,500 and -1,800. The front street's rows (+300 and 0) and the back street's (-1,200) are never raised by a neighbour's collapse, so the carriageway stays flat and the plane row is untouched by any building. The linear blend puts the ramp from the crest to zero inside the block lane's own depth (300 units): with the heap crest capped at 4 bh (300 units) the step between neighbouring rows is at most 300, a slope of 1.0, inside the limit, so no relaxation between rows is needed for heaps. Heaps still skip a standing building's footing in x and z, and still taper toward it. In x a heap may spill into an avenue (a gap of 6 to 14 bh through every row); it is at most 0.3 of a width and tapers to the repose limit.

**(3) `S.lanes` as a flat packed array** (`PackedFloat32Array`, derived, not hashed; world units, z positive toward the camera; read by the ground shader every frame):

| Index | Content |
| :--- | :--- |
| 0 to 12 | Header: 0 version (1); 1 `nLanes`; 2 `nStrips`; 3 `nDistricts`; 4 `nAvenues`; 5 `nRows`; 6 `rowZ0` (+300); 7 `rowStep` (-300); 8 `zFront` (+375); 9 `zBack` (-2,025); 10 `offLanes`; 11 `offStrips`; 12 `offDistricts`. `offAvenues` = `offDistricts + 6 x nDistricts`. Row k is at `rowZ0 + k x rowStep`. |
| Lanes, 4 floats each | `zTop`, `zBottom`, `kind` (0 street, 1 block, 2 scenery), `row` (the building row it holds, or -1). In z order, front to back. |
| Strips, 4 floats each | `lane` (index), `zTop`, `zBottom`, `kind` (0 sidewalk, 1 kerb parking, 2 carriageway). Strips tile each street lane exactly. |
| Districts, 6 floats each | `x0`, `x1` (the district's x interval; settlement spans never cross the seam), `look` (an index into the `looks` list of `settlements.json`), `laneMask` (bit per lane the district uses), `traffic`, `settlement` (index). |
| Avenues, 3 floats each | `x0`, `x1`, `district`. The cross streets: the same intervals in every block row of the district. |

A shader finds a pixel's lane by `z`, its strip by `z` within a street, its district by `x`, and whether it is in an avenue by `x`; everything else (sidewalk, kerb, carriageway, block) follows from the table. `looks` is a new top-level list in `settlements.json` (the stable order of the look names), so the index is data, not code. `dataHash()` (section 9) covers it.

## 11. Orb's answers, Questionnaire 10 (2026-10-01)

- **The ridge row.** The tall mountains are a damageable scenery row far behind the band: `lanes.json` gains a lane of kind `ridge` at a depth beyond the background scenery row (proposal: z about -90 bh, as data), outside `Z_BACK`, so the clamp keeps every fighter, launch, prop and blast away from it. A beam is the only thing that reaches it: L5's beam ray (`oz`, `zs`) crossing the ridge depth below the profile scars it by the scorch rule into `S.ridgeDmg` (see `districts-plan.md` section 14). `S.lanes` gains one lane record (kind 3, ridge); the shader reads the scarred profile from `S.ridgeDmg`. Before L5 the ridge is Rendering's static backdrop and `S.ridgeDmg` stays zero.
- **Workers evacuate fast.** The district data carries `worker_share` and `vehicle_share` (numbers from Game Design); the lane table needs nothing new. Harbour and industrial districts are the low-civilian places.
- **The second city is 12%**, so the lane table has two city districts sets (Bellgate and the harbour metropolis) and no 17% layout.
- **30 fps with reduced effects** relaxes the cost worries in sections 5 and 10 (water windows, digs per row); the plan does not change.

## 12. L1 inside D1: scratch build and measurements (2026-10-03, on HEAD 76c9485)

Built in a scratch copy of HEAD, switched on by data (`"enabled": true` in `settlements.json`); the files are in `docs/world/scratch-build/l1d1/` (`l1d1.diff` for `settlements.gd`, `terrain.gd` and the probe; `lanes.json`; the data file `settlements.json` with `depth_fill` for `depth_aspect`; `lane_check.gd`). What it does: `genWorld` takes its buildings from `WorldSettle.generate` (the D1 generator) instead of the old rows; **a building's z and d come from its lane** (blocks flush to their street: row 1 at z = -4 bh less half the depth, row 2 at -18 bh; the scenery rows centred; depth = lane width x `depth_fill`, no jitter); the avenues are the same x gaps in both block rows; a landmark clears the neighbours its footprint overlaps in its row and is never placed across an avenue. It writes only the fields that exist today (the new D1 fields, the hash lines and the landmark event are the window's, not part of this scratch).

**Layout checks (seed 1):** 186 buildings (196 today): row 0 17, row 1 65, row 2 65, row 3 39; mean footprint depth 3.4, 5.9, 6.7 and 6.5 bh; population 1,800; tallest 245 bh. **Footprints outside their lane: 0. Block footprints touching a street: 0. Overlaps in a row: 0. Buildings across an avenue: 0.** (The first run had one overlap and one building across an avenue, both from a landmark wider than the building it replaced; fixed as above.)

**Match effect (200 matches, seeds 101 to 300, the tree's tuned contact model on in both):** layout today against L1 with D1.

| | Today | L1 with D1 |
| :--- | ---: | ---: |
| Length to KO | 432 s | 435 s |
| Structures levelled | 52.0 of 196 (26.5%) | 44.3 of 186 (23.8%) |
| Civilians lost | 16% | 16% |
| Craters a match | 35 | 36 |
| KAI wins | 50% | 51.5% |
| BUILDING SMASH share of launches | 3% | 2% |
| Ticks a second | 12,331 | 12,709 |

Reading it: the layout is neutral for length, civilians and balance; levelled structures fall 15% (not investigated; the likely causes are the deeper, tighter towers and the avenue gaps, which I have not separated); the brunt share loses a point (3 to 2%), not investigated either (the candidates are the rows 1 and 2 buildings the planner can aim at). **If the brunt band (Game Design: 4 to 10%) matters for the layout, it is the planner's (Encounter's) lever, not the layout's.**

**The one probe finding.** The probe's "a front-row building leaves a heap no steeper than the angle of repose" took the steepest step of the *ground* around the first tall front-row tower; in the D1 layout that tower stands 1,280 units from a step in the base relief (58 units a column, the coast of the city's platform), so it failed on terrain that has nothing to do with the heap. The check now measures the heap's own step (the change in deform; 19.1 units a column, the 0.6 slope, in limit). That is a one-line change to World's probe, which the D1 window makes.

**Not in the scratch:** the lane table as `S.lanes`, the street strips, scenery rows' exclusion from the brunt candidates (the filter is the plan's step 3), the Building fields and hash lines, and the landmark event: those are the window's. The cost of the window is as section 7 says.

**Addendum (2026-10-03): a candidate filter to rows 1 and 2, and the brunt share.** The brunt share is the number of `launch_depth` events over `launch` events, 60 matches (seeds 101 to 160): **today's layout 2.84% of launches (2.63 a match; 85% of matches have one; targets by row: row 0 10, row 1 41, row 2 55, row 3 52, so the scenery rows take 39% of today's brunts); today's layout with the filter 2.80% (2.65 a match; rows 1 and 2 only, 60 and 99): the filter moves the brunts to the block rows and does not reduce them. L1 with D1: 1.81% (1.67 a match, 65% of matches; rows 1, 2 and 3: 37, 28, 35); L1 with D1 and the filter 1.54% (1.42 a match, 65%; rows 1 and 2: 47 and 38).** So the new layout is where the brunts go (about 1 point of the share), and the filter itself costs only 0.3 point more. The lever is the planner's: more candidates per side (`BR_PRESELECT`), a longer reach (`BR_MAX`), or the aim search accepting more flights. The D1 layout has 130 block buildings in rows 1 and 2 (65 each); whether it is the tighter blocks, the avenues or the number of tall buildings within reach that costs the point has not been separated.

## 13. Slice T built in scratch (2026-10-03, on HEAD 74ede76)

The terrain rows, as the EP's reduced scope (section 10): heights only, eight rows at z = +300, 0, -300 ... -1,800, water on the lowest ground, local writes behind `S.depthOn`. Files: `docs/world/scratch-build/t/` (`slice_t.diff` against HEAD, `t_rows.py` which applies it to a HEAD export, `probe_rows.gd` the checks, `t_cost.gd`, `depth_ab.gd`).

**How it works.** Row 1 (z = 0) **is** `S.deform` and `S.rubble`, so every reader of the plane keeps working; the other seven rows are `S.deformZ[k]` and `S.rubbleZ[k]`, allocated only when depth is on (`WorldTerrain.initRows`, one line in `newMatch` after `S.depthOn`). **A writer works on one row by swapping that row's arrays into `S.deform` and `S.rubble` for the length of its write** (`enterRow` and `leaveRow`, `rowZ` says which), so the dig, the relaxation, the trench, the heap and their footing rules run unchanged on the row, and events and records are emitted once. `dig` takes the depth from its `z` argument or from the cause's `z`, digs that row in full and then the other rows inside the bowl's plan radius, with the same bowl and rim at the plan distance (a row 300 units away sees a shallower, narrower slice). `scorch`, `carveSegment` and `berm` take a `z` the same way (the contact model passes the body's). A heap goes on the rows **strictly inside the footprint's depth interval** and on no other (a street row stays flat, as section 10 says). A standing building is a footing only for the rows inside its interval; `baseY` is the highest ground over the footprint in x and in depth. `S.low` (derived, not hashed) is the lowest deform over the rows, refreshed by every writer, and water reads it where it read `deform` (five lines). `groundY(S, x, z = 0)` blends the two nearest rows and holds the edge rows beyond the band; with depth off `z` is ignored. The contact model reads the ground at the body's `z`.

**Neutral proof (depth off):** the 12-match batch digest is identical to HEAD's (5dcb57721ebb7a83); `npm test --prefix sim` passes 5 of 5 **on the untouched goldens** (the hash adds the rows only when `S.depthOn`, so a match without depth hashes as before: **no golden regeneration for the slice**); the world probe passes 0 failures; the water, the plane row and everything else are the old model's by construction (no row exists).

**With depth forced on:** 20 checks pass (`probe_rows.gd`): a dig at z = 0 on open ground leaves the plane row and the water bit for bit as the old model's; a dig at z = -600 digs only its row and the neighbours' smaller bowls; an energy-10 bowl at z = -900 is deepest on its own row (-111) and shallower with plan distance (-42 two rows over), the largest step between neighbouring rows 83 against the limit of 375; `low` equals the minimum over the rows after digs, a trench and a berm; `groundY` is the plane row at z = 0, the mean halfway between two rows, the edge rows beyond; a collapsed tower's heap is on exactly the rows inside its footprint; two depth-on runs of one seed give the same state hash and no NaN in any row (a full match, 14,195 ticks).

**Match effect with depth on (40 matches, seeds 1 to 40, no L2 or L4 so the fighters stay near the plane):** length 426 s against 442 s with depth off; structures levelled 59.1 against 61.3; civilians 16.9% against 19.6%; craters 34.6 against 35.8: noise. **Cost:** 6,806 against 6,977 ticks a second (-2.5%); a dig 136 us off and 409 us on (the neighbour rows), a trench 35 and 52 us, a `groundY` read at depth 0.74 and 1.36 us. Memory: seven rows of two 4,800-float arrays a match, and the hash adds the non-zero columns of the rows (about 6,700 a match).

**Grants the window needs (Simulation's files):** `state.gd` (three fields: `deformZ`, `rubbleZ`, `low`), `sim.gd` (one line, `WorldTerrain.initRows(S)` after `S.depthOn`), `hash.gd` (the rows, when depth is on). **Not in this slice:** callers that should read the ground at a depth (`fighter.gd`, `melee.gd`, the camera and the animation's `groundY` reads default to the plane: L2 and L3 give them the fighter's `z`); `z` on the `crater` event for Rendering (L0's "z on every positioned event"); `S.lanes` and Rendering's row texture; `contact.surfaceAt`'s rubble and paving reads stay on the plane row.
