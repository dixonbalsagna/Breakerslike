class_name UiCards
## Wound cards (spec-wounds.md section 3): a picture-in-picture callout of about 1.5 s, one line of text such as
## "ARMS: BROKEN", with a small body glyph that highlights the region. Cards live in the fighter's outer column under
## the plate, never over the fighters. The stage is carried by pattern in the glyph and by the card's edge accent
## (solid, dashed or dotted), so colour is never the only cue. Timing, stacking and the readability caps are the
## event hub's job (ui_event_hub.gd); this file only draws what the hub says is visible.

static func draw(ci: CanvasItem, hub: UiEventHub, lay: UiLayout, s: float, t: float, o: Dictionary) -> void:
	var reduced: bool = bool(o.get("reduced_motion", false))
	var card_h: float = lay.card_h
	var gap: float = maxf(8.0 * s, 5.0)
	# Each fighter's column, under the plate. Newest on top. Portrait shows one card per side (the hub caps it at one).
	for slot in range(hub.models.size()):
		var col: Rect2 = lay.cards[slot]
		var mine: Array = hub.cards_of(slot)
		mine.reverse()
		var y2: float = col.position.y
		for c in mine:
			_card(ci, hub, c, Rect2(col.position.x, y2, col.size.x, card_h), s, t, reduced, hub.model(slot).left_side, false)
			y2 += card_h + gap
	if hub.world_card != null:
		_world(ci, hub.world_card, lay.world_card, s, reduced)


static func _card(ci: CanvasItem, hub: UiEventHub, c: UiEventHub.Card, rect: Rect2, s: float, t: float, reduced: bool, left: bool, tag_owner: bool) -> void:
	var a: float = hub.card_alpha(c)
	if a <= 0.0:
		return
	var stamp: float = 1.0 if reduced else clampf(c.age / UiLook.CARD_STAMP, 0.0, 1.0)
	var slide: float = (1.0 - stamp) * 14.0 * s * (-1.0 if left else 1.0)
	var r := Rect2(rect.position + Vector2(slide, 0.0), rect.size)
	var m: UiFighterModel = hub.model(c.slot)
	var stage_col: Color = UiLook.stage_col(maxi(c.stage, 0), m.aura if m != null else Color(UiLook.STAGE_FRESH))
	if c.kind == "internal":
		stage_col = UiLook.col(UiLook.INTERNAL)
	elif c.stage < 0:
		stage_col = UiLook.col(UiLook.WARN)
	UiIcons.rrect(ci, r, 8.0 * s, Color(UiLook.col(UiLook.SCRIM), 0.82 * a), Color(UiLook.col(UiLook.EDGE), 0.4 * a), maxf(1.2, 1.5 * s))
	if not reduced and stamp < 1.0:
		UiIcons.rrect(ci, r, 8.0 * s, Color(1, 1, 1, (1.0 - stamp) * 0.3 * a))
	# Edge accent on the outer side: solid = broken, dashed = battered, dotted = bruised, thin = a state card.
	var ax: float = r.position.x + (4.0 * s if left else r.size.x - 4.0 * s)
	var aw: float = maxf(3.0, 4.0 * s)
	var ac: Color = Color(stage_col, a)
	match c.stage:
		3:
			UiIcons.line(ci, Vector2(ax, r.position.y + 5.0), Vector2(ax, r.end.y - 5.0), aw, ac)
		2:
			UiIcons.dashed_line(ci, Vector2(ax, r.position.y + 5.0), Vector2(ax, r.end.y - 5.0), 9.0 * s, 5.0 * s, aw, ac)
		1:
			UiIcons.dashed_line(ci, Vector2(ax, r.position.y + 5.0), Vector2(ax, r.end.y - 5.0), 2.5 * s, 5.0 * s, aw, ac)
		_:
			UiIcons.line(ci, Vector2(ax, r.position.y + 5.0), Vector2(ax, r.end.y - 5.0), maxf(1.5, aw * 0.5), ac)
	# The picture-in-picture glyph, on the inner side.
	var g: float = r.size.y - 8.0 * s
	var gx: float = (r.position.x + 12.0 * s) if left else (r.end.x - 12.0 * s - g)
	var frame := Rect2(gx, r.position.y + 4.0 * s, g, g)
	UiIcons.rrect(ci, frame, 5.0 * s, Color(0, 0, 0, 0.5 * a), Color(UiLook.col(UiLook.EDGE), 0.35 * a), 1.0)
	_glyph(ci, m, c, frame, s, a)
	# Text.
	var tfs: int = UiText.px(24.0, s)
	var sfs: int = UiText.px(20.0, s)
	var tx: float = (frame.end.x + 10.0 * s) if left else (frame.position.x - 10.0 * s)
	var has_sub: bool = c.sub != "" and r.size.y >= float(tfs) + float(sfs) + 10.0
	var max_w: float = r.size.x - g - 34.0 * s
	var title: String = c.title
	var use_fs: int = tfs
	while UiText.width(title, use_fs) > max_w and use_fs > int(UiLook.text_floor):
		use_fs -= 1
	# On a narrow card (a phone) a title that still does not fit splits into two lines: "CORE" over "BROKEN".
	var lines: PackedStringArray = PackedStringArray([title])
	if UiText.width(title, use_fs) > max_w:
		var parts: PackedStringArray = title.split(": ", false, 1)
		lines = parts if parts.size() == 2 else UiText.wrap(title, use_fs, max_w)
	var body_h: float = float(lines.size()) * (float(use_fs) + 2.0) + (float(sfs) + 2.0 if has_sub else 0.0)
	var ty: float = r.position.y + (r.size.y - body_h) * 0.5 + UiText.ascent(use_fs)
	for l in lines:
		UiText.draw(ci, l, Vector2(tx, ty), use_fs, Color(UiLook.col(UiLook.INK), a), -1 if left else 1, 2.0)
		ty += float(use_fs) + 2.0
	if has_sub:
		var sub: String = c.sub
		UiText.draw(ci, sub, Vector2(tx, ty), sfs, Color(UiLook.col(UiLook.INK_DIM), a), -1 if left else 1, 1.5)


