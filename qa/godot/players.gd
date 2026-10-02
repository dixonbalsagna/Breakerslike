extends SceneTree
## Scripted players for the agency-pass balance tests (docs/qa/timing-edge-plan.md): a masher, a holder, a tapper with an
## adjustable timing accuracy, a mix, and the AI, played against each other on the live sim through the real input path (a v2
## human slot). Each scripted player keeps the press log the sim will keep (SimPressRead, Controls' classifier and thresholds
## from data/input/timing.json `read`) and reports what the classifier reads, how many of its presses were on the beat, and
## how its exchanges ended, so the same script measures today's sim (no timing rules: expect no edge) and the agency-pass sim.
##   godot --headless --path . --script res://qa/godot/players.gd -- <matches> <baseSeed> --a=<spec> --b=<spec> [--capsec=900]
## A spec is kind[:key=value...]:
##   ai[:level=easy|medium|hard]                     the AI (the director drives the slot)
##   masher[:gap=8][:kind=L|H][:forms=1]             a press every gap live ticks
##   holder[:kind=H|L][:hold=16][:rest=24][:forms=1] press and hold the button hold ticks, then rest
##   holder:timed=1[:acc=100][:win=6]               a hold released on a blow's flash: acc percent of releases land within win ticks of a blow's contact
##                                                   (Game Design: a hold released within 6 ticks of the flash)
##   tapper[:acc=100][:jit=1][:win=4][:mix=L][:idle=24][:forms=1]
##                                                   taps its own blows: acc percent of presses land within the beat window
##                                                   (win ticks, default beatHalf 4, of a blow's contact), the rest miss it by 3 to 10 ticks more;
##                                                   win=3 is the steady mash that lands on the beat (Game Design: within 3 ticks);
##                                                   jit adds a uniform jitter of +-jit ticks to every press; mix is a string of
##                                                   L and H pressed in turn; between exchanges it requests one every idle ticks
##   mix[:mix=LLH][:gap=12][:forms=1]                presses in a fixed pattern, off the beat (a rhythm of its own)
## Add :stick=1 to any scripted player: a heavy press (and a hold) is made with the stick up and toward the rival, the way Orb's earned
## launch is thrown (agency slice 1: a heavy pressed with a stick direction that lands clean launches); without it a heavy is a plain heavy.
## Player A takes slot 0 on odd seeds and slot 1 on even ones, so spawn side and slot cancel. Prints one JSON line.
## Read-only with respect to sim/: it only calls the sim's public functions.

