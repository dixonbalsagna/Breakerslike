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
	# newMatch now starts every default match with two entrance craters (docs/architecture/intro-phase.md), each a crack set of its own:
	# one set a record, and only the dug crater (energy 14) has fissures to vent.
	_check(h.crack_sets.size() == S.craters.size() - 2 and S.craters.size() == 3, "one crack set a record, but the two entrance craters get none: only the dug one (%d sets, %d records)" % [h.crack_sets.size(), S.craters.size()])
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
	_check(h2.crack_sets.size() == S.craters.size() - 2 and h2.debris.jobs.is_empty(), "sets rebuilt long after their records have no vents")
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
	_aura()
	_react()
	_speed()
	_earth()
	_trails()
	_intro()
	_rocks()
	_blast()
	_pressure()
	_shots()
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


## The standing aura (docs/vfx/aura-plan.md): on while charging or attacking, eased, off otherwise.
func _aura() -> void:
	print("standing aura")
	var S := SimCore.createSim()
	SimCore.newMatch(S, 6)
	var h := VfxHub.new()
	h.reset(S, 6)
	var f = S.fighters[0]
	f.state = "free"
	f.tier = 2.0
	for k in range(30):
		_tick(S, h, [])
	_check(h.aura.level[0] == 0.0 and h.aura.level[1] == 0.0, "free fighters have no standing aura after 30 ticks")
	f.state = "charging"
	var rise: Array = []
	for k in range(12):
		_tick(S, h, [])
		rise.append(h.aura.level[0])
	_check(rise[0] > 0.0 and rise[0] < 0.5 and rise[11] == 1.0 and rise[3] > rise[1], "charging eases the aura in over %d ticks (%.2f, %.2f, %.2f ... %.2f)" % [int(VfxAura.p("standing", "ease_in_ticks")), rise[0], rise[1], rise[2], rise[11]])
	_check(h.aura.level[1] == 0.0, "only the charging fighter has it")
	f.state = "free"
	var hold: int = int(VfxAura.p("standing", "hold_ticks"))
	for k in range(hold):
		_tick(S, h, [])
	_check(h.aura.level[0] == 1.0, "it holds %d ticks after the charge ends, so it does not blink between beats" % hold)
	var fell: Array = []
	for k in range(30):
		_tick(S, h, [])
		fell.append(h.aura.level[0])
	_check(fell[0] < 1.0 and fell[29] == 0.0 and fell[10] > fell[20], "then it eases out to zero (%.2f ... %.2f)" % [fell[0], fell[29]])
	# Each attack signal turns it on.
	var ex := SimState.Exchange.new()
	ex.A = f
	ex.D = S.fighters[1]
	S.dirS.ex = ex
	for k in range(4):
		_tick(S, h, [])
	_check(h.aura.level[0] > 0.0 and h.aura.level[1] == 0.0, "being the attacker of the running exchange turns it on, being the defender does not")
	S.dirS.ex = null
	for k in range(60):
		_tick(S, h, [])
	f.beamCharge = 1.0
	for k in range(4):
		_tick(S, h, [])
	_check(h.aura.level[0] > 0.0, "a beam charge turns it on")
	f.beamCharge = null
	for k in range(60):
		_tick(S, h, [])
	var bm := SimState.Beam.new()
	bm.A = f
	S.beams.append(bm)
	for k in range(4):
		_tick(S, h, [])
	_check(h.aura.level[0] > 0.0, "a beam of its own turns it on")
	S.beams.clear()
	for k in range(60):
		_tick(S, h, [])
	f.state = "charging"
	f.hidden = true
	for k in range(6):
		_tick(S, h, [])
	_check(h.aura.level[0] == 0.0, "a hidden fighter has none")
	f.hidden = false
	# Frozen ticks hold the level; a transformation of that slot cuts it.
	for k in range(4):
		_tick(S, h, [])
	var before: float = h.aura.level[0]
	f.state = "free"
	for k in range(5):
		S.tick += 1
		var tk := SimState.FxEvent.new()
		tk.type = "tick"
		tk.dt = SimConst.DT
		tk.frozen = true
		h.consume(S, [tk])
	_check(h.aura.level[0] == before and before > 0.0, "a frozen tick holds the level (%.2f)" % before)
	f.state = "charging"
	_tick(S, h, [VfxMock.ev("transform", {"actor": 0, "tier": 3.0, "source": "ai", "dur": 3.0, "version": "full"})])
	_check(h.aura.level[0] == 0.0, "the slot's own transformation cuts it (that effect draws the aura)")
	# The real sim: over a minute of AI play the aura comes and goes, it is not constant.
	var S2 := SimCore.createSim()
	SimCore.newMatch(S2, 12345)
	var h2 := VfxHub.new()
	h2.reset(S2, 12345)
	var on_ticks: int = 0
	var off_ticks: int = 0
	var switches: int = 0
	var last_on: bool = false
	for k in range(3600):
		SimCore.step(S2)
		h2.consume(S2, S2.out.fx)
		S2.out.fx.clear()
		S2.out.feed.clear()
		var on: bool = h2.aura.level[0] > 0.5
		if on:
			on_ticks += 1
		else:
			off_ticks += 1
		if on != last_on:
			switches += 1
		last_on = on
	SimCore.dispose(S2)
	_check(on_ticks > 60 and off_ticks > 600 and switches >= 4, "in a real minute the aura is on for %d ticks and off for %d, switching %d times" % [on_ticks, off_ticks, switches])
	SimCore.dispose(S)
	var saved: Dictionary = VfxAura._data
	VfxAura._data = {}
	var fallback: bool = VfxAura.p("standing", "hold_ticks") == 18.0 and VfxAura.p("standing", "alpha") == 0.4
	VfxAura._data = saved
	_check(fallback, "missing data falls back to the defaults")
	var same: bool = true
	for k in VfxAura.DEFAULTS["standing"].keys():
		if not saved.has("standing") or not saved["standing"].has(k) or float(saved["standing"][k]) != float(VfxAura.DEFAULTS["standing"][k]):
			same = false
			print("    differs: standing.%s" % k)
	_check(same, "data/vfx/aura.json and the built-in defaults agree")


## The reactions to power (docs/vfx/react-plan.md): the flicker when worn, and from tier 3 rubble, standing cracks and windows
## blowing out; Legal's colour rule for auras.
func _react() -> void:
	print("reactions to power")
	var S := SimCore.createSim()
	SimCore.newMatch(S, 6)
	var plains: float = SimWrap.wrap(2250.0 * SimConst.PS)
	var f = S.fighters[0]
	var o = S.fighters[1]
	o.x = SimWrap.wrap(plains + 6000.0)
	o.y = WorldTerrain.groundY(S, o.x)
	var place := func(tier: float):
		f.x = plains
		f.y = WorldTerrain.groundY(S, plains)
		f.vx = 0.0
		f.vy = 0.0
		f.state = "free"
		f.hidden = false
		f.beamCharge = null
		f.tier = tier
	# Flicker: not worn, nothing; worn, dropouts; more worn, deeper; reduced motion, steady; a pure function of the tick.
	f.stage[1] = 0
	f.brink = false
	_check(VfxReact.flicker(f, 17, 0, false) == 1.0, "a fighter who is not worn has a steady aura")
	f.stage[1] = 2
	var lo_min: float = 1.0
	var dips: int = 0
	for t in range(300):
		var v: float = VfxReact.flicker(f, t, 0, false)
		lo_min = minf(lo_min, v)
		if v < 0.7:
			dips += 1
	_check(lo_min < 0.7 and dips > 20 and dips < 250, "a battered core makes the aura drop out (%d of 300 ticks, lowest %.2f)" % [dips, lo_min])
	f.stage[1] = 3
	f.brink = true
	var lo3: float = 1.0
	for t in range(300):
		lo3 = minf(lo3, VfxReact.flicker(f, t, 0, false))
	_check(lo3 < lo_min, "a broken core on the brink drops it deeper (%.2f against %.2f)" % [lo3, lo_min])
	var differ: bool = false
	for t in range(60):
		if VfxReact.flicker(f, t, 0, false) != VfxReact.flicker(f, t, 1, false):
			differ = true
	_check(VfxReact.flicker(f, 41, 0, false) == VfxReact.flicker(f, 41, 0, false) and differ, "the flicker is a pure function of the tick, and the two slots do not flicker in step")
	_check(VfxReact.flicker(f, 9, 0, true) == VfxReact.flicker(f, 10, 0, true) and VfxReact.flicker(f, 9, 0, true) < 1.0, "reduced motion: a steady dimming, no flicker (%.2f)" % VfxReact.flicker(f, 9, 0, true))
	f.stage[1] = 0
	f.brink = false
	# Rubble.
	var run_rubble := func(tier: float, ticks: int, setup: Callable) -> VfxHub:
		var h := VfxHub.new()
		h.cracks_enabled = false
		h.reset(S, 6)
		place.call(tier)
		setup.call()
		for k in range(ticks):
			_tick(S, h, [])
		return h
	var none := func(): pass
	var h2: VfxHub = run_rubble.call(2.0, 240, none)
	_check(h2.react.rubble_made == 0 and h2.debris.spawned == 0, "tier 2: no rubble, nothing at all from the world")
	var h3: VfxHub = run_rubble.call(3.0, 240, none)
	var h4: VfxHub = run_rubble.call(4.0, 240, none)
	_check(h3.react.rubble_made > 8 and h4.react.rubble_made > h3.react.rubble_made, "rubble lifts from tier 3 and more of it at tier 4 (%d, %d in 4 s)" % [h3.react.rubble_made, h4.react.rubble_made])
	var left: int = 0
	var right: int = 0
	var under: int = 0
	var rising: int = 0
	for b in h4.debris.bits:
		if b.grav < 0.0:
			var dx: float = SimWrap.sdx(plains, b.x)
			if dx < 0.0:
				left += 1
			else:
				right += 1
			if false:
				under += 1
			if b.vy > 0.0:
				rising += 1
	_check(left > 0 and right > 0 and h4.react.min_dx >= 0.25 * VfxLook.BH - 0.01 and rising > 0, "rubble is scattered on both sides, never spawned straight under him, and rising (%d left, %d right, %d rising, nearest spawn %.0f units)" % [left, right, rising, h4.react.min_dx])
	var hc: VfxHub = run_rubble.call(4.0, 240, func(): f.state = "charging")
	_check(hc.react.rubble_made == 0, "the world stands down while he charges (Legal's stacking rule)")
	var hh: VfxHub = run_rubble.call(4.0, 240, func(): f.hidden = true)
	_check(hh.react.rubble_made == 0, "nothing for a hidden fighter")
	var hs: VfxHub = run_rubble.call(4.0, 240, func(): f.y = WorldTerrain.groundY(S, plains) + 1500.0)
	_check(hs.react.rubble_made == 0, "nothing while he is high in the air")
	var hr := VfxHub.new()
	hr.reset(S, 6)
	hr.reduced_motion = true
	place.call(4.0)
	for k in range(240):
		_tick(S, hr, [])
	_check(hr.react.rubble_made < h4.react.rubble_made, "reduced motion throws less rubble (%d < %d)" % [hr.react.rubble_made, h4.react.rubble_made])
	_check(h4.debris._rubble_alive <= int(VfxReact.p("rubble", "alive_cap")), "rubble stays within its cap (%d of %d)" % [h4.debris._rubble_alive, int(VfxReact.p("rubble", "alive_cap"))])
	# Standing cracks: tier 3 or more, still, on the ground: a set spreads from his feet, stays, and fades away after he leaves.
	var hk := VfxHub.new()
	hk.cracks_enabled = true
	hk.reset(S, 6)
	place.call(3.0)
	for k in range(20):
		_tick(S, hk, [])
	_check(hk.react.stand_sets == 0, "no cracks before he has stood still for half a second")
	for k in range(30):
		_tick(S, hk, [])
	_check(hk.react.stand_sets == 1 and hk.crack_sets.any(func(cs): return cs.kind == 2 and cs.slot == 0), "standing still at tier 3 starts a web of cracks under him")
	for k in range(30):
		_tick(S, hk, [])
	_check(hk.react.level[0] > 0.99, "it fades in and stays while he stands (%.2f)" % hk.react.level[0])
	f.x = SimWrap.wrap(plains + 3000.0)
	f.y = WorldTerrain.groundY(S, f.x)
	var gone: int = -1
	for k in range(400):
		_tick(S, hk, [])
		if gone < 0 and not hk.crack_sets.any(func(cs): return cs.kind == 2):
			gone = k
	_check(gone > int(VfxReact.p("cracks", "stay_ticks")) and gone < 300, "after he walks away it stays a moment, fades and is removed (after %d ticks)" % gone)
	var hk2 := VfxHub.new()
	hk2.cracks_enabled = true
	hk2.reset(S, 6)
	place.call(2.0)
	for k in range(120):
		_tick(S, hk2, [])
	_check(hk2.react.stand_sets == 0, "no standing cracks below tier 3")
	var hk3 := VfxHub.new()
	hk3.cracks_enabled = true
	hk3.reset(S, 6)
	place.call(4.0)
	f.state = "charging"
	for k in range(120):
		_tick(S, hk3, [])
	_check(hk3.react.stand_sets == 0, "none while charging either")
	# Windows: a tier 3 or 4 fighter's big impact blows glass out of the block along it, nearest first, and publishes the list.
	var hw := VfxHub.new()
	hw.reset(S, 6)
	place.call(3.0)
	var city: float = SimWrap.wrap(2960.0 * SimConst.PS)
	var towers: Array = VfxMock.towers_near(S, city, 40000.0)
	var bt = S.buildings[towers[0]]
	var cx: float = SimWrap.wrap(bt.x - 700.0)
	var crater := func(energy: float, owner: float): return VfxMock.ev("crater", {"x": cx, "y": 0.0, "r": 200.0, "depth": 60.0, "energy": energy, "cause": "impact", "owner": owner, "special": 0.0})
	_tick(S, hw, [crater.call(18.0, 0.0)])
	_check(hw.react.blow_buildings >= 3 and hw.react.blowouts.size() >= 3, "a big impact blows the windows of the block (%d buildings listed for Rendering)" % hw.react.blow_buildings)
	var first: float = 1e30
	var last_at: float = 0.0
	for w in hw.react.blowouts:
		first = minf(first, float(w["at"]))
		last_at = maxf(last_at, float(w["at"]))
	_check(last_at > first, "the shock travels: the farther buildings go later (%.2f s spread)" % (last_at - first))
	for k in range(90):
		_tick(S, hw, [])
	_check(hw.debris.spawned > 60 and hw.debris.bits.size() <= VfxLook.DEBRIS_CAP, "the glass flies and the pool holds (%d thrown, %d live)" % [hw.debris.spawned, hw.debris.bits.size()])
	for k in range(500):
		_tick(S, hw, [])
	_check(hw.react.blowouts.is_empty(), "the list is pruned after a few seconds")
	var hw2 := VfxHub.new()
	hw2.reset(S, 6)
	place.call(2.0)
	_tick(S, hw2, [crater.call(18.0, 0.0)])
	_check(hw2.react.blow_buildings == 0, "nothing below tier 3")
	place.call(3.0)
	_tick(S, hw2, [crater.call(3.0, 0.0)])
	_check(hw2.react.blow_buildings == 0, "a small impact blows nothing")
	_tick(S, hw2, [crater.call(18.0, 1.0)])
	_check(hw2.react.blow_buildings == 0, "the owner's tier decides (the other fighter is tier 1)")
	var hw3 := VfxHub.new()
	hw3.react_enabled = false
	hw3.earth_enabled = false
	hw3.blast_enabled = false   # the blast amplification is its own flag: it would add its own debris
	hw3.reset(S, 6)
	place.call(4.0)
	for k in range(200):
		_tick(S, hw3, [crater.call(18.0, 0.0)] if k == 0 else [])
	_check(hw3.react.rubble_made == 0 and hw3.react.blow_buildings == 0 and hw3.debris.spawned == 0, "react_enabled off does nothing")
	# Legal's colour rule: no gold, white or red in an aura.
	var c_red: Color = VfxAura.lane_color("#ff5a3c")
	var c_gold: Color = VfxAura.lane_color("#ffd27a")
	var c_white: Color = VfxAura.lane_color("#ffffff")
	var c_blue: Color = VfxAura.lane_color("#8fd6ff")
	_check(c_red.to_html(false) == "9a80d8" and c_gold.to_html(false) == "9a80d8" and c_white.to_html(false) == "9a80d8", "red, gold and white auras are drawn in Art's Anti-hero violet (%s)" % c_red.to_html(false))
	_check(c_blue.to_html(false) == "8fd6ff", "a cool aura colour is kept as it is")
	# The data.
	var saved: Dictionary = VfxReact._data
	VfxReact._data = {}
	var fallback: bool = VfxReact.p("rubble", "alive_cap") == 36.0 and VfxReact.p("windows", "reach_t4") == 3200.0
	VfxReact._data = saved
	_check(fallback, "missing data falls back to the defaults")
	var same: bool = true
	for g in VfxReact.DEFAULTS.keys():
		for k in VfxReact.DEFAULTS[g].keys():
			if not saved.has(g) or not saved[g].has(k) or float(saved[g][k]) != float(VfxReact.DEFAULTS[g][k]):
				same = false
				print("    differs: %s.%s" % [g, k])
	_check(same, "data/vfx/react.json and the built-in defaults agree")
	SimCore.dispose(S)


