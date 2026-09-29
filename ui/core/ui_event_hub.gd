class_name UiEventHub
extends RefCounted
## The HUD's brain: folds the sim's events (spec-wounds.md section 4) and state patches into fighter models, wound
## cards, barks, the banner and the director feed, and enforces the readability caps. It is a pure view model:
##   - it reads events and never writes the sim; it draws no random numbers (animation is time-driven);
##   - it is fed by the mock (ui/mock/ui_mock_feed.gd) today and by the sim's fx stream once the wear slice lands.
## Events arrive as Dictionaries or as objects with the same field names (the sim's FxEvent); see norm().
##
## Assumed event shapes (S1 in docs/architecture/wounds-plan.md fixes the first four; the rest are proposals, listed
## as a wish-list in docs/ui/hud-spec.md section 10 so the sim can match or the HUD can adapt):
##   region_stage {actor, region, stage[, internal]}   region_broken {actor, region}   brink_enter/brink_exit {actor}
##   rally {actor, region}   heat_stage {actor, stage}   boil_over {actor}   facade_crack {actor}   shame_stack {actor, n}
##   drop_act {actor}   revision_reprint {actor, revision[, region]}   hatch_open {actor, station, dur}   chip_stage {actor, stage}
##   fold_flicker / fold_start / unfold {}   finisher_start {actor, target}   ko {winner, loser}
##   window_open {actor, kind: parry|chain, dur[, n]}   cinematic_start {actor, kind, dur} / cinematic_end {}
##   lock_lost {actor[, dur]}   bark {speaker, text[, cues, priority, dur, setpiece]}   banner {text, col, dur}   shake {k}
##   state {actor, ...}  (a patch of the fields in UiFighterModel: stance, tier, momentum, charge, ego, hidden, ...)

enum Mode { NORMAL, HAZARD, CINEMATIC }

const REGION_IDS: Array = ["head", "core", "arms", "legs", "mantle"]
const STATION_IDS: Array = ["head", "chest", "back", "hip"]
const FEED_KEEP := 40
const PRIO_BREAK := 1
const PRIO_STAGE := 2
const PRIO_TOAST := 3


class Card:
	var slot: int = 0            # 0 or 1 (a fighter's column); -1 = a world card (top centre)
	var key: String = ""         # merge key: same key on the same slot updates one card instead of stacking a second
	var title: String = ""
	var sub: String = ""
	var region: String = ""      # the region highlighted in the card's body glyph ("" for none)
	var regions: Array = []      # a compressed card (facade cracks): the regions it lists
	var stage: int = -1          # 0..3 for the pattern chip, -1 for none
	var kind: String = "wound"   # wound, internal, state, world
	var priority: int = 2
	var age: float = 0.0
	var life: float = 1.5
	var wait: float = 0.0
	var shown: bool = false
	var fading: bool = false     # evicted early: the remaining life is the fade


class Bark:
	var slot: int = 0
	var text: String = ""
	var cues: Array = []         # [{at, gesture, intensity}]
	var priority: int = 2        # line-system.md: finisher 5, transformation 4, set piece 3, reaction 2, ambient 1
	var age: float = 0.0
	var dur: float = 2.0         # the hold after the text has finished revealing
	var setpiece: bool = false
	var reveal_time: float = 0.0
	var fired: int = 0           # how many cues have fired
	var wait: float = 0.0


var models: Array = []           # UiFighterModel
var cards: Array = []            # visible Card
var waiting: Array = []          # queued Card
var world_card: Card = null
var barks: Array = []            # visible Bark
var bark_wait: Array = []        # queued Bark
var feed: Array = []             # {t, tag, sub}
var banner: Dictionary = {}      # {text, col, dur, age} or empty
var struggle: Dictionary = {}    # the finisher struggle on the brink fighter: {actor, beats, half, resolve, t, res, end_t}
var toll: Dictionary = {"civilians": 0, "pop0": 0, "structures": 0, "craters": 0}
var mode: int = Mode.NORMAL
var cinematic_left: float = 0.0
var cinematic_kind: String = ""
var hazard_left: float = 0.0
var t_now: float = 0.0
var toll_age: float = 99.0       # seconds since the world toll last changed (the chip dims at rest)
var stats: Dictionary = {}       # counters for the readability tests and the demo's status line
var captions_on: bool = true
var reduced_motion: bool = false
var cap_limit: int = 99          # the host lowers this where the screen is small (portrait: one card per side)


