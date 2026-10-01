extends Node3D
## Greybox main scene: runs the GDScript sim as a 60 Hz fixed-step loop (SimHost) and draws it every frame,
## interpolated between the last two ticks, in a 2.5D side-on view of the wrapped planet. It starts as an AI-vs-AI
## demo; any key or click hands P1 to a human (as the prototype did).
##
## It hosts UI's HUD (ui/hud/ui_hud.tscn, docs/ui/hud-spec.md section 14) and Audio's voices (audio/, "Hooking it
## up"). Both read the sim and the events SimHost drains; neither writes it. F2 swaps in the greybox HUD
## (render/core/hud.gd) until UI's playtest, F3 shows the performance readout, F4 the director feed.
##
## Rendering never writes sim state: the views read S, the fx consumer and the reference camera, and only SimHost
## steps the sim. render/tools/determinism.gd checks that the gameplay hashes are unchanged by rendering.
##
## The world is drawn by panes (render/core/pane_world.gd). The game runs Camera's dynamic split screen by default
## (docs/camera/split-screen.md): main owns and steps its SplitRig (render/camera/split_rig.gd), and Camera's
## compositor (SplitView) attaches through make_pane, move_pane0 and `compositor`, so the panes follow the rig's
## cameras and UI's HUD gets the rig's record (split_fn). F9 toggles it, --nosplit starts with one view from the
## reference camera, and the tools (manual) get one view unless they attach a compositor themselves. The contract is
## in docs/rendering/README.md, "Panes and the split screen". SplitView follows UI's options each frame: split_solo,
## reduced_motion, and Camera's zoom, shake and launch-follow settings (F10 and F11 flip the first two).
## Alt+F9 steps the camera's pitch (RenderLook.PITCH_STEPS: straight on, Camera's raised side view, its three-quarter
## view; docs/camera/camera-v2.md section 8), and Ctrl+F9 swaps the occlusion method (a hole around the fighter, or the
## buildings in front cut down to stubs; docs/rendering/README.md, "Occlusion"). Neither takes P1 over (Alt and Ctrl
## are not game keys; Shift is). --pitch=DEG and --occl=hole|stub set them at start. --nostreets leaves the lane table's
## streets unpainted (for A/B). Camera's inset pane comes from make_inset and the compositor's inset_view (below).
##
## Command-line options (after "--"): --seed=N, --human (take P1 at start), --legacy-hud, --frames=N (quit after N frames),
## --shot=path.png (save the last frame), --bench (vsync off; print frame-time stats at quit, also split by whether two
## full panes were drawn; VFX at a fixed quality), --novsync, --nosplit, --novfx (VFX off, for A/B runs),
## UI's How to play card opens at the first run and with F1 (the HUD handles the key) or from the pause menu (P, then
## How to play), and its feedback panel from the pause menu (Send feedback) or its match-end pill; the sim is frozen
## while either is open. --vfx-quality=0|1|2 (VFX's low, medium or high, fixed). F6 toggles VFX's ground cracks (on by default), Shift+F6 its
## destruction (shards, collapse dust, holes; off by default until B2), and while that is on the particles skip a
## building fall's dust and debris (SimHost._without_fall_debris), which VFX draws instead. Ctrl+F6 toggles VFX's scorch
## embers (on by default), which replace ImpactFx's scorch sparks while on.
## Head flashes (render/core/flash_view.gd): F7 on and off (on by default, in place of the placeholder aura), F8 the
## legacy shapes, Alt plus 1 to 9, 0, -, =, [ and ] fires each flash in the data's order on P1 (Shift: P2), Alt+F
## cycles a fighter's shape family (Shift: P2). The Alt keys never take P1 over. --flash-soak (for the bench) keeps
## flashes cycling on both fighters, one after another in the data's order.
## Benchmark: godot --path . --fixed-fps 60 --resolution 1280x720 -- --seed=4 --frames=4800 --bench
## (--fixed-fps 60 gives exactly one sim tick per frame; with vsync off each frame runs as fast as it can, so the
## wall-clock frame time is the true cost of one tick plus one rendered frame.)

@onready var hud: HudView = $HUD/Overlay

var pane: PaneWorld                 # the first pane: the world, drawn in this scene's own world until a compositor moves it
var panes: Array = []               # [PaneWorld]: pane i follows fighter slot i in a split (SplitFrame)
var split_rig := SplitRig.new()     # Camera's split-screen rig, stepped after every tick while a compositor is attached
var split_frame: SplitFrame = null  # this frame's, while a compositor is attached
## Camera's compositor (SplitView), or null for one view from the reference camera. main calls its present(frame)
## once per displayed frame after drawing the panes, and its pane_jitter(i) (if it has one) for a pane's shake.
## Attaching one resets the rig to the current state; without one the rig costs nothing (about 0.05 ms a tick).
var split_view: SplitView = null   # Camera's compositor in the game (null in the tools)
var cam_pitch: float = 0.0          # the cameras' pitch in degrees (Alt+F9), unless the rig's frame carries its own
var occlusion: int = PaneWorld.OCCL_HOLE   # every pane's occlusion method (Ctrl+F9)
var inset: PaneWorld = null         # Camera's inset pane (make_inset), or null
var compositor: Object = null:
	set(v):
		compositor = v
		if v != null and host != null:
			var vp: Vector2 = get_viewport().get_visible_rect().size
			split_rig.reset(host.S, vp.x, vp.y)
