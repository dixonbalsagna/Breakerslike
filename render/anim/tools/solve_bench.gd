extends SceneTree
## Solve cost bench: the same seeded match run several times, alternating configurations (everything on, the ground feet off, the
## whole overhaul off), the mean microseconds a solve in each. Machine noise is large, so the configurations alternate and the
## minimum of the runs is reported with the mean.
##   godot --headless --path . --script res://render/anim/tools/solve_bench.gd [-- --seed=4 --ticks=1800 --rounds=3]

const DT := 1.0 / 60.0

var seed_: int = 4
var ticks: int = 1800
var rounds: int = 3
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_ = int(a.substr(7))
		elif a.begins_with("--ticks="):
			ticks = int(a.substr(8))
		elif a.begins_with("--rounds="):
			rounds = int(a.substr(9))
	DirData.templatesProfile = "dynamic"
	var vpn := SubViewport.new()
	vpn.size = Vector2i(1280, 720)
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _one(ragdoll: bool, feet: bool) -> float:
	RenderAnim.enabled = true
	RenderAnim.ragdoll_enabled = ragdoll
	RenderAnim.ground_feet = feet
	RenderAnim.solve_usec = 0
	RenderAnim.solve_count = 0
	main.start_match(seed_, {"p1": true, "p2": true})
	while main.host.ticks < ticks:
		main.frame(DT)
	return float(RenderAnim.solve_usec) / maxf(1.0, RenderAnim.solve_count)


func _run() -> void:
	await process_frame
	var names: Array = ["overhaul on", "ground feet off", "overhaul off"]
	var res: Array = [[], [], []]
	for r in range(rounds):
		res[0].append(_one(true, true))
		res[1].append(_one(true, false))
		res[2].append(_one(false, false))
	for i in range(3):
		var mn: float = 1.0e9
		var sum: float = 0.0
		for v in res[i]:
			mn = minf(mn, v)
			sum += v
		print("%-16s min %.1f us, mean %.1f us a solve (%d rounds)" % [names[i], mn, sum / res[i].size(), res[i].size()])
	quit(0)
