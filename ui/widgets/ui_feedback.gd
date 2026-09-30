class_name UiFeedback
extends RefCounted
## The in-game feedback panel (docs/ui/hud-spec.md section 20) for friends' playtests: a few quick tags, a free-text box, and COPY
## REPORT, which puts a plain-text report on the clipboard for the player to paste to Orb. No network call, no account, nothing
## personal: the report holds the build, the match seed and setup, the match time, the platform and browser family, the settings, the
## tags and what the player typed. `plan` is pure geometry (so hud_check can prove the panel fits and every control is a touch
## target), `draw` paints the frame, `build_report` makes the text. The two text boxes are real TextEdit nodes the HUD places.
##
## Two states: "write" (tags and the text box) and "copied" (the report in a read-only box, for players whose browser would not
## let the page write the clipboard: select it and copy it by hand).

const STATE_WRITE := "write"
const STATE_COPIED := "copied"


static func data() -> Dictionary:
	return UiData.feedback()


static func tag_list() -> Array:
	return data().get("tags", [])


static func word(key: String) -> String:
	return str((data().get("report", {}) as Dictionary).get(key, key))


# --- The report -----------------------------------------------------------------------------------------------------------------

## Browser family and major version from a user-agent string, never the string itself: "Chrome 126", "Firefox 127", "Safari 17".
static func browser_from_ua(ua: String) -> String:
	for pair in [["Edg/", "Edge"], ["OPR/", "Opera"], ["Firefox/", "Firefox"], ["Chrome/", "Chrome"], ["Version/", "Safari"]]:
		var i: int = ua.find(pair[0])
		if i >= 0:
			if pair[0] == "Version/" and not ua.contains("Safari/"):
				continue
			var rest: String = ua.substr(i + String(pair[0]).length())
			var major := ""
			for ch in rest:
				if ch >= "0" and ch <= "9":
					major += ch
				else:
					break
			return "%s %s" % [pair[1], major] if major != "" else String(pair[1])
	return "unknown browser"


## The operating-system family from a user-agent string: a word, never a version or a device model.
static func os_from_ua(ua: String) -> String:
	if ua.contains("Android"):
		return "Android"
	if ua.contains("iPhone") or ua.contains("iPad") or ua.contains("iPod"):
		return "iOS"
	if ua.contains("Windows"):
		return "Windows"
	if ua.contains("Mac OS X") or ua.contains("Macintosh"):
		return "macOS"
	if ua.contains("CrOS"):
		return "ChromeOS"
	if ua.contains("Linux") or ua.contains("X11"):
		return "Linux"
	return "unknown OS"


## {os, browser, web, mobile, engine} for this run, coarse on purpose.
static func platform_info() -> Dictionary:
	var info := {"os": OS.get_name(), "browser": "", "web": OS.has_feature("web"), "mobile": OS.has_feature("mobile"), "engine": str(Engine.get_version_info().get("string", ""))}
	if info["web"]:
		var ua = JavaScriptBridge.eval("navigator.userAgent || ''", true)
		var uas: String = str(ua) if ua != null else ""
		info["os"] = os_from_ua(uas)
		info["browser"] = browser_from_ua(uas)
		info["mobile"] = uas.contains("Mobile") or uas.contains("Android") or uas.contains("iPhone") or uas.contains("iPad")
	return info


static func platform_line(info: Dictionary) -> String:
	if bool(info.get("web", false)):
		return "Web, %s, %s%s" % [info.get("browser", ""), info.get("os", ""), ", mobile" if bool(info.get("mobile", false)) else ""]
	return "%s%s" % [info.get("os", ""), ", mobile" if bool(info.get("mobile", false)) else ""]


## {commit, date} from res://build_info.json if the build wrote one (CI does); {} otherwise.
static func build_info() -> Dictionary:
	if not FileAccess.file_exists("res://build_info.json"):
		return {}
	var f := FileAccess.open("res://build_info.json", FileAccess.READ)
	if f == null:
		return {}
	var v = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}


