extends SceneTree
## Golden check for the GDScript sim (the CI gate). It recomputes every golden vector with the recipes in
## golden_recipes.gd and exits 0 only if all match the golden file bit for bit. From the repo root:
##   godot --headless --path . --import
##   godot --headless --path . --script res://sim/core/tools/parity.gd [-- --golden=res://path.json] [-- --no-bench]
## The default golden file is sim/core/test/golden.json, written by tools/golden.gd. The frozen JS record
## (sim/core/test/frozen/golden-js.json) is checked the same way with --golden; it matches only while the GDScript
## sim still behaves like the frozen JS core. It also prints the tick cost.

const DEFAULT_GOLDEN := "res://sim/core/test/golden.json"
const LIT_RE := "(?<![\\w.])(\\d+\\.\\d+(?:e[+-]?\\d+)?|\\d+e[+-]?\\d+)(?![\\w.])"

var failures: int = 0


func _init() -> void:
	var t0: int = Time.get_ticks_usec()
	var path: String = DEFAULT_GOLDEN
	var bench: bool = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--golden="):
			path = a.substr(9)
		elif a == "--no-bench":
			bench = false
	print("Orb Combat EX golden check   Godot %s   %s" % [Engine.get_version_info().string, path])
	var g = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (g is Dictionary):
		print("FAIL  cannot read %s (generate it with: godot --headless --path . --script res://sim/core/tools/golden.gd)" % path)
		quit(1)
		return
	check("long float literals", _literals())
	check("constants", _list("constants", SimGolden.constants(), g.constants))
	check("cosmetic stream seeds", _stream_seeds(g))
	check("rng", _keyed(g.rng, func(s): return SimGolden.rngHash(s)))
	check("wrap", "" if SimGolden.wrapHash() == g.wrap else "differs")
	check("sin/cos", "" if SimGolden.sincosHash() == g.sincos else "differs")
	check("pow/exp/log/hypot", "" if SimGolden.powHash() == g.powexplog else "differs")
	check("tick-0 state", _tick0(g))
	check("wounds (forced hits)", "" if SimGolden.woundsHash() == g.get("wounds", "") else "differs")
	check("rally (forced)", "" if SimGolden.rallyHash() == g.get("rally", "") else "differs")
	check("crippling (forced)", "" if SimGolden.crippleHash() == g.get("cripple", "") else "differs")
	check("mood and style (forced)", "" if SimGolden.moodHash() == g.get("mood", "") else "differs")
	check("fight data", _fightData(g))
	check("roster data", _roster(g))
	check("roster loader rejects bad data", _rosterRejects())
	check("wired numbers change a match", _wiredNumbers())
	check("keyed draws", _keyedDraws(g))
	check("arm setups", _armSetups())
	check("intent pack", _intentPack())
	check("replay module", _replayModule())
	var tm: int = Time.get_ticks_usec()
	check("matches", _matches(g))
	check("human-input replays", _replays(g))
	print("      (matches and replays: %.1f s)" % ((Time.get_ticks_usec() - tm) / 1e6))
	if bench:
		_bench()
	print("time  %.1f s" % ((Time.get_ticks_usec() - t0) / 1e6))
	print("\ngolden check FAILED" if failures else "\ngolden check passed")
	quit(1 if failures else 0)


## err is "" for a pass. Anything else fails, including null: a check that stops on a script error returns null, and must
## not read as a pass.
func check(name: String, err) -> void:
	if err is String and err == "":
		print("ok    " + name)
	else:
		failures += 1
		print("FAIL  %s: %s" % [name, err])


## GDScript's parser is not correctly rounded for long literals, and whether its result can differ between platforms is
## unproven, so the sim may not contain float literals with more than 15 significant digits: build such constants from
## their bits with SimMathx.f64 (sim/README.md, GDScript traps).
func _literals() -> String:
	var re := RegEx.create_from_string(LIT_RE)
	var strip_str := RegEx.create_from_string("\"[^\"\\n]*\"")
	var strip_com := RegEx.create_from_string("(?m)#.*$")
	var bad: Array = []
	for file in _gd_files("res://sim"):
		var src: String = strip_com.sub(strip_str.sub(FileAccess.get_file_as_string(file), "\"\"", true), "", true)
		for m in re.search_all(src):
			var lit: String = m.get_string(1)
			var digits: String = lit.split("e")[0].split("E")[0].replace(".", "").lstrip("0")
			if digits.length() > 15:
				bad.append("%s in %s" % [lit, file])
	return "" if bad.is_empty() else "use SimMathx.f64 for: " + ", ".join(bad)


