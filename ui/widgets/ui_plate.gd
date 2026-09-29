class_name UiPlate
## A fighter's nameplate: name, stance, tier pips, the ego meter, charge, and the state chips (hidden, trail lost,
## charging, chain, signature ready). There is no health bar: damage is read on the crown and the silhouette.
## Every cue pairs colour with shape: stance icons, striped meter fills with tick marks, diamond pips, chips with icons.
## The plate mirrors for the right-hand fighter and fills its bars from the outer edge inward.

const STANCE_IDS: Array = ["press", "guard", "dodge", "escape"]   # the sim's stance order: AGGRESSIVE, DEFENSIVE, EVASIVE, ESCAPE

static var _A := 1.0   # the plate's overall opacity this frame (dimmed during a cinematic)


static func _c(c: Color) -> Color:
	return Color(c.r, c.g, c.b, c.a * _A)


static func _base(y0: float, h: float, fs: int) -> float:
	return y0 + (h - UiText.height(fs)) * 0.5 + UiText.ascent(fs)


static func draw(ci: CanvasItem, m: UiFighterModel, rect: Rect2, pm: Dictionary, s: float, t: float, o: Dictionary) -> void:
	_A = float(o.get("plate_alpha", 1.0))
	UiText.no_outline = true
	UiText.defer = true
	var left: bool = m.left_side
	var pad: float = float(pm["pad"])
	var reduced: bool = bool(o.get("reduced_motion", false))
	# A light scrim: the plate is a quiet strip on the screen's edge, not a panel (Orb: nothing in the way of the fight).
	UiIcons.rrect(ci, rect, 10.0 * s, _c(UiLook.alpha(UiLook.SCRIM, 0.5)), _c(UiLook.alpha(UiLook.EDGE, 0.22)), maxf(1.0, 1.2 * s))
	# Landscape plates are compact: the stance chip shares the name's row, and the state chips share the pips' row.
	# Portrait plates (a narrow phone) keep separate rows.
	var combined: bool = not bool(pm["compact"])
	var x0: float = rect.position.x + pad
	var x1: float = rect.end.x - pad
	var inner_w: float = x1 - x0
	var ink: Color = _c(UiLook.col(UiLook.INK))
	var dim: Color = _c(UiLook.col(UiLook.INK_DIM))

	# Row 1: name, an AI tag, and the brink chip on the far side.
	var fs: int = int(pm["fs_name"])
	var ry: float = rect.position.y + float(pm["name_y"])
	var rh: float = float(pm["name_h"])
	var nb: float = _base(ry, rh, fs)
	var nw: float = UiText.draw(ci, m.name, Vector2(x0 if left else x1, nb), fs, ink, -1 if left else 1, 2.0)
	if m.ai:
		var afs: int = int(pm["fs_state"])
		var tag: String = UiData.t("state.ai")
		var tw: float = UiText.width(tag, afs)
		var tx: float = (x0 + nw + 10.0 * s) if left else (x1 - nw - 10.0 * s - tw - 12.0 * s)
		UiIcons.rrect(ci, Rect2(tx, ry + 1.0, tw + 12.0 * s, rh - 2.0), 5.0 * s, _c(Color(1, 1, 1, 0.12)), _c(UiLook.alpha(UiLook.EDGE, 0.5)), 1.0)
		UiText.draw(ci, tag, Vector2(tx + 6.0 * s, _base(ry, rh, afs)), afs, dim, -1)
	if m.brink and combined:
		# Icon only, right after the name (the crown ring, the card and the silhouette say the rest).
		var bcol2: Color = _c(Color(UiLook.col(UiLook.STAGE_BROKEN), 1.0 if reduced else (0.6 + 0.4 * (0.5 + 0.5 * sin(t * UiLook.HZ_BRINK * TAU)))))
		var isz2: float = rh * 0.8
		var ai_w: float = (UiText.width(UiData.t("state.ai"), int(pm["fs_state"])) + 22.0 * s) if m.ai else 0.0
		var bx2: float = (x0 + nw + 10.0 * s + ai_w) if left else (x1 - nw - 10.0 * s - ai_w - isz2)
		UiIcons.brink(ci, Vector2(bx2 + isz2 * 0.5, ry + rh * 0.5), isz2, bcol2)
	if m.brink and not combined:
		var bfs: int = int(pm["fs_state"])
		var bt: String = UiData.t("state.brink")
		var bw: float = UiText.width(bt, bfs)
		var pulse: float = 1.0 if reduced else (0.6 + 0.4 * (0.5 + 0.5 * sin(t * UiLook.HZ_BRINK * TAU)))
		var bcol: Color = _c(Color(UiLook.col(UiLook.STAGE_BROKEN), pulse))
		var isz: float = rh * 0.86
		# It never crowds the name: the full chip if it fits, the icon alone if not, nothing on the narrowest plates
		# (the crown, the silhouette and the card still say it).
		var used: float = nw + (UiText.width(UiData.t("state.ai"), int(pm["fs_state"])) + 22.0 * s if m.ai else 0.0)
		var avail: float = inner_w - used - 10.0 * s
		var full_w: float = isz + 8.0 * s + bw
		var show_text: bool = full_w <= avail
		if show_text or isz <= avail:
			var cw2: float = full_w if show_text else isz
			var bx: float = (x1 - cw2) if left else x0
			UiIcons.brink(ci, Vector2(bx + isz * 0.5, ry + rh * 0.5), isz, bcol)
			if show_text:
				UiText.draw(ci, bt, Vector2(bx + isz + 8.0 * s, _base(ry, rh, bfs)), bfs, bcol, -1, 1.5)

	# The pips' geometry and the signature chip's width are needed early: the state chips sit after the pips.
	var psize: float = float(pm["pip"])
	var pstep: float = psize * 1.4
	var pips_w: float = pstep * 3.0 + psize
	var tfs: int = int(pm["fs_tier"])
	var sig_ready: bool = m.charge >= m.sig_cost
	var sig_label: String = UiData.t("state.signature")
	var tier_rh: float = float(pm["tier_h"])
	var sig_w: float = UiText.width(sig_label, tfs) + tier_rh * 0.9 + 16.0 * s if sig_ready else 0.0

	# Row 2: the stance chip (far side of the name's row in landscape), then state chips in the inward direction.
	ry = rect.position.y + float(pm["chip_y"])
	rh = float(pm["chip_h"])
	var cfs: int = int(pm["fs_chip"])
	var word: String = UiData.t("stance." + STANCE_IDS[clampi(m.stance, 0, 3)])
	var scol: Color = UiLook.stance_col(m.stance)
	var isize: float = rh * 0.68
	var cw: float = isize + UiText.width(word, cfs) + 20.0 * s
	var cur: float = (inner_w - cw) if combined else 0.0
	_chip(ci, rect, left, pad, cur, cw, ry, rh, _c(UiLook.alpha(UiLook.SCRIM, 0.85)), _c(scol), 2.0)
	var cx: float = (x0 + cur + 8.0 * s + isize * 0.5) if left else (x1 - cur - 8.0 * s - isize * 0.5)
	UiIcons.stance(ci, m.stance, Vector2(cx, ry + rh * 0.5), isize, _c(scol))
	var tx0: float = (x0 + cur + 8.0 * s + isize + 6.0 * s) if left else (x1 - cur - 8.0 * s - isize - 6.0 * s)
	UiText.draw(ci, word, Vector2(tx0, _base(ry, rh, cfs)), cfs, ink, -1 if left else 1, 1.5)
	# State chips: after the stance chip (portrait), or on the pips' row after the pips (landscape), never over SIGNATURE.
	var chip_limit: float = inner_w
	if combined:
		ry = rect.position.y + float(pm["tier_y"])
		rh = tier_rh
		cur = pips_w + 10.0 * s
		chip_limit = inner_w - (sig_w + 8.0 * s if sig_ready else 0.0)
	else:
		cur += cw + 8.0 * s
	var chips: Array = []
	if m.hidden:
		chips.append(["hidden", UiData.t("state.hidden"), UiLook.col(UiLook.HIDDEN)])
	if m.lost_trail:
		chips.append(["lost", UiData.t("state.lost_trail"), UiLook.col(UiLook.WARN)])
	if m.charging:
		chips.append(["charging", UiData.t("state.charging"), UiLook.col(UiLook.CHARGE)])
	if m.chain_n > 1 and m.chain_t >= 0.0:
		chips.append(["chain", UiData.fmt("state.chain", {"n": m.chain_n}), UiLook.col(UiLook.WARN)])
	var sfs: int = int(pm["fs_state"])
	var chip_h: float = rh * 0.82
	var chip_y: float = ry + (rh - chip_h) * 0.5
	for ch in chips:
		var label: String = ch[1]
		var lw: float = UiText.width(label, sfs)
		var w: float = chip_h * 0.9 + lw + 16.0 * s
		if cur + w > chip_limit:
			break
		_chip(ci, rect, left, pad, cur, w, chip_y, chip_h, _c(UiLook.alpha(UiLook.SCRIM, 0.85)), _c(ch[2]), 1.6)
		var icx: float = (x0 + cur + 8.0 * s + chip_h * 0.35) if left else (x1 - cur - 8.0 * s - chip_h * 0.35)
		var icp := Vector2(icx, chip_y + chip_h * 0.5)
		match ch[0]:
			"hidden":
				UiIcons.eye_slash(ci, icp, chip_h * 0.75, _c(ch[2]))
			"lost":
				UiIcons.trail_lost(ci, icp, chip_h * 0.8, _c(ch[2]))
			"charging":
				UiIcons.caret_up(ci, icp + Vector2(0, chip_h * 0.12), chip_h * 0.5, _c(ch[2]))
			"chain":
				UiIcons.chevron(ci, icp, chip_h * 0.45, 1.0, maxf(2.0, chip_h * 0.11), _c(ch[2]))
		var ltx: float = (x0 + cur + 8.0 * s + chip_h * 0.75 + 4.0 * s) if left else (x1 - cur - 8.0 * s - chip_h * 0.75 - 4.0 * s)
		UiText.draw(ci, label, Vector2(ltx, _base(chip_y, chip_h, sfs)), sfs, ink, -1 if left else 1)
		cur += w + 6.0 * s

	# Row 3: tier pips (the next pip fills with momentum), the tier name, and SIGNATURE on the far side when ready.
	ry = rect.position.y + float(pm["tier_y"])
	rh = float(pm["tier_h"])
	var pcol: Color = _c(UiLook.col(UiLook.TIER_PIP))
	var pedge: Color = _c(UiLook.alpha(UiLook.INK, 0.9))
	for i in range(4):
		var fill: float = 1.0 if i < m.tier else (clampf(m.momentum / 100.0, 0.0, 1.0) if i == m.tier else 0.0)
		var pxc: float = (x0 + psize * 0.5 + pstep * float(i)) if left else (x1 - psize * 0.5 - pstep * float(i))
		var pc := Vector2(pxc, ry + rh * 0.5)
		# The partial pip fills from the fighter's near side, like the bars.
		if left:
			UiIcons.pip(ci, pc, psize, fill, pcol, pedge)
		else:
			_pip_right(ci, pc, psize, fill, pcol, pedge)
	var tname: String = UiData.tier_name(m.tier)
	var name_w: float = UiText.width(tname, tfs)
	if not combined and pips_w + 12.0 * s + name_w + (sig_w + 8.0 * s if sig_ready else 0.0) <= inner_w:
		var nx: float = (x0 + pips_w + 12.0 * s) if left else (x1 - pips_w - 12.0 * s)
		UiText.draw(ci, tname, Vector2(nx, _base(ry, rh, tfs)), tfs, dim, -1 if left else 1)
	if sig_ready:
		var pl: float = 1.0   # steady: a ready signature does not pulse (nothing animates at rest)
		var chh: float = rh
		# On a narrow plate (a phone) the chip shrinks to its star, so it never covers the pips.
		var avail: float = inner_w - pips_w - 8.0 * s
		var sw: float = sig_w if sig_w <= avail else chh * 1.2
		if sw <= avail:
			var sx: float = (x1 - sw) if left else x0
			UiIcons.rrect(ci, Rect2(sx, ry, sw, chh), 6.0 * s, _c(Color(UiLook.col(UiLook.CHARGE_READY), 0.92)), _c(Color(1, 1, 1, pl)), 2.0)
			UiIcons.star4(ci, Vector2(sx + (chh * 0.55 if sw == sig_w else sw * 0.5), ry + chh * 0.5), chh * 0.62, _c(UiLook.col(UiLook.INK_DARK)))
			if sw == sig_w:
				UiText.draw(ci, sig_label, Vector2(sx + chh * 0.55 + chh * 0.45 + 4.0 * s, _base(ry, chh, tfs)), tfs, _c(UiLook.col(UiLook.INK_DARK)), -1)

	# Rows 4 and 5: the ego meter and charge, each a labelled striped bar with tick marks.
	var efs: int = int(pm["fs_ego"])
	var ego_label: String = UiData.t("meter." + m.ego_name)
	var charge_label: String = UiData.t("meter.charge")
	var label_w: float = maxf(UiText.width(ego_label, efs), UiText.width(charge_label, efs)) + 10.0 * s
	var bar_h: float = float(pm["bar_h"])
	var shame_w: float = 0.0
	var shame_max: int = int(m.profile.get("shame_max", 0))
	if shame_max > 0:
		shame_w = float(shame_max) * (bar_h + 4.0 * s) + 6.0 * s
	var bw2: float = maxf(inner_w - label_w - shame_w, 20.0)
	ry = rect.position.y + float(pm["ego_y"])
	rh = float(pm["ego_h"])
	UiText.draw(ci, ego_label, Vector2(x0 if left else x1, _base(ry, rh, efs)), efs, ink, -1 if left else 1, 1.5)
	var bx: float = (x0 + label_w) if left else (x1 - label_w - bw2)
	var by: float = ry + (rh - bar_h) * 0.5
	var notch: float = float(m.profile.get("ego_notch", 0)) / 100.0
	_bar(ci, Rect2(bx, by, bw2, bar_h), m.ego / 100.0, _c(UiLook.ego_col(m.ego_name)), left, notch if notch > 0.0 else -1.0, s)
	if shame_max > 0:
		var sq: float = bar_h
		for i in range(shame_max):
			var sxp: float = (bx + bw2 + 6.0 * s + float(i) * (sq + 4.0 * s)) if left else (bx - 6.0 * s - sq - float(i) * (sq + 4.0 * s))
			var r := Rect2(sxp, by, sq, sq)
			ci.draw_rect(r, _c(Color(0, 0, 0, 0.5)))
			if i < m.shame:
				ci.draw_rect(r.grow(-2.0), ink)
			ci.draw_rect(r, _c(UiLook.alpha(UiLook.INK, 0.8)), false, 1.2)
	ry = rect.position.y + float(pm["charge_y"])
	rh = float(pm["charge_h"])
	UiText.draw(ci, charge_label, Vector2(x0 if left else x1, _base(ry, rh, efs)), efs, ink, -1 if left else 1, 1.5)
	by = ry + (rh - bar_h) * 0.5
	var ccol: Color = UiLook.col(UiLook.CHARGE_READY) if sig_ready else UiLook.col(UiLook.CHARGE)
	_bar(ci, Rect2(bx if left else bx - shame_w, by, bw2 + shame_w, bar_h), m.charge / 100.0, _c(ccol), left, m.sig_cost / 100.0, s, sig_ready)
	UiText.flush(ci)
	UiText.no_outline = false


