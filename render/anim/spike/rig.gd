extends RefCounted
## The A0 spike's rig: 27 bones (R1 core of 22 plus 5 extras, like the Cyborg), and a faceted low-poly body built as
## either one rigid-skinned mesh (every vertex 100% on one bone), one small mesh per bone (a puppet of MeshInstance3D
## nodes) or one static mesh (no skeleton, the cost baseline). Units are the game's (about 85 tall, feet at y = 0, facing
## +x, the character's right side at +z). All geometry is generated here; nothing is imported.

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
	["x_cable_a1", "spine_2", Vector3(-5, 9, -4)],
	["x_cable_a2", "x_cable_a1", Vector3(0, -10, 0)],
	["x_cable_b1", "spine_2", Vector3(-5, 9, 4)],
	["x_cable_b2", "x_cable_b1", Vector3(0, -10, 0)],
]
const N := 27

const C_BODY := Color("#1a3d46")
const C_GEAR := Color("#c4ece6")
const C_ACCENT := Color("#4fb9a8")
const C_MASK := Color("#e8f1ee")
const C_SKIN := Color("#a56d4d")

var index: Dictionary = {}          # bone name -> index
var parent := PackedInt32Array()
var rest_local := PackedVector3Array()
var rest_global := PackedVector3Array()   # rest positions in model space (rotations are identity at rest)
var parts: Array = []               # [bone idx, origin (model space), dir, length, profile, sides, colour]
var subdiv: int = 1
var tris_full: int = 0


func _init() -> void:
	parent.resize(N)
	rest_local.resize(N)
	rest_global.resize(N)
	for i in range(N):
		var b: Array = BONES[i]
		index[b[0]] = i
		parent[i] = -1 if b[1] == "" else int(index[b[1]])
		rest_local[i] = b[2]
		rest_global[i] = rest_local[i] + (rest_global[parent[i]] if parent[i] >= 0 else Vector3.ZERO)
	_define_parts()


func _p(bone: String, off: Vector3, dir: Vector3, length: float, profile: Array, sides: int, col: Color) -> void:
	var i: int = index[bone]
	parts.append([i, rest_global[i] + off, dir.normalized(), length, profile, sides, col])


func _define_parts() -> void:
	var up := Vector3(0, 1, 0)
	var dn := Vector3(0, -1, 0)
	_p("pelvis", Vector3(0, -6, 0), up, 12.0, [[0.0, 5.0, 8.0], [0.5, 6.0, 9.0], [1.0, 5.5, 8.0]], 8, C_GEAR)
	_p("spine_1", Vector3(0, 0, 0), up, 11.0, [[0.0, 5.5, 8.5], [0.5, 6.0, 9.5], [1.0, 6.0, 9.5]], 8, C_BODY)
	_p("spine_2", Vector3(0, 0, 0), up, 13.0, [[0.0, 6.0, 9.5], [0.4, 7.0, 11.0], [0.8, 6.5, 10.5], [1.0, 5.0, 8.0]], 8, C_BODY)
	_p("neck", Vector3(0, 0, 0), up, 6.0, [[0.0, 2.5, 2.5], [1.0, 2.5, 2.5]], 6, C_SKIN)
	_p("head", Vector3(0, 0, 0), up, 12.0, [[0.0, 3.5, 3.5], [0.3, 6.0, 5.5], [0.65, 6.5, 5.5], [1.0, 3.0, 3.0]], 8, C_MASK)
	for s in ["l", "r"]:
		var zs: float = -1.0 if s == "l" else 1.0
		_p("clavicle_" + s, Vector3(0, 0, 0), Vector3(0, 0, zs), 6.0, [[0.0, 3.0, 3.0], [1.0, 3.0, 3.0]], 6, C_GEAR)
		_p("upper_arm_" + s, Vector3(0, 0, 0), dn, 16.0, [[0.0, 3.6, 3.6], [0.5, 3.2, 3.2], [1.0, 2.8, 2.8]], 6, C_SKIN)
		_p("forearm_" + s, Vector3(0, 0, 0), dn, 15.0, [[0.0, 2.8, 2.8], [0.6, 3.2, 3.2], [1.0, 2.4, 2.4]], 6, C_ACCENT)
		_p("hand_" + s, Vector3(0, 0, 0), dn, 5.0, [[0.0, 2.6, 3.2], [1.0, 2.4, 3.0]], 4, C_SKIN)
		_p("fingers_" + s, Vector3(0, 0, 0), dn, 5.0, [[0.0, 2.2, 3.0], [1.0, 2.0, 2.8]], 4, C_SKIN)
		_p("thigh_" + s, Vector3(0, 0, 0), dn, 17.0, [[0.0, 4.4, 4.4], [0.5, 4.2, 4.2], [1.0, 3.2, 3.2]], 6, C_BODY)
		_p("shin_" + s, Vector3(0, 0, 0), dn, 17.0, [[0.0, 3.2, 3.2], [0.4, 3.4, 3.4], [1.0, 2.4, 2.4]], 6, C_BODY)
		_p("foot_" + s, Vector3(-2, 0, 0), Vector3(1, 0, 0), 11.0, [[0.0, 2.2, 3.0], [1.0, 1.6, 2.4]], 4, C_GEAR)
	_p("x_pack", Vector3(0, -4, 0), up, 16.0, [[0.0, 4.0, 7.0], [1.0, 4.0, 7.0]], 4, C_GEAR)
	for c in ["x_cable_a1", "x_cable_a2", "x_cable_b1", "x_cable_b2"]:
		_p(c, Vector3(0, 0, 0), dn, 10.0, [[0.0, 1.0, 1.0], [1.0, 1.0, 1.0]], 4, C_ACCENT)


