# The last stand (docs/architecture/last-stand.md). Usage: python laststand.py <repo root> code|director|hash|flip
#   code      the core: the two fighter fields, the window opening at the first brink, the count, sigFree, the events, the
#             data key (windowS 0: off), the forced parity check. Parity must pass on the untouched goldens.
#   director  Encounter's five signature gates (exchange.gd, beam.gd, ai.gd): by grant. Neutral while the window is 0.
#   hash      the fields and the events join the hash. Regenerate: the light digests must not move.
#   flip      windowS 20 in both fighters' wounds.json. Regenerate.
import os, sys
os.chdir(sys.argv[1])
part=sys.argv[2]
assert part in ('code','director','hash','flip')
def edit(p, pairs):
    s=open(p,encoding='utf-8').read()
    for a,b in pairs:
        assert s.count(a)==1,(p,a[:80],s.count(a))
        s=s.replace(a,b)
    open(p,'w',encoding='utf-8',newline='\n').write(s)

if part=='code':
    for fid in ("KAI","VORR"):
        edit("data/fighters/%s/wounds.json"%fid, [
        ('''  "cripple": {''','''  "lastStand": {
    "windowS": 0,
    "_note": "the last stand (spec-wounds section 1b, point 7): the first time this fighter reaches the brink in a match, one signature is free and off cooldown for windowS seconds, counted while he is free. 0 switches it off"
  },
  "cripple": {'''),
        ])
    edit('sim/core/fighter_data.gd', [
    ('''	var cripMax: int = 0
''','''	var cripMax: int = 0
	var lastStandTicks: int = 0      # the last stand: the free signature's window at the first brink, in ticks (lastStand.windowS; 0 is off)
'''),
    ('''	w.profile = String(j.get("profile", {}).get("type", ""))''','''	var lsS = j.get("lastStand", {}).get("windowS")
	if not (lsS is float or lsS is int) or float(lsS) < 0.0 or float(lsS) * 60.0 != floor(float(lsS) * 60.0):
		_err(where + ": lastStand.windowS must be a number of seconds, at least 0, that is a whole number of ticks")
	else:
		w.lastStandTicks = int(float(lsS) * 60.0)
	w.profile = String(j.get("profile", {}).get("type", ""))'''),
    ])
    edit('sim/core/state.gd', [
    ('''	var brinkSetups: int = 0  ''','''	var lastStandUsed: bool = false  # the last stand: this fighter has had his (the first brink of the match)
	var lastStandLeft: int = 0       # ... and the ticks left in its window, counted while he is free (0: closed)
	var brinkSetups: int = 0  '''),
    ])
    edit('sim/core/wounds.gd', [
    ('''		if brink:
			SimFx.brinkEnter(S, f)
''','''		if brink:
			SimFx.brinkEnter(S, f)
			SimFighter.lastStandOpen(S, f)   # the last stand: the first brink of the match
'''),
    ])
    edit('sim/core/fighter.gd', [
    ('''## The tier a fighter's power has earned: 1, plus one per threshold reached.''','''## The last stand (spec-wounds.md section 1b, point 7; docs/architecture/last-stand.md). The first time a fighter reaches
## the brink in a match, one signature is free and off cooldown for his window (wounds.json lastStand.windowS). The window
## counts live ticks in which he is free or charging and not stunned, so it starts when he is next free; it closes when he
## fires (lastStandUse) or runs out. A second brink gives nothing. The director's signature gates read sigFree().
static func lastStandOpen(S: SimState, f) -> void:
	if f.lastStandUsed or f.wd.lastStandTicks <= 0:
		return
	f.lastStandUsed = true
	f.lastStandLeft = f.wd.lastStandTicks
	SimFx.lastStandReady(S, f, float(f.wd.lastStandTicks) / 60.0)


static func sigFree(f) -> bool:
	return f.lastStandLeft > 0


static func lastStandUse(S: SimState, f) -> void:
	if f.lastStandLeft > 0:
		f.lastStandLeft = 0
		SimFx.lastStandEnd(S, f, "used")


## The tier a fighter's power has earned: 1, plus one per threshold reached.'''),
    ('''	var regen: float = 5.0 + (25.0 if f.hidden and f.canHide else 0.0)''','''	if f.lastStandLeft > 0 and (f.state == "free" or f.state == "charging") and f.stunTicks == 0 and S.game.ko == null:
		f.lastStandLeft -= 1   # the last stand's window
		if f.lastStandLeft == 0:
			SimFx.lastStandEnd(S, f, "expired")
	var regen: float = 5.0 + (25.0 if f.hidden and f.canHide else 0.0)'''),
    ])
    edit('sim/core/fx.gd', [
    ('''## The intro phase (sim/core/intro.gd). intro_start:''','''## The last stand: actor reached the brink for the first time this match; one signature is free and off cooldown for dur
## seconds of his free time. last_stand_end: the window closed; kind is used (he fired) or expired.
static func lastStandReady(S: SimState, f, dur: float) -> void:
	var e := _ev(S, "last_stand_ready")
	e.actor = float(S.fighters.find(f)); e.dur = dur


static func lastStandEnd(S: SimState, f, kind: String) -> void:
	var e := _ev(S, "last_stand_end")
	e.actor = float(S.fighters.find(f)); e.kind = kind


## The intro phase (sim/core/intro.gd). intro_start:'''),
    ])
    edit('sim/core/view/fx.gd', [
    ('''"pause_start", "pause_end",''','''"pause_start", "pause_end", "last_stand_ready", "last_stand_end",'''),
    ])
    p='sim/core/tools/parity.gd'
    s=open(p,encoding='utf-8').read()
    def rep(a,b):
        global s
        assert s.count(a)==1,(a[:80],s.count(a))
        s=s.replace(a,b)
    rep('''	check("the intro phase", _intro())
''','''	check("the intro phase", _intro())
	check("the last stand", _lastStand())
''')
    rep('''## The intro phase (sim/core/intro.gd): off unless''','''## The last stand (sim/core/fighter.gd): the window opens at a fighter's first brink and not at a second; it counts only
## while he is free and not stunned; it runs out with last_stand_end expired; a use closes it; with the data's window at
## 0 nothing opens. When the director's gates are in (they read sigFree), a free signature starts with no ki and inside
## the cooldown, costs nothing and closes the window.
func _lastStand() -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5, {"p1": false, "p2": false})
	var a = S.fighters[0]
	var n: int = a.wd.lastStandTicks
	var core: int = SimWounds.CORE
	var toBrink := func() -> void:
		a.wear[core] = SimWounds.STAGE_AT[2]
		SimWounds.updateStages(S, a)
	var count := func(type: String, kind: String) -> int:
		var c: int = 0
		for e in S.out.fx:
			if e.type == type and (kind == "" or e.kind == kind) and int(e.actor) == 0:
				c += 1
		return c
	toBrink.call()
	if not a.brink:
		return "the forced brink did not take"
	if n <= 0:
		SimCore.dispose(S)
		return "" if (a.lastStandLeft == 0 and count.call("last_stand_ready", "") == 0) else "with the window at 0 a last stand opened"
	if not a.lastStandUsed or a.lastStandLeft != n or count.call("last_stand_ready", "") != 1 or not SimFighter.sigFree(a):
		return "the first brink did not open the last stand (left %d of %d)" % [a.lastStandLeft, n]
	# it counts only while he is free and not stunned
	a.state = "locked"
	for t in range(10):
		SimFighter.stepFighter(S, a, SimConst.DT)
	a.state = "free"
	a.stunTicks = 100
	for t in range(10):
		SimFighter.stepFighter(S, a, SimConst.DT)
	if a.lastStandLeft != n:
		return "the window ran while he was locked or stunned (%d of %d)" % [a.lastStandLeft, n]
	a.stunTicks = 0
	for t in range(10):
		SimFighter.stepFighter(S, a, SimConst.DT)
	if a.lastStandLeft != n - 10:
		return "the window did not count his free ticks (%d, wants %d)" % [a.lastStandLeft, n - 10]
	# a use closes it
	S.out.fx.clear()
	SimFighter.lastStandUse(S, a)
	if a.lastStandLeft != 0 or SimFighter.sigFree(a) or count.call("last_stand_end", "used") != 1:
		return "a use did not close the window"
	# a second brink gives nothing
	a.wear[core] = 0
	SimWounds.updateStages(S, a)
	S.out.fx.clear()
	toBrink.call()
	if a.lastStandLeft != 0 or count.call("last_stand_ready", "") != 0:
		return "a second brink opened a second last stand"
	# it runs out
	var b = S.fighters[1]
	b.wear[core] = SimWounds.STAGE_AT[2]
	SimWounds.updateStages(S, b)
	b.lastStandLeft = 2
	b.state = "free"
	b.stunTicks = 0
	S.out.fx.clear()
	SimFighter.stepFighter(S, b, SimConst.DT)
	SimFighter.stepFighter(S, b, SimConst.DT)
	var expired: int = 0
	for e in S.out.fx:
		if e.type == "last_stand_end" and e.kind == "expired" and int(e.actor) == 1:
			expired += 1
	if b.lastStandLeft != 0 or expired != 1:
		return "the window did not run out with one last_stand_end (left %d, %d events)" % [b.lastStandLeft, expired]
	SimCore.dispose(S)
	return _lastStandGates()


## The director's side of the last stand; "" until its gates are in.
func _lastStandGates() -> String:
	return ""


## The intro phase (sim/core/intro.gd): off unless''')
    open(p,'w',encoding='utf-8',newline='\n').write(s)

