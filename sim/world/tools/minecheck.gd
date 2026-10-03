extends SceneTree
# Mines and the air burst through Simulation's shot modes and World's blast.
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
func ends(S: SimState) -> String:
	var s := ""
	for e in S.out.fx:
		if e.type == "shot_end":
			s += " " + str(e.cause)
	return s
func _init() -> void:
	print("== mines and the air burst ==")
	var X: float = 40000.0
	# a ground mine, set off by a blow
	var S := fresh()
	var nc: int = S.craters.size()
	var m = SimShots.fire(S, 0, "mine", {"x": X, "ground": true, "z": 0.0})
	ok(m != null, "a ground mine is laid")
	for t in range(40):
		SimShots.step(S, 1.0 / 60.0)
	ok(SimShots.trip(S, m, "blow", 0), "a blow sets it off once armed")
	for t in range(10):
		SimShots.step(S, 1.0 / 60.0)
	ok(m.dead and "mine" in ends(S), "it ends with cause mine (%s)" % ends(S))
	ok(S.craters.size() == nc + 1, "and leaves one crater (R%.0f depth %.0f)" % [S.craters[-1].r, S.craters[-1].depth] if S.craters.size() > nc else "and leaves one crater")
	# an air mine
	var S2 := fresh()
	var nc2: int = S2.craters.size()
	var m2 = SimShots.fire(S2, 0, "mine", {"x": X, "y": WorldTerrain.groundY(S2, X) + 300.0, "ground": false, "z": 0.0})
	for t in range(40):
		SimShots.step(S2, 1.0 / 60.0)
	SimShots.trip(S2, m2, "blow", 0)
	for t in range(10):
		SimShots.step(S2, 1.0 / 60.0)
	print("  an air mine 300 up: craters %d, R%s" % [S2.craters.size() - nc2, str(S2.craters[-1].r) if S2.craters.size() > nc2 else "none"])
	# a bolt that runs out of life in the air bursts there, a low one digs
	var S3 := fresh()
	var sh = SimShots.fire(S3, 0, "bolt", {"x": X, "y": WorldTerrain.groundY(S3, X) + 12000.0, "ux": 1.0, "uy": 0.0, "z": 0.0})
	var n3: int = S3.craters.size()
	for t in range(200):
		SimShots.step(S3, 1.0 / 60.0)
		if sh.dead:
			break
	ok(sh.dead and "life" in ends(S3), "a bolt that runs out of life ends (%s)" % ends(S3))
	ok(S3.craters.size() == n3, "high up it digs nothing")
	print("MINE: %d check(s) failed" % fails)
	quit()
