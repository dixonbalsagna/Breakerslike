# Determinism: risks, mitigations and a recommendation for ADR 0001

Owner: Simulation and Engine. Inputs: the reference core in `sim/` (a tick-exact port of the prototype at 7233c96), QA's harness, Research's engine spike plan (`research/engine-spike/PLAN.md`) and Orb's answers in `docs/ep/vision.md`. Every claim marked **(verify)** is from memory rather than a source checked tonight. Research's cross-language golden tests are the arbiter for those.

## 1. What we need

Bit-identical simulation state, tick by tick, for:
- **Replays.** Seed plus intents gives the same match on any machine. Implemented and tested for the JS core (`sim/core/replay.js`).
- **Rollback online.** Both peers resimulate from the same state and must agree to the bit. Orb has put online play after launch, so this is not a launch blocker, but the sim must be designed so it stays possible.
- **The parity oracle.** Every engine port must reproduce the reference core's per-tick hashes, and the reference core reproduces the prototype.

It breaks when two runs:
- round differently: extended precision, FMA contraction, float32 against float64, a different library `sin` or `pow`;
- evaluate in a different order: reassociated arithmetic, hash-map iteration, threads;
- read something outside the sim: the clock, `Math.random`, frame time, the viewport.

## 2. Inventory: the float operations the simulation uses

| Operation | Where (gameplay unless noted) | Deterministic across platforms? |
| :--- | :--- | :--- |
| `+ - * /`, comparisons | everywhere | Yes, under IEEE 754 binary64 with round-to-nearest, no FMA contraction and no extended precision. JS guarantees this. C# on x64/ARM64 does in practice **(verify: the JIT contraction policy)**. GDScript scalars are C++ doubles, so it depends on how the engine binary was compiled **(verify per platform)**. |
| `Math.sqrt` | not called directly; inside `hypot` | Yes, in practice: IEEE 754 requires a correctly rounded square root. |
| `floor`, `ceil`, `abs`, `sign`, `min`, `max`, `round` | indices, clamps, feed text | Yes. `round` in JS rounds half toward +infinity; other languages' default `round` differs (C# uses banker's rounding by default), so a port must copy JS semantics. |
| `%` on doubles | `wrap`, `sdx`, world generation | Yes: exact (fmod semantics). |
| `Math.imul`, `>>>`, `\|0` | mulberry32 | Yes, if the port emulates 32-bit wrap. GDScript ints are 64-bit and need masking; C# uses `uint`. |
| Float32 storage (`Float32Array`) | `base`, `deform`, the world-generation buffer | Yes: storing rounds to float32 exactly. A port must store float32 and read it back as float64 at the same points. |
| `Math.sin` | world generation (every column, once per match); `aiInput` evasive stance, every tick | **No.** Library-defined. |
| `Math.cos` | crater falloff (gameplay); particle directions (cosmetic) | **No.** |
| `Math.pow` | per-tick decays `k^dt` (`0.55, 0.05, 0.1, 0.001, 0.0008, 0.03`; shake `0.02`); `pow(1 - hp/maxhp, 2)` in `hit()` | **No** in general. With dt fixed (DT or DT x 0.35) every `k^dt` is a constant that can be precomputed once as a literal. `pow(x, 2)` can become `x*x`. |
| `Math.hypot` | beam aim, launched speed, impact speed, the hiding speed check | **No.** Implementations scale differently. `sqrt(x*x + y*y)` is deterministic but gives different bits, so switching is a deliberate change. |
| `Math.PI` | crater falloff, world generation | Yes (a constant). |

The whole deterministic-risk surface is therefore four library functions (sin, cos, pow, hypot) at about a dozen call sites, plus the integer RNG.

## 3. Hazards specific to this core

