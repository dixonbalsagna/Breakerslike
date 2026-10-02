# Agency: the director's slice plan after Orb's picks

Owner: Encounter Systems Director. Date: 2026-10-02. Status: plan only. Sources: `docs/ep/vision.md` ("Orb's picks after the pitches"), `docs/design/agency-pass.md`, `docs/director/agency-evidence.md`. The first slice (the attacker's free cancel, the earned launch, the knock-back, the press log) is in `agency-slice-1.md`.

Sizes are the director's code only: **small** is under 60 lines, **medium** 60 to 200, **large** over 200. Each slice is one golden regeneration.

**Built since:** 1a and 1b, in `agency-slice-2.md`. 1a needed no new event and no core lines: the approach runs before the exchange exists, and the `attack` event fires at the engage. 1c, 1d and the flow count (2c), in `agency-slice-3.md`. The lights-only ruling, in `agency-slice-4.md`. 3a (bolts and the charged shot), in `agency-slice-5.md`. Next: the buried fighter's follow-up and the slide's bump, then 3b and 3c.

## 1. The ranged press: three bands, decided at the wind-up

| Slice | What the director does | Size | Needs |
| :--- | :--- | :--- | :--- |
| **1a. The exchange is decided at the wind-up** | `_start` splits in two. At the press only the attacker's move starts and the defender stays free. An `engage` beat, one wind-up before contact, locks the defender, reads his state and his own press, and plans the rest. A defender who flies off turns it into a pursuit | Medium (about 150 lines) | **Simulation:** an event at the engage (the `attack` event's template and defender state are unknown at the press), three core lines. **Every reader of `attack`:** HUD, Camera, Animation, QA. **Tools:** the event's row and fixtures |
| **1b. The bands** | Close: a strike now, as today. Mid: a short lunge, decided at its wind-up (1a). Far: no strike exists; a press there is a taunt or a charge (1c, 1d). The band edges are data | Small | **Game Design:** the two distances. **Tools:** schema |
| **1c. Far, tap: the taunt as a challenge** | A director state of about a second: the cue, the meter (with the guard against farming), and a window in which the rival's attack press answers it. Answered, both rush and meet in a clash or a blur. Unanswered, it ends and he is free | Medium | **Combat:** the meeting exchange (a clash and a blur; the interim is today's HEAVY CLASH and TRADE BLOWS), the taunt cues. **Narrative:** the lines. **UI:** the face cut-in. **Game Design:** the meter amounts |
| **1d. Far, hold: the charge** | A press held past the hold time arms the attack and the fighter flies in himself, steering. The director takes over inside contact range with only the wind-up left. A held light is fast and can be dropped for free (the feint); a held heavy is slower, shrugs off blasts, and can earn a launch (the held heavy already does) | Large (about 250 lines) | **Controls and Simulation:** the hold as an input (which button is held, and its release), and the charge's movement in the fighter's flight (speed by weight, steering). **Camera:** framing a charge. **Combat:** the arrival pieces. The "shrugs off blasts" part waits for the energy slice |

Order: 1a, then 1b with 1d, then 1c. 1a alone already frees the defender at every range.

## 2. The alchemist: timing grades and the flow count

| Slice | What the director does | Size | Needs |
| :--- | :--- | :--- | :--- |
| **2a. Recipes** | Strings planned a phrase at a time from both five-press windows, re-read at decision ticks. The recipe is a data table; no draw decides an outcome | Large (about 400 lines, `alchemy.gd`) | **Combat:** the phrases with their three endings, the recipe table, the join rules, per-phrase damage. **Tools:** schema. **QA:** damage per minute held |
| **2b. Timing grades per style** | Each press is graded against the beat: a steady mash, a hold released on the flash, a tap in time with a blow. The grade upgrades the style (a perfect blur, a guard break, a clean hit) | Medium | **Controls and Simulation:** the release edge and the hold length in the intent (a mash and a timed tap are readable today; a release is not). **Combat:** the upgraded pieces. **VFX and Audio:** the flash to time against |
| **2c. The flow count** | A per-fighter count that timed presses build and a miss resets; it earns the ending in place of today's four launch rules | Small, on 2b | **Game Design:** the numbers. Orb asked for balance tests: consistent timing should give a substantial edge |
| **2d. The traded-blows set piece** | Both players time their power blows in turn until one misses: an exchange kind of alternating pulse windows | Medium | **Combat:** the set piece (in authoring). **Simulation:** the clash score and the pulse index as state. **Legal:** its twelve staging rules. **Animation, Camera** |

## 3. The first energy slice

| Slice | What the director does | Size | Needs |
| :--- | :--- | :--- | :--- |
| **3a. Hold RB: blasts** | With the energy family held, a light is a volley and a heavy a charged shot. Blasts are travelling shots the director owns, as it owns beams: they fly, they hit or are blocked, a perfect block deflects them. From range the defender answers a blast as a blast | Large (about 350 lines, a new `blast.gd`) | **Simulation:** the shots as state (a list beside the beams, hashed, and in the view for VFX). **Controls:** RB held as the family. **Combat:** volley and charged-shot data. **Game Design:** ki costs and damage. **VFX, Audio** |
| **3b. The short beam, or stream** | A held heavy with RB: a lesser beam that drains ki while held. Stream against stream, and stream against a signature, are struggles | Medium | **World:** what a stream carves. **Game Design:** drain and damage |
| **3c. The beam plays** | A late answer in the first 20 ticks after a beam fires. The dodge with no roll. The perfect block's 14 ticks. Swat, split and walk through, by the direction held at contact | Medium, and no core lines | **Combat:** the outcome rules and cue names. **VFX:** the split and the swat. **Game Design:** the direction sampled at contact |

The signature limit stays as it is until Orb has played this.

## 4. The provisional escape control

| Slice | What the director does | Size | Needs |
| :--- | :--- | :--- | :--- |
| **4. Escape, provisional** | Fast flight at will is the fighter's movement. The director's part is what an attack on a fleeing rival becomes (the pursuit, as today), a way out of an exchange at a risk (an escape press inside an exchange: he breaks off, and the rival's next blow, if it was already winding up, lands clean), and the AI's use of it | Small to medium (about 80 lines) | **Controls:** the input. **Simulation:** the flight speed. **Game Design:** the risk |

## What I would build first

1a. It needs the one new event, and it is the base for the bands, the taunt and the charge. Then the energy slice 3a, because Orb will not rule on beams before playing it. The recipes (2a) wait for Combat's phrases.
