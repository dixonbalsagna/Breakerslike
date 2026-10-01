class_name VfxAura
extends RefCounted
## The standing aura (docs/vfx/aura-plan.md). Orb's rule: the current tier's aura shape and colour shows while a fighter
## charges or attacks, eased in and out, weaker than the transformation's own, and is otherwise off. "Charging or attacking"
## is read from sim state already available each tick: the charge hold (state "charging"), the beam charge
## (`beamCharge`), the fighter is the attacker of the running exchange (a strike, a heavy, a signature), a rush is on, or
## the fighter's own beam is out. A short hold after the last such tick keeps it from blinking between strike beats.
## The level eases per host tick (not on frozen ticks: it holds through a hit-stop), and it is cut while the fighter's own
## transformation is playing (transform.gd draws the aura then). Shapes come from the transformation's per-tier table.
## Presentation only: reads the sim, writes nothing, draws no randomness.

const DEFAULTS: Dictionary = {
	"standing": {"ease_in_ticks": 8, "ease_out_ticks": 24, "hold_ticks": 18, "alpha": 0.4, "fill_scale": 0.5, "pulse": 0.03, "pulse_ticks": 50, "min_tier": 1},
}

static var _data: Dictionary = {}
static var _loaded: bool = false

var level := PackedFloat32Array([0.0, 0.0])    # eased 0..1 per slot, after the last tick
var prev := PackedFloat32Array([0.0, 0.0])     # ... and the tick before, for drawing between ticks
var _hold := PackedInt32Array([0, 0])          # ticks since the fighter was last charging or attacking
var clock: int = 0                             # unfrozen ticks, for the breathing pulse
var started: int = 0                           # times a slot's level rose from zero (for the tests)


static func warm() -> void:
	if _loaded:
		return
	_loaded = true
	var path := "res://data/vfx/aura.json"
	if FileAccess.file_exists(path):
		var v = JSON.parse_string(FileAccess.get_file_as_string(path))
		if v is Dictionary:
			_data = v


## One number: group.key from the data file, else the default.
static func p(group: String, key: String) -> float:
	warm()
	var g = _data.get(group)
	if g is Dictionary and g.has(key):
		return float(g[key])
	return float(DEFAULTS[group][key])


func reset() -> void:
	level = PackedFloat32Array([0.0, 0.0])
	prev = PackedFloat32Array([0.0, 0.0])
	_hold = PackedInt32Array([1000, 1000])
	clock = 0
	started = 0
	warm()


## Is this fighter charging or attacking right now?
static func is_active(S: SimState, f) -> bool:
	if f.hidden or f.state == "down" or f.state == "launched":
		return false
	if f.state == "charging" or f.beamCharge != null or f.rush != null:
		return true
	var ex = S.dirS.ex
	if ex != null and ex.A == f:
		return true
	for b in S.beams:
		if b.A == f:
			return true
	return false


## Once per consume(): ease each slot's level toward its target. forms: the transformations in play (VfxTransform.Form).
func step(S: SimState, frozen: bool, forms: Array) -> void:
	var n: int = mini(2, S.fighters.size())
	var in_form: Array = [false, false]
	for fm in forms:
		if fm.slot >= 0 and fm.slot < 2:
			in_form[fm.slot] = true
	for i in range(n):
		prev[i] = level[i]
		if in_form[i]:
			level[i] = 0.0     # the transformation draws its own aura, and the standing one starts again after it
			prev[i] = 0.0
			_hold[i] = 1000
	if frozen:
		return                 # holds through a hit-stop and a pause
	clock += 1
	for i in range(n):
		if in_form[i]:
			continue
		var f = S.fighters[i]
		var on: bool = is_active(S, f) and f.tier >= p("standing", "min_tier")
		if on:
			_hold[i] = 0
		else:
			_hold[i] = mini(_hold[i] + 1, 100000)
		if on or _hold[i] <= int(p("standing", "hold_ticks")):
			if level[i] <= 0.0 and on:
				started += 1
			level[i] = minf(level[i] + 1.0 / maxf(p("standing", "ease_in_ticks"), 1.0), 1.0)
		else:
			level[i] = maxf(level[i] - 1.0 / maxf(p("standing", "ease_out_ticks"), 1.0), 0.0)


## The colour an aura, a transformation's ring and its flash are drawn in: the fighter's own `aura` colour, except that
## Legal's screen (docs/legal/rule-of-cool-screen.md) rules out gold, white and red for them. A colour in the fire range
## (red, orange, gold) or close to white is swapped for Art's Anti-hero accent (data/art/flashes.json, accents.A.mid), the
## lane colour that fighter is meant to have. Fighter data is not changed; see docs/vfx/aura-plan.md for the one-line
## recommendation. A cool colour (KAI's light blue) is used as it is.
static func lane_color(hex: String) -> Color:
	var c: Color = RenderLook.col(hex)
	var fire: bool = c.s > 0.35 and c.v > 0.35 and (c.h < 0.19 or c.h > 0.96)
	var whiteish: bool = c.s < 0.12 and c.v > 0.8
	if not (fire or whiteish):
		return c
	return _lane_sub()


static var _sub: Color = Color(0.0, 0.0, 0.0, 0.0)


static func _lane_sub() -> Color:
	if _sub.a > 0.0:
		return _sub
	var col := Color("#9a80d8")
	var path := "res://data/art/flashes.json"
	if FileAccess.file_exists(path):
		var v = JSON.parse_string(FileAccess.get_file_as_string(path))
		if v is Dictionary and v.get("accents") is Dictionary and v["accents"].get("A") is Dictionary:
			var m = v["accents"]["A"].get("mid")
			if m is String and m.begins_with("#"):
				col = Color(m)
	_sub = col
	return _sub
