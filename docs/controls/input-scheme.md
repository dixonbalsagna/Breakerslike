# Input scheme (ADR 0008): actions, layouts, tap and hold rules, keyboard, touch, intent

Owner: Controls and Game Feel. Date: 2026-09-30. Status: **spec, no sim edits; work is on hold until Orb gives the go** (ADR 0008). Sources: `docs/decisions/0008-control-scheme.md`, `docs/ep/vision.md` questionnaire 8, the EP's brief. Data model and schemas for Tools are in [input-schema.md](input-schema.md).

**What this replaces.** The 1 to 4 stance keys, the stance cycle, the sticky light/heavy weight and the one-shot signature queue (`stage-c-spec.md`), the special/transform slot design of `input-map.md` §4, and Stage A's `SimIntent` additions. **What stands:** the hit-stop table and its integer-tick counter (`rulings.md` §5), the shake pass, the latency budget, stick quantisation, device layers and rebinding (`platform-plan.md`), diagonal normalisation (Stage B), the Encore as a transform-chord prompt.

## 1. The actions (the same in every layout)

A layout only decides **which control produces which action**. Every layout produces the same intent (section 8). Terms follow ADR 0008; stance names are Press, Guard, Dodge, Escape.

| Action | Kind | What it does |
| :--- | :--- | :--- |
| `move` | axis | fly; the direction held relative to the opponent (toward, neutral, away) picks the entry: rush, stand, retreat |
| `light`, `heavy` | press | one exchange request each; repeated presses queue a short combo (section 4.5) |
| `signature` | press | the signature request (45 ki), as an exchange request |
| `guard` | hold, plus a tap | holding is the Guard state; a **fresh press** inside a visible wind-up is a perfect block; a mistimed tap still blocks |
| `dodge` | press, plus a hold | the press is a dodge (cancels anything mid-exchange for an energy cost and a cooldown; a free lunge outside one); **holding** it is sprint, and sprinting away is Escape |
| `burst` | tap | the 360-degree energy burst, everyone's answer to pressure, with an energy cost and a cooldown |
| `power` | hold | channel or charge; **while it is held, a face button fires a special or the signature** |
| `special1..3`, `special_auto` | press in the power layer | one of the 3 loadout specials; `special_auto` lets the director pick (Simple) |
| `mode` | tap | toggles physical and energy, which swaps the piece family |
| `context` | press | grab and throw, pick up, the fighter's civilian action, else provoke or feint (physical) or energy shove (energy). While guarding: reversal close up, deflect at range. While sprinting: tackle. In the air: dive grab |
| `transform` | hold 0.5 s | when a transformation is available; also the Encore call (18 ticks) |
| `pause` | system | |

**Held states drive the director.** Press (the default), Guard (`guard` held), Dodge (a `dodge` tap) and Escape (`dodge` held and moving away) are read **at exchange start**, as the stance was. Mid-exchange, only `dodge`, the perfect block, `burst` and the reversal act, at defined windows (Encounter and Combat define the windows; I define the input rules). This also removes the old exploit of flicking stance after the template is fixed.

## 2. The three controller layouts

Godot's `JOY_BUTTON_A/B/X/Y` are positional (south, east, west, north), so the layouts are by position and identical on every pad family. Triggers are digital (on at 0.35, off at 0.25).

### 2.1 Arena (the default)

| Control | Action |
| :--- | :--- |
| Left stick | `move` |
| **LT** | `dodge` (tap) / sprint (hold) |
| **LB** | `guard` (hold) / perfect block (tap) |
| **RB** | `mode` (tap) |
| **RT** | `burst` (tap) / `power` (hold) |
| **X** | `light` |
| **Y** | `heavy` |
| **B** | `signature` |
| **A** | `context` |
| RT held + **X, Y, A** | `special1`, `special2`, `special3` |
| RT held + **B** | `signature` (the power layer is complete: three specials and the signature) |
| **LT + RT** held 0.5 s | `transform` (only counts when a transformation is available) |
| L3 + R3 held 0.5 s | `transform` (alternative on every pad layout) |
| Start | pause |
| View (back) | toggle on-screen hints |
| D-pad, right stick | unused in play (reserved for hints and emotes; the right stick for the free camera in replays) |

### 2.2 Brawler (attacks on the shoulders)

