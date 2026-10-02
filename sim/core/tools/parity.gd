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
	check("action state", _actState())
	check("pausing set pieces", _pause())
	check("act rule and time cap", _actRule())
	check("the break", _formBreak())
	check("the form impulse", _formImpulse())
	check("depth in the core", _depth())
	check("the intro phase", _intro())
	check("the last stand", _lastStand())
	check("shots", _shots())
	check("agency lines", _agencyLines())
	check("the intro phase (golden)", "" if SimGolden.introHash() == g.get("intro", "") else "differs")
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
	var bools: Array = ["guard", "guardPress", "dodge", "sprint", "power", "powerPress", "powerTap", "light", "heavy", "sig", "context", "transform", "dash", "charge", "lightHeld", "heavyHeld", "escape"]
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
	for badp in [-1, 1 << 43, 255, 255 << 8, 3 << 16, 3 << 18, 5 << 35, 7 << 35]:
		if SimIntent.unpack(badp) != null:
			return "unpack accepted %d, which is not a packed intent" % badp
	return ""


## I2a: the action state's rules (sim/core/act.gd), each asserted: the setup's v2 and assists, the stance from the held
## states (and today's stance field for a slot that is not v2), guard, dodge, mode and the cooldowns, the stun gate, the
## burst flag, the queue, and the tier-up gate with its data flag on and off.
func _actState() -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5, {"p1": false, "p2": false}, {"v2": [true, false], "assists": [["autoBurst"], []]})
	var a = S.fighters[0]
	var b = S.fighters[1]
	if not a.act.v2 or b.act.v2 or not SimAct.assisted(a, "autoBurst") or SimAct.assisted(a, "specialAuto") or SimAct.assisted(b, "autoBurst"):
		return "the setup's v2 and assists did not reach the fighters"
	var ia := SimIntent.new()
	var ib := SimIntent.new()
	var away: float = -SimMathx.jsign(SimWrap.sdx(a.x, b.x))
	var go := func() -> void:
		SimCore.step(S, [ia, ib])
		S.out.fx.clear()
		S.out.feed.clear()
	ib.stance = 1.0
	ia.stance = 1.0          # ignored for the v2 slot
	go.call()
	if b.stance != 1.0 or a.stance != 0.0:
		return "the stance field: b %s (wants 1, not v2), a %s (wants 0, v2 ignores it)" % [str(b.stance), str(a.stance)]
	ia.guard = true
	go.call()
	var t0: int = S.tick
	if a.stance != 1.0 or a.act.guardSince != t0:
		return "guard held: stance %s, guardSince %d (tick %d)" % [str(a.stance), a.act.guardSince, t0]
	go.call()
	if a.act.guardSince != t0:
		return "guardSince moved while the guard was held"
	ia.guard = false
	go.call()
	if a.stance != 0.0 or a.act.guardSince != -1:
		return "guard released: stance %s, guardSince %d" % [str(a.stance), a.act.guardSince]
	ia.dodge = true
	go.call()
	ia.dodge = false
	var held: int = 1
	while a.stance == 2.0 and held < 40:
		go.call()
		held += 1
	if held != SimAct.dodgeWindow + 1:
		return "a dodge read as Dodge for %d ticks, not %d" % [held - 1, SimAct.dodgeWindow]
	ia.sprint = true
	ia.mx = away
	go.call()
	if a.stance != 3.0:
		return "sprint away is not Escape (stance %s)" % str(a.stance)
	ia.mx = -away
	go.call()
	if a.stance != 0.0:
		return "sprint toward read as %s" % str(a.stance)
	ia.sprint = false
	ia.mx = 0.0
	ia.mode = 1
	go.call()
	ia.mode = -1
	go.call()
	if a.act.mode != 1:
		return "the mode did not hold through auto (%d)" % a.act.mode
	a.act.dodgeCool = 3
	a.act.burstCool = 2
	go.call(); go.call(); go.call()
	if a.act.dodgeCool != 0 or a.act.burstCool != 0:
		return "the cooldowns did not count down"
	ia.guard = true
	a.stunTicks = 5
	go.call()
	if a.stance != 0.0 or a.input.guard:
		return "a stunned fighter kept its guard"
	a.stunTicks = 0
	ia.guard = false
	# the burst flag
	var ip := SimIntent.new()
	ip.powerPress = true
	SimAct.update(S, a, ip)
	if not SimAct.wantsBurst(a, ip, true):
		return "a threatened power press did not burst"
	var it := SimIntent.new()
	it.powerTap = true
	SimAct.update(S, a, it)
	if SimAct.wantsBurst(a, it, false):
		return "the tap after a burst-on-press fired a second burst"
	SimAct.update(S, a, ip)
	if SimAct.wantsBurst(a, ip, false):
		return "an unthreatened press burst at once"
	SimAct.update(S, a, it)
	if not SimAct.wantsBurst(a, it, false):
		return "an unthreatened tap did not burst"
	# the queue
	var pushed: int = 0
	for n in range(5):
		if SimAct.push(a, SimAct.LIGHT, 0, 1, 100 + n):
			pushed += 1
	if pushed != SimAct.queueMax or a.act.queue.size() != SimAct.queueMax:
		return "the queue took %d requests, not %d" % [pushed, SimAct.queueMax]
	if not SimAct.upgrade(a, SimAct.HEAVY) or a.act.queue[SimAct.queueMax - 1][0] != SimAct.HEAVY or a.act.queue[0][0] != SimAct.LIGHT:
		return "an upgrade did not replace the newest request's weight"
	SimAct.expire(a, 138, 36)   # pushed at ticks 100, 101, 102: the first two are older than 36 ticks, the last is exactly 36
	if a.act.queue.size() != SimAct.queueMax - 2 or SimAct.peek(a)[3] != 100 + SimAct.queueMax - 1:
		return "expiry left %d requests" % a.act.queue.size()
	if SimAct.pop(a)[0] != SimAct.HEAVY or not SimAct.pop(a).is_empty() or SimAct.upgrade(a, SimAct.SIG):
		return "pop or upgrade on an empty queue"
	# the tier-up gate, on (the data, since I2b): a threshold makes the form ready and the tier waits for the transform
	a.power = a.ld.thresholds[1] + 1.0   # two steps earned, whatever the thresholds are
	SimFighter.stepFighter(S, a, SimConst.DT)
	if a.tier != 1.0 or not a.act.formReady:
		return "with manualTierUp on the tier did not wait (tier %s, ready %s)" % [str(a.tier), str(a.act.formReady)]
	if not SimFighter.transform(S, a) or a.tier != 2.0 or not a.act.formReady:
		return "the first transform: tier %s, ready %s" % [str(a.tier), str(a.act.formReady)]
	if not SimFighter.transform(S, a) or a.tier != 3.0 or a.act.formReady or SimFighter.transform(S, a):
		return "the second transform: tier %s, ready %s" % [str(a.tier), str(a.act.formReady)]
	SimCore.dispose(S)
	# ... and off, from a copy of the data: the tier rises by itself
	var dir := "user://i2a_gate/"
	for id in ["KAI", "VORR"]:
		DirAccess.make_dir_recursive_absolute(dir + id)
		for fname in ["fighter.json", "wounds.json", "meters.json", "ladder.json"]:
			var text: String = FileAccess.get_file_as_string(FighterData.ROOT + id + "/" + fname)
			if fname == "ladder.json":
				var d = JSON.parse_string(text)
				d.manualTierUp = false
				text = JSON.stringify(d, "  ")
			var fw := FileAccess.open(dir + id + "/" + fname, FileAccess.WRITE)
			fw.store_string(text)
			fw.close()
	var rf := FileAccess.open(dir + "roster.json", FileAccess.WRITE)
	rf.store_string("[\"KAI\", \"VORR\"]")
	rf.close()
	FighterData.quiet = true
	FighterData.loadFrom(dir)
	var err: String = "; ".join(FighterData.errors())
	if err == "":
		var G := SimCore.createSim()
		SimCore.newMatch(G, 5)
		var f = G.fighters[0]
		f.power = f.ld.thresholds[0] + 1.0   # one step earned
		SimFighter.stepFighter(G, f, SimConst.DT)
		if f.tier != 2.0 or f.act.formReady or SimFighter.transform(G, f):
			err = "with manualTierUp off the tier did not rise by itself"
		SimCore.dispose(G)
	FighterData.quiet = false
	FighterData.loadFrom()
	return err


