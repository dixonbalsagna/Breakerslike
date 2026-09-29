# The fx event stream: the sim's cosmetic output

Owner: Simulation and Engine. Status: implemented in both cores (`sim/core/fx.js`, `sim/core/fx.gd`) and bit-identical between them. It's the input for Rendering, VFX, Camera and Audio. It resolves QA-002.

Since the QA-002 split, the sim holds no cosmetic state and makes no cosmetic random draws. Every visual effect the prototype spawned inside the sim now leaves it as an event: particles, damage numbers, the banner and camera shake. The render side turns events into visuals with its own random streams, so no VFX change can ever alter a match. `sim/core/view/fx.js` and its GDScript twin `view/fx.gd` are the reference consumer. They reproduce the prototype's particles, and the golden checks cover them too.

## Delivery and timing

- `step(S, inputs)` appends the tick's events to `S.out.fx`, an array (GDScript: `SimState.FxEvent` objects). The host drains it after every call: consume the events in order, then clear the array. This applies to hit-stop ticks too.
- Events are in emission order, which is the order the prototype made its effect calls. Each tick's list holds exactly one `tick` event, placed where the prototype stepped its particles, after the fighters, the director and the beams. The only events that can follow it are the beam-clash sparks.
- A hit-stop tick (the sim is frozen; `step` returns false) emits just `{type: 'tick', frozen: true}`.
- Coordinates are world units, taken when the event was emitted: x in [0, 9600) on the wrapped planet, y upward with sea level at 0. Durations are in seconds.
- Measured over 20 AI matches (85,863 ticks): about 1.35 events per tick on average, 7 at p99 and 46 at most, in a beam-and-explosion tick.

## Event types

Fields are listed in their canonical order, the order the golden hash reads them.

| type | fields | when | what the reference consumer does |
| :--- | :--- | :--- | :--- |
| `spark` | x, y, n, col, spd | hits, explosions, power-ups, beam clashes, glass-trench beams | n spark streaks: direction and speed random (spd sets the scale), life 0.15 to 0.4 s |
| `ring` | x, y, gr, col, life, r0 | shockwaves: impacts, launches, dodges, parries, charges | an expanding ring, radius r0 growing at gr units/s over life |
| `debris` | x, y, n, col, spd | building damage, craters, impacts | n chunks under gravity 900 that bounce off the ground (the consumer reads terrain height) |
| `dust` | x, y, n, col | collapses, impacts, beam scars, power-ups | n dust puffs with drag, life 0.8 to 1.8 s |
| `splash` | x, y, n | fighters hitting water, impacts at sea | n droplets under gravity 1200 |
| `fire` | x, y, n | explosions, burning trees, firestorm beams | n flames, orange or yellow |
| `after` | x, y, life, col, face | dodges and escapes (life 0.45), every tick of a rush (0.16) | a fading silhouette of the fighter facing `face` (+1 right, -1 left) |
| `charge` | x, y, col, ground | every tick a fighter is charging | the consumer rolls 40% for an aura spark and 6% for a dust puff, the latter only within 30 units of `ground` |
| `crater` | x, y, r, depth, energy, cause, rim, skid, owner | a crater was dug (GDScript sim only): ground impacts, ground-level power-ups, beam ground strikes, clash blasts | nothing yet: the reference consumer ignores it. Rendering builds a bowl from it; VFX adds the burst |
| `scorch` | x, y, w, power, variant, owner | every beam sample within reach of the ground (GDScript sim only) | nothing yet (ignored). Rendering and VFX draw the burn trail and the beam's ground contact |
| `beamSplash` | x | a beam sample below y = 30 over the sea | the consumer rolls 60% for a splash of 3 at (x, 0) |
| `damage` | x, y, amount, col | every hit | a damage number: text `String(Math.round(amount))` rising 60 units/s for 0.9 s; gold when stance was ignored, white otherwise |
| `banner` | text, col, dur | power-ups, parries, KO, chains, clashes, ambushes; for human players also NEED 45 KI and LOCK LOST | the centre-screen banner (the latest one replaces any earlier one) for dur seconds of unfrozen time |
| `shake` | k | anything heavy | camera shake: `shake = max(shake, k)` |
| `tick` | dt, frozen | once per tick | steps the particles and damage numbers by dt (dt × 0.1 when frozen) |

### The `crater` and `scorch` events

Owner: World and Environment (`sim/world/crater.gd`; numbers and reasoning in `docs/world/craters-scorch-water.md`). Both carry gameplay facts, not just looks, and both are backed by persistent state ("What the renderer reads from the sim directly", below), so a renderer that joins late or seeks in a replay rebuilds everything from state and never depends on having seen the event.

