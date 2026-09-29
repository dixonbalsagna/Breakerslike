# Architecture overview: the reference simulation core

Owner: Simulation and Engine. Code: `sim/`. Interface detail: [module-spec.md](module-spec.md). Determinism analysis for ADR 0001: [determinism.md](determinism.md).

`sim/` is a headless, deterministic port of `prototype/index.html` (pinned at commit 7233c96). It reproduces the prototype exactly, tick by tick, and it is the parity oracle for whichever engine ADR 0001 picks: any engine port must reproduce its per-tick state hashes. Plain JavaScript ES modules, no DOM, Node built-ins only. `npm test --prefix sim` runs everything (unit tests, full parity, the 1000-match soak) and exits 0 or 1.

## 1. Layers and the sim/render boundary

| Layer | Directory | Holds | Owner after the port |
| :--- | :--- | :--- | :--- |
| Player | `sim/input/` | the intent record, keyboard mapping, `control()` (intent to stance switch, press time, attack request) | Controls and Game Feel |
| Opponent AI | `sim/director/ai.js` | stance choice, hunting, hiding, attack timing; produces intents like a player | Encounter Systems |
| Director | `sim/director/` | exchange planner and beat ops, melee templates, parry and chain windows, beams and clashes, launch planner | Encounter Systems |
| World | `sim/world/` | biomes, wrapped heightfield and craters, structures, civilians and casualties, cover | World and Environment |
| Core | `sim/core/` | the state object, the tick, fighter physics, damage and KO, the hiding mechanic, RNG, wrap math, hashing, replays, the cosmetic lane | Simulation and Engine |

Temporary homes: `ROSTER` stays in `core/roster.js` until `data/fighters/` exists (Narrative, Tools). `core/view/camera.js` goes to Camera once an engine is chosen.

Boundary rules:
1. **One state object.** Everything the simulation knows lives in one plain object `S` (module-spec section 2). No module keeps state and no code reads globals, so several sims run side by side in one process. The parity lockstep does this now, and rollback will do it later.
2. **Rendering reads, never writes.** Renderers, the view camera, audio and UI read `S` after a tick. Nothing inside `step()` calls view code; the host runs `camStep(cam, S, S.dt, ...)` after each tick.
3. **A cosmetic lane.** Particles, damage numbers, the banner and the shake cue live in `S.fx`. Gameplay code never reads `S.fx`. The canonical hash has two lanes, gameplay and presentation (`core/hash.js`), so the boundary is testable: a cosmetic change may move the presentation hash, never the gameplay one. (That test arrives with the QA-002 split, section 3.)
4. **Exchange beats are data.** The prototype scheduled closures. The port schedules `{t, op, args, done}` records and runs them through one dispatcher (`director/exchange.js runBeat`). An exchange in flight is therefore plain data, which a snapshot, a rollback or a replay inspector can store and restore. Beats run in the prototype's order (stable sort by time, insertion order on ties). The op catalogue is module-spec section 4.

## 2. Tick contract

`step(S, inputs)` advances exactly one fixed tick, `DT = 1/60` s, and returns true, or false during hit-stop.

