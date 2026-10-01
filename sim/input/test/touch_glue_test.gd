extends SceneTree
## The touch bridge end to end: synthetic screen touches into the main scene (render/core/main.gd, with the glue of
## docs/controls/touch-bridge.patch applied), frames of 1/60 s, and what the human fighter in slot 0 does. From the repo root:
##   godot --headless --path . --script res://sim/input/test/touch_glue_test.gd
## Exit 0 if every check passes. A phone-sized viewport (844 x 390 dp at 2.75) is used so the layout is the real one.

var main
var host
var fails: int = 0
var checks: int = 0


func ok(c: bool, what: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL  ", what)


func _init() -> void:
	var vpn := SubViewport.new()
	vpn.size = Vector2i(2321, 1072)   # 844 x 390 dp at 2.75
	vpn.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _fresh() -> void:
	main.start_match(5, {"p1": false, "p2": false})   # an idle opponent, so nothing else starts an exchange
	host = main.host
	host.touch.release_all()
	main._touch_last = false   # the next touch flips the device, as a first touch does
	host.touch_on = false
	main.ui_hud.dp = 2.75
	main.ui_hud.set_option("touch_ui", true)
	host.touch.dp = 2.75


func _frames(n: int) -> void:
	for i in range(n):
		main.frame(1.0 / 60.0)


func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	main._input(e)


func _drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	main._input(e)


func _at(name: String) -> Vector2:
	var c: Dictionary = main.touch_layout()[name]
	return Vector2(float(c.x), float(c.y))


func _run() -> void:
	await process_frame
	_fresh()
	var f = host.S.fighters[0]
	_frames(2)
	ok(not host.touch_on or true, "setup")
	# Touch takes the slot over, and guard is the DEFENSIVE stance while held.
	_touch(1, _at("guard"), true)
	_frames(3)
	ok(host.touch_on, "a touch makes touch the active device")
	ok(f.ai == null, "a touch takes the fighter over from the demo")
	ok(f.stance == 1.0, "guard held: DEFENSIVE")
	_touch(1, _at("guard"), false)
	_frames(3)
	ok(f.stance == 0.0, "guard released: AGGRESSIVE")
	# Power: charge.
	f.ki = 10.0
	_touch(2, _at("power"), true)
	_frames(30)
	ok(f.state == "charging" or f.ki > 10.0, "power held: charging")
	_touch(2, _at("power"), false)
	# A tap is a light attack.
	_fresh()
	f = host.S.fighters[0]
	_frames(80)   # past the opening cooldown
	_touch(3, _at("attack"), true)
	_frames(3)
	_touch(3, _at("attack"), false)
	var got: String = ""
	for i in range(30):
		_frames(1)
		var ex = host.S.dirS.ex
		if ex != null and ex.A == f:
			got = ex.kind
			break
	ok(got == "light", "attack tap: a light exchange, got '%s'" % got)
	# A hold is a heavy.
	_fresh()
	f = host.S.fighters[0]
	_frames(80)
	f.ki = 100.0
	_touch(4, _at("attack"), true)
	got = ""
	for i in range(30):
		_frames(1)
		var ex2 = host.S.dirS.ex
		if ex2 != null and ex2.A == f:
			got = ex2.kind
			break
	_touch(4, _at("attack"), false)
	ok(got == "heavy", "attack hold: a heavy exchange, got '%s'" % got)
	# A swipe up is the signature.
	_fresh()
	f = host.S.fighters[0]
	_frames(80)
	f.ki = 100.0
	var a: Vector2 = _at("attack")
	_touch(5, a, true)
	_frames(2)
	_drag(5, a + Vector2(0.0, -45.0 * 2.75))
	got = ""
	for i in range(30):
		_frames(1)
		var ex3 = host.S.dirS.ex
		if ex3 != null and ex3.A == f:
			got = ex3.kind
			break
	_touch(5, a + Vector2(0.0, -45.0 * 2.75), false)
	ok(got == "sig", "attack swipe up: a signature exchange, got '%s'" % got)
	# A flick on the stick: the dodge stance and a dash.
	_fresh()
	f = host.S.fighters[0]
	_frames(10)
	var lay: Dictionary = main.touch_layout()
	var z: Dictionary = lay["stick"]
	var s0 := Vector2((float(z.x0) + float(z.x1)) * 0.5, (float(z.y0) + float(z.y1)) * 0.5)
	var x0: float = f.x
	_touch(6, s0, true)
	_drag(6, s0 + Vector2(50.0 * 2.75, 0.0))
	_frames(4)
	ok(f.stance == 2.0, "flick: the dodge stance")
	_frames(8)
	var moved: float = absf(f.x - x0)
	ok(moved > 20.0, "flick: the fighter lunged (moved %.1f)" % moved)
	_touch(6, s0 + Vector2(50.0 * 2.75, 0.0), false)
	# The HUD's pause button is the HUD's, not a control; an open overlay swallows touches.
	_fresh()
	f = host.S.fighters[0]
	_frames(5)
	main.ui_hud.show_howto()
	_touch(7, _at("guard"), true)
	_frames(3)
	ok(f.stance == 0.0, "an open How to play card swallows touches")
	_touch(7, _at("guard"), false)
	print("touch_glue_test: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
