class_name UiFighterModel
extends RefCounted
## What the HUD knows about one fighter: a view model, folded from events and patched from sim state. It is the only
## input the plate, crown and silhouette draw from. It never writes anywhere, draws no random numbers, and holds no
## numeric health: regions are stages, and the optional `wear` is used only to animate a smooth thinning.

var slot: int = 0
var id: String = "default"         # readout profile id ("protagonist", "anti_hero", "empress", "cyborg", or a placeholder)
var profile: Dictionary = {}
var name: String = ""
var title: String = ""
var aura: Color = Color("#8fd6ff")
var ai: bool = false
var left_side: bool = true         # which side's column it lives in

var regions: Array = ["head", "core", "arms", "legs"]
var stage: Dictionary = {}         # region -> 0..3 (the stage that is DRAWN; for a masked Anti-hero, the front)
var true_stage: Dictionary = {}    # region -> 0..3 (the real stage; differs from `stage` only while a Pride mask holds)
var internal_stage: int = 0        # the Protagonist's internal (scald) wear on the core, 0..3
var wear: Dictionary = {}          # region -> 0..100 or -1 when unknown (optional, for smooth thinning only)
var region_age: Dictionary = {}    # region -> seconds since its drawn stage last changed (animation)
var region_dir: Dictionary = {}    # region -> +1 worsened, -1 mended, 0 none
var brink: bool = false
var brink_age: float = 0.0
var pride_holds: bool = false      # Anti-hero: the Proud front is up, battered penalties are withheld
var shame: int = 0                 # Anti-hero shame stacks, 0..3
var unrestrained: bool = false     # Anti-hero after Drop the Act
var facade_age: float = 99.0       # seconds since the Proud front cracked (animation)

var stance: int = 0                # 0 press, 1 guard, 2 dodge, 3 escape (the sim's AGGRESSIVE..ESCAPE order)
var tier: int = 1                  # 1..4, shown as pips
var momentum: float = 0.0          # 0..100, the fill toward the next tier (a partial pip, never a number)
var charge: float = 60.0           # 0..100
var sig_cost: float = 45.0
var charging: bool = false
var ego_name: String = "respect"
var ego: float = 0.0               # 0..100
var heat_stage: int = 0            # Protagonist: 0 cool, 1 heated, 2 simmering, 3 boiling
var boil_flash: float = 0.0        # seconds left of a boil-over flash
var revision: int = 0              # Empress: the current revision (a plain numeral on her silhouette)
var patch_region: String = ""      # Empress: the region a real revision last mended (drawn with a patch mark)
var chip_station: int = 0          # Cyborg: which of the rail's stations the chip is at
var chip_stage: int = 0            # Cyborg: 0 whole, 1 scratched, 2 cracked, 3 split
var hatch_open: bool = false
var hatch_t: float = 0.0

var hidden: bool = false           # this fighter is hiding
var lost_trail: bool = false       # the opponent has lost the trail to this fighter (shown on the hunter's plate)
var parry_t: float = -1.0          # >= 0 while a parry window is open: seconds elapsed
var parry_dur: float = 0.0
var chain_t: float = -1.0
var chain_dur: float = 0.0
var chain_n: int = 0
var crown_a: float = 0.0           # the transient crown's opacity, 0..1: it pops on an event and fades back
var crown_hold: float = 0.0        # seconds of full opacity still to go
var hit_pop_age: float = 99.0      # seconds since a plain hit popped the crown (throttles a chain of blows)
var cue: float = 99.0              # seconds since the last grunt cue (drives the voice-burst mark)
var cue_intensity: int = 1
var cinematic: String = ""         # "" or the kind of respected cinematic this fighter is in
var ko: bool = false


func setup(p_slot: int, p_id: String, p_name: String = "") -> void:
	slot = p_slot
	id = p_id
	profile = UiData.profile(p_id)
	regions = (profile.get("regions", ["head", "core", "arms", "legs"]) as Array).duplicate()
	ego_name = str(profile.get("ego", "respect"))
	sig_cost = float(profile.get("sig_cost", 45))
	name = p_name if p_name != "" else p_id.to_upper()
	left_side = p_slot == 0
	reset_wounds()


func reset_wounds() -> void:
	for r in regions:
		stage[r] = 0
		true_stage[r] = 0
		wear[r] = -1.0
		region_age[r] = 99.0
		region_dir[r] = 0
	internal_stage = 0
	brink = false
	brink_age = 0.0
	pride_holds = bool(profile.get("withhold_until_pride_breaks", false))
	shame = 0
	unrestrained = false
	facade_age = 99.0
	heat_stage = 0
	boil_flash = 0.0
	crown_a = 0.0
	crown_hold = 0.0
	hit_pop_age = 99.0
	revision = 0
	patch_region = ""
	chip_station = 0
	chip_stage = 0
	hatch_open = false
	ko = false


func has_region(r: String) -> bool:
	return stage.has(r)


func worst_stage() -> int:
	var w := 0
	for r in regions:
		if r != "mantle":
			w = maxi(w, int(stage[r]))
	return w


## The opposite of the crown's smooth thinning: a stage from an optional wear value (0..100), for a mock or a sim that gives wear.
static func stage_from_wear(w: float) -> int:
	if w >= UiLook.STAGE_BROKEN_AT:
		return 3
	if w >= UiLook.STAGE_BATTERED_AT:
		return 2
	if w >= UiLook.STAGE_BRUISED_AT:
		return 1
	return 0


## Pop the crown: rise, hold for `hold` seconds, fall. A second pop while it shows extends the hold, never shortens it.
func pop(hold: float) -> void:
	crown_hold = maxf(crown_hold, hold)


## A plain hit pops the crown only if it is not already showing from one, so a chain of blows does not strobe it.
func pop_hit(region: String) -> void:
	if region != "" and stage.has(region):
		region_age[region] = 0.0
		if int(region_dir[region]) == 0:
			region_dir[region] = 1
	if hit_pop_age >= UiLook.CROWN_HIT_GAP:
		hit_pop_age = 0.0
		pop(UiLook.CROWN_HOLD_HIT)


func advance(dt: float) -> void:
	hit_pop_age += dt
	if crown_hold > 0.0:
		crown_a = move_toward(crown_a, 1.0, dt / UiLook.CROWN_ATTACK)
		crown_hold = maxf(0.0, crown_hold - dt)
	else:
		crown_a = move_toward(crown_a, 0.0, dt / UiLook.CROWN_RELEASE)
	for r in regions:
		region_age[r] = float(region_age[r]) + dt
	brink_age += dt
	facade_age += dt
	boil_flash = maxf(0.0, boil_flash - dt)
	cue += dt
	if parry_t >= 0.0:
		parry_t += dt
		if parry_t > maxf(parry_dur, UiLook.WINDOW_MIN_SHOWN):
			parry_t = -1.0
	if chain_t >= 0.0:
		chain_t += dt
		if chain_t > maxf(chain_dur, UiLook.WINDOW_MIN_SHOWN):
			chain_t = -1.0
	if hatch_open:
		hatch_t += dt
