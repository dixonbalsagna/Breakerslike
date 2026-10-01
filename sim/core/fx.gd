class_name SimFx
## Cosmetic effects leave the sim as events: the twin of fx.js (docs/architecture/fx-events.md). Each function appends
## one FxEvent to S.out.fx and changes no sim state; the render side (view/fx.gd is the reference consumer) turns them
## into particles, damage numbers, the banner and camera shake with its own cosmetic streams. The GDScript core has
## only the canonical 'split' mode, so no emitter draws anything (fx.js's 'shared' mode exists for prototype parity).


static func _ev(S: SimState, type: String) -> SimState.FxEvent:
	var e := SimState.FxEvent.new()
	e.type = type
	e.tick = S.tick
	S.out.fx.append(e)
	return e


## L0 (fight lanes): every positioned event carries z, the depth it happens at (0 is the fighter plane). The emitters
## that take a position take z last, 0 by default; the ones that take a fighter read his.
static func spark(S: SimState, x: float, y: float, n: int, col: String, spd: float, z: float = 0.0) -> void:
	var e := _ev(S, "spark")
	e.x = x; e.y = y; e.n = n; e.z = z
	e.col = col if col != "" else "#fff3c0"
	e.spd = spd if spd != 0.0 else 500.0


static func ring(S: SimState, x: float, y: float, gr: float, col: String, life: float, r0: float, z: float = 0.0) -> void:
	var e := _ev(S, "ring")
	e.x = x; e.y = y; e.gr = gr; e.z = z
	e.col = col if col != "" else "#ffffff"
	e.life = life if life != 0.0 else 0.5
	e.r0 = r0 if r0 != 0.0 else 10.0


static func debris(S: SimState, x: float, y: float, n: int, col: String, spd: float, z: float = 0.0) -> void:
	var e := _ev(S, "debris")
	e.x = x; e.y = y; e.n = n; e.z = z
	e.col = col if col != "" else "#6d6a66"
	e.spd = spd if spd != 0.0 else 500.0


static func dust(S: SimState, x: float, y: float, n: int, col: String = "", z: float = 0.0) -> void:
	var e := _ev(S, "dust")
	e.x = x; e.y = y; e.n = n; e.z = z
	e.col = col if col != "" else "#9b8f7e"


static func splash(S: SimState, x: float, y: float, n: int, z: float = 0.0) -> void:
	var e := _ev(S, "splash")
	e.x = x; e.y = y; e.n = n; e.z = z


static func fire(S: SimState, x: float, y: float, n: int, z: float = 0.0) -> void:
	var e := _ev(S, "fire")
	e.x = x; e.y = y; e.n = n; e.z = z


## An afterimage of f: 0.45 s for a dodge or escape, 0.16 s for each tick of a rush trail.
static func afterimage(S: SimState, f, life: float = 0.45) -> void:
	var e := _ev(S, "after")
	e.x = f.x; e.y = f.y; e.z = f.z; e.life = life; e.col = f.aura; e.face = f.face


static func banner(S: SimState, text: String, col: String, dur: float) -> void:
	var e := _ev(S, "banner")
	e.text = text
	e.col = col if col != "" else "#ffffff"
	e.dur = dur if dur != 0.0 else 1.3


## A damage number; the consumer prints String(Math.round(amount)).
## A damage event: who hit whom, where on the body and how. x, y is where a damage number shows; number is false
## for landings and collisions, which never showed one.
static func damage(S: SimState, f, attacker, amount: float, region: String, kind: String, col: String, number: bool) -> void:
	var e := _ev(S, "damage")
	e.x = f.x; e.y = f.y + 90.0; e.z = f.z; e.amount = amount; e.col = col
	e.victim = float(S.fighters.find(f)); e.attacker = -1.0 if attacker == null else float(S.fighters.find(attacker))
	e.region = region; e.kind = kind; e.number = number


## Camera shake request: the consumer keeps shake = max(shake, k) and decays it at the end of the tick. x is the world x
## of the cause, so a split-screen camera can shake only the pane that shows it.
static func shake(S: SimState, k: float, x: float, z: float = 0.0) -> void:
	var e := _ev(S, "shake")
	e.k = k
	e.x = x
	e.z = z


