class_name UiIcons
## Vector icons and shape helpers, all drawn with CanvasItem primitives so they need no font and no texture (the web
## build's fallback font lacks arrow and triangle glyphs). Every HUD cue that also carries colour carries one of these
## shapes too: stance, hidden, lost trail, hazard, the grunt burst, tier pips.
## All functions take the CanvasItem to draw on; sizes are real pixels.


static func rrect_pts(r: Rect2, rad: float, seg: int = 4) -> PackedVector2Array:
	var pts := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var corners: Array = [
		[Vector2(r.position.x + r.size.x - rad, r.position.y + rad), -PI * 0.5],
		[Vector2(r.position.x + r.size.x - rad, r.position.y + r.size.y - rad), 0.0],
		[Vector2(r.position.x + rad, r.position.y + r.size.y - rad), PI * 0.5],
		[Vector2(r.position.x + rad, r.position.y + rad), PI],
	]
	for c in corners:
		for i in range(seg + 1):
			var a: float = c[1] + PI * 0.5 * float(i) / float(seg)
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return pts


static func rrect(ci: CanvasItem, r: Rect2, rad: float, fill: Color, edge: Color = Color(0, 0, 0, 0), edge_w: float = 0.0) -> void:
	var pts: PackedVector2Array = rrect_pts(r, rad)
	if fill.a > 0.0:
		fill_poly(ci, pts, fill)
	if edge.a > 0.0 and edge_w > 0.0:
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, edge, edge_w, true)


## A right-pointing arrow starting at `from`, `length` long.
static func arrow(ci: CanvasItem, from: Vector2, length: float, width: float, col: Color) -> void:
	var h: float = width * 2.4
	var tip: Vector2 = from + Vector2(length, 0.0)
	UiIcons.line(ci, from, tip - Vector2(h * 0.7, 0.0), width, col, true)
	fill_poly(ci, PackedVector2Array([tip, tip + Vector2(-h, -h * 0.75), tip + Vector2(-h, h * 0.75)]), col)


static func chevron(ci: CanvasItem, c: Vector2, size: float, dir: float, width: float, col: Color) -> void:
	var a: Vector2 = c + Vector2(-size * 0.5 * dir, -size * 0.6)
	var b: Vector2 = c + Vector2(size * 0.5 * dir, 0.0)
	var d: Vector2 = c + Vector2(-size * 0.5 * dir, size * 0.6)
	ci.draw_polyline(PackedVector2Array([a, b, d]), col, width, true)


static func dashed_line(ci: CanvasItem, a: Vector2, b: Vector2, dash: float, gap: float, width: float, col: Color, offset: float = 0.0) -> void:
	var total: float = a.distance_to(b)
	if total <= 0.0:
		return
	var dir: Vector2 = (b - a) / total
	var pos: float = -fposmod(offset, dash + gap)
	while pos < total:
		var s: float = maxf(pos, 0.0)
		var e: float = minf(pos + dash, total)
		if e > s:
			UiIcons.line(ci, a + dir * s, a + dir * e, width, col)
		pos += dash + gap


