extends SceneTree
# Journey statistics for Game Design's re-measure (balance-targets section 20): endings, bounce shares, time and distance, bounds,
# lip flights per minute, wear against the single-impact budget, collateral per journey, off-screen distance.
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var launches: int = 0
	var journeys: int = 0
	var ends := {}
	var with_bounce: int = 0
	var bounces_total: int = 0
	var lips_total: int = 0
	var minutes: float = 0.0
	var times: Array = []
	var dists: Array = []
	var hit_cap_t: int = 0
	var hit_cap_c: int = 0
	var capped_kind: int = 0
	var wear_ratio: Array = []
	var wear_over: int = 0
	var cas_pct: Array = []
	var struct_lost: Array = []
	var open := {}
	var firstcls := {}
	var lg_causes := {}
	for sd in range(int(a[0]), int(a[1])):
		var S := SimCore.createSim()
		SimCore.newMatch(S, sd)
		SimGolden.applyArm("default", S.fighters)
		var steps: int = 0
		var pop0: float = S.world.pop0
		while S.game.ko == null and steps < 54000:
			SimCore.step(S, null)
			for e in S.out.fx:
				var key: String = "%d_%d_%d" % [sd, int(e.actor), int(e.n)]
				if e.type == "launch":
					launches += 1
				elif e.type in ["land", "bounce", "skim"]:
					if not open.has(key):
						open[key] = {"x": e.x, "spd": e.spd, "dmg": 0.0, "cas": S.world.casualties, "st": S.world.structuresLost}
						var cls: String = e.type
						if e.type == "land":
							cls = e.kind
						firstcls[cls] = firstcls.get(cls, 0) + 1
				elif e.type == "left_ground":
					lg_causes[e.cause] = lg_causes.get(e.cause, 0) + 1
				elif e.type == "damage" and e.kind == "impact":
					for k2 in open:
						if k2.begins_with("%d_%d_" % [sd, int(e.victim)]):
							open[k2].dmg += e.amount
				elif e.type == "journey_end":
					journeys += 1
					ends[e.kind] = ends.get(e.kind, 0) + 1
					if e.nb > 0:
						with_bounce += 1
						bounces_total += e.nb
					lips_total += e.lips
					times.append(e.dur)
					if e.dur >= 3.95:
						hit_cap_t += 1
					if e.contacts >= 8:
						hit_cap_c += 1
					if e.kind == "capped":
						capped_kind += 1
					if open.has(key):
						var o: Dictionary = open[key]
						dists.append(absf(SimWrap.sdx(o.x, e.x)))
						var budget: float = o.spd * 0.018
						if budget > 0.0:
							wear_ratio.append(o.dmg / budget)
							if o.dmg > budget * 1.05:
								wear_over += 1
						cas_pct.append((S.world.casualties - o.cas) / maxf(pop0, 1.0) * 100.0)
						struct_lost.append(S.world.structuresLost - o.st)
						open.erase(key)
			S.out.fx.clear()
			S.out.feed.clear()
			steps += 1
		minutes += S.T / 60.0
		SimCore.dispose(S)
	times.sort()
	dists.sort()
	wear_ratio.sort()
	var jn: float = maxf(float(journeys), 1.0)
	var ncls: float = 0.0
	for k in firstcls:
		ncls += firstcls[k]
	var line: String = "J2 launches %d journeys %d (%.0f%% of launches) | ends %s | bounced %.1f%% of launches, bounces per bounced journey %.2f | first contacts %s\n" % [launches, journeys, 100.0 * journeys / maxf(launches, 1.0), str(ends), 100.0 * with_bounce / maxf(launches, 1.0), float(bounces_total) / maxf(with_bounce, 1.0), str(firstcls)]
	line += "J2 journey time s mean %.2f p90 %.2f | distance units mean %.0f p90 %.0f, over 2000: %.0f%% over 4000: %.0f%% over 8000: %.0f%% | 4 s bound %.1f%%, 8 contacts %.1f%%, capped end %.1f%%\n" % [_mean(times), _pct(times, 0.9), _mean(dists), _pct(dists, 0.9), _share(dists, 2000.0), _share(dists, 4000.0), _share(dists, 8000.0), 100.0 * hit_cap_t / jn, 100.0 * hit_cap_c / jn, 100.0 * capped_kind / jn]
	line += "J2 lip flights per minute %.2f | wear per journey / single-impact budget mean %.2f p90 %.2f, over budget %.1f%% | casualties per journey mean %.3f%% of pop, structures levelled per journey %.2f" % [lips_total / maxf(minutes, 0.01), _mean(wear_ratio), _pct(wear_ratio, 0.9), 100.0 * wear_over / maxf(float(wear_ratio.size()), 1.0), _mean(cas_pct), _mean(struct_lost)]
	var lgl: String = "J2 left_ground per minute:"
	for k in lg_causes:
		lgl += " %s %.2f" % [k, lg_causes[k] / maxf(minutes, 0.01)]
	print(line)
	print(lgl)
	quit(0)


func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s: float = 0.0
	for v in a:
		s += float(v)
	return s / float(a.size())


func _pct(a: Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	return float(a[mini(a.size() - 1, int(floor(float(a.size()) * p)))])


func _share(a: Array, thr: float) -> float:
	if a.is_empty():
		return 0.0
	var n: int = 0
	for v in a:
		if float(v) > thr:
			n += 1
	return 100.0 * n / float(a.size())
