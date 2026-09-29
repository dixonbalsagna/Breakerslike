extends SceneTree
## Ground check: the drawn ground against the sim's (render/core/ground_field.gd). It runs real matches through the
## full scene, one tick per frame, and every CHECK_EVERY ticks checks:
## 1. data: the rows the GPU holds are the sim's bytes: S.base, S.deform, S.scorch and S.water, bit for bit;
## 2. slice: the band's fighter-plane row reads S.deform directly, so the ground drawn there is base + deform exactly;
##    the bowl formula that draws every other row, evaluated at z = 0, is within SLICE_TOL of it, so the rows beside
##    the fighter plane join it without a step;
## 3. rebuild: a fresh GroundField rebuilt from state alone (as for a replay seek or a snapshot restore) holds the same
##    crater lists, residual and crater data as the one the renderer kept up to date frame by frame.
## Then, on a staged state, a crater on the wrap seam (x = 0) must be mirror-symmetric across it at every depth.
## Also checks the mesh: every column has exactly one top-grid vertex on z = 0, flagged exact.
##   godot --headless --path . --script res://render/tools/ground_check.gd [-- --seeds=4,12345,7 --ticks=5400]

const CHECK_EVERY := 120
const SLICE_TOL := 0.01

var seeds: Array = [4, 12345, 7]
var max_ticks: int = 5400
var main: Node
var fails: Array = []
var checks: int = 0
var worst_slice: float = 0.0
var craters_seen: int = 0
var furrows_seen: int = 0
var wet_max: int = 0
var burnt_max: int = 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
	var vpn := SubViewport.new()
	vpn.size = Vector2i(1280, 720)
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_check_mesh()
	for seed in seeds:
		main.start_match(seed, {"p1": true, "p2": true})
		var S: SimState = main.host.S
		while main.host.ticks < max_ticks and not (S.game.ko != null and S.game.koT > 3.0):
			main.frame(1.0 / 60.0)
			if main.host.ticks % CHECK_EVERY == 0:
				_check(S, "seed %d tick %d" % [seed, main.host.ticks])
		_check(S, "seed %d end (tick %d)" % [seed, main.host.ticks])
		craters_seen += S.craters.size()
		for c in S.craters:
			if c.skid != 0.0:
				furrows_seen += 1
	_check_seam()
	print("Ground check  %d checks over seeds %s" % [checks, seeds])
	print("craters %d (furrows %d), most wet columns %d, most burnt columns %d" % [craters_seen, furrows_seen, wet_max, burnt_max])
	print("slice: fighter-plane row = S.deform bit for bit; bowl formula at z = 0 within %.6f (limit %.2f)" % [worst_slice, SLICE_TOL])
	print("full rebuilds during play: %d (a new match each)" % main.planet.ground.full_rebuilds)
	if fails.is_empty():
		print("\nground check passed")
	else:
		for f in fails.slice(0, 20):
			print("FAIL  " + f)
		print("\nground check FAILED (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


func _check_mesh() -> void:
	var arr: Array = main.planet.terrain_mesh().surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
	var per_col: Dictionary = {}
	for k in range(v.size()):
		if uv2[k].x > 0.5 and uv2[k].y > 0.5:
			if v[k].z != 0.0 or uv[k].y < 0.5:
				fails.append("mesh: an exact-row vertex at z %.1f (follows height %s)" % [v[k].z, uv[k].y > 0.5])
			per_col[int(uv[k].x)] = per_col.get(int(uv[k].x), 0) + 1
	for i in range(SimConst.NC + 1):
		if per_col.get(i, 0) != 1:
			fails.append("mesh: column %d has %d exact-row vertices" % [i, per_col.get(i, 0)])
			break


func _check(S: SimState, label: String) -> void:
	checks += 1
	var gfld: GroundField = main.planet.ground
	for r in [[GroundField.ROW_BASE, S.base, "base"], [GroundField.ROW_DEFORM, S.deform, "deform"], [GroundField.ROW_SCORCH, S.scorch, "scorch"], [GroundField.ROW_WATER, S.water, "water"]]:
		if gfld.row_bytes(r[0]) != r[1].to_byte_array():
			fails.append("%s: the GPU's %s row differs from the sim's" % [label, r[2]])
	for i in range(SimConst.NC):
		var d: float = absf(gfld.offset_at(S, i, float(i) * SimConst.COL, 0.0) - S.deform[i])
		worst_slice = maxf(worst_slice, d)
		if d > SLICE_TOL:
			fails.append("%s: column %d, the bowl formula at z = 0 is %.4f off deform" % [label, i, d])
			break
	var fresh := GroundField.new()
	fresh.rebuild(S)
	if fresh.lists != gfld.lists or fresh.g != gfld.g or fresh.cdata != gfld.cdata:
		fails.append("%s: a rebuild from state differs from the kept-up-to-date field (lists %s, residual %s, craters %s)" % [label, fresh.lists == gfld.lists, fresh.g == gfld.g, fresh.cdata == gfld.cdata])
	var wet: int = 0
	var burnt: int = 0
	for i in range(SimConst.NC):
		if S.water[i] >= 0.5 and S.base[i] >= -30.0:
			wet += 1
		if S.scorch[i] > 0.0:
			burnt += 1
	wet_max = maxi(wet_max, wet)
	burnt_max = maxi(burnt_max, burnt)


## A crater dug exactly on the seam must read the same on both sides of it, at every depth of the band.
func _check_seam() -> void:
	main.start_match(3, {"p1": true, "p2": true})
	var S: SimState = main.host.S
	WorldCrater.dig(S, 0.0, 12.0, null, "impact", 0.0, 1.0)
	S.out.fx.clear()
	var gfld := GroundField.new()
	gfld.rebuild(S)
	var worst: float = 0.0
	for z in RenderLook.BAND_ROWS:
		if z == 0.0:
			continue
		for d in [8.0, 40.0, 120.0, 200.0, 320.0]:
			var a: float = gfld.ground_at(S, SimConst.W - d, z) - S.base[int((SimConst.W - d) / SimConst.COL)]
			var b: float = gfld.ground_at(S, d, z) - S.base[int(d / SimConst.COL)]
			worst = maxf(worst, absf(a - b))
	print("seam crater: largest left/right difference in the bowl across the seam %.6f units" % worst)
	if worst > 0.01:
		fails.append("seam: a crater on x = 0 is %.4f asymmetric across the seam" % worst)
