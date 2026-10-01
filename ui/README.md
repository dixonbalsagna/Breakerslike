# ui/: the HUD

Owner: UI and UX. The spec is `docs/ui/hud-spec.md`. There are no health bars: damage is read on the aura crown, the silhouette and the wound cards. Everything here reads sim state and events and never writes them, draws no random numbers, and animates by wall time only.

## Run the demo

Import once so the `class_name` scripts register, then open the demo scene:

```
godot --headless --path . --import
godot --path . res://ui/demo/hud_demo.tscn
```

The demo draws the real HUD over a greybox backdrop, driven by `ui/mock/ui_mock_feed.gd`, a scripted feed shaped like spec-wounds.md §4's events. Keys: Tab scenario, Space pause, R restart, S silhouette (off by default), F4 feed, C captions, M reduced motion, K keep the crown up, B brink ring, D simulated split screen, X flip sides, T arc thickness, Z clear zones, L region label, V viewport size, +/- fighter size, H legend. The crown is transient: it pops on a hit, a stage change, the brink, a Rally or a tier-up and fades back; at rest the fighters are clean.

Options after `--`: `--scenario=hero_vs_proud|empress_vs_cyborg|placeholders|stress|controls`, `--at=SECONDS` (fast-forward the feed), `--frames=N --shot=file.png` (save a frame), `--portrait`, `--clear`, `--nofeed`, `--sil`, `--crown`, `--reduced`, `--nolegend`, `--prompts`. Add Godot's `--fixed-fps 60 --resolution 1920x1080` for a known frame.

## Check

```
godot --headless --path . --script res://ui/tools/hud_check.gd
```

Exits 0 when the terms, the layout at ten sizes, the hub's rules, the mock scenarios against the readability caps, a draw of every scenario, and the bridge against the live sim all pass. If the sim does not compile (another director's working tree), the bridge check prints SKIP.

## Layout of the folder

