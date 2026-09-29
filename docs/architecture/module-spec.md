# Reference core: module and state specification

Owner: Simulation and Engine. Status: the contract for the port of `prototype/index.html` (pinned at commit 7233c96) into `sim/`. Every module in `sim/` follows it. `overview.md` explains the architecture; this file is the detailed interface.

## 1. Rules of the port

1. **Behaviour-identical.** The port must reproduce the prototype exactly: same state after every tick, same feed text, same random draws. Do not fix prototype bugs. Replicate them and list them (sim/README.md collects the list).
2. **Verbatim arithmetic.** Copy every arithmetic expression from the prototype with the same operands, the same order and the same grouping. `a*b*c` stays `a*b*c`. `x += y + z` stays a compound assignment. `Math.pow`, `Math.hypot`, `Math.sin`, `Math.cos` stay as they are. Do not hoist, cache, simplify or reorder floating-point work, and do not replace `Float32Array` storage with plain arrays (float32 rounding is part of the behaviour).
3. **Random-draw order.** Every `rng()` and `R(a, b)` in the prototype becomes exactly one `next(stream)` or `range(stream, a, b)` in the port, in the same order and under the same conditions. Short-circuit evaluation (`D.ai && rng() < p` draws only when `D.ai` is truthy), object-literal property order and argument order all decide the draw order, so keep them.
4. **One state object.** All simulation state lives in one object `S` (section 2). Every function that reads or writes state takes `S` as its first parameter. No module-level mutable state, no globals, no `Math.random`, no `Date`, no DOM, no Node APIs in runtime modules (tools and tests may use `node:*`).
5. **References stay references.** Live state keeps references to fighter objects exactly where the prototype does: `f.rush.tgt`, `f.launchBy`, `S.game.ko`, `S.game.clash.A` and `.D`, `beam.A`, `ex.A` and `ex.D`, and every `cause`, `by`, `att`, `tgt` parameter. Serialisation maps them to fighter indices (overview.md).
6. **Names and shapes.** Keep the prototype's field names and object shapes for fighters, buildings, trees, the world counters, game, dirS, exchanges, beams, particles and damage numbers. Section 7 lists every deliberate difference.
7. **Cosmetics are a separate lane.** Particles, damage numbers, the banner and camera shake live in `S.fx`. Gameplay code never reads `S.fx`. Cosmetic random draws use `S.rngFx`. In the parity build `S.rngFx === S.rng` (the same object), so the draw order is the prototype's. Section 6 lists the cosmetic draw sites.
8. **Imports and cycles.** Modules import each other by relative path with the `.js` extension. Import cycles exist (damage to director and back) and are safe only because no module calls an imported function or reads an imported binding at module-evaluation time. Keep it that way: no top-level code that uses imports, no `const OPS = {...importedFns}` tables at top level.
9. **Name clashes with the prototype.** The prototype's `planMelee` has a local helper called `S` (schedule a strike) and a local `base` (damage base). In the port `S` is the state object, so rename the helper (for example `STRIKE`). `R` becomes `range(S.rng, a, b)`; `R0` (schedule the opening rush) can keep its name.

## 2. The state object S

Created by `createSim()`, reset by `newMatch()`.

```js
S = {
  opts:    { fxRng: 'shared' },       // 'shared': cosmetics draw from S.rng (prototype parity). 'split' comes later (QA-002).
  T:       0,                         // sim time in seconds (prototype T)
  dt:      0,                         // effective dt of the latest tick (DT x game.ts), for the view layer
  rng:     { a },                     // gameplay stream (prototype rng)
  rngFx:   S.rng,                     // cosmetic stream; the same object as S.rng in the parity build
  game:    { ko: null, koT: 0, ts: 1, clash: null, seed: 1 },            // prototype game, minus banner, paused, started
  dirS:    { ex: null, cool: 0, stop: 0, lastLaunch: '', lastLaunch2: '' },
  fighters: [F0, F1],                 // createFighter objects
  world:   { pop0, casualties, structuresLost, craters },
  base:    Float32Array(NC),          // generated terrain height per column
  deform:  Float32Array(NC),          // accumulated crater depth per column
  buildings: [ {x, w, h, maxhp, hp, alive, kind, pop, seed, popAlive} ],
  trees:   [ {x, h, alive, burn} ],
  beams:   [ {A, ox, oy, ux, uy, len, p, t, life, w, variant, col} ],
  fx:      { parts: [], floats: [], banner: null, shake: 0 },         // presentation lane
  out:     { feed: [] },              // output: feed lines {t, tag, sub}; the host drains it
}
```

