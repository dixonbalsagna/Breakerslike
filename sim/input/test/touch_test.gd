extends SceneTree
## Headless checks for SimTouch (sim/input/touch.gd), the touch Simple bridge. From the repo root:
##   godot --headless --path . --script res://sim/input/test/touch_test.gd
## Exit 0 if every check passes. It also proves determinism: a match whose human slot is driven by a scripted touch
## session replays to the same state hash, and the session leaves the AI-only hash untouched.

var fails: int = 0
var checks: int = 0


func ok(c: bool, what: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL  ", what)


func _init() -> void:
	var dp: float = 2.75
	_taps_and_holds(dp)
	_guard_power(dp)
	_stick(dp)
	_display(dp)
	_layout()
	_determinism()
	print("touch_test: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _mk(dp: float) -> SimTouch:
	var t := SimTouch.new()
	t.dp = dp
	return t


func _run(t: SimTouch, n: int) -> SimIntent:
	var last: SimIntent = null
	for k in range(n):
		last = t.build()
	return last


func _taps_and_holds(dp: float) -> void:
	# A tap: released before holdTicks is one light, held until consumed.
	var t := _mk(dp)
	t.touch_down(1, 700.0, 300.0, "attack")
	_run(t, 3)
	t.touch_up(1)
	var i: SimIntent = t.build()
	ok(i.light and not i.heavy and not i.sig, "tap: one light on release")
	i = t.build()
	ok(i.light, "tap: the light stays until consumed (hit-stop must not eat it)")
	t.consumed()
	i = t.build()
	ok(not i.light, "tap: spent after consumed()")
	# A tap at the last tick before the threshold is still a light.
	t = _mk(dp)
	t.touch_down(1, 700.0, 300.0, "attack")
	_run(t, 11)
	t.touch_up(1)
	ok(t.build().light, "tap: 11 ticks is still a tap")
	# A hold: heavy at holdTicks, no light on release.
	t = _mk(dp)
	t.touch_down(1, 700.0, 300.0, "attack")
	i = _run(t, 11)
	ok(not i.heavy, "hold: no heavy before 12 ticks")
	i = t.build()
	ok(i.heavy and not i.light, "hold: heavy at 12 ticks")
	t.consumed()
	t.touch_up(1)
	i = t.build()
	ok(not i.light and not i.heavy, "hold: nothing more on release")
	# A swipe up: the signature at once, no light or heavy.
	t = _mk(dp)
	t.touch_down(1, 700.0, 300.0, "attack")
	_run(t, 4)
	t.touch_move(1, 702.0, 300.0 - 39.0 * dp)
	ok(not t.build().sig, "swipe: 39 dp is not enough")
	t.touch_move(1, 702.0, 300.0 - 41.0 * dp)
	i = t.build()
	ok(i.sig and not i.light and not i.heavy, "swipe: 41 dp up within the hold time is the signature")
	t.consumed()
	_run(t, 20)
	t.touch_up(1)
	i = t.build()
	ok(not i.light and not i.heavy and not i.sig, "swipe: no light, heavy or second signature after")
	# A slow swipe is a hold: the heavy has fired, the swipe adds nothing.
	t = _mk(dp)
	t.touch_down(1, 700.0, 300.0, "attack")
	_run(t, 13)
	t.touch_move(1, 700.0, 300.0 - 80.0 * dp)
	i = t.build()
	ok(i.heavy and not i.sig, "swipe: after the hold time it is a heavy, not a signature")
	# One finger per button.
	t = _mk(dp)
	t.touch_down(1, 700.0, 300.0, "attack")
	t.touch_down(2, 705.0, 305.0, "attack")
	t.touch_up(2)
	ok(not t.build().light, "one finger per button: the second finger is ignored")


func _guard_power(dp: float) -> void:
	var t := _mk(dp)
	t.touch_down(1, 600.0, 300.0, "guard")
	var i: SimIntent = t.build()
	ok(i.stance == 1.0, "guard: DEFENSIVE while the finger is down, on the first tick")
	t.touch_up(1)
	ok(t.build().stance == 0.0, "guard: back to AGGRESSIVE on release")
	t.touch_down(2, 500.0, 300.0, "power")
	i = t.build()
	ok(i.charge, "power: charge while held")
	t.touch_up(2)
	ok(not t.build().charge, "power: charge stops on release")
	# Guard wins over a dodge stance.
	t.touch_down(3, 100.0, 600.0, "stick")
	t.touch_move(3, 100.0 + 45.0 * dp, 600.0)
	t.touch_down(4, 600.0, 300.0, "guard")
	ok(t.build().stance == 1.0, "guard: guard outranks the dodge stance")
	t.release_all()
	i = t.build()
	ok(i.stance == 0.0 and not i.charge and i.mx == 0.0, "release_all: nothing stuck")


func _stick(dp: float) -> void:
	var t := _mk(dp)
	t.touch_down(1, 200.0, 700.0, "stick")
	# Inside the dead zone: no motion.
	t.touch_move(1, 200.0 + 8.0 * dp, 700.0)
	var i: SimIntent = _run(t, 2)
	ok(i.mx == 0.0 and i.my == 0.0, "stick: dead zone")
	# Slow drag: quantised in sixteenths, up is positive my.
	t.touch_move(1, 200.0, 700.0 - 30.0 * dp)
	i = _run(t, 8)
	ok(is_equal_approx(i.my * 16.0, roundf(i.my * 16.0)) and i.my > 0.0 and i.my < 1.0, "stick: quantised 1/16, up is positive, partial at 30 dp")
	ok(i.dash == false and i.stance == 0.0, "stick: a slow drag is not a flick or a sprint")
	t.touch_up(1)
	# A flick to the right: EVASIVE for 30 ticks, a dash for 12 in the flick direction, then released.
	t.touch_down(2, 200.0, 700.0, "stick")
	t.touch_move(2, 200.0 + 44.0 * dp, 700.0 - 4.0 * dp)
	i = t.build()
	ok(i.stance == 2.0 and i.dash and i.mx == 1.0 and i.my == 0.0, "flick: dodge stance, dash, direction snapped to the right")
	t.touch_move(2, 200.0, 700.0)   # the thumb comes back
	i = _run(t, 10)
	ok(i.dash and i.mx == 1.0, "flick: the dash holds its direction for 12 ticks even if the thumb returns")
	i = _run(t, 3)
	ok(not i.dash and i.stance == 2.0 and i.mx == 0.0, "flick: the dash is over, the dodge stance lasts")
	i = _run(t, 20)
	ok(i.stance == 0.0, "flick: back to AGGRESSIVE after 30 ticks")
	t.touch_up(2)
	# A drag that takes too long is not a flick.
	t.touch_down(3, 200.0, 700.0, "stick")
	_run(t, 8)
	t.touch_move(3, 200.0 + 50.0 * dp, 700.0)
	i = t.build()
	ok(i.stance == 0.0 and not i.dash, "flick: slower than 6 ticks is a walk")
	t.touch_up(3)
	# Up-left flick snaps to both axes.
	t.touch_down(4, 200.0, 700.0, "stick")
	t.touch_move(4, 200.0 - 30.0 * dp, 700.0 - 30.0 * dp)
	i = t.build()
	ok(i.mx == -1.0 and i.my == 1.0, "flick: eight-way snap, up and left")
	t.release_all()
	# Sprint: beyond 1.3 radii for 6 ticks, ends inside 1.15.
	t.touch_down(5, 200.0, 700.0, "stick")
	_run(t, 8)   # past the flick window
	t.touch_move(5, 200.0 + 80.0 * dp, 700.0)   # 80 dp > 1.3 * 56
	i = _run(t, 5)
	ok(not i.dash, "sprint: not before 6 ticks beyond the ring")
	i = _run(t, 2)
	ok(i.dash, "sprint: dash while beyond the outer ring")
	t.touch_move(5, 200.0 + 70.0 * dp, 700.0)   # 70 dp: inside 1.3 (72.8) but outside 1.15 (64.4): hysteresis keeps it
	i = _run(t, 2)
	ok(i.dash, "sprint: hysteresis holds it between 1.15 and 1.3 radii")
	t.touch_move(5, 200.0 + 60.0 * dp, 700.0)
	i = _run(t, 2)
	ok(not i.dash, "sprint: ends inside 1.15 radii")


func _display(dp: float) -> void:
	var t := _mk(dp)
	var d: Dictionary = t.display_state()
	ok(not d.attack.down and not d.guard.down and not d.power.down and not d.stick.active and not d.transform.down, "display: everything idle at rest")
	t.touch_down(1, 700.0, 300.0, "attack")
	_run(t, 6)
	d = t.display_state()
	ok(d.attack.down and absf(d.attack.hold - 0.5) < 0.01, "display: attack hold progress is half at 6 of 12 ticks")
	_run(t, 8)
	ok(t.display_state().attack.hold == 1.0, "display: attack hold is full once it is a heavy")
	t.touch_up(1)
	t.touch_down(2, 600.0, 300.0, "guard")
	t.touch_down(3, 500.0, 300.0, "power")
	t.touch_down(4, 400.0, 300.0, "context")
	t.touch_down(5, 200.0, 700.0, "stick")
	t.touch_move(5, 230.0, 690.0)
	d = t.display_state()
	ok(d.guard.down and d.power.down and d.transform.down, "display: guard, power and the transform slot report down")
	ok(d.stick.active and d.stick.base == Vector2(200.0, 700.0) and d.stick.thumb == Vector2(230.0, 690.0), "display: the stick reports its base and thumb")
	t.release_all()
	d = t.display_state()
	ok(not d.guard.down and not d.stick.active, "display: idle again after release_all")


func _layout() -> void:
	for cfgv in [[844.0 * 2.75, 390.0 * 2.75, 2.75, false, false], [844.0 * 2.75, 390.0 * 2.75, 2.75, false, true],
			[360.0 * 3.0, 800.0 * 3.0, 3.0, true, false], [1280.0, 800.0, 1.5, false, false], [2360.0, 1640.0, 2.0, false, false]]:
		var vw: float = cfgv[0]
		var vh: float = cfgv[1]
		var dpv: float = cfgv[2]
		var port: bool = cfgv[3]
		var lh: bool = cfgv[4]
		var lay: Dictionary = SimTouch.layout(vw, vh, dpv, port, lh)
		var tag: String = "%dx%d %s%s" % [int(vw), int(vh), "portrait" if port else "landscape", " left-handed" if lh else ""]
		var names: Array = ["attack", "guard", "power", "context"]
		for a in range(names.size()):
			var c: Dictionary = lay[names[a]]
			ok(float(c.x) - float(c.r) >= 0.0 and float(c.x) + float(c.r) <= vw and float(c.y) - float(c.r) >= 0.0 and float(c.y) + float(c.r) <= vh, "layout %s: %s is on screen" % [tag, names[a]])
			ok(float(c.r) >= 24.0 * dpv - 0.01, "layout %s: %s visual radius at least 24 dp (a 48 dp target)" % [tag, names[a]])
			for b in range(a + 1, names.size()):
				var d: Dictionary = lay[names[b]]
				var dist: float = sqrt((float(c.x) - float(d.x)) * (float(c.x) - float(d.x)) + (float(c.y) - float(d.y)) * (float(c.y) - float(d.y)))
				ok(dist >= float(c.r) + float(d.r) + 4.0 * dpv, "layout %s: %s and %s do not touch" % [tag, names[a], names[b]])
			# No button sits in the stick zone.
			var z: Dictionary = lay["stick"]
			ok(float(c.x) - float(c.r) >= float(z.x1) or float(c.x) + float(c.r) <= float(z.x0), "layout %s: %s is outside the stick zone" % [tag, names[a]])
		# Hit tests agree with the layout.
		var t := SimTouch.new()
		t.dp = dpv
		for n in names:
			var c2: Dictionary = lay[n]
			ok(t.widget_at(float(c2.x), float(c2.y), lay) == n, "layout %s: the centre of %s hits %s" % [tag, n, n])
		var z2: Dictionary = lay["stick"]
		ok(t.widget_at((float(z2.x0) + float(z2.x1)) * 0.5, float(z2.y1) - 10.0, lay) == "stick" or lh, "layout %s: the stick zone hits stick" % tag)
		ok(t.widget_at(vw * 0.5, 4.0, lay) == "", "layout %s: the top of the screen hits nothing" % tag)


## A match with a human slot driven by a scripted touch session, twice with the same seed: the same state hash.
func _session(seed_: int, with_touch: bool) -> String:
	var S: SimState = SimCore.createSim()
	SimCore.newMatch(S, seed_, {"p1": not with_touch, "p2": true})
	var t := SimTouch.new()
	t.dp = 2.75
	for n in range(900):
		var inputs: Array = [null, null]
		if with_touch:
			# The script: guard, flick, tap, hold, swipe, power, in a repeating 150-tick cycle.
			var c: int = n % 150
			if c == 0:
				t.touch_down(1, 600.0, 300.0, "guard")
			elif c == 20:
				t.touch_up(1)
			elif c == 30:
				t.touch_down(2, 200.0, 700.0, "stick")
				t.touch_move(2, 200.0 + 50.0 * 2.75, 700.0)
			elif c == 50:
				t.touch_up(2)
			elif c == 60:
				t.touch_down(3, 700.0, 300.0, "attack")
			elif c == 63:
				t.touch_up(3)
			elif c == 80:
				t.touch_down(4, 700.0, 300.0, "attack")
			elif c == 100:
				t.touch_up(4)
			elif c == 105:
				t.touch_down(5, 700.0, 300.0, "attack")
				t.touch_move(5, 700.0, 300.0 - 50.0 * 2.75)
			elif c == 108:
				t.touch_up(5)
			elif c == 120:
				t.touch_down(6, 500.0, 300.0, "power")
			elif c == 140:
				t.touch_up(6)
			inputs[0] = t.build()
		if SimCore.step(S, inputs):
			t.consumed()
	var h: String = str(SimHash.stateHash(S).gameplay)
	SimCore.dispose(S)
	return h


func _determinism() -> void:
	var a: String = _session(7, true)
	var b: String = _session(7, true)
	ok(a == b, "determinism: a scripted touch session replays to the same hash")
	var c: String = _session(7, false)
	var d: String = _session(7, false)
	ok(c == d, "determinism: the AI-only match is unchanged by SimTouch existing")
	ok(a != c, "sanity: the touch session actually changed the match")
