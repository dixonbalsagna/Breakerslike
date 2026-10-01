class_name UiPause
extends RefCounted
## The pause menu (docs/ui/hud-spec.md section 28): a card with Resume, How to play, Settings, Send feedback and New match, opened by the
## host's pause key or button, with a focus ring so a keyboard or a pad can reach every entry. New match asks first (Start it, or Keep
## playing). `plan` is pure geometry (so hud_check proves every button is a 48 dp target inside the card at every size, one column when the
## height allows and two when it does not), `hit` says what a point is on, `draw` paints from a plan. Every word is in terms.json (prompt.pause_*).

const ENTRIES: Array = ["resume", "howto", "settings", "feedback", "new"]
## While two people play, player two can be handed back to the AI from here.
const ENTRIES_TWO: Array = ["resume", "howto", "settings", "feedback", "p2_leave", "new"]
const CONFIRM: Array = ["new_yes", "new_no"]
const KEYS: Dictionary = {"resume": "pause_resume_key", "howto": "pause_howto_key", "new": "pause_new_key"}


static func ids(confirm: bool, two: bool = false) -> Array:
	return CONFIRM if confirm else (ENTRIES_TWO if two else ENTRIES)


static func label(id: String) -> String:
	return UiData.t("prompt.pause_" + id)


## The geometry for a viewport. `st` is {focus: index into ids(confirm, two), confirm: bool, two: bool (two people play: the hand-back entry),
## join: bool (player two is the AI and may join: a line under the buttons says how)}. Returns {card, title, title_pos, items[{id, label, key, rect}],
## cols, tm, fs_body, fs_title, fs_small, fits, bw}.
static func plan(vp: Vector2, s: float, dp: float, touch: bool, st: Dictionary) -> Dictionary:
	var confirm: bool = bool(st.get("confirm", false))
	var list: Array = ids(confirm, bool(st.get("two", false)))
	var join: bool = bool(st.get("join", false)) and not confirm
	var tm: float = maxf(48.0 * dp, 44.0)
	var margin: float = maxf(vp.x * 0.03, 12.0)
	var my: float = maxf(vp.y * 0.04, 10.0)
	var cs: float = maxf(s, 0.3)
	var pad: float = maxf(20.0 * cs, 10.0)
	var fs_title: int = UiText.px(34.0, cs)
	var fs_body: int = UiText.px(22.0, cs)
	var fs_small: int = UiText.px(18.0, cs)
	var gap: float = maxf(10.0 * cs, 6.0)
	var title: String = UiData.t("prompt.pause_new_ask") if confirm else UiData.t("prompt.pause_title")
	var title_h: float = UiText.height(fs_title) * 1.15 + gap
	var avail_w: float = vp.x - 2.0 * margin - 2.0 * pad
	var avail_h: float = vp.y - 2.0 * my - 2.0 * pad
	var widest: float = UiText.width(title, fs_title) - tm * 0.9
	for id in list:
		var w: float = UiText.width(label(id), fs_body) + (UiText.width(UiData.t("prompt." + str(KEYS[id])) , fs_small) + pad if (not touch and KEYS.has(id)) else 0.0)
		widest = maxf(widest, w)
	var bw0: float = maxf(maxf(300.0 * cs, tm * 4.0), widest + tm * 0.9)
	var join_text: String = UiData.t("prompt.pause_p2_join") if join else ""
	var lh_small: float = UiText.height(fs_small) * 1.15
	var cols: int = 1
	var join_h1: float = (lh_small * 2.0 + gap) if join else 0.0
	if title_h + float(list.size()) * (tm + gap) - gap + join_h1 > avail_h:
		cols = 2
	var rows_n: int = int(ceil(float(list.size()) / float(cols)))
	var bw: float = minf(bw0, (avail_w - float(cols - 1) * gap) / float(cols))
	var cw: float = float(cols) * bw + float(cols - 1) * gap + 2.0 * pad
	var join_lines: PackedStringArray = UiText.wrap(join_text, fs_small, cw - 2.0 * pad) if join else PackedStringArray()
	var join_h: float = (float(join_lines.size()) * lh_small + gap) if join else 0.0
	var chh: float = pad * 2.0 + title_h + float(rows_n) * (tm + gap) - gap + join_h
	var card := Rect2((vp.x - cw) * 0.5, (vp.y - chh) * 0.5, cw, chh)
	var items: Array = []
	for i in range(list.size()):
		var col: int = i % cols
		var row: int = i / cols
		var r := Rect2(card.position.x + pad + float(col) * (bw + gap), card.position.y + pad + title_h + float(row) * (tm + gap), bw, tm)
		var id: String = str(list[i])
		items.append({"id": id, "label": label(id), "key": UiData.t("prompt." + str(KEYS[id])) if (KEYS.has(id) and not touch) else "", "rect": r})
	var fits: bool = Rect2(Vector2.ZERO, vp).encloses(card) and UiText.width(title, fs_title) <= cw - 2.0 * pad
	for it in items:
		var need: float = UiText.width(str(it["label"]), fs_body) + (UiText.width(str(it["key"]), fs_small) + gap * 2.0 if str(it["key"]) != "" else 0.0) + 16.0
		if need > bw or not card.encloses(it["rect"]) or (it["rect"] as Rect2).size.y < tm - 0.01:
			fits = false
	var join_pos := Vector2(card.position.x + pad, card.end.y - pad - float(join_lines.size()) * lh_small + UiText.ascent(fs_small))
	return {"join_lines": join_lines, "join_pos": join_pos, "lh_small": lh_small, "card": card, "title": title, "title_pos": Vector2(card.position.x + pad, card.position.y + pad + UiText.ascent(fs_title)), "items": items, "cols": cols, "tm": tm,
		"fs_body": fs_body, "fs_title": fs_title, "fs_small": fs_small, "fits": fits, "bw": bw, "focus": int(st.get("focus", 0)), "confirm": confirm, "two": bool(st.get("two", false)), "join": join, "touch": touch, "cs": cs, "pad": pad, "gap": gap}


