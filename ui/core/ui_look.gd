class_name UiLook
## Every colour role, size and timing the HUD uses, in one place (like render/core/look.gd). Colours are SEMANTIC ROLES
## with provisional hex values: Art owns the palette, Accessibility reviews the contrast. No cue relies on colour
## alone: every role is paired with a shape, pattern, icon or motion (docs/ui/hud-spec.md section 2).

## Design space. Landscape is laid out against 1920x1080, portrait against 1080x1920; everything scales by `s`.
const DESIGN_LANDSCAPE := Vector2(1920.0, 1080.0)
const DESIGN_PORTRAIT := Vector2(1080.0, 1920.0)
const SCALE_MIN := 0.45
const SCALE_MAX := 2.5
## Smallest text ever drawn, in real pixels: player-facing text and the debug feed.
const MIN_TEXT_PX := 14.0
const MIN_DEBUG_PX := 12.0

## Wound stages: 0 fresh, 1 bruised, 2 battered, 3 broken (spec-wounds.md section 1).
const STAGE_NAMES: Array = ["fresh", "bruised", "battered", "broken"]
const STAGE_BRUISED_AT := 30.0
const STAGE_BATTERED_AT := 60.0
const STAGE_BROKEN_AT := 90.0

## Colour roles (provisional hex; see Art).
const INK := "#f4f1ea"
const INK_DIM := "#b9b6ad"
const INK_DARK := "#10121a"
const SCRIM := "#0b0d14"
const SCRIM_ALPHA := 0.62
const EDGE := "#e8e4d8"
const STAGE_FRESH := "#8fd6ff"        # fallback: a fighter's own aura colour replaces it
const STAGE_BRUISED := "#f2e6a0"
const STAGE_BATTERED := "#ffb454"
const STAGE_BROKEN := "#ff5c8a"
const INTERNAL := "#bfeeff"           # the Protagonist's internal (scald) wear: cool white, never red (Legal)
const CHARGE := "#5fb4ff"
const CHARGE_READY := "#c8e6ff"
const TIER_PIP := "#ffe9a8"
const HIDDEN := "#bedcff"
const WARN := "#ffd45a"
const EGO: Dictionary = {
	"respect": "#6fd1a8", "pride": "#c9a8ff", "wrath": "#ff9a5c", "hunger": "#e0c14a",
	"menace": "#b05cff", "anguish": "#3fd6c5",
}
const STANCE_COL: Array = ["#ff6a5a", "#5aaaff", "#62d986", "#b892ff"]
const BIOME: Dictionary = {
	"ocean": "#2a6b98", "plains": "#5f9140", "city": "#6c7079", "village": "#7c8e4b",
	"forest": "#2e6a35", "desert": "#cfa85c", "mountains": "#7e766a",
}

## Timings, seconds.
const CARD_LIFE := 1.5                # spec-wounds.md section 3: about 1.5 s
const CARD_LIFE_BROKEN := 2.2         # a break holds longer: it is a chapter
const CARD_FADE := 0.25
const CARD_TOAST_LIFE := 0.9          # a bruise: a single line, only when nothing else is showing
const CARD_WAIT_MAX := 2.5            # a queued card older than this is dropped (a break waits up to CARD_WAIT_BREAK)
const CARD_WAIT_BREAK := 6.0
const CARD_STAMP := 0.18              # the stamp-in animation
const BARK_MIN := 1.2                 # line-system.md section 9: barks show between 1.2 and 3.5 s
const BARK_MAX := 3.5
const BARK_SETPIECE_MAX := 6.0
const MEND_SWEEP := 0.5
const CUE_PULSE := 0.35
const WINDOW_MIN_SHOWN := 0.12        # a window shorter than this still shows for this long, so it registers

## Readability caps: how much may show at once (spec section 8). Index: NORMAL, HAZARD, CINEMATIC.
const CAP_CARDS_PER_SIDE: Array = [3, 2, 1]
const CAP_BARK_LINES: Array = [2, 2, 1]
const CAP_TOASTS: Array = [1, 0, 0]
const CAP_FEED_LINES: Array = [14, 6, 0]
## The camera-shake strength (the fx `shake` event's k) at or above which the HUD treats the moment as a hazard: the sim's
## power-ups, beams and collapses (14 to 16), heavy launches and ground hits (18 to 30), not an ordinary hit (6 to 12).
const HAZARD_SHAKE_K := 14.0
const HAZARD_HOLD := 1.2

## Crown geometry, in units of the crown radius R (the fighter's height, floored at CROWN_MIN_R design px).
const CROWN_MIN_R := 46.0
const CROWN_MAX_R := 150.0
const CROWN_R_PER_HEIGHT := 0.78
const CROWN_CORE_R := 0.5
const CROWN_MANTLE_R := 1.2
const CROWN_THICK := 0.085            # arc thickness as a fraction of R, floored at CROWN_MIN_THICK design px
const CROWN_MIN_THICK := 4.0

## Flicker and pulse rates, Hz.
const HZ_BATTERED := 4.0
const HZ_BRINK := 1.2
const HZ_HEAT := 2.2


static var _cache: Dictionary = {}


static func col(hex: String) -> Color:
	var c = _cache.get(hex)
	if c == null:
		c = Color.html(hex)
		_cache[hex] = c
	return c


static func alpha(hex: String, a: float) -> Color:
	var c: Color = col(hex)
	return Color(c.r, c.g, c.b, a)


static func stage_col(stage: int, fresh: Color) -> Color:
	match stage:
		0:
			return fresh
		1:
			return col(STAGE_BRUISED)
		2:
			return col(STAGE_BATTERED)
	return col(STAGE_BROKEN)


static func stance_col(idx: int) -> Color:
	return col(STANCE_COL[clampi(idx, 0, 3)])


static func ego_col(name: String) -> Color:
	return col(EGO.get(name, "#cccccc"))