class Pl:
	var kind: String = "ai"
	var P: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	var log: Array = []
	var carry: int = -1            # a press the sim did not consume (hit-stop): sent again on the next call
	var carry_hold: bool = false
	var plan: Array = []           # [{tick, k}] presses planned against the running exchange's blows
	var last_press: int = -1000
	var hold_until: int = -1
	var hold_kind: int = 0
	var pending_rel: int = -1      # a timed hold's release tick
	var rest_until: int = 0
	var pat_i: int = 0
	var contacts: Array = []       # contact ticks (live ticks) of the running exchange's blows, both sides
	var seen_ex = null
	var next_idle: int = 0
	var presses: int = 0
	var on_beat: int = 0
	var in_beat_window: int = 0    # presses made during an exchange (the denominator of the on-beat share)
	var styles: Dictionary = {}
	var half: int = 4
	var forms: bool = false
	var level: String = ""

	func setup(spec: String, seed_: int, slot: int) -> void:
		var parts: PackedStringArray = spec.split(":")
		kind = parts[0]
		P = {}
		for i in range(1, parts.size()):
			var kv: PackedStringArray = parts[i].split("=")
			if kv.size() == 2:
				P[kv[0]] = kv[1]
		rng.seed = seed_ * 7919 + slot * 104729 + 13
		forms = int(P.get("forms", "0")) != 0
		level = String(P.get("level", ""))
		half = int(SimPressRead.params()["beatHalf"])

	func scripted() -> bool:
		return kind != "ai"

	func _kind_at(pattern: String) -> int:
		var c: String = pattern.substr(pat_i % maxi(1, pattern.length()), 1)
		pat_i += 1
		return 1 if c == "H" else 0

	## Plan the presses for a new exchange: one per blow of this player's own side, on or off the beat.
	func _plan_exchange(S, slot: int, lt: int) -> void:
		plan.clear()
		contacts.clear()
		var ex = S.dirS.ex
		if ex == null:
			return
		var mine: String = "A" if ex.A == S.fighters[slot] else "D"
		var acc: float = float(P.get("acc", "100")) / 100.0
		var jit: int = int(P.get("jit", "1"))
		var win: int = int(P.get("win", str(half)))
		var pattern: String = String(P.get("mix", "L"))
		for b in ex.beats:
			if b.op != "strike" or b.args == null:
				continue
			var contact: int = lt + int(roundf((b.t - ex.t) * 60.0))
			contacts.append(contact)
			if String(b.args.a) != mine:
				continue
			var off: int
			if rng.randf() < acc:
				off = rng.randi_range(-win, win)
			else:
				off = (1 if rng.randf() < 0.5 else -1) * rng.randi_range(win + 3, win + 10)
			if jit > 0:
				off += rng.randi_range(-jit, jit)
			if kind == "holder":   # a timed hold: down hold ticks before the release, released at the flash
				var hold_t: int = int(P.get("hold", "16"))
				if contact + off - hold_t > lt:
					plan.append({"tick": contact + off - hold_t, "k": 1 if String(P.get("kind", "H")) == "H" else 0, "rel": contact + off})
			else:
				plan.append({"tick": maxi(lt + 1, contact + off), "k": _kind_at(pattern)})

	## The press to send this call: -1 none, 0 light, 1 heavy. `hold` is set when the button stays down.
	func decide(S, slot: int, lt: int) -> int:
		if carry >= 0:
			return carry
		match kind:
			"masher":
				var gap: int = int(P.get("gap", "8"))
				if lt - last_press >= gap:
					return 1 if String(P.get("kind", "L")) == "H" else 0
			"mix":
				var gap2: int = int(P.get("gap", "12"))
				if lt - last_press >= gap2:
					return _kind_at(String(P.get("mix", "LLH")))
			"holder":
				if int(P.get("timed", "0")) != 0:
					if S.dirS.ex != seen_ex:
						seen_ex = S.dirS.ex
						_plan_exchange(S, slot, lt)
					while not plan.is_empty() and int(plan[0]["tick"]) < lt - 1:
						plan.pop_front()
					if lt >= hold_until and not plan.is_empty() and int(plan[0]["tick"]) <= lt:
						var pk: Dictionary = plan.pop_front()
						hold_kind = int(pk["k"])
						pending_rel = int(pk["rel"])
						return hold_kind
					if S.dirS.ex == null and lt >= hold_until and lt >= next_idle:   # nothing to time against: request an exchange with an ordinary hold
						hold_kind = 1 if String(P.get("kind", "H")) == "H" else 0
						pending_rel = -1
						return hold_kind
				elif lt >= hold_until and lt >= rest_until:
					hold_kind = 1 if String(P.get("kind", "H")) == "H" else 0
					return hold_kind
			"tapper":
				if S.dirS.ex != seen_ex:
					seen_ex = S.dirS.ex
					_plan_exchange(S, slot, lt)
				if S.dirS.ex != null and not plan.is_empty():
					if int(plan[0]["tick"]) <= lt:
						var k: int = int(plan[0]["k"])
						plan.pop_front()
						return k
				elif lt >= next_idle and (S.dirS.ex == null or plan.is_empty()):
					if S.dirS.ex == null:
						return _kind_at(String(P.get("mix", "L")))
		return -1

	## The press went through at live tick lt (kind k): log it, read the beat, classify.
	func pressed(k: int, lt: int, held: bool) -> void:
		var beat: int = SimPressRead.beat_offset(lt, contacts)
		SimPressRead.push(log, k, 0, lt, beat)
		last_press = lt
		presses += 1
		if beat != SimPressRead.NO_BEAT:
			in_beat_window += 1
			if absi(beat) <= half:
				on_beat += 1
		var now_c: int = lt
		if kind == "holder":   # a hold reads as a hold once it has been down holdTicks: classify at the release
			now_c = lt + int(P.get("hold", "16"))
		var st: String = String(SimPressRead.classify(log, now_c, {"offset": 0})["style"])
		styles[st] = int(styles.get(st, 0)) + 1
		if kind == "tapper" or kind == "holder":
			next_idle = lt + int(P.get("idle", "24"))
		if kind == "holder":
			hold_until = pending_rel if (int(P.get("timed", "0")) != 0 and pending_rel > lt) else lt + int(P.get("hold", "16"))
			rest_until = hold_until + int(P.get("rest", "24"))
			SimPressRead.release(log, k, hold_until)

	func is_holding(lt: int) -> bool:
		return kind == "holder" and lt < hold_until


