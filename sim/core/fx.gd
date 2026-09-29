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


static func spark(S: SimState, x: float, y: float, n: int, col: String, spd: float) -> void:
	var e := _ev(S, "spark")
	e.x = x; e.y = y; e.n = n
	e.col = col if col != "" else "#fff3c0"
	e.spd = spd if spd != 0.0 else 500.0


static func ring(S: SimState, x: float, y: float, gr: float, col: String, life: float, r0: float) -> void:
	var e := _ev(S, "ring")
	e.x = x; e.y = y; e.gr = gr
	e.col = col if col != "" else "#ffffff"
	e.life = life if life != 0.0 else 0.5
	e.r0 = r0 if r0 != 0.0 else 10.0


static func debris(S: SimState, x: float, y: float, n: int, col: String, spd: float) -> void:
	var e := _ev(S, "debris")
	e.x = x; e.y = y; e.n = n
	e.col = col if col != "" else "#6d6a66"
	e.spd = spd if spd != 0.0 else 500.0


static func dust(S: SimState, x: float, y: float, n: int, col: String = "") -> void:
	var e := _ev(S, "dust")
	e.x = x; e.y = y; e.n = n
	e.col = col if col != "" else "#9b8f7e"


static func splash(S: SimState, x: float, y: float, n: int) -> void:
	var e := _ev(S, "splash")
	e.x = x; e.y = y; e.n = n


static func fire(S: SimState, x: float, y: float, n: int) -> void:
	var e := _ev(S, "fire")
	e.x = x; e.y = y; e.n = n


## An afterimage of f: 0.45 s for a dodge or escape, 0.16 s for each tick of a rush trail.
static func afterimage(S: SimState, f, life: float = 0.45) -> void:
	var e := _ev(S, "after")
	e.x = f.x; e.y = f.y; e.life = life; e.col = f.aura; e.face = f.face


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
	e.x = f.x; e.y = f.y + 90.0; e.amount = amount; e.col = col
	e.victim = float(S.fighters.find(f)); e.attacker = -1.0 if attacker == null else float(S.fighters.find(attacker))
	e.region = region; e.kind = kind; e.number = number


## Camera shake request: the consumer keeps shake = max(shake, k) and decays it at the end of the tick. x is the world x
## of the cause, so a split-screen camera can shake only the pane that shows it.
static func shake(S: SimState, k: float, x: float) -> void:
	var e := _ev(S, "shake")
	e.k = k
	e.x = x


## A charging fighter's aura, once per charging tick (the consumer rolls its sparks and dust).
static func chargeFx(S: SimState, f, ground: float) -> void:
	var e := _ev(S, "charge")
	e.x = f.x; e.y = f.y; e.col = f.aura; e.ground = ground


## A crater was dug (world/crater.gd): the persistent record's fields, as the render side needs them.
static func crater(S: SimState, c) -> void:
	var e := _ev(S, "crater")
	e.x = c.x; e.y = c.y; e.r = c.r; e.depth = c.depth; e.energy = c.energy; e.cause = c.cause
	e.rim = c.rim; e.skid = c.skid; e.owner = c.owner


## A beam sample scorched the ground: x, ground height, groove width, the beam-power scalar, the variant and the owner.
## A knockback slide ended (world/slide.gd): the whole trench, start to end.
static func slideEvent(S: SimState, r) -> void:
	var e := _ev(S, "slide")
	e.x = r.x0; e.x1 = r.x1; e.w = r.hw * 2.0; e.depth = r.depth; e.energy = r.energy
	e.variant = "paved" if r.surface > 0.5 else "ground"; e.owner = r.owner


## A sample along a slide, for dust and chips: x, ground height, normalised speed, trench width, surface, index.
static func slideDust(S: SimState, x: float, y: float, v: float, w: float, surface: String, i: int) -> void:
	var e := _ev(S, "slide_dust")
	e.x = x; e.y = y; e.spd = v; e.w = w; e.variant = surface; e.n = i


## One skip off the water: x, surface height, speed, skip number.
static func skim(S: SimState, x: float, y: float, v: float, i: int) -> void:
	var e := _ev(S, "skim")
	e.x = x; e.y = y; e.spd = v; e.n = i


static func scorchEvent(S: SimState, x: float, y: float, w: float, power: float, variant: String, owner: float) -> void:
	var e := _ev(S, "scorch")
	e.x = x; e.y = y; e.w = w; e.power = power; e.variant = variant; e.owner = owner


## A beam sample low over water (the consumer rolls the splash).
static func beamSplash(S: SimState, x: float) -> void:
	var e := _ev(S, "beamSplash")
	e.x = x


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


static func brinkExit(S: SimState, f) -> void:
	var e := _ev(S, "brink_exit")
	e.actor = float(S.fighters.find(f))


## Structured event log (QA-004) for the core's feed lines: a fighter reached a new tier.
static func tierUp(S: SimState, f, onGround: bool) -> void:
	var e := _ev(S, "tier_up")
	e.actor = float(S.fighters.find(f)); e.tier = f.tier; e.onGround = onGround


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


## Camera: actor was launched by target at speed amount, horizontally toward face (+1 or -1).
static func launch(S: SimState, f, by, speed: float, dir: float) -> void:
	var e := _ev(S, "launch")
	e.actor = float(S.fighters.find(f)); e.target = float(S.fighters.find(by)) if by != null else -1.0
	e.amount = speed; e.face = dir


## Camera: actor rushes to target, arriving at tick n.
static func rush(S: SimState, f, target, endTick: int) -> void:
	var e := _ev(S, "rush")
	e.actor = float(S.fighters.find(f)); e.target = float(S.fighters.find(target)) if target != null else -1.0; e.n = endTick


## Danger sense: actor is about to be hit. source windup: a parryable strike is winding up; ambush: an ambush is on him.
static func danger(S: SimState, f, source: String, eta: float) -> void:
	var e := _ev(S, "danger")
	e.actor = float(S.fighters.find(f)); e.source = source; e.eta = eta


## End of the sim's part of a tick: where the prototype stepped its particles (dt, or dt*0.1 during hit-stop).
static func tickMark(S: SimState, dt: float, frozen: bool) -> void:
	var e := _ev(S, "tick")
	e.dt = dt; e.frozen = frozen
