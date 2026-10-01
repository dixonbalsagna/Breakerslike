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
1. **Rims (revised after Game Design's wider-lip request, section 3 has the numbers).** Today's rims are 0.33 to 0.83 of the depth with a lip 0.3 R wide, and the big ones are walls (inner slope 0.77 to 1.13). With the lip widened to 0.5 R the crest can be taller and still be a ramp: **lip 0.5 R, crest 0.40 d** (inner slope 0.57, 1D rim-and-apron volume 0.53 of the bowl), with 0.45 d the most that holds 0.6. The 0.5 d crest Game Design asked for gives 0.63, over the limit, unless the lip is 0.6 R. I first proposed a 0.12 R rim (0.55 d, slope 0.8) and a 0.33 d cap at the old lip; both are superseded.
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

- **Craters: lip 0.5 R, crest at most 0.40 of the depth** (`RIM_IN` 0.3 to 0.5, `RIM_DEPTH_MAX` 0.40). Numbers, for a straight-down bowl (depth 0.22 R), steepest slope on the way up to the crest, bowl wall and rim together:

  | Rim, lip | Inner slope | Rim+apron area / bowl area (the sim's 1D profile) | Crest at E = 0.5, 1, 4, 16 (units) |
  | :--- | ---: | ---: | :--- |
  | today: 0.33 to 0.83 d, 0.3 R | 0.58 to 1.13 | 0.39 (E <= 2) to 1.02 (E = 16) | 8, 12, 27, 110 |
  | 0.33 d, 0.5 R | 0.52 | 0.43 | 8, 12, 23, 44 |
  | **0.40 d, 0.5 R (recommended)** | **0.57** | **0.53** | **10, 14, 28, 53** |
  | 0.45 d, 0.5 R (the most that holds 0.6) | 0.60 | 0.60 | 11, 16, 32, 59 |
  | 0.50 d, 0.5 R | 0.63 (fails) | 0.68 | 12, 18, 35, 66 |
  | 0.50 d, 0.6 R | 0.60 | 0.72 | 12, 18, 35, 66 |

  The slope and the ratios do not depend on the size. Game Design's estimate of 0.53 holds for a crest of about 0.35 d; at 0.5 d it is 0.63. **Volume:** the doc's convention is the 1D profile (the sim's crater is a trench across the band), where rim and apron hold 0.53 of the bowl at the recommended setting, inside "no more than the bowl". By a revolved 3D measure (a ring at a larger radius carries more) the ratio is above 1 already today (1.6) and would be about 2.3; the sim does not use that measure, and Rendering draws the bowl from the same profile, so I read the rule as the 1D one.
- **Does the lip launch?** The crest's radius of curvature is `(lip x R)^2 / (6 rim)`; a skid leaves when `v^2 / g` exceeds it. At the recommended setting: E = 1 leaves above about 275 units a second, E = 4 above 390, E = 16 above 530 (today, with the 0.3 R lip: 180, 260, 350). A skid is over 900 by section 20, so every skid leaves every crater lip; a tumble (350 to 900) leaves the big ones only above about 530. The wider lip is a gentler ramp, so the launch reads as an arc and not a pop.
- **T1 to T4 limits.** The relaxation's limit is 1.25 (40 units a column): a 0.57 slope (18 units a column) is untouched, so rims stay crisp. The crest never meets `DEFORM_CEIL` (960): a special crater of R 8,320 had a rim of 0.83 d = 1,520, so it was clipped flat-topped; at 0.40 d it is about 730. The relief cap (`RELIEF_MAX_RATIO`), the ordinary bowl cap and `DEFORM_FLOOR` are untouched. The ring the next dig samples at 1.2 R sits on the apron (0.9 of the crest), so a second dig on a lip is held back slightly more, which is right. The audit's steps stay under 0.6 bh a column, a smooth crest does not trip the spike metric, and shafts are unaffected.
- **Footings.** The apron reaches 2 R and the lip starts at 0.5 R, so more columns are in it than before. A rim lands on the columns of standing buildings in its apron. The T4 rule extends to digs: the rim's positive writes skip the columns under standing footings (`WorldStructures.pinned`), as heaps do.
- **Probe and audit.** The audit tool adds a "lip slope" metric (the steepest rise into any rim) and the probe a hard check: over a sweep of energies and grazes, the steepest inner slope is at most 0.6 and the 1D rim-and-apron area at most the bowl's.
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

## 6. Game Design's rulings (balance-targets section 20) and what is left

**Applied:** a trench in paving becomes soil for braking (the surface class reads the trench: a column whose `S.deform` is below its settlement platform's paving level counts as soil); heaps at slope 0.6 (`RUBBLE_SLOPE`); highlands flanks 0.35 to 0.6 (`HIGHLAND_SLOPE_MIN`, `HIGHLAND_SLOPE_MAX`); the leave uses the normalised tangent, with an optional lip-lift factor (`LIP_LIFT`, 1 to 2, data in `contact.json`, default 1) that multiplies the vertical rate at the leave; no personality difference; no random draw anywhere.

**Still open** (small, for Game Design): the spin at a bounce and its decay, and whether a tumble marks the ground per roll or per contact; the wear split across contacts (one impact in all); `LEAVE_CLEAR` (my 1.5 units) or none; and Orb's view of the rim, now 0.40 d on a 0.5 R lip: the taller crest the ruling hoped for (0.5 d) needs a 0.6 R lip to hold the slope.

## 7. Risks

- **Plan and outcome** are the main one (as for B2): the planner must call `journey`, which calls `advance`; the probe covers it, and the cost of a decision grows with journeys (cap candidates first).
- **Jitter:** `LEAVE_CLEAR` and the surface noise; the probe checks that a skid across 1,000 seeded plains leaves nowhere.
- **Slide length:** tumbles replace slow slides, so trenches and dust at low power shorten; Art and VFX want to see it.
- **Collateral:** longer flights and bounces move where launches end; slides near towns are watched by QA.
- **Replays:** `contact.json` joins the replay data hash (`dataHash()`).
