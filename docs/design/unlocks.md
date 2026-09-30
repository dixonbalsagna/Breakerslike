# Unlocks: cosmetics earned through play

Owner: Game Design. Orb wants a vast assortment of cosmetics across the four fighters, unlocked through play (`docs/ep/vision.md`, "Moveset scope and cosmetics"). Art owns the categories and the items (`docs/art/cosmetics-plan.md`). This page owns the unlock tracks, the pacing and the save.

## 1. The rules

1. **Only cosmetics unlock.** Everything that changes play is open from the start (Orb, questionnaire 3): fighters, modes, planets, specials, signatures, world-change picks and transformations. When a moveset grows by data (the first fighter starts at Lean: 3 specials, 4 signatures, 6 showcases), the new moves reach everyone at once.
2. **Earned through play only.**
   - There are no purchases, loot boxes, paid currency or random reward rolls.
   - Every item has a named condition the player can see, except a few secrets, which show a hint.
   - Art's `rarity` field is display only: it says how showy an item is, never its odds.
   - Paid items would need a new decision from Orb and a Legal review.
3. **Nothing is missable.** Challenges never expire, and no item is ever withdrawn.
4. **Cosmetics never touch balance** (§5).

## 2. What earns unlocks

| Source | How it works |
| :--- | :--- |
| **Play** | Every finished match in Versus, Versus CPU, Arcade, Survival or Team Battle gives mastery points to the fighter used (§3). A losing player still progresses. Training and replays give nothing |
| **Per-fighter mastery** | 60 levels per fighter, and each level gives one item from that fighter's pool. Every 5th level offers a choice of 3, so players steer toward what they want without a currency. The two items not picked stay in the pool for later levels. Levels 10, 30 and 60 give a showpiece: an outfit set, a victory pose or a scene |
| **Milestones** | Per fighter: the first win, the Arcade clear (a showpiece), and 25 and 100 matches. Account-wide: 10, 50, 100, 250 and 500 matches; the first Team Battle win; every mode played; all four Arcade clears; and one per biome class |
| **Style labels** | Finishing a match with a style label (turtle, rusher, runner, charger, sniper or mixer; `docs/narrative/style-thresholds.md`) counts toward that label for that fighter. 3 finishes unlock an item and 10 unlock a title. All six labels on one fighter is a showpiece. It rewards trying every way to play |
| **Set pieces (feats)** | First-time moments, per fighter (list below) |
| **Challenges** | Three challenges are open at a time, drawn from one fixed, seeded sequence, so they are the same for everyone and work offline. Finishing one opens the next, and a skipped challenge goes to the back of the sequence. Examples: win at tier 1 only; win as the Protagonist with under 10% casualties; land 3 signatures in one match. Authored challenges join with the `scenarios` mode after 1.0 |
| **Secrets** | A few, each with a hint: for example, win without entering DEFENSIVE, or win a beam struggle at tier 1 |

**The feats**, 24 per fighter:
- the first crippling moment dealt;
- a win while crippled;
- each world change used (8 per fighter, `moveset-rules.md` §9);
- up to 4 form stages reached, where the final stage is a showpiece: the Empress's Final Approved, the Protagonist's Open Hand, the Anti-hero's Apex, the Cyborg going Online;
- a won beam struggle;
- a Rally;
- a comeback win;
- a full 5-link chain;
- a time-cap ending;
- **the signature log:** 10%, 25%, 50%, 75% and 100% of that fighter's signature variants seen, by biome, altitude and stance. This rewards pillar 7. The thresholds are shares, so they scale as movesets grow from Lean.

**What goals never ask for:**
- civilian casualties. Pillar 5 is personality, not a scoreboard. Protecting goals are fine;
- losing on purpose, quitting, or anything that spoils the match for the other player;
- the hardest AI difficulty, except for one showpiece per fighter;
- online play. Every item can be earned offline.

## 3. The curve, fitted to Art's pool

**The pool, deduplicated.** Art plans about 160 items per fighter. Patterns (10), trails (10), beam tints (12) and victory scenes (6) are shared across the fighters, so:
- each fighter has **122 items of its own**;
- **38 items are shared**;
- the total is **526 items**: 4 × 122 + 38.

UI's roughly 40 titles, frames and nameplates come on top.

**Where the items come from:**

| Track | Per fighter (122) | Shared (38) | Total | Share |
| :--- | ---: | ---: | ---: | ---: |
| Mastery | 60 | 0 | 240 | 46% |
| Challenges | 25 | 20 | 120 | 23% |
| Feats | 24 | 0 | 96 | 18% |
| Milestones | 4 | 14 | 30 | 6% |
| Style labels (3 finishes, and all six) | 7 | 0 | 28 | 5% |
| Secrets | 2 | 4 | 12 | 2% |

