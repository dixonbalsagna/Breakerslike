class_name RenderLook
## Greybox look: every colour and dimension the renderer uses, in one place. Placeholder values until Art's palette
## and the procedural generator specs land; then these move to data files. The biome, prop and HUD colours are the
## prototype's (prototype/index.html BCOL and draw*), so the greybox reads like the prototype.

## Camera: vertical field of view in degrees. The reference camera's zoom z (pixels per world unit) is honoured
## exactly on the fighter plane (depth 0); anything in front of or behind it gets perspective parallax.
const FOV_DEG: float = 30.0
## The camera pitches the debug key steps through, in degrees (CameraRig): straight on (today's view, which already
## sees the ground from about 6 degrees through its raised lens), then Camera's raised side view and its three-quarter
## view (docs/camera/camera-v2.md section 8). Camera's own constants replace these when its mapping takes the pitch.
const PITCH_STEPS: Array = [0.0, 11.0, 49.0]

## World scale. Sizes that belong to the world (buildings, trees, craters, the ground's depth) are written at the
## original scale and multiplied by the sim's feature scale WS; mountain heights by MS; lengths along the planet by PS
## (sim/core/constants.gd, docs/world/scale.md). Fighter-scale sizes (the fighter plane's fine rows, particles, the
## fighters themselves) are not scaled.
const WS: float = SimConst.WS
const MS: float = SimConst.MS
const PS: float = SimConst.PS

