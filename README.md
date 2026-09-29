# Meridian handoff package

Contents:
- `CLAUDE.md` project brief and instructions for the Executive Producer (main session)
- `DIRECTORS.md` roster: Executive Producer plus 22 directors, with duties, deliverables and activation schedule
- `.claude/agents/` one subagent file per director
- `.claude/commands/` two helper commands: `/standup` and `/gate`
- `prototype/index.html` playable browser prototype (open it directly)
- `prototype/tools/` headless simulation harness and stats runner
- `tools/gen_directors.py` regenerates DIRECTORS.md and the agent files from one roster (run from the repo root: `python3 tools/gen_directors.py`)
- `docs/decisions/` decision records (ADR 0001 engine choice is open)
- `docs/production/risk-register.md` starting risk register

## Start in Claude Code
1. Unzip into an empty folder and `git init`.
2. Open a terminal in that folder and run `claude`.
3. Choose Opus for the main session (for example with the `/model` command).
4. Paste: "Read CLAUDE.md and DIRECTORS.md. You are the Executive Producer. Run the first tasks in order, delegating to directors as described, and report back with the engine recommendation and open questions."

Check the Claude Code documentation for current subagent settings and model aliases. Files here follow the documented format: markdown with `name`, `description`, optional `tools` and `model` in the frontmatter.

## Sanity checks
- `node prototype/tools/sim-stats.js 20` runs 20 AI-vs-AI matches with no dependencies.
- `/agents` or `claude agents` lists the directors once the folder is loaded (the exact command depends on your Claude Code version).
