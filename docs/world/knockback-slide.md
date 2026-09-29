# The knockback slide: ground impacts that skid, and water that skips

Owner: World and Environment. Status: design, docs only (2026-09-29); built in the SC window, in the same golden regeneration, when the tree is World's. Grant (EP): World may edit the ground-impact and bounce logic in `sim/core/fighter.gd` (`impact`, and the ground and water parts of `stepLaunched`) and add the fighter fields below.

Orb, after playing the craters build: on ground a launched fighter should not bounce and leave a trail of craters. Impacts should be weighted toward a **knockback slide**, "dragging their feet or hands along the ground to stay upright, which leaves a deep trench, shatters concrete, and kicks up massive clouds of dust". On water a shallow incline should skip the fighter across the surface.

## 1. Today

`impact()` runs on every ground contact with speed over 350: it digs a crater (energy from speed and tier), splashes or throws debris, damages buildings around (`damageArea`), hurts the fighter (`speed * 0.018`), then, if the speed is over 700 and it has bounced under twice, bounces (`vy` x 0.3, `vx` x 0.75) and impacts again, otherwise ends in the `down` state. A launch at speed 2,000 therefore digs up to three craters in a row (18.8 impact craters a match in the crater-build batch). Water is separate: the skim from the crater build (entry faster than 650 with descent slope under 0.5 skips up to 3 times).

## 2. The rule

At a ground contact, with `sp` the speed, `vert = |vy| / sp` the share of the velocity that is vertical (1 is straight down), and `E` the impact energy (`WorldCrater.impactEnergy`):

| Case | Test | Result |
| :--- | :--- | :--- |
| **Slam** | `vert >= SLAM_VERT (0.85)` (about 58 degrees or steeper) | One crater, as now, with the bowl and rim. No bounce. The fighter goes `down`. At `sp >= HOP_SPEED (2,000)` and `E >= HOP_E` it may make one small hop first (`vy` x 0.25, one time) so a huge slam reads; the hop's landing is a slide or a slam by the same rule but cannot hop again |
| **Slide** | everything shallower than a slam | No crater. The fighter lands upright and slides. See 3 |
| **Too slow** | `sp <= 350` | As now: no crater and no slide, the fighter drops `down` |

So a launch makes at most one crater on the ground, and most launches make a trench instead. Bouncing stays only for the single optional hop.

## 3. The slide