## Speed lines alone (docs/vfx/react-plan.md): a six-tick streak on every launch and landed heavy, quiet and rationed.
func _speed() -> void:
	print("speed lines")
	var S := SimCore.createSim()
	SimCore.newMatch(S, 6)
	var f = S.fighters[0]
	var o = S.fighters[1]
	f.x = 20000.0
	f.y = 500.0
	o.x = 20400.0
	o.y = 500.0
	var heavy := func(victim: float, attacker: float): return VfxMock.ev("damage", {"x": f.x, "y": f.y + 40.0, "amount": 40.0, "col": "#ffffff", "attacker": attacker, "victim": victim, "region": "core", "kind": "heavy", "number": true})
	var h := VfxHub.new()
	h.reset(S, 6)
	_tick(S, h, [heavy.call(0.0, 1.0)])
	_check(h.speed.streaks.size() == 1 and h.speed.made == 1, "a heavy that lands starts one streak")
	var s0: VfxSpeed.Streak = h.speed.streaks[0]
	_check(s0.dx < -0.9, "it points along the blow, from the attacker (to the right) toward the hit (%.2f)" % s0.dx)
	# Its life is six ticks, through frozen ticks too.
	for k in range(5):
		S.tick += 1
		var tk := SimState.FxEvent.new()
		tk.type = "tick"
		tk.dt = SimConst.DT
		tk.frozen = true
		h.consume(S, [tk])
	_check(h.speed.streaks.size() == 1, "still playing after five ticks, hit-stop ticks included")
	_tick(S, h, [])
	_check(h.speed.streaks.is_empty(), "gone after six")
	# Other damage does not start one.
	var hl := VfxHub.new()
	hl.reset(S, 6)
	_tick(S, hl, [VfxMock.ev("damage", {"x": f.x, "y": f.y, "amount": 5.0, "col": "#fff", "attacker": 1.0, "victim": 0.0, "region": "arms", "kind": "light", "number": true})])
	_tick(S, hl, [VfxMock.ev("damage", {"x": f.x, "y": f.y, "amount": 5.0, "col": "#fff", "attacker": 1.0, "victim": 0.0, "region": "arms", "kind": "heavy", "number": false})])
	_check(hl.speed.made == 0, "a light hit, or a heavy landing with no number (a landing or collision), starts none")
	# A launch starts one along its direction; a heavy and the launch it causes are one streak.
	var hn := VfxHub.new()
	hn.reset(S, 6)
	f.vx = 3000.0
	f.vy = 900.0
	_tick(S, hn, [VfxMock.ev("launch", {"actor": 0.0, "target": 1.0, "amount": 3100.0, "face": 1.0})])
	_check(hn.speed.made == 1, "a launch starts a streak")
	var sn: VfxSpeed.Streak = hn.speed.streaks[0]
	_check(sn.dx > 0.9 and sn.dy > 0.2, "pointing along his launch (%.2f, %.2f)" % [sn.dx, sn.dy])
	var hd := VfxHub.new()
	hd.reset(S, 6)
	_tick(S, hd, [heavy.call(0.0, 1.0), VfxMock.ev("launch", {"actor": 0.0, "target": 1.0, "amount": 3100.0, "face": 1.0})])
	_check(hd.speed.made == 1 and hd.speed.skipped == 1, "a heavy that launches is one streak, not two")
	# Rationing: a gap between two, and no more than four alive.
	var hr := VfxHub.new()
	hr.reset(S, 6)
	_tick(S, hr, [heavy.call(0.0, 1.0)])
	_tick(S, hr, [heavy.call(1.0, 0.0)])
	_check(hr.speed.made == 1, "two hits two ticks apart on different fighters give one streak (the gap)")
	for k in range(5):
		_tick(S, hr, [])
	_tick(S, hr, [heavy.call(1.0, 0.0)])
	_check(hr.speed.made == 2, "and the next after the gap gives another")
	# One streak an exchange: on its launch, else its last landed heavy; none on a hit that gets a panel.
	var new_ex := func(n: int, kind: String, tag: String):
		var ex := SimState.Exchange.new()
		ex.n = n
		ex.kind = kind
		ex.tag = tag
		ex.A = S.fighters[1]
		ex.D = S.fighters[0]
		return ex
	var wait := func(hx: VfxHub, k: int):
		for i in range(k):
			_tick(S, hx, [])
	var he := VfxHub.new()
	he.reset(S, 6)
	S.dirS.ex = new_ex.call(7, "heavy", "")
	_tick(S, he, [heavy.call(0.0, 1.0)])
	wait.call(he, 3)
	f.x = 20050.0
	_tick(S, he, [VfxMock.ev("damage", {"x": f.x, "y": f.y + 40.0, "amount": 40.0, "col": "#ffffff", "attacker": 1.0, "victim": 0.0, "region": "core", "kind": "heavy", "number": true})])
	wait.call(he, 3)
	_check(he.speed.made == 0, "a heavy waits for the end of its exchange (nothing yet)")
	S.dirS.ex = null
	wait.call(he, 2)
	_check(he.speed.made == 1 and absf(he.speed.streaks[0].x - 20050.0) < 1.0, "the exchange's last landed heavy gets the one streak when it ends (x %.0f)" % (he.speed.streaks[0].x if he.speed.streaks.size() > 0 else -1.0))
	f.x = 20000.0
	var hl2 := VfxHub.new()
	hl2.reset(S, 6)
	S.dirS.ex = new_ex.call(8, "heavy", "")
	_tick(S, hl2, [heavy.call(0.0, 1.0)])
	f.vx = 3000.0
	f.vy = 500.0
	_tick(S, hl2, [VfxMock.ev("launch", {"actor": 0.0, "target": 1.0, "amount": 3100.0, "face": 1.0}), heavy.call(0.0, 1.0)])
	S.dirS.ex = null
	wait.call(hl2, 60)
	_check(hl2.speed.made == 1, "an exchange with a launch has the launch's streak and nothing else (%d)" % hl2.speed.made)
	for kind_tag in [["sig", ""], ["heavy", "RIPOSTE"]]:
		var hp := VfxHub.new()
		hp.reset(S, 6)
		S.dirS.ex = new_ex.call(9, kind_tag[0], kind_tag[1])
		_tick(S, hp, [heavy.call(0.0, 1.0)])
		_tick(S, hp, [VfxMock.ev("launch", {"actor": 0.0, "target": 1.0, "amount": 3100.0, "face": 1.0})])
		S.dirS.ex = null
		wait.call(hp, 60)
		_check(hp.speed.made == 0 and hp.speed.suppressed >= 1, "a %s exchange tagged '%s' gets a panel, so no streak (%d suppressed)" % [kind_tag[0], kind_tag[1], hp.speed.suppressed])
	for panel_ev in ["limb_break", "ko", "finisher_start"]:
		var hq2 := VfxHub.new()
		hq2.reset(S, 6)
		S.dirS.ex = new_ex.call(10, "heavy", "")
		_tick(S, hq2, [heavy.call(0.0, 1.0), VfxMock.ev(panel_ev, {"actor": 1.0, "victim": 0.0, "region": "arms", "winner": 1.0, "loser": 0.0, "target": 0.0, "dur": 2.0})])
		S.dirS.ex = null
		wait.call(hq2, 60)
		_check(hq2.speed.made == 0, "a hit with a %s event gets a panel, so no streak" % panel_ev)
	var hdc := VfxHub.new()
	hdc.reset(S, 6)
	S.dirS.ex = new_ex.call(11, "heavy", "")
	_tick(S, hdc, [heavy.call(0.0, 1.0), VfxMock.ev("decisive", {"winner": 1.0, "loser": 0.0, "kind": "clash"})])
	S.dirS.ex = null
	wait.call(hdc, 60)
	_check(hdc.speed.made == 0, "a won clash (decisive) gets a panel too")
	var hlong := VfxHub.new()
	hlong.reset(S, 6)
	S.dirS.ex = new_ex.call(12, "heavy", "")
	_tick(S, hlong, [heavy.call(0.0, 1.0)])
	wait.call(hlong, 50)
	_check(hlong.speed.made == 1, "a long exchange does not hold its heavy's streak for more than 45 ticks")
	S.dirS.ex = null
	# A riposte without a launch, and a clash that is not won, still have their heavy's streak.
	var hrp := VfxHub.new()
	hrp.reset(S, 6)
	S.dirS.ex = new_ex.call(13, "heavy", "RIPOSTE")
	_tick(S, hrp, [heavy.call(0.0, 1.0)])
	S.dirS.ex = null
	wait.call(hrp, 6)
	_check(hrp.speed.made == 1, "a riposte that does not launch has its last heavy's streak")
	var hcl := VfxHub.new()
	hcl.reset(S, 6)
	S.dirS.ex = new_ex.call(14, "heavy", "HEAVY CLASH — COUNTERED")
	_tick(S, hcl, [heavy.call(0.0, 1.0)])
	S.dirS.ex = null
	wait.call(hcl, 6)
	_check(hcl.speed.made == 1, "a clash that is not won (no decisive event) has its heavy's streak")
	# The rationing in a controlled minute: twelve scripted exchanges, 60 ticks apart, of the kinds that matter. The rule decides how many
	# streaks come out of them; how often a real fight makes such exchanges is the fight's rhythm (it changes with Encounter's work), so no
	# count from live play is asserted here (docs/vfx/react-plan.md has the measured rate).
	var hm := VfxHub.new()
	hm.reset(S, 6)
	var script_ex: Array = [
		["heavy", "", "heavy"], ["heavy", "", "heavy"], ["heavy", "", "heavy"], ["heavy", "", "heavy"],      # four heavies: four streaks
		["heavy", "", "launch"], ["heavy", "", "launch"], ["heavy", "", "launch"],                            # three launches: three streaks (the launch takes the heavy's)
		["heavy", "", "follow"], ["heavy", "", "follow"],                                                      # a launch and then a follow-up heavy: both keep their streak (Orb's flashier trading)
		["heavy", "", "two"],                                                                                   # two heavies in one exchange: one streak (the last)
		["sig", "", "heavy"], ["heavy", "RIPOSTE", "launch"],                                                  # a signature and a riposte that launches: panels, none
	]
	var n_ex: int = 100
	for sx in script_ex:
		S.dirS.ex = new_ex.call(n_ex, sx[0], sx[1])
		n_ex += 1
		f.x = 20000.0
		f.vx = 3000.0
		f.vy = 500.0
		var evs: Array = [heavy.call(0.0, 1.0)]
		if sx[2] == "launch" or sx[2] == "follow":
			evs.append(VfxMock.ev("launch", {"actor": 0.0, "target": 1.0, "amount": 3100.0, "face": 1.0}))
		_tick(S, hm, evs)
		if sx[2] == "two":
			wait.call(hm, 8)
			_tick(S, hm, [heavy.call(0.0, 1.0)])
		if sx[2] == "follow":
			wait.call(hm, 20)
			_tick(S, hm, [heavy.call(0.0, 1.0)])
		S.dirS.ex = null
		wait.call(hm, 60)
	_check(hm.speed.made == 12 and hm.speed.suppressed == 3 and hm.speed.capped == 5, "twelve scripted exchanges: %d streaks (4 heavies, 3 launches, 2 launches each with a follow-up heavy of its own, 1 of two heavies), %d hits left to panels (the signature, the riposte and its launch), %d heavies left without because they are the blow that launched" % [hm.speed.made, hm.speed.suppressed, hm.speed.capped])
	# And in real play the system fires at all, whatever the rhythm: two minutes of AI play make at least one streak.
	var S2 := SimCore.createSim()
	SimCore.newMatch(S2, 12345)
	var h2 := VfxHub.new()
	h2.reset(S2, 12345)
	for k in range(7200):
		SimCore.step(S2)
		h2.consume(S2, S2.out.fx)
		S2.out.fx.clear()
		S2.out.feed.clear()
	print("    (live, for the record: %.1f streaks a minute, %d panelled, %d second hits capped)" % [float(h2.speed.made) / 2.0, h2.speed.suppressed, h2.speed.capped])
	_check(h2.speed.made >= 1, "in two real minutes of play the speed lines fire (%d)" % h2.speed.made)
	SimCore.dispose(S2)
	# Off, and the drawing budget.
	var ho := VfxHub.new()
	ho.speedlines_enabled = false
	ho.reset(S, 6)
	_tick(S, ho, [heavy.call(0.0, 1.0)])
	_check(ho.speed.made == 0, "speedlines_enabled off starts none")
	SimCore.dispose(S)


