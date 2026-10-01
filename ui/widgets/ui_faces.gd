class_name UiFaces
extends RefCounted
## The face cut-in (docs/ui/hud-spec.md section 29): when a fighter speaks a line (a quip, a one-liner, a banter reply, a taunt, a shout), a small
## portrait of the speaker slides in at that fighter's side of the screen, holds for the line and leaves. It is tied to the bark: the hub decides
## at the moment a bark becomes visible whether it gets a face (the kind's level and the rate cap, `ui/data/faces.json`), and the face lives as
## long as the bark. A fighter speaks one line at a time and each fighter has a side, so two faces on one side never happen; two speakers at once
## give one face a side.
##
## Where it goes: DOCKED, a square in the speaker's column just above the bark lane (UiLayout.face[slot], placed so it never touches the
## nameplates, the cards, the prompt row, the legend's three rows, the toll chip, the pause button, the touch buttons or the other HUD parts);
## or EMBEDDED, a square at the outer end of the bark's own panel (portrait, touch landscape where one lane stacks the lines, and any screen too
## small for a docked one). The portrait is a placeholder drawn from the fighter's aura colour for now; `faces.json` has a slot per fighter
## and expression (neutral, smirk, strain, hurt) where Art's textures go.

static func data() -> Dictionary:
	return UiData.faces()


## "always" (a jewel, a shout, a set piece: not counted by the rate cap), "cap" (an ordinary line: at most `per_minute` a minute) or "never"
## (a thought, an ambient line, a crowd or narrator line, a line with no fighter speaking).
static func level(b: UiEventHub.Bark) -> String:
	var d: Dictionary = data()
	if not b.fighter or b.text == "" or b.style == "thought" or b.kind == "thought":
		return "never"
	if b.setpiece or b.priority >= int(d.get("always_priority", 3)) or b.style == "shout":
		return "always"
	if b.priority < int(d.get("min_priority", 2)):
		return "never"
	return str((d.get("kinds", {}) as Dictionary).get(b.kind, "cap"))


## The expression for a line: from its first cue's gesture (laugh and scoff are a smirk, wince and gasp hurt, roar and growl strain), else hurt
## if the speaker is on the brink, else neutral.
static func expression(b: UiEventHub.Bark, m: UiFighterModel) -> String:
	var d: Dictionary = data()
	var map: Dictionary = d.get("gesture_expression", {})
	if not b.cues.is_empty():
		var g: String = str((b.cues[0] as Dictionary).get("gesture", ""))
		var fam: String = g.get_slice(".", 0)
		if map.has(g):
			return str(map[g])
		if map.has(fam):
			return str(map[fam])
	if m != null and m.brink:
		return "hurt"
	return str(d.get("default_expression", "neutral"))


## The texture for a fighter's expression, or null (the placeholder is drawn). Art fills the paths in faces.json.
static var _tex: Dictionary = {}


static func texture_for(fighter_id: String, expr: String) -> Texture2D:
	var fighters: Dictionary = data().get("fighters", {})
	var f: Dictionary = fighters.get(fighter_id, fighters.get("default", {}))
	var path: String = str((f.get(expr, {}) as Dictionary).get("art", ""))
	if path == "":
		return null
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_tex[path] = t
	return t


## A bark's face is embedded in its panel (not docked) on a portrait screen, in a one-lane touch landscape, and where no docked square fit.
static func embedded(lay: UiLayout, slot: int) -> bool:
	return lay.portrait or lay.bark_single or slot >= lay.face.size() or (lay.face[slot] as Rect2).size.y <= 0.0


## The slide of a face for a bark: {off: 0 (in place) to 1 (fully out), a: opacity}. It slides in over `slide_in`, holds, and slides out over
## `slide_out` at the end of the line; in reduced motion it fades instead of sliding.
static func motion(b: UiEventHub.Bark, reduced: bool) -> Dictionary:
	var d: Dictionary = data().get("timing", {})
	var tin: float = maxf(float(d.get("slide_in", 0.18)), 0.01)
	var tout: float = maxf(float(d.get("slide_out", 0.22)), 0.01)
	var total: float = b.reveal_time + b.dur
	var kin: float = clampf(b.age / tin, 0.0, 1.0)
	var kout: float = clampf((total - b.age) / tout, 0.0, 1.0)
	var k: float = minf(kin, kout)
	var eased: float = 1.0 - pow(1.0 - k, 3.0)
	if reduced:
		return {"off": 0.0, "a": clampf(k * (1.0 / 0.5), 0.0, 1.0)}
	return {"off": 1.0 - eased, "a": clampf(k * 3.0, 0.0, 1.0)}


