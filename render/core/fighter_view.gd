class_name FighterView
extends Node3D
## One fighter as a greybox figure of flat-coloured primitives, generated from its roster colours and role (no
## hand-made assets). The layout follows the prototype's drawFighter, in its units: the body pivot sits 34 units above
## f.y and rotates by f.rot (launch spin) and the stance lean. Readability cues:
## - stance: a badge above the head in the stance colour, a lean (aggressive forward, evasive back) and a guard glow
##   in front in defensive; the HUD labels it too;
## - hit: the body flashes white for RenderLook.HIT_FLASH_S after f.hurtT;
## - tier: the aura grows with tier, and at tier 3+ (or while charging) aura streaks rise from the feet;
## - hidden: the whole figure fades to RenderLook.HIDDEN_ALPHA inside a sonar ripple;
## - head flashes (flash_view.gd, the aura's replacement): brief pops at the head for what the fighter senses or
##   feels. While they are on (F7), the aura, its streaks and the charge orb are hidden;
## - Combat's cues (brace, glance, tell, turn_read and the rest; RenderLook.CUE_POSES): short placeholder poses blended
##   onto the rig (arms, lean, crouch, step, head, tremble) with a brief flare, spark, guard or ring. Presentation only.
##
## Staging (Orb: fighters "cheat out" like stage actors). The body is turned toward the camera by a pose angle
## (RenderLook.TURN per state, TURN_STANCE per stance, measured from a pure profile) and the head leads by TURN_HEAD.
## When the facing flips the figure turns through facing the camera over TURN_TIME and mirrors at that front-on
## moment, so the same side always faces the camera and the back never shows; the turn runs on sim time (it holds in
## hit-stop and pause). Every part draws with the hybrid projection (render/shaders/ortho.gdshaderinc): the pivot is
## placed by the perspective, the figure around it orthographically, so it looks the same at the screen centre and
## edges. Art sets the angles in look.gd (or turn_scale per fighter) when its turnarounds arrive.
## Reads the fighter only; never writes it.

const PIVOT_Y := 34.0
const HEIGHT := 90.0           # feet to the top of the hair, in world units (for UI's anchors)
const HEAD_Y := 30.0
const FRONT_SHOULDER := Vector2(12, 14)
const BACK_SHOULDER := Vector2(-12, 14)
const BACK_HAND := Vector2(-20, -4)
## Hair outlines in the prototype's canvas units (x forward, y down), extruded to low-poly prisms. The hero's crest is
## swept back rather than spiked upward, to keep the placeholder away from genre-classic silhouettes.
const HAIR_HERO: Array = [[-10, -30], [-24, -39], [-12, -41], [-19, -49], [-2, -45], [9, -46], [12, -37], [10, -30]]
const HAIR_VILLAIN: Array = [[-11, -30], [-10, -42], [0, -44], [10, -42], [13, -20], [8, -32]]
const CAPE: Array = [[-10, -18], [-30, 22], [-4, 14]]

