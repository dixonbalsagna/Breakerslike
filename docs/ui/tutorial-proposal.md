# Proposal: a guided first match

Owner: UI and UX (a proposal for Game Design to design properly). Date: 2026-09-30. Status: proposal, nothing built beyond the How to play card (`hud-spec.md` section 17).

Orb's friend could not tell what to do. The card answers "what is this game"; it cannot teach timing, because nobody learns a window from a sentence. This is a light tutorial: one guided match, in beats, that the player can leave at any time. It must not break the core principle (Orb, Playtest 2): **the player owns macro strategy, pacing and positioning; the fight director owns combos, tactics and voice lines.** So the tutorial never teaches combos or moves. It teaches the four things the player does and the five things the player reads.

## What the player must learn (in this order)

| # | The player learns to... | How we know they did | What the HUD shows |
| :--- | :--- | :--- | :--- |
| 1 | Fly, and that the planet wraps | flew to the rival, then once round the planet or across the seam | the Fly glyph, the planet strip and the ring map lit |
| 2 | Choose a stance and watch the director act on it | changed stance twice and saw an exchange | the stance prompt row always on, one line "Pick PRESS" |
| 3 | Read damage on bodies | saw a rival's region reach battered (a wound card, the crown) | a hint under the card: "That is how you read damage" |
| 4 | Parry and chain | pressed Light inside a closing ring twice (clean or not) | the ring with its prompt glyph, `press_ack` marks, the clean tail |
| 5 | Dodge and escape as choices | took DODGE when the rival wound up, tried ESCAPE once | prompt row; a one-line note that ESCAPE is a gamble |
| 6 | Charge and signature | held Charge to 45 and fired the signature | the charge meter's 45 tick, `NEED 45 CHARGE` |
| 7 | Finish and survive a finisher | pressed on the beats of one struggle (their own or the rival's) | the struggle rings, the tally pips, assist width |
| 8 | Be let go | fights a normal match against an easy rival | the prompts fade out (they are off after the first three matches) |

Beats 3 and 7 are the ones a player cannot guess, so they are taught by doing, not by text.

## The flow

1. **The card** (first run only, 20 seconds, skippable). It is already built.
2. **Beats 1 to 7 in one match**, about four to five minutes, on the real planet, against a rival whose script is gentle and readable. A beat starts when the previous one is done or its timer runs out; each has a one-line hint at the top centre ("Choose a stance: press 1") that fades after the player does it. **No fail state, no fixed timer, no forced order**: if the player does something later in the list first, that beat is ticked off.
3. **Adaptive**: a hint reappears only if the player has not done the thing after 20 seconds; a player who already does it never sees it. Everything the tutorial shows is also on the card (pause menu, F1).
4. **Skip** is always one key or one tap (Pause menu: "Skip tutorial"). Skipping still marks the card seen.
5. **Hand-off**: the rival turns up to a normal AI, the prompts stay on for the first three matches, and the last hint says the director keeps fighting for you.

## What this asks of other directors (through the EP)

- **Game Design**: own the beats, their wording and their order; the assist widths used in beat 4 and 7; whether one rival fighter is the teacher. Decide whether the tutorial match counts as a match for "the first three matches".
- **Encounter and Simulation**: a "tutorial rival" profile in data: lower aggression, always telegraphs, windows always wide, will stop on the brink for beat 7, never finishes the player. No sim rule changes, only a profile and the existing hit-stop, windows and finisher.
- **Controls**: the assist (beat 4 and 7: parry buffer and struggle window at the wide values) and the prompt glyphs; touch hit-testing for the stance ring (`hud-spec.md` section 16).
- **Narrative**: the hint lines (short, no jargon, no franchise terms) and the director's voice in the match (the rival's lines stay procedural).
- **Accessibility**: the hint line is text plus an icon, never colour alone; a "keep hints on" toggle; reduced motion respected.
- **QA**: a bot playthrough that ticks every beat; the metrics below.
- **UI (me)**: the hint line and beat ticks (the HUD's "training hint line" that the spec lists as not built), the `tutorial_beat` events, and the menu entry. About two days of work once the events exist.

## Events the HUD would need

`tutorial_beat {id, state}` with state `start`, `done` or `skipped`, and `tutorial_hint {id, text_key}` (text from `ui/data/howto.json`, not the sim). The sim already emits everything the beats check (stance change, `window_open`, `press_ack`, `struggle_open`, charge); Game Design's beat script can be a data file that reads those.

## How we would know it worked

Playtest with people who have not seen the game, one session each, no help:
- time to the first deliberate stance change (target under 60 seconds);
- how many players press Light inside a parry ring at least once (target 80%);
- how many can say, afterwards, where they read the rival's damage (target 80%);
- how many open the card again from the pause menu (a sign it helped, not a failure);
- how many quit before the first finisher.

Orb's friend's words are the test: "I'm not sure what I'm supposed to do" should stop being said.
