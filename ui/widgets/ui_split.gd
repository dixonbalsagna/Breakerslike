class_name UiSplit
## HUD support for Camera's dynamic split screen (docs/camera/split-screen.md, docs/ui/hud-spec.md section 10):
##   - the divider's styling (thin, neutral, stopping under the toll chip and above the ring map and the strip),
##   - the planet ring map (both fighters on the wrapped planet, each pane's viewed arc, the held shortest arc),
##   - an edge pointer chip in each pane toward the rival, with the distance in fighter heights.
## All of it is fed by one record from Camera each frame (UiHud.split_fn), and all of it draws only while it has something
## to say: the divider only while the panes are open, the pointers only in a split (or when the rival is off screen and
## the camera does not split), the ring map with the planet strip.
##
## The split record (a Dictionary; every key optional):
##   sep      0..1   how far the panes are open (0 = one camera, no divider)
##   c, n            the divider's centre (px) and its unit normal, pointing from pane A's fighter toward pane B's
##   gap      px     the compositor's divider gap; fade 0..1 the divider's opacity; slam 0..1 the slam flash
##   sigma    +1/-1  +1 when fighter B is to A's right on screen (so A is the left pane): -1 swaps the columns
##   dist_bh         the held separation in fighter heights (else computed from the ring angles)
##   pointer  "split" (default) | "always" (a single camera: point when the rival is off screen) | "off"
##   ring     {angle_A, angle_B, sigma, arc_A, arc_B, swing, sep, W}   angles are x / W * TAU; arcs are the viewed width in
##            radians of planet angle; W (the planet's circumference in world units) defaults to SimConst.W
## Fighter A is slot 0 and fighter B is slot 1.

const FIGHTER_HEIGHT := 75.0   # world units (render/core/fighter_view.gd HEIGHT), for the distance in fighter heights


# --- The divider ----------------------------------------------------------------------------------------------------

static func divider_active(sp: Dictionary) -> bool:
	return sp.has("c") and sp.has("n") and float(sp.get("sep", 0.0)) > 0.01 and float(sp.get("fade", 1.0)) > 0.01


## The divider as a rotated bar: {mid, len, angle, w, a, slam}, or {} when the line misses the band. The HUD draws it with
## two ColorRect nodes (a dark edge under a light line) whose transform it sets, so a moving divider costs no redraw and no
## draw command at all. Thin, neutral, never a fighter's accent; it stops under the toll chip and above the ring map and
## the strip, and where it swings through the horizontal it spans the width inside that band.
static func divider_geometry(lay: UiLayout, sp: Dictionary, s: float) -> Dictionary:
	var seg: Array = lay.divider_segment(sp["c"], sp["n"])
	if seg.is_empty():
		return {}
	var p0: Vector2 = seg[0]
	var p1: Vector2 = seg[1]
	var slam: float = clampf(float(sp.get("slam", 0.0)), 0.0, 1.0)
	return {"mid": (p0 + p1) * 0.5, "len": p0.distance_to(p1), "angle": (p1 - p0).angle(), "w": maxf(2.0, 2.0 * s) * (1.0 + 1.5 * slam),
		"a": clampf(float(sp.get("fade", 1.0)), 0.0, 1.0), "slam": slam}


## Changes only when the bar moves half a pixel or turns a fifth of a degree: the HUD skips the node updates otherwise.
static func divider_key(geo: Dictionary) -> Array:
	if geo.is_empty():
		return []
	var mid: Vector2 = geo["mid"]
	return [int(mid.x * 2.0), int(mid.y * 2.0), int(float(geo["len"]) * 2.0), int(float(geo["angle"]) * 300.0), int(float(geo["a"]) * 50.0), int(float(geo["slam"]) * 20.0)]


# --- The ring map ---------------------------------------------------------------------------------------------------

static func ring_active(sp: Dictionary) -> bool:
	return sp.get("ring") is Dictionary and not (sp["ring"] as Dictionary).is_empty()


## The moving marks redraw when a fighter or an arc has moved a whole degree (the ring is about 90 px across, so a degree is
## under a pixel).
static func ring_sig(sp: Dictionary) -> Array:
	var r: Dictionary = sp["ring"]
	var k: float = 57.3   # degrees
	return [int(float(r.get("angle_A", 0.0)) * k), int(float(r.get("angle_B", 0.0)) * k), int(r.get("sigma", 1)), int(float(r.get("arc_A", 0.0)) * k / 2.0), int(float(r.get("arc_B", 0.0)) * k / 2.0), int(float(r.get("sep", 0.0)) * 10.0)]


