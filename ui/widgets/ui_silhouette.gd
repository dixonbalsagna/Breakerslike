class_name UiSilhouette
## The silhouette: a small body figure per fighter, each region drawn by stage with a pattern (clean, hatched, cracked,
## shattered). On by default in training and as the accessibility default (Orb's pick, spec-wounds.md section 3), with
## a variant per fighter:
##   Protagonist  an even wash; the core fills from inside with a separate internal pattern (heat and scald)
##   Anti-hero    only the hairline "front" shows while Pride holds; broken regions still show; a crack drops it
##   Empress      a fifth region (the mantle); each real revision reprints it: a numeral badge and a patch mark
##   Cyborg       flesh regions as usual, plus the chip's rail: station, hatch and chip stage are the persistent state

static func draw(ci: CanvasItem, m: UiFighterModel, rect: Rect2, t: float, s: float, o: Dictionary) -> void:
	if rect.size.y <= 0.0:
		return
	var reduced: bool = bool(o.get("reduced_motion", false))
	# Panel. The edge pulses on the brink; under reduced motion it is a static double outline instead.
	var edge_a: float = 0.45
	var edge_w: float = maxf(1.2, 1.5 * s)
	if m.brink:
		edge_a = 0.95 if reduced else (0.45 + 0.5 * (0.5 + 0.5 * sin(t * UiLook.HZ_BRINK * TAU)))
		edge_w = maxf(2.5, 3.0 * s)
	UiIcons.rrect(ci, rect, 8.0 * s, UiLook.alpha(UiLook.SCRIM, UiLook.SCRIM_ALPHA), UiLook.alpha(UiLook.EDGE, edge_a), edge_w)
	if m.brink and reduced:
		UiIcons.rrect(ci, rect.grow(-4.0 * s), 6.0 * s, Color(0, 0, 0, 0), UiLook.alpha(UiLook.EDGE, 0.9), 1.5)
	var prof: String = str(m.profile.get("silhouette", "plain"))
	var fit: Array = UiBody.fit(rect, maxf(6.0 * s, 4.0), prof == "chip")
	var origin: Vector2 = fit[0]
	var sc: float = fit[1]
	var ink := UiLook.col(UiLook.INK_DARK)
	var alpha: float = 0.45 if m.hidden else 1.0
	# Region draw order: mantle behind, then legs, core, arms, head.
	for r in ["mantle", "legs", "core", "arms", "head"]:
		if not m.has_region(r):
			continue
		var st: int = int(m.stage[r])
		var col: Color = UiLook.stage_col(st, m.aura)
		var a: float = alpha * (0.6 if r == "mantle" else 1.0)
		UiBody.draw_region(ci, r, origin, sc, st, col, ink, a, UiBody.REGIONS.find(r))
		if float(m.region_age[r]) < UiLook.MEND_SWEEP and int(m.region_dir[r]) != 0:
			var k: float = float(m.region_age[r]) / UiLook.MEND_SWEEP
			for poly in UiBody.px_polys(r, origin, sc):
				var closed: PackedVector2Array = poly.duplicate()
				closed.append(poly[0])
				ci.draw_polyline(closed, Color(1, 1, 1, (1.0 - k) * 0.9), maxf(2.0, sc * 0.02), true)
	match prof:
		"pride_mask":
			if m.pride_holds:
				# The hairline front: a fine line across the whole figure, and nothing else, until the crack.
				var a0: Vector2 = origin + Vector2(-0.2, 0.12) * sc
				var b0: Vector2 = origin + Vector2(0.2, 0.9) * sc
				UiIcons.line(ci, a0, b0, maxf(1.0, sc * 0.007), Color(1, 1, 1, 0.75 * alpha))
			elif m.facade_age < 0.6:
				var k2: float = m.facade_age / 0.6
				ci.draw_rect(Rect2(origin.x - sc * 0.4, origin.y, sc * 0.8, sc), Color(1, 1, 1, (1.0 - k2) * 0.35))
		"spread":
			_internal(ci, m, origin, sc, t, reduced)
		"refit":
			_numeral(ci, m, rect, s)
			if m.patch_region != "" and m.has_region(m.patch_region):
				var polys: Array = UiBody.px_polys(m.patch_region, origin, sc)
				if not polys.is_empty():
					_plaster(ci, UiIcons.centroid(polys[0]), sc * 0.07)
		"chip":
			_rail(ci, m, origin, sc, t, reduced, s)


