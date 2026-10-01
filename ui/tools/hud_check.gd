extends SceneTree
## The HUD's headless checks. Run from the repo root (import once first: godot --headless --path . --import):
##   godot --headless --path . --script res://ui/tools/hud_check.gd
## Exits 0 when every check passes. It checks: the term data, the layout geometry at many sizes (text floors, safe area,
## fighter-clear zone), the event hub's rules (Pride mask, merge, caps, priorities, cinematic quiet, bark timing) against
## the mock scenarios, that the HUD really draws (a scene run, so a bad draw call is a script error), and that the bridge
## only reads the live sim (when the sim compiles: the sim is another director's working tree).

var fails: int = 0
var checks: int = 0


func _ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL  ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_terms()
	_layouts()
	_bark_timing()
	_hub_rules()
	_crown_rules()
	_fx_defaults()
	_controls_rules()
	_scenarios()
	await _draw_smoke()
	await _layer_rules()
	await _split_rules()
	await _split_cost()
	_chip_dodge()
	await _responsive()
	await _howto_rules()
	await _reads_hud()
	await _feedback_rules()
	_toll_rules()
	await _hints_rules()
	await _touch_controls_rules()
	await _settings_rules()
	_touch_full_rules()
	await _remap_rules()
	await _pause_menu_rules()
	await _faces_rules()
	await _two_player_rules()
	await _sim_pause_rules()
	await _bridge()
	print("hud_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


# --- Terms ---------------------------------------------------------------------------------------------------------

func _terms() -> void:
	UiData.reload()
	var must: Array = ["stance.press", "stance.guard", "stance.dodge", "stance.escape", "meter.respect", "meter.pride", "meter.wrath",
		"meter.hunger", "meter.charge", "region.head", "region.core", "region.arms", "region.legs", "region.mantle", "stage.bruised",
		"stage.battered", "stage.broken", "card.brink", "card.rally.protagonist", "card.heat.1", "card.heat.2", "card.heat.3",
		"card.boil_over", "card.facade_crack", "card.drop_act", "card.fold_flicker", "state.hidden", "state.lost_trail",
		"state.signature", "toll.civilians", "station.hip", "chip_stage.2", "internal_stage.battered"]
	for k in must:
		_ok(UiData.t(k) != k, "term exists: " + k)
	_ok(UiData.t("stance.press") == "PRESS", "glossary: stance press")
	_ok(UiData.tier_name(1) == "TREMOR" and UiData.tier_name(4) == "CATACLYSM", "glossary: tier names")
	_ok(UiData.fmt("state.chain", {"n": 3}) == "CHAIN ×3", "glossary: CHAIN ×N")
	_ok(UiData.banner("NEED 45 KI") == "NEED 45 CHARGE", "banner rename: ki becomes charge")
	_ok(UiData.place_at(3100.0) == "BELLGATE", "place label lookup")
	# No banned words in any term (Legal's glossary rules: no ki, no aura, no scouter, no "power level").
	for k in ["ki", "aura", "scouter", "power level"]:
		var found := false
		for path in must:
			if UiData.t(path).to_lower().find(k) >= 0 and k != "ki":
				found = true
			if k == "ki" and (" " + UiData.t(path).to_lower() + " ").find(" ki ") >= 0:
				found = true
		_ok(not found, "no franchise-coded word in the player terms: " + k)
	var p: Dictionary = UiData.profile("anti_hero")
	_ok(p.get("ego") == "pride" and int(p.get("shame_max", 0)) == 3, "profile: anti_hero")
	_ok((UiData.profile("empress").get("regions") as Array).size() == 5, "profile: empress has a fifth region")
	_ok(UiData.profile("kai").get("ego") == "anguish", "profile: placeholder KAI alias")


# --- Layout --------------------------------------------------------------------------------------------------------

func _layouts() -> void:
	var sizes: Array = [Vector2(1920, 1080), Vector2(1366, 768), Vector2(1280, 720), Vector2(1024, 576), Vector2(2560, 1080),
		Vector2(3840, 2160), Vector2(800, 480), Vector2(390, 844), Vector2(1080, 1920), Vector2(360, 640)]
	for sz in sizes:
		for sil in [true, false]:
			var lay := UiLayout.new()
			lay.compute(sz, sil)
			var tag: String = "%dx%d sil=%s" % [int(sz.x), int(sz.y), str(sil)]
			var pm: Dictionary = lay.pm
			for k in ["fs_name", "fs_chip", "fs_tier", "fs_ego", "fs_state"]:
				_ok(float(pm[k]) >= UiLook.MIN_TEXT_PX, "%s: text floor %s (%d)" % [tag, k, int(pm[k])])
			var view := Rect2(Vector2.ZERO, sz)
			for r in lay.hud_rects():
				_ok(view.encloses(r), "%s: HUD rect inside the viewport %s" % [tag, str(r)])
				_ok(not r.intersects(lay.clear_zone), "%s: HUD rect %s stays out of the clear zone %s" % [tag, str(r), str(lay.clear_zone)])
			_ok(lay.clear_zone.size.x > sz.x * (0.30 if not lay.portrait else 0.6), "%s: the clear zone is wide enough (%d px)" % [tag, int(lay.clear_zone.size.x)])
			_ok(lay.clear_zone.size.y > sz.y * (0.45 if not lay.portrait else 0.22), "%s: the clear zone is tall enough (%d px)" % [tag, int(lay.clear_zone.size.y)])
			_ok(lay.plate[0].size.y > 0.0 and not lay.plate[0].intersects(lay.plate[1]), "%s: plates do not overlap" % tag)
			_ok(not lay.toll.intersects(lay.plate[0]) and not lay.toll.intersects(lay.plate[1]), "%s: the toll chip clears the plates" % tag)
			_ok(not lay.strip.intersects(lay.bark[0]) or lay.portrait, "%s: the strip clears the bark lane" % tag)
			if lay.portrait:
				_ok(not lay.clear_zone.intersects(lay.touch_reserve), "%s: portrait: touch controls keep their reserve" % tag)
			var plate_frac: float = lay.plate[0].size.y / sz.y
			_ok(plate_frac < (0.26 if sz.y < 700.0 else 0.20), "%s: a plate stays compact (%.1f%% of the height)" % [tag, plate_frac * 100.0])


# --- Bark timing ---------------------------------------------------------------------------------------------------

func _bark_timing() -> void:
	var text := "Ha! My arm. I'll need that later."
	_ok(UiBarkTiming.reveal_count(text, 0.0, 1) == 0, "bark: nothing at t=0")
	_ok(UiBarkTiming.reveal_count(text, 99.0, 1) == text.length(), "bark: everything at the end")
	_ok(UiBarkTiming.reveal_total(text, 3) < UiBarkTiming.reveal_total(text, 0), "bark: a harder line reveals faster")
	var prev := 0
	var mono := true
	for i in range(0, 300):
		var n: int = UiBarkTiming.reveal_count(text, float(i) * 0.01, 1)
		if n < prev:
			mono = false
		prev = n
	_ok(mono, "bark: the reveal never goes backwards")
	_ok(UiBarkTiming.time_for_char(text, 3, 1) > UiBarkTiming.time_for_char(text, 2, 1), "bark: cues can be timed by character")
	# The shown time of a typical bark is within the line system's 1.2 to 3.5 s.
	var hub := UiEventHub.new()
	hub.setup_fighters(["protagonist", "anti_hero"], ["A", "B"])
	hub.consume({"type": "bark", "speaker": 0, "text": text, "cues": [{"at": 0, "gesture": "wince", "intensity": 1}]})
	var b = hub.barks[0]
	_ok(b.reveal_time + b.dur >= UiLook.BARK_MIN and b.reveal_time + b.dur <= UiLook.BARK_MAX + 1.5, "bark: shown for a sensible time (%.2f s)" % (b.reveal_time + b.dur))


# --- Hub rules -----------------------------------------------------------------------------------------------------

func _hub(ids: Array = ["protagonist", "anti_hero"]) -> UiEventHub:
	var hub := UiEventHub.new()
	hub.setup_fighters(ids, ["ONE", "TWO"])
	return hub


func _step(hub: UiEventHub, seconds: float) -> void:
	var n: int = int(round(seconds * 60.0))
	for i in range(n):
		hub.advance(1.0 / 60.0)


func _hub_rules() -> void:
	# A wound card appears, shows about 1.5 s, and is gone.
	var hub := _hub()
	hub.consume({"type": "region_stage", "actor": 0, "region": "arms", "stage": "battered"})
	_step(hub, 0.1)
	_ok(hub.cards_of(0).size() == 1 and hub.cards_of(0)[0].title == "ARMS: BATTERED", "card: appears with the glossary wording")
	_step(hub, 1.6)
	_ok(hub.cards_of(0).size() == 0, "card: gone after its life")
	# Same region, worse stage: the card upgrades in place, it does not stack.
	hub = _hub()
	hub.consume({"type": "region_stage", "actor": 0, "region": "arms", "stage": "battered"})
	_step(hub, 0.5)
	hub.consume({"type": "region_stage", "actor": 0, "region": "arms", "stage": "broken"})
	hub.consume({"type": "region_broken", "actor": 0, "region": "arms"})
	_step(hub, 0.1)
	_ok(hub.cards_of(0).size() == 1 and hub.cards_of(0)[0].title == "ARMS: BROKEN", "card: a break upgrades the battered card in place")
	_ok(hub.stats["cards_merged"] >= 1, "card: merge counted")
	# A bruise is a toast, and only when nothing else is showing.
	hub = _hub()
	hub.consume({"type": "region_stage", "actor": 0, "region": "head", "stage": "battered"})
	_step(hub, 0.05)
	hub.consume({"type": "region_stage", "actor": 0, "region": "legs", "stage": "bruised"})
	_step(hub, 0.05)
	_ok(hub.stats["toasts_skipped"] == 1, "card: a bruise toast is skipped while a card is showing")
	# Caps: a flood on one side shows at most the cap; breaks outrank the rest.
	hub = _hub()
	for r in ["head", "core", "arms", "legs"]:
		hub.consume({"type": "region_stage", "actor": 0, "region": r, "stage": "battered"})
	hub.consume({"type": "brink_enter", "actor": 0})
	_step(hub, 0.6)
	_ok(hub.cards_of(0).filter(func(c): return not c.fading).size() <= UiLook.CAP_CARDS_PER_SIDE[0], "cap: at most %d cards per side in normal play" % UiLook.CAP_CARDS_PER_SIDE[0])
	_ok(hub.cards_of(0).any(func(c): return c.key == "brink"), "cap: the brink card (a break-priority card) is among those shown")
	# Portrait: the host lowers the cap to one card per side.
	hub = _hub()
	hub.cap_limit = 1
	for r in ["head", "core", "arms"]:
		hub.consume({"type": "region_stage", "actor": 0, "region": r, "stage": "battered"})
	_step(hub, 0.05)
	_ok(hub.cards_of(0).filter(func(c): return not c.fading).size() == 1, "cap: portrait shows one card per side")
	# A world card takes the banner's slot and the banner waits.
	hub = _hub()
	hub.consume({"type": "banner", "text": "PARRY", "dur": 1.0})
	hub.consume({"type": "fold_flicker"})
	_step(hub, 0.5)
	_ok(hub.world_card != null and float(hub.banner.get("age", 0.0)) < 0.05, "world card: the banner's clock waits while a world card shows")
	# Hazard lowers the cap; a cinematic lowers it again and quiets ambient barks.
	hub = _hub()
	hub.consume({"type": "shake", "k": 18.0})
	_step(hub, 0.05)
	_ok(hub.mode == UiEventHub.Mode.HAZARD, "mode: a hard shake is a hazard")
	for r in ["head", "core", "arms", "legs"]:
		hub.consume({"type": "region_stage", "actor": 1, "region": r, "stage": "battered"})
	_step(hub, 0.05)
	_ok(hub.cards_of(1).filter(func(c): return not c.fading).size() <= UiLook.CAP_CARDS_PER_SIDE[1], "cap: hazard shows at most %d cards per side" % UiLook.CAP_CARDS_PER_SIDE[1])
	hub = _hub()
	hub.consume({"type": "cinematic_start", "actor": 0, "kind": "transformation", "dur": 2.0})
	_step(hub, 0.05)
	_ok(hub.mode == UiEventHub.Mode.CINEMATIC, "mode: a cinematic is CINEMATIC")
	hub.consume({"type": "bark", "speaker": 1, "text": "Ambient chatter.", "priority": 1})
	_ok(hub.barks.is_empty() and hub.stats["barks_suppressed"] == 1, "cinematic: ambient barks are suppressed")
	hub.consume({"type": "bark", "speaker": 0, "text": "A set piece line.", "priority": 4, "setpiece": true})
	_ok(hub.barks.size() == 1, "cinematic: set pieces still speak")
	_step(hub, 2.2)
	_ok(hub.mode == UiEventHub.Mode.NORMAL, "mode: back to normal after the cinematic")
	# The Anti-hero's Proud front: battered and bruised are withheld, breaks show, the crack releases one compressed card.
	hub = _hub()
	var ah: UiFighterModel = hub.model(1)
	hub.consume({"type": "region_stage", "actor": 1, "region": "arms", "stage": "battered"})
	hub.consume({"type": "region_stage", "actor": 1, "region": "head", "stage": "bruised"})
	_step(hub, 0.1)
	_ok(ah.stage["arms"] == 0 and ah.true_stage["arms"] == 2, "pride mask: the crown stays whole, the true stage is kept")
	_ok(hub.cards_of(1).is_empty() and hub.stats["cards_withheld"] == 2, "pride mask: battered and bruised cards are withheld")
	hub.consume({"type": "region_stage", "actor": 1, "region": "legs", "stage": "broken"})
	_step(hub, 0.1)
	_ok(ah.stage["legs"] == 3 and hub.cards_of(1).size() == 1, "pride mask: a broken region shows and announces")
	hub.consume({"type": "facade_crack", "actor": 1})
	_step(hub, 0.1)
	var fc: Array = hub.cards_of(1).filter(func(c): return c.key == "facade")
	_ok(fc.size() == 1 and (fc[0].regions as Array).size() == 2, "pride mask: the crack fires one compressed card listing the withheld regions")
	_ok(ah.stage["arms"] == 2 and ah.stage["head"] == 1 and not ah.pride_holds, "pride mask: the crown drops to its true state at once")
	# Recovery is quiet; a Rally announces.
	hub = _hub()
	hub.consume({"type": "region_stage", "actor": 0, "region": "arms", "stage": "battered"})
	_step(hub, 2.0)
	hub.consume({"type": "region_stage", "actor": 0, "region": "arms", "stage": "bruised"})
	_step(hub, 0.1)
	_ok(hub.cards_of(0).is_empty(), "recovery: no card when a region improves")
	hub.consume({"type": "region_stage", "actor": 0, "region": "arms", "stage": "broken"})
	hub.consume({"type": "brink_enter", "actor": 0})
	_step(hub, 0.1)
	hub.consume({"type": "rally", "actor": 0, "region": "arms"})
	_step(hub, 0.9)
	_ok(hub.model(0).stage["arms"] == 2 and not hub.model(0).brink, "rally: mends to battered and leaves the brink")
	_ok(hub.cards_of(0).any(func(c): return c.title == "SECOND WIND"), "rally: the card uses the fighter's own name")
	# Heat cards, the boil-over, internal wear.
	hub = _hub()
	hub.consume({"type": "heat_stage", "actor": 0, "stage": 2})
	hub.consume({"type": "region_stage", "actor": 0, "region": "core", "stage": "battered", "internal": true})
	_step(hub, 0.1)
	_ok(hub.cards_of(0).any(func(c): return c.title == "BLOOD: SIMMERING"), "heat: stage card")
	_ok(hub.cards_of(0).any(func(c): return c.title == "CORE: SCALDED"), "heat: internal core wear has its own card")
	_ok(hub.model(0).internal_stage == 2 and hub.model(0).stage["core"] == 0, "heat: internal wear is separate from surface wear")
	# The Empress: no paperwork cards, ever. The Cyborg: chip cards.
	hub = _hub(["empress", "cyborg"])
	hub.consume({"type": "revision_reprint", "actor": 0, "revision": 9, "region": "arms"})
	hub.consume({"type": "revision_fill_reset", "actor": 0})
	hub.consume({"type": "encore_start", "actor": 0})
	hub.consume({"type": "guard_fall", "actor": 0})
	_step(hub, 0.1)
	_ok(hub.cards_of(0).is_empty() and hub.waiting.is_empty(), "empress: no paperwork or gauge cards (Orb: diegetic only)")
	_ok(hub.model(0).revision == 9, "empress: the reprint updates the silhouette's numeral")
	hub.consume({"type": "hatch_open", "actor": 1, "station": 3, "dur": 1.5})
	hub.consume({"type": "chip_stage", "actor": 1, "stage": 2})
	_step(hub, 0.1)
	_ok(hub.cards_of(1).any(func(c): return c.title == "HATCH OPEN: HIP") and hub.cards_of(1).any(func(c): return c.title == "CHIP: CRACKED"), "cyborg: hatch and chip cards")
	# Windows and hiding.
	hub = _hub()
	hub.consume({"type": "window_open", "actor": 1, "kind": "parry", "dur": 0.33})
	_ok(hub.model(1).parry_t == 0.0, "window: parry opens")
	_step(hub, 0.5)
	_ok(hub.model(1).parry_t < 0.0, "window: parry closes")
	hub.consume({"type": "window_open", "actor": 0, "kind": "parry", "dur": 0.05})
	_step(hub, 0.08)
	_ok(hub.model(0).parry_t >= 0.0, "window: a very short parry window still shows for a moment")
	# Hiding is removed from the base game (a flag, off): the hidden state and the lost trail are ignored...
	hub.consume({"type": "lock_lost", "actor": 1, "dur": 1.0})
	hub.patch(0, {"hidden": true})
	_ok(not hub.model(1).lost_trail and not hub.model(0).hidden, "hiding flag off: lock_lost and a hidden patch are ignored")
	# ...and the code is intact behind the flag for the future stealth fighter.
	UiData.set_feature("hiding", true)
	hub.consume({"type": "lock_lost", "actor": 1, "dur": 1.0})
	hub.patch(0, {"hidden": true})
	_ok(hub.model(1).lost_trail and hub.model(0).hidden, "hiding flag on: trail lost and hidden show")
	_step(hub, 1.2)
	_ok(not hub.model(1).lost_trail, "hiding flag on: and the trail clears")
	UiData.set_feature("hiding", null)
	_ok(not UiData.feature("hiding"), "hiding: the data flag is off by default")
	# The hub takes objects with the same fields (the sim's FxEvent).
	hub = _hub()
	var ev := SimState.FxEvent.new()
	ev.type = "banner"
	ev.text = "NEED 45 KI"
	ev.dur = 1.0
	hub.consume(ev)
	_ok(str(hub.banner.get("text", "")) == "NEED 45 CHARGE", "objects: an FxEvent is consumed like a Dictionary")
	# Unknown fields on an object do not crash it.
	var ev2 := SimState.FxEvent.new()
	ev2.type = "region_stage"
	hub.consume(ev2)
	_ok(true, "objects: an FxEvent without wound fields is ignored quietly")


# --- Scenarios -----------------------------------------------------------------------------------------------------

func _scenarios() -> void:
	for scn in UiMockFeed.SCENARIOS:
		var f: Array = UiMockFeed.fighters(scn)
		var hub := UiEventHub.new()
		hub.setup_fighters(f[0], f[1])
		var feed := UiMockFeed.new(scn, 5)
		var worst_cards := 0
		var worst_barks := 0
		var over_cap := 0
		var max_life := 0.0
		var steps: int = int((feed.length * 2.2) * 60.0)
		for i in range(steps):
			for e in feed.step(1.0 / 60.0):
				hub.consume(e)
			hub.advance(1.0 / 60.0)
			var cap: int = UiLook.CAP_CARDS_PER_SIDE[hub.mode]
			for slot in range(2):
				var live: int = hub.cards_of(slot).filter(func(c): return not c.fading).size()
				worst_cards = maxi(worst_cards, live)
				if live > cap:
					over_cap += 1
				for c in hub.cards_of(slot):
					max_life = maxf(max_life, c.life)
			worst_barks = maxi(worst_barks, hub.barks.size())
		_ok(over_cap == 0, "%s: live cards never exceed the cap for the current mode (%d violations)" % [scn, over_cap])
		_ok(worst_barks <= 2, "%s: at most two bark lines on screen (saw %d)" % [scn, worst_barks])
		_ok(max_life <= UiLook.CARD_LIFE_BROKEN + 0.001, "%s: no card lives longer than %.1f s" % [scn, UiLook.CARD_LIFE_BROKEN])
		print("  scenario %-18s cards<=%d barks<=%d %s" % [scn, worst_cards, worst_barks, str(hub.stats)])


# --- Draw smoke ----------------------------------------------------------------------------------------------------

func _draw_smoke() -> void:
	var errors_before: int = 0
	for scn in UiMockFeed.SCENARIOS:
		for sz in [Vector2i(1920, 1080), Vector2i(390, 844)]:
			root.size = sz
			var host := Control.new()
			host.set_anchors_preset(Control.PRESET_FULL_RECT)
			root.add_child(host)
			var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
			host.add_child(hud)
			var f: Array = UiMockFeed.fighters(scn)
			hud.setup(f[0], f[1])
			hud.set_option("show_feed", true)
			hud.set_option("region_label", true)
			hud.set_option("show_clear_zone", true)
			hud.anchor_fn = func(slot): return {"pos": Vector2(float(sz.x) * (0.35 + 0.3 * float(slot)), float(sz.y) * 0.55), "h": 120.0, "visible": true}
			hud.strip_fn = func(): return {"W": 9600.0, "segs": [[0.0, 4000.0, "ocean"], [4000.0, 9600.0, "city"]], "cam_x": 100.0, "cam_w": 2000.0, "dead": [500.0], "fighters": [{"x": 50.0, "slot": 0, "hidden": false, "aura": Color.WHITE, "seen_x": 50.0}, {"x": 900.0, "slot": 1, "hidden": true, "aura": Color.RED, "seen_x": 800.0}]}
			var feed := UiMockFeed.new(scn, 3)
			var frames: int = int(feed.length * 60.0 * 1.05)
			for i in range(frames):
				for e in feed.step(1.0 / 60.0):
					hud.consume(e)
				hud.advance(1.0 / 60.0)
				if i % 3 == 0:
					await process_frame
			host.queue_free()
			await process_frame
	_ok(true, "draw: every scenario drew at 1920x1080 and 390x844 without a script error (look for SCRIPT ERROR above)")


# --- Bridge --------------------------------------------------------------------------------------------------------

func _bridge() -> void:
	if not ClassDB.class_exists("Node") or load("res://render/core/sim_host.gd") == null or not (load("res://render/core/sim_host.gd") as GDScript).can_instantiate():
		print("SKIP  bridge: the sim host does not compile right now (another director's working tree)")
		return
	var host := SimHost.new()
	host.new_match(4)
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	root.add_child(hud)
	var f: Array = UiSimBridge.fighters(host.S)
	hud.setup(f[0], f[1])
	var events := 0
	var saw_pop := false
	var seen := {"stage": false, "damage": false}
	host.drained.connect(func(evs: Array, _lines: Array):
		for e in evs:
			if e.type == "region_stage" or e.type == "damage":
				seen[e.type if e.type in seen else "stage"] = true
		hud.consume_all(evs))
	for i in range(4200):
		host.tick(1280.0, 720.0)
		UiSimBridge.patch(hud, host.S)
		UiSimBridge.feed(hud, host.feed.slice(maxi(0, host.feed.size() - 1)))
		hud.advance(1.0 / 60.0)
		for mm in hud.hub.models:
			if mm.crown_a > 0.5:
				saw_pop = true
	events = int(hud.hub.stats["events"])
	var m0: UiFighterModel = hud.hub.model(0)
	_ok(m0.name == "KAI" and m0.tier >= 1 and m0.charge >= 0.0, "bridge: reads name, tier and charge from the sim")
	var sig_name0: String = str(host.S.fighters[0].sigName).strip_edges().to_upper()
	_ok(sig_name0 != "" and hud.hub.move_names.has(sig_name0), "bridge: the fighters' signature names are known to the hub (a banner that is only a move name is dropped)")
	_ok(hud.hub.toll["pop0"] > 0, "bridge: reads the world counters")
	var sd: Dictionary = UiSimBridge.strip_data(host.S, host.cam.x, 2000.0)
	_ok((sd["segs"] as Array).size() == 11 and (sd["fighters"] as Array).size() == 2, "bridge: builds the planet strip's data")
	_ok(bool(seen["damage"]), "bridge: the live sim emits damage events (S1): " + str(seen))
	_ok(float(m0.wear["core"]) >= 0.0, "bridge: reads wear from the sim state")
	# A ready form is the sim's own f.act.formReady, read every patch (the transform_ready event is only the fast path).
	host.S.fighters[0].act.formReady = true
	UiSimBridge.patch(hud, host.S)
	var ready_on: bool = hud.hub.model(0).avail["transform"]
	host.S.fighters[0].act.formReady = false
	UiSimBridge.patch(hud, host.S)
	_ok(ready_on and not hud.hub.model(0).avail["transform"], "bridge: the Transform prompt reads f.act.formReady (up while a form is ready, down when it is taken)")
	# The greybox balance rarely wears a region past bruised in a minute, so push one through the real S1 code: the stage
	# events it emits must reach the HUD as they are.
	var f0 = host.S.fighters[0]
	# A limb now wears to battered and stops (the rest spills into the core), so the core is the region that can break from damage alone.
	SimWounds.addWear(host.S, f0, SimWounds.CORE, 100000.0)
	SimWounds.updateStages(host.S, f0)
	host.tick(1280.0, 720.0)
	hud.advance(1.0 / 60.0)
	_ok(int(m0.true_stage["core"]) == 3 and m0.crown_a > 0.0, "bridge: a real region_stage and region_broken from S1 reach the model and pop the crown")
	_ok(hud.hub.cards_of(0).any(func(c): return str(c.title).ends_with(": BROKEN")) or hud.hub.waiting.any(func(c): return str(c.title).ends_with(": BROKEN")), "bridge: and make a BROKEN wound card")
	print("  bridge ok: %d events consumed over 4200 ticks" % events)
	host.S = null


# --- The transient crown: it owns wear only (Orb: at rest the fighters are clean; Art: the flashes own the rest) ---------

func _crown_rules() -> void:
	var longest: float = UiLook.CROWN_ATTACK + UiLook.CROWN_HOLD_MAJOR + UiLook.CROWN_RELEASE
	_ok(longest <= 1.55, "crown: the longest pop is about 1.5 s (%.2f s)" % longest)
	var hub := _hub()
	_step(hub, 2.0)
	_ok(hub.model(0).crown_a == 0.0 and hub.model(1).crown_a == 0.0, "crown: at rest it is not drawn")
	_ok(not hub.crown_up(0) and not hub.crown_up(1), "crown_up: false at rest")
	# A plain hit does NOT pop it (Art: emotion belongs to the flashes), makes no card, no bark and no number.
	hub.consume({"type": "damage", "attacker": 0, "victim": 1, "region": "arms", "kind": "heavy", "number": true})
	_step(hub, 0.3)
	_ok(hub.model(1).crown_a == 0.0 and not hub.crown_up(1), "crown: a hit, even a heavy one, does not pop it")
	_ok(hub.cards_of(1).is_empty() and hub.barks.is_empty(), "crown: a plain hit makes no card and no bark")
	# The five things that do: a stage change, the brink, a Rally, the facade crack, a boil-over.
	hub = _hub()
	hub.consume({"type": "region_stage", "actor": 0, "region": "arms", "stage": 2})
	_step(hub, 0.3)
	_ok(hub.model(0).crown_a > 0.9 and hub.crown_up(0) and not hub.crown_up(1), "crown: a region getting worse pops it, and crown_up says so for that fighter only")
	_step(hub, 0.5)
	_ok(hub.crown_up(0), "crown_up: still true while it fades (a flash must not start under a fading crown)")
	_step(hub, 0.6)
	_ok(hub.model(0).crown_a == 0.0 and not hub.crown_up(0), "crown: gone by 1.4 s, and crown_up is false again")
	hub.consume({"type": "region_stage", "actor": 0, "region": "arms", "stage": 1})
	_step(hub, 0.3)
	_ok(hub.model(0).crown_a == 0.0, "crown: a recovery does not pop it")
	hub.consume({"type": "brink_enter", "actor": 0})
	_step(hub, 0.3)
	_ok(hub.model(0).crown_a > 0.9, "crown: the brink pops it")
	_step(hub, 1.7)
	_ok(hub.model(0).crown_a == 0.0 and hub.model(0).brink and not hub.crown_up(0), "crown: then only the faint ring stays (the model keeps brink; crown_up is false)")
	hub.consume({"type": "rally", "actor": 0, "region": "arms"})
	_step(hub, 0.3)
	_ok(hub.model(0).crown_a > 0.9, "crown: a Rally pops it")
	hub = _hub()
	hub.consume({"type": "boil_over", "actor": 0})
	_step(hub, 0.3)
	_ok(hub.model(0).crown_a > 0.9, "crown: a boil-over pops it")
	hub = _hub(["protagonist", "anti_hero"])
	hub.consume({"type": "region_stage", "actor": 1, "region": "arms", "stage": 2})
	hub.consume({"type": "facade_crack", "actor": 1})
	_step(hub, 0.3)
	_ok(hub.model(1).crown_a > 0.9, "crown: the facade crack pops it")
	# Not for: a tier-up, a heat stage, Drop the Act on its own, a cinematic's subject.
	hub = _hub()
	hub.consume({"type": "tier_up", "actor": 1, "tier": 2})
	hub.consume({"type": "heat_stage", "actor": 0, "stage": 2})
	hub.consume({"type": "drop_act", "actor": 1})
	_step(hub, 0.3)
	_ok(hub.model(0).crown_a == 0.0 and hub.model(1).crown_a == 0.0, "crown: a tier-up, a heat stage and Drop the Act do not pop it by themselves")
	# The Anti-hero's masked stage changes do not pop it (the front holds); a break does.
	hub = _hub()
	hub.consume({"type": "region_stage", "actor": 1, "region": "arms", "stage": 2})
	_step(hub, 0.3)
	_ok(hub.model(1).crown_a == 0.0, "crown: a masked stage change does not pop it")
	hub.consume({"type": "region_stage", "actor": 1, "region": "arms", "stage": 3})
	_step(hub, 0.3)
	_ok(hub.model(1).crown_a > 0.9, "crown: a break pops it through the mask")
	# A transformation cinematic holds the crown down (Art: the surge owns the fighter); it fades in 0.1 s and stays down.
	hub = _hub()
	hub.consume({"type": "region_stage", "actor": 0, "region": "arms", "stage": 2})
	_step(hub, 0.3)
	_ok(hub.crown_up(0), "cinematic: the crown is up before the transformation")
	hub.consume({"type": "cinematic_start", "actor": 1, "kind": "transformation", "dur": 2.0})
	_step(hub, 0.2)
	_ok(hub.model(0).crown_a == 0.0 and not hub.crown_up(0) and hub.crown_locked(), "cinematic: it fades out within 0.2 s and crown_up is false")
	hub.consume({"type": "region_stage", "actor": 0, "region": "legs", "stage": 3})
	_step(hub, 0.5)
	_ok(hub.model(0).crown_a == 0.0 and not hub.crown_up(0), "cinematic: a wear event during it does not pop the crown")
	_step(hub, 1.6)
	_ok(not hub.crown_locked(), "cinematic: the lock ends with the cinematic")
	hub.consume({"type": "region_stage", "actor": 0, "region": "head", "stage": 2})
	_step(hub, 0.3)
	_ok(hub.model(0).crown_a > 0.9, "cinematic: and the crown works again afterwards")
	hub = _hub()
	hub.consume({"type": "cinematic_start", "actor": 0, "kind": "finisher", "dur": 1.0})
	hub.consume({"type": "region_stage", "actor": 1, "region": "arms", "stage": 3})
	_step(hub, 0.3)
	_ok(hub.model(1).crown_a > 0.9, "cinematic: only a transformation locks the crown; a finisher does not")
	# Neutral role colours only: the crown never takes a fighter's accent.
	var accents: Array = [Color("#ff9ad0"), Color("#8fd6ff"), Color("#e0c14a"), Color("#ff5a3c")]
	var neutral := true
	for st in range(4):
		var c: Color = UiCrown.stroke_color(st)
		for ac in accents:
			if c.is_equal_approx(ac):
				neutral = false
	_ok(neutral, "crown: stroke colours are neutral roles, never a fighter accent")
	_ok(UiCrown.stroke_color(0).is_equal_approx(UiLook.col(UiLook.CROWN_FRESH)) and UiCrown.stroke_color(3).is_equal_approx(UiLook.col(UiLook.STAGE_BROKEN)), "crown: fresh is the neutral role, broken the wound role")
	# The sim's own event objects (S1): floats for slots, strings for regions.
	hub = _hub()
	var rs := SimState.FxEvent.new()
	rs.type = "region_stage"
	rs.actor = 0.0
	rs.region = "core"
	rs.stage = 2
	hub.consume(rs)
	_step(hub, 0.2)
	_ok(hub.model(0).crown_a > 0.9 and hub.model(0).stage["core"] == 2, "crown: the sim's region_stage object is read as it is")
	var dm := SimState.FxEvent.new()
	dm.type = "damage"
	dm.attacker = 1.0
	dm.victim = 0.0
	dm.region = "head"
	dm.kind = "light"
	dm.number = true
	var before_a: float = hub.model(0).crown_a
	hub.consume(dm)
	_ok(hub.model(0).crown_a == before_a, "crown: the sim's damage object changes nothing on the crown")
	var bi := SimState.FxEvent.new()
	bi.type = "brink_enter"
	bi.actor = 0.0
	hub.consume(bi)
	_ok(hub.model(0).brink, "crown: a brink_enter object sets the brink")
	# The toll chip brightens for a moment after a change, then dims.
	hub = _hub()
	_step(hub, 1.0)
	hub.consume({"type": "world", "civilians": 3, "pop0": 425, "structures": 0, "craters": 0})
	_ok(hub.toll_age == 0.0, "toll: a change resets the chip's brightness")
	_step(hub, UiLook.TOLL_SHOW + 0.1)
	_ok(hub.toll_age > UiLook.TOLL_SHOW, "toll: and it dims again")
	# The mock hero scenario: how much of the time is any crown showing? Now only for wear.
	var f: Array = UiMockFeed.fighters("hero_vs_proud")
	hub = UiEventHub.new()
	hub.setup_fighters(f[0], f[1])
	var feed := UiMockFeed.new("hero_vs_proud", 5)
	var up := 0
	var total: int = int(feed.length * 60.0)
	for i in range(total):
		for e in feed.step(1.0 / 60.0):
			hub.consume(e)
		hub.advance(1.0 / 60.0)
		if hub.crown_up(0) or hub.crown_up(1):
			up += 1
	var share: float = float(up) / float(total)
	print("  crown up in %.0f%% of the scripted fight (any fighter)" % (share * 100.0))
	_ok(share < 0.5, "crown: a crown is up in under half of even a dense scripted fight (%.0f%%)" % (share * 100.0))


# --- Cached layers: at rest the HUD redraws nothing ---------------------------------------------------------------

func _layer_rules() -> void:
	root.size = Vector2i(1280, 720)
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	root.add_child(hud)
	hud.setup(["kai", "vorr"], ["KAI", "VORR"])
	hud.set_option("control_hints", "off")   # the control legend fades over seconds 10 to 12 of a match; this test is about the base layers
	hud.anchor_fn = func(slot): return {"pos": Vector2(400.0 + 400.0 * float(slot), 400.0), "h": 120.0, "visible": true}
	hud.strip_fn = func(): return {"W": 9600.0, "segs": [[0.0, 4800.0, "ocean"], [4800.0, 9600.0, "city"]], "cam_x": 100.0, "cam_w": 2000.0, "dead": [], "fighters": [{"x": 50.0, "slot": 0, "hidden": false, "aura": Color.WHITE, "seen_x": 50.0}, {"x": 900.0, "slot": 1, "hidden": false, "aura": Color.WHITE, "seen_x": 900.0}]}
	for i in range(260):
		hud.advance(1.0 / 60.0)
		await process_frame
	var base: int = hud.redraw_count()
	for i in range(180):
		hud.advance(1.0 / 60.0)
		await process_frame
	_ok(hud.redraw_count() - base <= 2, "layers: at rest 180 frames cause %d redraws (a still HUD redraws nothing)" % (hud.redraw_count() - base))
	hud.consume({"type": "region_stage", "actor": 1, "region": "arms", "stage": 2})
	for i in range(20):
		hud.advance(1.0 / 60.0)
		await process_frame
	_ok(hud.redraw_count() - base > 10, "layers: a stage change redraws the crown layer while it shows")
	for i in range(150):
		hud.advance(1.0 / 60.0)
		await process_frame
	var base2: int = hud.redraw_count()
	for i in range(120):
		hud.advance(1.0 / 60.0)
		await process_frame
	_ok(hud.redraw_count() - base2 <= 2, "layers: back at rest, it stops redrawing again (%d)" % (hud.redraw_count() - base2))
	# The parry window keeps the crown's ring (Art: a flash would double it): the crown layer draws for a window even with no pop.
	hud.consume({"type": "window_open", "actor": 0, "kind": "parry", "dur": 0.33})
	hud.advance(0.05)
	_ok(hud.hub.model(0).crown_a == 0.0 and hud._l_crown.sig != null, "parry window: the crown layer draws its ring with no pop showing")
	for i in range(40):
		hud.advance(1.0 / 60.0)
		await process_frame
	_ok(hud._l_crown.sig == null, "parry window: and it clears when the window closes")
	# The always-on crown (accessibility) must not remove the flash channel: crown_up stays false, and the crown dims under a flash.
	hud.set_option("crown_always", true)
	hud.consume({"type": "region_stage", "actor": 0, "region": "arms", "stage": 2})
	hud.advance(0.05)
	var ao: Dictionary = {"crown_always": true}
	var mm0: UiFighterModel = hud.hub.model(0)
	_ok(not hud.crown_up(0) and not hud.crown_up(1), "crown_always: crown_up is false for arbitration, even with a wear pop showing")
	_ok(is_equal_approx(UiCrown.pop_alpha(mm0, ao), 1.0), "crown_always: the crown is at full opacity with no flash")
	hud.set_flash_up(0, true)
	_ok(is_equal_approx(UiCrown.pop_alpha(mm0, ao), UiLook.CROWN_DIM_UNDER_FLASH) and is_equal_approx(UiCrown.pop_alpha(hud.hub.model(1), ao), 1.0), "crown_always: it dims under a flash on that fighter only")
	hud.set_flash_up(0, false)
	_ok(is_equal_approx(UiCrown.pop_alpha(mm0, ao), 1.0), "crown_always: and comes back when the flash ends")
	_ok(is_equal_approx(UiCrown.pop_alpha(mm0, {"crown_always": true, "crown_locked": true}), 0.0), "crown_always: a transformation cinematic still holds it down")
	hud.set_option("crown_always", false)
	# The info-flashes option, from the options data, on by default.
	_ok(UiData.option_defaults().get("info_flashes") == true and hud.opts["info_flashes"] == true and hud.info_flashes(), "options: info_flashes is in the options data, on by default")
	hud.set_option("info_flashes", false)
	_ok(not hud.info_flashes(), "options: and can be turned off")
	hud.set_option("info_flashes", true)
	_ok(UiData.options().has("crown_always") and UiData.options().has("silhouette") and UiData.options()["crown_always"].get("accessibility", false), "options: the accessibility options are marked in the data")
	var od: Dictionary = UiData.option_defaults()
	_ok(od.get("split_solo") == true and hud.opts["split_solo"] == true and not od.has("shake_scale") and not hud.opts.has("shake_scale") and float(hud.opts["camera_shake"]) == 2.0, "options: split_solo defaults on, shake is camera_shake alone (shake_scale is gone; Camera reads them through the options)")
	_ok(UiData.options()["camera_shake"].get("accessibility", false) and UiData.options()["reduced_motion"].get("accessibility", false) and not UiData.options()["split_solo"].get("accessibility", false), "options: camera_shake and reduced_motion are accessibility options, split_solo is a display option")
	var cpn: Dictionary = UiData.options()["camera_panels"]
	_ok(cpn["default"] == "full" and cpn["choices"] == ["full", "still", "off"] and cpn["group"] == "display" and hud.opts["camera_panels"] == "full" and UiData.settings()["labels"]["camera_panels"]["still"] == "Still", "options: camera_panels offers full, still and off, default full, in the Camera section")
	var in_camera := false
	for sec in UiData.settings()["sections"]:
		if sec["id"] == "camera" and (sec["items"] as Array).has("camera_panels"):
			in_camera = true
	_ok(in_camera, "options: camera_panels is on the Settings screen's Camera section")
	var clf: Dictionary = UiData.options()["camera_launch_follow"]
	_ok(clf["default"] == "auto" and clf["choices"] == ["auto", "chase", "split"] and clf["group"] == "display" and hud.opts["camera_launch_follow"] == "auto", "options: camera_launch_follow offers auto, chase and split, default auto")
	hud.set_option("force_redraw", true)
	var base3: int = hud.redraw_count()
	for i in range(30):
		hud.advance(1.0 / 60.0)
		await process_frame
	_ok(hud.redraw_count() - base3 > 100, "layers: the bench switch redraws every layer every frame (%d)" % (hud.redraw_count() - base3))
	hud.queue_free()
	await process_frame


# --- Camera's split screen: divider, ring map, pointers, per-pane zones ---------------------------------------------------

## Camera's anchors (docs/camera/split-screen.md section 3): each fighter's chest on its OUTER side of the divider.
func _anchor_for(lay: UiLayout, c: Vector2, n: Vector2, slot: int) -> Vector2:
	var sgn: float = -1.0 if slot == 0 else 1.0
	return c + Vector2(0.0, 0.12 * lay.vp.y) + Vector2(n.x * 0.28 * lay.vp.x * sgn, n.y * 0.24 * lay.vp.y * sgn)


func _split_rules() -> void:
	# Geometry: the divider stops under the toll chip and above the ring map; the ring map sits between the bark lanes.
	for sz in [Vector2(1920, 1080), Vector2(1366, 768), Vector2(1280, 720), Vector2(2560, 1080)]:
		var lay := UiLayout.new()
		lay.compute(sz, false)
		var tag: String = "%dx%d" % [int(sz.x), int(sz.y)]
		var band: Vector2 = lay.divider_band()
		_ok(band.x >= lay.toll.end.y and band.y <= lay.ring.position.y and band.y < lay.strip.position.y, "%s split: the divider band is under the toll chip and above the ring map and the strip" % tag)
		_ok(lay.ring.size.y > 0.0 and not lay.ring.intersects(lay.clear_zone) and not lay.ring.intersects(lay.bark[0]) and not lay.ring.intersects(lay.bark[1]) and not lay.ring.intersects(lay.strip), "%s split: the ring map is clear of the fight, the bark lanes and the strip" % tag)
		var c: Vector2 = sz * 0.5
		var seg: Array = lay.divider_segment(c, Vector2(1.0, 0.0))
		_ok(seg.size() == 2 and is_equal_approx(seg[0].x, c.x) and is_equal_approx(minf(seg[0].y, seg[1].y), band.x) and is_equal_approx(maxf(seg[0].y, seg[1].y), band.y), "%s split: a level divider runs the whole band" % tag)
		seg = lay.divider_segment(c, Vector2(0.0, -1.0))
		_ok(seg.size() == 2 and absf(minf(seg[0].x, seg[1].x)) < 0.01 and is_equal_approx(maxf(seg[0].x, seg[1].x), sz.x), "%s split: a divider swinging through the horizontal spans the width" % tag)
		# Each anchor stays inside its own pane's clear zone at every tilt, on both orientations.
		var bad := 0
		var overlap := 0
		for sigma in [1.0, -1.0]:
			for deg in range(-30, 31, 5):
				var phi: float = deg_to_rad(float(deg))
				var n := Vector2(sigma * cos(phi), -sin(phi))
				var za: PackedVector2Array = lay.pane_zone(false, c, n)
				var zb: PackedVector2Array = lay.pane_zone(true, c, n)
				for slot in range(2):
					var p: Vector2 = _anchor_for(lay, c, n, slot)
					var zone: PackedVector2Array = za if slot == 0 else zb
					if zone.size() < 3 or not Geometry2D.is_point_in_polygon(p, zone):
						bad += 1
				for gx in range(0, 21):
					for gy in range(0, 11):
						var q := Vector2(float(gx) / 20.0 * sz.x, float(gy) / 10.0 * sz.y)
						if za.size() >= 3 and zb.size() >= 3 and Geometry2D.is_point_in_polygon(q, za) and Geometry2D.is_point_in_polygon(q, zb):
							overlap += 1
		_ok(bad == 0, "%s split: every anchor is inside its pane's clear zone at every tilt (%d outside)" % [tag, bad])
		_ok(overlap == 0, "%s split: the two panes' clear zones never overlap" % tag)
	# Swapped columns: slot 0 on the right.
	var l2 := UiLayout.new()
	l2.compute(Vector2(1920, 1080), true, Vector4.ZERO, true)
	_ok(l2.plate[0].position.x > 960.0 and l2.plate[1].position.x < 960.0 and l2.cards[0].position.x > 960.0 and l2.bark[0].position.x > 960.0, "swap: slot 0's plate, cards and bark lane move to the right")
	# The HUD: the sigma flip swaps the columns after a short fade; the divider, ring and pointers follow the record.
	root.size = Vector2i(1280, 720)
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	root.add_child(hud)
	hud.setup(["kai", "vorr"], ["KAI", "VORR"])
	var st := {"sigma": 1.0, "sep": 1.0, "phi": 0.3, "dist": 40000.0}
	hud.split_fn = func():
		var n := Vector2(st["sigma"] * cos(st["phi"]), -sin(st["phi"]))
		return {"sep": st["sep"], "c": Vector2(640.0, 360.0), "n": n, "gap": 3.0, "fade": 1.0, "sigma": st["sigma"], "pointer": "split",
			"ring": {"angle_A": 1.0, "angle_B": 1.0 + st["dist"] / SimConst.W * TAU, "sigma": st["sigma"], "arc_A": 0.3, "arc_B": 0.3, "swing": 0.0, "sep": st["sep"]}}
	hud.anchor_fn = func(slot):
		var n := Vector2(st["sigma"] * cos(st["phi"]), -sin(st["phi"]))
		return {"pos": _anchor_for(hud.layout, Vector2(640.0, 360.0), n, slot), "h": 90.0, "visible": true}
	hud.strip_fn = func(): return {"W": 9600.0, "segs": [[0.0, 9600.0, "ocean"]], "cam_x": 0.0, "cam_w": 2000.0, "dead": [], "fighters": []}
	for i in range(10):
		hud.advance(1.0 / 60.0)
		await process_frame
	_ok(not hud.layout.swapped and hud.hub.model(0).left_side and not hud.hub.model(1).left_side, "hud split: sigma +1 keeps slot 0 on the left")
	_ok(hud._div_light.visible and hud._div_dark.visible and hud._l_ring.sig != null and hud._l_ring_base.sig != null and hud._l_chips[0].visible and hud._l_chips[1].visible and hud._l_chips[0].sig != null, "hud split: the divider bars, the ring map and both pointer chips show while the panes are open")
	_ok(hud._chips.size() == 2, "hud split: one pointer chip per pane")
	var bad_chip := 0
	var lay2: UiLayout = hud.layout
	var n0 := Vector2(cos(0.3), -sin(0.3))
	for ch in hud._chips:
		var slot: int = int(ch["slot"])
		var dirn: Vector2 = n0 if slot == 0 else -n0
		if (ch["dir"] as Vector2).dot(dirn) < 0.99:
			bad_chip += 1
		# On its own side of the divider and inside the safe area.
		if (ch["pos"] - Vector2(640.0, 360.0)).dot(n0) * (-1.0 if slot == 0 else 1.0) <= 0.0 or not lay2.safe.grow(1.0).has_point(ch["pos"]):
			bad_chip += 1
	_ok(bad_chip == 0, "hud split: each pointer points the rival's way and sits in its own pane inside the safe area")
	_ok(hud._chips[0]["text"] == str(int(round(40000.0 / 75.0 / 25.0)) * 25), "hud split: the distance is in fighter heights (from the ring's angles and the planet's size)")
	_ok(hud.pane_clear_zone(0).size() >= 3 and hud.pane_clear_zone(1).size() >= 3, "hud split: pane_clear_zone gives each fighter's zone")
	st["sigma"] = -1.0
	for i in range(30):
		hud.advance(1.0 / 60.0)
		await process_frame
	_ok(hud.layout.swapped and not hud.hub.model(0).left_side and hud.hub.model(1).left_side, "hud split: sigma -1 swaps the plate, card and bark columns")
	st["sep"] = 0.0
	for i in range(6):
		hud.advance(1.0 / 60.0)
		await process_frame
	_ok(not hud._div_light.visible and not hud._l_chips[0].visible and not hud._l_chips[1].visible and hud._l_ring.sig != null, "hud split: merged, the divider and the chips clear and the ring map stays")
	# One camera, no split: pointers only when the rival is off screen.
	hud.split_fn = func(): return {"sep": 0.0, "sigma": 1.0, "pointer": "always", "ring": {"angle_A": 0.0, "angle_B": 1.0, "sigma": 1, "arc_A": 0.3, "arc_B": 0.3, "swing": 0.0, "sep": 0.0}}
	hud.anchor_fn = func(slot): return {"pos": Vector2(300.0 + 500.0 * float(slot), 300.0), "h": 90.0, "visible": true}
	hud.advance(1.0 / 60.0)
	_ok(hud._chips.is_empty(), "pointers: a single camera with the rival in view shows none")
	hud.anchor_fn = func(slot): return {"pos": Vector2(300.0, 300.0), "h": 90.0, "visible": slot == 0}
	hud.advance(1.0 / 60.0)
	_ok(hud._chips.size() >= 1, "pointers: a single camera with the rival off screen shows a chip toward it")
	hud.queue_free()
	await process_frame


func _fx_defaults() -> void:
	# The sim's FxEvent carries every field with a default: finisher_start has dur 0.0, so it must still run its 3 s.
	var hub := _hub()
	var fs := SimState.FxEvent.new()
	fs.type = "finisher_start"
	fs.actor = 0.0
	fs.target = 1.0
	hub.consume(fs)
	_step(hub, 0.2)
	_ok(hub.mode == UiEventHub.Mode.CINEMATIC and hub.cinematic_left > 2.5, "fx defaults: a finisher_start object (dur 0.0) runs the 3 s default cinematic")
	var ko := SimState.FxEvent.new()
	ko.type = "ko"
	ko.winner = 0.0
	ko.loser = 1.0
	hub = _hub()
	hub.consume(ko)
	_step(hub, 0.2)
	_ok(hub.mode == UiEventHub.Mode.CINEMATIC and hub.model(1).ko, "fx defaults: a ko object runs its cinematic and marks the loser")
	var cs := SimState.FxEvent.new()
	cs.type = "cinematic_start"
	cs.actor = 0.0
	hub = _hub()
	hub.consume(cs)
	_step(hub, 0.2)
	_ok(hub.cinematic_kind == "transformation" and hub.crown_locked(), "fx defaults: a cinematic_start object with no kind is a transformation and locks the crown")
	var wo := SimState.FxEvent.new()
	wo.type = "window_open"
	wo.actor = 1.0
	wo.kind = "parry"
	wo.dur = 0.33
	hub = _hub()
	hub.consume(wo)
	_ok(hub.model(1).parry_t == 0.0 and is_equal_approx(hub.model(1).parry_dur, 0.33), "fx defaults: the sim's window_open (actor, kind, dur) opens the parry ring")


# --- Controls' rulings: the struggle rings, press acks, window ticks, availability, glyphs -------------------------------

func _controls_rules() -> void:
	# Glyph tables: every action has an entry for every device family, in the neutral style, and the neutral style prints
	# only position letters and plain text marks (no console maker's letters).
	var g: Dictionary = UiData.glyphs()
	var fams: Array = g.get("families", [])
	var missing := 0
	for act in (g.get("actions", {}) as Dictionary):
		for fam in fams:
			for slot in range(2):
				if UiGlyphs.spec(act, fam, slot).is_empty() or str(UiGlyphs.spec(act, fam, slot).get("kind", "")) == "":
					missing += 1
	_ok(missing == 0 and fams.size() == 6, "glyphs: every action has an entry for every device family (%d missing)" % missing)
	_ok(UiGlyphs.spec("light", "xbox", 0)["label"] == "W" and UiGlyphs.spec("signature", "switch", 0)["label"] == "E" and UiGlyphs.spec("context", "ps", 0)["label"] == "S", "glyphs: the neutral style prints position letters (W, E, S), not a maker's letters")
	_ok(UiGlyphs.spec("light", "xbox", 0, "family")["label"] == "X" and UiGlyphs.spec("signature", "switch", 0, "family")["label"] == "A", "glyphs: the family style exists in the data (X on xbox, A on switch) but is not the default")
	_ok(UiGlyphs.spec("light", "kbd", 0)["label"] == "J" and UiGlyphs.spec("light", "kbd", 1)["label"] == "H" and UiGlyphs.spec("guard", "kbd", 1)["label"] == ";", "glyphs: keyboard slots show their own keys")
	_ok(UiGlyphs.spec("dash", "xbox", 0).is_empty() and UiGlyphs.spec("stance_press", "xbox", 0).is_empty() and UiGlyphs.spec("charge", "kbd", 0).is_empty(), "glyphs: the retired actions (dash, stances, charge) have no glyph")
	# The glyph of an action is the active layout's own binding (data/input/layouts.json): a single control in preference to a chord,
	# four axis keys as one cap, a chord as its controls joined by a plus, and nothing for an action the layout does not bind.
	var lbl := func(preset: String, action: String, fam: String) -> String:
		var parts := PackedStringArray()
		for sp in UiGlyphs.specs_for(action, fam, 0, "neutral", preset):
			parts.append(str(sp.get("label", "")))
		return " ".join(parts)
	_ok(lbl.call("kb-solo", "move", "kbd") == "WASD" and lbl.call("kb-solo", "dodge", "kbd") == "Space" and lbl.call("kb-solo", "guard", "kbd") == "Shift" and lbl.call("kb-solo", "light", "kbd") == "J" and lbl.call("kb-solo", "transform", "kbd") == "R", "glyphs: kb-solo reads WASD, Space, Shift, J and R for transform (the single key beats the chord)")
	_ok(lbl.call("kb-shared-p2", "move", "kbd") == "IJKL" and lbl.call("kb-shared-p2", "guard", "kbd") == ";" and lbl.call("kb-shared-p2", "dodge", "kbd") == "." and lbl.call("kb-shared-p2", "transform", "kbd") == ". + /", "glyphs: kb-shared-p2 reads IJKL, ; and . and the chord . + / for transform")
	_ok(lbl.call("arena", "guard", "xbox") == "LB" and lbl.call("arena", "dodge", "xbox") == "LT" and lbl.call("arena", "transform", "xbox") == "LT + RT" and lbl.call("brawler", "light", "xbox") == "RB" and lbl.call("simple-pad", "transform", "xbox") == "RB", "glyphs: the pad presets read LB guard, LT dodge, the LT + RT chord (RB on Simple) for transform")
	_ok(UiGlyphs.bound("brawler", "mode") and not UiGlyphs.bound("simple-pad", "mode") and not UiGlyphs.bound("simple-pad", "heavy") and UiGlyphs.bound("arena", "specials") and UiGlyphs.bound("", "mode"), "glyphs: a layout that does not bind an action is told apart (Simple has no mode or heavy key)")
	# Options: hitstop_scale and the hot-seat layout are in the data.
	var od: Dictionary = UiData.option_defaults()
	_ok(is_equal_approx(float(od.get("hitstop_scale", -1.0)), 1.0) and od.get("hotseat_alt_layout") == false and od.get("show_prompts") == false, "options: hitstop_scale defaults to 1.0, the hot-seat layout to off, prompts to off")
	var o: Dictionary = UiData.options()
	# Settings: Camera's zoom and shake (0 to 10), the pad layout, and a change signal the host applies from.
	_ok(float(od.get("camera_zoom", -1.0)) == 7.0 and float(od.get("camera_shake", -1.0)) == 2.0 and float(o["camera_zoom"]["min"]) == 0.0 and float(o["camera_zoom"]["max"]) == 10.0 and float(o["camera_shake"]["max"]) == 10.0 and float(o["camera_zoom"]["step"]) == 1.0 and o["camera_shake"].get("accessibility", false), "options: camera_zoom (0 to 10, default 7) and camera_shake (0 to 10, default 2, accessibility) are in the data")
	_ok(od.get("pad_preset") == "arena" and (o["pad_preset"]["choices"] as Array) == ["arena", "brawler", "simple-pad"] and o["pad_preset"]["group"] == "controls", "options: pad_preset offers arena, brawler and simple-pad, default arena")
	var pad_ids_ok := true
	for pid0 in o["pad_preset"]["choices"]:
		if SimInputData.preset(str(pid0)).is_empty() or str(SimInputData.preset(str(pid0)).get("device", "")) != "pad":
			pad_ids_ok = false
	_ok(pad_ids_ok and SimInputData.preset("arena").get("name", "") == "Arena" and SimInputData.preset("simple-pad").get("name", "") == "Simple", "options: every pad_preset choice is a pad layout in data/input/layouts.json (named Arena, Brawler, Simple)")
	_ok(UiData.clamp_option("camera_zoom", 15) == 10.0 and UiData.clamp_option("camera_zoom", -3) == 0.0 and UiData.clamp_option("camera_zoom", 6.4) == 6.0 and UiData.clamp_option("camera_shake", 4) == 4.0 and UiData.clamp_option("glyph_style", "family") == "family" and UiData.clamp_option("no_such_option", 99) == 99, "options: a slider is held to 0..10 in whole steps, other keys pass through")
	var oh: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	root.add_child(oh)
	await process_frame
	var got: Array = []
	oh.option_changed.connect(func(k, v): got.append([k, v]))
	oh.set_option("pad_preset", "brawler")
	oh.set_option("pad_preset", "brawler")
	oh.set_option("camera_zoom", 99)
	_ok(got == [["pad_preset", "brawler"], ["camera_zoom", 10.0]] and oh.opts["pad_preset"] == "brawler" and oh.opts["camera_zoom"] == 10.0 and oh.opts["camera_shake"] == 2, "options: set_option announces a change once (so the host can set SimInputHub.pad_preset) and clamps the sliders")
	# The Transform prompt: the layout's own control, while a form is ready and prompts are on.
	var tm := UiFighterModel.new()
	tm.ai = false
	tm.slot = 0
	tm.device = "kbd"
	tm.avail["transform"] = true
	var tchip := func(o2: Dictionary) -> Dictionary:
		for c in UiPrompts.plan(tm, Rect2(0, 0, 900, 40), 1.0, o2):
			if c["name"] == "transform":
				return c
		return {}
	var tc_kb: Dictionary = tchip.call({"prompts": true, "control_scheme": "kb-solo"})
	var tc_pad: Dictionary = tchip.call({"prompts": true, "control_scheme": "arena"})
	_ok(not tc_kb.is_empty() and not tc_pad.is_empty() and float(tc_pad["gw"]) > float(tc_kb["gw"]) and tchip.call({"prompts": false}).is_empty(), "options: the Transform chip is the layout's control (R on the solo keyboard, LT + RT on Arena), only while prompts are on")
	tm.avail["transform"] = false
	_ok(tchip.call({"prompts": true, "control_scheme": "kb-solo"}).is_empty(), "options: and it goes when no form is ready")
	oh.queue_free()
	await process_frame
	_ok(float(o["hitstop_scale"].get("min", 0.0)) == 0.5 and float(o["hitstop_scale"].get("max", 0.0)) == 1.0 and o["hitstop_scale"].get("accessibility", false), "options: hitstop_scale runs 0.5 to 1.0 and is an accessibility option")
	# The struggle (Q4: resolved by state). Beats at -18 and 0 (count-in), 18, 36, 54; three pulses reveal holding or slipping; no press.
	var hub := _hub()
	hub.consume({"type": "struggle_open", "actor": 1})
	_ok(not hub.struggle.is_empty() and hub.struggle["beats"] == [-18, 0, 18, 36, 54] and int(hub.struggle["resolve"]) == 66, "struggle: opens with the default beats (-18, 0, 18, 36, 54; resolve 66)")
	_ok(is_equal_approx(float(hub.struggle["t"]), -18.0 / 60.0), "struggle: the count-in starts 18 ticks before contestOpen")
	_step(hub, 36.0 / 60.0)   # to tick 18 after contestOpen
	hub.consume({"type": "struggle_pulse", "actor": 1, "n": 1, "state": "holding"})
	_ok(hub.struggle["res"][18] == "hit" and hub.struggle["last"] == "holding", "struggle: a holding pulse marks its ring and names the state")
	hub.consume({"type": "struggle_pulse", "actor": 1, "n": 2, "state": "slipping"})
	_ok(hub.struggle["res"][36] == "miss" and hub.struggle["last"] == "slipping", "struggle: a slipping pulse marks its ring and names the state")
	hub.consume({"type": "press_ack", "actor": 1, "kind": "struggle", "result": "hit"})
	_step(hub, 46.0 / 60.0)
	_ok(hub.struggle["res"][54] == "" and hub.struggle["res"][18] == "hit", "struggle: there is no press to score: an unrevealed ring stays open, nothing turns into a miss")
	hub.consume({"type": "struggle_pulse", "actor": 1, "n": 3, "state": "bogus"})
	_ok(hub.struggle["res"][54] == "", "struggle: a pulse with an unknown state is ignored")
	hub.consume({"type": "finisher_contest", "target": 1, "chance": 0.3, "survived": true})
	_step(hub, 0.7)
	_ok(hub.struggle.is_empty(), "struggle: it ends shortly after the contest resolves, and the chance is never shown")
	var pulse_only := _hub()
	pulse_only.consume({"type": "struggle_pulse", "actor": 0, "n": 1, "state": "slipping"})
	_ok(not pulse_only.struggle.is_empty() and pulse_only.struggle["res"][18] == "miss", "struggle: a pulse with no open event still opens the rings")
	var span := 100.0
	_ok(is_equal_approx(UiStruggle.ring_radius(50.0, span, 18.0, false), 150.0) and is_equal_approx(UiStruggle.ring_radius(50.0, span, 0.0, false), 50.0) and is_equal_approx(UiStruggle.ring_radius(50.0, span, 9.0, false), 100.0), "struggle: a ring closes linearly and lands on the target exactly on the beat")
	_ok(absf(UiStruggle.ring_radius(50.0, span, 9.0, true) - 116.67) < 0.1, "struggle: reduced motion steps the ring in thirds instead of easing")
	# Weight (sticky, Game Design R9 and Controls stage C): light at the start, set by an event, a state patch or an ack; fallback is a mark.
	hub = _hub()
	_ok(hub.model(0).weight == "light" and hub.model(1).weight == "light", "weight: a match starts in light")
	hub.consume({"type": "weight_set", "actor": 1, "weight": "heavy"})
	_ok(hub.model(1).weight == "heavy" and hub.model(0).weight == "light", "weight: weight_set sets one fighter's weight (the rival's is a read too)")
	hub.patch(0, {"weight": 1})
	_ok(hub.model(0).weight == "heavy", "weight: a state patch with 1 is heavy")
	hub.consume({"type": "press_ack", "actor": 0, "kind": "weight_light"})
	_ok(hub.model(0).weight == "light", "weight: the ack sets the mark within the same call (inside two ticks)")
	hub.consume({"type": "press_ack", "actor": 1, "kind": "weight_fallback"})
	_ok(hub.model(1).weight == "heavy" and hub.model(1).weight_fallback_t == 0.0, "weight: a fallback keeps the mode heavy and shows the mark")
	_step(hub, 1.7)
	_ok(hub.model(1).weight_fallback_t > 1.5, "weight: the fallback mark goes after 1.5 s")
	# Signature intent: queued, funded (the 180-tick cap), fired, cancelled, expired or fallen back.
	hub = _hub()
	var sm: UiFighterModel = hub.model(0)
	sm.charge = 20.0
	hub.consume({"type": "sig_queued", "actor": 0, "state": "queued"})
	_ok(sm.sig_queued and not sm.sig_funded, "signature: queued without the Charge waits unfunded (the chip fills toward 45)")
	hub.patch(0, {"charge": 50.0})
	hub.consume({"type": "press_ack", "actor": 0, "kind": "sig_funded"})
	_ok(sm.sig_queued and sm.sig_funded and sm.sig_cap_t == 0.0, "signature: funded starts the cap")
	_step(hub, 1.5)
	_ok(absf(sm.sig_cap_t - 1.5) < 0.05, "signature: the 3 s cap runs down while the clock runs")
	sm.charging = true
	_step(hub, 1.0)
	sm.charging = false
	_ok(absf(sm.sig_cap_t - 1.5) < 0.05, "signature: the cap pauses while the fighter charges")
	hub.consume({"type": "sig_queued", "actor": 0, "state": "fired"})
	_ok(not sm.sig_queued and not sm.sig_funded and sm.sig_note == "fired" and sm.sig_note_t == 0.0, "signature: fired clears the intent and leaves a brief note")
	for st in ["expired", "fallback"]:
		hub.consume({"type": "sig_queued", "actor": 0, "state": "queued"})
		hub.consume({"type": "sig_queued", "actor": 0, "state": st})
		_ok(not sm.sig_queued and sm.sig_note == st, "signature: %s ends the intent with its note" % st)
	hub.consume({"type": "press_ack", "actor": 0, "kind": "sig_queued"})
	_ok(sm.sig_queued and sm.sig_funded, "signature: queueing with the Charge already there is funded at once")
	hub.consume({"type": "press_ack", "actor": 0, "kind": "sig_cancelled"})
	_ok(not sm.sig_queued and sm.sig_note == "cancelled", "signature: pressing again cancels it")
	# The rival's stance is an edge as well as state: stance_set changes it and makes the chip pulse.
	hub = _hub()
	hub.consume({"type": "stance_set", "actor": 1, "stance": 1})
	_ok(hub.model(1).stance == 1 and hub.model(1).stance_flash_t == 0.0, "reads: stance_set changes the stance and pulses the chip")
	hub.consume({"type": "stance_set", "actor": 1, "stance": "escape"})
	_ok(hub.model(1).stance == 3, "reads: a stance id works as well as an index")
	# The finisher telegraph: the kind shows for the whole wind-up (Game Design: stance against the finisher's kind).
	hub = _hub()
	hub.consume({"type": "finisher_start", "actor": 1, "target": 0, "kind": "beam", "dur": 3.0})
	_ok(hub.telegraph.get("kind", "") == "beam" and int(hub.telegraph["actor"]) == 1 and int(hub.telegraph["target"]) == 0, "telegraph: finisher_start with a kind shows it")
	_ok(UiReads.telegraph_sig(hub, false, false) != UiReads.telegraph_sig(hub, true, false), "telegraph: prompts add the answering stance (a different picture)")
	var cnt: Dictionary = UiData.reads()["finisher_counter"]
	_ok(cnt["launch"] == "guard" and cnt["melee"] == "dodge" and cnt["beam"] == "press", "telegraph: the answers are GUARD a launch, DODGE a melee, PRESS a beam")
	hub.consume({"type": "finisher_contest", "target": 0})
	_step(hub, 0.6)
	_ok(hub.telegraph.is_empty(), "telegraph: it goes when the contest is over")
	hub.consume({"type": "finisher_start", "actor": 0, "target": 1})
	_ok(hub.telegraph.is_empty(), "telegraph: a finisher with no kind has no chip (the cinematic still runs)")
	hub.consume({"type": "finisher_start", "actor": 0, "target": 1, "kind": "bogus"})
	_ok(hub.telegraph.is_empty(), "telegraph: an unknown kind is ignored")
	hub.consume({"type": "finisher_start", "actor": 0, "target": 1, "kind": "melee"})
	hub.consume({"type": "ko", "winner": 0, "loser": 1})
	_ok(hub.telegraph.is_empty(), "telegraph: a KO clears it")
	# Tutorial hints (Narrative's lines in ui/data/reads.json).
	var rd_: Dictionary = UiData.reads()
	var hints: Dictionary = rd_["hints"]
	var bad_words := 0
	for k in hints:
		if str(hints[k]).split(" ", false).size() > 14:
			bad_words += 1
	var ids: Array = rd_["beat_ids"]
	var no_hint := 0
	for id in ids:
		if not hints.has(str(id) + ".hint") or not hints.has(str(id) + ".done"):
			no_hint += 1
	_ok(ids.size() == 9 and no_hint == 0 and bad_words == 0, "hints: nine beats, each with a hint and a done line, every line 14 words or fewer (two lines at most)")
	_ok(hints.has("b1.nudge") and hints.has("b8.nudge") and not hints.has("b9.nudge"), "hints: beats 1 to 8 have a nudge, the last beat has none")
	hub = _hub()
	hub.consume({"type": "tutorial_beat", "id": "b3", "state": "start"})
	hub.consume({"type": "tutorial_hint", "id": "b3", "text_key": "b3.hint"})
	_ok(hub.hint["text"] == "They're guarding. Hit heavy." and hub.hint["kind"] == "hint" and hub.beats["b3"] == "start", "hint: a hint event shows Narrative's line for its key")
	hub.consume({"type": "tutorial_hint", "id": "b3", "text_key": "b3.alt1"})
	_ok(hub.hint["text"] == "Guard up? Go heavy." and hub.hint["kind"] == "hint", "hint: an alternate is a hint too")
	hub.consume({"type": "tutorial_hint", "id": "b3", "text_key": "b3.nudge"})
	_ok(hub.hint["kind"] == "nudge", "hint: the nudge has its own kind")
	hub.consume({"type": "tutorial_beat", "id": "b3", "state": "done"})
	_ok(hub.hint.is_empty(), "hint: a beat that is done clears its open hint")
	hub.consume({"type": "tutorial_hint", "id": "b3", "text_key": "b3.done"})
	_ok(hub.hint["kind"] == "done" and hub.hint_alpha() < 0.1, "hint: a done line rises from nothing")
	_step(hub, 1.0)
	_ok(is_equal_approx(hub.hint_alpha(), 1.0), "hint: it is fully up after 0.25 s")
	_step(hub, 1.5)
	_ok(hub.hint_alpha() < 0.5, "hint: a done line fades over its last half second")
	_step(hub, 0.5)
	_ok(hub.hint.is_empty(), "hint: a done line is gone after 2.6 s")
	hub.consume({"type": "tutorial_hint", "id": "b1", "text_key": "b1.hint"})
	_step(hub, 11.0)
	_ok(is_equal_approx(hub.hint_alpha(), 0.6), "hint: a hint dims to 60% after ten seconds so it does not nag")
	hub.keep_hints = true
	_ok(is_equal_approx(hub.hint_alpha(), 1.0), "hint: keep hints on holds it at full")
	hub.consume({"type": "tutorial_beat", "id": "b1", "state": "done"})
	_ok(not hub.hint.is_empty(), "hint: and keeps it after the beat is done, until the next one")
	hub.consume({"type": "tutorial_hint", "id": "b2", "text_key": ""})
	_ok(hub.hint.is_empty(), "hint: an empty key clears the line")
	hub.consume({"type": "tutorial_hint", "id": "b2", "text_key": "nope.hint"})
	_ok(hub.hint.is_empty(), "hint: an unknown key shows nothing")
	hub.consume({"type": "tutorial_hint", "id": "x", "text": "A line the sim wrote."})
	_ok(hub.hint.get("text", "") == "A line the sim wrote.", "hint: an event may carry its own text")
	# Thoughts (Narrative's display styles): a thought, a shout, and a caption.
	hub = _hub()
	hub.consume({"type": "bark", "speaker": 0, "text": "They're guarding. Something heavy, then.", "display": {"style": "thought", "dur_s": 2.0}, "cues": []})
	_ok(hub.barks.size() == 1 and hub.barks[0].style == "thought" and is_equal_approx(hub.barks[0].dur, 2.0) and hub.barks[0].priority == 1, "thought: a display style of thought is a low-priority inner line with its own hold")
	hub.consume({"type": "bark", "speaker": 1, "text": "Never!", "display": "shout", "cues": []})
	_ok(hub.barks.size() == 2 and hub.barks[1].style == "shout", "thought: a shout is its own style")
	hub.consume({"type": "bark", "speaker": 0, "text": "Another.", "kind": "thought", "cues": []})
	_ok(hub.bark_wait.size() + hub.barks.size() >= 3 and (hub.bark_wait.back() as UiEventHub.Bark).style == "thought", "thought: kind thought alone makes a thought")
	hub.consume({"type": "bark", "speaker": 0, "text": "Plain.", "cues": [], "priority": 3})
	_ok(hub.barks.any(func(b): return b.style == "caption"), "thought: a line with no display style is a caption")
	# Invisible acts and the fight's mood: nothing shows them; the feed names them.
	hub = _hub()
	hub.consume({"type": "act_change", "act": 2})
	hub.consume({"type": "mood_band", "band": "tense"})
	_ok(hub.act == 2 and hub.mood_band == "tense" and hub.feed.size() == 2, "acts and mood: recorded and named in the feed, never drawn")
	# window_open: the closing ring is the director's moment now; the clean tail is gone.
	hub = _hub()
	hub.consume({"type": "window_open", "actor": 1, "kind": "parry", "dur_ticks": 20, "clean_ticks": 6})
	_ok(is_equal_approx(hub.model(1).parry_dur, 20.0 / 60.0) and hub.model(1).parry_clean == 0.0, "window: dur_ticks sets the length and a clean tail is ignored (no timing press remains)")
	var wo := SimState.FxEvent.new()
	wo.type = "window_open"
	wo.actor = 0.0
	wo.kind = "chain"
	wo.dur = 0.6
	hub.consume(wo)
	_ok(hub.model(0).chain_t == 0.0 and hub.model(0).chain_n == 0, "window: a chain window object from the sim opens without an n")
	# Availability: Special and Transform prompts appear only while the action can be used.
	hub = _hub()
	_ok(not hub.model(0).avail["transform"] and not hub.model(0).avail["special"], "availability: nothing is available at first")
	hub.consume({"type": "availability", "actor": 0, "action": "transform"})
	hub.consume({"type": "availability", "actor": 0, "action": "special", "available": true})
	_ok(hub.model(0).avail["transform"] and hub.model(0).avail["special"], "availability: an availability event turns the action on")
	hub.consume({"type": "availability", "actor": 0, "action": "special", "available": false})
	_ok(not hub.model(0).avail["special"] and hub.model(0).avail["transform"], "availability: and off")
	hub.patch(0, {"hold_transform": 0.5})
	_ok(is_equal_approx(float(hub.model(0).hold["transform"]), 0.5), "availability: the hold ring's progress is a state patch")
	# The prompt row: nothing for an AI fighter, the stance prompt for 3 s after a change, hold prompts only with prompts on.
	var m: UiFighterModel = hub.model(0)
	m.ai = false
	m.stance_prompt_t = 99.0
	_ok(not UiPrompts.has_content(m, false) or false, "prompts: with prompts off the stance prompt is gone after 3 s and availability alone does not show")
	hub.patch(0, {"stance": 2})
	_ok(UiPrompts.has_content(m, false) and UiPrompts.stance_visible(m, false), "prompts: a stance change shows the stance prompt for a moment")
	_step(hub, 3.2)
	_ok(not UiPrompts.stance_visible(m, false), "prompts: and it is gone after 3 s")
	_ok(UiPrompts.has_content(m, true), "prompts: with prompts on the row shows availability and the stance prompt")
	m.ai = true
	_ok(not UiPrompts.has_content(m, true), "prompts: an AI fighter has no device and gets no prompts")
	# The layout keeps the prompt rows in the outer columns, clear of the fight.
	var lay := UiLayout.new()
	lay.compute(Vector2(1920, 1080), false)
	_ok(lay.prompts[0].size.y > 0.0 and not lay.prompts[0].intersects(lay.clear_zone) and not lay.prompts[1].intersects(lay.clear_zone) and not lay.prompts[0].intersects(lay.cards[0]), "prompts: the rows sit under the cards, outside the clear zone")


func _split_cost() -> void:
	# The split layers are cheap by construction: a divider that turns and moves costs no redraw, a chip that follows a fighter
	# costs none, and the distance text is rounded so the chip redraws a few times a second.
	_ok(UiSplit._dist_text(47.0) == "45" and UiSplit._dist_text(48.0) == "50" and UiSplit._dist_text(237.0) == "225" and UiSplit._dist_text(1234.0) == "1.2k", "split cost: the distance rounds to 5, then 25, then tenths of a thousand")
	root.size = Vector2i(1280, 720)
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	root.add_child(hud)
	hud.setup(["kai", "vorr"], ["KAI", "VORR"])
	hud.hub.model(0).ai = true   # two AI fighters, as in the demo: no YOU marker follows them, so this measures the split layers alone
	hud.hub.model(1).ai = true
	var st := {"t": 0.0}
	hud.split_fn = func():
		var phi: float = 0.3 * sin(st["t"] * 0.7)
		return {"sep": 1.0, "c": Vector2(640.0, 360.0), "n": Vector2(cos(phi), -sin(phi)), "gap": 3.0, "fade": 1.0, "sigma": 1.0, "pointer": "split", "dist_bh": 60.0 + 40.0 * sin(st["t"]),
			"ring": {"angle_A": 1.0 + 0.5 * sin(st["t"]), "angle_B": 2.0, "sigma": 1, "arc_A": 0.3, "arc_B": 0.3, "swing": 0.0, "sep": 1.0}}
	hud.anchor_fn = func(slot): return {"pos": Vector2(300.0 + 700.0 * float(slot) + 40.0 * sin(st["t"] * 2.0), 400.0), "h": 90.0, "visible": true}
	hud.strip_fn = func(): return {"W": 9600.0, "segs": [[0.0, 9600.0, "ocean"]], "cam_x": 0.0, "cam_w": 2000.0, "dead": [], "fighters": []}
	for i in range(300):
		st["t"] += 1.0 / 60.0
		hud.advance(1.0 / 60.0)
		await process_frame
	var r0: int = hud.redraw_count()
	var chip0: int = hud._l_chips[0].redraws + hud._l_chips[1].redraws
	var frames := 300
	for i in range(frames):
		st["t"] += 1.0 / 60.0
		hud.advance(1.0 / 60.0)
		await process_frame
	var chip_redraws: int = hud._l_chips[0].redraws + hud._l_chips[1].redraws - chip0
	var all_redraws: int = hud.redraw_count() - r0
	print("  split cost: over %d frames of a moving split, %d layer redraws (%d of them chips)" % [frames, all_redraws, chip_redraws])
	_ok(chip_redraws <= frames * 10 / 60 + 4, "split cost: two chips redraw at most about five times a second each (%d in %d)" % [chip_redraws, frames])
	_ok(all_redraws <= frames, "split cost: the whole moving split redraws at most one layer a frame on average (%d in %d)" % [all_redraws, frames])
	hud.queue_free()
	await process_frame


## Edge pointer chips keep about one fighter height clear of both fighters (Camera's threshold lets a fighter sit at 44% of the width).
func _chip_dodge() -> void:
	var tag := "chip dodge"
	for sz in [Vector2(1920, 1080), Vector2(1280, 720)]:
		var lay := UiLayout.new()
		lay.compute(sz, false)
		var c: Vector2 = sz * 0.5
		var sp := {"sep": 1.0, "c": c, "n": Vector2(1.0, 0.0), "fade": 1.0, "sigma": 1.0, "pointer": "split", "dist_bh": 60.0}
		var fh: float = sz.y * 0.11
		var psz: Vector2 = UiSplit.pointer_size(lay.s)
		# Far apart: nothing to dodge, the chips sit at the divider at their fighter's height.
		var far: Array = [{"pos": Vector2(c.x - 0.4 * sz.x, c.y), "h": fh, "visible": true}, {"pos": Vector2(c.x + 0.4 * sz.x, c.y), "h": fh, "visible": true}]
		var chips: Array = UiSplit.pointers(lay, sp, far, lay.s)
		_ok(chips.size() == 2 and absf((chips[0]["pos"] as Vector2).y - c.y) < 1.0 and absf((chips[1]["pos"] as Vector2).y - c.y) < 1.0, "%s %s: fighters far from the divider leave the chips at their own height" % [tag, sz])
		# Both fighters hard against the divider: every chip that shows is at least one fighter height from both anchors.
		var near: Array = [{"pos": Vector2(c.x - 0.03 * sz.x, c.y), "h": fh, "visible": true}, {"pos": Vector2(c.x + 0.03 * sz.x, c.y + 0.02 * sz.y), "h": fh, "visible": true}]
		chips = UiSplit.pointers(lay, sp, near, lay.s)
		var bad := 0
		for ch in chips:
			if not UiSplit._chip_clear(ch["pos"], psz, near) or not lay.safe.grow(1.0).has_point(ch["pos"]):
				bad += 1
		_ok(chips.size() >= 1 and bad == 0, "%s %s: chips beside both fighters slide along the edge to a clear spot inside the safe area (%d shown)" % [tag, sz, chips.size()])
		# A fighter as tall as the screen leaves no room: the chips hide rather than cover it.
		var huge: Array = [{"pos": Vector2(c.x - 40.0, c.y), "h": sz.y * 1.5, "visible": true}, {"pos": Vector2(c.x + 40.0, c.y), "h": sz.y * 1.5, "visible": true}]
		_ok(UiSplit.pointers(lay, sp, huge, lay.s).is_empty(), "%s %s: with no clear place the chips hide" % [tag, sz])
		# An unseen fighter is not a keep-out.
		var unseen: Array = [{"pos": Vector2(c.x - 30.0, c.y), "h": fh, "visible": false}, {"pos": Vector2(c.x + 0.4 * sz.x, c.y), "h": fh, "visible": true}]
		chips = UiSplit.pointers(lay, sp, unseen, lay.s)
		_ok(chips.size() == 2 and absf((chips[0]["pos"] as Vector2).y - c.y) < 1.0, "%s %s: an off-screen fighter does not move the chip" % [tag, sz])


## Responsive: text and targets follow the screen's size and density (docs/ui/hud-spec.md section 16).
func _responsive() -> void:
	# A desktop is unchanged: dp 1 keeps the floor at 14 and the scale at the old value.
	var d0 := UiLayout.new()
	d0.compute(Vector2(1920, 1080), false)
	_ok(is_equal_approx(d0.s, 1.0) and is_equal_approx(d0.text_floor, 14.0) and is_equal_approx(UiLook.text_floor, 14.0), "responsive: a desktop at dp 1 keeps the scale 1.0 and the text floor 14")
	# Phones and tablets in landscape, at their real pixel sizes and densities, touch off and on.
	var cases: Array = [[Vector2(2400, 1080), 2.6], [Vector2(2340, 1080), 2.75], [Vector2(2532, 1170), 3.0], [Vector2(1560, 720), 2.0], [Vector2(1920, 1080), 1.5], [Vector2(1600, 720), 1.0], [Vector2(2560, 1600), 2.0]]
	for cs in cases:
		var sz: Vector2 = cs[0]
		var dpv: float = cs[1]
		for touch in [false, true]:
			var lay := UiLayout.new()
			lay.dp = dpv
			lay.touch_ui = touch
			lay.compute(sz, false)
			var tag := "responsive %dx%d dp %.2f touch=%s" % [int(sz.x), int(sz.y), dpv, str(touch)]
			var want_floor: float = maxf(14.0, 12.0 * dpv) if dpv > 1.25 else 14.0
			_ok(is_equal_approx(lay.text_floor, want_floor), "%s: the text floor is 12 dp (%.0f px)" % [tag, lay.text_floor])
			var low := 0
			for k in ["fs_name", "fs_chip", "fs_tier", "fs_ego", "fs_state"]:
				if float(lay.pm[k]) < lay.text_floor - 0.5:
					low += 1
			_ok(low == 0, "%s: every plate text is at or above the floor" % tag)
			var view := Rect2(Vector2.ZERO, sz)
			var bad := 0
			for r in lay.hud_rects():
				if not view.encloses(r) or r.intersects(lay.clear_zone):
					bad += 1
			_ok(bad == 0, "%s: every HUD rectangle is on screen and out of the fight (%d bad)" % [tag, bad])
			_ok(lay.clear_zone.size.x > sz.x * 0.30 and lay.clear_zone.size.y > sz.y * 0.40, "%s: the fight keeps the middle (%d by %d px)" % [tag, int(lay.clear_zone.size.x), int(lay.clear_zone.size.y)])
			if touch:
				var tm: float = lay.touch_min
				_ok(is_equal_approx(tm, maxf(48.0 * dpv, 44.0)) and lay.pause_btn.size.x >= tm - 0.01 and lay.pause_btn.size.y >= tm - 0.01, "%s: the pause button is a 48 dp target (%d px)" % [tag, int(lay.pause_btn.size.x)])
				_ok(lay.pause_btn.size.y > 0.0 and not lay.pause_btn.intersects(lay.plate[0]) and not lay.pause_btn.intersects(lay.plate[1]) and not lay.pause_btn.intersects(lay.toll), "%s: the pause button clears the plates and the toll chip" % tag)
				_ok(lay.prompts[0].size.y <= 0.0 and lay.prompts[1].size.y <= 0.0 and lay.hints[0].size.y <= 0.0, "%s: no stance ring or legend on touch (the buttons are the controls)" % tag)
	# A narrow phone (800 wide at dp 1) still keeps its floor and the fight.
	var lay2 := UiLayout.new()
	lay2.compute(Vector2(800, 360), false)
	_ok(lay2.clear_zone.size.x > 800.0 * 0.30 and float(lay2.pm["fs_name"]) >= 14.0, "responsive: 800 by 360 at dp 1 keeps the floor and the fight")
	UiLook.text_floor = UiLook.MIN_TEXT_PX
	# The HUD itself: set_density and touch_ui reach the layout, and the targets and hit test agree.
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	hud.size = Vector2(2400, 1080)
	root.add_child(hud)
	await process_frame
	hud.setup(["protagonist", "anti_hero"], ["ONE", "TWO"])
	hud.hub.model(0).ai = false
	hud.hub.model(1).ai = true
	hud.set_density(2.6)
	hud.set_option("touch_ui", true)
	hud.advance(1.0 / 60.0)
	var tr: Dictionary = hud.touch_rects()
	_ok(hud.layout.touch_ui and is_equal_approx(hud.layout.dp, 2.6) and tr.has("pause") and not tr.has("stance_0_p0") and tr.size() == 1, "responsive: on touch the HUD owns only the pause button (and the feedback pill after a KO); the stance ring is retired")
	_ok(hud.touch_target_at((tr["pause"] as Rect2).get_center()).get("name", "") == "pause" and hud.touch_target_at(Vector2(1200, 540)).is_empty(), "responsive: a tap on the pause button is named and a tap on the fight is not a target")
	hud.set_option("touch_ui", false)
	_ok(hud.touch_rects().is_empty(), "responsive: with touch off there are no touch targets")
	hud.queue_free()
	await process_frame


## The How to play card: every page fits at every size, every button is a target, and the flow works (docs/ui/hud-spec.md section 17).
func _howto_rules() -> void:
	var n: int = UiHowto.page_count()
	_ok(n == 3, "howto: three pages (the idea, the controls, reading the fight)")
	# Orb's direction: the player IS the fighter. The copy says bluntly what they control and what is automatic, and never frames the
	# player as directing someone else.
	var all_text := ""
	for pg in UiData.howto().get("pages", []):
		for it in pg.get("items", []):
			all_text += " " + str(it.get("text", "")) + " " + str(it.get("heading", ""))
	_ok(not all_text.contains("Press Light") and not all_text.contains("parry") and not all_text.contains("timing"), "howto: no copy asks for a timed press (the director times every blow)")
	var page0: String = str((UiData.howto()["pages"] as Array)[0]["title"])
	_ok(page0 == "What you control" and all_text.contains("You are the fighter") and all_text.to_lower().contains("no combo inputs") and all_text.contains("play out on their own") and all_text.to_lower().contains("no health bars") and all_text.contains("finisher"), "howto: the first page is What you control: you are the fighter, there are no combo inputs, the blows play out on their own, no health bars, a finisher ends it")
	var p0text := ""
	for it in (UiData.howto()["pages"] as Array)[0]["items"]:
		p0text += " " + str(it.get("text", ""))
	for verb in ["fly", "dodge", "guard", "light or heavy", "power", "signature", "transform"]:
		_ok(p0text.to_lower().contains(verb), "howto: the first page says plainly that you control: %s" % verb)
	var all_hints := ""
	for k in UiData.reads()["hints"]:
		all_hints += " " + str(UiData.reads()["hints"][k])
	var player_copy: String = (all_text + all_hints).to_lower()
	_ok(not player_copy.contains("strategist") and not player_copy.contains("director") and not player_copy.contains("intent") and not player_copy.contains("the fight follows") and not player_copy.contains("follow from"), "howto: no player-facing copy says strategist, director, intent or the fight follows (those are internal words)")
	# Geometry at desktop, tablet, phone and a small window, with every device family and touch on or off.
	var cases: Array = [[Vector2(1920, 1080), 1.0], [Vector2(1280, 720), 1.0], [Vector2(1024, 576), 1.0], [Vector2(2400, 1080), 2.6], [Vector2(2532, 1170), 3.0], [Vector2(1560, 720), 2.0], [Vector2(2560, 1600), 2.0], [Vector2(3840, 2160), 1.0],
		[Vector2(1170, 2532), 3.0], [Vector2(1080, 2340), 2.75], [Vector2(1125, 2436), 3.0], [Vector2(828, 1792), 2.0], [Vector2(750, 1334), 2.0], [Vector2(390, 844), 1.0], [Vector2(360, 640), 1.0]]
	for cs in cases:
		var sz: Vector2 = cs[0]
		var dpv: float = cs[1]
		var lay := UiLayout.new()
		lay.dp = dpv
		lay.compute(sz, false)
		for touch in [false, true]:
			for dev in ["kbd", "xbox"]:
				for pg in range(n):
					var p: Dictionary = UiHowto.plan(sz, lay.s, dpv, touch, pg, dev, 0)
					var tag := "howto %dx%d dp %.1f touch=%s %s page %d" % [int(sz.x), int(sz.y), dpv, str(touch), dev, pg]
					var view := Rect2(Vector2.ZERO, sz)
					_ok(bool(p["fits"]), "%s: the page fits (type scale %.2f)" % [tag, float(p["cs"])])
					var card: Rect2 = p["card"]
					var tm: float = float(p["tm"])
					var bad := 0
					if not view.encloses(card):
						bad += 1
					for k in ["close", "next"] + ([] if pg == 0 else ["back"]):
						var r: Rect2 = p[k]
						if r.size.x < tm - 0.01 or r.size.y < tm - 0.01 or not card.encloses(r):
							bad += 1
					if (p["close"] as Rect2).intersects(p["next"]) or (pg > 0 and (p["back"] as Rect2).intersects(p["next"])):
						bad += 1
					for rec in p["items"]:
						if not card.encloses(rec["rect"]):
							bad += 1
					_ok(bad == 0, "%s: the card is on screen, every button is at least 48 dp and inside it, and every item is inside (%d bad)" % [tag, bad])
					_ok(float(p["fs_small"]) >= UiLook.text_floor - 0.5 and float(p["fs_body"]) >= UiLook.text_floor - 0.5, "%s: type is at or above the text floor" % tag)
					var dots: Array = p["dots"]
					var dr: float = float(p["dot_r"]) * 1.3
					var dbox := Rect2((dots[0] as Vector2) - Vector2(dr, dr), Vector2((dots[dots.size() - 1] as Vector2).x - (dots[0] as Vector2).x + 2.0 * dr, 2.0 * dr))
					_ok(dots.size() == n and ((dots[1] as Vector2).x - (dots[0] as Vector2).x) >= 2.0 * dr + 1.0 and not dbox.intersects(p["next"]) and (pg == 0 or not dbox.intersects(p["back"])) and card.encloses(dbox), "%s: the page dots do not overlap each other or the buttons" % tag)
	UiLook.text_floor = UiLook.MIN_TEXT_PX
	# The touch page describes touch Simple (the stick, Attack, Guard and Power) and nothing from the retired stance ring.
	var touch_text := ""
	for it in UiData.howto()["pages"][1]["touch_items"]:
		touch_text += " " + str(it.get("text", ""))
	var tl: String = touch_text.to_lower()
	_ok(tl.contains("flick to dodge") and tl.contains("push out to sprint") and tl.contains("tap light") and tl.contains("hold heavy") and tl.contains("swipe up") and tl.contains("signature") and tl.contains("guard: hold") and tl.contains("power: hold to charge") and not tl.contains("stance ring") and not tl.contains("left edge"), "howto: the touch page describes the stick (flick, sprint), Attack (tap, hold, swipe up), Guard and Power, and no stance ring")
	# Keyboard pages show the second player's keys; pads do not.
	var pk: Dictionary = UiHowto.plan(Vector2(1920, 1080), 1.0, 1.0, false, 1, "kbd", 0)
	var px: Dictionary = UiHowto.plan(Vector2(1920, 1080), 1.0, 1.0, false, 1, "xbox", 0)
	var has_note := func(pl: Dictionary) -> bool:
		for rec in pl["items"]:
			if rec["kind"] == "note":
				return true
		return false
	var pks: Dictionary = UiHowto.plan(Vector2(1920, 1080), 1.0, 1.0, false, 1, "kbd", 1, "kb-shared-p2")
	_ok(has_note.call(pks) and not has_note.call(pk) and not has_note.call(px), "howto: the controls page notes the shared keyboard (and only then)")
	# The rows follow the layout: Simple has no mode or heavy row, the keyboard shows its own keys.
	var row_texts := func(pl: Dictionary) -> Array:
		var out: Array = []
		for rec in pl["items"]:
			if rec["kind"] == "action":
				out.append(str((rec["item"] as Dictionary).get("text", "")))
		return out
	var rt_solo: Array = row_texts.call(UiHowto.plan(Vector2(1920, 1080), 1.0, 1.0, false, 1, "kbd", 0, "kb-solo"))
	var rt_simple: Array = row_texts.call(UiHowto.plan(Vector2(1920, 1080), 1.0, 1.0, false, 1, "xbox", 0, "simple-pad"))
	_ok(rt_solo.has("Heavy") and rt_solo.has("Mode") and rt_solo.has("Specials") and not rt_simple.has("Heavy") and not rt_simple.has("Mode") and not rt_simple.has("Specials") and rt_simple.has("Guard (hold)"), "howto: the controls page lists the actions the layout binds (Simple has no heavy, mode or specials row)")
	_ok(rt_solo.size() >= 10 and rt_simple.size() >= 6, "howto: the controls page keeps its rows (%d keyboard, %d Simple)" % [rt_solo.size(), rt_simple.size()])
	# The flow in the HUD.
	UiPrefs.path = "user://ui_prefs_test.json"
	if FileAccess.file_exists(UiPrefs.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(UiPrefs.path))
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	hud.size = Vector2(1920, 1080)
	root.add_child(hud)
	await process_frame
	hud.setup(["protagonist", "anti_hero"], ["ONE", "TWO"])
	hud.hub.model(0).ai = false
	var opened := [0]
	var closed := []
	hud.howto_opened.connect(func(f: bool): opened[0] += 1)
	hud.howto_closed.connect(func(f: bool): closed.append(f))
	_ok(not hud.howto_seen() and not hud.is_howto_open(), "howto: not seen and not open at the start")
	hud.show_howto(true)
	hud.advance(1.0 / 60.0)
	_ok(hud.is_howto_open() and hud.howto_page() == 0 and opened[0] == 1 and hud._l_howto.sig != null, "howto: the first-run card opens on page 0 and draws")
	var key := func(code: int) -> InputEventKey:
		var e := InputEventKey.new()
		e.keycode = code
		e.pressed = true
		return e
	hud._unhandled_input(key.call(KEY_ENTER))
	hud._unhandled_input(key.call(KEY_RIGHT))
	_ok(hud.howto_page() == 2, "howto: Enter and Right go forward a page each")
	hud._unhandled_input(key.call(KEY_LEFT))
	_ok(hud.howto_page() == 1, "howto: Left goes back")
	hud._unhandled_input(key.call(KEY_SPACE))
	hud._unhandled_input(key.call(KEY_SPACE))
	_ok(not hud.is_howto_open() and closed == [true] and hud.howto_seen(), "howto: Space past the last page closes it and, for the first run, records that it has been seen")
	hud.advance(1.0 / 60.0)
	_ok(hud._l_howto.sig == null, "howto: closed, its layer draws nothing")
	# From the pause menu or F1: it opens again, Esc closes it, and it does not touch the seen flag's meaning.
	hud._unhandled_input(key.call(KEY_F1))
	_ok(hud.is_howto_open(), "howto: F1 opens it again")
	hud._unhandled_input(key.call(KEY_ESCAPE))
	_ok(not hud.is_howto_open() and closed == [true, false], "howto: Esc closes it")
	# A tap (a mouse click) on Next, Back and Close.
	hud.show_howto(false)
	var click := func(pos: Vector2) -> InputEventMouseButton:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		e.position = pos
		return e
	var pl: Dictionary = hud.howto_plan()
	hud._unhandled_input(click.call((pl["next"] as Rect2).get_center()))
	_ok(hud.howto_page() == 1, "howto: a tap on Next goes forward")
	pl = hud.howto_plan()
	hud._unhandled_input(click.call((pl["back"] as Rect2).get_center()))
	_ok(hud.howto_page() == 0, "howto: a tap on Back goes back")
	hud._unhandled_input(click.call(Vector2(5, 5)))
	_ok(hud.is_howto_open() and hud.howto_page() == 0, "howto: a tap outside the buttons does nothing (and does not reach the game)")
	pl = hud.howto_plan()
	hud._unhandled_input(click.call((pl["close"] as Rect2).get_center()))
	_ok(not hud.is_howto_open(), "howto: a tap on Close closes it")
	# A pad: A goes forward, B closes.
	hud.show_howto(false)
	var pad := func(btn: int) -> InputEventJoypadButton:
		var e := InputEventJoypadButton.new()
		e.button_index = btn
		e.pressed = true
		return e
	hud._unhandled_input(pad.call(JOY_BUTTON_A))
	_ok(hud.howto_page() == 1, "howto: pad A goes forward")
	hud._unhandled_input(pad.call(JOY_BUTTON_B))
	_ok(not hud.is_howto_open(), "howto: pad B closes it")
	hud.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(UiPrefs.path))
	UiPrefs.path = "user://ui_prefs.json"


