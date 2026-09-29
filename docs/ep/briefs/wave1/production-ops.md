# P0 wave 1 brief: production-ops

From the Executive Producer, 2026-09-28. Prototype line references are pinned to commit 7233c96.

Brief from the EP (P0 wave 1): tonight all 22 directors work in parallel. Turn the plan's paperwork into a live roadmap, a current risk register, a single list of what Orb must decide, and reusable report templates.

GOAL: Give the EP and Orb one-page clarity on where P0 stands, what could hurt us, what waits on Orb, and how the P0 gate will be judged.

CONTEXT (read first):
- docs/directors/production-ops.md (charter), CLAUDE.md ('Roadmap and exit criteria', 'Open questions for Orb'), DIRECTORS.md (activation schedule: reflect it, do not edit it) and .claude/commands/gate.md (how the EP runs a gate).
- docs/production/risk-register.md: 11 rows today, with columns #, Risk, Likelihood, Impact, Owner, Mitigation. Keep them and add from #12.
- Legal files:
  - docs/legal/review-log.md (open flags RL-001, RL-002, RL-012, RL-014, RL-015);
  - licence-recommendation.md (section 2's four questions, 3B GPL versus Steam, 7 stores, 8 AI);
  - licence-register.md Part D;
  - originality-rules.md (the grey-zone table and fan-game rights);
  - name-screening.md (markets and trademark filing).
- qa/baseline-p0.md (findings 1 to 3, 6 and 9; defects QA-001 to QA-005) and qa/README.md.
- Facts from the EP as of this brief:
  - QA-001 is fixed in the working tree (newMatch resets the launch history), and the hero's hair changed from '#ffd54a' to '#22c7a9'. Both await EP commit. RL-014 stays open until the art bible.
  - QA-002 is fixed by Simulation after parity. QA-004 needs Simulation (the event envelope) and Encounter Systems (director events).
  - Legal's wave-1 docs are accepted, and Legal does a follow-up tonight. Tools is briefed for the first time tonight.
  - Orb's answers are pending. The repo stays private until a licence and a new name are approved.
  - Prototype line numbers after 216 shifted by one tonight; cite function names.
- Tonight's wave (from the EP; you cannot see the briefs themselves). Format: director | focus | writes | waits on (via the EP)
  Research | engine spike (Godot 4.7.2 vs web), then the information-hiding spike | research/ | Camera and UI hiding docs for the second spike
  Simulation | reference port with parity, architecture and determinism docs; then QA-002 and QA-004 | sim/, docs/architecture/ | QA-001 commit; Netcode's port requests
  Game Design | pillars, stance matrix, economy, balance targets, modes, open questions | docs/design/ | none
  Encounter Systems | director architecture, decision-log format, overlay content spec, tuning plan | docs/director/ (data/director/ later) | Simulation's port for sim/director/
  Combat | move grammar, exchange templates, signature variants, field list | docs/combat/ (data/atoms, data/exchanges later) | Tools' schemas for data
  Narrative | game and hero name longlists, fighter sketches, shortlist | docs/narrative/ (data/fighters later) | Tools' fighter schema for data
  QA | QA-001 fix, hero hair colour, baseline-diff script | qa/, prototype/tools/, two edits in prototype/index.html | none
  Legal | licence drafts, contributor rules, asset-origin log, public-readiness edits | docs/legal/ | Narrative's shortlist (optional)
  Tools | schemas and validator, one-command setup, CI, pinned canvas, PR template | tools/, build/, .github/, root and prototype package files | Legal's register rows before commit
  Production | roadmap, risks, decisions pending, templates | docs/production/ | all reports
  Art | three art directions, bible skeleton, biome notes, concept SVGs | docs/art-bible/, art/concepts/ | Orb (presentation, style); Legal's asset-origin log
  Camera | framing rules, comfort limits, cinematic moments, hiding options | docs/camera/ | none
  World | destruction rules, planet layout, cover, escalation analysis, biome fields | docs/world/ | Simulation's port; Tools' biome schema
  Netcode | determinism contract, rollback feasibility, port requests | docs/net/ | none (feeds ADR 0001)
  Controls | tuning table, input map, feel risks | docs/feel/ | Simulation's port for sim/input/
  Performance | budgets, measured tick cost, worst-case scene, profiling method, hardware | docs/perf/ | a quiet-machine re-measure
  UI & UX | HUD spec, debug overlay layout, menu flow | docs/ux/ | Encounter's decision-log fields
  Accessibility | checklist, assist review, localization plan, English strings | docs/accessibility/, localization/ | Controls' window numbers
  VFX | effect inventory, style options, effect budgets, readability | docs/vfx/ | Performance's budgets, Art's directions
  Audio | SFX events, adaptive music, mix, sourcing | docs/audio/ | Legal's asset-origin log
  Animation | clip list, warping rules, rig options | docs/animation/ | Combat's move grammar
  Marketing | positioning, playtest plan, devlog calendar, channels | docs/marketing/ | Legal review; the new name
- Everything routes through the EP. If you need a director's status, list it under NEEDS FROM EP.

YOU OWN: docs/production/ only (roadmap.md, risk-register.md, decisions-pending.md, status-digest-template.md, gate-packet-p0.md).

ACCEPTANCE CRITERIA:
1. roadmap.md lists P0 to P5 with the CLAUDE.md exit criteria, quoted and labelled 'copied from CLAUDE.md on 2026-09-28; CLAUDE.md wins if they differ'. Add a checkable exit checklist per phase, and a P0 status line per criterion with its evidence or its owner:
   - engine ADR: Research's spike, Netcode's verdict, Orb;
   - repo;
   - CI: Tools;
   - data schemas: Tools;
   - sim core skeleton with seam-crossing tests: Simulation;
   - originality rules: Legal, done;
   - fresh clone in one command: Tools' npm run setup;
   - 1000 matches without error: the node qa/run-all.js soak today, then Simulation's port soak.
2. roadmap.md carries the activation schedule and the wave table above.
3. risk-register.md keeps rows 1 to 11 and adds at least 12 new risks. Each has likelihood, impact, owner, mitigation, source id and status:
   - KAI name (RL-002);
   - hero hair (RL-014: prototype fixed, art open);
   - no LICENSE file (Part D);
   - AI-content disclosure and ownership (section 8);
   - GPL versus Steam (3B);
   - repo name before public (RL-012);
   - KAI's 41.8% win rate (finding 1);
   - SLAM DOWN at 46.4% against the 40% cap (finding 2);
   - 69.4% of beams over the ocean (finding 3);
   - cosmetic RNG (QA-002);
   - cross-match reset (QA-001: fixed, pending commit);
   - Node 24 pinning (QA-005);
   - plus any you find, for example 22 sessions on one machine skewing performance measurements.
4. Every risk row has a named owner and a mitigation. Add a status column and a short dependency map (who blocks whom), built from the wave table.
5. decisions-pending.md lists every Orb decision, one row each:
   - the EP's list: tone, presentation, art style, platforms, modes, online, AI assets, licence, name brief, timeline, budget;
   - CLAUDE.md's eight open questions (merge duplicates);
   - every 'Orb decides' item in docs/legal/: licence-recommendation section 2 questions 1 to 4 and 8.5 item 6; the seven grey-zone rows and the fan-game rights in originality-rules.md; markets and trademark filing in name-screening.md.
   Each row gives who needs it, what it blocks, a recommended default (Legal's where one exists) and the 'Orb decides' label. Order the rows by blocking impact, one clear question each.
6. status-digest-template.md fits on one page (at most 60 lines when filled in): a line per director, gates, top three risks, decisions needed, and scope changes with their cost. gate-packet-p0.md is a skeleton aligned with .claude/commands/gate.md: criteria, evidence links (node qa/run-all.js output, ADRs, review-log open flags), an open-flags list and a go or no-go box.

CONSTRAINTS: No git state changes. Edit nothing outside docs/production/. Do not invent numbers; cite the source file. Use no franchise wording, and keep public wording out of these docs (Legal owns it). Keep documents concise; no process for its own sake.

RETURN: the standard report (SUMMARY, CHANGES, DECISIONS, NEEDS FROM EP, RISKS, NEXT), sent to me with SendMessage.

## Since this brief was drafted

Current status, for your digest timeline:

Committed and pushed:
- 811629e: QA baseline and test suite
- 115f56b: effort tiers (ADR 0003)
- 7233c96: QA-001 reset and hair colour (the pinned prototype)
- 18e6e4d: QA baseline-diff
- f253011 and 541f97e: Narrative name longlists and glossary
- 29786e3: Legal wave 1 (accepted with fixes)
- 5311aa6: Narrative places

In progress:
- QA is building a known-bugs register. Game Design and Combat independently found the same prototype bugs.
- Research is running the engine spike and Simulation the port with parity, both with ultracode.

New questions for Orb:
- The hero's gender or pronouns (from Narrative).
- Whether civilians die on screen.
- The copyright holder's name.
- Lemming Ball Z provenance.

Orb is filling in the scope-and-vision questionnaire now. List those topics in decisions-pending.md as "answer incoming".
