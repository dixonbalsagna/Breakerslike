# Fight lanes: the architecture plan for real depth (ADR 0009)

Owner: Simulation and Engine. Status: plan, docs only (2026-10-01). Nothing here is in the sim yet. It answers ADR 0009 ("depth is real, and the choreographer owns it entirely") with a depth model, the state it touches, what stays as it is, the slices and their owners, and the risks. Sections 8 and 9 list what Encounter, World, Camera and Rendering have to decide; their answers become sections of this file.

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
| Traffic and street crowd | None. | Cosmetic: Rendering places them from the lane table and the `evacuate` events (V1's fast evacuees are counts). |
| Props (V1) | `S.props`: World's record gains `z` and the same waypoint as a fighter's flight. | Only held and thrown props step. A parked prop is a blocker with a footprint. |
| Terrain | `deform`, `water`, `scorch`, `rubble`, `crack` become `NR` rows each. The base relief stays one row. | Below. |
| Events | Every event with an `x` and a `y` carries `z` (the field exists on `FxEvent`). | For Rendering, VFX, Camera and Audio. |

### Terrain rows

- **Proposal: 8 rows, 300 units (4 bh) apart, across the band.** `groundY(S, x, z)` interpolates linearly between the two nearest rows, so the ground is continuous in depth. An ordinary crater (bowl radius 160 to 600 units) covers 1 to 4 rows and reads as a bowl; a special one (up to 8,320 units) covers them all, as now.
- **The base relief stays one row** (section 3), so generation, biomes and the sea rule do not change.
- **Not a full grid.** 32-unit cells in depth would be 75 rows and 1.8 million values: too slow to step and to hash in GDScript.
- **Water.** Each row floods along x by today's rule. Flow between rows is World's question (section 8); the cost below assumes none.

**Cost, measured on Orb's PC today** (seed 3, 20,000 ticks, one row) and estimated for 8 rows:

| | Today | With 8 rows |
| :--- | :--- | :--- |
| Mean tick | 99 µs | about 110 to 130 µs |
| `groundY` | 0.48 µs a call | about 1 µs a call (two rows and a blend). A launch decision runs up to 16 predicted flights of 240 steps: up to 2 ms more on that one tick in the worst case, about 0.5 ms typically. |
| A dig, with its relaxation | 0.13 to 0.41 ms each, 46 in the run | Times the rows touched: 0.13 to 1.6 ms for an ordinary crater, 1 to 3.3 ms across all 8 at the size measured. The largest specials were not measured. |
| Water, while a window is open (12% of ticks) | 90 µs a tick | 200 to 350 µs a tick. The worst case is unchanged: `MAX_WINDOWS` (8) bounds it whatever the row count. |
| Full state hash | 29 ms (19,030 values) | About 80 ms if `deform` is hashed densely; about 30 ms if rows are hashed as their non-zero columns, which I recommend. |
| Memory of the per-column arrays | 96 KB | 768 KB |
| Copy of those arrays (a rollback save) | 2.8 µs | about 25 µs |

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

One sim editor at a time. Mechanisms land behaviour-neutral, switched off by data; one slice switches them on. That gives one large behaviour change and one QA re-baseline for it.

| # | Slice | Owner | Behaviour | Goldens |
| :--- | :--- | :--- | :--- | :--- |
| L0 | Depth plumbing: `zT`, `Rush.pz`, `Exchange.z`, `Beam.oz` and `zs`, `Slide.z0` and `z1`, `z` on every positioned event, `launch_depth` for every launch, the band constants, `groundY(S, x, z)` with a default (World's line, by grant). All zero. | Simulation | Neutral. Proof: parity passes on the untouched goldens before the fields are hashed; after the regeneration the per-tick light digests and tick counts are identical. | Regenerated once (hash only) |
| L1 | The lane table (`WorldLanes`) and the layout on it: streets kept clear, footprints by lane, rows 0 and 3 as scenery, trees' `z`. Folded into D1, which re-lays the city anyway. | World | Changes (the layout) | D1's regeneration |
| L2 | Depth in the core, switched off: the free ease to `zT`, the rush homing, the exchange alignment, the waypoint for every flight and slide, the band clamp, ground height at `z`. The director still passes zero. | Simulation | Neutral. Proof: parity on untouched goldens. | None |
| L3 | True collisions, behind a data flag (off): the swept footprint test for bodies in `fighter.gd`'s launched branch (by grant), the same test in the predictors, blasts by plan distance, the free-fighter contact rule (section 9, question 2). The probe's plan-equals-outcome test gains depth. | World | Neutral while off | None |
| L4 | **The switch-on.** The director plans depth: the small deviation on every smash, launch and throw (a keyed draw by exchange index, numbers in data), the targeted deviations, alignment before an exchange, where a flight's end leaves the fighter. The collision flag goes on. | Encounter | Changes | Regenerated; QA re-baselines every band |
| L5 | Beams in depth: the beam plan sets `oz` and `zs`; hits, scorch and the strike crater follow the ray. | Encounter, with World for scorch | Changes | Regenerated |
| T1 | Terrain rows, storage only: the five arrays become rows, every writer still writes the whole band, the hash takes rows sparsely. | World, with granted lines in `state.gd` and `hash.gd` | Neutral. Proof: light digests identical. | Regenerated once (hash only) |
| T2 | Terrain rows, local: craters, furrows, scorch, rubble and water written by depth extent. | World | Changes (small while fights stay in one street) | Regenerated |
| P1 | Props and formations as blockers on lanes (V1 and N1, already planned). | World, with Combat and Controls for the context button | Changes | Their own regenerations |

- **Order.** I2c (Controls) keeps the next window. Then L0, L1 with D1, L2, L3, L4, L5. T1 can land any time after L1. T2 lands with or after L4. P1 follows D2 as planned. I3 (the intent clean-up) fits anywhere after I2c.
- **Why the terrain rows are not first.** True collisions and lane fights do not need them, and they are the largest refactor (World's five terrain files, and Rendering has to draw eight deformable strips). Until T2 the ground is as today: a crater is a trench across the band.
- **Camera and Rendering** work alongside and need no sim window. After L0 every event carries `z`; after L1 the lane table exists.
- **My part.** L0 and L2, the state and hash lines of every other slice, a read-only review of each, and the neutrality proofs.

## 6. Risks

**Determinism**
- Plan and outcome can disagree once the predictor has to see footprints again. B2 needed three fixes to reach 220 of 220. The probe's test has to cover depth and run in QA's batch.
- A candidate order that depends on bucket layout would break replays. Rule: candidates in index order, the earliest crossing wins, ties to the lower index.
- A new field left out of the hash. Each slice's review lists its fields against `hash.gd`.
- Facing flips when two fighters are at the same x in different streets. Rule to settle in L2: facing keeps its last sign while `|dx|` is under a small threshold.

**Cost on old laptops and phones**
- The numbers in section 2 are from one desktop. A measured tick on the lowest target (the browser on a phone or an old laptop) is needed before T1.
- A launch decision's predictor cost grows with depth candidates and the two-row ground lookup. Encounter measures it in L4; the first lever is fewer candidates.
- A dig across all rows is a one-tick spike (levers in section 2).
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
- **Rows:** with identical rows, `groundY(S, x, z)` equals `groundY(S, x, 0)` bit for bit (T1).
- The plan-equals-outcome test with depth is World's (the probe).

## 8. What I need from the other directors

**Encounter**
1. The default deviation: its size (I suggest a few bh over a whole flight), its distribution, and whether the hero and the villain differ.
2. Alignment before an exchange: who moves to whom, how fast, and whether an exchange may be fought inside a block row or only in a street.
3. A rush with a footprint in the way: plough through (the prototype), go round, or go over.
4. Where a fighter stays after a flight: where it landed, or back to a street.
5. The data file for these numbers (I suggest `data/combat/depth.json`) and the debug feed lines that explain a depth choice.
6. The predictor's cost budget at a launch decision.

**World**
1. The lane table: its shape, per district or per settlement, the guarantee that a street is clear, and the cross streets.
2. Confirm the band (section 1) and which rows are scenery.
3. Terrain rows: 8 by 300 units or another count; water between rows or not; whether any base relief must vary in depth (a quay, a riverbank).
4. The swept test's interface (I suggest `WorldStructures.sweep(S, x0, y0, z0, x1, y1, z1, r)` returning the building index and the crossing point).
5. The free-fighter contact rule (section 9, question 2) once it is decided.
6. Whether L1 can be part of D1.

**Camera**
1. The deepest `z` at which a fighter stays readable, and whether the lens changes. This sets the band.
2. What it reads each tick: I offer `z`, `zT`, `ex.z` and `launch_depth` for every launch (the end depth and the time to it).
3. Framing two fighters in different streets, in one view and in split-screen.

**Rendering**
1. The occlusion method (cut-away or porthole) and the state it needs. The footprints near each fighter are already in state.
2. Whether 8 deformable terrain strips are affordable on the Compatibility renderer and on a phone, or how many are.
3. The depth aids (shadow, lane line) and what they read: `groundY(S, x, z)` is enough for both.
4. Traffic and street crowd as cosmetic, placed from the lane table.

Also: Tools for the schemas of the new data files (in the same commit as each file), and QA for the re-baseline at L4.

## 9. Questions for the EP

1. **The band.** Two streets and two block rows, 32 bh deep, with rows 0 and 3 as scenery. Camera's answer may shrink it.
2. **A free fighter meets a footprint.** My recommendation is the prototype's rule: it is stopped, slides along the wall or lands on the roof, and an attack ploughs through. Streets are kept clear, so in a city it happens only after a flight ends inside a block. The alternative is that the sim side-steps the fighter into the nearest clear lane. This is a feel call for Orb.
3. **Terrain rows after the switch-on** (T1 and T2 as their own track), so a playable depth build arrives sooner. The alternative is rows first, which delays L4 by World's largest refactor.
