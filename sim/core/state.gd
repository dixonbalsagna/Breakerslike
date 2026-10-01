class_name SimState
extends RefCounted
## The whole simulation state: the GDScript twin of the JS object S (module-spec section 2). Field names match the
## JS ones, so the two cores read alike and hash.gd walks them in the same order as hash.js. Every number is a float,
## because JS numbers are float64 and the hash sees their bits. Object references (a fighter, a clash, a beam's owner)
## stay references, as in JS.

var opts: Dictionary = {"fxRng": "shared", "math": "det"}
var T: float = 0.0
var tick: int = 0               # steps since newMatch, hit-stop ticks included (stamps every fx event)
var dt: float = 0.0
var rng: SimRng = SimRng.new(7)
var game := Game.new()
var dirS := DirS.new()
var fighters: Array = []
var world: World = null
var base := PackedFloat32Array()
var deform := PackedFloat32Array()
var water := PackedFloat32Array()     # water depth per terrain column (world/water.gd); the surface is ground + depth
var scorch := PackedFloat32Array()    # scorch intensity per terrain column, 0 to 1, permanent (world/crater.gd)
var craters: Array = []               # Crater records, oldest first, capped at WorldCrater.LIST_MAX (fx-events.md)
var rubble := PackedFloat32Array()    # rubble heap height per terrain column (world/structures.gd): part of S.deform, kept apart for cover, tint and digging
var bIdx: Array = []                  # spatial index of the buildings: PackedInt32Array per x bucket (world/structures.gd), never changes in a match
var popHist := PackedFloat32Array()   # living civilians per lure bucket (director/ai.gd LURE_STEP), kept up to date by WorldCollateral
var crack := PackedFloat32Array()     # pavement crack intensity per terrain column, 0 to 1, permanent (world/slide.gd)
var slides: Array = []                # Slide records, oldest first, capped at WorldSlide.LIST_MAX
var waterWin: Array = []              # active water-flow windows [centre column, half width, quiet steps, age steps]
var waterTick: float = 0.0            # unfrozen ticks since the match started; paces the water step
var buildings: Array = []
var trees: Array = []
var beams: Array = []
var mood := MoodState.new()           # M1 (sim/core/mood.gd): the fight's mood, the act and the outputs
var pause := PauseState.new()         # Q10 (sim/core/pause.gd): the pausing set pieces' bank and the running pause
var out := Out.new()


class Game:
	var ko = null            # the fighter that was KO'd, or null
	var koT: float = 0.0
	var ts: float = 1.0
	var clash = null         # Clash or null
	var seed: float = 1.0
	var timeCap: bool = false  # the brink chapter's override: the 11:00 time-cap event sets it, and every decisive exchange is a finisher


## I2a (intent v2): the action state derived from a fighter's intents (sim/core/act.gd). Integers and bools.
class ActState:
	var v2: bool = false          # the fighter's intents are v2: the stance and this state follow the held fields
	var queue: Array = []         # pending requests, oldest first: [weight, mode, entry, tick]
	var guardSince: int = -1      # S.tick when the guard went up, -1 while it is down
	var dodgeTick: int = -100000  # S.tick of the last dodge (SimAct.NEVER)
	var dodgeCool: int = 0        # ticks until the next dodge cancel
	var burstCool: int = 0        # ticks until the next burst
	var mode: int = 0             # 0 physical, 1 energy
	var assist: int = 0           # SimAct.ASSISTS bit flags, from the setup
	var formReady: bool = false   # a tier is ready and waits for the transform (ladder.json manualTierUp)
	var burstFired: bool = false  # the burst already fired on this power press
	var breakIn: int = -1         # the break: ticks until a transformation's tier-up lands (SimPause gather), -1 for none


## Q10: pausing set pieces (sim/core/pause.gd). Integers; a tick is a real tick, frozen or live.
class PauseState:
	var left: int = 0         # frozen ticks left in the running pause (0: none)
	var kind: int = 0         # SimPause.KINDS index of the running or the last pause
	var version: int = 0      # SimPause.VERSIONS index of it
	var actor: int = -1       # its fighter's slot, -1 for the time cap
	var bank: int = 0         # the bank, in ticks
	var acc: int = 0          # the bank's accrual remainder (SimPause.liveTick)
	var sinceEnd: int = 0     # live ticks since the last pause ended (SimPause.LONG_AGO before the first)
	var seen: int = 0         # bit slot * 4 + kind: the slot has asked for a set piece of the kind (its first may play in full)
	var total: int = 0        # ticks paused so far this match (QA: at most 2.5 s per minute)
	var count: int = 0        # pauses so far


