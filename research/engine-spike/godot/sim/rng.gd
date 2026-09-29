class_name SpikeRng
extends RefCounted
## Engine spike (throwaway, research only). mulberry32, bit-identical to shared/sim-ref.mjs Rng.
## GDScript int is 64-bit signed. The state is kept as an unsigned 32-bit value in [0, 2^32): every
## result is masked with & 0xFFFFFFFF, and >> on a non-negative int64 is the same as JS >>> on 32 bits.
## Math.imul is built from 16-bit halves so no product exceeds 2^49 (no int64 overflow).

const MASK: int = 0xFFFFFFFF

var a: int = 0   # JS this.a, stored unsigned (JS keeps it signed; the 32 bits are the same)


func _init(seed: int = 0) -> void:
	a = seed & MASK


## Low 32 bits of x * y for x, y in [0, 2^32). Same bits as JS Math.imul.
static func imul(x: int, y: int) -> int:
	return (x * (y & 0xFFFF) + (((x * (y >> 16)) & 0xFFFF) << 16)) & MASK


func u32() -> int:
	a = (a + 0x6D2B79F5) & MASK
	var s: int = a
	# t = Math.imul(a ^ (a >>> 15), 1 | a)   (imul inlined: this is the hot path)
	var x: int = s ^ (s >> 15)
	var y: int = 1 | s
	var t: int = (x * (y & 0xFFFF) + (((x * (y >> 16)) & 0xFFFF) << 16)) & MASK
	# t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t   (JS ToInt32 of the sum = the sum mod 2^32)
	x = t ^ (t >> 7)
	y = 61 | t
	var m: int = (x * (y & 0xFFFF) + (((x * (y >> 16)) & 0xFFFF) << 16)) & MASK
	t = ((t + m) & MASK) ^ t
	# (t ^ (t >>> 14)) >>> 0
	return (t ^ (t >> 14)) & MASK


## u32() / 4294967296 in float64 (exact: a u32 fits in 53 bits, the divisor is a power of two).
func next() -> float:
	return float(u32()) / 4294967296.0


## JS range(lo, hi): lo + (hi - lo) * next(). Named range_ because range() is a Godot built-in.
func range_(lo: float, hi: float) -> float:
	return lo + (hi - lo) * next()


## JS state(): this.a >>> 0.
func state() -> int:
	return a
