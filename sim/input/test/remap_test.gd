extends SceneTree
## Headless checks for the remap support (sim/input/remap.gd, input_data.gd, names.gd): the listing, rebind and its
## conflicts, swap, remove, the required-action check, the diff, applying overrides (idempotent, partners follow, pause
## fixed, touch not remapped), check_bindings, the player's file, the hub reloading its layouts, and the shared names.
## From the repo root:
##   godot --headless --path . --script res://sim/input/test/remap_test.gd
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
	SimInputData.clear_overrides()
	_listing_and_required()
	_rebind()
	_diff_and_apply()
	_chords()
	_gestures()
	_move()
	_check()
	_per_slot()
	_file_and_hub()
	_names()
	SimInputData.clear_overrides()
	print("remap_test: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _kb() -> Dictionary:
	return SimInputData.original("kb-solo")


func _used(p: Dictionary, layer: String = "") -> Dictionary:
	return SimInputRemap.controls_used(p, layer)


func _listing_and_required() -> void:
	var rows: Array = SimInputRemap.listing(_kb())
	var tf: int = 0
	var fixed: int = 0
	for r in rows:
		if r["action"] == "transform":
			tf += 1
		if r["fixed"]:
			fixed += 1
	ok(rows.size() == _kb()["bindings"].size() and tf == 2, "listing: one row per binding, transform has two")
	ok(fixed == 1, "listing: only the chord is fixed on the solo keyboard")
	var mv: Dictionary = {}
	for r2 in rows:
		if r2["action"] == "move":
			mv = r2
	ok(mv.get("controls", []).size() == 4 and not mv.get("fixed", true), "listing: the move axis is one row of four keys and can be changed")
	ok(_used(_kb()).get("kb:KeyJ", "") == "light", "controls_used: J is light on the base layer")
	ok(_used(_kb(), "power").get("kb:KeyJ", "") == "special1", "controls_used: J is special1 on the power layer")
	for id in SimInputData.presets:
		ok(SimInputRemap.missing_required(SimInputData.presets[id]).is_empty(), "required: shipped preset %s is complete" % id)
	var p: Dictionary = SimInputRemap.remove(_kb(), "guard", null, 0)["preset"]
	ok(SimInputRemap.missing_required(p) == ["guard"], "required: removing guard is reported")
	p = SimInputRemap.remove(_kb(), "transform", null, 0)["preset"]
	ok(SimInputRemap.missing_required(p).is_empty(), "required: transform still has its other binding")


func _rebind() -> void:
	var kb: Dictionary = _kb()
	var r: Dictionary = SimInputRemap.rebind(kb, "light", null, 0, ["kb:KeyU"])
	ok(r["ok"] and _used(r["preset"]).get("kb:KeyU", "") == "light" and not _used(r["preset"]).has("kb:KeyJ"), "rebind: light moves from J to U")
	ok(_used(kb).get("kb:KeyJ", "") == "light", "rebind: the original is untouched")
	r = SimInputRemap.rebind(kb, "light", null, 0, ["kb:KeyK"])
	ok(not r["ok"] and r["conflict"]["action"] == "heavy" and r["conflict"]["control"] == "kb:KeyK", "rebind: a control already used is a conflict, named")
	r = SimInputRemap.rebind(kb, "light", null, 0, ["pad:west"])
	ok(not r["ok"] and r["error"] != "", "rebind: a control of another device is refused")
	ok(not SimInputRemap.rebind(kb, "light", null, 5, ["kb:KeyU"])["ok"], "rebind: a bad index is refused")
	ok(SimInputRemap.rebind(kb, "special1", "power", 0, ["kb:KeyU"])["ok"], "rebind: the power layer is its own space")
	r = SimInputRemap.rebind(kb, "guard", null, 1, ["kb:KeyG"])
	ok(r["ok"] and SimInputRemap._count(r["preset"], "guard", null) == 2, "rebind: an index at the count adds a binding")
	r = SimInputRemap.swap(kb, "light", null, 0, "kb:KeyK")
	var used: Dictionary = _used(r["preset"])
	ok(r["ok"] and used.get("kb:KeyK", "") == "light" and used.get("kb:KeyJ", "") == "heavy", "swap: light and heavy trade J and K")
	ok(SimInputRemap.swap(kb, "light", null, 0, "kb:KeyU")["ok"], "swap: with no conflict it is a plain rebind")
	ok(not SimInputRemap.rebind(kb, "transform", null, 0, ["kb:Space", "kb:KeyQ"])["ok"], "rebind: a chord cannot be made or changed (chords are fixed)")


func _diff_and_apply() -> void:
	var kb: Dictionary = _kb()
	ok(SimInputRemap.diff(kb, kb).is_empty(), "diff: no change is no overrides")
	var edited: Dictionary = SimInputRemap.rebind(kb, "light", null, 0, ["kb:KeyU"])["preset"]
	var d: Array = SimInputRemap.diff(kb, edited)
	ok(d.size() == 1 and d[0]["action"] == "light" and d[0]["controls"] == ["kb:KeyU"], "diff: one override for the changed action")
	# Partners follow: special1 moved with light.
	var eff: Dictionary = SimInputRemap.apply_overrides(kb, d)
	ok(_used(eff).get("kb:KeyU", "") == "light" and not _used(eff).has("kb:KeyJ"), "apply: light is on U")
	ok(_used(eff, "power").get("kb:KeyU", "") == "special1", "apply: special1 followed light to U")
	ok(_used(eff, "power").get("kb:KeyK", "") == "special2" and _used(eff).get("kb:KeyK", "") == "heavy", "apply: heavy and special2 stayed on K")
	ok(SimInputRemap.diff(kb, eff).size() == d.size(), "apply: and the diff round-trips")
	# Through SimInputData: effective preset, idempotent, empty restores.
	var e1: Dictionary = SimInputData.apply_overrides("kb-solo", d)
	var e2: Dictionary = SimInputData.apply_overrides("kb-solo", d)
	ok(e1 == e2 and SimInputData.preset("kb-solo") == e1, "data: apply_overrides is idempotent and preset() returns the effective one")
	ok(SimInputData.original("kb-solo") == kb, "data: original() is the shipped preset")
	SimInputData.apply_overrides("kb-solo", [])
	ok(SimInputData.preset("kb-solo") == kb, "data: an empty list restores the shipped preset")
	# A removed binding.
	var gone: Dictionary = SimInputRemap.remove(kb, "context", null, 0)["preset"]
	var d2: Array = SimInputRemap.diff(kb, gone)
	ok(d2.size() == 1 and d2[0]["controls"].is_empty(), "diff: a removed action is an empty-controls entry")
	ok(not _used(SimInputRemap.apply_overrides(kb, d2)).values().has("context"), "apply: and applying it removes the binding")
	# A layered row is never edited on its own; pause and hints are fixed; touch is not remapped.
	var lay: Array = [{"controls": ["kb:KeyU"], "action": "special1", "layer": "power"}]
	ok(SimInputRemap.apply_overrides(kb, lay) == kb, "apply: a layered row on its own is ignored (it follows its base action)")
	var ar: Dictionary = SimInputData.original("arena")
	var pz: Dictionary = SimInputRemap.apply_overrides(ar, [{"controls": ["pad:east"], "action": "pause"}])
	ok(pz == ar and _used(pz).get("pad:start", "") == "pause", "apply: pause cannot be rebound (Start stays pause)")
	var tc: Dictionary = SimInputData.original("touch-simple")
	ok(SimInputRemap.apply_overrides(tc, [{"controls": ["touch:power"], "action": "guard"}]) == tc, "apply: touch presets are not remapped")
	# The Brawler's special3 sits on the mode button: it follows mode.
	var bw: Dictionary = SimInputData.original("brawler")
	var bw2: Dictionary = SimInputRemap.apply_overrides(bw, [{"controls": ["pad:dpad_down"], "action": "mode"}])
	ok(_used(bw2).get("pad:dpad_down", "") == "mode" and _used(bw2, "power").get("pad:dpad_down", "") == "special3", "apply: on the Brawler special3 follows mode")
	# Everything the shipped presets say still validates after an identity apply.
	for id in SimInputData.presets:
		var pr: Dictionary = SimInputData.presets[id]
		ok(SimInputRemap.apply_overrides(pr, []) == pr, "apply: an empty override list leaves %s as it is" % id)


func _check() -> void:
	for id in SimInputData.presets:
		ok(SimInputData.check_bindings(SimInputData.presets[id]).is_empty(), "check: shipped preset %s has no problems" % id)
	var kb: Dictionary = _kb()
	var bad: Dictionary = SimInputRemap.apply_overrides(kb, [{"controls": ["kb:KeyP"], "action": "light"}])
	var probs: Array = SimInputData.check_bindings(bad)
	var rules: Array = []
	for pr in probs:
		rules.append(pr["rule"])
	ok(rules.has("layout-reserved"), "check: P is reserved for the system")
	bad = SimInputRemap.apply_overrides(kb, [{"controls": ["kb:F5"], "action": "light"}])
	ok(SimInputData.check_bindings(bad).any(func(x): return x["rule"] == "layout-reserved" and x["control"] == "kb:F5"), "check: a function key is reserved")
	bad = SimInputRemap.apply_overrides(kb, [{"controls": ["kb:KeyK"], "action": "light"}])
	ok(SimInputData.check_bindings(bad).any(func(x): return x["rule"] == "layout-conflict"), "check: K on light and heavy is a conflict")
	bad = SimInputRemap.apply_overrides(kb, [{"controls": [], "action": "guard"}])
	ok(SimInputData.check_bindings(bad).any(func(x): return x["rule"] == "layout-required" and x["action"] == "guard"), "check: a removed guard is a missing required action")
	# The two shared-keyboard halves cannot share a key.
	var p1: Dictionary = SimInputData.original("kb-shared-p1")
	var shared: Dictionary = SimInputRemap.apply_overrides(p1, [{"controls": ["kb:KeyH"], "action": "light"}])
	ok(SimInputData.check_bindings(shared).any(func(x): return x["rule"] == "layout-pair" and x["control"] == "kb:KeyH"), "check: H is slot 1's light, so slot 0 cannot take it")
	var ok_pair: Dictionary = SimInputRemap.apply_overrides(p1, [{"controls": ["kb:KeyB"], "action": "light"}])
	ok(not SimInputData.check_bindings(ok_pair).any(func(x): return x["rule"] == "layout-pair"), "check: a free key is not a pair conflict")
	# Mode can be rebound.
	var m: Dictionary = SimInputRemap.apply_overrides(kb, [{"controls": ["kb:KeyB"], "action": "mode"}])
	ok(_used(m).get("kb:KeyB", "") == "mode" and SimInputData.check_bindings(m).is_empty(), "check: mode can be rebound")


func _file_and_hub() -> void:
	var path: String = "user://input_remap_test.json"
	var d: Dictionary = SimInputRemap.load_file(path)
	ok(d["schema"] == 1 and d["presets"].is_empty(), "file: a fresh file when there is none")
	var edited: Dictionary = SimInputRemap.rebind(_kb(), "light", null, 0, ["kb:KeyU"])["preset"]
	d["presets"]["kb-solo"] = {"overrides": SimInputRemap.diff(_kb(), edited)}
	d["presets"]["no-such-preset"] = {"overrides": []}
	d["presets"]["arena"] = {"overrides": [{"controls": ["pad:east"], "action": "no_such_action"}]}
	ok(SimInputRemap.save_file(d, path), "file: saves")
	var d2: Dictionary = SimInputRemap.load_file(path)
	ok(d2["presets"].has("kb-solo"), "file: loads what it saved")
	var dropped: Array = SimInputRemap.apply_file(d2)
	ok(dropped.size() == 2, "file: an unknown preset and an unknown action are dropped, the rest applies (%d dropped)" % dropped.size())
	ok(SimInputData.preset("kb-solo") != SimInputData.original("kb-solo"), "file: SimInputData.preset returns the edited preset")
	# save_overrides writes the current overrides in UI's shape.
	var path2: String = "user://input_remap_test2.json"
	ok(SimInputData.save_overrides(path2), "file: save_overrides writes")
	var d3: Dictionary = SimInputRemap.load_file(path2)
	ok(d3["schema"] == 1 and d3["presets"].has("kb-solo") and d3["presets"]["kb-solo"]["overrides"][0]["action"] == "light", "file: in the shape {schema, presets: {id: {overrides}}}")
	# The hub plays the remapped key after reload_layouts().
	var hub := SimInputHub.new()
	hub.set_humans(true, false)
	ok(hub.key("KeyU", true) and hub.intent(0).light, "hub: U is the light after the file is applied")
	hub.consumed()
	hub.key("KeyU", false)
	hub.key("KeyJ", true)
	ok(not hub.intent(0).light, "hub: and J no longer is")
	hub.consumed()
	hub.key("KeyJ", false)
	SimInputData.apply_overrides("kb-solo", [])
	hub.reload_layouts()
	ok(hub.key("KeyJ", true) and hub.intent(0).light, "hub: after a reset and reload_layouts J is the light again")
	hub.consumed()
	hub.key("KeyJ", false)
	# Mid-match: a held key is let go and a pad keeps its slot.
	hub.set_humans(true, true)
	hub.pad_button(3, "west", true)
	hub.key("Shift", true)
	hub.reload_layouts()
	ok(hub.slot_pad[0] == 3 or hub.slot_pad[1] == 3, "hub: reload_layouts keeps a pad's slot")
	hub.set_humans(true, false)
	ok(not hub.intent(0).guard, "hub: and lets a held key go")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path2))


