class_name UiHowto
extends RefCounted
## The How to play card (docs/ui/hud-spec.md section 17): three short pages, shown on the first run and from the pause menu.
##   1. You choose. The fight follows.   (the core idea and the four stances)
##   2. Controls                         (the keys, pad glyphs or touch controls of the player's own device)
##   3. Reading the fight                (the few HUD reads: crown, cards, brink, windows, finisher rings, toll, strip)
## Every word is data (ui/data/howto.json). `plan` is pure geometry, so hud_check can prove that every page fits at every size and
## that every button is a real touch target; `draw` paints from a plan. The card scales with the screen and its density (text is at
## least the HUD's floor, 12 dp on a phone) and shrinks its type until a page fits, rather than clipping.

const PAGE_PAD := 24.0
const FIRST_PAGE := 0


static func page_count() -> int:
	return (UiData.howto().get("pages", []) as Array).size()


## The geometry of page `page_i` for a viewport: {card, title, close, back, next, dots, items[], cs, fits, tm, ...}. `device` is the
## glyph family ("kbd", "xbox", ...), `slot` the player's slot (P1 or P2 keys), `touch` true for the touch controls page.
static func plan(vp: Vector2, s: float, dp: float, touch: bool, page_i: int, device: String = "kbd", slot: int = 0) -> Dictionary:
	var data: Dictionary = UiData.howto()
	var pages: Array = data.get("pages", [])
	var n: int = pages.size()
	var pi: int = clampi(page_i, 0, maxi(n - 1, 0))
	var page: Dictionary = pages[pi] if n > 0 else {}
	var tm: float = maxf(48.0 * dp, 44.0)
	var margin: float = maxf(vp.x * 0.03, 12.0)
	var my: float = maxf(vp.y * 0.04, 10.0)
	var cw: float = minf(vp.x - 2.0 * margin, maxf(1500.0 * s, 560.0))
	var ch: float = minf(vp.y - 2.0 * my, maxf(900.0 * s, 360.0))
	var card := Rect2((vp.x - cw) * 0.5, (vp.y - ch) * 0.5, cw, ch)
	var cs: float = maxf(s, 0.3)
	var cs_min: float = UiLook.text_floor / 24.0
	var need_h: float = 0.0
	var all_fit: bool = true
	# Lay every page out at one scale so the card keeps one size across pages; shrink the type until all of them fit.
	while true:
		need_h = 0.0
		all_fit = true
		for k in range(n):
			var r: Dictionary = _layout(card, cs, tm, touch, pages[k], k, n, device, slot, data)
			need_h = maxf(need_h, float(r["need_h"]))
			all_fit = all_fit and bool(r["fits"])
		if all_fit or cs <= cs_min + 0.001:
			break
		cs = maxf(cs_min, cs - 0.04)
	# The card is as tall as its tallest page needs (centred), not the whole screen.
	var h2: float = minf(ch, maxf(need_h, 240.0 * cs))
	card = Rect2(card.position.x, (vp.y - h2) * 0.5, cw, h2)
	var out: Dictionary = _layout(card, cs, tm, touch, page, pi, n, device, slot, data)
	out["fits"] = all_fit
	out["page"] = pi
	out["pages"] = n
	out["tm"] = tm
	return out


