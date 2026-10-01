# Wave 4: the grab and throw family, with the turning throw

Owner: Combat and Choreography. Date: 2026-10-01. Status: parked specs for Animation. Nothing here is loaded or hashed, and no live data changed. The data is `grabs.antihero.wave4.json` in this folder. Plan: `../m0-rich.md` (the grab family is wave 7 in its table; the EP brought it forward). Rules: `docs/design/control-rules.md` sections 4 and 9, `moveset-rules.md` section 11(d), `spec-wounds.md` section 1d.

**What is here.** 16 pieces: 2 grabs, the hold, 7 throws, the tackle (2), the dive grab (2) and the reversal (2). They need 22 new poses, plus 2 for the tail throw, which is held until Orb rules on the tail. The thrown fighter needs none: he is Animation's ragdoll, pinned at the grip.

## 1. The grab in ticks
| Beat | Ticks | What happens |
| :--- | ---: | :--- |
| Reach | 10 | the tell. It lands at the hand's contact distance, 58 u. An attack in progress beats it; a dodge makes it whiff (20 ticks open, a 1.5 s cooldown); it beats Guard, Neutral and Power |
| Hold | 8 | both lock. He pulls the rival in from 58 to 36 u. The held fighter cannot act |
| Throw | the next tick | the direction held picks it. A launch at ×0.8 of a heavy, and a decisive exchange |
| The turn throw | 2 of hold and 8 of turn, then the release | 10 ticks in all, as ruled; no ki |

The outcome against each held state is Game Design's table (`control-rules.md` section 9).

## 2. The grabs and the hold
| Piece | Grip | Ticks | Uses | New poses | Look |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `reach` | one hand to the collar (the chest socket) | reach 10, open on a whiff 20 | 1 arm | the reach: arm at full length, hand open and clawed | A clawed hand shot out flat at the collar, the arm one line with the back leg; the other hand open at his ribs. **Legal:** the grip is on the collar or an arm: never the throat, the face or the hair. |
| `lunge` | one hand to the collar | reach 10, open on a whiff 20, inside the last 10 ticks of the rush | 1 arm | the lunge: the reach laid out behind a rush | The same reach on the end of a rush, his whole body a line behind the hand. |
| `hold` | the gripping hand pulls in; the forearm guard lies across the collar | hold 8, pulls in from 58 to 36 u | 1 arm | the hold: the rival pulled in chest to shoulder | He pulls the rival in against his shoulder, forearm guard across the collar, his head beside theirs. **Legal:** no lift by the throat or the face, and no rival held up at arm's length. |

## 3. The seven throws
The direction held picks the throw. Toward and neutral each have a two-arm and a one-arm throw; away has the back throw and the turn throw; the tail throw serves any direction.

| Piece | Grip | Ticks | Uses | Sends the rival | Sides after | New poses | Look |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `hurl` (toward) | both hands: collar and hip | release 1, follow 6, recover 10 | 2 arms; grounded: both legs | across: the planner's long-haul candidates, brunt targets ahead included | same | load: his back turned into the rival, hips under theirs; release: both arms thrown out in one line | He turns his back into the rival and throws them past his hip, both arms ending in one long line after them. **Legal:** half a turn at most before the release. |
| `sling` (toward) | one hand on the collar | release 1, follow 6, recover 10 | 1 arm | across, lower and shorter than the hurl | same | load: the arm bent, the rival swung to his side; release: the arm straight, at full reach | A half turn of the shoulders and the arm straightens like a thrown blade, letting go at full reach. **Legal:** half a turn at most: never a swing of several turns, and never by the legs or a tail. |
| `drive_down` (neutral) | both forearm guards under the rival | release 1, follow 6, recover 12 | 2 arms; grounded: both legs | the drive: down and forward, 25 to 50 degrees below level (launch-vectors.md) | same | load: the rival lifted to shoulder height on both guards; release: driven down ahead of him, his weight following | He lifts the rival on both forearm guards and drives them down ahead of him, falling in behind them. **Legal:** no press held overhead, and no rival broken across a knee or the shoulders. |
| `spike` (neutral) | one hand on the collar | release 1, follow 6, recover 12 | 1 arm | the drive; the straight crater slam only under its gates | same | load: risen a body length, the rival hanging from the grip; release: the arm whipped down past his own knee | He rises a body length with them and throws them down past his own knee. |
| `back_throw` (away) | both arms round the middle (the gut socket) | release 1, follow 6, recover 12 | 2 arms; grounded: both legs | across, behind him: over his shoulder, never through him | swapped | load: dropped under the rival's arm, arms locked round their middle; release: arched back, the rival leaving over his shoulder | He drops under the rival's arm, locks both arms round their middle and arches back so they go over his shoulder and behind him. **Legal:** the rival is let go in the air: no drop held to the ground. |
| `turn_throw` (away) | one hand on the collar | hold 2, turn 8, release 1, follow 6, recover 10 | 1 arm; grounded: both legs | the planner's vector at the target behind him; from a grab, across behind him | swapped | the turn: mid-pivot, the rival carried at a bent arm on his outside; release: his back to where he first faced, the arm thrown out | He pivots half a turn on the spot with the rival carried round him at a bent arm, and lets go with his back to where he first faced. **Legal:** one half turn: the body goes round him, never through him and never further. |
| `tail_throw` (any) (held: the tail) | the tail round the middle | release 1, follow 6, recover 10 | own limb | any direction held | same | load: the tail coiled, his hands open at his sides; release: the tail snapped straight | The tail coils the rival's middle and whips them away while his open hands never leave his sides. **Legal:** a hair, cloth or metal tail, never a furred or reptilian one; no more than half a turn. |

