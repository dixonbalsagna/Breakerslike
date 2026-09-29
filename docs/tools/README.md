# Tools: CI and setup

Owner: Tools and Pipeline. Free GitHub-hosted runners only, no secrets, no paid services.

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

`.github/workflows/ci.yml` runs on every push and pull request on `ubuntu-latest`, with Node pinned to **24.19.0**:

| Job | Runs | Time |
| :--- | :--- | :--- |
| `qa` | `node qa/run-all.js` | about 35 s |
| `sim` | `npm test --prefix sim` | about 1.5 min |
| `godot-parity` | Godot 4.7.2 headless on Linux: import, then `sim/core/tools/parity.gd` | about 1 min with the download |

The two live jobs run in parallel. There are no install steps because both suites use Node built-ins only. CI therefore runs without `@napi-rs/canvas`; the golden hashes match with and without it (the runner never calls `render()`). Add `npm ci` (with a lockfile) the day either grows a dependency.

Settings: `permissions: contents: read`, no secrets, `persist-credentials: false` on checkout, a run cancels the older run on the same ref, each job has a timeout.

### Pinned actions

| Action | Version | Commit SHA |
| :--- | :--- | :--- |
| `actions/checkout` | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/setup-node` | v7.0.0 | `820762786026740c76f36085b0efc47a31fe5020` |

Both are first-party GitHub actions. To bump one, look up the tag's commit (`gh api repos/actions/checkout/git/ref/tags/<tag>`; if the type is `tag` rather than `commit`, follow it once more), replace the SHA and the version comment together, and update this table.

### The Godot job

`godot-parity` runs the GDScript port against the JS reference sim's golden vectors (ADR 0001). Steps, from the repo root (`project.godot` is there):

1. Download the official Godot 4.7.2 Linux build (`Godot_v4.7.2-stable_linux.x86_64.zip`, standard build, not .NET) from the GitHub release and verify its SHA-512 (from the release's `SHA512-SUMS.txt`, pinned in the workflow) before running anything.
2. `godot --headless --path . --import` registers the `class_name` scripts, because a fresh clone has no class cache.
3. `godot --headless --path . --script res://sim/core/tools/parity.gd` exits 0 on pass and 1 on fail (about 16 s locally).

The `.godot/` import cache is created on the runner only; it is in `.gitignore` and never committed.

The `sim` job does not set `GODOT`, so `npm test --prefix sim` skips its own godot stage there ("Godot not found" note) and the parity check runs once, in this job. To bump Godot, change `GODOT_VERSION` and `GODOT_ZIP_SHA512` together, and update `tools/setup.*` and this page.

Locally, both commands passed with the Windows 4.7.2 console build, and the Linux zip's checksum matched. The job itself has not run on a runner yet, so its first run is the proof.

### What is and isn't proven

- **The first Actions run after the EP pushes is the real proof.** The workflow was checked by reading it and by running its two commands locally, not by GitHub.
- **The goldens were recorded on Windows.** A Linux runner is the first cross-OS check. If the golden check fails there while the rest passes, the fallback is `runs-on: windows-latest` for the `qa` and `sim` jobs, which matches where they were recorded. Do not update the goldens to make a Linux run pass without a decision from QA.
- **Branch protection is not assumed.** On a private repository on a free plan GitHub does not offer required status checks, so a red CI run informs but does not block a merge.

## Held for now

CONTRIBUTING.md, the pull request template and any licence field or licence check are on hold while Orb reconsiders the licence.
