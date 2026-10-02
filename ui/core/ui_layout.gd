class_name UiLayout
extends RefCounted
## Where everything on the HUD goes, as rectangles, for a viewport size. Pure geometry: no drawing, no sim access, so
## a headless check can prove the fighter-clear zone and the text floors (ui/tools/hud_check.gd).
##
## Two layouts: landscape (16:9 and wider, designed against 1920x1080) and portrait (phones, designed against
## 1080x1920). Both scale by `s` and both keep every text at or above UiLook.MIN_TEXT_PX real pixels.
##
## Vocabulary: `clear_zone` is the band where nothing persistent or transient may draw (the fighters' space, and what
## the camera should frame within). `frame_rect` is the wider band the camera may use when fighters are far apart.

var vp := Vector2(1920, 1080)
var portrait := false
var s := 1.0
var safe := Rect2()
var silhouette_on := true

var plate: Array = [Rect2(), Rect2()]        # the nameplate of each fighter
var silhouette: Array = [Rect2(), Rect2()]   # the silhouette panel (zero size when off)
var cards: Array = [Rect2(), Rect2()]        # the wound-card column of each fighter
var card_h := 56.0                           # one card's height, real pixels
var toll := Rect2()                          # the world-toll chip
var banner_c := Vector2()                    # banner centre (the world card shares this slot)
var world_card := Rect2()
var bark: Array = [Rect2(), Rect2()]         # each fighter's bark lane
var letterbox_top := Rect2()
var letterbox_bottom := Rect2()
var setpiece := Rect2()                      # the caption band inside the bottom letterbox
var strip := Rect2()                         # the planet strip
var feed := Rect2()                          # the director feed (debug)
var clear_zone := Rect2()                    # nothing draws here: the fighters' space
var frame_rect := Rect2()                    # where the camera may keep fighters: full width, below the columns
var touch_reserve := Rect2()                 # portrait: kept free for Controls' touch controls (from the highest button down)
var left_handed := false                     # the touch buttons on the left, the stick on the right (SimTouch mirrors them)
var face: Array = [Rect2(), Rect2()]        # per slot: the square for the speaker's face cut-in, in its column above the bark lane (empty: the face is embedded in the bark panel)
var touch_full := false                      # the Full touch layout (nine buttons, SimTouch.layout with full = true) instead of Simple's three
var touch_ctrl: Dictionary = {}              # SimTouch.layout(...) for this screen in touch mode: attack, guard, power, context circles and the stick zone
var bark_single := false                     # touch landscape: one bark lane, on the side away from the buttons, the lines stacking as in portrait
var cards_one := false                       # touch landscape: the buttons leave room for one wound card a side, not two
var cards_none := false                      # touch landscape on a very short screen (about 360 dp tall): no room for a card above the buttons; the plate and the crown carry the wear
var ring := Rect2()                          # the planet ring map (landscape), centred above the strip
var hints: Array = [Rect2(), Rect2()]        # each column's control-hint legend, under the prompt row; landscape only (UiHints decides who shows one)
var prompts: Array = [Rect2(), Rect2()]      # each column's prompt row (stance and hold prompts), under the cards; landscape only
var form: Array = [Rect2(), Rect2()]         # each column's form-ready chip (UiFormPrompt): top of the legend's space under the prompt row, or empty where it does not fit (portrait, a cramped touch screen)
var swapped := false                         # slot 0 is on the right: the fighter on the left of the screen is slot 1
var touch_grid := false                      # touch: the stance ring is a 2 by 2 grid because the column is too narrow for four targets in a row
var read_slot := Rect2()                     # the telegraph chip and the tutorial hint line: the banner slot, between the plates, above the fight
var feedback_label := ""                     # the pill's words (SEND FEEDBACK, or FEEDBACK where the room is tight) and their size
var feedback_fs := 14
var feedback_btn := Rect2()                  # the match-end SEND FEEDBACK pill: beside the ring map (landscape) or at the clear zone's foot (portrait)
var pause_btn := Rect2()                     # touch only: the pause button (48 dp), beside the toll chip
var dp := 1.0                                # device pixels per dp (CSS pixel on the web): 1 on a desktop, 2 to 3.5 on a phone. The host sets it before compute
var touch_ui := false                        # touch is the last input device: targets are at least 48 dp and the prompt row is the stance ring
var text_floor := UiLook.MIN_TEXT_PX         # the smallest text, real pixels: 14, or 12 dp on a dense screen
var touch_min := 48.0                        # the smallest touch target, real pixels (48 dp)
var pm: Dictionary = {}                      # plate metrics for this scale


