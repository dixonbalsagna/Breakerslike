extends SceneTree
## Does the babble voice behave? From the repo root:
##   godot --headless --path . --script res://audio/tools/babble_check.gd
## Checks (exit code 1 on any failure):
##   1. the babble clock is the text-reveal clock (ui/core/ui_bark_timing.gd): same total and same time for every character
##   2. plans are reproducible (same seed, same plan) and vary with the seed and the line
##   3. punctuation shapes the pitch: a question rises, an exclamation punches its last word, an ellipsis trails away
##   4. moods differ the way they should (pitch, pace, loudness), averaged over seeds
##   5. laughs and cue gestures become laugh and grunt events
##   6. the bank renders for every voice, and what it costs (time, memory)
##   7. babbling never changes the sim: the gameplay hash of a seeded match is the same with and without it

var bank: AudioBank
var bab: AudioBabble
var fails: int = 0


func _init() -> void:
	bank = AudioBank.new()
	bab = AudioBabble.new(bank)
	bab.reset(4)
	_clock()
	_repro()
	_punctuation()
	_moods()
	_gestures()
	_director_schema()
	_bank_cost()
	_sim_untouched()
	print("\nbabble check %s" % ("FAILED (%d)" % fails if fails > 0 else "passed"))
	quit(1 if fails > 0 else 0)


