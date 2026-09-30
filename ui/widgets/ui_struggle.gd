class_name UiStruggle
## The finisher struggle's beat rings, shown around the fighter on the brink. The struggle is resolved by state now (Game Design, Q4):
## the sim has already drawn the result, and three pulses at the beats (18, 36 and 54 ticks after the contest opens, with a count-in
## at -18 and 0 so the tempo shows) reveal it step by step. This is a beat to watch, not a press to make: no prompt, no timing window.
##
## One ring closes on a fixed target ring for each beat, arriving exactly on the beat tick. When a pulse arrives (`struggle_pulse`:
## holding or slipping) its ring leaves a shape at the target for a moment, a star for HOLDING and a cross for SLIPPING, and the
## tally pip under the ring fills the same way; the last word (HOLDING or SLIPPING) is printed under the pips. No survival
## percentage, no number: the chance is never shown. Every beat also has an audio tick (Audio); this ring and the word carry the
## same information. Reduced motion keeps the shapes and steps the ring instead of easing it.

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
	var c: Vector2 = anchor["pos"]
	var R: float = UiCrown.radius(float(anchor.get("h", 90.0)), s)
	var target_r: float = R * 1.2
	var span: float = R * 0.9
	var speed: float = span / PERIOD           # px of ring travel per tick
	var band: float = maxf(3.0 * s, 3.0)   # the target ring's soft edge: a landing mark, not a timing window
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
	# What the pulses have shown so far, in words as well as shapes.
	var last: String = str(st.get("last", ""))
	if last != "":
		var fs: int = UiText.px(22.0, s)
		UiText.draw(ci, UiData.t("state." + last), Vector2(c.x, py + pip * 2.0 + UiText.ascent(fs)), fs, Color(ink, a_all), 0, 2.0)


## The redraw key: every frame while it runs (the rings move), so it is just a frame counter; null when idle.
static func sig(hub: UiEventHub, frame: int):
	return frame if active(hub) else null
