# EP handoff

This file is for a fresh Executive Producer session. Read it first, then docs/ep/playbook.md, ADR 0005 and docs/ep/vision.md. Memory has the essentials too.

## State on 2026-09-29
- P0 is in progress. Line references into the prototype are pinned to commit 7233c96.
- Committed and accepted:
  - QA: seeded sim, baseline, regression suite and baseline-diff (811629e, 18e6e4d; ADR 0004).
  - Legal wave 1 (29786e3), accepted with fixes.
  - Narrative: names, glossary and places (f253011, 541f97e, 5311aa6).
  - Wave-1 briefs for 15 directors (docs/ep/briefs/wave1/, 40bb119).
  - The routing checklist (docs/ep/wave1-sequencing.md).
- Orb answered questionnaire 1 (docs/ep/vision.md). The verbatim fighter notes are in .private/, local only. Questionnaire 2 was posted in chat on 2026-09-29.

## Directors (lean team, ADR 0005)
- **Active:**
  - Simulation: finish the port and its parity checks.
  - Research: finish the engine spike.
  - Game Design: design docs reflecting Orb's answers.
  - Legal: review the fighter concepts for IP risk; prepare going public.
  - Narrative: pitch titles.
- **Paused mid-work.** Resume these later with "continue your brief":
  - Combat (move grammar)
  - Encounter Systems (director docs)
  - QA (known-bugs register)
- **Briefed but not started.** Hold these until their phase, and update their briefs with vision.md before resuming them: Tools, Production, Art, Camera, World, Netcode, Controls, Performance, UI & UX, Accessibility, VFX, Audio, Animation, Community. Their briefs are in docs/ep/briefs/wave1/.
- **Charters written, sessions not yet opened:**
  - Rendering & Technical Art: open at the engine decision.
  - Modding & Extensibility: open later.

## The sim port has landed (2026-09-29)
- The port is committed, with parity against 7233c96 proven. `npm test --prefix sim` passes (unit, parity and soak; about 2 minutes).
- Ownership has passed, to be announced when each director resumes:
  - sim/world/ to World
  - sim/director/ to Encounter Systems
  - sim/input/ to Controls
- Next for Simulation:
  - the QA-002 split and the QA-004 event log, after Netcode's requests;
  - an N-fighter state model, when the roster work starts. sim/README.md lists every place that assumes two fighters.
- Needs a ruling from Game Design and Controls: a human can switch stance while locked in an exchange and take 0.38x damage (sim/README.md, bug 3).
- For ADR 0001: docs/architecture/determinism.md recommends deterministic binary64 floats with our own trig functions. It advises against C# for the sim while Godot C# can't export to the browser.

## GDScript port and fx split (2026-09-29)
- The GDScript sim is bit-identical to the det-mode JS core (26479d5), and CI runs the Godot parity job on Linux.
- The QA-002 split has landed: the sim holds only gameplay state, and cosmetic effects arrive as fx events (docs/architecture/fx-events.md). Tick mean 35 µs; projected worst case on an old laptop 1.4 to 2.4 ms.
- Ownership of sim/world, sim/director and sim/input (both twins) now passes to World, Encounter Systems and Controls. Announce it in each one's next brief. The JS core stays the oracle; any sim change touches both twins and the goldens.
- Give docs/architecture/fx-events.md to Rendering (first brief), VFX, Camera and Audio. The 'camera' and 'audio' stream ids are reserved for them.
- Simulation's next items (held): integer tick timers (determinism.md hazard 1), before Netcode's rollback work.

## Greybox (2026-09-29)
- Rendering's greybox is committed (2ebdb53): F5 plays the GDScript sim AI vs AI in 2.5D, and any key takes P1. Seam sweep and render determinism tools pass. Desktop frame 0.98 ms, web 1.83 ms (high-end machine only).
- Tools is working on a web export preset, the render tools in CI, and a Pages deploy at /play/. Flipping Pages to deploy through Actions needs Orb's OK.

## Questionnaire 3 wave (2026-09-29)
- **Active now:**
  - Game Design: the meter-less damage model and pacing (damage-model.md).
  - Combat: procedural movesets (procedural-moves.md).
  - Narrative: the signature pitches (orbs, multiplier, Cyborg food and core, transformations, fusion, tail) and the line system.
  - Simulation: GDScript becomes the source of truth; the JS core is frozen (ADR 0006 draft).
- **Next, once Simulation's switch lands (goldens are then GD-only):**
  - World (with Rendering): craters, not canyons. The ground gets depth. Impacts make round bowls with rims and ejecta, sized by energy; a diagonal slam skids into a bowl. The z=0 slice must equal the sim's groundY. Beams scorch and leave trails of destruction that scale with power (vision.md). Also simple water flow, and a planet that reads full-scale.
  - Encounter Systems: fights stuck in the ocean; more launches across the map; the tempo changes from Game Design.
  - Rendering: civilians too small; planet-scale feel.
  - Legal: screen Narrative's favourites, the true-merge fusion and the redesigned tail.
