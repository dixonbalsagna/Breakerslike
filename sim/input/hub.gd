class_name SimInputHub
extends RefCounted
## The host's whole input side in one object (I2c): which device drives which human slot, the layout for each, and the
## intent v2 for a slot on a tick. The host (render/core/sim_host.gd) feeds it key, pad and touch events as they arrive
## and asks intent(k) once per fixed tick for each human slot; it never builds an intent itself. Engine-agnostic, so a
## headless test drives it with scripted events and gets what the game would play.
##
## Local two-player (docs/controls/local-two-player.md). A device is a keyboard, one pad (by device id) or the touch
## screen. A device that drives no slot is assigned the first time it is used, in this order:
##   1. a human slot no device drives yet (a player the mouse or a T press made human), the lower slot first;
##   2. slot 0, if nobody is playing yet (the demo): the first input is player one;
##   3. slot 1, if it is the AI: the device joins as player two (join_pending / take_joins() ask the host to make the
##      slot human);
##   4. otherwise, when both players are driven, a pad or key goes to a slot on another kind of device (a player
##      changing device), and an extra pad is ignored. A second pad never takes slot 0 from a player using it.
## Player two can hand the slot back to the AI: leave(1), the pause menu's entry, or unplugging the pad that drives it.
## A solo keyboard player uses the solo layout; two keyboard players use the shared halves; one keyboard next to a pad is
## solo. Each slot has its own pad preset, so players choose Arena, Brawler or Simple for themselves.
## Every intent leaves here in its canonical form (SimIntent.canon), the grid a replay reproduces; nothing here is
## recorded, so replays are unaffected by who joined or how.

var touch: SimTouch
var pad_preset: String = ""                  # the default pad layout
var pad_presets: Array = ["", ""]            # a slot's own pad layout; "" follows pad_preset
var touch_preset: String = "touch-simple"
var slot_device: Array = ["kb", "kb"]
var slot_pad: Array = [-1, -1]
var claimed: Array = [false, false]          # a device is driving this slot
var humans: Array = [false, false]
var layouts: Dictionary = {}      # "solo", "p1", "p2" -> SimLayout (keyboard)
var pads: Dictionary = {}         # device id -> SimLayout, built for the slot the pad drives
var notes: Array = []             # {kind: "joined" | "left", slot, device}, for UI's "P2 joined" line; take_notes() drains it
var _joins: Array = []
var _leaves: Array = []
var _was: Array = [false, false]


func _init() -> void:
	SimInputData.ensure()
	touch = SimTouch.new()
	pad_preset = SimInputData.default_preset("pad")
	touch_preset = SimInputData.default_preset("touch")
	layouts["solo"] = SimLayout.new(SimInputData.preset("kb-solo"))
	layouts["p1"] = SimLayout.new(SimInputData.preset("kb-shared-p1"))
	layouts["p2"] = SimLayout.new(SimInputData.preset("kb-shared-p2"))


## Who is human this tick (the host reads f.ai == null). A slot that stopped being human is no longer driven.
func set_humans(h0: bool, h1: bool) -> void:
	humans = [h0, h1]
	for s in range(2):
		if _was[s] and not humans[s] and not _joins.has(s):
			_free(s)
		_was[s] = humans[s]


func _free(s: int) -> void:
	_claim_release(s)
	claimed[s] = false
	slot_pad[s] = -1
	slot_device[s] = "kb"


func _taken(s: int) -> bool:
	return humans[s] or claimed[s] or _joins.has(s)


func pad_preset_of(slot: int) -> String:
	var p: String = str(pad_presets[slot])
	return p if p != "" else pad_preset


func _kb_shared() -> bool:
	return _taken(0) and _taken(1) and slot_device[0] == "kb" and slot_device[1] == "kb"


func _kb_layout(slot: int) -> SimLayout:
	if _kb_shared():
		return layouts["p1"] if slot == 0 else layouts["p2"]
	return layouts["solo"]


## Whatever the slot's previous device held is let go, so nothing sticks.
func _claim_release(slot: int) -> void:
	match slot_device[slot]:
		"kb":
			var other: int = 1 - slot
			if not (_taken(other) and slot_device[other] == "kb"):   # the other player may still be on the keyboard
				for l in layouts.values():
					l.release_all()
		"pad":
			if pads.has(slot_pad[slot]):
				pads[slot_pad[slot]].release_all()
		"touch":
			touch.release_all()


## A device took a slot.
func _claim(slot: int, device: String) -> void:
	if slot_device[slot] != device:
		_claim_release(slot)
		slot_device[slot] = device
	claimed[slot] = true


## Which slot a device that drives none should take (the order in the header), or -1. May start a join.
func _assign(device: String) -> int:
	for s in range(2):
		if (humans[s] or _joins.has(s)) and not claimed[s]:
			return s
	if not _taken(0):
		return 0
	if not _taken(1):
		_joins.append(1)
		notes.append({"kind": "joined", "slot": 1, "device": device})
		return 1
	for s in range(2):
		if slot_device[s] != device:
			return s
	return -1


