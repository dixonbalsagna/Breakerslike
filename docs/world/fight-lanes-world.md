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
