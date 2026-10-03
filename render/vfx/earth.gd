class_name VfxEarth
extends RefCounted
## Earth, material and fire (docs/vfx/earth-plan.md). Three things the reference particle consumer drew as placeholders or
## not at all, drawn here from events the sim already sends:
##  - `debris` (building damage, craters, impacts): chunks of the right material that tumble, instead of small solid squares;
##  - `fire` (burning, blasts, a firestorm): cel flames with a wobble and a little smoke, instead of solid discs;
##  - World's ground contact (G3, world/contact.gd): `land`, `bounce`, `left_ground`, `tumble_end` and `journey_end`, and the
##    skid itself while a body slides: spray, clods and dust by surface and speed. Water is the skip's (water.gd).
## Presentation only: it reads the events and the fighters and writes nothing; its randomness is the debris pool's cosmetic
## streams. The pool's caps and the per-tick spawn budget keep every burst bounded.

const DEFAULTS: Dictionary = {
	"deb": {"size_min": 6.0, "size_max": 15.0, "life_min": 1.2, "life_max": 2.4, "max_per_event": 14, "spin": 10.0, "speed_scale": 1.0},
	"flame": {"per_unit": 1.0, "max_per_event": 8, "size_min": 22.0, "size_max": 46.0, "life_min": 0.7, "life_max": 1.5, "rise_min": 70.0, "rise_max": 190.0, "smoke_every": 3, "smoke_life": 1.6, "alive_cap": 40},
	"land": {"speed_ref": 2500.0, "chunks_slam": 10, "chunks_skid": 5, "chunks_tumble": 6, "size_min": 8.0, "size_max": 16.0, "dust_slam": 5, "dust_skid": 3, "dust_tumble": 3, "sand_chunks": 0.5, "sand_dust": 1.6, "paving_chunks": 1.2, "paving_dust": 0.8},
	"bounce": {"vn_ref": 1500.0, "chunks": 4, "dust": 2},
	"leave": {"speed_ref": 2500.0, "chunks_lip": 6, "chunks_heap": 8, "chunks_cliff": 4, "chunks_crest": 0, "chunks_bounce": 2, "dust": 2},
	"settle": {"tumble_dust": 2, "journey_dust": 3, "wall_chunks": 8, "capped_scale": 1.5},
	"skid": {"min_speed": 500.0, "rate_per_s": 14.0, "dust_every": 3, "speed_ref": 2500.0},
}

static var _data: Dictionary = {}
static var _loaded: bool = false

var debris: VfxDebris
var deb_made: int = 0          # counters for the tests
var flames_made: int = 0
var contact_made: int = 0      # chunks and puffs thrown for contact events
var contact_events: int = 0
var dust_made: int = 0
var entrance_now: bool = false   # this tick holds an entrance landing: the other effects of its tick (the crater's ejecta and dust) are quiet and short, so the dust clears by the staredown
var _acc := PackedFloat32Array([0.0, 0.0])    # the skid's spawn accumulators per slot
var _skid_n := PackedInt32Array([0, 0])
var _fire_n: int = 0


static func warm() -> void:
	if _loaded:
		return
	_loaded = true
	var path := "res://data/vfx/earth.json"
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
	deb_made = 0
	flames_made = 0
	contact_made = 0
	contact_events = 0
	dust_made = 0
	_acc = PackedFloat32Array([0.0, 0.0])
	_skid_n = PackedInt32Array([0, 0])
	_fire_n = 0
	warm()


func _q() -> float:
	return VfxLook.QUALITY_SHARDS[clampi(debris.quality, 0, 2)] * (0.5 if debris.reduced else 1.0)


## A count scaled by quality, rounded, with the remainder decided by a draw so the average is right.
func _lk() -> float:
	return 0.55 if entrance_now else 1.0


func _count(n: float) -> int:
	var v: float = n * _q()
	var whole: int = int(floor(v))
	return whole + (1 if debris._rd.next() < v - float(whole) else 0)


# --------------------------------------------------------------------------------------------------------------- materials

