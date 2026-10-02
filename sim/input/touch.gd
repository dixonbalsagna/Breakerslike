class_name SimTouch
extends RefCounted
## Touch Simple, host side (docs/controls/touch-bridge.md, input-scheme.md section 6.1): pointer events in, one
## intent v2 per fixed tick out (I2c). It resolves the gestures (tap against hold, flick, swipe, hold beyond the outer
## ring) in tick time and never touches the sim. Today's intents are the bridge: attack tap is a light, attack hold
## a heavy, attack swipe up the signature, guard hold the DEFENSIVE stance, a stick flick the EVASIVE stance plus a
## dash, power hold a charge. The resolved actions are kept in the named fields below, so the intent v2 adapter
## (docs/architecture/intent-v2.md) reads the same state and only the last step of build() changes.
##
## Engine-agnostic on purpose: no Input, no Node, no clock. The host passes positions in pixels, the scale dp
## (pixels per density-independent pixel) and calls build() once per fixed tick, so every timer here counts ticks.
## The host has to call consumed() when SimCore.step consumed the intent (it returns false during hit-stop), so a
## press is held until a tick can use it, as the keyboard's edges are.

## Every number the bridge uses, in one place. They move to data/input/timing.json (input-schema.md section 5)
## when that file and its schema are adopted; a caller may pass overrides to _init.
const DEFAULTS: Dictionary = {
	"holdTicks": 12,          # an attack press still down after this many ticks is a heavy; released before, a light
	"swipeDp": 40.0,          # an upward drag of this length within holdTicks is the signature
	"stickRadiusDp": 56.0,    # the floating stick's base radius
	"deadzone": 0.2,
	"fullAt": 0.9,            # full speed at this fraction of the radius
	"quant": 16,              # stick values are multiples of 1/16
	"flickTicks": 6,          # a drag of flickFrac of the radius within this many ticks of touching down is a flick
	"flickFrac": 0.7,
	"outerRing": 1.3,         # beyond this many radii the thumb is sprinting
	"outerRelease": 1.15,     # back inside this many radii the sprint ends
	"sprintTicks": 6,         # beyond the ring for this long before the sprint starts
	"dodgeStanceTicks": 30,   # the EVASIVE stance after a flick (the director reads stance at exchange start)
	"dashTicks": 12,          # the flick's dash, in the flick direction
	"hitPadDp": 8.0,          # a button's hit radius is its visual radius plus this
	"minHitDp": 24.0,         # and never under this radius (a 48 dp target)
}

## Button geometry in dp, as offsets of the button centre from the bottom-right safe corner, plus the visual radius.
## Left-handed mirrors x. UI draws from layout() and hit-tests with widget_at(), so the two cannot disagree.
const LAND: Dictionary = {
	"attack": [-100.0, -100.0, 44.0],
	"guard": [-204.0, -78.0, 36.0],
	"power": [-108.0, -204.0, 36.0],
	"context": [-204.0, -178.0, 32.0],
}
const PORT: Dictionary = {
	"attack": [-68.0, -68.0, 34.0],
	"guard": [-150.0, -52.0, 28.0],
	"power": [-92.0, -136.0, 28.0],
	"context": [-168.0, -116.0, 24.0],
}
## The Full touch preset (tablets): a diamond on the right (light west, heavy north, signature east, context south),
## Mode and Power above it, Transform beside it, and Dodge and Guard stacked on the left edge. [dx, dy, r, side]:
## offsets from the bottom-right corner (side R) or the bottom-left corner (side L), in dp.
const FULL_LAND: Dictionary = {
	"light": [-172.0, -112.0, 30.0, "R"], "heavy": [-112.0, -170.0, 30.0, "R"], "signature": [-54.0, -112.0, 30.0, "R"],
	"context": [-112.0, -54.0, 30.0, "R"], "power": [-54.0, -236.0, 34.0, "R"], "mode": [-130.0, -240.0, 28.0, "R"],
	"transform": [-232.0, -170.0, 30.0, "R"], "dodge": [48.0, -240.0, 32.0, "L"], "guard": [48.0, -160.0, 32.0, "L"],
}
const FULL_PORT: Dictionary = {
	"light": [-134.0, -90.0, 24.0, "R"], "heavy": [-88.0, -136.0, 24.0, "R"], "signature": [-42.0, -90.0, 24.0, "R"],
	"context": [-88.0, -44.0, 24.0, "R"], "power": [-42.0, -186.0, 26.0, "R"], "mode": [-104.0, -190.0, 24.0, "R"],
	"transform": [-182.0, -136.0, 24.0, "R"], "dodge": [40.0, -186.0, 26.0, "L"], "guard": [40.0, -122.0, 26.0, "L"],
}

