extends SceneTree
## Posed pictures for the rule-of-cool work (docs/rendering/README.md, "Battle damage" and "The sky reacts"): the
## mannequin's battle damage at each wound stage, full and reduced, the sky with its clouds, reacting to a fighter
## at tier 3 and at tier 4, and a block's windows before and after a blow-out. The tool poses a fresh match's fighters by hand (its own state, never the game's: the wound
## stages and the tier are set directly), runs no ticks and draws the real scene. Needs a window (not --headless).
##   godot --path . --script res://render/tools/cool_shots.gd -- --out=DIR [--s=1]

const CELL := Vector2i(300, 330)   # one figure of the damage sheet

var main: Node
var out: String = "."
var seed: int = 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--s="):
			seed = int(a.substr(4))
	var vpn := SubViewport.new()
	vpn.size = Vector2i(1280, 720)
	vpn.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	main.started = true
	main.start_match(seed)
	main.ui_hud.visible = false
	main.hud.visible = false
	var S: SimState = main.host.S
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	# Open plains, away from buildings.
	var x0: float = _plains(S)
	for i in range(2):
		var f = S.fighters[i]
		f.x = SimWrap.wrap(x0 + (-170.0 if i == 0 else 170.0))
		f.y = WorldTerrain.groundY(S, f.x) + 2.0
		f.z = 0.0
		f.face = 1.0 if i == 0 else -1.0
	for k in range(3):
		main.host.follow(vp.x, vp.y)
	# 1: the damage sheet. Rows: each fighter at full detail, then the first again reduced. Columns: stages 0 to 3.
	var sheet := Image.create_empty(CELL.x * 4, CELL.y * 3, false, Image.FORMAT_RGBA8)
	var rows: Array = [[0, false], [1, false], [0, true]]
	for r in range(rows.size()):
		for st in range(4):
			for i in range(2):
				S.fighters[i].stage = [st, st, st, st]
			_forget()
			FighterView.damage_reduced = rows[r][1]
			var img: Image = await _frame(S, S.fighters[rows[r][0]], 3.4, vp)
			sheet.blit_rect(img, Rect2i((img.get_width() - CELL.x) / 2, (img.get_height() - CELL.y) / 2 - 20, CELL.x, CELL.y), Vector2i(CELL.x * st, CELL.y * r))
	sheet.save_png("%s/damage-sheet.png" % out)
	FighterView.damage_reduced = false
	# 2: battle damage at the fight's own size, both battered.
	for i in range(2):
		S.fighters[i].stage = [2, 3, 2, 1]
	_forget()
	(await _wide(S, 1.1, vp)).save_png("%s/damage-fight.png" % out)
	for i in range(2):
		S.fighters[i].stage = [0, 0, 0, 0]
	_forget()
	# 3: the sky. Clouds alone, then reacting to a tier-3 and to a tier-4 fighter, then both, then the reduced version.
	# Each: the picture's name, the two tiers, clouds on, and how high above the ground both fly (the high camera: the
	# gap must stay a gap in the clouds and never a pillar against the horizon, QA's GB-002).
	var skies: Array = [["sky-calm", 1.0, 1.0, true, 0.0], ["sky-tier3", 3.0, 1.0, true, 0.0], ["sky-tier4", 4.0, 1.0, true, 0.0], ["sky-both", 4.0, 4.0, true, 0.0], ["sky-reduced", 4.0, 1.0, false, 0.0], ["sky-high-calm", 1.0, 1.0, true, 3000.0], ["sky-high-both", 4.0, 4.0, true, 3000.0]]
	PaneWorld.sky_react_on = true   # off in the game unless --skyreact is given: these are the pictures of it
	for sk in skies:
		for i in range(2):
			var f = S.fighters[i]
			f.tier = sk[1] if i == 0 else sk[2]
			f.y = WorldTerrain.groundY(S, f.x) + 2.0 + float(sk[4])
		for k in range(3):
			main.host.follow(vp.x, vp.y)
		PaneWorld.clouds_on = sk[3]
		(await _wide(S, 0.62, vp)).save_png("%s/%s.png" % [out, sk[0]])
	for i in range(2):
		S.fighters[i].y = WorldTerrain.groundY(S, S.fighters[i].x) + 2.0
	PaneWorld.clouds_on = true
	PaneWorld.sky_react_on = false
	S.fighters[0].tier = 1.0
	S.fighters[1].tier = 1.0
	# 4: windows. A city block as it stands, then after a blow-out wave from between the fighters, as VFX lists one
	# (the nearest buildings lose more rows; render/vfx/react.gd).
	var blk: int = _block(S)
	if blk >= 0:
		var bx: float = S.buildings[blk].x
		for i in range(2):
			var f = S.fighters[i]
			f.x = SimWrap.wrap(bx + (-300.0 if i == 0 else 300.0))
			f.y = WorldTerrain.groundY(S, f.x) + 2.0
		for k in range(3):
			main.host.follow(vp.x, vp.y)
		(await _wide(S, 0.5, vp)).save_png("%s/windows-before.png" % out)
		var list: Array = []
		for b in S.buildings:
			var d: float = absf(SimWrap.sdx(bx, b.x))
			if b.alive and int(b.floors) >= 3 and d < 3200.0:
				list.append({"b": b.idx, "at": S.T, "strength": clampf(1.0 - 0.6 * d / 3200.0, 0.2, 1.0), "lo": 0, "hi": int(b.floors) - 1})
		main.planet.blow_windows(S, list)
		(await _wide(S, 0.5, vp)).save_png("%s/windows-after.png" % out)
	quit(0)