static func format_time(sec: float) -> String:
	var t: int = maxi(0, int(sec))
	return "%02d:%02d" % [t / 60, t % 60]


## The player-facing options as "key=value", sorted: booleans as on or off, numbers to two places.
static func settings_line(opts: Dictionary) -> String:
	var keys: Array = (UiData.options() as Dictionary).keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k in keys:
		if not opts.has(k):
			continue
		var v = opts[k]
		var vs: String
		if v is bool:
			vs = "on" if v else "off"
		elif v is float:
			vs = "%.2f" % v
		else:
			vs = str(v)
		parts.append("%s=%s" % [k, vs])
	return ", ".join(parts)


## The report. ctx: {commit, date, seed, setup, time, ended}; env: {screen: Vector2, dp, touch, platform: Dictionary, settings: String}.
## Plain text, one fact a line, so it reads in a chat message.
static func build_report(ctx: Dictionary, tags: Array, notes: String, env: Dictionary) -> String:
	var unk: String = word("unknown")
	var build: String = str(ctx.get("commit", ""))
	if build == "":
		build = unk
	if str(ctx.get("date", "")) != "":
		build += " (%s)" % ctx["date"]
	var seed_s: String = str(ctx["seed"]) if ctx.has("seed") and str(ctx["seed"]) != "" else unk
	var setup: String = str(ctx.get("setup", ""))
	if setup == "":
		setup = unk
	var tm: String = format_time(float(ctx.get("time", 0.0))) + " (" + word("ended" if bool(ctx.get("ended", false)) else "in_progress") + ")"
	var scr: Vector2 = env.get("screen", Vector2.ZERO)
	var screen: String = "%dx%d, density %.1f, touch %s" % [int(scr.x), int(scr.y), float(env.get("dp", 1.0)), "on" if bool(env.get("touch", false)) else "off"]
	var plat: Dictionary = env.get("platform", {})
	var tag_names: PackedStringArray = []
	for id in tags:
		for t in tag_list():
			if str(t["id"]) == str(id):
				tag_names.append(str(t["label"]))
	var lines: PackedStringArray = [
		str(word("title")),
		"%s: %s" % [word("build"), build],
		"%s: %s" % [word("seed"), seed_s],
		"%s: %s" % [word("setup"), setup],
		"%s: %s" % [word("time"), tm],
		"%s: %s" % [word("screen"), screen],
		"%s: %s" % [word("platform"), platform_line(plat)],
		"%s: %s" % [word("engine"), str(plat.get("engine", "")) if str(plat.get("engine", "")) != "" else unk],
		"%s: %s" % [word("settings"), str(env.get("settings", ""))],
		"%s: %s" % [word("tags"), ", ".join(tag_names) if not tag_names.is_empty() else word("none")],
		"%s:" % word("notes"),
		notes.strip_edges() if notes.strip_edges() != "" else "(" + word("none") + ")",
	]
	return "\n".join(lines)


# --- The panel's geometry ---------------------------------------------------------------------------------------------------------

## Rectangles for a viewport. `state` is write or copied. Every control is at least 48 dp; the card is only as tall as it needs.
static func plan(vp: Vector2, s: float, dp: float, touch: bool, state: String) -> Dictionary:
	var tm: float = maxf(48.0 * dp, 44.0)
	var margin: float = maxf(vp.x * 0.03, 12.0)
	var my: float = maxf(vp.y * 0.04, 10.0)
	var cw: float = minf(vp.x - 2.0 * margin, maxf(1000.0 * s, 520.0))
	var ch_max: float = vp.y - 2.0 * my
	var cs: float = maxf(s, 0.3)
	var cs_min: float = UiLook.text_floor / 22.0
	var out: Dictionary = {}
	for rows in ([5, 3] if state == STATE_WRITE else [9, 6, 4, 3]):
		cs = maxf(s, 0.3)
		while true:
			out = _layout(Rect2((vp.x - cw) * 0.5, my, cw, ch_max), cs, tm, state, rows)
			if out["fits"] or cs <= cs_min + 0.001:
				break
			cs = maxf(cs_min, cs - 0.04)
		if out["fits"]:
			break
	# Centre the card vertically at the height it needs.
	var h2: float = minf(ch_max, float(out["need_h"]))
	var dy: float = (vp.y - h2) * 0.5 - float((out["card"] as Rect2).position.y)
	out = _layout(Rect2((vp.x - cw) * 0.5, (vp.y - h2) * 0.5, cw, h2), cs, tm, state, int(out["rows"]))
	out["state"] = state
	out["tm"] = tm
	return out


