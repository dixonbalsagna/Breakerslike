extends SceneTree
## Window scan (the review pipeline, docs/animation/review-plan.md): finds the stretches of a seeded AI match worth a reel, by what
## happens in them. For each seed it lists the ticks where a fighter is launched, and for a window around each (--before ticks
## ahead, --after behind) the share of frames where the camera's view holds both fighters (their screen rectangles inside the
## pane and no farther apart than --span px), so a reel can be cut where the action stays framed. Headless.
##   godot --headless --path . --script res://render/anim/tools/window_scan.gd [-- --seeds=4,12345,7 --ticks=5400 --before=240 --after=960 --span=360 --state=launched]

const DT := 1.0 / 60.0

var seeds: Array = [4, 12345, 7]
var max_ticks: int = 5400
var before: int = 240
var after: int = 960
var span: float = 360.0
var state_name: String = "launched"
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
		elif a.begins_with("--before="):
			before = int(a.substr(9))
		elif a.begins_with("--after="):
			after = int(a.substr(8))
		elif a.begins_with("--span="):
			span = float(a.substr(7))
		elif a.begins_with("--state="):
			state_name = a.substr(8)
	DirData.templatesProfile = "dynamic"
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
	for seed in seeds:
		main.start_match(seed, {"p1": true, "p2": true})
		var S: SimState = main.host.S
		var framed: Array = []      # per tick: 1 when both fighters are in the pane and close enough
		var launches: Array = []    # ticks where a fighter enters the state
		var prev: Array = ["", ""]
		var last_tick: int = -1
		while main.host.ticks < max_ticks and not (S.game.ko != null and S.game.koT > 3.0):
			main.frame(DT)
			if S.tick == last_tick:
				continue
			last_tick = S.tick
			for i in range(2):
				var st: String = String(S.fighters[i].state)
				if st == state_name and prev[i] != state_name:
					launches.append([S.tick, i])
				prev[i] = st
			var pw = main.panes[0]
			var r0: Rect2 = pw._screen_rect(main.fighter_views[0])
			var r1: Rect2 = pw._screen_rect(main.fighter_views[1])
			var pane := Rect2(Vector2.ZERO, Vector2(1280, 720))
			var ok: bool = pane.encloses(r0) and pane.encloses(r1) and r0.get_center().distance_to(r1.get_center()) <= span
			framed.append(1 if ok else 0)
		print("seed %d: %d ticks, %d fighter-entries into '%s'" % [seed, framed.size(), launches.size(), state_name])
		var shown := 0
		var seen_at: int = -100000
		for l in launches:
			if int(l[0]) - seen_at < 240:
				continue
			seen_at = int(l[0])
			var a: int = maxi(0, int(l[0]) - before)
			var b: int = mini(framed.size() - 1, int(l[0]) + after)
			var n := 0
			for t in range(a, b + 1):
				n += int(framed[t]) if t < framed.size() else 0
			var window: int = maxi(1, b - a + 1)
			print("  tick %5d fighter %d: window %d..%d, both framed %3.0f%%" % [l[0], l[1], a, b, 100.0 * float(n) / float(window)])
			shown += 1
			if shown >= 12:
				break
	quit(0)
