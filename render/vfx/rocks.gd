class_name VfxRocks
extends RefCounted
## Levitating rocks: a PROTOTYPE of one way to show a high tier without more speed (docs/vfx/power-language.md, idea 1), behind the hub
## flag `rocks_enabled` (default off). A fighter at tier 3 (a few pieces) or 4 (about twice as many) standing or hovering near the
## ground, not charging, not transforming, not hidden and not moving fast, has pieces of the ground's own earth hanging about him:
## a loose, uneven cloud at different distances and heights, drifting very slowly and bobbing a little, never an even ring (Legal's
## rule for rubble: gentle, with weight, not a ring of rocks round the fighter, docs/legal/rule-of-cool-screen.md row 12). They rise
## out of the ground as he reaches the state (0.8 s). **When he leaves the state or speeds up, they are let go in world space** (GB-007,
## qa/known-bugs.md): each piece keeps the place it had, falls under gravity and fades (`loose`, 0.9 s; 0.45 s when it is a transformation
## or a charge that takes him out of the state), so nothing rides along beside a fast mover or stays locked to a fighter who has left.
## "Still" is a walking pace (6 fighter heights a second: a dash is 14 to 18), entered below two thirds of that and left above it, so
## speed hovering about the limit does not flicker them. Every piece is a function of the match seed and the clock, so it is
## deterministic. Presentation only: reads the fighters, writes nothing, no `S.rng`.

const DEFAULTS: Dictionary = {
	"rocks": {"min_tier": 3, "count_t3": 5, "count_t4": 10, "r_min_bh": 0.8, "r_max_bh": 2.6, "h_min_bh": -0.1, "h_max_bh": 1.9, "drift_min": 0.05, "drift_max": 0.22, "bob_bh": 0.07, "bob_hz": 0.35, "size_min": 11.0, "size_max": 30.0, "t4_size": 1.25, "ease_in_s": 0.8, "ease_out_s": 0.9, "near_ground_bh": 6.0, "max_speed_bh": 6.0, "alpha": 1.0},
}
const MAX_PIECES := 12
const FORM_OUT_S: float = 0.45       # how long a piece let go by a transformation or a charge takes to fall and fade (seconds)
const ENTER_SPEED_K: float = 0.67    # he is "still" again below this share of max_speed_bh (the hysteresis)
const GRAVITY: float = 900.0         # a let-go piece falls at this (units a second squared)
const FADE_S: float = 0.35           # and fades over the last of its life
const MAX_LOOSE: int = 40

## A piece let go: it has its own world place now and no longer follows him.
class Loose:
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	var vy: float = 0.0
	var age: float = 0.0
	var life: float = 0.9
	var size: float = 10.0
	var tone: int = 0
	var rot: float = 0.0
	var spin: float = 0.5
	var seed: float = 0.0
	var alpha: float = 1.0
	var slot: int = 0

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
var loose: Array = []                          # Loose, oldest first
var released: int = 0                          # pieces let go (the tests)
var _active := [false, false]                  # per slot: in the state (the hysteresis)
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
	loose = []
	released = 0
	_active = [false, false]
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
## heights a second (the trail's measure); qshare: the quality share (how many pieces are showing, for what is let go).
func step(S: SimState, forms: Array, speed_bh: Array, qshare: float = 1.0) -> void:
	clock += 1
	_fall(S)
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
		var limit: float = p("rocks", "max_speed_bh")
		var spd: float = float(speed_bh[i])
		# Still: below the limit, and (to come back) below two thirds of it, so a speed hovering about the limit does not flicker.
		var slow: bool = spd <= (limit if _active[i] else limit * ENTER_SPEED_K)
		var on: bool = tier >= int(p("rocks", "min_tier")) and not busy and near and slow
		if on:
			level[i] = minf(level[i] + 1.0 / maxf(p("rocks", "ease_in_s") * 60.0, 1.0), 1.0)
		else:
			# He has left the state (or sped up): every piece that was up is let go where it is, and nothing stays attached.
			if level[i] > 0.0:
				_release(S, i, f, tier, qshare, p("rocks", "ease_out_s") if not busy else FORM_OUT_S)
			level[i] = 0.0
			prev[i] = 0.0
		_active[i] = on


## Let go the pieces that are up for slot i: each keeps its world place (his place plus its offset as it was drawn) and falls.
func _release(S: SimState, i: int, f, tier: int, qshare: float, life: float) -> void:
	var cnt: int = count_for(tier, qshare)
	var bh: float = VfxLook.BH
	var t: float = (float(clock) - 1.0) / 60.0
	var size_k: float = p("rocks", "t4_size") if tier >= 4 else 1.0
	for k in range(cnt):
		var lo: float = float(k) / float(cnt) * 0.5
		var act: float = smoothstep(lo, lo + 0.5, level[i])
		if act < 0.01:
			continue
		var pc: Piece = pieces[i][k]
		var off: Vector3 = at(pc, t, bh, p("rocks", "bob_bh") * bh)
		var l := Loose.new()
		l.x = SimWrap.wrap(f.x + off.x * act)
		l.y = f.y + off.y * act
		l.z = f.z + off.z * act
		l.vy = 0.0
		l.life = life
		l.size = pc.size * size_k * (0.6 + 0.4 * act)
		l.tone = pc.tone
		l.rot = pc.rot0 + pc.spin * t
		l.spin = pc.spin
		l.seed = pc.seed
		l.alpha = smoothstep(0.0, 0.5, act)
		l.slot = i
		loose.append(l)
		released += 1
	while loose.size() > MAX_LOOSE:
		loose.pop_front()


## Once a tick: the pieces that were let go fall to the ground and fade.
func _fall(S: SimState) -> void:
	var dt: float = SimConst.DT
	var i: int = 0
	while i < loose.size():
		var l: Loose = loose[i]
		l.age += dt
		if l.age >= l.life:
			loose.remove_at(i)
			continue
		l.vy -= GRAVITY * dt
		l.y += l.vy * dt
		var gy: float = WorldTerrain.groundY(S, l.x) + l.size * 0.3
		if l.y <= gy:
			l.y = gy
			l.vy = 0.0
		l.rot += l.spin * dt * (0.0 if l.y <= gy else 1.0)
		i += 1


## How opaque a let-go piece is: its own, fading out over the last of its life.
static func loose_alpha(l: Loose) -> float:
	return l.alpha * (1.0 - smoothstep(l.life - FADE_S, l.life, l.age))
