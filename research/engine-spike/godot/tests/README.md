# Godot sim port: GDScript sim, camera and reference checks

Engine spike for ADR 0001. This is throwaway research code, and nothing outside `research/` may import it. This README covers the three folders the sim-port agent owns:

| Path | What it holds |
|---|---|
| `godot/sim/` | GDScript port of `shared/sim-ref.mjs`: wrap math, mulberry32, terrain, fighters, scenes, state vectors and hashes |
| `godot/view/camera.gd` | GDScript port of `shared/camera-ref.mjs` |
| `godot/tests/` | `run_tests.gd` (the checks of `shared/test-ref.mjs`), `simbench.gd`, `microbench.gd` and this README |

The renderer, `project.godot`, the demo, bench mode and exports belong to the Godot render build. See its README.

## Result
The port is bit-exact. Every golden hash in `shared/golden.json` is reproduced, and all 6 camera seam tests pass with the same metrics as Node. The 22 PASS lines are byte-identical to the output of `node shared/test-ref.mjs`. This holds in both the editor binary and a release export template.

GDScript runs this sim about 24 times slower than V8 in the editor build and about 18 times slower in a release export. That is still only 0.04 to 0.06 % of a 60 Hz frame for this scene (details under Speed).

## How to run
Godot is not on PATH. Use the full path to `Godot_v4.7.2-stable_win64_console.exe`, which is the editor binary with a console. Run the commands from the repo root.

```
# once per fresh checkout (or if .godot/ looks corrupted: delete godot/.godot and import again)
Godot_v4.7.2-stable_win64_console.exe --headless --path research/engine-spike/godot --import

# goldens + camera tests; exit code 0 = all pass, 1 = any failure
Godot_v4.7.2-stable_win64_console.exe --headless --path research/engine-spike/godot -s res://tests/run_tests.gd
#   ... -- --bench                      also print a SIMBENCH line
#   ... -- --golden <abs golden.json>   read the goldens from a given file (exported builds cannot see ../shared)
#   ... -- --dump <scene|flight-input> <tick>
#        prints the state vector at that tick, one line per element: "index value float64-hex".
#        Diff it against the same vector from sim-ref.mjs to find the first diverging value.

# per-operation GDScript costs (smoke only)
Godot_v4.7.2-stable_win64_console.exe --headless --path research/engine-spike/godot -s res://tests/microbench.gd
```

`run_tests.gd` and `simbench.gd` load every dependency with `preload()`, not through a global `class_name`, so they also run when the class cache is stale or another agent is importing the project at the same time. The renderer can use the global names (`SpikeScenes`, `SpikeCamera` and so on) after an import.

## What passed (2026-09-29, smoke run on a shared machine)
Node reference: `node research/engine-spike/shared/test-ref.mjs --bench`, exit 0.
GDScript: `Godot_v4.7.2-stable_win64_console.exe --headless --path research/engine-spike/godot -s res://tests/run_tests.gd -- --bench`, exit 0:

```
PASS terrainBase c3a0b9144b0e7f2550710ff8d12e3330efb37ce63c9b5394067031198ee83f9a
PASS worst@600 89f74584951f0f370648e03ed01635d70aa568a40df5cb32f0fbb814f16858a5
PASS worst@1980 19a92e5cae133e412bfe48d09aef31bcd3453057c5d4542353aa97f2dd9f1dac
PASS worst@3600 463ca3deba0baad96dd9202f270a9bb6b7d43ec32d909c79182f8ebcf1ca19dc
PASS flight@600 43c587a678a1ab9bb32fca86da714ae793fd0564805298fc602f36b6a3dea622
PASS flight@1800 8745c90ad6ca5d2c5e7503cde6a46b1e4782d60c5a3e45d36a93ccaa1f58f4e4
PASS flight@3600 1e38eeae2ed0717cb48a2fa18c09122994c26a5ed69f229845248043bf3b562a
PASS flight-input@600 41f72fd0f924edcefbf79db7a09553662f788eee58e1b64ea1ac79622d7a89c4
PASS flight-input@1800 134e02d195abd79b62ecb862d19949978fdcd96383f1908afb897ca0544a90da
PASS flight-input@3600 907584896d3f2eac783941c5336dc482cf1b66505ef28bda27b8229a6e8e36ae
PASS camera.sweep@3600 fd570acbd7b083d8184db0ff9a751104b72ceceb68e782799b7e2d7c427c6b3e
PASS camera.chase@3600 a451a2c8321a98fb4e5f19f141e16ee4d71f09bc74c4cd4c868845c4a06febcd
PASS camera.orbit@3600 1b8858a28145b69f4a3f907b81c70da52b75f74609c206cce6c6751f3e28a3db
PASS camera.climb@3600 54954fb7ac2a26fc53206bff35bfd75f58963a861eed61e10fe6c8a4884bc1b7
PASS camera.flight@3600 b85e9e49b06eb292358c458ed0fdaa0c9e41ebc8ce540d557b19e3d79b1313e7
PASS camera.worst@3600 54e464968c8c103ba118ec539496d1908b65b10e7f815609bd5933b2151eaab2
PASS camera {"scene":"sweep","ticks":3600,"seamCrossings":19,"flips":19,"flipTicks":741,"outOfFrameTicks":0,"outOfFrameDuringFlip":570,"maxScreenJump":0.01796,"maxSeamOffsetDiff":5.10702591327572e-15,"pass":true}
PASS camera {"scene":"chase","ticks":3600,"seamCrossings":17,"flips":1,"flipTicks":28,"outOfFrameTicks":0,"outOfFrameDuringFlip":26,"maxScreenJump":0.01233,"maxSeamOffsetDiff":7.882583474838611e-15,"pass":true}
PASS camera {"scene":"orbit","ticks":3600,"seamCrossings":4,"flips":0,"flipTicks":0,"outOfFrameTicks":0,"outOfFrameDuringFlip":0,"maxScreenJump":0.00113,"maxSeamOffsetDiff":2.886579864025407e-15,"pass":true}
PASS camera {"scene":"climb","ticks":3600,"seamCrossings":6,"flips":0,"flipTicks":0,"outOfFrameTicks":0,"outOfFrameDuringFlip":0,"maxScreenJump":0.00808,"maxSeamOffsetDiff":5.10702591327572e-15,"pass":true}
PASS camera {"scene":"flight","ticks":3600,"seamCrossings":20,"flips":3,"flipTicks":111,"outOfFrameTicks":0,"outOfFrameDuringFlip":89,"maxScreenJump":0.01705,"maxSeamOffsetDiff":7.882583474838611e-15,"pass":true}
PASS camera {"scene":"worst","ticks":3600,"seamCrossings":7,"flips":0,"flipTicks":0,"outOfFrameTicks":0,"outOfFrameDuringFlip":0,"maxScreenJump":0.00682,"maxSeamOffsetDiff":3.219646771412954e-15,"pass":true}
SIMBENCH {"stack":"godot 4.7.2-stable (official) gdscript editor debug","reps":5,"ticks":3600,"terrainGenMs":4.22,"worstTickUs":9.206}
all reference checks passed
```

`diff` of the PASS/FAIL lines against the Node output is empty. The camera metrics, including `maxSeamOffsetDiff` to the last digit, are the same because the floats are identical.

Other checks:
- **Dump against Node.** `--dump flight-input 1800` (1210 values, printed as value and float64 hex, plus the hash) is identical to the same vector printed by `sim-ref.mjs`.
- **Release export template.** The same scripts were exported with `windows_release_x86_64.exe` (binary-token GDScript and the release VM) and run from a scratch copy outside the repo (recipe below). All 22 PASS lines were identical, exit code 0, with this SIMBENCH line: `{"stack":"godot 4.7.2-stable (official) gdscript template release","reps":5,"ticks":3600,"terrainGenMs":3.098,"worstTickUs":6.719}`.
- **Static check.** `sim/` and `view/` use no Vector2, Vector3, sin, cos, pow, exp, log, sqrt or lerp. They use only `float` (float64) scalars, `int`, `PackedFloat64Array`, `fmod`, `floorf`/`floori`/`ceili` and `+ - * /`.

## API (fixed, shared with the Godot renderer)
All classes extend RefCounted except `run_tests.gd`, which extends SceneTree.

