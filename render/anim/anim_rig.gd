class_name AnimRig
extends RefCounted
## Rig R1 for the mannequin (docs/animation/pose-pipeline.md section 2.2): 27 bones (the 22-bone core plus 5 extras) and
## a faceted low-poly body, built as one rigid-skinned mesh (every vertex 100% on one bone). Units are the game's:
## feet at y = 0, about 85 tall, facing +x, the character's right (near) side at +z. The mesh is generated here from a
## palette, so any fighter's colours make one mesh; nothing is imported. Render only.
## Bone and part tables are static; a mesh is built once per palette and shared by every view of that fighter.

const N := 27
const BONES: Array = [
	# [name, parent, local rest offset]
	["root", "", Vector3(0, 0, 0)],
	["pelvis", "root", Vector3(0, 36, 0)],
	["spine_1", "pelvis", Vector3(0, 7, 0)],
	["spine_2", "spine_1", Vector3(0, 11, 0)],
	["neck", "spine_2", Vector3(0, 13, 0)],
	["head", "neck", Vector3(0, 6, 0)],
	["clavicle_l", "spine_2", Vector3(0, 10, -4)],
	["upper_arm_l", "clavicle_l", Vector3(0, -1, -6)],
	["forearm_l", "upper_arm_l", Vector3(0, -16, 0)],
	["hand_l", "forearm_l", Vector3(0, -15, 0)],
	["fingers_l", "hand_l", Vector3(0, -5, 0)],
	["clavicle_r", "spine_2", Vector3(0, 10, 4)],
	["upper_arm_r", "clavicle_r", Vector3(0, -1, 6)],
	["forearm_r", "upper_arm_r", Vector3(0, -16, 0)],
	["hand_r", "forearm_r", Vector3(0, -15, 0)],
	["fingers_r", "hand_r", Vector3(0, -5, 0)],
	["thigh_l", "pelvis", Vector3(0, -2, -5)],
	["shin_l", "thigh_l", Vector3(0, -17, 0)],
	["foot_l", "shin_l", Vector3(0, -17, 0)],
	["thigh_r", "pelvis", Vector3(0, -2, 5)],
	["shin_r", "thigh_r", Vector3(0, -17, 0)],
	["foot_r", "shin_r", Vector3(0, -17, 0)],
	["x_pack", "spine_2", Vector3(-8, 4, 0)],
	["x_sash_a1", "spine_2", Vector3(-5, 9, -4)],
	["x_sash_a2", "x_sash_a1", Vector3(0, -10, 0)],
	["x_sash_b1", "spine_2", Vector3(-5, 9, 4)],
	["x_sash_b2", "x_sash_b1", Vector3(0, -10, 0)],
]

static var index: Dictionary = {}          # bone name -> index
static var parent := PackedInt32Array()
static var rest_local := PackedVector3Array()
static var rest_global := PackedVector3Array()
static var _ready_: bool = false
static var _meshes: Dictionary = {}        # palette key -> ArrayMesh

const TRIS_TARGET := 2500

## Palette keys: body (torso), legs, arms, skin (head), gear (pelvis, plates), accent (forearms, sashes), hair.


static func setup() -> void:
	if _ready_:
		return
	_ready_ = true
	parent.resize(N)
	rest_local.resize(N)
	rest_global.resize(N)
	for i in range(N):
		var b: Array = BONES[i]
		index[b[0]] = i
		parent[i] = -1 if b[1] == "" else int(index[b[1]])
		rest_local[i] = b[2]
		rest_global[i] = rest_local[i] + (rest_global[parent[i]] if parent[i] >= 0 else Vector3.ZERO)


static func bone(name: String) -> int:
	setup()
	return int(index[name])