| Path | What |
| :--- | :--- |
| `hud/ui_hud.tscn`, `ui_hud.gd` | The root `Control` a main scene hosts. `setup`, `consume_all`, `advance`, `anchor_fn`, `strip_fn`, `opts` |
| `core/ui_event_hub.gd` | Folds events and state patches into models, cards, barks, banner and feed; enforces the caps |
| `core/ui_fighter_model.gd` | One fighter's view model (stages, meters, windows, hidden) |
| `core/ui_layout.gd` | Every rectangle, for landscape and portrait, and the fighter-clear zone |
| `core/ui_look.gd` | Colour roles, sizes, timings, caps (provisional until Art) |
| `core/ui_data.gd` | Loads `data/terms.json` and `data/readout_profiles.json` |
| `core/ui_text.gd`, `ui_icons.gd`, `ui_body.gd`, `ui_bark_timing.gd` | Text with the arrow fix; vector icons; the body figure; bark reveal timing |
| `core/ui_sim_bridge.gd` | Reads the live greybox sim into the HUD (read only) |
| `widgets/` | Crown, silhouette, plate, cards, barks, centre (toll, banner), strip, feed, `ui_split.gd` (the split-screen divider geometry, ring map and pointer chips), `ui_glyphs.gd` (the neutral prompt glyphs), `ui_prompts.gd` (the prompt row) and `ui_struggle.gd` (the finisher beat rings) and `ui_howto.gd` (the How to play card) `ui_reads.gd` (the weight mark, the finisher telegraph, the tutorial hint line) `ui_feedback.gd` (the feedback panel, its report and the GitHub issue link) and `ui_hints.gd` (the control legend and the YOU label) and `ui_touch_controls.gd` (the touch Simple buttons) and `ui_settings.gd` (the Settings screen): static draw functions |
| `data/` | Player-facing terms (Narrative's glossary), per-fighter readout profiles, and the player options with their defaults (`options.json`: `info_flashes`, `crown_always`, `silhouette`, ...), feature flags (`features.json`: `hiding`, off), the prompt glyph tables (`glyphs.json`) and the How to play card's words (`howto.json`), the telegraph counters and tutorial hint lines (`reads.json`), and the feedback panel's words (`feedback.json`), its Send step (`send.json`) and the control hints' schemes (`hints.json`) and the Settings screen's sections and words (`settings.json`) |
| `mock/`, `demo/`, `tools/` | The mock feed, the demo scene, the checks |

## What a host does

See `docs/ui/hud-spec.md` section 14. In short: instance `ui/hud/ui_hud.tscn`, call `setup`, give it `anchor_fn` and `strip_fn`, call `UiSimBridge.patch` and `consume_all` each tick, `advance(delta)` each frame. Changing `render/` to do it is Rendering's, routed by the EP.

## Rules

- Transient by default: nothing sits over the fighters at rest except the brink ring (option `brink_cue`). Options: `silhouette` (off), `crown_always` (off), `numeral` in a profile (off).
- Original HUD only: no scanner, no numeric power readout, no hair-colour cue, no borrowed font or logo. "ki" is an internal label; the player sees Charge.
- No cue is colour-only. Every colour role is paired with a shape, pattern, icon or motion.
- Every player-facing word is data in `data/terms.json`.
- The Empress's paperwork is never shown (Orb): no stamp cards, no forms, no REJECTED or REGISTERED text.

## Performance

The HUD is a stack of cached layers (`hud/ui_layer.gd`): a layer redraws only when its small signature changes, so at rest nothing is redrawn. To measure it in the live build (a window opens; alternates the UI HUD shown and hidden and prints the cost in wall time, render CPU and GPU, and draw calls):

```
godot --path . --fixed-fps 60 --resolution 1280x720 --script res://ui/tools/hud_bench.gd -- --seed=4 --blocks=6 --block=300
```

Add `--force` to redraw every layer every frame (the cost without caching), or `--rawpolys` to draw polygons unguarded. Results are in `docs/ui/hud-spec.md` section 14.

## Automated playtest

`godot --headless --path . --script res://ui/tools/hud_playtest.gd -- --matches=12 --seed=1` runs whole live AI matches, feeds the HUD model the real events, and reports crown time, brink time, card latency for every break, cap violations and a midpoint "who is closer to losing" proxy for spec tests 8 and 9. Tests 10 and 11 need human eyes.

## Responsive and touch, and the How to play card

- `UiHud.set_density(dp)` (else detected), option `touch_ui`, `touch_rects()` and `touch_target_at(pos)`: see `docs/ui/hud-spec.md` section 16. Text is at least 12 dp on a dense screen, touch targets at least 48 dp. Demo: `--dp=2.6 --touch` with `--resolution 2400x1080`.
- `show_settings()`, `hide_settings()`, `is_settings_open()`, `is_overlay_open()`, `settings_action(act)`, `load_saved_options()`, signals `settings_opened`, `settings_closed`, `settings_action_requested(action)`; every change fires `option_changed`. The host freezes the sim while it is open and leaves pad and keys to the HUD. Section 26. Demo: `--settings[=N]` (N steps of focus down), `--pad`, `--sscroll=PX`.
- `show_howto(first_run, page)`, `hide_howto()`, `is_howto_open()`, `howto_seen()`, signals `howto_opened` and `howto_closed`; F1 toggles it. The host freezes the sim while it is open. Section 17. Demo: `--howto=0|1|2`, `--device=xbox`, `--preset=arena|brawler|simple-pad|kb-solo|kb-shared-p2` (the layout the legend and the card describe), `--ready` (a form is ready), `--stance=N`, `--target=github|mailto|form` (a send target for the feedback shots).

## Q4 reads (docs/ui/hud-spec.md sections 18 and 19)

The director times every blow; the player reads and answers. The plate shows the weight and the signature intent; a chip names the finisher's kind while it winds up; the struggle's pulses reveal a result; tutorial hints come from `ui/data/reads.json` through `tutorial_hint` events; barks have caption, thought and shout styles. Demo: `--scenario=controls --prompts` (the full Q4 loop), `--at=SECONDS` to jump.
