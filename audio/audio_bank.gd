class_name AudioBank
extends RefCounted
## The sound bank: renders each sound from its recipe (data/impacts.json, data/grunts.json) the first time it is asked
## for and keeps the AudioStreamWAV. A sound is a pure function of its recipe and the fixed bank seed, so the bank is
## identical on every machine and in every match; which variant plays in a match is the cue mapper's business.
##
## Ids: "impact.light" and the other impact recipes; "voice.<voice>.<gesture>", for example
## "voice.protagonist.effort.heavy".

const IMPACTS_PATH := "res://audio/data/impacts.json"
const GRUNTS_PATH := "res://audio/data/grunts.json"

var impacts: Dictionary = {}
var grunts: Dictionary = {}
var _cache: Dictionary = {}       # "id#variant" -> AudioStreamWAV
var render_ms: Dictionary = {}    # "id#variant" -> milliseconds it took to render
var _queue: Array = []            # [id, variant] pairs still to render for warm_step()


func _init() -> void:
	impacts = load_json(IMPACTS_PATH)
	grunts = load_json(GRUNTS_PATH)


static func load_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("AudioBank: cannot read %s" % path)
		return {}
	return parsed


## Every sound id the bank can render.
func ids() -> Array:
	var out: Array = []
	for k in impacts.get("sounds", {}):
		out.append(k)
	for v in grunts.get("voices", {}):
		for g in grunts.voices[v].gestures:
			out.append("voice.%s.%s" % [v, g])
	return out


func has_sound(id: String) -> bool:
	return _recipe(id).size() > 0


func variants(id: String) -> int:
	return maxi(1, int(_recipe(id).get("variants", 1)))


## The mono samples of one variant (rendered fresh each call; stream() caches the wrapped stream).
func buffer(id: String, variant: int) -> PackedFloat32Array:
	var r: Dictionary = _recipe(id)
	if r.is_empty():
		return PackedFloat32Array()
	var v: int = posmod(variant, variants(id))
	if id.begins_with("voice."):
		return GruntSynth.render(r, int(grunts.get("bank_seed", 0)), id, v)
	return ImpactSynth.render(r, int(impacts.get("bank_seed", 0)), id, v)


func rate_of(id: String) -> int:
	return int(_recipe(id).get("rate", 32000))


## How long a variant plays at normal pitch, in seconds (UI times a line's text to its grunt with this).
func duration(id: String, variant: int) -> float:
	return stream(id, variant).get_length()


func stream(id: String, variant: int) -> AudioStreamWAV:
	var v: int = posmod(variant, variants(id))
	var key: String = "%s#%d" % [id, v]
	if _cache.has(key):
		return _cache[key]
	var t0: int = Time.get_ticks_usec()
	var w: AudioStreamWAV = AudioDsp.to_wav(buffer(id, v), rate_of(id))
	render_ms[key] = (Time.get_ticks_usec() - t0) / 1000.0
	_cache[key] = w
	return w


## Render every variant now, so nothing is rendered in the middle of a fight. Returns the milliseconds taken.
func warm() -> float:
	var t0: int = Time.get_ticks_usec()
	for id in ids():
		for v in range(variants(id)):
			stream(id, v)
	return (Time.get_ticks_usec() - t0) / 1000.0


## The same work in slices, for a loading screen or the first frames of a match: call warm_begin() once, then
## warm_step() each frame until it returns false. One call renders one variant (2 to 60 ms on a desktop).
func warm_begin(only_voices: Array = []) -> void:
	_queue.clear()
	for id in ids():
		if id.begins_with("voice.") and not only_voices.is_empty() and not (id.split(".")[1] in only_voices):
			continue
		for v in range(variants(id)):
			_queue.append([id, v])


## Render the next queued variant. Returns true while more remain.
func warm_step() -> bool:
	if _queue.is_empty():
		return false
	var q: Array = _queue.pop_front()
	stream(q[0], q[1])
	return not _queue.is_empty()


## The recipe for an id, or an empty dictionary.
func _recipe(id: String) -> Dictionary:
	if id.begins_with("voice."):
		var parts: PackedStringArray = id.split(".")
		if parts.size() < 3:
			return {}
		var voice: String = parts[1]
		var gesture: String = ".".join(parts.slice(2))
		return grunts.get("voices", {}).get(voice, {}).get("gestures", {}).get(gesture, {})
	return impacts.get("sounds", {}).get(id, {})
