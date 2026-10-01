extends SceneTree
# L1 + D1 layout checks on the generated world
const BH: float = 75.0
func _init() -> void:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 1)
	var rows := {}
	var street_hits: int = 0
	var out_of_lane: int = 0
	var overlap: int = 0
	var dsum := {}
	var tall := 0.0
	var tallest := 0.0
	var byrow := {}
	for b in S.buildings:
		var r: int = int(b.row)
		rows[r] = rows.get(r, 0) + 1
		var lo: float = (b.z - b.d * 0.5) / BH
		var hi: float = (b.z + b.d * 0.5) / BH
		var ln: Dictionary = WorldSettle.laneOfRow(r)
		if hi > float(ln.top) + 0.001 or lo < float(ln.bottom) - 0.001:
			out_of_lane += 1
		if r == 1 or r == 2:
			# street intervals: front street +5 to -4, back street -12 to -18
			if (hi > -4.0 + 0.001 and lo < 5.0) or (hi > -18.0 + 0.001 and lo < -12.0 - 0.001 and r == 1) or (r == 2 and hi > -12.0 + 0.001):
				street_hits += 1
		if not byrow.has(r):
			byrow[r] = []
		byrow[r].append(b)
		tallest = maxf(tallest, b.h / BH)
		dsum[r] = dsum.get(r, 0.0) + b.d / BH
	for r in byrow:
		var arr: Array = byrow[r]
		arr.sort_custom(func(p, q): return p.x < q.x)
		for i in range(1, arr.size()):
			var gap: float = (arr[i].x - arr[i].w * 0.5) - (arr[i - 1].x + arr[i - 1].w * 0.5)
			if gap < -0.01:
				overlap += 1
	var s: String = "LANES buildings %d: rows %s | mean depth bh by row:" % [S.buildings.size(), str(rows)]
	for r in dsum:
		s += " row%d %.1f" % [r, dsum[r] / rows[r]]
	s += " | footprints outside their lane %d, block footprints touching a street %d, x overlaps in a row %d | tallest %.0f bh | population %.0f" % [out_of_lane, street_hits, overlap, tallest, S.world.pop0]
	print(s)
	# avenues: a gap through the band: for each pair of x positions at the avenue, no row 1 or 2 building spans it
	var gen: Dictionary = WorldSettle.generate(S, WorldSettle.data().settlements[1])
	var bad: int = 0
	var nav: int = 0
	for dd in gen.districts:
		for av in dd.avenues:
			nav += 1
			for b in gen.buildings:
				if int(b.row) in [1, 2] and b.x - b.w * 0.5 < av[1] - 0.01 and b.x + b.w * 0.5 > av[0] + 0.01:
					bad += 1
	print("LANES Bellgate: %d avenues, buildings of row 1 or 2 across an avenue: %d" % [nav, bad])
	SimCore.dispose(S)
	quit(0)