func _names() -> void:
	ok(SimInputNames.kb("KeyF") == "kb:KeyF" and SimInputNames.pad("south") == "pad:south", "names: control ids")
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_X
	b.pressed = true
	ok(SimInputNames.pad_control_from_event(b) == "pad:west", "names: X is the west button")
	b.pressed = false
	ok(SimInputNames.pad_control_from_event(b) == "", "names: a release is not a binding")
	var m := InputEventJoypadMotion.new()
	m.axis = JOY_AXIS_TRIGGER_RIGHT
	m.axis_value = 0.9
	ok(SimInputNames.pad_control_from_event(m) == "pad:rt", "names: RT past triggerOn is pad:rt")
	m.axis_value = 0.2
	ok(SimInputNames.pad_control_from_event(m) == "", "names: a light pull is nothing")
	m.axis = JOY_AXIS_LEFT_X
	m.axis_value = 1.0
	ok(SimInputNames.pad_control_from_event(m) == "", "names: a stick is not a binding")
	for idx in SimInputNames.PAD_BUTTONS:
		var name: String = SimInputNames.PAD_BUTTONS[idx]
		ok(name != "", "names: button %d has a name" % idx)


func _chords() -> void:
	var ar: Dictionary = SimInputData.original("arena")
	var used: Dictionary = _used(ar)
	ok(not used.has("pad:l3") and used.get("pad:r3", "") == "escape" and used.get("pad:lt", "") == "dodge" and used.get("pad:rt", "") == "power", "chords: L3 is free, R3 is Escape; LT and RT are dodge and power's own")
	var chords_before: int = 0
	for b in ar["bindings"]:
		if b["controls"].size() > 1:
			chords_before += 1
	var r: Dictionary = SimInputRemap.rebind(ar, "light", null, 0, ["pad:l3"])
	var chords_after: int = 0
	for b in r["preset"]["bindings"]:
		if b["controls"].size() > 1:
			chords_after += 1
	ok(r["ok"] and chords_before == 1 and chords_after == 1, "chords: light can take L3 and the chord is untouched")
	r = SimInputRemap.swap(ar, "dodge", null, 0, "pad:lb")
	var u: Dictionary = _used(r["preset"])
	var kept: bool = false
	for b in r["preset"]["bindings"]:
		if b["controls"] == ["pad:lt", "pad:rt"] and b["action"] == "transform":
			kept = true
	ok(r["ok"] and u.get("pad:lb", "") == "dodge" and u.get("pad:lt", "") == "guard" and kept, "chords: dodge and guard swap across a chord member and the chord stays")
	r = SimInputRemap.rebind(ar, "power", null, 0, ["pad:dpad_left"])
	ok(r["ok"] and SimInputRemap.rebind(r["preset"], "mode", null, 0, ["pad:rt"])["ok"], "chords: power can leave RT and mode take it")
	var kb: Dictionary = _kb()
	ok(_used(kb).get("kb:Space", "") == "dodge" and _used(kb).get("kb:KeyE", "") == "power", "chords: Space and E belong to dodge and power, not to the chord")
	r = SimInputRemap.swap(kb, "power", null, 0, "kb:KeyQ")
	ok(r["ok"] and _used(r["preset"]).get("kb:KeyQ", "") == "power" and _used(r["preset"]).get("kb:KeyE", "") == "mode", "chords: power and mode swap, E (a chord member) goes to mode")
	ok(SimInputData.check_bindings(r["preset"]).is_empty(), "chords: and the result checks clean")
	var chord_rows: int = 0
	for row in SimInputRemap.listing(ar):
		if row["controls"].size() > 1 and row["fixed"]:
			chord_rows += 1
	ok(chord_rows == 1, "chords: listing marks the Arena chord fixed")


