class_name SimFx
## Cosmetic effects leave the sim as events: the twin of fx.js (docs/architecture/fx-events.md). Each function appends
## one FxEvent to S.out.fx and changes no sim state; the render side (view/fx.gd is the reference consumer) turns them
## into particles, damage numbers, the banner and camera shake with its own cosmetic streams. The GDScript core has
## only the canonical 'split' mode, so no emitter draws anything (fx.js's 'shared' mode exists for prototype parity).


static func _ev(S: SimState, type: String) -> SimState.FxEvent:
	var e := SimState.FxEvent.new()
	e.type = type
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
static func damageNumber(S: SimState, x: float, y: float, amount: float, col: String) -> void:
	var e := _ev(S, "damage")
	e.x = x; e.y = y; e.amount = amount; e.col = col


## Camera shake request: the consumer keeps shake = max(shake, k) and decays it at the end of the tick.
static func shake(S: SimState, k: float) -> void:
	var e := _ev(S, "shake")
	e.k = k


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
static func scorchEvent(S: SimState, x: float, y: float, w: float, power: float, variant: String, owner: float) -> void:
	var e := _ev(S, "scorch")
	e.x = x; e.y = y; e.w = w; e.power = power; e.variant = variant; e.owner = owner


## A beam sample low over water (the consumer rolls the splash).
static func beamSplash(S: SimState, x: float) -> void:
	var e := _ev(S, "beamSplash")
	e.x = x


## End of the sim's part of a tick: where the prototype stepped its particles (dt, or dt*0.1 during hit-stop).
static func tickMark(S: SimState, dt: float, frozen: bool) -> void:
	var e := _ev(S, "tick")
	e.dt = dt; e.frozen = frozen