## [mid, light, shadow] and the chunk mode for the colour a `debris` event names. Grey ground chunks take the biome's own earth
## (Art's dust ramp), paving and steel take the steel ramp, the rest keep their own colour with a lit and a shaded step.
static func tones_for_col(hex: String, x: float) -> Dictionary:
	var c: Color = RenderLook.col(hex)
	var grey: bool = c.s < 0.12 and c.v > 0.3 and c.v < 0.65
	if grey:
		if hex.to_lower() == "#8f8b84":      # paving
			return {"t": [VfxPalette.steel("light"), VfxPalette.steel("light").lightened(0.12), VfxPalette.steel("mid")], "mode": 2}
		var bk: String = VfxPalette.biome_key(x)
		return {"t": [VfxPalette.dust(bk, "mid"), VfxPalette.dust(bk, "light"), VfxPalette.dust(bk, "shadow")], "mode": 2}
	if hex.to_lower() == "#77808f":           # a tower's steel and concrete
		return {"t": [VfxPalette.steel("mid"), VfxPalette.steel("light"), VfxPalette.steel("shadow")], "mode": 0}
	return {"t": [c, c.lightened(0.25), c.darkened(0.3)], "mode": 2}


## [mid, light, shadow] for a ground surface class at x.
static func tones_for_surface(surface: String, x: float) -> Array:
	if surface == "paving":
		return [VfxPalette.steel("light"), VfxPalette.steel("light").lightened(0.12), VfxPalette.steel("mid")]
	var bk: String = VfxPalette.biome_key(x)
	if surface == "rubble":
		return [VfxPalette.dust(bk, "shadow"), VfxPalette.steel("mid"), VfxPalette.dust(bk, "shadow")]
	return [VfxPalette.dust(bk, "mid"), VfxPalette.dust(bk, "light"), VfxPalette.dust(bk, "shadow")]


# ------------------------------------------------------------------------------------------------------ debris and fire

## A `debris` event: n chunks thrown up from (x, y) at up to spd, tumbling, in the colour's material.
func on_debris(e) -> void:
	var n: int = mini(int(e.n), int(p("deb", "max_per_event")))
	if n <= 0:
		return
	var tn: Dictionary = tones_for_col(String(e.col), float(e.x))
	var z: float = float(e.get("z") if e.get("z") != null else 0.0) + 6.0
	var spd: float = float(e.spd) * p("deb", "speed_scale")
	for i in range(n):
		var a: float = debris._rd.range_(0.2, 2.9)
		var s: float = debris._rd.range_(0.2, 1.0) * spd
		var flip: float = -1.0 if debris._rd.next() < 0.5 else 1.0
		var ox: float = debris._rd.range_(-20.0, 20.0)
		var size: float = debris._rd.range_(p("deb", "size_min"), p("deb", "size_max"))
		var life: float = debris._rd.range_(p("deb", "life_min"), p("deb", "life_max")) * _lk()
		var keep: float = debris._rd.next()
		if keep < _q():
			debris.chunk(float(e.x) + ox, float(e.y), z, cos(a) * s * flip, sin(a) * s, size, life, tn["t"], int(tn["mode"]), p("deb", "spin"))
			deb_made += 1


## A `fire` event: n flames and a little smoke rising from (x, y).
func on_fire(e) -> void:
	var n: int = mini(int(ceil(float(e.n) * p("flame", "per_unit"))), int(p("flame", "max_per_event")))
	var z: float = float(e.get("z") if e.get("z") != null else 0.0) + 4.0
	var cap: int = int(round(p("flame", "alive_cap") * (0.5 + 0.5 * _q())))
	for i in range(n):
		var x: float = float(e.x) + debris._rd.range_(-25.0, 25.0)
		var y: float = float(e.y) + debris._rd.range_(0.0, 30.0)
		var vx: float = debris._rd.range_(-30.0, 30.0)
		var vy: float = debris._rd.range_(p("flame", "rise_min"), p("flame", "rise_max"))
		var size: float = debris._rd.range_(p("flame", "size_min"), p("flame", "size_max"))
		var life: float = debris._rd.range_(p("flame", "life_min"), p("flame", "life_max"))
		var keep: float = debris._rd.next()
		if keep >= _q() or debris._flame_alive >= cap:
			continue
		debris.flame(x, y, z, vx, vy, size, life)
		flames_made += 1
		_fire_n += 1
		if not debris.reduced and _fire_n % maxi(int(p("flame", "smoke_every")), 1) == 0:
			debris.smoke(x, y + size, z - 2.0, size * 0.9, p("flame", "smoke_life"))


