# Data fields for atoms, exchanges and signatures

Owner: Combat and Choreography. Audience: Tools and Pipeline, who decide the schemas (JSON layout, naming, validation tooling). This is the list of what the data must be able to say. It covers every atom and template in the prototype (`move-grammar.md`, `exchange-templates.md`) plus the proposals in those documents. Field names are suggestions; the meaning is the requirement.

`data/atoms/*.json` and `data/exchanges/*.json` will be drafted against the schemas once Tools has published them.

---

## 1. Principles the schemas need to support

1. **Content is data, logic is not.** An atom is a parameterised unit the engine knows how to run (rush, strike, launch, window...). A template is a timeline of atom instances with branches. New atom *types* need code; new atoms, templates and variants must not.
2. **Deterministic.** Every random choice is declared as a named draw, in order, so a seeded replay can reproduce it, and so the port can prove parity with the prototype. Presentation events never draw from the simulation RNG and never write simulation state (QA-002).
3. **Explainable.** Every branch decision records its inputs, its probability or rule, the roll or input that decided it, and a reason string for the debug feed. It also records a structured event for QA, so the feed text no longer has to be parsed (QA-004).
4. **Expressions, not code.** Timings, damages, forces and probabilities need small formulas: for example `clamp(dist/2600, 0.18, 0.65)`, `26 + 7*combo`, `0.5 + 0.07*(D.tier - A.tier)`. A whitelisted expression language is enough. Operators: numbers, `+ - * /`, `min`, `max`, `clamp`, comparisons, `&& || !`, ternary. Variables: section 5.
5. **Tier scaling is common.** Most values are `a + b·tier` or `a·(1 + b·(tier − 1))`. Consider a shorthand for these.

---

## 2. Atom fields (`data/atoms/*.json`)

| Field | Type | Meaning | Prototype examples |
| :--- | :--- | :--- | :--- |
| `id` | string, unique | stable identifier, dotted by family | `rush`, `rush.chain`, `strike`, `guard.drain`, `beam.connect` |
| `type` | enum | the engine behaviour this atom parameterises | `approach`, `strike`, `warp`, `launch`, `window`, `resource`, `clash`, `beam`, `hold`, `state` |
| `category` | enum | grouping for docs and tools | approach, offence, defence, launch, chain, clash, beam, hold |
| `displayName`, `description` | string | for tools and the previewer | |
| `actor` | enum `attacker` \| `defender` \| `both` | default performer; a beat may override it | `counter` is a `strike` with actor defender |
| `target` | enum `opponent` \| `point` \| `self` | what it acts on | |
| `duration` | expression, seconds | how long it runs; 0 for instantaneous | `rt`, `0.8*rt`, `0.24`, `0.55` |
| `warp.mode` | enum | how it moves the actor | `to_target` (rush), `behind_opponent` (dodge-warp, 74 u), `vertical_to` (beam rise), `burst_away` (slip, beam escape), `teleport_offset` (beam dodge, +300 y) |
| `warp.offset` | {x, y} expressions, u | x is along the actor's facing; negative means on the actor's side of the target | rush −58, rush.far −260, rush.chain −60 |
| `warp.track` | enum `live` \| `snapshot` | re-read the target's position each frame, or fix it at the start | all rushes track live |
| `warp.easing` | enum | motion profile | prototype: `remaining_fraction` (covers dt/remaining each frame) |
| `warp.terrain` | enum `pass_through` \| `slide` \| `stop` | collision with terrain during the move | prototype: `pass_through` with a clamp on the last frame (CC-006) |
| `warp.burst` | {speed expr, vy range} | for burst moves | slip: `1500 + 200*D.tier`, vy −150 to 300 |
| `hit.damage` | expression | base damage before the damage model | `base*1.4`, `24`, `52 + 7*combo` |
| `hit.knockback` | u/s | horizontal push on the target | 220 default, 120, 150 |
| `hit.hitstop` | seconds | freeze on contact (max-stacked) | 0.05 default, up to 0.16 |
| `hit.shake` | number | camera shake intensity | 6 default, up to 18 |
| `hit.parryable` | bool | may the defender's parry cancel it | false for `noParry` strikes |
| `hit.ignoreStance` | bool | skip the target's stance multiplier and the DEFENSIVE ki drain | true for guard-break finisher, chain links, beam HIT |
| `hit.catchAirborne` | bool | re-lock a launched or downed target (keep 10% velocity) | true for every strike today |
| `hit.weight` | enum `normal` \| `big` | presentation weight | `big` = 18 sparks instead of 9 |
| `launch.force` | expression | launch strength | 800 to 2,600 |
| `launch.direction` | enum `planner` \| `fixed` \| `along_beam` | who picks the direction | planner for melee; fixed (0.9·face, 0.5) for the KO launch; along the beam with a 0.12 lift for signatures |
| `launch.tierScale` | number | force × (1 + k·(tier − 1)) | 0.16 |
| `resource` | list of {who, stat, delta expr} | ki, power or hp changes | guard.drain: D ki −25; slip: A ki −3; chain: A ki −6 |
| `stateChange` | {actor, target} | state flips | slip frees D; connect launches D |
| `terrain.crater` | {radius, depth, condition} expressions | ground deformation | explosion: radius 0.9·r, depth `18 + 8*tier`, if within r of the ground |
| `terrain.area` | {radius, damage} expressions | structure and tree damage | clash wave: `160 + 40*tier`, `110 + 80*tier` |
| `window` | object, for window atoms | see section 4 | |
| `cancel.by` | list | what cancels this atom | `parry`, `ko`, `actor_dead`, `target_dead` |
| `cancel.onCancel` | enum `skip` \| `end_exchange` | what happens to it when cancelled | strikes: `skip`; proposal: windows `skip` after a parry (fixes CC-001) |
| `rng` | ordered list of {name, distribution, range} | declared random draws | dodge-warp: `heightOffset` uniform(−30, 70); launch: `spin` uniform(8, 16) |
| `events.sim` | list of {at, type, params} | simulation events (the structured log for QA) | `hit`, `launch`, `parry`, `crater`, `structure_damaged` |
| `events.fx` | list of {at, type, params} | presentation cues for VFX, audio and UI; never read by the simulation | ring, sparks, afterimage, banner text, shake |
| `anim` | {clip, keyMoments: [{name, at}]} | the authored anchor Animation keys to (anticipation, contact, recovery) | strike: contact at the beat |
| `legal` | {reviewId, status} | for any player-facing name | RL-006 for HORIZON CLEAVE |

