extends SceneTree
## Headless checks for the press reader (sim/input/press_read.gd, docs/controls/agency-input.md 1a): holds, rhythm, mash and
## taps, the precedence between them, the beat windows (touch, assist, the player's offset), staleness, the mix, the log's size
## and its helpers, and that the numbers come from data. Pure functions, so the checks are plain arrays. From the repo root:
##   godot --headless --path . --script res://sim/input/test/press_read_test.gd
## Exit 0 if every check passes.

var fails: int = 0
var checks: int = 0
const NB: int = SimPressRead.NO_BEAT


func ok(c: bool, what: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL  ", what)


func _init() -> void:
	SimInputData.load_and_apply()
	_data()
	_log()
	_hold()
	_rhythm()
	_mash()
	_taps_and_stale()
	_windows()
	_mix()
	_grades()
	_timing()
	_section20_steady()
	_section20_hitstop()
	_section20_recipe()
	_release()
	_determinism()
	print("press_read_test: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


## A log of presses at `ticks` (light), each with the given beat offset (or NB), all released 3 ticks after the press.
func _mk(ticks: Array, beats: Array = [], kinds: Array = [], modes: Array = []) -> Array:
	var log: Array = []
	for k in range(ticks.size()):
		var kind: int = int(kinds[k]) if k < kinds.size() else SimPressRead.LIGHT
		var mode: int = int(modes[k]) if k < modes.size() else 0
		var b: int = int(beats[k]) if k < beats.size() else NB
		SimPressRead.push(log, kind, mode, int(ticks[k]), b)
		SimPressRead.release(log, kind, int(ticks[k]) + 3)
	return log


func _data() -> void:
	var p: Dictionary = SimPressRead.params()
	ok(p["logSize"] == 20 and p["mixShort"] == 5 and p["expireTicks"] == 90, "data: the log holds 20 presses, the recipe reads the latest 5, a press expires after 90 ticks")
	ok(p["holdTicks"] == SimInputData.ti(["tapHold", "holdStart"], 12) and p["holdTicks"] == 12, "data: a hold is the game's hold, 12 ticks")
	ok(p["beatHalf"] == 4 and p["touchBeatHalf"] == 5, "data: the beat window is 8 ticks, 10 on touch")
	ok(p["mashPresses"] == 4 and p["mashGap"] == 10 and p["mashClear"] == 20, "data: a mash is 4 presses 10 ticks apart or fewer, over after 20")
	ok(SimInputData.ti(["read", "debounce"], -1) == 2, "data: the debounce is 2 ticks")
	# A value in the file moves the reader.
	var saved = SimInputData.timing.get("read", null)
	SimInputData.timing["read"] = (saved as Dictionary).duplicate()
	SimInputData.timing["read"]["mashGap"] = 6
	ok(SimPressRead.params()["mashGap"] == 6, "data: a changed mashGap in the data is the reader's")
	SimInputData.timing["read"] = saved


func _log() -> void:
	var log: Array = []
	for k in range(25):
		SimPressRead.push(log, SimPressRead.LIGHT, 0, 100 + k * 10)
	ok(log.size() == 20, "log: 25 presses leave the last 20")
	ok(int(log[0]["down"]) == 150 and int(log[19]["down"]) == 340, "log: oldest first, the oldest dropped")
	SimPressRead.release(log, SimPressRead.LIGHT, 345)
	ok(int(log[19]["up"]) == 345 and int(log[18]["up"]) == -1, "log: a release closes the latest held entry of its kind")
	var l2: Array = []
	SimPressRead.push(l2, SimPressRead.LIGHT, 0, 10)
	SimPressRead.push(l2, SimPressRead.HEAVY, 0, 12)
	SimPressRead.release(l2, SimPressRead.LIGHT, 14)
	ok(int(l2[0]["up"]) == 14 and int(l2[1]["up"]) == -1, "log: a release closes its own kind, not the latest entry")
	ok(SimPressRead.beat_offset(100, []) == NB, "beat: no blows is no beat")
	ok(SimPressRead.beat_offset(100, [90, 103, 130]) == -3, "beat: the nearest blow, and early is negative")
	ok(SimPressRead.beat_offset(100, [96]) == 4, "beat: late is positive")
	ok(SimPressRead.classify([], 100)["style"] == "none", "classify: an empty log reads as nothing")


func _hold() -> void:
	var log: Array = []
	SimPressRead.push(log, SimPressRead.HEAVY, 0, 100)
	ok(SimPressRead.classify(log, 105)["style"] == "taps" and SimPressRead.classify(log, 105)["hold_ticks"] == 5, "hold: down 5 ticks is not yet a hold")
	ok(SimPressRead.classify(log, 111)["style"] != "hold", "hold: 11 ticks is not a hold")
	var c: Dictionary = SimPressRead.classify(log, 112)
	ok(c["style"] == "hold" and c["hold_ticks"] == 12, "hold: 12 ticks down is a hold, live, before the release")
	ok(SimPressRead.classify(log, 400)["style"] == "hold", "hold: a button still down stays a hold however long")
	SimPressRead.release(log, SimPressRead.HEAVY, 130)
	ok(SimPressRead.classify(log, 131)["style"] == "taps", "hold: released, it is over")
	# A tap that is released inside 12 ticks is never a hold.
	var t: Array = _mk([100])
	ok(SimPressRead.classify(t, 103)["style"] == "taps", "hold: a tap released at 3 ticks is a tap")
	# A hold beats a rhythm and a mash.
	var m: Array = _mk([100, 108, 116, 124], [0, 0, 0, 0])
	SimPressRead.push(m, SimPressRead.LIGHT, 0, 130, 0)
	ok(SimPressRead.classify(m, 143)["style"] == "hold", "hold: the precedence puts a hold over a rhythm and a mash")


func _rhythm() -> void:
	# Three presses 15 ticks apart, each within 2 ticks of a blow.
	var log: Array = _mk([100, 115, 130], [1, -2, 0])
	var c: Dictionary = SimPressRead.classify(log, 133)
	ok(c["style"] == "rhythm" and c["on_beat"] == 3, "rhythm: three presses on the blows")
	# Two of three on the beat is enough; one is not.
	ok(SimPressRead.classify(_mk([100, 115, 130], [1, 9, -3]), 133)["style"] == "rhythm", "rhythm: two of the last three is rhythm")
	ok(SimPressRead.classify(_mk([100, 115, 130], [1, 9, -9]), 133)["style"] == "taps", "rhythm: one of three is not")
	# Only the last three count: an old on-beat press does not.
	ok(SimPressRead.classify(_mk([60, 80, 100, 115, 130], [0, 0, 9, 9, 0]), 133)["on_beat"] == 1, "rhythm: only the last three presses count")
	# Presses outside an exchange have no beat.
	ok(SimPressRead.classify(_mk([100, 115, 130]), 133)["style"] == "taps", "rhythm: no beat to be on, no rhythm")
	# A mash that lands on the blows is rhythm, not a mash.
	var fast: Array = _mk([100, 107, 114, 121], [0, 1, 0, -1])
	ok(SimPressRead.classify(fast, 124)["style"] == "rhythm", "rhythm: a mash on the blows is rhythm")
	# Two presses on the beat from a fresh log count (2 of 2).
	ok(SimPressRead.classify(_mk([100, 115], [0, 1]), 118)["style"] == "rhythm", "rhythm: the second on-beat press makes it")
	ok(SimPressRead.classify(_mk([100], [0]), 103)["style"] == "taps", "rhythm: one press is not yet rhythm")


func _mash() -> void:
	var log: Array = _mk([100, 108, 116, 124])
	var c: Dictionary = SimPressRead.classify(log, 127)
	ok(c["style"] == "mash", "mash: four presses 8 ticks apart")
	ok(absf(float(c["rate"]) - 7.5) < 0.01, "mash: the rate is 7.5 presses a second")
	ok(SimPressRead.classify(_mk([100, 110, 120, 130]), 133)["style"] == "mash", "mash: gaps of exactly 10 still count")
	ok(SimPressRead.classify(_mk([100, 111, 122, 133]), 136)["style"] == "taps", "mash: gaps of 11 do not")
	ok(SimPressRead.classify(_mk([100, 108, 116]), 119)["style"] == "taps", "mash: three presses are not enough")
	ok(SimPressRead.classify(_mk([100, 130, 138, 146, 154]), 157)["style"] == "mash", "mash: the last four decide, an earlier slow press does not")
	ok(SimPressRead.classify(_mk([100, 108, 116, 124]), 145)["style"] == "taps", "mash: over after 20 ticks without a press")
	ok(SimPressRead.classify(_mk([100, 108, 116, 124]), 144)["style"] == "mash", "mash: still on at 20 ticks")
	# A jittered mash, as a person does it.
	ok(SimPressRead.classify(_mk([100, 106, 116, 123, 133]), 136)["style"] == "mash", "mash: a jittered mash")
	# Alternating light and heavy is still a mash.
	ok(SimPressRead.classify(_mk([100, 108, 116, 124], [], [0, 1, 0, 1]), 127)["style"] == "mash", "mash: light and heavy together are a mash")


func _taps_and_stale() -> void:
	var log: Array = _mk([100, 125, 150])
	ok(SimPressRead.classify(log, 153)["style"] == "taps", "taps: presses spaced out and off the beat")
	ok(SimPressRead.classify(log, 150 + 60)["style"] == "taps", "taps: still read at the stale limit")
	ok(SimPressRead.classify(log, 150 + 61)["style"] == "none", "taps: a log older than 60 ticks reads as nothing")


func _windows() -> void:
	var log: Array = _mk([100, 115], [4, -4])
	ok(SimPressRead.classify(log, 118)["style"] == "rhythm", "window: plus and minus 4 is on the beat (8 ticks)")
	var wide: Array = _mk([100, 115], [5, -5])
	ok(SimPressRead.classify(wide, 118)["style"] == "taps", "window: 5 is off the beat")
	ok(SimPressRead.classify(wide, 118, {"touch": true})["style"] == "rhythm", "window: 5 is on the beat on touch (10 ticks)")
	var wider: Array = _mk([100, 115], [8, -8])
	ok(SimPressRead.classify(wider, 118, {"assist": true})["style"] == "rhythm", "window: assist doubles it (8)")
	ok(SimPressRead.classify(wider, 118)["style"] == "taps", "window: and without assist 8 is off")
	# The player's timing offset moves where the beat is for them.
	var late: Array = _mk([100, 115], [7, 6])
	ok(SimPressRead.classify(late, 118)["style"] == "taps", "window: a player who presses 6 to 7 ticks late misses")
	ok(SimPressRead.classify(late, 118, {"offset": 6})["style"] == "rhythm", "window: their offset of 6 puts them on the beat")


func _mix() -> void:
	var log: Array = _mk([100, 115, 130, 145, 160], [], [0, 0, 1, 1, 2], [0, 1, 1, 0, 0])
	var c: Dictionary = SimPressRead.classify(log, 163)
	var ms: Dictionary = c["mix_short"]
	var ml: Dictionary = c["mix_long"]
	ok(ms["light"] == 2 and ms["heavy"] == 2 and ms["sig"] == 1 and ms["energy"] == 2, "mix: the latest five presses (the recipe's read: 2 light, 2 heavy, 1 signature, 2 energy)")
	ok(ml == ms, "mix: with only five presses the long mix is the same")
	# The long mix reads 20: eight lights, then three heavies, 8 ticks apart.
	var ticks: Array = []
	var kinds: Array = []
	for k in range(11):
		ticks.append(100 + k * 8)
		kinds.append(0 if k < 8 else 1)
	var long_log: Array = _mk(ticks, [], kinds)
	var c2: Dictionary = SimPressRead.classify(long_log, 183)
	ok(c2["mix_long"]["light"] == 8 and c2["mix_long"]["heavy"] == 3, "mix: the long mix counts every unexpired press (8 light, 3 heavy)")
	ok(c2["mix_short"]["light"] == 2 and c2["mix_short"]["heavy"] == 3, "mix: and the short mix the latest five (2 light, 3 heavy)")
	ok(SimPressRead.classify(long_log, 190)["mix_long"]["light"] == 8, "mix: a press exactly 90 ticks old still counts")
	var c3: Dictionary = SimPressRead.classify(long_log, 191)
	ok(c3["mix_long"]["light"] == 8 and c3["mix_long"]["heavy"] == 3, "mix: old presses stay while the window is live (section 20: the lapse is of the whole window, not press by press)")
	ok(SimPressRead.classify(long_log, 270)["mix_long"]["heavy"] == 3, "mix: 90 ticks after the last press the window is still whole")
	var cold: Dictionary = SimPressRead.classify(long_log, 271)
	ok(cold["mix_long"]["light"] == 0 and cold["mix_long"]["heavy"] == 0 and cold["mix_short"]["heavy"] == 0 and cold["presses"] == 0, "mix: after 90 idle ticks the whole window is empty")


func _determinism() -> void:
	var a: Array = _mk([100, 108, 116, 124], [0, 3, -2, 1])
	var b: Array = _mk([100, 108, 116, 124], [0, 3, -2, 1])
	ok(str(SimPressRead.classify(a, 127)) == str(SimPressRead.classify(b, 127)), "same log, same reading")
	var before: String = str(a)
	SimPressRead.classify(a, 127)
	ok(str(a) == before, "classify does not change the log")


func _grades() -> void:
	ok(SimPressRead.grade_of(0) == "perfect" and SimPressRead.grade_of(4) == "perfect" and SimPressRead.grade_of(-4) == "perfect", "grade: within 4 ticks is perfect")
	ok(SimPressRead.grade_of(5) == "good" and SimPressRead.grade_of(-8) == "good", "grade: within 8 is good")
	ok(SimPressRead.grade_of(9) == "off", "grade: past 8 is off")
	ok(SimPressRead.grade_of(5, {"touch": true}) == "perfect" and SimPressRead.grade_of(11, {"touch": true}) == "off", "grade: touch widens the perfect window to 5")
	ok(SimPressRead.grade_of(8, {"assist": true}) == "perfect" and SimPressRead.grade_of(16, {"assist": true}) == "good", "grade: assist doubles both windows")
	ok(SimPressRead.grade_of(7, {"offset": 6}) == "perfect", "grade: the player's offset shifts the mark")


func _timing() -> void:
	# A steady mash is perfect; a ragged one is not.
	var steady: Dictionary = SimPressRead.classify(_mk([100, 108, 116, 124], [0, 1, 0, -1]), 127)
	ok(steady["steady"] and steady["timing"] == "perfect", "timing: an even mash on the blows is steady, a perfect blur")
	var blind: Dictionary = SimPressRead.classify(_mk([100, 108, 116, 124]), 127)
	ok(blind["style"] == "mash" and not blind["steady"] and blind["timing"] == "none", "timing: the same spacing with no blows to be on is a mash, not steady")
	var ragged: Dictionary = SimPressRead.classify(_mk([100, 106, 116, 123]), 126)
	ok(ragged["style"] == "mash" and not ragged["steady"] and ragged["timing"] == "none", "timing: a ragged mash is a mash, not a perfect one")
	ok(SimPressRead.classify(_mk([100, 108, 117, 125], [0, 0, 0, 0]), 128)["steady"], "timing: gaps of 8, 9, 8 on the blows are steady (within 3)")
	ok(SimPressRead.classify(_mk([100, 108, 121, 129], [0, 0, 0, 0]), 132)["steady"], "timing: gaps of 8, 13, 8 on the blows are steady (no spacing test)")
	# Taps in time: perfect after three in a row, good before.
	var three: Dictionary = SimPressRead.classify(_mk([100, 115, 130], [0, 2, -3]), 133)
	ok(three["style"] == "rhythm" and three["streak"] == 3 and three["timing"] == "perfect", "timing: three perfect taps in a row land clean (perfect)")
	var two: Dictionary = SimPressRead.classify(_mk([100, 115], [0, 2]), 118)
	ok(two["style"] == "rhythm" and two["streak"] == 2 and two["timing"] == "good", "timing: two perfect taps are good, not yet perfect")
	var broken: Dictionary = SimPressRead.classify(_mk([100, 115, 130], [0, 9, 1]), 133)
	ok(broken["streak"] == 1 and broken["timing"] == "good", "timing: an off press breaks the streak (rhythm, but only good)")
	var plain: Dictionary = SimPressRead.classify(_mk([100, 125, 150]), 153)
	ok(plain["style"] == "taps" and plain["timing"] == "none", "timing: taps off the beat have no timing")
	ok(SimPressRead.classify(_mk([100, 125, 150], [0, 30, 30]), 153)["timing"] == "good", "timing: taps with one perfect press are good")


func _release() -> void:
	var log: Array = []
	SimPressRead.push(log, SimPressRead.HEAVY, 0, 100)
	ok(SimPressRead.release_grade(log[0]) == "none", "release: no flash, no grade")
	SimPressRead.set_flash(log, SimPressRead.HEAVY, 136)
	ok(int(log[0]["flash"]) == 136 and SimPressRead.release_grade(log[0]) == "held", "release: still held, flashed at 136")
	var c: Dictionary = SimPressRead.classify(log, 140)
	ok(c["style"] == "hold" and c["timing"] == "none" and c["release"] == "none", "release: a held charge is a hold with no grade yet")
	SimPressRead.release(log, SimPressRead.HEAVY, 138)
	ok(SimPressRead.release_grade(log[0]) == "perfect", "release: let go 2 ticks after the flash is perfect (a hold released on the flash)")
	c = SimPressRead.classify(log, 139)
	ok(c["release"] == "perfect", "release: classify reports it")
	var cases: Array = [[132, "perfect"], [140, "perfect"], [143, "good"], [128, "good"], [120, "early"], [150, "late"]]
	for k in cases:
		var l2: Array = []
		SimPressRead.push(l2, SimPressRead.LIGHT, 0, 100)
		SimPressRead.set_flash(l2, SimPressRead.LIGHT, 136)
		SimPressRead.release(l2, SimPressRead.LIGHT, int(k[0]))
		ok(SimPressRead.release_grade(l2[0]) == k[1], "release: let go at %d with the flash at 136 is %s" % [k[0], k[1]])
	# Touch, assist and the offset apply to a release as to a press.
	var l3: Array = []
	SimPressRead.push(l3, SimPressRead.LIGHT, 0, 100)
	SimPressRead.set_flash(l3, SimPressRead.LIGHT, 136)
	SimPressRead.release(l3, SimPressRead.LIGHT, 141)
	ok(SimPressRead.release_grade(l3[0]) == "good" and SimPressRead.release_grade(l3[0], {"touch": true}) == "perfect", "release: touch widens the flash window")
	SimPressRead.release(l3, SimPressRead.LIGHT, 141)
	# A release on the flash lifts a hold; the next press is read fresh.
	var l4: Array = []
	SimPressRead.push(l4, SimPressRead.HEAVY, 0, 100)
	SimPressRead.set_flash(l4, SimPressRead.HEAVY, 136)
	SimPressRead.release(l4, SimPressRead.HEAVY, 136)
	SimPressRead.push(l4, SimPressRead.LIGHT, 0, 150)
	var c4: Dictionary = SimPressRead.classify(l4, 153)
	ok(c4["release"] == "perfect" and c4["style"] == "taps", "release: the latest release grade stays available after the next press")


## A log of presses at `press_ticks` against blow contacts at `blows` (each press's beat is its distance to the nearest blow).
func _beat_log(press_ticks: Array, blows: Array) -> Array:
	var log: Array = []
	for pt in press_ticks:
		SimPressRead.push(log, SimPressRead.LIGHT, 0, int(pt), SimPressRead.beat_offset(int(pt), blows))
		SimPressRead.release(log, SimPressRead.LIGHT, int(pt) + 3)
	return log


## Section 20 (ruled: four on-beat presses within 2 ticks): steady needs the blows. A blind metronome against a blur's cadence.
func _section20_steady() -> void:
	var p: Dictionary = SimPressRead.params()
	var need: int = int(p["steadyPresses"])
	ok(need == 4 and p["blurBeatHalf"] == 2 and p["blurBeatBonus"] == 0 and p["powerShare"] == 60, "s20 data: four presses, 2 ticks, no bonus, power over 60 percent")
	# Presses on the contacts, for each cadence in the set, are steady and a perfect blur.
	for cad in [7, 8, 9, 10]:
		var blows: Array = []
		for k in range(16):
			blows.append(100 + cad * k)
		var on: Array = []
		for k in range(need):
			on.append(100 + cad * (2 + k))
		var c: Dictionary = SimPressRead.classify(_beat_log(on, blows), on[need - 1] + 3)
		ok(c["steady"] and c["timing"] == "perfect", "s20: %d presses on the contacts of a %d-tick cadence are steady and perfect" % [need, cad])
		ok(not SimPressRead.classify(_beat_log(on.slice(1), blows), on[need - 1] + 3)["steady"], "s20: one fewer is not enough (%d-tick cadence)" % cad)
		# A person's jitter of 1 tick is still on them; 3 ticks is not.
		var near: Array = []
		for k in range(need):
			near.append(int(on[k]) + (1 if k < need / 2 else -1))
		ok(SimPressRead.classify(_beat_log(near, blows), near[need - 1] + 3)["steady"], "s20: 1 tick of jitter on a %d-tick cadence is still steady" % cad)
		var off: Array = on.duplicate()
		off[need - 2] += 3
		ok(not SimPressRead.classify(_beat_log(off, blows), off[need - 1] + 3)["steady"], "s20: one press 3 ticks off a %d-tick cadence breaks it" % cad)
	# The two bands over whole strings, with the ruled numbers. Blind: an 8-tick metronome at any phase against each cadence,
	# the four cadences equally likely, steady at ANY point of a string of 8, 12 and 20 presses.
	var line: String = ""
	for length in [8, 12, 20]:
		var hit: Dictionary = {}
		for cad in [7, 8, 9, 10]:
			var blows2: Array = []
			for k in range(40):
				blows2.append(100 + cad * k)
			var n_hit: int = 0
			for phase in range(cad):
				var pt: Array = []
				for k in range(length):
					pt.append(100 + phase + 8 * k)
				if _steady_somewhere(pt, blows2):
					n_hit += 1
			hit[cad] = n_hit
		var share: float = (0.25 * float(hit[7]) / 7.0 + 0.25 * float(hit[8]) / 8.0 + 0.25 * float(hit[9]) / 9.0 + 0.25 * float(hit[10]) / 10.0) * 100.0
		line += " %d presses: %.1f%% (cadence 7: %d of 7 phases, 8: %d of 8, 9: %d of 9, 10: %d of 10);" % [length, share, hit[7], hit[8], hit[9], hit[10]]
	print("s20 measured, blind 8-tick masher on SYNTHETIC contacts with no hit-stop (information only; the band is asserted under live spacing below):" + line)
	# The script that presses on every contact: every cadence, strings of 8 presses or more.
	var script_hits: int = 0
	var script_total: int = 0
	for length in [8, 12, 20]:
		for cad in [7, 8, 9, 10]:
			var blows3: Array = []
			for k in range(40):
				blows3.append(100 + cad * k)
			var pt3: Array = []
			for k in range(length):
				pt3.append(100 + cad * k)
			script_total += 1
			if _steady_somewhere(pt3, blows3):
				script_hits += 1
	ok(script_hits * 100 >= script_total * 80, "s20: the on-contact script earns the perfect blur on at least 80 percent of strings of 8 presses or more, synthetic contacts (%d of %d)" % [script_hits, script_total])
	# A human-ish script: each press within one tick of its contact, a seeded jitter, strings of 8 to 20 presses.
	var rng := SimRng.new(2026)
	var strings: Array = []
	for length in [8, 12, 20]:
		for cad in [7, 8, 9, 10]:
			for rep in range(25):
				var pt4: Array = []
				for k in range(length):
					pt4.append(100 + cad * k + int(floor(rng.next() * 3.0)) - 1)
				strings.append([cad, pt4])
	var h_hits: int = 0
	for sc in strings:
		var blows4: Array = []
		for k in range(40):
			blows4.append(100 + int(sc[0]) * k)
		if _steady_somewhere(sc[1], blows4):
			h_hits += 1
	print("s20 measured, a player with uniform jitter of up to one tick on every contact (synthetic contacts): %d of %d strings (%.0f%%)" % [h_hits, strings.size(), 100.0 * float(h_hits) / float(strings.size())])
	ok(h_hits * 100 >= strings.size() * 80, "s20: a player within one tick of every contact earns it on at least 80 percent of strings")
	# Touch and 30 fps get no extra tolerance (ruled); the assist still doubles the window, and the offset moves the mark.
	var blows5: Array = []
	for k in range(14):
		blows5.append(100 + 8 * k)
	var late3: Array = []
	for k in range(need):
		late3.append(100 + 8 * (2 + k) + 3)
	var l3: Array = _beat_log(late3, blows5)   # 3 ticks late each time, even
	var at3: int = int(late3[need - 1]) + 3
	ok(not SimPressRead.classify(l3, at3)["steady"], "s20: 3 ticks late each time is outside the blur's 2")
	ok(not SimPressRead.classify(l3, at3, {"touch": true})["steady"], "s20: touch gets no extra tolerance for the blur's beat")
	ok(not SimPressRead.classify(l3, at3, {"slow": true})["steady"], "s20: nor does a 30 fps client")
	ok(SimPressRead.classify(l3, at3, {"assist": true})["steady"], "s20: the assist (accessibility) still doubles the window")
	ok(SimPressRead.classify(l3, at3, {"offset": 3})["steady"], "s20: and the player's timing offset moves the mark")
	# The EP's rule: no spacing test. Any gaps on different blows are steady; the opener's 28 and 44 ticks, then a cadence.
	for cad in [7, 8, 9, 10]:
		var opener: Array = [100, 128, 172, 172 + cad, 172 + 2 * cad]
		ok(SimPressRead.classify(_beat_log(opener.slice(0, 4), opener), opener[3] + 3)["steady"], "s20: presses on the contacts with gaps 28, 44 and %d are steady" % cad)
		ok(SimPressRead.classify(_beat_log(opener.slice(1, 5), opener), opener[4] + 3)["steady"], "s20: and gaps 44, %d and %d (the opener's tail) are steady" % [cad, cad])
		var live: Array = [100, 100 + cad + 4, 100 + 2 * (cad + 4), 100 + 3 * (cad + 4)]
		ok(SimPressRead.classify(_beat_log(live, live), live[3] + 3)["steady"], "s20: contacts a cadence of %d plus 4 ticks of hit-stop apart are steady" % cad)
		var live5: Array = [100, 100 + cad + 5, 100 + 2 * (cad + 5), 100 + 3 * (cad + 5)]
		ok(SimPressRead.classify(_beat_log(live5, live5), live5[3] + 3)["steady"], "s20: and a cadence of %d plus 5 ticks of hit-stop" % cad)
	# Two presses on one blow count once.
	var blows7: Array = [100, 128, 172, 180, 188]
	var twice: Array = _beat_log([128, 130, 172, 180], blows7)
	ok(not SimPressRead.classify(twice, 183)["steady"], "s20: two presses on one blow do not count twice (128 and 130 are one blow)")
	var thrice: Array = _beat_log([100, 128, 172, 180, 188, 188 + 1], [100, 128, 172, 180, 188])
	ok(not SimPressRead.classify(thrice, 192)["steady"], "s20: a double press on the last blow breaks the last four")
	# A press 4 ticks late is not on the blow.
	var late4: Array = _beat_log([100, 128, 172, 184], [100, 128, 172, 180])
	ok(not SimPressRead.classify(late4, 187)["steady"], "s20: a press 4 ticks late is not steady")
	var late2: Array = _beat_log([100, 128, 172, 182], [100, 128, 172, 180])
	ok(SimPressRead.classify(late2, 185)["steady"], "s20: 2 ticks late is still on the blow")
	# An off-beat press between them breaks it, and four clean presses after it make it again.
	var blows8: Array = [100, 128, 172, 180, 188, 196, 204]
	var broken: Array = _beat_log([100, 128, 150, 172, 180], blows8)
	ok(not SimPressRead.classify(broken, 183)["steady"], "s20: a press off every blow among the last four breaks it")
	var healed: Array = _beat_log([100, 128, 150, 172, 180, 188, 196], blows8)
	ok(SimPressRead.classify(healed, 199)["steady"], "s20: four clean presses after it are steady again")
	# Out of order or outside an exchange: no blows, no steady.
	ok(not SimPressRead.classify(_beat_log([100, 128, 172, 180], []), 183)["steady"], "s20: with no blows to be on there is no steady")
	# No absolute spacing: gaps of 12, 13 and 15 on the beat are steady (live contacts are a cadence plus the hit-stop apart).
	for gap in [11, 12, 13, 14, 15]:
		var even: Array = []
		for k in range(need):
			even.append(100 + gap * k)
		ok(SimPressRead.classify(_beat_log(even, even), even[need - 1] + 3)["steady"], "s20: %d presses on the beat %d ticks apart are steady (no absolute gap cap)" % [need, gap])


## Whether the log of these presses (the latest 8 at each step, as the director keeps them) is steady at any point.
func _steady_somewhere(press_ticks: Array, blows: Array, opts: Dictionary = {}) -> bool:
	for k in range(press_ticks.size()):
		var sub: Array = press_ticks.slice(maxi(0, k - 7), k + 1)
		if SimPressRead.classify(_beat_log(sub, blows), int(sub[sub.size() - 1]) + 3, opts)["steady"]:
			return true
	return false


## Live contacts: a blur's blows are a cadence of 7 to 10 live ticks plus the chain strike's hit-stop (4 to 5 ticks) apart, because
## S.tick runs through hit-stop, so presses on the contacts are 11 to 15 ticks apart (Encounter measured 11, 12, 12, 12 at cadence 7).
## `hs` is the hit-stop per blow: 4, 5, or "mixed" (a seeded 4 or 5 each blow).
func _live_contacts(cad: int, hs: String, count: int, seed_: int) -> Array:
	var r := SimRng.new(seed_)
	var out: Array = []
	var at: int = 100
	for k in range(count):
		out.append(at)
		var h: int = 4 if hs == "4" else (5 if hs == "5" else (4 + int(floor(r.next() * 2.0))))
		at += cad + h
	return out


## The opener a TRADE BLOWS string starts with: blows 28 and 44 ticks apart, then the cadence plus hit-stop.
func _opener_contacts(cad: int, hs: String, count: int, seed_: int) -> Array:
	var r := SimRng.new(seed_)
	var out: Array = [100, 128, 172]
	var at: int = 172
	while out.size() < count:
		var h: int = 4 if hs == "4" else (5 if hs == "5" else (4 + int(floor(r.next() * 2.0))))
		at += cad + h
		out.append(at)
	return out


func _section20_hitstop() -> void:
	var combos: Array = []
	for cad in [7, 8, 9, 10]:
		for hs in ["4", "5", "mixed"]:
			combos.append([cad, hs])
	# Encounter's measured case: contacts 11, 12, 12, 12 ticks apart.
	var measured: Array = [100, 111, 123, 135, 147]
	ok(SimPressRead.classify(_beat_log(measured.slice(0, 4), measured), 138)["steady"], "hit-stop: presses on contacts 11, 12, 12 apart (measured at cadence 7) are steady")
	# The script that presses on every contact, every cadence and hit-stop, strings of 8 presses or more.
	var script_hits: int = 0
	var script_total: int = 0
	for length in [5, 8, 12, 20]:
		for c in combos:
			var blows: Array = _live_contacts(int(c[0]), str(c[1]), 40, 11 + length)
			var pt: Array = blows.slice(0, length)
			script_total += 1
			if _steady_somewhere(pt, blows):
				script_hits += 1
	print("hit-stop measured, on-contact script: %d of %d strings steady (%.0f%%)" % [script_hits, script_total, 100.0 * float(script_hits) / float(script_total)])
	ok(script_hits * 100 >= script_total * 80, "hit-stop: the on-contact script earns the perfect blur on at least 80 percent of strings (five blows or more) under live spacing")
	# The same with the opener's rhythm (blows 28 and 44 apart before the links), strings of five blows or more.
	var op_hits: int = 0
	var op_total: int = 0
	for length in [5, 8, 12]:
		for c in combos:
			var blows_o: Array = _opener_contacts(int(c[0]), str(c[1]), 40, 70 + length)
			op_total += 1
			if _steady_somewhere(blows_o.slice(0, length), blows_o):
				op_hits += 1
	print("opener measured, on-contact script (28 and 44 ticks, then the cadence plus hit-stop): %d of %d strings steady (%.0f%%)" % [op_hits, op_total, 100.0 * float(op_hits) / float(op_total)])
	ok(op_hits * 100 >= op_total * 80, "opener: the on-contact script earns the perfect blur on at least 80 percent of strings that start with the 28 and 44 tick opener (five blows or more)")
	var op_blind: float = 0.0
	for length in [5, 8, 12]:
		var o_total: float = 0.0
		var o_hits: float = 0.0
		for c in combos:
			var blows_b: Array = _opener_contacts(int(c[0]), str(c[1]), 60, 900 + length)
			var o_n: int = 0
			for phase in range(40):
				var ptb: Array = []
				for k in range(length):
					ptb.append(100 + phase + 8 * k)
				if _steady_somewhere(ptb, blows_b):
					o_n += 1
			o_hits += float(o_n) / 40.0
			o_total += 1.0
		op_blind = maxf(op_blind, 100.0 * o_hits / o_total)
	print("opener measured, blind 8-tick masher, worst of strings of 5, 8 and 12 presses: %.1f%%" % op_blind)
	ok(op_blind <= 20.0, "opener: a blind 8-tick masher earns the perfect blur on at most 20 percent of strings with the opener (%.1f)" % op_blind)
	# A person within one tick of every contact (seeded jitter).
	var rng := SimRng.new(77)
	var h_hits: int = 0
	var h_total: int = 0
	for length in [5, 8, 12, 20]:
		for c in combos:
			for rep in range(8):
				var blows2: Array = _live_contacts(int(c[0]), str(c[1]), 40, 500 + rep)
				var pt2: Array = []
				for k in range(length):
					pt2.append(int(blows2[k]) + int(floor(rng.next() * 3.0)) - 1)
				h_total += 1
				if _steady_somewhere(pt2, blows2):
					h_hits += 1
	print("hit-stop measured, uniform jitter of up to one tick on every contact: %d of %d strings (%.0f%%)" % [h_hits, h_total, 100.0 * float(h_hits) / float(h_total)])
	# The blind 8-tick masher under live spacing: every phase of every spacing, equally likely.
	var line: String = ""
	var worst_share: float = 0.0
	for length in [5, 8, 12, 20]:
		var total_phases: float = 0.0
		var hits: float = 0.0
		for c in combos:
			var blows3: Array = _live_contacts(int(c[0]), str(c[1]), 60, 900 + length)
			var period: int = int(c[0]) + 4
			var n_hit: int = 0
			for phase in range(period + 2):
				var pt3: Array = []
				for k in range(length):
					pt3.append(100 + phase + 8 * k)
				if _steady_somewhere(pt3, blows3):
					n_hit += 1
			hits += float(n_hit) / float(period + 2)
			total_phases += 1.0
		var share: float = 100.0 * hits / total_phases
		worst_share = maxf(worst_share, share)
		line += " %d presses: %.1f%%;" % [length, share]
	print("hit-stop measured, blind 8-tick masher:" + line)
	ok(worst_share <= 20.0, "hit-stop: a blind 8-tick masher earns the perfect blur on at most 20 percent of strings under live spacing, at every string length (worst %.1f)" % worst_share)
	# Which blind rates can ride a live spacing: a metronome whose gap equals the spacing keeps the beat by luck of phase.
	var rate_line: String = ""
	for gap in [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]:
		var rh: int = 0
		var rt: int = 0
		for c in combos:
			var blows4: Array = _live_contacts(int(c[0]), "4", 60, 31)
			for phase in range(int(c[0]) + 6):
				var pt4: Array = []
				for k in range(12):
					pt4.append(100 + phase + gap * k)
				rt += 1
				if _steady_somewhere(pt4, blows4):
					rh += 1
		rate_line += " %d:%.0f%%" % [gap, 100.0 * float(rh) / float(rt)]
	print("hit-stop measured, blind metronome by gap (strings of 12, hit-stop 4, share of phases and cadences):" + rate_line)
	# The assist still doubles the window under live spacing.
	var blows5: Array = _live_contacts(7, "4", 20, 3)
	var late: Array = []
	for k in range(int(SimPressRead.params()["steadyPresses"])):
		late.append(int(blows5[2 + k]) + 3)
	var ll: Array = _beat_log(late, blows5)
	ok(not SimPressRead.classify(ll, int(late[late.size() - 1]) + 3)["steady"] and SimPressRead.classify(ll, int(late[late.size() - 1]) + 3, {"assist": true})["steady"], "hit-stop: 3 ticks late each time is not steady, and the assist's doubled window makes it so")


func _section20_recipe() -> void:
	var lone: Array = []
	SimPressRead.push(lone, SimPressRead.HEAVY, 0, 100)
	ok(SimPressRead.classify(lone, 103)["recipe"] == "power", "s20 recipe: one heavy alone reads power")
	var lone_l: Array = []
	SimPressRead.push(lone_l, SimPressRead.LIGHT, 0, 100)
	ok(SimPressRead.classify(lone_l, 103)["recipe"] == "blur", "s20 recipe: one light alone is blur")
	ok(SimPressRead.classify([], 103)["recipe"] == "none", "s20 recipe: no presses, none")
	var two: Array = _mk([100, 130], [], [1, 1])
	ok(SimPressRead.classify(two, 133)["recipe"] == "power", "s20 recipe: two heavies running read power")
	var mixed: Array = _mk([100, 130, 160], [], [0, 1, 0])
	ok(SimPressRead.classify(mixed, 163)["recipe"] == "combo", "s20 recipe: a heavy among lights (one in three) is a combo")
	# Four heavies 47 ticks apart: the old press-by-press expiry could never hold them; the window does.
	var four: Array = _mk([100, 147, 194, 241], [], [1, 1, 1, 1])
	var c4: Dictionary = SimPressRead.classify(four, 244)
	ok(c4["recipe"] == "power" and c4["mix_short"]["heavy"] == 4 and c4["presses"] == 4, "s20 recipe: four heavies 47 ticks apart read power, all four present")
	# Five presses: the old rule exactly (none blur, one to three combo, four or five power).
	var rules: Array = [[0, "blur"], [1, "combo"], [2, "combo"], [3, "combo"], [4, "power"], [5, "power"]]
	for r in rules:
		var kinds: Array = []
		for k in range(5):
			kinds.append(1 if k < int(r[0]) else 0)
		var l5: Array = _mk([100, 110, 120, 130, 140], [], kinds)
		ok(SimPressRead.classify(l5, 143)["recipe"] == r[1], "s20 recipe: five presses with %d heavies read %s (the old rule)" % [r[0], r[1]])
	# Only the latest five count: eight presses of which the last five are lights.
	var old_heavy: Array = _mk([100, 110, 120, 130, 140, 150, 160, 170], [], [1, 1, 1, 0, 0, 0, 0, 0])
	ok(SimPressRead.classify(old_heavy, 173)["recipe"] == "blur", "s20 recipe: the recipe reads the latest five, so earlier heavies are out")
	# The lapse: the window holds for 90 idle ticks, then clears as a whole.
	var held: Array = _mk([100, 147, 194, 241], [], [1, 1, 1, 1])
	ok(SimPressRead.classify(held, 241 + 90)["recipe"] == "power", "s20 lapse: 90 ticks after the last press the window still reads")
	var gone: Dictionary = SimPressRead.classify(held, 241 + 91)
	ok(gone["recipe"] == "none" and gone["presses"] == 0 and gone["mix_short"]["heavy"] == 0, "s20 lapse: 91 idle ticks clears the whole window")
	# A new press after the lapse starts a fresh window of its own (the director clears the log; the read of a stale entry is empty).
	SimPressRead.push(held, SimPressRead.LIGHT, 0, 400)
	var fresh: Dictionary = SimPressRead.classify(held, 403)
	ok(fresh["mix_short"]["light"] == 1 and fresh["mix_short"]["heavy"] == 4, "s20 lapse: a log the director has not cleared still counts its entries once a press comes (clearing is the director's)")
