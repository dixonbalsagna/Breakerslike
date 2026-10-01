class_name UiBarks
## Barks and captions (docs/narrative/line-system.md sections 4 and 9). A bark is a short line in a fighter's own
## voice, shown between 1.2 and 3.5 s in that fighter's lane at the bottom of its side of the screen, over live action,
## never freezing it. Text reveals at a speed set by the line's intensity, with pauses on punctuation. Each cue in a
## line fires a grunt burst mark; with captions on, the latest cue also shows as a bracketed gesture tag, for players who
## cannot hear it. Set pieces (a finisher, a transformation) run longer in the letterbox band. No voice acting: the text
## and the cue carry it.

static func draw_letterbox(ci: CanvasItem, lay: UiLayout, k: float) -> void:
	if k <= 0.001:
		return
	var col := Color(0.02, 0.02, 0.04, 0.92 * k)
	ci.draw_rect(Rect2(lay.letterbox_top.position.x, lay.letterbox_top.position.y, lay.letterbox_top.size.x, lay.letterbox_top.size.y * k), col)
	var bh: float = lay.letterbox_bottom.size.y * k
	ci.draw_rect(Rect2(lay.letterbox_bottom.position.x, lay.letterbox_bottom.end.y - bh, lay.letterbox_bottom.size.x, bh), col)


static func draw(ci: CanvasItem, hub: UiEventHub, lay: UiLayout, s: float, t: float, o0: Dictionary) -> void:
	var o: Dictionary = o0.duplicate()
	o["vp_w"] = lay.vp.x
	UiFaces.draw_docked(ci, hub, lay, s, o)
	var stack: Array = [0, 0]
	var idx := 0
	for b in hub.barks:
		if b.setpiece:
			_setpiece(ci, hub, b, lay, s)
			continue
		var lane_i: int = 0 if (lay.portrait or lay.bark_single) else b.slot
		var lane: Rect2 = lay.bark[lane_i]
		var slot_off: float = 0.0
		if lay.portrait or lay.bark_single:
			slot_off = float(idx) * (lane.size.y + 6.0 * s) * -1.0
			idx += 1
		_bark(ci, hub, b, Rect2(lane.position.x, lane.position.y + slot_off, lane.size.x, lane.size.y), s, hub.model(b.slot).left_side, b.face and UiFaces.embedded(lay, b.slot), o)


## Text that leans: an italic stand-in (the web build has one font), drawn with a shear about the baseline.
static func _lean(ci: CanvasItem, text: String, pos: Vector2, fs: int, col: Color, align: int) -> void:
	var k: float = 0.2
	ci.draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(-k, 1.0), Vector2(k * pos.y, 0.0)))
	UiText.draw(ci, text, pos, fs, col, align, 0.0)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## An inner line (Narrative, dialogue-director.md section 2.3): smaller, leaning, softer, no name and no grunt mark, with a small
## thought trail toward the fighter. It shows what the fighter will not say, and for the tutorial what the fighter reads.
static func _thought(ci: CanvasItem, hub: UiEventHub, b: UiEventHub.Bark, lane: Rect2, s: float, left: bool) -> void:
	var m: UiFighterModel = hub.model(b.slot)
	var inten: int = int((b.cues[0] as Dictionary).get("intensity", 1)) if not b.cues.is_empty() else 1
	var fs: int = UiText.px(23.0, s)
	var pad: float = 10.0 * s
	var lines: PackedStringArray = UiText.wrap(b.text, fs, lane.size.x - pad * 2.0 - 26.0 * s)
	var shown: int = UiBarkTiming.reveal_count(b.text, b.age, inten)
	var fade: float = 1.0
	var left_t: float = b.reveal_time + b.dur - b.age
	if left_t < 0.35:
		fade = clampf(left_t / 0.35, 0.0, 1.0)
	fade = minf(fade, clampf(b.age / 0.15, 0.0, 1.0))
	var w: float = 0.0
	for l in lines:
		w = maxf(w, UiText.width(l, fs))
	w += pad * 2.0
	var total_h: float = pad * 1.6 + float(lines.size()) * (float(fs) + 3.0)
	var x: float = lane.position.x + 16.0 * s if left else lane.end.x - w - 16.0 * s
	var panel := Rect2(x, lane.end.y - total_h, w, total_h)
	var aura: Color = m.aura if m != null else Color.WHITE
	UiIcons.rrect(ci, panel, total_h * 0.4, Color(UiLook.col(UiLook.SCRIM), 0.38 * fade), Color(aura, 0.4 * fade), maxf(1.2, 1.5 * s))
	# The thought trail: three circles, small to large, toward the fighter's own edge of the screen.
	var dir: float = -1.0 if left else 1.0
	var ty0: float = panel.end.y - 4.0 * s
	var tx0: float = (panel.position.x + 4.0 * s) if left else (panel.end.x - 4.0 * s)
	for k in range(3):
		ci.draw_circle(Vector2(tx0 + dir * float(k + 1) * 7.0 * s, ty0 + float(k) * 4.0 * s), maxf(1.6, (1.4 + float(k) * 0.9) * s), Color(UiLook.col(UiLook.INK_DIM), 0.5 * fade))
	var yy: float = panel.position.y + pad * 0.8 + float(fs)
	var remaining: int = shown
	for l in lines:
		var part: String = l.substr(0, remaining) if remaining < l.length() else l
		if part != "":
			_lean(ci, part, Vector2(panel.position.x + pad if left else panel.end.x - pad, yy), fs, Color(UiLook.col(UiLook.INK_DIM), 0.95 * fade), -1 if left else 1)
		remaining -= l.length() + 1
		if remaining < 0:
			break
		yy += float(fs) + 3.0


