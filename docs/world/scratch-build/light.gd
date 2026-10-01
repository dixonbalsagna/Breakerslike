extends SceneTree
# A light per-tick digest of a match (fighters, T, counts) that does not depend on the hashed field list.
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	for sd in range(int(a[0]), int(a[1])):
		var S := SimCore.createSim()
		SimCore.newMatch(S, sd)
		var h := SimHash.Hasher.new()
		var steps: int = 0
		while S.game.ko == null and steps < int(a[2]):
			SimCore.step(S, null)
			S.out.fx.clear()
			S.out.feed.clear()
			steps += 1
			for f in S.fighters:
				h.num(f.x); h.num(f.y); h.num(f.hp); h.num(f.ki); h.num(f.vx); h.num(f.vy)
			h.num(S.T); h.num(float(S.craters.size())); h.num(S.world.structuresLost); h.num(S.world.casualties)
		print("LIGHT seed %d steps %d %s" % [sd, steps, h.hex()])
		SimCore.dispose(S)
	quit(0)