func _init() -> void:
	reset()


func reset() -> void:
	cards.clear()
	waiting.clear()
	world_card = null
	barks.clear()
	bark_wait.clear()
	feed.clear()
	banner = {}
	struggle = {}
	toll = {"civilians": 0, "pop0": 0, "structures": 0, "craters": 0}
	toll_age = 99.0
	mode = Mode.NORMAL
	cinematic_left = 0.0
	cinematic_kind = ""
	hazard_left = 0.0
	t_now = 0.0
	stats = {"cards_shown": 0, "cards_merged": 0, "cards_dropped": 0, "cards_evicted": 0, "cards_withheld": 0,
		"barks_shown": 0, "barks_cut": 0, "barks_suppressed": 0, "toasts_skipped": 0, "max_cards_visible": 0,
		"max_barks_visible": 0, "events": 0}
	for m in models:
		m.reset_wounds()


## Set up the fighters: ids are readout profile ids; names are what the plates show.
func setup_fighters(ids: Array, names: Array) -> void:
	models.clear()
	for i in range(ids.size()):
		var m := UiFighterModel.new()
		m.setup(i, str(ids[i]), str(names[i]) if i < names.size() else "")
		models.append(m)
	reset()


func model(slot: int) -> UiFighterModel:
	if slot < 0 or slot >= models.size():
		return null
	return models[slot]


# --- Event intake -------------------------------------------------------------------------------------------------

const _FIELDS: Array = ["type", "actor", "target", "region", "stage", "internal", "n", "text", "dur", "k", "col", "kind",
	"station", "revision", "speaker", "cues", "priority", "setpiece", "winner", "loser", "chance", "survived", "attacker", "victim", "tier", "cover", "beats", "half_width", "resolve", "lead", "result", "action", "available", "dur_ticks", "clean_ticks"]


## Any event (a Dictionary, or an object with these properties such as the sim's FxEvent) as a Dictionary.
static func norm(e) -> Dictionary:
	if e is Dictionary:
		return e
	var d := {}
	if e is Object:
		for f in _FIELDS:
			var v = e.get(f)
			if v != null:
				d[f] = v
	return d


static func _region(v) -> String:
	if v is String:
		return v
	if v is int or v is float:
		var i := int(v)
		if i >= 0 and i < REGION_IDS.size():
			return REGION_IDS[i]
	return ""


static func _stage(v) -> int:
	if v is String:
		var i: int = UiLook.STAGE_NAMES.find(v)
		return maxi(0, i)
	if v is int or v is float:
		return clampi(int(v), 0, 3)
	return 0


static func _station(v) -> int:
	if v is String:
		return maxi(0, STATION_IDS.find(v))
	if v is int or v is float:
		return clampi(int(v), 0, 3)
	return 0


func consume_all(events: Array) -> void:
	for e in events:
		consume(e)