## Q10: pausing set pieces (sim/core/pause.gd), each rule asserted: the bank's start, accrual and cap; the full, short
## and live versions and what each spends; the final-form length; a live step; the time cap; two requests on one tick; a
## pause as frozen ticks (no input consumed, the clock and the fighters still, a hit-stop resumed after it); and a replay
## of an AI match that runs through a pause.
func _pause() -> String:
	if not SimPause.errors().is_empty():
		return "; ".join(SimPause.errors())
	var fresh := func() -> SimState:
		var S0 := SimCore.createSim()
		SimCore.newMatch(S0, 5)
		return S0
	var started := func(S0: SimState) -> int:
		var n: int = 0
		for e in S0.out.fx:
			if e.type == "pause_start":
				n += 1
		return n
	# the bank
	var S: SimState = fresh.call()
	var p = S.pause
	if p.bank != SimPause.bankStart or p.left != 0 or p.total != 0:
		return "a new match's bank is %d ticks, not %d" % [p.bank, SimPause.bankStart]
	p.bank = 0
	for t in range(SimPause.TPM):
		SimPause.liveTick(S)
	if p.bank != mini(SimPause.bankMax, SimPause.bankGain):
		return "a minute of match time gave the bank %d ticks, not %d" % [p.bank, SimPause.bankGain]
	p.bank = SimPause.bankMax - 1
	for t in range(SimPause.TPM):
		SimPause.liveTick(S)
	if p.bank != SimPause.bankMax:
		return "the bank passed its cap (%d)" % p.bank
	SimCore.dispose(S)
	# full, then a second request on the same tick, then the frozen ticks
	S = fresh.call()
	p = S.pause
	var kai = S.fighters[0]
	p.bank = SimPause.bankMax
	S.dirS.stop = 0.2
	var r: Dictionary = SimPause.request(S, SimPause.TRANSFORM, 0)
	if r.version != SimPause.FULL or r.ticks != SimPause.fullTicks or p.left != SimPause.fullTicks or p.bank != SimPause.bankMax - SimPause.fullTicks or started.call(S) != 1:
		return "the first set piece was not the full version (%s, bank %d)" % [str(r), p.bank]
	var r2: Dictionary = SimPause.request(S, SimPause.TRANSFORM, 1)
	if r2.version != SimPause.LIVE or r2.ticks != SimPause.liveTicks or p.left != SimPause.fullTicks or started.call(S) != 1:
		return "a second request on the same tick was not live (%s)" % str(r2)
	var t0: float = S.T
	var x0: float = kai.x
	var ki0: float = kai.ki
	var tick0: int = S.tick
	var ended: int = 0
	for t in range(SimPause.fullTicks):
		S.out.fx.clear()
		if SimCore.step(S, null):
			return "a paused tick consumed input (tick %d of the pause)" % t
		for e in S.out.fx:
			if e.type == "pause_end":
				ended += 1
	if S.T != t0 or kai.x != x0 or kai.ki != ki0 or S.tick != tick0 + SimPause.fullTicks or p.left != 0 or p.total != SimPause.fullTicks or ended != 1:
		return "the pause did not hold the sim still (T %s to %s, left %d, total %d, ends %d)" % [str(t0), str(S.T), p.left, p.total, ended]
	if S.dirS.stop != 0.2:
		return "the pause spent the hit-stop (%s)" % str(S.dirS.stop)
	var stops: int = 0
	while not SimCore.step(S, null) and stops < 100:
		stops += 1
	var H: SimState = fresh.call()   # the same hit-stop with no pause before it
	H.dirS.stop = 0.2
	var plain: int = 0
	while not SimCore.step(H, null) and plain < 100:
		plain += 1
	SimCore.dispose(H)
	if stops != plain or plain == 0 or S.T == t0:
		return "the hit-stop after the pause ran %d ticks, not %d" % [stops, plain]
	# short: a repeat, with the bank and the gap it needs; live below either
	p.bank = SimPause.shortTicks
	p.sinceEnd = SimPause.shortGap - 1
	r = SimPause.request(S, SimPause.TRANSFORM, 0)
	if r.version != SimPause.LIVE or p.bank != SimPause.shortTicks or p.left != 0:
		return "a request inside the short gap was not live (%s)" % str(r)
	p.sinceEnd = SimPause.shortGap
	r = SimPause.request(S, SimPause.TRANSFORM, 0)
	if r.version != SimPause.SHORT or r.ticks != SimPause.shortTicks or p.bank != 0 or p.left != SimPause.shortTicks:
		return "a repeat with the bank and the gap was not short (%s, bank %d)" % [str(r), p.bank]
	SimCore.dispose(S)
	# a first set piece inside the full gap, or with a thin bank
	S = fresh.call()
	p = S.pause
	p.bank = SimPause.bankMax
	p.sinceEnd = SimPause.fullGap - 1
	r = SimPause.request(S, SimPause.TRANSFORM, 0)
	if r.version != SimPause.SHORT:
		return "a first set piece inside the full gap was not short (%s)" % str(r)
	SimCore.dispose(S)
	S = fresh.call()
	p = S.pause
	p.bank = SimPause.shortTicks - 1
	r = SimPause.request(S, SimPause.TRANSFORM, 0)
	if r.version != SimPause.LIVE or p.bank != SimPause.shortTicks - 1 or p.left != 0 or started.call(S) != 0:
		return "a set piece the bank cannot cover was not live (%s)" % str(r)
	SimCore.dispose(S)
	# a final-form reveal takes what the bank covers, up to its own length
	S = fresh.call()
	p = S.pause
	p.bank = SimPause.bankMax
	r = SimPause.request(S, SimPause.TRANSFORM, 0, true)
	if r.version != SimPause.FULL or r.ticks != mini(SimPause.finalTicks, SimPause.bankMax):
		return "a final-form reveal: %s" % str(r)
	SimCore.dispose(S)
	# a live step never pauses and leaves the bank and the first-of-kind mark alone
	S = fresh.call()
	p = S.pause
	p.bank = SimPause.bankMax
	var kinds: Array = S.fighters[0].ld.stepKinds
	var was: String = kinds[0]
	kinds[0] = "live"
	r = SimPause.request(S, SimPause.TRANSFORM, 0)
	kinds[0] = was
	if r.version != SimPause.LIVE or p.bank != SimPause.bankMax or p.seen != 0 or p.left != 0:
		return "a live step: %s, bank %d, seen %d" % [str(r), p.bank, p.seen]
	# the time cap always pauses, outside the bank
	p.bank = 0
	r = SimPause.request(S, SimPause.TIMECAP, -1)
	if r.ticks != SimPause.capTicks or p.left != SimPause.capTicks or p.bank != 0:
		return "the time cap: %s, left %d" % [str(r), p.left]
	SimCore.dispose(S)
	# an AI match recorded through a pause plays back
	for seed in [3, 7, 12]:
		var R := SimCore.createSim()
		var rec := SimReplay.recorder(R, seed, {})
		var n: int = 0
		while n < 14400 and R.pause.total == 0:
			rec.step(null)
			R.out.fx.clear()
			R.out.feed.clear()
			n += 1
		var paused: bool = R.pause.total > 0
		for t in range(600):
			rec.step(null)
			R.out.fx.clear()
			R.out.feed.clear()
		var rp: Dictionary = rec.finish()
		SimCore.dispose(R)
		if not paused:
			continue
		var res: Dictionary = SimReplay.play(JSON.parse_string(JSON.stringify(rp)))
		return "" if res.ok else "a replay through a pause: %s at tick %d" % [res.reason, res.firstBadTick]
	return "no AI match of seeds 3, 7 and 12 reached a pause in four minutes"


