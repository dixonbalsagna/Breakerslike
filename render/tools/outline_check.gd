extends SceneTree
## Outline check (docs/rendering/outline-normals-plan.md): the fighter outline never cracks. A faceted, rigid-skinned
## mannequin (box torso and head, six-sided limbs, palm and finger slabs; Animation's A1 mesh replaces it when it
## lands) is baked by OutlineBake and drawn through fighter_hull.gdshader, posed by seeded bone sweeps, near and far,
## with the hybrid projection and without. For each frame the body is drawn alone (its silhouette B), then with its
## outline (H); every pixel within OUTLINE_PX - 0.5 of B must be in H. Any that is not is a crack. The same frames with
## the outline pushed along the faceted normals (the spike's hull) must crack: the failing control. Needs a window:
## the masks are rendered, so under --headless (no renderer) it says so and exits with code 2 (1 is a failure).
##   godot --path . --script res://render/tools/outline_check.gd -- [--out=DIR] [--poses=24] [--seed=7]

const SIZE := 640
const FIG_H := 76.0   # a fighter's height in world units

var out: String = ""
var poses: int = 24
var control_sheet: bool = false   # the sheet shows the faceted control instead (to see what cracks look like)
var seed: int = 7
var vp: SubViewport
var cam: Camera3D
var skel: Skeleton3D
var mi: MeshInstance3D
var baked: ArrayMesh
var raw: ArrayMesh   # the unbaked mesh: the failing control pushes along its faceted normals
var body_mat: ShaderMaterial
var hull_mat: ShaderMaterial
var bones: Array = []   # [name, parent, rest origin]


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("outline check: needs a window (it renders its masks); not run under --headless")
		quit(2)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--poses="):
			poses = int(a.substr(8))
		elif a.begins_with("--seed="):
			seed = int(a.substr(7))
		elif a == "--control-sheet":
			control_sheet = true
	vp = SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	vp.add_child(env)
	cam = Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	_build()
	_run.call_deferred()


# --- the mannequin -----------------------------------------------------------------------------------------------------

