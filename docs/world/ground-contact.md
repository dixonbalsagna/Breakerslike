# Ground contact: leaving the ground, landing, bouncing, rims (plan)

Owner: World and Environment. Status: plan, docs only (2026-10-01), written against Game Design's rules (`docs/design/balance-targets.md` section 20). Nothing here is in the sim. Orb's brief: a fighter who skids up the side of a crater like a ramp should leave the lip with his speed and fly on, not follow the ground down the inside; fighters should be "ragdolled and skid, tumble, bounced over the course of the fight", ocean skipping being the example that already looks great. The approved rule: a skidding fighter leaves the ground whenever the terrain curves away beneath him faster than gravity pulls him down (a ballistic step ends above the ground), keeping his speed and direction; on coming down he resumes the skid with the tangent part of his velocity, or bounces. Encounter is the sim editor now; this takes the slot after its step 2a.

## 0. What the code does today (`slide.gd`, `fighter.gd`)

- **A skid follows the ground, kinematically.** `WorldSlide.step` moves the fighter horizontally and then sets `f.y = groundY(S, x2)` every tick, with `f.vy = 0`. Speed changes only by friction (`MU` 1200 and `KV` 1.2 times speed) and by the slope ahead (`GRAV` 1000 times rise over run). His vertical velocity is never carried: a ramp does not turn horizontal speed into upward speed.
- **At a crest or a crater lip nothing happens.** The only way off the ground is the cliff rule: a drop steeper than `CLIFF` = 1.0 (drop over run, one tick's step) ends the slide with `vx` kept and **`vy` set to 0**. A lip with a gentle outer slope never trips it, so he rides over and down the inside of the bowl, which is what Orb saw. Even when the cliff rule fires he leaves flat, not along the ramp.
- **A rise steeper than `WALL` = 0.8 stops the skid** (a stop-impact dent and some damage) if he still has speed over `STOP`.
- **Nothing bounces on land.** `SimFighter.impact` (fighter.gd:31) decides by the vertical share of the velocity: a slam (`SLAM_VERT`, 0.94 after Game Design's section 19) digs one crater and the fighter goes down; anything shallower starts a skid; a very hard slam (speed 2,000 or more) hops once. The only repeated bounce is the **water skim** in `stepLaunched` (up to `SKIM_MAX` = 6, lift 0.65, keep 0.85, for a fast shallow entry).
- **The impact angle is measured against the horizontal, not the surface.** A body hitting the steep wall of a crater at a shallow angle to the horizontal is "a slide" though it meets the wall nearly head-on, and the vertical part of its velocity is thrown away at touch-down.
- **Wrap-safe:** every x uses `SimWrap.wrap` and `groundY` wraps its columns.
- **Craters already have rims, but small ones, and the big ones are walls.** From the probe on flat ground: E = 1: R 160, depth 35, rim 11.7 units (0.33 of the depth, 0.16 of a fighter height); E = 4: rim 27 (0.39 d); E = 8: 56 (0.56 d); E = 16: 110 (0.83 d). Measuring the steepest slope of the whole profile on its way up to the lip (bowl wall and rim together; rim = x of the depth, lip 0.3 R wide):

  | Rim | Steepest inner slope |
  | :--- | ---: |
  | none | 0.34 |
  | 0.25 d | 0.50 |
  | 0.33 d | 0.585 |
  | 0.50 d | 0.77 |
  | 0.83 d | 1.13 |

  The ratio does not depend on size. So today's rims are ramps only up to E = 4 (0.33 to 0.39 d, slope about 0.6); **from E = 8 the rim is over 0.5 d and its inner slope passes 0.77, and at E = 16 it is 1.13, past `WALL` (0.8): a skid that climbs into a big crater's lip is stopped by a wall instead of launched.**

## 1. Against section 20: what I accept, and where I disagree

**Accepted as written:** the state table (airborne, skid, bounce, slam, tumble, skip, down); the angle bands (a contact angle is the angle between the velocity and the surface: shallow under 30 degrees, bounce 30 to 70, slam over 70: `sin` 0.5 and 0.94, which is the same 0.94 as section 19's `SLAM_VERT`, now measured against the surface normal and not the horizontal); the speed bands (nothing under 350; tumble 350 to 900; skid and bounce over 900; a skid falls to a tumble under 600); bounce keeps 80% along the ground and 45%, 35%, 25% of the vertical speed for the first, second and third bounce; bounces by tier (1, 2, 3, 3); bounds on a journey (8 contacts, 4 s, then a tumble to a stop); one journey costs at most one impact of wear; water skips as today; every outcome decided by speed, angle and surface with no draw. The leave test below is the approved rule.

**Where I disagree or add:**
1. **Rims.** Section 20 asks for "a rim of about a quarter of the depth" with an inner slope of 0.6 or less. Today's small rims already meet that (0.33 d, slope 0.585), so the work is the opposite for big craters: **cap the rim at 0.33 d** (`RIM_DEPTH_MAX`), which keeps the whole inner slope at 0.585 for every size, so no lip trips the wall. A quarter of the depth gives 0.50. Raising absolute height at small sizes is not possible under a 0.6 slope without a wider lip, and the crest stays about 0.07 R: 12 units at E = 1. If Orb wants visibly taller lips, the slope limit has to move, or Rendering draws the rim larger than the sim's. (I had first proposed a rim of 0.12 R; that is 0.55 d and a slope of 0.8, which trips the wall. Withdrawn.)
2. **New hashed fighter fields.** Section 20's journey bounds, the tumble, and the early recovery need state: `jContacts` (contacts so far), `jT` (seconds since the first contact), `jV0` (the journey's starting normalised speed, for the one-impact wear budget), `tumbleT` (seconds rolled), `contactT` (seconds since the last contact, for the 8-tick recovery window). `bounces` exists. These are granted lines in `state.gd` and `hash.gd` (Simulation).
3. **The tumble is a mode of the skid, not a separate system:** braking doubled, no trench, `rot` free, ends at 1.2 s or at a stop. Contact on rubble is always a tumble (a surface-class flag).
4. **Today's slide runs from 350 to 60 (`STOP`);** under section 20 a contact at 350 to 900 is a tumble and a skid under 600 becomes one. That shortens slides at low power and gives them the "rolls to a hard stop" look. It is a behaviour change QA should expect in slide length and trench counts.
5. **The leave test has one tolerance,** `LEAVE_CLEAR` (about 1.5 units: the ballistic step must end that far above the ground). It is not a speed threshold; it only keeps column-level noise from making a slow fighter hop.
6. **Wear** (one impact per journey) is Combat's and Simulation's code (`SimDamage`); I supply the contact record (speed in, speed out, kind) and the journey function reports the budget. The numbers are Game Design's.

## 2. The ground model: leave, land, bounce, tumble

One pure function shared by the runtime and Encounter's launch predictor (the B2 pattern, so plan equals outcome): `WorldSlide.advance(S, st, dt) -> st`, with `st` a small record `{x, y, z, vx, vy, mode, slide, bounces, contacts, t, launchT, tier}` and nothing else changed. `stepLaunched` and the journey function both call it; events are emitted by the runtime from the record's flags, never by `advance`. Arithmetic is float64 with `SimDetMath` roots, no trigonometry (an angle is a ratio), `x` wrapped with `SimWrap.wrap`; slopes from `groundY` at `x +- COL`.

**The leave test (replaces `CLIFF`).** In a skid or a tumble, let `s` be the slope of the segment just travelled (rise over run, in the direction of travel) and `vy_t = s x vN` the tangent's vertical rate. Take the next ballistic step exactly as `stepLaunched` integrates it: `vy' = vy_t - 1000 dt`, `y_b = y + vy' dt`. If `y_b - groundY(S, x2) > LEAVE_CLEAR` he leaves: `slide = 0`, `vx` kept, **`vy = vy_t`**, mode airborne, a `left_ground` event. It is equivalent to "the ground's radius of curvature at the crest is smaller than `v^2 / g`": at 2,000 units a second any crest tighter than 4,000 units lets go, at 500 any under 250. A hill (radius in the hundreds of thousands) never does; a heap crest (about 75) does from 270 upward; a crater lip, a cliff and a ridge do.
- The vertical rate uses the normalised speed (`vy = s x vN`), with the horizontal part carrying the launch's traversal factor as every launch does, so arcs stay readable. Alternative (Game Design): the tangent in raw space, arcs `launchT` times higher.
- The wall rule (`WALL` 0.8) stays: a rise steeper than a skid can climb stops him.

**Landing.** With the ground slope `s` at the contact (secant over `+- COL`), tangent `t = (1, s)/q` and normal `n = (-s, 1)/q`, `q = sqrt(1 + s^2)`, normalised velocity `(vxn, vy)`: `vn = (vy - s vxn)/q` (negative into the ground), `vt = (vxn + s vy)/q`, speed `sp = hypot(vxn, vy)`, contact `sin^2 a = vn^2/sp^2` compared as squares with 0.25 (30 degrees) and 0.94^2 (70). Then section 20's table applies as written: skid (over 900), bounce (30 to 70 degrees, over 900, with a bounce left: `vn' = -e_k vn` with `e` = 0.45, 0.35, 0.25 by bounce number, `vt' = 0.8 vt`, lifted off at once), slam (a crater, a hop at 2,000 or more), tumble (350 to 900, or rubble, or no bounce left and too slow to skid), water (the skim, unchanged: its keep and limits move into the surface table). A skid starts with the tangent speed (`vt / q` horizontal): the normal part is what the ground took.
- **Spin.** At a bounce `spin = dir x vt / BODY_R`, decaying in the air (a formula, no draw); `rot` free in a tumble, 0 in a skid. Animation reads `spin`, `bounces`, `mode` events.
- **Depth.** With lanes `groundY` takes the fighter's `z`; nothing in `advance` changes.

**The surface class per column** (braking). `WorldTerrain.surfaceAt(S, x)` is a pure, derived function (nothing new hashed): water where `S.water` is at least `MIN_DEPTH`; rubble where `S.rubble` is above a threshold; paving inside a settlement's platform (the span and platform the generator already has, not the coarse biome test `_paved` uses today); otherwise by biome from data: desert sand, mountains and highlands rock, plains and forest soil. `data/biomes/contact.json` (`biomes.contact/1`) holds the table: braking multiplier (paving and rock 0.8, sand and soil 1.3, per section 20), the tumble flag (rubble), and the water row (skip limits). A dug column is soil, its paving gone: a trench in a street leaves the class as paving until the cracks are the pavement's record (`S.crack`), a decision for Game Design.

**The journey function.** `WorldSlide.journey(S, st0, tier) -> {contacts: [{t, x, y, kind, speed, left}...], end: {x, y, t, kind}, n, lips, tumble, speedLoss, area: [{x, power}...]}`. It runs `advance` from the first contact (or from a launch) until the stop, 8 contacts or 4 s, then closes the tail as a tumble to a stop (closed form, no more steps), and reports each contact's area-damage power so Encounter can check the collateral budget (section 20: the planner declines an over-budget journey). Pure, no draw, same `advance` as the runtime. Cost: a journey is at most 240 ticks of `advance` (about 0.5 to 1 us a tick); with up to 16 predicted flights per decision that is 2 to 4 ms on that one tick: Encounter's budget (a candidate cap or a coarser candidate screen first); the plan equals the outcome because the step is the same.

## 3. Raised crater rims and lips on ridges and heaps

- **Craters.** Rim crest at most `RIM_DEPTH_MAX` = 0.33 of the bowl depth (today: `d x volFrac x 0.83`, which is 0.33 to 0.83 d with the energy), lip width `RIM_IN` 0.3 R as now. Result: the whole inner slope is at most 0.585 for every size; a table of crest heights: E 0.5: 8, E 1: 12, E 4: 23, E 8: 33, E 16: 44 units. The volume ratio of rim and apron to bowl is unchanged up to E = 2 (0.39 to 0.40) and falls above it (0.46 to 0.39 at E = 4, 1.02 to about 0.41 at E = 16): material is lost on the big craters, which "roughly conserve" tolerates; Orb can trade it for a wider lip.
- **Footings.** A rim lands on the columns of standing buildings in its apron. The T4 rule extends to digs: the rim's positive writes skip the columns under standing footings (`WorldStructures.pinned`), as heaps do.
- **Terrain audit and T1 to T4.** Steps stay under 0.6 bh a column; a smooth crest does not trip the spike metric; the relaxation (limit 1.25) leaves a slope of 0.585 alone, so crisp rims stay crisp. The audit tool adds a "lip slope" metric (the steepest rise into any rim) and the probe a hard check: over a sweep of energies, the steepest inner slope is at most 0.6.
- **Level caps.** `RELIEF_MAX_RATIO`, the ordinary bowl cap and `DEFORM_FLOOR` are untouched; the rim now never meets `DEFORM_CEIL` (the largest special rim is 0.33 d, far below it).
- **Rubble heaps** get the same ramp rule. T1's crest cap (4 bh, slope at most 1.0) becomes **slope at most 0.6** (`RUBBLE_SLOPE` 0.6) with a wider spill (`RUBBLE_SPILL` 1.2 widths): a heap at most about 2.5 bh, a ramp a skid can climb and leave from the crest, not a wall that stops him. The footing taper stays.
- **Ridges and hills.** Slopes in the fighter plane are set by the generator: the highlands relief (about 8 bh at most, `districts-plan.md` section 14) is built with `HIGHLAND_SLOPE_MAX` 0.6 on the flanks and a crest tight enough to launch a fast skid; the formations (N1) stand on top. Today's mountain flanks reach 1.15 (37 units a 32 unit column) and would stop a skid as a wall; they become the far ridge row (not reachable) or the highlands.
- **Cliffs.** The relaxation allows up to 1.25: a step steeper than a skid can climb stops him (wall), a drop leaves by the test. Nothing else is needed.
- **Buildings, formations, props:** unchanged (a body that meets a footprint stops or is hit, L3). **Water's edge:** the skim.

## 4. Events (Camera, VFX, Animation, Audio)

New events (`docs/architecture/fx-events.md` gets them in the same slice; each carries `z` per the lanes plan):

| Event | Fields | When |
| :--- | :--- | :--- |
| `left_ground` | actor, x, y, vx, vy, speed, cause (`lip`, `crest`, `heap`, `cliff`, `ridge`, `bounce`) | the leave test fires, or a bounce lifts off |
| `bounce` | actor, x, y, n, speed, vn, vt, keep, surface | a ground bounce; water skims keep `skim` and also emit this |
| `land` | actor, x, y, speed, kind (`skid`, `tumble`, `slam`, `stop`), sin_a, surface | a contact that is not a bounce |
| `tumble_end` | actor, x, y, t, how (`stop`, `recover`, `air`) | a tumble ends |
| existing slide events | unchanged | the trench, dust and record |

Camera takes `left_ground` to `land` as an airborne phase with a known arc; VFX hangs dust, tumble blur and the contact flash on `bounce` and `land` by speed and surface; Animation picks skid, tumble, bounce and air from the events and from `mode`, `spin`, `bounces`; Audio takes surface and speed. The early recovery (a dodge tap in a tumble or within 8 ticks of a bounce) is Controls' and Combat's; the window is readable from `contactT` and the mode.

## 5. Slices and goldens

| # | Slice | Owner | Behaviour | Goldens |
| :--- | :--- | :--- | :--- | :--- |
| G1 | Rims capped at 0.33 d, the dig's footing skip, the heap ramp (`RUBBLE_SLOPE` 0.6, spill 1.2), the lip-slope probe check and audit metric, the doc table | World | Changes (terrain: smaller big rims, gentler heaps) | Regenerated |
| G2 | The ground model: `WorldSlide.advance`, the leave test, the landing table, tumble, `surfaceAt`, `contact.json`, the new fighter fields; `fighter.gd` (`impact` and the launched branch) calls it, by grant. **Lands off by a data flag** (`enabled`), so it is neutral and provable on the light digests | World, with granted lines in `fighter.gd`, `state.gd`, `hash.gd` | Neutral | Hash-only |
| G3 | The events and their consumers: `fx.gd`, `view/fx.gd`, FX_FIELDS (granted); Camera, VFX, Animation, Audio read them | World, with Rendering and the others | Neutral | Hash-only |
| G4 | `WorldSlide.journey`, and Encounter's planner calls it; the probe of plan against outcome over 300 seeded launches across craters, heaps and cliffs | World writes it; Encounter calls it | Neutral until switched on | None |
| G5 | **The switch-on** (`enabled`) with Game Design's numbers; the early recovery with Controls; QA re-baselines | World, Combat, QA | Changes (landings, wear, slide length, collateral from slides, where launches end) | Regenerated once |

G1 can land first and alone (terrain only). G2 to G4 follow the lanes order (they touch the launched branch of `fighter.gd`): after L0 and L2. G5 lands with or just before L4's switch-on so QA re-baselines once. **QA bands that move:** slides, bounces, slams and caught-in-the-air shares (section 20's table), craters per match (down), time to a stop, airborne time after a landing, wear per journey, flights off a lip per minute, and collateral from slides.

## 6. What I still need from Game Design

1. **Surface at a dug street:** does a trench in paving stay paving for braking, or become soil?
2. **Heap and rim shape:** confirm the 0.33 d cap and the 0.6 heap slope (or a wider lip at a taller rim); a number for the highlands slope.
3. **Spin and tumble look:** the spin at a bounce and its decay; whether a tumble draws a mark and dust per roll or per contact.
4. **Wear numbers:** the budget split across contacts (section 20 says "one impact per journey"); where the 30% touch-down share goes.
5. **The leave tolerance:** `LEAVE_CLEAR` as a small margin (mine), or none.
6. **Whether the leave direction uses the normalised or the raw tangent** (default: normalised).
7. **Tier and personality:** whether the hero's and the villain's journeys differ (bounces by tier only, as written, is my default).

## 7. Risks

- **Plan and outcome** are the main one (as for B2): the planner must call `journey`, which calls `advance`; the probe covers it, and the cost of a decision grows with journeys (cap candidates first).
- **Jitter:** `LEAVE_CLEAR` and the surface noise; the probe checks that a skid across 1,000 seeded plains leaves nowhere.
- **Slide length:** tumbles replace slow slides, so trenches and dust at low power shorten; Art and VFX want to see it.
- **Collateral:** longer flights and bounces move where launches end; slides near towns are watched by QA.
- **Replays:** `contact.json` joins the replay data hash (`dataHash()`).
