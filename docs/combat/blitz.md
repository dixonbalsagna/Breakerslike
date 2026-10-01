# Speed blitzes: ping-pong, teleport spam, no pass-through, full contact

Owner: Combat and Choreography. Date: 2026-10-01. Status: plan only; no data or code. Game Design sets the blitz rules (when, cost, damage, the defender's answers); Encounter builds it; ADR 0009 gives the choreographer depth.

**Orb** (`docs/ep/vision.md`, questionnaire 10):
- "I really want the 'ping pong' speed blitzes to look great, 'teleport spam' should definitely be a system."
- Flight paths should be efficient but not direct. A fighter knocks the opponent away at high speed, then blasts off even faster to arrive ahead and knock them back. The path arcs like a golden-ratio spiral, not a straight line that would clip through the other fighter.
- From play: fighters pass through each other in close exchanges and end up facing opposite ways; every hit should make full contact.

---

## 1. The ping-pong blitz

### 1.1 What it is
A blitz is a fast chain (`styles.json` `chains.blitz`). The **ping-pong** is its choreography: instead of launch, catch, launch along one line, each link is a **bounce**.

| Beat of one bounce | What happens |
| :--- | :--- |
| **Knock-away** | a strike and a launch: the body flies off at high speed. The first knock is the exchange's own launch |
| **Intercept** | the attacker leaves at once and reaches a point *ahead of the body*, by a spiral flight (1.2) or a blink (section 2) |
| **Return blow** | the attacker is already there, wound up, when the body arrives, and knocks it back |

- **Length:** 2 to 5 bounces, then the **ender**: the last return blow, with the chain ender's 18-tick wind-up, then a long launch or a ground slam.
- **Who sets the length.** Under ADR 0008 the queued presses set the links, capped at 5 hits. For the AI and the Simple layout it is `chainP`.
- **Patterns.** The knock vectors follow one of three authored patterns, chosen from the room available:

| Pattern | Vectors | Where |
| :--- | :--- | :--- |
| **Rally** | back and forth along one line, with ADR 0009's small lane angle each way | open air, long sight lines |
| **Ladder** | a zigzag climbing, then a spike down for the ender | near the ground or a city: it clears the buildings, then slams |
| **Orbit** | each knock turns about 70 degrees, so the body circles a point | over a landmark or a crowd of formations: the camera can hold one frame |

### 1.2 The intercept flight: a quarter-turn golden spiral
The attacker flies from **S** (where it stands after the knock) to **I** (the intercept point) along a logarithmic spiral that turns a quarter turn and grows by the golden ratio φ = 1.618.

**The intercept point.** The planner already predicts a launched body's free flight (`launch.gd`). Call B(t) the body's predicted position t ticks after the knock.
- Pick the intercept tick `tᵢ`: 30 ticks by default, shorter in Frenzied mood. Game Design tunes it.
- I is the body's position then, pushed one reach further along its direction of travel: `I = B(tᵢ) + reach · v̂(tᵢ)`. The attacker ends just beyond the body's arrival point, facing it.

**The curve.** Let `d = I − S`, and let `n` be a unit vector perpendicular to `d`: the side the pole sits on. Let `σ` be +1 or −1. Then:

```
pole:   C = S + (d + σ·φ·|d|·n) / (1 + φ²)
path:   P(s) = C + φ^s · Rot(σ · 90° · s) · (S − C),   s from 0 to 1
```

`Rot` turns the vector `S − C` in the plane of `d` and `n`; the arc bulges on the side **opposite** the pole. P(0) = S and P(1) = I exactly.

**What the formula gives** (checked numerically), with D = |d|:
| Property | Value |
| :--- | :--- |
| Pole | 0.276·D along the chord, 0.447·D to the side |
| Path length | **1.109·D**: 11% longer than the straight line (efficient) |
| Greatest distance from the straight line | **0.205·D**, at s ≈ 0.54 (not direct) |
| Leaves S at | 48.7° off the chord, so it never starts along the body's line |
| Arrives at I at | 41.3° off the chord from the bulge side, so it swings in from the side, ahead of the body |

**Which side it bulges** (deterministic, in this order):
1. **Away from the opponent's path.** Take the body's mid-flight point `M = B(tᵢ/2)`. Put the pole on M's side of the chord, so the arc bulges on the other side.
2. **Alternate.** When the body flies nearly along the chord (M within 0.05·D of it), flip the side from the previous bounce. The first side comes from one keyed draw (`blitz/side`, the exchange index).
3. **The bulge plane is the choreographer's** (ADR 0009). `n` may point up or down, or into a neighbouring depth lane. Prefer a depth-lane bulge when the body's path is level: on screen the attacker swings around behind or in front of the body's line and the two never overlap. Prefer up when within 4 bh of the ground.
4. **Clearance.** Sample the arc at 8 points. If any sample is under the ground plus 0.5 bh, or inside a structure's footprint, try the other side, then another plane.
5. **Shallower if needed.** If no quarter turn clears, reduce the turn angle `α` (60°, then 30°): `P(s) = C + φ^(s·α/90°) · Rot(σ·α·s) · (S − C)`, with `C = S − d / (φ^(α/90°) · Rot(σ·α) − 1)`. The division treats vectors in the plane of `d` and `n` as complex numbers; at α = 90° it reduces to the pole formula above.
6. **Last resort:** a blink intercept (section 2).

**Timing: "blasts off even faster".**
- The attacker leaves 4 ticks after the knock (after the hit-stop).
- It arrives **before** the body: 6 ticks early for a middle bounce (its anticipation), 18 for the ender (its wind-up).
- So with `tᵢ = 30`, the flight takes 20 ticks over 1.109·D, while the body covers about D in 30. The attacker averages about **1.7 times the body's speed**.
- Along the path, `s` follows a fixed ease, `s = 1 − (1 − t/T)²`: a hard launch-off, then a brake into the arrival. No draws.
- All of it is planned at the knock from sim state. The spiral uses the sim's deterministic math (the same trig and power functions as the rest of the sim, never the platform's).