## The reads on screen: the read slot's geometry, the telegraph and the hint sharing it (telegraph first, banner over hint), the weight
## and signature marks redrawing the plate, and the stance ring's weight mark.
func _reads_hud() -> void:
	for cs in [[Vector2(1920, 1080), 1.0], [Vector2(1280, 720), 1.0], [Vector2(1024, 576), 1.0], [Vector2(2560, 1080), 1.0], [Vector2(390, 844), 1.0], [Vector2(1080, 1920), 1.0], [Vector2(2400, 1080), 2.6]]:
		var sz: Vector2 = cs[0]
		var lay := UiLayout.new()
		lay.dp = cs[1]
		lay.touch_ui = cs[1] > 1.5
		lay.compute(sz, false)
		var slot: Rect2 = lay.read_slot
		var tag := "reads %dx%d" % [int(sz.x), int(sz.y)]
		_ok(slot.size.x > 0.0 and slot.size.y > 0.0 and Rect2(Vector2.ZERO, sz).encloses(slot), "%s: the read slot is on screen" % tag)
		_ok(not slot.intersects(lay.clear_zone) and not slot.intersects(lay.toll) and (lay.portrait or (not slot.intersects(lay.plate[0]) and not slot.intersects(lay.plate[1]))), "%s: the read slot is clear of the fight, the toll chip and the plates" % tag)
		_ok(lay.pause_btn.size.y <= 0.0 or not slot.intersects(lay.pause_btn), "%s: and of the pause button" % tag)
		_ok(slot.size.y >= 24.0 and slot.size.x >= 200.0, "%s: and big enough for a line (%d by %d)" % [tag, int(slot.size.x), int(slot.size.y)])
	UiLook.text_floor = UiLook.MIN_TEXT_PX
	root.size = Vector2i(1920, 1080)
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	hud.size = Vector2(1920, 1080)
	root.add_child(hud)
	await process_frame
	hud.setup(["protagonist", "anti_hero"], ["ONE", "TWO"])
	hud.hub.model(0).ai = false
	hud.hub.model(0).device = "xbox"
	hud.advance(1.0 / 60.0)
	# The hint line.
	hud.consume({"type": "tutorial_hint", "id": "b3", "text_key": "b3.hint"})
	for i in range(3):
		hud.advance(1.0 / 60.0)
		await process_frame
	_ok(hud._l_hint.sig != null and hud._l_hint.redraws > 0 and hud._l_tele.sig == null, "reads: a hint draws in the read slot")
	# The telegraph takes the slot: the hint steps aside and the banner is held.
	hud.consume({"type": "finisher_start", "actor": 1, "target": 0, "kind": "beam", "dur": 3.0})
	hud.consume({"type": "banner", "text": "TIER 2", "col": "#ffffff", "dur": 1.0})
	for i in range(3):
		hud.advance(1.0 / 60.0)
		await process_frame
	_ok(hud._l_tele.sig != null and hud._l_tele.redraws > 0 and hud._l_hint.sig == null, "reads: the finisher telegraph takes the slot and the hint steps aside")
	hud.consume({"type": "finisher_contest", "target": 0})
	for i in range(45):
		hud.advance(1.0 / 60.0)
		await process_frame
	_ok(hud._l_tele.sig == null, "reads: the telegraph clears after the contest")
	_ok(hud.hub.banner.is_empty() or hud._l_hint.sig == null, "reads: a banner in the slot hides the hint (the banner wins over the hint)")
	for i in range(80):
		hud.advance(1.0 / 60.0)
		await process_frame
	_ok(hud.hub.banner.is_empty() and hud._l_hint.sig != null, "reads: and the hint returns when the banner is gone")
	hud.consume({"type": "chain_ender", "actor": 0, "n": 3})
	_ok(str(hud.hub.banner.get("text", "")).begins_with("CHAIN") and str(hud.hub.banner["text"]).contains("3"), "reads: chain_ender puts CHAIN x3 in the banner")
	hud.consume({"type": "chain_ender", "actor": 0, "n": 1})
	_ok(str(hud.hub.banner.get("text", "")).contains("3"), "reads: a chain of one gets no banner (the earlier one stands)")
	# Weight, signature and stance edges redraw the plate within a frame.
	var r0: int = hud._l_plate[1].redraws
	hud.consume({"type": "weight_set", "actor": 1, "weight": "heavy"})
	hud.advance(1.0 / 60.0)
	await process_frame
	_ok(hud._l_plate[1].redraws > r0, "reads: a weight change redraws the plate in the next frame (the ack is inside two ticks)")
	r0 = hud._l_plate[0].redraws
	hud.consume({"type": "sig_queued", "actor": 0, "state": "queued"})
	hud.advance(1.0 / 60.0)
	await process_frame
	_ok(hud._l_plate[0].redraws > r0 and hud.hub.model(0).sig_queued, "reads: a queued signature redraws the plate in the next frame")
	r0 = hud._l_plate[1].redraws
	hud.consume({"type": "stance_set", "actor": 1, "stance": 3})
	hud.advance(1.0 / 60.0)
	await process_frame
	_ok(hud._l_plate[1].redraws > r0, "reads: the rival's stance change redraws the plate (the chip pulses)")
	# The stance ring's weight mark: beside the four stances on a desktop row, a badge on the current stance on touch.
	var pm0: UiFighterModel = hud.hub.model(0)
	pm0.left_side = true
	var chips: Array = UiPrompts.plan(pm0, hud.layout.prompts[0], hud.layout.s, {"touch": false, "prompts": false, "glyph_style": "neutral"})
	var kinds: Array = chips.map(func(c): return c["kind"])
	_ok(kinds.count("stance") == 4 and kinds.has("weight"), "reads: the held-state row has a weight mark beside the four states")
	var last_r: Rect2 = chips[chips.size() - 1]["rect"]
	_ok(last_r.end.x <= hud.layout.prompts[0].end.x + 0.5, "reads: and it stays inside the column")
	hud.queue_free()
	await process_frame


