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
	ok(c3["mix_long"]["light"] == 7 and c3["mix_long"]["heavy"] == 3, "mix: a press 91 ticks old has expired")
	ok(SimPressRead.classify(long_log, 400)["mix_long"]["light"] == 0 and SimPressRead.classify(long_log, 400)["mix_long"]["heavy"] == 0, "mix: a log gone cold has an empty mix")


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
	var steady: Dictionary = SimPressRead.classify(_mk([100, 108, 116, 124]), 127)
	ok(steady["style"] == "mash" and steady["steady"] and steady["timing"] == "perfect", "timing: a steady mash is a perfect blur")
	var ragged: Dictionary = SimPressRead.classify(_mk([100, 106, 116, 123]), 126)
	ok(ragged["style"] == "mash" and not ragged["steady"] and ragged["timing"] == "none", "timing: a ragged mash is a mash, not a perfect one")
	ok(SimPressRead.classify(_mk([100, 108, 117, 125]), 128)["steady"], "timing: gaps of 8, 9, 8 are steady (within 3)")
	ok(not SimPressRead.classify(_mk([100, 108, 120, 128]), 131)["steady"], "timing: gaps of 8, 12, 8 are not")
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
