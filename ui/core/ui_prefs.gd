class_name UiPrefs
extends RefCounted
## The few things the UI remembers between runs, in one small file (`user://ui_prefs.json`; on the web that is the browser's
## storage). Today: whether the player has seen the How to play card. Reads and writes never throw: a missing or unreadable file
## means "nothing remembered", and a write that fails is ignored (the card then shows again next run, which is harmless).

static var path := "user://ui_prefs.json"


static func load_all() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}


static func get_bool(key: String, default: bool = false) -> bool:
	return bool(load_all().get(key, default))


static func set_bool(key: String, value: bool) -> void:
	set_value(key, value)


## Any JSON value (a bool, a number, a string, a dictionary).
static func get_value(key: String, default = null):
	return load_all().get(key, default)


static func set_value(key: String, value) -> void:
	var d: Dictionary = load_all()
	d[key] = value
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
