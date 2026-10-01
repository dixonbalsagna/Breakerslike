extends SceneTree
## QA record producer for the GDScript sim (ADR 0006). Plays seeded AI-vs-AI matches and writes one plain record per match
## to a JSON file: outcome, collateral, tiers, time by biome, tempo (exchange lengths and gaps), director events read from the
## feed, every fx event type counted, and the wounds/hazard events kept in order. qa/godot/bands.js turns the records into
## band checks. Read-only with respect to sim/: it only calls the sim's public functions.
##   godot --headless --path . --script res://qa/godot/records.gd -- <matches> <baseSeed> --arm=default --out=<abs path> [--capsec=900] [--cap=<tick safety>]
## Match i uses seed baseSeed+i. Arms are the sim's own (SimGolden.applyArm): default, swap, mirror-villain, mirror-hero, each with -flip.

const STANCES: Array = ["AGGRESSIVE", "DEFENSIVE", "EVASIVE", "ESCAPE"]
## fx event types that carry game meaning rather than decoration: kept in order with their fields (wounds-plan.md, living destruction).
const KEEP_PREFIXES: Array = ["region_", "brink_", "finisher_", "rally", "ko", "hazard", "fire_", "landslide", "quake", "rift", "lava", "cloud", "front_", "wound", "tier_up", "hide_start", "found", "blitz", "volley", "decisive", "searching", "lock_lost", "launch_plan", "struggle_press", "limb_break", "mood_band", "act_change", "style_label", "building_hit"]
## fighter indices are meaningful at 0
const INDEX_FIELDS: Array = ["actor", "target", "winner", "loser", "owner"]
const KEEP_FIELDS: Array = ["kind", "chosen", "tick", "tier", "cover", "actor", "target", "region", "stage", "chance", "survived", "winner", "loser", "amount", "n", "cause", "owner", "kind", "front", "text", "x"]

var re_atk := RegEx.create_from_string("^([A-Z][A-Z0-9-]*) (LIGHT|HEAVY|SIG) vs (\\w+)$")
var re_beam := RegEx.create_from_string("^(.+) over (\\w+) \\((.+?)\\)(?: → (\\w+))?")   # since step 2b the tag has no outcome: it arrives as a beam_outcome event
var re_launch := RegEx.create_from_string("^LAUNCH: (.+)$")
var re_parry := RegEx.create_from_string("^([A-Z][A-Z0-9-]*) PARRIES$")
var re_chain := RegEx.create_from_string("^CHAIN x(\\d+) ended$")


func _init() -> void:
	var pos: Array = []
	var arm: String = "default"
	var out: String = ""
	var cap: int = 200000        # tick safety only; the match cap is in sim seconds (hit-stop ticks do not advance S.T)
	var capsec: float = 900.0     # the S4 ruling: 15:00 of sim time
	var level: String = ""        # the AI level for the run (DirAI.level): easy, medium or hard; "" follows data/director/ai.json
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arm="):
			arm = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--capsec="):
			capsec = float(a.substr(9))
		elif a.begins_with("--level="):
			level = a.substr(8)
		elif a.begins_with("--cap="):
			cap = int(a.substr(6))
		else:
			pos.append(a)
	var n: int = int(pos[0]) if pos.size() > 0 else 10
	var base: int = int(pos[1]) if pos.size() > 1 else 1
	if out == "" or not (arm.trim_suffix("-flip") in ["default", "swap", "mirror-villain", "mirror-hero"]):
		print("usage: godot --headless --path . --script res://qa/godot/records.gd -- <matches> <baseSeed> --arm=<arm> --out=<file> [--capsec=<sim seconds>] [--cap=<ticks>]")
		quit(2)
		return
	if level != "":
		var dai = load("res://sim/director/ai.gd")   # loaded as a resource: a typed class reference would not parse on a sim before step 3 (no level)
		dai.set("level", level)
	var recs: Array = []
	for i in range(n):
		recs.append(run_match(base + i, arm, cap, capsec))
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(recs))
	f.close()
	quit(0)


