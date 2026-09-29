# Licence register

Owner: Legal and IP Compliance. Every third-party component in the repo or planned for P0, with its licence and what we must do about it. Started 2026-09-28. Not legal advice.

## Rules

1. Nothing goes into the repo or a build (library, tool, font, art, sound, music, template, AI-generated asset) until it has a row here. The director who brings it in asks Legal through the EP. Legal accepts or rejects it.
2. Every row records: name and version, where it is used, licence (SPDX identifier), source, what we must do, whether it ships to players, and status.
3. Pin exact versions and commit the lockfile. "Latest" (`*`) is not a version.
4. Development tools that never ship to players can carry any licence, as long as we do not redistribute them.
5. Licences and obligations here are read from each project's own published terms on the date shown. Re-check when a version changes.

## Part A: third-party components

### A1. Would ship to players (only once the engine is confirmed)

| ID | Component | Version | Licence | What we must do | Status |
|---|---|---|---|---|---|
| LR-001 | Godot Engine (runtime and export templates) | 4.7.2 | MIT | Give players Godot's licence text and copyright notice, plus the third-party licences the engine lists, in a credits or licences screen, or in a file that ships with the game. Godot has calls that produce these (`Engine.get_license_text()`, `Engine.get_license_info()`, `Engine.get_copyright_info()`). Our own game's licence is independent of Godot's. Copyright: Godot Engine contributors (2014 onwards), Juan Linietsky and Ariel Manzur (2007 to 2014). | Candidate. ADR 0001 waits for Orb. 4.7.2 is installed on the dev machine, checksum-verified (EP playbook). |
| LR-002 | Third-party libraries built into Godot | as bundled with 4.7.2 | Various, mostly permissive (MIT, BSD, Apache-2.0, zlib and others) | Covered by the same licences screen as LR-001. Nothing to add by hand. Check that the screen really appears in each build. | Candidate |
| LR-003 | Godot .NET build (only if C# is chosen) | .NET 10 | MIT | Adds Microsoft's .NET runtime, and any NuGet packages, to the shipped build. Register each package when added. | Not chosen. The .NET 10 SDK is installed on the dev machine. |
| LR-004 | Fonts | none bundled | n/a | The prototype's CSS names Barlow, Barlow Condensed, Segoe UI, Arial Narrow and Impact but bundles none of them, so players see system fonts. If a font is bundled later, register it first. Barlow is published under the SIL Open Font Licence (verify when registering). | No obligation today |
| LR-005 | Art, audio, music | none | n/a | The prototype draws everything in code and has no audio. | Nothing to register yet |

### A2. Development tools that never ship

| ID | Component | Version | Licence | What we must do | Status |
|---|---|---|---|---|---|
| LR-010 | Node.js | 24 (installed) | MIT. Bundled parts include V8 (BSD-3-Clause), OpenSSL (Apache-2.0), ICU (Unicode-3.0) and others. | Runs the headless sim and QA tools on dev machines. Nothing to do while we do not redistribute Node. If a CI image or installer bundles it, keep Node's LICENSE file with it. | Accepted, dev only |
| LR-011 | npm | bundled with Node | Artistic-2.0 | Dev use only. Nothing to do. | Accepted, dev only |
| LR-012 | @napi-rs/canvas (optional dependency in `prototype/package.json`) | `*` in package.json (unpinned). 1.0.9 was the latest on the npm registry on 2026-09-28. | MIT | Optional. Used only by `prototype/tools/headless.js` and `screenshot.js` to draw PNG snapshots. Not shipped. If we ever redistribute it, keep its MIT notice and the Skia notice (LR-013). Pin an exact version and commit a lockfile (Tools). | Accepted, dev only |
| LR-013 | Skia graphics library, built into the @napi-rs/canvas binaries | as bundled | BSD-3-Clause (Google) | Same as LR-012. No action while dev only. | Accepted, dev only |
| LR-014 | @napi-rs/canvas platform binary packages (for example `@napi-rs/canvas-win32-x64-msvc`) | same as LR-012 | Expected to match the main package (MIT). Not checked package by package. | Same as LR-012. | Accepted, dev only |
| LR-015 | Python 3 | installed | PSF-2.0 | Runs `tools/gen_directors.py`, which uses only the standard library (`os`, `textwrap`). Dev use only. | Accepted, dev only |
| LR-016 | Git, GitHub CLI, Claude Code | installed | Git: GPL-2.0-only. GitHub CLI: MIT. Claude Code: Anthropic's own terms. | Development tools. Not shipped. For the terms on AI output see `licence-recommendation.md`, section 8. | Accepted, dev only |

### A3. Planned for P0, not chosen yet

Each needs a row before it is used.
- CI (Tools): GitHub Actions and every action it calls (checking out code, setting up Node, installing Godot). Each action, and any Godot CI image, is a third-party component.
- A data-schema validator (Tools), such as a JSON Schema library, when chosen.
- Anything else Tools or Simulation add.
- Later, if Steam becomes a target: the Steamworks SDK and any wrapper for it. The SDK is not open source and has its own terms, so keep its files out of the public repo until Legal has read them.

## Part B: asset origins

Every shipped asset needs a recorded origin (the P5 gate). There are none yet. Add one row per asset, or per pack when all files share one origin.

| Asset ID | Path | Type | Origin (human-made, AI-assisted, third-party, public domain) | Author or source | If AI: tool, model, date, prompt location | Licence (SPDX) | Legal review (date, RL id) | Notes |
|---|---|---|---|---|---|---|---|---|
| none yet | | | | | | | | |

## Part C: what Legal accepts

This assumes the code licence recommended in `licence-recommendation.md` (MIT). If Orb picks another licence, Legal updates this section.

**Accepted:** MIT, BSD-2-Clause, BSD-3-Clause, ISC, Apache-2.0, zlib, 0BSD, Unlicense and CC0 (code); CC BY 4.0 and CC0 (art, audio, data); SIL OFL 1.1 (fonts); public domain with proof.

**Accepted with a condition:**
- MPL-2.0: keep the files separate, and ask Legal first.
- LGPL: dynamic linking only, and ask Legal first.
- CC BY-SA 4.0 assets: only if Orb chooses share-alike for our own assets.
- Artistic-2.0, Unicode and similar: fine for tools, ask Legal for shipped code.

**Rejected:**
- GPL and AGPL code in the shipped game, until Orb decides on a copyleft licence and a Steam plan.
- CC BY-NC, CC BY-ND, "free for non-commercial use" and "personal use only" licences.
- Anything with no licence stated (that means all rights reserved).
- Ripped, fan-made or "found" content, and anything from Lemming Ball Z.
- AI output from a tool whose terms bar commercial use, or where the terms are unclear.

## Part D: open items

1. There is no LICENSE file anywhere in the repo. That is fine while it is private, but with no licence the default is "all rights reserved". Orb decides the licence (see `licence-recommendation.md`). Then the EP or Tools adds the LICENSE files and a `license` field to `prototype/package.json`.
2. `@napi-rs/canvas` is unpinned and there is no lockfile. Tools to pin it.
3. The prototype code and the docs were written with AI assistance. The provenance policy is in `licence-recommendation.md`, section 8.
4. Godot's licences screen has to be planned into the UI (P5).
