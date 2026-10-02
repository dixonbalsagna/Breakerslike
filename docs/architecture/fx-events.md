# The fx event stream: the sim's cosmetic output

Owner: Simulation and Engine. Status: implemented in both cores (`sim/core/fx.js`, `sim/core/fx.gd`) and bit-identical between them. It's the input for Rendering, VFX, Camera and Audio. It resolves QA-002.

Since the QA-002 split, the sim holds no cosmetic state and makes no cosmetic random draws. Every visual effect the prototype spawned inside the sim now leaves it as an event: particles, damage numbers, the banner and camera shake. The render side turns events into visuals with its own random streams, so no VFX change can ever alter a match. `sim/core/view/fx.js` and its GDScript twin `view/fx.gd` are the reference consumer. They reproduce the prototype's particles, and the golden checks cover them too.

## Delivery and timing

- `step(S, inputs)` appends the tick's events to `S.out.fx`, an array (GDScript: `SimState.FxEvent` objects). The host drains it after every call: consume the events in order, then clear the array. This applies to hit-stop ticks too.
- Events are in emission order, which is the order the prototype made its effect calls. Each tick's list holds exactly one `tick` event, placed where the prototype stepped its particles, after the fighters, the director and the beams. The only events that can follow it are the beam-clash sparks.
- A hit-stop tick (the sim is frozen; `step` returns false) emits just `{type: 'tick', frozen: true}`.
- Coordinates are world units, taken when the event was emitted: x in [0, W) on the wrapped planet (W = `SimConst.W`, 153,600 since the world scale), y upward with sea level at 0. Durations are in seconds.
- Measured over 20 AI matches (85,863 ticks): about 1.35 events per tick on average, 7 at p99 and 46 at most, in a beam-and-explosion tick.

## The envelope

Every event carries `type` and `tick` (`S.tick`: steps since the match began, hit-stop ticks included), plus the fields of its type. Fighter references are slots in `S.fighters` (0 and 1 today; -1 means none). The feed text (`S.out.feed`) stays for people. **Tools and tests read events, not feed text (QA-004).** The core's feed lines already have structured twins (`tier_up`, `hide_start`, `found`, `ko`). The director's (attacks, launches with their `launch_plan` candidates, parries, chains, ambush, lock lost) arrive with Encounter's slices; `wounds-plan.md` lists who delivers each one. Planned shapes that UI, Audio and QA have asked for are fixed there too (§6): for example `window_open` {kind, duration}, `cinematic_start` and `cinematic_end` {kind, length}, and an `internal` flag on core `region_stage` events.

## Event types

Fields are listed in their canonical order, the order the golden hash reads them.

**Each type sets exactly the fields in its row, and no others** (checked at S3b: every emitter in `sim/core/fx.gd` sets exactly its `FX_FIELDS` list in `hash.gd`, and nothing else builds events). A GDScript `FxEvent` carries every field of every type; the ones not in the row keep their defaults (0, empty string, false, -1 for a slot) and are not part of the event, so treat them as absent. A listed field is always set, even when its value happens to equal a default: `n` 0 on a parry window, `actor` -1 on a cue for both fighters and an empty `text` on a cue with no camera hint are meaningful values, described in the row.

