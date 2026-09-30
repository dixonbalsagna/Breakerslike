class_name UiReads
extends RefCounted
## The reads the player must always be able to see (Game Design, Q4: the director times every blow, so the player's skill is reading
## and answering): the rival's stance (the plate's stance chip), their weight (the weight mark), and the finisher's kind while it
## winds up. This file draws the last two marks and the tutorial's hint line. Nothing here is an input prompt.
##
##   - The weight mark: a little barbell, small and thin for LIGHT, big and heavy for HEAVY. It sits on the plate and on the stance
##     ring, never colour alone (its size and its word carry it), and a fallback (a heavy strike that fell to light for lack of
##     Charge) shows the heavy mark struck through with LOW CHARGE for a moment.
##   - The finisher telegraph: a chip in the banner slot for the whole wind-up: the kind's icon and "FINISHER: BEAM" (LAUNCH, MELEE,
##     BEAM). With prompts on (the tutorial and the first matches) it adds the stance that answers it. This is the contract; Rendering's
##     diegetic cue (a distinct wind-up silhouette per kind) is the second channel, for players who look at the fighters, not the chip.
##   - The hint line: Narrative's tutorial hints, in the same slot: the line, a dot for each beat, and a dimmer style for a nudge and
##     a check mark for a done line. Text plus an icon, never colour alone.

const ICON_INK := "#f4f1ea"


## The barbell weight mark, centred at c, about `size` wide. `fallback` strikes it through.
static func weight_mark(ci: CanvasItem, c: Vector2, size: float, heavy: bool, col: Color, fallback: bool = false) -> void:
	var bar: float = size * 0.36
	var r: float = size * (0.2 if heavy else 0.1)
	var w: float = maxf(2.0, size * (0.15 if heavy else 0.07))
	ci.draw_line(c - Vector2(bar, 0.0), c + Vector2(bar, 0.0), col, w)
	ci.draw_circle(c - Vector2(bar, 0.0), r, col)
	ci.draw_circle(c + Vector2(bar, 0.0), r, col)
	if fallback:
		UiIcons.line(ci, c + Vector2(-bar, size * 0.34), c + Vector2(bar, -size * 0.34), maxf(2.0, size * 0.12), Color(UiLook.col(UiLook.WARN), col.a))


## The finisher kinds' icons: launch (an arrow rising from a base), melee (a burst), beam (a line ending in a point, charged at the tail).
static func kind_icon(ci: CanvasItem, kind: String, c: Vector2, sz: float, col: Color) -> void:
	var w: float = maxf(2.0, sz * 0.1)
	var s: float = sz * 0.5
	match kind:
		"launch":
			UiIcons.line(ci, c + Vector2(0.0, s * 0.8), c + Vector2(0.0, -s * 0.3), w, col)
			UiIcons.fill_poly(ci, PackedVector2Array([c + Vector2(0.0, -s), c + Vector2(-s * 0.55, -s * 0.25), c + Vector2(s * 0.55, -s * 0.25)]), col)
			UiIcons.line(ci, c + Vector2(-s * 0.55, s * 0.9), c + Vector2(s * 0.55, s * 0.9), w, col)
		"melee":
			UiIcons.star4(ci, c, sz * 0.75, col)
			for k in range(4):
				var d: Vector2 = Vector2.from_angle(PI * 0.25 + float(k) * PI * 0.5)
				UiIcons.line(ci, c + d * s * 0.75, c + d * s * 1.05, w, col)
		"beam":
			ci.draw_circle(c + Vector2(-s * 0.75, 0.0), s * 0.26, col)
			UiIcons.line(ci, c + Vector2(-s * 0.45, 0.0), c + Vector2(s * 0.45, 0.0), w * 1.6, col)
			UiIcons.fill_poly(ci, PackedVector2Array([c + Vector2(s * 1.0, 0.0), c + Vector2(s * 0.35, -s * 0.5), c + Vector2(s * 0.35, s * 0.5)]), col)


# --- The finisher telegraph ---------------------------------------------------------------------------------------------------

static func telegraph_sig(hub: UiEventHub, prompts: bool, reduced: bool):
	if hub.telegraph.is_empty():
		return null
	return [str(hub.telegraph["kind"]), prompts, 0 if reduced else int(float(hub.telegraph["age"]) * 5.0)]


