class_name SplitFrame
extends RefCounted
## One presentation frame of the dynamic split screen (docs/camera/split-screen.md): what the compositor and the HUD
## need, and nothing else. The rig makes one per sim tick; the host interpolates between the last two.
##
## Pane index equals fighter slot: pane 0 is slot 0's, pane 1 slot 1's. `n` is the unit normal (screen coordinates,
## y down) from pane 0's region toward pane 1's, so pane 1 holds the points with (p - c) . n > 0.

var vw: float = 1280.0
var vh: float = 720.0
var mode: String = "merged"          # merged, opening, split, closing, slam, swing, solo
var sep: float = 0.0                 # 0 one view, 1 two panes (linear; the panes' blend uses smootherstep(sep))
var e: float = 0.0                   # how far one pane has taken the screen (a launch, a cinematic, a slam)
var e_slot: int = -1
var sliver: float = 0.0              # share of the screen the other pane keeps at e = 1
var theta: float = 0.0               # angle of n, radians
var n: Vector2 = Vector2.RIGHT
var c: Vector2 = Vector2(640.0, 360.0)   # a point on the divider, with the expansion applied
var gap: float = 0.0                 # divider line width, px
var feather: float = 0.0             # dissolve blend half-width, px
var line_alpha: float = 0.0
var cam_x: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])   # per pane: the reference camera's x, y, zoom
var cam_y: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])
var cam_z: PackedFloat64Array = PackedFloat64Array([0.5, 0.5])
var anchor: Array = [Vector2.ZERO, Vector2.ZERO]   # where each fighter's chest is meant to sit, px
var active: Array = [true, false]    # which panes must be rendered
var kind: Array = ["normal", "normal"]   # pane_request hook: "normal" or "search"
var swing: float = -1.0              # -1, or 0..1 while the panes trade sides
var sigma: int = 1                   # +1 when slot 1 is to slot 0's right (the layout now shown)
var ring: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])   # both fighters' angles round the planet, radians
var held_u: float = 0.0              # the held signed separation slot 0 to slot 1, units
var flash: float = 0.0               # seconds left of the divider's slam flash
var slam: bool = false               # true on the one frame the slam closes
var cut: bool = true                 # a hard cut: do not interpolate into this frame


func duplicate() -> SplitFrame:
	var f := SplitFrame.new()
	f.vw = vw
	f.vh = vh
	f.mode = mode
	f.sep = sep
	f.e = e
	f.e_slot = e_slot
	f.sliver = sliver
	f.theta = theta
	f.n = n
	f.c = c
	f.gap = gap
	f.feather = feather
	f.line_alpha = line_alpha
	f.cam_x = cam_x.duplicate()
	f.cam_y = cam_y.duplicate()
	f.cam_z = cam_z.duplicate()
	f.anchor = anchor.duplicate()
	f.active = active.duplicate()
	f.kind = kind.duplicate()
	f.swing = swing
	f.sigma = sigma
	f.ring = ring.duplicate()
	f.held_u = held_u
	f.flash = flash
	f.slam = slam
	f.cut = cut
	return f


## Weight of pane 1 at screen point p (pane 0's is one minus this). Zero or one away from the divider; a smooth blend
## across the feather while the panes dissolve into one view.
func weight1(p: Vector2) -> float:
	if not bool(active[1]):
		return 0.0
	if not bool(active[0]):
		return 1.0
	var s: float = (p - c).dot(n)
	if feather <= 0.001:
		return 1.0 if s > 0.0 else 0.0
	return smoothstep(-feather, feather, s)


## The screen point of a world point as pane i draws it: the reference camera's mapping (docs/rendering/README.md).
func screen_pos(i: int, wx: float, wy: float) -> Vector2:
	return Vector2(SimWrap.sdx(cam_x[i], wx) * cam_z[i] + vw * 0.5, vh * CamParams.PLANE_Y - (wy - cam_y[i]) * cam_z[i])