- **Pinned for Game Design later:** planet destruction and stage transitions (the mantle and lava, zero-g space).
- **Audio, when active:** per-character grunts, growls and laughs that carry unvoiced text lines.

## After questionnaire 3 (2026-09-29, later)
- ADR 0006 is committed: GDScript first, JS frozen at 9ac1ea9, goldens from golden.gd, batch.gd for AI batches. **Only one director changes sim behaviour at a time**, so golden.json doesn't collide in the shared folder.
- **Orb's picks:**
  - Damage: Wounds.
  - Cyborg food: Press.
  - Overcommit liked, but to be made recognisable and non-infringing (Narrative round 2).
  - Orbs and fusion: re-pitch (Narrative round 2). Keep the pride-for-power mechanic.
- **Active:**
  - Encounter Systems: tempo, launch planner, ocean. The only sim editor right now.
  - Rendering: civilian scale, planet-scale feel.
  - Narrative: round 2 pitches.
- **Standing by:**
  - Game Design: writes the Wounds spec after Orb picks the readout, Rally and downtime.
  - Combat: stage 0/1 after the spec. The composer's code lives in sim/director (Encounter owns it); Combat owns the vocabulary as data.
  - Simulation.
- **Next sim editor after Encounter:** World, one brief covering:
  - rims are gameplay (EP ruling), so the 1D profile gets raised rims and wider, shallower bowls sized by energy;
  - fx events 'crater' (x, ground y, r, depth, energy, cause) and 'scorch' (x, ground y, width, power, variant, owner) with defined energy and power scalars;
  - a persistent crater list in state, for replay seek and snapshots;
  - sim quirk 7 (a crater every 36 units along low beams) replaced by scorch trails that scale with beam power;
  - simple water flow;
  - launched fighters skim water (a sim/core/fighter.gd edit, routed via Simulation if needed).
  Then Rendering draws the crater bowls in depth (the z=0 slice equals the sim) and the scorch trails.
- **Tools, small:** fix the godot-parity comment (it now checks the GD goldens); add a batch.gd 5-match smoke step. QA: move baselines to batch.gd.

## Plan upgrade (2026-09-29)
Orb upgraded the subscription ('more tokens to play with, keep going'). More directors may work in parallel on non-sim tracks. Workflows and ultracode still need Orb's per-task OK (ADR 0005). Newly active: Art (look v0 and the Anti-hero concept), UI & UX (the no-health-bar HUD in ui/), QA (move to batch.gd, Wounds test skeletons), Audio (direction and grunt palettes). Ping Orb whenever a new playable build is live.

## Audio follow-ups (2026-09-29)
- The event list in docs/audio/direction.md §9 goes to Simulation (S1 events) and Encounter (S2). Needed: damage with attacker, victim, region and kind; beam_fire, beam_end and beam_clash; transform, tier_up, heat_stage, boil_over, fold and encore; hide, found, ambush and lock_lost; building and world events.
- Rendering applies audio's 4-line hook in sim_host.gd and main.gd (audio/README.md) after its visual fix.
- Grunt names: Narrative's gesture, intensity and mood names map to Audio's recipes. Narrative owns caption strings; UI displays them.
- Legal: origin rows AUD-GEN-001, AUD-GEN-002 and AUD-PREV-001; screen the beam and Press sound rules (direction.md §5.2 to 5.3).

## Collateral ramp and cap (Game Design §4b)
World builds it with B1: a rolling 60 s budget by tier (evacuation, not deaths, over budget), a cumulative ceiling (10, 30, 60 and 90%), and per-casualty weights times 425/pop0. Narrative and World make evacuation read as fleeing. QA adds the rolling-window test, the ceiling test and the per-tier split.

## QA follow-ups (Game Design)
- Re-baseline the collateral bands after B1.
- If chapters feel thin after S4, run the stricter-brink experiment (core or three limbs broken, k ×1.4).