func _gestures() -> void:
	var sp: Dictionary = SimInputData.original("simple-pad")
	var eff: Dictionary = SimInputRemap.apply_overrides(sp, [{"controls": ["pad:dpad_up"], "action": "light"}])
	var hold_on: String = ""
	var auto_on: String = ""
	for b in eff["bindings"]:
		if b["action"] == "upgrade_heavy":
			hold_on = b["controls"][0]
		if b["action"] == "special_auto":
			auto_on = b["controls"][0]
	ok(_used(eff).get("pad:dpad_up", "") == "light", "gesture: light moved to the d-pad")
	ok(hold_on == "pad:dpad_up", "gesture: the hold-to-heavy follows light")
	ok(auto_on == "pad:dpad_up", "gesture: and the power-layer special follows too")
	var l := SimLayout.new(eff)
	l.press("pad:dpad_up")
	for k in range(12):
		l.build()
	ok(l.build().heavy, "gesture: the moved control still gives a heavy when held")
	ok(SimInputRemap.apply_overrides(sp, []) == sp, "gesture: no overrides leave the preset alone")
	var d: Array = SimInputRemap.diff(sp, eff)
	ok(SimInputRemap.diff(sp, SimInputRemap.apply_overrides(sp, d)).size() == d.size(), "gesture: the diff round-trips")