| File | Class | Contents |
|---|---|---|
| `sim/wrap.gd` | `SpikeWrap` | `W, COL, NC, HALF, TPS, DT`; static `wrapx`, `sdx`, `clampf_`, `tri` |
| `sim/rng.gd` | `SpikeRng` | `_init(seed)`, `u32()`, `next()`, `range_(lo, hi)`, `state()`; also static `imul(x, y)` |
| `sim/terrain.gd` | `SpikeTerrain` | `base`, `deform` (PackedFloat64Array), `version`; `height`, `is_sea`, `ground_y`, `crater`; static `gen_terrain`, `biome_at`; `BIOME_*`, `BIOME_NAMES`, `SEG`, `TERRAIN_SEED`, `DEFORM_MIN`, `SEA_BASE` |
| `sim/fighter.gd` | `SpikeFighter` | `x, y, vx, vy, tvx, tvy` (float) |
| `sim/scenes.gd` | `SpikeScenes` | static `make_scene(name, seed = -1)`. Inner classes `Scene` (the common base), `WorstScene`, `FlightScene` and `ScriptScene`, each with `name, tick, terrain, a, b, beams, events, rng, step(), set_input(ix, iy)` |
| `sim/state_hash.gd` | `SpikeHash` | static `state_vector`, `base_vector`, `sha256_hex`, `golden()`, `WORST_1980`; also `camera_vector` (used by the camera goldens) |
| `view/camera.gd` | `SpikeCamera` | `x, y, view_w, d, o, ax, flips, flipping, ready`; `reset`, `step`, `view_h`, `screen_x`, `screen_y`, `distance`; the CAM table as typed constants (`MARGIN_X` ... `TAN_HALF_HFOV`) and as the `CAM` Dictionary |
| `tests/simbench.gd` | `SpikeSimbench` | static `run(reps = 5, ticks = 3600)` returns `{stack, reps, ticks, terrainGenMs, worstTickUs}` |

About `beams` and `events`: `beams` is `Array[Dictionary]` holding `{sx, sy, tx, ty, owner}` and is updated in place every tick. `events` is `Array[Dictionary]` holding `{kind, x, y, r}` and is cleared at the start of every `step()`. Renderers read both and never write them.

`SpikeHash.golden()` reads `ProjectSettings.globalize_path("res://")/../shared/golden.json` with `FileAccess` on the absolute path. In an exported build that path does not exist, so it returns `{"embedded": true, "worst": {"1980": WORST_1980}}`.

## Determinism in GDScript: what matters

### Float behaviour
- **Scalars and vectors.** GDScript `float` is IEEE float64. `Vector2`, `Vector3`, `Color` and `PackedFloat32Array` are float32 in the standard build, so they are never used in the sim or the camera. Any sim value that passed through a Vector2 would lose about 29 bits.
- **No fusing or reordering.** Each GDScript operator runs as its own VM instruction, so nothing fuses (FMA) or reassociates across operators. Keeping the JS order of operations was enough. On x86-64 the engine uses SSE2 (no x87 extended precision).
- **Constant folding is safe.** The analyser folds constant expressions (`1.0 / 60.0`, `16.0 / 9.0`) in float64 with IEEE rounding, which gives the same double as JS `1 / 60`.
- **Safe operations.** `+ - * /`, comparisons, `fmod` (exact by definition in IEEE), `floorf`/`floori`/`ceili` (exact), `absf`, unary minus and `float(int)` for ints below 2^53. The sim uses nothing else.
- **Engine helpers whose semantics differ.**
  - `clampf`, `minf` and `maxf` treat NaN and -0 differently from JS ternaries, so the sim uses the JS form (`SpikeWrap.clampf_`).
  - `wrapf` and `fposmod` are not the JS formula: for x = -1e-14, `fposmod(x, W)` adds W and returns 9600.0, while JS `((x % W) + W) % W` returns 0. `snappedf` is floor-based, not `toFixed`.
  - `lerp` has the same formula as the JS `a + (b - a) * s`, but it is engine C++, which a compiler may contract into an FMA on some targets (for example clang on arm64). The sim writes the formula out in GDScript instead.
  - sin, cos, pow, exp and log call the platform libm, which differs between platforms (the reference sim bans them).
- **Hashing.** `PackedFloat64Array.to_byte_array()` copies the raw memory, which is little-endian on every target Godot ships (x86-64, arm64, wasm32). `HashingContext` SHA-256 then matches Node's `crypto` byte for byte.