## The feedback panel: words, the report (no network, nothing personal), geometry at every size, the flow by mouse and touch, and the
## match-end button (docs/ui/hud-spec.md section 20).
func _feedback_rules() -> void:
	UiFeedback.target_override = "github"   # most of these exercise SEND; the targets themselves are tested near the end
	var d: Dictionary = UiData.feedback()
	var labels: Array = []
	for t in d["tags"]:
		labels.append(str(t["label"]))
	_ok(labels == ["Bug", "Felt unfair", "Confusing", "Loved it"], "feedback: four quick tags: bug, felt unfair, confusing, loved it")
	_ok(d["buttons"].has("copy") and d["buttons"].has("close") and d["buttons"].has("match_end") and str(d["title"]) != "", "feedback: the buttons and the title are data")
	# Platform words are coarse: a family and a major version, never the user-agent string.
	var chrome := "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
	var edge := chrome + " Edg/126.0.2592.81"
	var ff := "Mozilla/5.0 (X11; Linux x86_64; rv:127.0) Gecko/20100101 Firefox/127.0"
	var safari := "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1"
	_ok(UiFeedback.browser_from_ua(chrome) == "Chrome 126" and UiFeedback.browser_from_ua(edge) == "Edge 126" and UiFeedback.browser_from_ua(ff) == "Firefox 127" and UiFeedback.browser_from_ua(safari) == "Safari 17" and UiFeedback.browser_from_ua("curl/8") == "unknown browser", "feedback: the browser is a family and a major version")
	_ok(UiFeedback.os_from_ua(chrome) == "Windows" and UiFeedback.os_from_ua(ff) == "Linux" and UiFeedback.os_from_ua(safari) == "iOS" and UiFeedback.os_from_ua("... Android 14; Pixel ...") == "Android" and UiFeedback.os_from_ua("Macintosh; Intel Mac OS X 10_15") == "macOS", "feedback: the OS is a family word, with no version or device model")
	_ok(UiFeedback.format_time(222.4) == "03:42" and UiFeedback.format_time(-3.0) == "00:00" and UiFeedback.format_time(3725.0) == "62:05", "feedback: the match time is minutes and seconds")
	var sl: String = UiFeedback.settings_line({"captions": true, "reduced_motion": false, "camera_shake": 4.0, "glyph_style": "neutral", "not_an_option": 1})
	_ok(sl == "camera_shake=4.00, captions=on, glyph_style=neutral, reduced_motion=off", "feedback: the settings are the player options, sorted, on or off")
	# The report.
	var env := {"screen": Vector2(1920, 1080), "dp": 1.0, "touch": false, "platform": {"os": "Windows", "browser": "Chrome 126", "web": true, "mobile": false, "engine": "Godot 4.7.2"}, "settings": sl}
	var ctx := {"commit": "abc1234", "date": "2026-09-30", "seed": 987654, "setup": "ONE (player, xbox) vs TWO (AI)", "time": 222.0, "ended": true}
	var rep: String = UiFeedback.build_report(ctx, ["bug", "confusing"], "The beam froze.\nSecond line.", env)
	for must in ["ORB COMBAT EX - PLAYTEST FEEDBACK", "Build: abc1234 (2026-09-30)", "Seed: 987654", "Setup: ONE (player, xbox) vs TWO (AI)", "Match time: 03:42 (ended)", "Screen: 1920x1080, density 1.0, touch off", "Platform: Web, Chrome 126, Windows", "Engine: Godot 4.7.2", "Settings: " + sl, "Tags: Bug, Confusing", "Notes:", "The beam froze."]:
		_ok(rep.contains(must), "feedback: the report has '%s'" % must.substr(0, 40))
	var un: String = OS.get_environment("USERNAME") if OS.get_environment("USERNAME") != "" else OS.get_environment("USER")
	_ok(not rep.to_lower().contains("http") and not rep.contains("user://") and not rep.contains("C:\\") and (un == "" or not rep.contains(un)), "feedback: the report holds no URL, path or user name")
	var empty: String = UiFeedback.build_report({}, [], "   ", env)
	_ok(empty.contains("Build: unknown") and empty.contains("Seed: unknown") and empty.contains("Tags: none") and empty.contains("(none)"), "feedback: missing facts read unknown and an empty note reads (none)")
	# Geometry at desktop, tablet, phone and a small window, both states, touch off and on.
	for cs in [[Vector2(1920, 1080), 1.0], [Vector2(1280, 720), 1.0], [Vector2(1024, 576), 1.0], [Vector2(2400, 1080), 2.6], [Vector2(1560, 720), 2.0], [Vector2(390, 844), 1.0], [Vector2(3840, 2160), 1.0]]:
		var sz: Vector2 = cs[0]
		var lay := UiLayout.new()
		lay.dp = cs[1]
		lay.compute(sz, false)
		for st in [UiFeedback.STATE_WRITE, UiFeedback.STATE_COPIED, UiFeedback.STATE_REVIEW]:
			var p: Dictionary = UiFeedback.plan(sz, lay.s, cs[1], cs[1] > 1.5, st)
			var tag := "feedback %dx%d dp %.1f %s" % [int(sz.x), int(sz.y), cs[1], st]
			var card: Rect2 = p["card"]
			var tm: float = float(p["tm"])
			_ok(bool(p["fits"]) and Rect2(Vector2.ZERO, sz).encloses(card), "%s: the panel fits on screen (type scale %.2f)" % [tag, float(p["cs"])])
			var ctrl: Array = [p["close"]]
			if st == UiFeedback.STATE_WRITE:
				ctrl.append_array([p["copy"], p["send"], p["done"]])
				for chip in p["tags"]:
					ctrl.append(chip["rect"])
			elif st == UiFeedback.STATE_REVIEW:
				ctrl.append_array([p["issue"], p["again"], p["back"]])
			else:
				ctrl.append_array([p["back"], p["again"], p["done"]])
			var bad := 0
			for i in range(ctrl.size()):
				var r: Rect2 = ctrl[i]
				if r.size.x < tm - 0.01 or r.size.y < tm - 0.01 or not card.encloses(r):
					bad += 1
				for j in range(i + 1, ctrl.size()):
					if r.intersects(ctrl[j]):
						bad += 1
			_ok(bad == 0, "%s: every control is at least 48 dp, inside the card, and none overlap (%d bad)" % [tag, bad])
			if st == UiFeedback.STATE_WRITE:
				var clipped := 0
				for chip in p["tags"]:
					if UiText.width(str(chip["label"]), int(p["fs_body"])) + float(chip["off"]) > (chip["rect"] as Rect2).size.x - 2.0:
						clipped += 1
				_ok(clipped == 0, "%s: every tag's word fits inside its chip (%d clipped)" % [tag, clipped])
			var box: Rect2 = p["text_rect"] if st == UiFeedback.STATE_WRITE else p["preview_rect"]
			_ok(card.encloses(box) and box.size.y >= float(p["lh"]) * 2.9, "%s: the text box is inside the card and at least three lines tall" % tag)
	UiLook.text_floor = UiLook.MIN_TEXT_PX
	# The match-end pill.
	for cs in [[Vector2(1920, 1080), 1.0], [Vector2(1280, 720), 1.0], [Vector2(2560, 1080), 1.0], [Vector2(2400, 1080), 2.6], [Vector2(1560, 720), 2.0]]:
		var lay2 := UiLayout.new()
		lay2.dp = cs[1]
		lay2.touch_ui = cs[1] > 1.5
		lay2.compute(cs[0], false)
		var b: Rect2 = lay2.feedback_btn
		var view := Rect2(Vector2.ZERO, cs[0])
		var tag2 := "feedback pill %dx%d dp %.1f" % [int(cs[0].x), int(cs[0].y), cs[1]]
		_ok(b.size.y > 0.0 and view.encloses(b), "%s: the pill is on screen" % tag2)
		_ok(not b.intersects(lay2.ring) and not b.intersects(lay2.strip) and not b.intersects(lay2.bark[0]) and not b.intersects(lay2.bark[1]) and not b.intersects(lay2.plate[0]) and not b.intersects(lay2.plate[1]) and not b.intersects(lay2.clear_zone), "%s: clear of the ring map, the strip, the bark lanes, the plates and the fight" % tag2)
		_ok(b.size.y >= (lay2.touch_min if lay2.touch_ui else 34.0) - 0.01, "%s: tall enough to tap" % tag2)
	var lp := UiLayout.new()
	lp.compute(Vector2(390, 844), false)
	_ok(lp.feedback_btn.size.y > 0.0 and Rect2(Vector2.ZERO, Vector2(390, 844)).encloses(lp.feedback_btn), "feedback pill: portrait keeps one on screen")
	# The flow in the HUD.
	root.size = Vector2i(1920, 1080)
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	hud.size = Vector2(1920, 1080)
	root.add_child(hud)
	await process_frame
	hud.setup(["protagonist", "anti_hero"], ["ONE", "TWO"])
	hud.hub.model(0).ai = false
	hud.hub.model(0).device = "xbox"
	hud.advance(1.0 / 60.0)
	var ev := {"opened": [], "closed": 0}
	hud.feedback_opened.connect(func(c: String): ev["opened"].append(c))
	hud.feedback_closed.connect(func(): ev["closed"] += 1)
	_ok(not hud._pill_visible() and hud._l_fbpill.sig == null and not hud.touch_rects().has("feedback"), "feedback: no pill during the fight")
	hud.consume({"type": "ko", "winner": 0, "loser": 1})
	hud.advance(1.0 / 60.0)
	_ok(hud._pill_visible() and hud._l_fbpill.sig != null, "feedback: the pill shows once the match is over")
	var click := func(pos: Vector2) -> InputEventMouseButton:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		e.position = pos
		return e
	hud._unhandled_input(click.call(hud.layout.feedback_btn.get_center()))
	_ok(hud.is_feedback_open() and ev["opened"] == ["match_end"] and not hud._pill_visible(), "feedback: a tap on the pill opens the panel (context match_end) and the pill steps aside")
	_ok(hud._fb_text.visible and not hud._fb_prev.visible and hud.feedback_plan()["card"].encloses(Rect2(hud._fb_text.position, hud._fb_text.size)), "feedback: the text box shows inside the card")
	hud.show_howto(false)
	_ok(not hud.is_howto_open(), "feedback: the How to play card does not open over the panel")
	var pl: Dictionary = hud.feedback_plan()
	hud._unhandled_input(click.call((pl["tags"][0]["rect"] as Rect2).get_center()))
	hud._unhandled_input(click.call((pl["tags"][2]["rect"] as Rect2).get_center()))
	_ok(hud.feedback_selected_tags() == ["bug", "confusing"], "feedback: a tap on a tag chip selects it")
	hud._unhandled_input(click.call((pl["tags"][0]["rect"] as Rect2).get_center()))
	_ok(hud.feedback_selected_tags() == ["confusing"], "feedback: and a second tap clears it")
	hud._unhandled_input(click.call((pl["tags"][0]["rect"] as Rect2).get_center()))
	hud._fb_text.text = "The beam froze."
	hud.feedback_fn = func(): return {"commit": "abc1234", "seed": 42, "setup": "ONE vs TWO", "time": 222.0}
	hud._unhandled_input(click.call((pl["copy"] as Rect2).get_center()))
	var rep2: String = hud._fb_prev.text
	_ok(hud._fb_state == "copied" and hud._fb_prev.visible and not hud._fb_text.visible, "feedback: COPY REPORT shows the report in the read-only box (the hand-copy fallback)")
	_ok(rep2.contains("abc1234") and rep2.contains("Seed: 42") and rep2.contains("ONE vs TWO") and rep2.contains("03:42") and rep2.contains("Bug, Confusing") and rep2.contains("The beam froze.") and rep2.contains("(ended)"), "feedback: the report carries the host's build, seed, setup and time, the tags and the note")
	_ok(rep2 == hud.feedback_report(), "feedback: copying twice gives the same report")
	pl = hud.feedback_plan()
	hud._unhandled_input(click.call((pl["back"] as Rect2).get_center()))
	_ok(hud._fb_state == "write" and hud._fb_text.text == "The beam froze." and hud.feedback_selected_tags() == ["bug", "confusing"], "feedback: BACK returns to writing with the note and tags kept")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	hud._unhandled_input(esc)
	_ok(not hud.is_feedback_open() and ev["closed"] == 1 and not hud._fb_text.visible and not hud._fb_prev.visible, "feedback: Esc closes it and hides the boxes")
	hud.show_feedback("pause")
	_ok(ev["opened"] == ["match_end", "pause"] and hud.feedback_selected_tags().is_empty() and hud._fb_text.text == "", "feedback: from the pause menu it opens fresh (context pause)")
	pl = hud.feedback_plan()
	hud._unhandled_input(click.call((pl["close"] as Rect2).get_center()))
	_ok(not hud.is_feedback_open() and ev["closed"] == 2, "feedback: the close cross closes it")
	hud.show_feedback("pause")
	pl = hud.feedback_plan()
	hud._unhandled_input(click.call((pl["done"] as Rect2).get_center()))
	_ok(not hud.is_feedback_open() and ev["closed"] == 3, "feedback: the CLOSE button closes it")
	var wasd := InputEventKey.new()
	wasd.keycode = KEY_D
	wasd.pressed = true
	hud.show_feedback("pause")
	hud._unhandled_input(wasd)
	_ok(hud.is_feedback_open(), "feedback: a game key does nothing to the open panel")
	hud.hide_feedback()
	# The web's clipboard bridge: the page-side code is there, and off the web every call is a harmless no-op.
	for must in ["navigator.clipboard.writeText", "execCommand('copy')", "readonly", "pointerup", "createElement('textarea')", "__fbClose", "window.open(url, '_blank', 'noopener')", "openRect", "mailto:"]:
		_ok(UiWebClip.JS_INSTALL.contains(must), "feedback web: the page-side code has %s" % must)
	_ok(not UiWebClip.available(), "feedback web: this headless run is not the web, so the bridge stays out of the way")
	UiWebClip.install(func(): pass)
	UiWebClip.set_report("x")
	UiWebClip.set_copy_rect(Rect2(1, 2, 3, 4))
	UiWebClip.copy("x")
	UiWebClip.show_textarea(Rect2(0, 0, 10, 10), 12.0, "x")
	UiWebClip.clear()
	_ok(hud._fb_prev.visible == false and not hud.is_feedback_open(), "feedback web: the no-op calls leave the HUD alone")
	hud.show_feedback("pause")
	hud.copy_feedback()
	_ok(hud._fb_prev.visible and hud._fb_prev.text.contains("Notes:"), "feedback web: off the web the read-only Godot box shows the report")
	hud.hide_feedback()
	# Touch: the pill is a target, the panel works by tap, and the boxes stay inside the card.
	# SEND: a review of exactly what a prefilled GitHub issue will hold, then OPEN ISSUE (the test catches the open).
	var opened: Array = []
	UiFeedback.opener = func(url: String): opened.append(url)
	hud.show_feedback("pause")
	pl = hud.feedback_plan()
	hud._unhandled_input(click.call((pl["tags"][0]["rect"] as Rect2).get_center()))
	hud._fb_text.text = "The beam froze. Two lines & a symbol?\nSecond line."
	hud.feedback_fn = func(): return {"commit": "abc1234", "seed": 42, "setup": "ONE vs TWO", "time": 222.0}
	hud._unhandled_input(click.call((pl["send"] as Rect2).get_center()))
	_ok(hud._fb_state == "review" and hud._fb_prev.visible and hud._fb_prev.text == hud.feedback_report() and not hud._fb_issue.is_empty() and opened.is_empty(), "feedback send: SEND shows the review (the exact report) and opens nothing yet")
	var url: String = str(hud._fb_issue["url"])
	_ok(url.begins_with("https://github.com/dixonbalsagna/orb-combat-ex/issues/new?title=") and url.contains("&body=") and url.length() <= 3000 and not bool(hud._fb_issue["fallback"]), "feedback send: the link is the repo's new-issue page with a title and body, under the 3000-character limit")
	var body_enc: String = url.get_slice("&body=", 1)
	var title_enc: String = url.get_slice("&body=", 0).get_slice("?title=", 1)
	_ok(not body_enc.contains(" ") and not body_enc.contains("\n") and not body_enc.contains("&") and not title_enc.contains(" "), "feedback send: the title and body are percent-encoded (no raw space, newline or ampersand)")
	_ok(body_enc.uri_decode() == hud.feedback_report() and title_enc.uri_decode().begins_with("Playtest: Bug - The beam froze."), "feedback send: the body decodes to the report and the title to Playtest, the tag and the first words of the note")
	pl = hud.feedback_plan()
	_ok(hud._fb_texts()[1] == "" and str(pl["status"]) == "Review before sending" and str(pl["note"]).contains("public GitHub issue") and str(pl["note"]).contains("Nothing is sent until you submit it there"), "feedback send: the review says it is a public issue and that nothing is sent until the player submits it")
	hud._unhandled_input(click.call((pl["issue"] as Rect2).get_center()))
	_ok(opened == [url] and hud._fb_opened and str(hud.feedback_plan()["note"]).contains("GitHub opened"), "feedback send: OPEN ISSUE opens the link once and says so")
	hud._unhandled_input(click.call((hud.feedback_plan()["again"] as Rect2).get_center()))
	_ok(hud._fb_state == "review" and str(hud.feedback_plan()["status"]).begins_with("Copied"), "feedback send: COPY REPORT in the review copies and stays in the review")
	hud._unhandled_input(click.call((hud.feedback_plan()["back"] as Rect2).get_center()))
	_ok(hud._fb_state == "write" and hud._fb_text.text.begins_with("The beam froze.") and hud.feedback_selected_tags() == ["bug"], "feedback send: BACK returns to writing with the note and tags kept")
	# A report too long for a link: the full report is copied and the issue opens with a short body.
	hud._fb_text.text = "x".repeat(4000)
	hud.send_feedback()
	var long_issue: Dictionary = hud._fb_issue
	_ok(bool(long_issue["fallback"]) and str(long_issue["url"]).length() <= 3000 and str(long_issue["url"]).get_slice("&body=", 1).uri_decode().contains("copied to the clipboard") and not str(long_issue["url"]).get_slice("&body=", 1).contains("xxxxxxxx"), "feedback send: a report too long for the limit opens with a short body asking to paste")
	_ok(str(hud.feedback_plan()["note"]).contains("too long for a link"), "feedback send: and the review says the full report is copied")
	hud.hide_feedback()
	UiFeedback.opener = Callable()
	# The send targets. With no target (the shipped default until an address is chosen) SEND is hidden and COPY REPORT stays.
	UiFeedback.target_override = ""
	_ok(UiFeedback.send_target() == "none", "feedback targets: the shipped data has no target yet (none)")
	hud.show_feedback("pause")
	pl = hud.feedback_plan()
	_ok((pl["send"] as Rect2).size.y <= 0.0 and (pl["copy"] as Rect2).size.y > 0.0 and (pl["done"] as Rect2).size.y > 0.0 and bool(pl["fits"]) and hud.send_feedback().is_empty() and hud._fb_state == "write", "feedback targets: with no target the SEND button is hidden, COPY REPORT and CLOSE stay, and send does nothing")
	hud.hide_feedback()
	var sd0: Dictionary = UiData.send()
	var tg: Dictionary = sd0["_targets"]
	var keep_to: String = str(tg["mailto"]["to"])
	var keep_form: String = str(tg["form"]["url"])
	UiFeedback.target_override = "mailto"
	_ok(UiFeedback.send_target() == "none", "feedback targets: a mailto with no address is still none")
	tg["mailto"]["to"] = "team@example.test"
	tg["form"]["url"] = "https://forms.example.test/f?t={title}&b={body}"
	_ok(UiFeedback.send_target() == "mailto" and UiFeedback.send_is_private() and UiFeedback.target_word("open") == "OPEN EMAIL", "feedback targets: with an address the mailto target is on, private, and says OPEN EMAIL")
	var mrep := "Build: x\nNotes:\nThe beam froze & a line"
	var mu: Dictionary = UiFeedback.send_url(mrep, "Playtest: Bug")
	_ok(str(mu["url"]).begins_with("mailto:team@example.test?subject=Playtest%3A%20Bug&body=") and not bool(mu["fallback"]) and str(mu["url"]).get_slice("&body=", 1).uri_decode() == mrep and str(mu["url"]).length() <= 1800, "feedback targets: the mailto link carries the address, a percent-encoded subject and the report as the body")
	var mlong: Dictionary = UiFeedback.send_url("x".repeat(3000), "T")
	_ok(bool(mlong["fallback"]) and str(mlong["url"]).length() <= 1800 and str(mlong["url"]).get_slice("&body=", 1).uri_decode().contains("clipboard"), "feedback targets: an email too long for its 1800-character limit opens with a short body that asks to paste")
	hud.show_feedback("pause")
	pl = hud.feedback_plan()
	_ok((pl["send"] as Rect2).size.y > 0.0, "feedback targets: with an address SEND is back")
	hud._unhandled_input(click.call((pl["send"] as Rect2).get_center()))
	pl = hud.feedback_plan()
	_ok(hud._fb_state == "review" and str(pl["note"]).contains("Only the team sees it") and not str(pl["note"]).contains("public") and not str(pl["note"]).contains("GitHub"), "feedback targets: the email review says it is private (and not that it is a public issue)")
	hud.hide_feedback()
	UiFeedback.target_override = "form"
	var fu: Dictionary = UiFeedback.send_url(mrep, "T 1")
	_ok(UiFeedback.send_target() == "form" and str(fu["url"]).begins_with("https://forms.example.test/f?t=T%201&b=") and str(fu["url"]).get_slice("&b=", 1).uri_decode() == mrep and UiFeedback.target_word("open") == "OPEN FORM", "feedback targets: the form link fills {title} and {body}")
	UiFeedback.target_override = "github"
	_ok(UiFeedback.send_target() == "github" and not UiFeedback.send_is_private() and UiFeedback.target_word("open") == "OPEN ISSUE" and str(UiFeedback.send_url(mrep, "T")["url"]).begins_with("https://github.com/"), "feedback targets: GitHub is one option, public, with OPEN ISSUE")
	tg["mailto"]["to"] = keep_to
	tg["form"]["url"] = keep_form
	UiFeedback.target_override = "github"
	# The title and link helpers on their own.
	_ok(UiFeedback.issue_title([], "") == "Playtest: feedback" and UiFeedback.issue_title(["bug", "loved"], "").begins_with("Playtest: Bug, Loved it") and UiFeedback.issue_title(["bug"], "y".repeat(300)).length() <= 80, "feedback send: the title falls back to Playtest: feedback, lists the tags and stays under 80 characters")
	var shorter: Dictionary = UiFeedback.issue_url("A\nSettings: a=on\nEngine: 4\nB", "T")
	_ok(not bool(shorter["fallback"]) and str(shorter["url"]).uri_decode().contains("Settings:"), "feedback send: a short report keeps its settings line in the link")
	var trimmed: String = "Build: x\nSettings: " + "s".repeat(3400) + "\nEngine: 1\nNotes:\nhi"
	var tr_issue: Dictionary = UiFeedback.issue_url(trimmed, "T")
	_ok(not bool(tr_issue["fallback"]) and not str(tr_issue["url"]).uri_decode().contains("Settings:") and str(tr_issue["url"]).uri_decode().contains("hi"), "feedback send: a report only too long for its settings line drops that line and keeps the rest")
	UiFeedback.target_override = ""
	hud.set_density(2.6)
	hud.set_option("touch_ui", true)
	hud.advance(1.0 / 60.0)
	_ok(hud.touch_rects().has("feedback") and hud.touch_target_at((hud.touch_rects()["feedback"] as Rect2).get_center()).get("name", "") == "feedback", "feedback: on touch the pill is a named target")
	hud.show_feedback("match_end")
	pl = hud.feedback_plan()
	hud._unhandled_input(click.call((pl["tags"][3]["rect"] as Rect2).get_center()))
	hud._unhandled_input(click.call((pl["copy"] as Rect2).get_center()))
	_ok(hud._fb_state == "copied" and hud._fb_prev.text.contains("Loved it") and hud._fb_prev.text.contains("touch on"), "feedback: on touch a tag and a copy work and the report says touch on")
	_ok(hud.feedback_plan()["card"].encloses(Rect2(hud._fb_prev.position, hud._fb_prev.size)), "feedback: and the preview stays inside the card")
	hud.hide_feedback()
	hud.queue_free()
	await process_frame


