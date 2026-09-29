class_name SpikeScenes
extends RefCounted
## Engine spike (throwaway, research only). The scenes of shared/sim-ref.mjs: WorstScene, FlightScene, ScriptScene.
##
## Every scene has: name, tick, terrain (SpikeTerrain), a and b (SpikeFighter), beams (Array of Dictionary
## {sx, sy, tx, ty, owner}), events (this tick only, Array of Dictionary {kind: 0 crater | 1 big crater, x, y, r}),
## rng (SpikeRng or null), step(), and set_input(ix, iy) (a no-op except in flight).
## The renderer reads these and never writes them.
##
## Bit-exact port rules followed here: float64 scalars only, int -> float before any division, fmod for JS %,
## the JS expression order, and the same number and order of RNG draws.

const _Rng = preload("res://sim/rng.gd")
const _Terrain = preload("res://sim/terrain.gd")
const _Fighter = preload("res://sim/fighter.gd")

const W: float = 9600.0          # SpikeWrap.W
const HALF: float = 4800.0       # SpikeWrap.HALF
const DT: float = 1.0 / 60.0     # SpikeWrap.DT
const NBEAMS: int = 6


static func make_scene(name: String, seed: int = -1) -> RefCounted:
	if name == "worst":
		return WorstScene.new(7 if seed == -1 else seed)
	if name == "flight":
		return FlightScene.new(11 if seed == -1 else seed)
	if name == "sweep" or name == "chase" or name == "orbit" or name == "climb":
		return ScriptScene.new(name)
	push_error("SpikeScenes.make_scene: unknown scene " + name)
	return null


## Common shape of every scene, plus the helpers the scenes share. (Inner classes cannot call the outer
## class's static functions, so the wrap helpers live here and are inherited.)
class Scene:
	extends RefCounted

	var name: String = ""
	var tick: int = 0
	var terrain: _Terrain
	var a: _Fighter
	var b: _Fighter
	var beams: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	var rng: _Rng = null

	func step() -> void:
		pass

	func set_input(_ix: float, _iy: float) -> void:
		pass

	## wrap(x): ((x % W) + W) % W
	static func wrapx(x: float) -> float:
		return fmod(fmod(x, W) + W, W)

	## tri(n, period) for int ticks; float conversion before the division.
	static func tri(n: int, period: int) -> float:
		var p: float = float(n % period) / float(period)
		if p < 0.5:
			return 2.0 * p
		return 2.0 - 2.0 * p


## Worst case for the benchmark: six beams that never stop, 60 craters a second, a power-up crater every two seconds.
## The pair's centre flies east at 600 u/s (it crosses the seam every 16 s) while their separation swings 300..4600.
class WorstScene:
	extends Scene

	func _init(seed: int = 7) -> void:
		name = "worst"
		terrain = _Terrain.new()
		rng = _Rng.new(seed)
		tick = 0
		a = _Fighter.new(0.0, 0.0)
		b = _Fighter.new(0.0, 0.0)
		for i in NBEAMS:
			beams.append({"sx": 0.0, "sy": 0.0, "tx": 0.0, "ty": 0.0, "owner": 0 if i < 3 else 1})
		place(0)
		aim_beams(0)

	func place(n: int) -> void:
		var c: float = wrapx(float(2400 + 10 * n))
		var sep: float = 300.0 + 4300.0 * tri(n, 600)
		a.x = wrapx(c - sep / 2.0)
		b.x = wrapx(c + sep / 2.0)
		a.y = 150.0 + 750.0 * tri(n, 420)
		b.y = 150.0 + 750.0 * tri(n + 210, 420)

	func aim_beams(n: int) -> void:
		for i in NBEAMS:
			var src: _Fighter = a if i < 3 else b
			var dir: float = 1.0 if i < 3 else -1.0
			var bm: Dictionary = beams[i]
			bm["sx"] = src.x
			bm["sy"] = src.y + 40.0
			var tx: float = wrapx(src.x + dir * (250.0 + 900.0 * tri(n + 37 * i, 180 + 30 * i)))
			bm["tx"] = tx
			bm["ty"] = terrain.ground_y(tx)

	func step() -> void:
		tick += 1
		var n: int = tick
		events.clear()
		place(n)
		aim_beams(n)
		for i in NBEAMS:
			if n % 6 != i:
				continue
			var bm: Dictionary = beams[i]
			var r: float = rng.range_(40.0, 120.0)
			var depth: float = rng.range_(10.0, 30.0)
			var tx: float = bm["tx"]
			terrain.crater(tx, r, depth)
			var ty: float = terrain.ground_y(tx)
			bm["ty"] = ty
			events.append({"kind": 0, "x": tx, "y": ty, "r": r})
		if n % 120 == 60:
			# JS Math.floor(n / 120): float division then floor (the same as int division for n >= 0).
			var f: _Fighter = a if floori(float(n) / 120.0) % 2 == 0 else b
			terrain.crater(f.x, 300.0, 80.0)
			events.append({"kind": 1, "x": f.x, "y": terrain.ground_y(f.x), "r": 300.0})