static func _layout(card: Rect2, cs: float, tm: float, touch: bool, page: Dictionary, pi: int, n: int, device: String, slot: int, data: Dictionary) -> Dictionary:
	var pad: float = maxf(PAGE_PAD * cs, 10.0)
	var fs_title: int = UiText.px(36.0, cs)
	var fs_body: int = UiText.px(24.0, cs)
	var fs_small: int = UiText.px(19.0, cs)
	var lh: float = UiText.height(fs_body) * 1.12
	var btn_h: float = maxf(tm, 44.0 * cs)
	var inner := Rect2(card.position + Vector2(pad, pad), card.size - Vector2(pad, pad) * 2.0)
	# Header: the page title, the close button at the right.
	var close_sz: float = maxf(tm, 40.0 * cs)
	var close := Rect2(card.end.x - pad - close_sz, card.position.y + pad * 0.6, close_sz, close_sz)
	var title_h: float = maxf(UiText.height(fs_small) * 1.1 + UiText.height(fs_title), close_sz)
	var body_top: float = inner.position.y + title_h + pad * 0.9
	var footer := Rect2(inner.position.x, card.end.y - pad - btn_h, inner.size.x, btn_h)
	var body := Rect2(inner.position.x, body_top, inner.size.x, footer.position.y - pad * 0.6 - body_top)
	var back_w: float = maxf(tm * 2.0, 120.0 * cs)
	var next_w: float = maxf(tm * 2.0, 140.0 * cs)
	var back := Rect2(footer.position.x, footer.position.y, back_w, btn_h)
	var nxt := Rect2(footer.end.x - next_w, footer.position.y, next_w, btn_h)
	var dots: Array = []
	var dot_gap: float = maxf(22.0 * cs, 14.0)
	for i in range(n):
		dots.append(Vector2(footer.position.x + footer.size.x * 0.5 + (float(i) - float(n - 1) * 0.5) * dot_gap, footer.position.y + btn_h * 0.5))
	# The items, in columns. Two columns when the body is wide; items carry their own column in the data (col 0 or 1).
	var items: Array = page.get("items", [])
	if touch and page.has("touch_items"):
		items = page["touch_items"]
	var cols: int = 2 if body.size.x >= float(fs_body) * 38.0 else 1
	var gap: float = maxf(pad * 0.7, 8.0)
	var colw: float = (body.size.x - gap * float(cols - 1)) / float(cols)
	var heights: Array = [0.0, 0.0]
	var placed: Array = []
	var isz: float = maxf(34.0 * cs, float(fs_body) * 1.7)
	var item_gap: float = maxf(10.0 * cs, 5.0)
	# Stance rows put the stance's name and its line side by side; the names share one column width.
	var name_w: float = 0.0
	for it0 in items:
		if str(it0.get("stance", "")) != "":
			name_w = maxf(name_w, UiText.width(UiData.t("stance." + str(it0["stance"])), fs_body))
	name_w += gap
	for it in items:
		var col: int = mini(int(it.get("col", 0)), cols - 1) if cols == 2 else 0
		if it.has("note") and str(it["note"]) == "kbd_p2" and device != "kbd":
			continue
		var x: float = body.position.x + float(col) * (colw + gap)
		var y: float = body.position.y + float(heights[col])
		var rec: Dictionary = {"item": it, "col": col, "fs": fs_body, "fs_small": fs_small}
		var text: String = str(it.get("text", ""))
		if it.has("heading"):
			var hh: float = UiText.height(fs_body) * 1.25
			rec["rect"] = Rect2(x, y, colw, hh)
			rec["kind"] = "heading"
			rec["lines"] = PackedStringArray([str(it["heading"])])
			heights[col] = float(heights[col]) + hh + item_gap * 0.5
		elif it.has("note"):
			var ntext: String = str(data.get("reopen", "")) if str(it["note"]) == "reopen" else text
			var lines_n: PackedStringArray = UiText.wrap(ntext, fs_small, colw)
			var hn: float = float(lines_n.size()) * UiText.height(fs_small) * 1.12 + 2.0
			rec["rect"] = Rect2(x, y, colw, hn)
			rec["kind"] = "note"
			rec["lines"] = lines_n
			heights[col] = float(heights[col]) + hn + item_gap
		elif it.has("action") or it.has("actions"):
			var acts: Array = it["actions"] if it.has("actions") else [it["action"]]
			var gh: float = isz
			var gw_total: float = 0.0
			for a in acts:
				gw_total += UiGlyphs.width(str(a), device, slot, gh) + gh * 0.25
			var label_x: float = x + maxf(gw_total, isz * 2.2) + gap
			var lines_a: PackedStringArray = UiText.wrap(text, fs_body, maxf(colw - (label_x - x), 20.0))
			var ha: float = maxf(isz, float(lines_a.size()) * lh) + 2.0
			rec["rect"] = Rect2(x, y, colw, ha)
			rec["kind"] = "action"
			rec["acts"] = acts
			rec["gh"] = gh
			rec["label_x"] = label_x
			rec["lines"] = lines_a
			heights[col] = float(heights[col]) + ha + item_gap
		else:
			var tx: float = x + isz + gap * 0.8
			var st: String = str(it.get("stance", ""))
			var lines_i: PackedStringArray = UiText.wrap(text, fs_body, maxf(colw - (tx - x) - (name_w if st != "" else 0.0), 20.0))
			var hi: float = maxf(isz, float(lines_i.size()) * lh) + 2.0
			rec["rect"] = Rect2(x, y, colw, hi)
			rec["kind"] = "icon"
			rec["icon_c"] = Vector2(x + isz * 0.5, y + isz * 0.5)
			rec["isz"] = isz
			rec["text_x"] = tx
			rec["name_w"] = name_w if st != "" else 0.0
			rec["lines"] = lines_i
			rec["stance"] = st
			heights[col] = float(heights[col]) + hi + item_gap
		placed.append(rec)
	var tallest: float = maxf(float(heights[0]), float(heights[1]))
	# The fit: the tallest column is inside the body, every line is inside its column, and the title clears the close button.
	var fits: bool = tallest - item_gap <= body.size.y + 0.5
	var title_text: String = str(page.get("title", ""))
	var dl: Dictionary = page.get("device_label", {})
	if not dl.is_empty():
		title_text += ": " + str(dl.get("touch" if touch else device, ""))
	var kicker: String = str(data.get("title", ""))
	var title_w: float = UiText.width(title_text, fs_title)
	if inner.position.x + title_w > close.position.x - pad * 0.5:
		fits = false
	# What the card needs in height for this page: the header, the tallest column, the footer and the paddings.
	var need_h: float = (body_top - card.position.y) + tallest - item_gap + pad * 0.6 + btn_h + pad
	return {"need_h": need_h, "card": card, "inner": inner, "body": body, "close": close, "back": back, "next": nxt, "dots": dots, "items": placed, "cs": cs, "fits": fits,
		"fs_title": fs_title, "fs_body": fs_body, "fs_small": fs_small, "lh": lh, "btn_h": btn_h, "pad": pad, "title_text": title_text, "kicker": kicker,
		"title_h": title_h, "tallest": tallest, "is_last": pi >= n - 1, "is_first": pi <= 0, "cols": cols}


