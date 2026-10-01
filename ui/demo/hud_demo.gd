extends Control
## The HUD demo: the real HUD (ui/hud/ui_hud.tscn) driven by the mock event feed over a greybox backdrop, so the crown,
## cards, silhouette, meters, barks, feed and layouts can be reviewed without the sim. Nothing here is part of the game.
##
## Run:  godot --path . res://ui/demo/hud_demo.tscn
## Options after "--": --scenario=hero_vs_proud|empress_vs_cyborg|placeholders|stress|controls   --shot=file.png (save a frame)
##   --at=SECONDS (fast-forward the feed to that time before the shot)   --frames=N   --portrait (start portrait-shaped)   --sil --crown --clear --nofeed --nolegend --reduced --split --flip --prompts --dp=2.6 --touch[=press|ready] --left --device=xbox --preset=arena|brawler|simple-pad|kb-solo|kb-shared-p2 --ready --stance=N --target=github|mailto|form --howto[=PAGE] --ko --feedback[=copied|review]
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
var split_on := false          # D: a simulated split screen (the divider, the ring map, the pointers, per-pane anchors)
var split_sep := 0.0
var split_sigma := 1           # X flips it (slot 0 on the left, or on the right)
var ring_always := true        # the ring map shows even with one camera


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
	hud.split_fn = _split_fn
	hud.set_option("show_feed", true)
	if args.has("at"):
		var target: float = float(args["at"])
		while feed.t < target:
			_step(1.0 / 60.0)
	if args.has("nolegend"):
		legend = false
	if args.has("split"):
		split_on = true
		split_sep = 1.0
	if args.has("flip"):
		split_sigma = -1
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
	if args.has("prompts"):
		hud.set_option("show_prompts", true)
	if args.has("dp"):
		hud.set_density(float(args["dp"]))
	if args.has("left"):
		hud.set_option("left_handed", true)
	if args.has("touch"):
		hud.set_option("touch_ui", true)
	if args.has("touch"):
		# A mock of the host's touch state, for the screenshots: --touch=press shows the buttons held and a stick drag, --touch=ready the idle layout.
		var tstate := {"attack": {"down": false, "hold": 0.0}, "guard": {"down": false}, "power": {"down": false}, "stick": {"active": false}}
		if str(args["touch"]) == "press":
			tstate = {"attack": {"down": true, "hold": 0.6}, "guard": {"down": false}, "power": {"down": true}, "stick": {"active": true, "base": Vector2(size.x * 0.2, size.y * 0.72), "thumb": Vector2(size.x * 0.2 + 90.0, size.y * 0.72 - 40.0), "sprint": false}}
		hud.touch_state_fn = func(): return tstate
		hud.consume({"type": "availability", "actor": 0, "action": "transform", "available": str(args["touch"]) == "press"})
	if args.has("device"):
		hud.set_device(0, str(args["device"]))
	if args.has("preset"):
		# A control layout: a pad preset (arena, brawler, simple-pad) or any layout id (kb-solo, kb-shared-p2) forced onto the legend and the card.
		if ["arena", "brawler", "simple-pad"].has(str(args["preset"])):
			hud.set_option("pad_preset", str(args["preset"]))
		else:
			hud.set_option("control_scheme", str(args["preset"]))
	if args.has("ready"):
		hud.consume({"type": "availability", "actor": 0, "action": "transform", "available": true})
	if args.has("stance"):
		hud.consume({"type": "stance_set", "actor": 0, "stance": int(args["stance"])})
	if args.has("target"):
		# A send target for the feedback screenshots (the shipped data has none yet): github, mailto or form, with a sample address.
		var tg: Dictionary = UiData.send()["_targets"]
		tg["mailto"]["to"] = "team@example.test"
		tg["form"]["url"] = "https://forms.example.test/f?t={title}&b={body}"
		UiFeedback.target_override = str(args["target"])
	if args.has("ko"):
		hud.consume({"type": "ko", "winner": 0, "loser": 1})
		for i in range(240):
			hud.advance(1.0 / 60.0)
	if args.has("feedback"):
		hud.show_feedback("pause")
		hud.toggle_feedback_tag("bug")
		hud.toggle_feedback_tag("confusing")
		hud._fb_text.text = "The beam froze after the second pulse."
		if str(args["feedback"]) == "review":
			hud.feedback_fn = func(): return {"commit": "02c8fd3", "date": "2026-09-30", "seed": 123456, "time": 222.0}
			hud.send_feedback()
		if str(args["feedback"]) == "copied":
			hud.feedback_fn = func(): return {"commit": "02c8fd3", "date": "2026-09-30", "seed": 123456, "time": 222.0}
			hud.copy_feedback()
	if args.has("howto"):
		hud.show_howto(false, int(args["howto"]) if str(args["howto"]).is_valid_int() else 0)


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


