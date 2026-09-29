extends Control
## The HUD demo: the real HUD (ui/hud/ui_hud.tscn) driven by the mock event feed over a greybox backdrop, so the crown,
## cards, silhouette, meters, barks, feed and layouts can be reviewed without the sim. Nothing here is part of the game.
##
## Run:  godot --path . res://ui/demo/hud_demo.tscn
## Options after "--": --scenario=hero_vs_proud|empress_vs_cyborg|placeholders|stress   --shot=file.png (save a frame)
##   --at=SECONDS (fast-forward the feed to that time before the shot)   --frames=N   --portrait (start portrait-shaped)   --sil --crown --clear --nofeed --nolegend --reduced
## Keys: Tab scenario | Space pause | R restart | S silhouette | F4 feed | C captions | M reduced motion | K crown always on | B brink ring | T arc thickness
##       Z clear zones | L region label | V viewport size | +/- fighter size | H hide this legend

const SEGS: Array = [[0.0, 1200.0, "ocean"], [1200.0, 1800.0, "village"], [1800.0, 2350.0, "plains"], [2350.0, 3850.0, "city"], [3850.0, 4500.0, "village"], [4500.0, 5500.0, "forest"], [5500.0, 6500.0, "desert"], [6500.0, 7600.0, "mountains"], [7600.0, 8000.0, "village"], [8000.0, 8300.0, "plains"], [8300.0, 9600.0, "ocean"]]
const SIZES: Array = [Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1280, 720), Vector2i(390, 844), Vector2i(1080, 1920)]

var hud: UiHud
var feed: UiMockFeed
var scenario_i := 0
var paused := false
var fight_mul := 1.0
var t := 0.0
var size_i := 0
var legend := true
var args: Dictionary = {}
var frames := 0
var thick_i := 0


func _ready() -> void:
	args = _parse_args()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud = preload("res://ui/hud/ui_hud.tscn").instantiate()
	add_child(hud)
	if args.has("scenario"):
		scenario_i = maxi(0, UiMockFeed.SCENARIOS.find(args["scenario"]))
	if args.has("portrait"):
		size_i = 3
	_start_scenario()
	hud.anchor_fn = _anchor
	hud.strip_fn = _strip
	hud.set_option("show_feed", true)
	if args.has("at"):
		var target: float = float(args["at"])
		while feed.t < target:
			_step(1.0 / 60.0)
	if args.has("nolegend"):
		legend = false
	if args.has("clear"):
		hud.set_option("show_clear_zone", true)
	if args.has("sil"):
		hud.set_option("silhouette", true)
	if args.has("crown"):
		hud.set_option("crown_always", true)
	if args.has("nosil"):
		hud.set_option("silhouette", false)
	if args.has("reduced"):
		hud.set_option("reduced_motion", true)
	if args.has("nofeed"):
		hud.set_option("show_feed", false)


func _parse_args() -> Dictionary:
	var out: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return out


func _start_scenario() -> void:
	var scn: String = UiMockFeed.SCENARIOS[scenario_i]
	feed = UiMockFeed.new(scn, 11)
	var f: Array = UiMockFeed.fighters(scn)
	hud.setup(f[0], f[1])


func _step(dt: float) -> void:
	for e in feed.step(dt):
		hud.consume(e)
	t += dt
	hud.advance(dt)


func _process(delta: float) -> void:
	if not paused:
		_step(minf(delta, 0.1))
	queue_redraw()
	frames += 1
	if args.has("frames") and frames >= int(args["frames"]):
		if args.has("shot"):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(str(args["shot"]))
			print("saved ", args["shot"])
		get_tree().quit()


## The fighters' size on screen: a fraction of the viewport (so a phone gets small fighters), times the +/- multiplier.
func _fh() -> float:
	var vp: Vector2 = size
	return minf(vp.y * 0.16, vp.x * 0.14) * fight_mul


## Fighters are placed inside the layout's clear zone, as the camera should frame them.
func _fighter_pos(slot: int) -> Vector2:
	var cz: Rect2 = hud.layout.clear_zone
	var sep: float = (0.24 if not hud.layout.portrait else 0.22) + 0.04 * sin(t * 0.35)
	var cx: float = cz.get_center().x + (-1.0 if slot == 0 else 1.0) * cz.size.x * sep
	var bob: float = sin(t * 1.3 + float(slot) * 2.0) * 10.0
	return Vector2(cx, cz.get_center().y + bob)


func _anchor(slot: int) -> Dictionary:
	return {"pos": _fighter_pos(slot), "h": _fh(), "visible": true}


