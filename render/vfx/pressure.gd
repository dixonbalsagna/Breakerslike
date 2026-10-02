class_name VfxPressure
extends RefCounted
## Pressure rings on movement (docs/vfx/power-language.md idea 4): when a fighter breaks into a dash, stops hard or turns hard, a
## thin ring of shoved air leaves the spot, seen edge-on as a narrow ellipse across his line of travel. The size and the second ring
## come from the tier, not the speed: the same dash shoves more air at tier 4 than at tier 2, so a powerful fighter reads as heavy
## and not just quick. Tier 1 has none; tier 2 a small single ring; tier 3 a wider one; tier 4 the widest, with a second behind it.
##
## Read from the trails' own speed and direction (trail_state.gd), so it works for every kind of free flight. A fighter who is
## launched, down, charging, in a rush, hidden or in his transformation gets none. Drawn by transform_view.gd in the lane colour,
## thin, never white, gold or red (VfxAura.lane_color), a ring and not a flame or a spike. Not one of Legal's seven marks (a ring of
## air is not wind streaming past, rubble or ground cracking), so it sits outside the stacking rule. Presentation only: it reads the
## trails and the fighters and draws no random numbers.

const DEFAULTS: Dictionary = {
	"pressure": {"mult_t1": 0.0, "mult_t2": 0.6, "mult_t3": 1.0, "mult_t4": 1.5, "fast_bh": 9.0, "rest_bh": 3.0, "start_window": 24, "stop_window": 18, "stop_hold": 4,
		"turn_dot": -0.3, "cooldown": 30, "r0_bh": 0.5, "r1_bh": 1.1, "r1_t_bh": 0.7, "squash": 0.4, "life_start": 12, "life_stop": 14, "alpha": 0.55, "thick": 0.05,
		"second_delay": 4, "second_scale": 0.8, "alive_max": 8},
}

class Ring:
	var slot: int = 0
	var x: float = 0.0          # wrapped world x, y of its centre
	var y: float = 0.0
	var z: float = 0.0
	var dx: float = 1.0         # unit direction of travel (the ring's narrow axis)
	var dy: float = 0.0
	var age: float = 0.0        # ticks
	var delay: float = 0.0      # ticks before it starts (the second ring)
	var life: float = 12.0
	var r0: float = 37.0        # radius at the start and the end, world units
	var r1: float = 80.0
	var alpha: float = 0.55
	var kind: String = "start"

static var _data: Dictionary = {}
static var _loaded: bool = false

var rings: Array = []                                 # Ring, oldest first
var made: int = 0                                     # events, for the tests
var ring_count: int = 0                               # rings made, the second ring of tier 4 included
var made_start: int = 0
var made_stop: int = 0
var made_turn: int = 0
var skipped: int = 0
var _moving := [false, false]
var _rest_age := PackedInt32Array([1000, 1000])       # ticks since the speed was last at rest
var _fast_age := PackedInt32Array([1000, 1000])       # ticks since the speed was last fast
var _still := PackedInt32Array([0, 0])                # ticks at rest in a row
var _cool := PackedInt32Array([0, 0])
var _fast_dir: Array = [Vector2(1.0, 0.0), Vector2(1.0, 0.0)]


static func warm() -> void:
	if _loaded:
		return
	_loaded = true
	var path := "res://data/vfx/power.json"
	if FileAccess.file_exists(path):
		var v = JSON.parse_string(FileAccess.get_file_as_string(path))
		if v is Dictionary:
			_data = v


static func p(group: String, key: String) -> float:
	warm()
	var g = _data.get(group)
	if g is Dictionary and g.has(key):
		return float(g[key])
	return float(DEFAULTS[group][key])


static func mult_for(tier: int) -> float:
	return p("pressure", "mult_t%d" % clampi(tier, 1, 4))


func reset() -> void:
	rings.clear()
	made = 0
	ring_count = 0
	made_start = 0
	made_stop = 0
	made_turn = 0
	skipped = 0
	_moving = [false, false]
	_rest_age = PackedInt32Array([1000, 1000])
	_fast_age = PackedInt32Array([1000, 1000])
	_still = PackedInt32Array([0, 0])
	_cool = PackedInt32Array([0, 0])
	_fast_dir = [Vector2(1.0, 0.0), Vector2(1.0, 0.0)]
	warm()


