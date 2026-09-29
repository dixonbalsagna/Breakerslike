class_name SpikeWrap
extends RefCounted
## Engine spike (throwaway, research only). GDScript port of the wrap math in shared/sim-ref.mjs.
## Portability contract: float64 scalars only (GDScript `float`), + - * / floor ceil fmod, JS expression order.
## Never use the engine vector types here: they are float32.

const W: float = 9600.0
const COL: int = 8
const NC: int = 1200
const HALF: float = 4800.0
const TPS: int = 60
const DT: float = 1.0 / 60.0   # folded at parse time; the same correctly rounded double as JS 1 / 60


## JS: ((x % W) + W) % W. JS % on numbers is fmod (sign of the dividend), exactly like C fmod().
## Named wrapx because wrap() is a Godot built-in.
static func wrapx(x: float) -> float:
	return fmod(fmod(x, W) + W, W)


## Signed shortest-arc distance from a to b, in (-HALF, HALF].
static func sdx(a: float, b: float) -> float:
	var d: float = fmod(b - a, W)
	if d > HALF:
		d -= W
	elif d < -HALF:
		d += W
	return d


## JS clamp: v < a ? a : v > b ? b : v (kept as written, not Godot's clampf, so NaN and -0 behave the same).
static func clampf_(v: float, a: float, b: float) -> float:
	if v < a:
		return a
	if v > b:
		return b
	return v


## Triangle wave in [0, 1] over an integer tick count: 0 at n = 0, 1 at n = period/2.
## int % int truncates like JS; convert to float BEFORE dividing (GDScript int / int truncates).
static func tri(n: int, period: int) -> float:
	var p: float = float(n % period) / float(period)
	if p < 0.5:
		return 2.0 * p
	return 2.0 - 2.0 * p