static func _layout(card: Rect2, cs: float, tm: float, state: String, rows: int) -> Dictionary:
	var pad: float = maxf(24.0 * cs, 10.0)
	var fs_title: int = UiText.px(34.0, cs)
	var fs_body: int = UiText.px(22.0, cs)
	var fs_small: int = UiText.px(18.0, cs)
	var lh: float = UiText.height(fs_body) * 1.15
	var inner := Rect2(card.position + Vector2(pad, pad), card.size - Vector2(pad, pad) * 2.0)
	var d: Dictionary = data()
	var close_sz: float = maxf(tm, 40.0 * cs)
	var close := Rect2(card.end.x - pad - close_sz, card.position.y + pad * 0.6, close_sz, close_sz)
	var title_w: float = UiText.width(str(d.get("title", "")), fs_title)
	var fits: bool = inner.position.x + title_w <= close.position.x - pad * 0.5
	var y: float = inner.position.y + maxf(UiText.height(fs_title), close_sz) + pad * 0.5
	var out: Dictionary = {"card": card, "inner": inner, "close": close, "cs": cs, "fs_title": fs_title, "fs_body": fs_body, "fs_small": fs_small, "lh": lh, "pad": pad, "rows": rows}
	var gap: float = maxf(pad * 0.5, 6.0)
	if state == STATE_WRITE:
		var hint_lines: PackedStringArray = UiText.wrap(str(d.get("hint", "")), fs_small, inner.size.x)
		out["hint_pos"] = Vector2(inner.position.x, y)
		out["hint_lines"] = hint_lines
		y += float(hint_lines.size()) * UiText.height(fs_small) * 1.15 + gap
		# The tags flow left to right and wrap.
		var chips: Array = []
		var x: float = inner.position.x
		var row_y: float = y
		var chip_gap: float = maxf(8.0 * cs, 6.0)
		for t in tag_list():
			var w: float = UiText.width(str(t["label"]), fs_body) + tm * 0.5 + pad * 1.2
			if x + w > inner.end.x and x > inner.position.x:
				x = inner.position.x
				row_y += tm + chip_gap
			chips.append({"id": str(t["id"]), "label": str(t["label"]), "rect": Rect2(x, row_y, w, tm)})
			x += w + chip_gap
		y = row_y + tm + gap * 1.4
		out["tags"] = chips
		var box_h: float = lh * float(rows) + pad
		out["text_rect"] = Rect2(inner.position.x, y, inner.size.x, box_h)
		y += box_h + gap * 1.4
		var btn_w: float = maxf(tm * 2.6, 170.0 * cs)
		out["copy"] = Rect2(inner.end.x - btn_w, y, btn_w, tm)
		out["back"] = Rect2()
		out["again"] = Rect2()
		out["done"] = Rect2(inner.position.x, y, maxf(tm * 2.0, 130.0 * cs), tm)
	else:
		var status: String = str(d.get("copied", ""))
		out["status_pos"] = Vector2(inner.position.x, y)
		y += UiText.height(fs_body) * 1.15
		var fb_lines: PackedStringArray = UiText.wrap(str(d.get("copied_fallback", "")), fs_small, inner.size.x)
		out["fallback_pos"] = Vector2(inner.position.x, y)
		out["fallback_lines"] = fb_lines
		y += float(fb_lines.size()) * UiText.height(fs_small) * 1.15 + gap
		var box_h2: float = lh * float(rows) + pad
		out["preview_rect"] = Rect2(inner.position.x, y, inner.size.x, box_h2)
		y += box_h2 + gap * 1.4
		# The buttons flow left to right and wrap on a narrow screen.
		var bx: float = inner.position.x
		var by: float = y
		var btns: Dictionary = d.get("buttons", {})
		for pair in [["again", str(btns.get("copy_again", "COPY AGAIN"))], ["back", str(btns.get("back", "BACK"))], ["done", str(btns.get("close", "CLOSE"))]]:
			var bw: float = maxf(tm * 1.8, UiText.width(pair[1], fs_body) + pad * 1.6)
			if bx + bw > inner.end.x and bx > inner.position.x:
				bx = inner.position.x
				by += tm + gap
			out[pair[0]] = Rect2(bx, by, bw, tm)
			bx += bw + gap * 2.0
		y = by
		out["copy"] = Rect2()
		if status == "":
			fits = false
	var need_h: float = y + tm + pad - card.position.y
	out["need_h"] = need_h
	out["fits"] = fits and need_h <= card.size.y + 0.5
	return out