# --------------------------------------------------------------------------------------------------------- ground contact

func _on_water(S: SimState, x: float) -> bool:
	return WorldWater.surfaceAt(S, x) != WorldWater.DRY


## The direction a fighter travels along x: +1 or -1.
static func _dirx(S: SimState, e) -> float:
	var a: int = int(e.actor)
	if a >= 0 and a < S.fighters.size():
		var vx: float = S.fighters[a].vx
		if absf(vx) > 1.0:
			return signf(vx)
		return S.fighters[a].face if S.fighters[a].face != 0.0 else 1.0
	return 1.0


func _chunks(x: float, y: float, z: float, n: int, tones: Array, dirx: float, back: float, up_lo: float, up_hi: float, side: float, size_k: float) -> void:
	for i in range(n):
		var sz: float = debris._rd.range_(p("land", "size_min"), p("land", "size_max")) * size_k
		var vx: float = -dirx * debris._rd.range_(0.0, 1.0) * back + debris._rd.range_(-side, side)
		var vy: float = debris._rd.range_(up_lo, up_hi)
		debris.chunk(x + debris._rd.range_(-30.0, 30.0), y + 4.0, z, vx, vy, sz, debris._rd.range_(1.0, 2.0) * _lk(), tones, 2, 11.0)
		contact_made += 1


func _dust(x: float, y: float, z: float, n: int, s: float, dirx: float, spread: float, biome: String) -> void:
	for i in range(n):
		var vx: float = -dirx * debris._rd.range_(40.0, 260.0) * s + debris._rd.range_(-spread, spread)
		var vy: float = debris._rd.range_(30.0, 180.0) * s
		var sz: float = debris._rd.range_(40.0, 90.0) * (0.6 + 0.5 * s)
		debris.dust_puff(biome, x + debris._rd.range_(-40.0, 40.0), y + debris._rd.range_(0.0, 24.0), z + debris._rd.range_(4.0, 30.0), vx, vy, sz * 0.6, sz * 1.5, debris._rd.range_(1.2, 2.4), i % 3)
		contact_made += 1


