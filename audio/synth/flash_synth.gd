class_name FlashSynth
extends RefCounted
## Renders the short cue for a head flash (art/concepts/marked-aura/flashes.json) from data/flash_cues.json. The recipe
## is the same for every fighter; the family (circles, blades, wedges, steps: the fighter's shape family) sets only the
## timbre, so each fighter's flashes sound like that fighter and the twelve stay distinct from one another.
##
## Layer types: note (a pitched tone with a glide, vibrato and its own envelope), tick (a woody knock), breath
## (filtered noise with an optional tremolo: sweeps, inhales, shivers), thump (a low pulse: a heartbeat), growl (a low
## fry with a swell that is cut off). Pitches are semitones from the family's root; a `semi` may be a dictionary keyed by
## family (the surge's closing chord differs per family).


static func render(def: Dictionary, fam: Dictionary, fam_id: String, rate: int, bank_seed: int, id: String) -> PackedFloat32Array:
	var mix := PackedFloat32Array()
	var sd: int = SimRng.deriveSeed(bank_seed, "audio.bank.flash." + id + "." + fam_id)
	var k: int = 0
	var pulse: Dictionary = def.get("pulse", {})
	var period: float = float(pulse.get("on", 0.0)) + float(pulse.get("off", 0.0))
	for L in def.layers:
		var buf: PackedFloat32Array
		match String(L.type):
			"note": buf = _note(L, fam, fam_id, rate)
			"tick": buf = _tick(L, fam, rate, sd + k)
			"breath": buf = _breath(L, rate, sd + k)
			"thump": buf = _thump(L, rate)
			"growl": buf = _growl(L, fam, rate, sd + k)
			_: buf = PackedFloat32Array()
		var at: float = float(L.get("at", 0.0)) + float(L.get("at_pulse", 0)) * period
		if bool(L.get("pulsed", false)) and not pulse.is_empty():
			_pulse(buf, pulse, float(L.get("floor", 0.2)), float(def.get("grow", 0.0)), at, rate)
		AudioDsp.mix_into(mix, buf, int(at * rate), float(L.get("level", 1.0)))
		k += 1
	if int(fam.bits) > 0:
		var q: float = pow(2.0, float(fam.bits) - 1.0)
		for i in range(mix.size()):
			mix[i] = roundf(mix[i] * q) / q if absf(mix[i]) > 1.0 / q else mix[i]
	var max_s: float = float(def.get("max_s", 0.0))
	if not pulse.is_empty():
		max_s = float(pulse.count) * float(pulse.on) + float(int(pulse.count) - 1) * float(pulse.off) + float(pulse.fade)
	var max_n: int = int(max_s * rate)
	if max_n > 0 and mix.size() > max_n:
		mix.resize(max_n)
	AudioDsp.dc_block(mix, 20.0, rate)
	AudioDsp.normalize(mix, AudioDsp.db_to_lin(float(def.get("peak_db", -10.0))))
	AudioDsp.fade(mix, 0.0004, 0.04, rate)
	return mix


## Shape a layer with the flash's pulses: a raised-cosine swell over each `on`, a floor level between pulses, later
## pulses louder by `grow`, and a fade after the last. t0 is the layer's start in the cue's own time.
static func _pulse(buf: PackedFloat32Array, pulse: Dictionary, floor_lvl: float, grow: float, t0: float, rate: int) -> void:
	var count: int = int(pulse.count)
	var on: float = float(pulse.on)
	var period: float = on + float(pulse.off)
	var end: float = float(count - 1) * period + on
	var fade: float = maxf(float(pulse.fade), 0.001)
	var top: float = 1.0 + grow * float(count - 1)
	for i in range(buf.size()):
		var t: float = t0 + float(i) / float(rate)
		var k: int = clampi(int(t / period), 0, count - 1)
		var within: float = t - float(k) * period
		var g: float = (1.0 + grow * float(k)) / top
		var e: float = floor_lvl * g
		if within < on:
			var sw: float = sin(PI * within / on)
			e = maxf(e, sw * sw * g)
		if t > end:
			e *= maxf(0.0, 1.0 - (t - end) / fade)
		buf[i] *= e


static func _semi(L: Dictionary, fam_id: String) -> float:
	var s = L.semi
	return float(s[fam_id]) if typeof(s) == TYPE_DICTIONARY else float(s)


static func _note(L: Dictionary, fam: Dictionary, fam_id: String, rate: int) -> PackedFloat32Array:
	var fs: float = float(rate)
	var a: float = float(L.a) * float(fam.attack_k)
	var hold: float = float(L.hold)
	var t60: float = float(L.t60)
	var dur: float = float(L.dur)
	var n: int = int((maxf(dur, a + hold) + t60 * 1.05) * fs)
	var out := PackedFloat32Array()
	out.resize(n)
	var s0: float = _semi(L, fam_id)
	var glide: float = float(L.get("glide", 0.0))
	var vib_hz: float = float(L.get("vib_hz", fam.vib_hz))
	var vib: float = float(L.get("vib", fam.vib))
	var step_s: float = float(fam.step_ms) * 0.001
	var wave: String = String(fam.wave)
	var duty: float = float(fam.duty)
	var h2: float = float(fam.h2)
	var h3: float = float(fam.h3)
	var fm: float = float(fam.fm)
	var lp: float = float(fam.lp_hz)
	var kf: float = minf(TAU * lp / fs, 0.9) if lp > 0.0 else 1.0
	var dec: float = exp(-AudioDsp.LN60 / (fs * t60))
	var ph: float = 0.0
	var amp: float = 1.0
	var y: float = 0.0
	var semi_now: float = s0
	for i in range(n):
		var t: float = float(i) / fs
		# pitch: a linear glide over the note; the stepped family holds each step for step_ms and snaps to a semitone
		var frac: float = clampf(t / maxf(dur, 0.001), 0.0, 1.0)
		var s: float = s0 + glide * frac
		if step_s > 0.0:
			s = roundf(s0 + glide * floorf(t / step_s) * step_s / maxf(dur, 0.001))
		semi_now = s
		var f: float = float(fam.root_hz) * pow(2.0, semi_now / 12.0) * (1.0 + vib * sin(TAU * vib_hz * t))
		ph += f / fs
		ph -= floor(ph)
		var x: float
		match wave:
			"sine":
				x = sin(TAU * ph) + h2 * sin(TAU * 2.0 * ph) + h3 * sin(TAU * 3.0 * ph)
			"fm":
				x = sin(TAU * ph + fm * exp(-t / 0.15) * sin(TAU * 2.0 * ph))
			"pulse":
				x = (1.0 if ph < duty else -1.0) * 0.6
			_:
				x = (1.0 if ph < 0.5 else -1.0) * 0.5
		y += kf * (x - y)
		var e: float = amp
		if t < a:
			e = t / a
		elif t >= a + hold:
			amp *= dec
			e = amp
		out[i] = (y if lp > 0.0 else x) * e
	return out


