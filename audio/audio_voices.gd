class_name AudioVoices
extends Node
## Plays cues (audio_cues.gd): a pool of AudioStreamPlayer2D voices on the buses in data/mix.json. It is the only part
## of the audio code that needs the scene tree and a sound device.
##
## Space. The sim's x wraps around the planet, so a sound's distance is the shortest arc from the camera (SimWrap.sdx),
## as in rendering: a fight across the seam is as loud as it really is. The player is given the camera-relative offset
## times the zoom, with an AudioListener2D at the origin, so Godot's own 2D panning follows what is on screen. Level
## by distance comes from mix.json, not from Godot's attenuation (which would measure screen pixels).
##
## Voice cap. mix.json "voices" players; when all are busy a new cue takes the quietest, lowest-priority voice if its
## own priority is at least as high, and is dropped otherwise. A cue with a group replaces the earlier voice in that
## group (each fighter has one mouth).

var bank: AudioBank
var mix: Dictionary = {}
var played: int = 0
var dropped: int = 0
var _pool: Array = []          # AudioStreamPlayer2D
var _meta: Array = []          # per player: {priority, group, t}
var _listener: AudioListener2D
var _clock: float = 0.0


func _init(p_bank: AudioBank = null) -> void:
	bank = p_bank if p_bank != null else AudioBank.new()
	mix = AudioBank.load_json("res://audio/data/mix.json")


func _ready() -> void:
	setup_buses(mix)
	_listener = AudioListener2D.new()
	add_child(_listener)
	_listener.make_current()
	for i in range(int(mix.voices)):
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 1.0e7      # distance is handled in play(); never let Godot cut a voice off
		p.attenuation = 0.0
		add_child(p)
		_pool.append(p)
		_meta.append({"priority": -1, "group": "", "t": -1.0})


func _process(delta: float) -> void:
	_clock += delta


## Create the buses and the master limiter named in mix.json (once; safe to call again).
static func setup_buses(m: Dictionary) -> void:
	for b in m.buses:
		var idx: int = AudioServer.get_bus_index(b.name)
		if idx == -1:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b.name)
			AudioServer.set_bus_send(idx, "Master")
			if b.has("lowpass_hz"):
				var lp := AudioEffectLowPassFilter.new()
				lp.cutoff_hz = float(b.lowpass_hz)
				AudioServer.add_bus_effect(idx, lp)
		AudioServer.set_bus_volume_db(idx, float(b.volume_db))
	if AudioServer.get_bus_effect_count(0) == 0 and m.has("master_limiter"):
		var lim := AudioEffectLimiter.new()
		lim.threshold_db = float(m.master_limiter.threshold_db)
		lim.ceiling_db = float(m.master_limiter.ceiling_db)
		AudioServer.add_bus_effect(0, lim)


## Level in dB for a sound this far (world units) from the camera; below the floor means inaudible.
func distance_db(dist: float) -> float:
	var s: Dictionary = mix.space
	var f: float = clampf(dist / float(s.max_distance), 0.0, 1.0)
	return float(s.min_gain_db) * pow(f, float(s.rolloff))


## Play a cue for a camera at cam_x with zoom pixels per world unit. Returns true if a voice took it.
func play(cue: AudioCues.Cue, cam_x: float, zoom: float = 1.0) -> bool:
	var dx: float = SimWrap.sdx(cam_x, cue.x)
	var dist: float = absf(dx)
	if dist >= float(mix.space.max_distance):
		dropped += 1
		return false
	var slot: int = _take(cue)
	if slot < 0:
		dropped += 1
		return false
	var p: AudioStreamPlayer2D = _pool[slot]
	p.stop()
	p.stream = bank.stream(cue.sound, cue.variant)
	p.volume_db = cue.gain_db + distance_db(dist)
	p.pitch_scale = cue.pitch
	p.bus = cue.bus
	if cue.muffled:
		p.bus = "SfxMuffled" if cue.bus == "Sfx" else ("VoiceMuffled" if cue.bus == "Voice" else cue.bus)
	p.position = Vector2(dx * zoom, 0.0)
	p.play()
	_meta[slot] = {"priority": cue.priority, "group": cue.group, "t": _clock}
	played += 1
	return true


## Which pool slot a cue may use: its own group's voice, then a free one, then the weakest voice it outranks.
func _take(cue: AudioCues.Cue) -> int:
	if cue.group != "":
		for i in range(_pool.size()):
			if _meta[i].group == cue.group and _pool[i].playing:
				return i
	var weakest: int = -1
	for i in range(_pool.size()):
		if not _pool[i].playing:
			return i
		if weakest == -1 or _meta[i].priority < _meta[weakest].priority or (_meta[i].priority == _meta[weakest].priority and _meta[i].t < _meta[weakest].t):
			weakest = i
	if weakest != -1 and cue.priority >= int(_meta[weakest].priority):
		return weakest
	return -1


func active() -> int:
	var n: int = 0
	for p in _pool:
		if p.playing:
			n += 1
	return n