## Once per unfrozen tick, after the trails have stepped. forms: the transformations in play. quality: a VfxLook.Q_ level.
func step(S: SimState, trails: Array, forms: Array, quality: int, reduced: bool) -> void:
	var i: int = 0
	while i < rings.size():
		var r: Ring = rings[i]
		if r.delay > 0.0:
			r.delay -= 1.0
		else:
			r.age += 1.0
		if r.age >= r.life:
			rings.remove_at(i)
		else:
			i += 1
	var fast: float = p("pressure", "fast_bh")
	var rest: float = p("pressure", "rest_bh")
	for s in range(mini(2, S.fighters.size())):
		var f = S.fighters[s]
		var t: VfxTrailState = trails[s]
		var v: float = t.speed_bh
		_cool[s] = maxi(_cool[s] - 1, 0)
		_rest_age[s] += 1
		_fast_age[s] += 1
		if v <= rest:
			_rest_age[s] = 0
			_still[s] += 1
		else:
			_still[s] = 0
		var in_form: bool = false
		for fm in forms:
			if fm.slot == s:
				in_form = true
		var gated: bool = in_form or f.state != "free" or f.rush != null or f.hidden
		var tier: int = VfxReact.tier_of(f)
		var m: float = mult_for(tier)
		if v >= fast:
			if not gated and m > 0.0 and _cool[s] == 0:
				if not _moving[s] and _rest_age[s] <= int(p("pressure", "start_window")):
					_emit(S, s, f, t.dir, "start", m, quality, reduced)
					made_start += 1
				elif _moving[s] and t.dir.dot(_fast_dir[s]) < p("pressure", "turn_dot"):
					_emit(S, s, f, _fast_dir[s], "turn", m, quality, reduced)
					made_turn += 1
			_moving[s] = true
			_fast_dir[s] = t.dir
			_fast_age[s] = 0
		elif _moving[s]:
			if _still[s] >= int(p("pressure", "stop_hold")) and _fast_age[s] <= int(p("pressure", "stop_window")):
				if not gated and m > 0.0 and _cool[s] == 0:
					_emit(S, s, f, _fast_dir[s], "stop", m, quality, reduced)
					made_stop += 1
				_moving[s] = false
			elif _fast_age[s] > int(p("pressure", "stop_window")):
				_moving[s] = false


func _emit(S: SimState, slot: int, f, dir: Vector2, kind: String, m: float, quality: int, reduced: bool) -> void:
	if rings.size() >= int(p("pressure", "alive_max")):
		skipped += 1
		return
	_cool[slot] = int(p("pressure", "cooldown"))
	var bh: float = VfxLook.BH
	var r := Ring.new()
	r.slot = slot
	r.kind = kind
	var d: Vector2 = dir if dir.length() > 0.01 else Vector2(1.0, 0.0)
	d = d.normalized()
	r.dx = d.x
	r.dy = d.y
	r.r0 = p("pressure", "r0_bh") * bh
	r.r1 = (p("pressure", "r1_bh") + p("pressure", "r1_t_bh") * m) * bh
	r.alpha = p("pressure", "alpha") * (0.6 if reduced else 1.0)
	r.life = p("pressure", "life_start") if kind == "start" else p("pressure", "life_stop")
	r.z = f.z
	# A start leaves the spot he left from; a stop or a turn puts it a little ahead of him, where the air piled up.
	var ahead: float = 0.0 if kind == "start" else 0.55 * bh
	r.x = SimWrap.wrap(f.x + d.x * ahead)
	r.y = f.y + VfxLook.CHEST_Y + d.y * ahead
	rings.append(r)
	made += 1
	ring_count += 1
	if m >= 1.4 and quality > VfxLook.Q_LOW and not reduced and rings.size() < int(p("pressure", "alive_max")):
		var r2 := Ring.new()
		r2.slot = slot
		r2.kind = kind
		r2.dx = r.dx
		r2.dy = r.dy
		r2.x = r.x
		r2.y = r.y
		r2.z = r.z
		r2.delay = p("pressure", "second_delay")
		r2.life = r.life
		r2.r0 = r.r0
		r2.r1 = r.r1 * p("pressure", "second_scale")
		r2.alpha = r.alpha * 0.7
		rings.append(r2)
		ring_count += 1