func consume(e) -> void:
	var d: Dictionary = norm(e)
	var type: String = str(d.get("type", ""))
	if type == "":
		return
	stats["events"] += 1
	var actor: int = int(d.get("actor", -1)) if d.has("actor") else -1
	var m: UiFighterModel = model(actor)
	match type:
		"match_start":
			reset()
		"state":
			patch(actor, d)
		"region_stage":
			_on_region_stage(m, d)
		"region_broken":
			if m != null:
				_set_region(m, _region(d.get("region")), 3, bool(d.get("internal", false)))
		"brink_enter":
			if m != null and not m.brink:
				m.brink = true
				m.brink_age = 0.0
				_pop(m, UiLook.CROWN_HOLD_MAJOR)
				_card(m.slot, "brink", UiData.t("card.brink"), "", "", -1, "state", PRIO_BREAK)
		"brink_exit":
			if m != null:
				m.brink = false
				_pop(m, UiLook.CROWN_HOLD_MAJOR)
		"damage":
			# A hit does NOT pop the crown (Art's flashes own emotion; the crown owns wear, and wear is a stage change).
			# It only marks the region, for the silhouette's flash. The event's `number` is ignored: no numbers.
			var vf = d.get("victim", -1)
			if (vf is int or vf is float) and float(vf) >= 0.0:
				var vm: UiFighterModel = model(int(vf))
				if vm != null:
					vm.mark_hit(_region(d.get("region")))
		"rally":
			_on_rally(m, d)
		"heat_stage":
			_on_heat(m, int(d.get("stage", 0)))
		"boil_over":
			if m != null:
				_pop(m, UiLook.CROWN_HOLD_MAJOR)
			if m != null:
				m.heat_stage = 0
				m.boil_flash = 0.8
				_card(m.slot, "boil", UiData.t("card.boil_over"), "", "core", 3, "internal", PRIO_BREAK)
		"facade_crack":
			_on_facade(m)
		"shame_stack":
			if m != null:
				var was: int = m.shame
				m.shame = clampi(int(d.get("n", was + 1)), 0, 3)
				if m.shame > was:
					_card(m.slot, "shame", UiData.t("card.shame"), "", "", -1, "state", PRIO_TOAST)
		"drop_act":
			if m != null:
				m.unrestrained = true
				_card(m.slot, "drop_act", UiData.t("card.drop_act"), "", "", -1, "state", PRIO_BREAK)
		"revision_reprint":
			if m != null:
				m.revision = int(d.get("revision", m.revision + 1))
				var rr: String = _region(d.get("region"))
				if rr != "" and m.has_region(rr):
					m.patch_region = rr
					m.region_age[rr] = 0.0
					m.region_dir[rr] = -1
					m.stage[rr] = maxi(0, int(m.stage[rr]) - 1)
					m.true_stage[rr] = m.stage[rr]
		"hatch_open":
			if m != null:
				m.hatch_open = true
				m.hatch_t = 0.0
				m.chip_station = _station(d.get("station", m.chip_station))
				var st: String = UiData.t("station." + STATION_IDS[m.chip_station])
				_card(m.slot, "hatch", UiData.fmt("card.hatch_open", {"station": st}), "", "", -1, "state", PRIO_STAGE)
		"hatch_close":
			if m != null:
				m.hatch_open = false
		"chip_stage":
			if m != null:
				var cs: int = clampi(int(d.get("stage", 0)), 0, 3)
				var worse: bool = cs > m.chip_stage
				m.chip_stage = cs
				if worse and cs > 0:
					_card(m.slot, "chip", UiData.fmt("card.chip_stage", {"stage": UiData.t("chip_stage." + str(cs))}), "", "", cs, "state", PRIO_BREAK if cs >= 2 else PRIO_STAGE)
		"fold_flicker":
			_world("fold", UiData.t("card.fold_flicker"))
		"fold_start":
			_world("fold", UiData.t("card.fold_start"))
			_cinematic(-1, "fold", _dur(d, 4.0))
		"unfold":
			_world("fold", UiData.t("card.unfold"))
		"finisher_start":
			_cinematic(actor, "finisher", _dur(d, 3.0))
		"ko":
			var lo: UiFighterModel = model(int(d.get("loser", -1)))
			if lo != null:
				lo.ko = true
			_cinematic(int(d.get("winner", -1)), "ko", _dur(d, 3.0))
		"cinematic_start":
			_cinematic(actor, _kind(d, "transformation"), _dur(d, 2.5))
		"cinematic_end":
			cinematic_left = 0.0
			cinematic_kind = ""
			for mm in models:
				mm.cinematic = ""
		"window_open":
			_on_window(m, d)
		"chain":
			if m != null:
				m.chain_n = int(d.get("n", m.chain_n))
				m.chain_t = 0.0
				m.chain_dur = float(d.get("dur", 0.6))
		"lock_lost":
			if m != null and UiData.feature("hiding"):
				m.lost_trail = true
				_lost_trail_left[m.slot] = float(d.get("dur", 2.0))
		"struggle_open":
			_on_struggle_open(d)
		"finisher_contest":
			if not struggle.is_empty():
				struggle["end_t"] = float(struggle["t"])
		"press_ack":
			_on_press_ack(m, d)
		"availability":
			if m != null:
				var act: String = str(d.get("action", ""))
				if m.avail.has(act):
					m.avail[act] = bool(d.get("available", true)) if d.get("available") != null else true
		"bark":
			_on_bark(d)
		"banner":
			banner = {"text": UiData.banner(str(d.get("text", ""))), "col": str(d.get("col", UiLook.INK)), "dur": float(d.get("dur", 1.4)), "age": 0.0}
		"shake":
			if float(d.get("k", 0.0)) >= UiLook.HAZARD_SHAKE_K:
				hazard_left = UiLook.HAZARD_HOLD
		"world":
			var before: Array = [toll["civilians"], toll["structures"], toll["craters"]]
			toll["civilians"] = int(d.get("civilians", toll["civilians"]))
			toll["pop0"] = int(d.get("pop0", toll["pop0"]))
			toll["structures"] = int(d.get("structures", toll["structures"]))
			toll["craters"] = int(d.get("craters", toll["craters"]))
			if before != [toll["civilians"], toll["structures"], toll["craters"]] and t_now > 0.0:
				toll_age = 0.0
		# Events the HUD deliberately does not draw (docs/ui/hud-spec.md section 9): the Empress's paperwork is diegetic
		# only (Orb), the Encore's mend gauge reads through her posture, damage numbers would be a health bar in disguise.
		"revision_fill_reset", "encore_start", "encore_end", "guard_fall", "spark", "ring", \
		"debris", "dust", "splash", "fire", "after", "charge", "crater", "scorch", "beamSplash", "tick":
			pass
		_:
			pass


