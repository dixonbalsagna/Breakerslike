extends SceneTree
## Headless checks for the momentary energy mode and the attack debounce (docs/controls/agency-input.md 2 and 1a): hold
## RB (and the mode control of every other layout) for energy, the toggle as the accessibility setting, touch Full's hybrid,
## Simple's auto mode, the per-player style through the hub, and the 2-tick contact debounce. From the repo root:
##   godot --headless --path . --script res://sim/input/test/mode_test.gd
## Exit 0 if every check passes.

var fails: int = 0
var checks: int = 0


func ok(c: bool, what: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL  ", what)


func _init() -> void:
	SimInputData.load_and_apply()
	SimInputData.clear_overrides()
	_hold_every_layout()
	_same_tick()
	_toggle_setting()
	_hybrid()
	_simple()
	_hub()
	_debounce()
	print("mode_test: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _mk(id: String) -> SimLayout:
	return SimLayout.new(SimInputData.preset(id))


func _run(l: SimLayout, n: int) -> SimIntent:
	var i: SimIntent = null
	for k in range(n):
		i = l.build()
		l.consumed()
	return i


func _hold_every_layout() -> void:
	var cases: Array = [["arena", "pad:rb", "pad:west"], ["brawler", "pad:west", "pad:rb"], ["kb-solo", "kb:KeyQ", "kb:KeyJ"], ["kb-shared-p1", "kb:KeyE", "kb:KeyF"], ["kb-shared-p2", "kb:KeyO", "kb:KeyH"]]
	for c in cases:
		var l: SimLayout = _mk(c[0])
		ok(l.mode_style == "hold", "%s: momentary is the default" % c[0])
		ok(_run(l, 3).mode == 0, "%s: physical to start" % c[0])
		l.press(c[1])
		var i: SimIntent = _run(l, 5)
		ok(i.mode == 1, "%s: held is energy" % c[0])
		l.press(c[2])
		i = l.build()
		ok(i.mode == 1 and i.light, "%s: the attack pressed while held carries energy" % c[0])
		l.consumed()
		l.release(c[2])
		l.release(c[1])
		ok(_run(l, 1).mode == 0, "%s: released is physical again, no latch" % c[0])
		# A long hold, then release.
		l.press(c[1])
		ok(_run(l, 40).mode == 1, "%s: a long hold stays energy" % c[0])
		l.release(c[1])
		ok(_run(l, 1).mode == 0, "%s: and ends on release" % c[0])


## The modifier first and the face press on the same tick, and a modifier tapped shorter than a tick.
func _same_tick() -> void:
	var l: SimLayout = _mk("arena")
	l.press("pad:rb")
	l.press("pad:west")
	var i: SimIntent = l.build()
	ok(i.mode == 1 and i.light, "same tick: RB and X pressed together are an energy light")
	l.consumed()
	l.release("pad:rb")
	l.release("pad:west")
	# A modifier pressed and released between two ticks still counts for its tick.
	var l2: SimLayout = _mk("arena")
	l2.press("pad:rb")
	l2.press("pad:west")
	l2.release("pad:rb")
	l2.release("pad:west")
	i = l2.build()
	ok(i.mode == 1 and i.light, "same tick: a press shorter than a tick is stretched and still energy")
	l2.consumed()
	ok(l2.build().mode == 0, "same tick: and is physical on the next")


func _toggle_setting() -> void:
	var l: SimLayout = _mk("arena")
	l.set_mode_style("toggle")
	l.press("pad:rb")
	ok(l.build().mode == 1, "toggle: a press latches energy")
	l.consumed()
	l.release("pad:rb")
	ok(_run(l, 14).mode == 1, "toggle: and keeps it after the release")
	l.press("pad:rb")
	ok(l.build().mode == 0, "toggle: the next press puts it back")
	l.consumed()
	l.release("pad:rb")
	# Changing the style lets a latch go.
	l.press("pad:rb")
	_run(l, 14)
	l.release("pad:rb")
	l.set_mode_style("hold")
	ok(_run(l, 1).mode == 0, "toggle: switching to hold lets a latch go")


func _hybrid() -> void:
	SimInputData.ensure()
	var l: SimLayout = _mk("arena")
	l.set_mode_style("hybrid")
	l.press("pad:rb")
	ok(_run(l, 3).mode == 1, "hybrid: down is energy")
	l.release("pad:rb")
	ok(_run(l, 1).mode == 1, "hybrid: a quick tap latches")
	l.press("pad:rb")
	_run(l, 3)
	l.release("pad:rb")
	ok(_run(l, 1).mode == 0, "hybrid: a second tap unlatches")
	l.press("pad:rb")
	_run(l, 20)
	l.release("pad:rb")
	ok(_run(l, 1).mode == 0, "hybrid: a hold is momentary, back to physical on release")
	l.press("pad:rb")
	_run(l, 2)
	l.release("pad:rb")
	_run(l, 2)
	l.press("pad:rb")
	_run(l, 20)
	l.release("pad:rb")
	ok(_run(l, 1).mode == 1, "hybrid: a hold from a latched energy gives it back, still latched")
	# Touch Full is hybrid by default, and its Simple layout leaves the mode to the director.
	var t := SimTouch.new()
	t.set_preset("touch-full")
	ok(t.build().mode in [0, 1], "hybrid: touch Full sends a mode, not the director's")
	t.set_preset("touch-simple")
	ok(t.build().mode == -1, "hybrid: touch Simple leaves the mode to the director")


func _simple() -> void:
	var l: SimLayout = _mk("simple-pad")
	ok(_run(l, 3).mode == -1, "simple: auto mode, -1")
	l.set_mode_style("toggle")
	ok(_run(l, 3).mode == -1, "simple: the style does not touch the director's choice")


func _hub() -> void:
	var hub := SimInputHub.new()
	ok(hub.mode_style_of(0) == "hold" and hub.mode_style_of(1) == "hold", "hub: the default style is hold")
	hub.set_humans(true, true)
	hub.pad_button(3, "south", true)
	hub.pad_button(3, "south", false)
	hub.pad_button(9, "south", true)
	hub.pad_button(9, "south", false)
	hub.consumed()
	hub.set_mode_style("toggle", 1)
	ok(hub.mode_style_of(0) == "hold" and hub.mode_style_of(1) == "toggle", "hub: a style is per player")
	hub.pad_button(3, "rb", true)
	hub.pad_button(9, "rb", true)
	var a: SimIntent = hub.intent(0)
	var b: SimIntent = hub.intent(1)
	ok(a.mode == 1 and b.mode == 1, "hub: both pads read energy while RB is down")
	hub.consumed()
	hub.pad_button(3, "rb", false)
	hub.pad_button(9, "rb", false)
	for k in range(14):
		a = hub.intent(0)
		b = hub.intent(1)
		hub.consumed()
	ok(a.mode == 0 and b.mode == 1, "hub: player one's is momentary, player two's latched")
	hub.set_mode_style("", -1)
	ok(hub.mode_style_of(1) == "hold", "hub: an empty style is the data default")


## A worn button that chatters: a press within 2 ticks of its own release is the same press.
func _debounce() -> void:
	var l: SimLayout = _mk("arena")
	l.press("pad:west")
	var i: SimIntent = l.build()
	ok(i.light, "debounce: the first press is a light")
	l.consumed()
	l.release("pad:west")
	l.press("pad:west")                      # the bounce, the same tick
	i = l.build()
	ok(not i.light, "debounce: a re-press on the same tick as the release is the same press")
	l.consumed()
	l.release("pad:west")
	_run(l, 2)
	l.press("pad:west")                      # 2 ticks after
	i = l.build()
	ok(not i.light, "debounce: nor one 2 ticks after the release")
	l.consumed()
	l.release("pad:west")
	_run(l, 3)
	l.press("pad:west")                      # a real second press, 3 ticks after
	i = l.build()
	ok(i.light, "debounce: 3 ticks after the release is a new press")
	l.consumed()
	l.release("pad:west")
	# Only attack buttons: a dodge pressed twice quickly is two dodges.
	var d: SimLayout = _mk("arena")
	d.press("pad:lt")
	d.build()
	d.consumed()
	d.release("pad:lt")
	d.press("pad:lt")
	ok(d.build().dodge, "debounce: dodge is not debounced")
	# The power layer is never taken for a bounce: a layer press after a base press of the same button.
	var p: SimLayout = _mk("arena")
	p.press("pad:west")
	p.build()
	p.consumed()
	p.release("pad:west")
	p.press("pad:rt")
	p.press("pad:west")
	var pi: SimIntent = p.build()
	ok(pi.special == 1 and not pi.light, "debounce: a special on the same button right after a light is a special")