## The id of the button a point is on, or "".
static func hit(p: Dictionary, pos: Vector2) -> String:
	for it in p["items"]:
		if (it["rect"] as Rect2).has_point(pos):
			return str(it["id"])
	return ""


## The focus after a move: dx and dy are -1, 0 or 1 (a grid of `cols` columns); it stays put at an edge.
static func moved(p: Dictionary, focus: int, dx: int, dy: int) -> int:
	var n: int = (p["items"] as Array).size()
	var cols: int = int(p["cols"])
	var f: int = clampi(focus, 0, n - 1)
	if dx != 0:
		var nf: int = f + dx
		if nf >= 0 and nf < n and (nf / cols) == (f / cols):
			f = nf
		elif cols == 1:
			f = clampi(nf, 0, n - 1)
	if dy != 0:
		var nf2: int = f + dy * cols
		if nf2 >= 0 and nf2 < n:
			f = nf2
	return f


static func sig(p: Dictionary) -> Array:
	return [int((p["card"] as Rect2).size.x), int((p["card"] as Rect2).size.y), int(p["cs"] * 100.0), p["touch"], int(p["focus"]), p["confirm"], p["two"], p["join"]]


static func draw(ci: CanvasItem, p: Dictionary) -> void:
	var vp: Vector2 = ci.size if ci is Control else Vector2(1920, 1080)
	var ink := Color(UiLook.col(UiLook.INK))
	var dim := Color(UiLook.col(UiLook.INK_DIM))
	var dark := Color(UiLook.col(UiLook.INK_DARK))
	var edge := Color(UiLook.col(UiLook.EDGE), 0.55)
	var scrim := Color(UiLook.col(UiLook.SCRIM))
	var card: Rect2 = p["card"]
	var fs_body: int = p["fs_body"]
	var focus: int = int(p["focus"])
	var touch: bool = p["touch"]
	UiText.no_outline = true
	ci.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.03, 0.06, 0.62))
	UiIcons.rrect(ci, card, 18.0 * float(p["cs"]), Color(scrim, 0.97), edge, 2.0)
	UiText.draw(ci, str(p["title"]), p["title_pos"], int(p["fs_title"]), ink, -1)
	var items: Array = p["items"]
	for i in range(items.size()):
		var it: Dictionary = items[i]
		var r: Rect2 = it["rect"]
		# The focused button is the filled one (a touch screen has no focus to show: Resume, the first, is the filled one).
		var on: bool = (i == focus) if not touch else (i == 0)
		UiIcons.rrect(ci, r, r.size.y * 0.3, Color(ink, 0.92) if on else Color(scrim, 0.8), Color(UiLook.col(UiLook.EDGE), 0.8), 1.8)
		var col: Color = dark if on else ink
		UiText.draw(ci, str(it["label"]), Vector2(r.position.x + r.size.y * 0.4, r.get_center().y + float(fs_body) * 0.35), fs_body, col, -1)
		if str(it["key"]) != "":
			UiText.draw(ci, str(it["key"]), Vector2(r.end.x - r.size.y * 0.4, r.get_center().y + float(p["fs_small"]) * 0.35), int(p["fs_small"]), Color(dark if on else dim, 0.8), 1)
	var jp: Vector2 = p["join_pos"]
	for ln in p["join_lines"]:
		UiText.draw(ci, ln, jp, int(p["fs_small"]), Color(dim, 0.9), -1)
		jp.y += float(p["lh_small"])
	UiText.no_outline = false
