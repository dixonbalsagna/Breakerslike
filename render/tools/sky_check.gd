extends SceneTree
## Sky check: at tier 3 and 4 the clouds part for a fighter, and that is all the sky does (QA's GB-002: the reaction
## once paled the sky in a tall opening down to the horizon, which read as a pale pillar from a high camera and hung
## in the sky for a fighter nobody could see). The tool poses a fresh match's fighters by hand on open plains (its own
## state; no tick runs), draws the sky with both at tier 1 and again with both at tier 4, from a low and a high
## camera, and compares the two pictures above the horizon:
## - with the clouds off, nothing differs: the reaction draws nothing where there is no cloud;
## - with the clouds on, the last of the cloud band above the horizon does not differ: no pillar to the horizon;
## - with the clouds on, something does differ in at least one place round the planet: the check is not blind;
## - a tier 4 fighter off the screen changes nothing;
## - with reduced motion (PaneWorld.sky_calm) nothing differs.
## Needs a window: the pictures are rendered, so under --headless it says so and exits with code 2 (1 is a failure).
##   godot --path . --script res://render/tools/sky_check.gd -- [--out=DIR] [--s=4]

const SAME := 3.0      # the largest difference of a channel (of 255) between two draws of the same sky
const SEEN := 12.0     # ... and the least that counts as the clouds having parted

var out: String = ""
var seed: int = 4
var main: Node
var fails: int = 0


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("sky check: needs a window (it renders its pictures); not run under --headless")
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


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok   " if ok else "FAIL ", what])
	if not ok:
		fails += 1


func _run() -> void:
	await process_frame
	main.started = true
	main.start_match(seed)
	main.ui_hud.visible = false
	main.hud.visible = false
	# Only the sky is judged. Hidden: the fighters (their auras and streaks grow with the tier), VFX's effects, and the
	# planet (a building's cut-away round a fighter changes with his drawn size, and a roof can stand above the horizon).
	for name in ["Fighters", "Vfx", "Planet"]:
		main.pane.get_node(name).visible = false
	var S: SimState = main.host.S
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var seen: float = 0.0
	# Places round the planet with dry ground under both fighters, so the clouds differ from place to place.
	var places: Array = []
	for c in range(0, SimConst.NC, SimConst.NC / 12):
		var x: float = float(c) * SimConst.COL
		if WorldWater.surfaceAt(S, x) <= WorldTerrain.groundY(S, x) + 0.5:
			places.append(x)
	for lift in [0.0, 3000.0]:
		var cam_name: String = "high" if lift > 0.0 else "low"
		var worst_off: float = 0.0
		var worst_low: float = 0.0
		var worst_far: float = 0.0
		var worst_calm: float = 0.0
		var most: float = 0.0
		for x0 in places:
			# Both on the screen.
			_pose(S, x0, 260.0, lift, vp)
			PaneWorld.clouds_on = false
			var off1: Image = await _sky(S, 1.0, 1.0, vp, 0)
			var off4: Image = await _sky(S, 4.0, 4.0, vp, 0)
			var top: int = _horizon_row(off1)
			var low: Rect2i = _low_band(top, vp)
			worst_off = maxf(worst_off, _peak(off1, off4, Rect2i(0, 0, int(vp.x), top)))
			PaneWorld.clouds_on = true
			var on1: Image = await _sky(S, 1.0, 1.0, vp, 0)
			var on4: Image = await _sky(S, 4.0, 4.0, vp, 0)
			var d: float = _peak(on1, on4, Rect2i(0, 0, int(vp.x), top))
			if d > most:
				most = d
				if out != "":
					on1.save_png("%s/sky-check-%s-tier1.png" % [out, cam_name])
					on4.save_png("%s/sky-check-%s-tier4.png" % [out, cam_name])
			if low.size.y > 0:
				worst_low = maxf(worst_low, _peak(on1, on4, low))
			PaneWorld.sky_calm = true
			var calm4: Image = await _sky(S, 4.0, 4.0, vp, 0)
			PaneWorld.sky_calm = false
			worst_calm = maxf(worst_calm, _peak(on1, calm4, Rect2i(0, 0, int(vp.x), top)))
			# Fighter B far off the screen, the camera on A at tier 1: B at tier 4 must change nothing.
			_pose(S, x0, 1500.0, lift, vp)
			var far1: Image = await _sky(S, 1.0, 1.0, vp, 1)
			var far4: Image = await _sky(S, 1.0, 4.0, vp, 1)
			worst_far = maxf(worst_far, _peak(far1, far4, Rect2i(0, 0, int(vp.x), int(vp.y))))
		seen = maxf(seen, most)
		_expect(worst_off <= SAME, "%s camera, clouds off: tier 4 draws nothing in the sky (%.0f of 255 at most, %d places)" % [cam_name, worst_off, places.size()])
		_expect(worst_low <= SAME, "%s camera: the last of the band above the horizon is left alone (%.0f)" % [cam_name, worst_low])
		_expect(worst_far <= SAME, "%s camera: a tier 4 fighter off the screen changes nothing (%.0f)" % [cam_name, worst_far])
		_expect(worst_calm <= SAME, "%s camera: with reduced motion nothing parts (%.0f)" % [cam_name, worst_calm])
		_expect(most >= SEEN, "%s camera: the clouds do part somewhere (%.0f of 255 at the most changed place)" % [cam_name, most])
	print("sky check %s" % ("passed" if fails == 0 else "FAILED (%d)" % fails))
	quit(0 if fails == 0 else 1)


