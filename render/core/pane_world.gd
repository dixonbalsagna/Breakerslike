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
## How a building between the camera and a fighter is opened (docs/rendering/README.md, "Occlusion").
const OCCL_HOLE := 0     # a round hole around him (Orb's pick)
const OCCL_STUB := 1     # the building cut down to a low stub

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
var markers: bool = true           # the fighters' head markers (the stance badge); main's inset pane has none
var occlusion: int = OCCL_HOLE     # main sets it (a debug toggle)
## Camera's request for this pane's cut-away, each frame (docs/camera/camera-v2.md section 6). Every key is optional:
## request (false: no cut-away, for a shot that wants the wall whole), radius_px (the hole's radius; 0 or absent:
## RenderLook's rule), only (a fighter slot: only his; absent or -1: both fighters').
var cutaway: Dictionary = {}
var occluded: Array = []           # per fighter: a building stands between this pane's camera and him (for Camera)
var _join: float = 0.0             # 0 to 1: the two fighters' holes grown into one
var _join_t: float = -1.0
var _cue := PackedFloat32Array()   # per fighter: his lane cue, 0 to 1
var _cue_z := PackedFloat32Array() # ... his depth at the last tick seen,
var _cue_want: Array = []          # ... and whether the cue was wanted then
var _cue_t: float = -1.0
static var clouds_on: bool = true          # the sky's clouds (main's --noclouds)
static var sky_calm: bool = false          # reduced motion: the clouds stand still and nothing parts (main sets it)
static var sky_react_on: bool = false      # the clouds part for a fighter at tier 3 or more: off unless asked for (main's --skyreact; QA's GB-002)
var _react := PackedFloat32Array()         # per fighter: the sky's reaction to him, 0 to 1 (tier 3 half, tier 4 full)
var _react_t: float = -1.0
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
		v.markers = markers
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
## zoom, as SimHost.camera gives them), its screen shake in pixels and its pitch in degrees (CameraRig). The first pane
## also applies the world's changes.
func render(host: SimHost, a: float, cam_x: float, cam: Vector3, jitter: Vector2, pitch: float = 0.0) -> void:
	var S: SimState = host.S
	var vp: Vector2 = get_viewport().get_visible_rect().size
	view_cam_x = cam_x
	cam_rig.frame(cam.y, cam.z, jitter, vp.y, pitch)
	planet.set_camera(cam_rig.position)
	_view_cues(cam, vp)
	if source == null and host.vfx.enabled and host.vfx.react_enabled:
		planet.blow_windows(S, host.vfx.react.blowouts)   # the facades' windows go out with VFX's glass
	planet.update(S, cam_x, host.impact.heat, host.impact.heat_changed)
	for i in range(fighter_views.size()):
		var v: FighterView = fighter_views[i]
		var pose: Vector3 = host.fighter_pose(i, a)
		var wx: float = host.fighter_x(i, a)
		var vx: float = SimWrap.sdx(cam_x, wx)
		v.depth = host.fighter_z(i, a)
		v.sag = mats.sag(vx, v.depth)
		v.markers = markers and not host.intro_running()   # no head badge before the clock: UI's HUD is hidden too
		v.update(S, S.fighters[i], pose, vx, cam.z)
		_place_shadow(S, i, wx, vx, pose.y, v.depth)
	_occlusion(S, cam_x, vp)
	_lane_cues(host, a)
	_sky_react(host, cam_x)
	vfx_layer.update(host, a, cam_x, cam.z, vp.x)
	beams.update(S, cam_x, cam.z)
	particles.update(host.fxv, host.impact, cam_x, cam.z, cam_rig.half_width(vp.x, RenderLook.Z_PARTICLES), fighter_views)


