class_name MusicSketch
extends RefCounted
## A tiny procedural sequencer that renders a 30-second sketch of one music direction (docs/audio/direction.md section 3)
## so Orb can choose by ear. The three sketches share one arc and one tune, and differ in the instruments (the "kit"):
## A The Town Band, B Furnace, C Kitchen Drums. Every note, chord, pattern level and instrument choice is in
## data/sketch_*.json; this file is the instruments and the pattern engine.
##
## These are SKETCHES, not the score. They show the mood, the arrangement idea and the escalation. All three are
## synthesised (no samples), so A's brass and C's "kitchen" are stand-ins for the real thing: A wants sampled brass and C
## wants real recordings. B is the closest to how the final music would sound.
##
## The arc, 12 bars at 96 BPM (a bar is 2.5 s): 0-1 overture (intensity 0), 2-3 the tune (1), 4-5 a region breaks and the
## edge layer joins (2), 6 the chapter drop-out, 7-10 the peak (3), 11 the KO hit and its tail.

const PC := {"D": 2, "Bb": 10, "C": 0, "G": 7, "A": 9}


## Render a sketch spec (parsed data/sketch_*.json) to a mono buffer at spec.rate, peak -3 dBFS.
static func render(spec: Dictionary, bank_seed: int) -> PackedFloat32Array:
	var fs: int = int(spec.rate)
	var beat: float = 60.0 / float(spec.bpm)
	var bars: int = int(spec.bars)
	var total: int = int(float(bars) * 4.0 * beat * fs)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var kit: Dictionary = spec.kit
	var gain: Dictionary = spec.gain
	var I: Array = spec.intensity
	var k: int = 0    # note counter, for the per-note noise seed
	var pat: Dictionary = spec.patterns

	# the planet's drone, the whole way
	_put(mix, _inst("drone", 38.0, float(bars) * 4.0 * beat, 0.6, fs, 1), 0.0, float(gain.drone), fs)

	for bar in range(bars):
		var t0: float = float(bar) * 4.0 * beat
		var ch: Array = spec.chords[bar]
		var pc: int = int(PC[ch[0]])
		var minor: bool = ch[1] == "m"
		var bass_m: float = float(36 + pc - (12 if pc >= 7 else 0))
		var mid_m: float = float(60 + pc - (12 if pc > 6 else 0))
		var tones: Array = [mid_m, mid_m + (3.0 if minor else 4.0), mid_m + 7.0]
		var lvl: int = int(I[bar])
		var last: bool = bar == bars - 1
		var brk: bool = bar == 6

		if last:
			# the KO hit: everything at once, then the tail
			_put(mix, _inst(kit.accent, 60.0, 2.0, 1.0, fs, k), t0, float(gain.accent) * 1.4, fs)
			_put(mix, _inst(kit.kick, 40.0, 0.5, 1.0, fs, k + 1), t0, float(gain.kick) * 1.3, fs)
			_put(mix, _inst(kit.bass, bass_m, 2.2, 1.0, fs, k + 2), t0, float(gain.bass), fs)
			for tn in tones:
				_put(mix, _inst(kit.chord, tn, 2.2, 0.9, fs, k + 3), t0, float(gain.chord), fs)
			k += 4
			continue

		# chord bed
		if not brk and bool(pat.bed):
			for tn in tones:
				_put(mix, _inst(kit.bed, tn, 4.0 * beat, 0.6, fs, k), t0, float(gain.bed) * (0.6 if lvl == 0 else 1.0), fs)
				k += 1

		if brk:
			# the chapter drop-out: one soft hit, then a snare roll that leads back in
			_put(mix, _inst(kit.kick, 40.0, 0.4, 0.8, fs, k), t0, float(gain.kick), fs)
			for j in range(4):
				_put(mix, _inst(kit.snare, 70.0, 0.15, 0.4 + 0.15 * float(j), fs, k + 1 + j), t0 + (3.0 + 0.25 * float(j)) * beat, float(gain.snare), fs)
			k += 6
			continue

		# bell: single strikes in the overture, the top of the chord on each downbeat after
		if lvl == 0:
			if bar == 0 or bar == 1:
				_put(mix, _inst(kit.bell, tones[2] + 12.0, 2.0, 0.6, fs, k), t0 + (0.0 if bar == 0 else 2.0) * beat, float(gain.bell), fs)
				k += 1
		elif lvl >= 2:
			_put(mix, _inst(kit.bell, tones[2] + 12.0, 1.5, 0.7, fs, k), t0, float(gain.bell), fs)
			k += 1

		# bass and drums
		if lvl >= 1:
			var bp: Array = pat.bass_beats
			var bl: float = float(pat.bass_len)
			for b in bp:
				var note: float = bass_m + (7.0 if String(pat.bass_style) == "oompah" and int(b) == 2 else 0.0)
				_put(mix, _inst(kit.bass, note, bl * beat, 0.9, fs, k), t0 + float(b) * beat, float(gain.bass), fs)
				k += 1
			var kb: Array = pat.kick_beats_half if lvl == 3 else pat.kick_beats
			for b in kb:
				_put(mix, _inst(kit.kick, 40.0, 0.4, 0.9, fs, k), t0 + float(b) * beat, float(gain.kick), fs)
				k += 1
			for b in pat.snare_beats:
				_put(mix, _inst(kit.snare, 70.0, 0.15, 0.8, fs, k), t0 + float(b) * beat, float(gain.snare), fs)
				k += 1
			if bool(pat.chord_stabs):
				for b in [1.0, 3.0]:
					for tn in tones:
						_put(mix, _inst(kit.chord, tn, 0.3 * beat, 0.6, fs, k), t0 + b * beat, float(gain.chord), fs)
						k += 1
		if lvl >= 2:
			# arpeggio on chord tones, eighth notes
			for j in range(8):
				var tn: float = tones[[0, 1, 2, 1, 0, 1, 2, 1][j]] + (12.0 if lvl == 3 else 0.0)
				_put(mix, _inst(kit.arp, tn, 0.45 * beat, 0.5, fs, k), t0 + 0.5 * float(j) * beat, float(gain.arp), fs)
				k += 1
			# time-keeping tick
			for j in range(8 if lvl == 2 else int(pat.tick_peak)):
				var step: float = 4.0 / float(8 if lvl == 2 else int(pat.tick_peak))
				_put(mix, _inst(kit.tick, 90.0, 0.08, 0.5, fs, k), t0 + float(j) * step * beat, float(gain.tick), fs)
				k += 1
			# the edge layer: a chromatic line around the bass note (menace)
			for j in range(8):
				var off: float = [0.0, 1.0, 0.0, -1.0, 0.0, 1.0, 0.0, -1.0][j]
				_put(mix, _inst(kit.edge, bass_m + off, 0.4 * beat, 0.8, fs, k), t0 + 0.5 * float(j) * beat, float(gain.edge), fs)
				k += 1
			# an accent on the downbeat
			_put(mix, _inst(kit.accent, 60.0, 1.2, 0.8, fs, k), t0, float(gain.accent), fs)
			k += 1
		if lvl == 3 and String(pat.peak_extra) != "":
			_put(mix, _inst(String(pat.peak_extra), tones[0] + 12.0, 4.0 * beat, 0.7, fs, k), t0, float(gain.peak_extra), fs)
			k += 1

	# the tune (the same notes in every sketch): [bar, beat, midi, beats]
	for n in spec.tune:
		var t: float = float(n[0]) * 4.0 * beat + float(n[1]) * beat
		var m: float = float(n[2]) + float(spec.transpose)
		_put(mix, _inst(kit.lead, m, float(n[3]) * beat, 0.9, fs, k), t, float(gain.lead), fs)
		k += 1

	_dynamics(mix, spec.get("dynamics_db", []), 4.0 * beat, fs)
	AudioDsp.saturate(mix, float(spec.get("drive", 1.1)))
	AudioDsp.dc_block(mix, 20.0, fs)
	AudioDsp.normalize(mix, AudioDsp.db_to_lin(-3.0))
	AudioDsp.fade(mix, 0.005, 0.15, fs)
	return mix


