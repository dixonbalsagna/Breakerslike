class_name SimCamera
extends RefCounted
## View-layer camera follow: the twin of view/camera.js. The host calls camStep after each tick with S.dt; it reads S
## and never writes it. (Temporary home: it goes to Camera once the renderer exists.)

var x: float = 2500.0
var y: float = 100.0
var z: float = 0.45


func reset() -> void:
	x = 2500.0
	y = 100.0
	z = 0.45


func camStep(S: SimState, dt: float, vw: float, vh: float) -> void:
	var a = S.fighters[0]
	var b = S.fighters[1]
	var d: float = SimWrap.sdx(a.x, b.x)
	var mx: float = a.x + d / 2.0
	var my: float = (a.y + b.y) / 2.0
	var spanX: float = absf(d) + 700.0
	var spanY: float = absf(a.y - b.y) + 500.0
	var zz: float = SimMathx.jmin(SimMathx.jmin(vw / spanX, (vh * 0.8) / spanY), 1.15)
	zz *= 1.0 - 0.06 * (SimMathx.jmax(a.tier, b.tier) - 1.0)
	zz = SimMathx.jclamp(zz, 0.06, 1.15)
	var k: float = 1.0 - SimDetMath.pow(0.02, dt)
	z += (zz - z) * k
	x = SimWrap.wrap(x + SimWrap.sdx(x, mx) * k)
	y += (SimMathx.jclamp(my + 40.0, -180.0, 2400.0) - y) * k