## A row-1 tower with towers either side of it: the middle of a block.
static func _block(S: SimState) -> int:
	var best: int = -1
	var most: int = 0
	for i in range(S.buildings.size()):
		var b = S.buildings[i]
		if not b.alive or int(b.row) != 1 or b.d <= 0.0 or WorldStructures.curH(b) < 600.0:
			continue
		var n: int = 0
		for j in range(S.buildings.size()):
			var t = S.buildings[j]
			if j != i and t.alive and int(t.row) == 1 and absf(SimWrap.sdx(b.x, t.x)) < 900.0 and WorldStructures.curH(t) > 300.0:
				n += 1
		if n > most:
			most = n
			best = i
	return best


## The marks stay through a match; a posed sheet steps the stages back down, so the views forget.
func _forget() -> void:
	for v in main.pane.fighter_views:
		v.snap_damage(true)


## Open country for the sky: the plains column farthest along the planet from any mountain (their far massif hides
## the sky behind it), where no water stands.
static func _plains(S: SimState) -> float:
	var peaks: Array = []
	for c in range(0, SimConst.NC, 16):
		if WorldBiomes.biomeAt(float(c) * SimConst.COL) == "mountains":
			peaks.append(float(c) * SimConst.COL)
	var best: float = 0.0
	var far: float = -1.0
	for c in range(0, SimConst.NC, 8):
		var x: float = float(c) * SimConst.COL
		if WorldBiomes.biomeAt(x) != "plains" or WorldWater.surfaceAt(S, x) > WorldTerrain.groundY(S, x) + 0.5:
			continue
		var d: float = INF
		for px in peaks:
			d = minf(d, absf(SimWrap.sdx(x, px)))
		if d > far:
			far = d
			best = x
	return best


## One frame with fighter f at the screen's centre at this zoom.
func _frame(S: SimState, f, zoom: float, vp: Vector2) -> Image:
	var cam := Vector3(0.0, f.y + 45.0 - 0.2 * vp.y / zoom, zoom)
	return await _draw(f.x, cam)


## One frame of both fighters, low in the frame, at this zoom.
func _wide(S: SimState, zoom: float, vp: Vector2) -> Image:
	var mid: float = SimWrap.wrap(S.fighters[0].x + SimWrap.sdx(S.fighters[0].x, S.fighters[1].x) * 0.5)
	var cam := Vector3(0.0, S.fighters[0].y + 45.0 + 150.0 / zoom - 0.2 * vp.y / zoom, zoom)
	return await _draw(mid, cam)


func _draw(cam_x: float, cam: Vector3) -> Image:
	main.pane.snap_occlusion()
	main.pane.render(main.host, 1.0, cam_x, cam, Vector2.ZERO)
	await RenderingServer.frame_post_draw
	main.pane.render(main.host, 1.0, cam_x, cam, Vector2.ZERO)
	await RenderingServer.frame_post_draw
	return main.get_viewport().get_texture().get_image()