## Font sizes and row geometry of a nameplate at scale s; y values are relative to the plate's top.
static func plate_metrics(scale: float, compact: bool) -> Dictionary:
	var m := {}
	var pad: float = maxf(8.0 * scale, 5.0)
	m["pad"] = pad
	m["fs_name"] = UiText.px(24.0, scale)
	m["fs_chip"] = UiText.px(20.0, scale)
	m["fs_tier"] = UiText.px(18.0, scale)
	m["fs_ego"] = UiText.px(18.0, scale)
	m["fs_state"] = UiText.px(18.0, scale)
	var y: float = pad
	m["name_y"] = y
	m["chip_h"] = maxf(30.0 * scale, float(m["fs_chip"]) + 8.0)
	if compact:
		# Portrait: the name, then the stance chip, on separate rows (a phone plate is too narrow to share a row).
		m["name_h"] = float(m["fs_name"]) + 4.0
		y += float(m["name_h"]) + 3.0 * scale
		m["chip_y"] = y
		y += float(m["chip_h"]) + 4.0 * scale
	else:
		# Landscape: the stance chip shares the name's row, and the state chips share the pips' row (see UiPlate).
		m["name_h"] = float(m["chip_h"])
		m["chip_y"] = y
		y += float(m["chip_h"]) + 3.0 * scale
	m["tier_y"] = y
	m["pip"] = maxf(16.0 * scale, 13.0)
	m["tier_h"] = maxf(float(m["pip"]) + 4.0, float(m["fs_tier"]) + 2.0)
	y += float(m["tier_h"]) + 3.0 * scale
	m["ego_y"] = y
	m["ego_h"] = maxf(float(m["fs_ego"]) + 2.0, 16.0)
	y += float(m["ego_h"]) + 2.0 * scale
	m["charge_y"] = y
	m["charge_h"] = float(m["ego_h"])
	m["bar_h"] = maxf(10.0 * scale, 8.0)
	y += float(m["charge_h"]) + pad
	m["h"] = y
	m["compact"] = compact
	return m


## Height of one bark panel (name line plus two text lines) at scale s.
static func bark_height(scale: float) -> float:
	var fs: int = UiText.px(28.0, scale)
	var tfs: int = UiText.px(20.0, scale)
	return maxf(120.0 * scale, 20.0 * scale + float(tfs) + 4.0 + 2.0 * (float(fs) + 4.0) + 6.0)


func compute(p_vp: Vector2, p_silhouette: bool = true, insets: Vector4 = Vector4.ZERO, p_swapped: bool = false) -> void:
	vp = p_vp
	silhouette_on = p_silhouette
	swapped = p_swapped
	portrait = vp.y > vp.x * 1.05
	# On a small portrait phone (under 700 px tall) the silhouette would leave the fight under a fifth of the screen:
	# it is dropped there, and the crown, the cards and the plate carry the state (docs/ui/hud-spec.md section 7).
	silhouette_on = p_silhouette and not (portrait and vp.y < 700.0)
	var design: Vector2 = UiLook.DESIGN_PORTRAIT if portrait else UiLook.DESIGN_LANDSCAPE
	s = clampf(minf(vp.x / design.x, vp.y / design.y), UiLook.SCALE_MIN, UiLook.SCALE_MAX)
	# Dense screens (phones: dp above 1.25). Text is never under 12 dp (about 2 mm), and a touch target never under 48 dp. In
	# landscape the whole HUD grows so its smallest text (18 design px) meets that floor, as far as the two columns may take
	# 30% of the width each; then it steps down until the fight keeps its middle, no column meets a bark lane and (on touch)
	# the pause button fits beside the toll chip. Portrait grows its fonts only.
	text_floor = UiLook.MIN_TEXT_PX
	touch_min = maxf(48.0 * dp, 44.0)
	var s_fit: float = s
	var s_try: float = s
	if dp > 1.25:
		text_floor = maxf(UiLook.MIN_TEXT_PX, 12.0 * dp)
		if not portrait:
			s_try = clampf(maxf(s_fit, minf(text_floor / 18.0, 0.30 * vp.x / 380.0)), UiLook.SCALE_MIN, UiLook.SCALE_MAX)
	UiLook.text_floor = text_floor
	while true:
		s = s_try
		_pass(insets)
		if portrait or s_try <= s_fit + 0.001 or _fits():
			break
		s_try = maxf(s_fit, s_try - 0.04)
	if touch_ui and not portrait and pause_btn.size.y <= 0.0:
		# A very small screen: under the toll chip, where it fits best.
		var bs: float = maxf(touch_min, 44.0)
		pause_btn = Rect2(vp.x * 0.5 - bs * 0.5, toll.end.y + 4.0, bs, bs)
	if swapped:
		# Slot 0 is on the right of the screen (the shortest way puts the rival to its left): mirror every per-slot column.
		for arr in [plate, silhouette, cards, bark, prompts, hints]:
			var tmp = arr[0]
			arr[0] = arr[1]
			arr[1] = tmp
	_place_faces()
	_place_forms()


