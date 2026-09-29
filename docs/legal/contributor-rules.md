# Contributor rules (for Tools to place in .github/)

Owner: Legal and IP Compliance. 2026-09-29. Draft. Tools places this as `.github/CONTRIBUTING.md` (legal section) and in the PR template. Not legal advice.

## Legal section for CONTRIBUTING.md

**Licences.** Code is MIT (`LICENSE`). Content (art, audio, data, docs) is CC BY 4.0 (`LICENSE-ASSETS`). By contributing you agree your contribution is under the matching licence. You keep your copyright.

**Sign-off (DCO).** Sign every commit with `git commit -s`. That adds a `Signed-off-by:` line and means you agree to the Developer Certificate of Origin, version 1.1: you wrote the work or have the right to submit it under the project's licence, and you understand it is public. The official text is at https://developercertificate.org/ and governs. Its fit for non-code assets (art, audio) has not been tested, so for those also state where the work came from in the PR (see below). No CLA is needed.

**Originality.** This project is an original work in a genre. Do not contribute franchise names, characters, designs, catchphrases, music, sound, logos, UI or code from other games, including fan games. Read `docs/legal/originality-rules.md` first.

**Third-party material.** Say what it is and its licence. Only licences listed as accepted in `docs/legal/licence-register.md` (Part C) are welcome. No licence stated means no.

**AI assistance.** Allowed, and you are responsible for what you submit. Say so in the PR (tool, model, date, where the prompt is kept). Never use franchise names or images in a prompt.

## PR template wording

```
## What and why


## Originality (tick all)
- [ ] No franchise names, characters, designs, catchphrases, music, sound, logos, UI or code
- [ ] I did not use reference images, audio or footage from an existing franchise
- [ ] Any third-party material is listed below with its licence
- [ ] I signed off my commits (git commit -s)

## AI assistance (delete if none)
Tool: 
Model: 
Date: 
Where the prompt is kept: 
What a human changed: 

## Third-party material (delete if none)
| Name and version | Source | Licence (SPDX) | Ships to players? |
|---|---|---|---|

## Content origin (art, audio, data; delete if none)
Made by: 
Tool, if any: 
```

Legal adds a row to `docs/legal/asset-origins.md` for each content item, once that log exists.
