class_name OutlineBake
extends RefCounted
## Fighter outlines (docs/rendering/outline-normals-plan.md): the direction and reach of the inverted-hull outline,
## baked once into a fighter mesh. A faceted mesh has a copy of each corner per face, each with that face's normal;
## pushed along those, the copies part at every hard edge and the hull cracks. The bake gives every copy at one
## position of one bone the same push:
## - its direction, the angle-weighted mean of the faces' normals there, as the vertex NORMAL: skinning turns it with
##   the bone. (Not TANGENT: the Compatibility renderer's skinning rebuilds the tangent square to the normal, which
##   wrecks a smoothed direction kept there; the outline check caught it.)
## - its reach, 1 / (the least cosine between that direction and those faces), clamped to OUTLINE_F_MAX, in UV2.x: so
##   every face plane there moves out by the full width (a box corner would otherwise draw 42% thin).
## The body no longer reads NORMAL for its facets: fighter_body.gdshader takes each face's normal from the screen-space
## derivatives of its position, exact and free. Positions are never merged across bones: a seam between two bones
## opens as they turn. render/shaders/fighter_hull.gdshader reads both.

const QUANT := 1000.0   # positions are grouped to 1 / QUANT units


## A copy of `mesh` with the outline baked into every triangle surface (materials kept).
static func bake(mesh: ArrayMesh, f_max: float = RenderLook.OUTLINE_F_MAX) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(s)
		if mesh.surface_get_primitive_type(s) == Mesh.PRIMITIVE_TRIANGLES:
			bake_arrays(arr, f_max)
		var keep: int = mesh.surface_get_format(s) & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arr, [], {}, keep)
		out.surface_set_material(s, mesh.surface_get_material(s))
		out.surface_set_name(s, mesh.surface_get_name(s))
	return out


## Bakes one surface's arrays in place: ARRAY_NORMAL (the push direction) and ARRAY_TEX_UV2 (x: its reach).
static func bake_arrays(arr: Array, f_max: float = RenderLook.OUTLINE_F_MAX) -> void:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nv: int = v.size()
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var bones = arr[Mesh.ARRAY_BONES]
	var weights = arr[Mesh.ARRAY_WEIGHTS]
	var bpv: int = 0 if bones == null or nv == 0 else (bones as PackedInt32Array).size() / nv
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(nv))
	# Each vertex's face normal: its own (faceted), or its triangle's (Godot's front faces wind clockwise).
	var fn := PackedVector3Array()
	fn.resize(nv)
	for t in range(0, idx.size() - 2, 3):
		var a: int = idx[t]
		var b: int = idx[t + 1]
		var c: int = idx[t + 2]
		var n: Vector3 = (v[c] - v[a]).cross(v[b] - v[a]).normalized()
		for k in [a, b, c]:
			fn[k] = nrm[k].normalized() if nrm.size() == nv else n
	# Group the copies: one position of one bone.
	var gid := PackedInt32Array()
	gid.resize(nv)
	var groups: Dictionary = {}
	for k in range(nv):
		var key := Vector4i(_bone(bones, weights, bpv, k), roundi(v[k].x * QUANT), roundi(v[k].y * QUANT), roundi(v[k].z * QUANT))
		if not groups.has(key):
			groups[key] = groups.size()
		gid[k] = groups[key]
	var ng: int = groups.size()
	var sum := PackedVector3Array()
	sum.resize(ng)
	for t in range(0, idx.size() - 2, 3):
		var tri: Array = [idx[t], idx[t + 1], idx[t + 2]]
		for j in range(3):
			var k: int = tri[j]
			var p: Vector3 = v[tri[(j + 1) % 3]] - v[k]
			var q: Vector3 = v[tri[(j + 2) % 3]] - v[k]
			var ang: float = p.angle_to(q) if p.length_squared() > 0.0 and q.length_squared() > 0.0 else 0.0
			sum[gid[k]] += fn[k] * ang
	var dir := PackedVector3Array()
	dir.resize(ng)
	var least := PackedFloat32Array()
	least.resize(ng)
	least.fill(1.0)
	for k in range(nv):
		var g: int = gid[k]
		if dir[g] == Vector3.ZERO:
			dir[g] = sum[g].normalized() if sum[g].length_squared() > 1e-12 else fn[k]
		least[g] = minf(least[g], dir[g].dot(fn[k]))
	var out_n := PackedVector3Array()
	out_n.resize(nv)
	var uv2 := PackedVector2Array()
	uv2.resize(nv)
	for k in range(nv):
		var g: int = gid[k]
		out_n[k] = dir[g]
		uv2[k] = Vector2(clampf(1.0 / maxf(least[g], 1.0 / f_max), 1.0, f_max), 0.0)
	arr[Mesh.ARRAY_NORMAL] = out_n
	arr[Mesh.ARRAY_TANGENT] = null
	arr[Mesh.ARRAY_TEX_UV2] = uv2


## The bone a vertex follows (its heaviest; 0 for an unskinned mesh).
static func _bone(bones, weights, bpv: int, k: int) -> int:
	if bpv == 0:
		return 0
	var best: int = 0
	var bw: float = -1.0
	for j in range(bpv):
		var w: float = (weights as PackedFloat32Array)[k * bpv + j] if weights != null else (1.0 if j == 0 else 0.0)
		if w > bw:
			bw = w
			best = (bones as PackedInt32Array)[k * bpv + j]
	return best
