# Meridian (working title)

An original fighting game in the anime energy-brawler tradition: free flight, beam struggles, transformations and planet-scale destruction, with every character, name and asset our own. Free and open source. Owner and creative lead: Orb.

The names Meridian, KAI and VORR are placeholders, and Orb wants a completely different name for the game. Everything in this project must be original: no characters, names, designs, catchphrases, music or code from existing franchises. The genre is the inspiration, not the content.

## How this project runs

Orb (owner) → Executive Producer → 24 directors. Every director answers directly to the Executive Producer, and every role runs as its own Claude Code session in this folder (ADR 0002). DIRECTORS.md has the full roster.

- **Your role comes from how your session started.** Directors start with `/director <slug>` and follow their charter in `docs/directors/<slug>.md`. The Executive Producer is the session titled "Meridian - Executive Producer" and follows `docs/ep/playbook.md`. A session with no role asks Orb before doing anything.
- **Chain of command.** Directors take briefs only from the EP and report only to the EP. They never message or delegate to each other; anything cross-director goes under NEEDS FROM EP, and the EP routes it.
- **Messages.** Briefs and reports travel with SendMessage between session titles. Text written in your own session is not seen by any other session. Every session runs in Auto permission mode so messages are not held for approval.
- **Files and git.** All sessions share this folder. Directors edit only their owned paths and never change git state. The EP reviews each deliverable, commits it and records significant decisions as ADRs in `docs/decisions/`.
- **Pacing.** The activation schedule in DIRECTORS.md decides who is briefed in each phase. A session with no brief stays idle.
- **Escalation.** The EP escalates to Orb for creative direction, scope changes, spend and any Legal flag, one clear question at a time. Orb may also talk to any director directly.
- **Token discipline (ADR 0005).** The project runs on a Pro plan with zero budget. Don't use workflows or ultracode unless the EP says Orb approved it for the task. Read only the files your task needs, and keep reports short.
- **Orb's vision.** docs/ep/vision.md records Orb's answers on tone, fighters, modes, platforms and more. Read it before any work it touches. Never commit franchise character names as design references.

### Delegation brief template
```
Goal: one sentence
Context: files to read first
You own: paths you may change
Acceptance criteria: testable list
Constraints: determinism, originality, budgets
Return: the standard report format (SUMMARY, CHANGES, DECISIONS, NEEDS FROM EP, RISKS, NEXT)
```

## Design pillars

1. **The planet is the arena.** The world wraps. No walls, no corners, no side of the screen to be cornered on. Fly either way and you loop the planet.
2. **Stances, not combos.** The player chooses intent (aggressive, defensive, evasive, escape). A procedural director choreographs the exchange that results.
3. **Never out of range.** Distance never blocks drama. Attacks always close the gap, and the escape stance is a real gamble rather than a range check.
4. **Power has weight.** Terrain, buildings and civilians are damaged by fights, and damage escalates with power tier.
5. **Characters are personalities.** The hero and the villain do different things to the world. The hero is pressured by collateral damage (anguish). The villain feeds on it (menace).
6. **Fights tell stories.** Hiding to recover, ambushing from cover, comebacks, chains and clashes emerge from systems, not scripts.
7. **Signatures adapt.** One signature move plays out differently by biome, altitude and the defender's stance.

## Architecture (three layers, keep them separate)

- **Player layer.** Input to intent: movement, stance, attack request, charge. Deterministic, replayable.
- **Director layer.** Takes an attack request and the current world and composes an exchange from authored atoms: template selection, beat scheduling, launch planning with scored candidates, parry and chain windows. Every decision is explainable via a debug feed.
- **World layer.** Wrapped heightfield terrain with deformation, biomes, destructible structures, civilians, particles.
- **Rules.** Simulation is fixed-timestep and seeded-RNG only. Rendering reads sim state and never writes it. All distances use shortest-arc wrap math.
- **Content is data.** Atoms, exchange templates, fighters and biomes are data files, not code.

Engine: **Godot 4.7 with GDScript** (ADR 0001, confirmed by Orb on 2026-09-29). No C# in the shipped game, because C# can't export to the browser. The Compatibility renderer is the baseline. The sim stays engine-agnostic (float64, our own trig and RNG), and the JS core in sim/ is the parity oracle for the GDScript port.

## The prototype (prototype/index.html)

A single-file HTML/JS canvas prototype, no libraries. Open it in a browser. It starts as an AI-vs-AI demo; any key hands P1 to a human.

- P1: WASD move, Space dash, F light, G heavy, R signature (45 ki), Q hold to charge, 1 2 3 4 stances.
- P2: arrows, Enter dash, comma light, period heavy, slash signature, semicolon charge, 7 8 9 0 stances.
- System: N new match, T toggle P2 AI, Y toggle P1 AI, P pause.

### What it demonstrates
- Wrapped planet, 9600 units around, 1200 columns of 8 units. Biomes in order: ocean, harbour village, plains, city, outskirts village, forest, desert, mountains, far village, plains, ocean.
- Deformable terrain with craters. Water only where the original base terrain is below sea level.
- About 47 destructible structures and 425 civilians. Casualties feed VORR's menace and KAI's anguish.
- Four stances with a director that selects exchange templates by attack type versus defender stance: trade blows, pressure, guard break, dodge and read, dodge and counter, pursuit (slips away or caught), heavy clash (won, countered, shockwave), charge interrupt.
- Parry window (defender presses attack during the wind-up) and chain window (attacker presses attack again after a hit, up to 5).
- Launch planner: scores UPPERCUT, SLAM DOWN, SMASH ACROSS, BUILDING SMASH, MOUNTAINSIDE with noise, a variety penalty and a personality term (hero avoids populated areas, villain seeks them). Top three scores are printed in the feed.
- Signature beam with biome variants (HORIZON CLEAVE, BOULEVARD RAZE, FIRESTORM, RIDGE BORE, GLASS TRENCH, MERIDIAN SCAR) and outcomes CLASH, GUARD, DODGE, HIT, ESCAPE. Beams carve terrain and structures along their path.
- Power tiers 1 to 4. Powering up at ground level craters the terrain.
- Hiding: escape stance in cover (submerged in the ocean, forest canopy, mountain ridge) suppresses the power signature, denies the opponent's lock-on and recovers HP and ki quickly. Leaving cover after 1.8s or more grants an ambush (x1.5 damage) on the next attack within 2.5s.