- The shared milestones assume 6 biome classes. The challenge count absorbs any difference.
- UI's marks go to the 24 style-label titles (10 finishes), one mastery-60 nameplate per fighter, and 12 frames on the account milestones.

**The mastery curve.**
- *Points:* a finished match gives 12 points per minute played (up to 12 minutes), plus up to 15 for events (exchanges won, chains, clashes). A win adds 15%. So a typical 7-minute match gives about 95 points for a loss and 110 for a win.
- *Cost:* level n costs 100 + 15 × (n − 1) points, capped at 535 from level 30 on.
- *Total:* levels 1 to 30 cost 9,525 points and levels 31 to 60 cost 16,050, so 25,575 in all. That is about 250 matches, or about 36 hours at about 7 matches an hour with menus.

**The pace, checked:**

| Stage | Pace |
| :--- | :--- |
| **Match 1** | An item: mastery level 1 costs 100 points |
| **First 10 hours** (about 70 matches) | About 50 to 65 items, about 10% of the pool. Mastery reaches about level 25 on the fighter played, and early feats, milestones and challenges land. It starts at about one item a match and eases to one every two |
| **10 to 100 hours** | One item every 2 to 3 matches when rotating fighters (their early levels are cheap), or every 3 to 4 when sticking to one. About 75% of the collection is owned by 100 hours |
| **The long tail** | Mastery 60 on one fighter comes at about 36 hours, which finishes most of that fighter's pool. 100% takes about 150 hours (about 1,050 matches), set by mastery 60 on all four fighters |

- **Tuning.** The points, costs and allocation are data (`data/unlocks/`). QA checks the pace table from AI-vs-AI batches using the same event log. The target bands are: first item in match 1; 40 to 70 items by 10 hours; 60 to 85% by 100 hours; 100% in 150 to 200 hours.
- **Growth.** New items from updates slot into the existing tracks: mastery levels past 60, new feats, new challenges, and a signature log that grows as movesets grow from Lean. Returning players always have something new to earn.
- **No duplicates.** A reward is never an item the player already owns.

## 4. The save: offline now, online later

- **A local profile.** One versioned JSON file in Godot's `user://`, holding:
  - the owned item ids;
  - goal counters, mastery points and the challenge position;
  - the equipped cosmetics;
  - the schema version.

  It is written atomically, with one backup copy.
- **Stable ids.** Each item's track sits in Art's loadout data (`data/art/cosmetics/`), and the goals and the curve sit in `data/unlocks/`. Both use stable string ids that are never reused, with schemas in `tools/schemas/`. A removed item stays owned, and an unknown id is kept and ignored, so old saves always load.
- **Outside the sim.** The meta layer checks unlocks after the match, from the match's event log. The sim never reads the profile, and replays never award anything, so determinism and replays are untouched.
- **Portability.** The profile can be exported and imported as a file. This matters most in the browser, where storage can be wiped, and for moving between devices.
- **Online, later.**
  - The local profile stays the source of truth. Cosmetics can't change balance, so there is nothing to cheat and no server check is needed.
  - In a lobby, each side sends its equipped cosmetic ids. An item the other player's build lacks shows as the default.
  - Account sync can come later as a convenience, not a requirement.
- **Open source.** Anyone can edit their save, and that is fine. *For Orb:* an "unlock all cosmetics" setting, off by default, would be the honest version of that, and it helps players who just want the looks. Orb decides.

## 5. Cosmetics never touch balance

- **The sim never reads cosmetic data.** A cosmetic has no stats, hurtboxes, size, speed, timing or AI behaviour. Cosmetics live only in the render and UI layers.
- **Readability locks.** A cosmetic can't hide, recolour or replace:
  - the wound readout on the body, or the brink call-out (`spec-wounds.md` §3);
  - transformation tells: the Empress's revision tells and number, the Protagonist's heat seams and steam, the Anti-hero's regalia, the Cyborg's form stages;
  - telegraphs: signature wind-ups, parry and chain cues, hazard warnings, and the info flashes (`docs/art/cosmetics-plan.md`);
  - the silhouette, beyond Art's envelope.
- **Colour rules.** Each fighter stays distinct from every biome and from the rival. If both sides pick near-identical colours or auras, the second side shifts automatically, so beam struggles stay readable. Team colours stay locked in Team Battle.
- **Sound.** Cosmetic sounds, such as a victory sting, never replace or mask a gameplay cue.
- **A setting** shows opponents in their default cosmetics, for readability or taste.