## Keep the fighters in view behind buildings, by this pane's method. Either way a building counts as in front of a
## fighter when it stands between this pane's camera and his chest, and the building a launched fighter is aimed at
## stays whole (its cut floors show him inside).
## The hole: a dithered circle around each fighter, cutting whatever of a building is nearer the camera than he is. It
## is always there, so a wall is eaten as he passes behind it and nothing pops. When both fighters are in view within
## HOLE_JOIN of the screen's width and buildings are in front of at least two of the three points (each fighter and
## the point between them), each hole stretches to the other fighter, so one opening shows both and the gap between
## them. A fighter behind a wall and one out in the open keep two round holes.
## The stub: the buildings near a fighter's sight line, and those in front of the stretch between two fighters in view
## together, sink to low stubs and stand again when no longer in the way.
func _occlusion(S: SimState, cam_x: float, vp: Vector2) -> void:
	var n: int = fighter_views.size()
	var eye: Vector3 = cam_rig.position
	var on: bool = bool(cutaway.get("request", true))
	var only: int = int(cutaway.get("only", -1))
	var chest: Array = []
	var px: Array = []
	var tall := PackedFloat32Array()
	var seen: Array = []
	var aim := PackedInt32Array()
	var near_view := Rect2(-0.25 * vp, 1.5 * vp)
	var xa: float = eye.x
	var xb: float = eye.x
	var z_min: float = INF
	for i in range(n):
		var v: FighterView = fighter_views[i]
		var c: Vector3 = v.position + Vector3(0.0, FighterView.HEIGHT * 0.5, 0.0)
		var vis: bool = not cam_rig.is_position_behind(c)
		var p: Vector2 = cam_rig.unproject_position(c) if vis else Vector2.ZERO
		vis = vis and near_view.has_point(p)
		chest.append(c)
		px.append(p)
		tall.append(absf(cam_rig.unproject_position(v.position + Vector3(0.0, FighterView.HEIGHT, 0.0)).y - cam_rig.unproject_position(v.position).y) if vis else 0.0)
		seen.append(vis)
		var f = S.fighters[i]
		aim.append(int(f.aimB) if int(f.aimB) >= 0 and int(f.aimB) < S.buildings.size() else -1)
		if vis:
			xa = minf(xa, c.x)
			xb = maxf(xb, c.x)
			z_min = minf(z_min, c.z)
	var cand: Array = planet.occluder_candidates(S, cam_x, xa, xb, z_min, RenderLook.STUB_MARGIN) if z_min < INF else []
	occluded.resize(n)
	for i in range(n):
		occluded[i] = seen[i] and not cand.is_empty() and planet.occluders(S, cand, eye, cam_x, chest[i], RenderLook.OCCL_MARGIN, aim[i], {})
	var pair: bool = n == 2 and only < 0 and seen[0] and seen[1] and (px[0] as Vector2).distance_to(px[1]) < RenderLook.HOLE_JOIN * vp.x
	# The stubs.
	var want: Dictionary = {}
	if on and occlusion == OCCL_STUB and not cand.is_empty():
		for i in range(n):
			if seen[i] and (only < 0 or only == i):
				planet.occluders(S, cand, eye, cam_x, chest[i], RenderLook.STUB_MARGIN, aim[i], want)
		if pair:
			var steps: int = clampi(int((chest[0] as Vector3).distance_to(chest[1]) / RenderLook.STUB_SPAN), 1, 8)
			for k in range(1, steps):
				planet.occluders(S, cand, eye, cam_x, (chest[0] as Vector3).lerp(chest[1], float(k) / steps), RenderLook.OCCL_MARGIN, -1, want)
			for bi in aim:
				want.erase(bi)
	planet.set_stubs(S, want)
	# The holes.
	var holes: Array = []
	var inv: Transform3D = cam_rig.transform.affine_inverse()
	for i in range(n):
		if not on or occlusion != OCCL_HOLE or not seen[i] or (only >= 0 and only != i):
			holes.append([Vector3.ZERO, 0.0, 0.0, Vector3.ZERO, 0.0, 0.0])
			continue
		var r: float = float(cutaway.get("radius_px", 0.0))
		if r <= 0.0:
			r = maxf(RenderLook.HOLE_PX, RenderLook.HOLE_BODY * tall[i])
		var near: float = -(inv * (chest[i] as Vector3)).z - RenderLook.HOLE_GAP
		if aim[i] >= 0:
			var b = S.buildings[aim[i]]
			if b.d > 0.0:
				near = minf(near, -(inv * Vector3(SimWrap.sdx(cam_x, b.x), (chest[i] as Vector3).y, b.z + b.d * 0.5)).z - RenderLook.HOLE_GAP)
		holes.append([chest[i], r, near, chest[i], r, near])
	var join: bool = false
	if pair and on and occlusion == OCCL_HOLE and not cand.is_empty() and (occluded[0] or occluded[1]):
		var mid: bool = planet.occluders(S, cand, eye, cam_x, ((chest[0] as Vector3) + chest[1]) * 0.5, RenderLook.OCCL_MARGIN, -1, {})
		join = int(occluded[0]) + int(occluded[1]) + int(mid) >= 2
	var dt: float = clampf(PlanetView.tick_time(S) - _join_t, 0.0, 0.1) if _join_t >= 0.0 else 1.0e3
	_join_t = PlanetView.tick_time(S)
	_join = move_toward(_join, 1.0 if join else 0.0, dt / RenderLook.HOLE_JOIN_S)
	if _join > 0.0 and n == 2 and float(holes[0][1]) > 0.0 and float(holes[1][1]) > 0.0:
		# Each hole reaches toward the other fighter, its radius and its depth easing to his along the way.
		var e: float = _join * _join * (3.0 - 2.0 * _join)
		var r0: Array = [holes[0][1], holes[0][2]]
		var r1: Array = [holes[1][1], holes[1][2]]
		holes[0][3] = (chest[0] as Vector3).lerp(chest[1], e)
		holes[0][4] = lerpf(r0[0], r1[0], e)
		holes[0][5] = lerpf(r0[1], r1[1], e)
		holes[1][3] = (chest[1] as Vector3).lerp(chest[0], e)
		holes[1][4] = lerpf(r1[0], r0[0], e)
		holes[1][5] = lerpf(r1[1], r0[1], e)
	planet.set_holes(holes)


