# C# in the engine spike: Godot 4.7 .NET platforms, the C# sim port, and determinism

Owner: Research & Prototyping (engine spike, ADR 0001). Written 2026-09-29. Every source below was accessed on 2026-09-29.
Build details and how to run things are in `research/engine-spike/csharp/README.md`.

## Verdict

**Godot 4.7.2 cannot export a C# (.NET) project to the Web: it is officially unsupported, the .NET editor refuses the export, and there is no committed date. Android and iOS C# exports exist but are officially "experimental".**

What this means for Orb's criteria (browser, mobile and old laptops are all weighted heavily):
- A game written in Godot C# today has **no browser build**. The mobile builds are experimental.
- A GDScript (or C++ GDExtension) Godot project has none of these blocks. The GDScript port of the sim already matches the goldens (see `godot/`).
- If a C# core is still wanted, it would have to wait for official web support, which has no date. The alternative is to keep a second, non-C# copy of the core for the web build. Both are real costs for a web-first minimum spec. Details are under "What a C# core would mean if web matters".

## Evidence: primary sources

Quotes are verbatim and under 15 words. Everything else is paraphrased.

### Official Godot documentation (4.7 branch)
1. **C#/.NET index, section "C# platform support"**: https://docs.godotengine.org/en/4.7/tutorials/scripting/c_sharp/index.html
   - "Currently, projects written in C# cannot be exported to the web platform."
   - "Android support is currently experimental."
   - "iOS support is currently experimental and has a few limitations."
   - Also: the iOS simulator templates are x64 only, and iOS export needs a macOS machine.
   - The same text is on `/en/stable/` (the stable docs currently show version 4.7).
2. **Exporting for the Web**, "Attention" box: https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html
   - "Projects written in C# using Godot 4 currently cannot be exported to the web."
   - It tells C# users to use Godot 3 for the web. It links the 4.2 blog post (source 4) for the reason.
3. **C# basics**, Introduction: https://docs.godotengine.org/en/4.7/tutorials/scripting/c_sharp/c_sharp_basics.html
   - "Android and iOS platform support is available as of Godot 4.2, but is experimental"
   - Desktop .NET export (Windows, Linux, macOS) has been supported since 4.0.

I checked sources 1 to 3 twice: once with WebFetch, and once with `curl` plus `grep` of the raw HTML for the exact sentences.

### Godot blog and release notes
4. **"Platform state in C# for Godot 4.2"**, Raul Santos (.NET lead), 26 January 2024: https://godotengine.org/article/platform-state-in-csharp-for-godot-4-2/
   - This is the root cause, and it still applies. Godot's web build is the main WASM module and loads extensions as side modules.
     - ".NET expects to be the main entry point and doesn't support dynamic linking".
     - The .NET runtime "can only be built as a main module".
   - Android uses the linux-bionic Mono runtime. At the time, missing Android bindings made some APIs (such as SSL) crash. That is the reason for the experimental label.
   - iOS uses NativeAOT. Trimming conflicts with Godot's use of reflection, and export needs a Mac.
5. **"Live from GodotCon Boston: Web .NET prototype"**, 9 May 2025: https://godotengine.org/article/live-from-godotcon-boston-web-dotnet-prototype/
   - dotnet.js, NativeAOT-LLVM and a first static-linking attempt all failed. A later attempt that statically links the Mono WASM runtime into Godot worked as a prototype.
   - Caveats in the article:
     - The C# project must match the template's WASM features (threads, exceptions, SIMD) and its TargetFramework.
     - Only invariant globalization is supported.
     - Some browser-dependent .NET APIs will not work.
     - The prototype's .pck was 72 MiB, or 23.8 MiB with Brotli.
   - The team said it could not commit to a timeline. It hoped for "the next Godot release". That would have been 4.5, and 4.5, 4.6 and 4.7 have since shipped without it.
