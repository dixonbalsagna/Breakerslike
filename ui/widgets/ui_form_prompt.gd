class_name UiFormPrompt
## The "form ready" prompt (docs/ui/hud-spec.md section 31). Transforming is its own input, and a beginner who never does it stays at
## tier 1 while the AI climbs, so the moment a form is ready the player's own column says so, loudly:
##   - a chip on that player's side, in the top of the legend's space under the prompt row (UiLayout.form), with the transform control
##     of the player's own device and layout (both triggers on a pad, the key or keys on a keyboard, TAP on touch) and plain words:
##     "TRANSFORM", then "Hold: hit harder for the rest of the match";
##   - it shows while a form is ready (f.act.formReady) and the fighter is free (not in an exchange, not out, not in a cinematic or a pause),
##     goes when an exchange starts and comes back when it ends;
##   - it pulses (the HUD scales and fades the layer, so the pulse costs no redraw); with reduced motion there is no pulse, a steady thick
##     highlight instead; shape and words carry it, never the pulse or the colour alone;
##   - the legend gives way: it starts under the chip, and drops its own Transform row while the chip shows.
## The icon square at the chip's left (three rising chevrons, with the hold ring round it) is the ring slot of Controls' parked 45-tick
## "Transforming" cue (docs/controls/auto-form-spec.md): when `m.form_cue_left` is built it fills there and the words swap. Not built.

const PULSE_HZ := 1.4
const PULSE_SCALE := 0.04       # the chip swells by 4% at the top of the pulse
const PULSE_ALPHA_LOW := 0.78


## Whether the prompt is wanted now for this fighter (the HUD adds the pause and the option).
static func wanted(m: UiFighterModel) -> bool:
	return not m.ai and bool(m.avail["transform"]) and m.form_free and not m.ko and m.cinematic == ""


## The chip's height at scale s: two lines of text and a little padding.
static func height(s: float) -> float:
	var pad: float = maxf(6.0 * s, 4.0)
	return pad * 2.0 + float(UiText.px(22.0, s)) * 1.15 + float(UiText.px(15.0, s)) * 1.3 + 2.0 * s


## The pulse's phase: 0..1 over one cycle (the HUD's clock), eased so the chip swells and settles.
static func pulse(t: float) -> float:
	return 0.5 - 0.5 * cos(TAU * t * PULSE_HZ)


## The geometry of the chip in `rect` (the layout's slot for this player), or {} when nothing fits. The chip sits at the column's own
## edge (left for the left column). `o` carries touch, glyph_style and the layout id (UiHints.preset_id).
static func plan(m: UiFighterModel, rect: Rect2, s: float, o: Dictionary) -> Dictionary:
	if rect.size.y <= 0.0 or rect.size.x <= 0.0:
		return {}
	var touch: bool = bool(o.get("touch", false))
	var style: String = str(o.get("glyph_style", "neutral"))
	var preset: String = UiHints.preset_id(m, o)
	var h: float = height(s)
	if rect.size.y < h - 0.5:
		return {}
	var pad: float = maxf(6.0 * s, 4.0)
	var gap: float = maxf(8.0 * s, 5.0)
	var fs1: int = UiText.px(22.0, s)
	var fs2: int = UiText.px(15.0, s)
	var icon: float = (h - 2.0 * pad) * 0.86
	var gh: float = float(fs1) * 1.05
	var gw: float = 0.0 if touch else UiGlyphs.width("transform", m.device, m.slot, gh, style, preset)
	var word: String = UiData.t("prompt.transform")
	var tw1: float = UiText.width(word, fs1)
	var verb: String = UiData.t("prompt.form_tap" if touch else "prompt.form_hold")
	var line1_w: float = (gw + gap if gw > 0.0 else 0.0) + tw1
	var tail: String = ""
	var tw2: float = 0.0
	var room: float = rect.size.x - (pad * 2.5 + icon)
	for key in ["prompt.form_boost", "prompt.form_boost_short"]:
		var cand: String = "%s: %s" % [verb, UiData.t(key)]
		var cw: float = UiText.width(cand, fs2)
		if cw <= room:
			tail = cand
			tw2 = cw
			break
	if tail == "":
		# No room for the sentence: the verb and the glyph still say what to do.
		tail = verb
		tw2 = UiText.width(tail, fs2)
	var need: float = maxf(line1_w, tw2)
	if need > room:
		if gw > 0.0 and tw1 <= room:
			gw = 0.0   # the word without the glyph: the legend keeps the control
			line1_w = tw1
			need = maxf(line1_w, tw2)
		if need > room:
			return {}
	var w: float = minf(pad * 2.5 + icon + need, rect.size.x)
	var left: bool = m.left_side
	var x: float = rect.position.x if left else rect.end.x - w
	var r := Rect2(x, rect.position.y, w, h)
	var tx: float = r.position.x + pad * 1.75 + icon
	return {"rect": r, "icon_c": Vector2(r.position.x + pad + icon * 0.5, r.get_center().y), "icon_r": icon * 0.5, "tx": tx, "gh": gh, "gw": gw,
		"fs1": fs1, "fs2": fs2, "gap": gap, "word": word, "tail": tail, "y1": r.position.y + pad + float(fs1) * 0.575, "y2": r.end.y - pad - float(fs2) * 0.65,
		"pad": pad, "preset": preset, "style": style, "touch": touch, "left": left}