## The next frame's stubs, joined hole and lane cues jump to their targets instead of easing (for tools that pose a
## frame).
func snap_occlusion() -> void:
	planet.snap_stubs()
	_join_t = -1.0
	_cue_t = -1.0
	_react_t = -1.0
	for v in fighter_views:
		v.snap_damage()


## The sky (render/shaders/sky.gdshader): its clouds drift with the camera's place round the planet and a slow wind.
## That is all of it unless sky_react_on is set (off by default since QA's GB-002 came back: a gap that follows a
## fighter read as a glowing patch over him; docs/rendering/sky-gap-anchored.md is the version that would not follow).
## With it on, from tier 3 the clouds part for a fighter (docs/design/rule-of-cool.md feature 12; nothing below tier 3): a gap
## in the cloud band above him with its edge lit in his colour, half at tier 3 and full at tier 4, easing over
## SKY_REACT_S of tick time. Only for a fighter this pane shows: it fades out as he leaves the screen, so no gap hangs
## in the sky for someone the player cannot see (QA's GB-002). It never darkens the sky (Legal). It stands down while
## he charges or transforms, as VFX's rubble and cracks do (the stacking rule, rule 9 of the list: his own show has
## the moment). With reduced motion (sky_calm) nothing parts.
func _sky_react(host: SimHost, cam_x: float) -> void:
	var S: SimState = host.S
	var n: int = fighter_views.size()
	var now: float = PlanetView.tick_time(S)
	var snap: bool = _react_t < 0.0 or _react.size() != n
	var dt: float = 0.0 if snap else clampf(now - _react_t, 0.0, 0.1)
	_react_t = now
	if _react.size() != n:
		_react.resize(n)
		_react.fill(0.0)
	var dirs: Array = []
	var cols := PackedColorArray()
	for i in range(2):
		var w: float = 0.0
		var d := Vector3(0.0, 0.0, -1.0)
		var c := Color.BLACK
		if i < n:
			var f = S.fighters[i]
			var want: float = 0.0 if not sky_react_on or _busy(host, i) else clampf((float(f.tier) - 2.0) / 2.0, 0.0, 1.0)
			_react[i] = want if snap else move_toward(_react[i], want, dt / RenderLook.SKY_REACT_S)
			var v: FighterView = fighter_views[i]
			var chest: Vector3 = v.position + Vector3(0.0, FighterView.HEIGHT * 0.5, 0.0)
			d = (chest - cam_rig.position).normalized()
			c = v._aura_col
			w = _react[i] * _on_screen(chest)
		dirs.append(Vector4(d.x, d.y, d.z, w))
		cols.append(c)
	_sky_mat.set_shader_parameter("sky_react", dirs)
	_sky_mat.set_shader_parameter("sky_react_col", cols)
	_sky_mat.set_shader_parameter("cloud_on", 1.0 if clouds_on else 0.0)
	_sky_mat.set_shader_parameter("cloud_part", 1.0 if sky_react_on and not sky_calm else 0.0)
	_sky_mat.set_shader_parameter("cloud_shift", SimWrap.wrap(cam_x) / SimConst.W * RenderLook.CLOUD_PERIOD + (0.0 if sky_calm else now * RenderLook.CLOUD_WIND))


