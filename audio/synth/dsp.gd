class_name AudioDsp
extends RefCounted
## The small DSP toolkit behind the procedural sound bank. A buffer is a PackedFloat32Array of mono samples at a
## known rate. Everything here is a pure function of its arguments and a seed (an xorshift32 stream of its own, never
## the sim's), so a sound is the same on every machine and every run. Nothing here touches the sim.
##
## Envelope convention: t60 is the time an envelope takes to fall 60 dB, so it reads as "how long it rings".

const LN60: float = 6.907755278982137   # ln(1000): amplitude ratio for 60 dB
const BLOCK: int = 32                   # samples between filter coefficient refreshes while a cutoff glides


## A non-zero xorshift32 state from any integer seed.
static func state_of(sd: int) -> int:
	var s: int = sd & 0xFFFFFFFF
	return s if s != 0 else 0x9E3779B9


## A tiny seeded stream for values drawn a few at a time (grain times, per-variant jitter). Same algorithm as noise().
class Rand:
	var s: int = 1

	func _init(sd: int = 1) -> void:
		s = AudioDsp.state_of(sd)

	## A number in [0, 1).
	func next() -> float:
		s ^= (s << 13) & 0xFFFFFFFF
		s ^= s >> 17
		s ^= (s << 5) & 0xFFFFFFFF
		return float(s) * (1.0 / 4294967296.0)

	func range_(lo: float, hi: float) -> float:
		return lo + (hi - lo) * next()

	## A factor 1 +/- spread.
	func pm(spread: float) -> float:
		return 1.0 + spread * (next() * 2.0 - 1.0)


## White noise in [-1, 1).
static func noise(n: int, sd: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var s: int = state_of(sd)
	for i in range(n):
		s ^= (s << 13) & 0xFFFFFFFF
		s ^= s >> 17
		s ^= (s << 5) & 0xFFFFFFFF
		out[i] = float(s) * (1.0 / 2147483648.0) - 1.0
	return out


static func db_to_lin(db: float) -> float:
	return pow(10.0, db / 20.0)


## Biquad filter, in place. kind is "lp", "hp" or "bp" (constant 0 dB peak gain). The cutoff glides from f0 to f1 with
## time constant tau seconds (f0 == f1, or tau <= 0: fixed). RBJ cookbook coefficients.
static func filter(buf: PackedFloat32Array, kind: String, f0: float, f1: float, tau: float, q: float, rate: int) -> void:
	var n: int = buf.size()
	var fs: float = float(rate)
	var glide: bool = tau > 0.0 and absf(f1 - f0) > 0.001
	var ceiling: float = fs * 0.45
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	var start: int = 0
	while start < n:
		var stop: int = mini(start + BLOCK, n) if glide else n
		var fc: float = f0
		if glide:
			fc = f1 + (f0 - f1) * exp(-(float(start) / fs) / tau)
		fc = clampf(fc, 15.0, ceiling)
		var w0: float = TAU * fc / fs
		var cw: float = cos(w0)
		var alpha: float = sin(w0) / (2.0 * maxf(q, 0.05))
		var a0: float = 1.0 + alpha
		var a1: float = -2.0 * cw / a0
		var a2: float = (1.0 - alpha) / a0
		var b0: float
		var b1: float
		var b2: float
		match kind:
			"hp":
				b0 = (1.0 + cw) * 0.5 / a0
				b1 = -(1.0 + cw) / a0
				b2 = b0
			"bp":
				b0 = alpha / a0
				b1 = 0.0
				b2 = -b0
			_:
				b0 = (1.0 - cw) * 0.5 / a0
				b1 = (1.0 - cw) / a0
				b2 = b0
		for i in range(start, stop):
			var x0: float = buf[i]
			var y0: float = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
			x2 = x1
			x1 = x0
			y2 = y1
			y1 = y0
			buf[i] = y0
		start = stop


## Soft saturation, in place: tanh(drive x) / tanh(drive). drive <= 0 leaves the buffer alone.
static func saturate(buf: PackedFloat32Array, drive: float) -> void:
	if drive <= 0.0:
		return
	var norm: float = 1.0 / tanh(drive)
	for i in range(buf.size()):
		buf[i] = tanh(drive * buf[i]) * norm


static func peak(buf: PackedFloat32Array) -> float:
	var p: float = 0.0
	for i in range(buf.size()):
		var a: float = absf(buf[i])
		if a > p:
			p = a
	return p


static func rms(buf: PackedFloat32Array) -> float:
	if buf.is_empty():
		return 0.0
	var s: float = 0.0
	for i in range(buf.size()):
		s += buf[i] * buf[i]
	return sqrt(s / float(buf.size()))


## Scale so the largest sample is target (linear). A silent buffer stays silent.
static func normalize(buf: PackedFloat32Array, target: float) -> void:
	var p: float = peak(buf)
	if p < 1e-9:
		return
	var k: float = target / p
	for i in range(buf.size()):
		buf[i] *= k


## Remove DC with a one-pole high-pass at fc Hz (in place).
static func dc_block(buf: PackedFloat32Array, fc: float, rate: int) -> void:
	var r: float = exp(-TAU * fc / float(rate))
	var x1: float = 0.0
	var y1: float = 0.0
	for i in range(buf.size()):
		var x0: float = buf[i]
		var y0: float = x0 - x1 + r * y1
		x1 = x0
		y1 = y0
		buf[i] = y0


## Short linear fades at both ends so a sound never starts or stops on a click.
static func fade(buf: PackedFloat32Array, fade_in: float, fade_out: float, rate: int) -> void:
	var n: int = buf.size()
	var ni: int = mini(int(fade_in * rate), n)
	var no: int = mini(int(fade_out * rate), n)
	for i in range(ni):
		buf[i] *= float(i) / float(ni)
	for i in range(no):
		buf[n - 1 - i] *= float(i) / float(no)


## Add src into dst starting at sample offset at (dst grows if needed), scaled by gain.
static func mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, at: int, gain: float) -> void:
	var need: int = at + src.size()
	if dst.size() < need:
		dst.resize(need)
	for i in range(src.size()):
		dst[at + i] += src[i] * gain


## Wrap a mono buffer as a 16-bit AudioStreamWAV (a runtime stream, or saveable with save_to_wav).
static func to_wav(buf: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in range(buf.size()):
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	w.data = data
	return w