# Pane 0's parts, for the tools and the HUD hooks.
var cam_rig: CameraRig
var planet: PlanetView
var fighters_root: Node3D
var beams: BeamView
var particles: ParticleView

var host: SimHost
var started: bool = false
var manual: bool = false          # tools call frame() or render_view() themselves
var fighter_views: Array = []
var view_cam_x: float = 0.0       # the interpolated camera's wrapped world x this frame
var args: Dictionary = {}
var frames: int = 0
var _ring: Array = [PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array()]   # frame, tick, fx, view ms
var _bench: Array = [PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array()]
var _render_cpu := PackedFloat64Array()
var _render_gpu := PackedFloat64Array()
var _draws := PackedInt32Array()
var _quitting: bool = false
var _last_usec: int = 0
var _bench_two := PackedFloat64Array()     # wall-clock frame ms while two full panes are drawn
var _bench_other := PackedFloat64Array()   # ... and otherwise
var ui_hud: UiHud                 # UI's HUD
var _overlay_resume: bool = false  # the pause state the How to play card, the feedback panel or the Settings screen found when it opened
var _touch_last: bool = false     # touch was the last input device (UI's touch_ui option)
var audio: AudioVoices            # Audio's voice pool
var legacy_hud: bool = false      # F2: the greybox HUD instead of UI's
var flashes_on: bool = true       # F7: head flashes instead of the placeholder aura
var cues_on: bool = true          # Combat's cue events as placeholder poses on the fighters (tools switch it off for A/B)
var flash_legacy: bool = false    # F8: the flashes' shapes before Legal's conditions
var flash_family: Array = RenderLook.FLASH_FAMILY.duplicate()   # each fighter's shape family (Alt+F cycles)
## The flash debug keys, in the data's order (FlashSet.ids()).
const FLASH_KEYS: Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL, KEY_BRACKETLEFT, KEY_BRACKETRIGHT]


