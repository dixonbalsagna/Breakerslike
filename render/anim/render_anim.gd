class_name RenderAnim
extends RefCounted
## The mannequin runtime's hub (slice A1 of docs/animation/pose-pipeline.md): one AnimFighter per fighter, fed by the
## per-tick fx events and solved once a frame however many panes draw it. FighterView asks for its pose here. Render only:
## it reads S and the events, never writes them.
##   --noanim              keep the placeholder box figures (A/B runs, tools)
##   --anim-style=NAME     a timing profile from data/anim/profiles.json (snappy or fluid)
## Tools set `enabled` and `style_override` directly.

static var enabled: bool = true
static var style_override: String = ""
static var _args_read: bool = false
static var _style_arg: String = ""
static var _fighters: Dictionary = {}
static var _sid: int = 0
static var _last_tick: int = -1
## Cost counters for tools: microseconds spent in AnimFighter.solve, and how many solves.
## Tools set this to scan every bone for NaN each solve (the game checks two).
static var debug_checks: bool = false
static var solve_usec: int = 0
static var solve_count: int = 0


static func _read_args() -> void:
	if _args_read:
		return
	_args_read = true
	for a in OS.get_cmdline_user_args():
		if a == "--noanim":
			enabled = false
		elif a.begins_with("--anim-style="):
			_style_arg = a.substr(13)


static func is_enabled() -> bool:
	_read_args()
	return enabled


static func style() -> String:
	_read_args()
	if style_override != "":
		return style_override
	return _style_arg if _style_arg != "" else AnimData.default_profile


## True when a style was forced (--anim-style or a tool): then every part uses that profile instead of Orb's per-part mix.
static func style_forced() -> bool:
	_read_args()
	return style_override != "" or _style_arg != ""


## The facing a view should draw this fighter with: the opponent's side in an exchange, the travel direction on the run
## (the sim's own `face` when the mannequin is off).
static func face_for(S: SimState, f) -> float:
	if not is_enabled():
		return f.face
	return fighter(S, f).update_face(S, f)


static func profile() -> Dictionary:
	return AnimData.profile(style())


static func _sync(S: SimState) -> void:
	if S.get_instance_id() != _sid or S.tick < _last_tick:
		_fighters.clear()
		_sid = S.get_instance_id()
	_last_tick = S.tick


static func fighter(S: SimState, f) -> AnimFighter:
	_sync(S)
	var id: int = f.get_instance_id()
	var af = _fighters.get(id)
	if af == null:
		AnimData.load_all()
		af = AnimFighter.new(S.fighters.find(f))
		_fighters[id] = af
	return af


## The fighter's pose for this frame, solved on the first ask (the other panes reuse it).
static func solve(S: SimState, f) -> AnimFighter:
	var af: AnimFighter = fighter(S, f)
	if af.frame != _frame_key(S):
		var t0: int = Time.get_ticks_usec()
		af.solve(S, f, profile())
		solve_usec += Time.get_ticks_usec() - t0
		solve_count += 1
	return af


## Each tick's events, from the host (main.gd's drained handler): ticks step the springs, cues start poses, hits start
## reactions.
static func consume(S: SimState, events: Array) -> void:
	if not is_enabled():
		return
	_sync(S)
	AnimData.load_all()
	for e in events:
		match e.type:
			"tick":
				for f in S.fighters:
					fighter(S, f).on_tick(float(e.dt), bool(e.frozen))
			"transform":
				var who2: int = int(e.actor)
				if who2 >= 0 and who2 < S.fighters.size():
					fighter(S, S.fighters[who2]).on_transform(S.T, String(e.version))
			"cue":
				var who: int = int(e.actor)
				for i in range(S.fighters.size()):
					if who < 0 or i == who:
						fighter(S, S.fighters[i]).on_cue(String(e.kind), S.T)
			"damage":
				var v: int = int(e.victim)
				if v >= 0 and v < S.fighters.size() and String(e.kind) != "impact":
					var vf = S.fighters[v]
					var a: int = int(e.attacker)
					var front: bool = true
					if a >= 0 and a < S.fighters.size():
						front = SimWrap.sdx(vf.x, S.fighters[a].x) * fighter(S, vf).vface > 0.0
					fighter(S, vf).on_hit(S.T, String(e.region), front, float(e.amount) / 70.0, String(e.kind))


## Which frame a solve belongs to: the engine frame and the sim tick (tools step several ticks in one engine frame).
static func _frame_key(S: SimState) -> int:
	return Engine.get_process_frames() * 1000003 + S.tick
