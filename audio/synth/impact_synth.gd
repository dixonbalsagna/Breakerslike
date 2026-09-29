class_name ImpactSynth
extends RefCounted
## Renders an impact, crash or debris sound from a recipe in data/impacts.json: a list of layers summed, saturated and
## normalised. Layer types:
##   tone    a sine that glides from f to f_to (time constant tau) with optional 2nd and 3rd harmonics and saturation.
##           The pitch drop is what gives a hit its body; the harmonics keep it audible on small speakers.
##   noise   filtered white noise ("hp", "lp", "bp", or "none"), the cutoff optionally gliding f -> f_to.
##   rumble  low-passed noise with a slow swell, optionally wobbled: a rolling, distant sound.
##   grains  a scatter of short damped rings (pebbles, plaster, falling rock). The rate starts at rate0 grains a second
##           and falls with time constant tau; each grain has a random pitch in [f0, f1] Hz.
## Every layer is normalised to a peak of 1 and then scaled by its gain, so gain reads as a relative level.
## Times are seconds, frequencies Hz. A recipe's "jitter" widens each variant a little (pitch, decay, level).


## Render one variant of a recipe to a mono buffer at recipe.rate. bank_seed and id pick the noise; variant picks jitter.
static func render(recipe: Dictionary, bank_seed: int, id: String, variant: int) -> PackedFloat32Array:
	var rate: int = int(recipe.get("rate", 32000))
	var sd: int = SimRng.deriveSeed(bank_seed, "audio.bank." + id + "." + str(variant))
	var rnd := AudioDsp.Rand.new(sd)
	var jit: Dictionary = recipe.get("jitter", {})
	var jf: float = float(jit.get("f", 0.0))
	var jt: float = float(jit.get("t60", 0.0))
	var jg: float = float(jit.get("gain", 0.0))
	var mix := PackedFloat32Array()
	var k: int = 0
	for L in recipe.layers:
		var P: Dictionary = L.duplicate()
		for key in ["f", "f_to", "lp"]:
			if P.has(key):
				P[key] = _scaled(P[key], rnd.pm(jf))
		if P.has("t60"):
			P["t60"] = float(P["t60"]) * rnd.pm(jt)
		P["gain"] = float(P.get("gain", 1.0)) * rnd.pm(jg)
		var buf: PackedFloat32Array = _layer(P, rate, SimRng.deriveSeed(sd, "layer" + str(k)))
		AudioDsp.mix_into(mix, buf, int(float(P.get("at", 0.0)) * rate), float(P["gain"]))
		k += 1
	AudioDsp.saturate(mix, float(recipe.get("drive", 0.0)))
	AudioDsp.dc_block(mix, 20.0, rate)
	AudioDsp.normalize(mix, AudioDsp.db_to_lin(float(recipe.get("peak_db", -3.0))))
	AudioDsp.fade(mix, 0.0004, 0.008, rate)
	return mix


static func _scaled(v, k: float):
	if typeof(v) == TYPE_ARRAY:
		return [float(v[0]) * k, float(v[1]) * k]
	return float(v) * k


static func _layer(P: Dictionary, rate: int, sd: int) -> PackedFloat32Array:
	var buf: PackedFloat32Array
	match String(P.type):
		"tone":
			buf = _tone(P, rate)
		"noise":
			buf = _noise(P, rate, sd)
		"rumble":
			buf = _rumble(P, rate, sd)
		"grains":
			buf = _grains(P, rate, sd)
		_:
			push_warning("ImpactSynth: unknown layer type '%s'" % String(P.type))
			buf = PackedFloat32Array()
	AudioDsp.normalize(buf, 1.0)
	return buf


static func _length(P: Dictionary, rate: int) -> int:
	var t60: float = float(P.get("t60", 0.1))
	return int((float(P.get("attack", 0.0)) + t60 * 1.05) * rate)


