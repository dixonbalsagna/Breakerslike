class_name CrowdMesh
## The civilian figure, generated: legs, torso, arms and head as boxes (front view, so the silhouette reads as a
## person at a few pixels), plus a dark outline shell. Feet at y = 0, about 17 units tall. UV.x tags each part for
## render/shaders/crowd.gdshader: 0 outline, 0.5 shirt, 0.8 skin, 1 trousers. (Not COLOR: in 4.7.2 Compatibility a
## MultiMesh without instance colours multiplies COLOR by zero.)

## [centre, half extents, tag]
const PARTS: Array = [
	[Vector3(-1.05, 3.6, 0.0), Vector3(0.8, 3.6, 0.9), 1.0],
	[Vector3(1.05, 3.6, 0.0), Vector3(0.8, 3.6, 0.9), 1.0],
	[Vector3(0.0, 10.2, 0.0), Vector3(2.4, 3.2, 1.3), 0.5],
	[Vector3(-3.25, 10.0, 0.0), Vector3(0.7, 3.0, 0.8), 0.5],
	[Vector3(3.25, 10.0, 0.0), Vector3(0.7, 3.0, 0.8), 0.5],
	[Vector3(0.0, 15.4, 0.0), Vector3(1.7, 1.8, 1.6), 0.8],
]
const HEIGHT := 17.2


static func build() -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedVector2Array()
	for p in PARTS:
		_box(v, n, c, p[0], p[1], p[2], false)
	for p in PARTS:
		_box(v, n, c, p[0], p[1], 0.0, true)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = c
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## One box. The body faces outward with flat normals; the shell faces inward (so only its far side draws, around the
## silhouette) and its normals point at the corners, the direction the shader pushes it out along.
static func _box(v: PackedVector3Array, n: PackedVector3Array, c: PackedVector2Array, ctr: Vector3, h: Vector3, tag: float, shell: bool) -> void:
	for axis in range(3):
		for sgn in [-1.0, 1.0]:
			var nrm := Vector3.ZERO
			nrm[axis] = sgn
			var u: int = (axis + 1) % 3
			var w: int = (axis + 2) % 3
			var q: Array = []
			for s in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
				var p := ctr
				p[axis] += sgn * h[axis]
				p[u] += s[0] * h[u]
				p[w] += s[1] * h[w]
				q.append(p)
			for t in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = q[t[0]]
				var b: Vector3 = q[t[1]]
				var d: Vector3 = q[t[2]]
				# Godot's front faces wind clockwise as seen from their front.
				var want: Vector3 = -nrm if shell else nrm
				if (b - a).cross(d - a).dot(want) > 0.0:
					var tmp := b
					b = d
					d = tmp
				for p in [a, b, d]:
					v.append(p)
					n.append(((p - ctr).sign()).normalized() if shell else nrm)
					c.append(Vector2(tag, 0.0))
