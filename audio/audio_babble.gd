class_name AudioBabble
extends RefCounted
## The babble voice: a caption becomes a run of short syllables, in the speaking fighter's voice, that plays while the
## caption is revealed. Orb (playtest 2): lines should play out with a distinct voice per character in "grunts, laughs
## and chattering noises while their captions appear".
##
## plan() is a pure function of (voice, text, mood, intensity, cues, seed): it lists what to play and when, and nothing
## else. It draws only from its own seeded stream, so a replay speaks the same babble, and it never touches the sim.
## AudioBabblePlayer plays a plan; mix() renders one to a buffer for previews and tools.
##
## What the caption drives:
##   * timing: the same clock as the text reveal (ui/core/ui_bark_timing.gd: characters a second at the line's intensity,
##     with pauses at punctuation), so a syllable sounds as its words appear. One syllable per few letters of a word (up to
##     four; the voice's chars_per_syl), thinned so the voice never chatters faster than its own minimum gap; hyphenated stutters ("n-n-not") each
##     speak.
##   * pitch: a contour from punctuation. A question rises over its last four syllables, an exclamation punches its last
##     word, an ellipsis trails away (lower and quieter), a full stop falls, a comma lifts a little, and an ALL-CAPS word
##     is accented.
##   * mood: neutral, smug, angry, hurt, desperate, laughing (and playful, respectful, grim, with Narrative's register and
##     mood tags mapped onto them). A mood sets a timbre, a base pitch and drift, a lilt, a tempo, accents and jitter.
##   * punctuation by sound: laughs ("Ha!", "Ohoho"), a grunt after an exclamation, a sigh after an ellipsis, and any
##     gesture in the line's own cues (Narrative's line system, section 4).

const CUES_PATH := "res://audio/data/cues.json"

class Ev:
	var t: float = 0.0           # seconds from the start of the line
	var kind: String = "syl"     # "syl", "laugh" or "grunt"
	var sound: String = ""       # a bank id
	var variant: int = 0
	var st: float = 0.0          # semitones above the clip's own pitch
	var gain_db: float = 0.0


class Plan:
	var voice: String = ""
	var inner: bool = false          # a thought: quiet, breathy and muffled
	var emotion: String = "neutral"
	var text: String = ""
	var events: Array = []       # Ev, in time order
	var reveal: float = 0.0      # seconds the caption takes to reveal
	var total: float = 0.0       # seconds until the last sound has ended (about)

	## A short string that changes if any event changes (tests compare plans with it).
	func digest() -> String:
		var lines := PackedStringArray()
		for e in events:
			lines.append("%.4f|%s|%s|%d|%.3f|%.2f" % [e.t, e.kind, e.sound, e.variant, e.st, e.gain_db])
		return "\n".join(lines).sha256_text().substr(0, 16)

	func count(kind: String) -> int:
		var n: int = 0
		for e in events:
			if e.kind == kind:
				n += 1
		return n


var cfg: Dictionary = {}
var cues_cfg: Dictionary = {}
var bank: AudioBank
var _match_seed: int = 1
var _laugh_re: RegEx


func _init(p_bank: AudioBank = null) -> void:
	bank = p_bank if p_bank != null else AudioBank.new()
	cfg = bank.babble
	cues_cfg = AudioBank.load_json(CUES_PATH)
	_laugh_re = RegEx.create_from_string("^(?:ha+h?|hah+|(?:he){2,}h?|heh+|(?:ho){2,}h?|oh(?:oh)+o?|oho(?:ho)*h?|aha(?:ha)*)$")


## A new match: babble seeds derive from the match seed (and the line), so replays speak the same babble.
func reset(match_seed: int) -> void:
	_match_seed = match_seed