## Per-bar level in dB, with a 0.15 s ramp at each bar line.
static func _dynamics(mix: PackedFloat32Array, db: Array, bar_s: float, fs: int) -> void:
	if db.is_empty():
		return
	var bar_n: int = int(bar_s * fs)
	var ramp: float = 0.15 * float(fs)
	for i in range(mix.size()):
		var bar: int = mini(i / bar_n, db.size() - 1)
		var into: float = float(i - bar * bar_n)
		var g: float = float(db[bar])
		if bar > 0 and into < ramp:
			g = lerpf(float(db[bar - 1]), g, into / ramp)
		mix[i] *= AudioDsp.db_to_lin(g)


static func _put(mix: PackedFloat32Array, buf: PackedFloat32Array, t: float, g: float, fs: int) -> void:
	var at: int = int(t * fs)
	var n: int = mini(buf.size(), mix.size() - at)
	for i in range(n):
		mix[at + i] += buf[i] * g


static func _hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## Attack, decay to a sustain level, hold to dur, then a linear release. The note lasts dur + r.
static func _env(t: float, dur: float, a: float, d: float, s: float, r: float) -> float:
	if t < a:
		return t / a
	if t < a + d:
		return 1.0 + (s - 1.0) * (t - a) / d
	if t < dur:
		return s
	return maxf(0.0, s * (1.0 - (t - dur) / r))


