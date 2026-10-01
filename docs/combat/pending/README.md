# Parked data for Encounter's step 2b

Merged, ready-to-apply copies of the three combat data files, prepared on 2026-10-01 from the live files. They are parked here because they change the combat data hash and the goldens; files under `docs/` are not loaded or hashed by the sim. The EP says when to apply them. They replace the earlier Q4 copies.

| File | Applies to | Built from |
| :--- | :--- | :--- |
| `templates.2b.json` | `data/combat/templates.json` | the live file, plus the step-2b plan (`../control-scheme-data.md`) |
| `finishers.2b.json` | `data/combat/finishers.json` | the live file, plus the parked Q4 batch (kinds, the struggle by state, the cue names) |
| `styles.2b.json` | `data/combat/styles.json` | the live file, with the heat table and the blitz cap as real fields |

**Preserved from the live files:** `"profile": "dynamic"` (templates), `"profile": "authored"` (finishers), `contest.brinkSetups` 2, `contest.timeCapAt` 660, and `scoring.base` 0.23.

**Untouched:** the `parity` and `spaced` profiles, checked field by field against the live file, so the frozen parity copy needs no refresh.

**If a data file changes before these are applied,** merge by field; never overwrite.

## What is in `templates.2b.json`

| Change | Detail |
| :--- | :--- |
| **Strike classes** | Every strike in the `dynamic` profile carries `o.class` (`opener`, `heavy`, `ender`, `blast`, `mid` or `none`) in place of `o.noParry` |
| **The 2b parry rule** | Until step 3 wires per-strike windows: a strike can be parried only when its class is `opener`, `heavy` or `ender` **and** it is the attacker's first strike after a `wind` beat. That is exactly today's behaviour. The rule is written in `profiles.dynamic.strikeClass` |
| **Wind-ups** | `profiles.dynamic.windups` (ticks by class), `tempo.enderWindup` 18, and `approach.minHeavy` (20 ticks) so a heavy opener's wind-up fits inside the approach |
| **Timing edits** | GUARD BREAK's wind-up tell is 20 ticks (was 15). A DODGE read strikes 20 ticks after the dodge (was 14), and the counter 15 (was 14). TRADE BLOWS' deciding blow has an 18-tick wind-up |
| **The "circle" beat is gone** | It passed through the opponent. TRADE BLOWS now has a backstep (9 ticks) and a lunge back in (the 18-tick wind-up), on the same side. The cue is `backstep` |
| **The Neutral column** | New templates `clean_hit` (light) and `clean_hit_heavy`, with branches CLEAN HIT and CLIPPED, chosen by `defClipped` with no draw |
| **Request-only counters** | `selectorByProfile.dynamic` on four templates. `dodge`: not read gives the counter only with `defQueued`, else the new DODGE — CLEAN branch. `pressure`: fixed GUARD HOLDS, no roll (R4 re-ruled). `trade_blows` and `heavy_clash`: the retreat-entry terms (`defEntry`, `atkEntry`) |
| **The answered beam** | `beam.outcomeByProfile.dynamic`, decided at the fire beat: an answering signature or heavy blast gives CLASH (the blast at −10); a perfect block DEFLECT; then the held state; otherwise HIT. The automatic clash rule stays only in the old profiles |
| **Interrupts (data for step 3)** | A top-level `interrupts` block (perfect block, reversal, dodge cancel, burst), `interrupts` lists on the branches that allow them, `profiles.dynamic.perfectBlock` and the `riposte` template. Nothing reads them in 2b |
| **Kept for now** | `profiles.dynamic.parry`: it leaves at step 3, so behaviour does not change early |

## What is in `finishers.2b.json`
- `kind` on every finisher: `generic.placeholder` launch, `generic` launch, `kai` beam, `vorr` launch. The loader's `finisherKind` already reads it.
- `contest.struggle.byState`: base 0.23, the stance read, the ki bonus, and the tilts. The press fields stay until Encounter switches the struggle over.
- 36 new cue names, including `backstep`, `perfect_block`, `riposte` and `reversal`.

## What is in `styles.2b.json`
**Teleporting is on hold (Orb, 2026-10-01).** The `blink_clash` style is switched off with `weight.base` 0, and the `blink` trait has no effect. The style, its overlay and the three blink cue names stay in the data so the cross-references still resolve. No other parked file uses a blink.

