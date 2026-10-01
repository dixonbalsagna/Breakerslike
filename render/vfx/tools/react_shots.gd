extends SceneTree
## Pictures of the reactions to power (docs/vfx/react-plan.md), before and after: --off turns the reactions off for the
## "before" set. Needs a window.
##   godot --path . --script res://render/vfx/tools/react_shots.gd -- --out=DIR --case=rubble|windows|flicker|speed [--off]
##       [--tier=3|4] [--ticks=20,60,120,200] [--x=1500] [--zoom=1.0] [--size=1280x720] [--stage=2|3] [--brink]
## rubble: a tier 3 or 4 fighter stands still on the ground; rubble lifts and a web of cracks spreads from his feet.
## windows: a big impact by a tier 3 or 4 fighter in the city; the windows of the block along it blow out.
## flicker: a worn fighter (the core's wear stage) charging, with his aura on, frame by frame.
## speed: a heavy lands on the fighter (a `damage` event of kind heavy): the six-tick streak of speed lines toward the hit.

var main: Node
var out: String = "."
var zoom: float = 1.0
var size := Vector2i(1280, 720)
var off: bool = false
var which: String = "rubble"
var tier: float = 3.0
var wx: float = 1500.0
var ticks: Array = [20, 60, 120, 200]
var stage: int = 2
var brink: bool = false
var stance: int = -1             # set the fighter's stance (0 aggressive, 1 defensive, 2 evasive, 3 escape); -1 leaves it
var nofx: bool = false           # every VFX flag of this work off (to tell VFX from Rendering)
var slot: int = 0                # which fighter the case is about (1: VORR, to see the Anti-hero's lane colour)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--off":
			off = true
		elif a.begins_with("--slot="):
			slot = int(a.substr(7))
		elif a.begins_with("--stance="):
			stance = int(a.substr(9))
		elif a == "--nofx":
			nofx = true
		elif a == "--brink":
			brink = true
		elif a.begins_with("--case="):
			which = a.substr(7)
		elif a.begins_with("--tier="):
			tier = float(a.substr(7))
		elif a.begins_with("--x="):
			wx = float(a.substr(4))
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
		elif a.begins_with("--stage="):
			stage = int(a.substr(8))
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
	S.T += SimConst.DT
	S.tick += 1
	var tk := SimState.FxEvent.new()
	tk.type = "tick"
	tk.dt = SimConst.DT
	tk.frozen = false
	var all: Array = evs.duplicate()
	all.append(tk)
	main.host.vfx.consume(S, all)
	main.host.ticks += 1
	main.host._prev = main.host._cur
	main.host._cur = main.host._capture()


func _shot(S: SimState, name: String, cam_x: float, cam_y: float) -> void:
	main.host.cam.x = SimWrap.wrap(cam_x)
	main.host.cam.y = cam_y
	main.host.cam.z = zoom
	main.host._prev = main.host._capture()
	main.host._cur = main.host._prev
	main.render_view(1.0)
	await RenderingServer.frame_post_draw
	main.render_view(1.0)
	await RenderingServer.frame_post_draw
	var path: String = "%s/react_%s_t%d_%s.png" % [out, which, int(tier), name + ("_before" if off else "_after")]
	main.get_viewport().get_texture().get_image().save_png(path)
	var h = main.host.vfx
	print("saved %s (bits %d, rubble %d, stand sets %d, blow buildings %d)" % [path, h.debris.bits.size(), h.debris._rubble_alive, h.react.stand_sets, h.react.blow_buildings])