static func _tick(L: Dictionary, fam: Dictionary, rate: int, sd: int) -> PackedFloat32Array:
	var fs: float = float(rate)
	var f: float = float(L.f) * sqrt(float(fam.root_hz) / 293.66)
	var t60: float = float(L.t60)
	var n: int = int(t60 * 1.05 * fs) + 16
	var out := PackedFloat32Array()
	out.resize(n)
	var dec: float = exp(-AudioDsp.LN60 / (fs * t60))
	var amp: float = 1.0
	for i in range(n):
		out[i] = (sin(TAU * f * float(i) / fs) + 0.5 * sin(TAU * f * 2.4 * float(i) / fs)) * amp
		amp *= dec
	var nz: PackedFloat32Array = AudioDsp.noise(int(0.004 * fs), sd)
	for i in range(nz.size()):
		out[i] += nz[i] * float(L.click) * (1.0 - float(i) / float(nz.size()))
	return out


static func _breath(L: Dictionary, rate: int, sd: int) -> PackedFloat32Array:
	var fs: float = float(rate)
	var a: float = float(L.a)
	var hold: float = float(L.hold)
	var t60: float = float(L.t60)
	var dur: float = float(L.dur)
	var n: int = int((maxf(dur, a + hold) + t60 * 1.05) * fs)
	var out: PackedFloat32Array = AudioDsp.noise(n, sd)
	var f0: float = float(L.f)
	var f1: float = float(L.get("f_to", f0))
	AudioDsp.filter(out, String(L.filter), f0, f1, maxf(dur * 0.5, 0.01) if f1 != f0 else 0.0, float(L.get("q", 0.7)), rate)
	var dec: float = exp(-AudioDsp.LN60 / (fs * t60))
	var amp: float = 1.0
	var trem_hz: float = float(L.get("trem_hz", 0.0))
	var trem: float = float(L.get("trem", 0.0))
	for i in range(n):
		var t: float = float(i) / fs
		var e: float = amp
		if t < a:
			e = t / a
		elif t >= a + hold:
			amp *= dec
			e = amp
		if trem > 0.0:
			e *= 1.0 - trem * 0.5 * (1.0 + sin(TAU * trem_hz * t))
		out[i] *= e
	AudioDsp.normalize(out, 1.0)
	return out


static func _thump(L: Dictionary, rate: int) -> PackedFloat32Array:
	var fs: float = float(rate)
	var t60: float = float(L.t60)
	var n: int = int(t60 * 1.05 * fs)
	var out := PackedFloat32Array()
	out.resize(n)
	var f0: float = float(L.f)
	var f1: float = float(L.f_to)
	var dec: float = exp(-AudioDsp.LN60 / (fs * t60))
	var gl: float = exp(-1.0 / (fs * 0.05))
	var g: float = 1.0
	var amp: float = 1.0
	var ph: float = 0.0
	for i in range(n):
		ph += TAU * (f1 + (f0 - f1) * g) / fs
		g *= gl
		out[i] = sin(ph) * amp * minf(1.0, float(i) / 24.0)
		amp *= dec
	AudioDsp.saturate(out, 1.5)
	return out


## A low creak: a saw with every other cycle quieter, noise, a low-pass, a swell and a hard cut (no tail).
static func _growl(L: Dictionary, fam: Dictionary, rate: int, sd: int) -> PackedFloat32Array:
	var fs: float = float(rate)
	var dur: float = float(L.dur)
	var n: int = int(dur * fs)
	var out := PackedFloat32Array()
	out.resize(n)
	var nz: PackedFloat32Array = AudioDsp.noise(n, sd)
	var f0: float = float(L.f0)
	var f1: float = float(L.f1)
	var swell: float = float(L.swell)
	var fry: float = float(fam.growl_fry)
	var ph: float = 0.0
	var cyc: int = 0
	var cyc_a: float = 1.0
	for i in range(n):
		var t: float = float(i) / fs
		ph += (f0 + (f1 - f0) * t / dur) / fs
		if ph >= 1.0:
			ph -= 1.0
			cyc += 1
			cyc_a = (1.0 - fry) if (cyc & 1) == 1 else 1.0
		var e: float = minf(1.0, t / swell)
		e *= e
		out[i] = ((ph * 2.0 - 1.0) * cyc_a * 0.8 + nz[i] * 0.25) * e
	AudioDsp.filter(out, "lp", float(fam.growl_lp), float(fam.growl_lp), 0.0, 0.8, rate)
	AudioDsp.saturate(out, 2.0)
	return out
