class_name WorldBlast
## What an energy shot does to the world where it ends (docs/world/ground-contact.md section 23; SimShots.hitWorld calls this): a
## crater in the ground, the structures around the point, a splash in water. Numbers are data (data/biomes/blast.json) by shot
## kind and by the shooter's tier. Pure function of the shot's end and the world: nothing is drawn from S.rng, so it is replay-safe.
## The blast reaches buildings through damageArea, so the tier's structure reach (reachStructure) and the casualty window apply as for
## any impact; a shot that dodged a fighter and flew on ends here exactly as one that missed.

const PATH: String = "res://data/biomes/blast.json"
const SCHEMA: String = "biomes.blast/1"
static var _d: Dictionary = {}
static var _errors: Array = []
static var _loaded: bool = false
static var _hash: String = ""


static func data() -> Dictionary:
	if not _loaded:
		_load()
	return _d


static func errors() -> Array:
	if not _loaded:
		_load()
	return _errors


static func dataHash() -> String:
	if not _loaded:
		_load()
	return _hash


static func _load() -> void:
	_loaded = true
	_errors = []
	_d = {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		_errors.append("blast.json: cannot open " + PATH)
		return
	var j = JSON.parse_string(f.get_as_text())
	if not (j is Dictionary) or j.get("schema", "") != SCHEMA:
		_errors.append("blast.json: not a %s object" % SCHEMA)
		return
	for k in ["kinds", "tierEnergy", "tierDamage"]:
		if not j.has(k):
			_errors.append("blast.json: missing " + k)
	var h := SimHash.Hasher.new()
	h.text("biomes.blast")
	FighterData._canon(h, j)
	_hash = h.hex()
	if _errors.is_empty():
		_d = j


## A shot of the given kind, fired by slot, ended at (x, y, z) moving at (vx, vy) units a second, against the ground (cause "ground") or the
## water (cause "water"). Returns {"crater": the record or null, "levelled": buildings levelled}.
static func shotHit(S: SimState, slot: int, kind: String, x: float, y: float, z: float, vx: float, vy: float, cause: String) -> Dictionary:
	var res := {"crater": null, "levelled": 0}
	var D: Dictionary = data()
	if D.is_empty() or not D.kinds.has(kind) or slot < 0 or slot >= S.fighters.size():
		return res
	var k: Dictionary = D.kinds[kind]
	var f = S.fighters[slot]
	var ti: int = clampi(int(f.tier), 1, 4) - 1
	if cause == "water":
		SimFx.splash(S, x, y, int(k.splash), z)
		SimFx.ring(S, x, y, float(k.ringR), "#bfe6ff", 0.4, 8.0, z)
		return res
	var g: float = WorldTerrain.groundY(S, x, z)
	var sp: float = maxf(SimDetMath.hypot(vx, vy), 0.000001)
	var E: float = float(k.craterE) * float(D.tierEnergy[ti])
	res.crater = WorldCrater.dig(S, x, E, f, "impact", vx / sp, absf(vy) / sp, false, z)
	SimFx.debris(S, x, g + 8.0, int(k.debris), "#6d6a66", 500.0, z)
	SimFx.dust(S, x, g, int(k.dust), "", z)
	SimFx.ring(S, x, g + 10.0, float(k.ringR), "#ffffff", 0.35, 8.0, z)
	SimFx.shake(S, float(k.shake), x, z)
	res.levelled = WorldStructures.damageArea(S, x, g + 5.0, float(k.radius), float(k.damage) * float(D.tierDamage[ti]), f)
	return res
