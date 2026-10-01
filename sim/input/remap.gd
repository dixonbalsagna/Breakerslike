class_name SimInputRemap
## What a remap screen needs (docs/controls/input-schema.md sections 6 and 9), as pure functions on preset dictionaries:
## list what a preset binds, rebind or remove one binding with the conflict rules, check the required actions, diff a
## preset against its shipped form for saving, and read and write the player's file. No UI and no engine input: a screen
## calls these, shows what comes back, and gives the hub the result with SimInputHub.reload().
##
## A binding is {controls: [..], action, layer?, gesture?, axis?}. A preset may bind an action more than once (the
## transform has two chords and a key), so a binding is addressed by (action, layer, index) among its remappable
## bindings: single-control bindings and the keyboard's four-key move axis. A chord (several controls held together), a
## gesture binding (a swipe, a flick, a hold upgrade) and the pad stick are part of the layout and are fixed; a chord
## member is still free to be bound as a single control of its own action, and a chord is never changed by a rebind.

const USER_PATH: String = "user://input.json"

## Actions a preset must bind, by device (Tools' layout-required rule).
const REQUIRED: Array = ["move", "light", "heavy", "signature", "guard", "dodge", "power", "context", "transform"]
const REQUIRED_PAD_TOUCH: Array = ["pause"]


## Everything a screen lists for a preset: one row per remappable binding, in preset order:
## {action, layer, index, controls, fixed}. Chords, gesture bindings and the pad stick are `fixed`; the keyboard move
## axis is one row of four keys (up, left, down, right) and is not.
static func listing(preset: Dictionary) -> Array:
	var rows: Array = []
	var seen: Dictionary = {}
	for b in preset.get("bindings", []):
		var layer = b.get("layer", null)
		var key: String = "%s|%s" % [b["action"], str(layer)]
		var idx: int = seen.get(key, 0)
		var fixed: bool = not _remappable(b)
		rows.append({"action": b["action"], "layer": layer, "index": 0 if fixed else idx, "controls": b["controls"].duplicate(), "fixed": fixed})
		if not fixed:
			seen[key] = idx + 1
	return rows


## control -> action for the controls the remappable bindings use on a layer ("" is the base layer, "power" the power
## layer): the single controls and the four move keys. Chord members are not counted, so a control that only belongs to
## a chord is free for a single binding.
static func controls_used(preset: Dictionary, layer: String = "") -> Dictionary:
	var out: Dictionary = {}
	for b in preset.get("bindings", []):
		var l: String = str(b.get("layer", "")) if b.get("layer", null) != null else ""
		if l != layer or not _remappable(b):
			continue
		for c in b["controls"]:
			out[c] = b["action"]
	return out


## A binding the player may change: one control, or the keyboard's four-key move axis. Not a chord, a gesture or the
## pad's stick.
static func _remappable(b: Dictionary) -> bool:
	if b.get("gesture", null) != null:
		return false
	if b.has("axis"):
		return (b["controls"] as Array).size() == 4
	return (b["controls"] as Array).size() == 1 and str(b["action"]) != "move"


static func _same_group(b: Dictionary, action: String, layer) -> bool:
	return b["action"] == action and b.get("layer", null) == layer and _remappable(b)


## Replace binding `index` of (action, layer) with `controls` (one control, or several for a chord); an index equal to
## the count adds a new one. Returns {ok, preset, conflict, error}. A control already bound to another action on the same
## layer is a conflict: nothing changes, and `conflict` names it ({action, layer, control}) so the screen can offer swap().
static func rebind(preset: Dictionary, action: String, layer, index: int, controls: Array) -> Dictionary:
	var p: Dictionary = preset.duplicate(true)
	var prefix: String = str(p.get("device", ""))
	if controls.is_empty():
		return {"ok": false, "preset": preset, "conflict": {}, "error": "no control given"}
	for c in controls:
		if not str(c).begins_with(prefix + ":"):
			return {"ok": false, "preset": preset, "conflict": {}, "error": "%s is not a %s control" % [c, prefix]}
	var is_move: bool = action == "move"
	if is_move and not (controls.size() == 4 and preset_has_axis(p)):
		return {"ok": false, "preset": preset, "conflict": {}, "error": "the move axis takes four keys"}
	if not is_move and controls.size() != 1:
		return {"ok": false, "preset": preset, "conflict": {}, "error": "chords are fixed"}
	if is_move:
		for i in range(4):
			for j in range(i + 1, 4):
				if controls[i] == controls[j]:
					return {"ok": false, "preset": preset, "conflict": {}, "error": "the four move keys must differ"}
	var used: Dictionary = controls_used(p, "" if layer == null else str(layer))
	for c in controls:
		var other = used.get(c, "")
		if other != "" and other != action:
			return {"ok": false, "preset": preset, "conflict": {"action": other, "layer": layer, "control": c}, "error": "already bound"}
	var group: Array = []
	for i in range(p["bindings"].size()):
		if _same_group(p["bindings"][i], action, layer):
			group.append(i)
	if index < 0 or index > group.size():
		return {"ok": false, "preset": preset, "conflict": {}, "error": "no such binding"}
	var nb: Dictionary = {"controls": controls.duplicate(), "action": action}
	if layer != null:
		nb["layer"] = layer
	if is_move:
		nb["axis"] = ["up", "left", "down", "right"]
	if index == group.size():
		var at: int = group[group.size() - 1] + 1 if not group.is_empty() else p["bindings"].size()
		p["bindings"].insert(at, nb)
	else:
		p["bindings"][group[index]] = nb
	return {"ok": true, "preset": p, "conflict": {}, "error": ""}


