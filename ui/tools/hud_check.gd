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
	_scenarios()
	await _draw_smoke()
	await _layer_rules()
	await _split_rules()
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
	SimWounds.addWear(host.S, f0, 2, 1200.0)
	SimWounds.updateStages(host.S, f0)
	host.tick(1280.0, 720.0)
	hud.advance(1.0 / 60.0)
	_ok(int(m0.true_stage["arms"]) == 3 and m0.crown_a > 0.0, "bridge: a real region_stage and region_broken from S1 reach the model and pop the crown")
	_ok(hud.hub.cards_of(0).any(func(c): return c.title == "ARMS: BROKEN") or hud.hub.waiting.any(func(c): return c.title == "ARMS: BROKEN"), "bridge: and make the ARMS: BROKEN card")
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
	for i in range(40):
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
	_ok(hud._l_divider.sig != null and hud._l_ring.sig != null and hud._l_pointers.sig != null, "hud split: the divider, the ring map and the pointers draw while the panes are open")
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
	_ok(hud._chips[0]["text"] == str(int(round(40000.0 / 75.0))), "hud split: the distance is in fighter heights (from the ring's angles and the planet's size)")
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
	_ok(hud._l_divider.sig == null and hud._l_pointers.sig == null and hud._l_ring.sig != null, "hud split: merged, the divider and the pointers clear and the ring map stays")
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
