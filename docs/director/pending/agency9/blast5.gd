extends SceneTree
# Read-only checks of agency slice 9 (the wild deflect, the context deflect, the free approach, the spray, mines) with two
# scripted humans. P1 gets to a distance; the scripts run from that tick.
# Steps [tick, what]. P1: "eL" a bolt, "eLs n e" bolts every e ticks for n ticks, "eH n" an energy heavy held n ticks,
# "mine" (energy + context). P2: "pb" a guard press as the next shot is 6 ticks away, "ctx" guard held and a context
# press at that tick, "guard n", "L", "toward n" (fly at P1), "wait".
func _init() -> void:
	for c in [
			["a bolt; P2 perfect-blocks it, then presses light and comes in while P1 keeps firing", 10.0, [[0, "eL"], [22, "eLs 80 12"]], [[0, "pb"], [44, "L"]], 200],
			["a full charged shot; P2 holds guard and presses context", 20.0, [[0, "eH 40"]], [[30, "guard 60"], [45, "ctx"]], 160],
			["bolts every 6 ticks for 120 ticks; P2 does nothing", 20.0, [[0, "eLs 120 6"]], [], 200],
			["bolts every 12 ticks for 120 ticks; P2 does nothing", 20.0, [[0, "eLs 120 12"]], [], 200],
			["P1 lays a mine and backs off; P2 flies at him", 12.0, [[0, "mine"], [5, "back 60"]], [[40, "toward 200"]], 320],
			["P1 lays a mine; P2 holds guard and flies at him", 12.0, [[0, "mine"], [5, "back 60"]], [[40, "toward 200"], [40, "guard 260"]], 320],
			["P1 lays two mines 1 bh apart (the second is refused), then seven in a row moving back", 14.0, [[0, "mine"], [10, "mine"], [12, "back 400"], [40, "mines 300 40"]], [], 420]]:
		print(JSON.stringify(_case(String(c[0]), float(c[1]), c[2], c[3], int(c[4]))))
	quit()


func _case(name: String, bh: float, s1: Array, s2: Array, run: int) -> Dictionary:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 7, {"p1": false, "p2": false}, {"v2": [true, true]})
	var a = S.fighters[0]; var b = S.fighters[1]
	var t0 := -1; var t := 0; var k := 0
	var log: Array = []; var res := {"case": name}; var dmg := 0.0; var x0 := 0.0; var pbDone := false
	var outs := {}; var fired := 0; var wide := 0; var mines := 0
	while t < 5000 and (t0 < 0 or k < run):
		var ia := SimIntent.new(); var ib := SimIntent.new()
		var dx: float = SimWrap.sdx(a.x, b.x)
		var d: float = SimDetMath.hypot(dx, b.y - a.y)
		if t0 < 0:
			if S.dirS.ex == null and S.dirS.cool <= 0.0 and absf(d - bh * 75.0) < 40.0 and t > 20:
				t0 = t
				a.ki = 100.0; b.ki = 100.0
				x0 = b.x
			else:
				ia.mx = signf(dx) * (1.0 if d > bh * 75.0 else -1.0)
		if t0 >= 0:
			ia.mode = 0
			for st in s1:
				var w: String = String(st[1]); var at: int = int(st[0]); var p: PackedStringArray = w.split(" ")
				if w == "eL" and k == at:
					ia.light = true; ia.mode = 1
				elif p[0] == "eLs" and k >= at and k < at + int(p[1]):
					ia.mode = 1
					ia.light = (k - at) % int(p[2]) == 0
				elif p[0] == "eH" and k >= at and k < at + int(p[1]):
					ia.mode = 1; ia.heavy = k == at; ia.heavyHeld = true
				elif w == "mine" and k == at:
					ia.mode = 1; ia.context = true
				elif p[0] == "mines" and k >= at and k < at + int(p[1]):
					ia.mode = 1
					ia.context = (k - at) % int(p[2]) == 0
				elif p[0] == "back" and k >= at and k < at + int(p[1]):
					ia.mx = -signf(dx)
			var near: int = 9999
			for sh in S.shots:
				if not sh.dead and sh.owner == 0 and sh.mode == SimShots.SEEK: near = mini(near, sh.left)
			for st in s2:
				var w2: String = String(st[1]); var at2: int = int(st[0]); var p2: PackedStringArray = w2.split(" ")
				if w2 == "pb" and not pbDone and near <= 6:
					ib.guard = true; ib.guardPress = true; pbDone = true
				elif w2 == "ctx" and k == at2:
					ib.context = true
				elif p2[0] == "guard" and k >= at2 and k < at2 + int(p2[1]):
					ib.guard = true; ib.guardPress = k == at2
				elif w2 == "L" and k == at2:
					ib.light = true
				elif p2[0] == "toward" and k >= at2 and k < at2 + int(p2[1]):
					ib.mx = -signf(dx)
		var live: bool = SimCore.step(S, [ia, ib])
		if t0 >= 0:
			for fl in S.out.feed:
				var tg: String = str(fl.tag)
				if tg == "PRESSES": continue
				if tg.ends_with("BOLT"):
					fired += 1
					if str(fl.sub).begins_with("sprayed"): wide += 1
					continue
				log.append(str(k) + ": " + tg + " | " + str(fl.sub).substr(0, 90))
			for e in S.out.fx:
				if e.type == "damage" and e.amount > 0.0 and int(e.attacker) >= 0:
					if int(e.victim) == 1: dmg += e.amount
				elif e.type == "shot_hit":
					var key: String = S.fighters[int(e.victim)].name + " " + str(e.outcome)
					outs[key] = outs.get(key, 0) + 1
				elif e.type == "shot_deflect":
					log.append(str(k) + ": shot_deflect, bound " + str(int(absf(SimWrap.sdx(float(e.x), float(e.x1))) / 75.0)) + " bh away, " + str(snappedf(float(e.dur), 0.01)) + " s")
				elif e.type == "mine_trip":
					log.append(str(k) + ": mine_trip " + str(e.kind))
				elif e.type == "shot_end" and (str(e.get("cause")) == "mine" or str(e.get("cause")) == "life"):
					log.append(str(k) + ": shot_end " + str(e.get("cause")))
				elif e.type == "decisive" or e.type == "knockback":
					log.append(str(k) + ": " + str(e.type) + " " + str(e.kind))
				elif e.type == "cue" and (str(e.kind).begins_with("mine") or str(e.kind).begins_with("context")):
					log.append(str(k) + ": cue " + str(e.kind))
					if str(e.kind) == "mine_lay": mines += 1
			if live:
				k += 1
		S.out.fx.clear(); S.out.feed.clear()
		t += 1
	var liveMines := 0
	for sh in S.shots:
		if sh.mode == SimShots.MINE and not sh.dead: liveMines += 1
	res["log"] = log.slice(0, 40)
	res["bolts fired"] = fired
	res["sprayed wide"] = wide
	res["shots that met a fighter"] = outs
	res["mines laid"] = mines
	res["mines live at the end"] = liveMines
	res["damage to P2"] = snappedf(dmg, 0.1)
	res["P2 moved, bh"] = snappedf(absf(SimWrap.sdx(x0, b.x)) / 75.0, 0.1)
	res["P1 ki"] = snappedf(a.ki, 0.1)
	res["P2 ki"] = snappedf(b.ki, 0.1)
	SimCore.dispose(S)
	return res