## One ground-contact event of World's G3 (type: land, bounce, left_ground, tumble_end, journey_end).
func on_contact(S: SimState, e) -> void:
	var x: float = float(e.x)
	if _on_water(S, x):
		return          # the sea is the skip's (water.gd)
	var z: float = float(e.z) if e.get("z") != null else 0.0
	var y: float = float(e.y)
	var biome: String = VfxPalette.biome_key(x)
	var dirx: float = _dirx(S, e)
	contact_events += 1
	match String(e.type):
		"land":
			var surf: String = String(e.surface)
			var kind: String = String(e.kind)
			var s: float = clampf(float(e.spd) / p("land", "speed_ref"), 0.25, 2.2)
			var ck: float = p("land", "chunks_" + kind) if kind in ["slam", "skid", "tumble"] else 5.0
			var dk: float = p("land", "dust_" + kind) if kind in ["slam", "skid", "tumble"] else 3.0
			var cm: float = 1.0
			var dm: float = 1.0
			if surf == "sand":
				cm = p("land", "sand_chunks")
				dm = p("land", "sand_dust")
			elif surf == "paving":
				cm = p("land", "paving_chunks")
				dm = p("land", "paving_dust")
			var tones: Array = tones_for_surface(surf, x)
			if kind == "slam":
				_chunks(x, y, z, _count(ck * s * cm), tones, 0.0, 0.0, 250.0 * s, 900.0 * s, 650.0 * s, 0.7 + 0.5 * s)
				_dust(x, y, z, _count(dk * s * dm), s, 0.0, 380.0 * s, biome)
			else:
				# a skid or a tumble throws the surface up and back along the way it came
				_chunks(x, y, z, _count(ck * s * cm), tones, dirx, 520.0 * s, 150.0 * s, 650.0 * s, 120.0, 0.6 + 0.4 * s)
				_dust(x, y, z, _count(dk * s * dm), s, dirx, 80.0, biome)
		"bounce":
			var surf2: String = String(e.surface)
			if surf2 == "water":
				return
			var vn: float = absf(float(e.vn))
			var sb: float = clampf(vn / p("bounce", "vn_ref"), 0.25, 1.8)
			var tones2: Array = tones_for_surface(surf2, x)
			_chunks(x, y, z, _count(p("bounce", "chunks") * sb), tones2, dirx, 200.0, 200.0 * sb, 600.0 * sb, 160.0, 0.6 + 0.4 * sb)
			_dust(x, y, z, _count(p("bounce", "dust") * sb), sb, dirx, 60.0, biome)
		"left_ground":
			var cause: String = String(e.cause)
			var sl: float = clampf(float(e.spd) / p("leave", "speed_ref"), 0.25, 2.0)
			var nch: float = p("leave", "chunks_" + cause) if cause in ["lip", "heap", "cliff", "crest", "bounce"] else 0.0
			var tones3: Array = tones_for_surface("rubble" if cause == "heap" else "soil", x)
			# thrown along the way he leaves: the launch vector, spread a little
			var v: Vector2 = Vector2(float(e.vx), float(e.vy))
			var dv: Vector2 = v.normalized() if v.length() > 1.0 else Vector2(dirx, 0.5).normalized()
			var cnt: int = _count(nch * sl)
			for i in range(cnt):
				var ang: float = dv.angle() + debris._rd.range_(-0.5, 0.5)
				var sp: float = debris._rd.range_(300.0, 900.0) * sl
				var sz: float = debris._rd.range_(p("land", "size_min"), p("land", "size_max")) * (0.6 + 0.4 * sl)
				debris.chunk(x, y + 6.0, z, cos(ang) * sp, sin(ang) * sp, sz, debris._rd.range_(1.0, 2.0), tones3, 2, 11.0)
				contact_made += 1
			_dust(x, y, z, _count(p("leave", "dust") * sl), sl, -dirx, 60.0, biome)
		"tumble_end":
			if String(e.kind) == "air":
				return
			_dust(x, y, z, _count(p("settle", "tumble_dust")), 0.7, dirx, 60.0, biome)
		"journey_end":
			var how: String = String(e.kind)
			if how == "water":
				return
			var sj: float = 1.0
			if how == "capped":
				sj = p("settle", "capped_scale")
			if how == "wall":
				_chunks(x, y, z, _count(p("settle", "wall_chunks")), tones_for_surface("rock", x), dirx, 600.0, 250.0, 800.0, 200.0, 1.0)
			_dust(x, y, z, _count(p("settle", "journey_dust") * sj), 0.9 * sj, dirx, 90.0, biome)


## The skid itself, once per unfrozen tick: a body sliding on the ground (`slide` above zero) throws a spray of its surface
## back along the way it came, more of it the faster he goes.
func step_skid(S: SimState) -> void:
	var q: float = _q()
	for i in range(mini(2, S.fighters.size())):
		var f = S.fighters[i]
		var sp: float = float(f.slide)
		if sp < p("skid", "min_speed") or f.state != "launched" or _on_water(S, f.x):
			_acc[i] = 0.0
			continue
		var s: float = clampf(sp / p("skid", "speed_ref"), 0.25, 2.0)
		_acc[i] += p("skid", "rate_per_s") / 60.0 * s * q
		var dirx: float = signf(f.vx) if absf(f.vx) > 1.0 else 1.0
		var surf: String = String(WorldContact.surfaceAt(S, f.x))
		var tones: Array = tones_for_surface(surf, f.x)
		var biome: String = VfxPalette.biome_key(f.x)
		while _acc[i] >= 1.0:
			_acc[i] -= 1.0
			_skid_n[i] += 1
			var sz: float = debris._rd.range_(p("land", "size_min") * 0.5, p("land", "size_max") * 0.7)
			debris.chunk(f.x, WorldTerrain.groundY(S, f.x) + 4.0, f.z + 6.0, -dirx * debris._rd.range_(60.0, 380.0) * s, debris._rd.range_(120.0, 450.0) * s, sz, debris._rd.range_(0.8, 1.5), tones, 2, 12.0)
			contact_made += 1
			if _skid_n[i] % maxi(int(p("skid", "dust_every")), 1) == 0:
				debris.dust_puff(biome, f.x, WorldTerrain.groundY(S, f.x) + 6.0, f.z + 10.0, -dirx * debris._rd.range_(40.0, 200.0), debris._rd.range_(20.0, 90.0), 36.0, 80.0, debris._rd.range_(1.0, 1.8))
				contact_made += 1