## The agency pass's small core lines: the autoCharge assist reaches a slot from the setup; the flow count is 0 at the
## start and setFlow sends one flow event for a change and none for the same value; the embed fields start clear; the
## four events (knockback, exchange_end, flow, embed) carry their fields; and no default match sends any of them.
func _agencyLines() -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5, {"p1": false, "p2": false}, {"assists": [["autoCharge"], []]})
	var a = S.fighters[0]
	var b = S.fighters[1]
	if not SimAct.assisted(a, "autoCharge") or SimAct.assisted(b, "autoCharge") or SimAct.assisted(a, "autoBurst"):
		return "the autoCharge assist did not reach its slot alone"
	if a.act.flow != 0 or a.embedT != 0 or a.embedCool > -1.0e8:
		return "the flow count or the embed fields do not start clear"
	S.out.fx.clear()
	SimAct.setFlow(S, a, 3)
	SimAct.setFlow(S, a, 3)
	SimAct.setFlow(S, a, 0)
	var flows: Array = []
	for e in S.out.fx:
		if e.type == "flow" and int(e.actor) == 0:
			flows.append(int(e.n))
	if flows != [3, 0] or a.act.flow != 0:
		return "setFlow sent %s, not [3, 0]" % str(flows)
	S.out.fx.clear()
	SimFx.knockback(S, b, a, "long slide", 450.0, S.tick + 30)
	SimFx.exchangeEnd(S, a, "knockback")
	SimFx.embed(S, b, b.x, 12.0, 130.0, 300.0, 4.0, 1.5, 7)
	var k = S.out.fx[0]
	var x = S.out.fx[1]
	var m = S.out.fx[2]
	if k.type != "knockback" or int(k.victim) != 1 or int(k.attacker) != 0 or k.kind != "long slide" or k.amount != 450.0 or k.dur != 0.5 or k.n != S.tick + 30:
		return "the knockback event's fields"
	if x.type != "exchange_end" or int(x.actor) != 0 or x.kind != "knockback":
		return "the exchange_end event's fields"
	if m.type != "embed" or int(m.actor) != 1 or m.y != 12.0 or m.depth != 130.0 or m.r != 300.0 or m.energy != 4.0 or m.dur != 1.5 or m.n != 7:
		return "the embed event's fields"
	SimCore.dispose(S)
	return ""


