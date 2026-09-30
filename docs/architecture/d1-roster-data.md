# D1: the roster as data (plan)

Status: plan only (Simulation, 2026-09-29). D1 runs after World's B1 and Controls' Stage A. F1 (the Anti-hero) builds on it. The model is in `wounds-plan.md` §2. This page fixes the schema, the loader and the proof, so Tools, Narrative, Game Design and Combat can review before any code lands.

## 1. Goal and proof

Every per-fighter number and rule choice moves out of code into `data/fighters/<id>/`, with no change in behaviour.

**The proof: the goldens do not change.** That covers the tick-0 states, the 8 matches, the replays, the wounds and Rally vectors, and the constants vector.
- D1a also adds hashed fields: the exchange index (§4b) and the roster data hash.
- So the proof is done in two steps, in this order:
  1. With `exN`, `ex.n` and the data hash left out of the hash, one run must reproduce the **pre-D1a goldens exactly**.
  2. The goldens are then regenerated once, with those fields in.

## 2. Scope: two steps

| Step | Moves to data | Code touched | Owner of the code |
| :--- | :--- | :--- | :--- |
| **D1a** | Identity, base stats, the Rally rule, finisher keys, the wound numbers and the profile type (`plain`). Also the exchange index and keyed draws (§4b), so Encounter's Q4 starts with them ready | `core/roster.gd`, `core/wounds.gd`, `core/sim.gd` (setup), a new `core/fighter_data.gd`, `core/state.gd`, `core/hash.gd`, `core/rng.gd`; `director/data.gd` (the finisher key); `director/exchange.gd` (one line, granted to Simulation for D1a) | Simulation (Encounter reviews the two director lines) |
| **D1b** | The power ladder (tiers today), and menace and anguish as meters | `core/fighter.gd`, `core/damage.gd`, `director/launch.gd`, `world/structures.gd` (casualty pressure) | Simulation, with the tree handed for director and world |

D1a is small and self-contained. D1b touches other owners' files, so it waits for the EP to hand over the tree. Forms (transformations), per-fighter meters such as Pride, and the other profile types are F1 and later. They use the same files and schemas.

## 3. Files

```
data/fighters/<id>/          id: the stable roster id (Fighter.id, "KAI" today; D1 keeps the upper-case ids so the
                             finisher data and QA records still match)
  fighter.json               identity, base stats, slot defaults, rally, finishers        (D1a)
  wounds.json                regions, thresholds, rates, k, family weights, penalties, profile   (D1a)
  ladder.json                power tiers: fill rate, thresholds, per-tier deltas           (D1b)
  meters.json                menace, anguish (placeholders), later Pride, heat and others  (D1b)
  forms.json                 transformations (F1 onward; spec-wounds §8)
data/fighters/roster.json    ["KAI", "VORR"] (Tools' schema today; the loader also takes {"schema": "roster/1", "order": [...]})
```

`fighter.json` for KAI holds today's values exactly (VORR's file has the same shape):

```json
{
  "schema": "fighter/1",
  "id": "KAI",
  "identity": { "name": "KAI", "title": "Meridian Warden", "role": "hero", "sigName": "Meridian Lance",
                "col": "#3d8fdc", "aura": "#8fd6ff", "hair": "#22c7a9" },
  "stats": { "care": 1.0, "dmgMul": 1.0, "spd": 1.0, "maxhp": 1600.0 },
  "kit": { "canHide": false },
  "rally": { "rule": "second_wind" },
  "finishers": { "base": "kai" }
}
```

- **`identity`** is Narrative's text (`docs/narrative/identity.md`), plus Art's colours until Art has real readout ids. `role` is one of `hero`, `villain` or `rival` (the Anti-hero). It is a label only and never gates mechanics: meters come from the profile (Game Design's data-driven ruling). Today's `role ==` branches (menace, anguish, composure, regen) stay until D1b replaces them with meter checks. A `rival` must not play before D1b; the loader accepts the value from D1a.
- **`rally.rule`** is one of `second_wind`, `spite`, `reboot`, `encore` or `none`. Parameters come with each fighter. For Spite that is the mend order; for Reboot the dock and Press ranges; for Encore the input window, 180 ticks. Every rule's code stays in `wounds.gd`, so the data only chooses a rule and its numbers.
- **`finishers`** maps a form tier to a finisher template id in `data/combat/finishers.json`. D1a reads `base`. F1 adds form tiers. Combat's `select.byFighter` becomes a fallback during D1 and is removed in F1 (Combat's call).

