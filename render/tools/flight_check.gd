extends SceneTree
## Flight check: evacuation as drawn (render/core/crowd_flight.gd) against World's evacuate events. Real AI matches
## run through the full scene, one tick per frame, and every frame the check tests:
## 1. standing: every building's figures at home are exactly the people it has (popAlive, less the shelterers still
##    running to it), so no one a blow took is left standing where it fell, and an emptied district has no one;
## 2. runs: no runner outlives its run, and each building's incoming count is the runners heading to it.
## At the end of each match:
## 3. runners: per building, the runners started equal the events' n, within ROUND_TOL (figures are whole people).
##   godot --headless --path . --script res://render/tools/flight_check.gd [-- --seeds=4,12345,7 --ticks=5400]

const ROUND_TOL := 2.0

var seeds: Array = [4, 12345, 7]
var max_ticks: int = 5400
var main: Node
var fails: Array = []
var frames: int = 0
var most_runners: int = 0
var worst_round: float = 0.0
var step_usec: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
	var vpn := SubViewport.new()
	vpn.size = Vector2i(1280, 720)
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var started: int = 0
	var events_n: float = 0.0
	var sheltered: int = 0
	for si in range(seeds.size()):
		var seed: int = seeds[si]
		main.start_match(seed, {"p1": true, "p2": true})
		var S: SimState = main.host.S
		while main.host.ticks < max_ticks and not (S.game.ko != null and S.game.koT > 3.0):
			main.frame(1.0 / 60.0)
			_check_frame(S, "seed %d tick %d" % [seed, main.host.ticks])
		_check_end(S, "seed %d" % seed)
		started += main.planet.flight.started
		events_n += main.planet.flight.events_n
		sheltered += main.planet.flight.sheltered
	step_usec.sort()
	var p99: int = step_usec[int(step_usec.size() * 0.99)] if step_usec.size() > 0 else 0
	print("Flight check  %d frames over seeds %s" % [frames, seeds])
	print("runners %d for events totalling %.1f people; worst building off by %.2f (limit %.1f); most at once %d" % [started, events_n, worst_round, ROUND_TOL, most_runners])
	print("flight step per frame: p99 %d us, max %d us (headless: no GPU upload)" % [p99, step_usec[-1] if step_usec.size() > 0 else 0])
	print("runners to shelter in another building: %d" % sheltered)
	if fails.is_empty():
		print("\nflight check passed")
	else:
		for f in fails.slice(0, 20):
			print("FAIL  " + f)
		print("\nflight check FAILED (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


func _check_frame(S: SimState, where: String) -> void:
	frames += 1
	var pv: PlanetView = main.planet
	for bi in range(S.buildings.size()):
		var b = S.buildings[bi]
		var n: int = pv._crowd_first[bi + 1] - pv._crowd_first[bi]
		var want: int = clampi(int(b.popAlive - float(pv.flight.incoming[bi])), 0, n)
		if pv._shown[bi] != want:
			fails.append("%s: building %d shows %d standing, %d people there" % [where, bi, pv._shown[bi], want])
	var heading := PackedInt32Array()
	heading.resize(S.buildings.size())
	for ci in pv.flight._runs:
		var r = pv.flight._runs[ci]
		if S.T - r.t0 > r.dur + 2.0 * SimConst.DT:
			fails.append("%s: runner %d is %.2f s into a %.2f s run" % [where, ci, S.T - r.t0, r.dur])
		if r.dest >= 0:
			heading[r.dest] += 1
	if heading != pv.flight.incoming:
		fails.append("%s: the buildings' incoming counts are not the runners heading to them" % where)
	most_runners = maxi(most_runners, pv.flight.count())
	var t0: int = Time.get_ticks_usec()
	pv.flight.step(S, pv._crowd)
	step_usec.append(Time.get_ticks_usec() - t0)


func _check_end(S: SimState, where: String) -> void:
	var fl: CrowdFlight = main.planet.flight
	for bi in range(S.buildings.size()):
		var off: float = absf(float(fl._ran[bi]) - fl._evac[bi])
		worst_round = maxf(worst_round, off)
		if off > ROUND_TOL:
			fails.append("%s: building %d ran %d for events of %.2f people" % [where, bi, fl._ran[bi], fl._evac[bi]])