# --- Drawing --------------------------------------------------------------------------------------------------------------------

static func sig(vp: Vector2, state: String, selected: Dictionary, status_ok: bool, dp: float, s: float, touch: bool) -> Array:
	var bits := 0
	var i := 0
	for t in tag_list():
		if selected.get(str(t["id"]), false):
			bits |= (1 << i)
		i += 1
	return [int(vp.x), int(vp.y), state, bits, status_ok, int(dp * 100.0), int(s * 100.0), touch]


static func draw(ci: CanvasItem, p: Dictionary, selected: Dictionary) -> void:
	var d: Dictionary = data()
	var vp: Vector2 = ci.size if ci is Control else Vector2(1920, 1080)
	var card: Rect2 = p["card"]
	var ink := Color(UiLook.col(UiLook.INK))
	var dim := Color(UiLook.col(UiLook.INK_DIM))
	var edge := Color(UiLook.col(UiLook.EDGE), 0.55)
	var fs_body: int = p["fs_body"]
	var fs_small: int = p["fs_small"]
	UiText.no_outline = true
	ci.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.03, 0.06, 0.78))
	UiIcons.rrect(ci, card, 18.0 * float(p["cs"]), Color(UiLook.col(UiLook.SCRIM), 0.97), edge, 2.0)
	var inner: Rect2 = p["inner"]
	UiText.draw(ci, str(d.get("title", "")), Vector2(inner.position.x, inner.position.y + UiText.ascent(int(p["fs_title"]))), int(p["fs_title"]), ink, -1)
	# The close button.
	var close: Rect2 = p["close"]
	UiIcons.rrect(ci, close, close.size.y * 0.25, Color(UiLook.col(UiLook.SCRIM), 0.8), edge, 1.6)
	var cc: Vector2 = close.get_center()
	var cr: float = close.size.x * 0.22
	UiIcons.line(ci, cc + Vector2(-cr, -cr), cc + Vector2(cr, cr), maxf(2.0, close.size.x * 0.06), ink)
	UiIcons.line(ci, cc + Vector2(-cr, cr), cc + Vector2(cr, -cr), maxf(2.0, close.size.x * 0.06), ink)
	var btns: Dictionary = d.get("buttons", {})
	if p["state"] == STATE_WRITE:
		var hp: Vector2 = p["hint_pos"]
		for ln in p["hint_lines"]:
			UiText.draw(ci, ln, Vector2(hp.x, hp.y + UiText.ascent(fs_small)), fs_small, dim, -1)
			hp.y += UiText.height(fs_small) * 1.15
		for chip in p["tags"]:
			var r: Rect2 = chip["rect"]
			var on: bool = bool(selected.get(chip["id"], false))
			UiIcons.rrect(ci, r, r.size.y * 0.5, Color(ink, 0.92) if on else Color(UiLook.col(UiLook.SCRIM), 0.8), Color(UiLook.col(UiLook.EDGE), 0.8), 1.8)
			var tcol := Color(UiLook.col(UiLook.INK_DARK)) if on else ink
			var bx: float = r.position.x + r.size.y * 0.5
			if on:
				var cy: float = r.get_center().y
				var k: float = r.size.y * 0.18
				ci.draw_polyline(PackedVector2Array([Vector2(bx - k, cy), Vector2(bx - k * 0.2, cy + k * 0.9), Vector2(bx + k * 1.1, cy - k * 0.8)]), tcol, maxf(2.0, r.size.y * 0.07), true)
			else:
				ci.draw_arc(Vector2(bx, r.get_center().y), r.size.y * 0.16, 0.0, TAU, 14, Color(ink, 0.6), maxf(1.5, r.size.y * 0.05), true)
			UiText.draw(ci, str(chip["label"]), Vector2(r.position.x + r.size.y * 0.5 + r.size.y * 0.3, r.get_center().y - UiText.height(fs_body) * 0.5 + UiText.ascent(fs_body)), fs_body, tcol, -1)
		_button(ci, p["copy"], str(btns.get("copy", "COPY REPORT")), fs_body, true)
		_button(ci, p["done"], str(btns.get("close", "CLOSE")), fs_body, false)
	else:
		var sp: Vector2 = p["status_pos"]
		UiText.draw(ci, str(d.get("copied", "")), Vector2(sp.x, sp.y + UiText.ascent(fs_body)), fs_body, ink, -1)
		var fp: Vector2 = p["fallback_pos"]
		for ln in p["fallback_lines"]:
			UiText.draw(ci, ln, Vector2(fp.x, fp.y + UiText.ascent(fs_small)), fs_small, dim, -1)
			fp.y += UiText.height(fs_small) * 1.15
		_button(ci, p["back"], str(btns.get("back", "BACK")), fs_body, false)
		_button(ci, p["again"], str(btns.get("copy_again", "COPY AGAIN")), fs_body, false)
		_button(ci, p["done"], str(btns.get("close", "CLOSE")), fs_body, true)
	UiText.no_outline = false


