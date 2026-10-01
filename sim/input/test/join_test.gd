extends SceneTree
## Local two-player, end to end through the real sim (docs/controls/local-two-player.md): the join rule, every pairing of
## devices (pad and pad, pad and keyboard, the shared keyboard halves, touch and pad), the way out, per-player layouts,
## and that who played on what changes nothing the sim records. The loop below does what SimHost.tick does with the hub:
## drain the joins and leaves, tell the hub who is human, take an intent for each human slot, step, spend the edges.
## From the repo root:
##   godot --headless --path . --script res://sim/input/test/join_test.gd
## Exit 0 if every check passes.

var fails: int = 0
var checks: int = 0


func ok(c: bool, what: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL  ", what)


func _init() -> void:
	SimInputData.load_and_apply()
	SimInputData.clear_overrides()
	_pad_pad()
	_pad_keyboard()
	_keyboard_shared()
	_touch_pad()
	_leave()
	_presets()
	_replays()
	print("join_test: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _new(hub: SimInputHub, p2_ai: bool = true) -> SimState:
	var S: SimState = SimCore.createSim()
	SimCore.newMatch(S, 5, {"p1": false, "p2": p2_ai}, hub.setup())
	return S


## One host tick for the hub, as SimHost.tick does it.
func _tick(S: SimState, hub: SimInputHub, n: int = 1) -> void:
	for k in range(n):
		for s in hub.take_joins():
			if S.fighters[s].ai != null:
				SimCore.toggleAI(S, s)
		for s in hub.take_leaves():
			if S.fighters[s].ai == null:
				SimCore.toggleAI(S, s)
		hub.set_humans(S.fighters[0].ai == null, S.fighters[1].ai == null)
		var inputs: Array = [null, null]
		for s in range(2):
			if S.fighters[s].ai == null:
				inputs[s] = hub.intent(s)
		if SimCore.step(S, inputs):
			hub.consumed()


func _pad_pad() -> void:
	var hub := SimInputHub.new()
	var S: SimState = _new(hub)
	ok(not hub.joinable(), "pad+pad: nobody is playing, so there is nothing to join yet")
	hub.pad_button(3, "lb", true)           # the demo's first input is player one
	_tick(S, hub, 3)
	ok(hub.slot_pad[0] == 3 and hub.device_of(0) == "pad", "pad+pad: the first pad is player one")
	ok(hub.joinable(), "pad+pad: now a device could join as player two")
	hub.pad_button(9, "south", true)        # a second pad, while slot 1 is the AI
	_tick(S, hub, 3)
	ok(hub.slot_pad[0] == 3 and hub.slot_pad[1] == 9, "pad+pad: the second pad joins as player two and player one keeps hers")
	ok(S.fighters[1].ai == null, "pad+pad: slot 1 became human")
	ok(not hub.joinable(), "pad+pad: and there is nothing left to join")
	var notes: Array = hub.take_notes()
	ok(notes.size() == 1 and notes[0]["kind"] == "joined" and notes[0]["slot"] == 1 and notes[0]["device"] == "pad", "pad+pad: UI gets one 'joined' note")
	# Each drives their own fighter: LB is guard for player one, RB is not for player two but LB is.
	hub.pad_button(9, "south", false)
	hub.pad_button(9, "lb", true)
	_tick(S, hub, 3)
	ok(S.fighters[0].stance == 1.0 and S.fighters[1].stance == 1.0, "pad+pad: both guard with their own pad")
	hub.pad_button(3, "lb", false)
	_tick(S, hub, 3)
	ok(S.fighters[0].stance == 0.0 and S.fighters[1].stance == 1.0, "pad+pad: and let go separately")
	# A third pad is ignored, and never takes slot 0 from the player using it.
	hub.pad_button(5, "north", true)
	_tick(S, hub, 2)
	ok(hub.slot_pad[0] == 3 and hub.slot_pad[1] == 9 and not hub.pads.has(5), "pad+pad: a third pad changes nothing")
	# A second pad plugged in while P2 is the AI never took slot 0 (the first scenario), also with P1 mid-action.
	var hub2 := SimInputHub.new()
	var S2: SimState = _new(hub2)
	hub2.pad_button(1, "lb", true)
	_tick(S2, hub2, 2)
	hub2.pad_stick(1, 1.0, 0.0)
	hub2.pad_button(2, "west", true)
	_tick(S2, hub2, 2)
	ok(hub2.slot_pad[0] == 1 and hub2.slot_pad[1] == 2 and S2.fighters[0].stance == 1.0, "pad+pad: a pad plugged in mid-play joins as P2 and P1 keeps guarding")


func _pad_keyboard() -> void:
	# Player one on a pad; the keyboard joins as player two with the solo layout.
	var hub := SimInputHub.new()
	var S: SimState = _new(hub)
	hub.pad_button(0, "lb", true)
	_tick(S, hub, 2)
	hub.key("Shift", true)
	_tick(S, hub, 3)
	ok(hub.device_of(0) == "pad" and hub.device_of(1) == "kb" and S.fighters[1].ai == null, "pad+kb: the keyboard joins as player two")
	ok(hub.layout_of(1) == "kb-solo" and hub.layout_of(0) == "arena", "pad+kb: with the solo layout, and player one on Arena")
	ok(S.fighters[1].stance == 1.0 and S.fighters[0].stance == 1.0, "pad+kb: both guard, each on their own device")
	hub.key("Shift", false)
	_tick(S, hub, 3)
	ok(S.fighters[1].stance == 0.0 and S.fighters[0].stance == 1.0, "pad+kb: and the keyboard lets go without touching the pad")
	# Player one on the keyboard; a pad joins as player two.
	var hub2 := SimInputHub.new()
	var S2: SimState = _new(hub2)
	hub2.key("KeyD", true)
	_tick(S2, hub2, 2)
	ok(hub2.device_of(0) == "kb" and hub2.joinable(), "kb+pad: player one on the keyboard")
	hub2.pad_button(4, "lb", true)
	_tick(S2, hub2, 3)
	ok(hub2.device_of(1) == "pad" and S2.fighters[1].ai == null and S2.fighters[1].stance == 1.0, "kb+pad: a pad joins as player two")
	ok(hub2.layout_of(0) == "kb-solo", "kb+pad: player one keeps the solo layout")
	# An unbound key does not join.
	var hub3 := SimInputHub.new()
	var S3: SimState = _new(hub3)
	hub3.pad_button(0, "south", true)
	_tick(S3, hub3, 2)
	hub3.key("KeyZ", true)
	_tick(S3, hub3, 2)
	ok(S3.fighters[1].ai != null, "pad+kb: a key no layout uses does not join")


func _keyboard_shared() -> void:
	# One keyboard player; T hands player two to a human (the host's T key): the shared halves.
	var hub := SimInputHub.new()
	var S: SimState = _new(hub)
	hub.key("KeyD", true)
	_tick(S, hub, 2)
	hub.key("KeyD", false)
	ok(hub.layout_of(0) == "kb-solo", "kb+kb: alone, the solo layout")
	SimCore.toggleAI(S, 1)                 # T
	_tick(S, hub, 2)
	ok(hub.layout_of(0) == "kb-shared-p1" and hub.layout_of(1) == "kb-shared-p2", "kb+kb: two humans on the keyboard use the shared halves")
	hub.key("Shift", true)                 # player one's guard
	hub.key("Semicolon", true)             # player two's guard
	_tick(S, hub, 3)
	ok(S.fighters[0].stance == 1.0 and S.fighters[1].stance == 1.0, "kb+kb: each half drives its own fighter")
	hub.key("Shift", false)
	_tick(S, hub, 3)
	ok(S.fighters[0].stance == 0.0 and S.fighters[1].stance == 1.0, "kb+kb: and lets go separately")
	hub.key("Semicolon", false)
	# A pad then takes the human slot nobody's device drives: with both humans on the keyboard it takes slot 0 (player one
	# moves to the pad), never a second player.
	hub.pad_button(0, "lb", true)
	_tick(S, hub, 3)
	ok(S.fighters[1].ai == null and (hub.device_of(0) == "pad" or hub.device_of(1) == "pad"), "kb+kb: a pad takes a player's slot, no third player appears")
	ok(hub.layout_of(0) != "kb-shared-p1" or hub.layout_of(1) != "kb-shared-p2", "kb+kb: and the keyboard goes back to solo for the other player")


func _touch_pad() -> void:
	var hub := SimInputHub.new()
	var S: SimState = _new(hub)
	hub.touch_down(1, 700.0, 300.0, "guard")
	_tick(S, hub, 3)
	ok(hub.device_of(0) == "touch" and S.fighters[0].stance == 1.0, "touch+pad: a touch is player one")
	hub.pad_button(6, "lb", true)
	_tick(S, hub, 3)
	ok(hub.device_of(1) == "pad" and hub.device_of(0) == "touch" and S.fighters[1].ai == null, "touch+pad: a pad joins as player two without disturbing the touch")
	ok(S.fighters[0].stance == 1.0 and S.fighters[1].stance == 1.0, "touch+pad: both guard")
	# And the other way: a pad first, a touch joins as player two.
	var hub2 := SimInputHub.new()
	var S2: SimState = _new(hub2)
	hub2.pad_button(0, "south", true)
	_tick(S2, hub2, 2)
	hub2.touch_down(1, 700.0, 300.0, "guard")
	_tick(S2, hub2, 3)
	ok(hub2.device_of(0) == "pad" and hub2.device_of(1) == "touch" and S2.fighters[1].stance == 1.0, "pad+touch: a touch joins as player two")
	# The touch layer's Simple assists reach the next match's setup for that slot.
	ok(hub2.setup()["assists"][1].has("autoBurst"), "pad+touch: the touch player's Simple assists are in the next setup")


func _leave() -> void:
	var hub := SimInputHub.new()
	var S: SimState = _new(hub)
	hub.pad_button(0, "south", true)
	_tick(S, hub, 2)
	hub.pad_button(1, "south", true)
	_tick(S, hub, 2)
	hub.take_notes()
	ok(S.fighters[1].ai == null, "leave: player two is in")
	ok(not hub.leave(0), "leave: player one cannot hand the slot to the AI")
	ok(hub.leave(1), "leave: player two can")
	_tick(S, hub, 2)
	ok(S.fighters[1].ai != null and hub.slot_pad[1] == -1 and hub.joinable(), "leave: the slot is the AI's again and can be joined")
	var n: Array = hub.take_notes()
	ok(n.size() == 1 and n[0]["kind"] == "left" and n[0]["slot"] == 1, "leave: UI gets a 'left' note")
	hub.pad_button(1, "east", true)   # the same pad presses again and rejoins
	_tick(S, hub, 2)
	ok(S.fighters[1].ai == null and hub.slot_pad[1] == 1, "leave: pressing again rejoins")
	# Unplugging player two's pad hands the slot back to the AI.
	hub.pad_disconnected(1)
	_tick(S, hub, 2)
	ok(S.fighters[1].ai != null and not hub.pads.has(1), "leave: unplugging player two's pad hands the slot back to the AI")
	# Unplugging player one's pad returns the slot to the keyboard and keeps player one human.
	hub.pad_disconnected(0)
	_tick(S, hub, 2)
	ok(S.fighters[0].ai == null and hub.device_of(0) == "kb", "leave: unplugging player one's pad leaves player one on the keyboard")
	hub.key("KeyD", true)
	_tick(S, hub, 2)
	ok(hub.device_of(0) == "kb" and S.fighters[1].ai != null, "leave: and the next key is player one's, not a join")


func _presets() -> void:
	var hub := SimInputHub.new()
	var S: SimState = _new(hub)
	hub.pad_button(0, "west", true)    # player one: Arena, X is a light
	_tick(S, hub, 2)
	hub.pad_button(1, "west", true)    # player two joins
	_tick(S, hub, 2)
	hub.set_pad_preset("brawler", 1)
	ok(hub.layout_of(0) == "arena" and hub.layout_of(1) == "brawler", "presets: each player has their own layout")
	hub.pad_button(1, "west", false)
	hub.pad_button(1, "rb", true)      # the Brawler's light
	var i1: SimIntent = hub.intent(1)
	var i0: SimIntent = hub.intent(0)
	ok(i1.light and not i0.light, "presets: RB is player two's light, and player one's pad is unaffected")
	hub.consumed()
	hub.pad_button(1, "rb", false)
	hub.pad_button(1, "west", true)     # on the Brawler X is the mode button, not a light
	ok(not hub.intent(1).light, "presets: X is not a light on the Brawler")
	hub.consumed()
	hub.set_pad_preset("simple-pad", 0)
	ok(hub.layout_of(0) == "simple-pad" and hub.layout_of(1) == "brawler", "presets: changing player one's leaves player two's")
	ok(hub.setup()["assists"][0].has("autoBurst") and hub.setup()["assists"][1].is_empty(), "presets: only the Simple player gets assists")
	hub.set_pad_preset("arena")
	ok(hub.layout_of(0) == "arena" and hub.layout_of(1) == "arena", "presets: with no slot the default applies to both")


## Replays record intents, not devices: the same actions on a pad or on the keyboard give the same match.
func _replays() -> void:
	var hashes: Array = []
	for dev in ["pad", "kb"]:
		var hub := SimInputHub.new()
		var S: SimState = _new(hub)
		for n in range(600):
			match n:
				5:
					if dev == "pad":
						hub.pad_button(0, "lb", true)
					else:
						hub.key("Shift", true)
				40:
					if dev == "pad":
						hub.pad_button(0, "lb", false)
					else:
						hub.key("Shift", false)
				60:
					if dev == "pad":
						hub.pad_button(0, "west", true)
					else:
						hub.key("KeyJ", true)
				63:
					if dev == "pad":
						hub.pad_button(0, "west", false)
					else:
						hub.key("KeyJ", false)
			_tick(S, hub)
		hashes.append(str(SimHash.stateHash(S).gameplay))
		SimCore.dispose(S)
	ok(hashes[0] == hashes[1], "replays: the same actions from a pad and from the keyboard are the same match")
