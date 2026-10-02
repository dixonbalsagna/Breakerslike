class_name VfxRocks
extends RefCounted
## Levitating rocks: a PROTOTYPE of one way to show a high tier without more speed (docs/vfx/power-language.md, idea 1), behind the hub
## flag `rocks_enabled` (default off). A fighter at tier 3 (a few pieces) or 4 (about twice as many) standing or hovering near the
## ground, not charging, not transforming, not hidden and not moving fast, has pieces of the ground's own earth hanging about him:
## a loose, uneven cloud at different distances and heights, drifting very slowly and bobbing a little, never an even ring (Legal's
## rule for rubble: gentle, with weight, not a ring of rocks round the fighter, docs/legal/rule-of-cool-screen.md row 12). They rise
## out of the ground as he reaches the state (0.8 s) and sink back when he leaves it (0.5 s). Every piece is a function of the
## match seed and the clock, so it is deterministic. Presentation only: reads the fighters, writes nothing, no `S.rng`.

const DEFAULTS: Dictionary = {
	"rocks": {"min_tier": 3, "count_t3": 5, "count_t4": 10, "r_min_bh": 0.8, "r_max_bh": 2.6, "h_min_bh": -0.1, "h_max_bh": 1.9, "drift_min": 0.05, "drift_max": 0.22, "bob_bh": 0.07, "bob_hz": 0.35, "size_min": 11.0, "size_max": 30.0, "t4_size": 1.25, "ease_in_s": 0.8, "ease_out_s": 0.5, "near_ground_bh": 6.0, "max_speed_bh": 40.0, "alpha": 1.0},
}
const MAX_PIECES := 12
const FORM_OUT_S: float = 0.15       # how fast they sink when his transformation starts (seconds)

class Piece:
	var ang: float = 0.0        # angle round him at clock zero (radians), random: never evenly spaced
	var r: float = 1.0          # distance, in fighter heights
	var h: float = 0.5          # height above his feet, in fighter heights
	var drift: float = 0.1      # radians a second, either way
	var bob_ph: float = 0.0
	var spin: float = 0.5
	var rot0: float = 0.0
	var size: float = 10.0      # world units
	var tone: int = 0           # 0 mid, 1 light, 2 shadow of the earth ramp
	var seed: float = 0.0

static var _data: Dictionary = {}
static var _loaded: bool = false

var pieces: Array = [[], []]                   # per slot: Piece, MAX_PIECES each, drawn in order up to the tier's count
var level := PackedFloat32Array([0.0, 0.0])    # eased 0..1 per slot
var prev := PackedFloat32Array([0.0, 0.0])
var clock: int = 0                             # unfrozen ticks
var shown: int = 0                             # pieces drawn last frame (the tests)


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


func reset(seed: int) -> void:
	warm()
	level = PackedFloat32Array([0.0, 0.0])
	prev = PackedFloat32Array([0.0, 0.0])
	clock = 0
	shown = 0
	var rng := SimRng.new(SimRng.deriveSeed(seed, "vfx.rocks"))
	pieces = [[], []]
	for s in range(2):
		for i in range(MAX_PIECES):
			var pc := Piece.new()
			pc.ang = rng.next() * TAU
			pc.r = lerpf(p("rocks", "r_min_bh"), p("rocks", "r_max_bh"), pow(rng.next(), 0.8))
			pc.h = lerpf(p("rocks", "h_min_bh"), p("rocks", "h_max_bh"), rng.next())
			pc.drift = lerpf(p("rocks", "drift_min"), p("rocks", "drift_max"), rng.next()) * (1.0 if rng.next() < 0.5 else -1.0)
			pc.bob_ph = rng.next() * TAU
			pc.spin = rng.range_(0.2, 0.9) * (1.0 if rng.next() < 0.5 else -1.0)
			pc.rot0 = rng.next() * TAU
			pc.size = lerpf(p("rocks", "size_min"), p("rocks", "size_max"), pow(rng.next(), 1.4))
			var tr: float = rng.next()
			pc.tone = 0 if tr < 0.55 else (2 if tr < 0.85 else 1)   # mostly the earth's mid and shadow, a few lit
			pc.seed = rng.next()
			pieces[s].append(pc)


## How many pieces a tier shows, at a quality share (0.35 low, 0.7 medium, 1 high; halved in reduced motion by the caller).
static func count_for(tier: int, q: float) -> int:
	if tier < int(p("rocks", "min_tier")):
		return 0
	var n: float = p("rocks", "count_t4") if tier >= 4 else p("rocks", "count_t3")
	return clampi(int(round(n * q)), 1, MAX_PIECES)


## Where a piece hangs at clock t (seconds), relative to the fighter's feet: x and z from the angle it has drifted to at its own fixed
## distance (so it circles slowly and never spirals in or out), y a fixed height plus a small bob (so it never climbs). Legal's
## conditions on the rocks (RL-057) are read off this function in effects_check.gd. bob_amp is in world units, bh one fighter height.
static func at(pc: Piece, t: float, bh: float, bob_amp: float) -> Vector3:
	var ang: float = pc.ang + pc.drift * t
	return Vector3(cos(ang) * pc.r * bh, pc.h * bh + sin(TAU * p("rocks", "bob_hz") * t + pc.bob_ph) * bob_amp, sin(ang) * pc.r * bh * 0.35)


## Once per consume(), on unfrozen ticks. forms: the transformations in play; speed_bh: per slot, the fighter's speed in fighter
## heights a second (the trail's measure).
func step(S: SimState, forms: Array, speed_bh: Array) -> void:
	clock += 1
	for i in range(mini(2, S.fighters.size())):
		prev[i] = level[i]
		var f = S.fighters[i]
		var tier: int = clampi(int(floor(float(f.tier) + 0.001)), 1, 4)
		var in_form: bool = false
		for fm in forms:
			if fm.slot == i:
				in_form = true
		var busy: bool = in_form or f.state == "charging" or f.beamCharge != null or f.hidden or f.state == "down"
		var near: bool = f.y - WorldTerrain.groundY(S, f.x) <= p("rocks", "near_ground_bh") * VfxLook.BH and WorldWater.surfaceAt(S, f.x) == WorldWater.DRY
		var slow: bool = float(speed_bh[i]) <= p("rocks", "max_speed_bh")
		var on: bool = tier >= int(p("rocks", "min_tier")) and not busy and near and slow
		if on:
			level[i] = minf(level[i] + 1.0 / maxf(p("rocks", "ease_in_s") * 60.0, 1.0), 1.0)
		elif in_form:
			level[i] = maxf(level[i] - 1.0 / (FORM_OUT_S * 60.0), 0.0)   # a transformation: they are gone by its break (RL-059), back after the settle
		else:
			level[i] = maxf(level[i] - 1.0 / maxf(p("rocks", "ease_out_s") * 60.0, 1.0), 0.0)
