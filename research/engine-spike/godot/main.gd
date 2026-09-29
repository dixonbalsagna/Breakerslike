extends Node3D
## Engine spike (throwaway, research only). The Godot 4.7.2 spike application: demo, bench, screenshot and simbench.
##
## Layers (kept separate, per SPEC):
##   sim      sim/*.gd (another agent's port of shared/sim-ref.mjs). Stepped here at a fixed 60 Hz by an accumulator
##            in _process (at most 8 steps per frame). Physics is not used.
##   camera   view/camera.gd. Presentation; stepped once per sim tick, after the sim.
##   render   render/world_view.gd, render/particles.gd, render/hud.gd. They read the scene and camera, never write.
##   input    the demo's flight keys and C (crater) are player-layer inputs applied at a tick boundary, before step().
##
## User arguments (after "--"), or the page query on the web (?bench=1&scene=worst&shot=1&warmup=&measure=):
##   --bench --scene worst --out <abs.json> [--warmup 180] [--measure 1800] [--look production]
##   --screenshot <abs.png> --scene <name> [--at <tick>]
##   --simbench --out <abs.json> [--reps 5] [--ticks 3600]
##   demo: [--scene <name>] [--cycle <seconds per scene>] [--quit-after-sec <s>]

const _Scenes = preload("res://sim/scenes.gd")
const _Camera = preload("res://view/camera.gd")
const _Hash = preload("res://sim/state_hash.gd")
const _Simbench = preload("res://tests/simbench.gd")
const _Bench = preload("res://bench/bench.gd")

const DT: float = 1.0 / 60.0
const MAX_STEPS: int = 8
const HASH_TICK: int = 1980
const SCENE_NAMES: Array[String] = ["flight", "worst", "sweep", "chase", "orbit", "climb"]
# Screenshot ticks: flight at 410 (camera 565 u from the seam, ground in view, a crater 20 ticks old; found by
# scanning the reference sim + camera), worst at 1200, sweep with the boxes
# half the planet apart (separation 50 u per tick -> 4800 at tick 96).
const SHOT_AT: Dictionary = {"flight": 410, "worst": 1200, "sweep": 96, "chase": 120, "orbit": 120, "climb": 300}
const JS_GPU: String = "(function(){try{var c=document.createElement('canvas');var g=c.getContext('webgl2');var e=g.getExtension('WEBGL_debug_renderer_info');return e?String(g.getParameter(e.UNMASKED_RENDERER_WEBGL)):String(g.getParameter(g.RENDERER));}catch(x){return '';}})()"

@onready var camera3d: Camera3D = $Camera
@onready var view = $View
@onready var particles = $Particles
@onready var hud = $HUD
@onready var sun: DirectionalLight3D = $Sun
@onready var world_env: WorldEnvironment = $WorldEnvironment

var opts: Dictionary = {}
var is_web: bool = false
var mode: String = "demo"          # demo | bench | shot | simbench
var quitting: bool = false
var scene_name: String = "flight"
var scene = null
var cam = null
var golden: Dictionary = {}
var hash_status: String = "n/a"
var input_used: bool = false       # player input changed the scene: goldens no longer apply
var human: bool = false
var crater_req: bool = false
var acc: float = 0.0
var prev_start_us: int = -1
var live_now: int = 0
var _sim_us: int = 0
var _part_us: int = 0
var look: String = "baseline"

# bench
var rec = null
var cur_measured: bool = false
var cur_start_us: int = 0
var bench_hash: String = ""
var bench_ff_from: int = -1
var vp_rid: RID

# demo
var cycle_s: float = 0.0
var cycle_acc: float = 0.0
var quit_after_s: float = 0.0
var run_s: float = 0.0
var scene_frames: int = 0
var scene_time_s: float = 0.0
var scene_live_max: int = 0


