class_name SimWrap
## Wrapped-planet math: the twin of wrap.js. Keep the exact formulas: wrap() adds W before the second fmod, which
## rounds in-range non-integers in their last bits, and every port must reproduce that (sim/README.md, bug 12).


## Any real x mapped into [0, W).
static func wrap(x: float) -> float:
	return fmod(fmod(x, SimConst.W) + SimConst.W, SimConst.W)


## Signed shortest-arc displacement from a to b, in [-HALF, HALF].
static func sdx(a: float, b: float) -> float:
	var d: float = fmod(b - a, SimConst.W)
	if d > SimConst.HALF:
		d -= SimConst.W
	elif d < -SimConst.HALF:
		d += SimConst.W
	return d