var cfg: Dictionary
var dp: float = 1.0               # pixels per dp; the host sets it from the screen
var tick: int = 0                 # build() calls so far (the host's ticks, hit-stop included)

# Resolved state, one tick's worth, readable by an intent v2 adapter.
var mx: float = 0.0
var my: float = 0.0
var guard: bool = false
var dodge_active: bool = false    # inside the flick's dodge stance
var sprint: bool = false
var power: bool = false
var req_light: bool = false       # requests are held until consumed()
var req_heavy: bool = false
var req_sig: bool = false

# I2c: edges and holds that intent v2 carries.
var _guard_press: bool = false
var _dodge_edge: bool = false
var _power_press: bool = false
var _power_tap: bool = false
var _power_t0: int = 0
var _power_voided: bool = false   # a layer press (Attack with Power held) fired during this hold
var _special_edge: int = 0
var _tf_t0: int = -1              # the Transform button's press tick, or -1
var _tf_sent: bool = false
var _transform_edge: bool = false
var _escape_edge: bool = false    # a swipe up on Guard (provisional Escape, docs/controls/agency-input.md)

# The Full touch preset: the same widgets go through a SimLayout (touch-full), the stick stays here.
var full_mode: bool = false
var preset_id: String = "touch-simple"
var _full: SimLayout = null

var _touches: Dictionary = {}     # pointer id -> {w, x0, y0, x, y, t0, fired, flicked, beyond}
var _owner: Dictionary = {}       # widget -> pointer id, so a button has one finger
var _dodge_until: int = -1
var _dash_until: int = -1
var _dash_mx: float = 0.0
var _dash_my: float = 0.0
var _sprinting: bool = false


func _init(overrides: Dictionary = {}) -> void:
	cfg = DEFAULTS.duplicate()
	# The numbers are data (data/input/timing.json); DEFAULTS above stand in where a key is missing.
	cfg.holdTicks = SimInputData.ti(["tapHold", "holdStart"], int(cfg.holdTicks))
	cfg.transformTicks = SimInputData.ti(["tapHold", "transformConfirm"], 30)
	cfg.swipeDp = SimInputData.tf(["touch", "swipeUpPx"], float(cfg.swipeDp))
	cfg.swipeTicks = SimInputData.ti(["touch", "swipeUpTicks"], 24)
	cfg.flickTicks = SimInputData.ti(["touch", "flickToDodgeTicks"], int(cfg.flickTicks))
	cfg.flickFrac = SimInputData.tf(["touch", "flickThreshold"], float(cfg.flickFrac))
	cfg.outerRing = SimInputData.tf(["touch", "outerRingScale"], float(cfg.outerRing))
	cfg.sprintTicks = SimInputData.ti(["touch", "outerRingHold"], int(cfg.sprintTicks))
	cfg.deadzone = SimInputData.tf(["stick", "deadzone"], float(cfg.deadzone))
	cfg.quant = SimInputData.ti(["stick", "quant"], int(cfg.quant))
	cfg.dodgeStanceTicks = SimInputData.ti(["dodge", "stateTicks"], 12)
	cfg.dashTicks = SimInputData.ti(["dodge", "lungeTicks"], int(cfg.dashTicks))
	for k in overrides:
		cfg[k] = overrides[k]


## Choose the touch preset: "touch-simple" (the default) or "touch-full". Everything held is let go.
func set_preset(id: String) -> void:
	release_all()
	preset_id = id
	full_mode = id == "touch-full"
	_full = SimLayout.new(SimInputData.preset(id)) if full_mode else null
	if _full != null:
		_full.mode_style = "hybrid"   # a thumb is busy: a tap latches energy, a hold is momentary


## The player's energy style ("hold", "toggle", "hybrid"; the Simple touch layout leaves the mode to the director). Full touch is
## hybrid unless the player chose the toggle.
func set_mode_style(s: String) -> void:
	if _full != null:
		_full.set_mode_style("toggle" if s == "toggle" else "hybrid")


