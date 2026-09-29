# Public-readiness edits

Owner: Legal and IP Compliance. 2026-09-29. What must change before the repo goes public. Orb wants it public now, with MIT, CC BY 4.0 and the DCO. Legal cannot edit these files, so each edit is proposed for the EP or the owning director. **Must** means before the repo is public. **Should** means soon after. Not legal advice. Counsel should read the licence files, the README and the homage line before the switch.

Scan basis: tracked files at the current head, checked with `git grep`. The scan covered `README.md`, `CLAUDE.md`, `DIRECTORS.md`, `tools/gen_directors.py`, `docs/directors/`, `.claude/`, `docs/setup/`, `docs/ep/`, `docs/decisions/`, `docs/narrative/`, `prototype/index.html`, and `docs/legal/`. It looked for franchise and fan-game names, "Breakers", "KAI", gold-hair references, and internal-process text. Orb's private notes are in `.private/`, which is git-ignored, and never entered history (checked).

## 1. Rename the repo (Must)

**Recommendation.** Rename before flipping to public, so the old name is never indexed. Do not use "Breakers", "Meridian" (RL-001) or any franchise word.
- **If Orb picks a title within days:** rename once to the title's slug. From the screen so far, "skyburden" is unused on GitHub (0 repos).
- **If not:** rename now to a neutral descriptive slug, for example `wraparound-fighter` (0 GitHub repos found), and rename again at title lock. GitHub redirects the old address each time.
- Do not put a franchise word in the description or topics. Use "fighting game", "open-source", "godot" or "procedural".

**Steps** (EP or Orb, from the repo folder):
```bash
gh repo rename <new-name> --repo dixonbalsagna/Breakerslike
git remote set-url origin https://github.com/dixonbalsagna/<new-name>.git
```
Then edit the description and topics on GitHub, update `docs/setup/git-and-github.md` (section 3), and only then make the repo public in Settings. The local folder name is not public and can stay.

## 2. Proposed edits

### Must

| # | File and heading | Before | After |
|---|---|---|---|
| M1 | `README.md`, opening line | An original fighting game: a homage to Dragon Ball and a spiritual successor to the fan games "Lemming Ball Z" and "Lemming Ball Z 3d". Free and open source. Meridian is a placeholder name. | One of the lines in section 5, chosen by Orb. Then add: a Licence section (code MIT, content CC BY 4.0, link both files); a "How this is made" note (developed by Orb with AI assistance, Claude by Anthropic); a Trademarks line ("The game's name, logo and fighters' names are not licensed"). |
| M2 | `CLAUDE.md`, first paragraph | "...a homage to Dragon Ball and a spiritual successor to the fan games..." | Same wording as M1. CLAUDE.md is loaded by every session, so keep it accurate: "An original fighting game in the anime energy-brawler genre." |
| M3 | `CLAUDE.md`, "Open questions" list, "Lemming Ball Z provenance" | names the fan game | "Provenance of any material inherited from earlier projects." Legal's fan-game note stays in `originality-rules.md`. |
| M4 | `tools/gen_directors.py` (Tools owns), the EP mission line and the director intro line | "Hold the vision: Dragon Ball homage, original in every asset..." and "...an original fighting game that is a homage to Dragon Ball..." | "Hold the vision: an original anime-inspired energy-brawler..." and "...an original fighting game in the anime energy-brawler genre...". Then rerun `python tools/gen_directors.py`. This clears 24 charters and `DIRECTORS.md` at once. |
| M5 | `docs/setup/git-and-github.md`, all headings | `dixonbalsagna/Breakerslike` (5), the local path with the Windows user name (1) | The new repo name, and "<your project folder>" in place of the path. |
| M6 | Root | no licence files | Place `LICENSE`, `LICENSE-ASSETS`, `NOTICE` from `docs/legal/drafts/` (copyright holder filled in), plus `.github/CONTRIBUTING.md` and the PR template from `docs/legal/contributor-rules.md`. |
| M7 | Any hosted build, screenshot, GIF or devlog of the prototype | shows "Meridian" and "KAI" | Do not publish captures or a hosted build until the hero is renamed (RL-002) and the title is changed (RL-001). Source text is a Should (S4). |

### Should

