extends SceneTree
# WorldCrater.deepen, WorldContact.slideObstacle and WorldContact.bump: the checks (docs/world/ground-contact.md section 25)
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
	print("== deepen, slideObstacle, bump ==")
	var X: float = 89600.0 + 3000.0
	var S := fresh()
	var by = S.fighters[1]
	var rec = WorldCrater.dig(S, X, 6.0, by, "impact", 0.0, 1.0)
	var d0: float = rec.depth
	var c0: int = int(floor(X / SimConst.COL))
	var floor0: float = S.deform[c0]
	var rng0: int = S.rng.state_i32()
	var nd: float = WorldCrater.deepen(S, X, by, 1.2)
	ok(absf(nd - 1.2 * d0) < 0.01 and absf(rec.depth - 1.2 * d0) < 0.01, "deepen by 1.2 makes the crater 1.2 times as deep (%.1f to %.1f units)" % [d0, nd])
	ok(S.deform[c0] < floor0 - 0.15 * d0, "the ground at the centre is lower by about a fifth of the depth (%.1f to %.1f)" % [floor0, S.deform[c0]])
	ok(S.rng.state_i32() == rng0, "it draws nothing from the rng")
	ok(WorldCrater.deepen(S, X + 5000.0, by, 1.2) == 0.0, "no crater there: nothing, 0 returned")
	ok(WorldCrater.deepen(S, X, by, 1.0) == 0.0, "a factor of 1 or less does nothing")
	# a crater that the old dig could not deepen: dig of 1.44 times the energy of a bowl at the radius cap
	var S2 := fresh()
	var rc2 = WorldCrater.dig(S2, X, 400.0, S2.fighters[1], "impact")
	var oldd: float = rc2.depth
	var again = WorldCrater.dig(S2, X, 400.0 * 1.44, S2.fighters[1], "impact")
	var nd2: float = WorldCrater.deepen(S2, X, S2.fighters[1], 1.2)
	ok(nd2 > oldd * 1.19, "a bowl at the radius cap is deepened (%.0f to %.0f; a second dig made %s)" % [oldd, nd2, "nothing" if again == null else "%.0f" % again.depth])
	var nan: bool = false
	for v in S2.deform:
		if is_nan(v):
			nan = true
	ok(not nan, "no NaN in the ground")
	# the obstacle and the bump
	var S3 := fresh()
	var f = S3.fighters[0]
	var found = null
	var xs: float = 100000.0
	while xs < 125000.0 and found == null:
		for dir in [1.0, -1.0]:
			var r: Dictionary = WorldContact.slideObstacle(S3, xs, 0.0, dir, 262.0)
			if r.hit and found == null:
				found = [xs, dir, r]
		xs += 200.0
	ok(found != null and found[2].d > 0.0 and found[2].kind in ["wall", "rim", "heap"], "an obstacle is found on a mountain slope within 3.5 bh")
	var clear: Dictionary = WorldContact.slideObstacle(S3, X, 0.0, 1.0, 262.0)
	ok(not clear.hit and clear.d == 262.0, "open desert is clear")
	f.hp = 1000.0
	f.x = found[2].x
	f.y = WorldTerrain.groundY(S3, f.x)
	var dmg: float = WorldContact.bump(S3, f, S3.fighters[1], found[2].kind, 870.0)
	ok(dmg > 4.0 and dmg < 7.0 and f.hp < 1000.0, "a bump at 870 speed costs %.1f hp" % dmg)
	print("DEEPEN: %d check(s) failed" % fails)
	quit(1 if fails > 0 else 0)
