class_name VfxReact
extends RefCounted
## The reactions to power (docs/vfx/react-plan.md; rows 1 and 12 of docs/design/rule-of-cool.md, shaped by Legal's screen,
## docs/legal/rule-of-cool-screen.md):
##  - the aura flickering when the fighter is worn (any tier): read from the wear stage of the core and the brink;
##  - from tier 3 the world answering: rubble lifting off the ground with weight, cracks spreading where he stands, and on
##    a big impact the windows of a block blowing out along it.
## All of it is presentation read from sim state and events, with its randomness from the debris pool's cosmetic streams.
## Legal's stacking rule: the world effects stand down while the fighter is charging and during his own transformation,
## so a power-up scene never shows crouch, scream, body aura and a rising-rubble-with-cracks world together. Rubble is
## scattered, not a ring; nothing here is lightning, wind or a darkening sky.

const DEFAULTS: Dictionary = {
	"flicker": {"min_stage": 2, "amp": 0.8, "brink_add": 0.25, "density": 0.55, "period_ticks": 3, "shape_jitter": 0.03},
	"rubble": {"min_tier": 3, "rate_t3": 4.0, "rate_t4": 9.0, "spread_bh_t3": 1.6, "spread_bh_t4": 2.6, "rise_min": 25, "rise_max": 70, "accel": 16, "life_min": 1.8, "life_max": 3.0, "size_min": 8, "size_max": 20, "near_ground_bh": 3.0, "alive_cap": 36},
	"cracks": {"min_tier": 3, "still_ticks": 30, "still_speed": 300, "r_t3": 150, "r_t4": 230, "energy_t3": 8, "energy_t4": 18, "grow_s": 2.5, "fade_in_ticks": 20, "fade_out_ticks": 60, "stay_ticks": 90, "move_radius": 220},
	"windows": {"min_tier": 3, "min_energy": 8, "reach_t3": 1800, "reach_t4": 3200, "speed": 2600, "min_floors": 3, "floors_max": 6, "max_buildings": 10, "scale": 0.8, "keep_s": 6},
	"speed": {"lines": 7, "ticks": 6, "dist_bh": 3.6, "len_min_bh": 1.4, "len_max_bh": 3.0, "spread_bh": 1.15, "gap_min_bh": 0.35, "gap_max_bh": 0.8, "width_bh": 0.04, "alpha": 0.7, "rim_alpha": 0.4, "min_gap_ticks": 6, "dedupe_ticks": 24, "alive_max": 4},
}

static var _data: Dictionary = {}
static var _loaded: bool = false

var debris: VfxDebris
var level := PackedFloat32Array([0.0, 0.0])     # the standing cracks' fade per slot, 0..1 (drawn by crack_view)
var blowouts: Array = []                        # windows blowing out: {b, at, strength, lo, hi}; Rendering may read them (see react-plan.md)
var rubble_made: int = 0                        # counters for the tests
var min_dx: float = 1e9                         # the nearest a piece of rubble spawned to the fighter (the tests: never straight under him)
var stand_sets: int = 0
var blow_waves: int = 0
var blow_buildings: int = 0
var _acc := PackedFloat32Array([0.0, 0.0])      # rubble spawn accumulators
var _still := PackedInt32Array([0, 0])
var _away := PackedInt32Array([0, 0])
var _set: Array = [null, null]                  # VfxHub.CrackSet per slot
var _busy: Array = [false, false]               # the slot was charging or transforming this tick (the world stands down)


static func warm() -> void:
	if _loaded:
		return
	_loaded = true
	var path := "res://data/vfx/react.json"
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
	blowouts.clear()
	rubble_made = 0
	min_dx = 1e9
	stand_sets = 0
	blow_waves = 0
	blow_buildings = 0
	_acc = PackedFloat32Array([0.0, 0.0])
	_still = PackedInt32Array([0, 0])
	_away = PackedInt32Array([0, 0])
	_set = [null, null]
	_busy = [false, false]
	warm()


static func tier_of(f) -> int:
	return clampi(int(floor(float(f.tier) + 0.001)), 1, 4)


# ------------------------------------------------------------------------------------------------------------- flicker

## How worn a fighter is, 0 to 1: the core's wear stage (battered 0.5, broken 1.0) and the brink on top. It stays and
## keeps building through a transformation because it reads the wounds, not the tier.
static func worn(f) -> float:
	var st: int = int(f.stage[1])
	var lo: int = int(p("flicker", "min_stage"))
	if st < lo:
		return 0.0
	var w: float = clampf(float(st - (lo - 1)) / float(maxi(3 - (lo - 1), 1)), 0.0, 1.0)
	return clampf(w + (p("flicker", "brink_add") if f.brink else 0.0), 0.0, 1.0)


