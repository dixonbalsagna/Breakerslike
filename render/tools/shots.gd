extends SceneTree
## Posed screenshots for the rendering docs. The fighters are placed at fixed spots on a fresh match and no ticks
## run, so the pictures don't change when the sim's behaviour does. Some poses also stage world damage on that
## fixture state with World's own functions (WorldCrater.dig and .scorch, WorldWater.step), and feed the fx events
## that produces to the render-side consumers. The reference camera settles on the fighters, and the real scene
## renders one frame per pose. Needs a window (not --headless).
##   godot --path . --script res://render/tools/shots.gd -- --out=DIR [--size=1280x720] [--only=village,wide]

## name: [ax, ay, bx, by]
const POSES: Dictionary = {
	"village": [900.0, 30.0, 2400.0, 30.0],
	"city": [2960.0, 60.0, 3260.0, 320.0],
	"wide": [2350.0, 20.0, 4550.0, 900.0],
	"high": [5000.0, 2250.0, 5260.0, 2450.0],
	"climb": [2900.0, 20.0, 3300.0, 2300.0],
	"craters": [1850.0, 40.0, 2650.0, 260.0],
	"lake": [1120.0, 10.0, 1480.0, 70.0],
}

var main: Node
var out: String = "."
var only: Array = []


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
	for pose_name in POSES:
		if only.size() and not (pose_name in only):
			continue
		main.start_match(1)
		var S: SimState = main.host.S
		var p: Array = POSES[pose_name]
		for i in range(2):
			var f = S.fighters[i]
			f.x = p[i * 2]
			f.y = p[i * 2 + 1]
			f.face = 1.0 if i == 0 else -1.0
		if has_method("_stage_" + pose_name):
			call("_stage_" + pose_name, S)
		var vp: Vector2 = main.get_viewport().get_visible_rect().size
		for k in range(300):
			main.host.follow(vp.x, vp.y)
		main.render_view(1.0)
		await RenderingServer.frame_post_draw
		main.render_view(1.0)
		await RenderingServer.frame_post_draw
		var path: String = "%s/%s.png" % [out, pose_name]
		main.get_viewport().get_texture().get_image().save_png(path)
		print("saved %s (zoom %.3f, camera y %.0f)" % [path, main.host.cam.z, main.host.cam.y])
	quit()


## A straight-down hit, a glancing hit with its furrow, and a strong beam's trail ending in its strike crater.
func _stage_craters(S: SimState) -> void:
	var A = S.fighters[1]
	WorldCrater.dig(S, 2080.0, 8.0, A, "impact", 0.1, 1.0)
	WorldCrater.dig(S, 2330.0, 5.0, A, "impact", 0.92, 0.35)
	var x: float = 2420.0
	while x < 2760.0:
		WorldCrater.scorch(S, x, 4.2, "MERIDIAN SCAR", A)
		x += 30.0
	WorldCrater.dig(S, 2780.0, WorldCrater.beamStrikeEnergy(4.2), A, "beam")
	_feed(S, 18)


## A big crater at the coast that the sea floods, with a splash on the new lake.
func _stage_lake(S: SimState) -> void:
	WorldCrater.dig(S, 1290.0, 25.0, S.fighters[1], "impact", 0.2, 1.0)
	for k in range(1400):
		WorldWater.step(S)
	S.out.fx.clear()
	SimFx.splash(S, 1270.0, WorldWater.surfaceAt(S, 1270.0), 14)
	_feed(S, 20)


## Pass the staged events to the render-side consumers, then let their effects run for n ticks.
func _feed(S: SimState, n: int) -> void:
	var host = main.host
	for k in range(n):
		var t := SimState.FxEvent.new()
		t.type = "tick"
		t.dt = SimConst.DT
		S.out.fx.append(t)
		host.fxv.consume(S, S.out.fx)
		if host.get("impact") != null:
			host.impact.consume(S, S.out.fx)
		S.out.fx.clear()
