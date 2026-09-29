# Art pipeline and tooling fit: Godot 4.7 against the web stack

Owner: Research & Prototyping (engine spike, notes). Written 2026-09-29.

Tags:
- `[source: URL]` for a supporting page or file (all listed in `sources.md`);
- `[inferred]` for my own reasoning.

Quotes are 15 words or fewer.

Orb's direction (docs/ep/vision.md):
- presentation: 2.5D side-on;
- art: cel-shaded low-poly, with procedurally generated and AI-generated assets;
- planets: procedurally generated;
- a modding scene;
- keyboard and gamepad supported equally.

This file compares how well each stack fits that direction, and what changes if the presentation becomes 2D sprites or full 3D.

## Summary

| | Godot 4.7 | Web stack (three.js or raw WebGL2) |
|---|---|---|
| **2.5D side-on (recommended)** | Strong fit. glTF import, skeletal animation with retargeting, AnimationTree, particles, visual shaders, toon shading modes and SurfaceTool for procedural meshes are all built in. Web export limits it to the Compatibility renderer [inferred] | Workable. three.js covers loading, skinning, clip playback, retargeting and toon materials. State machines, VFX authoring, level tools and the editor are custom work [inferred] |
| **2D sprites** | Strong fit. The 2D renderer, Skeleton2D and Polygon2D cut-out rigs and AnimationPlayer are built in. DragonBones has an MIT GDExtension [inferred] | Strong fit for rendering (PixiJS, MIT). Rig authoring needs a third-party tool. Spine's runtime licence conflicts with an open-source repo (§3) [inferred] |
| **Full 3D** | Good in editor and on desktop (Forward+). On the web and old iGPUs, Compatibility still caps features [inferred] | Hardest option. WebGPU is not universal in 2026, so full 3D must still scale down to WebGL2, and the tooling gap is at its widest [inferred] |

Across all three presentations, the tooling burden decides the question more than rendering capability [inferred].

## 1. Asset import
- **Godot.** glTF 2.0 is the recommended format, as text `.gltf` or binary `.glb`. It also imports `.blend`, DAE, OBJ and FBX [source: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html]:
  - `.blend` import runs Blender in the background. It needs Blender 3.0 or later (3.5+ recommended) and a Blender path set in Editor Settings.
  - Every team member then needs Blender installed, and `.blend` import is unavailable in the Android and web editors.
  - FBX uses ufbx since 4.3.
- Implication [inferred]:
  - Commit `.glb` exports as the source of truth for the game, not `.blend` files.
  - Otherwise every contributor and every CI runner needs a matching Blender, and headless CI imports (`--import`) would fail without it.
  - Blender source files can live in `art/` as authoring files.