## Shots (sim/core/shots.gd): none in a default match; a straight shot's speed, its life, the ground, and the seam; a
## seeking shot arriving on its tick at a moving target, near and far, with its damage; the fire tick's rest; trades in
## pairs with the rest landing, and a charged shot eating bolts; a deflect; the cap; a lob's arc and landing.
func _shots() -> String:
	if not SimShots.errors().is_empty():
		return "; ".join(SimShots.errors())
	var D := SimCore.createSim()
	SimCore.newMatch(D, 5)
	for t in range(600):
		SimCore.step(D)
		D.out.fx.clear()
		D.out.feed.clear()
		if not D.shots.is_empty():
			return "a default match has a shot in flight"
	SimCore.dispose(D)
	var dt: float = SimConst.DT
	var bolt: Dictionary = SimShots.kinds.bolt
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5, {"p1": false, "p2": false}, {"intro": false})
	var a = S.fighters[0]
	var b = S.fighters[1]
	var count := func(type: String, key: String = "", val = null) -> int:
		var c: int = 0
		for e in S.out.fx:
			if e.type == type and (key == "" or e.get(key) == val):
				c += 1
		return c
	var run := func(ticks: int) -> void:
		for t in range(ticks):
			SimShots.step(S, dt)
	# a straight shot: the fire tick's rest, the speed, the life
	a.x = 40000.0; a.y = 3000.0
	b.x = 70000.0; b.y = 9000.0
	var sh = SimShots.fire(S, 0, "bolt", {"ux": 1.0, "uy": 0.0})
	if sh == null or sh.id != 1 or count.call("shot_fire") != 1:
		return "fire did not make shot 1"
	var x0: float = sh.x
	run.call(1)
	if sh.x != x0:
		return "a shot moved on its fire tick"
	run.call(10)
	if absf(SimWrap.sdx(x0, sh.x) - 10.0 * bolt.speed) > 0.001 or sh.y != a.y + SimShots.chest:
		return "a straight bolt moved %s in 10 ticks, not %s" % [str(SimWrap.sdx(x0, sh.x)), str(10.0 * bolt.speed)]
	run.call(int(bolt.lifeTicks))
	if not S.shots.is_empty() or count.call("shot_end", "cause", "life") != 1:
		return "a straight bolt did not end with its life"
	# the seam
	S.out.fx.clear()
	a.x = SimConst.W - 100.0
	sh = SimShots.fire(S, 0, "bolt", {"ux": 1.0, "uy": 0.0})
	run.call(4)
	if absf(sh.x - (3.0 * bolt.speed - 100.0)) > 0.001:
		return "a bolt across the seam is at %s" % str(sh.x)
	SimShots.end(S, sh, "test")
	run.call(1)
	# the ground stops a straight shot
	S.out.fx.clear()
	a.x = 40000.0
	a.y = WorldTerrain.groundY(S, a.x) + 200.0
	sh = SimShots.fire(S, 0, "bolt", {"ux": 0.3, "uy": -1.0})
	run.call(30)
	if not S.shots.is_empty() or count.call("shot_end", "cause", "ground") != 1:
		return "a bolt fired at the ground did not end on it"
	# a seeking shot: near (the speed sets the time) and far (arriveTicks does), at a target that moves
	for far in [false, true]:
		S.out.fx.clear()
		a.y = 3000.0
		b.x = SimWrap.wrap(a.x + (30000.0 if far else 600.0))
		b.y = 3200.0
		var hp0: float = b.hp
		sh = SimShots.fire(S, 0, "bolt", {"target": 1})
		var want: int = mini(SimShots.arriveTicks, int(ceil(SimDetMath.hypot(SimWrap.sdx(a.x, b.x), b.y - a.y) / bolt.speed)))
		if (far and want != SimShots.arriveTicks) or (not far and want >= SimShots.arriveTicks):
			return "the seeking test's distances no longer straddle arriveTicks"
		if sh.left != want:
			return "a seeking bolt %s away takes %d ticks, not %d" % ["far" if far else "600", sh.left, want]
		run.call(1)
		for t in range(want):
			if S.shots.is_empty():
				return "a seeking bolt ended %d ticks early" % (want - t)
			b.x = SimWrap.wrap(b.x + 150.0)
			b.y += 20.0
			run.call(1)
		if not S.shots.is_empty() or count.call("shot_hit", "victim", 1.0) != 1 or b.hp != hp0 - bolt.dmg:
			return "a seeking bolt did not land on its tick (hits %d, hp %s to %s)" % [count.call("shot_hit"), str(hp0), str(b.hp)]
	# trades: three bolts against two cancel in pairs and one lands; a charged shot eats two bolts and lands
	for charged in [false, true]:
		S.out.fx.clear()
		a.x = 40000.0; a.y = 3000.0
		b.x = 42400.0; b.y = 3000.0
		var hpA: float = a.hp
		var hpB: float = b.hp
		if charged:
			SimShots.fire(S, 0, "charged", {"target": 1})
		else:
			for n in range(3):
				SimShots.fire(S, 0, "bolt", {"target": 1, "group": 7})
		for n in range(2):
			SimShots.fire(S, 1, "bolt", {"target": 0})
		run.call(60)
		var hitsB: int = count.call("shot_hit", "victim", 1.0)
		if not S.shots.is_empty() or count.call("shot_clash") != 2 or hitsB != 1 or a.hp != hpA or b.hp >= hpB:
			return "%s against two bolts: %d clashes, %d hits on the defender, attacker hp %s to %s" % ["a charged shot" if charged else "three bolts", count.call("shot_clash"), hitsB, str(hpA), str(a.hp)]
	# a deflect sends it back to its owner
	S.out.fx.clear()
	var hpA2: float = a.hp
	sh = SimShots.fire(S, 0, "bolt", {"target": 1})
	run.call(5)
	SimShots.deflect(S, sh, 1)
	if sh.owner != 1 or sh.tgt != 0 or sh.deflected != 1:
		return "a deflect did not turn the shot"
	run.call(60)
	if count.call("shot_hit", "victim", 0.0) != 1 or a.hp != hpA2 - bolt.dmg:
		return "a deflected bolt did not land on its old owner"
	# the cap
	b.x = SimWrap.wrap(a.x + 60000.0)
	var made: int = 0
	for n in range(SimShots.cap + 5):
		if SimShots.fire(S, 0, "bolt", {"target": 1}) != null:
			made += 1
	if made != SimShots.cap or S.shots.size() != SimShots.cap:
		return "the cap let %d shots fly, not %d" % [made, SimShots.cap]
	for q in S.shots:
		SimShots.end(S, q, "test")
	run.call(1)
	# a lob: up, over, and down on its point
	S.out.fx.clear()
	a.y = WorldTerrain.groundY(S, a.x) + 100.0
	var lobk: Dictionary = SimShots.kinds.lob
	sh = SimShots.fire(S, 0, "lob", {"px": a.x + 900.0, "py": WorldTerrain.groundY(S, a.x + 900.0)})
	var top: float = sh.y
	run.call(1)
	for t in range(int(lobk.lobTicks)):
		if S.shots.is_empty():
			return "a lob ended %d ticks early" % (int(lobk.lobTicks) - t)
		top = maxf(top, sh.y)
		run.call(1)
	if not S.shots.is_empty() or count.call("shot_end", "cause", "ground") != 1 or top < a.y + SimShots.chest + lobk.lobArc * 0.5:
		return "a lob did not arc and land (top %s)" % str(top)
	SimCore.dispose(S)
	return ""


## The last stand (sim/core/fighter.gd): the window opens at a fighter's first brink and not at a second; it counts only
## while he is free and not stunned; it runs out with last_stand_end expired; a use closes it; with the data's window at
## 0 nothing opens. When the director's gates are in (they read sigFree), a free signature starts with no ki and inside
## the cooldown, costs nothing and closes the window.
func _lastStand() -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5, {"p1": false, "p2": false})
	var a = S.fighters[0]
	var n: int = a.wd.lastStandTicks
	var core: int = SimWounds.CORE
	var toBrink := func() -> void:
		a.wear[core] = SimWounds.STAGE_AT[2]
		SimWounds.updateStages(S, a)
	var count := func(type: String, kind: String) -> int:
		var c: int = 0
		for e in S.out.fx:
			if e.type == type and (kind == "" or e.kind == kind) and int(e.actor) == 0:
				c += 1
		return c
	toBrink.call()
	if not a.brink:
		return "the forced brink did not take"
	if n <= 0:
		SimCore.dispose(S)
		return "" if (a.lastStandLeft == 0 and count.call("last_stand_ready", "") == 0) else "with the window at 0 a last stand opened"
	if not a.lastStandUsed or a.lastStandLeft != n or count.call("last_stand_ready", "") != 1 or not SimFighter.sigFree(a):
		return "the first brink did not open the last stand (left %d of %d)" % [a.lastStandLeft, n]
	# it counts only while he is free and not stunned
	a.state = "locked"
	for t in range(10):
		SimFighter.stepFighter(S, a, SimConst.DT)
	a.state = "free"
	a.stunTicks = 100
	for t in range(10):
		SimFighter.stepFighter(S, a, SimConst.DT)
	if a.lastStandLeft != n:
		return "the window ran while he was locked or stunned (%d of %d)" % [a.lastStandLeft, n]
	a.stunTicks = 0
	for t in range(10):
		SimFighter.stepFighter(S, a, SimConst.DT)
	if a.lastStandLeft != n - 10:
		return "the window did not count his free ticks (%d, wants %d)" % [a.lastStandLeft, n - 10]
	# a use closes it
	S.out.fx.clear()
	SimFighter.lastStandUse(S, a)
	if a.lastStandLeft != 0 or SimFighter.sigFree(a) or count.call("last_stand_end", "used") != 1:
		return "a use did not close the window"
	# a second brink gives nothing
	a.wear[core] = 0
	SimWounds.updateStages(S, a)
	S.out.fx.clear()
	toBrink.call()
	if a.lastStandLeft != 0 or count.call("last_stand_ready", "") != 0:
		return "a second brink opened a second last stand"
	# it runs out
	var b = S.fighters[1]
	b.wear[core] = SimWounds.STAGE_AT[2]
	SimWounds.updateStages(S, b)
	b.lastStandLeft = 2
	b.state = "free"
	b.stunTicks = 0
	S.out.fx.clear()
	SimFighter.stepFighter(S, b, SimConst.DT)
	SimFighter.stepFighter(S, b, SimConst.DT)
	var expired: int = 0
	for e in S.out.fx:
		if e.type == "last_stand_end" and e.kind == "expired" and int(e.actor) == 1:
			expired += 1
	if b.lastStandLeft != 0 or expired != 1:
		return "the window did not run out with one last_stand_end (left %d, %d events)" % [b.lastStandLeft, expired]
	SimCore.dispose(S)
	return _lastStandGates()


