class_name UiRecipe
## The "Show recipe" readout (option show_recipe, off by default): the mix of blows a player has been throwing, from the press reader's
## `mix_long` (sim/input/press_read.gd, the last five presses: {light, heavy, sig, energy}). PLACEHOLDER: only the words are built. The host
## gives `UiHud.recipe_fn(slot)` once the press log is in the sim (UiSimBridge.recipe reads it when a fighter has one), the HUD keeps
## `UiFighterModel.recipe` current while the option is on, and nothing is drawn until the alchemist exists and Orb has seen what it reads.

const ORDER: Array = ["light", "heavy", "sig", "energy"]


## The mix as words, "2 light, 1 heavy, 2 energy" (kinds with none are left out), or "" for an empty or missing mix.
static func text(mix: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in ORDER:
		var n: int = int(mix.get(k, 0))
		if n > 0:
			parts.append("%d %s" % [n, UiData.t("prompt.recipe_" + k)])
	return ", ".join(parts)
