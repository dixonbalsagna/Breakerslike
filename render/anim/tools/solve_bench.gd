extends SceneTree
## Solve cost bench: the same seeded match run several times, alternating configurations, the mean microseconds a solve in each.
## Machine noise is large, so the configurations alternate round by round and the minimum of the rounds is reported with the mean.
## Configurations: everything on, each overhaul layer switched off alone (RenderAnim.layers_off), the overhaul off (--noragdoll),
## and each quality level of data/anim/quality.json. The saving of a layer is the difference to everything on, in microseconds a
## solve; with the layers sorted by it, that is the order to drop them in.
##   godot --headless --path . --script res://render/anim/tools/solve_bench.gd [-- --seed=4 --ticks=1800 --rounds=3 --levels]

const DT := 1.0 / 60.0
const LAYERS := ["ragdoll", "feet", "look", "aim", "personality", "transitions", "defender", "flight", "cloth", "lean"]

var seed_: int = 4
var ticks: int = 1800
var rounds: int = 3
var levels: bool = false
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_ = int(a.substr(7))
		elif a.begins_with("--ticks="):
			ticks = int(a.substr(8))
		elif a.begins_with("--rounds="):
			rounds = int(a.substr(9))
		elif a == "--levels":
			levels = true
	DirData.templatesProfile = "dynamic"
	var vpn := SubViewport.new()
	vpn.size = Vector2i(1280, 720)
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _one(overhaul: bool, off: Array, level: String) -> float:
	RenderAnim.enabled = true
	RenderAnim.ragdoll_enabled = overhaul
	RenderAnim.ground_feet = true
	RenderAnim.layers_off.clear()
	for nm in off:
		RenderAnim.layers_off[nm] = true
	RenderAnim.set_quality(level)
	RenderAnim.solve_usec = 0
	RenderAnim.solve_count = 0
	main.start_match(seed_, {"p1": true, "p2": true})
	while main.host.ticks < ticks:
		main.frame(DT)
	return float(RenderAnim.solve_usec) / maxf(1.0, RenderAnim.solve_count)


func _run() -> void:
	await process_frame
	AnimData.load_all()
	var cfgs: Array = [["everything on", true, [], "high"], ["overhaul off", false, [], "high"]]
	for nm in LAYERS:
		cfgs.append(["off: " + nm, true, [nm], "high"])
	if levels:
		for lv in AnimData.quality_levels:
			cfgs.append(["level: " + lv, true, [], lv])
	var res: Array = []
	for c in cfgs:
		res.append([])
	for r in range(rounds):
		for i in range(cfgs.size()):
			res[i].append(_one(cfgs[i][1], cfgs[i][2], cfgs[i][3]))
	var mins: Array = []
	for i in range(cfgs.size()):
		var mn: float = 1.0e9
		var sum: float = 0.0
		for v in res[i]:
			mn = minf(mn, v)
			sum += v
		mins.append(mn)
		print("%-18s min %.1f us, mean %.1f us a solve (%d rounds)" % [cfgs[i][0], mn, sum / res[i].size(), res[i].size()])
	var base: float = mins[0]
	var saves: Array = []
	for i in range(2, 2 + LAYERS.size()):
		saves.append([base - mins[i], LAYERS[i - 2]])
	saves.sort_custom(func(a, b): return a[0] > b[0])
	print("\nwhat each layer costs (everything on minus the layer off, us a solve), biggest first:")
	for s in saves:
		print("  %-14s %.1f" % [s[1], s[0]])
	print("the whole overhaul: %.1f us a solve" % (base - mins[1]))
	RenderAnim.layers_off.clear()
	RenderAnim.set_quality("high")
	quit(0)
