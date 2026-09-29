# ui/: the HUD

Owner: UI and UX. The spec is `docs/ui/hud-spec.md`. There are no health bars: damage is read on the aura crown, the silhouette and the wound cards. Everything here reads sim state and events and never writes them, draws no random numbers, and animates by wall time only.

## Run the demo

Import once so the `class_name` scripts register, then open the demo scene:

```
godot --headless --path . --import
godot --path . res://ui/demo/hud_demo.tscn
```

The demo draws the real HUD over a greybox backdrop, driven by `ui/mock/ui_mock_feed.gd`, a scripted feed shaped like spec-wounds.md §4's events. Keys: Tab scenario, Space pause, R restart, S silhouette (off by default), F4 feed, C captions, M reduced motion, K keep the crown up, B brink ring, T arc thickness, Z clear zones, L region label, V viewport size, +/- fighter size, H legend. The crown is transient: it pops on a hit, a stage change, the brink, a Rally or a tier-up and fades back; at rest the fighters are clean.

Options after `--`: `--scenario=hero_vs_proud|empress_vs_cyborg|placeholders|stress`, `--at=SECONDS` (fast-forward the feed), `--frames=N --shot=file.png` (save a frame), `--portrait`, `--clear`, `--nofeed`, `--sil`, `--crown`, `--reduced`, `--nolegend`. Add Godot's `--fixed-fps 60 --resolution 1920x1080` for a known frame.

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
| `widgets/` | Crown, silhouette, plate, cards, barks, centre (toll, banner), strip, feed: static draw functions |
| `data/` | Player-facing terms (Narrative's glossary), per-fighter readout profiles, and the player options with their defaults (`options.json`: `info_flashes`, `crown_always`, `silhouette`, ...) |
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