## The body parts: [bone, offset from the bone's rest position, axis, length, ring profile [t, rx, rz], sides, palette key].
static func _parts() -> Array:
	setup()
	var up := Vector3(0, 1, 0)
	var dn := Vector3(0, -1, 0)
	var p: Array = []
	p.append(["pelvis", Vector3(0, -6, 0), up, 12.0, [[0.0, 5.0, 8.0], [0.5, 6.0, 9.0], [1.0, 5.5, 8.0]], 8, "gear"])
	p.append(["spine_1", Vector3.ZERO, up, 11.0, [[0.0, 5.5, 8.5], [0.5, 6.0, 9.5], [1.0, 6.0, 9.5]], 8, "body"])
	p.append(["spine_2", Vector3.ZERO, up, 13.0, [[0.0, 6.0, 9.5], [0.4, 7.0, 11.0], [0.8, 6.5, 10.5], [1.0, 5.0, 8.0]], 8, "body"])
	p.append(["neck", Vector3.ZERO, up, 6.0, [[0.0, 2.5, 2.5], [1.0, 2.5, 2.5]], 6, "skin"])
	p.append(["head", Vector3.ZERO, up, 12.0, [[0.0, 3.5, 3.5], [0.3, 6.0, 5.5], [0.65, 6.5, 5.5], [1.0, 3.0, 3.0]], 8, "skin"])
	p.append(["head", Vector3(0, 6.5, 0), up, 6.5, [[0.0, 6.7, 5.7], [0.5, 6.3, 5.4], [1.0, 2.5, 2.2]], 8, "hair"])
	for s in ["l", "r"]:
		var zs: float = -1.0 if s == "l" else 1.0
		p.append(["clavicle_" + s, Vector3.ZERO, Vector3(0, 0, zs), 6.0, [[0.0, 3.0, 3.0], [1.0, 3.0, 3.0]], 6, "gear"])
		p.append(["upper_arm_" + s, Vector3.ZERO, dn, 16.0, [[0.0, 3.6, 3.6], [0.5, 3.2, 3.2], [1.0, 2.8, 2.8]], 6, "arms"])
		p.append(["forearm_" + s, Vector3.ZERO, dn, 15.0, [[0.0, 2.8, 2.8], [0.6, 3.2, 3.2], [1.0, 2.4, 2.4]], 6, "accent"])
		p.append(["hand_" + s, Vector3.ZERO, dn, 5.0, [[0.0, 2.6, 3.2], [1.0, 2.4, 3.0]], 4, "arms"])
		p.append(["fingers_" + s, Vector3.ZERO, dn, 5.0, [[0.0, 2.2, 3.0], [1.0, 2.0, 2.8]], 4, "arms"])
		p.append(["thigh_" + s, Vector3.ZERO, dn, 17.0, [[0.0, 4.4, 4.4], [0.5, 4.2, 4.2], [1.0, 3.2, 3.2]], 6, "legs"])
		p.append(["shin_" + s, Vector3.ZERO, dn, 17.0, [[0.0, 3.2, 3.2], [0.4, 3.4, 3.4], [1.0, 2.4, 2.4]], 6, "legs"])
		p.append(["foot_" + s, Vector3(-2, 0, 0), Vector3(1, 0, 0), 11.0, [[0.0, 2.2, 3.0], [1.0, 1.6, 2.4]], 4, "gear"])
	p.append(["x_pack", Vector3(0, -4, 0), up, 16.0, [[0.0, 4.0, 7.0], [1.0, 4.0, 7.0]], 4, "gear"])
	for c in ["x_sash_a1", "x_sash_a2", "x_sash_b1", "x_sash_b2"]:
		p.append([c, Vector3.ZERO, dn, 10.0, [[0.0, 1.0, 1.0], [1.0, 1.0, 1.0]], 4, "accent"])
	return p


static func _profile(p: Array, sub: int) -> Array:
	if sub <= 1:
		return p
	var out: Array = []
	for k in range(p.size() - 1):
		var a: Array = p[k]
		var b: Array = p[k + 1]
		for j in range(sub):
			var f: float = float(j) / sub
			out.append([lerpf(a[0], b[0], f), lerpf(a[1], b[1], f), lerpf(a[2], b[2], f)])
	out.append(p[p.size() - 1])
	return out


