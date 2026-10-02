extends SceneTree
## Headless checks for the layout layer (sim/input/layout.gd) with the shipped presets (data/input/layouts.json): a
## keyboard (solo), a pad (Arena and Simple), the tap and hold rules, the power layer, the transform chord, the mode
## toggle and the persistence of an edge through a frozen tick. From the repo root:
##   godot --headless --path . --script res://sim/input/test/layout_test.gd
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
	ok(SimInputData.loaded and not SimInputData.presets.is_empty(), "data: the presets loaded from data/input")
	_data()
	_keyboard()
	_pad()
	_simple_pad()
	_hold_and_pause()
	print("layout_test: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _mk(id: String) -> SimLayout:
	return SimLayout.new(SimInputData.preset(id))


func _run(l: SimLayout, n: int) -> SimIntent:
	var i: SimIntent = null
	for k in range(n):
		i = l.build()
		l.consumed()   # a normal tick: the step took the input
	return i


func _data() -> void:
	# The built-in fallback equals the shipped file, so a tool without the data folder plays the same.
	for sect in SimInputData.DEFAULT_TIMING:
		if sect == "schema" or sect == "ticksPerSecond":
			continue
		var a = SimInputData.DEFAULT_TIMING[sect]
		var b = SimInputData.timing.get(sect, {})
		for k in a:
			ok(b.has(k) and is_equal_approx(float(a[k]), float(b[k])), "data: DEFAULT_TIMING.%s.%s equals timing.json" % [sect, k])
	ok(SimInputData.default_preset("pad") == "arena" and SimInputData.default_preset("kb") == "kb-solo" and SimInputData.default_preset("touch") == "touch-simple", "data: the default preset per device")
	SimInputData.load_and_apply()
	ok(SimAct.queueMax == 3 and SimAct.dodgeWindow == 12 and is_equal_approx(SimAct.awayDead, 0.3), "data: SimAct's statics set from the data")


func _keyboard() -> void:
	var l: SimLayout = _mk("kb-solo")
	ok(l.press("kb:KeyJ"), "kb: a bound key is used")
	ok(not l.press("kb:KeyZ"), "kb: an unbound key is not")
	var i: SimIntent = l.build()
	ok(i.light and not i.heavy and not i.sig, "kb: J is a light, on the tick it landed (no delay)")
	var again: SimIntent = l.build()
	ok(again.light, "kb: the edge stays until the step takes it (hit-stop must not eat a press)")
	l.consumed()
	ok(not l.build().light, "kb: spent after consumed()")
	l.release("kb:KeyJ")
	l.press("kb:KeyK")
	l.press("kb:KeyL")
	i = l.build()
	ok(i.heavy and i.sig, "kb: K is heavy and L the signature")
	l.consumed()
	l.release("kb:KeyK")
	l.release("kb:KeyL")
	# Guard: held, with its press edge for the perfect block.
	l.press("kb:Shift")
	i = l.build()
	ok(i.guard and i.guardPress and i.stance == -1.0, "kb: Shift is guard with its press edge on the first tick")
	l.consumed()
	i = l.build()
	ok(i.guard and not i.guardPress, "kb: held guard has no second edge")
	l.consumed()
	l.release("kb:Shift")
	ok(not l.build().guard, "kb: guard released")
	l.consumed()
	# Dodge: an edge and a free lunge on a tap, a sprint on a hold.
	l.press("kb:Space")
	i = l.build()
	ok(i.dodge and i.dash and not i.sprint, "kb: Space tap is the dodge edge and a lunge (today's dash)")
	l.consumed()
	l.release("kb:Space")
	i = _run(l, 11)
	ok(i.dash, "kb: the lunge lasts while its ticks run")
	i = _run(l, 3)
	ok(not i.dash and not i.sprint, "kb: and ends (12 ticks)")
	l.press("kb:Space")
	l.build()
	l.consumed()
	i = _run(l, 10)
	ok(not i.sprint, "kb: a hold is not a sprint before 12 ticks")
	i = _run(l, 3)
	ok(i.sprint and i.dash, "kb: held 12 ticks is a sprint (and today's dash)")
	l.release("kb:Space")
	_run(l, 2)
	# Power: press, tap on release, channel on a hold.
	l.press("kb:KeyE")
	i = l.build()
	ok(i.powerPress and i.power and not i.charge, "kb: E down is powerPress, held, not yet the channel")
	l.consumed()
	l.release("kb:KeyE")
	i = l.build()
	ok(i.powerTap and not i.power, "kb: a quick E is powerTap on release")
	l.consumed()
	l.press("kb:KeyE")
	i = _run(l, 13)
	ok(i.power and i.charge, "kb: E held 12 ticks is the channel (charge)")
	l.release("kb:KeyE")
	i = l.build()
	ok(not i.powerTap and not i.charge, "kb: a hold ends with no tap")
	l.consumed()
	# The power layer: a face press while E is down is a special, and no tap follows.
	l.press("kb:KeyE")
	_run(l, 3)
	l.press("kb:KeyJ")
	i = l.build()
	ok(i.special == 1 and not i.light, "kb: E held then J is special 1, with no light")
	l.consumed()
	l.release("kb:KeyJ")
	l.press("kb:KeyL")
	i = l.build()
	ok(i.sig and i.special == 0 and not i.light, "kb: E held then L is the signature")
	l.consumed()
	l.release("kb:KeyL")
	l.release("kb:KeyE")
	i = l.build()
	ok(not i.powerTap, "kb: releasing E after a layer press fires no tap")
	l.consumed()
	l.press("kb:KeyE")
	l.press("kb:KeyI")
	ok(l.build().special == 3, "kb: E held then I is special 3")
	l.consumed()
	l.release("kb:KeyI")
	l.release("kb:KeyE")
	l.build()
	l.consumed()
	# The chord: Space and E within 6 ticks, held 30 ticks.
	l.press("kb:Space")
	_run(l, 3)
	l.press("kb:KeyE")
	i = _run(l, 20)
	ok(not i.sprint and not i.charge and not i.transform, "chord: no sprint, charge or transform yet")
	i = _run(l, 8)
	ok(not i.transform, "chord: not at 29 ticks")
	var got: bool = false
	for k in range(5):
		i = l.build()
		l.consumed()
		got = got or i.transform
	ok(got, "chord: the transform edge at 30 ticks")
	i = _run(l, 40)
	ok(not i.transform and not i.sprint and not i.charge, "chord: once only, and still no sprint or charge")
	l.release("kb:KeyE")
	i = l.build()
	ok(not i.powerTap, "chord: releasing a chord fires no tap")
	l.consumed()
	l.release("kb:Space")
	_run(l, 2)
	# Two triggers more than 6 ticks apart are two actions: a sprint and a channel, no transform.
	l.press("kb:Space")
	_run(l, 8)
	l.press("kb:KeyE")
	i = _run(l, 40)
	ok(i.sprint and i.charge and not i.transform, "chord: 8 ticks apart is no chord: sprint and channel")
	l.release("kb:Space")
	l.release("kb:KeyE")
	_run(l, 2)
	# A single transform key (R) held 30 ticks.
	l.press("kb:KeyR")
	i = _run(l, 29)
	ok(not i.transform, "transform key: not before 30 ticks")
	i = l.build()
	ok(i.transform, "transform key: the edge at 30 ticks")
	l.consumed()
	l.release("kb:KeyR")
	l.press("kb:KeyR")
	_run(l, 10)
	l.release("kb:KeyR")
	ok(not _run(l, 40).transform, "transform key: an early release resets the count")
	# Move: WASD, and a diagonal reads (1, 1) as the keyboard always did.
	l.press("kb:KeyW")
	l.press("kb:KeyD")
	i = l.build()
	ok(i.mx == 1.0 and i.my == 1.0, "kb: W and D are a (1, 1) diagonal")
	l.consumed()
	l.release("kb:KeyW")
	l.release("kb:KeyD")
	l.press("kb:KeyA")
	l.press("kb:KeyS")
	i = l.build()
	ok(i.mx == -1.0 and i.my == -1.0, "kb: A and S are (-1, -1)")
	l.release("kb:KeyA")
	l.release("kb:KeyS")
	l.consumed()
	# Mode: a toggle with a cooldown, sent every tick.
	i = l.build()
	ok(i.mode == 0, "kb: the mode starts physical")
	l.set_mode_style("toggle")   # the accessibility setting: the old latch (the momentary default is in mode_test.gd)
	l.press("kb:KeyQ")
	i = l.build()
	ok(i.mode == 1, "kb: Q toggles to energy")
	l.consumed()
	l.release("kb:KeyQ")
	l.press("kb:KeyQ")
	i = l.build()
	ok(i.mode == 1, "kb: a second toggle inside the cooldown is ignored")
	l.consumed()
	l.release("kb:KeyQ")
	_run(l, 14)
	l.press("kb:KeyQ")
	ok(l.build().mode == 0, "kb: and works after it")
	l.consumed()
	# release_all lets everything go.
	l.press("kb:Shift")
	l.press("kb:KeyD")
	l.release_all()
	i = l.build()
	ok(not i.guard and i.mx == 0.0, "kb: release_all leaves nothing held")
	# An intent that goes through canon keeps every field.
	l.press("kb:Shift")
	l.press("kb:KeyD")
	var c: SimIntent = SimIntent.canon(l.build())
	ok(c != null and c.guard and c.guardPress and c.mx == 1.0, "kb: the intent survives canon (pack and unpack)")


func _pad() -> void:
	var l: SimLayout = _mk("arena")
	ok(l.press("pad:west"), "pad: a bound button is used")
	var i: SimIntent = l.build()
	ok(i.light, "pad: west is light")
	l.consumed()
	l.release("pad:west")
	l.press("pad:north")
	l.press("pad:east")
	i = l.build()
	ok(i.heavy and i.sig, "pad: north is heavy and east the signature")
	l.consumed()
	l.release("pad:north")
	l.release("pad:east")
	l.press("pad:south")
	ok(l.build().context, "pad: south is context")
	l.consumed()
	l.release("pad:south")
	# Analog triggers with hysteresis: LT is the dodge.
	l.analog("pad:lt", 0.2)
	ok(not l.build().dodge, "pad: a light pull below 0.35 is nothing")
	l.consumed()
	l.analog("pad:lt", 0.5)
	i = l.build()
	ok(i.dodge and i.dash, "pad: LT past 0.35 is the dodge and a lunge")
	l.consumed()
	l.analog("pad:lt", 0.3)
	i = _run(l, 9)
	ok(not i.sprint, "pad: still held at 0.3 (hysteresis), not yet a sprint")
	i = _run(l, 4)
	ok(i.sprint, "pad: held past 12 ticks is a sprint")
	l.analog("pad:lt", 0.1)
	i = l.build()
	ok(not i.sprint, "pad: released under 0.25")
	l.consumed()
	# The stick: dead zone, per-axis gate, quantised.
	l.axis("pad:ls", 0.1, 0.1)
	i = l.build()
	ok(i.mx == 0.0 and i.my == 0.0, "pad: inside the dead zone is nothing")
	l.axis("pad:ls", 1.0, -1.0)
	i = l.build()
	ok(i.mx == 1.0 and i.my == -1.0, "pad: full travel reads (1, -1), the square gate the keyboard matches")
	l.axis("pad:ls", 0.55, 0.0)
	i = l.build()
	ok(i.mx > 0.3 and i.mx < 0.8 and is_equal_approx(i.mx * 16.0, roundf(i.mx * 16.0)) and i.my == 0.0, "pad: a partial push is quantised to 1/16")
	l.axis("pad:ls", 0.0, 0.0)
	l.consumed()
	# Chords: LT and RT within 6 ticks held 30, and L3 and R3.
	l.analog("pad:lt", 0.9)
	_run(l, 2)
	l.analog("pad:rt", 0.9)
	i = _run(l, 20)
	ok(not i.sprint and not i.charge and not i.transform, "pad chord: nothing from the two triggers yet")
	var got: bool = false
	for k in range(15):
		i = l.build()
		l.consumed()
		got = got or i.transform
	ok(got, "pad chord: LT and RT held 30 ticks send transform")
	l.analog("pad:lt", 0.0)
	l.analog("pad:rt", 0.0)
	_run(l, 2)
	l.press("pad:l3")
	l.press("pad:r3")
	got = false
	var esc: bool = false
	for k in range(33):
		i = l.build()
		l.consumed()
		got = got or i.transform
		esc = esc or i.escape
	ok(not got, "pad: L3 and R3 are no longer a transform (R3 is Escape)")
	ok(esc, "pad: R3 is the Escape edge")
	l.release("pad:l3")
	l.release("pad:r3")
	_run(l, 2)
	# RT: a tap, a hold, and the layer.
	l.analog("pad:rt", 0.9)
	_run(l, 4)
	l.analog("pad:rt", 0.0)
	ok(l.build().powerTap, "pad: an RT tap is powerTap")
	l.consumed()
	l.analog("pad:rt", 0.9)
	i = _run(l, 14)
	ok(i.charge and i.power, "pad: RT held is the channel")
	l.analog("pad:rt", 0.0)
	_run(l, 2)
	l.analog("pad:rt", 0.9)
	_run(l, 2)
	l.press("pad:west")
	i = l.build()
	ok(i.special == 1 and not i.light, "pad: RT held then X is special 1")
	l.consumed()
	l.release("pad:west")
	l.press("pad:east")
	ok(l.build().sig, "pad: RT held then B is the signature")
	l.consumed()
	l.release("pad:east")
	l.analog("pad:rt", 0.0)
	_run(l, 2)
	# Every preset loads and indexes without error.
	for id in SimInputData.presets:
		var p: Dictionary = SimInputData.presets[id]
		var lay := SimLayout.new(p)
		var n: int = 0
		for b in p["bindings"]:
			for c in b["controls"]:
				if lay.has_control(c) or b["action"] in ["pause", "hints"]:
					n += 1
		ok(n > 0, "preset %s indexes its controls" % id)


func _simple_pad() -> void:
	var l: SimLayout = _mk("simple-pad")
	ok(l.slot_flags.get("autoBurst", false) and l.slot_flags.get("specialPick", "") == "auto", "simple: the slot flags come from the preset")
	l.press("pad:west")
	var i: SimIntent = _run(l, 3)
	ok(not i.light and not i.heavy, "simple: X down is neither yet")
	l.release("pad:west")
	i = l.build()
	ok(i.light and not i.heavy, "simple: X tapped is a light on release (the bridge)")
	l.consumed()
	_run(l, 3)   # past the 2-tick contact debounce: a re-press is a new press
	l.press("pad:west")
	i = _run(l, 11)
	ok(not i.heavy, "simple: no heavy before 12 ticks")
	i = l.build()
	ok(i.heavy and not i.light, "simple: X held is a heavy at 12 ticks")
	l.consumed()
	l.release("pad:west")
	i = l.build()
	ok(not i.light, "simple: no light after the heavy")
	l.consumed()
	l.press("pad:north")
	ok(l.build().sig, "simple: Y is the signature")
	l.consumed()
	l.release("pad:north")
	l.press("pad:east")
	ok(l.build().guard, "simple: B is guard")
	l.release("pad:east")
	l.consumed()
	l.analog("pad:rt", 0.9)
	_run(l, 2)
	l.press("pad:west")
	i = l.build()
	ok(i.special == 7 and not i.light, "simple: RT held then X is special 7, the director's pick")
	l.consumed()
	l.release("pad:west")
	ok(not l.build().light, "simple: and no light on release")
	l.consumed()
	l.analog("pad:rt", 0.0)
	_run(l, 2)
	ok(l.build().mode == -1, "simple: the mode is the director's (-1)")
	l.consumed()
	l.press("pad:rb")
	var got: bool = false
	for k in range(33):
		i = l.build()
		l.consumed()
		got = got or i.transform
	ok(got, "simple: RB held 30 ticks is the transform")


func _hold_and_pause() -> void:
	var l: SimLayout = _mk("kb-solo")
	ok(l.transform_hold() == 0.0, "hold: no progress when nothing is held")
	l.press("kb:KeyR")
	_run(l, 15)
	ok(absf(l.transform_hold() - 0.5) < 0.04, "hold: the transform key is half way at 15 of 30 ticks")
	_run(l, 20)
	ok(l.transform_hold() == 1.0, "hold: full at 30")
	l.release("kb:KeyR")
	ok(l.transform_hold() == 0.0, "hold: back to 0 on release")
	# The chord's progress.
	l.press("kb:Space")
	l.press("kb:KeyE")
	_run(l, 9)
	ok(absf(l.transform_hold() - 0.3) < 0.04, "hold: the chord counts from when both are down")
	l.release("kb:Space")
	l.release("kb:KeyE")
	_run(l, 2)
	# A pause: presses made meanwhile are dropped, and a hold is read again from the end of it.
	l.press("kb:KeyJ")
	l.drop_edges()
	ok(not l.build().light, "pause: a press made during a pause is dropped")
	l.consumed()
	l.release("kb:KeyJ")
	l.press("kb:Space")
	_run(l, 11)
	l.resume()
	ok(not _run(l, 5).sprint, "pause: a held dodge counts again from the end of the pause (no sprint yet)")
	ok(_run(l, 8).sprint, "pause: and is a sprint 12 ticks after it")
	l.release("kb:Space")
	_run(l, 2)
	l.press("kb:KeyR")
	_run(l, 25)
	l.resume()
	var got: bool = false
	for k in range(10):
		var i: SimIntent = l.build()
		l.consumed()
		got = got or i.transform
	ok(not got, "pause: the transform count restarted, so 10 ticks after it is not 30")
	for k in range(25):
		var i2: SimIntent = l.build()
		l.consumed()
		got = got or i2.transform
	ok(got, "pause: and it completes 30 ticks after the pause ended")