`crater`: `x` is the centre (world x), `y` the ground height there before the dig, `r` the bowl radius (the rim crest is at `r`), `depth` the bowl depth actually applied (already limited by the local relief cap, so it can be less than a fresh hit would give), `rim` the rim height above the surrounding ground, `energy` the impact-energy scalar the size came from, `cause` one of `"impact"` (a launched fighter hits the ground, or a heavy-clash wave), `"beam"` (a beam's ground strike or a clash blast) or `"powerup"`, `skid` a signed offset from `x` to the tail of a furrow that runs into the bowl (0 for none), and `owner` the slot of the fighter that caused it (-1 for none). The z = 0 slice of the bowl is exactly `WorldCrater.profile(|dx| / r, depth, rim)` added to the ground, plus the furrow. Rendering draws the bowl in depth, round, with that slice as its profile.

`scorch`: one per beam sample that is within reach of the ground. `x` is the sample's world x, `y` the ground height before the groove was carved, `w` the groove's full width, `power` the beam-power scalar P (0.5 to 4.5: tier and charge, `WorldCrater.beamPower`), `variant` the beam's biome variant (`HORIZON CLEAVE`, `BOULEVARD RAZE`, `FIRESTORM`, `RIDGE BORE`, `GLASS TRENCH`, `MERIDIAN SCAR`) and `owner` the firing fighter's slot. Samples are at most 36 units apart along the beam, so a trail is a chain of these; the burn mark itself is `S.scorch` (permanent, per column).

Colours are CSS hex strings, as in the prototype. Replacing them with a palette is for Art and VFX.

## Consumer rules (the reference consumer)

Run once per tick, after `step`:
1. Consume events in order. Effect events spawn particles; `damage`, `banner` and `shake` update the presentation; `tick` steps existing particles and damage numbers.
2. At the end of the tick: if it wasn't frozen, advance the banner timer by dt and drop the banner after `dur`. Then decay the shake: `shake *= 0.02^dt`, using the tick's dt, even when frozen.
3. The camera adds the shake as screen jitter. The renderer takes that jitter from the `camera` stream.

Played in this order, the banner, the damage numbers and the shake match the prototype tick for tick (the parity check compares them). Particles use their own streams, so they look like the prototype's but not bit for bit.

## Cosmetic random streams

The canonical rule is in overview.md section 3. Each consumer has its own mulberry32 streams, reseeded at every match start from the match seed (`S.game.seed`) with `deriveSeed(seed, id)` (`sim/core/rng.js`, `rng.gd`). The derivation is integer-only, so every language agrees:

| id | used for |
| :--- | :--- |
| `vfx.spark`, `vfx.debris`, `vfx.dust`, `vfx.splash`, `vfx.fire` | the particles of each effect class |
| `vfx.charge` | the charge aura's spark and dust rolls (and the aura spark's spread) |
| `vfx.water` | the beam-splash roll |
| `camera` | screen-shake jitter (the prototype used `Math.random` here) |
| `audio` | reserved for Audio |

A renderer can use GPU particles or any other method: the stream contract only matters where cosmetic output has to be reproducible, as in replay videos or tests.

## What the renderer reads from the sim directly

Events carry only transient effects. Persistent visuals come from sim state, read after each tick and never written:
- fighters: `x, y, face, rot, state, stance, tier, hidden, beamCharge, aura, col, hair, name`
- `S.beams`: origin, direction, length, progress `p`, age `t`, `life`, width `w`, `col`
- `S.game.clash`: the beam-clash midpoint and its progress
- `S.game.ko`
- `S.dirS.ex.combo`: the chain counter
- terrain height: `groundY` and `seaAt`, or `S.base` and `S.deform`
- the world's persistent damage (GDScript sim), all rebuilt from state after a seek or a snapshot:
  - `S.craters`: an array of records, oldest first, capped at 400 (`WorldCrater.LIST_MAX`; the oldest is dropped, its dent stays in `S.deform`). Each has `x, y, r, depth, rim, energy, cause, owner, t, skid, sdepth`, the `crater` event's fields plus the match time `t` and the furrow's depth at the bowl `sdepth`. `S.deform` is the truth for the ground: it also holds the scorch grooves, which have no records, and the deform limits (-260 to +60) clip it, so do not rebuild it from the records; use them for the round bowls in depth.
  - `S.scorch`: burn intensity per terrain column, 0 to 1, permanent (a `PackedFloat32Array` of 1,200, like `S.deform`).
  - `S.water`: water depth per terrain column (`PackedFloat32Array` of 1,200). The surface of standing water is ground + depth, and it is sea level (0) once settled. A column is wet at 0.5 or more (`WorldWater.MIN_DEPTH`). `WorldWater.surfaceAt(S, x)` and `depthAt(S, x)` read it. The prototype's rule that water is drawn only where the base terrain is below -30 (`seaAt`) still holds for the sea; crater lakes that fill from the sea are the difference, and they exist only where the ground was dug below -30 and connects to the sea.
- buildings: `curH`, `alive`
- trees
- the `S.world` counters

The prototype's `draw*` functions show how each one was drawn.

## Prototype parity mode

`createSim({math: 'native', fxRng: 'shared'})` keeps the port tick-identical to the prototype. Each emitter also burns, on the gameplay stream, exactly the random draws the prototype's effect made (`core/fx.js`). This is a JS-only test mode that keeps the prototype usable as an oracle; the game runs det + split. The port harness and `sim/core/tools/parity.js` use it.
