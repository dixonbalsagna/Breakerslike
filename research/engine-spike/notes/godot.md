# Godot 4.7.2: evidence notes for ADR 0001

Owner: Research & Prototyping (engine spike, notes). Written 2026-09-29. Engine under test: Godot 4.7.2 stable, official build `4.7.2.stable.official.ed1daf0bf`, released 2026-08-18 [source: https://api.github.com/repos/godotengine/godot/releases/tags/4.7.2-stable].

How to read the tags:
- `[source: URL]` means the page or file at that URL supports the claim. Every URL is listed with its access date in `sources.md`.
- `[source: local M<n>]` means a command run on this machine. The commands and their output are in "Local measurements" at the end.
- `[inferred]` means my own reasoning from the sourced facts. Check it before relying on it.
- Quotes are short (15 words or fewer). Everything else is paraphrase.

Related notes: `web.md` (the web stack), `pipeline.md` (art pipeline and tooling), `csharp.md` (C# in Godot 4.7, including web export; owned by the C# agent).

## Summary for the decision

1. **Determinism is achievable, but only in our own code.** GDScript `float` and `int` are 64-bit. Vector types are 32-bit in official builds. Transcendental math comes from the C runtime, and engine physics gives no determinism guarantee. A rollback sim should use scalar floats (or integers) with + - * / sqrt only, plus our own RNG. The spike's GDScript port does this and matches the reference goldens [source: local M4] [inferred].
2. **Web export works, with limits.** Only the Compatibility renderer (WebGL 2.0) runs on the web. There is no WebGPU. Single-threaded export is the default since 4.3 and needs no special headers. The runtime is a 39.5 MB wasm, about 10.1 MB gzipped or 6.9 MB with brotli [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html] [source: local M1, M2].
3. **C# cannot export to the web in 4.7.** GDScript can. See `csharp.md` [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
4. **Old laptops.** The Compatibility renderer needs only OpenGL 3.3, or Direct3D 11 through ANGLE on Windows. It is also the renderer the web build uses, so one renderer covers both the minimum spec and the browser [source: https://docs.godotengine.org/en/stable/about/system_requirements.html] [inferred].
5. **Consoles are only available through third-party ports under NDA.** For an open-source game, the console layer would have to be a private fork [source: https://godotengine.org/consoles/] [inferred].
6. **Benchmark caveat for the final runs:** `--gpu-index` works only with the Forward+ and Mobile renderers, not with Compatibility [source: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html]. The official Windows binaries also export `NvOptimusEnablement = 1` and `AmdPowerXpressRequestHighPerformance = 1`, which ask hybrid-GPU drivers for the high-performance GPU, so `gl_compatibility` runs lean towards the RTX [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/windows/os_windows.cpp] [source: local M5] [inferred]. There is no command-line way to put a Compatibility run on the iGPU. That needs a manual Windows graphics-preference change by Orb or the director, or the display attached to the iGPU. Every run's adapter string in the bench JSON must be checked (section 6) [inferred].

## 1. Determinism for a rollback-capable fixed-step sim

### 1.1 Number types
- GDScript `float` is a 64-bit double, equivalent to C++ `double` [source: https://docs.godotengine.org/en/stable/classes/class_float.html].
- `Vector2`, `Vector3` and the other math structs use `real_t`. The docs say they are 32-bit by default, unlike `float` which is "always 64-bit" [source: https://docs.godotengine.org/en/stable/classes/class_vector2.html] [source: https://docs.godotengine.org/en/stable/classes/class_float.html].
- Official 4.7.2 builds are single precision. On this machine `OS.has_feature("single")` is true, and `Vector2(0.1, 0).x` differs from the float64 value 0.1 by 1.49e-9, which is float32 rounding [source: local M3].
- Double-precision vectors need a custom engine build. Both the editor and the export templates need `precision=double`, and GDExtensions must be rebuilt as well [source: https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html]. Shaders stay 32-bit on the GPU even then [source: https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html].
- GDScript `int` is a signed 64-bit integer that wraps on overflow [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/int.xml] [source: local M3].
  - To reproduce 32-bit integer RNGs such as mulberry32, mask with `& 0xFFFFFFFF` and build `imul` from 16-bit halves, as `godot/sim/rng.gd` does [inferred].
  - Int-to-int division truncates, so mixed int/float formulas need explicit `float()` casts. The shared portability contract calls this out [inferred].
- **Consequence for the sim** [inferred]:
  - Keep all sim state in scalar `float` and `int`, or in `PackedFloat64Array` and `PackedInt64Array`.
  - Never use Vector2, Vector3 or Transform types for sim state in an official build, because they would silently round to float32.
  - Vectors are fine in the renderer.

### 1.2 RandomNumberGenerator
- The class docs say it "currently uses PCG32" [source: https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html].
- The same page calls the algorithm "an implementation detail and should not be depended upon" [source: https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html].
- `seed` gives a reproducible sequence. The `state` property can be saved and restored, which is what rollback needs [source: https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html].
- The float helpers are riskier than `randi()`:
  - In 4.7.2, `randf()` and `randd()` use a count-leading-zeros intrinsic and `ldexp`, with a different fallback formula compiled in when the intrinsic is missing [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/core/math/random_pcg.h].
  - `randfn()` uses the Box-Muller transform [source: https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html], which needs log and cos from libm [inferred].
- Recommendation [inferred]:
  - Own the RNG in the sim, as the spike does with mulberry32 in integer ops.
  - If `RandomNumberGenerator` is used, take only `randi()` and convert to float with an exact division by 2^32.

### 1.3 Transcendental math comes from the platform C runtime
- In 4.7.2, `Math::sin`, `cos`, `pow`, `exp` and `sqrt` simply call `std::sin` and the other `std::` functions [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/core/math/math_funcs.h].
- The results therefore depend on each platform's libm [inferred]:
  - Windows: the MinGW-w64 runtime. The official Windows builds use MinGW-w64 GCC, not MSVC. The 4.7.2 release template contains `GCC: (MinGW-W64 x86_64-msvcrt-posix-seh ...) 15.2.0` strings [source: local M5], and the official 4.7 build container installs the MinGW toolchains [source: https://raw.githubusercontent.com/godotengine/build-containers/4.7/Dockerfile.windows].
  - Linux: glibc. macOS and iOS: Apple's libm. Web: Emscripten's libc, which is based on musl [inferred].
- `sqrt` is correctly rounded under IEEE 754, so it is safe [inferred].
- Consequence [inferred]:
  - Sim code must avoid `sin`, `cos`, `pow`, `exp`, `log` and `atan2`, or replace them with our own polynomial or table built from + - * / only.
  - This is what `shared/sim-ref.mjs` already requires.

### 1.4 Built-in physics is not a deterministic base
- In 4.7, new projects use Jolt for 3D physics by default [source: https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html]. That page says nothing about determinism [source: https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html].
- The Jolt integration's own repository says Godot's integration cannot offer the determinism Jolt itself offers [source: https://github.com/godot-jolt/godot-jolt].
- A 2025 engine issue reported 2D physics that was not deterministic even within one instance on one machine. It is now closed, and I did not check how it was resolved [source: https://github.com/godotengine/godot/issues/112976].
- Godot Rapier Physics (MIT) claims cross-platform deterministic simulation. It builds its dependencies with `enhanced-determinism`, supports 4.7 and has single-threaded web builds [source: https://github.com/appsinacup/godot-rapier-physics]. I have not tested it.
- Consequence [inferred]:
  - Fighters, launches, craters and beams stay in our own sim (the three-layer architecture).
  - Engine physics, if used at all, is presentation only (debris, ragdolls) and is never read back into the sim.

### 1.5 Fixed step
- `_physics_process` runs at a fixed rate, 60 per second by default [source: https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html].
- The rate is `physics/common/physics_ticks_per_second`, default 60 [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/ProjectSettings.xml]. `Engine.max_physics_steps_per_frame` defaults to 8 [source: https://docs.godotengine.org/en/stable/classes/class_engine.html].
- `physics/common/physics_jitter_fix` defaults to 0.5. At 0 or less, ticks stay synchronised with real time, which the docs recommend for network games [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/ProjectSettings.xml].
- `Engine.time_scale` stretches each tick over more engine time and does not change the tick rate [source: https://docs.godotengine.org/en/stable/classes/class_engine.html].
- Two workable patterns [inferred]:
  - (a) Step the sim from `_physics_process` with `physics_jitter_fix = 0`.
  - (b) Run a custom accumulator in `_process` that calls the sim's own `step()` (at most 8 steps per frame, as SPEC.md requires), which keeps the sim independent of engine timing. The spike uses (b). It is also the better fit for rollback, because re-simulating N ticks is a plain loop.
- Animation can be stepped by the sim too. `AnimationMixer` (the base of AnimationPlayer and AnimationTree) has a manual process mode driven by `advance()` [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/AnimationMixer.xml].

### 1.6 Rollback options and add-ons
| Option | Model | Licence | Status (checked 2026-09-29) |
|---|---|---|---|
| Godot Rollback Netcode (David Snopek) | Peer-to-peer rollback and prediction. Covers input, state save and load, hashing and mismatch detection, timers, animation, RNG and sound [source: https://gitlab.com/snopek-games/godot-rollback-netcode/-/raw/main/README.md] | MIT [source: https://gitlab.com/snopek-games/godot-rollback-netcode/-/raw/main/LICENSE.txt] | v1.0.0 released 2026-06-06. The main branch's project targets feature set "4.6" [source: https://gitlab.com/api/v4/projects/snopek-games%2Fgodot-rollback-netcode/releases/v1.0.0] [source: https://gitlab.com/snopek-games/godot-rollback-netcode/-/raw/main/project.godot]. Separate C# wrapper (MIT) [source: https://api.github.com/repos/Fractural/GodotRollbackNetcodeMono] |
| netfox (Fox's Sake Studio) | Client-side prediction with server-side reconciliation, plus rollback and interpolation [source: https://raw.githubusercontent.com/foxssake/netfox/main/README.md] | MIT [source: https://api.github.com/repos/foxssake/netfox] | Supports Godot 4.x. Latest GitHub release v1.35.3 (2025-11-23), last push 2026-09-26 [source: https://api.github.com/repos/foxssake/netfox] |
| Own implementation | Lockstep or rollback over our deterministic sim | n/a | Our sim already has seeded RNG, fixed step and state hashing (`shared/golden.json`), which are the prerequisites [inferred] |

- Either add-on needs our sim to be deterministic and snapshot-able. Neither makes engine physics deterministic [inferred].
- Online is post-launch (Orb's criteria), so the choice can wait. The sim must still be built rollback-ready from the start [inferred].

### 1.7 GDExtension as a route to a native core
- godot-cpp holds the official C++ bindings [source: https://docs.godotengine.org/en/stable/tutorials/scripting/cpp/about_godot_cpp.html]. It is MIT [source: https://api.github.com/repos/godotengine/godot-cpp].
- Extensions built for an earlier Godot minor version should work in later ones, but not the other way round [source: https://docs.godotengine.org/en/stable/tutorials/scripting/cpp/about_godot_cpp.html].
- gdext (the Rust bindings) is MPL-2.0 [source: https://api.github.com/repos/godot-rust/gdext]. Its web support is labelled experimental [source: https://godot-rust.github.io/book/toolchain/export-web.html]:
  - It needs nightly Rust and the `wasm32-unknown-emscripten` target.
  - For Emscripten, the book says "We recommend version 3.1.74 when targeting Godot 4.3 or later".
  - It needs either threaded export or its `experimental-wasm-nothreads` feature.
- The official 4.7 web templates were built with a newer toolchain. The official build container for the 4.7 branch pins `EMSCRIPTEN_VERSION=4.0.20` [source: https://raw.githubusercontent.com/godotengine/build-containers/4.7/Dockerfile.web], and the commit that set it is titled "Update various toolchains for 4.6" [source: https://api.github.com/repos/godotengine/build-containers/commits?sha=4.7&path=Dockerfile.web&per_page=3]. An independent review of these notes also reported a browser load of the 4.7.2 template printing Emscripten 4.0.20. I did not repeat that run. The book's 3.1.74 advice may therefore be stale for 4.7 [inferred].
- Risk, not tested: a C++ or Rust side module usually needs an Emscripten version compatible with the one that built the templates. Matching toolchains for a native core on the web is an open risk [inferred].
- Web requirements from the Godot docs:
  - The export must enable "Extensions Support".
  - Extensions must be compiled for the web.
  - The docs say that, like threads, this needs cross-origin isolation headers [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
  - Extension-enabled exports use the separate "dlink" templates. On this machine `web_dlink_nothreads_release.zip` holds a 44.1 MB `godot.side.wasm` plus a 1.5 MB main wasm, against 39.5 MB for the plain template [source: local M1].
  - I did not test whether a no-threads extension build really needs COOP/COEP in a browser. The docs say it does.
- Consequence [inferred]:
  - A native core (C++ or Rust) is possible, and it gives full control of float behaviour.
  - On the web it adds cross-origin isolation, a larger download and a per-platform toolchain.
  - With GDScript for the sim, the web build stays header-free.

### 1.8 What the spike showed
- The GDScript sim port (`godot/sim/`) reproduces every SHA-256 golden of `shared/sim-ref.mjs`, and its `tests/run_tests.gd` exits 0. The Godot sim agent reported this in the resumed-run state. I did not re-run it for these notes, to avoid writing into another agent's `.godot/` cache [inferred].
- This is evidence of same-machine, same-build agreement between V8 and GDScript. It is not evidence of cross-platform agreement: Linux, macOS, ARM and web builds of the port have not been run [inferred].

## 2. Web export in 4.7

### 2.1 Renderer, threads and headers
- The web platform supports only the Compatibility renderer, which targets WebGL 2.0. The docs state "Forward+/Mobile are not supported on the web platform" [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
- Godot does not support WebGPU, which the docs name as the prerequisite for Forward+ and Mobile on the web [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
- Single-threaded export exists since 4.3 and is now the default and preferred way [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
  - It cannot use threads and is slower than the threaded export [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
  - It works well on macOS and iOS, where threaded exports always had compatibility issues [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
- SharedArrayBuffer and the COOP and COEP headers are needed only with "Use Threads" or "Extensions Support".
  - The headers are `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
  - The PWA option can inject them through a service worker when a host cannot set headers [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
- Verified locally: a headless export of a minimal 3D project with default Web settings used the no-threads release template (identical wasm SHA-256) and wrote `GODOT_THREADS_ENABLED = false` [source: local M2].

### 2.2 Sizes (measured from the installed official templates)
| Template (zip) | Zip size | wasm inside | Notes |
|---|---|---|---|
| web_nothreads_release | 10,245,903 B | godot.wasm 39,514,754 B | default export [source: local M1] |
| web_release (threads) | 10,290,815 B | godot.wasm 38,820,072 B | needs COOP/COEP [source: local M1] |
| web_dlink_nothreads_release (extensions) | 11,549,046 B | godot.wasm 1,508,095 B + godot.side.wasm 44,078,870 B | GDExtension builds [source: local M1] |

- Compression of the default wasm on this machine: gzip -9 gives 10,084,297 B (25.5%), brotli (default quality) gives 6,902,599 B (17.5%) [source: local M1]. This matches the docs' "around a quarter" with gzip [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
- A minimal 3D project's `.pck` was 2,392 B. The full minimal export was about 39.8 MB uncompressed, almost all of it engine [source: local M2].
- The game's own `.pck` will grow with assets. The spike's own pck size is measured by the Godot render build, not here [inferred].
- Implication [inferred]:
  - Plan for a first download of roughly 7 to 10 MB compressed engine plus game data.
  - A custom template build that strips unused modules (for example 2D physics and navigation) can shrink this. I have not measured it.

### 2.3 Browser and mobile support
- The page needs WebAssembly and WebGL 2.0 in the browser [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
- Browser lists for exported projects, from the "Exported Godot project" part of the system requirements [source: https://docs.godotengine.org/en/stable/about/system_requirements.html]:
  - Recommended (desktop): the latest Firefox, Chrome, Edge, Safari and Opera. Recommended (mobile) adds Samsung Internet.
  - Minimum (desktop and mobile): recent versions of Firefox, Chrome and their derivatives, and Safari and WebKit derivatives. On the 4.7 page these minimum rows are labelled "Web editor", apparently carried over from the editor section, so treat them as indicative.
- The docs warn that Safari "has several issues with WebGL 2.0 support that other browsers don't have" and recommend Chromium or Firefox [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
- Web exports run on mobile browsers, but native Android and iOS exports "will always perform better by a significant margin" [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].

### 2.4 Audio, input and browser rules
- Since 4.3, web exports use **Sample** playback by default, through the Web Audio API [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
  - The docs say Sample mode "allows for low latency even when the project is exported without thread support".
  - The cost is features: no AudioEffects, no reverb or doppler, and no procedural audio generation.
- **Stream** playback (a project setting, or per player node) enables the full audio feature set. The docs warn it "leads to increased latency", especially without thread support [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
- Low-latency Stream playback is one of the reasons the docs give for the threaded build, which needs COOP/COEP [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
- So the default no-threads build has low-latency audio as long as the game avoids bus effects and procedural audio. A game that needs them on the web needs the threaded build and its headers [inferred]. I have not measured latency in either mode.
- Audio needs a user interaction before it can start. Fullscreen and mouse capture must happen inside a JavaScript input event [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
- Gamepads are not detected until a button is pressed [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].

### 2.5 C#
- The docs state "Projects written in C# using Godot 4 currently cannot be exported to the web" [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].
- The empirical check and the roadmap are in `csharp.md`.

## 3. Desktop export and Steam

- **Windows.** The x86_64 release template executable is 109,268,480 B on this machine, which is the size of a shipped game before its pck [source: local M1].
- **macOS.** Export and notarisation are covered in the macOS export docs [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html]:
  - Notarising needs an Apple Developer ID certificate.
  - Projects exported without code signing and notarisation are blocked by Gatekeeper.
  - From Windows or Linux, signing and notarising use `rcodesign` instead of Xcode.
  - Without a certificate, the "Built-in (ad-hoc only)" option makes the app easier for users to launch. Downloaded builds that are not signed and notarised are still blocked by Gatekeeper, and users must follow the manual steps on the docs page "Running Godot apps on macOS".
  - The Apple Developer Program costs 99 USD per membership year [source: https://developer.apple.com/programs/whats-included/]. With Orb's zero budget, macOS builds would ship unsigned: users can still override Gatekeeper, but it is a poor experience [inferred].
  - The macOS template zip is 123,597,580 B [source: local M1].
- **Linux.** x86_64 is the default. arm64 builds exist [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_linux.html]. The x86_64 release template is 73,519,416 B [source: local M1].
- **Steam.**
  - GodotSteam is MIT. It has moved from GitHub (now archived) to Codeberg, and it maps each GodotSteam version to the Steamworks SDK version it supports [source: https://codeberg.org/godotsteam/godotsteam/raw/branch/godot4/license.md] [source: https://raw.githubusercontent.com/GodotSteam/GodotSteam/master/readme.md] [source: https://codeberg.org/godotsteam/godotsteam/raw/branch/godot4/readme.md].
  - The Steamworks SDK itself is Valve's proprietary SDK. The open-source repo should reference it and not commit it. This needs Legal to confirm against Valve's SDK terms, which I did not fetch [inferred].
  - The Steam Direct fee is 100 USD per app, recoupable once the product reaches 1,000 USD adjusted gross revenue [source: https://partner.steamgames.com/doc/gettingstarted/appfee].

## 4. Steam Deck
- Valve's Deck compatibility review covers four areas [source: https://partner.steamgames.com/doc/steamdeck/compat]:
  - Full controller support in the default configuration.
  - Controller glyphs that match the input in use.
  - Text legible at 1280x800.
  - No compatibility warnings, and launchers that can be navigated with a controller.
- Games may run through Proton. If a native Linux build exists, testers test it and use whichever runtime works better [source: https://partner.steamgames.com/doc/steamdeck/compat].
- Valve does not prescribe native Linux over Proton. Its Proton page lists known problem areas: .NET/WPF UI, Media Foundation and kernel-level anti-cheat [source: https://partner.steamgames.com/doc/steamdeck/proton].
- Godot exports a native Linux x86_64 build, and GDScript projects have none of the listed Proton problem areas. Either route should work [inferred]. The Deck's AMD APU supports Vulkan, so the Forward+ and Mobile renderers are available there as well as Compatibility [inferred].

## 5. Mobile export (GDScript)
- **Android** [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html]:
  - Tools: OpenJDK 17, Android SDK Platform-Tools 35.0.0 or later, Build-Tools 35.0.1, Platform 35, CMake 3.10.2.4988404 and NDK r28b.
  - Google Play requires AAB, which needs a Gradle build, and a release keystore.
  - Play Console registration is 25 USD one time. Personal accounts created after 2023-11-13 must pass a testing requirement before publishing [source: https://support.google.com/googleplay/android-developer/answer/6112435].
  - Minimum OS is Android 7.0 for Compatibility and 9.0 for Forward+ and Mobile [source: https://docs.godotengine.org/en/stable/about/system_requirements.html].
- **iOS:**
  - Export must be done "from a computer running macOS with Xcode installed" [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html].
  - It needs an App Store Team ID [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html], which means an Apple Developer Program membership at 99 USD a year [source: https://developer.apple.com/programs/whats-included/] [inferred].
  - Minimum iOS is 12.0 (Vulkan) or 16.0 (Metal) for Forward+ and Mobile [source: https://docs.godotengine.org/en/stable/about/system_requirements.html].
  - C# on iOS has been experimental since 4.2 [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html].
- The same GDScript project exports to both with no code changes. The cost is toolchains, accounts and a Mac for iOS [inferred]. The installed release templates are 104,803,333 B (Android APK) and 202,976,946 B (ios.zip). These are template sizes, not the size of a shipped app [source: local M1].

## 6. Old laptops and integrated GPUs
- **Minimum GPU per renderer** [source: https://docs.godotengine.org/en/stable/about/system_requirements.html]:
  - Forward+ needs Vulkan 1.0, Direct3D 12 (feature level 12_0) or Metal 3. The docs' examples are Intel HD 510 and AMD Radeon R5.
  - Compatibility needs OpenGL 3.3, or Direct3D 11 on Windows. The docs' examples are Intel HD 2500 and AMD Radeon R5.
  - On mobile, Compatibility needs OpenGL ES 3.0.
- The docs recommend Compatibility for older desktop and mobile devices [source: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html].
- Compatibility lacks some features, including particle trails, particle SDF collision, SSR and SDFGI. Glow works [source: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html].
- **Driver fallbacks** [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/ProjectSettings.xml]:
  - On Windows, Compatibility falls back to ANGLE (`fallback_to_angle`, default true) when native OpenGL is missing or the device is on `force_angle_on_devices`.
  - Forward+ falls back to OpenGL 3 when D3D12, Metal and Vulkan are all missing (`fallback_to_opengl3`, default true).
  - Since 4.4, Vulkan and D3D12 fall back to each other [source: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html].
- Implication [inferred]: a 2.5D game targeting Compatibility runs one render path on old iGPUs, mobile browsers and the web build. The iGPU smoke and final runs on the AMD Radeon iGPU are the right proxy.
- **Benchmark caveat:**
  - `--gpu-index` applies only to Forward+ and Mobile. The docs describe it as "only available on the Forward+/Mobile renderers" [source: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html].
  - The official Windows binaries export `NvOptimusEnablement = 1` and `AmdPowerXpressRequestHighPerformance = 1` (lines 101 and 102 of `platform/windows/os_windows.cpp` at 4.7.2-stable) [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/windows/os_windows.cpp]. Both symbols are present in the installed 4.7.2 editor and Windows release template [source: local M5].
  - On hybrid systems these exports ask the NVIDIA and AMD drivers for the high-performance GPU, which matters for OpenGL. `gl_compatibility` runs will therefore tend to land on the RTX, and a Windows per-app graphics preference can still override that [inferred].
  - There is no command-line route to force the iGPU for the Compatibility minimum-spec runs. They need either a manual Windows graphics-preference change for the Godot executable, made by Orb or the director (agents may not change system settings), or the display connected to the iGPU [inferred].
  - Record `RenderingServer.get_video_adapter_name()` for each run, as the EP amendment requires, and discard runs on the wrong adapter [inferred].

## 7. Consoles
- The open-source engine ships no console support. Godot's console page explains that console development needs legal contracts and closed access, while Godot is MIT and has no NDAs [source: https://godotengine.org/consoles/].
- The 4.5 docs give the reasons as legal liability, disproportionate cost and open-source licensing issues [source: https://docs.godotengine.org/en/4.5/tutorials/platform/consoles.html].
- Developers must register with each console maker and be approved for its SDKs [source: https://godotengine.org/consoles/].
- **Routes:**
  - W4 Games middleware covers Switch, Xbox Series X|S and PlayStation 5 [source: https://godotengine.org/consoles/].
  - Porting houses include Lone Wolf Technology, Pineapple Works, RAWRLAB, mazette!, Tuanisapps, Seaven Studio and Sickhead Games [source: https://godotengine.org/consoles/]. The 4.5 docs list their consoles, and say Pineapple Works covers both GDScript and C# [source: https://docs.godotengine.org/en/4.5/tutorials/platform/consoles.html].
  - The 4.7 docs URL for that page returned 404 on 2026-09-29, so I used the 4.5 page and the official site.
- **Implications for an open-source game** [inferred]:
  - Console SDK code and the console-specific engine port are under NDA and cannot live in the public repo.
  - The game would need a private console fork or a porting partner. Public code should reach platform services (saves, achievements, input glyphs, networking) only through a narrow platform interface, so the private layer stays small.
  - Rollback netcode on console also depends on each platform's networking rules. Budget for a partner or a paid middleware licence.

## 8. Tooling
- **Editor and code editing:**
  - The GDScript Language Server needs a running Godot instance with the project open. The defaults are port 6005 for LSP and 6006 for the Debug Adapter [source: https://docs.godotengine.org/en/stable/tutorials/editor/external_editor.html].
  - The official VS Code extension is MIT [source: https://api.github.com/repos/godotengine/godot-vscode-plugin].
- **Test frameworks:**
  - GUT is MIT; its 9.x releases target Godot 4, and it has a command-line runner. Latest release v9.6.1, 2026-07-09 [source: https://raw.githubusercontent.com/bitwes/Gut/main/README.md] [source: https://raw.githubusercontent.com/bitwes/Gut/main/addons/gut/LICENSE.md] [source: https://api.github.com/repos/bitwes/Gut/releases/latest].
  - gdUnit4 is MIT and now lives in `godot-gdunit-labs`. It tests GDScript and C#, and has a command-line tool, JUnit XML output and a GitHub Action. Latest release v6.2.1, 2026-08-20 [source: https://raw.githubusercontent.com/godot-gdunit-labs/gdUnit4/master/README.md] [source: https://api.github.com/repos/MikeSchulze/gdUnit4] [source: https://api.github.com/repos/godot-gdunit-labs/gdUnit4/releases/latest].
  - The spike itself uses a plain `-s` script, `tests/run_tests.gd`, with no framework [inferred].
- **Headless CI and exports:**
  - The command-line flags are `--headless`, `--import`, `--export-release`, `--export-debug`, `--export-pack` and `-s <script>` [source: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html].
  - Exports need the export templates installed, or a custom template [source: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html].
  - Measured: a headless web export of a minimal project took 2.6 s wall time on this machine [source: local M2].
- **Scene format and merging:**
  - TSCN and TRES are text formats, "mostly human-readable and easy for version control systems to manage" [source: https://docs.godotengine.org/en/stable/engine_details/file_formats/tscn.html].
  - Scenes carry `uid://` identifiers so moved files keep their references, and `load_steps` has been deprecated since 4.6 [source: https://docs.godotengine.org/en/stable/engine_details/file_formats/tscn.html]. Removing `load_steps` also removed a frequent source of merge conflicts [inferred].
  - Whitespace and comments are discarded on save, and default-valued properties are not stored [source: https://docs.godotengine.org/en/stable/engine_details/file_formats/tscn.html]. Hand edits and editor edits can therefore produce noisy diffs [inferred].
  - Rule of thumb: one owner per scene at a time, and small scenes composed by instancing. Keep content that is data (atoms, templates, fighters) in JSON or plain `.tres` files, not large scenes [inferred].
- **C#:** see `csharp.md`. In short, C# is not an option while web export matters [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html].

## 9. Modding
- Godot can load PCK or ZIP packs at runtime with `ProjectSettings.load_resource_pack()`. By default a pack replaces files with the same path, and a second argument opts out [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html].
- The docs call automatic pack loading a security vulnerability in three scenarios, including malicious mods, and suggest signing patches with asymmetric cryptography [source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html].
- `FileAccess.get_var(allow_objects)` warns that deserialised objects can contain code that gets executed [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/FileAccess.xml].
- Scripts inside a loaded pack or scene run with full engine privileges. There is no sandbox, so script mods are as trusted as the game [inferred].
- Recommended split [inferred]:
  - Data mods: JSON atoms, exchange templates, fighters and biomes, plus glTF and PNG assets loaded through the runtime loaders the docs recommend for user content [source: https://docs.godotengine.org/en/stable/tutorials/io/runtime_file_loading_and_saving.html]. These are far safer than script mods, because by design they execute no code. The glTF, image and JSON parsers are still an attack surface, so validate mods against schemas and size limits before loading [inferred].
  - Script mods are opt-in, with a clear warning.
- Community option: Godot Mod Loader is CC0-1.0 [source: https://api.github.com/repos/GodotModding/godot-mod-loader].
- On the web, packs must first be fetched into the virtual file system. I did not test this [inferred].

## 10. Gamepad
- Since 4.5, desktop builds use SDL 3 for controllers on Windows, macOS and Linux [source: https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html].
- Android and web still use Godot's own code, and the docs say web controller support varies widely across browsers [source: https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html].
- Vibration uses `Input.start_joy_vibration` and `stop_joy_vibration` [source: https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html].
- Keyboard and gamepad map to the same InputMap actions, so "equal" input support is mostly UI work: glyphs and rebinding [inferred].

## 11. Distribution
- **itch.io:**
  - HTML5 zips are limited to 1,000 files, 500 MB extracted and 200 MB per file.
  - The CDN gzips wasm and pck files automatically, and `.br` files are served as brotli [source: https://itch.io/docs/creators/html5].
  - A 39.5 MB wasm fits easily [inferred].
  - I could not find itch.io documentation on its SharedArrayBuffer option, so a threaded build there is unverified. The no-threads default avoids the question [inferred].
- **Steam:** see section 3. The Linux build doubles as the Deck build [inferred].
- **GitHub Releases:** each file must be under 2 GiB, with no limit on total release size or bandwidth [source: https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases].

## 12. Cel-shaded, low-poly, procedural
Details are in `pipeline.md`. Godot has, built in:
- runtime mesh building (SurfaceTool, ArrayMesh);
- toon diffuse and specular modes;
- outlines through vertex "grow" with a front-culled second pass, or the experimental stencil outline preset [source: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/BaseMaterial3D.xml].

## 13. Not verified (gaps)
- Cross-platform bit-equality of the GDScript sim: not run on Linux, macOS, ARM, Android or web.
- Whether a no-threads GDExtension web build really needs COOP/COEP. The docs say yes. Not tested.
- Which Emscripten version a GDExtension (godot-cpp or gdext) side module needs to load into the official 4.7.2 web templates (built with 4.0.20). Not tested.
- Real audio latency of web builds, in Sample mode (the default) and in Stream mode, with and without threads. Not measured.
- Which GPU a `gl_compatibility` run actually uses on this hybrid machine, and whether a Windows graphics preference moves it to the iGPU. Not tested (changing that preference is a system setting, so it is for Orb or the director).
- How issue #112976 was resolved.
- Steamworks SDK licence terms for open-source repos: needs Legal.
- itch.io SharedArrayBuffer option.
- Size of a stripped custom web template.

## Local measurements
All commands were run on 2026-09-29 on the spike machine (Windows 11, Godot 4.7.2 official). Scratch files are in the session scratchpad, not the repo.

**M1: template sizes and compression**
```
$ ls -la "$APPDATA/Godot/export_templates/4.7.2.stable"      (excerpt)
 10245903 web_nothreads_release.zip   10290815 web_release.zip   11549046 web_dlink_nothreads_release.zip
109268480 windows_release_x86_64.exe  73519416 linux_release.x86_64  123597580 macos.zip
104803333 android_release.apk         202976946 ios.zip
$ unzip -l web_nothreads_release.zip        -> godot.wasm 39514754, godot.js 279815
$ unzip -l web_release.zip                  -> godot.wasm 38820072
$ unzip -l web_dlink_nothreads_release.zip  -> godot.wasm 1508095, godot.side.wasm 44078870
$ gzip -9 -c godot.wasm | wc -c   -> 10084297
$ brotli -c godot.wasm | wc -c    -> 6902599
```
**M2: headless web export of a minimal 3D project** (Compatibility, default Web preset, `variant/thread_support=false`)
```
$ Godot_v4.7.2-stable_win64_console.exe --headless --path <scratch>/gd-webcheck --export-release "Web" <scratch>/gd-webcheck/out/index.html
[ DONE ] savepack        real 0m2.570s
out/: index.wasm 39514754, index.pck 2392, index.js 279815, index.html 5436 (+ worklets, icons)
GODOT_CONFIG = {... "ensureCrossOriginIsolationHeaders":true, ... "fileSizes":{"index.pck":2392,"index.wasm":39514754}
GODOT_THREADS_ENABLED = false
sha256(index.wasm) = sha256(web_nothreads_release.zip:godot.wasm) = fc74679e3b97f768...
```
**M3: number widths in the official build**
```
$ Godot_v4.7.2-stable_win64_console.exe --headless --path <scratch>/gd-webcheck -s res://probe.gd
version=4.7.2-stable (official)
feature single=true double=false
Vector2(0.1,0).x == 0.1 -> false ; error=0.00000000149012
float: 0.1+0.2 == 0.30000000000000004 -> true
int: 9223372036854775807 + 1 -> -9223372036854775808
```
**M4: reference tests** (the target every port reproduces)
```
$ node research/engine-spike/shared/test-ref.mjs --bench
PASS terrainBase c3a0b914...  PASS worst@1980 19a92e5c...  (16 golden PASS lines, 6 camera PASS lines)
SIMBENCH {"stack":"node v24.19.0","reps":5,"ticks":3600,"terrainGenMs":0.176,"worstTickUs":0.362}
all reference checks passed
```
The SIMBENCH figures are a smoke run on a busy machine, not final numbers.

**M5: Windows binaries (compiler and GPU-preference exports)**
```
$ cd "$APPDATA/Godot/export_templates/4.7.2.stable"
$ grep -a -o "GCC: ([^)]*) [0-9.]*" windows_release_x86_64.exe | sort -u
GCC: (GNU) 15.1.1
GCC: (GNU) 15.2.1
GCC: (MinGW-W64 x86_64-msvcrt-posix-seh, built by Brecht Sanders, r7) 15.2.0
GCC: (x86_64-posix-seh-rev0, Built by MinGW-Builds project) 15.2.0
$ grep -a -o "NvOptimusEnablement\|AmdPowerXpressRequestHighPerformance" windows_release_x86_64.exe | sort | uniq -c
      1 AmdPowerXpressRequestHighPerformance
      1 NvOptimusEnablement
$ (same grep on Godot_v4.7.2-stable_win64.exe, the editor)   -> both symbols, once each
$ (same grep on Godot_v4.7.2-stable_win64_console.exe)       -> neither (a 198,152 B wrapper, not the engine itself)
```
