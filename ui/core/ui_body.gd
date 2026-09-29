class_name UiBody
## The body figure shared by the silhouette panel and the wound card's picture-in-picture glyph. A stylised, generic
## figure built from convex polygons in a unit space (x from -0.36 to 0.36, y from 0 at the top of the head to 1 at the
## feet). No hair, no costume, no colour beyond the wound stages: the figure carries damage only, never identity.
##
## Each region is drawn by stage with a PATTERN, so colour is never the only cue:
##   fresh: clean fill    bruised: hatched    battered: cracked and hatched    broken: shattered (shards with gaps)

const REGIONS: Array = ["head", "core", "arms", "legs", "mantle"]


static func _quad(a: Vector2, b: Vector2, hw: float) -> PackedVector2Array:
	var n: Vector2 = (b - a).normalized().orthogonal() * hw
	return PackedVector2Array([a + n, b + n, b - n, a - n])


static func _octagon(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(8):
		var ang: float = PI / 8.0 + TAU * float(i) / 8.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	return pts


## The unit-space polygons of a region (a region may have several: two arms, two legs).
static func polys(region: String) -> Array:
	match region:
		"head":
			return [_octagon(Vector2(0.0, 0.095), 0.088)]
		"core":
			return [PackedVector2Array([Vector2(-0.145, 0.205), Vector2(0.145, 0.205), Vector2(0.105, 0.53), Vector2(-0.105, 0.53)])]
		"arms":
			return [_quad(Vector2(-0.16, 0.228), Vector2(-0.31, 0.535), 0.038), _quad(Vector2(0.16, 0.228), Vector2(0.31, 0.535), 0.038)]
		"legs":
			return [_quad(Vector2(-0.055, 0.54), Vector2(-0.088, 0.985), 0.052), _quad(Vector2(0.055, 0.54), Vector2(0.088, 0.985), 0.052)]
		"mantle":
			return [PackedVector2Array([Vector2(-0.15, 0.215), Vector2(0.15, 0.215), Vector2(0.35, 0.86), Vector2(0.0, 0.93), Vector2(-0.35, 0.86)])]
	return []


## Pixel polygons for a region inside a rect: the figure is `scale` tall and centred horizontally in the rect.
static func px_polys(region: String, origin: Vector2, scale: float) -> Array:
	var out: Array = []
	for p in polys(region):
		var q := PackedVector2Array()
		for v in p:
			q.append(origin + v * scale)
		out.append(q)
	return out


## Figure placement in a rect: returns [origin (top centre), scale].
static func fit(rect: Rect2, margin: float = 0.0, wide: bool = false) -> Array:
	# `wide` leaves room for the Cyborg's rail on the right of the figure (the figure spans -0.36..0.36, the rail to 0.48).
	var span: float = 0.86 if wide else 0.74
	var sc: float = minf(rect.size.y - margin * 2.0, (rect.size.x - margin * 2.0) / span)
	var cx: float = rect.position.x + rect.size.x * 0.5 - (0.06 * sc if wide else 0.0)
	return [Vector2(cx, rect.position.y + (rect.size.y - sc) * 0.5), sc]


static func _shards(poly: PackedVector2Array) -> Array:
	var out: Array = []
	var c: Vector2 = UiIcons.centroid(poly)
	var n: int = poly.size()
	var step: int = maxi(1, int(ceil(float(n) / 4.0)))
	var i := 0
	var k := 0
	while i < n:
		var j: int = (i + step) % n
		var tri := PackedVector2Array([c, poly[i], poly[j]])
		var tc: Vector2 = UiIcons.centroid(tri)
		var rot: float = 0.06 if k % 2 == 0 else -0.06
		var moved := PackedVector2Array()
		for p in tri:
			moved.append(tc + (p - tc).rotated(rot) * 0.84 + (tc - c) * 0.10)
		out.append(moved)
		i += step
		k += 1
	return out


## Draw one region at a stage. `col` is the stage's role colour (the fighter's aura for fresh); `ink` the dark line
## colour; `alpha` scales the whole thing; `variant` varies the crack direction per region.
static func draw_region(ci: CanvasItem, region: String, origin: Vector2, scale: float, stage: int, col: Color, ink: Color, alpha: float = 1.0, variant: int = 0) -> void:
	var idx := 0
	for poly in px_polys(region, origin, scale):
		var fill := Color(col.r, col.g, col.b, alpha)
		var line := Color(ink.r, ink.g, ink.b, 0.85 * alpha)
		var edge := Color(col.r, col.g, col.b, alpha)
		var closed: PackedVector2Array = poly.duplicate()
		closed.append(poly[0])
		var sp: float = maxf(3.0, scale * 0.045)
		match stage:
			0:
				UiIcons.fill_poly(ci, poly, Color(fill.r, fill.g, fill.b, 0.82 * alpha))
				ci.draw_polyline(closed, Color(1, 1, 1, 0.35 * alpha), maxf(1.0, scale * 0.008), true)
			1:
				UiIcons.fill_poly(ci, poly, Color(fill.r, fill.g, fill.b, 0.7 * alpha))
				UiIcons.hatch(ci, poly, -PI * 0.25, sp, Color(line.r, line.g, line.b, 0.7 * alpha), maxf(1.0, scale * 0.01))
				ci.draw_polyline(closed, edge, maxf(1.2, scale * 0.011), true)
			2:
				UiIcons.fill_poly(ci, poly, Color(fill.r, fill.g, fill.b, 0.55 * alpha))
				UiIcons.hatch(ci, poly, -PI * 0.25, sp * 0.65, Color(line.r, line.g, line.b, 0.5 * alpha), maxf(1.0, scale * 0.009))
				UiIcons.crack(ci, poly, variant + idx, line, maxf(1.5, scale * 0.014))
				ci.draw_polyline(closed, edge, maxf(1.4, scale * 0.013), true)
			_:
				for shard in _shards(poly):
					UiIcons.fill_poly(ci, shard, Color(fill.r, fill.g, fill.b, 0.34 * alpha), true)
					var sc2: PackedVector2Array = shard.duplicate()
					sc2.append(shard[0])
					ci.draw_polyline(sc2, edge, maxf(1.2, scale * 0.012), true)
				UiIcons.crack(ci, poly, variant + idx + 1, line, maxf(1.5, scale * 0.014))
				# Dashed original outline: the region's ghost.
				var m: int = poly.size()
				for e in range(m):
					UiIcons.dashed_line(ci, poly[e], poly[(e + 1) % m], maxf(3.0, scale * 0.03), maxf(3.0, scale * 0.03), maxf(1.0, scale * 0.008), Color(edge.r, edge.g, edge.b, 0.55 * alpha))
		idx += 1
