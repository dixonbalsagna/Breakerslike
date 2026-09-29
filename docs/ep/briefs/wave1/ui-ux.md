# P0 wave 1 brief: ui-ux

From the Executive Producer, 2026-09-28. Prototype line references are pinned to commit 7233c96.

Brief from the EP (P0 wave 1): tonight you write the first UX specs: the HUD (including hiding-mode HUD options), the debug overlay layout and the menu flow. Specs only; no ui/ code until the engine is chosen.

GOAL: Give every later engine, camera and art decision a concrete, legible HUD and menu target that a new player can read without a tutorial and that never clutters the fighters.

CONTEXT (read first):
- docs/directors/ui-ux.md (charter), CLAUDE.md (pillars; prototype section; known limitation 1 on hidden information), docs/legal/originality-rules.md (Logos and UI row, power-level row, 'ki' row) and review-log.md RL-014.
- prototype/index.html, read only. Lines after 216 moved down by one tonight. drawHUD() and bar() are at about lines 1096 to 1143. Audit the HUD as it stands:
  - bw = clamp(vw*0.32,150,380); the HP bar is 12px, green/amber/red at 50% and 25%; the ki and power bars are 7px;
  - 'TIER n' and the MENACE/ANGUISH labels at 10px; CIVILIANS LOST at 12px; STRUCTURES LOST and CRATERS at 11px;
  - the banner;
  - the planet strip (1129 to 1135), built from SEG and BCOL, with the camera box, fighter dots, '?' for hidden fighters and dead-building ticks;
  - fighter labels and the 'HIDDEN' ripple in drawFighter() (984).
  What is missing: no parry-window or chain-window cue (openWindow sets ex.ext for 0.6 s, and some templates open a parry window with nothing parryable); no ki cost shown on the signature (45 ki); stance is text only. STN and STS are the stance names, and the key maps are in KEYS.
- Director legibility today is the DOM feed() list (14 lines, tag plus sub) and chooseLaunch's top-three scores.
- The debug overlay is split tonight. Encounter Systems writes docs/director/debug-overlay-spec.md (what the overlay must show: which decisions, which fields, their meaning) and decision-log-format.md. You write the presentation: layout, toggle, scrub and legibility. You cannot see their work tonight; use placeholders and list your assumptions.
- Game Design writes docs/design/modes.md tonight. The menu flow uses it as a placeholder, not a mode list of its own.
- Art owns the palette, and VFX and Accessibility propose colour lanes tonight. Specify colours as semantic roles with contrast needs; hex values are provisional.
- The prototype hero's hair was '#ffd54a' (RL-014); QA changed it to '#22c7a9' tonight. Neither is a design, and no hair-colour cue appears anywhere.
- qa/baseline-p0.md: matches average 55 s, so menu-to-fight friction matters. The AI never attacks from ESCAPE, and DEFENSIVE has one outcome per attack kind; the overlay should make this visible.
- Hiding depends on Research's information-hiding spike and Camera. Do not pick a winner.

YOU OWN: docs/ux/ (and ui/, but do not create anything in it tonight). Nothing outside these paths.

ACCEPTANCE CRITERIA:
1. docs/ux/hud-spec.md audits each prototype HUD element (keep, change or cut, with a reason) and proposes a layout for 1920x1080 and for 1366x768: pixel or percent sizes, minimum text size, safe-area margins and a fighter-clear zone. Tiers show as pips or bars, with no numeric 'power level' text.
2. The HUD spec adds stance display, parry and chain window cues, the signature-ready state and a hidden or lost-lock indicator, each with an unaided-discovery rationale. No cue is colour-only: shape, icon or motion carries it too. Colours are semantic roles, with hex provisional pending Art. It lists the states the Accessibility director should review (colour-only cues, motion, text size), sent through the EP.
3. docs/ux/debug-overlay.md gives the layout, the toggle and a pause-and-scrub concept for showing director decisions (template chosen, launch candidates with scores, window opened and why, hide or ambush, beam outcome). Every data field is marked {PLACEHOLDER: from decision log}, and the list of decisions is labelled 'assumed, to reconcile with Encounter's debug-overlay-spec.md'. It ends with a field wish-list for the EP to route.
4. docs/ux/menu-flow.md is a skeleton: title, character select, pause, settings, results. Give a screen flow, the purpose of each screen and its open questions. Modes appear as {modes: from docs/design/modes.md}. Online and platforms are marked 'Orb decides', with options and trade-offs.
5. hud-spec.md has a section on the HUD implications of each hiding option (split-screen, picture-in-picture, fog): layout changes, what the planet strip shows, and the risk to the fighter-clear zone. The options are compared, with no recommendation locked. If Camera needs edge indicators for distant fighters, the HUD reserves space for them; say where.
6. A short 'controller and keyboard prompts' note lists what you need from Controls and Game Feel, through the EP.

CONSTRAINTS: No git state changes. Original UI only: no scanner or franchise-style HUD, no borrowed fonts or logos, and no hair-colour cues. Use 'ki' only as an internal label, and mark the player-facing term 'Narrative proposes'. The game name is a placeholder. Specs must never require the HUD to write to simulation state or draw from the sim RNG, so the sim stays deterministic and QA-002 is respected.

RETURN: the standard report (SUMMARY, CHANGES, DECISIONS, NEEDS FROM EP, RISKS, NEXT), sent to me with SendMessage.

## Since this brief was drafted

1. Narrative's glossary (docs/narrative/glossary.md) is the proposed source for every on-screen term:
- Stances are PRESS, GUARD, DODGE and ESCAPE.
- Ki becomes Charge.
- Tiers are shown as four pips.
- Several banners are renamed.
It also flags that HEAVY CLASH — WON / COUNTERED doesn't say whose win. Section 12 lists dev text that names the prototype (the window title, "take over as KAI", the help text); strip it before any public capture.

2. Narrative asks for an optional region label on the planet strip (docs/narrative/places.md). It also suggests terms live in a data table, so that changing the tone is a data swap.
