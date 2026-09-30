extends SceneTree
## Screenshots of VFX in a real AI-vs-AI match: it plays the match at 60 Hz (one tick a frame) and saves a picture
## whenever a fighter's trail is at full strength (trail mode), or at the given ticks (--at=T1,T2). One view, from the
## reference camera, through the VFX scene. Needs a window (not --headless).
##   godot --path . --script res://render/vfx/tools/vfx_shots.gd -- --out=DIR [--seed=4] [--max=6] [--min-k=0.85]
##       [--size=1280x720] [--frames=6000] [--at=600,1200] [--novfx] [--split] [--min-zoom=0.15]
## --split attaches Camera's split screen, as the game does; --min-zoom keeps only frames whose camera is this close.

var main: Node
var split: bool = false
var min_zoom: float = 0.0
var on_events: String = ""     # "impact": a picture --delay ticks after each new crater or slide record
var delay: int = 20
var cracks: bool = false
var out: String = "."
var seed: int = 4
var max_shots: int = 6
var min_k: float = 0.85
var max_frames: int = 6000
var at: Array = []
var novfx: bool = false


func _initialize() -> void:
	var size := Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--seed="):
			seed = int(a.substr(7))
		elif a.begins_with("--max="):
			max_shots = int(a.substr(6))
		elif a.begins_with("--min-k="):
			min_k = float(a.substr(8))
		elif a.begins_with("--frames="):
			max_frames = int(a.substr(9))
		elif a.begins_with("--at="):
			at = Array(a.substr(5).split(",")).map(func(s): return int(s))
		elif a.begins_with("--size="):
			var wh: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif a == "--novfx":
			novfx = true
		elif a == "--split":
			split = true
		elif a == "--cracks":
			cracks = true
		elif a.begins_with("--on="):
			on_events = a.substr(5)
		elif a.begins_with("--delay="):
			delay = int(a.substr(8))
		elif a.begins_with("--min-zoom="):
			min_zoom = float(a.substr(11))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vpn := SubViewport.new()
	vpn.size = size
	vpn.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	main.started = true
	if novfx:
		main.host.vfx.enabled = false
	main.host.vfx.auto_quality = false
	main.host.vfx.cracks_enabled = cracks
	if split:
		# What main does in a real run (not manual): Camera's compositor over the panes.
		main.split_view = SplitView.new()
		main.add_child(main.split_view)
		main._sync_split_options()
		main.split_view.attach(main)
	main.start_match(seed, {"p1": true, "p2": true})
	var shots: int = 0
	var last: int = -1000
	var seen_c: int = 0
	var seen_s: int = 0
	var due: int = -1
	for i in range(max_frames):
		main.frame(1.0 / 60.0)
		var t: int = main.host.ticks
		var hit: bool = false
		if on_events != "":
			var S: SimState = main.host.S
			if S.craters.size() > seen_c or S.slides.size() > seen_s:
				if due < 0 and S.game.ko == null:
					due = t + delay
			seen_c = S.craters.size()
			seen_s = S.slides.size()
			if due >= 0 and t >= due:
				hit = true
				due = -1
		elif at.is_empty():
			for k in range(2):
				if main.host.vfx.trails[k].k >= min_k and main.panes[0].cam_rig.zoom >= min_zoom:
					hit = true
		else:
			hit = t in at
		if hit and i - last >= 90:
			await RenderingServer.frame_post_draw
			main.render_view(1.0)
			await RenderingServer.frame_post_draw
			var path: String = "%s/vfx_%d_%02d.png" % [out, seed, shots]
			main.get_viewport().get_texture().get_image().save_png(path)
			var tr: Array = main.host.vfx.trails
			print("saved %s tick %d k %.2f/%.2f speed %.0f/%.0f bh/s ribbons %d marks %d" % [path, t, tr[0].k, tr[1].k, tr[0].speed_bh, tr[1].speed_bh, main.panes[0].vfx_layer.trail_view.ribbons, main.panes[0].vfx_layer.trail_view.mark_count])
			shots += 1
			last = i
			if shots >= max_shots:
				break
		if main.host.S.game.ko != null and main.host.S.game.koT > 3.0:
			break
		await process_frame
	print("shots: %d in %d frames" % [shots, main.host.ticks])
	quit()
