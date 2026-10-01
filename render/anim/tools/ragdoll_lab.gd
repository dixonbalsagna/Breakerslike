extends SceneTree
## Ragdoll lab: a real seeded match runs, and one fighter's mannequin is drawn in a close, fixed side view (centred, turned by
## the sim's rot and mirrored by the visual facing, with a ground line and a velocity tick), so a launch, a tumble, a skid or
## a slam can be judged at full size whatever the match camera does. Raw RGB frames for tools/gif.mjs. Needs a window.
##   godot --path . --script res://render/anim/tools/ragdoll_lab.gd -- --out=a.rgb [--seed=4] [--fighter=1] [--from=205]
##       [--count=140] [--step=1] [--size=220] [--noragdoll] [--reduced]
## --noragdoll draws the same ticks with the overhaul layers off (the before of a before and after); --reduced turns reduced motion on.

const DT := 1.0 / 60.0

var out: String = "lab.rgb"
var seed_: int = 4
var who: int = 1
var from_tick: int = 205
var count: int = 140
var step: int = 1
var size: int = 220
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--seed="):
			seed_ = int(a.substr(7))
		elif a.begins_with("--fighter="):
			who = int(a.substr(10))
		elif a.begins_with("--from="):
			from_tick = int(a.substr(7))
		elif a.begins_with("--count="):
			count = int(a.substr(8))
		elif a.begins_with("--step="):
			step = int(a.substr(7))
		elif a.begins_with("--size="):
			size = int(a.substr(7))
		elif a == "--noragdoll":
			RenderAnim.ragdoll_enabled = false
		elif a == "--reduced":
			RenderAnim.reduced_motion = true
	DirData.templatesProfile = "dynamic"
	var vpn := SubViewport.new()
	vpn.size = Vector2i(640, 360)
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var sv := SubViewport.new()
	sv.size = Vector2i(size, size)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.15, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 150.0
	cam.environment = env
	sv.add_child(cam)
	cam.position = Vector3(0.0, 0.0, 300.0)
	cam.current = true
	var pal: Dictionary = {"body": Color("#3d8fdc"), "legs": Color("#1b1f2a"), "arms": Color("#e6b995"), "skin": Color("#efc7a2"), "gear": Color("#cdd6e4"), "accent": Color("#4fb9a8"), "hair": Color("#22c7a9")}
	var root3 := Node3D.new()
	sv.add_child(root3)
	var pivot := Node3D.new()
	root3.add_child(pivot)
	var body := AnimBody.new()
	body.build(pal, false)
	pivot.add_child(body)
	body.position = Vector3(0.0, -34.0, 0.0)
	var ground := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(400.0, 2.0, 2.0)
	ground.mesh = bm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.35, 0.4, 0.5)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = gm
	sv.add_child(ground)
	ground.position = Vector3(0.0, -50.0, 0.0)
	main.start_match(seed_, {"p1": true, "p2": true})
	var S: SimState = main.host.S
	while main.host.ticks < from_tick:
		main.frame(DT)
	var fa := FileAccess.open(out, FileAccess.WRITE)
	fa.store_32(size)
	fa.store_32(size)
	fa.store_32(count)
	var rows: Array = []
	for n in range(count * step):
		main.frame(DT)
		if n % step != 0:
			continue
		var f = S.fighters[who]
		var af: AnimFighter = RenderAnim.solve(S, f)
		root3.scale = Vector3(af.vface, 1.0, 1.0)
		pivot.rotation.z = -f.rot
		# the body stays centred; on the ground it stands on the line, in the air it floats at the centre
		var h: float = clampf(f.y - WorldTerrain.groundY(S, f.x), 0.0, 60.0)
		pivot.position = Vector3(0.0, -16.0 + minf(h, 40.0) * 0.4, 0.0)
		body.apply(af.q, af.hips, af.curl, af.root_off)
		await process_frame
		await process_frame
		var img: Image = sv.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		fa.store_buffer(img.get_data())
	fa.close()
	print("LAB ", out, " ", count, " frames ", size, "x", size)
	quit()
