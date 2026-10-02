extends SceneTree
var fails: int = 0
func ok(c: bool, w: String) -> void:
	print("  %s  %s" % ["ok  " if c else "FAIL", w])
	if not c:
		fails += 1
func fresh() -> SimState:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 1, {}, {"intro": false})
	S.out.fx.clear()
	return S
func _init() -> void:
	print("== blast: what a shot does where it ends ==")
	ok(WorldBlast.errors().is_empty(), "the data loads (%s)" % str(WorldBlast.errors()))
	var X: float = 89600.0 + 3000.0
	for kind in ["bolt", "lob", "charged"]:
		var line: String = "  %s on open ground (vertical hit) by tier:" % kind
		for t in [1, 2, 3, 4]:
			var S := fresh()
			S.fighters[0].tier = float(t)
			var rng0: int = S.rng.state_i32()
			var r := WorldBlast.shotHit(S, 0, kind, X, WorldTerrain.groundY(S, X), 0.0, 0.0, -2000.0, "ground")
			ok(S.rng.state_i32() == rng0, "%s tier %d draws nothing from the rng" % [kind, t]) if t == 1 else null
			var c = r.crater
			line += "  t%d %s" % [t, "no crater" if c == null else "R %.0f depth %.0f" % [c.r, c.depth]]
		print(line)
	# a glancing bolt digs less than a vertical one
	var S1 := fresh()
	var v1 := WorldBlast.shotHit(S1, 0, "charged", X, WorldTerrain.groundY(S1, X), 0.0, 5000.0, -300.0, "ground")
	var S2 := fresh()
	var v2 := WorldBlast.shotHit(S2, 0, "charged", X, WorldTerrain.groundY(S2, X), 0.0, 300.0, -5000.0, "ground")
	ok(v1.crater != null and v2.crater != null and v1.crater.depth < v2.crater.depth, "a glancing charged shot digs a shallower bowl than a vertical one (%.0f against %.0f units)" % [v1.crater.depth if v1.crater != null else 0.0, v2.crater.depth if v2.crater != null else 0.0])
	# the town: structures around the point
	var S3 := fresh()
	var bt = null
	for b in S3.buildings:
		if b.row == 1.0 and b.h > 2000.0:
			bt = b
			break
	var txt: String = "  at the foot of a 20-floor front-row tower, buildings levelled by kind and tier:"
	for kind in ["bolt", "lob", "charged"]:
		for t in [1, 4]:
			var Sx := fresh()
			Sx.fighters[0].tier = float(t)
			var tb = Sx.buildings[bt.idx]
			var lost0: float = Sx.world.structuresLost
			var hp0: float = tb.hp
			var r2 := WorldBlast.shotHit(Sx, 0, kind, tb.x, WorldTerrain.groundY(Sx, tb.x), 0.0, 0.0, -2000.0, "ground")
			txt += " %s t%d: levelled %d, the tower at %.0f%% hp;" % [kind, t, r2.levelled, 100.0 * tb.hp / hp0]
	print(txt)
	# water
	var S4 := fresh()
	var ev0: int = S4.out.fx.size()
	var r4 := WorldBlast.shotHit(S4, 0, "charged", -1000.0, -50.0, 0.0, 0.0, -1000.0, "water")
	ok(r4.crater == null and S4.out.fx.size() > ev0, "a shot into water leaves a splash and no crater")
	# cost
	var S5 := fresh()
	var t0: int = Time.get_ticks_usec()
	for n in range(200):
		WorldBlast.shotHit(S5, 0, "bolt", X + float(n) * 400.0, WorldTerrain.groundY(S5, X + float(n) * 400.0), 0.0, 0.0, -2000.0, "ground")
		S5.out.fx.clear()
	print("  cost: a bolt's end %.0f us, " % (float(Time.get_ticks_usec() - t0) / 200.0))
	var t1: int = Time.get_ticks_usec()
	for n in range(100):
		WorldBlast.shotHit(S5, 0, "charged", X + 90000.0 + float(n) * 600.0, WorldTerrain.groundY(S5, X), 0.0, 0.0, -2000.0, "ground")
		S5.out.fx.clear()
	print("  a charged shot's end %.0f us" % (float(Time.get_ticks_usec() - t1) / 100.0))
	print("BLAST: %d check(s) failed" % fails)
	quit(1 if fails > 0 else 0)
