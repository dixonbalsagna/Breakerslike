# The fx event stream: the sim's cosmetic output

Owner: Simulation and Engine. Status: implemented in both cores (`sim/core/fx.js`, `sim/core/fx.gd`) and bit-identical between them. It's the input for Rendering, VFX, Camera and Audio. It resolves QA-002.

Since the QA-002 split, the sim holds no cosmetic state and makes no cosmetic random draws. Every visual effect the prototype spawned inside the sim now leaves it as an event: particles, damage numbers, the banner and camera shake. The render side turns events into visuals with its own random streams, so no VFX change can ever alter a match. `sim/core/view/fx.js` and its GDScript twin `view/fx.gd` are the reference consumer. They reproduce the prototype's particles, and the golden checks cover them too.

## Delivery and timing

- `step(S, inputs)` appends the tick's events to `S.out.fx`, an array (GDScript: `SimState.FxEvent` objects). The host drains it after every call: consume the events in order, then clear the array. This applies to hit-stop ticks too.
- Events are in emission order, which is the order the prototype made its effect calls. Each tick's list holds exactly one `tick` event, placed where the prototype stepped its particles, after the fighters, the director and the beams. The only events that can follow it are the beam-clash sparks.
- A hit-stop tick (the sim is frozen; `step` returns false) emits just `{type: 'tick', frozen: true}`.
- Coordinates are world units, taken when the event was emitted: x in [0, W) on the wrapped planet (W = `SimConst.W`, 153,600 since the world scale), y upward with sea level at 0. Durations are in seconds.
- Measured over 20 AI matches (85,863 ticks): about 1.35 events per tick on average, 7 at p99 and 46 at most, in a beam-and-explosion tick.

## The envelope

