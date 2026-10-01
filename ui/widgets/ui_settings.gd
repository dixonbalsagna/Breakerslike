class_name UiSettings
extends RefCounted
## The Settings screen (docs/ui/hud-spec.md section 26): a card of sections and rows, opened from the pause menu. Every row is built
## from ui/data/options.json (a toggle for a boolean, a slider for a number with a range, a choice for a list) and laid out by
## ui/data/settings.json (sections, order, the words for each choice, the rows that wait for a feature flag).
##
## `plan` is pure geometry, like the other cards, so hud_check can prove that at every size every control is a real 48 dp target inside
## the card and the rows scroll when they do not fit. `draw` paints from a plan. `hit` says what a point is on. The HUD keeps the
## state (focus, scroll, drag) and applies the changes through set_option, which emits option_changed.
##
## It works three ways: keys and the pad move a focus ring (up and down choose, left and right change, accept switches, back closes);
## the mouse and a finger tap a control or drag the track of a slider, and drag anywhere else to scroll.

const HEADING := "heading"
const TOGGLE := "toggle"
const SLIDER := "slider"
const CHOICE := "choice"
const BUTTON := "button"
const BIND := "bind"        # the Remap screen's row: an action's name and the controls it has now (row["specs"] are glyph specs)


## True while two people play: the HUD sets it before it asks for the rows. Then the controller layout and Remap rows for player two are listed.
static var two_humans: bool = false


static func data() -> Dictionary:
	return UiData.settings()


# --- The rows -------------------------------------------------------------------------------------------------------------------

## The screen's rows in order: {kind, key, label, help, enabled, ...}. A section is a heading row then its items. `needs` is a feature
## flag; without it the row is listed but disabled. An id with no option in options.json is skipped.
static func rows() -> Array:
	var d: Dictionary = data()
	var od: Dictionary = UiData.options()
	var out: Array = []
	var needs: Dictionary = d.get("needs", {})
	for sec in d.get("sections", []):
		out.append({"kind": HEADING, "key": "", "label": str(sec.get("title", "")), "help": "", "enabled": false, "section": str(sec.get("id", ""))})
		for it in sec.get("items", []):
			if it is Dictionary:
				if str(it.get("action", "")) == "remap_two" and not two_humans:
					continue
				var need: String = str(it.get("needs", ""))
				out.append({"kind": BUTTON, "key": "", "action": str(it.get("action", "")), "label": str(it.get("label", "")), "value": str(it.get("value", "")),
					"help": str(it.get("help", "")), "enabled": need == "" or UiData.feature(need)})
				continue
			var key: String = str(it)
			var o: Dictionary = od.get(key, {})
			if o.is_empty() or (key == "pad_preset_p2" and not two_humans):
				continue
			var kind: String = TOGGLE if o["default"] is bool else (SLIDER if o.has("min") else CHOICE)
			var need2: String = str(needs.get(key, ""))
			out.append({"kind": kind, "key": key, "label": str(o.get("label", key)), "help": str(o.get("help", "")), "enabled": need2 == "" or UiData.feature(need2), "o": o})
	return out


## The row indexes a focus can land on (not headings, not disabled).
static func focusable(rws: Array) -> Array:
	var out: Array = []
	for i in range(rws.size()):
		if rws[i]["kind"] != HEADING and bool(rws[i]["enabled"]):
			out.append(i)
	return out


## The option's current value: the HUD's opts, else the option's default.
static func value_of(row: Dictionary, opts: Dictionary):
	return opts.get(row["key"], (row["o"] as Dictionary)["default"])


static func _same(a, b) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return a == b


## A choice row's word for a value: the row's own words (the Remap screen's layouts) or the labels in settings.json, else the value itself.
static func row_word(row: Dictionary, value) -> String:
	if row.has("words"):
		return str((row["words"] as Dictionary).get(str(value), str(value)))
	return choice_word(str(row["key"]), value)


## A choice's word: the label from settings.json, else the value itself.
static func choice_word(key: String, value) -> String:
	var lbl: Dictionary = (data().get("labels", {}) as Dictionary).get(key, {})
	return str(lbl.get(str(value), str(value)))


