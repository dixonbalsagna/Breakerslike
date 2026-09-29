# ADR 0005: Lean team and token discipline

Status: accepted (EP, 2026-09-29; Orb asked for a reasonable distribution)

## Context
The project runs on a Claude Pro plan with zero budget. On the night of 2026-09-28, all 22 director sessions ran at once, alongside several multi-agent workflows, and used up a full 5-hour usage window in about 25 minutes. The EP's brief-drafting workflow alone used about 1.7 million subagent tokens. The EP session's growing context was also re-read on every notification. Orb asked for a distribution that can actually finish something playable.

## Decision
- **Few directors at a time.** Three to five directors work at once. Everyone else stays idle, which costs nothing. The EP briefs a director only when its work is on the critical path or unblocks it.
- **No standing ultracode.** Workflows run only when Orb approves a specific task: a bounded, high-stakes check of at most five agents. A workflow that was interrupted may be resumed from its journal to finish; it is not restarted.
- **Effort (Orb's choice).** Opus directors run at xhigh and Sonnet directors at high. The EP session should run at high.
- **Short messages.** Briefs and reports stay short, and deliverables go in files. The EP reads summaries rather than whole documents, and does not subscribe to idle notices.
- **Read only what the task needs.** Directors don't re-read the whole prototype unless the task needs it.
- **Keep the EP's context small.** When its context grows large, the EP session is refreshed from docs/ep/handoff.md and memory.

## Consequences
- Less happens in parallel. The critical path runs in bursts within each 5-hour window.
- Idle directors keep their context, so resuming them later is cheap.
- This ADR revises the effort and ultracode settings in ADR 0003.
