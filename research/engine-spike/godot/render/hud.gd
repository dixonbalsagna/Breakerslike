extends CanvasLayer
## Engine spike (throwaway, research only). Small HUD text (fps, frame ms, scene, tick, live particles, hash status)
## plus a marker at the top of the screen where the seam (world x = 0) is. H toggles it. Text is re-laid out at most
## four times a second so the HUD costs next to nothing in bench runs.

@onready var label: Label = $Label
@onready var seam_tick: ColorRect = $SeamTick
@onready var seam_label: Label = $SeamLabel

var _acc_s: float = 0.0
var _frames: int = 0
var _fps: float = 0.0
var _ms: float = 0.0


## frame_s: this frame's duration. info: the lines to show (already formatted), refreshed at 4 Hz.
func tick_frame(frame_s: float, lines: Callable) -> void:
	_acc_s += frame_s
	_frames += 1
	if _acc_s >= 0.25:
		_fps = float(_frames) / _acc_s
		_ms = 1000.0 * _acc_s / float(_frames)
		_acc_s = 0.0
		_frames = 0
		if visible:
			label.text = ("%.0f fps  %.2f ms\n" % [_fps, _ms]) + String(lines.call())


func force_text(prefix: String, lines: Callable) -> void:
	label.text = prefix + String(lines.call())


## sx: seam position as a fraction of the screen width (from the camera's screen_x(0)); hidden when off screen.
func set_seam(sx: float, width: float) -> void:
	var on: bool = sx >= 0.0 and sx <= 1.0
	seam_tick.visible = on
	seam_label.visible = on
	if on:
		seam_tick.position = Vector2(sx * width - 1.5, 0.0)
		seam_label.position = Vector2(sx * width + 4.0, 22.0)


func toggle() -> void:
	visible = not visible