## Earth, material and fire (docs/vfx/earth-plan.md): `debris` as tumbling chunks, `fire` as flames, the ground-contact events.
func _earth() -> void:
	print("earth, material and fire")
	var S := SimCore.createSim()
	SimCore.newMatch(S, 6)
	var plains: float = SimWrap.wrap(2250.0 * SimConst.PS)
	var g: float = WorldTerrain.groundY(S, plains)
	var deb := func(col: String, n: int): return VfxMock.ev("debris", {"x": plains, "y": g + 10.0, "n": n, "col": col, "spd": 600.0, "z": 0.0})
	# debris: chunks that tumble, in the material's colours.
	var h := VfxHub.new()
	h.reset(S, 6)
	_tick(S, h, [deb.call("#6d6a66", 12)])
	var chunks: Array = h.debris.bits.filter(func(b): return b.kind == VfxDebris.CHUNK)
	_check(chunks.size() > 6 and chunks.size() <= 12, "a debris event of 12 throws up to 12 chunks (%d)" % chunks.size())
	var spins: int = 0
	var earth_mode: int = 0
	for b in chunks:
		if absf(b.spin) > 0.5:
			spins += 1
		if b.mode == 2:
			earth_mode += 1
	_check(spins >= chunks.size() - 1 and earth_mode == chunks.size(), "they tumble (every chunk spins) and are drawn as earth (%d of %d)" % [spins, chunks.size()])
	_check(chunks[0].col.to_html(false) == VfxPalette.dust(VfxPalette.biome_key(plains), "mid").to_html(false), "grey ground debris takes the biome's own earth colour (%s)" % chunks[0].col.to_html(false))
	var hs := VfxHub.new()
	hs.reset(S, 6)
	_tick(S, hs, [deb.call("#77808f", 10)])
	var steel: Array = hs.debris.bits.filter(func(b): return b.kind == VfxDebris.CHUNK)
	_check(steel.size() > 0 and steel[0].mode == 0 and steel[0].col.to_html(false) == VfxPalette.steel("mid").to_html(false), "a tower's debris is steel and concrete, drawn with the shared rim")
	var hw := VfxHub.new()
	hw.reset(S, 6)
	_tick(S, hw, [deb.call("#8a6a4a", 10)])
	var wood: Array = hw.debris.bits.filter(func(b): return b.kind == VfxDebris.CHUNK)
	_check(wood.size() > 0 and wood[0].col.to_html(false) == "8a6a4a", "a house's debris keeps its wood colour")
	var hb := VfxHub.new()
	hb.reset(S, 6)
	for k in range(60):
		_tick(S, hb, [deb.call("#6d6a66", 14)])
	_check(hb.debris.bits.size() <= VfxLook.DEBRIS_CAP, "the pool holds under a flood of debris (%d)" % hb.debris.bits.size())
	var hq := VfxHub.new()
	hq.quality = VfxLook.Q_LOW
	hq.reset(S, 6)
	hq.quality = VfxLook.Q_LOW
	_tick(S, hq, [deb.call("#6d6a66", 14)])
	_check(hq.earth.deb_made < 8, "low quality throws fewer (%d)" % hq.earth.deb_made)
	# The reference consumer is not given what this hub draws.
	var evs: Array = [deb.call("#6d6a66", 3), VfxMock.ev("fire", {"x": plains, "y": g, "n": 2, "z": 0.0}), VfxMock.ev("dust", {"x": plains, "y": g, "n": 2, "col": "", "z": 0.0}), VfxMock.ev("splash", {"x": plains, "y": g, "n": 4, "z": 0.0})]
	var ref: Array = h.reference_events(evs)
	_check(ref.size() == 1 and ref[0].type == "splash", "reference_events leaves the reference consumer only what this hub does not draw (%d of 4)" % ref.size())
	var hoff := VfxHub.new()
	hoff.earth_enabled = false
	hoff.reset(S, 6)
	_check(hoff.reference_events(evs).size() == 4, "with the effects off it returns every event")
	_tick(S, hoff, [deb.call("#6d6a66", 12)])
	_check(hoff.debris.spawned == 0, "earth_enabled off throws nothing")
	# A building that fell this tick: its debris is the fall's, not these.
	var hf := VfxHub.new()
	hf.destruction_enabled = true
	hf.reset(S, 6)
	var bi: int = 0
	var bb = S.buildings[bi]
	var bx: float = bb.x
	var fall := VfxMock.building_fall(S, bi, "burst", 0.0, bx)
	var bd := VfxMock.ev("debris", {"x": bx, "y": g + 10.0, "n": 12, "col": "#77808f", "spd": 600.0, "z": 0.0})
	var made0: int = hf.earth.deb_made
	_tick(S, hf, [fall, bd])
	_check(hf.earth.deb_made == made0, "debris at a building that fell in the tick is left to the fall's own effect")
	# Dust: scalloped puffs in the biome's colours, or the colour the event names when it is not grey.
	var hd := VfxHub.new()
	hd.reset(S, 6)
	_tick(S, hd, [VfxMock.ev("dust", {"x": plains, "y": g, "n": 5, "col": "#9b8f7e", "z": 0.0})])
	var dp: Array = hd.debris.bits.filter(func(b): return b.kind == VfxDebris.PUFF)
	var biome_mid: String = VfxPalette.dust(VfxPalette.biome_key(plains), "mid").to_html(false)
	var biome_cols: Array = [VfxPalette.dust(VfxPalette.biome_key(plains), "mid").to_html(false), VfxPalette.dust(VfxPalette.biome_key(plains), "shadow").to_html(false), VfxPalette.dust(VfxPalette.biome_key(plains), "light").to_html(false)]
	var all_biome: bool = dp.size() > 2
	for b in dp:
		if not biome_cols.has(b.col.to_html(false)):
			all_biome = false
	_check(all_biome, "a dust event throws puffs in the biome's own dust colours (%d puffs, %s)" % [dp.size(), biome_mid])
	var hg := VfxHub.new()
	hg.reset(S, 6)
	_tick(S, hg, [VfxMock.ev("dust", {"x": plains, "y": g, "n": 5, "col": "#e6c47a", "z": 0.0})])
	var gp: Array = hg.debris.bits.filter(func(b): return b.kind == VfxDebris.PUFF)
	_check(gp.size() > 2 and gp[0].col.to_html(false) in ["e6c47a", "b8a362", "ffd68f", "ecc882"] or (gp.size() > 2 and absf(gp[0].col.h - Color("#e6c47a").h) < 0.03), "a coloured dust event (a glass trench) keeps its own hue")
	# Fire: cel flames with a cap, and smoke only when not reduced.
	var hr := VfxHub.new()
	hr.reset(S, 6)
	for k in range(30):
		_tick(S, hr, [VfxMock.ev("fire", {"x": plains, "y": g, "n": 6, "z": 0.0})])
	_check(hr.earth.flames_made > 20 and hr.debris._flame_alive <= int(VfxEarth.p("flame", "alive_cap")), "fire events throw flames, within the cap (%d made, %d alive of %d)" % [hr.earth.flames_made, hr.debris._flame_alive, int(VfxEarth.p("flame", "alive_cap"))])
	var smokes: int = hr.debris.bits.filter(func(b): return b.kind == VfxDebris.PUFF).size()
	_check(smokes > 0, "with a little smoke (%d puffs)" % smokes)
	var hrr := VfxHub.new()
	hrr.reset(S, 6)
	hrr.reduced_motion = true
	for k in range(30):
		_tick(S, hrr, [VfxMock.ev("fire", {"x": plains, "y": g, "n": 6, "z": 0.0})])
	_check(hrr.debris.bits.filter(func(b): return b.kind == VfxDebris.PUFF).size() == 0 and hrr.earth.flames_made < hr.earth.flames_made, "reduced motion: fewer flames and no smoke (%d)" % hrr.earth.flames_made)
	# Ground contact events.
	var contact := func(type: String, d: Dictionary): return VfxMock.ev(type, d)
	var land := func(kind: String, surface: String, spd: float): return VfxMock.ev("land", {"actor": 0.0, "x": plains, "y": g, "z": 0.0, "spd": spd, "n": 1, "surface": surface, "kind": kind, "vn": -spd * 0.8, "vt": spd * 0.3, "sina": 0.9, "slope": 0.0, "contacts": 1, "dur": 0.1})
	S.fighters[0].vx = 2000.0
	var counts: Dictionary = {}
	for surf in ["soil", "sand", "paving"]:
		var hc := VfxHub.new()
		hc.reset(S, 6)
		_tick(S, hc, [land.call("slam", surf, 3500.0)])
		var ch: int = hc.debris.bits.filter(func(b): return b.kind == VfxDebris.CHUNK).size()
		var pf: int = hc.debris.bits.filter(func(b): return b.kind == VfxDebris.PUFF).size()
		counts[surf] = [ch, pf]
	_check(counts["soil"][0] > 6 and counts["soil"][1] > 3, "a slam throws clods and dust (%d chunks, %d puffs on soil)" % [counts["soil"][0], counts["soil"][1]])
	_check(counts["sand"][0] < counts["soil"][0] and counts["sand"][1] > counts["soil"][1], "sand throws fewer chunks and more dust (%d, %d against %d, %d)" % [counts["sand"][0], counts["sand"][1], counts["soil"][0], counts["soil"][1]])
	_check(counts["paving"][0] >= counts["soil"][0], "paving throws sharper, more chunks (%d)" % counts["paving"][0])
	var hsmall := VfxHub.new()
	hsmall.reset(S, 6)
	_tick(S, hsmall, [land.call("slam", "soil", 800.0)])
	var hbig := VfxHub.new()
	hbig.reset(S, 6)
	_tick(S, hbig, [land.call("slam", "soil", 5000.0)])
	_check(hbig.earth.contact_made > hsmall.earth.contact_made, "a faster landing throws more (%d against %d)" % [hbig.earth.contact_made, hsmall.earth.contact_made])
	var hk := VfxHub.new()
	hk.reset(S, 6)
	_tick(S, hk, [land.call("skid", "soil", 3000.0)])
	var thrown_back: bool = false
	for b in hk.debris.bits:
		if b.kind == VfxDebris.CHUNK and b.vx < 0.0:
			thrown_back = true
	_check(thrown_back, "a skid throws its surface back along the way he came")
	# Water is the skip's, not these.
	var sea: float = 0.0
	while sea < SimConst.W:
		var wet: bool = true
		for k in range(-3, 4):
			if WorldWater.surfaceAt(S, SimWrap.wrap(sea + float(k) * 1500.0)) == WorldWater.DRY:
				wet = false
				break
		if wet:
			break
		sea += 1500.0
	var hwtr := VfxHub.new()
	hwtr.reset(S, 6)
	_tick(S, hwtr, [VfxMock.ev("bounce", {"actor": 0.0, "x": sea, "y": 0.0, "z": 0.0, "spd": 3000.0, "surface": "water", "k": 1.0, "vn": -2000.0}), VfxMock.ev("left_ground", {"actor": 0.0, "x": sea, "y": 0.0, "z": 0.0, "spd": 3000.0, "cause": "bounce", "vx": 2500.0, "vy": 800.0})])
	_check(hwtr.earth.contact_made == 0, "a bounce and a leave over water throw no earth")
	# Bounce, leaving from a lip, settling.
	var hbo := VfxHub.new()
	hbo.reset(S, 6)
	_tick(S, hbo, [VfxMock.ev("bounce", {"actor": 0.0, "x": plains, "y": g, "z": 0.0, "spd": 2600.0, "surface": "soil", "k": 1.0, "vn": -1800.0, "keep": 0.45})])
	_check(hbo.earth.contact_made > 2, "a bounce throws clods and dust (%d)" % hbo.earth.contact_made)
	var hl := VfxHub.new()
	hl.reset(S, 6)
	_tick(S, hl, [VfxMock.ev("left_ground", {"actor": 0.0, "x": plains, "y": g, "z": 0.0, "spd": 3000.0, "cause": "lip", "vx": 2500.0, "vy": 1500.0, "slope": 0.4})])
	var forward: int = 0
	var up: int = 0
	for b in hl.debris.bits:
		if b.kind == VfxDebris.CHUNK:
			if b.vx > 0.0:
				forward += 1
			if b.vy > 0.0:
				up += 1
	_check(forward >= 3 and up >= 3, "leaving a lip throws chunks along his leaving vector, forward and up (%d, %d)" % [forward, up])
	var hcr := VfxHub.new()
	hcr.reset(S, 6)
	_tick(S, hcr, [VfxMock.ev("left_ground", {"actor": 0.0, "x": plains, "y": g, "z": 0.0, "spd": 3000.0, "cause": "crest", "vx": 2500.0, "vy": 300.0, "slope": 0.1})])
	_check(hcr.debris.bits.filter(func(b): return b.kind == VfxDebris.CHUNK).size() == 0, "leaving a crest throws only dust")
	var hte := VfxHub.new()
	hte.reset(S, 6)
	_tick(S, hte, [VfxMock.ev("tumble_end", {"actor": 0.0, "x": plains, "y": g, "z": 0.0, "spd": 200.0, "kind": "air"})])
	_check(hte.earth.contact_made == 0, "a tumble that ends in the air (water) throws nothing")
	_tick(S, hte, [VfxMock.ev("tumble_end", {"actor": 0.0, "x": plains, "y": g, "z": 0.0, "spd": 200.0, "kind": "stop"}), VfxMock.ev("journey_end", {"actor": 0.0, "x": plains, "y": g, "z": 0.0, "spd": 100.0, "kind": "stop"})])
	_check(hte.earth.contact_made > 0, "a tumble and a journey that stop leave a settling cloud (%d)" % hte.earth.contact_made)
	var hwl := VfxHub.new()
	hwl.reset(S, 6)
	_tick(S, hwl, [VfxMock.ev("journey_end", {"actor": 0.0, "x": plains, "y": g, "z": 0.0, "spd": 1500.0, "kind": "wall"})])
	_check(hwl.debris.bits.filter(func(b): return b.kind == VfxDebris.CHUNK).size() > 3, "a journey that ends at a wall bursts chunks")
	# A flood of contact events keeps the pool bounded.
	var hfl := VfxHub.new()
	hfl.reset(S, 6)
	for k in range(120):
		_tick(S, hfl, [land.call("slam", "soil", 5000.0), VfxMock.ev("bounce", {"actor": 0.0, "x": plains, "y": g, "z": 0.0, "spd": 4000.0, "surface": "soil", "k": 1.0, "vn": -3000.0, "keep": 0.4})])
	_check(hfl.debris.bits.size() <= VfxLook.DEBRIS_CAP, "the pool holds under a flood of contact events (%d)" % hfl.debris.bits.size())
	# A crater's ejecta and the slide's end, which ImpactFx drew as squares.
	var hcr2 := VfxHub.new()
	hcr2.reset(S, 6)
	_tick(S, hcr2, [VfxMock.ev("crater", {"x": plains, "y": g, "r": 220.0, "depth": 60.0, "energy": 14.0, "cause": "impact", "owner": 1.0, "special": 0.0, "rim": 20.0, "z": 0.0})])
	var ej: int = hcr2.debris.bits.filter(func(b): return b.kind == VfxDebris.CHUNK).size()
	var ejd: int = hcr2.debris.bits.filter(func(b): return b.kind == VfxDebris.PUFF).size()
	_check(ej >= 12 and ejd >= 8, "a crater throws its ejecta as tumbling chunks and lifts dust off the rim (%d chunks, %d puffs)" % [ej, ejd])
	var hcr3 := VfxHub.new()
	hcr3.reset(S, 6)
	_tick(S, hcr3, [VfxMock.ev("crater", {"x": plains, "y": g, "r": 100.0, "depth": 20.0, "energy": 1.0, "cause": "impact", "owner": 1.0, "special": 0.0, "rim": 5.0, "z": 0.0})])
	_check(hcr3.debris.bits.filter(func(b): return b.kind == VfxDebris.CHUNK).size() < ej, "a small impact throws less")
	var hsd := VfxHub.new()
	hsd.reset(S, 6)
	_tick(S, hsd, [VfxMock.ev("slide", {"x": plains, "x1": plains + 900.0, "w": 120.0, "energy": 8.0, "variant": "ground", "z1": 0.0})])
	_check(hsd.debris.bits.size() > 6, "where a slide stops, a burst of dust and chunks off the berm (%d)" % hsd.debris.bits.size())
	# The skid itself: a body sliding on the ground throws spray, more the faster; none when slow, in the air or at sea.
	var hsk := VfxHub.new()
	hsk.reset(S, 6)
	var f0 = S.fighters[0]
	f0.x = plains
	f0.y = g
	f0.vx = 4000.0
	f0.state = "launched"
	f0.slide = 4000.0
	for k in range(60):
		_tick(S, hsk, [])
	var fast: int = hsk.earth.contact_made
	var hsl := VfxHub.new()
	hsl.reset(S, 6)
	f0.slide = 700.0
	for k in range(60):
		_tick(S, hsl, [])
	var slow: int = hsl.earth.contact_made
	f0.slide = 100.0
	var hsn := VfxHub.new()
	hsn.reset(S, 6)
	for k in range(60):
		_tick(S, hsn, [])
	_check(fast > 10 and fast > slow and slow > 0 and hsn.earth.contact_made == 0, "a sliding body sprays his surface back, more when fast, none when nearly stopped (%d, %d, %d)" % [fast, slow, hsn.earth.contact_made])
	f0.slide = 0.0
	f0.state = "free"
	# Real ground-contact events, when World's switch is on in the data (a scratch copy has it on; HEAD has it off).
	var on: bool = FileAccess.get_file_as_string("res://data/biomes/contact.json").find("\"enabled\": true") >= 0
	if on:
		var S2 := SimCore.createSim()
		SimCore.newMatch(S2, 12345)
		var h2 := VfxHub.new()
		h2.reset(S2, 12345)
		var f2 = S2.fighters[0]
		for k in range(1800):
			if k % 200 == 20:
				f2.x = SimWrap.wrap(2250.0 * SimConst.PS)
				f2.y = WorldTerrain.groundY(S2, f2.x) + 900.0
				f2.vx = 3500.0
				f2.vy = -2600.0
				f2.state = "launched"
				f2.launchT = 1.0
				f2.stateT = 0.0
			SimCore.step(S2)
			h2.consume(S2, S2.out.fx)
			S2.out.fx.clear()
			S2.out.feed.clear()
		_check(h2.earth.contact_events > 3 and h2.earth.contact_made > 20, "real ground-contact events (data/biomes/contact.json enabled): %d events handled, %d chunks and puffs thrown" % [h2.earth.contact_events, h2.earth.contact_made])
		SimCore.dispose(S2)
	else:
		print("  skip real ground-contact events: data/biomes/contact.json is off in this copy")
	# The data.
	var saved: Dictionary = VfxEarth._data
	VfxEarth._data = {}
	var fallback: bool = VfxEarth.p("deb", "max_per_event") == 14.0 and VfxEarth.p("flame", "alive_cap") == 40.0
	VfxEarth._data = saved
	_check(fallback, "missing data falls back to the defaults")
	var same: bool = true
	for gk in VfxEarth.DEFAULTS.keys():
		for k in VfxEarth.DEFAULTS[gk].keys():
			if not saved.has(gk) or not saved[gk].has(k) or float(saved[gk][k]) != float(VfxEarth.DEFAULTS[gk][k]):
				same = false
				print("    differs: %s.%s" % [gk, k])
	_check(same, "data/vfx/earth.json and the built-in defaults agree")
	SimCore.dispose(S)


