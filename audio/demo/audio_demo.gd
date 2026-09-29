extends Node
## Listen to the audio prototype, no rendering needed. Run it from the repo root:
##   godot --path . res://audio/demo/audio_demo.tscn
##
## Keys: 1 light hit, 2 heavy hit, 3 crater, 4 Protagonist effort grunt, 5 Anti-hero effort grunt,
##       P move the source left / centre / right (tests panning), M start or stop a live seeded match.
## The live match is the real sim, stepped at 60 Hz here with no graphics. Each tick's fx events go to AudioCues, and the
## cues go to AudioVoices, exactly as a render host would do it (audio/README.md, "Hooking it up"). The camera stand-in is
## the midpoint of the two fighters.
##
## Command-line options (after "--"): --auto (start the live match at once), --seed=N, --frames=N (quit after N frames;
## for a headless smoke test with the dummy audio driver).

const TICK := 1.0 / 60.0

var bank: AudioBank
var cues: AudioCues
var voices: AudioVoices
var S: SimState
var live: bool = false
var seed_: int = 4
var acc: float = 0.0
var frames: int = 0
var max_frames: int = 0
var pos_mode: int = 1               # 0 left, 1 centre, 2 right
var log_lines: Array = []
var label: Label


func _ready() -> void:
	var args: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	seed_ = int(args.get("seed", 4))
	max_frames = int(args.get("frames", 0))
	bank = AudioBank.new()
	var ms: float = bank.warm()
	cues = AudioCues.new(bank)
	voices = AudioVoices.new(bank)
	add_child(voices)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(24, 20)
	layer.add_child(label)
	_say("bank rendered in %.0f ms (%d sounds)" % [ms, bank.ids().size()])
	if args.has("auto"):
		_toggle_live()
	_refresh()


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_1: _manual("impact.light", 12.0)
		KEY_2: _manual("impact.heavy", 60.0)
		KEY_3: _manual("impact.crater", 4.0)
		KEY_4: _voice("protagonist")
		KEY_5: _voice("anti_hero")
		KEY_P:
			pos_mode = (pos_mode + 1) % 3
			_refresh()
		KEY_M: _toggle_live()


func _process(delta: float) -> void:
	if live:
		acc += minf(delta, 0.1)
		while acc >= TICK:
			acc -= TICK
			_tick()
	frames += 1
	if max_frames > 0 and frames >= max_frames:
		print("frames done: %d cues played, %d dropped, %d voices active" % [voices.played, voices.dropped, voices.active()])
		get_tree().quit(0)


func _toggle_live() -> void:
	live = not live
	if live:
		if S != null:
			SimCore.dispose(S)
		S = SimCore.createSim()
		SimCore.newMatch(S, seed_)
		cues.reset(seed_)
		acc = 0.0
		_say("live match, seed %d" % seed_)
	_refresh()


## One host tick: step the sim, hand the events to the cue mapper, play what it returns.
func _tick() -> void:
	SimCore.step(S)
	var made: Array = cues.consume(S, S.out.fx)
	S.out.fx.clear()
	S.out.feed.clear()
	var f0 = S.fighters[0]
	var f1 = S.fighters[1]
	var cam_x: float = SimWrap.wrap(f0.x + SimWrap.sdx(f0.x, f1.x) * 0.5)
	for c in made:
		var ok: bool = voices.play(c, cam_x, 0.35)
		_say("%5.1fs  %-34s v%d  %+5.1f dB  x%.2f  %s%s" % [S.T, c.sound, c.variant, c.gain_db, c.pitch, c.caption, "" if ok else "  (dropped)"])


func _manual(id: String, size: float) -> void:
	var c: AudioCues.Cue = cues.make_sfx(null, id, _offset(), 40.0, size, cues.cfg.damage if id != "impact.crater" else cues.cfg.crater)
	voices.play(c, 0.0, 0.35)
	_say("%-16s v%d  %+5.1f dB  x%.2f" % [c.sound, c.variant, c.gain_db, c.pitch])


func _voice(voice: String) -> void:
	var id: String = "voice.%s.effort.heavy" % voice
	var c := AudioCues.Cue.new()
	c.sound = id
	c.kind = "voice"
	c.variant = randi() % bank.variants(id)
	c.x = _offset()
	c.y = 40.0
	c.gain_db = -2.0
	c.bus = "Voice"
	c.priority = 70
	c.group = "voice." + voice
	voices.play(c, 0.0, 0.35)
	_say("%-34s v%d" % [id, c.variant])


func _offset() -> float:
	return [-1200.0, 0.0, 1200.0][pos_mode]


func _say(line: String) -> void:
	print(line)
	log_lines.append(line)
	while log_lines.size() > 14:
		log_lines.pop_front()
	_refresh()


func _refresh() -> void:
	if label == null:
		return
	label.text = "Audio prototype (procedural, generated at runtime)\n\n1 light hit    2 heavy hit    3 crater\n4 Protagonist effort    5 Anti-hero effort\nP source position: %s    M live match: %s\n\n%s" % [
		["left", "centre", "right"][pos_mode], "ON" if live else "off", "\n".join(log_lines)]
