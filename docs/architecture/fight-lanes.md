# Fight lanes: the architecture plan for real depth (ADR 0009)

Owner: Simulation and Engine. Status: plan, docs only (2026-10-01). Nothing here is in the sim yet. It answers ADR 0009 ("depth is real, and the choreographer owns it entirely") with a depth model, the state it touches, what stays as it is, the slices and their owners, and the risks. Section 8 lists what Encounter, World, Camera and Rendering have to decide; their answers become sections of this file. Section 9 records the EP's rulings.

Sources: `docs/decisions/0009-fight-lanes-depth.md`, `research/band-proto/README.md` (the prototype Orb played), `docs/world/b2-plan.md` section 10 (today's depth), `docs/world/districts-plan.md` (D1, N1, V1), `docs/camera/depth-and-chains.md`.

## 0. Where the code is today

- A fighter has `z` (hashed). It is a function of a brunt's aim (`WorldBrunt.stepZ`: a smoothstep from `aimZ0` to `aimZ1` over the x distance `aimD`) and eases back to 0 after the flight. It enters no physics: the ground, hits, blasts and beams never read it.
- Buildings already stand on boxes: `x`, `w`, `z`, `d`, `row`. Rows are at +10, -8, -22 and -38 bh (1 bh = 75 units, a fighter's height); `z` is positive toward the camera. Only the building a launch is aimed at can be hit, and a free fighter passes every building.
- The terrain is five float32 arrays of 4,800 columns (`deform`, `water`, `scorch`, `rubble`, `crack`) over a base relief of the same size. A crater is a trench across the whole depth.
- Civilians are counts per building. There is no street crowd, no traffic and no prop in the sim state.
- A blast reaches a building by its x distance and a fixed depth reach (`Z_REACH`); a beam is a ray in x and y.

## 1. The depth model

**Recommendation: a continuous `z` in a band. Lanes are World's layout data, not a quantised fighter position.**

- **Why continuous.** ADR 0009 asks for a slight variation of angle on every smash, launch and throw. That needs positions between lanes. Footprints with jitter, the camera (which already follows an eased `z`) and a true collision test all need a real coordinate too. Discrete lanes would still need an interpolated position between them, so they add state without removing any.
- **What a lane is.** A named interval of `z` in World's layout: a street (kept clear of footprints all along its district) or a block row (where footprints stand). The director plans in lanes ("land in the back street"), the sim moves in `z`. Lanes also place traffic, props and the debug view.
- **Type and rules.** `z` is a float64 like `x` and `y`, under the same determinism rules (`docs/architecture/determinism.md`). No angle is ever stored: a deviation is a target depth, so no new trigonometry enters the sim.
- **The band.** Fighters, props and beams live in `Z_BACK <= z <= Z_FRONT`. The sim clamps to it. My proposal, for Camera and World to confirm:

  | Lane | z (bh) | z (units) |
  | :--- | :--- | :--- |
  | Front street (today's fighter plane is its centre line, z = 0) | +5 to -4 | +375 to -300 |
  | Block row 1 (today's row 1) | -4 to -12 | -300 to -900 |
  | Back street | -12 to -18 | -900 to -1,350 |
  | Block row 2 (today's row 2) | -18 to -27 | -1,350 to -2,025 |

  That is 32 bh (2,400 units): two streets and two block rows, Research's "B-lite" plus one row to smash into. Today's rows 0 (foreground) and 3 (back) are outside the band: they stay scenery that blasts and beams still damage, and no fighter goes there. The limit is the camera: at the usual zoom a fighter at -27 bh draws at about half size, and at -38 bh it cannot be made larger than 35 px (`depth-and-chains.md`). The band limits are data (World's layout record), so the number can change without code.
- **Open country.** Outside settlements the whole band is open ground. Formations (N1) stand on footprints anywhere in it.
- **How it wraps.** The band is a strip around the ring: `x` wraps as today and `z` does not. Every x difference stays the shortest arc (`SimWrap.sdx`); a z difference is a plain subtraction; a plan distance is `sqrt(sdx² + dz²)`. Nothing new happens at the seam. The lane table must be periodic in x (World: the seam falls inside one layout segment).

### How a fighter's depth moves (the mechanisms; the director sets the targets)

| Situation | Rule | Who sets the target |
| :--- | :--- | :--- |
| Free | `z` eases to the home depth `zT` (today's ease to 0, with `zT` in place of 0). | The sim sets `zT` to where a flight ended; Encounter may override it (alignment). |
| Rush | The rush homes in `z` exactly as it does in `x` and `y`: to the target fighter's `z`, or to a point's `pz`. | Encounter (the rush's target). |
| Exchange | Both fighters ease to the exchange's depth `ex.z`. | Encounter, at `requestAttack`. |
| Launch, throw, slide | The flight carries a depth waypoint: from `(aimX0, aimZ0)` to `aimZ1` over the x distance `aimD`. These are B2's four fields, used for every flight and not only for an aimed one. A slide and a rebound continue from a new waypoint. | Encounter (the small deviation, or the targeted one), through the launch plan. |
| Beam | A ray with a start depth and a depth change per unit of length. | Encounter (the beam plan). |

A waypoint, not a velocity, because it is bounded by construction, costs no new integrator, and the predictor can reproduce it exactly (B2's "plan equals outcome" test carries over).

### Collisions are true

- A launched, sliding, rushing or thrown body is tested against every standing footprint its path really crosses in `x`, `y` and `z` this tick. The test is swept (the tick's segment against the box), because a fast launch moves about 200 units a tick and D1's thinnest buildings are under 2 bh (150 units) deep. The earliest crossing wins; ties go to the lower building index.
- A hit is B2's brunt (`WorldBrunt.hit`), so floors, chains, splash and the collateral token are unchanged.
- The predictor (`flightTo`, `predictFlight`) runs the same test, so the director knows every building a plan will hit before it chooses.
- A blast reaches a building by plan distance from its centre `(x, z)`, in place of the fixed depth reach.

## 2. Where depth enters state and hash

Every field below is hashed. "Exists" means the field is already in state and hash.

| Thing | State | Notes |
| :--- | :--- | :--- |
| Fighter | `z`, `aimX0`, `aimZ0`, `aimZ1`, `aimD`, `aimB` exist. New: `zT` (home depth). | `z` becomes physical: ground height, hits, blasts and beams read it. |
| Rush | New: `pz` (a point rush's depth). | A fighter rush reads the target's `z`. |
| Exchange | New: `z` (the depth it is fought at). | Beat arguments (already hashed) may carry depth offsets; that is Encounter's data. |
| Launch and flight | No new field: the plan fills the waypoint for every launch. | `launch_depth` is sent for every launch, so Camera always knows where a flight goes. |
| Slide | Record: new `z0`, `z1` (the furrow's depth at each end). | The fighter's slide fields are unchanged; `z` follows the waypoint. |
| Beam | New: `oz` (start depth), `zs` (depth change per unit of length). | `sampleBeam` yields `(x, y, z)`. A beam hits what its ray and width really cross. |
| Clash | No new field. | Its point is midway between the two fighters in `z` as in `x`. |
| Structures and formations | No new field (`x`, `w`, `z`, `d` exist). D1 adds `district`, `shape`, `landmark`. | The x-bucket index stays; the depth test follows the bucket lookup. A bucket holds a handful of boxes. |
| Trees | New: `z` per tree. | A tree falls only inside a crater's plan radius. |
| Civilians | None. | They stay counts per building; the building has the depth. |
| Traffic and street crowd | None. | Cosmetic: Rendering places them from the lane table and the `evacuate` events (V1's fast evacuees are counts). Nothing cosmetic is ever within a fighter's reach; anything still standing near the fight is a prop in state. |
| Props (V1) | `S.props`: World's record gains `z` and the same waypoint as a fighter's flight. | Only held and thrown props step. A parked prop is a blocker with a footprint. |
| Terrain | `deform` and `rubble` become rows. `water`, `scorch`, `crack` and the base relief stay one row. | Below. |
| Events | Every event with an `x` and a `y` carries `z` (the field exists on `FxEvent`). | For Rendering, VFX, Camera and Audio. |

### Terrain rows

Revised after World's and Rendering's sections (the reasons are in section 12).

- **8 rows, 300 units (4 bh) apart, as data** (`rows`, `spacing` in `lanes.json`), **with one row exactly on z = 0**: z = +300, 0, -300 … -1,800. The plane row is then the sim's ground bit for bit, as today.
- **`groundY(S, x, z)`** blends linearly between the two nearest rows and clamps to the edge row outside them. At z = 0 it reads one row and costs what it costs today.
- **Only the heights get rows: `deform` and `rubble`.** The base relief, `scorch` and `crack` stay one row (the last two are paint, which Rendering spreads to a width as now).
- **Water stays one row, on the lowest ground across the rows.** The writers keep a derived array `low` (the minimum of the rows at each column), and the water model runs on it unchanged. The surface is one value per column for every row, and a row's depth there is the surface less its own ground. So water is level across the band (Rendering's ask), `water.gd` barely changes, and its cost does not grow.
- **Storage is dense, writes are local.** A dig writes only the rows and columns inside its plan radius. Sparse storage would save 300 KB and cost a second code path.
- **A dig's depth centre snaps to the nearest row.** A small bowl (radius 160) centred between two rows would otherwise be missed by both. The error is at most 150 units in depth, about a tenth of that on screen.
- **Local writes are gated by `S.depthOn`.** With it off every writer writes the whole band, so the rows are identical and the ground is today's.
- **Not a full grid.** 32-unit cells in depth would be 75 rows and 1.8 million values: too slow to hash in GDScript.

**Cost, measured on Orb's PC today** (seed 3, 20,000 ticks, one row) and estimated for 8 rows:

| | Today | With 8 rows |
| :--- | :--- | :--- |
| Mean tick | 99 µs | about 105 to 120 µs |
| `groundY` | 0.48 µs a call | The same on the plane row; about 1 µs off it (two rows and a blend). |
| A dig, with its relaxation | 0.13 to 0.41 ms each, 46 in the run | Times the rows touched: 0.13 to 1.6 ms for an ordinary crater, 1 to 3.3 ms across all 8 at the size measured. The largest specials were not measured. A relaxation between rows, if World adds one, costs more. |
| Water, while a window is open (12% of ticks) | 90 µs a tick | Unchanged: one row. |
| Full state hash | 29 ms (19,030 values) | About 30 ms with rows hashed as their non-zero columns; about 60 ms if hashed densely. |
| Memory of the per-column arrays | 96 KB | 365 KB |
| Copy of those arrays (a rollback save) | 2.8 µs | about 10 µs |

On a desktop the mean tick stays under 1% of a 16.7 ms frame. I have no measurement on an old laptop or a phone in the browser. If they run GDScript 5 to 10 times slower, the mean is still about 1 ms, but a dig tick could reach 10 to 30 ms. Levers, in order: a shared result for rows that were identical before the dig, a cap on relaxation passes, and spreading a dig's rows over the following ticks (a hashed queue).

## 3. What stays one-dimensional

- The base relief, the biomes (`biomeAt(x)`), the sea rule (`seaAt(x)`), the settlement spans and platforms.
- Wrap math, the planet's length, the columns along x.
- Free movement, dash, sprint, boost, lock-on, the AI's lure and hunting, location variety, the population histogram: all by x.
- Flight physics in `x` and `y` (gravity, drag, water skim, slam or slide). Depth rides on it by the waypoint.
- Stance, wounds, meters, the ladder, mood and style, the act. None reads depth.
- Hiding and cover (held for the stealth fighter).
- The intent record, the replay format and the HUD's ring minimap.

## 4. The player never steers depth

- `SimIntent` gets no depth field. Its version, the 40-bit packing and replay format v3 are unchanged. ADR 0008 is unchanged.
- `sim/input` never writes `z`, `zT` or a waypoint. A parity lint checks it, in the way the casualty lint checks that only `WorldCollateral.kill` counts a death.
- The AI does not steer depth either: it asks for attacks, and the director places them. A dodge that reads as a sidestep in depth is choreography (Encounter), not an input.

## 5. The slices

One sim editor at a time. Mechanisms land behaviour-neutral, switched off by data; one slice switches them on. That gives one large behaviour change and one QA re-baseline for it. Revised twice: with World's section (L1 rides with D1) and with Rendering's (the terrain rows come before the switch-on; section 12).

| # | Slice | Owner | Behaviour | Goldens |
| :--- | :--- | :--- | :--- | :--- |
| L0 | Depth plumbing: `zT`, `Rush.pz`, `Exchange.z`, `Beam.oz` and `zs`, `Slide.z0` and `z1`, `z` on every positioned event, `launch_depth` for every launch, the switch `S.depthOn` (section 11), World's data hash in the replay header, `groundY(S, x, z)` with a default (World's line, by grant). All zero. | Simulation | Neutral. Proof: parity passes on the untouched goldens before the fields are hashed; after the regeneration the per-tick light digests and tick counts are identical. | Regenerated once (hash only) |
| L1 | The lane table (`data/biomes/lanes.json`, `S.lanes`) and the layout on it: streets clear by construction, footprints by lane, rows 0 and 3 as scenery, brunt candidates from rows 1 and 2 only. Part of D1, which re-lays the city anyway. No new state. | World | Changes (the layout) | D1's regeneration |
| L2 | Depth in the core, switched off: the free ease to `zT`, the rush homing, the exchange alignment, the waypoint for every flight and slide, the band clamp, ground height at `z`. The director still passes zero. | Simulation | Neutral. Proof: parity on untouched goldens. | None |
| L3 | True collisions, behind a data flag (off): the swept footprint test for bodies in `fighter.gd`'s launched branch (by grant), the same test in the predictors, blasts by plan distance, the free-fighter contact rule (section 9, ruling 2; granted lines in `fighter.gd`). The probe's plan-equals-outcome test gains depth. | World | Neutral while off | None |
| L4 | **The switch-on, after T.** The director plans depth: the small deviation on every smash, launch and throw (keyed draws by exchange index, numbers in `data/director/depth.json`), the targeted deviations, alignment before an exchange, where a flight's end leaves the fighter. `enabled` goes true, which turns the collisions on with it. | Encounter | Changes | Regenerated; QA re-baselines every band |
| L5 | Beams in depth: the beam plan sets `oz` and `zs`; hits, scorch and the strike crater follow the ray. | Encounter, with World for scorch | Changes | Regenerated |
| T | Terrain rows, behind the switch: `deform` and `rubble` become rows, water runs on the lowest ground, craters, furrows, grooves and heaps are written by depth extent when `S.depthOn` is set and across the whole band when it is not. Rendering's row texture lands with it. | World, with granted lines in `state.gd` and `hash.gd` | Neutral while off. Proof: light digests identical; the probes run it with the switch forced on. | Regenerated once (hash only) |
| P1 | Props and formations as blockers on lanes (V1 and N1, already planned). | World, with Combat and Controls for the context button | Changes | Their own regenerations |

- **Order.** I2c (Controls) keeps the next window. Then L1 with D1 (World), L0 and L2 (mine: one window, two proofs), L3 and T (World, in either order or one window), L4 (Encounter), L5. P1 follows D2 as planned. I3 (the intent clean-up) fits anywhere after I2c.
- **The switch is the last step.** L4's code can land with `enabled` false and be tested with the switch forced in a match setup. `enabled` goes true only when L3, T and L4 are all in, in a data commit with the golden regeneration. So no build ever has fighters at depth over ground that is a trench across the band.
- **Beams at the switch.** Until L5 a beam has no depth, so its groove would cross the whole band. L4 should at least set `oz` to the firing fighter's depth, or L5 lands with it.
- **Camera and Rendering** work alongside and need no sim window. After L1 the lane table exists; after L0 every event carries `z`.
- **My part.** L0 and L2, the state and hash lines of every other slice (T's are the row arrays and `low`), a read-only review of each, and the neutrality proofs.

## 6. Risks

**Determinism**
- Plan and outcome can disagree once the predictor has to see footprints again. B2 needed three fixes to reach 220 of 220. The probe's test has to cover depth and run in QA's batch.
- A candidate order that depends on bucket layout would break replays. Rule: candidates in index order, the earliest crossing wins, ties to the lower index.
- A new field left out of the hash. Each slice's review lists its fields against `hash.gd`.
- Facing flips when two fighters are at the same x in different streets. Rule to settle in L2: facing keeps its last sign while `|dx|` is under a small threshold.

**Cost on old laptops and phones**
- The numbers in section 2 are from one desktop. A measured tick on the lowest target (the browser on a phone or an old laptop) is needed before T.
- A launch decision's predictor cost grows with depth candidates and the two-row ground lookup. Encounter measures it in L4; the first lever is fewer candidates.
- A dig across all rows is a one-tick spike (levers in section 2).
- T is one more World window before the switch. If it runs long, the switch waits; L4's code does not.
- The full hash is already 29 ms. Rollback or desync checks online cannot run it every tick; that is a note for Netcode, and the reason rows are hashed sparsely.
- Occlusion: the prototype hid a fighter behind a building 35% of the time. That is Rendering's and Camera's core problem, not an edge case.

**QA re-baselines**
- L4 moves every band at once: collateral, brunt share and chains, launch variety, match length, win rates, location shares, and the mood and style rates that follow them. Blasts by plan distance alone lower collateral in the back rows.
- The parity probes that depend on a seed's events (the wired-number rows) will need new seeds at L1 and L4, as happened with B2.
- D1's re-baseline and L4's are separate. Folding L1 into D1 avoids a third.

**Scope**
- The exchange templates were written for a line. Throws, wall splats and finishers that assume "the building beside us" need Combat's and Encounter's pass before L4.
- Split-screen: two fighters in different streets need the camera's depth mapping per pane (Camera).

## 7. Tests I will add

- **Depth is neutral until the switch-on:** every fighter's `z` and `zT` are 0 over the golden matches (L0 to L3).
- **No depth in the intent:** the lint of section 4.
- **The seam:** a flight with a waypoint that crosses x = 0 gives the same `z` per tick as the same flight half a planet away.
- **The band clamp:** no body leaves the band, at any tier.
- **Rows:** with identical rows, `groundY(S, x, z)` equals `groundY(S, x, 0)` bit for bit (T).
- The plan-equals-outcome test with depth is World's (the probe).

## 8. What I need from the other directors

**Encounter:** answered (section 10).

**World:** answered (section 11).

**Camera:** answered (section 13).

**Rendering:** answered (section 12).

Also: Tools for the schemas of the new data files (in the same commit as each file), and QA for the re-baseline at L4.

## 9. Rulings (EP, 2026-10-01)

1. **The band.** Two streets and two block rows, 32 bh deep, with rows 0 and 3 as scenery. Camera may shrink it for readability.
2. **A free fighter meets a footprint.** It is stopped, as in the prototype Orb liked: it slides along the wall or lands on the roof, and an attack ploughs through. The sim does not side-step it. Streets are kept clear, so in a city this happens only after a flight ends inside a block.
3. **Terrain rows land before the switch-on, as slice T** (revised after Rendering's finding; section 12). The order is I2c, L1 with D1 (World), L0 and L2 (Simulation), L3 and T (World), L4 (Encounter), L5.

## 10. Encounter's section (folded from `docs/director/fight-lanes-director.md`)

That file is the plan for L4 and L5 and holds the detail. What it decides, and what it changes here:

| Ask | Encounter's answer | Effect on this plan |
| :--- | :--- | :--- |
| The default deviation | A target depth at the end of the flight (`aimZ1`). 0.3 to 1.0 bh for a shove, 0.3 to 1.2 bh for a vertical launch, 0.6 to 2.5 bh for a long one. Skewed small (`u²`), leaning back toward the lane's centre near an edge, and clamped inside the starting lane with a 0.5 bh margin. Two keyed draws per decision; `S.rng` is not touched. No difference between hero and villain. | A shove is not a flight, so it moves depth through `zT` and the free ease. The keyed draw takes one integer: `ex.n * 8 + combo` covers the chain links. |
| Targeted deviations | Only a BUILDING SMASH, or a throw or launch at a formation or a prop, leaves the lane. | None: B2's aim fills the waypoint as now. |
| Alignment | The attacker moves. `ex.z` is the defender's depth at `requestAttack`, and the rush or pursuit homes to it in its own time. An exchange is fought wherever the defender is, inside a block row too. | `Exchange.z` and the rush homing (L0, L2) are enough. |
| A rush with a footprint in the way | It ploughs through, and each footprint takes a brunt hit. A fighter with care above 0 arcs over a building whose roof is within 6 bh of the path. | See "The rush" below. |
| After a flight | The fighter stays where it landed: `zT` is the landing depth. Inside a block row, when it is next free and moves, `zT` becomes the nearest point of the adjacent street, 1 bh in from the kerb. | `zT` is set by the sim at a flight's end and may be set by the director (the block exit). |
| Data and feed | `data/director/depth.json`, with `enabled` false until L4, and Tools' `director-depth.schema.json`. Feed lines `DEPTH`, `ALIGN`, `RUSH`, `REST`; `launch_plan` lists each candidate's end depth. | The file is the director's, not `data/combat/` as I suggested. |
| Predictor budget | At most 12 flights, 16 aim solves and 3,000 steps a decision; 0.3 ms typical and 1 ms worst. One gather of the footprints near the launch, reused by every candidate. | See "The budget" below. |

**The rush (my proposal for L3 and L4).** The director finds the crossings once, at the request, with World's swept test along the rush line, and schedules each hit as a beat at its crossing time. `SimFighter.stepRush` stays a tween with no collision test, so the plan and the outcome cannot differ. Going over a roof needs an arc on the rush: a `Rush.arc` field (core, hashed), which Combat's variety pass also asks for.

**The budget did not fit its step cap** (Encounter has since taken the smaller cap: 1,100 steps, 8 flights, 8 aim solves, with early exits). I measured the predictor today on Orb's PC (400 flights, 190 steps each on average): 0.87 µs a step.
- 3,000 steps is 2.6 ms today, not 1 ms.
- A typical decision (4 to 6 flights) is 0.7 to 1.0 ms, not 0.3 ms.
- With the depth waypoint, and the two-row ground after T, a step is about 1.3 to 1.5 µs: up to 4.5 ms for 3,000 steps.

Either the cap comes down to about 1,100 steps for 1 ms, or the target is restated as about 1 ms typical and 4.5 ms worst on this PC. A decision comes about ten times a minute, so the mean is unaffected; the question is the one-tick spike on a machine 5 to 10 times slower. Encounter's rule that a non-targeted flight in a city needs no footprint test keeps the swept test off most steps.

**The switch.** One flag, in the director's file (section 11).

**Still open, for Game Design** (Encounter's asks): the protector going over while the feeder ploughs, exchanges fought inside a block row, and the sizes above.

## 11. World's section (folded from `docs/world/fight-lanes-world.md`)

That file is the plan for L1, L3, T1 and T2 and holds the detail (`districts-plan.md` section 13 is D1's revision). What it decides, and what it changes here:

| Ask | World's answer | Effect on this plan |
| :--- | :--- | :--- |
| The lane table | `data/biomes/lanes.json`: the band (`z_front`, `z_back`), the lanes (name, kind, z range, row), the street strips (sidewalk, kerb parking, carriageway) and each archetype's use of them. The derived table is `S.lanes`, not hashed; a probe checks that the data reproduces it bit for bit. | The band limits are read from `S.lanes`, not from `SimConst`. `S.lanes` is unhashed like `S.bIdx`. World's data files join the replay header's data hash (below). |
| Streets clear | By construction: every row 1 and row 2 footprint lies inside its block lane, flush to its street, with no z jitter. Avenues are the same x intervals in both block rows, so they are real cross streets. A hard probe checks it on every seed. | A flight that stays in a street needs no footprint test (Encounter's cost rule holds). |
| The band | Confirmed: +5 to -27 bh. Rows 0 and 3 are scenery: damaged by blasts and beams, never brunt targets or collision candidates. Brunt candidates come from rows 1 and 2 only, from D1. | None. A flight that leaves the band is a bug, and my band-clamp test covers it. |
| Terrain rows | 8 rows of 300 units, as data (`rows`, `spacing`), so a phone build can try 6 rows of 400. The base relief stays one row. No water flow between rows: every wet column's surface is the sea level, so the rows agree. One water window steps all rows. The relaxation limits the step between neighbouring rows. | The row count is data, so the arrays are sized at `genWorld`. Two cost notes below. |
| The swept test | Pure functions: `WorldStructures.along(S, xa, xb, pad)` (the candidate list, once per flight, in index order), `WorldStructures.sweep(S, list, x0, y0, z0, x1, y1, z1, rx, ry, rz)` (the earliest crossing, ties to the lower index, with the face and the wall normal), `WorldStructures.blocked(...)`, `WorldLanes.laneAt(z)` and `WorldLanes.clearLane(S, x, z)`. Buildings, formations and props share one candidate list. A fighter's body is 0.3 by 0.5 by 0.3 bh (data). | This replaces my suggested signature. `laneAt` and `clearLane` are what Encounter asked for (the lane's bounds come from `S.lanes`). |
| The contact rule | World supplies `blocked` and the wall normal. The rule is ruled (section 9): stopped, slides along the wall or lands on the roof. | It lands in L3, in the free branch of `fighter.gd`, by grant. |
| L1 in D1 | Yes: no state field, no dependence on L0. | The order in section 5. |
| Traffic and props | Moving vehicles and foot traffic are Rendering's dressing in the street strips, outside the sim and the hash. Parked cars are V1 props in the kerb strips, clear of the fighters' corridor. | As section 2 assumed. |

**The switch: one flag, in `data/director/depth.json`.** World suggested `data/combat/depth.json` and Encounter `data/director/depth.json`. The numbers are the director's policy and the file is Encounter's, with Tools' `director-depth.schema.json`; `data/combat/` was only my first suggestion. So that World and the core do not read the director's file, `SimCore.newMatch` copies `enabled` into `S.depthOn` (hashed, one bool), and the collision test, the contact rule and the core's depth rules read only `S.depthOn`. A match setup may force it (`"depth": true`), so the probes can exercise L2 and L3 before L4.

**The replay header.** `SimReplay.dataHash()` covers the director's, the roster's and the mood's data, and none of World's. `lanes.json` and `settlements.json` should join it, so a replay refuses a different layout with reason `data` and does not diverge at tick 0. World supplies a `dataHash()`; the line in `replay.gd` is mine (L0).

**Two cost notes for T1 and T2** (superseded by section 12: water keeps one row, so the first no longer applies).
- **Shared water windows cost up to eight times today's step.** I measured 90 µs a tick while a window is open, for one row. A window that steps all 8 rows is about 0.7 ms a tick while open, and the worst case (8 windows) about 2.9 ms. If a window records the rows it covers, only the rows a dig touched are stepped, and my estimate of 200 to 350 µs holds.
- **The relaxation between rows adds to a dig.** My estimate (the rows touched, times today's 0.13 to 0.41 ms) did not include a sweep across rows. Allow half as much again until it is measured.

**Still open.** Trees' `z` (World's section does not say; a tree line across the band is the fallback). Camera's confirmation of -27 bh.

## 12. Rendering's section, and the terrain rows before the switch-on

Folded from `docs/rendering/fight-lanes-render.md`, which holds the detail (occlusion, depth aids, closer framing).

**The finding.** After L4 fighters stand at any depth on the sim's ground. If the rows came later, a crater would still be a trench across the band in the sim while Rendering draws a bowl. Rendering would have to draw the trenches (the "canyons" Orb rejected) or let fighters at depth float over or sink into the drawn ground. Neither is acceptable, so the terrain rows have to be in before the switch.

**Recommendation: one terrain slice (T) before L4, smaller than T1 and T2 were, and neutral.** What makes it smaller:
- **Rows for the heights only** (`deform`, `rubble`). `scorch` and `crack` are paint and stay one row.
- **Water is not touched.** It runs on the lowest ground across the rows (section 2). `water.gd` is the most delicate of World's terrain files (the no-inland-flooding proof), and it keeps its code, its windows and its cost. This also answers Rendering's water ask: the surface is level across the rows by construction.
- **One slice, not two.** The local writes sit behind `S.depthOn`, so the slice is neutral and proven on the light digests, and the probes exercise it with the switch forced. The behaviour arrives with the one switch-on.
- **No relaxation between rows is needed for craters:** a bowl is as smooth in depth as along x. A heap's edge is the one steep step; World decides whether rubble spills into the street.

**The EP's interim** (bowls in depth by formula at dig time, stored per row only inside the crater's footprint) is this slice's dig: the bowl formula takes the plan distance, and only the rows inside the footprint are written. The difference is dense arrays under it, which are simpler than a sparse store and cost 300 KB. I see no cheaper interim that Rendering would not also have to mirror and then throw away.

**The delay.** One World window more before the switch (D1 with L1, L3, T, in place of D1 with L1, L3). L4's code does not wait: it lands switched off, and only the flip of `enabled` waits for T (section 5). World should confirm T's size against its own estimate for T1 and T2.

**Rendering's other asks**

| Ask | Answer |
| :--- | :--- |
| One row exactly on z = 0 | Yes: rows at +300, 0, -300 … -1,800 (section 2). `lanes.json` gives `rows`, `spacing` and the first row's z; the validator checks that 0 is a row. |
| `groundY` clamped outside the edge rows | Yes. The band's front edge (+375) and back edge (-2,025) read the edge rows. |
| The lane table in a form the ground shader can read | World's `S.lanes`: I ask World for a flat packed array (per lane: z range, kind; per strip: z range, kind), the same all round the band, plus each district's x interval and lane use. It is derived data, so Rendering may read it every frame. |
| Nothing cosmetic within a fighter's reach | Agreed, as a rule of this plan (section 2). The sim sends what Rendering needs to clear the way: `launch_depth` for every launch (L0) and the attack events. Anything that stays near a fight is a prop in state (P1). |
| Water between rows | Level by construction (above). |
| 8 rows or 16 | 8. Rendering can draw 16; the sim's dig cost doubles with them. The count is data, so 16 rows of 150 can be tried if the camera is raised. |
| Occlusion, depth aids, close-ups | No new sim state: Rendering reads `z`, the footprints, `ex.z`, the waypoint and the beam's `oz` and `zs`. The picks are Orb's and Camera's. |

## 13. Camera's section (folded from `docs/camera/camera-v2.md`, section 6)

| Ask | Camera's answer | Effect on this plan |
| :--- | :--- | :--- |
| The deepest readable depth | All of the band. The floor is 23 px at 720p. At -27 bh a fighter is 30 px at the fight zoom and 24 px at the wide shared zoom. The lens does not change for the side view. | The band stays as it is. |
| What it reads | `z`, `zT` and `ex.z` each tick, and `launch_depth` for every launch (the end depth and the time to it). Otherwise only the events it already reads. | All four are in L0. They are plain state fields and one event; the camera writes nothing. |
| Two fighters in different streets | Framed by their screen positions, with the zoom sized for the deeper fighter. In a split each pane frames its own fighter. | None. |
| The cut-away | Rendering's porthole, with the radius from the fighter's apparent height. | No sim state. |

**A correction to pass on.** Camera's table takes the band's back edge as -32 bh (2,400 units behind the plane). The band is 32 bh deep but starts at +5 bh, so its back edge is -27 bh (2,025 units). Camera's row for -27 bh is therefore the true worst case: 30 px at the fight zoom and 24 px at the wide zoom, both above the floor. Its option for Orb, "keep 32 bh or shrink to 27", is already answered by the band as planned, and the rule "size for the deeper fighter" is a safeguard, not a need.

**Outside this plan.** Camera also asks the sim for a slow-motion scale in the match header, a recorded skip intent if Orb picks skippable cinematics, and an intro hold at tick 0. None of them concerns depth. Each needs its own brief once Orb has answered Camera's options. One constraint to state now: anything that changes sim time has to be a match setting in the replay header, the same for both players, and never a per-player preference.

## 14. L0 and L2 prepared, and the new order (2026-10-02)

**Prepared.** L0 and L2 are built and proven in a scratch copy of 5fe078a and parked as scripts in `docs/architecture/pending/` (its README has the steps and the proofs). They touch only `sim/core`.

**Scope, corrected while building** (section 5's table said more than the core can do alone):

| Item | Was in | Now |
| :--- | :--- | :--- |
| The depth waypoint for every flight and slide | L2 | World's L3: the waypoint is stepped by `WorldBrunt.stepZ`, which its predictor shares. L0 gives it the field `zWay` |
| Ground height at `z` | L0 and L2 | With the terrain rows (T): `groundY(S, x, z)` is World's signature, and until the rows exist it would ignore `z` |
| `launch_depth` for every launch | L0 | Encounter's L4: only the planner knows an unaimed launch's end depth and time |
| World's data hash in the replay header | L0 | When World has a `dataHash()` (D1 with L1); the line in `replay.gd` is mine |
| The director's data switch | L0 | L4: `S.depthOn` reads the setup's `"depth"` now, and `data/director/depth.json` when Encounter's file exists |

Added to L0 from the ground-contact review: `launch` carries `ux`, `uy` and `n`.

**A quirk found:** `WorldBrunt.stepZ` runs only while a fighter is launched, so a fighter who ends a brunt flight away from the plane keeps that depth until his next launch (it eases to 0 only during a flight). With depth on, L2's `stepDepth` owns the depth outside flights; with it off, today's behaviour is unchanged. World should know for L3.

**Order (EP, with Orb's ruling that depth stays behind the ragdoll physics):** Encounter's landing and contact slices; World's G1 and structure reach; **L0 and L2** (neutral, accepted ahead of G2 because both rewrite the launched branch); World's G2 to G5; the intro phase; the last stand; then the rest of the lanes (L1 with D1, L3 and T, L4, L5).