## One note of an instrument. m is a MIDI note (or, for unpitched hits, a placeholder); dur in seconds; vel 0 to 1.
static func _inst(name: String, m: float, dur: float, vel: float, fs: int, sd: int) -> PackedFloat32Array:
	var f: float = _hz(m)
	match name:
		"brass": return _saw_lp(f, dur, vel, fs, 0.05, 0.08, 0.8, 0.10, 2.0, 6.0, 0.004, 1.003)
		"trombone": return _saw_lp(f, dur, vel, fs, 0.03, 0.06, 0.7, 0.06, 1.5, 3.5, 0.002, 1.002)
		"tuba": return _harm(f, dur, vel, fs, [1.0, 0.5, 0.25], 0.02, 0.1, 0.6, 0.1, 1.6)
		"clar": return _harm(f, dur, vel, fs, [1.0, 0.0, 0.35, 0.0, 0.2], 0.03, 0.05, 0.85, 0.06, 0.0)
		"drone": return _harm(f, dur, vel, fs, [1.0, 0.6, 0.35, 0.2], 1.5, 0.5, 0.9, 1.0, 0.0)
		"glock": return _modal(f, [1.0, 2.76, 5.4], [1.0, 0.5, 0.25], [1.0, 0.5, 0.25], vel, fs, sd, 0.0)
		"snare": return _snare(vel, fs, sd)
		"kick": return _kick(vel, fs, 130.0, 48.0, 0.04, 0.28)
		"cymbal": return _noise_hit(vel, fs, sd, 2600.0, "hp", 0.7, 1.6)
		"tick": return _noise_hit(vel, fs, sd, 3500.0, "hp", 0.7, 0.05)
		"synbass": return _synbass(f, dur, vel, fs)
		"pulse": return _pulse(f, dur, vel, fs, 0.35, 0.0)
		"pulselead": return _pulse(f, dur, vel, fs, 0.4, 0.004)
		"pad": return _pad(f, dur, vel, fs)
		"fmbell": return _fm(f, vel, fs)
		"anvil": return _modal(200.0, [1.0, 2.4, 3.9, 6.1], [1.0, 0.7, 0.5, 0.3], [0.5, 0.35, 0.25, 0.15], vel, fs, sd, 0.4)
		"clap": return _noise_hit(vel, fs, sd, 1300.0, "bp", 0.9, 0.10)
		"pot": return _modal(f, [1.0, 2.32, 3.87, 5.63, 7.9], [1.0, 0.7, 0.5, 0.3, 0.2], [0.5, 0.32, 0.22, 0.14, 0.1], vel, fs, sd, 0.3)
		"pan": return _modal(f, [1.0, 2.7, 4.9, 7.3], [1.0, 0.6, 0.4, 0.25], [0.3, 0.2, 0.12, 0.08], vel, fs, sd, 0.4)
		"wood": return _modal(f * 2.0, [1.0, 2.4], [1.0, 0.5], [0.05, 0.03], vel, fs, sd, 0.5)
		"spoon": return _noise_hit(vel, fs, sd, 4200.0, "hp", 0.9, 0.03)
		"lid": return _lid(vel, fs, sd)
		"oildrum": return _kick(vel, fs, f * 1.8, f, 0.05, 0.5)
		"glass": return _glass(f, dur, vel, fs)
		"hum": return _hum(f, dur, vel, fs, sd)
		_:
			push_warning("MusicSketch: unknown instrument '%s'" % name)
			return PackedFloat32Array()


