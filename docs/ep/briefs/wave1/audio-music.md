# P0 wave 1 brief: audio-music

From the Executive Producer, 2026-09-28. Prototype line references are pinned to commit 7233c96.

Brief from the EP (P0 wave 1): tonight you write the four audio design docs that turn the silent prototype into a specified soundscape and give Legal a sourcing plan.

GOAL: Give every prototype gameplay event a distinct, prioritised sound spec, an adaptive score driven by tier, menace and collateral, a mix, and zero-budget sourcing options with their licence implications.

CONTEXT (read first):
- docs/directors/audio-music.md (charter) and CLAUDE.md (pillars 4 and 5; 'Known limitations' item 3: no audio today).
- prototype/index.html, read only. Lines after 216 moved down by one tonight, so anchor on names. Events to catalogue:
  - hit() (o.big, o.stop, o.shake) and the strike() parry;
  - banner() texts: GUARD BREAK, PARRY, CLASH, BEAM CLASH, ESCAPED, AMBUSH FROM COVER, LOCK LOST, n HIT CHAIN, POWERS UP TIER n, K.O.;
  - planBeam/fireBeam: charge 0.8 s, beam life 0.95 s, outcomes CLASH/GUARD/DODGE/HIT/ESCAPE, six variants;
  - explode(), clashWave(), crater(), damageBuilding() (h > 200 collapse), casualty(), doLaunch();
  - impact() (sp > 350 crater, splash if seaAt); stepLaunched() water entry and building hits;
  - tierUp() (ground versus airborne), updateHidden() (hide, found, ambush window), stepRush() afterimage dash;
  - ko() (game.ts 0.35 slow-motion) and dirS.stop hit-stop.
- Drivers: fighter.tier (1 to 4), villain menace and hero anguish (0 to 100), world.casualties / world.pop0, cam.shake and cam.z. Distance uses sdx() shortest-arc wrap. Altitude is f.y versus groundY().
- qa/baseline-p0.md: 69.4% of beams land over the ocean, so ocean and splash variants matter. Matches average about 55 s to KO, so the score must escalate within one minute. SLAM DOWN is 46.4% of launches, so it needs several variants.
- Legal files:
  - docs/legal/licence-register.md Part C: CC BY 4.0 and CC0 are accepted for audio; NC and unlicensed material are rejected;
  - Legal is creating docs/legal/asset-origins.md tonight as the single origin log, replacing Part B. Keep no register of your own;
  - originality-rules.md: audio checklist, no sound-alikes, no ripped clips;
  - licence-recommendation.md section 8: AI disclosure.
- Netcode is defining how hit-stop and slow-motion exist in the sim tonight (whole ticks). Audio follows the sim and never changes its timing.
- Dependencies: none blocking. The QA-004 event log (Simulation's envelope, Encounter Systems' director events) becomes your cue source; list the event names you need under NEEDS FROM EP. Barks come from Narrative, so reserve bark slots only.

YOU OWN: audio/ and docs/audio/. Tonight write only docs/audio/. Nothing outside them.

ACCEPTANCE CRITERIA:
1. docs/audio/sfx-events.md: a table of at least 40 events. Columns: ID, prototype trigger (function and condition), priority, layers, distance falloff using the wrap-aware sdx() distance, altitude behaviour (ground, air, underwater, high altitude), variants (biome, tier, stance), and a 'confusable with' column naming the nearest other event and the layer, pitch or envelope that tells them apart. Include the hidden and ambush cues: suppressed signature, lock lost, found, ambush.
2. docs/audio/adaptive-music.md: at least 5 layers, with entry and exit rules from tier, menace and collateral fraction; crossfade timing; and a worked timeline of a 55 s match. Include KO and comeback stingers and a tempo, key and stem plan. It must be original and name no franchise themes.
3. docs/audio/mix.md: a priority ladder (barks, critical combat, beams, destruction, ambience, music), ducking rules, a voice cap, loudness targets in LUFS, and hit-stop and slow-motion behaviour that follows the sim's tick-based timing.
4. docs/audio/sourcing-options.md: at least four options (volunteers, procedural or synthesised, CC0 and CC BY libraries, AI-assisted). For each: cost, quality, licence, the Legal risk, and which fields of Legal's asset-origins.md it must fill. Mark AI-dependent choices, and presentation-dependent choices (2D, 2.5D, 3D spatialisation), 'Orb decides', with a default.
5. Consistency: every event ID used in adaptive-music.md and mix.md exists in sfx-events.md, and each event has the same priority in sfx-events.md and mix.md. Each doc says this check was done and ends with its open questions.

CONSTRAINTS: No git state changes. Everything original: no sound-alikes of any franchise theme, charge-up or beam, and no voice clips. Audio reads sim state and never writes it. It never draws from the sim RNG (QA-002), and any procedural variation uses its own seeded generator. Numbers live in data, so express them as tables ready to become data files. Stay engine-agnostic until ADR 0001 lands.

RETURN: the standard report (SUMMARY, CHANGES, DECISIONS, NEEDS FROM EP, RISKS, NEXT), sent to me with SendMessage.

## Since this brief was drafted

Narrative's fighter sketches (docs/narrative/fighter-sketches.md) give the voice direction:
- The hero speaks in the future tense ("I'll be back with hands").
- VORR speaks in the past tense about things still standing: a witness, not a boastful emperor.
Tone is pending Orb.