static func _button(ci: CanvasItem, r: Rect2, label: String, fs: int, primary: bool) -> void:
	if r.size.y <= 0.0:
		return
	var ink := Color(UiLook.col(UiLook.INK))
	UiIcons.rrect(ci, r, r.size.y * 0.3, Color(ink, 0.92) if primary else Color(UiLook.col(UiLook.SCRIM), 0.8), Color(UiLook.col(UiLook.EDGE), 0.7), 1.8)
	UiText.draw(ci, label, Vector2(r.get_center().x, r.get_center().y - UiText.height(fs) * 0.5 + UiText.ascent(fs)), fs, Color(UiLook.col(UiLook.INK_DARK)) if primary else ink, 0)


## The match-end button: a pill with the words SEND FEEDBACK, centred in `r` (the layout's feedback_btn).
static func draw_pill(ci: CanvasItem, r: Rect2, s: float, label: String, fs: int) -> void:
	if r.size.y <= 0.0:
		return
	var ink := Color(UiLook.col(UiLook.INK))
	UiText.no_outline = true
	UiIcons.rrect(ci, r, r.size.y * 0.5, Color(UiLook.col(UiLook.SCRIM), 0.85), Color(UiLook.col(UiLook.EDGE), 0.75), maxf(1.6, 2.0 * s))
	UiText.draw(ci, label, Vector2(r.get_center().x, r.get_center().y - UiText.height(fs) * 0.5 + UiText.ascent(fs)), fs, ink, 0)
	UiText.no_outline = false