## The lowest edge of the nameplates, the toll chip and the pause button, plus a gap: Camera's top panel band should start at or below this (the
## band is 19% to 39% of the height; on a short or small screen the plates reach into its first few pixels).
func panel_floor() -> float:
	var y: float = maxf(plate[0].end.y, plate[1].end.y)
	y = maxf(y, toll.end.y)
	if pause_btn.size.y > 0.0:
		y = maxf(y, pause_btn.end.y)
	return y + 6.0 * s


## The docked face squares (UiFaces): each in its speaker's column, bottom on the bark lane's top, as large as `desired` allows without touching a
## nameplate, a card row, the silhouette, the prompt row, the legend's three rows, the toll chip, the pause button, the match-end pill, the ring map,
## the strip, the read slot or a touch button. None fits (a portrait phone, the one-lane touch landscape, a tiny window): the rect stays empty and the
## face is embedded in the bark panel instead. The legend then ends where the face begins.
func _place_faces() -> void:
	face = [Rect2(), Rect2()]
	if portrait or bark_single:
		return
	var gap: float = 12.0 * s
	var desired: float = clampf(vp.y * 0.2, 72.0, 240.0)
	var min_side: float = maxf(56.0, 48.0 * minf(dp, 1.5))
	var gh: float = maxf(24.0 * s, 20.0)
	var row_h: float = maxf(gh, float(UiText.px(18.0, s)) * 1.4) + 4.0 * s
	var legend_min: float = 3.0 * row_h + 2.0 * maxf(8.0 * s, 5.0)
	var legend_full: float = 12.0 * row_h + 2.0 * maxf(8.0 * s, 5.0)
	var fixed: Array = [plate[0], plate[1], toll, strip, ring, read_slot, pause_btn, feedback_btn, cards[0], cards[1], silhouette[0], silhouette[1], prompts[0], prompts[1]]
	fixed.append(Rect2(vp.x * UiFaces.CENTRE_FROM, 0.0, vp.x * (UiFaces.CENTRE_TO - UiFaces.CENTRE_FROM), vp.y))   # Camera's panel strip owns the centre 56% of the width
	if touch_ui and not touch_ctrl.is_empty():
		for k in touch_keys():
			var c: Dictionary = touch_ctrl[k]
			fixed.append(Rect2(float(c.x) - float(c.r) - 6.0 * dp, float(c.y) - float(c.r) - 6.0 * dp, (float(c.r) + 6.0 * dp) * 2.0, (float(c.r) + 6.0 * dp) * 2.0))
	for i in range(2):
		var p: Rect2 = plate[i]
		var left: bool = p.get_center().x < vp.x * 0.5
		var top: float = (prompts[i].end.y if prompts[i].size.y > 0.0 else maxf(cards[i].end.y, silhouette[i].end.y)) + gap
		# The legend keeps every row if a face at least two thirds of the wanted size still fits; if not, the face wins down to the legend's three rows.
		var tries: Array = [[legend_full, desired * 0.66], [legend_min, min_side]] if not touch_ui else [[0.0, min_side]]
		for tr in tries:
			var obstacles: Array = fixed.duplicate()
			if not touch_ui:
				obstacles.append(Rect2(p.position.x, top, p.size.x, float(tr[0]) + gap))
			var side: float = minf(desired, p.size.x * 0.85)
			while side >= maxf(float(tr[1]), min_side):
				var x: float = p.position.x if left else p.end.x - side
				var r := Rect2(x, bark[i].position.y - gap - side, side, side)
				var clash := not Rect2(Vector2.ZERO, vp).encloses(r)
				for o in obstacles:
					if (o as Rect2).size.y > 0.0 and (o as Rect2).size.x > 0.0 and r.intersects(o):
						clash = true
						break
				if not clash:
					face[i] = r
					break
				side *= 0.93
			if face[i].size.y > 0.0:
				break
		if face[i].size.y > 0.0 and hints[i].size.y > 0.0:
			var hh: float = face[i].position.y - gap - hints[i].position.y
			hints[i] = Rect2(hints[i].position.x, hints[i].position.y, hints[i].size.x, maxf(hh, 0.0))


