# Sources for godot.md, web.md and pipeline.md

Every URL cited in the three notes files is listed here, with what it supports. All were accessed on **2026-09-29** (the machine's clock during the fetches; the brief gave 2026-09-28 as "today").

How each source was read:
- **WebFetch**: the page was fetched and summarised with a question.
- **curl**: the raw file or API response was downloaded, then grepped or parsed.
- **HEAD**: the file's existence was checked with an HTTP 200.

For the most decision-relevant claims I read the exact wording twice: Godot web export, float and Vector width, the Spine licence, WebGPU status, and ECMAScript Math.

`docs.godotengine.org/en/stable/` pages showed the header "Godot Engine 4.7 documentation" when fetched. Raw engine files are pinned to the `4.7.2-stable` tag.

Section references: G = godot.md, W = web.md, P = pipeline.md.

## Godot: official documentation (docs.godotengine.org, 4.7)
| URL | How | Supports |
|---|---|---|
| https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html | WebFetch ×4 | G summary and §2 (Compatibility/WebGL 2.0 only; no WebGPU; no-threads default since 4.3; slower than threads; works well on macOS/iOS; COOP/COEP only for threads or extensions; header values; PWA isolation option; audio: Sample playback by default, low latency even without threads, but no AudioEffects, reverb, doppler or procedural audio; Stream playback has higher latency, especially without threads; low-latency Stream playback is a reason for threads; audio/fullscreen need user input; gamepad needs a button press; size "about a quarter" with gzip; Safari WebGL2 issues; native mobile faster; C# cannot export to web); G §1.7 (Extensions Support needs web builds and isolation headers); W §4, §7 |
| https://docs.godotengine.org/en/stable/classes/class_float.html | WebFetch | G §1.1 (float is 64-bit double; vectors 32-bit by default; precision=double) |
| https://docs.godotengine.org/en/stable/classes/class_vector2.html | WebFetch | G §1.1 (Vector2 32-bit by default, "unlike float which is always 64-bit") |
| https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html | WebFetch | G §1.1 (double needs editor and templates built with precision=double; extensions rebuilt; shaders stay 32-bit) |
| https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html | WebFetch ×2 | G §1.2 (PCG32; algorithm is an implementation detail; seed and state; randfn uses Box-Muller) |
| https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html | WebFetch | G §1.4 (Jolt is the default for new projects; page silent on determinism) |
| https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html | WebFetch | G §1.5 (_physics_process at a fixed rate, 60/s by default) |
| https://docs.godotengine.org/en/stable/classes/class_engine.html | WebFetch | G §1.5 (max_physics_steps_per_frame 8; time_scale does not change the tick rate) |
| https://docs.godotengine.org/en/stable/tutorials/scripting/cpp/about_godot_cpp.html | WebFetch | G §1.7 (godot-cpp official; forward compatibility across minor versions) |
| https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html | WebFetch ×2 | G §3 (Developer ID needed to notarise; Gatekeeper blocks unsigned downloads; rcodesign from Windows/Linux; ad-hoc option) |
| https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_linux.html | WebFetch | G §3 (x86_64 default, arm64) |
| https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html | WebFetch | G §5 (macOS with Xcode required; Team ID; C# on iOS experimental since 4.2) |
| https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html | WebFetch | G §5 (OpenJDK 17, SDK/Build-Tools/Platform 35, CMake, NDK r28b; AAB via Gradle; release keystore) |
| https://docs.godotengine.org/en/stable/about/system_requirements.html | WebFetch + curl parse | G summary, §2.3, §5, §6 (GPU minimums per renderer; example GPUs; Android 7/9; iOS 12/16; exported-project browser lists: recommended latest Firefox, Chrome, Edge, Safari, Opera, plus Samsung Internet on mobile; minimum rows labelled "Web editor"); W §1.1 |
| https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html | WebFetch | G §6 (Compatibility recommended for old devices; missing features; Vulkan/D3D12 fallback); P §4 |
| https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html | WebFetch ×2 | G summary, §6 (`--gpu-index` "only available on the Forward+/Mobile renderers"), §8 (headless, import, export flags; templates needed) |
| https://docs.godotengine.org/en/stable/tutorials/editor/external_editor.html | WebFetch | G §8 (LSP needs a running instance; ports 6005/6006; official VS Code plugin) |
| https://docs.godotengine.org/en/stable/engine_details/file_formats/tscn.html | WebFetch | G §8 (TSCN VCS-friendly; uid://; load_steps deprecated since 4.6; defaults and whitespace dropped on save) |
| https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html | WebFetch | G §9 (load_resource_pack; replace flag; security warning; signing suggestion) |
| https://docs.godotengine.org/en/stable/tutorials/io/runtime_file_loading_and_saving.html | WebFetch | G §9 (runtime loaders for user content: images, glTF, audio, fonts, ZIP) |
| https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html | WebFetch | G §10 (SDL 3 since 4.5 on desktop; custom code on Android/web; web support varies; vibration); W §8 |
| https://docs.godotengine.org/en/4.5/tutorials/platform/consoles.html | WebFetch | G §7 (reasons: liability, cost, licensing; per-vendor console list; Pineapple Works GDScript/C#) |
| https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html | WebFetch | P §1 (glTF recommended; .blend needs Blender 3.0+ on every machine; not in Android/web editors; ufbx) |
| https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html | WebFetch | P §2 (SkeletonProfileHumanoid, BoneMap, rest fixer, Normalize Position Tracks) |
| https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html | WebFetch | P §2 (AnimationTree node types; root motion) |
| https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html | WebFetch | P §3 (Skeleton2D, Bone2D, Polygon2D weights; page flagged not updated for 4.7) |
| https://docs.godotengine.org/en/stable/tutorials/3d/particles/index.html | WebFetch | P §4 (GPU vs CPU particles; collision, attractors, sub-emitters) |
| https://docs.godotengine.org/en/stable/tutorials/shaders/visual_shaders.html | WebFetch | P §4 (visual shader editor; converts to text shader) |

## Godot: engine repository (tag 4.7.2-stable) and releases
| URL | How | Supports |
|---|---|---|
| https://api.github.com/repos/godotengine/godot/releases/tags/4.7.2-stable | curl | G header (4.7.2 published 2026-08-18, maintenance release) |
| https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/core/math/math_funcs.h | WebFetch + curl grep | G §1.3 (Math::sin/cos/pow/exp/sqrt call std:: functions) |
| https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/core/math/random_pcg.h | curl | G §1.2 (randf/randd use CLZ32 + ldexp, with a different fallback without the intrinsic) |
| https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/int.xml | curl | G §1.1 (int is signed 64-bit and wraps) |
| https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/ProjectSettings.xml | curl grep | G §1.5 (physics_ticks_per_second 60; physics_jitter_fix 0.5, ≤ 0 recommended for network games), G §6 (fallback_to_angle, force_angle_on_devices, fallback_to_opengl3) |
| https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/AnimationMixer.xml | curl grep | G §1.5, P §2 (manual callback mode, advance()) |
| https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/FileAccess.xml | curl grep | G §9 (get_var allow_objects warning about executed code) |
| https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/BaseMaterial3D.xml | curl grep | G §12, P §5 (DIFFUSE_TOON, SPECULAR_TOON, grow outline note, experimental STENCIL_MODE_OUTLINE) |
| https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/SurfaceTool.xml | curl | P §5 (SurfaceTool builds meshes from script) |
| https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/ArrayMesh.xml | curl | P §5 (ArrayMesh builds surfaces from arrays) |
| https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/windows/os_windows.cpp | curl grep | G summary, §6 (lines 101 and 102 export NvOptimusEnablement = 1 and AmdPowerXpressRequestHighPerformance = 1) |
| https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/.github/workflows/web_builds.yml | curl grep | Consulted: the CI web build uses EM_VERSION 4.0.11. Not cited, because official release templates come from the build containers below |
| https://github.com/godotengine/godot/issues/112976 | WebFetch | G §1.4 (2D physics nondeterminism report; closed; resolution not checked) |

## Godot: official site and ecosystem
| URL | How | Supports |
|---|---|---|
| https://godotengine.org/consoles/ | WebFetch | G summary, §7 (no console support in the MIT engine; NDAs; developer registration; W4 Games middleware; porting houses) |
| https://github.com/godot-jolt/godot-jolt | WebFetch | G §1.4 (the Jolt integration cannot guarantee determinism; MIT; maintenance mode) |
| https://github.com/appsinacup/godot-rapier-physics | WebFetch | G §1.4 (claims cross-platform determinism; enhanced-determinism; web builds; MIT; 4.7) |
| https://gitlab.com/snopek-games/godot-rollback-netcode/-/raw/main/README.md | curl | G §1.6 (rollback and prediction features; C# companion) |
| https://gitlab.com/snopek-games/godot-rollback-netcode/-/raw/main/LICENSE.txt | curl | G §1.6 (MIT) |
| https://gitlab.com/snopek-games/godot-rollback-netcode/-/raw/main/project.godot | curl | G §1.6 (config/features "4.6") |
| https://gitlab.com/api/v4/projects/snopek-games%2Fgodot-rollback-netcode/releases/v1.0.0 | curl | G §1.6 (v1.0.0, 2026-06-06) |
| https://api.github.com/repos/Fractural/GodotRollbackNetcodeMono | curl | G §1.6 (C# wrapper, MIT) |
| https://api.github.com/repos/foxssake/netfox | curl | G §1.6 (MIT; last push 2026-09-26; latest release v1.35.3 via /releases/latest) |
| https://raw.githubusercontent.com/foxssake/netfox/main/README.md | curl | G §1.6 (client-side prediction, server reconciliation, rollback; Godot 4.x) |
| https://api.github.com/repos/godotengine/godot-cpp | curl | G §1.7 (MIT) |
| https://api.github.com/repos/godot-rust/gdext | curl | G §1.7 (MPL-2.0) |
| https://godot-rust.github.io/book/toolchain/export-web.html | WebFetch ×2 | G §1.7 (web experimental; nightly Rust; "We recommend version 3.1.74" of Emscripten for Godot 4.3+; Extensions Support; threads or nothreads feature) |
| https://raw.githubusercontent.com/godotengine/build-containers/4.7/Dockerfile.web | curl grep | G §1.7 (official 4.7 build container pins EMSCRIPTEN_VERSION=4.0.20) |
| https://api.github.com/repos/godotengine/build-containers/commits?sha=4.7&path=Dockerfile.web&per_page=3 | curl | G §1.7 (commit "Update various toolchains for 4.6": Emscripten 4.0.20, MinGW with GCC 15.2.1; dated 2025-11-22) |
| https://raw.githubusercontent.com/godotengine/build-containers/4.7/Dockerfile.windows | curl grep | G §1.3 (official Windows builds use MinGW toolchains: mingw64-gcc and llvm-mingw) |
| https://codeberg.org/godotsteam/godotsteam/raw/branch/godot4/license.md | curl | G §3 (GodotSteam MIT) |
| https://codeberg.org/godotsteam/godotsteam/raw/branch/godot4/readme.md | curl | G §3 (Steamworks SDK version table) |
| https://raw.githubusercontent.com/GodotSteam/GodotSteam/master/readme.md | curl | G §3 (repository moved to Codeberg; GitHub repo archived per API) |
| https://api.github.com/repos/godotengine/godot-vscode-plugin | curl | G §8 (VS Code plugin MIT) |
| https://raw.githubusercontent.com/bitwes/Gut/main/README.md | curl | G §8 (GUT 9.x for Godot 4; CLI) |
| https://raw.githubusercontent.com/bitwes/Gut/main/addons/gut/LICENSE.md | curl | G §8 (GUT MIT) |
| https://api.github.com/repos/bitwes/Gut/releases/latest | curl | G §8 (v9.6.1, 2026-07-09) |
| https://api.github.com/repos/MikeSchulze/gdUnit4 | curl -L | G §8 (redirects to godot-gdunit-labs/gdUnit4; MIT) |
| https://raw.githubusercontent.com/godot-gdunit-labs/gdUnit4/master/README.md | curl | G §8 (GDScript and C# tests; CLI; JUnit XML; GitHub Action) |
| https://api.github.com/repos/godot-gdunit-labs/gdUnit4/releases/latest | curl | G §8 (v6.2.1, 2026-08-20) |
| https://api.github.com/repos/GodotModding/godot-mod-loader | curl | G §9 (CC0-1.0) |

## Platforms, stores and distribution
| URL | How | Supports |
|---|---|---|
| https://developer.apple.com/programs/whats-included/ | WebFetch | G §3, §5; W §4 (Apple Developer Program 99 USD per year) |
| https://support.google.com/googleplay/android-developer/answer/6112435 | WebFetch | G §5; W §4 (Play registration 25 USD once; testing requirement for new personal accounts) |
| https://partner.steamgames.com/doc/gettingstarted/appfee | WebFetch | G §3; W §3 (Steam Direct 100 USD, recoupable after 1,000 USD) |
| https://partner.steamgames.com/doc/steamdeck/compat | WebFetch | G §4; W §3 (Deck criteria; Linux build tested if available; 1280x800) |
| https://partner.steamgames.com/doc/steamdeck/proton | WebFetch | G §4 (Proton caveats: .NET/WPF, Media Foundation, kernel anti-cheat) |
| https://itch.io/docs/creators/html5 | WebFetch | G §11; W §12 (1,000 files, 500 MB, 200 MB per file; gzip and brotli handling) |
| https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases | WebFetch | G §11; W §12 (release files under 2 GiB; no total or bandwidth limit) |
| https://learn.microsoft.com/en-us/windows/uwp/xbox-apps/frequently-asked-questions | WebFetch | W summary, §5 (UWP games no longer accepted in the Xbox Store; use ID@Xbox) |
| https://learn.microsoft.com/en-us/windows/uwp/xbox-apps/development-lanes-html | WebFetch | W §5 (archived: HTML5 games on Xbox One via UWP and Edge) |
| https://mp2.dk/chowdren/ | WebFetch | W §5 (Chowdren: C++ runtime offered as a porting service for Construct and Clickteam Fusion games; Switch, PS5, PS4, Xbox Series X/S, Xbox One) |

## Web platform standards and browsers
| URL | How | Supports |
|---|---|---|
| https://tc39.es/ecma262/multipage/numbers-and-dates.html | curl + parse | W summary, §6.1 (§21.3.2 note: Math functions not precisely specified, fdlibm recommended; Math.sin "implementation-approximated"; Math.sqrt exact; Math.imul exact; Math.random implementation-defined) |
| https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html | curl + parse | W §6.1 (Number::exponentiate is implementation-approximated) |
| https://262.ecma-international.org/16.0/ | curl + parse | W §6.1 (published ES2025 edition, §21.3.2.31 Math.sin has the same wording) |
| https://webassembly.github.io/spec/core/exec/numerics.html | curl + parse | W §6.2 (NaN sign and payload non-deterministic; relaxed operators implementation-dependent) |
| https://webassembly.github.io/spec/core/appendix/profiles.html | curl + parse | W §6.2 (deterministic profile: canonical NaNs, fixed relaxed behaviour) |
| https://developer.mozilla.org/en-US/docs/Web/API/Performance/now | WebFetch | W §7 (5 µs isolated, 100 µs otherwise) |
| https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/SharedArrayBuffer | WebFetch ×2 | W §7 (shared memory needs a secure context and cross-origin isolation; crossOriginIsolated; ArrayBuffer is transferable, SharedArrayBuffer is not) |
| https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers | WebFetch | W §7 (worker messages are copied, not shared; transferable objects; no isolation requirement for dedicated workers mentioned) |
| https://developer.mozilla.org/en-US/docs/Web/API/AudioWorklet | WebFetch | W §7 (secure context only; no isolation requirement mentioned) |
| https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame | WebFetch | W §7 (rAF generally matches refresh rate; paused in background tabs) |
| https://developer.mozilla.org/en-US/docs/Web/API/Gamepad_API | WebFetch | W §8 (Baseline widely available; haptics listed as experimental extension) |
| https://www.w3.org/TR/gamepad/ | WebFetch | W §8 (Working Draft 2025-07-10; empty list before a gamepad user gesture; standard mapping; haptics) |
| https://caniuse.com/webgl2 | WebFetch | W summary, §1.1, §4 (96.44%; Chrome 56, Edge 79, Firefox 51, Safari/iOS 15) |
| https://github.com/gpuweb/gpuweb/wiki/Implementation-Status | WebFetch | W summary, §1.2, §3, §4 (WebGPU per browser and OS; page updated 2026-08-13) |
| https://developer.chrome.com/blog/webgpu-release | WebFetch | W §1.2 (Chrome 113 default on ChromeOS, macOS, Windows) |
| https://www.firefox.com/en-US/firefox/141.0/releasenotes/ | WebFetch ×2 (after a redirect from mozilla.org) | W §1.2 (Firefox 141 enabled WebGPU on Windows; the quote elides the spec and MDN links) |
| https://webkit.org/blog/17333/webkit-features-in-safari-26-0/ | WebFetch | W §1.2, §4 (Safari 26.0 ships WebGPU on macOS, iOS, iPadOS, visionOS) |
| https://raw.githubusercontent.com/google/angle/main/README.md | curl | W §1.1 (ANGLE translates GL ES to D3D11, Vulkan, GL and Metal; platform table) |

## Web stack: libraries, wrappers and tools
| URL | How | Supports |
|---|---|---|
| https://registry.npmjs.org/three/latest | curl | W §2 (three 0.186.1, MIT) |
| https://api.github.com/repos/mrdoob/three.js | curl | W §2 (MIT; latest release r186 via /releases/latest) |
| https://raw.githubusercontent.com/mrdoob/three.js/r186/src/renderers/webgpu/WebGPURenderer.js | curl grep | W §1.2 (falls back to a WebGL 2 backend) |
| https://raw.githubusercontent.com/mrdoob/three.js/r186/src/animation/AnimationMixer.js | HEAD + curl grep | W §2, §9; P §2 (update(deltaTime), setTime) |
| https://raw.githubusercontent.com/mrdoob/three.js/r186/examples/jsm/utils/SkeletonUtils.js | curl grep | W §9; P §2 (retarget, retargetClip) |
| https://raw.githubusercontent.com/mrdoob/three.js/r186/examples/jsm/loaders/GLTFLoader.js | HEAD | P §1 (GLTFLoader exists in r186) |
| https://raw.githubusercontent.com/mrdoob/three.js/r186/src/core/BufferGeometry.js | HEAD | W §11; P §5 |
| https://raw.githubusercontent.com/mrdoob/three.js/r186/src/materials/MeshToonMaterial.js | HEAD | W §11; P §5 |
| https://raw.githubusercontent.com/mrdoob/three.js/r186/examples/jsm/effects/OutlineEffect.js | HEAD | W §11; P §5 |
| https://raw.githubusercontent.com/mrdoob/three.js/r186/examples/jsm/postprocessing/OutlinePass.js | HEAD | W §11; P §5 |
| https://registry.npmjs.org/@babylonjs/core/latest | curl | W §2 (9.28.0, Apache-2.0) |
| https://api.github.com/repos/BabylonJS/Babylon.js | curl | W §2 (Apache-2.0) |
| https://api.github.com/repos/BabylonJS/Editor | curl | W §2, §9 (community-managed editor, Apache-2.0) |
| https://raw.githubusercontent.com/BabylonJS/BabylonNative/master/README.md | curl grep | W §5 (Babylon Native platforms; no consoles listed) |
| https://registry.npmjs.org/pixi.js/latest | curl | W §2 (8.21.0, MIT) |
| https://api.github.com/repos/pixijs/pixijs | curl | W §2 (MIT) |
| https://registry.npmjs.org/playcanvas/latest | curl | W §2 (2.22.6, MIT) |
| https://api.github.com/repos/playcanvas/engine | curl | W §2 (MIT) |
| https://raw.githubusercontent.com/playcanvas/editor/main/README.md | curl | W §2, §9 (editor front end on GitHub, used at playcanvas.com; repo MIT per API) |
| https://www.electronjs.org/docs/latest/ | WebFetch | W §3 (embeds Chromium and Node.js; Windows, macOS, Linux) |
| https://registry.npmjs.org/electron/latest | curl | W §3 (44.4.5, MIT) |
| https://v2.tauri.app/reference/webview-versions/ | WebFetch | W §3, §4 (system webviews per OS; update and version caveats) |
| https://registry.npmjs.org/@tauri-apps/cli/latest | curl | W §3 (2.12.0, "Apache-2.0 OR MIT") |
| https://api.github.com/repos/tauri-apps/tauri/contents | curl | W §3 (LICENSE-MIT and LICENSE-APACHE-2.0 in the repo root) |
| https://registry.npmjs.org/nw/latest | curl | W §3 (0.117.0, MIT) |
| https://api.github.com/repos/nwjs/nw.js | curl | W §3 (MIT) |
| https://registry.npmjs.org/steamworks.js/latest | curl | W §3 (0.4.0, MIT) |
| https://api.github.com/repos/ceifa/steamworks.js | curl | W §3 (community repo, MIT) |
| https://raw.githubusercontent.com/ceifa/steamworks.js/main/README.md | curl grep | W §3 (electronEnableSteamOverlay for the overlay) |
| https://capacitorjs.com/docs | WebFetch | W §4 (native runtime for web apps on iOS and Android) |
| https://registry.npmjs.org/@capacitor/core/latest | curl | W §4 (8.5.2, MIT) |

## 2D skeletal tools (licences)
| URL | How | Supports |
|---|---|---|
| https://raw.githubusercontent.com/EsotericSoftware/spine-runtimes/4.3/LICENSE | curl (the 4.2 branch is identical) | P §3 (Spine Runtimes License, updated 2025-04-05: an Editor licence is needed per user; the notice must be included) |
| https://esotericsoftware.com/spine-runtimes-license | curl + parse | P §3 (same text as the repo LICENSE) |
| https://esotericsoftware.com/spine-editor-license | curl + parse | P §3 (Section 2.1 to 2.4: integration and derivative works need a valid Editor licence; third parties need their own; the Trial licence grants no runtime rights) |
| https://esotericsoftware.com/spine-purchase | curl + parse | P §3 (prices shown on 2026-09-29) |
| https://api.github.com/orgs/DragonBones/repos?per_page=50&sort=pushed | curl | P §3 (DragonBones JS/C++/C# runtimes MIT; activity dates) |
| https://raw.githubusercontent.com/DragonBones/DragonBonesJS/master/README.md | curl | P §3 (supported engines, including PixiJS; recommends LoongBones) |
| https://raw.githubusercontent.com/DragonBones/Godot-DragonBones/master/README.md | curl | P §3 (GDExtension; Godot 4.2+) |
| https://api.github.com/repos/DragonBones/Godot-DragonBones | curl | P §3 (repo description: GDExtension for Godot 4.x; MIT per the org listing) |

## Consulted but not cited as support
| URL | Why |
|---|---|
| https://docs.godotengine.org/en/stable/tutorials/platform/consoles.html | Returned 404 on 2026-09-29, so the 4.5 page and godotengine.org/consoles were used instead |
| https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html | Checked for a security warning about untrusted resources. None found there, so FileAccess.xml was used |
| https://docs.godotengine.org/en/stable/classes/class_projectsettings.html | The WebFetch excerpt was truncated, so ProjectSettings.xml at 4.7.2-stable was used |
| https://developer.apple.com/support/compare-memberships/ | Did not state the fee, so the "What's included" page was used |
| https://www.mozilla.org/en-US/firefox/141.0/releasenotes/ | Redirected to firefox.com (cited above) |
| WebSearch results about Construct 3 console exports (construct.net forum, chadorivirtual.com, ratalaikagames.com) | Secondary sources only. Used just to flag "porting houses for HTML5 games" as unverified in W §5 |
| WebSearch results about Godot physics determinism (godot-jolt discussions #548 and #557, forum threads) | Secondary. Only the godot-jolt README and issue #112976 are cited |

## Local sources (in this repo or on this machine)
| Source | Supports |
|---|---|
| `research/engine-spike/shared/sim-ref.mjs` (header, portability contract) | G §1.1, §1.3; W §6.1 |
| `research/engine-spike/shared/test-ref.mjs --bench` output | G "Local measurements" M4 |
| `research/engine-spike/godot/sim/rng.gd` | G §1.1 (imul from 16-bit halves with 32-bit masks) |
| `%APPDATA%\Godot\export_templates\4.7.2.stable\` (official templates, SHA-512 verified per PLAN.md) | G M1 (template and wasm sizes, gzip and brotli sizes) |
| Minimal headless web export and a precision probe in the session scratchpad (not in the repo) | G M2, M3 |
| `grep -a` on the installed 4.7.2 Windows release template, editor and console executables | G M5, §1.3, §6 (MinGW-w64 GCC strings; NvOptimusEnablement and AmdPowerXpressRequestHighPerformance symbols) |
| `docs/ep/vision.md` | P header (Orb's criteria) |
| `research/engine-spike/notes/csharp.md` (the C# agent) | Linked for C# web export. Not re-verified here |

## Added by the Research director for RESULT.md (accessed 2026-09-29)
- https://www.cpubenchmark.net/cpu.php?cpu=AMD+Ryzen+7+9800X3D&id=6344: PassMark Single Thread Rating 4,420 for the spike machine's CPU.
- https://www.cpubenchmark.net/cpu.php?cpu=Intel+Core+i5-7200U+%40+2.50GHz: 1,728, a 2016 laptop CPU.
- https://www.cpubenchmark.net/cpu.php?cpu=Intel+Core+i3-5005U+%40+2.00GHz: 1,128, a 2015 laptop CPU.
- Together these give the 2.6x to 3.9x old-laptop CPU factor used to project the GDScript tick cost. PassMark's single-thread score is not an interpreter benchmark, so the factor is only indicative.
- https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_mono_export_templates.tpz: listed locally. It contains no web template (see csharp.md, addendum).