func run_match(seed: int, arm: String, cap: int, capsec: float) -> Dictionary:
	var S := SimCore.createSim()
	SimCore.newMatch(S, seed)
	SimGolden.applyArm(arm, S.fighters)
	var fs: Array = S.fighters
	var slot := {}
	for i in range(fs.size()):
		slot[fs[i].name] = i
	var rec := {"seed": seed, "arm": arm, "names": [fs[0].name, fs[1].name], "attacks": {"light": 0, "heavy": 0, "sig": 0}, "ambush": 0,
		"launches": {}, "melee": {}, "beams": [], "parries": [0, 0], "chains": [], "hides": [0, 0], "found": 0, "seam": 0, "maxMove": 0.0,
		"bad": "", "koAt": -1.0, "winner": -1, "maxTier": [1, 1], "lowSec": 0.0, "lowCas": 0.0, "casByTier": [0.0, 0.0, 0.0, 0.0, 0.0],
		"fightSec": {}, "dmgVictim": [0.0, 0.0], "batteredIn": 0.0, "breathWear": 0.0, "casTimeline": [], "slides": [], "landings": {"brunt": 0, "water": 0, "slide": 0, "slam": 0, "bounce": 0, "stop": 0, "wall": 0, "caught": 0, "other": 0}, "landingsAll": {"brunt": 0, "water": 0, "slide": 0, "slam": 0, "bounce": 0, "stop": 0, "wall": 0, "caught": 0, "other": 0}, "cues": {}, "firstContact": {}, "liftsSeen": {}, "reach": {"n": 0, "far": 0, "maxD": 0.0, "tall": 0, "tallFlat": 0, "maxDy": 0.0}, "heavyLanded": [0, 0], "heavyClashWins": [0, 0], "slideShort": 0, "slideShortPl": 0, "lips": 0, "journeys": {"jn": 0, "tumbledEnd": 0, "jbounced": 0, "jbounces": 0, "n": 0, "capped": 0, "long": 0, "anyBounce": 0, "bounced": 0, "bounces": 0, "tumbled": 0, "lips": 0}, "impactCraters": 0, "skims": 0, "longHaul": 1500.0 * SimConst.TRAV_LAUNCH, "dmgByRegion": {}, "underSec": 0.0, "tierT": [0.0, -1.0, -1.0, -1.0, -1.0], "flights": [], "hiddenSec": [0.0, 0.0], "exLens": [], "exGaps": [], "fxCounts": {}, "events": [], "fronts": 0}
	var prev_x: Array = [fs[0].x, fs[1].x]
	var was_launched: Array = [false, false]
	var ended: Array = [false, false]   # a flight ended this tick: its open launch takes the class of the contact if no event named one
	var new_fl: Array = []   # launch events of this tick
	var lift: Array = [null, null]   # the open flight off terrain of each fighter: {tick, cause}; counted as seen once it has been in the air 10 ticks (balance-targets 20, second landing ruling)
	var last_fl: Array = [null, null]   # the latest launch of each fighter, for the bounce, lip and tumble counts of its journey
	var open_fl: Array = []   # launches whose first contact has not been seen: {"v": victim index, "cls": ""}; balance-targets 18 (one landing class per launch)
	var launch_x: Array = [0.0, 0.0]
	var prev_t: float = 0.0
	var prev_cas: float = 0.0
	var prev_wear: Array = [[0, 0, 0, 0], [0, 0, 0, 0]]
	var last_sec: int = 0
	var prev_ex = null
	var ex_start: float = 0.0
	var last_release: float = -1.0
	var ticks: int = 0
	while ticks < cap and (S.T < capsec or S.game.ko != null) and not (S.game.ko != null and S.game.koT > 3.0):
		SimCore.step(S)
		ticks += 1
		var dT: float = S.T - prev_t
		prev_t = S.T
		if S.game.ko != null and rec.koAt < 0.0:
			rec.koAt = S.T
			rec.winner = 1 - fs.find(S.game.ko)
		var top: int = 1
		for i in range(2):
			var f = fs[i]
			if not (is_finite(f.x) and is_finite(f.y) and is_finite(f.hp) and is_finite(f.ki)):
				rec.bad = "NaN in %s at %.2f s" % [f.name, S.T]
			if f.x < 0.0 or f.x >= SimConst.W:
				rec.bad = "%s x %f outside [0, W)" % [f.name, f.x]
			if absf(f.x - prev_x[i]) > SimConst.HALF:
				rec.seam += 1
			rec.maxMove = maxf(rec.maxMove, absf(SimWrap.sdx(prev_x[i], f.x)))
			prev_x[i] = f.x
			rec.maxTier[i] = maxi(rec.maxTier[i], int(f.tier))
			top = maxi(top, int(f.tier))
			if S.game.ko == null:
				var b: String = WorldBiomes.biomeAt(f.x)
				rec.fightSec[b] = rec.fightSec.get(b, 0.0) + dT
				if f.hidden:
					rec.hiddenSec[i] += dT
				if f.y < 0.0 and b == "ocean":
					rec.underSec += dT
			# launch flights: horizontal travel and whether the landing is in another biome
			var now_launched: bool = f.state == "launched"
			if now_launched and not was_launched[i]:
				launch_x[i] = f.x
			elif was_launched[i] and not now_launched:
				ended[i] = true
				rec.flights.append({"travel": snappedf(absf(SimWrap.sdx(launch_x[i], f.x)), 0.1), "newBiome": WorldBiomes.biomeAt(launch_x[i]) != WorldBiomes.biomeAt(f.x)})
			# first contact by kind (docs/director/landing-mix.md): a launched fighter whose slide has begun took a slide at his first ground contact, however short it runs and even if it ends against a rise (the stop dent digs a crater before the `slide` event, which is why the event order cannot name the class)
			if now_launched and f.slide > 0.0:
				_land(open_fl, i, "slide")
			was_launched[i] = now_launched
		for tt in range(2, 5):
			if top >= tt and rec.tierT[tt] < 0.0:
				rec.tierT[tt] = S.T
		# casualties by the higher of the two tiers; "low" is both fighters at tier 2 or below
		var dcas: float = S.world.casualties - prev_cas
		prev_cas = S.world.casualties
		if dcas != 0.0 or top <= 2:
			rec.casByTier[clampi(top, 1, 4)] += dcas
		# wear taken inside the battered band (60 to 90): the denominator of the second-breath band (balance-targets 8)
		var wear0 = fs[0].get("wear")
		if wear0 != null:
			for i in range(2):
				for ri in range(4):
					var w: int = fs[i].wear[ri]
					if w > prev_wear[i][ri]:
						var band: int = mini(w, SimWounds.STAGE_AT[2]) - maxi(prev_wear[i][ri], SimWounds.STAGE_AT[1])
						if band > 0:
							rec.batteredIn += float(band) / SimWounds.WEAR_SCALE
					prev_wear[i][ri] = w
		# casualty timeline for the rolling-budget and ceiling tests (balance-targets 4b): [second, share of the starting population lost, higher tier]
		if int(S.T) > last_sec:
			last_sec = int(S.T)
			rec.casTimeline.append([last_sec, snappedf(S.world.casualties / S.world.pop0, 0.0001), top])
		if top <= 2 and S.game.ko == null:
			rec.lowSec += dT
			rec.lowCas += dcas
		# exchange tempo: length of each exchange (request to release) and the gap before the next request
		if S.dirS.ex != prev_ex:
			if prev_ex != null:
				rec.exLens.append(snappedf(S.T - ex_start, 0.001))
				last_release = S.T
			if S.dirS.ex != null:
				ex_start = S.T
				if last_release >= 0.0:
					rec.exGaps.append(snappedf(S.T - last_release, 0.001))
			prev_ex = S.dirS.ex
		for e in S.out.fx:
			rec.fxCounts[e.type] = rec.fxCounts.get(e.type, 0) + 1
			# structured twins of feed lines (QA-004): hides, finds and tier-ups come from events, not text
			if e.type == "hide_start":
				rec.hides[int(e.actor)] += 1
			elif e.type == "found":
				rec.found += 1
			elif e.type == "tier_up":
				rec.maxTier[int(e.actor)] = maxi(rec.maxTier[int(e.actor)], int(e.tier))
			# one landing class per launch, by first contact (balance-targets 18): brunt (a building first), water (a skim or splash, or an impact in the sea), slide (a first ground contact carrying on for 2 bh = 150 units or more), else slam
			if e.type == "launch":
				var v0: int = int(e.actor)
				for fl in open_fl:
					if fl.v == v0 and fl.cls == "":
						fl.cls = "other"   # launched again before any contact
				var nf := {"v": v0, "cls": "", "pl": false, "bn": 0, "lip": 0, "tum": false, "kc": "", "endk": "", "n": (int(e.n) if e.get("n") != null else -1), "je": null, "x0": 0.0, "hx0": false}
				open_fl.append(nf)
				last_fl[v0] = nf
				new_fl.append(nf)
			# World's ground-contact events (docs/world/ground-contact.md section 4; G3 to G5): bounce {actor, n, surface}, land {actor, kind: skid | tumble | slam | stop, surface}, left_ground {actor, cause: lip | crest | heap | cliff | ridge | bounce}, tumble_end {actor, how: stop | recover | air}
			# The first contact's kind decides the class (a skid or tumble is a slide, a crater a slam, a bounce a bounce); a water skim also emits `bounce` with surface water, which is the water class and not a bounce.
			elif e.type == "bounce":
				var bv: int = int(e.actor)
				_contact(rec, lift, last_fl, bv, e)
				if str(e.get("surface")) == "water":
					_land(open_fl, bv, "water")
				else:
					_kind(open_fl, bv, "bounce")
					if last_fl[bv] != null:
						last_fl[bv].bn += 1
			elif e.type == "land":
				var lk: String = str(e.get("kind"))
				_contact(rec, lift, last_fl, int(e.actor), e)
				if str(e.get("surface")) == "water":
					_land(open_fl, int(e.actor), "water")
				else:
					_kind(open_fl, int(e.actor), "slam" if lk == "slam" else ("stop" if lk == "stop" else "slide"))
					if last_fl[int(e.actor)] != null:
						last_fl[int(e.actor)].endk = "slam" if lk == "slam" else ("stop" if lk == "stop" else "slide")   # the journey is classed by how it ends (balance-targets 20, the landing ruling after World's build)
			elif e.type == "left_ground":
				if str(e.get("cause")) != "bounce":
					rec.lips += 1
					lift[int(e.actor)] = {"tick": int(e.tick), "cause": str(e.get("cause"))}
					if last_fl[int(e.actor)] != null:
						last_fl[int(e.actor)].lip += 1
			elif e.type == "journey_end":   # World's closing event, once per journey: end (stop, tumble, slam, wall, water, recover, capped), contacts, lips, bounces, t; n is the launch number
				var jv: int = int(e.actor)
				for fl in open_fl:
					if fl.v == jv and fl.je == null and (fl.n < 0 or int(e.n) < 0 or fl.n == int(e.n)):
						var jend: String = str(e.get("end")) if e.get("end") != null else str(e.get("kind"))
						fl.je = {"end": jend, "bounces": int(_f(e, "bounces", "nb")), "len": (absf(SimWrap.sdx(fl.x0, e.x)) if fl.hx0 else 0.0), "t": _f(e, "t", "dur")}
						break
				lift[jv] = null
			elif e.type == "tumble_end":
				if str(e.get("how")) != "air" and last_fl[int(e.actor)] != null:
					last_fl[int(e.actor)].tum = true   # the journey ended from a tumble (it stopped or he recovered early)
			elif e.type == "beam_outcome":   # step 2b (ADR 0008): the signature's outcome, decided at its fire beat; the oldest unresolved beam of this actor takes it
				for bm in rec.beams:
					if bm.out == "" and (bm.who == int(e.actor) or bm.who < 0):
						bm.out = str(e.get("kind"))
						break
			elif e.type == "building_hit":
				_land(open_fl, int(e.actor), "brunt")
			elif e.type == "skim" or e.type == "splash":
				_land(open_fl, _nearest_open(S, open_fl, e.x), "water")
			elif e.type == "crater" and e.cause == "impact":
				_land(open_fl, 1 - int(e.owner), "water" if WorldTerrain.seaAt(S, e.x) else "slam")
			elif e.type == "slide":
				var long_slide: bool = absf(e.get("x1") - e.x) >= 150.0
				_land(open_fl, 1 - int(e.owner), "slide" if long_slide else "slideShort")   # a short slide is counted as a slam (balance-targets 18); the tally keeps its count
			# knockback slides and slams (docs/world/knockback-slide.md): a slide ends in one `slide` event, a slam digs an impact crater
			if e.type == "slide":
				rec.slides.append({"len": snappedf(absf(e.get("x1") - e.x), 1.0), "w": snappedf(e.w, 0.1), "depth": snappedf(e.depth, 0.1), "energy": snappedf(e.energy, 0.1), "variant": e.variant, "owner": e.owner, "t": snappedf(S.T, 0.001)})
			elif e.type == "crater" and e.cause == "impact":
				rec.impactCraters += 1
			elif e.type == "skim":
				rec.skims += 1
			if e.type == "cue":   # the director's cues by kind: perfect_block, dodge_cancel, burst (step 3)
				var cq: String = str(e.get("kind"))
				rec.cues[cq] = rec.cues.get(cq, 0) + 1
			# reach (Encounter's contact slice): every damaging strike of a light or heavy melee exchange (a light, a heavy or a guarded hit; signatures and their guarded hits are beams, not strikes) is measured from the attacker to the victim at the damage event: the horizontal distance must stay within 68 units, and a height difference beyond 68 is allowed only on sloped ground
			var rex = S.dirS.ex
			if e.type == "damage" and e.number and e.amount > 0.0 and rex != null and (str(rex.kind) == "light" or str(rex.kind) == "heavy") and (str(e.get("kind")) == "light" or str(e.get("kind")) == "heavy" or str(e.get("kind")) == "guard") and int(e.attacker) >= 0 and int(e.attacker) < 2 and int(e.victim) >= 0 and int(e.victim) < 2:
				var fa = fs[int(e.attacker)]
				var fv = fs[int(e.victim)]
				var rdx: float = absf(SimWrap.sdx(fa.x, fv.x))
				var rdy: float = absf(fa.y - fv.y)
				rec.reach.n += 1
				rec.reach.maxD = maxf(rec.reach.maxD, rdx)
				rec.reach.maxDy = maxf(rec.reach.maxDy, rdy)
				if rdx > 68.0:
					rec.reach.far += 1
				if rdy > 68.0:
					rec.reach.tall += 1
					var gx: float = fv.x
					var slope: float = absf(WorldTerrain.groundY(S, gx + 40.0) - WorldTerrain.groundY(S, gx - 40.0)) / 80.0
					if slope <= 0.15:
						rec.reach.tallFlat += 1
			# Game Design's pitch measures: heavies that landed (a heavy blow dealing damage; a guarded one is kind guard and does not count) and heavy clashes won (a decisive exchange of kind clash), by the fighter who dealt or won it
			if e.type == "damage" and str(e.get("kind")) == "heavy" and e.number and e.amount > 0.0 and int(e.attacker) >= 0 and int(e.attacker) < 2:
				rec.heavyLanded[int(e.attacker)] += 1
			elif e.type == "decisive" and str(e.get("kind")) == "clash" and int(e.winner) >= 0 and int(e.winner) < 2:
				rec.heavyClashWins[int(e.winner)] += 1
			if e.type == "damage" and e.region != "":
				rec.dmgByRegion[e.region] = rec.dmgByRegion.get(e.region, 0.0) + e.amount
				if int(e.victim) >= 0 and int(e.victim) < 2:
					rec.dmgVictim[int(e.victim)] += e.amount   # damage taken by each fighter: the rate k scales (blows, volleys, clash chip, impacts that hit a region)
			if _keep(e.type):
				var d := {"type": e.type, "t": snappedf(S.T, 0.001)}
				for k in KEEP_FIELDS:
					var v = e.get(k)
					if v != null and not (v is String and v == "") and not (v is float and v == 0.0 and not (k in INDEX_FIELDS)):
						d[k] = v
				rec.events.append(d)
		for i in range(2):
			if ended[i]:
				ended[i] = false
				var fe = fs[i]
				for fl in open_fl:
					if fl.v == i and fl.cls == "":
						# the flight ended with no named contact: a hit too weak to slam or slide (350 units a second or less) is a stop, in the sea water; a flight that ends in the air was caught by the follow-up
						if fe.y <= 0.0 and WorldTerrain.seaAt(S, fe.x):
							_land(open_fl, i, "water")
						elif fe.y <= WorldTerrain.groundY(S, fe.x) + 5.0:
							_land(open_fl, i, "stop")   # a weak landing (350 or slower): no slam, no slide
						else:
							_land(open_fl, i, "caught")   # still in the air when the flight ended: the follow-up caught him (balance-targets 19)
		var fr = S.get("frontsInFrame")   # hazard fronts inside the camera framing, once living destruction lands; null before
		if fr != null:
			rec.fronts = maxi(rec.fronts, int(fr))
		S.out.fx.clear()
		var pl_before: int = 0
		for n_ in rec.launches.values():
			pl_before += int(n_)
		for l in S.out.feed:
			parse(rec, l.tag, l.sub, slot)
		var pl_after: int = 0
		for n_ in rec.launches.values():
			pl_after += int(n_)
		if pl_after > pl_before and not new_fl.is_empty():
			new_fl[new_fl.size() - 1].pl = true   # the planner launch: its LAUNCH line is in the same tick as its launch event (the last one if a scripted launch follows in the tick)
		new_fl.clear()
		S.out.feed.clear()
		if rec.bad != "":
			break
	rec.ticks = ticks
	rec.timeout = S.game.ko == null
	if rec.koAt < 0.0:
		rec.koAt = S.T
	rec.civPct = S.world.casualties / S.world.pop0 * 100.0
	rec.pop0 = S.world.pop0
	rec.structs = S.world.structuresLost
	rec.nStructs = S.buildings.size()
	var rows := {}
	for b in S.buildings:
		var row = b.get("row")
		var key: String = "1" if row == null else str(int(row))
		var r: Dictionary = rows.get(key, {"n": 0, "lost": 0})
		r.n += 1
		if not b.alive:
			r.lost += 1
		rows[key] = r
	rec.rows = rows
	rec.craters = S.world.craters
	if fs[0].get("breathWear") != null:
		rec.breathWear = float(fs[0].breathWear + fs[1].breathWear) / SimWounds.WEAR_SCALE   # S4: wear recovered by second breath
	rec.wear = [fs[0].get("wear"), fs[1].get("wear")]   # [head, core, arms, legs] in WEAR_SCALE units at the end (Wounds S1); null before
	rec.stage = [fs[0].get("stage"), fs[1].get("stage")]
	rec.menace = [fs[0].menace, fs[1].menace]
	rec.anguish = [fs[0].anguish, fs[1].anguish]
	for fl in open_fl:
		var c: String = "other" if fl.cls == "" else String(fl.cls)   # a launch that never made contact (KO or the cap first) is "other"
		if fl.kc != "" and (fl.cls == "" or fl.cls == "slide" or fl.cls == "slam" or fl.cls == "slideShort"):
			c = String(fl.kc)   # World's events name the first contact: the kind rule replaces the 2 bh distance test
			if fl.pl:
				rec.firstContact[c] = rec.firstContact.get(c, 0) + 1
			# the journey is classed by how it ends: a bounce that ends in a skid, a tumble or a stop is a halt (a slide); one that ends in a crater is a slam
			if fl.endk != "":
				c = "slide" if (fl.endk == "stop" and fl.bn > 0) else String(fl.endk)
			elif c == "bounce":
				c = "slide"
		if fl.je != null and fl.cls != "brunt":   # World's closing event names how the journey ended, whatever the first contact was
			var jc: String = str(fl.je.end)
			c = "slam" if jc == "slam" else ("water" if jc == "water" else ("wall" if jc == "wall" else "slide"))   # stop, tumble, recover and capped are all a halt
			if fl.pl:
				rec.journeys.jn += 1
				if jc == "capped":
					rec.journeys.capped += 1
				if float(fl.je.len) > 4000.0:
					rec.journeys.long += 1
				if jc == "tumble":
					rec.journeys.tumbledEnd += 1
				if int(fl.je.bounces) > 0:
					rec.journeys.jbounced += 1
					rec.journeys.jbounces += int(fl.je.bounces)
		if c == "slideShort":
			c = "slam"
			rec.slideShort += 1
			if fl.pl:
				rec.slideShortPl += 1
		rec.landingsAll[c] += 1
		if fl.pl:
			rec.landings[c] += 1
			if fl.bn > 0:
				rec.journeys.anyBounce += 1   # launches with at least one bounce, whatever the journey's ending
			if c == "slide" or c == "slam" or c == "bounce":   # a journey: a launch that reached the ground
				rec.journeys.n += 1
				rec.journeys.bounces += fl.bn
				rec.journeys.lips += fl.lip
				if fl.bn > 0:
					rec.journeys.bounced += 1
				if fl.tum:
					rec.journeys.tumbled += 1
	rec.hash = SimHash.stateHash(S).gameplay
	SimCore.dispose(S)
	return rec


