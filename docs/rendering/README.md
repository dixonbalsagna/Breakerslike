# Rendering: the greybox

Owner: Rendering and Technical Art. Code: `render/`. Status: first playable greybox (P1), 2026-09-29; civilians and planet-scale pass the same day.

The main scene runs the GDScript sim (`sim/`) as a 60 Hz fixed-step loop and draws it every frame in a 2.5D side-on view of the wrapped planet. Frames are interpolated between the last two ticks. It starts as an AI-vs-AI demo; any key or click hands P1 to a human, as the prototype did. Everything on screen is a greybox made of simple meshes and flat colours. The cel-shaded look comes later with Art.

## Run it

Godot 4.7.2 (`C:\Users\itsha\AppData\Local\Programs\Godot\4.7.2\`; use `_console.exe` for headless runs). On a fresh clone, import once so the `class_name` scripts register:

```
godot --headless --path . --import
```

Then press F5 in the editor, or run:

```
godot --path .
```

| Key | Action |
| :--- | :--- |
| any key or click | take control of P1 (the demo starts AI vs AI) |
| WASD, Space, F, G, R, Q, 1-4 | P1: move, dash, light, heavy, signature, charge, stances |
| arrows, Enter, comma, period, slash, semicolon, 7-0 | P2 (the same, as in the prototype) |
| N / T / Y / P | new match / toggle P2 AI / toggle P1 AI / pause |
| F3 | performance overlay |
| Esc | quit (desktop) |

The key mapping is Controls' `sim/input/keyboard.gd`. `render/core/key_codes.gd` only turns Godot's physical keys into its code names.

Command-line options go after `--`: `--seed=N`, `--human` (take P1 at start), `--frames=N` (quit after N frames), `--shot=file.png` (save the last frame), `--bench` (vsync off; print frame-time statistics at quit), `--novsync`. Add Godot's own `--fixed-fps 60` to get exactly one tick per frame, for screenshots at a known tick.

## Scene structure (`render/main.tscn`)

```
Main          Node3D               core/main.gd         the frame loop, input, match start, bench and shots
├ Camera      Camera3D             core/camera_rig.gd   the reference camera as a 3D camera
├ Environment WorldEnvironment                          sky gradient (shaders/sky.gdshader), built in main.gd
├ Planet      Node3D               core/planet_view.gd  terrain, water, ridges, buildings, trees, crowd (3 copies)
├ Fighters    Node3D                                    one core/fighter_view.gd per fighter, built per match
├ Beams       Node3D               core/beam_view.gd    signature beams and beam clashes
├ Particles   MultiMeshInstance3D  core/particle_view.gd  the fx consumer's particles, one draw call
└ HUD         CanvasLayer
  └ Overlay   Control              core/hud.gd          panels, counters, banner, labels, damage numbers, feed, planet strip
```

| File | Role |
| :--- | :--- |
| `core/sim_host.gd` | The host: the fixed-step accumulator (overview.md section 2), keyboard intents, draining `S.out.feed` and `S.out.fx` after each tick, the reference camera and fx consumer, the camera-shake stream, and the two snapshots that frames interpolate between. It is the only render-side code that calls into the sim. |
| `core/look.gd` | Every colour and dimension of the greybox look, in one place (the prototype's palette). |
| `core/mats.gd` | Flat and glow materials over the shaders. |
| `core/crowd_mesh.gd` | The generated civilian figure (see Civilians below). |
| `shaders/` | `flat` (opaque and alpha) and `glow` (additive) for props and fighters; `terrain` and `water` (heightfield from a texture); `crowd`; `particle` (shapes per instance); `sky` (gradient, space, stars, the planet's limb); `bend.gdshaderinc` (horizon curvature). |
| `tools/seam_sweep.gd`, `tools/determinism.gd` | The seam and determinism checks (see below). |
| `tools/shots.gd` | Posed screenshots for these docs (see below). |

## How it draws

- **Camera.** A perspective camera with a 30° vertical FOV looks straight down -z. For the reference camera's x, y and zoom z (pixels per world unit, `sim/core/view/camera.gd`), the rig places the camera at distance `vh / (2 z tan(fov/2))`. On the fighter plane (z = 0) a point therefore lands on the prototype's `w2s()` pixel exactly. Things in front of or behind that plane get perspective parallax: the ground band, buildings, trees and far ridges. Screen shake is the fx consumer's `shake`, with jitter drawn once per tick from the `camera` stream.
- **Floating origin and the seam.** Everything is placed relative to the camera's wrapped x, so the camera sits at x = 0 and no coordinate grows large. World-anchored content (terrain, water, ridges, buildings, trees, crowd) is built once per match over x in [0, 9600). It is drawn as three identical copies at `k * W - cam.x` for k = -1, 0, 1, sharing meshes and MultiMeshes. The seam is therefore invisible by construction, and a view wider than the planet (tiny zoom on an ultra-wide or phone screen) shows everything wherever it appears. Fighters, beams and particles are placed by the shortest arc `sdx(cam.x, x)`. A beam is laid out from its tail along its direction, so one crossing the seam stays in one piece.
- **Terrain.** The ground band is one static mesh: per column, a front face from the surface down to a floor and a top face running back in depth. The vertex shader reads heights from a 1200 × 2 float texture (row 0 base, row 1 crater deform). The planet view re-uploads the texture only when `S.deform` changes, so craters never rebuild geometry. Crater, sea-floor and biome colours come from the same data, and water is drawn only where the base terrain is below sea level (the sim's `seaAt` rule).
- **Props.** Buildings, roofs, trees and civilians are MultiMeshes, one draw call per kind per copy. Only instances whose building, tree or ground changed are updated. The sim has civilians only as counts per building, so the greybox stands `popAlive` figures around each building. Where each one stands, the tree depths, and each civilian's shirt and skin tone come from render-side streams seeded from the fixed world seed, never from the sim stream.
- **Fighters.** Each fighter is generated from its roster colours and role: boxes, a low-poly head, and hair and cape extruded from 2D outlines. Stance shows as a badge colour, a lean and a guard glow in defensive, and the HUD labels it too. A hit makes the body flash white for 0.12 s after `hurtT`. The aura grows with tier, and aura streaks appear at tier 3 or above and while charging. A hidden fighter fades to 22 % inside a sonar ripple. The beam charge orb grows at the hand. The placeholder hero's hair is a teal, swept-back crest.
- **Shading.** All greybox materials are unshaded, with one fixed fake light in the shader. That means no light passes and the same look on every renderer. In 4.7.2 Compatibility, vertex and MultiMesh instance colours reach shaders already linear (checked by sampling rendered pixels), so the shaders use `COLOR` as it is. A MultiMesh without instance colours multiplies `COLOR` by zero there, so the crowd tags its parts in `UV` and takes its colours from custom data.
- **Interpolation.** After each tick the host snapshots fighter x, y and rotation and the camera. Frames draw at `alpha = acc / DT` between the last two snapshots, with x interpolated along the shortest arc. Beams, particles, terrain and props show the latest tick.

## Civilians and planet scale

Orb's notes on the first live build were "civilians seem too tiny" and "make the scale of the map seem more like a full planet". Both answers are presentation only: the sim's positions and counts are untouched.

**Civilians.** Each civilian is a generated figure, seen from the front so it reads as a person at a few pixels. It has legs, torso, arms and a head, is about 17 units tall, and has a dark outline shell (an inverted hull pushed out in the shader, sized to about 1 px on screen). Shirts come in eight bright colours over dark trousers, with two skin tones. They are drawn at about twice real scale: a person would be about 7 units against 120 to 660-unit towers. As the camera zooms out they grow about their feet, up to 2x, so they stay about 12 px tall down to zoom 0.35. About half of them hop idly, out of step. The crowd is still one MultiMesh, and one draw call, per copy. Tunables are in `look.gd` (`CROWD_*`).

| Before | After |
| :---: | :---: |
| ![civilians before](img/civilians-before.png) | ![civilians after](img/civilians-after.png) |

**Planet scale.** I picked the three cheapest cues that read at the zoom real fights use. In AI matches the zoom stays around 0.3 to 0.7 and the camera below about 850 units, so cues that only showed at extreme zoom would rarely be seen. All three are static meshes or shader uniforms, with no per-frame CPU work beyond a few uniforms.

1. **Horizon curvature** (`bend.gdshaderinc`). World geometry sags by `bend * x^2` across the screen, weighted by depth: nothing moves within 60 units of the fighter plane, and the weight is full from 1,260 units behind. So the fight, the ground under the fighters, the HUD mapping and the seam proof are exactly as before, while the world behind curves away like a horizon. The sag at the screen edge is 3.5 % of screen height at close zoom and 10 % at wide zoom, plus up to 6 % more as the camera climbs (`CURVE_*`). It is a function of the camera-relative x, so it is identical in every planet copy and invisible at the seam.
2. **Far land along the wrap.** 1,500 units behind the fighter plane, the planet's own biome layout is rebuilt as a hazed silhouette: city skyline, mountain range, forest canopy, dunes, rooftops and a flat sea. Depth shows a wider stretch of it than of the ground band, so the biomes ahead around the planet come into view before the fighters reach them. The world reads as a continuous planet rather than a strip.
3. **Atmosphere and the view from altitude.** A glow band behind the ridges gives the curved horizon a lit atmosphere. As the camera climbs, the sky darkens to space and stars come up. The planet's limb then rises into view: a large curved horizon with a bright rim, drawn in the sky shader only where no geometry covers the sky.

| Before | After |
| :---: | :---: |
| ![planet before](img/planet-before.png) | ![planet after](img/planet-after.png) |

Both pairs come from `godot --path . --script res://render/tools/shots.gd -- --out=DIR`, which poses the fighters on a fresh match without stepping the sim. That keeps the pictures stable while the sim's behaviour changes. The "before" images are the committed renderer (2ebdb53) run on the same sim. Other poses: `city`, `wide`, `high`.

## The sim boundary

Rendering reads and never writes. The views read `S`, the fx consumer (`sim/core/view/fx.gd`) and the reference camera. Only `SimHost` steps the sim, toggles AI, starts matches and drains `S.out`, which is exactly the host's job in `docs/architecture/overview.md`. How many ticks run per frame is the only thing that depends on frame timing, so the tick sequence and every gameplay hash are the same at any frame rate.

## Verification

All commands run from the repo root; each exits 0 on success.

| Check | Command | Result (2026-09-29) |
| :--- | :--- | :--- |
| Seam sweep | `godot --headless --path . --script res://render/tools/seam_sweep.gd -- --size=1280x720` | passed at 1280×720, 2560×720 and 720×1280 |
| Determinism | `godot --headless --path . --script res://render/tools/determinism.gd` | passed (seeds 12345 and 4) |
| Sim parity (Simulation's) | `godot --headless --path . --script res://sim/core/tools/parity.gd` | still passes |

**Seam sweep.** The tool poses the two fighters by hand (it never steps the sim) and runs the real scene on 1,331 frames. It covers flying together through the seam at separations 0, 1, 60, 400, 1500, 3000, 4500 and 4790; meeting head-on on the seam; the smallest zoom (one fighter under the sea, one at the ceiling); and one fighter lapping the planet. Per frame it checks four things:
1. Each fighter lands on the prototype's `w2s()` pixel (worst 0.0005 px).
2. Its frame-to-frame screen motion matches the reference motion (worst 0.0005 px), with no step over 120 px.
3. The ground drawn under it is the sim's ground at its own x (worst 0.0005 world units).
4. The planet copies meet exactly one planet apart (worst 0.001 units) and cover the whole view. At 2560×720 the view is 14,889 units wide against a 9,600-unit planet.

`-- --shots=DIR` (without `--headless`) also saves frames around each seam crossing; those were inspected by eye, and nothing marks the seam.

**Determinism.** For each seed the tool compares gameplay hashes every 60 ticks and at the end, across the sim alone and the full scene at 1/60 s frames, 1/144 s frames and irregular 2 to 50 ms frames (twice). All are identical. `--negative-control` nudges a fighter by 0.001 once, as a renderer write would, and the check then fails at the next checkpoint. `--live` without `--headless` also renders every frame on the GPU; it passed for seed 4. The web build reproduces the desktop gameplay hash (seed 4, tick 2400: `60432212cae42156`).

**Performance** (seed 4, one tick per frame, vsync off; frame time is wall clock per frame; Ryzen 7 9800X3D and RTX 5070 Ti, a high-end machine):

| Build | Frame mean / p95 / p99 | Sim tick mean | View update mean | Draw calls |
| :--- | :--- | :--- | :--- | :--- |
| Desktop, Compatibility, 1280×720 | 0.98 / 1.38 / 2.11 ms | 0.056 ms | 0.12 ms | about 85 |
| Desktop, Compatibility, 1920×1080 | 0.99 / 1.39 / 2.14 ms | 0.056 ms | 0.12 ms | about 85 |
| Web (Chrome 154, WebGL 2 over D3D11), 1280×720 | 1.83 / 2.50 / 3.30 ms | 0.12 ms | 0.18 ms | about 82 |
| Desktop 1280×720, after the scale pass | 0.97 / 1.32 / 2.05 ms | 0.057 ms | 0.11 ms | about 80 |
| Web 1280×720, after the scale pass | 1.82 / 2.20 / 3.10 ms | 0.13 ms | 0.16 ms | about 79 |

The scale pass was measured against the committed renderer on the same sim, the same day. Desktop before was 1.05 / 1.56 / 2.30 ms, with a 0.115 ms view update and a 0.178 ms GPU frame; after, the GPU frame is 0.166 ms. The rendering cost is unchanged within noise. The sim numbers moved because Encounter Systems is changing the director. The first three rows came from an earlier sim, so compare their rendering columns only.

The fx consumer and camera cost 0.06 ms per tick on desktop (p99 0.8 ms in explosion ticks). The web build has one 176 ms hitch on first use (shader compilation) and downloads about 10.1 MB gzipped (wasm) plus a 0.16 MB pack. Not yet measured: minimum-spec hardware (an old laptop, integrated GPU, mobile).

To reproduce the desktop numbers:

```
godot --path . --fixed-fps 60 --resolution 1280x720 -- --seed=4 --frames=4800 --bench
```

For the web: export with a Web preset (single-threaded) and pass `--fixed-fps 60 -- --seed=4 --frames=2400 --bench` in the page's engine `args`. Then drive the page with `node research/engine-spike/tools/bench-browser.mjs`, which reads the `window.__benchResult` the bench publishes. The repo has no export preset yet; the smoke test used a scratch copy of the project.

## What is placeholder

- Every visual: primitive-box fighters, box buildings, cone trees, box-figure civilians, flat colours, the sky gradient, the far land, ridges and limb. Art's palette and the cel-shaded look replace `look.gd` and the flat shaders.
- The planet-scale cues are tuned by eye (`CURVE_*`, `FAR_HAZE`, the limb in `sky.gdshader`). The curvature is a presentation lens, not the planet's true radius: at 9,600 units around, the true curve would be far stronger.
- Known issue: the crowd's idle hop runs on the shader's `TIME`, so civilians keep hopping while the game is paused. Accepted for the greybox; drive it from sim time when it matters.
- The prototype's palette and the fx event colours (CSS hex strings) are used as they are.
- The camera is the reference camera. Camera will own framing. When the fighters' separation passes half the planet, it re-targets the other arc and pans across (up to about 80 to 180 px per frame, depending on the window size). That is reference-camera behaviour, not a render pop.
- The HUD is a debug HUD drawn with the fallback font. UI will own the real one.
- No window lights on towers, no damage state on towers beyond height and colour, no burning trees, no debris volume.
- Particles follow the reference consumer (`sim/core/view/fx.gd`) exactly, one quad each. VFX will own the real effects.

## Next

- Rendering: `docs/rendering/pipeline.md` and the procedural generator specs (the extruded-outline path in `fighter_view.gd` is the seed of it), LOD and draw-call budgets once Performance sets them, and a measured run on minimum-spec hardware.
- Others, through the EP: a repo Web export preset (Tools), the half-planet camera re-targeting (Camera), and the palette and cel look (Art).
