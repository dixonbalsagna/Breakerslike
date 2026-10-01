# Rule of cool: the narrative side

Owner: Narrative and Fighter Identity. Version 1, 2026-10-01. Answers the EP's brief on Orb's rule-of-cool picks (`docs/design/rule-of-cool.md`, `docs/ep/vision.md` questionnaires 11 and 12). The data is in `data/narrative/combat_barks.json` and `data/narrative/hints_fix.json`. Every name and line is a placeholder in the current house style, easy to re-style, because Orb is still hand-editing the voice lab batch (`voice-lab/batch-01-protagonist.csv`). Lines are original and unsearched unless noted. No `.private/`, no git.

## 1. Face cut-ins: what a bark event carries

Orb: every quip, one-liner, banter line and taunt shows the speaker's face at the side of the screen. UI built it (`ui/data/faces.json`, `hud-spec.md` section 29). The dialogue director's bark events must carry:

| Field | Values | Notes |
|---|---|---|
| `kind` | `line`, `reply`, `retort`, `callback`, `jewel`, `thought` | As in `dialogue-director.md` section 5. UI gives a face to every kind except `thought`. |
| `speaker` | a **numeric fighter slot** (0, 1, ...), or the string `"crowd"`, or `"narrator"` | A crowd or narrator line sends the string, and UI shows no face for it (evacuation barks and tutorial hints use them). |
| `priority` | 1 ambient, 2 ordinary, 3 important, 4 set piece or shout | UI shows no face below priority 2. |
| `display` | `{style: caption | thought | shout, dur_s}` | A shout is always faced. |

**In data**, a line cannot know the slot, since the same line can be spoken by slot 0 or 1. So each line declares `speaker_role` (`self`, `opponent`, `crowd` or `narrator`), and the dialogue director resolves it to the numeric `speaker` when it emits the event. The shape is in `combat_barks.json` (`event_shape`) and in `line-system.md` section 14.

**Needs from sim or director** (see NEEDS FROM EP): the sim events that trigger these barks must carry the actor's fighter slot.

## 2. Move names are shouted

The fighter shouts the name of a signature, special or finisher. There is no name card, and Legal's rule is that a name is **never stretched into drawn-out syllables** across a charge. So each shout is a single, short, clipped burst fired at the start of the move.

| Fighter | Signature | Shout lines (alternates) |
|---|---|---|
| KAI | Meridian Lance | "Meridian Lance!" / "Lance!" / "Here. Meridian Lance!" |
| VORR | Calamity Wave | "Calamity Wave." / "Wave." / "Look. Calamity Wave." (low and flat; VORR is calm) |

