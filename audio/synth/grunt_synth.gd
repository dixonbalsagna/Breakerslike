class_name GruntSynth
extends RefCounted
## A source-filter voice for grunts, growls and efforts (Orb: lines are unvoiced text carried by each character's own
## grunts). A glottal pulse train with a falling pitch, plus breath noise, runs through three time-varying formant
## resonators (the vowel gliding from vowel_a to vowel_b) and a fixed fourth. Then a chest resonance, saturation and a
## peak normalise. No recording and no sample: the vowel formants are the published average male values, and every
## number is in data/grunts.json.
##
## Recipe keys (times in seconds, frequencies in Hz):
##   dur          clip length
##   f0           [start, end] pitch; it settles from start to end with time constant f0_tau
##   f0_jitter    random pitch wobble per cycle (fraction); shimmer is the same for loudness
##   open, fry    open quotient of the glottal pulse (lower = pressed, brighter); fry = every other cycle quieter
##   vowel_a/b    {f: [F1, F2, F3], bw: [B1, B2, B3]}; glide = [start, end] of the a -> b move
##   breath       aspiration noise level; h_onset = the length of the breathy "h" before the voice
##   attack, hold, t60   the voiced envelope: ramp, flat part, then a fall of 60 dB in t60
##   chest        {f, bw, gain}: a low resonance on the raw source for body
##   drive        saturation on the way out
const UPDATE: int = 16          # samples between resonator coefficient refreshes
const F4: float = 3300.0        # the fixed fourth formant
const B4: float = 250.0


