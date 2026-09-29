class_name RenderLook
## Greybox look: every colour and dimension the renderer uses, in one place. Placeholder values until Art's palette
## and the procedural generator specs land; then these move to data files. The biome, prop and HUD colours are the
## prototype's (prototype/index.html BCOL and draw*), so the greybox reads like the prototype.

## Camera: vertical field of view in degrees. The reference camera's zoom z (pixels per world unit) is honoured
## exactly on the fighter plane (depth 0); anything in front of or behind it gets perspective parallax.
const FOV_DEG: float = 30.0

## Depth layout, in world units along +z (toward the camera). Fighters, beams and particles live on z = 0.
const Z_TERRAIN_FRONT: float = 140.0     # front face of the ground band
const Z_TERRAIN_BACK: float = -520.0     # back edge of the ground band
const TERRAIN_FLOOR: float = -5000.0     # bottom of the ground band's front face
const Z_BUILDING_FRONT: float = -44.0    # buildings stand behind the fighter plane
const Z_TREE_MIN: float = -120.0
const Z_TREE_MAX: float = -30.0
const Z_CROWD_MIN: float = -40.0
const Z_CROWD_MAX: float = -8.0
const Z_PARTICLES: float = 10.0
const Z_BEAMS: float = 6.0
const RIDGES: Array = [  # far parallax ridges: [depth z, base height, amplitude, colour]
	[-3400.0, 330.0, 260.0, "#2b2850"],
	[-2500.0, 190.0, 170.0, "#3a3560"],
]
const Z_FAR_LAND: float = -1500.0        # the planet's biomes rebuilt as a distant silhouette
const Z_ATMOSPHERE: float = -4200.0      # the glowing limb behind everything

## Planet-scale cues. Horizon curvature: how far the world behind the fighter plane sags at the screen edge, as a
## fraction of screen height (for the depth-weighted bend in render/shaders/bend.gdshaderinc). It grows from
## CURVE_NEAR at close zoom to CURVE_WIDE at wide zoom, plus CURVE_HIGH as the camera climbs.
const CURVE_NEAR: float = 0.035
const CURVE_WIDE: float = 0.10
const CURVE_HIGH: float = 0.06
const ZOOM_CLOSE: float = 0.6
const ZOOM_WIDE: float = 0.2
const HIGH_FROM: float = 600.0           # camera y where the sky starts turning to space
const HIGH_TO: float = 2200.0
const HAZE := "#5a4d85"                  # aerial haze the far land fades toward
const FAR_HAZE: float = 0.55
const ATMOSPHERE := "#ffc48a"

const BIOME: Dictionary = {
	"ocean": "#2a6b98", "plains": "#5f9140", "city": "#6c7079", "village": "#7c8e4b",
	"forest": "#2e6a35", "desert": "#cfa85c", "mountains": "#7e766a",
}
const SEA_FLOOR := "#5a5346"
const CRATER := "#4a4237"
const CRATER_DESERT := "#a98544"
const WATER := Color(30.0 / 255.0, 110.0 / 255.0, 175.0 / 255.0)
const WATER_SURFACE := Color(0.42, 0.68, 0.9, 0.55)
const SKY: Array = ["#111a3e", "#4b4483", "#d9776b", "#f4b87a"]   # top to horizon

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