## The first contact of the oldest open launch of victim v (balance-targets 18): one class per launch.
func _land(open_fl: Array, v: int, cls: String) -> void:
	for fl in open_fl:
		if fl.v == v and fl.cls == "":
			fl.cls = cls
			return


## A numeric event field under either of two names (World's doc and the EP's note differ: bounces or nb, t or dur), 0 when neither exists.
func _f(e, a: String, b: String) -> float:
	var v = e.get(a)
	if v == null:
		v = e.get(b)
	return float(v) if v != null else 0.0


## A contact (bounce or land) of fighter v's journey: the flight off terrain before it counts as seen if it lasted 10 ticks, and the first contact's x starts the journey's distance.
func _contact(rec: Dictionary, lift: Array, last_fl: Array, v: int, e) -> void:
	if lift[v] != null:
		if int(e.tick) - int(lift[v].tick) >= 10:
			rec.liftsSeen[str(lift[v].cause)] = rec.liftsSeen.get(str(lift[v].cause), 0) + 1
		lift[v] = null
	var fl = last_fl[v]
	if fl != null and not fl.hx0:
		fl.hx0 = true
		fl.x0 = float(e.x)


## The first ground contact's kind from World's events: kept apart from the class the older events gave (crater, slide), which it overrides for a ground class.
func _kind(open_fl: Array, v: int, cls: String) -> void:
	for fl in open_fl:
		if fl.v == v and fl.kc == "" and (fl.cls == "" or fl.cls == "slide" or fl.cls == "slam" or fl.cls == "slideShort"):
			fl.kc = cls
			return