## Depth layout, in world units along +z (toward the camera). Fighters, beams and particles live on z = 0.
const Z_TERRAIN_FRONT: float = 600.0     # the ground's shading reference in front (its top face brightens toward here)
## The ground runs toward the camera and past it, so there is no front face to see at any zoom: Z_FORE is past the
## camera at its widest pull-out (SimCamera.ZOOM_MIN) on viewports up to about 3,500 px tall. In front of the fighter
## plane the foreground rule (ground.gdshaderinc, fore_fall) keeps land and water below the sight line from the camera
## to the fighter plane, less FORE_DROP of their depth: nothing in front hides the fight, the camera is never inside
## the ground or under water, and a ridge or sea the camera is below shows as a soft face under its own profile.
const Z_FORE: float = 1.0e6
const FORE_DROP: float = 0.03
const WATER_FALL_BODY: float = 4.0   # water that fell this far under the foreground rule shows its body, not its surface
const Z_TERRAIN_BACK: float = -1125.0 * WS   # back of the crater rows: tier-4 rims reach about 2 x 4,300
## Ground rows are generated, not listed: spacing ROW_STEP0 at the fighter plane (fighter scale), growing by
## ROW_GROWTH of the distance, from Z_FORE in front to the horizon (FOG_FAR) behind. The row at exactly 0 reads the
## sim's profile (render/core/ground_field.gd). Columns coarsen with distance from the fighter plane, either side:
## STRIDES is [up to this |z|, column stride]. The finest run and the middle runs are split into chunks along the
## planet (CHUNK_COLS columns) so the frustum culls them; the coarsest is one mesh per copy.
const ROW_STEP0: float = 16.0
const ROW_GROWTH: float = 0.15
const STRIDES: Array = [[400.0, 1], [2000.0, 2], [-Z_TERRAIN_BACK, 4], [1.0e12, 8]]
const CHUNK_COLS: int = 320              # a multiple of the largest stride
const Z_BUILDING_FRONT: float = -140.0   # a building with no depth from the sim stands here (B1 gives z and d)
## Buildings in depth (World's B1, docs/world/buildings-in-depth.md): each stands at its sim z with footprint depth d,
## on the highest ground under its footprint, its footing extended down to the lowest. An implode sinks it straight
## down over IMPLODE_S from the ripple's delay (VFX draws the dust skirt). Row 0 stands in front of the fighter plane.
## Civilians stand on their building's street side, CROWD_GAP units out from its face and up to CROWD_DEEP more.
## A building between a pane's camera and a fighter is opened by one of two methods (docs/rendering/README.md,
## "Occlusion"): a round hole around him (HOLE_*), or the building cut down to a low stub (STUB_*).
const IMPLODE_S: float = 0.5
const HOLE_PX: float = 70.0              # the hole around a fighter: its least radius on screen,
const HOLE_BODY: float = 1.6             # ... or this many of his drawn heights if that is more (Camera's rule)
const HOLE_GAP: float = 30.0             # it cuts up to this far in front of him (and of the building he is aimed at)
const HOLE_JOIN: float = 0.6             # two fighters behind a block this near on screen (of its width) share one hole,
const HOLE_JOIN_S: float = 0.25          # ... the two holes growing into one over this long
const OCCL_MARGIN: float = 40.0          # a building counts as in front of a fighter when it is this near his sight line
const STUB_H: float = 40.0               # a cut-down building stands this tall
const STUB_MARGIN: float = 110.0         # buildings this near a fighter's sight line are cut down with the one hiding him
const STUB_IN_S: float = 0.2             # a building sinks to its stub over this long,
const STUB_OUT_S: float = 0.35           # ... and stands again over this long
const STUB_SPAN: float = 150.0           # the stretch between two fighters is kept clear in steps of this
## Fight lanes (ADR 0009): the streets painted on the ground from the lane table (render/core/lanes.gd), and the lane
## cue, a stripe on the ground at a fighter's depth in his colour, shown while it says something: the fighters are at
## different depths, or his depth is changing.
const STREET_WALK: String = "#84878f"
const STREET_ROAD: String = "#3f4249"
const STREET_KERB: String = "#5c5f67"
const STREET_LINE: String = "#c8c2a8"
const STREET_EDGE: float = 120.0         # the paint fades in over this at a district's ends
const STREET_DASH: float = 120.0         # a centre-line dash and its gap, each
const STREET_BAY: float = 190.0          # a kerb parking bay's length (a car is 2.5 bh)
const LANE_CUE_W: float = 14.0           # the stripe's half width in depth,
const LANE_CUE_LEN: float = 450.0        # ... its half length along the street,
const LANE_CUE_ALPHA: float = 0.5        # ... and its strength at full
const LANE_CUE_DZ: float = 40.0          # the fighters count as at different depths past this,
const LANE_CUE_VZ: float = 60.0          # ... and a depth as changing past this many units a second
const LANE_CUE_IN_S: float = 0.15        # it comes up over this long,
const LANE_CUE_OUT_S: float = 0.6        # ... and goes over this long
const BUILDING_INSIDE := "#12131a"       # the inside of a tower seen through its cut floors (a tunnel)
const CROWD_GAP: float = 20.0
const CROWD_DEEP: float = 90.0
const Z_TREE_MIN: float = -120.0 * WS
const Z_TREE_MAX: float = -30.0 * WS
const TREE_W: float = 26.0 * WS
const ROOF_H: float = 16.0 * WS
const Z_PARTICLES: float = 10.0
const Z_BEAMS: float = 6.0
## The ground continues behind the crater rows to the horizon as one surface (no separate backdrop): the far terrain
## blends in from the band's own heights over FAR_BLEND and is the same planet (each column's base height and biome,
## with relief). It fades into the sky between FOG_NEAR and FOG_FAR, so its far edge never shows.
const FAR_BLEND: float = 900.0 * WS
const MEANDER: float = 600.0 * PS        # how far (in x) the far land's biomes wander with depth
const FOG_NEAR: float = 700.0 * WS
const FOG_FAR: float = 15000.0 * WS       # far enough that the planet fills the lower screen from the ceiling
## Far relief per biome: [height multiplier on the base terrain, relief amplitude at the original scale]; the relief is
## multiplied by WS (MS for mountains) and smoothed across biome borders.
const FAR_RELIEF: Dictionary = {
	"ocean": [1.0, 40.0], "plains": [1.0, 45.0], "city": [1.0, 12.0], "village": [1.0, 30.0],
	"forest": [1.0, 70.0], "desert": [1.0, 55.0], "mountains": [1.25, 300.0],
}
const FAR_SMOOTH_COLS: int = 24 * 4      # half width of the smoothing, in columns
const SNOW_FROM: float = 560.0 * MS      # far peaks whiten above this height ...
const SNOW_FULL: float = 900.0 * MS      # ... fully by this
const SNOW := "#dfe3ec"
const PLANET_COPIES: int = 2             # ground and water copies each side of the camera (props use 1)

