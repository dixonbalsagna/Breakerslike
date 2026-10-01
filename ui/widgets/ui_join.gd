class_name UiJoin
extends RefCounted
## The player-two join note (docs/ui/hud-spec.md section 30): while one person plays the AI, a small persistent line in the AI's column says
## "P2: press any button to join". It shows from the start of the match, fades after SHOW seconds of fight time and comes back in the pause
## menu; it is hidden on a touch screen and once player two has joined. When player two joins (or hands back) a brief "P2 joined" ("P2 handed
## back to the AI") note takes its place for NOTE seconds. It sits in the AI fighter's prompt row, which is empty for an AI. `plan` is pure
## geometry and text-fitting so hud_check can prove the line fits its row; `draw` paints from it.

const SHOW := 25.0    # seconds of fight time the join prompt stays before it fades
const FADE := 2.0     # the length of the fade
const NOTE := 2.6     # seconds a "joined" or "handed back" note shows
const KINDS := ["prompt", "joined", "left"]


## `kbd`: the keyboard is the only device, so the way in is the T key (Controls' joinable rule), not "any button".
## `level` 0 is the full words, 1 shorter, 2 the shortest (for a very narrow column).
static func words(kind: String, level: int = 0, kbd: bool = false) -> String:
	match kind:
		"joined":
			return UiData.t("prompt.joined")
		"left":
			return UiData.t("prompt.left" if level == 0 else "prompt.left_short")
	var suffix: String = ["", "_short", "_tiny"][clampi(level, 0, 2)]
	return UiData.t(("prompt.join_key" if kbd else "prompt.join") + suffix)


## How strongly the join prompt shows, 0 to 1, `t` seconds of fight time since it became due: full, then a fade over FADE after SHOW.
static func alpha(t: float) -> float:
	if t < 0.0:
		return 0.0
	return clampf(1.0 - (t - SHOW) / FADE, 0.0, 1.0) * clampf(t / 0.3, 0.0, 1.0)


## The line for `kind` in `rect`: {text, fs, fits, rect}. The full words at the largest size from 18 design px down to the text floor that fit, else the
## short words; fits says whether either did.
static func plan(rect: Rect2, s: float, kind: String, kbd: bool = false) -> Dictionary:
	if rect.size.y <= 0.0 or rect.size.x <= 0.0:
		return {"text": "", "fs": 0, "fits": false, "rect": rect}
	var pad: float = maxf(10.0 * s, 6.0)
	var avail: float = rect.size.x - pad * 2.0
	var fs0: int = UiText.px(18.0, s)
	for level in [0, 1, 2]:
		var text: String = words(kind, level, kbd)
		var fs: int = fs0
		while true:
			if UiText.width(text, fs) <= avail and UiText.height(fs) <= rect.size.y:
				return {"text": text, "fs": fs, "fits": true, "rect": rect}
			if fs <= int(UiLook.text_floor):
				break
			fs -= 1
	return {"text": words(kind, 2, kbd), "fs": int(UiLook.text_floor), "fits": false, "rect": rect}


static func sig(p: Dictionary, kind: String, a: float) -> Array:
	return [kind, int(a * 10.0), str(p["text"]), int(p["fs"]), int((p["rect"] as Rect2).position.x), int((p["rect"] as Rect2).position.y), int((p["rect"] as Rect2).size.x)]


## Draw the line in its row with the AI fighter's lane colour at the edge.
static func draw(ci: CanvasItem, p: Dictionary, aura: Color, a: float, s: float) -> void:
	if a <= 0.01 or str(p["text"]) == "":
		return
	var r: Rect2 = p["rect"]
	var fs: int = int(p["fs"])
	UiText.no_outline = true
	UiIcons.rrect(ci, r, r.size.y * 0.3, Color(Color(UiLook.col(UiLook.SCRIM)), 0.62 * a), Color(aura, 0.7 * a), maxf(1.5, 2.0 * s))
	UiText.draw(ci, str(p["text"]), Vector2(r.get_center().x, r.get_center().y + float(fs) * 0.35), fs, Color(Color(UiLook.col(UiLook.INK)), a), 0)
	UiText.no_outline = false
