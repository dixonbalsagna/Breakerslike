# Unlocks: cosmetics earned through play

Owner: Game Design. Orb wants a vast assortment of cosmetics across the four fighters, unlocked through play (`docs/ep/vision.md`, "Moveset scope and cosmetics"). Art owns the categories and the items. This page owns how items are earned, the pacing and the save.

## 1. The rules

1. **Only cosmetics unlock.** Everything that changes play is open from the start (Orb, questionnaire 3): fighters, modes, planets, specials, signatures, world-change picks and transformations. When a moveset grows by data (the first fighter starts at Lean: 3 specials, 4 signatures, 6 showcases), the new moves reach everyone at once.
2. **Earned through play only.** There are no purchases, loot boxes, paid currency or random reward rolls. Every item has a named condition the player can see, except a few secrets, which show a hint. Paid items would need a new decision from Orb and a Legal review.
3. **Nothing is missable.** Rotating challenges come back, and no item is ever withdrawn for good.
4. **Cosmetics never touch balance** (§5).

## 2. What earns unlocks

| Source | How it works | Share of the collection |
| :--- | :--- | :--- |
| **Play** | Every finished match in Versus, Versus CPU, Arcade, Survival or Team Battle gives mastery points to the fighter used. Points come from time played and from events (exchanges won, chains, clashes), with a +25% win bonus, so a losing player still progresses. Training and replays give nothing | Feeds mastery |
| **Per-fighter mastery** | 50 levels per fighter, and each level gives one item from that fighter's pool. Every 5th level offers a choice of 3, so players steer toward what they want without a currency. Levels 10, 25 and 50 give a showpiece: an outfit, a victory pose or a title | About 45% |
| **Milestones** | Account-wide: the first win; the first match on each biome class; each fighter's Arcade clear; the first Team Battle win; 10, 50, 100 and 250 matches; every mode played | About 10% |
| **Style labels** | Finishing a match with a style label (turtle, rusher, runner, charger, sniper or mixer; `docs/narrative/style-thresholds.md`) counts toward that label for that fighter. 3 and 10 finishes unlock a title and an emblem, and all six labels on one fighter is a showpiece. It rewards trying every way to play | About 10% |
| **Set pieces (feats)** | First-time moments, per fighter where it fits. **The signature log:** the first sighting of each signature variant (by biome, altitude and stance) unlocks a small item, which rewards pillar 7. Other feats (list below) | About 25% |
| **Challenges** | Three local challenges a week. They are generated from the calendar week and a fixed seed, so they work offline and are the same for everyone. Examples: win at tier 1 only; win as the Protagonist with under 10% casualties; land 3 signatures in one match. Each one rotates back later. Authored challenges arrive with the `scenarios` mode after 1.0 | About 10% |
| **Secrets** | A handful, each with a hint: for example, win without entering DEFENSIVE, or win a beam struggle at tier 1 | A few items |

The feats are:
- the first crippling moment dealt;
- a win while crippled;
- each world change used (8 per fighter, `moveset-rules.md` §9);
- each form stage reached: the Empress's Final Approved, the Protagonist's Open Hand, the Anti-hero's Apex, the Cyborg going Online;
- a won beam struggle;
- a Rally;
- a comeback win;
- a full 5-link chain;
- a time-cap ending.

**What goals never ask for:**
- civilian casualties. Pillar 5 is personality, not a scoreboard. Protecting goals are fine;
- losing on purpose, quitting, or anything that spoils the match for the other player;
- the hardest AI difficulty, except for one showpiece per fighter;
- online play. Every item can be earned offline.

## 3. Pacing, so the collection lasts

A match takes about 7 to 9 minutes with menus.

| Stage | Pace |
| :--- | :--- |
| **First session** | An item in the first match |
| **First 10 hours** (about 65 matches) | About one item every two matches |
| **After that** | One item every 3 to 5 matches. The mastery points per level rise until level 30, then stay flat, so no fighter becomes a wall |
| **The long tail** | Mastery 50 on one fighter takes about 30 to 40 hours. Most of the collection comes in about 100 hours, and 100% takes about 150 to 200 hours |

- **Sized by data.** The curve, the shares and the points per match are data. Once Art fixes the pool size, the curve is fitted to these targets. QA measures items per hour from AI-vs-AI batches, using the same event log.
- **Growth.** New items from updates slot into the existing tracks: mastery levels past 50, new feats, and new signature-log entries as movesets grow from Lean. Returning players always have something new to earn.
- **No duplicates.** A reward is never an item the player already owns.

## 4. The save: offline now, online later

- **A local profile.** One versioned JSON file in Godot's `user://`, holding:
  - the owned item ids;
  - goal counters and mastery points;
  - the equipped cosmetics;
  - the schema version.

  It is written atomically, with one backup copy.
- **Stable ids.** Items and goals are data (`data/unlocks/`, with a schema in `tools/schemas/`), keyed by stable string ids that are never reused. A removed item stays owned, and an unknown id is kept and ignored, so old saves always load.
- **Outside the sim.** The meta layer checks unlocks after the match, from the match's event log. The sim never reads the profile, and replays never award anything, so determinism and replays are untouched.
- **Portability.** The profile can be exported and imported as a file. This matters most in the browser, where storage can be wiped, and for moving between devices.
- **Online, later.**
  - The local profile stays the source of truth. Cosmetics can't change balance, so there is nothing to cheat, and no server check is needed.
  - In a lobby, each side sends its equipped cosmetic ids. An item the other player's build lacks shows as the default.
  - Account sync can come later, as a convenience rather than a requirement.
- **Open source.** Anyone can edit their save, and that is fine. *For Orb:* an "unlock all cosmetics" setting, off by default, would be the honest version of that, and it helps players who just want the looks. Orb decides.

## 5. Cosmetics never touch balance

- **The sim never reads cosmetic data.** A cosmetic has no stats, hurtboxes, size, speed, timing or AI behaviour. Cosmetics live only in the render and UI layers.
- **Readability locks.** A cosmetic can't hide, recolour or replace:
  - the wound readout on the body, or the brink call-out (`spec-wounds.md` §3);
  - transformation tells: the Empress's revision tells and number, the Protagonist's heat seams and steam, the Anti-hero's regalia, the Cyborg's form stages;
  - telegraphs: signature wind-ups, parry and chain cues, hazard warnings;
  - the silhouette, beyond Art's limits.
- **Colour rules.** Each fighter stays distinct from every biome and from the rival. If both sides pick near-identical colours or auras, the second side shifts automatically, so beam struggles stay readable. Team colours stay locked in Team Battle.
- **Sound.** Cosmetic sounds, such as a victory sting, never replace or mask a gameplay cue.
- **A setting** shows opponents in their default cosmetics, for readability or taste.
