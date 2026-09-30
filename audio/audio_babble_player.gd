class_name AudioBabblePlayer
extends Node
## Plays a babble plan (audio_babble.gd) while its caption is revealed. It has no clock of its own: the caller gives it
## the line's age in seconds (the same age that drives the text reveal, ui/core/ui_bark_timing.gd), so a replay seek
## lands on the right syllable and a pause or a slow-down in the text pauses the voice with it. Each event is one call to
## AudioVoices.play; a fighter alternates between two voice groups, so a syllable never cuts off the one before it.
##
## Interruption follows the line system's priorities (docs/narrative/line-system.md section 3): speak() replaces the
## fighter's earlier line, and cut() stops it (a higher-priority line, a KO).

const LATE := 0.25       # an event later than this when first seen (a stall, a seek) is skipped, not played in a burst

var voices: AudioVoices
var played: int = 0
var _speech: Dictionary = {}     # actor -> {plan, next, flip, last_age}


func _init(p_voices: AudioVoices = null) -> void:
	voices = p_voices


## Start a plan for a fighter (replacing any line it was saying).
func speak(actor: int, plan: AudioBabble.Plan) -> void:
	_speech[actor] = {"plan": plan, "next": 0, "flip": 0, "last_age": -1.0}


func cut(actor: int) -> void:
	_speech.erase(actor)


func speaking(actor: int) -> bool:
	return _speech.has(actor)


## Play what is due at `age` seconds into the line. x, y is where the fighter's mouth is now; cam_x and zoom are as for
## AudioVoices.play. Returns how many sounds it started. The speech ends itself once its plan is finished.
func sync(actor: int, age: float, x: float, y: float, cam_x: float, zoom: float = 1.0) -> int:
	if not _speech.has(actor):
		return 0
	var sp: Dictionary = _speech[actor]
	var plan: AudioBabble.Plan = sp.plan
	if age < float(sp.last_age) - 0.05:                 # a seek backwards: find the next event again
		sp["next"] = 0
		while int(sp.next) < plan.events.size() and plan.events[int(sp.next)].t <= age:
			sp["next"] = int(sp.next) + 1
	sp["last_age"] = age
	var n: int = 0
	while int(sp.next) < plan.events.size() and plan.events[int(sp.next)].t <= age:
		var e: AudioBabble.Ev = plan.events[int(sp.next)]
		sp["next"] = int(sp.next) + 1
		if age - e.t > LATE:
			continue
		var cue := AudioCues.Cue.new()
		cue.sound = e.sound
		cue.kind = "voice"
		cue.variant = e.variant
		cue.x = x
		cue.y = y
		cue.gain_db = e.gain_db
		cue.pitch = pow(2.0, e.st / 12.0)
		cue.priority = 70
		cue.bus = "Voice"
		sp["flip"] = 1 - int(sp.flip)
		cue.group = "babble.%d.%d" % [actor, int(sp.flip)]
		if voices != null and voices.play(cue, cam_x, zoom):
			n += 1
			played += 1
	if age > plan.total + 0.5:
		_speech.erase(actor)
	return n
