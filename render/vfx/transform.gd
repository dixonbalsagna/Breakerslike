class_name VfxTransform
extends RefCounted
## The transformation's effects (docs/vfx/transform-plan.md; staging in docs/design/moveset-rules.md section 10.8). One
## `transform` event starts a Form for that slot: three beats, the gather (the aura and loose dust are drawn inward to the
## sigil, the light around him dims), the break (one ring leaves the body, the aura swaps to the new tier's shape in a single
## frame, a flash in his own colour) and the settle (the new aura holds steady, then eases out). No upward flame, no
## lightning, nothing outward on the gather.
##
## The clock is the host's tick, not the sim's: step() runs once per consume() whether the sim ran, was in hit-stop or was
## paused (Q10: a full or short transformation freezes the sim for its whole length, S.pause.left), so the effect plays
## through a pause at the speed of the wall clock. A live version (no pause) holds still on a hit-stop tick, like the rest
## of the fight. Everything is a function of the form's age, so a frame between two ticks is interpolated by age.
## Presentation only: it reads the event and the sim, never writes either, and its cosmetic RNG is the stream
## "vfx.xform" derived from the match seed.

const DEFAULTS: Dictionary = {
	"gather": {"motes": 40, "dust_motes": 14, "loops_full": 2.0, "loops_short": 1.0, "loops_live": 1.0, "radius_bh": 2.6, "len_bh": 0.55, "width_bh": 0.05, "alpha": 0.85, "dim_radius_bh": 6.0, "dim_alpha": 0.32, "aura_shrink": 0.12},
	"break": {"ring_r0_bh": 0.7, "ring_r1_bh": 4.2, "ring_ticks": 14, "ring_thick": 0.045, "ring_alpha": 0.95, "flash_radius_bh": 1.7, "flash_alpha": 0.5, "flash_ticks": 5, "aura_alpha": 0.9},
	"settle": {"aura_alpha": 0.6, "ease_ticks": 10, "fade_ticks": 24},
}
const DEFAULT_BEATS: Dictionary = {
	"full": [60, 30, 90],
	"short": [24, 18, 48],
	"live": [10, 14, 24],
}
const DEFAULT_AURA: Dictionary = {
	1: {"w_bh": 1.0, "h_bh": 1.45, "lobes": 0, "fill": 0.14, "mix": 0.0},
	2: {"w_bh": 1.2, "h_bh": 1.6, "lobes": 1, "fill": 0.15, "mix": 0.0},
	3: {"w_bh": 1.45, "h_bh": 1.75, "lobes": 2, "fill": 0.16, "mix": 0.0},
	4: {"w_bh": 1.7, "h_bh": 1.9, "lobes": 3, "fill": 0.17, "mix": 0.0},
}
const MOTE_STRIDE := 5   # theta, start radius share, phase, length jitter, kind (0 aura mote, 1 dust)

## One slot's transformation in play.
class Form:
	var slot: int = 0
	var version: String = "live"
	var tier: int = 2          # the new tier
	var old_tier: int = 1
	var g: int = 10            # beat lengths in ticks
	var b: int = 14
	var s: int = 24
	var age: float = 0.0       # ticks played
	var adv: bool = false      # the last step advanced the clock
	var pause: bool = false    # runs through a sim pause (full and short)
	var motes := PackedFloat32Array()

	func total() -> int:
		return g + b + s

	## The age to draw a frame at: a tick back plus the interpolation, so it is smooth between ticks, and held when the
	## clock held.
	func at(a: float) -> float:
		return maxf(age - (1.0 - a), 0.0) if adv else age

static var _data: Dictionary = {}
static var _loaded: bool = false

var forms: Array = []          # Form, at most one per slot
var started: int = 0           # counters for the tests
var finished: int = 0
var _rng: SimRng


static func warm() -> void:
	if _loaded:
		return
	_loaded = true
	var path := "res://data/vfx/transform.json"
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


## The three beat lengths of a version, in ticks.
static func beats(version: String) -> Array:
	warm()
	var bt = _data.get("beats")
	if bt is Dictionary and bt.get(version) is Dictionary:
		var d: Dictionary = bt[version]
		var dd: Array = DEFAULT_BEATS.get(version, DEFAULT_BEATS["live"])
		return [int(d.get("gather", dd[0])), int(d.get("break", dd[1])), int(d.get("settle", dd[2]))]
	return (DEFAULT_BEATS.get(version, DEFAULT_BEATS["live"]) as Array).duplicate()