- **In.** `inputs = [intent|null, intent|null]`, one per slot. An intent is `{mx, my, dash, charge}` held levels plus `{light, heavy, sig}` presses and `stance` (-1, or a pressed 0 to 3). AI slots ignore `inputs` and make their intents inside the tick, because the AI draws from the sim stream.
- **Out.** The updated `S`; `S.dt`, the effective dt of the tick; feed lines in `S.out.feed` as `{t, tag, sub}`, which the host drains. The structured event log (QA-004) comes later: an envelope `{type, tick, actor, target, payload}`, with the director's decision events defined by Encounter Systems.
- **Time.** The effective dt is `DT * game.ts`: 0.35 slow motion for 2.2 s after a KO. Hit-stop (`dirS.stop > 0`) counts down in real seconds, advances only cosmetics and consumes no input, so the host keeps unconsumed presses until a tick returns true. Both are float-second timers carried over from the prototype. determinism.md names them as a hazard; the target is integer ticks in sim state (Netcode's contract).
- **Order inside a tick** (the prototype's): hit-stop check; `T += dt`; KO timer; one gameplay draw picks which slot's control runs first; `control` for both slots in that order; `stepFighter` slot 0, then slot 1; director update (due beats, chain window, end of exchange); beams; particles; clash sparks; banner timer; shake decay.
- **Host loop.** A fixed-step accumulator:

```
acc += min(0.1, frameSeconds)
while (acc >= DT) { inputs = sampleIntents(); if (step(S, inputs)) clearPresses(); camStep(cam, S, S.dt, vw, vh); acc -= DT }
render(S, cam)
```

## 3. RNG policy (canonical: VFX, Camera and Audio cite this)

The rule:
1. **One sim stream.** Every gameplay random number comes from `S.rng`, a mulberry32 stream seeded by the match seed. Its state is a single 32-bit integer (`{a}`), so it snapshots trivially. Nothing in `sim/` may use `Math.random` or a clock; unseeded play means the host picks a seed and records it.
2. **Cosmetic streams per consumer**, seeded from the match seed by a fixed derivation: one per VFX effect class (`vfx.spark`, `vfx.debris`, `vfx.dust`, `vfx.splash`, `vfx.fire`), plus `camera` and `audio`. Proposed derivation, integer-only so every language reproduces it: `seed(id) = fmix32(matchSeed ^ fnv1a32(id))`, where fnv1a32 runs over the id's UTF-16 code units and fmix32 is the MurmurHash3 finaliser.
3. **No cosmetic draw ever advances the sim stream.**

Current state. The parity build deliberately breaks rule 3, because the prototype does (QA-002): the draw sites in module-spec section 6 use `S.rngFx`, which is `S.rng` itself (`opts.fxRng: 'shared'`). The QA-002 change, held for now, replaces `S.rngFx` with the per-class streams. It keeps `'shared'` only as a test mode, so the port can still be checked against the prototype, and it adds the test that switching cosmetics off leaves every gameplay hash unchanged. World generation uses its own fixed seed (4242), consumed entirely inside `genWorld`; it is part of generating world data, not a runtime stream, and will follow World's procedural-planet seed. Adding, removing or reordering a sim-stream draw is a behaviour change: parity breaks and the golden hashes must be regenerated on purpose.

## 4. Serialisation and replay

**Replay (implemented, `core/replay.js`, tested).** A replay is JSON:

```
{format: 'meridian-replay', v: 1, seed, ai: {p1, p2}, ticks,
 inputs: [[tick, slot, intent|null], ...],        // only where a slot's intent changed
 toggles: [[tick, slot], ...],                     // AI toggled before that tick
 checkpoints: [[tick, gameplayHash], ...],         // every 60 ticks
 final: {gameplay, presentation}}
```

`play(replay)` re-runs from the seed and reports the first checkpoint that disagrees. Replays store intents, not keys, so they don't depend on the key mapping. Planned additions: a `sim` version field (the package version or git revision) and a `setup` block (roster and spawns) once there are more than two fighters.

**Snapshot (proposed v1, not implemented).** A plain object built from `S`:
- Fighter references become indices: `rush.tgt`, `launchBy`, `game.ko`, `game.clash.A` and `.D`, `beam.A`, `ex.A` and `ex.D`. Beats are already data.
- Static world data (base heights, building sizes, tree positions) is regenerated from the world seed. Only what changes is stored: `deform` as raw little-endian float32 bytes (1200 columns, 4.8 KB, base64 in JSON), building `hp`, `alive` and `popAlive`, and a tree `alive` bit mask.
- Numbers must round-trip exactly, including -0 and NaN. Plain JSON turns -0 into 0, and signed zeros can arise in the sim (`Math.sign(-0)`, `-0 * x`), so the binary form uses raw float64 and the JSON form tags -0.
- The rng states are two integers.
- The cosmetic lane is optional: a rollback snapshot drops it (about 10 KB without particles), and a save state keeps it (particles can reach 2400 x 14 fields).
- Acceptance when implemented: a snapshot taken at any tick and restored into a fresh `S` continues with the same per-tick hashes as the original.

## 5. Parity and tests

`node sim/core/tools/parity.js`, also part of `npm test --prefix sim`, has five stages:
1. **Probe.** The prototype, loaded through QA's harness with two read-only probes, matches the plain prototype.
2. **Lockstep.** 170 matches in every arm; after every tick it compares the gameplay lane, the presentation lane, the camera and the feed text.
3. **Keys.** Scripted key events drive both sides: P1 human, both human, AI toggled mid-match, and a directed lock-lost case.
4. **Records.** QA's own `runMatch` gives identical records on both.
5. **Golden.** `qa/golden-hashes.json` is reproduced.

Under the full plan every line of the port executes except one unreachable return. Negative controls (one extra draw, a changed constant, changed text) are caught at the tick they take effect. Unit tests cover the RNG, wrap and shortest-arc math at every separation across the seam, terrain, craters and the camera across the seam, moving fighters crossing it, same-seed determinism, independent sims, and replays.

## 6. Module map

| Module | Prototype functions it holds |
| :--- | :--- |
| core/constants.js | `DT`, `W`, `COL`, `NC`, `HALF` |
| core/rng.js | `mulberry32`, `rng`, `R` (as `createRng`, `next`, `range`) |
| core/wrap.js | `wrap`, `sdx` |
| core/mathx.js | `clamp` |
| core/roster.js | `ROSTER`, `mkF` (as `createFighter`), `opp` |
| core/sim.js | `newMatch`, `step`, `toggleAI` (plus `createSim`) |
| core/fighter.js | `tierUp`, `impact`, `stepLaunched`, `stepRush`, `stepFighter` |
| core/hiding.js | `updateHidden` |
| core/damage.js | `hurt`, `hit`, `ko` |
| core/fx.js | `banner`, `P`, `spark`, `ring`, `debris`, `dust`, `splash`, `fire`, `afterimage`, `stepParts` |
| core/events.js | `feed` |
| core/view/camera.js | `camStep` (camera follow; the shake decay stays in the tick) |
| core/hash.js, core/replay.js | new: canonical hash, replays |
| world/biomes.js | `SEG`, `biomeAt` |
| world/terrain.js | `base`, `deform`, `genWorld`, `groundY`, `seaAt`, `crater` |
| world/structures.js | `curH`, `casualty`, `damageBuilding`, `damageArea`, `explode`, `popNear`, `nearestBuilding` |
| world/cover.js | `nearTree`, `coverAt`, `nearestCover` |
| director/exchange.js | `STN`, `newEx`, `B` (as `schedule`), `requestAttack`, `openWindow`, `chain`, `endEx`, `dirUpdate`, and `runBeat` (new: the op dispatcher) |
| director/melee.js | `planMelee`, `strike`, `launchBeat`, `clashWave`, and the melee beat ops |
| director/beam.js | `planBeam`, `startClash`, `fireBeam`, `sampleBeam`, `beamStep`, and the beam beat ops |
| director/launch.js | `chooseLaunch`, `doLaunch` |
| director/ai.js | `pickW`, `aiInput` |
| input/intent.js | the `f.in` record and its reset (from `control`) |
| input/keyboard.js | `KEYS`, `humanInput` (as `intentFromKeys`) |
| input/control.js | `control` |
| not ported (render, host) | `hexA`, `BCOL`, `STS`, `w2s`, `rr`, clouds, stars, `draw*`, `bar`, `render`, `resize`, `syncButtons`, `takeOver`, listeners, `frame` |