## The redraw key: changes only with the page, the size, the device and the touch mode.
static func sig(vp: Vector2, page_i: int, device: String, slot: int, touch: bool, dp: float, s: float) -> Array:
	return [int(vp.x), int(vp.y), page_i, device, slot, touch, int(dp * 100.0), int(s * 100.0)]


# --- Drawing -------------------------------------------------------------------------------------------------------------------

static func draw(ci: CanvasItem, p: Dictionary, device: String, slot: int, style: String, touch: bool) -> void:
	var data: Dictionary = UiData.howto()
	var vp: Vector2 = ci.size if ci is Control else Vector2(1920, 1080)
	var card: Rect2 = p["card"]
	var fs_body: int = p["fs_body"]
	var fs_small: int = p["fs_small"]
	var fs_title: int = p["fs_title"]
	var ink := Color(UiLook.col(UiLook.INK))
	var dim := Color(UiLook.col(UiLook.INK_DIM))
	var edge := Color(UiLook.col(UiLook.EDGE), 0.55)
	UiText.no_outline = true
	# The scrim over the whole HUD, then the card.
	ci.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.03, 0.06, 0.78))
	UiIcons.rrect(ci, card, 18.0 * float(p["cs"]), Color(UiLook.col(UiLook.SCRIM), 0.97), edge, 2.0)
	var inner: Rect2 = p["inner"]
	var close: Rect2 = p["close"]
	# The heading: a small kicker, then the page's title.
	var kick_h: float = UiText.height(fs_small) * 1.1
	UiText.draw(ci, str(p["kicker"]), Vector2(inner.position.x, inner.position.y + UiText.ascent(fs_small)), fs_small, dim, -1)
	UiText.draw(ci, str(p["title_text"]), Vector2(inner.position.x, inner.position.y + kick_h + UiText.ascent(fs_title)), fs_title, ink, -1)
	if not touch and close.size.x > 0.0:
		var hint: String = str(data.get("hint", ""))
		var hw: float = UiText.width(hint, fs_small)
		if close.position.x - hw - 12.0 > inner.position.x + UiText.width(str(p["title_text"]), fs_title) + 20.0:
			UiText.draw(ci, hint, Vector2(close.position.x - 12.0, close.get_center().y + float(fs_small) * 0.35), fs_small, dim, 1)
	# The close button: a cross in a square target.
	UiIcons.rrect(ci, close, close.size.y * 0.25, Color(UiLook.col(UiLook.SCRIM), 0.8), edge, 1.6)
	var cc: Vector2 = close.get_center()
	var cr: float = close.size.x * 0.22
	UiIcons.line(ci, cc + Vector2(-cr, -cr), cc + Vector2(cr, cr), maxf(2.0, close.size.x * 0.06), ink)
	UiIcons.line(ci, cc + Vector2(-cr, cr), cc + Vector2(cr, -cr), maxf(2.0, close.size.x * 0.06), ink)
	# The items.
	var lh: float = p["lh"]
	for rec in p["items"]:
		var r: Rect2 = rec["rect"]
		var it: Dictionary = rec["item"]
		match rec["kind"]:
			"heading":
				UiText.draw(ci, str(rec["lines"][0]), Vector2(r.position.x, r.position.y + float(fs_body) * 0.9), fs_body, dim, -1)
			"note":
				var ny: float = r.position.y + float(fs_small) * 0.9
				for ln in rec["lines"]:
					UiText.draw(ci, ln, Vector2(r.position.x, ny), fs_small, dim, -1)
					ny += UiText.height(fs_small) * 1.12
			"action":
				var gh: float = rec["gh"]
				var gx: float = r.position.x
				for a in rec["acts"]:
					var w: float = UiGlyphs.draw(ci, str(a), device, slot, Vector2(gx, r.position.y + gh * 0.5), gh, 1.0, true, style)
					gx += w + gh * 0.25
				var ly: float = r.position.y + maxf(0.0, (r.size.y - float(rec["lines"].size()) * lh) * 0.5) + UiText.ascent(fs_body) + (lh - UiText.height(fs_body)) * 0.5
				for ln in rec["lines"]:
					UiText.draw(ci, ln, Vector2(rec["label_x"], ly), fs_body, ink, -1)
					ly += lh
			_:
				_icon(ci, str(it.get("icon", "")), rec["icon_c"], rec["isz"], float(p["cs"]))
				var ty: float = r.position.y + UiText.ascent(fs_body) + (lh - UiText.height(fs_body)) * 0.5
				if rec["stance"] != "":
					# The stance's name in its own words (terms.json), beside its line.
					var idx: int = int(str(it.get("icon", "stance_0")).get_slice("_", 1))
					UiText.draw(ci, UiData.t("stance." + str(rec["stance"])), Vector2(rec["text_x"], ty), fs_body, UiLook.stance_col(idx), -1)
				for ln in rec["lines"]:
					UiText.draw(ci, ln, Vector2(float(rec["text_x"]) + float(rec["name_w"]), ty), fs_body, ink, -1)
					ty += lh
	# The footer: back, the page dots, next (or got it).
	var b: Dictionary = data.get("buttons", {})
	var back: Rect2 = p["back"]
	var nxt: Rect2 = p["next"]
	if not p["is_first"]:
		_button(ci, back, str(b.get("back", "BACK")), fs_body, false)
	_button(ci, nxt, str(b.get("done", "GOT IT")) if p["is_last"] else str(b.get("next", "NEXT")), fs_body, true)
	var dots: Array = p["dots"]
	for i in range(dots.size()):
		var on: bool = i == int(p["page"])
		ci.draw_circle(dots[i], maxf(5.0, float(p["btn_h"]) * 0.12) * (1.25 if on else 1.0), ink if on else Color(dim, 0.5))
	UiText.no_outline = false