func _build() -> void:
	skel = Skeleton3D.new()
	vp.add_child(skel)
	# name, parent, rest origin (relative to the parent), in fighter units (FIG_H tall)
	bones = [
		["hips", -1, Vector3(0, 38, 0)], ["torso", 0, Vector3(0, 4, 0)], ["head", 1, Vector3(0, 24, 0)],
		["l_upper", 1, Vector3(-11, 21, 0)], ["l_fore", 3, Vector3(0, -13, 0)], ["l_hand", 4, Vector3(0, -12, 0)],
		["r_upper", 1, Vector3(11, 21, 0)], ["r_fore", 6, Vector3(0, -13, 0)], ["r_hand", 7, Vector3(0, -12, 0)],
		["l_thigh", 0, Vector3(-5, -2, 0)], ["l_shin", 9, Vector3(0, -17, 0)],
		["r_thigh", 0, Vector3(5, -2, 0)], ["r_shin", 11, Vector3(0, -17, 0)],
	]
	for b in bones:
		var i: int = skel.add_bone(b[0])
		if b[1] >= 0:
			skel.set_bone_parent(i, b[1])
		skel.set_bone_rest(i, Transform3D(Basis(), b[2]))
		skel.set_bone_pose_position(i, b[2])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, 0, Vector3(0, 0, 0), Vector3(16, 8, 9))                 # hips
	_box(st, 1, Vector3(0, 11, 0), Vector3(20, 22, 11))             # torso
	_box(st, 2, Vector3(0, 6, 0), Vector3(11, 12, 11))              # head
	for s in [3, 6]:
		_tube(st, s, Vector3(0, 0, 0), Vector3(0, -13, 0), 3.2, 6)        # upper arm
		_tube(st, s + 1, Vector3(0, 0, 0), Vector3(0, -12, 0), 2.8, 6)    # forearm
		_box(st, s + 2, Vector3(0, -3, 0), Vector3(5, 6, 2.2))            # palm
		_box(st, s + 2, Vector3(0, -7.5, 0.6), Vector3(4.6, 3.5, 1.4))    # finger slab
	for s in [9, 11]:
		_tube(st, s, Vector3(0, 0, 0), Vector3(0, -17, 0), 4.0, 6)
		_tube(st, s + 1, Vector3(0, 0, 0), Vector3(0, -17, 0), 3.4, 6)
		_box(st, s + 1, Vector3(0, -18.5, 2.5), Vector3(5, 3, 10))        # foot
	raw = st.commit()
	baked = OutlineBake.bake(raw)
	mi = MeshInstance3D.new()
	mi.mesh = baked
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = skel.create_skin_from_rest_transforms()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
#include "res://render/shaders/bend.gdshaderinc"
#include "res://render/shaders/ortho.gdshaderinc"
void vertex() {
	POSITION = ortho > 0.5 ? ortho_clip(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, VERTEX) : bent_clip(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
}
void fragment() {
	ALBEDO = vec3(1.0);
}
"""
	body_mat = ShaderMaterial.new()
	body_mat.shader = sh
	hull_mat = RenderMats.fighter_hull()
	hull_mat.set_shader_parameter("col", Color(1, 0, 0))
	mi.material_override = body_mat


## A part's triangle, in bone `b`'s bind space turned into skeleton space: faceted (one normal a face), rigidly bound,
## wound clockwise seen from outside (Godot's front face) with its normal pointing away from `ref`, the part's centre.
func _tri(st: SurfaceTool, b: int, p: Array, ref: Vector3) -> void:
	var o: Vector3 = skel.get_bone_global_rest(b).origin
	var out_dir: Vector3 = (p[0] + p[1] + p[2]) / 3.0 - ref
	var g: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	var n: Vector3 = g.normalized() if g.dot(out_dir) > 0.0 else -g.normalized()
	if g.dot(out_dir) > 0.0:
		p = [p[0], p[2], p[1]]
	for q in p:
		st.set_normal(n)
		st.set_bones(PackedInt32Array([b, 0, 0, 0]))
		st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		st.add_vertex(o + q)


func _quad(st: SurfaceTool, b: int, a: Vector3, c: Vector3, d: Vector3, e: Vector3, ref: Vector3) -> void:
	_tri(st, b, [a, c, d], ref)
	_tri(st, b, [a, d, e], ref)


func _box(st: SurfaceTool, b: int, c: Vector3, s: Vector3) -> void:
	var h: Vector3 = s * 0.5
	var p: Array = []
	for i in range(8):
		p.append(c + Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1)))
	_quad(st, b, p[0], p[2], p[3], p[1], c)   # -z
	_quad(st, b, p[4], p[5], p[7], p[6], c)   # +z
	_quad(st, b, p[0], p[4], p[6], p[2], c)   # -x
	_quad(st, b, p[1], p[3], p[7], p[5], c)   # +x
	_quad(st, b, p[0], p[1], p[5], p[4], c)   # -y
	_quad(st, b, p[2], p[6], p[7], p[3], c)   # +y


func _tube(st: SurfaceTool, b: int, a: Vector3, e: Vector3, r: float, sides: int) -> void:
	var ring_a: Array = []
	var ring_e: Array = []
	for k in range(sides):
		var t: float = TAU * k / sides
		var off := Vector3(cos(t) * r, 0.0, sin(t) * r)
		ring_a.append(a + off)
		ring_e.append(e + off)
	var mid: Vector3 = (a + e) * 0.5
	for k in range(sides):
		var k2: int = (k + 1) % sides
		_quad(st, b, ring_a[k], ring_a[k2], ring_e[k2], ring_e[k], mid)
		_tri(st, b, [a, ring_a[k2], ring_a[k]], mid)
		_tri(st, b, [e, ring_e[k], ring_e[k2]], mid)


# --- the check ---------------------------------------------------------------------------------------------------------

func _pose(rng: RandomNumberGenerator) -> void:
	for i in range(1, bones.size()):
		var axis := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		skel.set_bone_pose_rotation(i, Quaternion(axis, deg_to_rad(rng.randf_range(-70.0, 70.0))))
	skel.set_bone_pose_rotation(0, Quaternion(Vector3.UP, deg_to_rad(rng.randf_range(-35.0, 35.0))))


func _frame(hull: bool, face: bool) -> Image:
	mi.mesh = raw if face else baked
	mi.material_override = body_mat
	body_mat.next_pass = hull_mat if hull else null
	hull_mat.set_shader_parameter("face_normals", face)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


## Pixels within r of the body's silhouette that the outline does not cover.
static func _cracks(b: Image, h: Image, r: int, mark: Image) -> int:
	var n: int = 0
	var w: int = b.get_width()
	var ht: int = b.get_height()
	for y in range(ht):
		for x in range(w):
			if h.get_pixel(x, y).r > 0.3:
				continue
			var near: bool = false
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var xx: int = x + dx
					var yy: int = y + dy
					if xx >= 0 and yy >= 0 and xx < w and yy < ht and b.get_pixel(xx, yy).r > 0.5:
						near = true
			if near:
				n += 1
				if mark != null:
					mark.set_pixel(x, y, Color(0, 1, 1))
	return n


func _run() -> void:
	await process_frame
	var r: int = int(floor(RenderLook.OUTLINE_PX - 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var fails: Array = []
	var total: int = 0
	var control: int = 0
	var sheet: Array = []
	for pi in range(poses):
		_pose(rng)
		var far: bool = pi % 3 == 2
		var ortho: float = 0.0 if pi % 4 == 3 else 1.0
		var dist: float = 900.0 if far else 220.0
		cam.position = Vector3(rng.randf_range(-40, 40), 40.0 + rng.randf_range(-20, 30), dist)
		cam.look_at(Vector3(cam.position.x * 0.5, 38.0, 0.0))
		for m in [body_mat, hull_mat]:
			m.set_shader_parameter("ortho", ortho)
			m.set_shader_parameter("anchor", Vector3(0, 38, 0))
		var b: Image = await _frame(false, false)
		var h: Image = await _frame(true, false)
		var mark: Image = h.duplicate()
		var n: int = _cracks(b, h, r, mark)
		var hc: Image = await _frame(true, true)
		var nc: int = _cracks(b, hc, r, null)
		total += n
		control += nc
		if n > 0:
			fails.append("pose %d (%s, %s): %d crack pixels" % [pi, "far" if far else "near", "hybrid" if ortho > 0.5 else "perspective", n])
		if control_sheet:
			mark = hc.duplicate()
			_cracks(b, hc, r, mark)
		if sheet.size() < 8:
			sheet.append(mark)
	# The look: the faceted body (fighter_body.gdshader) with its outline, the first pose of a fresh draw.
	if out != "":
		rng.seed = seed
		_pose(rng)
		cam.position = Vector3(0, 45, 220)
		cam.look_at(Vector3(0, 38, 0))
		var look: ShaderMaterial = RenderMats.fighter_body(Color(0.85, 0.62, 0.42))
		look.set_shader_parameter("anchor", Vector3(0, 38, 0))
		look.next_pass.set_shader_parameter("anchor", Vector3(0, 38, 0))
		mi.mesh = baked
		mi.material_override = look
		var env: Environment = (vp.get_child(0) as WorldEnvironment).environment
		env.background_color = Color(0.55, 0.62, 0.7)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/outline-look.png" % out)
	print("Outline check: %d poses (a third far, a quarter plain perspective), outline %.1f px" % [poses, RenderLook.OUTLINE_PX])
	print("baked outline: %d crack pixels; faceted control: %d" % [total, control])
	if control == 0:
		fails.append("the faceted control shows no cracks: the check cannot see them")
	if out != "":
		var cols: int = 4
		var s := Image.create_empty(SIZE * cols, SIZE * int(ceil(sheet.size() / float(cols))), false, Image.FORMAT_RGBA8)
		for i in range(sheet.size()):
			var im: Image = sheet[i]
			im.convert(Image.FORMAT_RGBA8)
			s.blit_rect(im, Rect2i(0, 0, SIZE, SIZE), Vector2i((i % cols) * SIZE, (i / cols) * SIZE))
		s.save_png("%s/outline-sheet.png" % out)
	for f in fails:
		print("FAIL  " + f)
	print("\noutline check %s" % ("passed" if fails.is_empty() else "FAILED (%d)" % fails.size()))
	quit(0 if fails.is_empty() else 1)
