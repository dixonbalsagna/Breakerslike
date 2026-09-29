class_name SimHiding
## Hiding and the ambush setup: the twin of hiding.js (updateHidden).


static func updateHidden(S: SimState, f, dt: float) -> void:
	var o = SimRoster.opp(S, f)
	var dist: float = absf(SimWrap.sdx(f.x, o.x))
	var c = WorldCover.coverAt(S, f)
	var want: bool = f.stance == 3.0 and f.state == "free" and c != null and dist > 170.0 and not f.input.charge and not f.input.dash and SimDetMath.hypot(f.vx, f.vy) < 260.0
	if want:
		f.hideT += dt
		if f.hideT > 0.9 and not f.hidden:
			f.hidden = true
			f.hiddenFor = 0.0
			var ls := SimState.LastSeen.new()
			ls.x = f.x
			ls.y = f.y
			f.lastSeen = ls
			SimEvents.feed(S, f.name + " goes to ground", "Power signature suppressed (" + c + "). Recovering; opponent has no lock-on.")
	else:
		f.hideT = 0.0
		if f.hidden:
			f.hidden = false
			if dist <= 240.0:
				SimEvents.feed(S, f.name + " found", "Opponent closed within scouting range.")
			elif f.hiddenFor > 1.8:
				f.ambushUntil = S.T + 2.5
	if f.hidden:
		f.hiddenFor += dt