## The form-ready chip's slot in each column (UiFormPrompt): directly under the prompt row (on touch, under the cards), as wide as the column, as
## tall as the chip. It takes the top of the legend's space; the legend starts under it while it shows. It must clear the bark lane, the docked face,
## the toll chip, the strip, the ring map, the pause button, the feedback pill and every touch button; if any of them is in the way the slot stays
## empty and the prompt row's own Transform chip carries it (and, on touch, the lit button). Portrait has no column room: the touch button carries it.
func _place_forms() -> void:
	form = [Rect2(), Rect2()]
	if portrait:
		return
	var gap: float = 12.0 * s
	var fh: float = UiFormPrompt.height(s)
	var obstacles: Array = [bark[0], bark[1], toll, strip, ring, read_slot, pause_btn, feedback_btn, face[0], face[1]]
	if touch_ui and not touch_ctrl.is_empty():
		for k in touch_keys():
			var c: Dictionary = touch_ctrl[k]
			obstacles.append(Rect2(float(c.x) - float(c.r) - 6.0 * dp, float(c.y) - float(c.r) - 6.0 * dp, (float(c.r) + 6.0 * dp) * 2.0, (float(c.r) + 6.0 * dp) * 2.0))
	for i in range(2):
		var p: Rect2 = plate[i]
		var top: float = (prompts[i].end.y if prompts[i].size.y > 0.0 else maxf(cards[i].end.y, silhouette[i].end.y)) + gap
		# Not into Camera's panel strip (the centre of the screen): the chip's width stops at the strip's edge, on the column's own side.
		var left: bool = p.get_center().x < vp.x * 0.5
		var x0: float = p.position.x if left else maxf(p.position.x, vp.x * UiFaces.CENTRE_TO + gap * 0.5)
		var x1: float = minf(p.end.x, vp.x * UiFaces.CENTRE_FROM - gap * 0.5) if left else p.end.x
		var r := Rect2(x0, top, maxf(x1 - x0, 0.0), fh)
		var clash: bool = not Rect2(Vector2.ZERO, vp).encloses(r)
		for o in obstacles:
			if (o as Rect2).size.y > 0.0 and (o as Rect2).size.x > 0.0 and r.intersects(o):
				clash = true
				break
		if not clash:
			form[i] = r


## One layout pass at the current scale `s`.
func _pass(insets: Vector4) -> void:
	var mx: float = maxf(vp.x * 0.04, 24.0 if not portrait else 14.0)
	var my: float = maxf(vp.y * 0.045, 16.0)
	safe = Rect2(mx + insets.x, my + insets.y, vp.x - 2.0 * mx - insets.x - insets.z, vp.y - 2.0 * my - insets.y - insets.w)
	pm = plate_metrics(s, portrait)
	card_h = maxf(60.0 * s, float(UiText.px(22.0, s)) * 2.0 + 12.0)
	ring = Rect2()
	pause_btn = Rect2()
	read_slot = Rect2()
	feedback_btn = Rect2()
	touch_grid = false
	bark_single = false
	cards_one = false
	cards_none = false
	prompts = [Rect2(), Rect2()]
	hints = [Rect2(), Rect2()]
	# The touch controls (Controls' SimTouch): the same call and the same inputs as the host's touch_layout(), so what is drawn is what is hit.
	touch_ctrl = {}
	if touch_ui:
		var tmargin: float = maxf(maxf(vp.x - safe.end.x, vp.y - safe.end.y), 8.0 * dp)
		touch_ctrl = SimTouch.layout(vp.x, vp.y, dp, portrait, left_handed, tmargin, touch_full)
	if portrait:
		_portrait()
		var fb_h2: float = maxf(touch_min if touch_ui else 40.0 * s, 34.0)
		var fb_w2: float = _pill_fit(safe.size.x, fb_h2)
		feedback_btn = Rect2(vp.x * 0.5 - fb_w2 * 0.5, clear_zone.end.y - fb_h2 - 8.0 * s, fb_w2, fb_h2)
	else:
		_landscape()
		# The planet ring map: centred above the strip, below the clear zone and between the two bark lanes.
		var d: float = clampf(vp.y * 0.085, 52.0, 120.0)
		var gap: float = 12.0 * s
		ring = Rect2(vp.x * 0.5 - d * 0.5, strip.position.y - gap - d, d, d)
		var fb_h: float = maxf(touch_min if touch_ui else 40.0 * s, 34.0)
		var pill_right: float = bark[1].position.x
		if touch_ui and not touch_ctrl.is_empty():
			pill_right = minf(pill_right, _ctrl_box().position.x) if not left_handed else pill_right
		var fb_w: float = _pill_fit(pill_right - gap - (ring.end.x + gap), fb_h)
		feedback_btn = Rect2(ring.end.x + gap, strip.position.y - 4.0 * s - fb_h, fb_w, fb_h)
		if touch_ui and not touch_ctrl.is_empty():
			_touch_adjust()