var _lost_trail_left: Dictionary = {}


func patch(actor: int, d: Dictionary) -> void:
	var m: UiFighterModel = model(actor)
	if m == null:
		return
	var old_stance: int = m.stance
	for k in ["stance", "tier", "charge", "momentum", "ego", "hidden", "charging", "sig_cost", "name", "title", "ai", "chip_station", "device"]:
		if d.has(k):
			# Hiding is removed from the base game (a future fighter); with the flag off the hidden state is ignored.
			m.set(k, (bool(d[k]) and UiData.feature("hiding")) if k == "hidden" else d[k])
	if d.has("aura") and d["aura"] is Color:
		m.aura = d["aura"]
	elif d.has("aura") and d["aura"] is String:
		m.aura = UiLook.col(d["aura"])
	if d.has("stance"):
		m.stance = clampi(int(d["stance"]), 0, 3)
		if m.stance != old_stance:
			m.stance_prompt_t = 0.0   # the stance prompt shows for a moment whenever the stance changes
	for act in ["transform", "special"]:
		if d.has("hold_" + act):
			m.hold[act] = clampf(float(d["hold_" + act]), 0.0, 1.0)
		if d.has("avail_" + act):
			m.avail[act] = bool(d["avail_" + act])
	if d.has("tier"):
		m.tier = clampi(int(d["tier"]), 1, 4)
	if d.has("wear") and d["wear"] is Dictionary:
		for r in d["wear"]:
			if m.has_region(r):
				m.wear[r] = float(d["wear"][r])


func feed_line(t: float, tag: String, sub: String) -> void:
	feed.append({"t": t, "tag": tag, "sub": sub})
	while feed.size() > FEED_KEEP:
		feed.pop_front()


# --- Wounds -------------------------------------------------------------------------------------------------------

func _on_region_stage(m: UiFighterModel, d: Dictionary) -> void:
	if m == null:
		return
	var r: String = _region(d.get("region"))
	if r == "" or not m.has_region(r):
		return
	_set_region(m, r, _stage(d.get("stage")), bool(d.get("internal", false)))


func _set_region(m: UiFighterModel, r: String, st: int, internal: bool) -> void:
	if r == "" or not m.has_region(r):
		return
	if internal:
		var was_i: int = m.internal_stage
		m.internal_stage = st
		if st > was_i and st > 0:
			_pop(m, UiLook.CROWN_HOLD_STAGE)
			var word: String = UiData.t("internal_stage." + UiLook.STAGE_NAMES[st])
			_card(m.slot, "internal", UiData.fmt("card.internal", {"region": UiData.t("region.core"), "stage": word}), "", "core", st, "internal", PRIO_BREAK if st == 3 else PRIO_STAGE)
		return
	var prev_true: int = int(m.true_stage[r])
	m.true_stage[r] = st
	var drawn: int = _masked(m, st)
	var prev_drawn: int = int(m.stage[r])
	if drawn != prev_drawn:
		m.stage[r] = drawn
		m.region_age[r] = 0.0
		m.region_dir[r] = 1 if drawn > prev_drawn else -1
	if st <= prev_true:
		return   # a recovery: the crown and silhouette update quietly, cards announce only what got worse
	if drawn < st:
		stats["cards_withheld"] += 1   # the Proud front holds: a battered or bruised card is withheld (spec section 3)
		return
	_pop(m, UiLook.CROWN_HOLD_MAJOR if st == 3 else UiLook.CROWN_HOLD_STAGE)
	_stage_card(m, r, st)