### Int and float traps (each is a silent wrong answer, not an error)
1. **`int / int` truncates.** JS `i / per`, `(n % period) / period` and `k * COL / r` are float divisions. Convert first: `float(i) / float(per)`, `float(n % period) / float(period)`, `float(k * COL) / r`. The int product is exact, so converting after the multiply matches JS.
2. **`%` is not defined for floats in GDScript.** With typed operands it is a parse error: `Invalid operands "float" and "float" for "%" operator` (checked in 4.7.2). Use `fmod(a, b)`, which has JS semantics (the sign of the dividend). JS `((x % W) + W) % W` becomes `fmod(fmod(x, W) + W, W)`. `fposmod` is different.
3. **`int % int` truncates toward zero, as in JS.** It is safe for the sim's non-negative tick counts and column indices. For negative operands, add `NC` first, as the JS does.
4. **`Math.floor(n / 120)` becomes `floori(float(n) / 120.0)`.** Integer division `n / 120` gives the same result for n >= 0, but the explicit form follows the reference.
5. **GDScript `int` is 64-bit signed.** JS `| 0`, `>>> 0` and `Math.imul` have no direct equivalent:
   - Keep the RNG state unsigned in `[0, 2^32)` by masking every result with `& 0xFFFFFFFF`. On a non-negative int64, `>>` then equals JS `>>>`.
   - Build `imul` from 16-bit halves so that no product exceeds 2^49 (no int64 overflow): `(a * (b & 0xFFFF) + (((a * (b >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF`.
   - JS `(t + imul(...)) | 0` becomes `(t + m) & 0xFFFFFFFF`, which has the same low 32 bits.
6. **Name clashes with built-ins.** `wrap()` and `range()` are built-in names, hence `wrapx` and `range_`. A function named `wrap` would shadow the built-in with no error at the call site.
7. **Int literals in float context.** `var x: float = 2400 + 10 * n` computes the int sum first, then converts it. That is exact here, but write float math with float literals (`150.0 + 750.0 * tri(...)`) so that no int division sneaks in.
8. **Untyped Dictionary values are Variants.** `bm["tx"]` holds a float, but reading it into an untyped `var` loses static typing and speed. The sim reads it into a typed local (`var tx: float = bm["tx"]`).

### Printing floats (this affects only test output, never the hashes)
- **`str()`, `print(float)` and `JSON.stringify`** print about 14 significant digits. They are not round-trip safe, so never use them to compare states. Use hashes or the float64 hex in `--dump`.
- **`String.num_scientific()`** gives round-trip digits, but not always the shortest. It printed `-30.624960823896622` where JS prints `-30.62496082389662`.
- **`String.to_float()` is not correctly rounded.** It parsed `7.88258347483861e-15` to the double that JS prints as `7.882583474838611e-15`, so it cannot be used to check a round-trip.
- **`js_num()` in `run_tests.gd`** reproduces JS `Number#toString`. It trims the num_scientific digits to the shortest candidate that converts back exactly, using the exact fast path (an integer below 2^53 times or divided by a power of ten up to 1e22). It matches Node on 31 edge values and on all 1210 values of the dump. For values that need more than 22 decimal places (for example `7.882583474838611e-15`), it keeps the num_scientific digits, which can be one digit longer than JS. None of the printed metrics hit this: all of them matched Node.
- **`snappedf(x, 0.001)`** leaves values like `4.1850000000000005`. `SpikeSimbench` rounds through `String.num(x, 3)`, like JS `+x.toFixed(3)`.

### What was verified, and what was not
- **Verified on Windows x86-64:** the editor binary (debug VM) and the release export template (release VM, binary-token scripts) give identical hashes at every checkpoint. The replay golden (`flight-input`, box a flown by a scripted input stream) reproduces, so input replay is deterministic.
- **Not verified here:** the Godot web export (wasm) and arm64 (Android, Apple). Nothing in the port depends on the platform: no libm, no float32 and no fused operators across GDScript instructions. The Godot render build's bench mode hashes the worst scene at tick 1980 against `WORST_1980`, so its web-export run is the cross-platform evidence. Nobody has run on arm64 yet.

## Speed (smoke numbers only; other sessions shared this machine; not final)
Ryzen 7 9800X3D, Windows 11, Godot 4.7.2 official, Node 24.19.0. The median of 5 runs of 3600 worst-scene ticks, plus the median of 5 terrain generations:

| Stack | worstTickUs | terrainGenMs | Ratio to V8 (tick / terrain) |
|---|---|---|---|
| Node 24.19 (V8), `test-ref.mjs --bench` | 0.38 | 0.171 | 1 |
| GDScript, editor binary (debug VM), 3 runs | 9.315 / 9.2 / 9.206 | 4.185 / 4.259 / 4.22 | about 24x / 25x |
| GDScript, release export template, 1 run | 6.719 | 3.098 | about 18x / 18x |

