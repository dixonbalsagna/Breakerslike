extends SceneTree
## Motion reel: raw RGB frames of a real seeded AI match, cropped around the fighters, for judging the mannequin's
## timing in motion (docs/animation/pose-pipeline.md section 6.5). The gameplay is identical for every style, so two runs
## of the same seed line up frame for frame. tools/gif.mjs turns the raw files into GIFs (one, or two side by side).
## Needs a window (not --headless).
##   godot --path . --script res://render/anim/tools/anim_reel.gd -- --out=reel.rgb [--seed=4] [--from=730] [--count=150]
##       [--step=2] [--style=snappy] [--crop=220x140] [--scale=2]
## Output: a 12-byte header (width, height, frames as little-endian int32) then width*height*3 bytes a frame.

const DT := 1.0 / 60.0

var out: String = "reel.rgb"
var seed_: int = 4
var from_tick: int = 730
var count: int = 150
var step: int = 2
var style: String = ""
var crop := Vector2i(220, 140)
var scale: int = 2
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--seed="):
			seed_ = int(a.substr(7))
		elif a.begins_with("--from="):
			from_tick = int(a.substr(7))
		elif a.begins_with("--count="):
			count = int(a.substr(8))
		elif a.begins_with("--step="):
			step = int(a.substr(7))
		elif a.begins_with("--style="):
			style = a.substr(8)
		elif a.begins_with("--scale="):
			scale = int(a.substr(8))
		elif a.begins_with("--crop="):
			var p: PackedStringArray = a.substr(7).split("x")
			crop = Vector2i(int(p[0]), int(p[1]))
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


func _run() -> void:
	await process_frame
	main.start_match(seed_, {"p1": true, "p2": true})
	while main.host.ticks < from_tick:
		main.frame(DT)
	var fa := FileAccess.open(out, FileAccess.WRITE)
	fa.store_32(crop.x * scale)
	fa.store_32(crop.y * scale)
	fa.store_32(count)
	var cx: float = -1.0
	var cy: float = -1.0
	for n in range(count * step):
		main.frame(DT)
		if n % step != 0:
			continue
		await process_frame
		var img: Image = main.get_viewport().get_texture().get_image()
		var pw = main.panes[0]
		var r0: Rect2 = pw._screen_rect(main.fighter_views[0])
		var r1: Rect2 = pw._screen_rect(main.fighter_views[1])
		var c0: Vector2 = r0.get_center()
		var c1: Vector2 = r1.get_center()
		var c: Vector2 = (c0 + c1) * 0.5
		if c0.distance_to(c1) > float(crop.x) * 0.8:
			c = c0 if absf(c0.x - cx) < absf(c1.x - cx) else c1
		# smooth the crop centre so the frame does not jump
		if cx < 0.0:
			cx = c.x
			cy = c.y
		cx = lerpf(cx, c.x, 0.35)
		cy = lerpf(cy, c.y, 0.35)
		var x0: int = clampi(int(cx) - crop.x / 2, 0, img.get_width() - crop.x)
		var y0: int = clampi(int(cy) - crop.y / 2, 0, img.get_height() - crop.y)
		var tile: Image = img.get_region(Rect2i(x0, y0, crop.x, crop.y))
		tile.resize(crop.x * scale, crop.y * scale, Image.INTERPOLATE_NEAREST)
		tile.convert(Image.FORMAT_RGB8)
		fa.store_buffer(tile.get_data())
	fa.close()
	print("REEL ", out, " ", count, " frames ", crop.x * scale, "x", crop.y * scale)
	quit()