## A charging fighter's aura, once per charging tick (the consumer rolls its sparks and dust).
static func chargeFx(S: SimState, f, ground: float) -> void:
	var e := _ev(S, "charge")
	e.x = f.x; e.y = f.y; e.z = f.z; e.col = f.aura; e.ground = ground


## A crater was dug (world/crater.gd): the persistent record's fields, as the render side needs them.
static func crater(S: SimState, c) -> void:
	var e := _ev(S, "crater")
	e.x = c.x; e.y = c.y; e.r = c.r; e.depth = c.depth; e.energy = c.energy; e.cause = c.cause
	e.rim = c.rim; e.skid = c.skid; e.owner = c.owner; e.special = c.special > 0.5


## A beam sample scorched the ground: x, ground height, groove width, the beam-power scalar, the variant and the owner.
## A knockback slide ended (world/slide.gd): the whole trench, start to end.
static func slideEvent(S: SimState, r) -> void:
	var e := _ev(S, "slide")
	e.pop = r.pop
	e.x = r.x0; e.x1 = r.x1; e.z = r.z0; e.z1 = r.z1; e.w = r.hw * 2.0; e.depth = r.depth; e.energy = r.energy
	e.variant = "paved" if r.surface > 0.5 else "ground"; e.owner = r.owner


## A sample along a slide, for dust and chips: x, ground height, normalised speed, trench width, surface, index.
static func slideDust(S: SimState, x: float, y: float, v: float, w: float, surface: String, i: int, z: float = 0.0) -> void:
	var e := _ev(S, "slide_dust")
	e.x = x; e.y = y; e.z = z; e.spd = v; e.w = w; e.variant = surface; e.n = i


## One skip off the water: x, surface height, speed, skip number.
static func skim(S: SimState, x: float, y: float, v: float, i: int, z: float = 0.0) -> void:
	var e := _ev(S, "skim")
	e.x = x; e.y = y; e.z = z; e.spd = v; e.n = i


static func scorchEvent(S: SimState, x: float, y: float, w: float, power: float, variant: String, owner: float, z: float = 0.0) -> void:
	var e := _ev(S, "scorch")
	e.x = x; e.y = y; e.z = z; e.w = w; e.power = power; e.variant = variant; e.owner = owner


## A beam sample low over water (the consumer rolls the splash).
static func beamSplash(S: SimState, x: float, z: float = 0.0) -> void:
	var e := _ev(S, "beamSplash")
	e.x = x
	e.z = z


## Wounds (wounds.gd): a region changed stage.
static func regionStage(S: SimState, f, region: String, stage: int) -> void:
	var e := _ev(S, "region_stage")
	e.actor = float(S.fighters.find(f)); e.region = region; e.stage = stage


## Wounds: a region reached broken (also reported as a region_stage).
static func regionBroken(S: SimState, f, region: String) -> void:
	var e := _ev(S, "region_broken")
	e.actor = float(S.fighters.find(f)); e.region = region


## Wounds: the fighter is on the brink (the core broken, or two of head, arms and legs broken).
static func brinkEnter(S: SimState, f) -> void:
	var e := _ev(S, "brink_enter")
	e.actor = float(S.fighters.find(f))


## The brink chapter (spec-wounds.md §1b): actor, on the brink, is open to target's finisher. It is staggered with its
## guard dropped, and the finisher telegraphs: kind is the finisher's kind (launch, melee or beam; empty until Combat's
## finishers carry one), text the finisher's id.
static func brinkOpen(S: SimState, f, target, kind: String, finisher: String) -> void:
	var e := _ev(S, "brink_open")
	e.actor = float(S.fighters.find(f)); e.target = float(S.fighters.find(target)); e.kind = kind; e.text = finisher


## The opening on actor closed. kind: won (actor won a decisive exchange), survived (it survived a finisher) or rally
## (a Rally took it off the brink). The rival needs a new set-up.
static func brinkClose(S: SimState, f, kind: String) -> void:
	var e := _ev(S, "brink_close")
	e.actor = float(S.fighters.find(f)); e.kind = kind


static func brinkExit(S: SimState, f) -> void:
	var e := _ev(S, "brink_exit")
	e.actor = float(S.fighters.find(f))


