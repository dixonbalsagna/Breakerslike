class_name UiPrompts
## The prompt row under each fighter's column (docs/controls/prompt-glyphs.md section 4): the stance prompt (the four stances
## with the glyph for each on the player's device, the current one filled), and the hold prompts for actions that can be used
## right now (Special and Transform, with a ring that fills while the button is held). It draws nothing at rest:
##   - the stance prompt shows for 3 s at the start of a match and whenever the stance changes, and always while prompts are on;
##   - Special and Transform show only while their action is available, and only while prompts are on.
## Prompts are drawn here and on the crown windows and the struggle rings, never over the fighters. Glyphs are the neutral set
## of the fighter's own device (UiGlyphs). "Prompts on" is the Show prompts option, which the host also turns on in training
## and in the first three matches.

const STANCE_ACTIONS: Array = ["stance_press", "stance_guard", "stance_dodge", "stance_escape"]
const STANCE_SHOW := 3.0


static func stance_visible(m: UiFighterModel, prompts_on: bool) -> bool:
	return prompts_on or m.stance_prompt_t < STANCE_SHOW


## Whether the row has anything to draw for this fighter.
static func has_content(m: UiFighterModel, prompts_on: bool) -> bool:
	if m.ai:
		return false   # an AI fighter has no device: nothing to prompt
	return stance_visible(m, prompts_on) or (prompts_on and (m.avail["transform"] or m.avail["special"]))


## The redraw key for the row.
static func sig(m: UiFighterModel, prompts_on: bool) -> Array:
	var fade: int = int(clampf((STANCE_SHOW - m.stance_prompt_t) * 4.0, 0.0, 4.0)) if not prompts_on else 4
	return [m.stance, m.device, prompts_on, stance_visible(m, prompts_on), fade, m.avail["transform"], m.avail["special"], int(m.hold["transform"] * 30.0), int(m.hold["special"] * 30.0)]


static func draw(ci: CanvasItem, m: UiFighterModel, rect: Rect2, s: float, o: Dictionary) -> void:
	var prompts_on: bool = bool(o.get("prompts", false))
	if rect.size.y <= 0.0 or not has_content(m, prompts_on):
		return
	var style: String = str(o.get("glyph_style", "neutral"))
	var left: bool = m.left_side
	var h: float = minf(maxf(26.0 * s, 20.0), rect.size.y * 0.8)
	var y: float = rect.position.y + rect.size.y * 0.5
	var gap: float = maxf(6.0 * s, 4.0)
	var x: float = rect.position.x if left else rect.end.x
	var fade: float = 1.0 if prompts_on else clampf((STANCE_SHOW - m.stance_prompt_t) * 4.0, 0.0, 1.0)
	UiText.no_outline = true
	# The stance prompt: [icon glyph] x4, the current one on a lit chip.
	if stance_visible(m, prompts_on):
		for i in range(4):
			var gw: float = UiGlyphs.width(STANCE_ACTIONS[i], m.device, m.slot, h * 0.8, style)
			var cw: float = h + gw + gap * 1.5
			var cx: float = x if left else x - cw
			var current: bool = i == m.stance
			UiIcons.rrect(ci, Rect2(cx, y - h * 0.5 - 2.0, cw, h + 4.0), h * 0.25, Color(UiLook.col(UiLook.SCRIM), (0.75 if current else 0.5) * fade), Color(UiLook.stance_col(i), (0.95 if current else 0.35) * fade), 2.0 if current else 1.2)
			UiIcons.stance(ci, i, Vector2(cx + h * 0.55, y), h * 0.72, Color(UiLook.stance_col(i), fade))
			# Every chip shows its own bound position solid; the current chip is told apart by its border and fill.
			UiGlyphs.draw(ci, STANCE_ACTIONS[i], m.device, m.slot, Vector2(cx + h + gap * 0.3, y), h * 0.8, fade, true, style)
			x += (cw + gap) if left else -(cw + gap)
	# The hold prompts, only while the action can be used.
	if prompts_on:
		for act in ["special", "transform"]:
			if not m.avail[act]:
				continue
			var word: String = UiData.t("prompt." + act)
			var fs: int = UiText.px(18.0, s)
			var tw: float = UiText.width(word, fs)
			var gw2: float = UiGlyphs.width(act, m.device, m.slot, h * 0.8, style)
			var cw2: float = gw2 + tw + gap * 3.0 + h * 0.4
			var cx2: float = x if left else x - cw2
			UiIcons.rrect(ci, Rect2(cx2, y - h * 0.5 - 2.0, cw2, h + 4.0), h * 0.25, Color(UiLook.col(UiLook.SCRIM), 0.65), Color(UiLook.col(UiLook.EDGE), 0.5), 1.4)
			var gx: float = cx2 + gap
			UiGlyphs.draw(ci, act, m.device, m.slot, Vector2(gx, y), h * 0.8, 1.0, true, style)
			UiGlyphs.hold_ring(ci, Vector2(gx + gw2 * 0.5, y), h * 0.55, float(m.hold[act]), 1.0)
			UiText.draw(ci, word, Vector2(gx + gw2 + gap, y + float(fs) * 0.35), fs, Color(UiLook.col(UiLook.INK), 1.0), -1)
			x += (cw2 + gap) if left else -(cw2 + gap)
	UiText.no_outline = false
