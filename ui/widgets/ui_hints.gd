class_name UiHints
extends RefCounted
## On-screen control hints during play, and the YOU labels that say which fighter is the player's (friends could not tell). For each
## human fighter, a small legend in their column under the prompt row: the glyph of each action on their own device and one word
## ("[WASD] Fly", "[Space] Dash", ...). It shows for the first 12 seconds of every match (the last two fade), and all the time while
## prompts are on (training, the first matches) or the control_hints option is "always"; "off" hides it. A YOU pill with a small
## pointer rides over the human's fighter while the hints show, and the human's plate carries a YOU (or P1 and P2) tag. The rows are
## a scheme in ui/data/hints.json (option control_scheme, default "today"), so Controls' new layouts (ADR 0008) are data. Nothing
## here is drawn for an AI fighter, for the touch layout (its controls are on screen already) or in portrait.

static func data() -> Dictionary:
	return UiData.hints()


## The label for a fighter: YOU for the one human, P1 and P2 for two, "" for an AI (or when nobody plays).
static func you_label(models: Array, m: UiFighterModel) -> String:
	if m.ai:
		return ""
	var humans := 0
	for x in models:
		if not x.ai:
			humans += 1
	var d: Dictionary = data().get("you", {})
	if humans >= 2:
		var pair: Array = d.get("pair", ["P1", "P2"])
		return str(pair[clampi(m.slot, 0, pair.size() - 1)])
	return str(d.get("single", "YOU"))


## How strongly the hints show, 0 to 1: `mode` is the control_hints option (auto, always or off), `t` the match clock in seconds.
static func visible_alpha(m: UiFighterModel, mode: String, prompts_on: bool, t: float) -> float:
	if m.ai or mode == "off":
		return 0.0
	if mode == "always" or prompts_on:
		return 1.0
	var intro: float = float(data().get("intro_seconds", 12))
	if t < intro - 2.0:
		return 1.0
	return clampf((intro - t) / 2.0, 0.0, 1.0)


## The layout id this fighter plays on: touch-simple on touch; on a keyboard kb-solo, or kb-shared-p1 and kb-shared-p2 when two humans
## share it; on a pad the pad_preset option (arena, brawler or simple-pad). `o["control_scheme"]` overrides it (a test, or a preview).
static func preset_id(m: UiFighterModel, o: Dictionary) -> String:
	var forced: String = str(o.get("control_scheme", ""))
	if forced != "":
		return forced
	var sp: Dictionary = o.get("slot_presets", {})
	if sp.has(m.slot):
		return str(sp[m.slot])   # the host named this player's layout (Controls' per-slot preset)
	if bool(o.get("touch", false)):
		return "touch-simple"
	if m.device == "" or m.device == "kbd":
		# The shared-keyboard halves only when both people are on the keyboard; one on the keyboard and one on a pad is the solo layout.
		if int(o.get("kbd_humans", o.get("humans", 1))) >= 2:
			return "kb-shared-p%d" % (clampi(m.slot, 0, 1) + 1)
		return "kb-solo"
	if m.slot == 1 and o.has("pad_preset_p2"):
		return str(o["pad_preset_p2"])
	return str(o.get("pad_preset", "arena"))


## The rows to show now, from the layout's scheme (falling back to "today"): an action or group and a word. A row for an action the
## layout does not bind is skipped, and a row marked only_when_avail appears only while the fighter can use that action.
static func rows(m: UiFighterModel, scheme: String) -> Array:
	var schemes: Dictionary = data().get("schemes", {})
	var sc: Dictionary = schemes.get(scheme, schemes.get("today", {}))
	var out: Array = []
	for r in sc.get("rows", []):
		var acts: Array = r["actions"] if r.has("actions") else [r.get("action", "")]
		if not UiGlyphs.bound(scheme, str(acts[0]), m.slot):
			continue
		if bool(r.get("only_when_avail", false)):
			var a: String = str(r.get("action", ""))
			if not (m.avail.has(a) and bool(m.avail[a])):
				continue
		out.append({"acts": acts, "label": str(r.get("label", ""))})
	return out


## The glyph specs of one row, flat: each action's binding in the layout, a power group (Power then its face buttons) joined by a plus.
static func row_specs(m: UiFighterModel, acts: Array, preset: String, style: String) -> Array:
	var fam: String = m.device if m.device != "" else "kbd"
	return UiGlyphs.group_specs(acts, fam, m.slot, style, preset)


static func _row_width(specs: Array, gh: float, gap: float) -> float:
	var w := 0.0
	for sp in specs:
		w += UiGlyphs.width_spec(sp, gh) + gap * 0.4
	return w


