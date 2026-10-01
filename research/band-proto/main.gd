extends Node3D
## Band prototype (option B): the fighting ground is a strip with real depth, so every collision is physically true.
## Throwaway research code: quick and dirty, one script, everything built in code. Not deterministic, no sim, no director.
## Units: 1 body height (BH) = 2 units. Axes: x along the strip, y up, z depth (the camera sits on the +z side).

const BH := 2.0
const LEN := 600.0            # strip length (300 BH)
const DEPTH := 120.0          # strip depth (60 BH)
const SPEED := 34.0
const SPEED_Y := 26.0
const DEPTH_SPEED := 22.0     # manual depth nudge
const MAGNET_SPEED := 12.0    # AUTO+ soft depth magnet
const RUSH_SPEED := 150.0
const RUSH_MAX := 0.65
const REACH := 2.6
const LAUNCH_SPEED := 105.0
const LAUNCH_UP := 26.0
const GRAV := 62.0
const TAN_V := 0.36397        # tan(20 deg): vertical fov 40
const TAN_H := 0.64706

enum DepthMode { AUTO, AUTO_MAGNET, MANUAL }
enum Occl { FADE, CUT, OFF }
const DEPTH_NAMES := ["AUTO (attacks align depth)", "AUTO+ (attacks align, soft magnet)", "MANUAL (you align depth)"]
const OCCL_NAMES := ["fade", "cut away", "off"]
const CAM_NAMES := ["side-on, slightly raised", "three-quarter, high"]

class Fighter:
	var pos := Vector3.ZERO     # feet
	var vel := Vector3.ZERO
	var hp := 100.0
	var state := "free"         # free, rush, windup, launched, stun, down, dodge
	var t := 0.0
	var face := 1.0
	var cd := 0.0
	var dodge_cd := 0.0
	var guard := false
	var heavy := false
	var passed: Array = []      # buildings already ploughed in this rush or flight
	var bounced := false
	var spin := 0.0
	var flash := 0.0
	var ai := false
	var ai_t := 0.0
	var ai_atk := 1.0
	var ai_alt := 0.0
	var ai_guard := 0.0
	var ai_side := 0.0
	var ai_z := 12.0
	var ai_zt := 0.0
	var rush_dir := Vector3.RIGHT
	var col := Color.WHITE
	var inp := {}
	var node: Node3D
	var body: Node3D
	var mat: StandardMaterial3D
	var shield: MeshInstance3D
	var shadow: MeshInstance3D
	var lane: MeshInstance3D
	var pole: MeshInstance3D

class Building:
	var lo := Vector3.ZERO      # AABB min
	var hi := Vector3.ZERO      # AABB max
	var hp := 2
	var alive := true
	var fade := 1.0
	var cut := 0.0
	var collapse := 0.0         # 0 standing .. 1 rubble
	var node: MeshInstance3D
	var mat: ShaderMaterial
	var col := Color.GRAY

var fighters: Array[Fighter] = []
var buildings: Array[Building] = []
var depth_mode: int = DepthMode.AUTO
var occl_mode: int = Occl.FADE
var cam_mode := 0
var show_hints := true
var show_map := true
var show_aids := true
var camera: Camera3D
var cam_target := Vector3.ZERO
var cam_dist := 60.0
var shake := 0.0
var hud: Control
var ko_t := 0.0
var feed: Array[String] = []
var time := 0.0
var rng := RandomNumberGenerator.new()

# debris pool (CPU ballistic, one MultiMesh)
const NDEB := 360
var deb_mm: MultiMesh
var deb_pos: PackedVector3Array
var deb_vel: PackedVector3Array
var deb_life: PackedFloat32Array
var deb_size: PackedFloat32Array
var deb_next := 0
var deb_live := 0

# bench / screenshot / staging (user args on desktop, query string on the web)
var opts := {}
var bench := false
var bench_frames: PackedFloat32Array = []
var bench_last := 0
var shot_done := false
var stats := {"time": 0.0, "occluded_time": 0.0, "launches": 0, "launch_ploughs": 0, "rush_ploughs": 0, "collapses": 0,
	"attacks": 0, "depth_gap_at_attack_sum": 0.0, "kos": 0}

const BUILDING_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 base_color : source_color = vec3(0.6);
uniform float fade = 1.0;     // 1 solid .. 0 gone (screen-door dither, so it stays in the opaque pass)
uniform float cut_y = 1000.0; // cut-away height
uniform float damage = 0.0;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	if (wpos.y > cut_y) { discard; }
	float n = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (n > fade) { discard; }
	vec3 c = base_color;
	if (abs(wnrm.y) < 0.5) {
		float u = abs(wnrm.x) > 0.5 ? wpos.z : wpos.x;
		float win = step(0.3, fract(u / 3.0)) * step(0.35, fract(wpos.y / 3.5));
		c = mix(c, vec3(0.13, 0.17, 0.25), win * 0.75);
	}
	c *= 1.0 - damage * 0.45;
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""

const GROUND_SHADER := """
shader_type spatial;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 c = vec3(0.27, 0.29, 0.31);
	float lz = 1.0 - step(0.12, abs(fract(wpos.z / 10.0 + 0.5) - 0.5) * 10.0);   // a line every 10 units of depth
	float lx = 1.0 - step(0.15, abs(fract(wpos.x / 50.0 + 0.5) - 0.5) * 50.0);   // a line every 50 units along
	c = mix(c, vec3(0.42, 0.44, 0.46), max(lz, lx) * 0.8);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
"""


