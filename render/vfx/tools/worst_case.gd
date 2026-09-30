extends SceneTree
## The worst-case VFX scene for the budget table (docs/vfx/effect-budgets.md): everything at once, in view. Two fighters
## at full trail speed, a chain through four towers with its tunnel, a block of eight towers imploding beside it, a
## crack set from every impact and slide staged around the camera, all on the real planet at a gameplay zoom. It plays the
## same scene with VFX on and with VFX off (hub.enabled false) and prints frame CPU time, the GPU render time, draw
## calls and the VFX pools' peak. Needs a window (not --headless) for the GPU numbers.
##   godot --path . --script res://render/vfx/tools/worst_case.gd -- [--frames=360] [--size=1280x720] [--quality=2]

const DT := SimConst.DT

var main: Node
var frames: int = 360
var size := Vector2i(1280, 720)
var quality: int = 2


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			frames = int(a.substr(9))
		elif a.begins_with("--size="):
			var wh: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--quality="):
			quality = int(a.substr(10))
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
	RenderingServer.viewport_set_measure_render_time(main.get_viewport().get_viewport_rid(), true)
	var on: Dictionary = await _scene(true)
	var off: Dictionary = await _scene(false)
	print("WORST CASE %dx%d, %d frames, quality %d" % [size.x, size.y, frames, quality])
	for k in ["cpu", "gpu"]:
		print("  %-4s VFX on  %s" % [k, on[k]])
		print("  %-4s VFX off %s" % [k, off[k]])
	print("  draw calls   on %s | off %s" % [on["draws"], off["draws"]])
	print("  vfx: consume mean %.3f ms max %.3f ms; layer update mean %.3f ms max %.3f ms" % [on["consume_ms"], on["consume_max"], on["update_ms"], on["update_max"]])
	print("  pools: peak bits %d (shards+puffs cap %d), crack sets %d (%d triangles), holes peak %d, ribbons peak %d, marks peak %d" % [on["peak_bits"], VfxLook.DEBRIS_CAP, on["sets"], on["tris"], on["peak_holes"], on["peak_ribbons"], on["peak_marks"]])
	quit()