func _run() -> void:
	await process_frame
	main.started = true
	var h = main.host.vfx
	h.auto_quality = false
	h.react_enabled = not off
	h.speedlines_enabled = not off
	h.standing_aura_enabled = not nofx
	h.transform_enabled = not nofx
	h.flicker_enabled = not nofx
	h.speedlines_enabled = not (off or nofx)
	h.react_enabled = not (off or nofx)
	main.start_match(3, {"p1": true, "p2": true})
	var S: SimState = main.host.S
	var f = S.fighters[slot]
	var o = S.fighters[1 - slot]
	f.tier = tier
	o.tier = 1.0
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var last: int = ticks.max()
	if which == "windows":
		var c: float = SimWrap.wrap(2960.0 * SimConst.PS)
		var near: Array = VfxMock.towers_near(S, c, 40000.0)
		var b0 = S.buildings[near[0]]
		f.x = SimWrap.wrap(b0.x - 700.0)
		f.y = WorldTerrain.groundY(S, f.x) + 60.0
		o.x = SimWrap.wrap(f.x + 2200.0)
		o.y = WorldTerrain.groundY(S, o.x) + 60.0
		var crater := SimState.FxEvent.new()
		crater.type = "crater"
		crater.x = f.x
		crater.y = WorldTerrain.groundY(S, f.x)
		crater.r = 220.0
		crater.depth = 60.0
		crater.energy = 18.0
		crater.cause = "impact"
		crater.owner = float(slot)
		crater.special = 0.0
		for t in range(last + 1):
			_tick(S, [crater] if t == 0 else [])
			if t in ticks:
				await _shot(S, "t%d" % t, f.x + 1200.0, f.y + 300.0 + 0.1 * vp.y / zoom)
	elif which == "bench":
		# Everything at once in the city: both fighters tier 4 and worn, standing and charging in turn, a big crater every second,
		# a heavy every 8 ticks. CPU and draw calls with the reactions on or off (--off).
		var c2: float = SimWrap.wrap(2960.0 * SimConst.PS)
		var near2: Array = VfxMock.towers_near(S, c2, 40000.0)
		var b2 = S.buildings[near2[0]]
		f.tier = 4.0
		o.tier = 4.0
		f.x = SimWrap.wrap(b2.x - 700.0)
		f.y = WorldTerrain.groundY(S, f.x)
		o.x = SimWrap.wrap(f.x + 1500.0)
		o.y = WorldTerrain.groundY(S, o.x)
		f.stage[1] = 3
		o.stage[1] = 2
		var cpu := PackedFloat64Array()
		var draws := PackedFloat64Array()
		var peak: int = 0
		var rid: RID = main.get_viewport().get_viewport_rid()
		var n_frames: int = last
		for t in range(n_frames):
			var evs: Array = []
			if t % 60 == 5:
				var cr := SimState.FxEvent.new()
				cr.type = "crater"
				cr.x = f.x
				cr.y = f.y
				cr.r = 220.0
				cr.depth = 60.0
				cr.energy = 18.0
				cr.cause = "impact"
				cr.owner = 0.0
				cr.special = 0.0
				evs.append(cr)
			if t % 8 == 3:
				var hv := SimState.FxEvent.new()
				hv.type = "damage"
				hv.x = o.x
				hv.y = o.y + 40.0
				hv.amount = 30.0
				hv.col = "#fff"
				hv.attacker = float(t / 8 % 2)
				hv.victim = float(1 - int(t / 8) % 2)
				hv.region = "core"
				hv.kind = "heavy"
				hv.number = true
				evs.append(hv)
			f.state = "charging" if (t / 120) % 2 == 1 else "free"
			_tick(S, evs)
			main.host.cam.x = SimWrap.wrap(f.x + 700.0)
			main.host.cam.y = f.y + 300.0 + 0.1 * vp.y / zoom
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
			peak = maxi(peak, main.host.vfx.debris.bits.size())
		var srt: PackedFloat64Array = cpu.duplicate()
		srt.sort()
		var mean: float = 0.0
		for v in cpu:
			mean += v
		mean /= maxf(float(cpu.size()), 1.0)
		var dmean: float = 0.0
		for v in draws:
			dmean += v
		dmean /= maxf(float(draws.size()), 1.0)
		print("BENCH reactions %s: frame CPU mean %.3f p99 %.3f max %.3f ms, draw calls mean %.1f, peak bits %d, consume mean %.3f max %.3f ms, update (layer) mean %.3f max %.3f ms" % ["off" if off else "on", mean, srt[int(srt.size() * 0.99)], srt[srt.size() - 1], dmean, peak, h.stat_consume_usec / 1000.0 / maxf(1.0, float(h.stat_consume_n)), h.stat_consume_max / 1000.0, main.panes[0].vfx_layer.stat_update_usec / 1000.0 / maxf(1.0, float(main.panes[0].vfx_layer.stat_update_n)), main.panes[0].vfx_layer.stat_update_max / 1000.0])
	elif which == "speed":
		f.x = SimWrap.wrap(wx * SimConst.PS)
		f.y = maxf(WorldTerrain.groundY(S, f.x), 0.0) + 700.0
		o.x = SimWrap.wrap(f.x - 520.0)
		o.y = f.y
		f.vx = 0.0
		f.vy = 0.0
		var hit := SimState.FxEvent.new()
		hit.type = "damage"
		hit.x = f.x
		hit.y = f.y + 40.0
		hit.amount = 40.0
		hit.col = "#ffffff"
		hit.attacker = 1.0
		hit.victim = 0.0
		hit.region = "core"
		hit.kind = "heavy"
		hit.number = true
		for t in range(last + 1):
			_tick(S, [hit] if t == 0 else [])
			if t in ticks:
				await _shot(S, "t%d" % t, f.x - 200.0, f.y + 0.1 * vp.y / zoom)
	else:
		f.x = SimWrap.wrap(wx * SimConst.PS)
		f.y = WorldTerrain.groundY(S, f.x)
		f.vx = 0.0
		f.vy = 0.0
		f.state = "free"
		o.x = SimWrap.wrap(f.x + 2600.0)
		o.y = WorldTerrain.groundY(S, o.x) + 80.0
		if stance >= 0:
			f.stance = float(stance)
		if which == "flicker":
			f.state = "charging"
			f.stage[1] = stage
			f.brink = brink
		for t in range(last + 1):
			_tick(S, [])
			if t in ticks:
				await _shot(S, "t%d" % t, f.x + 100.0, f.y + 40.0 + 0.1 * vp.y / zoom)
	quit()