## A detuned pair of naive saws through a two-pole low-pass whose cutoff follows the envelope: a brass-like tone.
static func _saw_lp(f: float, dur: float, vel: float, fs: int, a: float, d: float, s: float, r: float, lo: float, hi: float, vib: float, det: float) -> PackedFloat32Array:
	var n: int = int((dur + r) * fs)
	var out := PackedFloat32Array()
	out.resize(n)
	var p1: float = 0.0
	var p2: float = 0.0
	var l1: float = 0.0
	var l2: float = 0.0
	var fsf: float = float(fs)
	for i in range(n):
		var t: float = float(i) / fsf
		var e: float = _env(t, dur, a, d, s, r)
		var v: float = 1.0 + vib * sin(TAU * 5.2 * t) * minf(1.0, t / 0.25)
		p1 += f * v / fsf
		p2 += f * v * det / fsf
		p1 -= floor(p1)
		p2 -= floor(p2)
		var x: float = (p1 + p2) - 1.0
		var cut: float = minf(f * (lo + (hi - lo) * e * vel), fsf * 0.4)
		var k: float = minf(TAU * cut / fsf, 0.9)
		l1 += k * (x - l1)
		l2 += k * (l1 - l2)
		out[i] = l2 * e * vel
	return out


## A sum of sine harmonics with amplitudes, an envelope and optional saturation: tuba, clarinet, drone.
static func _harm(f: float, dur: float, vel: float, fs: int, amps: Array, a: float, d: float, s: float, r: float, drive: float) -> PackedFloat32Array:
	var n: int = int((dur + r) * fs)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph: float = 0.0
	var fsf: float = float(fs)
	for i in range(n):
		var t: float = float(i) / fsf
		var e: float = _env(t, dur, a, d, s, r)
		ph += f * (1.0 + 0.003 * sin(TAU * 5.0 * t)) / fsf
		var x: float = 0.0
		for h in range(amps.size()):
			if float(amps[h]) != 0.0 and f * float(h + 1) < fsf * 0.45:
				x += float(amps[h]) * sin(TAU * ph * float(h + 1))
		out[i] = x * e * vel * 0.5
	if drive > 0.0:
		AudioDsp.saturate(out, drive)
	return out


## Inharmonic partials with their own decays: bells, pots, pans, wood, anvils. click adds a short noise tick.
static func _modal(f: float, ratios: Array, amps: Array, t60s: Array, vel: float, fs: int, sd: int, click: float) -> PackedFloat32Array:
	var longest: float = 0.0
	for t in t60s:
		longest = maxf(longest, float(t))
	var n: int = int((longest * 1.05 + 0.01) * fs)
	var out := PackedFloat32Array()
	out.resize(n)
	var fsf: float = float(fs)
	for h in range(ratios.size()):
		var fh: float = f * float(ratios[h])
		if fh > fsf * 0.45:
			continue
		var dec: float = exp(-AudioDsp.LN60 / (fsf * float(t60s[h])))
		var amp: float = float(amps[h])
		var w: float = TAU * fh / fsf
		var m: int = mini(n, int(float(t60s[h]) * 1.05 * fs))
		for i in range(m):
			out[i] += amp * sin(w * float(i))
			amp *= dec
	if click > 0.0:
		var nz: PackedFloat32Array = AudioDsp.noise(int(0.006 * fs), sd + 77)
		for i in range(nz.size()):
			out[i] += nz[i] * click * (1.0 - float(i) / float(nz.size()))
	for i in range(n):
		out[i] *= vel * 0.35
	return out


