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
	print("== mark: a missed power-1 shot ==")
	var X: float = 89600.0 + 3000.0
	var S := fresh()
	var rng0: int = S.rng.state_i32()
	var nc: int = S.craters.size()
	var dfm0: float = S.deform[int(X / SimConst.COL)]
	var r := WorldBlast.shotHit(S, 0, "bolt", X, WorldTerrain.groundY(S, X), 0.0, 0.0, -2000.0, "ground", 1.0)
	ok(r.crater == null and S.craters.size() == nc, "a power-1 bolt digs no crater")
	var c0: int = int(X / SimConst.COL)
	ok(S.scorch[c0] > 0.4, "it raises a scorch mark (%.2f)" % S.scorch[c0])
	ok(S.deform[c0] == dfm0, "the ground height is not changed")
	ok(S.rng.state_i32() == rng0, "draws nothing from the rng")
	var sc := 0
	for e in S.out.fx:
		if e.type == "scorch":
			sc += 1
	print("  fx events: ", S.out.fx.size(), " scorch events ", sc)
	var r2 := WorldBlast.shotHit(fresh(), 0, "charged", X, WorldTerrain.groundY(S, X), 0.0, 0.0, -2000.0, "ground", 1.0)
	ok(r2.crater == null, "a charged shot worn down to power 1 is a mark too")
	var r3 := WorldBlast.shotHit(fresh(), 0, "arc", X, WorldTerrain.groundY(S, X), 0.0, 0.0, -2000.0, "ground", 2.0)
	ok(r3.crater != null, "an arc (power 2) digs")
	var r4 := WorldBlast.shotHit(fresh(), 0, "lob", X, WorldTerrain.groundY(S, X), 0.0, 0.0, -2000.0, "ground", 3.0)
	ok(r4.crater != null, "a lob (power 3) digs")
	# the structures: the foot of a tower
	var S3 := fresh()
	var bt = null
	for b in S3.buildings:
		if b.row == 1.0 and b.h > 2000.0:
			bt = b
			break
	var hp0: float = bt.hp
	WorldBlast.shotHit(S3, 0, "bolt", bt.x, WorldTerrain.groundY(S3, bt.x), 0.0, 0.0, -2000.0, "ground", 1.0)
	ok(bt.hp == hp0, "a power-1 bolt at the foot of a tower does it no damage")
	WorldBlast.shotHit(S3, 0, "arc", bt.x, WorldTerrain.groundY(S3, bt.x), 0.0, 0.0, -2000.0, "ground", 2.0)
	ok(bt.hp < hp0, "an arc at its foot does (%.0f of %.0f)" % [bt.hp, hp0])
	print("MARK: %d check(s) failed" % fails)
	quit()