func _gd_files(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(d)))
	return out


func _list(what: String, got: Array, want: Array) -> String:
	if got.size() != want.size():
		return "%d %s, golden %d" % [got.size(), what, want.size()]
	for i in range(got.size()):
		if str(got[i]) != str(want[i]):
			return "%s %d is %s, golden %s" % [what, i, got[i], want[i]]
	return ""


func _keyed(want: Dictionary, fn: Callable) -> String:
	for k in want:
		var got: String = fn.call(int(k))
		if got != want[k]:
			return "seed %s: %s, golden %s" % [k, got, want[k]]
	return ""


func _stream_seeds(g: Dictionary) -> String:
	for k in g.streamSeeds:
		var got: Array = SimGolden.streamSeeds(int(k))
		for i in range(got.size()):
			if got[i] != int(g.streamSeeds[k][i]):
				return "seed %s %s: %d, golden %d" % [k, SimGolden.STREAM_IDS[i], got[i], int(g.streamSeeds[k][i])]
	return ""


func _tick0(g: Dictionary) -> String:
	for k in g.tick0:
		var got: String = SimGolden.tick0Hash(int(k))
		if got != g.tick0[k]:
			var why := "seed %s: %s (golden %s)" % [k, got, g.tick0[k]]
			if k == "1":
				why += "; " + _first_diff(SimGolden.tick0Values(1), g.tick0Values)
			return why
	return ""


func _first_diff(got: Array, want: Array) -> String:
	for i in range(maxi(got.size(), want.size())):
		var a: String = got[i] if i < got.size() else "(missing)"
		var b: String = want[i] if i < want.size() else "(missing)"
		if a != b:
			return "first difference at value %d: %s, golden %s" % [i, a, b]
	return "value lists are equal (the hash code differs)"


func _matches(g: Dictionary) -> String:
	var bad: Array = []
	var ticks: int = 0
	for m in g.matches:
		var got: Dictionary = SimGolden.goldenRun(m.arm, int(m.seed), null, int(m.get("cap", SimGolden.CAP)))
		ticks += got.ticks
		var e := SimGolden.compareRun(got, m, "%s seed %d" % [m.arm, int(m.seed)])
		if e != "":
			bad.append(e)
	if bad.size():
		return "; ".join(bad)
	print("      %d matches, %d ticks: every per-tick digest and full-state checkpoint identical" % [g.matches.size(), ticks])
	return ""


func _replays(g: Dictionary) -> String:
	for r in g.replays:
		var got: Dictionary = SimGolden.goldenRun("default", int(r.replay.seed), r.replay)
		var e := SimGolden.compareRun(got, r.run, "replay seed %d" % int(r.replay.seed))
		if e != "":
			return e
	return ""


## I1 (intent v2): pack and unpack are inverse on every field's range, canon() puts the stick on its 1 / 127 grid, and
## unpack refuses integers that are not packed intents.
func _intentPack() -> String:
	var bools: Array = ["guard", "guardPress", "dodge", "sprint", "power", "powerPress", "powerTap", "light", "heavy", "sig", "context", "transform", "dash", "charge"]
	var fields: Array = ["mx", "my", "mode", "upgrade", "special", "stance"] + bools
	var same := func(x: SimIntent, y: SimIntent) -> bool:
		for k in fields:
			if x.get(k) != y.get(k):
				return false
		return true
	var cases: Array = []
	var neutral := SimIntent.new()
	if SimIntent.unpack(SimIntent.pack(neutral)) == null or not same.call(neutral, SimIntent.unpack(SimIntent.pack(neutral))):
		return "the neutral intent does not round-trip"
	for b in bools:
		var i := SimIntent.new()
		i.set(b, true)
		cases.append(i)
	for v in [[-1, 0, 0, -1.0], [0, 1, 1, 0.0], [1, 2, 4, 1.0], [1, 2, 7, 2.0], [0, 0, 3, 3.0]]:
		var i2 := SimIntent.new()
		i2.mode = v[0]; i2.upgrade = v[1]; i2.special = v[2]; i2.stance = v[3]
		cases.append(i2)
	for k in range(-127, 128):
		var i3 := SimIntent.new()
		i3.mx = float(k) / 127.0
		i3.my = float(-k) / 127.0
		cases.append(i3)
	var r := SimRng.new(2024)
	for n in range(4000):
		var i4 := SimIntent.new()
		i4.mx = float(int(floor(r.next() * 255.0)) - 127) / 127.0
		i4.my = float(int(floor(r.next() * 255.0)) - 127) / 127.0
		i4.mode = int(floor(r.next() * 3.0)) - 1
		i4.upgrade = int(floor(r.next() * 3.0))
		i4.special = int(floor(r.next() * 8.0))
		i4.stance = float(int(floor(r.next() * 5.0)) - 1)
		for b in bools:
			i4.set(b, r.next() < 0.5)
		cases.append(i4)
	for i in cases:
		var p: int = SimIntent.pack(i)
		var u: SimIntent = SimIntent.unpack(p)
		if u == null or not same.call(i, u):
			return "unpack(pack(i)) differs for packed %d" % p
		if SimIntent.pack(u) != p:
			return "pack(unpack(p)) differs for %d" % p
	var off := SimIntent.new()
	off.mx = 0.5
	off.my = -0.3333
	var c: SimIntent = SimIntent.canon(off)
	if c.mx != 64.0 / 127.0 or c.my != -42.0 / 127.0 or SimIntent.pack(c) != SimIntent.pack(off):
		return "canon() does not put the stick on its 1 / 127 grid"
	for badp in [-1, 1 << 40, 255, 255 << 8, 3 << 16, 3 << 18, 5 << 35, 7 << 35]:
		if SimIntent.unpack(badp) != null:
			return "unpack accepted %d, which is not a packed intent" % badp
	return ""