elif part=='director':
    edit('sim/director/exchange.gd', [
    ('''	if kind == "sig" and A.ki < 45.0:''','''	if kind == "sig" and A.ki < 45.0 and not SimFighter.sigFree(A):   # the last stand's signature is free'''),
    ('''	if kind == "sig" and S.T < A.sigReadyT:''','''	if kind == "sig" and S.T < A.sigReadyT and not SimFighter.sigFree(A):   # ... and off cooldown'''),
    ('''	if kind == "sig":
		A.ki -= 45.0
		A.sigReadyT = S.T + A.sigCooldown''','''	if kind == "sig":
		if SimFighter.sigFree(A):
			SimFighter.lastStandUse(S, A)   # the last stand: no cost, and the window closes
		else:
			A.ki -= 45.0
		A.sigReadyT = S.T + A.sigCooldown'''),
    ])
    edit('sim/director/beam.gd', [
    ('''		var canSig: bool = D.ki >= 45.0 and S.T >= D.sigReadyT''','''		var canSig: bool = (D.ki >= 45.0 and S.T >= D.sigReadyT) or SimFighter.sigFree(D)   # the last stand answers free'''),
    ('''		if int(q[k][0]) == SimAct.SIG and D.ki >= 45.0 and S.T >= D.sigReadyT:
			q.remove_at(k)
			D.ki -= 45.0''','''		if int(q[k][0]) == SimAct.SIG and ((D.ki >= 45.0 and S.T >= D.sigReadyT) or SimFighter.sigFree(D)):
			q.remove_at(k)
			if SimFighter.sigFree(D):
				SimFighter.lastStandUse(S, D)   # the last stand: no cost, and the window closes
			else:
				D.ki -= 45.0'''),
    ])
    edit('sim/director/ai.gd', [
    ('''			if f.ki >= 50.0 and q < sigPick and S.T >= f.sigReadyT:   # the signature cooldown (fighter.json sigCooldown)''','''			if SimFighter.sigFree(f) or (f.ki >= 50.0 and q < sigPick and S.T >= f.sigReadyT):   # the signature cooldown (fighter.json sigCooldown); the AI takes its last stand'''),
    ])
    edit('sim/core/tools/parity.gd', [
    ('''func _lastStandGates() -> String:
	return ""
''','''func _lastStandGates() -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5, {"p1": false, "p2": false})
	var a = S.fighters[0]
	if a.wd.lastStandTicks <= 0:
		SimCore.dispose(S)
		return ""
	S.dirS.cool = 0.0
	a.ki = 0.0
	a.sigReadyT = S.T + 100.0
	DirExchange.requestAttack(S, a, "sig")
	if S.dirS.ex != null:
		return "a signature with no ki, inside the cooldown, started without a last stand"
	a.lastStandUsed = true
	a.lastStandLeft = 600
	S.out.fx.clear()
	DirExchange.requestAttack(S, a, "sig")
	var used: int = 0
	for e in S.out.fx:
		if e.type == "last_stand_end" and e.kind == "used":
			used += 1
	if S.dirS.ex == null or S.dirS.ex.kind != "sig" or a.ki != 0.0 or a.lastStandLeft != 0 or used != 1:
		return "the free signature: exchange %s, ki %s, window %d, %d used events" % [str(S.dirS.ex != null), str(a.ki), a.lastStandLeft, used]
	if a.sigReadyT <= S.T:
		return "the free signature did not start the ordinary cooldown"
	SimCore.dispose(S)
	return ""
'''),
    ])

