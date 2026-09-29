# Places: the planet and its regions

Owner: Narrative and Fighter Identity. Version 1, 2026-09-28 (P0 wave 1c). Draft for the EP. Names are proposals; nothing is in the prototype or in data yet. Not a clearance.

Tone tags: **Epic** = earnest epic. **Humour** = heroic with humour. **Comedy**. **Dark**. Orb's tone answer is still pending, so each entry has options, and my pick is tone-neutral unless it says otherwise.

## 1. The layout I named

Read from `SEG` (`prototype/index.html:118`) and the `row()` calls in `genWorld` (`:169`). The layout is identical at commit 7233c96 and at the current head. The world is 9,600 units around. I replayed the seeded generator (`mulberry32(4242)`) to count structures and civilians per region: 47 structures and 425 civilians in total, matching CLAUDE.md.

| # | Biome | Span (x) | Width | Share | Built and lived in | Role in play |
|---|---|---|---|---|---|---|
| 1 | Ocean | 0 to 1,200 | 1,200 | 26% together with #11 | Nothing | Hiding cover (submerged). Where most beams land today. |
| 2 | Harbour village | 1,200 to 1,800 | 600 | 6% | 7 houses, 25 people | Populated ground. |
| 3 | Plains | 1,800 to 2,350 | 550 | 6% | Nothing | Open ground. |
| 4 | City | 2,350 to 3,850 | 1,500 | 16% | 27 towers, 351 people (83% of all civilians). Tallest tower at x = 3,100, 533 units high. | The Hero lures fights away from x = 3,100. VORR seeks it out. |
| 5 | Outskirts village | 3,850 to 4,500 | 650 | 7% | 8 houses, 28 people | Populated ground. |
| 6 | Forest | 4,500 to 5,500 | 1,000 | 10% | 33 trees | Hiding cover (canopy). |
| 7 | Desert | 5,500 to 6,500 | 1,000 | 10% | Nothing | Open ground. |
| 8 | Mountains | 6,500 to 7,600 | 1,100 | 11% | Nothing. Peak envelope centred at x = 7,050. | Hiding cover (ridge). Launch target. |
| 9 | Far village | 7,600 to 8,000 | 400 | 4% | 5 houses, 21 people | Populated ground. |
| 10 | Plains | 8,000 to 8,300 | 300 | 3% | Nothing | Open ground. |
| 11 | Ocean | 8,300 to 9,600 | 1,300 | (with #1) | Nothing | As #1. |

Two facts that shape the naming:

- **Rows 1 and 11 are one sea.** The wrap seam (x = 0 and 9,600) sits in the middle of it, 1,300 units from the shore at 8,300 and 1,200 from the shore at 1,200. It needs one name, and nothing should mark the seam (pillar 1).
- **The two plains are separate places.** They have different neighbours (village and city; village and sea). I gave them different names.

## 2. The planet

| Option | Meaning | Tone | Notes |
|---|---|---|---|
| **Everhold** | Ever plus hold: the world that holds. Reads two ways: hopeful, or ironic if VORR is right that nothing holds. | Epic, or Dark | Searched: no game, fantasy setting or planet with the name. |
| Rundle | An old word for a round thing. Sounds warm and a little silly. | Humour, Comedy | Searched: nothing exact. The word is a surname and the name of a Canadian mountain. |
| the Round | A plain everyday name. The people just call it the Round. | Any | Not searched (ordinary words, not a brand). Echoes the game-name options Roundfall and Roundhouse World. |

**Pick: Everhold**, with "the Round" as the everyday name in speech (a bark says "all the way round the Round"). If Orb picks Everward as the game name, the two are too close and the planet should be Rundle or the Round.

Rejected on search: Hollowmere (an Android game and a fantasy-world project use it), Ashhold (a Forgotten Realms location), Gloamhold (a published RPG supplement), Sundermere (flagged in the name longlist).

## 3. The naming rule for places

**A place is named for what it holds or what people do there, with a plain suffix for what kind of place it is.**

- Suffixes: **-water** (sea), **-lea** (grass), **-gate** (city), **-stead** (settlement), **-holt** (wood), **-waste** (desert), **-fell** (mountain), **-watch** (frontier), **-hold** (world). A village may be named for its work instead: Netmend.
- Plain old-English-style compounds, two parts at most, easy to say. This matches the glossary rule "plain words we already know".
- No compass-direction cities ("West City"), no "Capital" or "Central", no lookouts or towers as landmarks, no food or vegetable puns, no numbered places. Those are the franchise's habits.
- Hero names are short and soft, VORR is hard, and places are compounds. Nobody should mistake a place for a fighter.

## 4. The names

Every pick got a quoted web search on 2026-09-28 (US-only; see section 7). Stage 0 (franchise words and habits) passed for every option below.

| # | Region | Options | Pick | Self-screen |
|---|---|---|---|---|
| 1 and 11 | The sea across the seam | Longwater (Epic). The Hem, where the world is sewn shut (Humour, Comedy). The Quiet Water (Dark). | **Longwater** | Nothing exact found. |
| 2 | Harbour village | Netmend, where they mend nets (Epic, and it echoes the Hero's habit). Little Splash (Comedy). Lastlight, the last light before the sea (Dark). | **Netmend** | Nothing exact found. |
| 3 | Plains by the city | Furrowlea (Epic). The Flats (Comedy). The Fallows (Dark). | **Furrowlea** | Nothing exact found. |
| 4 | City | Bellgate, for the alarm bells (Epic; also fits the dark tier word Toll). The Bustle (Humour, Comedy). Lastlamp (Dark). | **Bellgate** | Nothing exact found. The nearest match is the game Hellgate: London, a sound-alike only. |
| 5 | Outskirts village | Kilnstead, kilns and workshops (Epic). Almost Bellgate (Comedy). Cinderby (Dark). | **Kilnstead** | Nothing exact found. |
| 6 | Forest | Deepholt (Epic). Squirrel Country (Comedy). The Hush (Dark). | **Deepholt** | Nothing exact found. |
| 7 | Desert | Sunwaste (Epic). The Sandbox (Humour). The Long Thirst (Dark). | **Sunwaste** | Nothing exact found. Dark Sun is a well-known desert D&D setting, but the name is different. |
| 8 | Mountains | Anvilfell, the range that takes the blows (Epic). Old Grumble (Comedy). The Spine (Dark). | **Anvilfell** | Nothing exact found. |
| 9 | Far village | Farwatch, far from the city and watching the pass (Epic). Nowhere Much (Comedy). Lastroof, the last roof before the sea (Dark). | **Farwatch** | Nothing exact found. |
| 10 | Plains by the sea | Windlea (Epic). The Gull Flats (Humour). The Last Green (Dark). | **Windlea** | Nothing exact found. |

Only the picks and the planet options were searched. The alternatives in the Comedy and Dark columns were not.

## 5. Where each pick shows up

These are the beam variants and glossary terms (`glossary.md`) that reference each place. Today the feed line reads "over ocean (HORIZON CLEAVE)". With a place name it can read "over Longwater (TIDE CLEAVE)".

| Pick | Beam variant now, then glossary pick | Glossary terms and other references | Fiction hooks |
|---|---|---|---|
| **Everhold** (planet) | None | HUD planet strip label; the title screen; "the Round" in barks. | "Everhold was lovely." |
| **Longwater** | HORIZON CLEAVE, then TIDE CLEAVE | Cover type "submerged" and "goes to ground". SLAM DOWN scores extra over the ocean. The fight-lure destination. | The Hero lures fights out here. VORR finds nothing to mourn. |
| **Netmend** | BOULEVARD RAZE, then LANE SWEEP (villages) | STRUCTURES LOST and CIVILIANS LOST counters. THROUGH THE WALL. | "Not over Netmend." |
| **Furrowlea** and **Windlea** | MERIDIAN SCAR, then FURROW SCAR | The beam is named for the plough furrow, and Furrowlea is where it is most at home. | Farmland, then a coastal meadow. |
| **Bellgate** | BOULEVARD RAZE (kept) | 83% of civilians. THROUGH THE WALL for the towers. Menace gain. The lure origin. | "Bellgate was lovely." |
| **Kilnstead** | BOULEVARD RAZE, then LANE SWEEP | Counters. THROUGH THE WALL. | The Hero's "I'll help rebuild once I'm done here." |
| **Deepholt** | FIRESTORM, then CANOPY BURN | Cover type "canopy". Trees are only destroyed, not burned, in the prototype today. | Hiding and ambush. |
| **Sunwaste** | GLASS TRENCH | None else. | Open ground, no one to save. |
| **Anvilfell** | RIDGE BORE | Cover type "ridge". Launch INTO THE MOUNTAIN. | The range takes the blows. |
| **Farwatch** | BOULEVARD RAZE, then LANE SWEEP | Counters. | The last village before the sea. |

## 6. How barks use the names (original, for illustration)

Barks fire on events (a launch near a town, a collapse), and `{place}` comes from the biome under the fight. When no name is needed, the plain words "harbour" and "city" still work.

- The Hero, luring: "Not over Netmend. Follow me out onto Longwater."
- The Hero, after a collapse: "Sorry, Kilnstead. I'll help rebuild once I'm done here."
- VORR, aiming at a town: "Bellgate was lovely. Someone should have said so while the bells still rang."
- VORR, dragged out to sea: "Out over Longwater? There is nothing here worth the trouble."

## 7. Method and limits

- **Stage 0 (mine, all options):** no franchise words or sound-alikes, no compass-direction cities, no food puns, no landmarks named tower or lookout, no numbered places.
- **Web search:** one quoted search per pick, form `"NAME" game OR fantasy OR ...`, US-only. Bellgate and the planet options were checked the same way. Results above are "nothing exact found" unless noted. That is a quick screen and not a clearance. I did not search the Comedy and Dark alternatives.
- **Not checked:** other languages, non-US results, or whether small real-world places share a name. I believe Saltwick (an option I dropped) is a real bay in England, unverified.
- **Rejected on search:** Brassgate (near "City of Brass", a game and a mythic city), Lampgate (near Lamplight City, a game), Hollowmere, Ashhold, Gloamhold, and "the Furrows" (a region in Pathfinder).

## 8. Notes for other directors

- **World and Environment, and UI/UX:** the picks need a `place_name` per region in the biome data, and an optional region label on the planet strip. I have not created any data.
- **Art:** the names carry no visual instructions. Suffix families (-gate, -stead, -holt) might inform silhouettes, but that is Art's call.
- **Legal:** please screen the picks in section 4 and the planet name with the rest of the glossary.
