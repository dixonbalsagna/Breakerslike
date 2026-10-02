class_name RenderAnim
extends RefCounted
## The mannequin runtime's hub (slice A1 of docs/animation/pose-pipeline.md): one AnimFighter per fighter, fed by the
## per-tick fx events and solved once a frame however many panes draw it. FighterView asks for its pose here. Render only:
## it reads S and the events, never writes them.
##   --noanim              keep the placeholder box figures (A/B runs, tools)
##   --noragdoll           switch the active ragdoll and the overhaul layers off (A/B runs)
##   --anim-style=NAME     a timing profile from data/anim/profiles.json (snappy or fluid)
## Tools set `enabled` and `style_override` directly.

static var enabled: bool = true
static var style_override: String = ""
static var _args_read: bool = false
static var _style_arg: String = ""
static var _quality_arg: String = ""
static var _fighters: Dictionary = {}
static var _sid: int = 0
static var _last_tick: int = -1
## Cost counters for tools: microseconds spent in AnimFighter.solve, and how many solves.
## Tools set this to scan every bone for NaN each solve (the game checks two).
static var debug_checks: bool = false
static var joint_audit: bool = false   # the joint-limit lint: every fighter notes which stage first took a joint past its limits (AnimFighter.audit)
## The active ragdoll (docs/animation/overhaul-plan.md): tools turn it off for the A/B; the host sets reduced_motion from the
## player's setting (it scales the ragdoll to 35% and turns the contact smear off).
static var ragdoll_enabled: bool = true
static var blow_join: bool = false        # --blowjoin: the blow's own snap is smoothed as a join (how it played before 2026-10-01 unit T), for an A/B
static var last_stand_poses: bool = true   # the last stand's body cue (docs 9.20); --no-last-stand-poses switches it off
static var flight_lead: bool = true         # a fast launched body flies head first (docs 9.23); --no-flight-lead switches it off (the before)
static var agency_poses: bool = true       # the agency slice's events (knockback, embed, the far taunt, the charges) play their poses (docs 9.22); --no-agency-poses switches them off
static var intro_poses: bool = true        # the opening's fall, landing and staredown (docs 9.19); --no-intro-poses switches them off
static var ground_poses: bool = true       # World's ground-contact events play their poses and sequences (docs 9.18); --no-ground-poses switches them off
static var step3_cues: bool = true         # Encounter's step 3 cue events (perfect_block, reversal, dodge_cancel, burst, burst_absorbed) play their pose sequences: ON (they are the only feedback for live mechanics); --no-step3-cues switches them off
static var wave1_live: bool = false        # --wave1-live: wave 1's key sets are in the pick lists (go-live step 1, docs/combat/pending/golive-step1.md); OFF by default
static var force_target: String = ""      # a lab switch (--target=arm_r): every blow aims at this socket instead of its key set's own
static var force_keyset: String = ""      # a lab switch (--keyset=strike.elbow): every blow plays this key set, to test a limb that no pick uses yet
static var reduced_motion: bool = false
## Feet planted on the slope under a standing fighter, and a skid pitched to the ground (overhaul unit D); tools turn it off for the A/B.
static var ground_feet: bool = true
## The quality switch (overhaul unit H): a level from data/anim/quality.json switches whole layers off for the web's low setting and
## old laptops. Tools switch single layers off with `layers_off` to measure what each costs (solve_bench).
static var quality: String = "high"
static var layers_off: Dictionary = {}
static var _quality_off: Dictionary = {}


static func set_quality(level: String) -> void:
	AnimData.load_all()
	quality = level
	_quality_off.clear()
	for nm in AnimData.quality_levels.get(level, []):
		_quality_off[String(nm)] = true


## Whether an overhaul layer runs: the master switch (--noragdoll), the quality level and the tools' own switches.
static func layer(name: String) -> bool:
	if not ragdoll_enabled:
		return false
	if name == "feet" and not ground_feet:
		return false
	return not _quality_off.has(name) and not layers_off.has(name)
static var solve_usec: int = 0
static var solve_count: int = 0


static func _read_args() -> void:
	if _args_read:
		return
	_args_read = true
	for a in OS.get_cmdline_user_args():
		if a == "--noanim":
			enabled = false
		elif a == "--noragdoll":
			ragdoll_enabled = false
		elif a == "--no-last-stand-poses":
			last_stand_poses = false
		elif a == "--no-agency-poses":
			agency_poses = false
		elif a == "--no-flight-lead":
			flight_lead = false
		elif a == "--no-intro-poses":
			intro_poses = false
		elif a == "--no-ground-poses":
			ground_poses = false
		elif a == "--step3-cues":
			step3_cues = true
		elif a == "--no-step3-cues":
			step3_cues = false
		elif a == "--wave1-live":
			wave1_live = true
		elif a.begins_with("--target="):
			force_target = a.substr(9)
		elif a == "--blowjoin":
			blow_join = true
		elif a.begins_with("--keyset="):
			force_keyset = a.substr(9)
		elif a.begins_with("--anim-quality="):
			_quality_arg = a.substr(15)
		elif a.begins_with("--anim-style="):
			_style_arg = a.substr(13)


