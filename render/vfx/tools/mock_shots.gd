extends SceneTree
## The burst-through and collapse effects on mock events (render/vfx/mock/vfx_mock.gd), against the real planet. It
## stages a fixture (fighter positions, and the buildings' fallen state set the way shots.gd stages craters), plays a
## scenario tick by tick through host.vfx.consume() with events shaped like B2's, and saves pictures. The camera is set
## by hand: "follow" tracks the launched fighter at a gameplay zoom, "wide" frames the whole building. Needs a window.
##   godot --path . --script res://render/vfx/tools/mock_shots.gd -- --out=DIR [--scenario=burst|chain|implode|all]
##       [--size=1280x720] [--zoom=0.5] [--novfx]

const DT := SimConst.DT

var main: Node
var out: String = "."
var scenario: String = "all"
var size := Vector2i(1280, 720)
var zoom: float = 0.5
var novfx: bool = false
var shots: int = 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--scenario="):
			scenario = a.substr(11)
		elif a.begins_with("--size="):
			var wh: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
		elif a == "--novfx":
			novfx = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vpn := SubViewport.new()
	vpn.size = size
	vpn.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	main.started = true
	var h = main.host.vfx
	h.auto_quality = false
	h.enabled = not novfx
	h.destruction_enabled = true
	h.cracks_enabled = false
	for sc in ["burst", "heavy", "chain", "implode", "embers"]:
		if scenario != "all" and scenario != sc:
			continue
		await call("_play_" + sc)
	print("shots: %d" % shots)
	quit()


## Fresh match with both fighters parked and the tick clock at zero.
func _fresh() -> SimState:
	main.start_match(1)
	var S: SimState = main.host.S
	S.out.fx.clear()
	return S


## The tower nearest the city centre with the most neighbours: returns the chain of standing towers around x.
func _pick(S: SimState, n: int) -> Array:
	var c: float = SimWrap.wrap(2960.0 * SimConst.PS)
	var near: Array = VfxMock.towers_near(S, c, 30000.0)
	# The first group of n towers, in order along x, whose gaps are small.
	for i in range(near.size() - n + 1):
		var ok: bool = true
		for k in range(n - 1):
			var a = S.buildings[near[i + k]]
			var b = S.buildings[near[i + k + 1]]
			if SimWrap.sdx(a.x, b.x) - (a.w + b.w) * 0.5 > 3000.0 or S.buildings[near[i + k]].h < 900.0:
				ok = false
		if ok:
			return near.slice(i, i + n)
	return near.slice(0, n)


func _tick(S: SimState, events: Array, frozen: bool = false) -> void:
	if not frozen:
		S.T += DT
	S.tick += 1
	var t := SimState.FxEvent.new()
	t.type = "tick"
	t.dt = DT
	t.frozen = frozen
	events.append(t)
	main.host.vfx.consume(S, events)


## Camera by hand: centred on (x, y) at zoom z, then a frame.
func _frame(S: SimState, x: float, y: float, z: float) -> void:
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	main.host.follow(vp.x, vp.y)
	main.host.cam.x = SimWrap.wrap(x)
	main.host.cam.y = y + 0.2 * vp.y / z
	main.host.cam.z = z
	main.host._prev = main.host._capture()
	main.host._cur = main.host._prev
	main.render_view(1.0)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	main.render_view(1.0)
	await RenderingServer.frame_post_draw
	var path: String = "%s/mock_%s.png" % [out, name]
	main.get_viewport().get_texture().get_image().save_png(path)
	var hub = main.host.vfx
	print("saved %s (bits %d, shards %d, puffs %d, holes %d, jobs %d)" % [path, hub.debris.bits.size(), main.panes[0].vfx_layer.shard_view.shards, main.panes[0].vfx_layer.shard_view.puffs, hub.holes.size(), hub.debris.jobs.size()])
	shots += 1