- **Web stack.** three.js loads glTF through `GLTFLoader` (an add-on in `examples/jsm`) [source: https://raw.githubusercontent.com/mrdoob/three.js/r186/examples/jsm/loaders/GLTFLoader.js]. There is no import step. Texture compression, LOD and optimisation are build scripts we would write or assemble [inferred].
- **Textures.** For cel-shaded low-poly art, flat colours, small ramp textures and vertex colours cover most needs. Texture memory is not a driver for either stack [inferred].

## 2. Animation
- **Godot.**
  - **Retargeting.** Animations can be shared between skeletons [source: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html]:
    - `SkeletonProfileHumanoid` is the humanoid preset. It drives auto-mapping of bones into a `BoneMap`.
    - The import-time "rest fixer" options (Apply Node Transform, Normalize Position Tracks, Overwrite Axis, Fix Silhouette) make skeletons conform.
    - "Normalize Position Tracks" scales position tracks by a base-bone height, so strides don't slip between differently proportioned bodies.
  - **AnimationTree** [source: https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html]:
    - Node types: BlendTree, StateMachine, BlendSpace1D and 2D, OneShot, Transition and TimeScale.
    - Root motion is supported through a root-motion track.
  - **Sim-driven playback.** `AnimationMixer`, the base of AnimationPlayer and AnimationTree, has a manual callback mode driven by `advance()` [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/AnimationMixer.xml]. The director's atoms can advance animation exactly in step with the sim tick, or scrub to a tick after a rollback [inferred].
- **Web stack (three.js).**
  - `AnimationMixer` plays clips, with `update(delta)` and `setTime(t)` [source: https://raw.githubusercontent.com/mrdoob/three.js/r186/src/animation/AnimationMixer.js].
  - `SkeletonUtils` provides `retarget` and `retargetClip` [source: https://raw.githubusercontent.com/mrdoob/three.js/r186/examples/jsm/utils/SkeletonUtils.js].
  - There is no state machine, blend-tree asset or editor. Those, and root-motion extraction, are custom [inferred].
- **For this game [inferred].** Pillar 2 ("stances, not combos") and the director's authored atoms mean animation selection lives in our director, not in an engine state machine. That narrows Godot's advantage to authoring (AnimationTree for blends and locomotion) and the editor preview loop. It does not remove it.

## 3. 2D skeletal tools and their licences
- **Spine (Esoteric Software).** The Spine Runtimes License (last updated 2025-04-05) is the same in the official repo's `LICENSE` and on the website [source: https://raw.githubusercontent.com/EsotericSoftware/spine-runtimes/4.3/LICENSE] [source: https://esotericsoftware.com/spine-runtimes-license]. What it requires:
  - Integration is allowed under Section 2 of the Spine Editor License Agreement.
  - Otherwise, integrating the runtimes is allowed only if "each user of the Products must obtain their own Spine Editor license". Redistribution must include the licence text.
  - Section 2 of the Editor licence requires a valid Spine Editor licence at the time the runtimes are integrated [source: https://esotericsoftware.com/spine-editor-license].
  - Third parties may not "modify, adapt, develop" works containing the runtimes without their own Spine Editor licence.
  - The Trial licence grants no runtime rights.
  - The Editor is paid. On 2026-09-29 the purchase page listed Essential at 69 USD (99 USD also shown) and Professional at 379 USD (449 USD also shown) [source: https://esotericsoftware.com/spine-purchase].
  - **Conclusion** [inferred]: in a public repo, every contributor who builds or modifies the game would be creating a derivative work that contains the Spine Runtimes, so each would need a paid Spine licence. That conflicts with a free, open-source project that anyone can fork and build. Legal should treat Spine as incompatible unless the runtime is kept out of the repo, which would break "fresh clone builds in one command".
- **DragonBones.**
  - The runtimes are MIT, including JS, C++ and C# [source: https://api.github.com/orgs/DragonBones/repos?per_page=50&sort=pushed].
  - Godot-DragonBones is an MIT GDExtension for Godot 4.2+ [source: https://raw.githubusercontent.com/DragonBones/Godot-DragonBones/master/README.md] [source: https://api.github.com/repos/DragonBones/Godot-DragonBones]. As a GDExtension, its web build needs "Extensions Support" and cross-origin isolation headers (see `godot.md` §1.7) [inferred].
  - The DragonBones runtime README now recommends the LoongBones editor [source: https://raw.githubusercontent.com/DragonBones/DragonBonesJS/master/README.md]. I did not verify LoongBones' licence or price.
- **Godot built in.** Skeleton2D, Bone2D and Polygon2D with weight painting give cut-out skeletal animation [source: https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html]. This is engine code (MIT) with no third-party licence. The 4.7 docs flag that page as not yet updated for 4.7 [source: https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html].
- **Web stack.** The DragonBones JS runtime (MIT) supports PixiJS and Phaser [source: https://raw.githubusercontent.com/DragonBones/DragonBonesJS/master/README.md]. Otherwise a custom cut-out rig format is needed [inferred].

## 4. VFX tooling
- **Godot.**
  - **Particles.** GPUParticles3D can render hundreds of thousands of particles. CPUParticles3D is the fallback. There are collision shapes, attractors and sub-emitters [source: https://docs.godotengine.org/en/stable/tutorials/3d/particles/index.html]. The Compatibility renderer lacks particle trails and particle SDF collision [source: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html].
  - **Visual shader editor.** Graph-based, with previews. The graph compiles to a text shader that can be inspected [source: https://docs.godotengine.org/en/stable/tutorials/shaders/visual_shaders.html].
- **Web stack.** three.js has no particle system editor and no visual shader editor. The spike's web build writes its own particle system and shaders [inferred]. A custom VFX authoring loop (edit parameters, see the result live) is extra tooling to build [inferred].
- **Spike note.** SPEC.md fixes the particle counts (about 24k live) so both stacks draw the same load. The frame-time comparison is in the benchmark results, not here.

## 5. Cel-shaded low-poly with procedurally generated assets
- **Runtime mesh generation.**
  - Godot has `SurfaceTool`, which builds a mesh vertex by vertex from script, and `ArrayMesh`, which builds a surface from arrays [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/SurfaceTool.xml] [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/ArrayMesh.xml].
  - three.js has `BufferGeometry` [source: https://raw.githubusercontent.com/mrdoob/three.js/r186/src/core/BufferGeometry.js].
  - Raw WebGL2 uses our own vertex buffers, as the spike's terrain does.
  - Procedural planets (heightfield, biomes, structure placement) are our own sim and world code in either stack. Neither engine gives them for free [inferred].
- **Toon shading.**
  - Godot's `BaseMaterial3D` has a toon diffuse mode ("hard cut" lighting) and a toon specular mode [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/BaseMaterial3D.xml].
  - Custom ramp shaders are easy in both stacks [inferred].
  - three.js has `MeshToonMaterial` [source: https://raw.githubusercontent.com/mrdoob/three.js/r186/src/materials/MeshToonMaterial.js].
- **Outlines.**
  - Godot's `grow` property with a second, front-culled material pass gives inverted-hull outlines. The docs warn of gaps at sharp corners unless normals are smooth [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/BaseMaterial3D.xml].
  - Godot also has a stencil outline preset (`STENCIL_MODE_OUTLINE`), marked experimental [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/BaseMaterial3D.xml]. I did not check whether it works in the Compatibility renderer.
  - three.js offers `OutlineEffect` (inverted hull) and `OutlinePass` (post-process) [source: https://raw.githubusercontent.com/mrdoob/three.js/r186/examples/jsm/effects/OutlineEffect.js] [source: https://raw.githubusercontent.com/mrdoob/three.js/r186/examples/jsm/postprocessing/OutlinePass.js].
  - Inverted-hull outlines cost one extra draw per object and suit old iGPUs better than full-screen edge detection [inferred].
- **AI-generated assets [inferred].**
  - Both stacks take the same glTF and PNG files, so the engine choice does not affect this.
  - What matters is provenance: each asset's tool, terms and prompt must be recorded for the originality rules and Legal review.
  - Generated meshes usually need retopology and rigging before they suit low-poly cel shading. Godot's retargeting helps with rigging (§2).
- **Deformable terrain on screen.**
  - The spike renders deformation with a 1200-texel height texture and a static grid, which works in both stacks.
  - In Godot this is a `.gdshader` with `texelFetch`. On the web it is GLSL ES 3.0 [inferred].

## 6. How much custom tooling each option needs [inferred]
| Tool | Godot 4.7 | Web stack |
|---|---|---|
| Scene and level editor | Built in (Godot editor, text `.tscn`) | Build or adopt (Babylon editor, PlayCanvas hosted editor, or custom) |
| Animation blending and state machines | Built in (AnimationTree) | Custom |
| Retargeting | Built in (SkeletonProfileHumanoid, BoneMap) | three.js SkeletonUtils (code only, no UI) |
| Particles and VFX authoring | Built in (GPUParticles3D, visual shaders) | Custom |
| Asset import and optimisation | Built in (import docks, reimport on change) | Custom build scripts |
| Profiler and debugger | Built in (editor debugger, remote debug, LSP/DAP) | Browser devtools, plus custom sim overlays |
| Test runner and headless CI | `--headless -s`, GUT or gdUnit4 | Node (the spike's sim runs in Node with no browser) |
| Exports (desktop, mobile, web) | Built in (templates) | Wrappers per platform (Electron or NW.js, Capacitor, PWA) |
| Mod loading | `load_resource_pack` plus our own validation | Custom loader and sandbox |
| Debug feed and replay viewer (pillar 6, "explainable director") | Custom in both | Custom in both |

The web stack's advantages:
- One language (TypeScript) for sim, tools and game.
- Instant reload.
- The sim already runs headless in Node, which QA's tools use today (`qa/`, `prototype/tools/sim-stats.js`).

Godot can keep that advantage for the sim if the sim stays a plain, engine-agnostic JS module used by tools. But then the Godot build needs either a GDScript port kept in lock-step (as the spike did) or a JS runtime inside Godot. That is a real architectural cost to raise under ADR 0001 [inferred].

## 7. What changes if Orb picks 2D sprites or full 3D [inferred]
- **2D sprites.**
  - Rendering load drops on both stacks. Old iGPUs and the web are easy targets.
  - The web stack gets its best case: PixiJS (MIT) is a mature 2D renderer, and 2D tooling needs are smaller (sprite sheets, cut-out rigs, tilemaps).
  - Godot remains strong: its 2D engine is a first-class, separate renderer, and Skeleton2D is built in.
  - The risk is rig tooling. Spine is excluded by licence, so DragonBones (MIT runtimes, editor licence unverified), Godot's built-in 2D skeletons or frame-by-frame sprites would be used.
  - Procedural or AI-generated sprites are harder to keep consistent across frames than procedural low-poly meshes, which is an art-direction cost.
  - Net effect: the gap between the stacks narrows, and the web stack becomes more competitive.
- **Full 3D.**
  - The camera, readability and collateral-damage visuals all get more expensive.
  - Godot's desktop Forward+ renderer shines, but web and old-iGPU builds still run Compatibility (WebGL 2.0), so two quality tiers must be designed and tested.
  - The web stack is limited to WebGL2 in 2026 for broad reach, because WebGPU is missing on Firefox for Linux and Android and on most Linux Chromium. The tooling gap (animation, VFX, level editing) is widest here.
  - Net effect: this strongly favours Godot, but full 3D and "browser plus old laptops" pull against each other in either engine.
- **2.5D side-on (current recommendation).**
  - This is the sweet spot for the minimum spec: 3D models on a gameplay plane, one render path (Compatibility or WebGL2) that runs everywhere, and full use of Godot's 3D tooling.
  - The web stack can do it too, at the cost of the custom tooling listed in §6.

## 8. Not verified (gaps)
- LoongBones (DragonBones editor successor) licence and price.
- Whether Godot's experimental stencil outline preset works in the Compatibility renderer and on the web.
- The Babylon.js built-in editors (Node Material Editor, particle editors): not checked, so not claimed.
- Spine prices are as displayed on 2026-09-29. The page showed two prices per tier, so which one is current is my reading.
