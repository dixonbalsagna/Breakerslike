class_name UiCrown
## The aura crown: the fighter's damage drawn as arcs around the body (spec-wounds.md section 3, Orb's pick).
##   head: top arc    arms: a pair of side arcs    legs: bottom arc    core: an inner ring    mantle (Empress): a hem arc
## Each arc reads by SHAPE first and colour second, and moves only where motion adds meaning:
##   fresh     solid arc, full thickness
##   bruised   solid, thinner, with a tick at each end
##   battered  dashed, thinner, flickers (a static dashed arc under reduced motion)
##   broken    a wide gap: two short stubs and a spark tick at the break
## The whole crown gutters and gains a dashed outer ring on the brink. A dark under-stroke keeps every arc readable
## over sky, ground and explosions. The crown is presentation only: it reads a UiFighterModel and draws nothing random.

const ARMS_SPAN := 0.87    # radians per side arc (about 50 degrees)
const HEAD_SPAN := 1.47    # about 84 degrees
const LEGS_SPAN := 1.47
const CORE_SPAN := 5.2     # the core ring is nearly full
const MANTLE_SPAN := 1.9

## Crown radius for a fighter `h` pixels tall on screen, at UI scale s. Floored so it stays readable at the widest zoom.
static func radius(h: float, s: float) -> float:
	return clampf(h * UiLook.CROWN_R_PER_HEIGHT, UiLook.CROWN_MIN_R * s, UiLook.CROWN_MAX_R * s)


static var _still := false   # reduced motion: no flicker, no shimmer, no shrinking rings (set by draw())