## Kill a building in the fixture: standing height to nothing, no one left in it.
func _fell(S: SimState, bi: int) -> void:
	var b = S.buildings[bi]
	b.alive = false
	b.hp = 0.0
	b.popAlive = 0.0


func _fly(S: SimState, f, x: float, y: float, vx: float, vy: float) -> void:
	f.x = SimWrap.wrap(x)
	f.y = y
	f.vx = vx
	f.vy = vy
	f.state = "launched"


func _park(S: SimState, x: float) -> void:
	var g = S.fighters[1]
	g.x = SimWrap.wrap(x)
	g.y = WorldTerrain.groundY(S, g.x) + 40.0
	g.state = "free"
	g.vx = 0.0
	g.vy = 0.0


## One tower, one launch straight through it: 9,000 units a second, in at the near wall and out at the far. Camera's hit
## hold (0.35 s) is played as frozen ticks, in which the shrapnel moves at a tenth of its speed.
func _play_burst() -> void:
	await _burst("collapse", "burst")


## The same, but the tower survives as a heavy wreck: the hole stays in its wall.
func _play_heavy() -> void:
	await _burst("heavy", "heavy")


func _burst(outcome: String, tag: String) -> void:
	var S: SimState = _fresh()
	var bi: int = _pick(S, 1)[0]
	var b = S.buildings[bi]
	var g: float = WorldTerrain.groundY(S, b.x)
	var y0: float = g + b.h * 0.42
	var v: float = 9000.0
	var x0: float = b.x - b.w * 0.5 - 4200.0
	var f = S.fighters[0]
	_park(S, x0 - 300.0)
	var hit_tick: int = int(4200.0 / (v * DT))
	var after: Dictionary = {12: "d_flight", 40: "e_settle", 80: "f_dust"}
	for t in range(hit_tick + 100):
		var evs: Array = []
		var x: float = x0 + v * DT * float(t) if t <= hit_tick else b.x + b.w * 0.5 + 300.0 * DT * float(t - hit_tick)
		_fly(S, f, x, y0, v if t <= hit_tick else 3000.0, 0.0)
		if t == hit_tick:
			evs.append(VfxMock.building_hit(S, bi, 1.0, 0.0, v, 1, 1, outcome, 0))
			if outcome == "collapse":
				_fell(S, bi)
				evs.append(VfxMock.building_fall(S, bi, "burst", 0.0, b.x))
		_tick(S, evs)
		if t == hit_tick:
			# Camera's hold: the sim is frozen for 21 ticks; the effects run a tenth as fast.
			for k in range(21):
				_tick(S, [], true)
				if k == 1 or k == 8 or k == 20:
					_frame(S, b.x, y0, zoom)
					await _save("%s_a_hold%02d" % [tag, k])
		elif after.has(t - hit_tick):
			_frame(S, b.x + 200.0, y0, zoom)
			await _save("%s_%s" % [tag, after[t - hit_tick]])
	# And the whole tower, from far.
	_frame(S, b.x, g + b.h * 0.3, minf(0.5, 0.6 * float(size.y) / maxf(b.h, 1.0)))
	await _save("%s_wide" % tag)


