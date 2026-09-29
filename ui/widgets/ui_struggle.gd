class_name UiStruggle
## The finisher struggle's beat rings (docs/controls/rulings.md section 8), shown around the fighter on the brink, the one
## who must press. Three timed presses on a visible rhythm, 300 ms apart: the beats are at 18, 36 and 54 ticks after the
## contest opens, with a count-in at -18 and 0 so the tempo shows before the first scored beat.
##
## One ring closes on a fixed target ring for each beat, arriving exactly on the beat tick. The target ring is a BAND: its
## width is the on-beat window (+-4 ticks, +-8 with the assist), so a player sees how forgiving it is, and the assist
## visibly doubles it. A beat's result stays as a shape at the target for a moment: a star for a hit, a cross for a miss.
## Three pips under the ring keep the tally (a star, a cross, or an open ring while pending). No survival percentage, no
## number: the contest's chance is never shown. Every beat also has an audio tick and a rumble (Audio and Controls); this
## ring carries the same information and nothing else does. Reduced motion keeps the shapes and steps the ring instead of easing it.

const PERIOD := 18.0        # ticks between beats
const LINGER := 22.0        # ticks a beat's result mark stays after it


static func active(hub: UiEventHub) -> bool:
	return not hub.struggle.is_empty()


## The ring radius for a beat `ticks_to` ticks away (18 or more: the outer edge; 0: on the target), `span` px of travel.
static func ring_radius(target_r: float, span: float, ticks_to: float, stepped: bool) -> float:
	var frac: float = clampf(ticks_to / PERIOD, 0.0, 1.0)
	if stepped:
		frac = ceilf(frac * 3.0) / 3.0
	return target_r + span * frac


static func draw(ci: CanvasItem, hub: UiEventHub, lay: UiLayout, anchor: Dictionary, s: float, o: Dictionary) -> void:
	var st: Dictionary = hub.struggle
	if st.is_empty() or anchor.is_empty() or not bool(anchor.get("visible", true)):
		return
	var m: UiFighterModel = hub.model(int(st["actor"]))
	var c: Vector2 = anchor["pos"]
	var R: float = UiCrown.radius(float(anchor.get("h", 90.0)), s)
	var target_r: float = R * 1.2
	var span: float = R * 0.9
	var speed: float = span / PERIOD           # px of ring travel per tick
	var half: float = float(st["half"])
	var band: float = maxf(2.0 * half * speed, 4.0)
	var now: float = float(st["t"]) / UiEventHub.TICK
	var reduced: bool = bool(o.get("reduced_motion", false))
	var ink := Color(UiLook.col(UiLook.INK), 1.0)
	var dark := Color(UiLook.col(UiLook.INK_DARK), 0.55)
	var a_all: float = clampf((now + PERIOD) / 6.0, 0.0, 1.0)   # fades in over the first six ticks
	# The on-beat band, and the target ring inside it.
	ci.draw_arc(c, target_r, 0.0, TAU, 56, Color(ink, 0.2 * a_all), band, true)
	ci.draw_arc(c, target_r, 0.0, TAU, 56, Color(dark, 0.6 * a_all), maxf(3.0, 3.0 * s) + 2.0, true)
	ci.draw_arc(c, target_r, 0.0, TAU, 56, Color(ink, 0.85 * a_all), maxf(2.0, 2.5 * s), true)
	var w: float = maxf(3.0, 3.5 * s)
	var scored: Array = []
	for b in st["beats"]:
		var bt: float = float(b)
		var count_in: bool = bt <= 0.0
		if not count_in:
			scored.append(int(b))
		var to: float = bt - now
		if to > PERIOD or to < -LINGER:
			continue
		if to >= 0.0:
			var r: float = ring_radius(target_r, span, to, reduced)
			var a: float = (0.45 if count_in else 1.0) * a_all
			ci.draw_arc(c, r, 0.0, TAU, 56, Color(dark, a), w + 2.0, true)
			ci.draw_arc(c, r, 0.0, TAU, 56, Color(ink, a), w, true)
		elif not count_in:
			# After the beat: its result at the top of the target ring, fading.
			var res: String = str(st["res"].get(int(b), ""))
			if res != "":
				var fa: float = clampf(1.0 - (-to) / LINGER, 0.0, 1.0)
				UiGlyphs.draw_ack(ci, "hit" if res == "hit" else "miss", c + Vector2(0.0, -target_r), maxf(22.0 * s, 20.0), fa)
	# The tally: one pip per scored beat under the ring.
	scored.sort()
	var pip: float = maxf(11.0 * s, 9.0)
	var gap: float = pip * 2.6
	var py: float = c.y + target_r + band * 0.5 + pip * 1.6
	for i in range(scored.size()):
		var res: String = str(st["res"].get(scored[i], ""))
		var p := Vector2(c.x + (float(i) - float(scored.size() - 1) * 0.5) * gap, py)
		match res:
			"hit":
				UiIcons.star4(ci, p, pip * 2.0, Color(ink, a_all))
			"miss":
				UiGlyphs.draw_ack(ci, "miss", p, pip * 1.8, a_all)
			_:
				ci.draw_arc(p, pip * 0.6, 0.0, TAU, 12, Color(ink, 0.8 * a_all), maxf(1.5, 1.6 * s), true)
	# The prompt: the light glyph large, the heavy glyph small ("either counts"), when prompts are on.
	if bool(o.get("prompts", false)) and m != null and not m.ai:
		var fam: String = m.device
		var style: String = str(o.get("glyph_style", "neutral"))
		var gh: float = maxf(28.0 * s, 22.0)
		var y: float = py + pip * 2.4 + gh * 0.5
		var w1: float = UiGlyphs.width("light", fam, m.slot, gh, style)
		var w2: float = UiGlyphs.width("heavy", fam, m.slot, gh * 0.7, style)
		var x0: float = c.x - (w1 + gh * 0.3 + w2) * 0.5
		UiGlyphs.draw(ci, "light", fam, m.slot, Vector2(x0, y), gh, a_all, true, style)
		UiGlyphs.draw(ci, "heavy", fam, m.slot, Vector2(x0 + w1 + gh * 0.3, y), gh * 0.7, 0.8 * a_all, true, style)


## The redraw key: every frame while it runs (the rings move), so it is just a frame counter; null when idle.
static func sig(hub: UiEventHub, frame: int):
	return frame if active(hub) else null
