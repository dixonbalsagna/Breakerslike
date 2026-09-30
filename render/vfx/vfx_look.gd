class_name VfxLook
extends RefCounted
## Every number and colour of VFX's effects, in one place (docs/vfx/plan.md). Placeholder values until Art's palette
## roles land; every colour is a semantic role (trail rim, glass, steel, dust, crack line, lit lip) so Art can retune
## them without touching logic. Presentation only: nothing here is read by the sim.

const BH: float = 75.0                  # one fighter height in world units (FighterView.HEIGHT is 90 with the hair)
const WS: float = SimConst.WS

# ------------------------------------------------------------------------------------------------ motion trails
## Speed is measured from the fighter's displacement per unfrozen tick, in body heights a second. The camera keeps a
## fighter 32 to 47 px tall, so bh/s is zoom-independent by construction.
const V_ON: float = 40.0                # bh/s: nothing below this (melee dash tops out at about 18)
const V_FULL: float = 110.0             # bh/s: full trail
const K_UP_TAU: float = 0.06            # seconds: intensity eases up ...
const K_DOWN_TAU: float = 0.25          # ... and down slower, so a trail never flickers at the threshold
const HIST_MAX: int = 16                # one point per unfrozen tick: 0.27 s of path
const SPAN_MIN: float = 0.07            # seconds of path the ribbon covers at k = 0 ...
const SPAN_MAX: float = 0.20            # ... and at k = 1
const LEN_MAX_BH: float = 14.0          # a ribbon is never longer than this
const SEGS: int = 4                     # straight segments per ribbon (a curved launch bends)
const RING_S: float = 0.25              # the break ring: one thin arc at the front the moment a fighter reaches full speed
const RING_GAP_S: float = 1.5
const RING_R0_BH: float = 1.5
const RING_R1_BH: float = 4.5
const W_OUTER_BH: float = 0.50          # head width of the outer band
const W_CORE_BH: float = 0.22           # head width of the core
const MIN_CORE_PX: float = 2.0          # the core is never thinner than this on screen
const A_OUTER: float = 0.55
const A_CORE: float = 0.90
const SEG_ALPHA: Array = [1.0, 1.0, 0.65, 0.35]   # hard steps along the length, not a smooth fade
const Z_TRAIL: float = -12.0            # behind the fighter plane: a trail never covers a fighter
const CHEST_Y: float = 36.0             # the ribbon leaves from the chest (sim beams aim at y + 36)
const RUSH_GATE: bool = true            # a rush has its own silhouettes: no trail unless it is faster than V_FULL

## Wind marks: dashes fixed in the world that the camera flies past, so speed reads against something still.
const MARKS_MAX: int = 10               # live per fighter
const MARK_P: float = 0.50              # spawn chance per unfrozen tick at k = 1
const MARK_LEN_S: float = 0.05          # length = speed * this: at least 3 frames of travel, so no strobing
const MARK_LEN_MIN_BH: float = 1.5
const MARK_LEN_MAX_BH: float = 30.0
const MARK_OFF_MIN_BH: float = 0.7      # keep off the fighter's centre line
const MARK_OFF_MAX_BH: float = 5.0
const MARK_AHEAD_MIN_BH: float = 4.0     # spawn this far ahead of the fighter along its path (a pane is about +-15 bh wide) ...
const MARK_AHEAD_MAX_BH: float = 18.0    # ... to this, and live until the fighter is MARK_BEHIND_BH past them
const MARK_BEHIND_BH: float = 22.0
const MARK_LIFE_MIN: float = 0.12
const MARK_LIFE_MAX: float = 0.80
const MARK_W_BH: float = 0.09           # thin
const MARK_MIN_PX: float = 1.5
const MARK_A: float = 0.60
const Z_MARK_MIN: float = -30.0
const Z_MARK_MAX: float = -8.0

const TRAIL_NEUTRAL := "#cfe6f0"        # used when a fighter's accent is in the fire range (orange, yellow, red)
const TRAIL_CORE := "#ffffff"

