# Agency, slice 10: the alchemy layer's framework (A1 and A2)

Owner: Encounter Systems Director. Date: 2026-10-03. Status: in the tree on HEAD `7f4a12d`, waiting for the EP's commit. Plan: `docs/director/alchemy-plan.md` (A1, A2). Rules: `docs/design/agency-pass.md` §2; Controls' `docs/controls/agency-input.md` (the note for A1 to A4); Combat's `docs/combat/alchemist-recipes.md`.

Everything here runs only in the `dynamic` profile. **It changes nothing in play:** AI matches are the same as on slice 9, tick for tick, and the scripted players' rows are the same. What it adds is the layer the timing rules stand on: the log Controls' classifier reads, the style, and a piece on every planned strike.

## What changed

| Part | Rule | Where |
| :--- | :--- | :--- |
| **One log, read by Controls' classifier** (A1) | Each press is kept with its weight, family, direction and tilt, the tick its button was let go, its beat (the ticks to the nearest blow contact of the running exchange, either fighter's, up to 12 ahead or behind) and its charge's planned flash. `SimPressRead.classify` reads it: hold, rhythm, mash or taps; perfect, good or none; steady; the release grade; the two mixes. The read is recorded with each press | `alchemy.gd` `log`, `_blows`, `logOf`, `read`, `flash` |
| **The freeze rule** | `S.tick` runs through hit-stop. A press or a release that arrives on the first live tick after a freeze of h ticks is graded at `S.tick - h` | `alchemy.gd` `_freeze`, `log`, `_release` |
| **Releases** | A button level that falls closes his newest held press of that weight. A press whose button is not down as a level is a tap, let go at once | `alchemy.gd` `tick`, `_release` |
| **The flash** | A charged shot stamps its planned flash (the full charge) when its charge begins, so a release is graded against it. The melee power blow's flash comes with A3 | `blast.gd` `press`; `alchemy.gd` `flash` |
| **The aim latch** | Controls' `SimAim` latch is fed once a live tick and kept in the fighter's state. Nothing reads it yet (A4's launch direction will) | `alchemy.gd` `tick`, `aim` |
| **The style** (A2) | The heavies among his last five presses still alive: none is blur, one to three combo, four or five power | `recipe.gd` `style` |
| **A piece on every strike** | After each plan (the opener, a link, the blur's own ender), every pending strike is given one piece from Combat's pools: by its fighter's style, the weight of the press behind it, whether he held toward the rival, and whether it is the string's last blow. The pick is a keyed draw on the match seed, the exchange and the press, stepping past his last two picks. `waiting` pieces are skipped; `posed` and `live` are drawn alike. The piece is a name on the beat (`args.piece`); the strike's numbers are still the template's | `recipe.gd` `poolName`, `pick`, `dress`; `exchange.gd` `_start`, `chain`, `_blurEnder` |
| **Combat's recipes are live data** | `data/combat/recipes.json`, from Combat's parked draft without its `_target` line (the EP's grant for that one file). It and the new `data/director/alchemy.json` are in the combat data hash | `recipe.gd`; `data.gd` `_ensure` |

**The rhythm tags and the flow keep today's rules in this slice.** A press is tagged timed when one of his own blows lands within 4 ticks of it, and mashed when it is the third press inside 20 ticks. Controls' read is recorded beside them and takes them over with the timing upgrades (slice 11), where the re-tune belongs. The first build of this slice moved the tags at once and the masher went from 47 to 53 of 100 against the medium AI with nothing else changed.

**Feed lines:** `PRESSES` now names the style and Controls' read; `PIECES` names the pieces picked. **Beats:** `strike` and `chainStrike` carry `args.piece` (`strike.<name>`). No new event, cue or decisive kind. **No core lines.**

**Fighters and pools:** KAI draws on `protagonist` and VORR on `rival` (`alchemy.json` `recipes.fighters`), until the roster ids change.

## Results

**Two scripted humans in the close band** (P1 presses a pattern, P2 does nothing):

| Pattern | Style at the exchanges | Pieces |
| :--- | :--- | :--- |
| Lights every 8 ticks | blur | 9 different pieces of `blur.base`; never the same twice in three |
| The same, the stick toward | blur | The 4 close pieces of `blur.toward` (elbows, knee, shoulder) |
| L L H every 16 ticks | combo once the heavy is in the window | Links from `combo.link`, accents from `combo.accent` |
| Heavies every 30 ticks | combo, never power | Accents; see the second finding below |
| Lights held 14 ticks, every 40 | blur | `blur.base` |

Every planned strike of P1's had a piece.

**Unchanged from slice 9,** measured: 25 AI matches give the same record as on slice 9; the masher against the medium AI wins 47 of 100 with QA's script (47 on slice 9); the bolt-only player against the medium AI 32 of 100 (31 on slice 9).

**QA's harness on slice 9's final build,** which this slice's AI matches equal (four arms, 100 an arm): KAI 48.5% over both slots (45.0% from P1, 52.0% from P2); match median 506 s (band to 480); blasts 12.0% of damage; front-row structures 57.1% (band to 50); 86 bands pass, 20 fail, 22 pending. The masher row in that run read 53 of 100 on this slice's first build, before the tags were put back.

**Gates** on a clean copy of HEAD with exactly the tree's changes (parity again in the tree): goldens regenerated (9 matches, 175,559 ticks, the same count as slice 9's: the state grows and the play does not change); parity, the loader check at 200 matches, `npm test` 5 of 5, determinism, seam, the animation check, the cue check, Controls' input tests and its mash probe (6 of 6) pass. The validator has no errors; it warns that the two new files have no schema until Tools' scripts are applied.

## Two findings for Game Design and Controls

1. **A metronome reads as a steady mash.** Controls' classifier calls a mash steady when its gaps differ by 3 ticks or less, and a steady mash is the timed version of the blur. A script that presses exactly every 8 ticks is perfectly steady, so QA's untimed masher would get the perfect blur. With the tags on the classifier and nothing else changed, a masher on the real clock won 56 of 100 against the medium AI (64 when the mash was read from the gaps alone), and QA's, which presses every 8 live ticks, so its gaps stretch through hit-stop and often read as taps, won 53. Both are 43 and 47 on slice 9. §2 asks for "evenly spaced, within 3 ticks of the beat"; the classifier checks only the spacing. Slice 11 needs one of: the steady mash also has to be on the beat, or QA's masher gets human jitter.
2. **Four heavies do not fit a 90-tick window.** Heavy exchanges start about 47 ticks apart, and each press expires 90 ticks after it was made, so at most three heavies are alive at once and the power style is reached only by a burst of queued presses. If the window instead lapsed 90 ticks after his last press (as the flow does), four heavies in a row would read as power.

## Where the routed asks went

- **In:** posed and live pieces drawn alike, only `waiting` skipped; `args.piece` on strike and chainStrike beats.
- **Not in, and why:** entry beats (the recipes have no entries pool; they come with Combat's brawl and agency data); the far-taunt gesture pick (Animation picks today and holds the gesture lists; the director would need them as data); `taunt_close` (nothing in the sim starts a close taunt).

## Data keys for Tools

| File | Keys |
| :--- | :--- |
| `data/director/alchemy.json` (new, `director.alchemy/1`) | `recipes` {`enabled` (boolean), `fighters` (roster id to a key of the recipes' `pools`), `_note`} |
| `data/combat/recipes.json` (new, Combat's) | Tools' `apply-recipes.cjs` |

## Left for slice 11

- A4: flow gates the string's ender; the stick earner only as its own exchange; the showcase ender at flow 5 (its 20% more impact wear needs a hook in World's journey: there is no wear multiplier on a launch today).
- A3's blur and combo upgrades, with the tags and the flow moved onto Controls' read, and the AI timing its presses at its level's rate.
- The blur patterns need each strike's limb and target as live data; the pools carry only ids and statuses.