## A `dust` event (a skid sample, a heavy landing, a beam over the ground, a building's feet): n puffs in the biome's own dust
## colours (or the colour the event names), scalloped cel puffs that spread and drift up, instead of flat squares.
func on_dust(e, keep_mul: float = 1.0) -> void:
	var n: int = mini(int(e.n), 6)
	var x: float = float(e.x)
	var y: float = float(e.y)
	var z: float = float(e.get("z") if e.get("z") != null else 0.0)
	var biome: String = VfxPalette.biome_key(x)
	var ec: Color = RenderLook.col(String(e.col))
	var tint: Color = ec if (ec.s >= 0.3 and ec.v >= 0.3) else Color(0.0, 0.0, 0.0, 0.0)   # grey dust takes the biome's own colour
	for i in range(n):
		var px: float = x + debris._rd.range_(-40.0, 40.0)
		var py: float = y + debris._rd.range_(0.0, 20.0)
		var vx: float = debris._rd.range_(-90.0, 90.0)
		var vy: float = debris._rd.range_(20.0, 140.0)
		var life: float = debris._rd.range_(0.9, 1.9) * _lk()
		var sz: float = debris._rd.range_(14.0, 34.0)
		var keep: float = debris._rd.next()
		if keep < _q() * keep_mul:
			debris.dust_puff(biome, px, py, z + debris._rd.range_(2.0, 24.0), vx, vy, sz * 1.1, sz * 2.4, life, i % 3, tint)
			dust_made += 1


## A crater (the sim's `crater` event): the ejecta thrown out of the bowl as tumbling chunks of its own earth, and the dust that
## lifts off the rim, as Rendering's ImpactFx drew them as squares. More and bigger with the energy.
func on_crater_ejecta(e) -> void:
	var x: float = float(e.x)
	var biome: String = VfxPalette.biome_key(x)
	var E: float = float(e.energy)
	var r: float = float(e.r)
	var z: float = float(e.get("z") if e.get("z") != null else 0.0)
	var tones: Array = tones_for_surface("soil", x)
	var sws: float = sqrt(SimConst.WS)             # the sim's world-scale factor for speeds of things thrown by world-scale events
	var sp: float = (260.0 + 90.0 * sqrt(maxf(E, 0.0))) * sws
	var nch: int = clampi(int(3.0 + E * 2.0), 3, 30)
	for k in range(nch):
		var off: float = debris._rd.range_(-0.6, 0.6) * r
		var vx: float = (1.0 if off >= 0.0 else -1.0) * debris._rd.range_(0.3, 1.0) * sp
		var vy: float = debris._rd.range_(0.6, 1.4) * sp
		var sz: float = debris._rd.range_(8.0, 13.0 + 2.0 * sqrt(maxf(E, 0.0)))
		var life: float = debris._rd.range_(1.0, 2.0) * _lk()
		if debris._rd.next() < _q():
			debris.chunk(x + off, float(e.y) + 6.0, z + 6.0, vx, vy, sz, life, tones, 2, 10.0)
			contact_made += 1
	var nd: int = clampi(int(4.0 + r / 20.0), 4, 18)
	for k in range(nd):
		var side: float = 1.0 if k % 2 == 0 else -1.0
		var sz: float = debris._rd.range_(18.0, 36.0)
		if debris._rd.next() < _q():
			debris.dust_puff(biome, x + side * r * debris._rd.range_(0.8, 1.25), float(e.y) + float(e.get("rim") if e.get("rim") != null else 0.0) + debris._rd.range_(0.0, 20.0), z + debris._rd.range_(2.0, 24.0), side * debris._rd.range_(20.0, 90.0) * sws, debris._rd.range_(20.0, 110.0) * sws * (0.5 if entrance_now else 1.0), sz * 1.2, sz * 2.6, debris._rd.range_(1.2, 2.4) * _lk(), k % 3)
			contact_made += 1


