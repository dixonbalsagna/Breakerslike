class_name UiMockFeed
extends RefCounted
## A scripted stand-in for the sim's event stream, shaped like spec-wounds.md section 4's events, so the HUD can be built
## and reviewed before Simulation's wear slice lands. Events are plain Dictionaries in the shapes the hub documents
## (ui/core/ui_event_hub.gd). The feed loops. A "stress" scenario floods the HUD to test the readability caps.
##
## Scenarios: "hero_vs_proud" (the Protagonist against the Anti-hero: heat track, Pride mask, shame, facade crack, Rally),
##            "empress_vs_cyborg" (mantle, revision reprint, chip rail, hatch, regrowth),
##            "placeholders" (the greybox fighters KAI and VORR), "stress" (a seeded flood).
## Uses its own seeded generator: nothing here touches the sim's random streams.

const SCENARIOS: Array = ["hero_vs_proud", "empress_vs_cyborg", "placeholders", "stress"]

var scenario: String = "hero_vs_proud"
var t: float = 0.0
var length: float = 40.0
var _events: Array = []      # [[time, event]]
var _i: int = 0
var _rng := RandomNumberGenerator.new()


static func fighters(scn: String) -> Array:
	match scn:
		"empress_vs_cyborg":
			return [["empress", "cyborg"], ["THE EMPRESS", "THE CYBORG"]]
		"placeholders":
			return [["kai", "vorr"], ["KAI", "VORR"]]
		"stress":
			return [["protagonist", "anti_hero"], ["PROTAGONIST", "ANTI-HERO"]]
	return [["protagonist", "anti_hero"], ["PROTAGONIST", "ANTI-HERO"]]


func _init(p_scenario: String = "hero_vs_proud", p_seed: int = 7) -> void:
	scenario = p_scenario
	_rng.seed = p_seed
	_build()


func restart() -> void:
	t = 0.0
	_i = 0


## Events due in the next dt seconds (the feed loops at `length`).
func step(dt: float) -> Array:
	var out: Array = []
	var t1: float = t + dt
	while _i < _events.size() and float(_events[_i][0]) <= t1:
		out.append(_events[_i][1])
		_i += 1
	t = t1
	if t >= length:
		t = 0.0
		_i = 0
		out.append({"type": "match_start"})
	return out


func _e(time: float, ev: Dictionary) -> void:
	_events.append([time, ev])


func _st(time: float, actor: int, d: Dictionary) -> void:
	var ev: Dictionary = d.duplicate()
	ev["type"] = "state"
	ev["actor"] = actor
	_e(time, ev)


func _rs(time: float, actor: int, region: String, stage: String, internal: bool = false) -> void:
	_e(time, {"type": "region_stage", "actor": actor, "region": region, "stage": stage, "internal": internal})


func _bark(time: float, speaker: int, text: String, gesture: String, intensity: int, prio: int = 2, setpiece: bool = false, extra_at: int = -1, extra: String = "") -> void:
	var cues: Array = [{"at": 0, "gesture": gesture, "intensity": intensity}]
	if extra_at >= 0:
		cues.append({"at": extra_at, "gesture": extra, "intensity": intensity})
	_e(time, {"type": "bark", "speaker": speaker, "text": text, "cues": cues, "priority": prio, "setpiece": setpiece})


func _build() -> void:
	_events.clear()
	match scenario:
		"empress_vs_cyborg":
			_build_empress_cyborg()
		"placeholders":
			_build_placeholders()
		"stress":
			_build_stress()
		_:
			_build_hero_proud()
	_events.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	_i = 0


func _world(time: float, civ: int, structures: int, craters: int) -> void:
	_e(time, {"type": "world", "civilians": civ, "pop0": 425, "structures": structures, "craters": craters})


