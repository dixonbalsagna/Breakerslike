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
	_aura()
	_react()
	_speed()
	_earth()
	_trails()
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
	# The count in a real minute of AI play against the 20 a minute Orb's treatment B was sized on.
	var S2 := SimCore.createSim()
	SimCore.newMatch(S2, 12345)
	var h2 := VfxHub.new()
	h2.reset(S2, 12345)
	for k in range(3600):
		SimCore.step(S2)
		h2.consume(S2, S2.out.fx)
		S2.out.fx.clear()
		S2.out.feed.clear()
	var per_min: int = h2.speed.made
	_check(per_min >= 8 and per_min <= 24, "in a real minute %d streaks (%d hits had a panel, %d were the same exchange's second), about the 17 a minute Game Design sized the one-per-exchange rule on" % [per_min, h2.speed.suppressed, h2.speed.capped])
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
