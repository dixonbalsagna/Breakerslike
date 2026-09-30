class_name HudView
extends Control
## The greybox 2D overlay (prototype drawHUD and the text parts of drawFighter and drawParts): fighter panels (HP,
## ki, power, tier, stance, menace or anguish), world counters, the chain counter, the banner, fighter labels, damage
## numbers, the director's feed and the planet strip, shown only when `legacy` is on (F2) now that UI's HUD is hosted;
## and always the take-over prompt, the seed and tick, and the F3 performance readout.
## Reads the sim and the fx consumer only; world positions go to the screen through the 3D camera.

const FEED_LINES := 8

var main: Node       # the Main node (render/core/main.gd)
var show_perf: bool = false
var legacy: bool = false   # the full greybox HUD (F2), instead of UI's
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if main == null or main.host == null:
		return
	var host: SimHost = main.host
	var S: SimState = host.S
	var vw: float = size.x
	var vh: float = size.y
	if not legacy:
		_prompt(host, vw, vh)
		return
	_labels(S, host)
	_floats(host)
	var bw: float = clampf(vw * 0.32, 150.0, 380.0)
	for idx in range(S.fighters.size()):
		_panel(S.fighters[idx], idx == 1, bw, vw)
	var w = S.world
	_text("CIVILIANS LOST %d / %d" % [int(round(w.casualties)), int(w.pop0)], Vector2(vw * 0.5, 24), 12, Color(1, 1, 1, 0.92), 0)
	_text("STRUCTURES LOST %d   CRATERS %d" % [int(w.structuresLost), int(w.craters)], Vector2(vw * 0.5, 40), 11, Color(1, 1, 1, 0.7), 0)
	var ex = S.dirS.ex
	if ex != null and ex.combo > 1.0:
		_text("%d CHAIN" % int(ex.combo), Vector2(vw * 0.5, 70), 22, RenderLook.col("#ffd45a"), 0)
	var b = host.fxv.banner
	if b != null:
		var k: float = b.t / 0.12 if b.t < 0.12 else (maxf(0.0, (b.dur - b.t) / 0.3) if b.t > b.dur - 0.3 else 1.0)
		var fs: int = int(round(clampf(vw * 0.045, 22.0, 44.0)))
		var c: Color = RenderLook.col(b.col)
		_text(b.text, Vector2(vw * 0.5 + 2, vh * 0.28 + (1.0 - k) * 8.0 + 2), fs, Color(0, 0, 0, 0.6 * k), 0)
		_text(b.text, Vector2(vw * 0.5, vh * 0.28 + (1.0 - k) * 8.0), fs, Color(c, k), 0)
	_feed(host, vh)
	_strip(S, host, vw, vh)
	_prompt(host, vw, vh)


func _prompt(host: SimHost, vw: float, vh: float) -> void:
	if not main.started:
		_text("AI vs AI demo. Press any key to take control of P1.", Vector2(vw * 0.5, vh - 96.0 if not legacy else 104.0), 16, Color(1, 1, 1, 0.9), 0)
		_text("P1: WASD move, Space dash, F light, G heavy, R signature, Q charge, 1-4 stances.   N new match, T/Y toggle AI, P pause, F2 old HUD, F3 perf, F4 feed, F6 cracks (Shift: destruction, Ctrl: embers), F9 split", Vector2(vw * 0.5, vh - 78.0 if not legacy else 124.0), 11, Color(1, 1, 1, 0.7), 0)
		_text(_flash_keys(), Vector2(vw * 0.5, vh - 62.0 if not legacy else 140.0), 11, Color(1, 1, 1, 0.6), 0)
	_text("seed %d   tick %d%s" % [host.seed, host.ticks, "   PAUSED" if host.paused else ""], Vector2(vw - 10, vh - 30), 10, Color(1, 1, 1, 0.5), 1)
	if show_perf:
		_perf(vw)


