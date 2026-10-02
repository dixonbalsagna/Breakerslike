extends SceneTree
## VFX must not change the sim. For each seed it runs the match the sim alone (SimCore.step, no scene) and then the full
## game scene (render/main.tscn, which hosts host.vfx and a VfxLayer per pane; every view updated every
## frame) several ways, and compares the gameplay hash (SimHash.stateHash, which includes the sim RNG state) every 60
## ticks and at the end:
##   pure          the sim alone
##   vfx 60 Hz     the VFX scene, frames of exactly 1/60 s, quality high
##   vfx 144 Hz    the same at 1/144 s frames (several frames per tick, interpolated)
##   vfx jitter    irregular frame times from 2 to 50 ms, and again to repeat it
##   vfx low       quality low, reduced motion on: a different effect path, the same sim
##   vfx split     Camera's split screen attached (two panes, two layers)
## Any difference fails. It also fails if the effects never ran (a check that draws nothing proves nothing): trails must
## have reached full strength and spawned marks in at least one seed.
## --negative-control nudges a fighter's x by 0.001 once at frame 300 of every VFX run, as an effect that wrote the sim
## would; the check must then fail.
##
## Usage (from the repo root):
##   godot --headless --path . --script res://render/vfx/tools/hash_check.gd [-- --seeds=12345,4,7 --ticks=3600 --negative-control]

const EVERY := 60

var seeds: Array = [12345, 4, 7]
var max_ticks: int = 3600
var negative: bool = false
var main: Node
var stats: Dictionary = {"max_k": 0.0, "marks": 0, "ribbons": 0, "ticks": 0, "crack_builds": 0, "crack_ms": 0.0, "debris": 0, "forms": 0, "water": 0, "react": 0, "earth": 0, "rocks": 0}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
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
	main.host.vfx.auto_quality = false
	main.host.vfx.cracks_enabled = true
	main.host.vfx.destruction_enabled = true
	main.host.vfx.embers_enabled = true
	main.host.vfx.rocks_enabled = true   # the prototype too: it must not touch the sim either
	var ok := true
	var pures: Dictionary = {}
	for seed in seeds:
		var pure: Array = _pure(seed)
		pures[seed] = pure
		var n: int = pure.size() - 1
		var last: int = pure[n][0]
		var runs: Dictionary = {}
		main.host.vfx.quality = VfxLook.Q_HIGH
		runs["vfx 60 Hz"] = await _rendered(seed, last, func(_i): return 1.0 / 60.0)
		runs["vfx 144 Hz"] = await _rendered(seed, last, func(_i): return 1.0 / 144.0)
		runs["vfx jitter"] = await _rendered(seed, last, _jitter(seed))
		runs["vfx jitter again"] = await _rendered(seed, last, _jitter(seed))
		main.host.vfx.quality = VfxLook.Q_LOW
		runs["vfx low"] = await _rendered(seed, last, func(_i): return 1.0 / 60.0, true)
		main.host.vfx.quality = VfxLook.Q_HIGH
		print("seed %d: %d checkpoints to tick %d, final %s" % [seed, pure.size(), pure[n][0], pure[n][1]])
		for k in runs:
			var diff: String = _compare(pure, runs[k])
			ok = ok and diff == ""
			print("  %-18s %s" % [k, "same as the sim alone" if diff == "" else "DIFFERS: " + diff])
	# The split screen last, attached once and kept: two panes, two layers (detaching frees the pane it composites).
	main.split_view = SplitView.new()
	main.add_child(main.split_view)
	main.split_view.attach(main)
	for seed in seeds:
		var pure: Array = pures[seed]
		var diff: String = _compare(pure, await _rendered(seed, pure[pure.size() - 1][0], func(_i): return 1.0 / 60.0))
		ok = ok and diff == ""
		print("seed %d vfx split      %s" % [seed, "same as the sim alone" if diff == "" else "DIFFERS: " + diff])
	var ran: bool = stats["max_k"] >= 0.99 and stats["marks"] > 0 and stats["ribbons"] > 0 and stats["debris"] > 0 and stats["forms"] > 0 and stats["react"] > 0 and stats["earth"] > 0 and stats["rocks"] > 0
	print("effects ran: max trail strength %.2f, %d marks spawned, %d ribbon segments drawn in %d ticks%s" % [stats["max_k"], stats["marks"], stats["ribbons"], stats["ticks"], "" if ran else "   (NOT ENOUGH: the check proves nothing)"])
	print("crack sets built: %d meshes in %.1f ms; %d debris bits spawned from the sim's own building_fall events" % [stats["crack_builds"], stats["crack_ms"], stats["debris"]])
	print("water effects fired %d times, transformations started %d (real events from the sim), %d rubble, standing-crack and window effects, %d chunks, flames and contact effects, up to %d levitating rocks drawn at once" % [stats["water"], stats["forms"], stats["react"], stats["earth"], stats["rocks"]])
	ok = ok and ran
	print("\nhash check passed" if ok else "\nhash check FAILED")
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
		_ready_forms(S, t)
		_raise_tiers(S, t)
	if out.is_empty() or out[-1][0] != t:
		out.append([t, SimHash.stateHash(S).gameplay])
	SimCore.dispose(S)
	return out


