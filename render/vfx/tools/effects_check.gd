extends SceneTree
## Checks of the effects that have no picture test: Art's palette is read from data/art/effects.json, a hard impact's
## fissures vent dust as their front opens, scorch events shed embers by variant, the break ring fires once when a fighter
## reaches full speed, cracks skip the ocean, and the debris pool never passes its cap. Headless is fine.
##   godot --headless --path . --script res://render/vfx/tools/effects_check.gd

var fails: int = 0


func _check(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Palette.
	print("palette")
	_check(VfxPalette.glass("mid").to_html(false) == "9fd6e4", "glass mid comes from data/art/effects.json (9fd6e4)")
	_check(VfxPalette.dust("desert", "mid").to_html(false) == "e0c48a", "desert dust mid is Art's (e0c48a)")
	_check(not VfxPalette.takes_cracks("ocean"), "the ocean takes no cracks")
	_check(VfxPalette.crack("city").to_html(false) == "1f2329", "city crack line is Art's (1f2329)")
	_check(VfxPalette.haze().to_html(false) == "cfe6f0", "haze is Art's (cfe6f0)")
	var S := SimCore.createSim()
	SimCore.newMatch(S, 4)
	var h := VfxHub.new()
	h.cracks_enabled = true
	h.destruction_enabled = true
	h.embers_enabled = true
	h.reset(S, 4)
	# A hard impact on plains: fissures, and vents while its front opens.
	print("cracks and vents")
	var x: float = 0.0
	for i in range(S.buildings.size()):
		pass
	x = SimWrap.wrap(2250.0 * SimConst.PS)
	var A = S.fighters[1]
	var rec = WorldCrater.dig(S, x, 14.0, A, "impact", 0.3, 1.0)
	S.out.fx.clear()
	_check(rec != null, "a crater of energy 14 was dug")
	_tick(S, h, [])
	_check(h.crack_sets.size() == 1, "one crack set from the record (%d)" % h.crack_sets.size())
	_check(h.debris.jobs.size() > 0, "fissure vents are scheduled (%d jobs)" % h.debris.jobs.size())
	var puffs0: int = h.debris.bits.size()
	for k in range(60):
		_tick(S, h, [])
	_check(h.debris.jobs.is_empty() and h.debris.spawned > puffs0, "the vents ran and threw dust (%d bits)" % h.debris.spawned)
	# A rebuild after a seek draws no vents.
	var h2 := VfxHub.new()
	h2.cracks_enabled = true
	h2.reset(S, 4)
	S.T += 5.0
	_tick(S, h2, [])
	_check(h2.crack_sets.size() == 1 and h2.debris.jobs.is_empty(), "a set rebuilt long after its record has no vents")
	# Embers by variant.
	print("embers")
	for v in ["GLASS TRENCH", "FIRESTORM", "HORIZON CLEAVE", "MERIDIAN SCAR"]:
		var before: int = h.debris.spawned
		var e := VfxMock.ev("scorch", {"x": x, "y": 50.0, "w": 100.0, "power": 3.0, "variant": v, "owner": 0})
		_tick(S, h, [e])
		_check(h.debris.spawned > before, "%s sheds embers (%d)" % [v, h.debris.spawned - before])
	# The pool cap under a flood.
	print("pool")
	for k in range(400):
		var e := VfxMock.ev("scorch", {"x": x, "y": 50.0, "w": 100.0, "power": 4.5, "variant": "MERIDIAN SCAR", "owner": 0})
		_tick(S, h, [e, e, e])
	_check(h.debris.bits.size() <= VfxLook.DEBRIS_CAP, "the debris pool stays within %d (%d)" % [VfxLook.DEBRIS_CAP, h.debris.bits.size()])
	# B2's floor events (docs/architecture/fx-events.md): a punch on a skyscraper, a crack, a dent, a pancake.
	print("floors")
	var tw: int = -1
	var house: int = -1
	for i in range(S.buildings.size()):
		var bb = S.buildings[i]
		if tw < 0 and bb.kind == "tower" and bb.floors >= WorldBrunt.FLOORS_MIN:
			tw = i
		if house < 0 and bb.floors < WorldBrunt.FLOORS_MIN and bb.h > 200.0:
			house = i
	_check(tw >= 0 and house >= 0, "a skyscraper (%d) and a small building (%d) exist" % [tw, house])
	var bt = S.buildings[tw]
	var hf := VfxHub.new()
	hf.destruction_enabled = true
	hf.reset(S, 4)
	var base: int = hf.debris.spawned
	var fh := VfxMock.ev("floor_hit", {"b": tw, "floor": 3, "n": 2, "outcome": "punch", "ratio": 1.4, "x": bt.x - bt.w * 0.5, "y": 500.0, "z": bt.z, "ux": 1.0, "uy": 0.0, "kind": "tower", "owner": 1, "victim": 0})
	var bh := VfxMock.ev("building_hit", {"b": tw, "outcome": "punch", "link": 1, "n": 1, "x": bt.x - bt.w * 0.5, "y": 500.0, "z": bt.z, "spd": 1500.0, "ux": 1.0, "uy": 0.0, "kind": "tower", "w": bt.w, "h": 1.0})
	_tick(S, hf, [fh, bh])
	var n_floor: int = hf.debris.spawned - base
	_check(n_floor > 20, "a floor punch throws shards and window glass (%d)" % n_floor)
	_check(hf.holes.is_empty(), "no decal for a skyscraper punch (Rendering cuts the tunnel)")
	var hf2 := VfxHub.new()
	hf2.destruction_enabled = true
	hf2.reset(S, 4)
	_tick(S, hf2, [bh])
	_check(hf2.debris.spawned > 0, "building_hit alone (no floor_hit) still bursts (%d)" % hf2.debris.spawned)
	for kind in ["crack", "dent"]:
		var h3 := VfxHub.new()
		h3.destruction_enabled = true
		h3.reset(S, 4)
		_tick(S, h3, [VfxMock.ev("floor_hit", {"b": tw, "floor": 2, "n": 0, "outcome": kind, "ratio": 0.5, "x": bt.x, "y": 400.0, "z": bt.z, "ux": 1.0, "uy": 0.0, "kind": "tower"})])
		_check(h3.debris.spawned > 0, "floor_hit %s throws something (%d)" % [kind, h3.debris.spawned])
	var h4 := VfxHub.new()
	h4.destruction_enabled = true
	h4.reset(S, 4)
	_tick(S, h4, [VfxMock.ev("floors_fall", {"b": tw, "from": 4, "to": 8, "n": 5, "x": bt.x, "z": bt.z, "w": bt.w})])
	_check(h4.debris.jobs.size() == 5, "a pancake of 5 floors schedules its bursts and a ring, the top floor firing at once (%d left)" % h4.debris.jobs.size())
	for k in range(40):
		_tick(S, h4, [])
	_check(h4.debris.jobs.is_empty() and h4.debris.spawned > 30, "the pancake ran top to bottom and threw dust and shrapnel (%d)" % h4.debris.spawned)
	var h5 := VfxHub.new()
	h5.destruction_enabled = true
	h5.reset(S, 4)
	_tick(S, h5, [VfxMock.ev("building_hit", {"b": house, "outcome": "heavy", "link": 1, "n": 1, "x": S.buildings[house].x, "y": 100.0, "z": S.buildings[house].z, "spd": 1200.0, "ux": 1.0, "uy": 0.0, "kind": "house", "w": S.buildings[house].w, "h": 1.0})])
	_check(h5.holes.size() == 2, "a heavy hit on a small building leaves two holes (%d)" % h5.holes.size())
	# The pool cap under many chains and pancakes at once.
	var h6 := VfxHub.new()
	h6.destruction_enabled = true
	h6.reset(S, 4)
	for k in range(60):
		_tick(S, h6, [VfxMock.ev("floors_fall", {"b": tw, "from": 1, "to": 15, "n": 15, "x": bt.x, "z": bt.z, "w": bt.w}), fh, bh])
	_check(h6.debris.bits.size() <= VfxLook.DEBRIS_CAP, "the pool holds under repeated pancakes and punches (%d)" % h6.debris.bits.size())
	# A straight flight draws a straight ribbon: the polyline from the interpolated head back through the history is
	# collinear (the history is kept at chest height, like the head), flat for a level flight and on one line for a climb.
	print("ribbon straightness")
	for slope in [0.0, 0.6]:
		var ts := VfxTrailState.new()
		var rg := SimRng.new(2)
		var ff = S.fighters[0]
		ff.state = "launched"
		ff.hidden = false
		ff.rush = null
		ff.x = 20000.0
		ff.y = 800.0
		for k in range(40):
			ff.x += 150.0
			ff.y += 150.0 * slope
			ts.step(S, ff, SimConst.DT, rg, VfxLook.Q_HIGH, true)
		var head_x: float = ff.x - 70.0                     # a frame part-way between the last two ticks
		var head_y: float = ff.y - 70.0 * slope + VfxLook.CHEST_Y
		var pts: PackedVector3Array = ts.ribbon(head_x, head_y, 0.0, 900.0, VfxLook.SEGS)
		var worst: float = 0.0
		for p in pts:
			var line_y: float = head_y + p.x * slope
			worst = maxf(worst, absf(p.y - line_y))
		_check(pts.size() == VfxLook.SEGS + 1 and worst < 0.01, "slope %.1f: ribbon points lie on the flight line (worst off-line %.3f units)" % [slope, worst])
	# A ribbon follows the fighter in depth: head at the fighter's z, history points at the z they were at.
	print("ribbon depth")
	var tz := VfxTrailState.new()
	var rz := SimRng.new(3)
	var fz = S.fighters[0]
	fz.state = "launched"
	fz.hidden = false
	fz.rush = null
	fz.x = 30000.0
	fz.y = 900.0
	for k in range(40):
		fz.x += 150.0
		fz.z = -20.0 * float(k)
		tz.step(S, fz, SimConst.DT, rz, VfxLook.Q_HIGH, true)
	var zp: PackedVector3Array = tz.ribbon(fz.x - 75.0, fz.y + VfxLook.CHEST_Y, fz.z + 10.0, 900.0, VfxLook.SEGS)
	_check(zp.size() == VfxLook.SEGS + 1 and absf(zp[0].z - (fz.z + 10.0)) < 0.01 and zp[VfxLook.SEGS].z > zp[0].z, "the ribbon starts at the head's depth and runs back through the depths it came from (%.0f to %.0f)" % [zp[0].z, zp[VfxLook.SEGS].z])
	# The break ring: a fighter accelerating from rest to 130 bh/s fires it once.
	print("break ring")
	var t := VfxTrailState.new()
	var rng := SimRng.new(1)
	var f = S.fighters[0]
	f.state = "launched"
	f.hidden = false
	f.rush = null
	f.x = 1000.0
	f.y = 300.0
	for k in range(120):
		f.x += minf(float(k) * 12.0, 130.0 * VfxLook.BH * SimConst.DT)
		t.step(S, f, SimConst.DT, rng, VfxLook.Q_HIGH, false)
	_check(t.rings == 1, "one break ring on reaching full speed (%d)" % t.rings)
	_water(S)
	_transform(S)
	print("\neffects check passed" if fails == 0 else "\neffects check FAILED (%d)" % fails)
	quit(0 if fails == 0 else 1)


## Water effects (docs/vfx/water-plan.md): skip, plunge, beam strike and wake, their scaling, their budgets and the data fallback.
func _water(S: SimState) -> void:
	print("water")
	var sx: float = 0.0
	while sx < SimConst.W:
		var wet: bool = true
		for k in range(-5, 6):
			if WorldWater.surfaceAt(S, SimWrap.wrap(sx + float(k) * 2000.0)) == WorldWater.DRY:
				wet = false
				break
		if wet:
			break
		sx += 2000.0
	_check(sx < SimConst.W, "open sea found at x=%.0f" % sx)
	var f0 = S.fighters[0]
	f0.x = sx
	f0.y = 100.0
	f0.vx = 6000.0
	f0.vy = 0.0
	f0.tier = 3.0
	f0.hidden = false
	var skim_ev := func(n: int, spd: float): return VfxMock.ev("skim", {"x": sx, "y": 0.0, "spd": spd, "n": n})
	# Scale grows with speed and tier.
	_check(VfxWater.scale_of(6000.0, 4.0) > VfxWater.scale_of(1500.0, 1.0) * 2.0, "the effect scale grows with speed and tier (%.2f vs %.2f)" % [VfxWater.scale_of(6000.0, 4.0), VfxWater.scale_of(1500.0, 1.0)])
	# A skip: spray and foam; later skips smaller; a skip at n=8 is not a plunge.
	var hs := VfxHub.new()
	hs.reset(S, 4)
	_tick(S, hs, [skim_ev.call(1, 5000.0)])
	var first: int = hs.debris.spawned
	_check(hs.water.skims == 1 and first > 20 and hs.debris._spray_alive > 10, "a skip throws spray and foam (%d bits, %d spray)" % [first, hs.debris._spray_alive])
	var hs2 := VfxHub.new()
	hs2.reset(S, 4)
	_tick(S, hs2, [skim_ev.call(5, 5000.0)])
	_check(hs2.debris.spawned < first, "the fifth skip is smaller than the first (%d < %d)" % [hs2.debris.spawned, first])
	var hs3 := VfxHub.new()
	hs3.reset(S, 4)
	_tick(S, hs3, [VfxMock.ev("splash", {"x": sx, "y": 0.0, "n": 8}), skim_ev.call(1, 5000.0)])
	_check(hs3.water.plunges == 0 and hs3.water.skims == 1, "a splash of 8 (a skip's own) is not also a plunge")
	# A plunge: a splash of 12 or more draws the column, scaled by the fighter's speed; the rebound comes later.
	var hp := VfxHub.new()
	hp.reset(S, 4)
	_tick(S, hp, [VfxMock.ev("splash", {"x": sx, "y": 0.0, "n": 12})])
	_check(hp.water.plunges == 1 and hp.debris.spawned > first, "a plunge throws more than a skip (%d > %d)" % [hp.debris.spawned, first])
	_check(hp.debris.jobs.size() >= 1, "the plunge schedules its rebound")
	var before_rebound: int = hp.debris.spawned
	for k in range(40):
		_tick(S, hp, [])
	_check(hp.debris.spawned > before_rebound, "the rebound jet follows (%d more)" % (hp.debris.spawned - before_rebound))
	# Quality and reduced motion thin it out.
	var hl := VfxHub.new()
	hl.quality = VfxLook.Q_LOW
	hl.reset(S, 4)
	hl.quality = VfxLook.Q_LOW
	_tick(S, hl, [skim_ev.call(1, 5000.0)])
	_check(hl.debris.spawned < first, "low quality throws less (%d < %d)" % [hl.debris.spawned, first])
	# A beam raking the sea: spray along it, bounded.
	var hb := VfxHub.new()
	hb.reset(S, 4)
	var bm := SimState.Beam.new()
	bm.A = f0
	bm.ox = sx
	bm.oy = 100.0
	bm.ux = 1.0
	bm.pw = 3.0
	S.beams.append(bm)
	var worst_alive: int = 0
	for t in range(60):
		var evs: Array = []
		for k in range(12):
			evs.append(VfxMock.ev("beamSplash", {"x": sx + float(t) * 160.0 + float(k) * 13.0}))
		_tick(S, hb, evs)
		worst_alive = maxi(worst_alive, hb.debris._spray_alive)
	S.beams.clear()
	_check(hb.water.beam_hits == 720 and hb.debris.spawned > 80, "a beam over the sea throws spray along its length (%d hits, %d bits)" % [hb.water.beam_hits, hb.debris.spawned])
	_check(worst_alive <= int(VfxWater.p("caps", "spray_alive")) and hb.debris.bits.size() <= VfxLook.DEBRIS_CAP, "the spray stays within its cap (%d) and the pool within %d" % [worst_alive, VfxLook.DEBRIS_CAP])
	# The wake: a fast low flight over water leaves one; slow, high or hidden does not.
	var hw := VfxHub.new()
	hw.reset(S, 4)
	f0.vx = 5000.0
	f0.y = 60.0
	_tick(S, hw, [])
	_check(hw.water.wakes >= 1 and hw.debris.spawned > 0, "a fast low flight leaves a wake (%d)" % hw.debris.spawned)
	var hw2 := VfxHub.new()
	hw2.reset(S, 4)
	f0.vx = 800.0
	_tick(S, hw2, [])
	f0.vx = 5000.0
	f0.y = 900.0
	_tick(S, hw2, [])
	f0.y = 60.0
	f0.hidden = true
	_tick(S, hw2, [])
	f0.hidden = false
	_check(hw2.water.wakes == 0, "no wake when slow, high or hidden")
	# Off: with the flag down nothing is thrown.
	var ho := VfxHub.new()
	ho.water_enabled = false
	ho.reset(S, 4)
	_tick(S, ho, [skim_ev.call(1, 5000.0), VfxMock.ev("splash", {"x": sx, "y": 0.0, "n": 12})])
	_check(ho.debris.spawned == 0, "water_enabled off throws nothing")
	# The data file is optional: with it gone every number falls back to the same default.
	var saved: Dictionary = VfxWater._data
	VfxWater._data = {}
	var ok_fallback: bool = VfxWater.p("scale", "ref_speed") == 4000.0 and VfxWater.p("caps", "spray_alive") == 260.0
	VfxWater._data = saved
	_check(ok_fallback, "missing data falls back to the defaults")
	var same: bool = true
	for g in VfxWater.DEFAULTS.keys():
		for k in VfxWater.DEFAULTS[g].keys():
			if not saved.has(g) or not saved[g].has(k) or float(saved[g][k]) != float(VfxWater.DEFAULTS[g][k]):
				same = false
				print("    differs: %s.%s" % [g, k])
	_check(same, "data/vfx/water.json and the built-in defaults agree")


## Transformation effects (docs/vfx/transform-plan.md): beats per version, the clock running through a sim pause, a live
## version holding on a hit-stop, tier shapes, budgets and the data fallback.
func _transform(S: SimState) -> void:
	print("transformation")
	var ev := func(actor: int, tier: float, version: String, dur: float): return VfxMock.ev("transform", {"actor": actor, "tier": tier, "source": "ai", "dur": dur, "version": version})
	var frozen_tick := func(h: VfxHub):
		S.tick += 1
		var tk := SimState.FxEvent.new()
		tk.type = "tick"
		tk.dt = SimConst.DT
		tk.frozen = true
		h.consume(S, [tk])
	# Beat lengths follow the staging table, scaled to the event's duration.
	for spec in [["full", 3.0, 60, 30, 90], ["short", 1.5, 24, 18, 48], ["live", 0.8, 10, 14, 24]]:
		var hb := VfxHub.new()
		hb.reset(S, 4)
		_tick(S, hb, [ev.call(0, 2.0, spec[0], spec[1])])
		var fm: VfxTransform.Form = hb.xform.forms[0] if hb.xform.forms.size() == 1 else null
		_check(fm != null and fm.g == spec[2] and fm.b == spec[3] and fm.s == spec[4], "%s: gather %d, break %d, settle %d ticks as in section 10.8 (%s)" % [spec[0], spec[2], spec[3], spec[4], "no form" if fm == null else "%d/%d/%d" % [fm.g, fm.b, fm.s]])
	var hs := VfxHub.new()
	hs.reset(S, 4)
	_tick(S, hs, [ev.call(1, 4.0, "full", 4.0)])
	var fz: VfxTransform.Form = hs.xform.forms[0]
	_check(fz.total() == 240 and fz.g == 80 and fz.b == 40 and fz.s == 120, "a longer full version (a final-form reveal, 4 s) scales every beat (%d/%d/%d)" % [fz.g, fz.b, fz.s])
	# A full version plays through the sim's frozen ticks: the age advances on each, and the form ends with the pause.
	var hp := VfxHub.new()
	hp.reset(S, 4)
	_tick(S, hp, [ev.call(0, 3.0, "full", 3.0)])
	var f0: VfxTransform.Form = hp.xform.forms[0]
	for k in range(100):
		frozen_tick.call(hp)
	_check(absf(f0.age - 100.0) < 0.01 and hp.xform.forms.size() == 1, "a full version's clock runs through frozen (paused) ticks (age %.0f after 100)" % f0.age)
	_check(VfxTransform.beat_of(f0, f0.age) == 2, "tick 100 of a full version is in the settle")
	for k in range(80):
		frozen_tick.call(hp)
	_check(hp.xform.forms.is_empty() and hp.xform.finished == 1, "the form ends after its 180 ticks")
	# A live version waits out a hit-stop (a frozen tick with no pause) and runs on live ticks.
	var hl := VfxHub.new()
	hl.reset(S, 4)
	_tick(S, hl, [ev.call(0, 2.0, "live", 0.8)])
	var fl: VfxTransform.Form = hl.xform.forms[0]
	_tick(S, hl, [])
	_tick(S, hl, [])
	frozen_tick.call(hl)
	frozen_tick.call(hl)
	_check(absf(fl.age - 2.0) < 0.01, "a live version holds on a hit-stop (age %.0f after 2 live and 2 frozen ticks)" % fl.age)
	# The look: aura in at the break, nothing outward on the gather, the shape changes with the tier, eases out.
	var fa := VfxTransform.Form.new()
	fa.g = 60
	fa.b = 30
	fa.s = 90
	_check(VfxTransform.aura_scale(fa, 0.0) == 1.0 and VfxTransform.aura_scale(fa, 59.0) < 0.2 and VfxTransform.aura_scale(fa, 60.0) == 1.0, "the aura is drawn in over the gather and is full size at the break")
	_check(VfxTransform.aura_alpha(fa, 61.0) >= VfxTransform.aura_alpha(fa, 140.0) and VfxTransform.aura_alpha(fa, 179.0) < 0.1, "the new aura is strongest at the break, holds, and eases out at the end (%.2f, %.2f)" % [VfxTransform.aura_alpha(fa, 61.0), VfxTransform.aura_alpha(fa, 179.0)])
	var shapes: Dictionary = {}
	for t in range(1, 5):
		shapes[int(VfxTransform.aura(t)["lobes"])] = true
	_check(shapes.size() == 4, "each tier has its own aura shape (%d distinct)" % shapes.size())
	# Never more than the budget, whatever the scene.
	var hq := VfxHub.new()
	hq.reset(S, 4)
	_tick(S, hq, [ev.call(0, 2.0, "full", 3.0), ev.call(1, 3.0, "full", 3.0)])
	_check(hq.xform.forms.size() == 2, "both fighters can transform at once")
	var hr := VfxHub.new()
	hr.reset(S, 4)
	_tick(S, hr, [ev.call(0, 2.0, "full", 3.0), ev.call(0, 3.0, "short", 1.5)])
	_check(hr.xform.forms.size() == 1 and (hr.xform.forms[0] as VfxTransform.Form).version == "short", "a slot has one form at a time; the newest wins")
	# Flag off: nothing starts. Data: missing falls back, and the file matches the defaults.
	var ho := VfxHub.new()
	ho.transform_enabled = false
	ho.reset(S, 4)
	_tick(S, ho, [ev.call(0, 2.0, "full", 3.0)])
	_check(ho.xform.forms.is_empty(), "transform_enabled off starts nothing")
	var saved: Dictionary = VfxTransform._data
	VfxTransform._data = {}
	var fallback: bool = VfxTransform.p("gather", "motes") == 40.0 and VfxTransform.beats("full") == [60, 30, 90] and int(VfxTransform.aura(4)["lobes"]) == 3
	VfxTransform._data = saved
	_check(fallback, "missing data falls back to the defaults")
	var same: bool = true
	for g in VfxTransform.DEFAULTS.keys():
		for k in VfxTransform.DEFAULTS[g].keys():
			if not saved.has(g) or not saved[g].has(k) or float(saved[g][k]) != float(VfxTransform.DEFAULTS[g][k]):
				same = false
				print("    differs: %s.%s" % [g, k])
	for v in VfxTransform.DEFAULT_BEATS.keys():
		for i in range(3):
			if int(saved["beats"][v][["gather", "break", "settle"][i]]) != int(VfxTransform.DEFAULT_BEATS[v][i]):
				same = false
				print("    differs: beats.%s.%d" % [v, i])
	for t in range(1, 5):
		for k in VfxTransform.DEFAULT_AURA[t].keys():
			if float(saved["aura"][str(t)][k]) != float(VfxTransform.DEFAULT_AURA[t][k]):
				same = false
				print("    differs: aura.%d.%s" % [t, k])
	_check(same, "data/vfx/transform.json and the built-in defaults agree")


func _tick(S: SimState, h: VfxHub, events: Array) -> void:
	S.T += SimConst.DT
	S.tick += 1
	var tk := SimState.FxEvent.new()
	tk.type = "tick"
	tk.dt = SimConst.DT
	tk.frozen = false
	var evs: Array = events.duplicate()
	evs.append(tk)
	h.consume(S, evs)
