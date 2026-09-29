# P0 wave 1 brief: camera

From the Executive Producer, 2026-09-28. Prototype line references are pinned to commit 7233c96.

Brief from the EP (P0 wave 1): write the camera design docs for the wrapped planet tonight, from the prototype's camera, with no code until the engine is chosen.

GOAL: Produce framing rules, comfort limits, a cinematic-moment library and hiding-camera options that a later implementer can build and test without asking you anything.

CONTEXT (read first):
- docs/directors/camera.md (charter) and CLAUDE.md (pillars 1 and 3, the 'Never out of range' rule, known limitation 1 on hidden information).
- prototype/index.html, read only. QA's edit tonight moved every line after 216 down by one, so anchor on function names.
  - cam (196: x, y, z, shake).
  - camStep (870): midpoint via sdx, spanX = |d|+700, spanY = |dy|+500, zoom clamp 0.06 to 1.15, tier factor 0.06 per tier, ease k = 1-0.02^dt, shake decay cam.shake *= 0.02^dt at 879.
  - render (1144): shake applied with Math.random per frame at 1147.
  - w2s (903); parallax from cam.x*pf (915-926); the planet-strip camera box (1133-1135).
  - Constants: W=9600, HALF=4800.
- Shake sources, all written from sim code: damageBuilding collapse (288, 10), explode (309, 16), hit (335, o.shake or 6), doLaunch (383, 10), guard break (485, 12), clashWave (518, 18), fireBeam (644, 14), tierUp (696, 14), impact (712, min(30, sp*0.01)) and clash (896, 7).
- KO sets game.ts = 0.35 (341) until koT > 2.2 (885), which slows the sim itself. Hit-stop is dirS.stop, consumed with real dt in step() (883), and camStep still runs during it.
- Facts to design against: at half-planet separation the prototype zoom is about 0.16. 76% of matches cross the seam, and the largest single-step move is 186 units (qa/baseline-p0.md finding 9 and section 10). 69.4% of beams land over the ocean.
- Hiding: updateHidden (681) and the hidden drawing in drawFighter (988-1023).
- Tonight, in parallel, and reachable only through the EP:
  - Controls owns the per-impact-class hit-stop and shake values; you set the caps they must fit.
  - Netcode defines how hit-stop and slow-motion exist in the sim.
  - Simulation's docs/architecture/overview.md sets the RNG policy, including a cosmetic stream.
  - UI & UX designs HUD elements such as edge indicators.
  - Research runs the information-hiding spike after its engine spike and will score options on your five criteria.
- docs/legal/originality-rules.md: no scanner overlay, no numeric 'power level' text, no franchise nods. Tier-up cues must not use hair colour (RL-014).

YOU OWN: docs/camera/ and render/camera/. Tonight write only docs/camera/. Nothing outside these paths.

ACCEPTANCE CRITERIA:
1. docs/camera/framing-rules.md:
   - the shortest-arc midpoint math using sdx, with a worked example across x=9600/0;
   - the zoom-by-separation and altitude formulas, citing the camStep constants;
   - how both fighters stay readable at 4800 units apart: the minimum on-screen fighter size in px, the lowest zoom you allow, and whether an edge indicator or inset is needed, with the screen space it may use (UI & UX designs it);
   - a testable no-pop rule for the seam covering cam.x, the parallax layers and the planet-strip camera box (note how the box behaves when it straddles the strip's end), plus a proposed test such as a per-frame camera delta bound under 300 units, as in qa/tests/seam.test.js.
2. docs/camera/comfort-limits.md:
   - numeric limits for zoom rate (per second), pan speed, the shake amplitude cap (prototype max 30 units) and shake decay;
   - a user shake scale from 0 to 100% with its default, and a reduced-motion mode;
   - timing policy: hit-stop and KO slow-motion are sim-owned durations in whole 60 Hz ticks (per Netcode's contract, pending). The camera reacts to them and never changes sim time. Any camera-only slow-motion is a render effect that changes neither the number of sim steps nor when input is sampled;
   - shake is cosmetic: it never reads or advances the sim RNG stream, and it uses a cosmetic stream under Simulation's RNG policy, which may be seeded from the match seed so replays show the same shake.
   Mark defaults that depend on presentation 'Orb decides'.
3. docs/camera/cinematic-moments.md defines launch follow, beam wide shot, tier-up push and KO slow-motion. Each has:
   - a trigger (a sim event), duration in seconds and in ticks, framing and zoom;
   - shake numbers within your caps, marked 'to align with Controls';
   - an input-control policy (the player keeps control unless justified) and a cancel or skip rule.
   Add a table mapping each shake write above to the sim event that should replace it in the port, so render reads sim state instead of sim writing camera state. List the event fields you need from Simulation and Encounter Systems for the EP.
4. docs/camera/hiding-camera-options.md compares split-screen, picture-in-picture and fog for hidden fighters. Rate each on fairness, readability, screen cost, netcode fit (under rollback both clients hold full state) and accessibility. Give a provisional ranking and the evidence from Research's spike that would change it. The final choice waits for Research's result and is 'Orb decides' on presentation and platform.
5. Each doc opens with a 5-line summary and lists its open questions for Orb.

CONSTRAINTS: No git state changes. Do not edit prototype or sim files. The camera reads sim state and never writes it. Camera randomness never touches the sim RNG stream. Everything stays original, with no franchise camera tropes copied by name or shot.

RETURN: the standard report (SUMMARY, CHANGES, DECISIONS, NEEDS FROM EP, RISKS, NEXT), sent to me with SendMessage.

## Since this brief was drafted

Research's early spike finding: once the fighters are more than half the planet apart, the framed arc has to flip. That flip is a pan of about 0.5 s during which both fighters are briefly out of frame; everywhere else they stay framed. Give framing-rules.md a rule for it, for example hysteresis, a zoom-out or a split presentation, with the trade-offs.
