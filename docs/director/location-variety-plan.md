# Plan: location variety (G0 triage §14, group C)

Owner: Encounter Systems Director. Status: plan only, no edits. It lands as a small slice right after World's B2, before Q4.

**The problem** (`balance-targets.md` §14 C, from QA's G0 baseline):
- The biome floors fail: ocean 0.5%, plains 0.4%, city 2.1%, against half the planet share or 3%.
- So do the beam variants that follow: HORIZON CLEAVE and MERIDIAN SCAR at 0.5% each, against at least 3%.

The cause is the open-ground spawn (desert edge) plus a hero lure that only acts near population and never targets the sea. The fight starts on empty land and stays in desert, forest and mountains.

## Changes (all owned paths unless marked)

1. **The biome record.** Per tick, the director adds DT to the biome under the fight: the midpoint of the two fighters, on the shortest arc. It counts only between exchanges and while neither fighter is launched, so launches don't dilute it. Stored per match in hashed state (NEEDS 1).
2. **The roam target, for both roles.** `heroLure` becomes `DirLocation.roam(S, f)`. It returns ±1, or 0 when no move is wanted, and has two triggers:
   - **Hero:** it leads away from population, as today. New: it also leads when the current biome's time share exceeds its planet share by `excessStart`.
   - **Villain:** at tier 3 or above, it prowls toward the nearest settlement when the fight has been away from towns for `prowlAfter` seconds. That is the villain pull from the earlier civilians lever, and it also lifts the city floor.
3. **Destination scoring.** For each biome segment in each direction, cost = distance + `popW × care × population crossed` + `varietyW × max(0, share − planetShare)` of the destination biome. The hero's care makes population a cost; the villain's negative care makes it a draw. Ocean and plains are back in the rotation:
   - **The ocean** is a surface destination. The existing `SURFACE_Y` rule keeps fighters at the surface, so underwater time stays under §10's 10% cap.
   - **Plains** count as empty land wherever the population window allows.
   - Settlements are destinations only for the villain's prowl.
4. **Data:** `data/director/location.json`, which I own:

   | Key | What it sets |
   | :--- | :--- |
   | `excessStart` | the hero's variety trigger |
   | `varietyW` | the weight on a destination biome's excess share |
   | `popW` | the population weight (today's `LURE_POP_W`) |
   | `keepW` | the discount for the way a fighter already moves (today's `LURE_KEEP`) |
   | `oceanSurface` | lets the sea be a destination |
   | `prowlTier` | the villain's prowl starts at this tier (3) |
   | `prowlAfter` | seconds away from towns before the villain prowls |
   | `destinations` | the biomes that can be destinations, per role |

   The planet shares come from `WorldBiomes.SEG` at load; they are not data. `DirData.dataHash()` covers the new file, for the replay header.
5. **No random draws.** The choice is deterministic from state, so the RNG sequence is unchanged apart from the moves it causes. The goldens regenerate.

## Measure (QA's rows, default and swap arms, 200 matches)
- Every biome at least half its planet share or 3%: ocean, plains and city.
- HORIZON CLEAVE and MERIDIAN SCAR at least 3% each.
- Underwater at most 10%; civilians lost 25 to 50%.
- Unchanged: KAI, match length, the brink bands, and the feel rows (standoffs, release to request).

## Also planned

- **The SMASH ACROSS cap** (§14 B), after B2. If SMASH ACROSS is still over 40% (bound 42%), `REPEAT_1` and `REPEAT_2` in `launch.gd` move to `data/director/launch.json`, and the penalty on the most-used type goes up there. `launch.gd` is mine again after B2.
- **The 120 s signature cooldown** (questionnaire 5): it goes into Q4 checkpoint A, the attack clock. `sigCooldown` 120 s is per-fighter data, and the clock won't fire or queue a signature until it has passed. It needs a per-fighter `sigReadyT` in hashed state (NEEDS 3).

## Grants (EP, approved and committed)
- **This slice**, after B2 and Simulation's M1b: `S.dirS.biomeT` in `state.gd` (a `PackedFloat64Array`, reset at `newMatch`) and its `hash.gd` line. Simulation reviews.
- **Tools** writes `director-location.schema.json`.
- **Q4:** `Fighter.sigReadyT` and its hash line, granted in that window. `sigCooldown` lives in `fighter.json` (per fighter), and Game Design has been told.
- **No edits until the EP opens the window.**
- **Tools' schema is committed** (`director.location/1`). It matches this plan key for key: `excessStart`, `varietyW`, `popW`, `keepW`, `oceanSurface`, `prowlTier`, `prowlAfter`, and `destinations` per role (hero, villain) from the 7 sim biomes. There are no differences to route. Future roster fighters map onto the two roles by `role` until Game Design adds more.