## The buttons the HUD keeps clear: Simple's attack, guard and power, or every Full button (the stick's zone is not a button).
func touch_keys() -> Array:
	if touch_full:
		var out: Array = []
		for k in touch_ctrl:
			if k != "stick":
				out.append(k)
		return out
	return ["attack", "guard", "power"]


## The bounding box of the drawn touch buttons: what the fight and the columns must stay clear of.
func _ctrl_box() -> Rect2:
	var box := Rect2()
	var first := true
	for k in touch_keys():
		if not touch_ctrl.has(k):
			continue
		var c: Dictionary = touch_ctrl[k]
		var r := Rect2(float(c.x) - float(c.r), float(c.y) - float(c.r), float(c.r) * 2.0, float(c.r) * 2.0)
		box = r if first else box.merge(r)
		first = false
	return box


## Make room for the touch buttons in a landscape layout: the wound cards stop above them, the fight (clear zone and camera band) ends
## beside them, and the bark lanes become one lane on the other side, the lines stacking as in portrait. No stance ring or control
## legend on touch: the buttons are the controls.
func _touch_adjust() -> void:
	var gap: float = 12.0 * s
	var box: Rect2 = _ctrl_box()
	for i in range(2):
		var c: Rect2 = cards[i]
		if c.end.x > box.position.x and c.position.x < box.end.x:
			var room: float = box.position.y - gap - c.position.y
			var full: float = c.size.y
			cards[i] = Rect2(c.position.x, c.position.y, c.size.x, clampf(room, 0.0, full))
			if room < 2.0 * card_h + gap:
				cards_one = true
			if room < card_h:
				cards_none = true
	if not left_handed:
		var edge: float = box.position.x - gap
		clear_zone = Rect2(clear_zone.position, Vector2(maxf(minf(clear_zone.end.x, edge) - clear_zone.position.x, 0.0), clear_zone.size.y))
		frame_rect = Rect2(frame_rect.position, Vector2(maxf(minf(frame_rect.end.x, edge) - frame_rect.position.x, 0.0), frame_rect.size.y))
	else:
		var edge2: float = box.end.x + gap
		var cx2: float = maxf(clear_zone.position.x, edge2)
		clear_zone = Rect2(cx2, clear_zone.position.y, maxf(clear_zone.end.x - cx2, 0.0), clear_zone.size.y)
		var fx2: float = maxf(frame_rect.position.x, edge2)
		frame_rect = Rect2(fx2, frame_rect.position.y, maxf(frame_rect.end.x - fx2, 0.0), frame_rect.size.y)
	if cards_none:
		cards = [Rect2(cards[0].position, Vector2(cards[0].size.x, 0.0)), Rect2(cards[1].position, Vector2(cards[1].size.x, 0.0))]
	var lane: Rect2 = bark[1] if left_handed else bark[0]
	bark = [lane, lane]
	bark_single = true


## The match-end pill's width for `avail` px: the full words at the normal size if they fit, else the same words smaller (to the text
## floor), else the short words; sets feedback_label and feedback_fs.
func _pill_fit(avail: float, h: float) -> float:
	var b: Dictionary = UiFeedback.data().get("buttons", {})
	var full: String = str(b.get("match_end", "SEND FEEDBACK"))
	var words: PackedStringArray = full.split(" ", false)
	var short_label: String = words[words.size() - 1] if words.size() > 1 else full   # SEND FEEDBACK becomes FEEDBACK where the room is tight
	var fs0: int = UiText.px(20.0, s)
	var floor_fs: int = int(text_floor)
	for label in [full, short_label]:
		var fs: int = fs0
		while true:
			var w: float = UiText.width(label, fs) + h * 0.5 + 8.0 * s
			if w <= avail:
				feedback_label = label
				feedback_fs = fs
				return w
			if fs <= floor_fs:
				break
			fs -= 1
	feedback_label = short_label
	feedback_fs = floor_fs
	return UiText.width(short_label, floor_fs) + h * 0.5 + 8.0 * s


