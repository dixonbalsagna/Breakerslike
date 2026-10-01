class_name SimLayout
extends RefCounted
## The layout layer for keyboards and pads (docs/controls/input-scheme.md, intent-v2.md): physical controls in, one
## intent v2 per fixed tick out. A preset from data/input/layouts.json says which control is which action; this class
## resolves tap against hold, the power layer and the transform chord in tick time, so the sim receives resolved
## requests and held states and never sees a device. It also writes today's dash and charge next to the v2 fields,
## because fighter.gd still reads them until I3, and leaves `stance` unset (a v2 slot's stance is derived from the held
## guard, dodge and sprint by SimAct).
##
## Engine-agnostic: no Input, no Node, no clock. The host feeds press, release, axis and analog as events arrive and
## calls build() once per fixed tick and consumed() when SimCore.step took the input (it does not on a hit-stop tick), so
## a press waits through a freeze as the old keyboard edges did.
##
## Rules (input-scheme.md section 3):
##  - a tap fires on press, with no delay: dodge, guard (and its perfect-block edge), light, heavy, signature, context,
##    mode and the power press all report on the tick they land;
##  - a hold adds behaviour on top: a dodge held for holdStart ticks is a sprint, power held for holdStart ticks is the
##    channel (charge), a power tap released before that is powerTap, and a layer press (power held plus a face button)
##    is a special or the signature and voids the pending tap;
##  - two triggers down within chordWindow ticks are the transform chord: no sprint, charge or tap comes from them, and
##    transform is sent once they have been held transformConfirm ticks. A single transform control does the same alone;
##  - a preset whose attack control has a hold gesture (the Simple layouts) fires its light on release and a heavy at
##    holdStart, because today's director cannot upgrade a request it has already started (touch-bridge.md).

## The held-attack bridge: true while the director starts an exchange the moment it gets a request. Encounter's queue
## (I2 later) turns it off, and a light then fires on press and the hold upgrades it.
const ATTACK_BRIDGE: bool = true

var preset_id: String = ""
var slot_flags: Dictionary = {}
var tick: int = 0

var _single: Dictionary = {}        # control -> Array of {action, layer, gesture}
var _chords: Array = []             # [{controls, action, active, since, sent}]
var _keys_move: Array = []          # four controls, up left down right, for a keyboard
var _stick_control: String = ""     # the pad stick's control id
var _hold_attack: Dictionary = {}   # control -> true when the preset gives it a hold gesture
var _transform_single: Dictionary = {}   # control -> true

var _down: Dictionary = {}          # control -> bool
var _as: Dictionary = {}            # control -> "base" or "layer": how the press was taken
var _press_tick: Dictionary = {}    # control -> tick of the press
var _held: Dictionary = {}          # base action -> controls holding it
var _aedge: Dictionary = {}         # action -> true: reported since the last consumed step
var _special_edge: int = 0
var _stick: Vector2 = Vector2.ZERO  # the pad stick, x right and y up
var _analog_down: Dictionary = {}   # trigger control -> bool (digital, with hysteresis)

var _dodge_t0: int = 0
var _power_t0: int = 0
var _power_voided: bool = false     # a layer press fired during this power hold
var _chorded: Dictionary = {}       # control -> true while its press is part of a chord
var _lunge_until: int = -1
var _lunge_seen: bool = false
var _tf_t0: Dictionary = {}         # single transform control -> press tick
var _tf_sent: Dictionary = {}
var _atk: Dictionary = {}           # hold-attack control -> {t0, fired}
var sprint_override: bool = false   # a host-side gesture held a sprint (the touch stick's outer ring)
var _mode: int = 0
var _mode_t: int = -1000
var _auto_mode: bool = false

# numbers, from data
var hold_start: int
var transform_confirm: int
var chord_window: int
var lunge_ticks: int
var mode_cooldown: int
var deadzone: float
var full_at: float
var quant: float
var trig_on: float
var trig_off: float


