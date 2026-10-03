extends SceneTree
## Launch-pair coverage check (docs/animation/launch-pair-coverage.md): every row of docs/animation/launch-pair-coverage.json (a move, shot kind, ending or set piece of the next
## update, per fighter, and the pose, sequence or key set that plays it) is looked up in the real loader with every wave baked. A row that says live or parked must find all
## its ids (a key set needs its chamber, contact and follow poses; a sequence its phases' poses); a `gap` row is a hole. design, later and blocked rows are listed, not checked.
##   godot --headless --path . -s res://render/anim/tools/coverage.gd -- [--strict] [--list]
## Exit 1 with --strict when an id is missing or a row is a gap. --list prints every row.

const FILE := "res://docs/animation/launch-pair-coverage.json"
var strict: bool = false
var list_all: bool = false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--strict":
			strict = true
		elif a == "--list":
			list_all = true
	_run.call_deferred()


## An id found in the baked data: a pose, a key set, a sequence or entry; the shared set prefixes (ls1, win, gc, in) match any pose of the set.
func _found(id: String) -> String:
	if AnimData.poses.has(id):
		return ""
	if AnimData.keysets.has(id):
		var miss: Array = []
		for k in AnimData.keysets[id].get("keys", []):
			if not AnimData.poses.has(String(k.pose)):
				miss.append(String(k.pose))
		return "" if miss.is_empty() else "its poses are missing: " + ", ".join(miss)
	if AnimData.entries.has(id):
		var miss2: Array = []
		for ph in AnimData.entries[id].get("phases", []):
			if not AnimData.poses.has(String(ph.pose)):
				miss2.append(String(ph.pose))
		return "" if miss2.is_empty() else "its poses are missing: " + ", ".join(miss2)
	var sets: Dictionary = {"ls1": "ls.", "win": "win.", "gc": "gc.", "in": "in."}
	if sets.has(id):
		for pid in AnimData.poses:
			if String(pid).begins_with(String(sets[id])):
				return ""
		return "no pose of the set"
	return "not found"


func _run() -> void:
	await process_frame
	AnimRig.setup()
	AnimData.load_every_wave()
	var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if typeof(d) != TYPE_DICTIONARY:
		print("COVERAGE: cannot read ", FILE)
		quit(1)
		return
	var counts: Dictionary = {}
	var bad: Array = []
	var ids_checked: int = 0
	for r in d.rows:
		var st: String = String(r.status)
		counts[st] = int(counts.get(st, 0)) + 1
		if list_all:
			print("%-8s %-12s %-28s %s" % [st, String(r.fighter), String(r.area), String(r.item)])
		if st == "gap":
			bad.append("GAP  %s: %s (%s)" % [r.fighter, r.item, r.note])
		elif st == "live" or st == "parked":
			if r.plays.is_empty() and String(r.type) != "none":
				bad.append("EMPTY %s: %s plays nothing" % [r.fighter, r.item])
			for id in r.plays:
				ids_checked += 1
				var why: String = _found(String(id))
				if why != "":
					bad.append("MISSING %s: %s -> %s (%s)" % [r.fighter, r.item, id, why])
	print("\n== launch-pair coverage ==")
	print("%d rows, %d ids checked: %s" % [d.rows.size(), ids_checked, JSON.stringify(counts)])
	for b in bad:
		print("  " + b)
	print("coverage: %s" % ("every posed row finds its poses and there is no gap" if bad.is_empty() else "%d problems" % bad.size()))
	quit(1 if (strict and not bad.is_empty()) else 0)