static func _noise_hit(vel: float, fs: int, sd: int, fc: float, kind: String, q: float, t60: float) -> PackedFloat32Array:
	var n: int = int(t60 * 1.05 * fs) + 8
	var out: PackedFloat32Array = AudioDsp.noise(n, sd + 1234)
	AudioDsp.filter(out, kind, fc, fc, 0.0, q, fs)
	var dec: float = exp(-AudioDsp.LN60 / (float(fs) * t60))
	var amp: float = vel
	for i in range(n):
		out[i] *= amp
		amp *= dec
	AudioDsp.normalize(out, vel * 0.8)
	return out


static func _snare(vel: float, fs: int, sd: int) -> PackedFloat32Array:
	var body: PackedFloat32Array = _kick(vel * 0.5, fs, 220.0, 170.0, 0.02, 0.12)
	var nz: PackedFloat32Array = _noise_hit(vel, fs, sd, 1700.0, "bp", 0.6, 0.14)
	var n: int = maxi(body.size(), nz.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(body.size()):
		out[i] += body[i]
	for i in range(nz.size()):
		out[i] += nz[i]
	return out


static func _kick(vel: float, fs: int, f0: float, f1: float, tau: float, t60: float) -> PackedFloat32Array:
	var n: int = int(t60 * 1.05 * fs)
	var out := PackedFloat32Array()
	out.resize(n)
	var fsf: float = float(fs)
	var ph: float = 0.0
	var dec: float = exp(-AudioDsp.LN60 / (fsf * t60))
	var gl: float = exp(-1.0 / (fsf * tau))
	var g: float = 1.0
	var amp: float = vel
	for i in range(n):
		ph += TAU * (f1 + (f0 - f1) * g) / fsf
		g *= gl
		var e: float = amp
		if i < 24:
			e *= float(i) / 24.0
		out[i] = sin(ph) * e
		amp *= dec
	AudioDsp.saturate(out, 1.6)
	return out


static func _synbass(f: float, dur: float, vel: float, fs: int) -> PackedFloat32Array:
	var r: float = 0.05
	var n: int = int((dur + r) * fs)
	var out := PackedFloat32Array()
	out.resize(n)
	var fsf: float = float(fs)
	var p: float = 0.0
	var ps: float = 0.0
	var l1: float = 0.0
	var l2: float = 0.0
	for i in range(n):
		var t: float = float(i) / fsf
		var e: float = _env(t, dur, 0.004, 0.08, 0.7, r)
		p += f / fsf
		p -= floor(p)
		ps += f * 0.5 / fsf
		var cut: float = 150.0 + 900.0 * exp(-t / 0.12)
		var k: float = minf(TAU * cut / fsf, 0.9)
		l1 += k * ((p * 2.0 - 1.0) - l1)
		l2 += k * (l1 - l2)
		out[i] = (l2 * 1.6 + 0.6 * sin(TAU * ps)) * e * vel
	AudioDsp.saturate(out, 2.0)
	return out


static func _pulse(f: float, dur: float, vel: float, fs: int, duty: float, vib: float) -> PackedFloat32Array:
	var r: float = 0.06
	var n: int = int((dur + r) * fs)
	var out := PackedFloat32Array()
	out.resize(n)
	var fsf: float = float(fs)
	var p: float = 0.0
	var l1: float = 0.0
	var l2: float = 0.0
	for i in range(n):
		var t: float = float(i) / fsf
		var e: float = _env(t, dur, 0.005, 0.06, 0.4 if vib == 0.0 else 0.8, r)
		p += f * (1.0 + vib * sin(TAU * 5.5 * t)) / fsf
		p -= floor(p)
		var cut: float = minf(800.0 + 1600.0 * exp(-t / 0.08), fsf * 0.4)
		var k: float = minf(TAU * cut / fsf, 0.9)
		l1 += k * ((1.0 if p < duty else -1.0) - l1)
		l2 += k * (l1 - l2)
		out[i] = l2 * e * vel * 0.6
	return out


static func _pad(f: float, dur: float, vel: float, fs: int) -> PackedFloat32Array:
	var r: float = 0.5
	var n: int = int((dur + r) * fs)
	var out := PackedFloat32Array()
	out.resize(n)
	var fsf: float = float(fs)
	var ph := PackedFloat64Array([0.0, 0.0, 0.0])
	var det := PackedFloat64Array([0.996, 1.0, 1.004])
	var l1: float = 0.0
	var l2: float = 0.0
	var k: float = minf(TAU * 1100.0 / fsf, 0.9)
	for i in range(n):
		var t: float = float(i) / fsf
		var e: float = _env(t, dur, 0.5, 0.3, 0.85, r)
		var x: float = 0.0
		for j in range(3):
			ph[j] += f * det[j] / fsf
			ph[j] -= floor(ph[j])
			x += ph[j] * 2.0 - 1.0
		l1 += k * (x / 3.0 - l1)
		l2 += k * (l1 - l2)
		out[i] = l2 * e * vel * 0.7
	return out


static func _fm(f: float, vel: float, fs: int) -> PackedFloat32Array:
	var n: int = int(1.4 * fs)
	var out := PackedFloat32Array()
	out.resize(n)
	var fsf: float = float(fs)
	for i in range(n):
		var t: float = float(i) / fsf
		var idx: float = 3.0 * exp(-t / 0.3)
		var e: float = exp(-AudioDsp.LN60 * t / 1.2) * minf(1.0, t / 0.003)
		out[i] = sin(TAU * f * t + idx * sin(TAU * f * 3.5 * t)) * e * vel * 0.5
	return out


static func _lid(vel: float, fs: int, sd: int) -> PackedFloat32Array:
	var nz: PackedFloat32Array = _noise_hit(vel, fs, sd, 3000.0, "bp", 0.6, 0.9)
	var ring: PackedFloat32Array = _modal(1400.0, [1.0, 1.51, 2.42], [1.0, 0.6, 0.4], [0.7, 0.5, 0.3], vel, fs, sd, 0.0)
	var out := PackedFloat32Array()
	out.resize(maxi(nz.size(), ring.size()))
	for i in range(nz.size()):
		out[i] += nz[i]
	for i in range(ring.size()):
		out[i] += ring[i]
	return out


static func _glass(f: float, dur: float, vel: float, fs: int) -> PackedFloat32Array:
	var r: float = 1.0
	var n: int = int((dur + r) * fs)
	var out := PackedFloat32Array()
	out.resize(n)
	var fsf: float = float(fs)
	for i in range(n):
		var t: float = float(i) / fsf
		var e: float = _env(t, dur, 0.8, 0.5, 0.9, r)
		var v: float = 1.0 + 0.002 * sin(TAU * 4.0 * t)
		out[i] = (sin(TAU * f * v * t) + sin(TAU * f * 1.004 * t) + 0.3 * sin(TAU * f * 2.0 * t)) * e * vel * 0.25
	return out


## A sung "oo" hum from the grunt voice engine: the same source-filter code, a steady pitch and a closed vowel.
static func _hum(f: float, dur: float, vel: float, fs: int, sd: int) -> PackedFloat32Array:
	var def := {
		"rate": fs, "dur": dur + 0.15, "f0": [f, f * 0.996], "f0_tau": 0.3, "f0_jitter": 0.008, "shimmer": 0.03,
		"open": 0.7, "fry": 0.0,
		"vowel_a": {"f": [300.0, 870.0, 2240.0], "bw": [60.0, 90.0, 120.0]},
		"vowel_b": {"f": [300.0, 870.0, 2240.0], "bw": [60.0, 90.0, 120.0]},
		"glide": [0.0, 0.5], "breath": 0.04, "h_onset": 0.01, "attack": 0.06, "hold": maxf(dur - 0.25, 0.05), "t60": 0.12,
		"drive": 0.0, "peak_db": -6.0
	}
	var b: PackedFloat32Array = GruntSynth.render(def, 20260929, "music.hum." + str(sd), 0)
	for i in range(b.size()):
		b[i] *= vel
	return b