static func draw_telegraph(ci: CanvasItem, hub: UiEventHub, lay: UiLayout, s: float, prompts: bool, reduced: bool) -> void:
	var t: Dictionary = hub.telegraph
	var slot: Rect2 = lay.read_slot
	if t.is_empty() or slot.size.y <= 0.0:
		return
	var kind: String = str(t["kind"])
	var fs: int = UiText.px(24.0, s)
	var label: String = UiData.t("state.finisher") + ": " + UiData.t("state.finisher_" + kind)
	var sz: float = minf(slot.size.y * 0.72, maxf(float(fs) * 1.5, 26.0))
	var pad: float = maxf(10.0 * s, 6.0)
	var tw: float = UiText.width(label, fs)
	var counter: String = str((UiData.reads().get("finisher_counter", {}) as Dictionary).get(kind, ""))
	var ci_idx: int = UiPlate.STANCE_IDS.find(counter)
	var answer: String = UiData.t("state.answer")
	var aw: float = UiText.width(answer, int(float(fs) * 0.85))
	var w: float = pad + sz + pad * 0.8 + tw + pad
	if prompts and ci_idx >= 0:
		w += pad + aw + pad * 0.6 + sz * 0.9 + pad * 0.4
	w = minf(w, slot.size.x)
	var h: float = minf(slot.size.y - 2.0, maxf(sz, float(fs) * 1.3) + pad)
	var r := Rect2(slot.get_center().x - w * 0.5, slot.get_center().y - h * 0.5, w, h)
	var pulse: float = 1.0 if reduced else 0.7 + 0.3 * sin(float(t["age"]) * TAU * 1.2)
	UiText.no_outline = true
	UiIcons.rrect(ci, r, h * 0.3, Color(UiLook.col(UiLook.SCRIM), 0.9), Color(UiLook.col(UiLook.WARN), pulse), maxf(2.0, 2.5 * s))
	var ink := Color(UiLook.col(UiLook.INK))
	kind_icon(ci, kind, Vector2(r.position.x + pad + sz * 0.5, r.get_center().y), sz, ink)
	var tx: float = r.position.x + pad + sz + pad * 0.8
	UiText.draw(ci, label, Vector2(tx, r.get_center().y - UiText.height(fs) * 0.5 + UiText.ascent(fs)), fs, ink, -1)
	if prompts and ci_idx >= 0 and r.end.x - tx - tw > aw + sz:
		var ax: float = tx + tw + pad
		UiText.draw(ci, answer, Vector2(ax, r.get_center().y + float(fs) * 0.3), int(float(fs) * 0.85), Color(UiLook.col(UiLook.INK_DIM)), -1)
		UiIcons.stance(ci, ci_idx, Vector2(ax + aw + pad * 0.6 + sz * 0.45, r.get_center().y), sz * 0.85, UiLook.stance_col(ci_idx))
	UiText.no_outline = false


# --- The tutorial hint line ---------------------------------------------------------------------------------------------------

static func hint_sig(hub: UiEventHub):
	if hub.hint.is_empty() or not hub.telegraph.is_empty() or not hub.banner.is_empty():
		return null
	var dots := 0
	var ids: Array = UiData.reads().get("beat_ids", [])
	for i in range(ids.size()):
		var st: String = str(hub.beats.get(ids[i], ""))
		dots |= ((1 if st == "start" else (2 if (st == "done" or st == "skipped") else 0)) << (i * 2))
	return [str(hub.hint["text"]), str(hub.hint["kind"]), int(hub.hint_alpha() * 12.0), dots]