func _init(p_preset: Dictionary = {}) -> void:
	hold_start = SimInputData.ti(["tapHold", "holdStart"], 12)
	transform_confirm = SimInputData.ti(["tapHold", "transformConfirm"], 30)
	chord_window = SimInputData.ti(["tapHold", "chordWindow"], 6)
	lunge_ticks = SimInputData.ti(["dodge", "lungeTicks"], 12)
	mode_cooldown = SimInputData.ti(["mode", "toggleCooldown"], 12)
	deadzone = SimInputData.tf(["stick", "deadzone"], 0.2)
	full_at = SimInputData.tf(["stick", "fullAt"], 0.9)
	quant = float(SimInputData.ti(["stick", "quant"], 16))
	trig_on = SimInputData.tf(["stick", "triggerOn"], 0.35)
	trig_off = SimInputData.tf(["stick", "triggerOff"], 0.25)
	if not p_preset.is_empty():
		set_preset(p_preset)


## Take a preset (a dictionary from layouts.json) and index its bindings. Everything held is let go.
func set_preset(p: Dictionary) -> void:
	release_all()
	preset_id = str(p.get("id", ""))
	slot_flags = p.get("slot", {})
	_auto_mode = bool(slot_flags.get("autoMode", false))
	_mode = -1 if _auto_mode else 0
	_single.clear()
	_chords.clear()
	_keys_move.clear()
	_stick_control = ""
	_hold_attack.clear()
	_transform_single.clear()
	for b in p.get("bindings", []):
		var controls: Array = b["controls"]
		var action: String = str(b["action"])
		var layer = b.get("layer", null)
		var gesture = b.get("gesture", null)
		if action == "move":
			if b.has("axis") and controls.size() == 4:
				_keys_move = controls.duplicate()
			elif controls.size() == 1:
				_stick_control = str(controls[0])
			continue
		if action == "pause" or action == "hints":
			continue   # the host's, not the sim's
		if controls.size() > 1:
			_chords.append({"controls": controls.duplicate(), "action": action, "active": false, "since": 0, "sent": false})
			continue
		var c: String = str(controls[0])
		if not _single.has(c):
			_single[c] = []
		_single[c].append({"action": action, "layer": layer, "gesture": gesture})
		if gesture == "hold" and action == "upgrade_heavy":
			_hold_attack[c] = true
		if action == "transform" and layer == null:
			_transform_single[c] = true


## Whether a control is bound in this preset (the hub uses it to see which device is talking).
func has_control(c: String) -> bool:
	if _single.has(c) or c == _stick_control or _keys_move.has(c):
		return true
	for ch in _chords:
		if ch["controls"].has(c):
			return true
	return false


## Let go of everything: no stuck hold, no pending edge.
func release_all() -> void:
	_down.clear()
	_as.clear()
	_press_tick.clear()
	_held.clear()
	_aedge.clear()
	_special_edge = 0
	_stick = Vector2.ZERO
	_analog_down.clear()
	_power_voided = false
	_chorded.clear()
	_lunge_until = -1
	_lunge_seen = false
	_tf_t0.clear()
	_tf_sent.clear()
	_atk.clear()
	for ch in _chords:
		ch["active"] = false
		ch["sent"] = false


func _is_down(action: String) -> bool:
	return _held.get(action, []).size() > 0


func _hold_add(action: String, c: String) -> void:
	if not _held.has(action):
		_held[action] = []
	if not _held[action].has(c):
		_held[action].append(c)


func _hold_del(action: String, c: String) -> void:
	if _held.has(action):
		_held[action].erase(c)


## A control went down. Returns true if this preset uses it.
func press(c: String) -> bool:
	if not has_control(c):
		return false
	if _down.get(c, false):
		return true   # a repeat
	_down[c] = true
	_press_tick[c] = tick
	_chorded.erase(c)
	if _single.has(c):
		var power_layer: bool = _is_down("power")
		var took_layer: bool = false
		if power_layer:
			for b in _single[c]:
				if b["layer"] == "power":
					took_layer = true
					_layer_press(str(b["action"]))
		if took_layer:
			_as[c] = "layer"
		else:
			_as[c] = "base"
			for b in _single[c]:
				if b["layer"] == null and b["gesture"] == null:
					if _hold_attack.has(c) and str(b["action"]) == "light":
						continue   # a hold-attack control fires its light on release (or a heavy at holdStart)
					_base_press(str(b["action"]), c)
			if _hold_attack.has(c):
				_atk[c] = {"t0": tick, "fired": false}
	_check_chords(c)
	return true