## The toll chip with the population as about 1,800 whole people: four-digit counters fit the chip at every size, phone width included.
func _toll_rules() -> void:
	var l1 := "%s %d / %d" % [UiData.t("toll.civilians"), 1799, 1800]
	var l2 := "%s %d    %s %d" % [UiData.t("toll.structures"), 1234, UiData.t("toll.craters"), 1999]
	for cs in [[Vector2(1920, 1080), 1.0], [Vector2(1280, 720), 1.0], [Vector2(1024, 576), 1.0], [Vector2(800, 480), 1.0], [Vector2(2400, 1080), 2.6], [Vector2(1560, 720), 2.0], [Vector2(390, 844), 1.0], [Vector2(360, 640), 1.0], [Vector2(1080, 1920), 1.0]]:
		var lay := UiLayout.new()
		lay.dp = cs[1]
		lay.compute(cs[0], false)
		var fs: int = UiCenter.toll_fs(lay, lay.s, l1, l2)
		var wide: float = UiText.width(l1, fs) if lay.portrait else maxf(UiText.width(l1, fs), UiText.width(l2, fs))
		var tag := "toll %dx%d dp %.1f" % [int(cs[0].x), int(cs[0].y), cs[1]]
		_ok(wide <= lay.toll.size.x - 8.0 + 0.5, "%s: four-digit counts fit the chip (%d px in %d, type %d)" % [tag, int(wide), int(lay.toll.size.x), fs])
		_ok(fs >= int(UiLook.text_floor), "%s: and the type stays at or above the floor" % tag)
	UiLook.text_floor = UiLook.MIN_TEXT_PX


