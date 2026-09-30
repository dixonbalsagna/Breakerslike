# B2: the brunt and chains, implementation plan

Owner: World and Environment, with Encounter (the planner's scoring) and Simulation (fighter fields, hash). Status: plan, docs only (2026-09-29), for the sim window after Encounter's dynamic-feel slice. The design is `docs/world/buildings-in-depth.md` (sections 3, 4, 4b, 4c and 10); this note is how it is built on today's code, at today's scale, with the interfaces between the three owners. Bands are Game Design's (`balance-targets.md` §4b, §5b, §5c).

## 0. Where the code is today

- B1 is in: buildings have `row`, `z` (the centre's depth, rows at +10, -8, -22 and -38 bh from the plane, i.e. 750, -600, -1650 and -2850 units), `d`, and the spatial index `WorldStructures.near`. Only the front street (`PLANE_ROW`) collides.
- `SimFighter._buildingHits` is the incidental collision: any launched or sliding fighter whose x is inside a front-street building's footprint and below its top hits it (damage `spN * (0.55 + 0.25 tier)`, thrown back). `DirLaunch.predictFlight` stops the flight at the first front-street building (the same box). The BUILDING SMASH candidate is `nearestBuilding` (front street only), aimed along the plane (`ux = sign`, `uy = 0.12`).
- Encounter already telegraphs a brunt: `melee.launchBeat` calls `SimFx.hazardTelegraph(S, tgt, "brunt", p.t, p.x)` when the predicted flight ends at a building (`p.building`).
- The collateral module gives set pieces a token (`WorldCollateral.beginEvent(S, "chain", cause)`) with the allowance 12 percent at tier 3 and 20 percent at tier 4, none below.
- Damage: `damageBuilding(S, b, d, cause, mode, cx, evt)` already takes the mode (`burst`) and the token; `damageArea` takes the token.

B2 replaces the incidental collision with the director's chosen building, adds depth to the flight, adds the chain, and moves BUILDING SMASH candidates to every row.

## 0b. Conventions Camera and Rendering can rely on

- **Sign of `z`.** Positive is toward the camera, as everywhere in the renderer. The fighter plane is 0; the foreground row is in front of it at `+10 bh` (+750 units) and the rows behind are negative: front street `-8 bh` (-600), mid `-22 bh` (-1,650), back `-38 bh` (-2,850). (B1's constants, `ROW_Z_BH` in `terrain.gd`; an earlier line in `buildings-in-depth.md`, "+70 x WS", was the pre-scale draft and is superseded by these.) A building's `z` is its centre's depth, so a hit point on its face is about `z + d / 2` for a building behind the plane. The fighter's `z` uses the same sign: it runs from 0 to a negative number as it flies into the rows behind.
- **Time.** `launch_depth.dur` is in seconds of match time (a float), the predicted time from the launch to the first hit, as the predictor's `t`. `chain_link.dur` is the same, in seconds, from leaving one building to reaching the next. No event in this plan counts ticks.
- **Small back-row fighter.** At 38 bh the fighter is about 25 px tall for a second or two. If Orb finds it too small, the fix is mine, in the aim: shorten or slow the last-row flights (a back-row candidate's force multiplier capped, or the row's score penalised), to be tuned in B2 step 4. Camera does not have to solve it.

## 1. Split of the work

| Piece | File | Owner |
| :--- | :--- | :--- |
| Geometry and the runtime: aim search, flight to a building, the hit, the carry-on, splash, the fighter's depth | new `sim/world/brunt.gd` (`WorldBrunt`) | World |
| The planner: candidates, scoring, the pity counter, chain choice, the launch telegraph | `sim/director/launch.gd`, `melee.gd` | Encounter |
| Fighter fields and the launched-flight branch | `sim/core/fighter.gd`, `state.gd`, `hash.gd`, `fx.gd` | Simulation, with World's grant for the launched branch |
| Events | `fx.gd`, `docs/architecture/fx-events.md` | World |
| Predictor parity, the aimed-only collision tests | `sim/world/tools/probe.gd`, QA's batch bands | World, QA |

The contract between World and Encounter is `WorldBrunt.aim` (section 2): the planner asks it, scores what it returns, and hands the chosen result to `doLaunch`. World never chooses which building; Encounter never simulates a hit.

## 2. `WorldBrunt`: what it provides

All functions are pure over the sim state, use no random draw, and are the only place geometry lives, so the plan and the outcome cannot disagree.

1. `WorldBrunt.candidates(S, D, A) -> Array[int]`: the buildings worth trying for a launch of the target D by A. Buildings within `BR_MIN` and `BR_MAX` of D.x (90 and 1,300 units at scale 1, times `WS`: 720 to 10,400) on either side, in any row, alive, with the top above D.y minus 40, from `near()`. Preselect the best `BR_PRESELECT` = 2 per side by a cheap score (height, occupancy, freshness). Cost: a bucket walk.
2. `WorldBrunt.aim(S, A, D, b, force, tierF) -> Dictionary or null`: the launch vector that brings the flight into building b.
   - For `uy` in `AIM_UY = [0.05, 0.12, 0.25, 0.4]` with `ux = sign`, run `flightTo(S, D.x, D.y, vx, vy, trav, b)`; keep the first `uy` for which the flight enters `[b.x - b.w/2, b.x + b.w/2]` with y between the ground and the building's current top, at arrival speed above `AIM_MIN_SP` (500, normalised). A building with no aimable `uy` is dropped.
   - `flightTo` is `predictFlight` without building obstacles and with a target: gravity, air drag, water, the slam-or-slide rule (a flight that lands before the building fails). It returns the arrival `{ok, t, x, y, spN, dirx, diry}`. Same constants as `stepLaunched`, one source (`WorldSlide.launchVX`, `launchTravel`).
   - The result is `{ux, uy, fm, b, hit: {t, x, y, spN, ux, uy}, chain: [ {b, spN, dmg, ratio, keep, pop} ... ], deaths, z0, z1}`. `chain` is the lookahead of section 4 (its first element is b itself; a plain brunt has length 1).
3. `WorldBrunt.hit(S, f, b, ...)`: the runtime resolution (section 3).
4. `WorldBrunt.next(S, f, b, spN) -> int`: the next building on the line after b for a fighter at b with speed spN and velocity `(vx, vy)`: the nearest ahead whose footprint the remaining flight enters, above the flight's height there, within `CHAIN_GAP` of b's far edge (260 units x WS = 2,080) and `CHAIN_DZ` of b's row depth (180 x WS = 1,440 in z), or -1. The planner's lookahead and the runtime both call it.
5. `WorldBrunt.z(f)`: the fighter's depth for its progress (section 3).

Cost: `aim` runs at most `BR_PRESELECT * 2 sides * 4 uy` = 16 flights in the worst case; the early exit at the first working `uy` makes it about 4 to 6. Each flight is the 240-step loop with no building list. Encounter measures it against the tick budget; the first lever is `BR_PRESELECT` = 1.

## 3. The runtime: what happens in the flight

New fighter fields (hash them): `aimB` (building index or -1), `aimX0` (the x at the last waypoint), `aimZ0` (the depth at it), `aimZ1` (the depth of the next), `aimD` (x distance to it), `chainN` (buildings hit so far), `chainEvt` (the collateral token), `z` (the depth, 0 unless aimed). `doLaunch` sets them from the plan when the plan has a building (`plan.p.brunt`), otherwise `aimB = -1`.

In `stepLaunched`:
1. **Depth.** If `aimB >= 0`: `p = clamp(|x travelled since aimX0| / aimD, 0, 1)`, `z = aimZ0 + (aimZ1 - aimZ0) * smoothstep(p)`. Otherwise `z` eases to 0 over 0.3 s. `z` is state (hashed), read by Rendering and Camera; it does not enter any physics.
2. **Incidental collision is removed.** `_buildingHits` no longer runs for a launched or sliding fighter, and `predictFlight` no longer stops at the front street (that stop exists to match the old collision). A launch that is not aimed at a building never touches one. Only building `aimB` is tested, and only while `p >= 1` (the fighter has reached its x range) and y is between the ground and its top.
3. **The hit.** On contact with `aimB`, `WorldBrunt.hit`:
   - `sp` is the unboosted arrival speed; `dmg = sp * (0.55 + 0.25 * tier) * BRUNT_MUL`, `BRUNT_MUL = 1.8`; `ratio = dmg / b.maxhp`.
   - `damageBuilding(S, b, dmg, by, "burst", f.x, f.chainEvt)`: the casualties go through `WorldCollateral.kill`, with the chain's token at tier 3 and above.
   - Outcome: `ratio >= 1` collapse; `0.6 <= ratio < 1` heavy wreck; `0.4 <= ratio < 0.6` partial wreck; below `0.4` crack.
   - Splash: buildings within `0.9 w` in x and `SPLASH_Z` (120 x WS) in depth, not in the chain, take `0.25 * dmg`, once per launch (a small set on the fighter: the indices already splashed, capped at 16).
   - The fighter: `spN * 0.012` through `SimDamage.hurt` (one wear hit), then `S.dirS.stop` 0.06 (the first hit 0.35 s and each further one 0.12 s per Camera's proposal, capped at 0.8 s in all).
4. **Carry-on.** After a collapse or a heavy wreck (a further 0.7): `keep = clamp(0.8 - 0.45 * maxhp / 3000, 0.35, 0.8)` (maxhp is the unscaled hit-point value); `vx` and `vy` times keep; continue if the speed is at least `CHAIN_MIN_SP` (500) and `chainN < CHAIN_MAX[tier]` (2, 2, 3, 4 for tiers 1 to 4; 5 only for a finisher, `special`): `WorldBrunt.next` gives the next building, `aimB` moves to it, and the depth waypoints update. Otherwise, or after a partial wreck or a crack (the old reversal, a quarter of the speed backward), `aimB = -1` and the flight is ordinary: it lands by the slam-or-slide rule. The chain's token is closed (`endEvent`).
5. **The predictor still matches.** `predictFlight` (plain launches) simply has no buildings now. The chain's outcome is predicted only by `aim`'s lookahead; a test compares the predicted and actual chain (section 6).

## 4. The planner side (Encounter)

`chooseLaunch` replaces the `nearestBuilding` BUILDING SMASH with one candidate per aimable building from `WorldBrunt.candidates` and `aim`:

`s = BRUNT_BASE (14) + h / 32 (in unscaled height) + 3 * tier + fresh (+4 if hp = maxhp) - care * CARE_W * clamp(popAlive / POP_REF, 0, 1) - REPEAT_B (12 if it is the last building hit) + noise + brunt pity`.

- The personality term uses the fighter's `care` (roster data, so any hero or villain reads it the same way). The villain adds `TALL_W * clamp(h / 400, 0, 1)` (12) and `+2 per row` (the far tower is more dramatic). Drama terms together are capped at `DRAMA_CAP` = 14 against a personality swing of about 60.
- **`POP_REF` has to be re-derived.** The doc's 60 was for a 13-person tower at the old scale; at the current scale a tower holds 1 to 5 people (389 across 216 buildings). Set `POP_REF` to about 8 so the term still spans the range; measure it with the batch, not by argument.
- **Chain terms:** for each further building in `aim.chain`: personality as above (the hero loses up to 34 per occupied building, so he chains only through empty ones), `+5` drama (`CHAIN_DRAMA`), `REPEAT_CHAIN` 12 after a chain. A chain whose expected deaths exceed `WorldCollateral.room(S) + allowance` is dropped (allowance from `EVENT_ALLOW["chain"]` at tier 3 or above, else 0): the planner reads the same numbers the runtime will, so it can never plan what the cap would refuse.
- **The pity counter** `sinceBrunt` in `S.dirS` counts planner launches that had a candidate in reach and chose something else, and adds `BRUNT_RAMP` (5) per count to building candidates; it resets on a building hit (a chain counts once).
- `melee.launchBeat` keeps its telegraph: `hazardTelegraph(S, tgt, "brunt", p.hit.t, p.hit.x)`; for a chain of more than one it is sent again from each `chain_link` (the next building's eta).

## 5. Events (Rendering, VFX, Camera, Audio)

`victim` (the fighter's slot who is being thrown; `FxEvent.victim` exists) and `owner` (the launcher's slot) are on all three. Field names for the `FxEvent` record; hash order as listed.

| Event | Fields | When |
| :--- | :--- | :--- |
| `launch_depth` | `x` `y` (start), `x1` `y1` (the first hit point), `z` (its depth), `b`, `dur` (predicted time), `n` (the planned chain length), `owner`, `victim` | at the launch beat, when the plan is a brunt |
| `building_hit` | `b`, `x` `y` (the hit point) `z`, `damage`, `ratio`, `outcome` (`crack`, `wreck`, `heavy`, `collapse`), `link` (1 for the first), `n`, `spd` (arrival speed), `keep`, `ux` `uy` (the unit velocity at impact, for the shrapnel's direction), `kind` (`tower` or `house`), `w`, `h` (the building's width and standing height), `owner`, `victim` | on the tick of each hit |
| `chain_link` | `from`, `to` (building indices), `x` `y` `z` (leaving), `x1` `y1` `z1` (the next building's hit point), `dur`, `link`, `owner`, `victim` | on a burst-through toward the next building |
| `building_fall` | as B1, `mode` `burst` | as each building falls |

New `FxEvent` fields: `ratio`, `keep`, `link`, `kind`, `ux`, `uy`, `z`, `z1`, `y1`, `from`, `to`, `outcome` (String). `kind`, `w`, `h` are what VFX needs to choose glass and steel (a tower) or timber and brick (a house), and to size the shrapnel by the building's mass. The hash lists them in the order above.

## 6. Tests (all in `probe.gd` or QA's batch; hard unless a band)

1. No launch hits a building it was not aimed at (hard): over 1,000 seeded launches with the aim disabled, zero building hits.
2. The plan is the outcome (hard): for 300 seeded aimed launches, the predicted chain (buildings, order, arrival speeds within 1 percent) equals the runtime's; a mismatch fails.
3. Chain length never exceeds `CHAIN_MAX[tier]`; a chain never uses more than its allowance; nothing else can use it; the fighter's building damage in one launch at most 12 percent of max HP (the chain cap, `buildings-in-depth.md` 4b); and no hero chain through a building with people alive above the empty threshold.
4. Collateral (band): brunts and chains count toward all §4 bands, and a chain at tier 2 or below must fit the window (no borrowing).
5. Determinism: no draw from `S.rng` in `WorldBrunt` (the `rng` position after an aimed launch equals the wear hits it caused, as for the slide).
6. Rates (bands, `balance-targets.md` §5b and QA's rebased brunt and slide bands): brunts among launches with a building in reach, per personality; chains as a share of brunts; per match and per minute.
7. Cost: `aim` flights per launch and the tick's p99 before and after.

## 7. Order of the work in the window

0. **First, Game Design's collateral rulings (before any B2 code):** `WorldCollateral.RELOCATE = true` (evacuees shelter in the nearest standing building outside the danger zone, at most twice its people; `evacuate.dest` is set), and every evacuee feeds menace, `+0.45` per person times `425 / pop0`, for fighters with a menace meter (roster data, as anguish is; anguish gets nothing from evacuees). The menace feed goes in `WorldCollateral.kill` and the district flight, next to `_feed`. The goldens change; QA re-baselines the civilian band (25 to 50 percent mean at the KO, worst pairing at most 70 percent, 90 percent losses in at most 5 percent of matches). The probe's evacuation checks change: `casualties + evacuated` still equals what would have died, but the building's people are conserved by the shelter.
1. `sim/world/brunt.gd` with `candidates`, `flightTo`, `aim` (no chain) and their probe tests (World).
2. Fighter fields, `z`, the aimed collision and `hit` with the outcome table, `building_hit` and `launch_depth`, the removal of `_buildingHits` and the predictor's stop (World, Simulation's grant). Goldens change here.
3. `next`, the carry-on, `chain_link`, the token and the collateral cap, the chain caps (World).
4. The planner: candidates, scoring, pity, chain terms, `POP_REF` from the batch (Encounter, with World reading the numbers).
5. Bands: QA reruns the brunt and chain rows; Game Design tunes; VFX and Camera work against the events from step 2 on.

Steps 1 to 3 need no change in choices (BUILDING SMASH stays a candidate with its old scoring until step 4), so the fight can be checked against today's numbers before the planner changes.

## 8. Risks

- **Tempo.** Removing the incidental collision changes launches that used to bounce off the front street (they now pass through it). Encounter's tempo and location rows (`tempo.gd`) must be rerun at step 2, before the planner is touched.
- **Fewer people per building.** A tower holds 1 to 5 people at this scale, so a single brunt kills few; the chain and the budget do the drama. `POP_REF` and the bands may want Game Design's attention.
- **Aiming cost.** Up to 16 flights in the worst case; `BR_PRESELECT` 1 is the fallback.
- **Depth and the camera.** The fighter's `z` reaches -2,850 (38 bh) for the back row; Camera's framing and Rendering's fighter placement are B3's job, and the ground band's depth must reach that far.
- **Two fighters at once.** A second launch while a chain is open closes the first token (`beginEvent` replaces it); the first chain's allowance is then gone. Rare; documented.


## 9. Floors: Rampage-style skyscrapers (Orb, playtest 2)

Orb: "each skyscraper has floors, windows, a fighter can be blasted through the building and affect individual floors, and may not necessarily bring the building crashing down before causing enough damage." So a brunt on a tall building is local first (floors), and whole-building collapse is what happens when the damage is enough. The sim stays cheap: floors are a bit mask and a lazily allocated damage array; nothing runs per floor per tick.

### What a floor is

- `F = max(1, round(h / FLOOR_H))` with `FLOOR_H` = 2 bh (150 units): a 5,000-unit tower has 33 floors, a 960-unit one 6, a house 2 to 4. A building's floor height is `h / F`, and floor k spans `[g + k h/F, g + (k + 1) h/F]`.
- **Skyscraper mode** is for `F >= FLOORS_MIN` (5). Houses and low buildings use the whole-building rule of section 3 unchanged (a house has nothing to tunnel).
- Per building, two new fields: `fmask` (an int, one bit per standing floor; 62 floors at most, taller buildings use fatter floors) and `fdmg` (a `PackedFloat32Array` of `F` damage values, allocated on the first local hit, `null` before). Both go in the hash (sparse). Untouched buildings cost nothing.
- **Strength.** Floor k's strength is `s_k = (maxhp / F) * FLOOR_STR * (1 + STR_GRAD * (F - 1 - k))`: the lower the floor, the stronger it is (it carries more), by `STR_GRAD` = 0.5 per floor above (starting values; QA tunes them). `maxhp` is the building's unscaled hit points, so the tower's total is what it is today.
- **The core.** `hp` stays the building's structural pool, exactly as now: area damage (blasts, beams, slides, craters) hits `hp` and, when it reaches 0, the whole building implodes (section 4c of `buildings-in-depth.md`) with every floor. Local damage (below) takes `CORE_SHARE` = 25 percent of its damage from `hp` too, so repeated punches wear the building down toward that collapse.

### A brunt on a skyscraper

1. **The hit height picks the floors.** The fighter reaches the building at height `y`; the floor index is `k = floor((y - g) / (h / F))`. His body is about 1 bh tall, so it covers floor k and one neighbour (`HIT_FLOORS` = 2).
2. **Punch-through or stopped.** `dmg = spN * (0.55 + 0.25 tier) * BRUNT_MUL` as before; `ratio = dmg / (s_k * HIT_FLOORS)`.
   - `ratio >= 1`: **punch-through.** The floors are cleared (their `fmask` bits go), leaving a tunnel through the building, and the fighter continues: `keep = clamp(0.8 - 0.45 * (s_k * HIT_FLOORS) / 3000, 0.35, 0.8)` (the chain rule of `buildings-in-depth.md` 4b, now with the strength of the floors crossed). The next building on the line is a chain link as before.
   - `0.4 <= ratio < 1`: **cracked floors**: `fdmg[k]` takes `dmg` and the floor stays, windows broken (a render hint), the fighter rebounds and the chain ends.
   - below 0.4: a dent (`fdmg` only), the fighter drops.
3. **Casualties are by floor, and the people on a floor evacuate or are lost (Orb).** Over the budget, a floor's occupants flee instead of dying: the `evacuate` event gains a `floor` field (the floor they left; -1 for a whole building) so Rendering runs them out of that floor's doors and windows. People are spread evenly over the floors (`pop / F` each). A punched floor's occupants die (through `WorldCollateral.kill`, so the budget and the token apply); a cracked floor's die in proportion to `fdmg / s_k`. The rest of the building is untouched. A chain through five towers is five tunnels and a few floors of people, not five collapsed towers.
4. **Local damage to the core.** `hp -= CORE_SHARE * dmg` (through `damageBuilding` with a floor-mode flag, so it does not itself trigger the implode unless `hp <= 0`).

### Pancaking, partial wrecks and the whole tower

- **A tunnel is not a collapse.** A cleared span of up to `TUNNEL_MAX` = 2 floors is carried by the columns; the floors above stay.
- **Pancake.** If the cleared span is longer than `TUNNEL_MAX` (a heavy punch, or two punches on adjacent floors), the stack of floors above it, `m` floors of mass, falls onto the floor below. It breaks that floor if `PANCAKE_K * m >= s_j` (`PANCAKE_K` = 0.6), the floor joins the stack (`m + 1`), and it goes on to the floor below, until a floor holds. The floors it broke are cleared, and their occupants die with them (through `kill`, same cap). A punch high in a tall tower with few floors above breaks a few floors and stops (a partial wreck: the top comes down onto the floors below and the building stands, shorter); a punch low, or one with a heavy stack above, cascades to the ground, which is a whole-tower collapse (`hp` is then set to 0: implode, mode `burst`).
- **Partial wrecks persist.** `fmask` and `fdmg` stay for the match. `curH` is the height of the top standing floor (`(highest set bit + 1) * h / F`; the old `hp` rule while the mask is full), so a pancaked tower is visibly shorter and a tunnelled one keeps its height with a hole. The rubble of the fallen floors is a heap at the foot, sized by the floors that fell (`RUBBLE_H_FRAC` of their height), as in 4c.
- **When the whole building goes.** Either the pancake reaches the ground, or `hp <= 0` from accumulated local damage (`CORE_SHARE`) or area damage.

### Interfaces for Rendering and VFX (ruling: Rendering draws, VFX throws)

- **The floor count is state, not a formula to copy.** `Building.floors` (an int, set at generation: `F = max(1, round(h / FLOOR_H))`, capped at 62) is on the building, and `FLOOR_H` (150 units, 2 bh) is a named constant in `structures.gd` (`WorldStructures.FLOOR_H`). A floor's height is `h / floors`; floor k spans `[g + k h/floors, g + (k + 1) h/floors]`. Neither Rendering nor VFX computes F from `h`.
- **`floor_hit.n` is the number of floors cleared** (0 for a crack or a dent), and **`floor` is the lowest floor of the hit** (a punch through floors 12 and 13 reports `floor` 12, `n` 2). For a crack or a dent, `floor` is the floor struck and `n` is 0.
- **Rendering** draws window states and the tunnel cut from `fmask` (a set bit is a standing floor; a cleared bit is a hole) and `fdmg` (per floor damage over the floor's strength, 0 to 1 and beyond) on the building mesh; it reads them from state, so a late join or a seek shows the same building. **VFX** throws only glass, shards and dust from the events (`floor_hit`, `floors_fall`, `building_hit`).
- `floors_fall {b, from, to, n, x, z, w}`: `from` is the lowest floor that fell and `to` the highest; `n = to - from + 1`.

### Windows and events

- **Windows are a render hint.** Rendering draws lit or dark windows by the floor's occupancy and broken ones by `fdmg[k] / s_k` (0 whole to 1 shattered) on the floor and its neighbours; the sim stores only `fmask` and `fdmg`.
- **New events.** `floor_hit {b, floor, n (floors), outcome (punch, crack, dent), ratio, x, y, z, ux, uy, kind, victim, owner}` for each brunt hit on a skyscraper, in addition to `building_hit`, which carries the whole-building summary (its `outcome` is then `punch` (a tunnel), `crack`, `dent`, `pancake` or `collapse`); `floors_fall {b, from, to, n, x, z, w}` when a stack pancakes, so Rendering drops the floors and VFX throws the shrapnel of what they crushed. `building_fall` fires only when the building itself goes.
- **Shrapnel data for VFX:** `kind` (tower: glass and steel), the floor count, the hit height, the unit impact velocity, and `n` floors.

### How the plan changes

- Section 3's outcome table (collapse, heavy wreck, partial wreck, crack by `dmg / maxhp`) applies to buildings under `FLOORS_MIN` floors. For skyscrapers it is replaced by the floor rule above; `ratio` in `building_hit` is the floor ratio.
- The chain's `keep` uses the strength of the floors crossed, so a skyscraper takes far more out of the fighter than a house, and a chain through skyscrapers is short by physics (2, 2, 3, 4 by tier still caps it).
- The planner (Encounter) scores a skyscraper candidate by `F`, occupancy and height as before; the aim search also picks the hit height: it tries `uy` values that put the arrival at a chosen floor, preferring occupied floors for the villain and empty ones for the hero (the floor's `pop / F` term).
- `WorldBrunt.hit` grows a `hitFloors` step and there is a `WorldBrunt.pancake(S, b, k)`; both are pure functions of `fmask`, `fdmg`, `maxhp` and `hp`.
- **Cost.** A brunt allocates one `fdmg` array (up to 62 floats) and loops over at most `F` floors once; the pancake loop is at most `F` iterations. Untouched buildings keep `fdmg = null`.
- **Tests.** A punch at a low floor of a tall tower cascades; a punch near the top stops after a few floors; two punches at the same floor deepen the tunnel and count toward the core; the sum of floor occupants equals `popAlive`; a blast still implodes the whole building; `fmask` and `fdmg` are in the hash and reproducible.
- **Open (Orb, Game Design):** how many floors a fighter's body clears (`HIT_FLOORS`), whether a pancake may drop a skyscraper's top onto the street beside it (a "topple" for tall stacks: `living-destruction.md` idea 4), and whether floors should show a lit or dark state that reads occupancy.

## 10. As built (B2 landed)

What the code does, where it differs from the plan above, and what the gates said.

- **Code.** `sim/world/brunt.gd` (`WorldBrunt`): floors (`floorCount`, `outcomeOf`, `applyFloors`, `pancake`), the pure geometry (`flightTo`, `next`, `chainPlan`, `candidates`, `aim`) and the runtime (`arm`, `stepZ`, `checkHit`, `hit`, `endFlight`). Wiring: `SimFighter.stepLaunched` (aimed collision, `z`, carry-on; the incidental building hit is gone), `DirLaunch.doLaunch` (`arm`), `DirLaunch.predictFlight` (no buildings; a slide's front-street stop is gone with them), `DirLaunch.chooseLaunch` (BUILDING SMASH candidates from `WorldBrunt.candidates` and `aim`, scored by `bruntScore`, pity counter `dirS.sinceBrunt`), and `melee.gd` (only the `#<building>` suffix in the launch_plan text). `WorldSlide.begin` and the water exit and impact paths close the chain (`endFlight`).
- **Plan equals outcome.** The probe aims 220 launches across 5 seeds and tiers and compares the planned chain with the chain that happens: identical in all, none over the tier cap, none off the plan. Getting there took three fixes that are now rules:
  1. *Splash spares what is ahead.* A hit's splash (25% of its damage on the neighbours, once per launch) skips every building beyond the hit's far edge while the flight goes on, so a link never levels the next link. When the chain ends at that hit, the ones ahead are splashed like the others.
  2. *The next link gets its tick.* After a hit that carries on, the tick does not run the ground test, so a chain that leaves a building low is not turned into a slide before its next hit (chainPlan tests the crossing before the ground, in the same order).
  3. *No water in a brunt.* `flightTo` refuses any flight that starts or passes under the water surface (`WorldWater.surfaceAt`), since the runtime's skim and buoyancy differ from a fixed model. A fighter leaving the far face starts exactly at that face (`f.x = far`), where chainPlan starts the next flight.
- **Hash.** Fighter: `aimB`, `aimX0`, `aimZ0`, `aimZ1`, `aimD`, `chainEvt`, `z`, and the `splashed` list (Simulation's review). Building: `floors`, `fmask`, and `fdmg` (its length, then the values). `dirS`: `sinceBrunt`, `lastBrunt`. Events: `launch_depth`, `chain_link`, `floor_hit`, `floors_fall`, extended `building_hit` and `evacuate` (docs/architecture/fx-events.md). M1's `building_hit` inputs (`actor`, `x`, `n`) are unchanged and the mood vector passes.
- **Planner numbers (launch.gd).** `BRUNT_BASE` 14, `BRUNT_POP_REF` 8, `BRUNT_TALL_W` 12, `BRUNT_FRESH` 4, `BRUNT_ROW_W` 2, `BRUNT_CHAIN_DRAMA` 5, `BRUNT_DRAMA_CAP` 14, `BRUNT_REPEAT` 12, `BRUNT_RAMP` 5, `BRUNT_OVER_BUDGET` 40. `BR_MIN` 90 and `BR_MAX` 1300 (feature scale units) bound the candidates; two per side are aimed.
- **Measured** (default arm, seeds 1 to 100): BUILDING SMASH is 5% of launches by the feed (359 brunts), picked 45% of the time a building is in reach (18% before). Chains: 1 building 116, 2 buildings 190, 3 buildings 33, 4 buildings 20. Outcomes: punch 265, collapse 116, crack 107, dent 3. Pancakes are rare (4 in 100 matches): one brunt clears at most `HIT_FLOORS` (2) floors, so it takes a second brunt on the same tower. Collateral 30.6% of civilians (28.3% with the planner's brunt candidates switched off in a scratch run), 111 of 196 structures (99.5 without), length 410 s (420 without), KAI 48 wins. Only about 9% of launches have a building in reach, so the brunt share is bounded by where fights happen (Encounter's location variety), not by the scoring.
- **Cost.** `aim` runs at most 4 flight searches per candidate and 4 candidates per launch decision, only at a launch, and draws nothing from `S.rng`.
- **Changed while landing.** `parity.gd`'s wired-number rows for VORR's menace `effects[2].perPoint` and `sources[1].amount` moved from seed 16 to seed 12: the opening of seed 16 no longer reaches VORR's evacuees (Simulation and the EP agreed).