func _masked(m: UiFighterModel, st: int) -> int:
	if m.pride_holds and st < 3:
		return 0
	return st


func _stage_card(m: UiFighterModel, r: String, st: int) -> void:
	if st <= 0:
		return
	var title: String = UiData.fmt("card.region_stage", {"region": UiData.t("region." + r), "stage": UiData.t("stage." + UiLook.STAGE_NAMES[st])})
	var prio: int = PRIO_BREAK if st == 3 else (PRIO_STAGE if st == 2 else PRIO_TOAST)
	_card(m.slot, r, title, "", r, st, "wound", prio)


func _on_rally(m: UiFighterModel, d: Dictionary) -> void:
	if m == null:
		return
	var r: String = _region(d.get("region"))
	if r != "" and m.has_region(r):
		m.stage[r] = 2
		m.true_stage[r] = 2
		m.region_age[r] = 0.0
		m.region_dir[r] = -1
	m.brink = false
	_pop(m, UiLook.CROWN_HOLD_MAJOR)
	var key: String = "card.rally." + m.id
	var title: String = UiData.t(key)
	if title == key:
		title = UiData.t("card.rally")
	_card(m.slot, "rally", title, "", r, 2, "state", PRIO_BREAK)


func _on_heat(m: UiFighterModel, st: int) -> void:
	if m == null:
		return
	var up: bool = st > m.heat_stage
	m.heat_stage = clampi(st, 0, 3)
	if up and st > 0:
		_card(m.slot, "heat", UiData.t("card.heat." + str(st)), "", "core", -1, "internal", PRIO_STAGE)


func _on_facade(m: UiFighterModel) -> void:
	if m == null or not m.pride_holds:
		return
	m.pride_holds = false
	m.facade_age = 0.0
	_pop(m, UiLook.CROWN_HOLD_MAJOR)
	var listed: Array = []
	for r in m.regions:
		var tr: int = int(m.true_stage[r])
		if tr != int(m.stage[r]):
			m.stage[r] = tr
			m.region_age[r] = 0.0
			m.region_dir[r] = 1
			if tr > 0:
				listed.append(r)
	var c := _card(m.slot, "facade", UiData.t("card.facade_crack"), "", "", -1, "wound", PRIO_BREAK)
	if c != null:
		c.regions = listed
		c.sub = " · ".join(listed.map(func(x): return UiData.t("region." + x)))


# --- Windows, cinematics, barks -----------------------------------------------------------------------------------

const TICK := 1.0 / 60.0
const STRUGGLE_BEATS: Array = [-18, 0, 18, 36, 54]   # docs/controls/rulings.md section 8: count-in at -18 and 0, scored 18, 36, 54


## The finisher struggle opens for the fighter on the brink (Controls, rulings section 8). Beats are ticks relative to
## contestOpen; those at or below 0 are the count-in (shown, not scored). half_width is +-4 ticks, +-8 with the assist.
## The event arrives `lead` ticks (18) before contestOpen, so the count-in rings can close.
func _on_struggle_open(d: Dictionary) -> void:
	var beats: Array = d.get("beats") if d.get("beats") is Array and not (d.get("beats") as Array).is_empty() else STRUGGLE_BEATS.duplicate()
	var half: int = int(d.get("half_width", 0))
	var lead: int = int(d.get("lead", 0))
	var res: Dictionary = {}
	for b in beats:
		res[int(b)] = "" if int(b) > 0 else "count"
	struggle = {"actor": int(d.get("actor", -1)), "beats": beats, "half": half if half > 0 else 4, "resolve": int(d.get("resolve", 0)) if int(d.get("resolve", 0)) > 0 else 66,
		"t": -float(lead if lead > 0 else 18) * TICK, "res": res, "end_t": -1.0}


## A press was acknowledged (Controls): a small mark at the fighter for a moment. During the struggle a hit also marks its beat.
func _on_press_ack(m: UiFighterModel, d: Dictionary) -> void:
	if m == null:
		return
	var result: String = str(d.get("result", ""))
	if result == "":
		return
	m.ack_result = result
	m.ack_t = 0.0
	if not struggle.is_empty() and int(struggle["actor"]) == m.slot and result == "hit":
		var now: float = float(struggle["t"]) / TICK
		var best: int = 99999
		var best_d: float = 1e9
		for b in struggle["res"]:
			if int(b) > 0 and struggle["res"][b] == "" and absf(now - float(b)) < best_d:
				best = int(b)
				best_d = absf(now - float(b))
		if best != 99999 and best_d <= float(struggle["half"]) + 3.0:
			struggle["res"][best] = "hit"