## One variant of a gesture as a mono buffer. jit widens each variant a little (pitch, formants, length).
static func render(def: Dictionary, bank_seed: int, id: String, variant: int) -> PackedFloat32Array:
	var rate: int = int(def.get("rate", 24000))
	var fs: float = float(rate)
	var sd: int = SimRng.deriveSeed(bank_seed, "audio.bank." + id + "." + str(variant))
	var rnd := AudioDsp.Rand.new(sd)
	var jit: Dictionary = def.get("jitter", {})
	var jf0: float = rnd.pm(float(jit.get("f0", 0.0)))
	var jfm: float = float(jit.get("formant", 0.0))
	var jd: float = rnd.pm(float(jit.get("dur", 0.0)))

	var dur: float = float(def.dur) * jd
	var n: int = int(dur * fs)
	var out := PackedFloat32Array()
	out.resize(n)
	var noise: PackedFloat32Array = AudioDsp.noise(n, SimRng.deriveSeed(sd, "breath"))

	var f0a: float = float(def.f0[0]) * jf0
	var f0b: float = float(def.f0[1]) * jf0
	var f0_tau: float = maxf(float(def.get("f0_tau", 0.1)), 0.005)
	var jitter: float = float(def.get("f0_jitter", 0.0))
	var shimmer: float = float(def.get("shimmer", 0.0))
	var oq: float = clampf(float(def.get("open", 0.6)), 0.3, 0.9)
	var fry: float = float(def.get("fry", 0.0))
	var va: Dictionary = def.vowel_a
	var vb: Dictionary = def.vowel_b
	var fa := PackedFloat64Array()
	var fb := PackedFloat64Array()
	for i in range(3):
		var kf: float = rnd.pm(jfm)
		fa.append(float(va.f[i]) * kf)
		fb.append(float(vb.f[i]) * kf)
	var glide: Array = def.get("glide", [0.0, dur])
	var g0: float = float(glide[0])
	var g1: float = maxf(float(glide[1]), g0 + 0.001)
	var breath: float = float(def.get("breath", 0.0))
	var h_on: float = maxf(float(def.get("h_onset", 0.03)), 0.002)
	var attack: float = maxf(float(def.get("attack", 0.005)), 0.001)
	var hold: float = float(def.get("hold", 0.05))
	var t60: float = float(def.t60)
	var delay: float = h_on * 0.4    # the voice starts a little after the breath does
	var chest: Dictionary = def.get("chest", {})
	var chest_gain: float = float(chest.get("gain", 0.0))
	var dec: float = exp(-AudioDsp.LN60 / (fs * t60))

	# Resonator state: three moving formants, the fixed fourth, and the chest.
	var y1 := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
	var y2 := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
	var ca := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
	var cb := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
	var cc := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
	_resonator(3, F4, B4, fs, ca, cb, cc)
	if chest_gain > 0.0:
		_resonator(4, float(chest.f), float(chest.get("bw", 120.0)), fs, ca, cb, cc)

	var phase: float = 0.0
	var g_prev: float = 0.0
	var cycles: int = 0
	var cyc_f: float = 1.0
	var cyc_a: float = 1.0
	var cyc_fry: float = 1.0
	var f_settle: float = 1.0
	var f_step: float = exp(-1.0 / (fs * f0_tau))
	var body_amp: float = 1.0
	var t_body: float = attack + hold

	for i in range(n):
		var t: float = float(i) / fs
		if i % UPDATE == 0:
			var s: float = smoothstep(g0, g1, t)
			for m in range(3):
				var F: float = lerpf(fa[m], fb[m], s)
				var B: float = lerpf(float(va.bw[m]), float(vb.bw[m]), s)
				_resonator(m, F, B, fs, ca, cb, cc)
		# voiced envelope: silent through the breath's lead, ramp, hold, then fall
		var tv: float = t - delay
		var ve: float = 0.0
		if tv > 0.0:
			if tv < attack:
				ve = tv / attack
			elif tv < t_body:
				ve = 1.0
			else:
				ve = body_amp
				body_amp *= dec
		# glottal pulse train: differentiated Rosenberg-style flow, per-cycle jitter, shimmer and creak
		var f0: float = (f0b + (f0a - f0b) * f_settle) * cyc_f
		f_settle *= f_step
		phase += f0 / fs
		if phase >= 1.0:
			phase -= 1.0
			cycles += 1
			cyc_f = 1.0 + jitter * (rnd.next() * 2.0 - 1.0)
			cyc_a = 1.0 + shimmer * (rnd.next() * 2.0 - 1.0)
			cyc_fry = (1.0 - fry) if (cycles & 1) == 1 else 1.0
		var g: float = _glottal(phase, oq)
		var src: float = (g - g_prev) * (fs / maxf(f0, 20.0)) * cyc_a * cyc_fry * ve
		g_prev = g
		# breath: loudest in the "h" lead, a whisper of it through the vowel
		var ne: float = breath * (exp(-t / h_on) + 0.35 * ve)
		var x: float = src + noise[i] * ne * 3.0
		# cascade of the four formants
		var y: float = x
		for m in range(4):
			var yn: float = ca[m] * y + cb[m] * y1[m] + cc[m] * y2[m]
			y2[m] = y1[m]
			y1[m] = yn
			y = yn
		# chest: a low resonance fed by the raw voiced source
		if chest_gain > 0.0:
			var xc: float = src
			var ync: float = ca[4] * xc + cb[4] * y1[4] + cc[4] * y2[4]
			y2[4] = y1[4]
			y1[4] = ync
			y += ync * chest_gain
		out[i] = y

	# Level first, then saturate (drive is relative to full scale), then set the final peak.
	AudioDsp.dc_block(out, 30.0, rate)
	AudioDsp.normalize(out, 1.0)
	AudioDsp.saturate(out, float(def.get("drive", 0.0)))
	AudioDsp.dc_block(out, 30.0, rate)
	AudioDsp.normalize(out, AudioDsp.db_to_lin(float(def.get("peak_db", -5.0))))
	AudioDsp.fade(out, 0.002, 0.012, rate)
	return out


## Klatt-style two-pole resonator with unity gain at DC: y = a x + b y1 + c y2.
static func _resonator(slot: int, f: float, bw: float, fs: float, ca: PackedFloat64Array, cb: PackedFloat64Array, cc: PackedFloat64Array) -> void:
	var c: float = -exp(-TAU * bw / fs)
	var b: float = 2.0 * exp(-PI * bw / fs) * cos(TAU * f / fs)
	cc[slot] = c
	cb[slot] = b
	ca[slot] = 1.0 - b - c


## One period of glottal flow at phase in [0, 1): a raised-cosine rise over 70% of the open phase, a quarter-cosine
## fall over the rest, then closed.
static func _glottal(phase: float, oq: float) -> float:
	var rise: float = 0.7 * oq
	if phase < rise:
		return 0.5 * (1.0 - cos(PI * phase / rise))
	if phase < oq:
		return cos(0.5 * PI * (phase - rise) / (oq - rise))
	return 0.0
