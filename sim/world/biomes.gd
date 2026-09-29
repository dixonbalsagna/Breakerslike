class_name WorldBiomes
## Biome layout of the wrapped planet: the twin of biomes.js (SEG, biomeAt).

## [start, end, biome] spans of world x, in order, covering [0, W). Static data, never written.
const SEG: Array = [[0.0, 1200.0, "ocean"], [1200.0, 1800.0, "village"], [1800.0, 2350.0, "plains"], [2350.0, 3850.0, "city"], [3850.0, 4500.0, "village"], [4500.0, 5500.0, "forest"], [5500.0, 6500.0, "desert"], [6500.0, 7600.0, "mountains"], [7600.0, 8000.0, "village"], [8000.0, 8300.0, "plains"], [8300.0, 9600.0, "ocean"]]


static func biomeAt(x: float) -> String:
	x = SimWrap.wrap(x)
	for s in SEG:
		if x >= s[0] and x < s[1]:
			return s[2]
	return "plains"
