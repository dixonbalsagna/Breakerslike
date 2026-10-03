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

## Transformation (2026-10-01)

One MultiMesh draw per pane, at most 140 quads (51 for one fighter in the gather's middle, about 100 for both), no pool and no per-frame allocation beyond the buffer. The view's update takes about 80 microseconds a frame for one fighter in its busiest beat (fast desktop, `transform_shots.gd`), the hub's clock under 2. Counts scale with quality (0.7 medium, 0.35 low with no dust, halved in reduced motion, which also drops the flash). Degrade order 3 (before the trail's outer band). Not measured: the web build and an old laptop.

## Standing aura (2026-10-01)

One quad a fighter, in the transformation's one draw call (it adds none), no pool. The fill is dropped at quality low. Cost is under the transformation's 80 microseconds a frame and not separately measured.

## Reactions to power and speed lines (2026-10-01)

Rubble alive 36 at quality high (inside the pool's 460, thinned with quality), windows at most 10 buildings and 6 floors a wave, one standing crack set a fighter (two more crack materials), speed lines at most 4 streaks of 7 lines (the transformation's draw call, now up to 220 quads). Everything at once (`react_shots.gd --case=bench`, both fighters tier 4 and worn in the city, a big crater a second, a heavy every 8 ticks, 1280x720, fast desktop): frame CPU mean 1.02 ms against 0.40 with the reactions off (p99 1.59 against 0.61), draw calls 27.7 against 24.6, peak bits 426 of 460, consume 0.41 ms mean (1.23 max). Not measured: the web build and an old laptop. Degrade order: speed lines and the flicker's size stutter first (they are cheap), then the rubble count, then the glass, then the standing cracks.

## Earth, material and fire (2026-10-01)

Chunks, flames, dust puffs and smoke all live in the debris pool (460), so no draw call is added. Flames alive: 40 at quality high (27 at low), at most 8 an event; chunks at most 14 an event for `debris`, 30 for a crater. `earth_shots.gd --case=bench` (a fire burst every tick, 14 chunks every 8 ticks, a slam every 30, a bounce every 17, a sliding body, 1280x720, fast desktop): frame CPU mean 1.39 ms against 1.11 ms with these off, where "off" still draws the reference consumer's squares and discs (a second run 1.59 against 1.45), draw calls 22 and 22, peak bits 449 of 460, consume 0.8 ms mean (1.7 max). Not measured: the web build and an old laptop. Degrade order: smoke, then the flames' sway (reduced motion), then chunk counts, then dust.

## Levitating rocks prototype (2026-10-02, behind `rocks_enabled`, default off)

One MultiMesh draw (shard shader), at most 12 quads a fighter (24 in all), no debris pool use. Headless CPU for the layer with 17 pieces on screen: 81 microseconds a frame. Counts scale with quality (0.7, 0.35) and halve in reduced motion, which also stops the bobbing. Degrade order: after the speed lines, before the rubble count. Not measured: the web build and an old laptop.

## Blast amplification and pressure rings (2026-10-02)

Blast: spawns into the debris pool only (no draw call), at most 18 chunks, 20 dust puffs, 20 pebbles, 12 settling puffs and 2 rings a crater, at most one a fighter every 0.25 s, so a busy crater is the pool's per-tick budget at worst; thinned with quality (0.7, 0.35, halved in reduced motion, which also drops the rings). Degrade order: pebbles and settling dust first, then the dome, then the chunks. Pressure rings: 8 alive at most, one SHAPE_RING quad each in the transformation's existing draw call once drawn (CAP 220), no pool. Hash check, 8 AI matches: 72 craters amplified, 495 rings (about 27 a minute for both fighters together). Cost not separately measured; not measured: the web build and an old laptop.

## Energy blasts (2026-10-03)

One MultiMesh, one draw call (the transformation's shader), 224 quads reserved: at most 32 shots (4 quads a bolt, 5 a charged shot), 14 for the hit and trade effects, 16 for the two charges. A miss on the ground spawns into the debris pool (about 8 bits). Counts: none scale with quality except the miss's dust. Not measured: the web build and an old laptop.

## Blast explosions and mines (2026-10-03)

Debris pool only (no draw call): a bolt's explosion about 9 bits, a full charged shot's about 32 plus 8 smouldering jobs; flames capped at 40 alive, sparks at 12 a tick and 100 alive, the pool at 460 (a test fires twenty full bursts in one tick: 292 bits). Quality low about 0.35 of the count, reduced motion half and no ring. Knocked-loose shots: up to six, a smoke puff each tick (every other at low). Mines: 7 to 13 quads each, at most 24 held, in the shots view's one draw (320 quads reserved). Not measured: the web build and an old laptop.

## Round two of the blasts (2026-10-03)

Twelve mines (the most there can be) and twenty bolts in one view: 123 quads of 320, one draw call. A mine is 7 to 13 quads. A building hit or an air burst costs a bolt's explosion (about 9 bits) or a charged shot's (about 24 to 32) from the debris pool; a spray's misses are bounded by the pool's caps (flames 40, sparks 12 a tick). Not measured: the web build and an old laptop.