static func draw(ci: CanvasItem, m: UiFighterModel, c: Vector2, R: float, t: float, s: float, o: Dictionary) -> void:
	var reduced: bool = bool(o.get("reduced_motion", false))
	_still = reduced
	var tscale: float = float(o.get("thickness", 1.0))
	var th: float = maxf(R * UiLook.CROWN_THICK, 3.0) * tscale
	var alpha: float = 0.35 if m.hidden else 1.0
	# The whole crown gutters on the brink.
	if m.brink:
		var g: float = 0.5 + 0.5 * sin(t * UiLook.HZ_BRINK * TAU)
		alpha *= 1.0 if reduced else (0.42 + 0.58 * g)
		var ring_col: Color = UiLook.alpha(UiLook.INK, 0.65 * alpha)
		var n := 28
		for i in range(n):
			var a0: float = TAU * float(i) / float(n)
			ci.draw_arc(c, R * 1.18, a0, a0 + TAU / float(n) * 0.5, 4, ring_col, maxf(1.5, th * 0.35), true)
	var spread: bool = m.profile.get("crown", "plain") == "spread"
	var thin: float = 1.0
	if spread:
		var tot := 0.0
		var cnt := 0
		for r in m.regions:
			var w: float = float(m.wear[r])
			tot += (w / 100.0) if w >= 0.0 else (float(m.stage[r]) / 3.0)
			cnt += 1
		thin = lerpf(1.0, 0.55, clampf(tot / float(maxi(cnt, 1)), 0.0, 1.0))
	var crawl: bool = m.profile.get("crown", "plain") == "regrowth" and not reduced
	# Outer arcs.
	_region_arc(ci, m, "head", c, R, -PI * 0.5, HEAD_SPAN, th * thin, t, alpha, crawl)
	_region_arc(ci, m, "legs", c, R, PI * 0.5, LEGS_SPAN, th * thin, t, alpha, crawl)
	_region_arc(ci, m, "arms", c, R, 0.0, ARMS_SPAN, th * thin, t, alpha, crawl)
	_region_arc(ci, m, "arms", c, R, PI, ARMS_SPAN, th * thin, t, alpha, crawl, true)
	if m.has_region("mantle"):
		_region_arc(ci, m, "mantle", c, R * UiLook.CROWN_MANTLE_R, PI * 0.5, MANTLE_SPAN, th * 0.85, t, alpha, crawl)
		_mantle_teeth(ci, m, c, R * UiLook.CROWN_MANTLE_R, th, alpha)
	# The core ring, inside. Heat shimmers it and thickens it; internal wear is its own thinner ring inside that.
	var heat: int = m.heat_stage
	var core_r: float = R * UiLook.CROWN_CORE_R
	var core_th: float = th * thin * (1.0 + 0.28 * float(heat))
	if heat > 0 and not reduced:
		core_r *= 1.0 + 0.035 * float(heat) * sin(t * UiLook.HZ_HEAT * TAU * (1.0 + 0.4 * float(heat)))
	_region_arc(ci, m, "core", c, core_r, PI * 0.5, CORE_SPAN, core_th, t, alpha, crawl, false, UiLook.col(UiLook.INTERNAL) if heat > 0 else Color(0, 0, 0, 0))
	if m.internal_stage > 0 or heat > 0:
		var ist: int = maxi(m.internal_stage, 1 if heat > 0 else 0)
		var ic: Color = UiLook.alpha(UiLook.INTERNAL, alpha)
		_arc(ci, c, core_r * 0.66, PI * 0.5, CORE_SPAN, ist, ic, th * 0.6, t, alpha, 0.0, 0, crawl, 0.0)
	if m.boil_flash > 0.0:
		var k: float = 1.0 - m.boil_flash / 0.8
		ci.draw_arc(c, R * (0.5 + 0.9 * k), 0.0, TAU, 40, Color(1, 1, 1, (1.0 - k) * 0.9), maxf(2.0, th * (1.4 - k)), true)
	# Pride mask: while the Proud front holds, an unbroken thin ring stands outside the crown; on the crack it shatters.
	if m.profile.get("crown", "plain") == "pride_mask":
		if m.pride_holds:
			ci.draw_arc(c, R * 1.09, 0.0, TAU, 48, UiLook.alpha(UiLook.INK, 0.55 * alpha), maxf(1.5, th * 0.32), true)
		elif m.facade_age < 0.6:
			var kk: float = m.facade_age / 0.6
			var seg := 18
			for i in range(seg):
				var a0: float = TAU * float(i) / float(seg) + kk * 0.6
				ci.draw_arc(c, R * (1.09 + 0.35 * kk), a0, a0 + TAU / float(seg) * 0.45, 3, UiLook.alpha(UiLook.INK, (1.0 - kk) * 0.7), maxf(1.5, th * 0.32), true)
		var notch_angles: Array = [deg_to_rad(-38.0), deg_to_rad(142.0), deg_to_rad(212.0)]
		for i in range(mini(m.shame, 3)):
			_notch(ci, c, R, notch_angles[i], th)
	_windows(ci, m, c, R, t, th, reduced)


static func _region_arc(ci: CanvasItem, m: UiFighterModel, region: String, c: Vector2, r: float, a_mid: float, span: float, th: float, t: float, alpha: float, crawl: bool, second: bool = false, col_override: Color = Color(0, 0, 0, 0)) -> void:
	if not m.has_region(region):
		return
	var st: int = int(m.stage[region])
	var col: Color = col_override if col_override.a > 0.0 else UiLook.stage_col(st, m.aura)
	var age: float = float(m.region_age[region])
	var dir: int = int(m.region_dir[region])
	var seed: int = 0 if not second else 1
	_arc(ci, c, r, a_mid, span, st, col, th, t, alpha, age, dir, crawl, float(seed) * 0.37)