func _step_struggle(dt: float) -> void:
	if struggle.is_empty():
		return
	struggle["t"] = float(struggle["t"]) + dt
	var now: float = float(struggle["t"]) / TICK
	for b in struggle["res"]:
		if int(b) > 0 and struggle["res"][b] == "" and now > float(b) + float(struggle["half"]) + 1.0:
			struggle["res"][b] = "miss"
	var end_t: float = float(struggle["end_t"])
	if (end_t >= 0.0 and float(struggle["t"]) - end_t > 0.5) or now > float(struggle["resolve"]) + 30.0:
		struggle = {}


func _on_window(m: UiFighterModel, d: Dictionary) -> void:
	if m == null:
		return
	var kind: String = _kind(d, "parry")
	var ticks: int = int(d.get("dur_ticks", 0))
	var dur: float = float(ticks) / 60.0 if ticks > 0 else _dur(d, 0.33 if kind == "parry" else 0.6)
	if kind == "parry":
		m.parry_t = 0.0
		m.parry_dur = dur
		# The clean-parry tail (Controls: the last 6 or 8 ticks): its share of the window, drawn as a brighter band.
		var clean: int = int(d.get("clean_ticks", 0))
		m.parry_clean = clampf(float(clean) / float(ticks), 0.0, 1.0) if (ticks > 0 and clean > 0) else 0.0
	else:
		m.chain_t = 0.0
		m.chain_dur = dur
		var n: int = int(d.get("n", 0))
		if n > 0:
			m.chain_n = n


## The kinds of respected cinematic in which the surge owns the fighter and the crown stays down (Art, marked-aura.md).
const TRANSFORM_KINDS: Array = ["transformation", "revision"]


## True while a transformation cinematic runs: no crown pops, and any crown showing fades out in 0.1 s.
func crown_locked() -> bool:
	return cinematic_left > 0.0 and TRANSFORM_KINDS.has(cinematic_kind)


## Pop a fighter's crown, unless a transformation cinematic holds it down.
func _pop(m: UiFighterModel, hold: float) -> void:
	if m != null and not crown_locked():
		m.pop(hold)


## For Rendering's flash arbitration (Art: never a flash and a crown up together): is this fighter's crown up, that is
## popped or fading out? `crown_always` (an accessibility option) keeps it up, so no flash then.
func crown_up(actor: int) -> bool:
	var m: UiFighterModel = model(actor)
	if m == null:
		return false
	if crown_locked():
		return false
	return m.crown_hold > 0.0 or m.crown_a > 0.02


## The sim's FxEvent objects carry every field with a default (dur 0.0, kind ""), so an unset value must read as absent.
static func _dur(d: Dictionary, default: float) -> float:
	var v: float = float(d.get("dur", 0.0))
	return v if v > 0.0 else default


static func _kind(d: Dictionary, default: String) -> String:
	var k: String = str(d.get("kind", ""))
	return k if k != "" else default


func _cinematic(slot: int, kind: String, dur: float) -> void:
	cinematic_left = maxf(cinematic_left, dur)
	cinematic_kind = kind
	var m: UiFighterModel = model(slot)
	if m != null:
		m.cinematic = kind


func _on_bark(d: Dictionary) -> void:
	var b := Bark.new()
	b.slot = clampi(int(d.get("speaker", 0)), 0, maxi(0, models.size() - 1))
	b.text = str(d.get("text", ""))
	b.cues = d.get("cues", []) if d.get("cues", []) is Array else []
	b.setpiece = bool(d.get("setpiece", false))
	b.priority = int(d.get("priority", 3 if b.setpiece else 2))
	if b.text == "":
		return
	b.reveal_time = UiBarkTiming.reveal_total(b.text, _intensity_of(b))
	var hold: float = clampf(0.9 + 0.035 * b.text.length(), UiLook.BARK_MIN, UiLook.BARK_MAX)
	if d.has("dur"):
		hold = float(d["dur"])
	if b.setpiece:
		hold = clampf(hold, 3.0, UiLook.BARK_SETPIECE_MAX)
	b.dur = hold
	# In a respected cinematic only set pieces and up speak (line-system.md: silence is a feature).
	if mode == Mode.CINEMATIC and b.priority < 3:
		stats["barks_suppressed"] += 1
		return
	# A fighter speaks one line at a time: a higher priority cuts a lower one, an equal or lower one waits.
	for v in barks:
		if v.slot == b.slot:
			if b.priority > v.priority:
				barks.erase(v)
				stats["barks_cut"] += 1
				break
			else:
				for w in bark_wait:
					if w.slot == b.slot:
						bark_wait.erase(w)
						break
				bark_wait.append(b)
				return
	barks.append(b)
	stats["barks_shown"] += 1
	_trim_barks()