## Sim editor queue (one at a time; the plan is docs/architecture/wounds-plan.md)
S0 menace fixes (Simulation, active), S1 wear core, then SC world scale plus W-R rim scaling (World first, then Simulation, then Encounter's tempo pass; one golden regen; docs/world/scale.md; about 2,000 bh planet; 10-20 s lap), B1 building depth data (World), LD1 fire and smoke cover (World and Encounter), then (with the ko() hook behind a flag), S2 the end (Encounter), S3a and S3b, S4 Rally, B2 the building brunt (Encounter, World, Simulation; docs/world/buildings-in-depth.md), with B3 building presentation (Rendering, Camera) in parallel after B1, LD2 landslides, then LD3 lava, quakes and rifts (Orb's picks; docs/world/living-destruction.md), then D1 roster as data, then F1: the **Anti-hero** (Orb's pick). W1 (variable circumference) comes before the fold; N1 (N bodies) comes before the Empress.

## Old sim queue notes
1. World: craters, scorch, water (active).
2. Simulation: Game Design's menace placeholder fixes (balance-targets.md §9: decay 0.4/s after 4 s without a villain-caused casualty; menace damage cap from +25% to +15%). Also add tempo.gd to the sim/README layout table.
3. Wounds implementation (spec-wounds.md): Encounter Systems and Combat (stage 0/1). QA re-baselines on batch.gd, then tests KAI at 42% or better, with at least 400 matches per arm.

## Queued for idle directors (send when they resume)
- **Camera:** when separation passes half the planet, the reference camera re-targets the other arc and pans 80 to 180 px per frame. That's a framing choice to fix.
- **Performance:** a min-spec run (old laptop, integrated GPU, mobile), draw-call budgets, and the float-texture vertex fetch on mobile GLES3 (the fallback is packed 8-bit heights).
- **Simulation:** in sim.gd, createSim labels its fx mode 'shared' and rejects 'split', though the docs say det plus split (label only).
- **QA:**
  - Raise the match cap to 900 s for game-scale batches.
  - Split casualties by tier.
  - Run the fixed-stance probe (docs/design/stance-matrix.md §6).
  - Its known-bugs register is mid-way.
- **Combat:**
  - Second outcomes per stance cell (Game Design R3), finisher templates and CUT-IN beats.
  - LANE SWEEP: Game Design supports it for P4 if it plays differently, e.g. a long shallow trench, and Legal screens the name.
  - Use CANOPY BURN and TIDE CLEAVE in place of FIRESTORM and HORIZON CLEAVE.
- **Controls:** the missed-parry cost (5 ki and a 0.5 s lock) and visible windows.
- **Encounter Systems:**
  - The AI attacks from ESCAPE and uses ambushes.
  - Fix where fights happen (69% of beams fire over the ocean) and launch variety.
- **World:** collateral mechanisms that meet the bands in docs/design/balance-targets.md, including a civilian floor for the Cyborg.
- **Narrative:**
  - Names for the ego meters (Respect, Pride, Wrath, Hunger) and for the replacement mechanics.
  - The fighter bible, after Orb picks the replacements.
- **Legal:**
  - Register rows LR-020 to LR-023, once Tools reports.
  - The place-name screen.
  - A final check of the licence files at the repo root.
  - Register Research's dev tools. None of them is in the repo:
    - Godot 4.7.2 export templates (MIT, SHA-512 checked)
    - the Godot 4.7.2 .NET editor and its .NET export templates (MIT; scratch use only)
    - TypeScript 7.0.2 via npx (Apache-2.0; an optional type-check, dev only)
  - Register the CI actions (CI only, shipped nowhere; confirm the licences): actions/checkout v7.0.1 @ 3d3c42e5aac5ba805825da76410c181273ba90b1 and actions/setup-node v7.0.0 @ 820762786026740c76f36085b0efc47a31fe5020. Also the Godot 4.7.2 Linux zip used by the CI parity job.
  - Register @napi-rs/canvas 1.0.9 (MIT, dev-only, optional; github.com/Brooooooklyn/canvas) and its per-platform prebuilt packages (same scope and version; confirm each licence). Pinned in prototype/package-lock.json.
  - The licence files were removed on 2026-09-29 while Orb decides; update the licence register to match.
  - Stages 4 and 5 on the title, once Orb picks.
- **Tools:**
  - Rerun the generator after any charter edit.
  - Add the licence fields, .github/CONTRIBUTING.md and the PR template from docs/legal/contributor-rules.md.

## Open decisions for Orb
- Game Design's G1 to G15 and 29 per-system questions (docs/design/open-questions.md, systems-sketch.md). The most urgent:
  - How a 7-minute match ends.
  - Whether the last segment needs a finisher.
  - Whether a fighter can be hit while transforming.
  - What a human playing the Tyrant controls.
  - Tandem versus Unison.
- Legal's replacement picks (docs/legal/fighter-concepts-review.md); the tyrant's tail; whether fusion becomes a mod or is dropped.
- The README pitch line (docs/legal/public-readiness-edits.md §5).
- The title.
- The copyright holder's name.
- Lemming Ball Z provenance.
- Renaming the repo before it goes public.
- The outcome of Legal's fighter-concept review.
- Answers to questionnaire 2.

## Critical path to something playable
1. **ADR 0001 (engine choice): done.** Godot 4.7 with GDScript, confirmed by Orb on 2026-09-29.
2. **A greybox 1v1 on a wrapped planet.** Port the sim core into the chosen engine, with a greybox 2.5D renderer (Simulation, Rendering & Technical Art) and keyboard and gamepad input (Controls).
3. **Then the content:** polish the stance director (Combat, Encounter Systems, Game Design), then build the four fighters and their transformations.

## Practical notes
- **Messaging.** Send messages with SendMessage to exact session titles ("Meridian - <role>"). Directors reply the same way. Don't subscribe to idle notices.
- **Git.** Only the EP commits. The QA suite is `node qa/run-all.js` on Node 24.19.0.
- **Godot.** 4.7.2 is at C:\Users\itsha\AppData\Local\Programs\Godot\4.7.2\, with export templates installed.