static func _chip(ci: CanvasItem, rect: Rect2, left: bool, pad: float, cur: float, w: float, y: float, h: float, fill: Color, edge: Color, edge_w: float) -> void:
	var x: float = (rect.position.x + pad + cur) if left else (rect.end.x - pad - cur - w)
	UiIcons.rrect(ci, Rect2(x, y, w, h), h * 0.28, fill, edge, edge_w)


static func _pip_right(ci: CanvasItem, c: Vector2, size: float, fill: float, col: Color, edge: Color) -> void:
	# A pip that fills from its right side: draw the full pip mirrored by filling (1 - fill) from the left of an inverted clip.
	var s: float = size * 0.5
	var poly := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
	UiIcons.fill_poly(ci, poly, Color(0, 0, 0, 0.45 * _A))
	if fill > 0.0:
		var flipped := PackedVector2Array()
		for p in poly:
			flipped.append(Vector2(2.0 * c.x - p.x, p.y))
		var clipped: PackedVector2Array = UiIcons.clip_x(flipped, c.x - s + 2.0 * s * clampf(fill, 0.0, 1.0))
		var back := PackedVector2Array()
		for p in clipped:
			back.append(Vector2(2.0 * c.x - p.x, p.y))
		if back.size() >= 3:
			UiIcons.fill_poly(ci, back, col, true)
	var closed: PackedVector2Array = poly.duplicate()
	closed.append(poly[0])
	ci.draw_polyline(closed, edge, maxf(1.5, size * 0.09), true)


