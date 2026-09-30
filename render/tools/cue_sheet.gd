extends SceneTree
## Combat's cue poses on a contact sheet, for the rendering docs: every pose in RenderLook.CUE_POSES at its peak on P1,
## facing P2, in the real scene (circle also rings P2). The fighters are posed, no sim ticks run, and time is stepped
## by hand, so each pose blends in as in play. Needs a window (not --headless).
##   godot --path . --script res://render/tools/cue_sheet.gd -- --out=DIR

const COLS := 5
const W := 400
const H := 260

var main: Node
var out: String = "."


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
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
	main.started = true
	main.start_match(1)
	var S: SimState = main.host.S
	var c: float = 5900.0 * SimConst.PS
	for i in range(2):
		var f = S.fighters[i]
		f.x = SimWrap.wrap(c + (-110.0 if i == 0 else 110.0))
		f.y = WorldTerrain.groundY(S, f.x) + 40.0
		f.face = 1.0 if i == 0 else -1.0
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	for k in range(300):
		main.host.follow(vp.x, vp.y)
	var kinds: Array = RenderLook.CUE_POSES.keys()
	var rows: int = int(ceil(kinds.size() / float(COLS)))
	var sheet := Image.create_empty(W * COLS, H * rows, false, Image.FORMAT_RGBA8)
	var T: float = 10.0
	for n in range(kinds.size()):
		var kind: String = kinds[n]
		var pose: Dictionary = RenderLook.CUE_POSES[kind]
		T += 10.0
		S.T = T
		for v in main.fighter_views:
			v._cue = {}
			v._ring_t0 = -1.0
		main.fighter_views[0].cue(kind, T)
		if pose.has("ring_other"):
			main.fighter_views[1].ring(T, float(pose.ring_other))
		for t in [0.0, 0.05, 0.1, minf(0.2, float(pose.dur) * 0.4)]:
			S.T = T + t
			main.render_view(1.0)
		await RenderingServer.frame_post_draw
		main.render_view(1.0)
		await RenderingServer.frame_post_draw
		var img: Image = main.get_viewport().get_texture().get_image()
		var a: Vector2 = main.cam_rig.unproject_position(main.fighter_views[0].global_position)
		var b: Vector2 = main.cam_rig.unproject_position(main.fighter_views[1].global_position)
		var mid: Vector2 = (a + b) * 0.5
		var rect := Rect2i(int(mid.x) - W / 2, int(mid.y) - H * 3 / 4, W, H)
		sheet.blit_rect(img, rect, Vector2i((n % COLS) * W, (n / COLS) * H))
	sheet.save_png("%s/cue-sheet.png" % out)
	print("cells, left to right, top to bottom: ", " ".join(kinds))
	quit()