## The layout of the legend in `rect`: as many rows as fit, in order. Returns {rows: [{specs, label, y}], label_x, gh, fs, row_h, box}.
static func plan(m: UiFighterModel, rect: Rect2, s: float, o: Dictionary) -> Dictionary:
	var out := {"rows": [], "label_x": 0.0, "gh": 0.0, "fs": 0, "row_h": 0.0, "box": Rect2()}
	if rect.size.y <= 0.0 or rect.size.x <= 0.0:
		return out
	var preset: String = preset_id(m, o)
	var style: String = str(o.get("glyph_style", "neutral"))
	var fs: int = UiText.px(18.0, s)
	var gh: float = maxf(24.0 * s, 20.0)
	var row_h: float = maxf(gh, float(fs) * 1.4) + 4.0 * s
	var pad: float = maxf(8.0 * s, 5.0)
	var cap: int = int(floor((rect.size.y - pad * 2.0) / row_h))
	var all: Array = rows(m, preset)
	var shown: Array = all.slice(0, maxi(cap, 0))
	if shown.is_empty():
		return out
	var gap: float = maxf(8.0 * s, 5.0)
	var maxw: float = 0.0
	var full: Array = []
	for r in shown:
		var specs: Array = row_specs(m, r["acts"], preset, style)
		full.append(specs)
		maxw = maxf(maxw, _row_width(specs, gh, gap))
	# A row too wide for the column (a long chord) would crowd the words: cap the glyph block at 60% of the column.
	maxw = minf(maxw, rect.size.x * 0.6)
	var y: float = rect.position.y + pad
	var placed: Array = []
	for i in range(shown.size()):
		placed.append({"specs": full[i], "label": shown[i]["label"], "y": y + row_h * 0.5})
		y += row_h
	out["rows"] = placed
	out["label_x"] = rect.position.x + pad + maxw + gap
	out["gh"] = gh
	out["fs"] = fs
	out["row_h"] = row_h
	out["gap"] = gap
	out["pad"] = pad
	out["preset"] = preset
	out["box"] = Rect2(rect.position, Vector2(minf(rect.size.x, (out["label_x"] as float) - rect.position.x + _widest_label(placed, fs) + pad), float(placed.size()) * row_h + pad * 2.0))
	return out


static func _widest_label(placed: Array, fs: int) -> float:
	var w := 0.0
	for r in placed:
		w = maxf(w, UiText.width(str(r["label"]), fs))
	return w


static func sig(m: UiFighterModel, alpha: float, preset: String) -> Array:
	return [m.device, m.slot, int(alpha * 10.0), preset, m.avail["transform"], m.left_side]


static func draw(ci: CanvasItem, m: UiFighterModel, rect: Rect2, s: float, o: Dictionary, alpha: float) -> void:
	var p: Dictionary = plan(m, rect, s, o)
	if p["rows"].is_empty() or alpha <= 0.01:
		return
	var style: String = str(o.get("glyph_style", "neutral"))
	var gh: float = p["gh"]
	var fs: int = p["fs"]
	var gap: float = p["gap"]
	var left: bool = m.left_side
	var box: Rect2 = p["box"]
	UiText.no_outline = true
	var bx: float = box.position.x if left else rect.end.x - box.size.x
	var shift: float = bx - box.position.x
	UiIcons.rrect(ci, Rect2(bx, box.position.y, box.size.x, box.size.y), 8.0 * s, Color(UiLook.col(UiLook.SCRIM), 0.5 * alpha), Color(UiLook.col(UiLook.EDGE), 0.25 * alpha), 1.2)
	for r in p["rows"]:
		var x: float = rect.position.x + float(p["pad"]) + shift
		for sp in r["specs"]:
			var w: float = UiGlyphs.draw_spec(ci, sp, Vector2(x, float(r["y"])), gh, alpha, true)
			x += w + gap * 0.4
		UiText.draw(ci, str(r["label"]), Vector2(float(p["label_x"]) + shift, float(r["y"]) - UiText.height(fs) * 0.5 + UiText.ascent(fs)), fs, Color(UiLook.col(UiLook.INK), alpha), -1)
	UiText.no_outline = false


## The YOU marker over a fighter: a small pill with the label and a pointer toward the head, kept inside `safe`.
static func draw_you(ci: CanvasItem, label: String, anchor: Dictionary, s: float, alpha: float, safe: Rect2) -> void:
	if label == "" or anchor.is_empty() or not bool(anchor.get("visible", true)) or alpha <= 0.01:
		return
	var c: Vector2 = anchor["pos"]
	var R: float = UiCrown.radius(float(anchor.get("h", 90.0)), s)
	var fs: int = UiText.px(22.0, s)
	var tw: float = UiText.width(label, fs)
	var pw: float = tw + 22.0 * s
	var ph: float = float(fs) + 10.0 * s
	var cx: float = clampf(c.x, safe.position.x + pw * 0.5, safe.end.x - pw * 0.5)
	var top: float = clampf(c.y - R * 1.3 - ph - 22.0 * s, safe.position.y, safe.end.y - ph - 12.0 * s)
	var r := Rect2(cx - pw * 0.5, top, pw, ph)
	UiText.no_outline = true
	UiIcons.rrect(ci, r, ph * 0.5, Color(UiLook.col(UiLook.INK), 0.92 * alpha), Color(UiLook.col(UiLook.INK_DARK), 0.7 * alpha), 1.5)
	UiText.draw(ci, label, Vector2(r.get_center().x, r.get_center().y - UiText.height(fs) * 0.5 + UiText.ascent(fs)), fs, Color(UiLook.col(UiLook.INK_DARK), alpha), 0)
	# The pointer: a small triangle under the pill, toward the head.
	var tip := Vector2(clampf(c.x, r.position.x + ph * 0.5, r.end.x - ph * 0.5), r.end.y + 12.0 * s)
	UiIcons.fill_poly(ci, PackedVector2Array([tip, tip + Vector2(-8.0 * s, -12.0 * s), tip + Vector2(8.0 * s, -12.0 * s)]), Color(UiLook.col(UiLook.INK), 0.92 * alpha))
	UiText.no_outline = false
