class_name BabbleSynth
extends RefCounted
## Renders the babble bank (data/babble.json): a few short syllables per voice, in four timbres, and a laugh. A
## syllable is one call to the grunt voice engine (GruntSynth): an onset (a plosive burst, a nasal murmur, a breath or
## nothing) gliding into a vowel, about 100 ms long, at the voice's reference pitch. The player then changes its pitch
## a few semitones per syllable to make the contour. Bank ids: "babble.<voice>.<timbre>.<syllable>" and
## "babble.<voice>.laugh". Pure functions of the data and the fixed bank seed.


static func render(id: String, cfg: Dictionary) -> PackedFloat32Array:
	var p: PackedStringArray = id.split(".")
	if p.size() == 3 and p[2] == "laugh":
		return laugh(cfg, p[1], 0)
	if p.size() == 4:
		return syllable(cfg, p[1], p[2], p[3])
	return PackedFloat32Array()


static func _scaled(v: Dictionary, k: float) -> Dictionary:
	var f: Array = []
	for x in v.f:
		f.append(float(x) * k)
	return {"f": f, "bw": v.bw}


## The recipe of one syllable as a GruntSynth definition.
static func syllable_def(cfg: Dictionary, voice: String, timbre: String, syl: String, f0_mul: float = 1.0) -> Dictionary:
	var V: Dictionary = cfg.voices[voice]
	var S: Dictionary = cfg.syllables[syl]
	var on: Dictionary = cfg.onsets[S.onset]
	var tm: Dictionary = cfg.timbres[timbre]
	var k: float = float(V.formant_k)
	var vowel: Dictionary = _scaled(cfg.vowels[S.vowel], k)
	var onset: Dictionary = _scaled(cfg.nasal, k) if bool(on.nasal) else vowel
	var dur: float = float(V.syl_ms) * 0.001
	var f0: float = float(V.ref_f0) * f0_mul
	return {
		"rate": int(cfg.rate), "dur": dur, "f0": [f0, f0 * 0.94], "f0_tau": 0.05,
		"f0_jitter": float(V.jitter) * float(tm.jitter), "shimmer": float(V.shimmer) * float(tm.shimmer),
		"open": clampf(float(V.open) * float(tm.open), 0.3, 0.9), "fry": float(tm.fry),
		"vowel_a": onset, "vowel_b": vowel, "glide": on.glide,
		"breath": float(on.breath) * float(tm.breath), "h_onset": float(on.h_onset), "breath_body": 0.08,
		"attack": 0.006 * float(tm.attack), "hold": dur * 0.35, "t60": dur * 0.5,
		"drive": float(V.drive) * float(tm.drive), "peak_db": -8.0
	}


static func syllable(cfg: Dictionary, voice: String, timbre: String, syl: String) -> PackedFloat32Array:
	var def: Dictionary = syllable_def(cfg, voice, timbre, syl)
	var buf: PackedFloat32Array = GruntSynth.render(def, int(cfg.bank_seed), "babble.%s.%s.%s" % [voice, timbre, syl], 0)
	_crush(buf, cfg.voices[voice])
	return buf


## A laugh: pulses of "ha" (a breath into an open vowel) falling or rising in pitch, spaced and fading as the voice says.
static func laugh(cfg: Dictionary, voice: String, variant: int) -> PackedFloat32Array:
	var V: Dictionary = cfg.voices[voice]
	var L: Dictionary = V.laugh
	var rate: int = int(cfg.rate)
	var pulses: int = int(L.pulses)
	var mix := PackedFloat32Array()
	var t: float = 0.0
	var gain: float = 1.0
	for p in range(pulses):
		var u: float = float(p) / float(maxi(pulses - 1, 1))
		var f0: float = lerpf(float(L.f0[0]), float(L.f0[1]), u) * pow(2.0, float(L.step_st) * float(p) / 12.0)
		var def: Dictionary = syllable_def(cfg, voice, "base", "ha", f0 / float(V.ref_f0))
		def["dur"] = float(L.pulse_ms) * 0.001
		def["hold"] = def.dur * 0.3
		def["t60"] = def.dur * 0.45
		def["breath"] = float(L.breath)
		def["f0"] = [f0, f0 * 0.9]
		var pb: PackedFloat32Array = GruntSynth.render(def, int(cfg.bank_seed), "babble.%s.laugh.%d.%d" % [voice, variant, p], 0)
		AudioDsp.mix_into(mix, pb, int(t * rate), gain)
		t += lerpf(float(L.spacing[0]), float(L.spacing[1]), u) * (1.0 + 0.08 * float(variant))
		gain *= float(L.decay)
	_crush(mix, V)
	AudioDsp.normalize(mix, AudioDsp.db_to_lin(-7.0))
	return mix


## A bit-crush and sample-hold for the mechanical voice (crush_bits 0 leaves the buffer alone).
static func _crush(buf: PackedFloat32Array, V: Dictionary) -> void:
	var bits: int = int(V.get("crush_bits", 0))
	var hold: int = maxi(int(V.get("hold", 1)), 1)
	if bits <= 0 and hold <= 1:
		return
	var q: float = pow(2.0, float(bits) - 1.0) if bits > 0 else 0.0
	var held: float = 0.0
	for i in range(buf.size()):
		if i % hold == 0:
			held = buf[i]
		buf[i] = roundf(held * q) / q if q > 0.0 else held
