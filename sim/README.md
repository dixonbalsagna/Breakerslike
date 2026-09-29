# sim: the reference simulation core

A headless, deterministic port of `prototype/index.html` (pinned at commit 7233c96): plain JavaScript ES modules, no DOM, Node built-ins only, no install step. It reproduces the prototype tick for tick and is the parity oracle for the engine port. Architecture: `docs/architecture/overview.md`. Interfaces: `docs/architecture/module-spec.md`. Determinism: `docs/architecture/determinism.md`.

## Run

| Command (from the repo root) | What it does | Time |
| :--- | :--- | :--- |
| `npm test --prefix sim` | everything below; exits 0 only if all pass (the CI entry point) | about 2 min |
| `node sim/core/tools/run-all.js --quick` | the same with the quick parity plan and a 100-match soak | about 25 s |
| `node sim/core/tools/parity.js` | parity with the prototype (probe, per-tick lockstep, keyboard lockstep, QA records, golden hashes) | about 80 s |
| `node sim/core/tools/soak.js 1000 [--compare]` | 1000 AI-vs-AI matches with QA's rule checks, timed | about 12 s |
| `npm run unit --prefix sim` | node:test unit and integration tests only | about 10 s |
| `godot --headless --path . --import` then `godot --headless --path . --script res://sim/core/tools/parity.gd` | GDScript parity: the GDScript core reproduces every golden vector of the JS core (math, RNG, world, 17 AI matches, 2 human-input replays), and prints its tick cost. The import pass registers the `class_name` scripts on a fresh clone. | about 20 s |
| `node sim/core/tools/golden.js` | rewrites `core/test/golden-gd.json` from the JS core after an intended change (`--check` only verifies it) | about 5 s |

Use Node 24. The golden hashes were recorded on Node 24.19.0 and are skipped on other majors (QA-005).

## Layout and owners

| Path | Contents | Owner |
| :--- | :--- | :--- |
| `core/` | state, tick, fighters, damage, hiding, RNG, wrap math, cosmetic lane, hash, replay, view camera; `tools/` parity and soak; `test/` | Simulation and Engine |
| `world/` | `biomes.js`, `terrain.js`, `structures.js`, `cover.js` | World and Environment |
| `director/` | `exchange.js`, `melee.js`, `beam.js`, `launch.js`, `ai.js` | Encounter Systems |
| `input/` | `intent.js`, `keyboard.js`, `control.js` | Controls and Game Feel |

Rules for everyone changing `sim/`: behaviour changes are deliberate (parity then breaks by design; say so and regenerate the goldens); arithmetic and random-draw order are behaviour; the tick never calls view code; gameplay never reads `S.fx`; no `Math.random`, no clock.

## Two cores: JavaScript and GDScript

Every `.gd` file sits beside its JavaScript twin and keeps the same function and field names (ADR 0001: Godot 4.7 with GDScript). The JS core has two math modes, set with `createSim({math})`:
- `'native'` (the default) uses `Math.sin` and friends and matches the prototype;
- `'det'` uses `core/detmath.js` and matches the GDScript core bit for bit.
In det mode, matches play out the same as in native mode over 1000 seeds (same lengths and outcomes); only the last bits of floats differ. Change both twins together, regenerate the goldens with `node sim/core/tools/golden.js`, and run both parity checks.

GDScript traps that break bit-identity (each one was hit while porting):
- **Long float literals.** GDScript's parser is not correctly rounded for them: `0.017453292519943295` parses 2 ulp off, and the smallest normal double parses as 0. Build long constants from bit patterns (`SimMathx.f64`). The parity check compiles every float literal in the `.gd` files and compares its bits.
- **JS-exact helpers.** `sign(-0.0)`, `max`/`min` with signed zeros, and `round()` on halves all differ from JS. Use `SimMathx.jsign`, `jmax`, `jmin`, `jround` and `jclamp`, `SimDamage.jor` for JS `x || y`, and `SimMathx.jstr` for numbers in text.
- **Unqualified built-in names.** Inside a class, a bare `exp()`, `log()` or `sin()` calls Godot's built-in, not the class's own function. Always write `SimDetMath.sin(...)`.
- **Integer division.** `7/2` is 3. Every sim number is a float: write `2.0`, `60.0`.
- **The literal `-0.0`** folds to +0.
- **Unstable sort.** `sort_custom` is not stable. Beats and launch candidates use explicit stable insertion, as the JS stable sort does.
- **Native class names.** An inner class may not reuse one (`Tree` is taken, hence `TreeState`), and `in` is a keyword, so the fighter's intent is `f.input`.