## The ring's static base, drawn once: the dark disc and the track. Nothing marks the seam (pillar 1).
static func draw_ring_base(ci: CanvasItem, lay: UiLayout, s: float, o: Dictionary) -> void:
	var rect: Rect2 = lay.ring
	if rect.size.y <= 0.0:
		return
	var a: float = float(o.get("plate_alpha", 1.0))
	var c: Vector2 = rect.get_center()
	var r: float = rect.size.x * 0.5 - 6.0 * s
	ci.draw_circle(c, r + 5.0 * s, Color(UiLook.col(UiLook.SCRIM), 0.4 * a))
	ci.draw_arc(c, r, 0.0, TAU, 48, Color(UiLook.col(UiLook.INK), 0.45 * a), maxf(2.0, 2.0 * s), true)


## The shortest signed angular separation from A to B, in radians (-PI to PI).
static func shortest(angle_a: float, angle_b: float) -> float:
	return fposmod(angle_b - angle_a + PI, TAU) - PI


static func draw_ring_marks(ci: CanvasItem, lay: UiLayout, hub: UiEventHub, sp: Dictionary, s: float, o: Dictionary) -> void:
	var rect: Rect2 = lay.ring
	if rect.size.y <= 0.0:
		return
	var a: float = float(o.get("plate_alpha", 1.0))
	var rg: Dictionary = sp["ring"]
	var c: Vector2 = rect.get_center()
	var r: float = rect.size.x * 0.5 - 6.0 * s
	var aa: float = float(rg.get("angle_A", 0.0))
	var ab: float = float(rg.get("angle_B", 0.0))
	var sigma: int = 1 if int(rg.get("sigma", 1)) >= 0 else -1
	var sep: float = float(rg.get("sep", 0.0))
	var top: float = -PI * 0.5   # planet angle 0 is drawn at the top; the seam is not marked (pillar 1)
	var bw: float = maxf(4.0, 4.5 * s)
	# The viewed arcs: one per open pane (centred on its fighter), or the single camera's arc at the midpoint.
	var ink_dim := Color(UiLook.col(UiLook.INK_DIM), 0.5 * a)
	var arc_a: float = float(rg.get("arc_A", 0.0))
	var arc_b: float = float(rg.get("arc_B", 0.0))
	if sep > 0.05:
		if arc_a > 0.0:
			ci.draw_arc(c, r + bw, aa + top - arc_a * 0.5, aa + top + arc_a * 0.5, 16, ink_dim, bw, true)
		if arc_b > 0.0:
			ci.draw_arc(c, r + bw, ab + top - arc_b * 0.5, ab + top + arc_b * 0.5, 16, ink_dim, bw, true)
	elif arc_a > 0.0:
		var mid: float = aa + shortest(aa, ab) * 0.5
		ci.draw_arc(c, r + bw, mid + top - arc_a * 0.5, mid + top + arc_a * 0.5, 16, ink_dim, bw, true)
	# The held shortest arc from A to B, in the direction sigma says B lies.
	var span: float = fposmod(float(sigma) * (ab - aa), TAU) * float(sigma)
	var a0: float = aa + top
	ci.draw_arc(c, r, a0, a0 + span, maxi(4, int(absf(span) * 8.0)), Color(UiLook.col(UiLook.INK), 0.85 * a), maxf(2.5, 2.5 * s), true)
	# Both fighters: a circle for A, a diamond for B, as on the strip.
	var msz: float = maxf(6.0 * s, 5.0)
	for i in range(2):
		var m: UiFighterModel = hub.model(i)
		var ang: float = (aa if i == 0 else ab) + top
		var p: Vector2 = c + Vector2(cos(ang), sin(ang)) * r
		var col: Color = m.aura if m != null else Color.WHITE
		if i == 0:
			ci.draw_circle(p, msz, Color(col, a))
			ci.draw_arc(p, msz, 0.0, TAU, 14, Color(0, 0, 0, a), 1.4, true)
		else:
			var d := PackedVector2Array([p + Vector2(0, -msz * 1.25), p + Vector2(msz * 1.25, 0), p + Vector2(0, msz * 1.25), p + Vector2(-msz * 1.25, 0)])
			UiIcons.fill_poly(ci, d, Color(col, a))
			var closed: PackedVector2Array = d.duplicate()
			closed.append(d[0])
			ci.draw_polyline(closed, Color(0, 0, 0, a), 1.4, true)


# --- Edge pointers ---------------------------------------------------------------------------------------------------

## The distance between the fighters in fighter heights: the record's `dist_bh`, else from the ring's angles.
static func distance_bh(sp: Dictionary) -> float:
	if sp.has("dist_bh"):
		return float(sp["dist_bh"])
	var rg = sp.get("ring")
	if rg is Dictionary and not (rg as Dictionary).is_empty():
		var w: float = float(rg.get("W", SimConst.W))
		return absf(shortest(float(rg.get("angle_A", 0.0)), float(rg.get("angle_B", 0.0)))) / TAU * w / FIGHTER_HEIGHT
	return 0.0


