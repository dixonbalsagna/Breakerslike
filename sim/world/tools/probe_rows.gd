extends SceneTree
# Slice T checks: the depth rows, with depth forced on, against the old model with it off.
var fails: int = 0
const BH: float = 75.0

func ok(cond: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1


func fresh(depth: bool, seed: int = 1) -> SimState:
	var S := SimCore.createSim()
	SimCore.newMatch(S, seed, {}, {"depth": depth, "intro": false})
	S.out.fx.clear()
	return S


func rowsChanged(S: SimState, ref: Array) -> Array:
	# which rows differ from the reference arrays (the deform of each row before)
	var out: Array = []
	for k in range(WorldTerrain.ROWS):
		var a: PackedFloat32Array = WorldTerrain.rowArr(S, k)
		var diff: float = 0.0
		for i in range(a.size()):
			diff += absf(a[i] - ref[k][i])
		out.append(diff)
	return out


func snapshot(S: SimState) -> Array:
	var out: Array = []
	for k in range(WorldTerrain.ROWS):
		out.append(WorldTerrain.rowArr(S, k).duplicate())
	return out


func _init() -> void:
	var X: float = 89600.0 + 3000.0   # open desert, clear of any building
	print("== T: terrain rows (depth forced on) ==")
	var S1 := fresh(true)
	ok(S1.depthOn and S1.deformZ.size() == 8 and S1.low.size() == SimConst.NC, "depth on makes eight rows and the low array; depth off makes none")
	var S0 := fresh(false)
	ok(S0.deformZ.is_empty() and S0.low.is_empty(), "with depth off there are no rows")
	# a. a dig at z = 0 on open ground: the plane row is the old crater, bit for bit
	var ca = WorldCrater.dig(S0, X, 3.0, S0.fighters[0], "impact", 0.0, 1.0)
	var cb = WorldCrater.dig(S1, X, 3.0, null, "impact", 0.0, 1.0, false, 0.0)
	var same: bool = ca != null and cb != null
	for i in range(SimConst.NC):
		if S0.deform[i] != S1.deform[i]:
			same = false
	ok(same, "a dig at z = 0 on open ground leaves the plane row bit for bit as the old model's")
	var wsame: bool = true
	for i in range(SimConst.NC):
		if S0.water[i] != S1.water[i]:
			wsame = false
	ok(wsame, "and the water is the same")
	# b. a small crater at z = -600 lands on its row; the plane row is untouched
	var S2 := fresh(true)
	var ref2: Array = snapshot(S2)
	var rec2 = WorldCrater.dig(S2, X, 1.0, null, "impact", 0.0, 1.0, false, -600.0)
	var ch: Array = rowsChanged(S2, ref2)
	var line: String = "  changed by row (z +300 .. -1800):"
	for k in range(8):
		line += " %.0f" % ch[k]
	print(line)
	ok(rec2 != null and ch[3] > 0.0 and ch[1] == 0.0 and ch[0] == 0.0 and ch[7] == 0.0, "a dig at z = -600 digs row z = -600; the plane row and the far rows are untouched")
	ok(ch[2] > 0.0 and ch[4] > 0.0 and ch[2] < ch[3] and ch[4] < ch[3], "its neighbours get a smaller bowl")
	# c. a big crater: the depth falls with plan distance across rows, and the step between rows stays inside the repose
	var S3 := fresh(true)
	WorldCrater.dig(S3, X, 10.0, null, "impact", 0.0, 1.0, false, -900.0)
	var prof: Array = []
	var maxstep: float = 0.0
	var c0: int = int(floor(X / SimConst.COL))
	for k in range(8):
		var mn: float = 0.0
		for q in range(-60, 61):
			mn = minf(mn, WorldTerrain.rowArr(S3, k)[c0 + q])
		prof.append(mn)
	for k in range(7):
		for q in range(-60, 61):
			maxstep = maxf(maxstep, absf(WorldTerrain.rowArr(S3, k + 1)[c0 + q] - WorldTerrain.rowArr(S3, k)[c0 + q]))
	print("  a bowl of energy 10 at z = -900: deepest point on each row %s; largest step between neighbouring rows %.0f (limit %.0f)" % [str(prof.map(func(v): return int(v))), maxstep, WorldCrater.REPOSE_SLOPE * 300.0])
	ok(prof[4] <= prof[3] and prof[4] <= prof[5] and prof[3] <= prof[2] and prof[5] <= prof[6], "the bowl is deepest on its own row and shallower with plan distance")
	ok(maxstep <= WorldCrater.REPOSE_SLOPE * 300.0 + 1.0, "no step between neighbouring rows exceeds the angle of repose over a row's spacing")
	# d. low is the minimum over the rows after a run of mixed writes
	var S4 := fresh(true)
	WorldCrater.dig(S4, X, 4.0, null, "impact", 0.0, 1.0, false, -300.0)
	WorldCrater.dig(S4, X + 400.0, 4.0, null, "impact", 0.0, 1.0, false, -1200.0)
	WorldCrater.carveSegment(S4, X - 800.0, X - 200.0, 30.0, false, 0.0, -600.0)
	WorldCrater.berm(S4, X - 150.0, 1.0, 40.0, 20.0, -900.0)
	var lowok: bool = true
	for i in range(SimConst.NC):
		var m: float = 1.0e9
		for k in range(8):
			m = minf(m, WorldTerrain.rowArr(S4, k)[i])
		if absf(m - S4.low[i]) > 0.001:
			lowok = false
	ok(lowok, "low equals the minimum over the rows after digs, a trench and a berm")
	# e. groundY: the plane row at z = 0, a blend between rows, the edge rows beyond the band
	var g0: float = WorldTerrain.groundY(S4, X)
	var gr1: float = S4.base[int(floor(X / SimConst.COL))]
	ok(WorldTerrain.groundY(S4, X, 0.0) == g0, "groundY(x, 0) is the plane row")
	var ga: float = WorldTerrain.groundY(S4, X, -300.0)
	var gb: float = WorldTerrain.groundY(S4, X, -600.0)
	var gm: float = WorldTerrain.groundY(S4, X, -450.0)
	ok(absf(gm - 0.5 * (ga + gb)) < 0.01, "halfway between two rows the ground is the mean of the two")
	ok(WorldTerrain.groundY(S4, X, 5000.0) == WorldTerrain.groundY(S4, X, 300.0) and WorldTerrain.groundY(S4, X, -5000.0) == WorldTerrain.groundY(S4, X, -1800.0), "beyond the band the edge rows hold")
	ok(WorldTerrain.groundY(fresh(false), X, -600.0) == WorldTerrain.groundY(fresh(false), X), "with depth off z is ignored")
	# f. a heap goes on the rows inside the footprint only
	var S5 := fresh(true)
	var bt = null
	for b in S5.buildings:
		if b.row == 1.0 and b.h > 2000.0:
			bt = b
			break
	var ref5: Array = snapshot(S5)
	WorldStructures.damageBuilding(S5, bt, 1.0e9, S5.fighters[1], "implode", bt.x, 0.0)
	var ch5: Array = rowsChanged(S5, ref5)
	var inside: Array = []
	for k in range(8):
		var zk: float = WorldTerrain.rowZOf(k)
		inside.append(zk > bt.z - bt.d * 0.5 and zk < bt.z + bt.d * 0.5)
	var line5: String = "  tower z %.0f depth %.0f: rows inside %s; changed by row:" % [bt.z, bt.d, str(inside)]
	for k in range(8):
		line5 += " %.0f" % ch5[k]
	print(line5)
	var heapok: bool = true
	for k in range(8):
		if inside[k] != (ch5[k] > 0.0):
			heapok = false
	ok(heapok, "a collapsed tower's heap is on the rows strictly inside its depth interval, and only those")
	# g. a match plays with depth on: no NaN, determinism, rows hashed
	var h1: Array = []
	for rep_ in range(2):
		var S6 := SimCore.createSim()
		SimCore.newMatch(S6, 7, {}, {"depth": true, "intro": false})
		SimGolden.applyArm("default", S6.fighters)
		var steps: int = 0
		while S6.game.ko == null and steps < 20000:
			SimCore.step(S6, null)
			S6.out.fx.clear()
			S6.out.feed.clear()
			steps += 1
		var nan: bool = false
		for k in range(8):
			for v in WorldTerrain.rowArr(S6, k):
				if is_nan(v):
					nan = true
		ok(not nan, "a depth-on match (seed 7, %d ticks) has no NaN in any row" % steps)
		h1.append(SimHash.stateHash(S6))
		SimCore.dispose(S6)
	ok(str(h1[0]) == str(h1[1]), "two depth-on runs of one seed give the same state hash")
	print("T: %d check(s) failed" % fails)
	quit(1 if fails > 0 else 0)
