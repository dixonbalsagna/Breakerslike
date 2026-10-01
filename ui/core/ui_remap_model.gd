class_name UiRemapModel
extends RefCounted
## The Remap controls screen's rules (docs/ui/hud-spec.md section 27, docs/controls/input-schema.md section 6), with no drawing in it so
## hud_check can prove them. A layout (a preset of data/input/layouts.json, keyboard or pad) is a list of bindings; the player rebinds
## ENTRIES: the single-control, base-layer binding of an action (Light, Guard, ...) and, on a keyboard, the four Move keys as one entry.
##
##  - A control already on another entry is a CONFLICT: the screen offers a swap (the other entry takes this entry's old control).
##  - A reserved control (the keyboard's N, T, Y, P, Esc and F-keys; a pad's Start and Back) is refused, and a control belonging to the
##    other half of a shared keyboard (the `pair` preset) is refused. So a required action is never left empty.
##  - A binding on the same control as an entry that is not itself an entry (the power layer's special1 on Light's control, the Simple
##    layouts' hold gesture, signature on the power layer) FOLLOWS that entry: rebinding Light also moves them.
##  - Chords (LT + RT, Space + E, L3 + R3), the pad stick for move, Pause and Hints are fixed.
##
## What the screen produces is a list of OVERRIDES per layout: one {controls, action, layer?, gesture?, axis?} row for each binding whose
## controls differ from the layout's data. `apply(base, overrides)` puts them back on a preset (idempotent, so it is safe on a preset that
## already has them), and `preset(id)` is the layout as it is played: the data plus the player's overrides held in `overrides`.

static var overrides: Dictionary = {}   # layout id -> Array of override rows (what the player changed)

const RESERVED_KB: Array = ["KeyN", "KeyT", "KeyY", "KeyP", "Escape"]
const PAD_BINDABLE: Array = ["west", "north", "east", "south", "lb", "rb", "lt", "rt", "l3", "r3", "dpad_up", "dpad_down", "dpad_left", "dpad_right"]
const ORDER: Array = ["move", "light", "heavy", "signature", "guard", "dodge", "power", "mode", "context", "transform"]
const MOVE_STEPS: Array = ["up", "left", "down", "right"]


## The layouts a player can remap: keyboard and pad presets, in the data's order.
static func layouts() -> Array:
	SimInputData.ensure()
	var out: Array = []
	for id in SimInputData.presets:
		var d: String = str((SimInputData.presets[id] as Dictionary).get("device", ""))
		if d == "kb" or d == "pad":
			out.append(str(id))
	return out


static var _pristine: Dictionary = {}


## A layout as the data wrote it (no overrides): Controls' `SimInputData.base_preset(id)` when it exists, else a copy this class took of
## `SimInputData.preset(id)` the first time it was asked, which is the data as long as nothing has applied overrides yet.
static func base(id: String) -> Dictionary:
	var s: GDScript = SimInputData
	if s.has_method("base_preset"):
		return s.call("base_preset", id)
	if not _pristine.has(id):
		_pristine[id] = SimInputData.preset(id).duplicate(true)
	return _pristine[id]


## A layout as it is played: its data with the player's overrides on it.
static func preset(id: String) -> Dictionary:
	var base: Dictionary = SimInputData.preset(id)
	if base.is_empty() or not overrides.has(id):
		return base
	return apply(base, overrides[id])


static func _type(b: Dictionary) -> String:
	if b.has("axis"):
		return "axis"
	return "chord" if (b["controls"] as Array).size() > 1 else "single"


static func _key(b: Dictionary) -> String:
	return "%s|%s|%s|%s" % [str(b.get("action", "")), str(b.get("layer", "")), str(b.get("gesture", "")), _type(b)]


## The preset with override rows put on it: each row replaces the controls of the binding with the same action, layer, gesture and kind.
static func apply(base: Dictionary, ovr: Array) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	var bs: Array = out.get("bindings", [])
	for o in ovr:
		var k: String = _key(o)
		for b in bs:
			if _key(b) == k:
				b["controls"] = (o["controls"] as Array).duplicate()
				break
	return out


## The override rows that take `base` to `current` (same bindings, some with other controls).
static func diff(base: Dictionary, current: Dictionary) -> Array:
	var out: Array = []
	var a: Array = base.get("bindings", [])
	var b: Array = current.get("bindings", [])
	for i in range(mini(a.size(), b.size())):
		if a[i]["controls"] != b[i]["controls"]:
			out.append((b[i] as Dictionary).duplicate(true))
	return out


## The rebindable entries of a preset, in screen order: {id, action, bi (the binding's index), count (1, or 4 for the move keys)}.
static func entries(p: Dictionary) -> Array:
	var out: Array = []
	var bs: Array = p.get("bindings", [])
	var dev: String = str(p.get("device", ""))
	for i in range(bs.size()):
		var b: Dictionary = bs[i]
		var a: String = str(b.get("action", ""))
		if a == "pause" or a == "hints" or b.has("layer") or b.has("gesture"):
			continue
		var cs: Array = b["controls"]
		if b.has("axis"):
			if dev == "kb" and cs.size() == 4:
				out.append({"id": a, "action": a, "bi": i, "count": 4})
			continue
		if cs.size() != 1 or a == "move":
			continue
		out.append({"id": a, "action": a, "bi": i, "count": 1})
	out.sort_custom(func(x, y): return _rank(str(x["action"])) < _rank(str(y["action"])))
	return out


