extends SceneTree
## Filmstrip of a real exchange in the real scene: it runs a seeded AI match until a melee exchange with a blow starts,
## then saves cropped frames around the two fighters every few ticks, so the mannequin's timing can be judged as a strip
## (docs/animation/pose-pipeline.md section 6.5). Needs a window (not --headless).
##   godot --path . --script res://render/anim/tools/anim_strip.gd -- --out=strip.png [--seed=4] [--nth=1] [--style=snappy]
##       [--step=3] [--count=16] [--skip=0] [--cols=4] [--scale=2] [--crop=300x200] [--noanim]
## --nth picks the n-th such exchange of the match. The strip's row 1 is the start of the exchange.

const DT := 1.0 / 60.0

var out: String = "strip.png"
var seed_: int = 4
var nth: int = 1
var style: String = ""
var step: int = 3
var count: int = 16
var skip: int = 0
var cols: int = 4
var scale: int = 2
var crop := Vector2i(300, 200)
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--seed="):
			seed_ = int(a.substr(7))
		elif a.begins_with("--nth="):
			nth = int(a.substr(6))
		elif a.begins_with("--style="):
			style = a.substr(8)
		elif a.begins_with("--step="):
			step = int(a.substr(7))
		elif a.begins_with("--skip="):
			skip = int(a.substr(7))
		elif a.begins_with("--count="):
			count = int(a.substr(8))
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
		elif a.begins_with("--scale="):
			scale = int(a.substr(8))
		elif a.begins_with("--crop="):
			var p: PackedStringArray = a.substr(7).split("x")
			crop = Vector2i(int(p[0]), int(p[1]))
		elif a == "--noanim":
			RenderAnim.enabled = false
	RenderAnim.style_override = style
	DirData.templatesProfile = "dynamic"
	var vpn := SubViewport.new()
	vpn.size = Vector2i(1280, 720)
	vpn.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _has_blow(ex) -> bool:
	for b in ex.beats:
		if b.op == "strike":
			return true
	return false


func _run() -> void:
	await process_frame
	main.start_match(seed_, {"p1": true, "p2": true})
	var S: SimState = main.host.S
	var seen: int = 0
	var last_n: int = -1
	var guard: int = 0
	while guard < 20000:
		guard += 1
		main.frame(DT)
		var ex = S.dirS.ex
		if ex != null and int(ex.n) != last_n and ex.kind != "sig" and _has_blow(ex) and ex.t < 0.05:
			last_n = int(ex.n)
			seen += 1
			if seen >= nth:
				break
	print("exchange %d: %s, tick %d, style %s" % [last_n, S.dirS.ex.tag if S.dirS.ex != null else "", main.host.ticks, RenderAnim.style()])
	for _k in range(skip):
		main.frame(DT)
	var dslot: int = S.fighters.find(S.dirS.ex.D) if S.dirS.ex != null else 1
	var tiles: Array = []
	for n in range(count * step):
		main.frame(DT)
		if n % step == 0:
			await process_frame
			var img: Image = main.get_viewport().get_texture().get_image()
			var pw = main.panes[0]
			var r: Rect2 = pw._screen_rect(main.fighter_views[dslot])
			var c: Vector2 = r.get_center()
			var x0: int = clampi(int(c.x) - crop.x / 2, 0, img.get_width() - crop.x)
			var y0: int = clampi(int(c.y) - crop.y / 2, 0, img.get_height() - crop.y)
			var tile: Image = img.get_region(Rect2i(x0, y0, crop.x, crop.y))
			tile.resize(crop.x * scale, crop.y * scale, Image.INTERPOLATE_NEAREST)
			tiles.append(tile)
	var rows: int = int(ceil(tiles.size() / float(cols)))
	var sheet := Image.create_empty(cols * crop.x * scale, rows * crop.y * scale, false, Image.FORMAT_RGBA8)
	for i in range(tiles.size()):
		sheet.blit_rect(tiles[i], Rect2i(0, 0, crop.x * scale, crop.y * scale), Vector2i((i % cols) * crop.x * scale, (i / cols) * crop.y * scale))
	sheet.save_png(out)
	print("STRIP ", out, " ", tiles.size(), " frames")
	quit()
