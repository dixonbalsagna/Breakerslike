extends SceneTree
## Posed screenshots of the ground cracks. On a fresh match it stages ground damage with World's own functions
## (WorldCrater.dig, WorldSlide.begin and .step) on a fixed state, lets VFX turn the sim's records into crack sets,
## builds and draws them, and saves a picture per pose. Needs a window (not --headless).
##   godot --path . --script res://render/vfx/tools/crack_shots.gd -- --out=DIR [--only=impact_big,slide_paved]
##       [--size=1280x720] [--novfx] [--seed=1]

## name: [centre x on the original planet (scaled by PS), kind, energy, fighter y above ground]
const POSES: Dictionary = {
	"impact_small": [2250.0, "impact", 1.5, 120.0],
	"impact_mid": [2250.0, "impact", 5.0, 200.0],
	"impact_big": [2250.0, "impact", 14.0, 300.0],
	"impact_special": [2250.0, "special", 30.0, 400.0],
	"powerup": [2250.0, "powerup", 4.0, 150.0],
	"slide_paved": [2960.0, "slide", 3.0, 60.0],
	"slide_earth": [2250.0, "slide", 3.0, 60.0],
}

var main: Node
var out: String = "."
var only: Array = []
var novfx: bool = false
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
		elif a.begins_with("--seed="):
			seed = int(a.substr(7))
		elif a == "--novfx":
			novfx = true
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
	main.host.vfx.auto_quality = false
	main.host.vfx.cracks_enabled = true
	main.host.vfx.enabled = not novfx
	for pose_name in POSES:
		if only.size() and not (pose_name in only):
			continue
		main.start_match(seed)
		var S: SimState = main.host.S
		var P: Array = POSES[pose_name]
		var c: float = SimWrap.wrap(P[0] * SimConst.PS)
		var g: float = WorldTerrain.groundY(S, c)
		var A = S.fighters[1]
		var f = S.fighters[0]
		match P[1]:
			"impact":
				WorldCrater.dig(S, c, P[2], A, "impact", 0.3, 1.0)
			"special":
				WorldCrater.dig(S, c, P[2], A, "impact", 0.0, 1.0)
				if S.craters.size() > 0 and S.craters[-1].get("special") != null:
					S.craters[-1].special = true
			"powerup":
				WorldCrater.dig(S, c, P[2], A, "powerup")
			"slide":
				f.x = c
				f.state = "launched"
				f.y = WorldTerrain.groundY(S, c)
				f.vx = 1800.0
				f.vy = 0.0
				WorldSlide.begin(S, f, A, 1800.0, P[2])
				for k in range(600):
					if f.slide <= 0.0:
						break
					WorldSlide.step(S, f, SimConst.DT)
		# Both fighters near the damage, for the camera.
		var span: float = 700.0 if P[1] != "slide" else 500.0
		var off: float = 0.0
		if P[1] != "slide" and S.craters.size() > 0:
			# Stand just outside the rim, one fighter each side of a point past it, so the camera looks at the cracks.
			off = S.craters[-1].r * 1.3
			span = 350.0
		S.fighters[0].x = SimWrap.wrap(c + off - span)
		S.fighters[1].x = SimWrap.wrap(c + off + span)
		for i in range(2):
			var ff = S.fighters[i]
			ff.state = "free"
			ff.slide = 0.0
			ff.vx = 0.0
			ff.vy = 0.0
			ff.y = WorldTerrain.groundY(S, ff.x) + P[3]
			ff.face = 1.0 if i == 0 else -1.0
		S.out.fx.clear()
		var t := SimState.FxEvent.new()
		t.type = "tick"
		t.dt = SimConst.DT
		t.frozen = false
		main.host.vfx.consume(S, [t])
		S.T += 2.0    # the web is grown by now
		var vp: Vector2 = main.get_viewport().get_visible_rect().size
		for k in range(300):
			main.host.follow(vp.x, vp.y)
		for k in range(4):
			main.render_view(1.0)
			await RenderingServer.frame_post_draw
		var path: String = "%s/crack_%s%s.png" % [out, pose_name, "_off" if novfx else ""]
		main.get_viewport().get_texture().get_image().save_png(path)
		var sets: Array = main.host.vfx.crack_sets
		var tris: int = 0
		var fis: int = 0
		for cs in sets:
			tris += cs.tris
			fis += cs.fissures
		_dump(S)
		print("saved %s (zoom %.3f) crack sets %d, %d triangles, %d fissures, mesh builds %d in %.2f ms" % [path, main.host.cam.z, sets.size(), tris, fis, main.host.vfx.crack_builds, main.host.vfx.crack_build_usec / 1000.0])
	quit()


## Debug: what the crack view holds for the first pane.
func _dump(S: SimState) -> void:
	var cv = main.panes[0].vfx_layer.crack_view
	print("  crack view: visible %d, visible flag %s, built now %d" % [cv.visible_count, str(cv.visible), cv.built_now])
	for cs in main.host.vfx.crack_sets:
		var c = S.craters[-1] if S.craters.size() > 0 else null
		print("  set kind %d x %.1f reach %.1f tris %d mesh %s" % [cs.kind, cs.x, cs.reach, cs.tris, str(cs.mesh != null)])
		if cs.mesh != null:
			print("  mesh aabb %s" % [str(cs.mesh.get_aabb())])
		if c != null:
			print("  crater x %.1f r %.1f E %.2f depth %.1f rim %.1f" % [c.x, c.r, c.energy, c.depth, c.rim])
	for k in cv._items:
		var mi = cv._items[k]
		print("  item %s pos %s visible %s" % [str(k), str(mi.position), str(mi.visible)])
