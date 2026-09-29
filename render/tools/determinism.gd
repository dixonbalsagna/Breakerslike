extends SceneTree
## Determinism check for the greybox: the renderer must not change the sim. For each seed it runs the match four ways
## and compares the gameplay hash (SimHash.stateHash) every 60 ticks and at the end:
##   pure    the sim alone: SimCore.step and the fx consumer, no scene;
##   60 Hz   the full main scene (every view updated every frame), frames of exactly 1/60 s;
##   144 Hz  the same at 1/144 s frames (several frames per tick, interpolated);
##   jitter  the same with irregular frame times from 2 to 50 ms (0 to 3 ticks per frame), and again to repeat it.
## Any difference fails. AI vs AI, so no input; each run is a fresh match from the same seed.
##
## Usage (from the repo root):
##   godot --headless --path . --script res://render/tools/determinism.gd [-- --seeds=12345,4 --ticks=5400 --live]
## --live waits for a real frame after every simulated one (use it without --headless to render on the GPU too).
## --negative-control nudges a fighter's x by 0.001 once, at frame 300 of every rendered run, as a renderer write
## would; the check must then fail.

const EVERY := 60

var seeds: Array = [12345, 4]
var max_ticks: int = 5400
var live: bool = false
var negative: bool = false
var main: Node
var _log: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
		elif a == "--live":
			live = true
		elif a == "--negative-control":
			negative = true
	var vpn := SubViewport.new()
	vpn.size = Vector2i(1280, 720)
	vpn.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ok := true
	for seed in seeds:
		var pure: Array = _pure(seed)
		var n: int = pure.size() - 1
		var last: int = pure[n][0]
		var runs: Dictionary = {
			"60 Hz": await _rendered(seed, last, func(_i): return 1.0 / 60.0),
			"144 Hz": await _rendered(seed, last, func(_i): return 1.0 / 144.0),
			"jitter": await _rendered(seed, last, _jitter(seed)),
			"jitter again": await _rendered(seed, last, _jitter(seed)),
		}
		print("seed %d: %d checkpoints to tick %d, final %s" % [seed, pure.size(), pure[n][0], pure[n][1]])
		for k in runs:
			var diff: String = _compare(pure, runs[k])
			ok = ok and diff == ""
			print("  %-12s %s" % [k, "same as the sim alone" if diff == "" else "DIFFERS: " + diff])
	print("\ndeterminism passed" if ok else "\ndeterminism FAILED")
	quit(0 if ok else 1)


## The sim alone, as the parity tools run it: [[tick, hash], ...] every EVERY ticks, then the last tick.
func _pure(seed: int) -> Array:
	var S := SimCore.createSim()
	SimCore.newMatch(S, seed)
	var V := SimFxView.new(seed)
	var out: Array = []
	var t: int = 0
	while t < max_ticks and not (S.game.ko != null and S.game.koT > 3.0):
		SimCore.step(S)
		V.consume(S, S.out.fx)
		S.out.fx.clear()
		S.out.feed.clear()
		t += 1
		if t % EVERY == 0:
			out.append([t, SimHash.stateHash(S).gameplay])
	if out.is_empty() or out[-1][0] != t:
		out.append([t, SimHash.stateHash(S).gameplay])
	SimCore.dispose(S)
	return out


## The main scene driving the same match with frame times from dt_of(frame index), up to the same last tick (the
## final frame may run a tick or two past it; those are not recorded).
func _rendered(seed: int, last: int, dt_of: Callable) -> Array:
	var out: Array = []
	main.start_match(seed, {"p1": true, "p2": true})
	var host: SimHost = main.host
	var rec := func(n: int):
		if n <= last and (n % EVERY == 0 or n == last):
			out.append([n, SimHash.stateHash(host.S).gameplay])
	host.ticked.connect(rec)
	var i: int = 0
	while host.ticks < last:
		main.frame(dt_of.call(i))
		if negative and i == 300:
			host.S.fighters[0].x += 0.001
		i += 1
		if live:
			await process_frame
	host.ticked.disconnect(rec)
	return out


## Irregular frame times, 2 to 50 ms, from their own stream (repeatable).
func _jitter(seed: int) -> Callable:
	var r := SimRng.new(SimRng.deriveSeed(seed, "test.jitter"))
	return func(_i): return r.range_(0.002, 0.05)


static func _compare(a: Array, b: Array) -> String:
	if a.size() != b.size():
		return "%d checkpoints vs %d" % [a.size(), b.size()]
	for i in range(a.size()):
		if a[i][0] != b[i][0] or a[i][1] != b[i][1]:
			return "first at tick %d (%s vs %s)" % [a[i][0], a[i][1], b[i][1]]
	return ""
