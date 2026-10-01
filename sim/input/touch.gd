class_name SimTouch
extends RefCounted
## Touch Simple, host side (docs/controls/touch-bridge.md, input-scheme.md section 6.1): pointer events in, one
## SimIntent per fixed tick out. It resolves the gestures (tap against hold, flick, swipe, hold beyond the outer
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
	"stanceGuard": 1,         # today's stance ids: AGGRESSIVE 0, DEFENSIVE 1, EVASIVE 2, ESCAPE 3
	"stanceDodge": 2,
	"stanceNeutral": 0,
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

var _touches: Dictionary = {}     # pointer id -> {w, x0, y0, x, y, t0, fired, flicked, beyond}
var _owner: Dictionary = {}       # widget -> pointer id, so a button has one finger
var _dodge_until: int = -1
var _dash_until: int = -1
var _dash_mx: float = 0.0
var _dash_my: float = 0.0
var _sprinting: bool = false


func _init(overrides: Dictionary = {}) -> void:
	cfg = DEFAULTS.duplicate()
	for k in overrides:
		cfg[k] = overrides[k]


## Where the buttons are, in pixels: {name: {x, y, r}} for the circles (r is the visual radius) and
## {"stick": {x0, x1, y0, y1}} for the zone where a left-thumb touch starts the floating stick. margin is the safe
## margin in pixels from the screen edge (UI's safe area).
static func layout(vw: float, vh: float, dp_: float, portrait: bool, left_handed: bool = false, margin: float = 8.0) -> Dictionary:
	var src: Dictionary = PORT if portrait else LAND
	var out: Dictionary = {}
	var cx: float = vw - margin
	var cy: float = vh - margin
	for k in src:
		var a: Array = src[k]
		var x: float = cx + float(a[0]) * dp_
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
	for k in ["attack", "guard", "power", "context"]:
		if not lay.has(k):
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
	_touches[id] = {"w": widget, "x0": x, "y0": y, "x": x, "y": y, "t0": tick, "fired": false, "flicked": false, "beyond": 0}
	if widget == "stick":
		_check_flick(_touches[id])


func touch_move(id: int, x: float, y: float) -> void:
	if not _touches.has(id):
		return
	var t: Dictionary = _touches[id]
	t.x = x
	t.y = y
	match t.w:
		"attack":
			_check_swipe(t)
		"stick":
			_check_flick(t)


func touch_up(id: int) -> void:
	if not _touches.has(id):
		return
	var t: Dictionary = _touches[id]
	if t.w == "attack" and not t.fired:
		req_light = true   # a tap: released before holdTicks (the bridge fires it on release; see touch-bridge.md)
	_owner.erase(t.w)
	_touches.erase(id)


## Let go of everything (focus lost, an overlay opened, the device changed): no stuck guard or charge.
func release_all() -> void:
	_touches.clear()
	_owner.clear()
	_sprinting = false
	_dodge_until = -1
	_dash_until = -1
	req_light = false
	req_heavy = false
	req_sig = false


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
	var i := SimIntent.new()
	i.mx = mx
	i.my = my
	i.dash = dashing or sprint
	i.charge = power
	i.light = req_light
	i.heavy = req_heavy
	i.sig = req_sig
	if guard:
		i.stance = float(cfg.stanceGuard)
	elif dodge_active:
		i.stance = float(cfg.stanceDodge)
	else:
		i.stance = float(cfg.stanceNeutral)
	return i


## SimCore.step consumed the intent (it did not freeze for hit-stop): the requests are spent.
func consumed() -> void:
	req_light = false
	req_heavy = false
	req_sig = false