## Where a knockback slide stopped (the `slide` event: x1, w, energy, variant): a heavier burst of dust and chunks off the
## end berm.
func on_slide_end(S: SimState, e) -> void:
	var x: float = float(e.x1)
	var y: float = WorldTerrain.groundY(S, x)
	var z: float = float(e.get("z1") if e.get("z1") != null else 0.0)
	var biome: String = VfxPalette.biome_key(x)
	var paved: bool = String(e.variant) == "paved"
	var tones: Array = tones_for_surface("paving" if paved else "soil", x)
	var n: int = clampi(int(4.0 + float(e.energy)), 4, 14)
	for k in range(n):
		var sz: float = debris._rd.range_(18.0, 36.0)
		if debris._rd.next() < _q():
			debris.dust_puff(biome, x + debris._rd.range_(-0.5, 0.5) * float(e.w), y + debris._rd.range_(0.0, 16.0), z + debris._rd.range_(2.0, 24.0), debris._rd.range_(-90.0, 90.0) * sqrt(SimConst.WS), debris._rd.range_(30.0, 140.0) * sqrt(SimConst.WS), sz * 1.2, sz * 2.6, debris._rd.range_(1.2, 2.4), k % 3)
			contact_made += 1
	for k in range(clampi(int(2.0 + float(e.energy) * 0.5), 2, 8)):
		if debris._rd.next() < _q():
			debris.chunk(x + debris._rd.range_(-0.5, 0.5) * float(e.w), y + 6.0, z + 6.0, debris._rd.range_(-1.0, 1.0) * 420.0 * sqrt(SimConst.WS), debris._rd.range_(200.0, 600.0) * sqrt(SimConst.WS), debris._rd.range_(8.0, 15.0), debris._rd.range_(1.0, 1.8), tones, 2, 11.0)
			contact_made += 1


## The entrance landing (the sim's `entrance_land`, played intro only): a fighter comes down out of the sky into a crater, so it
## is a slam with more drama than the crater's own 1.5-energy ejecta: clods thrown both ways, a low skirt of dust spreading along
## the ground, a short column of dust, and one thin ring lying on the ground round the crater. Scaled by the height he fell from.
## It is all short and low on purpose: the staredown starts 30 ticks after the second landing, and it is the faces that must read
## then, so the dust lives under a second and a half, hugs the ground and has cleared by about 1.5 s (docs/vfx/README.md, the
## intro reel). The crater itself is the sim's record.
func on_entrance_land(S: SimState, e) -> void:
	var x: float = float(e.x)
	var y: float = float(e.y)
	var z: float = float(e.get("z") if e.get("z") != null else 0.0)
	var r: float = maxf(float(e.get("r") if e.get("r") != null else 0.0), 120.0)
	var s: float = clampf(sqrt(maxf(float(e.y1) - y, 0.0) / 3000.0), 0.7, 2.0)
	var biome: String = VfxPalette.biome_key(x)
	var tones: Array = tones_for_surface("soil", x)
	contact_events += 1
	_chunks(x, y, z, _count(p("land", "chunks_slam") * 1.2 * s), tones, 0.0, 0.0, 300.0 * s, 900.0 * s, 650.0 * s, 0.8 + 0.4 * s)
	# The skirt: puffs along the ground out to both sides, low and quick to go.
	var n: int = _count(8.0 * s)
	for k in range(n):
		var side: float = 1.0 if k % 2 == 0 else -1.0
		var sz: float = debris._rd.range_(45.0, 90.0) * (0.7 + 0.3 * s)
		debris.dust_puff(biome, x + side * debris._rd.range_(20.0, 140.0), y + debris._rd.range_(0.0, 24.0), z + debris._rd.range_(4.0, 36.0), side * debris._rd.range_(200.0, 600.0) * s, debris._rd.range_(10.0, 60.0), sz * 0.6, sz * 1.5, debris._rd.range_(0.8, 1.3), k % 3)
		contact_made += 1
	# The column: a few puffs off the impact, rising a little and gone in about a second.
	for k in range(_count(3.0 * s)):
		var sz2: float = debris._rd.range_(55.0, 95.0) * (0.7 + 0.3 * s)
		debris.dust_puff(biome, x + debris._rd.range_(-50.0, 50.0), y + debris._rd.range_(10.0, 70.0), z + debris._rd.range_(4.0, 30.0), debris._rd.range_(-60.0, 60.0), debris._rd.range_(60.0, 150.0) * s, sz2 * 0.6, sz2 * 1.3, debris._rd.range_(0.9, 1.4), 2)
		contact_made += 1
	# One ring lying on the ground round the crater: from just inside its lip out to about twice its radius, in half a second.
	if not debris.reduced:
		debris._ring(x, y + 18.0, z + 8.0, r * 0.7, r * 1.4 / 0.5, 0.5, true)
