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

| ID | Component | Version | Licence | What we must do | Status | Source and checked on |
|---|---|---|---|---|---|---|
| LR-001 | Godot Engine (runtime and export templates) | 4.7.2 | MIT | Give players Godot's licence text and copyright notice, plus the third-party licences the engine lists, in a credits or licences screen, or in a file that ships with the game. Godot has calls that produce these (`Engine.get_license_text()`, `Engine.get_license_info()`, `Engine.get_copyright_info()`). Our own game's licence is independent of Godot's. Copyright: Godot Engine contributors (2014 onwards), Juan Linietsky and Ariel Manzur (2007 to 2014). | Candidate. ADR 0001 waits for Orb. 4.7.2 is installed on the dev machine, checksum-verified (EP playbook). | [Godot licence](https://godotengine.org/license/), [complying with licences](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html); checked 2026-09-28 |
| LR-002 | Third-party libraries built into Godot | as bundled with 4.7.2 | Various, mostly permissive (MIT, BSD, Apache-2.0, zlib and others) | Covered by the same licences screen as LR-001. Nothing to add by hand. Check that the screen really appears in each build. | Candidate | same pages as LR-001; checked 2026-09-28; the full list is read from the engine build |
| LR-003 | Godot .NET build (only if C# is chosen) | .NET 10 | MIT | Adds Microsoft's .NET runtime, and any NuGet packages, to the shipped build. Register each package when added. | Not chosen. The .NET 10 SDK is installed on the dev machine. | not checked; verify when C# is chosen |
| LR-004 | Fonts | none bundled | n/a | The prototype's CSS names Barlow, Barlow Condensed, Segoe UI, Arial Narrow and Impact but bundles none of them, so players see system fonts. If a font is bundled later, register it first. Barlow is published under the SIL Open Font Licence (verify when registering). | No obligation today | not checked; verify if a font is bundled |
| LR-004a | Open Sans (Godot's built-in fallback font, `thirdparty/fonts/OpenSans*.woff2`) | as bundled with 4.7.2 | OFL-1.1, "2020, The Open Sans Project Authors" | Covered by LR-001 and LR-002. It is the only font in a build until a font is bundled. Do not sell the font on its own, and keep its notice with it. | Accepted. Read from Godot's COPYRIGHT.txt on 2026-09-29; the fetched text did not show the tag, so confirm on the 4.7.2 source before release |
| LR-005 | Art, audio, music | none | n/a | The prototype draws everything in code and has no audio. | Nothing to register yet | n/a |

### A2. Development tools that never ship

| ID | Component | Version | Licence | What we must do | Status | Source and checked on |
|---|---|---|---|---|---|---|
| LR-010 | Node.js | 24 (installed) | MIT. Bundled parts include V8 (BSD-3-Clause), OpenSSL (Apache-2.0), ICU (Unicode-3.0) and others. | Runs the headless sim and QA tools on dev machines. Nothing to do while we do not redistribute Node. If a CI image or installer bundles it, keep Node's LICENSE file with it. | Accepted, dev only | [Node.js LICENSE](https://raw.githubusercontent.com/nodejs/node/main/LICENSE); checked 2026-09-28 |
| LR-011 | npm | bundled with Node | Artistic-2.0 | Dev use only. Nothing to do. | Accepted, dev only | [npm registry](https://registry.npmjs.org/npm/latest); checked 2026-09-28 |
| LR-012 | @napi-rs/canvas (optional dependency in `prototype/package.json`) | `*` in package.json (unpinned). 1.0.9 was the latest on the npm registry on 2026-09-28. | MIT | Optional. Used only by `prototype/tools/headless.js` and `screenshot.js` to draw PNG snapshots. Not shipped. If we ever redistribute it, keep its MIT notice and the Skia notice (LR-013). Pin an exact version and commit a lockfile (Tools). | Accepted, dev only | [npm registry](https://registry.npmjs.org/@napi-rs%2fcanvas/latest); checked 2026-09-28 |
| LR-013 | Skia graphics library, built into the @napi-rs/canvas binaries | as bundled | BSD-3-Clause (Google) | Same as LR-012. No action while dev only. | Accepted, dev only | not fetched; BSD-3-Clause per Skia project, verify |
| LR-014 | @napi-rs/canvas platform binary packages (for example `@napi-rs/canvas-win32-x64-msvc`) | same as LR-012 | Expected to match the main package (MIT). Not checked package by package. | Same as LR-012. | Accepted, dev only | not checked |
| LR-015 | Python 3 | installed | PSF-2.0 | Runs `tools/gen_directors.py`, which uses only the standard library (`os`, `textwrap`). Dev use only. | Accepted, dev only | not fetched; verify |
| LR-016 | Git, GitHub CLI, Claude Code | installed | Git: GPL-2.0-only. GitHub CLI: MIT. Claude Code: Anthropic's own terms. | Development tools. Not shipped. For the terms on AI output see `licence-recommendation.md`, section 8. | Accepted, dev only | not fetched; verify |

### A3. Planned for P0, not chosen yet

Each needs a row before it is used.
- CI (Tools): GitHub Actions and every action it calls (checking out code, setting up Node, installing Godot). Each action, and any Godot CI image, is a third-party component.
- A data-schema validator (Tools), such as a JSON Schema library, when chosen.
- Anything else Tools or Simulation add.
- **Pending rows (facts needed from Tools):**

| ID | Component | Licence | Status |
|---|---|---|---|
| LR-020 | actions/checkout v7.0.1 @ 3d3c42e5aac5ba805825da76410c181273ba90b1 (CI only) | MIT | accepted, dev only. Licence read from the GitHub licence API 2026-09-29 (version and commit as reported by the EP) |
| LR-021 | actions/setup-node v7.0.0 @ 820762786026740c76f36085b0efc47a31fe5020 (CI only) | MIT | accepted, dev only. Same source and date |
| LR-022 | JSON Schema validator | unknown | pending: only if Tools uses one |
| LR-024 | Godot 4.7.2 export templates (Research), Godot 4.7.2 .NET editor and templates (scratch use), Godot 4.7.2 Linux zip in the CI parity job | MIT | accepted, dev and CI only; not in the repo. Licence per LR-001. Checksums as reported by Research |
| LR-025 | TypeScript 7.0.2 via npx (optional type-check) | Apache-2.0 | accepted, dev only. Registry read 2026-09-29 |
| LR-023 | @napi-rs/canvas 1.0.9 (pinned, commit 2faf2b1) | MIT (see LR-012) | accepted, dev only. Lockfile status still to confirm |

- Later, if Steam becomes a target: the Steamworks SDK and any wrapper for it. The SDK is not open source and has its own terms, so keep its files out of the public repo until Legal has read them.

## Part B: asset origins

The origin log for every shipped asset is now `asset-origins.md` (rules, template, status vocabulary). This part is only a pointer.

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

1. There is no LICENSE file in the repo. The EP placed MIT and CC BY 4.0 files and then removed them (commit 3166470, 2026-09-29) while Orb decides the licence, so the repo is all rights reserved by default. The drafts in `drafts/` are unchanged and still match pairing 1. If Orb picks another licence, Legal redrafts. Do not make the repo public without a licence file.
2. `@napi-rs/canvas` is now pinned to 1.0.9 (LR-023). Still to confirm: that a lockfile is committed, and whether a JSON Schema validator (LR-022) is used.
3. The prototype code and the docs were written with AI assistance. The provenance policy is in `licence-recommendation.md`, section 8.
4. Godot's licences screen has to be planned into the UI (P5).
5. Each row's Source column shows what was actually read. "Not fetched" means the licence is from general knowledge and must be verified before it is relied on.
