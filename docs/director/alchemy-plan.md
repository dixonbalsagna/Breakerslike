# The combat alchemy layer: the director's slice plan

Owner: Encounter Systems Director. Date: 2026-10-02. Status: a plan, nothing built. Scope: the third part of Orb's next big update, "the framework for the combat alchemy layer tied into the fight choreographer" (`docs/ep/vision.md`, last section).

Sources: `docs/design/agency-pass.md` §2 (the frame, the three styles, timing, flow, the running mix, both fighters attacking, Blow for Blow) and §12 to §16; Combat's `docs/combat/alchemist-recipes.md` and its parked `docs/combat/pending/recipes.alchemist.json`; Controls' `sim/input/press_read.gd` and `docs/controls/agency-input.md` (R3, 1a); `docs/design/rule-of-cool.md` §2 (clashes on the pulse).

## What exists today

| Piece | State |
| :--- | :--- |
| **The press log** (`sim/director/alchemy.gd`) | Built. A ring of each fighter's last 20 presses (weight, family, direction, tilt, a rhythm tag), the window of five with a 90-tick life. Its rhythm tags (held, mashed, timed) are the director's own simple reads, not Controls' classifier |
| **The flow count** | Built as a count (+1 for a timed press, up to 5; it lapses after 90 ticks), sent as the `flow` event. Nothing in play reads it yet |
| **Endings** | Built: the earned launch (§3, four rules), the blur's own ender after four landed strikes (§13), the plain blur's ender as half a set-up (§14.4), the barrage's ender (§16) |
| **Controls' classifier** (`SimPressRead`) | Built and tested, not wired. Pure functions over a five-entry log: hold, rhythm, mash or taps; perfect, good or off; the steady mash; the release grade on the flash; the short and long mix |
| **Combat's recipes** | Parked draft (`recipes.alchemist.json`): the three styles with their strike pools (base and timed), the flow's pieces, the direction pools, six blur patterns, the last-press endings. Not loaded |
| **Clashes on the pulse** | Not built. Today's heavy clash and beam clash are decided by a draw. Combat's wave 5 clashes are parked (Legal GO, RL-050) |

**The mashed blur keeps its weak ender** (§13, §14.4, confirmed in §18): after four landed lights, 0.6 of the knock-back distance and half a set-up. The perfect blur closes with a full set-up. §2's "no ender" was written before §13.

**A player who never times still launches** (§18): with a held heavy, a lone heavy with the stick, and a won clash. Timing adds launches at the end of his strings, the showcase ender and each style's upgrade.

## The slices