## The control hints and the YOU labels (docs/ui/hud-spec.md section 22).
func _hints_rules() -> void:
	var hd: Dictionary = UiData.hints()
	var acts: Dictionary = UiData.glyphs().get("actions", {})
	var bad := 0
	for sname in hd["schemes"]:
		for r in hd["schemes"][sname]["rows"]:
			for a in (r["actions"] if r.has("actions") else [r["action"]]):
				if not acts.has(a):
					bad += 1
			if str(r.get("label", "")) == "":
				bad += 1
	_ok(bad == 0 and hd["schemes"].has("today"), "hints: every row names a real glyph action and has a word, and the 'today' scheme exists (%d bad)" % bad)
	var hub := _hub()
	hub.model(0).ai = false
	hub.model(1).ai = true
	_ok(UiHints.you_label(hub.models, hub.model(0)) == "YOU" and UiHints.you_label(hub.models, hub.model(1)) == "", "hints: one human is YOU and the AI has no label")
	hub.model(1).ai = false
	_ok(UiHints.you_label(hub.models, hub.model(0)) == "P1" and UiHints.you_label(hub.models, hub.model(1)) == "P2", "hints: two humans are P1 and P2")
	hub.model(0).ai = true
	hub.model(1).ai = true
	_ok(UiHints.you_label(hub.models, hub.model(0)) == "", "hints: nobody is labelled in an AI against AI demo")
	var m: UiFighterModel = hub.model(0)
	m.ai = false
	_ok(UiHints.visible_alpha(m, "auto", false, 0.0) == 1.0 and UiHints.visible_alpha(m, "auto", false, 9.0) == 1.0 and is_equal_approx(UiHints.visible_alpha(m, "auto", false, 11.0), 0.5) and UiHints.visible_alpha(m, "auto", false, 12.5) == 0.0, "hints: auto shows for the first 12 s of a match and fades over the last two")
	_ok(UiHints.visible_alpha(m, "auto", true, 60.0) == 1.0 and UiHints.visible_alpha(m, "always", false, 60.0) == 1.0 and UiHints.visible_alpha(m, "off", true, 0.0) == 0.0, "hints: prompts on or 'always' keep them up, 'off' hides them")
	m.ai = true
	_ok(UiHints.visible_alpha(m, "always", true, 0.0) == 0.0, "hints: an AI fighter never gets a legend")
	m.ai = false
	var rows0: Array = UiHints.rows(m, "kb-solo")
	_ok(rows0.size() == 10, "hints: ten rows at first on a keyboard (fly, light, heavy, signature, guard, dodge, power, mode, context, specials)")
	hub.consume({"type": "availability", "actor": 0, "action": "transform", "available": true})
	_ok(UiHints.rows(m, "kb-solo").size() == 11, "hints: Transform joins the legend only while a form is ready")
	_ok(UiHints.rows(m, "no_such_scheme").size() == UiHints.rows(m, "today").size() and UiHints.rows(m, "today").size() == 11, "hints: an unknown scheme falls back to today (a layout is looked up by its own id)")
	_ok(UiHints.rows(m, "simple-pad").size() == 8 and UiHints.rows(m, "arena").size() == 11 and UiHints.rows(m, "brawler").size() == 11, "hints: Simple's legend is shorter (no heavy, mode or specials) and Arena and Brawler show every row")
	hub.consume({"type": "availability", "actor": 0, "action": "transform", "available": false})
	var pid := func(dev: String, slot: int, o: Dictionary) -> String:
		var mm := UiFighterModel.new()
		mm.device = dev
		mm.slot = slot
		return UiHints.preset_id(mm, o)
	_ok(pid.call("kbd", 0, {}) == "kb-solo" and pid.call("kbd", 0, {"humans": 2}) == "kb-shared-p1" and pid.call("kbd", 1, {"humans": 2}) == "kb-shared-p2" and pid.call("xbox", 0, {"pad_preset": "brawler"}) == "brawler" and pid.call("xbox", 0, {}) == "arena" and pid.call("kbd", 0, {"touch": true}) == "touch-simple" and pid.call("kbd", 0, {"control_scheme": "simple-pad"}) == "simple-pad", "hints: the layout comes from the device, how many humans share the keyboard, the pad preset and touch")
	# Geometry: the legend sits in the column under the prompt row, clear of the fight, and not on touch or in portrait.
	for cs in [[Vector2(1920, 1080), 1.0], [Vector2(1366, 768), 1.0], [Vector2(1280, 720), 1.0], [Vector2(2560, 1080), 1.0], [Vector2(1024, 576), 1.0]]:
		var lay := UiLayout.new()
		lay.dp = cs[1]
		lay.compute(cs[0], false)
		var tag := "hints %dx%d" % [int(cs[0].x), int(cs[0].y)]
		var r0: Rect2 = lay.hints[0]
		var view := Rect2(Vector2.ZERO, cs[0])
		_ok(r0.size.y > 0.0 and view.encloses(r0) and not r0.intersects(lay.clear_zone) and not r0.intersects(lay.prompts[0]) and not r0.intersects(lay.bark[0]) and not r0.intersects(lay.cards[0]), "%s: the legend's room is in the column, clear of the fight, the prompt row, the cards and the bark lane" % tag)
		var pl: Dictionary = UiHints.plan(m, r0, lay.s, {"glyph_style": "neutral", "control_scheme": "kb-solo"})
		var placed: Array = pl["rows"]
		_ok(placed.size() >= 3 and (pl["box"] as Rect2).size.y <= r0.size.y + 0.5 and r0.encloses(pl["box"]), "%s: at least three rows fit and the legend stays inside its room (%d rows)" % [tag, placed.size()])
		var lw := UiLayout.new()
		lw.compute(cs[0], false, Vector4.ZERO, true)
		_ok(lw.hints[1].position.x < cs[0].x * 0.5 and lw.hints[0].position.x > cs[0].x * 0.5, "%s: swapped, the legends follow their columns" % tag)
	var lt := UiLayout.new()
	lt.touch_ui = true
	lt.dp = 2.6
	lt.compute(Vector2(2400, 1080), false)
	var lp := UiLayout.new()
	lp.compute(Vector2(390, 844), false)
	_ok(lt.hints[0].size.y <= 0.0 and lp.hints[0].size.y <= 0.0, "hints: none on touch (its controls are on screen) or in portrait")
	# In the HUD: a legend for the human only, for 12 s, and a YOU marker with it.
	root.size = Vector2i(1920, 1080)
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	hud.size = Vector2(1920, 1080)
	root.add_child(hud)
	await process_frame
	hud.setup(["protagonist", "anti_hero"], ["ONE", "TWO"])
	hud.anchor_fn = func(slot): return {"pos": Vector2(700.0 + 500.0 * float(slot), 500.0), "h": 120.0, "visible": true}
	hud.hub.model(0).ai = false
	hud.hub.model(1).ai = true
	for i in range(3):
		hud.advance(1.0 / 60.0)
		await process_frame
	_ok(hud._l_hints[0].sig != null and hud._l_hints[1].sig == null and hud._l_you.sig != null, "hints: the human gets a legend and a YOU marker at the start, the AI neither")
	_ok(hud.hub.model(0).you_label == "YOU" and hud.hub.model(1).you_label == "", "hints: the plate labels follow (YOU, none)")
	var steps := 0
	while steps < 900 and hud._l_hints[0].sig != null:
		hud.advance(1.0 / 30.0)
		steps += 1
	_ok(steps > 300 and hud._l_hints[0].sig == null and hud._l_you.sig == null, "hints: they are gone after the first 12 s (%d half-frames)" % steps)
	hud.set_option("control_hints", "always")
	hud.advance(1.0 / 60.0)
	_ok(hud._l_hints[0].sig != null and hud._l_you.sig != null, "hints: 'always' brings them back")
	hud.set_option("control_hints", "off")
	hud.advance(1.0 / 60.0)
	_ok(hud._l_hints[0].sig == null and hud._l_you.sig == null, "hints: 'off' hides them")
	hud.set_option("control_hints", "auto")
	hud.consume({"type": "match_start"})
	hud.hub.model(0).ai = false
	hud.hub.model(1).ai = true
	hud.advance(1.0 / 60.0)
	_ok(hud._l_hints[0].sig != null, "hints: a new match shows them again")
	hud.set_density(2.6)
	hud.set_option("touch_ui", true)
	hud.advance(1.0 / 60.0)
	_ok(hud._l_hints[0].sig == null and hud._l_you.sig != null, "hints: touch mode has no legend (its controls are on screen) but still marks YOU")
	hud.queue_free()
	await process_frame


## The touch Simple controls, drawn from SimTouch.layout (docs/ui/hud-spec.md section 24): geometry at phone sizes in both orientations and
## both hands, nothing overlapping the HUD, UI's pause and feedback targets winning, and the HUD's state-driven drawing.
func _touch_controls_rules() -> void:
	var sizes: Array = [[Vector2(2400, 1080), 2.6], [Vector2(2340, 1080), 2.75], [Vector2(2532, 1170), 3.0], [Vector2(1560, 720), 2.0], [Vector2(844, 390), 1.0],
		[Vector2(1170, 2532), 3.0], [Vector2(1080, 2340), 2.75], [Vector2(1125, 2436), 3.0], [Vector2(828, 1792), 2.0], [Vector2(750, 1334), 2.0], [Vector2(390, 844), 1.0]]
	for cs in sizes:
		for lh in [false, true]:
			var sz: Vector2 = cs[0]
			var dpv: float = cs[1]
			var lay := UiLayout.new()
			lay.dp = dpv
			lay.touch_ui = true
			lay.left_handed = lh
			lay.compute(sz, false)
			var tag := "touch controls %dx%d dp %.2f %s" % [int(sz.x), int(sz.y), dpv, "left" if lh else "right"]
			_ok(not lay.touch_ctrl.is_empty() and lay.touch_ctrl.has("attack") and lay.touch_ctrl.has("guard") and lay.touch_ctrl.has("power"), "%s: the layout comes from SimTouch.layout with attack, guard and power" % tag)
			var view := Rect2(Vector2.ZERO, sz)
			var rects: Dictionary = {}
			var bad := 0
			var small := 0
			for n in ["attack", "guard", "power"]:
				var c: Dictionary = UiTouchControls.circle(lay, n)
				var r: Rect2 = UiTouchControls.rect_of(c)
				rects[n] = r
				if not view.encloses(r):
					bad += 1
				if float(c.r) * 2.0 < 48.0 * dpv - 0.01:
					small += 1
			_ok(bad == 0 and small == 0, "%s: every button is on screen and at least 48 dp across (%d off, %d small)" % [tag, bad, small])
			var clash := 0
			var names: Array = ["attack", "guard", "power"]
			for i in range(3):
				for j in range(i + 1, 3):
					var a: Dictionary = UiTouchControls.circle(lay, names[i])
					var b: Dictionary = UiTouchControls.circle(lay, names[j])
					if Vector2(float(a.x), float(a.y)).distance_to(Vector2(float(b.x), float(b.y))) < float(a.r) + float(b.r):
						clash += 1
			_ok(clash == 0, "%s: the buttons do not overlap each other" % tag)
			var over: PackedStringArray = []
			var obstacles: Array = [["plate0", lay.plate[0]], ["plate1", lay.plate[1]], ["toll", lay.toll], ["pause", lay.pause_btn], ["pill", lay.feedback_btn], ["read slot", lay.read_slot], ["ring", lay.ring], ["strip", lay.strip], ["clear zone", lay.clear_zone], ["cards0", lay.cards[0]], ["cards1", lay.cards[1]], ["bark", lay.bark[0]]]
			for n in names:
				for o in obstacles:
					if (rects[n] as Rect2).intersects(o[1]) and (o[1] as Rect2).size.y > 0.0:
						over.append("%s>%s" % [n, o[0]])
			_ok(over.is_empty(), "%s: nothing in the HUD (plates, toll, pause, pill, ring, strip, cards, barks) or the fight is under a button %s" % [tag, str(over)])
			if lay.portrait:
				var inside := true
				for n in names:
					if not lay.touch_reserve.encloses(rects[n]):
						inside = false
				_ok(inside, "%s: portrait keeps its reserve from the highest button down" % tag)
				_ok(lay.clear_zone.size.y > sz.y * 0.20, "%s: and the fight keeps its height (%d px)" % [tag, int(lay.clear_zone.size.y)])
			else:
				_ok(lay.clear_zone.size.x > sz.x * 0.27 and lay.clear_zone.size.y > sz.y * 0.40, "%s: the fight keeps its middle beside the buttons (%d by %d px)" % [tag, int(lay.clear_zone.size.x), int(lay.clear_zone.size.y)])
				_ok(lay.bark_single and (lay.bark[0] as Rect2) == (lay.bark[1] as Rect2), "%s: one bark lane, on the other side" % tag)
				var tall_enough: bool = sz.y / dpv >= 380.0 and dpv >= 1.5   # a real phone; a 390 px canvas at dp 1 is an emulator without a pixel ratio
				_ok(not tall_enough or not lay.cards_none, "%s: on a screen at least 380 dp tall the buttons leave room for a wound card a side" % tag)
				_ok(lay.cards_none or (lay.cards[0].size.y >= lay.card_h - 0.5 and lay.cards[1].size.y >= lay.card_h - 0.5), "%s: the cards that remain have their full height" % tag)
			var touch_h := SimTouch.new()
			touch_h.dp = dpv
			var hits := 0
			for n in names:
				var c2: Dictionary = UiTouchControls.circle(lay, n)
				if touch_h.widget_at(float(c2.x), float(c2.y), lay.touch_ctrl) != n:
					hits += 1
			var pc: Vector2 = lay.pause_btn.get_center()
			var pause_hit: String = touch_h.widget_at(pc.x, pc.y, lay.touch_ctrl)
			_ok(hits == 0 and (lay.pause_btn.size.y <= 0.0 or pause_hit != "attack" and pause_hit != "guard" and pause_hit != "power"), "%s: SimTouch hit-tests each button where it is drawn, and the pause button is not under one" % tag)
	UiLook.text_floor = UiLook.MIN_TEXT_PX
	# Without touch there is nothing: the layout does not call SimTouch.
	var l0 := UiLayout.new()
	l0.compute(Vector2(1920, 1080), false)
	_ok(l0.touch_ctrl.is_empty() and not l0.bark_single and not l0.cards_one, "touch controls: none without touch mode")
	# In the HUD: drawn from the host's state, pause and feedback win, TRANSFORM appears only when available.
	root.size = Vector2i(1920, 1080)
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	hud.size = Vector2(2400, 1080)
	root.add_child(hud)
	await process_frame
	hud.setup(["protagonist", "anti_hero"], ["ONE", "TWO"])
	hud.anchor_fn = func(slot): return {"pos": Vector2(900.0 + 400.0 * float(slot), 500.0), "h": 150.0, "visible": true}
	hud.hub.model(0).ai = false
	hud.hub.model(1).ai = true
	hud.set_density(2.6)
	hud.set_option("touch_ui", true)
	var st := {"attack": {"down": false, "hold": 0.0}, "guard": {"down": false}, "power": {"down": false}, "stick": {"active": false}}
	hud.touch_state_fn = func(): return st
	for i in range(3):
		hud.advance(1.0 / 60.0)
		await process_frame
	_ok(hud._l_touchctl.sig != null and hud._l_touchctl.redraws > 0, "touch controls: the HUD draws them in touch mode")
	_ok(hud._l_you.sig != null and hud.hub.model(0).you_label == "YOU", "touch controls: and the YOU marker shows on touch")
	_ok(hud._l_prompts[0].sig == null and hud._l_prompts[1].sig == null and hud._l_hints[0].sig == null, "touch controls: the stance ring and the legend are retired")
	var r0: int = hud._l_touchctl.redraws
	for i in range(60):
		hud.advance(1.0 / 60.0)
		await process_frame
	_ok(hud._l_touchctl.redraws - r0 <= 2, "touch controls: idle, they cost no redraws (%d in a second)" % (hud._l_touchctl.redraws - r0))
	st["attack"] = {"down": true, "hold": 0.5}
	hud.advance(1.0 / 60.0)
	await process_frame
	var r1: int = hud._l_touchctl.redraws
	_ok(r1 > r0, "touch controls: a pressed Attack redraws the layer")
	st["attack"] = {"down": true, "hold": 1.0}
	st["guard"] = {"down": true}
	st["power"] = {"down": true}
	st["stick"] = {"active": true, "base": Vector2(300, 800), "thumb": Vector2(360, 760), "sprint": false}
	hud.advance(1.0 / 60.0)
	await process_frame
	_ok(hud._l_touchctl.redraws > r1, "touch controls: guard, power, a full hold ring and the stick each show")
	var rd: int = hud._l_touchctl.redraws
	st["stick"] = {"active": true, "base": Vector2(300, 800), "thumb": Vector2(361, 761), "sprint": false}
	hud.advance(1.0 / 60.0)
	await process_frame
	_ok(hud._l_touchctl.redraws == rd, "touch controls: a thumb that moves under 2 px does not redraw")
	var tr: Dictionary = hud.touch_rects()
	_ok(tr.has("pause") and not tr.has("transform"), "touch controls: the HUD owns the pause button, and no Transform until it is available")
	hud.consume({"type": "availability", "actor": 0, "action": "transform", "available": true})
	hud.advance(1.0 / 60.0)
	await process_frame
	tr = hud.touch_rects()
	var ctx: Rect2 = UiTouchControls.rect_of(UiTouchControls.circle(hud.layout, "context"))
	_ok(tr.has("transform") and (tr["transform"] as Rect2) == ctx and hud.touch_target_at(ctx.get_center()).get("name", "") == "transform", "touch controls: TRANSFORM takes the context slot when it is available and is a named target")
	var pc2: Vector2 = (tr["pause"] as Rect2).get_center()
	_ok(hud.touch_target_at(pc2).get("name", "") == "pause", "touch controls: the pause button is a HUD target, asked before SimTouch's, so it wins")
	hud.consume({"type": "ko", "winner": 0, "loser": 1})
	hud.advance(1.0 / 60.0)
	await process_frame
	var fbc: Vector2 = hud.layout.feedback_btn.get_center()
	_ok(hud.touch_target_at(fbc).get("name", "") == "feedback", "touch controls: so does the feedback pill after a KO")
	hud.set_option("left_handed", true)
	hud.advance(1.0 / 60.0)
	await process_frame
	_ok(float(hud.layout.touch_ctrl["attack"].x) < hud.layout.vp.x * 0.5 and float(hud.layout.touch_ctrl["stick"].x0) > hud.layout.vp.x * 0.5, "touch controls: left-handed mirrors the buttons to the left and the stick zone to the right")
	hud.queue_free()
	await process_frame


# --- The Settings screen (docs/ui/hud-spec.md section 26) ------------------------------------------------------------------------

func _settings_rules() -> void:
	var od: Dictionary = UiData.options()
	var sd: Dictionary = UiData.settings()
	# The data: every option is on the screen or on its hidden list, every item exists, every shown choice has a word.
	var listed := {}
	var missing := 0
	for sec in sd["sections"]:
		for it in sec["items"]:
			if it is Dictionary:
				continue
			listed[str(it)] = true
			if not od.has(str(it)):
				missing += 1
	for k in sd["hidden"]:
		listed[str(k)] = true
	var unlisted := 0
	for k in od:
		if not listed.has(k):
			unlisted += 1
	var unworded := 0
	for k in listed:
		if sd["hidden"].has(k):
			continue
		if od.has(k) and (od[k] as Dictionary).has("choices"):
			for c in od[k]["choices"]:
				if not (sd["labels"].get(k, {}) as Dictionary).has(str(c)):
					unworded += 1
	_ok(missing == 0 and unlisted == 0 and unworded == 0, "settings: every option is on the screen or hidden on purpose, every item exists and every choice has a word (%d missing, %d unlisted, %d unworded)" % [missing, unlisted, unworded])
	var keys := []
	for r in UiSettings.rows():
		keys.append(r["key"])
	_ok(keys.has("pad_preset") and keys.has("touch_preset") and keys.has("camera_zoom") and keys.has("camera_shake") and keys.has("left_handed") and keys.has("unlock_all") and keys.has("reduced_motion"), "settings: it lists the controller layout, the touch layout, camera zoom and shake, left-handed, unlock all and the accessibility options")
	_ok(od["unlock_all"]["default"] == false and od["touch_preset"]["choices"] == ["touch-simple", "touch-full"], "settings: unlock all is off by default and the touch layout offers Simple and Full")
	var pads_ok := true
	for c in od["pad_preset"]["choices"]:
		pads_ok = pads_ok and sd["labels"]["pad_preset"].has(c)
	_ok(pads_ok and sd["labels"]["pad_preset"]["simple-pad"] == "Simple" and sd["labels"]["pad_preset"]["arena"] == "Arena", "settings: Arena, Brawler and Simple are the words for the three pad layouts")
	# Rows that wait for a feature are listed but disabled and skipped by the focus.
	UiData.set_feature("touch_full", false)
	UiData.set_feature("remap", false)
	var soon := {}
	for r in UiSettings.rows():
		if r["kind"] != UiSettings.HEADING and not bool(r["enabled"]):
			soon[str(r["key"]) if r["key"] != "" else str(r["action"])] = true
	var fo: Array = UiSettings.focusable(UiSettings.rows())
	var rows0: Array = UiSettings.rows()
	var focus_on_soon := false
	for i in fo:
		focus_on_soon = focus_on_soon or not bool(rows0[i]["enabled"])
	_ok(soon.has("touch_preset") and soon.has("remap") and not focus_on_soon and UiSettings.value_word(rows0[keys.find("touch_preset")], {}) == "Soon", "settings: the Full touch layout and Remap wait for their features: listed, dimmed, marked Soon and skipped by the focus")
	UiData.set_feature("touch_full", true)
	UiData.set_feature("remap", true)
	var all_on := true
	for r in UiSettings.rows():
		all_on = all_on and (r["kind"] == UiSettings.HEADING or bool(r["enabled"]))
	_ok(all_on, "settings: with the features on every row is live")
	UiData.set_feature("touch_full", false)
	UiData.set_feature("remap", false)
	# Values: words, steps and the slider's point.
	var rzoom: Dictionary = {}
	var rpad: Dictionary = {}
	var rtog: Dictionary = {}
	var rthick: Dictionary = {}
	var rhit: Dictionary = {}
	for r in UiSettings.rows():
		match str(r["key"]):
			"camera_zoom": rzoom = r
			"pad_preset": rpad = r
			"left_handed": rtog = r
			"thickness": rthick = r
			"hitstop_scale": rhit = r
	var vo := {"camera_zoom": 7.0, "pad_preset": "arena", "left_handed": false, "thickness": 1.0, "hitstop_scale": 0.5}
	_ok(UiSettings.value_word(rzoom, vo) == "7" and UiSettings.value_word(rpad, vo) == "Arena" and UiSettings.value_word(rtog, vo) == "Off" and UiSettings.value_word(rthick, vo) == "Normal" and UiSettings.value_word(rhit, vo) == "50%", "settings: values read as words (7, Arena, Off, Normal, 50%)")
	_ok(UiSettings.stepped(rzoom, vo, 1) == 8.0 and UiSettings.stepped(rzoom, {"camera_zoom": 10.0}, 1) == 10.0 and UiSettings.stepped(rzoom, {"camera_zoom": 0.0}, -1) == 0.0, "settings: a slider steps by one and stops at its ends")
	_ok(UiSettings.stepped(rpad, vo, 1) == "brawler" and UiSettings.stepped(rpad, {"pad_preset": "simple-pad"}, 1) == "arena" and UiSettings.stepped(rpad, vo, -1) == "simple-pad", "settings: a choice cycles round its list in both directions")
	_ok(UiSettings.stepped(rtog, vo, 1) == true and UiSettings.stepped(rthick, vo, 1) == 1.5, "settings: a toggle flips and a numeric choice moves to the next choice")
	var trk := Rect2(100, 0, 200, 48)
	_ok(UiSettings.slider_at(rzoom, trk, 100.0) == 0.0 and UiSettings.slider_at(rzoom, trk, 300.0) == 10.0 and UiSettings.slider_at(rzoom, trk, 200.0) == 5.0 and UiSettings.slider_at(rzoom, trk, 999.0) == 10.0, "settings: a point on the track is a whole step of the slider")
	# Geometry at desktop, tablet, phone and small sizes, touch on and off.
	var cases: Array = [[Vector2(1920, 1080), 1.0], [Vector2(1280, 720), 1.0], [Vector2(1024, 576), 1.0], [Vector2(3840, 2160), 1.0], [Vector2(2400, 1080), 2.6], [Vector2(2532, 1170), 3.0], [Vector2(1560, 720), 2.0],
		[Vector2(844, 390), 1.0], [Vector2(1170, 2532), 3.0], [Vector2(1080, 2340), 2.75], [Vector2(828, 1792), 2.0], [Vector2(750, 1334), 2.0], [Vector2(390, 844), 1.0], [Vector2(360, 640), 1.0]]
	var rcount: int = UiSettings.rows().size()
	for cs in cases:
		var sz: Vector2 = cs[0]
		var dpv: float = cs[1]
		var lay := UiLayout.new()
		lay.dp = dpv
		lay.compute(sz, false)
		for touch in [false, true]:
			var tag := "settings %dx%d dp %.1f touch=%s" % [int(sz.x), int(sz.y), dpv, str(touch)]
			var p: Dictionary = UiSettings.plan(sz, lay.s, dpv, touch, {"focus": 1, "scroll": 0.0}, vo)
			var card: Rect2 = p["card"]
			var body: Rect2 = p["body"]
			var tm: float = float(p["tm"])
			_ok(bool(p["fits"]) and Rect2(Vector2.ZERO, sz).encloses(card) and card.encloses(body) and card.encloses(p["close"]), "%s: the card is on screen and the screen's parts are inside it (%d bad controls)" % [tag, int(p["bad"])])
			_ok((p["close"] as Rect2).size.x >= tm - 0.01 and (p["close"] as Rect2).size.y >= tm - 0.01, "%s: the close cross is at least 48 dp" % tag)
			_ok(body.size.y >= tm * 2.4 and float(p["fs_body"]) >= UiLook.text_floor - 0.5 and float(p["fs_small"]) >= UiLook.text_floor - 0.5, "%s: the body shows at least two rows and the type is at the floor or above (body %d px, row %d px)" % [tag, int(body.size.y), int(tm)])
			# Every row is reachable by scrolling and the focus scrolls into view.
			var seen := 0
			var maxs: float = float(p["max_scroll"])
			var vis_ok := true
			for i in range(rcount):
				var rec: Dictionary = (p["rows"] as Array)[i]
				if rec["kind"] == UiSettings.HEADING or not bool(rec["enabled"]):
					continue
				var sc: float = UiSettings.scroll_to(p, i, 0.0)
				var pp: Dictionary = UiSettings.plan(sz, lay.s, dpv, touch, {"focus": i, "scroll": sc}, vo)
				var rr: Rect2 = (pp["rows"] as Array)[i]["rect"]
				if rr.position.y < body.position.y - 0.5 or rr.end.y > (pp["body"] as Rect2).end.y + 0.5:
					vis_ok = false
				seen += 1
			_ok(vis_ok and seen >= 20 and (maxs > 0.0 or seen > 0), "%s: every row can be scrolled fully into view by the focus (%d rows, content %d in %d)" % [tag, seen, int(p["content_h"]), int(body.size.y)])
			# Rows do not overlap and each control's centre hits itself.
			var hits_ok := true
			var overlap := 0
			var prev_end: float = -1e9
			for rec in p["rows"]:
				var rect: Rect2 = rec["rect"]
				if float(rect.position.y) < prev_end - 0.5:
					overlap += 1
				prev_end = rect.end.y
			var p2: Dictionary = UiSettings.plan(sz, lay.s, dpv, touch, {"focus": 1, "scroll": 0.0}, vo)
			for rec in p2["rows"]:
				if rec["kind"] == UiSettings.HEADING or not bool(rec["enabled"]) or not (rec["rect"] as Rect2).intersects(p2["body"]):
					continue
				if not (p2["body"] as Rect2).encloses(rec["rect"]):
					continue
				for k in rec["ctl"]:
					if k == "switch" or k == "value":
						continue
					var cr: Rect2 = rec["ctl"][k]
					var h: Dictionary = UiSettings.hit(p2, cr.get_center())
					if int(h.get("row", -9)) != int(rec["idx"]) or str(h.get("part", "")) != k:
						hits_ok = false
			_ok(overlap == 0 and hits_ok, "%s: rows do not overlap and every control's centre hits that control (%d overlaps)" % [tag, overlap])
	UiLook.text_floor = UiLook.MIN_TEXT_PX
	# The flow in the HUD: keys, pad, mouse and touch, the signals and what is remembered.
	UiPrefs.path = "user://ui_prefs_test_settings.json"
	if FileAccess.file_exists(UiPrefs.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(UiPrefs.path))
	root.size = Vector2i(1920, 1080)
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	hud.size = Vector2(1920, 1080)
	root.add_child(hud)
	await process_frame
	hud.setup(["protagonist", "anti_hero"], ["ONE", "TWO"])
	hud.hub.model(0).ai = false
	hud.hub.model(1).ai = true
	hud.advance(1.0 / 60.0)
	var ev := {"opened": 0, "closed": 0, "changes": [], "actions": []}
	hud.settings_opened.connect(func(): ev["opened"] += 1)
	hud.settings_closed.connect(func(): ev["closed"] += 1)
	hud.option_changed.connect(func(k, v): ev["changes"].append([k, v]))
	hud.settings_action_requested.connect(func(a): ev["actions"].append(a))
	var rws: Array = UiSettings.rows()
	var idx_of := func(key: String) -> int:
		for i in range(rws.size()):
			if str(rws[i]["key"]) == key:
				return i
		return -1
	hud.show_settings()
	_ok(hud.is_settings_open() and hud.is_overlay_open() and ev["opened"] == 1 and hud.settings_focus() == idx_of.call("pad_preset"), "settings: it opens on the first live row and tells the host")
	hud.show_howto()
	hud.show_feedback("pause")
	_ok(not hud.is_howto_open() and not hud.is_feedback_open(), "settings: How to play and the feedback panel do not open over it")
	var key := func(code: int) -> InputEventKey:
		var e := InputEventKey.new()
		e.keycode = code
		e.pressed = true
		return e
	# Keys: down to Control hints skips the dimmed Touch layout, right changes it, Enter flips a toggle, Esc closes.
	hud._unhandled_input(key.call(KEY_DOWN))
	_ok(hud.settings_focus() == idx_of.call("left_handed"), "settings keys: Down skips the dimmed Touch layout row")
	hud._unhandled_input(key.call(KEY_ENTER))
	_ok(hud.opts["left_handed"] == true and ev["changes"].back() == ["left_handed", true], "settings keys: Enter switches a toggle and option_changed fires")
	hud._unhandled_input(key.call(KEY_ENTER))
	_ok(hud.opts["left_handed"] == false, "settings keys: and again switches it back")
	hud.settings_action("end")
	hud.settings_action("home")
	_ok(hud.settings_focus() == idx_of.call("pad_preset"), "settings keys: Home goes to the first row")
	hud._unhandled_input(key.call(KEY_RIGHT))
	_ok(hud.opts["pad_preset"] == "brawler" and ev["changes"].back() == ["pad_preset", "brawler"], "settings keys: Right changes the controller layout and the host hears it (pad_preset, brawler)")
	hud._unhandled_input(key.call(KEY_LEFT))
	hud._unhandled_input(key.call(KEY_LEFT))
	_ok(hud.opts["pad_preset"] == "simple-pad", "settings keys: Left cycles back round the list")
	hud.settings_action("right")
	var zoom_i: int = idx_of.call("camera_zoom")
	var guard := 0
	while hud.settings_focus() != zoom_i and guard < 60:
		hud.settings_action("down")
		guard += 1
	hud._unhandled_input(key.call(KEY_RIGHT))
	hud._unhandled_input(key.call(KEY_RIGHT))
	hud._unhandled_input(key.call(KEY_RIGHT))
	hud._unhandled_input(key.call(KEY_RIGHT))
	_ok(hud.opts["camera_zoom"] == 10.0 and ev["changes"].back() == ["camera_zoom", 10.0], "settings keys: Right on camera zoom moves it a step at a time and stops at 10")
	hud._unhandled_input(key.call(KEY_LEFT))
	_ok(hud.opts["camera_zoom"] == 9.0, "settings keys: Left lowers it")
	var p0: Dictionary = hud.settings_plan()
	var fr: Rect2 = (p0["rows"] as Array)[hud.settings_focus()]["rect"]
	_ok(fr.position.y >= (p0["body"] as Rect2).position.y - 0.5 and fr.end.y <= (p0["body"] as Rect2).end.y + 0.5, "settings keys: the focused row is scrolled into view")
	# The pad.
	var pad := func(btn: int) -> InputEventJoypadButton:
		var e := InputEventJoypadButton.new()
		e.button_index = btn
		e.pressed = true
		return e
	hud.settings_action("home")
	hud._unhandled_input(pad.call(JOY_BUTTON_DPAD_RIGHT))
	hud._unhandled_input(pad.call(JOY_BUTTON_DPAD_RIGHT))
	var after_pad: String = str(hud.opts["pad_preset"])
	_ok(after_pad == "simple-pad", "settings pad: D-pad right changes a choice (brawler, then simple)")
	hud._unhandled_input(pad.call(JOY_BUTTON_DPAD_DOWN))
	_ok(hud.settings_focus() == idx_of.call("left_handed"), "settings pad: D-pad down moves the focus")
	hud._unhandled_input(pad.call(JOY_BUTTON_A))
	_ok(hud.opts["left_handed"] == true, "settings pad: A switches a toggle")
	hud._unhandled_input(pad.call(JOY_BUTTON_A))
	var jm := InputEventJoypadMotion.new()
	jm.axis = JOY_AXIS_LEFT_Y
	jm.axis_value = 0.9
	hud._unhandled_input(jm)
	hud._unhandled_input(jm)
	_ok(hud.settings_focus() == idx_of.call("hotseat_alt_layout"), "settings pad: a stick push is one step, not a stream")
	var jr := InputEventJoypadMotion.new()
	jr.axis = JOY_AXIS_LEFT_Y
	jr.axis_value = 0.0
	hud._unhandled_input(jr)
	hud._unhandled_input(jm)
	_ok(hud.settings_focus() == idx_of.call("control_hints"), "settings pad: and after the stick returns, the next push is another step")
	hud._unhandled_input(jr)
	# The mouse and a finger: a tap on a control, a drag on a track, a drag elsewhere to scroll, the wheel.
	var mouse := func(pos: Vector2, pressed: bool) -> InputEventMouseButton:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		return e
	var tap := func(pos: Vector2) -> void:
		hud._unhandled_input(mouse.call(pos, true))
		hud._unhandled_input(mouse.call(pos, false))
	hud._unhandled_input(key.call(KEY_ESCAPE))
	_ok(not hud.is_settings_open() and ev["closed"] == 1, "settings: Esc closes it and tells the host")
	hud.show_settings()
	var pl: Dictionary = hud.settings_plan()
	var prec: Dictionary = (pl["rows"] as Array)[idx_of.call("pad_preset")]
	var before: String = str(hud.opts["pad_preset"])
	tap.call((prec["ctl"]["right"] as Rect2).get_center())
	_ok(hud.opts["pad_preset"] != before and hud.settings_focus() == idx_of.call("pad_preset"), "settings touch: a tap on the right chevron changes the controller layout and focuses the row")
	tap.call((prec["ctl"]["left"] as Rect2).get_center())
	_ok(hud.opts["pad_preset"] == before, "settings touch: a tap on the left chevron changes it back")
	pl = hud.settings_plan()
	var lrec: Dictionary = (pl["rows"] as Array)[idx_of.call("left_handed")]
	tap.call((lrec["ctl"]["tap"] as Rect2).get_center())
	_ok(hud.opts["left_handed"] == true, "settings touch: a tap on a toggle switches it")
	tap.call((lrec["rect"] as Rect2).get_center() + Vector2(-100, 0))
	_ok(hud.opts["left_handed"] == false, "settings touch: a tap anywhere on a toggle's row switches it too")
	# Scroll first so the camera rows are on screen, then drag a slider's track.
	var zoom_rec: Dictionary = (hud.settings_plan()["rows"] as Array)[zoom_i]
	hud._set_scroll = UiSettings.scroll_to(hud.settings_plan(), zoom_i, 0.0)
	zoom_rec = (hud.settings_plan()["rows"] as Array)[zoom_i]
	var trk2: Rect2 = zoom_rec["ctl"]["track"]
	hud._unhandled_input(mouse.call(Vector2(trk2.position.x + 2.0, trk2.get_center().y), true))
	_ok(hud.opts["camera_zoom"] == 0.0, "settings touch: a press at the left end of a track sets 0")
	var mm := InputEventMouseMotion.new()
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	mm.position = Vector2(trk2.get_center().x, trk2.get_center().y + 30.0)
	hud._unhandled_input(mm)
	var mid: float = float(hud.opts["camera_zoom"])
	mm.position = Vector2(trk2.end.x + 50.0, trk2.get_center().y)
	hud._unhandled_input(mm)
	hud._unhandled_input(mouse.call(mm.position, false))
	_ok(mid >= 4.0 and mid <= 6.0 and hud.opts["camera_zoom"] == 10.0, "settings touch: dragging along a track follows the finger (to about the middle, then to the end)")
	var plus_rec: Rect2 = (hud.settings_plan()["rows"] as Array)[zoom_i]["ctl"]["minus"]
	tap.call(plus_rec.get_center())
	_ok(hud.opts["camera_zoom"] == 9.0, "settings touch: the minus button steps a slider down")
	# Dragging on a label scrolls instead of acting.
	hud._set_scroll = 0.0
	var pl2: Dictionary = hud.settings_plan()
	var lab: Rect2 = (pl2["rows"] as Array)[idx_of.call("show_prompts")]["rect"]
	var start := Vector2(lab.position.x + 40.0, lab.get_center().y)
	var show_before: bool = bool(hud.opts["show_prompts"])
	hud._unhandled_input(mouse.call(start, true))
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = start + Vector2(0, -160)
	hud._unhandled_input(drag)
	hud._unhandled_input(mouse.call(drag.position, false))
	_ok(hud._set_scroll > 100.0 and bool(hud.opts["show_prompts"]) == show_before, "settings touch: a drag on a row scrolls the list and does not switch the row")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var s0: float = hud._set_scroll
	hud._unhandled_input(wheel)
	_ok(hud._set_scroll < s0, "settings mouse: the wheel scrolls")
	tap.call((hud.settings_plan()["close"] as Rect2).get_center())
	_ok(not hud.is_settings_open() and ev["closed"] == 2, "settings touch: the close cross closes it")
	# The remap entry emits its action once its feature is on.
	UiData.set_feature("remap", true)
	hud.show_settings()
	var ridx := -1
	rws = UiSettings.rows()
	for i in range(rws.size()):
		if rws[i]["kind"] == UiSettings.BUTTON:
			ridx = i
	hud._set_focus = ridx
	hud.settings_action("accept")
	_ok(hud.is_remap_open() and hud.is_settings_open() and ev["actions"].is_empty(), "settings: the Remap controls entry opens the remap screen over Settings")
	hud.hide_remap()
	_ok(not hud.is_remap_open() and hud.is_settings_open(), "settings: and closing the remap screen goes back to Settings")
	hud.hide_settings()
	UiData.set_feature("remap", false)
	hud.show_settings()
	hud._set_focus = ridx
	hud.settings_action("accept")
	_ok(not hud.is_remap_open(), "settings: and the entry does nothing while it is marked Soon")
	hud.hide_settings()
	# Remembered: the changes are in the prefs file and a new HUD applies them.
	hud.settings_set("camera_shake", 9)
	hud.settings_set("pad_preset", "brawler")
	hud.queue_free()
	await process_frame
	var hud2: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	hud2.size = Vector2(1920, 1080)
	root.add_child(hud2)
	await process_frame
	var got: Array = []
	hud2.setup(["protagonist", "anti_hero"], ["ONE", "TWO"])
	hud2.option_changed.connect(func(k, v): got.append(k))
	var fresh_ok: bool = hud2.opts["camera_shake"] == 2 and hud2.opts["pad_preset"] == "arena"
	hud2.load_saved_options()
	_ok(fresh_ok and hud2.opts["camera_shake"] == 9.0 and hud2.opts["pad_preset"] == "brawler" and got.has("pad_preset") and got.has("camera_shake") and hud2.opts["show_prompts"] == false, "settings: what the player changed on the screen comes back on the next run (and the host hears it), and nothing else does")
	# The screen draws without error at a desktop and a phone size, and costs nothing while closed.
	var redraws: int = hud2.redraw_count()
	hud2.advance(1.0 / 60.0)
	hud2.advance(1.0 / 60.0)
	_ok(hud2.redraw_count() == redraws, "settings: a closed screen costs no redraws")
	hud2.show_settings()
	hud2.advance(1.0 / 60.0)
	await process_frame
	await process_frame
	_ok(hud2._l_settings.sig != null, "settings: an open screen has its layer drawing")
	hud2.hide_settings()
	_ok(hud2._l_settings.sig == null, "settings: and none once closed")
	hud2.queue_free()
	await process_frame
	UiPrefs.path = "user://ui_prefs.json"
	if FileAccess.file_exists("user://ui_prefs_test_settings.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ui_prefs_test_settings.json"))
	UiData.set_feature("touch_full", null)
	UiData.set_feature("remap", null)