## The slider's number as text: a whole number for whole steps, a percentage for a 0..1 style range.
static func slider_word(o: Dictionary, v) -> String:
	if float(o.get("step", 1.0)) >= 1.0:
		return str(int(roundf(float(v))))
	return "%d%%" % int(roundf(float(v) * 100.0))


## What a row shows at the right: On or Off, the number, the choice's word, a button's word, or Soon while it waits for its feature.
static func value_word(row: Dictionary, opts: Dictionary) -> String:
	var d: Dictionary = data()
	if row["kind"] == HEADING:
		return ""
	if not bool(row["enabled"]):
		return str(d.get("soon", "Soon"))
	match row["kind"]:
		TOGGLE:
			return str(d.get("on", "On")) if bool(value_of(row, opts)) else str(d.get("off", "Off"))
		SLIDER:
			return slider_word(row["o"], value_of(row, opts))
		CHOICE:
			return row_word(row, value_of(row, opts))
		BUTTON:
			return str(row.get("value", ""))
		BIND:
			var parts := PackedStringArray()
			for sp in row.get("specs", []):
				parts.append(str(sp.get("label", "")))
			return " ".join(parts)
	return ""


## The value after one step in a direction (+1 or -1): a toggle flips, a slider moves by its step within its range, a choice cycles
## round its list. Anything else returns the current value.
static func stepped(row: Dictionary, opts: Dictionary, dir: int):
	var cur = value_of(row, opts)
	var o: Dictionary = row.get("o", {})
	match row["kind"]:
		TOGGLE:
			return not bool(cur)
		SLIDER:
			var st: float = float(o.get("step", 1.0))
			return clampf(float(cur) + float(dir) * st, float(o["min"]), float(o["max"]))
		CHOICE:
			var ch: Array = o["choices"]
			var i: int = 0
			for k in range(ch.size()):
				if _same(ch[k], cur):
					i = k
			return ch[posmod(i + dir, ch.size())]
	return cur


## A slider's value for a point's x on its track (snapped to the step and held to the range by set_option).
static func slider_at(row: Dictionary, track: Rect2, x: float):
	var o: Dictionary = row["o"]
	var f: float = clampf((x - track.position.x) / maxf(track.size.x, 1.0), 0.0, 1.0)
	var st: float = float(o.get("step", 1.0))
	var v: float = float(o["min"]) + f * (float(o["max"]) - float(o["min"]))
	return float(o["min"]) + roundf((v - float(o["min"])) / st) * st


# --- Geometry -------------------------------------------------------------------------------------------------------------------