## Whether a device that drives no slot would join as player two now: player one is playing and slot 1 is the AI. UI shows
## "P2: press any button to join" while this is true.
func joinable() -> bool:
	return _taken(0) and not _taken(1)


## Slots to make human (the host toggles the AI off) and slots to hand back to the AI; each call drains its list.
func take_joins() -> Array:
	var j: Array = _joins.duplicate()
	_joins.clear()
	return j


func take_leaves() -> Array:
	var l: Array = _leaves.duplicate()
	_leaves.clear()
	return l


func take_notes() -> Array:
	var n: Array = notes.duplicate()
	notes.clear()
	return n


## Player two hands the slot back to the AI (the pause menu's entry). False for slot 0 or a slot that is not human.
func leave(slot: int) -> bool:
	if slot != 1 or not (humans[1] or claimed[1]):
		return false
	var dev: String = str(slot_device[1])
	_free(1)
	_leaves.append(1)
	notes.append({"kind": "left", "slot": 1, "device": dev})
	return true


## A key by its KeyboardEvent code ("KeyF", "Space", "Shift"). Returns true if a keyboard preset uses it. A key in a
## keyboard layout is what claims or joins; other keys do nothing here.
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
		_kb_input(c)
	return used


func _kb_input(c: String) -> void:
	var kbs: Array = []
	for s in range(2):
		if _taken(s) and slot_device[s] == "kb":
			kbs.append(s)
	if kbs.size() == 2:
		for s in kbs:
			if _kb_layout(s).has_control(c):
				_claim(s, "kb")
		return
	if kbs.size() == 1 and (claimed[kbs[0]] or humans[kbs[0]]):
		_claim(kbs[0], "kb")
		return
	var s2: int = _assign("kb")
	if s2 >= 0:
		_claim(s2, "kb")


func _pad(dev: int, slot: int) -> SimLayout:
	if not pads.has(dev):
		pads[dev] = SimLayout.new(SimInputData.preset(pad_preset_of(slot)))
	return pads[dev]


## The slot a pad drives, or -1: the one it has, else a new assignment.
func _pad_slot(dev: int) -> int:
	for s in range(2):
		if slot_pad[s] == dev and claimed[s]:
			return s
	var s2: int = _assign("pad")
	if s2 < 0:
		return -1
	if slot_pad[s2] != -1 and slot_pad[s2] != dev:
		if pads.has(slot_pad[s2]):
			pads[slot_pad[s2]].release_all()
			pads.erase(slot_pad[s2])
	slot_pad[s2] = dev
	_claim(s2, "pad")
	return s2


## A pad was unplugged (Input.joy_connection_changed): its layout is dropped with every control it held, so a stick held at
## the moment of the disconnect does not keep flying. If it drove player two, the slot goes back to the AI; if it drove
## player one, the slot goes back to the keyboard.
func pad_disconnected(dev: int) -> void:
	if pads.has(dev):
		pads[dev].release_all()
		pads.erase(dev)
	for s in range(2):
		if slot_pad[s] == dev:
			if s == 1:
				leave(1)
			else:
				_free(0)
			slot_pad[s] = -1


## A pad button by position name: south, east, west, north, lb, rb, l3, r3, start, back, dpad_up, ... Any button joins.
func pad_button(dev: int, name: String, down: bool) -> void:
	if down:
		var s: int = _pad_slot(dev)
		if s < 0:
			return
		_pad(dev, s).press("pad:" + name)
		_claim(s, "pad")
	elif pads.has(dev):
		pads[dev].release("pad:" + name)


## An analog trigger ("lt", "rt"), 0 to 1.
func pad_trigger(dev: int, name: String, v: float) -> void:
	if v >= SimInputData.tf(["stick", "triggerOn"], 0.35):
		var s: int = _pad_slot(dev)
		if s < 0:
			return
		_pad(dev, s).analog("pad:" + name, v)
		_claim(s, "pad")
	elif pads.has(dev):
		pads[dev].analog("pad:" + name, v)


## The left stick, x right and y up. A stick alone does not join; it moves a pad that already drives a slot.
func pad_stick(dev: int, x: float, y: float) -> void:
	for s in range(2):
		if slot_pad[s] == dev and claimed[s]:
			_pad(dev, s).axis("pad:ls", x, y)
			if absf(x) > 0.5 or absf(y) > 0.5:
				_claim(s, "pad")
			return


## A finger down on a touch control (the host names the widget: SimTouch.widget_at). The touch screen is one device: it
## takes a slot like any other (the demo's player one, else it joins as player two).
func touch_down(id: int, x: float, y: float, widget: String) -> void:
	if widget != "":
		var slot: int = -1
		for s in range(2):
			if slot_device[s] == "touch" and claimed[s]:
				slot = s
		if slot < 0:
			slot = _assign("touch")
			if slot >= 0:
				_claim(slot, "touch")
		if slot < 0:
			return
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


