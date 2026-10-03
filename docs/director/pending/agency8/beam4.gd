extends SceneTree
# Read-only: AI against AI, how signatures end. Args: matches, base seed. Counts the beam_outcome events by kind, the
# beam-play cues (beam_swat, beam_split, beam_walk, beam_wade, beam_late), the signatures started and the clashes won
# by the attacker, and the damage by kind.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n: int = int(args[0]); var base: int = int(args[1])
	var outs := {}; var cues := {}; var sigs := 0; var dmg := {}; var mins := 0.0; var clashA := 0; var clashes := 0
	for i in range(n):
		var S := SimCore.createSim()
		SimCore.newMatch(S, base + i)
		var steps := 0
		var sigA := -1
		while steps < 54000 and S.game.ko == null:
			SimCore.step(S)
			steps += 1
			for e in S.out.fx:
				if e.type == "attack" and str(e.kind) == "sig":
					sigs += 1
					sigA = int(e.actor)
				elif e.type == "beam_outcome":
					outs[str(e.kind)] = outs.get(str(e.kind), 0) + 1
				elif e.type == "cue" and str(e.kind).begins_with("beam_"):
					cues[str(e.kind)] = cues.get(str(e.kind), 0) + 1
				elif e.type == "decisive" and str(e.kind) == "beam_clash":
					clashes += 1
					if int(e.winner) == sigA: clashA += 1
				elif e.type == "damage" and int(e.attacker) >= 0:
					dmg[e.kind] = dmg.get(e.kind, 0.0) + e.amount
			S.out.fx.clear(); S.out.feed.clear()
		mins += S.T / 60.0
		SimCore.dispose(S)
	print(JSON.stringify({"n": n, "mins": snappedf(mins, 0.1), "signatures": sigs, "outcomes": outs, "cues": cues, "clashes decided": clashes, "won by the attacker": clashA, "dmg": dmg}))
	quit()