## The layout for a viewport: {card, inner, close, title_pos, body, footer, rows[], content_h, max_scroll, scroll, fits, tm, ...}.
## `st` is {focus: row index, scroll: pixels}; `opts` the HUD's options. The Remap screen uses the same card with its own rows and words: `st` may
## also carry rows (instead of rows()), title, hint_text, status (shown in the foot instead of the focused row's help), confirm (labels of
## buttons under the foot), and capture (a row waiting for a control) with capture_word. A row is {idx, kind, key, label_lines, label_x, label_y, rect,
## ctl: {part: Rect2}, word, frac, enabled, visible, y (in the content), h}.
static func plan(vp: Vector2, s: float, dp: float, touch: bool, st: Dictionary, opts: Dictionary) -> Dictionary:
	var d: Dictionary = data()
	var rws: Array = st["rows"] if st.has("rows") else rows()
	var tm: float = maxf(48.0 * dp, 44.0)
	var margin: float = maxf(vp.x * 0.03, 12.0)
	var my: float = maxf(vp.y * 0.04, 10.0)
	var cw: float = minf(vp.x - 2.0 * margin, maxf(1100.0 * s, 560.0))
	var ch: float = vp.y - 2.0 * my
	var card := Rect2((vp.x - cw) * 0.5, my, cw, ch)
	var cs: float = maxf(s, 0.3)
	var pad: float = maxf(20.0 * cs, 10.0)
	var fs_title: int = UiText.px(34.0, cs)
	var fs_body: int = UiText.px(22.0, cs)
	var fs_small: int = UiText.px(18.0, cs)
	var lh: float = UiText.height(fs_body) * 1.15
	var lh_small: float = UiText.height(fs_small) * 1.15
	var inner := Rect2(card.position + Vector2(pad, pad), card.size - Vector2(pad, pad) * 2.0)
	var close_sz: float = maxf(tm, 40.0 * cs)
	var close := Rect2(card.end.x - pad - close_sz, card.position.y + pad * 0.6, close_sz, close_sz)
	var title: String = str(st.get("title", d.get("title", "SETTINGS")))
	var header_h: float = maxf(UiText.height(fs_title), close_sz)
	var fits: bool = inner.position.x + UiText.width(title, fs_title) <= close.position.x - pad * 0.5
	var gap: float = maxf(pad * 0.4, 5.0)
	# The small print at the foot: the focused row's help, in as many lines as the longest help needs (up to three), so it does not jump.
	# At most two lines, and never more than a fifth of the card: a short phone screen gives its height to the rows. A longer help ends in "...".
	var help_lines: int = 1
	for r in rws:
		help_lines = maxi(help_lines, mini(2, UiText.wrap(str(r["help"]), fs_small, inner.size.x).size()))
	help_lines = clampi(mini(help_lines, int(floor(card.size.y * 0.2 / lh_small))), 1, 2)
	var hint_key: String = "hint_pad" if (not touch and str(st.get("device", "kbd")) != "kbd") else "hint_keys"
	var hint_text: String = "" if touch else str(d.get(hint_key, ""))
	if st.has("hint_text"):
		hint_text = "" if touch else str(st["hint_text"])
	var status: String = str(st.get("status", ""))
	if status != "":
		help_lines = clampi(maxi(help_lines, UiText.wrap(status, fs_small, inner.size.x).size()), 1, 2)
	var foot_lines: int = help_lines + (1 if hint_text != "" else 0)
	var confirm: Array = st.get("confirm", [])
	var conf_h: float = (tm + gap) if not confirm.is_empty() else 0.0
	var footer := Rect2(inner.position.x, inner.end.y - float(foot_lines) * lh_small - 2.0 - conf_h, inner.size.x, float(foot_lines) * lh_small + 2.0 + conf_h)
	var conf_rects: Array = []
	var cx: float = footer.position.x
	for k in range(confirm.size()):
		var bw0: float = maxf(tm * 2.2, UiText.width(str(confirm[k]), fs_body) + tm * 0.8)
		conf_rects.append(Rect2(cx, footer.end.y - tm, bw0, tm))
		cx += bw0 + gap
	var body_top: float = inner.position.y + header_h + gap
	var body := Rect2(inner.position.x, body_top, inner.size.x, footer.position.y - gap - body_top)
	var sbw: float = maxf(6.0 * cs, 4.0)
	var row_w: float = body.size.x - sbw - 4.0
	# Narrow cards put the control on its own line under the label; so do cards whose control column cannot hold a slider.
	var slider_need: float = tm * 3.5 + UiText.width("100%", fs_body) + gap * 2.0
	var stack: bool = row_w < float(fs_body) * 26.0 or row_w * 0.56 < slider_need
	var label_w: float = row_w * 0.44 if not stack else row_w
	var ctl_w: float = row_w - label_w
	var rg: float = maxf(4.0 * cs, 3.0)
	var y: float = 0.0
	var placed: Array = []
	var bad := 0
	var scroll: float = float(st.get("scroll", 0.0))
	for i in range(rws.size()):
		var r: Dictionary = rws[i]
		var rec: Dictionary = {"idx": i, "kind": r["kind"], "key": r["key"], "enabled": r["enabled"], "help": r["help"], "ctl": {}, "label_lines": PackedStringArray(), "frac": 0.0, "word": value_word(r, opts)}
		if r["kind"] == HEADING:
			var hh: float = lh * 1.35
			y += rg * 2.0 if i > 0 else 0.0
			rec["y"] = y
			rec["h"] = hh
			rec["label_lines"] = PackedStringArray([str(r["label"])])
			y += hh + rg
			placed.append(rec)
			continue
		var lines: PackedStringArray = UiText.wrap(str(r["label"]), fs_body, label_w - gap)
		var lbl_h: float = float(lines.size()) * lh
		var h: float = maxf(tm + rg, lbl_h + rg) if not stack else lbl_h + tm + rg * 1.5
		rec["y"] = y
		rec["h"] = h
		rec["label_lines"] = lines
		rec["lbl_h"] = lbl_h
		y += h + rg
		placed.append(rec)
	var content_h: float = maxf(y - rg, 0.0)
	var max_scroll: float = maxf(0.0, content_h - body.size.y)
	scroll = clampf(scroll, 0.0, max_scroll)
	for rec in placed:
		var i2: int = rec["idx"]
		var r2: Dictionary = rws[i2]
		var ry: float = body.position.y + float(rec["y"]) - scroll
		var rect := Rect2(body.position.x, ry, row_w, float(rec["h"]))
		rec["rect"] = rect
		rec["visible"] = rect.intersects(body)
		if rec["kind"] == HEADING:
			rec["label_x"] = rect.position.x
			rec["label_y"] = rect.position.y + rect.size.y - lh * 0.3
			continue
		rec["label_x"] = rect.position.x + gap * 0.5
		var band: float = minf(rect.size.y, tm + rg)
		rec["label_y"] = rect.position.y + UiText.ascent(fs_body) + (0.0 if stack else (band - float(rec["lbl_h"])) * 0.5)
		var area := Rect2(rect.end.x - ctl_w, rect.position.y, ctl_w, rect.size.y) if not stack else Rect2(rect.position.x, rect.end.y - tm - rg * 0.5, row_w, tm)
		var cy: float = area.position.y + area.size.y * 0.5 if stack else rect.position.y + band * 0.5
		var ctl: Dictionary = {}
		match r2["kind"]:
			TOGGLE:
				var sw := Vector2(tm * 1.3, tm * 0.62)
				ctl["switch"] = Rect2(area.end.x - sw.x, cy - sw.y * 0.5, sw.x, sw.y)
				ctl["tap"] = Rect2(area.end.x - tm * 1.6, cy - tm * 0.5, tm * 1.6, tm)
			CHOICE:
				var o: Dictionary = r2["o"]
				var vw: float = tm * 1.6
				for c in o["choices"]:
					vw = maxf(vw, UiText.width(row_word(r2, c), fs_body) + gap * 2.0)
				vw = minf(vw, maxf(area.size.x - tm * 2.0, tm))
				var rb := Rect2(area.end.x - tm, cy - tm * 0.5, tm, tm)
				var lb := Rect2(rb.position.x - vw - tm, cy - tm * 0.5, tm, tm)
				ctl["left"] = lb
				ctl["right"] = rb
				ctl["value"] = Rect2(lb.end.x, cy - tm * 0.5, vw, tm)
			SLIDER:
				var o2: Dictionary = r2["o"]
				var vtw: float = maxf(UiText.width(slider_word(o2, o2["max"]), fs_body), UiText.width(slider_word(o2, o2["min"]), fs_body)) + gap
				var pb := Rect2(area.end.x - vtw - tm, cy - tm * 0.5, tm, tm)
				var mb := Rect2(area.position.x, cy - tm * 0.5, tm, tm)
				ctl["minus"] = mb
				ctl["plus"] = pb
				ctl["track"] = Rect2(mb.end.x + 2.0, cy - tm * 0.5, maxf(pb.position.x - mb.end.x - 4.0, 1.0), tm)
				ctl["value"] = Rect2(pb.end.x, cy - tm * 0.5, vtw, tm)
				var o3: Dictionary = o2
				rec["frac"] = clampf((float(value_of(r2, opts)) - float(o3["min"])) / (float(o3["max"]) - float(o3["min"])), 0.0, 1.0)
			BUTTON:
				var bw: float = maxf(tm * 2.2, UiText.width(str(rec["word"]), fs_body) + tm * 0.8)
				ctl["button"] = Rect2(area.end.x - bw, cy - tm * 0.5, bw, tm)
			BIND:
				ctl["tap"] = Rect2(area.position.x, cy - tm * 0.5, area.size.x, tm)
				var gh0: float = tm * 0.6
				var tw: float = 0.0
				for sp in r2.get("specs", []):
					tw += UiGlyphs.width_spec(sp, gh0) + gh0 * 0.08
				if tw > area.size.x:
					bad += 1
				rec["specs"] = r2.get("specs", [])
				rec["gh"] = gh0
				rec["capturing"] = i2 == int(st.get("capture", -1))
				if rec["capturing"]:
					rec["word"] = str(st.get("capture_word", "..."))
		rec["ctl"] = ctl
		# Checks: every control is at least a 48 dp square (the track and the tap area at least that tall), inside its row and the card.
		for k in ctl:
			var cr: Rect2 = ctl[k]
			if k == "switch" or k == "value":
				continue
			if cr.size.y < tm - 0.01 or cr.size.x < tm - 0.01 or cr.position.x < card.position.x or cr.end.x > card.end.x:
				bad += 1
		if r2["kind"] == SLIDER and (ctl["track"] as Rect2).size.x < tm * 1.5:
			bad += 1
	var out := {"card": card, "inner": inner, "close": close, "cs": cs, "pad": pad, "tm": tm, "title": title, "title_pos": Vector2(inner.position.x, inner.position.y + UiText.ascent(fs_title)),
		"fs_title": fs_title, "fs_body": fs_body, "fs_small": fs_small, "lh": lh, "lh_small": lh_small, "body": body, "footer": footer, "rows": placed, "content_h": content_h,
		"max_scroll": max_scroll, "scroll": scroll, "stack": stack, "hint": hint_text, "help_lines": help_lines, "sbw": sbw, "bad": bad, "gap": gap, "focus": int(st.get("focus", -1)),
		"status": status, "confirm": conf_rects, "confirm_labels": confirm}
	for cr2 in conf_rects:
		if not card.encloses(cr2):
			bad += 1
	out["bad"] = bad
	out["fits"] = fits and bad == 0 and body.size.y >= tm
	return out