## Planet-scale cues. Horizon curvature: how far the world behind the fighter plane sags at the screen edge, as a
## fraction of screen height (for the depth-weighted bend in render/shaders/bend.gdshaderinc). It grows from
## CURVE_NEAR at close zoom to CURVE_WIDE at wide zoom (log scale between ZOOM_CLOSE and ZOOM_WIDE), plus CURVE_HIGH as
## the camera climbs from HIGH_FROM to HIGH_TO (fractions of the flight ceiling).
const CURVE_NEAR: float = 0.035
const CURVE_WIDE: float = 0.10
const CURVE_HIGH: float = 0.10
const ZOOM_CLOSE: float = 0.3
const ZOOM_WIDE: float = 0.015
const HIGH_FROM: float = 0.2 * SimConst.CEILING   # camera y where the sky starts turning to space
const HIGH_TO: float = 0.85 * SimConst.CEILING

const BIOME: Dictionary = {
	"ocean": "#2a6b98", "plains": "#5f9140", "city": "#6c7079", "village": "#7c8e4b",
	"forest": "#2e6a35", "desert": "#cfa85c", "mountains": "#7e766a",
}
const SEA_FLOOR := "#5a5346"
const CRATER := "#4a4237"
const CRATER_DESERT := "#a98544"
const EJECTA := "#9a8a70"                # rims and aprons, dusty
const CRACKED := "#2b2a2c"               # cracked pavement (S.crack), its crack lines
const CHAR := "#1d1715"                  # scorched ground at full burn
const HEAT_LO := "#c2381c"               # a cooling groove
const HEAT_HI := "#ffd27a"               # a fresh groove from a strong beam
## Ground field widths across the band's depth (render/core/ground_field.gd). Bowls and grooves take their sizes from
## the sim (each crater record's r, depth and rim; the scorch constants in WorldCrater); only these are the renderer's.
const FURROW_W_R: float = 0.3            # a furrow's half width across the band, per unit of its crater's r ...
const FURROW_W_MIN: float = 20.0 * WS    # ... and at least this
const GROUND_SPREAD: float = 60.0 * WS   # half width across the band of dents with no record (dropped craters, clips)
const RUBBLE_EDGE: float = 30.0 * WS     # a rubble heap eases off over this depth past the range it spans
const RUBBLE_TINT_H: float = 20.0        # heap height at which the rubble tint is full
const RUBBLE := "#6f675d"                # rubble: broken concrete and brick dust
const SHORE_COLS: int = 16               # a land vertex this many columns from water (twice the band mesh's widest stride) keeps its level
const OUTLINE_MIN_PX: float = 0.75       # ... and the thinnest it gets on a fighter deep in the rows
const SHADOW_W: float = 56.0             # a fighter's ground shadow: across, and
const SHADOW_D: float = 26.0             # ... in depth, in world units at his feet
const SHADOW_ALPHA: float = 0.38         # its strength under a fighter on the ground,
const SHADOW_FADE_H: float = 900.0       # ... easing to a quarter of that (and half again as wide) this high above it
const SHADOW_LIFT: float = 2.0           # it lies this far above the ground, clear of it
const OUTLINE_PX: float = 1.5            # fighter outline width on screen, in pixels (placeholder until Art sets it)
const OUTLINE_F_MAX: float = 2.5         # the most a corner's outline reaches past the width (outline_bake.gd)
const OUTLINE := "#0a0d14"               # fighter outline colour
const SHORE_FLOOD: float = 24.0          # dry land at most this far below the water beside it is drawn under that water (World's shore step is at most 0.25 bh)
const WATER := Color(30.0 / 255.0, 110.0 / 255.0, 175.0 / 255.0)
const WATER_SURFACE := Color(0.42, 0.68, 0.9, 0.55)
const SKY: Array = ["#111a3e", "#4b4483", "#d9776b", "#f4b87a"]   # top to horizon
## The sky's gradient is anchored to the horizon (the far edge of the ground), in half-screen heights above it: the
## horizon colour at the line, the lower colour SKY_LOWER_AT above it, the upper at SKY_UPPER_AT, the top by
## SKY_TOP_AT. As the camera climbs the band thins by up to SKY_THIN times (a thin atmosphere rim seen from high up).
const SKY_LOWER_AT: float = 0.12
const SKY_UPPER_AT: float = 0.55
const SKY_TOP_AT: float = 1.45
const SKY_THIN: float = 5.0
const FOG_BAND: float = 0.25             # ground haze depth below the horizon line, half-screen heights