## Trails across contacts (the sim's land, bounce and journey_end): the path breaks at each contact, a trail on the ground fades fast,
## and a ribbon is thin and pale enough to read as a trail.
func _trails() -> void:
	print("trails across contacts")
	var S := SimCore.createSim()
	SimCore.newMatch(S, 6)
	var f = S.fighters[0]
	var plains: float = SimWrap.wrap(2250.0 * SimConst.PS)
	var g: float = WorldTerrain.groundY(S, plains)
	_check(VfxLook.W_OUTER_BH <= 0.4 and VfxLook.A_OUTER <= 0.4, "the outer band is thin and pale (width %.2f bh, alpha %.2f), so a ribbon reads as a trail and not a solid shape" % [VfxLook.W_OUTER_BH, VfxLook.A_OUTER])
	# A dive and a landing: a ribbon with the whole dive in its history, then the contact cuts it.
	var rg := SimRng.new(5)
	var ts := VfxTrailState.new()
	f.state = "launched"
	f.hidden = false
	f.rush = null
	f.slide = 0.0
	f.z = 0.0
	for k in range(16):
		f.x = SimWrap.wrap(plains - 1500.0 + 150.0 * float(k))
		f.y = g + 1500.0 - 90.0 * float(k)
		ts.step(S, f, SimConst.DT, rg, VfxLook.Q_HIGH, true)
	_check(ts.hx.size() == 16 and ts.k > 0.5, "a fast dive has a long history and a strong trail (%d points, k %.2f)" % [ts.hx.size(), ts.k])
	var before: PackedVector3Array = ts.ribbon(f.x, f.y + VfxLook.CHEST_Y, 0.0, 1500.0, VfxLook.SEGS)
	var span_before: float = before[before.size() - 1].distance_to(before[0])
	ts.cut()
	_check(ts.hx.size() == 1 and ts.cuts == 1, "a contact keeps one point of the path")
	f.y = g + 10.0
	f.state = "launched"
	f.slide = 3000.0
	for k in range(4):
		ts.step(S, f, SimConst.DT, rg, VfxLook.Q_HIGH, true)
	var after: PackedVector3Array = ts.ribbon(f.x, f.y + VfxLook.CHEST_Y, 0.0, 1500.0, VfxLook.SEGS)
	var span_after: float = 0.0
	if after.size() > 1:
		span_after = after[after.size() - 1].distance_to(after[0])
	_check(span_after < 0.2 * span_before, "the ribbon after the landing starts at the contact and is a short taper to the fighter, not the dive's arc (%.0f against %.0f units)" % [span_after, span_before])
	var all_near: bool = true
	for p in after:
		if absf(p.x) > 200.0:
			all_near = false
	_check(all_near, "and it ends at the fighter: every point of it is within 200 units of the head")
	# On the ground the trail fades fast; in the air it does not.
	var tg := VfxTrailState.new()
	var ta := VfxTrailState.new()
	var rg2 := SimRng.new(6)
	f.slide = 0.0
	for k in range(20):
		f.x = SimWrap.wrap(plains + 160.0 * float(k))
		f.y = g + 2000.0
		ta.step(S, f, SimConst.DT, rg2, VfxLook.Q_HIGH, true)
	for k in range(20):
		f.x = SimWrap.wrap(plains + 160.0 * float(k))
		f.y = g + 8.0
		f.slide = 6000.0
		tg.step(S, f, SimConst.DT, rg2, VfxLook.Q_HIGH, true)
	var k_air_start: float = ta.k
	var k_gnd_start: float = tg.k
	f.slide = 300.0
	for k in range(8):
		f.x = SimWrap.wrap(plains + 3200.0 + 4.0 * float(k))
		f.y = g + 8.0
		tg.step(S, f, SimConst.DT, rg2, VfxLook.Q_HIGH, true)
	for k in range(8):
		f.x = SimWrap.wrap(plains + 3200.0 + 4.0 * float(k))
		f.y = g + 2000.0
		f.slide = 0.0
		ta.step(S, f, SimConst.DT, rg2, VfxLook.Q_HIGH, true)
	_check(tg.grounded and tg.k < 0.35 * maxf(k_gnd_start, 0.01) and ta.k > 0.4 * maxf(k_air_start, 0.01), "after eight ticks of slowing, a trail on the ground has faded (k %.2f from %.2f) and one in the air has not (%.2f from %.2f)" % [tg.k, k_gnd_start, ta.k, k_air_start])
	# The hub cuts a fighter's trail on land, bounce and journey_end, and on nothing else.
	var h := VfxHub.new()
	h.reset(S, 6)
	_tick(S, h, [])
	_tick(S, h, [])
	_tick(S, h, [])
	var c0: int = h.trails[0].cuts
	_tick(S, h, [VfxMock.ev("land", {"actor": 0.0, "x": plains, "y": g, "z": 0.0, "spd": 3000.0, "surface": "soil", "kind": "slam"})])
	_tick(S, h, [VfxMock.ev("bounce", {"actor": 0.0, "x": plains, "y": g, "z": 0.0, "spd": 3000.0, "surface": "soil", "k": 1.0, "vn": -2000.0})])
	_tick(S, h, [VfxMock.ev("journey_end", {"actor": 0.0, "x": plains, "y": g, "z": 0.0, "spd": 100.0, "kind": "stop"})])
	_check(h.trails[0].cuts == c0 + 3 and h.trails[1].cuts == 0, "land, bounce and journey_end each break the landing fighter's trail, and only his (%d)" % (h.trails[0].cuts - c0))
	_tick(S, h, [VfxMock.ev("left_ground", {"actor": 0.0, "x": plains, "y": g, "z": 0.0, "spd": 3000.0, "cause": "lip", "vx": 2000.0, "vy": 900.0})])
	_check(h.trails[0].cuts == c0 + 3, "leaving the ground does not (the flight after it is the new trail)")
	SimCore.dispose(S)