## Structured event log (QA-004) for the core's feed lines: a fighter reached a new tier.
static func tierUp(S: SimState, f, onGround: bool) -> void:
	var e := _ev(S, "tier_up")
	e.actor = float(S.fighters.find(f)); e.tier = f.tier; e.onGround = onGround


## Step 2b: actor's signature reached its fire beat and its outcome was decided there (target the defender): kind is
## CLASH, GUARD, DODGE, ESCAPE, HIT or DEFLECT. The attack event at the request no longer carries it.
static func beamOutcome(S: SimState, f, target, kind: String) -> void:
	var e := _ev(S, "beam_outcome")
	e.actor = float(S.fighters.find(f)); e.target = float(S.fighters.find(target)); e.kind = kind


## I2b, the placeholder transform (ADR 0008): actor's power crossed a threshold and tier waits for the transform input.
## source is the input that takes it: triggers (the two-trigger chord), power (the power hold of the Simple layout and of
## today's keyboard and touch) or ai.
static func transformReady(S: SimState, f, tier: float, source: String) -> void:
	var e := _ev(S, "transform_ready")
	e.actor = float(S.fighters.find(f)); e.tier = tier; e.source = source


## actor took the transform: tier is its new tier, source the input that took it, dur the hold in seconds. The tier_up
## (the power-up burst) comes in the same tick, at the start of the hold.
static func transform(S: SimState, f, tier: float, source: String, dur: float, version: String = "live") -> void:
	var e := _ev(S, "transform")
	e.actor = float(S.fighters.find(f)); e.tier = tier; e.source = source; e.dur = dur; e.version = version
	e.gather = float(SimPause.gatherOf(version)) / float(SimPause.TPS)


## Q10: a pausing set piece starts: the sim is frozen for dur seconds from the next tick. kind: transform, world or
## timecap; actor: the fighter's slot, -1 for the time cap; version: full or short (a live version does not pause).
static func pauseStart(S: SimState, kind: String, slot: int, version: String, dur: float) -> void:
	var e := _ev(S, "pause_start")
	e.kind = kind; e.actor = float(slot); e.version = version; e.dur = dur


## Q10: the pause's last frozen tick: the next tick is live.
static func pauseEnd(S: SimState, kind: String) -> void:
	var e := _ev(S, "pause_end")
	e.kind = kind


## The fighter went to ground (hidden); cover is submerged, canopy or ridge.
static func hideStart(S: SimState, f, cover: String) -> void:
	var e := _ev(S, "hide_start")
	e.actor = float(S.fighters.find(f)); e.cover = cover


## A hidden fighter was found by the opponent closing in.
static func found(S: SimState, f) -> void:
	var e := _ev(S, "found")
	e.actor = float(S.fighters.find(f))


## The match's KO.
static func ko(S: SimState, winner, loser) -> void:
	var e := _ev(S, "ko")
	e.winner = float(S.fighters.find(winner)); e.loser = float(S.fighters.find(loser))


# ---------------------------------------------------------------- director events (Encounter, S2)
# Structured events for the Wounds ending, QA-004's director feed lines, Art's head flashes and UI. Slots are fighter indices.

## A decisive exchange was won (spec-wounds.md §1). kind: launch, clash, guard_break, interrupt, beam or beam_clash.
static func decisive(S: SimState, winner, loser, why: String) -> void:
	var e := _ev(S, "decisive")
	e.winner = float(S.fighters.find(winner)); e.loser = float(S.fighters.find(loser)); e.kind = why


## M1: the mood's band changed (after its dwell): kind calm, tense or frenzied; amount the mood in points; n the act.
static func moodBand(S: SimState, band: String, points: float, act: int) -> void:
	var e := _ev(S, "mood_band")
	e.kind = band; e.amount = points; e.n = act


## M1: the act rose to n; kind is the cause (break, core or form).
static func actChange(S: SimState, act: int, cause: String) -> void:
	var e := _ev(S, "act_change")
	e.n = act; e.kind = cause


## M1: f's style label: kind the new label ("" when one ends with none to follow), text the previous one ("" if none).
static func styleLabel(S: SimState, f, label: String, prev: String) -> void:
	var e := _ev(S, "style_label")
	e.actor = float(S.fighters.find(f)); e.kind = label; e.text = prev


