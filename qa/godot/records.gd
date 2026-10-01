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
var re_beam := RegEx.create_from_string("^(.+) over (\\w+) \\((.+)\\) → (\\w+)")
var re_launch := RegEx.create_from_string("^LAUNCH: (.+)$")
var re_parry := RegEx.create_from_string("^([A-Z][A-Z0-9-]*) PARRIES$")
var re_chain := RegEx.create_from_string("^CHAIN x(\\d+) ended$")


func _init() -> void:
	var pos: Array = []
	var arm: String = "default"
	var out: String = ""
	var cap: int = 200000        # tick safety only; the match cap is in sim seconds (hit-stop ticks do not advance S.T)
	var capsec: float = 900.0     # the S4 ruling: 15:00 of sim time
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arm="):
			arm = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--capsec="):
			capsec = float(a.substr(9))
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
		"fightSec": {}, "dmgVictim": [0.0, 0.0], "batteredIn": 0.0, "breathWear": 0.0, "casTimeline": [], "slides": [], "impactCraters": 0, "skims": 0, "longHaul": 1500.0 * SimConst.TRAV_LAUNCH, "dmgByRegion": {}, "underSec": 0.0, "tierT": [0.0, -1.0, -1.0, -1.0, -1.0], "flights": [], "hiddenSec": [0.0, 0.0], "exLens": [], "exGaps": [], "fxCounts": {}, "events": [], "fronts": 0}
	var prev_x: Array = [fs[0].x, fs[1].x]
	var was_launched: Array = [false, false]
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
				rec.flights.append({"travel": snappedf(absf(SimWrap.sdx(launch_x[i], f.x)), 0.1), "newBiome": WorldBiomes.biomeAt(launch_x[i]) != WorldBiomes.biomeAt(f.x)})
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
			# knockback slides and slams (docs/world/knockback-slide.md): a slide ends in one `slide` event, a slam digs an impact crater
			if e.type == "slide":
				rec.slides.append({"len": snappedf(absf(e.get("x1") - e.x), 1.0), "w": snappedf(e.w, 0.1), "depth": snappedf(e.depth, 0.1), "energy": snappedf(e.energy, 0.1), "variant": e.variant, "owner": e.owner, "t": snappedf(S.T, 0.001)})
			elif e.type == "crater" and e.cause == "impact":
				rec.impactCraters += 1
			elif e.type == "skim":
				rec.skims += 1
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
		var fr = S.get("frontsInFrame")   # hazard fronts inside the camera framing, once living destruction lands; null before
		if fr != null:
			rec.fronts = maxi(rec.fronts, int(fr))
		S.out.fx.clear()
		for l in S.out.feed:
			parse(rec, l.tag, l.sub, slot)
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
	rec.hash = SimHash.stateHash(S).gameplay
	SimCore.dispose(S)
	return rec


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
				rec.beams.append({"bio": b.get_string(2), "variant": b.get_string(3), "out": b.get_string(4), "ds": m.get_string(3)})
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
