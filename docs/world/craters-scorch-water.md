# Craters, beam scorch and water

Owner: World and Environment. Status: implemented in the GDScript sim (ADR 0006), 2026-09-29. Code: `sim/world/crater.gd`, `sim/world/water.gd`, and the call sites named below. Checks: `sim/world/tools/probe.gd`. Events and persistent state for Rendering: `docs/architecture/fx-events.md`.

This answers Orb's greybox notes: craters should look like craters and not canyons; beams should scorch and leave trails of destruction that scale with their power; water should have a simple fluid simulation. The EP ruled that rims are gameplay (the sim's 1D profile has raised rims) and that Rendering draws the bowls in depth with the z = 0 slice equal to the sim's profile.

The frozen JS core keeps the prototype's cos-squared notch. Nothing here changes it.

## 1. Craters

### One scalar: impact energy E

A crater's size comes from one number, E. Bowl radius `R = R_BASE * sqrt(E)` (58 * sqrt(E), capped at 260). Depth, rim and furrow follow from R, so every source only has to say how much energy it carries.

| Source | Where | E | Notes |
| :--- | :--- | :--- | :--- |
| Launched fighter hits the ground (`impact`, speed above 350) | `fighter.gd` | `(speed / 900)^2 * (1 + 0.25 * (tier - 1))` | tier is the launcher's. Speed and the horizontal share `vx / speed` also set glancing depth and the furrow |
| Ground-level power-up (`tierUp`, within 140 of the ground) | `fighter.gd` | `1.6 * tier * sqrt(tier)` | tiers 2 to 4 |
| Heavy-clash shockwave (`clashWave`) | `director/melee.gd` | `0.8 + 0.9 * tier` | tier is the higher of the two |
| Beam-clash blast (`explode`) | `world/structures.gd` | `1.6 * tier * (1 + 0.25 * tier)` | the blast's damage radius and damage are unchanged |
| Beam ground strike (steep beams) | `director/beam.gd` | `2.0 * P * (1 + 0.4 * P)` | P is the beam-power scalar (section 2). At most one per beam |

Size by energy, straight-down hit on flat ground (from `probe.gd`):

| E | R | depth | rim | depth / diameter | rim and apron area / bowl area |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0.5 | 41 | 9.0 | 4.5 | 0.11 | 0.60 |
| 1 | 58 | 12.8 | 6.4 | 0.11 | 0.60 |
| 2 | 82 | 18.0 | 9.0 | 0.11 | 0.60 |
| 4 | 116 | 25.5 | 12.8 | 0.11 | 0.60 |
| 8 | 164 | 36.1 | 18.0 | 0.11 | 0.60 |
| 16 | 232 | 51.0 | 25.5 | 0.11 | 0.60 |
| 30 | 260 (cap) | 57.2 | 28.6 | 0.11 | 0.60 |

Against the prototype: at the typical impact (speed 1,200, tier 2) the bowl is 86 in radius and 19 deep where the prototype's was 112 in radius and 31 deep (0.28 R against 0.22 R); a fast tier-4 hit (speed 2,600) is 222 wide where the prototype's was 206 and 60 deep where the prototype dug up to 90. Power-ups and explosions come out 5 to 20 percent wider than before at the same or slightly lower depth (a tier-2 power-up is 27 deep where it was 26), and now have rims. Small impacts are smaller: a speed-400 impact is a 26-radius scuff where the prototype dug 60. The main change in look comes from the rim, the smooth bowl and the depth cap, not from the numbers alone.

### The profile

`WorldCrater.profile(u, depth, rim)`, with u the distance from the centre in units of R. It uses polynomials only, so it is exact and cheap, and the renderer uses the same function for the z = 0 slice.
- Inside the lip (u below 1): a smooth bowl, `-depth * (1 - u^2)^2`, flat at the bottom and easing into the lip.
- Rim: from 0.3 R inside the lip (`RIM_IN`) a smoothstep rises to the crest of height `rim` at the lip (u = 1), then an apron falls smoothstep-wise to nothing at 1.0 R beyond the lip (`RIM_OUT`).
- `rim = 0.5 * depth` (`RIM_H_FRAC`).

Volume: the rim and apron carry 0.60 of the bowl's volume in the 1D profile (the last column of the table; the same for every E). The rest is what real craters lose to compaction and fine ejecta. "Roughly conserve" is met at 60 percent; raise `RIM_H_FRAC` to 0.8 to get to about 1.0, at the price of rims as tall as 0.8 of the depth. Orb decides how tall a rim should read.