var turn_scale: float = 1.0    # per-fighter multiplier on the pose angles (for Art)
var pivot := Node3D.new()      # body centre; rotates by f.rot and the stance lean
var body := Node3D.new()       # turned toward the camera and mirrored by facing
var head := Node3D.new()       # leads the body's turn by TURN_HEAD
var solid: Array = []          # [MeshInstance3D, base Color, flashes on hit, opaque material, faded material]
var arm_front: MeshInstance3D
var arm_back: MeshInstance3D
var flare: MeshInstance3D      # a cue's brief chest flare
var spark: MeshInstance3D      # a cue's contact spark at the front hand
var cue_ring: MeshInstance3D   # a ring around this fighter when the other circles it
var _cue: Dictionary = {}      # the cue pose showing: a RenderLook.CUE_POSES entry, plus t0 and kind
var _ring_t0: float = -1.0
var _ring_a: float = 0.0
var cues_started: Dictionary = {}   # kind -> poses started this match (for tools)
var aura: MeshInstance3D
var orb_outer: MeshInstance3D
var orb_core: MeshInstance3D
var badge: MeshInstance3D
var guard: MeshInstance3D
var ripple: MeshInstance3D
var streaks: Array = []
var glows: Array = []          # every glow material, for the projection anchor
var flash_view: FlashView      # head flashes (render/core/flash_view.gd)
var anim_body: AnimBody        # the A1 mannequin (render/anim/), null with --noanim
var depth: float = 0.0         # B3: the sim's depth of this fighter this frame (Fighter.z; the pane sets it before update)
var sag: float = 0.0           # ... and how far the planet's bend lowers that spot (RenderMats.sag), as it does the world there
var flashes_on: bool = true    # F7: the head flashes instead of the placeholder aura, streaks and charge orb
var markers: bool = true       # the stance badge over the head; off in Camera's inset pane, a close-up strip it would poke into
var _badge_mat: ShaderMaterial
var _faded: bool = false
var _flash: bool = false
var _stance: int = -1
var _aura_col := Color.WHITE
var _turn: float = 1.0         # visual facing, -1 to 1: follows f.face through 0 (facing the camera)
var _pose: float = 30.0        # the pose angle in degrees, eased toward the current pose's
var _last_t: float = -1.0
## Battle damage on the mannequin (fighter_body.gdshader): per wound region (head, core, arms, legs), the marks showing,
## 0 to 3. They ease up to the worst stage the region has reached this match and stay, whatever the wear does after.
static var damage_on: bool = true         # main's --nodamage switches it off, for A/B
static var damage_reduced: bool = false   # the reduced version, a flat tint by stage (main sets it from VFX's quality)
var _dmg: Array = [0.0, 0.0, 0.0, 0.0]
var _dmg_worst: Array = [0, 0, 0, 0]
var _dmg_sent := Vector4(-1.0, -1.0, -1.0, -1.0)
var _dmg_detail: float = -1.0
var _dmg_snap: bool = true                # the next update shows the marks at once (the first frame, or a posed tool)


func build(f) -> void:
	name = f.name
	add_child(pivot)
	pivot.position.y = PIVOT_Y
	pivot.add_child(body)
	body.add_child(head)
	head.position.y = HEAD_Y
	_turn = f.face
	_pose = _pose_angle(f)
	_aura_col = RenderLook.col(f.aura)
	var legs := RenderLook.col(RenderLook.LEGS)
	_part(_box(Vector3(8, 26, 8)), Vector3(-6, -23, -5), legs, true)
	_part(_box(Vector3(8, 26, 8)), Vector3(6, -23, 5), legs, true)
	if f.role == "villain":
		_part(_extrude(CAPE, 4.0), Vector3(0, 0, -10), RenderLook.col(RenderLook.CAPE), false)
	_part(_box(Vector3(28, 32, 18)), Vector3(0, 4, 0), RenderLook.col(f.col), true)
	var arm := RenderLook.col(RenderLook.ARM)
	arm_back = _part(_box(Vector3(6, 1, 6)), Vector3.ZERO, arm, true)
	_limb(arm_back, BACK_SHOULDER, BACK_HAND, -10.0)
	arm_front = _part(_box(Vector3(6, 1, 6)), Vector3.ZERO, arm, true)
	var hs := SphereMesh.new()
	hs.radius = 10.0
	hs.height = 20.0
	hs.radial_segments = 8
	hs.rings = 4
	_part(hs, Vector3.ZERO, RenderLook.col(RenderLook.SKIN), true, head)
	_part(_extrude(HAIR_HERO if f.role == "hero" else HAIR_VILLAIN, 23.0), Vector3(0, -HEAD_Y, 0), RenderLook.col(f.hair), false, head)
	_part(_box(Vector3(4, 2, 2)), Vector3(5, 31 - HEAD_Y, 10.5), RenderLook.col(RenderLook.EYE), false, head)
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
	_badge_mat = RenderMats.fighter_flat(Color.WHITE, 1.0, 0.2)
	badge.material_override = _badge_mat
	add_child(badge)
	guard = _glow(_sphere(), RenderLook.col(RenderLook.STANCE_COL[1]), 0.4, 0.6)
	guard.position = Vector3(30.0, 0.0, 0.0)
	guard.scale = Vector3(12.0, 84.0, 60.0)
	body.add_child(guard)
	flash_view = FlashView.new()
	add_child(flash_view)
	flash_view.set_head(hs.radius)
	flare = _glow(_sphere(), _aura_col, 0.0, 1.4)
	flare.visible = false
	pivot.add_child(flare)
	spark = _glow(_sphere(), Color(1.0, 0.95, 0.8), 0.0, 0.6)
	spark.visible = false
	add_child(spark)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.93
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 4
	ripple = _glow(torus, Color(190.0 / 255.0, 220.0 / 255.0, 1.0), 0.55, 0.0)
	ripple.rotation.x = PI * 0.5
	add_child(ripple)
	cue_ring = _glow(torus, Color(1.0, 1.0, 1.0), 0.0, 0.0)
	cue_ring.rotation.x = PI * 0.5
	cue_ring.visible = false
	add_child(cue_ring)
	if RenderAnim.is_enabled():
		_build_anim(f)


