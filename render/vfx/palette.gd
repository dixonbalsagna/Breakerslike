class_name VfxPalette
extends RefCounted
## Art's semantic effect colours (data/art/effects.json, schema tools/schemas/art-effects.schema.json): trail core,
## glass, steel, dust, crack line and lit lip, per biome. Read once; if the file is missing or malformed the placeholders
## in vfx_look.gd stand in, so an effect never fails to draw for want of a colour. Presentation only.

static var _d: Dictionary = {}
static var _loaded: bool = false


## Read the file now (the hub does at each match start), so the first crack or puff does not pay for it mid-fight.
static func warm() -> void:
	_load()


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var path := "res://data/art/effects.json"
	if FileAccess.file_exists(path):
		var v = JSON.parse_string(FileAccess.get_file_as_string(path))
		if v is Dictionary and v.has("lanes") and v.has("by_biome"):
			_d = v


static func _hex(s, fallback: String) -> Color:
	return RenderLook.col(String(s) if s is String and String(s).begins_with("#") else fallback)


## The sim's biome name at world x, as Art's by_biome keys have it (a village is the harbour type by default).
static func biome_key(x: float) -> String:
	var b: String = WorldBiomes.biomeAt(x)
	return "village_harbour" if b == "village" else b


static func trail_core() -> Color:
	_load()
	return _hex(_d.get("lanes", {}).get("trail", {}).get("core"), VfxLook.TRAIL_CORE)


static func haze() -> Color:
	_load()
	return _hex(_d.get("haze"), VfxLook.TRAIL_NEUTRAL)


## step: "light", "mid" or "shadow".
static func glass(step: String) -> Color:
	_load()
	return _hex(_d.get("lanes", {}).get("glass", {}).get(step), VfxLook.GLASS if step != "light" else VfxLook.GLASS_HI)


static func steel(step: String) -> Color:
	_load()
	return _hex(_d.get("lanes", {}).get("steel", {}).get(step), VfxLook.STEEL if step != "light" else VfxLook.STEEL_HI)


static func dust(biome: String, step: String) -> Color:
	_load()
	var by = _d.get("by_biome", {})
	var lane = by.get(biome, {}).get("dust") if by.has(biome) else null
	if not (lane is Dictionary):
		lane = _d.get("lanes", {}).get("dust", {}).get("default", {})
	return _hex(lane.get(step), VfxLook.DUST_A if step != "shadow" else VfxLook.DUST_B)


## Whether a biome takes cracks (the ocean does not: Art's crack for it is null).
static func takes_cracks(biome: String) -> bool:
	_load()
	var by = _d.get("by_biome", {})
	if by.has(biome) and by[biome].has("crack") and by[biome]["crack"] == null:
		return false
	return true


static func crack(biome: String) -> Color:
	_load()
	var by = _d.get("by_biome", {})
	return _hex(by.get(biome, {}).get("crack") if by.has(biome) else null, VfxLook.CRACK_CORE)


static func lip(biome: String) -> Color:
	_load()
	var by = _d.get("by_biome", {})
	return _hex(by.get(biome, {}).get("lip") if by.has(biome) else null, VfxLook.CRACK_LIP)