## Whether the landscape layout at this scale is acceptable: the fight keeps the middle, the prompt rows clear the bark lanes
## and stay on screen, and on touch the pause button found room.
func _fits() -> bool:
	if clear_zone.size.y < 0.42 * vp.y or clear_zone.size.x < 0.30 * vp.x:
		return false
	if touch_ui and pause_btn.size.y <= 0.0:
		return false
	if touch_ui and not touch_ctrl.is_empty() and cards_none:
		return false   # the buttons must leave room for at least one wound card a side (the loop tries a smaller scale first)
	var view := Rect2(Vector2.ZERO, vp)
	for i in range(2):
		if prompts[i].size.y > 0.0 and (prompts[i].intersects(bark[i]) or not view.encloses(prompts[i])):
			return false
	return true


func _landscape() -> void:
	var col_w: float = 380.0 * s
	var ph: float = float(pm["h"])
	var gap: float = 12.0 * s
	plate[0] = Rect2(safe.position.x, safe.position.y, col_w, ph)
	plate[1] = Rect2(safe.end.x - col_w, safe.position.y, col_w, ph)
	var sil_w: float = 120.0 * s if silhouette_on else 0.0
	var sil_h: float = 168.0 * s
	for i in range(2):
		var p: Rect2 = plate[i]
		var col_top: float = p.end.y + gap
		var left: bool = i == 0
		var sil_x: float = p.position.x if left else p.end.x - sil_w
		silhouette[i] = Rect2(sil_x, col_top, sil_w, sil_h if silhouette_on else 0.0)
		var cx0: float = (sil_x + sil_w + gap) if left else p.position.x
		var cx1: float = p.end.x if left else (sil_x - gap)
		if not silhouette_on:
			cx0 = p.position.x
			cx1 = p.end.x
		cards[i] = Rect2(cx0, col_top, cx1 - cx0, 2.0 * (card_h + gap))
		# No stance ring on touch any more (Controls' bridge has no stance taps; the buttons are the controls): the row is empty there.
		var prow: float = 0.0 if touch_ui else maxf(40.0 * s, 30.0)
		prompts[i] = Rect2(p.position.x, maxf(cards[i].end.y, silhouette[i].end.y) + gap, col_w, prow)
	var toll_w: float = 380.0 * s
	# The toll chip grows to hold four-digit counts (the population is whole people, about 1,800) where the plates leave room.
	var fs_t: int = UiText.px(20.0, s)
	var need_w: float = maxf(UiText.width("%s 9999 / 9999" % UiData.t("toll.civilians"), fs_t), UiText.width("%s 9999    %s 9999" % [UiData.t("toll.structures"), UiData.t("toll.craters")], fs_t)) + maxf(24.0 * s, 10.0)
	var room_w: float = plate[1].position.x - plate[0].end.x - 2.0 * gap - (2.0 * (maxf(touch_min, 44.0) + gap) if touch_ui else 0.0)
	toll_w = minf(maxf(toll_w, need_w), maxf(room_w, 200.0))
	toll = Rect2(vp.x * 0.5 - toll_w * 0.5, safe.position.y, toll_w, 2.0 * float(UiText.px(20.0, s)) + 18.0)
	banner_c = Vector2(vp.x * 0.5, toll.end.y + gap + 28.0 * s)
	pause_btn = Rect2()
	if touch_ui:
		# The pause button: a touch screen has no P key. Beside the toll chip, on the side with room (never over a plate).
		var bs: float = maxf(touch_min, 44.0)
		var right := Rect2(toll.end.x + gap, safe.position.y, bs, bs)
		var left := Rect2(toll.position.x - gap - bs, safe.position.y, bs, bs)
		if right.end.x <= plate[1].position.x - gap:
			pause_btn = right
		elif left.position.x >= plate[0].end.x + gap:
			pause_btn = left
	# The read slot (the telegraph chip and the tutorial hint): from under the toll chip to the clear zone's top edge, between the plates.
	var rs_y: float = toll.end.y + gap * 0.5
	read_slot = Rect2(plate[0].end.x + gap, rs_y, plate[1].position.x - plate[0].end.x - 2.0 * gap, banner_c.y + 34.0 * s - rs_y)
	if pause_btn.size.y > 0.0:
		# The button sits beside the toll chip and reaches below it: the slot narrows to the toll's width so a centred line never meets it.
		var half: float = absf(pause_btn.get_center().x - vp.x * 0.5) - pause_btn.size.x * 0.5 - gap
		read_slot = Rect2(vp.x * 0.5 - half, rs_y, 2.0 * half, read_slot.size.y)
	world_card = Rect2(vp.x * 0.5 - 200.0 * s, banner_c.y - 26.0 * s, 400.0 * s, 52.0 * s)
	var strip_h: float = maxf(20.0 * s, 14.0)
	var strip_w: float = minf(safe.size.x * 0.46, 900.0 * s)
	strip = Rect2(vp.x * 0.5 - strip_w * 0.5, safe.end.y - strip_h, strip_w, strip_h)
	var lane_w: float = minf(safe.size.x * 0.34, 640.0 * s)
	var lane_h: float = bark_height(s)
	var lane_bottom: float = strip.position.y - gap * 1.2
	bark[0] = Rect2(safe.position.x, lane_bottom - lane_h, lane_w, lane_h)
	bark[1] = Rect2(safe.end.x - lane_w, lane_bottom - lane_h, lane_w, lane_h)
	# The control-hint legend: the rest of the column under the prompt row, down to the bark lane. Not on touch (its controls are on screen).
	if not touch_ui:
		for i in range(2):
			var hy: float = prompts[i].end.y + gap
			var hh: float = bark[i].position.y - gap - hy
			if hh > 0.0:
				hints[i] = Rect2(prompts[i].position.x, hy, col_w, hh)
	var lb_h: float = vp.y * 0.09
	letterbox_top = Rect2(0, 0, vp.x, lb_h)
	letterbox_bottom = Rect2(0, vp.y - lb_h, vp.x, lb_h)
	setpiece = Rect2(vp.x * 0.15, letterbox_bottom.position.y, vp.x * 0.70, lb_h)
	feed = Rect2(safe.position.x, maxf(cards[0].end.y + gap, vp.y * 0.36), minf(safe.size.x * 0.30, 520.0 * s), vp.y * 0.30)
	touch_reserve = Rect2()
	var mid_l: float = plate[0].end.x + gap
	var mid_r: float = plate[1].position.x - gap
	var zone_top: float = banner_c.y + 34.0 * s + gap
	var zone_bottom: float = bark[0].position.y - gap
	clear_zone = Rect2(mid_l, zone_top, mid_r - mid_l, zone_bottom - zone_top)
	var col_bottom: float = maxf(maxf(cards[0].end.y, cards[1].end.y), maxf(prompts[0].end.y, prompts[1].end.y))
	frame_rect = Rect2(safe.position.x, col_bottom + gap, safe.size.x, zone_bottom - (col_bottom + gap))


