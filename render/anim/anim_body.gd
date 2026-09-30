class_name AnimBody
extends Node3D
## One view of a mannequin: a Skeleton3D and one rigid-skinned MeshInstance3D (plus the outline pass), in the model's own
## space (feet at the node's origin, facing +x). FighterView puts it in the body node, PANE by pane; the pose comes from
## a per-fighter AnimFighter that is solved once a frame and written to every pane's body. Render only.

var skel: Skeleton3D
var mi: MeshInstance3D
var _mat: ShaderMaterial      # the body (RenderMats.fighter_body); its next_pass is the outline (fighter_hull)
var _hull: ShaderMaterial
var _fingers_l: int
var _fingers_r: int
var _flash: float = 0.0

## Palette keys: body, legs, arms, skin, gear, accent, hair (Colors). game true uses the hybrid projection (the game's
## fighters); false the plain perspective path (tools).
func build(pal: Dictionary, game: bool = true) -> void:
	AnimRig.setup()
	skel = AnimRig.make_skeleton()
	add_child(skel)
	mi = MeshInstance3D.new()
	mi.mesh = AnimRig.mesh_for(pal)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skel.add_child(mi)
	mi.skin = skel.create_skin_from_rest_transforms()
	mi.skeleton = NodePath("..")
	_mat = RenderMats.fighter_body(Color.WHITE)
	_hull = _mat.next_pass
	if not game:
		_mat.set_shader_parameter("ortho", 0.0)
		_hull.set_shader_parameter("ortho", 0.0)
	mi.material_override = _mat
	_fingers_l = AnimRig.index["fingers_l"]
	_fingers_r = AnimRig.index["fingers_r"]


## Writes a solved pose: local rotations, the pelvis offset, the finger curl of each hand and a cosmetic root offset.
func apply(q: Array[Quaternion], hips: Vector3, curl: Vector2, root_off: Vector3 = Vector3.ZERO) -> void:
	for i in range(AnimRig.N):
		skel.set_bone_pose_rotation(i, q[i])
	skel.set_bone_pose_position(0, root_off)
	skel.set_bone_pose_position(1, AnimRig.rest_local[1] + hips)   # a bone pose is an absolute local transform, not an offset from rest
	skel.set_bone_pose_rotation(_fingers_l, q[_fingers_l] * Quaternion(Vector3(0, 0, 1), curl.x))
	skel.set_bone_pose_rotation(_fingers_r, q[_fingers_r] * Quaternion(Vector3(0, 0, 1), curl.y))


## The hybrid projection's anchor (world space), on both the body and its outline pass.
func set_anchor(a: Vector3) -> void:
	_mat.set_shader_parameter("anchor", a)
	_hull.set_shader_parameter("anchor", a)


## The hit flash (0 to 1). (Hidden fighters have no translucent variant on the baked body yet: hiding left the base game.)
func set_look(flash: float, _hidden: bool) -> void:
	if flash != _flash:
		_flash = flash
		_mat.set_shader_parameter("albedo", Color(1, 1, 1) if flash <= 0.0 else Color(8, 8, 8))
