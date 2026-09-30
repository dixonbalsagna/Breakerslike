# Animation A0 spike

Owner: Animation. A standalone Godot project (it has its own `project.godot`, so the game's project ignores this folder and the game's export never includes it). It measures what `docs/animation/pose-pipeline.md` §2.3 and §7 ask about: skinning cost, draw calls, the animation layer stack on the CPU, and the hands (palm plus finger slab). It never touches the sim, the game scenes or the gameplay hash. Results and the decisions they support are in `docs/animation/pose-pipeline.md` §7.8.

| File | What it is |
| :--- | :--- |
| `rig.gd` | 27 bones (R1 core of 22 plus 5 extras) and a faceted body of about 2,700 triangles, built as one rigid-skinned mesh, one static mesh, a puppet of per-bone meshes, or with separate hand meshes |
| `solve.gd` | A representative layer stack (key blend, inertia, modifiers, FK, closed-form two-bone IK on four limbs, spring chains, an impact wave, a joint clamp) and the write to the rig. Layers are bits of a mask, so each can be timed alone |
| `spike.gd` | The harness: panes (each a SubViewport with its own World3D, like the split screen), fighters, the frame loop, statistics, the microbenchmark, `--shot` |
| `export_presets.cfg` | A Web preset (single-threaded) and a Windows preset; exports go to `build/`, which git ignores |

## Run

```
godot --path render/anim/spike -- --rig=skinned --hull=1 --solve=0 --fighters=2 --panes=2 --frames=900
godot --path render/anim/spike --fixed-fps 60 -- --rig=skinned --hull=1 --solve=none --fistmix=1 --px=650 --shot=hands.png
```

Options are in the header of `spike.gd` (on the web they are query parameters: `index.html?rig=skinned&panes=2&solve=0`). Desktop writes `--out=file.json`; the web build sets `window.__benchResult`, which `research/engine-spike/tools/bench-browser.mjs` reads. The web results were taken with a copy of that driver that adds Chrome's CPU throttle (`Emulation.setCPUThrottlingRate`), to stand in for an old laptop's CPU.

Export: `godot --headless --path render/anim/spike --export-release "Web" build/web/index.html`.