func _portrait() -> void:
	var gap: float = maxf(8.0 * s, 6.0)
	var pw: float = (safe.size.x - gap) * 0.5
	var ph: float = float(pm["h"])
	plate[0] = Rect2(safe.position.x, safe.position.y, pw, ph)
	plate[1] = Rect2(safe.end.x - pw, safe.position.y, pw, ph)
	var strip_h: float = maxf(20.0 * s, 14.0)
	strip = Rect2(safe.position.x, plate[0].end.y + gap, safe.size.x, strip_h)
	var row_top: float = strip.end.y + gap
	# One row: [silhouette | card | card | silhouette]. One card per side in portrait (the hub caps at one).
	var sil_w: float = maxf(minf(safe.size.x * 0.16, 130.0 * s), 56.0) if silhouette_on else 0.0
	var sil_h: float = sil_w * 1.4
	silhouette[0] = Rect2(safe.position.x, row_top, sil_w, sil_h if silhouette_on else 0.0)
	silhouette[1] = Rect2(safe.end.x - sil_w, row_top, sil_w, sil_h if silhouette_on else 0.0)
	var inner_l: float = safe.position.x + (sil_w + gap if silhouette_on else 0.0)
	var inner_r: float = safe.end.x - (sil_w + gap if silhouette_on else 0.0)
	var cw: float = (inner_r - inner_l - gap) * 0.5
	cards[0] = Rect2(inner_l, row_top, cw, card_h)
	cards[1] = Rect2(inner_r - cw, row_top, cw, card_h)
	var row_h: float = maxf(card_h, sil_h if silhouette_on else 0.0)
	toll = Rect2(safe.position.x, row_top + row_h + gap, safe.size.x, float(UiText.px(20.0, s)) + 12.0)
	banner_c = Vector2(vp.x * 0.5, toll.end.y + gap + 22.0 * s)
	world_card = Rect2(vp.x * 0.5 - 180.0 * s, banner_c.y - 22.0 * s, 360.0 * s, 44.0 * s)
	var rs_y2: float = toll.end.y + gap * 0.5
	read_slot = Rect2(safe.position.x, rs_y2, safe.size.x, banner_c.y + 30.0 * s - rs_y2)
	var reserve_top: float = vp.y * 0.78
	if touch_ui and not touch_ctrl.is_empty():
		for k in touch_keys():
			if touch_ctrl.has(k):
				reserve_top = minf(reserve_top, float(touch_ctrl[k].y) - float(touch_ctrl[k].r) - 6.0 * dp)
	touch_reserve = Rect2(0, reserve_top, vp.x, vp.y - reserve_top)
	var lane_h: float = bark_height(s)
	bark[0] = Rect2(safe.position.x, touch_reserve.position.y - lane_h - gap, safe.size.x, lane_h)
	bark[1] = bark[0]
	var lb_h: float = vp.y * 0.07
	letterbox_top = Rect2(0, 0, vp.x, lb_h)
	letterbox_bottom = Rect2(0, touch_reserve.position.y - lb_h, vp.x, lb_h)
	setpiece = Rect2(safe.position.x, letterbox_bottom.position.y, safe.size.x, lb_h)
	feed = Rect2()
	var zone_top: float = banner_c.y + 30.0 * s + gap
	clear_zone = Rect2(safe.position.x, zone_top, safe.size.x, bark[0].position.y - gap - zone_top)
	frame_rect = clear_zone