## The head flashes' debug keys, in the data's order (main.gd FLASH_KEYS).
static func _flash_keys() -> String:
	var ids: Array = FlashSet.ids()
	var parts: PackedStringArray = []
	for i in range(mini(ids.size(), main_keys().size())):
		parts.append("%s %s" % [main_keys()[i], ids[i]])
	return "Head flashes, Alt+: " + "  ".join(parts) + "  (Shift: P2).  Alt+F family, F7 flashes on/off, F8 legacy shapes"


static func main_keys() -> Array:
	return ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "[", "]"]


func _panel(f, right: bool, bw: float, vw: float) -> void:
	var x: float = vw - bw - 14.0 if right else 14.0
	var y: float = 12.0
	var al: int = 1 if right else -1
	var ax: float = x + bw if right else x
	_text(f.name + ("  (AI)" if f.ai != null else ""), Vector2(ax, y + 12), 15, Color.WHITE, al)
	var st: String = RenderLook.STANCE_LONG[int(f.stance)]
	_text(f.title + "  ·  " + st + ("  ·  HIDDEN" if f.hidden else ""), Vector2(ax, y + 27), 11, Color(1, 1, 1, 0.75), al)
	var fr: float = f.hp / f.maxhp
	var hpc: Color = RenderLook.col("#5ed17a" if fr > 0.5 else ("#f1c232" if fr > 0.25 else "#e5484d"))
	_bar(x, y + 33, bw, 12, fr, hpc, right)
	_bar(x, y + 49, bw, 7, f.ki / 100.0, RenderLook.col("#4aa8ff"), right)
	_bar(x, y + 60, bw, 7, f.power / 100.0, RenderLook.col("#ffcf4a"), right)
	_text("TIER %d" % int(f.tier), Vector2(ax, y + 80), 10, Color(1, 1, 1, 0.9), al)
	var sc: Color = RenderLook.col(RenderLook.STANCE_COL[int(f.stance)])
	draw_rect(Rect2(x + bw - 64.0 if not right else x, y + 70.0, 64.0, 13.0), Color(sc, 0.85))
	_text(RenderLook.STANCE_SHORT[int(f.stance)], Vector2((x + bw - 32.0) if not right else x + 32.0, y + 81), 10, Color.BLACK, 0)
	if f.role == "villain":
		_bar(x, y + 84, bw, 7, f.menace / 100.0, RenderLook.col("#b05cff"), right)
		_text("MENACE", Vector2(ax, y + 103), 10, Color(1, 1, 1, 0.9), al)
	else:
		_bar(x, y + 84, bw, 7, f.anguish / 100.0, RenderLook.col("#3fd6c5"), right)
		_text("ANGUISH", Vector2(ax, y + 103), 10, Color(1, 1, 1, 0.9), al)


func _labels(S: SimState, host: SimHost) -> void:
	var cam: Camera3D = main.cam_rig
	for i in range(S.fighters.size()):
		var f = S.fighters[i]
		var fv: FighterView = main.fighter_views[i]
		var top: Vector3 = fv.global_position + Vector3(0, 84.0 + f.tier * 3.0 + 22.0, 0)
		if cam.is_position_behind(top):
			continue
		var p: Vector2 = cam.unproject_position(top)
		if f.hidden:
			_text("HIDDEN", p, 12, Color(190.0 / 255.0, 220.0 / 255.0, 1.0, 0.95), 0)
		else:
			_text("%s %s T%d" % [f.name, RenderLook.STANCE_SHORT[int(f.stance)], int(f.tier)], p, 11, Color(1, 1, 1, 0.9), 0)


func _floats(host: SimHost) -> void:
	var cam: Camera3D = main.cam_rig
	var cx: float = main.view_cam_x
	for fl in host.fxv.floats:
		var p: Vector2 = cam.unproject_position(Vector3(SimWrap.sdx(cx, fl.x), fl.y, 0.0))
		var fs: int = int(round(14.0 + minf(10.0, fl.txt.length() * 2.0)))
		var c: Color = RenderLook.col(fl.col)
		_text(fl.txt, p, fs, Color(c, 1.0 - fl.t / 0.9), 0)