func _intensity_of(b: Bark) -> int:
	if b.cues.is_empty():
		return 1
	return int((b.cues[0] as Dictionary).get("intensity", 1))


func _trim_barks() -> void:
	var cap: int = UiLook.CAP_BARK_LINES[mode]
	while barks.size() > cap:
		# Drop the lowest priority, oldest first.
		var worst = barks[0]
		for v in barks:
			if v.priority < worst.priority or (v.priority == worst.priority and v.age > worst.age):
				worst = v
		barks.erase(worst)
		stats["barks_cut"] += 1


# --- Cards --------------------------------------------------------------------------------------------------------

func _card(slot: int, key: String, title: String, sub: String, region: String, stage: int, kind: String, priority: int) -> Card:
	# Merge with a card that is already showing or waiting for the same thing (a wound card upgrades in place).
	for c in cards:
		if c.slot == slot and c.key == key:
			c.title = title
			c.sub = sub
			c.stage = stage
			c.region = region
			c.priority = mini(c.priority, priority)
			c.age = 0.0
			c.life = _life_for(c.priority)
			c.fading = false
			stats["cards_merged"] += 1
			return c
	for c in waiting:
		if c.slot == slot and c.key == key:
			c.title = title
			c.sub = sub
			c.stage = stage
			c.region = region
			c.priority = mini(c.priority, priority)
			stats["cards_merged"] += 1
			return c
	# A toast (a bruise) is only worth a line when nothing else is showing on that side.
	if priority == PRIO_TOAST:
		var busy := false
		for c in cards:
			if c.slot == slot and not c.fading:
				busy = true
		if busy or UiLook.CAP_TOASTS[mode] <= 0:
			stats["toasts_skipped"] += 1
			return null
	var n := Card.new()
	n.slot = slot
	n.key = key
	n.title = title
	n.sub = sub
	n.region = region
	n.stage = stage
	n.kind = kind
	n.priority = priority
	n.life = _life_for(priority)
	waiting.append(n)
	return n


func _world(key: String, title: String) -> void:
	var c := Card.new()
	c.slot = -1
	c.key = key
	c.title = title
	c.kind = "world"
	c.priority = PRIO_BREAK
	c.life = 1.8
	c.shown = true
	world_card = c
	stats["cards_shown"] += 1


static func _life_for(priority: int) -> float:
	if priority == PRIO_BREAK:
		return UiLook.CARD_LIFE_BROKEN
	if priority == PRIO_TOAST:
		return UiLook.CARD_TOAST_LIFE
	return UiLook.CARD_LIFE


func cards_of(slot: int) -> Array:
	var out: Array = []
	for c in cards:
		if c.slot == slot:
			out.append(c)
	return out


func card_alpha(c: Card) -> float:
	var a: float = clampf(c.age / 0.08, 0.0, 1.0)
	var left: float = c.life - c.age
	if left < UiLook.CARD_FADE:
		a = minf(a, clampf(left / UiLook.CARD_FADE, 0.0, 1.0))
	return a


# --- Time ---------------------------------------------------------------------------------------------------------

func advance(dt: float) -> void:
	t_now += dt
	toll_age += dt
	_step_struggle(dt)
	for m in models:
		m.advance(dt)
		if _lost_trail_left.has(m.slot):
			_lost_trail_left[m.slot] -= dt
			if _lost_trail_left[m.slot] <= 0.0:
				_lost_trail_left.erase(m.slot)
				m.lost_trail = false
	cinematic_left = maxf(0.0, cinematic_left - dt)
	hazard_left = maxf(0.0, hazard_left - dt)
	if crown_locked():
		for lm in models:
			lm.crown_hold = 0.0
			lm.crown_a = move_toward(lm.crown_a, 0.0, dt / 0.1)
	if cinematic_left <= 0.0 and cinematic_kind != "":
		cinematic_kind = ""
		for m in models:
			m.cinematic = ""
	var new_mode: int = Mode.CINEMATIC if cinematic_left > 0.0 else (Mode.HAZARD if hazard_left > 0.0 else Mode.NORMAL)
	mode = new_mode
	if not banner.is_empty() and world_card == null:
		banner["age"] = float(banner["age"]) + dt
		if float(banner["age"]) > float(banner["dur"]):
			banner = {}
	if world_card != null:
		world_card.age += dt
		if world_card.age > world_card.life:
			world_card = null
	_age_cards(dt)
	_age_barks(dt)
	_schedule_cards(dt)
	stats["max_cards_visible"] = maxi(stats["max_cards_visible"], cards.size())
	stats["max_barks_visible"] = maxi(stats["max_barks_visible"], barks.size())


