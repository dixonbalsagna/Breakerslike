extends SceneTree
# the cost of a dig, a trench, a heap and a groundY read: depth off against depth on
func bench(depth: bool) -> void:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 1, {}, {"depth": depth, "intro": false})
	S.out.fx.clear()
	var X0: float = 89600.0 + 2000.0
	var t0: int = Time.get_ticks_usec()
	for n in range(200):
		WorldCrater.dig(S, X0 + float(n % 40) * 900.0, 1.0 + float(n % 5), null, "impact", 0.0, 1.0, false, -300.0 * float(n % 6))
		S.out.fx.clear()
		if S.craters.size() > 300:
			S.craters.clear()
	var dig_us: float = float(Time.get_ticks_usec() - t0) / 200.0
	t0 = Time.get_ticks_usec()
	for n in range(200):
		WorldCrater.carveSegment(S, X0 + float(n) * 20.0, X0 + float(n) * 20.0 + 400.0, 25.0, false, 0.0, -300.0 * float(n % 6))
	var carve_us: float = float(Time.get_ticks_usec() - t0) / 200.0
	t0 = Time.get_ticks_usec()
	var acc: float = 0.0
	for n in range(20000):
		acc += WorldTerrain.groundY(S, X0 + float(n % 500) * 7.0, -300.0 * float(n % 6) if depth else 0.0)
	var g_us: float = float(Time.get_ticks_usec() - t0) / 20000.0
	print("COST depth %s: dig %.0f us, trench %.0f us, groundY %.2f us" % ["on" if depth else "off", dig_us, carve_us, g_us])
	SimCore.dispose(S)


func _init() -> void:
	bench(false)
	bench(true)
	quit(0)
