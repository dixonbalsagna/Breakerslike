extends SceneTree
## Render the whole bank to WAV files and print each sound's size, level and render time. From the repo root:
##   godot --headless --path . --script res://audio/tools/render_wavs.gd [-- --out=DIR]
## --variants=N writes at most N variants of each sound (default 2). DIR defaults to audio/preview (the committed previews, so anyone can listen without opening Godot). The previews
## are derived output: the recipes in audio/data are the source, and this tool regenerates them.
## audio/tools/analyse_wav.py prints spectral checks and draws a spectrogram of any of them.

func _init() -> void:
	var out_dir: String = ProjectSettings.globalize_path("res://audio/preview")
	var max_variants: int = 2     # the committed previews keep two variants of each sound, to stay small
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--variants="):
			max_variants = int(a.substr(11))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bank := AudioBank.new()
	var total: float = 0.0
	print("%-44s %7s %8s %8s %8s %9s" % ["sound", "samples", "seconds", "peak dB", "rms dB", "render ms"])
	for id in bank.ids():
		for v in range(mini(bank.variants(id), max_variants)):
			var t0: int = Time.get_ticks_usec()
			var buf: PackedFloat32Array = bank.buffer(id, v)
			var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
			total += ms
			var rate: int = bank.rate_of(id)
			var w: AudioStreamWAV = AudioDsp.to_wav(buf, rate)
			var path: String = "%s/%s.v%d.wav" % [out_dir, id, v]
			var err: int = w.save_to_wav(path)
			if err != OK:
				push_error("could not write %s (error %d)" % [path, err])
				quit(1)
				return
			print("%-44s %7d %8.3f %8.1f %8.1f %9.1f" % [
				"%s.v%d" % [id, v], buf.size(), float(buf.size()) / rate,
				20.0 * log(maxf(AudioDsp.peak(buf), 1e-9)) / log(10.0),
				20.0 * log(maxf(AudioDsp.rms(buf), 1e-9)) / log(10.0), ms])
	print("rendered the whole bank in %.0f ms; wrote WAVs to %s" % [total, out_dir])
	quit(0)
