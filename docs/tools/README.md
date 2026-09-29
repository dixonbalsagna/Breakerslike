# Tools: CI, setup and the web build

Owner: Tools and Pipeline. Free GitHub-hosted runners only, no secrets beyond the built-in Pages token permissions, no paid services.

## One-command setup

From a fresh clone:

| System | Command |
| :--- | :--- |
| Windows | `tools\setup.cmd` (wraps `tools/setup.ps1` and bypasses the execution policy for that one run) |
| Linux, macOS | `sh tools/setup.sh` |

It checks, in order:

1. **Node** (required). Missing or older than 18: it stops with exit 1. Any major other than 24 gives a warning, because the golden hashes were recorded on Node 24.19.0 and are skipped on other majors (ADR 0004), so a pass proves less.
2. **npm** (required, ships with Node).
3. **Godot** (optional today). Looks for `$GODOT`, then `godot` and `godot4` on the path (Windows also tries the `Godot_v4.7.2-stable_win64*.exe` names). Warns if it is missing, is not 4.7.x, or is the .NET build (ADR 0001: standard build, GDScript).
4. **npm dependencies**: `npm ci` in the root, `prototype/`, `sim/` and `qa/`, only where a `package-lock.json` exists. Today only `prototype/` has one: it installs `@napi-rs/canvas` 1.0.9 (optional, MIT), which `prototype/tools/screenshot.js` needs to write a real PNG. The suites do not need it.

Exit 0 means ready, warnings allowed. Exit 1 means a required tool is missing or an install failed. Then run `node qa/run-all.js --quick` (about 40 s) or `npm test --prefix sim`.

## CI

`.github/workflows/ci.yml` runs on every push, pull request and manual run, on `ubuntu-latest`:

| Job | Runs | Time |
| :--- | :--- | :--- |
| `qa` | `node qa/run-all.js` (Node 24.19.0) | about 35 s |
| `sim` | `npm test --prefix sim` (Node 24.19.0) | about 1.5 min |
| `godot-parity` | Godot 4.7.2 headless: import, GDScript parity, render determinism, render seam sweep | about 1 min |
| `site` | Godot Web export, then assembles the Pages site (`tools/build-site.mjs`) | about 2 to 3 min (the 1.28 GB templates download dominates) |
| `deploy` | Publishes the site to GitHub Pages. Only on push (or manual run) on `main`, and only after the four jobs above pass | seconds |

The first four run in parallel. There are no npm install steps because the suites use Node built-ins only; CI runs without `@napi-rs/canvas` and the golden hashes match with and without it (the runner never calls `render()`). Add `npm ci` (with a lockfile) the day a suite grows a dependency.

Settings: `permissions: contents: read` (only `deploy` adds `pages: write` and `id-token: write`, the built-in Pages token permissions), no secrets, `persist-credentials: false` on checkout, a timeout on every job. A newer push cancels an older run of the same branch, except on `main`, where every run finishes so a deploy is never cut off.

### Pinned actions

