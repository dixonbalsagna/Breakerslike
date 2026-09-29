# csharp/: the C# build of the engine spike

Throwaway spike code for ADR 0001 (research/ only; nothing outside research/ may import it). Two parts:

| Folder | What it is |
|---|---|
| `SimPort/` | A .NET 10 console port of `shared/sim-ref.mjs`, `shared/camera-ref.mjs` and the checks in `shared/test-ref.mjs`. It has no NuGet packages. |
| `godot-web-probe/` | The smallest Godot 4.7 C# project (one script, one scene, three export presets). It is used to ask the official .NET editor whether it will export C# to the Web. |

The verdict, sources, SIMBENCH comparison, determinism facts and download ledger are in **`../notes/csharp.md`**.

**Verdict in one line:** Godot 4.7.2 cannot export C# to the Web (unsupported, refused by the editor, no date), and C# on Android and iOS is officially experimental.

There is no demo, bench mode or screenshots here. The C# build is a headless sim port plus an export probe, not a renderer. The SPEC's render, bench and screenshot items belong to `godot/` and `web/`.

## How to run

All commands run from the repo root.

**Tests**: the goldens, the flight-input replay and the 6 camera seam tests. Exit code 0 means everything passed; 1 means something failed:
```
dotnet run -c Release --project research/engine-spike/csharp/SimPort
```

**Tests plus SIMBENCH**: the median µs per `worst` tick over 3600 ticks × 5 reps, plus the terrain generation time:
```
dotnet run -c Release --project research/engine-spike/csharp/SimPort -- --bench
```

Options:
- `--reps N` sets the number of SIMBENCH reps.
- `--golden <path>` points at a different golden.json. By default the program finds `research/engine-spike/shared/golden.json` by walking up from the binary and the working directory.
- The JIT can be switched through the environment, for example `DOTNET_TieredCompilation=0`. The SIMBENCH line records any such variables in `jitEnv`.

**Probe**: needs the Godot 4.7.2 .NET editor. Its console exe is at `C:\Users\itsha\AppData\Local\Programs\Godot\4.7.2-mono\Godot_v4.7.2-stable_mono_win64\`, and it runs self-contained because of the `_sc_` marker file.
```
cd research/engine-spike/csharp/godot-web-probe
dotnet build WebProbe.csproj                        # offline: nuget.config points only at the editor's bundled nupkgs
<mono>/Godot_v4.7.2-stable_mono_win64_console.exe --headless --path .                                   # prints one line and quits
<mono>/Godot_v4.7.2-stable_mono_win64_console.exe --headless --path . --export-release Web <abs>/index.html   # fails: see notes
```

## What passed (2026-09-29)

`dotnet run -c Release --project research/engine-spike/csharp/SimPort -- --bench` exited 0. The output below is shortened: each hash line is identical to `shared/golden.json`.
```
PASS terrainBase c3a0b9144b0e7f2550710ff8d12e3330efb37ce63c9b5394067031198ee83f9a
PASS worst@600 89f7458495…  PASS worst@1980 19a92e5cae…  PASS worst@3600 463ca3deba…
PASS flight@600 43c587a678…  PASS flight@1800 8745c90ad6…  PASS flight@3600 1e38eeae2e…
PASS flight-input@600 41f72fd0f9…  PASS flight-input@1800 134e02d195…  PASS flight-input@3600 907584896d…
PASS camera.sweep@3600 fd570acb…  camera.chase a451a2c8…  camera.orbit 1b8858a2…  camera.climb 54954fb7…  camera.flight b85e9e49…  camera.worst 54e46496…
PASS camera {"scene":"sweep","ticks":3600,"seamCrossings":19,"flips":19,"flipTicks":741,"outOfFrameTicks":0,"outOfFrameDuringFlip":570,"maxScreenJump":0.01796,"maxSeamOffsetDiff":5.10702591327572e-15,"pass":true}
PASS camera {"scene":"chase",...}  PASS camera {"scene":"orbit",...}  PASS camera {"scene":"climb",...}  PASS camera {"scene":"flight",...}  PASS camera {"scene":"worst",...}
SIMBENCH {"stack":"dotnet 10.0.12 x64","reps":5,"ticks":3600,"terrainGenMs":0.28,"worstTickUs":0.715,...}
all reference checks passed
```

Further checks:
- Apart from the SIMBENCH line, stdout is **byte-identical** to `node research/engine-spike/shared/test-ref.mjs`. I checked this with `diff`. Numbers are printed with JavaScript's `Number#toString` rules, including `+x.toFixed(5)`.
- The same 22 PASS lines and exit 0 appear under `DOTNET_TieredCompilation=0`, `DOTNET_TieredPGO=0`, `DOTNET_TC_QuickJitForLoops=0` and `DOTNET_EnableAVX2=0`.
- SIMBENCH numbers are smoke only, taken on a shared machine. The comparison table is in `../notes/csharp.md`.

## How it was built

