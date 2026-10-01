extends SceneTree
# Journey distance two ways: from the launch to the end (Camera's measure: launched until not launched) and from the first ground
# contact to the end (World's earlier measure).
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var launch_x := {}
	var first_x := {}
	var d_launch: Array = []
	var d_contact: Array = []
	var d_air: Array = []
	var d_ticks: Array = []
	var launch_tick := {}
	for sd in range(int(a[0]), int(a[1])):
		var S := SimCore.createSim()
		SimCore.newMatch(S, sd)
		SimGolden.applyArm("default", S.fighters)
		var steps: int = 0
		while S.game.ko == null and steps < 54000:
			SimCore.step(S, null)
			for e in S.out.fx:
				var key: String = "%d_%d_%d" % [sd, int(e.actor), int(e.n)]
				if e.type == "launch":
					var f = S.fighters[int(e.actor)]
					launch_x["%d_%d_%d" % [sd, int(e.actor), int(e.n)]] = f.x
					launch_tick[key] = S.tick
				elif e.type in ["land", "bounce", "skim"]:
					if not first_x.has(key):
						first_x[key] = e.x
				elif e.type == "journey_end":
					if launch_x.has(key) and first_x.has(key):
						d_launch.append(absf(SimWrap.sdx(launch_x[key], e.x)))
						d_contact.append(absf(SimWrap.sdx(first_x[key], e.x)))
						d_air.append(absf(SimWrap.sdx(launch_x[key], first_x[key])))
						d_ticks.append(float(S.tick - launch_tick[key]) / 60.0)
			S.out.fx.clear()
			S.out.feed.clear()
			steps += 1
		SimCore.dispose(S)
	d_launch.sort()
	d_contact.sort()
	d_air.sort()
	d_ticks.sort()
	print("JD n %d | launch->end median %.0f mean %.0f p90 %.0f over4000 %.0f%% | first contact->end median %.0f mean %.0f p90 %.0f over4000 %.0f%% | launch->first contact median %.0f mean %.0f p90 %.0f | launch->end time median %.2f p90 %.2f" % [d_launch.size(), _p(d_launch, 0.5), _m(d_launch), _p(d_launch, 0.9), _s(d_launch, 4000.0), _p(d_contact, 0.5), _m(d_contact), _p(d_contact, 0.9), _s(d_contact, 4000.0), _p(d_air, 0.5), _m(d_air), _p(d_air, 0.9), _p(d_ticks, 0.5), _p(d_ticks, 0.9)])
	quit(0)


func _m(a: Array) -> float:
	var s: float = 0.0
	for v in a:
		s += float(v)
	return s / maxf(float(a.size()), 1.0)


func _p(a: Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	return float(a[mini(a.size() - 1, int(floor(float(a.size()) * p)))])


func _s(a: Array, thr: float) -> float:
	var n: int = 0
	for v in a:
		if float(v) > thr:
			n += 1
	return 100.0 * n / maxf(float(a.size()), 1.0)