func _move() -> void:
	var kb: Dictionary = _kb()
	var arrows: Array = ["kb:ArrowUp", "kb:ArrowLeft", "kb:ArrowDown", "kb:ArrowRight"]
	var r: Dictionary = SimInputRemap.rebind(kb, "move", null, 0, arrows)
	ok(r["ok"] and _used(r["preset"]).get("kb:ArrowLeft", "") == "move" and not _used(r["preset"]).has("kb:KeyW"), "move: the four keys change as one row")
	ok(SimInputRemap.preset_has_axis(r["preset"]), "move: and the axis binding survives")
	ok(not SimInputRemap.rebind(kb, "move", null, 0, ["kb:ArrowUp", "kb:ArrowUp", "kb:ArrowDown", "kb:ArrowRight"])["ok"], "move: four different keys are required")
	ok(not SimInputRemap.rebind(kb, "move", null, 0, ["kb:ArrowUp"])["ok"], "move: one key is refused")
	var c: Dictionary = SimInputRemap.rebind(kb, "move", null, 0, ["kb:KeyJ", "kb:ArrowLeft", "kb:ArrowDown", "kb:ArrowRight"])
	ok(not c["ok"] and c["conflict"]["action"] == "light", "move: a key another action uses is a conflict, named")
	var c2: Dictionary = SimInputRemap.rebind(kb, "light", null, 0, ["kb:KeyW"])
	ok(not c2["ok"] and c2["conflict"]["action"] == "move", "move: an action cannot take a move key")
	ok(not SimInputRemap.swap(kb, "light", null, 0, "kb:KeyW")["ok"], "move: and a swap with a move key is refused")
	var d: Array = SimInputRemap.diff(kb, r["preset"])
	ok(d.size() == 1 and d[0]["action"] == "move" and d[0]["controls"] == arrows, "move: the diff is one row of four keys")
	var eff: Dictionary = SimInputRemap.apply_overrides(kb, d)
	ok(SimInputRemap.preset_has_axis(eff) and _used(eff).get("kb:ArrowRight", "") == "move", "move: apply_overrides keeps the axis shape")
	ok(SimInputData.check_bindings(eff).is_empty(), "move: the arrows check clean")
	var ar: Dictionary = SimInputData.original("arena")
	ok(not SimInputRemap.rebind(ar, "move", null, 0, ["pad:dpad_up"])["ok"], "move: the pad stick cannot be rebound")
	ok(SimInputRemap.apply_overrides(ar, [{"controls": ["pad:dpad_up", "pad:dpad_left", "pad:dpad_down", "pad:dpad_right"], "action": "move"}]) == ar, "move: an override for the pad's move is ignored")
	var rows_fixed: bool = false
	for row in SimInputRemap.listing(ar):
		if row["action"] == "move":
			rows_fixed = row["fixed"]
	ok(rows_fixed, "move: the pad's move row is fixed")
	var p1: Dictionary = SimInputData.original("kb-shared-p1")
	var bad: Dictionary = SimInputRemap.apply_overrides(p1, [{"controls": ["kb:KeyI", "kb:KeyJ", "kb:KeyK", "kb:KeyL"], "action": "move"}])
	var pair_hits: int = 0
	for pr in SimInputData.check_bindings(bad):
		if pr["rule"] == "layout-pair":
			pair_hits += 1
	ok(pair_hits == 4, "move: slot 0 on slot 1's four keys is four pair conflicts (%d)" % pair_hits)
	var free: Dictionary = SimInputRemap.apply_overrides(p1, [{"controls": arrows, "action": "move"}])
	ok(not SimInputData.check_bindings(free).any(func(x): return x["rule"] == "layout-pair"), "move: the arrows are free for slot 0")
	SimInputData.apply_overrides("kb-solo", d)
	var hub := SimInputHub.new()
	hub.set_humans(true, false)
	hub.key("ArrowUp", true)
	hub.key("ArrowRight", true)
	var i: SimIntent = hub.intent(0)
	ok(i.my == 1.0 and i.mx == 1.0, "move: Up and Right move the fighter after the remap")
	hub.consumed()
	hub.key("ArrowUp", false)
	hub.key("ArrowRight", false)
	hub.key("KeyW", true)
	ok(hub.intent(0).my == 0.0, "move: and W no longer does")
	SimInputData.apply_overrides("kb-solo", [])


