extends SceneTree
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var n: int = 0
	var T: float = 0.0
	var st: float = 0.0
	var cas: float = 0.0
	for sd in range(int(a[0]), int(a[1])):
		WorldContact._embLast.clear()
		WorldContact._embPend.clear()
		var S := SimCore.createSim()
		SimCore.newMatch(S, sd)
		SimGolden.applyArm("default", S.fighters)
		var steps: int = 0
		while S.game.ko == null and steps < 54000:
			SimCore.step(S, null)
			S.out.fx.clear()
			S.out.feed.clear()
			steps += 1
		T += S.T
		st += S.world.structuresLost
		cas += S.world.casualties / maxf(S.world.pop0, 1.0)
		n += 1
		SimCore.dispose(S)
	var d: Array = WorldContact.STAT
	print("EMBRUN %d matches: embeds %.2f a match, held back by the 5 s rule %.2f a match, hops suppressed %.2f a match; length %.0f s, structures %.1f, civilians %.1f%%" % [n, float(d[0]) / n, float(d[1]) / n, float(d[2]) / n, T / n, st / n, 100.0 * cas / n])
	quit(0)
