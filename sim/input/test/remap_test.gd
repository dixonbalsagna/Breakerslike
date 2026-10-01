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
	_check()
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
	ok(fixed == 1, "listing: the keyboard move axis is fixed")
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
	ok(SimInputRemap.rebind(kb, "transform", null, 0, ["kb:Space", "kb:KeyQ"])["ok"], "rebind: a chord of two controls")


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
	var bw2: Dictionary = SimInputRemap.apply_overrides(bw, [{"controls": ["pad:dpad_up"], "action": "mode"}])
	ok(_used(bw2).get("pad:dpad_up", "") == "mode" and _used(bw2, "power").get("pad:dpad_up", "") == "special3", "apply: on the Brawler special3 follows mode")
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
