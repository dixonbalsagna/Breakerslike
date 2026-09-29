class_name UiStrip
## The planet strip: the whole wrapped planet as one bar, with the camera's view, both fighters, and the places where
## buildings fell. Fighter markers differ by SHAPE (a circle for the left fighter, a diamond for the right), so they
## never rely on colour. A hidden fighter's marker becomes a hollow ring with a "?" and a slow ping at its last seen
## spot. An optional region label names the place under the camera (Narrative's places, data in ui/data/terms.json).
##
## data: {W, segs: [[x0, x1, biome]], cam_x, cam_w, dead: [x], fighters: [{x, slot, hidden, aura, seen_x}]}

## The static parts: the bar, the biome segments and the ticks for fallen buildings. Redrawn only when a building falls.
static func draw_base(ci: CanvasItem, lay: UiLayout, data: Dictionary, o: Dictionary) -> void:
	var r: Rect2 = lay.strip
	if r.size.x <= 0.0:
		return
	var W: float = float(data.get("W", 9600.0))
	var a: float = float(o.get("plate_alpha", 1.0))
	var bar := Rect2(r.position.x, r.position.y + r.size.y * 0.3, r.size.x, r.size.y * 0.5)
	ci.draw_rect(Rect2(bar.position - Vector2(2, 2), bar.size + Vector2(4, 4)), Color(UiLook.col(UiLook.SCRIM), 0.75 * a))
	# The biome segments as one multi-line (each a thick horizontal line: butt caps make them exact rects), and the ticks
	# for fallen buildings as another: two draw commands instead of a dozen.
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var cy: float = bar.position.y + bar.size.y * 0.5
	for seg in data.get("segs", []):
		var x0: float = bar.position.x + float(seg[0]) / W * bar.size.x
		var x1: float = bar.position.x + float(seg[1]) / W * bar.size.x + 1.0
		pts.append(Vector2(x0, cy))
		pts.append(Vector2(x1, cy))
		cols.append(Color(UiLook.col(UiLook.BIOME.get(seg[2], "#666666")), a))
	if not pts.is_empty():
		ci.draw_multiline_colors(pts, cols, bar.size.y)
	var ticks := PackedVector2Array()
	for x in data.get("dead", []):
		var dx: float = bar.position.x + fposmod(float(x), W) / W * bar.size.x
		ticks.append(Vector2(dx, bar.position.y + 1))
		ticks.append(Vector2(dx, bar.end.y - 1))
	if not ticks.is_empty():
		ci.draw_multiline(ticks, Color(0, 0, 0, 0.7 * a), 1.0)


## Redraw key for the moving parts: the camera box and the fighters at half-pixel steps, plus a slow phase while a fighter is
## hidden (its marker pings). The layer redraws only when this changes.
static func marks_sig(lay: UiLayout, data: Dictionary, t: float, o: Dictionary) -> Array:
	var r: Rect2 = lay.strip
	var W: float = float(data.get("W", 9600.0))
	var k: float = r.size.x / W * 2.0
	var out: Array = [int(float(data.get("cam_x", 0.0)) * k), int(float(data.get("cam_w", 0.0)) * k), bool(o.get("region_label", false))]
	var ping: bool = false
	for f in data.get("fighters", []):
		out.append(int(float(f.get("x", 0.0)) * k))
		if bool(f.get("hidden", false)) and UiData.feature("hiding"):
			ping = true
			out.append(int(float(f.get("seen_x", 0.0)) * k))
	if ping and not bool(o.get("reduced_motion", false)):
		out.append(int(t * 12.0))
	return out


## The moving parts: the camera's box (it wraps), both fighters, the region label.
static func draw_marks(ci: CanvasItem, lay: UiLayout, hub: UiEventHub, data: Dictionary, s: float, t: float, o: Dictionary) -> void:
	var r: Rect2 = lay.strip
	if r.size.x <= 0.0:
		return
	var W: float = float(data.get("W", 9600.0))
	var a: float = float(o.get("plate_alpha", 1.0))
	var bar := Rect2(r.position.x, r.position.y + r.size.y * 0.3, r.size.x, r.size.y * 0.5)
	# The camera's box (it wraps).
	var cw: float = minf(float(data.get("cam_w", 1600.0)) / W * bar.size.x, bar.size.x)
	var cx0: float = bar.position.x + fposmod(float(data.get("cam_x", 0.0)) - float(data.get("cam_w", 1600.0)) * 0.5, W) / W * bar.size.x
	var wcol := Color(1, 1, 1, 0.9 * a)
	ci.draw_rect(Rect2(cx0, r.position.y, cw, r.size.y), wcol, false, maxf(1.5, 1.5 * s))
	if cx0 + cw > bar.end.x:
		ci.draw_rect(Rect2(cx0 - bar.size.x, r.position.y, cw, r.size.y), wcol, false, maxf(1.5, 1.5 * s))
	# Fighters.
	var msz: float = maxf(r.size.y * 0.42, 6.0)
	for f in data.get("fighters", []):
		var slot: int = int(f.get("slot", 0))
		var col: Color = f.get("aura", Color.WHITE)
		var hidden: bool = bool(f.get("hidden", false)) and UiData.feature("hiding")
		var fx: float = bar.position.x + fposmod(float(f.get("x", 0.0)), W) / W * bar.size.x
		var cy: float = bar.position.y + bar.size.y * 0.5
		if hidden:
			var sx: float = bar.position.x + fposmod(float(f.get("seen_x", f.get("x", 0.0))), W) / W * bar.size.x
			var ring_r: float = msz * (1.0 + (0.0 if bool(o.get("reduced_motion", false)) else 0.6 * fposmod(t * 0.7, 1.0)))
			_marker(ci, slot, Vector2(sx, cy), msz, Color(col, 0.0), Color(col, 0.9 * a), true)
			ci.draw_arc(Vector2(sx, cy), ring_r, 0.0, TAU, 20, Color(col, 0.5 * a * (1.0 - fposmod(t * 0.7, 1.0))), 1.5, true)
			UiText.draw(ci, "?", Vector2(sx, r.position.y - 3.0), UiText.px(18.0, s), Color(UiLook.col(UiLook.INK), a), 0, 1.5)
		else:
			_marker(ci, slot, Vector2(fx, cy), msz, Color(col, a), Color(0, 0, 0, a), false)
	# The region label, under the camera's centre.
	if bool(o.get("region_label", false)):
		var name: String = UiData.place_at(fposmod(float(data.get("cam_x", 0.0)), W))
		if name != "":
			UiText.draw(ci, name, Vector2(r.get_center().x, r.position.y - 6.0), UiText.px(20.0, s), Color(UiLook.col(UiLook.INK_DIM), a), 0, 1.5)


static func _marker(ci: CanvasItem, slot: int, c: Vector2, size: float, fill: Color, edge: Color, hollow: bool) -> void:
	if slot == 0:
		if fill.a > 0.0:
			ci.draw_circle(c, size, fill)
		ci.draw_arc(c, size, 0.0, TAU, 20, edge, 1.6, true)
	else:
		var d := PackedVector2Array([c + Vector2(0, -size * 1.2), c + Vector2(size * 1.2, 0), c + Vector2(0, size * 1.2), c + Vector2(-size * 1.2, 0)])
		if fill.a > 0.0:
			UiIcons.fill_poly(ci, d, fill)
		var closed: PackedVector2Array = d.duplicate()
		closed.append(d[0])
		ci.draw_polyline(closed, edge, 1.6, true)
