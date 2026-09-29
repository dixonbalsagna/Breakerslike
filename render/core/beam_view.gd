class_name BeamView
extends Node3D
## Signature beams and beam clashes (prototype drawBeams): each beam is three additive cylinders (outer glow, body,
## white core) from its tail to its head, faded by age. A beam is laid out from its tail's camera-relative x along its
## direction, never by wrapping its head separately, so a beam that crosses the seam stays one straight piece.
## Reads S.beams and S.game.clash only.

const LAYERS: Array = [[2.4, 4.0, 0.25], [1.3, 3.0, 0.6], [0.5, 2.0, 0.95]]   # width factor, extra pixels, alpha

var _pool: Array = []       # per beam slot: 3 MeshInstance3D
var _flare: MeshInstance3D
var _cyl: CylinderMesh


func _ready() -> void:
	_cyl = CylinderMesh.new()
	_cyl.top_radius = 0.5
	_cyl.bottom_radius = 0.5
	_cyl.height = 1.0
	_cyl.radial_segments = 12
	_cyl.rings = 0
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	_flare = MeshInstance3D.new()
	_flare.mesh = s
	_flare.material_override = RenderMats.glow(Color.WHITE, 1.0, 1.4)
	add_child(_flare)


func update(S: SimState, cam_x: float, z: float) -> void:
	var n: int = 0
	for b in S.beams:
		var k: float = 1.0 if b.t < 0.3 else maxf(0.0, 1.0 - (b.t - 0.3) / (b.life - 0.3))
		var s: float = b.p * b.len
		var tail: float = clampf((b.t - 0.4) / (b.life - 0.4), 0.0, 1.0) * b.len if b.t > 0.4 else 0.0
		var x0: float = SimWrap.sdx(cam_x, b.ox + b.ux * tail)
		var a := Vector2(x0, b.oy + b.uy * tail)
		var e := Vector2(x0 + b.ux * (s - tail), b.oy + b.uy * s)
		_beam(n, a, e, b.w, RenderLook.col(b.col), k, z)
		n += 1
	var c = S.game.clash
	_flare.visible = c != null
	if c != null:
		var p: float = clampf((S.T - c.t0) / c.dur, 0.0, 1.0)
		var mid: float = 0.5 + (1.0 if c.aw else -1.0) * 0.35 * p
		var ax: float = SimWrap.sdx(cam_x, c.A.x)
		var dx: float = SimWrap.sdx(c.A.x, c.D.x)
		var m := Vector2(ax + dx * mid, c.A.y + 38.0 + (c.D.y - c.A.y) * mid)
		_beam(n, Vector2(ax, c.A.y + 38.0), m, 26.0 + c.A.tier * 8.0, RenderLook.col(c.A.aura), 1.0, z)
		_beam(n + 1, Vector2(ax + dx, c.D.y + 38.0), m, 26.0 + c.D.tier * 8.0, RenderLook.col(c.D.aura), 1.0, z)
		n += 2
		_flare.position = Vector3(m.x, m.y, RenderLook.Z_BEAMS + 2.0)
		_flare.scale = Vector3.ONE * 2.0 * (70.0 + 20.0 / z)
	for i in range(n, _pool.size()):
		for mi in _pool[i]:
			mi.visible = false


func _beam(i: int, a: Vector2, e: Vector2, w: float, c: Color, k: float, z: float) -> void:
	while _pool.size() <= i:
		var layers: Array = []
		for L in LAYERS:
			var mi := MeshInstance3D.new()
			mi.mesh = _cyl
			mi.material_override = RenderMats.glow(Color.WHITE, 1.0, 0.7)
			add_child(mi)
			layers.append(mi)
		_pool.append(layers)
	var d: Vector2 = e - a
	var l: float = d.length()
	for j in range(LAYERS.size()):
		var mi: MeshInstance3D = _pool[i][j]
		mi.visible = l > 0.01
		if not mi.visible:
			continue
		var u: Vector2 = d / l
		var th: float = w * LAYERS[j][0] + LAYERS[j][1] / z
		mi.transform = Transform3D(Basis(Vector3(u.y, -u.x, 0.0) * th, Vector3(u.x, u.y, 0.0) * (l + th * 0.5), Vector3(0.0, 0.0, th)), Vector3((a.x + e.x) * 0.5, (a.y + e.y) * 0.5, RenderLook.Z_BEAMS))
		RenderMats.set_glow(mi.material_override, Color.WHITE if j == 2 else c, LAYERS[j][2] * k)