**State.** A fighter that slides stays in the `launched` state (so control, the AI and the exchange logic see no new state) with a new field `slide` (0 when not sliding, otherwise the slide's start speed, for the ratios below). Rendering reads `slide` to pose him upright, leaning back, feet or hands dragging. New fighter fields: `slide`, `slideX0` (start x), `slideD` (distance so far); all in the hash. `f.bounces` still counts the hop.

**Braking.** Each tick, on the ground: `v' = v - (SLIDE_MU + SLIDE_KV * v) * dt` along the surface, so friction is a constant plus a speed term (fast slides brake hard, slow ones drag out). Uphill costs the gravity component: the acceleration adds `-1000 * slope` where slope is the ground's rise over run at the fighter (in the direction of travel), so a slide that meets a rise slows sharply and a slide down a slope runs on. The fighter follows the ground (`y = groundY(x)`, `vy = 0`); if the ground falls away faster than free fall he leaves it and is ballistic again, and the next contact is judged afresh (slam, or slide). The slide ends when `v <= SLIDE_STOP (60)`. Starting values: `SLIDE_MU = 1200`, `SLIDE_KV = 1.2` per second. That gives a slide of about 2.5 bh from 900 units per second and about 15 bh from 2,500, in fighter body heights (75 units) and independent of the world scale.

**The trench.** Each tick the fighter carves the ground from the last x to the new x by the carve-to-target rule of `WorldCrater.scorch` (a groove that is carved to a depth and never added to, so overlapping or repeated slides do not dig shafts):
- half width `hw = SLIDE_HW0 + SLIDE_HW_E * sqrt(E)`, starting at 14 (half a fighter) and 6 per unit of `sqrt(E)`: 20 to 40 for typical launches;
- depth `d = SLIDE_D0 + SLIDE_D_V * v_now`, starting at 4 plus 0.008 per unit of speed, capped at `SLIDE_D_MAX = 0.5 bh` (38): deepest where the fighter is fast, shallowing as he brakes, ending in a small **berm** (a raised lip of `0.3 d` over two columns, ahead of the stop);
- the trench is in `S.deform`, so ground physics, later crater relief and the renderer all see it.

**Concrete and pavement.** Where the slide runs over a settled biome (city, harbour village, outskirts village: `WorldBiomes.biomeAt`), it also raises a per-column array `S.crack` (0 to 1, permanent, like `S.scorch`) across the trench width by the energy, and each sample throws rubble chips (debris events). Rendering tints the cracked pavement and draws shattered slabs. `S.crack` is sparse in the hash.

**Damage.** Total damage is what it is today, moved to where it happens: the fighter's `speed * 0.018` splits into 30 percent at touch-down and 70 percent in proportion to the speed lost, so a slide that stops early costs the same. `damageArea` at touch-down uses 50 percent of today's radius and damage; along the path a sample every `SLIDE_SAMPLE = 40` units applies `damageArea` with radius `2 * hw` and damage scaled by `v_now / v_start`, so the buildings and trees on the slide's line are shattered in proportion to how fast he was going. The touch-down keeps the shake, the ring and the 0.06 s hit-stop. Because a slide crosses ground, the collateral goes up in settlements and stays the same in open country; it is measured before and after and the casualty ramp must count it (below).

**Ending.** At rest the fighter is `down` for `SLIDE_RECOVER = 0.35` s instead of 0.75 (upright: he was never knocked flat). A slide can also end early against:
- a **rim or rubble heap**, where the rise slows him by the slope term, and a steep rise (rise over run above `SLIDE_WALL = 0.8`) stops him at once with a small stop-impact (a dent crater of energy `0.15 * E`, a shake, and `speed * 0.006` damage);
- a **building footing**: until B2 lands, the existing building test in `stepLaunched` still runs, so a slide into a building's footprint is a collision as today (a brunt in B2 replaces it), and the slide ends with the same stop-impact.

## 4. Events and state

- **`slide`** (one, when it ends): `x0, x1, hw, depth, energy, surface, owner`. `surface` is `"ground"` or `"paved"`. Rendering uses it to draw the whole trench, and the dust plume's total.
- **`slide_dust`** (periodic, one per `SLIDE_SAMPLE` units and at most `SLIDE_SAMPLE_MAX = 60` per slide): `x, y (ground), v, hw, surface, i`. Rendering and VFX throw the dust and chips at each; LD1's clouds later take one cloud per slide, growing with `energy`, not one per sample.
- The existing touch-down events (`ring`, `shake`, `debris`, `dust`) stay.
- **State:** `S.slides`, a persistent record list like `S.craters` (`x0, x1, hw, depth, energy, t, owner, surface`), capped at 200 (oldest dropped, the trench stays in `S.deform`), and `S.crack`. Both in the hash. New fighter fields as above.

## 5. Water

Keep the skip and tune it so a shallow incline skips several times:
- `SKIM_MAX_TAN` 0.5 to 0.6 (about 31 degrees), `SKIM_MIN_SPEED` 650 to 500, `SKIM_LIFT` 0.55 to 0.65, `SKIM_KEEP` 0.8 to 0.85, `SKIM_MAX` 3 to 6. The expected result, to be measured at the build, is that a fighter at 1,500 units per second and a 15-degree descent skips four or five times;
- a steeper or slower entry plunges as before (drag, then `free` when slow);
- every skip emits `splash` and `ring`, and (new) a `skim` sample event `{x, y, v, i}` for a wake trail. The skip count still lives in `f.bounces`, separate from the ground hop.

## 6. Encounter's predictor

`DirLaunch.predictFlight` estimates where a launch lands, and its landing decides the personality and distance terms. It must use the same rule as the runtime, so the plan and the outcome agree (the same lesson as the chain rule in `buildings-in-depth.md`). I will provide one shared, pure function in `sim/world/`, `WorldSlide`, that both call:
- `classify(vx, vy, sp)` returns slam or slide;
- `slideDistance(sp, slope_avg)` integrates the braking law in closed form and returns the distance and end x, ignoring the trench.
Encounter replaces the bounce branch in `predictFlight` with them (a slam lands where it hits; a slide lands at the end x; a hop is ignored). A test compares predicted and actual landing x over a few hundred seeded launches (tolerance in units, set by Encounter). Coordinate through the EP.

## 7. Caps, determinism and cost

- No draw is made from `S.rng` in the slide (the touch-down and samples are pure functions of state). A test checks the position of `S.rng` after a launch does not move against a run with the slide code path stubbed to the old bounce (they differ in trajectory, not in draws).
- Caps: samples per slide 60; `S.slides` 200; per-tick carve is at most `2 * hw / COL` columns (about 10 at today's column, more at the new scale and resolution, still small); one crater per launch.
- Cost: a slide is about 60 ticks of about 15 to 30 columns each, roughly 10 slides a match, under 1 microsecond a tick on average. The trench carve reuses the scorch loop.
- QA measures before and after at the build: impact craters a match (18.8 today) and slides a match, tick cost, the collateral bands (civilians, structures) and match length. Expected: craters a match down by about half (only slams remain), slides a match about the same as today's launch impacts (about 9), collateral up in settlements.

## 8. Slot

Part of the SC window, after the world-scale constants and before the golden regeneration: the slide constants, `WorldCrater.carve` (factored out of `scorch`), `WorldSlide`, `S.slides`, `S.crack`, the fighter fields and the `fighter.gd` changes, in the same golden regeneration as SC and W-R. Encounter's predictor change follows it in the SC tempo pass. Rendering (the upright pose, the trench, the dust, the crack tint) in parallel from the events above.

## 9. Open points

- **Orb decides:** the recovery time after a slide (0.35 s against 0.75), and whether a fighter may brace during a slide (an input that adds friction or steers, a Controls question; not proposed now).
- **Game Design:** the numbers (friction, trench depth, damage split), and the collateral cost of slides in cities.
- **Risk:** a slide that runs through a settlement can raze it. A tier-4 slide of 15 bh through Bellgate is a demolition line, which is what Orb asked for, so the casualty ramp and the tier caps (`scale.md`, `buildings-in-depth.md` 4b) must count slides as a source, and the planner should read the predicted slide when it scores a launch over a town.