The profile is added to `S.deform`, clamped to -260 (the prototype's floor) and +60 (`DEFORM_CEIL`, new: rims and aprons stack, so they need a ceiling).

### Repeated hits and shafts

A hit digs no deeper than `RELIEF_MAX_RATIO * R` (0.26 R) below its surroundings. The surroundings are measured from `S.deform` at 1.2 R on each side of the centre, so a spot that is already dented has less relief left to give. Consequences, all checked in `probe.gd`:
- 61 identical E = 8 hits on one spot: one crater (36 deep). The rest find no relief left and dig nothing (no record, no event).
- 80 small hits (E = 0.5) into the floor of an E = 16 bowl: one dent of 6 units, then nothing more.
- 400 random hits of E 1 to 30 within a 600-unit stretch: the deform stays inside -260 to +60, and the record list stays under its cap.
A bigger hit on an old crater does deepen it, up to its own relief limit. A chain of overlapping hits along a line digs a trench, which is what a long beam should do; it just cannot dig straight down forever.

### Glancing hits and the furrow

Only `impact` craters use the direction. With `vert = |vy| / speed` the bowl depth is scaled by `0.6 + 0.4 * vert`, so a flat skim digs 60 percent of a straight-down depth. If the horizontal share `|vx| / speed` is above 0.35 a furrow runs into the bowl from the side the fighter came from: full length `1.1 R` at a share of 0.85 or more, tapering linearly in between, depth `0.35 * bowl depth` at the bowl end fading to nothing at the tail (`(1 - s / length)^2`). The record has the signed tail offset `skid` and the furrow depth `sdepth`. About 39 percent of impact craters in AI matches have a furrow (369 of 940 craters over 40 matches).

### Persistent list and events

Each crater appends a `SimState.Crater` record to `S.craters` (capped at 400; the oldest is dropped, and its dent stays in `S.deform`) and emits a `crater` event. Field lists and rules are in `fx-events.md`. `S.world.craters` now counts real craters (about 24 a match, against about 190 when every beam sample counted).

## 2. Beam scorch

### The beam-power scalar P

`P = 0.5 + power / 25` (`WorldCrater.beamPower`), fixed when the beam fires and stored on the beam (`b.pw`). `power` is the 0 to 100 meter that Q-charging fills and that sets the tier (`tier = 1 + floor(power / 25)`), so P is tier and charge in one number: it equals the tier in the middle of each band and rises smoothly through it, from 0.5 at power 0 to 4.5 at power 100. The beam's damage used the integer tier; it now uses P, which is the same on average, so collateral does not shift (section 5).

### What a beam does to the ground

For each beam sample (every 36 units or less) whose height is within `beamReach(P) = 40 + 12 * P` of the ground:
1. **Groove.** `scorch()` carves the ground toward a target depth, with a half width `(30 + 22 * P) * width factor` and depth `(3 + 2.2 * P) * depth factor`, cross-section `-depth * (1 - u^2)^2`. It carves toward the target and never adds, so overlapping samples and a second beam over the same trail do not deepen it. Factors by variant (depth, width): RIDGE BORE (1.6, 0.8) drills, GLASS TRENCH (0.8, 1.3) fuses a wide strip, FIRESTORM (1.0, 1.1), BOULEVARD RAZE (0.8, 1.0), MERIDIAN SCAR and HORIZON CLEAVE (1.0, 1.0).
2. **Burn.** `S.scorch[i]` takes `clamp(0.35 + 0.15 * P, 0, 1) * (1 - u^2)` (max with what is there): permanent, per column, for Rendering to tint.
3. **Event.** A `scorch` event (x, ground y, width, P, variant, owner) per sample.
4. **Damage.** Unchanged in form: `damageArea` radius `26 + 8 * P`, damage `110 + 75 * P`.

Groove size (plains):

| P | half width | reach | depth (MERIDIAN SCAR) | RIDGE BORE | GLASS TRENCH |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0.5 | 41 | 46 | 4.1 | 6.6 | 3.3 |
| 1 | 52 | 52 | 5.2 | 8.3 | 4.2 |
| 2 | 74 | 64 | 7.4 | 11.8 | 5.9 |
| 3 | 96 | 76 | 9.6 | 15.4 | 7.7 |
| 4 | 118 | 88 | 11.8 | 18.9 | 9.4 |
| 4.5 | 129 | 94 | 12.9 | 20.6 | 10.3 |

A tier-4 beam cuts a trail about 240 wide, three times the width of a tier-1 trail, and reaches almost twice as far up from the ground.

### The strike crater

A beam that descends at least 0.25 (`|uy|`, about 14 degrees) digs one crater where it first gets within reach of the ground, of energy `2.0 * P * (1 + 0.4 * P)`: R about 97 at P = 1, 156 at P = 2, 210 at P = 3, 260 (the cap) at P = 4 and above. A flat beam only scorches. This replaces sim quirk 7 (a crater every 36 units along any low beam, 190 craters a match); quirk 8 (samples restart at each tick's start) stays, and the 36-unit spacing is a maximum, so the groove is continuous.

## 3. Water

### Rules

`S.water` is the water depth of each terrain column. Standing water's surface is sea level (0).
- **The sea is a reservoir.** A column whose original ground is below -30 (`RESERVOIR_BASE`, the prototype's `seaAt` rule) is always full to sea level. Digging the sea floor deepens the water there at once.
- **Every other column is dynamic.** Water enters one only by flowing from a wet neighbour, and only while the column's ground is below `SHORE_WET` (a quarter of a fighter height under sea level, -18.75; it was -30 x WS = -240 until 2026-09-30, which left a slab of dry land up to 240 units below the sea's surface). At the start of a match the shallows connected to the sea are already full. Otherwise a column is dry, however low.
- **Flow.** Each link between two neighbouring columns moves `0.4 * surface difference` of depth per step, at least 0.25 (or half the difference when that is less), at most 14, and never more than half of a dynamic donor's water. The flows are computed from the old state and applied afterwards, so order does not matter. A step runs every 2 ticks, only in windows around terrain that was just changed below -30 and within reach of water. A window grows to follow the front and closes after 3 quiet steps or 600 steps. Nothing draws a random number.
- **Splash and cover.** `WorldWater.surfaceAt` and `depthAt` are the queries. Submerged hiding (`cover.gd`) now reads them: 60 units under the surface, in water at least 100 deep, no longer only in the ocean biome.
- **Skim** (`fighter.gd`, the water-stop logic): a launched fighter entering water faster than 650 with a descent shallower than 0.5 (rise over run) skips off the surface: `vy` reversed and scaled by 0.55, `vx` by 0.8, up to 3 times a flight (it uses `bounces`), with a splash each time. Steeper or slower entries go in and are slowed exactly as before. A grazing entry at 1,500 units per second skips twice and covers about 900 units; the prototype stopped it within half a second.

### Craters never flood inland

Claim: after any sequence of craters and scorch, every wet dynamic column is joined to the sea by an unbroken run of dynamic columns whose ground is below -30.

Proof: initially every dynamic column has ground of at least -30 (that is what makes a column dynamic), so none is wet. A dynamic column gains water only in a flow step, from a neighbour that is wet, and only if its own ground is below -30 at that moment. So a column can be wet only if a neighbour was wet before it and its ground is below -30; by induction along the chain of donors, each wet column has a neighbour chain down to a reservoir column through columns that were below -30 when the water passed. Terrain can later rise (a rim) but water already in a column is not destroyed by that; it simply flows away. So an inland pit, however deep, has no wet neighbour and stays dry; a bay at the coast fills. The bound on how deep a crater can go (0.26 R below its surroundings, at most 57 units below the ground, against a 30-unit margin below sea level) means only the coast, where the base ground is already at -20 to -30, can go below -30 at all.

Test (`probe.gd`): 1,000 random craters and beam lines on each of three planets, run to rest, then checked against the definition above: 0 wet columns not connected to the sea, 0 in the desert, forest, city or mountains. Five E = 30 craters in plains, city, village, desert and mountains stay dry.

Where water does appear: the coast, at the two ocean edges (x about 1,200 and 8,300). A big crater within about 300 units of the sea becomes a bay: an E = 25 crater at x = 1,200 fills in about 3 seconds (mostly in the first second), one at x = 1,290 in about 5 seconds to 80 percent and about 20 seconds to level. `WorldWater.MAX_AGE_STEPS` caps a window, so a very slow tail can stop a few units short of level.

Crater lakes are shallow: the deepest bay a crater can dig is under 60 units, so they are wading pools. Hiding still needs 100, so nothing can hide in them; only the sea can (and a crater in the sea floor makes it deeper).

## 4. What Rendering and the others need to know

- `S.water` is new state. The renderer draws water only where `seaAt` (base below -30) says so today, so crater lakes will not show until it reads `S.water` (one row more in the terrain texture, or a second texture).
- The bowls in depth come from `S.craters`; the z = 0 slice must equal `S.base + S.deform` there.
- `S.deform` can now rise above zero (up to +60): rims and aprons. Buildings and trees sit on the raised ground (their base follows `groundY`).
- The reference fx consumer ignores `crater` and `scorch` (`view/fx.gd`), so nothing in the render side's particle hash moved.
- Call sites I edited outside `sim/world/`, one line each, and why: `fighter.gd` `tierUp` and `impact` (the crater calls take an energy now), `melee.gd` `clashWave` (same), `beam.gd` `fireBeam` and `sampleBeam` (P, scorch and the strike crater replace the per-sample crater), `sim.gd` `step` (one call, `WorldWater.step`), `state.gd` (new fields), `fx.gd`, `view/fx.gd` and `hash.gd` (the two events and the new state in the hash).

## 5. Numbers, before and after

Same seeds (1 to 1,000, default arm, `batch.gd`), baseline is the tree at HEAD (4cc7e13), both run on this machine.

| Measure | Before | After |
| :--- | ---: | ---: |
| Civilians lost at the KO, mean | 37.7% | 39.4% |
| Structures lost, mean (of 47) | 14.3 | 14.9 |
| Match length, mean | 98.8 s | 102.5 s |
| Craters counted per match | 188 | 24 |
| Hides per match | 1.47 | 1.58 |
| Ambush attacks per match | 0.09 | 0.11 |
| Beams per match | 3.87 | 3.98 |
| P1 (KAI) win rate | 34.9% | 34.3% |
| Timeouts (no KO in 300 s) | 0 | 2 |
| Sim tick cost | 58.1 us | 62.6 us |

300-match check by arm (seeds 1 to 300; civilians lost, share of matches losing 90 percent or more, low-tier bleed in percent of the population per minute while both fighters are at tier 2 or below):

| Arm | Before | After |
| :--- | :--- | :--- |
| default | 32.5%, 2.0%, 17.6 | 33.6%, 3.7%, 17.5 |
| mirror-villain | 54.5%, 10.0%, 39.4 | 52.2%, 9.7%, 36.6 |
| mirror-hero | 24.1%, 1.7%, 14.2 | 24.2%, 1.7%, 12.6 |

The bands in `balance-targets.md` §4 still hold or move by less than the noise: the default mean is inside the P2 band (25 to 50%), the worst pairing is inside its 65% cap, and the 90-percent share is unchanged within noise on the villain mirror (the default-arm share moved from 2.0 to 3.7 over 300 matches, a difference of five matches; it stays under the 7% cap). The mean civilian and structure rises are about 1.3 standard errors, and the length rise of 4 percent is a plausible cause. The low-tier bleed is not a pass against the game band (4 percent a minute) either before or after; that is the collateral ramp's job and is not touched here.

`tempo.gd -- 100 1` (before, after): exchanges per minute 11.74, 11.62; launches per minute 5.30, 5.25; median breathing room 2.58 s, 2.58 s; breathing gaps over 10 s in 51, 60 matches; civilians lost 31.5%, 32.3%; underwater time 3.6%, 4.9%; fight time over the ocean 10.5%, 11.8%; launch mix SLAM DOWN 23.2%, 21.9%. `batch.gd -- 100 1` (before, after): civilians 35.7%, 36.5%; structures 13.4, 14.5; match length 102.0 s, 105.0 s; hides per match 1.64, 1.76; craters counted 195, 24; timeouts 0, 0. Encounter's tempo work is not disturbed; the sea and the skim keep fighters underwater about a second longer per 100 seconds.

Tick cost, measured on the same 20 seeds stepping the sim alone: 53.6 us before, 57.3 us after (+7%); over the 1,000-match batches 58.1 us and 62.6 us (+8%). The `parity.gd` bench (a different 10 matches, since the matches changed) reads 57.8 before and 64.7 after. Most of the extra time is the water windows: about 25 windows open in 20 matches, in about 2.5 percent of ticks, each costing about 0.1 to 0.15 ms per tick while open (a window covers the crater and the front, up to 240 columns). The rest is scorch and the crater loops. p99 of the tick is unchanged (190 to 195 us). Event volume: 1.23 events per tick on average, 55 at most in a tick (was 1.35 and 46); per match about 24 crater events (19 impact, 2.5 beam, 2 power-up) and 136 scorch events.

## 6. Known gaps and what to decide

- **Timeouts.** Two of 1,000 matches did not end in 300 seconds (none before; none in seeds 1 to 100 in the final build). In the one I inspected (seed 1, an earlier build) a fighter hid submerged in the sea and the other could not find it, both at nearly full health. This is the hiding stalemate that already exists (hidden fighters recover 40 HP a second), not a new mechanism, but the changed matches expose it slightly more often. Encounter Systems owns the fix (a hunter's search, or a hide time limit).
- **Volume ratio 0.60.** See section 1. Orb decides how much rim.
- **Crater lakes are wading pools.** Deeper bays would need bigger craters or a lower sea floor near the coast. Not needed for the notes.
- **Water is 1D and instantaneous at a coarse scale.** Waves, tides and currents are out of scope; `waterTick` and the windows are the only hooks.
- **Rims on buildings.** A crater's rim can lift the ground under a building by up to 28 units. Buildings follow `groundY`, so they rise with it. If that reads badly, Rendering can flatten a building's footing, or I can flatten the rim under a footprint.
- **Scorch damage is linear in P.** Orb's "more intense destructive capability" is met by the width, reach, depth and burn scaling and by the linear damage rise; making structure damage superlinear would raise collateral at tier 3 and 4, which is a collateral-cap question for Game Design.
- **Not done from wave 1:** `destruction-rules.md`, `planet-layout.md`, `cover-and-hiding.md`, `escalation-analysis.md` and `biome-schema-fields.md` are still to write; this note supersedes the parts of them about craters and water.
- **Untouched on purpose:** the collateral formulas (`damageArea`, `casualty`), tree burning, and the AI's use of `seaAt` (the AI does not treat crater lakes as sea; they are too small to matter).

## 7. Retune after Orb's playtest (2026-09-29)

Orb: hard ground hits sometimes left no crater and the second, lighter bounce left a large one; ordinary craters were too big; overlapping craters looked strange.
- **The bug.** The high-energy hop (added with the knockback slide) skipped the crater at the first contact and dug at the landing, which was the lighter hit. Now the first contact of a slam always makes the mark and hops once if the speed is 2,000 or more; the hop's landing digs nothing (`Fighter.hopped`). A slide never hops. `probe.gd` checks that a slam at speed 2,800 leaves exactly one crater, at the first contact, with and without the special flag.
- **Sizes.** `R_BASE` is now `20 * WS` (was `58 * WS`): an impact at speed 2,000 on tier 3 leaves a bowl of about 435 units (6 fighter heights) where it left 1,260. Ordinary blows are capped at `ORD_R_MAX` = 8 fighter heights. A tier-2, 3 and 4 power-up is 485, 928 and 1,470 (6, 12 and 20 fighter heights; it is its own ladder, held only by `R_MAX`).
- **The big marks are flagged.** `special` on the blow multiplies the energy by 9 (the radius by 3) and lifts the cap to `R_MAX`. Special: signature beam launches, finisher launches, break launches, the beam strike, the beam-clash blast. `doLaunch` takes a `special` flag (`Fighter.launchSpecial`), set at the launch, and the crater record and event carry `special`. A special slam at speed 2,800 leaves a 1,576-unit bowl against 525 for an ordinary one.
- **Artefacts fixed.** (1) The bowl was centred on its column, not on x: up to half a column of shift, so the sim's profile and the record's did not match; it is now centred on the true x. (2) A rim landing on ground that was already raised stacked and grew spikes; it now merges (the higher of the two). (3) The furrow was subtracted at every column, which could dig a channel deeper than the bowl it ran into; it now cuts toward a target below the ground as it was before the crater, so it opens a channel through the rim and never digs below the bowl floor. `S.deform` is the truth for the ground; the records' profiles are an approximation where craters overlap (the deform limits clip them and rims merge), which the renderer should treat as the shape of one crater, not a sum.
- **The counter.** `S.world.craters` counts real craters (it did, and does); most ground hits are now slides, so it reads lower. `S.world.slides` counts slides so the HUD can show both.