## M1: the fight's mood (sim/core/mood.gd). Integers only; the unit is 1/60 of a mood point.
class MoodState:
	var t: int = 0            # non-frozen ticks the component has run
	var sec: int = 0          # its seconds (the 1 Hz style steps)
	var v: int = 0            # the mood, 0 to range
	var band: int = 0         # 0 calm, 1 tense, 2 frenzied
	var cand: int = 0         # the band the mood is in, while it differs from band ...
	var candT: int = 0        # ... and the ticks it has stayed there (the dwell)
	var act: int = 1          # the act announced so far (act_change); SimMood.act() is the live value
	var beats: int = 0        # act beats so far (mood.json actBeats): act = 1 + beats, until actBeats.formSteps
	var breaks: int = 0       # Q10: the region breaks among them (the act's additive part under actBeats.formSteps)
	var onceMask: int = 0     # the once-per-match beats already counted (SimMood.ONCE bits)
	var cause: int = 0        # the last beat's cause (SimMood.CAUSES index)
	var aggression: int = 1000  # output, permille: the director's scale (Encounter's Q4)
	var crowd: int = 0        # output: 0 excited, 1 nervous, 2 fleeing
	var casGiven: int = 0     # casualty impulse given so far, in units
	var lastCombo: int = 0    # the running exchange's chain count last tick


## M1: one fighter's play style (sim/core/mood.gd): a 60 s window of one-second buckets of 11 counters, match totals and
## the label with its holds.
class StyleState:
	var cur: Array = []       # this second's counters
	var buckets: Array = []   # 60 seconds x 11, a ring
	var bi: int = 0
	var filled: int = 0
	var win: Array = []       # the window's sums
	var total: Array = []     # match-long sums
	var label: int = -1       # the current label (SimMood.LABELS index), -1 none
	var leaveT: int = 0       # seconds the current label's leave condition has held
	var enterT: Array = []    # per label: seconds its enter condition has held
	var leftAt: Array = []    # per label: the second it last ended
	var shiftAt: int = 0      # the second the current label began (entry or shift): a shift waits minGapS from it
	var runKind: int = -1     # the current run of one attack kind ...
	var runLen: int = 0
	var runMax: int = 0       # ... and the match's longest
	var sigLanded: int = 0    # signatures that landed (match-long)


class Clash:
	var A = null
	var D = null
	var t0: float = 0.0
	var dur: float = 0.0
	var aw: bool = false


class DirS:
	var ex = null            # Exchange or null
	var cool: float = 0.0
	var stop: float = 0.0
	var lastLaunch: String = ""
	var lastLaunch2: String = ""
	var sinceBrunt: float = 0.0       # B2: planner launches with a building in reach that chose something else since the last brunt
	var lastBrunt: float = -1.0       # B2: the building index of the last brunt
	var exN: int = 0          # D1a: exchanges started this match (the exchange index for keyed draws, SimRng.keyed)
	var biomeT: PackedFloat64Array = PackedFloat64Array()   # location variety: seconds of fight per biome (DirLocation.BIOMES order), sized by the director
	var craterT: PackedFloat64Array = PackedFloat64Array()   # Encounter's slice (a) (granted line): the director owns it


class World:
	var pop0: float = 0.0
	var casualties: float = 0.0
	var structuresLost: float = 0.0
	var craters: float = 0.0
	var slides: float = 0.0           # knockback slides that have ended (the HUD's other mark counter)
	var evacuated: float = 0.0        # civilians who fled instead of dying (over budget or at the ceiling); they never return
	var cbBuckets := PackedFloat32Array()   # casualties per second of match time, 60 buckets (rolling budget window)
	var cbSec: float = 0.0            # the last second index the window has advanced to
	var cbSum: float = 0.0            # sum of the window
	var maxTier: float = 1.0          # highest tier either fighter has reached this match (the cumulative ceiling)
	var evtKind: String = ""          # the open set piece ("slide", "chain", ...) or ""
	var evtLeft: float = 0.0          # what the open set piece may still borrow, in people
	var evtToken: float = 0.0         # its token; 0 when none is open
	var evtDead: float = 0.0          # casualties the open set piece has caused
	var evtEvac: float = 0.0          # civilians it has made flee
	var tokenSeq: float = 0.0         # token counter
	var heavyX: float = -1.0          # x of the latest heavy event (the district flight flees from it)
	var heavyT: float = -1.0e9        # its match time
	var lotAcc := PackedFloat32Array()      # per building: evacuees not yet reported in an evacuate event (district flight lots)
	var stateT: float = 0.0           # match time of the last collateral_state event
	var fallTick: float = -1.0        # scratch for the implode event cap of one blast (not hashed)
	var fallN: float = 0.0
	var fallFold: float = 0.0


