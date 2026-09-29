extends Node
## The game's main scene with the dynamic split screen switched on (docs/camera/split-screen.md). It instances
## Rendering's main scene (render/main.tscn), adds a SplitView beneath UI's HUD and attaches it, so the panes split as
## the design says. Command-line options go to the main scene as usual (--seed=N, --human, --frames=N, --bench, --shot=...);
## --nosplit starts with one view (the reference camera).
##
##   godot --path . res://render/camera/split_main.tscn
##
## F9 toggles the split, F10 solo against the AI (split like two players, or follow the human alone), F11 reduced motion.
## Until Rendering adopts these few lines in main.gd (or makes this the main scene), main.tscn alone stays one view.

var main: Node
var view: SplitView
var _last_usec: int = 0
var _frames: int = 0
var _two_ms := PackedFloat64Array()     # wall-clock frame times while two full panes are up
var _one_ms := PackedFloat64Array()     # ... and otherwise (one view, opening, closing, expanded)
var _published: bool = false


func _ready() -> void:
	main = load("res://render/main.tscn").instantiate()
	add_child(main)
	view = SplitView.new()
	main.add_child(view)
	if not OS.get_cmdline_user_args().has("--nosplit"):
		view.attach(main)


## With --bench, frame times are split by whether two full panes were being drawn (printed at exit as SPLITBENCH).
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _last_usec > 0 and _frames >= 60 and OS.get_cmdline_user_args().has("--bench"):
		var ms: float = float(now - _last_usec) / 1000.0
		var fr: SplitFrame = main.split_frame
		if fr != null and fr.sep > 0.99 and fr.e < 0.01:
			_two_ms.append(ms)
		else:
			_one_ms.append(ms)
	_last_usec = now
	_frames += 1
	# On the web the page never quits: publish the result for a browser driver (window.__splitBench) just before main's last frame.
	var args: Dictionary = main.args
	if OS.has_feature("web") and args.has("bench") and not _published and args.has("frames") and int(main.frames) >= int(args["frames"]) - 1:
		_published = true
		var all := PackedFloat64Array()
		all.append_array(_two_ms)
		all.append_array(_one_ms)
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var res: Dictionary = {
			"head": "%s | %s | %dx%d | split %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), int(vp.x), int(vp.y), str(view.is_attached())],
			"all": _dist(all), "two_panes": _dist(_two_ms), "other": _dist(_one_ms), "two_pane_share": float(_two_ms.size()) / maxf(1.0, float(all.size())),
			"frames": all.size(), "hash": SimHash.stateHash(main.host.S).gameplay, "ticks": main.host.ticks,
		}
		JavaScriptBridge.eval("window.__splitBench = %s;" % JSON.stringify(res), true)


func _exit_tree() -> void:
	if _two_ms.size() + _one_ms.size() == 0:
		return
	print("SPLITBENCH two panes %d frames (%.0f%%): %s" % [_two_ms.size(), 100.0 * _two_ms.size() / float(_two_ms.size() + _one_ms.size()), _dist(_two_ms)])
	print("SPLITBENCH other frames %d: %s" % [_one_ms.size(), _dist(_one_ms)])


static func _dist(v: PackedFloat64Array) -> String:
	if v.is_empty():
		return "n/a"
	var s: Array = Array(v)
	s.sort()
	var sum: float = 0.0
	for x in s:
		sum += x
	return "mean %.3f  p50 %.3f  p95 %.3f  p99 %.3f  max %.3f" % [sum / s.size(), s[s.size() / 2], s[int(s.size() * 0.95)], s[int(s.size() * 0.99)], s[-1]]


func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var handled: bool = true
	match e.physical_keycode:
		KEY_F9:
			if view.is_attached():
				view.detach()
			else:
				view.attach(main)
		KEY_F10:
			view.set_solo_split(not main.split_rig.solo_split)
		KEY_F11:
			view.set_reduced_motion(not main.split_rig.reduced_motion)
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()