| type | fields | when | what the reference consumer does |
| :--- | :--- | :--- | :--- |
| `spark` | x, y, n, col, spd | hits, explosions, power-ups, beam clashes, glass-trench beams | n spark streaks: direction and speed random (spd sets the scale), life 0.15 to 0.4 s |
| `ring` | x, y, gr, col, life, r0 | shockwaves: impacts, launches, dodges, parries, charges | an expanding ring, radius r0 growing at gr units/s over life |
| `debris` | x, y, n, col, spd | building damage, craters, impacts | n chunks under gravity 900 that bounce off the ground (the consumer reads terrain height) |
| `dust` | x, y, n, col | collapses, impacts, beam scars, power-ups | n dust puffs with drag, life 0.8 to 1.8 s |
| `splash` | x, y, n | fighters hitting water, impacts at sea | n droplets under gravity 1200 |
| `fire` | x, y, n | explosions, burning trees, firestorm beams | n flames, orange or yellow |
| `after` | x, y, life, col, face | dodges and escapes (life 0.45), every tick of a rush (0.16) | a fading silhouette of the fighter facing `face` (+1 right, -1 left) |
| `charge` | x, y, col, ground | every tick a fighter is charging | the consumer rolls 40% for an aura spark and 6% for a dust puff, the latter only within 30 units of `ground` |
| `crater` | x, y, r, depth, energy, cause, rim, skid, owner, special | a crater was dug (GDScript sim only): ground impacts, ground-level power-ups, beam ground strikes, clash blasts | nothing yet: the reference consumer ignores it. Rendering builds a bowl from it; VFX adds the burst |
| `scorch` | x, y, w, power, variant, owner | every beam sample within reach of the ground (GDScript sim only) | nothing yet (ignored). Rendering and VFX draw the burn trail and the beam's ground contact |
| `evacuate` | b, x, n, cx, reason, owner, dest, floor | civilians fled instead of dying (GDScript sim only): `b` the building's index, `x` its x, `n` how many (a float head count, unrounded for a blow's evacuees, lots of at least half a person for the district flight), `cx` the x of the event the crowd flees from, `reason` `"budget"`, `"ceiling"` or `"flight"`, `owner` the causing fighter's slot (-1 for the flight), `dest` the building the people took shelter in (-1 unless `RELOCATE` is on). `floor` the lowest floor the people left when a brunt cleared floors of a skyscraper (B2; -1 for a whole building). Emitted in the same tick as the building's `popAlive` falls | Rendering draws them running away from `cx`; Narrative's barks read the reason |
| `building_fall` | b, x, y (= the building's depth z), w, depth (= its height h), mode, delay, cx, rubble, n | a building's hp reached 0 by any source: `mode` `"implode"` (area damage: straight down into its footprint) or `"burst"` (a launch through it), `delay` the cosmetic ripple delay in seconds (distance from `cx` over `IMPLODE_SPEED`, at most 1 s), `rubble` the heap height left, `n` 1, or the count folded into a summary event (`b` -1) past 24 events per blast | Rendering animates the fall and the heap; Camera can hold on the ripple |
| `collateral_state` | room, budget, left, over | once a second: the casualties the window still admits, the window's budget, the ceiling left (all in people) and whether the window is over budget or the ceiling reached | the UI (default: not shown), QA |
| `slide` | x, x1, w, depth, energy, variant, owner, pop | a knockback slide ended (GDScript sim only): `x` where the fighter touched down, `x1` where he stopped or left the ground, `w` the trench's full width, `depth` its depth at the start, `variant` `"ground"` or `"paved"` (it started in a city or village), `owner` the launcher's slot, `pop` the civilians the slide killed (its own set piece's casualties) | nothing yet (ignored). Rendering draws the whole trench and the dust plume's total |
| `slide_dust` | x, y, spd, w, variant, n | a sample along a slide, every 40 x WS units, at most 60 per slide: `spd` is the normalised speed (the launch's traversal factor divided out), `w` the trench width, `variant` the surface, `n` the sample index | nothing yet (ignored). Rendering and VFX throw dust and rubble chips at each |
| `skim` | x, y, spd, n | a launched fighter skipped off water: the surface height, the speed, and the skip number | nothing yet (ignored). VFX draws the wake |
| `beamSplash` | x | a beam sample below y = 30 over the sea | the consumer rolls 60% for a splash of 3 at (x, 0) |
| `damage` | x, y, amount, col, attacker, victim, region, kind, number | every hit, and every landing or collision that hurts | a damage number when `number` is true (hits): text `String(Math.round(amount))` rising 60 units/s for 0.9 s, gold when stance was ignored, white otherwise. `attacker` and `victim` are fighter slots (-1 for none); `region` is head, core, arms or legs; `kind` is light, heavy, guard, guard_break (the GUARD BREAK's finishing strike, from S2), beam or impact (Audio's hit sounds) |
| `banner` | text, col, dur | power-ups, parries, KO, chains, clashes, ambushes; for human players also NEED 45 KI and LOCK LOST | the centre-screen banner (the latest one replaces any earlier one) for dur seconds of unfrozen time |
| `shake` | k, x | anything heavy; `x` is the world x of the cause (the hit fighter, the impact, the beam's origin, the clash point, the building) | camera shake: `shake = max(shake, k)`. A split-screen camera can shake only the pane whose view holds `x` |
| `tick` | dt, frozen | once per tick | steps the particles and damage numbers by dt (dt × 0.1 when frozen) |
| `region_stage` | actor, region, stage | a body region's wound stage changes, up or down (Wounds, `sim/core/wounds.gd`) | nothing; for the crown and wound cards (Rendering, UI). `actor` is the fighter's slot; `region` is head, core, arms or legs; `stage` 0 fresh, 1 bruised, 2 battered, 3 broken |
| `region_broken` | actor, region | a region reaches broken (also sent as a `region_stage`) | nothing; the break's wound card and set piece |
| `brink_enter` | actor | the fighter is on the brink: the core broken, or two of head, arms and legs broken | nothing; the brink state (a finisher can now end the match, from S2) |
| `brink_exit` | actor | the fighter leaves the brink (by a Rally, from S4) | nothing |
| `brink_open` | actor, target, kind, text | the brink chapter (`spec-wounds.md` §1b): `target` won the set-up (`contest.brinkSetups` decisive wins, never in the exchange that caused the brink) against `actor`, which is on the brink. `actor` is staggered and **open**: `target`'s next decisive win, in a later exchange, is the finisher. `kind` is `target`'s finisher kind (launch, melee or beam; empty until Combat's finishers carry one) and `text` its finisher id | nothing; UI's open marker, Rendering's stagger and dropped-guard pose, the finisher-kind tell, Audio's sting |
| `brink_close` | actor, kind | `actor`'s opening closed, and the rival needs a new set-up. `kind` is won (`actor` won a decisive exchange), survived (it survived a finisher) or rally (a Rally took it off the brink) | nothing; UI clears the marker |
| `mood_band` | kind, amount, n | M1: the fight's mood entered a new band after its dwell. `kind` calm, tense or frenzied; `amount` the mood in points (0 to 100); `n` the act | nothing; Audio's music layer, Camera's stance, QA's time in band |
| `act_change` | n, kind | M1: the act rose to `n` (2 to 4). `kind` is the beat (M1b, `mood.json actBeats`): `regionBreak`, `form` (F1), or a once-per-match `limbBattered`, `coreBruised` or `coreBattered` | nothing; Audio, Camera, Narrative |
| `style_label` | actor, kind, text | M1: `actor`'s style label changed. `kind` is the new label (turtle, rusher, runner, charger, sniper, mixer), or "" when a label ends with none to follow; `text` is the previous label, or "" | nothing; Narrative's lines and thoughts, Encounter (Q4) |
| `crowd_state` | kind | M1: the crowd output changed: excited, nervous or fleeing | nothing; Rendering's crowd dressing, World (evacuation) |
| `building_hit` | actor, x, n, b, y, z, amount, ratio, outcome, link, spd, keep, ux, uy, kind, w, h, owner, victim | a brunt: launched fighter `actor` (slot) hit the building `b` (index) at `x`, height `y`, depth `z` (its near face); `n` = `link` counts the buildings of this flight (2 or more: a chain). M1's three fields (actor, x, n) are unchanged and are what the mood module reads. B2 adds `amount` (damage), `ratio` (damage over the strength struck), `outcome` (floors: `punch`, `crack`, `dent`; a whole building: `collapse`, `heavy`, `wreck`, `crack`; `pancake` when floors fell), `spd` (the normalised arrival speed), `keep` (the share of speed carried on), `ux`/`uy` (the unit impact velocity), `kind`, `w`, `h` (the building's standing height) and `owner`/`victim` (slots of the launcher and the launched). A mood input | Camera frames the hit; VFX/Rendering: debris, dust and the hit-stop that accompanies it (`dirS.stop`, 0.35 s for the first hit, 0.12 s for each further one, 0.8 s at most); Audio |
| `launch_depth` | x, y, x1, y1, z, b, dur, n, owner, victim | B2, at the launch: the launched fighter will hit building `b` first: from (`x`, `y`) to the first hit point (`x1`, `y1`) at depth `z` in `dur` seconds, and the planned chain is `n` buildings long. The fighter's depth then eases to `z` by his x progress (`Fighter.z`, positive toward the camera); it enters no physics | Camera (depth framing), Rendering (the fighter's scale and sort), Audio |
| `chain_link` | from, to, x, y, z, x1, y1, z1, dur, link, owner, victim | B2: after a hit on building `from` the fighter leaves its far face at (`x`, `y`, `z`) and heads for building `to`, arriving at (`x1`, `y1`, `z1`) in `dur` seconds: the `link`-th hit of the flight comes next. Plan and outcome are the same code, so the link always happens | Camera, VFX (the trail between the two buildings) |
| `floor_hit` | b, floor, n, outcome, ratio, x, y, z, ux, uy, kind, owner, victim | B2: a brunt struck floors of a skyscraper (5 floors or more): `floor` the lowest floor, `n` how many it cleared (0 for a crack or a dent), `outcome` `punch` (cleared: a hole the fighter flies through), `crack` or `dent`, `ratio` the damage over the strength of the floors, with the impact point and direction. Emitted with the `building_hit` | Rendering (hole, cracks and the dent on the building's face), VFX |
| `floors_fall` | b, from, to, n, x, z, w | B2: a span of floors was cleared that is longer than a tunnel (`TUNNEL_MAX` 2), so the stack above pancakes down: floors `from` to `to` of building `b` fell, `n` in all (broken floors, the stack and the cleared span). The building stands shorter, or is gone if nothing is left (then a `building_fall` follows) | Rendering (the fall of the stack), VFX (dust), Audio |
| `limb_break` | actor, victim, region | Pitch A, the crippling moment: `actor` broke `victim`'s limb (`arms` or `legs`) with a heavy-class blow in a decisive exchange. A `region_stage` (3) and a `region_broken` follow in the same tick. At most one per fighter a match. It is a mood input (M1) | nothing yet; Encounter's 1.5 s set piece (Q4), the HUD, Camera, Audio, Narrative |
| `rally` | actor, region, kind | S4: `actor` rallied, mending `region` to battered at 89 (a `region_stage` and `brink_exit` follow in the same tick). `kind` is the fighter's rule: `second_wind` (survived a finisher contest) or `spite` (won a decisive exchange by hand); `reboot` and `encore` arrive with their fighters | nothing; the HUD's Rally card, Camera, Audio |
| `tier_up` | actor, tier, onGround | a fighter reaches a new power tier (the structured twin of the feed line). For a transformation this is the **break**: it comes at the end of the gather, with the burst, the crater and the size step, and on a full or short version it is sent on a frozen tick | nothing; `onGround` is true when the power-up cratered the ground. Animation, VFX and Camera key the break on it |
| `transform_ready` | actor, tier, source | I2b, the placeholder transform (ADR 0008): `actor`'s power crossed a threshold and `tier` waits for the transform. `source` is the input that takes it: `triggers` (the two-trigger chord), `power` (the power hold, for the Simple layout and today's keyboard and touch) or `ai`. It is sent on the rising edge of `Fighter.act.formReady` | nothing; the HUD's transform prompt and hold ring |
| `transform` | actor, tier, source, dur, version, gather | `actor` started a transformation: `tier` is the tier it is taking, `source` the input that took it. `version` is `full`, `short` or `live` (`SimPause`): full and short pause the sim for `dur` seconds from the next tick (the cinematic); live does not pause, and `dur` is the hold in which the transformer cannot be interrupted. **The tier does not rise here.** It rises at the break, `gather` seconds after this event (60, 24 or 10 ticks), and the `tier_up` is sent then: on a frozen tick inside the pause for full and short, on a live tick for live | nothing; Camera, Audio, the HUD, Animation |
| `beam_outcome` | actor, target, kind | step 2b (ADR 0008): `actor`'s signature reached its fire beat and its outcome was decided there, from what `target` did during the tell. `kind` is CLASH, GUARD, DODGE, ESCAPE, HIT or DEFLECT (DEFLECT from step 3). In the `dynamic` profile the `attack` event at the request no longer carries the outcome, so tools read it here | nothing; QA's beam rows, the outcome flash |
| `pause_start` | kind, actor, version, dur | Q10: a pausing set piece starts. The sim is frozen for `dur` seconds from the next tick: `SimCore.step` returns false, consumes no input, and the match clock, cooldowns and fighters stand still (`S.pause.left` counts the ticks down). `kind` is `transform`, `world` or `timecap`; `actor` the fighter's slot, -1 for the time cap; `version` `full` or `short` | nothing; Camera plays its shot for `dur` of real time; the host decides what to do with presses made during it |
| `pause_end` | kind | Q10: the pause's last frozen tick; the next tick is live | nothing |
| `hide_start` | actor, cover | a fighter goes to ground (hidden); cover is submerged, canopy or ridge. Since S2 only a fighter with `canHide` (the future stealth fighter) hides; nobody in the base roster emits it | nothing |
| `found` | actor | the opponent regains lock on `actor` (spec-wounds.md §1c): line of sight returns, the hunter comes within 240, `actor` attacks, or 4 s pass. For a `canHide` fighter it still means found in hiding | nothing; the Found flash |
| `ko` | winner, loser | the match's KO (fighter slots). Since S2 only a lost finisher contest KOs | nothing; the KO banner arrives as a `banner` event |
| `decisive` | winner, loser, kind | a decisive exchange was won (spec-wounds.md §1): `kind` launch (any launch, however it lands), clash (a heavy clash won), guard_break, interrupt (a CHARGE INTERRUPT that ended in a shove), beam (a signature hit or guard) or beam_clash | nothing; Art's Pride flash |
| `finisher_start` | actor, target, dur | `actor` won a decisive exchange against `target` on the brink: the finisher replaces the rest of the exchange. `dur` (S3b) is the finisher's length in seconds from this event to its last beat, taking the longer of its two outcomes (Combat's finisher in `data/combat/finishers.json`) | nothing; the finisher set piece (Camera, UI) |
| `finisher_contest` | target, chance, survived | the fighter on the brink rolled against the finisher: `chance` is the survival chance, less 0.10 per minute past 8:00, floor 0. With the struggle (the authored finishers, S3b) it starts from 0.15, +0.10 per beat hit, -0.05 per beat missed and per stray press; without it (parity) from 0.30. One draw either way; a loss is followed by `ko` | nothing |
| `attack` | actor, target, kind, defStance, template, ambush | the director accepted an attack: `kind` light, heavy or sig; `defStance` the defender's stance or CHARGING; `template` the exchange's tag; `ambush` true only for a `canHide` fighter | nothing; the structured twin of the feed's attack line (QA-004) |
| `parry` | actor, target | `actor` parried `target`'s strike; the rest of the exchange is cancelled | nothing |
| `chain_end` | actor, n | a chain of `n` linked exchanges by `actor` ended | nothing |
| `ambush` | actor, target | an ambush attack from cover began (`canHide` fighters only) | nothing |
| `lock_lost` | actor, target | `actor` tried to attack `target` while lock was broken: the attempt costs 2 ki and a 0.5 s cooldown | nothing |
| `launch_plan` | actor, target, text, chosen | every launch decision: `text` lists every candidate as `NAME score` joined with `|`; `chosen` is the launch, or NONE for a shove | nothing; the planner's reasons (debug overlay, QA §5b) |
| `window_open` | actor, kind, dur, n | a window really opened (no window opens without this event): `kind` parry (`actor` the defender, `dur` until the first parryable strike), chain (`actor` the attacker, `dur` 0.6 s, `n` the exchange's chain count so far, 1 on the first, for the CHAIN xN chip; a press links number n + 1) or contest (S3b: the finisher struggle, `actor` the fighter on the brink, `dur` until the contest resolves). `n` is 0 on parry and contest windows | nothing; UI's window cue |
| `clash_draw` | actor, target | a clash ended in a draw (the heavy-clash shockwave) | nothing; Art's flash |
| `hazard_telegraph` | actor, source, eta, x | the world is about to hit `actor` at `x` in `eta` seconds (0 when unknown). `source` brunt (a launch predicted to hit a building) from the director; World adds collapse, landslide and lava | nothing; Art's Hazard flash |
| `searching` | actor, target, x, kind | `actor` searches for `target` around `x`. `kind` (S3b) is lock (`target` just broke lock, or `actor` tried to attack while it was broken: the Searching flash) or sweep (an AI hunt sweep to a new point near the last known position, for debug and QA) | nothing; the Searching flash on lock |
| `danger` | actor, source, eta | `actor` is about to be hit: `source` windup (a parryable strike winds up, `eta` until it lands) or ambush | nothing; Art's danger-sense flash |
| `launch` | actor, target, amount, face, ux, uy, n | `actor` was launched by `target` at speed `amount`, horizontally toward `face` (+1 or -1). `amount` is the drawn speed, `hypot(vx, vy)` of the fighter as it leaves: the horizontal part already carries the launch's traversal factor (`launchT`, up to TRAV_LAUNCH). Divide `vx` by `launchT` for the unboosted speed that impact damage and energy use `ux`, `uy`: the launch's unit direction before the traversal boost (L0). `n`: the launch number that pairs a journey's ground-contact events to it (0 until World's ground contact sets it) | nothing; Camera's launch follow |
| `rush` | actor, target, n | `actor` rushes to `target`, arriving at tick `n` | nothing; Camera |
| `cue` | actor, kind, text, source | a render-only cue from Combat's templates and finishers (the `cue` op, S3b; no state change, no draw): `kind` the cue name (the `cues` vocabulary in `data/combat/finishers.json` says what each looks like), `actor` the fighter the cue names (-1 for both), `text` a camera hint (push_in, tight, freeze_zoom and so on; empty for none), `source` a bark trigger id (finisher_landed, finisher_survived), `"true"` for a bark pause with no trigger yet, empty for none | nothing; VFX, Camera, Audio and UI |
| `struggle_press` | actor, kind, n | the finisher struggle scored a press by `actor`, the fighter on the brink (S3b): `kind` hit (on beat `n`, 1 to 3) or stray (off every beat, `n` 0). A press inside the debounce is not scored and sends nothing | nothing; UI's press marks |

### The `crater` and `scorch` events

Owner: World and Environment (`sim/world/crater.gd`; numbers and reasoning in `docs/world/craters-scorch-water.md`). Both carry gameplay facts, not just looks, and both are backed by persistent state ("What the renderer reads from the sim directly", below), so a renderer that joins late or seeks in a replay rebuilds everything from state and never depends on having seen the event.

`crater`: `x` is the centre (world x), `y` the ground height there before the dig, `r` the bowl radius (the rim crest is at `r`), `depth` the bowl depth actually applied (already limited by the local relief cap, so it can be less than a fresh hit would give), `rim` the rim height above the surrounding ground, `energy` the impact-energy scalar the size came from, `cause` one of `"impact"` (a launched fighter hits the ground, or a heavy-clash wave), `"beam"` (a beam's ground strike or a clash blast) or `"powerup"`, `skid` a signed offset from `x` to the tail of a furrow that runs into the bowl (0 for none), `special` true for the big marks (a signature, finisher, break launch or beam clash: its energy is 9 times an ordinary blow's), and `owner` the slot of the fighter that caused it (-1 for none). The z = 0 slice of the bowl is exactly `WorldCrater.profile(|dx| / r, depth, rim)` added to the ground, plus the furrow. Rendering draws the bowl in depth, round, with that slice as its profile.

`scorch`: one per beam sample that is within reach of the ground. `x` is the sample's world x, `y` the ground height before the groove was carved, `w` the groove's full width, `power` the beam-power scalar P (0.5 to 4.5: tier and charge, `WorldCrater.beamPower`), `variant` the beam's biome variant (`HORIZON CLEAVE`, `BOULEVARD RAZE`, `FIRESTORM`, `RIDGE BORE`, `GLASS TRENCH`, `MERIDIAN SCAR`) and `owner` the firing fighter's slot. Samples are at most 36 units apart along the beam, so a trail is a chain of these; the burn mark itself is `S.scorch` (permanent, per column).

Colours are CSS hex strings, as in the prototype. Replacing them with a palette is for Art and VFX.

## Consumer rules (the reference consumer)

Run once per tick, after `step`:
1. Consume events in order. Effect events spawn particles; `damage`, `banner` and `shake` update the presentation; `tick` steps existing particles and damage numbers.
2. At the end of the tick: if it wasn't frozen, advance the banner timer by dt and drop the banner after `dur`. Then decay the shake: `shake *= 0.02^dt`, using the tick's dt, even when frozen.
3. The camera adds the shake as screen jitter. The renderer takes that jitter from the `camera` stream.

Played in this order, the banner, the damage numbers and the shake match the prototype tick for tick (the parity check compares them). Particles use their own streams, so they look like the prototype's but not bit for bit.

## Cosmetic random streams

The canonical rule is in overview.md section 3. Each consumer has its own mulberry32 streams, reseeded at every match start from the match seed (`S.game.seed`) with `deriveSeed(seed, id)` (`sim/core/rng.js`, `rng.gd`). The derivation is integer-only, so every language agrees:

| id | used for |
| :--- | :--- |
| `vfx.spark`, `vfx.debris`, `vfx.dust`, `vfx.splash`, `vfx.fire` | the particles of each effect class |
| `vfx.charge` | the charge aura's spark and dust rolls (and the aura spark's spread) |
| `vfx.water` | the beam-splash roll |
| `camera` | screen-shake jitter (the prototype used `Math.random` here) |
| `audio` | reserved for Audio |

A renderer can use GPU particles or any other method: the stream contract only matters where cosmetic output has to be reproducible, as in replay videos or tests.

## What the renderer reads from the sim directly

Events carry only transient effects. Persistent visuals come from sim state, read after each tick and never written:
- fighters: `x, y, face, rot, state, stance, tier, hidden, beamCharge, aura, col, hair, name`
- `S.beams`: origin, direction, length, progress `p`, age `t`, `life`, width `w`, `col`
- `S.game.clash`: the beam-clash midpoint and its progress
- `S.game.ko`
- `S.dirS.ex.combo`: the chain counter
- terrain height: `groundY` and `seaAt`, or `S.base` and `S.deform`
- the world's persistent damage (GDScript sim), all rebuilt from state after a seek or a snapshot:
  - `S.craters`: an array of records, oldest first, capped at 400 (`WorldCrater.LIST_MAX`; the oldest is dropped, its dent stays in `S.deform`). Each has `x, y, r, depth, rim, energy, cause, owner, t, skid, sdepth`, the `crater` event's fields plus the match time `t` and the furrow's depth at the bowl `sdepth`. `S.deform` is the truth for the ground: it also holds the scorch grooves, which have no records, and the deform limits (-260 to +60) clip it, so do not rebuild it from the records; use them for the round bowls in depth.
  - `S.rubble`: rubble heap height per terrain column (already part of `S.deform`; kept apart for tint, cover and so that a later dig removes the heap first). `S.buildings` carry `z` (depth of the centre), `d` (footprint depth) and `row` (0 foreground, 1 front street, 2 mid, 3 back). `S.world.evacuated` counts the civilians who fled.
  - `S.slides`: an array of records like `S.craters`, capped at 200: `x0, x1, hw, depth, energy, t, owner, surface, pop` (the `slide` event's fields plus the match time and 1 for a paved start).
  - `S.crack`: pavement crack intensity per terrain column, 0 to 1, permanent, set by slides in city and village biomes (a `PackedFloat32Array` of `NC`). Rendering tints cracked pavement from it.
  - `S.scorch`: burn intensity per terrain column, 0 to 1, permanent (a `PackedFloat32Array` of `NC`, like `S.deform`).
  - `S.water`: water depth per terrain column (`PackedFloat32Array` of `SimConst.NC`). The surface of standing water is ground + depth, and it is sea level (0) once settled. A column is wet at 0.5 or more (`WorldWater.MIN_DEPTH`). `WorldWater.surfaceAt(S, x)` and `depthAt(S, x)` read it. The prototype's rule that water is drawn only where the base terrain is below -30 (`seaAt`) still holds for the sea; crater lakes that fill from the sea are the difference, and they exist only where the ground was dug below -30 and connects to the sea.
- buildings: `curH`, `alive`
- trees
- the `S.world` counters

The prototype's `draw*` functions show how each one was drawn.

## Prototype parity mode

`createSim({math: 'native', fxRng: 'shared'})` keeps the port tick-identical to the prototype. Each emitter also burns, on the gameplay stream, exactly the random draws the prototype's effect made (`core/fx.js`). This is a JS-only test mode that keeps the prototype usable as an oracle; the game runs det + split. The port harness and `sim/core/tools/parity.js` use it.

## Depth on events (L0, fight lanes)

Every positioned effect event carries `z`, the depth it happens at (0 is the fighter plane, positive toward the camera): `spark`, `ring`, `debris`, `dust`, `splash`, `fire`, `after`, `charge`, `beamSplash`, `damage`, `scorch`, `slide` (with `z1` for its far end), `slide_dust`, `skim` and `shake`. An emitter that takes a fighter reads his depth; one that takes a position takes `z` last and sends 0 when the caller gives none. The core's own calls pass the fighter's depth; World's and the director's pass theirs in their depth slices. Until the depth switch-on a fighter's `z` is 0 except during a flight aimed at a building.

World's ground contact (G3) sends `left_ground`, `bounce`, `land`, `tumble_end` and `journey_end` (fields in docs/world/ground-contact.md section 4). `tumble_end`: `kind` (stop, recover, air), `contacts`, `n`, and `dur`, the **ticks the body rolled in the tumble** (0 to 72; `journey_end.dur` is the whole journey in seconds).

## The intro phase and the last stand

| Event | Fields | When | Who reads it |
| :--- | :--- | :--- | :--- |
| `intro_start` | dur, delay | the first tick of a match whose setup says `"intro": true`: the pre-clock window opens, `dur` seconds long; a press on a human slot skips it after `delay` seconds | Camera, UI (the HUD stays hidden; the skip prompt) |
| `entrance_fall` | actor, x, y, z, y1, dur | a fighter starts to fall toward `x`, `y` (the ground), from height `y1`, for `dur` seconds. A, on the left start spot, falls first | Camera (it frames the sky before the landing), Animation |
| `entrance_land` | actor, x, y, z, y1, r | he touches down; the entrance crater is dug this tick (`r` its bowl radius, 0 if none). On a skip the landings left over come at once, in order | Camera, VFX, Animation, Audio |
| `staredown_start` | dur | both stand, for `dur` seconds, until the clock | Camera, Animation |
| `clock_start` | kind | the intro's last tick: the fight starts with the next tick. `kind` is `full`, or `skip` when a press ended it | Camera, UI (the HUD appears), Audio |
| `last_stand_ready` | actor, dur | `actor` reached the brink for the first time this match: one signature is free and off cooldown for `dur` seconds of his free time | Camera (the cut and the face cut-in), Narrative, UI |
| `last_stand_end` | actor, kind | the window closed: `used` (he fired) or `expired` | UI, Narrative |

An intro tick is a pre-clock tick: `SimCore.step` returns false and consumes no input, and the clock, the mood and every cooldown stand still. Its `tick` mark says `frozen: false`, so effects run at full speed and the landing's dust settles. A host tells an intro tick from a live one by the step's return value or `S.intro.left`. A match whose setup has no `"intro"` key starts from the intro's end state (the two craters dug, both fighters on the ground) and sends none of the intro's events.

## Shots, and the agency pass

| Event | Fields | When | Who reads it |
| :--- | :--- | :--- | :--- |
| `shot_fire` | actor, kind, id, x, y, z, target, spd, amount, link, ux, uy | a shot is fired by `actor`: its kind and id, where it starts, the slot it seeks (-1 for none), its speed and direction, its power (`amount`) and its volley's group (`link`) | VFX (the muzzle), Audio |
| `shot_hit` | actor, victim, kind, id, x, y, z, amount, outcome, link | the shot met `victim`; `amount` is the damage; `outcome` is `hit` by the plain rule, and the director's blasts send their own (guard, deflect and the rest) | VFX, Audio, Camera, the HUD |
| `shot_clash` | id, b, x, y, z, amount | two opposing shots (ids `id` and `b`) traded `amount` of power at x, y, z | VFX, Audio |
| `shot_end` | id, kind, x, y, z, cause | the shot is gone; `cause` is hit, clash, ground, water or life | VFX (it stops drawing the shot) |
| `knockback` | victim, attacker, kind, amount, dur, n, x, y, z | `victim` was sent back, not launched; `kind` is Combat's piece (a short slide, a long slide, a bump, a drift), `amount` the distance, `dur` its seconds, `n` the tick it ends | Animation, Camera, QA |
| `exchange_end` | actor, kind | `actor`'s exchange ended: `continue` (both stay in reach), `knockback` or `launch` | QA, Camera |
| `flow` | actor, n | `actor`'s flow count is now `n` | the HUD's recipe strip, QA |
| `embed` | actor, x, y, z, depth, r, energy, dur, n | `actor` is driven into the ground: the crater's floor, its depth and radius, the impact's energy, the seconds he stays down, his launch number | Animation, Camera, VFX |

A renderer draws shots in flight from `S.shots` (position, velocity, kind, owner, power), as it reads `S.beams`. `knockback`, `exchange_end` and `flow` are sent by the director and `embed` by World's contact model; until their slices land none of the eight is sent in a match.

