# Wounds: implementation plan (slices)

Owner: Simulation & Engine. Status: plan for the EP to route. Binding inputs:
- `docs/design/spec-wounds.md` (the spec; section numbers below refer to it);
- `docs/combat/procedural-moves.md` §8 and §12 (the composer's interface and its stages);
- `docs/director/tempo-and-location.md`;
- `docs/design/balance-targets.md` §9 and §10.

Rules for every sim slice: the GDScript sim is the source of truth (ADR 0006). There is **one sim editor at a time**, because there is one working tree and one golden file. Each slice regenerates `sim/core/test/golden.json` in its own commit, with the reason stated.

## The order at a glance

```
S0  menace fixes (placeholder balance)          Simulation      XS   before Wounds
S1  wear core: regions, stages, brink, events    Simulation      M    -- first readouts can start (R1)
S2  the end: decisive exchanges, finisher, KO    Encounter       M    -> Wounds PLAYABLE on the greybox
S3a stage penalties, sim side                    Simulation      S
S3b stage penalties, director side               Encounter       S
S4  Rally (shared rule, 15 s cooldown, limits)   Encounter+Sim   S    -> spec §5 tests 1-5 measurable
D1  roster as data (KAI and VORR as files)       Simulation      M    goldens must NOT change (the proof)
F1  first real fighter (profile, meters, forms)  per fighter     L    after D1 and composer stages 0-2
W1  variable planet circumference                Simulation+World L   before the fold (§7)
N1  N bodies on the field (the Empress's guard)  Sim+Encounter   L    before the Empress
In parallel at any time (no golden impact): R1/R2 readouts, T1 data schema, Combat data authoring, Narrative text
```

Sizes, as a rough guide to GDScript lines and review effort:
- XS: under 50 lines, one short session.
- S: 50 to 150 lines.
- M: 150 to 400 lines.
- L: over 400 lines, several sessions.

## Slices

### S0: Placeholder balance fixes (balance-targets.md §9). Before Wounds, not folded into S1.
- **Owner:** Simulation. **Files:** `sim/core/fighter.gd` (menace decay), `sim/core/damage.gd` (the cap).
- **Change:**
  - Menace decays at 0.4 per second after 4 s without a new villain-caused casualty. Menace only rises through casualties, so `stepFighter` detects the rise itself and `sim/world` stays untouched.
  - The menace damage cap drops from +25% to +15%.
- **Events:** none.
- **Acceptance:**
  - `batch.gd` on 400 matches per arm puts KAI at 42% or better (QA re-tests);
  - the balance-targets §10 pacing rows still pass;
  - goldens regenerated.
- **Why first:** §9 sets the testbed target on today's HP game. Folded into S1, its effect could not be told apart from the wear change, and every S1 to S4 tuning run would sit on a 35/65 skew.

### S1: Wear core (spec §1, §4). The HP bar stays the match ender for one more slice, so the game stays playable.
- **Owner:** Simulation.
- **Files:**
  - new `sim/core/wounds.gd`;
  - `sim/core/state.gd`: per fighter, wear per region, stage, brink, and the rally mask for later;
  - `sim/core/damage.gd`: `hit()` also calls `SimWounds.applyHit`;
  - `sim/core/fighter.gd`: recovery;
  - `sim/core/hash.gd`: the new fields enter the gameplay lane;
  - `sim/core/fx.gd`: the events;
  - `sim/core/tools/batch.gd`: wound statistics from events;
  - `golden_recipes.gd`.
- **Rules:**
  - **Regions.** Head, core, arms and legs. Wear is 0 to 100, stored as **fixed-point integer thousandths**. Each hit adds `round(damage × 0.08 × 1000)`, with damage being today's `hit()` value.
  - **Stages.** Fresh, bruised, battered and broken, at 30, 60 and 90.
  - **Brink.** The core broken, or two of head, arms and legs broken.
  - **Recovery.** Below 60, a region fades 1 per second out of exchanges; while hidden, a battered region fades 3 per second, down to 59. Broken regions never fade.
  - **Region choice.** A **provisional default** picker in `wounds.gd`, with two tables:
    - family weights by attack kind (lights: head and arms; heavies: core and legs; guard hits: arms; beams and impacts: spread);
    - go-for-the-wound, a factor of (1 + wear/50).
    One draw from `S.rng` per wearing hit. Encounter replaces the picker with per-atom weights (S2 or the composer's stages) through the same function signature.
- **Events** (fx stream; documented in `fx-events.md` in the same slice):
  - `region_stage` {actor, region, stage}
  - `region_broken` {actor, region}
  - `brink_enter` {actor}
  - `brink_exit` {actor}
  The `FxEvent` record gains `actor` (fighter index), `region` and `stage`.
- **Acceptance** (spec §5):
  - test 1: the golden check passes after regeneration;
  - test 5: wear spread is measured by `batch.gd` and reported, but not yet banded;
  - every event type is documented and consumed (`fx.test` equivalent in `parity.gd`).
- **Size:** M.

### S2: The end comes through finishers (spec §1: decisive exchange, finisher, the end). Wounds becomes playable here.
- **Owner:** Encounter Systems (`sim/director/`). Combat supplies the finisher template skeleton as data or a named template.
- **Files:**
  - `sim/director/exchange.gd`: decisive-exchange detection;
  - `melee.gd` and `beam.gd`: the finisher template, and the break launch at 1,500 units or more through the planner's distance and new-biome terms;
  - `ai.gd`: the AI reads wear and brink instead of `hp/maxhp` for its stance weights. A proxy is enough for now: `1 - max(regionWear)/100`, and "on the brink".
  - Simulation's hook is needed: `hurt()` stops calling `ko()`. The only KO path becomes a finisher outcome in `damage.gd`. This is a 10-line change in `sim/core`, done by Encounter with the EP's approval, or by Simulation just before S2 as S1's last commit.
- **Rules:**
  - A decisive exchange is one where the loser is launched, a heavy or beam clash is won, a GUARD BREAK lands, or a CHARGE INTERRUPT lands.
  - A finisher starts when the opponent of a fighter on the brink wins one.
  - The contest roll is 30% base, −10 points per minute past 8:00 (Rallies come in S4), with a floor of 0. It uses one `S.rng` draw.
  - A lost contest means KO.
  - The match-length cap in the golden runs and `batch.gd` rises from 18,000 ticks (300 s) to 43,200 (12 min, spec §5 test 3 p99).
- **Events:** `finisher_start` {actor, target}, `finisher_contest` {target, chance, survived}, `ko` {winner, loser}.
- **Acceptance** (spec §5):
  - test 2: 100% of KOs follow `brink_enter` and `finisher_start`;
  - test 3 is measured: breaks per match, first brink, length. QA sets the k value that meets the 6 to 8 minute median.
- **Size:** M.

### S3a and S3b: Stage penalties (spec §1).
- **S3a** (Simulation, S). The core-side penalties:
  - core battered: ki regen −30%;
  - legs battered: speed ×0.85; legs broken: no dash, hide time 1.8 s;
  - head battered: a 0.2 s stagger after heavies; head broken: a 0.4 s daze after a lost exchange. Both are new timers.
- **S3b** (Encounter, S). The director-side penalties:
  - parry window −20%;
  - defence roll −0.08;
  - DEFENSIVE multiplier 0.38 → 0.55;
  - heavies and signatures ×0.8, and no BRACE;
  - ESCAPE slip chance −0.10.
- **Timers:** every new timer is an **integer tick count** (determinism.md hazard 1). Existing float timers stay as they are.
- **Acceptance:** spec §5 test 5 (each of head, arms and legs is the first broken in at least 10% of matches; no region above 45% of wear), and the §10 pacing bands.

### S4: Rally, shared rule (spec §2). Placeholder trigger for the prototype fighters: survive a finisher contest (Second Wind's shape).
- **Owners:** Simulation (state: rallied-region mask, a 15 s cooldown as ticks, a mended region returning battered at 89; events), then Encounter (the AI's use, and the contest tilt of −10 per Rally).
- **Events:** `rally` {actor, region}.
- **Acceptance:** spec §5 test 4 (0.5 to 2.0 Rallies per match; never the same region twice; survival reaches 0 after the third Rally or through the past-8:00 tilt).
- **Size:** S.

### D1: The roster as data. It slots in after S2 (or S4), and before any real fighter.
- **Owner:** Simulation (loader), with Tools (schema and validator in `tools/`) and Narrative (identity text).
- **Files:**
  - `data/fighters/kai/fighter.json`, `data/fighters/vorr/fighter.json`;
  - `sim/core/roster.gd` loads them at `newMatch`.
- **Acceptance:** **the goldens do not change.** The same behaviour, now from data, is the proof that the move is lossless. A data hash also enters the goldens, so a data edit shows up as a golden change.
- **Size:** M. Section 2 below has the model.

### F1: The first real fighter. It needs D1 and the composer's stages 0 to 2 (Combat and Encounter: the event log, parity as data, one generative slot for the first fighter).
- **Recommendation to Orb, via the EP:**
  - **The Anti-hero** is the cheapest *complete* fighter. His profile is a mask and meters on the shared regions: the Proud front, Pride, Humbled, Drop the Act and Spite. He needs no new world systems and no extra bodies.
  - **The Protagonist** is the story lead. His profile, meters and forms are about the same size: the Rolls-with-it spread, the heat track with internal wear, Second Wind and the Respect-fed track forms. But his **final form needs the fold (§7), which needs W1**. So "Protagonist first" ships without his final form, which then lands after W1.
  - **The Empress** needs N1 (her guard). **The Cyborg** needs the chip rail, Press and the backup drive (Press works on civilians, which exist today). Both are later.
- **Per-fighter work:**
  - the profile code in `sim/core/wounds.gd`, as one strategy per profile type: plain, spread, pride_mask, refit, regrowth_chip;
  - meters and forms as data plus small rule code;
  - finishers per form tier (Combat);
  - AI use (Encounter);
  - readout variants (UI and Rendering).
- **Size:** L per fighter.

### W1: Variable planet circumference. Needed for the fold's proving ground (a third of the planet) and for procedural planets.
- **Owners:** Simulation (`SimWrap`, `SimConst.W` and `NC` moving into state or a planet record), then World (terrain arrays and generation).
- **Scope:** every wrap call site takes the planet: in core, world, director and the view.
- **Acceptance:** goldens unchanged at the default circumference, plus a seam-crossing test at a second circumference.
- **Size:** L. It is mechanical but wide.

### N1: N bodies on the field. Needed for the Empress's guard (the goon phase and the Encore).
- **Owners:** Simulation (fighters as an array of N with teams, a lock-on target that replaces `opp()`, `newMatch` from a roster list), then Encounter (one exchange at a time, target choice, support behaviour such as covering volleys as non-exchange wear hits), then Camera (framing N).
- **The spec's Encore fits one exchange at a time:** one guard engages while the others support. So the global single exchange (`S.dirS.ex`) can stay. Only `opp()` and the two-slot assumptions go (the list is in sim/README.md, "Hard-coded for two fighters").
- **Size:** L.

## 2. The roster data model (lands in D1; used by F1 onward)

```
data/fighters/<id>/
  fighter.json      identity (working name, role), base stats (speed, damage multiplier), readout ids
  wounds.json       regions (4, or 5 with the Empress's mantle, flagged brink:false), stage thresholds, recovery rates,
                    wear k, penalty keys per region and stage, profile {type: plain|spread|pride_mask|refit|regrowth_chip,
                    params}, rally {rule id, trigger params}, finishers {formTier: template id}
  meters.json       each meter: range, visible, fill sources (event -> amount), decay (rate, delay), spend rules
                    (for example Pride, heat, Wrath, Hunger, Respect; the prototype's menace and anguish as placeholders)
  forms.json        the transformation ladder: each form's fill rule (meter threshold or condition), cinematic ticks
                    (respected, capped per spec §8), deltas (damage, speed, rolls), gates
  moves/            the composer vocabulary, parts and specials (Combat; procedural-moves.md §11)
```

- **Numbers are data; rules are code.** A new *profile type* or *meter rule* is code (in `sim/core/wounds.gd`, `meters.gd` and `forms.gd`). A new fighter that reuses the types is data only: the composer's stage-5 modding test.
- **Determinism for data:**
  - Godot parses JSON numbers with the same, not correctly rounded, parser as literals. So the Tools validator enforces at most 15 significant digits, the same lint as `parity.gd`.
  - The loaded data are hashed into the goldens.
  - Timings in data are integer ticks.
- **State per fighter** (spec §4):
  - wear per region (int), stage, brink;
  - the rallied-region mask, and the Rally cooldown in ticks;
  - meter values; the current form, with its fill and cinematic timers in ticks;
  - profile state: the hatch timer, chip station and chip stage, the Pride mask, internal core wear.

## 3. Menace fixes: before Wounds

S0, above, runs as its own slice before S1. It is small, it is measured on the game QA's §9 target was set on, and it removes a 35/65 skew from every Wounds tuning run that follows. The composure bonus (+10% damage while anguish is under 10) is the fallback, and it lands in S0 only if QA's re-test falls short of 42%.

## 4. What can run in parallel

| Work | Parallel with sim slices? | Why |
| :--- | :--- | :--- |
| R1: crown with four arcs, wound cards (Rendering, UI) | Yes, once S1's fields and events are named. Stub the events until S1 lands | It reads state and events and writes nothing; `render/` and `ui/` are outside the goldens |
| R2: silhouette, the per-fighter readout variants | Yes | Same reason |
| T1: `data/fighters/` schema and validator (Tools) | Yes | Nothing loads the data until D1 |
| Combat data: region weights per atom, finisher skeletons, break-launch set pieces | Yes | Data only until Encounter's slice reads it |
| Narrative: card text, barks, stage names | Yes | Text |
| Composer stages 0 and 1 (event log, parity as data) | **No** | `sim/director` and the goldens: serialize with S2 and S3b (Encounter can do them back to back) |
| Any two sim slices | **No** | One working tree and one golden file. A second editor sees the first's half-made changes, and parity results become noise |

The practical pairing: Simulation and Encounter alternate sim slices (S0 → S1 → S2 → S3a → S3b → S4), while Rendering, UI, Tools, Combat and Narrative work alongside against the event names fixed in S1.

## 5. Risks

**Performance.**
- Matches grow from about 100 s to a median of 6 to 8 minutes, about 4 to 5 times the ticks.
- The golden check's match section grows from about 13 s to about 1 minute. For S2, cut the golden set from 17 matches to 8 (the eight arms, one seed each) to keep CI under 5 minutes.
- `batch.gd` drops to about 70 to 90 matches per minute, so a 1,000-match QA arm takes about 12 minutes. Add a `--jobs=N` option that spreads seed ranges over several Godot processes: a Simulation task, S1 or S2.
- Per-tick costs added by Wounds are small: 4 or 5 integers per fighter, and one draw per hit. The biggest current cost is the hero lure's route scan (+20 µs mean, Encounter). N1 multiplies AI and lure costs by the number of bodies.

**Determinism.**
- Region draws come from `S.rng`: intended, with goldens regenerated.
- The composer's counter-based streams (procedural-moves.md §10) should derive their keys with the existing `deriveSeed` (integer only), not a new hash.
- JSON number parsing is covered by the 15-digit lint.
- New timers use integer ticks. Wear is integer.
- Respected cinematics pause the director cooldown. Implement the pause as a tick count on `S`, never as a scaled dt, so hit-stop and slow motion stay the only float timers (hazard 1).

**Readability.**
- Four arcs, cards, a silhouette, heat, Pride and the fold all compete for attention. Ship R1 with the crown and cards only. The silhouette comes in R2, on in training and as the accessibility default.
- Spec §5 tests 8 to 11 are playtests and need a build with R1 plus S2 (playable Wounds) before F1.

**Scope.**
- HP removal (S2) reaches the AI (stance weights), camera framing, and every `hp <= 0` guard in the director: about 30 sites.
- Keep the `hp` field alive but unused until S2 lands, then delete it in S2's commit. Every change of ending semantics then happens in one slice.