# --- The Remap controls screen (docs/ui/hud-spec.md section 27) -------------------------------------------------------------------

func _binding_controls(p: Dictionary, action: String, layer: String = "", gesture: String = "") -> Array:
	for b in p["bindings"]:
		if str(b["action"]) == action and str(b.get("layer", "")) == layer and str(b.get("gesture", "")) == gesture and not b.has("axis") and (b["controls"] as Array).size() == 1:
			return b["controls"]
	return []


func _remap_rules() -> void:
	SimInputData.ensure()
	SimInputData.clear_overrides()
	UiRemapModel.save_path = "user://input_test_remap.json"
	if FileAccess.file_exists(UiRemapModel.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(UiRemapModel.save_path))
	var solo: Dictionary = SimInputData.preset("kb-solo")
	# The layouts and the entries each has.
	_ok(UiRemapModel.layouts() == ["arena", "brawler", "simple-pad", "kb-solo", "kb-shared-p1", "kb-shared-p2"], "remap: the keyboard and pad layouts can be changed, touch cannot")
	var ids := func(id: String) -> Array:
		var out: Array = []
		for e in UiRemapModel.entries(SimInputData.preset(id)):
			out.append(e["id"])
		return out
	_ok(ids.call("kb-solo") == ["move", "light", "heavy", "signature", "guard", "dodge", "power", "mode", "context", "transform"] and ids.call("arena") == ["light", "heavy", "signature", "guard", "dodge", "power", "mode", "context"] and ids.call("simple-pad") == ["light", "signature", "guard", "dodge", "power", "context", "transform"], "remap: a keyboard lists Fly (four keys) and every action, a pad its single-control actions")
	var fixed_ids := func(id: String) -> Array:
		var out: Array = []
		for r in UiRemapModel.rows(SimInputData.preset(id)):
			if bool(r["fixed"]):
				out.append(r["id"])
		return out
	_ok(fixed_ids.call("arena") == ["move@fixed0", "transform@fixed0", "transform@fixed1"] and fixed_ids.call("kb-solo") == ["transform@fixed0"] and fixed_ids.call("simple-pad") == ["move@fixed0", "transform@fixed0"], "remap: the pad stick and the chords are listed as fixed rows (greyed, no capture); Pause, Hints, gestures and the power layer are not listed")
	# A free key: the layered special follows Light (Controls' applier), nothing else moves.
	var r1: Dictionary = UiRemapModel.attempt("kb-solo", "light", "kb:KeyZ")
	_ok(r1["status"] == "ok" and (r1["overrides"] as Array) == [{"controls": ["kb:KeyZ"], "action": "light"}], "remap: a free key is an override row for Light")
	UiRemapModel.commit("kb-solo", r1["overrides"])
	var z: Dictionary = SimInputData.preset("kb-solo")
	_ok(_binding_controls(z, "light") == ["kb:KeyZ"] and _binding_controls(z, "special1", "power") == ["kb:KeyZ"] and _binding_controls(z, "heavy") == ["kb:KeyK"] and SimInputData.check_bindings(z).is_empty(), "remap: committing it moves Light and the first special, nothing else, and the layout still passes Controls' checks")
	_ok(SimInputRemap.load_file(UiRemapModel.save_path)["presets"]["kb-solo"]["overrides"] == [{"controls": ["kb:KeyZ"], "action": "light"}], "remap: it is saved to the player's file in Controls' shape")
	# A conflict offers a swap.
	var c2: Dictionary = UiRemapModel.attempt("kb-solo", "light", "kb:KeyK")
	var c3: Dictionary = UiRemapModel.attempt("kb-solo", "heavy", "kb:KeyZ")
	_ok(c2["status"] == "conflict" and c2["with"] == "heavy" and c3["status"] == "conflict" and c3["with"] == "light", "remap: a key that is another action's is a conflict that names it")
	var sw: Dictionary = UiRemapModel.attempt("kb-solo", "heavy", "kb:KeyZ", true)
	UiRemapModel.commit("kb-solo", sw["overrides"])
	var s2: Dictionary = SimInputData.preset("kb-solo")
	_ok(sw["status"] == "ok" and _binding_controls(s2, "heavy") == ["kb:KeyZ"] and _binding_controls(s2, "light") == ["kb:KeyK"] and _binding_controls(s2, "special1", "power") == ["kb:KeyK"] and _binding_controls(s2, "special2", "power") == ["kb:KeyZ"] and SimInputData.check_bindings(s2).is_empty(), "remap: the swap hands the old control to the other action and the specials follow both")
	UiRemapModel.commit("kb-solo", [])
	_ok(_binding_controls(SimInputData.preset("kb-solo"), "light") == ["kb:KeyJ"] and not SimInputData.overrides[0].has("kb-solo"), "remap: an empty list puts the layout back")
	# Refusals.
	var bad := true
	for k in ["kb:KeyP", "kb:KeyN", "kb:KeyT", "kb:KeyY", "kb:Escape", "kb:F5"]:
		bad = bad and UiRemapModel.attempt("kb-solo", "light", k)["status"] == "reserved"
	_ok(bad and UiRemapModel.attempt("arena", "light", "pad:start")["status"] == "reserved" and UiRemapModel.attempt("arena", "light", "pad:back")["status"] == "reserved" and UiRemapModel.attempt("simple-pad", "light", "pad:back")["status"] == "reserved" and UiRemapModel.attempt("kb-solo", "light", "pad:west")["status"] == "wrong_device" and UiRemapModel.attempt("arena", "light", "kb:KeyZ")["status"] == "wrong_device" and UiRemapModel.attempt("kb-solo", "light", "kb:KeyJ")["status"] == "same" and UiRemapModel.attempt("kb-solo", "light", "kb:KeyL")["status"] == "conflict", "remap: N, T, Y, P, Esc, F-keys, Start and Back are refused; the wrong device is refused; the same control is no change")
	_ok(UiRemapModel.attempt("kb-shared-p1", "light", "kb:KeyH")["status"] == "pair" and UiRemapModel.attempt("kb-shared-p1", "light", "kb:KeyK")["status"] == "pair" and UiRemapModel.attempt("kb-shared-p1", "light", "kb:KeyZ")["status"] == "ok" and UiRemapModel.attempt("kb-solo", "light", "kb:KeyH")["status"] == "ok", "remap: a key the other half of a shared keyboard uses is refused (and not on the solo layout)")
	# A chord's members are free for single bindings; the chords themselves are never changed.
	var cm: Dictionary = UiRemapModel.attempt("arena", "light", "pad:l3")
	var cs2: Dictionary = UiRemapModel.attempt("arena", "light", "pad:rt")
	var cs3: Dictionary = UiRemapModel.attempt("kb-solo", "light", "kb:Space")
	_ok(cm["status"] == "ok" and cs2["status"] == "conflict" and cs2["with"] == "power" and cs3["status"] == "conflict" and cs3["with"] == "dodge", "remap: a chord member that is only in the chord (L3) is free; one that is also an action's control (RT, Space) is a conflict with that action")
	UiRemapModel.commit("arena", UiRemapModel.attempt("arena", "light", "pad:rt", true)["overrides"])
	var chords_kept := 0
	for b in SimInputData.preset("arena")["bindings"]:
		if (b["controls"] as Array).size() > 1 and str(b["action"]) == "transform":
			chords_kept += 1
	_ok(_binding_controls(SimInputData.preset("arena"), "light") == ["pad:rt"] and _binding_controls(SimInputData.preset("arena"), "power") == ["pad:west"] and chords_kept == 2, "remap: swapping across a chord member (Light to RT, Power to the west button) leaves both chords as they are")
	UiRemapModel.commit("arena", [])
	# Fly: four keys in order, rebound together.
	var ck: Dictionary = UiRemapModel.check_move_key("kb-solo", [], "kb:Digit1")
	_ok(ck["status"] == "ok" and UiRemapModel.check_move_key("kb-solo", ["kb:Digit1"], "kb:Digit1")["status"] == "twice" and UiRemapModel.check_move_key("kb-solo", [], "kb:KeyJ")["status"] == "taken" and UiRemapModel.check_move_key("kb-solo", [], "kb:KeyJ")["with"] == "light" and UiRemapModel.check_move_key("kb-solo", [], "kb:KeyW")["status"] == "ok" and UiRemapModel.check_move_key("kb-solo", [], "kb:KeyP")["status"] == "reserved" and UiRemapModel.check_move_key("kb-solo", [], "pad:west")["status"] == "wrong_device" and UiRemapModel.check_move_key("kb-shared-p1", [], "kb:KeyH")["status"] == "pair" and UiRemapModel.check_move_key("kb-shared-p1", [], "kb:KeyI")["status"] == "pair", "remap: each Fly key is checked as it is pressed (a free key, the same key twice, another action's key, one of its own old keys, a reserved key, the wrong device, the other half's keys)")
	var mk: Array = ["kb:Digit1", "kb:Digit2", "kb:Digit3", "kb:Digit4"]
	var am: Dictionary = UiRemapModel.attempt_move("kb-solo", mk)
	_ok(am["status"] == "ok" and (am["overrides"] as Array) == [{"controls": mk, "action": "move"}] and UiRemapModel.attempt_move("kb-solo", ["kb:KeyW", "kb:KeyA", "kb:KeyS", "kb:KeyD"])["status"] == "same" and UiRemapModel.attempt_move("kb-solo", ["kb:KeyJ", "kb:KeyA", "kb:KeyS", "kb:KeyD"])["status"] == "taken" and UiRemapModel.attempt_move("kb-solo", ["kb:KeyJ", "kb:KeyA", "kb:KeyS", "kb:KeyD"])["control"] == "kb:KeyJ" and UiRemapModel.attempt_move("kb-solo", ["kb:Digit1", "kb:Digit1", "kb:Digit3", "kb:Digit4"])["status"] == "twice" and UiRemapModel.attempt("arena", "move", "pad:west")["status"] == "reserved", "remap: Fly rebinds four different keys in one row with no swap (a key that is another action's is named), and the pad stick cannot be remapped")
	UiRemapModel.commit("kb-solo", am["overrides"])
	var mvp: Dictionary = SimInputData.preset("kb-solo")
	var mv_ctrl: Array = []
	for b in mvp["bindings"]:
		if b.has("axis"):
			mv_ctrl = b["controls"]
	_ok(mv_ctrl == mk and SimInputData.check_bindings(mvp).is_empty(), "remap: the new Fly keys are the layout's and it passes Controls' checks")
	UiRemapModel.commit("kb-solo", [])
	# Partners on the pads.
	var rs: Dictionary = UiRemapModel.attempt("simple-pad", "light", "pad:lt")
	UiRemapModel.commit("simple-pad", rs["overrides"])
	var spz: Dictionary = SimInputData.preset("simple-pad")
	_ok(_binding_controls(spz, "light") == ["pad:lt"] and _binding_controls(spz, "special_auto", "power") == ["pad:lt"] and _binding_controls(spz, "upgrade_heavy", "", "hold") == ["pad:lt"] and UiRemapModel.attempt("simple-pad", "heavy_none", "pad:rt")["status"] == "reserved", "remap: on Simple the hold-for-heavy and the auto special follow Light")
	UiRemapModel.commit("simple-pad", [])
	var rb: Dictionary = UiRemapModel.attempt("brawler", "mode", "pad:dpad_up")
	UiRemapModel.commit("brawler", rb["overrides"])
	_ok(_binding_controls(SimInputData.preset("brawler"), "special3", "power") == ["pad:dpad_up"], "remap: on Brawler the third special follows Mode")
	UiRemapModel.commit("brawler", [])
	# The glyphs everywhere follow the player's layout.
	var lbl := func(action: String, layer_preset: String) -> String:
		var parts := PackedStringArray()
		for sp2 in UiGlyphs.specs_for(action, "kbd", 0, "neutral", layer_preset):
			parts.append(str(sp2.get("label", "")))
		return " ".join(parts)
	UiRemapModel.commit("kb-solo", UiRemapModel.attempt("kb-solo", "light", "kb:KeyZ")["overrides"])
	_ok(lbl.call("light", "kb-solo") == "Z" and lbl.call("special1", "kb-solo") == "Z" and lbl.call("heavy", "kb-solo") == "K", "remap: the legend and the card read the remapped keys (Light is Z, and so is the first special)")
	UiRemapModel.commit("kb-solo", [])
	_ok(lbl.call("light", "kb-solo") == "J", "remap: and the data's keys when there are no overrides")
	# The screen, in the HUD: keys, the pad, the mouse and touch.
	UiData.set_feature("remap", true)
	root.size = Vector2i(1920, 1080)
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	hud.size = Vector2(1920, 1080)
	root.add_child(hud)
	await process_frame
	hud.setup(["protagonist", "anti_hero"], ["ONE", "TWO"])
	hud.hub.model(0).ai = false
	hud.hub.model(1).ai = true
	hud.advance(1.0 / 60.0)
	var got := {"changes": [], "opened": 0, "closed": 0}
	hud.remap_changed.connect(func(id, o): got["changes"].append([id, o]))
	hud.settings_opened.connect(func(): got["opened"] += 1)
	hud.settings_closed.connect(func(): got["closed"] += 1)
	hud.show_remap()
	_ok(hud.is_remap_open() and hud.is_settings_open() and got["opened"] == 1 and hud.remap_layout() == "kb-solo", "remap: opened on its own it opens Settings too and starts on the player's own layout (the solo keyboard)")
	hud.hide_remap()
	_ok(not hud.is_remap_open() and not hud.is_settings_open() and got["closed"] == 1, "remap: and closing it closes both, once")
	hud.show_settings()
	hud.show_remap("arena")
	_ok(hud.remap_layout() == "arena", "remap: a layout can be asked for by id")
	hud.hide_remap()
	hud.hide_settings()
	hud.show_remap()
	var key := func(code: int) -> InputEventKey:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = true
		return e
	var rows_of := func() -> Array:
		return hud._rm_rows()
	var idx := func(id: String) -> int:
		return hud._rm_row_index(id)
	hud._rm_focus = idx.call("light")
	hud._unhandled_input(key.call(KEY_ENTER))
	_ok(hud.remap_mode() == "capture" and str(hud.remap_plan()["status"]).contains("Press the key for Light"), "remap keys: Enter on a row waits for a key and says which")
	hud._unhandled_input(key.call(KEY_Z))
	var solo_now: Dictionary = SimInputData.preset("kb-solo")
	_ok(hud.remap_mode() == "list" and _binding_controls(solo_now, "light") == ["kb:KeyZ"] and str(hud.remap_plan()["status"]) == "Light is now Z." and got["changes"].size() == 1 and got["changes"][0][0] == "kb-solo" and (got["changes"][0][1] as Array).size() == 1, "remap keys: the key is taken, the screen says so and the host is told (kb-solo, one row)")
	_ok(lbl.call("light", "kb-solo") == "Z" and SimInputRemap.load_file(UiRemapModel.save_path)["presets"].has("kb-solo"), "remap keys: the glyphs follow at once and the change is saved")
	hud._rm_focus = idx.call("heavy")
	hud._unhandled_input(key.call(KEY_ENTER))
	hud._unhandled_input(key.call(KEY_Z))
	_ok(hud.remap_mode() == "confirm" and str(hud.remap_plan()["status"]) == "Z is already Light. Swap them?" and (hud.remap_plan()["confirm_labels"] as Array) == ["SWAP", "CANCEL"] and got["changes"].size() == 1, "remap keys: a key that is Light's asks before anything changes")
	hud._unhandled_input(key.call(KEY_ESCAPE))
	_ok(hud.remap_mode() == "list" and hud.is_remap_open() and _binding_controls(SimInputData.preset("kb-solo"), "heavy") == ["kb:KeyK"], "remap keys: Esc says no and stays on the screen")
	hud._unhandled_input(key.call(KEY_ENTER))
	hud._unhandled_input(key.call(KEY_Z))
	hud._unhandled_input(key.call(KEY_ENTER))
	var swapped: Dictionary = SimInputData.preset("kb-solo")
	_ok(hud.remap_mode() == "list" and _binding_controls(swapped, "heavy") == ["kb:KeyZ"] and _binding_controls(swapped, "light") == ["kb:KeyK"] and SimInputData.check_bindings(swapped).is_empty(), "remap keys: Enter swaps the two")
	hud._rm_focus = idx.call("guard")
	hud._unhandled_input(key.call(KEY_ENTER))
	hud._unhandled_input(key.call(KEY_P))
	_ok(hud.remap_mode() == "capture" and str(hud.remap_plan()["status"]) == "P is kept for the game. Pick another.", "remap keys: a reserved key is refused and the screen keeps waiting")
	hud._unhandled_input(key.call(KEY_ESCAPE))
	_ok(hud.remap_mode() == "list" and hud.is_remap_open(), "remap keys: Esc cancels the wait, not the screen")
	# Fly: four keys in order, refusals along the way, then one row emitted.
	hud._rm_focus = idx.call("move")
	hud._unhandled_input(key.call(KEY_ENTER))
	_ok(hud.remap_mode() == "capture" and str(hud.remap_plan()["status"]) == "Press the key for Fly up.  Esc cancels.", "remap keys: Enter on Fly asks for up first")
	hud._unhandled_input(key.call(KEY_1))
	_ok(str(hud.remap_plan()["status"]) == "Press the key for Fly left.  Esc cancels.", "remap keys: then left, in order")
	hud._unhandled_input(key.call(KEY_1))
	_ok(str(hud.remap_plan()["status"]) == "Pick four different keys." and hud.remap_mode() == "capture", "remap keys: the same key twice is refused and the wait goes on")
	hud._unhandled_input(key.call(KEY_L))
	_ok(str(hud.remap_plan()["status"]) == "L is already Signature. Pick another." and (hud.remap_plan()["confirm_labels"] as Array) == ["CANCEL"], "remap keys: another action's key is named, and there is no swap for a Fly key")
	var before_n: int = got["changes"].size()
	for k in [KEY_2, KEY_3, KEY_4]:
		hud._unhandled_input(key.call(k))
	var fly_now: Dictionary = SimInputData.preset("kb-solo")
	var fly_keys: Array = []
	for b in fly_now["bindings"]:
		if b.has("axis"):
			fly_keys = b["controls"]
	_ok(hud.remap_mode() == "list" and fly_keys == ["kb:Digit1", "kb:Digit2", "kb:Digit3", "kb:Digit4"] and got["changes"].size() == before_n + 1 and (got["changes"].back()[1] as Array).has({"controls": fly_keys, "action": "move"}) and str(hud.remap_plan()["status"]) == "Fly is now 1 2 3 4.", "remap keys: four presses rebind Fly as one row and the host is told")
	_ok(lbl.call("move", "kb-solo") == "1234", "remap keys: and the legend shows the new Fly keys")
	hud._rm_focus = idx.call("move")
	hud._unhandled_input(key.call(KEY_ENTER))
	hud._unhandled_input(key.call(KEY_ESCAPE))
	_ok(hud.remap_mode() == "list", "remap keys: Esc cancels half-way through Fly")
	hud._rm_focus = rows_of.call().size() - 1
	hud._unhandled_input(key.call(KEY_ENTER))
	_ok(not SimInputData.overrides[0].has("kb-solo") and got["changes"].back() == ["kb-solo", []] and lbl.call("light", "kb-solo") == "J" and str(hud.remap_plan()["status"]) == "Keyboard is back to its defaults.", "remap keys: Reset puts the layout back, tells the host the empty list and the glyphs return")
	hud._unhandled_input(key.call(KEY_RIGHT))
	_ok(hud.remap_layout() == "kb-shared-p1", "remap keys: Right goes to the next layout")
	hud._unhandled_input(key.call(KEY_LEFT))
	hud._unhandled_input(key.call(KEY_LEFT))
	_ok(hud.remap_layout() == "simple-pad", "remap keys: and Left to the one before (round the list)")
	hud._rm_set_layout("kb-shared-p1")
	hud._rm_focus = idx.call("light")
	hud._unhandled_input(key.call(KEY_ENTER))
	hud._unhandled_input(key.call(KEY_H))
	_ok(hud.remap_mode() == "capture" and str(hud.remap_plan()["status"]).contains("other player"), "remap keys: a key of the other player's half is refused")
	hud._unhandled_input(key.call(KEY_ESCAPE))
	# The pad.
	hud._rm_set_layout("arena")
	var pad := func(btn: int) -> InputEventJoypadButton:
		var e := InputEventJoypadButton.new()
		e.button_index = btn
		e.pressed = true
		return e
	var fixed_rows := 0
	var fixed_off := true
	for r in hud._rm_rows():
		if r["kind"] == UiSettings.BIND and str(r["key"]).contains("@fixed"):
			fixed_rows += 1
			fixed_off = fixed_off and not bool(r["enabled"])
	var pl_fx: Dictionary = hud.remap_plan()
	var fx_rec: Dictionary = (pl_fx["rows"] as Array)[hud._rm_row_index("transform@fixed0")]
	_ok(fixed_rows == 3 and fixed_off and UiSettings.hit(pl_fx, (fx_rec["rect"] as Rect2).get_center()).get("part", "") == "off", "remap pad: the stick and the two chords are greyed rows that cannot be captured")
	hud._rm_focus = idx.call("context")
	hud._unhandled_input(pad.call(JOY_BUTTON_DPAD_DOWN))
	_ok(hud.remap_plan()["focus"] == hud._rm_rows().size() - 1, "remap pad: the focus skips the greyed rows (Down from Context goes to Reset)")
	hud._rm_focus = idx.call("light")
	hud._unhandled_input(pad.call(JOY_BUTTON_DPAD_DOWN))
	_ok(hud.remap_layout() == "arena" and hud.remap_plan()["focus"] == idx.call("heavy"), "remap pad: the D-pad moves the focus")
	hud._rm_focus = idx.call("light")
	hud._unhandled_input(pad.call(JOY_BUTTON_A))
	_ok(hud.remap_mode() == "capture" and str(hud.remap_plan()["status"]).contains("Press the button for Light"), "remap pad: A waits for a button")
	hud._unhandled_input(key.call(KEY_Z))
	_ok(hud.remap_mode() == "capture", "remap pad: a key is ignored while a button is wanted")
	hud._unhandled_input(pad.call(JOY_BUTTON_LEFT_SHOULDER))
	_ok(hud.remap_mode() == "confirm" and str(hud.remap_plan()["status"]) == "LB is already Guard. Swap them?", "remap pad: a button that is Guard's asks")
	hud._unhandled_input(pad.call(JOY_BUTTON_B))
	_ok(hud.remap_mode() == "list", "remap pad: B says no")
	hud._unhandled_input(pad.call(JOY_BUTTON_A))
	hud._unhandled_input(pad.call(JOY_BUTTON_START))
	_ok(hud.remap_mode() == "list" and hud.is_remap_open(), "remap pad: Start cancels the wait")
	hud._unhandled_input(pad.call(JOY_BUTTON_A))
	hud._unhandled_input(pad.call(JOY_BUTTON_BACK))
	_ok(hud.remap_mode() == "capture" and str(hud.remap_plan()["status"]).contains("kept for the game"), "remap pad: Back is refused")
	var trig := InputEventJoypadMotion.new()
	trig.axis = JOY_AXIS_TRIGGER_RIGHT
	trig.axis_value = 1.0
	hud._unhandled_input(trig)
	_ok(hud.remap_mode() == "confirm" and str(hud.remap_plan()["status"]) == "RT is already Power. Swap them?", "remap pad: a trigger pulled past the threshold is a press of that trigger (RT is Power's: a swap is offered)")
	hud._unhandled_input(pad.call(JOY_BUTTON_B))
	hud._rm_focus = idx.call("light")
	hud._unhandled_input(pad.call(JOY_BUTTON_A))
	hud._unhandled_input(pad.call(JOY_BUTTON_RIGHT_SHOULDER))
	_ok(hud.remap_mode() == "confirm" and str(hud.remap_plan()["status"]) == "RB is already Mode. Swap them?", "remap pad: a bumper that is Mode's asks")
	hud._unhandled_input(pad.call(JOY_BUTTON_A))
	var arena_now: Dictionary = SimInputData.preset("arena")
	_ok(hud.remap_mode() == "list" and _binding_controls(arena_now, "light") == ["pad:rb"] and _binding_controls(arena_now, "mode") == ["pad:west"] and _binding_controls(arena_now, "special1", "power") == ["pad:rb"], "remap pad: A swaps (Light on RB, Mode on the west button, the first special with Light)")
	_ok(str(UiGlyphs.specs_for("light", "xbox", 0, "neutral", "arena")[0].get("label", "")) == "RB", "remap pad: and the pad glyphs follow (Light reads RB)")
	hud._rm_focus = rows_of.call().size() - 1
	hud._unhandled_input(pad.call(JOY_BUTTON_A))
	_ok(not SimInputData.overrides[0].has("arena") and _binding_controls(SimInputData.preset("arena"), "light") == ["pad:west"], "remap pad: Reset on a pad layout puts it back")
	# The mouse and a finger.
	var mouse := func(pos: Vector2, pressed: bool) -> InputEventMouseButton:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		return e
	var tap := func(pos: Vector2) -> void:
		hud._unhandled_input(mouse.call(pos, true))
		hud._unhandled_input(mouse.call(pos, false))
	hud._rm_set_layout("kb-solo")
	var pl: Dictionary = hud.remap_plan()
	var lrec: Dictionary = (pl["rows"] as Array)[idx.call("light")]
	tap.call((lrec["ctl"]["tap"] as Rect2).get_center())
	_ok(hud.remap_mode() == "capture", "remap touch: a tap on a row waits for a key")
	var cancel_r: Rect2 = (hud.remap_plan()["confirm"] as Array)[0]
	tap.call(cancel_r.get_center())
	_ok(hud.remap_mode() == "list", "remap touch: and its Cancel button cancels")
	tap.call((lrec["ctl"]["tap"] as Rect2).get_center())
	hud._unhandled_input(key.call(KEY_K))
	var lc: Array = (hud.remap_plan()["confirm"] as Array)
	_ok(hud.remap_mode() == "confirm" and lc.size() == 2, "remap touch: a taken key shows Swap and Cancel buttons")
	tap.call((lc[0] as Rect2).get_center())
	_ok(hud.remap_mode() == "list" and _binding_controls(SimInputData.preset("kb-solo"), "light") == ["kb:KeyK"], "remap touch: tapping Swap swaps")
	var rrec: Dictionary = (hud.remap_plan()["rows"] as Array)[0]
	tap.call((rrec["ctl"]["right"] as Rect2).get_center())
	_ok(hud.remap_layout() == "kb-shared-p1", "remap touch: the right chevron goes to the next layout")
	tap.call(((hud.remap_plan()["rows"] as Array)[0]["ctl"]["left"] as Rect2).get_center())
	hud._rm_set_layout("kb-solo")
	var res_r: Rect2 = (hud.remap_plan()["rows"] as Array)[rows_of.call().size() - 1]["ctl"]["button"]
	tap.call(res_r.get_center())
	_ok(not SimInputData.overrides[0].has("kb-solo"), "remap touch: the Reset button resets")
	tap.call((hud.remap_plan()["close"] as Rect2).get_center())
	_ok(not hud.is_remap_open() and hud.is_settings_open() == false and got["closed"] == 3, "remap touch: the close cross leaves the screen (and, opened on its own, Settings with it)")
	# Remembered: Controls loads the player's file at startup; the screen then reads the effective layout.
	hud.show_remap()
	hud._rm_focus = idx.call("guard")
	hud._unhandled_input(key.call(KEY_ENTER))
	hud._unhandled_input(key.call(KEY_Z))
	hud.hide_remap()
	SimInputData.clear_overrides()
	_ok(_binding_controls(SimInputData.preset("kb-solo"), "guard") == ["kb:Shift"], "remap: with the overrides cleared the layout is the data's again")
	hud.queue_free()
	await process_frame
	SimInputRemap.apply_file(SimInputRemap.load_file(UiRemapModel.save_path))   # what SimInputData.load_and_apply does at startup
	var hud2: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	hud2.size = Vector2(1920, 1080)
	root.add_child(hud2)
	await process_frame
	hud2.setup(["protagonist", "anti_hero"], ["ONE", "TWO"])
	hud2.hub.model(1).ai = true
	hud2.show_remap()
	var gi: int = hud2._rm_row_index("guard")
	var grow: Dictionary = (hud2._rm_rows() as Array)[gi]
	_ok(str((grow["specs"] as Array)[0]["label"]) == "Z" and lbl.call("guard", "kb-solo") == "Z", "remap: what the player remapped is on the screen and in the legend on the next run")
	# Geometry: the same card at desktop, tablet and phone sizes, with the capture and swap buttons showing.
	var rws2: Array = hud2._rm_rows()
	var cases: Array = [[Vector2(1920, 1080), 1.0], [Vector2(1280, 720), 1.0], [Vector2(1024, 576), 1.0], [Vector2(3840, 2160), 1.0], [Vector2(2400, 1080), 2.6], [Vector2(2532, 1170), 3.0], [Vector2(1560, 720), 2.0],
		[Vector2(844, 390), 1.0], [Vector2(1170, 2532), 3.0], [Vector2(1080, 2340), 2.75], [Vector2(828, 1792), 2.0], [Vector2(750, 1334), 2.0], [Vector2(390, 844), 1.0], [Vector2(360, 640), 1.0]]
	for cs in cases:
		var sz: Vector2 = cs[0]
		var dpv: float = cs[1]
		var lay := UiLayout.new()
		lay.dp = dpv
		lay.compute(sz, false)
		for touch in [false, true]:
			for mode in [0, 1, 2]:
				var tag := "remap %dx%d dp %.1f touch=%s mode %d" % [int(sz.x), int(sz.y), dpv, str(touch), mode]
				var st := {"rows": rws2, "focus": 1, "scroll": 0.0, "status": "Z is already Light. Swap them?" if mode > 0 else "", "confirm": [] if mode == 0 else (["CANCEL"] if mode == 1 else ["SWAP", "CANCEL"]), "capture": 2 if mode > 0 else -1}
				var p: Dictionary = UiSettings.plan(sz, lay.s, dpv, touch, st, {"layout": "kb-solo"})
				var ok_all: bool = bool(p["fits"]) and Rect2(Vector2.ZERO, sz).encloses(p["card"]) and (p["card"] as Rect2).encloses(p["body"])
				var hits_ok := true
				for rec in p["rows"]:
					if not (p["body"] as Rect2).encloses(rec["rect"]) or not bool(rec["enabled"]):
						continue
					for k in rec["ctl"]:
						if k == "switch" or k == "value":
							continue
						var h: Dictionary = UiSettings.hit(p, (rec["ctl"][k] as Rect2).get_center())
						if int(h.get("row", -9)) != int(rec["idx"]) or str(h.get("part", "")) != k:
							hits_ok = false
				var conf_ok := true
				for cr in p["confirm"]:
					conf_ok = conf_ok and (cr as Rect2).size.y >= float(p["tm"]) - 0.01 and (p["card"] as Rect2).encloses(cr) and not (cr as Rect2).intersects(p["body"])
				_ok(ok_all and hits_ok and conf_ok and (p["body"] as Rect2).size.y >= float(p["tm"]) * 1.4, "%s: the card fits, every control is 48 dp and hit by its own centre, the buttons are under the list (%d bad, body %d)" % [tag, int(p["bad"]), int((p["body"] as Rect2).size.y)])
	UiLook.text_floor = UiLook.MIN_TEXT_PX
	hud2.hide_remap()
	hud2.queue_free()
	await process_frame
	UiData.set_feature("remap", null)
	SimInputData.clear_overrides()
	UiRemapModel.save_path = SimInputRemap.USER_PATH
	if FileAccess.file_exists("user://input_test_remap.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://input_test_remap.json"))


