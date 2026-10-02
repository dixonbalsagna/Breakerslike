extends SceneTree
## The real opening (docs/architecture/intro-phase.md): a match started with the setup's "intro": true, stepped through the game's own scene so the sim's state and events,
## Camera's shots and the mannequin all run as in play, recorded as raw RGB frames for tools/gif.mjs (the whole 300 ticks, then 20 more). Needs a window.
##   godot --path . --script res://render/anim/tools/intro_real.gd -- [--out=intro_real.rgb] [--seed=4] [--step=2] [--size=640x360] [--skip=N] [--reduced] [--nointro]
## --skip=N presses a button at tick N (the host's skip); --nointro switches the opening's poses off for the before.

const DT := 1.0 / 60.0
var out: String = "intro_real.rgb"
var seed_: int = 4
var step: int = 2
var size := Vector2i(640, 360)
var skip_at: int = -1
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--seed="):
			seed_ = int(a.substr(7))
		elif a.begins_with("--step="):
			step = int(a.substr(7))
		elif a.begins_with("--size="):
			var p: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--skip="):
			skip_at = int(a.substr(7))
		elif a == "--reduced":
			RenderAnim.reduced_motion = true
		elif a == "--nointro":
			RenderAnim.intro_poses = false
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
	main.start_match(seed_, {"p1": false, "p2": false}, {"intro": true})
	var fa := FileAccess.open(out, FileAccess.WRITE)
	fa.store_32(size.x)
	fa.store_32(size.y)
	fa.store_32(0)
	var n: int = 0
	for i in range(332):
		if skip_at >= 0 and i == skip_at:
			main.host.skip_intro()
		main.frame(DT)
		if i % step != 0:
			continue
		await process_frame
		var img: Image = main.get_viewport().get_texture().get_image()
		img.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
		img.convert(Image.FORMAT_RGB8)
		fa.store_buffer(img.get_data())
		n += 1
	fa.seek(8)
	fa.store_32(n)
	fa.close()
	print("INTRO REAL ", out, " ", n, " frames ", size.x, "x", size.y)
	quit(0)
