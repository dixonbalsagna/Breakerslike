# Band prototype (option B: a fighting ground with real depth)

Research & Prototyping, 2026-10-01. A throwaway, standalone Godot 4.7 project. It is never loaded by the game or the sim, and nothing here is production code.

**The question.** Launched fighters "bounce off an invisible wall" when the building is in a background row. Option B keeps the planet a ring, but makes the fighting ground a band with real depth, so every collision is physically true. Does that feel and read better?

**Read this first.** I can't hold a controller. The prototype was checked by running it (screenshots, an input self-test, AI bouts, browser benchmarks), and the numbers below come from those runs. Everything about *feel* is an expectation for Orb to confirm or reject by playing.

## Run it
- **Desktop:** `Godot_v4.7.2-stable_win64.exe --path research/band-proto`
- **Browser:** the web export is in `research/band-proto/build/web/` (gitignored, 40 MB). Serve it with
  `node research/engine-spike/tools/serve.mjs --root research/band-proto/build/web --port 8641` and open http://127.0.0.1:8641/.
- **Rebuild the export:** `Godot_v4.7.2-stable_win64_console.exe --headless --path research/band-proto --export-release Web <abs>/build/web/index.html` (run `--import` once on a fresh copy).
- **Options** (after `--` on desktop, or in the page's query string):
  - `--demo`: the AI plays both fighters.
  - `--cam 0|1`, `--occl 0|1|2`, `--depth 0|1|2`: set the starting camera, occlusion mode and depth mode.
  - `--stats <seconds>`: fast-forward AI bouts and print what happened.
  - `--bench`: time frames and report (on the web, in `window.__benchResult`).
  - `--shot <png> --at <s>`: save a screenshot.
  - `--selftest`: drive blue through the real input actions.

## Controls (a subset of the Arena layout and the kb-solo preset, ADR 0008)
| Action | Keyboard | Pad |
|---|---|---|
| Move and fly | W A S D | left stick |
| Light / heavy | J / K | X / Y |
| Guard (hold) | Shift | LB |
| Dodge (tap; with no direction it is a sidestep in depth) | Space | LT |
| **Depth nudge** (prototype only) | R away, F towards the camera (or the up and down arrows) | right stick |
| **Depth mode**: AUTO, AUTO+ (soft magnet), MANUAL | T | d-pad left |
| **Camera**: side-on / three-quarter | C | d-pad up |
| **Occlusion**: fade / cut away / off | O | d-pad right |
| Depth aids (shadow, lane line, altitude pole) | G | d-pad down |
| Minimap / help / new round / AI plays blue | M / H / N / Y | – / View / Start / – |

## What is in it
- **The strip.** 300 body heights long and 60 deep, with 18 box buildings on real footprints in three rows. That leaves two streets along the strip and cross streets between buildings.
- **Fighters.** Two box fighters, each with x, altitude and depth. Buildings stop free movement: you slide along walls or land on roofs.
- **Depth is mostly automatic.**
  - An attack is a homing rush that closes the gap in all three axes.
  - A heavy launches the defender mostly along the street, keeping up to 35% of the attacker's approach angle in depth.
  - A rushing or launched fighter that is truly inside a building ploughs through it. The building takes a hit and collapses when its hits run out, with debris. The fighter slows and carries on, and the fight continues where it lands.
- **Depth modes.**
  - AUTO: attacks align depth.
  - AUTO+: also drifts you towards the opponent's depth when close.
  - MANUAL: the rush does not change depth, and a swing more than 1.5 body heights off in depth hits empty air.
- **Cameras and occlusion.**
  - Side-on, raised about 11°; or a three-quarter view at about 49°.
  - A building between the camera and a fighter either fades (dithered, so it stays in the opaque pass) or is cut down to a low stub.
- **Readability aids.** A top-down debug minimap, blob shadows, a lane line on the ground at each fighter's depth, and an altitude pole.
- **Not in it:** wounds, the director, wrap, terrain deformation, audio, determinism, a mannequin.

## What I learned
Numbers are from 600 s of AI-versus-AI bouts (`--stats 600`), with the AI changing depth lane every few seconds.

- **Depth alignment.**
  - In AUTO, the fighters were on average 14 units (7 body heights) apart in depth when an attack started. The rush closed that with no input, and no attack missed because of depth.
  - In MANUAL, the same situation is a whiff unless you steer a third axis first. I expect that to feel like work rather than play, but that is exactly what Orb should compare with T.
  - Consequence: if depth is automatic, the player mostly doesn't *use* depth. What they get is true collisions and launches that cross lanes.
- **Collisions are true, and they happen a lot.** 34 of 64 launches (53%) went through at least one building. 63 rushes smashed through a building to reach the opponent, and 49 buildings fell. Nothing bounces off anything invisible.
- **Occlusion is the main cost of real depth.**
  - A building hid a fighter from the side camera 35% of the time (26% for the three-quarter view). So occlusion handling is a core system, not an edge case.
  - *Fade* keeps the sense of where the walls are, but looks noisy when two tall buildings are in front.
  - *Cut away* gives the cleanest view of the fighters and is slightly cheaper, but buildings pop out of sight, and with them the reason for the collision.
- **Camera.**
  - Side-on keeps the fighting-game profile, but depth is nearly invisible without the aids. With shadows and lane lines on, the depth gap reads.
  - The three-quarter view makes depth and the streets obvious and occludes less. But the fighters are smaller, altitude is harder to judge, and it reads as a different genre.
- **Cost in a browser on the integrated GPU** (Chrome, WebGL2, 1920x1080, vsync off, AI bout, 20 s):

  | Camera, occlusion | avg ms | p95 ms |
  |---|---|---|
  | Side-on, fade | 3.1 | 3.9 |
  | Side-on, cut away | 2.8 | 3.4 |
  | Three-quarter, fade | 3.6 | 6.1 |
  | Side-on, fade, on the RTX | 1.6 | 2.1 |

  One-off spikes of 18 to 68 ms appeared in each run; their cause was not investigated. Rendering depth is not a performance problem at this scale: 18 buildings and up to 360 debris pieces.
- **The real cost is in the sim, not the frame.** A band means depth for everything: terrain, structures, civilians, beams, launches, the director's planners, the AI and the camera. Today only brunts carry a depth value.

## Recommendation (provisional until Orb has played it)
1. **Don't adopt full, free depth (this prototype as built) for the game.** It solves the invisible wall honestly, but it trades it for a fighter hidden a third of the time, a third axis the player doesn't want to steer, and a rewrite of the world and the director.
2. **If Orb likes the feel, take the smaller version ("B-lite"):**
   - depth is always automatic (no nudge);
   - the band is narrow, with a few lanes (street, building row, street);
   - buildings sit on true footprints, so launches and rushes hit only what is really there;
   - side-on camera, cut-away to a stub, with the shadow and lane-line aids.
3. **Compare it with Rendering's option A** (drawing the launch's depth) in the same session. A fixes the *look* for far less work. B-lite fixes the *truth*. Which matters more is a feel call for Orb.

## Hosting at /band/
Either copy the static folder `research/band-proto/build/web/`, or have Tools build it in CI:
- **`ci.yml`**, after the main export:
  - `"$GODOT" --headless --path research/band-proto --import`
  - `mkdir -p "${RUNNER_TEMP}/band" && "$GODOT" --headless --path research/band-proto --export-release "Web" "${RUNNER_TEMP}/band/index.html"`
  - pass `--band "${RUNNER_TEMP}/band"` to build-site.
- **`tools/build-site.mjs`:**
  - add `const band = opt('--band'); if (band) cpSync(resolve(band), join(outDir, 'band'), { recursive: true });`
  - optionally add the same `noindex` meta tag as `/bench/`.
- **Size.** This adds a second 39.5 MB wasm (10 MB gzipped). The engine wasm is identical to `/play/`'s, so the page could instead load `../play/index` with its own `index.pck`, as `/bench/` does.

## Files
- `main.gd`: everything (about 1,050 lines), with `main.tscn`, `project.godot` and `export_presets.cfg`.
- `shots/`: screenshots (side, three-quarter, fade, cut away, plough, and the browser runs).
- `results/`: the browser benchmark JSON.