## A control went up.
func release(c: String) -> void:
	if not _down.get(c, false):
		return
	_down[c] = false
	if _as.get(c, "") == "base" and _single.has(c):
		for b in _single[c]:
			if b["layer"] == null and b["gesture"] == null:
				_base_release(str(b["action"]), c)
		if _atk.has(c):
			if not _atk[c]["fired"]:
				_aedge["light"] = true   # a tap on a hold-attack control, taken on release (the bridge)
			_atk.erase(c)
	_as.erase(c)
	_tf_t0.erase(c)
	_tf_sent.erase(c)
	for ch in _chords:
		if ch["controls"].has(c) and ch["active"]:
			ch["active"] = false
			ch["sent"] = false
	_chorded.erase(c)


## An analog trigger or a similar 0 to 1 control, made digital with hysteresis (stick.triggerOn and triggerOff).
func analog(c: String, v: float) -> void:
	var on: bool = _analog_down.get(c, false)
	if not on and v >= trig_on:
		_analog_down[c] = true
		press(c)
	elif on and v <= trig_off:
		_analog_down[c] = false
		release(c)


## The pad stick, x right and y up, each -1 to 1 as the device reports it.
func axis(c: String, x: float, y: float) -> void:
	if c == _stick_control:
		_stick = Vector2(x, y)


func _layer_press(action: String) -> void:
	_power_voided = true
	match action:
		"special1": _special_edge = 1
		"special2": _special_edge = 2
		"special3": _special_edge = 3
		"special_auto": _special_edge = 7
		"signature": _aedge["signature"] = true


func _base_press(action: String, c: String) -> void:
	match action:
		"guard":
			_hold_add("guard", c)
			_aedge["guardPress"] = true
		"dodge":
			_hold_add("dodge", c)
			_aedge["dodge"] = true
			_dodge_t0 = tick
		"power":
			_hold_add("power", c)
			_aedge["powerPress"] = true
			_power_t0 = tick
			_power_voided = false
		"transform":
			_tf_t0[c] = tick
		"mode":
			_aedge["mode"] = true
		"light", "heavy", "signature", "context":
			_aedge[action] = true


func _base_release(action: String, c: String) -> void:
	match action:
		"guard", "dodge":
			_hold_del(action, c)
		"power":
			_hold_del("power", c)
			if not _is_down("power") and not _power_voided and not _chorded.get(c, false) and tick - _power_t0 < hold_start:
				_aedge["powerTap"] = true


func _check_chords(c: String) -> void:
	for ch in _chords:
		if not ch["controls"].has(c):
			continue
		var all_down := true
		var lo: int = 1 << 30
		var hi: int = -(1 << 30)
		for k in ch["controls"]:
			if not _down.get(k, false):
				all_down = false
				break
			var pt: int = int(_press_tick.get(k, tick))
			lo = mini(lo, pt)
			hi = maxi(hi, pt)
		if all_down and hi - lo <= chord_window and not ch["active"]:
			ch["active"] = true
			ch["since"] = tick
			ch["sent"] = false
			for k in ch["controls"]:
				_chorded[k] = true


func _chord_active_on(action: String) -> bool:
	for ch in _chords:
		if ch["active"]:
			for k in ch["controls"]:
				if _held.get(action, []).has(k):
					return true
	return false


func _axis_value(a: float) -> float:
	var m: float = absf(a)
	if m <= deadzone:
		return 0.0
	var s: float = clampf((m - deadzone) / (full_at - deadzone), 0.0, 1.0)
	s = roundf(s * quant) / quant
	return s if a > 0.0 else -s


