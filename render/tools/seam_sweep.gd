extends SceneTree
## Seam sweep: poses the two fighters across the wrap seam (x = 0 / 9600) at many separations, frames them with the
## reference camera and runs the real renderer (render/main.tscn) on every frame, then checks the result:
## 1. mapping: each fighter lands on the pixel the prototype's w2s() gives, sdx(cam.x, x) * z + vw / 2 across and
##    vh * 0.7 - (y - cam.y) * z down (within 0.5 px);
## 2. no jump: frame to frame, each on-screen fighter's screen motion matches the reference mapping's motion (within
##    0.5 px), and that motion is smooth (no step bigger than MAX_STEP_PX);
## 3. ground: the planet copy under each fighter shows the sim's ground at the fighter's own x (the copies are placed
##    so that view x - copy offset wraps to f.x);
## 4. seam join and coverage: neighbouring copies meet exactly one planet apart, the last terrain column reads column
##    0 again, and the copies cover the whole visible width even when the view is wider than the planet.
## The sweep poses a match state by hand (fighter x and y) and never steps the sim; the renderer only reads it.
##
## Usage (from the repo root):
##   godot --headless --path . --script res://render/tools/seam_sweep.gd [-- --size=1280x720]   numeric; exit 0/1
##   godot --path . --script res://render/tools/seam_sweep.gd -- --shots=DIR                    also saves PNGs
## Try a very wide view (--size=2560x720) to see one wider than the planet.

const SEPS: Array = [0.0, 1.0, 60.0, 400.0, 1500.0, 3000.0, 4500.0, 4790.0]
const SPEED := 25.0          # world units per frame (1500 units/s at 60 Hz)
const SPAN := 3000.0         # each pass covers [W - SPAN/2, W + SPAN/2] around the seam
const PREROLL := 240         # frames for the camera to settle before a pass
const MAX_STEP_PX := 120.0
const TOL_PX := 0.5

var main: Node
var shots: String = ""
var fails: Array = []
var frames_checked: int = 0
var worst_map: float = 0.0
var worst_motion: float = 0.0
var worst_ground: float = 0.0
var worst_join: float = 0.0
var min_cover_margin: float = INF
var widest_view: float = 0.0
var orbit_max_step: float = 0.0


