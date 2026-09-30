# Voice lab: batch 1 (the Protagonist)

Owner: Narrative and Fighter Identity. Version 1, 2026-09-30. For Orb.

**What this is.** About 150 draft lines for the Protagonist, written in his voice, in the raw way an AI writes them by default. **They are not polished, and they are meant to be edited by a person.** You can spot AI-written dialogue on sight, so we want your edits. We will analyse what you change into style rules, a list of banned patterns, and an automatic check, so the game's lines stop sounding written by a machine.

**Do not be kind to them.** A line that is fine but not you is still worth rewriting. A line that is wrong is worth cutting. The more you change, the more we learn.

## What to do

1. Open `batch-01-protagonist.csv` in Excel (or any spreadsheet). It has a BOM, so accents and quotes open cleanly.
2. Each row is one line. The columns are:

| Column | What it is | Who fills it |
|---|---|---|
| `id` | A stable id. Do not change it. | (given) |
| `category` | What kind of line: threat, boast, one-liner, banter reply, inner thought, style reaction, pain and injury, comeback and rally, transformation, finisher, win, loss, collateral and anguish, taunt response. | (given) |
| `situation` | What is happening when he says it. | (given) |
| `opponent` | Who he is fighting: Anti-hero, Empress, Cyborg or any. | (given) |
| `draft` | The line as the AI wrote it. | (given) |
| `orb_version` | **Your rewrite.** Say it the way you would. It can be shorter, longer, weirder, one word, or a different idea. | **You** |
| `verdict` | **keep**, **rewrite** or **cut**. | **You** |
| `note` | Optional. Why, in a few words ("too neat", "he'd never say that", "funny"). | **You** (optional) |

3. For each line, do **one** of these:
   - **Keep it:** set `verdict` to `keep`. Leave `orb_version` empty.
   - **Rewrite it:** put your version in `orb_version`, and set `verdict` to `rewrite`. (If you fill `orb_version`, we treat it as a rewrite even if you forget the verdict.)
   - **Cut it:** set `verdict` to `cut`. Nobody will say it.
4. Add a `note` if you have a reason. Notes are gold, even short ones like "boring" or "this is a movie line".
5. **Save in the same format.** In Excel, choose Save As, then **CSV UTF-8 (Comma delimited)**. Keep the same file name and columns, and do not add, delete or reorder rows. Then tell the EP, and the EP will pass it on.

## How long it takes

- A **fast pass** (keep or cut only, no rewrites): about **15 minutes**.
- A **full pass** (rewrite most lines): about **45 to 60 minutes** for 150 lines. Splitting it into two sittings works well, and a batch does not have to be finished at once. Send whatever you have done.

## What we will do with it

- Compare each `draft` with your `orb_version` to find what you keep changing: words, rhythm, length, tone, jokes, structure.
- Write **style rules** for the Protagonist ("he says X, never Y") and a **banned-patterns list**.
- Build an automatic **lint check**, so new lines are tested against your rules before you ever see them.
- Send you a second batch, better and shorter.

## Notes

- The lines mix new drafts with a few from the earlier voice bible, and they are not marked. Treat them all the same.
- Some lines may be bad on purpose to test us. They are not. Every line is a real attempt.
- No franchise names or catchphrases appear in these lines. If one sounds familiar, cut it and say so in the note.
