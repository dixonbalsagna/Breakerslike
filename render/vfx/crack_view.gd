class_name VfxCrackView
extends Node3D
## One pane's ground cracks (docs/vfx/plan.md section 3). The hub keeps the crack sets (one per crater or slide record);
## this pane keeps a MeshInstance3D for each, sharing the set's mesh with every other pane, one material per pane
## (it carries this pane's curvature through RenderMats.track and the sim time). The first pane to draw a frame builds
## the meshes the hub has queued, a couple per frame, from the ground as drawn (planet.ground), so a crack is draped
## on the ground the renderer has just uploaded. Only the nearest few sets are visible at once. Reads only.

var mats: RenderMats               # this pane's material state (the curvature)
var ground: GroundField            # the planet's ground field, for building meshes
var mat: ShaderMaterial
var built_frame: int = -1          # for the tests
var visible_count: int = 0
var built_now: int = 0
var _items: Dictionary = {}        # set key -> MeshInstance3D


func _init() -> void:
	name = "Cracks"
	mat = ShaderMaterial.new()
	mat.shader = preload("res://render/vfx/shaders/crack.gdshader")
	mat.render_priority = 0
	mat.set_shader_parameter("grow_t", VfxLook.CRACK_GROW_S)


func attach(p_mats: RenderMats, p_ground: GroundField) -> void:
	ground = p_ground
	if p_mats != mats:
		mats = p_mats
		if mats != null:
			mats.track(mat)


## cam_x: this pane's wrapped camera x; half_w: half the visible width at the fighter plane (world units); zoom: pixels per unit there.
func update(hub: VfxHub, S: SimState, cam_x: float, half_w: float, zoom: float) -> void:
	visible_count = 0
	built_now = 0
	mat.set_shader_parameter("now", S.T)
	mat.set_shader_parameter("px_world", 1.0 / maxf(zoom, 1e-6))
	# Build what the hub has queued (any pane may; the mesh is shared). A build needs the ground field.
	var built: int = 0
	while built < VfxLook.CRACK_BUILD_PER_FRAME and not hub.crack_pending.is_empty() and ground != null:
		hub.build_next_crack(S, ground)
		built += 1
	built_now = built
	# Drop instances whose set the hub no longer keeps.
	if _items.size() > hub.crack_sets.size():
		var live: Dictionary = {}
		for cs in hub.crack_sets:
			live[cs.id] = true
		for k in _items.keys():
			if not live.has(k):
				_items[k].queue_free()
				_items.erase(k)
	# Nearest sets, up to the cap.
	var cand: Array = []
	for cs in hub.crack_sets:
		if cs.mesh == null:
			continue
		var vx: float = SimWrap.sdx(cam_x, cs.x)
		var near: float = absf(vx) - cs.reach
		if near > half_w * 1.3:
			continue
		cand.append([near, vx, cs])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var seen: Dictionary = {}
	for i in range(mini(cand.size(), VfxLook.CRACK_VISIBLE_MAX)):
		var cs = cand[i][2]
		var mi: MeshInstance3D = _items.get(cs.id)
		if mi == null:
			mi = MeshInstance3D.new()
			mi.mesh = cs.mesh
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_items[cs.id] = mi
		mi.visible = true
		mi.position = Vector3(cand[i][1], 0.0, 0.0)
		seen[cs.id] = true
		visible_count += 1
	for k in _items:
		if not seen.has(k):
			_items[k].visible = false


func clear() -> void:
	for k in _items:
		_items[k].queue_free()
	_items.clear()
