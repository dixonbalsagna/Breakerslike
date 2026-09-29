# Wave 1 routing checklist (EP working notes, 2026-09-28)

These are the cross-forwards to make as reports land. They come from the integration critic's sequencing and are kept current by the EP.

## Done
- QA-001 fix and the hair colour are committed (7233c96, the pinned prototype for line references). QA's baseline-diff is committed (18e6e4d).
- Legal's wave-1 docs are committed (29786e3), accepted with fixes. Narrative's names, glossary and places are committed (f253011, 541f97e, 5311aa6).
- The 15 briefs are sent (docs/ep/briefs/wave1/, 40bb119). Amendments are sent to Research, Simulation, Encounter Systems, Combat and Game Design.
- Narrative is on hold until Orb gives a tone.

## When each report lands

**Tools**
- Forward its component list to Legal: npm packages with exact versions, each GitHub Action's SHA, and the @napi-rs/canvas pin.
- Check that `node qa/run-all.js` still passes with @napi-rs/canvas installed.
- Commit Tools only after Legal has written the register rows.
- Then forward tools/schemas/ and its README to Combat (data/atoms, data/exchanges), World (data/biomes) and Narrative (data/fighters).

**Legal**
- Commit.
- Forward the contributor-rules.md PR wording to Tools, for the pull-request template and .github/CONTRIBUTING.md.
- Forward asset-origins.md to Art, Audio and Narrative.
- Forward the homage-line options to Marketing.
- Forward the name screening results to Orb.

**Art**
- Send its proposed SVG origin rows to Legal. Commit art/concepts/*.svg only after Legal records them.
- Forward the semantic colour roles to VFX, UI, Accessibility and Animation.

**Field lists**
- When the Combat, World and Narrative field lists are all in, send them to Tools in one pass for schema v2.
- Forward v2 back to all three once it's committed.

**Netcode**
- Forward determinism-contract.md and simulation-port-requests.md to Simulation before it starts QA-002 and QA-004.
- Forward the hit-stop and slow-motion tick rule to Camera, Controls, Audio and Animation.
- Hold rollback-feasibility.md for ADR 0001.

**Encounter Systems**
- Forward decision-log-format.md and debug-overlay-spec.md to UI, Simulation, Audio, Camera and QA (QA-004).
- Forward the data/director layout to Tools for a director-tuning schema.

**Simulation's port is committed**
- Hand over sim/world/ to World, sim/director/ to Encounter Systems and sim/input/ to Controls, using Simulation's file list.
- Brief Tools (wave 2) to add `npm test --prefix sim` to check and CI.
- Ask Performance to re-measure the sim tick on the port.
- Queue QA's port of the regression suite (ADR 0004).

**Camera and UI**
- Forward hiding-camera-options.md and the HUD hiding notes to Research.
- Forward the lowest zoom and minimum fighter size to Art and VFX.
- Forward the shake caps to Controls.

**Other forwards**
- Performance's canonical worst-case scene and profiling template: to Research and VFX.
- Combat's move-grammar.md: to Animation, Controls, VFX, Audio and Accessibility.
- Controls' window and hit-stop table: to Accessibility, UI and Combat.

**Quiet window**
- Performance, then Research, rerun their one-command timing scripts with QA's soaks paused.
- Replace the provisional numbers with the quiet-window results.

**ADR 0001**
- Once Research's RESULT.md, Netcode's rollback verdict and Performance's review are all in, draft ADR 0001 and send Orb one question.

**Throughout**
- Forward committed reports to Production for the status digest and the risk register.
- Close the night with Production's gate-packet-p0.md and the top questions for Orb.

**When Orb's questionnaire answers arrive**
- Forward each answer to the directors it affects: Art, VFX, Audio, Animation, Marketing, Narrative (tone), Game Design (modes and match length), Legal (licence, homage, AI) and Production (decisions-pending.md).