| Control | Action |
| :--- | :--- |
| Left stick | `move` |
| **LT** | `dodge` / sprint |
| **LB** | `guard` / perfect block |
| **RB** | `light` |
| **RT** | `heavy` |
| **X** | `mode` |
| **Y** | `power` (hold) / `burst` (tap) |
| **B** | `signature` |
| **A** | `context` |
| Y held + **RB, RT, X** | `special1`, `special2`, `special3` |
| Y held + **B** | `signature` |
| L3 + R3 held 0.5 s | `transform` |

Why: fighting-game players expect attacks on the shoulders and the thumb free for the face buttons. The shoulders now carry attacks and not charge, so power moves to Y.

### 2.3 Simple (six buttons)

For players who want strategy and spectacle. The director picks the mode and the bursts; the player picks when to attack, defend, charge and cast.

| Control | Action |
| :--- | :--- |
| Left stick | `move` |
| **X** | **Attack:** tap `light`, hold `heavy` (the hold upgrades an unconsumed light; section 4.4) |
| **Y** | `signature` |
| **B** | `guard` (hold) / perfect block (tap) |
| **A** | `dodge` (tap) / sprint (hold) |
| **RT** | `power`: hold to charge; no burst (the director bursts) |
| **LB** | `context` (shown only when it applies) |
| RT held + **X** | `special_auto`: the director picks which loadout special |
| RT held + **Y** | `signature` |
| **RB** held 0.5 s | `transform` (when available) |

That is six action buttons plus the stick. **Match setup flags for the slot** (recorded in the replay header, so ranked can separate assisted players later): `autoMode`, `autoBurst`, `specialPick: "auto"`.

### 2.4 Parity of capability

| | Arena | Brawler | Simple |
| :--- | :---: | :---: | :---: |
| Every action reachable | yes | yes | all but `mode`, `burst`, a chosen `special1..3` (the director picks) |
| Two buttons never needed together except the power layer and the transform chord | yes | yes | yes |
| Remappable per action | yes | yes | yes |

## 3. Tap and hold rules (no latency on taps)

**Rule 1: the tap fires on press.** Nothing is delayed to see whether a press becomes a hold. The hold adds behaviour on top.

**Rule 2: an action is designed so its press is harmless to a hold-minded player.**

| Control | On press (tick 0, no delay) | If still held at tick 12 (0.2 s) | On release |
| :--- | :--- | :--- | :--- |
| `dodge` | the dodge, or the free lunge outside an exchange. The energy cost is paid **only when it affects an exchange** (cancel or avoid); a plain lunge into a sprint is free (Game Design confirms) | **sprint** begins, in the stick direction; away from the opponent reads as Escape | sprint ends |
| `guard` | the Guard state starts at once. A **fresh press** is evaluated for a perfect block on this tick | nothing more: the hold is the state | Guard ends |
| `power` | **inside an exchange as the defender (threatened): the burst fires now.** Otherwise nothing yet | **channel** begins (charging state, exposed as today) | a tap (released before tick 12) while **not threatened** fires the burst **on release**. A hold ends the channel |
| face button with `power` held | the special (or signature) fires now, and voids the pending burst-on-release | | |
| `light`, `heavy`, `signature`, `context`, `mode` | the request or action, now | | |
| `light` on touch or Simple (`X` / Attack) | the light request, now | upgrade to heavy (4.4) | |
| `transform` chord | the first trigger's own press action as above | the count runs from when **both** are down and a transformation is **available**; at 30 ticks the transformation starts | releasing early resets the count to 0 |

**Why the burst has one exception.** A burst costs energy, and a player who wants to channel would burst every time if it always fired on press. The only moment the burst must not wait is under pressure, so there it fires on press; elsewhere a tap fires it on release (at most 11 ticks later, 183 ms, and inside a tap the player controls). If you can think of a rule that is simpler and keeps both, tell me. This is the one place the "no latency" rule cannot hold in full, and it is flagged to Orb.

**Rule 3: the transform chord only counts when a transformation is available.** If not, `LT + RT` simply does both (sprint and channel). The prompt appears when it is available, with a hold ring; the count runs only then. Holding `power` and `dodge` is therefore never a hidden transform.

**Rule 4: the power layer is entered when `power` goes down.** A face press at any time while it is down is a special, with no 12-tick wait. Releasing power ends the layer.

## 4. Timing windows and input rules (ticks at 60 Hz, data values)