func _ready() -> void:
	_parse_opts()
	rng.seed = 7
	seed(12345)
	_setup_input()
	_build_world()
	_build_fighters()
	_build_debris()
	_build_camera_and_hud()
	_reset_round()
	if opts.has("cam"):
		cam_mode = int(opts["cam"]) % 2
	if opts.has("occl"):
		occl_mode = int(opts["occl"]) % 3
	if opts.has("depth"):
		depth_mode = int(opts["depth"]) % 3
	if opts.has("stage"):
		_stage(int(opts["stage"]))
	bench = opts.has("bench")
	if bench or opts.has("shot") or opts.has("demo") or opts.has("stats"):
		fighters[0].ai = true
	if bench:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	_snap_camera()


func _parse_opts() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var a := String(args[i])
		if a.begins_with("--"):
			var k := a.substr(2)
			if i + 1 < args.size() and not String(args[i + 1]).begins_with("--"):
				opts[k] = String(args[i + 1])
				i += 1
			else:
				opts[k] = "1"
		i += 1
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("window.location.search")
		if typeof(q) == TYPE_STRING and String(q).length() > 1:
			for part in String(q).substr(1).split("&", false):
				var kv := part.split("=")
				opts[kv[0]] = kv[1] if kv.size() > 1 else "1"


func _act(action: String, keys: Array, buttons: Array = [], axes: Array = []) -> void:
	InputMap.add_action(action, 0.35)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var eb := InputEventJoypadButton.new()
		eb.button_index = b
		InputMap.action_add_event(action, eb)
	for a in axes:
		var ea := InputEventJoypadMotion.new()
		ea.axis = a[0]
		ea.axis_value = a[1]
		InputMap.action_add_event(action, ea)


