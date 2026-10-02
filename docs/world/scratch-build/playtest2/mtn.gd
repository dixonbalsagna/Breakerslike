extends SceneTree
# Speed before and after each contact, by slope and incidence: where does a journey gain speed?
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var rows: Array = []          # per contact: [n, kind, spd_in, spd_out, slope, sina, biome, seed, tick, journey v0, bounces]
	var journeys: Array = []      # per journey: [seed, tick, biome, v0, max landing speed, max ground speed, contacts, distance, end]
	var cur := {}
	for sd in range(int(a[0]), int(a[1])):
		var S := SimCore.createSim()
		SimCore.newMatch(S, sd)
		SimGolden.applyArm("default", S.fighters)
		var steps: int = 0
		var lastout := {}
		var maxg := {}
		var firstx := {}
		while S.game.ko == null and steps < 54000:
			SimCore.step(S, null)
			for i in 2:
				var f = S.fighters[i]
				if f.state == "launched" and f.slide > 0.0:
					var key: String = "%d_%d" % [i, f.launchN]
					maxg[key] = maxf(float(maxg.get(key, 0.0)), f.slide)
			for e in S.out.fx:
				var key: String = "%d_%d" % [int(e.actor), int(e.n)]
				if e.type == "land" or e.type == "bounce":
					var spin: float = float(e.spd)
					var prev: float = float(lastout.get(key, -1.0))
					var biome: String = WorldBiomes.biomeAt(float(e.x))
					var out: float = spin * float(e.keep) if e.type == "bounce" else spin
					rows.append([e.type if e.type == "bounce" else String(e.kind), spin, out, float(e.slope), float(e.sina), biome, sd, steps, prev, int(e.contacts)])
					if not cur.has(key):
						cur[key] = [sd, steps, biome, spin, spin, float(e.x), 0]
					cur[key][4] = maxf(cur[key][4], spin)
					cur[key][6] += 1
				elif e.type == "left_ground":
					lastout[key] = float(e.spd)
				elif e.type == "journey_end":
					if cur.has(key):
						var j: Array = cur[key]
						journeys.append([j[0], j[1], j[2], j[3], j[4], float(maxg.get(key, 0.0)), j[6], absf(SimWrap.sdx(j[5], float(e.x))), String(e.kind)])
						cur.erase(key)
			S.out.fx.clear()
			S.out.feed.clear()
			steps += 1
		SimCore.dispose(S)
	# summaries
	var by := {}
	for r in rows:
		var sl: float = absf(r[3])
		var bucket: String = "flat (<0.15)" if sl < 0.15 else ("slope 0.15 to 0.5" if sl < 0.5 else ("steep 0.5 to 1.0" if sl < 1.0 else "cliff (1.0+)"))
		var k2: String = r[0] + " | " + bucket
		if not by.has(k2):
			by[k2] = [0, 0, 0.0, 0.0, 0, 0]
		by[k2][0] += 1
		if r[1] > 0.0:
			by[k2][2] += r[2] / r[1]
			if r[2] > r[1] * 1.0001:
				by[k2][1] += 1
		if r[8] > 0.0:
			by[k2][3] += r[1] / r[8]      # landing speed over the last leave speed (gravity in the flight)
			by[k2][4] += 1
			if r[1] > r[8] * 1.15:
				by[k2][5] += 1
	var keys: Array = by.keys()
	keys.sort()
	for k in keys:
		var v: Array = by[k]
		print("MTN %s: n %d, out/in speed mean %.2f, contacts adding speed %d, landing/last-leave mean %.2f (n %d, landing >15%% over the leave speed: %d)" % [k, v[0], v[2] / maxf(v[0], 1), v[1], v[3] / maxf(v[4], 1), v[4], v[5]])
	# journeys: max ground speed over the first-contact speed, by biome
	var bj := {}
	for j in journeys:
		var b: String = j[2]
		if not bj.has(b):
			bj[b] = [0, 0, 0, 0.0, 0.0]
		bj[b][0] += 1
		var gain: float = j[5] / maxf(j[3], 1.0)
		var land: float = j[4] / maxf(j[3], 1.0)
		if gain > 1.0:
			bj[b][1] += 1
		if gain > 1.25:
			bj[b][2] += 1
		bj[b][3] += gain
		bj[b][4] += land
	for b in bj:
		var v2: Array = bj[b]
		print("MTNJ %s: %d journeys; peak ground speed over the first-contact speed: mean %.2f, above 1.0 in %d, above 1.25 in %d; peak landing speed over first: mean %.2f" % [b, v2[0], v2[3] / v2[0], v2[1], v2[2], v2[4] / v2[0]])
	journeys.sort_custom(func(p, q): return p[5] / maxf(p[3], 1.0) > q[5] / maxf(q[3], 1.0))
	for k in range(mini(8, journeys.size())):
		var j: Array = journeys[k]
		print("MTNTOP seed %d tick %d %s: first-contact speed %.0f, peak ground speed %.0f (x%.2f), peak landing %.0f, contacts %d, distance %.0f, end %s" % [j[0], j[1], j[2], j[3], j[5], j[5] / maxf(j[3], 1.0), j[4], j[6], j[7], j[8]])
	quit(0)
