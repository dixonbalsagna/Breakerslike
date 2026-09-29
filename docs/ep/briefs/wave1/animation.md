# P0 wave 1 brief: animation

From the Executive Producer, 2026-09-28. Prototype line references are pinned to commit 7233c96.

Brief from the EP (P0 wave 1): tonight you turn the prototype's position tweens into a written clip list, a set of warping rules and a rig/retarget options paper, so animation is specified before any rig exists.

GOAL: Give Combat, VFX, Tools and Simulation a precise, timing-safe animation contract (clips, beats, warp ranges) without changing any gameplay timing.

CONTEXT (read first):
- docs/directors/animation.md (charter) and CLAUDE.md sections 'Architecture', 'Code map' and 'Known limitations' (item 2: motion warping is approximated with position tweens; characters are procedural shapes).
- prototype/index.html, read only. Lines after 216 moved down by one tonight. It is tonight's source of truth for atom timings; the fixed step is DT = 1/60.
  - planMelee() (418): gap-close is rush() with duration rt = clamp(dist/2600, 0.18, 0.65) and a standoff offset of 58. Pursuit uses offset 260 for rt*0.8.
  - chain() rushes 0.24 s at offset 60, strikes at +0.26 and launches at +0.3.
  - stepRush() (745) moves x by sdx*dt/rem (shortest-arc wrap) and y toward the target, clamped to groundY.
  - Strike beats per template: t for most templates; t+0.16/0.32 (PRESSURE); t+0.2/0.42 (GUARD BREAK); t+0.17/0.34/0.51/0.72 (TRADE BLOWS); t+0.28 (HEAVY CLASH). LAUNCH comes 0.04 to 0.05 s after contact.
  - Dodge is an instant reposition to A.x - face*74, plus afterimage().
  - Hit-pause is dirS.stop: 0.05 by default, 0.08 to 0.16 for heavy hits and beams; particles run at 0.1x.
  - chooseLaunch() (359) has five launch types: UPPERCUT (ux 0.25·face, uy 1.0), SLAM DOWN (ux 0.2·face, uy -1.25), SMASH ACROSS (ux face, uy 0.18), BUILDING SMASH (ux ±1, uy 0.12, lands at the building) and MOUNTAINSIDE (ux ±1, uy 0.05, lands 520 away). The last two can go either side, so there are up to seven candidate vectors.
  - doLaunch() (377) applies force·(1+0.16·(tier-1)) with forces of 800 to 2600, and spins the target R(8,16).
  - planBeam(): 0.8 s charge, a rise of clamp(dist*0.22, 90, 300) over 0.55 s, beam life 0.95 s. startClash() lasts 1.6 s, followed by clashWave().
  - ko() (339) sets game.ts to 0.35, then launches at 1800.
- groundY(x) is what feet must follow: 8-unit columns, deformed by craters.
- docs/legal/originality-rules.md and review-log RL-014: original charge and fire poses (no cupped hands at the hip, no two fingers to the forehead, no raised-arms orb), and no hair-colour power cues.
- qa/baseline-p0.md: SLAM DOWN is 46.4% of launches, so the slam clip is the most-played launch and needs the most variants.
- Dependency: Combat is writing docs/combat/move-grammar.md tonight and decides atom timings, warp targets and names. Use the prototype atom names (rush, strike, block, dodge, counter, launch, chase, slam, beam, clash, KO). Where the prototype has no distinct function for one (block, counter, chase), cite the beat that stands in for it or say there is none. Mark every timing 'provisional until Combat's move grammar', and list every name you expect Combat to rename under NEEDS FROM EP. Do not wait.

YOU OWN: art/animation/ and docs/animation/. Nothing outside them.

ACCEPTANCE CRITERIA:
1. docs/animation/clip-list.md has one row per atom above, with anticipation, contact and recovery beats in seconds and 60 Hz frames, each cited to the prototype beat or constant. Add hit-pause data and a pose-data field list in two parts:
   - render-only pose data, never read by the sim;
   - any timing or contact data the sim would read. This becomes part of Combat's atom contract and Tools' atom schema, and a change to it is a sim change that re-baselines QA's golden hashes.
2. Clip durations fit the prototype beat times unchanged. Where a clip cannot, flag a Combat request through the EP.
3. docs/animation/warping-rules.md: how one rush clip serves rt from 0.18 to 0.65 s and any distance; how the slam and the other launches warp to the five launch types and their seven candidate vectors; min and max cases; and the foot-plant rule on sloped groundY, including across the seam.
4. docs/animation/rig-options.md: 2D skeletal against 2.5D against 3D, each with trade-offs, a retarget standard for four fighters, and a personality-override scheme. Mark every presentation-dependent choice 'Orb decides', and recommend a default.
5. Pose sketches described in words only, each with a one-line originality check.
6. End with a five-item open-questions list.

CONSTRAINTS: No git state changes. Everything original. Clips never change gameplay timing. The sim stays deterministic, so animation reads sim state and never writes it; render-only data never feeds the sim. Do not edit prototype/ or data/.

RETURN: the standard report (SUMMARY, CHANGES, DECISIONS, NEEDS FROM EP, RISKS, NEXT), sent to me with SendMessage.
