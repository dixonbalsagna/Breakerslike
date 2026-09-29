extends SceneTree
## Render the twelve head-flash cues for the chosen sound families and print their length and level. From the repo root:
##   godot --headless --path . --script res://audio/tools/render_flashes.gd [-- --families=circles,steps --out=DIR]
## The default writes the Protagonist's family (circles) to audio/preview/flash-<family>-<flash>.wav; pass other families to hear them.

func _init() -> void:
	var out_dir: String = ProjectSettings.globalize_path("res://audio/preview")
	var fams: Array = ["circles"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--families="):
			fams = Array(a.substr(11).split(","))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bank := AudioBank.new()
	var total: float = 0.0
	print("%-22s %7s %8s %8s %9s" % ["cue", "seconds", "peak dB", "rms dB", "render ms"])
	for fam in fams:
		for fl in bank.flashes.flashes:
			var id: String = "flash.%s.%s" % [fl, fam]
			var t0: int = Time.get_ticks_usec()
			var buf: PackedFloat32Array = bank.buffer(id, 0)
			var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
			total += ms
			var rate: int = bank.rate_of(id)
			var err: int = AudioDsp.to_wav(buf, rate).save_to_wav("%s/flash-%s-%s.wav" % [out_dir, fam, fl])
			if err != OK:
				push_error("write failed")
				quit(1)
				return
			print("%-22s %7.3f %8.1f %8.1f %9.1f" % ["%s.%s" % [fam, fl], float(buf.size()) / rate, 20.0 * log(maxf(AudioDsp.peak(buf), 1e-9)) / log(10.0), 20.0 * log(maxf(AudioDsp.rms(buf), 1e-9)) / log(10.0), ms])
	print("rendered %d cues in %.0f ms" % [fams.size() * bank.flashes.flashes.size(), total])
	quit(0)
