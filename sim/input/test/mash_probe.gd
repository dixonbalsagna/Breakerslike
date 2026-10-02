extends SceneTree
## Two humans mashing at once (the game-feel side of Orb's two-player test): through the real sim and the real queue
## (SimAct, depth 3, expiry 36 ticks), how fast a press becomes an exchange, whether the queue holds its limits, and
## whether either player's presses starve the other's. It prints the numbers and fails only on the hard rules (latency,
## queue depth and expiry); the fairness figure is reported with its verdict because the director is Encounter's.
## From the repo root:
##   godot --headless --path . --script res://sim/input/test/mash_probe.gd [-- --seeds=20 --ticks=3000]
## Exit 0 unless a hard rule fails.

var fails: int = 0
var checks: int = 0


func ok(c: bool, what: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL  ", what)


func _init() -> void:
	SimInputData.load_and_apply()
	var seeds: int = 20
	var ticks: int = 3000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.substr(8))
		elif a.begins_with("--ticks="):
			ticks = int(a.substr(8))
	_latency()
	_queue_limits()
	_fairness(seeds, ticks)
	_jitter_and_patient(seeds, ticks)
	print("mash_probe: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _intent(light: bool = false) -> SimIntent:
	var i := SimIntent.new()
	i.light = light
	return i


func _two_humans(seed_: int) -> SimState:
	var S: SimState = SimCore.createSim()
	SimCore.newMatch(S, seed_, {"p1": false, "p2": false}, {"v2": [true, true]})
	return S


## A press when the director is free is an exchange (close up) or an approach (from range) on the same tick, whoever presses.
func _latency() -> void:
	for slot in range(2):
		var S: SimState = _two_humans(11)
		for n in range(90):   # past the opening cooldown
			SimCore.step(S, [_intent(), _intent()])
		ok(S.dirS.ex == null, "latency: no exchange running before the press")
		var ins: Array = [_intent(), _intent()]
		ins[slot] = _intent(true)
		SimCore.step(S, ins)
		# From range the press starts an approach (DirBands.pending), not an exchange; close up it starts the exchange. Either
		# is the press taking effect on the same tick.
		var started: bool = (S.dirS.ex != null and S.dirS.ex.A == S.fighters[slot]) or DirBands.pending(S.fighters[slot])
		ok(started, "latency: slot %d's press starts its exchange or its approach on the same tick (0 ticks)" % slot)
		SimCore.dispose(S)


func _queue_limits() -> void:
	var S: SimState = _two_humans(12)
	# While an exchange runs, ten light presses in ten ticks: the queue holds three, the rest are ignored.
	for n in range(90):
		SimCore.step(S, [_intent(), _intent()])
	SimCore.step(S, [_intent(true), _intent()])   # starts an exchange
	var p2: SimIntent
	for n in range(10):
		p2 = _intent(true)
		SimCore.step(S, [_intent(), p2])
	ok(S.fighters[1].act.queue.size() <= SimAct.queueMax and S.fighters[1].act.queue.size() == 3, "queue: ten presses in ten ticks leave exactly %d queued" % SimAct.queueMax)
	# An unattended request expires after 36 ticks.
	for n in range(40):
		SimCore.step(S, [_intent(), _intent()])
	ok(S.fighters[1].act.queue.size() == 0 or S.dirS.ex == null, "queue: waiting requests expire after 36 ticks (queue %d)" % S.fighters[1].act.queue.size())
	SimCore.dispose(S)


## Both players press light every `gap` ticks for the whole match: who starts the exchanges.
func _fairness(seeds: int, ticks: int) -> void:
	for gap in [4, 7, 12]:
		var starts: Array = [0, 0]
		var firsts: Array = [0, 0]
		var worst: float = 1.0
		var longest: int = 0
		var run_hist: Dictionary = {}
		for sd in range(1, seeds + 1):
			var S: SimState = _two_humans(sd)
			var last_ex = null
			var mine: Array = [0, 0]
			var first_seen: bool = false
			var prev_k: int = -1
			var run: int = 0
			for n in range(ticks):
				var l0: bool = (n + sd) % gap == 0
				var l1: bool = (n + sd * 3 + 1) % gap == 0
				SimCore.step(S, [_intent(l0), _intent(l1)])
				var ex = S.dirS.ex
				if ex != null and ex != last_ex:
					var k: int = S.fighters.find(ex.A)
					mine[k] += 1
					if k == prev_k:
						run += 1
					else:
						run = 1
					prev_k = k
					longest = maxi(longest, run)
					run_hist[run] = int(run_hist.get(run, 0)) + 1
					if not first_seen:
						firsts[k] += 1
						first_seen = true
				last_ex = ex
				if S.game.ko != null and S.game.koT > 3.0:
					break
			starts[0] += mine[0]
			starts[1] += mine[1]
			var tot: int = mine[0] + mine[1]
			if tot >= 4:
				worst = minf(worst, float(minf(mine[0], mine[1])) / float(tot))
			SimCore.dispose(S)
		var total: int = starts[0] + starts[1]
		var share: float = float(starts[0]) / float(maxi(total, 1))
		var verdict: String = "fair" if absf(share - 0.5) <= 0.15 else "UNFAIR"
		print("fairness: both mash light every %2d ticks: P1 starts %d, P2 starts %d (P1 share %.2f), first exchange P1 %d / P2 %d, smallest per-match minority share %.2f, longest run by one player %d: %s" % [gap, starts[0], starts[1], share, firsts[0], firsts[1], worst, longest, verdict])
		var keys: Array = run_hist.keys()
		keys.sort()
		var line: String = "    run lengths of consecutive starts by one player:"
		for kk in keys:
			line += " %dx%d" % [kk, run_hist[kk]]
		print(line)


## Real mashing is not periodic: both players with jittered gaps, then a masher against a patient player who presses once
## in a while (the beginner against the expert the design promises can beat the beginner).
func _jitter_and_patient(seeds: int, ticks: int) -> void:
	var scen: Array = [["both jittered around 6 ticks", 6, 6], ["both jittered around 12 ticks", 12, 12], ["P1 mashes (4), P2 presses about every 40 ticks", 4, 40], ["P1 mashes (4), P2 presses about every 20 ticks", 4, 20]]
	for sc in scen:
		var starts: Array = [0, 0]
		var presses: Array = [0, 0]
		for sd in range(1, seeds + 1):
			var S: SimState = _two_humans(100 + sd)
			var r := SimRng.new(sd * 7919)
			var next: Array = [5, 9]
			var last_ex = null
			for n in range(ticks):
				var l: Array = [false, false]
				for k in range(2):
					if n >= next[k]:
						l[k] = true
						presses[k] += 1
						var g: float = float(sc[1 + k])
						next[k] = n + int(maxf(2.0, g * (0.7 + 0.6 * r.next())))
				SimCore.step(S, [_intent(l[0]), _intent(l[1])])
				var ex = S.dirS.ex
				if ex != null and ex != last_ex:
					starts[S.fighters.find(ex.A)] += 1
				last_ex = ex
				if S.game.ko != null and S.game.koT > 3.0:
					break
			SimCore.dispose(S)
		var total: int = starts[0] + starts[1]
		print("fairness: %s: P1 starts %d, P2 starts %d (P2 share %.2f); presses %d / %d" % [sc[0], starts[0], starts[1], float(starts[1]) / float(maxi(total, 1)), presses[0], presses[1]])