func _init() -> void:
	var pos: Array = []
	var spec_a: String = "masher"
	var spec_b: String = "ai:level=medium"
	var capsec: float = 900.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--a="):
			spec_a = a.substr(4)
		elif a.begins_with("--b="):
			spec_b = a.substr(4)
		elif a.begins_with("--capsec="):
			capsec = float(a.substr(9))
		else:
			pos.append(a)
	var n: int = int(pos[0]) if pos.size() > 0 else 20
	var base: int = int(pos[1]) if pos.size() > 1 else 1
	SimInputData.load_and_apply()
	var sums: Array = [_blank(), _blank()]
	var wins: Array = [0, 0]
	var timeouts: int = 0
	var lens: Array = []
	for i in range(n):
		var seed: int = base + i
		var slot_a: int = 0 if seed % 2 == 1 else 1
		var res: Dictionary = _match(seed, [spec_a, spec_b], [slot_a, 1 - slot_a], capsec, sums)
		lens.append(res.t)
		if res.winner < 0:
			timeouts += 1
		else:
			wins[res.winner] += 1
	lens.sort()
	var out: Dictionary = {"players": true, "a": spec_a, "b": spec_b, "n": n, "aWins": wins[0], "bWins": wins[1], "timeouts": timeouts, "medianSec": snappedf(lens[lens.size() >> 1], 0.1), "alternationShare": snappedf(float(sums[0].alternations) / maxf(1.0, float(sums[0].pairs)), 0.001), "stats": [_report(sums[0], n), _report(sums[1], n)]}
	print(JSON.stringify(out))
	quit(0)


func _blank() -> Dictionary:
	return {"presses": 0, "onBeat": 0, "inExchange": 0, "styles": {}, "exchanges": 0, "launchEnds": 0, "otherEnds": 0, "damage": 0.0, "hits": 0, "heavyHits": 0, "launchesEarned": 0, "launchesTaken": 0, "airCatches": 0, "alternations": 0, "pairs": 0, "flowMax": 0, "flowTo3": 0, "end_launch": 0, "end_knockback": 0, "end_continue": 0}


func _report(s: Dictionary, n: int) -> Dictionary:
	var ex: float = maxf(1.0, float(s.exchanges))
	return {"pressesPerMatch": snappedf(float(s.presses) / n, 0.1), "onBeatShare": snappedf(float(s.onBeat) / maxf(1.0, float(s.inExchange)), 0.001), "styles": s.styles, "exchangesPerMatch": snappedf(float(s.exchanges) / n, 0.1), "launchShareOfExchanges": snappedf(float(s.launchEnds) / ex, 0.001), "damagePerMatch": snappedf(float(s.damage) / n, 1.0), "damagePerExchange": snappedf(float(s.damage) / ex, 0.1), "hitsPerMatch": snappedf(float(s.hits) / n, 0.1), "heavyHitsPerMatch": snappedf(float(s.heavyHits) / n, 0.1), "launchesEarnedPerMatch": snappedf(float(s.launchesEarned) / n, 0.1), "launchesTakenPerMatch": snappedf(float(s.launchesTaken) / n, 0.1), "endsLaunch": s.end_launch, "endsKnockback": s.end_knockback, "endsContinue": s.end_continue, "flowMax": s.flowMax, "flowTo3PerMatch": snappedf(float(s.flowTo3) / n, 0.1)}


