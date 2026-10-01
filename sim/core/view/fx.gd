class_name SimFxView
extends RefCounted
## Reference cosmetic consumer (render side): the twin of view/fx.js. It turns the sim's fx events into particles,
## damage numbers, the banner and camera shake, reads the sim (terrain height) and never writes it. Its random numbers
## come from cosmetic streams seeded from the match seed, one per effect class (the canonical RNG rule).

const STREAMS: Array = ["vfx.spark", "vfx.debris", "vfx.dust", "vfx.splash", "vfx.fire", "vfx.charge", "vfx.water"]

var parts: Array = []
var floats: Array = []
var banner = null            # Banner or null
var shake: float = 0.0
var rng: Dictionary = {}     # stream id -> SimRng


## A particle. The defaults are fx.js P()'s; face exists only on afterimages (null elsewhere, like JS undefined).
class Part:
	var life: float = 1.0
	var age: float = 0.0
	var grav: float = 0.0
	var drag: float = 0.0
	var size: float = 3.0
	var col: String = "#fff"
	var type: String = "dot"
	var vx: float = 0.0
	var vy: float = 0.0
	var r: float = 0.0
	var gr: float = 0.0
	var x: float = 0.0
	var y: float = 0.0
	var face = null


class DmgFloat:
	var x: float = 0.0
	var y: float = 0.0
	var txt: String = ""
	var t: float = 0.0
	var col: String = ""


class Banner:
	var text: String = ""
	var col: String = ""
	var t: float = 0.0
	var dur: float = 0.0


func _init(seed: int = 1) -> void:
	reset(seed)


## A new match: empty the view and reseed every stream from the match seed.
func reset(seed: int) -> void:
	parts.clear()
	floats.clear()
	banner = null
	shake = 0.0
	for id in STREAMS:
		rng[id] = SimRng.new(SimRng.deriveSeed(seed, id))


func _P(p: Part) -> void:
	if parts.size() > 2400:
		return
	parts.append(p)


func _spark(x: float, y: float, n: int, col: String, spd: float, r: SimRng) -> void:
	for i in range(n):
		var a: float = r.range_(0.0, 6.283)
		var s: float = r.range_(0.3, 1.0) * spd
		var p := Part.new()
		p.type = "spark"; p.x = x; p.y = y
		p.vx = SimDetMath.cos(a) * s
		p.vy = SimDetMath.sin(a) * s
		p.life = r.range_(0.15, 0.4)
		p.col = col
		p.size = r.range_(1.5, 3.0)
		_P(p)


func _debris(x: float, y: float, n: int, col: String, spd: float, r: SimRng) -> void:
	for i in range(n):
		var a: float = r.range_(0.2, 2.9)
		var s: float = r.range_(0.2, 1.0) * spd
		var p := Part.new()
		p.type = "deb"
		p.x = x + r.range_(-20.0, 20.0)
		p.y = y
		p.vx = SimDetMath.cos(a) * s * (-1.0 if r.next() < 0.5 else 1.0)
		p.vy = SimDetMath.sin(a) * s
		p.grav = 900.0
		p.life = r.range_(0.8, 1.8)
		p.col = col
		p.size = r.range_(3.0, 9.0)
		_P(p)


func _dust(x: float, y: float, n: int, col: String, r: SimRng) -> void:
	for i in range(n):
		var p := Part.new()
		p.type = "dust"
		p.x = x + r.range_(-40.0, 40.0)
		p.y = y + r.range_(0.0, 20.0)
		p.vx = r.range_(-90.0, 90.0)
		p.vy = r.range_(20.0, 140.0)
		p.life = r.range_(0.8, 1.8)
		p.col = col
		p.size = r.range_(14.0, 34.0)
		p.drag = 0.02
		_P(p)


func _splash(x: float, y: float, n: int, r: SimRng) -> void:
	for i in range(n):
		var p := Part.new()
		p.type = "splash"
		p.x = x + r.range_(-30.0, 30.0)
		p.y = y
		p.vx = r.range_(-160.0, 160.0)
		p.vy = r.range_(250.0, 900.0)
		p.grav = 1200.0
		p.life = r.range_(0.7, 1.5)
		p.col = "#bfe6ff"
		p.size = r.range_(2.0, 5.0)
		_P(p)


func _fire(x: float, y: float, n: int, r: SimRng) -> void:
	for i in range(n):
		var p := Part.new()
		p.type = "flame"
		p.x = x + r.range_(-25.0, 25.0)
		p.y = y + r.range_(0.0, 30.0)
		p.vx = r.range_(-30.0, 30.0)
		p.vy = r.range_(60.0, 200.0)
		p.life = r.range_(0.5, 1.3)
		p.col = "#ff9a2e" if r.next() < 0.5 else "#ffd45a"
		p.size = r.range_(6.0, 16.0)
		_P(p)


