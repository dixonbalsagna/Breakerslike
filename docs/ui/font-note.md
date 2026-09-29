# Font note: the missing arrow, and the licence position

Owner: UI and UX. 2026-09-29. For Legal, through the EP. Not legal advice.

## The bug

The director feed prints "→" (beam tags such as `TIDE CLEAVE (…) → HIT`, and `→ COUNTER`). The web build has no system fonts, so it only has Godot's built-in fallback font, and that font has no arrow. Checked in Godot 4.7.2 (`ThemeDB.fallback_font`): it is **Open Sans SemiBold**, and `has_char` is false for `→`, `▶` and `◀`, and true for `×`, `—`, `·`, `…` and the quotes.

## The fix: change the glyph, bundle nothing

`ui/core/ui_text.gd` never asks the font for a glyph it does not have:
- "→" is drawn as a vector arrow inside the line of text.
- Other missing glyphs fall back to ASCII (`×` to `x`, `—` to `-`, `·` to `-`, `…` to `...`).
- Stance icons, the hidden eye, the star, chevrons and pips are all vector shapes, so no HUD cue needs a symbol font.

The sim's strings are unchanged. Rendering's old `hud.gd` still shows the box until it is replaced by the new HUD; a one-line stopgap there is `l.tag.replace("→", ">")`.

## Licence position

- **No font was added to the repo or a build.** So there is no new third-party component to register, and `LR-004` ("Fonts: none bundled") stays true for our own files.
- The fallback font is built into the Godot engine and ships in every build. From Godot's own `COPYRIGHT.txt` (master branch, read 2026-09-29 through a page summary, not checked against the 4.7.2 tag): Open Sans is "2020, The Open Sans Project Authors", **OFL-1.1**. It is covered by `LR-001` and `LR-002` (the engine's own licences screen). **Ask for Legal:** confirm this against the 4.7.2 source, and consider adding one sentence to `LR-004` saying that the engine's built-in Open Sans is the only font in a build.

## If Orb or Art wants a real UI font

A bundled font would improve typography and language coverage. Steps: pick an OFL-1.1 family (for example one the prototype already names, Barlow or Barlow Condensed, or an accessibility-first face), ask Legal for a register row **before** it is added, download the files from the publisher (needs permission), put them in `ui/fonts/` with the licence text, and set `UiText.font`. Nothing else in the HUD changes.
