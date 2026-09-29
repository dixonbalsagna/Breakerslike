# Player-facing glossary

Owner: Narrative and Fighter Identity. Version 1, 2026-09-28 (P0 wave 1b). Draft for the EP. Nothing here is implemented, and I have not touched the prototype.

**What this is.** Every term the prototype shows to a player, or implies, with a risk note, alternatives tagged by tone, and my pick. Source: a read of `prototype/index.html` (HUD, banners, feed lines, the `STN`, `SEG`, `sigName` and beam-variant tables, and the `ex.tag` strings), `docs/combat/exchange-templates.md`, `docs/legal/originality-rules.md` and `docs/legal/review-log.md`.

**How to read it.**
- **Risk:** *Franchise-coded* (echoes Dragon Ball, or a grey-zone item in the originality rules), *Generic* (ordinary genre vocabulary, no action needed) or *Fine*. "RL-nnn" is a Legal review-log entry.
- **Tone tags:** Epic = earnest epic. Humour = heroic with humour. Comedy. Dark. Orb's tone answer is still pending, so each row offers options.
- **Pick** is tone-neutral unless it says otherwise. A pick tagged with a tone changes if Orb picks a different tone. I did not need to change any *mechanical* banner for tone; only fiction-facing words (tiers, signatures, titles, the resource word) move with tone.
- **Screening.** The picks that are proper-name-like (Keeper's Lance, Last Look, Tide Cleave, Lane Sweep, Canopy Burn, Furrow Scar) got one quoted web search each on 2026-09-28 (US-only): no exact match for any. "Cleave" and "sweep" are common ability words in other games (Dota 2, Diablo III and others). Ordinary-word picks were not searched. Every pick still goes to Legal through the EP before it ships (originality checklist).

## 1. The naming rule

**One line:** say it plainly, name it after the land, and let one word mean one thing.

1. **Plain words we already know.** Ordinary English. No coined or borrowed-language words for mechanics, no "-ha" endings, no Latin or English superlatives (Ultra, Hyper, Omega, "Super ___", "God"). Do not use the franchise's vocabulary: ki, aura, scouter, radar, sensing, "power level", Burst, Raging, Sparking, and the "Final ___", "Big Bang ___", "Spirit ___", "Special ___ Cannon" patterns (originality rules).
2. **Beams follow the land pattern.** A beam variant is a place or material plus what the beam does to the land (GLASS TRENCH). One variant per biome, and each biome different. A fighter's signature is a short phrase from that fighter's own voice, optionally with a plain shape word (Lance, Wave, Beam).
3. **One word, one meaning, everywhere.** GUARD, CLASH, CHAIN and ESCAPE each mean one thing. Stances are verbs of intent, and results reuse the verb: GUARD leads to GUARD HOLDS, DODGE to DODGED, ESCAPE to ESCAPED.
4. **Banners are short and shaped the same.** Capitals, three words at most. Events are verb-first (PARRY, AMBUSH FROM COVER). Exchange results read FAMILY — OUTCOME (PURSUIT — CAUGHT). Outcomes are in the past tense (DODGED, ESCAPED).
5. **Named, not numbered.** Tiers and resources have names and show as pips and bars. No numeric "power" readouts. A cost may show a number (NEED 45 CHARGE).
6. **Tone lives in the fiction layer, not the mechanics.** Mechanical terms stay plain, so tone changes, translation and screen readers do not break them. Puns and jokes belong in tier names, signatures, titles and barks.
7. **Built to be translated and read.** No idioms or puns in mechanical terms. HUD labels 12 characters or fewer. Prefer the whole word to an abbreviation.
8. **Search it, say it, send it.** Before a term ships: search the exact phrase with "game" in quotes, say it aloud, and send it to Legal via the EP. No nods and no Easter eggs (originality rules).

## 2. Picks at a glance

Only terms that change. Everything not listed stays as it is.

| Now | Pick | Why |
|---|---|---|
| ki | **Charge** | Franchise-coded word (RL-015). "Charge" is what the Charge action fills. |
| power (unlabelled bar) | **Momentum** | Keeps "power level" out of the UI. |
| TIER 1 to 4 | **Tremor, Quake, Upheaval, Cataclysm**, shown as four pips | Named ladder instead of numbers (grey zone). Names what each tier can move. |
| POWERS UP | **RISES — (tier name)** | Removes the genre's default banner. |
| AGGRESSIVE / DEFENSIVE / EVASIVE / ESCAPE | **PRESS / GUARD / DODGE / ESCAPE** | Short verbs of intent that match the results. Drops ATK/DEF/EVA/ESC. |
| "Meridian Warden" | **the Warden** | "Meridian" leaves with the game name. |
| "Calamity Sovereign" | **the Last Witness** | Matches the villain sketch. |
| Meridian Lance | **Keeper's Lance** | "Meridian" leaves with the game name. |
| Calamity Wave | **Last Look** | The villain's habit of watching. |
| HORIZON CLEAVE | **TIDE CLEAVE** | Horizon is a Sony brand (RL-006). |
| FIRESTORM | **CANOPY BURN** | Breaks the land pattern, and DC's character name (RL-008). |
| MERIDIAN SCAR | **FURROW SCAR** | "Meridian" leaves with the game name. |
| BOULEVARD RAZE for villages | **LANE SWEEP** (villages only) | Villages should not play like the city (pillar 7). |
| SMASH ACROSS, BUILDING SMASH | **HURL ACROSS, THROUGH THE WALL** | "Smash" is used twice. |
| MOUNTAINSIDE | **INTO THE MOUNTAIN** | Same shape as THROUGH THE WALL. |
| DODGE & READ | **DODGE — SEEN THROUGH** | The current label does not say who read whom. |
| PURSUIT — TARGET SLIPS AWAY | **PURSUIT — SLIPPED AWAY** | Matches the SLIPPED AWAY banner. |
| N HIT CHAIN / N CHAIN | **CHAIN ×N** | One label for one thing. |
| LOCK LOST — TARGET HIDDEN, "power signature" | **TRAIL LOST**, "trail" | Sensing language is franchise-coded. |

## 3. Resources and readouts

| Current | Where it shows | Risk | Alternatives | Pick |
|---|---|---|---|---|
| ki | Blue bar. "NEED 45 KI". The signature costs 45. | **Franchise-coded** (grey zone, RL-015). The genre's word for energy. An everyday word and not ownable, but next to auras and power-ups it adds to a lookalike impression. | Reserve (Epic). Gas (Humour, Comedy). Ember (Dark). | **Charge**, the neutral default. Swap for a tone option once Orb picks a tone. |
| power | Gold bar, unlabelled. Drives the tier. "Power signature" in a feed line. | **Generic.** Keep clear of the phrase "power level" (no numeric readouts). | Rise (Epic). Fury (Dark). Swagger (Humour, Comedy). | **Momentum** |
| HP | Green bar. | **Fine.** | Health (plain). Vitality (Epic). Grit (Humour). | **Health** |
| MENACE | VORR's purple bar. | **Fine.** A pillar word, plain English. | Dread (Epic). Appetite (Dark). Hunger (Dark). | **Menace** (keep) |
| ANGUISH | The Hero's teal bar. | **Fine.** | Weight (Epic). Guilt (Dark). Worry (Humour, Comedy). | **Anguish** (keep) |
| CIVILIANS LOST n / N | Top centre. | **Fine, but tone-sensitive.** "Lost" reads as dead. Whether people die on screen is a tone call for Orb. | People lost (Epic). Bystanders (Humour, Comedy). Casualties (Dark). | **Civilians lost** (keep until tone is set) |
| STRUCTURES LOST | Top centre. | **Fine.** | Buildings lost (Epic). Wrecked (Humour). Razed (Dark). | **Structures lost** (keep) |
| CRATERS | Top centre. | **Fine.** | Scars (Epic, Dark). Holes (Comedy). | **Craters** (keep) |

## 4. Tiers

| Current | Where it shows | Risk | Alternatives | Pick |
|---|---|---|---|---|
| TIER 1 to 4 | HUD "TIER 3", banner, feed line "reaches tier 3". | **Franchise-coded** (grey zone: named transformations and numeric readouts). A bare number is generic, but numbers plus a power-up banner plus an aura is the genre's ladder. Legal's default is original tier names shown as pips. | Epic: Tremor, Quake, Upheaval, Cataclysm. Humour: Scuffle, Ruckus, Rampage, Catastrophe. Dark: Omen, Toll, Ruin, Silence. Comedy: Oops, Whoops, Yikes, Sorry. | **Tremor, Quake, Upheaval, Cataclysm.** It names how much ground each tier can move (pillar 4). Four pips plus the name. Numbers stay in data. Note: Quake and Cataclysm are also famous game titles; as plain labels the risk is low, but Legal may prefer other words. |
| POWERS UP | Banner "NAME POWERS UP TIER 3". | **Generic** on its own. It is the genre's default banner. | "NAME RISES" (Epic). "NAME STEPS UP" (Humour). "NAME ESCALATES" (Dark). | **"NAME RISES — (tier name)"** |
| "Ground-level power-up scarred the terrain" | Dev feed. | **Fine.** | Keep the sentence; change the noun to "rise". | **Keep** (reword to "rise") |

## 5. Titles and signatures (the fighter layer)

| Current | Where it shows | Risk | Alternatives | Pick |
|---|---|---|---|---|
| KAI | HUD name. | **Franchise-coded.** NO-GO (RL-002). | See `hero-name-longlist.md`. | Not a glossary pick. Shortlist: Weir, Wyn, Havren, Orlo, Solan. |
| VORR | HUD name. | **Fine.** Working name (RL-003). | None here. | **Keep.** Re-screen at name lock. |
| "Meridian Warden" | Title under the Hero's name. | **Fine** (RL-013), but "Meridian" leaves with the game name. | The Warden (Epic). Warden of the Round (Epic). Keeper of Roofs (Humour, Comedy). | **The Warden** |
| "Calamity Sovereign" | Title under VORR's name. | **Fine** (RL-013). "Calamity" must not become the game's title or brand. | The Last Witness (Dark). Sovereign of Endings (Epic). Lord of Last Looks (Humour). | **The Last Witness** |
| Meridian Lance | Hero signature banner and feed. | **Fine** (RL-005), but carries "Meridian". | Keeper's Lance (Epic). Fair Warning (Humour, Comedy). Last Promise (Dark). | **Keeper's Lance** |
| Calamity Wave | VORR signature banner and feed. | **Fine** (RL-004). Move name only, not a brand. | Last Look (Dark). Elegy Wave (Epic). Curtain Call (Humour, Comedy). | **Last Look** |

## 6. Stances and states

The display names change; the internal enum names can stay. `docs/combat/` uses AGGRESSIVE and the rest, and that is fine.

| Current | Where it shows | Risk | Alternatives | Pick |
|---|---|---|---|---|
| AGGRESSIVE (ATK) | HUD subtitle, floating label, key 1. | **Generic.** | Press (Epic). Brawl (Humour). Hunt (Dark). | **PRESS** |
| DEFENSIVE (DEF) | Same, key 2. | **Generic.** | Guard. Stand (Epic). Brace (Humour, Comedy). Endure (Dark). | **GUARD** |
| EVASIVE (EVA) | Same, key 3. | **Generic.** | Dodge. Slip (Epic). Duck (Humour, Comedy). Drift (Dark). | **DODGE** |
| ESCAPE (ESC) | Same, key 4. | **Generic.** Fine as is. | Withdraw (Epic). Scram (Comedy). Vanish (Dark). | **ESCAPE** (keep) |
| ATK, DEF, EVA, ESC | Floating label over a fighter. | **Fine**, but cryptic. | Full word. | **Drop them.** The new names are six letters or fewer. |
| CHARGING | HUD state. | **Generic.** | Gathering (Epic). Winding up (Humour). | **CHARGING** (keep) |
| HIDDEN | HUD state and "?" on the planet strip. | **Fine.** | Unseen (Epic). Lying low (Humour). | **HIDDEN** (keep) |
| "(AI)" | Suffix after a name. | **Fine.** | CPU (Humour). | **(AI)** (keep) |

## 7. Actions and inputs

| Current | Where it shows | Risk | Alternatives | Pick |
|---|---|---|---|---|
| Light, Heavy | Controls, feed ("LIGHT", "HEAVY"). | **Generic.** | Quick, Strong (plain). Jab, Haymaker (Humour). | **Light, Heavy** (keep) |
| Signature | Controls, feed ("SIG"). | **Generic.** "Signature move" is common. | Hallmark (Epic). Showstopper (Humour, Comedy). Finale (Dark). | **Signature** (keep) |
| Dash | Controls. | **Generic.** Avoid "Burst" (a franchise word). | Streak (Epic). Rush (Humour). | **Dash** (keep) |
| Charge (hold) | Controls, state. | **Generic.** The word matches the new resource name. | Gather (Epic). Wind up (Humour). | **Charge** (keep) |
| K.O. NAME WINS | End banner. | **Generic.** | FINISHED (Epic). LIGHTS OUT (Humour). THE QUIET (Dark). | **K.O.** (keep) |

## 8. Exchange templates, banners and feed tags

| Current | Where it shows | Risk | Alternatives | Pick |
|---|---|---|---|---|
| TRADE BLOWS | Feed tag. | **Generic.** A boxing idiom. | Exchange (Epic). Slugfest (Humour). | **Keep** |
| PRESSURE — GUARD HOLDS (→ COUNTER) | Feed tag. | **Fine.** | Pressed — Held (Epic). Not budging (Humour). | **Keep** |
| GUARD BREAK | Banner and feed tag. | **Generic.** A common fighting-game term. | Guard shattered (Epic). Guard cracked (Humour). | **Keep** |
| DODGE & READ | Feed tag. | **Fine**, but unclear. Reads as if the defender did the reading. | Dodge — seen through (Epic). "Nice try" (Humour, Comedy). Dodge — punished (Dark). | **DODGE — SEEN THROUGH** |
| DODGE & COUNTER | Feed tag. | **Fine.** | Dodge — answered (Epic). "Gotcha" (Comedy). | **DODGE — COUNTER** (same shape as the pair) |
| PURSUIT — TARGET SLIPS AWAY | Feed tag. | **Fine.** | Pursuit — got away (Humour). Pursuit — lost (Dark). | **PURSUIT — SLIPPED AWAY** |
| PURSUIT — CAUGHT | Feed tag. | **Fine.** | Pursuit — run down (Epic). | **Keep** |
| HEAVY CLASH — WON / COUNTERED | Feed tag. | **Fine**, but it does not say whose win. UI/UX to decide. | Heavy clash — attacker wins / defender wins. | **Keep** (flag for UI/UX) |
| CLASH SHOCKWAVE | Feed tag. | **Fine.** | Clash — shockwave. | **Keep** |
| CHARGE INTERRUPT | Feed tag. | **Generic.** | Charge cut short (Epic). Rude interruption (Comedy). Broken charge (Dark). | **Keep** |
| PARRY | Banner, "NAME PARRIES". | **Generic.** | Turned aside (Epic). "Nope" (Comedy). | **Keep** |
| N HIT CHAIN, N CHAIN | Banner and HUD. | **Fine.** Two labels for one thing. | Streak (Humour). Run (Dark). | **CHAIN ×N** |
| CLASH | Banner (melee shockwave). | **Fine.** | Collision (Epic). | **Keep** |
| BEAM CLASH | Banner. | **Fine.** | Beams meet (Epic). | **Keep** |
| AMBUSH FROM COVER | Banner. | **Fine.** | Sprung from cover (Epic). "Surprise!" (Comedy). Out of the quiet (Dark). | **Keep** |
| SLIPPED AWAY | Banner. | **Fine.** | Got away (Humour). | **Keep** |
| NEED 45 KI | Banner. | **Franchise-coded** (follows ki). | Not enough charge. | **NEED 45 CHARGE** |

## 9. Launch names

The launch feed line prints "LAUNCH: NAME" and the top three scored names.

| Current | Where it shows | Risk | Alternatives | Pick |
|---|---|---|---|---|
| UPPERCUT | Feed. | **Generic.** A boxing term. | Heave up (Epic). Loft (Humour). | **Keep** |
| SLAM DOWN | Feed. | **Generic.** | Drive down (Epic). Faceplant (Comedy). | **Keep** |
| SMASH ACROSS | Feed. | **Generic.** "Smash" is used twice and echoes a big game brand. | Hurl across (Epic). Send packing (Humour). | **HURL ACROSS** |
| BUILDING SMASH | Feed. | **Generic.** Same. | Through the wall (Humour). Building crash (Epic). Room service (Comedy). | **THROUGH THE WALL** |
| MOUNTAINSIDE | Feed. | **Fine.** | Into the mountain (Epic). "Mountain, meet face" (Comedy). Carved in stone (Dark). | **INTO THE MOUNTAIN** |

## 10. Beam variants and outcomes

Legal's pattern: a place or material plus what the beam does to the land.

| Current | Biome | Risk | Alternatives | Pick |
|---|---|---|---|---|
| HORIZON CLEAVE | Ocean | **Fine** as a label (RL-006). Horizon is a Sony brand, so never a title or logo. | Tide cleave (Epic). Salt split (Dark). Splash zone (Comedy). | **TIDE CLEAVE** |
| BOULEVARD RAZE | City | **Fine** (RL-007). | Avenue raze (Epic). Main Street raze (Humour). | **Keep** |
| BOULEVARD RAZE | Village (shared with city today) | **Fine**, but pillar 7 wants a different play in each biome. A design ask for Combat and Game Design. | Lane sweep (Epic). Roofline raze (Dark). Street sweep (Humour). | **LANE SWEEP** |
| FIRESTORM | Forest | **Generic**, and a DC Comics character (RL-008). The only variant that breaks the land pattern. | Canopy burn (Epic). Cinder line (Dark). Timber torch (Humour). | **CANOPY BURN** |
| RIDGE BORE | Mountains | **Fine** (RL-009). | Stone bore (Epic). Spine split (Dark). Peak punch (Humour). | **Keep** |
| GLASS TRENCH | Desert | **Fine** (RL-010). | Sand glass (Epic). Glass rut (Dark). | **Keep** |
| MERIDIAN SCAR | Plains | **Fine** (RL-011), but carries "Meridian". | Furrow scar (Epic). Long scar (Dark). Turf tear (Humour). | **FURROW SCAR** |
| CLASH, GUARD, DODGE, HIT, ESCAPE | Beam outcomes. | **Fine.** | Met, held, missed, landed, got away. | **Keep** |
| DODGED, ESCAPED | Banners. | **Fine.** | Missed (Humour). Got away (Humour). | **Keep** |

## 11. Hiding and ambush

| Current | Where it shows | Risk | Alternatives | Pick |
|---|---|---|---|---|
| "Power signature suppressed" | Feed line when a fighter hides. | **Franchise-coded.** Sensing language echoes ki-sensing and the scouter. | "Wake hidden" (Epic). "Trail gone cold" (Dark). "Off the map" (Humour). | **"Trail gone cold"** |
| LOCK LOST — TARGET HIDDEN | Banner. | **Franchise-coded** (mild): the same sensing idea. "Lock-on" alone is generic gaming. | No lock (plain). Lost them (Humour). Trail lost (Dark). | **TRAIL LOST** |
| lock-on | Feed line. | **Generic.** | Track (Epic). | **Keep** |
| goes to ground | Feed line. | **Fine.** | Takes cover. Vanishes (Dark). | **Keep** |
| Cover types: submerged, canopy, ridge | Feed line. | **Fine.** | Underwater, tree cover, ridgeline. | **Keep** |
| found | Feed line. | **Fine.** | Flushed out (Humour). | **Keep** |
| scouting range | Feed line. | **Fine.** "Scouter" is the franchise device; "scouting" is not. | Search range. | **Keep** |

## 12. Text that names the prototype (dev-only, not player-facing)

These are not glossary terms, but they show up in every screenshot and clip. They carry names that must go before anything is public (RL-001, RL-002, RL-014):

- Page and panel title: "Meridian — director prototype".
- The overlay: "take over as KAI".
- The help text: "As KAI, watch what happens ... VORR feeds on the wreckage".
- Fighter definitions: the `name`, `title` and `sigName` fields.
- Beam-variant text with "MERIDIAN" (MERIDIAN SCAR, Meridian Lance).

Tools and UI/UX own those files. I have not edited any of them.

## 13. Open decisions

- **Tone** (Orb): picks the tier ladder, the resource word (Charge or a tone option), the titles and the signatures. Every mechanical banner above is tone-neutral.
- **Do civilians die on screen?** (Orb, with Game Design): the strongest tone lever. It decides "CIVILIANS LOST", the tier names, and what VORR's Savour beat shows.
- **Village beam** (Combat and Game Design): a separate LANE SWEEP variant is a design change, not just a rename.
- **Legal:** please screen the picks in section 2 before any of them is coded.
