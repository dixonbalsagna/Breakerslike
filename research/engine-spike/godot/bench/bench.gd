extends RefCounted
## Engine spike (throwaway, research only). Bench recorder and the SPEC bench JSON.
## Protocol (SPEC "Bench mode"): frames rendered while sim tick <= warmup are warm-up; every frame with
## warmup < tick <= warmup + measure is measured; a frame's time is the interval between its start and the next
## frame's start. pN = sorted[ceil(N/100 * n) - 1]. fps = frames / elapsed seconds.

var warmup: int = 180
var measure: int = 1800
var frame_ms := PackedFloat64Array()
var sim_ms := PackedFloat64Array()
var upload_ms := PackedFloat64Array()
var particles_ms := PackedFloat64Array()
var gpu_ms := PackedFloat64Array()
var live := PackedFloat64Array()
var steps := PackedInt32Array()      # sim steps run in each measured frame
var first_start_us: int = -1
var last_end_us: int = -1
var dropped_warmup: int = 0       # ticks dropped by the 8-step cap during warm-up (loading, first-draw compiles)
var dropped_measured: int = 0     # ticks dropped inside the measure window (the sim fell behind real time)
var max_steps_frames: int = 0     # frames that hit the 8-step cap


func end_tick() -> int:
	return warmup + measure


func is_measured(tick: int) -> bool:
	return tick > warmup and tick <= warmup + measure


static func pct(sorted: PackedFloat64Array, n: int) -> float:
	if sorted.is_empty():
		return 0.0
	var idx: int = int(ceil(float(n) / 100.0 * float(sorted.size()))) - 1
	return sorted[clampi(idx, 0, sorted.size() - 1)]


static func avg(v: PackedFloat64Array) -> float:
	if v.is_empty():
		return 0.0
	var s: float = 0.0
	for x in v:
		s += x
	return s / float(v.size())


static func r4(x: float) -> float:
	return snappedf(x, 0.0001)


static func avg_p95(v: PackedFloat64Array) -> Dictionary:
	var s := v.duplicate()
	s.sort()
	return {"avg": r4(avg(v)), "p95": r4(pct(s, 95))}


func stats() -> Dictionary:
	var s := frame_ms.duplicate()
	s.sort()
	var n: int = s.size()
	var elapsed: float = float(last_end_us - first_start_us) / 1000.0
	var gpu = null
	var any_gpu: bool = false
	for g in gpu_ms:
		if g > 0.0:
			any_gpu = true
			break
	if any_gpu:
		gpu = avg_p95(gpu_ms)
	var times: Array = []
	times.resize(n)
	for i in n:
		times[i] = r4(frame_ms[i])
	var live_max: float = 0.0
	for x in live:
		live_max = maxf(live_max, x)
	# The same sub-timings over only the frames that ran at least one sim step (at thousands of fps most frames run
	# none, so the all-frame averages above are tiny and their p95 is often 0).
	var ss := PackedFloat64Array()
	var su := PackedFloat64Array()
	var sp := PackedFloat64Array()
	for i in steps.size():
		if steps[i] > 0:
			ss.append(sim_ms[i])
			su.append(upload_ms[i])
			sp.append(particles_ms[i])
	return {
		"frames": n,
		"elapsedMs": r4(elapsed),
		"frameMs": {
			"avg": r4(avg(frame_ms)), "p50": r4(pct(s, 50)), "p95": r4(pct(s, 95)),
			"p99": r4(pct(s, 99)), "max": r4(s[n - 1] if n > 0 else 0.0),
		},
		"fps": r4(float(n) / (elapsed / 1000.0)) if elapsed > 0.0 else 0.0,
		"subMs": {
			"sim": avg_p95(sim_ms), "upload": avg_p95(upload_ms), "particles": avg_p95(particles_ms), "gpu": gpu,
		},
		"subMsStepFrames": {"frames": ss.size(), "sim": avg_p95(ss), "upload": avg_p95(su), "particles": avg_p95(sp)},
		"particles": {"liveAvg": roundi(avg(live)), "liveMax": int(live_max)},
		"frameTimesMs": times,
	}