### Code map (all in the one script)
World and terrain: `wrap`, `sdx`, `biomeAt`, `genWorld`, `groundY`, `seaAt`. Destruction: `crater`, `casualty`, `damageBuilding`, `damageArea`, `explode`, `popNear`. Damage: `hit`, `hurt`, `ko`. Launch planner: `chooseLaunch`, `doLaunch`. Director: `requestAttack`, `planMelee`, `strike`, `launchBeat`, `openWindow`, `chain`, `endEx`, `dirUpdate`. Beams: `planBeam`, `startClash`, `fireBeam`, `sampleBeam`, `beamStep`. Hiding: `coverAt`, `nearestCover`, `updateHidden`. Fighters: `stepFighter`, `stepLaunched`, `impact`, `stepRush`. Input and AI: `humanInput`, `aiInput`, `control`. Loop: `step`. Rendering: `render` and the `draw*` functions.

### Headless QA tools
`prototype/tools/sim-stats.js` runs AI-vs-AI batches with no dependencies: `node prototype/tools/sim-stats.js 60`. `tools/screenshot.js` saves a PNG (needs `npm i @napi-rs/canvas`).

### Findings from testing (80 to 150 AI-vs-AI matches)
- Match length averages about 55 to 60 seconds (range about 25 to 140).
- Collateral averages about 35 to 40 percent of civilians and about 12 to 14 of 47 structures.
- Win rate is about 55 to 65 percent for VORR. A mirror match (identical stats) still gave the first slot a small deficit (about 44 percent), so some of the skew is ordering. Treat as a starting point for QA, not a verdict.
- The hero AI now lures fights out of the city (this cut collateral from about 60 to about 39 percent). Side effect: most beams and launches now happen over the ocean. Needs variety.
- Launch variety is dominated by SLAM DOWN and UPPERCUT when no building or mountain is close.
- Hiding works: hidden fighters can recover for many seconds and ambush. Hunters search around the last known position with random offsets.

### Known limitations of the prototype
1. Hidden information is not modelled. Both players see the same screen; hidden fighters are drawn faded and only lose the opponent's lock-on. Real hiding needs split-screen or fog (Research spike).
2. Characters are procedural shapes. No sprites, rigs or real animation atoms. Motion warping is approximated with position tweens.
3. No audio.
4. Terrain deformation is a capped heightfield with no rim, debris volume or water flow. Trees are only destroyed, not burned.
5. Human versus human play was tested only with scripted input, not real playtesters.
6. Everything is one script with closures. It needs modules, tests and data files before it is a foundation.
7. Only two fighters. Four are planned.

## Roadmap and exit criteria

- **P0 Foundations.** Engine decision (ADR), repo, CI, data schemas, sim core skeleton with seam-crossing tests, originality rules. Exit: fresh clone builds in one command; headless sim runs 1000 matches without error.
- **P1 Wrapped world and camera greybox.** Wrapped terrain, camera framing across the seam, two boxes flying. Exit: no visual or logic pop at the seam at any separation.
- **P2 Stance director.** Three then four stances, atoms, exchange templates, parry and chain windows, opponent AI. Exit: every stance pairing has at least two authored outcomes; decisions visible in a debug feed; seeded replays reproduce.
- **P3 Terrain, collateral and menace.** Deformation, structures, civilians, hiding and ambush, menace and anguish. Exit: escalation reads clearly across tiers; no fight destroys the planet at low tiers.
- **P4 Signatures and four fighters.** Signature composer with contextual variants, four distinct fighters, personalities in the director. Exit: no signature plays the same way in two contexts; QA balance within target.
- **P5 Art, audio, online, polish.** Final art, animation, VFX, music, accessibility, rollback online, marketing. Exit: budgets met, accessibility checklist passed, Legal clear.

## Conventions and definition of done

- Every change keeps the sim deterministic: seeded RNG, fixed step, no rendering state in the sim.
- Numbers live in data, not code.
- A task is done when it meets its acceptance criteria, the headless sim still runs clean, and the deliverable is documented in the owning director's docs folder.
- Suggested layout (adjust with the engine ADR): `sim/`, `data/`, `render/`, `ui/`, `audio/`, `net/`, `tools/`, `art/`, `qa/`, `research/`, `docs/`.
- Commits are small and named for the outcome. Reference the ADR number when a decision drove the change.

## Orb's answers and open questions

Orb answered the first scope-and-vision questionnaire on 2026-09-28 (docs/ep/vision.md). In short:
- 2.5D side-on presentation.
- Four fighters with transformations.
- Matches of five minutes or more.
- Procedural planets.
- Online play after launch.
- Platforms: Windows, Linux, macOS, browser, Steam Deck and mobile, down to old laptops.
- Licence as Legal recommends.
- Zero budget (ADR 0005).

Still open:
- The title (Narrative's round 2 pitch, with Legal screening).
- The licence: Orb is reconsidering MIT and CC BY 4.0 to keep more commercial control.
- Legal's review of the fighter concepts.