func ok(cond: bool, msg: String) -> void:
	print("  %s  %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		fails += 1


func _plan(voice: String, text: String, mood: String, intensity: int = 1, sd: int = 7, cues: Array = []) -> AudioBabble.Plan:
	return bab.plan(voice, text, mood, intensity, cues, sd)


func _syl(P: AudioBabble.Plan) -> Array:
	return P.events.filter(func(e): return e.kind == "syl")


func _mean(a: Array, key: String) -> float:
	var s: float = 0.0
	for e in a:
		s += float(e.get(key))
	return s / maxf(float(a.size()), 1.0)


func _clock() -> void:
	print("1. the clock")
	var path := "res://ui/core/ui_bark_timing.gd"
	if not ResourceLoader.exists(path):
		print("  skip  ui_bark_timing.gd is not in this checkout")
		return
	var U = load(path)
	var worst: float = 0.0
	for text in ["Good. You came. Now show me everything.", "Not the chip! Anything but the chip!", "...Enough. Leave.", "A, b; c: d - e — f … g"]:
		for inten in range(4):
			var T: PackedFloat64Array = bab.times(text, inten)
			worst = maxf(worst, absf(T[text.length()] - U.reveal_total(text, inten)))
			for i in range(0, text.length(), 3):
				worst = maxf(worst, absf(T[i] - U.time_for_char(text, i, inten)))
	ok(worst < 1e-6, "reveal times equal ui_bark_timing.gd's (worst difference %.9f s)" % worst)


func _repro() -> void:
	print("2. reproducible")
	var t := "That was somebody's roof. I'll help rebuild it once I'm done here."
	var a := _plan("protagonist", t, "hurt", 1, 11)
	var b := _plan("protagonist", t, "hurt", 1, 11)
	var c := _plan("protagonist", t, "hurt", 1, 12)
	var d := _plan("protagonist", t + "!", "hurt", 1, 11)
	ok(a.digest() == b.digest(), "same seed, same plan (%s)" % a.digest())
	ok(a.digest() != c.digest(), "another seed gives another plan")
	ok(a.digest() != d.digest(), "another line gives another plan")
	bab.reset(5)
	var l := {"id": "x.1", "text": t, "mood": "hurt", "intensity": 1}
	var s1 := SimCore.createSim()
	SimCore.newMatch(s1, 5)
	var p1: AudioBabble.Plan = bab.speak_line(s1, 0, l)
	bab.reset(5)
	var p2: AudioBabble.Plan = bab.speak_line(s1, 0, l)
	bab.reset(6)
	var p3: AudioBabble.Plan = bab.speak_line(s1, 0, l)
	SimCore.dispose(s1)
	ok(p1 != null and p1.digest() == p2.digest(), "speak_line: the same match seed and line give the same plan")
	ok(p1.digest() != p3.digest(), "speak_line: another match seed gives another plan")
	bab.reset(4)


func _punctuation() -> void:
	print("3. punctuation")
	var q := _syl(_plan("protagonist", "Is there really a manager here?", "neutral", 1, 3))
	var head: Array = q.slice(0, q.size() - 4)
	ok(q[q.size() - 1].st - _mean(head, "st") > 3.0, "a question rises: last syllable %.1f st against %.1f before" % [q[q.size() - 1].st, _mean(head, "st")])
	var e := _syl(_plan("protagonist", "I suppose that is that...", "neutral", 1, 3))
	var ehead: Array = e.slice(0, e.size() - 3)
	ok(e[e.size() - 1].gain_db < _mean(ehead, "gain_db") - 3.0 and e[e.size() - 1].st < _mean(ehead, "st") - 2.0, "an ellipsis trails away: last %.1f st %.1f dB, before %.1f st %.1f dB" % [e[e.size() - 1].st, e[e.size() - 1].gain_db, _mean(ehead, "st"), _mean(ehead, "gain_db")])
	var x := _syl(_plan("protagonist", "That was a great big brilliant CHIP!", "neutral", 1, 3))
	var xr: Array = x.slice(0, x.size() - 3)
	var top: float = -99.0
	for s in x.slice(x.size() - 3):
		top = maxf(top, s.st)
	ok(top - _mean(xr, "st") > 2.5, "an exclamation punches its last word: %.1f st against %.1f before" % [top, _mean(xr, "st")])
	var caps := _syl(_plan("empress", "We appeal and appeal and APPEAL.", "neutral", 1, 3))
	var m: float = _mean(caps.slice(0, caps.size() - 3), "gain_db")
	ok(caps[caps.size() - 3].gain_db > m + 1.5 or caps[caps.size() - 2].gain_db > m + 1.5, "an ALL-CAPS word is louder")


func _moods() -> void:
	print("4. moods (mean over 24 seeds, the same 60-character line)")
	var t := "Hold on now, this is going to take a little while, I think."
	var stat: Dictionary = {}
	for mood in ["neutral", "smug", "angry", "hurt", "desperate", "laughing"]:
		var st: float = 0.0
		var gap: float = 0.0
		var gain: float = 0.0
		var laughs: int = 0
		for s in range(24):
			var P := _plan("protagonist", t, mood, 1, 100 + s)
			var sy := _syl(P)
			st += _mean(sy, "st")
			gain += _mean(sy, "gain_db")
			gap += (sy[sy.size() - 1].t - sy[0].t) / maxf(float(sy.size() - 1), 1.0)
			laughs += P.count("laugh")
		stat[mood] = {"st": st / 24.0, "gap": gap / 24.0, "gain": gain / 24.0, "laughs": laughs}
		print("     %-9s pitch %+5.2f st, gap %.3f s, level %+5.1f dB, laughs %d" % [mood, st / 24.0, gap / 24.0, gain / 24.0, laughs])
	ok(stat.hurt.st < stat.neutral.st - 0.8 and stat.neutral.st < stat.desperate.st - 0.8, "pitch: hurt < neutral < desperate")
	ok(stat.angry.gap < stat.smug.gap, "pace: angry is quicker than smug")
	ok(stat.angry.gain > stat.hurt.gain + 3.0, "level: angry is louder than hurt")
	ok(stat.laughing.laughs > 0 and stat.neutral.laughs == 0, "laughing mood laughs, neutral does not")
	var digests: Dictionary = {}
	for v in ["protagonist", "anti_hero", "empress", "cyborg"]:
		var P := _plan(v, "Good. You came. Now show me everything.", "neutral")
		digests[P.digest()] = true
		for e in _syl(P):
			var syl: String = e.sound.split(".")[3]
			if not bank.babble.voices[v].lexicon.has(syl):
				ok(false, "%s spoke a syllable outside its lexicon: %s" % [v, syl])
	ok(digests.size() == 4, "the four voices babble differently")


func _gestures() -> void:
	print("5. laughs and gestures")
	var P := _plan("empress", "Ohoho. Cute. Cute!", "neutral")
	ok(P.count("laugh") >= 1, "\"Ohoho\" is a laugh event (%d)" % P.count("laugh"))
	var Q := _plan("protagonist", "Well then, here we go.", "neutral", 1, 7, [{"at": 0, "gesture": "laugh.short", "intensity": 2}, {"at": 10, "gesture": "sigh", "intensity": 1}])
	ok(Q.count("laugh") >= 1 and Q.count("grunt") >= 1, "cues become a laugh and a grunt (%d, %d)" % [Q.count("laugh"), Q.count("grunt")])
	var N := _plan("anti_hero", "Fine. Fine.", "hurt")
	var in_order := true
	for i in range(1, N.events.size()):
		in_order = in_order and N.events[i].t >= N.events[i - 1].t
	ok(in_order, "events are in time order")


func _director_schema() -> void:
	print("5b. Narrative's line schema and mood graph")
	var b: Dictionary = bank.babble
	var missing: Array = []
	for node in ["sizing_up", "playful", "cocky", "heated", "grim", "contemptuous", "rattled", "desperate", "triumphant", "spent", "reverent",
			"respectful-grim", "cold", "resolved", "polite", "hungry", "frantic", "grim-heated"]:
		var emo: String = String(b.mood_map.get(node, node))
		if not b.moods.has(emo):
			missing.append(node)
	ok(missing.is_empty(), "every mood node in dialogue-director.md maps to a babble mood (missing: %s)" % str(missing))
	var t := "He means it. That is what makes it unbearable."
	var cap := _plan("anti_hero", t, "contemptuous", 1, 21)
	var th := bab.plan("anti_hero", t, "contemptuous", 0, [], 21, "thought")
	var sh := bab.plan("anti_hero", t, "contemptuous", 3, [], 21, "shout")
	ok(th.inner and not cap.inner, "a thought is marked inner (played muffled)")
	ok(_mean(_syl(th), "gain_db") < _mean(_syl(cap), "gain_db") - 7.0, "a thought is quieter (%.1f against %.1f dB)" % [_mean(_syl(th), "gain_db"), _mean(_syl(cap), "gain_db")])
	ok(_syl(th).size() < _syl(cap).size(), "a thought is sparser (%d against %d syllables)" % [_syl(th).size(), _syl(cap).size()])
	ok(_mean(_syl(sh), "gain_db") > _mean(_syl(cap), "gain_db") + 2.0, "a shout is louder")
	var thl := bab.plan("protagonist", "Ha ha. Ohoho.", "playful", 0, [{"at": 0, "gesture": "laugh.short", "intensity": 1}], 3, "thought")
	ok(thl.count("laugh") == 0, "a thought never laughs aloud")
	var rat := bab.plan("anti_hero", "I can't feel my arms. Help me.", "rattled", 1, [], 5)
	var con := bab.plan("anti_hero", "I can't feel my arms. Help me.", "contemptuous", 1, [], 5)
	ok(rat.emotion == "cracked" and con.emotion == "smug", "the Anti-hero's rattled mood is his cracked-facade voice (%s, and %s otherwise)" % [rat.emotion, con.emotion])
	var s2 := SimCore.createSim()
	SimCore.newMatch(s2, 5)
	bab.reset(5)
	var line := {"id": "anti.callback.bridge.001", "kind": "thought", "text": t, "mood": "contemptuous", "cues": [], "display": {"style": "thought", "dur_s": 2.4}}
	var P: AudioBabble.Plan = bab.speak_line(s2, 1, line)
	SimCore.dispose(s2)
	ok(P != null and P.inner, "speak_line takes Narrative's line object (kind, display.style, mood, cues)")
	bab.reset(4)


func _bank_cost() -> void:
	print("6. the bank")
	var total_ms: float = 0.0
	for v in ["protagonist", "anti_hero", "empress", "cyborg"]:
		var t0: int = Time.get_ticks_usec()
		var bytes: int = 0
		var n: int = 0
		for id in bank.babble_ids([v]):
			for k in range(bank.variants(id)):
				var w: AudioStreamWAV = bank.stream(id, k)
				bytes += w.data.size()
				n += 1
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		total_ms += ms
		print("     %-10s %3d clips, %4.0f KB, %5.0f ms" % [v, n, float(bytes) / 1024.0, ms])
	ok(total_ms < 4000.0, "all four voices render in %.0f ms" % total_ms)
	var t1: int = Time.get_ticks_usec()
	var P := _plan("protagonist", "That was somebody's roof. I'll help rebuild it once I'm done here.", "hurt")
	var plan_ms: float = (Time.get_ticks_usec() - t1) / 1000.0
	ok(plan_ms < 5.0, "planning a 66-character line takes %.2f ms (%d events)" % [plan_ms, P.events.size()])


func _sim_untouched() -> void:
	print("7. the sim is untouched")
	var hashes: Array = []
	for with_babble in [false, true]:
		var S := SimCore.createSim()
		SimCore.newMatch(S, 4)
		bab.reset(4)
		for t in range(1200):
			SimCore.step(S)
			if with_babble and t % 120 == 0:
				bab.speak_line(S, t % 2, {"id": "t%d" % t, "text": "Hold on now, I'll be fine in a minute.", "mood": "desperate", "intensity": 2})
			S.out.fx.clear()
			S.out.feed.clear()
		hashes.append(SimHash.stateHash(S).gameplay)
		SimCore.dispose(S)
	ok(str(hashes[0]) == str(hashes[1]), "gameplay hash after 1200 ticks is the same with and without babbling (%s)" % str(hashes[0]))
