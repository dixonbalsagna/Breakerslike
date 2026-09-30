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
	print("\neffects check passed" if fails == 0 else "\neffects check FAILED (%d)" % fails)
	quit(0 if fails == 0 else 1)


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
