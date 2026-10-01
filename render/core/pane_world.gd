class_name PaneWorld
extends Node3D
## One camera's view of the world (docs/camera/split-screen.md section 11): the camera rig, the planet, the fighters,
## the beams, the particles and the sky, and the per-camera material state they draw with (RenderMats). The main
## scene holds one in its own world. Camera's split screen puts two in SubViewports with a World3D each
## (main.gd make_pane and move_pane0).
##
## The first pane runs the world's render-side logic: the ground uploads, the props, the flight and the startle, and
## the head flashes' state machines with their hooks to Audio and UI. A second pane has it as its `source`: it shares
## the planet's meshes, ground data and props, and its fighters' flashes follow the first pane's. Its own nodes and
## materials carry its camera (the floating origin, the curvature, the sky, the fore rule, the crowd's boost, the
## fighters' anchors), so a second pane costs nodes and draw submission, not memory or logic.

const SHADOW_SHADER: Shader = preload("res://render/shaders/shadow.gdshader")

var mats := RenderMats.new()
var cam_rig := CameraRig.new()
var env := WorldEnvironment.new()
var planet := PlanetView.new()
var fighters_root := Node3D.new()
var beams := BeamView.new()
var particles := ParticleView.new()
var vfx_layer := VfxLayer.new()    # VFX's drawing for this pane (render/vfx/); main sets its hub, which every pane shares
var fighter_views: Array = []
var shadows: Array = []            # per fighter: the ground shadow under him (render/shaders/shadow.gdshader)
var source: PaneWorld = null       # a second pane: the first, whose world it draws
var view_cam_x: float = 0.0        # this frame's camera's wrapped world x
var _sky_mat: ShaderMaterial


func _init() -> void:
	name = "Pane"
	cam_rig.name = "Camera"
	env.name = "Environment"
	planet.name = "Planet"
	fighters_root.name = "Fighters"
	beams.name = "Beams"
	particles.name = "Particles"
	vfx_layer.name = "Vfx"
	planet.mats = mats
	for n in [cam_rig, env, planet, fighters_root, beams, particles, vfx_layer]:
		add_child(n)
	_setup_environment()


## A new match: the planet and the fighters. A second pane builds after the first.
func build(S: SimState) -> void:
	planet.source = source.planet if source != null else null
	planet.build(S)
	for v in fighter_views:
		fighters_root.remove_child(v)
		v.free()
	fighter_views.clear()
	for i in range(S.fighters.size()):
		var v := FighterView.new()
		fighters_root.add_child(v)
		v.build(S.fighters[i])
		if source != null and i < source.fighter_views.size():
			v.flash_view.set_leader(source.fighter_views[i].flash_view)
		fighter_views.append(v)
		if i >= shadows.size():
			# kept across matches (its material is tracked for the pane's bend once)
			var sh := MeshInstance3D.new()
			sh.name = "Shadow%d" % i
			sh.mesh = _shadow_mesh()
			var sm := ShaderMaterial.new()
			sm.shader = SHADOW_SHADER
			mats.track(sm)
			sh.material_override = sm
			sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fighters_root.add_child(sh)
			shadows.append(sh)
	vfx_layer.build(S)


## Draw one frame from a camera: its wrapped world x (float64), cam.y and cam.z (the reference camera's height and
## zoom, as SimHost.camera gives them) and its screen shake in pixels. The first pane also applies the world's changes.
func render(host: SimHost, a: float, cam_x: float, cam: Vector3, jitter: Vector2) -> void:
	var S: SimState = host.S
	var vp: Vector2 = get_viewport().get_visible_rect().size
	view_cam_x = cam_x
	cam_rig.frame(cam.y, cam.z, jitter, vp.y)
	planet.set_camera(cam_rig.position)
	_view_cues(cam, vp)
	planet.update(S, cam_x, host.impact.heat, host.impact.heat_changed)
	var rects: Array = []
	var holes: Array = []
	for i in range(fighter_views.size()):
		var v: FighterView = fighter_views[i]
		var pose: Vector3 = host.fighter_pose(i, a)
		var wx: float = host.fighter_x(i, a)
		var vx: float = SimWrap.sdx(cam_x, wx)
		v.depth = host.fighter_z(i, a)
		v.sag = mats.sag(vx, v.depth)
		v.update(S, S.fighters[i], pose, vx, cam.z)
		rects.append(_screen_rect(v))
		holes.append(_hole(S, S.fighters[i], v, rects[i], cam_x))
		_place_shadow(S, i, wx, vx, pose.y, v.depth)
	planet.fade_front(S, cam_rig, cam_x, rects)
	planet.set_holes(holes)
	vfx_layer.update(host, a, cam_x, cam.z, vp.x)
	beams.update(S, cam_x, cam.z)
	particles.update(host.fxv, host.impact, cam_x, cam.z, cam_rig.half_width(vp.x, RenderLook.Z_PARTICLES))


