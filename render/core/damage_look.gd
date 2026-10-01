class_name RenderDamage
extends RefCounted
## Art's battle-damage stages for the body shader (data/art/damage.json, written by art/concepts/damage/gen.mjs; the
## picture is art/concepts/damage/damage-stages.svg). Each outfit lists, for the stages scuffed, torn and ruined
## (the wounds' bruised, battered and broken), its layer ids: decals (shader layers), geometry (small mesh swaps,
## Animation's at equip) and silhouette (poses and missing parts, Animation's). A stage keeps the layers below it.
##
## The mannequin has no outfit meshes yet, so no id has a place of its own to go. What the ids say is what kind of
## mark an outfit shows at each stage and how much of it, and that is what the shader's layers take from them:
## - scuffs: decals named scuff_ or dent_, and hard damage in the geometry list (chip, cracked, dented, holes, gone);
## - bruises: decals named bruise_ (a _large one counts twice);
## - tears: geometry named torn, frayed, trailing or loose (torn_open and torn_wide count twice). They stand in for
##   the mesh swaps until those exist.
## Each unit is a share of the surface (SCUFF_SHARE, BRUISE_SHARE, TEAR_SHARE). Blood decals stay behind the graphic
## dial and are not drawn. Reads data only.

const PATH := "res://data/art/damage.json"
const SCUFF_SHARE: float = 0.07
const BRUISE_SHARE: float = 0.06
const TEAR_SHARE: float = 0.05
const SHARE_MAX: float = 0.55
## With no data, or an outfit it does not list: scuffs and bruises from the first stage, tears from the second.
const FALLBACK: Dictionary = {"scuff": Vector3(0.14, 0.3, 0.5), "bruise": Vector3(0.12, 0.24, 0.3), "tear": Vector3(0.0, 0.1, 0.25), "ids": []}

static var _data: Dictionary = {}
static var _loaded: bool = false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var v = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if v is Dictionary and v.get("fighters") is Dictionary:
		_data = v["fighters"]


## The outfits the data lists.
static func outfits() -> Array:
	_load()
	return _data.keys()


## An outfit's marks at wound stages 1, 2 and 3: {scuff, bruise, tear: Vector3 of surface shares, each stage
## including the ones below; ids: per stage, the layer ids it adds: {decals, geometry, silhouette}}.
static func marks(outfit: String) -> Dictionary:
	_load()
	var o = _data.get(outfit)
	if not (o is Dictionary):
		return FALLBACK
	var scuff := Vector3.ZERO
	var bruise := Vector3.ZERO
	var tear := Vector3.ZERO
	var ids: Array = []
	var su: float = 0.0
	var bu: float = 0.0
	var tu: float = 0.0
	for k in range(3):
		var st = o.get(str(k + 1), {})
		if not (st is Dictionary):
			st = {}
		ids.append({"decals": st.get("decals", []), "geometry": st.get("geometry", []), "silhouette": st.get("silhouette", [])})
		for id in st.get("decals", []):
			var d: String = str(id)
			if d.begins_with("bruise_"):
				bu += 2.0 if d.ends_with("_large") else 1.0
			elif d.begins_with("scuff_") or d.begins_with("dent_"):
				su += 1.0
		for id in st.get("geometry", []):
			var g: String = str(id)
			if g.contains("torn_open") or g.contains("torn_wide"):
				tu += 2.0
			elif g.contains("torn") or g.contains("frayed") or g.contains("trailing") or g.contains("loose"):
				tu += 1.0
			elif g.contains("chip") or g.contains("cracked") or g.contains("dented") or g.contains("holes") or g.contains("gone"):
				su += 1.0
		scuff[k] = minf(su * SCUFF_SHARE, SHARE_MAX)
		bruise[k] = minf(bu * BRUISE_SHARE, SHARE_MAX)
		tear[k] = minf(tu * TEAR_SHARE, SHARE_MAX)
	return {"scuff": scuff, "bruise": bruise, "tear": tear, "ids": ids}
