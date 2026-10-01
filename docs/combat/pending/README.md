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
