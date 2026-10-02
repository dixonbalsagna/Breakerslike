extends SceneTree
func _init() -> void:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 1, {}, {"intro": false})
	# 16 bolts flying over the city at roof height, so none ends early
	var cx: float = 38000.0
	var tot: int = 0
	var ticks: int = 0
	for rep in range(20):
		S.shots = []
		for i in range(16):
			SimShots.fire(S, 0, "bolt", {"x": cx + 200.0 * float(i), "y": 5000.0, "z": 0.0, "ux": 1.0, "uy": 0.0})
		for t in range(30):
			var us := Time.get_ticks_usec()
			SimShots.step(S, 1.0 / 60.0)
			tot += Time.get_ticks_usec() - us
			ticks += 1
	print("16 shots over a city: %.0f us a tick" % (float(tot) / float(ticks)))
	var tot2: int = 0
	for rep in range(20):
		S.shots = []
		for i in range(16):
			SimShots.fire(S, 0, "bolt", {"x": cx + 200.0 * float(i), "y": 100.0, "z": 0.0, "ux": 1.0, "uy": 0.0})
		for t in range(30):
			var us := Time.get_ticks_usec()
			SimShots.step(S, 1.0 / 60.0)
			tot2 += Time.get_ticks_usec() - us
	print("16 shots at street height (they hit what is in the way): %.0f us a tick (including the hits)" % (float(tot2) / float(ticks)))
	quit()
