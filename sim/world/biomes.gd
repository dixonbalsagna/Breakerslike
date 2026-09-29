class_name WorldBiomes
## Biome layout of the wrapped planet: the twin of biomes.js (SEG, biomeAt).

## [start, end, biome] spans of world x, in order, covering [0, W): the original spans times the planet scale. Static data.
const P: float = SimConst.PS
const SEG: Array = [[0.0 * P, 1200.0 * P, "ocean"], [1200.0 * P, 1800.0 * P, "village"], [1800.0 * P, 2350.0 * P, "plains"], [2350.0 * P, 3850.0 * P, "city"], [3850.0 * P, 4500.0 * P, "village"], [4500.0 * P, 5500.0 * P, "forest"], [5500.0 * P, 6500.0 * P, "desert"], [6500.0 * P, 7600.0 * P, "mountains"], [7600.0 * P, 8000.0 * P, "village"], [8000.0 * P, 8300.0 * P, "plains"], [8300.0 * P, 9600.0 * P, "ocean"]]


static func biomeAt(x: float) -> String:
	x = SimWrap.wrap(x)
	for s in SEG:
		if x >= s[0] and x < s[1]:
			return s[2]
	return "plains"
