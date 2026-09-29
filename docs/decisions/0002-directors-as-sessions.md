# ADR 0002: Directors run as separate Claude Code sessions

Status: accepted (Orb, 2026-09-28)

## Context
The handoff modelled the 22 directors as subagents invoked by one main session. Orb wants every director to be its own specialised Claude Code session, answering directly to the Executive Producer session, and wants as many directors as the project can use.

## Decision
- One session per director (22 today), plus the Executive Producer session. Session titles are "Meridian - <role>", unique on this machine.
- Charters move from `.claude/agents/` to `docs/directors/`, so sessions read them as role documents and nothing auto-delegates to them as subagents. `tools/gen_directors.py` stays the single source of truth for DIRECTORS.md and the charters.
- A director session starts with `/director <slug>`. Briefs and reports travel by SendMessage. Every session runs in Auto permission mode.
- All sessions share the project folder. Directors edit only their owned paths and never change git state; the EP reviews, commits and pushes.
- The activation schedule decides who is briefed in each phase. QA and Balance joins P0 as support, because the P0 plan needs its baseline report.
- The Encounter Systems Director's slug changes from `fight-director-ai` to `encounter-systems`, to match its title.

## Consequences
- Coordination runs through the EP session, so briefs must be self-contained.
- All sessions share the account's usage limits, so the EP paces briefs.
- Concurrent edits are contained by owned paths and EP-only git. Any change to a shared file goes through the EP.
