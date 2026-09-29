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


static func draw(ci: CanvasItem, hub: UiEventHub, lay: UiLayout, s: float, t: float, o: Dictionary) -> void:
	var stack: Array = [0, 0]
	var idx := 0
	for b in hub.barks:
		if b.setpiece:
			_setpiece(ci, hub, b, lay, s)
			continue
		var lane_i: int = 0 if lay.portrait else b.slot
		var lane: Rect2 = lay.bark[lane_i]
		var slot_off: float = 0.0
		if lay.portrait:
			slot_off = float(idx) * (lane.size.y + 6.0 * s) * -1.0
			idx += 1
		_bark(ci, hub, b, Rect2(lane.position.x, lane.position.y + slot_off, lane.size.x, lane.size.y), s, b.slot == 0)


static func _bark(ci: CanvasItem, hub: UiEventHub, b: UiEventHub.Bark, lane: Rect2, s: float, left: bool) -> void:
	var m: UiFighterModel = hub.model(b.slot)
	var inten: int = int((b.cues[0] as Dictionary).get("intensity", 1)) if not b.cues.is_empty() else 1
	var fs: int = UiText.px(28.0, s)
	var tfs: int = UiText.px(20.0, s)
	var pad: float = 10.0 * s
	var lines: PackedStringArray = UiText.wrap(b.text, fs, lane.size.x - pad * 2.0)
	var shown: int = UiBarkTiming.reveal_count(b.text, b.age, inten)
	var total_h: float = pad * 2.0 + float(tfs) + 4.0 + float(lines.size()) * (float(fs) + 4.0)
	var fade: float = 1.0
	var left_t: float = b.reveal_time + b.dur - b.age
	if left_t < 0.25:
		fade = clampf(left_t / 0.25, 0.0, 1.0)
	fade = minf(fade, clampf(b.age / 0.08, 0.0, 1.0))
	# Anchor the panel to the lane's bottom edge, growing upward.
	var w: float = 0.0
	for l in lines:
		w = maxf(w, UiText.width(l, fs))
	w = maxf(w, UiText.width(m.name if m != null else "", tfs) + 60.0 * s) + pad * 2.0
	var x: float = lane.position.x if left else lane.end.x - w
	var panel := Rect2(x, lane.end.y - total_h, w, total_h)
	UiIcons.rrect(ci, panel, 8.0 * s, Color(UiLook.col(UiLook.SCRIM), 0.55 * fade), Color(m.aura if m != null else Color.WHITE, 0.55 * fade), maxf(1.5, 2.0 * s))
	var ty: float = panel.position.y + pad + UiText.ascent(tfs)
	var name_x: float = panel.position.x + pad if left else panel.end.x - pad
	var nw: float = UiText.draw(ci, m.name if m != null else "", Vector2(name_x, ty), tfs, Color(m.aura if m != null else Color.WHITE, fade), -1 if left else 1, 1.5)
	# The grunt burst pulses beside the name when a cue fires; the caption tag names the gesture for players who cannot hear.
	if m != null and m.cue < UiLook.CUE_PULSE * 1.6 and b.fired > 0:
		var k: float = m.cue / (UiLook.CUE_PULSE * 1.6)
		var bx: float = (name_x + nw + 18.0 * s) if left else (name_x - nw - 18.0 * s - float(tfs))
		UiIcons.sound_burst(ci, Vector2(bx, ty - float(tfs) * 0.3), float(tfs) * 1.1, m.cue_intensity, Color(UiLook.col(UiLook.INK), (1.0 - k) * fade))
	if hub.captions_on and b.fired > 0:
		var last: Dictionary = b.cues[b.fired - 1]
		var cap: String = "[" + UiData.caption_for(str(last.get("gesture", ""))) + "]"
		var cx: float = (panel.end.x - pad) if left else (panel.position.x + pad)
		UiText.draw(ci, cap, Vector2(cx, ty), tfs, Color(UiLook.col(UiLook.INK_DIM), fade), 1 if left else -1, 1.5)
	# The revealed text, character by character across the wrapped lines.
	var yy: float = ty + 6.0 + float(fs)
	var remaining: int = shown
	for l in lines:
		var part: String = l.substr(0, remaining) if remaining < l.length() else l
		if part != "":
			UiText.draw(ci, part, Vector2(panel.position.x + pad if left else panel.end.x - pad, yy), fs, Color(UiLook.col(UiLook.INK), fade), -1 if left else 1, 2.0)
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