func _age_cards(dt: float) -> void:
	var keep: Array = []
	for c in cards:
		c.age += dt
		if c.age < c.life:
			keep.append(c)
	cards = keep
	var still: Array = []
	for c in waiting:
		c.wait += dt
		var limit: float = UiLook.CARD_WAIT_BREAK if c.priority == PRIO_BREAK else UiLook.CARD_WAIT_MAX
		if c.wait <= limit:
			still.append(c)
		else:
			stats["cards_dropped"] += 1
	waiting = still


func _age_barks(dt: float) -> void:
	var keep: Array = []
	for b in barks:
		b.age += dt
		_fire_cues(b)
		if b.age < b.reveal_time + b.dur:
			keep.append(b)
	barks = keep
	# A queued line takes the place of a finished one for its speaker; a line that waited too long is dropped.
	var still: Array = []
	for w in bark_wait:
		w.wait += dt
		var taken := false
		for v in barks:
			if v.slot == w.slot:
				taken = true
		if not taken and barks.size() < UiLook.CAP_BARK_LINES[mode] and not (mode == Mode.CINEMATIC and w.priority < 3):
			barks.append(w)
			stats["barks_shown"] += 1
		elif w.wait < 1.5:
			still.append(w)
	bark_wait = still
	_trim_barks()


func _fire_cues(b: Bark) -> void:
	while b.fired < b.cues.size():
		var c: Dictionary = b.cues[b.fired]
		var at_char: int = int(c.get("at", 0))
		if UiBarkTiming.time_for_char(b.text, at_char, _intensity_of(b)) > b.age:
			break
		b.fired += 1
		var m: UiFighterModel = model(b.slot)
		if m != null:
			m.cue = 0.0
			m.cue_intensity = clampi(int(c.get("intensity", 1)), 0, 3)


func _schedule_cards(dt: float) -> void:
	var cap: int = mini(UiLook.CAP_CARDS_PER_SIDE[mode], cap_limit)
	for slot in range(models.size()):
		var vis: Array = cards_of(slot)
		# The mode shrank the cap (a cinematic began): retire extras now, lowest priority and oldest first.
		var live: Array = vis.filter(func(c): return not c.fading)
		while live.size() > cap:
			var worst = live[0]
			for c in live:
				if c.priority > worst.priority or (c.priority == worst.priority and c.age > worst.age):
					worst = c
			worst.fading = true
			worst.life = minf(worst.life, worst.age + UiLook.CARD_FADE)
			live.erase(worst)
			stats["cards_evicted"] += 1
		# Admit waiting cards for this side: breaks first, then stages, then older first.
		var queue: Array = waiting.filter(func(c): return c.slot == slot)
		queue.sort_custom(func(a, b): return a.priority < b.priority or (a.priority == b.priority and a.wait > b.wait))
		for c in queue:
			if live.size() >= cap:
				# A waiting break may push out a lower-priority card that has already had a moment on screen.
				if c.priority == PRIO_BREAK:
					var victim = null
					for v in live:
						if (v.priority > PRIO_BREAK and v.age >= 0.35) or (v.priority == PRIO_BREAK and v.age >= 0.8):
							if victim == null or v.priority > victim.priority or (v.priority == victim.priority and v.age > victim.age):
								victim = v
					if victim != null:
						victim.fading = true
						victim.life = minf(victim.life, victim.age + UiLook.CARD_FADE)
						live.erase(victim)
						stats["cards_evicted"] += 1
					else:
						continue
				else:
					continue
			waiting.erase(c)
			c.shown = true
			c.age = 0.0
			cards.append(c)
			live.append(c)
			stats["cards_shown"] += 1
