class_name UiPrompts
## The prompt row under each fighter's column (docs/controls/prompt-glyphs.md section 4): the held-state chips (PRESS, GUARD, DODGE,
## ESCAPE: the state the fighter is in now, filled; there are no stance keys, the state follows the held controls, so GUARD and DODGE
## carry the glyph of the control that holds them in the player's own layout), and the hold prompt for Transform while a form is
## ready (the layout's control, with a ring that fills while it is held). It draws nothing at rest:
##   - the chips show for 3 s at the start of a match and whenever the state changes, and always while prompts are on;
##   - Transform shows only while a form is ready, and only while prompts are on.
## Prompts are drawn here and on the crown windows and the struggle rings, never over the fighters. Glyphs are the neutral set
## of the fighter's own device (UiGlyphs). "Prompts on" is the Show prompts option, which the host also turns on in training
## and in the first three matches.
##
## On a touch screen (option touch_ui) the row is the STANCE RING instead (docs/controls/platform-plan.md section 7.1): four square
## chips, each a touch target at least 48 dp, always shown, icon only (no key glyph to read on a phone). The hold buttons
## (Special, Transform) belong to Controls' touch controls. `touch_rects` gives the chips' rectangles for Controls to hit-test.

## The action whose control holds each state ("" for none: PRESS is the rest state, ESCAPE is dodge held while moving away).
const STANCE_ACTIONS: Array = ["", "guard", "dodge", ""]
const HOLD_ACTIONS: Array = ["transform"]
const STANCE_SHOW := 3.0


static func stance_visible(m: UiFighterModel, prompts_on: bool) -> bool:
	return prompts_on or m.stance_prompt_t < STANCE_SHOW


## Whether the row has anything to draw for this fighter.
static func has_content(m: UiFighterModel, prompts_on: bool, touch: bool = false) -> bool:
	if m.ai:
		return false   # an AI fighter has no device: nothing to prompt
	if touch:
		return true    # the stance ring is always there
	return stance_visible(m, prompts_on) or (prompts_on and m.avail["transform"])


## The redraw key for the row.
static func sig(m: UiFighterModel, prompts_on: bool, touch: bool = false, preset: String = "") -> Array:
	var fade: int = int(clampf((STANCE_SHOW - m.stance_prompt_t) * 4.0, 0.0, 4.0)) if (not prompts_on and not touch) else 4
	return [m.stance, m.device, prompts_on, touch, stance_visible(m, prompts_on), fade, m.avail["transform"], int(m.hold["transform"] * 30.0), preset]


## The chips of the row, in order, as {name, rect, kind, i or act, gw, h, y, gap}: the geometry that both draw and touch_rects
## use, so a target is exactly what is drawn. `rect` is the row; the chips are laid from its column edge inward.
static func plan(m: UiFighterModel, rect: Rect2, s: float, o: Dictionary) -> Array:
	var out: Array = []
	var touch: bool = bool(o.get("touch", false))
	var prompts_on: bool = bool(o.get("prompts", false))
	if rect.size.y <= 0.0 or not has_content(m, prompts_on, touch):
		return out
	var style: String = str(o.get("glyph_style", "neutral"))
	var preset: String = UiHints.preset_id(m, o)
	var left: bool = m.left_side
	var gap: float = maxf(6.0 * s, 4.0)
	var grid: bool = touch and bool(o.get("touch_grid", false))
	var h: float = minf(maxf(26.0 * s, 20.0), rect.size.y * 0.8)
	if touch:
		h = ((rect.size.y - gap) * 0.5 - 4.0) if grid else (rect.size.y - 4.0)
	var y: float = rect.position.y + rect.size.y * 0.5
	var x: float = rect.position.x if left else rect.end.x
	if touch or stance_visible(m, prompts_on):
		for i in range(4):
			var gw: float = 0.0 if (touch or STANCE_ACTIONS[i] == "") else UiGlyphs.width(STANCE_ACTIONS[i], m.device, m.slot, h * 0.8, style, preset)
			var cw: float = (h + 4.0) if touch else (h + gw + gap * 1.5)
			if grid:
				# Two rows of two, from the column edge inward.
				var col: int = i % 2
				var row: int = i / 2
				var gx0: float = rect.position.x + float(col) * (cw + gap) if left else rect.end.x - cw - float(col) * (cw + gap)
				var gy: float = rect.position.y + float(row) * (h + 4.0 + gap) + (h + 4.0) * 0.5
				out.append({"name": "stance_%d" % i, "kind": "stance", "i": i, "gw": gw, "h": h, "y": gy, "gap": gap, "rect": Rect2(gx0, gy - h * 0.5 - 2.0, cw, h + 4.0)})
				continue
			var cx: float = x if left else x - cw
			out.append({"name": "stance_%d" % i, "kind": "stance", "i": i, "gw": gw, "h": h, "y": y, "gap": gap, "rect": Rect2(cx, y - h * 0.5 - 2.0, cw, h + 4.0)})
			x += (cw + gap) if left else -(cw + gap)
	# The weight mark beside the stance ring (light or heavy, sticky). It comes before the hold prompts: it is a read, they are a reminder.
	if not touch and stance_visible(m, prompts_on):
		var ww: float = h + 4.0
		var used: float = (x - rect.position.x) if left else (rect.end.x - x)
		if used + ww <= rect.size.x:
			var wx: float = x if left else x - ww
			out.append({"name": "weight", "kind": "weight", "gw": 0.0, "h": h, "y": y, "gap": gap, "rect": Rect2(wx, y - h * 0.5 - 2.0, ww, h + 4.0)})
			x += (ww + gap) if left else -(ww + gap)
	if prompts_on and not touch:
		for act in HOLD_ACTIONS:
			if not m.avail[act]:
				continue
			var word: String = UiData.t("prompt." + act)
			var fs: int = UiText.px(18.0, s)
			var tw: float = UiText.width(word, fs)
			var gw2: float = UiGlyphs.width(act, m.device, m.slot, h * 0.8, style, preset)
			var cw2: float = gw2 + tw + gap * 3.0 + h * 0.4
			var used2: float = (x - rect.position.x) if left else (rect.end.x - x)
			var short_chip: bool = false
			if used2 + cw2 > rect.size.x:
				# Not enough room for the word: the glyph and its ring alone, or nothing.
				cw2 = gw2 + gap * 2.0 + h * 0.5
				short_chip = true
				if used2 + cw2 > rect.size.x:
					continue
			var cx2: float = x if left else x - cw2
			out.append({"name": act, "kind": "hold", "act": act, "word": "" if short_chip else word, "fs": fs, "tw": tw, "gw": gw2, "h": h, "y": y, "gap": gap, "rect": Rect2(cx2, y - h * 0.5 - 2.0, cw2, h + 4.0)})
			x += (cw2 + gap) if left else -(cw2 + gap)
	return out