## The hook for the dialogue director (docs/narrative/dialogue-director.md). A line is Narrative's line object with the
## text filled in: {id, kind, text, cues, display: {style}, mood, intensity}. `mood` is the speaker's current mood node
## (playful, cocky, heated, rattled, ...; Narrative's graph, mapped in babble.json); `display.style` is caption, thought
## or shout (a `thought` kind counts as a thought); `intensity` is optional and defaults from the style. voice defaults to
## the fighter's voice (cues.json "fighters"). Returns the plan, or null if the fighter has no voice or the line no text.
func speak_line(S: SimState, actor: int, line: Dictionary, voice: String = "") -> Plan:
	if voice == "":
		if actor < 0 or actor >= S.fighters.size():
			return null
		voice = String(cues_cfg.get("fighters", {}).get(S.fighters[actor].name, ""))
	var text: String = String(line.get("text", ""))
	if voice == "" or text == "" or not cfg.voices.has(voice):
		return null
	var style: String = String(line.get("display", {}).get("style", "caption"))
	if String(line.get("kind", "")) == "thought":
		style = "thought"
	if not cfg.styles.has(style):
		style = "caption"
	var intensity: int = int(line.get("intensity", cfg.styles[style].intensity))
	var key: String = "audio.babble.%s.%d" % [String(line.get("id", text)), actor]
	return plan(voice, text, String(line.get("mood", "neutral")), intensity, line.get("cues", []), SimRng.deriveSeed(_match_seed, key), style)


## Seconds until each character index is on screen: T[i] is the reveal time of the start of character i, T[n] the total.
func times(text: String, intensity: int) -> PackedFloat64Array:
	var tl: Dictionary = cfg.timeline
	var per: float = 1.0 / (float(tl.base_cps) + float(tl.cps_per_intensity) * float(clampi(intensity, 0, 3)))
	var out := PackedFloat64Array()
	out.resize(text.length() + 1)
	var t: float = 0.0
	for i in range(text.length()):
		out[i] = t
		t += per + float(tl.pauses.get(text[i], 0.0))
	out[text.length()] = t
	return out