func _scene(vfx_on: bool) -> Dictionary:
	main.start_match(1)
	var S: SimState = main.host.S
	S.out.fx.clear()
	var h = main.host.vfx
	h.auto_quality = false
	h.enabled = vfx_on
	h.cracks_enabled = true
	h.destruction_enabled = true
	h.quality = quality
	# The chain: four towers in a row near the city; a block of eight more further along, to implode.
	var c: float = SimWrap.wrap(2960.0 * SimConst.PS)
	var near: Array = VfxMock.towers_near(S, c, 40000.0)
	var ch: Array = near.slice(0, 4)
	var blk: Array = near.slice(6, 14)
	var b0 = S.buildings[ch[0]]
	var g0: float = WorldTerrain.groundY(S, b0.x)
	var v: float = 9000.0
	var x0: float = b0.x - b0.w * 0.5 - 1500.0
	var y0: float = g0 + b0.h * 0.4
	# Impacts and slides staged around the camera: one crack set each.
	var A = S.fighters[1]
	for k in range(14):
		WorldCrater.dig(S, x0 + (float(k) - 6.0) * 2200.0, 1.0 + float(k % 5) * 3.0, A, "impact", 0.3, 1.0)
	var f = S.fighters[0]
	var arrive: Array = []
	var leave: Array = []
	for k in range(4):
		var bk = S.buildings[ch[k]]
		arrive.append(int((SimWrap.sdx(x0, bk.x) - bk.w * 0.5) / (v * DT)))
		leave.append(int((SimWrap.sdx(x0, bk.x) + bk.w * 0.5) / (v * DT)))
	var cpu := PackedFloat64Array()
	var gpu := PackedFloat64Array()
	var draws := PackedFloat64Array()
	var peak_bits: int = 0
	var peak_holes: int = 0
	var peak_ribbons: int = 0
	var peak_marks: int = 0
	var rid: RID = main.get_viewport().get_viewport_rid()
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	for t in range(frames):
		var evs: Array = []
		var x: float = x0 + v * DT * float(t)
		f.x = SimWrap.wrap(x)
		f.y = y0
		f.vx = v
		f.vy = 0.0
		f.state = "launched"
		var o = S.fighters[1]
		o.x = SimWrap.wrap(x0 - 600.0 + v * DT * float(t) * 0.5)
		o.y = y0 + 400.0
		o.vx = v * 0.5
		o.vy = 0.0
		o.state = "launched"
		for k in range(4):
			if t == arrive[k]:
				evs.append(VfxMock.building_hit(S, ch[k], 1.0, 0.0, v * (1.0 - 0.1 * float(k)), k + 1, 4, "collapse", 0))
			if t == leave[k]:
				evs.append(VfxMock.building_fall(S, ch[k], "burst", 0.0, S.buildings[ch[k]].x))
				if k < 3:
					evs.append(VfxMock.chain_link(S, ch[k], ch[k + 1], v, k + 1))
		if t == arrive[1]:
			var cx: float = S.buildings[blk[3]].x
			for bi in blk:
				evs.append(VfxMock.building_fall(S, bi, "implode", clampf(absf(SimWrap.sdx(cx, S.buildings[bi].x)) / 1000.0, 0.0, 1.0), cx))
		S.T += DT
		S.tick += 1
		var tk := SimState.FxEvent.new()
		tk.type = "tick"
		tk.dt = DT
		tk.frozen = false
		evs.append(tk)
		if vfx_on:
			h.consume(S, evs)
		# The camera follows the launched fighter at a gameplay zoom.
		main.host.follow(vp.x, vp.y)
		main.host.cam.x = SimWrap.wrap(f.x + 400.0)
		main.host.cam.y = f.y + 0.2 * vp.y / 0.5
		main.host.cam.z = 0.5
		main.host._prev = main.host._capture()
		main.host._cur = main.host._prev
		var t0: int = Time.get_ticks_usec()
		main.render_view(1.0)
		var t1: int = Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		if t > 20:
			cpu.append((t1 - t0) / 1000.0)
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
			draws.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
		peak_bits = maxi(peak_bits, h.debris.bits.size())
		peak_holes = maxi(peak_holes, h.holes.size())
		var lay = main.panes[0].vfx_layer
		peak_ribbons = maxi(peak_ribbons, lay.trail_view.ribbons)
		peak_marks = maxi(peak_marks, lay.trail_view.mark_count)
	var tris: int = 0
	for cs in h.crack_sets:
		tris += cs.tris
	var lay2 = main.panes[0].vfx_layer
	return {
		"cpu": _dist(cpu), "gpu": _dist(gpu), "draws": "%.0f mean, %.0f max" % [_mean(draws), _max(draws)],
		"consume_ms": h.stat_consume_usec / 1000.0 / maxf(1.0, float(h.stat_consume_n)), "consume_max": h.stat_consume_max / 1000.0,
		"update_ms": lay2.stat_update_usec / 1000.0 / maxf(1.0, float(lay2.stat_update_n)), "update_max": lay2.stat_update_max / 1000.0,
		"peak_bits": peak_bits, "sets": h.crack_sets.size(), "tris": tris, "peak_holes": peak_holes, "peak_ribbons": peak_ribbons, "peak_marks": peak_marks,
	}


static func _mean(v: PackedFloat64Array) -> float:
	if v.size() == 0:
		return 0.0
	var s: float = 0.0
	for x in v:
		s += x
	return s / v.size()


static func _max(v: PackedFloat64Array) -> float:
	var m: float = 0.0
	for x in v:
		m = maxf(m, x)
	return m


static func _pct(v: PackedFloat64Array, q: float) -> float:
	if v.size() == 0:
		return 0.0
	var s: PackedFloat64Array = v.duplicate()
	s.sort()
	return s[mini(s.size() - 1, int(s.size() * q))]


static func _dist(v: PackedFloat64Array) -> String:
	return "mean %.3f  p50 %.3f  p95 %.3f  p99 %.3f  max %.3f ms" % [_mean(v), _pct(v, 0.5), _pct(v, 0.95), _pct(v, 0.99), _max(v)]