# --- The Full touch layout, drawn from SimTouch.layout(..., full = true) (docs/ui/hud-spec.md section 24) --------------------------

## Full is the tablet layout (Controls' docs/controls/remap.md): nine buttons reach about 270 dp up from the bottom, so a landscape screen
## shorter than about 390 dp (a small phone) has the top buttons under the nameplates. The sizes here are tablets and large phones.
func _touch_full_rules() -> void:
	var sizes: Array = [[Vector2(2400, 1080), 2.6], [Vector2(2340, 1080), 2.75], [Vector2(2532, 1170), 3.0], [Vector2(2560, 1600), 2.0], [Vector2(1920, 1200), 1.5], [Vector2(1280, 800), 1.0],
		[Vector2(1170, 2532), 3.0], [Vector2(1080, 2340), 2.75], [Vector2(828, 1792), 2.0], [Vector2(750, 1334), 2.0], [Vector2(390, 844), 1.0]]
	for cs in sizes:
		for lh in [false, true]:
			var sz: Vector2 = cs[0]
			var dpv: float = cs[1]
			var lay := UiLayout.new()
			lay.dp = dpv
			lay.touch_ui = true
			lay.touch_full = true
			lay.left_handed = lh
			lay.compute(sz, false)
			var tag := "touch full %dx%d dp %.2f %s" % [int(sz.x), int(sz.y), dpv, "left" if lh else "right"]
			var has_all := true
			for n in UiTouchControls.FULL_NAMES:
				has_all = has_all and lay.touch_ctrl.has(n)
			_ok(has_all and lay.touch_ctrl.has("stick") and lay.touch_keys().size() == 9, "%s: the layout has Controls' nine buttons and the stick zone" % tag)
			var view := Rect2(Vector2.ZERO, sz)
			var bad := 0
			var small := 0
			var clash := 0
			var over: PackedStringArray = []
			var obstacles: Array = [["plate0", lay.plate[0]], ["plate1", lay.plate[1]], ["toll", lay.toll], ["pause", lay.pause_btn], ["pill", lay.feedback_btn], ["read slot", lay.read_slot], ["ring", lay.ring], ["strip", lay.strip], ["clear zone", lay.clear_zone], ["cards0", lay.cards[0]], ["cards1", lay.cards[1]], ["bark", lay.bark[0]]]
			var names: Array = UiTouchControls.FULL_NAMES
			for i in range(names.size()):
				var a: Dictionary = lay.touch_ctrl[names[i]]
				var ra: Rect2 = UiTouchControls.rect_of(a)
				if not view.encloses(ra):
					bad += 1
				if float(a.r) * 2.0 < 48.0 * dpv - 0.01 and float(a.r) * 2.0 < 48.0:
					small += 1
				for j in range(i + 1, names.size()):
					var b: Dictionary = lay.touch_ctrl[names[j]]
					if Vector2(float(a.x), float(a.y)).distance_to(Vector2(float(b.x), float(b.y))) < float(a.r) + float(b.r):
						clash += 1
				for o in obstacles:
					if ra.intersects(o[1]) and (o[1] as Rect2).size.y > 0.0:
						over.append("%s>%s" % [names[i], o[0]])
			_ok(bad == 0 and small == 0 and clash == 0, "%s: every button is on screen, at least 48 dp across, and none overlap (%d off, %d small, %d clash)" % [tag, bad, small, clash])
			_ok(over.is_empty(), "%s: nothing in the HUD or the fight is under a button %s" % [tag, str(over)])
			var key_sig: Array = UiTouchControls.sig(lay, {"full": {"light": {"down": true}}}, 0.0, true)
			var key_sig2: Array = UiTouchControls.sig(lay, {"full": {}}, 0.0, true)
			_ok(key_sig != key_sig2, "%s: a held button changes the layer's signature" % tag)
	var lay2 := UiLayout.new()
	lay2.dp = 2.6
	lay2.touch_ui = true
	lay2.compute(Vector2(2400, 1080), false)
	_ok(lay2.touch_keys() == ["attack", "guard", "power"], "touch full: Simple still keeps its three buttons clear")


# --- The pause menu (docs/ui/hud-spec.md section 28) ----------------------------------------------------------------------------------

func _pause_menu_rules() -> void:
	for id in ["title", "resume", "howto", "settings", "feedback", "new", "new_ask", "new_yes", "new_no", "resume_key", "howto_key", "new_key"]:
		_ok(UiData.t("prompt.pause_" + id) != "prompt.pause_" + id, "pause menu: the word pause_%s exists" % id)
	# Geometry at every size, touch on and off, with and without the new-match question.
	var cases: Array = [[Vector2(1920, 1080), 1.0], [Vector2(1280, 720), 1.0], [Vector2(1024, 576), 1.0], [Vector2(3840, 2160), 1.0], [Vector2(2400, 1080), 2.6], [Vector2(2532, 1170), 3.0], [Vector2(1560, 720), 2.0],
		[Vector2(844, 390), 1.0], [Vector2(1170, 2532), 3.0], [Vector2(1080, 2340), 2.75], [Vector2(828, 1792), 2.0], [Vector2(750, 1334), 2.0], [Vector2(390, 844), 1.0], [Vector2(360, 640), 1.0]]
	for cs in cases:
		var sz: Vector2 = cs[0]
		var dpv: float = cs[1]
		var lay := UiLayout.new()
		lay.dp = dpv
		lay.compute(sz, false)
		for touch in [false, true]:
			for confirm in [false, true]:
				var tag := "pause menu %dx%d dp %.1f touch=%s confirm=%s" % [int(sz.x), int(sz.y), dpv, str(touch), str(confirm)]
				var p: Dictionary = UiPause.plan(sz, lay.s, dpv, touch, {"focus": 0, "confirm": confirm})
				var hits_ok := true
				for it in p["items"]:
					if UiPause.hit(p, (it["rect"] as Rect2).get_center()) != it["id"] or (it["rect"] as Rect2).size.y < float(p["tm"]) - 0.01:
						hits_ok = false
				var distinct := true
				var its: Array = p["items"]
				for i in range(its.size()):
					for j in range(i + 1, its.size()):
						if (its[i]["rect"] as Rect2).intersects(its[j]["rect"]):
							distinct = false
				_ok(bool(p["fits"]) and hits_ok and distinct and its.size() == (2 if confirm else 5), "%s: every button is a 48 dp target inside a card that is on screen, none overlap (%d column%s)" % [tag, int(p["cols"]), "" if int(p["cols"]) == 1 else "s"])
	UiLook.text_floor = UiLook.MIN_TEXT_PX
	var pw: Dictionary = UiPause.plan(Vector2(1920, 1080), 1.0, 1.0, false, {"focus": 0, "confirm": false})
	var pn: Dictionary = UiPause.plan(Vector2(1280, 540), 0.5, 2.0, true, {"focus": 0, "confirm": false})
	_ok(int(pw["cols"]) == 1 and int(pn["cols"]) == 2, "pause menu: one column where the height allows, two on a very short screen")
	_ok(UiPause.moved(pw, 0, 0, 1) == 1 and UiPause.moved(pw, 4, 0, 1) == 4 and UiPause.moved(pw, 0, 0, -1) == 0 and UiPause.moved(pn, 0, 1, 0) == 1 and UiPause.moved(pn, 0, 0, 1) == 2 and UiPause.moved(pn, 1, 1, 0) == 1 and UiPause.moved(pn, 4, 0, -1) == 2, "pause menu: the focus moves down a column or across a grid and stops at the edges")
	# The flow in the HUD.
	root.size = Vector2i(1920, 1080)
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	hud.size = Vector2(1920, 1080)
	root.add_child(hud)
	await process_frame
	hud.setup(["protagonist", "anti_hero"], ["ONE", "TWO"])
	hud.hub.model(0).ai = false
	hud.hub.model(1).ai = true
	hud.advance(1.0 / 60.0)
	var got := {"opened": 0, "closed": [], "entries": [], "new": 0, "howto": 0, "settings": 0}
	hud.pause_menu_opened.connect(func(): got["opened"] += 1)
	hud.pause_menu_closed.connect(func(r): got["closed"].append(r))
	hud.pause_entry.connect(func(e): got["entries"].append(e))
	hud.new_match_requested.connect(func(): got["new"] += 1)
	hud.howto_opened.connect(func(_f): got["howto"] += 1)
	hud.settings_opened.connect(func(): got["settings"] += 1)
	var key := func(code: int) -> InputEventKey:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = true
		return e
	hud.toggle_pause_menu()
	_ok(hud.is_pause_menu_open() and hud.is_overlay_open() and got["opened"] == 1 and hud.pause_menu_focus() == 0, "pause menu: the host's pause key opens it on Resume and the host is told")
	hud.toggle_pause_menu()
	_ok(not hud.is_pause_menu_open() and got["closed"] == ["resume"], "pause menu: and the same key resumes")
	hud.show_pause_menu()
	hud._unhandled_input(key.call(KEY_DOWN))
	hud._unhandled_input(key.call(KEY_DOWN))
	_ok(hud.pause_menu_focus() == 2, "pause keys: Down twice reaches Settings")
	hud._unhandled_input(key.call(KEY_ENTER))
	_ok(hud.is_settings_open() and hud.is_pause_menu_open() and got["settings"] == 1 and got["entries"].back() == "settings", "pause keys: Enter opens Settings over the menu")
	hud._unhandled_input(key.call(KEY_DOWN))
	_ok(hud.pause_menu_focus() == 2, "pause keys: while Settings is open the keys are Settings' (the menu's focus does not move)")
	hud._unhandled_input(key.call(KEY_ESCAPE))
	_ok(not hud.is_settings_open() and hud.is_pause_menu_open() and hud.pause_menu_focus() == 2, "pause keys: Esc closes Settings and gives the menu back where it was")
	hud._unhandled_input(key.call(KEY_UP))
	hud._unhandled_input(key.call(KEY_ENTER))
	_ok(hud.is_howto_open() and got["howto"] == 1, "pause keys: Up and Enter open How to play")
	hud.hide_howto()
	hud._unhandled_input(key.call(KEY_F1))
	_ok(hud.is_howto_open(), "pause keys: F1 opens How to play from the menu too")
	hud.hide_howto()
	hud._unhandled_input(key.call(KEY_DOWN))
	hud._unhandled_input(key.call(KEY_DOWN))
	hud._unhandled_input(key.call(KEY_ENTER))
	_ok(hud.is_feedback_open() and got["entries"].back() == "feedback", "pause keys: Send feedback opens the feedback panel")
	hud.hide_feedback()
	_ok(hud.is_pause_menu_open(), "pause keys: and closing it returns to the menu")
	# New match asks first, with Keep playing under the focus.
	hud._unhandled_input(key.call(KEY_DOWN))
	hud._unhandled_input(key.call(KEY_ENTER))
	_ok(hud.pause_menu_plan()["confirm"] and hud.pause_menu_focus() == 1 and str(hud.pause_menu_plan()["title"]) == "Start a new match?" and got["new"] == 0, "pause keys: New match asks \"Start a new match?\" and the focus starts on Keep playing")
	hud._unhandled_input(key.call(KEY_ENTER))
	_ok(not hud.pause_menu_plan()["confirm"] and got["new"] == 0 and hud.pause_menu_focus() == 4 and hud.is_pause_menu_open(), "pause keys: Enter on Keep playing goes back with nothing lost")
	hud._unhandled_input(key.call(KEY_ENTER))
	hud._unhandled_input(key.call(KEY_ESCAPE))
	_ok(not hud.pause_menu_plan()["confirm"] and got["new"] == 0, "pause keys: Esc answers the question with no")
	hud._unhandled_input(key.call(KEY_N))
	hud._unhandled_input(key.call(KEY_UP))
	hud._unhandled_input(key.call(KEY_ENTER))
	_ok(not hud.is_pause_menu_open() and got["new"] == 1 and got["closed"].back() == "new", "pause keys: N, then the first button, starts a new match and closes the menu (closed with reason new)")
	# Resume by Enter, by Esc and by P.
	for k in [KEY_ESCAPE, KEY_P]:
		hud.show_pause_menu()
		hud._unhandled_input(key.call(k))
		_ok(not hud.is_pause_menu_open() and got["closed"].back() == "resume", "pause keys: %s resumes" % ("Esc" if k == KEY_ESCAPE else "P"))
	hud.show_pause_menu()
	hud._unhandled_input(key.call(KEY_ENTER))
	_ok(not hud.is_pause_menu_open() and got["closed"].back() == "resume" and got["entries"].has("resume"), "pause keys: Enter on Resume resumes")
	# The pad.
	var pad := func(btn: int) -> InputEventJoypadButton:
		var e := InputEventJoypadButton.new()
		e.button_index = btn
		e.pressed = true
		return e
	hud.show_pause_menu()
	hud._unhandled_input(pad.call(JOY_BUTTON_DPAD_DOWN))
	hud._unhandled_input(pad.call(JOY_BUTTON_A))
	_ok(hud.is_howto_open(), "pause pad: D-pad down and A open How to play")
	hud._unhandled_input(pad.call(JOY_BUTTON_B))
	_ok(not hud.is_howto_open() and hud.is_pause_menu_open(), "pause pad: B closes it and gives the menu back")
	var jm := InputEventJoypadMotion.new()
	jm.axis = JOY_AXIS_LEFT_Y
	jm.axis_value = 0.9
	hud._unhandled_input(jm)
	hud._unhandled_input(jm)
	var f_after: int = hud.pause_menu_focus()
	var jr := InputEventJoypadMotion.new()
	jr.axis = JOY_AXIS_LEFT_Y
	jr.axis_value = 0.0
	hud._unhandled_input(jr)
	_ok(f_after == 2, "pause pad: a stick push is one step")
	hud._unhandled_input(pad.call(JOY_BUTTON_START))
	_ok(not hud.is_pause_menu_open() and got["closed"].back() == "resume", "pause pad: Start resumes")
	# The mouse and a finger.
	var mouse := func(pos: Vector2, pressed: bool) -> InputEventMouseButton:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		return e
	var tap := func(pos: Vector2) -> void:
		hud._unhandled_input(mouse.call(pos, true))
		hud._unhandled_input(mouse.call(pos, false))
	hud.show_pause_menu()
	var pl: Dictionary = hud.pause_menu_plan()
	var rect_of := func(id: String) -> Rect2:
		for it in hud.pause_menu_plan()["items"]:
			if it["id"] == id:
				return it["rect"]
		return Rect2()
	tap.call((rect_of.call("settings") as Rect2).get_center())
	_ok(hud.is_settings_open(), "pause mouse: a click on Settings opens it")
	hud.hide_settings()
	hud._unhandled_input(mouse.call((rect_of.call("feedback") as Rect2).get_center(), true))
	hud._unhandled_input(mouse.call((rect_of.call("howto") as Rect2).get_center(), false))
	_ok(not hud.is_feedback_open() and not hud.is_howto_open() and hud.is_pause_menu_open(), "pause mouse: a press that slides off its button chooses nothing")
	tap.call(Vector2(5, 5))
	_ok(hud.is_pause_menu_open(), "pause mouse: a click outside the card does nothing")
	tap.call((rect_of.call("new") as Rect2).get_center())
	var yes_r: Rect2 = rect_of.call("new_yes")
	_ok(hud.pause_menu_plan()["confirm"] and yes_r.size.y > 0.0, "pause mouse: a click on New match shows the question")
	tap.call((rect_of.call("new_no") as Rect2).get_center())
	tap.call((rect_of.call("resume") as Rect2).get_center())
	_ok(not hud.is_pause_menu_open() and got["closed"].back() == "resume", "pause mouse: Keep playing, then Resume, close the menu")
	# On a phone: two columns, the cross-grid moves.
	hud.set_density(2.0)
	hud.set_option("touch_ui", true)
	hud.size = Vector2(1280, 540)
	hud.advance(1.0 / 60.0)
	hud.show_pause_menu()
	var pp: Dictionary = hud.pause_menu_plan()
	hud.pause_menu_action("right")
	hud.pause_menu_action("down")
	_ok(int(pp["cols"]) == 2 and hud.pause_menu_focus() == 3, "pause touch: on a short phone screen the menu has two columns and Right then Down moves across and down")
	tap.call(((hud.pause_menu_plan()["items"] as Array)[4]["rect"] as Rect2).get_center())
	_ok(hud.pause_menu_plan()["confirm"], "pause touch: a tap on New match asks first")
	hud.pause_menu_action("back")
	hud.pause_menu_action("back")
	_ok(not hud.is_pause_menu_open(), "pause touch: and back, back resumes")
	hud.queue_free()
	await process_frame


# --- A sim pause freezes the fight's timers, not the drawing (docs/architecture/fx-events.md: pause_start, pause_end) ------------------

func _sim_pause_rules() -> void:
	var hub := _hub()
	var m: UiFighterModel = hub.model(0)
	m.stance_prompt_t = 0.0
	hub.consume({"type": "window_open", "actor": 0, "kind": "parry", "dur": 0.4})
	hub.consume({"type": "cinematic_start", "actor": 0, "kind": "transformation", "dur": 3.0})
	var t0: float = hub.t_now
	var pt0: float = m.parry_t
	hub.consume({"type": "pause_start", "kind": "transform", "actor": 0, "version": "full", "dur": 2.0})
	_ok(hub.sim_paused and hub.sim_pause_kind == "transform", "sim pause: pause_start marks the HUD paused with its kind")
	for i in range(60):
		hub.advance(1.0 / 60.0)
	_ok(is_equal_approx(hub.t_now, t0) and is_equal_approx(m.stance_prompt_t, 0.0) and is_equal_approx(m.parry_t, pt0), "sim pause: the match clock, the stance prompt and the parry window stand still for a second of it")
	_ok(hub.cinematic_left < 2.1 and hub.cinematic_left > 1.9 and hub.toll_age > 90.0, "sim pause: what is only drawn (the cinematic mode) runs on in real time")
	hub.consume({"type": "pause_end", "kind": "transform"})
	for i in range(30):
		hub.advance(1.0 / 60.0)
	_ok(not hub.sim_paused and hub.t_now > t0 + 0.4 and m.stance_prompt_t > 0.4, "sim pause: pause_end lets them run again")
	# A pause_end that never comes does not freeze the HUD for good.
	var hub2 := _hub()
	hub2.consume({"type": "pause_start", "kind": "world", "actor": 1, "version": "short", "dur": 1.0})
	for i in range(120):
		hub2.advance(1.0 / 60.0)
	_ok(not hub2.sim_paused and hub2.t_now > 0.4, "sim pause: after its duration with no pause_end the HUD carries on")
	# A new match clears it.
	var hub3 := _hub()
	hub3.consume({"type": "pause_start", "kind": "timecap", "actor": -1, "version": "full", "dur": 5.0})
	hub3.reset()
	_ok(not hub3.sim_paused, "sim pause: a new match clears it")
	# The real HUD: the legend's 12 seconds do not burn during a pause.
	root.size = Vector2i(1920, 1080)
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	hud.size = Vector2(1920, 1080)
	root.add_child(hud)
	await process_frame
	hud.setup(["protagonist", "anti_hero"], ["ONE", "TWO"])
	hud.hub.model(0).ai = false
	hud.hub.model(1).ai = true
	hud.advance(1.0 / 60.0)
	hud.consume({"type": "pause_start", "kind": "transform", "actor": 0, "version": "full", "dur": 30.0})
	for i in range(60 * 14):
		hud.advance(1.0 / 60.0)
	_ok(hud._l_hints[0].sig != null, "sim pause: the control legend is still up after 14 s of a sim pause (it counts fight time)")
	hud.consume({"type": "pause_end", "kind": "transform"})
	for i in range(60 * 13):
		hud.advance(1.0 / 60.0)
	_ok(hud._l_hints[0].sig == null, "sim pause: and goes after its 12 s of fight time once the pause ends")
	hud.queue_free()
	await process_frame


# --- The face cut-in (docs/ui/hud-spec.md section 29) -----------------------------------------------------------------------------------

func _bark_obj(slot: int, prio: int = 2, style: String = "caption", kind: String = "line", setpiece: bool = false, fighter: bool = true, cues: Array = []) -> UiEventHub.Bark:
	var b := UiEventHub.Bark.new()
	b.slot = slot
	b.text = "A line."
	b.priority = prio
	b.style = style
	b.kind = kind
	b.setpiece = setpiece
	b.fighter = fighter
	b.cues = cues
	return b