## Where the buttons are, in pixels: {name: {x, y, r}} for the circles (r is the visual radius) and
## {"stick": {x0, x1, y0, y1}} for the zone where a left-thumb touch starts the floating stick. margin is the safe
## margin in pixels from the screen edge (UI's safe area).
static func layout(vw: float, vh: float, dp_: float, portrait: bool, left_handed: bool = false, margin: float = 8.0, full: bool = false) -> Dictionary:
	var src: Dictionary = (FULL_PORT if portrait else FULL_LAND) if full else (PORT if portrait else LAND)
	var out: Dictionary = {}
	var cx: float = vw - margin
	var cy: float = vh - margin
	for k in src:
		var a: Array = src[k]
		var x: float = cx + float(a[0]) * dp_
		if a.size() > 3 and a[3] == "L":
			x = margin + float(a[0]) * dp_
		if left_handed:
			x = vw - x
		out[k] = {"x": x, "y": cy + float(a[1]) * dp_, "r": float(a[2]) * dp_}
	var zone_w: float = vw * 0.42
	var zone_top: float = vh * (0.55 if portrait else 0.30)
	if left_handed:
		out["stick"] = {"x0": vw - zone_w, "x1": vw, "y0": zone_top, "y1": vh}
	else:
		out["stick"] = {"x0": 0.0, "x1": zone_w, "y0": zone_top, "y1": vh}
	return out


## Which control a point is on: "attack", "guard", "power", "context", "stick" (the move zone) or "". The host asks
## UI's HUD about its own targets (pause, feedback) first and passes "" here for those.
func widget_at(x: float, y: float, lay: Dictionary) -> String:
	var best: String = ""
	var best_d: float = INF
	for k in lay:
		if k == "stick":
			continue
		var c: Dictionary = lay[k]
		var hit_r: float = maxf(float(c.r) + float(cfg.hitPadDp) * dp, float(cfg.minHitDp) * dp)
		var d: float = sqrt((x - float(c.x)) * (x - float(c.x)) + (y - float(c.y)) * (y - float(c.y)))
		if d <= hit_r and d - float(c.r) < best_d:
			best_d = d - float(c.r)
			best = k
	if best != "":
		return best
	var z: Dictionary = lay.get("stick", {})
	if not z.is_empty() and x >= float(z.x0) and x <= float(z.x1) and y >= float(z.y0) and y <= float(z.y1):
		return "stick"
	return ""


func touch_down(id: int, x: float, y: float, widget: String) -> void:
	if widget == "" or _touches.has(id):
		return
	if _owner.has(widget):
		return   # one finger per control; the second is ignored
	_owner[widget] = id
	_touches[id] = {"w": widget, "x0": x, "y0": y, "x": x, "y": y, "t0": tick, "fired": false, "flicked": false, "beyond": 0, "layer": false}
	if full_mode and widget != "stick":
		_full.press("touch:" + widget)
		return
	match widget:
		"stick":
			_check_flick(_touches[id])
		"guard":
			_guard_press = true
		"power":
			_power_press = true
			_power_t0 = tick
			_power_voided = false
		"attack":
			if _owner.has("power"):
				# The power layer: Attack with Power held is the director's pick of a special, at once, and not a light.
				_touches[id].layer = true
				_touches[id].fired = true
				_special_edge = 7
				_power_voided = true
		"context":
			_tf_t0 = tick
			_tf_sent = false


func touch_move(id: int, x: float, y: float) -> void:
	if not _touches.has(id):
		return
	var t: Dictionary = _touches[id]
	t.x = x
	t.y = y
	match t.w:
		"attack":
			_check_swipe(t)
		"guard":
			_check_escape_swipe(t)
		"stick":
			_check_flick(t)


func touch_up(id: int) -> void:
	if not _touches.has(id):
		return
	var t: Dictionary = _touches[id]
	if full_mode and t.w != "stick":
		_full.release("touch:" + str(t.w))
		_owner.erase(t.w)
		_touches.erase(id)
		return
	if t.w == "attack" and not t.fired:
		req_light = true   # a tap: released before holdTicks (the bridge fires it on release; see touch-bridge.md)
	if t.w == "power" and not _power_voided and (tick - _power_t0) < int(cfg.holdTicks):
		_power_tap = true
	if t.w == "context":
		_tf_t0 = -1
	_owner.erase(t.w)
	_touches.erase(id)


## Let go of everything (focus lost, an overlay opened, the device changed): no stuck guard or charge.
func release_all() -> void:
	if _full != null:
		_full.release_all()
		_full.sprint_override = false
	_touches.clear()
	_owner.clear()
	_sprinting = false
	_dodge_until = -1
	_dash_until = -1
	req_light = false
	req_heavy = false
	req_sig = false
	_guard_press = false
	_dodge_edge = false
	_power_press = false
	_power_tap = false
	_power_voided = false
	_special_edge = 0
	_tf_t0 = -1
	_transform_edge = false
	_escape_edge = false


