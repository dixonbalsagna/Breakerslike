extends SceneTree
## A brunt launch from a real AI match through the full scene with Camera's split rig and compositor, for the camera docs
## (docs/camera/depth-and-chains.md): the match runs to --tick (a launch_depth tick, see docs/rendering/README.md "The
## fighter in depth"), then every --every ticks a frame is saved for --count frames. --ref draws the game's reference
## camera instead (no compositor), the "before". Saves frames (cam-NN.png), a strip (cam-strip.png) and raw RGB frames
## (cam.rgb) for render/anim/tools/gif.mjs, and prints the launched fighter's apparent height and how far from the screen
## edge he got. Needs a window (not --headless).
##   godot --path . --script res://render/camera/tests/depth_strip.gd -- --out=DIR [--seed=24 --tick=7178 --count=56
##        --every=3 --size=960x540] [--ref]

var main: Node
var view: SplitView
var out: String = "."
var seed: int = 24
var tick: int = 7178
var frames: int = 56
var every: int = 3
var size := Vector2i(960, 540)
var ref_cam: bool = false


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("depth_strip: needs a window (it renders frames); not run under --headless")
		quit(2)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--seed="):
			seed = int(a.substr(7))
		elif a.begins_with("--tick="):
			tick = int(a.substr(7))
		elif a.begins_with("--count="):
			frames = int(a.substr(8))
		elif a.begins_with("--every="):
			every = int(a.substr(8))
		elif a == "--ref":
			ref_cam = true
		elif a.begins_with("--size="):
			var wh: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
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
	main.start_match(seed, {"p1": true, "p2": true})
	if not ref_cam:
		view = SplitView.new()
		main.add_child(view)
		view.size = Vector2(size)
		view.attach(main)
		await process_frame
	var h: SimHost = main.host
	while h.ticks < tick - 6:
		main.frame(1.0 / 60.0)
	var shots: Array = []
	var rgb := PackedByteArray()
	var min_px: float = 1e9
	var worst_off: float = 0.0
	var zmin: float = 0.0
	for k in range(frames):
		for j in range(every):
			main.frame(1.0 / 60.0)
		await RenderingServer.frame_post_draw
		var img: Image = main.get_viewport().get_texture().get_image()
		img.save_png("%s/cam-%02d.png" % [out, k])
		shots.append(img)
		var c: Image = img.duplicate()
		c.convert(Image.FORMAT_RGB8)
		rgb.append_array(c.get_data())
		# the deepest fighter's size and distance outside the screen, from the rig's frame (or the reference camera)
		for i in range(h.S.fighters.size()):
			var f = h.S.fighters[i]
			if absf(f.z) > 300.0 and (f.state == "launched" or f.aimB >= 0):   # the launched fighter; the other is out of a solo shot by design
				zmin = minf(zmin, f.z)
				if main.split_frame != null:
					var fr: SplitFrame = main.split_frame
					var pi: int = i if fr.shows(i) else 0
					var a: float = h.alpha()
					var p: Vector2 = fr.screen_pos(pi, h.fighter_x(i, a), h.fighter_pose(i, a).y + CamParams.CHEST, h.fighter_z(i, a))
					min_px = minf(min_px, CamParams.BODY_H * fr.cam_z[pi] * fr.depth_scale(pi, h.fighter_z(i, a)))
					var off_now: float = maxf(maxf(-p.x, p.x - size.x), maxf(-p.y, p.y - size.y))
					if off_now > 50.0:
						print("  frame %d fighter %d off by %.0f px: mode %s sep %.2f e %.2f pane %d pos %s z %.0f cam %.0f/%.0f/%.3f" % [k, i, off_now, fr.mode, fr.sep, fr.e, pi, p, h.fighter_z(i, a), fr.cam_x[pi], fr.cam_y[pi], fr.cam_z[pi]])
					worst_off = maxf(worst_off, off_now)
				else:
					# the reference camera: the same mapping with its camera
					var a2: float = h.alpha()
					var cam: Vector3 = h.camera(a2)
					var cx: float = h.camera_x(a2)
					var fz: float = h.fighter_z(i, a2)
					var d: float = CamParams.K_FACTOR * size.y / cam.z
					var s: float = maxf(d / maxf(d - fz, 1.0), CamParams.DEPTH_S_MIN)
					var c0 := Vector2(size.x * 0.5, size.y * 0.5)
					var pp := Vector2(SimWrap.sdx(cx, h.fighter_x(i, a2)) * cam.z + size.x * 0.5, size.y * CamParams.PLANE_Y - (h.fighter_pose(i, a2).y + CamParams.CHEST - cam.y) * cam.z)
					var q: Vector2 = c0 + (pp - c0) * s
					min_px = minf(min_px, CamParams.BODY_H * cam.z * s)
					worst_off = maxf(worst_off, maxf(maxf(-q.x, q.x - size.x), maxf(-q.y, q.y - size.y)))
	var head := PackedByteArray()
	head.resize(12)
	head.encode_s32(0, size.x)
	head.encode_s32(4, size.y)
	head.encode_s32(8, frames)
	var fa := FileAccess.open("%s/cam.rgb" % out, FileAccess.WRITE)
	fa.store_buffer(head)
	fa.store_buffer(rgb)
	fa.close()
	var cols: int = 5
	var pick: Array = []
	for i in range(10):
		pick.append(shots[mini(shots.size() - 1, i * shots.size() / 10)])
	var w: int = size.x / 2
	var hh: int = size.y / 2
	var strip := Image.create_empty(w * cols + 4 * (cols - 1), hh * 2 + 4, false, Image.FORMAT_RGBA8)
	strip.fill(Color.BLACK)
	for i in range(pick.size()):
		var im: Image = pick[i].duplicate()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, hh, Image.INTERPOLATE_BILINEAR)
		strip.blit_rect(im, Rect2i(0, 0, w, hh), Vector2i((i % cols) * (w + 4), (i / cols) * (hh + 4)))
	strip.save_png("%s/cam-strip.png" % out)
	print("%s: seed %d from tick %d, %d frames every %d ticks; deepest z %.0f; smallest apparent height %.1f px (at %dx%d); worst distance outside the screen %.0f px" % ["reference camera" if ref_cam else "split rig", seed, tick - 6, frames, every, zmin, min_px, size.x, size.y, worst_off])
	quit()
