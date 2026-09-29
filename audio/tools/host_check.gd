extends SceneTree
## Does the audio hook behave? Runs seeded AI-vs-AI matches on the real sim and feeds each tick's fx events to
## AudioCues, as a render host would. From the repo root:
##   godot --headless --path . --script res://audio/tools/host_check.gd [-- --seeds=4,12345,777 --ticks=5400]
## For every seed it checks:
##   1. the sim is unchanged: the gameplay hash every 60 ticks and at the end is identical with and without audio
##      (audio reads the sim and draws nothing from its RNG);
##   2. the cues are reproducible: a second audio run gives the same cue log (same variants, pitches, levels);
##   3. every cue names a sound the bank can render, and every cue's numbers are finite and inside the data's limits;
##   4. what a fight sounds like: cues per sound, grunts, the busiest tick.
## Exit code 1 on any failure. No sound device is used.

var seeds: Array = [4, 12345, 777]
var max_ticks: int = 5400


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
	var bank := AudioBank.new()
	var ok: bool = true
	for sd in seeds:
		var plain: Array = _run(sd, null)
		var cues := AudioCues.new(bank)
		var with_audio: Array = _run(sd, cues)
		var again_cues := AudioCues.new(bank)
		var again: Array = _run(sd, again_cues)
		var same_sim: bool = str(plain[0]) == str(with_audio[0])
		var same_cues: bool = with_audio[2] == again[2]
		var bad: String = _validate(with_audio[3], bank, cues.cfg)
		ok = ok and same_sim and same_cues and bad == ""
		print("seed %-6d ticks %d  sim hash %s  %s" % [sd, plain[1], str(plain[0][-1]), "unchanged by audio" if same_sim else "CHANGED BY AUDIO"])
		print("            cue log %s  %s   %d cues (%.1f a minute), busiest tick %d" % [with_audio[2].substr(0, 16), "reproducible" if same_cues else "NOT REPRODUCIBLE", with_audio[3].size(), with_audio[3].size() * 3600.0 / with_audio[1], with_audio[4]])
		var by: Dictionary = {}
		for c in with_audio[3]:
			by[c.sound] = by.get(c.sound, 0) + 1
		var parts: Array = []
		for k in by:
			parts.append("%s %d" % [k, by[k]])
		parts.sort()
		print("            " + ", ".join(parts))
		if bad != "":
			print("            FAIL: " + bad)
	print("\naudio host check passed" if ok else "\naudio host check FAILED")
	quit(0 if ok else 1)


## [gameplay hashes every 60 ticks + last, ticks run, cue-log sha256, all cues, busiest tick]
func _run(sd: int, cues) -> Array:
	var S := SimCore.createSim()
	SimCore.newMatch(S, sd)
	if cues != null:
		cues.reset(sd)
	var hashes: Array = []
	var all: Array = []
	var lines := PackedStringArray()
	var busiest: int = 0
	var t: int = 0
	while t < max_ticks and not (S.game.ko != null and S.game.koT > 3.0):
		SimCore.step(S)
		if cues != null:
			var made: Array = cues.consume(S, S.out.fx)
			busiest = maxi(busiest, made.size())
			for c in made:
				all.append(c)
				lines.append("%d|%s|%d|%.3f|%.3f|%.3f|%.4f|%s|%s" % [t, c.sound, c.variant, c.x, c.y, c.gain_db, c.pitch, c.group, str(c.muffled)])
		S.out.fx.clear()
		S.out.feed.clear()
		t += 1
		if t % 60 == 0:
			hashes.append(SimHash.stateHash(S).gameplay)
	hashes.append(SimHash.stateHash(S).gameplay)
	SimCore.dispose(S)
	return [hashes, t, "\n".join(lines).sha256_text(), all, busiest]


func _validate(all: Array, bank: AudioBank, cfg: Dictionary) -> String:
	for c in all:
		if not bank.has_sound(c.sound):
			return "cue for a sound the bank does not have: " + c.sound
		if c.variant < 0 or c.variant >= bank.variants(c.sound):
			return "variant out of range for " + c.sound
		if not (is_finite(c.gain_db) and is_finite(c.pitch) and is_finite(c.x) and is_finite(c.y)):
			return "a cue has a non-finite number: " + c.sound
		if c.pitch < 0.4 or c.pitch > 2.0:
			return "pitch %.2f outside 0.4 to 2.0 for %s" % [c.pitch, c.sound]
		if c.gain_db < -20.0 or c.gain_db > 8.0:
			return "gain %.1f dB outside -20 to +8 for %s" % [c.gain_db, c.sound]
		if c.x < 0.0 or c.x >= SimConst.W:
			return "x %.1f is outside the planet for %s" % [c.x, c.sound]
	return ""