- **"Swapped"** means the pair changes sides: the body goes over his shoulder or round him, never through him. These are the two authored cross-overs in the family, so their beats carry `"side": "cross"` and their branches end `swapped`.
- **Away: which one.** The back throw when nothing stands behind him. The turn throw when a brunt target does, or when he has one arm.

## 4. The turning throw, as ruled
One piece, two uses.
- **From a grab:** the away throw above.
- **From the director** (`moveset-rules.md` section 11(d)): after a heavy, an ender, a guard break or a finisher strike, when a brunt target is behind him and scores above every target in front after the turn's penalty. The body must be held, not flying, so it is never a ping-pong's return blow or ender. The held fighter cannot act for the 10 ticks. It costs no ki.
- **What it looks like in both:** he catches at the collar, pivots half a turn with the body carried round him at a bent arm, and lets go with his back to where he first faced.

## 5. The tackle, the dive grab and the reversal
| Piece | Grip | Ticks | Uses | Sends the rival | Sides after | New poses | Look |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `tackle_hit` | a shoulder to the middle, one arm hooked behind the back | reach 12, recover on a whiff 30 | 1 arm; grounded: both legs | none | same | the hit: shoulder in, body flat, one arm round | At full sprint: the plated shoulder into the middle, one arm hooked behind the rival's back. |
| `tackle_carry` | the same hold | carry 30 to 60, recover 12 | 1 arm; grounded: both legs | released along the ground: a slide, or a brunt if something stands in the way | same | the carry: the rival folded over his shoulder, his body low and driving | He keeps driving: the rival folded over his shoulder, the ground tearing under their back, until he lets them go into whatever is ahead. |
| `dive_catch` | one hand to the collar from above | reach 10, recover on a whiff 30 | 1 arm; air only | none | same | the catch: head first from above, one arm reaching down | Head first from above, one arm reaching down to take the collar. |
| `dive_spike` | the same grip | release 1, follow 6, recover 12 | 1 arm; air only | straight down when the rival is directly below (the crater slam's gate); otherwise the drive | same | release: thrown down the last body length as he pulls up | He keeps falling with them and throws them down the last body length, pulling up himself. |
| `reversal_throw` | the hand that blocked catches the arm (the chest socket until an arm socket exists) | turn 8, release 1, follow 6, recover 10 | 1 arm | across and low: a skid | same | the catch: the blocked arm taken at the guard; release: his hip under the arm, the rival going over | He takes the blocked arm, turns his hip under it and lets the rival's own push carry them over. |
| `reversal_sweep` | a leg hooked behind the rival's lead leg (the legs socket) | turn 8, follow 4, recover 10 | 1 leg; grounded: both legs | none: the rival goes down where he stands | same | the sweep: guard still up on the good arm, one leg hooking low | The guard stays up on the good arm while a low hook of the leg takes the rival's feet. |

## 6. The broken-limb filter
Two-arm throws are dropped with a broken arm, and the throw does ×0.8. With a broken leg on the ground, throws that need both legs are dropped. If no throw is left for the direction held, the neutral throw plays.

| | Toward | Neutral | Away |
| :--- | :--- | :--- | :--- |
| Healthy | hurl, sling, tail_throw | drive_down, spike, tail_throw | back_throw, turn_throw, tail_throw |
| A broken arm | sling, tail_throw | spike, tail_throw | turn_throw, tail_throw |
| A broken leg, in the air | hurl, sling, tail_throw | drive_down, spike, tail_throw | back_throw, turn_throw, tail_throw |
| A broken leg, on the ground | sling, tail_throw | spike, tail_throw | tail_throw |

- The grab, the hold, the tackle and the dive grab all work with one arm. The one-armed guard's reversal is the sweep; with a broken leg on the ground it is the throw.
- **Without a tail** every direction has one throw with a broken arm, and away has none with a broken leg on the ground (the neutral throw plays). If the tail goes, the slot needs an armless throw in its place.

## 7. What this needs
| For | What |
| :--- | :--- |
| **Animation** | the new poses in the rows; the pinned ragdoll; hands that follow the rival's collar, middle and arm |
| **Simulation and Encounter** | a `held` state on the thrown fighter: the holder, the socket, the tick it began and the release tick. He is placed at the socket every tick and cannot act |
| **Encounter** | beat ops `hold` and `throw`; the throw picked by direction and limb tags; `"side": "cross"` on the back throw and the turn throw; the turn throw as a launch entry under its gates |
| **Tools, with the contact data** | the hold sits at 36 u, inside `minSeparation` 45, so it needs the `clinch` floor proposed in wave 1; tempo names `grabReach` 10, `grabHold` 8, `turnHold` 2 (the turn reuses `stepAround` 8) |
| **Animation, later** | an arm socket, for the sling and the reversal throw |
| **Legal** | a screen of the Legal lines in the rows: they are Combat's proposals |
| **Orb, through Art** | the tail (the tail throw) |