### 4.1 Perfect block
- **Window:** the last **8 ticks** (133 ms) of a light wind-up, the last **10** (167 ms) of a heavy one. The wind-up is Combat's visible tell (15 and 20 ticks); the perfect window sits at its end. It opens only while the tell is visible.
- **Needs a fresh `guardPress`.** A hold that is already down is an ordinary block (the player can release and re-tap).
- **Mistimed tap still blocks** (ADR): outside the window a press raises Guard as normal.
- **Buffer:** a press up to **4 ticks before** the window opens counts.
- **Anti-mash:** after any `guardPress`, another press within **18 ticks** cannot be perfect (it still blocks). Mashing beats nothing; a read beats a mash (Orb: experts beat mashers).
- **No late grace**: a press after the contact tick cannot cancel it (contact frames are fixed). The tick of contact itself counts, because `control()` runs before the director in a tick.
- Assist (accessibility): window ×2 and the anti-mash lockout off.
- Reward, costs and cooldown: Game Design.

### 4.2 Dodge
- Accepted any time. Inside an exchange it must fall in the cancel window Encounter defines; buffer **4 ticks** before the window opens; no buffer after. Direction is the stick at the press tick.
- Cost and cooldown: Game Design. During the cooldown a press is acknowledged with a "cooling" mark (no cost).

### 4.3 Burst
- Fires per section 3. Cooldown and cost: Game Design. Acknowledged on the same tick.

### 4.4 Upgrade (hold adds on top of a tap)
`light` is requested on press. If the same button is **still down at tick 12** (touch and Simple Attack), the host sends `upgrade = 1` (heavy). If the swipe-up gesture completes within 24 ticks, it sends `upgrade = 2` (signature). Rule: an `upgrade` **replaces the most recent attack request from this button if the director has not started it** (within 24 ticks); otherwise it is queued as a new request. The player never gets a light followed by an accidental heavy.

### 4.5 Attack requests and the combo queue
- Every `light`, `heavy` or `signature` press is an exchange request; the director decides when it fires.
- **Repeated presses queue a short combo:** the queue holds up to **3** requests (data), each expiring **36 ticks** (0.6 s) after the last press. Order is kept (light, light, heavy is a different phrase from light, heavy, heavy). Presses beyond 3 are ignored, with a "queue full" mark and no penalty: **mashing is fine for beginners**.
- `signature` needs 45 ki when the director fires it; unfunded, it waits in the queue up to **600 ticks** and shows NEED 45 CHARGE (Game Design's confirmation, kept).
- Clearing: KO, being launched by a decisive exchange, and a `guard`/`dodge` that cancels the exchange.
- Heavy under 4 ki falls back to light for that request, with a mark.

### 4.6 Context
- An edge. Priority and modifiers are the sim's (section 1). **Extra presses during recovery are ignored** (no buffer). The sim emits an availability event with the kind (grab, pick up, civilian, provoke, shove, reversal, deflect, tackle, dive) for the on-screen icon.

### 4.7 Mode
- A tap. The state flips at once; the **running exchange keeps its piece family** (the family is read at exchange start). A toggle cooldown of **12 ticks** stops flicking (data). In Simple it does not exist; the director picks.

### 4.8 Same-tick priority
When several presses share a tick: `transform` chord, then `burst` (when threatened), `dodge`, `guard`, `special`, `signature`, `heavy`, `light`, `context`, `mode`. Defence beats offence, because a missed block costs more than a missed attack.

### 4.9 Carried over unchanged
- Presses during a hit-stop freeze are kept and stamped on the first live tick; the input stage runs during a freeze (`rulings.md` §5.1).
- During an opponent's respected cinematic: `power` and `special` stay live; movement, dash and attacks are ignored and not buffered.
- Latency budget: press to first visible reaction at most 3 ticks; every press gets a `press_ack` within 2 ticks.

## 5. Keyboard

Bindings are physical keycodes. **System keys, reserved and never bound:** `N` new match, `T`, `Y` toggle AI, `P` pause, `Esc`, `F1` to `F12`.

### 5.1 Solo keyboard (the default for one human)
Two hands: the left on movement and defence, the right on attacks.

| Action | Key |
| :--- | :--- |
| `move` | `W` `A` `S` `D` |
| `dodge` / sprint | `Space` |
| `guard` / perfect block | `Shift` |
| `mode` | `Q` |
| `power` / `burst` | `E` |
| `light`, `heavy`, `signature`, `context` | `J`, `K`, `L`, `I` |
| `special1`, `special2`, `special3` | `E` held + `J`, `K`, `I` |
| `transform` | `Space` + `E` held 0.5 s (and an optional dedicated key, default `R`) |
| `signature` with power | `E` held + `L` |

### 5.2 Shared keyboard, two players (compact)
Each player has **one hand**, so the sets are compact and the layout is a fallback: **the recommended local pairing is one keyboard plus one pad, or two pads, or the Simple layouts.** Orb decides whether to design anything beyond this.

| Action | P1 (left hand) | P2 (right hand) |
| :--- | :--- | :--- |
| `move` | `W` `A` `S` `D` | `I` `J` `K` `L` |
| `light` | `F` | `H` |
| `heavy` | `G` | `M` |
| `signature` | `R` | `U` |
| `context` | `V` | `Comma` |
| `mode` | `E` | `O` |
| `dodge` / sprint | `Space` | `Period` |
| `guard` / perfect block | `Shift` | `Semicolon` |
| `power` / `burst` | `Q` | `Slash` |
| `special1..3` | `Q` held + `F`, `G`, `V` | `Slash` held + `H`, `M`, `Comma` |
| `transform` | `Space` + `Q` held 0.5 s | `Period` + `Slash` held 0.5 s |

Notes:
- The prototype's old P2 keys (arrows, Enter, `,` `.` `/` `;`, `7` to `0`) are retired. A legacy preset keeps arrows for move if wanted (data: `kb-p2-arrows`).
- `Space` is P1's alone. `Shift` is read as one key (Rendering's `RenderKeys` maps both Shift keys to "Shift"), so P2 must not use Shift.
- `Quote`, `BracketLeft`, `Backquote`, `Minus` are no longer needed. `Comma`, `Period`, `Slash`, `Semicolon` are already named in `RenderKeys`.
- A hot-seat ergonomics test is part of the plan (section 9).