- **`Sim.cs`** ports the wrap math (`Wrap`, `Sdx`, `Tri`), mulberry32 (`Rng`, `unchecked` uint multiply for `Math.imul`), terrain generation (value noise, a 25-tap smoothing pass, biome segments), craters, fighters, beams and the six scenes.
  - The expressions are the reference's, in the same order. Every real is a `double`.
  - Only `+ - * /`, `Math.Floor`, `Math.Ceiling` and `%` (C fmod) are used. There is no `Math.Sin`/`Cos`/`Pow`, and no `Math.FusedMultiplyAdd` or `MultiplyAddEstimate`.
  - Ints are widened to double exactly where JS holds them as doubles.
- **`Camera.cs`** ports the continuous arc, the hysteresis flip, the capped pan and the floating origin. It reads sim state and never writes it, and it is stepped once per tick after the sim. `tan(20°)·16/9` is a precomputed literal, so no libm call is needed.
- **`Program.cs`** ports `test-ref.mjs`:
  - goldens, including `flight-input` with `ScriptedInput(n)` called before each step;
  - camera seam tests at the offsets 0.5, 1234.5, 4800, 9599.75 and 7777.77;
  - SIMBENCH.
  - Hashing is `BinaryPrimitives.WriteDoubleLittleEndian` followed by `SHA256.HashData`.
  - It never writes `golden.json`, because the goldens belong to the reference.
- **`SimPort.csproj`**: net10.0, `InvariantGlobalization`, overflow checks off, warnings as errors, no `PackageReference` (`project.assets.json` lists 0 libraries).
- **`godot-web-probe/`**: `project.godot` (Compatibility renderer), `WebProbe.csproj` (`Godot.NET.Sdk/4.7.2`, net10.0), `nuget.config`, `Main.cs`, `main.tscn` and `export_presets.cfg` (Web, Windows Desktop, Android).
  - `nuget.config` uses `<clear/>` plus the editor's bundled nupkgs folder, so the restore is offline and never contacts nuget.org.
  - `Main.cs.uid` was generated by the editor. `.godot/` is gitignored, and the build output goes there.

## Determinism notes (summary; sources in ../notes/csharp.md)

- **Verified on x64 CoreCLR:** bit-identical to V8 across all 16 goldens, with every JIT tier, with and without PGO, and with and without AVX2.
- **Sourced:**
  - The C# spec allows extra intermediate precision, but on x64 and ARM64 there is no wider type to use (the ARM64 half is an inference).
  - The .NET team treats implicit FMA contraction as a value-changing optimization it does not do; fusion is opt-in only.
  - `Math.Sin` and the other transcendentals go through the platform C runtime and may differ between OSes and architectures, which is why the contract bans them.
- **Not verified:**
  - ARM64;
  - Mono (Godot's Android runtime);
  - NativeAOT (Godot's iOS runtime);
  - the C# sim running inside Godot's hosted runtime. The probe only proves C# runs there, not the sim.

## Export notes

- **Web:** refused by the .NET editor before any template lookup, with exit code 1. The message is *Exporting to Web is currently not supported in Godot 4 when using C#/.NET.* The full output is in the notes.
- **Windows Desktop:** the only blocker was missing .NET export templates, which were not downloaded.
- **Android:** the editor says the export is experimental, and the 4.7.2 template only supports `net9.0`. A net10.0 project needs a Gradle build.
- **iOS:** needs macOS. Not testable here.

## Tooling observations

- The official .NET editor zip is self-contained apart from the .NET SDK. It ships its NuGet packages as local `.nupkg` files, so an offline, reproducible restore works with a project-local `nuget.config`.
- The `_sc_` marker file keeps the editor's settings and templates beside the exe. Running it did not change the user's `%APPDATA%\NuGet\NuGet.Config`; its SHA-256 was the same before and after.
- `dotnet run -c Release` takes a few seconds to build. The full check suite then runs in well under a minute.
- Default tiered JIT makes short benchmarks noisy: a visible tier-up spike on rep 3, and about 2.5x slower than `TieredCompilation=0` for this sim. A shipped Godot C# game would want ReadyToRun or tiering settings reviewed.

## Dependencies (EP amendment (c))

- `SimPort`: **none** beyond the .NET 10 shared framework.
- `godot-web-probe`: Godot.NET.Sdk, GodotSharp, GodotSharpEditor and Godot.SourceGenerators, all **4.7.2**, **MIT** licence.
  - Source: the official `Godot_v4.7.2-stable_mono_win64.zip` (`GodotSharp/Tools/nupkgs`), SHA-512 verified.
  - Restored into `%TEMP%\meridian-spike-nuget`, outside the repo.
- No npm packages.

## Known gaps

- No C# build was actually exported, for any platform. Following the brief, the .NET export templates (about 1.3 GB) were not downloaded once the docs said web is unsupported.
- The official C# web prototype (draft PR #106125) was not built. That would mean compiling Godot with Emscripten plus the .NET `wasm-tools` workload.
- Running the C# sim on the web through .NET's own `browser-wasm` runtime, outside Godot, was not tested.
- Determinism was not checked on ARM64, Mono or NativeAOT, which are the runtimes Godot C# uses on mobile.
- The GDScript SIMBENCH comparison has a placeholder. `godot/tests/README.md` did not exist when this was written.
- All benchmark numbers are smoke runs on a shared machine.