func _ready() -> void:
	_parse_args()
	if opts.has("simbench"):
		mode = "simbench"
		set_process(false)
		_run_simbench()
		return
	view.setup(camera3d)
	# One directional light (shines along its -Z), no shadows in the baseline.
	sun.basis = Basis.looking_at(Vector3(0.35, -0.8, -0.5))
	if str(opts.get("look", "")) == "production":
		look = "production"
		view.set_production_look(sun, world_env.environment, true)
	golden = _Hash.golden()
	if opts.has("screenshot") or (is_web and str(opts.get("shot", "0")) == "1"):
		mode = "shot"
	elif opts.has("bench") and str(opts["bench"]) != "0":
		mode = "bench"
	scene_name = str(opts.get("scene", "worst" if mode == "bench" else "flight"))
	if not SCENE_NAMES.has(scene_name):
		push_error("unknown scene " + scene_name)
		scene_name = "flight"
	_load_scene(scene_name)
	print("SPIKE mode=%s scene=%s renderer=%s driver=%s gpu=%s build=%s look=%s" % [mode, scene_name,
		RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(),
		_gpu_name(), _build_kind(), look])
	if mode == "bench":
		_bench_setup()
	elif mode == "shot":
		set_process(false)
		_run_shot.call_deferred()
	else:
		cycle_s = float(opts.get("cycle", "0"))
		quit_after_s = float(opts.get("quit-after-sec", "0"))
		if opts.has("inject-keys"):
			inject = str(opts["inject-keys"]).split(",", false)


func _parse_args() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < a.size():
		var k: String = a[i]
		if k.begins_with("--"):
			var key: String = k.substr(2)
			if i + 1 < a.size() and not a[i + 1].begins_with("--"):
				opts[key] = a[i + 1]
				i += 2
			else:
				opts[key] = "1"
				i += 1
		else:
			i += 1
	if OS.has_feature("web"):
		is_web = true
		var q = JavaScriptBridge.eval("location.search", true)
		if q is String:
			for part in (q as String).trim_prefix("?").split("&", false):
				var kv: PackedStringArray = part.split("=", true, 1)
				opts[kv[0].uri_decode()] = kv[1].uri_decode() if kv.size() > 1 else "1"


func _build_kind() -> String:
	if OS.has_feature("editor"):
		return "editor"
	if OS.has_feature("web"):
		return "web"
	return "release" if not OS.is_debug_build() else "debug"


var _gpu_cache: String = ""


func _gpu_name() -> String:
	if _gpu_cache != "":
		return _gpu_cache
	_gpu_cache = RenderingServer.get_video_adapter_name()
	if is_web:
		var g = JavaScriptBridge.eval(JS_GPU, true)
		if g is String and g != "":
			_gpu_cache = g
	return _gpu_cache


func _driver_name() -> Variant:
	if is_web:
		var g: String = _gpu_name()
		if g.begins_with("ANGLE (") and g.ends_with(")"):
			var inner: String = g.substr(0, g.length() - 1)
			return inner.substr(inner.rfind(",") + 1).strip_edges()
		return null
	var info: PackedStringArray = OS.get_video_adapter_driver_info()
	return RenderingServer.get_current_rendering_driver_name() + "; " + " ".join(info)


func _write_text(path: String, text: String) -> bool:
	path = path.replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(text)
	f.close()
	return true


func _quit(code: int) -> void:
	quitting = true
	set_process(false)
	if not is_web:
		get_tree().quit(code)


# ------------------------------------------------------------------------------------------------ scenes and ticks

func _load_scene(name: String) -> void:
	scene_name = name
	scene = _Scenes.make_scene(name)
	cam = _Camera.new()
	cam.reset(scene.a, scene.b)
	particles.clear()
	human = false
	crater_req = false
	input_used = false
	acc = 0.0
	var g = golden.get(name)
	hash_status = "pending (goldens at %s)" % ", ".join((g as Dictionary).keys()) if g is Dictionary else "n/a (no golden for this scene)"
	view.upload_heights(scene.terrain)
	view.sync(scene, cam)
	scene_frames = 0
	scene_time_s = 0.0
	scene_live_max = 0
	if mode == "demo":
		print("SCENE %s loaded" % name)


## One sim tick: player input at the tick boundary, the sim step, particle spawns from this tick's events and beams,
## then the camera (once per tick, after the sim).
func _sim_tick() -> void:
	var input_crater: bool = false
	if mode == "demo" and scene_name == "flight":
		var ix: float = float(_key(KEY_RIGHT) or _key(KEY_D)) - float(_key(KEY_LEFT) or _key(KEY_A))
		var iy: float = float(_key(KEY_UP) or _key(KEY_W)) - float(_key(KEY_DOWN) or _key(KEY_S))
		if ix != 0.0 or iy != 0.0:
			human = true
		if human:
			input_used = true
			scene.set_input(ix, iy)
		if crater_req:
			crater_req = false
			input_used = true
			scene.terrain.crater(scene.a.x, 120.0, 40.0)
			input_crater = true
	var t0: int = Time.get_ticks_usec()
	scene.step()
	var t1: int = Time.get_ticks_usec()
	particles.spawn_from(scene)
	if input_crater:
		particles.spawn_crater(scene.a.x, scene.terrain.ground_y(scene.a.x), scene.tick)
	var t2: int = Time.get_ticks_usec()
	cam.step(scene.a, scene.b)
	_sim_us += t1 - t0
	_part_us += t2 - t1
	_check_hash()