## The scroll that brings row `idx` (and its section heading, if it is the first of its section) into the body, from the current scroll.
static func scroll_to(p: Dictionary, idx: int, scroll: float) -> float:
	var rws: Array = p["rows"]
	if idx < 0 or idx >= rws.size():
		return scroll
	var body: Rect2 = p["body"]
	var rec: Dictionary = rws[idx]
	var top: float = float(rec["y"])
	if idx > 0 and rws[idx - 1]["kind"] == HEADING:
		top = float(rws[idx - 1]["y"])
	var bottom: float = float(rec["y"]) + float(rec["h"])
	var s: float = scroll
	if top < s:
		s = top
	elif bottom > s + body.size.y:
		s = bottom - body.size.y
	return clampf(s, 0.0, float(p["max_scroll"]))


## What a point is on: {row: index or -1, part: "close", a control's name ("minus", "plus", "left", "right", "track", "switch", "tap", "button"),
## "row" (the row itself) or "body" (empty space in the body)}; {} if it is on none of them.
static func hit(p: Dictionary, pos: Vector2) -> Dictionary:
	if (p["close"] as Rect2).has_point(pos):
		return {"row": -1, "part": "close"}
	var cb: Array = p.get("confirm", [])
	for k in range(cb.size()):
		if (cb[k] as Rect2).has_point(pos):
			return {"row": k, "part": "confirm"}
	var body: Rect2 = p["body"]
	if not body.has_point(pos):
		return {}
	for rec in p["rows"]:
		if rec["kind"] == HEADING or not (rec["rect"] as Rect2).has_point(pos):
			continue
		if not bool(rec["enabled"]):
			return {"row": int(rec["idx"]), "part": "off"}
		var ctl: Dictionary = rec["ctl"]
		for k in ["minus", "plus", "left", "right", "track", "button", "tap"]:
			if ctl.has(k) and (ctl[k] as Rect2).has_point(pos):
				return {"row": int(rec["idx"]), "part": k}
		return {"row": int(rec["idx"]), "part": "row"}
	return {"row": -1, "part": "body"}


