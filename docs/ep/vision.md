# Orb's vision (questionnaire 1, 2026-09-28)

Orb's answers to the first scope-and-vision questionnaire, summarised by the EP. Every director reads this before working on anything it touches. Orb's full notes on the fighters are kept locally in .private/orb-answers-2026-09-28.md. They name franchise inspirations, so never quote them into a committed file.

## Tone and feel

**Tone.** All four tones at once: mature violence and destruction on a planetary scale, a humorous voice, and a sincere, respectful homage to the source anime's aesthetics. Orb's line is "staples yes, signatures no".

**Match feel.** A match is the finale of a bitter rivalry after a whole season of build-up, compressed into an epic showdown of seven minutes or more. It has one-liners, carnage, destruction and high stakes, like a full-throttle reimagining of a lost high-octane flash game. It is never two fighters trading aimless jabs from opposite corners. Combat looks choreographed, seamless and exhilarating, and it expresses each fighter's identity at every moment.

**Carried over from the fan-game predecessors:** comedy, free flight, huge arenas, beam struggles, transformations, destruction, playing with friends, and a modding scene.

## The four fighters

These are archetypes. Legal is checking them against "staples yes, signatures no" in docs/legal/fighter-concepts-review.md (pending). Design mechanics so they survive re-skinning.

1. **The Protagonist.** An earnest martial artist with a handful of epic transformations that unlock along parallel tracks. He powers up when a challenger gives everything they have. He fights to protect his loved ones, but his fixation on the fight itself causes massive collateral damage. He has a huge hand-to-hand repertoire, strategic teleports mid-attack, and ends fights with an all-out energy finisher. His unique ability: he gathers scattered artefacts to move the fight somewhere no one else can get hurt. Once there, he reveals his final form.
2. **The Anti-hero.** A brooding rival whose sense of justice comes second to his ego and pride. He has a few epic transformations that boost both his power and his self-importance. His style is brutal and showy: he drags fights out to enforce his own sense of hierarchy, bombards the foe with elaborate energy barrages until they submit, then finishes them by hand. The player chooses whether he wins on his own strength or accepts a fusion item thrown by the Protagonist. Fusing creates a stronger combined fighter with its own visuals and abilities.
3. **The Galactic Tyrant.** He starts by watching from behind two or three autonomous minions, who take turns fighting. Once they fall, he transforms through a comically long chain of stages (ten or more), each with a subtly different moveset, up to a full-power form with its own abilities. He torments foes with precise cutting beams from range and uses tail attacks and dominant power attacks. His personality: confident, leering, boastful and quick to anger.
4. **The Demon Cyborg.** He consumes civilians to power up, each one adding a small multiplicative bonus. He then molts into a form that can turn nearby civilians into sandwiches, which grant further bonuses. His final form requires hunting down and eating his small demon companion, which is hidden somewhere on the planet. In that form he is the fastest fighter of all, blitzing through portals that spew monstrous sandwiches, a light-hearted parody. His body is dark red, wrapped in mechanical wiring and chainmail-like electrical parts. His true vital point is a stylised quantum microchip in a translucent orb; the rest of his flesh regenerates.

More characters must be addable after launch (see the Modding and Extensibility charter).

## Answers

