extends SceneTree
# Read-only checks of agency slice 10 (the alchemist's A1 and A2) with two scripted humans in the close band. P1 presses
# a pattern; P2 does nothing. Prints the styles read, the pieces picked and Controls' read of P1's log.
# A pattern is a string of L and H pressed `every` ticks apart, repeated for `run` ticks; "toward" holds the stick at P2;
# "held" keeps each button down for 14 ticks (a hold).
func _init() -> void:
	for c in [
			["lights every 8 ticks", "L", 8, false, false, 200],
			["lights every 8 ticks, the stick toward", "L", 8, true, false, 200],
			["L L H every 16 ticks", "LLH", 16, false, false, 300],
			["heavies every 30 ticks", "H", 30, false, false, 300],
			["lights held 14 ticks, every 40", "L", 40, false, true, 240]]:
		print(JSON.stringify(_case(String(c[0]), String(c[1]), int(c[2]), bool(c[3]), bool(c[4]), int(c[5]))))
	quit()


func _case(name: String, pat: String, every: int, toward: bool, held: bool, run: int) -> Dictionary:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 7, {"p1": false, "p2": false}, {"v2": [true, true]})
	var a = S.fighters[0]; var b = S.fighters[1]
	var t0 := -1; var t := 0; var k := 0; var n := 0; var downAt := -100; var downKind := ""
	var styles := {}; var pieces := {}; var reads := {}; var log: Array = []; var dmg := 0.0; var noPiece := 0; var strikes := 0
	while t < 6000 and (t0 < 0 or k < run):
		var ia := SimIntent.new(); var ib := SimIntent.new()
		var dx: float = SimWrap.sdx(a.x, b.x)
		var d: float = SimDetMath.hypot(dx, b.y - a.y)
		if t0 < 0:
			if S.dirS.ex == null and S.dirS.cool <= 0.0 and d < 2.0 * 75.0 and t > 20:
				t0 = t
				a.ki = 100.0; b.ki = 100.0
			else:
				ia.mx = signf(dx)
		if t0 >= 0:
			ia.mode = 0
			if toward: ia.mx = signf(dx)
			elif d > 2.5 * 75.0: ia.mx = signf(dx)
			if k % every == 0:
				var ch: String = pat[n % pat.length()]
				n += 1
				if ch == "L": ia.light = true
				else: ia.heavy = true
				downAt = k; downKind = ch
			if held and k - downAt < 14:
				if downKind == "L": ia.lightHeld = true
				else: ia.heavyHeld = true
			elif k == downAt:
				if downKind == "L": ia.lightHeld = true
				else: ia.heavyHeld = true
		var live: bool = SimCore.step(S, [ia, ib])
		if t0 >= 0:
			for fl in S.out.feed:
				var tg: String = str(fl.tag)
				if tg == "PRESSES":
					var st: String = DirRecipe.style(S, a)
					styles[st] = styles.get(st, 0) + 1
					if log.size() < 6: log.append(str(k) + ": " + str(fl.sub).substr(0, 110))
				elif tg == "PIECES":
					for part in str(fl.sub).split("  (")[0].split(", "):
						if part.begins_with(a.name + " "):
							var id: String = part.substr(a.name.length() + 1)
							pieces[id] = pieces.get(id, 0) + 1
					if log.size() < 10: log.append(str(k) + ": PIECES " + str(fl.sub).substr(0, 110))
			for e in S.out.fx:
				if e.type == "damage" and e.amount > 0.0 and int(e.attacker) == 0:
					dmg += e.amount
			var ex = S.dirS.ex
			if ex != null:
				for bt in ex.beats:
					if not bt.done and bt.op == "strike" and bt.args != null and String(bt.args.get("a", "")) == "A" and not bt.args.has("counted"):
						bt.args["counted"] = true
						strikes += 1
						if not bt.args.has("piece"): noPiece += 1
			if live:
				if k % every == 1:
					var rd: Dictionary = DirAlchemy.read(S, a)
					var key: String = str(rd.style) + "/" + str(rd.timing) + ("/steady" if rd.steady else "")
					reads[key] = reads.get(key, 0) + 1
				k += 1
		S.out.fx.clear(); S.out.feed.clear()
		t += 1
	var res := {"case": name, "styles at exchange starts": styles, "reads after each press": reads, "P1's pieces": pieces, "P1 strikes planned": strikes, "without a piece": noPiece, "damage by P1": snappedf(dmg, 0.1), "flow at the end": a.act.flow, "log": log}
	SimCore.dispose(S)
	return res