const TOWER := "#565e70"
const TOWER_DEAD := "#3f424a"
const HOUSE := "#a67c52"
const HOUSE_DEAD := "#5d4a37"
const ROOF := "#7a3b2e"
const TREE := "#1f4a26"
const TREE_TOP := "#2f6b35"
## Civilians: bright shirts over dark trousers with a dark outline, so they read on any ground. Life-size against the
## fighters (Orb: people as tall as a fighter, towers tens of times taller): CROWD_SCALE times the 17-unit figure. They
## grow further as the camera zooms out, up to CROWD_BOOST_MAX, so they stay about CROWD_MIN_PX tall on screen.
const CROWD: Array = ["#f8f9fa", "#ffd43b", "#ff6b6b", "#4dabf7", "#69db7c", "#ff922b", "#da77f2", "#3bc9db"]
const CROWD_SKIN: Array = ["#f1c9a5", "#8d5a3b"]
const CROWD_LEGS := "#2b2f3f"
const CROWD_OUTLINE := "#0d0e14"
const CROWD_SCALE: float = 5.0          # about a fighter's height (90)
const CROWD_SPREAD: float = 50.0 * WS    # how far past a building's width its people stand
const CROWD_MIN_PX: float = 12.0
const CROWD_BOOST_MAX: float = 2.0
const CROWD_OUTLINE_PX: float = 1.1
## Evacuation (render/core/crowd_flight.gd, World's `evacuate` event): people who flee a blow run away from it, faster
## the closer they were, drifting back behind the building row; a share look back once; each fades out at the end of
## its run. The run cycle plays in the figure's plane, as a runner seen side-on. Speeds and the stride are a person's
## (fighter scale); the blow's reach is the world's.
const RUN_SPEED: float = 420.0          # units a second: a sprint for a life-size person
const RUN_NEAR: float = 0.6             # up to this much faster for people right at the blow ...
const RUN_NEAR_R: float = 200.0 * WS    # ... falling to none this far from it
const RUN_TIME: float = 3.2             # seconds of running before a runner is gone (each 75% to 125% of this)
const RUN_FADE: float = 0.45            # the last seconds of a run, fading out
const RUN_BEHIND: float = 60.0          # they drift this far back past their own row's face (into the row)
const RUN_DEST_MAX: float = 6.0         # the longest run to shelter in another building (they speed up past it)
const RUN_YAW: float = 20.0             # degrees they turn from face-on (back-on, running left) toward where they run
const RUN_LOOK_SHARE: float = 0.15      # the share that look back once ...
const RUN_LOOK_S: float = 0.35          # ... for this long, slowing
const RUN_STRIDE_HZ: float = 2.8        # the run cycle (render/shaders/crowd.gdshader): strides a second,
const RUN_LEG_SWING: float = 0.75       # leg and arm swing (radians), forward lean and bob (figure units)
const RUN_ARM_SWING: float = 0.9
const RUN_LEAN: float = 0.2
const RUN_BOB: float = 1.1
## Survivors near a blow (a crater, a beam's scorch or a building hit) are startled for STARTLE_S: no idle hop, arms
## over the head, a small crouch and a tremble (figure units), until the flight takes them or they calm down.
const STARTLE_R: float = 150.0 * WS
const STARTLE_S: float = 4.0
const STARTLE_ARMS: float = 2.4          # radians the arms swing up, over the head
const STARTLE_CROUCH: float = 0.1        # share of the height they drop
const STARTLE_TREMBLE: float = 0.3
## Combat's cue events (data/combat/finishers.json `cues`) as placeholder poses on the fighter rig
## (render/core/fighter_view.gd): each blends in over CUE_IN, holds, and blends out over CUE_OUT by `dur` seconds of
## sim time (hit-stop holds it). front and back: the hands' targets in the body plane (x forward, y up from the pivot,
## fighter units; the shoulders are at (12, 14) and (-12, 14)); lean: radians, negative leans forward (the stance lean's
## sign); crouch and step: units down and forward; head and yaw: radians the head, and the whole body, turn toward the
## camera; tremble: units of shake; flare, spark and guard: a brief chest flare, a spark at the front hand, the guard
## glow; badge: the stance badge's size (a tell); ring_other: a ring around the other fighter (circle). The body
## signals (lean, crouch, yaw, flare) carry the pose at gameplay zoom, where the arms are a few pixels. Cues not listed draw nothing here (camera, banner and HUD cues).
const CUE_IN: float = 0.08
const CUE_OUT: float = 0.14
const CUE_RING_S: float = 0.45
const CUE_POSES: Dictionary = {
	"brace": {"dur": 0.45, "front": [8, 8], "back": [-8, 6], "lean": 0.2, "crouch": 9.0, "flare": 0.45},
	"glance": {"dur": 0.3, "front": [28, 18], "lean": -0.1, "spark": 1.0},
	"tell": {"dur": 0.4, "back": [2, 26], "lean": 0.32, "crouch": 6.0, "step": -8.0, "badge": 1.8},
	"turn_read": {"dur": 0.45, "front": [2, 24], "lean": -0.14, "head": 0.5, "yaw": 0.7},
	"overextend": {"dur": 0.5, "front": [34, -6], "back": [-24, 2], "lean": -0.4, "crouch": 3.0, "step": 12.0},
	"circle": {"dur": 0.45, "front": [20, 6], "lean": -0.28, "ring_other": 0.6},
	"guard_set": {"dur": 0.45, "front": [32, 14], "back": [10, 18], "lean": -0.2, "step": 8.0, "guard": 1.0},
	"struggle": {"dur": 1.2, "front": [14, 26], "back": [-8, 24], "crouch": 8.0, "tremble": 2.4},
	"last_look": {"dur": 0.9, "front": [-2, 22], "lean": 0.08, "head": 0.6, "flare": 0.25},
	"breaks_hold": {"dur": 0.55, "front": [26, 30], "back": [-26, 28], "lean": 0.24, "flare": 0.9},
	"holds_on": {"dur": 0.7, "front": [18, 22], "back": [-4, 22], "crouch": -3.0, "flare": 0.3},
	"catch": {"dur": 0.45, "front": [30, 20], "lean": -0.18, "step": 8.0, "spark": 0.8},
	"glance_back": {"dur": 0.5, "lean": -0.12, "head": 2.0, "yaw": 0.4},
	"pursue": {"dur": 0.5, "front": [6, 2], "back": [-26, 8], "lean": -0.42},
	"reset": {"dur": 0.4, "front": [22, 0], "back": [-20, -4], "crouch": 5.0},
}
## Head flashes (render/core/flash_view.gd; Art's spec docs/art/flash-prototype-spec.md, data data/art/flashes.json).
## The layouts, timings, priorities, colours of the info flashes and Legal's rules are Art's data; these are the
## drawing's own numbers from the spec. Sizes are in layout units: a twelfth of the fighter's head size, the data's
## own unit. For Art's figures that is also the spec's hundredth of a body height; the placeholder's head is larger
## (a 20-unit head on a 90-unit body), so the head rule keeps every flash as Art drew it around the head.
const FLASH_UP: float = 2.0             # the flash's origin above the head centre
## The spec puts the flash just behind the head. The placeholder's hair crest is deep and would swallow it, so the
## flash draws in front (FLASH_Z) with the head's own disc cut out (never over the face). Glyphs rise by any excess
## of the head's radius over Art's (FLASH_ART_HEAD_R; none with the head unit).
const FLASH_Z: float = 24.0             # world units in front of the fighter plane, past the head and hair
const FLASH_ART_HEAD_R: float = 6.0     # Art's head radius in layout units (head size 12)
const FLASH_GLYPH_AT: Array = [[2.0, 5.0]]                 # a glyph's place from the origin; hazard's two bangs:
const FLASH_GLYPH2_AT: Array = [[-5.5, 5.0], [9.0, 5.0]]
const FLASH_OUT: float = 0.1            # seconds a preempted flash takes to fade (spec section 7)
const FLASH_JITTER: Dictionary = {"hurt": 0.04}     # irregular jitter per shape, as a share of the body height
const FLASH_JITTER_HZ: float = 18.0     # how often the jitter moves
const FLASH_SWEEP: Dictionary = {}     # degrees a layout sweeps over its first pulse's swell (rage no longer does)
const FLASH_BLADE_W: float = 2.3        # half widths of blades and wedges, layout units (thin, after the playtest)
const FLASH_WEDGE_W: float = 5.2
const FLASH_GLYPH_SCALE: float = 1.1    # glyph units to layout units at full size
## The placeholders' shape families: P1 draws as the Protagonist, P2 as the Anti-hero; Alt+F (Alt+Shift+F for P2)
## cycles a fighter through all four. The colours are Art's (flashes.json `accents`, `emotion_colours`).
const FLASH_FAMILY: Array = ["P", "A"]