## The VFX scene driving the same match with frame times from dt_of(frame index), up to the same last tick.
func _rendered(seed: int, last: int, dt_of: Callable, reduced: bool = false) -> Array:
	var out: Array = []
	main.start_match(seed, {"p1": true, "p2": true})
	main.host.vfx.force_reduced = reduced
	var host: SimHost = main.host
	var rec := func(n: int):
		if n <= last and (n % EVERY == 0 or n == last):
			out.append([n, SimHash.stateHash(host.S).gameplay])
	host.ticked.connect(rec)
	var forms_cb := func(n: int):
		_ready_forms(host.S, n)
		_raise_tiers(host.S, n)
	host.ticked.connect(forms_cb)
	var i: int = 0
	var t0: Array = [0, 0]
	while host.ticks < last:
		main.frame(dt_of.call(i))
		if negative and i == 300:
			host.S.fighters[0].x += 0.001
		for k in range(2):
			stats["max_k"] = maxf(stats["max_k"], main.host.vfx.trails[k].max_k)
		for pw in main.panes:
			stats["ribbons"] += pw.vfx_layer.trail_view.ribbons
			stats["rocks"] = maxi(stats["rocks"], pw.vfx_layer.rocks_view.count)
		i += 1
	for k in range(2):
		stats["marks"] += main.host.vfx.trails[k].spawned
	stats["ticks"] += host.ticks
	stats["crack_builds"] += main.host.vfx.crack_builds
	stats["debris"] += main.host.vfx.debris.spawned
	stats["forms"] += main.host.vfx.xform.started
	stats["earth"] += main.host.vfx.earth.deb_made + main.host.vfx.earth.flames_made + main.host.vfx.earth.contact_made
	stats["react"] += main.host.vfx.react.rubble_made + main.host.vfx.react.stand_sets + main.host.vfx.react.blow_buildings
	stats["water"] += main.host.vfx.water.skims + main.host.vfx.water.plunges + main.host.vfx.water.beam_hits
	stats["crack_ms"] += main.host.vfx.crack_build_usec / 1000.0
	host.ticked.disconnect(rec)
	host.ticked.disconnect(forms_cb)
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


## Forms ready at fixed ticks, in every run alike (after that tick's hash is taken), so real `transform` events, their
## Q10 pauses and the effects played through them are part of what the check compares.
const FORM_TICKS: Array = [300, 1500]


static func _ready_forms(S: SimState, n: int) -> void:
	if FORM_TICKS.has(n):
		for f in S.fighters:
			f.act.formReady = true


## Tiers and a worn core set at fixed ticks too, in every run alike (after that tick's hash), so the reactions to power
## (tier 3 and up, a battered core) are in the compared match: tier 3 at tick 900 for fighter 0 (the form readied at 1500 takes it to 4), and a
## battered core on fighter 1 from tick 1200.
const TIER_TICKS: Dictionary = {900: 3.0}


static func _raise_tiers(S: SimState, n: int) -> void:
	if TIER_TICKS.has(n):
		S.fighters[0].tier = TIER_TICKS[n]
	if n == 1200:
		S.fighters[1].stage[1] = 2
