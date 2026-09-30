extends SceneTree
## Combat feel probe (Combat, read-only). Steps AI-vs-AI matches and classifies every frame:
##   freeze  : hit-stop (sim time did not advance)
##   active  : a fighter moved faster than MOVE u/s, or a strike-type event happened in the last HOLD_VIS frames
##   idle    : neither (inside an exchange), or both fighters close and still (outside one: a "standoff")
## From the repo root:
##   godot --headless --path . --script res://qa/godot/feel/feel_probe.gd -- <matches> <baseSeed> [profile | path to a templates.json] [label]
## A profile name forces DirData.templatesProfile; a .json path swaps that templates file in (for profiles today's loader
## cannot select by name). Prints one JSON line. Definitions: docs/combat/dynamic-feel.md section 1.
const MOVE: float = 100.0          # u/s: about 1.3 fighter heights a second
const HOLD_VIS: int = 6            # frames a strike stays visible (spark, recoil)
const CLOSE_X: float = 400.0
const CLOSE_Y: float = 300.0
const MAX_STEPS: int = 43200
const STRIKE_EVENTS: Array = ["damage", "parry", "clash_draw", "launch"]

func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var n: int = int(a[0]) if a.size() > 0 else 20
	var base: int = int(a[1]) if a.size() > 1 else 1
	var prof: String = a[2] if a.size() > 2 else ""
	var label: String = a[3] if a.size() > 3 else prof
	if prof.ends_with(".json"):
		DirData.swap(DirData.parseFile(prof), DirData.parseFile("res://data/combat/finishers.json"))
	elif prof != "":
		DirData.templatesProfile = prof
	var agg := {"exFrames": 0, "exIdle": 0, "exFreeze": 0, "idleRuns": [], "firstStrike": [], "strikeGaps": [], "strikes": 0,
		"fightSec": 0.0, "exSec": 0.0, "exLen": [], "standFrames": 0, "standRuns": [], "outFrames": 0, "breath": [], "matches": n, "mFrames": 0, "mIdle": 0, "mIdleRuns": [], "mLen": [], "setIdleRuns": []}
	for i in range(n):
		_match(base + i, agg)
	print(JSON.stringify({"label": label, "profile": DirData.tplProfile(), "summary": _sum(agg)}))
	quit(0)

func _med(v: Array) -> float:
	if v.is_empty():
		return -1.0
	var s := v.duplicate(); s.sort()
	return s[int(s.size() / 2)]

func _pct(v: Array, p: float) -> float:
	if v.is_empty():
		return -1.0
	var s := v.duplicate(); s.sort()
	return s[mini(s.size() - 1, int(s.size() * p))]

func _sum(g: Dictionary) -> Dictionary:
	var exLive: int = g.exFrames - g.exFreeze
	return {
		"idle_share_in_exchanges": snappedf(float(g.exIdle) / maxf(1.0, exLive), 0.001),
		"freeze_share_in_exchanges": snappedf(float(g.exFreeze) / maxf(1.0, g.exFrames), 0.001),
		"longest_idle_per_exchange_med_s": snappedf(_med(g.idleRuns), 0.01),
		"longest_idle_per_exchange_p90_s": snappedf(_pct(g.idleRuns, 0.9), 0.01),
		"request_to_first_strike_med_s": snappedf(_med(g.firstStrike), 0.01),
		"gap_between_strikes_med_s": snappedf(_med(g.strikeGaps), 0.01),
		"gap_between_strikes_p90_s": snappedf(_pct(g.strikeGaps, 0.9), 0.01),
		"strikes_per_min": snappedf(g.strikes / maxf(1.0, g.fightSec / 60.0), 0.1),
		"exchange_len_med_s": snappedf(_med(g.exLen), 0.01),
		"share_time_in_exchanges": snappedf(g.exSec / maxf(1.0, g.fightSec), 0.001),
		"standoff_share_outside": snappedf(float(g.standFrames) / maxf(1.0, g.outFrames), 0.001),
		"standoff_run_med_s": snappedf(_med(g.standRuns), 0.01),
		"standoff_run_p90_s": snappedf(_pct(g.standRuns, 0.9), 0.01),
		"release_to_next_request_med_s": snappedf(_med(g.breath), 0.01),
		"melee_idle_share": snappedf(float(g.mIdle) / maxf(1.0, g.mFrames), 0.001),
		"melee_longest_idle_med_s": snappedf(_med(g.mIdleRuns), 0.01),
		"melee_longest_idle_p90_s": snappedf(_pct(g.mIdleRuns, 0.9), 0.01),
		"melee_len_med_s": snappedf(_med(g.mLen), 0.01),
		"setpiece_longest_idle_med_s": snappedf(_med(g.setIdleRuns), 0.01),
	}