## The four stance icons: press (forward chevrons), guard (shield), dodge (curved slip arrow), escape (bracket and an
## arrow leaving it). Centered at c, about `size` wide.
static func stance(ci: CanvasItem, idx: int, c: Vector2, size: float, col: Color, width: float = 0.0) -> void:
	var w: float = width if width > 0.0 else maxf(2.0, size * 0.11)
	match idx:
		0:
			chevron(ci, c + Vector2(-size * 0.17, 0), size * 0.55, 1.0, w, col)
			chevron(ci, c + Vector2(size * 0.17, 0), size * 0.55, 1.0, w, col)
		1:
			var s: float = size * 0.5
			var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.82, -s * 0.62), c + Vector2(s * 0.72, s * 0.28), c + Vector2(0, s), c + Vector2(-s * 0.72, s * 0.28), c + Vector2(-s * 0.82, -s * 0.62), c + Vector2(0, -s)])
			ci.draw_polyline(pts, col, w, true)
			UiIcons.line(ci, c + Vector2(0, -s * 0.55), c + Vector2(0, s * 0.55), maxf(1.0, w * 0.7), col, true)
		2:
			var r: float = size * 0.36
			ci.draw_arc(c + Vector2(-size * 0.05, size * 0.05), r, deg_to_rad(200.0), deg_to_rad(380.0), 12, col, w, true)
			var tip: Vector2 = c + Vector2(-size * 0.05 + r, size * 0.05)
			fill_poly(ci, PackedVector2Array([tip + Vector2(0, size * 0.22), tip + Vector2(-size * 0.17, -size * 0.06), tip + Vector2(size * 0.17, -size * 0.06)]), col)
			UiIcons.line(ci, c + Vector2(-size * 0.5, size * 0.36), c + Vector2(-size * 0.22, size * 0.36), maxf(1.0, w * 0.7), col, true)
		_:
			var x0: float = c.x - size * 0.5
			ci.draw_polyline(PackedVector2Array([Vector2(x0 + size * 0.14, c.y - size * 0.46), Vector2(x0, c.y - size * 0.46), Vector2(x0, c.y + size * 0.46), Vector2(x0 + size * 0.14, c.y + size * 0.46)]), col, w, true)
			arrow(ci, Vector2(x0 + size * 0.24, c.y), size * 0.76, w * 0.9, col)


## Eye with a slash: HIDDEN.
static func eye_slash(ci: CanvasItem, c: Vector2, size: float, col: Color) -> void:
	var w: float = maxf(2.0, size * 0.1)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in range(9):
		var u: float = float(i) / 8.0
		var x: float = lerpf(-0.5, 0.5, u) * size
		var y: float = sin(u * PI) * size * 0.26
		top.append(c + Vector2(x, -y))
		bot.append(c + Vector2(x, y))
	ci.draw_polyline(top, col, w, true)
	ci.draw_polyline(bot, col, w, true)
	ci.draw_circle(c, size * 0.1, col)
	UiIcons.line(ci, c + Vector2(-size * 0.42, size * 0.4), c + Vector2(size * 0.42, -size * 0.4), w * 1.3, col, true)


## A trail that stops short: TRAIL LOST.
static func trail_lost(ci: CanvasItem, c: Vector2, size: float, col: Color) -> void:
	var w: float = maxf(2.0, size * 0.1)
	var x: float = c.x - size * 0.5
	var lens: Array = [0.3, 0.22, 0.14]
	for l in lens:
		UiIcons.line(ci, Vector2(x, c.y), Vector2(x + size * l, c.y), w, col, true)
		x += size * (l + 0.1)
	var e: Vector2 = Vector2(c.x + size * 0.38, c.y)
	UiIcons.line(ci, e + Vector2(-size * 0.09, -size * 0.14), e + Vector2(size * 0.09, size * 0.14), w, col, true)
	UiIcons.line(ci, e + Vector2(-size * 0.09, size * 0.14), e + Vector2(size * 0.09, -size * 0.14), w, col, true)


## The grunt burst: a dot and up to three arcs, more arcs for a harder sound. intensity 0..3.
static func sound_burst(ci: CanvasItem, c: Vector2, size: float, intensity: int, col: Color) -> void:
	var w: float = maxf(2.0, size * 0.11)
	ci.draw_circle(c, size * 0.08, col)
	for k in range(clampi(intensity, 0, 3) + 1):
		ci.draw_arc(c, size * (0.24 + 0.2 * float(k)), -0.75, 0.75, 8, col, w, true)


## A warning triangle with a bar and a dot: the hazard mark in the mode indicator.
static func hazard(ci: CanvasItem, c: Vector2, size: float, col: Color) -> void:
	var s: float = size * 0.5
	var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.95, s * 0.75), c + Vector2(-s * 0.95, s * 0.75), c + Vector2(0, -s)])
	ci.draw_polyline(pts, col, maxf(2.0, size * 0.1), true)
	UiIcons.line(ci, c + Vector2(0, -s * 0.3), c + Vector2(0, s * 0.25), maxf(2.0, size * 0.1), col, true)
	ci.draw_circle(c + Vector2(0, s * 0.5), maxf(1.5, size * 0.06), col)