## A shout: large, heavy, no panel (the line is the event).
static func _shout(ci: CanvasItem, hub: UiEventHub, b: UiEventHub.Bark, lane: Rect2, s: float, left: bool, embed: bool = false, o: Dictionary = {}) -> void:
	var inten: int = int((b.cues[0] as Dictionary).get("intensity", 2)) if not b.cues.is_empty() else 2
	var fs: int = UiText.px(38.0, s)
	# An embedded face is a square at the lane's outer end, as high as two lines of the shout; the shout takes the rest.
	var fe: float = UiFaces.embed_side(2.6 * float(fs), lane, left, float(o.get("vp_w", 1.0e9))) if embed else 0.0
	embed = embed and fe > 0.0
	var lane_full: Rect2 = lane
	if embed:
		lane = Rect2(lane.position.x + (fe + 8.0 * s if left else 0.0), lane.position.y, lane.size.x - fe - 8.0 * s, lane.size.y)
	var lines: PackedStringArray = UiText.wrap(b.text, fs, lane.size.x)
	var shown: int = UiBarkTiming.reveal_count(b.text, b.age, inten)
	var fade: float = minf(clampf(b.age / 0.06, 0.0, 1.0), clampf((b.reveal_time + b.dur - b.age) / 0.25, 0.0, 1.0))
	var yy: float = lane.end.y - float(lines.size() - 1) * (float(fs) + 4.0) - 6.0 * s
	if embed:
		var m0: UiFighterModel = hub.model(b.slot)
		var fr := Rect2(lane_full.position.x if left else lane_full.end.x - fe, lane_full.end.y - fe, fe, fe)
		UiFaces.draw_portrait(ci, fr, m0, b.face_expr, fade * float(o.get("swap_fade", 1.0)), s, not left)
	var remaining: int = shown
	for l in lines:
		var part: String = l.substr(0, remaining) if remaining < l.length() else l
		if part != "":
			UiText.draw(ci, part, Vector2(lane.position.x if left else lane.end.x, yy), fs, Color(UiLook.col(UiLook.INK), fade), -1 if left else 1, maxf(3.0, float(fs) * 0.14))
		remaining -= l.length() + 1
		if remaining < 0:
			break
		yy += float(fs) + 4.0


