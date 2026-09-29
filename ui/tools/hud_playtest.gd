extends SceneTree
## An automated stand-in for the HUD's playtest (spec-wounds.md section 5, tests 8 to 11). Real players are not
## available here, so this runs whole AI matches on the live sim, feeds the HUD's model with the real events and state,
## and measures what a player would be shown: how often the crown is up, how long each break waits for its card, how long
## a fighter is on the brink, whether a cap is ever exceeded, and whether the fighter the HUD shows as closer to losing at
## the midpoint is the one who loses. It draws nothing (no renderer needed):
##   godot --headless --path . --script res://ui/tools/hud_playtest.gd -- --matches=12 --seed=1
## Test 8 proxy: the brink chip and the cards' stages say who is closer at the midpoint; test 9 proxy: every break gets a
## card, and quickly; tests 10 and 11 need eyes (the crown at widest zoom, the Anti-hero's facade) and are not covered.

var matches := 12
var seed0 := 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			if kv[0] == "matches":
				matches = int(kv[1])
			elif kv[0] == "seed":
				seed0 = int(kv[1])
	_run.call_deferred()


func _wear_score(m: UiFighterModel) -> float:
	var s := 0.0
	for r in m.regions:
		s += float(m.true_stage[r])
	return s + (4.0 if m.brink else 0.0)


