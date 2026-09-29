extends Node3D
## Greybox main scene: runs the GDScript sim as a 60 Hz fixed-step loop (SimHost) and draws it every frame,
## interpolated between the last two ticks, in a 2.5D side-on view of the wrapped planet. It starts as an AI-vs-AI
## demo; any key or click hands P1 to a human (as the prototype did).
##
## It hosts UI's HUD (ui/hud/ui_hud.tscn, docs/ui/hud-spec.md section 14) and Audio's voices (audio/, "Hooking it
## up"). Both read the sim and the events SimHost drains; neither writes it. F2 swaps in the greybox HUD
## (render/core/hud.gd) until UI's playtest, F3 shows the performance readout, F4 the director feed.
##
## Rendering never writes sim state: the views read S, the fx consumer and the reference camera, and only SimHost
## steps the sim. render/tools/determinism.gd checks that the gameplay hashes are unchanged by rendering.
##
## Command-line options (after "--"): --seed=N, --human (take P1 at start), --legacy-hud, --frames=N (quit after N frames),
## --shot=path.png (save the last frame), --bench (vsync off; print frame-time stats at quit), --novsync.
## Benchmark: godot --path . --fixed-fps 60 --resolution 1280x720 -- --seed=4 --frames=4800 --bench
## (--fixed-fps 60 gives exactly one sim tick per frame; with vsync off each frame runs as fast as it can, so the
## wall-clock frame time is the true cost of one tick plus one rendered frame.)

@onready var cam_rig: CameraRig = $Camera
@onready var planet: PlanetView = $Planet
@onready var fighters_root: Node3D = $Fighters
@onready var beams: BeamView = $Beams
@onready var particles: ParticleView = $Particles
@onready var hud: HudView = $HUD/Overlay
@onready var env: WorldEnvironment = $Environment

var host: SimHost
var started: bool = false
var manual: bool = false          # tools call frame() or render_view() themselves
var fighter_views: Array = []
var view_cam_x: float = 0.0       # the interpolated camera's wrapped world x this frame
var args: Dictionary = {}
var frames: int = 0
var _ring: Array = [PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array()]   # frame, tick, fx, view ms
var _bench: Array = [PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array()]
var _render_cpu := PackedFloat64Array()
var _render_gpu := PackedFloat64Array()
var _draws := PackedInt32Array()
var _quitting: bool = false
var _last_usec: int = 0
var _sky_mat: ShaderMaterial
var ui_hud: UiHud                 # UI's HUD
var audio: AudioVoices            # Audio's voice pool
var legacy_hud: bool = false      # F2: the greybox HUD instead of UI's


