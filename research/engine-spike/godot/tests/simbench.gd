class_name SpikeSimbench
extends RefCounted
## Engine spike (throwaway, research only). Sim throughput, as simbench() in shared/test-ref.mjs:
## median ms to generate the terrain, and median microseconds per worst-scene tick over `ticks` ticks x `reps` runs.
## A smoke check of the harness only: the Research director runs the final timed runs on a quiet machine.

const _Terrain = preload("res://sim/terrain.gd")
const _Scenes = preload("res://sim/scenes.gd")


static func _median(v: Array[float]) -> float:
	var s: Array[float] = v.duplicate()
	s.sort()
	return s[s.size() >> 1]


## JS +v.toFixed(3): round to 3 decimals through the decimal string, so the value prints short (snappedf() multiplies
## by 0.001 and can leave 4.1850000000000005).
static func _fixed3(v: float) -> float:
	return String.num(v, 3).to_float()


## "godot <version> gdscript <editor|template> <debug|release>"
static func stack_name() -> String:
	var ver: String = str(Engine.get_version_info().get("string", "?"))
	var kind: String = "editor" if OS.has_feature("editor") else "template"
	var dbg: String = "debug" if OS.is_debug_build() else "release"
	return "godot " + ver + " gdscript " + kind + " " + dbg


static func run(reps: int = 5, ticks: int = 3600) -> Dictionary:
	var gen: Array[float] = []
	var run_us: Array[float] = []
	for r in reps:
		var t0: int = Time.get_ticks_usec()
		_Terrain.gen_terrain(_Terrain.TERRAIN_SEED)
		gen.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	for r in reps:
		var s: _Scenes.Scene = _Scenes.make_scene("worst")
		var t0: int = Time.get_ticks_usec()
		for i in ticks:
			s.step()
		run_us.append(float(Time.get_ticks_usec() - t0) / float(ticks))
	return {
		"stack": stack_name(),
		"reps": reps,
		"ticks": ticks,
		"terrainGenMs": _fixed3(_median(gen)),
		"worstTickUs": _fixed3(_median(run_us)),
	}
