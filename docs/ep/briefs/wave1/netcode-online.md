# P0 wave 1 brief: netcode-online

From the Executive Producer, 2026-09-28. Prototype line references are pinned to commit 7233c96.

Brief from the EP (P0 wave 1): three short documents that give the engine decision (ADR 0001) a netcode verdict for Godot GDScript, Godot C# and web JS/TS.

GOAL: Define what the simulation must guarantee for input-only rollback and replay verification, and say which engine option carries the least desync risk with the procedural director.

CONTEXT (read first):
- docs/directors/netcode-online.md, CLAUDE.md (Architecture and Conventions), docs/decisions/0001-engine-choice.md and 0004-seeded-matches-and-qa-harness.md.
- prototype/index.html, read only. QA's edit tonight moved every line after 216 down by one.
  - Fixed step: DT = 1/60. step(dtReal) scales by game.ts, and dirS.stop hit-stop is consumed with real dt.
  - RNG: mulberry32, rng, R(), newMatch(seed); the no-seed path uses Date.now(). An order draw, rng() < 0.5, happens in step.
  - Inputs: the held/edges sets read by humanInput and applied in control. aiInput also draws from the RNG.
  - Floats: Math.sin/pow (28 uses of Math.sin/cos/pow/atan2/sqrt/Float32Array), the Float32Array base and deform arrays, and wrap/sdx on W = 9600.
  - Director: ex.beats holds closures pushed by B() and run in dirUpdate, so a snapshot cannot serialise them as written.
- qa/baseline-p0.md:
  - QA-001 (cross-match dirS.lastLaunch state): fixed in newMatch tonight, pending EP commit.
  - QA-002: cosmetic spark/debris/dust/splash/fire draw from the sim RNG; one extra draw changed 100 of 100 matches.
  - QA-004: event log. QA-005: Node 24 golden hashes depend on the engine's math library.
  - 76% of matches cross the seam, and matches average 55 s.
- Simulation, already briefed, writes docs/architecture/overview.md (RNG policy including a cosmetic stream, serialization and replay format) and docs/architecture/determinism.md tonight, and it decides the serialization and replay format. Your contract states the requirements those must meet. Where you would choose differently, write a request, not a ruling. The EP reconciles the two before Simulation starts the QA-002 split and the QA-004 event log.
- Camera, Controls, Audio and Animation will cite your rule for how hit-stop and slow-motion exist in the sim, so state it explicitly.
- Simulation's port (sim/) and Research's spikes are being written tonight, so any files you see may be partial. Write against the prototype and phrase every port need as a request. Anything for another director goes under NEEDS FROM EP.

YOU OWN: net/ and docs/net/. Tonight write only docs/net/; no code in net/.

ACCEPTANCE CRITERIA:
1. docs/net/determinism-contract.md states numbered MUST and SHOULD requirements for:
   - the fixed step: 60 Hz; the sim advances only in whole ticks; hit-stop and slow-motion are integer tick counts in sim state, never game.ts scaling of dt and never real-dt consumption as in step();
   - input-only sync, with one input struct per player per frame (the in fields plus stance);
   - RNG: one sim stream; cosmetic streams never affect state; the director draws only from the sim stream; state is snapshotable per frame;
   - floats: allowed operations, cross-platform math, and an option ruling on fixed-point versus float ('Orb decides' only if it needs him);
   - state hashing: fields, cadence and algorithm;
   - desync detection;
   - replay requirements: seed, version, input log and periodic hashes, with a verification procedure.
   Each requirement notes whether Simulation's docs are expected to satisfy it.
2. The contract cites the concrete prototype hazards above by function or constant name and gives the fix for each.
3. docs/net/rollback-feasibility.md covers GDScript, C# and web JS/TS. For each: what breaks determinism, how to guard it, the snapshot and restore cost for terrain deformation, particles and beats, and a ranked recommendation with confidence. Include the director-in-rollback design: how beat closures become data, and how misprediction of an attack request re-rolls an exchange.
4. It also covers the seam, hidden information under rollback (both clients hold full state) and the rollback budget in frames.
5. docs/net/simulation-port-requests.md lists at most 12 numbered requests covering hash points, the snapshot and restore API, event log fields, the RNG split and the input type. Each request is testable.
6. Every open claim is marked as verified or as an assumption. Where an answer depends on Orb (online at launch or later, platforms), give options with trade-offs marked 'Orb decides'.

CONSTRAINTS: No git state changes. Online features (lobby, matchmaking, spectator, anti-cheat) are P5 and out of scope tonight. Do not edit the prototype or sim/. Keep the simulation deterministic and separate from rendering. Stay original, with no code or wording copied from other netcode libraries or franchises. Keep each document under 1,500 words.

RETURN: the standard report (SUMMARY, CHANGES, DECISIONS, NEEDS FROM EP, RISKS, NEXT), sent to me with SendMessage.

## Since this brief was drafted

Simulation has written docs/architecture/module-spec.md; read it. Key points:
- The port has one state object S and no module globals.
- Exchange beats are serialisable data ops.
- Cosmetics draw from S.rngFx.
- step(S, inputs) is one fixed tick, and AI intents are generated inside it.
