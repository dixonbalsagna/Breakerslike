class_name FlashSet
extends RefCounted
## Art's head-flash data (data/art/flashes.json; docs/art/flash-prototype-spec.md), read once. Rendering reads it and
## never edits it: layouts, timings, priorities, cooldowns, the info flashes' colours, the arbitration waits and
## Legal's rules (round tips, the low crest, the danger ray) all come from here.

const PATH := "res://data/art/flashes.json"
## The shader's family index for each shape name in the data's `families`.
const SHAPES: Dictionary = {"circles": 0, "blades": 1, "wedges": 2, "steps": 3}

static var _data: Dictionary = {}
static var _ids: Array = []


static func data() -> Dictionary:
	if _data.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary:
			_data = d
			var fl: Dictionary = d.get("flashes", {})
			_ids = fl.keys()
	return _data


## One flash's record, or {} if the set has none by that id.
static func flash(id: String) -> Dictionary:
	return data().get("flashes", {}).get(id, {})


## The flash ids in the data's order (the debug keys follow it).
static func ids() -> Array:
	data()
	return _ids


static func priority(id: String) -> int:
	return int(flash(id).get("priority", 99))


static func total(id: String) -> float:
	var f: Dictionary = flash(id)
	return float(f.get("attack", 0.0)) + float(f.get("hold", 0.0)) + float(f.get("fade", 0.0))


## The shader's family index (circles, blades, wedges, steps) of a fighter's family key (P, A, E, C).
static func shape_of(fk: String) -> int:
	return int(SHAPES.get(String(data().get("families", {}).get(fk, "circles")), 0))


## Whether Legal's rule (round_tip, low_crest) applies to this family's flash.
static func rule(name: String, fk: String, id: String) -> bool:
	var r = data().get("legal_rules", {}).get(name, {})
	return r is Dictionary and r.get(fk) is Array and id in r[fk]


static func danger_ray() -> Dictionary:
	return data().get("legal_rules", {}).get("danger_ray", {"default_angle": 132.0, "clamp": [60.0, 200.0]})


## [core, line] of the family's info flashes.
static func info_colours(fk: String) -> Array:
	var c: Dictionary = data().get("legal_rules", {}).get("info_colours", {}).get(fk, {})
	return [Color(String(c.get("core", "#ffffff"))), Color(String(c.get("line", "#404040")))]


## Seconds a flash due while another (or the crown) is up waits before it is dropped.
static func default_wait() -> float:
	return float(data().get("arbitration", {}).get("default_wait_max", 0.25))


## The flash's sequence block (Resolve: after the crown's pop), or {}.
static func sequence(id: String) -> Dictionary:
	var s = flash(id).get("sequence")
	return s if s is Dictionary else {}
