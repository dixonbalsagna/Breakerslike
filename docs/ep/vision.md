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