## The redraw key: the size, the focus, the scroll, and every shown value.
static func sig(p: Dictionary, opts: Dictionary, touch: bool) -> Array:
	var vals: Array = []
	for rec in p["rows"]:
		vals.append(rec["word"])
	return [int((p["card"] as Rect2).size.x), int((p["card"] as Rect2).size.y), int(p["cs"] * 100.0), touch, int(p["focus"]), int(p["scroll"]), vals, p["status"], p["confirm_labels"], str(p["title"]), str(p["hint"])]


# --- Drawing --------------------------------------------------------------------------------------------------------------------

static func _inside(body: Rect2, r: Rect2) -> bool:
	return r.position.y >= body.position.y - 0.5 and r.end.y <= body.end.y + 0.5


static func draw(ci: CanvasItem, p: Dictionary, opts: Dictionary) -> void:
	var vp: Vector2 = ci.size if ci is Control else Vector2(1920, 1080)
	var ink := Color(UiLook.col(UiLook.INK))
	var dim := Color(UiLook.col(UiLook.INK_DIM))
	var dark := Color(UiLook.col(UiLook.INK_DARK))
	var edge := Color(UiLook.col(UiLook.EDGE), 0.55)
	var scrim := Color(UiLook.col(UiLook.SCRIM))
	var card: Rect2 = p["card"]
	var body: Rect2 = p["body"]
	var tm: float = p["tm"]
	var cs: float = p["cs"]
	var fs_body: int = p["fs_body"]
	var fs_small: int = p["fs_small"]
	var lh: float = p["lh"]
	var w: float = maxf(2.0, tm * 0.04)
	UiText.no_outline = true
	ci.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.03, 0.06, 0.78))
	UiIcons.rrect(ci, card, 18.0 * cs, Color(scrim, 0.97), edge, 2.0)
	# The header: the title and the close cross.
	UiText.draw(ci, str(p["title"]), p["title_pos"], int(p["fs_title"]), ink, -1)
	var close: Rect2 = p["close"]
	UiIcons.rrect(ci, close, close.size.y * 0.25, Color(scrim, 0.8), edge, 1.6)
	var cc: Vector2 = close.get_center()
	var cr: float = close.size.x * 0.22
	UiIcons.line(ci, cc + Vector2(-cr, -cr), cc + Vector2(cr, cr), maxf(2.0, close.size.x * 0.06), ink)
	UiIcons.line(ci, cc + Vector2(-cr, cr), cc + Vector2(cr, -cr), maxf(2.0, close.size.x * 0.06), ink)
	# The rows: an element is drawn when it is inside the body, so nothing spills over the header or the foot.
	var focus: int = int(p["focus"])
	for rec in p["rows"]:
		var r: Rect2 = rec["rect"]
		if not rec["visible"]:
			continue
		if rec["kind"] == HEADING:
			if _inside(body, r):
				UiText.draw(ci, str(rec["label_lines"][0]), Vector2(float(rec["label_x"]), float(rec["label_y"])), fs_body, dim, -1)
				ci.draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Color(edge, 0.5), 1.0)
			continue
		var on: bool = bool(rec["enabled"])
		var a: float = 1.0 if on else 0.42
		var is_focus: bool = int(rec["idx"]) == focus
		var rr: Rect2 = r.intersection(body)
		if rr.size.y > 1.0:
			if bool(rec.get("capturing", false)):
				UiIcons.rrect(ci, rr, tm * 0.2, Color(Color(UiLook.col(UiLook.WARN)), 0.12), Color(UiLook.col(UiLook.WARN)), 2.4)
			elif is_focus:
				UiIcons.rrect(ci, rr, tm * 0.2, Color(ink, 0.10), Color(ink, 0.75), 1.8)
			else:
				ci.draw_line(Vector2(r.position.x, rr.end.y), Vector2(r.end.x, rr.end.y), Color(edge, 0.12), 1.0)
		if not _inside(body, r):
			continue
		var ly: float = float(rec["label_y"])
		for ln in rec["label_lines"]:
			UiText.draw(ci, ln, Vector2(float(rec["label_x"]), ly), fs_body, Color(ink, a), -1)
			ly += lh
		var ctl: Dictionary = rec["ctl"]
		_draw_ctl(ci, rec, ctl, a, ink, dim, dark, edge, scrim, tm, fs_body, w, cs)
	# The scrollbar: a thin thumb at the body's right edge when the rows overflow.
	if float(p["max_scroll"]) > 0.0:
		var sb := Rect2(body.end.x - float(p["sbw"]), body.position.y, float(p["sbw"]), body.size.y)
		ci.draw_rect(sb, Color(edge, 0.18))
		var frac: float = body.size.y / float(p["content_h"])
		var th: float = maxf(sb.size.y * frac, tm * 0.5)
		var ty: float = sb.position.y + (sb.size.y - th) * (float(p["scroll"]) / float(p["max_scroll"]))
		ci.draw_rect(Rect2(sb.position.x, ty, sb.size.x, th), Color(ink, 0.6))
	# The foot: the focused row's help, then the keys.
	var foot: Rect2 = p["footer"]
	var fy: float = foot.position.y + UiText.ascent(fs_small)
	var help := ""
	var rws_p: Array = p["rows"]
	if focus >= 0 and focus < rws_p.size():
		help = str(rws_p[focus]["help"])
	if str(p["status"]) != "":
		help = str(p["status"])
	var hl: PackedStringArray = UiText.wrap(help, fs_small, foot.size.x)
	var nl: int = int(p["help_lines"])
	for k in range(nl):
		if k < hl.size():
			var ln: String = hl[k]
			if k == nl - 1 and hl.size() > nl:
				while ln.length() > 3 and UiText.width(ln + "...", fs_small) > foot.size.x:
					ln = ln.substr(0, ln.length() - 1)
				ln = ln.strip_edges() + "..."
			UiText.draw(ci, ln, Vector2(foot.position.x, fy), fs_small, ink, -1)
		fy += float(p["lh_small"])
	if str(p["hint"]) != "":
		UiText.draw(ci, str(p["hint"]), Vector2(foot.position.x, fy), fs_small, dim, -1)
	var cl: Array = p["confirm_labels"]
	for k in range(cl.size()):
		var cr3: Rect2 = p["confirm"][k]
		UiIcons.rrect(ci, cr3, cr3.size.y * 0.3, Color(ink, 0.92) if k == 0 else Color(scrim, 0.8), Color(UiLook.col(UiLook.EDGE), 0.7), 1.8)
		UiText.draw(ci, str(cl[k]), Vector2(cr3.get_center().x, cr3.get_center().y + float(fs_body) * 0.35), fs_body, Color(UiLook.col(UiLook.INK_DARK)) if k == 0 else ink, 0)
	UiText.no_outline = false