## Forget which device drives which slot (a fresh start, or a test): every layout is released and the next input from any
## device is assigned again. A new match does not call this: players keep their devices from one match to the next.
func reset_claims() -> void:
	release_all()
	claimed = [false, false]
	slot_device = ["kb", "kb"]
	slot_pad = [-1, -1]
	pads.clear()
	_joins.clear()
	_leaves.clear()
	notes.clear()
	_was = [false, false]


## Let everything go (focus lost, an overlay opened, a new match).
func release_all() -> void:
	for l in layouts.values():
		l.release_all()
	for l in pads.values():
		l.release_all()
	touch.release_all()


## The match setup for the sim (SimCore.newMatch's `setup`): both slots are v2, and a slot on a Simple layout gets the
## assists that let the sim act where the input is absent. It reads the devices as they are at match start; a player who
## joins later or changes layout gets the assists from the next match.
func setup() -> Dictionary:
	var assists: Array = [[], []]
	for s in range(2):
		var flags: Dictionary = {}
		match slot_device[s]:
			"pad":
				flags = SimInputData.preset(pad_preset_of(s)).get("slot", {})
			"touch":
				flags = SimInputData.preset(touch_preset).get("slot", {})
		if flags.get("autoBurst", false):
			assists[s].append("autoBurst")
		if str(flags.get("specialPick", "chosen")) == "auto":
			assists[s].append("specialAuto")
	return {"v2": [true, true], "assists": assists}


## Change a pad layout in the middle of a match. With no slot (-1) it is the default and every slot follows it; with a slot
## it is that player's own. The cached pad layouts of the slots affected are dropped (their holds let go) and each pad
## takes the new preset on its next input. Slot claims are kept.
func set_pad_preset(id: String, slot: int = -1) -> void:
	if SimInputData.preset(id).is_empty():
		return
	if slot < 0:
		if id == pad_preset and pad_presets == ["", ""]:
			return
		pad_preset = id
		pad_presets = ["", ""]
	else:
		if pad_preset_of(slot) == id and str(pad_presets[slot]) == id:
			return
		pad_presets[slot] = id
	for s in range(2):
		if (slot < 0 or s == slot) and pads.has(slot_pad[s]):
			pads[slot_pad[s]].release_all()
			pads.erase(slot_pad[s])
	if slot < 0:
		for l in pads.values():
			l.release_all()
		pads.clear()


## The presets changed (the player remapped, or reset): every layout is rebuilt from SimInputData, with its holds let go.
## Safe in the middle of a match; slot claims are kept, so a pad stays on its slot.
func reload_layouts() -> void:
	release_all()
	layouts["solo"].set_preset(SimInputData.preset("kb-solo"))
	layouts["p1"].set_preset(SimInputData.preset("kb-shared-p1"))
	layouts["p2"].set_preset(SimInputData.preset("kb-shared-p2"))
	pads.clear()
	touch.set_preset(touch_preset)


## Choose the touch layout ("touch-simple" or "touch-full"): what is held is let go, and the touch layer's buttons change.
func set_touch_preset(id: String) -> void:
	if id == touch_preset or SimInputData.preset(id).is_empty():
		return
	touch_preset = id
	touch.set_preset(id)


## A pausing set piece (Simulation's SimPause) froze the sim: call this each frozen tick to drop what was pressed, and
## resume() when it ends to read every hold again, so a pile of presses is not released at once.
func drop_edges() -> void:
	for l in layouts.values():
		l.drop_edges()
	for l in pads.values():
		l.drop_edges()
	touch.drop_edges()


func resume() -> void:
	for l in layouts.values():
		l.resume()
	for l in pads.values():
		l.resume()
	touch.resume()


## The transform hold's progress for a slot, 0 to 1, from whichever device holds it (UI's Transform ring).
func transform_hold(slot: int) -> float:
	match slot_device[slot]:
		"pad":
			var d: int = slot_pad[slot]
			return pads[d].transform_hold() if pads.has(d) else 0.0
		"touch":
			return touch.transform_hold()
		_:
			return _kb_layout(slot).transform_hold()


## Which device a slot is on, for UI's prompt glyphs and hints ("kb", "pad", "touch"); the layout it uses is
## layout_of(slot).
func device_of(slot: int) -> String:
	return str(slot_device[slot])


## The preset id a slot plays with now: "kb-solo", "kb-shared-p1" or "kb-shared-p2", its pad preset, or the touch preset.
func layout_of(slot: int) -> String:
	match slot_device[slot]:
		"pad":
			return pad_preset_of(slot)
		"touch":
			return touch_preset
		_:
			if _kb_shared():
				return "kb-shared-p1" if slot == 0 else "kb-shared-p2"
			return "kb-solo"