func _run() -> void:
	var tot := {"frames": 0, "crown_frames": 0, "brink_frames": 0, "cin_frames": 0, "haz_frames": 0, "cap_viol": 0, "bark_viol": 0,
		"breaks": 0, "break_cards": 0, "breaks_missed": 0, "finishers": 0, "kos": 0, "region_stages": 0, "damage": 0, "events": 0, "decisive": 0,
		"mid_right": 0, "mid_known": 0, "timeouts": 0}
	var latencies: Array = []
	var lengths: Array = []
	var types_seen := {}
	for mi in range(matches):
		var seed: int = seed0 + mi
		var host := SimHost.new()
		host.new_match(seed)
		var hud := UiHud.new()
		var f: Array = UiSimBridge.fighters(host.S)
		hud.hub.setup_fighters(f[0], f[1])
		var hub: UiEventHub = hud.hub
		var pending: Array = []
		var counts := {}
		host.drained.connect(func(evs: Array, lines: Array):
			for e in evs:
				counts[e.type] = int(counts.get(e.type, 0)) + 1
				if e.type == "region_broken":
					pending.append({"slot": int(e.actor), "region": str(e.region), "age": 0.0, "done": false})
			hub.consume_all(evs)
			UiSimBridge.feed(hud, lines))
		var mid_scores: Array = []
		var max_ticks := 43200
		var ko_tick := -1
		var t := 0
		while t < max_ticks:
			host.tick(1280.0, 720.0)
			t += 1
			UiSimBridge.patch(hud, host.S)
			hub.advance(1.0 / 60.0)
			tot["frames"] += 1
			if t == 3600 * 3 and mid_scores.is_empty():
				pass
			var any_crown := false
			for m in hub.models:
				if hub.crown_up(m.slot):
					any_crown = true
				if m.brink:
					tot["brink_frames"] += 1
			if any_crown:
				tot["crown_frames"] += 1
			if hub.mode == UiEventHub.Mode.CINEMATIC:
				tot["cin_frames"] += 1
			elif hub.mode == UiEventHub.Mode.HAZARD:
				tot["haz_frames"] += 1
			var cap: int = mini(UiLook.CAP_CARDS_PER_SIDE[hub.mode], hub.cap_limit)
			for slot in range(2):
				if hub.cards_of(slot).filter(func(c): return not c.fading).size() > cap:
					tot["cap_viol"] += 1
			if hub.barks.size() > UiLook.CAP_BARK_LINES[hub.mode]:
				tot["bark_viol"] += 1
			for p in pending:
				if p.done:
					continue
				p.age += 1.0 / 60.0
				for c in hub.cards:
					if c.slot == p.slot and c.stage == 3 and c.shown:
						p.done = true
						latencies.append(p.age)
						tot["break_cards"] += 1
						break
				if not p.done and p.age > 7.0:
					p.done = true
					tot["breaks_missed"] += 1
			# The midpoint: half of the eventual match, taken once the match has ended (we only know then), so store scores each second.
			if t % 60 == 0:
				mid_scores.append([_wear_score(hub.model(0)), _wear_score(hub.model(1))])
			if host.S.game.ko != null and ko_tick < 0:
				ko_tick = t
			if ko_tick >= 0 and t > ko_tick + 240:
				break
		if ko_tick < 0:
			tot["timeouts"] += 1
		else:
			lengths.append(float(ko_tick) / 60.0)
			var loser: int = host.S.fighters.find(host.S.game.ko)
			var mid: Array = mid_scores[mini(mid_scores.size() - 1, int(float(ko_tick) / 60.0 * 0.5))]
			if not is_equal_approx(mid[0], mid[1]):
				tot["mid_known"] += 1
				var closer: int = 0 if mid[0] > mid[1] else 1
				if closer == loser:
					tot["mid_right"] += 1
		for k in counts:
			types_seen[k] = int(types_seen.get(k, 0)) + int(counts[k])
		tot["breaks"] += int(counts.get("region_broken", 0))
		tot["finishers"] += int(counts.get("finisher_start", 0))
		tot["kos"] += int(counts.get("ko", 0))
		tot["region_stages"] += int(counts.get("region_stage", 0))
		tot["damage"] += int(counts.get("damage", 0))
		tot["decisive"] += int(counts.get("decisive", 0))
		tot["events"] += hub.stats["events"]
		host.S = null
		hud.free()
	latencies.sort()
	lengths.sort()
	var n: int = matches
	print("HUDPLAYTEST %d matches on the live sim (seeds %d to %d), no renderer" % [n, seed0, seed0 + n - 1])
	print("  match length (s): median %.0f, min %.0f, max %.0f; timeouts %d" % [lengths[lengths.size() / 2] if not lengths.is_empty() else 0.0, lengths[0] if not lengths.is_empty() else 0.0, lengths[lengths.size() - 1] if not lengths.is_empty() else 0.0, tot["timeouts"]])
	print("  per match: %.1f damage events, %.1f stage changes, %.1f breaks, %.1f decisive, %.1f finisher starts" % [float(tot["damage"]) / n, float(tot["region_stages"]) / n, float(tot["breaks"]) / n, float(tot["decisive"]) / n, float(tot["finishers"]) / n])
	print("  crown up (any fighter): %.1f%% of frames; a fighter on the brink: %.1f%% of fighter-frames; cinematic %.1f%%, hazard %.1f%%" % [100.0 * tot["crown_frames"] / tot["frames"], 100.0 * tot["brink_frames"] / (2.0 * tot["frames"]), 100.0 * tot["cin_frames"] / tot["frames"], 100.0 * tot["haz_frames"] / tot["frames"]])
	print("  caps: %d card-cap violations, %d bark-cap violations" % [tot["cap_viol"], tot["bark_viol"]])
	print("  test 9 proxy, every break gets its card: %d of %d shown (%d missed after 7 s); latency median %.2f s, p90 %.2f s, max %.2f s" % [tot["break_cards"], tot["breaks"], tot["breaks_missed"], latencies[latencies.size() / 2] if not latencies.is_empty() else 0.0, latencies[int(latencies.size() * 0.9)] if not latencies.is_empty() else 0.0, latencies[latencies.size() - 1] if not latencies.is_empty() else 0.0])
	print("  test 8 proxy, the fighter the HUD shows as more worn at the midpoint is the one who loses: %d of %d matches (%.0f%%)" % [tot["mid_right"], tot["mid_known"], 100.0 * float(tot["mid_right"]) / maxf(1.0, float(tot["mid_known"]))])
	var names: Array = types_seen.keys()
	names.sort()
	var parts: PackedStringArray = PackedStringArray()
	for k in names:
		if k in ["region_stage", "region_broken", "brink_enter", "brink_exit", "damage", "decisive", "finisher_start", "finisher_contest", "ko", "window_open", "parry", "chain_end", "lock_lost", "tier_up", "rally"]:
			parts.append("%s %d" % [k, types_seen[k]])
	print("  events over all matches: " + ", ".join(parts))
	quit()