func _ready() -> void:
	args = parse_args()
	pane = PaneWorld.new()
	add_child(pane)
	move_child(pane, 0)
	panes = [pane]
	cam_rig = pane.cam_rig
	planet = pane.planet
	fighters_root = pane.fighters_root
	beams = pane.beams
	particles = pane.particles
	fighter_views = pane.fighter_views
	SimInputData.load_and_apply()   # the input data and SimAct's three numbers, before the host builds its hub
	cam_pitch = float(args.get("pitch", 0.0))
	occlusion = PaneWorld.OCCL_STUB if String(args.get("occl", "hole")) == "stub" else PaneWorld.OCCL_HOLE
	PlanetView.streets = not args.has("nostreets")
	host = SimHost.new()
	host.vfx.cracks_enabled = true     # Orb asked for cracked ground; VFX's destruction stays off until B2's events (F6)
	host.vfx.embers_enabled = true     # VFX's scorch embers, in place of ImpactFx's scorch sparks (Ctrl+F6)
	if args.has("novfx"):
		host.vfx.enabled = false
	if args.has("vfx-quality"):
		host.vfx.quality = clampi(int(args["vfx-quality"]), 0, 2)
		host.vfx.auto_quality = false
	if args.has("bench"):
		host.vfx.auto_quality = false
	hud.main = self
	ui_hud = preload("res://ui/hud/ui_hud.tscn").instantiate()
	$HUD.add_child(ui_hud)
	$HUD.move_child(ui_hud, 0)    # under the greybox overlay, which keeps the take-over prompt and the perf readout
	ui_hud.anchor_fn = _hud_anchor
	ui_hud.strip_fn = _hud_strip
	ui_hud.split_fn = _split_record
	ui_hud.howto_opened.connect(_on_howto_opened)
	ui_hud.howto_closed.connect(_on_howto_closed)
	ui_hud.feedback_opened.connect(func(_context): _hold_for_overlay())
	ui_hud.feedback_closed.connect(_release_overlay)
	ui_hud.feedback_fn = _feedback_context
	ui_hud.settings_opened.connect(_hold_for_overlay)
	ui_hud.settings_closed.connect(_release_overlay)
	ui_hud.pause_menu_opened.connect(_on_pause_menu_opened)
	ui_hud.pause_menu_closed.connect(_on_pause_menu_closed)
	ui_hud.new_match_requested.connect(func(): start_match(fresh_seed()))
	ui_hud.option_changed.connect(_on_option_changed)
	# The hub's defaults go into the HUD first (its legend and prompts show the layouts in use) ...
	ui_hud.set_option("pad_preset", host.hub.pad_preset)
	ui_hud.set_option("touch_preset", host.hub.touch_preset)
	if ui_hud.has_signal("remap_changed"):
		ui_hud.remap_changed.connect(_on_remap_changed)
	if not manual and not args.has("bench") and not args.has("frames") and not args.has("shot"):
		# ... then what the player saved on the Settings screen, so the saved choice wins (the order matters). The
		# tools, the bench and scripted runs keep the defaults, so a saved option never changes a check or a measurement.
		ui_hud.load_saved_options()
	_touch_last = bool(ui_hud.opts["touch_ui"])
	ui_hud.touch_state_fn = host.touch.display_state
	host.drained.connect(_on_drained)
	Input.joy_connection_changed.connect(_on_joy_connection)
	audio = AudioVoices.new(host.audio_cues.bank)
	add_child(audio)
	if DisplayServer.get_name() != "headless":
		host.audio_cues.bank.warm()   # render every sound now, so none renders in the middle of a fight
	start_match(int(args["seed"]) if args.has("seed") else fresh_seed())
	if args.has("human"):
		take_over()
	if args.has("legacy-hud"):
		set_legacy_hud(true)
	if not manual:
		split_view = SplitView.new()
		add_child(split_view)
		_sync_split_options()
		if not args.has("nosplit"):
			split_view.attach(self)
	if not manual and not args.has("bench") and not args.has("frames") and not args.has("shot") and not ui_hud.howto_seen():
		ui_hud.show_howto(true)     # the first run's How to play card (docs/ui/hud-spec.md section 17)
	if args.has("bench") or args.has("novsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func _exit_tree() -> void:
	SimCore.dispose(host.S)
	for p in all_panes():
		p.mats.clear()


## Every pane: the split's, then Camera's inset if there is one.
func all_panes() -> Array:
	return panes + [inset] if inset != null else panes


func start_match(seed: int, ai: Dictionary = {}) -> void:
	host.new_match(seed, ai)
	var fl: Array = UiSimBridge.fighters(host.S)
	ui_hud.setup(fl[0], fl[1])
	for p in all_panes():
		p.vfx_layer.hub = host.vfx
		p.build(host.S)
		for v in p.fighter_views:
			v.flashes_on = flashes_on
	for i in range(fighter_views.size()):
		_setup_flash(fighter_views[i], i)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	split_rig.reset(host.S, vp.x, vp.y)
	render_view(host.alpha())


## For Camera's compositor: a new pane, a follower of the first, in a SubViewport of its own (its own World3D),
## built into the current match. It is panes[1], the second fighter's pane in a split.
func make_pane(size: Vector2i) -> SubViewport:
	if panes.size() > 1:
		return panes[1].get_parent() as SubViewport   # made once: a compositor attaching again gets the same pane
	var sv := _pane_viewport(size)
	panes.append(_follower(sv))
	return sv


## For Camera's compositor: the inset pane (docs/camera/camera-v2.md section 3), a small follower of the first in a
## SubViewport of the size given. It is not one of the split's panes. Each frame main asks the compositor's
## inset_view(a) for its camera: {cam_x (wrapped world x), cam_y, cam_z (pixels per world unit in the inset's own
## viewport), and optionally jitter, pitch and cutaway}, or {} when the inset is not shown, and draws it from that.
## The compositor places the viewport's texture and switches its updates on and off.
func make_inset(size: Vector2i) -> SubViewport:
	var sv := _pane_viewport(size)
	inset = _follower(sv)
	inset.name = "Inset"
	return sv


## A new pane that draws the first pane's world, in sv, built into the current match.
func _follower(sv: SubViewport) -> PaneWorld:
	var p := PaneWorld.new()
	p.source = pane
	p.vfx_layer.hub = host.vfx
	sv.add_child(p)
	p.build(host.S)
	for v in p.fighter_views:
		v.flashes_on = flashes_on
	return p


## For Camera's compositor: the first pane moved out of this scene's world into a SubViewport of its own, so it can
## be composited like the second. It keeps its nodes and state.
func move_pane0(size: Vector2i) -> SubViewport:
	if pane.get_parent() is SubViewport:
		return pane.get_parent() as SubViewport       # already moved
	var sv := _pane_viewport(size)
	remove_child(pane)
	sv.add_child(pane)
	return sv


static func _pane_viewport(size: Vector2i) -> SubViewport:
	var sv := SubViewport.new()
	sv.size = size
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return sv


## A fighter's head flashes: its family, the switches, and the hooks to UI (the crown, the info setting, the dimming
## of an always-on crown) and to Audio (the cue when a flash starts).
func _setup_flash(v: FighterView, i: int) -> void:
	v.flashes_on = flashes_on
	var fl: FlashView = v.flash_view
	fl.actor = i
	fl.family = String(flash_family[i % flash_family.size()])
	fl.legacy = flash_legacy
	fl.reduced_motion = bool(ui_hud.opts.get("reduced_motion", false))
	fl.crown_fn = ui_hud.crown_up
	fl.info_fn = ui_hud.info_flashes
	fl.up_fn = ui_hud.set_flash_up
	fl.started_fn = _flash_started


func _flash_started(actor: int, id: String) -> void:
	var c = host.audio_cues.flash(host.S, actor, id)
	if c != null:
		host.pending_cues.append(c)


## Ask for a head flash on a fighter. Danger sense points at the opponent (its bearing in the fighter's facing frame).
func fire_flash(actor: int, id: String) -> void:
	if not flashes_on or actor < 0 or actor >= fighter_views.size():
		return
	var S: SimState = host.S
	var f = S.fighters[actor]
	var o = S.fighters[1 - actor]
	var b: float = rad_to_deg(atan2(o.y - f.y, SimWrap.sdx(f.x, o.x) * f.face))
	if b < -90.0:
		b += 360.0
	fighter_views[actor].flash_view.fire(id, S.T, f.hidden, b)


## Combat's cue events (the `cue` op; data/combat/finishers.json `cues`) as placeholder poses, on the fighter the cue
## names (or both) in every pane. A cue with a ring_other ring also rings the other fighter (circle). Cues with no
## pose in RenderLook.CUE_POSES (the camera, banner and HUD ones) are left to their owners.
func _cue_events(events: Array) -> void:
	if not cues_on:
		return
	var T: float = host.S.T
	for e in events:
		if e.type != "cue":
			continue
		var kind: String = String(e.kind)
		var who: int = int(e.actor)
		var pose: Dictionary = RenderLook.CUE_POSES.get(kind, {})
		for pw in all_panes():
			var views: Array = pw.fighter_views
			for i in range(views.size()):
				if who < 0 or i == who:
					views[i].cue(kind, T)
			if pose.has("ring_other") and who >= 0 and who < 2 and views.size() == 2:
				views[1 - who].ring(T, float(pose.ring_other))


## The flashes today's events can drive (spec section 6); the rest wait for Encounter's events and have debug keys.
func _flash_events(events: Array) -> void:
	for e in events:
		match e.type:
			"found":
				fire_flash(int(e.actor), "found")
			"damage":
				if e.kind == "heavy" and e.victim >= 0.0:
					fire_flash(int(e.victim), "hurt")
			"region_broken":
				fire_flash(int(e.actor), "hurt")
			"ko":
				fire_flash(int(e.winner), "triumph")
			"tier_up":
				fire_flash(int(e.actor), "surge")          # a stand-in until cinematic_start and cinematic_end
			"brink_exit":
				fire_flash(int(e.actor), "resolve")        # a stand-in until rally
			"banner":
				if "CLASH" in String(e.text):              # a stand-in for the prototype only
					fire_flash(0, "rage")
					fire_flash(1, "rage")


func _process(delta: float) -> void:
	if not manual:
		frame(delta)


## One displayed frame: run the ticks this frame time allows, then draw at the interpolation point.
func frame(delta: float) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var t0: int = Time.get_ticks_usec()
	_sync_split_options()
	host.vfx.note_frame(delta)
	host.vfx.reduced_motion = bool(ui_hud.opts.get("reduced_motion", false))
	var n: int = host.advance(delta, vp.x, vp.y)
	if args.has("flash-soak") and frames % 40 == 0 and not FlashSet.ids().is_empty():
		var ids: Array = FlashSet.ids()
		fire_flash(0, ids[(frames / 40) % ids.size()])
		fire_flash(1, ids[(frames / 40 + 7) % ids.size()])
	var t1: int = Time.get_ticks_usec()
	render_view(host.alpha())
	ui_hud.advance(0.0 if host.paused else delta)
	for c in host.pending_cues:
		audio.play(c, view_cam_x, cam_rig.zoom)
	host.pending_cues.clear()
	var t2: int = Time.get_ticks_usec()
	# Wall-clock time since the last frame started (with --fixed-fps, delta is fixed and says nothing about cost).
	var wall: float = (t0 - _last_usec) / 1000.0 if _last_usec > 0 else delta * 1000.0
	_last_usec = t0
	_record(wall, n, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0)
	frames += 1
	if args.has("frames") and frames >= int(args["frames"]) and not _quitting:
		_quitting = true
		_finish()


## Draw the frame at interpolation a: one pane from the reference camera, or, with a compositor attached, each pane
## from the split rig's camera for it (the first always, since it applies the world's changes), then the composite.
func render_view(a: float) -> void:
	var S: SimState = host.S
	if compositor != null:
		if "pitch_deg" in split_rig:
			split_rig.pitch_deg = cam_pitch
		split_frame = split_rig.frame(a)
		# Camera's frame may carry the pitch and each pane's cut-away request; until it does, the debug pitch, and in a
		# split each pane opens the buildings in front of its own fighter only.
		var fp = split_frame.get("pitch")
		var pitch: float = float(fp) if fp != null else cam_pitch
		var cw = split_frame.get("cutaway")
		var two: bool = panes.size() > 1 and split_frame.shows(0) and split_frame.shows(1)
		for i in range(panes.size()):
			if i == 0 or split_frame.shows(i):
				var j: Vector2 = compositor.pane_jitter(i) if compositor.has_method("pane_jitter") else (host.jitter if i == 0 else Vector2.ZERO)
				panes[i].occlusion = occlusion
				panes[i].cutaway = cw[i] if cw is Array and i < cw.size() else ({"only": i} if two else {})
				panes[i].render(host, a, split_frame.cam_x[i], Vector3(0.0, split_frame.cam_y[i], split_frame.cam_z[i]), j, pitch)
		if inset != null and compositor.has_method("inset_view"):
			var iv: Dictionary = compositor.inset_view(a)
			if not iv.is_empty():
				inset.occlusion = occlusion
				inset.cutaway = iv.get("cutaway", {})
				inset.render(host, a, float(iv["cam_x"]), Vector3(0.0, float(iv["cam_y"]), float(iv["cam_z"])), iv.get("jitter", Vector2.ZERO), float(iv.get("pitch", pitch)))
		compositor.present(split_frame)
	else:
		split_frame = null
		var vh: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
		pane.occlusion = occlusion
		pane.cutaway = {}
		pane.render(host, a, host.camera_x(a), host.camera(a), PaneShake.capped(host.jitter, vh, _shake()), cam_pitch)
	view_cam_x = pane.view_cam_x
	host.impact.heat_changed = false
	UiSimBridge.patch(ui_hud, S)
	ui_hud.queue_redraw()
	hud.queue_redraw()


## Each tick's events and feed lines, as SimHost drains them: the planet's flight, and UI's HUD.
func _on_drained(events: Array, lines: Array) -> void:
	if compositor != null:
		var vp: Vector2 = get_viewport().get_visible_rect().size
		split_rig.step(host.S, vp.x, vp.y, events)
	planet.consume(events, host.S.T)
	_flash_events(events)
	_cue_events(events)
	RenderAnim.consume(host.S, events)
	ui_hud.consume_all(events)
	UiSimBridge.feed(ui_hud, lines)


## UI's HUD anchor: a fighter's torso on screen and its height in pixels (in a split, in its own pane: the rig's).
func _hud_anchor(slot: int) -> Dictionary:
	if slot < 0 or slot >= fighter_views.size():
		return {"pos": Vector2.ZERO, "h": 0.0, "visible": false}
	if split_frame != null:
		var a: float = host.alpha()
		return split_frame.hud_anchor(slot, host.fighter_x(slot, a), host.fighter_pose(slot, a).y, host.fighter_z(slot, a))
	var torso: Vector3 = fighter_views[slot].global_position + Vector3(0.0, FighterView.PIVOT_Y, 0.0)
	if cam_rig.is_position_behind(torso):
		return {"pos": Vector2.ZERO, "h": 0.0, "visible": false}
	var p: Vector2 = cam_rig.unproject_position(torso)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vis: bool = Rect2(Vector2(-200.0, -200.0), vp + Vector2(400.0, 400.0)).has_point(p)
	# The drawn height: smaller than the plane's when a launch has carried him into the building rows (B3).
	var feet: Vector3 = fighter_views[slot].global_position
	var h: float = absf(cam_rig.unproject_position(feet + Vector3(0.0, FighterView.HEIGHT, 0.0)).y - cam_rig.unproject_position(feet).y)
	return {"pos": p, "h": h, "visible": vis}


## UI's options for the split screen, applied each frame (UI has no change signal): solo against the AI, reduced
## motion (the rig's swing, the shake), Camera's zoom and shake settings (0 to 10; UI's options camera_zoom and
## camera_shake) and who the camera follows on a launch (camera_launch_follow; "auto" until UI has it).
func _sync_split_options() -> void:
	var o: Dictionary = ui_hud.opts
	split_rig.solo_split = bool(o.get("split_solo", true))
	split_rig.reduced_motion = bool(o.get("reduced_motion", false))
	if split_view != null:
		split_view.reduced_motion = split_rig.reduced_motion
		split_view.set_zoom_pref(float(o.get("camera_zoom", CamParams.ZOOM_PREF_DEFAULT)))
		split_view.set_shake_pref(float(o.get("camera_shake", CamParams.SHAKE_PREF_DEFAULT)))
		split_view.set_launch_follow(String(o.get("camera_launch_follow", "auto")))


## UI's options the host owns: the pad and touch layouts go to Controls' input hub (a pad's takes effect on its next
## input).
func _on_option_changed(key: String, value) -> void:
	if key == "pad_preset":
		host.hub.set_pad_preset(str(value))
	elif key == "touch_preset":
		host.hub.set_touch_preset(str(value))


## The Remap screen changed a layout's bindings (UI's remap_changed). UI has already applied and saved the overrides
## through Controls' SimInputData; the hub rebuilds its layouts, so the new keys play at once, mid-match.
func _on_remap_changed(_preset_id: String, _overrides: Array) -> void:
	host.hub.reload_layouts()


## The player's shake for one view: the shake setting, quartered in reduced motion (as SplitView's).
func _shake() -> float:
	var o: Dictionary = ui_hud.opts
	var pref: float = clampf(float(o.get("camera_shake", CamParams.SHAKE_PREF_DEFAULT)), 0.0, 10.0)
	return pref / 10.0 * CamParams.SHAKE_PREF_TOP * (0.25 if bool(o.get("reduced_motion", false)) else 1.0)


## UI's split record (UiHud.split_fn): the rig's, while a compositor draws the panes; empty for one view.
func _split_record() -> Dictionary:
	return split_frame.split_record() if compositor != null and split_frame != null else {}


## UI's planet strip: the bridge's data for the camera's centre and view width.
func _hud_strip() -> Dictionary:
	return UiSimBridge.strip_data(host.S, view_cam_x, 2.0 * cam_rig.half_width(get_viewport().get_visible_rect().size.x))


## The greybox HUD instead of UI's (F2, or --legacy-hud at start). UI's HUD keeps reading events while hidden.
func set_legacy_hud(on: bool) -> void:
	legacy_hud = on
	hud.legacy = on
	ui_hud.visible = not on


## The How to play card, the feedback panel and the Settings screen hold the fight: the sim freezes while one is open (the HUD takes every
## key and click), and held and pending keys are let go so no one flies on when it closes. Closing restores the pause
## it found, so one opened from the pause menu goes back to the menu.
func _on_howto_opened(_first_run: bool) -> void:
	_hold_for_overlay()


func _on_howto_closed(_first_run: bool) -> void:
	_release_overlay()


func _hold_for_overlay() -> void:
	_overlay_resume = host.paused
	host.paused = true
	host.release_all()


func _release_overlay() -> void:
	host.paused = _overlay_resume


## The feedback report's match facts (UI's feedback_fn, docs/ui/hud-spec.md section 20): the seed, the match time from
## sim ticks, whether it has ended, and the setup: the fighters as the HUD names them (who plays, on what device) and
## what only the host knows, the view and the effects this build runs.
func _feedback_context() -> Dictionary:
	var parts: PackedStringArray = []
	for m in ui_hud.hub.models:
		parts.append("%s (%s)" % [m.name, UiFeedback.word("ai") if m.ai else UiFeedback.word("you") + (", " + m.device if m.device != "" else "")])
	var fx: PackedStringArray = []
	for k in ["cracks", "destruction", "embers"]:
		if bool(host.vfx.get(k + "_enabled")):
			fx.append(k)
	var view: String = "split screen" if split_view != null and split_view.is_attached() else "one view"
	var setup: String = " vs ".join(parts) + "; %s; effects: %s" % [view, ", ".join(fx) if not fx.is_empty() else "none"]
	return {"seed": host.seed, "time": host.ticks * SimConst.DT, "ended": host.S.game.ko != null, "setup": setup}


## UI's pause menu (docs/ui/hud-spec.md section 28; P, a pad's Start and the touch pause button toggle it through
## ui_hud.toggle_pause_menu): open, the sim is frozen and held keys are let go; closed, it runs again ("new" is followed
## by new_match_requested). How to play, Settings and Send feedback open over the menu inside the HUD; they find the
## sim paused and leave it paused (_hold_for_overlay), so the menu comes back as it was.
func _on_pause_menu_opened() -> void:
	host.paused = true
	host.release_all()


func _on_pause_menu_closed(_reason: String) -> void:
	host.paused = false


## P, a pad's Start and the touch pause button: UI's pause menu. With the greybox HUD (F2) UI's HUD is hidden, its menu
## with it, so the pause is a plain one there.
func _toggle_pause() -> void:
	if legacy_hud:
		host.paused = not host.paused
	else:
		ui_hud.toggle_pause_menu()


## A click (or a tap, which Godot turns into one) on UI's pause button in touch mode: host glue until Controls' touch
## scheme hit-tests the HUD's targets (the stance ring is theirs).
func _pause_tap(pos: Vector2) -> bool:
	if ui_hud.is_overlay_open():
		return false
	if bool(ui_hud.opts["touch_ui"]) and String(ui_hud.touch_target_at(pos).get("name", "")) == "pause":
		_toggle_pause()
		return true
	return false


## The last input device sets UI's touch mode: a touch turns it on, a key or a pad turns it off (a mouse leaves it as
## it is). Read before anything consumes the event. Keys typed into the feedback panel don't count: a phone's on-screen
## keyboard sends key events, and the panel must not switch layout under the player's thumbs.
func _input(e: InputEvent) -> void:
	if ui_hud == null:
		return
	var touch: bool = _touch_last
	if e is InputEventScreenTouch or e is InputEventScreenDrag:
		touch = true
	elif (e is InputEventKey and not ui_hud.is_feedback_open()) or e is InputEventJoypadButton or (e is InputEventJoypadMotion and absf(e.axis_value) > 0.5):
		touch = false
	if touch != _touch_last:
		_touch_last = touch
		ui_hud.set_option("touch_ui", touch)
	if e is InputEventScreenTouch or e is InputEventScreenDrag:
		_touch_event(e)
	elif e is InputEventJoypadButton or e is InputEventJoypadMotion:
		_pad_event(e)


## The touch controls' geometry for the current screen (sim/input/touch.gd): UI draws the buttons from the same
## call, with the same inputs, so what is drawn is what is hit.
func touch_layout() -> Dictionary:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var safe: Rect2 = ui_hud.layout.safe
	var margin: float = maxf(maxf(vp.x - safe.end.x, vp.y - safe.end.y), 8.0 * ui_hud.dp)
	return SimTouch.layout(vp.x, vp.y, ui_hud.dp, ui_hud.layout.portrait, bool(ui_hud.opts.get("left_handed", false)), margin, host.hub.touch.full_mode)


## A finger on the screen: UI's own targets (pause, feedback) and any open overlay come first; the rest is the
## touch controls' (docs/controls/touch-bridge.md). A touch also takes the match over from the demo, like a key.
func _touch_event(e: InputEvent) -> void:
	var p: Vector2 = e.position
	if e is InputEventScreenDrag:
		host.hub.touch_move(e.index, p.x, p.y)
		return
	if not e.pressed:
		host.hub.touch_up(e.index)
		return
	if ui_hud.is_overlay_open() or host.paused:
		return
	take_over()
	# UI's own targets are asked first: pause and feedback are the HUD's. Transform shares the context slot, so its
	# touch is SimTouch's "context" (the bridge has no transform action yet; the button only shows state).
	var hud_target: String = String(ui_hud.touch_target_at(p).get("name", ""))
	if hud_target == "pause" or hud_target == "feedback":
		return
	host.touch.dp = ui_hud.dp
	host.hub.touch_down(e.index, p.x, p.y, host.touch.widget_at(p.x, p.y, touch_layout()))


## A gamepad, by position (docs/controls/input-scheme.md): buttons, the left stick and the analog triggers go to the
## input hub, which maps them through the pad preset. Start pauses, as P does. Overlays take the pad as they take keys.
var _pad_stick: Dictionary = {}   # device -> the left stick, x right and y up


func _pad_event(e: InputEvent) -> void:
	if ui_hud.is_overlay_open():
		return
	if e is InputEventJoypadButton:
		var btn: String = SimInputNames.PAD_BUTTONS.get(e.button_index, "")
		if btn == "":
			return
		if e.pressed:
			take_over()
			if btn == "start":
				_toggle_pause()
				get_viewport().set_input_as_handled()   # or the HUD, hearing the same press with its menu now open, closes it
				return
		host.hub.pad_button(e.device, btn, e.pressed)
	else:
		match e.axis:
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				var st: Vector2 = _pad_stick.get(e.device, Vector2.ZERO)
				if e.axis == JOY_AXIS_LEFT_X:
					st.x = e.axis_value
				else:
					st.y = -e.axis_value
				_pad_stick[e.device] = st
				if absf(e.axis_value) > 0.5:
					take_over()
				host.hub.pad_stick(e.device, st.x, st.y)
			JOY_AXIS_TRIGGER_LEFT:
				if e.axis_value > 0.5:
					take_over()
				host.hub.pad_trigger(e.device, "lt", e.axis_value)
			JOY_AXIS_TRIGGER_RIGHT:
				if e.axis_value > 0.5:
					take_over()
				host.hub.pad_trigger(e.device, "rt", e.axis_value)


## A pad plugged in or out: one that goes takes its held stick and buttons with it, so the fighter does not fly on.
func _on_joy_connection(device: int, connected: bool) -> void:
	if not connected:
		_pad_stick.erase(device)
		host.hub.pad_disconnected(device)


func take_over() -> void:
	if started:
		return
	started = true
	if host.S.fighters[0].ai != null:
		host.toggle_ai(0)


## Alt plus a flash key fires that flash (Shift: on P2); Alt+F cycles the fighter's shape family.
func _flash_key(e: InputEventKey) -> void:
	var k: int = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
	var who: int = 1 if e.shift_pressed else 0
	var i: int = FLASH_KEYS.find(k)
	var ids: Array = FlashSet.ids()
	if i >= 0 and i < ids.size():
		fire_flash(who, ids[i])
	elif k == KEY_F:
		var fams: Array = ["P", "A", "E", "C"]
		flash_family[who] = fams[(fams.find(flash_family[who]) + 1) % fams.size()]
		if who < fighter_views.size():
			fighter_views[who].flash_view.family = String(flash_family[who])


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey:
		var code: String = RenderKeys.code(e)
		get_viewport().set_input_as_handled()
		if not e.pressed:
			host.key_up(code)
			return
		var fkey: bool = code.length() <= 3 and code.begins_with("F") and code.substr(1).is_valid_int()
		if not e.echo:
			if code == "F3":
				hud.show_perf = not hud.show_perf
				return
			if code == "F2":
				set_legacy_hud(not legacy_hud)
				return
			if code == "F4":
				ui_hud.set_option("show_feed", not bool(ui_hud.opts["show_feed"]))
				return
			if code == "F6":
				if e.ctrl_pressed:
					host.vfx.embers_enabled = not host.vfx.embers_enabled
				elif e.shift_pressed:
					host.vfx.destruction_enabled = not host.vfx.destruction_enabled
				else:
					host.vfx.cracks_enabled = not host.vfx.cracks_enabled
				return
			if code == "F9":
				if e.alt_pressed:
					var steps: Array = RenderLook.PITCH_STEPS
					cam_pitch = float(steps[(steps.find(cam_pitch) + 1) % steps.size()])
				elif e.ctrl_pressed:
					occlusion = PaneWorld.OCCL_STUB if occlusion == PaneWorld.OCCL_HOLE else PaneWorld.OCCL_HOLE
				elif split_view != null:
					if split_view.is_attached():
						split_view.detach()
					else:
						split_view.attach(self)
				return
			if code == "F10":
				ui_hud.set_option("split_solo", not bool(ui_hud.opts.get("split_solo", true)))
				return
			if code == "F11":
				ui_hud.set_option("reduced_motion", not bool(ui_hud.opts.get("reduced_motion", false)))
				return
			if code == "F7":
				flashes_on = not flashes_on
				for pw in all_panes():
					for v in pw.fighter_views:
						v.flashes_on = flashes_on
				return
			if code == "F8":
				flash_legacy = not flash_legacy
				for v in fighter_views:
					v.flash_view.legacy = flash_legacy
				return
			if e.alt_pressed or code == "Alt":
				_flash_key(e)
				return
			if code == "Escape" and not OS.has_feature("web"):
				get_tree().quit()
				return
			if fkey:
				return
			if not e.ctrl_pressed and not e.meta_pressed:
				take_over()
			match code:
				"KeyN":
					start_match(fresh_seed())
					return
				"KeyT":
					host.toggle_ai(1)
					return
				"KeyY":
					host.toggle_ai(0)
					return
				"KeyP":
					_toggle_pause()
					return
			host.key_down(code)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT and _pause_tap(e.position):
			get_viewport().set_input_as_handled()
			return
		take_over()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and host != null:
		host.release_all()


static func fresh_seed() -> int:
	return ((Time.get_ticks_usec() ^ int(Time.get_unix_time_from_system() * 1000.0)) & 0xFFFFFF) | 1


static func parse_args() -> Dictionary:
	var out: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return out


func _record(frame_ms: float, n: int, tick_ms: float, view_ms: float) -> void:
	var row: Array = [frame_ms, host.tick_usec / 1000.0 if n > 0 else 0.0, host.fx_usec / 1000.0 if n > 0 else 0.0, view_ms]
	for i in range(4):
		_ring[i].append(row[i])
		if _ring[i].size() > 240:
			_ring[i].remove_at(0)
		if args.has("bench") and frames >= 60:
			_bench[i].append(row[i])
	if args.has("bench") and frames >= 60:
		if split_frame != null and split_frame.sep > 0.99 and split_frame.e < 0.01:
			_bench_two.append(frame_ms)
		else:
			_bench_other.append(frame_ms)
		var rid: RID = get_viewport().get_viewport_rid()
		_render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu())
		_render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		_draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))