## SimReplay (S4): record a scripted two-human run, play it back and play its JSON round trip; a changed input and a
## replay from other combat data must both fail.
func _replayModule() -> String:
	var src: Dictionary = SimGolden.scriptedReplay(13, 1200, true, [600])
	var S := SimCore.createSim()
	var rec := SimReplay.recorder(S, 13, src.ai)
	var cur: Array = [null, null]
	var ii: int = 0
	var ti: int = 0
	for t in range(int(src.ticks)):
		while ti < src.toggles.size() and int(src.toggles[ti][0]) == t:
			rec.toggle(int(src.toggles[ti][1]))
			ti += 1
		while ii < src.inputs.size() and int(src.inputs[ii][0]) == t:
			cur[int(src.inputs[ii][1])] = SimGolden._intent(src.inputs[ii][2])
			ii += 1
		rec.step(cur)
	var rp: Dictionary = rec.finish()
	SimCore.dispose(S)
	var r: Dictionary = SimReplay.play(rp)
	if not r.ok:
		return "playback: %s at tick %d" % [r.reason, r.firstBadTick]
	r = SimReplay.play(JSON.parse_string(JSON.stringify(rp)))
	if not r.ok:
		return "JSON round trip: %s at tick %d" % [r.reason, r.firstBadTick]
	var bad: Dictionary = rp.duplicate(true)
	bad.data = "0"
	if SimReplay.play(bad).reason != "data":
		return "a replay from other combat data was not refused"
	bad = rp.duplicate(true)
	# From the middle on, every record steers the other way: one altered record can fall on ticks where the fighter cannot
	# act, so the change is made to last.
	var at: int = int(floor(bad.inputs.size() / 2.0))
	for q in range(at, bad.inputs.size()):
		if bad.inputs[q][2] == null:
			continue
		var alt: SimIntent = SimIntent.unpack(int(bad.inputs[q][2]))
		alt.mx = -1.0 if alt.mx > 0.0 else 1.0
		bad.inputs[q][2] = SimIntent.pack(alt)
	if SimReplay.play(bad).ok:
		return "a changed input was not caught"
	# I1: format v3 refuses an older file, another intent schema, and an input that is not a packed intent.
	for edit in [["v", 2], ["intent", SimIntent.VERSION + 1], ["intent", 1]]:
		bad = rp.duplicate(true)
		bad[edit[0]] = edit[1]
		if SimReplay.play(bad).reason != "format":
			return "a replay with %s %s was not refused" % [edit[0], str(edit[1])]
	bad = rp.duplicate(true)
	bad.inputs[at][2] = 1 << 45
	if SimReplay.play(bad).reason != "format":
		return "an invalid packed intent was not refused"
	# D1a: a replay of a mirror setup plays back from its header alone.
	var S2 := SimCore.createSim()
	var rec2 := SimReplay.recorder(S2, 21, {}, SimGolden.armSetup("mirror-hero-flip"))
	for t in range(900):
		rec2.step(null)
	var rp2: Dictionary = rec2.finish()
	SimCore.dispose(S2)
	r = SimReplay.play(JSON.parse_string(JSON.stringify(rp2)))
	if not r.ok or rp2.setup.get("names", []) != ["KAI-A", "KAI-B"]:
		return "setup replay: %s at tick %d" % [r.reason, r.firstBadTick]
	return ""