Every event carries `type` and `tick` (`S.tick`: steps since the match began, hit-stop ticks included), plus the fields of its type. Fighter references are slots in `S.fighters` (0 and 1 today; -1 means none). The feed text (`S.out.feed`) stays for people. **Tools and tests read events, not feed text (QA-004).** The core's feed lines already have structured twins (`tier_up`, `hide_start`, `found`, `ko`). The director's (attacks, launches with their `launch_plan` candidates, parries, chains, ambush, lock lost) arrive with Encounter's slices; `wounds-plan.md` lists who delivers each one. Planned shapes that UI, Audio and QA have asked for are fixed there too (§6): for example `window_open` {kind, duration}, `cinematic_start` and `cinematic_end` {kind, length}, and an `internal` flag on core `region_stage` events.

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
| `slide` | x, x1, w, depth, energy, variant, owner | a knockback slide ended (GDScript sim only): `x` where the fighter touched down, `x1` where he stopped or left the ground, `w` the trench's full width, `depth` its depth at the start, `variant` `"ground"` or `"paved"` (it started in a city or village), `owner` the launcher's slot | nothing yet (ignored). Rendering draws the whole trench and the dust plume's total |
| `slide_dust` | x, y, spd, w, variant, n | a sample along a slide, every 40 x WS units, at most 60 per slide: `spd` is the normalised speed (the launch's traversal factor divided out), `w` the trench width, `variant` the surface, `n` the sample index | nothing yet (ignored). Rendering and VFX throw dust and rubble chips at each |
| `skim` | x, y, spd, n | a launched fighter skipped off water: the surface height, the speed, and the skip number | nothing yet (ignored). VFX draws the wake |
| `beamSplash` | x | a beam sample below y = 30 over the sea | the consumer rolls 60% for a splash of 3 at (x, 0) |
| `damage` | x, y, amount, col, attacker, victim, region, kind, number | every hit, and every landing or collision that hurts | a damage number when `number` is true (hits): text `String(Math.round(amount))` rising 60 units/s for 0.9 s, gold when stance was ignored, white otherwise. `attacker` and `victim` are fighter slots (-1 for none); `region` is head, core, arms or legs; `kind` is light, heavy, guard, guard_break (the GUARD BREAK's finishing strike, from S2), beam or impact (Audio's hit sounds) |
| `banner` | text, col, dur | power-ups, parries, KO, chains, clashes, ambushes; for human players also NEED 45 KI and LOCK LOST | the centre-screen banner (the latest one replaces any earlier one) for dur seconds of unfrozen time |
| `shake` | k, x | anything heavy; `x` is the world x of the cause (the hit fighter, the impact, the beam's origin, the clash point, the building) | camera shake: `shake = max(shake, k)`. A split-screen camera can shake only the pane whose view holds `x` |
| `tick` | dt, frozen | once per tick | steps the particles and damage numbers by dt (dt × 0.1 when frozen) |
| `region_stage` | actor, region, stage | a body region's wound stage changes, up or down (Wounds, `sim/core/wounds.gd`) | nothing; for the crown and wound cards (Rendering, UI). `actor` is the fighter's slot; `region` is head, core, arms or legs; `stage` 0 fresh, 1 bruised, 2 battered, 3 broken |
| `region_broken` | actor, region | a region reaches broken (also sent as a `region_stage`) | nothing; the break's wound card and set piece |
| `brink_enter` | actor | the fighter is on the brink: the core broken, or two of head, arms and legs broken | nothing; the brink state (a finisher can now end the match, from S2) |
| `brink_exit` | actor | the fighter leaves the brink (by a Rally, from S4) | nothing |
| `tier_up` | actor, tier, onGround | a fighter reaches a new power tier (the structured twin of the feed line) | nothing; `onGround` is true when the power-up cratered the ground |
| `hide_start` | actor, cover | a fighter goes to ground (hidden); cover is submerged, canopy or ridge. Since S2 only a fighter with `canHide` (the future stealth fighter) hides; nobody in the base roster emits it | nothing |
| `found` | actor | the opponent regains lock on `actor` (spec-wounds.md §1c): line of sight returns, the hunter comes within 240, `actor` attacks, or 4 s pass. For a `canHide` fighter it still means found in hiding | nothing; the Found flash |
| `ko` | winner, loser | the match's KO (fighter slots). Since S2 only a lost finisher contest KOs | nothing; the KO banner arrives as a `banner` event |
| `decisive` | winner, loser, kind | a decisive exchange was won (spec-wounds.md §1): `kind` launch (any launch, however it lands), clash (a heavy clash won), guard_break, interrupt (a CHARGE INTERRUPT that ended in a shove), beam (a signature hit or guard) or beam_clash | nothing; Art's Pride flash |
| `finisher_start` | actor, target | `actor` won a decisive exchange against `target` on the brink: the finisher replaces the rest of the exchange | nothing; the finisher set piece (Camera, UI) |
| `finisher_contest` | target, chance, survived | the fighter on the brink rolled against the finisher: `chance` is the survival chance (0.30, less 0.10 per minute past 8:00, floor 0); a loss is followed by `ko` | nothing |
| `attack` | actor, target, kind, defStance, template, ambush | the director accepted an attack: `kind` light, heavy or sig; `defStance` the defender's stance or CHARGING; `template` the exchange's tag; `ambush` true only for a `canHide` fighter | nothing; the structured twin of the feed's attack line (QA-004) |
| `parry` | actor, target | `actor` parried `target`'s strike; the rest of the exchange is cancelled | nothing |
| `chain_end` | actor, n | a chain of `n` linked exchanges by `actor` ended | nothing |
| `ambush` | actor, target | an ambush attack from cover began (`canHide` fighters only) | nothing |
| `lock_lost` | actor, target | `actor` tried to attack `target` while lock was broken: the attempt costs 2 ki and a 0.5 s cooldown | nothing |
| `launch_plan` | actor, target, text, chosen | every launch decision: `text` lists every candidate as `NAME score` joined with `|`; `chosen` is the launch, or NONE for a shove | nothing; the planner's reasons (debug overlay, QA §5b) |
| `window_open` | actor, kind, dur | a parry window (`actor` the defender, `dur` until the first parryable strike) or a chain window (`actor` the attacker, 0.6 s) really opened | nothing; UI's window cue |
| `clash_draw` | actor, target | a clash ended in a draw (the heavy-clash shockwave) | nothing; Art's flash |
| `hazard_telegraph` | actor, source, eta, x | the world is about to hit `actor` at `x` in `eta` seconds (0 when unknown). `source` brunt (a launch predicted to hit a building) from the director; World adds collapse, landslide and lava | nothing; Art's Hazard flash |
| `searching` | actor, target, x | `actor` searches for `target` around `x`: lock was broken, or a hunt sweep | nothing; the Searching flash |
| `danger` | actor, source, eta | `actor` is about to be hit: `source` windup (a parryable strike winds up, `eta` until it lands) or ambush | nothing; Art's danger-sense flash |
| `launch` | actor, target, amount, face | `actor` was launched by `target` at speed `amount`, horizontally toward `face` (+1 or -1). `amount` is the drawn speed, `hypot(vx, vy)` of the fighter as it leaves: the horizontal part already carries the launch's traversal factor (`launchT`, up to TRAV_LAUNCH). Divide `vx` by `launchT` for the unboosted speed that impact damage and energy use | nothing; Camera's launch follow |
| `rush` | actor, target, n | `actor` rushes to `target`, arriving at tick `n` | nothing; Camera |

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
  - `S.slides`: an array of records like `S.craters`, capped at 200: `x0, x1, hw, depth, energy, t, owner, surface` (the `slide` event's fields plus the match time and 1 for a paved start).
  - `S.crack`: pavement crack intensity per terrain column, 0 to 1, permanent, set by slides in city and village biomes (a `PackedFloat32Array` of `NC`). Rendering tints cracked pavement from it.
  - `S.scorch`: burn intensity per terrain column, 0 to 1, permanent (a `PackedFloat32Array` of `NC`, like `S.deform`).
  - `S.water`: water depth per terrain column (`PackedFloat32Array` of `SimConst.NC`). The surface of standing water is ground + depth, and it is sea level (0) once settled. A column is wet at 0.5 or more (`WorldWater.MIN_DEPTH`). `WorldWater.surfaceAt(S, x)` and `depthAt(S, x)` read it. The prototype's rule that water is drawn only where the base terrain is below -30 (`seaAt`) still holds for the sea; crater lakes that fill from the sea are the difference, and they exist only where the ground was dug below -30 and connects to the sea.
- buildings: `curH`, `alive`
- trees
- the `S.world` counters

The prototype's `draw*` functions show how each one was drawn.

## Prototype parity mode

`createSim({math: 'native', fxRng: 'shared'})` keeps the port tick-identical to the prototype. Each emitter also burns, on the gameplay stream, exactly the random draws the prototype's effect made (`core/fx.js`). This is a JS-only test mode that keeps the prototype usable as an oracle; the game runs det + split. The port harness and `sim/core/tools/parity.js` use it.