## One match: specs[i] plays slot slots[i]. Returns {winner: 0 or 1 (the spec's index), -1 for a timeout, t}.
func _match(seed: int, specs: Array, slots: Array, capsec: float, sums: Array) -> Dictionary:
	var pl: Array = []
	for i in range(2):
		var p := Pl.new()
		p.setup(specs[i], seed, slots[i])
		pl.append(p)
	var lvl: String = ""
	for p in pl:
		if p.kind == "ai" and p.level != "":
			lvl = p.level
	var dai = load("res://sim/director/ai.gd")   # loaded as a resource: a typed class reference would not parse on a sim before step 3
	dai.set("level", lvl)
	var by_slot: Array = [null, null]
	by_slot[slots[0]] = pl[0]
	by_slot[slots[1]] = pl[1]
	var S: SimState = SimCore.createSim()
	var ai: Dictionary = {"p1": not by_slot[0].scripted(), "p2": not by_slot[1].scripted()}
	SimCore.newMatch(S, seed, ai, {"v2": [by_slot[0].scripted(), by_slot[1].scripted()]})
	var lt: int = 0
	var ticks: int = 0
	var cur_ex = null
	var ex_launch: bool = false
	var ex_attacker: int = -1
	var last_att: int = -1
	while S.T < capsec and not (S.game.ko != null and S.game.koT > 3.0) and ticks < 400000:
		ticks += 1
		var ins: Array = [null, null]
		var sent: Array = [-1, -1]
		for slot in range(2):
			var p = by_slot[slot]
			if not p.scripted():
				continue
			var it := SimIntent.new()
			if p.forms and S.fighters[slot].act.formReady:
				it.transform = true
			var k: int = p.decide(S, slot, lt)
			if k >= 0:
				if k == 1:
					it.heavy = true
				else:
					it.light = true
			if int(p.P.get("stick", "0")) != 0 and (k == 1 or (p.is_holding(lt) and p.hold_kind == 1)):
				var rival = S.fighters[1 - slot]
				it.mx = 0.8 * SimMathx.jsign(SimWrap.sdx(S.fighters[slot].x, rival.x))
				it.my = 0.7
			if p.is_holding(lt):
				if p.hold_kind == 1 and "heavyHeld" in it:
					it.set("heavyHeld", true)
				elif "lightHeld" in it:
					it.set("lightHeld", true)
			ins[slot] = it
			sent[slot] = k
		var stepped: bool = SimCore.step(S, ins)
		if stepped:
			lt += 1
		for slot in range(2):
			var p = by_slot[slot]
			if not p.scripted():
				continue
			if sent[slot] >= 0:
				if stepped:
					p.carry = -1
					p.pressed(sent[slot], lt, p.kind == "holder")
				else:
					p.carry = sent[slot]
		# exchange endings and per-player counts, from this tick's events
		for e in S.out.fx:
			if e.type == "damage" and e.number and int(e.attacker) >= 0 and int(e.attacker) < 2 and e.amount > 0.0:
				var who = sums[_idx(pl, by_slot[int(e.attacker)])]
				who.damage += e.amount
				who.hits += 1
				if str(e.get("kind")) == "heavy":
					who.heavyHits += 1
			elif e.type == "exchange_end":   # slice 3: the director's ending of this player's exchange (the actor is the attacker)
				var xw = sums[_idx(pl, by_slot[int(e.actor)])]
				var xk: String = "end_" + str(e.get("kind"))
				xw[xk] = int(xw.get(xk, 0)) + 1
			elif e.type == "flow":   # slice 3: the flow count; nothing but the HUD and QA reads it
				var fwho = sums[_idx(pl, by_slot[int(e.actor)])]
				fwho.flowMax = maxi(int(fwho.flowMax), int(e.n))
				if int(e.n) == 3:
					fwho.flowTo3 += 1
			elif e.type == "launch":
				var victim: int = int(e.actor)
				var lau: int = int(e.target)
				ex_launch = true
				if lau >= 0 and lau < 2:
					sums[_idx(pl, by_slot[lau])].launchesEarned += 1
				sums[_idx(pl, by_slot[victim])].launchesTaken += 1
		S.out.fx.clear()
		S.out.feed.clear()
		if S.dirS.ex != cur_ex:
			if cur_ex != null and ex_attacker >= 0 and (str(cur_ex.kind) == "light" or str(cur_ex.kind) == "heavy"):
				var sm = sums[_idx(pl, by_slot[ex_attacker])]
				if ex_launch:
					sm.launchEnds += 1
				else:
					sm.otherEnds += 1
			cur_ex = S.dirS.ex
			ex_launch = false
			ex_attacker = S.fighters.find(cur_ex.A) if cur_ex != null else -1
			if cur_ex != null and (str(cur_ex.kind) == "light" or str(cur_ex.kind) == "heavy"):
				sums[_idx(pl, by_slot[ex_attacker])].exchanges += 1
				# turn-taking: does the attacker change from one melee exchange to the next (the trade of stomach punches)
				if last_att >= 0:
					sums[0].pairs += 1
					if last_att != ex_attacker:
						sums[0].alternations += 1
				last_att = ex_attacker
	var winner: int = -1
	if S.game.ko != null:
		var loser_slot: int = S.fighters.find(S.game.ko)
		winner = 1 - _idx(pl, by_slot[loser_slot])
	var t: float = S.T
	for i in range(2):
		sums[i].presses += pl[i].presses
		sums[i].onBeat += pl[i].on_beat
		sums[i].inExchange += pl[i].in_beat_window
		for st in pl[i].styles:
			sums[i].styles[st] = int(sums[i].styles.get(st, 0)) + int(pl[i].styles[st])
	SimCore.dispose(S)
	return {"winner": winner, "t": t}


## The index (0 or 1) of player object p in the pl array of the match, found through the sums' order: players are kept in spec order.
var _pl_ref: Array = []

func _idx(pl: Array, p) -> int:
	return 0 if pl[0] == p else 1