## D1a: the roster data load clean, and their canonical hash matches the goldens (a data edit shows here by name).
func _roster(g: Dictionary) -> String:
	if not FighterData.errors().is_empty():
		return "data/fighters: " + "; ".join(FighterData.errors())
	if FighterData.order() != ["KAI", "VORR"]:
		return "roster order " + str(FighterData.order())
	if FighterData.dataHash() != g.get("rosterHash", ""):
		return "the roster data hash differs (data/fighters/ changed): %s vs golden %s; regenerate the goldens if the edit is meant" % [FighterData.dataHash(), g.get("rosterHash", "")]
	return ""


## D1a negative controls: fixtures made from KAI's real files with one fault each (edits keyed to the key name, not its
## value, so a retune does not break them; the old value stays behind as a "_was" note), in user://, must each be rejected with
## the right message; a changed _note must not change the data hash, and a changed number must. Reloads data/fighters/
## at the end.
func _rosterRejects() -> String:
	var src: String = FighterData.ROOT + "KAI/"
	var base := {"fighter.json": FileAccess.get_file_as_string(src + "fighter.json"), "wounds.json": FileAccess.get_file_as_string(src + "wounds.json"),
		"meters.json": FileAccess.get_file_as_string(src + "meters.json"), "ladder.json": FileAccess.get_file_as_string(src + "ladder.json")}
	var h0: String = FighterData.dataHash()
	var cases: Array = [
		["note", "", "", "", ""],
		["number", "wounds.json", "\"focusWear\": ", "\"focusWear\": 31.5, \"_was\": ", ""],
		["nonint", "wounds.json", "\"out\": ", "\"out\": 25.5, \"_was\": ", "must be an integer"],
		["digits", "wounds.json", "\"wearPerDamage\": ", "\"wearPerDamage\": 204.00000000000001, \"_was\": ", "more than 15 significant digits"],
		["rally", "fighter.json", "\"second_wind\"", "\"berserk\"", "unknown Rally rule"],
		["profile", "wounds.json", "\"type\": \"plain\"", "\"type\": \"spread\"", "unknown profile type"],
		["pinned", "wounds.json", "\"legsSlip\": ", "\"legsSlip\": 0.3, \"_was\": ", "is pinned"],
		["meter", "meters.json", "\"anguish\": {", "\"pride\": {", "unknown meter"],
		["dup", "", "", "", "duplicate"],
	]
	var hashes := {}
	var err: String = ""
	FighterData.quiet = true
	for c in cases:
		var dir: String = "user://d1a_fixtures/%s/" % c[0]
		DirAccess.make_dir_recursive_absolute(dir + "KAI")
		var ros := FileAccess.open(dir + "roster.json", FileAccess.WRITE)
		ros.store_string("[\"KAI\", \"KAI\"]" if c[0] == "dup" else "[\"KAI\"]")
		ros.close()
		for fname in base:
			var text: String = base[fname]
			if fname == c[1]:
				if text.count(c[2]) != 1:
					err = "fixture %s: pattern not found once" % c[0]
				text = text.replace(c[2], c[3])
			if c[0] == "note" and fname == "wounds.json":
				text = text.replace("\"_about\": \"", "\"_about\": \"(edited note) ")
			var fw := FileAccess.open(dir + "KAI/" + fname, FileAccess.WRITE)
			fw.store_string(text)
			fw.close()
		FighterData.loadFrom(dir)
		var errs: String = "; ".join(FighterData.errors())
		hashes[c[0]] = FighterData.dataHash()
		if err == "" and c[4] == "" and errs != "":
			err = "fixture %s: unexpected errors: %s" % [c[0], errs]
		elif err == "" and c[4] != "" and not errs.contains(c[4]):
			err = "fixture %s: not rejected (%s)" % [c[0], errs]
	if err != "":
		FighterData.quiet = false
		FighterData.loadFrom()
		return err
	var numberBlind: bool = hashes.note == hashes.number
	# The note fixture is KAI alone, so compare it with KAI alone unedited: the dup-free base is the "number" case minus the edit.
	var plain := "user://d1a_fixtures/plain/"
	DirAccess.make_dir_recursive_absolute(plain + "KAI")
	var rp := FileAccess.open(plain + "roster.json", FileAccess.WRITE)
	rp.store_string("[\"KAI\"]")
	rp.close()
	for fname in base:
		var fp := FileAccess.open(plain + "KAI/" + fname, FileAccess.WRITE)
		fp.store_string(base[fname])
		fp.close()
	FighterData.loadFrom(plain)
	var hPlain: String = FighterData.dataHash()
	# A third fighter from data alone (the stage-5 modding test in miniature): KAI's files copied as TEST, no code change.
	var third := "user://d1a_fixtures/third/"
	for id in ["KAI", "TEST"]:
		DirAccess.make_dir_recursive_absolute(third + id)
		for fname in base:
			var ft := FileAccess.open(third + id + "/" + fname, FileAccess.WRITE)
			ft.store_string(base[fname].replace("\"KAI\"", "\"TEST\"") if id == "TEST" else base[fname])
			ft.close()
	var rt := FileAccess.open(third + "roster.json", FileAccess.WRITE)
	rt.store_string("[\"KAI\", \"TEST\"]")
	rt.close()
	FighterData.loadFrom(third)
	var thirdErr: String = "; ".join(FighterData.errors())
	var played: String = ""
	if thirdErr == "":
		var S := SimCore.createSim()
		SimCore.newMatch(S, 5, {}, {"slots": ["TEST", "KAI"]})
		for t in range(1200):
			SimCore.step(S)
			S.out.fx.clear()
			S.out.feed.clear()
		if S.fighters[0].id != "TEST" or S.fighters[0].name != "TEST" or not is_finite(S.fighters[0].x):
			played = "the TEST fighter did not play"
		SimCore.dispose(S)
	FighterData.quiet = false
	FighterData.loadFrom()
	if numberBlind:
		return "a changed number did not change the data hash"
	if hPlain != hashes.note:
		return "a changed _note changed the data hash"
	if thirdErr != "":
		return "a third fighter from data: " + thirdErr
	if played != "":
		return played
	if FighterData.dataHash() != h0:
		return "reloading data/fighters/ changed the hash"
	return ""


