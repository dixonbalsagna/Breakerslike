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
2. **New hashed fighter fields.** Section 20's journey bounds, the tumble, and the early recovery need state: `jContacts` (contacts so far), `jT` (seconds since the first contact), `jV0` (the journey's starting normalised speed, for the one-impact wear budget), `tumbleT` (seconds rolled), `contactT` (seconds since the last contact, for the 8-tick recovery window), `launchN` (the launch number, so every event pairs to its launch). `bounces` exists. These are granted lines in `state.gd` and `hash.gd` (Simulation).
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

New events (`docs/architecture/fx-events.md` gets them in the same slice). **Every one carries `x`, `y`, `z` (the body's depth) and `speed` (normalised), and `n`, the launch number** that pairs it to its launch: a per-fighter counter `launchN`, set when `doLaunch` arms a launch and hashed (one more fighter field), copied onto every event of that journey and onto the `launch` event itself.

| Event | Fields (besides actor, x, y, z, speed, n) | When |
| :--- | :--- | :--- |
| `left_ground` | vx, vy, cause (`lip`, `crest`, `heap`, `cliff`, `ridge`, `bounce`), contacts | the leave test fires, or a bounce lifts off |
| `bounce` | k (the bounce number, 1 for the first), vn, vt, keep, surface | a ground bounce; a water skim keeps its `skim` event and also emits this, with `surface` `water` |
| `land` | kind (`skid`, `tumble`, `slam`, `stop`), sin_a, surface, contacts, t | a contact that is not a bounce; `contacts` and `t` are the journey's counts so far |
| `tumble_end` | how (`stop`, `recover`, `air`), contacts, t | a tumble ends |
| **`journey_end`** | contacts (all kinds, at most 8), lips (flights off a lip), bounces, t (seconds from the first contact, at most 4), end (`stop`, `tumble`, `slam`, `water`, `recover`, `capped`) | once per journey, when it ends for any reason, including the 8-contact and 4 s caps (`capped`); the pairing event QA counts |
| existing `skim` | gains `z`, `speed`, `n` | each water skip |
| existing water events (`splash`, the water `ring`) | gain `z` (the body's depth, for a body at another lane), so VFX draws them at the right depth | as before |
| existing slide events | unchanged, plus `n` | the trench, dust and record |

**Why the journey counters come from state, not from the events:** `contacts` and `t` are the fighter's `jContacts` and `jT` (section 1, point 2), so the numbers on the events are exactly the ones the caps use and the planner's `journey` function predicts; QA can compare a predicted journey to the played one field by field. `launchN` is the only new field the events add. Nothing here draws a random number.

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

**Answered (balance-targets section 20, end):** spin is my formula, halving every 0.5 s in the air, capped at 3 turns a second (1.5 at tier 1); a tumble leaves one scuff and one dust puff per contact, at most 3 a second, and no trench; wear is 30% at the first touch-down and 70% in proportion to the speed each contact removes, a slam pays all, a lip flight pays nothing; `LEAVE_CLEAR` about 1.5 accepted. **Rim ruling (EP):** lip 0.5 R and crest 0.40 d as data (`RIM_IN`, `RIM_DEPTH_MAX`), with the pair 0.6 R and 0.5 d as the switch if Orb wants a taller lip after seeing it. Nothing is open on the plan.

## 7. Risks

- **Plan and outcome** are the main one (as for B2): the planner must call `journey`, which calls `advance`; the probe covers it, and the cost of a decision grows with journeys (cap candidates first).
- **Jitter:** `LEAVE_CLEAR` and the surface noise; the probe checks that a skid across 1,000 seeded plains leaves nowhere.
- **Slide length:** tumbles replace slow slides, so trenches and dust at low power shorten; Art and VFX want to see it.
- **Collateral:** longer flights and bounces move where launches end; slides near towns are watched by QA.
- **Replays:** `contact.json` joins the replay data hash (`dataHash()`).

## 8. Scratch build: status and measurements (2026-10-02)

Built against local HEAD 08f5cd0 in a scratch copy, so each slice is ready to apply the moment its slot opens. Everything is in `docs/world/scratch-build/` (a `build.py` that applies it to a fresh export; its README says how). The tree's sim files are untouched.

**G1 and reach** (`g1_reach.py`, `g1_freeze.py`): lip 0.5 R and crest 0.40 d with footings skipped; heaps at slope 0.6 (spill 1.0: above about 1.1 a low chain flight lands on the heap and plan and outcome differ); structure reach by tier with the scaled falloff, data in each `ladder.json` (`reach.structure` [1, 1, 1.6, 2.8], `reach.ringCap` -1) with the schema, `fighter_data.gd`'s parse and `beam.gd`'s explicit 1.0; and a slide's trench no longer relaxes the ground he stands on or the ground ahead (it dropped away beneath him and read as a lip of his own making). Probe: 0 failures, with the new section (rim slope at most 0.6 at every energy, largest 0.56; crest at most 0.40 d; rim and apron area at most the bowl's; heap slope at most 0.6; reach out to exactly the tier's factor and no further; the beam's path sample not widened). 100 default-arm matches, HEAD against G1 and reach:

| | HEAD | G1 and reach |
| :--- | ---: | ---: |
| Civilians lost at the KO | 17% | 20% |
| Structures lost | 45.8 | 55.1 |
| Craters | 48 | 46 |
| Length | 468 s | 475 s |
| KAI | 45 | 52 |
| BUILDING SMASH | 7% | 6% |
| Structures per minute at tier 3 (all rows / front row) | 4.15 / 5.53 | 3.91 / 5.49 |
| at tier 4 | 4.41 / 5.57 | **7.68 / 9.81** (band 6 to 20) |
| KO structures, all rows / front row | 24.9 / 32.4 | 31.2 / 41.0 (bands 15 to 40 and 25 to 50) |
| 60 second tier-4 windows over 20% of the front row | 7 of 40 matches | 13 of 40 (worst 47.5 to 61.3%) |

Tier 4 is now in its band; tier 3 was already in band on the retuned HEAD. The sim runs at 55 matches a minute against 58.

**G2 and G3** (`g2_contact.py`, `contact.gd`, `contact.json`; the model switched off by `enabled` in the data, copied into `S.contactOn` by `newMatch`): the pure `moveAir`, `groundPhase`, `stepContact` shared by the runtime (`stepFighter`) and the predictor; surface classes (`surfaceAt`, a column table built once); the landing table; bounces, skids, tumbles; the leave test; the 8-contact and 4 s bounds (past them he tumbles to a stop and cannot leave the ground again); one impact of wear per journey; spin and rot through `spinStep` (one function, only integrated or eased, never assigned); six hashed fighter fields (`jContacts`, `jV0`, `launchN` and, as integer ticks per Simulation's conditions, `jT`, `tumbleT`, `contactT` saturating at 8); the events `left_ground`, `bounce`, `land`, `tumble_end` and `journey_end`, with x, y, z, speed, the launch number, contacts and t, the slope, and `vx`, `vy` on `left_ground`; `launch` gains `ux`, `uy` and `n` (set in `WorldBrunt.arm` in the scratch; Simulation adds them in L0). Proofs:
- **Off is neutral:** per-tick light digests of 9 seeds over 12,000 ticks are identical to HEAD with the slice applied and the flag off.
- **On is deterministic:** two runs of the same 9 seeds give identical digests, and the render determinism check passes with the flag on.
- **Journey function:** over 240 seeded launches, on open ground the predicted end is within 60 units of the played one in 108 of 112 (96%); near a town it is 99 of 128, because a skid's own area damage collapses buildings and their heaps rise ahead of him, which a pre-computed journey cannot know. No NaN, no journey over 8 contacts, the same contact count in 212 of 240.
- **With the golden regenerated in the scratch (flag off):** parity passes (hash only); the validator reports only the missing `contact.json` schema (Tools).

**Flag on: what the model does** (100 default-arm matches; 20 matches for the landing classes): length 511 s (475), collateral 24% (20), structures lost 70.6 (55.1), craters 47 (46), KAI 48. Journeys per launch about 0.75; bounces per bounced journey 1.5 (band 1.3 to 2.2); the journey's end: stop 33%, wall 33% (the MOUNTAINSIDE launches landing on steep slopes), slam 31%, water 4%. **First-contact class of all launches against section 20's bands:** skid 19% and tumble 5% (slide band 40 to 55%), bounce 36% (8 to 15%), slam 21% (8 to 15%), water 3% (5 to 15%), caught in the air 16% (10 to 25%). The old model's slides were 56% of launches; the 30 to 70 degree landings it counted as slides are now bounces, and the planner's mix puts about a fifth of launches steeper than 70 degrees. Moving the skid/bounce boundary to 40 or 45 degrees gives skid 27% and bounce 27 or 22%. The bands are Game Design's call to re-base, or the angle bands' to move; the physics and the planner mix are what produce the numbers. **Cost:** about 17% more sim time per tick with the flag on (24,300 ticks a second against 28,600 in G1 and reach alone); trims: precomputed drag factors, fewer ground reads per tick.

**Order, per the EP and Simulation:** G1 and reach, then Simulation's L0 and L2 (both rewrite the launched branch), then G2 to G5 rebased onto them.

## 9. Physics constants for feel (proposed as data), for Animation's active ragdoll

Animation relies on: gravity 1000 u/s2 (unchanged), a spin cap of about 18 rad/s (mine is 3 turns a second, 18.85, and 1.5 at tier 1; halving every 0.5 s in the air, which is new: launch spin used to be constant), flights of 0.3 to 2 s. What the data gives, with the effect on a body:

| Constant | Value | Effect |
| :--- | :--- | :--- |
| Bounce keep (normal) | 0.45, 0.35, 0.25 | A 1,500 u/s landing rebounds 675 up (228 units, about 3 bh) for 1.35 s; a 900 landing 405 (82 units) for 0.8 s; the second bounce about a third of the first. Flights past 2 s only above about 2,200 into the ground: I propose `bounce.vyMax` 1,600 (a cap on the rebound's vertical speed, so a flight never exceeds 1.6 s) |
| Bounce keep (along the ground) | 0.8 | He keeps most of his run, so bounces travel |
| By surface (proposed, not built) | normal x paving 1.1, rock 1.15, soil 1.0, sand 0.75, rubble 0.8; along x paving 0.9, rock 0.9, soil 0.8, sand 0.65 | Streets and rock are lively, sand and rubble deaden: two extra data maps `bounceMul` and `tangentMul`, a few lines |
| Spin at a bounce | `vt / bodyR` (bodyR 60), capped 1.5 (tier 1) or 3 turns a second | A 1,000 u/s tangent gives 17 rad/s: a fast tumble; slower bounces roll gently |
| Tumble braking | double the skid's (section 20) for at most 1.2 s | At the tumble's entry speed (600) it stops in 0.13 to 0.3 s and 40 to 250 units: a short roll, as section 20 wants. If Animation wants a visible roll of 0.5 s or more, `tumble.brakeMul` 0.6 gives about 0.5 s; it is one number |
| Skid braking | 1,200 x surface + 1.2 v | Paving and rock 0.8, soil and sand 1.3: a 1,500 skid goes 700 units (times the launch's travel factor) on paving, 450 on soil |
| Water | skim at over 500 and under about 31 degrees, up to 6 skips, keep 0.85, lift 0.65 | Unchanged from today (the look Orb likes) |
| Slope | a skid gains or loses speed by `GRAV` x slope; a leave test per tick | Uphill a ramp slows him; a lip lets him go along the ramp; a straight downhill slope never lets go. I propose a `skid.vMax` (twice his entering speed) so a steep downhill cannot accelerate him without limit (not built) |
| `LEAVE_CLEAR`, `LIP_LIFT` | 1.5 units, 1.0 | A small tolerance; a lift above 1 raises the arc off a lip (data, at most 2) |

Animation's asks, from the EP's message: (1) the event fields are in (left_ground: vx, vy, cause, slope; bounce: k, vn, vt, keep, surface, slope; land: kind, sin_a, surface, slope; tumble_end: kind; plus z, n, contacts and t). (2) The ground slope is on each event as rise over run; the normal is `(-slope, 1)` over its length. (3) rot and spin are one function's, integrated or eased, never assigned (a skid eases upright with a 0.2 s time constant, so nothing snaps). (4) the launch event's `ux`, `uy`, `n` are Simulation's L0 line (my scratch sets them in `arm`, which I drop when L0 lands). (5) the constants above: gravity, the spin cap and the flight times are as Animation assumed, with the spin decay noted.

## 10. Re-measure on HEAD 607edce for Game Design's ruling (2026-10-02)

Scratch build (G1 and reach, G2 to G5 with the flag on) on top of Encounter's landing slice (93d5e0d), 40 default-arm matches (seeds 1 to 40) per boundary, 3,600 launches each. A journey is classed by how it ends (the closing `journey_end` event's `kind`: `stop`, `tumble`, `capped`, `wall`, `slam`, `water`); a launch with no journey was caught in the air.

| Boundary between skid and bounce | 30 degrees | **40 degrees (the ruling)** | 45 degrees |
| :--- | ---: | ---: | ---: |
| Launches with at least one bounce (band 15 to 30%) | 34.8% | **27.9%** | 24.6% |
| Bounces per bounced journey (band 1.3 to 2.2) | 1.27 | **1.28** | 1.25 |
| First contacts: skid + tumble / bounce (skids at least as common as bounces) | 26% / 35% | **32% / 29%** | 35% / 25% |
| Ending: halted (stop or tumble) | 31% | 29% | 29% |
| Ending: wall stop-impact | 15% | 17% | 17% |
| Ending: slam (band 8 to 18%) | 25% | 25% | 25% |
| Ending: water (band 2 to 10%) | 2% | 3% | 2% |
| Caught in the air, no journey (band 10 to 25%) | 27% | 27% | 28% |

Reading: **40 degrees puts bounced launches at 27.9%, inside 15 to 30**, so 45 is not needed. Halted plus wall is 46% of launches against the 55 to 75% band; slam (25%) and caught in the air (27%) are over theirs: the planner's mix, not the boundary, decides those (the boundary moves nothing in them). Bounces per bounced journey are just under 1.3: a bounce loses most of its height (45% then 35%), so the third is rare; raising the vertical keep to 0.5 and 0.4 would lift it, at the price of higher arcs. The wall endings (17%) are the MOUNTAINSIDE launches landing on slopes over 0.8; they count as halts in my reading (a stop-impact), which is Game Design's to confirm.

Other measures at 40 degrees:
- **Journey time** (first contact to the end, air time included): mean 1.08 s, 90th percentile 2.58 s. The 4 s bound is reached by 5.1% of journeys; the 8-contact bound by 0.5%; a `capped` end 0.0% (journeys reaching a bound end in a stop or a slam first). The bound applies at contacts, so a long flight after a bounce can carry past 4 s.
- **Distance** (first contact to the end): mean 2,530 units (34 bh), 90th percentile 5,638; over 2,000 units in 38% of journeys, over 4,000 in 16%, over 8,000 in 6%. For Camera: a journey leaves a normal framing (about 4,000 units) in roughly one in six.
- **Flights off the ground per minute of play** (both fighters): crater lips 1.75, natural crests 2.26 (hills and ridge flanks), cliffs 0.31, rubble heaps 0.37, bounce lift-offs 5.9. The band for lips (0.3 to 1.5 once craters have rims) is met by craters alone at the high end, and natural terrain adds more; if the band means all terrain flights the total is 4.7. (`journey_end.lips` needed a seventh hashed fighter field, `jLips`, to count them across ticks; the alternative is to drop `lips` from the event and count `left_ground` events with a terrain cause.)
- **Wear against the single-impact budget** (impact damage taken in the journey over 0.018 times the first-contact speed): mean 0.32, 90th percentile 0.60, over budget in 3.6% (slams and wall stops, which pay in full).
- **Collateral per journey:** 0.06% of the population (mean) and 0.33 structures levelled.

The closing event carries the last state: `kind` (the ending), `contacts`, `lips`, `nb` (bounces), `dur` (seconds), plus x, y, z, speed and the launch number `n`.

Notes picked up for the plan: `WorldBrunt.stepZ` runs only while a fighter is launched, so a fighter who ends a brunt flight away from the plane keeps that depth until his next launch (Simulation, for L3: the ease to the home depth has to run in every state). Rendering asks for a **sim record of window blow-outs** so a replay seek keeps them (VFX's list is pruned after 6 s): a hashed per-building bit mask of blown windows per floor, set by `floor_hit` and `building_hit` events and by the area damage, readable by Rendering; to be planned with the floors (a sized estimate follows in the next plan note).

## 11. Wear per journey (Game Design's check, 2026-10-02)

The 0.32 mean in section 10 was partly a measuring error: the first-touch damage event is emitted before the contact event of the same tick, so the script had not yet opened the journey and dropped it. Counted properly (three passes over a tick's events), 40 matches, 40 degree boundary, as a share of the single-impact budget (0.018 times the first-contact speed):

| Ending | Before the landing fix | After |
| :--- | :--- | :--- |
| Halted (stop) | 0.67 (p10 0.40, p90 1.03) | **0.87** (p10 0.54, p90 1.17), n 1,027 |
| Wall stop-impact | 0.63 | 0.83 |
| Tumble to a stop | 0.82 | 1.19 (n 29) |
| Slam | 1.09 | 1.12 (pays all, plus its area damage) |
| Water | 0.40 | 0.36 |

The shortfall in the halted journeys was real: the 70% share is paid by the speed each contact removes, but the landing itself removes the normal part of the velocity (the speed into the ground) and the skid only starts with the tangential part, so that part was never paid. The fix is in `_contact`: a skid or tumble that starts pays `perSpeed` times (the contact's speed minus the horizontal speed it starts with) into the same accumulator the skid's braking fills, so first touch 30%, landing removal and braking add up to the budget. A halted journey now pays 87% on average (80 to 100% is the target; the 10th to 90th percentile spread, 0.54 to 1.17, comes from journeys that end on a wall, a lip or in the water before the speed is gone, and from the stop at speed 60 leaving a little unpaid). The split needs no further change; if Game Design wants the mean nearer 0.95, `wear.perSpeed` 0.0126 can rise by about a tenth.

## 12. G1 landed (2026-10-02)

Rims (lip 0.5 R, crest 0.40 d, footings skipped), heaps (slope 0.6, spill 1.0), the slide-trench freeze, structure reach and its data are in the tree; the golden is regenerated and the gates pass (probe 0 failures with the new section, parity, determinism, seam sweep, `npm test` 5 of 5, the validator, the terrain audit on 8 seeds: steps over 1 bh 0 or 1, no shafts, tilted footings in rows 0 and 1 at most 3). Files: `sim/world/crater.gd` (`RIM_IN`, `RIM_DEPTH_MAX`, the footing skip in `dig`, `relax`'s freeze, `carveSegment`), `sim/world/structures.gd` (`RUBBLE_*`, the taper, `damageArea`'s reach and ring cap), `sim/director/beam.gd` (one token), `sim/core/fighter_data.gd` (the parse), the two `ladder.json` files, `tools/schemas/fighter-ladder.schema.json`, `sim/world/tools/probe.gd`, `sim/core/test/golden.json`.