static func is_enabled() -> bool:
	_read_args()
	if _quality_arg != "" and quality != _quality_arg:
		set_quality(_quality_arg)
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
					fighter(S, f).on_tick(float(e.dt), bool(e.frozen), S, f)
			"crater":
				# a crater was dug: a fighter near it feels it (the energy and the distance set how much)
				for f in S.fighters:
					var dxc: float = absf(SimWrap.sdx(f.x, float(e.x)))
					if dxc < 700.0:
						fighter(S, f).on_shock(S.T, clampf(float(_ev(e, "energy", 1.0)) / 8.0, 0.2, 1.0) * (1.0 - dxc / 700.0))
			"skim":
				# a launched fighter skipped off water: the event carries no actor, so it is the launched one at that x
				for f in S.fighters:
					if f.state == "launched" and absf(SimWrap.sdx(f.x, float(e.x))) < 120.0:
						fighter(S, f).on_skim(S.T, float(e.spd))
			"left_ground", "bounce", "land", "tumble_end", "journey_end":
				# World's ground-contact events (docs/world/ground-contact.md section 4); none exist until its G3 lands
				var ga: int = int(_ev(e, "actor", -1))
				if ga >= 0 and ga < S.fighters.size():
					var gd: Dictionary = {}
					for key in ["actor", "n", "k", "vn", "vt", "keep", "surface", "kind", "sina", "cause", "contacts", "dur", "spd", "vx", "vy", "slope", "lips", "nb", "z"]:
						var gv = e.get(key)
						if gv != null:
							gd[key] = gv
					var t_ev: float = S.T - float(S.tick - int(e.tick)) * (1.0 / 60.0)   # the event's own time
					fighter(S, S.fighters[ga]).on_ground_event(String(e.type), gd, t_ev)
			"last_stand_ready", "last_stand_end":
				var gl: int = int(_ev(e, "actor", -1))
				if gl >= 0 and gl < S.fighters.size():
					var t_ls: float = S.T - float(S.tick - int(e.tick)) * (1.0 / 60.0)
					fighter(S, S.fighters[gl]).on_last_stand(String(e.type), t_ls, float(_ev(e, "dur", 0.0)), String(e.kind))
			"intro_start", "entrance_fall", "entrance_land", "staredown_start", "clock_start":
				# the opening, on the sim's tick (the match clock is frozen until clock_start)
				var te: float = float(int(e.tick)) / 60.0
				var ga2: int = int(_ev(e, "actor", -1))
				if String(e.type) == "intro_start" or String(e.type) == "staredown_start" or String(e.type) == "clock_start":
					for f2 in S.fighters:
						fighter(S, f2).on_intro(String(e.type), te, float(_ev(e, "dur", 0.0)), String(e.kind))
				elif ga2 >= 0 and ga2 < S.fighters.size():
					fighter(S, S.fighters[ga2]).on_intro(String(e.type), te, float(_ev(e, "dur", 0.0)), "")
			"transform":
				var who2: int = int(e.actor)
				if who2 >= 0 and who2 < S.fighters.size():
					fighter(S, S.fighters[who2]).on_transform(S.T, String(e.version))
			"knockback":
				var kv: int = int(_ev(e, "victim", -1))
				if kv >= 0 and kv < S.fighters.size():
					var t_kb: float = S.T - float(S.tick - int(e.tick)) * (1.0 / 60.0)
					fighter(S, S.fighters[kv]).on_agency("knockback", t_kb, {"kind": String(e.kind), "dur": float(_ev(e, "dur", 0.5))})
			"embed":
				var ke: int = int(_ev(e, "actor", -1))
				if ke >= 0 and ke < S.fighters.size():
					var t_em: float = S.T - float(S.tick - int(e.tick)) * (1.0 / 60.0)
					fighter(S, S.fighters[ke]).on_agency("embed", t_em, {"dur": float(_ev(e, "dur", 60.0)) / 60.0})
			"cue":
				var who: int = int(e.actor)
				if AnimData.agency.get("cue_kinds", []).has(String(e.kind)):
					var t_ag: float = S.T - float(S.tick - int(e.tick)) * (1.0 / 60.0)
					for ia in range(S.fighters.size()):
						if who < 0 or ia == who:
							fighter(S, S.fighters[ia]).on_agency(String(e.kind), t_ag, {})
				var t_cue: float = S.T - float(S.tick - int(e.tick)) * (1.0 / 60.0)   # the event's own time, not the end of the frame's
				for i in range(S.fighters.size()):
					if who < 0 or i == who:
						fighter(S, S.fighters[i]).on_cue(String(e.kind), S.T, t_cue)
					elif who >= 0 and step3_cues:
						fighter(S, S.fighters[i]).on_cue_other(String(e.kind), t_cue)
			"damage":
				var v: int = int(e.victim)
				if v >= 0 and v < S.fighters.size() and String(e.kind) != "impact":
					var vf = S.fighters[v]
					var a: int = int(e.attacker)
					var front: bool = true
					if a >= 0 and a < S.fighters.size():
						front = SimWrap.sdx(vf.x, S.fighters[a].x) * fighter(S, vf).vface > 0.0
					var dm := Vector2.ZERO
					if a >= 0 and a < S.fighters.size():
						var atk = S.fighters[a]
						var dw := Vector2(SimWrap.sdx(atk.x, vf.x), vf.y - atk.y)
						if dw.length() > 1.0:
							dm = Vector2(dw.x * fighter(S, vf).vface, dw.y).normalized()
					fighter(S, vf).on_hit(S.T, String(e.region), front, float(e.amount) / 70.0, String(e.kind), dm, float(e.amount) / 60.0, S.tick)
					if String(e.kind) == "guard" and a >= 0 and a < S.fighters.size():
						fighter(S, S.fighters[a]).on_blocked(S.T)


## A field of an event that may not exist yet (World's ground-contact events arrive with their fields; until then the event is not sent).
static func _ev(e, key: String, default):
	var v = e.get(key)
	return default if v == null else v


## Which frame a solve belongs to: the engine frame and the sim tick (tools step several ticks in one engine frame).
static func _frame_key(S: SimState) -> int:
	return Engine.get_process_frames() * 1000003 + S.tick
