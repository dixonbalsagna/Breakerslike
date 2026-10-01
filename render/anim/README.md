# render/anim: the mannequin runtime (slices A1 and A2 first pass)

Owner: Animation (Rendering reviews). Plan: `docs/animation/pose-pipeline.md`; results: its sections 9.1 and 9.3 (A2: the visual facing `vface`, the hinge bake and limb pass, the contact solve, the per-part profile mix). Render only: it reads the sim (fighter state, the running exchange's beats, the per-tick events) and never writes it, draws no sim random numbers, and moves no anchor. Data is in `data/anim/`, outside the sim's data hash.

`--noanim` keeps the placeholder box figures. `--anim-style=snappy|fluid` picks a timing profile from `data/anim/profiles.json`.

| File | What it is |
| :--- | :--- |
| `anim_rig.gd` | Rig R1: 27 bones and a faceted rigid-skinned body built from a palette |
| `anim_pose.gd` | A baked pose, the sketch-to-pose bake (FK, two-bone IK), mirroring and the blend helpers |
| `anim_data.gd` | Loads and bakes `data/anim/*.json` |
| `anim_fighter.gd` | One fighter's solver: base pose, cue, approach and strike parts, beam, reactions, springs |
| `render_anim.gd` | The hub: one solver per fighter, per-tick events in, one solve a frame |
| `anim_body.gd` | The skinned figure with Rendering's baked body and outline pass (`RenderMats.fighter_body`, `OutlineBake`) |
| `spike/` | The A0 cost spike (a standalone project) |
| `tools/pose_sheet.gd` | Contact sheet of poses: cheat-out and profile, optional 38 px |
| `tools/anim_strip.gd` | Filmstrip of a real exchange (needs a window) |
| `tools/anim_reel.gd`, `tools/gif.mjs` | Raw-frame reels and a dependency-free GIF encoder (one clip or two side by side) |
| `tools/anim_check.gd` | The checks: hash off, mixed, snappy and fluid, contact-frame accuracy, the contact solve reaching the defender, no NaN, no writes to the sim |
| `tools/face_scan.gd` | Facing and pass-through scan over seeded matches (`--anim` reads the visual facing) |
| `tools/pop_scan.gd` | Join scan: bones turning more than a limit in one tick, by what was playing (the evidence for inertialisation) |
| `tools/limb_scan.gd` | Joint-limit scan (`--nolimit` turns the runtime limb pass off to show what it fixes) |

```
godot --headless --path . --script res://render/anim/tools/anim_check.gd
godot --path . --script res://render/anim/tools/pose_sheet.gd -- --out=sheet.png --prefix=strike. --cols=6 --cell=250
godot --path . --script res://render/anim/tools/anim_strip.gd -- --out=strip.png --seed=4 --nth=4 --skip=20 --step=2 --count=16
godot --path . --script res://render/anim/tools/anim_reel.gd -- --out=a.rgb --seed=4 --from=735 --count=150 --style=snappy
node render/anim/tools/gif.mjs reel.gif a.rgb [b.rgb]
```

Adding a pose: add a sketch to `data/anim/poses.json` (angles in degrees; `hand_r`, `hand_l`, `foot_r`, `foot_l` are model-space targets of the wrist and ankle; see its `_about`), check it on a pose sheet, and give any sensitive pose an `_orig` line (`docs/legal/animation-data-rule.md`). New class names need `godot --headless --path . --import` once.
