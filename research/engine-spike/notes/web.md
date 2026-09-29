# Web stack (TypeScript plus WebGL2 or WebGPU): evidence notes for ADR 0001

Owner: Research & Prototyping (engine spike, notes). Written 2026-09-29. "Web stack" means the game written in TypeScript and run in a browser, with an optional renderer library and an optional desktop or mobile wrapper. The spike's own web build (`web/`) uses raw WebGL2 with no dependencies.

Tags are the same as in `godot.md`:
- `[source: URL]` for a page or file that supports the claim (listed in `sources.md`);
- `[source: local ...]` for a local measurement;
- `[inferred]` for my own reasoning.

Quotes are 15 words or fewer.

## Summary for the decision

1. **WebGL2 is the universal baseline.** caniuse puts support at 96.44% of tracked browser usage [source: https://caniuse.com/webgl2].
2. **WebGPU is not universal in 2026.** Chrome, Edge and Safari 26 ship it. Firefox ships it on Windows and Apple-silicon Macs. Linux and Android coverage is partial [source: https://github.com/gpuweb/gpuweb/wiki/Implementation-Status]. A min-spec web game must still render with WebGL2 [inferred].
3. **The web stack has no console path.** Microsoft's historical HTML5 route on Xbox (UWP) is closed to new games [source: https://learn.microsoft.com/en-us/windows/uwp/xbox-apps/frequently-asked-questions]. Every console release would mean porting the game to a native runtime [inferred].
4. **Determinism in JS needs discipline.** The ECMAScript spec leaves `Math.sin`, `cos`, `exp`, `pow` and the other transcendental functions "implementation-approximated" [source: https://tc39.es/ecma262/multipage/numbers-and-dates.html]. The spike's portability contract (+ - * / sqrt floor, `Math.imul`) avoids them.
5. **Tooling is the web stack's main cost.** The libraries are rendering engines. The editor, animation state machines, VFX authoring and level tools have to be built or assembled (section 9) [inferred].

## 1. Graphics API availability

### 1.1 WebGL2
- caniuse lists WebGL 2.0 at 96.44% global usage. It is supported since Chrome 56, Edge 79, Firefox 51, and Safari and iOS Safari 15 [source: https://caniuse.com/webgl2].
- caniuse measures browser support, not per-GPU availability. Browsers can blocklist old GPUs or drivers, and a page must handle `getContext('webgl2')` returning null [inferred].
- WebGL2 is OpenGL ES 3.0 semantics. On Windows, Chromium and Firefox run it through ANGLE, which translates OpenGL ES 3.0 to Direct3D 11, Vulkan or desktop GL. On macOS and iOS it maps to Metal [source: https://raw.githubusercontent.com/google/angle/main/README.md] [inferred].
- For old laptops: an iGPU with Direct3D 11 drivers can usually run WebGL2 through ANGLE's D3D11 backend. This is the same class of hardware as Godot's Compatibility minimum (OpenGL 3.3 or D3D11) [inferred] [source: https://docs.godotengine.org/en/stable/about/system_requirements.html].

### 1.2 WebGPU status (as of the gpuweb implementation-status page, updated 2026-08-13)
| Browser | Shipped by default | Not yet (flag or in development) |
|---|---|---|
| Chrome and Edge (Chromium) | Windows, macOS and ChromeOS since 113. Android 12+ (ARM, Qualcomm, Intel) since 121. Linux: Intel Gen12+ since 144, NVIDIA on Wayland since 147 | Other Linux GPUs, Windows on ARM64, Samsung Xclipse |
| Firefox | Windows since 141. macOS on Apple silicon since 145 (macOS 26+) and 147 (all versions) | macOS Intel and Linux (Nightly only), Android (behind a flag) |
| Safari | Safari 26 on macOS, iOS, iPadOS and visionOS | none listed |

- The table follows the gpuweb page [source: https://github.com/gpuweb/gpuweb/wiki/Implementation-Status], cross-checked against primary release notes:
  - Chrome 113 shipped WebGPU by default on ChromeOS, macOS and Windows [source: https://developer.chrome.com/blog/webgpu-release].
  - Firefox 141 "Enabled the WebGPU API ... on Windows" [source: https://www.firefox.com/en-US/firefox/141.0/releasenotes/].
  - Safari 26.0 ships WebGPU for macOS, iOS, iPadOS and visionOS [source: https://webkit.org/blog/17333/webkit-features-in-safari-26-0/].
- The gpuweb page is a community wiki kept by the W3C GPU for the Web group. I verified the rows for Chrome 113, Firefox 141 and Safari 26 against the vendors' own pages. The other rows (Linux, Android, Firefox 145 and 147) come only from the wiki [inferred].
- Implication [inferred]:
  - The Steam Deck (Linux, AMD) and many Linux laptops would not get WebGPU in Chromium by default, and Firefox on Linux and Android would not either.
  - A web build must therefore treat WebGPU as optional.
  - three.js makes that easy: its `WebGPURenderer` falls back to a WebGL 2 backend when WebGPU is unavailable [source: https://raw.githubusercontent.com/mrdoob/three.js/r186/src/renderers/webgpu/WebGPURenderer.js].

## 2. Renderer libraries and licences
| Library | Latest (npm, 2026-09-29) | Licence | Notes |
|---|---|---|---|
| three.js | 0.186.1 (release r186) | MIT | 3D. `WebGLRenderer`, and `WebGPURenderer` with WebGL2 fallback. glTF loader, AnimationMixer, SkeletonUtils retargeting, MeshToonMaterial and outline effects exist in r186 [source: https://registry.npmjs.org/three/latest] [source: https://api.github.com/repos/mrdoob/three.js] [source: https://raw.githubusercontent.com/mrdoob/three.js/r186/src/animation/AnimationMixer.js] |
| Babylon.js | @babylonjs/core 9.28.0 | Apache-2.0 | Full 3D engine. A community-managed visual editor (Apache-2.0) also exists [source: https://registry.npmjs.org/@babylonjs/core/latest] [source: https://api.github.com/repos/BabylonJS/Babylon.js] [source: https://api.github.com/repos/BabylonJS/Editor] |
| PixiJS | pixi.js 8.21.0 | MIT | 2D renderer, WebGL and WebGPU [source: https://registry.npmjs.org/pixi.js/latest] [source: https://api.github.com/repos/pixijs/pixijs] |
| PlayCanvas engine | playcanvas 2.22.6 | MIT | 3D engine. Its editor front end is MIT on GitHub, but the editor is used through playcanvas.com [source: https://registry.npmjs.org/playcanvas/latest] [source: https://api.github.com/repos/playcanvas/engine] [source: https://raw.githubusercontent.com/playcanvas/editor/main/README.md] |
| Raw WebGL2 (the spike's approach) | n/a | our code | No dependencies. Everything above the draw calls is ours [inferred] |

All four licences are permissive and compatible with an open-source game. Apache-2.0 adds a patent clause and a NOTICE requirement [inferred]. Any library we adopt must be added to the licence register (licence-register rule 1).

## 3. Desktop packaging
| Wrapper | Licence | What it ships | Caveats |
|---|---|---|---|
| Electron 44.4.5 | MIT | Chromium plus Node.js embedded in the binary. Windows, macOS and Linux [source: https://www.electronjs.org/docs/latest/] [source: https://registry.npmjs.org/electron/latest] | Same Chromium everywhere, so rendering is consistent. A large download, because every app carries its own Chromium [inferred] |
| Tauri (CLI 2.12.0) | MIT OR Apache-2.0 [source: https://registry.npmjs.org/@tauri-apps/cli/latest] [source: https://api.github.com/repos/tauri-apps/tauri/contents] | Uses the system webview [source: https://v2.tauri.app/reference/webview-versions/]: WebView2 (Chromium) on Windows, WKWebView on macOS and iOS, WebKitGTK on Linux, Android System WebView | macOS WebKit updates only with the OS, and Linux WebKitGTK versions vary widely by distro [source: https://v2.tauri.app/reference/webview-versions/]. Rendering and WebGL/WebGPU features would differ per OS, which is a risk for a GPU-heavy game on Linux and Steam Deck [inferred] |
| NW.js 0.117.0 | MIT | Chromium plus Node.js, like Electron [source: https://registry.npmjs.org/nw/latest] [source: https://api.github.com/repos/nwjs/nw.js] | Same size trade-off as Electron [inferred] |

- **Steam for web-tech games.** Steam accepts any Windows, macOS or Linux executable, so a wrapped build ships like a native one [inferred]. The Steam Direct fee is 100 USD per app, recoupable after 1,000 USD of revenue [source: https://partner.steamgames.com/doc/gettingstarted/appfee].
  - Steamworks bindings for Node, such as `steamworks.js` 0.4.0 (MIT), are community projects, not Valve's [source: https://registry.npmjs.org/steamworks.js/latest] [source: https://api.github.com/repos/ceifa/steamworks.js].
  - With Electron, the Steam overlay needs a call to `electronEnableSteamOverlay()` [source: https://raw.githubusercontent.com/ceifa/steamworks.js/main/README.md].
- **Steam Deck.** Valve tests a native Linux build if one exists, otherwise the Windows build under Proton [source: https://partner.steamgames.com/doc/steamdeck/compat].
  - An Electron or NW.js Linux build should work natively [inferred].
  - The Deck's Chromium would run WebGL2, not WebGPU, unless the Linux WebGPU rollout reaches AMD GPUs [source: https://github.com/gpuweb/gpuweb/wiki/Implementation-Status] [inferred].
  - Valve's controller and text-legibility criteria apply either way [source: https://partner.steamgames.com/doc/steamdeck/compat].

## 4. Mobile
- **In the browser or as a PWA.** WebGL2 is available on iOS Safari 15+ [source: https://caniuse.com/webgl2]. WebGPU is in Safari 26 on iOS [source: https://webkit.org/blog/17333/webkit-features-in-safari-26-0/] and in Chrome for Android 12+ since 121 [source: https://github.com/gpuweb/gpuweb/wiki/Implementation-Status]. A PWA can be installed from the browser without store fees [inferred].
- **Store apps** through Capacitor 8.5.2 (MIT), a native runtime that runs web apps on iOS and Android [source: https://capacitorjs.com/docs] [source: https://registry.npmjs.org/@capacitor/core/latest]. iOS builds still need Xcode on a Mac, and store accounts cost the same as for Godot: Apple 99 USD a year, Google 25 USD once [source: https://developer.apple.com/programs/whats-included/] [source: https://support.google.com/googleplay/android-developer/answer/6112435] [inferred].
- **Tauri 2** also targets iOS and Android through the system webviews [source: https://v2.tauri.app/reference/webview-versions/].
- **Performance.** A mobile browser adds JS JIT, WebGL validation and compositor overhead over native. Godot's own docs say native exports beat its web export "by a significant margin" [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html]. I have not measured the web stack on a phone [inferred].

## 5. The console path for a JS/TS game
- **No official route that I could verify.**
  - None of the four renderer libraries' repositories documents a console target [inferred].
  - Babylon Native, Microsoft's native host for Babylon.js, lists Windows, macOS, iOS, Android, Linux, visionOS and HoloLens builds, and no consoles [source: https://raw.githubusercontent.com/BabylonJS/BabylonNative/master/README.md].
- **Xbox (historical).**
  - Microsoft's archived page says HTML5 games once ran on Xbox One as UWP apps in the Edge engine [source: https://learn.microsoft.com/en-us/windows/uwp/xbox-apps/development-lanes-html].
  - The current FAQ says UWP games "are no longer accepted in the Xbox Store" and points to ID@Xbox [source: https://learn.microsoft.com/en-us/windows/uwp/xbox-apps/frequently-asked-questions].
- **Realistic options** [inferred]:
  - (a) Port the sim and renderer to a native engine or runtime for console builds. A sim written to the spike's portability contract ports mechanically, as the GDScript and C# ports showed.
  - (b) Hire a porting house that ports HTML5 games. A web search suggests some do this for Construct games, but I found no primary source for a general HTML5 service, so it is unverified.
  - The one concrete console runtime I found does not apply. Chowdren, offered as a porting service to small teams, compiles Scirra Construct and Clickteam Fusion event sheets to C++, with Switch, PlayStation and Xbox targets [source: https://mp2.dk/chowdren/]. It converts those engines' project formats, not hand-written TypeScript, so it is not a path for this codebase [inferred].
  - (c) Embed a JS engine and a native renderer in a custom console runtime. That is a large engineering project under NDA.
- **Open-source implication.** Any console layer is closed source under the platform NDA, as with Godot, so the public repo needs a platform seam [inferred].

## 6. Determinism in JS and WebAssembly

### 6.1 JavaScript numbers
- JS Numbers are IEEE 754 binary64, so + - * / follow IEEE rules [inferred from the spec's Number type].
- The spec's note on Math function properties says the transcendental functions are "not precisely specified here". The list covers acos, asin, atan, atan2, cbrt, cos, cosh, exp, expm1, hypot, log, pow, sin, sinh, tan, tanh and others [source: https://tc39.es/ecma262/multipage/numbers-and-dates.html].
  - It recommends, but does not require, fdlibm's algorithms [source: https://tc39.es/ecma262/multipage/numbers-and-dates.html].
  - Each step ends by returning "an implementation-approximated Number value" (for example `Math.sin`, §21.3.2.31) [source: https://tc39.es/ecma262/multipage/numbers-and-dates.html]. The published ES2025 edition has the same wording [source: https://262.ecma-international.org/16.0/].
  - `Math.pow` and the `**` operator go through `Number::exponentiate`, which is also implementation-approximated [source: https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html].
- `Math.sqrt` is exact: it returns 𝔽(the square root), with no approximation clause [source: https://tc39.es/ecma262/multipage/numbers-and-dates.html].
- `Math.imul` is defined exactly as the product modulo 2^32, reinterpreted as signed [source: https://tc39.es/ecma262/multipage/numbers-and-dates.html].
- Together with `|0`, `>>>`, `Math.floor` and `Math.fround`, this makes 32-bit integer RNGs and fixed-point math bit-exact across engines [inferred].
- `Math.random` uses an "implementation-defined algorithm", so it must never be used in the sim [source: https://tc39.es/ecma262/multipage/numbers-and-dates.html].
- Consequence [inferred]:
  - The sim uses only + - * / sqrt floor ceil % and integer operations, as in `shared/sim-ref.mjs`.
  - It uses its own RNG (mulberry32).
  - Any trigonometry is our own polynomial.
  - The same rules make the JS sim portable to GDScript, C# and C++.

### 6.2 WebAssembly
- Wasm floating-point results are deterministic except for NaNs. When an operation produces a NaN, its sign is non-deterministic, and its payload is too unless every input NaN is canonical [source: https://webassembly.github.io/spec/core/exec/numerics.html].
- Relaxed SIMD operators are "implementation-dependent", meaning their results can depend on the hardware [source: https://webassembly.github.io/spec/core/exec/numerics.html].
- The spec defines a deterministic profile in which NaNs are canonical and relaxed instructions behave in a fixed way [source: https://webassembly.github.io/spec/core/appendix/profiles.html]. Browsers are not required to run in that profile, so we must not rely on it [inferred].
- Consequence [inferred]:
  - A Wasm sim core (C++, Rust or AssemblyScript) must avoid relaxed SIMD.
  - It must canonicalise NaNs before hashing, or better, never produce them.
  - Godot's own web build is Wasm too, so this applies to a GDScript sim running on the web as well.

## 7. Timers and cross-origin isolation
- `performance.now()` resolution is 5 µs in cross-origin-isolated contexts and 100 µs otherwise [source: https://developer.mozilla.org/en-US/docs/Web/API/Performance/now].
- `SharedArrayBuffer` needs a secure context and cross-origin isolation, which means COOP and COEP headers. Pages can check `crossOriginIsolated` [source: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/SharedArrayBuffer]. Godot documents the values `same-origin` and `require-corp` [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
- The `requestAnimationFrame` rate "will generally match the display refresh rate", and it pauses in background tabs [source: https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame].
- Consequences [inferred]:
  - A fixed 60 Hz sim needs an accumulator, as SPEC.md already says.
  - Browser frame times cannot go below the refresh interval without Chromium command-line flags, which matters when comparing "uncapped" web numbers with Godot's.
  - Moving the sim or audio off the main thread does **not** need isolation. Dedicated Workers exchange data by `postMessage`, which copies it or transfers an `ArrayBuffer` [source: https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers]. AudioWorklet needs only a secure context (HTTPS) [source: https://developer.mozilla.org/en-US/docs/Web/API/AudioWorklet].
  - Only shared-memory threading needs COOP/COEP: `SharedArrayBuffer`, and therefore Wasm threads for a C++ or Rust core [source: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/SharedArrayBuffer]. Static hosts that cannot set headers can only get isolation through a service-worker workaround, as Godot's PWA option does [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html] [inferred].
  - So a TypeScript sim in a Worker, messaging inputs in and snapshots out, runs on itch.io or GitHub Pages without special headers [inferred].

## 8. Gamepad
- The Gamepad API is MDN "Baseline: widely available" (since March 2017) [source: https://developer.mozilla.org/en-US/docs/Web/API/Gamepad_API].
- The W3C spec is a Working Draft dated 2025-07-10 [source: https://www.w3.org/TR/gamepad/]:
  - `getGamepads()` returns an empty list until a "gamepad user gesture" is seen, which is a fingerprinting mitigation.
  - A pad reports the "standard" mapping only when the browser has mapped its controls to the Standard Gamepad layout. Other pads expose raw, device-specific indices [inferred].
  - Haptics (`GamepadHapticActuator`, dual-rumble and trigger-rumble) are in the spec. MDN still marks the haptics extension as experimental [source: https://developer.mozilla.org/en-US/docs/Web/API/Gamepad_API].
- Godot's docs describe browser controller support as varying "wildly across browsers" [source: https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html]. This affects both stacks on the web. Native Godot desktop builds use SDL 3 instead [source: https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html].

## 9. Tooling a web build must write (or adopt) itself [inferred]
Godot provides each of these out of the box. In the web stack each is ours to build or assemble:
1. **Scene and level editor.** Placing structures, civilians, cover and biome dressing, with a data format and a reviewable text diff. The options are a custom in-browser editor, the Babylon editor (Apache-2.0, community-managed) or PlayCanvas's hosted editor [source: https://api.github.com/repos/BabylonJS/Editor] [source: https://raw.githubusercontent.com/playcanvas/editor/main/README.md].
2. **Animation.**
   - three.js provides clip playback (`AnimationMixer.update`/`setTime`) and skeleton retargeting (`SkeletonUtils.retarget`/`retargetClip`) [source: https://raw.githubusercontent.com/mrdoob/three.js/r186/src/animation/AnimationMixer.js] [source: https://raw.githubusercontent.com/mrdoob/three.js/r186/examples/jsm/utils/SkeletonUtils.js].
   - Blend trees, state machines, their editor and root-motion handling are ours.
3. **VFX.** A particle system and its authoring UI, shader authoring (no visual shader editor in three.js), and the look-dev loop.
4. **Asset pipeline.** glTF import settings, texture compression (KTX2/Basis), LOD and a build step that fingerprints and packs assets.
5. **Debug and profiling tools.** Frame profiler, sim debug feed and overlay, replay viewer. Browser devtools cover some of this.
6. **Platform glue.** Input remapping UI, save data, localisation, audio mixing, packaging (Electron, Capacitor), Steamworks bindings.
7. **Modding.** A mod loader and its sandbox (see below).

## 10. Modding on the web [inferred]
- A JS mod loaded into the page runs with the page's full privileges: DOM, storage and network.
- Safer designs:
  - Data-only mods (JSON atoms, templates, fighters, biomes, glTF and PNG assets) validated against schemas.
  - Script mods run in a Worker or a sandboxed iframe that talks to the game through messages, and can only return intents.
- The same data-first split is recommended for Godot, where script mods also have full privileges (see `godot.md` §9).
- On desktop wrappers (Electron or NW.js), a mod with Node access could touch the file system. Node integration must stay off for mod code.

## 11. Cel shading, low poly and procedural geometry
- three.js r186 has `BufferGeometry` for runtime meshes, `MeshToonMaterial`, and two outline approaches: `OutlineEffect` (inverted hull) and `OutlinePass` (post-process) [source: https://raw.githubusercontent.com/mrdoob/three.js/r186/src/core/BufferGeometry.js] [source: https://raw.githubusercontent.com/mrdoob/three.js/r186/src/materials/MeshToonMaterial.js] [source: https://raw.githubusercontent.com/mrdoob/three.js/r186/examples/jsm/effects/OutlineEffect.js] [source: https://raw.githubusercontent.com/mrdoob/three.js/r186/examples/jsm/postprocessing/OutlinePass.js].
- With raw WebGL2, as in the spike, the same results take custom vertex buffers and our own toon and outline shaders. That is not hard, but it is ours to maintain [inferred].
- Details and the comparison with Godot are in `pipeline.md`.

## 12. Distribution
- **itch.io.** HTML5 zips are limited to 1,000 files, 500 MB extracted and 200 MB per file. wasm and other files are gzipped automatically, and `.br` files are served as brotli [source: https://itch.io/docs/creators/html5].
- **GitHub.** Pages can host the static build [inferred]. Release assets must be under 2 GiB each, with no limit on total size or bandwidth [source: https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases].
- **Steam.** Through a desktop wrapper (section 3).

## 13. Not verified (gaps)
- WebGPU rows beyond Chrome 113, Firefox 141 and Safari 26: taken from the gpuweb wiki only.
- Console porting services for HTML5 games: no primary source found.
- Real per-GPU WebGL2 availability on old laptops, and browser blocklists: not measured.
- Tauri or Electron frame pacing on Steam Deck: not tested.
- Whether V8, SpiderMonkey and JavaScriptCore currently give identical `Math.sin` results: not tested. The spec does not require it.
