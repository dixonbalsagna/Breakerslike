extends SceneTree
## Posed screenshots for the rendering docs. The fighters are placed at fixed spots on a fresh match and no ticks
## run, so the pictures don't change when the sim's behaviour does. Some poses also stage world damage on that
## fixture state with World's own functions (WorldCrater.dig and .scorch, WorldWater.step), and feed the fx events
## that produces to the render-side consumers. The reference camera settles on the fighters, and the real scene
## renders one frame per pose. Needs a window (not --headless).
##   godot --path . --script res://render/tools/shots.gd -- --out=DIR [--size=1280x720] [--only=village,wide]

## name: [ax, ay, bx, by] on the original planet (W = 9,600, ceiling 2,600). _place() maps them to the current scale:
## the pair's centre along the planet scales by PS, their separation stays at fighter scale, heights above 600 scale
## with the flight ceiling; staged damage positions scale by PS (see X()).
const POSES: Dictionary = {
	"village": [900.0, 30.0, 2400.0, 30.0],
	"city": [2960.0, 60.0, 3260.0, 320.0],
	"wide": [2350.0, 20.0, 4550.0, 900.0],
	"high": [5000.0, 2250.0, 5260.0, 2450.0],
	"climb": [2900.0, 20.0, 3300.0, 2300.0],
	"craters": [2100.0, 40.0, 2400.0, 260.0],
	"lake": [1185.0, 10.0, 1255.0, 70.0],
	"coast": [1130.0, 60.0, 1420.0, 170.0],
	"max": [2700.0, 2600.0, 3150.0, 2600.0],
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
		var p: Array = _place(POSES[pose_name])
		for i in range(2):
			var f = S.fighters[i]
			f.x = SimWrap.wrap(p[i * 2])
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


static func X(x: float) -> float:
	return x * SimConst.PS


static func Y(y: float) -> float:
	return y if y < 600.0 else y * SimConst.CEILING / 2600.0


static func _place(p: Array) -> Array:
	var c: float = X((p[0] + p[2]) * 0.5)
	var h: float = (p[2] - p[0]) * 0.5
	return [c - h, Y(p[1]), c + h, Y(p[3])]


## A straight-down hit, a glancing hit with its furrow, and a strong beam's trail ending in its strike crater.
func _stage_craters(S: SimState) -> void:
	var A = S.fighters[1]
	var c: float = X(2250.0)
	WorldCrater.dig(S, c - 170.0 * SimConst.WS, 1.0, A, "impact", 0.1, 1.0)
	WorldCrater.dig(S, c + 80.0 * SimConst.WS, 0.6, A, "impact", 0.92, 0.35)
	var x: float = c + 170.0 * SimConst.WS
	while x < c + 510.0 * SimConst.WS:
		WorldCrater.scorch(S, x, 4.2, "MERIDIAN SCAR", A)
		x += 30.0 * SimConst.WS
	WorldCrater.dig(S, x + 20.0 * SimConst.WS, 1.5, A, "beam")
	_feed(S, 18)


## A big crater at the coast that the sea floods, with a splash on the new lake.
func _stage_lake(S: SimState) -> void:
	var c: float = X(1200.0) + 900.0
	WorldCrater.dig(S, c, 3.0, S.fighters[1], "impact", 0.2, 1.0)
	for k in range(1400):
		WorldWater.step(S)
	S.out.fx.clear()
	SimFx.splash(S, c - 300.0, WorldWater.surfaceAt(S, c - 300.0), 14)
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