### Prototype global to port path

| Prototype | Port |
| :--- | :--- |
| `T` | `S.T` |
| `rng()`, `R(a, b)` | `next(S.rng)`, `range(S.rng, a, b)`; cosmetic sites use `S.rngFx` |
| `game.ko`, `game.koT`, `game.ts`, `game.clash`, `game.seed` | `S.game.*` |
| `game.banner` | `S.fx.banner` |
| `game.paused`, `game.started` | not sim state (host UI) |
| `dirS.*` | `S.dirS.*` |
| `fighters` | `S.fighters` |
| `world`, `base`, `deform`, `buildings`, `trees` | `S.world`, `S.base`, `S.deform`, `S.buildings`, `S.trees` |
| `beams` | `S.beams` |
| `parts`, `floats` | `S.fx.parts`, `S.fx.floats` |
| `cam.shake = Math.max(cam.shake, k)` | `S.fx.shake = Math.max(S.fx.shake, k)` |
| `cam.x`, `cam.y`, `cam.z` | view layer only (`core/view/camera.js`), not in `S` |
| `held`, `edges` | input layer, host side (`input/keyboard.js`) |
| `vw`, `vh` | view layer only |
| `feed(tag, sub)` | `feed(S, tag, sub)`: pushes `{t: S.T, tag, sub}` onto `S.out.feed` |

### Fighter object

`createFighter(def, x, keys, ai)` returns the prototype `mkF` object with the same fields, the same order and the same initial values, except that `stanceOk` is dropped (written every tick, never read) and `dPrev: null` is added explicitly (the prototype leaves it undefined until the first attack; both are falsy and never equal `'charging'`).

## 3. Modules and exports

Signatures are exact. `S` is the state, `f`, `A`, `D`, `a`, `d`, `att`, `tgt`, `by`, `cause` are fighter objects, `ex` is an exchange, `b` a building or beam.

### sim/core (Simulation and Engine)
| File | Exports |
| :--- | :--- |
| constants.js | `DT, W, COL, NC, HALF` |
| rng.js | `createRng(seed)`, `next(r)`, `range(r, a, b)` |
| wrap.js | `wrap(x)`, `sdx(a, b)` |
| mathx.js | `clamp(v, a, b)` |
| roster.js | `ROSTER`, `createFighter(def, x, keys, ai)`, `opp(S, f)` |
| fx.js | `P(S, o)`, `spark(S, x, y, n, col, spd)`, `ring(S, x, y, gr, col, life, r0)`, `debris(S, x, y, n, col, spd)`, `dust(S, x, y, n, col)`, `splash(S, x, y, n)`, `fire(S, x, y, n)`, `afterimage(S, f)`, `banner(S, text, col, dur)`, `stepParts(S, dt)` |
| events.js | `feed(S, tag, sub)` |
| damage.js | `hurt(S, f, amt, by)`, `hit(S, ex, A, D, dmg, o)`, `ko(S, D, A)` |
| hiding.js | `updateHidden(S, f, dt)` |
| fighter.js | `tierUp(S, f)`, `impact(S, f, g, sp)`, `stepLaunched(S, f, dt)`, `stepRush(S, f, dt)`, `stepFighter(S, f, dt)` |
| sim.js | `createSim(opts)`, `newMatch(S, seed, ai)`, `step(S, inputs)`, `toggleAI(S, idx)` |
| view/camera.js | `createCamera()`, `resetCamera(cam)`, `camStep(cam, S, dt, vw, vh)` |
| hash.js | canonical state hashing (see the parity tooling) |
| index.js | re-exports the public API |

### sim/world (World and Environment after the port)
| File | Exports |
| :--- | :--- |
| biomes.js | `SEG`, `biomeAt(x)` |
| terrain.js | `genWorld(S)`, `groundY(S, x)`, `seaAt(S, x)`, `crater(S, x, r, depth, cause)` |
| structures.js | `curH(b)`, `casualty(S, n, cause)`, `damageBuilding(S, b, d, cause)`, `damageArea(S, x, y, r, dmg, cause)`, `explode(S, x, y, r, cause)`, `popNear(S, x, r)`, `nearestBuilding(S, x, sign, maxD, y)` |
| cover.js | `nearTree(S, x)`, `coverAt(S, f)`, `nearestCover(x)` |

