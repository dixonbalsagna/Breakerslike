extends SceneTree
## Pictures of the transformation's effects (docs/vfx/transform-plan.md), before and after: a `transform` event is fed to
## the hub for fighter 0 and the frames at chosen ticks into it are saved, the sim standing still the way a pause stands it
## (every tick after the event is a frozen tick, as for a full or short version). --off turns the effect off for the "before"
## set. Needs a window.
##   godot --path . --script res://render/vfx/tools/transform_shots.gd -- --out=DIR [--off] [--version=full|short|live]
##       [--tier=2..4] [--fighter=0|1] [--zoom=0.9] [--size=1280x720] [--ticks=0,30,58,62,70,100,150,175] [--ground]
## --ground stands him on the terrain; the default floats him a little above it. --aura=charge or --aura=attack shows the
## standing aura instead (he charges, or holds a beam charge, until --release=TICK), --noaura turns it off for the "before" set.

var main: Node
var out: String = "."
var zoom: float = 0.9
var size := Vector2i(1280, 720)
var off: bool = false
var version: String = "full"
var tier: float = 2.0
var slot: int = 0
var ground: bool = false
var wx: float = 2250.0
var aura_mode: String = ""        # "", "charge" or "attack": the standing aura instead of a transformation
var release: int = 60            # the tick the charge or attack ends, for the standing aura
var noaura: bool = false
var ticks: Array = [0, 30, 58, 62, 70, 100, 150, 175]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--off":
			off = true
		elif a.begins_with("--x="):
			wx = float(a.substr(4))
		elif a.begins_with("--aura="):
			aura_mode = a.substr(7)
		elif a.begins_with("--release="):
			release = int(a.substr(10))
		elif a == "--noaura":
			noaura = true
		elif a == "--ground":
			ground = true
		elif a.begins_with("--version="):
			version = a.substr(10)
		elif a.begins_with("--tier="):
			tier = float(a.substr(7))
		elif a.begins_with("--fighter="):
			slot = int(a.substr(10))
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
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


func _tick(S: SimState, evs: Array) -> void:
	var tk := SimState.FxEvent.new()
	tk.type = "tick"
	tk.dt = SimConst.DT
	tk.frozen = version != "live" and aura_mode == ""   # a full or short version is played during the sim's frozen (paused) ticks; a live one, and the standing aura, run on live ticks
	var all: Array = evs.duplicate()
	all.append(tk)
	main.host.vfx.consume(S, all)
	main.host.ticks += 1
	main.host._prev = main.host._cur
	main.host._cur = main.host._capture()


func _run() -> void:
	await process_frame
	main.started = true
	var h = main.host.vfx
	h.auto_quality = false
	h.transform_enabled = not off
	h.standing_aura_enabled = not noaura
	main.start_match(3, {"p1": true, "p2": true})
	var S: SimState = main.host.S
	var f = S.fighters[slot]
	var o = S.fighters[1 - slot]
	f.tier = tier
	f.x = SimWrap.wrap(wx * SimConst.PS)
	f.y = WorldTerrain.groundY(S, f.x) + (0.0 if ground else 120.0)
	f.vx = 0.0
	f.vy = 0.0
	o.x = SimWrap.wrap(f.x + 1500.0)
	o.y = WorldTerrain.groundY(S, o.x) + 80.0
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var dur: float = {"full": 3.0, "short": 1.5, "live": 0.8}[version]
	var ev := SimState.FxEvent.new()
	ev.type = "transform"
	ev.actor = float(slot)
	ev.tier = tier
	ev.source = "ai"
	ev.dur = dur
	ev.version = version
	var last: int = ticks.max()
	for t in range(last + 1):
		if aura_mode != "":
			f.state = "charging" if (aura_mode == "charge" and t < release) else "free"
			f.beamCharge = 1.0 if (aura_mode == "attack" and t < release) else null
		_tick(S, [] if aura_mode != "" else ([ev] if t == 0 else []))
		if t in ticks:
			main.host.cam.x = SimWrap.wrap(f.x + 100.0)
			main.host.cam.y = f.y + 40.0 + 0.1 * vp.y / zoom
			main.host.cam.z = zoom
			main.host._prev = main.host._capture()
			main.host._cur = main.host._prev
			main.render_view(1.0)
			await RenderingServer.frame_post_draw
			main.render_view(1.0)
			await RenderingServer.frame_post_draw
			var path: String = "%s/xform_%s_t%d_%s_%d.png" % [out, version if aura_mode == "" else "aura_" + aura_mode, int(tier), "off" if (off or noaura) else "on", t]
			main.get_viewport().get_texture().get_image().save_png(path)
			print("saved %s (forms %d, drawn %d, instances %d)" % [path, h.xform.forms.size(), main.panes[0].vfx_layer.transform_view.forms_drawn, main.panes[0].vfx_layer.transform_view.count])
	# The cost of drawing it: the view's update with the form in its busiest beat (the gather's middle), and the hub's step.
	if not off:
		_tick(S, [ev])
		for k in range(30):
			_tick(S, [])
		var tv = main.panes[0].vfx_layer.transform_view
		var a: float = main.host.alpha()
		var cx: float = main.host.camera_x(a)
		var t0: int = Time.get_ticks_usec()
		for k in range(500):
			tv.update(h, main.host, a, cx, zoom, 600.0)
		var per: float = float(Time.get_ticks_usec() - t0) / 500.0
		print("transform view update: %.1f us a frame (%d instances), one fighter; hub step+begin %.1f us" % [per, tv.count, _bench_step(h, S, ev)])
	quit()


func _bench_step(h, S: SimState, ev) -> float:
	var t0: int = Time.get_ticks_usec()
	for k in range(500):
		h.xform.step(true)
		if k % 100 == 0:
			h.xform.begin(0, 3.0, "full", 3.0)
	return float(Time.get_ticks_usec() - t0) / 500.0
