extends SceneTree
## Headless checks for the Full touch preset (touch-full, for tablets): the layout on screens, the hit tests, every
## button through the SimLayout, the stick's flick and sprint, several fingers at once, the display state and the hub's
## switch between Simple and Full. From the repo root:
##   godot --headless --path . --script res://sim/input/test/touch_full_test.gd
## Exit 0 if every check passes.

var fails: int = 0
var checks: int = 0


func ok(c: bool, what: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL  ", what)


func _init() -> void:
	SimInputData.load_data()
	_layout()
	_buttons()
	_stick()
	_fingers()
	_hub()
	print("touch_full_test: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _mk() -> SimTouch:
	var t := SimTouch.new()
	t.dp = 2.75
	t.set_preset("touch-full")
	return t


func _run(t: SimTouch, n: int) -> SimIntent:
	var i: SimIntent = null
	for k in range(n):
		i = t.build()
		t.consumed()
	return i


func _at(lay: Dictionary, name: String) -> Vector2:
	return Vector2(float(lay[name].x), float(lay[name].y))


func _layout() -> void:
	var names: Array = ["light", "heavy", "signature", "context", "power", "mode", "transform", "dodge", "guard"]
	for cfgv in [[844.0 * 2.75, 390.0 * 2.75, 2.75, false, false], [844.0 * 2.75, 390.0 * 2.75, 2.75, false, true],
			[1280.0 * 1.5, 800.0 * 1.5, 1.5, false, false], [2360.0, 1640.0, 2.0, false, false], [2360.0, 1640.0, 2.0, false, true],
			[360.0 * 3.0, 800.0 * 3.0, 3.0, true, false], [810.0 * 2.0, 1080.0 * 2.0, 2.0, true, false]]:
		var vw: float = cfgv[0]
		var vh: float = cfgv[1]
		var dpv: float = cfgv[2]
		var port: bool = cfgv[3]
		var lh: bool = cfgv[4]
		var lay: Dictionary = SimTouch.layout(vw, vh, dpv, port, lh, 8.0, true)
		var tag: String = "%dx%d %s%s" % [int(vw), int(vh), "portrait" if port else "landscape", " left-handed" if lh else ""]
		ok(lay.has("stick"), "full %s: the stick zone is there" % tag)
		for n in names:
			ok(lay.has(n), "full %s: %s exists" % [tag, n])
		for a in range(names.size()):
			var c: Dictionary = lay[names[a]]
			ok(float(c.x) - float(c.r) >= 0.0 and float(c.x) + float(c.r) <= vw and float(c.y) - float(c.r) >= 0.0 and float(c.y) + float(c.r) <= vh, "full %s: %s is on screen" % [tag, names[a]])
			ok(float(c.r) >= 24.0 * dpv - 0.01, "full %s: %s is a 48 dp target" % [tag, names[a]])
			for b in range(a + 1, names.size()):
				var d: Dictionary = lay[names[b]]
				var dist: float = sqrt((float(c.x) - float(d.x)) * (float(c.x) - float(d.x)) + (float(c.y) - float(d.y)) * (float(c.y) - float(d.y)))
				ok(dist >= float(c.r) + float(d.r) + 2.0 * dpv, "full %s: %s and %s do not touch" % [tag, names[a], names[b]])
		var t := SimTouch.new()
		t.dp = dpv
		t.set_preset("touch-full")
		for n in names:
			ok(t.widget_at(float(lay[n].x), float(lay[n].y), lay) == n, "full %s: the centre of %s hits %s" % [tag, n, n])
		ok(t.widget_at(vw * 0.5, 4.0, lay) == "", "full %s: the top of the screen hits nothing" % tag)
	# Simple's layout is untouched by the new parameter.
	var simple: Dictionary = SimTouch.layout(2321.0, 1072.0, 2.75, false)
	ok(simple.has("attack") and not simple.has("light"), "the default layout is still Simple's")


func _buttons() -> void:
	var t := _mk()
	t.touch_down(1, 0.0, 0.0, "light")
	var i: SimIntent = t.build()
	ok(i.light and not i.heavy, "full: Light is a light on the tick it lands (no wait, no gesture)")
	t.consumed()
	t.touch_up(1)
	t.touch_down(2, 0.0, 0.0, "heavy")
	t.touch_down(3, 0.0, 0.0, "signature")
	i = t.build()
	ok(i.heavy and i.sig, "full: Heavy and Signature")
	t.consumed()
	t.touch_up(2)
	t.touch_up(3)
	t.touch_down(4, 0.0, 0.0, "context")
	ok(t.build().context, "full: Context")
	t.consumed()
	t.touch_up(4)
	# Guard: held, with its press edge.
	t.touch_down(5, 0.0, 0.0, "guard")
	i = t.build()
	ok(i.guard and i.guardPress, "full: Guard is held, with its press edge")
	t.consumed()
	t.touch_up(5)
	ok(not t.build().guard, "full: and lets go")
	t.consumed()
	# Dodge: tap is a dodge and a lunge; held 12 ticks is a sprint.
	t.touch_down(6, 0.0, 0.0, "dodge")
	i = t.build()
	ok(i.dodge and i.dash and not i.sprint, "full: Dodge tap is the dodge edge and a lunge")
	t.consumed()
	i = _run(t, 13)
	ok(i.sprint, "full: Dodge held 12 ticks is a sprint")
	t.touch_up(6)
	_run(t, 2)
	# Power: press, tap, channel, and the layer.
	t.touch_down(7, 0.0, 0.0, "power")
	i = t.build()
	ok(i.powerPress and i.power and not i.charge, "full: Power down is powerPress, not yet the channel")
	t.consumed()
	i = _run(t, 13)
	ok(i.charge, "full: Power held 12 ticks is the channel")
	t.touch_up(7)
	i = t.build()
	ok(not i.powerTap, "full: a hold has no tap")
	t.consumed()
	t.touch_down(8, 0.0, 0.0, "power")
	_run(t, 4)
	t.touch_up(8)
	ok(t.build().powerTap, "full: a quick Power is powerTap")
	t.consumed()
	t.touch_down(9, 0.0, 0.0, "power")
	_run(t, 2)
	t.touch_down(10, 0.0, 0.0, "light")
	i = t.build()
	ok(i.special == 1 and not i.light, "full: Power held then Light is special 1 (west)")
	t.consumed()
	t.touch_up(10)
	t.touch_down(11, 0.0, 0.0, "heavy")
	ok(t.build().special == 2, "full: then Heavy is special 2 (north)")
	t.consumed()
	t.touch_up(11)
	t.touch_down(12, 0.0, 0.0, "context")
	ok(t.build().special == 3, "full: then Context is special 3 (south)")
	t.consumed()
	t.touch_up(12)
	t.touch_down(13, 0.0, 0.0, "signature")
	i = t.build()
	ok(i.sig and i.special == 0, "full: then Signature is the signature (east)")
	t.consumed()
	t.touch_up(13)
	t.touch_up(9)
	ok(not t.build().powerTap, "full: letting go of Power after a layer press fires no tap")
	t.consumed()
	# Mode: a toggle, with a cooldown.
	_run(t, 14)
	ok(t.build().mode == 0, "full: the mode starts physical")
	t.touch_down(14, 0.0, 0.0, "mode")
	ok(t.build().mode == 1, "full: the Mode button toggles to energy")
	t.consumed()
	t.touch_up(14)
	# Transform: the button held 30 ticks.
	t.touch_down(15, 0.0, 0.0, "transform")
	var i2: SimIntent = _run(t, 15)
	ok(absf(t.transform_hold() - 0.5) < 0.04 and not i2.transform, "full: the Transform button is half way at 15 ticks")
	var got: bool = false
	for k in range(16):
		i2 = t.build()
		t.consumed()
		got = got or i2.transform
	ok(got, "full: the Transform edge at 30 ticks")
	t.touch_up(15)
	ok(t.transform_hold() == 0.0, "full: the ring resets")
	# The display state names every held widget.
	t.touch_down(16, 0.0, 0.0, "light")
	t.touch_down(17, 0.0, 0.0, "guard")
	var d: Dictionary = t.display_state()
	ok(d.has("full") and d["full"].has("light") and d["full"].has("guard") and d.guard.down, "full: display_state lists the held widgets")
	t.release_all()
	d = t.display_state()
	ok(d["full"].is_empty() and not d.guard.down, "full: and is empty after release_all")


func _stick() -> void:
	var t := _mk()
	t.touch_down(1, 200.0, 700.0, "stick")
	t.touch_move(1, 200.0, 700.0 - 30.0 * 2.75)
	var i: SimIntent = _run(t, 8)
	ok(i.my > 0.0 and i.my < 1.0 and is_equal_approx(i.my * 16.0, roundf(i.my * 16.0)) and i.mx == 0.0, "full stick: a partial push, quantised, up is positive")
	t.touch_up(1)
	t.consumed()
	# A flick is the dodge edge and a dash in the flick direction.
	t.touch_down(2, 200.0, 700.0, "stick")
	t.touch_move(2, 200.0 + 44.0 * 2.75, 700.0)
	i = t.build()
	ok(i.dodge and i.dash and i.mx == 1.0, "full stick: a flick is the dodge edge and a dash to the right")
	t.consumed()
	t.touch_move(2, 200.0, 700.0)
	i = _run(t, 8)
	ok(i.dash and i.mx == 1.0, "full stick: the dash holds its direction")
	t.touch_up(2)
	_run(t, 12)
	# A sprint from the outer ring.
	t.touch_down(3, 200.0, 700.0, "stick")
	_run(t, 8)
	t.touch_move(3, 200.0 + 80.0 * 2.75, 700.0)
	i = _run(t, 8)
	ok(i.sprint and i.dash, "full stick: the outer ring is a sprint")
	t.touch_up(3)
	i = _run(t, 2)
	ok(not i.sprint, "full stick: and ends on release")


func _fingers() -> void:
	# Five fingers at once: the stick, Guard, Light, Power and Dodge.
	var t := _mk()
	t.touch_down(1, 200.0, 700.0, "stick")
	t.touch_move(1, 200.0 + 40.0 * 2.75, 700.0)
	t.touch_down(2, 0.0, 0.0, "guard")
	t.touch_down(3, 0.0, 0.0, "light")
	t.touch_down(4, 0.0, 0.0, "power")
	t.touch_down(5, 0.0, 0.0, "dodge")
	var i: SimIntent = t.build()
	ok(i.mx > 0.0 and i.guard and i.dodge and i.powerPress, "fingers: five touches at once all register")
	t.consumed()
	t.release_all()
	i = t.build()
	ok(not i.guard and not i.power and i.mx == 0.0, "fingers: and nothing sticks after release_all")
	# One finger per button.
	t.touch_down(6, 0.0, 0.0, "guard")
	t.touch_down(7, 0.0, 0.0, "guard")
	t.touch_up(7)
	ok(t.build().guard, "fingers: a second finger on a held button does not let go of it")


func _hub() -> void:
	var hub := SimInputHub.new()
	hub.set_humans(true, false)
	ok(hub.touch_preset == "touch-simple" and not hub.touch.full_mode, "hub: touch starts on Simple")
	hub.set_touch_preset("touch-full")
	ok(hub.touch.full_mode and hub.touch_preset == "touch-full", "hub: set_touch_preset switches to Full")
	hub.touch_down(1, 0.0, 0.0, "light")
	ok(hub.intent(0).light and hub.device_of(0) == "touch", "hub: a Full button drives slot 0")
	hub.consumed()
	hub.touch_up(1)
	ok(hub.setup()["assists"][0].is_empty(), "hub: Full has no assists")
	hub.set_touch_preset("nonsense")
	ok(hub.touch_preset == "touch-full", "hub: an unknown preset is ignored")
	hub.set_touch_preset("touch-simple")
	ok(not hub.touch.full_mode, "hub: and back to Simple")
	hub.touch_down(2, 0.0, 0.0, "guard")
	hub.set_touch_preset("touch-full")
	ok(not hub.intent(0).guard, "hub: switching the preset lets everything go")
	# Pause handling reaches the Full layout.
	hub.touch_down(3, 0.0, 0.0, "light")
	hub.drop_edges()
	ok(not hub.intent(0).light, "hub: a press made during a pause is dropped in Full too")
	hub.consumed()
	hub.touch_up(3)
	hub.touch_down(4, 0.0, 0.0, "transform")
	_run_hub(hub, 12)
	hub.resume()
	_run_hub(hub, 15)
	ok(hub.transform_hold(0) < 0.6, "hub: the transform ring restarts after a pause")
	# Through the real sim: Guard in Full is DEFENSIVE.
	hub = SimInputHub.new()
	hub.set_humans(true, false)
	hub.set_touch_preset("touch-full")
	var S: SimState = SimCore.createSim()
	SimCore.newMatch(S, 5, {"p1": false, "p2": true}, hub.setup())
	hub.touch_down(1, 0.0, 0.0, "guard")
	for k in range(4):
		hub.set_humans(S.fighters[0].ai == null, S.fighters[1].ai == null)
		if SimCore.step(S, [hub.intent(0), null]):
			hub.consumed()
	ok(S.fighters[0].stance == 1.0, "sim: a held Full Guard is DEFENSIVE")
	SimCore.dispose(S)


func _run_hub(hub: SimInputHub, n: int) -> void:
	for k in range(n):
		hub.intent(0)
		hub.consumed()