func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)


func _check_hash() -> void:
	var t: int = scene.tick
	var key: String = str(t)
	var g = golden.get(scene_name)
	var want: String = ""
	if g is Dictionary and (g as Dictionary).has(key):
		want = str(g[key])
	if t == HASH_TICK and mode == "bench":
		bench_hash = _Hash.sha256_hex(_Hash.state_vector(scene))
	if want == "" or input_used:
		return
	var h: String = bench_hash if (t == HASH_TICK and mode == "bench") else _Hash.sha256_hex(_Hash.state_vector(scene))
	hash_status = "%s@%d %s" % [scene_name, t, "MATCH" if h == want else "MISMATCH"]
	print("HASH %s@%d %s %s" % [scene_name, t, h, "MATCH" if h == want else "MISMATCH (golden " + want + ")"])


# ------------------------------------------------------------------------------------------------ frame loop

func _process(_delta: float) -> void:
	if quitting:
		return
	var now_us: int = Time.get_ticks_usec()
	if prev_start_us < 0:
		prev_start_us = now_us
	var frame_s: float = float(now_us - prev_start_us) / 1000000.0
	prev_start_us = now_us
	if mode == "bench":
		_bench_close_frame(now_us)
	# Fixed-step accumulator: the sim runs in real time at 60 Hz, at most MAX_STEPS steps per frame.
	acc += frame_s
	_sim_us = 0
	_part_us = 0
	var steps: int = 0
	while acc >= DT and steps < MAX_STEPS:
		_sim_tick()
		acc -= DT
		steps += 1
	if steps == MAX_STEPS and acc >= DT:
		if rec != null:
			if scene.tick > rec.warmup:
				rec.dropped_measured += int(acc / DT)
			else:
				rec.dropped_warmup += int(acc / DT)
			rec.max_steps_frames += 1
		acc = fmod(acc, DT)
	# Presentation: read the new state.
	var up_ms: float = view.upload_heights(scene.terrain)
	if steps > 0:
		view.sync(scene, cam)
	var now_tick: float = float(scene.tick) + clampf(acc / DT, 0.0, 0.999)
	var p_ms: float = particles.update_gpu(cam.x, now_tick) + float(_part_us) / 1000.0
	live_now = particles.live_count(now_tick)
	hud.set_seam(cam.screen_x(0.0), get_viewport().get_visible_rect().size.x)
	hud.tick_frame(frame_s, _hud_lines)
	if mode == "bench":
		_bench_open_frame(now_us, float(_sim_us) / 1000.0, up_ms, p_ms, steps)
	else:
		_demo_frame(frame_s)


func _hud_lines() -> String:
	var r: String = RenderingServer.get_current_rendering_method()
	return ("scene %s  tick %d  (%s)\nparticles live %d\nhash %s\ncamera x %.1f  view %.0f  flips %d%s\n%s | %s\n" +
		"1-6 scenes  H hud  WASD/arrows fly box a, C crater (flight)") % [
		scene_name, scene.tick, mode, live_now, hash_status, cam.x, cam.view_w, cam.flips,
		"  (flip pan)" if cam.flipping else "", r, _gpu_name()]


func _unhandled_input(event: InputEvent) -> void:
	if mode != "demo":
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var code: Key = k.physical_keycode
	if code >= KEY_1 and code <= KEY_6:
		_load_scene(SCENE_NAMES[int(code) - int(KEY_1)])
	elif code == KEY_H:
		hud.toggle()
	elif code == KEY_C and scene_name == "flight":
		crater_req = true
	elif code == KEY_ESCAPE:
		_quit(0)


func _demo_frame(frame_s: float) -> void:
	run_s += frame_s
	scene_frames += 1
	scene_time_s += frame_s
	scene_live_max = maxi(scene_live_max, live_now)
	if cycle_s > 0.0:
		cycle_acc += frame_s
		if cycle_acc >= cycle_s:
			cycle_acc = 0.0
			_demo_report()
			var idx: int = (SCENE_NAMES.find(scene_name) + 1) % SCENE_NAMES.size()
			_load_scene(SCENE_NAMES[idx])
	if inject.size() > 0:
		_inject_step(frame_s)
	if quit_after_s > 0.0 and run_s >= quit_after_s:
		_demo_report()
		print("DEMO quit after %.1f s" % run_s)
		_quit(0)