func perf_summary() -> Dictionary:
	return {
		"frame_ms": _mean(_ring[0]), "frame_p95": _pct(_ring[0], 0.95), "tick_ms": _mean(_ring[1]), "fx_ms": _mean(_ring[2]),
		"view_ms": _mean(_ring[3]), "particles": particles.count,
		"draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(),
	}


func _finish() -> void:
	var gh: String = SimHash.stateHash(host.S).gameplay
	if args.has("bench"):
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var d := PackedFloat64Array()
		for x in _draws:
			d.append(float(x))
		var rows: Array = [
			["frame ms (vsync off)", _bench[0]], ["frame ms, two full panes", _bench_two], ["frame ms, other", _bench_other],
			["view update ms / frame", _bench[3]],
			["sim tick ms (per tick)", Array(_bench[1]).filter(func(v): return v > 0.0)],
			["fx+camera ms (per tick)", Array(_bench[2]).filter(func(v): return v > 0.0)],
			["render cpu ms", _render_cpu], ["render gpu ms", _render_gpu], ["draw calls", d],
		]
		var head: String = "%s | %s | %s | %dx%d | %d frames after 60 warm-up | sim ticks %d, final T %.1f s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), OS.get_name(), int(vp.x), int(vp.y), _bench[0].size(), host.ticks, host.S.T]
		print("BENCH " + head)
		var res: Dictionary = {"head": head, "hash": gh, "ticks": host.ticks, "audio": "%d played, %d dropped" % [audio.played, audio.dropped]}
		res["split"] = "%s; two full panes in %.0f%% of frames" % ["on" if compositor != null else "off", 100.0 * _bench_two.size() / maxf(1.0, float(_bench_two.size() + _bench_other.size()))]
		print("BENCH split %s" % res["split"])
		print("BENCH audio %s" % res["audio"])
		for r in rows:
			print("BENCH %-24s %s" % [r[0], _dist(r[1])])
			res[r[0]] = _dist(r[1])
		if OS.has_feature("web"):
			# For browser drivers (research/engine-spike/tools/bench-browser.mjs polls window.__benchResult).
			JavaScriptBridge.eval("window.__benchResult = %s;" % JSON.stringify(res), true)
	if args.has("shot"):
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(args["shot"])
		print("saved " + args["shot"])
	print("gameplay hash at tick %d: %s" % [host.ticks, gh])
	if not OS.has_feature("web"):
		get_tree().quit()


static func _mean(v) -> float:
	if v.size() == 0:
		return 0.0
	var s: float = 0.0
	for x in v:
		s += x
	return s / v.size()


static func _pct(v, q: float) -> float:
	if v.size() == 0:
		return 0.0
	var s = v.duplicate()
	s.sort()
	return s[mini(s.size() - 1, int(s.size() * q))]


static func _dist(v) -> String:
	if v.size() == 0:
		return "n/a"
	return "mean %.3f  p50 %.3f  p95 %.3f  p99 %.3f  max %.3f" % [_mean(v), _pct(v, 0.5), _pct(v, 0.95), _pct(v, 0.99), _pct(v, 1.0)]