## The ring profile of a part with every segment split into `sub` pieces.
func _profile(p: Array, sub: int) -> Array:
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


func _basis_for(dir: Vector3) -> Array:
	var ref := Vector3(0, 0, 1) if absf(dir.z) < 0.9 else Vector3(1, 0, 0)
	var u: Vector3 = dir.cross(ref).normalized()
	var w: Vector3 = dir.cross(u).normalized()
	return [u, w]


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, bone: int, sub_origin: Vector3) -> void:
	var n: Vector3 = (c - a).cross(b - a).normalized()   # Godot fronts are clockwise, so the outward normal is the reverse of the counter-clockwise cross
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		if bone >= 0:
			st.set_bones(PackedInt32Array([bone, 0, 0, 0]))
			st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		st.add_vertex(v - sub_origin)


## Adds one part's faceted lathe solid to `st`. `bone` >= 0 rigid-skins it to that bone; `sub_origin` is subtracted
## from every vertex (a puppet part is built in its bone's own space).
func _emit_part(st: SurfaceTool, part: Array, sub: int, bone: int, sub_origin: Vector3) -> int:
	var origin: Vector3 = part[1]
	var dir: Vector3 = part[2]
	var length: float = part[3]
	var prof: Array = _profile(part[4], sub)
	var sides: int = part[5]
	var col: Color = part[6]
	var uw: Array = _basis_for(dir)
	var u: Vector3 = uw[0]
	var w: Vector3 = uw[1]
	var rings: Array = []
	for r in prof:
		var ring: Array = []
		var c: Vector3 = origin + dir * (float(r[0]) * length)
		for s in range(sides):
			var th: float = TAU * (float(s) + 0.5) / sides
			ring.append(c + u * (float(r[1]) * cos(th)) + w * (float(r[2]) * sin(th)))
		rings.append(ring)
	var tris := 0
	for k in range(rings.size() - 1):
		for s in range(sides):
			var s2: int = (s + 1) % sides
			var a: Vector3 = rings[k][s]
			var b: Vector3 = rings[k][s2]
			var c2: Vector3 = rings[k + 1][s2]
			var d: Vector3 = rings[k + 1][s]
			_tri(st, a, d, b, col, bone, sub_origin)
			_tri(st, b, d, c2, col, bone, sub_origin)
			tris += 2
	var c0: Vector3 = origin + dir * (float(prof[0][0]) * length)
	var c1: Vector3 = origin + dir * (float(prof[prof.size() - 1][0]) * length)
	for s in range(sides):
		var s2: int = (s + 1) % sides
		_tri(st, c0, rings[0][s], rings[0][s2], col, bone, sub_origin)
		_tri(st, c1, rings[rings.size() - 1][s2], rings[rings.size() - 1][s], col, bone, sub_origin)
		tris += 2
	return tris


func count_tris(sub: int) -> int:
	var n := 0
	for part in parts:
		var rings: int = _profile(part[4], sub).size()
		n += (rings - 1) * part[5] * 2 + part[5] * 2
	return n


## Picks the subdivision whose triangle count is closest to `target` without going far over.
func pick_subdiv(target: int) -> int:
	var best := 1
	for s in range(1, 9):
		if count_tris(s) <= target * 1.08:
			best = s
	subdiv = best
	tris_full = count_tris(best)
	return best


func _is_hand(bone: int) -> bool:
	var nm: String = BONES[bone][0]
	return nm.begins_with("hand_") or nm.begins_with("fingers_")


## One mesh for the whole body, rigid-skinned to the skeleton. `with_hands` false leaves the hands and fingers out
## (they are separate meshes in the mesh-swap variant).
func build_skinned(with_hands: bool = true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		if not with_hands and _is_hand(part[0]):
			continue
		_emit_part(st, part, subdiv, part[0], Vector3.ZERO)
	return st.commit()


## The same body with no skin (the cost baseline: one draw, no skeleton).
func build_static() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		_emit_part(st, part, subdiv, -1, Vector3.ZERO)
	return st.commit()


## The parts of one bone in that bone's own space (a puppet piece); null when the bone has no geometry.
func build_bone_mesh(bone: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for part in parts:
		if part[0] == bone:
			_emit_part(st, part, subdiv, -1, rest_global[bone])
			any = true
	return st.commit() if any else null


## A hand as one rigid mesh in the hand bone's space: palm plus fingers, fingers curled (fist) or in line (open).
## Used only by the mesh-swap variant.
func build_hand_mesh(side: String, fist: bool) -> ArrayMesh:
	var hb: int = index["hand_" + side]
	var fb: int = index["fingers_" + side]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		if part[0] == hb:
			_emit_part(st, part, 1, -1, rest_global[hb])
		elif part[0] == fb:
			var pc: Array = part.duplicate()
			var hinge: Vector3 = rest_global[fb]
			if fist:
				var q := Quaternion(Vector3(0, 0, 1), 1.7)
				pc[1] = hinge + q * (part[1] - hinge)
				pc[2] = q * part[2]
			_emit_part(st, pc, 1, -1, rest_global[hb])
	return st.commit()