## --inject-keys 2,3,H,1,D,C: feeds real key events through Input.parse_input_event, one key per second (held for
## 0.5 s), so the demo's hotkey path (_unhandled_input and the polled flight keys) is exercised without a person.
var inject: PackedStringArray = []
var _inject_t: float = 0.0
var _inject_down: InputEventKey = null


func _inject_step(frame_s: float) -> void:
	_inject_t += frame_s
	if _inject_down != null and _inject_t >= 0.5:
		var up: InputEventKey = _inject_down.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
		_inject_down = null
	if _inject_down == null and _inject_t >= 1.0:
		_inject_t = 0.0
		var name: String = inject[0]
		inject.remove_at(0)
		var ev := InputEventKey.new()
		ev.physical_keycode = OS.find_keycode_from_string(name)
		ev.keycode = ev.physical_keycode
		ev.pressed = true
		Input.parse_input_event(ev)
		_inject_down = ev
		print("INJECT key %s -> scene=%s tick=%d hud=%s" % [name, scene_name, scene.tick, str(hud.visible)])


func _demo_report() -> void:
	print("DEMO scene=%s ticks=%d frames=%d avg_fps=%.0f live_max=%d cam.x=%.1f flips=%d input=%s a=(%.0f,%.0f) hash=%s" % [scene_name,
		scene.tick, scene_frames, float(scene_frames) / maxf(scene_time_s, 0.001), scene_live_max, cam.x, cam.flips,
		str(input_used), scene.a.x, scene.a.y, hash_status])


# ------------------------------------------------------------------------------------------------ bench

func _bench_setup() -> void:
	rec = _Bench.new()
	rec.warmup = int(opts.get("warmup", "180"))
	rec.measure = int(opts.get("measure", "1800"))
	if not is_web:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)


func _bench_close_frame(now_us: int) -> void:
	if cur_measured:
		rec.frame_ms.append(float(now_us - cur_start_us) / 1000.0)
		rec.last_end_us = now_us
		cur_measured = false


func _bench_open_frame(now_us: int, sim_ms: float, up_ms: float, p_ms: float, steps: int) -> void:
	var t: int = scene.tick
	if t > rec.end_tick():
		_bench_finish()
		return
	if rec.is_measured(t):
		if rec.first_start_us < 0:
			rec.first_start_us = now_us
		cur_measured = true
		cur_start_us = now_us
		rec.sim_ms.append(sim_ms)
		rec.upload_ms.append(up_ms)
		rec.particles_ms.append(p_ms)
		rec.live.append(float(live_now))
		rec.steps.append(steps)
		rec.gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid))