func plan(voice: String, text: String, mood: String, intensity: int, cues: Array, sd: int, style: String = "caption") -> Plan:
	var P := Plan.new()
	P.voice = voice
	P.text = text
	var emo: String = String(cfg.voice_moods.get(voice, {}).get(mood, cfg.mood_map.get(mood, mood)))
	if not cfg.moods.has(emo):
		emo = "neutral"
	var sty: Dictionary = cfg.styles.get(style, cfg.styles.caption)
	P.inner = style == "thought"
	if P.inner:
		emo = String(sty.mood)
	P.emotion = emo
	if not cfg.voices.has(voice) or text == "":
		return P
	var M: Dictionary = cfg.moods[emo].duplicate()
	M["gain_db"] = float(M.gain_db) + float(sty.get("gain_db", 0.0))
	var V: Dictionary = cfg.voices[voice].duplicate()
	if sty.has("chars_mul"):
		V["chars_per_syl"] = float(V.chars_per_syl) * float(sty.chars_mul)
	var rnd := AudioDsp.Rand.new(sd)
	var T: PackedFloat64Array = times(text, intensity)
	var n: int = text.length()
	P.reveal = T[n]
	var syl_s: float = float(V.syl_ms) * 0.001

	# 1. candidates: one per syllable of each word, with where it sits in its word and phrase
	var cands: Array = []
	var phrase_kind: Dictionary = {}    # phrase number -> how it ends: question, exclaim, ellipsis, period
	var phrase: int = 0
	var i: int = 0
	while i < n:
		while i < n and _is_space(text[i]):
			i += 1
		if i >= n:
			break
		var start: int = i
		while i < n and not _is_space(text[i]):
			i += 1
		var token: String = text.substr(start, i - start)
		var core_lo: int = 0
		var core_hi: int = token.length()
		while core_lo < core_hi and not _is_letter(token[core_lo]):
			core_lo += 1
		while core_hi > core_lo and not _is_letter(token[core_hi - 1]):
			core_hi -= 1
		var core: String = token.substr(core_lo, core_hi - core_lo)
		var trail: String = token.substr(core_hi)
		var end_kind: String = ""
		if trail.contains("…") or trail.contains(".."):
			end_kind = "ellipsis"
		elif trail.contains("?"):
			end_kind = "question"
		elif trail.contains("!"):
			end_kind = "exclaim"
		elif trail.contains("."):
			end_kind = "period"
		var has_comma: bool = trail.contains(",") or trail.contains(";") or trail.contains(":")
		if core == "":
			if cands.size() > 0 and end_kind != "":
				cands[cands.size() - 1]["phrase_end"] = end_kind
			continue
		if not P.inner and _laugh_re.search(core.to_lower()) != null:
			cands.append({"kind": "laugh", "t": T[start + core_lo], "phrase": phrase, "phrase_end": end_kind, "comma": has_comma})
		else:
			var frags: PackedStringArray = core.split("-", false)
			var fpos: int = core_lo
			for fi in range(frags.size()):
				var frag: String = frags[fi]
				var ns: int = _syllables(frag, float(V.chars_per_syl), int(cfg.plan.max_syl_per_word))
				for j in range(ns):
					var idx: int = mini(start + fpos + int(float(j) * float(frag.length()) / float(ns)), n - 1)
					cands.append({"kind": "syl", "t": T[idx], "phrase": phrase, "first": j == 0 and fi == 0, "caps": frag.length() >= 2 and frag == frag.to_upper(),
						"frag": fi, "last_of_word": j == ns - 1 and fi == frags.size() - 1, "comma": false, "phrase_end": ""})
				fpos += frag.length() + 1
			if cands.size() > 0:
				var last = cands[cands.size() - 1]
				if last.kind == "syl":
					last["comma"] = has_comma
					last["phrase_end"] = end_kind
		if end_kind != "":
			phrase_kind[phrase] = end_kind
			phrase += 1

	# 2. thin to the voice's own pace, in time order; laughs suppress the syllables under them
	var gap: float = float(V.min_gap) * float(M.gap_mul)
	var seq: Array = []
	var last_t: float = -9.0
	var kept_syl: int = 0
	var laugh_len: float = _laugh_len(V)
	for c in cands:
		if c.kind == "laugh":
			seq.append(c)
			last_t = c.t + laugh_len
			continue
		var is_final: bool = c.phrase_end != ""
		if c.t - last_t < gap * (0.6 if is_final else 1.0):
			continue
		if not is_final and not c.caps and rnd.next() < float(M.skip_p):
			continue
		seq.append(c)
		last_t = c.t
		kept_syl += 1
		if int(M.laugh_every) > 0 and kept_syl % int(M.laugh_every) == 0 and not is_final:
			seq.append({"kind": "laugh", "t": c.t + syl_s, "phrase": c.phrase, "phrase_end": "", "comma": false, "auto": true})
			last_t = c.t + syl_s + laugh_len
		if seq.size() >= int(cfg.plan.max_syllables):
			break

	# 3. contour: per phrase, the syllables in it and where the end contour applies
	var syl_idx: Array = []
	for k in range(seq.size()):
		if seq[k].kind == "syl":
			syl_idx.append(k)
	var total_syl: int = syl_idx.size()
	var st: Dictionary = {}
	var gain: Dictionary = {}
	var by_phrase: Dictionary = {}
	var last_k: Dictionary = {}          # seq index of a phrase's last kept syllable -> phrase number
	for a in range(total_syl):
		var c = seq[syl_idx[a]]
		var s: float = float(M.pitch_st) + float(M.slope_st) * float(a) / float(maxi(total_syl - 1, 1))
		if float(M.lilt_period) > 0.0:
			s += float(M.lilt_st) * sin(TAU * float(a) / float(M.lilt_period))
		s += float(M.jitter_st) * (rnd.next() * 2.0 - 1.0)
		var g: float = float(cfg.plan.syllable_gain_db) + float(M.gain_db) + (rnd.next() * 2.0 - 1.0)
		if c.first:
			s += 1.0
		if c.caps:
			s += 3.0
			g += 3.0
		elif int(M.accent_every) > 0 and a % int(M.accent_every) == 0:
			s += float(M.accent_st)
			g += 2.0
		if c.comma:
			s += 1.5
		st[syl_idx[a]] = s
		gain[syl_idx[a]] = g
		if not by_phrase.has(c.phrase):
			by_phrase[c.phrase] = []
		by_phrase[c.phrase].append(syl_idx[a])
	for ph in by_phrase:
		var L: Array = by_phrase[ph]
		last_k[L[L.size() - 1]] = ph
		var kind: String = String(phrase_kind.get(ph, ""))
		var m: int = 0
		match kind:
			"question": m = mini(4, L.size())
			"ellipsis": m = mini(3, L.size())
			"period": m = mini(2, L.size())
		for j in range(m):
			var k: int = L[L.size() - m + j]
			var u: float = float(j + 1) / float(m)
			match kind:
				"question": st[k] += 6.0 * u
				"ellipsis":
					st[k] -= 5.0 * u
					gain[k] -= 6.0 * u
				"period": st[k] -= 2.0 * u
		if kind == "exclaim":
			# punch the last word: its first syllable up and louder, and the very last a little higher
			for j in range(L.size() - 1, -1, -1):
				if j == 0 or bool(seq[L[j - 1]].last_of_word):
					st[L[j]] += 3.0
					gain[L[j]] += 3.0
					break
			st[L[L.size() - 1]] += 1.0

	# 4. events
	var prev_id: String = ""
	var voice_last_t: float = 0.0
	for k in range(seq.size()):
		var c = seq[k]
		if c.kind == "laugh":
			var e := Ev.new()
			e.t = c.t
			e.kind = "laugh"
			e.sound = "babble.%s.laugh" % voice
			e.variant = int(rnd.next() * float(bank.variants(e.sound))) % bank.variants(e.sound)
			e.st = float(M.pitch_st) * 0.5 + (rnd.next() * 2.0 - 1.0) * 0.5
			e.gain_db = float(cfg.plan.laugh_gain_db) + float(M.gain_db)
			P.events.append(e)
			voice_last_t = maxf(voice_last_t, e.t + laugh_len)
			continue
		var sid: String = _pick(V, rnd, prev_id, bool(V.stutter) and int(c.frag) > 0)
		prev_id = sid
		var ev := Ev.new()
		ev.t = c.t
		ev.kind = "syl"
		ev.sound = "babble.%s.%s.%s" % [voice, M.timbre, sid]
		ev.st = clampf(float(st[k]), -12.0, 12.0)
		ev.gain_db = float(gain[k])
		P.events.append(ev)
		voice_last_t = maxf(voice_last_t, ev.t + syl_s)
		# grunt or sigh after the end of a phrase
		var ends: String = String(phrase_kind.get(last_k[k], "")) if last_k.has(k) else ""
		if ends == "exclaim" and not P.inner and rnd.next() < float(M.grunt_p):
			_grunt(P, voice, cfg.grunt_punctuation.exclaim, ev.t + syl_s, rnd)
		elif ends == "ellipsis" and rnd.next() < float(cfg.grunt_punctuation.ellipsis.p):
			_grunt(P, voice, cfg.grunt_punctuation.ellipsis, ev.t + syl_s, rnd)

	# 5. the line's own cues (Narrative's line system): a gesture at a character offset
	for cue in cues:
		if P.inner and not String(cue.get("gesture", "")).begins_with("sigh"):
			continue
		var at: int = clampi(int(cue.get("at", 0)), 0, n)
		var gesture: String = String(cue.get("gesture", ""))
		var t: float = T[at]
		var inten: int = int(cue.get("intensity", 1))
		if gesture.begins_with("laugh") or gesture == "cackle":
			var e := Ev.new()
			e.t = t
			e.kind = "laugh"
			e.sound = "babble.%s.laugh" % voice
			e.variant = int(rnd.next() * float(bank.variants(e.sound))) % bank.variants(e.sound)
			e.gain_db = float(cfg.plan.laugh_gain_db) + 2.0 * float(inten - 1)
			P.events.append(e)
		else:
			var g: String = String(cfg.cue_map.get(gesture, ""))
			var id: String = "voice.%s.%s" % [voice, g]
			if g != "" and bank.has_sound(id):
				var e := Ev.new()
				e.t = t
				e.kind = "grunt"
				e.sound = id
				e.variant = int(rnd.next() * float(bank.variants(id))) % bank.variants(id)
				e.gain_db = -8.0 + 2.0 * float(inten)
				P.events.append(e)

	P.events.sort_custom(func(x, y): return x.t < y.t)
	P.total = maxf(P.reveal, voice_last_t + 0.05)
	return P


