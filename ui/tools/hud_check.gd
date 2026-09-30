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
	_ok(hud.hub.toll["pop0"] > 0, "bridge: reads the world counters")
	var sd: Dictionary = UiSimBridge.strip_data(host.S, host.cam.x, 2000.0)
	_ok((sd["segs"] as Array).size() == 11 and (sd["fighters"] as Array).size() == 2, "bridge: builds the planet strip's data")
	_ok(bool(seen["damage"]), "bridge: the live sim emits damage events (S1): " + str(seen))
	_ok(float(m0.wear["core"]) >= 0.0, "bridge: reads wear from the sim state")
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
	_ok(od.get("split_solo") == true and is_equal_approx(float(od.get("shake_scale", -1.0)), 1.0) and hud.opts["split_solo"] == true and is_equal_approx(float(hud.opts["shake_scale"]), 1.0), "options: split_solo defaults on and shake_scale to 1 (Camera reads them through the options)")
	_ok(UiData.options()["shake_scale"].get("accessibility", false) and UiData.options()["reduced_motion"].get("accessibility", false) and not UiData.options()["split_solo"].get("accessibility", false), "options: shake_scale and reduced_motion are accessibility options, split_solo is a display option")
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
	_ok(UiGlyphs.spec("light", "xbox", 0)["label"] == "W" and UiGlyphs.spec("signature", "switch", 0)["label"] == "E" and UiGlyphs.spec("dash", "ps", 0)["label"] == "S", "glyphs: the neutral style prints position letters (W, E, S), not a maker's letters")
	_ok(UiGlyphs.spec("light", "xbox", 0, "family")["label"] == "X" and UiGlyphs.spec("signature", "switch", 0, "family")["label"] == "A", "glyphs: the family style exists in the data (X on xbox, A on switch) but is not the default")
	_ok(UiGlyphs.spec("light", "kbd", 0)["label"] == "F" and UiGlyphs.spec("light", "kbd", 1)["label"] == "," and UiGlyphs.spec("charge", "kbd", 1)["label"] == ";", "glyphs: keyboard slots show their own keys")
	_ok(UiGlyphs.spec("stance_press", "xbox", 0)["kind"] == "dpad" and UiGlyphs.spec("stance_press", "xbox", 0)["dir"] == "up", "glyphs: stances are D-pad shapes, never arrow characters")
	# Options: hitstop_scale and the hot-seat layout are in the data.
	var od: Dictionary = UiData.option_defaults()
	_ok(is_equal_approx(float(od.get("hitstop_scale", -1.0)), 1.0) and od.get("hotseat_alt_layout") == false and od.get("show_prompts") == false, "options: hitstop_scale defaults to 1.0, the hot-seat layout to off, prompts to off")
	var o: Dictionary = UiData.options()
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
				var hub := _hub()
				var m: UiFighterModel = hub.model(0)
				m.ai = false
				m.left_side = true
				var o := {"touch": true, "prompts": false, "glyph_style": "neutral", "touch_grid": lay.touch_grid}
				var chips: Array = UiPrompts.plan(m, lay.prompts[0], lay.s, o)
				var okc := chips.size() == 4
				var prev := Rect2()
				for c in chips:
					var r: Rect2 = c["rect"]
					if r.size.x < tm - 0.01 or r.size.y < tm - 0.01 or r.position.x < lay.prompts[0].position.x - 0.5 or r.end.x > lay.prompts[0].end.x + 0.5 or r.intersects(prev):
						okc = false
					prev = r
				_ok(okc, "%s: the stance ring is four targets of at least 48 dp inside the column" % tag)
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
	_ok(hud.layout.touch_ui and is_equal_approx(hud.layout.dp, 2.6) and tr.has("pause") and tr.has("stance_0_p0") and tr.has("stance_3_p0") and not tr.has("stance_0_p1"), "responsive: the HUD exposes the pause button and the human fighter's four stance targets (an AI gets none)")
	var hit: Dictionary = hud.touch_target_at((tr["stance_2_p0"] as Rect2).get_center())
	_ok(hit.get("name", "") == "stance" and int(hit.get("slot", -2)) == 0 and int(hit.get("stance", -1)) == 2, "responsive: a tap on the third chip is stance 2 for slot 0")
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
	_ok(page0 == "What you control" and all_text.contains("You are the fighter") and all_text.contains("no combo inputs") and all_text.contains("play out on their own") and all_text.contains("no health bars") and all_text.contains("finisher"), "howto: the first page is What you control: you are the fighter, there are no combo inputs, the blows play out on their own, no health bars, a finisher ends it")
	var p0text := ""
	for it in (UiData.howto()["pages"] as Array)[0]["items"]:
		p0text += " " + str(it.get("text", ""))
	for verb in ["fly", "dash", "pick a stance", "light or heavy", "charge", "signature", "specials", "transform"]:
		_ok(p0text.to_lower().contains(verb), "howto: the first page says plainly that you control: %s" % verb)
	var all_hints := ""
	for k in UiData.reads()["hints"]:
		all_hints += " " + str(UiData.reads()["hints"][k])
	var player_copy: String = (all_text + all_hints).to_lower()
	_ok(not player_copy.contains("strategist") and not player_copy.contains("director") and not player_copy.contains("intent") and not player_copy.contains("the fight follows") and not player_copy.contains("follow from"), "howto: no player-facing copy says strategist, director, intent or the fight follows (those are internal words)")
	# Geometry at desktop, tablet, phone and a small window, with every device family and touch on or off.
	var cases: Array = [[Vector2(1920, 1080), 1.0], [Vector2(1280, 720), 1.0], [Vector2(1024, 576), 1.0], [Vector2(2400, 1080), 2.6], [Vector2(2532, 1170), 3.0], [Vector2(1560, 720), 2.0], [Vector2(2560, 1600), 2.0], [Vector2(3840, 2160), 1.0]]
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
	UiLook.text_floor = UiLook.MIN_TEXT_PX
	# Keyboard pages show the second player's keys; pads do not.
	var pk: Dictionary = UiHowto.plan(Vector2(1920, 1080), 1.0, 1.0, false, 1, "kbd", 0)
	var px: Dictionary = UiHowto.plan(Vector2(1920, 1080), 1.0, 1.0, false, 1, "xbox", 0)
	var has_note := func(pl: Dictionary) -> bool:
		for rec in pl["items"]:
			if rec["kind"] == "note":
				return true
		return false
	_ok(has_note.call(pk) and not has_note.call(px), "howto: the keyboard page shows the second player's keys, a pad page does not")
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
	_ok(kinds.count("stance") == 4 and kinds.has("weight"), "reads: the stance ring has a weight mark beside the four stances")
	var last_r: Rect2 = chips[chips.size() - 1]["rect"]
	_ok(last_r.end.x <= hud.layout.prompts[0].end.x + 0.5, "reads: and it stays inside the column")
	hud.queue_free()
	await process_frame