static func _button(ci: CanvasItem, r: Rect2, label: String, fs: int, primary: bool) -> void:
	var ink := Color(UiLook.col(UiLook.INK))
	UiIcons.rrect(ci, r, r.size.y * 0.3, Color(ink, 0.92) if primary else Color(UiLook.col(UiLook.SCRIM), 0.8), Color(UiLook.col(UiLook.EDGE), 0.7), 1.8)
	UiText.draw(ci, label, Vector2(r.get_center().x, r.get_center().y + float(fs) * 0.35), fs, Color(UiLook.col(UiLook.INK_DARK)) if primary else ink, 0)


## The little pictures. Each is a few shapes in a square of side `sz` centred at `c`, in the HUD's own neutral colours.
static func _icon(ci: CanvasItem, name: String, c: Vector2, sz: float, cs: float) -> void:
	var ink := Color(UiLook.col(UiLook.INK))
	var dim := Color(UiLook.col(UiLook.INK_DIM), 0.7)
	var w: float = maxf(2.0, sz * 0.07)
	var r: float = sz * 0.42
	if name.begins_with("stance_"):
		var i: int = int(name.get_slice("_", 1))
		UiIcons.stance(ci, i, c, sz * 0.85, UiLook.stance_col(i))
		return
	match name:
		"plan":
			# A crosshair: you choose where.
			ci.draw_arc(c, r * 0.62, 0.0, TAU, 24, ink, w, true)
			for k in range(4):
				var d: Vector2 = Vector2.from_angle(float(k) * PI * 0.5)
				ci.draw_line(c + d * r * 0.4, c + d * r * 1.05, ink, w)
			ci.draw_circle(c, sz * 0.07, ink)
		"auto":
			# Three chevrons in a row: it plays out on its own.
			for k in range(3):
				UiIcons.chevron(ci, c + Vector2((float(k) - 1.0) * sz * 0.26, 0.0), sz * 0.3, 1.0, w, ink)
		"body":
			var cols: Array = [UiLook.STAGE_FRESH, UiLook.STAGE_BRUISED, UiLook.STAGE_BATTERED, UiLook.STAGE_BROKEN]
			for k in range(4):
				ci.draw_circle(c + Vector2((float(k) - 1.5) * sz * 0.26, 0.0), sz * 0.11, Color(UiLook.col(cols[k])))
		"finisher":
			UiIcons.star4(ci, c, sz * 0.8, ink)
			ci.draw_arc(c, r, 0.0, TAU, 28, dim, w, true)
		"wrap":
			ci.draw_arc(c, r, -PI * 0.15, PI * 1.55, 24, ink, w, true)
			UiIcons.chevron(ci, c + Vector2(r * 0.85, -r * 0.45), sz * 0.22, PI * 0.15, w, ink)
		"crown":
			for k in range(8):
				var a0: float = float(k) * TAU / 8.0
				ci.draw_arc(c, r, a0, a0 + TAU / 8.0 * 0.6, 6, Color(UiLook.col(UiLook.CROWN_FRESH)), w * 1.3, true)
		"card":
			var cr := Rect2(c - Vector2(r * 1.15, r * 0.55), Vector2(r * 2.3, r * 1.1))
			UiIcons.rrect(ci, cr, r * 0.2, Color(UiLook.col(UiLook.SCRIM), 0.9), Color(UiLook.col(UiLook.STAGE_BROKEN)), w)
			ci.draw_line(cr.position + Vector2(r * 0.3, r * 0.55), cr.end - Vector2(r * 0.3, r * 0.55), ink, w)
		"brink":
			UiIcons.brink(ci, c, sz * 0.8, ink)
			ci.draw_arc(c, r, 0.0, TAU, 28, Color(ink, 0.35), w * 0.8, true)
		"reads":
			# Their stance and their weight: a stance chip over a heavy barbell.
			UiIcons.stance(ci, 1, c + Vector2(0.0, -r * 0.5), sz * 0.55, UiLook.stance_col(1))
			UiReads.weight_mark(ci, c + Vector2(0.0, r * 0.55), sz * 0.7, true, ink)
		"struggle":
			ci.draw_arc(c, r * 0.45, 0.0, TAU, 20, ink, w, true)
			ci.draw_arc(c, r * 0.75, 0.0, TAU, 24, dim, w, true)
			ci.draw_arc(c, r, 0.0, TAU, 28, Color(dim, 0.45), w, true)
		"toll":
			var tr := Rect2(c - Vector2(r * 1.2, r * 0.55), Vector2(r * 2.4, r * 1.1))
			UiIcons.rrect(ci, tr, r * 0.25, Color(UiLook.col(UiLook.SCRIM), 0.9), Color(UiLook.col(UiLook.EDGE), 0.7), w * 0.8)
			ci.draw_line(tr.position + Vector2(r * 0.3, r * 0.4), tr.position + Vector2(r * 1.6, r * 0.4), dim, w)
			ci.draw_line(tr.position + Vector2(r * 0.3, r * 0.75), tr.position + Vector2(r * 2.0, r * 0.75), dim, w)
		"strip":
			ci.draw_line(c + Vector2(-r * 1.2, 0), c + Vector2(r * 1.2, 0), dim, w * 1.4)
			ci.draw_circle(c + Vector2(-r * 0.55, 0), sz * 0.12, Color(UiLook.col(UiLook.STAGE_FRESH)))
			UiIcons.fill_poly(ci, PackedVector2Array([c + Vector2(r * 0.6, -sz * 0.14), c + Vector2(r * 0.6 + sz * 0.14, 0), c + Vector2(r * 0.6, sz * 0.14), c + Vector2(r * 0.6 - sz * 0.14, 0)]), ink)
		"touch_move":
			ci.draw_arc(c, r, 0.0, TAU, 24, dim, w, true)
			ci.draw_circle(c + Vector2(r * 0.25, -r * 0.2), sz * 0.14, ink)
		"touch_attack":
			for k in range(3):
				ci.draw_circle(c + Vector2.from_angle(PI * (1.05 + 0.4 * float(k))) * r * 0.75 + Vector2(r * 0.4, r * 0.5), sz * 0.13, ink)
		"touch_hold":
			ci.draw_arc(c, r, 0.0, TAU, 24, dim, w, true)
			ci.draw_arc(c, r, -PI * 0.5, PI * 0.6, 16, ink, w * 1.6, true)
		"touch_pause":
			ci.draw_rect(Rect2(c.x - sz * 0.2, c.y - sz * 0.25, sz * 0.14, sz * 0.5), ink)
			ci.draw_rect(Rect2(c.x + sz * 0.06, c.y - sz * 0.25, sz * 0.14, sz * 0.5), ink)