## One dug crater, kept for replay seek and snapshots (docs/architecture/fx-events.md). The renderer rebuilds a bowl
## in depth from these; the heightfield alone only holds the z = 0 slice.
## One knockback slide, kept for replay seek and snapshots (docs/world/knockback-slide.md).
class Slide:
	var pop: float = 0.0      # civilians killed by this slide
	var x0: float = 0.0       # where the fighter touched down
	var x1: float = 0.0       # where he stopped or left the ground
	var hw: float = 0.0       # trench half width
	var depth: float = 0.0    # trench depth at the start
	var energy: float = 0.0   # the impact energy the slide came from
	var t: float = 0.0        # match time at the end
	var owner: float = -1.0   # slot of the fighter who launched him, or -1
	var surface: float = 0.0  # 1 when it started on pavement (city or village), else 0


class Crater:
	var special: float = 0.0  # 1 for a signature, finisher, break launch or beam clash (the big marks)
	var x: float = 0.0        # centre, world x
	var y: float = 0.0        # ground height at the centre before the dig
	var r: float = 0.0        # bowl radius (the rim crest is at r)
	var depth: float = 0.0    # applied bowl depth below y (already limited by the local relief cap)
	var rim: float = 0.0      # rim height above the surrounding ground
	var energy: float = 0.0   # the impact-energy scalar the size came from
	var cause: String = ""    # "impact", "beam" or "powerup"
	var owner: float = -1.0   # slot of the fighter that caused it, or -1
	var t: float = 0.0        # match time
	var skid: float = 0.0     # signed offset of the furrow's tail from x (0: no furrow); the furrow runs into the bowl
	var sdepth: float = 0.0   # furrow depth at the bowl end


class Building:
	var floors: int = 1        # floor count (world/brunt.gd floorCount), set at generation
	var fmask: int = 1        # one bit per standing floor, bit 0 the ground floor
	var fdmg := PackedFloat32Array()   # damage per floor, allocated on the first local hit (empty before)
	var idx: int = 0          # index in S.buildings (set at generation; not hashed)
	var fled: float = 0.0     # people who left in the district flight so far (capped at WorldCollateral.FLIGHT_MAX of pop)
	var z: float = 0.0        # depth of the building's centre from the fighter plane (negative: behind), world units
	var d: float = 0.0        # footprint depth
	var row: float = 1.0      # 0 foreground, 1 front street (the fighter plane's row for collisions), 2 mid, 3 back
	var x: float = 0.0
	var w: float = 0.0
	var h: float = 0.0
	var maxhp: float = 0.0
	var hp: float = 0.0
	var alive: bool = true
	var kind: String = ""
	var pop: float = 0.0
	var seed: float = 0.0
	var popAlive: float = 0.0


class TreeState:
	var x: float = 0.0
	var h: float = 0.0
	var alive: bool = true
	var burn: float = 0.0


class Beam:
	var A = null
	var ox: float = 0.0
	var oy: float = 0.0
	var ux: float = 0.0
	var uy: float = 0.0
	var len: float = 0.0
	var p: float = 0.0
	var t: float = 0.0
	var life: float = 0.0
	var w: float = 0.0
	var variant: String = ""
	var col: String = ""
	var pw: float = 1.0          # beam-power scalar, fixed at fire time (WorldCrater.beamPower)
	var struck: bool = false     # has this beam already dug its ground-strike crater?
	var sf: float = 1.0          # step 2, the tier gate (balance-targets.md §15): the structure-damage factor at fire time
	var cap: int = -1            # ... buildings this beam may level (-1: no cap); past it they are left at 25% hp
	var levelled: int = 0        # ... and how many it has levelled so far


class FeedLine:
	var t: float = 0.0
	var tag: String = ""
	var sub: String = ""


class Out:
	var feed: Array = []     # FeedLine
	var fx: Array = []       # FxEvent: this tick's cosmetic events; the host drains them


