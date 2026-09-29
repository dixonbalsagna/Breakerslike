# Modes

Owner: Game Design. Status: P0, draft for EP review. Date: 2026-09-29.

The modes, their stable ids, what each one is, and the 1.0 scope. Orb set the 1.0 list (`docs/ep/vision.md`): local 1v1, versus AI, arcade or survival, a training sandbox, and 2v2 or free-for-all, with online after launch. Game Design owns the mode list and each mode's rules (charter).

**Stable ids.** UI and UX, Marketing and the code refer to modes by id. An id never changes once published, even if the display name does. A retired id is never reused.

**Sources.** `index.html:L123` is a line of `prototype/index.html` at commit `7233c96`. Numeric bands are in `balance-targets.md`; per-fighter systems are in `systems-sketch.md`.

## Mode list

| Id | Display name (working) | Players | What it is | 1.0 |
| :--- | :--- | :--- | :--- | :--- |
| `versus-local` | Versus | 2, local | The core match: one planet, two fighters, one KO | **Yes** |
| `versus-ai` | Versus CPU | 1 | The core match against the AI, with difficulty levels | **Yes** |
| `arcade` | Arcade | 1 | A ladder through the roster, each fight a rivalry finale with pre-fight and KO lines | **Yes** (Orb's "arcade or survival": recommended first) |
| `survival` | Survival | 1 | Opponents one after another on one planet whose damage persists | **Yes, as a rule set of `arcade`**, if it fits; otherwise after 1.0 |
| `training` | Training | 1 | A sandbox with toggles, visible windows and the full director feed | **Yes** |
| `team-2v2` | Team Battle | 2 to 4, local; AI fills empty slots | Two against two on one planet | **Yes** (Orb's "2v2 or free-for-all": recommended first) |
| `ffa` | Free-for-all | 3 or 4, local; AI fills empty slots | Everyone against everyone | After 1.0, unless `team-2v2` proves the camera and director cheaply |
| `attract` | (menu background) | 0 or 1 | AI against AI on the menu; any key takes over P1 (today's demo, `L1163-1167`) | **Yes** (free) |
| `replay` | Replays | 1 | Watch a saved match: seed plus input log, bit-identical | Feature of 1.0 if Tools has time; it rides on the determinism work |
| `scenarios` | Challenges | 1 | Short authored setups that teach one rule each | After 1.0 (content for `training`) |
| `online-versus` | Online | 2 | Rollback netcode, lobbies | **After launch** (Orb) |

## The core match (every mode)

- **The arena.** One procedural wrapped planet per match, seeded (`systems-sketch.md`, "Procedural planets"). It keeps pillar 1: no walls, fly either way and loop the planet.
- **The rules.** Every rule in `stance-matrix.md` and `economy.md` applies. Transformations and each fighter's unique system run in every mode.
- **Length and escalation.** 5 minutes or more, with about 7 as the target. Four acts, bands in `balance-targets.md` §2 and §3.
- **The end.** There are no health bars. Region breaks are the chapters. A fighter on the brink can be ended only by the opponent's finisher, and that KO ends a 1v1 (`damage-model.md`).
- **Seeded and deterministic.** Every match can be replayed from its seed and inputs (ADR 0004).
- **Fair spawns.** Spawns come from pairs chosen by seed that QA has measured as fair. The prototype's fixed pair shows a +4.1-point west-spawn effect in the villain mirror (QA §2b).

## Mode rules

### `versus-local` and `versus-ai`
- **Players and screen.** Two fighters, keyboard and gamepad on equal terms (Orb). One shared 2.5D side-on screen. Hiding denies lock-on but does not conceal (`economy.md` §5).
- **AI difficulty.** Three levels, stored as AI data (Encounter Systems). Difficulty changes decisions (stance choice, cadence, parry odds, reaction time), never stats. The AI plays by the same rules as a human, which keeps AI-against-AI balance data meaningful.
- **Accept:**
  - Every pairing passes `balance-targets.md` bands 1, 2 and 7.
  - A first-time player beats Easy within three tries.
  - Hard beats Normal in at least 70% of AI-against-AI matches.

### `arcade` (with `survival` as a rule set)
- **Arcade.** Four to six fights against the roster, including a mirror rival. Each fight has its pre-fight exchange of lines and its KO lines (Narrative). There are no cutscenes that decide outcomes.
- **Survival rules.**
  - *What carries over:* the planet's damage, and each opponent starts on it.
  - *Between fights:* the player keeps broken regions, battered wear heals to bruised, ki returns to 60, and each opponent starts at the player's tier.
  - *Score:* fights won, then the time taken.
- **Accept:**
  - A median arcade run lasts 25 to 45 minutes. Each fight is a full-length match.
  - A player can name what changed on the planet since fight 1.
  - No fight starts with a fighter inside a crater or underwater.

### `training`
- **Toggles:**
  - infinite HP or ki, and a set tier or form;
  - set ego meters (respect, pride, wrath, hunger);
  - spawn keystones or civilians;
  - the dummy's behaviour: stand, hold a stance, standard AI, or hide;
  - start biome and altitude, planet seed, slow motion.
- **Display:**
  - parry and chain windows as they open (Combat CC-011: nothing shows them today);
  - the director feed with scored candidates (`L542`) and each exchange's branch roll.
- **Accept.** Every row of `stance-matrix.md` and every mechanic in `economy.md` and `systems-sketch.md` can be triggered within 10 seconds.

### `team-2v2`
- **Rules.** Two teams of two on one planet. A team is out when both its fighters are KO'd. A KO'd fighter is launched and out; there is no revive at 1.0.
- **The director.** It still resolves exchanges pairwise, one attacker against one defender (`L390-416`). Two exchanges may run at once between different pairs. If a third fighter attacks someone already locked in an exchange, the director composes a **CUT-IN**:
  - the new attacker joins the running exchange with one strike;
  - the defender's stance still applies;
  - the cut-in cannot be parried and cannot chain;
  - Combat authors the beats.
- **Teammates.** No friendly fire on fighters. Collateral stays shared.
- **Tandem and the Unison line.** The Protagonist and the Anti-hero on the same team get the Tandem offer, and two players can fire the Unison line. A true fusion is deferred (`systems-sketch.md` §3).
- **The Tyrant's minions.** They count as the Tyrant's fighters, not as extra team members.
- **Camera.** It frames both teams with shortest-arc bounds. When the spread is more than half the planet, it reframes to the most recent exchange (Camera).
- **Accept:**
  - Every team composition passes `balance-targets.md` band 1 (2v2).
  - No exchange overlaps silently: every third-party hit is a cut-in in the feed.
  - Median length is 6 to 9 minutes.

### `ffa`
- **Rules.** As `team-2v2`, but every fighter is on their own team. The last one standing wins.
- **Why after 1.0.** Three or four independent threads of the fight across a wrapped planet is the hardest framing problem for the camera. `team-2v2` proves the cut-in and multi-exchange director first.

### `attract` and `replay`
- **`attract`.** Today's AI-against-AI demo on the menu. It never stalls: QA's soak enforces at most 1% timeouts.
- **`replay`.** A file holding the build version, the seed and the input log. It plays back bit-identically (P2 exit), with the director feed, a free camera and slow motion. A 7-minute match should take under 250 KB.

## Build order

| Phase | Mode work |
| :--- | :--- |
| P2 Stance director | `training` as the director's debug harness; `versus-local`, `versus-ai` and `attract` carried over from the prototype |
| P3 Terrain, collateral, menace | Persistent planet damage and spawn validation for `survival`; procedural planets |
| P4 Signatures and four fighters | Every mode with four fighters; `arcade`; `team-2v2`, with cut-ins and Tandem |
| P5 Art, audio, polish | Menus and results, `replay` viewer, accessibility. `online-versus` after launch |

## Decisions for Orb

Details are in `open-questions.md`:
- **Arcade or survival first:** my recommendation is arcade, with survival as its rule set.
- **2v2 or free-for-all first:** my recommendation is 2v2.
- **Whether KO'd teammates can be revived in `team-2v2`.**