### sim/director (Encounter Systems after the port)
| File | Exports |
| :--- | :--- |
| exchange.js | `STN`, `newEx(A, D, kind)`, `schedule(ex, t, op, args)`, `requestAttack(S, A, kind)`, `runBeat(S, ex, b)`, `openWindow(S, ex)`, `chain(S, ex)`, `endEx(S, ex)`, `dirUpdate(S, dt)` |
| melee.js | `planMelee(S, ex)`, `strike(S, ex, a, d, dmg, o)`, `launchBeat(S, ex, att, tgt, force)`, `clashWave(S, ex)`, `opWind(S, ex, args)`, `opSlip(S, ex, args)`, `opDodge(S, ex, args)`, `opGuardBreak(S, ex, args)` |
| beam.js | `planBeam(S, ex)`, `startClash(S, ex, variant)`, `fireBeam(S, A, ox, oy, ux, uy, len, variant)`, `sampleBeam(S, b, s)`, `beamStep(S, dt)`, `opBeamCharge`, `opBeamFire`, `opBeamImpact`, `opBeamDodge`, `opBeamEscape`, `opClashResolve` (all `(S, ex, args)`) |
| launch.js | `chooseLaunch(S, A, D)`, `doLaunch(S, att, tgt, plan, force)` |
| ai.js | `pickW(S, w)`, `aiInput(S, f)` |

### sim/input (Controls and Game Feel after the port)
| File | Exports |
| :--- | :--- |
| intent.js | `createIntent()`, `clearIntent(i)`, `applyIntent(dst, src)` |
| keyboard.js | `KEYS`, `intentFromKeys(k, held, edges)` (k is `KEYS.p1` or `KEYS.p2`; held and edges are Sets of key codes) |
| control.js | `control(S, f, intent)` |

## 4. Exchange beats are data

A beat is `{t, op, args, done}`. `args` is a plain object or `null`. Nothing in a beat is a function, so an in-flight exchange can be serialised.

```js
export function schedule(ex, t, op, args = null) { ex.beats.push({ t, op, args, done: false }); ex.beats.sort((a, b) => a.t - b.t); }
```

The sort is the prototype's (stable, by `t`), run after every push, so beats with equal `t` keep insertion order and the port must schedule them in the prototype's `B()` call order. `dirUpdate` runs the prototype loop unchanged and calls `runBeat(S, ex, b)` where the prototype called `b.fn(ex)`. `runBeat` is a `switch (b.op)` in exchange.js; unknown ops throw. In the table, `A = ex.A`, `D = ex.D`, and `X(who)` means `who === 'A' ? A : D`.

| op | args | scheduled by | effect when it runs (prototype closure, verbatim) |
| :--- | :--- | :--- | :--- |
| `rush` | `{off, dur}` | planMelee `R0` (58, rt), pursuit slip (260, rt*0.8), chain (60, 0.24) | `A.rush = {tgt:D, off:-A.face*off, end:S.T + dur}` |
| `wind` | null | planMelee `wind(t)` | `opWind`: `ex.windowStart = S.T; if (D.ai && next(S.rng) < (D.stance === 1 ? 0.5 : D.stance === 0 ? 0.3 : 0.12)) schedule(ex, ex.t + range(S.rng, 0.05, 0.16), 'press', {who:'D'})` |
| `press` | `{who}` | wind (D), openWindow (A) | `X(who).lastAtkT = S.T` |
| `strike` | `{a, d, dmg, o}` with a, d in 'A' or 'D' | planMelee `S(t, a, d, dmg, o)` | `strike(S, ex, X(a), X(d), dmg, o)`; `dmg` and `o` are computed at plan time, as in the prototype |
| `launch` | `{force, rev}` | planMelee `LAUNCH(t, force, who)`, chain | `launchBeat(S, ex, rev ? D : A, rev ? A : D, force)`; `rev` is true where the prototype passed `who` (always D) |
| `window` | null | planMelee `WIN`, chain | `openWindow(S, ex)` |
| `nop` | null | planMelee `NOP`, beams | nothing |
| `slip` | null | pursuit, target slips away | `opSlip`: the closure at prototype line 446 |
| `dodge` | null | evasive defender | `opDodge`: the closure at line 462 |
| `guardBreak` | null | defensive defender, heavy | `opGuardBreak`: the closure at line 485 |
| `clashWave` | null | heavy vs aggressive, shockwave | `clashWave(S, ex)` |
| `chainStrike` | null | chain | `strike(S, ex, A, D, 52 + ex.combo*7, {noParry:true, ignoreStance:true, big:true, stop:0.08})`; `ex.combo` is read when the beat runs |
| `beamCharge` | `{rise}` | planBeam, t = 0 | `opBeamCharge`: closure at line 593 |
| `beamFire` | `{out, variant, dist}` | planBeam, t = 0.8 | `opBeamFire`: closure at line 598; schedules beamImpact, beamDodge or beamEscape, then a `nop` at `ex.t + 0.9` |
| `beamImpact` | `{out, ux, uy}` | beamFire | `opBeamImpact`: closure at line 608 |
| `beamDodge` | null | beamFire | `opBeamDodge`: closure at line 616 |
| `beamEscape` | null | beamFire | `opBeamEscape`: closure at line 618 |
| `clashResolve` | `{aw, variant}` | startClash, `ex.t + 1.6` | `opClashResolve`: closure at line 629 with `Wn = aw ? A : D`, `Ls = aw ? D : A` |