## Particles (swap-remove when expired), then the damage numbers.
func _stepParts(S: SimState, dt: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var p = parts[i]
		p.age += dt
		if p.age >= p.life:
			parts[i] = parts[parts.size() - 1]
			parts.pop_back()
			continue
		p.vy -= p.grav * dt
		if p.drag != 0.0:
			var d: float = SimDetMath.pow(1.0 - p.drag, dt * 60.0)
			p.vx *= d
			p.vy *= d
		p.x = SimWrap.wrap(p.x + p.vx * dt)
		p.y += p.vy * dt
		if p.type == "ring":
			p.r += p.gr * dt
		if p.type == "deb":
			var g: float = WorldTerrain.groundY(S, p.x)
			if p.y < g:
				p.y = g
				p.vy *= -0.3
				p.vx *= 0.6
	for i in range(floats.size() - 1, -1, -1):
		var f = floats[i]
		f.t += dt
		f.y += 60.0 * dt
		if f.t > 0.9:
			floats.remove_at(i)


## Consume one tick's events, in order (view/fx.js consumeFx).
func consume(S: SimState, events: Array) -> void:
	var dt: float = 0.0
	var frozen: bool = true
	for e in events:
		match e.type:
			"spark":
				_spark(e.x, e.y, e.n, e.col, e.spd, rng["vfx.spark"])
			"debris":
				_debris(e.x, e.y, e.n, e.col, e.spd, rng["vfx.debris"])
			"dust":
				_dust(e.x, e.y, e.n, e.col, rng["vfx.dust"])
			"splash":
				_splash(e.x, e.y, e.n, rng["vfx.splash"])
			"fire":
				_fire(e.x, e.y, e.n, rng["vfx.fire"])
			"ring":
				var p := Part.new()
				p.type = "ring"; p.x = e.x; p.y = e.y; p.r = e.r0; p.gr = e.gr; p.life = e.life; p.col = e.col
				_P(p)
			"after":
				var p := Part.new()
				p.type = "after"; p.x = e.x; p.y = e.y; p.life = e.life; p.col = e.col; p.face = e.face
				_P(p)
			"charge":
				var r: SimRng = rng["vfx.charge"]
				if r.next() < 0.4:
					var p := Part.new()
					p.type = "spark"
					p.x = e.x + r.range_(-40.0, 40.0)
					p.y = e.y + r.range_(0.0, 70.0)
					p.vx = r.range_(-40.0, 40.0)
					p.vy = r.range_(200.0, 500.0)
					p.life = 0.4
					p.col = e.col
					p.size = 2.0
					_P(p)
				if r.next() < 0.06 and e.y < e.ground + 30.0:
					_dust(e.x, e.ground, 1, "#9b8f7e", rng["vfx.dust"])
			"beamSplash":
				if rng["vfx.water"].next() < 0.6:
					_splash(e.x, 0.0, 3, rng["vfx.splash"])
			"damage":
				if e.number:   # landings and collisions carry no damage number
					var fl := DmgFloat.new()
					fl.x = e.x; fl.y = e.y; fl.txt = SimMathx.jstr(SimMathx.jround(e.amount)); fl.t = 0.0; fl.col = e.col
					floats.append(fl)
			"banner":
				var b := Banner.new()
				b.text = e.text; b.col = e.col; b.t = 0.0; b.dur = e.dur
				banner = b
			"shake":
				shake = SimMathx.jmax(shake, e.k)
			"crater", "scorch", "slide", "slide_dust", "skim", "evacuate", "building_fall", "collateral_state", "launch_depth", "chain_link", "floor_hit", "floors_fall":
				pass   # persistent geometry and decals: the renderer reads S.craters, S.scorch and these events itself
			"tick":
				dt = e.dt
				frozen = e.frozen
				_stepParts(S, dt * 0.1 if frozen else dt)
			"region_stage", "region_broken", "brink_enter", "brink_exit", "brink_open", "brink_close", "tier_up", "transform_ready", "transform", "beam_outcome", "pause_start", "pause_end", "hide_start", "found", "ko":
				pass   # wound readouts are the renderer's and UI's (crown, cards); nothing to spawn here
			"decisive", "finisher_start", "finisher_contest", "attack", "parry", "chain_end", "ambush", "lock_lost", "launch_plan", "window_open", "clash_draw", "hazard_telegraph", "searching", "danger", "launch", "rush", "cue", "struggle_press", "rally", "limb_break", "mood_band", "act_change", "style_label", "crowd_state", "building_hit":
				pass   # director and Rally readouts are the HUD's, Camera's and Audio's; nothing to spawn here
			_:
				push_error("consume: unknown event " + e.type)
	if not frozen and banner != null:
		banner.t += dt
		if banner.t > banner.dur:
			banner = null
	shake *= SimDetMath.pow(0.02, dt)
