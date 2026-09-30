# VFX plan for floors (Rampage-style skyscrapers)

Owner: VFX Director. 2026-09-30. Written against `docs/world/b2-plan.md` §9; nothing is built until B2 lands. Extends `docs/vfx/plan.md` and reuses `debris.gd`, `hole_view.gd` and the hub's handlers.

## What VFX needs from the events

| Event (B2 §9) | Fields I read | What VFX draws |
| :--- | :--- | :--- |
| `floor_hit` outcome **punch** | `b, floor, n, x, y, z, ux, uy, kind, victim` | Today's burst-through, but confined to the floors hit: glass thrown back at the entry and a forward cone at the exit spawned across floor k to k + n (not the whole tower), a window blow-out along the facade at those floors (glass slivers falling from the window row, one every window width, at most 40), a ring at each end, and a persistent tunnel decal: a ragged dark band two floors tall across the building's width |
| `floor_hit` **crack** | same | A window shower: glass falling from the hit floor and its neighbours, a dust puff, no tunnel; the broken windows themselves are Rendering's (from `fdmg`) |
| `floor_hit` **dent** | same | One dust puff and a few chips |
| `floors_fall` | `b, from, to, n, x, z, w` | The pancake: dust bursts at each broken floor's height, staggered top to bottom over about 0.4 s, a heavy dust column between `from` and `to`, glass and steel shrapnel of what was crushed (6 glass and 2 steel per floor, capped), and a ground ring; sized by the span, not the whole building. Rendering drops the floors |
| `building_hit` outcomes punch, crack, dent, pancake | `outcome, kind, spd, ux, uy` | The whole-building summary. The per-floor events carry the detail, so VFX draws from `floor_hit` and `floors_fall` and ignores a `building_hit` whose `floor_hit` came in the same tick; a house (under 5 floors) has no `floor_hit` and keeps today's burst |
| `building_fall` | as B1 | Unchanged: the whole tower implodes. Floor tunnels and holes of that building are removed |

## Data I ask for

- The floor count `F` of a building, or the constant `FLOOR_H` (150 units), so I can turn `floor` into a height band `[g + k h / F, g + (k + 1) h / F]` without copying the formula. The state is enough after a seek: `S.buildings[b].fmask` and `fdmg`.
- `floor_hit.n` is the number of floors cleared (2 for a body), not `F`; `floor` is the lowest.

## State and rebuilding

Tunnel decals are a function of state, like cracks: a run of cleared bits in `fmask` is a tunnel at that height. The hub will read the buildings' masks (only those that changed, tracked by mask value), so a seek or late join draws the same tunnels; `floor_hit` only adds the burst. The decal cap (24, three per building) becomes two per punched span, oldest dropped.

## Budgets (draft, to align with Performance)

- A punch: at most 60 shards, 40 window glass, 20 dust, 2 rings (the burst-through budget of `effect-budgets.md` plus the window row).
- A pancake of n floors: at most 8n shards, 4n dust, capped at 250 bits, staggered over 0.4 s so no tick passes the 260 spawn budget.
- A chain of five towers is five punches, spread over the flight; the debris pool (460) and the per-tick budget still bound it.
- Window glass counts against the shard cap and drops first under load.

## Build order when B2 lands

1. Mock builders `floor_hit` and `floors_fall` in `mock/vfx_mock.gd` and a `skyscraper` scenario in `mock_shots.gd`, against a real tower of 5 or more floors.
2. `_on_floor_hit` and `_on_floors_fall` in the hub; `debris.floor_burst`, `window_row` and `pancake` spawners.
3. Tunnel decals from `fmask`, in `hole_view.gd` (a wider band shape in `hole.gdshader`).
4. `hash_check.gd` against the real events (B2's own emit them), then `worst_case.gd` with a five-tower punch chain.

Open with World and Rendering: whether Rendering draws the lit or dark windows and the broken state from `fdmg` (so VFX only throws glass), and whether a floor's tunnel is cut into Rendering's building mesh or left to my decal.