## Docked faces: draw each visible bark's face at its slot's rect, sliding from the screen's edge.
static func draw_docked(ci: CanvasItem, hub: UiEventHub, lay: UiLayout, s: float, o: Dictionary) -> void:
	var reduced: bool = bool(o.get("reduced_motion", false))
	var swap: float = float(o.get("swap_fade", 1.0))
	for b in hub.barks:
		if not b.face or embedded(lay, b.slot):
			continue
		var m: UiFighterModel = hub.model(b.slot)
		var r: Rect2 = lay.face[b.slot]
		var left: bool = r.get_center().x < lay.vp.x * 0.5
		var mo: Dictionary = motion(b, reduced)
		var shift: float = (r.end.x + 4.0) if left else (lay.vp.x - r.position.x + 4.0)
		var rr := Rect2(r.position + Vector2((-shift if left else shift) * float(mo["off"]), 0.0), r.size)
		draw_portrait(ci, rr, m, b.face_expr, float(mo["a"]) * swap, s)


## One face panel in `rect`: the texture if Art has made one for this fighter and expression, else the placeholder.
static func draw_portrait(ci: CanvasItem, rect: Rect2, m: UiFighterModel, expr: String, alpha: float, s: float) -> void:
	if alpha <= 0.01:
		return
	var aura: Color = m.aura if m != null else Color.WHITE
	var scrim := Color(UiLook.col(UiLook.SCRIM))
	var ink := Color(UiLook.col(UiLook.INK))
	var edge_w: float = maxf(2.0, rect.size.y * 0.025)
	UiIcons.rrect(ci, rect, rect.size.y * 0.08, Color(scrim, 0.92 * alpha))
	var tex: Texture2D = texture_for(m.id if m != null else "default", expr)
	var inner: Rect2 = rect.grow(-edge_w * 1.2)
	if tex != null:
		var ts: Vector2 = tex.get_size()
		var k: float = maxf(inner.size.x / ts.x, inner.size.y / ts.y)
		var src := Rect2((ts - inner.size / k) * 0.5, inner.size / k)
		ci.draw_texture_rect_region(tex, inner, src, Color(1, 1, 1, alpha))
	else:
		_placeholder(ci, inner, aura, expr, alpha, ink)
	UiIcons.rrect(ci, rect, rect.size.y * 0.08, Color(0, 0, 0, 0), Color(aura, 0.9 * alpha), edge_w)


