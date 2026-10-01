extends SceneTree
## Facing and pass-through scan over seeded AI matches (A2, docs/animation/pose-pipeline.md section 9.3). Read only: it
## steps real matches and reports, from the sim's own state:
## 1. backwards facing: ticks where a fighter's sim `face` points away from its opponent while they are more than `--gap`
##    units apart, split by state and by whether an exchange is running (the sim's face is what the renderer mirrors by);
## 2. pass-through: ticks inside an exchange where the two fighters swap sides (the sign of the shortest-arc offset flips)
##    while closer than `--near` units, with the seed and tick, for Encounter and Combat;
## 3. facing runs: the longest stretch a fighter faced away from the opponent.
##    --anim reads the mannequin's visual facing (RenderAnim) instead of the sim's face.
##   godot --headless --path . --script res://render/anim/tools/face_scan.gd [-- --seeds=4,12345,7,99 --ticks=4200 --gap=60 --near=120]

const DT := 1.0 / 60.0

var seeds: Array = [4, 12345, 7, 99]
var max_ticks: int = 4200
var gap: float = 60.0
var near: float = 120.0
var anim: bool = false
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
		elif a == "--anim":
			anim = true
		elif a.begins_with("--gap="):
			gap = float(a.substr(6))
		elif a.begins_with("--near="):
			near = float(a.substr(7))
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
	RenderAnim.enabled = anim
	var total: Dictionary = {}
	var passes: Array = []
	for seed in seeds:
		main.start_match(seed, {"p1": true, "p2": true})
		var S: SimState = main.host.S
		var away_run: Array = [0, 0]
		var worst: Array = [0, 0]
		var last_side: float = 0.0
		var in_ex_prev: bool = false
		var ticks := 0
		while main.host.ticks < max_ticks and not (S.game.ko != null and S.game.koT > 3.0):
			main.frame(DT)
			ticks += 1
			var A = S.fighters[0]
			var B = S.fighters[1]
			var dx: float = SimWrap.sdx(A.x, B.x)
			var ex = S.dirS.ex
			var in_ex: bool = ex != null
			for i in range(2):
				var f = S.fighters[i]
				var toward: float = signf(dx) if i == 0 else -signf(dx)
				var fc: float = RenderAnim.fighter(S, f).vface if anim else f.face
				var away: bool = absf(dx) > gap and fc != toward and f.state != "launched"
				if away and (in_ex or f.state == "locked"):
					var key: String = "engaged, away from opponent (%s)" % f.state
					total[key] = int(total.get(key, 0)) + 1
					away_run[i] += 1
					worst[i] = maxi(int(worst[i]), int(away_run[i]))
				else:
					away_run[i] = 0
				if f.state == "free" and absf(f.vx) > 250.0 and fc != signf(f.vx) and not in_ex:
					total["running backwards (free, faster than 250 u/s)"] = int(total.get("running backwards (free, faster than 250 u/s)", 0)) + 1

			var side: float = signf(dx)
			if in_ex and in_ex_prev and last_side != 0.0 and side != 0.0 and side != last_side and absf(dx) < near:
				passes.append("seed %d tick %d: %s exchange (%s), sides swapped at %.0f u, A.face %.0f B.face %.0f" % [seed, main.host.ticks, ex.kind, ex.tag, absf(dx), A.face, B.face])
			if absf(dx) > 1.0:
				last_side = side
			in_ex_prev = in_ex
		print("seed %d: %d ticks, longest facing-away run %d and %d ticks" % [seed, ticks, worst[0], worst[1]])
	print("\nticks facing away from the opponent (more than %.0f u apart, not launched), and running backwards:" % gap)
	for k in total:
		print("  %-48s %d" % [k, total[k]])
	print("\nside swaps inside an exchange (closer than %.0f u): %d" % [near, passes.size()])
	for p in passes.slice(0, 30):
		print("  " + p)
	quit(0)