---

## 3. Exchange template fields (`data/exchanges/*.json`)

| Field | Type | Meaning | Prototype examples |
| :--- | :--- | :--- | :--- |
| `id`, `version` | string | | `trade_blows`, `heavy_clash`, `pressure`, `guard_break`, `dodge`, `pursuit`, `charge_interrupt`, `signature` |
| `trigger.attackKind` | list of `light` \| `heavy` \| `sig` | | |
| `trigger.defenderState` | list of `AGGRESSIVE` \| `DEFENSIVE` \| `EVASIVE` \| `ESCAPE` \| `CHARGING` | | |
| `trigger.attackerStance` | list, or `any` | lets the attacker's stance select or modify a template (proposal: attacker-stance overlays) | `any` for every prototype template |
| `trigger.condition` | expression | extra gate | signature CLASH: `D.ki >= 40 && !ambush` |
| `trigger.priority` | integer | resolves overlapping triggers | |
| `locals` | map of name → expression | values computed once at plan time | `rt = clamp(dist/2600, 0.18, 0.65)`, `base = heavy ? 66 : 26` |
| `anchors` | map of name → expression | named times beats can be relative to | `contact = rt`, `fire = 0.8` |
| `selector.mode` | enum | how the branch is picked | `probability` (DODGE: `pRead`), `band` (HEAVY CLASH: WON below `p − 0.12`, COUNTERED above `p + 0.12`), `score_compare` (TRADE BLOWS, beam clash), `condition` (PRESSURE counter: `D.ki > 25` then 40%), `input` (proposals: a window's result picks the branch), `fixed` |
| `selector.formula` | expressions with clamps | probability or score formulas | `clamp(0.42 + 0.08*(A.tier - D.tier) + ..., 0.15, 0.8)` |
| `selector.overrides` | list of {if, branch} | hard rules that win over the roll | ambush: pursuit is always CAUGHT, dodge is always READ |
| `selector.decideAt` | `plan` \| a window id | when the branch is fixed; the prototype always uses `plan` | proposals decide some branches at a window |
| `selector.rng` | ordered list of draws | for replay parity | TRADE BLOWS: `scoreA` uniform(0, 1.6), then `scoreD` |
| `beats` | list of beat objects | shared beats before the branch point | rush, windup, first strike |
| `beat.t` | expression | time on the exchange clock, or relative to an anchor | `contact - 0.1`, `contact + 0.17` |
| `beat.atom` | atom id | | |
| `beat.actor`, `beat.target` | `A` \| `D` | override the atom's defaults | counter: actor D, target A |
| `beat.params` | map | per-beat overrides of atom fields | damage 34, hitstop 0.1 |
| `beat.guard` | list | skip conditions | `not_cancelled`, `target_alive` |
| `beat.label` | string | debug-feed text for this beat | |
| `branches` | list | the outcomes | |
| `branch.id`, `branch.tag` | string | feed tag; **each branch needs its own tag** (the prototype reuses TRADE BLOWS for both branches) | `heavy_clash.won`, "HEAVY CLASH — WON" |
| `branch.favours` | `attacker` \| `defender` \| `neutral` | who ends ahead; used by the coverage check | |
| `branch.beats` | list of beats | | |
| `branch.end` | {mode: `chain_window` \| `hold` \| `release`, at} | how the branch ends | GUARD HOLDS: chain window at `contact + 0.42` |
| `windows` | list of window instances | parry, chain and proposed windows with their timings | parry opens at the windup, closes at the first parryable strike |
| `limits.maxDuration` | seconds | validation bound on the whole exchange | |
| `limits.maxDeadAir` | seconds | the longest allowed stretch with nothing authored happening (the charter's "no dead air") | proposal: 0.25 |
| `debug` | {inputs: [names], reason: template string} | what the debug feed prints for this decision | "pRead 0.50 (tier +0, ATK +0.08) roll 0.31 → READ" |
| `log` | event type and fields | structured event for QA | {type: exchange, template, branch, A, D, kind, stances, ambush, damage, launch} |

---

## 4. Window fields

Windows are atoms of type `window`, used by templates at specific beats.

| Field | Meaning | Prototype | Owner of the number |
| :--- | :--- | :--- | :--- |
| `kind` | `parry`, `chain`, or a proposed kind (`read`, `break_away`, `brace`, `burst`) | parry, chain | Combat |
| `owner` | who may act: `attacker` \| `defender` | parry: defender; chain: attacker | Combat |
| `inputs` | which inputs count | light or heavy (the signature key never counts, CC-010) | Controls and Game Feel |
| `opensAt` | expression or beat reference | parry: the windup; chain: the WIN beat | Combat |
| `closesAt` \| `closesOn` | a time, or an event such as `first_parryable_strike` | parry closes on the strike; chain after 0.6 s | Controls and Game Feel (width) |
| `buffer` | how early a press may be remembered | none | Controls and Game Feel |
| `lockout` | penalty for a press outside the window (anti-mash) | none (CC-008) | Controls and Game Feel |
| `maxUses` | per exchange | chain: combo below 5 | Combat |
| `cost` | resource paid on use | chain: 6 ki | Game Design |
| `onSuccess` | the branch or beats that follow | parry: cancel and punish; chain: append a link | Combat |
| `cue` | presentation cue while open (`events.fx`) | none (CC-011) | UI/UX and VFX |
| `ai` | reference to an AI policy; policies live with the AI, not in the template | parry press chance 0.5/0.3/0.12; chain press chance `clamp(0.62 - 0.14*combo, 0.05, 0.6)` | Encounter Systems |

---

## 5. Variables the expressions need

- **Exchange:** `dist`, `rt`, `heavy`, `kind`, `combo`, `ambush`, `ex.t`, and the named anchors.
- **Each fighter (`A`, `D`):** `tier`, `ki`, `hp`, `maxhp`, `power`, `stance`, `state`, `role`, `menace`, `anguish`, `care`, `altitude` (height above ground), `biome` (under the fighter), `submerged`, `hidden`, `hiddenFor`, `face`.
- **World:** `popNear(x, r)` (population nearby, 0 to 1), `groundY(x)`, `biomeAt(x)`, `seaAt(x)`, and the casualty and structure counters.

---

## 6. Supporting tables the templates reference

These may be separate files or part of the fighter and biome schemas. Tools decides where they live.

- **Combat rules** (global damage model). Values at `index.html:319-338`:
  - stance damage multipliers 1.12 / 0.38 / 1.0 / 1.25
  - the DEFENSIVE ki drain, 8% of damage taken
  - striker ki gain 4% and power gains 1% and 0.6% of damage
  - combo scaling 0.12, ambush 1.5, tier scaling 0.09
  - villain menace bonus 0.25, hero comeback bonus 0.5
  - director cooldowns 0.22, 0.6 and 0.5 s
- **Stances.** Id; damage multiplier taken; movement multiplier (1.0, 0.8, 1.25, 1.35, `index.html:771`); whether it can hide (ESCAPE); a reference to its attacker overlay (proposal).
- **Fighters** (only the fields combat reads): `sigName`, a reference to the signature, `care`, `dmgMul`, `spd`, `maxhp`, and a clash bonus rule (menace × 0.08 for the villain).
- **Biomes** (only the fields combat reads): the signature material key (section 7), cover type, carve presentation (dust colour, particle set). The launch-planner bonuses belong to Encounter Systems.

---

## 7. Signature variant fields

Signatures are the one place where a single move must change with context (pillar 7). Recommended as their own data (for example `data/exchanges/signature.json` plus a variant table), with these fields:

| Field | Meaning |
| :--- | :--- |
| `id`, `name` | variant id and player-facing name (with `legal`) |
| `keys.material` | the biome material that selects it; the prototype keys on the biome under the defender |
| `keys.altitudeBand` | submerged, ground, low air, high air (cut points in `signature-variants.md`) |
| `keys.outcome` | CLASH, GUARD, DODGE, HIT, ESCAPE, plus any proposed outcomes |
| `keys.collateral` | condition on population nearby or the casualty state |
| `keys.role` | hero or villain, or a personality weight such as `care` |
| `layers.charge` | charge time, rise rule, charge presentation |
| `layers.geometry` | aim rule, length, width, sweep time, path shape (straight, arc, sweep, dive) |
| `layers.carve` | crater radius and depth, carve threshold, material effect (glass, fire, bore, steam...), whether the effect follows the ground under each sample or the variant |
| `layers.outcome` | modifiers to outcome resolution (for example a deflect instead of a guard) |
| `layers.followUp` | launch force and direction, explosion, lingering hazard |
| `presentation` | dust colour, particles, banner; `events.fx` only |
| `precedence` | how layers combine when several keys match (for example material, then altitude, then outcome, then personality) |
| `distinctness` | the fingerprint fields QA compares to verify "never plays the same way in two contexts" |

---

## 8. Validation Tools could enforce

1. Every `beat.atom` exists, and every expression uses only known variables.
2. Beats are ordered, times are non-negative, and every branch ends in `chain_window`, `hold` or `release` within `limits.maxDuration`.
3. Every parryable strike is preceded by a windup in the same branch (catches CC-009).
4. Branch probabilities partition 0 to 1; every declared draw is used, in the declared order.
5. **Coverage:** build the attacker stance × defender state × attack kind matrix (60 cells) from the triggers. Fail if a cell has no template or fewer than two branches with different `favours` or different tags. This makes the P2 exit criterion a data check.
6. **Gap close:** every melee branch starts with an approach atom that guarantees contact (pillar 3), or is explicitly marked as an escape.
7. No `events.fx` entry writes simulation state or draws from the simulation RNG.
8. Every player-facing name carries a Legal review id before a release build.
9. `limits.maxDeadAir` is respected by the authored timeline (static check), and QA confirms it in play.

---

## 9. Time, windows, read-by and the Animation hook (EP amendment, 2026-09-28)

**Time unit.** New data stores times as integer **ticks** at 60 per second. Expressions that yield seconds (for example `rt`) are converted once, at plan time, with a documented rounding rule. The stage-1 parity data (`procedural-moves.md`, section 12) may carry the prototype's seconds, with a `timeUnit` field, until parity is proven.

**Window instances.** Each template branch lists its windows as data, and each strike beat carries its own `parryable` flag:

| Field | Meaning |
| :--- | :--- |
| `id`, `kind`, `owner`, `inputs` | as in section 4 |
| `startTick` | when the window opens, relative to the exchange start (or to an anchor) |
| `endTick` or `closesOn` | when it closes: a tick, or an event such as the first parryable strike |
| `parryableStrikes` | the ids of the strike beats this window can cancel |

Today's windows in ticks, derived from the wind-up beat to the first strike without `noParry` and confirmed by the census (`exchange-templates.md`, section 4):
- parry in TRADE BLOWS, PRESSURE and GUARD BREAK: 6 ticks (0.100 s measured);
- parry in HEAVY CLASH — WON: 19 to 20 ticks (0.317 to 0.333 s measured);
- no parryable strike in DODGE, HEAVY CLASH — COUNTERED, CLASH SHOCKWAVE, PURSUIT, CHARGE INTERRUPT, chain links or signatures;
- chain: 36 ticks.

Widths are Controls and Game Feel's; which templates have windows is Combat's (`exchange-templates.md`, section 5.2).

**Read by.** Every field in section 2 is **sim-read** except these, which are **render-only**:
- `displayName`, `description`
- `hit.weight` (presentation weight)
- `events.fx`
- `legal`
- everything under `anim` except the pose families below

Render-only fields must never change simulation state; the validation in section 8 checks this.

**Animation hook** (per atom or part):

| Field | Read by | Meaning |
| :--- | :--- | :--- |
| `anim.clip` | render-only | the clip to play |
| `anim.contactFrame` | render-only, validated | the clip's contact frame. Validation checks that it lands on the atom's sim contact tick, within the part's stretch range |
| `anim.keyMoments` | render-only | anticipation, contact, recovery and hold frames, for camera and fx cues |
| `anim.rootMotion` | render-only | presentation offset; simulation positions always come from the atom (warp, launch) |
| `anim.poseIn`, `anim.poseOut` | **sim-read** | symbolic pose families used by the procedural composer's joining rule (`procedural-moves.md`, section 2.2); tags, not animation data |
| `anim.hitVolumes` | reserved, sim-read if adopted | the prototype has no hit volumes (every strike connects on its beat); reserved in case a later build uses them |

The procedural move system's part files (`procedural-moves.md`, sections 2.2 and 11) follow the same split: a `sim` block and a `render` block.
