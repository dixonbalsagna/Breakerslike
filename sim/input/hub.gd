class_name SimInputHub
extends RefCounted
## The host's whole input side in one object (I2c): which device drives which human slot, the layout for each, and the
## intent v2 for a slot on a tick. The host (render/core/sim_host.gd) feeds it key, pad and touch events as they arrive
## and asks intent(k) once per fixed tick for each human slot; it never builds an intent itself. Engine-agnostic, so a
## headless test drives it with scripted events and gets what the game would play.
##
## Devices: "kb", "pad" or "touch" per slot, taken by whoever sends input last (a key, a pad button, a touch), as
## UI's touch mode already follows the last device. One human uses the solo keyboard preset; two humans use the shared
## pair, the left hand for slot 0 and the right for slot 1. A pad claims the first human slot without one and keeps it.
## Every intent leaves here in its canonical form (SimIntent.canon), the grid a replay reproduces.

var touch: SimTouch
var pad_preset: String = ""
var slot_device: Array = ["kb", "kb"]
var slot_pad: Array = [-1, -1]
var humans: Array = [false, false]
var layouts: Dictionary = {}      # "solo", "p1", "p2" -> SimLayout (keyboard)
var pads: Dictionary = {}         # device id -> SimLayout


func _init() -> void:
	SimInputData.ensure()
	touch = SimTouch.new()
	pad_preset = SimInputData.default_preset("pad")
	layouts["solo"] = SimLayout.new(SimInputData.preset("kb-solo"))
	layouts["p1"] = SimLayout.new(SimInputData.preset("kb-shared-p1"))
	layouts["p2"] = SimLayout.new(SimInputData.preset("kb-shared-p2"))


## Who is human this tick (the host reads f.ai == null). It decides which keyboard preset a slot uses.
func set_humans(h0: bool, h1: bool) -> void:
	humans = [h0, h1]


func _kb_layout(slot: int) -> SimLayout:
	if humans[0] and humans[1]:
		return layouts["p1"] if slot == 0 else layouts["p2"]
	return layouts["solo"]


func _kb_slots() -> Array:
	if humans[0] and humans[1]:
		return [0, 1]
	return [0] if humans[0] else ([1] if humans[1] else [0])


## A device took a slot: whatever the slot's previous device held is let go, so nothing sticks.
func _claim(slot: int, device: String) -> void:
	if slot_device[slot] == device:
		return
	match slot_device[slot]:
		"kb":
			for l in layouts.values():
				l.release_all()
		"pad":
			if pads.has(slot_pad[slot]):
				pads[slot_pad[slot]].release_all()
		"touch":
			touch.release_all()
	slot_device[slot] = device


## A key by its KeyboardEvent code ("KeyF", "Space", "Shift"). Returns true if a keyboard preset uses it.
func key(code: String, down: bool) -> bool:
	var c: String = "kb:" + code
	var used: bool = false
	for l in layouts.values():
		if down:
			if l.press(c):
				used = true
		else:
			l.release(c)
	if down and used:
		for s in _kb_slots():
			if _kb_layout(s).has_control(c):
				_claim(s, "kb")
	return used


func _pad(dev: int) -> SimLayout:
	if not pads.has(dev):
		pads[dev] = SimLayout.new(SimInputData.preset(pad_preset))
	return pads[dev]


## The slot a pad drives: the one it has, else the first human slot no pad has, else slot 0.
func _pad_slot(dev: int) -> int:
	for s in range(2):
		if slot_pad[s] == dev:
			return s
	for s in range(2):
		if humans[s] and slot_pad[s] == -1:
			slot_pad[s] = dev
			return s
	slot_pad[0] = dev
	return 0


## A pad button by position name: south, east, west, north, lb, rb, l3, r3, start, back, dpad_up, ...
func pad_button(dev: int, name: String, down: bool) -> void:
	var l: SimLayout = _pad(dev)
	if down:
		if l.press("pad:" + name):
			_claim(_pad_slot(dev), "pad")
	else:
		l.release("pad:" + name)


## An analog trigger ("lt", "rt"), 0 to 1.
func pad_trigger(dev: int, name: String, v: float) -> void:
	var l: SimLayout = _pad(dev)
	l.analog("pad:" + name, v)
	if v >= SimInputData.tf(["stick", "triggerOn"], 0.35):
		_claim(_pad_slot(dev), "pad")


## The left stick, x right and y up.
func pad_stick(dev: int, x: float, y: float) -> void:
	var l: SimLayout = _pad(dev)
	l.axis("pad:ls", x, y)
	if absf(x) > 0.5 or absf(y) > 0.5:
		_claim(_pad_slot(dev), "pad")


## A finger down on a touch control (the host names the widget: SimTouch.widget_at). Touch drives slot 0.
func touch_down(id: int, x: float, y: float, widget: String) -> void:
	if widget != "":
		_claim(0, "touch")
	touch.touch_down(id, x, y, widget)


func touch_move(id: int, x: float, y: float) -> void:
	touch.touch_move(id, x, y)


func touch_up(id: int) -> void:
	touch.touch_up(id)


## The intent v2 for a human slot this tick, canonical, from whichever device holds the slot. Call once per slot per tick.
func intent(slot: int) -> SimIntent:
	var i: SimIntent
	match slot_device[slot]:
		"pad":
			var d: int = slot_pad[slot]
			i = pads[d].build() if pads.has(d) else SimIntent.new()
		"touch":
			i = touch.build()
		_:
			i = _kb_layout(slot).build()
	return SimIntent.canon(i)


## SimCore.step took the intents: every device's edges are spent.
func consumed() -> void:
	for l in layouts.values():
		l.consumed()
	for l in pads.values():
		l.consumed()
	touch.consumed()


## Let everything go (focus lost, an overlay opened, a new match).
func release_all() -> void:
	for l in layouts.values():
		l.release_all()
	for l in pads.values():
		l.release_all()
	touch.release_all()


## The match setup for the sim (SimCore.newMatch's `setup`): both slots are v2, and a slot on a Simple layout gets the
## assists that let the sim act where the input is absent. It reads the devices as they are at match start.
func setup() -> Dictionary:
	var assists: Array = [[], []]
	for s in range(2):
		var flags: Dictionary = {}
		match slot_device[s]:
			"pad":
				flags = SimInputData.preset(pad_preset).get("slot", {})
			"touch":
				flags = SimInputData.preset(SimInputData.default_preset("touch")).get("slot", {})
		if flags.get("autoBurst", false):
			assists[s].append("autoBurst")
		if str(flags.get("specialPick", "chosen")) == "auto":
			assists[s].append("specialAuto")
	return {"v2": [true, true], "assists": assists}


## Which device a slot is on, for UI's prompt glyphs ("kb", "pad", "touch").
func device_of(slot: int) -> String:
	return str(slot_device[slot])