static func _bark(ci: CanvasItem, hub: UiEventHub, b: UiEventHub.Bark, lane: Rect2, s: float, left: bool, embed: bool = false, o: Dictionary = {}) -> void:
	if b.style == "thought":
		_thought(ci, hub, b, lane, s, left)
		return
	if b.style == "shout":
		_shout(ci, hub, b, lane, s, left, embed, o)
		return
	var m: UiFighterModel = hub.model(b.slot)
	var inten: int = int((b.cues[0] as Dictionary).get("intensity", 1)) if not b.cues.is_empty() else 1
	var fs: int = UiText.px(28.0, s)
	var tfs: int = UiText.px(20.0, s)
	var pad: float = 10.0 * s
	# An embedded face is a square the height of the panel at its outer end; the text takes the rest of the lane. It never goes into the centre
	# band Camera's panel strip owns (UiFaces.embed_side), and a lane with no room for one has none.
	var vp_w: float = float(o.get("vp_w", 1.0e9))
	var fe: float = UiFaces.embed_side(2.8 * float(fs), lane, left, vp_w) if embed else 0.0
	embed = embed and fe > 0.0
	var lines: PackedStringArray = UiText.wrap(b.text, fs, lane.size.x - pad * 2.0 - fe)
	var shown: int = UiBarkTiming.reveal_count(b.text, b.age, inten)
	var total_h: float = pad * 2.0 + float(tfs) + 4.0 + float(lines.size()) * (float(fs) + 4.0)
	if embed and total_h > fe:
		fe = UiFaces.embed_side(total_h, lane, left, vp_w)
		lines = UiText.wrap(b.text, fs, lane.size.x - pad * 2.0 - fe)
		total_h = pad * 2.0 + float(tfs) + 4.0 + float(lines.size()) * (float(fs) + 4.0)
	fe = minf(total_h, fe) if embed else 0.0
	var fade: float = 1.0
	var left_t: float = b.reveal_time + b.dur - b.age
	if left_t < 0.25:
		fade = clampf(left_t / 0.25, 0.0, 1.0)
	fade = minf(fade, clampf(b.age / 0.08, 0.0, 1.0))
	# Anchor the panel to the lane's bottom edge, growing upward.
	var w: float = 0.0
	for l in lines:
		w = maxf(w, UiText.width(l, fs))
	var cap_w: float = 0.0
	if hub.captions_on and not b.cues.is_empty():
		cap_w = UiText.width("[" + UiData.caption_for(str((b.cues[b.cues.size() - 1] as Dictionary).get("gesture", ""))) + "]", tfs)
	w = maxf(w, UiText.width(m.name if m != null else "", tfs) + maxf(60.0 * s, cap_w + 24.0 * s)) + pad * 2.0 + fe
	var x: float = lane.position.x if left else lane.end.x - w
	var panel := Rect2(x, lane.end.y - total_h, w, total_h)
	var tx0: float = panel.position.x + fe   # the text area's left edge, and its right edge below, inside the face
	var tx1: float = panel.end.x - fe
	UiIcons.rrect(ci, panel, 8.0 * s, Color(UiLook.col(UiLook.SCRIM), 0.55 * fade), Color(m.aura if m != null else Color.WHITE, 0.55 * fade), maxf(1.5, 2.0 * s))
	if embed and m != null:
		var fr := Rect2(panel.position.x if left else panel.end.x - fe, panel.position.y, fe, fe)
		UiFaces.draw_portrait(ci, fr.grow(-2.0 * s), m, b.face_expr, fade * float(o.get("swap_fade", 1.0)), s, not left)
	var ty: float = panel.position.y + pad + UiText.ascent(tfs)
	var name_x: float = tx0 + pad if left else tx1 - pad
	var nw: float = UiText.draw(ci, m.name if m != null else "", Vector2(name_x, ty), tfs, Color(m.aura if m != null else Color.WHITE, fade), -1 if left else 1, 1.5)
	# The grunt burst pulses beside the name when a cue fires; the caption tag names the gesture for players who cannot hear.
	if m != null and m.cue < UiLook.CUE_PULSE * 1.6 and b.fired > 0:
		var k: float = m.cue / (UiLook.CUE_PULSE * 1.6)
		var bx: float = (name_x + nw + 18.0 * s) if left else (name_x - nw - 18.0 * s - float(tfs))
		UiIcons.sound_burst(ci, Vector2(bx, ty - float(tfs) * 0.3), float(tfs) * 1.1, m.cue_intensity, Color(UiLook.col(UiLook.INK), (1.0 - k) * fade))
	if hub.captions_on and b.fired > 0:
		var last: Dictionary = b.cues[b.fired - 1]
		var cap: String = "[" + UiData.caption_for(str(last.get("gesture", ""))) + "]"
		var cx: float = (tx1 - pad) if left else (tx0 + pad)
		UiText.draw(ci, cap, Vector2(cx, ty), tfs, Color(UiLook.col(UiLook.INK_DIM), fade), 1 if left else -1, 1.5)
	# The revealed text, character by character across the wrapped lines.
	var yy: float = ty + 6.0 + float(fs)
	var remaining: int = shown
	for l in lines:
		var part: String = l.substr(0, remaining) if remaining < l.length() else l
		if part != "":
			UiText.draw(ci, part, Vector2(tx0 + pad if left else tx1 - pad, yy), fs, Color(UiLook.col(UiLook.INK), fade), -1 if left else 1, 2.0)
		remaining -= l.length() + 1
		if remaining < 0:
			break
		yy += float(fs) + 4.0


static func _setpiece(ci: CanvasItem, hub: UiEventHub, b: UiEventHub.Bark, lay: UiLayout, s: float) -> void:
	var m: UiFighterModel = hub.model(b.slot)
	var inten: int = int((b.cues[0] as Dictionary).get("intensity", 2)) if not b.cues.is_empty() else 2
	var fs: int = UiText.px(34.0, s)
	var tfs: int = UiText.px(20.0, s)
	var band: Rect2 = lay.setpiece
	var shown: int = UiBarkTiming.reveal_count(b.text, b.age, inten)
	var lines: PackedStringArray = UiText.wrap(b.text, fs, band.size.x)
	var fade: float = minf(clampf(b.age / 0.2, 0.0, 1.0), clampf((b.reveal_time + b.dur - b.age) / 0.3, 0.0, 1.0))
	var total: float = float(tfs) + 4.0 + float(lines.size()) * (float(fs) + 4.0)
	var y: float = band.position.y + (band.size.y - total) * 0.5 + UiText.ascent(tfs)
	UiText.draw(ci, m.name if m != null else "", Vector2(band.get_center().x, y), tfs, Color(m.aura if m != null else Color.WHITE, fade), 0, 1.5)
	var yy: float = y + 4.0 + float(fs)
	var remaining: int = shown
	for l in lines:
		var part: String = l.substr(0, remaining) if remaining < l.length() else l
		if part != "":
			UiText.draw(ci, part, Vector2(band.get_center().x, yy), fs, Color(UiLook.col(UiLook.INK), fade), 0, 2.0)
		remaining -= l.length() + 1
		if remaining < 0:
			break
		yy += float(fs) + 4.0