static func _tone(P: Dictionary, rate: int) -> PackedFloat32Array:
	var n: int = _length(P, rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var fs: float = float(rate)
	var f0: float = float(P.f)
	var f1: float = float(P.get("f_to", f0))
	var tau: float = maxf(float(P.get("tau", 0.05)), 0.001)
	var attack: float = float(P.get("attack", 0.001))
	var h2: float = float(P.get("h2", 0.0))
	var h3: float = float(P.get("h3", 0.0))
	var dec: float = exp(-AudioDsp.LN60 / (fs * float(P.t60)))
	var glide: float = exp(-1.0 / (fs * tau))
	var phase: float = 0.0
	var gl: float = 1.0
	var amp: float = 1.0
	for i in range(n):
		var f: float = f1 + (f0 - f1) * gl
		gl *= glide
		phase += TAU * f / fs
		var e: float = amp
		var t: float = float(i) / fs
		if t < attack:
			e *= t / attack
		amp *= dec
		out[i] = (sin(phase) + h2 * sin(2.0 * phase) + h3 * sin(3.0 * phase)) * e
	AudioDsp.saturate(out, float(P.get("drive", 0.0)))
	return out


static func _noise(P: Dictionary, rate: int, sd: int) -> PackedFloat32Array:
	var n: int = _length(P, rate)
	var out: PackedFloat32Array = AudioDsp.noise(n, sd)
	var kind: String = String(P.get("filter", "none"))
	if kind != "none":
		var f0: float = float(P.f)
		AudioDsp.filter(out, kind, f0, float(P.get("f_to", f0)), float(P.get("tau", 0.0)), float(P.get("q", 0.7)), rate)
	_envelope(out, float(P.get("attack", 0.0005)), float(P.t60), rate)
	return out


static func _rumble(P: Dictionary, rate: int, sd: int) -> PackedFloat32Array:
	var n: int = _length(P, rate)
	var out: PackedFloat32Array = AudioDsp.noise(n, sd)
	var lp: float = float(P.lp)
	AudioDsp.filter(out, "lp", lp, lp, 0.0, 0.7, rate)
	AudioDsp.filter(out, "lp", lp, lp, 0.0, 0.7, rate)
	_envelope(out, float(P.get("attack", 0.02)), float(P.t60), rate)
	var wob: float = float(P.get("wobble", 0.0))
	if wob > 0.0:
		var w: float = TAU * float(P.get("wobble_hz", 7.0)) / float(rate)
		for i in range(n):
			out[i] *= 1.0 + wob * sin(w * float(i))
	return out


## Linear attack, then an exponential decay that reaches -60 dB at t60 (in place).
static func _envelope(buf: PackedFloat32Array, attack: float, t60: float, rate: int) -> void:
	var fs: float = float(rate)
	var dec: float = exp(-AudioDsp.LN60 / (fs * t60))
	var amp: float = 1.0
	var na: int = int(attack * fs)
	for i in range(buf.size()):
		var e: float = amp
		if i < na:
			e *= float(i) / float(na)
		amp *= dec
		buf[i] *= e


static func _grains(P: Dictionary, rate: int, sd: int) -> PackedFloat32Array:
	var fs: float = float(rate)
	var length: float = float(P.get("len", 1.0))
	var t60: float = float(P.t60)
	var n: int = int((length + t60) * fs)
	var out := PackedFloat32Array()
	out.resize(n)
	var rnd := AudioDsp.Rand.new(sd)
	var rate0: float = float(P.rate0)
	var tau: float = maxf(float(P.get("tau", 0.5)), 0.001)
	var flo: float = float(P.f[0])
	var fhi: float = float(P.f[1])
	var click: float = float(P.get("click", 0.5))
	var per_sample: float = rate0 / fs
	var fall: float = exp(-1.0 / (fs * tau))
	var p: float = per_sample
	var glen: int = int(t60 * 1.1 * fs)
	for i in range(int(length * fs)):
		if rnd.next() < p:
			var f: float = flo * pow(fhi / flo, rnd.next())
			var a: float = 0.15 + 0.85 * pow(rnd.next(), 2.0)
			var gt60: float = t60 * (0.6 + 0.8 * rnd.next())
			var w: float = TAU * f / fs
			var gd: float = exp(-AudioDsp.LN60 / (fs * gt60))
			var amp: float = a
			var m: int = mini(glen, n - i)
			for j in range(m):
				out[i + j] += amp * sin(w * float(j))
				amp *= gd
			for j in range(mini(3, m)):
				out[i + j] += click * a * (rnd.next() * 2.0 - 1.0)
		p *= fall
	return out
