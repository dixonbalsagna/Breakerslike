class_name UiGlyphs
## Neutral prompt glyphs per device (docs/controls/prompt-glyphs.md) and the small press-acknowledged marks.
##
## A prompt shows the glyph of the device that last sent input for that slot (the host tells the HUD with
## UiHud.set_device). The default style is NEUTRAL: our own position diamond with a letter for the face buttons, plain text
## marks for triggers and bumpers, a small cross for the D-pad, a keycap for the keyboard. No console maker's icon art and no
## platform's face symbols until Legal answers (rule 7); the `family` style, which prints each family's own letters, is in the
## data and off. Every glyph has a shape or a letter, never colour alone; arrows are never characters.

const KBD := "kbd"
const SPECIALS: Array = ["power", "special1", "special2", "special3"]


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
	var tbl: Dictionary = _pad_table(family, style)
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
	return maxi(int(UiLook.text_floor), int(h * 0.55))


## The pad's mark table for a family and a style (face letters, LT, RT, LB, RB, R3).
static func _pad_table(family: String, style: String) -> Dictionary:
	var g: Dictionary = UiData.glyphs()
	if style == "family" and (g.get("family_labels", {}) as Dictionary).has(family):
		return g["family_labels"][family]
	var neutral: Dictionary = g.get("neutral", {})
	var pads: Dictionary = neutral.get("pad", {})
	return {"face": neutral.get("face", {}), "LT": pads.get("LT", "LT"), "RT": pads.get("RT", "RT"), "LB": pads.get("LB", "LB"), "RB": pads.get("RB", "RB"), "R3": pads.get("R3", "R3")}


## A keyboard code from the layout data ("KeyJ", "Space", "Comma") as the cap's label.
static func key_label(code: String) -> String:
	if code.begins_with("Key"):
		return code.substr(3)
	if code.begins_with("Digit"):
		return code.substr(5)
	match code:
		"Comma": return ","
		"Period": return "."
		"Semicolon": return ";"
		"Slash": return "/"
		"Quote": return "'"
		"BracketLeft": return "["
		"BracketRight": return "]"
		"Minus": return "-"
		"Equal": return "="
		"Backquote": return "`"
		"Backslash": return "\\"
	return code


## A control id from the layout data ("pad:west", "pad:lt", "kb:KeyJ") as a glyph spec, on a device family in a style.
static func spec_control(control: String, family: String, style: String = "neutral") -> Dictionary:
	var parts: PackedStringArray = control.split(":")
	if parts.size() < 2:
		return {}
	var name: String = parts[1]
	if parts[0] == "kb":
		return {"kind": "key", "label": key_label(name)}
	if parts[0] != "pad":
		return {}
	var tbl: Dictionary = _pad_table(family, style)
	match name:
		"west", "north", "east", "south":
			return {"kind": "face", "pos": name, "label": str((tbl.get("face", {}) as Dictionary).get(name, "?"))}
		"lt", "rt", "lb", "rb", "r3":
			return {"kind": "pad", "label": str(tbl.get(name.to_upper(), name.to_upper()))}
		"l3":
			return {"kind": "pad", "label": "L3"}
		"ls", "rs":
			return {"kind": "stick", "label": ""}
		"start":
			return {"kind": "pad", "label": "Start"}
		"back":
			return {"kind": "pad", "label": "Back"}
	return {"kind": "pad", "label": name.to_upper()}


## The glyph specs of an action in a preset (the layouts' data, as Controls wrote it): the base layer's binding, a single control in
## preference to a chord; a chord is its controls joined by a plus. `layer` is "" for the base layer or "power" for the power layer.
## Empty if the preset does not bind it.
static func binding_specs(preset: Dictionary, action: String, family: String, style: String = "neutral", layer: String = "") -> Array:
	var best: Array = []
	for b in preset.get("bindings", []):
		if str(b.get("action", "")) != action or str(b.get("layer", "")) != layer:
			continue
		if str(b.get("gesture", "")) != "":
			continue
		var cs: Array = b.get("controls", [])
		if cs.is_empty():
			continue
		if cs.size() == 1:
			var one: Dictionary = spec_control(str(cs[0]), family, style)
			return [one] if not one.is_empty() else []
		if b.has("axis") and str(cs[0]).begins_with("kb:"):
			# Four keys that make one axis (WASD) are one cap, not a chord.
			var word := ""
			for c in cs:
				word += key_label(str(c).get_slice(":", 1))
			return [{"kind": "key", "label": word}]
		if best.is_empty():
			for i in range(cs.size()):
				if i > 0:
					best.append({"kind": "plus", "label": "+"})
				best.append(spec_control(str(cs[i]), family, style))
	return best


