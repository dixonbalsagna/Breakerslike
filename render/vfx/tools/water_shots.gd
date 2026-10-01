extends SceneTree
## Pictures of the water effects, before and after: a fighter is launched over the sea in the real sim (the sim itself skips
## and plunges him, and sends the splash and skim events), a beam is staged over the sea with its beamSplash events, and the
## frames after each event are saved. --nowater turns VFX water off for the "before" set. Needs a window.
##   godot --path . --script res://render/vfx/tools/water_shots.gd -- --out=DIR [--nowater] [--zoom=0.3] [--size=1280x720]
##       [--case=skim|plunge|beam|all] [--tier=1..4]

var main: Node
var out: String = "."
var zoom: float = 0.3
var size := Vector2i(1280, 720)
var nowater: bool = false
var which: String = "all"
var tier: float = 2.0
var _seen: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
		elif a.begins_with("--size="):
			var wh: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif a == "--nowater":
			nowater = true
		elif a.begins_with("--case="):
			which = a.substr(7)
		elif a.begins_with("--tier="):
			tier = float(a.substr(7))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vpn := SubViewport.new()
	vpn.size = size
	vpn.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _on_drained(events: Array, _lines: Array) -> void:
	for e in events:
		if e.type in ["splash", "skim"]:
			_seen.append(e)


func _sea_x(S: SimState) -> float:
	var x: float = 0.0
	while x < SimConst.W:
		var ok: bool = true
		for k in range(-5, 6):
			if WorldWater.surfaceAt(S, SimWrap.wrap(x + float(k) * 2000.0)) == WorldWater.DRY:
				ok = false
				break
		if ok:
			return x
		x += 2000.0
	return 0.0


func _run() -> void:
	await process_frame
	main.started = true
	var h = main.host.vfx
	h.auto_quality = false
	h.water_enabled = not nowater
	main.host.drained.connect(_on_drained)
	for c in ["skim", "plunge", "beam"]:
		if which != "all" and which != c:
			continue
		await call("_play_" + c)
	quit()


func _fresh() -> SimState:
	main.start_match(3, {"p1": true, "p2": true})
	var S: SimState = main.host.S
	for f in S.fighters:
		f.tier = tier
	return S


func _cam(f, vp: Vector2) -> void:
	main.host.cam.x = SimWrap.wrap(f.x + 600.0)
	main.host.cam.y = f.y - 250.0 + 0.2 * vp.y / zoom
	main.host.cam.z = zoom
	main.host._prev = main.host._capture()
	main.host._cur = main.host._prev


func _save(name: String) -> void:
	main.render_view(1.0)
	await RenderingServer.frame_post_draw
	main.render_view(1.0)
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s%s.png" % [out, name, "_before" if nowater else "_after"]
	main.get_viewport().get_texture().get_image().save_png(path)
	var hub = main.host.vfx
	print("saved %s (bits %d, spray %d, skims %d, plunges %d)" % [path, hub.debris.bits.size(), hub.debris._spray_alive, hub.water.skims, hub.water.plunges])


## Launch fighter 0 over the sea with (vx, vy) from height y0 and play the sim until `due` ticks after the first event of kind.
func _launch(S: SimState, kind: String, vx: float, vy: float, y0: float, name: String) -> void:
	var x0: float = _sea_x(S) + 4000.0
	var f = S.fighters[0]
	var o = S.fighters[1]
	f.x = SimWrap.wrap(x0)
	f.y = y0
	f.vx = vx
	f.vy = vy
	f.state = "launched"
	f.launchT = 1.0
	f.stateT = 0.0
	f.bounces = 0.0
	f.wet = false
	o.x = SimWrap.wrap(x0 + 6000.0)
	o.y = 600.0
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var due: Array = []
	var got: bool = false
	for i in range(240):
		_seen.clear()
		main.frame(1.0 / 60.0)
		_cam(f, vp)
		var t: int = main.host.ticks
		for e in _seen:
			if e.type == kind and not got and (kind != "splash" or int(e.n) >= 10):
				got = true
				for d in [3, 10, 24]:
					due.append([t + d, "%s_t%d" % [name, d]])
		for d in due.duplicate():
			if t >= d[0]:
				due.erase(d)
				await _save(d[1])
		if got and due.is_empty():
			break
		await process_frame


func _play_skim() -> void:
	var S: SimState = _fresh()
	await _launch(S, "skim", 6500.0, -420.0, 260.0, "skim")


func _play_plunge() -> void:
	var S: SimState = _fresh()
	await _launch(S, "splash", 1500.0, -3800.0, 1200.0, "plunge")


## A beam raking the sea: S.beams holds one beam, and a beamSplash event goes in every tick along 600 units of it.
func _play_beam() -> void:
	var S: SimState = _fresh()
	var x0: float = _sea_x(S) + 4000.0
	var b := SimState.Beam.new()
	b.A = S.fighters[0]
	b.ox = x0
	b.oy = 100.0
	b.ux = 1.0
	b.pw = tier + 1.0
	S.beams.append(b)
	S.fighters[0].x = SimWrap.wrap(x0 - 300.0)
	S.fighters[0].y = 150.0
	S.fighters[0].state = "free"
	S.fighters[1].x = SimWrap.wrap(x0 + 9000.0)
	S.fighters[1].y = 400.0
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	for t in range(50):
		var evs: Array = []
		for k in range(10):
			var e := SimState.FxEvent.new()
			e.type = "beamSplash"
			e.x = x0 + float(t) * 160.0 + float(k) * 16.0
			evs.append(e)
		var tk := SimState.FxEvent.new()
		tk.type = "tick"
		tk.dt = SimConst.DT
		tk.frozen = false
		evs.append(tk)
		S.T += SimConst.DT
		S.tick += 1
		main.host.vfx.consume(S, evs)
		if t in [10, 24, 46]:
			main.host.cam.x = SimWrap.wrap(x0 + float(t) * 160.0)
			main.host.cam.y = 230.0
			main.host.cam.z = zoom
			main.host._prev = main.host._capture()
			main.host._cur = main.host._prev
			await _save("beam_t%d" % t)
