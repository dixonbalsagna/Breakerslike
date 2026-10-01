# VFX effect budgets

Owner: VFX Director. 2026-09-29. **To align with Performance** (their particle row and worst-case scene are not written yet). Every number lives in `render/vfx/vfx_look.gd`. Measurements are from `render/vfx/tools/worst_case.gd` on a fast desktop (Ryzen 7 9800X3D, RTX 5070 Ti, Compatibility renderer, 1280x720); the old-laptop column is an estimate, not a measurement.

## Pools

| Effect | Cap | Draw calls per pane | Overdraw | Peak seen in the worst case | Degrade order (first to go) |
| :--- | ---: | ---: | :--- | ---: | :---: |
| Trail ribbons | 2 fighters x 2 layers x 4 segments = 16 quads | 1, shared with the marks | thin blades | 16 | 3 (outer band, at quality low) |
| Wind marks | 10 per fighter, 2 quads each | (in the trail's call) | thin dashes | 10 | 1 (marks, at quality low or reduced motion) |
| Crack sets | 90 kept, 24 drawn per pane | up to 24 (one per set, culled) | thin strips on the ground | 14 sets, 3,718 triangles | 4 (hairlines halve at low; oldest sets dropped) |
| Shards (glass, steel, chunks) | 220 | 1, shared with the dust and rings | small quads | (in the 460 below) | 2 (glass first, kept at 35% in low) |
| Dust puffs and rings | 240 | (in the shards' call) | large soft-edged quads | 460 of 460 shards and dust together | 2 (puffs past 260 spawns a tick are dropped) |
| Hole decals | 24, at most 3 per building | 1 | one quad each | 0 (a collapse leaves none) | 5 (oldest) |
| Water spray streaks | 260 alive (thinned by quality), at most 60 thrown a tick, inside the 460 below | (in the shards' call) | thin stretched droplets | 260 in the sea worst case | 2 (the cap scales with quality) |

The debris pool is 460 in all; when it is full a shard evicts the oldest puff first, and a puff at the cap drops. Nothing gameplay-critical is dropped: the hit's own ring and the first shards of a burst spawn before the dust.

## Cost

| Scene | Frame CPU (render_view) | GPU | Draw calls |
| :--- | :--- | :--- | :--- |
| Worst case, VFX off | mean 0.226, p99 0.342, max 0.406 ms | 0.112 ms | 24 (max 26) |
| Worst case, VFX on | mean 0.369, p99 0.906, max 0.932 ms | 0.113 ms | 25 (max 31) |
| Real match (seed 4, split on), trails only | mean 1.702 against 1.688 ms | n/a | 189.8 against 189.6 |

Inside the worst case: the hub's `consume` averages 0.22 ms (peak 2.9 ms on the tick that spawns a four-tower chain and an eight-tower implode together), the layer's `update` 0.17 ms (peak 1.8 ms, the first mesh build). A crack set's mesh takes about 0.6 ms to build, one a frame.

Old-laptop estimate: the CPU work is GDScript loops over at most 460 debris bits, 20 marks and a few sets, and one float buffer per MultiMesh; the GPU work is under 0.01 ms here and dominated by fill on a low-end part. If a machine is five times slower than this one, the mean is about 1.8 ms and the busiest tick about 15 ms, so the spawn budget and the automatic quality step (below 42 fps for 2 s drops a level; back up at 57 fps for 8 s) are the levers, in that order. Quality low: no marks, no outer band, half the hairline cracks, one fissure, 35% of the shards.

## Worst-case scene, for Performance's list

Tier 4, full collateral, a beam clash in the city, zoomed out, particles at their cap, plus these on top: two fighters at full trail speed, a chain through four towers with its tunnel and shrapnel, a block of eight towers imploding, and a crack set from every impact and slide in the frame. `worst_case.gd` is that list minus the beam clash and the tier-4 scale (Rendering owns the beams and the zoom).

## Water (2026-10-01)

Spray streaks: 260 alive at quality high, thinned with quality (about 175 at low), at most 60 water bits thrown a tick, all inside the 460 debris pool, so water adds no draw call (it is drawn in the shard pass). Degrade order 2, with the shards.

Sea worst case, `worst_case.gd --sea`: a fighter raking the ocean at 9000 u/s with a skip every 20 ticks, a plunge a second, a power-4 beam sweeping 14 samples a tick and the wake, so every water effect fires every tick. 1280x720, same machine, Compatibility renderer.

| Quality | Frame CPU, VFX on | VFX off | Draw calls (on / off) | Consume mean (max) | Peak bits | Peak spray |
| :--- | :--- | :--- | :--- | :--- | ---: | ---: |
| High (2) | mean 0.853, p99 1.298 ms | mean 0.370, p99 0.542 ms | 25 / 23 | 0.80 (1.93) ms | 458 of 460 | 260 |
| Low (0) | mean 0.800, p99 1.220 ms | mean 0.365, p99 0.523 ms | 25 / 23 | 0.68 (1.20) ms | 428 of 460 | 260 (run before the quality-scaled cap; now about 175) |

About 0.5 ms a frame over the same scene without VFX, almost all of it the GDScript spawn and step loops. On a machine five times slower that is the lever to watch: the per-tick cap, the spray cap and the automatic quality step. Not measured: the web build and an old laptop (Tools bench with and without `--novfx`).