## The director's side of the last stand; "" until its gates are in.
func _lastStandGates() -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5, {"p1": false, "p2": false})
	var a = S.fighters[0]
	if a.wd.lastStandTicks <= 0:
		SimCore.dispose(S)
		return ""
	S.dirS.cool = 0.0
	a.ki = 0.0
	a.sigReadyT = S.T + 100.0
	DirExchange.requestAttack(S, a, "sig")
	if S.dirS.ex != null:
		return "a signature with no ki, inside the cooldown, started without a last stand"
	a.lastStandUsed = true
	a.lastStandLeft = 600
	S.out.fx.clear()
	DirExchange.requestAttack(S, a, "sig")
	var used: int = 0
	for e in S.out.fx:
		if e.type == "last_stand_end" and e.kind == "used":
			used += 1
	if S.dirS.ex == null or S.dirS.ex.kind != "sig" or a.ki != 0.0 or a.lastStandLeft != 0 or used != 1:
		return "the free signature: exchange %s, ki %s, window %d, %d used events" % [str(S.dirS.ex != null), str(a.ki), a.lastStandLeft, used]
	if a.sigReadyT <= S.T:
		return "the free signature did not start the ordinary cooldown"
	SimCore.dispose(S)
	return ""


## The intro phase (sim/core/intro.gd): off unless the setup asks; with it, the timeline's events on their ticks, every
## tick pre-clock (step false, S.T at 0), the falls going down, both craters dug, both fighters free on the ground at the
## clock; a press before skipFrom ignored and one after it skipping; the state at the clock the same whether the intro
## ran, was skipped at any tick, or was applied by the setup's "skip"; AI slots never skipping; a replay through a skip.
func _intro() -> String:
	if not SimIntro.errors().is_empty():
		return "; ".join(SimIntro.errors())
	var D := SimCore.createSim()
	SimCore.newMatch(D, 5)
	if D.intro.left != 0 or D.craters.size() != 2 or not SimCore.step(D, null):
		return "a match whose setup does not say did not start from the intro's end state"
	SimCore.newMatch(D, 5, {}, {"intro": false})
	if D.intro.left != 0 or D.craters.size() != 0 or D.fighters[0].y != 60.0:
		return "intro false did not give the flat start"
	SimCore.dispose(D)
	var quiet := SimIntent.new()
	var press := SimIntent.new()
	press.light = true
	var clockState := func(S0: SimState) -> String:   # the state at the clock, without the tick counters
		S0.tick = 0
		S0.intro.t = 0
		return SimHash.stateHash(S0).gameplay
	# the full intro, two human slots that press nothing
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5, {"p1": false, "p2": false}, {"intro": true})
	var a = S.fighters[0]
	var b = S.fighters[1]
	if a.state != "intro" or S.intro.left != SimIntro.clock or a.y != WorldTerrain.groundY(S, a.x) + SimIntro.fallHeight:
		return "the intro did not start (state %s, left %d)" % [a.state, S.intro.left]
	var at := {}
	var lastY: Array = [a.y, b.y]
	var cool0: float = S.dirS.cool
	var marks: int = 0
	for t in range(SimIntro.clock):
		S.out.fx.clear()
		if SimCore.step(S, [quiet, quiet]):
			return "pre-clock tick %d was live" % t
		if S.T != 0.0 or S.mood.t != 0 or S.pause.bank != SimPause.bankStart or S.dirS.cool != cool0:
			return "the clock, the mood, the pause bank or the director's cooldown moved during the intro"
		for e in S.out.fx:
			if e.type == "tick" and not e.frozen:
				marks += 1   # an intro tick is live for effects (dust settles at full speed), though the sim holds
			if e.type in ["intro_start", "entrance_fall", "entrance_land", "staredown_start", "clock_start"]:
				at["%s%s" % [e.type, ("" if e.actor < 0.0 else str(int(e.actor)))]] = t
		for k in range(2):
			if S.fighters[k].y > lastY[k]:
				return "slot %d rose during his fall" % k
			lastY[k] = S.fighters[k].y
	if marks != SimIntro.clock:
		return "%d of the intro's %d ticks were marked live for effects" % [marks, SimIntro.clock]
	var want := {"intro_start": 0, "entrance_fall0": SimIntro.fall[0], "entrance_land0": SimIntro.land[0], "entrance_fall1": SimIntro.fall[1],
		"entrance_land1": SimIntro.land[1], "staredown_start": SimIntro.staredown, "clock_start": SimIntro.clock - 1}
	for k in want:
		if at.get(k, -1) != want[k]:
			return "%s came at tick %s, not %d" % [k, str(at.get(k, "never")), want[k]]
	if a.state != "free" or b.state != "free" or a.y != WorldTerrain.groundY(S, a.x) or S.craters.size() != 2 or S.intro.left != 0:
		return "at the clock: states %s and %s, %d craters" % [a.state, b.state, S.craters.size()]
	var full: String = clockState.call(S)
	if not SimCore.step(S, [quiet, quiet]) or S.T <= 0.0:
		return "the tick after the clock was not live"
	SimCore.dispose(S)
	# a press too early is ignored; a press later skips, from any point, to the same state
	for at_tick in [SimIntro.skipFrom, SimIntro.land[0] + 3, SimIntro.land[1] + 3, SimIntro.clock - 1]:
		var K := SimCore.createSim()
		SimCore.newMatch(K, 5, {"p1": false, "p2": false}, {"intro": true})
		for t in range(at_tick):
			SimCore.step(K, [press if t < SimIntro.skipFrom else quiet, quiet])
		if K.intro.left != SimIntro.clock - at_tick:
			return "a press before skipFrom skipped the intro"
		K.out.fx.clear()
		if SimCore.step(K, [quiet, press]) or K.intro.left != 0:
			return "a press at tick %d did not skip" % at_tick
		var kind: String = ""
		for e in K.out.fx:
			if e.type == "clock_start":
				kind = e.kind
		if kind != "skip":
			return "a skip's clock_start kind is '%s'" % kind
		if clockState.call(K) != full:
			return "a skip at tick %d left another state at the clock than the full intro" % at_tick
		SimCore.dispose(K)
	var Q := SimCore.createSim()
	SimCore.newMatch(Q, 5, {"p1": false, "p2": false}, {"intro": "skip"})
	if Q.intro.left != 0 or not Q.out.fx.is_empty() or clockState.call(Q) != full:
		return "the setup's skip did not give the state at the clock"
	SimCore.dispose(Q)
	# AI slots never skip
	var A := SimCore.createSim()
	SimCore.newMatch(A, 5, {}, {"intro": true})
	for t in range(SimIntro.clock - 1):
		SimCore.step(A, [press, press])
	if A.intro.left != 1:
		return "an AI slot's intent skipped the intro"
	SimCore.dispose(A)
	# a replay through a skip
	var R := SimCore.createSim()
	var rec := SimReplay.recorder(R, 9, {"p1": false, "p2": true}, {"intro": true})
	for t in range(400):
		rec.step([press if t == SimIntro.skipFrom + 5 else quiet, null])
		R.out.fx.clear()
		R.out.feed.clear()
	if R.intro.t != SimIntro.skipFrom + 6:
		return "the recorded match did not skip where it pressed (%d)" % R.intro.t
	var rp: Dictionary = rec.finish()
	SimCore.dispose(R)
	var res: Dictionary = SimReplay.play(JSON.parse_string(JSON.stringify(rp)))
	return "" if res.ok else "a replay through a skipped intro: %s at tick %d" % [res.reason, res.firstBadTick]


