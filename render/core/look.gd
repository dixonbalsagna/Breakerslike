class_name RenderLook
## Greybox look: every colour and dimension the renderer uses, in one place. Placeholder values until Art's palette
## and the procedural generator specs land; then these move to data files. The biome, prop and HUD colours are the
## prototype's (prototype/index.html BCOL and draw*), so the greybox reads like the prototype.

## Camera: vertical field of view in degrees. The reference camera's zoom z (pixels per world unit) is honoured
## exactly on the fighter plane (depth 0); anything in front of or behind it gets perspective parallax.
const FOV_DEG: float = 30.0

## Depth layout, in world units along +z (toward the camera). Fighters, beams and particles live on z = 0.
const Z_TERRAIN_FRONT: float = 140.0     # front face of the ground band
const Z_TERRAIN_BACK: float = -520.0     # back edge of the band's crater rows (craters reach no further)
const TERRAIN_FLOOR: float = -5000.0     # bottom of the ground band's front face
## Rows of the ground band's top grid, front to back. Dense near the fighter plane, where bowls are narrow; the row at
## exactly 0 reads the sim's profile (render/core/ground_field.gd).
const BAND_ROWS: Array = [140.0, 110.0, 84.0, 62.0, 44.0, 30.0, 18.0, 8.0, 0.0, -8.0, -18.0, -30.0, -44.0, -62.0, -84.0, -110.0, -140.0, -176.0, -218.0, -266.0, -320.0, -380.0, -448.0, -520.0]
const Z_BUILDING_FRONT: float = -44.0    # buildings stand behind the fighter plane
const Z_TREE_MIN: float = -120.0
const Z_TREE_MAX: float = -30.0
const Z_CROWD_MIN: float = -40.0
const Z_CROWD_MAX: float = -8.0
const Z_PARTICLES: float = 10.0
const Z_BEAMS: float = 6.0
## The ground continues behind the crater rows to the horizon as one surface (no separate backdrop): these rows,
## widening with distance, carry the far terrain, which blends in from the band's own heights over FAR_BLEND and is
## the same planet (each column's base height and biome, with relief). It fades into the sky between FOG_NEAR and
## FOG_FAR, so its far edge never shows.
const FAR_ROWS: Array = [-570.0, -625.0, -685.0, -750.0, -820.0, -895.0, -975.0, -1060.0, -1150.0, -1250.0, -1360.0, -1480.0, -1610.0, -1750.0, -1900.0, -2070.0, -2260.0, -2470.0, -2700.0, -2960.0, -3250.0, -3580.0, -3950.0, -4370.0, -4850.0, -5400.0, -6050.0, -6800.0, -7700.0, -8750.0, -10000.0, -12000.0]
const FAR_BLEND: float = 900.0
const MEANDER: float = 600.0             # how far (in x) the far land's biomes wander with depth
const FOG_NEAR: float = 700.0
const FOG_FAR: float = 12000.0
## Far relief per biome: [height multiplier on the base terrain, relief amplitude], smoothed across biome borders.
const FAR_RELIEF: Dictionary = {
	"ocean": [1.0, 40.0], "plains": [1.0, 45.0], "city": [1.0, 12.0], "village": [1.0, 30.0],
	"forest": [1.0, 70.0], "desert": [1.0, 55.0], "mountains": [1.25, 300.0],
}
const FAR_SMOOTH_COLS: int = 24          # half width of the smoothing, in columns
const SNOW_FROM: float = 560.0           # far peaks whiten above this height ...
const SNOW_FULL: float = 900.0           # ... fully by this
const SNOW := "#dfe3ec"
const PLANET_COPIES: int = 2             # ground and water copies each side of the camera (props use 1)

## Planet-scale cues. Horizon curvature: how far the world behind the fighter plane sags at the screen edge, as a
## fraction of screen height (for the depth-weighted bend in render/shaders/bend.gdshaderinc). It grows from
## CURVE_NEAR at close zoom to CURVE_WIDE at wide zoom, plus CURVE_HIGH as the camera climbs.
const CURVE_NEAR: float = 0.035
const CURVE_WIDE: float = 0.10
const CURVE_HIGH: float = 0.10
const ZOOM_CLOSE: float = 0.6
const ZOOM_WIDE: float = 0.2
const HIGH_FROM: float = 600.0           # camera y where the sky starts turning to space
const HIGH_TO: float = 2200.0

const BIOME: Dictionary = {
	"ocean": "#2a6b98", "plains": "#5f9140", "city": "#6c7079", "village": "#7c8e4b",
	"forest": "#2e6a35", "desert": "#cfa85c", "mountains": "#7e766a",
}
const SEA_FLOOR := "#5a5346"
const CRATER := "#4a4237"
const CRATER_DESERT := "#a98544"
const EJECTA := "#9a8a70"                # rims and aprons, dusty
const CHAR := "#1d1715"                  # scorched ground at full burn
const HEAT_LO := "#c2381c"               # a cooling groove
const HEAT_HI := "#ffd27a"               # a fresh groove from a strong beam
## Ground field widths across the band's depth (render/core/ground_field.gd). Bowls and grooves take their sizes from
## the sim (each crater record's r, depth and rim; the scorch constants in WorldCrater); only these are the renderer's.
const FURROW_W_R: float = 0.3            # a furrow's half width across the band, per unit of its crater's r ...
const FURROW_W_MIN: float = 20.0         # ... and at least this
const GROUND_SPREAD: float = 60.0        # half width across the band of dents with no record (dropped craters, clips)
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
## Civilians: bright shirts over dark trousers with a dark outline, so they read on any ground. They are drawn about
## twice real scale (a person is about 7 units against 120 to 660-unit towers) and grow further as the camera zooms
## out, up to CROWD_BOOST_MAX, so they stay about CROWD_MIN_PX tall on screen.
const CROWD: Array = ["#f8f9fa", "#ffd43b", "#ff6b6b", "#4dabf7", "#69db7c", "#ff922b", "#da77f2", "#3bc9db"]
const CROWD_SKIN: Array = ["#f1c9a5", "#8d5a3b"]
const CROWD_LEGS := "#2b2f3f"
const CROWD_OUTLINE := "#0d0e14"
const CROWD_SPREAD: float = 50.0         # how far past a building's width its people stand
const CROWD_MIN_PX: float = 12.0
const CROWD_BOOST_MAX: float = 2.0
const CROWD_OUTLINE_PX: float = 1.1

const SKIN := "#efc7a2"
const ARM := "#e6b995"
const LEGS := "#1b1f2a"
const CAPE := "#7a1414"
const EYE := "#111111"
## Stance colours for the badge above each fighter: aggressive, defensive, evasive, escape.
const STANCE_COL: Array = ["#ff5a4a", "#4aa8ff", "#5ed17a", "#b58cff"]
const STANCE_SHORT: Array = ["ATK", "DEF", "EVA", "ESC"]
const STANCE_LONG: Array = ["AGGRESSIVE", "DEFENSIVE", "EVASIVE", "ESCAPE"]

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
