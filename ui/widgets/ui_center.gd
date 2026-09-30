class_name UiCenter
## The top-centre pieces: the world toll chip (civilians lost, structures lost, craters) and the event banner.
## The banner sits under the toll chip, at the top, not mid-screen as in the prototype, so it never covers the fight.
## Banner words are renamed to the glossary's wording by UiData.banner() when the event arrives.

static func draw_toll(ci: CanvasItem, hub: UiEventHub, lay: UiLayout, s: float, o: Dictionary) -> void:
	# The chip dims at rest and brightens for a moment after the toll changes: nothing sits bright over the fight.
	var a: float = float(o.get("plate_alpha", 1.0)) * lerpf(UiLook.TOLL_REST_ALPHA, 1.0, clampf(1.0 - hub.toll_age / UiLook.TOLL_SHOW, 0.0, 1.0))
	var r: Rect2 = lay.toll
	UiText.no_outline = true
	UiText.defer = true
	UiIcons.rrect(ci, r, 8.0 * s, Color(UiLook.col(UiLook.SCRIM), UiLook.SCRIM_ALPHA * a), Color(UiLook.col(UiLook.EDGE), 0.3 * a), 1.2)
	var fs: int = UiText.px(20.0, s)
	var l1: String = "%s %d / %d" % [UiData.t("toll.civilians"), int(hub.toll["civilians"]), int(hub.toll["pop0"])]
	var y1: float = r.position.y + (8.0 if not lay.portrait else 5.0) + UiText.ascent(fs)
	UiText.draw(ci, l1, Vector2(r.get_center().x, y1), fs, Color(UiLook.col(UiLook.INK), a), 0, 1.5)
	if not lay.portrait:
		# Portrait keeps the civilians line only: the phone's fight window is too small for a second line.
		var l2: String = "%s %d    %s %d" % [UiData.t("toll.structures"), int(hub.toll["structures"]), UiData.t("toll.craters"), int(hub.toll["craters"])]
		UiText.draw(ci, l2, Vector2(r.get_center().x, y1 + float(fs) + 3.0), fs, Color(UiLook.col(UiLook.INK_DIM), a), 0, 1.5)
	UiText.flush(ci)
	UiText.no_outline = false


static func draw_banner(ci: CanvasItem, hub: UiEventHub, lay: UiLayout, s: float, o: Dictionary) -> void:
	if hub.banner.is_empty() or hub.world_card != null or not hub.telegraph.is_empty():
		return   # a world card (the fold) takes the banner's slot; the banner waits (its clock is paused, see the hub)
	var b: Dictionary = hub.banner
	var age: float = float(b["age"])
	var dur: float = float(b["dur"])
	var k: float = 1.0
	if age < 0.12:
		k = age / 0.12
	elif age > dur - 0.3:
		k = maxf(0.0, (dur - age) / 0.3)
	var reduced: bool = bool(o.get("reduced_motion", false))
	var fs: int = UiText.px(clampf(lay.vp.x * 0.03, 30.0, 46.0) / maxf(s, 0.01), s, 22.0)
	var c: Color = UiLook.col(str(b["col"]))
	var rise: float = 0.0 if reduced else (1.0 - k) * 8.0
	var pos: Vector2 = lay.banner_c + Vector2(0.0, rise + float(fs) * 0.35)
	UiText.draw(ci, str(b["text"]), pos, fs, Color(c.r, c.g, c.b, k), 0, maxf(2.0, float(fs) * 0.09))
