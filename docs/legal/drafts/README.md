# Licence drafts (MIT + CC BY 4.0 + DCO)

Orb chose pairing 1 from `licence-recommendation.md` (relayed by the EP, 2026-09-29): MIT for code, CC BY 4.0 for content, DCO for outside contributors. Option B (GPL) is dropped. These are drafts for the EP and Tools to place. Not legal advice. Have counsel read the final text before the repo goes public.

| Draft | Goes to | Placeholder to fill |
|---|---|---|
| `LICENSE` | repo root | copyright holder |
| `LICENSE-ASSETS` | repo root | copyright holder, game name |
| `NOTICE` | repo root | copyright holder, game name; keep the Godot entry only if ADR 0001 confirms Godot |

`LICENSE` is the standard MIT text, checked against the SPDX template on 2026-09-28. `LICENSE-ASSETS` links to the official CC BY 4.0 legal code and summarises it in our own words. It does not copy the code, because it was not fetched verbatim.

**Copyright holder. Orb decides:** (a) a legal name, (b) "Orb", or (c) "<Game name> contributors". Option (c) needs the game name. Steam will also want a verified publisher identity, and counsel should advise on the pseudonym question.

## The split

| Paths | Licence | SPDX header |
|---|---|---|
| `sim/`, `render/`, `ui/`, `net/`, `tools/`, `prototype/`, `qa/`, build and CI files | MIT | `// SPDX-License-Identifier: MIT` (JS, C-style), `# SPDX-License-Identifier: MIT` (Python, YAML, shell), `<!-- SPDX-License-Identifier: MIT -->` (HTML) |
| `art/`, `audio/`, `data/`, `docs/` | CC BY 4.0 | `<!-- SPDX-License-Identifier: CC-BY-4.0 -->` (Markdown), `"_license": "CC-BY-4.0"` (JSON data, if the schema allows), or a directory-level file |
| Third-party files | their own | listed in `docs/legal/licence-register.md`, with the licence kept next to the file |

Headers on every file are optional. A directory-level rule in the licence files is enough for a start. Tools can add a `REUSE.toml` and a CI check later.

## How to land it

1. **Orb** names the copyright holder (and, when picked, the game name).
2. **The EP** places `LICENSE`, `LICENSE-ASSETS` and `NOTICE` at the repo root, with the holder filled in, and commits them.
3. **Tools** adds a `license` field (`MIT`) to the root and `prototype/package.json` (if a root one exists), and places `.github/CONTRIBUTING.md` and the PR template from `docs/legal/contributor-rules.md`.
4. **The EP** makes the Must edits in `public-readiness-edits.md`, renames the repo, and checks the README carries a licence section, an AI note and a trademark note (wording there).
5. **Legal** checks the placed files against these drafts, then counsel reads them before the repo goes public.