func _grunt(P: Plan, voice: String, spec: Dictionary, t: float, rnd: AudioDsp.Rand) -> void:
	var id: String = "voice.%s.%s" % [voice, spec.gesture]
	if not bank.has_sound(id):
		return
	var e := Ev.new()
	e.t = t + float(spec.delay)
	e.kind = "grunt"
	e.sound = id
	e.variant = int(rnd.next() * float(bank.variants(id))) % bank.variants(id)
	e.gain_db = float(spec.gain_db)
	P.events.append(e)


func _pick(V: Dictionary, rnd: AudioDsp.Rand, prev: String, repeat_prev: bool) -> String:
	if repeat_prev and prev != "":
		return prev
	var total: float = 0.0
	for k in V.lexicon:
		total += float(V.lexicon[k])
	for attempt in range(2):
		var r: float = rnd.next() * total
		for k in V.lexicon:
			r -= float(V.lexicon[k])
			if r <= 0.0:
				if k != prev or attempt == 1:
					return String(k)
				break
	return String(V.lexicon.keys()[0])


func _laugh_len(V: Dictionary) -> float:
	var L: Dictionary = V.laugh
	# how long a laugh keeps the syllables under it quiet: 60% of its length, so the speech can start under its tail
	return 0.6 * (float(L.pulses) * (float(L.spacing[0]) + float(L.spacing[1])) * 0.5 + float(L.pulse_ms) * 0.001)