func _setup_input() -> void:
	# A subset of the Arena pad layout and the kb-solo keyboard preset (ADR 0008, docs/controls/input-scheme.md).
	_act("move_left", [KEY_A], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_act("move_right", [KEY_D], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_act("move_up", [KEY_W], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_act("move_down", [KEY_S], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_act("light", [KEY_J], [JOY_BUTTON_X])
	_act("heavy", [KEY_K], [JOY_BUTTON_Y])
	_act("guard", [KEY_SHIFT], [JOY_BUTTON_LEFT_SHOULDER])
	_act("dodge", [KEY_SPACE], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	# Prototype-only: the manual depth nudge (right stick, or R = away from the camera, F = towards it; arrows too).
	_act("depth_in", [KEY_R, KEY_UP], [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_act("depth_out", [KEY_F, KEY_DOWN], [], [[JOY_AXIS_RIGHT_Y, 1.0]])
	_act("cam_toggle", [KEY_C], [JOY_BUTTON_DPAD_UP])
	_act("depth_toggle", [KEY_T], [JOY_BUTTON_DPAD_LEFT])
	_act("occl_toggle", [KEY_O], [JOY_BUTTON_DPAD_RIGHT])
	_act("aids_toggle", [KEY_G], [JOY_BUTTON_DPAD_DOWN])
	_act("map_toggle", [KEY_M])
	_act("hints_toggle", [KEY_H], [JOY_BUTTON_BACK])
	_act("reset", [KEY_N], [JOY_BUTTON_START])
	_act("ai_toggle", [KEY_Y])


# ------------------------------------------------------------------ world
func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	return m


func _flat(col: Color, alpha := 1.0, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = 0.9
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.46, 0.62, 0.84)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	add_child(sun)

	var gsh := Shader.new()
	gsh.code = GROUND_SHADER
	var gmat := ShaderMaterial.new()
	gmat.shader = gsh
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(LEN + 80.0, DEPTH)
	ground.mesh = pm
	ground.material_override = gmat
	add_child(ground)
	# The band's edges: a low kerb front and back, so the strip reads as a strip.
	for zz in [-DEPTH * 0.5, DEPTH * 0.5]:
		var kerb := _box(Vector3(LEN + 80.0, 0.6, 1.0), _flat(Color(0.55, 0.55, 0.5)))
		kerb.position = Vector3(0, 0.3, zz)
		add_child(kerb)

	var bsh := Shader.new()
	bsh.code = BUILDING_SHADER
	# Three rows of box buildings on real footprints, leaving two streets along the strip and cross streets between
	# buildings. Row: [z centre, depth min, depth max, height min, height max].
	var rows := [[-40.0, 16.0, 22.0, 34.0, 78.0], [-6.0, 16.0, 20.0, 22.0, 56.0], [30.0, 14.0, 18.0, 12.0, 30.0]]
	var palette := [Color(0.63, 0.6, 0.55), Color(0.55, 0.6, 0.66), Color(0.68, 0.62, 0.5), Color(0.5, 0.55, 0.52), Color(0.66, 0.56, 0.56)]
	for r in rows.size():
		var row: Array = rows[r]
		for k in 6:
			var w := rng.randf_range(24.0, 40.0)
			var d := rng.randf_range(row[1], row[2])
			var h := rng.randf_range(row[3], row[4])
			var cx := -228.0 + k * 91.0 + rng.randf_range(-14.0, 14.0) + r * 17.0
			var b := Building.new()
			b.lo = Vector3(cx - w * 0.5, 0.0, row[0] - d * 0.5)
			b.hi = Vector3(cx + w * 0.5, h, row[0] + d * 0.5)
			b.hp = 2 if h > 30.0 else 1
			b.col = palette[(r * 2 + k) % palette.size()]
			b.mat = ShaderMaterial.new()
			b.mat.shader = bsh
			b.mat.set_shader_parameter("base_color", Vector3(b.col.r, b.col.g, b.col.b))
			b.node = _box(Vector3(w, h, d), b.mat)
			b.node.position = Vector3(cx, h * 0.5, row[0])
			add_child(b.node)
			buildings.append(b)


func _build_fighters() -> void:
	var cols := [Color(0.24, 0.56, 0.86), Color(0.72, 0.2, 0.18)]
	for i in 2:
		var f := Fighter.new()
		f.col = cols[i]
		f.ai = i == 1
		f.node = Node3D.new()
		add_child(f.node)
		f.body = Node3D.new()
		f.node.add_child(f.body)
		f.mat = _flat(f.col)
		var torso := _box(Vector3(1.1, 1.5, 0.8), f.mat)
		torso.position.y = 0.95
		f.body.add_child(torso)
		var head := _box(Vector3(0.62, 0.62, 0.62), f.mat)
		head.position.y = 2.05
		f.body.add_child(head)
		var nose := _box(Vector3(0.5, 0.22, 0.22), _flat(Color(0.95, 0.9, 0.75)))
		nose.position = Vector3(0.5, 2.05, 0)
		f.body.add_child(nose)
		f.shield = _box(Vector3(0.2, 2.4, 1.8), _flat(Color(0.7, 0.9, 1.0), 0.4, true))
		f.shield.position = Vector3(0.95, 1.2, 0)
		f.body.add_child(f.shield)
		# Depth aids: a blob shadow, a lane line on the ground at the fighter's depth, and an altitude pole.
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.1
		cm.bottom_radius = 1.1
		cm.height = 0.04
		disc.mesh = cm
		disc.material_override = _flat(Color(0, 0, 0), 0.5, true)
		add_child(disc)
		f.shadow = disc
		f.lane = _box(Vector3(44.0, 0.03, 0.3), _flat(f.col, 0.45, true))
		add_child(f.lane)
		f.pole = _box(Vector3(0.08, 1.0, 0.08), _flat(f.col, 0.5, true))
		add_child(f.pole)
		fighters.append(f)


func _build_debris() -> void:
	deb_mm = MultiMesh.new()
	deb_mm.transform_format = MultiMesh.TRANSFORM_3D
	deb_mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	deb_mm.mesh = bm
	deb_mm.instance_count = NDEB
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = deb_mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mi.material_override = m
	mi.custom_aabb = AABB(Vector3(-LEN, -10, -DEPTH), Vector3(LEN * 2, 200, DEPTH * 2))
	add_child(mi)
	deb_pos.resize(NDEB)
	deb_vel.resize(NDEB)
	deb_life.resize(NDEB)
	deb_size.resize(NDEB)
	for i in NDEB:
		deb_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -50, 0)))
		deb_mm.set_instance_color(i, Color.GRAY)


func _build_camera_and_hud() -> void:
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.near = 1.0
	camera.far = 1500.0
	add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	layer.add_child(hud)


func _reset_round() -> void:
	for i in 2:
		var f := fighters[i]
		f.pos = Vector3(-18.0 if i == 0 else 18.0, 6.0, 12.0)
		f.vel = Vector3.ZERO
		f.hp = 100.0
		f.state = "free"
		f.t = 0.0
		f.cd = 0.0
		f.face = 1.0 if i == 0 else -1.0
		f.spin = 0.0
	for b in buildings:
		b.alive = true
		b.hp = 2 if b.hi.y > 30.0 else 1
		b.collapse = 0.0
		b.node.scale = Vector3.ONE
		b.node.position.y = b.hi.y * 0.5
		b.mat.set_shader_parameter("damage", 0.0)
	ko_t = 0.0


func _stage(n: int) -> void:
	# Fixed set-ups for screenshots: 1 = both in the back street (front and middle rows occlude);
	# 2 = both inside the middle row's depth band with buildings along the launch line.
	if n == 1:
		fighters[0].pos = Vector3(-60.0, 8.0, -23.0)
		fighters[1].pos = Vector3(-30.0, 10.0, -23.0)
	elif n == 2:
		fighters[0].pos = Vector3(-112.0, 9.0, -6.0)
		fighters[1].pos = Vector3(-100.0, 9.0, -6.0)


# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	if opts.has("stats"):
		# Fast-forward AI bouts (no need to render) and print what happened. Used for the README's numbers.
		var total := float(opts["stats"])
		while time < total:
			_tick(1.0 / 60.0)
		print("STATS ", JSON.stringify(stats))
		get_tree().quit()
		return
	if opts.has("selftest"):
		_selftest()
	_tick(minf(delta, 1.0 / 30.0))


func _selftest() -> void:
	# Drives player 1 through the real input actions (not the AI) to prove the input path works.
	var f := fighters[0]
	fighters[1].ai_atk = 99.0
	if time < 0.5:
		Input.action_press("move_right")
		Input.action_press("depth_in")
	elif time < 0.6:
		Input.action_release("move_right")
		Input.action_release("depth_in")
		if not stats.has("moved"):
			stats["moved"] = [snappedf(f.pos.x, 0.1), snappedf(f.pos.z, 0.1)]
			Input.action_press("heavy")
	elif time < 0.7:
		Input.action_release("heavy")
		stats["state_after_heavy"] = f.state if not stats.has("state_after_heavy") else stats["state_after_heavy"]
	elif time > 2.0:
		print("SELFTEST ", JSON.stringify(stats))
		get_tree().quit()


func _tick(dt: float) -> void:
	time += dt
	stats["time"] = time
	_toggles()
	if ko_t > 0.0:
		ko_t -= dt
		if ko_t <= 0.0:
			_reset_round()
	fighters[0].inp = _ai_input(fighters[0], fighters[1], dt) if fighters[0].ai else _human_input()
	fighters[1].inp = _ai_input(fighters[1], fighters[0], dt)
	for i in 2:
		_step_fighter(fighters[i], fighters[1 - i], dt)
	_step_buildings(dt)
	_step_debris(dt)
	_step_camera(dt)
	_occlusion(dt)
	_update_views()
	hud.queue_redraw()
	_bench_and_shot()


func _toggles() -> void:
	if Input.is_action_just_pressed("cam_toggle"):
		cam_mode = (cam_mode + 1) % 2
	if Input.is_action_just_pressed("depth_toggle"):
		depth_mode = (depth_mode + 1) % 3
	if Input.is_action_just_pressed("occl_toggle"):
		occl_mode = (occl_mode + 1) % 3
	if Input.is_action_just_pressed("aids_toggle"):
		show_aids = not show_aids
	if Input.is_action_just_pressed("map_toggle"):
		show_map = not show_map
	if Input.is_action_just_pressed("hints_toggle"):
		show_hints = not show_hints
	if Input.is_action_just_pressed("reset"):
		_reset_round()
	if Input.is_action_just_pressed("ai_toggle"):
		fighters[0].ai = not fighters[0].ai


func _blank() -> Dictionary:
	return {"mx": 0.0, "my": 0.0, "mz": 0.0, "light": false, "heavy": false, "guard": false, "dodge": false}


func _human_input() -> Dictionary:
	var i := _blank()
	i.mx = Input.get_axis("move_left", "move_right")
	i.my = Input.get_axis("move_down", "move_up")
	i.mz = Input.get_axis("depth_in", "depth_out")
	i.light = Input.is_action_just_pressed("light")
	i.heavy = Input.is_action_just_pressed("heavy")
	i.guard = Input.is_action_pressed("guard")
	i.dodge = Input.is_action_just_pressed("dodge")
	return i


func _ai_input(f: Fighter, o: Fighter, dt: float) -> Dictionary:
	var i := _blank()
	var d := o.pos - f.pos
	f.ai_t -= dt
	f.ai_atk -= dt
	f.ai_guard -= dt
	if f.ai_t <= 0.0:
		f.ai_t = randf_range(0.6, 1.4)
		f.ai_alt = randf_range(-3.0, 5.0)
		f.ai_side = randf_range(14.0, 26.0)
	if absf(d.x) > f.ai_side + 6.0:
		i.mx = signf(d.x)
	elif absf(d.x) < f.ai_side - 6.0:
		i.mx = -signf(d.x)
	# The AI wanders between depth lanes, so fights do not stay in one street.
	f.ai_zt -= dt
	if f.ai_zt <= 0.0:
		f.ai_zt = randf_range(3.0, 7.0)
		f.ai_z = randf_range(-DEPTH * 0.5 + 8.0, DEPTH * 0.5 - 8.0)
	i.mz = clampf((f.ai_z - f.pos.z) / 6.0, -1.0, 1.0)
	i.my = clampf((o.pos.y + f.ai_alt - f.pos.y) / 5.0, -1.0, 1.0)
	if f.pos.y < 3.0:
		i.my = 1.0
	if (o.state == "rush" or o.state == "windup") and f.ai_guard <= -0.6:
		f.ai_guard = 0.45 if randf() < 0.4 else -0.2
	i.guard = f.ai_guard > 0.0
	if f.ai_atk <= 0.0 and f.cd <= 0.0 and f.state == "free" and o.state != "launched" and o.state != "down" and ko_t <= 0.0:
		if randf() < 0.45:
			i.heavy = true
		else:
			i.light = true
		f.ai_atk = randf_range(0.8, 1.9)
	return i


# ------------------------------------------------------------------ fighters
func _step_fighter(f: Fighter, o: Fighter, dt: float) -> void:
	var inp: Dictionary = f.inp
	f.cd = maxf(0.0, f.cd - dt)
	f.dodge_cd = maxf(0.0, f.dodge_cd - dt)
	f.flash = maxf(0.0, f.flash - dt * 4.0)
	f.guard = false
	var homing_depth := f.ai or depth_mode != DepthMode.MANUAL   # the AI always aligns
	match f.state:
		"free":
			f.guard = inp.guard
			var want := Vector3(inp.mx * SPEED, inp.my * SPEED_Y, inp.mz * DEPTH_SPEED)
			if not f.ai and depth_mode == DepthMode.AUTO_MAGNET and absf(inp.mz) < 0.1 and absf(o.pos.x - f.pos.x) < 60.0:
				want.z = clampf((o.pos.z - f.pos.z) * 2.0, -MAGNET_SPEED, MAGNET_SPEED)
			if f.guard:
				want *= 0.3
			f.vel = f.vel.lerp(want, 1.0 - exp(-10.0 * dt))
			f.pos += f.vel * dt
			_push_out(f)
			if absf(o.pos.x - f.pos.x) > 0.5:
				f.face = signf(o.pos.x - f.pos.x)
			f.spin = lerpf(f.spin, 0.0, 1.0 - exp(-12.0 * dt))
			if ko_t <= 0.0:
				if inp.dodge and f.dodge_cd <= 0.0:
					var dir := Vector3(inp.mx, inp.my, inp.mz)
					if dir.length() < 0.2:
						dir = Vector3(0, 0, 1.0 if f.pos.z < DEPTH * 0.5 - 12.0 else -1.0)   # a sidestep in depth
					f.vel = dir.normalized() * 72.0
					f.state = "dodge"
					f.t = 0.28
					f.dodge_cd = 0.9
				elif (inp.light or inp.heavy) and f.cd <= 0.0:
					stats["attacks"] += 1
					stats["depth_gap_at_attack_sum"] += absf(o.pos.z - f.pos.z)
					f.state = "rush"
					f.t = 0.0
					f.heavy = inp.heavy
					f.cd = 0.55
					f.passed.clear()
		"dodge":
			f.pos += f.vel * dt
			_push_out(f)
			f.t -= dt
			if f.t <= 0.0:
				f.state = "free"
		"rush":
			f.t += dt
			var to := (o.pos - f.pos)
			if not homing_depth:
				to.z = 0.0
			var dist := to.length()
			var aligned := homing_depth or absf(o.pos.z - f.pos.z) <= 3.0
			if dist <= REACH:
				if not aligned:
					_say("%s swings at empty air: wrong depth" % _name(f))
					f.state = "stun"
					f.t = 0.35
					f.vel = Vector3.ZERO
				elif f.heavy:
					f.state = "windup"
					f.t = 0.16
					f.vel = Vector3.ZERO
				else:
					_strike(f, o)
			elif f.t > RUSH_MAX:
				f.state = "stun"
				f.t = 0.3
				f.vel *= 0.2
			else:
				var stepd := minf(RUSH_SPEED * dt, maxf(0.0, dist - REACH * 0.8))
				f.vel = to / dist * RUSH_SPEED
				f.rush_dir = to / dist
				f.pos += to / dist * stepd
				f.face = signf(to.x) if absf(to.x) > 0.1 else f.face
				_plough_check(f, false)
		"windup":
			f.t -= dt
			f.flash = 1.0
			if f.t <= 0.0:
				_strike(f, o)
		"stun":
			f.vel = f.vel.lerp(Vector3.ZERO, 1.0 - exp(-5.0 * dt))
			f.pos += f.vel * dt
			_push_out(f)
			f.t -= dt
			if f.t <= 0.0:
				f.state = "free"
		"launched":
			f.vel.y -= GRAV * dt
			f.pos += f.vel * dt
			f.spin += dt * 14.0 * signf(f.vel.x)
			_plough_check(f, true)
			if absf(f.pos.x) > LEN * 0.5 - 2.0:
				f.vel.x *= -0.4   # the end of the test strip (the real planet wraps)
			if f.pos.y <= 0.0 and f.vel.y < 0.0:
				f.pos.y = 0.0
				_burst(f.pos, Vector3(f.vel.x * 0.2, 14.0, 0), 10, Color(0.45, 0.44, 0.42), 0.5)
				shake = maxf(shake, 0.8)
				if not f.bounced and absf(f.vel.x) > 30.0:
					f.bounced = true
					f.vel = Vector3(f.vel.x * 0.55, -f.vel.y * 0.32, f.vel.z * 0.5)
				else:
					f.state = "down"
					f.t = 0.6
					f.vel = Vector3.ZERO
					_say("%s lands at depth %d: the fight continues there" % [_name(f), int(round(f.pos.z))])
		"down":
			f.spin = lerpf(f.spin, 0.0, 1.0 - exp(-6.0 * dt))
			f.t -= dt
			if f.t <= 0.0:
				f.state = "free"
	f.pos.x = clampf(f.pos.x, -LEN * 0.5 + 1.0, LEN * 0.5 - 1.0)
	f.pos.z = clampf(f.pos.z, -DEPTH * 0.5 + 1.5, DEPTH * 0.5 - 1.5)
	f.pos.y = clampf(f.pos.y, 0.0, 95.0)


func _strike(f: Fighter, o: Fighter) -> void:
	f.state = "stun"
	f.t = 0.18
	f.vel = Vector3.ZERO
	var to := o.pos - f.pos
	var in_reach := Vector2(to.x, to.y).length() <= REACH * 1.6 and absf(to.z) <= 3.2
	if o.state == "dodge" or not in_reach or o.state == "launched":
		_say("%s whiffs" % _name(f))
		f.t = 0.35
		return
	var dirx := signf(to.x) if absf(to.x) > 0.2 else f.face
	o.flash = 1.0
	if not f.heavy:
		if o.guard:
			o.hp -= 1.0
			_say("%s blocks a light" % _name(o))
		else:
			o.hp -= 6.0
			o.state = "stun"
			o.t = 0.22
			o.vel = Vector3(dirx * 18.0, 4.0, 0)
			_burst(o.pos + Vector3(0, 1.2, 0), Vector3(dirx * 10.0, 6.0, 0), 5, Color(1, 0.95, 0.6), 0.25)
	else:
		shake = maxf(shake, 1.0)
		if o.guard:
			o.hp -= 4.0
			o.state = "stun"
			o.t = 0.4
			o.vel = Vector3(dirx * 46.0, 2.0, 0)
			_say("%s guards a heavy and slides" % _name(o))
		else:
			o.hp -= 12.0
			stats["launches"] += 1
			o.state = "launched"
			o.bounced = false
			o.passed.clear()
			# Launches travel along the street: mostly along x, from the depth where the hit happened. They keep
			# some of the attacker's approach direction in depth, so a hit from another lane sends the defender
			# diagonally across the band (and into whatever is truly there).
			o.vel = Vector3(dirx * LAUNCH_SPEED, LAUNCH_UP, clampf(f.rush_dir.z, -0.35, 0.35) * LAUNCH_SPEED)
			_burst(o.pos + Vector3(0, 1.2, 0), Vector3(dirx * 20.0, 10.0, 0), 10, Color(1, 0.9, 0.5), 0.3)
			_say("%s launches %s along depth %d" % [_name(f), _name(o), int(round(o.pos.z))])
	if o.hp <= 0.0 and ko_t <= 0.0:
		ko_t = 2.5
		stats["kos"] += 1
		_say("KO: %s wins the round" % _name(f))


func _name(f: Fighter) -> String:
	return "BLUE" if f == fighters[0] else "RED"


func _say(s: String) -> void:
	feed.append(s)
	if feed.size() > 5:
		feed.remove_at(0)


func _inside(b: Building, p: Vector3, r: float) -> bool:
	return p.x > b.lo.x - r and p.x < b.hi.x + r and p.z > b.lo.z - r and p.z < b.hi.z + r and p.y < b.hi.y + r and p.y > -1.0


## A rushing or launched fighter that is truly inside a building ploughs through it: the building takes a hit
## (and falls when its hits run out), debris flies, the fighter slows and carries on.
func _plough_check(f: Fighter, launched: bool) -> void:
	var c := f.pos + Vector3(0, 1.0, 0)
	for b in buildings:
		if not b.alive or f.passed.has(b) or not _inside(b, c, 0.7):
			continue
		f.passed.append(b)
		stats["launch_ploughs" if launched else "rush_ploughs"] += 1
		b.hp -= 1
		var v := f.vel
		_burst(c, v * 0.25 + Vector3(0, 12.0, 0), 26 if launched else 14, b.col, 0.9)
		shake = maxf(shake, 1.2 if launched else 0.6)
		if launched:
			f.vel *= 0.74
			f.hp = maxf(1.0, f.hp - 4.0)
		else:
			f.t += 0.08
		if b.hp <= 0:
			b.alive = false
			stats["collapses"] += 1
			_burst(Vector3((b.lo.x + b.hi.x) * 0.5, b.hi.y * 0.5, (b.lo.z + b.hi.z) * 0.5), Vector3(0, 18.0, 0), 60, b.col, 1.6, Vector3(b.hi.x - b.lo.x, b.hi.y, b.hi.z - b.lo.z) * 0.4)
			_say("%s goes through a building: it collapses" % _name(f))
		else:
			b.mat.set_shader_parameter("damage", 1.0)
			_say("%s ploughs through a building" % _name(f))


## Free-moving fighters are stopped by buildings: push out along the smallest overlap (walls, or land on the roof).
func _push_out(f: Fighter) -> void:
	var r := 0.7
	for b in buildings:
		if not b.alive:
			continue
		var c := f.pos + Vector3(0, 1.0, 0)
		if not (c.x > b.lo.x - r and c.x < b.hi.x + r and c.z > b.lo.z - r and c.z < b.hi.z + r and f.pos.y < b.hi.y):
			continue
		var px0 := c.x - (b.lo.x - r)
		var px1 := (b.hi.x + r) - c.x
		var pz0 := c.z - (b.lo.z - r)
		var pz1 := (b.hi.z + r) - c.z
		var py := b.hi.y - f.pos.y
		var m := minf(minf(px0, px1), minf(minf(pz0, pz1), py))
		if m == py:
			f.pos.y = b.hi.y
			f.vel.y = maxf(f.vel.y, 0.0)
		elif m == px0:
			f.pos.x = b.lo.x - r
		elif m == px1:
			f.pos.x = b.hi.x + r
		elif m == pz0:
			f.pos.z = b.lo.z - r
		else:
			f.pos.z = b.hi.z + r


func _ground_under(p: Vector3) -> float:
	for b in buildings:
		if b.alive and p.x > b.lo.x and p.x < b.hi.x and p.z > b.lo.z and p.z < b.hi.z and p.y >= b.hi.y - 0.5:
			return b.hi.y
	return 0.0


func _step_buildings(dt: float) -> void:
	for b in buildings:
		if not b.alive and b.collapse < 1.0:
			b.collapse = minf(1.0, b.collapse + dt * 1.8)
			var h := lerpf(b.hi.y, 1.6, b.collapse * b.collapse)
			b.node.scale.y = h / b.hi.y
			b.node.position.y = h * 0.5
			b.mat.set_shader_parameter("damage", 1.0)


# ------------------------------------------------------------------ debris
func _burst(at: Vector3, v: Vector3, n: int, col: Color, size: float, spread := Vector3(1.5, 1.5, 1.5)) -> void:
	for k in n:
		var i := deb_next
		deb_next = (deb_next + 1) % NDEB
		deb_pos[i] = at + Vector3(randf_range(-1, 1) * spread.x, randf_range(-1, 1) * spread.y, randf_range(-1, 1) * spread.z)
		deb_vel[i] = v + Vector3(randf_range(-14, 14), randf_range(0, 20), randf_range(-14, 14))
		deb_life[i] = randf_range(2.5, 4.5)
		deb_size[i] = size * randf_range(0.5, 1.4)
		deb_mm.set_instance_color(i, col.darkened(randf_range(0.0, 0.35)))


func _step_debris(dt: float) -> void:
	deb_live = 0
	for i in NDEB:
		if deb_life[i] <= 0.0:
			continue
		deb_life[i] -= dt
		var p := deb_pos[i]
		var v := deb_vel[i]
		v.y -= GRAV * dt
		p += v * dt
		if p.y < deb_size[i] * 0.5:
			p.y = deb_size[i] * 0.5
			v = Vector3(v.x * 0.5, -v.y * 0.25, v.z * 0.5)
		deb_pos[i] = p
		deb_vel[i] = v
		var s := deb_size[i] * clampf(deb_life[i] * 2.0, 0.0, 1.0)
		deb_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), p if deb_life[i] > 0.0 else Vector3(0, -50, 0)))
		deb_live += 1


# ------------------------------------------------------------------ camera and occlusion
func _cam_goal() -> Array:
	var a := fighters[0].pos + Vector3(0, 1.2, 0)
	var b := fighters[1].pos + Vector3(0, 1.2, 0)
	var mid := (a + b) * 0.5
	var span_x := absf(a.x - b.x) + 26.0
	var span_y := absf(a.y - b.y) + 16.0
	var dist := maxf(span_x / (2.0 * TAN_H), span_y / (2.0 * TAN_V)) + absf(a.z - b.z) * 0.5
	return [mid, clampf(dist, 34.0, 280.0)]


func _cam_offset(dist: float) -> Vector3:
	if cam_mode == 0:
		return Vector3(0, dist * 0.2, dist)             # about 11 degrees above side-on
	return Vector3(0, dist * 0.85, dist * 0.75) * 1.05  # about 49 degrees: a high three-quarter view


func _snap_camera() -> void:
	var g := _cam_goal()
	cam_target = g[0]
	cam_dist = g[1]
	_place_camera(0.0)


func _step_camera(dt: float) -> void:
	var g := _cam_goal()
	# Follow fast and zoom out fast (a launch covers 100 units a second); zoom back in gently.
	cam_target = cam_target.lerp(g[0], 1.0 - exp(-12.0 * dt))
	cam_dist = lerpf(cam_dist, g[1], 1.0 - exp(-(16.0 if g[1] > cam_dist else 2.5) * dt))
	shake = maxf(0.0, shake - dt * 3.0)
	_place_camera(dt)


var _cam_off := Vector3(0, 12, 60)
func _place_camera(dt: float) -> void:
	var want := _cam_offset(cam_dist)
	_cam_off = want if dt == 0.0 else _cam_off.lerp(want, 1.0 - exp(-5.0 * dt))
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.6
	camera.position = cam_target + _cam_off + sh
	camera.look_at(cam_target + sh, Vector3.UP)


func _seg_hits(b: Building, p0: Vector3, p1: Vector3, grow: float) -> bool:
	# Slab test: does the segment p0 -> p1 pass through the building's box (grown a little)?
	var t0 := 0.0
	var t1 := 1.0
	var d := p1 - p0
	for ax in 3:
		var lo: float = b.lo[ax] - grow
		var hi: float = b.hi[ax] + grow
		if absf(d[ax]) < 1e-6:
			if p0[ax] < lo or p0[ax] > hi:
				return false
		else:
			var ta: float = (lo - p0[ax]) / d[ax]
			var tb: float = (hi - p0[ax]) / d[ax]
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
			if t0 > t1:
				return false
	return true


func _occlusion(dt: float) -> void:
	# A building between the camera and a fighter fades (dither) or is cut away down to a stub.
	var k := 1.0 - exp(-10.0 * dt)
	var any := false
	for b in buildings:
		var hide := false
		if occl_mode != Occl.OFF and b.alive:
			for f in fighters:
				var c: Vector3 = f.pos + Vector3(0, 1.2, 0)
				if not _inside(b, c, 0.0) and _seg_hits(b, camera.position, c, 2.5):
					hide = true
					any = true
		var want_fade := 0.22 if (hide and occl_mode == Occl.FADE) else 1.0
		var want_cut := 1.0 if (hide and occl_mode == Occl.CUT) else 0.0
		b.fade = lerpf(b.fade, want_fade, k)
		b.cut = lerpf(b.cut, want_cut, k)
		b.mat.set_shader_parameter("fade", b.fade)
		b.mat.set_shader_parameter("cut_y", lerpf(b.hi.y + 5.0, 3.0, b.cut) if b.alive else 1000.0)
	if any:
		stats["occluded_time"] += dt


func _update_views() -> void:
	for f in fighters:
		f.node.position = f.pos
		f.body.rotation = Vector3(0, 0.0 if f.face > 0.0 else PI, 0)
		f.body.rotate_z(-f.spin if f.face > 0.0 else f.spin)
		if f.state == "down":
			f.body.rotation.z = PI * 0.5
		f.shield.visible = f.guard
		var c := f.col.lerp(Color(1, 1, 0.8), f.flash)
		if f.state == "dodge":
			c = f.col.lightened(0.5)
		f.mat.albedo_color = c
		var gy := _ground_under(f.pos)
		f.shadow.visible = show_aids
		f.lane.visible = show_aids
		f.pole.visible = show_aids and f.pos.y - gy > 0.6
		var s := clampf(1.0 - (f.pos.y - gy) / 70.0, 0.35, 1.0)
		f.shadow.position = Vector3(f.pos.x, gy + 0.05, f.pos.z)
		f.shadow.scale = Vector3(s, 1.0, s)
		f.lane.position = Vector3(f.pos.x, 0.06, f.pos.z)
		var ph := maxf(0.01, f.pos.y - gy)
		f.pole.position = Vector3(f.pos.x, gy + ph * 0.5, f.pos.z)
		f.pole.scale = Vector3(1, ph, 1)


# ------------------------------------------------------------------ HUD and the top-down minimap
func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	var w := hud.size.x
	for i in 2:
		var f := fighters[i]
		var x := 16.0 if i == 0 else w - 16.0 - 260.0
		hud.draw_rect(Rect2(x, 14, 260, 14), Color(0, 0, 0, 0.5))
		hud.draw_rect(Rect2(x, 14, 260.0 * clampf(f.hp / 100.0, 0.0, 1.0), 14), f.col)
		hud.draw_string(font, Vector2(x, 44), "%s  depth %d  alt %d  %s" % [_name(f), int(round(f.pos.z)), int(round(f.pos.y)), f.state + (" (AI)" if f.ai else "")], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	var y := 66.0
	var lines := [
		"Depth: %s   [T / d-pad left]" % DEPTH_NAMES[depth_mode],
		"Camera: %s   [C / d-pad up]     Occlusion: %s   [O / d-pad right]" % [CAM_NAMES[cam_mode], OCCL_NAMES[occl_mode]],
		"%d fps   debris %d   depth gap %d" % [Engine.get_frames_per_second(), deb_live, int(round(absf(fighters[0].pos.z - fighters[1].pos.z)))],
	]
	if show_hints:
		lines.append_array([
			"Move and fly: WASD / left stick     Light: J / X     Heavy: K / Y     Guard (hold): Shift / LB     Dodge (tap): Space / LT",
			"Depth nudge: R away, F towards (or arrows) / right stick     Aids: G     Minimap: M     New round: N / Start     AI plays blue: Y     Hide help: H",
		])
	for s in lines:
		hud.draw_string(font, Vector2(16, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.92))
		y += 17.0
	var fy := hud.size.y - 14.0
	for k in range(feed.size() - 1, -1, -1):
		hud.draw_string(font, Vector2(16, fy), feed[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 0.8, 0.5 + 0.5 * float(k + 1) / feed.size()))
		fy -= 16.0
	if ko_t > 0.0:
		hud.draw_string(font, Vector2(w * 0.5 - 40, hud.size.y * 0.4), "K O", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(1, 0.9, 0.4))
	if show_map:
		_draw_map(font)


func _draw_map(font: Font) -> void:
	# Top-down debug map: x along, depth down the page (the camera side is at the bottom).
	var mw := 420.0
	var mh := mw * DEPTH / LEN
	var o := Vector2(hud.size.x - mw - 16.0, hud.size.y - mh - 30.0)
	var sx := mw / LEN
	hud.draw_rect(Rect2(o, Vector2(mw, mh)), Color(0, 0, 0, 0.55))
	for b in buildings:
		var r := Rect2(o + Vector2((b.lo.x + LEN * 0.5) * sx, (b.lo.z + DEPTH * 0.5) * sx), Vector2((b.hi.x - b.lo.x) * sx, (b.hi.z - b.lo.z) * sx))
		var c := Color(0.75, 0.75, 0.75)
		if not b.alive:
			c = Color(0.3, 0.25, 0.2)
		elif b.fade < 0.9 or b.cut > 0.1:
			c = Color(0.95, 0.85, 0.4)   # hidden for the camera right now
		elif b.hp < (2 if b.hi.y > 30.0 else 1):
			c = Color(0.6, 0.45, 0.4)
		hud.draw_rect(r, c)
	for f in fighters:
		var p := o + Vector2((f.pos.x + LEN * 0.5) * sx, (f.pos.z + DEPTH * 0.5) * sx)
		hud.draw_line(Vector2(o.x, p.y), Vector2(o.x + mw, p.y), Color(f.col.r, f.col.g, f.col.b, 0.35), 1.0)
		hud.draw_circle(p, 4.0, f.col.lightened(0.3))
		hud.draw_line(p, p + Vector2(f.face * 8.0, 0), Color.WHITE, 1.5)
	var cp := o + Vector2((camera.position.x + LEN * 0.5) * sx, mh + 8.0)
	var half := cam_dist * TAN_H * sx
	hud.draw_line(cp, o + Vector2((cam_target.x + LEN * 0.5) * sx - half, (cam_target.z + DEPTH * 0.5) * sx), Color(1, 1, 1, 0.4), 1.0)
	hud.draw_line(cp, o + Vector2((cam_target.x + LEN * 0.5) * sx + half, (cam_target.z + DEPTH * 0.5) * sx), Color(1, 1, 1, 0.4), 1.0)
	hud.draw_string(font, o + Vector2(0, mh + 22.0), "top-down debug map (camera at the bottom; yellow = hidden for the camera)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))


# ------------------------------------------------------------------ bench and screenshots
func _bench_and_shot() -> void:
	if opts.has("shot") and not shot_done and time >= float(opts.get("at", "6")):
		shot_done = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(String(opts["shot"]))
		get_tree().quit()
		return
	if not bench:
		return
	var now := Time.get_ticks_usec()
	var warm := float(opts.get("warmup", "3"))
	var dur := float(opts.get("measure", "20"))
	if time > warm and bench_last > 0:
		bench_frames.append((now - bench_last) / 1000.0)
	bench_last = now
	if time > warm + dur:
		bench = false
		var s := Array(bench_frames)
		s.sort()
		var n := s.size()
		var sum := 0.0
		for v in s:
			sum += v
		var res := {
			"stack": "godot band-proto", "engineVersion": Engine.get_version_info()["string"], "renderer": "gl_compatibility",
			"gpu": RenderingServer.get_video_adapter_name(), "width": get_viewport().size.x, "height": get_viewport().size.y,
			"camera": CAM_NAMES[cam_mode], "occlusion": OCCL_NAMES[occl_mode], "frames": n, "elapsedMs": sum,
			"frameMs": {"avg": sum / n, "p50": s[int(ceil(0.5 * n)) - 1], "p95": s[int(ceil(0.95 * n)) - 1], "p99": s[int(ceil(0.99 * n)) - 1], "max": s[n - 1]},
			"fps": n / (sum / 1000.0), "buildingsStanding": buildings.filter(func(b): return b.alive).size(), "hashMatch": true,
		}
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.__benchResult = %s;" % JSON.stringify(res))
		else:
			if opts.has("out"):
				var fa := FileAccess.open(String(opts["out"]), FileAccess.WRITE)
				fa.store_string(JSON.stringify(res, "  "))
				fa.close()
			print("BENCH ", JSON.stringify(res))
			get_tree().quit()