const SKIN := "#efc7a2"
const ARM := "#e6b995"
const LEGS := "#1b1f2a"
const CAPE := "#7a1414"
const EYE := "#111111"
## Stance colours for the badge above each fighter: aggressive, defensive, evasive, escape.
const STANCE_COL: Array = ["#ff5a4a", "#4aa8ff", "#5ed17a", "#b58cff"]
const STANCE_SHORT: Array = ["ATK", "DEF", "EVA", "ESC"]
const STANCE_LONG: Array = ["AGGRESSIVE", "DEFENSIVE", "EVASIVE", "ESCAPE"]

## Staging (Orb: fighters "cheat out" like stage actors, docs/ep/vision.md). A fighter is turned toward the camera by
## a pose angle in degrees from a pure profile: TURN by state ("sliding" while a knockback slide runs), plus
## TURN_STANCE by stance when free or locked; the head leads by TURN_HEAD. A facing flip turns through facing the
## camera in TURN_TIME seconds; pose changes ease at TURN_RATE_DEG per second. Art tunes these (and a fighter's
## turn_scale) for its turnarounds.
const TURN: Dictionary = {"free": 30.0, "locked": 24.0, "charging": 36.0, "launched": 34.0, "down": 38.0, "sliding": 28.0}
const TURN_DEFAULT: float = 30.0
const TURN_STANCE: Array = [-5.0, 6.0, 0.0, 4.0]   # aggressive squares to the opponent; defensive opens to the camera
const TURN_HEAD: float = 12.0
const TURN_TIME: float = 0.16
const TURN_RATE_DEG: float = 240.0
const SLIDE_LEAN: float = 0.35           # radians: a sliding fighter stays upright, leaning back against the slide
const SLIDE_CROUCH: float = 6.0          # and crouches this much
const HIDDEN_ALPHA: float = 0.22
const HIT_FLASH_S: float = 0.12

static var _colors: Dictionary = {}


## A CSS hex colour ("#fff", "#3d8fdc") as a Color, cached: the sim's colours are strings.
static func col(hex: String) -> Color:
	var c = _colors.get(hex)
	if c == null:
		c = Color.html(hex)
		_colors[hex] = c
	return c