## M1: the crowd output changed: excited, nervous or fleeing.
static func crowdState(S: SimState, crowd: String) -> void:
	var e := _ev(S, "crowd_state")
	e.kind = crowd


## B2: the launched fighter f will hit building bi first: the first hit point (x1, y1) at depth z1, in dur seconds, and the
## planned chain length n. owner is the launcher's slot, victim the launched fighter's.
static func launchDepth(S: SimState, f, att, x1: float, y1: float, z1: float, bi: int, dur: float, n: int) -> void:
	var e := _ev(S, "launch_depth")
	e.x = f.x; e.y = f.y; e.x1 = x1; e.y1 = y1; e.z = z1; e.b = float(bi); e.dur = dur; e.n = n
	e.owner = float(S.fighters.find(att)); e.victim = float(S.fighters.find(f))


## B2: the launched fighter f hit building b at height y (link-th of this flight): M1's {actor, x, n} plus the hit's detail.
## oc is WorldBrunt.outcomeOf's result; outcome the summary word (punch, crack, dent, pancake, collapse, heavy, wreck).
static func buildingHitB2(S: SimState, f, b, y: float, link: int, by, oc: Dictionary, outcome: String, spN: float) -> void:
	var e := _ev(S, "building_hit")
	e.actor = float(S.fighters.find(f)); e.x = b.x; e.n = link
	e.b = float(b.idx); e.y = y; e.z = WorldBrunt.faceZ(b); e.amount = oc.dmg; e.ratio = oc.ratio; e.outcome = outcome
	e.link = link; e.spd = spN; e.keep = oc.keep
	var l: float = SimDetMath.hypot(f.vx / f.launchT, f.vy)
	e.ux = f.vx / f.launchT / maxf(l, 0.000001); e.uy = f.vy / maxf(l, 0.000001)
	e.kind = b.kind; e.w = b.w; e.h = WorldStructures.curH(b)
	e.owner = float(S.fighters.find(by)); e.victim = e.actor


## B2: after a burst through building b the fighter heads for nb: from b's far face at height y to nb's near face.
static func chainLink(S: SimState, f, att, b, nb, y: float, r: Dictionary, link: int) -> void:
	var e := _ev(S, "chain_link")
	e.from = float(b.idx); e.to = float(nb.idx)
	e.x = f.x; e.y = y; e.z = WorldBrunt.faceZ(b); e.x1 = r.x; e.y1 = r.y; e.z1 = WorldBrunt.faceZ(nb)
	e.dur = r.t; e.link = link
	e.owner = float(S.fighters.find(att)); e.victim = float(S.fighters.find(f))


## B2: a brunt hit floors of a skyscraper: the lowest floor, how many were cleared (0 for a crack or a dent).
static func floorHit(S: SimState, f, b, floor_: int, n: int, outcome: String, ratio: float, y: float, by) -> void:
	var e := _ev(S, "floor_hit")
	e.b = float(b.idx); e.floor = floor_; e.n = n; e.outcome = outcome; e.ratio = ratio
	e.x = b.x; e.y = y; e.z = WorldBrunt.faceZ(b)
	var l: float = SimDetMath.hypot(f.vx / f.launchT, f.vy)
	e.ux = f.vx / f.launchT / maxf(l, 0.000001); e.uy = f.vy / maxf(l, 0.000001)
	e.kind = b.kind; e.owner = float(S.fighters.find(by)); e.victim = float(S.fighters.find(f))


## B2: a stack of floors pancaked: floors from..to (inclusive) of building b fell, n in all (broken floors, the stack, and
## the floors that were already gone between).
static func floorsFall(S: SimState, b, from_floor: int, to_floor: int, n: int) -> void:
	var e := _ev(S, "floors_fall")
	e.b = float(b.idx); e.from = float(from_floor); e.to = float(to_floor); e.n = n
	e.x = b.x; e.z = WorldBrunt.faceZ(b); e.w = b.w


## Pitch A: W broke L's limb (region) in a crippling moment.
static func limbBreak(S: SimState, W, L, region: String) -> void:
	var e := _ev(S, "limb_break")
	e.actor = float(S.fighters.find(W)); e.victim = float(S.fighters.find(L)); e.region = region


