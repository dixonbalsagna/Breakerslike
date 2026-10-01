extends SceneTree
## Pane check: the plumbing Camera's split-screen compositor plugs into (render/core/pane_world.gd, main.gd's
## make_pane, move_pane0 and compositor; docs/rendering/README.md, "Panes and the split screen"). A stand-in
## compositor takes Camera's place: it records the frames it is given and shows the two panes side by side. With the
## fighters posed far apart so the rig splits, it checks:
## 1. sharing: the second pane draws the first pane's ground data, meshes and props, with its own materials;
## 2. cameras: each pane's camera puts a fighter's chest exactly where the rig's SplitFrame says (within 0.5 px), and
##    each pane's fore rule and curvature carry its own camera; Camera's frame carries the pitch and each pane's
##    cut-away request, both reach the panes, and with a pitch a chest at depth still lands where the frame says;
## 3. flashes: a flash fired on the first pane shows in the second, and Audio gets one cue for it;
## 4. the HUD: split_fn gives the rig's record while a compositor is attached, and nothing without one;
## 5. the sim: a match played with the compositor attached ends on the same gameplay hash as one without;
## 6. the cut-away and the pitch: a pane's cut-away follows Camera's request (none, one fighter's, a given radius), and
##    at every pitch the fighter plane's centre point stays at the screen's centre at the zoom's distance;
## 7. the inset: a third follower pane outside the split's two, drawn at its own viewport's size;
## 8. attaching again: Camera's compositor attached, detached and attached again keeps the same two panes.
## Needs a window for the picture (--out); the numeric checks also run headless.
##   godot --path . --script res://render/tools/pane_check.gd -- [--out=DIR]

class StandIn:
	extends RefCounted
	var frames: int = 0
	var last: SplitFrame = null
	func present(f: SplitFrame) -> void:
		frames += 1
		last = f
	func pane_jitter(_i: int) -> Vector2:
		return Vector2.ZERO

var main: Node
var out: String = ""
var fails: Array = []
var checks: int = 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var vpn := SubViewport.new()
	vpn.size = Vector2i(1280, 720)
	vpn.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)


