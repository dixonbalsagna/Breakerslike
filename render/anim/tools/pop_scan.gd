extends SceneTree
## Pop scan (A2, docs/animation/pose-pipeline.md section 9.4): over seeded AI matches it finds the ticks where a bone
## turns more than --limit radians between two consecutive ticks of the solved pose, outside a blow's own snap (the
## authored snap is meant to be fast), and reports them by what was playing: the part before and after, and whether a
## reaction, a cue, an approach or a state change started. These are the joins that need inertialisation.
##   godot --headless --path . --script res://render/anim/tools/pop_scan.gd [-- --seeds=4,12345,7 --ticks=3000 --limit=0.6]

const DT := 1.0 / 60.0

var seeds: Array = [4, 12345, 7]
var max_ticks: int = 3000
var limit: float = 0.6
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
		elif a.begins_with("--limit="):
			limit = float(a.substr(8))
	DirData.templatesProfile = "dynamic"
	var vpn := SubViewport.new()
	vpn.size = Vector2i(1280, 720)
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	RenderAnim.enabled = true
	RenderAnim.debug_checks = true
	AnimPose.limits_on = not OS.get_cmdline_user_args().has("--nolimit")
	var kinds: Dictionary = {}
	var examples: Array = []
	var frames := 0
	var pops := 0
	var worst := 0.0
	for seed in seeds:
		main.start_match(seed, {"p1": true, "p2": true})
		var S: SimState = main.host.S
		var prev: Dictionary = {}
		var prev_part: Dictionary = {}
		var last_tick: int = -1
		while main.host.ticks < max_ticks and not (S.game.ko != null and S.game.koT > 3.0):
			main.frame(DT)
			if S.tick == last_tick:
				continue
			last_tick = S.tick
			for f in S.fighters:
				var af: AnimFighter = RenderAnim.fighter(S, f)
				if af.version == 0:
					continue
				var id: int = f.get_instance_id()
				frames += 1
				if prev.has(id):
					var pq: Array = prev[id]
					var big := 0.0
					var bone := 0
					for i in range(AnimRig.N):
						var a: float = af.q[i].angle_to(pq[i])
						if a > big:
							big = a
							bone = i
					var part_now: String = af._part
					var part_was: String = prev_part[id]
					if big > limit and not (part_now == part_was and part_now != ""):
						pops += 1
						worst = maxf(worst, big)
						var key: String = "%s -> %s [%s]" % [part_was if part_was != "" else "(base)", part_now if part_now != "" else "(base)", af.layers.strip_edges()]
						kinds[key] = int(kinds.get(key, 0)) + 1
						if true:
							examples.append([big, "seed %d tick %d fighter %d: %.2f rad on %s, %s, state %s" % [seed, S.tick, S.fighters.find(f), big, AnimRig.BONES[bone][0], key, f.state] + " ip %s t %.3f" % [af._ip_active, af._ip_t]])
				prev[id] = af.q.duplicate()
				prev_part[id] = af._part
		print("seed %d done" % seed)
	print("\nfighter-frames %d, joins with a bone turning more than %.2f rad in one tick: %d (worst %.2f rad)" % [frames, limit, pops, worst])
	var ks: Array = kinds.keys()
	ks.sort_custom(func(a, b): return kinds[a] > kinds[b])
	for k in ks.slice(0, 12):
		print("  %-40s %d" % [k, kinds[k]])
	examples.sort_custom(func(a, b): return a[0] > b[0])
	for e in examples.slice(0, 14):
		print("  " + e[1])
	quit(0)
