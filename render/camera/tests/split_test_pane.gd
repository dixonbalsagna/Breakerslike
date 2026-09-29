class_name SplitTestPane
extends RefCounted
## A stand-in pane for the compositor test (render/camera/tests/split_sweep.gd --render): a flat 2D world drawn with the
## reference camera's mapping (sdx(cam.x, x) * z + vw / 2 across, vh * 0.7 - (y - cam.y) * z down), blocks of colour by
## planet position, a ground line, and the fighters as boxes. It implements the pane contract of SplitView, so the real
## composite, the mask and the frame sequence are exercised without Rendering's PaneWorld.

var viewport := SubViewport.new()
var canvas := _Canvas.new()
var fighters: Array = [Vector2.ZERO, Vector2.ZERO]   # world x, y (feet)
var active: bool = true


func _init() -> void:
	viewport.size = Vector2i(1280, 720)
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(canvas)
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)


func set_active(on: bool) -> void:
	active = on
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func set_view(cam_x: float, cam_y: float, zoom: float, jitter: Vector2) -> void:
	canvas.cam = Vector3(cam_x, cam_y, zoom)
	canvas.jitter = jitter
	canvas.fighters = fighters
	canvas.queue_redraw()


class _Canvas extends Control:
	var cam := Vector3(0.0, 0.0, 0.5)
	var jitter := Vector2.ZERO
	var fighters: Array = []

	func _draw() -> void:
		var vw: float = size.x
		var vh: float = size.y
		var z: float = cam.z
		var W: float = SimConst.W
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.30, 0.42, 0.72))
		var block: float = W / 307.0   # fixed, and a whole number of blocks round the planet: the pattern must not jump at the seam
		var left: float = cam.x - vw * 0.5 / z
		var b0: int = int(floor(left / block))
		var nb: int = int(vw / z / block) + 2
		var gy: float = vh * 0.7 + cam.y * z + jitter.y
		for b in range(b0, b0 + nb):
			var wx: float = float(b) * block
			var sx: float = (wx - cam.x) * z + vw * 0.5 + jitter.x
			var idx: int = posmod(b, 307)   # by integer block number: a float division here rounds differently either side of the seam
			var h: float = fposmod(float(idx) * 0.61803, 1.0)
			var col := Color.from_hsv(h, 0.45, 0.85 if idx % 2 == 0 else 0.7)
			draw_rect(Rect2(sx, gy, block * z + 1.0, vh), col)
			if idx % 4 == 0:
				draw_rect(Rect2(sx, gy - 260.0 * z, 6.0 * maxf(z, 0.15), 260.0 * z), Color(0.15, 0.2, 0.3))
		draw_line(Vector2(0, gy), Vector2(vw, gy), Color(0.05, 0.05, 0.08), 2.0)
		for i in range(fighters.size()):
			var f: Vector2 = fighters[i]
			var sx: float = SimWrap.sdx(cam.x, f.x) * z + vw * 0.5 + jitter.x
			var sy: float = vh * 0.7 - (f.y - cam.y) * z + jitter.y
			var col := Color(0.95, 0.35, 0.3) if i == 0 else Color(0.3, 0.75, 0.95)
			draw_rect(Rect2(sx - 14.0 * z, sy - 75.0 * z, 28.0 * z, 75.0 * z), col)
			draw_rect(Rect2(sx - 14.0 * z, sy - 75.0 * z, 28.0 * z, 75.0 * z), Color.BLACK, false, 1.0)