## A cheap deterministic hash of a tick number and a slot to 0..1 (no random stream: a pure function of the tick).
static func _h(n: int, slot: int) -> float:
	var x: int = (n * 73856093 + slot * 19349663 + 12345) & 0x7FFFFFFF
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7FFFFFFF
	x = x ^ (x >> 16)
	return float(x & 0xFFFF) / 65536.0


## The factor an aura's alpha is multiplied by at a tick: 1 for a fighter who is not worn, and dropouts of a few ticks for
## one who is (more and deeper the more worn). With reduced motion: a steady dimming instead, no flicker.
static func flicker(f, tick: int, slot: int, reduced: bool) -> float:
	var w: float = worn(f)
	if w <= 0.0:
		return 1.0
	var amp: float = p("flicker", "amp")
	if reduced:
		return 1.0 - 0.5 * amp * w
	var n: int = tick / maxi(int(p("flicker", "period_ticks")), 1)
	var gate: bool = _h(n, slot) < p("flicker", "density") * (0.5 + 0.5 * w)
	return 1.0 - amp * w * (1.0 if gate else 0.12)


## A small size jitter that goes with the flicker (the outline stutters), 1.0 for a fighter who is not worn.
static func jitter(f, tick: int, slot: int, reduced: bool) -> float:
	var w: float = worn(f)
	if w <= 0.0 or reduced:
		return 1.0
	var n: int = tick / maxi(int(p("flicker", "period_ticks")), 1)
	return 1.0 + p("flicker", "shape_jitter") * w * (_h(n + 7777, slot) * 2.0 - 1.0)


# ------------------------------------------------------------------------------------------------------- the world reacts

## Once per consume(), on unfrozen ticks (it holds through a hit-stop and a pause): rubble and the standing cracks.
## hub: the VfxHub (for its crack sets); forms: the transformations in play.
func step(S: SimState, hub, forms: Array) -> void:
	var q: float = VfxLook.QUALITY_SHARDS[clampi(hub.quality, 0, 2)] * (0.5 if hub.reduced_motion else 1.0)
	var bh: float = VfxLook.BH
	for i in range(mini(2, S.fighters.size())):
		var f = S.fighters[i]
		var tier: int = tier_of(f)
		var in_form: bool = false
		for fm in forms:
			if fm.slot == i:
				in_form = true
		var charging: bool = f.state == "charging" or f.beamCharge != null
		_busy[i] = in_form or charging
		var up: bool = tier >= int(p("rubble", "min_tier")) and not f.hidden and not _busy[i] and WorldWater.surfaceAt(S, f.x) == WorldWater.DRY
		var g: float = WorldTerrain.groundY(S, f.x)
		# Rubble: a few chunks lifting slowly from the ground near him, scattered (never a ring), heavier and wider at tier 4.
		if up and f.y - g <= p("rubble", "near_ground_bh") * bh:
			var rate: float = p("rubble", "rate_t4") if tier >= 4 else p("rubble", "rate_t3")
			_acc[i] += rate / 60.0 * q
			var spread: float = (p("rubble", "spread_bh_t4") if tier >= 4 else p("rubble", "spread_bh_t3")) * bh
			var cap: int = int(round(p("rubble", "alive_cap") * q))
			var biome: String = VfxPalette.biome_key(f.x)
			while _acc[i] >= 1.0:
				_acc[i] -= 1.0
				if debris._rubble_alive >= cap:
					continue
				var x: float = f.x + debris._rd.range_(-spread, spread)
				if absf(x - f.x) < 0.25 * bh:
					x = f.x + maxf(absf(x - f.x), 0.25 * bh) * (1.0 if x >= f.x else -1.0)   # not straight under him: scattered
				if WorldWater.surfaceAt(S, x) != WorldWater.DRY:
					continue
				min_dx = minf(min_dx, absf(x - f.x))
				var gg: float = WorldTerrain.groundY(S, x)
				debris.rubble(x, gg + 3.0, f.z - 2.0, debris._rd.range_(-10.0, 10.0), debris._rd.range_(p("rubble", "rise_min"), p("rubble", "rise_max")), debris._rd.range_(p("rubble", "size_min"), p("rubble", "size_max")), debris._rd.range_(p("rubble", "life_min"), p("rubble", "life_max")), p("rubble", "accel"), biome)
				rubble_made += 1
		else:
			_acc[i] = 0.0
		# Standing cracks: he has stood still on the ground at tier 3 or more for half a second; a web spreads from his feet
		# over a couple of seconds, stays while he stands there, and fades when he leaves.
		if hub.cracks_enabled:
			_stand(S, hub, i, f, g, up and f.y - g <= 40.0 and absf(f.vx) <= p("cracks", "still_speed") and f.state != "launched" and f.state != "down")


