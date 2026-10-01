extends SceneTree
## Flight check: evacuation as drawn (render/core/crowd_flight.gd) against World's evacuate events. Real AI matches
## run through the full scene, one tick per frame, and every frame the check tests:
## 1. standing: no building shows more figures at home than the people it has (popAlive, up to its figures), so no one
##    a blow took is left standing where it fell and an emptied district has no one; and it shows fewer only while it
##    waits, for a shelterer still running to it or for its next figure's own run to end;
## 2. runs: no runner outlives its run, none also stands at home, and each building's incoming count is the runners
##    heading to it.
## At the end of each match:
## 3. runners: per building, the runners started are no more than the events' n and no fewer than the events' n or
##    the figures that left it, whichever is smaller, within ROUND_TOL (figures are whole people; a building that
##    sheltered others, World's RELOCATE, holds more people than figures).
##   godot --headless --path . --script res://render/tools/flight_check.gd [-- --seeds=4,12345,7 --ticks=5400]

const ROUND_TOL := 2.0

var seeds: Array = [4, 12345, 7]
var max_ticks: int = 5400
var main: Node
var fails: Array = []
var frames: int = 0
var most_runners: int = 0
var worst_round: float = 0.0
var owed_frames: int = 0
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
	print("runners to shelter in another building: %d; building-frames a shelter waited for them: %d" % [sheltered, owed_frames])
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
		var have: int = clampi(int(b.popAlive), 0, n)
		var shown: int = pv._shown[bi]
		if shown > have:
			fails.append("%s: building %d shows %d standing, %d people there" % [where, bi, shown, have])
		elif shown < have:
			owed_frames += 1
			# Short only while it waits: for a shelterer on the way, or for its next figure's own run to end.
			if pv.flight.incoming[bi] == 0 and not pv.flight.running(pv._crowd_first[bi] + shown):
				fails.append("%s: building %d shows %d standing, %d people there and no one on the way" % [where, bi, shown, have])
	var heading := PackedInt32Array()
	heading.resize(S.buildings.size())
	for ci in pv.flight._runs:
		var r = pv.flight._runs[ci]
		if S.T - r.t0 > r.dur + 2.0 * SimConst.DT:
			fails.append("%s: runner %d is %.2f s into a %.2f s run" % [where, ci, S.T - r.t0, r.dur])
		if r.dest >= 0:
			heading[r.dest] += 1
		var home: int = pv._crowd_first.bsearch(ci, false) - 1
		if ci - pv._crowd_first[home] < pv._shown[home]:
			fails.append("%s: figure %d of building %d runs and stands at home at once" % [where, ci, home])
	if heading != pv.flight.incoming:
		fails.append("%s: the buildings' incoming counts are not the runners heading to them" % where)
	most_runners = maxi(most_runners, pv.flight.count())
	var t0: int = Time.get_ticks_usec()
	pv.flight.step(S, pv._crowd)
	step_usec.append(Time.get_ticks_usec() - t0)


func _check_end(S: SimState, where: String) -> void:
	var fl: CrowdFlight = main.planet.flight
	for bi in range(S.buildings.size()):
		# A building that sheltered others holds more people than it has figures, so its events can report more fled
		# than figures ever left it: the runners are held to the smaller of the two.
		var over: float = float(fl._ran[bi]) - fl._evac[bi]
		var under: float = minf(fl._evac[bi], float(fl._lost[bi])) - float(fl._ran[bi])
		var off: float = maxf(over, under)
		worst_round = maxf(worst_round, off)
		if off > ROUND_TOL:
			var b = S.buildings[bi]
			fails.append("%s: building %d ran %d for events of %.2f people and %d figures gone (pop %d, popAlive %.2f)" % [where, bi, fl._ran[bi], fl._evac[bi], fl._lost[bi], int(b.pop), b.popAlive])