static func _internal(ci: CanvasItem, m: UiFighterModel, origin: Vector2, sc: float, t: float, reduced: bool) -> void:
	if m.internal_stage <= 0 and m.heat_stage <= 0:
		return
	var torso: Array = UiBody.px_polys("core", origin, sc)
	if torso.is_empty():
		return
	var poly: PackedVector2Array = torso[0]
	var c: Vector2 = UiIcons.centroid(poly)
	var inner := PackedVector2Array()
	for p in poly:
		inner.append(c + (p - c) * 0.58)
	var col: Color = UiLook.col(UiLook.INTERNAL)
	var glow: float = 0.15 * float(m.heat_stage)
	if m.heat_stage > 0 and not reduced:
		glow *= 0.7 + 0.3 * sin(t * UiLook.HZ_HEAT * TAU)
	ci.draw_colored_polygon(inner, Color(col.r, col.g, col.b, glow + 0.12 * float(m.internal_stage)))
	var sp: float = maxf(3.0, sc * 0.04) * (1.4 - 0.3 * float(m.internal_stage))
	# The internal pattern is a cross-hatch, unlike the surface wear's single diagonal: separate by shape.
	UiIcons.hatch(ci, inner, PI * 0.25, sp, Color(col.r, col.g, col.b, 0.9), maxf(1.0, sc * 0.008))
	if m.internal_stage >= 2:
		UiIcons.hatch(ci, inner, -PI * 0.25, sp, Color(col.r, col.g, col.b, 0.9), maxf(1.0, sc * 0.008))
	var closed: PackedVector2Array = inner.duplicate()
	closed.append(inner[0])
	ci.draw_polyline(closed, Color(col.r, col.g, col.b, 0.95), maxf(1.2, sc * 0.01), true)
	if m.internal_stage >= 3:
		UiIcons.crack(ci, inner, 1, Color(col.r, col.g, col.b, 1.0), maxf(1.5, sc * 0.012))


static func _numeral(ci: CanvasItem, m: UiFighterModel, rect: Rect2, s: float) -> void:
	if m.revision <= 0:
		return
	var fs: int = UiText.px(20.0, s)
	var r: float = fs * 0.85
	var c: Vector2 = Vector2(rect.end.x - r - 6.0 * s, rect.position.y + r + 6.0 * s)
	ci.draw_circle(c, r, UiLook.alpha(UiLook.INK_DARK, 0.85))
	ci.draw_arc(c, r, 0.0, TAU, 20, UiLook.alpha(UiLook.EDGE, 0.85), maxf(1.5, 1.5 * s), true)
	UiText.draw(ci, str(m.revision), c + Vector2(0, fs * 0.35), fs, UiLook.col(UiLook.INK), 0)


static func _plaster(ci: CanvasItem, c: Vector2, size: float) -> void:
	var dark := UiLook.col(UiLook.INK_DARK)
	var light := UiLook.col(UiLook.INK)
	UiIcons.line(ci, c + Vector2(-size, 0), c + Vector2(size, 0), size * 0.9, dark, true)
	UiIcons.line(ci, c + Vector2(0, -size), c + Vector2(0, size), size * 0.9, dark, true)
	UiIcons.line(ci, c + Vector2(-size * 0.85, 0), c + Vector2(size * 0.85, 0), size * 0.5, light, true)
	UiIcons.line(ci, c + Vector2(0, -size * 0.85), c + Vector2(0, size * 0.85), size * 0.5, light, true)


static func _rail(ci: CanvasItem, m: UiFighterModel, origin: Vector2, sc: float, t: float, reduced: bool, s: float) -> void:
	var rx: float = origin.x + sc * 0.43
	var ys: Array = [0.09, 0.30, 0.42, 0.56]
	var line := UiLook.alpha(UiLook.INK, 0.8)
	UiIcons.line(ci, Vector2(rx, origin.y + sc * 0.05), Vector2(rx, origin.y + sc * 0.6), maxf(1.5, sc * 0.012), line, true)
	for i in range(4):
		var c := Vector2(rx, origin.y + sc * float(ys[i]))
		var active: bool = i == m.chip_station
		var size: float = sc * (0.05 if active else 0.028)
		if active:
			# The chip: a small square that shows its stage by pattern: whole, scratched, cracked, split.
			var half: float = size
			var sq := PackedVector2Array([c + Vector2(-half, -half), c + Vector2(half, -half), c + Vector2(half, half), c + Vector2(-half, half)])
			ci.draw_colored_polygon(sq, Color(UiLook.col(UiLook.INTERNAL), 0.85))
			var ink := UiLook.col(UiLook.INK_DARK)
			if m.chip_stage == 1:
				UiIcons.line(ci, c + Vector2(-half, half * 0.4), c + Vector2(half, -half * 0.4), maxf(1.2, sc * 0.008), ink, true)
			elif m.chip_stage >= 2:
				UiIcons.crack(ci, sq, 1, ink, maxf(1.5, sc * 0.01))
			if m.chip_stage >= 3:
				UiIcons.line(ci, c + Vector2(0, -half), c + Vector2(0, half), maxf(2.0, sc * 0.014), UiLook.alpha(UiLook.SCRIM, 1.0), true)
			var closed: PackedVector2Array = sq.duplicate()
			closed.append(sq[0])
			ci.draw_polyline(closed, line, maxf(1.2, sc * 0.008), true)
			if m.hatch_open:
				# The hatch is open: brackets around the chip, pulsing unless reduced motion.
				var p: float = 1.0 if reduced else (0.6 + 0.4 * sin(t * 8.0))
				var b: float = half * 1.9
				var w: float = maxf(2.0, sc * 0.014)
				var bc := Color(1, 1, 1, p)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-b + half * 0.7, -b), c + Vector2(-b, -b), c + Vector2(-b, b), c + Vector2(-b + half * 0.7, b)]), bc, w, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(b - half * 0.7, -b), c + Vector2(b, -b), c + Vector2(b, b), c + Vector2(b - half * 0.7, b)]), bc, w, true)
		else:
			ci.draw_circle(c, size, line)