## Fight lanes, L0 and L2 (docs/architecture/fight-lanes.md). The player never steers depth: the intent has no depth field
## and nothing in sim/input writes a depth. Depth is off unless the setup or the director's switch asks for it, and a
## default match keeps every home depth at 0. With it on (a forced setup): a free fighter eases to his home depth; a rush
## homes in depth and leaves him there; a fighter in an exchange takes its depth; a flight's end is the new home; and
## nothing leaves the band.
func _depth() -> String:
	for prop in SimIntent.new().get_property_list():
		var pn: String = prop.name
		if pn == "z" or pn == "zT" or pn == "depth" or pn == "lane" or pn == "mz":
			return "SimIntent has a depth field: " + pn
	var rx := RegEx.new()
	rx.compile("\\.(z|zT|zWay|aimZ0|aimZ1|pz|oz|zs)\\s*(=[^=]|\\+=|-=|\\*=)")
	var d := DirAccess.open("res://sim/input")
	for fname in d.get_files():
		if not fname.ends_with(".gd"):
			continue
		var src: String = FileAccess.get_file_as_string("res://sim/input/" + fname)
		var m := rx.search(src)
		if m != null:
			return "sim/input/%s writes a depth: %s" % [fname, m.get_string()]
	var P := SimCore.createSim()
	SimCore.newMatch(P, 5)
	if P.depthOn:
		return "depth is on in a default match"
	for t in range(600):
		SimCore.step(P)
		P.out.fx.clear()
		P.out.feed.clear()
		for f in P.fighters:
			if f.zT != 0.0:
				return "with depth off a home depth moved (%s at tick %d)" % [str(f.zT), t]
	SimCore.dispose(P)
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5, {"p1": false, "p2": false}, {"depth": true})
	if not S.depthOn:
		return "the setup's depth switch did not reach the sim"
	var a = S.fighters[0]
	var b = S.fighters[1]
	var dt: float = SimConst.DT
	# the free ease, and the band
	a.z = 300.0
	a.zT = -600.0
	var last: float = a.z
	for t in range(240):
		SimFighter.stepDepth(S, a, dt)
		if a.z > last:
			return "the free ease moved away from the home depth"
		last = a.z
	if a.z != -600.0:
		return "a free fighter did not reach his home depth (%s)" % str(a.z)
	a.zT = -99999.0
	for t in range(600):
		SimFighter.stepDepth(S, a, dt)
	if a.z != SimConst.Z_BACK or a.zT != SimConst.Z_BACK:
		return "the band did not hold the back edge (z %s, home %s)" % [str(a.z), str(a.zT)]
	a.z = 99999.0
	SimFighter.stepDepth(S, a, dt)
	if a.z > SimConst.Z_FRONT:
		return "the band did not hold the front edge"
	# a rush homes in depth and leaves him there
	a.z = 0.0
	a.zT = 0.0
	b.z = -900.0
	b.zT = -900.0
	var r := SimState.Rush.new()
	r.tgt = b
	r.off = -60.0
	r.end = S.T + 0.5
	a.rush = r
	var steps: int = 0
	while a.rush != null and steps < 200:
		SimFighter.stepRush(S, a, dt)
		SimFighter.stepDepth(S, a, dt)
		S.T += dt
		steps += 1
	if a.z != -900.0 or a.zT != -900.0:
		return "a rush did not home in depth (z %s, home %s after %d ticks)" % [str(a.z), str(a.zT), steps]
	var r2 := SimState.Rush.new()
	r2.px = a.x + 400.0
	r2.py = a.y
	r2.pz = -300.0
	r2.end = S.T + 0.3
	a.rush = r2
	steps = 0
	while a.rush != null and steps < 200:
		SimFighter.stepRush(S, a, dt)
		S.T += dt
		steps += 1
	if a.z != -300.0:
		return "a point rush did not reach its depth (%s)" % str(a.z)
	# an exchange's depth is the home of both fighters
	var ex := SimState.Exchange.new()
	ex.A = a
	ex.D = b
	ex.z = -450.0
	S.dirS.ex = ex
	SimFighter.stepDepth(S, a, dt)
	SimFighter.stepDepth(S, b, dt)
	if a.zT != -450.0 or b.zT != -450.0:
		return "an exchange's depth did not become the fighters' home (%s, %s)" % [str(a.zT), str(b.zT)]
	S.dirS.ex = null
	# a flight's end is the new home
	a.state = "launched"
	a.z = -1200.0
	SimFighter.stepDepth(S, a, dt)
	a.state = "free"
	SimFighter.stepDepth(S, a, dt)
	if a.zT != -1200.0 or a.z != -1200.0:
		return "a flight's end did not become the home depth (z %s, home %s)" % [str(a.z), str(a.zT)]
	SimCore.dispose(S)
	return ""