static func preset_has_axis(p: Dictionary) -> bool:
	for b in p.get("bindings", []):
		if b.has("axis") and (b["controls"] as Array).size() == 4:
			return true
	return false


## The same, but a conflicting single control is handed over: the other action takes the control this one gave up (or
## loses the binding if this one had none).
static func swap(preset: Dictionary, action: String, layer, index: int, control: String) -> Dictionary:
	var first: Dictionary = rebind(preset, action, layer, index, [control])
	if first["ok"] or first["conflict"].is_empty():
		return first
	var other: String = first["conflict"]["action"]
	if other == "move" or action == "move":
		return first   # a move key cannot be traded one at a time: the screen rebinds the whole row
	var p: Dictionary = preset.duplicate(true)
	var old: Array = []
	var n: int = 0
	for b in p["bindings"]:
		if _same_group(b, action, layer):
			if n == index:
				old = b["controls"].duplicate()
			n += 1
	var other_at: int = _index_of(p, other, layer, control)
	_put(p, action, layer, index, [control])
	if old.size() == 1:
		_put(p, other, layer, other_at, old)
	else:
		p = remove(p, other, layer, other_at)["preset"]
	return {"ok": true, "preset": p, "conflict": {}, "error": ""}


## Set binding `index` of (action, layer) to `controls` in place.
static func _put(p: Dictionary, action: String, layer, index: int, controls: Array) -> void:
	var n: int = 0
	for i in range(p["bindings"].size()):
		if _same_group(p["bindings"][i], action, layer):
			if n == index:
				p["bindings"][i]["controls"] = controls.duplicate()
				return
			n += 1


static func _count(preset: Dictionary, action: String, layer) -> int:
	var n: int = 0
	for b in preset["bindings"]:
		if _same_group(b, action, layer):
			n += 1
	return n


static func _index_of(preset: Dictionary, action: String, layer, control: String) -> int:
	var n: int = 0
	for b in preset["bindings"]:
		if _same_group(b, action, layer):
			if b["controls"].has(control):
				return n
			n += 1
	return 0


## Remove binding `index` of (action, layer). The screen checks missing_required() before it accepts the result.
static func remove(preset: Dictionary, action: String, layer, index: int) -> Dictionary:
	var p: Dictionary = preset.duplicate(true)
	var n: int = 0
	for i in range(p["bindings"].size()):
		if _same_group(p["bindings"][i], action, layer):
			if n == index:
				p["bindings"].remove_at(i)
				return {"ok": true, "preset": p, "conflict": {}, "error": ""}
			n += 1
	return {"ok": false, "preset": preset, "conflict": {}, "error": "no such binding"}


## The actions this preset leaves unbound that it must bind (empty when it is complete): the required list, `pause` for
## a pad or touch, `mode` and the three specials unless the preset leaves them to the director, and `special_auto` when
## it does. The upgrade gestures count as binding heavy and signature (the Simple layouts).
static func missing_required(preset: Dictionary) -> Array:
	var bound: Dictionary = {}
	for b in preset.get("bindings", []):
		var a: String = str(b["action"])
		if a == "upgrade_heavy":
			a = "heavy"
		elif a == "upgrade_sig":
			a = "signature"
		if b.get("layer", null) == null:
			bound[a] = true
		else:
			bound[a + "@power"] = true
	var need: Array = REQUIRED.duplicate()
	if preset.get("device", "") != "kb":
		need.append_array(REQUIRED_PAD_TOUCH)
	var flags: Dictionary = preset.get("slot", {})
	if not flags.get("autoMode", false):
		need.append("mode")
	if str(flags.get("specialPick", "chosen")) == "auto":
		need.append("special_auto")
	else:
		need.append_array(["special1", "special2", "special3"])
	var out: Array = []
	for a in need:
		if not bound.has(a) and not bound.has(a + "@power"):
			out.append(a)
	return out


