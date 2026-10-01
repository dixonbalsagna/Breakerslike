extends SceneTree
## Pictures of the earth, material and fire effects (docs/vfx/earth-plan.md), before and after. --off turns them off for the
## "before" set, which leaves the reference consumer's placeholder squares and discs (hub.earth_enabled false makes
## reference_events pass everything through). Needs a window.
##   godot --path . --script res://render/vfx/tools/earth_shots.gd -- --out=DIR --case=deb|flame|slam|skid|bounce|bench [--off]
##       [--ticks=6,20,45] [--x=2250] [--zoom=0.9] [--size=1280x720] [--tier=2]
## deb: debris events of five materials in a row (ground, paving, tower steel, a house's wood, foliage).
## flame: fire events along a row, as a burning building's would be.
## slam, skid, bounce: a launched fighter meets the ground in the real sim (ground contact switched on, data/biomes/contact.json
## "enabled": true, in a scratch copy) and the frames after the first matching event are saved.

var main: Node
var out: String = "."
var zoom: float = 0.9
var size := Vector2i(1280, 720)
var off: bool = false
var which: String = "deb"
var wx: float = 2250.0
var ticks: Array = [6, 20, 45]
var tier: float = 2.0
var _seen: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--off":
			off = true
		elif a.begins_with("--case="):
			which = a.substr(7)
		elif a.begins_with("--x="):
			wx = float(a.substr(4))
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
		elif a.begins_with("--tier="):
			tier = float(a.substr(7))
		elif a.begins_with("--size="):
			var wh: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--ticks="):
			ticks = []
			for s in a.substr(8).split(","):
				ticks.append(int(s))
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
		if e.type in ["land", "bounce", "left_ground", "tumble_end", "journey_end"]:
			_seen.append(e)


func _tick(S: SimState, evs: Array) -> void:
	S.T += SimConst.DT
	S.tick += 1
	var tk := SimState.FxEvent.new()
	tk.type = "tick"
	tk.dt = SimConst.DT
	tk.frozen = false
	var all: Array = evs.duplicate()
	all.append(tk)
	var h = main.host.vfx
	main.host.impact.consume(S, all)
	main.host.fxv.consume(S, h.reference_events(all))
	h.consume(S, all)
	main.host.ticks += 1
	main.host._prev = main.host._cur
	main.host._cur = main.host._capture()


func _shot(name: String, cam_x: float, cam_y: float) -> void:
	main.host.cam.x = SimWrap.wrap(cam_x)
	main.host.cam.y = cam_y
	main.host.cam.z = zoom
	main.host._prev = main.host._capture()
	main.host._cur = main.host._prev
	main.render_view(1.0)
	await RenderingServer.frame_post_draw
	main.render_view(1.0)
	await RenderingServer.frame_post_draw
	var path: String = "%s/earth_%s_%s.png" % [out, name, "before" if off else "after"]
	main.get_viewport().get_texture().get_image().save_png(path)
	var h = main.host.vfx
	print("saved %s (bits %d, flames %d, deb %d, flames made %d, contact %d)" % [path, h.debris.bits.size(), h.debris._flame_alive, h.earth.deb_made, h.earth.flames_made, h.earth.contact_made])


func _ev(type: String, d: Dictionary) -> SimState.FxEvent:
	var e := SimState.FxEvent.new()
	e.type = type
	for k in d.keys():
		e.set(k, d[k])
	return e


