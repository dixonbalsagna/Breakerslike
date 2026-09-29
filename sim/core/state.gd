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
var waterWin: Array = []              # active water-flow windows [centre column, half width, quiet steps, age steps]
var waterTick: float = 0.0            # unfrozen ticks since the match started; paces the water step
var buildings: Array = []
var trees: Array = []
var beams: Array = []
var out := Out.new()


class Game:
	var ko = null            # the fighter that was KO'd, or null
	var koT: float = 0.0
	var ts: float = 1.0
	var clash = null         # Clash or null
	var seed: float = 1.0


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


class World:
	var pop0: float = 0.0
	var casualties: float = 0.0
	var structuresLost: float = 0.0
	var craters: float = 0.0


## One dug crater, kept for replay seek and snapshots (docs/architecture/fx-events.md). The renderer rebuilds a bowl
## in depth from these; the heightfield alone only holds the z = 0 slice.
class Crater:
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
	var n: int = 0
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
	var menaceSeen: float = 0.0     # menace after the last stepFighter (S0: menace decays when not fed)
	var menaceQuiet: int = 0         # ticks since menace was last fed
	var casSeen: float = 0.0        # S.world.casualties after the last stepFighter
	var wear: Array = [0, 0, 0, 0]   # Wounds (wounds.gd): head, core, arms, legs, in WEAR_SCALE units
	var stage: Array = [0, 0, 0, 0]  # per region: 0 fresh, 1 bruised, 2 battered, 3 broken
	var brink: bool = false
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
	var lastSeen = null      # LastSeen or null
	var ambushUntil: float = 0.0
	var input := SimIntent.new()   # JS f.in (in is a GDScript keyword)
	var dPrev = null         # String or null


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


class LastSeen:
	var x: float = 0.0
	var y: float = 0.0


class Exchange:
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


class Ext:
	var start: float = 0.0
	var until: float = 0.0


## An exchange beat: data, not a closure (module-spec section 4).
class Beat:
	var t: float = 0.0
	var op: String = ""
	var args = null          # Dictionary or null
	var done: bool = false