func _ready() -> void:
	args = parse_args()
	_setup_environment()
	host = SimHost.new()
	hud.main = self
	ui_hud = preload("res://ui/hud/ui_hud.tscn").instantiate()
	$HUD.add_child(ui_hud)
	$HUD.move_child(ui_hud, 0)    # under the greybox overlay, which keeps the take-over prompt and the perf readout
	ui_hud.anchor_fn = _hud_anchor
	ui_hud.strip_fn = _hud_strip
	host.drained.connect(_on_drained)
	audio = AudioVoices.new(host.audio_cues.bank)
	add_child(audio)
	if DisplayServer.get_name() != "headless":
		host.audio_cues.bank.warm()   # render every sound now, so none renders in the middle of a fight
	start_match(int(args["seed"]) if args.has("seed") else fresh_seed())
	if args.has("human"):
		take_over()
	if args.has("legacy-hud"):
		set_legacy_hud(true)
	if args.has("bench") or args.has("novsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func _exit_tree() -> void:
	SimCore.dispose(host.S)
	RenderMats.clear_cache()


func start_match(seed: int, ai: Dictionary = {}) -> void:
	host.new_match(seed, ai)
	var fl: Array = UiSimBridge.fighters(host.S)
	ui_hud.setup(fl[0], fl[1])
	planet.build(host.S)
	for v in fighter_views:
		fighters_root.remove_child(v)
		v.free()
	fighter_views.clear()
	for f in host.S.fighters:
		var v := FighterView.new()
		fighters_root.add_child(v)
		v.build(f)
		fighter_views.append(v)
	render_view(host.alpha())


func _process(delta: float) -> void:
	if not manual:
		frame(delta)


## One displayed frame: run the ticks this frame time allows, then draw at the interpolation point.
func frame(delta: float) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var t0: int = Time.get_ticks_usec()
	var n: int = host.advance(delta, vp.x, vp.y)
	var t1: int = Time.get_ticks_usec()
	render_view(host.alpha())
	ui_hud.advance(0.0 if host.paused else delta)
	for c in host.pending_cues:
		audio.play(c, view_cam_x, cam_rig.zoom)
	host.pending_cues.clear()
	var t2: int = Time.get_ticks_usec()
	# Wall-clock time since the last frame started (with --fixed-fps, delta is fixed and says nothing about cost).
	var wall: float = (t0 - _last_usec) / 1000.0 if _last_usec > 0 else delta * 1000.0
	_last_usec = t0
	_record(wall, n, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0)
	frames += 1
	if args.has("frames") and frames >= int(args["frames"]) and not _quitting:
		_quitting = true
		_finish()


func render_view(a: float) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var S: SimState = host.S
	var c: Vector3 = host.camera(a)
	view_cam_x = host.camera_x(a)
	cam_rig.frame(c.y, c.z, host.jitter, vp.y)
	_view_cues(c, vp)
	planet.update(S, view_cam_x, host.impact.heat, host.impact.heat_changed)
	host.impact.heat_changed = false
	for i in range(fighter_views.size()):
		fighter_views[i].update(S, S.fighters[i], host.fighter_pose(i, a), SimWrap.sdx(view_cam_x, host.fighter_x(i, a)), c.z)
	beams.update(S, view_cam_x, c.z)
	particles.update(host.fxv, host.impact, view_cam_x, c.z, cam_rig.half_width(vp.x, RenderLook.Z_PARTICLES))
	UiSimBridge.patch(ui_hud, S)
	ui_hud.queue_redraw()
	hud.queue_redraw()


## UI's HUD: each tick's events and feed lines, as SimHost drains them.
func _on_drained(events: Array, lines: Array) -> void:
	ui_hud.consume_all(events)
	UiSimBridge.feed(ui_hud, lines)


## UI's HUD anchor: a fighter's torso on screen and its height in pixels.
func _hud_anchor(slot: int) -> Dictionary:
	if slot < 0 or slot >= fighter_views.size():
		return {"pos": Vector2.ZERO, "h": 0.0, "visible": false}
	var torso: Vector3 = fighter_views[slot].global_position + Vector3(0.0, FighterView.PIVOT_Y, 0.0)
	if cam_rig.is_position_behind(torso):
		return {"pos": Vector2.ZERO, "h": 0.0, "visible": false}
	var p: Vector2 = cam_rig.unproject_position(torso)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vis: bool = Rect2(Vector2(-200.0, -200.0), vp + Vector2(400.0, 400.0)).has_point(p)
	return {"pos": p, "h": FighterView.HEIGHT * cam_rig.zoom, "visible": vis}


## UI's planet strip: the bridge's data for the camera's centre and view width.
func _hud_strip() -> Dictionary:
	return UiSimBridge.strip_data(host.S, view_cam_x, 2.0 * cam_rig.half_width(get_viewport().get_visible_rect().size.x))


## Planet-scale cues and crowd legibility for this frame, from the zoom and the camera height (presentation only).
func _view_cues(c: Vector3, vp: Vector2) -> void:
	var wide: float = smoothstep(RenderLook.ZOOM_CLOSE, RenderLook.ZOOM_WIDE, c.z)
	var high: float = smoothstep(RenderLook.HIGH_FROM, RenderLook.HIGH_TO, c.y)
	var d: float = lerpf(RenderLook.CURVE_NEAR, RenderLook.CURVE_WIDE, wide) + RenderLook.CURVE_HIGH * high
	# Every layer from full depth weight back sags d * vh pixels at its screen edge (bend.gdshaderinc).
	var dist: float = cam_rig.position.z
	RenderMats.set_bend(4.0 * d * vp.y * c.z / (vp.x * vp.x), dist)
	# The horizon is the far edge of the ground: its elevation from the camera anchors the sky and the fog.
	var hz: float = (0.0 - cam_rig.position.y) / (dist + RenderLook.FOG_FAR)
	for k in [["space", high], ["horizon", hz]]:
		_sky_mat.set_shader_parameter(k[0], k[1])
		RenderMats.set_sky(k[0], k[1])
	var boost: float = clampf(RenderLook.CROWD_MIN_PX / (CrowdMesh.HEIGHT * c.z), 1.0, RenderLook.CROWD_BOOST_MAX)
	# The shell's push directions are unit corner diagonals, so each axis moves 1/sqrt(3) of the width.
	planet.set_crowd_view(boost, 1.732 * RenderLook.CROWD_OUTLINE_PX / c.z)


## The greybox HUD instead of UI's (F2, or --legacy-hud at start). UI's HUD keeps reading events while hidden.
func set_legacy_hud(on: bool) -> void:
	legacy_hud = on
	hud.legacy = on
	ui_hud.visible = not on


func take_over() -> void:
	if started:
		return
	started = true
	if host.S.fighters[0].ai != null:
		host.toggle_ai(0)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey:
		var code: String = RenderKeys.code(e)
		get_viewport().set_input_as_handled()
		if not e.pressed:
			host.key_up(code)
			return
		var fkey: bool = code.length() <= 3 and code.begins_with("F") and code.substr(1).is_valid_int()
		if not e.echo:
			if code == "F3":
				hud.show_perf = not hud.show_perf
				return
			if code == "F2":
				set_legacy_hud(not legacy_hud)
				return
			if code == "F4":
				ui_hud.set_option("show_feed", not bool(ui_hud.opts["show_feed"]))
				return
			if code == "Escape" and not OS.has_feature("web"):
				get_tree().quit()
				return
			if fkey:
				return
			if not e.ctrl_pressed and not e.meta_pressed:
				take_over()
			match code:
				"KeyN":
					start_match(fresh_seed())
					return
				"KeyT":
					host.toggle_ai(1)
					return
				"KeyY":
					host.toggle_ai(0)
					return
				"KeyP":
					host.paused = not host.paused
					return
			host.key_down(code)
		elif not fkey:
			host.held[code] = true
	elif e is InputEventMouseButton and e.pressed:
		take_over()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and host != null:
		host.release_all()


static func fresh_seed() -> int:
	return ((Time.get_ticks_usec() ^ int(Time.get_unix_time_from_system() * 1000.0)) & 0xFFFFFF) | 1


static func parse_args() -> Dictionary:
	var out: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return out


func _setup_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	_sky_mat = sky_mat
	sky_mat.shader = preload("res://render/shaders/sky.gdshader")
	var skyp: Dictionary = {
		"sky_top": RenderLook.col(RenderLook.SKY[0]), "sky_upper": RenderLook.col(RenderLook.SKY[1]),
		"sky_lower": RenderLook.col(RenderLook.SKY[2]), "sky_horizon": RenderLook.col(RenderLook.SKY[3]),
		"sky_tan": tan(deg_to_rad(RenderLook.FOV_DEG) * 0.5), "sky_lower_at": RenderLook.SKY_LOWER_AT,
		"sky_upper_at": RenderLook.SKY_UPPER_AT, "sky_top_at": RenderLook.SKY_TOP_AT, "sky_thin": RenderLook.SKY_THIN,
		"fog_band": RenderLook.FOG_BAND,
	}
	for k in skyp:
		sky_mat.set_shader_parameter(k, skyp[k])
		RenderMats.set_sky(k, skyp[k])
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e


func _record(frame_ms: float, n: int, tick_ms: float, view_ms: float) -> void:
	var row: Array = [frame_ms, host.tick_usec / 1000.0 if n > 0 else 0.0, host.fx_usec / 1000.0 if n > 0 else 0.0, view_ms]
	for i in range(4):
		_ring[i].append(row[i])
		if _ring[i].size() > 240:
			_ring[i].remove_at(0)
		if args.has("bench") and frames >= 60:
			_bench[i].append(row[i])
	if args.has("bench") and frames >= 60:
		var rid: RID = get_viewport().get_viewport_rid()
		_render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu())
		_render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		_draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))