## M1: data/fight/ loads clean, and its canonical hash matches the goldens (a data edit shows here by name).
func _fightData(g: Dictionary) -> String:
	if not SimMood.errors().is_empty():
		return "data/fight: " + "; ".join(SimMood.errors())
	if SimMood.dataHash() != g.get("fightHash", ""):
		return "the fight data hash differs (data/fight/ changed): %s vs golden %s; regenerate the goldens if the edit is meant" % [SimMood.dataHash(), g.get("fightHash", "")]
	return ""


## D1b, made robust in I1: every wired number in meters.json, ladder.json and guardWearSplit changes what the sim does
## when edited (QA found the meters were documentation only). Each row copies data/fighters/ to user://, sets one value
## (ladder and guard edits in both fighters' files) and runs a forced probe: a fresh match, the state that number needs,
## one call into the code that reads it, and the values that call produced. The probe's result with the edited data must
## differ from its result with the real data. No probe plays a match, so a changed opening cannot break a row (the old
## check played seeds and needed new ones after B2 and after the terrain fixes). One end-to-end row still plays matches,
## over a list of seeds, and passes if any seed's digest differs. composure.below is left out: it only matters while
## composure's cap is not 0.
const WIRED: Array = [
	["KAI/meters.json", ["meters", "anguish", "effects", 0, "perPoint"], 0.2, "kaiTick"],
	["KAI/meters.json", ["meters", "anguish", "effects", 0, "cap"], 0.05, "kaiTick"],
	["KAI/meters.json", ["meters", "anguish", "effects", 1, "cap"], 0.3, "kaiHit"],
	["KAI/meters.json", ["meters", "anguish", "effects", 2, "cap"], 2.0, "kaiHit"],
	["KAI/meters.json", ["meters", "anguish", "decay", "rate"], 3.0, "kaiTick"],
	["KAI/meters.json", ["meters", "anguish", "sources", 0, "amount"], 5.0, "feedSelf"],
	["KAI/meters.json", ["meters", "anguish", "sources", 1, "amount"], 5.0, "feedOther"],
	["VORR/meters.json", ["meters", "menace", "effects", 0, "perPoint"], 0.3, "vorrTick"],
	["VORR/meters.json", ["meters", "menace", "effects", 0, "cap"], 0.01, "vorrTick"],
	["VORR/meters.json", ["meters", "menace", "effects", 1, "cap"], 1.0, "vorrHit"],
	["VORR/meters.json", ["meters", "menace", "effects", 2, "perPoint"], 50.0, "beam"],
	["VORR/meters.json", ["meters", "menace", "decay", "rate"], 3.0, "vorrTick"],
	["VORR/meters.json", ["meters", "menace", "decay", "delayTicks"], 30, "vorrQuiet"],
	["VORR/meters.json", ["meters", "menace", "sources", 0, "amount"], 5.0, "feedOther"],
	["VORR/meters.json", ["meters", "menace", "sources", 1, "amount"], 5.0, "evac"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["fillPerSec"], 2.0, "ladderTick"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["thresholds"], [10.0, 50.0, 75.0], "ladderTick"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["tiers", "speed"], 0.5, "speed"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["tiers", "damage"], 0.5, "tierHit"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["tiers", "launch"], 0.8, "launch"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["powerUp", "areaR"], 600.0, "powerUp"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["powerUp", "areaRPerTier"], 300.0, "powerUp"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["powerUp", "areaDmg"], 900.0, "powerUp"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["powerUp", "areaDmgPerTier"], 900.0, "powerUp"],
	[["KAI/wounds.json", "VORR/wounds.json"], ["guardWearSplit"], {"arms": 0.75, "legs": 0.25}, "guard"],
	["VORR/meters.json", ["meters", "menace", "effects", 1, "cap"], 1.0, "match"],   # end to end: any of WIRED_SEEDS
]
const WIRED_TICKS: int = 6000
const WIRED_SEEDS: Array = [3, 7, 12, 16, 18]


