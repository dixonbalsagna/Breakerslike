class_name SpikeFighter
extends RefCounted
## Engine spike (throwaway, research only). Kinematic box, as Fighter in shared/sim-ref.mjs.
## Plain float64 fields (not the engine vector types, which are float32).

var x: float = 0.0
var y: float = 0.0
var vx: float = 0.0
var vy: float = 0.0
var tvx: float = 0.0
var tvy: float = 0.0


func _init(px: float = 0.0, py: float = 0.0) -> void:
	x = px
	y = py
