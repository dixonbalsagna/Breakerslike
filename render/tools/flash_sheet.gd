extends SceneTree
## The head flashes on a contact sheet, for the rendering docs and Art's review: every flash in the data's order
## (columns) in every shape family, then the blades and wedges again with the legacy shapes (F8; rows), each at its
## last pulse's peak on P1's head in the real scene, and a last row on P2, who faces the other way (the flashes mirror
## with it).
## The fighters are posed, no sim ticks run, and time is stepped by hand, so the state machine sees each flash start
## and reach its hold as in play. Needs a window (not --headless).
##   godot --path . --script res://render/tools/flash_sheet.gd -- --out=DIR [--cell=240]

const ROWS: Array = [["P", false], ["A", false], ["E", false], ["C", false], ["A", true], ["E", true], ["A", false, 1]]

var main: Node
var out: String = "."
var cell: int = 240


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--cell="):
			cell = int(a.substr(7))
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
	main.start_match(1)
	var S: SimState = main.host.S
	var c: float = 5900.0 * SimConst.PS
	for i in range(2):
		var f = S.fighters[i]
		f.x = SimWrap.wrap(c + (-130.0 if i == 0 else 130.0))
		f.y = WorldTerrain.groundY(S, f.x) + 60.0
		f.face = 1.0 if i == 0 else -1.0
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	for k in range(300):
		main.host.follow(vp.x, vp.y)
	var ids: Array = FlashSet.ids()
	var sheet := Image.create_empty(cell * ids.size(), cell * ROWS.size(), false, Image.FORMAT_RGBA8)
	var T: float = 10.0
	for r in range(ROWS.size()):
		var who: int = ROWS[r][2] if ROWS[r].size() > 2 else 0
		for ci in range(ids.size()):
			var fv: FlashView = main.fighter_views[who].flash_view
			fv.family = ROWS[r][0]
			fv.legacy = ROWS[r][1]
			fv.cur = ""
			fv._queue.clear()
			fv._cool.clear()
			T += 20.0
			S.T = T
			fv.fire(ids[ci], T, false, 150.0)
			var seq: Dictionary = FlashSet.sequence(ids[ci])
			var pl: Dictionary = FlashSet.pulse(ids[ci])
			var peak: float = (int(pl.get("count", 1)) - 1) * (float(pl.get("on", 0.0)) + float(pl.get("off", 0.0))) + 0.6 * float(pl.get("on", 0.0))
			for t in [0.0, float(seq.get("delay_after_crown_down", 0.0)) + 0.02, peak + float(seq.get("delay_after_crown_down", 0.0)) + 0.02]:
				S.T = T + t
				main.render_view(1.0)
			await RenderingServer.frame_post_draw
			main.render_view(1.0)
			await RenderingServer.frame_post_draw
			var img: Image = main.get_viewport().get_texture().get_image()
			var head: Vector2 = main.cam_rig.unproject_position(main.fighter_views[who].head.global_position)
			var rect := Rect2i(int(head.x) - cell / 2, int(head.y) - cell * 5 / 8, cell, cell)
			sheet.blit_rect(img, rect, Vector2i(ci * cell, r * cell))
		main.fighter_views[who].flash_view.cur = ""
		print("row %d: %s%s" % [r, ROWS[r][0], " legacy" if ROWS[r][1] else (" on P2" if who == 1 else "")])
	sheet.save_png("%s/flash-sheet.png" % out)
	print("columns: ", " ".join(ids))
	quit()