## The aura's shape for a tier (1..4): w_bh, h_bh, lobes, fill, mix.
static func aura(tier: int) -> Dictionary:
	warm()
	var t: int = clampi(tier, 1, 4)
	var au = _data.get("aura")
	if au is Dictionary and au.get(str(t)) is Dictionary:
		var out: Dictionary = (DEFAULT_AURA[t] as Dictionary).duplicate()
		for k in au[str(t)].keys():
			out[k] = au[str(t)][k]
		return out
	return DEFAULT_AURA[t]


func reset(seed: int) -> void:
	forms.clear()
	started = 0
	finished = 0
	_rng = SimRng.new(SimRng.deriveSeed(seed, "vfx.xform"))
	warm()


## Once per consume(), before that tick's events: the clock. frozen: the tick was frozen (a hit-stop or a pause). A full or short
## version plays through frozen ticks (it is the pause); a live one waits them out.
func step(frozen: bool) -> void:
	var i: int = 0
	while i < forms.size():
		var f: Form = forms[i]
		if frozen and not f.pause:
			f.adv = false          # a live version waits out a hit-stop like the fight does
		else:
			f.age += 1.0
			f.adv = true
		if f.age >= float(f.total()):
			forms.remove_at(i)
			finished += 1
		else:
			i += 1


## A `transform` event: slot `actor` took tier `tier` in `version`, `dur` seconds long (the pause of a full or short
## version, the hold of a live one).
func begin(actor: int, tier: float, version: String, dur: float) -> void:
	var f := Form.new()
	f.slot = actor
	f.version = version if DEFAULT_BEATS.has(version) else "live"
	f.tier = clampi(int(round(tier)), 1, 4)
	f.old_tier = clampi(f.tier - 1, 1, 4)
	f.pause = f.version != "live"
	var bt: Array = beats(f.version)
	var sum: int = int(bt[0]) + int(bt[1]) + int(bt[2])
	var total: int = int(round(dur * float(SimPause.TPS))) if dur > 0.0 else sum
	total = maxi(total, 6)
	var k: float = float(total) / float(maxi(sum, 1))
	f.g = maxi(int(round(float(bt[0]) * k)), 1)
	f.b = maxi(int(round(float(bt[1]) * k)), 1)
	f.s = maxi(total - f.g - f.b, 1)
	var n: int = int(p("gather", "motes")) + int(p("gather", "dust_motes"))
	var nm: int = int(p("gather", "motes"))
	f.motes.resize(n * MOTE_STRIDE)
	for i in range(n):
		var o: int = i * MOTE_STRIDE
		f.motes[o] = _rng.next() * TAU
		f.motes[o + 1] = _rng.range_(0.55, 1.0)
		f.motes[o + 2] = _rng.next()
		f.motes[o + 3] = _rng.range_(0.6, 1.4)
		f.motes[o + 4] = 0.0 if i < nm else 1.0
	for i in range(forms.size() - 1, -1, -1):
		if (forms[i] as Form).slot == actor:
			forms.remove_at(i)
	forms.append(f)
	started += 1


## The beat an age falls in: 0 gather, 1 break, 2 settle.
static func beat_of(f: Form, age: float) -> int:
	if age < float(f.g):
		return 0
	if age < float(f.g + f.b):
		return 1
	return 2


## The aura's alpha at an age: pulled in on the gather, in full at the break, steady in the settle, easing out at the end.
static func aura_alpha(f: Form, age: float) -> float:
	var bt: int = beat_of(f, age)
	if bt == 0:
		var u: float = age / float(f.g)
		return 0.85 * (1.0 - 0.35 * u)
	var al: float = p("break", "aura_alpha") if bt == 1 else p("settle", "aura_alpha")
	if bt == 2:
		var ts: float = age - float(f.g + f.b)
		var ease_t: float = float(mini(int(p("settle", "ease_ticks")), f.s))
		al = lerpf(p("break", "aura_alpha"), p("settle", "aura_alpha"), smoothstep(0.0, maxf(ease_t, 1.0), ts))
		var fade_t: float = minf(p("settle", "fade_ticks"), float(f.s) * 0.5)
		al *= 1.0 - smoothstep(float(f.s) - fade_t, float(f.s), ts)
	return al


## The aura's scale on the gather: 1 at the start, drawn in toward the sigil by the end; 1 after.
static func aura_scale(f: Form, age: float) -> float:
	if age >= float(f.g):
		return 1.0
	var u: float = age / float(f.g)
	return lerpf(1.0, p("gather", "aura_shrink"), u * u)