func _split_fn() -> Dictionary:
	return _split_record() if (split_sep > 0.001 or ring_always) else {}


func _process(delta: float) -> void:
	split_sep = move_toward(split_sep, 1.0 if split_on else 0.0, delta / 0.45)
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
	var merged: Vector2 = _merged_pos(slot)
	if split_sep <= 0.001:
		return merged
	return merged.lerp(_split_pos(slot), split_sep)


func _merged_pos(slot: int) -> Vector2:
	var cz: Rect2 = hud.layout.clear_zone
	var sep: float = (0.24 if not hud.layout.portrait else 0.22) + 0.04 * sin(t * 0.35)
	var cx: float = cz.get_center().x + (-1.0 if slot == 0 else 1.0) * cz.size.x * sep
	var bob: float = sin(t * 1.3 + float(slot) * 2.0) * 10.0
	return Vector2(cx, cz.get_center().y + bob)


## The divider's tilt in the demo: swings between about -25 and +25 degrees.
func _phi() -> float:
	return deg_to_rad(25.0) * sin(t * 0.4)


func _split_n() -> Vector2:
	var phi: float = _phi()
	return Vector2(float(split_sigma) * cos(phi), -sin(phi))


## Camera's anchors (split-screen.md section 3): each chest on its outer side of the divider.
func _split_pos(slot: int) -> Vector2:
	var vp: Vector2 = size
	var n: Vector2 = _split_n()
	var sgn: float = -1.0 if slot == 0 else 1.0
	return vp * 0.5 + Vector2(0.0, 0.12 * vp.y) + Vector2(n.x * 0.28 * vp.x * sgn, n.y * 0.24 * vp.y * sgn)


## The record Camera would send (see UiSplit): the divider, sigma, the ring map's angles.
func _split_record() -> Dictionary:
	var vp: Vector2 = size
	var W := 9600.0
	var xs: Array = [2150.0 + 250.0 * sin(t * 0.2), 2900.0 + 300.0 * sin(t * 0.17 + 1.0)]
	var ring := {"angle_A": xs[0] / W * TAU, "angle_B": xs[1] / W * TAU, "sigma": split_sigma, "arc_A": 0.5, "arc_B": 0.5, "swing": 0.0, "sep": split_sep, "W": 153600.0}
	return {"sep": split_sep, "c": vp * 0.5, "n": _split_n(), "gap": maxf(3.0, 0.005 * vp.x), "fade": clampf(split_sep * 5.0, 0.0, 1.0), "slam": 0.0, "sigma": split_sigma, "dist_bh": 48.0 + 30.0 * sin(t * 0.3), "pointer": "split", "ring": ring}


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
		KEY_D:
			split_on = not split_on
		KEY_X:
			split_sigma = -split_sigma
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
		var text: String = "DEMO  scenario %s   %dx%d   Tab scenario  Space pause  R restart  S silhouette  F4 feed  C captions  M motion  K crown always  B brink ring  D split  X flip  T thickness  Z zones  L label  V size  +/- fighter  H legend" % [UiMockFeed.SCENARIOS[scenario_i], int(vp.x), int(vp.y), ]
		var lines: PackedStringArray = UiText.wrap(text, fs, vp.x - 20.0)
		var y: float = vp.y - float(fs) * float(lines.size()) - 2.0
		if hud.layout.portrait:
			y = 4.0
		for l in lines:
			UiText.draw(self, l, Vector2(10.0, y + float(fs)), fs, Color(1, 1, 1, 0.75), -1, 1.5)
			y += float(fs) + 1.0