func _build_hero_proud() -> void:
	length = 46.0
	_e(0.0, {"type": "match_start"})
	_st(0.0, 0, {"stance": 0, "tier": 1, "charge": 30.0, "momentum": 20.0, "ego": 12.0, "aura": "#8fd6ff", "ai": false})
	_st(0.0, 1, {"stance": 1, "tier": 1, "charge": 40.0, "momentum": 45.0, "ego": 78.0, "aura": "#c9a8ff", "ai": true})
	_world(0.0, 0, 0, 0)
	_bark(0.8, 0, "Good. You came. Now show me everything.", "effort.light", 1)
	_bark(2.2, 1, "You were something once. Let me see what's left.", "scoff", 1)
	# A parry window on the Anti-hero, then a chain window on the Protagonist.
	_e(3.6, {"type": "window_open", "actor": 1, "kind": "parry", "dur": 0.33})
	_e(4.0, {"type": "banner", "text": "PARRY", "col": "#ffffff", "dur": 1.0})
	_e(4.3, {"type": "chain", "actor": 0, "n": 2, "dur": 0.7})
	_e(4.9, {"type": "chain", "actor": 0, "n": 3, "dur": 0.7})
	# Wounds on both. The Anti-hero's bruises and batters are withheld while his Pride holds; only breaks show.
	_rs(5.2, 1, "head", "bruised")
	_rs(5.6, 1, "arms", "battered")
	_rs(6.0, 0, "arms", "bruised")
	_rs(6.6, 0, "arms", "battered")
	_bark(6.8, 0, "Ha! My arm. I'll need that later.", "wince", 1)
	_rs(8.2, 1, "legs", "broken")
	_e(8.2, {"type": "region_broken", "actor": 1, "region": "legs"})
	_st(8.4, 0, {"stance": 2, "charge": 55.0, "momentum": 55.0})
	# The Protagonist's heat track and its internal core wear.
	_e(9.4, {"type": "heat_stage", "actor": 0, "stage": 1})
	_e(11.0, {"type": "heat_stage", "actor": 0, "stage": 2})
	_rs(11.6, 0, "core", "bruised", true)
	_e(13.0, {"type": "heat_stage", "actor": 0, "stage": 3})
	_rs(13.4, 0, "core", "battered", true)
	# A hazard: heavy shake, and a flood of wounds that the cap must thin.
	_e(14.0, {"type": "shake", "k": 16.0})
	_rs(14.1, 0, "head", "battered")
	_rs(14.2, 0, "legs", "battered")
	_rs(14.3, 0, "core", "battered")
	_e(14.8, {"type": "boil_over", "actor": 0})
	_e(14.8, {"type": "shake", "k": 18.0})
	_st(15.0, 0, {"charge": 80.0})
	# The Anti-hero is humbled: shame stacks.
	_e(16.4, {"type": "shame_stack", "actor": 1, "n": 1})
	_e(17.6, {"type": "shame_stack", "actor": 1, "n": 2})
	# A respected cinematic (a transformation): plates recede, letterbox in, set-piece line.
	_e(18.5, {"type": "cinematic_start", "actor": 1, "kind": "transformation", "dur": 3.0})
	_bark(18.6, 1, "Regalia. Now you'll know who was watching.", "roar", 3, 4, true)
	_bark(19.0, 0, "Wait for it...", "sigh", 1, 2, false)
	_rs(19.4, 0, "arms", "broken")
	_st(21.4, 1, {"tier": 2, "momentum": 5.0, "ego": 60.0})
	_e(21.6, {"type": "banner", "text": "VORR POWERS UP  TIER 2", "col": "#c9a8ff", "dur": 1.4})
	# The facade cracks, and Drop the Act fires with it.
	_st(23.0, 1, {"ego": 30.0})
	_e(23.2, {"type": "facade_crack", "actor": 1})
	_e(23.2, {"type": "drop_act", "actor": 1})
	_e(23.4, {"type": "banner", "text": "NEED 45 KI", "col": "#ffd45a", "dur": 1.2})
	# Brinks, a Rally, a hidden fighter and a lost trail.
	_rs(25.0, 1, "core", "broken")
	_e(25.0, {"type": "region_broken", "actor": 1, "region": "core"})
	_e(25.1, {"type": "brink_enter", "actor": 1})
	_e(27.0, {"type": "brink_enter", "actor": 0})
	_e(28.4, {"type": "rally", "actor": 0, "region": "arms"})
	_bark(28.6, 0, "I've been holding back on your behalf. Not anymore.", "growl", 2)
	_st(30.0, 0, {"stance": 3, "hidden": true})
	_e(30.4, {"type": "lock_lost", "actor": 1, "dur": 2.4})
	_st(34.0, 0, {"stance": 0, "hidden": false, "charging": true})
	_st(35.0, 0, {"charging": false, "charge": 90.0})
	# The finisher: a set piece, a KO.
	_e(37.0, {"type": "finisher_start", "actor": 0, "target": 1, "dur": 3.0})
	_bark(37.2, 0, "Best fight of my year. Rest. I'll carry you home.", "laugh.long", 2, 5, true, 26, "sigh")
	_e(40.0, {"type": "ko", "winner": 0, "loser": 1, "dur": 3.0})
	_world(40.0, 61, 9, 14)
	_e(40.2, {"type": "banner", "text": "K.O.  PROTAGONIST WINS", "col": "#ffffff", "dur": 2.4})