## The porthole that keeps a fighter in the building rows in view (building.gdshader): [his chest as drawn, the radius
## in pixels (0 on the fighter plane, opening as he goes in), the view distance buildings are cut up to]. It stops
## short of the front of the building he is aimed at, so that one stays whole and only its cut floors show him inside.
func _hole(S: SimState, f, v: FighterView, rect: Rect2, cam_x: float) -> Array:
	if v.depth > -1.0 or rect.size.y <= 0.0:
		return [Vector3.ZERO, 0.0, 0.0]
	var chest: Vector3 = v.global_position + Vector3(0.0, FighterView.HEIGHT * 0.5, 0.0)
	var inv: Transform3D = cam_rig.global_transform.affine_inverse()
	var near: float = -(inv * chest).z - RenderLook.HOLE_GAP
	if int(f.aimB) >= 0 and int(f.aimB) < S.buildings.size():
		var b = S.buildings[int(f.aimB)]
		if b.d > 0.0:
			var front := Vector3(SimWrap.sdx(cam_x, b.x), chest.y, b.z + b.d * 0.5)
			near = minf(near, -(inv * front).z - RenderLook.HOLE_GAP)
	var r: float = maxf(RenderLook.HOLE_PX, RenderLook.HOLE_BODY * rect.size.y) * clampf(-v.depth / RenderLook.HOLE_IN, 0.0, 1.0)
	return [chest, r, near]


static func _shadow_mesh() -> PlaneMesh:
	var m := PlaneMesh.new()
	m.size = Vector2.ONE
	return m


## A fighter's ground shadow: on the ground as drawn under him at his depth (or the water over it), fainter and wider
## the higher he flies. It is what shows where he is over the ground when a launch carries him into the rows.
func _place_shadow(S: SimState, i: int, wx: float, vx: float, y: float, z: float) -> void:
	var sh: MeshInstance3D = shadows[i]
	var g: float = maxf(planet.ground.ground_at(S, wx, z), WorldWater.surfaceAt(S, wx))
	var up: float = clampf((y - g) / RenderLook.SHADOW_FADE_H, 0.0, 1.0)
	sh.visible = y >= g - 1.0
	sh.position = Vector3(vx, g + RenderLook.SHADOW_LIFT, z)
	sh.scale = Vector3(RenderLook.SHADOW_W * (1.0 + 0.5 * up), 1.0, RenderLook.SHADOW_D * (1.0 + 0.5 * up))
	(sh.material_override as ShaderMaterial).set_shader_parameter("strength", RenderLook.SHADOW_ALPHA * lerpf(1.0, 0.25, up))


## A fighter's rectangle on this pane's screen (feet to the top of the head, a body's width), a little grown.
func _screen_rect(v: FighterView) -> Rect2:
	var feet: Vector3 = v.global_position
	var top: Vector3 = feet + Vector3(0.0, FighterView.HEIGHT, 0.0)
	if cam_rig.is_position_behind(feet):
		return Rect2()
	var a: Vector2 = cam_rig.unproject_position(feet)
	var b: Vector2 = cam_rig.unproject_position(top)
	var h: float = absf(a.y - b.y)
	return Rect2(Vector2(a.x - 0.3 * h, minf(a.y, b.y)), Vector2(0.6 * h, h)).grow(0.1 * h)


## Planet-scale cues and crowd legibility for this frame, from the zoom and the camera height (presentation only).
func _view_cues(c: Vector3, vp: Vector2) -> void:
	var wide: float = smoothstep(log(RenderLook.ZOOM_CLOSE), log(RenderLook.ZOOM_WIDE), log(maxf(c.z, 1e-6)))
	var high: float = smoothstep(RenderLook.HIGH_FROM, RenderLook.HIGH_TO, c.y)
	var d: float = lerpf(RenderLook.CURVE_NEAR, RenderLook.CURVE_WIDE, wide) + RenderLook.CURVE_HIGH * high
	# Every layer from full depth weight back sags d * vh pixels at its screen edge (bend.gdshaderinc).
	var dist: float = cam_rig.position.z
	mats.set_bend(4.0 * d * vp.y * c.z / (vp.x * vp.x), dist)
	# The horizon is the far edge of the ground: its elevation from the camera anchors the sky and the fog.
	var hz: float = (0.0 - cam_rig.position.y) / (dist + RenderLook.FOG_FAR)
	for k in [["space", high], ["horizon", hz]]:
		_sky_mat.set_shader_parameter(k[0], k[1])
		mats.set_sky(k[0], k[1])
	var boost: float = clampf(RenderLook.CROWD_MIN_PX / (CrowdMesh.HEIGHT * RenderLook.CROWD_SCALE * c.z), 1.0, RenderLook.CROWD_BOOST_MAX)
	# The shell's push directions are unit corner diagonals, so each axis moves 1/sqrt(3) of the width.
	planet.set_crowd_view(boost, 1.732 * RenderLook.CROWD_OUTLINE_PX / (c.z * RenderLook.CROWD_SCALE))


func _setup_environment() -> void:
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = preload("res://render/shaders/sky.gdshader")
	var skyp: Dictionary = {
		"sky_top": RenderLook.col(RenderLook.SKY[0]), "sky_upper": RenderLook.col(RenderLook.SKY[1]),
		"sky_lower": RenderLook.col(RenderLook.SKY[2]), "sky_horizon": RenderLook.col(RenderLook.SKY[3]),
		"sky_tan": tan(deg_to_rad(RenderLook.FOV_DEG) * 0.5), "sky_lower_at": RenderLook.SKY_LOWER_AT,
		"sky_upper_at": RenderLook.SKY_UPPER_AT, "sky_top_at": RenderLook.SKY_TOP_AT, "sky_thin": RenderLook.SKY_THIN,
		"fog_band": RenderLook.FOG_BAND,
	}
	for k in skyp:
		_sky_mat.set_shader_parameter(k, skyp[k])
		mats.set_sky(k, skyp[k])
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