## The chips to draw: [{slot, pos, dir, text}]. `anchors` is [{pos, h, visible}] per slot from the host's anchor_fn.
static func pointers(lay: UiLayout, sp: Dictionary, anchors: Array, s: float) -> Array:
	var mode: String = str(sp.get("pointer", "split"))
	var out: Array = []
	if mode == "off" or anchors.size() < 2:
		return out
	var dist: float = distance_bh(sp)
	var txt: String = _dist_text(dist)
	var half: float = pointer_size(s).x * 0.5
	var margin: float = 24.0 * s   # the reserve band UI keeps around the clear zone
	var split_open: bool = divider_active(sp)
	for i in range(2):
		var an: Dictionary = anchors[i]
		if an.is_empty():
			continue
		var p: Vector2 = an["pos"]
		if split_open:
			var c: Vector2 = sp["c"]
			var nrm: Vector2 = sp["n"]
			var dirn: Vector2 = nrm if i == 0 else -nrm   # from this pane's fighter toward the rival
			var to_div: float = (c - p).dot(dirn)
			var pos: Vector2 = _dodge(_clamp_to(p + dirn * maxf(0.0, to_div - half - margin), lay), Vector2(-dirn.y, dirn.x), lay, anchors)
			if pos.x < -1e8:
				continue   # no clear place along the edge: the chip hides rather than cover a fighter
			out.append({"slot": i, "pos": pos, "dir": dirn, "text": txt})
		elif mode == "always":
			# One camera: point only when the rival is off screen, at the edge toward it.
			var rival: Dictionary = anchors[1 - i]
			var rp: Vector2 = rival.get("pos", p)
			var off: bool = rival.is_empty() or not bool(rival.get("visible", true)) or not Rect2(Vector2.ZERO, lay.vp).grow(-margin).has_point(rp)
			if off:
				var sig: float = float(sp.get("sigma", 1))
				var dx: float = sig if i == 0 else -sig
				var ex: float = lay.safe.end.x - half if dx > 0.0 else lay.safe.position.x + half
				var pos1: Vector2 = _dodge(_clamp_to(Vector2(ex, p.y), lay), Vector2(0.0, 1.0), lay, anchors)
				if pos1.x > -1e8:
					out.append({"slot": i, "pos": pos1, "dir": Vector2(dx, 0.0), "text": txt})
	return out


## Fighters may sit far from the centre in the one-view shot (up to 44% of the width), so an edge chip can land on one. Keep a chip
## about one fighter height (the anchor's `h`) clear of both fighters' anchors: nudge it along the edge (`along`, a unit vector
## parallel to the edge) to the nearest clear spot inside the safe area, or return an off-screen sentinel (x < -1e8) to hide it.
static func _dodge(pos: Vector2, along: Vector2, lay: UiLayout, anchors: Array) -> Vector2:
	var psz: Vector2 = pointer_size(lay.s)
	if _chip_clear(pos, psz, anchors):
		return pos
	var step: float = psz.y * 0.25
	var reach: float = psz.y
	for an in anchors:
		if not an.is_empty():
			reach = maxf(reach, float(an.get("h", 0.0)) * 2.5 + psz.y)
	var k := 1
	while float(k) * step <= reach:
		for sgn in [1.0, -1.0]:
			var cand: Vector2 = _clamp_to(pos + along * (sgn * float(k) * step), lay)
			if _chip_clear(cand, psz, anchors):
				return cand
		k += 1
	return Vector2(-1e9, -1e9)


## True when the chip's rectangle at `pos` is at least one fighter height from every visible anchor.
static func _chip_clear(pos: Vector2, psz: Vector2, anchors: Array) -> bool:
	var r := Rect2(pos - psz * 0.5, psz)
	for an in anchors:
		if an.is_empty() or not bool(an.get("visible", true)):
			continue
		var q: Vector2 = an["pos"]
		var d := Vector2(maxf(maxf(r.position.x - q.x, 0.0), q.x - r.end.x), maxf(maxf(r.position.y - q.y, 0.0), q.y - r.end.y))
		if d.length() < float(an.get("h", 0.0)):
			return false
	return true


static func pointer_size(s: float) -> Vector2:
	return Vector2(maxf(112.0 * s, 96.0), maxf(34.0 * s, 26.0))


static func _clamp_to(p: Vector2, lay: UiLayout) -> Vector2:
	var h: Vector2 = pointer_size(lay.s) * 0.5
	return Vector2(clampf(p.x, lay.safe.position.x + h.x, lay.safe.end.x - h.x), clampf(p.y, lay.safe.position.y + h.y, lay.safe.end.y - h.y))