## The victim whose open launch is nearest a water event (a skim or splash carries no actor).
func _nearest_open(S, open_fl: Array, x: float) -> int:
	var best: int = -1
	var bd: float = 1.0e30
	for fl in open_fl:
		if fl.cls == "":
			var d: float = absf(SimWrap.sdx(S.fighters[fl.v].x, x))
			if d < bd:
				bd = d
				best = fl.v
	return best


func _keep(t: String) -> bool:
	for p in KEEP_PREFIXES:
		if t.begins_with(p):
			return true
	return false


func parse(rec: Dictionary, tag: String, sub: String, slot: Dictionary) -> void:
	var m := re_atk.search(tag)
	if m:
		var kind: String = m.get_string(2).to_lower()
		rec.attacks[kind] += 1
		if sub.ends_with("(ambush)"):
			rec.ambush += 1
		if kind == "sig":
			var b := re_beam.search(sub)
			if b:
				rec.beams.append({"bio": b.get_string(2), "variant": b.get_string(3), "out": b.get_string(4), "ds": m.get_string(3), "who": slot.get(m.get_string(1), -1)})
		else:
			var base: String = sub.trim_suffix("  (ambush)").trim_suffix(" → COUNTER")
			rec.melee[base] = rec.melee.get(base, 0) + 1
		return
	m = re_launch.search(tag)
	if m:
		rec.launches[m.get_string(1)] = rec.launches.get(m.get_string(1), 0) + 1
		return
	m = re_parry.search(tag)
	if m:
		rec.parries[slot.get(m.get_string(1), 0)] += 1
		return
	m = re_chain.search(tag)
	if m:
		rec.chains.append(int(m.get_string(1)))
		return
