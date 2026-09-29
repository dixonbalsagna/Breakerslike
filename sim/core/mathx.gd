class_name SimMathx
## JavaScript-exact helpers. GDScript's built-ins differ from JS on signed zeros and ties, and the golden hashes see
## every bit: sign(-0.0) is +0 (JS keeps -0); max and min pick a zero by argument order (JS max prefers +0, min
## prefers -0); round() rounds halves away from zero (JS rounds them up). Use these wherever the JS core uses Math.*.


## mathx.js clamp.
static func jclamp(v: float, a: float, b: float) -> float:
	return a if v < a else (b if v > b else v)


## Math.max(a, b).
static func jmax(a: float, b: float) -> float:
	if a > b:
		return a
	if b > a:
		return b
	if a != a or b != b:
		return NAN
	return a + b if a == 0.0 else a   # equal zeros: (+0)+(-0) is +0, (-0)+(-0) is -0


## Math.min(a, b).
static func jmin(a: float, b: float) -> float:
	if a < b:
		return a
	if b < a:
		return b
	if a != a or b != b:
		return NAN
	return -((-a) + (-b)) if a == 0.0 else a   # equal zeros: -0 if either is -0


## Math.sign(x): keeps -0 and NaN.
static func jsign(x: float) -> float:
	if x > 0.0:
		return 1.0
	if x < 0.0:
		return -1.0
	return x


## Math.round(x): the nearest integer, halves toward +infinity.
static func jround(x: float) -> float:
	var r: float = floor(x)
	return r + 1.0 if x - r >= 0.5 else r


## String(x) for the integer-valued numbers the sim puts into text (feed lines, banners, damage numbers).
static func jstr(x: float) -> String:
	if x == floor(x) and absf(x) < 1e15:
		return str(int(x))
	push_error("jstr: non-integer %s has no exact JS formatting here" % x)
	return str(x)


## A float64 from its bit pattern, 16 hex digits with the high word first. GDScript's literal parser is not
## correctly rounded for long literals, so long constants are built this way.
static func f64(hex: String) -> float:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_u32(0, hex.substr(8, 8).hex_to_int())
	b.encode_u32(4, hex.substr(0, 8).hex_to_int())
	return b.decode_double(0)


## The bit pattern of x, 16 hex digits with the high word first.
static func bits(x: float) -> String:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	return "%08x%08x" % [b.decode_u32(4), b.decode_u32(0)]