## Whether a preset binds an action (the power layer's specials are special1 to special3). An empty preset id means "do not ask".
static func bound(preset: String, action: String, slot: int = 0) -> bool:
	if preset == "":
		return true
	if action == "specials":
		action = "special1"
	var pr: Dictionary = UiRemapModel.preset(preset, slot)
	if pr.is_empty():
		return true   # not a layout id (the "today" scheme, a preview): nothing to filter by
	var layer: String = "power" if action.begins_with("special") else ""
	return not binding_specs(pr, action, "xbox", "neutral", layer).is_empty()


## The specs to draw for an action: the preset's own binding if a preset is given and binds it, else the action's table entry.
static func specs_for(action: String, family: String, slot: int, style: String = "neutral", preset: String = "") -> Array:
	if preset != "":
		var layer := ""
		var act: String = action
		if action.begins_with("special") and action != "special":
			layer = "power"
		var specs: Array = binding_specs(UiRemapModel.preset(preset, slot), act, family, style, layer)
		if not specs.is_empty():
			return specs
	var sp: Dictionary = spec(action, family, slot, style)
	return [sp] if not sp.is_empty() else []


## The flat specs of a row's actions: each action's binding, and for the Specials group (power first) a plus after Power.
static func group_specs(acts: Array, family: String, slot: int, style: String, preset: String) -> Array:
	if acts.size() == 1 and str(acts[0]) == "specials":
		acts = SPECIALS   # the Specials row: Power, then the three face buttons it turns on
	var out: Array = []
	for i in range(acts.size()):
		if i == 1 and str(acts[0]) == "power":
			out.append({"kind": "plus", "label": "+"})
		out.append_array(specs_for(str(acts[i]), family, slot, style, preset))
	return out


static func width_spec(sp: Dictionary, h: float) -> float:
	var fs: int = _fs(h)
	match str(sp.get("kind", "")):
		"key":
			return maxf(h, UiText.width(sp["label"], fs) + h * 0.5)
		"face":
			return h + h * 0.12 + UiText.width(sp["label"], fs)
		"pad":
			return maxf(h * 1.1, UiText.width(sp["label"], fs) + h * 0.5)
		"plus":
			return h * 0.5
		"stick", "dpad":
			return h
	return h


## The width a glyph (or a chord's glyphs) takes at height h.
static func width(action: String, family: String, slot: int, h: float, style: String = "neutral", preset: String = "") -> float:
	var w := 0.0
	var specs: Array = specs_for(action, family, slot, style, preset)
	for i in range(specs.size()):
		w += width_spec(specs[i], h) + (h * 0.08 if i < specs.size() - 1 else 0.0)
	return w


## Draw a glyph with its left edge at `at.x` and its centre line at `at.y`. `on` fills the pressed position (the diamond's dot).
## `preset` (a layout id) makes it the preset's own binding. Returns the width drawn.
static func draw(ci: CanvasItem, action: String, family: String, slot: int, at: Vector2, h: float, alpha: float, on: bool = true, style: String = "neutral", preset: String = "") -> float:
	var specs: Array = specs_for(action, family, slot, style, preset)
	var x: float = at.x
	for i in range(specs.size()):
		var w: float = draw_spec(ci, specs[i], Vector2(x, at.y), h, alpha, on)
		x += w + (h * 0.08 if i < specs.size() - 1 else 0.0)
	return x - at.x


## One spec drawn: a keycap, a position diamond with its letter, a pad mark, a plus or a stick. Returns its width.
static func draw_spec(ci: CanvasItem, sp: Dictionary, at: Vector2, h: float, alpha: float, on: bool = true) -> float:
	if sp.is_empty():
		return 0.0
	var fs: int = _fs(h)
	var ink := Color(UiLook.col(UiLook.INK), alpha)
	var edge := Color(UiLook.col(UiLook.EDGE), 0.85 * alpha)
	var back := Color(UiLook.col(UiLook.SCRIM), 0.85 * alpha)
	var w: float = width_spec(sp, h)
	var cy: float = at.y
	match str(sp["kind"]):
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
		"plus":
			UiText.draw(ci, "+", Vector2(at.x + w * 0.5, cy + float(fs) * 0.35), fs, ink, 0)
		"dpad":
			var c2 := Vector2(at.x + h * 0.5, cy)
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