**How they are tagged** (`combat_barks.json`, `shouts`): `trigger: signature_start`, `kind: line`, `speaker_role: self`, `priority: 4`, `display: {style: shout, dur_s: 0.8}`, `cues: [effort.heavy]`, `no_stretch: true`, `max_syllable_s: 0.25` (so Audio renders it as one hit), and tags `move_name` and `signature`. A special or a finisher uses the same pattern with `special_start` or `finisher_start`. The four real fighters have placeholder stubs (Keeper's Lance, The Barrage, Decree Line, Portal Blitz).

## 3. Taunts feed meters

A completed taunt feeds a meter only (Pride +6, heat +10, Wrath +8, Hunger +5), takes 1 second, can be punished, and shows the face cut-in. **No beckoning gesture** (Legal). Each fighter has his or her own gesture and a small set of lines said during the second.

| Fighter | Meter | The gesture (not beckoning) | Taunt lines | If it is punished |
|---|---|---|---|---|
| Protagonist | heat +10 | A boxer's shuffle: rolls his shoulders, bounces on his toes, grinning | "Is that all? I hope not." / "I'm just getting warm." / "Go on. Show me more." / "Again. That one was fun." | "Ow! Fair." / "Ha! I asked for that." |
| Anti-hero | Pride +6 | Adjusts a cuff of his regalia without looking at the opponent | "You were adequate." / "Fifth. Behind the goons." / "Is that what you call a fight?" / "Look at me. I have not moved." | "...Noted." / "That was a mistake. Mine." |
| Empress | Wrath +8 | Smooths her train over one arm and tilts her chin | "Petitioner, you are boring us." / "We have seen better. We have commissioned better." / "How quaint." / "Do carry on. It is nearly amusing." | "You struck us mid-sentence!" / "How DARE you. ...We dare." |
| Cyborg | Hunger +5 | Wipes a plate on his sleeve and holds out a menu | "Would sir like a menu?" / "You look delicious." / "Your table is ready. Whenever you are." / "Take your time. I am not going anywhere. I am also hungry." | "Rude. I was mid-service." / "Please do not interrupt the waiter." |

Taunts are priority 3, so they always get a face.

## 4. The rival's "On the Chin"

**A name for the move: Chin Up** (a placeholder). It is the proud lift of the chin as he plants his feet and opens his arms, and it keeps the plain phrase "on the chin" in play. Alternates: **The Open Stance**, **Unmoved**.

**The bravado line** when a signature is absorbed. "Was that supposed to hurt?" passed Legal's exact-phrase search, so it leads. Two alternates in his voice (no contractions, no exclamation), which still need an exact-phrase search:

1. "Was that supposed to hurt?" (passed)
2. "Again. I was looking elsewhere."
3. "That was your best? Noted."

For a completed absorb (three hits): "Three. Is that all?" / "You may stop whenever you are ready." (both unsearched).

## 5. Launch labels

- **The straight-down slam keeps its working label, CRATER SLAM.** It is plain, ours, and it says what it leaves. A slam is an event.
- **SLAM DOWN should be renamed now that it is a forward drive.** "Slam" promises straight down, and the vector is now down and forward at 25 to 50 degrees, so the word is wrong, and it would blur the line between the event (CRATER SLAM) and the norm. **Pick: DRIVE DOWN**, which matches the vector's own intent word (`drive`) and keeps "down". The rule for names: *slam* means a straight-down event, and *drive* is the norm.
- UPPERCUT stays. If the earlier glossary picks are adopted, SMASH ACROSS, BUILDING SMASH and MOUNTAINSIDE become HURL ACROSS, THROUGH THE WALL and INTO THE MOUNTAIN. These are debug-feed names, so the change is cheap.

## 6. The last stand

One short line when the free last signature becomes ready at the brink. No final speech (Legal). Priority 4, caption, so it gets a face.

| Fighter | Line |
|---|---|
| Protagonist | "One more." |
| Anti-hero | "I am not finished." |
| Empress | "We are not amused." |
| Cyborg | "Please hold. I am not done." |
| KAI (legacy) | "Not yet!" |
| VORR (legacy) | "Not like this." |

## 7. Stale tutorial hints

The stance keys are gone since ADR 0008: stances are held states (Attack is Press, hold Guard, tap Dodge, hold Dodge and move is Escape). Five beats still said "pick a stance". The corrected lines are in `data/narrative/hints_fix.json`, for UI to apply to `ui/data/reads.json` (UI owns that file). All of them name a choice, never a timing, and the player is the fighter.

| Key | Now | Replace with |
|---|---|---|
| `b2.hint` | "You are the fighter. Pick a stance and your blows play out to match." | "Attack, hold Guard, or tap Dodge. The blows follow." |
| `b2.alt0` | "Change stance and watch your fighter change." | "Hold Guard, then attack. Feel how the exchange changes." |
| `b2.alt1` | "Try a different stance. Your blows follow it." | "Try Dodge, then Attack. Your blows follow what you do." |
| `b2.nudge` | "Pick another stance. Your blows will change with it." | "Hold Guard or tap Dodge. Watch the blows change." |
| `b2.done` | "Different stance, different blows." | "What you do decides the blows." |
| `b3.nudge` | "Set your attack to heavy while they guard." | "Use your heavy attack while they guard." |
| `b5.alt0` | "A heavy is winding up. DODGE, or GUARD and wait." | "A heavy is winding up. Tap Dodge, or hold Guard and wait." |
| `b5.alt1` | "See the wind-up? Answer it with a stance." | "See the wind-up? Tap Dodge or hold Guard." |
| `b5.nudge` | "When they wind up big, choose DODGE or GUARD." | "When they wind up big, tap Dodge or hold Guard." |
| `b6.alt0` | "Hold Charge until it's full enough, then set your signature." | "Charge until you have enough, then call your signature." |
| `b6.nudge` | "Your signature needs a full 45." | "Your signature needs a full 45 Charge." |
| `b8.alt0` | "A finisher is coming. Pick the stance that answers it." | "A finisher is coming. Guard, dodge or attack to answer it." |
| `b8.nudge` | "Choose a stance to match their finisher." | "Answer their finisher: Guard, Dodge or Attack." |

Beats 1, 4, 7 and 9 and the other lines are unchanged. The beat descriptions in `docs/design/tutorial.md` still say "pick a stance"; Game Design should update them, since the hints now match the held states.

## 8. Is the mixer's drift what I intended? (style revision 3)

Simulation added `leaveMaxStancePct` 55 and `leaveHoldS` 15 from my draft's text. QA then finds the AI sits in one label most of a match: rusher 1,400 events, turtle 270, mixer 40 in 400 matches.

**Part of that is what I intended, and part is not.**
- **Intended: stability.** Stickier labels were the whole point of revision 3 (fewer entries and endings), and an AI that presses most of the time should read as a rusher most of the time. The AI is a rusher by design, so a long rusher label is honest.
- **Not intended: a mixer that is almost never reached.** The mixer needs the largest stance at 45% or less, and the AI sits at 45 to 55%, in the dead zone between mixer (45) and rusher entry (55). I did not mean the mixer to be rare.
- **My advice:** keep the stability. For AI play, label shares are a description of behaviour and not a target (as in the earlier bands). Expect real variety from human play, where fighters vary their habits. If the mixer should appear more often, the data-only fix is `mixer.maxStancePct` from 45 to **50**, which closes the dead zone. If Orb wants AI against AI to show style shifts (for a demo), vary the AI's style profile by match or by act (Encounter), and leave the thresholds alone.

## NEEDS FROM EP

- **Simulation (sim or director lines):** confirm that these events carry the actor's fighter slot as `actor`, so the dialogue director can set `speaker`: `signature_start`, `special_start`, `finisher_start`, `taunt_start`, `taunt_punished`, `absorb_signature` (On the Chin), `last_stand_ready` and `brink_enter` (which already has `actor`). If a name differs, tell me and I will change the data triggers.
- **UI:** apply `data/narrative/hints_fix.json` to `ui/data/reads.json`; read `speaker_role` as resolved to `speaker`; make sure a `shout` style line with a numeric speaker is always faced.
- **Game Design:** update the beat text in `tutorial.md` to the held states; decide whether to rename SLAM DOWN to DRIVE DOWN.
- **Legal:** an exact-phrase search on the two On the Chin alternates, the taunt lines and the last-stand lines.
- **Audio:** render a shout with `no_stretch` as one clipped hit.