## The animation slice A1 mannequin (render/anim/, docs/animation/pose-pipeline.md): one skinned figure replaces the box
## parts (which stay, hidden, so the arm and head anchors below keep working). The pose comes from RenderAnim, solved once
## a frame for every pane. `--noanim` keeps the placeholder.
func _build_anim(f) -> void:
	AnimData.load_all()
	var pal: Dictionary = {
		"body": RenderLook.col(f.col), "legs": RenderLook.col(RenderLook.LEGS), "arms": RenderLook.col(RenderLook.ARM),
		"skin": RenderLook.col(RenderLook.SKIN), "gear": RenderLook.col(RenderLook.CAPE if f.role == "villain" else "#cdd6e4"),
		"accent": _aura_col, "hair": RenderLook.col(f.hair),
	}
	anim_body = AnimBody.new()
	anim_body.build(pal, true)
	body.add_child(anim_body)
	var bm := anim_body.mi.material_override as ShaderMaterial
	bm.set_shader_parameter("bone_region", bone_regions())
	bm.set_shader_parameter("skin", pal["skin"])
	bm.set_shader_parameter("gear", pal["gear"])
	bm.set_shader_parameter("grime", RenderLook.col(RenderLook.DAMAGE_GRIME))
	bm.set_shader_parameter("bruise", RenderLook.col(RenderLook.DAMAGE_BRUISE))
	bm.set_shader_parameter("damage_seed", float(absi(String(f.name).hash()) % 97) / 97.0)
	# How much of each mark the fighter's outfit shows at each stage: Art's stage data (render/core/damage_look.gd).
	var marks: Dictionary = RenderDamage.marks(String(RenderLook.DAMAGE_OUTFIT.get(String(f.name), RenderLook.DAMAGE_OUTFIT_DEFAULT)))
	bm.set_shader_parameter("mark_scuff", marks["scuff"])
	bm.set_shader_parameter("mark_bruise", marks["bruise"])
	bm.set_shader_parameter("mark_tear", marks["tear"])
	anim_body.position = Vector3(0.0, -PIVOT_Y, 0.0)
	# The placeholder box figure is dropped (its materials would only cost per-frame parameter writes); the two arm nodes stay
	# as bare transform holders for the orb, spark and head anchors below.
	for p in solid:
		if p[0] == arm_front or p[0] == arm_back:
			p[0].mesh = null
		else:
			p[0].queue_free()
	solid.clear()


## Each bone's wound region for the body shader (0 head, 1 core, 2 arms, 3 legs), from the rig's bone names.
static func bone_regions() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(32)
	out.fill(1)
	for i in range(mini(AnimRig.N, 32)):
		var n: String = AnimRig.BONES[i][0]
		if n == "neck" or n == "head":
			out[i] = 0
		elif n.begins_with("clavicle") or n.begins_with("upper_arm") or n.begins_with("forearm") or n.begins_with("hand") or n.begins_with("fingers"):
			out[i] = 2
		elif n.begins_with("thigh") or n.begins_with("shin") or n.begins_with("foot"):
			out[i] = 3
	return out


## Battle damage: each region's marks grow toward the worst wound stage it has reached this match (the sim's
## Fighter.stage: 1 bruised, 2 battered, 3 broken), over DAMAGE_GROW_S of sim time, and never fade.
func _damage(f, dt: float) -> void:
	var v := Vector4.ZERO
	for r in range(4):
		_dmg_worst[r] = maxi(_dmg_worst[r], int(f.stage[r])) if damage_on else 0
		_dmg[r] = float(_dmg_worst[r]) if _dmg_snap else move_toward(_dmg[r], float(_dmg_worst[r]), dt / RenderLook.DAMAGE_GROW_S)
		v[r] = _dmg[r]
	_dmg_snap = false
	var detail: float = 0.0 if damage_reduced else 1.0
	if v == _dmg_sent and detail == _dmg_detail:
		return
	_dmg_sent = v
	_dmg_detail = detail
	var bm := anim_body.mi.material_override as ShaderMaterial
	bm.set_shader_parameter("damage", v)
	bm.set_shader_parameter("damage_detail", detail)


