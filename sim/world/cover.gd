class_name WorldCover
## Hiding cover: the twin of cover.js (nearTree, coverAt, nearestCover).


static func nearTree(S: SimState, x: float) -> bool:
	for t in S.trees:
		if t.alive and absf(SimWrap.sdx(x, t.x)) < 120.0:
			return true
	return false


## Deep water (the sea or a lake a crater filled), low among standing forest trees, or low on a mountain; null when the
## fighter is in the open.
static func coverAt(S: SimState, f):
	var g: float = WorldTerrain.groundY(S, f.x)
	var b: String = WorldBiomes.biomeAt(f.x)
	var ws: float = WorldWater.surfaceAt(S, f.x)
	if f.y < ws - WorldWater.HIDE_BELOW_SURFACE and ws - g >= WorldWater.HIDE_MIN_DEPTH:
		return "submerged"
	if b == "forest" and f.y < g + 70.0 and nearTree(S, f.x):
		return "canopy"
	if b == "mountains" and f.y < g + 40.0:
		return "ridge"
	return null


## Nearest cover biome in 100-unit steps out to 4000, right before left; {"off", "b"} or null. Static layout only.
static func nearestCover(x: float):
	var off: float = 0.0
	while off <= 4000.0:
		for s in ([1.0, -1.0] if off != 0.0 else [1.0]):
			var b: String = WorldBiomes.biomeAt(x + s * off)
			if b == "ocean" or b == "forest" or b == "mountains":
				return {"off": s * off, "b": b}
		off += 100.0
	return null
