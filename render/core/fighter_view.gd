class_name FighterView
extends Node3D
## One fighter as a greybox figure of flat-coloured primitives, generated from its roster colours and role (no
## hand-made assets). The layout follows the prototype's drawFighter, in its units: the body pivot sits 34 units above
## f.y and rotates by f.rot (launch spin); the body mirrors by f.face. Readability cues:
## - stance: a badge above the head in the stance colour, a lean (aggressive forward, evasive back) and a guard glow
##   in front in defensive; the HUD labels it too;
## - hit: the body flashes white for RenderLook.HIT_FLASH_S after f.hurtT;
## - tier: the aura grows with tier, and at tier 3+ (or while charging) aura streaks rise from the feet;
## - hidden: the whole figure fades to RenderLook.HIDDEN_ALPHA inside a sonar ripple.
## Reads the fighter only; never writes it.

const PIVOT_Y := 34.0
const HEIGHT := 90.0           # feet to the top of the hair, in world units (for UI's anchors)
## Hair outlines in the prototype's canvas units (x forward, y down), extruded to low-poly prisms. The hero's crest is
## swept back rather than spiked upward, to keep the placeholder away from genre-classic silhouettes.
const HAIR_HERO: Array = [[-10, -30], [-24, -39], [-12, -41], [-19, -49], [-2, -45], [9, -46], [12, -37], [10, -30]]
const HAIR_VILLAIN: Array = [[-11, -30], [-10, -42], [0, -44], [10, -42], [13, -20], [8, -32]]
const CAPE: Array = [[-10, -18], [-30, 22], [-4, 14]]

var pivot := Node3D.new()      # body centre; rotates by f.rot and the stance lean
var body := Node3D.new()       # mirrored by facing
var solid: Array = []          # [MeshInstance3D, base Color, flashes on hit]
var arm_front: MeshInstance3D
var aura: MeshInstance3D
var orb_outer: MeshInstance3D
var orb_core: MeshInstance3D
var badge: MeshInstance3D
var guard: MeshInstance3D
var ripple: MeshInstance3D
var streaks: Array = []
var _faded: bool = false
var _flash: bool = false
var _stance: int = -1
var _aura_col := Color.WHITE


func build(f) -> void:
	name = f.name
	add_child(pivot)
	pivot.position.y = PIVOT_Y
	pivot.add_child(body)
	_aura_col = RenderLook.col(f.aura)
	var legs := RenderLook.col(RenderLook.LEGS)
	_part(_box(Vector3(8, 26, 8)), Vector3(-6, -23, -5), legs, true)
	_part(_box(Vector3(8, 26, 8)), Vector3(6, -23, 5), legs, true)
	if f.role == "villain":
		_part(_extrude(CAPE, 4.0), Vector3(0, 0, -10), RenderLook.col(RenderLook.CAPE), false)
	_part(_box(Vector3(28, 32, 18)), Vector3(0, 4, 0), RenderLook.col(f.col), true)
	var arm := RenderLook.col(RenderLook.ARM)
	var back_arm := _part(_box(Vector3(6, 1, 6)), Vector3.ZERO, arm, true)
	_limb(back_arm, Vector2(-12, 14), Vector2(-20, -4), -10.0)
	arm_front = _part(_box(Vector3(6, 1, 6)), Vector3.ZERO, arm, true)
	var head := SphereMesh.new()
	head.radius = 10.0
	head.height = 20.0
	head.radial_segments = 8
	head.rings = 4
	_part(head, Vector3(0, 30, 0), RenderLook.col(RenderLook.SKIN), true)
	_part(_extrude(HAIR_HERO if f.role == "hero" else HAIR_VILLAIN, 23.0), Vector3.ZERO, RenderLook.col(f.hair), false)
	_part(_box(Vector3(4, 2, 2)), Vector3(5, 31, 10.5), RenderLook.col(RenderLook.EYE), false)
	aura = _glow(_sphere(), _aura_col, 0.55, 1.6)
	pivot.add_child(aura)
	orb_outer = _glow(_sphere(), _aura_col, 0.9, 1.2)
	orb_core = _glow(_sphere(), Color.WHITE, 1.0, 0.8)
	add_child(orb_outer)
	add_child(orb_core)
	for k in range(5):
		var s := _glow(_box(Vector3(2, 1, 2)), _aura_col, 0.6, 0.3)
		add_child(s)
		streaks.append(s)
	var dia := SphereMesh.new()
	dia.radius = 7.0
	dia.height = 16.0
	dia.radial_segments = 4
	dia.rings = 1
	badge = MeshInstance3D.new()
	badge.mesh = dia
	add_child(badge)
	guard = _glow(_sphere(), RenderLook.col(RenderLook.STANCE_COL[1]), 0.4, 0.6)
	add_child(guard)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.93
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.ring_segments = 4
	ripple = _glow(ring, Color(190.0 / 255.0, 220.0 / 255.0, 1.0), 0.55, 0.0)
	ripple.rotation.x = PI * 0.5
	add_child(ripple)