## The mood's form impulse: a transformation's break adds impulses.form to the mood, by a call (SimMood.onForm) and not
## from the tier_up event, so it is also given when the break lands on a frozen tick inside a full pause.
func _formImpulse() -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5)
	var a = S.fighters[0]
	a.stance = 1.0   # not AGGRESSIVE: the plain impulse
	var want: int = SimMood.imp["form"][0]
	if want <= 0:
		return "mood.json impulses.form is 0"
	a.power = a.ld.thresholds[0] + 1.0
	a.act.formReady = true
	a.y = 20000.0
	S.pause.bank = SimPause.bankMax
	var r: Dictionary = SimPause.request(S, SimPause.TRANSFORM, 0)
	SimFighter.transform(S, a)
	if r.version != SimPause.FULL:
		return "the set-up did not give a full pause"
	var v0: int = S.mood.v
	var g: int = SimPause.gather[SimPause.FULL]
	for t in range(1, g + 1):
		if SimCore.step(S, null):
			return "tick %d of the pause was live" % t
		if S.mood.v != (v0 + want if t == g else v0):
			return "at paused tick %d the mood is %d (it was %d; the impulse is %d and the gather %d)" % [t, S.mood.v, v0, want, g]
	SimCore.dispose(S)
	return ""


## The break (moveset-rules.md section 10.8): a transformation's tier-up lands at the end of the version's gather, not on
## the request tick. Full and short: on a frozen tick inside the pause, exactly the gather after the request, with its
## tier_up there. Live: after the gather in live ticks. A second fighter's live gather starts when the first one's pause
## ends. A taken step cannot be taken again during its gather. No break once the match is over. A further step already
## earned is ready at the break, with its transform_ready.
func _formBreak() -> String:
	var ready := func(f) -> void:
		f.power = f.ld.thresholds[0] + 1.0
		f.act.formReady = true
		f.y = 20000.0   # airborne: no crater
	var take := func(S0: SimState, slot: int, bank: int) -> Dictionary:
		S0.pause.bank = bank
		var r0: Dictionary = SimPause.request(S0, SimPause.TRANSFORM, slot)
		SimFighter.transform(S0, S0.fighters[slot])
		return r0
	var tierUps := func(S0: SimState) -> int:
		var n: int = 0
		for e in S0.out.fx:
			if e.type == "tier_up":
				n += 1
		return n
	for version in [SimPause.FULL, SimPause.SHORT]:
		var S := SimCore.createSim()
		SimCore.newMatch(S, 5)
		var a = S.fighters[0]
		ready.call(a)
		if version == SimPause.SHORT:
			S.pause.seen = 1   # a repeat
		var r: Dictionary = take.call(S, 0, SimPause.bankMax)
		var g: int = SimPause.gather[version]
		if r.version != version or a.tier != 1.0 or a.act.breakIn != g or a.act.formReady or SimFighter.transform(S, a):
			return "%s: after the request tier %s, breakIn %d, ready %s" % [SimPause.VERSIONS[version], str(a.tier), a.act.breakIn, str(a.act.formReady)]
		for t in range(1, int(r.ticks) + 1):
			S.out.fx.clear()
			if SimCore.step(S, null):
				return "%s: tick %d of the pause was live" % [SimPause.VERSIONS[version], t]
			var want: float = 2.0 if t >= g else 1.0
			if a.tier != want or tierUps.call(S) != (1 if t == g else 0):
				return "%s: at paused tick %d the tier is %s and %d tier_up events (the gather is %d)" % [SimPause.VERSIONS[version], t, str(a.tier), tierUps.call(S), g]
		if a.act.breakIn != -1:
			return "%s: breakIn %d after the pause" % [SimPause.VERSIONS[version], a.act.breakIn]
		SimCore.dispose(S)
	# live, and a second fighter whose gather waits for the first one's pause
	var L := SimCore.createSim()
	SimCore.newMatch(L, 5)
	var k = L.fighters[0]
	var v = L.fighters[1]
	ready.call(k)
	ready.call(v)
	var r1: Dictionary = take.call(L, 0, SimPause.bankMax)
	var r2: Dictionary = take.call(L, 1, L.pause.bank)
	if r1.version != SimPause.FULL or r2.version != SimPause.LIVE or v.act.breakIn != SimPause.gather[SimPause.LIVE]:
		return "two requests on one tick: %s then %s" % [str(r1), str(r2)]
	for t in range(int(r1.ticks)):
		SimCore.step(L, null)
	if k.tier != 2.0 or v.tier != 1.0 or v.act.breakIn != SimPause.gather[SimPause.LIVE]:
		return "the second fighter's gather ran during the first one's pause (tier %s, breakIn %d)" % [str(v.tier), v.act.breakIn]
	var live: int = 0
	while v.tier == 1.0 and live < 200:
		if SimCore.step(L, null):
			live += 1
	if live != SimPause.gather[SimPause.LIVE]:
		return "a live break came after %d live ticks, not %d" % [live, SimPause.gather[SimPause.LIVE]]
	# a further step already earned is ready at the break
	k.power = k.ld.thresholds[2] + 0.0
	k.act.formReady = true
	L.pause.sinceEnd = 0
	take.call(L, 0, 0)
	L.out.fx.clear()
	var again: int = 0
	live = 0
	while k.tier == 2.0 and live < 200:
		L.out.fx.clear()
		if SimCore.step(L, null):
			live += 1
	for e in L.out.fx:
		if e.type == "transform_ready" and int(e.actor) == 0 and e.tier == 4.0:
			again += 1
	if k.tier != 3.0 or not k.act.formReady or again != 1:
		return "a further earned step at the break: tier %s, ready %s, %d transform_ready events" % [str(k.tier), str(k.act.formReady), again]
	SimCore.dispose(L)
	# no break once the match is over
	var E := SimCore.createSim()
	SimCore.newMatch(E, 5)
	var e0 = E.fighters[0]
	ready.call(e0)
	take.call(E, 0, 0)
	E.game.ko = E.fighters[1]
	for t in range(60):
		SimCore.step(E, null)
	if e0.tier != 1.0:
		return "the break landed after the KO"
	SimCore.dispose(E)
	return ""