`startClash` also schedules `nop` at `ex.t + 2.6`. `schedule` and the `op*` handlers never capture a fighter: they read `ex.A` and `ex.D` when they run, exactly as the closures did.

## 5. The tick

```js
export function step(S, inputs) {                     // inputs: [intent|null, intent|null] or undefined
  const dtReal = DT;
  const dt = dtReal*S.game.ts;
  S.dt = dt;
  if (S.dirS.stop > 0){ S.dirS.stop -= dtReal; stepParts(S, dt*0.1); S.fx.shake *= Math.pow(0.02, dt); return false; }
  S.T += dt;
  if (S.game.ko){ S.game.koT += dt; if (S.game.koT > 2.2) S.game.ts = 1; }
  const ord = next(S.rng) < 0.5 ? [0, 1] : [1, 0];
  for (const k of ord) control(S, S.fighters[k], inputs ? inputs[k] : null);
  for (const f of S.fighters) stepFighter(S, f, dt);
  dirUpdate(S, dt);
  beamStep(S, dt); stepParts(S, dt);
  if (S.game.clash){ /* prototype lines 892-897, spark() is cosmetic */ }
  if (S.fx.banner){ S.fx.banner.t += dt; if (S.fx.banner.t > S.fx.banner.dur) S.fx.banner = null; }
  S.fx.shake *= Math.pow(0.02, dt);
  return true;                                        // true: this tick consumed input (false during hit-stop)
}
```

The prototype's `camStep` did two unrelated things: it moved the camera (view) and decayed the shake (a cosmetic value the sim writes). The decay stays in the tick, at the same point; the camera follow moves to `core/view/camera.js`, which the host calls after each tick with `S.dt`. Nothing in the tick calls the view.

`control(S, f, intent)` is the prototype's `control(f)`: clear `f.in`; return if `S.game.ko`; if `f.ai` run `aiInput(S, f)`, else copy `intent` into `f.in` with `applyIntent` (a null intent leaves it neutral); then the stance switch, `lastAtkT` and the attack request, verbatim. `intentFromKeys` reproduces `humanInput`. The host clears its key-press set only after a tick that returns true (the prototype cleared `edges` only in ticks that ran `control`).

`newMatch(S, seed, ai)`:
- `seed` must be an integer, or it throws. The prototype picks `(Date.now() & 0xffffff) | 1` when no seed is given; that is the host's job now.
- `ai` is `{p1, p2}`, booleans. A missing entry keeps the previous fighter's setting (`!!S.fighters[k].ai`), or true if there are no fighters, as the prototype does.
- Then the prototype's `newMatch` body in order: seed, streams (`S.rng = createRng(S.game.seed)`, `S.rngFx = S.rng` while `opts.fxRng` is `'shared'`), `genWorld`, fighters, resets.
- It also resets `S.fx.shake = 0`, `S.out.feed.length = 0` and `S.dt = 0`. Section 7 has the reason for the shake reset.