## The distance as text, ROUNDED so the chip redraws a few times a second and not every frame while the fighters move: to
## the nearest 5 under 100, the nearest 25 under 1,000, then tenths of a thousand ("1.2k").
static func _dist_text(bh: float) -> String:
	if bh >= 1000.0:
		return "%.1fk" % (bh / 1000.0)
	if bh >= 100.0:
		return str(int(round(bh / 25.0)) * 25)
	return str(int(round(bh / 5.0)) * 5)


## What a chip's picture depends on (its position does not: the chip is a node the HUD moves, so following a fighter costs no
## redraw). The arrow's direction changes slowly and is rounded to about 5 degrees; the distance text is rounded (see _dist_text).
static func chip_sig(slot: int, dir: Vector2, text: String, alpha: float) -> Array:
	return [slot, int(dir.x * 12.0), int(dir.y * 12.0), text, int(alpha * 20.0)]


## One chip, drawn at the centre of `ci` (a node of pointer_size): the arrow along `dir`, the rival's strip shape (circle for A,
## diamond for B), and the distance with a small height mark ("in fighter heights"). Neutral colours; the marker takes the
## rival's accent, as on the strip. About nine draw commands, drawn only when the arrow or the number changes.
static func draw_chip(ci: Control, hub: UiEventHub, slot: int, dir: Vector2, text: String, s: float, o: Dictionary) -> void:
	var a: float = float(o.get("plate_alpha", 1.0))
	var sz: Vector2 = ci.size
	var p: Vector2 = sz * 0.5
	var fs: int = UiText.px(20.0, s)
	var rival: UiFighterModel = hub.model(1 - slot)
	UiText.no_outline = true
	UiIcons.rrect(ci, Rect2(Vector2.ZERO, sz), sz.y * 0.4, Color(UiLook.col(UiLook.SCRIM), 0.6 * a), Color(UiLook.col(UiLook.EDGE), 0.35 * a), 1.2)
	# The arrow, along dir, at the chip's rival-facing end.
	var ax: Vector2 = p + dir * (sz.x * 0.5 - sz.y * 0.55)
	var perp := Vector2(-dir.y, dir.x)
	var hl: float = sz.y * 0.32
	var ink := Color(UiLook.col(UiLook.INK), 0.95 * a)
	ci.draw_line(ax - dir * hl * 1.6, ax, ink, maxf(2.0, sz.y * 0.09), true)
	UiIcons.fill_poly(ci, PackedVector2Array([ax + dir * hl * 0.9, ax - dir * hl * 0.3 + perp * hl * 0.8, ax - dir * hl * 0.3 - perp * hl * 0.8]), ink)
	# The rival's marker on the far end.
	var mc: Vector2 = p - dir * (sz.x * 0.5 - sz.y * 0.55)
	var col: Color = rival.aura if rival != null else Color.WHITE
	var msz: float = sz.y * 0.2
	if (1 - slot) == 0:
		ci.draw_circle(mc, msz, Color(col, a))
		ci.draw_arc(mc, msz, 0.0, TAU, 12, Color(0, 0, 0, a), 1.2, true)
	else:
		var d := PackedVector2Array([mc + Vector2(0, -msz * 1.25), mc + Vector2(msz * 1.25, 0), mc + Vector2(0, msz * 1.25), mc + Vector2(-msz * 1.25, 0)])
		UiIcons.fill_poly(ci, d, Color(col, a))
		var cl: PackedVector2Array = d.duplicate()
		cl.append(d[0])
		ci.draw_polyline(cl, Color(0, 0, 0, a), 1.2, true)
	# The distance in the middle, then a small height mark after it (the unit is a fighter's height): one multi-line.
	var tw: float = UiText.width(text, fs)
	var tx: float = p.x - tw * 0.5 - sz.y * 0.1
	UiText.draw(ci, text, Vector2(tx, p.y + float(fs) * 0.35), fs, Color(UiLook.col(UiLook.INK), a), -1)
	var hx: float = tx + tw + sz.y * 0.28
	var hh: float = sz.y * 0.28
	ci.draw_multiline(PackedVector2Array([Vector2(hx, p.y - hh), Vector2(hx, p.y + hh), Vector2(hx - 3.0 * s, p.y - hh), Vector2(hx + 3.0 * s, p.y - hh), Vector2(hx - 3.0 * s, p.y + hh), Vector2(hx + 3.0 * s, p.y + hh)]), Color(UiLook.col(UiLook.INK_DIM), a), 1.6)
	UiText.no_outline = false
