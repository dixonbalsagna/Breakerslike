extends SceneTree
## Posed pictures for the fight-lanes work (docs/rendering/README.md, "Occlusion", "The camera's pitch" and "The inset
## pane"): the two occlusion methods with one fighter and with both behind a block of towers, the camera's pitch, and
## Camera's inset pane. The sim keeps fighters on the plane until the fight-lanes slices land, so the tool poses a
## fresh match's fighters at depth by hand (its own state, never the game's), runs no ticks and draws the real scene.
## Needs a window (not --headless).
##   godot --path . --script res://render/tools/lanes_shots.gd -- --out=DIR [--size=1280x720] [--s=1] [--only=pair_hole,inset]

## [name, both fighters behind the block, the occlusion method, the camera's pitch in degrees]
const SHOTS: Array = [
	["solo_hole", false, PaneWorld.OCCL_HOLE, 0.0],
	["solo_stub", false, PaneWorld.OCCL_STUB, 0.0],
	["pair_hole", true, PaneWorld.OCCL_HOLE, 0.0],
	["pair_stub", true, PaneWorld.OCCL_STUB, 0.0],
	["pair_hole_p11", true, PaneWorld.OCCL_HOLE, 11.0],
	["pair_stub_p11", true, PaneWorld.OCCL_STUB, 11.0],
	["pair_hole_p49", true, PaneWorld.OCCL_HOLE, 49.0],
	["pair_stub_p49", true, PaneWorld.OCCL_STUB, 49.0],
]
const BEHIND: float = 220.0     # how far behind the block's back faces the fighters stand
const INSET := Vector2i(320, 180)


## A stand-in for Camera's compositor with an inset: the split's own compositor, plus the inset's camera.
class InsetCompositor extends RefCounted:
	var view: SplitView
	var cam: Dictionary = {}

	func pane_jitter(i: int) -> Vector2:
		return view.pane_jitter(i)

	func present(fr) -> void:
		view.present(fr)

	func inset_view(_a: float) -> Dictionary:
		return cam


var main: Node
var out: String = "."
var only: Array = []
var seed: int = 1


func _initialize() -> void:
	var size := Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--size="):
			var wh: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--only="):
			only = Array(a.substr(7).split(","))
		elif a.begins_with("--s="):
			seed = int(a.substr(4))
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
	main.started = true   # no take-over prompt in the pictures
	main.start_match(seed)
	var S: SimState = main.host.S
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var block: int = _block(S)
	if block < 0:
		print("no row-1 tower in this planet's city")
		quit(1)
		return
	print("the block: building %d (x %.0f, z %.0f, %.0f wide, %.0f deep, %.0f tall)" % [block, S.buildings[block].x, S.buildings[block].z, S.buildings[block].w, S.buildings[block].d, WorldStructures.curH(S.buildings[block])])
	for shot in SHOTS:
		if only.size() and not (shot[0] in only):
			continue
		_pose(S, block, shot[1])
		main.occlusion = shot[2]
		main.cam_pitch = shot[3]
		for k in range(300):
			main.host.follow(vp.x, vp.y)
		await _save(shot[0])
		print("%s: occluded %s" % [shot[0], main.pane.occluded])
	if only.is_empty() or "inset" in only:
		await _inset(S, block, vp)
	quit(0)


func _save(name: String) -> void:
	for p in main.all_panes():
		p.snap_occlusion()
	main.render_view(1.0)
	await RenderingServer.frame_post_draw
	main.render_view(1.0)
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


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


## Fighter 0 behind the block (in the street behind row 1); fighter 1 beside him there (pair) or out on the plane.
func _pose(S: SimState, block: int, pair: bool) -> void:
	var b = S.buildings[block]
	var back: float = b.z - b.d * 0.5 - BEHIND
	var at: Array = [[b.x - (260.0 if pair else 0.0), back], [b.x + 260.0, back] if pair else [b.x + 700.0, 0.0]]
	for i in range(2):
		var f = S.fighters[i]
		f.x = SimWrap.wrap(at[i][0])
		f.z = at[i][1]
		f.y = WorldTerrain.groundY(S, f.x) + 70.0
		f.face = 1.0 if i == 0 else -1.0


## The split's compositor with an inset: fighter 0 behind the block in the main view, fighter 1 far off and high in
## the inset, top right.
func _inset(S: SimState, block: int, vp: Vector2) -> void:
	_pose(S, block, false)
	var f1 = S.fighters[1]
	f1.x = SimWrap.wrap(S.buildings[block].x + 1500.0)
	f1.y = WorldTerrain.groundY(S, f1.x) + 900.0
	f1.z = -400.0
	main.occlusion = PaneWorld.OCCL_HOLE
	main.cam_pitch = 0.0
	var view := SplitView.new()
	main.add_child(view)
	view.attach(main)
	var comp := InsetCompositor.new()
	comp.view = view
	main.compositor = comp
	var sv: SubViewport = main.make_inset(INSET)
	main.add_child(sv)
	var frame := ColorRect.new()
	frame.color = Color(0.04, 0.05, 0.08)
	frame.position = Vector2(vp.x - INSET.x - 26.0, 138.0)
	frame.size = Vector2(INSET) + Vector2(4.0, 4.0)
	main.add_child(frame)
	var tr := TextureRect.new()
	tr.texture = sv.get_texture()
	tr.position = frame.position + Vector2(2.0, 2.0)
	main.add_child(tr)
	# The inset's own chase camera: the far fighter at its centre, about 36 px tall.
	var zoom: float = 0.48
	comp.cam = {"cam_x": f1.x, "cam_y": f1.y + FighterView.HEIGHT * 0.5 - 0.2 * INSET.y / zoom, "cam_z": zoom}
	for k in range(300):
		main.host.follow(vp.x, vp.y)
		main.split_rig.step(S, vp.x, vp.y, [])
	await _save("inset")
	print("inset: main pane occluded %s, inset pane occluded %s" % [main.pane.occluded, main.inset.occluded])