## Whether pane i shows any of the screen.
func shows(i: int) -> bool:
	return bool(active[i])


## The HUD anchor record for a fighter (chest point in its own pane), in the shape Rendering's anchor_fn returns.
func hud_anchor(slot: int, wx: float, wy: float) -> Dictionary:
	var p: Vector2 = screen_pos(slot, wx, wy + CamParams.CHEST)
	var on: bool = shows(slot) and Rect2(Vector2(-200.0, -200.0), Vector2(vw, vh) + Vector2(400.0, 400.0)).has_point(p)
	if on and feather <= 0.001:
		var side: float = (p - c).dot(n)
		on = side <= 0.0 if slot == 0 else side > 0.0
	return {"pos": p, "h": CamParams.BODY_H * cam_z[slot], "visible": on, "pane": slot}


## The width of the world pane i shows at the fighter plane, in radians of planet angle.
func viewed_arc(i: int) -> float:
	var ss: float = smoothstep(0.0, 1.0, sep)
	var share: float = 1.0 - 0.5 * ss   # one view: the whole width; two panes: about half each
	if e_slot >= 0:
		var take: float = (1.0 - sliver) if i == e_slot else sliver
		share = lerpf(share, take, e)
	return (share * vw / cam_z[i]) / SimConst.W * TAU


## The record UI's HUD reads each frame (UiHud.split_fn, docs/ui/hud-spec.md section 10). Empty when the screen is one
## camera and there is nothing to draw. In one view arc_A and arc_B are the same (the camera's viewed width); UI draws
## a single arc at the fighters' midpoint.
func split_record(pointer_always: bool = false) -> Dictionary:
	var d: Dictionary = {}
	d["sep"] = sep
	d["c"] = c
	d["n"] = n
	d["gap"] = gap
	d["fade"] = line_alpha
	d["slam"] = clampf(flash / CamParams.SLAM_FLASH, 0.0, 1.0)
	d["sigma"] = sigma
	d["dist_bh"] = absf(held_u) / CamParams.BODY_H
	d["pointer"] = "always" if (pointer_always or sep < 0.5) else "split"
	d["ring"] = {
		"angle_A": ring[0], "angle_B": ring[1], "sigma": sigma, "arc_A": viewed_arc(0), "arc_B": viewed_arc(1),
		"swing": swing, "sep": sep, "W": SimConst.W,
	}
	return d


static func lerp_frames(a: SplitFrame, b: SplitFrame, t: float) -> SplitFrame:
	if b.cut or a.vw != b.vw or a.vh != b.vh:
		return b
	var f: SplitFrame = b.duplicate()
	f.sep = lerpf(a.sep, b.sep, t)
	f.e = lerpf(a.e, b.e, t)
	f.theta = a.theta + angle_difference(a.theta, b.theta) * t
	f.n = Vector2(cos(f.theta), sin(f.theta))
	f.c = a.c.lerp(b.c, t)
	f.gap = lerpf(a.gap, b.gap, t)
	f.feather = lerpf(a.feather, b.feather, t)
	f.line_alpha = lerpf(a.line_alpha, b.line_alpha, t)
	for i in range(2):
		f.cam_x[i] = SimWrap.wrap(a.cam_x[i] + SimWrap.sdx(a.cam_x[i], b.cam_x[i]) * t)
		f.cam_y[i] = lerpf(a.cam_y[i], b.cam_y[i], t)
		f.cam_z[i] = exp(lerpf(log(a.cam_z[i]), log(b.cam_z[i]), t))
		f.anchor[i] = a.anchor[i].lerp(b.anchor[i], t)
		f.ring[i] = a.ring[i] + angle_difference(a.ring[i], b.ring[i]) * t
	f.swing = lerpf(a.swing, b.swing, t) if a.swing >= 0.0 and b.swing >= 0.0 else b.swing
	f.flash = lerpf(a.flash, b.flash, t)
	f.held_u = lerpf(a.held_u, b.held_u, t)
	f.cut = false
	return f
