extends SceneTree
## Combat data loader regression (docs/combat/s3b-loader-note.md, step 1 kept as a test): every exchange, chain link and
## finisher is planned twice from the same RNG state, once with the live data and once with the frozen copy of the
## parity data in sim/director/test/combat-parity/ (proven bit-identical to the code it replaced at 69c4a2f, and to the
## goldens), both in the parity profile. The two plans must be identical: the same beats in the same order, the same
## time bits, deep-equal args with the same key types, the same tag and the same RNG state. It also counts which template
## branches were exercised.
##   godot --headless --path . --script res://sim/director/tools/loader_check.gd -- [matches=200] [baseSeed=1] [--arm=NAME]
## Exit code 1 on any difference, and on an unexercised branch in a full run (200 matches or more: a rare branch such as
## CHARGE INTERRUPT may not come up in a short one, where it is only noted).

var diffs: Array = []
var plans: int = 0
var seen := {}


func _init() -> void:
	var pos: Array = []
	var arm: String = "default"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arm="):
			arm = a.substr(6)
		else:
			pos.append(a)
	var n: int = int(pos[0]) if pos.size() > 0 else 200
	var base: int = int(pos[1]) if pos.size() > 1 else 1
	DirData.templatesProfile = "parity"
	DirData.finishersProfile = "parity"
	DirExchange.checkData = [DirData.parseFile("res://sim/director/test/combat-parity/templates.json"), DirData.parseFile("res://sim/director/test/combat-parity/finishers.json")]
	DirExchange.planCheck = _check
	for i in range(n):
		var S := SimCore.createSim()
		SimCore.newMatch(S, base + i)
		SimGolden.applyArm(arm, S.fighters)
		var steps: int = 0
		while steps < 43200 and S.game.ko == null and diffs.size() < 10:
			SimCore.step(S)
			steps += 1
			S.out.fx.clear()
			S.out.feed.clear()
		SimCore.dispose(S)
	print("plans compared: %d over %d matches (%s from seed %d)" % [plans, n, arm, base])
	var keys: Array = seen.keys()
	keys.sort()
	for k in keys:
		print("  %6d  %s" % [seen[k], k])
	var want: Array = ["melee:CHARGE INTERRUPT", "melee:PURSUIT — TARGET SLIPS AWAY", "melee:PURSUIT — CAUGHT", "melee:DODGE & READ", "melee:DODGE & COUNTER",
		"melee:PRESSURE — GUARD HOLDS", "melee:PRESSURE — GUARD HOLDS → COUNTER", "melee:GUARD BREAK", "melee:TRADE BLOWS", "melee:HEAVY CLASH — WON",
		"melee:HEAVY CLASH — COUNTERED", "melee:CLASH SHOCKWAVE", "chain", "finisher", "sig:CLASH", "sig:GUARD", "sig:DODGE", "sig:HIT", "sig:ESCAPE"]
	var missing: Array = want.filter(func(k): return not seen.has(k))
	for d in diffs:
		print("DIFF " + d)
	var full: bool = n >= 200   # coverage is a rule only for a full run
	if not missing.is_empty():
		print(("NOT EXERCISED: " if full else "not exercised in this short run (a note under 200 matches): ") + ", ".join(missing))
	var okRun: bool = diffs.is_empty() and (missing.is_empty() or not full)
	print("loader check " + ("passed" if okRun else "FAILED"))
	quit(0 if okRun else 1)


func _check(chk: Dictionary, ex, rngAfter: int, what: String) -> void:
	plans += 1
	var c = chk.ex
	var key: String = what
	if what == "melee":
		key = "melee:" + ex.tag
	elif what == "sig":
		key = "sig:" + ex.tag.get_slice("→ ", 1)
	seen[key] = seen.get(key, 0) + 1
	var where: String = "%s tag %s" % [what, ex.tag]
	if c.tag != ex.tag:
		diffs.append("%s: tag code '%s' data '%s'" % [where, c.tag, ex.tag])
	if chk.rng != rngAfter:
		diffs.append("%s: RNG state after planning differs" % where)
	if c.beats.size() != ex.beats.size():
		diffs.append("%s: %d beats by code, %d by data" % [where, c.beats.size(), ex.beats.size()])
		return
	for i in range(c.beats.size()):
		var a = c.beats[i]
		var b = ex.beats[i]
		if a.op != b.op or SimMathx.bits(a.t) != SimMathx.bits(b.t) or not _same(a.args, b.args):
			diffs.append("%s: beat %d code %s t=%s %s, data %s t=%s %s" % [where, i, a.op, SimMathx.bits(a.t), str(a.args), b.op, SimMathx.bits(b.t), str(b.args)])
			return


## Deep equality with exact float bits and matching key sets (null where the code passes null).
func _same(x, y) -> bool:
	if typeof(x) != typeof(y):
		return false
	if x is Dictionary:
		if x.size() != y.size():
			return false
		# Keys must match in type too: a StringName key hashes differently from a String key.
		var yk: Array = y.keys()
		for k in x:
			var found: bool = false
			for k2 in yk:
				if typeof(k2) == typeof(k) and k2 == k:
					found = true
			if not found or not _same(x[k], y[k]):
				return false
		return true
	if x is float:
		return SimMathx.bits(x) == SimMathx.bits(y)
	return x == y