# ---------------------------------------------------------------------------------------------------- ground cracks
const CRACKS_DEFAULT: bool = false      # off in the game until Orb has seen them (tools switch them on)
const DESTRUCTION_DEFAULT: bool = false # shrapnel, collapse dust and holes: off in the game until Orb has seen them
const EMBERS_DEFAULT: bool = false      # scorch embers by variant: off until Rendering suppresses ImpactFx's own
## Cracks are a pure function of the sim's records (S.craters, S.slides) plus the match seed (render/vfx/crack_gen.gd),
## so a seek, a snapshot or a late join draws the same ones. Lengths and widths are in crater radii r or trench half
## widths hw; numbers of lines grow with sqrt(energy).
const CRACK_SETS_MAX: int = 90          # crater and slide crack sets kept (oldest dropped)
const CRACK_VISIBLE_MAX: int = 24       # drawn per pane: the nearest
const CRACK_BUILD_PER_FRAME: int = 1
const CR_E_MIN: float = 0.5             # below this energy an impact leaves no cracks
const CR_SPOKES_BASE: float = 3.0
const CR_SPOKES_SQRT_E: float = 1.7
const CR_SPOKES_MAX: int = 16
const CR_LEN_BASE: float = 0.45         # x r
const CR_LEN_SQRT_E: float = 0.10
const CR_LEN_MAX: float = 1.7
const CR_W: float = 0.006               # x r: width at the source, clamped below
const CR_W_MIN: float = 6.0
const CR_W_MAX: float = 44.0
const CR_X_BIAS: float = 0.78           # share of spokes running along the ground's x axis (they read from the side)
const CR_X_SPREAD: float = 0.56         # radians either side of the x axis
const FISSURE_E: float = 6.0            # a fissure needs this energy, or a special blow
const FISSURE_MAX: int = 3
const FISSURE_LEN_BASE: float = 1.2     # x r
const FISSURE_LEN_SQRT_E: float = 0.22
const FISSURE_LEN_MAX: float = 3.6
const FISSURE_W: float = 0.022          # x r
const FISSURE_W_MIN: float = 24.0
const FISSURE_W_MAX: float = 300.0
const SL_STEP: float = 40.0 * WS        # a spur pair every this far along a slide (the sim's slide_dust spacing)
const SL_SPUR_MIN: float = 0.9          # x hw
const SL_SPUR_MAX: float = 2.2
const SL_MAX_SPURS: int = 60
const Z_CRACK_MAX: float = 30.0         # cracks stop at the fighter plane: the foreground rule pulls land in front down
const Z_CRACK_BACK: float = -RenderLook.Z_TERRAIN_BACK * 0.8   # ... and stop well inside the ground band: beyond its back rows the drawn ground is the far relief, not the sim's
const CRACK_GROW_S: float = 0.45        # seconds for the web to reach its full reach (sim time)
const CRACK_SEG: float = 40.0           # strips are cut into pieces this long so they follow the ground under them
const CRACK_CORE_PX: float = 4.4        # least on-screen thickness of a crack line, in pixels (the ground is seen at a grazing angle)
const CRACK_EDGE_PX: float = 8.4        # the broken edges around it
const CRACK_LIP_PX: float = 2.2         # the lit lip of a fissure
const CRACK_CORE := "#211f22"
const CRACK_EDGE := "#8a7a63"
const CRACK_LIP := "#e9e1cf"
const CRACK_A_CORE: float = 0.92
const CRACK_A_EDGE: float = 0.45
const CRACK_A_LIP: float = 0.55

# ------------------------------------------------------------------------------- shrapnel, collapse dust, holes
## Debris is simulated on the render side (VfxDebris): ballistic bits with gravity and a bounce, stepped once per unfrozen
## tick (a tenth of a step in hit-stop, like the reference consumer's particles). Sizes are in world units.
const GLASS := "#9ccfe4"                # glass slivers: pale cyan, light step on the lit edge
const GLASS_HI := "#e2f5fa"
const STEEL := "#586170"                # steel bits: dark grey, a lighter edge
const STEEL_HI := "#aab4c2"
const CONCRETE := "#8a8f98"
const DUST_A := "#b9b0a1"               # cel dust: a body colour and a darker rim
const DUST_B := "#8a8276"
const HOLE_DARK := "#14161b"            # the hole a fighter leaves in a facade: dark inside, a torn light rim
const HOLE_RIM := "#9aa4b2"
const DEBRIS_GRAV: float = 1000.0
const DEBRIS_CAP: int = 460             # shards and dust together (docs/vfx/plan.md section 6: 220 shards, 240 dust)
const SHARD_CAP: int = 220
const PUFF_CAP: int = 240
const BLAST_CAP: int = 700              # particles one blast may ask for, however many buildings it levels
const SPAWN_PER_TICK: int = 260         # dust puffs past this many spawns in one tick are dropped (shards keep priority)
const EMBER_PER_TICK: int = 12          # scorch embers spawned per tick, at most
const EMBER_CAP: int = 100              # and alive at once
const HOLES_MAX: int = 24
const HOLES_PER_BUILDING: int = 3
const GLASS_IN_MIN: int = 10            # a burst-through: glass thrown back at the entry ...
const GLASS_IN_MAX: int = 28
const GLASS_OUT_MIN: int = 22           # ... and the cone at the exit
const GLASS_OUT_MAX: int = 50
const STEEL_IN: int = 4
const STEEL_OUT_MIN: int = 6
const STEEL_OUT_MAX: int = 14
const CHUNKS_OUT: int = 8
const Z_SHARD_OVER: float = 24.0        # shards float this far in front of the facade they came out of
const QUALITY_SHARDS: Array = [0.35, 0.7, 1.0]

## Quality levels (docs/vfx/plan.md section 6).
const Q_LOW: int = 0
const Q_MED: int = 1
const Q_HIGH: int = 2
const MARKS_BY_QUALITY: Array = [0, 6, 10]        # live marks per fighter
const OUTER_BY_QUALITY: Array = [false, true, true]
const SPOKES_BY_QUALITY: Array = [0.5, 0.75, 1.0]     # multiplier on hairline spoke counts


## The trail's accent for a fighter colour: the colour itself unless it sits in the fire hues, which fire owns.
static func trail_accent(hex: String) -> Color:
	var c: Color = RenderLook.col(hex)
	if c.s > 0.35 and c.v > 0.35 and (c.h < 0.19 or c.h > 0.96):
		return VfxPalette.haze()
	return c
