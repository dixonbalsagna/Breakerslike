extends SceneTree
## What the HUD costs in the live build. It runs Rendering's main scene and alternates blocks of frames with the UI HUD
## shown and hidden (the sim, the events and the HUD's own model run identically in both; only drawing differs), and
## reports the difference in wall time per frame, in the engine's measured render time (CPU and GPU) and in draw calls,
## for all frames and for "rest" frames (no crown, card, bark or banner showing). It also times UiHud.advance() alone.
##
## Run (a window opens; vsync is turned off so frame time is the true cost):
##   godot --path . --fixed-fps 60 --resolution 1280x720 --script res://ui/tools/hud_bench.gd -- --seed=4 --blocks=4 --block=300
## Add --force to redraw every layer every frame (the cost without caching); --legacy for Rendering's old greybox HUD.

var main: Node
var args: Dictionary = {}
var frame: int = 0
var warm: int = 240
var block: int = 300
var blocks: int = 4
var last_usec: int = 0
var rows: Array = []      # {shown, rest, wall, cpu, gpu, draws}
var done: bool = false
var legacy: bool = false
var forced: bool = false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	block = int(args.get("block", 300))
	blocks = int(args.get("blocks", 4))
	legacy = args.has("legacy")
	forced = args.has("force")
	UiIcons.unguarded = args.has("rawpolys")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	main = load("res://render/main.tscn").instantiate()
	root.add_child(main)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)


func _process(_delta: float) -> bool:
	var now: int = Time.get_ticks_usec()
	var wall: float = float(now - last_usec) / 1000.0 if last_usec > 0 else 0.0
	last_usec = now
	frame += 1
	if done:
		return false
	var hud = main.get("ui_hud")
	if frame == 2 and forced:
		hud.set_option("force_redraw", true)
	if frame == 2 and legacy:
		hud.visible = false
		main.set("legacy_hud", true)
		main.hud.legacy = true
	if frame > warm:
		var idx: int = (frame - warm - 1) / block
		var shown: bool = idx % 2 == 0
		if legacy:
			main.hud.visible = shown
		else:
			hud.visible = shown
		if frame - warm > 3:
			var rid: RID = root.get_viewport_rid()
			var rest := true
			for m in hud.hub.models:
				if m.crown_a > 0.01 or m.parry_t >= 0.0 or m.chain_t >= 0.0:
					rest = false
			if not hud.hub.cards.is_empty() or not hud.hub.barks.is_empty() or not hud.hub.banner.is_empty() or hud.hub.world_card != null:
				rest = false
			rows.append({"shown": shown, "rest": rest, "split": float(hud._split.get("sep", 0.0)) > 0.5, "wall": wall,
				"cpu": RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu(),
				"gpu": RenderingServer.viewport_get_measured_render_time_gpu(rid),
				"draws": float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))})
		if idx >= blocks:
			done = true
			_report()
			quit()
	return false


func _mean(sel: Array, key: String) -> float:
	if sel.is_empty():
		return 0.0
	var s := 0.0
	for r in sel:
		s += float(r[key])
	return s / float(sel.size())


func _report() -> void:
	var on: Array = rows.filter(func(r): return r.shown)
	var off: Array = rows.filter(func(r): return not r.shown)
	var on_rest: Array = on.filter(func(r): return r.rest)
	var on_split: Array = on.filter(func(r): return r.split)
	var on_merged: Array = on.filter(func(r): return not r.split)
	print("HUDBENCH %s | %s | frames shown %d hidden %d, of the shown %d are rest (%.0f%%)" % [("legacy HUD" if legacy else "UI HUD"), RenderingServer.get_video_adapter_name(), on.size(), off.size(), on_rest.size(), 100.0 * float(on_rest.size()) / maxf(1.0, float(on.size()))])
	print("HUDBENCH            wall ms   render cpu ms   render gpu ms   draw calls")
	print("HUDBENCH hidden     %7.3f   %13.3f   %13.3f   %10.1f" % [_mean(off, "wall"), _mean(off, "cpu"), _mean(off, "gpu"), _mean(off, "draws")])
	print("HUDBENCH shown      %7.3f   %13.3f   %13.3f   %10.1f" % [_mean(on, "wall"), _mean(on, "cpu"), _mean(on, "gpu"), _mean(on, "draws")])
	print("HUDBENCH shown rest %7.3f   %13.3f   %13.3f   %10.1f" % [_mean(on_rest, "wall"), _mean(on_rest, "cpu"), _mean(on_rest, "gpu"), _mean(on_rest, "draws")])
	print("HUDBENCH shown split (%d frames) %7.3f   %8.3f   %8.3f   %6.1f    merged (%d) %7.3f   %8.3f   %8.3f   %6.1f" % [on_split.size(), _mean(on_split, "wall"), _mean(on_split, "cpu"), _mean(on_split, "gpu"), _mean(on_split, "draws"), on_merged.size(), _mean(on_merged, "wall"), _mean(on_merged, "cpu"), _mean(on_merged, "gpu"), _mean(on_merged, "draws")])
	print("HUDBENCH cost (all)  %+7.3f   %+13.3f   %+13.3f   %+10.1f" % [_mean(on, "wall") - _mean(off, "wall"), _mean(on, "cpu") - _mean(off, "cpu"), _mean(on, "gpu") - _mean(off, "gpu"), _mean(on, "draws") - _mean(off, "draws")])
	print("HUDBENCH cost (rest) %+7.3f   %+13.3f   %+13.3f   %+10.1f" % [_mean(on_rest, "wall") - _mean(off, "wall"), _mean(on_rest, "cpu") - _mean(off, "cpu"), _mean(on_rest, "gpu") - _mean(off, "gpu"), _mean(on_rest, "draws") - _mean(off, "draws")])
	if not legacy:
		var hud = main.get("ui_hud")
		var t0: int = Time.get_ticks_usec()
		for i in range(600):
			hud.advance(0.0)
		print("HUDBENCH UiHud.advance() alone: %.3f ms per call (signatures only)" % (float(Time.get_ticks_usec() - t0) / 600.0 / 1000.0))
		print("HUDBENCH layer redraws so far: %d over %d frames" % [hud.redraw_count(), frame])