| # | File and heading | Before | After |
|---|---|---|---|
| S1 | `docs/ep/playbook.md`, "Machine notes"; `docs/ep/handoff.md` (Godot path) | the local path with the Windows user name (2) | "the local Godot 4.7.2 install". Personal paths do not need to be public. |
| S2 | `docs/ep/handoff.md`, open questions | "Lemming Ball Z provenance" | as M3. |
| S3 | `docs/narrative/*` longlists (8 franchise mentions), `docs/ep/briefs/` (1 to 2 each) | Franchise names used to explain rejections | Keep. They are screening notes. Mention the franchise only as far as needed. Review before the first devlog links to them. |
| S4 | `prototype/index.html` (page title, overlay text, fighter fields), `qa/` | Meridian, KAI (3 in the prototype) | Rename with the hero and the title. QA files carry KAI in labels. Tools or QA own these. |
| S5 | `docs/legal/` | Franchise move names appear as examples of what not to use | Keep. This is the compliance record. Counsel may want them softened. |
| S6 | `README.md` and `CLAUDE.md`, process language | directors, sessions, EP, Orb (about 40 mentions across README, CLAUDE.md, DIRECTORS.md, playbook) | Fine to keep. It is honest about how the project is made. Add one README paragraph explaining it so a visitor is not confused. |

## 3. Counts

Tracked files outside `docs/legal/` (2026-09-29). "Dragon Ball" in the 24 charters is one line each.

| Term | Where | Count |
|---|---|---|
| Dragon Ball | 24 charters, `DIRECTORS.md` (1), `tools/gen_directors.py` (2), `README.md` (1), `CLAUDE.md` (1), `docs/narrative/*` (8), other docs (2) | about 40 |
| Lemming Ball Z | `CLAUDE.md` (2), `README.md` (1), `docs/ep/handoff.md` (1), briefs (2) | 6 |
| Breakers, Breakerslike, Breakers-Like | `docs/setup/git-and-github.md` (5), `docs/narrative/*` (3), briefs (1) | 9 |
| KAI | `prototype/index.html` (3), `qa/` (about 60), `docs/narrative/*` (7), `CLAUDE.md` (2), briefs (5) | about 75 |
| Windows user name in paths | `docs/setup/git-and-github.md`, `docs/ep/playbook.md`, `docs/ep/handoff.md` | 3 |
| Gold or golden hair | `qa/` tests, briefs, ADR 0004 | about 40 (test names and notes, no design) |

## 4. Git history

Making the repo public exposes every past commit. Facts: 14 commits, one author (a GitHub no-reply address, no personal email), no private notes ever tracked (`.private/` was ignored before it held anything), and no email addresses or private notes found by search (no secret scanner was run). Old commits contain the old README wording, the local paths and the gold-hair prototype.

| Option | Good | Bad |
|---|---|---|
| **A. Publish the history as it is** (recommended) | Keeps provenance and the record of who did what. Nothing sensitive is in it. Cheapest. | Old text stays visible, including the Dragon Ball wording in earlier README versions and the local paths. |
| **B. Start the public repo from a fresh history** | Clean first impression. The old wording never shows. | Loses the commit record and the `Co-Authored-By` lines that document AI assistance. Needs a new repo, and it breaks any existing links or forks. |

**Orb decides.** Legal's view: A is enough, because the history holds no private data and the old wording is a mild risk. Choose B only if Orb wants no trace of the earlier wording. Either way, do M1 to M6 first.

## 5. Describing the homage in public

**Rules.**
- No franchise names in the game's name, repo name, description, topics, tags or keywords.
- No franchise logos, artwork, screenshots or sounds anywhere.
- Describe the genre, not the show. If Orb wants to name an inspiration, say it once, factually, in an "Inspirations" note, not in the pitch line.
- "Not affiliated with any existing franchise" helps a little, and does not make a lookalike safe.
- Do not name the fan games in the pitch. Their names carry the franchise.
- Marketing and Legal review every public claim.

**Candidate README lines. Orb decides** (the EP forwards them to Marketing):
1. "An original arena fighter about two people flying around a wrapped planet and wrecking it. Inspired by the classic anime energy-brawlers."
2. "A free, open-source fighting game with no combo lists: pick a stance and the game choreographs the exchange. Made in the spirit of anime brawlers."
3. "Every fighter, move and planet here is original. The genre isn't: this is our love letter to sky-high anime fights."

## 6. Narrative's shortlist

- **Titles (Skyburden, Splendid Wreckage, Glorious Ruin):** screened, see `review-log.md` RL-016 to RL-018.
- **Other game names, hero names, longlist flags, glossary picks (closes RL-015) and place names:** not yet screened. Pending, after the items above.