What this means for the ADR:
- **This scene is cheap.** One worst tick in the GDScript release VM is about 7 µs, which is 0.04 % of a 16.7 ms frame. The spike's sim cost does not separate the stacks.
- **The real sim will be much heavier.** It adds the director, the launch planner, about 425 civilians and structures, and later rollback that re-simulates several ticks per frame. At about 18x V8 (and slower again on old laptops and in wasm, which was not measured), a real sim tick costing 50 µs in V8 would cost about 1 ms in GDScript. Eight rollback re-simulations per frame would then take about 8 ms of the 16.7 ms budget. This is an extrapolation, not a measurement. It suggests that the real sim core should not be GDScript if rollback is wanted: it would belong in C#, C++ (GDExtension) or another compiled language, and the export story of that language on web and mobile then becomes decisive.
- **Headless QA batches.** The P0 exit criterion of 1000 matches, run on this sim in GDScript, would take about 18 times the wall time of Node.

Where the time goes (`microbench.gd`, ns per operation with loop overhead subtracted; single runs):

| Operation | Editor (debug VM) | Release template |
|---|---|---|
| empty typed `for` iteration | 3.0 | 2.2 |
| float mul + add, typed locals | 6.0 | 5.9 |
| imul-style int mask/shift expression | 19.0 | 19.4 |
| `fmod()` utility call | 16.2 | 16.9 |
| `floori()` utility call | 9.0 | 7.8 |
| static func call, same script | 72.8 | 34.5 |
| method call on self | 87.9 | 39.0 |
| static call through a preloaded script (`_Wrap.wrapx`) | 102.6 | 69.2 |
| typed method call `terrain.ground_y()` | 212.0 | 161.2 |
| typed object field read + write (`f.x = f.x + 1.0`) | 27.9 | 28.6 |
| `PackedFloat64Array` get + set | 17.3 | 17.4 |
| Dictionary set, String key | 23.0 | 20.2 |
| Dictionary literal (4 keys) + append | 439.1 | 362.8 |
| `rng.next()` (mulberry32) | 314.7 | 192.9 |

Lessons from these numbers:
- **Calls dominate.** A GDScript function call costs 35 to 100 ns, while V8 inlines them for close to nothing. The release VM halves call overhead but not arithmetic.
- **Inline the hot helpers.** The port inlines `wrap` inside `terrain.gd` and builds `imul` inline in `u32()`, which is why it has local copies of the constants.
- **Avoid allocating.** Dictionary literals (events) and the RNG are the most expensive per use. A real GDScript sim would use typed objects or packed arrays for events, or a precomputed RNG buffer.
- **Typed code throughout.** Every sim file is fully typed. Untyped Variant code was not measured here.

## Export notes (found while building the release measurement)
- **`-s` is ignored in release templates.** With `--headless -s res://...`, the 4.7.2 Windows release template silently ignores the flag: even a three-line script never ran, and the process idled until killed.
- **Workaround.** Set `application/run/main_loop_type` to a global `class_name` that extends SceneTree (a one-line subclass of `run_tests.gd`), and give the project a main scene (the template refuses to start without one: "no main scene defined"). The main-loop script's `_init()` then runs the checks and `quit(code)` sets the process exit code.
- **Scratch recipe.** It lives outside the repo, in the session scratchpad:
  1. Copy `sim/`, `view/` and `tests/` into a scratch project.
  2. Add a minimal `project.godot` with `run/main_loop_type="SpikeRelRunner"`, `run/main_scene` set to an empty scene and `run/flush_stdout_on_print=true`.
  3. Add an `export_presets.cfg` for "Windows Desktop" with `export_filter="all_resources"`, `debug/export_console_wrapper=2` and `application/modify_resources=false` (so rcedit is not needed).
  4. Run `--import`, then `--export-release "Windows Desktop" <out>/simport.exe`, then `simport.console.exe --headless -- --bench --golden <abs golden.json>`.

  The export is a 109 MB exe (the stock template) plus a 33 KB pck.
- **Stdout from release builds.** Output is block-buffered when redirected unless `application/run/flush_stdout_on_print` is on (it defaults to on only in debug builds), so a killed release process loses its output.

## Known gaps
- **Web and arm64 determinism.** The GDScript sim has not been checked in a web (wasm) or arm64 build. The Godot render build's web bench compares the tick-1980 hash, which covers wasm. arm64 is untested.
- **Web and old-laptop speed.** GDScript sim speed in the web export and on the integrated GPU laptop stand-in was not measured separately. The render build's `subMs.sim` in its bench JSON gives the web figure.
- **Numbers are smoke only.** Every speed number was taken while other agents shared the machine. The Research director makes the final timed runs.
- **The fixed API is fully typed only where Godot allows it.** `state_vector(scene)` and `camera.reset(a, b)` / `step(a, b)` take untyped parameters, so that they accept any scene or any object with `x`/`y`, such as the shifted copies in the seam test. The tests pass `SpikeFighter` everywhere.