static func draw_hint(ci: CanvasItem, hub: UiEventHub, lay: UiLayout, s: float) -> void:
	var slot: Rect2 = lay.read_slot
	if hub.hint.is_empty() or slot.size.y <= 0.0:
		return
	var a: float = hub.hint_alpha()
	if a <= 0.01:
		return
	var kind: String = str(hub.hint["kind"])
	var text: String = str(hub.hint["text"])
	var ids: Array = UiData.reads().get("beat_ids", [])
	var pad: float = maxf(10.0 * s, 6.0)
	var dot_r: float = maxf(3.0, 3.6 * s)
	var dots_h: float = dot_r * 2.0 + pad * 0.5 if not ids.is_empty() else 0.0
	var fs: int = UiText.px(24.0, s)
	var isz: float = maxf(float(fs) * 1.25, 22.0)
	var lines: PackedStringArray = UiText.wrap(text, fs, slot.size.x - isz - pad * 3.0)
	# Two lines at most; shrink the type toward its floor until the line and the dots fit the slot.
	while (lines.size() > 2 or float(lines.size()) * UiText.height(fs) * 1.1 + dots_h + pad > slot.size.y - 2.0) and fs > int(UiLook.text_floor):
		fs -= 1
		lines = UiText.wrap(text, fs, slot.size.x - isz - pad * 3.0)
		isz = maxf(float(fs) * 1.25, 22.0)
	var lh: float = UiText.height(fs) * 1.1
	var tw: float = 0.0
	for ln in lines:
		tw = maxf(tw, UiText.width(ln, fs))
	var w: float = minf(slot.size.x, pad + isz + pad * 0.8 + tw + pad)
	var h: float = minf(slot.size.y - 2.0, float(lines.size()) * lh + dots_h + pad * 1.2)
	var r := Rect2(slot.get_center().x - w * 0.5, slot.get_center().y - h * 0.5, w, h)
	var nudge: bool = kind == "nudge"
	var border := Color(UiLook.col(UiLook.WARN if nudge else UiLook.EDGE), (0.95 if nudge else 0.55) * a)
	var ink := Color(UiLook.col(UiLook.INK), a)
	UiText.no_outline = true
	UiIcons.rrect(ci, r, minf(h * 0.3, 14.0 * s), Color(UiLook.col(UiLook.SCRIM), 0.86 * a), border, maxf(1.5, 2.0 * s))
	var ic := Vector2(r.position.x + pad + isz * 0.5, r.position.y + pad * 0.6 + float(lh) * 0.5)
	_hint_icon(ci, kind, ic, isz, a)
	var ty: float = r.position.y + pad * 0.6 + UiText.ascent(fs) + (lh - UiText.height(fs)) * 0.5
	for ln in lines:
		UiText.draw(ci, ln, Vector2(r.position.x + pad + isz + pad * 0.8, ty), fs, ink, -1)
		ty += lh
	# One dot per beat: a filled dot for a beat done, a ring for the one that is open, a faint ring for the rest.
	if not ids.is_empty():
		var step: float = dot_r * 3.2
		var x0: float = r.get_center().x - step * float(ids.size() - 1) * 0.5
		var y: float = r.end.y - pad * 0.45 - dot_r
		for i in range(ids.size()):
			var st: String = str(hub.beats.get(ids[i], ""))
			var p := Vector2(x0 + step * float(i), y)
			if st == "done" or st == "skipped":
				ci.draw_circle(p, dot_r, Color(ink, 0.95))
			elif st == "start":
				ci.draw_arc(p, dot_r * 1.1, 0.0, TAU, 14, ink, maxf(1.5, dot_r * 0.5), true)
			else:
				ci.draw_arc(p, dot_r * 0.85, 0.0, TAU, 12, Color(ink, 0.35), maxf(1.2, dot_r * 0.35), true)
	UiText.no_outline = false


## The hint's icon: an "i" in a circle (a hint), a triangle with a mark (a nudge) or a check (done).
static func _hint_icon(ci: CanvasItem, kind: String, c: Vector2, sz: float, a: float) -> void:
	var w: float = maxf(2.0, sz * 0.1)
	var r: float = sz * 0.46
	match kind:
		"nudge":
			var col := Color(UiLook.col(UiLook.WARN), a)
			ci.draw_polyline(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r * 0.95, r * 0.8), c + Vector2(-r * 0.95, r * 0.8), c + Vector2(0.0, -r)]), col, w, true)
			UiIcons.line(ci, c + Vector2(0.0, -r * 0.3), c + Vector2(0.0, r * 0.3), w, col)
			ci.draw_circle(c + Vector2(0.0, r * 0.58), w * 0.7, col)
		"done":
			var col2 := Color(UiLook.col(UiLook.INK), a)
			ci.draw_arc(c, r, 0.0, TAU, 24, Color(col2, 0.5), w, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.5, 0.0), c + Vector2(-r * 0.1, r * 0.42), c + Vector2(r * 0.55, -r * 0.4)]), col2, w * 1.3, true)
		_:
			var col3 := Color(UiLook.col(UiLook.INK), a)
			ci.draw_arc(c, r, 0.0, TAU, 24, col3, w, true)
			UiIcons.line(ci, c + Vector2(0.0, -r * 0.05), c + Vector2(0.0, r * 0.5), w * 1.2, col3)
			ci.draw_circle(c + Vector2(0.0, -r * 0.42), w * 0.8, col3)