## The intro (docs/architecture/intro-phase.md): the entrance craters, the effects clock through the pre-clock ticks, the landing's dust and
## the last stand's mark.
func _intro() -> void:
	print("intro and last stand")
	var S := SimCore.createSim()
	SimCore.newMatch(S, 6)
	var plains: float = SimWrap.wrap(2250.0 * SimConst.PS)
	# The default match starts from the intro's end state: two entrance craters, drawn grown from the first frame (they spread at
	# a landing, not at the clock).
	var h := VfxHub.new()
	h.cracks_enabled = true
	h.reset(S, 6)
	_tick(S, h, [])
	_check(S.craters.size() == 2 and h.crack_sets.is_empty() and h.debris.jobs.is_empty(), "a default match has two entrance craters and no crack set for them: their fine cracks read as dark dashes at the side-on camera (%d craters, %d sets)" % [S.craters.size(), h.crack_sets.size()])
	# The effects clock runs through the intro's pre-clock ticks while the sim clock stands still.
	S.intro.t = 90
	_check(absf(h.fx_now(S) - (S.T + 1.5)) < 1e-6, "the effects clock is the sim's time plus the intro's ticks (%.2f s at 90 ticks)" % h.fx_now(S))
	S.intro.t = 0
	# A played intro: the landing's dust, only when the fall was seen (a skipped intro throws nothing).
	var land := func(actor: float): return VfxMock.ev("entrance_land", {"actor": actor, "x": plains, "y": WorldTerrain.groundY(S, plains), "z": 0.0, "y1": WorldTerrain.groundY(S, plains) + 6000.0, "r": 196.0})
	var hf := VfxHub.new()
	hf.reset(S, 6)
	_tick(S, hf, [VfxMock.ev("entrance_fall", {"actor": 0.0, "x": plains, "y": 0.0, "z": 0.0, "y1": 6000.0, "dur": 0.6})])
	_tick(S, hf, [land.call(0.0)])
	var chunks: int = hf.debris.bits.filter(func(b): return b.kind == VfxDebris.CHUNK).size()
	var puffs: int = hf.debris.bits.filter(func(b): return b.kind == VfxDebris.PUFF).size()
	var rings: int = hf.debris.bits.filter(func(b): return b.kind == VfxDebris.RING).size()
	_check(chunks >= 8 and puffs >= 10 and rings == 1, "an entrance landing throws clods, a skirt and column of dust and one ring (%d chunks, %d puffs, %d ring)" % [chunks, puffs, rings])
	var hs := VfxHub.new()
	hs.reset(S, 6)
	_tick(S, hs, [land.call(0.0)])
	_check(hs.earth.contact_events == 0 and hs.debris.bits.size() == 0, "a landing with no fall before it (the skipped intro) throws nothing")
	var hr := VfxHub.new()
	hr.reduced_motion = true
	hr.reset(S, 6)
	hr.reduced_motion = true
	_tick(S, hr, [VfxMock.ev("entrance_fall", {"actor": 0.0, "x": plains, "y": 0.0, "z": 0.0, "y1": 6000.0, "dur": 0.6})])
	_tick(S, hr, [land.call(0.0)])
	_check(hr.debris.bits.filter(func(b): return b.kind == VfxDebris.RING).size() == 0 and hr.earth.contact_made < hf.earth.contact_made, "reduced motion: fewer pieces and no ring (%d against %d)" % [hr.earth.contact_made, hf.earth.contact_made])
	# The landing is quiet and short so the staredown reads: dust gone in under 1.5 s, low, and one ring that lies on the ground near
	# the crater; the crater's own ejecta of that tick is as short.
	var hq := VfxHub.new()
	hq.reset(S, 6)
	_tick(S, hq, [VfxMock.ev("entrance_fall", {"actor": 0.0, "x": plains, "y": 0.0, "z": 0.0, "y1": 6000.0, "dur": 0.6})])
	var gy: float = WorldTerrain.groundY(S, plains)
	_tick(S, hq, [VfxMock.ev("crater", {"x": plains, "y": gy, "r": 196.0, "depth": 50.0, "energy": 1.5, "cause": "impact", "owner": -1.0, "special": 0.0, "rim": 10.0, "z": 0.0}), land.call(0.0)])
	var longest: float = 0.0
	var highest: float = 0.0
	for b in hq.debris.bits:
		if b.kind == VfxDebris.PUFF:
			longest = maxf(longest, b.life)
			highest = maxf(highest, b.vy)
	_check(longest <= 1.5 and highest <= 260.0, "the landing's dust lives at most %.2f s (limit 1.5) and rises at most %.0f u/s" % [longest, highest])
	var ring = null
	for b in hq.debris.bits:
		if b.kind == VfxDebris.RING:
			ring = b
	_check(ring != null and ring.mode == 3 and ring.sx * 0.5 + ring.grow * 0.5 * ring.life < 2.5 * 196.0, "the ring is a ground ring (flat) and ends within 2.5 crater radii (%.0f of %.0f)" % [(ring.sx * 0.5 + ring.grow * 0.5 * ring.life) if ring != null else -1.0, 2.5 * 196.0])
	var gone_by: int = -1
	for k in range(200):
		_tick(S, hq, [])
		if gone_by < 0 and hq.debris.bits.filter(func(b): return b.kind == VfxDebris.PUFF or b.kind == VfxDebris.CHUNK).is_empty():
			gone_by = k
	_check(gone_by >= 0 and gone_by < 100, "every puff and chunk of the landing has cleared within 100 ticks (%d)" % gone_by)
	# The entrance craters have no crack set, played or skipped.
	var hc := VfxHub.new()
	hc.cracks_enabled = true
	hc.reset(S, 6)
	S.intro.t = 36
	_tick(S, hc, [VfxMock.ev("entrance_fall", {"actor": 0.0, "x": plains, "y": 0.0, "z": 0.0, "y1": 6000.0, "dur": 0.6})])
	S.intro.t = 0
	_check(hc.crack_sets.is_empty(), "no crack set for an entrance crater of a played intro either")
	# A chunk that has come to rest fades within 0.3 s (it must not lie on the sand as a dark dash); a falling one is not touched.
	var hcf := VfxHub.new()
	hcf.reset(S, 6)
	_tick(S, hcf, [])
	hcf.debris.chunk(plains, gy + 2.0, 0.0, 0.0, -50.0, 12.0, 2.0, [Color.GRAY, Color.WHITE, Color.BLACK], 2, 0.0)
	for k in range(120):
		_tick(S, hcf, [])
	var left_t: float = -1.0
	for b in hcf.debris.bits:
		if b.kind == VfxDebris.CHUNK:
			left_t = b.life - b.age
	_check(left_t < 0.0 or left_t <= 0.31, "an earth chunk at rest has at most 0.3 s left (%.2f)" % left_t)
	# The trail's break ring is for flight, not for the scripted entrance fall.
	var tf := VfxTrailState.new()
	var rgi := SimRng.new(8)
	S.fighters[0].state = "intro"
	for k in range(30):
		S.fighters[0].x = plains
		S.fighters[0].y = gy + 6000.0 - 200.0 * float(k)
		tf.step(S, S.fighters[0], SimConst.DT, rgi, VfxLook.Q_HIGH, false)
	_check(tf.rings == 0 and tf.max_k > 0.5, "a fighter in the intro's fall has his trail but no break ring (%d rings, k %.2f)" % [tf.rings, tf.max_k])
	S.fighters[0].state = "free"
	# Jobs run through the intro: the sim clock stands still, the effects clock does not.
	var hj := VfxHub.new()
	hj.reset(S, 6)
	S.T = 0.0
	hj.debris.vent(hj.fx_now(S) + 0.1, plains, 0.0, 100.0)
	for k in range(10):
		S.intro.t += 1
		_tick_still(S, hj)
	_check(hj.debris.jobs.is_empty() and hj.debris.spawned > 0, "a job scheduled in the intro runs while S.T stands still (%d bits)" % hj.debris.spawned)
	S.intro.t = 0
	# The last stand's mark.
	var hm := VfxHub.new()
	hm.reset(S, 6)
	_tick(S, hm, [VfxMock.ev("last_stand_ready", {"actor": 1.0, "dur": 0.5})])
	for k in range(12):
		_tick(S, hm, [])
	_check(hm.aura.mark_lvl[1] > 0.99 and hm.aura.mark_lvl[0] == 0.0, "the ring comes up on the fighter who reached the brink (%.2f), and only on him" % hm.aura.mark_lvl[1])
	var lvl_now: float = hm.aura.mark_lvl[1]
	var left_now: int = hm.aura.mark_left[1]
	for k in range(5):
		S.tick += 1
		var tk := SimState.FxEvent.new()
		tk.type = "tick"
		tk.dt = SimConst.DT
		tk.frozen = true
		hm.consume(S, [tk])
	_check(hm.aura.mark_left[1] == left_now and hm.aura.mark_lvl[1] == lvl_now, "the window counts his free time: it holds on frozen ticks")
	for k in range(40):
		_tick(S, hm, [])
	_check(hm.aura.mark_left[1] == 0 and hm.aura.mark_lvl[1] < 0.5, "it fades when the window expires on its own (%.2f)" % hm.aura.mark_lvl[1])
	var hu := VfxHub.new()
	hu.reset(S, 6)
	_tick(S, hu, [VfxMock.ev("last_stand_ready", {"actor": 0.0, "dur": 20.0})])
	for k in range(12):
		_tick(S, hu, [])
	_tick(S, hu, [VfxMock.ev("last_stand_end", {"actor": 0.0, "kind": "used"})])
	_check(hu.aura.mark_burst[0] > 0 and hu.aura.mark_left[0] == 0, "when it is used, one ring leaves him (%d ticks)" % hu.aura.mark_burst[0])
	var hx := VfxHub.new()
	hx.reset(S, 6)
	_tick(S, hx, [VfxMock.ev("last_stand_ready", {"actor": 5.0, "dur": 1.0}), VfxMock.ev("last_stand_end", {"actor": -1.0, "kind": "used"})])
	_check(hx.aura.marks_made == 0, "an actor out of range is ignored")
	var hz := VfxHub.new()
	hz.standing_aura_enabled = false
	hz.reset(S, 6)
	_tick(S, hz, [VfxMock.ev("last_stand_ready", {"actor": 0.0, "dur": 2.0})])
	_check(hz.aura.marks_made == 0, "with the aura effects off there is no mark")
	SimCore.dispose(S)


## A tick of the hub with nothing in it that the sim clock does not advance for (an intro tick): effects run, S.T stays.
func _tick_still(S: SimState, h: VfxHub) -> void:
	var tk := SimState.FxEvent.new()
	tk.type = "tick"
	tk.dt = SimConst.DT
	tk.frozen = false
	h.consume(S, [tk])


