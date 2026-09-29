class_name PaneShake
extends RefCounted
## Screen shake for the second pane, and the comfort cap for both (docs/camera/split-screen.md sections 11 and 12).
## Shake is cosmetic: it comes from the fx consumer's shake amount, never reads the sim's RNG stream, and draws from a
## cosmetic stream derived from the match seed by name ("camera_b"; the host's "camera" stream shakes pane 0), so a
## replay shows the same shake.

var scale: float = 1.0            # the player's shake scale, 0 to 1 (default 1; 0 turns shake off)
var _rng: SimRng
var jitter := Vector2.ZERO


func reset(match_seed: int, stream: String = "camera_b") -> void:
	_rng = SimRng.new(SimRng.deriveSeed(match_seed, stream))
	jitter = Vector2.ZERO


## One draw per tick, like the host's: shake_px is the fx consumer's decaying shake amount, vh the screen height.
func tick(shake_px: float, vh: float) -> Vector2:
	if _rng == null:
		return Vector2.ZERO
	if shake_px > 0.5 and scale > 0.0:
		jitter = capped(Vector2((_rng.next() - 0.5) * shake_px, (_rng.next() - 0.5) * shake_px), vh, scale)
	else:
		jitter = Vector2.ZERO
	return jitter


## The comfort cap: at most CamParams.SHAKE_CAP of the screen height, scaled by the player's setting.
static func capped(j: Vector2, vh: float, user_scale: float) -> Vector2:
	return j.limit_length(CamParams.SHAKE_CAP * vh) * clampf(user_scale, 0.0, 1.0)