## A cosmetic event (fx.gd, docs/architecture/fx-events.md). Only the fields of its type are meaningful.
class FxEvent:
	var type: String = ""
	var x: float = 0.0
	var y: float = 0.0
	var n = 0                    # an int for most events, a float head count for evacuate and building_fall
	var col: String = ""
	var spd: float = 0.0
	var gr: float = 0.0
	var life: float = 0.0
	var r0: float = 0.0
	var face: float = 0.0
	var ground: float = 0.0
	var amount: float = 0.0
	var text: String = ""
	var dur: float = 0.0
	var k: float = 0.0
	var dt: float = 0.0
	var frozen: bool = false
	var r: float = 0.0           # crater: bowl radius
	var depth: float = 0.0       # crater: bowl depth
	var rim: float = 0.0         # crater: rim height
	var energy: float = 0.0      # crater: impact-energy scalar
	var skid: float = 0.0        # crater: signed furrow tail offset, 0 for none
	var cause: String = ""       # crater: "impact", "beam" or "powerup"
	var w: float = 0.0           # scorch: full width of the groove
	var power: float = 0.0       # scorch: beam-power scalar
	var variant: String = ""     # scorch: the beam's biome variant
	var tick: int = 0             # every event: S.tick when it was emitted
	var actor: float = -1.0      # wounds, tier_up, hide_start, found: the fighter's slot
	var attacker: float = -1.0   # damage: the hitter's slot, or -1
	var victim: float = -1.0     # damage: the hit fighter's slot
	var kind: String = ""        # damage: light, heavy, guard, beam or impact
	var number: bool = false     # damage: whether a damage number shows (hits do; landings and collisions do not)
	var tier: float = 0.0        # tier_up
	var onGround: bool = false   # tier_up: a ground-level power-up (it cratered the terrain)
	var cover: String = ""       # hide_start: submerged, canopy or ridge
	var winner: float = -1.0     # ko
	var loser: float = -1.0      # ko
	var region: String = ""       # wounds: head, core, arms or legs
	var stage: int = 0            # wounds: 0 fresh, 1 bruised, 2 battered, 3 broken
	var owner: float = -1.0      # crater and scorch: firing fighter's slot, or -1
	var special: bool = false    # crater: a special blow (the big marks)
	var x1: float = 0.0          # slide: where it ended
	var pop: float = 0.0         # slide: civilians it killed
	var b: float = -1.0          # evacuate, building_fall: the building's index
	var dest: float = -1.0       # evacuate: the building the people ran to (-1: out of the district for good)
	var cx: float = 0.0          # evacuate, building_fall: the event's x (the crowd flees from it; the ripple starts there)
	var reason: String = ""      # evacuate: "budget", "ceiling" or "flight"
	var mode: String = ""        # building_fall: "implode" or "burst"
	var delay: float = 0.0       # building_fall: the ripple delay in seconds (cosmetic)
	var rubble: float = 0.0      # building_fall: the heap height left
	var room: float = 0.0        # collateral_state
	var budget: float = 0.0
	var left: float = 0.0
	var over: bool = false
	var ratio: float = 0.0       # building_hit, floor_hit: damage over the strength struck
	var keep: float = 0.0        # building_hit: the speed share the fighter keeps
	var link: int = 0            # building_hit, chain_link: 1 for the first building of a flight
	var ux: float = 0.0          # building_hit, floor_hit: the unit impact velocity
	var uy: float = 0.0
	var z: float = 0.0           # launch_depth: the first hit's depth; building_hit, floor_hit, chain_link: the hit depth
	var z1: float = 0.0          # chain_link: the next building's hit depth
	var y1: float = 0.0          # launch_depth, chain_link: the next hit point's height
	var from: float = -1.0       # chain_link: the building left; floors_fall: the lowest floor that fell
	var to: float = -1.0         # chain_link: the building headed for; floors_fall: the highest
	var outcome: String = ""     # building_hit: punch, crack, dent, pancake, collapse, heavy, wreck; floor_hit: punch, crack, dent
	var floor: int = -1          # floor_hit: the lowest floor of the hit; evacuate: the floor the people left (-1 for a whole building)
	var h: float = 0.0           # building_hit: the building's standing height
	# Director events (Encounter, S2; docs/architecture/fx-events.md):
	var target: float = -1.0     # the other fighter's slot (finisher, attack, parry, ambush, lock_lost, launch_plan, clash_draw, searching)
	var chance: float = 0.0      # finisher_contest: the survival chance
	var survived: bool = false   # finisher_contest
	var defStance: String = ""   # attack: the defender's stance, or CHARGING
	var template: String = ""    # attack: the exchange's template tag
	var ambush: bool = false     # attack: an ambush attack
	var chosen: String = ""      # launch_plan: the chosen launch, NONE for a shove
	var version: String = ""     # pause_start, transform: full, short or live (SimPause.VERSIONS)
	var gather: float = 0.0      # transform: seconds from this event to the break, where the tier_up comes
	var source: String = ""      # hazard_telegraph, danger: what is coming (brunt, windup, ambush; World adds collapse, landslide, lava)
	var eta: float = 0.0         # hazard_telegraph, danger: seconds until it lands, 0 when unknown


