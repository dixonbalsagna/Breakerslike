class_name UiText
## Text drawing for the HUD, safe on the web build.
##
## The web build has no system fonts, so it only has Godot's built-in fallback (Open Sans SemiBold), which lacks a
## few glyphs: "→", "▶" and "◀" among them. The director feed's "→" drew as a box. Fix: this class never asks the font
## for a glyph it lacks. "→" is drawn as a vector arrow inside the line; other missing glyphs fall back to ASCII.
## Every size goes through px(): a floor keeps text readable on a small window.

const ARROW := "→"
const _ASCII: Dictionary = {"×": "x", "—": "-", "·": "-", "…": "...", "’": "'", "“": "\"", "”": "\"", "•": "*"}

static var font: Font = null   # a bundled font may replace the fallback later (needs Legal's licence row first)


static func f() -> Font:
	if font != null:
		return font
	return ThemeDB.fallback_font


## A design size at scale s, never below the floor (real pixels).
static func px(design: float, s: float, floor_px: float = UiLook.MIN_TEXT_PX) -> int:
	return int(round(maxf(design * s, floor_px)))


## Replace glyphs the font lacks with ASCII. "→" is left in place: draw() and width() handle it as a vector arrow.
static func safe(text: String) -> String:
	var fnt: Font = f()
	var out := ""
	for i in range(text.length()):
		var ch: String = text[i]
		if ch == ARROW or ch.unicode_at(0) < 128 or fnt.has_char(ch.unicode_at(0)):
			out += ch
		else:
			out += _ASCII.get(ch, "?")
	return out


static func _segments(text: String) -> PackedStringArray:
	return safe(text).split(ARROW, true)


static func width(text: String, fs: int) -> float:
	var segs: PackedStringArray = _segments(text)
	var fnt: Font = f()
	var w := 0.0
	for i in range(segs.size()):
		w += fnt.get_string_size(segs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if i < segs.size() - 1:
			w += arrow_width(fs)
	return w


static func arrow_width(fs: int) -> float:
	return fs * 1.15


static func ascent(fs: int) -> float:
	return f().get_ascent(fs)


static func height(fs: int) -> float:
	return f().get_height(fs)


## Draw a line of text with its baseline at pos.y. align: -1 left, 0 centre, 1 right of pos.x. outline > 0 draws a dark
## outline that many pixels wide so the text survives bright explosions. Returns the drawn width.
static func draw(ci: CanvasItem, text: String, pos: Vector2, fs: int, color: Color, align: int = -1, outline: float = 0.0) -> float:
	var segs: PackedStringArray = _segments(text)
	var fnt: Font = f()
	var w: float = width(text, fs)
	var x: float = pos.x
	if align == 0:
		x -= w * 0.5
	elif align == 1:
		x -= w
	var ol := Color(0.03, 0.04, 0.07, minf(1.0, color.a * 0.9))
	for i in range(segs.size()):
		var seg: String = segs[i]
		var sw: float = fnt.get_string_size(seg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if seg != "":
			if outline > 0.0:
				ci.draw_string_outline(fnt, Vector2(x, pos.y), seg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(ceil(outline)), ol)
			ci.draw_string(fnt, Vector2(x, pos.y), seg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
		x += sw
		if i < segs.size() - 1:
			var aw: float = arrow_width(fs)
			var cy: float = pos.y - fs * 0.32
			if outline > 0.0:
				UiIcons.arrow(ci, Vector2(x + aw * 0.08, cy), aw * 0.84, fs * 0.13 + outline * 1.6, ol)
			UiIcons.arrow(ci, Vector2(x + aw * 0.08, cy), aw * 0.84, fs * 0.13, color)
			x += aw
	return w


## Wrap text to a pixel width; returns the lines. Breaks on spaces only.
static func wrap(text: String, fs: int, max_w: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var trial: String = word if line == "" else line + " " + word
		if width(trial, fs) <= max_w or line == "":
			line = trial
		else:
			out.append(line)
			line = word
	if line != "":
		out.append(line)
	return out
