extends SceneTree
## Cue check: Combat's cue events drawn as placeholder poses (render/core/fighter_view.gd, RenderLook.CUE_POSES), on
## the templates' dynamic profile (DirData.templatesProfile, the tools-only override). Real AI matches run through
## the full scene, one tick per frame:
## 1. every cue event with a pose starts that pose on the fighter it names (both for actor -1), and a cue with a
##    ring_other ring rings the other fighter;
## 2. no pose shows past its duration;
## 3. the gameplay hash is the same with the poses drawn and not (presentation only).
## It also prints the cues seen, with and without a pose.
##   godot --headless --path . --script res://render/tools/cue_check.gd [-- --seeds=4,12345 --ticks=5400 --profile=dynamic]

const DT := 1.0 / 60.0

var seeds: Array = [4, 12345]
var max_ticks: int = 5400
var profile: String = "dynamic"
var main: Node
var fails: Array = []
var checks: int = 0
var seen: Dictionary = {}          # kind -> events
var want: Array = [{}, {}]         # per fighter: kind -> poses the events ask for
var rings: Array = [0, 0]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
		elif a.begins_with("--profile="):
			profile = a.substr(10)
	DirData.templatesProfile = profile
	var vpn := SubViewport.new()
	vpn.size = Vector2i(1280, 720)
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)


func _on_drained(events: Array, _lines: Array) -> void:
	for e in events:
		if e.type != "cue":
			continue
		var kind: String = String(e.kind)
		seen[kind] = int(seen.get(kind, 0)) + 1
		var pose: Dictionary = RenderLook.CUE_POSES.get(kind, {})
		if pose.is_empty():
			continue
		var who: int = int(e.actor)
		for i in range(2):
			if who < 0 or i == who:
				want[i][kind] = int(want[i].get(kind, 0)) + 1
		if pose.has("ring_other") and who >= 0:
			rings[1 - who] += 1


func _run() -> void:
	await process_frame
	main.host.drained.connect(_on_drained)
	for seed in seeds:
		var hashes: Array = []
		for on in [true, false]:
			main.cues_on = on
			seen.clear()
			want = [{}, {}]
			rings = [0, 0]
			var ring_starts: Array = [0, 0]
			var last_ring: Array = [-1.0, -1.0]
			main.start_match(seed, {"p1": true, "p2": true})
			var S: SimState = main.host.S
			while main.host.ticks < max_ticks and not (S.game.ko != null and S.game.koT > 3.0):
				main.frame(DT)
				if not on:
					continue
				for i in range(2):
					var v: FighterView = main.fighter_views[i]
					if not v._cue.is_empty() and S.T - float(v._cue.t0) > float(v._cue.dur) + 2.0 * DT:
						fails.append("seed %d: fighter %d's %s pose is %.2f s into a %.2f s pose" % [seed, i, v._cue.kind, S.T - float(v._cue.t0), float(v._cue.dur)])
					if v._ring_t0 != last_ring[i]:
						last_ring[i] = v._ring_t0
						ring_starts[i] += 1
			hashes.append(str(SimHash.stateHash(S).gameplay))
			if on:
				for i in range(2):
					var got: Dictionary = main.fighter_views[i].cues_started
					for kind in want[i]:
						_expect(int(got.get(kind, 0)) == int(want[i][kind]), "seed %d: fighter %d started %d %s poses for %d events" % [seed, i, int(got.get(kind, 0)), kind, int(want[i][kind])])
					_expect(ring_starts[i] == rings[i], "seed %d: fighter %d was ringed %d times for %d circles" % [seed, i, ring_starts[i], rings[i]])
				var posed: Array = []
				var other: Array = []
				for kind in seen:
					(posed if RenderLook.CUE_POSES.has(kind) else other).append("%s %d" % [kind, seen[kind]])
				print("seed %d (%s profile, %d ticks): cues with a pose: %s" % [seed, profile, main.host.ticks, ", ".join(posed)])
				print("    cues left to their owners: %s" % ", ".join(other))
		_expect(hashes[0] == hashes[1], "seed %d: the gameplay hash differs with the poses on (%s) and off (%s)" % [seed, hashes[0], hashes[1]])
		print("seed %d: gameplay hash with poses %s, without %s" % [seed, hashes[0], hashes[1]])
	print("Cue check  %d checks" % checks)
	if fails.is_empty():
		print("\ncue check passed")
	else:
		for f in fails.slice(0, 20):
			print("FAIL  " + f)
		print("\ncue check FAILED (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