## A striped, ticked bar. The stripes and the quarter ticks carry the fill without colour; `mark` (0..1) is a taller
## marker (the Anti-hero's half-Pride line, or the signature's charge cost); `hot` brightens the edge.
static func _bar(ci: CanvasItem, r: Rect2, frac: float, col: Color, left: bool, mark: float, s: float, hot: bool = false) -> void:
	ci.draw_rect(r, _c(Color(0, 0, 0, 0.6)))
	var fw: float = r.size.x * clampf(frac, 0.0, 1.0)
	if fw > 0.5:
		var fr: Rect2 = Rect2(r.position.x if left else r.end.x - fw, r.position.y, fw, r.size.y)
		ci.draw_rect(fr, col)
		# The stripes that carry the fill without colour: one tiled texture rect, not a line per stripe.
		ci.draw_texture_rect(UiIcons.stripes(), fr, true, Color(1, 1, 1, _A))
	# The three quarter ticks in one draw command.
	var ticks := PackedVector2Array()
	for q in [0.25, 0.5, 0.75]:
		var qx: float = r.position.x + r.size.x * (q if left else 1.0 - q)
		ticks.append(Vector2(qx, r.position.y))
		ticks.append(Vector2(qx, r.end.y))
	ci.draw_multiline(ticks, _c(Color(0, 0, 0, 0.5)), 1.0)
	if mark > 0.0:
		var mx: float = r.position.x + r.size.x * (mark if left else 1.0 - mark)
		var ext: float = maxf(3.0, 3.5 * s)
		ci.draw_line(Vector2(mx, r.position.y - ext), Vector2(mx, r.end.y + ext), _c(UiLook.col(UiLook.INK_DARK)), maxf(4.0, 4.0 * s))
		ci.draw_line(Vector2(mx, r.position.y - ext), Vector2(mx, r.end.y + ext), _c(UiLook.col(UiLook.INK)), maxf(2.0, 2.0 * s))
	ci.draw_rect(r, _c(UiLook.alpha(UiLook.INK, 0.95 if hot else 0.6)), false, maxf(1.0, (2.0 if hot else 1.2) * s))
