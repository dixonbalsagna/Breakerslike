extends Node
## Animation A0 spike: measures skinning cost, draw calls and the animation layer stack for one or more 27-bone fighters
## in one or more panes (each pane is a SubViewport with its own World3D, as the game's split screen has).
##
## Options (desktop: `godot --path . -- --key=value ...`; web: the page's query string, `?key=value&...`):
##   rig=static|puppet|skinned   one static mesh, a puppet of per-bone MeshInstance3D nodes, or one rigid-skinned mesh
##   hull=0|1                    the inverted-hull outline pass (a second draw per mesh)
##   hands=slab|swap             (skinned) fingers as a bone in the body mesh, or separate hand meshes on the hands
##   fighters=N  panes=N         fighters per pane, panes
##   solve=none|2|1|0            the layer stack per frame: none, key blend, level 1, full
##   every=K                     solve every K frames (2 = a 30 Hz solve at 60 fps)
##   px=N                        fighter height on screen in pixels
##   tris=N                      triangle budget per fighter (default 2500)
##   frames=N warmup=N           measured and warm-up frames
##   micro=0|1                   the layer microbenchmark before the run (default 1)
##   shot=path.png               save pane 0 after a few frames and quit (desktop)
##   out=path.json               write the result (desktop); the web build sets window.__benchResult

const RigScript = preload("res://rig.gd")
const SolveScript = preload("res://solve.gd")

