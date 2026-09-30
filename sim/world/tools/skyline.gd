extends SceneTree
## Scratch generator report for the districts slice (docs/world/districts-plan.md): loads data/biomes/settlements.json,
## generates every settlement with WorldSettle on seed 1's world, prints the counts, heights and people per district, and
## writes two front-elevation SVGs of the skyline (docs/world/d1-skyline-bellgate.svg, docs/world/d1-skyline-planet.svg) for
## Art and Camera. It changes no sim state and draws nothing from S.rng. From the repo root:
##   godot --headless --path . --script res://sim/world/tools/skyline.gd

const BH: float = 75.0
const ROW_FILL: Array = ["#8fa3ad", "#51606b", "#6f7f8a", "#9aa8b1"]   # row 0 (foreground) to row 3 (back)
const ROW_OPACITY: Array = [0.9, 1.0, 0.85, 0.7]


func _init() -> void:
	var errs: Array = WorldSettle.errors()
	if not errs.is_empty():
		for e in errs:
			print("FAIL  " + str(e))
		quit(1)
		return
	var d: Dictionary = WorldSettle.data()
	var S := SimCore.createSim()
	SimCore.newMatch(S, 1)
	var all: Array = []
	var total: int = 0
	var total_pop: int = 0
	for s in d.settlements:
		var g: Dictionary = WorldSettle.generate(S, s)
		var bl: Array = g.buildings
		var pop: int = 0
		for b in bl:
			pop += int(b.pop)
		print("== %s (%s): span %.0f to %.0f units (%.0f long), %d buildings, %d rejected, %d people" % [s.id, s.archetype, g.span[0], g.span[1], g.span[1] - g.span[0], bl.size(), g.rejected, pop])
		for di in range(s.districts.size()):
			var dd: Dictionary = s.districts[di]
			var hs: Array = []
			var rows := [0, 0, 0, 0]
			var dpop: int = 0
			var maxpop: int = 0
			var lms: Array = []
			for b in bl:
				if b.district == di:
					hs.append(b.h / BH)
					rows[b.row] += 1
					dpop += int(b.pop)
					maxpop = maxi(maxpop, int(b.pop))
					if b.landmark != 0:
						lms.append("%s %.0f bh" % [d.landmarks[b.landmark - 1].key, b.h / BH])
			hs.sort()
			var n: int = hs.size()
			var line: String = "  %-14s %3d buildings" % [dd.name, n]
			if n > 0:
				line += "  rows %s  height bh min %.0f median %.0f max %.0f  people %d (max %d)" % [str(rows), hs[0], hs[n / 2], hs[n - 1], dpop, maxpop]
			if not lms.is_empty():
				line += "  landmark: " + ", ".join(lms)
			print(line)
		total += bl.size()
		total_pop += pop
		all.append(g)
	print("total: %d buildings (196 today), %d people (pop0 %d)" % [total, total_pop, int(d.pop0)])
	var bell = null
	var belli: int = 0
	for i in range(d.settlements.size()):
		if d.settlements[i].id == "bellgate":
			bell = all[i]
			belli = i
	_svg("res://docs/world/d1-skyline-bellgate.svg", [bell], bell.span[0], bell.span[1], 1600.0, 0.42, d)
	_svg("res://docs/world/d1-skyline-planet.svg", all, 0.0, float(SimConst.W), 1600.0, 0.42, d)
	SimCore.dispose(S)
	quit(0)


## A front elevation: the buildings of the given settlements between x0 and x1, back rows first, to a pixel width. The
## scale is pixels per world unit of x; the height uses the same scale times vscale (so the skyline is not stretched).
func _svg(path: String, sets: Array, x0: float, x1: float, px_w: float, vscale: float, d: Dictionary) -> void:
	var sx: float = px_w / (x1 - x0)
	var tall: float = 0.0
	for g in sets:
		for b in g.buildings:
			tall = maxf(tall, b.h)
	var H: float = tall * sx * 1.0 + 40.0
	var out: String = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 %d %d\" width=\"%d\" height=\"%d\">\n" % [int(px_w), int(H), int(px_w), int(H)]
	out += "<rect width=\"100%\" height=\"100%\" fill=\"#dfe8ee\"/>\n"
	var ground: float = H - 20.0
	for row in [3, 2, 1, 0]:
		for g in sets:
			for b in g.buildings:
				if b.row != row:
					continue
				var x: float = (b.x - b.w * 0.5 - x0) * sx
				var w: float = maxf(b.w * sx, 0.6)
				var h: float = b.h * sx
				var fill: String = ROW_FILL[row]
				if b.landmark != 0:
					fill = "#c4452f"
				out += "<rect x=\"%.2f\" y=\"%.2f\" width=\"%.2f\" height=\"%.2f\" fill=\"%s\" fill-opacity=\"%.2f\" stroke=\"#20282e\" stroke-width=\"0.3\"/>\n" % [x, ground - h, w, h, fill, ROW_OPACITY[row]]
	out += "<rect x=\"0\" y=\"%.1f\" width=\"%d\" height=\"20\" fill=\"#7a8a72\"/>\n" % [ground, int(px_w)]
	out += "</svg>\n"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("FAIL  cannot write " + path)
		return
	f.store_string(out)
	f.close()
	print("wrote " + path)
