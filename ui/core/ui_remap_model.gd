class_name UiRemapModel
extends RefCounted
## The Remap controls screen's model (docs/ui/hud-spec.md section 27): what the screen lists for a layout and what happens when a control
## is given to an action. The rules themselves are Controls' (docs/controls/remap.md): SimInputRemap lists, rebinds and swaps bindings,
## SimInputData.check_bindings is the one rule check (reserved keys, required actions, conflicts, devices, the shared keyboard's pair),
## SimInputData.apply_overrides makes the layout as it is played (the layered partners and gestures follow their base action) and
## SimInputData.preset(id) is that layout from then on, so the screen, the legend and the sim all read the same one. The player's file is
## user://input.json, written by SimInputData.save_overrides and read at startup by SimInputData.load_and_apply.
##
## A ROW of the screen is a base-layer binding. An ENTRY is one the player can change: a single-control action (Light, Heavy, Signature,
## Guard, Dodge, Power, Mode, Context, Escape, Transform where a layout has a single control for it) and, on a keyboard, Fly: four keys in order
## (up, left, down, right), captured one after the other and rebound together. A FIXED row is shown greyed and cannot be captured: a chord
## (Arena's LT + RT, a keyboard's two keys; its members are free to be bound as single controls) and the pad stick. Not listed: gesture bindings and
## the power layer (they follow their action), Pause and Hints.

const ORDER: Array = ["move", "light", "heavy", "signature", "guard", "dodge", "power", "mode", "context", "escape", "transform"]
const MOVE_STEPS: Array = ["up", "left", "down", "right"]
const FIXED: Array = ["pause", "hints"]
const PAD_RESERVED: Array = ["pad:start", "pad:back"]
const KB_RESERVED: Array = ["KeyN", "KeyT", "KeyY", "KeyP", "Escape"]

## Where the screen saves (a test points it elsewhere so it never touches the player's file).
static var save_path: String = SimInputRemap.USER_PATH


## The layouts a player can remap: keyboard and pad presets, in the data's order.
static func layouts() -> Array:
	SimInputData.ensure()
	var out: Array = []
	for id in SimInputData.presets:
		var d: String = str((SimInputData.presets[id] as Dictionary).get("device", ""))
		if d == "kb" or d == "pad":
			out.append(str(id))
	return out


## A layout as it is played (the data plus the player's overrides).
## `slot` is the player: 0 is player one, 1 is player two (each can remap the same layout separately, Controls' per-player remaps).
static func preset(id: String, slot: int = 0) -> Dictionary:
	return SimInputData.preset(id, slot)


## The rows of a preset, in screen order (an action's entries, then its fixed rows): {id, action, index, controls, fixed}.
static func rows(p: Dictionary) -> Array:
	var by_action := {}
	var seen := {}
	var nfixed := {}
	for row in SimInputRemap.listing(p):
		var a: String = str(row["action"])
		if row["layer"] != null or FIXED.has(a) or not ORDER.has(a):
			continue
		var cs: Array = row["controls"]
		var fixed: bool = bool(row["fixed"])
		var id: String
		if fixed:
			id = "%s@fixed%d" % [a, int(nfixed.get(a, 0))]
			nfixed[a] = int(nfixed.get(a, 0)) + 1
		else:
			id = a if not seen.has(a) else "%s#%d" % [a, int(row["index"])]
			seen[a] = true
		if not by_action.has(a):
			by_action[a] = []
		by_action[a].append({"id": id, "action": a, "index": int(row["index"]), "controls": cs, "fixed": fixed})
	var out: Array = []
	for a in ORDER:
		var list: Array = by_action.get(a, [])
		for r in list:
			if not bool(r["fixed"]):
				out.append(r)
		for r in list:
			if bool(r["fixed"]):
				out.append(r)
	return out


## The entries (rows the player can change).
static func entries(p: Dictionary) -> Array:
	var out: Array = []
	for r in rows(p):
		if not bool(r["fixed"]):
			out.append(r)
	return out


static func entry(p: Dictionary, id: String) -> Dictionary:
	for e in entries(p):
		if e["id"] == id:
			return e
	return {}


static func _verdict(layout_id: String, ovr: Array, slot: int = 0) -> String:
	var eff: Dictionary = SimInputRemap.apply_overrides(SimInputData.original(layout_id), ovr)
	for prob in SimInputData.check_bindings(eff, slot):
		match str(prob["rule"]):
			"layout-reserved":
				return "reserved"
			"layout-pair":
				return "pair"
			"layout-device":
				return "wrong_device"
			"layout-conflict", "layout-required":
				return "reserved"
	return "ok"