func perf_summary() -> Dictionary:
	return {
		"frame_ms": _mean(_ring[0]), "frame_p95": _pct(_ring[0], 0.95), "tick_ms": _mean(_ring[1]), "fx_ms": _mean(_ring[2]),
		"view_ms": _mean(_ring[3]), "particles": particles.count,
		"draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(),
	}


func _finish() -> void:
	var gh: String = SimHash.stateHash(host.S).gameplay
	if args.has("bench"):
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var d := PackedFloat64Array()
		for x in _draws:
			d.append(float(x))
		var rows: Array = [
			["frame ms (vsync off)", _bench[0]], ["view update ms / frame", _bench[3]],
			["sim tick ms (per tick)", Array(_bench[1]).filter(func(v): return v > 0.0)],
			["fx+camera ms (per tick)", Array(_bench[2]).filter(func(v): return v > 0.0)],
			["render cpu ms", _render_cpu], ["render gpu ms", _render_gpu], ["draw calls", d],
		]
		var head: String = "%s | %s | %s | %dx%d | %d frames after 60 warm-up | sim ticks %d, final T %.1f s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), OS.get_name(), int(vp.x), int(vp.y), _bench[0].size(), host.ticks, host.S.T]
		print("BENCH " + head)
		var res: Dictionary = {"head": head, "hash": gh, "ticks": host.ticks, "audio": "%d played, %d dropped" % [audio.played, audio.dropped]}
		print("BENCH audio %s" % res["audio"])
		for r in rows:
			print("BENCH %-24s %s" % [r[0], _dist(r[1])])
			res[r[0]] = _dist(r[1])
		if OS.has_feature("web"):
			# For browser drivers (research/engine-spike/tools/bench-browser.mjs polls window.__benchResult).
			JavaScriptBridge.eval("window.__benchResult = %s;" % JSON.stringify(res), true)
	if args.has("shot"):
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(args["shot"])
		print("saved " + args["shot"])
	print("gameplay hash at tick %d: %s" % [host.ticks, gh])
	if not OS.has_feature("web"):
		get_tree().quit()


static func _mean(v) -> float:
	if v.size() == 0:
		return 0.0
	var s: float = 0.0
	for x in v:
		s += x
	return s / v.size()


static func _pct(v, q: float) -> float:
	if v.size() == 0:
		return 0.0
	var s = v.duplicate()
	s.sort()
	return s[mini(s.size() - 1, int(s.size() * q))]


static func _dist(v) -> String:
	if v.size() == 0:
		return "n/a"
	return "mean %.3f  p50 %.3f  p95 %.3f  p99 %.3f  max %.3f" % [_mean(v), _pct(v, 0.5), _pct(v, 0.95), _pct(v, 0.99), _pct(v, 1.0)]