func _match(seed: int, g: Dictionary) -> void:
	var S := SimCore.createSim()
	SimCore.newMatch(S, seed)
	var fs: Array = S.fighters
	var px: Array = [fs[0].x, fs[1].x]
	var py: Array = [fs[0].y, fs[1].y]
	var vis: int = 0
	var inEx: bool = false
	var exT0: float = 0.0
	var run: int = 0
	var longest: int = 0
	var gotStrike: bool = false
	var lastStrikeT: float = -1.0
	var stand: int = 0
	var lastRelease: float = -1.0
	var setPiece: bool = false
	var exF: int = 0
	var exI: int = 0
	var steps: int = 0
	while steps < MAX_STEPS and S.game.ko == null:
		var T0: float = S.T
		SimCore.step(S)
		steps += 1
		var struck: bool = false
		var finStart: bool = false
		for e in S.out.fx:
			if e.type in STRIKE_EVENTS:
				struck = true
			if e.type == "finisher_start":
				finStart = true
		S.out.fx.clear()
		S.out.feed.clear()
		var freeze: bool = S.T == T0
		var dt: float = S.T - T0
		var moved: bool = false
		for k in range(2):
			var dx: float = absf(SimWrap.sdx(px[k], fs[k].x))
			var dy: float = absf(fs[k].y - py[k])
			if not freeze and sqrt(dx * dx + dy * dy) > MOVE * SimConst.DT:
				moved = true
			px[k] = fs[k].x; py[k] = fs[k].y
		if struck:
			vis = HOLD_VIS
			g.strikes += 1
			if lastStrikeT >= 0.0 and S.T > lastStrikeT:
				g.strikeGaps.append(S.T - lastStrikeT)
			lastStrikeT = S.T
		var nowEx: bool = S.dirS.ex != null
		if nowEx and not inEx:
			inEx = true; exT0 = S.T; run = 0; longest = 0; gotStrike = false; exF = 0; exI = 0
			setPiece = S.dirS.ex.kind == "sig"
			if lastRelease >= 0.0:
				g.breath.append(S.T - lastRelease)
			if stand > 0:
				g.standRuns.append(stand / 60.0); stand = 0
		if not freeze:
			g.fightSec += dt
		if inEx and finStart:
			setPiece = true
		if inEx:
			g.exFrames += 1
			if freeze:
				g.exFreeze += 1
			else:
				g.exSec += dt
				exF += 1
				var active: bool = moved or vis > 0
				if active:
					run = 0
				else:
					g.exIdle += 1
					exI += 1
					run += 1
					longest = maxi(longest, run)
			if struck and not gotStrike:
				gotStrike = true
				g.firstStrike.append(S.T - exT0)
		else:
			g.outFrames += 1
			var close: bool = absf(SimWrap.sdx(fs[0].x, fs[1].x)) < CLOSE_X and absf(fs[0].y - fs[1].y) < CLOSE_Y
			var calm: bool = not moved and fs[0].state != "launched" and fs[1].state != "launched"
			if close and calm and not freeze:
				g.standFrames += 1
				stand += 1
			elif stand > 0:
				g.standRuns.append(stand / 60.0); stand = 0
		if inEx and not nowEx:
			inEx = false
			g.exLen.append(S.T - exT0)
			g.idleRuns.append(longest / 60.0)
			if setPiece:
				g.setIdleRuns.append(longest / 60.0)
			else:
				g.mFrames += exF; g.mIdle += exI; g.mIdleRuns.append(longest / 60.0); g.mLen.append(S.T - exT0)
			lastRelease = S.T
		if vis > 0:
			vis -= 1