func _run() -> void:
	await process_frame
	# 5, first half: a match with no compositor.
	main.start_match(4, {"p1": true, "p2": true})
	for k in range(1800):
		main.frame(1.0 / 60.0)
	var hash_plain: String = str(SimHash.stateHash(main.host.S).gameplay)
	_expect(main._split_record().is_empty(), "split_fn gave a record with no compositor attached")
	# The plumbing.
	main.start_match(1)
	var S: SimState = main.host.S
	var size := Vector2i(1280, 720)
	var sv0: SubViewport = main.move_pane0(size)
	var sv1: SubViewport = main.make_pane(size)
	main.add_child(sv0)
	main.add_child(sv1)
	var comp := StandIn.new()
	main.compositor = comp
	var p0: PaneWorld = main.panes[0]
	var p1: PaneWorld = main.panes[1]
	# 1: sharing.
	_expect(p1.planet.ground == p0.planet.ground, "the second pane has its own ground field")
	_expect(p1.planet._terrain_meshes == p0.planet._terrain_meshes and p1.planet._crowd == p0.planet._crowd, "the second pane has its own meshes or props")
	_expect(p1.planet._terrain_mat != p0.planet._terrain_mat and p1.planet._crowd_mat != p0.planet._crowd_mat, "the panes share a terrain or crowd material")
	_expect(p1.mats != p0.mats, "the panes share their material state")
	# Pose the fighters far apart and let the rig split.
	var c: float = 5900.0 * SimConst.PS
	for i in range(2):
		var f = S.fighters[i]
		f.x = SimWrap.wrap(c + (-12000.0 if i == 0 else 12000.0))
		f.y = WorldTerrain.groundY(S, f.x) + 60.0
		f.face = 1.0 if i == 0 else -1.0
	var vp: Vector2 = Vector2(size)
	for k in range(600):
		main.host.follow(vp.x, vp.y)
		main.split_rig.step(S, vp.x, vp.y, [])
	main.render_view(1.0)
	await process_frame
	main.render_view(1.0)
	var fr: SplitFrame = comp.last
	_expect(comp.frames > 0 and fr != null, "the compositor was not given a frame")
	_expect(fr != null and fr.sep > 0.5, "the rig did not split with the fighters %d units apart (sep %.2f)" % [24000, fr.sep if fr != null else -1.0])
	# 2: cameras.
	for i in range(2):
		var pw: PaneWorld = main.panes[i]
		var f = S.fighters[i]
		var chest := Vector3(SimWrap.sdx(pw.view_cam_x, f.x), f.y + CamParams.CHEST, 0.0)
		var got: Vector2 = pw.cam_rig.unproject_position(chest)
		var want: Vector2 = fr.screen_pos(i, f.x, f.y + CamParams.CHEST)
		_expect(got.distance_to(want) <= 0.5, "pane %d puts fighter %d's chest at %s, the rig says %s" % [i, i, got, want])
		_expect(pw.planet._terrain_mat.get_shader_parameter("fore_cam") == pw.cam_rig.position, "pane %d's fore rule does not carry its camera" % i)
	_expect(absf(p0.view_cam_x - p1.view_cam_x) > 1000.0, "the panes' cameras did not part (%.0f and %.0f)" % [p0.view_cam_x, p1.view_cam_x])
	# 2b: Camera's frame carries the pitch and each pane's cut-away request, and both reach the panes. With a pitch the
	# rig's mapping is the 3D camera's: a fighter's chest, at depth too, lands where the frame says.
	for pitch in [11.0, 49.0, 0.0]:
		main.cam_pitch = pitch
		main.split_rig.pitch_deg = pitch     # main sets it each frame it draws; the rig takes it at its next step
		for i in range(2):
			S.fighters[i].z = -600.0 if (i == 0 and pitch > 0.0) else 0.0
		for k in range(300):
			main.host.follow(vp.x, vp.y)
			main.split_rig.step(S, vp.x, vp.y, [])
		main.render_view(1.0)
		fr = comp.last
		_expect(absf(fr.pitch - pitch) < 0.001, "the frame's pitch is %.1f with the host's at %.1f" % [fr.pitch, pitch])
		for i in range(2):
			var pw: PaneWorld = main.panes[i]
			var f = S.fighters[i]
			_expect(absf(pw.cam_rig.pitch_deg - pitch) < 0.001, "pane %d draws at pitch %.1f, not %.1f" % [i, pw.cam_rig.pitch_deg, pitch])
			_expect(pw.cutaway == fr.cutaway[i], "pane %d's cut-away request is not the frame's (%s, %s)" % [i, pw.cutaway, fr.cutaway[i]])
			var chest := Vector3(SimWrap.sdx(pw.view_cam_x, f.x), f.y + CamParams.CHEST, f.z)
			var got: Vector2 = pw.cam_rig.unproject_position(chest)
			var want: Vector2 = fr.screen_pos(i, f.x, f.y + CamParams.CHEST, f.z)
			_expect(got.distance_to(want) <= 0.5, "at pitch %.0f pane %d puts fighter %d's chest (depth %.0f) at %s, the rig says %s" % [pitch, i, i, f.z, got, want])
	main.cam_pitch = 0.0
	main.split_rig.pitch_deg = 0.0
	# 4: the HUD record.
	var rec: Dictionary = main._split_record()
	_expect(not rec.is_empty() and absf(float(rec.get("sep", 0.0)) - fr.sep) < 1e-6, "split_fn did not give the rig's record")
	# 3: flashes.
	var cues: int = main.host.pending_cues.size()
	main.fire_flash(0, "found")
	for k in range(6):
		S.T += 1.0 / 60.0
		main.render_view(1.0)
	var fv1: FlashView = p1.fighter_views[0].flash_view
	_expect(fv1.cur == "found" and fv1.visible, "the second pane's flash did not follow (showing '%s')" % fv1.cur)
	_expect(main.host.pending_cues.size() - cues <= 1, "Audio got %d cues for one flash" % (main.host.pending_cues.size() - cues))
	if out != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var a: Image = sv0.get_texture().get_image()
		var b: Image = sv1.get_texture().get_image()
		var pic := Image.create_empty(1288, 360, false, Image.FORMAT_RGBA8)
		a.resize(640, 360)
		b.resize(640, 360)
		pic.blit_rect(a, Rect2i(0, 0, 640, 360), Vector2i.ZERO)
		pic.blit_rect(b, Rect2i(0, 0, 640, 360), Vector2i(648, 0))
		pic.save_png("%s/panes.png" % out)
		print("saved %s/panes.png" % out)
	# 5, second half: the same match as the first, with the compositor attached.
	main.start_match(4, {"p1": true, "p2": true})
	for k in range(1800):
		main.frame(1.0 / 60.0)
	var hash_split: String = str(SimHash.stateHash(main.host.S).gameplay)
	_expect(hash_split == hash_plain, "the gameplay hash differs with a compositor attached (%s, %s)" % [hash_split, hash_plain])
	print("gameplay hash without and with the compositor: %s, %s; frames presented %d" % [hash_plain, hash_split, comp.frames])
	# 6: the cut-away request and the pitch, pane by pane.
	S = main.host.S
	var cam := Vector3(0.0, S.fighters[0].y, 0.8)
	var cx: float = S.fighters[0].x
	for req in [[{}, true], [{"request": false}, false], [{"only": 1}, false], [{"only": 0, "radius_px": 123.0}, true]]:
		p0.cutaway = req[0]
		p0.render(main.host, 1.0, cx, cam, Vector2.ZERO)
		var hole: Vector4 = p0.planet._bld_mat.get_shader_parameter("hole")[0]
		_expect((hole.w > 0.0) == req[1], "cut-away request %s gave fighter 0 a hole of radius %.1f" % [req[0], hole.w])
		if req[0].has("radius_px"):
			_expect(absf(hole.w - 123.0) < 0.01, "the cut-away's radius was not Camera's (%.1f)" % hole.w)
	p0.cutaway = {}
	for pitch in RenderLook.PITCH_STEPS:
		p0.render(main.host, 1.0, cx, cam, Vector2.ZERO, pitch)
		var look := Vector3(0.0, cam.y + 0.2 * vp.y / cam.z, 0.0)
		var at: Vector2 = p0.cam_rig.unproject_position(look)
		_expect(at.distance_to(vp * 0.5) <= 0.5, "at pitch %.0f the plane's centre point lands at %s, not the screen's centre" % [pitch, at])
		_expect(absf(p0.cam_rig.position.distance_to(look) - CameraRig.distance_for(cam.z, vp.y)) < 0.01, "at pitch %.0f the camera is not at the zoom's distance" % pitch)
		var deep: Vector2 = p0.cam_rig.unproject_position(look + Vector3(0.0, 0.0, -1000.0))
		_expect((pitch == 0.0 and absf(deep.y - at.y) < 0.5) or (pitch > 0.0 and deep.y < at.y - 10.0), "at pitch %.0f a point 1,000 units deep draws at y %.1f (the centre is %.1f)" % [pitch, deep.y, at.y])
	# 7: the inset pane is a follower outside the split's panes.
	var svi: SubViewport = main.make_inset(Vector2i(320, 180))
	main.add_child(svi)
	_expect(main.inset != null and main.panes.size() == 2 and main.all_panes().size() == 3, "the inset is not a third pane outside the split's two")
	_expect(main.inset.planet.ground == p0.planet.ground and main.inset.mats != p0.mats, "the inset does not share the first pane's world with its own materials")
	main.inset.render(main.host, 1.0, S.fighters[1].x, Vector3(0.0, S.fighters[1].y, 0.48), Vector2.ZERO)
	_expect(absf(main.inset.cam_rig.view_h - 180.0) < 0.5, "the inset does not draw at its own viewport's size (%.0f)" % main.inset.cam_rig.view_h)
	# 8: Camera's own compositor attached, detached and attached again (F9 twice; QA's GB-001) keeps the two panes.
	main.compositor = null
	main.remove_child(sv0)
	main.remove_child(sv1)
	var view := SplitView.new()
	main.add_child(view)
	view.attach(main)
	view.detach()
	view.attach(main)
	_expect(main.panes.size() == 2 and view.viewports[0] == sv0 and view.viewports[1] == sv1, "attaching again made new panes (%d panes)" % main.panes.size())
	_expect(main.panes[0].get_parent() == view.viewports[0] and main.panes[1].get_parent() == view.viewports[1], "after attaching again the panes are not in the compositor's viewports")
	_expect(main.compositor == view and view.is_attached(), "after attaching again the compositor is not attached")
	main.render_view(1.0)
	_expect(view.last_frame != null, "after attaching again no frame was presented")
	print("Pane check  %d checks" % checks)
	if fails.is_empty():
		print("\npane check passed")
	else:
		for f in fails:
			print("FAIL  " + f)
		print("\npane check FAILED (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
