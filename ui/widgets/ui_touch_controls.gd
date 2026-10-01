class_name UiTouchControls
extends RefCounted
## The on-screen controls of touch Simple (docs/controls/touch-bridge.md, ADR 0008): ATTACK (tap a light, hold a heavy, swipe up the
## signature), GUARD (hold) and POWER (hold to charge), drawn from `SimTouch.layout()`, the same call with the same inputs as the
## host's touch_layout(), so what is drawn is what is hit. A floating stick appears where the left thumb lands. There is no context
## button in this build; its slot carries a TRANSFORM button when the fighter can transform (the host hit-tests it as "context" until
## Controls gives it a name). The HUD never takes a touch itself: Controls' SimTouch does, and UI's pause and feedback targets win.
##
## `state` comes from the host (UiHud.touch_state_fn): {attack: {down, hold 0..1}, guard: {down}, power: {down}, stick: {active, base,
## thumb, sprint}, transform: {down}}. Without it every button is drawn idle. For the first seconds of a match (or while prompts are
## on) each button carries its word and the gesture ("TAP  HOLD  SWIPE UP"); a pressed button fills, Attack's ring fills over its 12
## ticks (it becomes a heavy), Power shows a ring while it charges, and the stick draws its base ring and thumb.

const HOLD_TICKS := 12.0
const NAMES: Array = ["attack", "guard", "power"]


## The circle {x, y, r} of a control, or {} (attack, guard, power, context).
static func circle(lay: UiLayout, name: String) -> Dictionary:
	return lay.touch_ctrl.get(name, {})


static func rect_of(c: Dictionary) -> Rect2:
	if c.is_empty():
		return Rect2()
	return Rect2(float(c.x) - float(c.r), float(c.y) - float(c.r), float(c.r) * 2.0, float(c.r) * 2.0)


## The redraw key: the pressed bits, the hold ring in twelfths, the stick (quantised to 2 px), the captions' alpha and Transform's state.
static func sig(lay: UiLayout, state: Dictionary, intro_a: float, transform_avail: bool) -> Array:
	var bits := 0
	var i := 0
	for n in NAMES:
		if bool((state.get(n, {}) as Dictionary).get("down", false)):
			bits |= (1 << i)
		i += 1
	if bool((state.get("transform", {}) as Dictionary).get("down", false)):
		bits |= (1 << 3)
	var st: Dictionary = state.get("stick", {})
	var sk: Array = []
	if bool(st.get("active", false)):
		var b: Vector2 = st.get("base", Vector2.ZERO)
		var t: Vector2 = st.get("thumb", Vector2.ZERO)
		sk = [int(b.x * 0.5), int(b.y * 0.5), int(t.x * 0.5), int(t.y * 0.5), bool(st.get("sprint", false))]
	return [int(lay.vp.x), int(lay.vp.y), int(lay.dp * 100.0), lay.left_handed, bits, int(float((state.get("attack", {}) as Dictionary).get("hold", 0.0)) * HOLD_TICKS), sk, int(intro_a * 10.0), transform_avail]


