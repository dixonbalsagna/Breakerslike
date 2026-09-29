class_name UiGlyphs
## Neutral prompt glyphs per device (docs/controls/prompt-glyphs.md) and the small press-acknowledged marks.
##
## A prompt shows the glyph of the device that last sent input for that slot (the host tells the HUD with
## UiHud.set_device). The default style is NEUTRAL: our own position diamond with a letter for the face buttons, plain text
## marks for triggers and bumpers, a small cross for the D-pad, a keycap for the keyboard. No console maker's icon art and no
## platform's face symbols until Legal answers (rule 7); the `family` style, which prints each family's own letters, is in the
## data and off. Every glyph has a shape or a letter, never colour alone; arrows are never characters.

const KBD := "kbd"


## What a glyph shows for an action on a device. Returns {kind, label, pos, dir}. `slot` picks the keyboard's P1 or P2 label;
## `style` is "neutral" (default) or "family". An unknown action returns an empty Dictionary.
static func spec(action: String, family: String, slot: int, style: String = "neutral") -> Dictionary:
	var g: Dictionary = UiData.glyphs()
	var a: Dictionary = (g.get("actions", {}) as Dictionary).get(action, {})
	if a.is_empty():
		return {}
	var kind: String = str(a.get("kind", "text"))
	if family == KBD or family == "touch":
		var labels: Array = a.get("kbd", [action.to_upper()])
		return {"kind": "key", "label": str(labels[clampi(slot, 0, labels.size() - 1)])}
	var tbl: Dictionary
	if style == "family" and (g.get("family_labels", {}) as Dictionary).has(family):
		tbl = g["family_labels"][family]
	else:
		var neutral: Dictionary = g.get("neutral", {})
		var pads: Dictionary = neutral.get("pad", {})
		tbl = {"face": neutral.get("face", {}), "LT": pads.get("LT", "LT"), "RT": pads.get("RT", "RT"), "LB": pads.get("LB", "LB"), "RB": pads.get("RB", "RB"), "R3": pads.get("R3", "R3")}
	match kind:
		"face":
			var pos: String = str(a.get("pos", "south"))
			return {"kind": "face", "pos": pos, "label": str((tbl.get("face", {}) as Dictionary).get(pos, "?"))}
		"pad":
			var pad: String = str(a.get("pad", ""))
			return {"kind": "pad", "label": str(tbl.get(pad, pad))}
		"dpad":
			return {"kind": "dpad", "dir": str(a.get("dir", "up")), "label": ""}
		"stick":
			return {"kind": "stick", "label": ""}
	return {"kind": "pad", "label": str(a.get("pad", ""))}


static func _fs(h: float) -> int:
	return maxi(int(UiLook.MIN_TEXT_PX), int(h * 0.55))


## The width a glyph takes at height h.
static func width(action: String, family: String, slot: int, h: float, style: String = "neutral") -> float:
	var sp: Dictionary = spec(action, family, slot, style)
	if sp.is_empty():
		return 0.0
	var fs: int = _fs(h)
	match sp["kind"]:
		"key":
			return maxf(h, UiText.width(sp["label"], fs) + h * 0.5)
		"face":
			return h + h * 0.12 + UiText.width(sp["label"], fs)
		"pad":
			return maxf(h * 1.1, UiText.width(sp["label"], fs) + h * 0.5)
	return h