static func _btn(ci: CanvasItem, r: Rect2, a: float, ink: Color, edge: Color, scrim: Color, glyph: String, w: float) -> void:
	var rr := Rect2(r.position + r.size * 0.12, r.size * 0.76)
	UiIcons.rrect(ci, rr, rr.size.y * 0.3, Color(scrim, 0.8 * a), Color(edge, a), 1.6)
	var c: Vector2 = rr.get_center()
	var k: float = rr.size.y * 0.22
	match glyph:
		"minus":
			ci.draw_line(c + Vector2(-k, 0), c + Vector2(k, 0), Color(ink, a), w, true)
		"plus":
			ci.draw_line(c + Vector2(-k, 0), c + Vector2(k, 0), Color(ink, a), w, true)
			ci.draw_line(c + Vector2(0, -k), c + Vector2(0, k), Color(ink, a), w, true)
		"left":
			UiIcons.chevron(ci, c, k * 1.6, -1.0, w, Color(ink, a))
		"right":
			UiIcons.chevron(ci, c, k * 1.6, 1.0, w, Color(ink, a))


static func _draw_ctl(ci: CanvasItem, rec: Dictionary, ctl: Dictionary, a: float, ink: Color, dim: Color, dark: Color, edge: Color, scrim: Color, tm: float, fs: int, w: float, cs: float) -> void:
	match rec["kind"]:
		TOGGLE:
			var sw: Rect2 = ctl["switch"]
			var is_on: bool = str(rec["word"]) == str(data().get("on", "On")) and bool(rec["enabled"])
			UiIcons.rrect(ci, sw, sw.size.y * 0.5, Color(ink, 0.92 * a) if is_on else Color(scrim, 0.8 * a), Color(edge, a), 1.8)
			var kr: float = sw.size.y * 0.34
			var kx: float = sw.end.x - sw.size.y * 0.5 if is_on else sw.position.x + sw.size.y * 0.5
			ci.draw_circle(Vector2(kx, sw.get_center().y), kr, Color(dark, a) if is_on else Color(ink, a))
			UiText.draw(ci, str(rec["word"]), Vector2(sw.position.x - tm * 0.2, sw.get_center().y + float(fs) * 0.35), fs, Color(dim, a), 1)
		CHOICE:
			_btn(ci, ctl["left"], a, ink, edge, scrim, "left", w)
			_btn(ci, ctl["right"], a, ink, edge, scrim, "right", w)
			var vr: Rect2 = ctl["value"]
			UiText.draw(ci, str(rec["word"]), Vector2(vr.get_center().x, vr.get_center().y + float(fs) * 0.35), fs, Color(ink, a), 0)
		SLIDER:
			_btn(ci, ctl["minus"], a, ink, edge, scrim, "minus", w)
			_btn(ci, ctl["plus"], a, ink, edge, scrim, "plus", w)
			var tr: Rect2 = ctl["track"]
			var ty: float = tr.get_center().y
			var th: float = maxf(4.0, tm * 0.1)
			var x0: float = tr.position.x + tm * 0.2
			var x1: float = tr.end.x - tm * 0.2
			ci.draw_line(Vector2(x0, ty), Vector2(x1, ty), Color(edge, 0.5 * a), th, true)
			var kx2: float = x0 + (x1 - x0) * float(rec["frac"])
			ci.draw_line(Vector2(x0, ty), Vector2(kx2, ty), Color(ink, a), th, true)
			ci.draw_circle(Vector2(kx2, ty), tm * 0.2, Color(ink, a))
			var vr2: Rect2 = ctl["value"]
			UiText.draw(ci, str(rec["word"]), Vector2(vr2.end.x, vr2.get_center().y + float(fs) * 0.35), fs, Color(ink, a), 1)
		BUTTON:
			var br: Rect2 = ctl["button"]
			UiIcons.rrect(ci, br, br.size.y * 0.3, Color(scrim, 0.8 * a), Color(edge, 0.9 * a), 1.8)
			UiText.draw(ci, str(rec["word"]), Vector2(br.get_center().x, br.get_center().y + float(fs) * 0.35), fs, Color(ink, a), 0)
		BIND:
			var tp: Rect2 = ctl["tap"]
			if bool(rec.get("capturing", false)):
				UiText.draw(ci, str(rec["word"]), Vector2(tp.end.x - tm * 0.2, tp.get_center().y + float(fs) * 0.35), fs, Color(UiLook.col(UiLook.WARN)), 1)
			else:
				var gh: float = float(rec["gh"])
				var tw: float = 0.0
				for sp in rec["specs"]:
					tw += UiGlyphs.width_spec(sp, gh) + gh * 0.08
				var gx: float = tp.end.x - tw
				for sp in rec["specs"]:
					gx += UiGlyphs.draw_spec(ci, sp, Vector2(gx, tp.get_center().y), gh, a, true) + gh * 0.08
