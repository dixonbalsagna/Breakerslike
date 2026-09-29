class_name SimDetMath
## Deterministic sin, cos, pow and hypot: the twin of detmath.js, expression for expression. Only + - * / sqrt floor,
## float64 throughout. The four long constants come from their bit patterns; the series coefficients are computed by
## IEEE division in the same order as detmath.js, so they match bit for bit (the golden vectors check all of them).

static var PIO2_1: float = SimMathx.f64("3ff921fb54400000")
static var PIO2_1T: float = SimMathx.f64("3dd0b4611a626331")
static var INVPIO2: float = 1.0 / (PIO2_1 + PIO2_1T)
static var LN2_HI: float = SimMathx.f64("3fe62e42fee00000")
static var LN2_LO: float = SimMathx.f64("3dea39ef35793c76")
static var INVLN2: float = 1.0 / (LN2_HI + LN2_LO)
static var SQRT2: float = sqrt(2.0)
static var SQRT_HALF: float = SQRT2 / 2.0
static var SIN_C := PackedFloat64Array()
static var COS_C := PackedFloat64Array()
static var EXP_C := PackedFloat64Array()
static var LOG_C := PackedFloat64Array()


static func _static_init() -> void:
	var s: float = 1.0
	var c: float = 1.0
	var e: float = 1.0
	for k in range(1, 12):
		s = s / float((2 * k) * (2 * k + 1))
		SIN_C.append(-s if k % 2 == 1 else s)
		c = c / float((2 * k - 1) * (2 * k))
		COS_C.append(-c if k % 2 == 1 else c)
	for n in range(1, 19):
		e = e / float(n)
		EXP_C.append(e)
	for k in range(1, 13):
		LOG_C.append(1.0 / float(2 * k + 1))


static func _ksin(r: float) -> float:
	var z: float = r * r
	var p: float = SIN_C[10]
	for k in range(9, -1, -1):
		p = SIN_C[k] + z * p
	return r + r * z * p


static func _kcos(r: float) -> float:
	var z: float = r * r
	var p: float = COS_C[10]
	for k in range(9, -1, -1):
		p = COS_C[k] + z * p
	return 1.0 + z * p


static func sin(x: float) -> float:
	var n: float = floor(x * INVPIO2 + 0.5)
	var r: float = (x - n * PIO2_1) - n * PIO2_1T
	var q: float = n - 4.0 * floor(n / 4.0)
	if q == 0.0:
		return _ksin(r)
	if q == 1.0:
		return _kcos(r)
	if q == 2.0:
		return -_ksin(r)
	return -_kcos(r)


static func cos(x: float) -> float:
	var n: float = floor(x * INVPIO2 + 0.5)
	var r: float = (x - n * PIO2_1) - n * PIO2_1T
	var q: float = n - 4.0 * floor(n / 4.0)
	if q == 0.0:
		return _kcos(r)
	if q == 1.0:
		return -_ksin(r)
	if q == 2.0:
		return -_kcos(r)
	return _ksin(r)


static func exp(x: float) -> float:
	var k: float = floor(x * INVLN2 + 0.5)
	var r: float = (x - k * LN2_HI) - k * LN2_LO
	var p: float = EXP_C[17]
	for i in range(16, -1, -1):
		p = EXP_C[i] + r * p
	var y: float = 1.0 + r * p
	var j: float = 0.0
	while j < k:
		y = y * 2.0
		j += 1.0
	j = 0.0
	while j > k:
		y = y / 2.0
		j -= 1.0
	return y


static func log(x: float) -> float:
	var m: float = x
	var e: float = 0.0
	while m >= SQRT2:
		m = m / 2.0
		e += 1.0
	while m < SQRT_HALF:
		m = m * 2.0
		e -= 1.0
	var s: float = (m - 1.0) / (m + 1.0)
	var z: float = s * s
	var p: float = LOG_C[11]
	for k in range(10, -1, -1):
		p = LOG_C[k] + z * p
	var lm: float = 2.0 * s + 2.0 * s * z * p
	return e * LN2_HI + (e * LN2_LO + lm)


static func pow(x: float, y: float) -> float:
	if y == 2.0:
		return x * x
	if y == 0.0 or x == 1.0:
		return 1.0
	if x == 0.0:
		return 0.0 if y > 0.0 else INF
	if x < 0.0:
		return NAN
	return SimDetMath.exp(y * SimDetMath.log(x))


static func hypot(x: float, y: float) -> float:
	return sqrt(x * x + y * y)