`chains.chainP.heat` (Heated 0.05, Simmering 0.10, Boiling 0.20) replaces `heatBoiling`, and `chains.blitz.chance.cap` is 0.60. The `_heat` and `_cap` notes are gone.

## Schema changes for Tools (same commit)

| # | Schema | Change |
| ---: | :--- | :--- |
| 1 | templates | `trigger.defender` gains `NEUTRAL`; `trigger.context` (`riposte`) as an alternative to `defender` |
| 2 | templates | a template or branch may carry `"only": ["dynamic"]`, and then needs only that profile's beats |
| 3 | templates | a strike's `o.class` (the six values); `noParry` stays valid in the old profiles |
| 4 | templates | `selectorByProfile` (profile name to selector). New selector kind `condition` (`if`, `then`, `else`, no draw). A `threshold` selector's `else` may be a condition object. `defenderAdd` on `score_compare`. New variables `defQueued`, `defClipped`, `defPerfect`, `defEntry`, `atkEntry`, `defAnswer`; the condition form `{"var", "is": string}` |
| 5 | templates | `profiles.dynamic`: `tempo.enderWindup`, `approach.minHeavy`, `windups`, `perfectBlock`, `strikeClass` |
| 6 | templates | top-level `interrupts`; a branch's `interrupts` list; the beat op `stagger`; `when: "riposteLaunch"` |
| 7 | templates | `beam.outcomeByProfile` (`decideAt`, ordered `rules` with optional `defender`, `if`, `clashScoreAdd`); the outcome `DEFLECT` |
| 8 | finishers | `finisher.kind` (launch, melee, beam); `contest.struggle.byState` |
| 9 | styles | `chains.chainP.heat` and `chains.blitz.chance.cap` required; `heatBoiling` removed (Tools' Q4 script already does this) |
| 10 | cross-references | the new cue names are in the vocabulary; `backstep` replaces `circle` in TRADE BLOWS |

## What Encounter reads in 2b
- `o.class`, with the 2b parry rule above.
- The NEUTRAL templates and the `condition` selector (`defClipped`).
- `selectorByProfile.dynamic` (`defQueued`, and the entry terms, which are 0 until entries are wired).
- `beam.outcomeByProfile.dynamic` at the fire beat (`defAnswer`).
- `approach.minHeavy`, `tempo.enderWindup`, and the finisher `kind`.

`interrupts`, `perfectBlock`, `riposte` and the DEFLECT rule wait for step 3.

## Checks when applying
1. The loader regression on the untouched frozen parity copy.
2. `node tools/validate.js` with Tools' schema changes: 0 errors.
3. QA's feel probe: the wind-ups add about 0.1 to 0.2 s to GUARD BREAK, DODGE reads and TRADE BLOWS.

## The contact change (applies after 2b)

`templates.contact.json` and `finishers.contact.json` are the 2b files plus the contact-spacing change (`../contact-spacing.md`): a step-in before every strike that needs one, the chain catch ending on its strike, the sides (`side`, `endSides`) and the `contact` block. Only the `dynamic` profile and the authored finishers change.

- **Apply after 2b**, in its own commit, with the schema additions listed in `../contact-spacing.md` section 6 (a branch's `endSides`; `tempo.stepIn` and `tempo.chainClose`; `profiles.dynamic.contact`).
- **Measured** on the live sim with a read-only probe (12 matches): strikes beyond 68 u fall from 52% to 2%. The remainder needs Encounter's sim-side rules.
- **Strike lead (Animation's ask).** Every strike beat is already in the list 12 ticks or more before it lands, so no beat moved. The rule is the `_lead` note in `profiles.dynamic.contact`. The blows Animation saw arrive late are the leftover strike beats of parried exchanges (`../contact-spacing.md` section 7): a sim and render fix, which should land with the contact data or before it.
- **Encounter's four constants, now data.** The `dodge` beat with `"side": "cross"` carries the step-around's length (`dur`, 8 ticks, `tempo.stepAround`), rise (`rise`, 98 u) and end distance (`off`, 74 u); the contact block carries the placement limit (`placementReaches`, 3). Two more schema keys for `apply-contact.cjs`: `tempo.stepAround` and `contact.placementReaches` (`../contact-spacing.md` section 6, rows 4 and 5).
- `styles.2b.json` is not affected.

## Start here: `waves-index.md`

One page for Orb: what each of the six waves adds in plain words, its new-pose count, what it needs before it can play, and the order they could go live in.

## Wave 1: the Anti-hero's strike specs (for Animation; not for applying)

`wave1-strikes.md` and `strikes.antihero.wave1.json` are the 38 key strikes as specs to pose from: base family, limb and target socket, weight, reach and the strike's own contact distance, timing, limb tags and one line on the look. 34 can be posed now (11 derive, 23 need a contact pose); the 4 tail strikes are held until Orb rules on the tail. Section 6 of the sheet notes what a per-strike contact distance changes in the live contact data at M0. Legal screened wave 1: GO, with its conditions now in the rows (`docs/legal/rule-of-cool-screen.md`). The `.2b.json` and `.contact.json` files in this folder are live now and kept for reference.

## Wave 2: the Anti-hero's entry specs (for Animation; not for applying)

`wave2-entries.md` and `entries.antihero.wave2.json` are the 15 entries (rush 6, stand 5, retreat 4) as specs to pose from: path, when it is offered, timing, where it plays, the new poses and what they derive from, the strikes it favours and one line on the look. 12 new poses. Eleven entries work on today's sim; the arc dive, the skid and the spiral need a path on the `rush` op, and the lane step needs fight lanes. Legal screened wave 2: GO, with its conditions in the rows.

## Wave 3: the ping-pong rally and the flight paths (not for applying)

`wave3-pingpong.md` and `pingpong.antihero.wave3.json`: the rally's beats in ticks, the `return` strike class, the 7 return blows and 16 enders as they play in a rally, three knock patterns, the defender's answers, and one new pose (the intercept turn). Section 2 is the one definition of the three flight paths (spiral, arc, ground) and the `path` event, for Encounter, Camera and VFX.

## Wave 4: the grab and throw family (for Animation; not for applying)

`wave4-grabs.md` and `grabs.antihero.wave4.json`: 16 pieces (2 grabs, the hold, 7 throws, the tackle, the dive grab, the reversal) with grip, ticks, limb tags, where each throw sends the rival and one line on the look; the turning throw as Game Design ruled it; the `held` state the sim must carry for the pinned ragdoll. 22 new poses, and 2 for the tail throw, which is held until Orb rules on the tail. Legal screened waves 3 and 4: GO, with its conditions in the rows.

## Wave 5: the pulse clashes and the beam answers (for Animation; not for applying)

`wave5-clashes.md` and `clashes.antihero.wave5.json`: the fist clash, the blur exchange and the grapple lock on Game Design's pulse (ticks, what is composed from the strike and grab pools, the strain poses), and the three looks of a perfect block against a signature (swat, split, walk through). 9 new poses for the clashes and 9 for the answers. Legal screened waves 5 and 6: GO, with its conditions in the rows; Game Design ruled their open numbers (`moveset-rules.md` section 11(h) to (j)).

## Wave 6: the energy family (for Animation and VFX; not for applying)

`wave6-energy.md` and `energy.antihero.wave6.json`: 7 emission shapes with range and travel, 6 hands, the 13 strikes that also emit, 5 energy poses, and all 31 energy strikes as emitter and shape. 7 new body poses. Every range band keeps at least 8 lights and 4 heavies, with a broken limb too.

## The Anti-hero's rich M0 piece list (not for applying)

`moveset.antihero.m0.json` is the piece list behind `../m0-rich.md`: 38 key strikes with limb tags, the energy shapes and emitters, 15 entries, 6 feints, the 16-piece grab family, 4 taunts, the set pieces' ticks, 3 finisher shapes, and the lists of 8 specials, 8 signatures and 16 showcases. It has no schema and no loader. It becomes `data/fighters/<id>/moveset.json` at M0, when Tools writes the `combat-moveset` schema and Encounter's composer reads it. The counts in `../m0-rich.md` section 2 are computed from it.
- If the 2b files change before they are applied, rebuild these two from them.