`toggleAI(S, idx)`: `f.ai = f.ai ? null : {t:0.5, atk:1.2, sT:0, sOff:0}`.

## 6. Cosmetic random-draw sites (use S.rngFx)

- `spark`, `debris` (including the `rng() < 0.5` sign), `dust`, `splash`, `fire` (including the `rng() < 0.5` colour): every draw.
- `stepFighter`, charging: both `rng() < 0.4` (spawn a spark) and its four `R()` calls, and `rng() < 0.06` (dust).
- `sampleBeam`: the `rng() < 0.6` splash chance.

Every other draw is gameplay and uses `S.rng`, including `doLaunch`'s spin (the fighter's `spin` and `rot` are fighter state and QA hashes them). `ring`, `afterimage` and `P` draw nothing.

## 7. Deliberate differences from the prototype (none change behaviour)

| Difference | Why |
| :--- | :--- |
| `stanceOk` dropped from fighters, `last` dropped from exchanges | written, never read |
| `dPrev: null` initialised | explicit shape; same truthiness |
| Exchange beats are data ops | serialisable state, section 4 |
| `game.banner`, `parts`, `floats`, `cam.shake` moved into `S.fx` | presentation lane; gameplay never reads them |
| Camera x, y, z follow moved out of the tick | rendering reads sim state and never writes it |
| `feed()` writes `S.out.feed` instead of the DOM | output channel; the QA adapter formats it as `[T.toFixed(1) + 's', tag, sub]` |
| `newMatch` needs an explicit seed; AI flags are an argument | the clock and the UI belong to the host |
| `newMatch` resets `S.fx.shake` | the prototype carries `cam.shake` from one match into the next. It is cosmetic, but a seed alone should reproduce the whole state, so the parity harness zeroes `cam.shake` before each prototype match |

## 8. Where every prototype function goes

| Prototype | Port |
| :--- | :--- |
| `mulberry32`, `rng`, `R` | core/rng.js `createRng`, `next`, `range` |
| `clamp` | core/mathx.js |
| `DT`, `W`, `COL`, `NC`, `HALF` | core/constants.js |
| `wrap`, `sdx` | core/wrap.js |
| `SEG`, `biomeAt` | world/biomes.js |
| `base`, `deform`, `genWorld`, `groundY`, `seaAt`, `crater` | world/terrain.js |
| `curH`, `casualty`, `damageBuilding`, `damageArea`, `explode`, `popNear`, `nearestBuilding` | world/structures.js |
| `nearTree`, `coverAt`, `nearestCover` | world/cover.js |
| `ROSTER`, `mkF`, `opp` | core/roster.js (`mkF` becomes `createFighter`) |
| `STN` | director/exchange.js |
| `newMatch`, `step`, `toggleAI` | core/sim.js |
| `banner`, `P`, `spark`, `ring`, `debris`, `dust`, `splash`, `fire`, `afterimage`, `stepParts` | core/fx.js |
| `feed` | core/events.js |
| `hurt`, `hit`, `ko` | core/damage.js |
| `chooseLaunch`, `doLaunch` | director/launch.js |
| `newEx`, `B`, `requestAttack`, `openWindow`, `chain`, `endEx`, `dirUpdate` | director/exchange.js (`B` becomes `schedule`) |
| `planMelee`, `clashWave`, `strike`, `launchBeat` | director/melee.js |
| `planBeam`, `startClash`, `fireBeam`, `sampleBeam`, `beamStep` | director/beam.js |
| `updateHidden` | core/hiding.js |
| `tierUp`, `impact`, `stepLaunched`, `stepRush`, `stepFighter` | core/fighter.js |
| `KEYS`, `humanInput` | input/keyboard.js (`humanInput` becomes `intentFromKeys`) |
| `control` | input/control.js |
| `pickW`, `aiInput` | director/ai.js |
| `camStep` | core/view/camera.js (camera follow) and the tick (shake decay) |
| `hexA`, `BCOL`, `STS`, `w2s`, `rr`, `clouds`, `stars`, `draw*`, `bar`, `render` | not ported: rendering |
| `resize`, `syncButtons`, `takeOver`, key and pointer listeners, `frame`, `window.__wf` | not ported: host and UI. The fixed-step accumulator is described in overview.md |