## S4: f rallied by rule kind (second_wind, spite, ...), mending region (now battered at 89).
static func rally(S: SimState, f, region: String, kind: String) -> void:
	var e := _ev(S, "rally")
	e.actor = float(S.fighters.find(f)); e.region = region; e.kind = kind


## dur: the finisher's length in seconds (Combat's template), so the HUD and Camera need not guess.
static func finisherStart(S: SimState, f, target, dur: float = 0.0) -> void:
	var e := _ev(S, "finisher_start")
	e.actor = float(S.fighters.find(f)); e.target = float(S.fighters.find(target)); e.dur = dur


## The fighter on the brink rolled against the finisher: the chance to survive, and whether he did.
static func finisherContest(S: SimState, target, chance: float, survived: bool) -> void:
	var e := _ev(S, "finisher_contest")
	e.target = float(S.fighters.find(target)); e.chance = chance; e.survived = survived


## An attack request the director accepted: the kind (light, heavy, sig), the defender's stance, the template tag.
static func attack(S: SimState, f, target, kind: String, defStance: String, template: String, ambush: bool) -> void:
	var e := _ev(S, "attack")
	e.actor = float(S.fighters.find(f)); e.target = float(S.fighters.find(target)); e.kind = kind
	e.defStance = defStance; e.template = template; e.ambush = ambush


## actor parried target's strike.
static func parry(S: SimState, f, target) -> void:
	var e := _ev(S, "parry")
	e.actor = float(S.fighters.find(f)); e.target = float(S.fighters.find(target))


## A chain of n linked exchanges ended.
static func chainEnd(S: SimState, f, n: int) -> void:
	var e := _ev(S, "chain_end")
	e.actor = float(S.fighters.find(f)); e.n = n


## An ambush attack from cover began.
static func ambush(S: SimState, f, target) -> void:
	var e := _ev(S, "ambush")
	e.actor = float(S.fighters.find(f)); e.target = float(S.fighters.find(target))


## actor tried to attack target, who is hidden: no lock-on.
static func lockLost(S: SimState, f, target) -> void:
	var e := _ev(S, "lock_lost")
	e.actor = float(S.fighters.find(f)); e.target = float(S.fighters.find(target))


## A launch decision: every candidate as "NAME score", joined with "|", and the chosen one (NONE for a shove).
static func launchPlan(S: SimState, f, target, candidates: String, chosen: String) -> void:
	var e := _ev(S, "launch_plan")
	e.actor = float(S.fighters.find(f)); e.target = float(S.fighters.find(target)); e.text = candidates; e.chosen = chosen


## A parry, chain or contest window really opened for actor (the fighter who can press), lasting dur seconds. n is the
## chain count for a chain window (the CHAIN xN chip), 0 otherwise.
static func windowOpen(S: SimState, f, kind: String, dur: float, n: int = 0) -> void:
	var e := _ev(S, "window_open")
	e.actor = float(S.fighters.find(f)); e.kind = kind; e.dur = dur; e.n = n


## A clash ended in a draw (the heavy-clash shockwave; later a blocked finisher).
static func clashDraw(S: SimState, a, b) -> void:
	var e := _ev(S, "clash_draw")
	e.actor = float(S.fighters.find(a)); e.target = float(S.fighters.find(b))


## The world is about to hit actor. source: brunt (a launch into a building) from the director; World adds collapse,
## landslide and lava. eta in seconds (0 when unknown); x where it will hit.
static func hazardTelegraph(S: SimState, f, source: String, eta: float, x: float) -> void:
	var e := _ev(S, "hazard_telegraph")
	e.actor = float(S.fighters.find(f)); e.source = source; e.eta = eta; e.x = x


## actor is searching for target around x. kind: lock (the target broke lock) or sweep (an AI hunt sweep).
static func searching(S: SimState, f, target, x: float, kind: String = "lock") -> void:
	var e := _ev(S, "searching")
	e.actor = float(S.fighters.find(f)); e.target = float(S.fighters.find(target)); e.x = x; e.kind = kind


