class_name SimRng
extends RefCounted
## Seeded random stream: mulberry32, bit-identical to rng.js. GDScript ints are 64-bit, so the state is kept as its
## 32 bits unsigned and every step is masked; Math.imul is built from 16-bit halves so no product passes 2^49.

const MASK: int = 0xFFFFFFFF

var a: int = 0   # the 32 state bits (rng.js keeps the same bits as a signed int)


func _init(seed: int = 0) -> void:
	a = seed & MASK


## Low 32 bits of x * y for x, y in [0, 2^32): the bits of JS Math.imul.
static func imul(x: int, y: int) -> int:
	return (x * (y & 0xFFFF) + (((x * (y >> 16)) & 0xFFFF) << 16)) & MASK


## rng.js next(r): a number in [0, 1).
func next() -> float:
	a = (a + 0x6D2B79F5) & MASK
	var t: int = imul(a ^ (a >> 15), 1 | a)
	t = ((t + imul(t ^ (t >> 7), 61 | t)) & MASK) ^ t
	return float((t ^ (t >> 14)) & MASK) / 4294967296.0


## rng.js range(r, lo, hi) (range is a GDScript built-in, hence the underscore).
func range_(lo: float, hi: float) -> float:
	return lo + (hi - lo) * next()


## The state as rng.js reports it (r.a | 0): signed 32-bit.
func state_i32() -> int:
	return a - 0x100000000 if a >= 0x80000000 else a


## rng.js deriveSeed: the seed of a cosmetic stream, fmix32(matchSeed ^ fnv1a32(id)) (canonical RNG rule).
static func deriveSeed(seed: int, id: String) -> int:
	var h: int = 0x811c9dc5
	for i in range(id.length()):
		h = imul((h ^ id.unicode_at(i)) & MASK, 0x01000193)
	var x: int = (seed ^ h) & MASK
	x ^= x >> 16
	x = imul(x, 0x85ebca6b)
	x ^= x >> 13
	x = imul(x, 0xc2b2ae35)
	x ^= x >> 16
	return x & MASK