## The overrides that make `edited` from `original`, in the user file's form ({controls, action, layer?}): for every
## action and layer whose base bindings changed, all of its current bindings, which replace the shipped ones on load.
static func diff(original: Dictionary, edited: Dictionary) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for b in edited.get("bindings", []):
		if not _remappable(b) or b.get("layer", null) != null or FIXED_ACTIONS.has(str(b["action"])):
			continue
		var key: String = "%s|%s" % [b["action"], str(b.get("layer", null))]
		if seen.has(key):
			continue
		seen[key] = true
		var now: Array = _group_controls(edited, b["action"], b.get("layer", null))
		if now != _group_controls(original, b["action"], b.get("layer", null)):
			for ctl in now:
				var e: Dictionary = {"controls": ctl, "action": b["action"]}
				if b.get("layer", null) != null:
					e["layer"] = b["layer"]
				out.append(e)
	# An action that lost all its bindings has nothing in `edited` to carry it: record that as an empty-controls entry.
	for b in original.get("bindings", []):
		if not _remappable(b) or b.get("layer", null) != null or FIXED_ACTIONS.has(str(b["action"])):
			continue
		var key2: String = "%s|%s" % [b["action"], str(b.get("layer", null))]
		if not seen.has(key2):
			seen[key2] = true
			var e2: Dictionary = {"controls": [], "action": b["action"]}
			if b.get("layer", null) != null:
				e2["layer"] = b["layer"]
			out.append(e2)
	return out


static func _group_controls(preset: Dictionary, action: String, layer) -> Array:
	var g: Array = []
	for b in preset.get("bindings", []):
		if _same_group(b, action, layer):
			g.append(b["controls"].duplicate())
	return g


## Actions whose controls the player cannot change (Start stays pause).
const FIXED_ACTIONS: Array = ["pause", "hints"]


## A preset with user overrides applied: for every (action, layer) an override names, its base bindings are replaced by
## the override entries (an entry with empty controls only removes). Overrides for pause and hints, for a gesture
## binding and for a touch preset are ignored. A layered partner follows its base action: special1 sits on the control
## light has, so when light moves, special1 moves with it (the partners are read from the shipped preset: a layered
## binding whose control is a base binding's control).
static func apply_overrides(preset: Dictionary, overrides: Array) -> Dictionary:
	var p: Dictionary = preset.duplicate(true)
	if str(p.get("device", "")) == "touch":
		return p
	var partners: Array = _partners(preset)
	var groups: Dictionary = {}
	for o in overrides:
		var layer = o.get("layer", null)
		if FIXED_ACTIONS.has(str(o["action"])) or layer != null:
			continue   # a layered row follows its base action; it is never edited on its own
		var n_ctl: int = (o["controls"] as Array).size()
		if str(o["action"]) == "move":
			if n_ctl != 4 or not preset_has_axis(preset):
				continue   # the move axis takes four keys; the pad stick is fixed
		elif n_ctl > 1:
			continue   # chords are fixed
		var key: String = str(o["action"])
		if not groups.has(key):
			groups[key] = {"action": o["action"], "entries": []}
		if not (o["controls"] as Array).is_empty():
			groups[key]["entries"].append(o["controls"].duplicate())
	for key in groups:
		var g: Dictionary = groups[key]
		var at: int = -1
		var kept: Array = []
		for i in range(p["bindings"].size()):
			var b: Dictionary = p["bindings"][i]
			if _same_group(b, g["action"], null):
				if at < 0:
					at = kept.size()
			else:
				kept.append(b)
		if at < 0:
			at = kept.size()
		var inserts: Array = []
		for ctl in g["entries"]:
			var nb: Dictionary = {"controls": ctl, "action": g["action"]}
			if g["action"] == "move":
				nb["axis"] = ["up", "left", "down", "right"]
			inserts.append(nb)
		var merged: Array = kept.slice(0, at)
		merged.append_array(inserts)
		merged.append_array(kept.slice(at))
		p["bindings"] = merged
	# Layered partners follow the first control of their base action.
	for pr in partners:
		var base_ctl: Array = _first_controls(p, pr["base"])
		for b in p["bindings"]:
			if b["action"] == pr["action"] and b.get("layer", null) == pr["layer"] and b.get("gesture", null) == pr["gesture"]:
				if base_ctl.size() == 1:
					b["controls"] = base_ctl.duplicate()
	return p