## One arc at a stage. age/dir animate the last change: a worsening flashes bright, a mend sweeps a light along the arc.
static func _arc(ci: CanvasItem, c: Vector2, r: float, a_mid: float, span: float, stage: int, col: Color, th: float, t: float, alpha: float, age: float, dir: int, crawl: bool, phase: float) -> void:
	var a0: float = a_mid - span * 0.5
	var a1: float = a_mid + span * 0.5
	var under := UiLook.alpha(UiLook.INK_DARK, 0.55 * alpha)
	var fl: float = 1.0
	match stage:
		0:
			ci.draw_arc(c, r, a0, a1, 24, under, th + 3.0, true)
			ci.draw_arc(c, r, a0, a1, 24, Color(col, alpha), th, true)
		1:
			ci.draw_arc(c, r, a0, a1, 24, under, th * 0.8 + 3.0, true)
			ci.draw_arc(c, r, a0, a1, 24, Color(col, alpha), th * 0.8, true)
			for a in [a0, a1]:
				var d := Vector2(cos(a), sin(a))
				UiIcons.line(ci, c + d * (r - th * 1.0), c + d * (r + th * 1.0), maxf(1.5, th * 0.45), Color(col, alpha), true)
		2:
			if not _still:
				fl = 0.6 + 0.4 * (0.5 + 0.5 * sin((t + phase) * UiLook.HZ_BATTERED * TAU))
			var dash: float = deg_to_rad(7.0)
			var step: float = deg_to_rad(11.0)
			var off: float = fmod(t * 0.35, step) if crawl else 0.0
			var a: float = a0 - off
			while a < a1:
				var s0: float = maxf(a, a0)
				var e0: float = minf(a + dash, a1)
				if e0 > s0:
					ci.draw_arc(c, r, s0, e0, 4, under, th * 0.7 + 3.0, true)
					ci.draw_arc(c, r, s0, e0, 4, Color(col, alpha * fl), th * 0.7, true)
				a += step
		_:
			var stub: float = span * 0.17
			for pair in [[a0, a0 + stub], [a1 - stub, a1]]:
				ci.draw_arc(c, r, pair[0], pair[1], 6, under, th * 0.6 + 3.0, true)
				ci.draw_arc(c, r, pair[0], pair[1], 6, Color(col, alpha * 0.85), th * 0.6, true)
			for a in [a0 + stub + 0.05, a1 - stub - 0.05]:
				var d2 := Vector2(cos(a), sin(a))
				UiIcons.line(ci, c + d2 * (r - th * 0.9), c + d2 * (r + th * 0.9), maxf(1.5, th * 0.4), Color(col, alpha), true)
	if age >= 0.0 and age < UiLook.MEND_SWEEP:
		var k: float = age / UiLook.MEND_SWEEP
		if dir < 0:
			var ang: float = lerpf(a0, a1, k)
			ci.draw_circle(c + Vector2(cos(ang), sin(ang)) * r, th * (1.1 + 0.6 * (1.0 - k)), Color(1, 1, 1, (1.0 - k) * 0.95 * alpha))
		elif dir > 0 and age < 0.3:
			var kk: float = age / 0.3
			ci.draw_arc(c, r, a0, a1, 24, Color(1, 1, 1, (1.0 - kk) * 0.9 * alpha), th * (1.0 + 1.2 * (1.0 - kk)), true)


static func _notch(ci: CanvasItem, c: Vector2, R: float, a: float, th: float) -> void:
	var d := Vector2(cos(a), sin(a))
	UiIcons.line(ci, c + d * (R - th * 1.4), c + d * (R + th * 1.4), th * 1.5, UiLook.alpha(UiLook.INK, 0.95), true)
	UiIcons.line(ci, c + d * (R - th * 1.2), c + d * (R + th * 1.2), th * 0.9, UiLook.col(UiLook.INK_DARK), true)


static func _mantle_teeth(ci: CanvasItem, m: UiFighterModel, c: Vector2, r: float, th: float, alpha: float) -> void:
	if int(m.stage["mantle"]) >= 3:
		return
	var a0: float = PI * 0.5 - MANTLE_SPAN * 0.5
	var n := 9
	for i in range(n + 1):
		var a: float = a0 + MANTLE_SPAN * float(i) / float(n)
		var d := Vector2(cos(a), sin(a))
		var tip: Vector2 = c + d * (r + th * 1.9)
		var b0: Vector2 = c + Vector2(cos(a - 0.03), sin(a - 0.03)) * (r + th * 0.4)
		var b1: Vector2 = c + Vector2(cos(a + 0.03), sin(a + 0.03)) * (r + th * 0.4)
		ci.draw_colored_polygon(PackedVector2Array([tip, b0, b1]), Color(UiLook.stage_col(int(m.stage["mantle"]), m.aura), 0.85 * alpha))