func _bench_finish() -> void:
	quitting = true
	if bench_hash == "":
		# Short smoke windows end before tick 1980: finish the sim (not rendered, not timed) to hash at 1980.
		bench_ff_from = scene.tick
		while scene.tick < HASH_TICK:
			scene.step()
		bench_hash = _Hash.sha256_hex(_Hash.state_vector(scene))
	var st: Dictionary = rec.stats()
	var g = golden.get(scene_name)
	var golden_hash: String = str(g[str(HASH_TICK)]) if g is Dictionary and (g as Dictionary).has(str(HASH_TICK)) else ""
	var notes: PackedStringArray = []
	notes.append("fixed-step 60 Hz accumulator in _process (max %d steps/frame); camera stepped once per tick after the sim" % MAX_STEPS)
	notes.append("particles: one MultiMesh of %d quads + stateless ballistic vertex shader, burst ring buffers in a 451x1 RGBA32F texture; live counts analytic from spawn ticks; overwrites %d" % [particles.INSTANCES, particles.overwrites])
	notes.append("terrain: 1100-column static grid, 1200x1 RF height texture (texelFetch), uploads %d" % view.uploads)
	notes.append("subMs averages every measured frame (most run no sim step); subMsStepFrames covers only frames that ran >= 1 step")
	notes.append("gpu ms: RenderingServer.viewport_get_measured_render_time_gpu (reported with a few frames of latency)")
	if st.subMs.gpu == null:
		notes.append("gpu ms unavailable on this renderer (the query returned 0)")
	if rec.dropped_warmup > 0 or rec.dropped_measured > 0:
		notes.append("step cap hit in %d frames: %d ticks dropped during warm-up, %d inside the measure window" % [rec.max_steps_frames, rec.dropped_warmup, rec.dropped_measured])
	if bench_ff_from >= 0:
		notes.append("measure window ended at tick %d; sim fast-forwarded (unrendered, untimed) from tick %d to %d for the hash" % [rec.end_tick(), bench_ff_from, HASH_TICK])
	if look != "baseline":
		notes.append("look=%s (glow and directional shadows on)" % look)
	var browser = null
	if is_web:
		browser = JavaScriptBridge.eval("navigator.userAgent", true)
	var vs = null if is_web else (DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
	var size: Vector2i = get_viewport().size
	var result: Dictionary = {
		"stack": "godot",
		"engineVersion": str(Engine.get_version_info().get("string", "")),
		"renderer": RenderingServer.get_current_rendering_method(),
		"renderingDriver": RenderingServer.get_current_rendering_driver_name(),
		"build": _build_kind(),
		"browser": browser,
		"gpu": _gpu_name(),
		"driver": _driver_name(),
		"cpu": OS.get_processor_name().strip_edges(),
		"os": OS.get_name() + " " + OS.get_version(),
		"width": size.x, "height": size.y, "vsync": vs,
		"scene": scene_name, "look": look,
		"warmupTicks": rec.warmup, "measureTicks": rec.measure,
		"frames": st.frames, "elapsedMs": st.elapsedMs, "frameMs": st.frameMs, "fps": st.fps,
		"subMs": st.subMs, "subMsStepFrames": st.subMsStepFrames, "particles": st.particles,
		"droppedTicksMeasured": rec.dropped_measured,
		"simTickFinal": HASH_TICK, "simHash": bench_hash, "goldenHash": golden_hash,
		"hashMatch": (bench_hash == golden_hash) if golden_hash != "" else null,
		"notes": "; ".join(notes),
		"frameTimesMs": st.frameTimesMs,
	}
	var text: String = JSON.stringify(result)
	if is_web:
		JavaScriptBridge.eval("window.__benchResult = " + text + ";", true)
	if opts.has("out"):
		_write_text(str(opts["out"]), JSON.stringify(result, "  ", false))
	print("BENCH renderer=%s driver=%s gpu=%s frames=%d avg=%.3fms p95=%.3fms p99=%.3fms fps=%.0f gpu=%s live_avg=%d hash=%s match=%s" % [
		result.renderer, result.renderingDriver, result.gpu, st.frames, st.frameMs.avg, st.frameMs.p95, st.frameMs.p99, st.fps,
		str(st.subMs.gpu), st.particles.liveAvg, bench_hash, str(result.hashMatch)])
	_quit(0 if result.hashMatch != false else 3)


# ------------------------------------------------------------------------------------------------ screenshot

func _run_shot() -> void:
	var at: int = int(opts.get("at", str(SHOT_AT.get(scene_name, 60))))
	while scene.tick < at:
		_sim_tick()
	view.upload_heights(scene.terrain)
	view.sync(scene, cam)
	particles.update_gpu(cam.x, float(scene.tick))
	live_now = particles.live_count(float(scene.tick))
	var w: float = get_viewport().get_visible_rect().size.x
	hud.set_seam(cam.screen_x(0.0), w)
	hud.force_text("screenshot  ", _hud_lines)
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var info: String = "SHOT scene=%s tick=%d size=%dx%d cam.x=%.2f view_w=%.1f seam_screen_x=%.4f live=%d" % [scene_name,
		scene.tick, img.get_width(), img.get_height(), cam.x, cam.view_w, cam.screen_x(0.0), live_now]
	if is_web:
		JavaScriptBridge.eval("window.__shotResult = " + JSON.stringify({"info": info, "scene": scene_name, "tick": scene.tick}) + ";", true)
		print(info)
		return
	var path: String = str(opts.get("screenshot", "")).replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err: int = img.save_png(path)
	print(info + " -> " + path + (" OK" if err == OK else " ERROR %d" % err))
	_quit(0 if err == OK else 1)


# ------------------------------------------------------------------------------------------------ simbench

func _run_simbench() -> void:
	var r: Dictionary = _Simbench.run(int(opts.get("reps", "5")), int(opts.get("ticks", "3600")))
	r["build"] = _build_kind()
	r["engineVersion"] = str(Engine.get_version_info().get("string", ""))
	var text: String = JSON.stringify(r)
	print("SIMBENCH " + text)
	if opts.has("out"):
		_write_text(str(opts["out"]), text)
	_quit(0)
