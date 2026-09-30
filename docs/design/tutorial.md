# Tutorial: the How-to-play card and a guided first match

Owner: Game Design. Status: plan, for UI, Encounter, Simulation, Narrative and QA. Date: 2026-09-30.

Orb's onboarding choice (questionnaire 4) is a How-to-play card plus a guided first match. It answers Orb's friend: "I'm not sure what I'm supposed to do… a tutorial or a card explaining how to play would be good." This plan builds on UI's proposal (`docs/ui/tutorial-proposal.md`), reworked for Orb's control ruling (`stance-matrix.md` §4b).

**The principle, front and centre.** The player owns strategy, pacing and positioning. The director owns combos, tactics, timing and voice. So the tutorial teaches **choices and reads, never timing**. There are no parry presses and no struggle presses, because both are director outcomes now.

## The beats (one match, about 4 to 5 minutes, on the real planet)

No fail state, no fixed timer and no forced order: a beat done early is ticked off. Hints reappear only after 20 s without the action. Skip is always one key.

| # | The player learns to… | The beat is done when | The hint line (Narrative writes the final text) |
| :--- | :--- | :--- | :--- |
| 1 | Fly, and that the planet wraps | They fly to the rival, or across the seam | "Fly. The world wraps: keep going and you come back round." |
| 2 | Pick a stance, and see the director fight differently | They change stance twice and watch an exchange in each | "Your stance is your intent. The fight follows it." |
| 3 | Set the attack weight to beat the rival's stance | They set heavy while the rival shows DEFENSIVE, and see a GUARD BREAK | "They're guarding. Hit heavy." |
| 4 | Read damage on bodies | A rival region reaches battered, with the wound card and the crown arc | "Watch the body: that's how you read damage." |
| 5 | Read the rival's wind-up and answer it with a stance | They hold EVASIVE into a heavy (a dodge), or DEFENSIVE into lights (the guard holds, and patience earns a counter) | "Big swing coming. Slip it." |
| 6 | Charge, and queue a signature | They charge to 45 ki and set signature. The director fires it | "Charge, then call your signature." |
| 7 | Take a transformation when it's ready | The fill completes and they take it (a respected cinematic) | "You're ready. Transform when you choose." |
| 8 | Meet a finisher with the right stance | The rival's finisher telegraphs its kind, and they hold the counter stance, then see the struggle's pulses hold | "They're going for the finish. Brace, slip or meet it." |
| 9 | Be let go | A normal match against an easy rival | "From here, the fight is yours." |

Beats 3, 5 and 8 are the read lessons: stance against weight, and stance against the finisher's kind. They are the game's real skill, taught by doing.

## What each director builds (through the EP)

- **Encounter and Simulation: a tutorial rival profile, in data.**
  - A slow cadence, and it holds each stance for at least 3 s so the read is possible.
  - It always telegraphs weight and finisher kind.
  - It steers into beats 3, 5 and 8 when they haven't happened yet.
  - It stops at the brink for beat 8, and never finishes the player.
  - No rule changes: only a profile.
- **Narrative:** the hint lines (short, no jargon, no franchise terms), plus a few inner thoughts that model the reads ("They're guarding. Something heavy, then.").
- **UI:** the card (built), the hint line, beat ticks, and a menu entry.
- **Events** (UI's spec): `tutorial_beat {id, state}` with start, done or skipped, and `tutorial_hint {id, text_key}`. The beat script is a data file that reads existing events: stance change, `exchange_start`, the template tag, `region_stage`, charge, `heat_stage` or the form fill, `finisher_start` and `finisher_contest`.
- **Accessibility:** hints are text plus an icon, there is a "keep hints on" toggle, and reduced motion is respected.
- **QA:** a bot playthrough that ticks every beat.

## How we know it worked

A playtest with people new to the game, one session each, with no help:
- time to the first deliberate stance change: under 60 s;
- 80% can say afterwards what heavy does to a guarding rival;
- 80% can say where they read the rival's damage;
- 70% pick the right stance against a telegraphed finisher on their own, in the hand-off match;
- the share who quit before the first finisher: tracked;
- the test sentence: nobody says "I'm not sure what I'm supposed to do".

The tutorial match does not count toward UI's "first three matches with prompts". Prompts stay on for the three matches after it.