## [{action, layer, gesture, base}] for each layered or gesture binding of the shipped preset whose single control is also
## a base binding's: the Simple pad's hold-to-heavy sits on the same button as light, the power-layer specials on the
## buttons of light, heavy and context.
static func _partners(preset: Dictionary) -> Array:
	var base_of: Dictionary = {}
	for b in preset.get("bindings", []):
		if b.get("layer", null) == null and b.get("gesture", null) == null and b["controls"].size() == 1 and str(b["action"]) != "move":
			base_of[b["controls"][0]] = b["action"]
	var out: Array = []
	for b in preset.get("bindings", []):
		if (b.get("layer", null) != null or b.get("gesture", null) != null) and b["controls"].size() == 1 and base_of.has(b["controls"][0]):
			out.append({"action": b["action"], "layer": b.get("layer", null), "gesture": b.get("gesture", null), "base": base_of[b["controls"][0]]})
	return out


static func _first_controls(preset: Dictionary, action: String) -> Array:
	for b in preset.get("bindings", []):
		if _same_group(b, action, null) and b["controls"].size() == 1:
			return b["controls"].duplicate()
	return []


## Problems in a preset, for the screen to show: [{rule, action, control}]. layout-reserved (a keyboard control the system
## keeps), layout-required (an action left unbound), layout-conflict (a control on two actions of one layer),
## layout-device (a control of another device) and layout-pair (the two shared-keyboard halves share a control).
static func check_bindings(preset: Dictionary, pair: Dictionary = {}) -> Array:
	var out: Array = []
	var device: String = str(preset.get("device", ""))
	var seen: Dictionary = {}
	for b in preset.get("bindings", []):
		var layer: String = str(b.get("layer", "")) if b.get("layer", null) != null else ""
		for c in b["controls"]:
			var cs: String = str(c)
			if not cs.begins_with(device + ":"):
				out.append({"rule": "layout-device", "action": b["action"], "control": cs})
			if device == "kb" and (RESERVED_KEYS.has(cs) or _is_function_key(cs)):
				out.append({"rule": "layout-reserved", "action": b["action"], "control": cs})
		if _remappable(b):
			for c1 in b["controls"]:
				var k: String = "%s|%s" % [layer, c1]
				if seen.has(k) and seen[k] != b["action"]:
					out.append({"rule": "layout-conflict", "action": b["action"], "control": c1})
				seen[k] = b["action"]
	for a in missing_required(preset):
		out.append({"rule": "layout-required", "action": a, "control": ""})
	if not pair.is_empty():
		var theirs: Dictionary = {}
		for b in pair.get("bindings", []):
			for c in b["controls"]:
				theirs[c] = b["action"]
		for b in preset.get("bindings", []):
			for c in b["controls"]:
				if theirs.has(c):
					out.append({"rule": "layout-pair", "action": b["action"], "control": c})
	return out


const RESERVED_KEYS: Array = ["kb:KeyN", "kb:KeyT", "kb:KeyY", "kb:KeyP", "kb:Escape"]


static func _is_function_key(c: String) -> bool:
	return c.length() > 4 and c.begins_with("kb:F") and c.substr(4).is_valid_int()


# ---------------------------------------------------------------- the player's file

## The user file as a dictionary, or a fresh one: {schema: 1, presets: {id: {overrides: [..]}}, options: {..}}.
static func load_file(path: String = USER_PATH) -> Dictionary:
	if FileAccess.file_exists(path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary and int(d.get("schema", 0)) == 1:
			return d
	return {"schema": 1, "presets": {}, "presets_p2": {}, "options": {}}


static func save_file(d: Dictionary, path: String = USER_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "  "))
	return true


## Put the file's overrides into SimInputData (every later preset() call returns the edited preset), unknown presets and
## actions dropped with a warning in the return value. Returns the list of dropped entries.
static func apply_file(d: Dictionary) -> Array:
	var dropped: Array = []
	SimInputData.clear_overrides()
	for slot in range(2):
		var key: String = "presets" if slot == 0 else "presets_p2"
		for id in d.get(key, {}):
			if SimInputData.presets.has(id):
				var entries: Array = []
				for o in d[key][id].get("overrides", []):
					if SimInputData.actions.is_empty() or SimInputData.actions.has(str(o.get("action", ""))):
						entries.append(o)
					else:
						dropped.append("%s: unknown action %s" % [id, str(o.get("action", ""))])
				SimInputData.set_overrides(id, entries, slot)
			else:
				dropped.append("unknown preset %s" % id)
	return dropped