| Action | Version | Commit SHA |
| :--- | :--- | :--- |
| `actions/checkout` | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/setup-node` | v7.0.0 | `820762786026740c76f36085b0efc47a31fe5020` |
| `actions/upload-pages-artifact` | v5.0.0 | `fc324d3547104276b827a68afc52ff2a11cc49c9` |
| `actions/deploy-pages` | v5.0.1 | `368f82528645a54fb793d4d04e342629a3f51346` |

All are first-party GitHub actions. To bump one, look up the tag's commit (`gh api repos/actions/checkout/git/ref/tags/<tag>`; if the type is `tag` rather than `commit`, follow it once more), replace the SHA and the version comment together, and update this table.

### The Godot jobs and the pinned download

Both Godot jobs use the local action `.github/actions/setup-godot`, so the pin lives in one place. It downloads the official Godot 4.7.2 Linux build (standard, not .NET) from the GitHub release and verifies its SHA-512 (from the release's `SHA512-SUMS.txt`) before running it, then sets `GODOT`. With `web-templates: 'true'` it also downloads `Godot_v4.7.2-stable_export_templates.tpz` (1.28 GB), verifies its SHA-512, and unpacks only the single-threaded Web templates (`web_nothreads_release.zip` and `_debug.zip`, about 20 MB). Nothing binary is committed. To bump Godot, change the version and both checksums together in that file and update this page.

`godot-parity` runs, from the repo root (`project.godot` is there): `--import` (registers the `class_name` scripts on a fresh clone), then `sim/core/tools/parity.gd`, `render/tools/determinism.gd` and `render/tools/seam_sweep.gd -- --size=1280x720`. Each exits 0 on pass. The `.godot/` import cache is created on the runner only (it is in `.gitignore`). The `sim` job does not set `GODOT`, so `npm test --prefix sim` skips its own godot stage there and the parity check runs once.

### Web export and the Pages site

`export_presets.cfg` (repo root) holds two presets:

- **Web**: Compatibility renderer (from `project.godot`), single-threaded, no extensions, so it needs no cross-origin isolation and runs on GitHub Pages as it is. Default output `build/web/index.html`.
- **Windows Desktop**: x86-64, pck embedded in one `.exe`, default output `build/win/orb-combat-ex.exe`. Not built in CI. The engine's Windows export template is in the same 1.28 GB download, so adding it later is a small change.

Both exclude `prototype/`, `qa/`, `research/`, `docs/`, `tools/` and `.github/` from the pack. Locally (with the 4.7.2 export templates installed):

```
godot --headless --path . --import
godot --headless --path . --export-release "Web" build/web/index.html
node tools/build-site.mjs --web build/web --out build/site
```

The `build/` folder should be in `.gitignore` (the EP's file). Serve `build/site` with any static server to try it; the web pack was about 0.6 MB and the wasm 39.5 MB (about 10 MB gzipped, which Pages applies).

`tools/build-site.mjs` lays out the site: `/` a small landing page, `/prototype/` the single-file prototype (the URL Orb shares, unchanged), `/play/` the Godot build. It fails if the export folder has no `index.html` and `.wasm`.

### Switching Pages to GitHub Actions (a repo setting)

Today Pages is "Deploy from a branch" (`main`, `/`), served by GitHub's own `pages build and deployment` workflow. The `deploy` job cannot publish until the source is "GitHub Actions". The exact change:

- Web: repository **Settings, Pages, Build and deployment, Source**: change "Deploy from a branch" to **GitHub Actions**.
- CLI: `gh api -X PUT repos/dixonbalsagna/orb-combat-ex/pages -f build_type=workflow`

Order: push the workflow first (the tests and `site` job run; `deploy` fails harmlessly while the source is still a branch and `/prototype/` keeps serving). After Orb agrees, flip the setting, then re-run the failed `deploy` job (or start CI by hand on `main`) so the site goes live at once. The site then serves only `/`, `/prototype/` and `/play/`: other repo files that the branch source used to publish at their paths (for example `/docs/...`) are no longer served. Switching back is the same setting in reverse.

### What is and isn't proven

- **Proven on GitHub:** `qa`, `sim` and `godot-parity` (parity only, before the render checks were added) have passed on `ubuntu-latest`, so the golden hashes hold across OSes.
- **Proven locally only:** the render checks (determinism 11 s, seam sweep 1 s), the Web and Windows exports, and the assembled site (loaded in a browser: title "Orb Combat EX", the greybox match runs). The template download and unpack, the Pages artifact and the deploy have not run on GitHub yet; the first run on `main` is the proof.
- **Branch protection** is available (the repository is public) but not needed while only the EP commits.

## Held for now

CONTRIBUTING.md, the pull request template and any licence field or licence check are on hold while Orb reconsiders the licence.