func _wiredNumbers() -> String:
	var files := {}
	for id in FighterData.order():
		for fname in ["fighter.json", "wounds.json", "meters.json", "ladder.json"]:
			files[id + "/" + fname] = FileAccess.get_file_as_string(FighterData.ROOT + id + "/" + fname)
	var base := {}
	for c in WIRED:
		if c[3] != "match" and not base.has(c[3]):
			base[c[3]] = _wiredProbe(c[3])
			if base[c[3]].begins_with("!"):
				return "probe %s cannot run on the real data: %s" % [c[3], base[c[3]]]
	var bad: Array = []
	FighterData.quiet = true
	for i in range(WIRED.size()):
		var c: Array = WIRED[i]
		var dir: String = "user://d1b_wired/%d/" % i
		for id in ["KAI", "VORR"]:
			DirAccess.make_dir_recursive_absolute(dir + id)
		var rf := FileAccess.open(dir + "roster.json", FileAccess.WRITE)
		rf.store_string("[\"KAI\", \"VORR\"]")
		rf.close()
		var targets: Array = c[0] if c[0] is Array else [c[0]]
		for key in files:
			var text: String = files[key]
			if targets.has(key):
				var d = JSON.parse_string(text)
				var node = d
				for k in range(c[1].size() - 1):
					node = node[c[1][k]]
				node[c[1][c[1].size() - 1]] = c[2]
				text = JSON.stringify(d, "  ")
			var fw := FileAccess.open(dir + key, FileAccess.WRITE)
			fw.store_string(text)
			fw.close()
		if c[3] == "match":
			var differs: bool = false
			for seed in WIRED_SEEDS:
				FighterData.loadFrom()
				var plain: String = _wiredRun(seed)
				FighterData.loadFrom(dir)
				if FighterData.errors().is_empty() and _wiredRun(seed) != plain:
					differs = true
					break
			if not differs:
				bad.append("%s %s: no effect in a match on seeds %s" % [str(c[0]), str(c[1]), str(WIRED_SEEDS)])
			continue
		FighterData.loadFrom(dir)
		if not FighterData.errors().is_empty():
			bad.append("%s %s: %s" % [str(c[0]), str(c[1]), "; ".join(FighterData.errors())])
		elif _wiredProbe(c[3]) == base[c[3]]:
			bad.append("%s %s: no effect on probe %s" % [str(c[0]), str(c[1]), c[3]])
	FighterData.quiet = false
	FighterData.loadFrom()
	return "" if bad.is_empty() else "; ".join(bad)