func _initialize() -> void:
	var size := Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
		if a.begins_with("--size="):
			var wh: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
	# A SubViewport of the requested size: headless mode ignores window sizes.
	var vpn := SubViewport.new()
	vpn.size = size
	vpn.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	main.start_match(1)
	var S: SimState = main.host.S
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	print("Seam sweep  %dx%d  %s" % [int(vp.x), int(vp.y), "shots to " + shots if shots != "" else "numeric only"])
	_check_static()
	var W: float = SimConst.W
	for d in SEPS:
		# Together: both fly right through the seam, d apart, at different heights.
		await _pass("together d=%d" % int(d), func(t): return [W - SPAN * 0.5 - d * 0.5 + t, 40.0, W - SPAN * 0.5 + d * 0.5 + t, 200.0], d)
	# Head-on: they meet on the seam (separation passes through 0 there).
	await _pass("head-on", func(t): return [W - SPAN * 0.5 + t * 0.5, 40.0, SPAN * 0.5 - t * 0.5, 200.0], 0.0)
	# Wide: one deep under the sea, one at the ceiling, so the zoom is as small as it gets.
	await _pass("wide (y -250 and 2600)", func(t): return [W - SPAN * 0.5 + t, -250.0, W - SPAN * 0.5 + 200.0 + t, 2600.0], 200.0)
	# Orbit: one fighter laps the planet while the other holds still, so the separation passes HALF; there the
	# reference camera re-targets the other arc and pans across (Camera's call). Reported, not failed, on motion.
	await _pass("orbit (separation through HALF)", func(t): return [SimWrap.wrap(2000.0 + t * 3.2), 400.0, 2000.0, 400.0], -1.0)
	print("frames checked       %d" % frames_checked)
	print("mapping error        max %.4f px (limit %.1f)" % [worst_map, TOL_PX])
	print("motion vs reference  max %.4f px per frame (limit %.1f)" % [worst_motion, TOL_PX])
	print("ground under fighter max %.6f world units" % worst_ground)
	print("copy join error      max %.6f world units" % worst_join)
	print("widest view          %.0f world units (planet %.0f); min coverage margin %.0f" % [widest_view, W, min_cover_margin])
	print("orbit pass           largest screen step %.1f px per frame (the camera's pan when the separation passes HALF)" % orbit_max_step)
	if fails.is_empty():
		print("\nseam sweep passed")
	else:
		for f in fails.slice(0, 20):
			print("FAIL  " + f)
		print("\nseam sweep FAILED (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


func _check_static() -> void:
	var arr: Array = main.planet.terrain_mesh().surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var last: int = v.size() - 1
	if v[0].x != 0.0 or v[last].x != SimConst.W:
		fails.append("terrain strip spans %f..%f, want 0..W" % [v[0].x, v[last].x])
	if int(uv[last].x + 0.5) % SimConst.NC != 0:
		fails.append("last terrain column reads column %d, want 0" % (int(uv[last].x + 0.5) % SimConst.NC))


## One pass: pose(t) returns [ax, ay, bx, by] for travel t. sep >= 0 checks the frame-to-frame motion strictly.
func _pass(label: String, pose: Callable, sep: float) -> void:
	var S: SimState = main.host.S
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var steps: int = int(SPAN / SPEED) if sep >= 0.0 else int(SimConst.W / (SPEED * 3.2))
	_apply(S, pose.call(0.0))
	for i in range(PREROLL):
		main.host.follow(vp.x, vp.y)
	var prev_p: Array = [null, null]
	var prev_e: Array = [null, null]
	var prev_on: Array = [false, false]
	var shot_at: Array = [steps / 2 - 12, steps / 2, steps / 2 + 12]
	for s in range(steps + 1):
		_apply(S, pose.call(float(s) * SPEED))
		main.host.follow(vp.x, vp.y)
		main.render_view(1.0)
		frames_checked += 1
		var cam: SimCamera = main.host.cam
		var z: float = cam.z
		for i in range(2):
			var f = S.fighters[i]
			var fv: Node3D = main.fighter_views[i]
			var p: Vector2 = main.cam_rig.unproject_position(fv.global_position)
			var e := Vector2(SimWrap.sdx(cam.x, f.x) * z + vp.x * 0.5, vp.y * 0.7 - (f.y - cam.y) * z)
			var err: float = p.distance_to(e)
			worst_map = maxf(worst_map, err)
			if err > TOL_PX:
				fails.append("%s frame %d fighter %d: %.2f px from the reference mapping" % [label, s, i, err])
			var on_screen: bool = p.x > -50.0 and p.x < vp.x + 50.0
			if prev_p[i] != null and on_screen and prev_on[i]:
				var dm: float = ((p - prev_p[i]) - (e - prev_e[i])).length()
				worst_motion = maxf(worst_motion, dm)
				var step_px: float = (p - prev_p[i]).length()
				if dm > TOL_PX:
					fails.append("%s frame %d fighter %d: moved %.2f px off the reference motion" % [label, s, i, dm])
				if sep >= 0.0 and step_px > MAX_STEP_PX:
					fails.append("%s frame %d fighter %d: jumped %.1f px" % [label, s, i, step_px])
				if sep < 0.0:
					orbit_max_step = maxf(orbit_max_step, step_px)
			prev_p[i] = p
			prev_e[i] = e
			prev_on[i] = on_screen
			_check_ground(label, s, i, fv.position.x, f.x)
		_check_copies(label, s, vp.x)
		if shots != "" and s in shot_at:
			await RenderingServer.frame_post_draw
			var path: String = "%s/seam_%s_%d.png" % [shots, label.split(" ")[0] + ("%d" % int(sep) if sep > 0.0 else ""), s]
			main.get_viewport().get_texture().get_image().save_png(path)


func _apply(S: SimState, p: Array) -> void:
	for i in range(2):
		var f = S.fighters[i]
		f.x = SimWrap.wrap(p[i * 2])
		f.y = p[i * 2 + 1]
		f.vx = 0.0
		f.vy = 0.0
		f.rot = 0.0


## The ground drawn under a fighter comes from the copy whose span holds its view x; that point must be f.x.
func _check_ground(label: String, s: int, i: int, vx: float, fx: float) -> void:
	for c in main.planet.copies():
		var wx: float = vx - c.position.x
		if wx >= 0.0 and wx < SimConst.W:
			var d: float = absf(SimWrap.sdx(wx, fx))
			worst_ground = maxf(worst_ground, d)
			if d > 0.01:
				fails.append("%s frame %d fighter %d: ground drawn for x %.3f, fighter at %.3f" % [label, s, i, wx, fx])
			return
	fails.append("%s frame %d fighter %d: no planet copy under view x %.1f" % [label, s, i, vx])


func _check_copies(label: String, s: int, vw: float) -> void:
	var cs: Array = main.planet.copies()
	for k in range(cs.size() - 1):
		var j: float = absf(cs[k].position.x + SimConst.W - cs[k + 1].position.x)
		worst_join = maxf(worst_join, j)
		if j > 0.01:
			fails.append("%s frame %d: copies %d and %d are %.4f off one planet apart" % [label, s, k, k + 1, j])
	var hw: float = main.cam_rig.half_width(vw, RenderLook.Z_TERRAIN_BACK)
	widest_view = maxf(widest_view, 2.0 * main.cam_rig.half_width(vw))
	var margin: float = minf(-hw - cs[0].position.x, cs[cs.size() - 1].position.x + SimConst.W - hw)
	min_cover_margin = minf(min_cover_margin, margin)
	if margin < 0.0:
		fails.append("%s frame %d: the planet copies leave %.0f units of the view uncovered" % [label, s, -margin])