## Escape on touch: a swipe up on the Guard button within swipeUpTicks of touching it (Guard stays down). Provisional, like the
## pad's R3; the finger is already on the button, so it costs no new control and cannot be hit by a stray tap.
func _check_escape_swipe(t: Dictionary) -> void:
	if t.fired:
		return
	if (tick - int(t.t0)) <= int(cfg.swipeTicks) and (float(t.y0) - float(t.y)) >= float(cfg.swipeDp) * dp:
		t.fired = true
		_escape_edge = true


func _check_swipe(t: Dictionary) -> void:
	if t.fired:
		return
	if (tick - int(t.t0)) <= int(cfg.holdTicks) and (float(t.y0) - float(t.y)) >= float(cfg.swipeDp) * dp:
		t.fired = true
		req_sig = true


func _check_flick(t: Dictionary) -> void:
	if t.flicked or (tick - int(t.t0)) > int(cfg.flickTicks):
		return
	var dx: float = float(t.x) - float(t.x0)
	var dy: float = float(t.y) - float(t.y0)
	var len_: float = sqrt(dx * dx + dy * dy)
	if len_ < float(cfg.flickFrac) * float(cfg.stickRadiusDp) * dp:
		return
	t.flicked = true
	# Eight-way snap, so the dash reads like a keyboard's: an axis counts when it carries at least 38% of the drag.
	var ux: float = dx / len_
	var uy: float = -dy / len_   # screen y runs down; the sim's my runs up
	_dash_mx = (1.0 if ux > 0.0 else -1.0) if absf(ux) >= 0.38 else 0.0
	_dash_my = (1.0 if uy > 0.0 else -1.0) if absf(uy) >= 0.38 else 0.0
	_dodge_until = tick + int(cfg.dodgeStanceTicks)
	_dash_until = tick + int(cfg.dashTicks)
	_dodge_edge = true
	if full_mode:
		_full.press("touch:dodge")
		_full.release("touch:dodge")


func _axis(a: float) -> float:
	var m: float = absf(a)
	var dz: float = float(cfg.deadzone)
	if m <= dz:
		return 0.0
	var s: float = clampf((m - dz) / (float(cfg.fullAt) - dz), 0.0, 1.0)
	var q: float = float(cfg.quant)
	s = roundf(s * q) / q
	return s if a > 0.0 else -s


## One fixed tick: advance the clock, resolve the held states and any timed gestures, and return the intent.
func build() -> SimIntent:
	if full_mode:
		return _build_full()
	tick += 1
	mx = 0.0
	my = 0.0
	guard = false
	power = false
	var sprint_now: bool = false
	var radius: float = float(cfg.stickRadiusDp) * dp
	for id in _touches:
		var t: Dictionary = _touches[id]
		match t.w:
			"guard":
				guard = true
			"power":
				power = true
			"attack":
				if not t.fired and (tick - int(t.t0)) >= int(cfg.holdTicks):
					t.fired = true
					req_heavy = true
			"stick":
				var dx: float = float(t.x) - float(t.x0)
				var dy: float = float(t.y) - float(t.y0)
				mx = _axis(dx / radius)
				my = _axis(-dy / radius)
				var dist: float = sqrt(dx * dx + dy * dy)
				var limit: float = (float(cfg.outerRelease) if _sprinting else float(cfg.outerRing)) * radius
				t.beyond = int(t.beyond) + 1 if dist > limit else 0
				sprint_now = int(t.beyond) >= int(cfg.sprintTicks)
	_sprinting = sprint_now
	sprint = sprint_now
	dodge_active = tick <= _dodge_until
	var dashing: bool = tick <= _dash_until
	if dashing:
		mx = _dash_mx
		my = _dash_my
	if _tf_t0 >= 0 and not _tf_sent and tick - _tf_t0 >= int(cfg.transformTicks):
		_tf_sent = true
		_transform_edge = true
	var i := SimIntent.new()
	i.mx = mx
	i.my = my
	i.guard = guard
	i.guardPress = _guard_press
	i.dodge = _dodge_edge
	i.sprint = sprint
	i.power = power
	i.powerPress = _power_press
	i.powerTap = _power_tap
	i.mode = -1   # Simple: the director picks the piece family
	i.light = req_light
	i.heavy = req_heavy
	i.sig = req_sig
	i.special = _special_edge
	i.transform = _transform_edge
	i.escape = _escape_edge
	# The attack level: a finger on Attack is light until holdTicks and heavy from then on (the Simple upgrade).
	for id in _touches:
		var at: Dictionary = _touches[id]
		if at.w == "attack" and not at.layer:
			if tick - int(at.t0) >= int(cfg.holdTicks):
				i.heavyHeld = true
			else:
				i.lightHeld = true
	# Today's fields, until I3: a flick's dash or a sprint is the dash; Power held past holdTicks is the channel.
	i.dash = dashing or sprint
	i.charge = power and not _power_voided and (tick - _power_t0) >= int(cfg.holdTicks)
	i.stance = -1.0
	return i