## A render-only cue from Combat's templates (the cue op): cue name in kind, actor the named fighter (-1 for both), text
## the camera hint, source the bark trigger ("true" for a bark pause with no trigger yet).
static func cue(S: SimState, f, name: String, cam: String, bark: String) -> void:
	var e := _ev(S, "cue")
	e.actor = float(S.fighters.find(f)) if f != null else -1.0; e.kind = name; e.text = cam; e.source = bark


## The finisher struggle scored a press by actor: kind hit (beat n, 1 to 3) or stray (n 0).
static func strugglePress(S: SimState, f, kind: String, n: int) -> void:
	var e := _ev(S, "struggle_press")
	e.actor = float(S.fighters.find(f)); e.kind = kind; e.n = n


## A ground-contact event (World, G3; world/contact.gd): left_ground, bounce, land, tumble_end, journey_end. Every one
## carries the body's x, y, z, speed and the launch number n; the caller sets the rest.
static func contactEvent(S: SimState, type: String, f, x: float, y: float, speed: float) -> SimState.FxEvent:
	var e := _ev(S, type)
	e.actor = float(S.fighters.find(f))
	e.x = x
	e.y = y
	e.z = f.z
	e.spd = speed
	e.n = int(f.launchN)
	return e


## Camera: actor was launched by target at speed amount, horizontally toward face (+1 or -1). ux, uy: the launch's unit
## direction before the traversal boost (from the fighter's velocity, which the launch has just set), so Animation's first
## frame points the right way. n: the launch number that pairs a journey's events (World's launchN; 0 until it lands).
static func launch(S: SimState, f, by, speed: float, dir: float, n: int = 0) -> void:
	var e := _ev(S, "launch")
	e.actor = float(S.fighters.find(f)); e.target = float(S.fighters.find(by)) if by != null else -1.0
	e.amount = speed; e.face = dir; e.n = n
	var hx: float = f.vx / f.launchT
	var d: float = SimDetMath.hypot(hx, f.vy)
	if d > 0.0:
		e.ux = hx / d
		e.uy = f.vy / d


## Camera: actor rushes to target, arriving at tick n.
static func rush(S: SimState, f, target, endTick: int) -> void:
	var e := _ev(S, "rush")
	e.actor = float(S.fighters.find(f)); e.target = float(S.fighters.find(target)) if target != null else -1.0; e.n = endTick


## Danger sense: actor is about to be hit. source windup: a parryable strike is winding up; ambush: an ambush is on him.
static func danger(S: SimState, f, source: String, eta: float) -> void:
	var e := _ev(S, "danger")
	e.actor = float(S.fighters.find(f)); e.source = source; e.eta = eta


## Civilians fled instead of dying (world/collateral.gd): the building, its x, how many (a float head count), the x the
## crowd flees from, the reason ("budget", "ceiling" or "flight") and the fighter's slot who caused it.
static func evacuate(S: SimState, b: int, x: float, n: float, cx: float, reason: String, owner: float, dest: int = -1, floor_: int = -1) -> void:
	var e := _ev(S, "evacuate")
	e.b = float(b); e.x = x; e.n = n; e.cx = cx; e.reason = reason; e.owner = owner; e.dest = float(dest); e.floor = floor_


## A building fell (any source). mode "implode" is area damage (straight down into its footprint, staggered by delay),
## "burst" a launch through it; rubble is the heap left; n folds in further implodes of the same blast past the event cap.
static func buildingFall(S: SimState, b: int, x: float, z: float, w: float, h: float, mode: String, delay: float, cx: float, rubble: float, n: float) -> void:
	var e := _ev(S, "building_fall")
	e.b = float(b); e.x = x; e.y = z; e.w = w; e.depth = h; e.mode = mode; e.delay = delay; e.cx = cx; e.rubble = rubble; e.n = n


## The collateral window once a second: the room left, the budget, the ceiling left, and whether the window is over.
static func collateralState(S: SimState, room: float, budget: float, left: float, over: bool) -> void:
	var e := _ev(S, "collateral_state")
	e.room = room; e.budget = budget; e.left = left; e.over = over


## End of the sim's part of a tick: where the prototype stepped its particles (dt, or dt*0.1 during hit-stop).
static func tickMark(S: SimState, dt: float, frozen: bool) -> void:
	var e := _ev(S, "tick")
	e.dt = dt; e.frozen = frozen