## What happens if `control` is given to the single-control entry `id` of a layout (as played): {status, with, overrides}. status is "ok"
## (overrides are what to apply), "same" (it already has it), "conflict" (another action has it: `with` names it; call again with swap true
## to take it and hand over the old control), "reserved" (the keyboard's N, T, Y, P, Esc and F-keys, Start and Back, or a control of Pause or
## Hints), "pair" (the other half of a shared keyboard has it) or "wrong_device". A chord's members are free: chords are never touched.
static func attempt(layout_id: String, id: String, control: String, swap: bool = false, slot: int = 0) -> Dictionary:
	var p: Dictionary = preset(layout_id, slot)
	var e: Dictionary = entry(p, id)
	if e.is_empty() or str(e["action"]) == "move":
		return {"status": "reserved"}
	if (e["controls"] as Array)[0] == control:
		return {"status": "same"}
	if PAD_RESERVED.has(control):
		return {"status": "reserved"}
	var r: Dictionary = SimInputRemap.swap(p, e["action"], null, int(e["index"]), control) if swap else SimInputRemap.rebind(p, e["action"], null, int(e["index"]), [control])
	if not bool(r["ok"]):
		var c: Dictionary = r["conflict"]
		if not c.is_empty():
			if FIXED.has(str(c["action"])) or str(c["action"]) == "move":
				return {"status": "reserved"}
			return {"status": "conflict", "with": str(c["action"])}
		return {"status": "wrong_device" if str(r["error"]).contains("control") else "reserved"}
	var ovr: Array = SimInputRemap.diff(SimInputData.original(layout_id), r["preset"])
	var verdict: String = _verdict(layout_id, ovr, slot)
	if verdict != "ok":
		return {"status": verdict}
	return {"status": "ok", "overrides": ovr}


## One key offered for Fly's next place, `keys_so_far` being the ones already taken: {status, with}. status is "ok", "wrong_device", "reserved",
## "twice" (it is one of the keys already taken), "taken" (another action has it: `with` names it, and there is no swap for a move key) or "pair".
static func check_move_key(layout_id: String, keys_so_far: Array, control: String, slot: int = 0) -> Dictionary:
	var p: Dictionary = preset(layout_id, slot)
	if not control.begins_with("kb:"):
		return {"status": "wrong_device"}
	var name: String = control.substr(3)
	var fkey: bool = name.length() <= 3 and name.begins_with("F") and name.substr(1).is_valid_int()
	if KB_RESERVED.has(name) or fkey:
		return {"status": "reserved"}
	if keys_so_far.has(control):
		return {"status": "twice"}
	var used: Dictionary = SimInputRemap.controls_used(p)
	if used.has(control) and str(used[control]) != "move":
		return {"status": "taken", "with": str(used[control])}
	if p.has("pair"):
		var pp: Dictionary = SimInputData.preset(str(p["pair"]), 1 - slot)   # the other player's half, as that player has it
		for b in pp.get("bindings", []):
			if (b["controls"] as Array).has(control):
				return {"status": "pair"}
	return {"status": "ok"}


## All four of Fly's keys, in order up, left, down, right: {status, with, control, overrides}, the statuses of check_move_key plus "same".
static func attempt_move(layout_id: String, keys: Array, slot: int = 0) -> Dictionary:
	var p: Dictionary = preset(layout_id, slot)
	var e: Dictionary = entry(p, "move")
	if e.is_empty() or keys.size() != 4:
		return {"status": "reserved"}
	if e["controls"] == keys:
		return {"status": "same"}
	var r: Dictionary = SimInputRemap.rebind(p, "move", null, 0, keys)
	if not bool(r["ok"]):
		var c: Dictionary = r["conflict"]
		if not c.is_empty():
			return {"status": "taken", "with": str(c["action"]), "control": str(c["control"])}
		return {"status": "twice" if str(r["error"]).contains("differ") else "reserved"}
	var ovr: Array = SimInputRemap.diff(SimInputData.original(layout_id), r["preset"])
	var verdict: String = _verdict(layout_id, ovr, slot)
	if verdict != "ok":
		return {"status": verdict}
	return {"status": "ok", "overrides": ovr}


## Make `overrides` the layout's: applied to the data (so every reader of SimInputData.preset follows) and saved to the player's file.
static func commit(layout_id: String, overrides: Array, slot: int = 0) -> void:
	SimInputData.apply_overrides(layout_id, overrides, slot)
	SimInputData.save_overrides(save_path)