func _strip() -> Dictionary:
	var W := 9600.0
	var fs: Array = []
	var xs: Array = [2150.0 + 250.0 * sin(t * 0.2), 2900.0 + 300.0 * sin(t * 0.17 + 1.0)]
	var m0: UiFighterModel = hud.hub.model(0)
	var m1: UiFighterModel = hud.hub.model(1)
	var models: Array = [m0, m1]
	for i in range(2):
		fs.append({"x": xs[i], "slot": i, "hidden": models[i] != null and models[i].hidden, "aura": models[i].aura if models[i] != null else Color.WHITE, "seen_x": xs[i] - 120.0})
	return {"W": W, "segs": SEGS, "cam_x": (xs[0] + xs[1]) * 0.5, "cam_w": 2200.0, "dead": [3100.0, 3160.0, 3300.0, 1400.0], "fighters": fs}


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_TAB:
			scenario_i = (scenario_i + 1) % UiMockFeed.SCENARIOS.size()
			_start_scenario()
		KEY_SPACE:
			paused = not paused
		KEY_R:
			feed.restart()
			hud.consume({"type": "match_start"})
		KEY_S:
			hud.set_option("silhouette", not bool(hud.opts["silhouette"]))
		KEY_F4:
			hud.set_option("show_feed", not bool(hud.opts["show_feed"]))
		KEY_C:
			hud.set_option("captions", not bool(hud.opts["captions"]))
		KEY_K:
			hud.set_option("crown_always", not bool(hud.opts["crown_always"]))
		KEY_B:
			hud.set_option("brink_cue", not bool(hud.opts["brink_cue"]))
		KEY_M:
			hud.set_option("reduced_motion", not bool(hud.opts["reduced_motion"]))
		KEY_T:
			thick_i = (thick_i + 1) % 3
			hud.set_option("thickness", [1.0, 1.5, 0.75][thick_i])
		KEY_Z:
			hud.set_option("show_clear_zone", not bool(hud.opts["show_clear_zone"]))
		KEY_L:
			hud.set_option("region_label", not bool(hud.opts["region_label"]))
		KEY_H:
			legend = not legend
		KEY_V:
			size_i = (size_i + 1) % SIZES.size()
			get_window().size = SIZES[size_i]
		KEY_EQUAL, KEY_KP_ADD:
			fight_mul = minf(fight_mul * 1.15, 3.0)
		KEY_MINUS, KEY_KP_SUBTRACT:
			fight_mul = maxf(fight_mul / 1.15, 0.2)


func _draw() -> void:
	# A greybox backdrop: sky, a far ridge, the ground, and two placeholder fighters. Nothing here is real art.
	var vp: Vector2 = size
	var fh: float = _fh()
	var ground_y: float = hud.layout.clear_zone.get_center().y + fh * 0.5 + 4.0
	draw_rect(Rect2(Vector2.ZERO, vp), Color("#2d3a63"))
	draw_rect(Rect2(0, ground_y - vp.y * 0.32, vp.x, vp.y * 0.32), Color("#5a4d85"))
	draw_rect(Rect2(0, ground_y - vp.y * 0.1, vp.x, vp.y * 0.1), Color("#d9776b"))
	draw_rect(Rect2(0, ground_y, vp.x, vp.y - ground_y), Color("#5f9140"))
	for i in range(2):
		var m: UiFighterModel = hud.hub.model(i)
		if m == null:
			continue
		var p: Vector2 = _fighter_pos(i)
		var a: float = 0.3 if m.hidden else 1.0
		var col: Color = Color(m.aura.r * 0.6, m.aura.g * 0.6, m.aura.b * 0.6, a)
		draw_rect(Rect2(p.x - fh * 0.16, p.y - fh * 0.3, fh * 0.32, fh * 0.6), col)
		draw_circle(p + Vector2(0, -fh * 0.42), fh * 0.11, Color(0.93, 0.78, 0.63, a))
	if legend:
		var fs: int = UiText.px(16.0, hud.layout.s, 12.0)
		var text: String = "DEMO  scenario %s   %dx%d   Tab scenario  Space pause  R restart  S silhouette  F4 feed  C captions  M motion  K crown always  B brink ring  T thickness  Z zones  L label  V size  +/- fighter  H legend" % [UiMockFeed.SCENARIOS[scenario_i], int(vp.x), int(vp.y), ]
		var lines: PackedStringArray = UiText.wrap(text, fs, vp.x - 20.0)
		var y: float = vp.y - float(fs) * float(lines.size()) - 2.0
		if hud.layout.portrait:
			y = 4.0
		for l in lines:
			UiText.draw(self, l, Vector2(10.0, y + float(fs)), fs, Color(1, 1, 1, 0.75), -1, 1.5)
			y += float(fs) + 1.0