## Levitating rocks (a prototype behind `rocks_enabled`; docs/vfx/power-language.md idea 1).
func _rocks() -> void:
	print("levitating rocks")
	var S := SimCore.createSim()
	SimCore.newMatch(S, 6)
	var plains: float = SimWrap.wrap(2250.0 * SimConst.PS)
	var g: float = WorldTerrain.groundY(S, plains)
	var f = S.fighters[0]
	var o = S.fighters[1]
	o.x = SimWrap.wrap(plains + 6000.0)
	o.y = WorldTerrain.groundY(S, o.x)
	var place := func(tier: float):
		f.x = plains
		f.y = g
		f.vx = 0.0
		f.vy = 0.0
		f.state = "free"
		f.hidden = false
		f.beamCharge = null
		f.tier = tier
	_check(VfxRocks.count_for(2, 1.0) == 0 and VfxRocks.count_for(3, 1.0) == 5 and VfxRocks.count_for(4, 1.0) == 10, "no rocks below tier 3, 5 at tier 3, 10 at tier 4")
	_check(VfxRocks.count_for(4, 0.35) < VfxRocks.count_for(4, 1.0) and VfxRocks.count_for(4, 1.0) <= VfxRocks.MAX_PIECES, "fewer at low quality, never past the pool of %d" % VfxRocks.MAX_PIECES)
	var run := func(tier: float, ticks: int, setup: Callable) -> VfxHub:
		var h := VfxHub.new()
		h.rocks_enabled = true
		h.reset(S, 6)
		place.call(tier)
		setup.call()
		for k in range(ticks):
			_tick(S, h, [])
		return h
	var none := func(): pass
	var h2: VfxHub = run.call(2.0, 90, none)
	var h3: VfxHub = run.call(3.0, 90, none)
	_check(h2.rocks.level[0] == 0.0 and h3.rocks.level[0] > 0.99 and h3.rocks.level[1] == 0.0, "the level comes up at tier 3 and stays at zero at tier 2 (%.2f, %.2f)" % [h3.rocks.level[0], h2.rocks.level[0]])
	var hc: VfxHub = run.call(4.0, 90, func(): f.state = "charging")
	_check(hc.rocks.level[0] == 0.0, "none while he charges (Legal's stacking rule)")
	var hh: VfxHub = run.call(4.0, 90, func(): f.hidden = true)
	_check(hh.rocks.level[0] == 0.0, "none while he is hidden")
	var hfar: VfxHub = run.call(4.0, 90, func(): f.y = g + 3000.0)
	_check(hfar.rocks.level[0] == 0.0, "none high in the air, away from the ground they come from")
	var hf2 := VfxHub.new()
	hf2.rocks_enabled = true
	hf2.reset(S, 6)
	place.call(4.0)
	for k in range(90):
		_tick(S, hf2, [])
	var up: float = hf2.rocks.level[0]
	f.x = SimWrap.wrap(plains + 150.0 * 40.0 * 0.0)
	for k in range(30):
		f.x = SimWrap.wrap(f.x + 400.0)       # 24000 u/s: a fast flight
		_tick(S, hf2, [])
	_check(up > 0.99 and hf2.rocks.level[0] < 0.2, "they sink when he moves fast (%.2f to %.2f)" % [up, hf2.rocks.level[0]])
	var hform := VfxHub.new()
	hform.rocks_enabled = true
	hform.reset(S, 6)
	place.call(3.0)
	for k in range(90):
		_tick(S, hform, [])
	_tick(S, hform, [VfxMock.ev("transform", {"actor": 0, "tier": 4.0, "source": "ai", "dur": 3.0, "version": "full"})])
	_check(hform.rocks.level[0] < hform.rocks.prev[0] + 0.001 and hform.rocks.level[0] <= 1.0, "a transformation of that slot takes them down")
	var hoff := VfxHub.new()
	hoff.rocks_enabled = false
	hoff.reset(S, 6)
	place.call(4.0)
	for k in range(90):
		_tick(S, hoff, [])
	_check(hoff.rocks.level[0] == 0.0 and hoff.rocks.clock == 0, "flag off: nothing runs")
	# Not a ring: the angles are uneven, the distances and heights vary, and a seed gives the same cloud twice.
	var pcs: Array = h3.rocks.pieces[0].slice(0, 10)
	var angs: Array = pcs.map(func(p): return fposmod(p.ang, TAU))
	angs.sort()
	var gaps: Array = []
	for i in range(angs.size()):
		gaps.append((angs[(i + 1) % angs.size()] - angs[i]) if i + 1 < angs.size() else (angs[0] + TAU - angs[i]))
	var mean: float = TAU / float(gaps.size())
	var dev: float = 0.0
	for gp in gaps:
		dev += absf(gp - mean)
	dev /= float(gaps.size()) * mean
	var rmin: float = 99.0
	var rmax: float = 0.0
	for pc in pcs:
		rmin = minf(rmin, pc.r)
		rmax = maxf(rmax, pc.r)
	_check(dev > 0.25 and rmax - rmin > 1.0, "the pieces are an uneven cloud, not a ring (spacing varies by %.0f%%, distances %.1f to %.1f heights)" % [dev * 100.0, rmin, rmax])
	var ha := VfxHub.new()
	ha.reset(S, 6)
	_check(ha.rocks.pieces[0][3].ang == h3.rocks.pieces[0][3].ang and ha.rocks.pieces[0][3].ang != h3.rocks.pieces[1][3].ang, "the same seed gives the same cloud, each fighter his own")
	# Legal's conditions (RL-057): few, small, uneven, each drifting its own way, never a ring, never spiralling, never rising in a column.
	_check(VfxHub.new().rocks_enabled == VfxLook.ROCKS_DEFAULT and VfxLook.ROCKS_DEFAULT, "the flag is on by default")
	_check(VfxRocks.count_for(4, 1.0) <= 10 and VfxRocks.MAX_PIECES <= 12, "few: at most 10 shown at tier 4, 12 in the pool")
	var big: float = 0.0
	for s2 in range(2):
		for pc in ha.rocks.pieces[s2]:
			big = maxf(big, pc.size)
	_check(big * VfxRocks.p("rocks", "t4_size") <= 0.6 * VfxLook.BH, "small: no piece over %.0f units, %.2f of a fighter's height (largest %.0f)" % [0.6 * VfxLook.BH, 0.6, big * VfxRocks.p("rocks", "t4_size")])
	var dr: Array = []
	var pos_n: int = 0
	var neg_n: int = 0
	var inrange: bool = true
	for pc in ha.rocks.pieces[0].slice(0, 10):
		dr.append(snappedf(absf(pc.drift), 0.0001))
		if pc.drift > 0.0:
			pos_n += 1
		else:
			neg_n += 1
		if absf(pc.drift) < VfxRocks.p("rocks", "drift_min") - 1e-6 or absf(pc.drift) > VfxRocks.p("rocks", "drift_max") + 1e-6:
			inrange = false
	var uniq: Dictionary = {}
	for d in dr:
		uniq[d] = true
	_check(inrange and pos_n > 0 and neg_n > 0 and uniq.size() == dr.size(), "each drifts its own way: both directions (%d and %d), all ten speeds differ, all slow (%.2f to %.2f rad/s)" % [pos_n, neg_n, VfxRocks.p("rocks", "drift_min"), VfxRocks.p("rocks", "drift_max")])
	var bh: float = VfxLook.BH
	var bob: float = VfxRocks.p("rocks", "bob_bh") * bh
	var steady: bool = true
	var level: bool = true
	var low: float = 99.0
	var high: float = -99.0
	for pc in ha.rocks.pieces[0].slice(0, 10):
		var a0: Vector3 = VfxRocks.at(pc, 0.0, bh, bob)
		var r0: float = sqrt(a0.x * a0.x + (a0.z / 0.35) * (a0.z / 0.35))
		var ymin: float = 1e9
		var ymax: float = -1e9
		for k in range(0, 601, 5):
			var tt: float = float(k) / 10.0           # a minute of drift
			var ak: Vector3 = VfxRocks.at(pc, tt, bh, bob)
			var rk: float = sqrt(ak.x * ak.x + (ak.z / 0.35) * (ak.z / 0.35))
			if absf(rk - r0) > 0.5:
				steady = false
			ymin = minf(ymin, ak.y)
			ymax = maxf(ymax, ak.y)
		if ymax - ymin > 2.0 * bob + 0.5:
			level = false
		low = minf(low, ymin / bh)
		high = maxf(high, ymax / bh)
	_check(steady, "never spiralling: every piece keeps its own distance from him over a minute of drift")
	_check(level and high <= VfxRocks.p("rocks", "h_max_bh") + VfxRocks.p("rocks", "bob_bh") + 1e-3, "never rising in a column: each stays at its own height (a bob of %.2f only), the highest %.2f heights up" % [VfxRocks.p("rocks", "bob_bh"), high])
	var saved: Dictionary = VfxRocks._data
	VfxRocks._data = {}
	var fallback: bool = VfxRocks.p("rocks", "count_t4") == 10.0 and VfxRocks.p("rocks", "min_tier") == 3.0
	VfxRocks._data = saved
	_check(fallback, "missing data falls back to the defaults")
	var same: bool = true
	for k in VfxRocks.DEFAULTS["rocks"].keys():
		if not saved.has("rocks") or not saved["rocks"].has(k) or float(saved["rocks"][k]) != float(VfxRocks.DEFAULTS["rocks"][k]):
			same = false
			print("    differs: rocks.%s" % k)
	_check(same, "data/vfx/power.json and the built-in defaults agree")
	SimCore.dispose(S)