static func _rank(a: String) -> int:
	var i: int = ORDER.find(a)
	return i if i >= 0 else ORDER.size()


static func entry(p: Dictionary, id: String) -> Dictionary:
	for e in entries(p):
		if e["id"] == id:
			return e
	return {}


## The controls an entry has now.
static func controls_of(p: Dictionary, e: Dictionary) -> Array:
	return (p["bindings"][int(e["bi"])]["controls"] as Array).duplicate()


## The entry and place that hold a control: {id, idx}, or {}.
static func owner_of(p: Dictionary, control: String) -> Dictionary:
	for e in entries(p):
		var cs: Array = controls_of(p, e)
		var at: int = cs.find(control)
		if at >= 0:
			return {"id": e["id"], "idx": at}
	return {}


## Whether any binding of a preset (a chord too) uses a control.
static func uses(p: Dictionary, control: String) -> bool:
	for b in p.get("bindings", []):
		if (b["controls"] as Array).has(control):
			return true
	return false


## Bindings that follow an entry: single-control bindings on `control` that are not entries themselves.
static func _followers(p: Dictionary, ents: Array, control: String) -> Array:
	var skip := {}
	for e in ents:
		skip[int(e["bi"])] = true
	var out: Array = []
	var bs: Array = p["bindings"]
	for i in range(bs.size()):
		if skip.has(i) or bs[i].has("axis"):
			continue
		if bs[i]["controls"] == [control]:
			out.append(i)
	return out


## What happens if `control` is given to place `idx` of entry `id`: {status, with (the other entry's id, for a conflict)}. status is
## "ok", "same" (it already has it), "conflict" (another entry has it: offer a swap), "reserved", "wrong_device" or "pair" (the other
## half of a shared keyboard has it). `pair_p` is the paired preset ({} if none).
static func check(p: Dictionary, pair_p: Dictionary, id: String, idx: int, control: String) -> Dictionary:
	var dev: String = str(p.get("device", ""))
	var prefix: String = "kb:" if dev == "kb" else "pad:"
	if not control.begins_with(prefix):
		return {"status": "wrong_device"}
	var name: String = control.substr(prefix.length())
	if dev == "kb":
		var fkey: bool = name.length() <= 3 and name.begins_with("F") and name.substr(1).is_valid_int()
		if RESERVED_KB.has(name) or fkey:
			return {"status": "reserved"}
	elif not PAD_BINDABLE.has(name):
		return {"status": "reserved"}
	if not pair_p.is_empty() and uses(pair_p, control):
		return {"status": "pair"}
	var e: Dictionary = entry(p, id)
	if e.is_empty():
		return {"status": "reserved"}
	var cs: Array = controls_of(p, e)
	if idx < 0 or idx >= cs.size():
		return {"status": "reserved"}
	if cs[idx] == control:
		return {"status": "same"}
	var o: Dictionary = owner_of(p, control)
	if not o.is_empty():
		return {"status": "conflict", "with": str(o["id"]), "with_idx": int(o["idx"])}
	return {"status": "ok"}


## The preset after giving `control` to place `idx` of entry `id`, with what follows it; `swap` hands the old control to the entry that
## had `control`. Returns {} if the control is taken and `swap` is false.
static func rebind(p: Dictionary, id: String, idx: int, control: String, swap: bool) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	var ents: Array = entries(out)
	var e: Dictionary = {}
	for x in ents:
		if x["id"] == id:
			e = x
	if e.is_empty():
		return {}
	var cs: Array = controls_of(out, e)
	var old: String = str(cs[idx])
	var o: Dictionary = owner_of(out, control)
	if not o.is_empty() and not swap:
		return {}
	var fe: Array = _followers(out, ents, old)
	var fo: Array = _followers(out, ents, control) if not o.is_empty() else []
	cs[idx] = control
	out["bindings"][int(e["bi"])]["controls"] = cs
	for i in fe:
		out["bindings"][i]["controls"] = [control]
	if not o.is_empty():
		var oe: Dictionary = {}
		for x in ents:
			if x["id"] == str(o["id"]):
				oe = x
		var ocs: Array = (out["bindings"][int(oe["bi"])]["controls"] as Array).duplicate()
		ocs[int(o["idx"])] = old
		# The same entry can hold both places (two move keys swapped): read its controls again.
		if str(oe["id"]) == id:
			ocs = (out["bindings"][int(e["bi"])]["controls"] as Array).duplicate()
			ocs[int(o["idx"])] = old
		out["bindings"][int(oe["bi"])]["controls"] = ocs
		for i in fo:
			out["bindings"][i]["controls"] = [old]
	return out


## Every entry holds a control and no control is held twice on one layer: what a remapped layout must satisfy.
static func valid(p: Dictionary) -> bool:
	var seen := {}
	for e in entries(p):
		for c in controls_of(p, e):
			if str(c) == "" or seen.has(c):
				return false
			seen[c] = true
	return true


## The paired preset of a layout ("pair" in the data: the other half of a shared keyboard), as it is played, or {}.
static func pair_of(id: String) -> Dictionary:
	var base: Dictionary = SimInputData.preset(id)
	var pid: String = str(base.get("pair", ""))
	return preset(pid) if pid != "" else {}