## 6. Touch

Landscape is the phone default; portrait is a fallback with the HUD's touch reserve. The stance ring that UI built for touch is **replaced by a mode chip** (UI to update); the pause button stays.

### 6.1 Simple touch (top priority for the next build)

Two thumbs only. Slot flags: `autoMode`, `autoBurst`, `specialPick: "auto"`.

| Control | Region (landscape) | Gestures |
| :--- | :--- | :--- |
| **Move stick** | floating: appears where the left thumb lands in the **left 42% of the width**, lower 70% of the height. Base radius 56 dp | drag = `move`. **Flick** (from the centre to 70% in at most 4 ticks) = `dodge` in that direction. **Hold beyond the outer ring** (1.3 × radius) for 6 ticks, or hold at full deflection for 30 ticks (setting), = sprint |
| **Attack** | the right thumb's rest point, diameter 88 dp | tap = `light` on press. Hold to tick 12 = `upgrade 1` (heavy). **Swipe up** (at least 48 px up, within 24 ticks) = `upgrade 2` (signature) |
| **Guard** | left of Attack, 72 dp | hold = `guard`; a timed tap = a perfect block |
| **Power** | above Attack, 72 dp | hold = `power` (charge); tap = nothing (the director bursts). **While Power is held, Attack tap = `special_auto`** and Attack swipe up = `signature` |
| **Context** | up-left of Attack, 64 dp, **fades in only when relevant** (the sim's availability event), with the action icon | tap |
| **Transform** | appears where Context sits, with a hold ring, only when a transformation or the Encore is available | hold 30 ticks (Encore 18) |
| Pause | top corner, UI's | tap |

**Layout anchors (dp, from the bottom-right safe corner, mirrored for left-handed):** Attack (−100, −100); Guard (−204, −78); Power (−108, −204); Context and Transform (−204, −178). Minimum hit radius = visual radius + 8 dp, never under 48 dp. The finished layout is UI's, hit-tested with `UiHud.touch_target_at`; I own the gesture rules, UI owns the pixels.

**Gesture arbitration:**
- A touch belongs to the first control it lands on and never moves between controls.
- The move stick claims the left zone only; a second touch on the right is independent. At least **4 simultaneous touches** (stick, Attack, Guard or Power, Context).
- A touch that starts within 8 dp of a screen edge is ignored (palm).
- A swipe-up on Attack that is 48 px up but longer than 24 ticks is a hold (heavy), not a signature.
- Haptics (Android Vibration API): 8 ms on a perfect-block window, 15 ms on a burst-ready. None on iOS Safari. Never the only cue.
- Touch latency budget: 150 ms button to photon; the perfect-block buffer gains **+2 ticks** on touch (6).

**Why this fits the playtest:** the actions friends found missing (manual block, dodge, cancel) are each one touch: Guard and Power are held by the right thumb's neighbours, the dodge is a flick on the stick, and the left thumb never leaves the stick. The right thumb only moves between four nearby buttons.

### 6.2 Full touch preset (tablets)
All Arena actions, with dedicated buttons in place of the shoulders:

| Control | Action |
| :--- | :--- |
| Floating move stick (left zone) | `move`; flick = `dodge`; outer-ring hold = sprint |
| Left edge, stacked above the stick: **Dodge** (tap / hold sprint) and **Guard** (hold / tap) | `dodge`, `guard` |
| Right edge, above the diamond: **Mode** and **Power** (hold) / burst (tap) | `mode`, `power` / `burst` |
| Right diamond: **Light**, **Heavy**, **Signature**, **Context** | `light`, `heavy`, `signature`, `context` |
| Power held + diamond | `special1`, `special2`, `special3` (West, North, South), `signature` (East) |
| A **Transform** button, shown when available | `transform` |

Needs at least 5 simultaneous touches. A layout editor lets the player move and resize buttons; the preset is a starting point.

## 7. Onboarding hints (Orb: on-screen control hints)

Hints are contextual and fade after the player has done the action three times: "Hold to guard" the first time an attack comes in, "Tap just before the hit" at the perfect-block window, "Flick to dodge", "Hold to sprint", "Hold Power, then Attack for a special". A hint toggle (View on a pad, `H` on a keyboard, a corner button on touch) shows or hides them. Content is UI's and Narrative's; the triggers are the sim's availability and press-ack events.

## 8. The intent record (for Simulation's `SimIntent`)

Replaces the eight-field intent. Types are `int`, `bool` or a float that is a multiple of 1/16, so every value is exact in float64. The host builds one per slot per tick; it is the only thing a replay or a network peer carries. The sim counts holds and decides tap versus hold from the `*Press` edges and the held bools.

| Field | Type | Meaning |
| :--- | :--- | :--- |
| `mx`, `my` | float, −1 to 1, step 1/16 | move, after deadzone and gate (stick) or ±1 (keys) |
| `light`, `heavy`, `sig` | bool edge | attack requests |
| `upgrade` | int edge, 0, 1 or 2 | 1 = heavy, 2 = signature, replacing an unconsumed request (4.4) |
| `guard` | bool held | |
| `guardPress` | bool edge | a fresh press this tick (even if released again within the tick) |
| `dodge` | bool held | |
| `dodgePress` | bool edge | |
| `power` | bool held | |
| `powerPress` | bool edge | |
| `special` | int edge, 0 to 4 | 1 to 3 = `special1..3`; 4 = `special_auto`; set only while `power` is held |
| `context` | bool edge | |
| `mode` | bool edge | |
| `transform` | bool held | the layout's chord; the sim counts the 30 ticks, and only when available |

Removed: `stance`, `dash`, `charge`, and Stage A's `special`, `transform` (as slots), `stanceStep`.

**Host guarantees:** a press shorter than one tick is stretched to one tick of held with its edge; a release then re-press between two ticks yields one edge. When `special` is set, `light`, `heavy`, `context` and `sig` for that same press are cleared (the layer swallows the face press). Layouts decide the mapping; the sim never sees a device.

**Match-setup flags per slot (replay header):** `autoMode`, `autoBurst`, `specialPick` ("chosen" or "auto"), and the accessibility assists (`perfectBlockAssist`, `holdToggle` is host-only). They do not change what a press means; they let the sim act where the input is absent.

**Suggested state derivation for Encounter (their call):** `guard` held at exchange start reads Guard (DEFENSIVE); `dodge` held 12 ticks or more while moving away reads Escape; a `dodge` tap in the last 12 ticks reads Dodge (EVASIVE); `power` held 12 ticks or more reads charging (exposed, CHARGE INTERRUPT); otherwise Press (AGGRESSIVE). Held states are sampled once, at exchange start.

**Hashes and replays:** the intent field lists in `hash.gd`, `golden_recipes.gd` and `replay.gd` change with this record, so the replay `v` bumps. That is a golden regeneration, and so a Stage C-type commit (section 9).

## 9. Stage plan, revised

| Stage | Content | Behaviour | When |
| :--- | :--- | :--- | :--- |
| **A** | Integer hit-stop counter with the shadow float; **no** intent changes (the new fields are added when the director reads them) | bit-identical goldens (`stage-a-proof.md`, its A7 now covers the new fields as inert) | still after D1a; unchanged |
| **B** | Hit-stop values, shake decay hold, diagonal normalisation | goldens regenerate | unchanged |
| **C** | `SimIntent` v2, the host's layout layer, tap/hold rules, perfect block, dodge cancel, burst, power layer, combo queue, context availability | behaviour change; needs Encounter's defender-state reads and Combat's energy-mode families | after Orb's go and Encounter's revision of the Q4 plan |
| **Touch first** | Simple touch and the host's touch layer can land **before** Stage C by mapping to today's intent (attack = `light`/`heavy`/`sig`, guard and dodge as today's DEFENSIVE and EVASIVE held stances, power as charge) | a bridge so the friends' main blocker is fixed first | Orb's go; to be agreed with Encounter and Rendering |

## 10. Tests and risks

| # | Test | Pass |
| :-: | :--- | :--- |
| T1 | **Tap latency:** for dodge, guard, light, heavy, signature, context, mode, special, and burst under threat, the sim reaction is on the **same tick** as the press | 0 ticks |
| T2 | **Burst exception:** unthreatened tap fires on release at most 11 ticks after the press; a hold of 12 ticks or more never bursts | scripted |
| T3 | **Power layer:** a face press 1 tick after `powerPress` fires the special and no burst follows the release | scripted |
| T4 | **Perfect block:** a fresh press on each tick of a 15-tick wind-up | perfect only in the last 8 (10 for heavy); the press at tick 6 is blocked normally; a second press within 18 ticks never perfect |
| T5 | **Mash resistance:** a bot pressing guard every 4 ticks | perfect rate at most one per 18 ticks; a rhythm bot beats it |
| T6 | **Upgrade:** a light, then `upgrade 1` at tick 12 with the request unconsumed | one heavy request, no light; if the light was consumed, light then heavy |
| T7 | **Combo queue:** 6 presses in 20 ticks | 3 queued, 3 ignored, order kept, no penalty |
| T8 | **Transform chord:** `dodge` and `power` held 40 ticks with no transformation available | sprint and channel, no transform; available: transform at 30 ticks; release at 29 resets |
| T9 | **Held state sampling:** change guard to dodge after the exchange starts | the running exchange keeps its read; only `dodge`/burst act in their windows |
| T10 | **Device parity:** the same scripted fight through keyboard, Arena, Brawler and touch Simple events | identical `SimIntent` streams for equivalent actions |
| T11 | **Touch arbitration:** swipe at 47 px and 49 px; a swipe slower than 24 ticks; flick at 3, 4 and 5 ticks; palm touch at 6 dp from an edge | as specified |
| T12 | **Hot-seat:** two humans play a minute on the shared keyboard | no ghosting on the chords (Space + Q, Period + Slash) on three keyboards; otherwise move them |
| T13 | **Replay:** a mixed-device match replays from the intent log | hash equal |

| Risk | Mitigation |
| :--- | :--- |
| Keyboard ghosting on chords | test on cheap keyboards (T12); alternative single-key transform |
| The perfect block is too hard or too easy | widths are data; QA's bot and a human test; assist ×2 |
| Simple touch feels like it plays itself | the player owns attack, guard, dodge, power, context and when to cast; the director owns only mode, burst and which special |
| Burst-on-release feels like latency | it applies only unthreatened, and a tap is at most 183 ms; the alternative is a dedicated burst button (Full touch and a rebind option) |
| The mode chip and context icon clutter a phone screen | UI's caps; context fades in only when relevant |
| Online fairness: Simple's auto picks vs manual | flags in the replay header; ranked separation later (ADR 0008) |

## 11. Needs

- **Orb (through the EP):** the burst exception (section 3); whether a two-hand shared keyboard layout is worth designing; handedness defaults; the go.
- **Game Design:** costs and cooldowns for dodge, burst, perfect block reward and cancel; whether a lunge outside an exchange is free; what `special_auto` picks.
- **Encounter:** defender states read at exchange start, the dodge cancel window, the burst window, the combo queue consumption, the context priorities; the AI's use of the new inputs.
- **Combat:** energy-mode piece families, the context actions, wind-up tells that match the 15/20-tick lengths, availability kinds.
- **Simulation:** `SimIntent` v2 (section 8), hash and replay lists, the `press_ack` and `availability` events.
- **UI:** the mode chip, the context icon and hold rings, the touch layout in section 6 (replacing the stance ring), glyph updates (stance glyphs retire), the hints.
- **Rendering:** the host layout layer, the touch layer, `RenderKeys` unchanged for the new keys.
- **Tools:** the schemas in `input-schema.md`.
- **QA:** the tests in section 10.
