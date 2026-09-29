extends SceneTree
## Engine spike (throwaway, research only). Rough cost of the GDScript operations the sim port is made of, in ns per
## operation (loop overhead subtracted), to explain the GDScript/V8 throughput ratio. Smoke numbers only.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path research/engine-spike/godot -s res://tests/microbench.gd
## Prints one line per operation and a MICROBENCH JSON line.

const _Wrap = preload("res://sim/wrap.gd")
const _Terrain = preload("res://sim/terrain.gd")
const _Fighter = preload("res://sim/fighter.gd")
const _Rng = preload("res://sim/rng.gd")

const N: int = 1000000
const W: float = 9600.0

var sink: float = 0.0


static func _add1(x: float) -> float:
	return x + 1.0


func _m_add1(x: float) -> float:
	return x + 1.0


func _time(label: String, fn: Callable, base_ns: float, out: Dictionary) -> float:
	var best: float = INF
	for rep in 3:
		var t0: int = Time.get_ticks_usec()
		fn.call()
		var ns: float = float(Time.get_ticks_usec() - t0) * 1000.0 / float(N)
		best = minf(best, ns)
	var net: float = best - base_ns
	out[label] = snappedf(net, 0.1)
	print("%-44s %7.1f ns/op  (raw %.1f)" % [label, net, best])
	return best


func _init() -> void:
	var out: Dictionary = {}
	var terrain := _Terrain.new()
	var f := _Fighter.new(10.0, 20.0)
	var rng := _Rng.new(7)
	var arr := PackedFloat64Array()
	arr.resize(1024)
	arr.fill(1.0)
	var d: Dictionary = {"sx": 0.0, "sy": 0.0, "tx": 0.0, "ty": 0.0, "owner": 0}
	var events: Array[Dictionary] = []

	var base: float = _time("empty typed for-loop iteration", func() -> void:
		for i in N:
			pass, 0.0, out)
	_time("float mul + add (typed locals)", func() -> void:
		var x: float = 1.0
		for i in N:
			x = x * 1.0000001 + 0.5
		sink = x, base, out)
	_time("int ops (imul-style mask/shift)", func() -> void:
		var t: int = 12345
		for i in N:
			t = (t * (t & 0xFFFF) + (((t * (t >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF
		sink = float(t), base, out)
	_time("fmod() utility call", func() -> void:
		var x: float = 12345.5
		for i in N:
			x = fmod(x + 7.0, W)
		sink = x, base, out)
	_time("floori() utility call", func() -> void:
		var k: int = 0
		var c: float = 3.5
		for i in N:
			k += floori(c)
		sink = float(k), base, out)
	_time("static func call, same script", func() -> void:
		var x: float = 0.0
		for i in N:
			x = _add1(x)
		sink = x, base, out)
	_time("method call on self", func() -> void:
		var x: float = 0.0
		for i in N:
			x = _m_add1(x)
		sink = x, base, out)
	_time("static call via preloaded script (wrapx)", func() -> void:
		var x: float = 0.0
		for i in N:
			x = _Wrap.wrapx(x + 7.0)
		sink = x, base, out)
	_time("typed method call (terrain.ground_y)", func() -> void:
		var x: float = 0.0
		var s: float = 0.0
		for i in N:
			s += terrain.ground_y(x)
			x += 7.0
		sink = s, base, out)
	_time("typed object field read+write (f.x)", func() -> void:
		for i in N:
			f.x = f.x + 1.0
		sink = f.x, base, out)
	_time("PackedFloat64Array get + set", func() -> void:
		for i in N:
			arr[i & 1023] = arr[(i + 1) & 1023] + 1.0
		sink = arr[0], base, out)
	_time("Dictionary set, String key", func() -> void:
		var x: float = 0.0
		for i in N:
			d["tx"] = x
			x += 1.0
		sink = x, base, out)
	_time("Dictionary literal (4 keys) + append", func() -> void:
		for i in N:
			if (i & 255) == 0:
				events.clear()
			events.append({"kind": 0, "x": 1.0, "y": 2.0, "r": 3.0})
		sink = float(events.size()), base, out)
	_time("rng.next() (mulberry32)", func() -> void:
		var s: float = 0.0
		for i in N:
			s += rng.next()
		sink = s, base, out)
	print("MICROBENCH " + JSON.stringify(out, "", false))
	quit(0)