## Q10: the act rule under actBeats.formSteps (1 + the larger of form steps and wound beats, + region breaks, capped), a
## form step announced as an act with cause form, and the finisher contest with no survival from the time cap (both
## contest paths; before the cap the chance is above 0).
func _actRule() -> String:
	if not SimMood.formSteps:
		return "mood.json actBeats.formSteps is off"
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5)
	var a = S.fighters[0]
	var b = S.fighters[1]
	var m = S.mood
	var cases: Array = [   # [tier a, tier b, once mask, breaks, act]
		[1.0, 1.0, 0, 0, 1], [2.0, 1.0, 0, 0, 2], [2.0, 3.0, 0, 0, 3], [1.0, 1.0, 7, 0, 4], [3.0, 1.0, 1, 0, 3],
		[1.0, 1.0, 3, 0, 3], [2.0, 2.0, 1, 1, 3], [3.0, 1.0, 1, 1, 4], [4.0, 4.0, 7, 5, 4], [1.0, 1.0, 0, 2, 3]]
	for c in cases:
		a.tier = c[0]
		b.tier = c[1]
		m.onceMask = c[2]
		m.breaks = c[3]
		if SimMood.act(S) != c[4]:
			return "act for tiers %s and %s, wound beats mask %d, breaks %d is %d, not %d" % [str(c[0]), str(c[1]), c[2], c[3], SimMood.act(S), c[4]]
	a.tier = 1.0
	b.tier = 1.0
	m.onceMask = 0
	m.breaks = 0
	a.act.formReady = true
	a.y = 20000.0   # airborne: no crater
	S.out.fx.clear()
	if not SimFighter.transform(S, a):
		return "the forced transform did not run"
	SimMood.tick(S)
	var cause: String = ""
	for e in S.out.fx:
		if e.type == "act_change":
			cause = "%d %s" % [int(e.n), e.kind]
	if cause != "2 form":
		return "a form step announced '%s', not act 2 with cause form" % cause
	# the contest: no survival from the time cap
	for path in ["plain", "branch"]:
		for capped in [false, true]:
			S.game.timeCap = capped
			S.out.fx.clear()
			var ex := SimState.Exchange.new()
			ex.A = a
			ex.D = b
			if path == "plain":
				DirExchange._opContest(S, ex, {"w": "A"})
			else:
				DirExchange._opContestBranch(S, ex, {"w": "A"})
			var chance: float = -1.0
			var lived: bool = false
			for e in S.out.fx:
				if e.type == "finisher_contest":
					chance = e.chance
					lived = e.survived
			if capped and (chance != 0.0 or lived):
				return "from the time cap the %s contest gave chance %s, survived %s" % [path, str(chance), str(lived)]
			if not capped and chance <= 0.0:
				return "before the time cap the %s contest's chance was %s" % [path, str(chance)]
			S.game.ko = null
	SimCore.dispose(S)
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
	# I2a: two v2 slots, their stance following the scripted held fields, record and play back from the header alone.
	var src3: Dictionary = SimGolden.scriptedReplay(17, 900, true, [])
	var S3 := SimCore.createSim()
	var rec3 := SimReplay.recorder(S3, 17, src3.ai, {"v2": [true, true]})
	var cur3: Array = [null, null]
	var i3: int = 0
	var stances := {}
	for t in range(int(src3.ticks)):
		while i3 < src3.inputs.size() and int(src3.inputs[i3][0]) == t:
			cur3[int(src3.inputs[i3][1])] = SimGolden._intent(src3.inputs[i3][2])
			i3 += 1
		rec3.step(cur3)
		stances[S3.fighters[0].stance] = true
	var rp3: Dictionary = rec3.finish()
	SimCore.dispose(S3)
	r = SimReplay.play(JSON.parse_string(JSON.stringify(rp3)))
	if not r.ok:
		return "v2 replay: %s at tick %d" % [r.reason, r.firstBadTick]
	if stances.size() < 3:
		return "the v2 replay's derived stance took only %d values" % stances.size()
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
	if not SimPause.errors().is_empty():
		return "data/fight/pause.json: " + "; ".join(SimPause.errors())
	if not SimIntro.errors().is_empty():
		return "data/fight/intro.json: " + "; ".join(SimIntro.errors())
	if not SimShots.errors().is_empty():
		return "data/fight/shots.json: " + "; ".join(SimShots.errors())
	var fh: String = SimMood.dataHash() + SimPause.dataHash() + SimIntro.dataHash() + SimShots.dataHash()
	if fh != g.get("fightHash", ""):
		return "the fight data hash differs (data/fight/ changed): %s vs golden %s; regenerate the goldens if the edit is meant" % [fh, g.get("fightHash", "")]
	return ""


## D1b, made robust in I1: every wired number in meters.json, ladder.json and guardWearSplit changes what the sim does
## when edited (QA found the meters were documentation only). Each row copies data/fighters/ to user://, sets one value
## (ladder and guard edits in both fighters' files) and runs a forced probe: a fresh match, the state that number needs,
## one call into the code that reads it, and the values that call produced. The probe's result with the edited data must
## differ from its result with the real data. No probe plays a match, so a changed opening cannot break a row (the old
## check played seeds and needed new ones after B2 and after the terrain fixes). The end-to-end row is forced as well: VORR,
## with menace set, attacks KAI through the director, and what KAI took must differ (it played seeds until they needed
## replacing three times). composure.below is left out: it only matters while composure's cap is not 0.
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
	[["KAI/ladder.json", "VORR/ladder.json"], ["chargePerSec"], 7.0, "chargeTick"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["tiers", "speed"], 0.5, "speed"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["tiers", "damage"], 0.5, "tierHit"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["tiers", "launch"], 0.8, "launch"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["powerUp", "areaR"], 600.0, "powerUp"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["powerUp", "areaRPerTier"], 300.0, "powerUp"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["powerUp", "areaDmg"], 900.0, "powerUp"],
	[["KAI/ladder.json", "VORR/ladder.json"], ["powerUp", "areaDmgPerTier"], 900.0, "powerUp"],
	[["KAI/wounds.json", "VORR/wounds.json"], ["guardWearSplit"], {"arms": 0.75, "legs": 0.25}, "guard"],
	["VORR/meters.json", ["meters", "menace", "effects", 1, "cap"], 1.0, "vorrExchange"],   # end to end, forced: through the director
]


func _wiredNumbers() -> String:
	var files := {}
	for id in FighterData.order():
		for fname in ["fighter.json", "wounds.json", "meters.json", "ladder.json"]:
			files[id + "/" + fname] = FileAccess.get_file_as_string(FighterData.ROOT + id + "/" + fname)
	var base := {}
	for c in WIRED:
		if not base.has(c[3]):
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
		"vorrExchange":   # end to end, forced: VORR, with menace, attacks KAI through the director; what KAI took
			kai.ai = null
			vorr.ai = null
			var hp0: float = kai.hp
			var asked: int = 0
			for t in range(600):
				vorr.menace = 50.0
				vorr.menaceSeen = 50.0
				vorr.menaceQuiet = 0
				if S.dirS.ex == null and kai.hp == hp0 and t >= 60:
					DirExchange.requestAttack(S, vorr, "heavy")
					asked += 1
				SimCore.step(S)
				S.out.fx.clear()
				S.out.feed.clear()
				if kai.hp != hp0 and S.dirS.ex == null:
					break
			if kai.hp == hp0:
				out = ["!VORR's attack never hurt KAI (%d requests)" % asked]
			else:
				out = [kai.hp, kai.wear[0], kai.wear[1], kai.wear[2], kai.wear[3]]
		"chargeTick":   # Q10: the charge rate
			kai.power = 15.0
			kai.state = "charging"
			kai.input.charge = true
			SimFighter.stepFighter(S, kai, SimConst.DT)
			out = [kai.power]
		"ladderTick":   # the fill and the thresholds
			kai.power = 15.0
			SimFighter.stepFighter(S, kai, SimConst.DT)
			out = [kai.power, kai.tier, kai.act.formReady]   # I2b: the tier waits for the transform, so the thresholds show in formReady
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
