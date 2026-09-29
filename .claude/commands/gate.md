---
description: Run a phase gate review against the exit criteria in CLAUDE.md
argument-hint: phase number, for example P2
---
Act as the Executive Producer running the gate for phase $ARGUMENTS. Read the exit criteria for that phase in CLAUDE.md. Brief the director sessions for QA and Balance (test evidence), Production Operations (schedule and risk status) and Legal and IP Compliance (originality status) with SendMessage; their session titles are in `docs/directors/README.md`. Compare the evidence to each exit criterion and report pass, fail or not evidenced for each. Recommend to Orb whether to open the next phase. Do not open it yourself.
