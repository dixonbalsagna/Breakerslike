extends SceneTree
## Live-coverage check (docs/animation/pair-live.md): the launch-pair coverage table (docs/animation/launch-pair-coverage.json) restated for a live match. Only the live loader runs
## (AnimData.load_all, then ensure_fighter for KAI and VORR: no --waves, no load_every_wave), so a row counts as loaded only when the ids it plays are baked by what a match really
## loads. docs/animation/launch-pair-live-status.json then says which of the loaded rows the sim starts today (live), which wait for a trigger it does not send yet (wired), and which
## nothing starts yet (baked). Fails with --strict when a row marked live, wired or baked is not loaded.
##   godot --headless --path . -s res://render/anim/tools/coverage_live.gd -- [--strict] [--list]

var strict: bool = false
var list_all: bool = false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--strict":
			strict = true
		elif a == "--list":
			list_all = true
	_run.call_deferred()


func _have(id: String) -> bool:
	if AnimData.poses.has(id) or AnimData.entries.has(id):
		return true
	if AnimData.keysets.has(id):
		for k in AnimData.keysets[id].get("keys", []):
			if not AnimData.poses.has(String(k.pose)):
				return false
		return true
	var sets: Dictionary = {"ls1": "ls.", "win": "win.", "gc": "gc.", "in": "in."}
	if sets.has(id):
		for pid in AnimData.poses:
			if String(pid).begins_with(String(sets[id])):
				return true
	return false


func _run() -> void:
	await process_frame
	AnimRig.setup()
	AnimData.load_all()
	var t0: int = Time.get_ticks_usec()
	AnimData.ensure_fighter("KAI")
	AnimData.ensure_fighter("VORR")
	var bake_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var cov = JSON.parse_string(FileAccess.get_file_as_string("res://docs/animation/launch-pair-coverage.json"))
	var rules = JSON.parse_string(FileAccess.get_file_as_string("res://docs/animation/launch-pair-live-status.json")).rules
	var counts: Dictionary = {}
	var bad: Array = []
	var before: Dictionary = {}
	for r in cov.rows:
		var st: String = String(r.status)
		before[st] = int(before.get(st, 0)) + 1
		var now: String = st
		if st == "live" or st == "parked":
			for rule in rules:
				if (String(rule.area) == "*" or String(rule.area) == String(r.area)) and (not rule.has("fighter") or String(rule.fighter) == String(r.fighter)) and (not rule.has("contains") or String(r.item).contains(String(rule.contains))):
					now = String(rule.status)
					break
			if now == "parked":
				now = "baked"
			if not r.plays.is_empty():
				for id in r.plays:
					if not _have(String(id)):
						bad.append("NOT LOADED %s: %s -> %s" % [r.fighter, r.item, id])
		counts[now] = int(counts.get(now, 0)) + 1
		if list_all:
			print("%-8s %-12s %-24s %s" % [now, String(r.fighter), String(r.area), String(r.item)])
	print("\n== launch-pair live coverage ==")
	print("%d rows. Before the live loader: %s" % [cov.rows.size(), JSON.stringify(before)])
	print("With it (only AnimData.load_all and ensure_fighter): %s" % JSON.stringify(counts))
	print("the pair's waves baked at match start in %.1f ms, %d poses" % [bake_ms, AnimData.pair_bake_poses])
	for b in bad:
		print("  " + b)
	print("live coverage: %s" % ("every row finds its ids in what a match loads" if bad.is_empty() else "%d problems" % bad.size()))
	quit(1 if (strict and not bad.is_empty()) else 0)
