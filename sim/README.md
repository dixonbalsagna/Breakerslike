# sim: the simulation core

**Source of truth: the GDScript sim (ADR 0006).** Gameplay changes land in the `.gd` files only. The JavaScript core (`*.js` in `core/`, `world/`, `director/`, `input/`) is **frozen** at commit 9ac1ea9 as the prototype-parity record: a tick-exact port of `prototype/index.html` (pinned at 7233c96), and the core the GDScript sim was proven bit-identical to. Do not edit the frozen JS: its checks fail if its behaviour changes. Architecture: `docs/architecture/overview.md`. Interfaces: `docs/architecture/module-spec.md`. Determinism and the GDScript rules: `docs/architecture/determinism.md`. Cosmetic events: `docs/architecture/fx-events.md`.

## Run

From the repo root. On a fresh clone, run `godot --headless --path . --import` once first: it registers the `class_name` scripts.

| Command | What it does | Time |
| :--- | :--- | :--- |
| `godot --headless --path . --script res://sim/core/tools/parity.gd` | **The gate (CI).** The GDScript sim reproduces every golden vector in `core/test/golden.json`: math, RNG, cosmetic stream seeds, world generation, 17 AI matches (per-tick digests, full-state checkpoints), 2 human-input replays. Also lints long float literals and prints the tick cost. `-- --no-bench` skips the timing; `-- --golden=<res:// path>` checks another file. | about 20 s |
| `godot --headless --path . --script res://sim/core/tools/golden.gd` | Regenerates `core/test/golden.json` from the GDScript sim. Only for an intended behaviour change (below). | about 15 s |
| `godot --headless --path . --script res://sim/core/tools/batch.gd -- [matches=60] [baseSeed=1] [--arm=NAME] [--json]` | AI-vs-AI batch statistics on the GDScript sim (the successor of `prototype/tools/sim-stats.js`): wins with a confidence interval, match length, collateral, launches, beams, parries, chains, hides, seam crossings, melee exchanges, speed, and a digest of every match. Deterministic per seed range. | about 350 matches per minute |
| `npm test --prefix sim` | The frozen JS core's checks: unit tests, parity with the prototype, the 1000-match soak, and "the frozen core still reproduces `core/test/frozen/golden-js.json`". It also runs the GDScript gate when Godot is found. | about 2 min |
| `node sim/core/tools/parity.js`, `node sim/core/tools/soak.js` | Frozen-core tools: the prototype lockstep and the soak | about 80 s, 12 s |

## Golden hashes: when they may change

`core/test/golden.json` pins the sim's behaviour bit for bit, and CI fails any push that changes it by accident. Regenerate it only when a change is **meant** to alter behaviour: a new move, a new number, a new world rule.
1. Make the change in the `.gd` files and check it with the batch runner.
2. Run `golden.gd`, then `parity.gd`.
3. Commit the new `golden.json` **in the same commit** as the change, and say why in the message.
Never regenerate to make an unexplained failure go away: find the cause first. A change that should not alter behaviour, such as a refactor or a comment, must pass `parity.gd` with the existing file.

`core/test/frozen/golden-js.json` is the one-time equivalence record: the frozen JS core wrote it, and the GDScript sim matched it when the JS core was frozen. After the first gameplay change it will stop matching the GDScript sim (`parity.gd -- --golden=res://sim/core/test/frozen/golden-js.json`). That is expected, and it is not a gate. `npm test` still checks that the frozen JS core reproduces it.


## Layout and owners

| Path | Contents | Owner |
| :--- | :--- | :--- |
| `core/` | state, tick, fighters, damage, hiding, RNG, wrap math, fx event emitters, hash, replay, view side (camera, reference cosmetic consumer); `tools/` the golden gate and generator, the batch runner, and the frozen JS tools; `test/` goldens and the frozen JS tests | Simulation and Engine |
| `world/` | `biomes`, `terrain`, `structures`, `cover` (`.gd` live, `.js` frozen) | World and Environment |
| `director/` | `exchange`, `melee`, `beam`, `launch`, `ai` (`.gd` live, `.js` frozen) | Encounter Systems |
| `input/` | `intent`, `keyboard`, `control` (`.gd` live, `.js` frozen) | Controls and Game Feel |

Rules for everyone changing `sim/`: behaviour changes are deliberate (parity then breaks by design; say so and regenerate the goldens); arithmetic and random-draw order are behaviour; the tick never calls view code; gameplay never reads `S.fx`; no `Math.random`, no clock.

## The GDScript sim and the frozen JS core

The GDScript files carry the JS twins' function and field names, so the frozen JS still reads as documentation of the port. The GDScript sim has one mode: deterministic math (`detmath.gd`) and split cosmetics (fx events, fx-events.md). The frozen JS core also has the modes it was proven with:
- `createSim()` is the game's rules, det + split, bit-identical to the GDScript sim at the freeze.
- `createSim({math: 'native', fxRng: 'shared'})` reproduces the prototype tick for tick.

A host drains `S.out.fx` after every tick and passes it to a consumer; `core/view/fx.gd` is the reference.

GDScript traps that break determinism or the goldens (each one was hit while porting; they still apply to every change):
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
| 2 | `core/sim.js` `step` | QA-002: cosmetic effects drew from the gameplay stream. | **Fixed.** Effects are events (`docs/architecture/fx-events.md`) consumed on the render side with per-consumer streams. The prototype's behaviour survives only in the JS parity mode `fxRng: 'shared'`. |
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