## A placeholder from the fighter's colours: the aura as the ground with speed lines, a head and hair in tones of it, and a face that is only
## strokes: the eyes and mouth change with the expression, so a line reads even before Art draws one.
static func _placeholder(ci: CanvasItem, r: Rect2, aura: Color, expr: String, alpha: float, ink: Color) -> void:
	var h: float = r.size.y
	var c: Vector2 = r.get_center() + Vector2(0.0, h * 0.04)
	ci.draw_rect(r, Color(aura.darkened(0.72), alpha))
	# Speed lines out of the head's corner: the manga cut-in ground.
	var origin: Vector2 = c + Vector2(0.0, -h * 0.05)
	for k in range(12):
		var a: float = float(k) * TAU / 12.0 + 0.13
		var d: Vector2 = Vector2.from_angle(a)
		var p0: Vector2 = origin + d * h * 0.42
		var p1: Vector2 = origin + d * h * 0.78
		var q0: Vector2 = Vector2(clampf(p0.x, r.position.x, r.end.x), clampf(p0.y, r.position.y, r.end.y))
		var q1: Vector2 = Vector2(clampf(p1.x, r.position.x, r.end.x), clampf(p1.y, r.position.y, r.end.y))
		ci.draw_line(q0, q1, Color(aura, 0.28 * alpha), maxf(2.0, h * 0.025), true)
	# Shoulders, head, hair.
	var skin: Color = aura.lightened(0.55).lerp(Color(0.92, 0.82, 0.72), 0.5)
	var hair: Color = aura.darkened(0.35)
	var sh := PackedVector2Array([Vector2(r.position.x + h * 0.05, r.end.y), Vector2(c.x - h * 0.3, c.y + h * 0.3), Vector2(c.x + h * 0.3, c.y + h * 0.3), Vector2(r.end.x - h * 0.05, r.end.y)])
	UiIcons.fill_poly(ci, sh, Color(aura.darkened(0.15), alpha))
	ci.draw_circle(c, h * 0.3, Color(skin, alpha))
	ci.draw_arc(c, h * 0.3, PI * 1.02, PI * 1.98, 18, Color(hair, alpha), h * 0.1, true)
	var w: float = maxf(2.0, h * 0.028)
	var dk := Color(0.06, 0.07, 0.1, alpha)
	var ex: float = h * 0.12
	var ey: float = c.y - h * 0.04
	var ew: float = h * 0.075
	match expr:
		"smirk":
			ci.draw_line(Vector2(c.x - ex - ew, ey), Vector2(c.x - ex + ew, ey), dk, w, true)
			ci.draw_arc(Vector2(c.x + ex, ey + ew * 0.1), ew, PI * 1.05, PI * 1.95, 8, dk, w, true)
			ci.draw_line(Vector2(c.x + ex - ew, ey - h * 0.075), Vector2(c.x + ex + ew, ey - h * 0.1), dk, w, true)
			ci.draw_polyline(PackedVector2Array([Vector2(c.x - h * 0.09, c.y + h * 0.14), Vector2(c.x + h * 0.02, c.y + h * 0.15), Vector2(c.x + h * 0.11, c.y + h * 0.11)]), dk, w, true)
		"strain":
			ci.draw_line(Vector2(c.x - ex - ew, ey - h * 0.07), Vector2(c.x - ex + ew, ey - h * 0.02), dk, w * 1.2, true)
			ci.draw_line(Vector2(c.x + ex + ew, ey - h * 0.07), Vector2(c.x + ex - ew, ey - h * 0.02), dk, w * 1.2, true)
			ci.draw_line(Vector2(c.x - ex - ew * 0.7, ey + h * 0.01), Vector2(c.x - ex + ew * 0.7, ey + h * 0.01), dk, w, true)
			ci.draw_line(Vector2(c.x + ex - ew * 0.7, ey + h * 0.01), Vector2(c.x + ex + ew * 0.7, ey + h * 0.01), dk, w, true)
			var mr := Rect2(c.x - h * 0.1, c.y + h * 0.11, h * 0.2, h * 0.06)
			ci.draw_rect(mr, Color(0.96, 0.95, 0.92, alpha))
			ci.draw_rect(mr, dk, false, w)
			ci.draw_line(Vector2(c.x, mr.position.y), Vector2(c.x, mr.end.y), dk, maxf(1.5, w * 0.6), true)
		"hurt":
			ci.draw_polyline(PackedVector2Array([Vector2(c.x - ex - ew, ey - ew * 0.9), Vector2(c.x - ex + ew * 0.4, ey), Vector2(c.x - ex - ew, ey + ew * 0.9)]), dk, w, true)
			ci.draw_polyline(PackedVector2Array([Vector2(c.x + ex + ew, ey - ew * 0.9), Vector2(c.x + ex - ew * 0.4, ey), Vector2(c.x + ex + ew, ey + ew * 0.9)]), dk, w, true)
			ci.draw_polyline(PackedVector2Array([Vector2(c.x - h * 0.1, c.y + h * 0.15), Vector2(c.x - h * 0.05, c.y + h * 0.11), Vector2(c.x, c.y + h * 0.15), Vector2(c.x + h * 0.05, c.y + h * 0.11), Vector2(c.x + h * 0.1, c.y + h * 0.15)]), dk, w, true)
			ci.draw_circle(Vector2(c.x + h * 0.27, c.y - h * 0.18), h * 0.03, Color(0.7, 0.9, 1.0, alpha))
		_:
			ci.draw_line(Vector2(c.x - ex - ew, ey), Vector2(c.x - ex + ew, ey), dk, w, true)
			ci.draw_line(Vector2(c.x + ex - ew, ey), Vector2(c.x + ex + ew, ey), dk, w, true)
			ci.draw_line(Vector2(c.x - ex - ew, ey - h * 0.07), Vector2(c.x - ex + ew, ey - h * 0.07), dk, w * 0.8, true)
			ci.draw_line(Vector2(c.x + ex - ew, ey - h * 0.07), Vector2(c.x + ex + ew, ey - h * 0.07), dk, w * 0.8, true)
			ci.draw_line(Vector2(c.x - h * 0.06, c.y + h * 0.14), Vector2(c.x + h * 0.06, c.y + h * 0.14), dk, w, true)
