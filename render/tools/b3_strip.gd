extends SceneTree
## B3 in motion, for the rendering docs: a brunt launch from a real AI match, drawn through the full scene. The match
## runs to --tick (a launch_depth tick from the scan in docs/rendering/README.md), then every --every ticks a frame is
## saved for --count frames: the launched fighter goes into the building rows at the sim's depth, shrinking under
## the perspective, with his shadow under him and the buildings in front of him fading; a punch cuts its floors out of
## the tower. Saves frames (b3-NN.png), a strip (b3-strip.png) and raw RGB frames (b3.rgb) for
## render/anim/tools/gif.mjs. Needs a window (not --headless).
##   godot --path . --script res://render/tools/b3_strip.gd -- --out=DIR [--seed=4 --tick=6864 --count=40 --every=3]
##        [--size=960x540] [--ref]
## The frames follow the launched fighter with the tool's own stand-in camera (leading toward the aimed building,
## closing in as he goes deep: roughly what Camera's depth-and-chains.md asks of the rig, which does not read the depth
## yet); --ref draws the game's reference camera instead.

var main: Node
var out: String = "."
var seed: int = 4
var tick: int = 6864
var frames: int = 40
var every: int = 3
var size := Vector2i(960, 540)
var ref_cam: bool = false
var _cx: float = 0.0
var _cy: float = 0.0
var _cz: float = 0.6
var _have: bool = false
var _who: int = 0


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("b3_strip: needs a window (it renders frames); not run under --headless")
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
	var h: SimHost = main.host
	while h.ticks < tick - 6:
		main.frame(1.0 / 60.0)
	var shots: Array = []
	var rgb := PackedByteArray()
	var zmin: float = 0.0
	for k in range(frames):
		for j in range(every):
			main.frame(1.0 / 60.0)
		for f in h.S.fighters:
			zmin = minf(zmin, f.z)
		_view(h, float(every) / 60.0)
		await RenderingServer.frame_post_draw
		_view(h, 0.0)
		await RenderingServer.frame_post_draw
		var img: Image = main.get_viewport().get_texture().get_image()
		img.save_png("%s/b3-%02d.png" % [out, k])
		shots.append(img)
		var c: Image = img.duplicate()
		c.convert(Image.FORMAT_RGB8)
		rgb.append_array(c.get_data())
	var head := PackedByteArray()
	head.resize(12)
	head.encode_s32(0, size.x)
	head.encode_s32(4, size.y)
	head.encode_s32(8, frames)
	var fa := FileAccess.open("%s/b3.rgb" % out, FileAccess.WRITE)
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
	strip.save_png("%s/b3-strip.png" % out)
	print("seed %d from tick %d: %d frames every %d ticks; the deepest a fighter went: z %.0f" % [seed, tick - 6, frames, every, zmin])
	quit()


## Draw the frame: the reference camera, or the stand-in that follows the fighter in depth (the one aimed at a building,
## or deepest in the rows; else the one last followed).
func _view(h: SimHost, dt: float) -> void:
	if ref_cam:
		main.render_view(1.0)
		return
	var S: SimState = h.S
	var who: int = -1
	for i in range(S.fighters.size()):
		var g = S.fighters[i]
		if g.aimB >= 0 or absf(g.z) > 1.0:
			who = i
	if who < 0:
		who = _who
	_who = who
	var f = S.fighters[who]
	var tx: float = f.x
	if f.aimB >= 0:
		tx = SimWrap.wrap(f.x + 0.35 * SimWrap.sdx(f.x, S.buildings[f.aimB].x))
	var z_want: float = lerpf(0.7, 0.85, clampf(absf(f.z) / 2600.0, 0.0, 1.0))
	if not _have:
		_cx = tx
		_cy = f.y
		_cz = z_want
		_have = true
	var k: float = 1.0 - exp(-dt * 6.0)
	_cx = SimWrap.wrap(_cx + SimWrap.sdx(_cx, tx) * k)
	_cy = lerpf(_cy, f.y + 40.0, k)
	_cz = lerpf(_cz, z_want, 1.0 - exp(-dt * 2.4))
	# A deep fighter draws s of the way from the camera's axis to where he would be on the plane (Camera's mapping), so
	# the camera stays close to his x and y and he stays in frame.
	var d: float = float(size.y) / (0.536 * _cz)
	var s: float = d / (d - f.z)
	var cam_x: float = SimWrap.wrap(f.x + SimWrap.sdx(f.x, _cx) * s)
	var cam_y: float = maxf(f.y + (_cy - f.y) * s, 60.0)
	main.pane.render(h, 1.0, cam_x, Vector3(0.0, cam_y, _cz), Vector2.ZERO)