## One fixed tick: advance the clock and return the intent v2 for it.
func build() -> SimIntent:
	tick += 1
	var i := SimIntent.new()
	# Move: a pad stick through the dead zone and the per-axis gate; keys as +-1, as the keyboard always was.
	if _stick_control != "":
		i.mx = _axis_value(_stick.x)
		i.my = _axis_value(_stick.y)
	elif _keys_move.size() == 4:
		i.my = (1.0 if _down.get(_keys_move[0], false) else 0.0) - (1.0 if _down.get(_keys_move[2], false) else 0.0)
		i.mx = (1.0 if _down.get(_keys_move[3], false) else 0.0) - (1.0 if _down.get(_keys_move[1], false) else 0.0)
	# Held attack controls (the Simple layouts): a heavy at holdStart.
	for c in _atk:
		var a: Dictionary = _atk[c]
		if not a["fired"] and tick - int(a["t0"]) >= hold_start:
			a["fired"] = true
			_aedge["heavy"] = true
	# The transform: a chord counted from when both were down, or a single control held.
	var tf: bool = false
	for ch in _chords:
		if ch["action"] == "transform" and ch["active"] and not ch["sent"] and tick - int(ch["since"]) >= transform_confirm:
			ch["sent"] = true
			tf = true
	for c in _tf_t0:
		if _down.get(c, false) and not _tf_sent.get(c, false) and tick - int(_tf_t0[c]) >= transform_confirm:
			_tf_sent[c] = true
			tf = true
	i.transform = tf
	# Guard: held, and its press edge for the perfect block.
	i.guard = _is_down("guard")
	i.guardPress = _aedge.has("guardPress")
	# Dodge: the edge on press, a free lunge (today's dash) for lungeTicks, a sprint once held holdStart ticks.
	var chord_dodge: bool = _chord_active_on("dodge")
	i.dodge = _aedge.has("dodge")
	if i.dodge and not _lunge_seen:
		_lunge_seen = true
		_lunge_until = tick + lunge_ticks
	var sprinting: bool = (_is_down("dodge") and tick - _dodge_t0 >= hold_start and not chord_dodge) or sprint_override
	i.sprint = sprinting
	# Power: held, its press, the tap on release, and the channel once held holdStart ticks.
	var chord_power: bool = _chord_active_on("power")
	i.power = _is_down("power") and not chord_power
	i.powerPress = _aedge.has("powerPress")
	i.powerTap = _aedge.has("powerTap")
	var channel: bool = _is_down("power") and tick - _power_t0 >= hold_start and not chord_power and not _power_voided
	# Attacks, the layer and the rest: edges as they landed.
	i.light = _aedge.has("light")
	i.heavy = _aedge.has("heavy")
	i.sig = _aedge.has("signature")
	i.context = _aedge.has("context")
	i.special = _special_edge
	# Mode: a toggle with a cooldown, sent every tick; -1 when the layout leaves it to the director.
	if _aedge.has("mode") and not _auto_mode and tick - _mode_t >= mode_cooldown:
		_mode = 1 - _mode
		_mode_t = tick
	i.mode = _mode
	# Today's fields, until I3: a lunge or a sprint is the dash, the channel is the charge.
	i.dash = sprinting or tick <= _lunge_until
	i.charge = channel
	i.stance = -1.0
	return i


## The transform's hold progress, 0 to 1: the chord counted from when both triggers went down, or a single transform
## control held, whichever is further along. 0 when none is held. Read-only, for UI's Transform ring.
func transform_hold() -> float:
	var best: float = 0.0
	for ch in _chords:
		if ch["action"] == "transform" and ch["active"]:
			best = maxf(best, clampf(float(tick - int(ch["since"])) / float(transform_confirm), 0.0, 1.0))
	for c in _tf_t0:
		if _down.get(c, false):
			best = maxf(best, clampf(float(tick - int(_tf_t0[c])) / float(transform_confirm), 0.0, 1.0))
	return best


## A pausing set piece froze the sim: whatever was pressed meanwhile is dropped (call each frozen tick, or once when it
## ends) so a pile of presses is not released at once.
func drop_edges() -> void:
	consumed()


## The pause ended: edges are dropped and every hold is read again as if it began now, so a sprint, a channel or the
## transform count starts fresh from what is still held, and nothing that was only pressed during the pause fires.
func resume() -> void:
	drop_edges()
	for c in _down:
		if _down[c]:
			_press_tick[c] = tick
	_dodge_t0 = tick
	_power_t0 = tick
	for c in _tf_t0:
		_tf_t0[c] = tick
	for ch in _chords:
		if ch["active"]:
			ch["since"] = tick
	for c in _atk:
		_atk[c]["t0"] = tick


## SimCore.step took the intent (it does not on a hit-stop tick): the edges are spent.
func consumed() -> void:
	_aedge.clear()
	_special_edge = 0
	_lunge_seen = false