| Topic | Answer |
|---|---|
| Roster at 1.0 | 4 fighters |
| Civilians | Keep casualties |
| Controls | Keep stances and the fight director |
| Modes at 1.0 | Local 1v1, versus AI, arcade or survival, training sandbox, 2v2 or free-for-all |
| Online | After launch |
| Match length | 5+ minutes (the feel above says 7+) |
| Planets | Procedural |
| Presentation | 2.5D side-on |
| Art style | Cel-shaded and low-poly; Art to pitch |
| Asset creation | Procedural; AI-generated assets allowed |
| Music | Audio to pitch |
| Platforms | Windows, Linux, macOS, browser, Steam Deck, mobile |
| Minimum hardware | Old laptops |
| Input | Keyboard and gamepad equally |
| Distribution | itch.io, Steam (free), GitHub releases |
| Licence | As Legal recommends: MIT for code, CC BY 4.0 for assets, DCO for contributors |
| Going public | Now, once the prerequisites are done (licence files, repo name, Legal's wording pass) |
| Timeline | No deadline, hobby pace |
| Reporting | A weekly one-pager |
| Budget | Zero; Pro plan only (ADR 0005) |
| Director effort | Opus at xhigh, Sonnet at high |
| Extra directors | Rendering and Technical Art; Modding and Extensibility |
| Name | An evocative title, pitched by Narrative |

## Questionnaire 2 (2026-09-29)

| Topic | Answer |
|---|---|
| Transformation triggers | Character dependent |
| Protagonist and anti-hero stages | 6 or more |
| Tyrant's forms | Jokes first, then a few real forms |
| Minions | AI only |
| Fusion | A unique final-form mechanic; could be reworked as another ability |
| Relocation | A barren proving ground; artefacts scattered on the planet, found mid-fight |
| Cyborg's companion hunt | A quick detour, under a minute |
| Violence | Graphic, including the Cyborg's consumption. Rating target: Mature |
| Signature replacements | Discuss each with Orb before choosing |
| 2v2 | All four fighters on the field at once |
| Arcade | Both a rival ladder and endless survival |
| Match shape | One continuous fight |
| Endings | KO, or the planet is destroyed |
| Procedural planets | Vary in size, biomes and settlements; seeds are shareable. The planet can be destroyed at top tiers |
| Mobile controls | Both virtual stick and simplified tap, player's choice |
| Copyright holder | Curtis A |
| Repo | Renamed to wraparound-fighter, then to orb-combat-ex when the title was picked |
| Token plan | Approved (ADR 0005) |
| Lemming Ball Z provenance | Unknown; nothing carries over |
| Feel reference | A well-known series of flash action animations (named in .private/) for its choreography and brutality |
| Title (final) | **Orb Combat EX**, picked 2026-09-29. Legal: conditional; resolve the OrbCombat GitHub project before any store page |
| Title history | Orb dislikes "Skyburden" and liked the direction of "Skyburners" (screened out: a Destiny faction). Round 2 sounded machine-made to Orb; round 3 aims for names a person would pick |
| Engine | Godot 4.7 with GDScript (ADR 0001, confirmed 2026-09-29) |
| README line | "A free, open-source fighting game about wrecking a planet. No combo lists: pick a stance and the game choreographs the exchange. Inspired by the classic anime energy-brawlers." (Orb's blend; final wording waits on the licence) |
| Repo visibility | Stays public so Orb can share the prototype with friends |
| Licence | Undecided: Orb may want to keep commercial rights. LICENSE and LICENSE-ASSETS were removed from the repo root on 2026-09-29 (all rights reserved by default until Orb decides; the drafts stay in docs/legal/drafts/). Options in the EP's 2026-09-29 chat: open code with protected art; everything non-commercial; or MIT plus CC BY as now |

## Questionnaire 3 (2026-09-29): gameplay and features

Orb had played the Godot greybox before answering.

| Topic | Answer |
|---|---|
| Greybox pace | Too fast |
| Next priorities | Better fighting feel, the first real fighter, bigger destruction |
| Health | **No health meters.** Location-based damage, where each fighter handles incoming damage slightly differently. Tension and dramatic build-up without traditional bars |
| Finisher | Always: the last blow is a fighter-specific finisher |
| Planet destruction | Pinned. Explore large-scale destruction (molten lava spewing from the mantle) short of full destruction, zero-g combat in space if the planet does go, and how stage transitions work |
| One-liners | Both: barks during play and short pauses at set pieces |
| Cinematics | Yes, and longer than 3 s is fine |
| Ego meters | Yes, visible (Respect, Pride, Wrath, Hunger) |
| Hit while transforming | Long transformations can be interrupted; the Tyrant's quick revisions are safe |
| Transform timing | Per fighter |
| Form duration | Permanent, except drain states |
| Transformations | Power-ups and transformations are genre staples, and Orb wants the space explored further. The beast stage was only an example |
| Multiplier stage | Pitch a replacement |
| Artefacts | Orb wants orbs: find a non-infringing way to include them. A heavy hit scatters one |
| Teleport tell | A ripple in the air |
| Anti-hero fusion | A true merge with an original trigger and look (Legal screens it) |
| Tyrant appendage | Keep a tail, redesigned so it doesn't read as the franchise's |
| Tyrant forms | The numbered "revision" joke |
| Human Tyrant during the goon phase | Snipes support shots and taunts |
| Goons | Three: bruiser, marksman, speedster |
| Cyborg food mechanic | Pitch it |
| Cyborg companion | A backup drive that runs around; he catches and docks it |
| Cyborg weak point | Pitch it |
| Asymmetric roster | Yes, with win rates still 45 to 55% |
| Planets | Earth-like and alien biomes; day and night plus weather; bigger for 2v2 |
| 2v2 revive | Yes, with a risky beat next to the fallen teammate |
| Mirror matches | Yes in 1v1, not on the same team |
| Unlocks | Everything unlocked from the start |

**Greybox notes (Orb's words):** "destructible terrain should look more like craters than canyons, water should have a simple fluid simulation, fighters seem to always fight in the ocean underwater, civilians seem too tiny, more attacks launching each other across the map, make the scale of the map seem more like a full planet"

**Anything else (Orb's words):** "I want procedural systems to create near limitless sets of attacks. Voice lines don't have to be voice-acted, if each character has distinct grunts and growls and laughs those could be used to evoke emotionality of lines that appear on the screen. I want one liners and taunts and reactions that depend on all kinds of variables, so there should be a very large set of lines that can potentially be seen accounting for every situation. the combat director I'm envisioning needs to be able to create extremely vast movesets for each character, with some unique special abilities for each character, but each fight should feel unique, with dynamic combos and attacks that gives the player the sense they're not going to see the same exact series of attacks twice."
**Craters and beams (Orb, confirmed 2026-09-29).** Ground impacts make round bowls with raised rims and ejecta, sized by impact energy. They're localised in depth, not slots through the whole ground strip. Beams scorch and leave trails of destruction, and the results scale up with the beam's power: stronger beams are more intense and more destructive.

**Damage model (Orb, 2026-09-29).** Variant A, Wounds (docs/design/damage-model.md). Game Design pitches: the optional wear readout; Rally rules per fighter (Orb: 'I'm thinking per-fighter'); and the downtime between exchanges. For downtime, the player flies freely, with dynamic set pieces and quick verbal exchanges. Pitch ideas that keep it engaging.

**Signature picks (Orb, 2026-09-29).**
- Cyborg food: Press.
- Cyborg weak point: Rail chip.
- Tyrant's tail: Bladed mantle, a cape with blade hems used like a tail.
- Protagonist power stage: Overcommit, made recognisable but non-infringing (Narrative round 2).
- Orbs: recognisable but non-infringing (Narrative round 2, within Legal's q3-screen §a).
- Fusion: may be replaced by a unique Anti-hero power-up; keep 'sacrifice pride for power'.
- Wear readout: a combination of the aura crown with wound cards and the silhouette, per fighter (Game Design pitches).
- Rally: Game Design's four per-fighter Rallies approved, with looser limits.

**Round 3 answers (Orb, 2026-09-29).**
- Power stage: 'something like his blood goes from heated to simmering to boiling, causing internal damage that adds up but gives big temporary boosts.'
- Anti-hero power-up: keep working. Orb wants it 'recognizable but non-infringing' and asks whether fair-use and parody rules can protect a good-faith tribute (Legal to explain).
- Voices: 'good start, let's work on this further.'
- The orb-payoff question was unclear; the EP is re-asking it plainly.

**Round 4 answers (Orb, 2026-09-29).**
- Hot Blood: the mechanic, cards, look and sound are liked. Names are **pinned**: Orb will think up names later, and they must not sound LLM-generated. Treat all current names as placeholders.
- Anti-hero: Orb likes Drop the Act (1v1) and Humbled. Keep pitching ideas in that theme.
- The orb payoff (the fold to the proving ground): **space folds inward** toward the Protagonist and the planet vanishes around them. It needs an in-world reason, with the hero saying something like 'we can't hurt anyone innocent here'.

**Focus and matchups (Orb, 2026-09-29).**
- **1v1 first.** 2v2 questions (the fold in 2v2, team rules) are deferred.
- Lines change with the matchup: who is facing whom, and what is at stake. The Protagonist is lighter against a sparring rival and more serious against someone threatening to end the world.
- Work the matchups out case by case with Orb.

**Matchup feedback (Orb, 2026-09-29).** 'These are a great start. I want as many possibilities.' Likes: the Tyrant's revision numbers, and the Cyborg asking for a manager. Tone fix for the Protagonist: the fight comes first and the repairs after. Not 'That was a home. I'll fix it. Then I'll deal with you.', but more like 'I'll help fix it once I'm done with you.' Orb read the Anti-hero's 'Fifth.' as a typo for 'Filth'.

**The Tyrant becomes an Empress (Orb, 2026-09-29).** The Galactic Tyrant is now a galactic empress (she/her). Everything else carries over (the revision joke, three goons, the bladed mantle, the surveyor line), and Narrative pitches how she's rewritten. Legal's revision 9 to 12 silhouette and palette rule still applies.

**The Empress, picks (Orb, 2026-09-29).**
- Who she is: 'very image focused, hates to have to change appearances, so has settled on their base form to keep paperwork tidy. Since the fight pushes them to transform, they need to update their paperwork to keep their legal status current. Bureaucratic and confusing on purpose. Let's work on this theme.'
- Goons: Guard of honour.
- Voice: approved (revision numbers, a royal 'we' that slips to 'I' when hurt, opponents are 'petitioner').

**Transformations are respected (Orb, 2026-09-29; this overrides questionnaire 3's 'long ones interruptible').** 'With few exceptions, I think the transformations should be cinematic and uninterruptible. The gauge or some mechanic must fill or otherwise complete, which can be stopped, but once the transformation happens it should be respected the way anime characters seem to traditionally allow their opponent to transform.' Also: the Empress's backdated-filing comeback, Orb is unsure ('I don't know about this'), so pitch alternatives. The rule that her filings don't register in the fold is dropped: her filings work everywhere.

**Empress paperwork is diegetic only (Orb, 2026-09-29).** 'I don't like the idea of visible paperwork or stamps. She could have voice lines about how frustrating it will be to go through the mountain of paperwork later, or some other diegetic clues as to what's going on.' No stamp cards and no visible forms. The paperwork lives in her lines and in in-world clues. The Appeal is not approved: pitch her comeback again without visible paperwork. The fold becomes a respected cinematic (yes, same rule).

**Empress comeback, round 2 (Orb, 2026-09-29).** None of Off the record, Close ranks or Recess approved: 'pitch more ideas. I like a straightforward brawl that must defeat the guards before getting to the empress, damage transference isn't exactly how I imagined the character.' The retinue rule is rejected: fallen guards leave, and the gestures come from her remaining guard or from her.

**Empress comeback: Encore (Orb, 2026-09-29).** On the brink, all three guard return for a short, harder second goon phase while she withdraws, snipes and taunts. If they hold, one region mends; if they fall first, she is on the brink and in reach. Once per match.

**First real fighter: the Anti-hero (Orb, 2026-09-29).** Built after the Wounds slices and roster-as-data (docs/architecture/wounds-plan.md).

**Rims and buildings (Orb, 2026-09-29).**
- Crater rim height depends on how hard the impact is: harder hits throw up taller rims.
- Buildings exist in both the foreground and the background (depth layers). Normal movement never collides with them, and neither do most launches. The director chooses when a launched fighter crashes destructively into a building, and it should often pick an individual building to take the brunt of an impact. This is part of stage design.

**Building impacts (Orb, 2026-09-29).**
- No rooftop cover.
- Targeting is a mix of personality and drama, weighted toward personality: the villain seeks tall, occupied towers and the hero avoids occupied ones.
- One impact can go through several buildings: 'a classic villain trope is to send the hero careening through multiple skyscrapers in one attack.'
- Anguish weight: Game Design's default (no extra multiplier) stands unless Orb says otherwise.

**Life-size scale (Orb, 2026-09-29).** 'Right now everything looks very small compared to the fighters. I'd like to see a much larger world with buildings and civilians scaled up to be life-size compared to the fighters.' World is drafting docs/world/scale.md, to land before building-depth slice B1.

**Scale answers (Orb, 2026-09-29).**
- Planet size between small and medium ('between 1 and 2', maybe larger after it's felt). Fighters should launch each other through the landscape and into different biomes several times per fight.
- A flat-out dash around the planet takes 10 to 20 s: anime-fast.
- Destruction: 'as the fighters power up, the destructiveness should keep scaling. Implement novel ways to keep this interesting so the players don't just see it as map painting, but rather interfering and actively engaging with a real landscape.'

**Living destruction picks (Orb, 2026-09-29).** From docs/world/living-destruction.md: fire and smoke cover (with cover made and taken), landslides, and the top-tier set: lava, quakes and rifts. Build order: LD1 fire and smoke, then LD2 landslides, then the tier-4 lava, quakes and rifts, leading toward the pinned planet-destruction finale.

**Blast-levelled buildings (Orb, 2026-09-29).** When an impact or ground blast craters a city, the buildings it levels collapse into their own footprint like a controlled demolition, and leave rubble behind.

**Knockback slide (Orb, 2026-09-29, after playing the craters build).** Orb likes the craters build. Against ground, a launched fighter shouldn't bounce and leave several craters. Impacts should be weighted toward a **knockback slide**: 'a character is hit with immense force or is braking from high-speed movement, dragging their feet or hands along the ground to stay upright, which leaves a deep trench, shatters concrete, and kicks up massive clouds of dust.' On water, a shallow incline skips the fighter across the surface (bouncing is good there). Orb also noted 'some visual peculiarities we can touch up'.

**Audio picks (Orb, 2026-09-29).** Grunts are synthesised first, and Orb may record laughs and the munch later. AI-generated audio is allowed once Legal clears the specific tool's terms. Wear and heat audio is on by default, with a slider. The music direction will be picked by ear from Audio's three 30-second sketches.

**Anti-hero look, round 1 (Orb, 2026-09-29).** None of Art's three silhouettes (Column, Bell, Standard) picked yet: pitch more. No cape. Shed Regalia: pitch it later. The music pick is pending until Orb listens.

**HUD clutter (Orb, 2026-09-29).** The aura crown rings should pop up for a moment when something happens (a hit, a stage change), then fade back. No persistent clutter in the way of the fight choreography. 'Let's revise this because it looks like a good start.'

**Character art direction (Orb, 2026-09-29).** F, the Coil, is 'a good start' for the Anti-hero. Orb isn't happy with the character designs yet and wants them **striking and recognizable**, with more style passes. Faceless or blank heads could be a style choice if the style is distinct enough. Art proposes several overall character art directions. Legal's note stands: nothing borrowed from Madness Combat's look.

**Character art direction, round 2 (Orb, 2026-09-29).** Blank is the closest and a good starting point. Pitch more styles and mock-ups building from it. Faces: pitch it, Orb wants a unique style. Poster: disliked ('the color scheme is too jarring'), and its use for key art is undecided.

**Staging the fighters: cheat out (Orb, 2026-09-29).** No strict side profile. Fighters turn slightly toward the camera, three-quarter, as stage actors 'cheat out', so stances, chest designs, limbs and demeanour read. Three techniques, as in modern 2.5D fighters:
1. Rotate the torso, hips and head toward the camera.
2. A hybrid projection: the background keeps perspective, and the fighters get an orthographic-style correction so they don't warp at the screen edges.
3. Mirroring when fighters switch sides, so the front always faces the camera and the back is never shown.
Orb also referenced 'downstage' stage power: being nearer the camera reads as commanding.
