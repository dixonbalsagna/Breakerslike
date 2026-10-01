# Ground contact: what World needs in the core files

Owner: Simulation and Engine. Status: review, docs only (2026-10-02). It reads World's `docs/world/ground-contact.md` (slices G1 to G5) and Animation's `docs/animation/overhaul-plan.md` section 3 against `sim/core`, so the grants are quick when World's window opens. Verdict: **go on every ask, with the conditions below.**

## 1. The journey fields (`state.gd`, `hash.gd`)

| Field | World's shape | My condition |
| :--- | :--- | :--- |
| `jContacts` | contacts so far | `int`. Go. |
| `launchN` | the launch number, pairs every event to its launch | `int`. Go. |
| `jT` | seconds since the first contact | **`int` ticks.** The cap is 4 s = 240 ticks. |
| `tumbleT` | seconds rolled | **`int` ticks.** It ends at 1.2 s = 72 ticks. |
| `contactT` | seconds since the last contact | **`int` ticks.** The recovery window is already written as 8 ticks. |
| `jV0` | the journey's starting normalised speed | `float`. Go. |

- **Why ticks:** new timers in the sim are integer ticks (the wounds, the mood, the pause). A float that adds `dt` each tick is deterministic too, but a cap compared against it depends on rounding at the boundary; a tick count does not. Events carry seconds as `ticks / 60`.
- **Hash:** all six join the fighter's field list. A field that is not hashed is not state.
- **Resets:** World names where each is reset (the launch, the journey's end, a new match). `SimRoster` builds a fighter from defaults, so a new match needs nothing.
- **Arm recipes:** none of these is a character key, so the swap arms need nothing.

## 2. `rot` and `spin` as smooth state (Animation's ask 3)

Today, in my files:
- `stepLaunched`: `rot += spin * dt` (fighter.gd 94). Good.
- `rot = 0` on a landing (fighter.gd 120) and when a downed fighter gets up (290): a jump.
- Free: `rot *= pow(0.001, dt)` (234): an ease to 0, the long way round if `rot` is several turns.
- `WorldSlide.begin` sets `spin = 0`, `rot = 0` (World's file): a jump.
- The launch's spin is a draw in the director (8 to 16 rad/s).

`rot` and `spin` are hashed but nothing in gameplay reads them; they exist for Animation. So the rule can change without touching a fight's outcome.

**Recommendation: one function owns body rotation,** `WorldSlide.spinStep(f, dt)` (World's, with the ground model), called from the four places above by grant:
- `rot` is only ever integrated or eased, never assigned;
- the spin from a bounce is World's formula (`dir x vt / BODY_R`), it halves every 0.5 s in the air, and it is capped at 18 rad/s (Animation's number);
- in a skid the spin goes to 0 and `rot` eases to the lying angle; in a tumble `rot` is free; getting up, `rot` eases to the nearest upright, the short way;
- `rot` is an angle: consumers compare it modulo a full turn. The sim may wrap it by a full turn when the body is at rest.

It is a hash-only change for gameplay (the light digests should not move), so it can ride in G2.

## 3. The `launch` event (Animation's ask 4, World's `n`)

- `SimFx.launch` gains `ux`, `uy` (the launch direction) and `n` (`launchN`). `FxEvent` already has `ux`, `uy` and `n`.
- The caller is `DirLaunch.doLaunch` (Encounter's line). I will add the parameters with defaults in L0, so Encounter passes them when it next has the slot and nothing breaks in between.

## 4. The new events (`fx.gd`, `view/fx.gd`, FX_FIELDS)

`left_ground`, `bounce`, `land`, `tumble_end`, `journey_end`: go, as granted lines for World (G3). New `FxEvent` fields they need: `vx`, `vy`, `vn`, `vt`, `sin_a`, `surface`, `contacts`, `t`, `how`, `lips`, `bounces`, `end`. Existing fields cover the rest (`actor`, `x`, `y`, `z`, `spd` for the speed, `n`, `k`, `keep`, `kind`, `cause`).
- Animation's ask 2 (the surface slope at the contact) is one more field, `slope`, on `bounce` and `land`.
- Every positioned event gets `z` in L0 anyway.

## 5. The launched branch and `impact` (`fighter.gd`)

- World's `WorldSlide.advance` replaces the body of the launched branch and `impact`, by grant, behind its data flag. Go.
- **Order:** after L0 and L2, as World's plan says. L2 changes the same branch (the depth waypoint on every flight), and two rewrites of it should not cross.
- **Wear, one impact per journey:** the call into `SimDamage.hurt` at a contact stays in my file. World passes the journey's budget; I will take that as a parameter at the call site in G2's review.

## 6. Not for the core

- The contact catch record (Animation's ask 5) is Encounter's event.
- The early recovery (a dodge tap in a tumble, or within 8 ticks of a bounce) is Controls' and Combat's rule; it reads `contactT` and the mode.
- Animation's rates (gravity 1,000, launch flight 0.3 to 2 s): gravity is a literal in `stepLaunched` and in the predictors. If it ever becomes data, Animation hears first.

## 7. In the tree since L0 (2026-10-02)

The grant lines went in with L0, neutral and proven on the light digests (`fight-lanes.md` section 15 lists them). What World's G2 still adds in my files, by grant:
1. `S.contactOn = WorldContact.enabled()` in `SimCore.newMatch`.
2. The hook at the top of `stepLaunched`.
3. In `SimFighter.spin`: `if S.contactOn:` hand over to `WorldContact.spinStep` and return.
4. The journey's wear budget at the impact's call into `SimDamage`.

World's script should drop its edits to `state.gd`, `hash.gd`, `fx.gd` and `view/fx.gd`, and in `WorldBrunt.arm` set only the launch event's `n` (the event already carries a unit `ux`, `uy`).

