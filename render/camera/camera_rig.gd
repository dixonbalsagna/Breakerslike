class_name CameraRig
extends Camera3D
## Turns the reference camera (world x, y and zoom z in pixels per world unit, sim/core/view/camera.gd) into a 3D
## perspective camera. With no pitch it looks straight down -z and the mapping is exact on the fighter plane (z = 0):
## a point there lands on the same pixel as the prototype's w2s(), sdx(cam.x, x) * z + vw / 2 across and
## vh * 0.7 - (y - cam.y) * z down.
## Everything is placed relative to the camera's wrapped x, so the camera itself always sits at x = 0 (floating
## origin): no large coordinates, and the wrap seam is invisible to the GPU.
##
## Pitch (docs/camera/camera-v2.md section 8) raises the camera and tips it down by that angle, orbiting the point of
## the fighter plane at the screen's centre: that point stays at the centre at the same distance, so the zoom across
## holds there. Heights on the plane then draw cos(pitch) as tall, and a point w units behind the plane moves up the
## screen by about w sin(pitch) zoom. The closed-form mapping above holds only at pitch 0; with a pitch, map through
## unproject_position().

var zoom: float = 0.45
var view_h: float = 700.0
var pitch_deg: float = 0.0
var dist: float = 3000.0       # the camera's distance to the fighter plane's point at the screen's centre


func _ready() -> void:
	fov = RenderLook.FOV_DEG
	keep_aspect = Camera3D.KEEP_HEIGHT
	current = true


## cam_y and cam_z from the reference camera; jitter is the screen shake in pixels (+x right, +y down); pitch in
## degrees (0: straight on).
func frame(cam_y: float, cam_z: float, jitter: Vector2, vh: float, pitch: float = 0.0) -> void:
	zoom = cam_z
	view_h = vh
	pitch_deg = pitch
	dist = distance_for(cam_z, vh)
	var p: float = deg_to_rad(pitch)
	basis = Basis(Vector3.RIGHT, -p)
	# The shake's offset and the distance, turned by the pitch (in float64, so pitch 0 gives the same numbers as before).
	var oy: float = jitter.y / cam_z
	position = Vector3(-jitter.x / cam_z, cam_y + 0.2 * vh / cam_z + oy * cos(p) + dist * sin(p), dist * cos(p) - oy * sin(p))
	# The ground runs past the camera. The foreground rule keeps it at least FORE_DROP of its depth under the sight lines
	# to the fighter plane, so the lowest view ray can't meet it closer than FORE_DROP * dist / (tan + FORE_DROP + 2)
	# (allowing the fighter plane's profile up to 2 x dist above the camera); near sits at half that, as far out as the
	# rule allows for depth precision. A pitched camera's lowest ray is steeper by the pitch.
	var tn: float = tan(minf(deg_to_rad(RenderLook.FOV_DEG) * 0.5 + p, 1.5))
	near = clampf(0.5 * RenderLook.FORE_DROP * dist / (tn + RenderLook.FORE_DROP + 2.0), 5.0, dist * 0.9)
	far = dist + RenderLook.FOG_FAR * 1.1


## Camera distance from the fighter plane that gives zoom z pixels per world unit there.
static func distance_for(cam_z: float, vh: float) -> float:
	return vh / (2.0 * cam_z * tan(deg_to_rad(RenderLook.FOV_DEG) * 0.5))


## Half the visible width, in world units, at depth zd (0 is the fighter plane; negative is farther away).
func half_width(vw: float, zd: float = 0.0) -> float:
	return vw * 0.5 / zoom * (dist - zd) / dist