## How far a point of this pane's world is on its screen: 1 on it, falling to 0 over SKY_REACT_OFF of the screen's
## width past an edge (0 behind the camera).
func _on_screen(at: Vector3) -> float:
	if cam_rig.is_position_behind(at):
		return 0.0
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var p: Vector2 = cam_rig.unproject_position(at)
	var out: float = maxf(maxf(-p.x, p.x - vp.x), maxf(-p.y, p.y - vp.y))
	return 1.0 - smoothstep(0.0, RenderLook.SKY_REACT_OFF * vp.x, out)


## Whether fighter i is charging or transforming now (VFX's own test, render/vfx/react.gd, plus the sim's state for a
## build with VFX off).
static func _busy(host: SimHost, i: int) -> bool:
	var S: SimState = host.S
	var f = S.fighters[i]
	if f.state == "charging" or f.beamCharge != null or ("breakIn" in f.act and int(f.act.breakIn) >= 0) or (S.pause.left > 0 and int(S.pause.actor) == i):
		return true
	if host.vfx.enabled:
		for fm in host.vfx.xform.forms:
			if int(fm.slot) == i:
				return true
	return false


## The lane cue (RenderLook.LANE_CUE_*): a stripe on the ground at a fighter's depth, in his colour, while it says
## something: the two fighters are at different depths, or his own depth is changing. It eases on tick time (PlanetView.tick_time), from the
## sim's depths tick by tick (the drawn stripe follows his interpolated position).
func _lane_cues(host: SimHost, a: float) -> void:
	var S: SimState = host.S
	var n: int = fighter_views.size()
	if _cue.size() != n:
		_cue.resize(n)
		_cue.fill(0.0)
		_cue_z.resize(n)
		_cue_want.resize(n)
		_cue_want.fill(false)
		_cue_t = -1.0
	var snap: bool = _cue_t < 0.0
	var dt: float = 0.0 if snap else clampf(PlanetView.tick_time(S) - _cue_t, 0.0, 0.1)
	_cue_t = PlanetView.tick_time(S)
	var apart: bool = n == 2 and absf(S.fighters[0].z - S.fighters[1].z) > RenderLook.LANE_CUE_DZ
	var cues: Array = []
	for i in range(n):
		var z: float = S.fighters[i].z
		if snap:
			_cue_want[i] = apart
			_cue[i] = 1.0 if apart else 0.0
		elif dt > 0.0:
			_cue_want[i] = apart or absf(z - _cue_z[i]) / dt > RenderLook.LANE_CUE_VZ
			_cue[i] = move_toward(_cue[i], 1.0 if _cue_want[i] else 0.0, dt / (RenderLook.LANE_CUE_IN_S if _cue_want[i] else RenderLook.LANE_CUE_OUT_S))
		if snap or dt > 0.0:
			_cue_z[i] = z
		var v: FighterView = fighter_views[i]
		cues.append([host.fighter_x(i, a), v.depth, _cue[i] * RenderLook.LANE_CUE_ALPHA, v._aura_col])
	planet.set_lane_cues(cues)


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


## A fighter's rectangle on this pane's screen (feet to the top of the head, a body's width), a little grown. (For
## Animation's tools.)
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
	mats.set_bend(4.0 * d * vp.y * c.z / (vp.x * vp.x), cam_rig.dist)
	# The horizon is the far edge of the ground: its elevation from the camera anchors the sky and the fog.
	var hz: float = (0.0 - cam_rig.position.y) / (cam_rig.position.z + RenderLook.FOG_FAR)
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
	for k in [["cloud_period", RenderLook.CLOUD_PERIOD], ["cloud_cover", RenderLook.CLOUD_COVER], ["react_r", RenderLook.SKY_REACT_R], ["react_at", RenderLook.SKY_REACT_AT]]:
		_sky_mat.set_shader_parameter(k[0], k[1])
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
