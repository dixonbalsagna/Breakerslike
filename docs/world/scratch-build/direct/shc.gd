extends SceneTree
# shots per match: how they end, floors hit by shots, buildings fallen
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var ends := {}
	var fl := {}
	var falls: int = 0
	var matches: int = 0
	var lost: float = 0.0
	var cas: float = 0.0
	for sd in range(int(a[0]), int(a[1])):
		var S := SimCore.createSim()
		SimCore.newMatch(S, sd)
		SimGolden.applyArm("default", S.fighters)
		var steps: int = 0
		while S.game.ko == null and steps < 54000:
			SimCore.step(S, null)
			for e in S.out.fx:
				if e.type == "shot_end":
					var c: String = str(e.cause)
					ends[c] = ends.get(c, 0) + 1
				elif e.type == "floor_hit" and float(e.victim) < 0.0:
					fl[str(e.outcome)] = fl.get(str(e.outcome), 0) + 1
			S.out.fx.clear()
			S.out.feed.clear()
			steps += 1
		matches += 1
		lost += S.world.structuresLost
		cas += S.world.casualties
		SimCore.dispose(S)
	print("SHC matches %d  shot ends per match: %s  shot floor hits per match: %s  structures lost %.1f  casualties %.1f" % [matches, str(ends), str(fl), lost / matches, cas / matches])
	for k in ends:
		print("   ", k, " ", float(ends[k]) / matches)
	quit(0)