## What the picture depends on (the pulse is the layer's scale and alpha, not a redraw): the control's own labels, the hold ring in 30ths,
## the colour, the steady (reduced motion) highlight and the rectangle.
static func sig(m: UiFighterModel, p: Dictionary, steady: bool) -> Array:
	return [p.get("rect", Rect2()), m.device, m.slot, p.get("preset", ""), int(m.hold["transform"] * 30.0), m.aura.to_html(false), steady, p.get("gw", 0.0) > 0.0, p.get("tail", "")]


static func draw(ci: CanvasItem, m: UiFighterModel, p: Dictionary, s: float, steady: bool) -> void:
	if p.is_empty():
		return
	var r: Rect2 = p["rect"]
	var accent: Color = m.aura
	UiText.no_outline = true
	# The halo (steady under reduced motion: a thick bright edge says "now"), then the chip.
	UiIcons.rrect(ci, r.grow(3.0 * s), r.size.y * 0.3, Color(accent, 0.0), Color(accent, 0.35), maxf(2.0, 2.0 * s))
	UiIcons.rrect(ci, r, r.size.y * 0.28, Color(UiLook.col(UiLook.SCRIM), 0.88), Color(accent, 1.0), maxf(3.5, 3.5 * s) if steady else maxf(2.5, 2.5 * s))
	UiIcons.rrect(ci, r.grow(-maxf(3.0, 3.0 * s)), r.size.y * 0.22, Color(accent, 0.14))
	var ink := Color(UiLook.col(UiLook.INK))
	# The icon: three rising chevrons in the hold ring (the ring fills while the control is held).
	var c: Vector2 = p["icon_c"]
	var ir: float = p["icon_r"]
	UiGlyphs.hold_ring(ci, c, ir * 0.92, float(m.hold["transform"]), 1.0)
	var w: float = maxf(2.0, ir * 0.16)
	for k in range(3):
		var cy: float = c.y + (float(k) - 1.0) * ir * 0.34 + ir * 0.14
		ci.draw_polyline(PackedVector2Array([Vector2(c.x - ir * 0.36, cy + ir * 0.14), Vector2(c.x, cy - ir * 0.14), Vector2(c.x + ir * 0.36, cy + ir * 0.14)]), Color(ink, 1.0 - 0.22 * float(2 - k)), w, true)
	var tx: float = p["tx"]
	var y1: float = p["y1"]
	var x: float = tx
	if float(p["gw"]) > 0.0:
		UiGlyphs.draw(ci, "transform", m.device, m.slot, Vector2(x, y1), float(p["gh"]), 1.0, true, str(p["style"]), str(p["preset"]))
		x += float(p["gw"]) + float(p["gap"])
	var fs1: int = p["fs1"]
	UiText.draw(ci, str(p["word"]), Vector2(x, y1 + float(fs1) * 0.35), fs1, ink, -1)
	var fs2: int = p["fs2"]
	UiText.draw(ci, str(p["tail"]), Vector2(tx, float(p["y2"]) + float(fs2) * 0.35), fs2, Color(ink, 0.92), -1)
	UiText.no_outline = false
