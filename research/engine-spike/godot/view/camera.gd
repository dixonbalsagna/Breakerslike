class_name SpikeCamera
extends RefCounted
## Engine spike (throwaway, research only). Port of shared/camera-ref.mjs. Presentation layer: it reads sim state
## (anything with float x and y, normally SpikeFighter) and never writes it. Stepped once per sim tick, after the sim.
## Same contract as the sim: float64 scalars only (no engine vector types), + - * / only, JS expression order.
##
## How it avoids pops:
##  1. Floating origin. The camera keeps a wrapped x in [0, W). Renderers draw every object at sdx(cam.x, x).
##  2. Continuous arc. `d` follows the pair with d += sdx(d, raw), so it never re-chooses the arc on its own.
##  3. Hysteresis. Only when the framed arc is longer than HALF + HYST does the camera switch to the short arc;
##     that pan is speed-capped (PAN_MAX of the view per tick): a fast, continuous pan instead of a cut.

const W: float = 9600.0          # SpikeWrap.W
const HALF: float = 4800.0       # SpikeWrap.HALF

# The CAM table of camera-ref.mjs, as typed constants...
const MARGIN_X: float = 700.0    # world units added to the horizontal span
const MARGIN_Y: float = 500.0    # world units added to the vertical span
const ASPECT: float = 16.0 / 9.0 # view width / view height (folded at parse time, same double as JS 16 / 9)
const MIN_VIEW: float = 1400.0   # narrowest view width, world units
const MAX_VIEW: float = 7200.0   # widest view width, world units
const HYST: float = 400.0        # arc hysteresis, world units
const K: float = 0.12            # exponential smoothing per tick for x, y and view width
const PAN_MAX: float = 0.03      # cap on horizontal camera motion per tick, as a fraction of the view width
const FLIP_DONE: float = 0.05    # a flip pan is finished once the remaining offset is under this fraction of the view
const Y_OFF: float = 40.0
const Y_MIN: float = -180.0
const Y_MAX: float = 2400.0
const VFOV_DEG: float = 40.0     # renderers: vertical field of view of the perspective camera
const TAN_HALF_HFOV: float = 0.6470581942510264   # tan(20 deg) * 16/9; D = (viewW/2) / TAN_HALF_HFOV
# ...and as one dictionary, keyed like the JS table.
const CAM: Dictionary = {
	"MARGIN_X": MARGIN_X, "MARGIN_Y": MARGIN_Y, "ASPECT": ASPECT, "MIN_VIEW": MIN_VIEW, "MAX_VIEW": MAX_VIEW,
	"HYST": HYST, "K": K, "PAN_MAX": PAN_MAX, "FLIP_DONE": FLIP_DONE, "Y_OFF": Y_OFF, "Y_MIN": Y_MIN,
	"Y_MAX": Y_MAX, "VFOV_DEG": VFOV_DEG, "TAN_HALF_HFOV": TAN_HALF_HFOV,
}

var x: float = 0.0
var y: float = 0.0
var view_w: float = MIN_VIEW
var d: float = 0.0
var o: float = 0.0        # signed world-unit offset still to pan (camera -> target), carried across ticks
var ax: float = 0.0       # a.x at the previous tick
var flips: int = 0
var flipping: bool = false
var ready: bool = false

# target() results (JS returns an object; kept in fields to avoid allocating).
var _tx: float = 0.0
var _ty: float = 0.0
var _tw: float = 0.0


static func _wrapx(v: float) -> float:
	return fmod(fmod(v, W) + W, W)


static func _sdx(p: float, q: float) -> float:
	var dd: float = fmod(q - p, W)
	if dd > HALF:
		dd -= W
	elif dd < -HALF:
		dd += W
	return dd


static func _clamp(v: float, lo: float, hi: float) -> float:
	if v < lo:
		return lo
	if v > hi:
		return hi
	return v


func _target(a_x: float, a_y: float, b_y: float) -> void:
	var ad: float = -d if d < 0.0 else d
	var dy: float = a_y - b_y
	var ady: float = -dy if dy < 0.0 else dy
	var span_x: float = ad + MARGIN_X
	var span_y: float = (ady + MARGIN_Y) * ASPECT
	_tx = _wrapx(a_x + d / 2.0)
	_ty = _clamp((a_y + b_y) / 2.0 + Y_OFF, Y_MIN, Y_MAX)
	_tw = _clamp(span_x if span_x > span_y else span_y, MIN_VIEW, MAX_VIEW)


## Snap to the pair with no smoothing (scene start).
func reset(a, b) -> void:
	var a_x: float = a.x
	var a_y: float = a.y
	var b_x: float = b.x
	var b_y: float = b.y
	d = _sdx(a_x, b_x)
	_target(a_x, a_y, b_y)
	x = _tx
	y = _ty
	view_w = _tw
	ready = true
	flipping = false
	o = 0.0
	ax = a_x


func step(a, b) -> void:
	if not ready:
		reset(a, b)
		return
	var a_x: float = a.x
	var a_y: float = a.y
	var b_x: float = b.x
	var b_y: float = b.y
	var raw: float = _sdx(a_x, b_x)
	var d_prev: float = d
	d = d + _sdx(d, raw)
	var ad: float = -d if d < 0.0 else d
	if ad > HALF + HYST:
		d = raw
		flips += 1
		flipping = true
	_target(a_x, a_y, b_y)
	# The pan offset is carried incrementally (a's own motion plus half the change in d, which includes the whole
	# flip jump), and re-synced exactly with sdx() when it is small, so rounding never accumulates.
	o = o + _sdx(ax, a_x) + (d - d_prev) / 2.0
	ax = a_x
	var oa: float = -o if o < 0.0 else o
	if oa < HALF / 2.0:
		o = _sdx(x, _tx)
	var mx: float = o * K
	var cap: float = view_w * PAN_MAX
	if mx > cap:
		mx = cap
	elif mx < -cap:
		mx = -cap
	x = _wrapx(x + mx)
	o = o - mx
	if flipping and (-o if o < 0.0 else o) < view_w * FLIP_DONE:
		flipping = false
	y = y + (_ty - y) * K
	view_w = view_w + (_tw - view_w) * K


func view_h() -> float:
	return view_w / ASPECT


## World position to normalised screen coordinates: (0, 0) top left, (1, 1) bottom right.
func screen_x(wx: float) -> float:
	return 0.5 + _sdx(x, wx) / view_w


func screen_y(wy: float) -> float:
	return 0.5 - (wy - y) / view_h()


## Perspective renderers: distance from the camera to the z = 0 plane so that it shows exactly view_w.
func distance() -> float:
	return (view_w / 2.0) / TAN_HALF_HFOV