func _stand(S: SimState, hub, i: int, f, _g: float, standing: bool) -> void:
	var cs = _set[i]
	if standing:
		_still[i] = mini(_still[i] + 1, 100000)
	else:
		_still[i] = 0
	if cs != null:
		if not hub.crack_sets.has(cs):
			_set[i] = null     # the hub dropped it (a new match, the cap)
			level[i] = 0.0
			return
		var near: bool = absf(SimWrap.sdx(cs.x, f.x)) <= p("cracks", "move_radius") and standing
		_away[i] = 0 if near else _away[i] + 1
		if _away[i] > int(p("cracks", "stay_ticks")):
			level[i] = maxf(level[i] - 1.0 / maxf(p("cracks", "fade_out_ticks"), 1.0), 0.0)
			if level[i] <= 0.0:
				hub.crack_sets.erase(cs)
				hub.crack_pending.erase(cs)
				_set[i] = null
		else:
			level[i] = minf(level[i] + 1.0 / maxf(p("cracks", "fade_in_ticks"), 1.0), 1.0)
		return
	level[i] = 0.0
	if _still[i] < int(p("cracks", "still_ticks")):
		return
	var tier: int = tier_of(f)
	var biome: String = VfxPalette.biome_key(f.x)
	if not VfxPalette.takes_cracks(biome):
		return
	var r: float = p("cracks", "r_t4") if tier >= 4 else p("cracks", "r_t3")
	var E: float = p("cracks", "energy_t4") if tier >= 4 else p("cracks", "energy_t3")
	if hub.reduced_motion:
		r *= 0.6
	var key: int = VfxCrackGen.crater_key(f.x, r, float(S.tick))
	var lines: Array = VfxCrackGen.crater_lines(hub.seed, key, r, E, false, "powerup", hub.quality)
	if lines.is_empty():
		return
	var ns = hub.make_set(2, key, SimWrap.wrap(f.x), S.T, biome, lines)
	ns.slot = i
	_set[i] = ns
	_away[i] = 0
	stand_sets += 1


# ---------------------------------------------------------------------------------------------------------- windows

## A crater (the sim's `crater` event): a tier 3 or 4 fighter's big impact blows the windows out of the buildings along it,
## nearest first, each after the shock has travelled to it. Rendering's building shader may show the same buildings'
## windows as out through `blowouts` (building index, the sim time they go, a 0 to 1 strength, the floor range).
func on_crater(S: SimState, e, hub) -> void:
	var owner: int = int(e.owner)
	if owner < 0 or owner >= S.fighters.size():
		return
	var f = S.fighters[owner]
	var tier: int = tier_of(f)
	if tier < int(p("windows", "min_tier")):
		return
	var special = e.get("special")
	if float(e.energy) < p("windows", "min_energy") and not (special != null and float(special) > 0.5):
		return
	var reach: float = p("windows", "reach_t4") if tier >= 4 else p("windows", "reach_t3")
	var cand: Array = []
	for b in S.buildings:
		if not b.alive or int(b.floors) < int(p("windows", "min_floors")):
			continue
		var d: float = absf(SimWrap.sdx(float(e.x), b.x))
		if d <= reach + b.w * 0.5:
			cand.append([d, b])
	if cand.is_empty():
		return
	cand.sort_custom(func(a, c): return a[0] < c[0])
	var q: float = VfxLook.QUALITY_SHARDS[clampi(hub.quality, 0, 2)] * (0.5 if hub.reduced_motion else 1.0)
	var nb: int = clampi(int(round(p("windows", "max_buildings") * (0.5 + 0.5 * q))), 1, 24)
	blow_waves += 1
	for k in range(mini(cand.size(), nb)):
		var d: float = cand[k][0]
		var b = cand[k][1]
		var strength: float = clampf(1.0 - 0.6 * d / maxf(reach, 1.0), 0.2, 1.0)
		var F: int = maxi(int(b.floors), 1)
		var rows: int = clampi(int(round(float(F) * strength * 0.6)), 1, int(p("windows", "floors_max")))
		var floors: Array = []
		for r in range(rows):
			floors.append(mini(int(floor((float(r) + 0.5) / float(rows) * float(F))), F - 1))
		var at: float = S.T + d / maxf(p("windows", "speed"), 1.0)
		var j := VfxDebris.Job.new()
		j.at = at
		j.kind = "blow"
		j.a = {"x": b.x, "w": b.w, "base": WorldStructures.baseY(S, b), "fh": b.h / float(F), "z": hub.front_z(b), "floors": floors, "scale": p("windows", "scale")}
		debris.jobs.append(j)
		blowouts.append({"b": b.idx, "at": at, "strength": strength, "lo": int(floors[0]), "hi": int(floors[floors.size() - 1])})
		blow_buildings += 1
	while blowouts.size() > 64:
		blowouts.pop_front()


## Drop blow-outs whose time is long past (Rendering reads them while the windows are out).
func prune(S: SimState) -> void:
	var keep: float = p("windows", "keep_s")
	blowouts = blowouts.filter(func(w): return S.T - float(w["at"]) < keep)
