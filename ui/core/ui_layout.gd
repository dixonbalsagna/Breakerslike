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
var touch_reserve := Rect2()                 # portrait: kept free for Controls' touch controls
var ring := Rect2()                          # the planet ring map (landscape), centred above the strip
var swapped := false                         # slot 0 is on the right: the fighter on the left of the screen is slot 1
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
	var mx: float = maxf(vp.x * 0.04, 24.0 if not portrait else 14.0)
	var my: float = maxf(vp.y * 0.045, 16.0)
	safe = Rect2(mx + insets.x, my + insets.y, vp.x - 2.0 * mx - insets.x - insets.z, vp.y - 2.0 * my - insets.y - insets.w)
	pm = plate_metrics(s, portrait)
	card_h = maxf(60.0 * s, float(UiText.px(22.0, s)) * 2.0 + 12.0)
	ring = Rect2()
	if portrait:
		_portrait()
	else:
		_landscape()
		# The planet ring map: centred above the strip, below the clear zone and between the two bark lanes.
		var d: float = clampf(vp.y * 0.085, 52.0, 120.0)
		var gap: float = 12.0 * s
		ring = Rect2(vp.x * 0.5 - d * 0.5, strip.position.y - gap - d, d, d)
	if swapped:
		# Slot 0 is on the right of the screen (the shortest way puts the rival to its left): mirror every per-slot column.
		for arr in [plate, silhouette, cards, bark]:
			var tmp = arr[0]
			arr[0] = arr[1]
			arr[1] = tmp


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
	var toll_w: float = 380.0 * s
	toll = Rect2(vp.x * 0.5 - toll_w * 0.5, safe.position.y, toll_w, 2.0 * float(UiText.px(20.0, s)) + 18.0)
	banner_c = Vector2(vp.x * 0.5, toll.end.y + gap + 28.0 * s)
	world_card = Rect2(vp.x * 0.5 - 200.0 * s, banner_c.y - 26.0 * s, 400.0 * s, 52.0 * s)
	var strip_h: float = maxf(20.0 * s, 14.0)
	var strip_w: float = minf(safe.size.x * 0.46, 900.0 * s)
	strip = Rect2(vp.x * 0.5 - strip_w * 0.5, safe.end.y - strip_h, strip_w, strip_h)
	var lane_w: float = minf(safe.size.x * 0.34, 640.0 * s)
	var lane_h: float = bark_height(s)
	var lane_bottom: float = strip.position.y - gap * 1.2
	bark[0] = Rect2(safe.position.x, lane_bottom - lane_h, lane_w, lane_h)
	bark[1] = Rect2(safe.end.x - lane_w, lane_bottom - lane_h, lane_w, lane_h)
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
	var col_bottom: float = maxf(cards[0].end.y, cards[1].end.y)
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
	touch_reserve = Rect2(0, vp.y * 0.78, vp.x, vp.y * 0.22)
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
	if ring.size.y > 0.0:
		out.append(ring)
	for i in range(2):
		if silhouette[i].size.y > 0.0:
			out.append(silhouette[i])
		out.append(cards[i])
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
