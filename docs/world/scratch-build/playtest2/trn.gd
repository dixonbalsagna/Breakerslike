extends SceneTree
# What a skid and a roll carve today: the slide records
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	print("TRN constants: WS %.2f, trench half width %.1f + %.1f sqrt(E), depth %.2f + %.4f v capped %.1f, berm %.2f of depth" % [SimConst.WS, WorldSlide.HW0, WorldSlide.HW_E, WorldSlide.D0, WorldSlide.D_V, WorldSlide.D_MAX, WorldSlide.BERM])
	var dep: Array = []
	var len_: Array = []
	var wid: Array = []
	var vol: float = 0.0
	var n: int = 0
	var paved: int = 0
	var ns: int = 0
	for sd in range(int(a[0]), int(a[1])):
		var S := SimCore.createSim()
		SimCore.newMatch(S, sd, {}, {"intro": false})
		SimGolden.applyArm("default", S.fighters)
		var steps: int = 0
		while S.game.ko == null and steps < 54000:
			SimCore.step(S, null)
			for e in S.out.fx:
				if e.type == "slide":
					ns += 1
					dep.append(float(e.depth))
					len_.append(absf(SimWrap.sdx(float(e.x), float(e.x1))))
					wid.append(float(e.w))
					vol += float(e.depth) * absf(SimWrap.sdx(float(e.x), float(e.x1))) * float(e.w) * 0.5
					if String(e.variant) == "paved":
						paved += 1
			S.out.fx.clear()
			S.out.feed.clear()
			steps += 1
		n += 1
		SimCore.dispose(S)
	dep.sort()
	len_.sort()
	wid.sort()
	var q = func(arr: Array, p: float) -> float:
		return float(arr[mini(arr.size() - 1, int(floor(arr.size() * p)))]) if not arr.is_empty() else 0.0
	print("TRN %d matches: %.1f slide records a match (%d%% paved); depth median %.1f p90 %.1f max %.1f units; length median %.0f p90 %.0f max %.0f units (%.1f bh median); width median %.0f; carved volume %.0f units^3 a match" % [n, float(ns) / n, 100 * paved / maxi(ns, 1), q.call(dep, 0.5), q.call(dep, 0.9), dep[dep.size() - 1], q.call(len_, 0.5), q.call(len_, 0.9), len_[len_.size() - 1], q.call(len_, 0.5) / 75.0, q.call(wid, 0.5), vol / n])
	quit(0)
