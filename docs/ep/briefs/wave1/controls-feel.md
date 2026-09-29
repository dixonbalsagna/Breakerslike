# P0 wave 1 brief: controls-feel

From the Executive Producer, 2026-09-28. Prototype line references are pinned to commit 7233c96.

Brief from the EP (P0 wave 1): document how the prototype feels in the hands today, propose gamepad support and buffering, and flag new-player feel risks, all as docs with no code.

GOAL: Produce docs/feel/tuning-table.md, docs/feel/input-map.md and docs/feel/feel-risks.md, so every window, hit-stop and input rule has a cited constant and a proposed target.

CONTEXT (read first):
- docs/directors/controls-feel.md and CLAUDE.md (prototype section, pillar 2, P2 exit criteria).
- prototype/index.html, read only. QA's edit tonight moved every line after 216 down by one, so anchor on function names.
  - Input: KEYS (188), humanInput (801), control (847), the keydown/keyup listeners and the held/edges sets. edges clears each step, and step() returns early during hit-stop, so presses carry through it.
  - Parry: wind() in planMelee (424) sets ex.windowStart. strike() (521, check at 525) parries if the defender's lastAtkT >= windowStart when a strike without noParry lands. control() sets lastAtkT on any light or heavy press (853), even when requestAttack refuses it.
  - The parry window runs from the wind beat to the first parryable strike, not a fixed offset:
    - about 0.10 s in TRADE BLOWS, PRESSURE and GUARD BREAK (wind at t-0.1, strike at t);
    - about 0.33 s in HEAVY CLASH — WON (wind at t-0.05, first strike at t+0.28);
    - no parryable strike in DODGE & READ and DODGE & COUNTER (wind at t-0.12, every strike noParry), HEAVY CLASH — COUNTERED, CLASH SHOCKWAVE, PURSUIT and CHARGE INTERRUPT.
    Verify each from the code.
  - Chain: openWindow (544) sets ex.ext for 0.6 s. dirUpdate (574) chains if lastAtkT >= ext.start, up to 5 hits, 6 ki each, and each link adds 12% damage.
  - requestAttack (390): dirS.cool 0.22 s after an exchange, heavy costs 4 ki, signature 45 ki.
  - Movement and stance: dash x2.4; charge (+30 ki/s, +9 power/s); stance speed multipliers; stance switching is instant, free and has no cooldown.
  - Hit-stop and shake: hit() (319; stop at 334, shake at 335), strike() opts, explode (309), impact (712), guard break (485), clashWave (518), fireBeam (644), tierUp (696), doLaunch (383); DT = 1/60. Enumerate every dirS.stop and cam.shake value per impact class.
  - step() (881-885) consumes dirS.stop with real dt and scales sim dt by game.ts during KO.
- qa/baseline-p0.md section 8: 9.1 parries per 100 melee exchanges (1.46 a match); 24% of exchanges chain (mean length 2.4; x5 is 13 in 1,000 matches); the AI never attacks from ESCAPE.
- docs/legal/originality-rules.md: no hair-colour cues, original poses, no power-level readouts.
- Ownership tonight, all through the EP:
  - You own window widths and the per-impact-class hit-stop and shake table.
  - Camera sets the global shake caps, decay and the user shake scale.
  - Combat documents which templates have windows.
  - Accessibility derives assist widths from your numbers.
  - Netcode defines how hit-stop exists in the sim.
  - Simulation is porting sim/input/ tonight, and ownership passes to you afterwards. Write no code there until the EP says so.

YOU OWN: docs/feel/ and sim/input/ (no code in sim/input/ tonight). Nothing outside them.

ACCEPTANCE CRITERIA:
1. tuning-table.md has one row per mechanic (parry per template, chain, dash, charge, stance switch, attack gating) and per impact class (light, heavy, guard break, parry, chain, clash, beam hit, launch impact, explosion). Columns: prototype value, source function and line, frames at 60 Hz, proposed value, reason. Proposed shake values are marked 'to fit Camera's caps'.
2. Parry and chain windows are stated in ms and frames, derived per template from the wind beat to the first parryable strike. Call out the templates that open a window with nothing to parry.
3. input-map.md lists the P1 and P2 keyboard maps exactly as in KEYS, plus a gamepad proposal (Xbox layout). The proposal gives one-button stance access, such as a stance-cycle button or a hold-and-flick radial, has keyboard parity, and includes a table of each action and its binding.
4. An input-buffering proposal: buffer length in frames, which actions buffer, priority rules, coyote time and forgiveness on the parry press, and a latency budget in ms from input to first visible reaction.
5. feel-risks.md ranks at least six risks for new players, each with a mitigation and a test to confirm. Examples: a 6-frame window against 9.1 parries per 100 exchanges; mash-parry through lastAtkT; windows that open with nothing to parry; an unreadable chain cue; free, instant stance switching.
6. Anything that depends on Orb's pending answers (presentation, platforms, online) is offered as options with trade-offs marked 'Orb decides'.

CONSTRAINTS: No git state changes. Do not edit prototype/ or qa/. Proposals keep the simulation deterministic: fixed 60 Hz step, seeded RNG, no wall-clock timing in the sim. Windows, buffers and hit-stop are whole 60 Hz ticks stored as data values, not hard-coded. The prototype's real-dt hit-stop and game.ts slow-down are hazards to flag, not models to copy. No franchise nods in control names or cues.

RETURN: the standard report (SUMMARY, CHANGES, DECISIONS, NEEDS FROM EP, RISKS, NEXT), sent to me with SendMessage. NEEDS FROM EP lists what you need from Camera, VFX, Combat and Netcode.

## Since this brief was drafted

1. Simulation's module map for sim/input/:
- intent.js: the intent shape {mx, my, dash, charge, light, heavy, sig, stance}
- keyboard.js: KEYS, the prototype's humanInput
- control.js: control(), which handles stance switches, press time for parry and chain, and attack requests

2. Narrative's glossary (docs/narrative/glossary.md) proposes the stance display names PRESS, GUARD, DODGE and ESCAPE. Use them in your input map as proposals.
