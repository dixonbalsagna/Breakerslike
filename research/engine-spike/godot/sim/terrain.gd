class_name SpikeTerrain
extends RefCounted
## Engine spike (throwaway, research only). Terrain from shared/sim-ref.mjs: value-noise heights on the prototype's
## biome segments, four 25-column box blurs, and bowl craters. Bit-exact port: float64 + - * / floor ceil fmod only,
## every expression in the JS order.
##
## Dependencies are preloaded (not referenced by global class_name) so the headless tests run even when the
## project's global class cache is stale or missing.

const _Rng = preload("res://sim/rng.gd")

const W: float = 9600.0          # SpikeWrap.W
const COL: int = 8               # SpikeWrap.COL
const NC: int = 1200             # SpikeWrap.NC
const TERRAIN_SEED: int = 4242
const DEFORM_MIN: float = -260.0
const SEA_BASE: float = -30.0

const BIOME_OCEAN: int = 0
const BIOME_PLAINS: int = 1
const BIOME_CITY: int = 2
const BIOME_VILLAGE: int = 3
const BIOME_FOREST: int = 4
const BIOME_DESERT: int = 5
const BIOME_MOUNTAINS: int = 6
const BIOME_NAMES = ["ocean", "plains", "city", "village", "forest", "desert", "mountains"]
## Same segments as the prototype: [start x, end x, biome].
const SEG = [[0, 1200, 0], [1200, 1800, 3], [1800, 2350, 1], [2350, 3850, 2], [3850, 4500, 3], [4500, 5500, 4],
	[5500, 6500, 5], [6500, 7600, 6], [7600, 8000, 3], [8000, 8300, 1], [8300, 9600, 0]]

var base: PackedFloat64Array
var deform: PackedFloat64Array
var version: int = 0   # bumped on every change; renderers re-upload heights when it moves


func _init(seed: int = TERRAIN_SEED) -> void:
	base = gen_terrain(seed)
	deform = PackedFloat64Array()
	deform.resize(NC)
	deform.fill(0.0)
	version = 0


static func biome_at(x: float) -> int:
	x = fmod(fmod(x, W) + W, W)   # wrap(x)
	for s in SEG:
		if x >= float(s[0]) and x < float(s[1]):
			return s[2]
	return BIOME_PLAINS


static func _lattice(rng: _Rng, cells: int) -> PackedFloat64Array:
	var v := PackedFloat64Array()
	v.resize(cells)
	for k in cells:
		v[k] = rng.next() * 2.0 - 1.0
	return v


## Value noise over column index i (an int) with `per` columns per lattice cell. The lattice wraps (NC % per == 0).
## JS: c = i / per is a float division, so both operands are converted to float first.
static func _vnoise(v: PackedFloat64Array, i: int, per: int) -> float:
	var c: float = float(i) / float(per)
	var kf: float = floorf(c)
	var f: float = c - kf
	var s: float = f * f * (3.0 - 2.0 * f)
	var k: int = int(kf)
	var n: int = v.size()
	var a: float = v[k % n]
	var b: float = v[(k + 1) % n]
	return a + (b - a) * s


static func gen_terrain(seed: int) -> PackedFloat64Array:
	var rng := _Rng.new(seed)
	var n1: PackedFloat64Array = _lattice(rng, 12)
	var n2: PackedFloat64Array = _lattice(rng, 48)
	var n3: PackedFloat64Array = _lattice(rng, 150)
	var m1: PackedFloat64Array = _lattice(rng, 24)
	var t := PackedFloat64Array()
	t.resize(NC)
	for i in NC:
		var x: int = i * COL
		var b: int = biome_at(float(x))
		var n: float = 0.5 * _vnoise(n1, i, 100) + 0.3 * _vnoise(n2, i, 25) + 0.2 * _vnoise(n3, i, 8)
		var h: float = 0.0
		if b == BIOME_OCEAN:
			h = -340.0 + n * 35.0
		elif b == BIOME_MOUNTAINS:
			# JS (x - 6500) / 1100 with an int x: the subtraction is exact, the division is float.
			var k: float = float(x - 6500) / 1100.0
			if k < 0.0:
				k = 0.0
			elif k > 1.0:
				k = 1.0
			var env: float = 4.0 * k * (1.0 - k)
			var r: float = _vnoise(m1, i, 50)
			if r < 0.0:
				r = -r
			h = env * (330.0 + 560.0 * r * (0.55 + 0.45 * _vnoise(n3, i, 8)))
		elif b == BIOME_DESERT:
			h = n * 28.0
		elif b == BIOME_PLAINS:
			h = n * 16.0
		elif b == BIOME_FOREST:
			h = 10.0 + n * 22.0
		t[i] = h
	# Four passes of a 25-column box blur, as in the prototype. Sum k = -12..12 in that order, then divide.
	# (A running sum would be faster but changes the rounding, so it would break the goldens.)
	var a: PackedFloat64Array = t
	var bf := PackedFloat64Array()
	bf.resize(NC)
	for p in 4:
		for i in NC:
			var s: float = 0.0
			for k in range(-12, 13):
				s += a[(i + k + NC) % NC]
			bf[i] = s / 25.0
		var tmp: PackedFloat64Array = a
		a = bf
		bf = tmp
	return a


func height(i: int) -> float:
	return base[i] + deform[i]


func is_sea(i: int) -> bool:
	return base[i] < SEA_BASE


func ground_y(x: float) -> float:
	var c: float = fmod(fmod(x, W) + W, W) / float(COL)   # wrap(x) / COL
	var i: int = floori(c)
	var f: float = c - float(i)
	var j: int = (i + 1) % NC
	var a: float = base[i] + deform[i]
	var b: float = base[j] + deform[j]
	return a + (b - a) * f


## Bowl crater with a (1 - u^2)^2 falloff, clamped so the planet never goes below DEFORM_MIN of deformation.
func crater(x: float, r: float, depth: float) -> void:
	var c0: int = floori(fmod(fmod(x, W) + W, W) / float(COL))
	var n: int = ceili(r / float(COL))
	for k in range(-n, n + 1):
		var i: int = (c0 + k + NC) % NC
		# JS (k < 0 ? -k : k) * COL / r: the int product is exact, then a float division.
		var u: float = float((-k if k < 0 else k) * COL) / r
		if u > 1.0:
			u = 1.0
		var f: float = 1.0 - u * u
		var v: float = deform[i] - depth * f * f
		deform[i] = DEFORM_MIN if v < DEFORM_MIN else v
	version += 1