## One forced probe on the loaded data: a fresh match (seed 3), the state its number needs, one call into the reader, and
## the values it produced as text. A result starting with "!" means the probe could not set its scenario up.
func _wiredProbe(kind: String) -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 3)
	var kai = S.fighters[0]
	var vorr = S.fighters[1]
	var out: Array = []
	match kind:
		"kaiTick":      # anguish: the regen penalty, its cap and the decay
			kai.anguish = 50.0
			kai.ki = 10.0
			SimFighter.stepFighter(S, kai, SimConst.DT)
			out = [kai.ki, kai.anguish]
		"vorrTick":     # menace: the regen bonus, its cap and the decay (long unfed)
			vorr.menace = 50.0
			vorr.menaceSeen = 50.0
			vorr.menaceQuiet = 1000
			vorr.casSeen = S.world.casualties
			vorr.ki = 10.0
			SimFighter.stepFighter(S, vorr, SimConst.DT)
			out = [vorr.ki, vorr.menace]
		"vorrQuiet":    # menace: the decay's delay (unfed for 100 ticks: under the real delay, over the edited one)
			vorr.menace = 50.0
			vorr.menaceSeen = 50.0
			vorr.menaceQuiet = 100
			vorr.casSeen = S.world.casualties
			SimFighter.stepFighter(S, vorr, SimConst.DT)
			out = [vorr.menace]
		"kaiHit", "vorrHit", "tierHit":   # damage: composure and the comeback; menace's damage_mul; the tier's damage step
			var A = vorr if kind == "vorrHit" else kai
			var D = kai if kind == "vorrHit" else vorr
			if kind == "kaiHit":
				A.wear[SimWounds.CORE] = 300000
				SimWounds.updateStages(S, A)
			elif kind == "vorrHit":
				A.menace = 50.0
			else:
				A.tier = 3.0
			var ex := SimState.Exchange.new()
			ex.A = A
			ex.D = D
			ex.kind = "light"
			out = [SimDamage.hit(S, ex, A, D, 20.0, {})]
		"beam":         # menace's beam power
			vorr.menace = 50.0
			out = [DirBeam._clashScore(S, vorr)]
		"feedSelf", "feedOther":   # the casualty sources: caused by KAI, or by VORR
			WorldCollateral._feed(S, 10.0, kai if kind == "feedSelf" else vorr)
			out = [kai.anguish, vorr.menace]
		"evac":         # the evacuee source: VORR's blows empty buildings until someone flees
			for b in S.buildings:
				if b.alive and b.popAlive > 0.0:
					WorldCollateral.kill(S, b.idx, b.popAlive, vorr, 0.0, b.x)
					if S.world.evacuated > 0.0:
						break
			if S.world.evacuated <= 0.0:
				out = ["!no evacuees"]
			else:
				out = [vorr.menace, S.world.evacuated]
		"ladderTick":   # the fill and the thresholds
			kai.power = 15.0
			SimFighter.stepFighter(S, kai, SimConst.DT)
			out = [kai.power, kai.tier]
		"speed":        # the tier's speed step
			kai.tier = 3.0
			kai.power = 60.0
			kai.input.mx = 1.0
			SimFighter.stepFighter(S, kai, SimConst.DT)
			out = [kai.vx]
		"launch":       # the tier's launch step
			kai.tier = 3.0
			DirLaunch.doLaunch(S, kai, vorr, {"ux": 1.0, "uy": 0.2}, 1500.0)
			out = [vorr.vx, vorr.vy]
		"powerUp":      # the power-up's area and damage, on the ground beside the building with the most neighbours
			var best = null
			var most: int = -1
			for b in S.buildings:
				if not b.alive:
					continue
				var near: int = WorldStructures.near(S, b.x, 6000.0).size()
				if near > most:
					most = near
					best = b
			if best == null:
				out = ["!no buildings"]
			else:
				kai.x = best.x
				kai.y = WorldTerrain.groundY(S, kai.x)
				kai.tier = 2.0
				SimFighter.tierUp(S, kai)
				var hp: float = 0.0
				var alive: int = 0
				for b in S.buildings:
					hp += b.hp
					alive += 1 if b.alive else 0
				out = [hp, alive]
		"guard":        # the guard wear split
			SimWounds.addGuardWear(S, kai, 100.0)
			out = [kai.wear[SimWounds.ARMS], kai.wear[SimWounds.LEGS]]
		_:
			out = ["!unknown probe " + kind]
	SimCore.dispose(S)
	var parts: PackedStringArray = []
	for v in out:
		parts.append(SimMathx.bits(v) if v is float else str(v))
	return ",".join(parts)


