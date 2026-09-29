extends SceneTree
## Render the three 30-second music sketches (docs/audio/direction.md section 3) to WAV files and print a per-bar
## loudness table, so the arc (quiet overture, building tune, the bar-6 drop-out, the peak, the KO tail) can be checked
## without listening. From the repo root:
##   godot --headless --path . --script res://audio/tools/render_sketches.gd [-- --out=DIR]
## DIR defaults to audio/preview. Mono 16-bit at 13 kHz keeps three sketches near 2.3 MB.

const NAMES := {"a": "sketch-a-town-band", "b": "sketch-b-furnace", "c": "sketch-c-kitchen-drums"}

func _init() -> void:
	var out_dir: String = ProjectSettings.globalize_path("res://audio/preview")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var common: Dictionary = AudioBank.load_json("res://audio/data/sketch_common.json")
	for id in ["a", "b", "c"]:
		var spec: Dictionary = AudioBank.load_json("res://audio/data/sketch_%s.json" % id)
		spec.merge(common)
		var t0: int = Time.get_ticks_usec()
		var buf: PackedFloat32Array = MusicSketch.render(spec, 20260929)
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		var rate: int = int(spec.rate)
		var path: String = "%s/%s.wav" % [out_dir, NAMES[id]]
		var err: int = AudioDsp.to_wav(buf, rate).save_to_wav(path)
		if err != OK:
			push_error("could not write " + path)
			quit(1)
			return
		var bar_n: int = int(float(rate) * 2.5)
		var row: PackedStringArray = []
		for bar in range(int(spec.bars)):
			var seg: PackedFloat32Array = buf.slice(bar * bar_n, (bar + 1) * bar_n)
			row.append("%5.1f" % (20.0 * log(maxf(AudioDsp.rms(seg), 1e-9)) / log(10.0)))
		print("%s  %.1f s, %d Hz, peak %.1f dB, %.0f ms to render" % [NAMES[id], float(buf.size()) / rate, rate, 20.0 * log(AudioDsp.peak(buf)) / log(10.0), ms])
		print("   RMS dB per bar: " + " ".join(row))
	quit(0)