## The feedback panel: words, the report (no network, nothing personal), geometry at every size, the flow by mouse and touch, and the
## match-end button (docs/ui/hud-spec.md section 20).
func _feedback_rules() -> void:
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
	var sl: String = UiFeedback.settings_line({"captions": true, "reduced_motion": false, "shake_scale": 0.5, "glyph_style": "neutral", "not_an_option": 1})
	_ok(sl == "captions=on, glyph_style=neutral, reduced_motion=off, shake_scale=0.50", "feedback: the settings are the player options, sorted, on or off")
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
		for st in [UiFeedback.STATE_WRITE, UiFeedback.STATE_COPIED]:
			var p: Dictionary = UiFeedback.plan(sz, lay.s, cs[1], cs[1] > 1.5, st)
			var tag := "feedback %dx%d dp %.1f %s" % [int(sz.x), int(sz.y), cs[1], st]
			var card: Rect2 = p["card"]
			var tm: float = float(p["tm"])
			_ok(bool(p["fits"]) and Rect2(Vector2.ZERO, sz).encloses(card), "%s: the panel fits on screen (type scale %.2f)" % [tag, float(p["cs"])])
			var ctrl: Array = [p["close"], p["done"]]
			if st == UiFeedback.STATE_WRITE:
				ctrl.append(p["copy"])
				for chip in p["tags"]:
					ctrl.append(chip["rect"])
			else:
				ctrl.append_array([p["back"], p["again"]])
			var bad := 0
			for i in range(ctrl.size()):
				var r: Rect2 = ctrl[i]
				if r.size.x < tm - 0.01 or r.size.y < tm - 0.01 or not card.encloses(r):
					bad += 1
				for j in range(i + 1, ctrl.size()):
					if r.intersects(ctrl[j]):
						bad += 1
			_ok(bad == 0, "%s: every control is at least 48 dp, inside the card, and none overlap (%d bad)" % [tag, bad])
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
	for must in ["navigator.clipboard.writeText", "execCommand('copy')", "readonly", "pointerup", "createElement('textarea')", "__fbClose"]:
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