## The next update shows the marks at their full stage at once (for tools that pose a frame); forget also drops what
## the regions have been through, so a posed sheet can step the stages back down.
func snap_damage(forget: bool = false) -> void:
	_dmg_snap = true
	if forget:
		_dmg_worst = [0, 0, 0, 0]


## A cue from Combat (RenderLook.CUE_POSES), started at sim time T; kinds with no pose are ignored.
func cue(kind: String, T: float) -> void:
	var p = RenderLook.CUE_POSES.get(kind)
	if p == null:
		return
	_cue = p.duplicate()
	_cue["t0"] = T
	_cue["kind"] = kind
	cues_started[kind] = int(cues_started.get(kind, 0)) + 1


## A ring around this fighter (the other one circles it), at alpha a.
func ring(T: float, a: float) -> void:
	_ring_t0 = T
	_ring_a = a


## The cue's weight now: in over CUE_IN, out over CUE_OUT, 0 outside its time.
func _cue_weight(T: float) -> float:
	if _cue.is_empty():
		return 0.0
	var t: float = T - float(_cue.t0)
	var d: float = float(_cue.dur)
	if t < 0.0 or t >= d:
		return 0.0
	return smoothstep(0.0, RenderLook.CUE_IN, t) * (1.0 - smoothstep(d - RenderLook.CUE_OUT, d, t))


## A part of the cue showing, times its weight (0 when the cue has none).
func _cue_part(key: String, T: float) -> float:
	return float(_cue.get(key, 0.0)) * _cue_weight(T) if not _cue.is_empty() else 0.0


## The cue pose on top of the state's own: the arms, lean, crouch, step, head and tremble, and its flare, spark and
## ring. m, th: the body's mirror and turn this frame; front: the front hand's own target.
func _pose_cue(T: float, m: float, th: float, front: Vector2) -> void:
	var w: float = _cue_weight(T)
	var back: Vector2 = BACK_HAND
	var step: float = 0.0
	if w > 0.0:
		var c: Dictionary = _cue
		if anim_body == null:
			# The placeholder's pose. With the mannequin (render/anim/) the pose is a key pose (data/anim/cues.json); only the
			# effects below (flare, spark, guard, badge, ring) and the tremble stay here.
			if c.has("front"):
				front = front.lerp(Vector2(c.front[0], c.front[1]), w)
			if c.has("back"):
				back = back.lerp(Vector2(c.back[0], c.back[1]), w)
			pivot.rotation.z += float(c.get("lean", 0.0)) * w * _turn
			pivot.position.y -= float(c.get("crouch", 0.0)) * w
			head.rotation.y -= float(c.get("head", 0.0)) * w
			if c.has("yaw"):
				body.basis = Basis(Vector3.UP, -m * (th + float(c.yaw) * w)) * Basis.from_scale(Vector3(m, 1.0, 1.0))
			step = float(c.get("step", 0.0)) * w * m
		if not flash_view.reduced_motion:
			step += sin(T * 55.0) * float(c.get("tremble", 0.0)) * w
	elif not _cue.is_empty() and T - float(_cue.t0) >= float(_cue.dur):
		_cue = {}
	pivot.position.x = step
	if anim_body == null:
		_limb(arm_front, FRONT_SHOULDER, front, 10.0)
		_limb(arm_back, BACK_SHOULDER, back, -10.0)
	var t: float = T - float(_cue.get("t0", 0.0))
	var fl: float = _cue_part("flare", T) * clampf(1.0 - t / float(_cue.get("dur", 1.0)), 0.0, 1.0)
	flare.visible = fl > 0.01
	if flare.visible:
		flare.scale = Vector3.ONE * 2.0 * (40.0 + 30.0 * t / float(_cue.dur))
		RenderMats.set_glow(flare.material_override, _aura_col, fl)
	var sp: float = float(_cue.get("spark", 0.0)) * clampf(1.0 - t / 0.2, 0.0, 1.0) if not _cue.is_empty() else 0.0
	spark.visible = sp > 0.01
	if spark.visible:
		spark.position = to_local(arm_front.global_transform * Vector3(0.0, 0.5, 0.0))
		spark.scale = Vector3.ONE * 2.0 * (6.0 + 10.0 * t / 0.2)
		RenderMats.set_glow(spark.material_override, Color(1.0, 0.95, 0.8), sp)
	var rt: float = (T - _ring_t0) / RenderLook.CUE_RING_S if _ring_t0 >= 0.0 else 2.0
	cue_ring.visible = rt >= 0.0 and rt < 1.0
	if cue_ring.visible:
		cue_ring.position = Vector3(0.0, PIVOT_Y, 0.0)
		cue_ring.scale = Vector3.ONE * (40.0 + 40.0 * rt)
		RenderMats.set_glow(cue_ring.material_override, Color(1.0, 1.0, 1.0), _ring_a * (1.0 - rt))