## Blast amplification (idea 2, `blast_enabled`): a crater is bigger to look at by the causer's tier.
func _blast() -> void:
	print("blast amplification")
	var S := SimCore.createSim()
	SimCore.newMatch(S, 6)
	var plains: float = SimWrap.wrap(2250.0 * SimConst.PS)
	var g: float = WorldTerrain.groundY(S, plains)
	var f = S.fighters[0]
	_check(VfxBlast.mult_for(1) == 0.0 and VfxBlast.mult_for(2) < VfxBlast.mult_for(3) and VfxBlast.mult_for(3) < VfxBlast.mult_for(4), "no extra at tier 1, more at each tier above")
	_check(VfxLook.BLAST_DEFAULT and VfxLook.BLAST_POWERUP_DEFAULT, "on by default, for power-up craters at the break too (Legal, RL-059)")
	var crater := func(owner: float, cause: String, special: float): return VfxMock.ev("crater", {"x": plains, "y": g, "r": 200.0, "depth": 60.0, "energy": 8.0, "cause": cause, "owner": owner, "special": special, "rim": 20.0, "z": 0.0})
	# One crater, then two and a half seconds of ticks: how many bits the pool took, with the amplification and without it.
	var run := func(tier: float, on: bool, ev: Array, setup: Callable) -> VfxHub:
		var h := VfxHub.new()
		h.blast_enabled = on
		h.reset(S, 6)
		f.x = plains
		f.y = g
		f.vx = 0.0
		f.vy = 0.0
		f.state = "free"
		f.beamCharge = null
		f.hidden = false
		f.tier = tier
		setup.call()
		_tick(S, h, ev)
		for k in range(150):
			_tick(S, h, [])
		return h
	var none := func(): pass
	var spawned: Array = []
	var rings: Array = []
	for t in [1.0, 2.0, 3.0, 4.0]:
		var base: VfxHub = run.call(t, false, [crater.call(0.0, "impact", 0.0)], none)   # the same tier without it: the rubble lifts and the ejecta are in both
		var h: VfxHub = run.call(t, true, [crater.call(0.0, "impact", 0.0)], none)
		spawned.append(h.debris.spawned - base.debris.spawned)
		rings.append(h.blast.rings)
	_check(spawned[0] == 0 and spawned[1] > 0 and spawned[2] > spawned[1] and spawned[3] > spawned[2], "more bits to the pool at each tier (extra %d, %d, %d, %d)" % [spawned[0], spawned[1], spawned[2], spawned[3]])
	_check(rings[0] == 0 and rings[1] == 1 and rings[2] == 1 and rings[3] == 2, "one shock ring at tiers 2 and 3, a second behind it at tier 4 (%s)" % str(rings))
	var h4: VfxHub = run.call(4.0, true, [crater.call(0.0, "impact", 0.0)], none)
	_check(h4.debris.jobs.is_empty(), "the pebble fall and the settling dust have all come due and run within two seconds")
	_check(h4.blast.chunks >= 8, "tier 4 throws a good handful of rim chunks (%d)" % h4.blast.chunks)
	# Ground-level power-up craters (RL-059): only at the transformation's break, one a transformation, never in the air, never in the gather.
	var xf_ev := func(tier: float): return VfxMock.ev("transform", {"actor": 0, "tier": tier, "source": "ai", "dur": 0.0, "version": "live"})
	var break_run := func(tier: float, pre_ticks: int, after: Array, setup: Callable, powerup_flag: bool) -> VfxHub:
		var h := VfxHub.new()
		h.blast_powerup_enabled = powerup_flag
		h.rocks_enabled = true
		h.reset(S, 6)
		f.x = plains
		f.y = g
		f.vx = 0.0
		f.vy = 0.0
		f.state = "free"
		f.beamCharge = null
		f.hidden = false
		f.tier = tier
		setup.call()
		for k in range(60):
			_tick(S, h, [])
		_tick(S, h, [xf_ev.call(tier)])
		for k in range(pre_ticks):
			_tick(S, h, [])
		_tick(S, h, [crater.call(0.0, "powerup", 1.0)])
		for step in after:
			for k in range(int(step[0])):
				_tick(S, h, [])
			if step.size() > 1:
				_tick(S, h, [crater.call(0.0, "powerup", 1.0)])
		return h
	var hb: VfxHub = break_run.call(4.0, 10, [[2]], none, true)       # the live version's gather is 10 ticks: this is the break
	_check(hb.blast.made == 1 and hb.blast.rings == 2, "at the break: one amplification, scaled by tier (a second ring at tier 4)")
	var hb3: VfxHub = break_run.call(3.0, 10, [[2]], none, true)
	_check(hb3.blast.made == 1 and hb3.blast.rings == 1 and hb3.blast.chunks > 0, "tier 3: one ring, rim chunks")
	var hg: VfxHub = break_run.call(4.0, 2, [[2]], none, true)
	_check(hg.blast.made == 0, "nothing in the gather (the crater two ticks into it)")
	var hn := VfxHub.new()
	hn.reset(S, 6)
	f.x = plains
	f.y = g
	f.tier = 4.0
	for k in range(30):
		_tick(S, hn, [])
	_tick(S, hn, [crater.call(0.0, "powerup", 1.0)])
	_check(hn.blast.made == 0, "none for a power-up that comes with no transformation (a charge's power-up)")
	var h2x: VfxHub = break_run.call(4.0, 10, [[20, 1]], none, true)
	_check(h2x.blast.made == 1, "one crater a transformation: a second in the same form gets none")
	var hair: VfxHub = break_run.call(4.0, 10, [[2]], func(): f.y = g + 400.0, true)
	_check(hair.blast.made == 0, "none for a power-up in the air")
	var hoffp: VfxHub = break_run.call(4.0, 10, [[2]], none, false)
	_check(hoffp.blast.made == 0, "blast_powerup_enabled off: none")
	_check(VfxBlast.POWERUP_OFF.is_empty(), "no fighter's gather has a scream or a crouch now: the off list is empty")
	VfxBlast.POWERUP_OFF = [String(f.name)]
	var hlist: VfxHub = break_run.call(4.0, 10, [[2]], none, true)
	VfxBlast.POWERUP_OFF = []
	_check(hlist.blast.made == 0, "a fighter on the off list (a scream or a fists-at-sides crouch in his gather) gets none")
	_check(hb.rocks.level[0] < 0.2, "the rocks are stood down through the transformation (level %.2f)" % hb.rocks.level[0])
	# Flat ring, thrown chunks: read the bits one tick after the break with everything else off.
	var hq := VfxHub.new()
	hq.earth_enabled = false
	hq.react_enabled = false
	hq.rocks_enabled = false
	hq.pressure_enabled = false
	hq.reset(S, 6)
	f.x = plains
	f.y = g
	f.tier = 4.0
	for k in range(5):
		_tick(S, hq, [])
	_tick(S, hq, [xf_ev.call(4.0)])
	for k in range(10):
		_tick(S, hq, [])
	_tick(S, hq, [crater.call(0.0, "powerup", 1.0)])
	_tick(S, hq, [])
	var flat_ok: bool = true
	var rings_n: int = 0
	var fall_ok: bool = true
	var chunks_n: int = 0
	for bt in hq.debris.bits:
		if bt.kind == VfxDebris.RING:
			rings_n += 1
			if bt.mode != 3:
				flat_ok = false
		if bt.kind == VfxDebris.CHUNK:
			chunks_n += 1
			if bt.grav <= 0.0:
				fall_ok = false
	_check(rings_n >= 1 and flat_ok, "the ring lies flat on the ground (%d ring, all flat)" % rings_n)
	_check(chunks_n > 0 and fall_ok, "the chunks are thrown and fall: %d, all under gravity, none rising (that is the rubble lift's)" % chunks_n)
	var hch: VfxHub = run.call(4.0, true, [crater.call(0.0, "impact", 0.0)], func(): f.state = "charging")
	_check(hch.blast.made == 0, "none from a fighter who is charging")
	var hno: VfxHub = run.call(4.0, true, [crater.call(-1.0, "impact", 0.0)], none)
	_check(hno.blast.made == 0, "none for a crater nobody caused (an entrance crater)")
	var hgap: VfxHub = run.call(4.0, true, [crater.call(0.0, "impact", 0.0), crater.call(0.0, "impact", 1.0)], none)
	_check(hgap.blast.made == 1 and hgap.blast.skipped == 1, "two craters in one tick make one amplification (the rate limit)")
	var hred := VfxHub.new()
	hred.force_reduced = true
	hred.reduced_motion = true
	hred.reset(S, 6)
	f.tier = 4.0
	_tick(S, hred, [crater.call(0.0, "impact", 0.0)])
	_check(hred.blast.rings == 0 and hred.blast.made == 1, "reduced motion keeps the debris and drops the shock rings")
	var saved: Dictionary = VfxBlast._data
	VfxBlast._data = {}
	var fallback: bool = VfxBlast.p("blast", "mult_t4") == 1.7
	VfxBlast._data = saved
	_check(fallback, "missing data falls back to the defaults")
	var same: bool = true
	for k in VfxBlast.DEFAULTS["blast"].keys():
		if not saved.has("blast") or not saved["blast"].has(k) or float(saved["blast"][k]) != float(VfxBlast.DEFAULTS["blast"][k]):
			same = false
			print("    differs: blast.%s" % k)
	_check(same, "data/vfx/power.json (blast) and the built-in defaults agree")
	SimCore.dispose(S)


## Pressure rings (idea 4, `pressure_enabled`): a ring of shoved air at a dash, a hard stop or a hard turn, by tier.
func _pressure() -> void:
	print("pressure rings")
	var S := SimCore.createSim()
	SimCore.newMatch(S, 6)
	var plains: float = SimWrap.wrap(2250.0 * SimConst.PS)
	var g: float = WorldTerrain.groundY(S, plains)
	var f = S.fighters[0]
	var o = S.fighters[1]
	o.x = SimWrap.wrap(plains + 9000.0)
	o.y = WorldTerrain.groundY(S, o.x)
	_check(VfxPressure.mult_for(1) == 0.0 and VfxPressure.mult_for(2) < VfxPressure.mult_for(3) and VfxPressure.mult_for(3) < VfxPressure.mult_for(4), "no ring at tier 1, bigger at each tier above")
	_check(VfxLook.PRESSURE_DEFAULT, "on by default (a ring of air is not one of Legal's seven marks)")
	# A scripted flight: at rest 40 ticks, a dash to the right at 14.4 fighter heights a second for 40 ticks, a hard reversal for 40, then at rest.
	var fly := func(tier: float, quality: int, reduced: bool, setup: Callable, steps: Array) -> VfxHub:
		var h := VfxHub.new()
		h.quality = quality
		h.reduced_motion = reduced
		h.reset(S, 6)
		f.x = plains
		f.y = g + 300.0
		f.vx = 0.0
		f.vy = 0.0
		f.state = "free"
		f.rush = null
		f.hidden = false
		f.beamCharge = null
		f.tier = tier
		setup.call()
		for st in steps:
			for k in range(int(st[0])):
				f.x = SimWrap.wrap(f.x + float(st[1]))
				_tick(S, h, [])
		return h
	var none := func(): pass
	var script: Array = [[40, 0.0], [40, 18.0], [40, -18.0], [40, 0.0]]
	var h1: VfxHub = fly.call(1.0, VfxLook.Q_HIGH, false, none, script)
	var h2: VfxHub = fly.call(2.0, VfxLook.Q_HIGH, false, none, script)
	var h3: VfxHub = fly.call(3.0, VfxLook.Q_HIGH, false, none, script)
	var h4: VfxHub = fly.call(4.0, VfxLook.Q_HIGH, false, none, script)
	_check(h1.pressure.made == 0, "tier 1: none")
	_check(h2.pressure.made_start == 1 and h2.pressure.made_turn == 1 and h2.pressure.made_stop == 1, "tier 2: a ring at the dash, the hard turn and the hard stop (%d, %d, %d)" % [h2.pressure.made_start, h2.pressure.made_turn, h2.pressure.made_stop])
	_check(h4.pressure.ring_count == 6 and h3.pressure.ring_count == 3, "tier 4 adds a second ring to each (%d rings against %d at tier 3)" % [h4.pressure.ring_count, h3.pressure.ring_count])
	# Size by tier: read the first ring at each tier.
	var first := func(tier: float) -> VfxPressure.Ring:
		var h := VfxHub.new()
		h.reset(S, 6)
		f.x = plains
		f.y = g + 300.0
		f.state = "free"
		f.rush = null
		f.hidden = false
		f.tier = tier
		for st in [[40, 0.0], [4, 18.0]]:
			for k in range(int(st[0])):
				f.x = SimWrap.wrap(f.x + float(st[1]))
				_tick(S, h, [])
		return h.pressure.rings[0] if not h.pressure.rings.is_empty() else null
	var r2: VfxPressure.Ring = first.call(2.0)
	var r3: VfxPressure.Ring = first.call(3.0)
	var r4: VfxPressure.Ring = first.call(4.0)
	_check(r2 != null and r3 != null and r4 != null and r2.r1 < r3.r1 and r3.r1 < r4.r1, "the ring grows with the tier, not the speed (%.0f, %.0f, %.0f units)" % [r2.r1 if r2 else 0.0, r3.r1 if r3 else 0.0, r4.r1 if r4 else 0.0])
	_check(r4 != null and absf(r4.dx) > 0.99, "it lies across his line of travel (narrow axis along the dash)")
	var hl: VfxHub = fly.call(4.0, VfxLook.Q_LOW, false, none, script)
	_check(hl.pressure.ring_count == 3, "no second ring at quality low (%d)" % hl.pressure.ring_count)
	var hr: VfxHub = fly.call(4.0, VfxLook.Q_HIGH, true, none, script)
	_check(hr.pressure.ring_count == 3, "no second ring with reduced motion (%d)" % hr.pressure.ring_count)
	var hq: VfxHub = fly.call(4.0, VfxLook.Q_HIGH, false, func(): f.state = "launched", script)
	_check(hq.pressure.made == 0, "none for a launched fighter (a hit is not a dash)")
	var hh: VfxHub = fly.call(4.0, VfxLook.Q_HIGH, false, func(): f.hidden = true, script)
	_check(hh.pressure.made == 0, "none while hidden")
	var slow: Array = [[40, 0.0], [80, 8.0], [40, 0.0]]       # 6.4 fighter heights a second: under the dash threshold
	var hs: VfxHub = fly.call(4.0, VfxLook.Q_HIGH, false, none, slow)
	_check(hs.pressure.made == 0, "none for ordinary movement under the dash speed")
	var hbusy: VfxHub = fly.call(4.0, VfxLook.Q_HIGH, false, none, [[40, 0.0], [40, 18.0], [10, 0.0], [10, 18.0], [10, 0.0], [10, 18.0], [10, 0.0]])
	_check(hbusy.pressure.made_start + hbusy.pressure.made_stop <= 3, "stutter-stepping is rationed by the cooldown (%d rings)" % hbusy.pressure.made)
	var hoff := VfxHub.new()
	hoff.pressure_enabled = false
	hoff.reset(S, 6)
	f.x = plains
	f.tier = 4.0
	for st in script:
		for k in range(int(st[0])):
			f.x = SimWrap.wrap(f.x + float(st[1]))
			_tick(S, hoff, [])
	_check(hoff.pressure.made == 0, "flag off: none")
	var saved: Dictionary = VfxPressure._data
	VfxPressure._data = {}
	var fallback: bool = VfxPressure.p("pressure", "mult_t4") == 1.5
	VfxPressure._data = saved
	_check(fallback, "missing data falls back to the defaults")
	var same: bool = true
	for k in VfxPressure.DEFAULTS["pressure"].keys():
		if not saved.has("pressure") or not saved["pressure"].has(k) or float(saved["pressure"][k]) != float(VfxPressure.DEFAULTS["pressure"][k]):
			same = false
			print("    differs: pressure.%s" % k)
	_check(same, "data/vfx/power.json (pressure) and the built-in defaults agree")
	SimCore.dispose(S)


class FakeHost:
	var S: SimState
	func fighter_x(i: int, _a: float) -> float:
		return S.fighters[i].x
	func fighter_pose(i: int, _a: float) -> Vector3:
		return Vector3(S.fighters[i].x, S.fighters[i].y, 0.0)
	func fighter_z(_i: int, _a: float) -> float:
		return 0.0


