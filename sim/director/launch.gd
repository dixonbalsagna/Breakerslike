class_name DirLaunch
## Launch planner: the twin of launch.js (chooseLaunch, doLaunch). Candidates are Dictionaries like the JS objects.


static func chooseLaunch(S: SimState, A, D) -> Dictionary:
	var g: float = WorldTerrain.groundY(S, D.x)
	var alt: float = D.y - g
	var bio: String = WorldBiomes.biomeAt(D.x)
	var f: float = A.face
	var c: Array = []
	c.append({"name": "UPPERCUT", "ux": 0.25 * f, "uy": 1.0, "s": 14.0 + (14.0 if alt < 120.0 else 0.0)})
	c.append({"name": "SLAM DOWN", "ux": 0.2 * f, "uy": -1.25, "s": (24.0 if alt > 140.0 else 6.0) + A.tier * 4.0 + (12.0 if bio == "ocean" else 0.0) + (16.0 if bio == "city" else 0.0) + (8.0 if bio == "forest" else 0.0)})
	c.append({"name": "SMASH ACROSS", "ux": f, "uy": 0.18, "s": 16.0})
	for sign in [-1.0, 1.0]:
		var nb = WorldStructures.nearestBuilding(S, D.x, sign, 1100.0, D.y)
		if nb != null:
			c.append({"name": "BUILDING SMASH", "ux": sign, "uy": 0.12, "s": 12.0 + nb.b.h / 32.0 + A.tier * 3.0 + (6.0 if sign == f else -4.0), "land": D.x + sign * nb.d})
		if WorldBiomes.biomeAt(D.x + sign * 520.0) == "mountains":
			c.append({"name": "MOUNTAINSIDE", "ux": sign, "uy": 0.05, "s": 24.0, "land": D.x + sign * 520.0})
	for k in c:
		var lx: float = k.land if k.has("land") else D.x + k.ux * 500.0
		k.s += S.rng.range_(0.0, 8.0) + (-A.care) * 34.0 * WorldStructures.popNear(S, lx, 700.0)
		if k.name == S.dirS.lastLaunch:
			k.s -= 14.0
		if k.name == S.dirS.lastLaunch2:
			k.s -= 5.0
	# The JS stable sort by score, highest first: an insertion sort keeps equal scores in candidate order.
	for i in range(1, c.size()):
		var key = c[i]
		var j: int = i - 1
		while j >= 0 and key.s - c[j].s > 0.0:
			c[j + 1] = c[j]
			j -= 1
		c[j + 1] = key
	return {"best": c[0], "top": c.slice(0, 3)}


static func doLaunch(S: SimState, att, tgt, plan: Dictionary, force: float) -> void:
	var f: float = force * (1.0 + 0.16 * (att.tier - 1.0))
	tgt.state = "launched"
	tgt.launchBy = att
	tgt.bounces = 0.0
	tgt.stateT = 0.0
	tgt.rush = null
	tgt.hidden = false
	tgt.wet = tgt.y < 0.0 and WorldTerrain.seaAt(S, tgt.x)
	tgt.vx = plan.ux * f
	tgt.vy = plan.uy * f
	tgt.spin = (1.0 if plan.ux >= 0.0 else -1.0) * S.rng.range_(8.0, 16.0)
	SimFx.ring(S, tgt.x, tgt.y + 34.0, 600.0, "#ffffff", 0.3, 20.0)
	SimFx.shake(S, 10.0)