func _build_empress_cyborg() -> void:
	length = 40.0
	_e(0.0, {"type": "match_start"})
	_st(0.0, 0, {"stance": 0, "tier": 1, "charge": 50.0, "momentum": 30.0, "ego": 40.0, "aura": "#ff9ad0", "ai": true})
	_st(0.0, 1, {"stance": 2, "tier": 1, "charge": 35.0, "momentum": 10.0, "ego": 20.0, "aura": "#e0c14a", "ai": true})
	_world(0.0, 0, 0, 0)
	_bark(1.0, 0, "You struck us! Do you know what revision this is?", "shriek", 2, 2, false, 24, "snort")
	_bark(2.4, 1, "Welcome. Your order is you.", "chirp", 1)
	_rs(4.0, 0, "mantle", "bruised")
	_rs(5.0, 0, "mantle", "battered")
	_rs(6.0, 0, "arms", "bruised")
	# The Cyborg's flesh wears and regrows; the chip is the persistent state.
	_rs(6.6, 1, "arms", "battered")
	_rs(7.0, 1, "head", "battered")
	_rs(8.2, 1, "arms", "broken")
	_e(9.0, {"type": "hatch_open", "actor": 1, "station": 3, "dur": 1.5})
	_e(10.5, {"type": "hatch_close", "actor": 1})
	_e(9.6, {"type": "chip_stage", "actor": 1, "stage": 1})
	_e(11.0, {"type": "hatch_open", "actor": 1, "station": 1, "dur": 1.5})
	_e(11.8, {"type": "chip_stage", "actor": 1, "stage": 2})
	_e(12.5, {"type": "hatch_close", "actor": 1})
	_bark(11.9, 1, "Not the chip! Anything but the chip!", "static", 3)
	_rs(13.0, 1, "arms", "battered")     # regrowth: the crown crawls back
	_rs(14.5, 1, "arms", "bruised")
	_rs(16.0, 1, "arms", "fresh")
	_rs(16.0, 1, "head", "bruised")
	# The Empress's revisions: a reprint per real revision, no paperwork on screen. Guard falls are not drawn.
	_e(17.0, {"type": "guard_fall", "actor": 0})
	_e(18.0, {"type": "cinematic_start", "actor": 0, "kind": "revision", "dur": 2.5})
	_e(18.1, {"type": "revision_reprint", "actor": 0, "revision": 9, "region": "arms"})
	_bark(18.2, 0, "Revision Nine. We have added a hat. Do not ask about the paperwork.", "sigh.heavy", 2, 4, true)
	_st(20.6, 0, {"tier": 3, "momentum": 0.0, "ego": 15.0})
	_rs(22.0, 0, "core", "battered")
	_rs(23.0, 0, "legs", "broken")
	_e(23.0, {"type": "region_broken", "actor": 0, "region": "legs"})
	_rs(24.0, 0, "head", "broken")
	_e(24.0, {"type": "region_broken", "actor": 0, "region": "head"})
	_e(24.1, {"type": "brink_enter", "actor": 0})
	_e(26.0, {"type": "encore_start", "actor": 0})
	_e(30.0, {"type": "rally", "actor": 0, "region": "head"})
	_e(30.1, {"type": "revision_reprint", "actor": 0, "revision": 10, "region": "head"})
	_st(32.0, 1, {"charge": 90.0, "ego": 88.0})
	_rs(33.0, 1, "core", "battered")
	_e(34.0, {"type": "fold_flicker"})
	_e(36.0, {"type": "finisher_start", "actor": 1, "target": 0, "dur": 3.0})
	_bark(36.2, 1, "Your order has been fulfilled. Please rate your experience.", "chirp", 2, 5, true)