## pose: interpolated [x, y, rot]; vx: the fighter's x relative to the camera; T: sim time; z: camera zoom.
func update(S: SimState, f, pose: Vector3, vx: float, z: float) -> void:
	var T: float = S.T
	position = Vector3(vx, pose.y, 0.0)
	var stance: int = int(f.stance)
	var lean: float = 0.0
	if f.state == "free" or f.state == "locked":
		lean = [-0.12, 0.0, 0.16, 0.05][stance]
	pivot.rotation.z = -pose.z + lean * f.face
	body.scale.x = f.face
	var punch: bool = f.state == "locked" or f.beamCharge != null
	_limb(arm_front, Vector2(12, 14), Vector2(30, 12) if punch else Vector2(22, 0), 10.0)
	var flash: bool = T - f.hurtT < RenderLook.HIT_FLASH_S and T >= f.hurtT
	if f.hidden != _faded or flash != _flash:
		_faded = f.hidden
		_flash = flash
		for p in solid:
			var c: Color = Color.WHITE if (flash and p[2]) else p[1]
			p[0].material_override = RenderMats.flat_alpha(c, RenderLook.HIDDEN_ALPHA) if _faded else RenderMats.flat(c)
	var fade: float = RenderLook.HIDDEN_ALPHA if f.hidden else 1.0
	var tier: float = f.tier
	var ch: bool = f.state == "charging"
	var bc: bool = f.beamCharge != null
	var rad: float = (46.0 + tier * 20.0 + (34.0 if ch else 0.0) + (20.0 if bc else 0.0)) * (1.0 + sin(T * 22.0 + f.x) * 0.04)
	aura.scale = Vector3.ONE * 2.0 * rad
	RenderMats.set_glow(aura.material_override, _aura_col, 0.5 * fade)
	var streak_on: bool = ch or tier >= 3.0
	for k in range(streaks.size()):
		var s: MeshInstance3D = streaks[k]
		s.visible = streak_on
		if streak_on:
			var x0: float = (k - 2) * 10.0 + sin(T * 18.0 + k) * 4.0
			var h: float = 60.0 + tier * 22.0 + (k % 3) * 14.0
			var lean_x: float = sin(T * 9.0 + k) * 6.0
			s.position = Vector3(x0 + lean_x * 0.5, h * 0.5, 4.0)
			s.rotation.z = -atan2(lean_x, h)
			s.scale = Vector3(1.0, h, 1.0)
			RenderMats.set_glow(s.material_override, _aura_col, 0.6 * fade)
	orb_outer.visible = bc
	orb_core.visible = bc
	if bc:
		var p: float = clampf((T - f.beamCharge) / 0.8, 0.0, 1.0)
		var r: float = (10.0 + p * 40.0) + 4.0 / z
		var at := Vector3(f.face * 30.0, 44.0, 8.0)
		orb_outer.position = at
		orb_outer.scale = Vector3.ONE * 2.0 * r
		orb_core.position = at
		orb_core.scale = Vector3.ONE * r * 0.8
	badge.visible = not f.hidden
	badge.position = Vector3(0.0, 84.0 + tier * 3.0 + 8.0, 0.0)
	badge.rotation.y = T * 2.0
	if stance != _stance:
		_stance = stance
		badge.material_override = RenderMats.flat(RenderLook.col(RenderLook.STANCE_COL[stance]), 0.2)
	guard.visible = stance == 1 and not f.hidden and (f.state == "free" or f.state == "locked")
	if guard.visible:
		guard.position = Vector3(f.face * 30.0, PIVOT_Y, 0.0)
		guard.scale = Vector3(12.0, 84.0, 60.0)
	ripple.visible = f.hidden
	if f.hidden:
		var rp: float = fmod(T * 1.2, 1.0)
		ripple.position = Vector3(0.0, 30.0, 0.0)
		ripple.scale = Vector3.ONE * ((20.0 + rp * 60.0) + 6.0 / z)
		RenderMats.set_glow(ripple.material_override, Color(190.0 / 255.0, 220.0 / 255.0, 1.0), 0.55 * (1.0 - rp * 0.6))


func _part(mesh: Mesh, at: Vector3, c: Color, flashes: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.material_override = RenderMats.flat(c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	solid.append([mi, c, flashes])
	return mi


## Stretch a unit-height box between two points in the body plane (y up), at depth z.
static func _limb(mi: MeshInstance3D, a: Vector2, b: Vector2, z: float) -> void:
	var d: Vector2 = b - a
	var l: float = maxf(d.length(), 0.001)
	var u: Vector2 = d / l
	mi.transform = Transform3D(Basis(Vector3(u.y, -u.x, 0.0), Vector3(u.x, u.y, 0.0) * l, Vector3(0.0, 0.0, 1.0)), Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, z))


static func _glow(mesh: Mesh, c: Color, alpha: float, soft: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = RenderMats.glow(c, alpha, soft)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


static func _sphere() -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 16
	s.rings = 8
	return s


## A closed outline (canvas units, y down) extruded into a prism of the given depth, centred on z = 0, with flat
## normals. The procedural path for any 2D silhouette: hair, capes and, later, generated props.
static func _extrude(outline: Array, depth: float) -> ArrayMesh:
	var pts := PackedVector2Array()
	for p in outline:
		pts.append(Vector2(p[0], -p[1]))
	var tri: PackedInt32Array = Geometry2D.triangulate_polygon(pts)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz: float = depth * 0.5
	for i in range(0, tri.size(), 3):
		for k in [0, 1, 2]:
			var p: Vector2 = pts[tri[i + k]]
			st.add_vertex(Vector3(p.x, p.y, hz))
		for k in [2, 1, 0]:
			var p: Vector2 = pts[tri[i + k]]
			st.add_vertex(Vector3(p.x, p.y, -hz))
	for i in range(pts.size()):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		for q in [[a, hz], [b, hz], [a, -hz], [a, -hz], [b, hz], [b, -hz]]:
			st.add_vertex(Vector3(q[0].x, q[0].y, q[1]))
	st.generate_normals()
	return st.commit()
