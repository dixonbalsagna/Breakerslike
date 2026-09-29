extends SceneTree
## Evacuation in motion, for the rendering docs: a blow on a populated building with the evacuation mock on
## (render/tools/evac_mock.gd), then FRAMES pictures STEP_S apart: every other one at half size side by side, and the
## full frames.
## The fighters are posed and no sim ticks run. The blow is World's own (WorldStructures.explode); time advances by
## hand (S.T), and the mock and the planet view see each tick as in the game, so the fled share runs from the blow's
## tick and the district empties behind it. Needs a window (not --headless).
##   godot --path . --script res://render/tools/flight_strip.gd -- --out=DIR [--x=orig_x] [--zoom=z]

const FRAMES := 6
const STEP_S := 0.5

var main: Node
var out: String = "."
var cx_orig: float = 4700.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--x="):
			cx_orig = float(a.substr(4))
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
	var mock := EvacMock.new()
	main.host.evac_mock = mock
	main.planet.crowd_extra = mock.extra
	main.start_match(1)
	var S: SimState = main.host.S
	# The populated building nearest the chosen spot, and the fighters either side of it.
	var c: float = cx_orig * SimConst.PS
	var bx: float = c
	var bd: float = INF
	for b in S.buildings:
		var d: float = absf(SimWrap.sdx(c, b.x))
		if b.alive and b.pop >= 4.0 and d < bd:
			bd = d
			bx = b.x
	for i in range(2):
		var f = S.fighters[i]
		f.x = SimWrap.wrap(bx + (-700.0 if i == 0 else 700.0))
		f.y = WorldTerrain.groundY(S, f.x) + 30.0
		f.face = 1.0 if i == 0 else -1.0
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	for k in range(300):
		main.host.follow(vp.x, vp.y)
	_tick(S, true, bx)
	var shots: Array = []
	for k in range(FRAMES):
		main.render_view(1.0)
		await RenderingServer.frame_post_draw
		main.render_view(1.0)
		await RenderingServer.frame_post_draw
		var img: Image = main.get_viewport().get_texture().get_image()
		img.save_png("%s/flight-%d.png" % [out, k])
		shots.append(img)
		print("frame %d: T %.2f, runners %d, events so far %.2f people" % [k, S.T, main.planet.flight.count(), main.planet.flight.events_n])
		for t in range(int(STEP_S / SimConst.DT)):
			_tick(S, false, bx)
	# Every other frame at half size, side by side.
	var w: int = 640
	var h: int = 360
	var picks: Array = range(0, FRAMES, 2)
	var strip := Image.create_empty(w * picks.size() + 6 * (picks.size() - 1), h, false, Image.FORMAT_RGBA8)
	strip.fill(Color.BLACK)
	for k in range(picks.size()):
		var im: Image = shots[picks[k]].duplicate()
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		strip.blit_rect(im, Rect2i(0, 0, w, h), Vector2i(k * (w + 6), 0))
	strip.save_png("%s/flight-strip.png" % out)
	quit()


## One tick as the host would run it, by hand: the blow on the first, then time passing. The events go to the mock,
## then the planet view (its flight), as SimHost's drain does.
func _tick(S: SimState, blow: bool, bx: float) -> void:
	if blow:
		WorldStructures.explode(S, bx - 60.0, WorldTerrain.groundY(S, bx) + 40.0, 420.0, S.fighters[1])
	S.dt = SimConst.DT
	S.T += SimConst.DT
	S.tick += 1
	var fx: Array = S.out.fx
	fx = fx + main.host.evac_mock.step(S, fx)
	main.host.fxv.consume(S, S.out.fx)
	main.planet.consume(fx)
	S.out.fx.clear()
	main.planet.update(S, main.view_cam_x)
