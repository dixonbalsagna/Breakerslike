extends SceneTree
## Headless checks for the agency pass's input side (docs/controls/agency-input.md): the intent's three new fields (the
## attack levels and the Escape edge) and their packing, the Escape control on every layout (R3, a key, a swipe up on Guard),
## the Brawler's new transform control, and lightHeld and heavyHeld on pads, keyboards and touch. From the repo root:
##   godot --headless --path . --script res://sim/input/test/agency_input_test.gd
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
	_pack()
	_escape_controls()
	_brawler_transform()
	_levels()
	_touch(2.75)
	print("agency_input_test: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _mk(id: String) -> SimLayout:
	return SimLayout.new(SimInputData.preset(id))


func _run(l: SimLayout, n: int) -> SimIntent:
	var i: SimIntent = null
	for k in range(n):
		i = l.build()
		l.consumed()
	return i


func _pack() -> void:
	ok(SimIntent.BITS == 43, "pack: the record is 43 bits")
	for f in ["lightHeld", "heavyHeld", "escape"]:
		var i := SimIntent.new()
		i.set(f, true)
		var u: SimIntent = SimIntent.unpack(SimIntent.pack(i))
		ok(u != null and u.get(f) == true, "pack: %s round-trips" % f)
		var others: bool = false
		for g in ["lightHeld", "heavyHeld", "escape", "light", "heavy", "guard"]:
			if g != f and u.get(g):
				others = true
		ok(not others, "pack: %s sets no other field" % f)
	var all := SimIntent.new()
	all.lightHeld = true
	all.heavyHeld = true
	all.escape = true
	all.mx = 1.0
	all.mode = 1
	var ua: SimIntent = SimIntent.canon(all)
	ok(ua.lightHeld and ua.heavyHeld and ua.escape and ua.mx == 1.0 and ua.mode == 1, "pack: canon keeps the new fields with the old")
	# An older packed intent (bits 0 to 39) is still valid and has the new fields off.
	var old := SimIntent.new()
	old.light = true
	old.guard = true
	var packed: int = SimIntent.pack(old)
	ok(packed < (1 << 40), "pack: an intent without the new fields uses no new bit, so older replays unpack as they were")
	var uo: SimIntent = SimIntent.unpack(packed)
	ok(uo != null and not uo.lightHeld and not uo.heavyHeld and not uo.escape and uo.light and uo.guard, "pack: an old packed intent unpacks with the new fields off")
	ok(SimIntent.unpack(1 << 43) == null, "pack: bits above 42 are refused")
	# clear and apply cover the new fields.
	var dst := SimIntent.new()
	SimIntent.applyIntent(dst, all)
	ok(dst.lightHeld and dst.heavyHeld and dst.escape, "pack: applyIntent copies them")
	SimIntent.clearIntent(dst)
	ok(not dst.lightHeld and not dst.heavyHeld and not dst.escape, "pack: clearIntent clears them")


## Escape is an edge on its own control; nothing else sets it.
func _escape_controls() -> void:
	for c in [["arena", "pad:r3"], ["brawler", "pad:r3"], ["simple-pad", "pad:r3"], ["kb-solo", "kb:KeyC"], ["kb-shared-p1", "kb:KeyX"], ["kb-shared-p2", "kb:Quote"]]:
		var l: SimLayout = _mk(c[0])
		ok(not _run(l, 3).escape, "%s: no Escape at rest" % c[0])
		l.press(c[1])
		var i: SimIntent = l.build()
		ok(i.escape, "%s: %s is Escape on the tick it is pressed (no delay)" % [c[0], c[1]])
		l.consumed()
		ok(not l.build().escape, "%s: and only that tick (an edge)" % c[0])
		l.consumed()
		l.release(c[1])
		# Held through a freeze: the edge waits for the step, as every edge does.
		l.press(c[1])
		l.build()          # a frozen tick: not consumed
		ok(l.build().escape, "%s: a press during a freeze is kept for the first live tick" % c[0])
		l.consumed()
		l.release(c[1])
	# Escape does not disturb the other actions or the transform.
	var a: SimLayout = _mk("arena")
	a.press("pad:r3")
	var ai: SimIntent = a.build()
	ok(ai.escape and not ai.transform and not ai.light and not ai.heavy and not ai.dodge and not ai.guardPress and not ai.powerPress, "arena: R3 is Escape and nothing else")
	# Every layout the player can remap has Escape bound once, and it is not a required action.
	for id in ["arena", "brawler", "simple-pad", "kb-solo", "kb-shared-p1", "kb-shared-p2"]:
		var used: Dictionary = SimInputRemap.controls_used(SimInputData.preset(id))
		var n: int = 0
		for k in used:
			if used[k] == "escape":
				n += 1
		ok(n == 1, "%s: Escape is bound once" % id)
		ok(SimInputRemap.missing_required(SimInputData.preset(id)).is_empty() and SimInputData.check_bindings(SimInputData.preset(id)).is_empty(), "%s: the layout is complete and checks clean" % id)
	# Remappable: Escape moves to another control.
	var r: Dictionary = SimInputRemap.rebind(SimInputData.original("arena"), "escape", null, 0, ["pad:dpad_down"])
	ok(r["ok"] and SimInputRemap.controls_used(r["preset"]).get("pad:dpad_down", "") == "escape", "arena: Escape can be remapped")


func _brawler_transform() -> void:
	var l: SimLayout = _mk("brawler")
	l.press("pad:dpad_up")
	var got: bool = false
	for k in range(35):
		var i: SimIntent = l.build()
		l.consumed()
		got = got or i.transform
	ok(got, "brawler: D-pad up held 30 ticks is the transform (L3 and R3 are Escape and free)")
	l.release("pad:dpad_up")
	var l2: SimLayout = _mk("brawler")
	l2.press("pad:dpad_up")
	var any: bool = false
	for k in range(20):
		any = any or l2.build().transform
		l2.consumed()
	ok(not any, "brawler: released early, no transform")


func _levels() -> void:
	# Arena: X light, Y heavy.
	var l: SimLayout = _mk("arena")
	ok(not _run(l, 2).lightHeld, "levels: none at rest")
	l.press("pad:west")
	var i: SimIntent = l.build()
	ok(i.light and i.lightHeld and not i.heavyHeld, "levels: X is the light edge and the light level on its tick")
	l.consumed()
	i = _run(l, 20)
	ok(i.lightHeld and not i.light, "levels: still down 20 ticks later, the level and no new edge")
	l.release("pad:west")
	ok(not _run(l, 1).lightHeld, "levels: released, the level ends")
	l.press("pad:north")
	i = _run(l, 5)
	ok(i.heavyHeld and not i.lightHeld, "levels: Y is the heavy level")
	l.release("pad:north")
	_run(l, 1)
	# A press shorter than a tick still has its level for the tick.
	l.press("pad:west")
	l.release("pad:west")
	i = l.build()
	ok(i.light and i.lightHeld, "levels: a sub-tick tap has its level for its tick")
	l.consumed()
	ok(not _run(l, 1).lightHeld, "levels: and not after")
	# The power layer is not an attack hold.
	l.analog("pad:rt", 0.9)
	l.press("pad:west")
	i = _run(l, 3)
	ok(not i.lightHeld and not i.heavyHeld, "levels: a special on X (the power layer) is not a held light")
	l.release("pad:west")
	l.analog("pad:rt", 0.0)
	_run(l, 2)
	# The Brawler: RB light, RT heavy.
	var b: SimLayout = _mk("brawler")
	b.press("pad:rb")
	ok(_run(b, 4).lightHeld, "levels: Brawler RB is the light level")
	b.release("pad:rb")
	b.analog("pad:rt", 0.9)
	ok(_run(b, 4).heavyHeld, "levels: Brawler RT is the heavy level")
	b.analog("pad:rt", 0.0)
	# Keyboards.
	var k: SimLayout = _mk("kb-solo")
	k.press("kb:KeyJ")
	ok(_run(k, 3).lightHeld, "levels: J holds the light")
	k.release("kb:KeyJ")
	k.press("kb:KeyK")
	ok(_run(k, 3).heavyHeld, "levels: K holds the heavy")
	# Simple pad: X is light until holdStart, then heavy (the upgrade).
	var s: SimLayout = _mk("simple-pad")
	s.press("pad:west")
	i = _run(s, 5)
	ok(i.lightHeld and not i.heavyHeld, "levels: Simple X reads as light before 12 ticks")
	i = _run(s, 8)
	ok(i.heavyHeld and not i.lightHeld, "levels: and as heavy after")
	s.release("pad:west")
	i = s.build()
	ok(not i.heavyHeld and not i.lightHeld, "levels: released, neither")
	# The bounce keeps the level: a worn contact opens for a tick and nothing lets go.
	var d: SimLayout = _mk("arena")
	d.press("pad:west")
	_run(d, 4)
	d.release("pad:west")
	d.press("pad:west")
	var di: SimIntent = d.build()
	ok(di.lightHeld and not di.light, "levels: a bounce keeps the level and makes no new press")


func _touch(dp: float) -> void:
	# Simple touch: Attack is a light level, then a heavy one.
	var t := SimTouch.new()
	t.dp = dp
	t.touch_down(1, 700.0, 300.0, "attack")
	var i: SimIntent = null
	for n in range(5):
		i = t.build()
	ok(i.lightHeld and not i.heavyHeld, "touch: Attack is the light level at first")
	for n in range(10):
		i = t.build()
	ok(i.heavyHeld and not i.lightHeld, "touch: and the heavy level after holdTicks")
	t.touch_up(1)
	t.consumed()
	ok(not t.build().heavyHeld, "touch: lifted, no level")
	# Escape: a swipe up on Guard (Simple touch), within swipeUpTicks, 40 dp or more.
	var g := SimTouch.new()
	g.dp = dp
	g.touch_down(1, 400.0, 300.0, "guard")
	for n in range(3):
		g.build()
	g.touch_move(1, 400.0, 300.0 - 39.0 * dp)
	ok(not g.build().escape, "touch: 39 dp up on Guard is not Escape")
	g.touch_move(1, 400.0, 300.0 - 41.0 * dp)
	i = g.build()
	ok(i.escape and i.guard, "touch: 41 dp up on Guard is Escape, and Guard stays down")
	g.consumed()
	g.touch_move(1, 400.0, 300.0 - 80.0 * dp)
	ok(not g.build().escape, "touch: once only")
	g.touch_up(1)
	# A slow drift is not an Escape.
	var s := SimTouch.new()
	s.dp = dp
	s.touch_down(1, 400.0, 300.0, "guard")
	for n in range(30):
		s.build()
	s.touch_move(1, 400.0, 300.0 - 80.0 * dp)
	ok(not s.build().escape, "touch: a drag after 24 ticks is not Escape (a held Guard is not a trap)")
	s.touch_up(1)
	# Full touch: the same swipe on its Guard widget.
	var f := SimTouch.new()
	f.dp = dp
	f.set_preset("touch-full")
	f.touch_down(1, 100.0, 500.0, "guard")
	f.build()
	f.touch_move(1, 100.0, 500.0 - 45.0 * dp)
	i = f.build()
	ok(i.escape and i.guard, "touch Full: a swipe up on Guard is Escape too")
	f.consumed()
	ok(not f.build().escape, "touch Full: an edge, once")
	# Through the hub, with the canonical packing.
	var hub := SimInputHub.new()
	hub.touch.set_preset("touch-simple")
	hub.touch.dp = dp
	hub.set_humans(true, false)
	hub.touch_down(1, 400.0, 300.0, "guard")
	hub.intent(0)
	hub.touch_move(1, 400.0, 300.0 - 45.0 * dp)
	ok(hub.intent(0).escape, "touch: the hub carries Escape through canon()")
