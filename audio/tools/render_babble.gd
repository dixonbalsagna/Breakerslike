extends SceneTree
## Render the babble previews: five captions per fighter, each planned and mixed exactly as the game would speak them.
## From the repo root:
##   godot --headless --path . --script res://audio/tools/render_babble.gd [-- --out=DIR --seed=N]
## Writes DIR/babble-<voice>.wav (the five captions in a row with a 0.7 s gap) at 12 kHz mono, and prints, for each
## caption, the mood, how many syllables, laughs and grunts it got, and how long the reveal and the sound run.

func _init() -> void:
	var out_dir: String = ProjectSettings.globalize_path("res://audio/preview")
	var seed: int = 4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--seed="):
			seed = int(a.substr(7))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bank := AudioBank.new()
	var bab := AudioBabble.new(bank)
	bab.reset(seed)
	var caps: Dictionary = AudioBank.load_json("res://audio/data/babble_captions.json").captions
	var rate: int = int(bank.babble.rate)
	for voice in caps:
		var t0: int = Time.get_ticks_usec()
		var song := PackedFloat32Array()
		print("\n%s" % voice)
		var t_plan: float = 0.0
		var t_mix: float = 0.0
		for line in caps[voice]:
			var p0: int = Time.get_ticks_usec()
			var plan: AudioBabble.Plan = bab.plan(voice, line.text, line.mood, int(line.intensity), line.get("cues", []), SimRng.deriveSeed(seed, "audio.babble." + line.text))
			var p1: int = Time.get_ticks_usec()
			var buf: PackedFloat32Array = bab.mix(plan, rate)
			t_plan += (p1 - p0) / 1000.0
			t_mix += (Time.get_ticks_usec() - p1) / 1000.0
			AudioDsp.mix_into(song, buf, song.size(), 1.0)
			song.resize(song.size() + int(0.7 * rate))
			print("  %-9s %2d syl %d laugh %d grunt  reveal %.2f s, sound %.2f s  \"%s\"" % [plan.emotion, plan.count("syl"), plan.count("laugh"), plan.count("grunt"), plan.reveal, plan.total, line.text])
		AudioDsp.normalize(song, AudioDsp.db_to_lin(-3.0))
		AudioDsp.fade(song, 0.003, 0.05, rate)
		var err: int = AudioDsp.to_wav(song, rate).save_to_wav("%s/babble-%s.wav" % [out_dir, voice])
		if err != OK:
			push_error("write failed")
			quit(1)
			return
		print("  %.1f s of audio; planning 5 lines %.2f ms, mixing %.0f ms, whole voice %.0f ms" % [float(song.size()) / rate, t_plan, t_mix, (Time.get_ticks_usec() - t0) / 1000.0])
	quit(0)
