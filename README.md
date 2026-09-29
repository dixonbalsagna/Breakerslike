# Orb Combat EX (working title)

A free fighting game about wrecking a planet. No combo lists: pick a stance and the game choreographs the exchange. Inspired by the classic anime energy-brawlers.

Every fighter, move and planet here is original. **Licence:** not chosen yet, so all rights are reserved for now. "Meridian" is the team's internal codename.

## What's here
- `CLAUDE.md` project brief, loaded by every Claude Code session in this folder
- `DIRECTORS.md` roster: Executive Producer plus 24 directors, with duties, deliverables and activation schedule
- `docs/directors/` one charter per director, and the list of director sessions (`docs/directors/README.md`)
- `docs/ep/playbook.md` how the Executive Producer session runs the project
- `.claude/commands/` `/director` (start a director session), `/standup` and `/gate`
- `prototype/index.html` playable browser prototype (open it directly)
- `prototype/tools/` headless simulation harness and stats runner
- `tools/gen_directors.py` regenerates DIRECTORS.md and the charters from one roster (`python tools/gen_directors.py` from the repo root)
- `docs/decisions/` decision records
- `docs/production/risk-register.md` risk register
- `docs/setup/git-and-github.md` linking the folder to GitHub, and setting up a new computer

## How the team runs
Each director is its own Claude Code session answering to the Executive Producer session (ADR 0002). To open one, follow `docs/directors/README.md`.

## Sanity checks
- `node prototype/tools/sim-stats.js 20` runs 20 AI-vs-AI matches with no dependencies.
