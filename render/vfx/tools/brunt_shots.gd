extends SceneTree
## Pictures of the real B2 events: it plays real AI-vs-AI matches (the sim's own building_hit, floor_hit, chain_link and
## floors_fall events, through host.vfx) until it has seen a chain of two or more buildings and a floor punch on a
## skyscraper, and saves frames after each, with the camera set by hand on the hit at a gameplay zoom. Needs a window.
##   godot --path . --script res://render/vfx/tools/brunt_shots.gd -- --out=DIR [--seeds=1,2,3,4,5,6,7,8] [--zoom=0.35]
##       [--size=1280x720] [--max-ticks=12000]

var main: Node
var out: String = "."
var seeds: Array = [1, 2, 3, 4, 5, 6, 7, 8]
var zoom: float = 0.35
var size := Vector2i(1280, 720)
var max_ticks: int = 12000
var _seen: Array = []          # events from this tick, filled by the host's drained signal


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
		elif a.begins_with("--size="):
			var wh: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--max-ticks="):
			max_ticks = int(a.substr(12))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vpn := SubViewport.new()
	vpn.size = size
	vpn.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _on_drained(events: Array, _lines: Array) -> void:
	for e in events:
		if e.type in ["building_hit", "floor_hit", "floors_fall", "chain_link"]:
			_seen.append(e)


func _run() -> void:
	await process_frame
	main.started = true
	var h = main.host.vfx
	h.auto_quality = false
	h.destruction_enabled = true
	h.cracks_enabled = true
	main.host.drained.connect(_on_drained)
	var got_chain: bool = false
	var got_floor: bool = false
	var got_fall: bool = false
	for seed in seeds:
		if got_chain and got_floor:
			break
		main.start_match(seed, {"p1": true, "p2": true})
		var S: SimState = main.host.S
		var due: Array = []          # [tick, name, x, y]
		for i in range(max_ticks):
			_seen.clear()
			main.frame(1.0 / 60.0)
			var t: int = main.host.ticks
			for e in _seen:
				var b = S.buildings[int(e.b)] if e.get("b") != null and int(e.b) >= 0 and int(e.b) < S.buildings.size() else null
				if e.type == "building_hit" and int(e.link) == 2 and not got_chain:
					got_chain = true
					for d in [2, 10, 26]:
						due.append([t + d, "chain_%d_t%d" % [seed, d], float(e.x), float(e.y)])
				elif e.type == "floor_hit" and String(e.outcome) == "punch" and not got_floor:
					got_floor = true
					for d in [2, 10, 26]:
						due.append([t + d, "floor_%d_t%d" % [seed, d], float(e.x), float(e.y)])
				elif e.type == "floors_fall" and not got_fall:
					got_fall = true
					for d in [4, 20]:
						due.append([t + d, "pancake_%d_t%d" % [seed, d], float(e.x), WorldTerrain.groundY(S, float(e.x)) + 1200.0])
			for d in due.duplicate():
				if t >= d[0]:
					due.erase(d)
					var vp: Vector2 = main.get_viewport().get_visible_rect().size
					main.host.cam.x = SimWrap.wrap(d[2])
					main.host.cam.y = d[3] + 0.2 * vp.y / zoom
					main.host.cam.z = zoom
					main.host._prev = main.host._capture()
					main.host._cur = main.host._prev
					main.render_view(1.0)
					await RenderingServer.frame_post_draw
					main.render_view(1.0)
					await RenderingServer.frame_post_draw
					var path: String = "%s/%s.png" % [out, d[1]]
					main.get_viewport().get_texture().get_image().save_png(path)
					print("saved %s (tick %d, bits %d, shards %d, puffs %d)" % [path, t, h.debris.bits.size(), main.panes[0].vfx_layer.shard_view.shards, main.panes[0].vfx_layer.shard_view.puffs])
			if (got_chain and got_floor and due.is_empty()) or (S.game.ko != null and S.game.koT > 3.0):
				break
			await process_frame
	print("chain %s, floor punch %s, pancake %s" % [got_chain, got_floor, got_fall])
	quit()
