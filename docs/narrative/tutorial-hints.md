# Tutorial hint lines

Owner: Narrative and Fighter Identity. Version 1, 2026-09-30. The text for Game Design's tutorial (`docs/design/tutorial.md`, nine beats). Names are placeholders. Lines are original and unsearched.

**The rule.** The tutorial teaches **choices and reads, never timing**. Every line names a thing to look at or a choice to make, and none says "press now", "time it" or "wait for it". Hints are short (10 words or fewer), have no jargon and no franchise terms, and use the display names from `glossary.md`: stances are **PRESS**, **GUARD**, **DODGE**, **ESCAPE**, the resource is **Charge**, and a broken defence is a **GUARD BREAK**.

**How it plays.** Each beat has a **hint** (shown while the beat is open), a **nudge** (shown only after 20 seconds without the action), and a **done** line (shown when the beat ticks). Two or three alternates each, so a replay does not read the same. **Thoughts** are the player's fighter thinking aloud, and they model the read ("They're guarding. Something heavy, then."). The hints are system text for the hint line; the thoughts use the thought display.

## The nine beats

| # | The player learns to... | Hint | Alternates | Nudge (after 20 s) | Done |
|---|---|---|---|---|---|
| 1 | Fly, and that the planet wraps | "Fly. The world wraps: keep going and you come back round." | "Head for your rival, or keep going and watch the world wrap." | "Try flying the other way. It's the same planet." | "See? No edges." |
| 2 | Pick a stance | "You are the fighter. Pick a stance and your blows play out to match." | "Change stance and watch your fighter change." / "Try a different stance. Your blows follow it." | "Pick another stance. Your blows will change with it." | "Different stance, different blows." |
| 3 | Set the attack weight to beat a stance | "They're guarding. Hit heavy." | "A guarding rival breaks under heavy blows." / "Guard up? Go heavy." | "Set your attack to heavy while they guard." | "Guard broken. That's the read." |
| 4 | Read damage on bodies | "Watch the body: that's how you read damage." | "No health bar. Look at their arms, legs and head." / "Where is the rival hurt? Look." | "Look at the rival. Where are they worn?" | "Now you can read a wound." |
| 5 | Read a wind-up and answer with a stance | "Big swing coming. Slip it." | "A heavy is winding up. DODGE, or GUARD and wait." / "See the wind-up? Answer it with a stance." | "When they wind up big, choose DODGE or GUARD." | "You read it and answered it. That's the game." |
| 6 | Charge, and queue a signature | "Charge, then call your signature." | "Hold Charge until it's full enough, then set your signature." | "Charge up. Your signature needs a full 45." | "Signature away. Watch it land." |
| 7 | Take a transformation when ready | "You're ready. Transform when you choose." | "The change is ready. Take it whenever you like." | "Your transformation is ready. Nobody will stop you." | "Nobody interrupts a transformation. Take your time." |
| 8 | Meet a finisher with the right stance | "They're going for the finish. Brace, slip or meet it." | "A finisher is coming. Pick the stance that answers it." / "Their finish has a kind. Match it." | "Choose a stance to match their finisher." | "You held. The fight is still yours." |
| 9 | Be let go | "From here, the fight is yours." | "You have the reads. Go and win." / "That's everything. It's your fight now." | (none: the tutorial is over) | "Good. Now go and play." |

## Thoughts that model the reads

The player's fighter thinks these when the matching situation appears, in the beats where the read is the lesson.

| Beat | Situation | Thought (alternates) |
|---|---|---|
| 3 | The rival is guarding | *They're guarding. Something heavy, then.* / *Guard up. That won't hold against a heavy.* |
| 4 | A rival region is worn | *His arm's hurt. That's where to aim.* / *No bar. The body tells me.* |
| 5 | The rival winds up | *That's a big swing. I could slip it.* / *Heavy coming. DODGE, and I'm through.* |
| 6 | Charging | *Almost enough. Almost.* / *Nearly there. Then the signature.* |
| 7 | A transformation is ready | *I'm ready.* / *This one's mine to take.* |
| 8 | The rival's finisher telegraphs | *This is the finisher. Choose a stance that answers it.* / *Brace, or slip. Which one is it?* |
| Any | The player holds one stance for a long time | *Only a little longer...* (a patience thought, as in the Calm band) |

## Notes

- **Never timing.** No hint contains a timing instruction. Beats 5 and 8 say to *choose a stance*, because the blows themselves play out automatically and the player owns the choice.
- **No franchise terms.** The words "Charge", "signature", "transformation" and "stance" are ours. "Guard break" is a common fighting-game phrase.
- **Length.** Hints fit a one-line hint bar. Thoughts are shorter still.
- **Accessibility.** The lines are text with an icon, so they work with the "keep hints on" toggle and screen readers. Localization can translate them, since there are no puns.
- **Tone.** The tutorial voice is the system's, plain and friendly. Only the thoughts carry the fighter's personality, and they use the Protagonist's warmth.
- **Numbers.** "A full 45" refers to the signature's cost of 45 Charge. If the number changes, this line does.

## Orb's rule for all player-facing text (2026-09-30)

**The player IS the fighter.** Never call them a strategist, and never say a director plays the fight ("director" and "strategist" stay internal). Be blunt about what they control, and that there are no combo inputs to learn.

**What you control** (for the How to play card and the onboarding; alternates):
1. "You are the fighter. You fly, dash, pick a stance, choose light or heavy, charge, call your signature and specials, and transform."
2. "There are no combo inputs to learn. Blows and combos play out on their own from those choices."
3. "Fly and dash. Pick PRESS, GUARD, DODGE or ESCAPE. Choose light or heavy. Charge, and call your signature."
4. "You decide where to go and how to fight. The blows play out by themselves."
5. "Nothing to memorise. Choose, and your fighter fights."

**Lines I changed in this file:** beat 2's hint, alternates, nudge and done line, and the note about who owns the strike. The other eight beats say nothing about a director, so they stay.