## A jagged edge: BRINK. Notched hexagon.
static func brink(ci: CanvasItem, c: Vector2, size: float, col: Color) -> void:
	var s: float = size * 0.5
	var pts := PackedVector2Array([c + Vector2(-s, -s * 0.2), c + Vector2(-s * 0.5, -s), c + Vector2(-s * 0.1, -s * 0.45), c + Vector2(s * 0.35, -s), c + Vector2(s, -s * 0.1), c + Vector2(s * 0.45, s * 0.25), c + Vector2(s * 0.5, s), c + Vector2(-s * 0.1, s * 0.4), c + Vector2(-s * 0.6, s), c + Vector2(-s, -s * 0.2)])
	ci.draw_polyline(pts, col, maxf(2.0, size * 0.1), true)


## Two stacked upward carets: CHARGING.
static func caret_up(ci: CanvasItem, c: Vector2, size: float, col: Color) -> void:
	var w: float = maxf(2.0, size * 0.22)
	for k in range(2):
		var y: float = c.y + size * (0.28 - 0.5 * float(k))
		ci.draw_polyline(PackedVector2Array([Vector2(c.x - size * 0.5, y + size * 0.3), Vector2(c.x, y - size * 0.15), Vector2(c.x + size * 0.5, y + size * 0.3)]), col, w, true)


## A four-point star: the signature is ready.
static func star4(ci: CanvasItem, c: Vector2, size: float, col: Color) -> void:
	var s: float = size * 0.5
	var k: float = s * 0.28
	fill_poly(ci, PackedVector2Array([c + Vector2(0, -s), c + Vector2(k, -k), c + Vector2(s, 0), c + Vector2(k, k), c + Vector2(0, s), c + Vector2(-k, k), c + Vector2(-s, 0), c + Vector2(-k, -k)]), col)


## A diamond pip filled from the left to `fill` (0..1). The diamond outline is always drawn, so an empty pip still reads.
static func pip(ci: CanvasItem, c: Vector2, size: float, fill: float, col: Color, edge: Color) -> void:
	var s: float = size * 0.5
	var poly := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
	fill_poly(ci, poly, Color(0, 0, 0, 0.45))
	if fill > 0.0:
		var clipped: PackedVector2Array = clip_x(poly, c.x - s + 2.0 * s * clampf(fill, 0.0, 1.0))
		if clipped.size() >= 3:
			fill_poly(ci, clipped, col, true)
	var closed: PackedVector2Array = poly.duplicate()
	closed.append(poly[0])
	ci.draw_polyline(closed, edge, maxf(1.5, size * 0.09), true)


## Sutherland-Hodgman clip of a polygon to x <= xmax.
static func clip_x(poly: PackedVector2Array, xmax: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = poly.size()
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var ain: bool = a.x <= xmax
		var bin: bool = b.x <= xmax
		if ain:
			out.append(a)
		if ain != bin:
			var t: float = (xmax - a.x) / (b.x - a.x)
			out.append(a + (b - a) * t)
	return out


static func poly_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	var n: int = poly.size()
	for i in range(n):
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % n]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


static func centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / float(maxi(1, poly.size()))


## Diagonal hatch lines clipped to a convex polygon. angle in radians; spacing and width in pixels.
static func hatch(ci: CanvasItem, poly: PackedVector2Array, angle: float, spacing: float, col: Color, width: float) -> void:
	if poly.size() < 3 or spacing < 1.5:
		return
	var d := Vector2(cos(angle), sin(angle))
	var n := Vector2(-d.y, d.x)
	var lo := 1e9
	var hi := -1e9
	for p in poly:
		var v: float = p.dot(n)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var sgn: float = 1.0 if poly_area(poly) > 0.0 else -1.0
	var v0: float = ceil(lo / spacing) * spacing
	var v: float = v0
	while v < hi:
		var p0: Vector2 = n * v
		var t0 := -1e9
		var t1 := 1e9
		var ok := true
		for i in range(poly.size()):
			var a: Vector2 = poly[i]
			var e: Vector2 = poly[(i + 1) % poly.size()] - a
			var nrm := Vector2(-e.y, e.x) * sgn
			var num: float = nrm.dot(a - p0)
			var den: float = nrm.dot(d)
			if absf(den) < 1e-9:
				if nrm.dot(p0 - a) < 0.0:
					ok = false
					break
			else:
				var t: float = num / den
				if den > 0.0:
					t0 = maxf(t0, t)
				else:
					t1 = minf(t1, t)
		if ok and t0 < t1:
			UiIcons.line(ci, p0 + d * t0, p0 + d * t1, width, col)
		v += spacing