## Energy blasts (Encounter's slice 5): every shot in S.shots drawn, the charge on the hand, the hits by outcome.
func _shots() -> void:
	print("energy blasts")
	var S := SimCore.createSim()
	SimCore.newMatch(S, 6)
	var plains: float = SimWrap.wrap(2250.0 * SimConst.PS)
	var g: float = WorldTerrain.groundY(S, plains)
	var f0 = S.fighters[0]
	var f1 = S.fighters[1]
	f0.x = plains
	f0.y = g
	f1.x = SimWrap.wrap(plains + 2400.0)
	f1.y = g
	_check(VfxLook.SHOTS_DEFAULT and VfxHub.new().shots_enabled, "on by default")
	var mk := func(kind: String, owner: int, x: float, vx: float, power: float, dmg: float) -> SimState.Shot:
		var sh := SimState.Shot.new()
		sh.kind = kind
		sh.owner = owner
		sh.x = x
		sh.y = g + 60.0
		sh.vx = vx
		sh.vy = 0.0
		sh.power = power
		sh.dmg = dmg
		sh.fresh = false
		return sh
	var host := FakeHost.new()
	host.S = S
	var view := VfxShotsView.new()
	root.add_child(view)
	var hub := VfxHub.new()
	hub.reset(S, 6)
	# Shots in S.shots are drawn, none when they are not.
	S.shots = [mk.call("bolt", 0, plains + 500.0, 3600.0, 1.0, 8.67), mk.call("charged", 1, plains + 1500.0, -5400.0, 3.0, 66.0)]
	_tick(S, hub, [])
	view.update(hub, host, 1.0, plains + 1200.0, 0.7, 1200.0)
	_check(view.shots_drawn == 2 and view.count >= 8, "a shot in S.shots is drawn: 2 shots, %d quads" % view.count)
	S.shots = []
	_tick(S, hub, [])
	view.update(hub, host, 1.0, plains + 1200.0, 0.7, 1200.0)
	_check(view.shots_drawn == 0 and view.count == 0, "none drawn once S.shots is empty (after shot_end)")
	# The cap: 32 live shots fit the one draw.
	S.shots = []
	for k in range(32):
		S.shots.append(mk.call("bolt" if k % 2 == 0 else "charged", k % 2, plains + 100.0 * float(k), 3600.0, 1.0 if k % 2 == 0 else 3.0, 8.0))
	view.update(hub, host, 1.0, plains + 1600.0, 0.7, 2400.0)
	_check(view.shots_drawn == 32 and view.count <= VfxShotsView.CAP, "32 live shots in one draw (%d quads of %d)" % [view.count, VfxShotsView.CAP])
	S.shots = []
	# Where it is drawn: interpolated by the tick's remainder, held in a hit-stop, and at its start when fired this tick.
	var sp: SimState.Shot = mk.call("bolt", 0, 1000.0, 3600.0, 1.0, 8.0)
	var b0: Vector2 = VfxShotsView.shot_back(sp, 0.0, false)
	var b5: Vector2 = VfxShotsView.shot_back(sp, 0.5, false)
	var b1: Vector2 = VfxShotsView.shot_back(sp, 1.0, false)
	_check(absf(b0.x - 60.0) < 0.01 and absf(b5.x - 30.0) < 0.01 and b1.x == 0.0, "interpolated between ticks: 60, 30 and 0 units back at 0, half and 1 (%.0f, %.0f, %.0f)" % [b0.x, b5.x, b1.x])
	sp.fresh = true
	_check(VfxShotsView.shot_back(sp, 0.0, false) == Vector2.ZERO, "a shot fired this tick sits at its start")
	sp.fresh = false
	_check(VfxShotsView.shot_back(sp, 0.0, true) == Vector2.ZERO, "held where it is through a hit-stop (the shots do not move then)")
	# A seeking shot's arc is zero at both ends.
	_check(VfxShotsView.arc_y(0.0, 30, 75.0) == 0.0 and absf(VfxShotsView.arc_y(1.0, 30, 75.0)) < 1e-6 and VfxShotsView.arc_y(0.5, 30, 75.0) > 5.0, "a seeking shot's slight arc starts and ends on its line (%.1f at the middle)" % VfxShotsView.arc_y(0.5, 30, 75.0))
	# Size: a bolt is small, a charged shot is bigger by its power and by its charge.
	var look_b: Dictionary = VfxShots.look_of(mk.call("bolt", 0, 0.0, 0.0, 1.0, 8.67))
	var look_t: Dictionary = VfxShots.look_of(mk.call("charged", 0, 0.0, 0.0, 3.0, 44.0))
	var look_f: Dictionary = VfxShots.look_of(mk.call("charged", 0, 0.0, 0.0, 3.0, 66.0))
	_check(look_b["rad"] < look_t["rad"] and look_t["rad"] < look_f["rad"] and look_b["tail"] < look_f["tail"] and not look_b["halo"] and look_f["halo"], "a bolt is small with a short tail; a charged shot is bigger by its power and its charge, with a halo (%.0f, %.0f, %.0f units)" % [look_b["rad"], look_t["rad"], look_f["rad"]])
	# Colour: the owner's lane colour; a deflect hands the shot to the other, so it changes; never white, gold or red.
	var c0: Color = VfxShots.lane_of(S, 0)
	var c1: Color = VfxShots.lane_of(S, 1)
	_check(c0 != c1 and c0.to_html(false) == VfxAura.lane_color(String(f0.aura)).to_html(false), "each shot is in its owner's lane colour (%s and %s)" % [c0.to_html(false), c1.to_html(false)])
	var ok_col: bool = true
	for cc in [c0, c1]:
		var core: Color = cc.lightened(0.18)
		if core.s < 0.12 or (core.r > 0.9 and core.g > 0.8 and core.b < 0.6) or (core.r > 0.8 and core.g < 0.4 and core.b < 0.4):
			ok_col = false
	_check(ok_col, "the cores stay coloured: no white, gold or red (Legal)")
	# Events by outcome.
	var hv := VfxHub.new()
	hv.reset(S, 6)
	var shot_hit := func(outcome: String): return VfxMock.ev("shot_hit", {"actor": 0, "victim": 1, "kind": "bolt", "id": 1, "x": f1.x, "y": g + 60.0, "z": 0.0, "amount": 9.0, "outcome": outcome, "link": 0})
	_tick(S, hv, [shot_hit.call("hit")])
	var kinds: Array = hv.shots.fx.map(func(e): return e.kind)
	_check(kinds.has("flash") and kinds.has("ring"), "a hit: a flash and a ring (%s)" % str(kinds))
	hv.shots.fx.clear()
	_tick(S, hv, [shot_hit.call("guard")])
	kinds = hv.shots.fx.map(func(e): return e.kind)
	var sp_fx = null
	for e in hv.shots.fx:
		if e.kind == "splash":
			sp_fx = e
	_check(kinds.has("splash") and sp_fx != null and sp_fx.dx < 0.0, "a guard: a splash fanning back toward the shooter (dx %.0f)" % (sp_fx.dx if sp_fx != null else 0.0))
	hv.shots.fx.clear()
	_tick(S, hv, [shot_hit.call("deflect")])
	var dring = null
	for e in hv.shots.fx:
		if e.kind == "ring":
			dring = e
	_check(dring != null and dring.col.to_html(false) == c1.to_html(false), "a deflect: a ring in the deflector's colour (%s)" % (dring.col.to_html(false) if dring != null else "none"))
	hv.shots.fx.clear()
	_tick(S, hv, [shot_hit.call("dodge")])
	_check(hv.shots.fx.is_empty(), "a dodge: nothing at him (the shot flies on)")
	for oc in ["shrug", "stop"]:
		hv.shots.fx.clear()
		_tick(S, hv, [shot_hit.call(oc)])
		_check(not hv.shots.fx.is_empty(), "'%s' has its small flash" % oc)
	hv.shots.fx.clear()
	_tick(S, hv, [VfxMock.ev("shot_clash", {"id": 1, "b": 2, "x": plains + 1200.0, "y": g + 60.0, "z": 0.0, "amount": 1.0})])
	var burst = null
	for e in hv.shots.fx:
		if e.kind == "burst":
			burst = e
	_check(burst != null and burst.col.to_html(false) != burst.col2.to_html(false), "a trade: a burst with a ring in each fighter's colour")
	# A drawn trade and a drawn hit, then both gone after their life.
	view.update(hv, host, 1.0, plains + 1200.0, 0.7, 1200.0)
	_check(view.count >= 10, "a trade's burst is drawn (%d quads)" % view.count)
	for k in range(30):
		_tick(S, hv, [])
	_check(hv.shots.fx.is_empty(), "the effects are gone after their life")
	# A miss on the ground: dust and chunks into the pool; on the water: no error.
	var hm := VfxHub.new()
	hm.reset(S, 6)
	_tick(S, hm, [VfxMock.ev("shot_end", {"id": 1, "kind": "bolt", "x": plains + 800.0, "y": g, "z": 0.0, "cause": "ground", "actor": 0})])
	_check(hm.debris.spawned > 0, "a shot that ends on the ground throws dust and chunks (%d bits)" % hm.debris.spawned)
	_tick(S, hm, [VfxMock.ev("shot_end", {"id": 2, "kind": "charged", "x": plains + 800.0, "y": 0.0, "z": 0.0, "cause": "water", "actor": 0})])
	_check(true, "a shot that ends on the water is handled")
	# The charge on the hand: starts on blast_charge, builds, pulses at blast_full, ends when the shot leaves or is cancelled.
	var hc := VfxHub.new()
	hc.reset(S, 6)
	f0.face = 1.0
	_tick(S, hc, [VfxMock.ev("cue", {"actor": 0, "kind": "blast_charge", "text": "", "source": ""})])
	_check(hc.shots.charges[0].on and not hc.shots.charges[1].on, "blast_charge starts the charge on his hand")
	for k in range(8):
		_tick(S, hc, [])
	var early: float = hc.shots.charges[0].lvl
	for k in range(25):
		_tick(S, hc, [])
	var late: float = hc.shots.charges[0].lvl
	_check(early > 0.05 and late > early and late > 0.9, "it builds over the 30 ticks (%.2f at 8, %.2f at 33)" % [early, late])
	_tick(S, hc, [VfxMock.ev("cue", {"actor": 0, "kind": "blast_full", "text": "", "source": ""})])
	_check(hc.shots.charges[0].full, "blast_full marks it complete")
	S.shots = []
	view.update(hc, host, 1.0, plains + 1200.0, 0.7, 1200.0)
	_check(view.charges_drawn == 1 and view.count >= 4, "the charge is drawn on the hand (%d quads)" % view.count)
	_tick(S, hc, [VfxMock.ev("shot_fire", {"actor": 0, "kind": "charged", "id": 5, "x": f0.x, "y": g + 60.0, "z": 0.0, "target": 1, "spd": 5400.0, "amount": 3.0, "link": 0, "ux": 1.0, "uy": 0.0})])
	_check(not hc.shots.charges[0].on, "the shot leaving ends the charge")
	for k in range(12):
		_tick(S, hc, [])
	_check(hc.shots.charges[0].lvl < 0.05, "and it fades off the hand")
	_tick(S, hc, [VfxMock.ev("cue", {"actor": 1, "kind": "blast_charge", "text": "", "source": ""})])
	_tick(S, hc, [VfxMock.ev("cue", {"actor": 1, "kind": "blast_cancel", "text": "", "source": ""})])
	_check(not hc.shots.charges[1].on, "blast_cancel ends it")
	_tick(S, hc, [VfxMock.ev("cue", {"actor": 1, "kind": "blast_charge", "text": "", "source": ""})])
	_tick(S, hc, [VfxMock.ev("cue", {"actor": 1, "kind": "charge_stopped", "text": "", "source": ""})])
	_check(not hc.shots.charges[1].on, "charge_stopped ends it")
	# Each fighter's own look: plates stacking on the Anti-hero's forearm, thin rings on the others'. Never a sphere in a palm.
	var hl := VfxHub.new()
	hl.reset(S, 6)
	_tick(S, hl, [VfxMock.ev("cue", {"actor": 0, "kind": "blast_charge", "text": "", "source": ""}), VfxMock.ev("cue", {"actor": 1, "kind": "blast_charge", "text": "", "source": ""})])
	var looks: Array = [hl.shots.charges[0].look, hl.shots.charges[1].look]
	_check(looks[1] == "plates" and looks[0] == "rings" and f1.role == "villain", "the Anti-hero's charge is plates along the forearm, the hero's thin rings (%s, %s)" % [looks[1], looks[0]])
	for k in range(40):
		_tick(S, hl, [])
	view.update(hl, host, 1.0, plains + 1200.0, 0.7, 1200.0)
	var disc_in_palm: bool = false
	for q in range(view.count):
		if is_equal_approx(view._buf[q * VfxShotsView.STRIDE + 18], VfxShotsView.SHAPE_DISC):
			disc_in_palm = true
	_check(view.charges_drawn == 2 and not disc_in_palm, "both charges drawn, and no disc (a sphere) among the quads")
	# Off: nothing.
	var hoff := VfxHub.new()
	hoff.shots_enabled = false
	hoff.reset(S, 6)
	_tick(S, hoff, [shot_hit.call("hit"), VfxMock.ev("cue", {"actor": 0, "kind": "blast_charge", "text": "", "source": ""})])
	_check(hoff.shots.fx.is_empty() and not hoff.shots.charges[0].on, "shots_enabled off: nothing")
	var saved: Dictionary = VfxShots._data
	VfxShots._data = {}
	var fallback: bool = VfxShots.p("shots", "charge_ticks") == 30.0
	VfxShots._data = saved
	_check(fallback, "missing data falls back to the defaults")
	view.queue_free()
	SimCore.dispose(S)


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