## Every persistent HUD rectangle (for the fighter-clear check). Transient ones (cards, barks) sit inside their columns and lanes.
func hud_rects() -> Array:
	var out: Array = [plate[0], plate[1], toll, strip]
	if pause_btn.size.y > 0.0:
		out.append(pause_btn)
	if ring.size.y > 0.0:
		out.append(ring)
	for i in range(2):
		if silhouette[i].size.y > 0.0:
			out.append(silhouette[i])
		out.append(cards[i])
		if prompts[i].size.y > 0.0:
			out.append(prompts[i])
		out.append(bark[i])
	return out


# --- Split screen (docs/camera/split-screen.md section 10) --------------------------------------------------------------

## The vertical range the divider may span: it stops under the toll chip and above the ring map and the planet strip.
func divider_band() -> Vector2:
	var top: float = toll.end.y + 6.0 * s
	var bottom: float = (ring.position.y if ring.size.y > 0.0 else strip.position.y) - 6.0 * s
	return Vector2(top, bottom)


## The divider's two ends: the line through c perpendicular to n, clipped to the full width and the divider band.
## Returns [] when the line misses the band. During a swing (n turning through the vertical) the line runs horizontal.
func divider_segment(c: Vector2, n: Vector2) -> Array:
	var band: Vector2 = divider_band()
	var d := Vector2(-n.y, n.x)
	if d.length() < 0.001:
		return []
	# Liang-Barsky against the rectangle [0, vp.x] x [band.x, band.y], along p(t) = c + d t.
	var t0 := -1e9
	var t1 := 1e9
	for pq in [[-d.x, c.x - 0.0], [d.x, vp.x - c.x], [-d.y, c.y - band.x], [d.y, band.y - c.y]]:
		var p: float = pq[0]
		var q: float = pq[1]
		if absf(p) < 1e-9:
			if q < 0.0:
				return []
		else:
			var r: float = q / p
			if p < 0.0:
				t0 = maxf(t0, r)
			else:
				t1 = minf(t1, r)
	if t0 >= t1:
		return []
	return [c + d * t0, c + d * t1]


## The clear zone of one pane: the pane's half of the screen, inset by the safe area on the outer edge and by 2% of the
## width on the divider side, within the vertical band 17.9% to 80.1% of the height (Camera's numbers). `pane_b` picks the
## pane on the +n side. A convex polygon (an empty array if the pane has no room).
func pane_zone(pane_b: bool, c: Vector2, n: Vector2) -> PackedVector2Array:
	var y0: float = vp.y * 0.179
	var y1: float = vp.y * 0.801
	var poly := PackedVector2Array([Vector2(safe.position.x, y0), Vector2(safe.end.x, y0), Vector2(safe.end.x, y1), Vector2(safe.position.x, y1)])
	var nn: Vector2 = n if pane_b else -n
	return UiIcons.clip_half_plane(poly, c + nn * (vp.x * 0.02), nn)


## Which pane a screen point is in: false = pane A (the -n side), true = pane B.
static func pane_of(p: Vector2, c: Vector2, n: Vector2) -> bool:
	return (p - c).dot(n) > 0.0