class Fighter:
	var name: String = ""
	var title: String = ""
	var role: String = ""
	var col: String = ""
	var aura: String = ""
	var hair: String = ""
	var care: float = 0.0
	var dmgMul: float = 0.0
	var spd: float = 0.0
	var maxhp: float = 0.0
	var sigName: String = ""
	var hp: float = 0.0
	var x: float = 0.0
	var y: float = 90.0
	var vx: float = 0.0
	var vy: float = 0.0
	var face: float = 1.0
	var ki: float = 60.0
	var power: float = 0.0
	var tier: float = 1.0
	var stance: float = 0.0
	var state: String = "free"
	var stateT: float = 0.0
	var hidden: bool = false
	var hideT: float = 0.0
	var hiddenFor: float = 0.0
	var menace: float = 0.0
	var anguish: float = 0.0
	var hasAnguish: bool = false  # the fighter's profile has a pressured-by-collateral meter (roster data, not the role name)
	var hasMenace: bool = false   # the fighter's profile has a menace meter, fed by the collateral it causes (roster data)
	var menaceSeen: float = 0.0     # menace after the last stepFighter (S0: menace decays when not fed)
	var menaceQuiet: int = 0         # ticks since menace was last fed
	var casSeen: float = 0.0        # S.world.casualties after the last stepFighter
	var wear: Array = [0, 0, 0, 0]   # Wounds (wounds.gd): head, core, arms, legs, in WEAR_SCALE units
	var stage: Array = [0, 0, 0, 0]  # per region: 0 fresh, 1 bruised, 2 battered, 3 broken
	var brink: bool = false
	var stunTicks: int = 0           # S3a: stagger or daze ticks left; input is gated while above 0 (wounds.gd)
	var rally: String = ""           # S4: the fighter's Rally rule (wounds.gd): second_wind, spite, reboot, encore or ""
	var rallied: int = 0             # S4: bit mask of the regions already rallied (each region once)
	var rallies: int = 0             # S4: Rallies so far
	var rallyCool: int = 0           # S4: ticks until the next Rally is allowed
	var breathWear: int = 0          # S4 (QA): wear units recovered by second breath so far
	var id: String = ""              # S4: stable roster id (the roster entry's key); arms may rename, never re-id
	var limbBreaks: int = 0          # pitch A: limbs broken in crippling moments this match
	var brinkSetups: int = 0         # the brink chapter: set-up wins the rival has against this fighter while it is on the brink
	var brinkOpen: bool = false      # ... it is open: the rival's next decisive win, in a later exchange, is the finisher
	var brinkEx: int = -1            # ... the exchange index (ex.n) of the last set-up win: a set-up and a finisher never share one
	var flightHits: int = 0          # M1: buildings hit in the current launched flight (building_hit's n)
	var act := ActState.new()        # I2a: what the fighter's presses mean now (sim/core/act.gd)
	var style = null                 # M1: StyleState (sim/core/mood.gd)
	var wd = null                    # D1a: the fighter's FighterData.WoundsDef (data; covered by the data hash, not hashed here)
	var md = null                    # D1b: its FighterData.MetersDef (the same)
	var ld = null                    # D1b: its FighterData.LadderDef (the same)
	var finisher: String = ""        # D1a: fighter.json finishers.base (data; data.gd still selects by byFighter until F1)
	var sigCooldown: float = 0.0     # step 2: fighter.json sigCooldown, seconds (a copy of the data, not hashed)
	var sigReadyT: float = 0.0       # step 2: the match time from which the signature can fire again (the director sets it)
	var ambush: bool = false
	var rush = null          # Rush or null
	var rot: float = 0.0
	var spin: float = 0.0
	var bounces: float = 0.0
	var launchBy = null      # Fighter or null
	var lastAtkT: float = -99.0
	var hurtT: float = -99.0
	var keys: String = ""
	var ai = null            # AiState or null
	var beamCharge = null    # float or null
	var wet: bool = false
	var launchT: float = 1.0       # horizontal traversal factor of the current launch (WorldSlide.launchTravel)
	var slide: float = 0.0         # 0, or the normalised start speed while a knockback slide runs
	var slideX0: float = 0.0
	var slideD: float = 0.0        # distance slid so far
	var slideE: float = 0.0        # impact energy of the slide
	var slideDmg: float = 0.0      # damage still to take by speed lost
	var slideAcc: float = 0.0      # damage earned by speed lost, not yet taken
	var aimB: int = -1               # B2: the building this launch is aimed at, or -1 (world/brunt.gd)
	var aimX0: float = 0.0           # x at the last waypoint (the launch, or the far face of the last building hit)
	var aimZ0: float = 0.0           # depth at that waypoint
	var aimZ1: float = 0.0           # depth of the aimed building's near face
	var aimD: float = 1.0            # x distance from the waypoint to the near face
	var chainEvt: float = 0.0        # the collateral set-piece token of a planned chain (0 for none)
	var z: float = 0.0               # the fighter's depth from the plane, positive toward the camera; a function of his aim
	var splashed := PackedInt32Array()   # buildings already splashed by this launch (at most WorldBrunt.SPLASH_CAP)
	var launchSpecial: bool = false  # the current launch is a signature, finisher or break launch (its ground mark may be big)
	var hopped: bool = false         # the launch has made its one hop
	var slideEvt: float = 0.0      # the collateral set-piece token of the running slide (world/collateral.gd)
	var lastSeen = null      # LastSeen or null
	var ambushUntil: float = 0.0
	var input := SimIntent.new()   # JS f.in (in is a GDScript keyword)
	var dPrev = null         # String or null
	var canHide: bool = false    # S2: the old hiding kit (recovery, ambush) is for a future stealth fighter only
	var lockBackT: float = -99.0 # S2 lock-break: when the opponent last regained lock on this fighter
	var exT: float = 0.0         # S2: when this fighter was last in an exchange (second breath counts from here)


