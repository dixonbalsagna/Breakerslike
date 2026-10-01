extends SceneTree
## Cull check: a building's or a roof's face is drawn whole or not at all. building.gdshader throws an uncut
## instance's back faces away in the vertex stage, a corner at a time. If the corners of one face disagree, the face
## is drawn stretched to the screen's corner: a dark stripe from a roof (the bug this check is for; a roof is scaled
## unevenly, and the test once used its normal without the inverse scale). The check pans a camera past roofed houses
## and a tower, at two zooms, two heights and two pitches, and draws every view twice: as the game does, and with the
## back faces left to the rasterizer (the shader's ref_cull). The two pictures must match. Then the failing control:
## the first house again with the old fault put back into a copy of the shader (the normal without the inverse scale,
## each corner tested at its own place), which must not match.
## Needs a window: the pictures are rendered, so under --headless it says so and exits with code 2 (1 is a failure).
##   godot --path . --script res://render/tools/cull_check.gd -- [--out=DIR] [--s=4]

## How far a view's two pictures may be apart (see _differ), of 255. A face seen edge-on can be in one picture and
## not the other, as a sliver a pixel or two thick: the vertex test does not bend the world as the drawing does. That
## measured 30 at most. A stretched face measured 229.
const TOLERANCE := 64.0

var out: String = ""
var seed: int = 4
var main: Node
var fails: int = 0
var views: int = 0
var worst: float = 0.0


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("cull check: needs a window (it renders its pictures); not run under --headless")
		quit(2)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--s="):
			seed = int(a.substr(4))
	var vpn := SubViewport.new()
	vpn.size = Vector2i(1280, 720)
	vpn.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	main.started = true
	main.start_match(seed)
	main.ui_hud.visible = false
	main.hud.visible = false
	# What moves between a view's two draws is hidden: the fighters and the crowd.
	main.pane.get_node("Fighters").visible = false
	for n in main.pane.find_children("Crowd*", "", true, false):
		n.visible = false
	var S: SimState = main.host.S
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	# Two roofed houses in each row, and the widest tower.
	var spots: Array = []
	var per_row: Dictionary = {}
	var tower = null
	for b in S.buildings:
		if not b.alive:
			continue
		if b.kind == "tower":
			if tower == null or b.w > tower.w:
				tower = b
		elif int(per_row.get(int(b.row), 0)) < 2:
			per_row[int(b.row)] = int(per_row.get(int(b.row), 0)) + 1
			spots.append(b)
	if tower != null:
		spots.append(tower)
	if spots.is_empty():
		printerr("cull check: no buildings")
		quit(1)
		return
	for b in spots:
		var res: Array = await _sweep(S, b, vp, true)
		var bad: int = int(res[0])
		var most: float = float(res[1])
		worst = maxf(worst, most)
		var what: String = "%s %d (row %d, x %.0f): 72 views, at most %.1f apart" % [b.kind, int(b.idx), int(b.row), b.x, most]
		if bad > 0:
			fails += 1
			print("FAIL  %s; %d views over %.0f" % [what, bad, TOLERANCE])
		else:
			print("ok    %s" % what)
	# The failing control.
	var mats: Array = [main.planet._bld_mat, main.planet._front_mat]
	var good: Shader = (mats[0] as ShaderMaterial).shader
	var faulty := Shader.new()
	faulty.code = good.code.replace("vec4(NORMAL / s2, 0.0)", "vec4(NORMAL, 0.0)").replace("fp.y = min(fp.y, COLOR.a < 0.5 ? stub - 1.0 : stub);", "fp = w;")
	if faulty.code == good.code or not faulty.code.contains("fp = w;"):
		fails += 1
		print("FAIL  the control could not be built: building.gdshader's cull lines have changed")
	else:
		for m in mats:
			(m as ShaderMaterial).shader = faulty
		var ctl: Array = await _sweep(S, spots[0], vp, false)
		for m in mats:
			(m as ShaderMaterial).shader = good
		if int(ctl[0]) == 0:
			fails += 1
			print("FAIL  control: the old fault matched the reference in every view (at most %.1f apart): the check sees nothing" % float(ctl[1]))
		else:
			print("ok    control: with the old fault %d of 72 views do not match (up to %.1f apart)" % [int(ctl[0]), float(ctl[1])])
	print("cull check %s: %d buildings, %d views, the game's picture and the reference at most %.1f apart" % ["passed" if fails == 0 else "FAILED (%d)" % fails, spots.size(), views, worst])
	quit(0 if fails == 0 else 1)