func _per_slot() -> void:
	SimInputData.clear_overrides()
	var light_up: Array = [{"controls": ["pad:dpad_up"], "action": "light"}]
	var e1: Dictionary = SimInputData.apply_overrides("arena", light_up, 1)
	ok(SimInputData.preset("arena", 0) == SimInputData.original("arena"), "per slot: player one's Arena is untouched by player two's remap")
	ok(SimInputData.preset("arena", 1) == e1 and e1 != SimInputData.original("arena"), "per slot: player two's Arena has it")
	ok(SimInputRemap.controls_used(SimInputData.preset("arena", 1)).get("pad:dpad_up", "") == "light" and SimInputRemap.controls_used(SimInputData.preset("arena", 0)).get("pad:west", "") == "light", "per slot: player two's light is on the d-pad, player one's on X")
	# The default slot is player one's, as before.
	SimInputData.apply_overrides("arena", [{"controls": ["pad:dpad_left"], "action": "light"}])
	ok(SimInputRemap.controls_used(SimInputData.preset("arena")).get("pad:dpad_left", "") == "light" and SimInputRemap.controls_used(SimInputData.preset("arena", 1)).get("pad:dpad_up", "") == "light", "per slot: no slot argument is player one, and player two's stays")
	# The hub: two pads on Arena, each with their own remap.
	var hub := SimInputHub.new()
	hub.set_humans(true, true)
	hub.pad_button(3, "dpad_left", true)    # player one's light is on the d-pad's left
	hub.pad_button(9, "dpad_up", true)      # player two's is on the d-pad's up
	var a: SimIntent = hub.intent(0)
	var b: SimIntent = hub.intent(1)
	ok(a.light and b.light, "per slot: each pad's remapped light works for its own player")
	hub.consumed()
	hub.pad_button(3, "dpad_left", false)
	hub.pad_button(9, "dpad_up", false)
	hub.pad_button(3, "west", true)         # X is no longer player one's light
	hub.pad_button(9, "west", true)         # player two is a different remap; the X press is not theirs either
	ok(not hub.intent(0).light, "per slot: X is no longer a light for player one")
	hub.consumed()
	# The solo keyboard under a player's own remap: player one on a pad, player two on the keyboard.
	SimInputData.clear_overrides()
	SimInputData.apply_overrides("kb-solo", [{"controls": ["kb:KeyU"], "action": "light"}], 1)
	var hub2 := SimInputHub.new()
	hub2.set_humans(true, false)
	hub2.pad_button(0, "south", true)
	hub2.set_humans(true, false)
	hub2.key("KeyU", true)
	ok(hub2.device_of(1) == "kb" and hub2.layout_of(1) == "kb-solo", "per slot: the keyboard joins as player two")
	hub2.set_humans(true, true)
	ok(hub2.intent(1).light, "per slot: player two's solo keyboard has their own light key")
	hub2.consumed()
	hub2.key("KeyU", false)
	hub2.key("KeyJ", true)
	ok(not hub2.intent(1).light, "per slot: and the default J is not a light for them")
	hub2.consumed()
	hub2.key("KeyJ", false)
	# check_bindings compares the shared halves across players: slot 0's half against slot 1's.
	SimInputData.clear_overrides()
	SimInputData.apply_overrides("kb-shared-p2", [{"controls": ["kb:KeyB"], "action": "light"}], 1)
	var p1_try: Dictionary = SimInputRemap.apply_overrides(SimInputData.original("kb-shared-p1"), [{"controls": ["kb:KeyB"], "action": "light"}])
	ok(SimInputData.check_bindings(p1_try, 0).any(func(x): return x["rule"] == "layout-pair" and x["control"] == "kb:KeyB"), "per slot: slot 0 cannot take the B key player two's half now uses")
	ok(not SimInputData.check_bindings(SimInputData.preset("kb-shared-p2", 1), 1).any(func(x): return x["rule"] == "layout-pair"), "per slot: and player two's own half is fine")
	# The file keeps both players apart.
	SimInputData.clear_overrides()
	SimInputData.apply_overrides("arena", light_up, 1)
	SimInputData.apply_overrides("arena", [{"controls": ["pad:dpad_left"], "action": "light"}], 0)
	var path: String = "user://input_slot_test.json"
	ok(SimInputData.save_overrides(path), "per slot: the file saves")
	var d: Dictionary = SimInputRemap.load_file(path)
	ok(d["presets"].has("arena") and d["presets_p2"].has("arena") and d["presets"]["arena"]["overrides"][0]["controls"] == ["pad:dpad_left"] and d["presets_p2"]["arena"]["overrides"][0]["controls"] == ["pad:dpad_up"], "per slot: presets is player one's and presets_p2 is player two's")
	SimInputData.clear_overrides()
	SimInputRemap.apply_file(d)
	ok(SimInputRemap.controls_used(SimInputData.preset("arena", 0)).get("pad:dpad_left", "") == "light" and SimInputRemap.controls_used(SimInputData.preset("arena", 1)).get("pad:dpad_up", "") == "light", "per slot: and loads back into the right players")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SimInputData.clear_overrides()