## Three towers in a row: through the first, the second, the third, with the tunnel between.
func _play_chain() -> void:
	var S: SimState = _fresh()
	var ch: Array = _pick(S, 3)
	var v: float = 9000.0
	var b0 = S.buildings[ch[0]]
	var g0: float = WorldTerrain.groundY(S, b0.x)
	var y0: float = g0 + b0.h * 0.4
	var x0: float = b0.x - b0.w * 0.5 - 3000.0
	var f = S.fighters[0]
	_park(S, x0 - 300.0)
	# Arrival ticks at each building's near wall, and the tick each falls.
	var arrive: Array = []
	var leave: Array = []
	for k in range(3):
		var bk = S.buildings[ch[k]]
		arrive.append(int((SimWrap.sdx(x0, bk.x) - bk.w * 0.5) / (v * DT)))
		leave.append(int((SimWrap.sdx(x0, bk.x) + bk.w * 0.5) / (v * DT)))
	var end_tick: int = leave[2] + 90
	var marks: Dictionary = {arrive[0] + 3: "a_first", leave[0] + 6: "b_tunnel", arrive[1] + 4: "c_second", leave[1] + 6: "d_between", arrive[2] + 4: "e_third", leave[2] + 8: "f_out", leave[2] + 40: "g_dust"}
	for t in range(end_tick):
		var evs: Array = []
		var xx: float = x0 + v * DT * float(t)
		_fly(S, f, xx, y0, v, 0.0)
		for k in range(3):
			if t == arrive[k]:
				evs.append(VfxMock.building_hit(S, ch[k], 1.0, 0.0, v * (1.0 - 0.15 * float(k)), k + 1, 3, "collapse", 0))
			if t == leave[k]:
				_fell(S, ch[k])
				evs.append(VfxMock.building_fall(S, ch[k], "burst", 0.0, S.buildings[ch[k]].x))
				if k < 2:
					evs.append(VfxMock.chain_link(S, ch[k], ch[k + 1], v, k + 1))
		_tick(S, evs)
		if marks.has(t):
			_frame(S, f.x + 500.0, f.y, zoom)
			await _save("chain_" + marks[t])
	var bl = S.buildings[ch[1]]
	_frame(S, bl.x, g0 + bl.h * 0.3, 0.09)
	await _save("chain_wide")


## A blast levels a block: each building falls straight down, rippling out from the blast centre.
func _play_implode() -> void:
	var S: SimState = _fresh()
	var ch: Array = _pick(S, 8)
	var cx: float = S.buildings[ch[ch.size() / 2]].x
	var f = S.fighters[0]
	_park(S, cx - 4000.0)
	f.x = SimWrap.wrap(cx)
	f.y = WorldTerrain.groundY(S, cx) + 600.0
	f.state = "free"
	var evs: Array = []
	for bi in ch:
		var d: float = absf(SimWrap.sdx(cx, S.buildings[bi].x))
		var delay: float = clampf(d / 1000.0, 0.0, 1.0)
		evs.append(VfxMock.building_fall(S, bi, "implode", delay, cx))
	# The sim's state falls in the same tick; the ripple is cosmetic (docs/world/buildings-in-depth.md 4c).
	for bi in ch:
		_fell(S, bi)
	var marks: Dictionary = {4: "a_first", 20: "b_ripple", 40: "c_mid", 70: "d_col", 120: "e_settle", 200: "f_late"}
	var g: float = WorldTerrain.groundY(S, cx)
	for t in range(240):
		_tick(S, evs if t == 0 else [])
		if marks.has(t):
			_frame(S, cx, g + 700.0, 0.2 if t < 60 else 0.09)
			await _save("implode_" + marks[t])


## A beam skimming the ground: a scorch event every 36 * WS units along 20 ticks of beam, once per variant.
func _play_embers() -> void:
	main.host.vfx.embers_enabled = true
	var c: float = SimWrap.wrap(2250.0 * SimConst.PS)
	for v in ["GLASS TRENCH", "FIRESTORM", "HORIZON CLEAVE", "MERIDIAN SCAR"]:
		var S: SimState = _fresh()
		_park(S, c - 400.0)
		S.fighters[0].x = SimWrap.wrap(c - 1200.0)
		S.fighters[0].y = WorldTerrain.groundY(S, c) + 300.0
		for t in range(40):
			var evs: Array = []
			for k in range(4):
				var x: float = c - 900.0 + float(t * 4 + k) * 36.0 * SimConst.WS * 0.08
				evs.append(VfxMock.ev("scorch", {"x": x, "y": WorldTerrain.groundY(S, x), "w": 200.0, "power": 3.0, "variant": v, "owner": 0}))
			_tick(S, evs)
			if t == 38:
				_frame(S, c - 200.0, S.fighters[0].y - 150.0, 0.5)
				await _save("embers_" + v.replace(" ", "_"))