## Every view of one building: [how many views are over the tolerance, the farthest apart]. `report` counts the views
## and saves the first failing one's pictures (--out).
func _sweep(S: SimState, b, vp: Vector2, report: bool) -> Array:
	var bad: int = 0
	var most: float = 0.0
	for zoom in [0.5, 1.1]:
		for lift in [0.2, 0.75]:
			for pitch in [0.0, 11.0]:
				for step in range(-4, 5):
					var cam_x: float = SimWrap.wrap(b.x + float(step) * b.w * 0.3)
					var cam := Vector3(0.0, WorldTerrain.groundY(S, cam_x) + lift * vp.y / zoom, zoom)
					var a: Image = await _draw(cam_x, cam, pitch, false)
					var r: Image = await _draw(cam_x, cam, pitch, true)
					var n: float = _differ(a, r)
					if report:
						views += 1
					most = maxf(most, n)
					if n <= TOLERANCE:
						continue
					bad += 1
					if report and out != "" and bad == 1:
						a = await _draw(cam_x, cam, pitch, false)   # _differ shrank them
						r = await _draw(cam_x, cam, pitch, true)
						a.save_png("%s/cull-%d-game.png" % [out, int(b.idx)])
						r.save_png("%s/cull-%d-reference.png" % [out, int(b.idx)])
						var dm: Array = _diff_map(a, r)
						(dm[0] as Image).save_png("%s/cull-%d-diff.png" % [out, int(b.idx)])
						print("      first view over: camera x %.0f, zoom %.1f, lift %.2f, pitch %.0f; %d pixels differ, inside %s" % [cam_x, zoom, lift, pitch, int(dm[1]), str(dm[2])])
	return [bad, most]


## One view of the first pane, as the game culls (reference false) or with the back faces left to the rasterizer.
func _draw(cam_x: float, cam: Vector3, pitch: float, reference: bool) -> Image:
	for m in [main.planet._bld_mat, main.planet._front_mat]:
		(m as ShaderMaterial).set_shader_parameter("ref_cull", 1.0 if reference else 0.0)
	main.pane.snap_occlusion()
	main.pane.render(main.host, 1.0, cam_x, cam, Vector2.ZERO, pitch)
	await RenderingServer.frame_post_draw
	main.pane.render(main.host, 1.0, cam_x, cam, Vector2.ZERO, pitch)
	await RenderingServer.frame_post_draw
	return main.get_viewport().get_texture().get_image()


## How far two pictures are apart: both are averaged down to an eighth each way, then the largest difference of any
## channel of any pixel is taken (the engine's metric, so no pixel is read in script). A face drawn in one and not in
## the other is a block of full contrast. What moves between the two draws (clouds, water) moves by far less, and an
## edge a pixel off is averaged to an eighth of its contrast.
static func _differ(a: Image, b: Image) -> float:
	for k in range(3):
		a.shrink_x2()
		b.shrink_x2()
	return float(a.compute_image_metrics(b, false)["max"])


## For a failing view's pictures (--out): white where they differ, how many pixels do, and the box around them.
static func _diff_map(a: Image, b: Image) -> Array:
	var m := Image.create_empty(a.get_width(), a.get_height(), false, Image.FORMAT_L8)
	var n: int = 0
	var box := Rect2i()
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.06:
				m.set_pixel(x, y, Color.WHITE)
				box = Rect2i(x, y, 1, 1) if n == 0 else box.expand(Vector2i(x, y))
				n += 1
	return [m, n, box]