## Prototype bugs and quirks, replicated rather than fixed

| # | Where | What | Impact |
| :--- | :--- | :--- | :--- |
| 1 | `world/structures.js` `casualty` | QA-003: anguish goes only to the first hero in the fighter list. | None with one hero; wrong in a hero mirror and with more fighters. |
| 2 | `core/sim.js` `step` | QA-002: cosmetic effects draw from the gameplay stream. | Any VFX change rewrites gameplay. Fix held (the per-consumer streams in overview.md section 3). |
| 3 | `core/fighter.js`, `input/control.js` | A human can switch stance at any time, including while locked in an exchange that was planned against the old stance, and `hit()` applies the stance at hit time (0.38x in defensive). The AI only switches when free. | A human can plan-dodge damage mid-exchange. Game Design and Controls should rule. |
| 4 | `core/damage.js` `hurt` | HP keeps falling after the KO: impacts after the KO call `hurt` again (matches end at about -10 to -90 HP). | Cosmetic today (the bar clamps); wrong for stats that read final HP. |
| 5 | prototype `newMatch` | `cam.shake` carries from one match into the next. | Cosmetic. The port resets it and the parity harness zeroes it (module-spec section 7). |
| 6 | `core/fx.js` `P` | The particle cap check is `> 2400`, so 2401 particles fit. | Trivial. |
| 7 | `world/terrain.js` `crater` | `world.craters` counts every beam-sample crater (one per 36 units of a low beam). | The "craters" statistic is inflated. |
| 8 | `director/beam.js` `beamStep` | Beam samples restart at each tick's start position instead of continuing the 36-unit grid. | Uneven damage density along a beam. |
| 9 | `core/fighter.js` `stepLaunched` | Leaving the launched state through water keeps `launchBy` and `bounces`. | Harmless (the next launch resets them). |
| 10 | `director/ai.js` `aiInput` | AI timers count down by the real `DT` even in the slow motion after a KO. | Minor. |
| 11 | `core/sim.js` `step` | Slot 0 always simulates before slot 1 within a tick. | A small first-mover asymmetry (QA's mirror-match slot deficit). |
| 12 | `core/wrap.js` `wrap` | Adding W before the second `%` changes the last bits of in-range non-integers. | None for parity, but every engine port must copy the exact formula. |
| 13 | dead state | `stanceOk` (write-only) and `ex.last` (never read) were dropped. `tree.burn` and `crater`'s `cause` parameter are unused and were kept. | None. |

## Hard-coded for two fighters

Vision: 4 fighters with transformations and AI minions. These assume exactly two:
- `core/roster.js` `opp(S, f)` returns "the other fighter". Callers: `requestAttack` (the defender), `aiInput` (the target), `updateHidden` (the distance to the hunter), `stepFighter` (facing), and the fallbacks `hurt`, `impact` and `stepLaunched` use for who gets the credit.
- `S.dirS.ex` holds one exchange for the whole match, and `dirS.cool` and the launch-variety history are global. Minions need concurrent exchanges, each with its own cooldown.
- `S.game.ko` is a single KO that ends the match, and `S.game.clash` is a single beam clash.
- `core/sim.js`: `newMatch` spawns `ROSTER[0]` and `ROSTER[1]` into slots `p1` and `p2`, and the control order is one coin flip between `[0, 1]` and `[1, 0]`. N fighters need a seeded shuffle, which changes the draw count, so it is a behaviour change.
- `core/view/camera.js` frames `fighters[0]` and `fighters[1]`.
- `input/keyboard.js` `KEYS` has two slots; `core/replay.js` and the harness record two input slots and `ai: {p1, p2}`.
- `casualty` rewards "the" villain as `cause` and pressures the first hero (bug 1).
