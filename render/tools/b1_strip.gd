extends SceneTree
## World's B1 in motion, for the rendering docs: a city block in depth rows, then a blast (World's own
## WorldStructures.explode) that levels part of it, pictured before and at STEPS seconds after: the implode's ripple
## sinking each building straight down from its delay, VFX's dust skirts, and the rubble heaps it leaves, filling the
## footprints and the street to the fighter plane. The fighters are posed and no sim ticks run; time is stepped by
## hand and each tick's events go to the planet view and VFX as in the game. Needs a window (not --headless).
## The blast is on the standing building of depth row --row (default 1) nearest --x, with the fighters 900 units to
## either side of it.
##   godot --path . --script res://render/tools/b1_strip.gd -- --out=DIR [--x=orig_x] [--r=blast_radius] [--row=0..3]

const STEPS: Array = [0.0, 0.25, 0.5, 0.8, 1.4, 2.5]

var main: Node
var out: String = "."
var x_orig: float = 3100.0
var blast_r: float = 1600.0
var row: int = 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--x="):
			x_orig = float(a.substr(4))
		elif a.begins_with("--r="):
			blast_r = float(a.substr(4))
		elif a.begins_with("--row="):
			row = int(a.substr(6))
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
	var c: float = x_orig * SimConst.PS
	var bx: float = c
	var bd: float = INF
	for b in S.buildings:
		var d: float = absf(SimWrap.sdx(c, b.x))
		if b.alive and int(b.row) == row and d < bd:
			bd = d
			bx = b.x
	for i in range(2):
		var f = S.fighters[i]
		f.x = SimWrap.wrap(bx + (-900.0 if i == 0 else 900.0))
		f.y = WorldTerrain.groundY(S, f.x) + 30.0
		f.face = 1.0 if i == 0 else -1.0
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	for k in range(300):
		main.host.follow(vp.x, vp.y)
	var shots: Array = []
	shots.append(await _shot(S, "b1-before"))
	WorldStructures.explode(S, bx, WorldTerrain.groundY(S, bx) + 40.0, blast_r, S.fighters[1])
	var T0: float = S.T
	var fallen: int = 0
	for e in S.out.fx:
		if e.type == "building_fall":
			fallen += 1
	print("blast r %.0f at x %.0f: %d building_fall events" % [blast_r, bx, fallen])
	var k: int = 0
	for t in STEPS:
		while S.T - T0 < t - 1e-6:
			_tick(S)
		if k == 0:
			_tick(S)
		shots.append(await _shot(S, "b1-%d" % k))
		k += 1
	var w: int = 640
	var h: int = 360
	var cols: int = 4
	var rows: int = int(ceil(shots.size() / float(cols)))
	var strip := Image.create_empty(w * cols + 6 * (cols - 1), h * rows + 6 * (rows - 1), false, Image.FORMAT_RGBA8)
	strip.fill(Color.BLACK)
	for i in range(shots.size()):
		var im: Image = shots[i].duplicate()
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		strip.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % cols) * (w + 6), (i / cols) * (h + 6)))
	strip.save_png("%s/b1-strip.png" % out)
	print("frames: before, then %s s after the blast" % [STEPS])
	quit()


## One tick by hand: time and the tick's events to the planet view and VFX, as SimHost's drain does.
func _tick(S: SimState) -> void:
	S.dt = SimConst.DT
	S.T += SimConst.DT
	S.tick += 1
	main.planet.consume(S.out.fx, S.T)
	main.host.vfx.consume(S, S.out.fx)
	main.host.fxv.consume(S, S.out.fx)
	S.out.fx.clear()


func _shot(S: SimState, name: String) -> Image:
	main.render_view(1.0)
	await RenderingServer.frame_post_draw
	main.render_view(1.0)
	await RenderingServer.frame_post_draw
	var img: Image = main.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	return img