func _feed(host: SimHost, vh: float) -> void:
	var n: int = mini(FEED_LINES, host.feed.size())
	var y: float = vh - 44.0 - n * 14.0
	for i in range(host.feed.size() - n, host.feed.size()):
		var l = host.feed[i]
		var age: float = host.S.T - l.t
		var a: float = clampf(1.0 - age / 12.0, 0.35, 0.95)
		_text("%6.1f  %s" % [l.t, l.tag], Vector2(14, y), 11, Color(1.0, 0.85, 0.45, a), -1)
		_text(l.sub, Vector2(66 + font.get_string_size(l.tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 16, y), 11, Color(1, 1, 1, a * 0.85), -1)
		y += 14.0


func _strip(S: SimState, host: SimHost, vw: float, vh: float) -> void:
	var sy: float = vh - 20.0
	var sw: float = vw - 28.0
	var sx0: float = 14.0
	var W: float = SimConst.W
	for s in WorldBiomes.SEG:
		draw_rect(Rect2(sx0 + s[0] / W * sw, sy, (s[1] - s[0]) / W * sw + 1.0, 10), RenderLook.col(RenderLook.BIOME[s[2]]))
	draw_rect(Rect2(sx0, sy + 10, sw, 2), Color(0, 0, 0, 0.35))
	var half: float = main.cam_rig.half_width(vw)
	var cwid: float = minf(2.0 * half / W * sw, sw)
	var cx0: float = sx0 + SimWrap.wrap(main.view_cam_x - half) / W * sw
	draw_rect(Rect2(cx0, sy - 2, cwid, 14), Color(1, 1, 1, 0.85), false, 1.5)
	if cx0 + cwid > sx0 + sw:
		draw_rect(Rect2(cx0 - sw, sy - 2, cwid, 14), Color(1, 1, 1, 0.85), false, 1.5)
	for b in S.buildings:
		if not b.alive:
			draw_rect(Rect2(sx0 + SimWrap.wrap(b.x) / W * sw, sy + 2, 1, 6), Color(0, 0, 0, 0.6))
	for f in S.fighters:
		var px: float = sx0 + SimWrap.wrap(f.x) / W * sw
		draw_circle(Vector2(px, sy + 5), 5.0, RenderLook.col(f.aura))
		draw_arc(Vector2(px, sy + 5), 5.0, 0.0, TAU, 16, Color.BLACK, 1.0)
		if f.hidden:
			_text("?", Vector2(px, sy - 4), 10, Color.WHITE, 0)


func _perf(vw: float) -> void:
	var p: Dictionary = main.perf_summary()
	var lines: Array = [
		"FPS %d   frame %.2f ms (p95 %.2f)" % [Engine.get_frames_per_second(), p.frame_ms, p.frame_p95],
		"sim tick %.3f ms   fx+cam %.3f ms   view update %.3f ms" % [p.tick_ms, p.fx_ms, p.view_ms],
		"draw calls %d   objects %d   particles %d" % [p.draws, p.objects, p.particles],
		"renderer %s   %s" % [p.renderer, p.adapter],
	]
	var y: float = 132.0
	for l in lines:
		_text(l, Vector2(14, y), 11, RenderLook.col("#9fe8ff"), -1)
		y += 14.0


func _bar(x: float, y: float, w: float, h: float, frac: float, c: Color, right: bool) -> void:
	draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.55))
	var fw: float = w * clampf(frac, 0.0, 1.0)
	draw_rect(Rect2(x + w - fw if right else x, y, fw, h), c)
	draw_rect(Rect2(x + 0.5, y + 0.5, w - 1.0, h - 1.0), Color(1, 1, 1, 0.35), false, 1.0)


## align: -1 left, 0 centre, 1 right of pos.x; pos.y is the baseline.
func _text(s: String, pos: Vector2, fs: int, c: Color, align: int) -> void:
	var w: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x: float = pos.x
	if align == 0:
		x -= w * 0.5
	elif align == 1:
		x -= w
	draw_string(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