## A rush toward a fighter ({tgt, off, end}) or toward a point ({px, py, end}).
class Rush:
	var tgt = null
	var off: float = 0.0
	var px: float = 0.0
	var py: float = 0.0
	var end: float = 0.0


class AiState:
	var t: float = 0.5
	var atk: float = 1.2
	var sT: float = 0.0
	var sOff: float = 0.0
	var st: float = 0.0   # I2b: the AI's chosen stance (a v2 slot's f.stance is derived from its held states every tick)


class LastSeen:
	var x: float = 0.0
	var y: float = 0.0


class Exchange:
	var n: int = 0            # D1a: this exchange's index (S.dirS.exN when it started)
	var tpl: String = ""      # I2a: the template id the exchange was planned from (the director sets it, I2b) ...
	var branch: String = ""   # ... and the branch id, so an interrupt finds its branch's `interrupts` block
	var cripR: int = -1       # pitch A: a heavy-class blow landed on this battered limb (region), awaiting the decisive result
	var cripA: int = -1       # ... by this slot
	var cripV: int = -1       # ... on this slot
	var startBattered: int = 0  # pitch A: limbs at battered when the exchange started (bit slot * 4 + region)
	var startBrink: int = 0     # the brink chapter: fighters on the brink when the exchange started (bit per slot)
	var A = null
	var D = null
	var kind: String = ""
	var t: float = 0.0
	var beats: Array = []    # Beat
	var combo: float = 1.0
	var tag: String = ""
	var ext = null           # Ext or null
	var windowStart: float = -1.0
	var cancel: bool = false
	var sA: float = 0.0          # S3b (R8): the attacker's stance, frozen at requestAttack; hit() reads it in the exchange
	var sD: float = 0.0          # ... and the defender's
	var loser: int = -1          # S3b: the slot that lost the exchange (branch favours, a decisive result, a parry), -1 none


class Ext:
	var start: float = 0.0
	var until: float = 0.0


## An exchange beat: data, not a closure (module-spec section 4).
class Beat:
	var t: float = 0.0
	var op: String = ""
	var args = null          # Dictionary or null
	var done: bool = false