static func draw(ci: CanvasItem, lay: UiLayout, s: float, state: Dictionary, intro_a: float, transform_avail: bool) -> void:
	if lay.touch_ctrl.is_empty():
		return
	var ink := Color(UiLook.col(UiLook.INK))
	var dark := Color(UiLook.col(UiLook.INK_DARK))
	var edge := Color(UiLook.col(UiLook.EDGE))
	var scrim := Color(UiLook.col(UiLook.SCRIM))
	var line: float = maxf(2.0, 2.5 * s)
	UiText.no_outline = true
	# The floating stick, where the thumb landed.
	var st: Dictionary = state.get("stick", {})
	var rs: float = 56.0 * lay.dp
	if bool(st.get("active", false)):
		var b: Vector2 = st["base"]
		var th: Vector2 = st["thumb"]
		var off: Vector2 = th - b
		if off.length() > rs * 1.1:
			off = off.normalized() * rs * 1.1
		var sprint: bool = bool(st.get("sprint", false))
		ci.draw_circle(b, rs, Color(scrim, 0.35))
		ci.draw_arc(b, rs, 0.0, TAU, 40, Color(edge, 0.7 if sprint else 0.45), line * (2.0 if sprint else 1.0), true)
		ci.draw_circle(b + off, rs * 0.42, Color(ink, 0.55))
	elif intro_a > 0.01:
		# The first seconds: where the stick will be, and what a flick does.
		var z: Dictionary = lay.touch_ctrl.get("stick", {})
		if not z.is_empty():
			var zc := Vector2((float(z.x0) + float(z.x1)) * 0.5, float(z.y0) + (float(z.y1) - float(z.y0)) * 0.32)
			ci.draw_arc(zc, rs * 0.8, 0.0, TAU, 32, Color(edge, 0.3 * intro_a), line, true)
			var fs0: int = UiText.px(16.0, s)
			UiText.draw(ci, UiData.t("prompt.move"), Vector2(zc.x, zc.y - UiText.height(fs0) * 0.5 + UiText.ascent(fs0) - float(fs0) * 0.6), fs0, Color(ink, 0.8 * intro_a), 0)
			UiText.draw(ci, UiData.t("prompt.move_hint"), Vector2(zc.x, zc.y - UiText.height(fs0) * 0.5 + UiText.ascent(fs0) + float(fs0) * 0.6), fs0, Color(ink, 0.6 * intro_a), 0)
	# The three buttons.
	for n in NAMES:
		var c: Dictionary = lay.touch_ctrl.get(n, {})
		if c.is_empty():
			continue
		var bs: Dictionary = state.get(n, {})
		var down: bool = bool(bs.get("down", false))
		var p := Vector2(float(c.x), float(c.y))
		var r: float = float(c.r)
		ci.draw_circle(p, r, Color(ink, 0.88) if down else Color(scrim, 0.58))
		ci.draw_arc(p, r, 0.0, TAU, 40, Color(edge, 0.9), line, true)
		var icol: Color = dark if down else ink
		match n:
			"attack":
				UiIcons.star4(ci, p, r * 1.05, icol)
				var hold: float = clampf(float(bs.get("hold", 0.0)), 0.0, 1.0)
				if down and hold > 0.0:
					ci.draw_arc(p, r * 1.14, -PI * 0.5, -PI * 0.5 + TAU * hold, 40, Color(UiLook.col(UiLook.WARN)), maxf(3.0, r * 0.1), true)
			"guard":
				UiIcons.stance(ci, 1, p, r * 1.0, dark if down else UiLook.stance_col(1))
			"power":
				UiIcons.caret_up(ci, p + Vector2(0.0, r * 0.1), r * 0.95, icol)
				if down:
					ci.draw_arc(p, r * 1.14, 0.0, TAU, 40, Color(UiLook.col(UiLook.CHARGE)), maxf(3.0, r * 0.1), true)
		if intro_a > 0.01:
			var fs: int = UiText.px(15.0, s)
			var lh: float = UiText.height(fs)
			var word: String = UiData.t("prompt." + n)
			var hint: String = UiData.t("prompt." + n + "_hint")
			if lay.portrait:
				# Portrait is tight: Power's word goes to its left, Attack's and Guard's below; only Attack keeps its gesture line.
				if n == "power":
					UiText.draw(ci, word, Vector2(p.x - r - 8.0 * lay.dp, p.y - lh * 0.5 + UiText.ascent(fs)), fs, Color(ink, 0.95 * intro_a), 1)
				else:
					var by: float = p.y + r + UiText.ascent(fs) + float(fs) * 0.1
					UiText.draw(ci, word, Vector2(p.x, by), fs, Color(ink, 0.95 * intro_a), 0)
					if n == "attack":
						UiText.draw(ci, hint, Vector2(p.x, by + lh), fs, Color(ink, 0.7 * intro_a), 0)
			else:
				# Landscape: Power's words go above it (Attack sits just under it); Attack's and Guard's go below.
				var top: float = (p.y - r - lh * 2.0 - 2.0) if n == "power" else (p.y + r + float(fs) * 0.1)
				var base: float = top + UiText.ascent(fs)
				UiText.draw(ci, word, Vector2(p.x, base), fs, Color(ink, 0.95 * intro_a), 0)
				UiText.draw(ci, hint, Vector2(p.x, base + lh), fs, Color(ink, 0.7 * intro_a), 0)
	# TRANSFORM, in the context button's slot, only while it can be used.
	if transform_avail:
		var tc: Dictionary = lay.touch_ctrl.get("context", {})
		if not tc.is_empty():
			var tp := Vector2(float(tc.x), float(tc.y))
			var tr: float = float(tc.r)
			var tdown: bool = bool((state.get("transform", {}) as Dictionary).get("down", false))
			ci.draw_circle(tp, tr, Color(ink, 0.88) if tdown else Color(scrim, 0.62))
			ci.draw_arc(tp, tr, 0.0, TAU, 40, Color(edge, 0.9), line, true)
			ci.draw_arc(tp, tr * 0.72, 0.0, TAU, 32, dark if tdown else Color(ink, 0.8), line, true)
			UiIcons.star4(ci, tp, tr * 0.8, dark if tdown else ink)
			if intro_a > 0.01:
				var fs2: int = UiText.px(15.0, s)
				UiText.draw(ci, UiData.t("prompt.transform"), Vector2(tp.x, tp.y - tr - float(fs2) * 0.4), fs2, Color(ink, 0.95 * intro_a), 0)
	UiText.no_outline = false
