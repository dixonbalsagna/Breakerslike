# ADR 0004: Seeded matches and the QA harness

Status: accepted (EP, 2026-09-28)

## Context
The prototype seeded its RNG from the clock, so no match could be replayed and no balance number could be reproduced. Seeded replays are a P2 exit criterion, and the parity tests for the sim port need a fixed oracle.

## Decision
- `newMatch(seed)` takes an optional integer seed. With no seed it keeps the clock-based behaviour.
- The QA harness in prototype/tools/ and qa/ runs seeded batches.
- `node qa/run-all.js` is the regression suite. It covers determinism, seam crossing, a 1000-match soak, and a self-test that must catch deliberately broken copies of the sim.
- Golden hashes in qa/golden-hashes.json are a tripwire for any change to sim behaviour. They are regenerated only on purpose (`--update-golden`), with the reason in the commit message.
- Golden hashes are pinned to Node 24; other major versions skip them with a notice.
- Match length is measured to the KO, excluding the 3-second KO tail.
- Cross-match director state (`dirS.lastLaunch`, `lastLaunch2`) is reset in `newMatch()`, so a seed alone reproduces a match (QA-001).

## Consequences
- Every change to numbers is measured against qa/baseline-p0.json.
- Tests that read the prototype's source text must be ported when the sim core moves to sim/.
- Cosmetic effects still draw from the sim RNG (QA-002). The port separates them after parity is proven.