static func _glyph(ci: CanvasItem, m: UiFighterModel, c: UiEventHub.Card, frame: Rect2, s: float, a: float) -> void:
	var fit: Array = UiBody.fit(frame, 3.0)
	var origin: Vector2 = fit[0]
	var sc: float = fit[1]
	var ink := UiLook.col(UiLook.INK_DARK)
	var base: Color = m.aura if m != null else Color(UiLook.STAGE_FRESH)
	var highlight: Array = []
	if c.region != "":
		highlight.append(c.region)
	for r in c.regions:
		if not highlight.has(r):
			highlight.append(r)
	# The rest of the body, faint but outlined; the highlighted regions at their stage pattern.
	for r in ["legs", "core", "arms", "head"]:
		if highlight.has(r):
			continue
		UiBody.draw_region(ci, r, origin, sc, 0, Color(0.7, 0.72, 0.8), ink, 0.3 * a, 0)
	for r in highlight:
		var st: int = c.stage if c.stage >= 0 else 2
		if m != null and c.regions.has(r):
			st = maxi(1, int(m.true_stage.get(r, 1)))
		var col: Color = UiLook.col(UiLook.INTERNAL) if c.kind == "internal" else UiLook.stage_col(st, base)
		UiBody.draw_region(ci, r, origin, sc, st, col, ink, a, UiBody.REGIONS.find(r))
		# A bright ring around the highlighted region, so it reads at a glance.
		for poly in UiBody.px_polys(r, origin, sc):
			var ring: PackedVector2Array = poly.duplicate()
			ring.append(poly[0])
			ci.draw_polyline(ring, Color(1, 1, 1, 0.9 * a), maxf(1.2, sc * 0.02), true)
	if highlight.is_empty():
		# A state card with no region (brink, rally, hatch): a bare diamond in the role colour.
		UiIcons.pip(ci, frame.get_center(), minf(frame.size.x, frame.size.y) * 0.5, 1.0, Color(UiLook.col(UiLook.WARN), a), Color(UiLook.col(UiLook.INK), a))


static func _world(ci: CanvasItem, c: UiEventHub.Card, rect: Rect2, s: float, reduced: bool) -> void:
	var a: float = clampf(c.age / 0.1, 0.0, 1.0)
	var left_t: float = c.life - c.age
	if left_t < UiLook.CARD_FADE:
		a = minf(a, left_t / UiLook.CARD_FADE)
	var fs: int = UiText.px(24.0, s)
	var w: float = UiText.width(c.title, fs) + 36.0 * s
	var r := Rect2(rect.get_center().x - w * 0.5, rect.position.y, w, rect.size.y)
	UiIcons.rrect(ci, r, 8.0 * s, Color(UiLook.col(UiLook.SCRIM), 0.85 * a), Color(UiLook.col(UiLook.WARN), a), maxf(2.0, 2.0 * s))
	UiText.draw(ci, c.title, Vector2(r.get_center().x, r.position.y + (r.size.y - UiText.height(fs)) * 0.5 + UiText.ascent(fs)), fs, Color(UiLook.col(UiLook.INK), a), 0, 2.0)