## The touch targets of the row: name to global rectangle (empty unless touch).
static func touch_rects(m: UiFighterModel, rect: Rect2, s: float, o: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if not bool(o.get("touch", false)):
		return out
	for c in plan(m, rect, s, o):
		out[c["name"]] = c["rect"]
	return out


static func draw(ci: CanvasItem, m: UiFighterModel, rect: Rect2, s: float, o: Dictionary) -> void:
	var chips: Array = plan(m, rect, s, o)
	if chips.is_empty():
		return
	var touch: bool = bool(o.get("touch", false))
	var prompts_on: bool = bool(o.get("prompts", false))
	var style: String = str(o.get("glyph_style", "neutral"))
	var preset: String = UiHints.preset_id(m, o)
	var fade: float = 1.0 if (prompts_on or touch) else clampf((STANCE_SHOW - m.stance_prompt_t) * 4.0, 0.0, 1.0)
	UiText.no_outline = true
	for c in chips:
		var r: Rect2 = c["rect"]
		var h: float = c["h"]
		var y: float = c["y"]
		var gap: float = c["gap"]
		if c["kind"] == "stance":
			var i: int = c["i"]
			var current: bool = i == m.stance
			UiIcons.rrect(ci, r, h * 0.25, Color(UiLook.col(UiLook.SCRIM), (0.75 if current else 0.5) * fade), Color(UiLook.stance_col(i), (0.95 if current else 0.35) * fade), 2.0 if current else 1.2)
			if touch:
				# The stance ring: the icon alone, big, centred in a square target, and the weight mark on the current stance.
				UiIcons.stance(ci, i, r.get_center(), h * 0.55, Color(UiLook.stance_col(i), fade))
				if current:
					var heavy_t: bool = m.weight == "heavy"
					UiReads.weight_mark(ci, Vector2(r.end.x - h * 0.3, r.position.y + h * 0.2), h * 0.4, heavy_t, Color(UiLook.col(UiLook.INK), fade), heavy_t and m.weight_fallback_t < 1.5)
			else:
				UiIcons.stance(ci, i, Vector2(r.position.x + h * 0.55, y), h * 0.72, Color(UiLook.stance_col(i), fade))
				# GUARD and DODGE show the control that holds them in this layout; the current chip is told apart by its border and fill.
				if STANCE_ACTIONS[i] != "":
					UiGlyphs.draw(ci, STANCE_ACTIONS[i], m.device, m.slot, Vector2(r.position.x + h + gap * 0.3, y), h * 0.8, fade, true, style, preset)
		elif c["kind"] == "weight":
			UiIcons.rrect(ci, r, h * 0.25, Color(UiLook.col(UiLook.SCRIM), 0.6 * fade), Color(UiLook.col(UiLook.EDGE), 0.4 * fade), 1.2)
			var heavy: bool = m.weight == "heavy"
			UiReads.weight_mark(ci, r.get_center(), h * 0.66, heavy, Color(UiLook.col(UiLook.INK), fade), heavy and m.weight_fallback_t < 1.5)
		else:
			var act: String = c["act"]
			UiIcons.rrect(ci, r, h * 0.25, Color(UiLook.col(UiLook.SCRIM), 0.65), Color(UiLook.col(UiLook.EDGE), 0.5), 1.4)
			var gx: float = r.position.x + gap
			UiGlyphs.draw(ci, act, m.device, m.slot, Vector2(gx, y), h * 0.8, 1.0, true, style, preset)
			UiGlyphs.hold_ring(ci, Vector2(gx + float(c["gw"]) * 0.5, y), h * 0.55, float(m.hold[act]), 1.0)
			if str(c["word"]) != "":
				UiText.draw(ci, str(c["word"]), Vector2(gx + float(c["gw"]) + gap, y + float(c["fs"]) * 0.35), int(c["fs"]), Color(UiLook.col(UiLook.INK), 1.0), -1)
	UiText.no_outline = false