static func _windows(ci: CanvasItem, m: UiFighterModel, c: Vector2, R: float, t: float, th: float, reduced: bool) -> void:
	if m.parry_t >= 0.0:
		var dur: float = maxf(m.parry_dur, UiLook.WINDOW_MIN_SHOWN)
		var k: float = clampf(m.parry_t / dur, 0.0, 1.0)
		var rr: float = R * 1.32 if reduced else R * (1.75 - 0.5 * k)
		var wcol: Color = UiLook.alpha(UiLook.INK, 0.95)
		ci.draw_arc(c, rr, 0.0, TAU, 48, UiLook.alpha(UiLook.INK_DARK, 0.6), maxf(3.0, th * 0.8) + 3.0, true)
		ci.draw_arc(c, rr, 0.0, TAU, 48, wcol, maxf(3.0, th * 0.8), true)
		for i in range(4):
			var a: float = PI * 0.5 * float(i)
			var d := Vector2(cos(a), sin(a))
			UiIcons.line(ci, c + d * (rr - th * 1.6), c + d * (rr + th * 1.6), maxf(3.0, th * 0.9), wcol, true)
	if m.chain_t >= 0.0:
		var dur2: float = maxf(m.chain_dur, UiLook.WINDOW_MIN_SHOWN)
		var k2: float = clampf(m.chain_t / dur2, 0.0, 1.0)
		var ccol: Color = UiLook.alpha(UiLook.WARN, 0.95)
		var sweep: float = TAU * (1.0 - k2)
		if reduced:
			sweep = TAU * 0.6
		ci.draw_arc(c, R * 1.38, -PI * 0.5, -PI * 0.5 + sweep, 32, UiLook.alpha(UiLook.INK_DARK, 0.6), maxf(3.0, th * 0.7) + 3.0, true)
		ci.draw_arc(c, R * 1.38, -PI * 0.5, -PI * 0.5 + sweep, 32, ccol, maxf(3.0, th * 0.7), true)
		var n: int = clampi(m.chain_n, 1, 6)
		var cw: float = th * 1.6
		var x0: float = c.x - cw * 0.5 * float(n - 1)
		for i in range(n):
			UiIcons.chevron(ci, Vector2(x0 + cw * float(i), c.y - R * 1.38 - th * 2.6), cw * 0.8, 1.0, maxf(2.5, th * 0.6), ccol)


## The small marks that ride above a fighter: its stance icon, or the hidden mark. Drawn at the crown's top.
static func draw_marker(ci: CanvasItem, m: UiFighterModel, c: Vector2, R: float, s: float, t: float) -> void:
	var size: float = maxf(22.0 * s, 20.0)
	var p: Vector2 = c + Vector2(0.0, -R * 1.3 - size * 0.9)
	var chip := Rect2(p - Vector2(size * 0.75, size * 0.62), Vector2(size * 1.5, size * 1.24))
	UiIcons.rrect(ci, chip, size * 0.3, UiLook.alpha(UiLook.SCRIM, 0.7), UiLook.alpha(UiLook.EDGE, 0.5), 1.2)
	if m.hidden:
		UiIcons.eye_slash(ci, p, size * 0.95, UiLook.col(UiLook.HIDDEN))
	else:
		UiIcons.stance(ci, m.stance, p, size * 0.85, UiLook.stance_col(m.stance))
	if m.cue < UiLook.CUE_PULSE:
		var k: float = m.cue / UiLook.CUE_PULSE
		UiIcons.sound_burst(ci, p + Vector2(size * 1.05, -size * 0.1), size * 0.9, m.cue_intensity, UiLook.alpha(UiLook.INK, 1.0 - k))
