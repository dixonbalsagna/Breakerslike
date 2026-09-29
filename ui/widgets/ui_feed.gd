class_name UiFeed
## The director feed (debug toggle): the sim's tag and sub lines, newest at the bottom, with a header that shows the
## HUD's own state (mode, cards, barks) so the readability caps are visible while testing. The "→" in beam and pressure
## tags is drawn as a vector arrow by UiText, so it survives the web build's fallback font.
## Full decision logging (template chosen, launch candidates and scores, windows and why) is the overlay's job
## (docs/ui/hud-spec.md section 9); this widget is the feed the prototype had, made legible and safe.

const MODE_NAMES: Array = ["NORMAL", "HAZARD", "CINEMATIC"]


static func draw(ci: CanvasItem, hub: UiEventHub, lay: UiLayout, s: float, o: Dictionary) -> void:
	var r: Rect2 = lay.feed
	if r.size.x <= 0.0:
		return
	var fs: int = UiText.px(18.0, s, UiLook.MIN_DEBUG_PX)
	var lh: float = float(fs) + 4.0
	var cap: int = UiLook.CAP_FEED_LINES[hub.mode]
	var n: int = mini(cap, hub.feed.size())
	var head: String = "FEED  %s   cards %d   barks %d   t %.1f" % [MODE_NAMES[hub.mode], hub.cards.size(), hub.barks.size(), hub.t_now]
	var h: float = lh * float(n + 1) + 12.0
	var panel := Rect2(r.position.x, r.position.y, r.size.x, minf(h, r.size.y))
	UiIcons.rrect(ci, panel, 6.0 * s, Color(UiLook.col(UiLook.SCRIM), 0.72), Color(UiLook.col(UiLook.EDGE), 0.25), 1.0)
	var y: float = panel.position.y + 6.0 + UiText.ascent(fs)
	UiText.draw(ci, head, Vector2(panel.position.x + 8.0, y), fs, UiLook.col(UiLook.HIDDEN), -1)
	y += lh
	for i in range(hub.feed.size() - n, hub.feed.size()):
		if y > panel.end.y:
			break
		var l: Dictionary = hub.feed[i]
		var age: float = hub.t_now - float(l["t"])
		var a: float = clampf(1.0 - age / 12.0, 0.4, 1.0)
		var tw: float = UiText.draw(ci, "%6.1f" % float(l["t"]), Vector2(panel.position.x + 8.0, y), fs, Color(UiLook.col(UiLook.INK_DIM), a), -1)
		var tagx: float = panel.position.x + 8.0 + tw + 10.0
		var gw: float = UiText.draw(ci, str(l["tag"]), Vector2(tagx, y), fs, Color(UiLook.col(UiLook.WARN), a), -1)
		var subx: float = tagx + gw + 14.0
		if subx < panel.end.x - 20.0:
			UiText.draw(ci, str(l["sub"]), Vector2(subx, y), fs, Color(UiLook.col(UiLook.INK), a * 0.85), -1)
		y += lh