---

## 2. The teleport variant, and how the two mix

**Blink intercept.** The attacker vanishes at S with the air-ripple tell and reappears at I, already wound up. There is no travel, so the bounce is quicker: `tᵢ` of 16 ticks instead of 30. Each blink costs ki (Game Design's number).

**"Teleport spam" as a system.**
- **A blink chain.** Consecutive blink intercepts, each with its ripple out, ripple in and an afterimage left at the departure point. The victim is knocked only a short way each time (the chain link's small pop), and the attacker appears around it in a fixed cycle: front, above, behind, below. The body barely travels; the afterimages ring it.
- **The limit is ki, not a rule against it.** Spam is allowed and it reads as spam, but each blink is paid for, and there are at most 5 hits.
- **The answer.** The victim's burst (ADR 0008) breaks it at a return blow's wind-up. If the victim has an attack queued and the ki, the director turns the next bounce into a **teleport clash**: both blink and meet (`styles.json` `blink_clash`). Game Design rules whether that needs a request.

**Mixing flight and blink, per bounce** (one keyed draw each, `blitz/kind` with the link index):
| Condition | Intercept |
| :--- | :--- |
| the chord D is at least 6 bh, and a spiral clears | flight, by default |
| D under 6 bh, or no spiral clears | blink |
| otherwise | blink with a chance by mood (Calm 0.2, Tense 0.4, Frenzied 0.6; +0.2 for a fighter with the `blink` trait): suggestions for Game Design |
| the same kind three times running | forced change. The exception is the blink chain above, which the director picks whole in Frenzied mood for a `blink` fighter |

A typical Tense blitz reads: flight, flight, blink, ender. A Frenzied one from a blink fighter: blink, blink, blink, flight ender.

---

## 3. No pass-through in close exchanges

**What goes wrong today.** Approach and footwork beats move a fighter in a straight line to an offset from the opponent, and facing is refreshed only when a strike lands. A move to the far side passes *through* the opponent, and both fighters then face the wrong way until the next strike. Combat's own "circle" beat in the dynamic profile does exactly this.

**The rule:**
1. **Each exchange has sides.** At the request, the attacker is on one side of the defender (left or right along the shortest arc). Every approach, footwork and pursuit target keeps that side: offsets are measured from the opponent toward the fighter's own side, not from where the fighter happens to face.
2. **Changing sides needs an explicit cross-over beat.** There are four authored cross-overs, each a visible move of at least 6 ticks that goes *around* the opponent, never through:
   - a **vault** over (an arc at least 1 bh above the opponent's head);
   - a **slide** under (airborne only);
   - a **step-around** through a neighbouring depth lane (ADR 0009);
   - a **blink** behind (with the ripple).
   The cross-over swaps the sides and emits a cue.
3. **Bodies never overlap.** Each fighter has a body radius of about 0.5 bh. A planned path that would enter the opponent's radius is rejected at plan time and replaced by a cross-over or a shorter move. If two bodies still end up overlapping (a launch, a physics nudge), the sim pushes them apart evenly.
4. **Facing always follows the opponent.** While a fighter is in an exchange and not launched, its facing is recomputed **every tick** toward the opponent. A cross-over flips it at its midpoint. A launched body faces along its velocity. A flight faces along its path, then turns to the opponent on arrival.
5. **Contact distance, not overlap.** Entries end at the striking piece's reach from the opponent's contact socket (section 4), never closer than the two body radii.

The EVASIVE dodge (a blink behind the attacker) is already a cross-over. Under rule 4 the attacker's facing follows at once, so "both facing away" cannot persist. The dynamic profile's "circle" becomes a vault or a step-around when the data next changes.

---

## 4. Full contact on every hit

**Every strike's contact point is on the opponent's body.**
- **Sockets.** Each fighter's data lists contact sockets in body-height units, per Wounds region and side: head, core, left and right arm, left and right leg (and the Empress's mantle). Animation's rig owns the exact points.
- **The contact point is computed by the sim.** It is the struck fighter's position at the contact tick plus the socket for the strike's region and side. It goes out in the part cue (`moveset-system.md` section 7.4) as `contact {x, y, depth}`, so Animation's IK puts the striking limb's end on that point on that tick.
- **The striker is placed to reach it.** At plan time the striker's position at the contact tick must be within the piece's reach of the socket. If it is not, the sim moves the striker during the anticipation, by up to 0.3 bh, as part of the piece's approach. Beyond that the piece is not a candidate, and the composer picks another.
- **Moving targets.** For a launched body (chain links, return blows) the socket is on the body's *predicted* position at the contact tick: the same prediction the intercept uses.
- **Blasts and beams.** The impact is on a socket too: a blast's arrival point, and the beam's connect point.
- **The hold sells it.** Hit-stop begins on the contact tick with the limb on the socket, and the reaction starts from that pose.

Together with section 3 this addresses Orb's list: backwards facing, pass-through, and punches that miss by a hand's width. Bent-the-wrong-way elbows are a rig and IK matter for Animation, helped by a reachable target.

---

## 5. What each team needs

| Team | Needs |
| :--- | :--- |
| **Game Design** | The blitz rules: what starts a ping-pong (queue depth, mood, act); damage per bounce; ki per blink and the blink shares; the intercept tick by mood; the burst as the escape; whether a teleport clash needs the victim's request; the band (2 to 6 blitzes a minute in Tense and Frenzied) |
| **Encounter** | (a) the intercept planner: the flight prediction, the intercept point, the spiral with its side, plane and clearance checks, the blink fallback. (b) A `flight` beat (`{w, to, path, ticks, ease}`) and a `blinkTo` beat. (c) The three patterns as launch-vector sequences. (d) A `blitz_plan` event issued one bounce ahead: the points, ticks and kinds. (e) Section 3: sides, cross-over beats, the overlap check and the per-tick facing. (f) Section 4: sockets in the part cue, and the reach check |
| **Simulation** | depth in positions (ADR 0009) for lane bulges and step-arounds; body radius and the push-apart; deterministic power and trig for the spiral; per-tick facing in the fighter step |
| **Animation** | flight poses: launch-off, banking along the curve (the bank follows the turn direction), brake and arrive, the return blow's wind-up held until the body arrives. The four cross-over pieces. IK to the contact socket on the contact tick, with elbow and knee pole constraints so joints bend the right way. Facing driven by the sim, never by the clip |
| **Camera** | The ping-pong framing. One **rally frame** for the whole blitz, from the `blitz_plan` points: no whip pan per bounce. A small punch-in on each return blow with the hit-stop. If the rally is wider than fighters can stay readable (ADR 0009: fighters read large), follow the body with a lead toward the next intercept. For a blink chain: a tight frame on the victim. On the ender: a push-in and hold |
| **VFX** | a flight trail that follows the true path (the spiral), a launch-off burst and a brake flare, a shock ring on each return blow, ripples and afterimages for blinks, and a rhythm accent that rises with each bounce |
| **Audio** | a rising pitch or accent per bounce; the ripple sound for blinks |
| **Tools** | later: schema for the blitz patterns, the intercept settings and the sockets |
| **QA** | no body overlap in any exchange frame; facing error (a fighter in an exchange facing away) at 0 frames; contact error (limb end to socket) within tolerance on every contact tick; blitz rate in band; the share of flight to blink intercepts |

**Order.** Sections 3 and 4 (no pass-through, facing, contact) fix what Orb sees today and need no new content, so they come first. The ping-pong with spiral flights comes next, then the blink variant and the mix.