## A zig-zag crack across a polygon's bounding box, deterministic from `variant`.
static func crack(ci: CanvasItem, poly: PackedVector2Array, variant: int, col: Color, width: float) -> void:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	var sz: Vector2 = hi - lo
	var a: Vector2
	var b: Vector2
	if variant % 2 == 0:
		a = Vector2(lo.x + sz.x * 0.15, lo.y + sz.y * 0.1)
		b = Vector2(lo.x + sz.x * 0.85, lo.y + sz.y * 0.92)
	else:
		a = Vector2(lo.x + sz.x * 0.85, lo.y + sz.y * 0.08)
		b = Vector2(lo.x + sz.x * 0.2, lo.y + sz.y * 0.9)
	var pts := PackedVector2Array()
	var steps := 5
	var perp: Vector2 = (b - a).normalized().orthogonal() * minf(sz.x, sz.y) * 0.16
	for i in range(steps + 1):
		var u: float = float(i) / float(steps)
		var off: float = 0.0 if (i == 0 or i == steps) else (1.0 if i % 2 == 1 else -1.0)
		pts.append(a.lerp(b, u) + perp * off)
	ci.draw_polyline(pts, col, width, true)


## draw_line with the width before the colour (CanvasItem.draw_line takes the colour first); antialiased by default.
static func line(ci: CanvasItem, a: Vector2, b: Vector2, width: float, col: Color, aa: bool = true) -> void:
	ci.draw_line(a, b, col, width, aa)


## A filled polygon that can never make the engine print "Invalid polygon data, triangulation failed": consecutive
## duplicate points and NaNs are dropped, and a shape with fewer than three points or a near-zero area (a sliver from a
## clip at the edge of its range, a zero-size rect) is skipped instead of drawn.
static var unguarded: bool = false   # bench and probes only: draw polygons raw, to see what the guard catches


static func fill_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, check: bool = true) -> void:
	if unguarded:
		ci.draw_colored_polygon(pts, col)
		return
	if col.a <= 0.0 or pts.size() < 3:
		return
	var clean := PackedVector2Array()
	for p in pts:
		if is_nan(p.x) or is_nan(p.y) or is_inf(p.x) or is_inf(p.y):
			return
		if clean.is_empty() or clean[clean.size() - 1].distance_squared_to(p) > 1e-6:
			clean.append(p)
	if clean.size() > 1 and clean[0].distance_squared_to(clean[clean.size() - 1]) <= 1e-6:
		clean.remove_at(clean.size() - 1)
	if clean.size() < 3 or absf(poly_area(clean)) < 0.05:
		return
	# A self-intersecting outline (which the triangulator rejects) is not something these shapes should produce, but
	# a clipped or shrunk shape can graze itself; skip it rather than print an error.
	if check and Geometry2D.triangulate_polygon(clean).is_empty():
		return
	ci.draw_colored_polygon(clean, col)


static var _stripes: ImageTexture = null


## An 8 by 8 diagonal-stripe texture (dark stripes at 28% over transparent), tiled by draw_texture_rect on a layer whose
## texture_repeat is enabled. One draw command replaces a hatch of one line per stripe.
static func stripes() -> ImageTexture:
	if _stripes == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		for y in range(8):
			for x in range(8):
				var on: bool = posmod(x - y, 8) < 2
				img.set_pixel(x, y, Color(0, 0, 0, 0.28 if on else 0.0))
		_stripes = ImageTexture.create_from_image(img)
	return _stripes