## Draw a glyph with its left edge at `at.x` and its centre line at `at.y`. `on` fills the pressed position (the diamond's
## dot, the D-pad's arm). Returns the width drawn.
static func draw(ci: CanvasItem, action: String, family: String, slot: int, at: Vector2, h: float, alpha: float, on: bool = true, style: String = "neutral") -> float:
	var sp: Dictionary = spec(action, family, slot, style)
	if sp.is_empty():
		return 0.0
	var fs: int = _fs(h)
	var ink := Color(UiLook.col(UiLook.INK), alpha)
	var edge := Color(UiLook.col(UiLook.EDGE), 0.85 * alpha)
	var back := Color(UiLook.col(UiLook.SCRIM), 0.85 * alpha)
	var w: float = width(action, family, slot, h, style)
	var cy: float = at.y
	match sp["kind"]:
		"key":
			UiIcons.rrect(ci, Rect2(at.x, cy - h * 0.5, w, h), h * 0.22, back, edge, 1.5)
			UiText.draw(ci, sp["label"], Vector2(at.x + w * 0.5, cy + float(fs) * 0.35), fs, ink, 0)
		"face":
			# The position diamond: four dots at south, east, west and north; the pressed one filled. Then its letter.
			var c := Vector2(at.x + h * 0.5, cy)
			var r: float = h * 0.13
			var offs := {"south": Vector2(0, 1), "east": Vector2(1, 0), "west": Vector2(-1, 0), "north": Vector2(0, -1)}
			for k in offs:
				var p: Vector2 = c + (offs[k] as Vector2) * h * 0.34
				if k == sp["pos"] and on:
					ci.draw_circle(p, r * 1.15, ink)
				else:
					ci.draw_arc(p, r, 0.0, TAU, 12, edge, 1.5, true)
			UiText.draw(ci, sp["label"], Vector2(at.x + h + h * 0.12, cy + float(fs) * 0.35), fs, ink, -1)
		"pad":
			UiIcons.rrect(ci, Rect2(at.x, cy - h * 0.5, w, h), h * 0.3, back, edge, 1.5)
			UiText.draw(ci, sp["label"], Vector2(at.x + w * 0.5, cy + float(fs) * 0.35), fs, ink, 0)
		"dpad":
			var c2 := Vector2(at.x + h * 0.5, cy)
			# A plus: the bound arm solid near-white, the other three arms and the centre at about 35%, so the four stance
			# chips read as four different positions (Art, RL-037: no new glyph art).
			var cell: float = h * 0.32
			var dirs := {"up": Vector2(0, -1), "right": Vector2(1, 0), "down": Vector2(0, 1), "left": Vector2(-1, 0)}
			var dim := Color(UiLook.col(UiLook.INK), 0.35 * alpha)
			ci.draw_rect(Rect2(c2 - Vector2(cell, cell) * 0.5, Vector2(cell, cell)), dim)
			for k in dirs:
				var d: Vector2 = dirs[k]
				var p2: Vector2 = c2 + d * cell
				ci.draw_rect(Rect2(p2 - Vector2(cell, cell) * 0.5, Vector2(cell, cell)), ink if (k == sp["dir"] and on) else dim)
		"stick":
			var c3 := Vector2(at.x + h * 0.5, cy)
			ci.draw_arc(c3, h * 0.42, 0.0, TAU, 20, edge, 1.5, true)
			ci.draw_circle(c3, h * 0.14, ink)
	return w


## A ring that fills clockwise from the top: the hold prompt (transform fills over confirmTicks).
static func hold_ring(ci: CanvasItem, c: Vector2, r: float, frac: float, alpha: float) -> void:
	ci.draw_arc(c, r, 0.0, TAU, 24, Color(UiLook.col(UiLook.EDGE), 0.4 * alpha), maxf(2.0, r * 0.14), true)
	if frac > 0.0:
		ci.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(frac, 0.0, 1.0), 24, Color(UiLook.col(UiLook.INK), alpha), maxf(2.5, r * 0.2), true)


# --- Press-acknowledged marks (docs/controls/rulings.md section 8) ------------------------------------------------------------

const ACK_RESULTS: Array = ["hit", "early", "late", "stray", "locked", "miss"]


## A press mark at `c`, about `size` tall. Shapes, never colour alone:
##   hit    a filled four-point star       early  an open ring with a dash leading it (the press came before the beat)
##   late, miss and stray  a cross         locked a small square with a bar through it (the action was locked out)
static func draw_ack(ci: CanvasItem, result: String, c: Vector2, size: float, alpha: float) -> void:
	var ink := Color(UiLook.col(UiLook.INK), alpha)
	var dark := Color(UiLook.col(UiLook.INK_DARK), 0.7 * alpha)
	var w: float = maxf(2.5, size * 0.13)
	match result:
		"hit":
			UiIcons.star4(ci, c, size * 1.15, dark)
			UiIcons.star4(ci, c, size, ink)
		"early":
			ci.draw_arc(c, size * 0.36, 0.0, TAU, 16, dark, w + 2.0, true)
			ci.draw_arc(c, size * 0.36, 0.0, TAU, 16, ink, w, true)
			UiIcons.line(ci, c + Vector2(-size * 0.85, 0), c + Vector2(-size * 0.5, 0), w, ink)
		"locked":
			var r := Rect2(c - Vector2(size * 0.32, size * 0.32), Vector2(size * 0.64, size * 0.64))
			ci.draw_rect(r, dark, false, w + 2.0)
			ci.draw_rect(r, ink, false, w)
			UiIcons.line(ci, c + Vector2(-size * 0.32, 0), c + Vector2(size * 0.32, 0), w, ink)
		_:
			var d: float = size * 0.34
			UiIcons.line(ci, c + Vector2(-d, -d), c + Vector2(d, d), w + 2.0, dark)
			UiIcons.line(ci, c + Vector2(-d, d), c + Vector2(d, -d), w + 2.0, dark)
			UiIcons.line(ci, c + Vector2(-d, -d), c + Vector2(d, d), w, ink)
			UiIcons.line(ci, c + Vector2(-d, d), c + Vector2(d, -d), w, ink)