## Both fighters at a place, `half` either side of it, `lift` above the ground.
func _pose(S: SimState, x0: float, half: float, lift: float, vp: Vector2) -> void:
	for i in range(2):
		var f = S.fighters[i]
		f.x = SimWrap.wrap(x0 + (-half if i == 0 else half))
		f.y = WorldTerrain.groundY(S, f.x) + 2.0 + lift
		f.z = 0.0
	for k in range(3):
		main.host.follow(vp.x, vp.y)


## The picture with the two tiers set; look 0 frames the point between the fighters, 1 frames fighter A.
func _sky(S: SimState, ta: float, tb: float, vp: Vector2, look: int) -> Image:
	S.fighters[0].tier = ta
	S.fighters[1].tier = tb
	var zoom: float = 0.6
	var cam_x: float = S.fighters[0].x if look == 1 else SimWrap.wrap(S.fighters[0].x + SimWrap.sdx(S.fighters[0].x, S.fighters[1].x) * 0.5)
	var cam := Vector3(0.0, S.fighters[0].y + 45.0 + 150.0 / zoom - 0.2 * vp.y / zoom, zoom)
	for k in range(2):
		main.pane.snap_occlusion()
		main.pane.render(main.host, 1.0, cam_x, cam, Vector2.ZERO)
		await RenderingServer.frame_post_draw
	return main.get_viewport().get_texture().get_image()


## The screen row of the sky's horizon line in a picture drawn with the planet hidden: below the line the sky is one
## colour (the horizon's), so it is the first row from the bottom, in the middle column, that is not.
static func _horizon_row(img: Image) -> int:
	var x: int = img.get_width() / 2
	var c0: Color = img.get_pixel(x, img.get_height() - 2)
	for y in range(img.get_height() - 3, 0, -1):
		var c: Color = img.get_pixel(x, y)
		if absf(c.r - c0.r) + absf(c.g - c0.g) + absf(c.b - c0.b) > 0.012:
			return y
	return 0


## The rows of the cloud band's last 0.09 above the horizon (the reaction begins at 0.14), in the middle half of the
## screen: a row is one height only near the screen's middle, since a line of equal elevation curves at the sides.
func _low_band(horizon_row: int, vp: Vector2) -> Rect2i:
	var m: ShaderMaterial = main.pane._sky_mat
	var thin: float = 1.0 + float(m.get_shader_parameter("sky_thin")) * float(m.get_shader_parameter("space"))
	var rows: int = int(0.09 * vp.y * 0.5 / thin)
	var top: int = maxi(0, horizon_row - rows)
	return Rect2i(int(vp.x * 0.25), top, int(vp.x * 0.5), horizon_row - top)


static func _peak(a: Image, b: Image, r: Rect2i) -> float:
	if r.size.x <= 0 or r.size.y <= 0:
		return 0.0
	return float(a.get_region(r).compute_image_metrics(b.get_region(r), false)["max"])
