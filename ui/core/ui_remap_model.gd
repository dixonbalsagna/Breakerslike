class_name UiRemapModel
extends RefCounted
## The Remap controls screen's model (docs/ui/hud-spec.md section 27): what the screen lists for a layout and what happens when a control
## is given to an action. The rules themselves are Controls' (docs/controls/remap.md): SimInputRemap lists, rebinds and swaps bindings,
## SimInputData.check_bindings is the one rule check (reserved keys, required actions, conflicts, devices, the shared keyboard's pair),
## SimInputData.apply_overrides makes the layout as it is played (the layered partners follow their base action) and
## SimInputData.preset(id) is that layout from then on, so the screen, the legend and the sim all read the same one. The player's file is
## user://input.json, written by SimInputData.save_overrides and read at startup by SimInputData.load_and_apply.
##
## An ENTRY is a single-control, base-layer binding the player can change: Light, Heavy, Signature, Guard, Dodge, Power, Mode, Context and
## Transform where a layout has a single control for it. Fixed (not listed): the keyboard's move keys, the pad stick, the chords, gesture
## bindings, the power layer (its partners follow), Pause and Hints.

const ORDER: Array = ["light", "heavy", "signature", "guard", "dodge", "power", "mode", "context", "transform"]
const FIXED: Array = ["pause", "hints"]
const PAD_RESERVED: Array = ["pad:start", "pad:back"]

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
static func preset(id: String) -> Dictionary:
	return SimInputData.preset(id)


## The entries of a preset, in screen order: {id, action, index (among the action's base bindings, chords included), control}.
static func entries(p: Dictionary) -> Array:
	var out: Array = []
	var seen := {}
	for row in SimInputRemap.listing(p):
		var a: String = str(row["action"])
		if row["layer"] != null or bool(row["fixed"]) or FIXED.has(a) or (row["controls"] as Array).size() != 1 or not ORDER.has(a):
			continue
		var id: String = a if not seen.has(a) else "%s#%d" % [a, int(row["index"])]
		seen[a] = true
		out.append({"id": id, "action": a, "index": int(row["index"]), "control": str(row["controls"][0])})
	out.sort_custom(func(x, y): return ORDER.find(str(x["action"])) < ORDER.find(str(y["action"])))
	return out


static func entry(p: Dictionary, id: String) -> Dictionary:
	for e in entries(p):
		if e["id"] == id:
			return e
	return {}


## What happens if `control` is given to entry `id` of preset `layout_id` (as played): {status, with, overrides}. status is "ok" (overrides
## are what to apply), "same" (it already has it), "conflict" (another action has it: `with` names it; call again with swap true to take it
## and hand over the old control), "reserved" (the keyboard's N, T, Y, P, Esc and F-keys, Start and Back, or a control of Pause or Hints),
## "pair" (the other half of a shared keyboard has it), "chord" (it is part of a chord, which stays as it is; `with` names the chord's action)
## or "wrong_device".
static func attempt(layout_id: String, id: String, control: String, swap: bool = false) -> Dictionary:
	var p: Dictionary = preset(layout_id)
	var e: Dictionary = entry(p, id)
	if e.is_empty():
		return {"status": "reserved"}
	if str(e["control"]) == control:
		return {"status": "same"}
	if PAD_RESERVED.has(control):
		return {"status": "reserved"}
	# A control that is part of a chord (LT + RT, L3 + R3, Space + E) stays with it: the chords are fixed.
	for b in p.get("bindings", []):
		if (b["controls"] as Array).size() > 1 and not b.has("axis") and (b["controls"] as Array).has(control):
			return {"status": "chord", "with": str(b["action"])}
	var r: Dictionary = SimInputRemap.swap(p, e["action"], null, int(e["index"]), control) if swap else SimInputRemap.rebind(p, e["action"], null, int(e["index"]), [control])
	if not bool(r["ok"]):
		var c: Dictionary = r["conflict"]
		if not c.is_empty():
			if FIXED.has(str(c["action"])):
				return {"status": "reserved"}
			return {"status": "conflict", "with": str(c["action"])}
		return {"status": "wrong_device" if str(r["error"]).contains("control") else "reserved"}
	var ovr: Array = SimInputRemap.diff(SimInputData.original(layout_id), r["preset"])
	var eff: Dictionary = SimInputRemap.apply_overrides(SimInputData.original(layout_id), ovr)
	for prob in SimInputData.check_bindings(eff):
		match str(prob["rule"]):
			"layout-reserved":
				return {"status": "reserved"}
			"layout-pair":
				return {"status": "pair"}
			"layout-device":
				return {"status": "wrong_device"}
			"layout-conflict", "layout-required":
				return {"status": "reserved"}
	return {"status": "ok", "overrides": ovr}


## Make `overrides` the layout's: applied to the data (so every reader of SimInputData.preset follows) and saved to the player's file.
static func commit(layout_id: String, overrides: Array) -> void:
	SimInputData.apply_overrides(layout_id, overrides)
	SimInputData.save_overrides(save_path)