`wounds.json` holds today's `SimWounds` constants, under the same names:
- `regions`: head, core, arms and legs. Each has `brink` (true, or false for the Empress's mantle later).
- `stageAt`: `[180000, 360000, 540000]`, in units.
- `wearPerDamage`: 228, which is k 0.038 × 6000 (Game Design's interim value with the stricter brink, spec §1b).
- `brinkLimbs`: 3. The brink is the core broken, or this many of head, arms and legs broken. `brinkProgress` reads the limb that completes it, the least worn of the three.
- `act1Damping`: 0.85, the wear multiplier while the act index is 1. Until M1 owns the act, it is `SimWounds.act(S)` = 1 + `S.game.breaks`, where `S.game.breaks` is region breaks so far, both fighters, hashed.
- `overtime`: `startTicks` 28800, `perMin` 0.25, `cap` 3.0, meaning k × min(3, 1 + 0.25 × minutes past 8:00). That is candidate A. Candidate B is 30600 and 0.40. QA switches by editing both fighters' files.
- `fade`: `out` 25, `breath` 100, `breathAfterTicks` 240, `hidden` 300 and `hiddenFloor` 354000.
- `focusWear`: 30.
- `family`: the four weight rows.
- `penalties`: one key per region and stage, with the S3a and S3b numbers.
- `profile`: `{ "type": "plain" }`.
- `rally`: `rallyWear` 534000 and `coolTicks` 900.

`breathAfterTicks` is an integer. The code keeps comparing it with `S.T - f.exT` in seconds (4.0 is exactly 240 / 60) until S.T itself becomes ticks.

## 4. Loader

- **`FighterData` (`core/fighter_data.gd`).** It is loaded once per process, like `DirData`. It parses `roster.json` and each `<id>/*.json` into one immutable def per id. `createFighter` copies the scalar fields into `Fighter`, as today, so the hot path never reads a Dictionary. The wound numbers go into one `WoundsDef` object per id, and `f.wd` points to it. Every `SimWounds` constant becomes `f.wd.<name>`. Today's numbers are identical for both fighters, so behaviour cannot move.
- **Numbers.**
  - Godot's JSON parser returns every number as a float.
  - Integer fields (units, ticks, bit counts) are checked for integral values and converted with `int()`.
  - Floats follow the literal rule: at most 15 significant digits, enforced by Tools' validator and by the loader in debug builds.
  - The constants vector in the goldens compares every loaded number with the old constant bit for bit. That is the exactness check for the JSON path.
- **Hash.**
  - `FighterData.dataHash()` hashes the parsed content canonically: sorted keys, and keys starting with `_` skipped. Comments and whitespace are free to change; any number or rule change shows up.
  - The replay header's `data` becomes the hash of the combat data plus the roster data. That is one field, so replay format v2 stays.
  - The goldens gain `rosterHash`, and parity names it when it differs, so a data edit fails with a clear message rather than a first-difference tick.
  - `DirData` can move to the same canonical hash; that is Combat's and Encounter's call.
- **Setup (the planned replay `setup` block).**
  - `newMatch(S, seed, ai, setup)` takes `setup = {"slots": ["KAI", "VORR"], "names": [...], "spawn": [...]}`. The default is today's pairing and positions.
  - QA's arms become setups: swap is `["VORR", "KAI"]`; mirror-hero is `["KAI", "KAI"]` with names KAI-A and KAI-B; `-flip` swaps the spawns.
  - The replay header records `setup`, so a replay replays its arm.
  - `golden_recipes.gd applyArm` stays for the D1a goldens (unchanged by construction). QA's runner moves to setups when it next re-baselines.

## 4b. The exchange index and keyed draws (for Encounter's Q4)

- **State:** `S.dirS.exN: int`, the exchanges started this match, and `ex.n: int` on each exchange.
  - `DirExchange.requestAttack` bumps them where the exchange starts: `S.dirS.exN += 1; ex.n = S.dirS.exN`, next to `S.dirS.ex = ex`, the point that emits `attack`.
  - Chain links stay inside their exchange (`ex.combo`). Finishers run inside theirs.
- **Hash:** `exN` joins the `dirS` walk after `lastLaunch2`, and `n` joins the exchange's field list.
- **`SimRng.keyed(seed, key, n) -> float` in [0, 1):** a stateless draw.
  - It is the fmix32 of the match seed, the key's FNV-1a hash and `n`: the same mixing as `deriveSeed`, with `n` folded in. The result is divided by 2^32.
  - A composition draw is `keyed(int(S.game.seed), "compose", ex.n)`, or it keys on `ex.n` and `ex.combo` for a chain link.
  - It never reads or advances `S.rng`, so adding, removing or reordering a keyed draw cannot shift any other draw. That is what composition needs.
- **Unit test** (in `parity.gd`, with a vector in the goldens):
  - the same inputs give the same value, twice and across a fresh process (the golden vector);
  - `S.rng.a` is unchanged after 1000 keyed calls;
  - different keys, and consecutive `n`, give different values;
  - values fall in [0, 1).
- **Goldens:** the counter changes only the hash, not behaviour (proof in §1). The keyed draws change behaviour only where Encounter uses them, with Q4's own golden change.

## 5. D1b in brief: ladder and meters

- **`ladder.json`**: `fillPerSec` 0.45, `thresholds` [25, 50, 75], and per-tier deltas: speed +0.10, damage +0.09, launch force +0.16. It also holds the power-up crater and area-damage coefficients. Forms (F1) extend it with a fill rule per form and cinematic ticks, capped per spec §8.
- **`meters.json`**: each meter has
  - `range`, `start` and `visible`;
  - `sources` (event, amount, cap and whose: self or the opponent);
  - `decay` (rate, and delay in ticks);
  - `effects`, from a closed list of effect keys that code implements: `regen_bonus`, `regen_penalty`, `damage_mul`, `composure`.
- **Menace and anguish** become two meters with today's numbers:
  - menace: `MENACE_DECAY` 0.4, quiet 240 ticks, cap 100, regen +0.03 per point, the damage cap 0.15;
  - anguish: decay 0.6 per second, regen −0.025 per point, composure below 10.
  - The `role == "hero"` and `role == "villain"` branches become "has this meter". The QA-003 bug (casualties pressure only the first hero) is fixed there, with World and Game Design, as the EP routed it.

## 6. Owners and hand-offs

- **Tools:** the JSON schemas in `tools/schemas/` (fighter, fighter-wounds, fighter-ladder, fighter-meters, fighter-roster) and the validator, with the 15-digit lint. A change to a data shape updates its schema in the same commit, or CI's data job, which gates deploy, fails. The D1a report lists every shape it lands, so Tools can tighten the schemas in that commit.
- **Narrative:** the identity text. **Art:** readout ids when they exist.
- **Game Design:** the numbers. D1 only moves them. Retunes happen after, as data edits.
- **Combat:** the finisher key move (§3).
- **QA:** arms as setups; re-baseline once the roster hash enters the goldens.

## 7. Acceptance

1. With `exN`, `ex.n` and the data hash left out of the hash, a run reproduces the pre-D1a goldens exactly, and the constants vector holds bit for bit. Only then are the goldens regenerated, once, with the new fields and `rosterHash`.
2. Editing a number in `data/fighters/KAI/wounds.json` fails parity, naming the roster hash. Editing a `_note` does not.
3. A third def, copied from KAI with a new id and name, loads and plays a match (the stage-5 modding test in miniature) with no code change.
4. A replay recorded with a mirror setup plays back from its header alone.
5. The loader rejects: a non-integral tick; a float with more than 15 significant digits; an unknown Rally rule, profile type or effect key; a duplicate id.
6. The `keyed()` unit test passes (§4b): stateless, `S.rng` untouched, distinct across keys and `n`, in [0, 1).

## 7b. D1a as built (2026-09-30)

**Data files.**
- `data/fighters/roster.json`: `["KAI", "VORR"]`, a bare array, per Tools' current schema. The loader also accepts `{"schema": "roster/1", "order": [...]}` for when Tools switches.
- `data/fighters/<id>/fighter.json` and `wounds.json`, as in §3.
- `data/fighters/<id>/meters.json`, which D1a reads only for **which meters a fighter has** (`hasAnguish`, `hasMenace`: World's data-driven meters from da5fb09).
  - Its numbers document today's rules in D1b's shape, and D1b wires them.
  - It is needed because `fighter.json`'s `kit` is closed in Tools' schema. The flags could move to `kit` if Tools prefers.

**Loader** (`sim/core/fighter_data.gd`).
- `FighterData.def(id)` returns the def. `createFighter` copies its scalars and sets `f.wd` (a `WoundsDef`) and `f.finisher`.
- `newMatch(S, seed, ai, setup)` takes `{"slots", "names", "flip"}`. `flip` swaps the spawn sides, in place of spawn coordinates, so a setup survives world-scale changes.
- `errors()` collects every problem. `loadFrom(dir)` and `quiet` exist for the negative controls.

**Pinned values.**
- These stay `SimWounds` constants because other owners' files read them:
  - `STAGE_AT` (sim/director/ai.gd, qa/godot/records.gd);
  - `FADE_HIDDEN_FLOOR` (ai.gd);
  - `HEAD_PARRY_NARROW` (sim/director/melee.gd);
  - `HEAD_DEFENCE` and `LEGS_SLIP` (sim/director/data.gd).
- The loader rejects data that differs from them, so an edit can't be silently half-applied. Each unpins when its reader moves to `f.wd`.

**Not moved in D1a.**
- `data.gd` still selects finishers by `select.byFighter[W.id]`. `f.finisher` is loaded and equal ("kai", "vorr"), and becomes the selector when Combat and Encounter switch that line.
- The overtime ramp moved to `wounds.json` in the brink and spread slice (see §3).

**The proof, as run.**
1. With `exN` and `ex.n` left out of the hash (and no roster hash in the goldens), parity passed against the untouched pre-D1a `golden.json` (d8ed601). That covered the tick-0 states, the wounds and Rally vectors, all 8 matches (144,000 ticks, every per-tick digest and checkpoint) and both replays.
2. The goldens were then regenerated once.

**Also in the regeneration:**
- a ninth golden match, default seed 11, with the 43,200-tick cap. It ends in a finisher and a KO at 19,084 ticks;
- `rosterHash` and the keyed vector;
- a bug fix in `SimGolden.applyArm`. Since da5fb09 it moved only the identity keys, so the meters, kit, Rally rule and wound data stayed with the slot: a swapped VORR kept KAI's anguish. The swap and mirror matches changed with the fix. The parity check "arm setups" now holds `applyArm` equal to the setups.

**Parity checks added:**
- roster data (clean, and the hash names itself);
- the loader's negative controls (a non-integer, 16 digits, an unknown Rally rule, profile or meter, a pinned value, a duplicate id; a `_note` edit keeps the hash, a number edit changes it; a third fighter from data plays a match);
- keyed draws;
- arm setups;
- a setup replay.

`check()` now fails a check that returns null (one that stopped on a script error). Before, a crashed check could print "ok".

## 8. Risks

- **JSON number parsing is a second path to the same doubles.** Criterion 1 catches any difference. The fallback is to store the few awkward values as the hex bits `SimMathx.f64` already reads.
- **`f.wd.<name>` lookups** cost a field read per use instead of a constant. The bench in parity shows whether that matters. The mean tick is 86 µs today.
- **Data files are match inputs.** A modded file changes outcomes. That is why the hash goes in the replay header and the goldens.
