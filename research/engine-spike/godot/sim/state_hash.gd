class_name SpikeHash
extends RefCounted
## Engine spike (throwaway, research only). State vectors and SHA-256 hashes, as stateVector/baseVector in
## shared/sim-ref.mjs and cameraVector in shared/camera-ref.mjs. The hash is SHA-256 of the little-endian float64
## bytes of the vector, as lowercase hex.

const NC: int = 1200   # SpikeWrap.NC

## Golden for the bench check (worst scene at tick 1980), embedded because exported builds cannot read ../shared.
const WORST_1980: String = "19a92e5cae133e412bfe48d09aef31bcd3453057c5d4542353aa97f2dd9f1dac"


## deform[0..NC), a.x, a.y, a.vx, a.vy, b.x, b.y, b.vx, b.vy, rng state (0 if none), tick.
static func state_vector(scene) -> PackedFloat64Array:
	var t = scene.terrain
	var v: PackedFloat64Array = t.deform.duplicate()
	v.resize(NC + 10)
	var a = scene.a
	var b = scene.b
	v[NC] = a.x
	v[NC + 1] = a.y
	v[NC + 2] = a.vx
	v[NC + 3] = a.vy
	v[NC + 4] = b.x
	v[NC + 5] = b.y
	v[NC + 6] = b.vx
	v[NC + 7] = b.vy
	v[NC + 8] = float(scene.rng.state()) if scene.rng != null else 0.0
	v[NC + 9] = float(scene.tick)
	return v


static func base_vector(terrain) -> PackedFloat64Array:
	return terrain.base.duplicate()


## x, y, view width, d, o, flips (not part of the fixed API; used by the camera goldens).
static func camera_vector(cam) -> PackedFloat64Array:
	return PackedFloat64Array([cam.x, cam.y, cam.view_w, cam.d, cam.o, float(cam.flips)])


## to_byte_array() copies the raw float64 memory, which is little-endian on every target we ship
## (x86-64, arm64, wasm32). A big-endian host would need a byte swap here.
static func sha256_hex(v: PackedFloat64Array) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(v.to_byte_array())
	return ctx.finish().hex_encode()


## Parses ../shared/golden.json next to the project folder. Exported builds have no such file (globalize_path of
## res:// does not point at the source tree there), so they fall back to the embedded worst@1980 golden only;
## the fallback dictionary carries "embedded": true.
static func golden() -> Dictionary:
	var root: String = ProjectSettings.globalize_path("res://")
	if root != "" and not root.begins_with("res://"):
		var path: String = (root.path_join("..").path_join("shared").path_join("golden.json")).simplify_path()
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				var parsed = JSON.parse_string(f.get_as_text())
				f.close()
				if parsed is Dictionary:
					return parsed
	return {"embedded": true, "worst": {"1980": WORST_1980}}