6. **Release pages**:
   - 4.4 (https://godotengine.org/releases/4.4/) moved C# to .NET 8 and extended Android C# to all ABIs.
   - 4.5 (https://godotengine.org/releases/4.5/) loads .NET assemblies directly from the APK on Android. It also mentions "our ongoing efforts towards bringing C#/.NET to GDExtension".
   - 4.6 (https://godotengine.org/releases/4.6/) adds C# translation parsing only.
   - **4.7** (https://godotengine.org/releases/4.7/ "Lights, Camera, Action!") **does not mention C# or .NET at all**. I fetched the page and grepped its text for "C#", ".NET" and "dotnet": no matches.

### GitHub (godotengine/godot)
State read from the GitHub REST API on 2026-09-29.
7. **Issue #70796**, "Readd support for web platform exports when using the C# (.NET) version of the engine": https://github.com/godotengine/godot/issues/70796
   - **Open**. No milestone. 116 comments. Opened 2023-01-01.
   - On **2026-06-19**, akien-mga (Godot project manager, MEMBER) locked the issue because it was attracting AI-generated spam. He said the Foundation is evaluating solutions for C# web support and is not interested in outside attempts for now.
8. **PR #106125**, "[.NET] Add web export support", by raulsntos: https://github.com/godotengine/godot/pull/106125
   - **Open, draft**, milestone 4.x. Opened 2025-05-06. Last updated 2026-09-14.
   - Approach: statically link the Mono WASM runtime. It needs the `wasm-tools` workload and invariant globalization, and the exported JS still has to be edited by hand.
   - Calinou (MEMBER) wrote on 2025-08-19: "any new features can only be merged in 4.6 at the earliest". It was not merged in 4.6 or 4.7.
9. **PR #99508**, "mono/wasm: Initial WebAssembly support for C# projects": https://github.com/godotengine/godot/pull/99508
   - Open, draft, labelled "needs work". Reviewers called it skeletal.
   - It is not a viable route.

**Roadmap summary.** No official release carries C# web export. The only official work is a draft PR (#106125, Mono WASM statically linked into the web template), open for nearly 17 months. Since June 2026, the Godot Foundation's public position has been that it is "evaluating solutions" (my paraphrase of source 7), with no date. Separately, the long-term plan to move C# onto GDExtension (source 6, 4.5 notes) is the other structural change that could eventually allow it. Both are unreleased and undated.

## Evidence: empirical (this machine, 2026-09-29)

Setup:
- Official `Godot_v4.7.2-stable_mono_win64.zip`, SHA-512 verified (see the ledger). It runs in self-contained mode (a `_sc_` file beside the exe), so it did not touch `%APPDATA%\Godot`, which the other Godot agents use.
- The probe is `research/engine-spike/csharp/godot-web-probe/`: one C# script, one scene, three export presets (Web, Windows Desktop, Android).
- It was built with plain `dotnet build`, offline. The only NuGet source is the editor's bundled `GodotSharp/Tools/nupkgs`.

```
$ dotnet build WebProbe.csproj -c Debug -nologo            (NUGET_PACKAGES=%TEMP%\meridian-spike-nuget)
  Restored ...\godot-web-probe\WebProbe.csproj (in 202 ms).
  WebProbe -> ...\godot-web-probe\.godot\mono\temp\bin\Debug\WebProbe.dll
Build succeeded.  0 Warning(s)  0 Error(s)

$ Godot_v4.7.2-stable_mono_win64_console.exe --headless --path .          (runs the scene on desktop)
Godot Engine v4.7.2.stable.mono.official.ed1daf0bf - https://godotengine.org
WebProbe C# ok: runtime=.NET 10.0.12 os=Windows wrap(-0.25)=9599.75
exit=0
```

**Web export** (the decisive check). Exit code 1, and no files were written:
```
$ Godot_v4.7.2-stable_mono_win64_console.exe --headless --path . --export-release Web <scratch>/web/index.html
Godot Engine v4.7.2.stable.mono.official.ed1daf0bf - https://godotengine.org
[ first_scan_filesystem progress lines trimmed ]
ERROR: Cannot export project with preset "Web" due to configuration errors:
Exporting to Web is currently not supported in Godot 4 when using C#/.NET. Use Godot 3 to target Web with C#/Mono instead.
If this project does not use C#, use a non-C# editor build to export the project.

   at: _fs_changed (editor/editor_node.cpp:1401)
ERROR: Project export for preset "Web" failed.
   at: _fs_changed (editor/editor_node.cpp:1417)
exit=1
```
This is a hard check in the .NET build of the editor, and it fires before any template lookup. No template download can get past it.

**Windows Desktop export** (control). Exit code 1. The only error is missing templates, so desktop C# export is not blocked:
```
ERROR: Cannot export project with preset "Windows Desktop" due to configuration errors:
No export template found at the expected path:
C:/Users/itsha/AppData/Local/Programs/Godot/4.7.2-mono/Godot_v4.7.2-stable_mono_win64/editor_data/export_templates/4.7.2.stable.mono/windows_debug_x86_64.exe
No export template found at the expected path:
.../4.7.2.stable.mono/windows_release_x86_64.exe
ERROR: Project export for preset "Windows Desktop" failed.
```

**Android export** (control). Exit code 1. The editor itself labels the export experimental, and it pins the .NET version:
```
ERROR: Cannot export project with preset "Android" due to configuration errors:
Exporting to Android when using C#/.NET is experimental.
C# project targets 'net10.0' but the export template only supports 'net9.0'. Consider using gradle builds instead.
ERROR: Project export for preset "Android" failed.
ERROR: EditorSettings not instantiated yet when getting setting "export/android/shutdown_adb_on_exit".
```
In 4.7.2 the prebuilt Android .NET template is built for net9.0, so a net10.0 project needs a Gradle build. The probe targets net10.0 because this machine has only the .NET 10 targeting pack. The last error line is a harmless headless quirk.

**Not done, by design.** Following the brief, I did not download the .NET export templates (`Godot_v4.7.2-stable_mono_export_templates.tpz`, about 1.3 GB), because the docs say C# web export is unsupported. As a result, no C# build was actually exported for Windows or Android, and iOS cannot be tested on Windows.

**Addendum by the Research director (2026-09-29): the official .NET export templates contain no web template.**
- The EP asked for a test rather than the docs, so the director downloaded `Godot_v4.7.2-stable_mono_export_templates.tpz`:
  - source: https://github.com/godotengine/godot/releases/download/4.7.2-stable/;
  - size: 1,202,598,411 bytes;
  - SHA-512 `bb5c41d7…2ff6bd5a`, which matches `SHA512-SUMS.txt`.
- The director then listed its contents. It holds 27 files:
  - `android_{debug,release}.apk`, `android_source.zip`, `ios.zip`;
  - `linux_{debug,release}.{arm32,arm64,x86_32,x86_64}`, `macos.zip`;
  - `windows_*` for arm64, x86_32 and x86_64;
  - `icudt_godot.dat`, `version.txt`.
- It contains **no `web_*.zip` at all**. The standard 4.7.2 templates ship eight web variants (`web_{,dlink_,nothreads_,dlink_nothreads_}{debug,release}.zip`).
- So even past the editor's hard refusal, a C# web export has no runtime to package. The file stays in the director's scratch folder and is not installed or committed.

## What a C# core would mean if web matters

The options, from cheapest to most expensive:
1. **No C# in the shipped game.**
   - Write the sim core in GDScript, which is already bit-exact to the reference (see `godot/`), or in C++ through GDExtension.
   - Godot web export works for both. GDExtension on the web needs the "extensions support" (dlink) web template variant.
   - Only this option keeps one codebase for all of Orb's platforms today.
2. **C# core with a separate web build.**
   - Ship Godot C# on desktop and (experimental) mobile.
   - The web build uses a second implementation of the core: GDScript in a GDScript-only Godot project, or TypeScript in the web stack.
   - Cost: two cores to keep bit-identical forever. The goldens in `shared/` make that checkable, but not free.
   - The .NET browser runtime (`browser-wasm`, as in Blazor) could run the C# sim inside the web stack. That is **untested here**, and it adds several MB of runtime to the download.
3. **Wait for Godot's own C# web support.**
   - The route is PR #106125 or a GDExtension-based C#. There is no date, and the Foundation says it is still evaluating options.
   - Even the working prototype had a 72 MiB .pck (23.8 MiB with Brotli). That is a large download for "old laptops and browser" before any game content.
   - It also requires the C# project to match the template's WASM feature set exactly.
4. **Build the fork yourself.**
   - Take #106125 or a community libgodot fork, build Godot with Emscripten and the `wasm-tools` workload, and maintain it. The draft still needs manual edits to the exported JavaScript.
   - That is too heavy for a zero-budget team and is not recommended.

The same pattern applies to mobile. Godot C# on Android and iOS works but is labelled experimental. Android is pinned to the template's .NET version (net9.0 in 4.7.2). iOS needs a Mac and NativeAOT, whose trimming conflicts with Godot's reflection (source 4).

## SIMBENCH: C# versus Node versus GDScript

These are smoke numbers only. The machine is shared with other agent sessions, so they are not final. They are the median µs per `worst` tick over 3600 ticks × reps, plus the terrain generation time. The final runs belong to the Research director on a quiet machine.

| Stack | Command | terrainGenMs | worstTickUs | Per-rep worstTickUs |
|---|---|---|---|---|
| Node v24.19.0 (V8) | `node shared/test-ref.mjs --bench` | 0.172 | **0.375** | (not printed) |
| .NET 10.0.12 x64, default tiered JIT | `dotnet run -c Release --project csharp/SimPort -- --bench` | 0.28 | **0.715** | 0.7, 0.721, 2.717, 0.715, 0.707 |
| same, 15 reps | `SimPort.exe --bench --reps 15` | 0.186 | 0.591 | 0.62 … 0.578 (one 2.327 tier-up spike) |
| same, `DOTNET_TieredPGO=0`, 15 reps | | 0.162 | 0.624 | drifted 0.44 → 0.65 during the run (machine noise) |
| .NET, `DOTNET_TieredCompilation=0` (full JIT at once) | `SimPort.exe --bench` | 0.147 | **0.265** | 0.394, 0.316, 0.265, 0.264, 0.265 |
| GDScript (Godot 4.7.2), editor build | final runs, `results/final/summary.md` | 4.14 | **9.07** | median of 3 runs |
| GDScript (Godot 4.7.2), release template | `build/win/spike.exe --headless -- --simbench` | 3.12 | **6.60** | median of 3 runs |

The two GDScript rows were filled in by the Research director from the final runs (2026-09-29). The same final runs put Node at 0.37 and default-tiered .NET at 0.61.

Reading:
- With tiering off, the C# sim is about 1.4x faster than V8 per tick. With default tiering it is about 1.6 to 1.9x slower in these short runs. Tier-up and on-stack replacement dominate a 3600-tick run.
- Either way, a worst-scene tick costs well under 1 µs against a 16,667 µs frame, so sim throughput does not decide the engine.
- For Godot C# on desktop, the same CoreCLR tiering applies. ReadyToRun or `TieredCompilation` settings would be the lever. None of that applies to the web, where C# cannot run at all.

## Determinism notes (.NET, for rollback)

Verified empirically on this machine (Ryzen 7 9800X3D, x64, CoreCLR RyuJIT, .NET 10.0.12):
- All 16 goldens (terrainBase, worst, flight and flight-input at three checkpoints each, and 6 camera hashes) are **bit-identical to the Node/V8 reference**. The 6 camera seam tests pass with the same numbers.
- stdout is byte-identical to `test-ref.mjs` apart from the SIMBENCH line (checked with `diff`).
- The results are identical under `DOTNET_TieredCompilation=0`, `DOTNET_TieredPGO=0`, `DOTNET_TC_QuickJitForLoops=0` and `DOTNET_EnableAVX2=0`. Each run gave 22 PASS lines and exit 0. So tier-0, OSR, tier-1 and PGO code, with and without AVX2, all agree on this sim.

Facts that matter for rollback, with sources:
1. **double is IEEE binary64, but the language allows extra precision.**
   - C# spec §8.3.7 says `double` uses the IEC 60559 64-bit format. It also says operations "may be performed with higher precision than the result type".
   - Source: https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/types (§8.3.7).
   - *Inference, not sourced:* on x64 (SSE2 scalar) and ARM64 (scalar FP), RyuJIT has no wider type to use, so each operation is rounded to double. The historic x87 problem was 32-bit .NET Framework. The bit-exact goldens are consistent with this on x64. ARM64 was not tested.
2. **FMA contraction.**
   - The .NET runtime team treats implicit FMA as unacceptable. tannergooding (.NET team, dotnet/runtime MEMBER), 2022-02-03, https://github.com/dotnet/runtime/issues/56855: "implicitly using `fma` is not a safe optimization, it is a value changing optimization". He noted that MSVC only does it under `/fp:fast`.
   - Fusion in .NET is opt-in through `Math.FusedMultiplyAdd` or `MultiplyAddEstimate`. The latter "may return a result that was rounded as one ternary operation" (https://learn.microsoft.com/en-us/dotnet/api/system.numerics.inumberbase-1.multiplyaddestimate). The sim must never call either; `Sim.cs` says so in its header.
   - Empirical: the Zen 5 CPU supports FMA3, yet results match V8 (which does not contract), so RyuJIT did not contract here.
   - *Not verified:* Mono (Godot's Android runtime) and NativeAOT (iOS). These use different code generators. That they also do not contract is an inference.
3. **Math.Sin, Cos, Pow and the other transcendentals are not portable.**
   - Microsoft's docs say `Math.Sin` "calls into the underlying C runtime". The exact result "may differ between different operating systems or architectures" (https://learn.microsoft.com/en-us/dotnet/api/system.math.sin).
   - The spike's contract therefore bans them. A rollback sim needs its own `+ - * /` implementations or lookup tables. The camera's `tan(20°)` is precomputed as a constant for this reason.
4. **The rest of the contract.**
   - `Math.Floor`, `Math.Ceiling` and double `%` (C fmod, truncated and exact) give identical results to JS here.
   - Integer RNG (`Math.imul`) is `unchecked` uint multiplication. `Math.Sqrt` is IEEE correctly rounded.
   - Compile-time constants such as `1.0 / 60.0` fold with IEEE double division to the same value as JS `1 / 60`.
   - All of this is verified only through the goldens, on x64.
5. **Hashing.** State vectors are written with `BinaryPrimitives.WriteDoubleLittleEndian` and hashed with `SHA256.HashData`. These are framework APIs only, with no NuGet packages.

Rollback caveats specific to Godot C#:
- Desktop uses CoreCLR, Android uses Mono, iOS uses NativeAOT, and there is no web runtime at all.
- A cross-platform rollback match would therefore be running three different code generators. Only one of them (CoreCLR x64) was verified here.
- GDScript has one VM on every platform, and its floats are doubles too.

## Download ledger

| File | Source | Size | SHA-512 verified |
|---|---|---|---|
| `Godot_v4.7.2-stable_mono_win64.zip` | https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_mono_win64.zip | 116,582,061 bytes | **Yes.** `79229fd112b0c9cbeab82363a4ef7be18ea70f1caf86bf912789335b136fbe7e01db0053a33461438c5da1c680c17bbb10040bd09bedc51221cd4423d0367757` matches the entry in `C:\Users\itsha\AppData\Local\Programs\Godot\4.7.2\SHA512-SUMS.txt`. Re-hashed with `sha512sum` on 2026-09-29. |

Notes on the ledger:
- The zip was downloaded on 2026-09-28 by the earlier, interrupted run of this task, and is stored outside the repo at `C:\Users\itsha\AppData\Local\Programs\Godot\4.7.2-mono\`.
- It was extracted to `...\4.7.2-mono\Godot_v4.7.2-stable_mono_win64\`. Since then this task has added a `_sc_` marker file and an `editor_data\` folder there, to keep the .NET editor self-contained.
- **Not downloaded:** `Godot_v4.7.2-stable_mono_export_templates.tpz` (SUMS entry `bb5c41d7…`), because the docs say C# web export is unsupported.
- **No NuGet downloads.**
  - The probe restores only from the editor's bundled `GodotSharp\Tools\nupkgs`. Its `nuget.config` uses `<clear/>`, so nuget.org is never contacted.
  - The packages were cached in `%TEMP%\meridian-spike-nuget`: Godot.NET.Sdk, GodotSharp, GodotSharpEditor and Godot.SourceGenerators, all 4.7.2 and MIT (the Godot licence).
  - `SimPort` has no package references (`project.assets.json` lists 0 libraries).
- The user's `%APPDATA%\NuGet\NuGet.Config` is unchanged: SHA-256 `3bdb0505…a7236`, the same before and after.
