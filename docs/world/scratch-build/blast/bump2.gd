extends SceneTree
# how often does a slide of 3.5 to 8 body heights from where fighters stand meet an obstacle?
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var dists: Array = [3.5, 5.0, 6.5, 8.0]
	var hit := [0, 0, 0, 0]
	var kinds := {}
	var tot: int = 0
	var bybiome := {}
	for sd in range(int(a[0]), int(a[1])):
		var S := SimCore.createSim()
		SimCore.newMatch(S, sd)
		SimGolden.applyArm("default", S.fighters)
		var steps: int = 0
		while S.game.ko == null and steps < 54000:
			SimCore.step(S, null)
			if steps % 120 == 0:
				for f in S.fighters:
					if f.state == "free" and f.y - WorldTerrain.groundY(S, f.x) < 40.0:
						for dir in [-1.0, 1.0]:
							tot += 1
							var b: String = WorldBiomes.biomeAt(f.x)
							if not bybiome.has(b):
								bybiome[b] = [0, 0]
							bybiome[b][0] += 1
							for i in 4:
								var r: Dictionary = WorldContact.slideObstacle(S, f.x, f.z, dir, dists[i] * 75.0)
								if r.hit:
									hit[i] += 1
									if i == 0:
										kinds[r.kind] = kinds.get(r.kind, 0) + 1
										bybiome[b][1] += 1
			S.out.fx.clear()
			S.out.feed.clear()
			steps += 1
		SimCore.dispose(S)
	var s: String = "BUMP2 %d fighter-and-direction samples on the ground:" % tot
	for i in 4:
		s += " %.1f bh: %.1f%% meet an obstacle;" % [dists[i], 100.0 * hit[i] / maxi(tot, 1)]
	s += " (at 3.5 bh the obstacle is %s)" % str(kinds)
	var bs: String = " by biome at 3.5 bh:"
	for b in bybiome:
		bs += " %s %.0f%% of %d;" % [b, 100.0 * bybiome[b][1] / bybiome[b][0], bybiome[b][0]]
	print(s + bs)
	quit(0)