elif part=='hash':
    edit('sim/core/hash.gd', [
    ('''"contactT", "launchN", "jLips",
''','''"contactT", "launchN", "jLips", "lastStandUsed", "lastStandLeft",
'''),
    ('''"pause_end": ["kind"],''','''"pause_end": ["kind"], "last_stand_ready": ["actor", "dur"], "last_stand_end": ["actor", "kind"],'''),
    ])
    edit('sim/core/tools/batch.gd', [
    ('''			elif e.type == "pause_start":''','''			elif e.type == "last_stand_ready":
				rec.lastStands += 1
			elif e.type == "last_stand_end":
				rec.lastStandUsed += 1 if e.kind == "used" else 0
			elif e.type == "pause_start":'''),
    ('''"pauseMax": 0.0, "pauseTicks": 0, "capSurvived": 0}''','''"pauseMax": 0.0, "pauseTicks": 0, "capSurvived": 0, "lastStands": 0, "lastStandUsed": 0}'''),
    ('''	var capSurvived: int = 0
''','''	var capSurvived: int = 0
	var lastStands: int = 0
	var lastStandUsed: int = 0
'''),
    ('''		capSurvived += int(r.capSurvived)
''','''		capSurvived += int(r.capSurvived)
		lastStands += int(r.lastStands)
		lastStandUsed += int(r.lastStandUsed)
'''),
    ('''"pauseMax": pauseMax, "pauseOver": pauseOver, "capSurvived": capSurvived,''','''"pauseMax": pauseMax, "pauseOver": pauseOver, "capSurvived": capSurvived, "lastStands": lastStands, "lastStandUsed": lastStandUsed,'''),
    ('''	print("crippling: %.2f limb breaks/match (max %d)''','''	print("last stand: %.2f opened a match   %d of %d used (the rest ran out or the match ended)   signatures %.2f a match" % [float(w.lastStands) / n, w.lastStandUsed, w.lastStands, float(a.attacks.sig) / n])
	print("crippling: %.2f limb breaks/match (max %d)'''),
    ])

else:
    for fid in ("KAI","VORR"):
        edit("data/fighters/%s/wounds.json"%fid, [
        ('''    "windowS": 0,''','''    "windowS": 20,'''),
        ])
print("last stand applied:", part)
