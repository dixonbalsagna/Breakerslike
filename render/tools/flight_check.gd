extends SceneTree
## Flight check: evacuation as drawn (render/core/crowd_flight.gd) against the evacuate events. Until the sim sends
## them, the events come from the mock (render/tools/evac_mock.gd). Real AI matches run through the full scene, one
## tick per frame, and every frame the check tests:
## 1. standing: every building's figures at home are exactly the people it shows (popAlive, less the mock's own), so
##    no one a blow took is left standing where it fell, and an emptied district has no one standing;
## 2. runs: no runner outlives its run.
## At the end of each match:
## 3. runners: per building, the runners started equal the events' n, within ROUND_TOL (figures are whole people, the
##    events come in lots of half a person).
## Then, on the first seed, the sim's gameplay hash at the end is the same with the mock on as off: nothing here
## writes the sim.
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
	var mock := EvacMock.new()
	main.host.evac_mock = mock
	main.planet.crowd_extra = mock.extra
	var started: int = 0
	var events_n: float = 0.0
	var hash_on: String = ""
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
		if si == 0:
			hash_on = str(SimHash.stateHash(S).gameplay)
	# The same first match with the mock off: the sim must not notice it.
	main.host.evac_mock = null
	main.planet.crowd_extra = []
	main.start_match(seeds[0], {"p1": true, "p2": true})
	var S0: SimState = main.host.S
	while main.host.ticks < max_ticks and not (S0.game.ko != null and S0.game.koT > 3.0):
		main.frame(1.0 / 60.0)
	var hash_off: String = str(SimHash.stateHash(S0).gameplay)
	if hash_off != hash_on:
		fails.append("the sim's hash differs with the mock on (%s) and off (%s)" % [hash_on, hash_off])
	step_usec.sort()
	var p99: int = step_usec[int(step_usec.size() * 0.99)] if step_usec.size() > 0 else 0
	print("Flight check  %d frames over seeds %s" % [frames, seeds])
	print("runners %d for events totalling %.1f people; worst building off by %.2f (limit %.1f); most at once %d" % [started, events_n, worst_round, ROUND_TOL, most_runners])
	print("flight step per frame: p99 %d us, max %d us (headless: no GPU upload)" % [p99, step_usec[-1] if step_usec.size() > 0 else 0])
	print("sim hash with the mock on and off: %s, %s" % [hash_on, hash_off])
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
	var extra: Array = pv.crowd_extra
	for bi in range(S.buildings.size()):
		var b = S.buildings[bi]
		var n: int = pv._crowd_first[bi + 1] - pv._crowd_first[bi]
		var pa: float = b.popAlive - (float(extra[bi]) if bi < extra.size() else 0.0)
		var want: int = clampi(int(pa), 0, n)
		if pv._shown[bi] != want:
			fails.append("%s: building %d shows %d standing, %d people there" % [where, bi, pv._shown[bi], want])
	for ci in pv.flight._runs:
		var r = pv.flight._runs[ci]
		if S.T - r.t0 > r.dur + 2.0 * SimConst.DT:
			fails.append("%s: runner %d is %.2f s into a %.2f s run" % [where, ci, S.T - r.t0, r.dur])
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