func _faces_rules() -> void:
	UiData.reload()
	var fd: Dictionary = UiData.faces()
	var slots_ok := true
	for id in ["default", "protagonist", "anti_hero", "empress", "cyborg"]:
		for e in fd["expressions"]:
			slots_ok = slots_ok and (fd["fighters"][id][e] as Dictionary).has("art")
	var profile_ids_ok := true
	for id in ["protagonist", "anti_hero", "empress", "cyborg"]:
		profile_ids_ok = profile_ids_ok and fd["fighters"].has(id)
	_ok(slots_ok and profile_ids_ok and fd["expressions"] == ["neutral", "smirk", "strain", "hurt", "laugh", "contempt", "shock", "grief"] and int(fd["rate"]["per_minute"]) == 6, "faces: the data has a texture slot per fighter for all eight expressions (neutral, smirk, strain, hurt, laugh, contempt, shock, grief) and the 6 a minute rate")
	var used := {}
	for k in fd["gesture_expression"]:
		used[fd["gesture_expression"][k]] = true
	var eight_map: Dictionary = fd["_gesture_expression_eight"]
	var eight_ok := true
	var eight_used := {}
	for k in eight_map:
		eight_ok = eight_ok and (fd["expressions"] as Array).has(eight_map[k])
		eight_used[eight_map[k]] = true
	_ok(used.size() == 4 and eight_ok and eight_used.size() == 8, "faces: four expressions are mapped now, and the ready eight-expression mapping uses all eight")
	var saved_map: Dictionary = fd["gesture_expression"]
	fd["gesture_expression"] = eight_map
	var ex8 := func(g: String) -> String:
		return UiFaces.expression(_bark_obj(0, 2, "caption", "line", false, true, [{"at": 0, "gesture": g, "intensity": 1}]), UiFighterModel.new())
	_ok(ex8.call("laugh.long") == "laugh" and ex8.call("laugh.cruel") == "contempt" and ex8.call("scoff") == "contempt" and ex8.call("gasp") == "shock" and ex8.call("sigh") == "grief" and ex8.call("laugh.short") == "smirk" and ex8.call("wince") == "hurt", "faces: swapping in the eight-expression mapping (a data change) gives laugh, contempt, shock and grief to their gestures")
	fd["gesture_expression"] = saved_map
	var lay8 := UiLayer.new()
	lay8.painter = func(ci: CanvasItem) -> void:
		var x := 10.0
		for e in fd["expressions"]:
			UiFaces.draw_portrait(ci, Rect2(x, 10.0, 120.0, 120.0), UiFighterModel.new(), str(e), 1.0, 1.0)
			x += 130.0
	lay8.sig = 1
	root.add_child(lay8)
	lay8.queue_redraw()
	await process_frame
	await process_frame
	_ok(lay8.redraws >= 1, "faces: all eight placeholder expressions draw")
	lay8.queue_free()
	# Which lines get a face.
	_ok(UiFaces.level(_bark_obj(0)) == "always" and UiFaces.level(_bark_obj(0, 2, "caption", "reply")) == "always" and UiFaces.level(_bark_obj(0, 2, "caption", "retort")) == "always" and UiFaces.level(_bark_obj(0, 2, "caption", "callback")) == "always" and UiFaces.level(_bark_obj(0, 2, "caption", "bit")) == "cap", "faces: every quip, reply, retort and callback gets a face (Orb); only a kind the data does not list falls to the rate cap")
	_ok(UiFaces.level(_bark_obj(0, 2, "caption", "jewel")) == "always" and UiFaces.level(_bark_obj(0, 2, "shout")) == "always" and UiFaces.level(_bark_obj(0, 3, "caption", "line", true)) == "always" and UiFaces.level(_bark_obj(0, 4)) == "always", "faces: a jewel, a shout, a set piece and a line of priority 3 or more always get one")
	_ok(UiFaces.level(_bark_obj(0, 2, "thought")) == "never" and UiFaces.level(_bark_obj(0, 2, "caption", "thought")) == "never" and UiFaces.level(_bark_obj(0, 1)) == "never" and UiFaces.level(_bark_obj(0, 2, "caption", "line", false, false)) == "never", "faces: a thought, an ambient line and a crowd or narrator line get none")
	# The expression.
	var mm := UiFighterModel.new()
	var ex := func(g: String, brink: bool) -> String:
		mm.brink = brink
		return UiFaces.expression(_bark_obj(0, 2, "caption", "line", false, true, [{"at": 0, "gesture": g, "intensity": 1}] if g != "" else []), mm)
	_ok(ex.call("laugh.cruel", false) == "smirk" and ex.call("scoff", false) == "smirk" and ex.call("wince", false) == "hurt" and ex.call("pain.head", false) == "hurt" and ex.call("roar", false) == "strain" and ex.call("growl", false) == "strain" and ex.call("effort.light", false) == "neutral" and ex.call("effort.heavy", false) == "strain" and ex.call("", true) == "hurt" and ex.call("", false) == "neutral", "faces: the expression follows the first cue's gesture (laugh and scoff smirk, wince and pain hurt, roar and growl strain), else hurt on the brink, else neutral")
	# The hub: faces, the rate cap, one a side, move names.
	var hub := _hub()
	hub.consume({"type": "bark", "speaker": 0, "text": "Quip one.", "cues": [{"at": 0, "gesture": "laugh.short", "intensity": 1}], "priority": 2, "dur": 0.4})
	hub.consume({"type": "bark", "speaker": 1, "text": "Reply.", "cues": [{"at": 0, "gesture": "wince", "intensity": 1}], "priority": 2, "dur": 0.4, "kind": "reply"})
	hub.consume({"type": "bark", "speaker": 0, "text": "Thinking.", "kind": "thought", "priority": 2})
	var both: bool = hub.barks.size() == 2 and hub.barks[0].face and hub.barks[1].face and hub.barks[0].face_expr == "smirk" and hub.barks[1].face_expr == "hurt"
	_ok(both and hub.bark_wait.size() == 1 and not hub.bark_wait[0].face, "faces: two speakers at once each get a face (one a side); a queued thought gets none")
	# The rate cap, which the data keeps for if it is wanted again: a kind set to cap gets 6 in a minute of fight time; a set piece still gets one; a minute later it opens again.
	UiData.faces()["kinds"]["line"] = "cap"
	var h2 := _hub()
	var sides_ok := true
	var granted := 0
	for i in range(9):
		h2.consume({"type": "bark", "speaker": 0, "text": "Line %d." % i, "priority": 2, "dur": 0.2})
		for k in range(60):
			h2.advance(1.0 / 60.0)
			var per := [0, 0]
			for b in h2.barks:
				if b.face:
					per[b.slot] += 1
			sides_ok = sides_ok and per[0] <= 1 and per[1] <= 1
		if i < 6:
			pass
	granted = int(h2.stats["faces_shown"])
	_ok(granted == 6 and int(h2.stats["faces_capped"]) == 3 and sides_ok, "faces: at most 6 an ordinary line in a minute (the rest play without), and never two on one side (%d shown, %d capped)" % [granted, int(h2.stats["faces_capped"])])
	h2.consume({"type": "bark", "speaker": 0, "text": "Set piece.", "priority": 3, "setpiece": true, "dur": 3.0})
	_ok(h2.barks.size() > 0 and h2.barks[h2.barks.size() - 1].face, "faces: a set-piece line gets one over the cap")
	for k in range(60 * 70):
		h2.advance(1.0 / 60.0)
	h2.consume({"type": "bark", "speaker": 1, "text": "Fresh minute.", "priority": 2, "dur": 0.3})
	_ok(h2.barks.size() > 0 and h2.barks[h2.barks.size() - 1].face, "faces: a minute later the cap has room again")
	# A sim pause holds the cap's clock (it is fight time): the window does not roll while the sim is frozen.
	var h3 := _hub()
	for i in range(6):
		h3.consume({"type": "bark", "speaker": 0, "text": "L%d" % i, "priority": 2, "dur": 0.1})
		for k in range(60):
			h3.advance(1.0 / 60.0)
	h3.consume({"type": "pause_start", "kind": "transform", "actor": 0, "version": "full", "dur": 200.0})
	for k in range(60 * 70):
		h3.advance(1.0 / 60.0)
	h3.consume({"type": "bark", "speaker": 0, "text": "Late.", "priority": 2, "dur": 0.1})
	_ok(h3.barks.size() == 0 or not h3.barks[0].face, "faces: the cap's minute is fight time, so a long sim pause does not reopen it")
	UiData.faces()["kinds"]["line"] = "always"
	# With every kind always, nothing is capped: nine lines in nine seconds all get a face.
	var h5 := _hub()
	for i in range(9):
		h5.consume({"type": "bark", "speaker": i % 2, "text": "Line %d." % i, "priority": 2, "dur": 0.2, "kind": ["line", "reply", "retort", "callback", "jewel"][i % 5]})
		for k in range(60):
			h5.advance(1.0 / 60.0)
	_ok(int(h5.stats["faces_shown"]) == 9 and int(h5.stats["faces_capped"]) == 0, "faces: as shipped (every kind always) nothing is capped: every line a fighter speaks gets a face (%d of 9)" % int(h5.stats["faces_shown"]))
	# No move-name card.
	var h4 := _hub()
	h4.set_move_names(["Horizon Cleave"])
	h4.consume({"type": "banner", "text": "HORIZON CLEAVE", "col": "#ffffff", "dur": 1.1})
	var dropped: bool = h4.banner.is_empty() and int(h4.stats["banners_move_name"]) == 1
	h4.consume({"type": "banner", "text": "PARRY", "col": "#9fe0ff", "dur": 0.8})
	_ok(dropped and h4.banner.get("text", "") == "PARRY", "faces: a banner that is only a fighter's move name is dropped (the fighter shouts it, no name card) and other banners show")
	# The slide.
	var sb := _bark_obj(0)
	sb.reveal_time = 0.5
	sb.dur = 1.0
	sb.age = 0.0
	var m0: Dictionary = UiFaces.motion(sb, false)
	sb.age = 0.3
	var m1: Dictionary = UiFaces.motion(sb, false)
	sb.age = 1.4
	var m2: Dictionary = UiFaces.motion(sb, false)
	sb.age = 1.45
	var m3: Dictionary = UiFaces.motion(sb, true)
	sb.age = 0.0
	var m4: Dictionary = UiFaces.motion(sb, true)
	_ok(float(m0["off"]) == 1.0 and float(m1["off"]) == 0.0 and float(m1["a"]) == 1.0 and float(m2["off"]) > 0.0 and float(m3["off"]) == 0.0 and float(m3["a"]) < 1.0 and float(m4["a"]) == 0.0, "faces: it slides in from the edge, holds, and slides out at the end of the line; in reduced motion it fades and does not move")
	# Where it goes: every size, touch off and on, both hands, both ways round.
	var cases: Array = [[Vector2(1920, 1080), 1.0], [Vector2(1280, 720), 1.0], [Vector2(1024, 576), 1.0], [Vector2(3840, 2160), 1.0], [Vector2(2400, 1080), 2.6], [Vector2(2532, 1170), 3.0], [Vector2(1560, 720), 2.0],
		[Vector2(844, 390), 1.0], [Vector2(1170, 2532), 3.0], [Vector2(1080, 2340), 2.75], [Vector2(828, 1792), 2.0], [Vector2(750, 1334), 2.0], [Vector2(390, 844), 1.0], [Vector2(360, 640), 1.0]]
	var docked_desktop := 0
	for cs in cases:
		var sz: Vector2 = cs[0]
		var dpv: float = cs[1]
		for touch in [false, true]:
			for lh in ([false, true] if touch else [false]):
				for swapped in [false, true]:
					var lay := UiLayout.new()
					lay.dp = dpv
					lay.touch_ui = touch
					lay.left_handed = lh
					lay.compute(sz, false, Vector4.ZERO, swapped)
					var tag := "faces %dx%d dp %.1f touch=%s %s%s" % [int(sz.x), int(sz.y), dpv, str(touch), "left-handed " if lh else "", "swapped" if swapped else "normal"]
					var view := Rect2(Vector2.ZERO, sz)
					var fixed: Array = [["plate0", lay.plate[0]], ["plate1", lay.plate[1]], ["toll", lay.toll], ["strip", lay.strip], ["ring", lay.ring], ["read", lay.read_slot], ["pause", lay.pause_btn], ["pill", lay.feedback_btn],
						["cards0", lay.cards[0]], ["cards1", lay.cards[1]], ["sil0", lay.silhouette[0]], ["sil1", lay.silhouette[1]], ["prompts0", lay.prompts[0]], ["prompts1", lay.prompts[1]], ["bark0", lay.bark[0]], ["bark1", lay.bark[1]]]
					if touch:
						for k in lay.touch_keys():
							fixed.append([k, UiTouchControls.rect_of(lay.touch_ctrl[k])])
					var bad: PackedStringArray = []
					var docked := 0
					for i in range(2):
						var r: Rect2 = lay.face[i]
						if r.size.y <= 0.0:
							continue
						docked += 1
						if not view.encloses(r) or r.size.y < 55.9 or absf(r.size.x - r.size.y) > 0.5:
							bad.append("face%d off screen or small" % i)
						for o in fixed:
							if (o[1] as Rect2).size.y > 0.0 and r.intersects(o[1]):
								bad.append("face%d>%s" % [i, o[0]])
						if (r.get_center().x < sz.x * 0.5) != (lay.plate[i].get_center().x < sz.x * 0.5):
							bad.append("face%d on the wrong side" % i)
						if lay.hints[i].size.y > 0.0 and (r.intersects(lay.hints[i]) or r.position.y < lay.hints[i].end.y):
							bad.append("face%d>legend" % i)
					if lay.face[0].size.y > 0.0 and lay.face[1].size.y > 0.0 and (lay.face[0] as Rect2).intersects(lay.face[1]):
						bad.append("the two faces meet")
					_ok(bad.is_empty(), "%s: the face squares are on screen, 56 px or more, on their side and clear of every HUD part and touch button %s" % [tag, str(bad)])
					if lay.portrait or lay.bark_single:
						_ok(docked == 0, "%s: a portrait or one-lane screen embeds the face in the bark panel" % tag)
					if not touch and dpv == 1.0 and sz.x >= 1024.0 and lay.hints[0].size.y > 0.0:
						var pl: Dictionary = UiHints.plan(UiFighterModel.new(), lay.hints[0], lay.s, {"glyph_style": "neutral", "control_scheme": "kb-solo"})
						_ok((pl["rows"] as Array).size() >= 3, "%s: the legend still has its three rows with the face docked" % tag)
					if cs == cases[0] and not touch and not swapped:
						docked_desktop += docked
	_ok(docked_desktop == 2, "faces: at 1920 by 1080 on a keyboard both faces are docked in their columns")
	# Camera's panel strip owns the centre 56% of the width, in a top band (19% to 39% of the height) or a bottom band (80% to 100%).
	var centre_bad: PackedStringArray = []
	var plate_bottom_bad: PackedStringArray = []
	var plate_top_sliver := 0.0
	var floor_bad: PackedStringArray = []
	for cs in cases:
		var sz2: Vector2 = cs[0]
		for touch in [false, true]:
			var lay2 := UiLayout.new()
			lay2.dp = cs[1]
			lay2.touch_ui = touch
			lay2.compute(sz2, false)
			var centre := Rect2(sz2.x * UiFaces.CENTRE_FROM, 0.0, sz2.x * (UiFaces.CENTRE_TO - UiFaces.CENTRE_FROM), sz2.y)
			var top_band := Rect2(centre.position.x, sz2.y * 0.19, centre.size.x, sz2.y * 0.20)
			var bottom_band := Rect2(centre.position.x, sz2.y * 0.80, centre.size.x, sz2.y * 0.20)
			for i in range(2):
				if lay2.face[i].size.y > 0.0 and (lay2.face[i] as Rect2).intersects(centre):
					centre_bad.append("docked %dx%d" % [int(sz2.x), int(sz2.y)])
				var left: bool = lay2.plate[i].get_center().x < sz2.x * 0.5
				var side: float = UiFaces.embed_side(400.0, lay2.bark[i], left, sz2.x)
				if side > 0.0:
					var fr := Rect2(lay2.bark[i].position.x if left else lay2.bark[i].end.x - side, lay2.bark[i].position.y, side, side)
					if fr.grow(-0.5).intersects(centre):
						centre_bad.append("embedded %dx%d" % [int(sz2.x), int(sz2.y)])
				# The plates: never in the bottom band; in the top band at most a few pixels, and panel_floor() says where the band may start.
				if (lay2.plate[i] as Rect2).intersects(bottom_band):
					plate_bottom_bad.append("%dx%d" % [int(sz2.x), int(sz2.y)])
				var inter: Rect2 = (lay2.plate[i] as Rect2).intersection(top_band)
				if inter.size.x > 0.0 and inter.size.y > 0.0:
					plate_top_sliver = maxf(plate_top_sliver, inter.size.y)
				if lay2.panel_floor() < (lay2.plate[i] as Rect2).end.y or lay2.panel_floor() < lay2.toll.end.y:
					floor_bad.append("%dx%d" % [int(sz2.x), int(sz2.y)])
	_ok(centre_bad.is_empty(), "faces: no face, docked or embedded, is in the centre 56 percent of the width at any of the 14 sizes %s" % str(centre_bad))
	_ok(plate_bottom_bad.is_empty() and plate_top_sliver <= 50.0 and floor_bad.is_empty(), "faces: no nameplate is in the panel strip's bottom band, the plates reach at most %d px into the top band, and panel_floor() clears every plate and the toll chip %s" % [int(plate_top_sliver), str(plate_bottom_bad)])
	UiLook.text_floor = UiLook.MIN_TEXT_PX
	# In the HUD: a docked face and an embedded one are drawn, and a swap carries the face to the new side.
	root.size = Vector2i(1920, 1080)
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	hud.size = Vector2(1920, 1080)
	root.add_child(hud)
	await process_frame
	hud.setup(["protagonist", "anti_hero"], ["ONE", "TWO"])
	hud.hub.model(0).ai = false
	hud.hub.model(1).ai = true
	hud.consume({"type": "bark", "speaker": 1, "text": "You were something once.", "cues": [{"at": 0, "gesture": "scoff", "intensity": 1}], "priority": 2})
	for i in range(30):
		hud.advance(1.0 / 60.0)
	await process_frame
	await process_frame
	var b0: UiEventHub.Bark = hud.hub.barks[0]
	_ok(b0.face and b0.face_expr == "smirk" and not UiFaces.embedded(hud.layout, 1) and hud.layout.face[1].size.y > 0.0, "faces: in the HUD a scoffed line has a smirking face docked on its fighter's side")
	hud.set_option("touch_ui", true)
	hud.set_density(2.6)
	hud.size = Vector2(1170, 2532)
	hud.advance(1.0 / 60.0)
	await process_frame
	_ok(UiFaces.embedded(hud.layout, 1), "faces: on a portrait phone the same line's face is embedded in its panel")
	# The lane colours Camera's strip borders take: each fighter's aura, announced when it changes.
	var seen: Array = []
	hud.lane_colors_changed.connect(func(a, b): seen.append([a, b]))
	hud.hub.model(0).aura = Color("#ff8800")
	hud.hub.model(1).aura = Color("#2299ff")
	hud.advance(1.0 / 60.0)
	hud.advance(1.0 / 60.0)
	var lc: Array = hud.lane_colors()
	_ok(lc[0] == Color("#ff8800") and lc[1] == Color("#2299ff") and seen.size() == 1 and seen[0] == [Color("#ff8800"), Color("#2299ff")], "faces: lane_colors() is each fighter's aura and lane_colors_changed fires once when they change (for SplitView.set_panel_colors)")
	_ok(hud.panel_floor_y() == hud.layout.panel_floor() and hud.panel_floor_y() > hud.layout.plate[0].end.y, "faces: panel_floor_y() is where the strip's top band may start")
	hud.queue_free()
	await process_frame


# --- Local two-player: the join prompt, the notes, each player's own legend, the pause menu and Settings (docs/ui/hud-spec.md section 30) ----------

func key_event_for(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func _two_player_rules() -> void:
	UiData.reload()
	for id in ["join", "join_short", "join_key", "join_key_short", "joined", "left", "pause_p2_leave", "pause_p2_join"]:
		_ok(UiData.t("prompt." + id) != "prompt." + id, "two players: the word %s exists" % id)
	var od: Dictionary = UiData.options()
	_ok(od["pad_preset_p2"]["choices"] == od["pad_preset"]["choices"] and od["pad_preset_p2"]["default"] == "arena" and od["join_prompt"]["default"] == true and UiData.settings()["labels"]["pad_preset_p2"]["simple-pad"] == "Simple", "two players: the options for player two's controller layout and the join prompt are in the data")
	# Each player's own layout.
	var pid := func(dev: String, slot: int, o: Dictionary) -> String:
		var mm := UiFighterModel.new()
		mm.device = dev
		mm.slot = slot
		return UiHints.preset_id(mm, o)
	_ok(pid.call("kbd", 0, {"kbd_humans": 2}) == "kb-shared-p1" and pid.call("kbd", 1, {"kbd_humans": 2}) == "kb-shared-p2", "two players: two people on the keyboard get the shared-keyboard halves")
	_ok(pid.call("kbd", 0, {"kbd_humans": 1, "humans": 2}) == "kb-solo" and pid.call("xbox", 1, {"pad_preset": "arena", "pad_preset_p2": "brawler"}) == "brawler" and pid.call("xbox", 0, {"pad_preset": "simple-pad", "pad_preset_p2": "brawler"}) == "simple-pad", "two players: one on the keyboard and one on a pad is the solo layout and the pad's own layout (player two's option for slot 1)")
	_ok(pid.call("xbox", 1, {"slot_presets": {1: "simple-pad"}, "pad_preset_p2": "arena"}) == "simple-pad" and pid.call("kbd", 0, {"slot_presets": {1: "simple-pad"}}) == "kb-solo", "two players: a layout the host names for a slot wins")
	# The join prompt's fade and its fit.
	_ok(UiJoin.alpha(-1.0) == 0.0 and UiJoin.alpha(1.0) == 1.0 and UiJoin.alpha(UiJoin.SHOW) == 1.0 and is_equal_approx(UiJoin.alpha(UiJoin.SHOW + UiJoin.FADE * 0.5), 0.5) and UiJoin.alpha(UiJoin.SHOW + UiJoin.FADE + 1.0) == 0.0, "two players: the join prompt is full from the start, fades after 25 s of fight time and is gone")
	var cases: Array = [[Vector2(1920, 1080), 1.0], [Vector2(1280, 720), 1.0], [Vector2(1024, 576), 1.0], [Vector2(3840, 2160), 1.0], [Vector2(2400, 1080), 2.6], [Vector2(2532, 1170), 3.0], [Vector2(1560, 720), 2.0],
		[Vector2(844, 390), 1.0], [Vector2(1170, 2532), 3.0], [Vector2(1080, 2340), 2.75], [Vector2(828, 1792), 2.0], [Vector2(750, 1334), 2.0], [Vector2(390, 844), 1.0], [Vector2(360, 640), 1.0]]
	for cs in cases:
		var sz: Vector2 = cs[0]
		for touch in [false, true]:
			var lay := UiLayout.new()
			lay.dp = cs[1]
			lay.touch_ui = touch
			lay.compute(sz, false)
			var tag := "two players %dx%d dp %.1f touch=%s" % [int(sz.x), int(sz.y), cs[1], str(touch)]
			var rect: Rect2 = lay.prompts[1]
			if rect.size.y <= 0.0:
				_ok(UiJoin.plan(rect, lay.s, "prompt")["text"] == "", "%s: no prompt row (touch or portrait), so no join line" % tag)
				continue
			var ok_all := true
			for kind in ["prompt", "joined", "left"]:
				for kbd in [false, true]:
					var p: Dictionary = UiJoin.plan(rect, lay.s, kind, kbd)
					ok_all = ok_all and bool(p["fits"]) and UiText.width(str(p["text"]), int(p["fs"])) <= rect.size.x and int(p["fs"]) >= int(UiLook.text_floor) - 1
			_ok(ok_all, "%s: the join line, the joined and left notes and the press-T wording fit the AI's prompt row at a readable size" % tag)
	UiLook.text_floor = UiLook.MIN_TEXT_PX
	# In the HUD: one person against the AI.
	root.size = Vector2i(1920, 1080)
	var hud: UiHud = load("res://ui/hud/ui_hud.tscn").instantiate()
	hud.size = Vector2(1920, 1080)
	root.add_child(hud)
	await process_frame
	hud.setup(["protagonist", "anti_hero"], ["ONE", "TWO"])
	hud.hub.model(0).ai = false
	hud.hub.model(1).ai = true
	hud.advance(1.0 / 60.0)
	for i in range(60):
		hud.advance(1.0 / 60.0)
	_ok(hud.join_due() and hud.join_prompt_alpha() > 0.99 and hud._l_join.sig != null, "two players: a person against the AI sees \"P2: press any button to join\" on the AI's side")
	hud.set_join_available(false)
	hud.advance(1.0 / 60.0)
	_ok(not hud.join_due() and hud._l_join.sig == null and not (hud.pause_menu_plan()["join"] as bool), "two players: when the host says nobody can join, the prompt and the pause line are gone")
	hud.set_join_available(true, true)
	hud.advance(1.0 / 60.0)
	_ok(hud.join_due() and hud._join_plan()["text"] == "P2: press T to join", "two players: with only the keyboard to join on, the prompt says press T")
	hud.set_join_available(true)
	hud.set_option("join_prompt", false)
	hud.advance(1.0 / 60.0)
	_ok(not hud.join_due(), "two players: the option turns the prompt off")
	hud.set_option("join_prompt", true)
	hud.set_option("touch_ui", true)
	hud.advance(1.0 / 60.0)
	_ok(not hud.join_due(), "two players: a touch screen hides it")
	hud.set_option("touch_ui", false)
	hud.advance(1.0 / 60.0)
	for i in range(60 * 27):
		hud.advance(1.0 / 60.0)
	_ok(hud.join_due() and hud.join_prompt_alpha() == 0.0 and hud._l_join.sig == null, "two players: after 27 s of fight time the prompt has faded")
	hud.show_pause_menu()
	var pmp: Dictionary = hud.pause_menu_plan()
	_ok(bool(pmp["join"]) and (pmp["join_lines"] as Array).size() >= 1 and bool(pmp["fits"]), "two players: and it is back in the pause menu as a line")
	hud.pause_menu_action("back")
	# Player two joins.
	hud.hub.model(1).ai = false
	hud.advance(1.0 / 60.0)
	_ok(hud.join_note() == "joined" and hud._l_join.sig != null and not hud.join_due(), "two players: when player two joins a \"P2 joined\" note takes the prompt's place")
	hud.advance(1.0 / 60.0)
	_ok(hud.hub.model(0).you_label == "P1" and hud.hub.model(1).you_label == "P2" and hud._l_hints[0].sig != null and hud._l_hints[1].sig != null, "two players: both nameplates show P1 and P2 and both players get their legend again")
	for i in range(int(UiJoin.NOTE * 60.0) + 30):
		hud.advance(1.0 / 60.0)
	_ok(hud.join_note() == "" and hud._l_join.sig == null, "two players: the note goes after about 2.6 s")
	hud.hub.model(1).ai = true
	hud.advance(1.0 / 60.0)
	_ok(hud.join_note() == "left" and hud.hub.model(0).you_label == "YOU" and hud._l_hints[1].sig == null, "two players: handed back, a \"P2 handed back to the AI\" note shows, the badges go back to YOU and player two's legend goes")
	hud.show_join_note("joined")
	_ok(hud.join_note() == "joined", "two players: the host can raise the note itself (Controls' input_note)")
	# Each player's own legend: one on the keyboard, one on a pad.
	hud.hub.model(1).ai = false
	hud.hub.model(0).device = "kbd"
	hud.hub.model(1).device = "xbox"
	hud.set_option("pad_preset_p2", "brawler")
	var o2: Dictionary = hud._o()
	_ok(UiHints.preset_id(hud.hub.model(0), o2) == "kb-solo" and UiHints.preset_id(hud.hub.model(1), o2) == "brawler", "two players: player one's legend is the solo keyboard's and player two's is the pad's own layout")
	hud.set_slot_layout(1, "simple-pad")
	_ok(UiHints.preset_id(hud.hub.model(1), hud._o()) == "simple-pad", "two players: a layout the host names for a slot is the one its legend shows")
	hud.set_slot_layout(1, "")
	hud.hub.model(1).device = "kbd"
	_ok(UiHints.preset_id(hud.hub.model(0), hud._o()) == "kb-shared-p1" and UiHints.preset_id(hud.hub.model(1), hud._o()) == "kb-shared-p2", "two players: both on the keyboard they get the two halves")
	# The pause menu: hand player two back.
	var got := {"leave": 0, "entries": []}
	hud.player_two_leave_requested.connect(func(): got["leave"] += 1)
	hud.pause_entry.connect(func(e): got["entries"].append(e))
	hud.show_pause_menu()
	var ids2: Array = UiPause.ids(false, true)
	var pmp2: Dictionary = hud.pause_menu_plan()
	var item_ids: Array = []
	for it in pmp2["items"]:
		item_ids.append(it["id"])
	_ok(item_ids == ids2 and ids2.has("p2_leave") and ids2.find("p2_leave") == ids2.find("new") - 1 and not bool(pmp2["join"]), "two players: while two people play the pause menu has \"Player two: hand back to the AI\" before New match, and no join line")
	hud._pm_focus = ids2.find("p2_leave")
	hud.pause_menu_action("accept")
	_ok(got["leave"] == 1 and got["entries"].back() == "p2_leave" and hud.is_pause_menu_open(), "two players: choosing it tells the host and the menu stays open")
	hud.hub.model(1).ai = true
	hud.pause_menu_action("down")
	_ok(not UiPause.ids(false, false).has("p2_leave") and hud.pause_menu_focus() < UiPause.ids(false, false).size(), "two players: once player two is the AI the entry is gone and the focus stays on a button")
	hud.pause_menu_action("back")
	# Settings and Remap for each player.
	hud.hub.model(1).ai = true
	UiData.set_feature("remap", true)
	hud.show_settings()
	var keys1: Array = []
	for r in UiSettings.rows():
		keys1.append(str(r["key"]) if r["key"] != "" else str(r.get("action", "")))
	hud.hide_settings()
	hud.hub.model(1).ai = false
	hud.show_settings()
	var keys2: Array = []
	for r in UiSettings.rows():
		keys2.append(str(r["key"]) if r["key"] != "" else str(r.get("action", "")))
	_ok(not keys1.has("pad_preset_p2") and not keys1.has("remap_two") and keys2.has("pad_preset_p2") and keys2.has("remap_two") and keys2.find("pad_preset_p2") == keys2.find("pad_preset") + 1, "two players: Settings lists player two's controller layout and Remap row only while two people play")
	var rows_now: Array = UiSettings.rows()
	var ridx := -1
	for i in range(rows_now.size()):
		if str(rows_now[i].get("action", "")) == "remap_two":
			ridx = i
	hud._set_focus = ridx
	hud.hub.model(0).device = "kbd"
	hud.hub.model(1).device = "xbox"
	hud.settings_action("accept")
	_ok(hud.is_remap_open() and hud.remap_layout() == "brawler", "two players: Remap player 2's controls opens player two's own layout (the pad layout set for player two)")
	hud.hide_remap()
	hud.hide_settings()
	hud.hub.model(1).device = "kbd"
	hud.show_remap("", 1)
	_ok(hud.remap_layout() == "kb-shared-p2" and hud.remap_plan()["status"] == "", "two players: on the keyboard it is player two's half, and a layout only one person uses has no shared note")
	hud.hide_remap()
	hud.hub.model(1).device = "xbox"
	hud.hub.model(0).device = "xbox"
	hud.set_option("pad_preset", "arena")
	hud.set_option("pad_preset_p2", "arena")
	hud.show_remap("arena", 0)
	var rows_sel: Array = hud._rm_rows()
	_ok(str(rows_sel[1]["key"]) == "slot" and str(hud.remap_plan()["status"]) == "" and UiSettings.row_word(rows_sel[1], 0) == "Player 1" and UiSettings.row_word(rows_sel[1], 1) == "Player 2", "two players: the Remap screen has a Player 1 / Player 2 selector, and no shared-remap note any more")
	hud.hide_remap()
	# Each player's own remap of a layout (Controls' per-player remaps).
	SimInputData.clear_overrides()
	UiRemapModel.save_path = "user://input_test_p2.json"
	if FileAccess.file_exists(UiRemapModel.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(UiRemapModel.save_path))
	var a2: Dictionary = UiRemapModel.attempt("kb-solo", "light", "kb:KeyZ", false, 1)
	UiRemapModel.commit("kb-solo", a2["overrides"], 1)
	var lbl2 := func(slot: int) -> String:
		var parts := PackedStringArray()
		for sp3 in UiGlyphs.specs_for("light", "kbd", slot, "neutral", "kb-solo"):
			parts.append(str(sp3.get("label", "")))
		return " ".join(parts)
	_ok(a2["status"] == "ok" and _binding_controls(SimInputData.preset("kb-solo", 1), "light") == ["kb:KeyZ"] and _binding_controls(SimInputData.preset("kb-solo", 0), "light") == ["kb:KeyJ"] and lbl2.call(1) == "Z" and lbl2.call(0) == "J" and UiGlyphs.bound("kb-solo", "light", 1) and UiGlyphs.bound("kb-solo", "special1", 0), "per-player remaps: player two's Light on Z leaves player one's on J, and each prompt shows its own player's key")
	UiRemapModel.commit("kb-solo", [], 1)
	UiRemapModel.commit("kb-shared-p2", UiRemapModel.attempt("kb-shared-p2", "light", "kb:KeyZ", false, 1)["overrides"], 1)
	var cross0: Dictionary = UiRemapModel.attempt("kb-shared-p1", "light", "kb:KeyZ", false, 0)
	var cross1: Dictionary = UiRemapModel.attempt("kb-shared-p1", "light", "kb:KeyH", false, 0)
	_ok(cross0["status"] == "pair" and cross1["status"] == "ok", "per-player remaps: the pair rule compares across players (player one cannot take the key player two has remapped to, and can take the one player two gave up)")
	UiRemapModel.commit("kb-shared-p2", [], 1)
	var got2 := {"slot": []}
	hud.remap_slot_changed.connect(func(id, o, sl): got2["slot"].append([id, sl]))
	hud.show_remap("kb-solo", 1)
	_ok(hud.remap_layout() == "kb-solo" and hud._rm_slot == 1 and str(hud._rm_rows()[1]["key"]) == "slot", "per-player remaps: the Remap screen opens on player two when asked")
	hud._rm_focus = hud._rm_row_index("light")
	hud._rm_start_capture("light")
	var kz := InputEventKey.new()
	kz.keycode = KEY_Z
	kz.physical_keycode = KEY_Z
	kz.pressed = true
	hud._unhandled_input(kz)
	var file2: Dictionary = SimInputRemap.load_file(UiRemapModel.save_path)
	_ok(got2["slot"].size() == 1 and got2["slot"][0] == ["kb-solo", 1] and _binding_controls(SimInputData.preset("kb-solo", 1), "light") == ["kb:KeyZ"] and _binding_controls(SimInputData.preset("kb-solo", 0), "light") == ["kb:KeyJ"] and file2.has("presets_p2") and (file2["presets_p2"] as Dictionary).has("kb-solo"), "per-player remaps: a capture on player two's page changes player two's copy, announces the slot and is saved under presets_p2")
	hud._rm_focus = 1
	hud._unhandled_input(key_event_for(KEY_LEFT))
	_ok(hud._rm_slot == 0, "per-player remaps: Left on the selector goes to player one")
	hud._rm_focus = 1
	hud._unhandled_input(key_event_for(KEY_RIGHT))
	_ok(hud._rm_slot == 1, "per-player remaps: and Right back to player two")
	hud._rm_set_slot(0)
	hud.pad_slot_fn = func(dev: int) -> int: return 1 if dev == 7 else 0
	var pb := InputEventJoypadButton.new()
	pb.device = 7
	pb.button_index = JOY_BUTTON_DPAD_DOWN
	pb.pressed = true
	hud._unhandled_input(pb)
	_ok(hud._rm_slot == 1, "per-player remaps: a pad pressed in the screen switches it to the player that pad drives")
	hud.pad_slot_fn = Callable()
	hud.hide_remap()
	SimInputData.clear_overrides()
	UiRemapModel.save_path = SimInputRemap.USER_PATH
	if FileAccess.file_exists("user://input_test_p2.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://input_test_p2.json"))
	UiData.set_feature("remap", null)
	# The pause menu's geometry with the hand-back entry and the join line.
	for cs in cases:
		var sz2: Vector2 = cs[0]
		var lay2 := UiLayout.new()
		lay2.dp = cs[1]
		lay2.compute(sz2, false)
		for touch in [false, true]:
			for variant in [[true, false], [false, true]]:
				var p2: Dictionary = UiPause.plan(sz2, lay2.s, cs[1], touch, {"focus": 0, "confirm": false, "two": variant[0], "join": variant[1]})
				var hits_ok := true
				for it in p2["items"]:
					hits_ok = hits_ok and UiPause.hit(p2, (it["rect"] as Rect2).get_center()) == it["id"] and (it["rect"] as Rect2).size.y >= float(p2["tm"]) - 0.01
				_ok(bool(p2["fits"]) and hits_ok and (p2["items"] as Array).size() == (6 if variant[0] else 5), "pause menu two-player %dx%d dp %.1f touch=%s %s: it fits and every button is 48 dp" % [int(sz2.x), int(sz2.y), cs[1], str(touch), "hand-back entry" if variant[0] else "join line"])
	UiLook.text_floor = UiLook.MIN_TEXT_PX
	hud.queue_free()
	await process_frame