const SHADER_BODY := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 light_dir = vec3(0.35, 0.8, 0.55);
void fragment() {
	vec3 L = normalize((VIEW_MATRIX * vec4(normalize(light_dir), 0.0)).xyz);
	float d = dot(normalize(NORMAL), L);
	float band = d > 0.55 ? 1.0 : (d > 0.18 ? 0.72 : 0.5);
	ALBEDO = COLOR.rgb * band;
}
"""
const SHADER_HULL := """
shader_type spatial;
render_mode unshaded, cull_front;
uniform float width = 0.7;
uniform vec3 col = vec3(0.04, 0.05, 0.08);
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = col;
}
"""

var cfg: Dictionary = {}
var rig
var mesh_static: ArrayMesh
var mesh_skinned: ArrayMesh
var mesh_bones: Array = []
var mesh_hand: Dictionary = {}
var mat_body: ShaderMaterial
var mat_hull: ShaderMaterial
var fighters: Array = []      # [{solver, skel, nodes}]
var panes: Array = []
var frame_ms: Array = []
var solve_us: Array = []
var draw_calls: Array = []
var prims: Array = []
var objects: Array = []
var frame_no: int = 0
var last_us: int = 0
var fist: float = 0.0
var micro: Dictionary = {}
var done: bool = false
var t_start_us: int = 0


func _ready() -> void:
	cfg = _parse_config()
	rig = RigScript.new()
	var target_tris: int = int(cfg.get("tris", 2500))
	rig.pick_subdiv(target_tris)
	_make_materials()
	_make_meshes()
	_build_panes()
	if int(cfg.get("micro", 1)) == 1 and str(cfg.get("solve", "none")) != "none":
		_microbench()
	last_us = Time.get_ticks_usec()
	t_start_us = last_us


func _cfg_str(k: String, d: String) -> String:
	return str(cfg.get(k, d))


func _parse_config() -> Dictionary:
	var d: Dictionary = {}
	var items: Array = []
	if OS.has_feature("web"):
		var qs = JavaScriptBridge.eval("window.location.search", true)
		if typeof(qs) == TYPE_STRING and qs.length() > 1:
			for kv in String(qs).substr(1).split("&"):
				items.append("--" + kv)
	else:
		for a in OS.get_cmdline_user_args():
			items.append(a)
	for a in items:
		var s: String = String(a)
		if s.begins_with("--"):
			s = s.substr(2)
		var eq: int = s.find("=")
		if eq > 0:
			d[s.substr(0, eq)] = s.substr(eq + 1)
		else:
			d[s] = "1"
	return d


func _make_materials() -> void:
	var sh := Shader.new()
	sh.code = SHADER_BODY
	mat_body = ShaderMaterial.new()
	mat_body.shader = sh
	var sh2 := Shader.new()
	sh2.code = SHADER_HULL
	mat_hull = ShaderMaterial.new()
	mat_hull.shader = sh2
	if int(cfg.get("hullcol", 0)) == 1:
		mat_hull.set_shader_parameter("col", Vector3(1.0, 0.2, 0.7))
	if int(cfg.get("hull", 0)) == 1:
		mat_body.next_pass = mat_hull


func _make_meshes() -> void:
	var r: String = _cfg_str("rig", "skinned")
	if r == "static":
		mesh_static = rig.build_static()
	elif r == "puppet":
		mesh_bones.resize(rig.N)
		for i in range(rig.N):
			mesh_bones[i] = rig.build_bone_mesh(i)
	else:
		var swap: bool = _cfg_str("hands", "slab") == "swap"
		mesh_skinned = rig.build_skinned(not swap)
		if swap:
			for s in ["l", "r"]:
				mesh_hand[s + "_fist"] = rig.build_hand_mesh(s, true)
				mesh_hand[s + "_open"] = rig.build_hand_mesh(s, false)


func _make_fighter(parent_node: Node, idx: int) -> Dictionary:
	var f: Dictionary = {}
	var r: String = _cfg_str("rig", "skinned")
	var holder := Node3D.new()
	holder.name = "Fighter%d" % idx
	parent_node.add_child(holder)
	f["holder"] = holder
	f["solver"] = SolveScript.new(rig, idx)
	if r == "static":
		var mi := MeshInstance3D.new()
		mi.mesh = mesh_static
		mi.set_surface_override_material(0, mat_body)
		holder.add_child(mi)
	elif r == "puppet":
		var nodes: Array = []
		nodes.resize(rig.N)
		for i in range(rig.N):
			var n := Node3D.new()
			n.position = rig.rest_local[i]
			var p: int = rig.parent[i]
			(holder if p < 0 else nodes[p]).add_child(n)
			nodes[i] = n
			if mesh_bones[i] != null:
				var mi := MeshInstance3D.new()
				mi.mesh = mesh_bones[i]
				mi.set_surface_override_material(0, mat_body)
				n.add_child(mi)
		f["nodes"] = nodes
	else:
		var sk := Skeleton3D.new()
		for i in range(rig.N):
			sk.add_bone(rig.BONES[i][0])
		for i in range(rig.N):
			sk.set_bone_parent(i, rig.parent[i])
			sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, rig.rest_local[i]))
		sk.reset_bone_poses()
		holder.add_child(sk)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh_skinned
		mi.set_surface_override_material(0, mat_body)
		sk.add_child(mi)
		mi.skin = sk.create_skin_from_rest_transforms()
		mi.skeleton = NodePath("..")
		if _cfg_str("hands", "slab") == "swap":
			for s in ["l", "r"]:
				var ba := BoneAttachment3D.new()
				ba.bone_name = "hand_" + s
				sk.add_child(ba)
				var hm := MeshInstance3D.new()
				hm.mesh = mesh_hand[s + "_fist"]
				hm.set_surface_override_material(0, mat_body)
				ba.add_child(hm)
		f["skel"] = sk
	return f


func _build_panes() -> void:
	var np: int = int(cfg.get("panes", 1))
	var nf: int = int(cfg.get("fighters", 2))
	var vw: int = 1280
	var vh: int = 720
	var pw: int = vw / np
	var layer := CanvasLayer.new()
	add_child(layer)
	for p in range(np):
		var sv := SubViewport.new()
		sv.size = Vector2i(pw, vh)
		sv.own_world_3d = true
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sv)
		var cam := Camera3D.new()
		cam.fov = 30.0
		var zoom: float = float(cfg.get("px", 300)) / 85.0
		var dist: float = vh / (2.0 * zoom * tan(deg_to_rad(15.0)))
		cam.position = Vector3(0, 42, dist)
		sv.add_child(cam)
		cam.current = true
		var group: Array = []
		for i in range(nf):
			var f: Dictionary = _make_fighter(sv, p * 10 + i)
			var holder: Node3D = f["holder"]
			holder.position = Vector3((i - (nf - 1) * 0.5) * 60.0, 0, -float(i) * 12.0)
			if i % 2 == 1:
				holder.rotation.y = PI
			group.append(f)
			fighters.append(f)
		var tr := TextureRect.new()
		tr.texture = sv.get_texture()
		tr.position = Vector2(p * pw, 0)
		tr.size = Vector2(pw, vh)
		layer.add_child(tr)
		panes.append(sv)


func _time_us(callable: Callable, k: int) -> float:
	var t0: int = Time.get_ticks_usec()
	for _i in range(k):
		callable.call()
	return float(Time.get_ticks_usec() - t0) / k


## Per-call cost of each layer on one fighter's solver, and of the write to the rig, in microseconds.
func _microbench() -> void:
	var s = fighters[0]["solver"]
	var k := 400
	for _w in range(40):
		s.solve_mask(127)
	var m: Dictionary = {}
	for mask in [0, 1, 2, 4, 12, 16, 48, 64, 21, 127]:
		m["mask_%d" % mask] = _time_us(func(): s.solve_mask(mask), k)
	if fighters[0].has("skel"):
		m["apply_skeleton"] = _time_us(func(): s.apply_skeleton(fighters[0]["skel"], fist), k)
	elif fighters[0].has("nodes"):
		m["apply_nodes"] = _time_us(func(): s.apply_nodes(fighters[0]["nodes"], fist), k)
	micro = m


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var dt_ms: float = float(now - last_us) / 1000.0
	last_us = now
	frame_no += 1
	var warm: int = int(cfg.get("warmup", 90))
	var total: int = int(cfg.get("frames", 900))
	# animate
	var mode: String = _cfg_str("solve", "none")
	var t0: int = Time.get_ticks_usec()
	if mode != "none":
		var every: int = int(cfg.get("every", 1))
		if frame_no % every == 0:
			var level: int = int(mode)
			var mask: int = SolveScript.mask_for_level(level)
			fist = 1.7 if (frame_no / 45) % 2 == 0 else 0.0
			for f in fighters:
				f["solver"].solve_mask(mask)
				if f.has("skel"):
					f["solver"].apply_skeleton(f["skel"], fist)
				elif f.has("nodes"):
					f["solver"].apply_nodes(f["nodes"], fist)
	elif cfg.has("fistmix") and frame_no == 2:
		var k := 0
		for f in fighters:
			if f.has("skel"):
				var fq := Quaternion(Vector3(0, 0, 1), 1.7 if k % 2 == 0 else 0.0)
				f["skel"].set_bone_pose_rotation(rig.index["fingers_l"], fq)
				f["skel"].set_bone_pose_rotation(rig.index["fingers_r"], fq)
			k += 1
	var us: int = Time.get_ticks_usec() - t0
	if frame_no > warm and not done:
		frame_ms.append(dt_ms)
		solve_us.append(float(us))
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		if frame_ms.size() >= total:
			done = true
			_finish()
	var shot: String = _cfg_str("shot", "")
	if shot != "" and frame_no == 40:
		panes[0].get_texture().get_image().save_png(shot)
		print("SHOT ", shot)
		get_tree().quit()


func _stats(a: Array) -> Dictionary:
	var s: Array = a.duplicate()
	s.sort()
	var n: int = s.size()
	if n == 0:
		return {}
	var sum := 0.0
	for v in s:
		sum += v
	return {"mean": sum / n, "p50": s[n / 2], "p95": s[int(n * 0.95)], "p99": s[int(n * 0.99)], "max": s[n - 1], "n": n}


func _finish() -> void:
	var res: Dictionary = {
		"cfg": cfg,
		"engine": Engine.get_version_info().get("string", ""),
		"method": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"os": OS.get_name(),
		"web": OS.has_feature("web"),
		"tris_per_fighter": rig.tris_full,
		"subdiv": rig.subdiv,
		"bones": rig.N,
		"fighters_total": fighters.size(),
		"frame_ms": _stats(frame_ms),
		"solve_us_per_frame": _stats(solve_us),
		"draw_calls": _stats(draw_calls),
		"primitives": _stats(prims),
		"objects": _stats(objects),
		"micro_us": micro,
		"viewport": get_viewport().get_visible_rect().size,
	}
	var js: String = JSON.stringify(res)
	print("RESULT ", js)
	var out: String = _cfg_str("out", "")
	if out != "":
		var fa := FileAccess.open(out, FileAccess.WRITE)
		if fa != null:
			fa.store_string(js)
			fa.close()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__benchResult = %s;" % js, true)
	else:
		get_tree().quit()