## Free flight for the demo: two boxes steer toward random velocities (seeded), cross the seam often, and a crater
## lands under one of them every half second. set_input() lets a human fly box a (deterministic per tick).
class FlightScene:
	extends Scene

	var ix: float = 0.0
	var iy: float = 0.0
	var human: bool = false

	func _init(seed: int = 11) -> void:
		name = "flight"
		terrain = _Terrain.new()
		rng = _Rng.new(seed)
		tick = 0
		a = _Fighter.new(9300.0, 400.0)
		b = _Fighter.new(250.0, 500.0)
		ix = 0.0
		iy = 0.0
		human = false

	func set_input(p_ix: float, p_iy: float) -> void:
		human = true
		ix = -1.0 if p_ix < -1.0 else (1.0 if p_ix > 1.0 else p_ix)   # JS clamp(ix, -1, 1)
		iy = -1.0 if p_iy < -1.0 else (1.0 if p_iy > 1.0 else p_iy)

	func steer(f: _Fighter, idx: int, n: int) -> void:
		if n % 90 == idx * 45:
			f.tvx = rng.range_(-1800.0, 1800.0)
			f.tvy = rng.range_(-300.0, 300.0)
		if idx == 0 and human:
			f.tvx = ix * 1800.0
			f.tvy = iy * 600.0
		f.vx = f.vx + (f.tvx - f.vx) * 0.05
		f.vy = f.vy + (f.tvy - f.vy) * 0.05
		f.x = wrapx(f.x + f.vx * DT)
		var y: float = f.y + f.vy * DT
		var g: float = terrain.ground_y(f.x) + 30.0
		if y < g:
			y = g
			if f.vy < 0.0:
				f.vy = 0.0
		if y > 2400.0:
			y = 2400.0
			if f.vy > 0.0:
				f.vy = 0.0
		f.y = y

	func step() -> void:
		tick += 1
		var n: int = tick
		events.clear()
		steer(a, 0, n)
		steer(b, 1, n)
		if n % 30 == 0:
			var f: _Fighter = a if rng.next() < 0.5 else b
			var r: float = rng.range_(60.0, 160.0)
			var depth: float = rng.range_(20.0, 60.0)
			terrain.crater(f.x, r, depth)
			events.append({"kind": 0, "x": f.x, "y": terrain.ground_y(f.x), "r": r})


## Scripted paths for the seam and camera tests. Positions are closed-form in the tick count (no accumulated error).
##   sweep: boxes fly apart in opposite directions at 1500 u/s from x = 9000; separation runs 0..4800, the short
##          arc flips, and both cross the seam repeatedly.
##   chase: same direction across the seam at 1200 and 1320 u/s.
##   orbit: centre drifts east at 300 u/s; separation swings 4500..5100, so it hovers around half the planet.
##   climb: separation 100..4700 while the height difference swings 0..2000 (vertical framing).
class ScriptScene:
	extends Scene

	var kind: String = ""
	var _k: int = -1   # 0 sweep, 1 chase, 2 orbit, 3 climb

	func _init(p_kind: String) -> void:
		name = p_kind
		kind = p_kind
		terrain = _Terrain.new()
		tick = 0
		a = _Fighter.new(0.0, 0.0)
		b = _Fighter.new(0.0, 0.0)
		_k = ["sweep", "chase", "orbit", "climb"].find(p_kind)
		if _k < 0:
			push_error("SpikeScenes.ScriptScene: unknown script " + p_kind)
		place(0)

	func place(n: int) -> void:
		if _k == 0:
			a.x = wrapx(float(9000 + 25 * n))
			b.x = wrapx(float(9000 - 25 * n))
			a.y = 300.0
			b.y = 500.0
		elif _k == 1:
			a.x = wrapx(float(9100 + 20 * n))
			b.x = wrapx(float(9300 + 22 * n))
			a.y = 400.0
			b.y = 450.0
		elif _k == 2:
			var c: float = wrapx(float(9000 + 5 * n))
			var s: float = 4500.0 + 600.0 * tri(n, 240)
			a.x = wrapx(c - s / 2.0)
			b.x = wrapx(c + s / 2.0)
			a.y = 300.0
			b.y = 350.0
		elif _k == 3:
			var c: float = wrapx(float(9400 + 8 * n))
			var s: float = 100.0 + 4600.0 * tri(n, 900)
			a.x = wrapx(c - s / 2.0)
			b.x = wrapx(c + s / 2.0)
			a.y = 100.0
			b.y = 100.0 + 2000.0 * tri(n, 300)

	func step() -> void:
		tick += 1
		var n: int = tick
		events.clear()
		place(n)