func _build_placeholders() -> void:
	length = 20.0
	_e(0.0, {"type": "match_start"})
	_st(0.0, 0, {"stance": 0, "tier": 1, "charge": 60.0, "momentum": 40.0, "ego": 20.0, "aura": "#8fd6ff", "ai": true})
	_st(0.0, 1, {"stance": 1, "tier": 1, "charge": 60.0, "momentum": 40.0, "ego": 35.0, "aura": "#ff5a3c", "ai": true})
	_world(0.0, 0, 0, 0)
	_rs(3.0, 0, "head", "bruised")
	_rs(5.0, 1, "arms", "battered")
	_rs(8.0, 0, "legs", "broken")
	_e(8.0, {"type": "region_broken", "actor": 0, "region": "legs"})
	_e(10.0, {"type": "brink_enter", "actor": 0})
	_bark(11.0, 1, "Bellgate was lovely.", "laugh.cruel", 2)
	_e(12.0, {"type": "window_open", "actor": 0, "kind": "parry", "dur": 0.33})
	_st(14.0, 0, {"stance": 3, "hidden": true})
	_e(14.4, {"type": "lock_lost", "actor": 1, "dur": 2.0})
	_st(17.0, 0, {"hidden": false})


func _build_stress() -> void:
	length = 30.0
	_e(0.0, {"type": "match_start"})
	_st(0.0, 0, {"stance": 0, "tier": 2, "charge": 70.0, "momentum": 50.0, "ego": 50.0, "aura": "#8fd6ff", "ai": true})
	_st(0.0, 1, {"stance": 1, "tier": 2, "charge": 70.0, "momentum": 50.0, "ego": 50.0, "aura": "#c9a8ff", "ai": true})
	var regions: Array = ["head", "core", "arms", "legs"]
	var stages: Array = ["bruised", "battered", "broken"]
	var n := 0
	var time := 0.5
	while time < 28.0:
		var burst: int = _rng.randi_range(1, 6)
		for k in range(burst):
			var actor: int = _rng.randi_range(0, 1)
			var r: String = regions[_rng.randi_range(0, 3)]
			var st: String = stages[_rng.randi_range(0, 2)]
			_rs(time + 0.02 * float(k), actor, r, st)
			if st == "broken" and _rng.randf() < 0.5:
				_e(time + 0.02 * float(k), {"type": "region_broken", "actor": actor, "region": r})
			n += 1
		if _rng.randf() < 0.3:
			_e(time, {"type": "shake", "k": _rng.randf_range(6.0, 24.0)})
		if _rng.randf() < 0.35:
			_bark(time, _rng.randi_range(0, 1), "That is one line and it keeps going for a while, doesn't it.", "growl", _rng.randi_range(0, 3), _rng.randi_range(1, 5), _rng.randf() < 0.2)
		if _rng.randf() < 0.1:
			_e(time, {"type": "cinematic_start", "actor": _rng.randi_range(0, 1), "kind": "transformation", "dur": _rng.randf_range(1.0, 3.0)})
		time += _rng.randf_range(0.05, 0.6)