func _run() -> void:
	await process_frame
	main.started = true
	var h = main.host.vfx
	h.auto_quality = false
	h.earth_enabled = not off
	main.start_match(3, {"p1": true, "p2": true})
	var S: SimState = main.host.S
	main.host.drained.connect(_on_drained)
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var x0: float = SimWrap.wrap(wx * SimConst.PS)
	var g0: float = WorldTerrain.groundY(S, x0)
	for f in S.fighters:
		f.tier = tier
	if which == "bench":
		# Everything at once: a fire burst every tick, debris every 8 ticks, a slam every 30, a bounce every 17, and a sliding body.
		var cpu := PackedFloat64Array()
		var draws := PackedFloat64Array()
		var peak: int = 0
		var f = S.fighters[0]
		f.x = x0
		f.y = g0
		f.state = "launched"
		f.vx = 4000.0
		f.slide = 4000.0
		for t in range(ticks.max()):
			var evs: Array = []
			evs.append(_ev("fire", {"x": x0 + float(t % 5) * 120.0, "y": g0, "n": 6, "z": 0.0}))
			if t % 8 == 0:
				evs.append(_ev("debris", {"x": x0, "y": g0 + 10.0, "n": 14, "col": "#6d6a66", "spd": 650.0, "z": 0.0}))
			if t % 30 == 0:
				evs.append(_ev("land", {"actor": 0.0, "x": x0, "y": g0, "z": 0.0, "spd": 4500.0, "n": 1, "surface": "soil", "kind": "slam", "vn": -3600.0, "vt": 1000.0, "sina": 0.95, "slope": 0.0}))
			if t % 17 == 0:
				evs.append(_ev("bounce", {"actor": 0.0, "x": x0, "y": g0, "z": 0.0, "spd": 3000.0, "n": 1, "surface": "soil", "k": 1.0, "vn": -2200.0, "keep": 0.4}))
			_tick(S, evs)
			main.host.cam.x = x0
			main.host.cam.y = g0 + 70.0
			main.host.cam.z = zoom
			main.host._prev = main.host._capture()
			main.host._cur = main.host._prev
			var t0: int = Time.get_ticks_usec()
			main.render_view(1.0)
			var t1: int = Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			if t > 30:
				cpu.append((t1 - t0) / 1000.0)
				draws.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
			peak = maxi(peak, h.debris.bits.size())
		var srt: PackedFloat64Array = cpu.duplicate()
		srt.sort()
		var mean: float = 0.0
		for v in cpu:
			mean += v
		mean /= maxf(float(cpu.size()), 1.0)
		var dm: float = 0.0
		for v in draws:
			dm += v
		dm /= maxf(float(draws.size()), 1.0)
		print("BENCH earth %s: frame CPU mean %.3f p99 %.3f max %.3f ms, draw calls mean %.1f, peak bits %d, consume mean %.3f max %.3f ms" % ["off" if off else "on", mean, srt[int(srt.size() * 0.99)], srt[srt.size() - 1], dm, peak, h.stat_consume_usec / 1000.0 / maxf(1.0, float(h.stat_consume_n)), h.stat_consume_max / 1000.0])
		quit()
		return
	if which == "deb" or which == "flame":
		S.fighters[0].x = SimWrap.wrap(x0 - 2400.0)
		S.fighters[0].y = WorldTerrain.groundY(S, S.fighters[0].x)
		S.fighters[1].x = SimWrap.wrap(x0 + 2400.0)
		S.fighters[1].y = WorldTerrain.groundY(S, S.fighters[1].x)
		var cols: Array = ["#6d6a66", "#8f8b84", "#77808f", "#8a6a4a", "#2f4a25"]
		var last: int = ticks.max()
		for t in range(last + 1):
			var evs: Array = []
			if which == "deb" and t == 0:
				for i in range(cols.size()):
					var dx: float = (float(i) - 2.0) * 450.0
					evs.append(_ev("debris", {"x": x0 + dx, "y": WorldTerrain.groundY(S, x0 + dx) + 10.0, "n": 12, "col": cols[i], "spd": 650.0, "z": 0.0}))
			if which == "flame" and t % 5 == 0 and t < 50:
				for i in range(3):
					var fx: float = x0 + (float(i) - 1.0) * 520.0
					evs.append(_ev("fire", {"x": fx, "y": WorldTerrain.groundY(S, fx), "n": 4, "z": 0.0}))
			_tick(S, evs)
			if t in ticks:
				await _shot("%s_t%d" % [which, t], x0, g0 + 70.0)
		quit()
		return
	# The ground contact cases, in the real sim.
	var spec: Dictionary = {"slam": [1500.0, -3600.0, 1200.0, "land"], "skid": [5200.0, -650.0, 300.0, "land"], "bounce": [3200.0, -2600.0, 800.0, "bounce"]}
	var sp: Array = spec[which]
	var f = S.fighters[0]
	var o = S.fighters[1]
	f.x = x0
	f.y = g0 + float(sp[2])
	f.vx = float(sp[0])
	f.vy = float(sp[1])
	f.state = "launched"
	f.launchT = 1.0
	f.stateT = 0.0
	f.bounces = 0.0
	o.x = SimWrap.wrap(x0 - 3000.0)
	o.y = WorldTerrain.groundY(S, o.x)
	var due: Array = []
	var got: bool = false
	var kind_want: String = sp[3]
	for i in range(300):
		_seen.clear()
		main.frame(1.0 / 60.0)
		var t: int = main.host.ticks
		for e in _seen:
			if e.type == kind_want and not got and e.get("surface") != "water":
				got = true
				for d in ticks:
					due.append([t + d, "%s_t%d" % [which, d], float(e.x), float(e.y)])
		for d in due.duplicate():
			if t >= d[0]:
				due.erase(d)
				await _shot(d[1], float(d[2]) + 200.0, float(d[3]) + 70.0)
		if got and due.is_empty():
			break
		await process_frame
	quit()