## What the on-screen controls show (UI's touch_state_fn, docs/ui/hud-spec.md section 24): {attack: {down, hold 0..1},
## guard: {down}, power: {down}, stick: {active, base, thumb, sprint}, transform: {down}}. Read-only, host side. In this
## build the context slot carries Transform, so `transform.down` is a finger on the "context" button.
func display_state() -> Dictionary:
	var out: Dictionary = {"attack": {"down": false, "hold": 0.0}, "guard": {"down": false}, "power": {"down": false},
			"stick": {"active": false, "base": Vector2.ZERO, "thumb": Vector2.ZERO, "sprint": false}, "transform": {"down": false}}
	if full_mode:
		out["full"] = {}
		for id in _touches:
			var f: Dictionary = _touches[id]
			if f.w == "stick":
				out.stick = {"active": true, "base": Vector2(float(f.x0), float(f.y0)), "thumb": Vector2(float(f.x), float(f.y)), "sprint": _sprinting}
			else:
				out["full"][f.w] = {"down": true}
				if f.w == "guard":
					out.guard = {"down": true}
				elif f.w == "power":
					out.power = {"down": true}
				elif f.w == "transform":
					out.transform = {"down": true}
		return out
	for id in _touches:
		var t: Dictionary = _touches[id]
		match t.w:
			"attack":
				out.attack = {"down": true, "hold": 1.0 if t.fired else clampf(float(tick - int(t.t0)) / float(cfg.holdTicks), 0.0, 1.0)}
			"guard":
				out.guard = {"down": true}
			"power":
				out.power = {"down": true}
			"context":
				out.transform = {"down": true}
			"stick":
				out.stick = {"active": true, "base": Vector2(float(t.x0), float(t.y0)), "thumb": Vector2(float(t.x), float(t.y)), "sprint": _sprinting}
	return out


## The Full preset's tick: the widgets resolved in the SimLayout, the floating stick and its flick and sprint here.
func _build_full() -> SimIntent:
	tick += 1
	var radius: float = float(cfg.stickRadiusDp) * dp
	var sprint_now: bool = false
	var vx: float = 0.0
	var vy: float = 0.0
	for id in _touches:
		var t: Dictionary = _touches[id]
		if t.w == "stick":
			var dx: float = float(t.x) - float(t.x0)
			var dy: float = float(t.y) - float(t.y0)
			vx = clampf(dx / radius, -1.0, 1.0)
			vy = clampf(-dy / radius, -1.0, 1.0)
			var dist: float = sqrt(dx * dx + dy * dy)
			var limit: float = (float(cfg.outerRelease) if _sprinting else float(cfg.outerRing)) * radius
			t.beyond = int(t.beyond) + 1 if dist > limit else 0
			sprint_now = int(t.beyond) >= int(cfg.sprintTicks)
	_sprinting = sprint_now
	sprint = sprint_now
	_full.axis("touch:stick", vx, vy)
	_full.sprint_override = sprint_now
	var i: SimIntent = _full.build()
	i.escape = _escape_edge
	if tick <= _dash_until:
		i.mx = _dash_mx
		i.my = _dash_my
		i.dash = true
	return i


## The Transform button's hold progress, 0 to 1 (UI's ring). 0 when it is not held.
func transform_hold() -> float:
	if full_mode:
		return _full.transform_hold()
	if _tf_t0 < 0:
		return 0.0
	return clampf(float(tick - _tf_t0) / float(cfg.transformTicks), 0.0, 1.0)


## A pausing set piece froze the sim: presses made meanwhile are dropped.
func drop_edges() -> void:
	consumed()


## The pause ended: edges dropped, and every hold read again as if it began now.
func resume() -> void:
	drop_edges()
	if full_mode:
		_full.resume()
	for id in _touches:
		_touches[id].t0 = tick
		_touches[id].beyond = 0
	_power_t0 = tick
	if _tf_t0 >= 0 and not _tf_sent:
		_tf_t0 = tick


## SimCore.step consumed the intent (it did not freeze for hit-stop): the requests are spent.
func consumed() -> void:
	if _full != null:
		_full.consumed()
	req_light = false
	req_heavy = false
	req_sig = false
	_guard_press = false
	_dodge_edge = false
	_power_press = false
	_power_tap = false
	_special_edge = 0
	_transform_edge = false
	_escape_edge = false
