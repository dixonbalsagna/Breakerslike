class_name VfxCrackMesh
extends RefCounted
## Builds one crack set's mesh (docs/vfx/plan.md section 3): each Line (crack_gen.gd) becomes flat strips draped on the
## ground as drawn (GroundField.ground_at, the CPU twin of the terrain shader), so a crack follows a bowl's wall and
## rim. A line is up to three strips: the dark throat, broken edges a little wider and lighter, and (fissures only) a
## thin lit lip on the far side. The mesh is built once and shared by every pane.
##
## Vertices sit on the crack's centre line; the offset to each side is in CUSTOM0 (ox, oz, u, born) and applied by
## shaders/crack.gdshader, which also widens it to a least thickness on screen (the ground is seen at a grazing angle) and grows
## the web outward from the set's origin: u is the point's distance from the origin over the reach, born the sim time
## it began. Positions are local to the set's origin x, so the mesh has small numbers however far round the planet it is.

const FLAGS: int = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT

var reach: float = 1.0       # the farthest a line goes from the origin (world units), for culling and the growth front
var tris: int = 0
var lines_used: int = 0
var aabb := AABB()


## origin_x: the set's origin (wrapped world x). lines: Array of VfxCrackGen.Line. born: sim time the set began.
## Returns an ArrayMesh, or null when nothing is left to draw (every line ended in water, say).
func build(S: SimState, ground: GroundField, origin_x: float, lines: Array, born: float, biome: String = "plains") -> ArrayMesh:
	reach = 1.0
	for ln in lines:
		for p in ln.pts:
			reach = maxf(reach, p.length())
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var cust := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var lo := Vector3(1e30, 1e30, 1e30)
	var hi := Vector3(-1e30, -1e30, -1e30)
	var core: Color = Color(VfxPalette.crack(biome), VfxLook.CRACK_A_CORE)
	var edge: Color = Color(VfxPalette.dust(biome, "shadow"), VfxLook.CRACK_A_EDGE)
	var lip: Color = Color(VfxPalette.lip(biome), VfxLook.CRACK_A_LIP)
	lines_used = 0
	for ln in lines:
		var pts: PackedVector2Array = _dry_part(S, origin_x, _subdivide(ln.pts, VfxLook.CRACK_SEG))
		if pts.size() < 2:
			continue
		lines_used += 1
		# Height along the line, once: the strips share the centre line.
		var hs := PackedFloat32Array()
		for p in pts:
			hs.append(ground.ground_at(S, SimWrap.wrap(origin_x + p.x), p.y))
		# Broken edges under the throat under the lip, so the order of drawing is the order of the strips.
		_strip(verts, cols, cust, uvs, idx, pts, hs, ln.w0 * (1.9 if ln.fissure else 1.7), 0.0, edge, VfxLook.CRACK_EDGE_PX, born, reach)
		_strip(verts, cols, cust, uvs, idx, pts, hs, ln.w0, 0.0, core, VfxLook.CRACK_CORE_PX, born, reach)
		if ln.fissure:
			_strip(verts, cols, cust, uvs, idx, pts, hs, ln.w0 * 0.22, -ln.w0 * 0.42, lip, VfxLook.CRACK_LIP_PX, born, reach)
	if verts.is_empty():
		return null
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	var w: float = reach * 0.6 + 400.0
	aabb = AABB(Vector3(lo.x - w, lo.y - 400.0, lo.z - 2500.0), Vector3(hi.x - lo.x + 2.0 * w, hi.y - lo.y + 800.0, hi.z - lo.z + 5000.0))
	tris = idx.size() / 3
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_CUSTOM0] = cust
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, FLAGS)
	m.custom_aabb = aabb
	return m


## The part of a line from its source that stays on dry ground (a crack does not run across a lake).
static func _dry_part(S: SimState, origin_x: float, pts: PackedVector2Array) -> PackedVector2Array:
	for i in range(pts.size()):
		if WorldWater.surfaceAt(S, SimWrap.wrap(origin_x + pts[i].x)) != WorldWater.DRY:
			return pts.slice(0, i)
	return pts


## One strip along a polyline: two vertices per point at the centre line (shifted by zshift across the depth, for the lip),
## with the half-width offsets and the least on-screen thickness in CUSTOM0, and UV = (u, born). Width tapers from w.
static func _strip(verts: PackedVector3Array, cols: PackedColorArray, cust: PackedFloat32Array, uvs: PackedVector2Array, idx: PackedInt32Array, pts: PackedVector2Array, hs: PackedFloat32Array, w: float, zshift: float, col: Color, px: float, born: float, set_reach: float) -> void:
	var n: int = pts.size()
	var base: int = verts.size()
	for i in range(n):
		var a: Vector2 = pts[maxi(i - 1, 0)]
		var b: Vector2 = pts[mini(i + 1, n - 1)]
		var t: Vector2 = (b - a).normalized()
		var nrm := Vector2(-t.y, t.x)
		var f: float = float(i) / float(n - 1)
		var taper: float = 1.0 - 0.85 * pow(f, 1.3)   # thick at the source, a fine point only at the far end
		var hw: float = 0.5 * w * taper
		var c: Vector2 = pts[i]
		var u: float = clampf(c.length() / set_reach, 0.0, 1.0)
		for s in [-1.0, 1.0]:
			verts.append(Vector3(c.x, hs[i], c.y + zshift))
			cols.append(col)
			cust.append(nrm.x * hw * s)
			cust.append(nrm.y * hw * s)
			cust.append(px * maxf(taper, 0.3))
			cust.append(0.0)
			uvs.append(Vector2(u, born))
	for i in range(n - 1):
		var k: int = base + i * 2
		idx.append_array(PackedInt32Array([k, k + 1, k + 2, k + 1, k + 3, k + 2]))


## Cut a polyline into pieces no longer than max_seg, so heights sampled at its vertices follow the ground between them
## (a strip is flat between its vertices; a bowl's rim or apron curves faster than a long strip can follow).
static func _subdivide(pts: PackedVector2Array, max_seg: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() == 0:
		return out
	out.append(pts[0])
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var n: int = maxi(1, int(ceil(a.distance_to(b) / max_seg)))
		for k in range(1, n + 1):
			out.append(a.lerp(b, float(k) / float(n)))
	return out