## The pose angle for the fighter's state and stance, in degrees from a pure profile toward the camera.
func _pose_angle(f) -> float:
	var a: float = RenderLook.TURN.get("sliding" if f.slide > 0.0 else f.state, RenderLook.TURN_DEFAULT)
	if f.state == "free" or f.state == "locked":
		a += RenderLook.TURN_STANCE[int(f.stance)]
	return clampf(a * turn_scale, 0.0, 89.0)


## pose: interpolated [x, y, rot]; vx: the fighter's x relative to the camera; T: sim time; z: camera zoom.
func update(S: SimState, f, pose: Vector3, vx: float, z: float) -> void:
	var T: float = S.T
	var dt: float = clampf(T - _last_t, 0.0, 0.1) if _last_t >= 0.0 else 0.0
	_last_t = T
	# At the sim's depth: the hybrid projection places the pivot with the world's perspective, so the fighter shrinks and
	# draws toward the camera's axis as he goes into the rows, and the buildings sort around him by true depth.
	position = Vector3(vx, pose.y - sag, depth)
	var stance: int = int(f.stance)
	var sliding: bool = f.slide > 0.0
	# Staging: ease the pose angle, turn through the camera when the facing flips, mirror at the front-on moment.
	_turn = move_toward(_turn, RenderAnim.face_for(S, f), dt * 2.0 / RenderLook.TURN_TIME)
	_pose = move_toward(_pose, _pose_angle(f), dt * RenderLook.TURN_RATE_DEG)
	var m: float = 1.0 if _turn >= 0.0 else -1.0
	var th: float = deg_to_rad(lerpf(90.0, _pose, absf(_turn)))
	body.basis = Basis(Vector3.UP, -m * th) * Basis.from_scale(Vector3(m, 1.0, 1.0))
	head.rotation.y = -deg_to_rad(RenderLook.TURN_HEAD)
	if anim_body != null:
		# the mannequin's key poses carry the lean, crouch and slide brace; the pivot only spins with a launch
		pivot.rotation.z = -pose.z
		pivot.position.y = PIVOT_Y
	elif sliding:
		pivot.rotation.z = RenderLook.SLIDE_LEAN * signf(f.vx)
		pivot.position.y = PIVOT_Y - RenderLook.SLIDE_CROUCH
	else:
		var lean: float = 0.0
		if f.state == "free" or f.state == "locked":
			lean = [-0.12, 0.0, 0.16, 0.05][stance]
		pivot.rotation.z = -pose.z + lean * _turn
		pivot.position.y = PIVOT_Y
	var punch: bool = f.state == "locked" or f.beamCharge != null
	var front: Vector2 = Vector2(30, 12) if punch else Vector2(22, 0)
	var flash: bool = T - f.hurtT < RenderLook.HIT_FLASH_S and T >= f.hurtT
	if anim_body != null:
		var af: AnimFighter = RenderAnim.solve(S, f)
		if af.version != anim_body.applied_version:
			anim_body.applied_version = af.version
			anim_body.apply(af.q, af.hips, af.curl, af.root_off)
		anim_body.set_look(1.0 if flash else 0.0, f.hidden)
		_damage(f, dt)
		var off := Vector3(0.0, -PIVOT_Y, 0.0)
		head.position = af.head_center() + off
		arm_front.transform = Transform3D(Basis.IDENTITY, af.socket("hand_r") + off)
	_pose_cue(T, m, th, front)
	if f.hidden != _faded or flash != _flash:
		_faded = f.hidden
		_flash = flash
		for p in solid:
			var c: Color = Color.WHITE if (flash and p[2]) else p[1]
			p[3].set_shader_parameter("albedo", c)
			p[4].set_shader_parameter("albedo", Color(c, RenderLook.HIDDEN_ALPHA))
			p[0].material_override = p[4] if _faded else p[3]
	var fade: float = RenderLook.HIDDEN_ALPHA if f.hidden else 1.0
	var tier: float = f.tier
	var ch: bool = f.state == "charging"
	var bc: bool = f.beamCharge != null
	var rad: float = (46.0 + tier * 20.0 + (34.0 if ch else 0.0) + (20.0 if bc else 0.0)) * (1.0 + sin(T * 22.0 + f.x) * 0.04)
	aura.scale = Vector3.ONE * 2.0 * rad
	aura.visible = not flashes_on
	RenderMats.set_glow(aura.material_override, _aura_col, 0.5 * fade)
	var streak_on: bool = (ch or tier >= 3.0) and not flashes_on
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
	orb_outer.visible = bc and not flashes_on
	orb_core.visible = bc and not flashes_on
	if bc:
		var p: float = clampf((T - f.beamCharge) / 0.8, 0.0, 1.0)
		var r: float = (10.0 + p * 40.0) + 4.0 / z
		var at: Vector3 = to_local(arm_front.global_transform * Vector3(0.0, 0.5, 0.0))
		orb_outer.position = at
		orb_outer.scale = Vector3.ONE * 2.0 * r
		orb_core.position = at
		orb_core.scale = Vector3.ONE * r * 0.8
	badge.visible = markers and not f.hidden and not (flashes_on and flash_view.glyph_up())
	badge.position = Vector3(0.0, 84.0 + tier * 3.0 + 8.0, 0.0)
	badge.scale = Vector3.ONE * (1.0 + (float(_cue.get("badge", 1.0)) - 1.0) * _cue_weight(T))
	badge.rotation.y = T * 2.0
	if stance != _stance:
		_stance = stance
		_badge_mat.set_shader_parameter("albedo", RenderLook.col(RenderLook.STANCE_COL[stance]))
	guard.visible = (stance == 1 and (f.state == "free" or f.state == "locked") or _cue_part("guard", T) > 0.3) and not f.hidden
	ripple.visible = f.hidden
	if f.hidden:
		var rp: float = fmod(T * 1.2, 1.0)
		ripple.position = Vector3(0.0, 30.0, 0.0)
		ripple.scale = Vector3.ONE * ((20.0 + rp * 60.0) + 6.0 / z)
		RenderMats.set_glow(ripple.material_override, Color(190.0 / 255.0, 220.0 / 255.0, 1.0), 0.55 * (1.0 - rp * 0.6))
	# The hybrid projection's anchor: the pivot, where the perspective places the fighter.
	var anchor: Vector3 = pivot.global_position
	if anim_body != null:
		anim_body.set_anchor(anchor)
	for p in solid:
		p[3].set_shader_parameter("anchor", anchor)
		p[4].set_shader_parameter("anchor", anchor)
	for g in glows:
		g.set_shader_parameter("anchor", anchor)
	_badge_mat.set_shader_parameter("anchor", anchor)
	if flashes_on:
		flash_view.step(T, f.hidden, to_local(head.global_position), m, anchor, WorldTerrain.groundY(S, f.x) - pose.y)
	else:
		flash_view.visible = false


func _part(mesh: Mesh, at: Vector3, c: Color, flashes: bool, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	var mo := RenderMats.fighter_flat(c)
	var mf := RenderMats.fighter_flat(c, RenderLook.HIDDEN_ALPHA)
	mi.material_override = mo
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else body).add_child(mi)
	solid.append([mi, c, flashes, mo, mf])
	return mi


## Stretch a unit-height box between two points in the body plane (y up), at depth z.
static func _limb(mi: MeshInstance3D, a: Vector2, b: Vector2, z: float) -> void:
	var d: Vector2 = b - a
	var l: float = maxf(d.length(), 0.001)
	var u: Vector2 = d / l
	mi.transform = Transform3D(Basis(Vector3(u.y, -u.x, 0.0), Vector3(u.x, u.y, 0.0) * l, Vector3(0.0, 0.0, 1.0)), Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, z))


func _glow(mesh: Mesh, c: Color, alpha: float, soft: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m: ShaderMaterial = RenderMats.glow(c, alpha, soft)
	m.set_shader_parameter("ortho", 1.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glows.append(m)
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
