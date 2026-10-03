extends SceneTree
# Read-only checks of the beam plays (agency slice 8) with two scripted humans. P1 gets to a distance and fires his
# signature at tick 0; P2's script runs from that tick. The tell is 48 ticks, so the beam leaves at 48.
# Steps: [tick, what] with what in: "guard n" (held from that tick for n ticks; the first is a fresh press),
# "toward n", "away n" (the stick, held), "dodge", "sig", "eH" (an energy heavy).
# Args: the distance in bh (default 20), "swap" to make VORR the attacker.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var bh: float = float(args[0]) if args.size() > 0 else 20.0
	var swap: bool = args.size() > 1 and args[1] == "swap"
	for c in [
			["nothing", []],
			["guard held from 0", [[0, "guard 200"]]],
			["guard held from 0, the stick toward", [[0, "guard 200"], [0, "toward 200"]]],
			["a guard press at 40, the stick level", [[40, "guard 60"]]],
			["a guard press at 40, the stick away", [[40, "guard 60"], [40, "away 60"]]],
			["a guard press at 40, the stick toward", [[40, "guard 120"], [40, "toward 120"]]],
			["a guard press at 30 (too early), held", [[30, "guard 100"]]],
			["a dodge at 30 (too early)", [[30, "dodge"]]],
			["a dodge at 36 (inside the last 14)", [[36, "dodge"]]],
			["a dodge at 53 (inside the first 6 of the beam)", [[53, "dodge"]]],
			["a dodge at 58 (too late)", [[58, "dodge"]]],
			["his own signature at 20 (in the tell)", [[20, "sig"]]],
			["his own signature at 56 (late)", [[56, "sig"]]],
			["an energy heavy at 56 (late)", [[56, "eH"]]],
			["his own signature at 66 (late, 2 ticks before it reaches him)", [[66, "sig"]]]]:
		print(JSON.stringify(_case(String(c[0]), bh, c[1], swap)))
	quit()


func _apply(it: SimIntent, script: Array, k: int, toward: float) -> void:
	it.mode = 0
	for st in script:
		var w: String = String(st[1]); var at: int = int(st[0])
		if w == "dodge" and k == at: it.dodge = true
		elif w == "sig" and k == at: it.sig = true
		elif w == "eH" and k == at:
			it.heavy = true; it.mode = 1
		elif w.begins_with("guard") and k >= at and k < at + int(w.split(" ")[1]):
			it.guard = true
			it.guardPress = k == at
		elif w.begins_with("toward") and k >= at and k < at + int(w.split(" ")[1]): it.mx = toward
		elif w.begins_with("away") and k >= at and k < at + int(w.split(" ")[1]): it.mx = -toward


func _case(name: String, bh: float, s2: Array, swap: bool) -> Dictionary:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 7, {"p1": false, "p2": false}, {"v2": [true, true]})
	var ai: int = 1 if swap else 0
	var a = S.fighters[ai]; var b = S.fighters[1 - ai]
	var t0 := -1; var t := 0; var k := 0; var endK := -1
	var log: Array = []; var res := {"case": name}; var dmg := 0.0; var lost0 := 0; var beams := 0
	while t < 4000 and (t0 < 0 or k < 220):
		var ia := SimIntent.new(); var ib := SimIntent.new()
		var dx: float = SimWrap.sdx(a.x, b.x)
		var d: float = SimDetMath.hypot(dx, b.y - a.y)
		if t0 < 0:
			if S.dirS.ex == null and S.dirS.cool <= 0.0 and absf(d - bh * 75.0) < 40.0 and t > 20:
				t0 = t
				a.ki = 100.0; b.ki = 100.0; a.sigReadyT = 0.0; b.sigReadyT = 0.0
				for bd in S.buildings:
					if bd.hp <= 0.0: lost0 += 1
			else:
				ia.mx = signf(dx) * (1.0 if d > bh * 75.0 else -1.0)
		if t0 >= 0:
			if k == 0: ia.sig = true
			_apply(ib, s2, k, signf(SimWrap.sdx(b.x, a.x)))
		var st0: String = b.state
		var ins: Array = [ib, ia] if swap else [ia, ib]
		var live: bool = SimCore.step(S, ins)
		if t0 >= 0:
			if S.beams.size() != beams:
				beams = S.beams.size()
				log.append(str(k) + ": " + str(beams) + " beam(s)" + (" (the newest is " + S.beams[beams - 1].A.name + "'s)" if beams > 0 else ""))
			if b.state != st0:
				log.append(str(k) + ": " + b.name + " is " + b.state)
			for fl in S.out.feed:
				if str(fl.tag) != "PRESSES":
					log.append(str(k) + ": " + str(fl.tag) + " | " + str(fl.sub).substr(0, 90))
			for e in S.out.fx:
				if e.type == "damage" and e.amount > 0.0 and int(e.attacker) >= 0:
					if int(e.victim) == 1 - ai: dmg += e.amount
					log.append(str(k) + ": damage " + str(snappedf(e.amount, 0.1)) + " " + str(e.kind) + " to " + S.fighters[int(e.victim)].name)
				elif e.type == "beam_outcome":
					log.append(str(k) + ": beam_outcome " + str(e.kind))
				elif e.type == "cue" and (str(e.kind).begins_with("beam") or str(e.kind) == "perfect_block"):
					log.append(str(k) + ": cue " + str(e.kind) + " (" + S.fighters[int(e.actor)].name + ")")
				elif e.type == "launch" or e.type == "exchange_end" or e.type == "decisive":
					log.append(str(k) + ": " + str(e.type) + (" " + str(e.kind) if e.type != "launch" else ""))
					if e.type == "exchange_end":
						endK = k
						res["at the end"] = {"bh apart": snappedf(SimDetMath.hypot(SimWrap.sdx(a.x, b.x), b.y - a.y) / 75.0, 0.1), "attacker's stun ticks": a.stunTicks, "defender's ki": snappedf(b.ki, 0.1)}
			if live:
				k += 1
			if endK >= 0 and k > endK + 60:
				break
		S.out.fx.clear(); S.out.feed.clear()
		t += 1
	var lost := 0
	for bd in S.buildings:
		if bd.hp <= 0.0: lost += 1
	res["log"] = log
	res["damage to the defender"] = snappedf(dmg, 0.1)
	res["buildings levelled"] = lost - lost0
	SimCore.dispose(S)
	return res