| Slice | What the director does | Size | Needs |
| :--- | :--- | :--- | :--- |
| **A1. One log, read by Controls' classifier** | The director builds the log `SimPressRead` reads. Each press carries its beat (the distance in ticks to the nearest blow contact of the running exchange, which the director knows from its strike beats), its release tick and the charge's flash tick. The director's own rhythm tags give way to the classifier's style, grade, streak, steady flag and release grade. A `press_read` event per press for QA and the HUD's recipe strip. No change in play | Medium (about 150 lines) | **Controls:** confirm the beat definition and the log fields; its `intent-hash.patch` (the held levels in the state hash) lands with this slice. **Simulation:** grant that patch in `sim/core/hash.gd`, with the goldens. **Tools:** the event's row |
| **A2. The style picks the string** | The heavies in the last five pick blur, combo or power. The last press picks the ending: a light stays a brawl; a heavy is a knock-back, or a launch when one is earned. The stick picks the pool (toward: the close strikes; level; away: a retreat, a knock-off heavy, blasts). The planner composes a phrase at a time from the recipe table and re-reads the window at each link. The recipe is a mapping, not a draw | Large (about 350 lines: the phrase planner in `alchemy.gd`, hooks in `data.gd` and the exchange's links) | **Combat:** `recipes.json` moved from pending to `data/combat/` with its schema version, and a list of which pool pieces are live today. **Tools:** its schema and loader fixtures. **QA:** style counts per match |
| **A3. Timing upgrades each style** | Blur: a steady mash (gaps within 3 ticks) is the perfect blur, every strike clean, closing with a full set-up; a pattern from the six fixes the limbs and targets. Combo: each tap within 4 ticks of a blow landing does 15% more and lands clean. Power: a hold released within 6 ticks of the flash breaks a guard, and unguarded it earns a launch | Medium (about 150 lines) | **Controls:** nothing new (the classifier gives all three grades). **VFX and Audio:** the flash on the forearm plates and its sound, which the player times against. **Combat:** the perfect blur's patterns and the guard-breaking blow's pieces. **Animation:** the charge pose at close range |
| **A4. Flow earns the string's ending** (§18) | A timed press adds 1 (from A1's grade); an off-beat press or 90 idle ticks resets it. Flow governs one of the four earners, the ender of a string: a heavy that ends a string of two or more landed strikes launches only at flow 3 or more, and below that it is a knock-back. There the stick only aims. At flow 5 it is a showcase ender with the panel and 20% more impact wear. The other three earners stay: a held heavy that lands (a far heavy charge included), a heavy with the stick that lands clean when it is its own exchange (an opener, not inside a string, so tilting can't skip flow), and a won clash (Blow for Blow included). In `DirLaunch.earned` today the string earner needs 4 landed strikes and no flow, and the stick earner counts inside strings too: both change | Small (about 60 lines) | **Combat:** the showcase enders' gates. **QA:** the launch bands (18 to 30% of decided exchanges, 25 to 40% of separating ones), which these two changes move |
| **A5. The running mix** | Over the last 20 presses against the latest five: a change-up's first blow winds up 3 ticks sooner, and each repeat adds 2 ticks up to 6. Today's staleness keys on weight, mode and direction; this moves it onto the classifier's mixes | Small (about 40 lines) | Nothing beyond A1 |
| **A6. When both attack: clashes on the pulse** | The blur exchange (traded strikes on the pulse), the fist clash, the rule that three clean lights stop a power blow, and the cross-counter's double slide. A clash has 3 pulses (24, 48 and 72 ticks; 30, 60 and 90 for the grapple lock and the beam struggle) with an 8-tick window; a press on the pulse is +10, an off-pulse press locks the next out for 20 ticks, and a difference under 10 is a tie. The beam struggle moves onto the same runner | Large (about 250 lines) | **Simulation:** the clash score and the pulse index as state (`S.game.clash`, or the director's integers by grant). **Controls:** clash presses as pulse presses (`tech-and-pulse-input.md`). **Combat:** wave 5's clashes into data. **Camera, VFX, Audio:** the pulse shown and heard. **Tools:** schemas and events |
| **A7. Blow for Blow** | Both release a power blow on the flash in one exchange: they trade heavies in turn, each inside an 8-tick window. The beat is 40 ticks and 4 shorter a turn, never under 24. Each blow is ×0.7 of a heavy, on a different strike and place. The pair travel 40 units on the first turn and 8 more each turn after. The first to miss, guard or dodge gives way to an earned launch with the panel and 25% more wear. At most 8 turns, one per 20 s; mood +8 and +3 a blow | Large (about 250 lines, on A3 and A6) | **Legal:** its twelve staging rules, screened before it is built. **Combat:** §2's pieces and three poses. **Animation:** sockets for the places. **Camera, VFX, World** (the furrow), **Narrative** (the name), **QA** |
| **The AI, in every slice** | Its presses make styles at its level's mix; it times presses, pulses and the flash at its level's rate (40, 65 and 85% for pulses and beats) | Inside each slice | `ai.json` keys per level; **Tools** |

## Controls' note for A1 to A4 (`docs/controls/agency-input.md`)

- **The beat** for a string is the nearest blow contact in the exchange, either fighter's, from the director's strike schedule.
- **A hold** grades against the charge's flash: the director stamps the planned flash tick when the charge begins.
- **Clashes** grade against the pulse and are never pushed into the log.
- **The log** is 20 presses, with a five-press mix and a 90-tick expiry.
- **No intent change** for A1 to A4: `lightHeld`, `heavyHeld`, `escape` and the intent hash are already in.
- **Hit-stop:** `S.tick` runs through hit-stop and only `S.T` stops. A press or a release made in a freeze of h ticks arrives on the first live tick, so A1 grades it at `S.tick - h`. Otherwise timed presses on heavy hits read late.
- **The stick's launch direction** comes from Controls' `SimAim` (`sim/input/aim.gd`): eight sectors with a 12-tick latch, `pool(sector, opp_sign)` for the direction pools and `snap(sector, candidates)` for the launch target. Its latch's two integers live in the director's per-fighter integers, which are hashed.

## A first playable cut

**A1, A2, A4, and A3's blur and combo upgrades.** Presses become ingredients, the three styles play differently, mashing steadily or tapping in time pays, and flow earns the launch at the end of a string. That is the "framework" Orb asked for, and it can be played against the AI.

It leaves out the power blow's flash release (it waits on VFX's and Audio's flash), both fighters attacking on the pulse (A6) and Blow for Blow (A7). Today's draw-decided clashes stay until A6.

Size: about 600 lines in `sim/director/` and a new `data/director/alchemy.json` for the director's numbers (the window, the life, the flow's thresholds, the upgrades' multipliers). In two or three slices, each gated and measured.

## What QA measures

§2's scripted mirrors: a timed player (80% of beats) beats a masher 72 to 82% of the time; a timed player beats a style-only player 62 to 70%; a style-only player beats a masher 55 to 62%. The bands already live stay: the masher against the AI, the lights-only and bolt-only finishes, and the launch, knock-back and stay shares.

## Risks

- **Balance moves with every slice,** as it did through the agency pass: the masher's band against the medium AI and the launch shares will need re-tuning each time.
- **A4 changes two of the four earners** (the string's ender, and the stick inside a string). They were tuned to the launch bands; with the flow gate the shares have to land in them again.
- **One log.** The director's private rhythm tags and Controls' classifier must not both decide: A1 retires the director's.
- **The pulse runner (A6) touches the beam struggle** that slice 8 leaves on a draw.