1. **Hit-stop and slow motion are float-second timers.** Hit-stop (`dirS.stop`) counts down by real `DT` while the tick is frozen, and after a KO the tick's dt is `DT * game.ts` (0.35). So `T` and every timer advance by non-integer multiples of DT. Parity keeps this, and it is deterministic, but `T` accumulates rounding error (for example 1.949999999999998 at tick 117), and every port must accumulate it identically, in the same order. Netcode's contract will require integer ticks in sim state. The change: an integer tick counter; hit-stop and slow motion as tick counts, with slow motion as a fixed tick-skip pattern; timers held as tick deadlines. It changes behaviour, so it lands as a deliberate change with new goldens, like QA-002.
2. **`wrap()` rounds values that are already in range.** `((x % W) + W) % W` adds W before the second `%`, so a non-integer x in [0, W) can come back with different last bits (6797.300000000001 becomes 6797.300000000003). Every position update goes through it. A port that writes the obvious conditional wrap (`x < 0 ? x + W : x`) will diverge. Ports must copy the formula exactly (see the test in `sim/core/test/wrap.test.js`).
3. **Evaluation order is behaviour.** Object-literal property order, short-circuit conditions and argument order decide the random-draw order (module-spec section 1). A port that reorders a literal changes the match.
4. **Slot order.** Slot 0 always simulates before slot 1 within a tick. This is deterministic, but it creates a small first-mover asymmetry (QA's mirror-match slot deficit) that any port must preserve until Game Design decides otherwise.
5. **Cosmetics on the sim stream (QA-002).** Resolved: effects are events now, and cosmetic randomness lives in per-consumer streams (fx-events.md).
6. **`-0` and NaN.** The sim can produce -0. Snapshot and transport formats must preserve it (overview.md section 4).

## 4. Per language

**JavaScript (the reference core).** The basic arithmetic is IEEE binary64 by specification, with no contraction. The ECMAScript spec leaves `sin`, `cos`, `pow` and `hypot` "implementation-approximated". V8 computes sin and cos with its own fdlibm port, so results match across platforms for a given V8 version **(verify for `pow` and `hypot`)**. Node majors can change V8, which is why QA pins the goldens to Node 24 (QA-005). Other browser engines (SpiderMonkey, JavaScriptCore) use other implementations **(verify)**, so a browser build is only bit-compatible with Node/V8 if the four functions are replaced by our own.

**GDScript (Godot 4).**
- `float` is a 64-bit double. The engine vector types (`Vector2`, `Vector3`) use 32-bit `real_t` unless Godot is built with double precision. So the sim must keep its state in scalars or packed float64 arrays, not engine vectors.
- The math built-ins call the platform C library **(verify)**, so sin, cos, pow and hypot need our own implementations there too.
- Ints are 64-bit, so mulberry32 needs `& 0xFFFFFFFF` and a signed 32-bit conversion. Research's spike plans exactly this (imul with 16-bit halves).
- Risks: the rounding behaviour of each platform's engine build (FMA contraction by the C++ compiler, for example on ARM mobile) **(verify)**, and interpreter speed on old laptops and phones, which only matters once rollback resimulates several ticks per frame.
- Web export works for GDScript projects.

**C# (Godot .NET).**
- IEEE doubles. The JIT on x64 and ARM64 does not contract to FMA unless asked **(verify)**.
- `Math.Sin` and the others call the platform C runtime **(verify)**, so we would need our own implementations.
- `uint` arithmetic gives mulberry32 directly.
- Good test tooling.
- The blocker for us: Godot 4 C# projects could not be exported to the web in the releases known to me **(verify for 4.7; Research's spike checks it)**. Orb lists the browser as a platform.

## 5. Fixed-point

Represent sim quantities as scaled integers, for example Q32.32 in int64 or Q16.16 in int32 with 64-bit intermediates.
- **Buys:** determinism by construction in every language and compiler.
- **Costs here:**
  - Range analysis for every quantity: positions to 9600, velocities to about 3000, launch forces to about 3850, HP 1600, multipliers.
  - A rewrite of every expression.
  - sqrt, sin, cos and pow rebuilt as tables or integer algorithms.
  - In JavaScript, no fast 64-bit integers: BigInt is slow, so we would need 32-bit limb arithmetic.
  - The loss of parity with the prototype and of the current balance baseline.
- It is the fallback if a target cannot guarantee IEEE binary64 behaviour.

## 6. Deterministic float (the alternative)

- binary64 only.
- The basic IEEE operations and sqrt only.
- Our own sin, cos, pow and hypot, written from basic operations with one algorithm ported identically to every language.
- Decay constants for the fixed dt precomputed as literals.
- No FMA contraction.
- float32 only where it is deliberate storage (the terrain), rounded at the same points.
- Integer tick timers (hazard 1).
- Per-consumer cosmetic streams (QA-002).
- Golden per-tick hashes from the JS core as cross-language test vectors.

**Cost:** one small math module per language (about 100 lines each), and one deliberate re-baseline of the goldens when the JS core adopts it. **Risk:** a platform compiler that contracts or uses extended precision behind our back. The cross-language golden tests catch that on the first run of each platform build.

## 7. Recommendation for ADR 0001 (simulation's view)

1. **Deterministic float, not fixed-point.** Fixed-point stays the documented fallback.
2. **Keep the simulation engine-agnostic behind the tick contract**, and keep this JS core as the parity oracle and the source of golden vectors. Before the port starts, the JS core should adopt the deterministic math, integer tick timers and the cosmetic split, so the goldens the port targets are platform-independent.
3. **Language by engine option:**
   - **Godot with GDScript:** viable. It meets the browser target and keeps one language. Gate it on Research's spike measuring the GDScript tick cost on the old-laptop proxy (the iGPU machine), because rollback later multiplies it.
   - **Godot with C#:** not for the sim while C# web export is unavailable, because the browser is a platform. Revisit if the spike shows 4.7 can export it.
   - **A native sim library shared by Godot and the web (for example compiled to WASM):** the strongest determinism story, but a heavier toolchain. Consider it only if GDScript fails the speed gate.
   - **Web stack (TypeScript):** the lowest porting cost, since this core becomes the production sim. It carries the weakest native, mobile and console story.
4. **What would change this:** rollback moving back to a launch requirement (it raises the speed bar); Research's numbers; or Orb dropping the browser platform (it reopens C#).

## 8. Measured cost of the reference core

Node v24.19.0, on the machine in Research's plan (Ryzen 7 9800X3D). The 1000-match AI-vs-AI soak through QA's runMatch with every rule check on:
- **Port:** 4,199,920 ticks in 11.8-12.9 s, about 2.8-3.1 µs per tick including QA's checks.
- **Prototype:** 2.7 µs per tick on the same seeds.
- The port costs about 1.13 times the prototype: state is passed explicitly and beats are dispatched as data.

At 60 ticks per second one tick takes under 0.02% of a frame, so the JS sim is far inside any budget, rollback included. Particles are the one unbounded cost (up to 2400) and belong to the cosmetic lane.

**GDScript core (Godot 4.7.2 editor binary, headless; 10 AI matches, about 47,800 ticks).** It matches the det-mode JS core bit for bit (`sim/core/tools/parity.gd`). The sim tick is `step()` alone; the reference cosmetic consumer and the camera follow are render-side work and are timed apart.

| | mean | p50 | p99 | worst tick |
| :--- | :--- | :--- | :--- | :--- |
| GDScript sim tick before the QA-002 split (particles inside the sim) | 85 µs | 45 µs | 0.81 ms | 2.1 ms |
| **GDScript sim tick after the split** | **35 µs** | 33 µs | **0.15 ms** | **0.55-0.62 ms** |
| Reference cosmetic consumer and camera (render side, CPU particles) | 45 µs | 15 µs | 0.61 ms | 1.7 ms |
| JS det tick, this machine | 2.8 µs | 1.1 µs | 24 µs | 0.65 ms |
| **Projected old laptop, sim tick after the split** (2.6 to 3.9 times slower single-threaded, Research's PassMark ratios) | 0.09-0.14 ms | | 0.39-0.60 ms | 1.4-2.4 ms |

After the split, the sim tick fits comfortably on the projected old laptop: 0.1 ms is under 1% of a 16.7 ms frame, and even the worst tick uses about 15%. The cosmetic cost moved to the render side, where the real renderer will likely use GPU particles rather than this CPU reference consumer. Rollback (after launch) would multiply the sim tick by the number of resimulated frames. At 8 frames that is about 0.7-1.1 ms on average on the projected old laptop, inside the 1 to 3 ms that ADR 0001 names as its revisit trigger.

These are projections from a desktop, not measurements on old hardware, and the editor binary is somewhat slower than a release export. Rollback (after launch) multiplies the tick by the number of resimulated frames, which is the trigger ADR 0001 names for revisiting the language.

## 9. Netcode requests

Pending. The EP will forward Netcode's `simulation-port-requests.md`. Declined requests will be recorded here with the reason.
