class_name FlashSet
extends RefCounted
## Art's head-flash data (data/art/flashes.json, version 3; docs/art/flash-prototype-spec.md), read once. Rendering
## reads it and never edits it: layouts, pulses, priorities, cooldowns, colours, the arbitration waits, the keep-out
## zone and Legal's rules (round tips, the low crest, the danger ray) all come from here.

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


## A flash's pulses: {count, on, off, fade, total} (spec section 5).
static func pulse(id: String) -> Dictionary:
	return flash(id).get("pulse", {})


## A flash's whole time, from its pulses: count x on + (count - 1) x off + fade (one pulse with reduced motion).
static func total(id: String, reduced: bool = false) -> float:
	var p: Dictionary = pulse(id)
	var n: int = 1 if reduced else int(p.get("count", 1))
	return n * float(p.get("on", 0.0)) + (n - 1) * float(p.get("off", 0.0)) + float(p.get("fade", 0.0))


## The share of a pulse's `on` it takes to swell to full (pulse_rule).
static func rise_fraction() -> float:
	return float(data().get("pulse_rule", {}).get("rise_fraction", 0.3))


## The keep-out zone: every layout shape sits between these angles (degrees, facing frame), ground shards excepted.
static func keep_out() -> Vector2:
	var k: Dictionary = data().get("keep_out", {})
	return Vector2(float(k.get("angle_min", 0.0)), float(k.get("angle_max", 360.0)))


## The shader's family index (circles, blades, wedges, steps) of a fighter's family key (P, A, E, C).
static func shape_of(fk: String) -> int:
	return int(SHAPES.get(String(data().get("families", {}).get(fk, "circles")), 0))


## Whether Legal's rule (round_tip, low_crest) applies to this family's flash.
static func rule(name: String, fk: String, id: String) -> bool:
	var r = data().get("legal_rules", {}).get(name, {})
	return r is Dictionary and r.get(fk) is Array and id in r[fk]


static func danger_ray() -> Dictionary:
	return data().get("legal_rules", {}).get("danger_ray", {"default_angle": 132.0, "clamp": [60.0, 200.0]})


## [rim, core] of the family's emotion flashes: the accent's mid and light steps (`accents`), unless
## `emotion_colours.overrides` lightens them against the fighter's own hair.
static func emotion_colours(fk: String) -> Array:
	var o: Dictionary = data().get("emotion_colours", {}).get("overrides", {}).get(fk, {})
	var a: Dictionary = data().get("accents", {}).get(fk, {})
	return [Color(String(o.get("rim", a.get("mid", "#ffffff")))), Color(String(o.get("core", a.get("light", "#ffffff"))))]


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
