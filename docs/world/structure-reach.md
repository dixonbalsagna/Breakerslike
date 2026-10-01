# High-tier structure reach (balance-targets section 21): plan

Owner: World and Environment. Status: plan, docs only (2026-10-02), with a read-only measurement in a scratch copy of HEAD (e1df0aa). Nothing here is in the sim. Game Design's ruling: the area in which impacts, power-ups, clashes and blasts damage **structures** grows by tier: x1.0 at tiers 1 and 2, x1.6 at tier 3, x2.4 at tier 4, as data. Casualties are unchanged. Reason: structures levelled per minute were 1.2 to 3.0% at tier 3 and 3.4% at tier 4 against bands of 3 to 10% and 6 to 20%.

## 1. Where the factor applies

`WorldStructures.damageArea(S, x, y, r, dmg, cause, beam, evt, capLeft, keep)` (structures.gd:211) is the one place every structure hit goes through, so the lever is one change there:

- **A new last parameter `reachMul`** (default -1: take the cause's factor). Inside, `r` becomes `r x tf`, where `tf = cause.ld.structureReach[tier - 1]` (tier clamped to 1 to 4, a cause with no `tier` or `ld` gets 1.0). The scaled `r` is used everywhere `r` is used today: the bucket query (`near`), the reach test, the height test (`y - 0.6 r > top`), the **falloff** (`1 - 0.7 d / r`), and the tree burn radius. Scaling the falloff too is what makes the lever bite (section 3).
- **Callers that get it, with no edit:** the ground power-up (fighter.gd:21, cause = the fighter), the landing impact (fighter.gd:57, cause = the launcher), the slide's path samples (slide.gd:151), the heavy-clash shockwave (melee.gd:100), and `explode` (beam clash blasts and strike blasts, structures.gd:251), which calls `damageArea`.
- **Beam path samples must not get it:** beam.gd:248 (the per-sample damage along the ray) passes `1.0` explicitly (a one-token edit in Encounter's file, a grant). The beam has its own tier gate (`sf`) and per-beam cap from 2a; scaling its reach would double-count.
- **The beam cap from 2a still holds, structurally.** The cap works on the `levelled` count inside `damageArea` and in the beam's `bm.levelled` (`capLeft = cap - levelled`), after the reach test: a wider reach finds more buildings, and the cap stops the levelling at `capLeft`, the rest taking `keep` damage. So a tier-4 clash blast through `explode` is still limited by the beam's cap. A probe checks it.
- **Depth:** x reach only. `Z_REACH` stays as it is, so rows 0 to 2 are reachable and the background scenery row stays out (the front-row band is what is gated). With lanes (L3, blasts by plan distance) the plan radius takes the factor, and I would keep the same rule (the band's rows only).
- **Casualties:** unchanged. `damageBuilding` kills occupants through `WorldCollateral.kill`, which the window and the ramp cap; a wider reach levels more buildings but the people lost stay under the same budget (and by tier 3 most of a threatened district has already fled).

## 2. Data and schema

- **Where:** each fighter's `ladder.json` (the pattern 2a used for `beamStructure` and `beamLevelCapShare`): `structureReach: [1.0, 1.0, 1.6, 2.4]`, four numbers, each at least 1.0 and at most 6.0. A tier's factor can only grow the area. A global default would also work, but a per-fighter row lets the villain reach further than the hero if Game Design ever wants it (no personality difference today).
- **Code:** `fighter_data.gd` (Simulation's) parses it into `ld.structureReach` (a grant); Tools' ladder schema adds the field (required, array of 4, 1 to 6); `parity.gd`'s wired-number check needs two rows (tier 3 and tier 4 entries) on seeds that reach a blast near buildings, and the usual seed search.
- **Neutral for tiers 1 and 2:** `tf = 1.0` multiplies `r` by exactly 1.0, so the low tiers are bit for bit unchanged (a probe check).

## 3. What the factor does, measured

Scratch copy of HEAD, 40 default-arm matches (seeds 1 to 40), structures levelled per minute of play at the higher fighter's tier (all rows, then the front row), and the totals at the KO. Bands: tier 3 3 to 10%, tier 4 6 to 20% (front row); KO front row 25 to 50%, all rows 15 to 40%.

| Setting | Tier 3 per min | Tier 4 per min | KO all rows | KO front row |
| :--- | ---: | ---: | ---: | ---: |
| None (HEAD) | 2.25 / 2.89 | 4.03 / 5.23 | 26.6 | 34.6 |
| x1.6 / x2.4, falloff at the old radius | 2.35 / 3.08 | 4.23 / 5.44 | 29.6 | 38.3 |
| **x1.6 / x2.4, falloff scaled (the proposal)** | **2.90 / 3.90** | **4.59 / 5.83** | **30.4** | **39.4** |
| x1.6 / x3.0, falloff scaled | 2.90 / 3.90 | 5.77 / 7.26 | 37.4 | 47.7 |
| x3 / x5, falloff at the old radius | 3.64 / 4.97 | 5.41 / 6.85 | 37.0 | 47.8 |
| x4 / x8, falloff at the old radius | 5.08 / 6.96 | 7.72 / 9.58 | 52.0 | 66.0 |

(Each cell is all rows / front row.)

- **The factor alone, with the falloff left at the old radius, barely moves the rates** (a house in the new outer ring takes only the edge damage, 0.3 of the base). It is the **scaled falloff** (the whole blast scaled) that brings tier 3 into its band.
- **Tier 4 stays a little under 6%** at x2.4 (5.83). A tier-4 factor of about 2.8 to 3.0 reaches the band (x3.0: 7.26) with the KO front row at 47.7, near the top of its 25 to 50 band. My recommendation: **start at x1.6 and x2.8** as the data, and let QA tune the tier-4 number.
- Tiers 1 and 2 are unchanged (0.32 and 0.96 per minute, all rows).

## 4. The risk in dense cities

- **Tier 4 past 20% a minute is already common without this change:** in 12 of 40 matches some 60 second window at tier 4 levels more than 20% of the front row (worst 52.5%), almost all of it beam sweeps through a town. With x2.4 it is 15 of 40 (worst 62.5%) and with x3.0 18 of 40 (worst 65%): the reach adds a few more.
- **Why dense downtown is safer than it sounds:** towers have thousands of hit points (a mid-rise 1,400, a downtown tower far more), so a tier-4 blast of 430 damage levels houses, shops and low-rise (suburbs, villages, harbour) but wounds towers; repeated blasts accumulate on them, which is the drama, and the 2a beam cap bounds the beam's share. D1's districts make the low-rise bands bigger (suburbs, the village cores), which raises the reach's effect there.
- **A safety valve, as data, if QA sees 20% minutes grow:** `reachRingCap`, a per-event cap on the buildings levelled in the **extended ring only** (those beyond the old reach), using the existing `capLeft` and `keep` mechanism. Default off (a large number); a tier-4 value of about 4 buildings per blast keeps one impact from emptying a street.
- The hero's lure still keeps fights off towns; at tier 4 the lure no longer saves a town's edge by itself, which section 21 states is the pressure the pillar asks for.

## 5. How it sits with G1 (rims, heaps and the ground model slices)

- **Files:** the reach edit is in `damageArea` (structures.gd, mine); G1's edits are in `crater.gd` and `_heap` (also structures.gd). They do not overlap and can be written in one window.
- **Goldens:** both change behaviour, so I recommend **one slice, one regeneration** ("G1 and reach"). Landing the reach first would need its own regeneration and a second QA pass on the same bands.
- **Interaction:** more buildings levelled at tiers 3 and 4 means more rubble heaps near the plane. G1 makes heaps gentler (slope 0.6, spill 1.2) and the footing rules already hold, so the terrain audit is re-run at tier 4 as part of the slice (steps, shafts, tilted footings) with the new reach; the heap rule (only rows 0 and 1 leave a sim heap) is unchanged.
- **Order with the lanes work:** independent of L0 to L3; the plan-distance blasts of L3 reuse the factor.

## 6. Probe checks and acceptance

- A tier-3 cause reaches a building at 1.6 times the old distance and not at 1.7; a tier-4 cause at 2.4 (or the data's value); tier 1 and 2 results are bit for bit today's.
- The falloff is scaled (the damage at a given fraction of the reach is the same at every tier).
- Beam path samples are unaffected (reach 1.0): a beam's levelled count and the 2a cap are identical with the change on or off.
- A tier-4 clash blast through `explode` obeys `capLeft` (levelled at most the cap).
- Casualties stay under the window: over 20 seeded tier-4 blasts in a town, the people lost never exceed `WorldCollateral.room` plus the ramp.
- `Z_REACH` still excludes the scenery row.
- The 100-match default-arm probe: the tier 3 and tier 4 rates and the KO totals against their bands, the worst 60 second window, collateral, length and KAI; the terrain audit at tier 4.
- Grants for the slice: `fighter_data.gd` (the field), `beam.gd:248` (the `1.0`), and the ladder data and schema (Game Design and Tools).

## 7. As built: "G1 and reach" (2026-10-02, on HEAD 7951f33)

Applied as one slice with one golden regeneration. `damageArea` takes `reachMul` (default: the cause's `ld.reachStructure[tier - 1]`, scaled whole, falloff included, with `reachRingCap` -1 off); the beam's path samples pass 1.0; data `reach.structure` [1, 1, 1.6, 2.8] and `reach.ringCap` -1 in each fighter's `ladder.json`, the schema field in `tools/schemas/fighter-ladder.schema.json`, and `fighter_data.gd`'s parse. **Re-measured on the new HEAD (100 matches, seeds 1 to 40 for the rates):** the retuned HEAD with Encounter's contact slice already has tier 4 at 7.2 / 9.2% a minute (all rows / front row) and tier 3 at 3.3 / 4.3, both inside their bands; with the reach they are 6.9 / 8.9 and 3.4 / 4.6, so the lever no longer moves them measurably (the earlier gap closed with Encounter's slices: crater slams and the landing mix). The data stays as ruled; setting `reach.structure` to [1, 1, 1, 1] is a data-only way to turn it off if QA prefers, and the ring cap is the valve if the dense-city 60 second windows (11 of 40 matches over 20% before, 13 after) need bounding.