static func _count(parts: Array, sub: int) -> int:
	var n := 0
	for part in parts:
		var rings: int = _profile(part[4], sub).size()
		n += (rings - 1) * part[5] * 2 + part[5] * 2
	return n


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, bone: int) -> void:
	# Godot's front faces are clockwise, so the outward normal is the reverse of the counter-clockwise cross product.
	var n: Vector3 = (c - a).cross(b - a).normalized()
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.set_bones(PackedInt32Array([bone, 0, 0, 0]))
		st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		st.add_vertex(v)


static func _emit(st: SurfaceTool, part: Array, sub: int, col: Color) -> void:
	var bone_i: int = int(index[part[0]])
	var origin: Vector3 = rest_global[bone_i] + part[1]
	var dir: Vector3 = (part[2] as Vector3).normalized()
	var length: float = part[3]
	var prof: Array = _profile(part[4], sub)
	var sides: int = part[5]
	var ref := Vector3(0, 0, 1) if absf(dir.z) < 0.9 else Vector3(1, 0, 0)
	var u: Vector3 = dir.cross(ref).normalized()
	var w: Vector3 = dir.cross(u).normalized()
	var rings: Array = []
	for r in prof:
		var ring: Array = []
		var c: Vector3 = origin + dir * (float(r[0]) * length)
		for s in range(sides):
			var th: float = TAU * (float(s) + 0.5) / sides
			ring.append(c + u * (float(r[1]) * cos(th)) + w * (float(r[2]) * sin(th)))
		rings.append(ring)
	for k in range(rings.size() - 1):
		for s in range(sides):
			var s2: int = (s + 1) % sides
			_tri(st, rings[k][s], rings[k + 1][s], rings[k][s2], col, bone_i)
			_tri(st, rings[k][s2], rings[k + 1][s], rings[k + 1][s2], col, bone_i)
	var c0: Vector3 = origin + dir * (float(prof[0][0]) * length)
	var c1: Vector3 = origin + dir * (float(prof[prof.size() - 1][0]) * length)
	for s in range(sides):
		var s2: int = (s + 1) % sides
		_tri(st, c0, rings[0][s], rings[0][s2], col, bone_i)
		_tri(st, c1, rings[rings.size() - 1][s2], rings[rings.size() - 1][s], col, bone_i)


## The fighter's mesh for a palette (Dictionary of palette key -> Color), cached by its colours.
static func mesh_for(pal: Dictionary) -> ArrayMesh:
	setup()
	var key := ""
	for k in ["body", "legs", "arms", "skin", "gear", "accent", "hair"]:
		key += (pal[k] as Color).to_html() + "|"
	var m = _meshes.get(key)
	if m != null:
		return m
	var parts: Array = _parts()
	var sub := 1
	for s in range(1, 9):
		if _count(parts, s) <= int(TRIS_TARGET * 1.08):
			sub = s
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		_emit(st, part, sub, pal[part[6]])
	# the outline: smoothed push directions and reach baked into the mesh (Rendering's OutlineBake)
	m = OutlineBake.bake(st.commit())
	_meshes[key] = m
	return m


static func triangle_count(pal: Dictionary) -> int:
	var m: ArrayMesh = mesh_for(pal)
	return int(m.surface_get_array_len(0) / 3.0)


## A Skeleton3D at its rest pose with R1's bones, and the skin for the mesh.
static func make_skeleton() -> Skeleton3D:
	setup()
	var sk := Skeleton3D.new()
	for i in range(N):
		sk.add_bone(BONES[i][0])
	for i in range(N):
		sk.set_bone_parent(i, parent[i])
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, rest_local[i]))
	sk.reset_bone_poses()
	return sk