func _wiredRun(seed: int) -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, seed)
	var h := SimHash.Hasher.new()
	for t in range(WIRED_TICKS):
		SimCore.step(S)
		S.out.fx.clear()
		S.out.feed.clear()
		for f in S.fighters:
			h.num(f.x); h.num(f.y); h.num(f.ki); h.num(f.power); h.num(f.menace); h.num(f.anguish)
			for r in range(4):
				h.num(float(f.wear[r]))
	var got: String = h.hex() + ":" + SimHash.stateHash(S).gameplay
	SimCore.dispose(S)
	return got


## D1a: SimRng.keyed is stateless (same inputs, same value; no stream moves), spread over keys and indices, in [0, 1), and
## the same as the golden vector (so the same in every process).
func _keyedDraws(g: Dictionary) -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 3)
	var a0: int = S.rng.a
	var seen := {}
	for n in range(1000):
		var x: float = SimRng.keyed(int(S.game.seed), "compose", n)
		if x < 0.0 or x >= 1.0:
			return "out of [0, 1): " + str(x)
		if x != SimRng.keyed(int(S.game.seed), "compose", n):
			return "not stateless at n %d" % n
		seen[x] = true
	var moved: bool = S.rng.a != a0
	SimCore.dispose(S)
	if moved:
		return "a keyed draw moved S.rng"
	if seen.size() < 1000:
		return "only %d distinct values over 1000 indices" % seen.size()
	if SimRng.keyed(3, "compose", 5) == SimRng.keyed(3, "chain", 5):
		return "keys do not separate"
	return "" if SimGolden.keyedHash() == g.get("keyed", "") else "the keyed vector differs from the golden"


## D1a: each QA arm as a match setup gives the same match as newMatch plus applyArm (full state at ticks 0, 60, 150, 300).
func _armSetups() -> String:
	for arm in ["default", "swap", "mirror-villain", "mirror-hero", "default-flip", "swap-flip", "mirror-villain-flip", "mirror-hero-flip"]:
		var A := SimCore.createSim()
		SimCore.newMatch(A, 2)
		SimGolden.applyArm(arm, A.fighters)
		var B := SimCore.createSim()
		SimCore.newMatch(B, 2, {}, SimGolden.armSetup(arm))
		var e: String = ""
		for t in range(301):
			if (t == 0 or t == 60 or t == 150 or t == 300) and SimHash.stateHash(A).gameplay != SimHash.stateHash(B).gameplay:
				e = "%s: setup and applyArm differ by tick %d" % [arm, t]
				break
			SimCore.step(A)
			SimCore.step(B)
			A.out.fx.clear(); A.out.feed.clear(); B.out.fx.clear(); B.out.feed.clear()
		SimCore.dispose(A)
		SimCore.dispose(B)
		if e != "":
			return e
	return ""


## Tick cost: AI-vs-AI matches with no hashing. The sim tick (step) and the render side's reference cosmetic consumer
## (view/fx.gd plus the camera follow) are timed apart; the first tick of each match (warm-up) is left out.
func _bench() -> void:
	var sim_t := PackedInt64Array()
	var view_t := PackedInt64Array()
	for seed in range(1, 11):
		var S := SimCore.createSim()
		var cam := SimCamera.new()
		var V := SimFxView.new(seed)
		SimCore.newMatch(S, seed)
		var steps: int = 0
		while steps < 18000 and not (S.game.ko != null and S.game.koT > 3.0):
			var t0: int = Time.get_ticks_usec()
			SimCore.step(S)
			var t1: int = Time.get_ticks_usec()
			V.consume(S, S.out.fx)
			cam.camStep(S, S.dt, 1200.0, 700.0)
			var t2: int = Time.get_ticks_usec()
			S.out.fx.clear()
			S.out.feed.clear()
			if steps > 0:
				sim_t.append(t1 - t0)
				view_t.append(t2 - t1)
			steps += 1
		SimCore.dispose(S)
	print("time  sim tick:  " + _dist(sim_t))
	print("time  cosmetic consumer and camera (render side): " + _dist(view_t))


static func _dist(v: PackedInt64Array) -> String:
	var s := v.duplicate()
	s.sort()
	var n: int = s.size()
	var tot: int = 0
	for x in s:
		tot += x
	return "mean %.1f us, p50 %d, p99 %d, p99.9 %d, max %d us over %d ticks of 10 matches" % [float(tot) / n, s[n / 2], s[int(n * 0.99)], s[int(n * 0.999)], s[n - 1], n]