static func _is_space(ch: String) -> bool:
	return ch == " " or ch == "\n" or ch == "\t"


static func _is_letter(ch: String) -> bool:
	return ch.to_lower() != ch.to_upper() or (ch >= "0" and ch <= "9")


## Syllables in a word, from its length: one per chars_per_syl letters (rounded), at least one for a word with a letter and
## at most max_n. The text length drives the babble, so a long word chatters longer than a short one.
static func _syllables(word: String, chars_per: float, max_n: int) -> int:
	var letters: int = 0
	for ch in word:
		if _is_letter(ch):
			letters += 1
	if letters == 0:
		return 0
	return clampi(int(roundf(float(letters) / chars_per)), 1, max_n)


## Render a plan to a mono buffer at `rate` (previews and tools; the game plays the events instead). Each clip is
## resampled by its pitch change with linear interpolation.
func mix(P: Plan, rate: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var cache: Dictionary = {}
	for e in P.events:
		var key: String = "%s#%d" % [e.sound, e.variant]
		if not cache.has(key):
			cache[key] = bank.buffer(e.sound, e.variant)
		var src: PackedFloat32Array = cache[key]
		var src_rate: float = float(bank.rate_of(e.sound))
		var step: float = pow(2.0, float(e.st) / 12.0) * src_rate / float(rate)
		var n: int = int(float(src.size()) / step)
		var g: float = AudioDsp.db_to_lin(float(e.gain_db))
		var at: int = int(float(e.t) * float(rate))
		if out.size() < at + n:
			out.resize(at + n)
		for j in range(n):
			var p: float = float(j) * step
			var i0: int = int(p)
			var f: float = p - float(i0)
			var a: float = src[i0]
			var b: float = src[i0 + 1] if i0 + 1 < src.size() else 0.0
			out[at + j] += (a + (b - a) * f) * g
	return out
