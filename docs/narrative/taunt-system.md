# The taunt system: lines that stay fresh

Owner: Narrative and Fighter Identity. Version 1, 2026-10-02. Answers the EP's brief from Orb's questionnaire 14 (`docs/ep/vision.md`). The shape of the data and a first batch are in `taunts.draft.json` and `voice-lab/taunts-draft.csv` (placeholders for Orb's edit; both are unwired). Lines are original and unsearched by Legal. Presentation only: nothing here writes sim state.

## 1. What Orb asked for

A press at range plays a taunt with a voice line and a face cut-in. In Orb's words: "standing far apart and spamming taunts is the minimum acceptable, especially if there are reactive voice-lines, bonus points if those lines keep feeling fresh even if they spent all day."

So three things have to be true:

1. **Reactive.** The line is about *this* fight: who the opponent is, who is ahead, what just broke.
2. **A conversation.** Two fighters taunting each other should sound like an exchange, not two radios.
3. **Fresh for a long time.** A player who stands still and presses the button for an hour should keep hearing new things, or at least things that make the repetition part of the joke.

Whether a taunt feeds a meter, and what holding the button does, are Game Design's (an earlier ruling says taunts feed meters; Orb did not pick it again in questionnaire 14). The system below works either way.

## 2. Where a taunt sits

| Moment | What happens | Narrative's part |
|---|---|---|
| **Press at range** | The fighter plays the taunt gesture for about 1 s (the gesture is each fighter's own; never a beckoning one, Legal). | The director picks a line (section 4) and the UI shows the speaker's face. |
| **Press again, fast** | A press during the gesture does nothing. A press right after it starts the next taunt. | The *tempo* between presses picks the line's length (section 4.3). |
| **Hold attack through the taunt** | The taunt ends in a take-off at max speed (Orb's idea). | A short `takeoff` line, said as the fighter goes. |
| **The other fighter taunts back** | Both are now in a taunt exchange. | Call and answer (section 5). |
| **An exchange starts (a hit lands, either way)** | The stand-off ends. | The ladder resets (section 6). |

Taunt lines are priority 3 (they always get a face), kind `line`, display `caption`, about 1.4 s. A line may keep playing after its gesture ends, and is never cut by a later taunt, only by a shout or a finisher.

## 3. What a line can react to: the context

The director keeps a small, plain **context** per taunt, read from events and state it already gets. Every facet is optional, and most lines name one or two.

| Facet | Values | Where it comes from |
|---|---|---|
| `vs` | protagonist, anti_hero, empress, cyborg (and the placeholders) | the opponent's fighter id |
| `standing` | ahead, behind, even (within 10% of health) | both fighters' HP |
| `event` | crater, building, guard_down, region_break, beam_clash, launch, transform, brink, hit_taken | the last big event in the last 8 s (the sim's events, the same ones the bark director reads) |
| `wound` | opp, self (and which `{part}`) | the wounds state: a broken region |
| `tier` | opp_higher, self_higher, equal | power tiers |
| `biome` | ocean, harbour, plains, city, village, forest, desert, mountains | the place under the fight (`places.md`) |
| `collateral` | none, some, many | casualties and structures lost this match |
| `streak` | 1, 2, 3 ... | taunts in a row by this fighter since an exchange began (section 6) |
| `standoff_count` | 1 ... 500 | taunts by both fighters this stand-off |
| `taunted_back` | true, false | the other fighter taunted in the last 3 s (section 5) |
| `tempo` | mashed, paced | the gap since this fighter's last taunt (section 4.3) |
| `guard` | alive, gone | the Empress's guard of honour |
| `style` | turtle, rusher, runner, charger, sniper, mixer | the player-style label (`style.draft.json`) |

`streak`, `standoff_count`, `taunted_back` and `tempo` are counted by the director from the sim's taunt and hit events (presentation state, never fed back). The rest already exist.

## 4. How a line is picked

Three tiers, tried in order. Each is deterministic (section 9).

1. **Answer.** If the other fighter's taunt ended in the last 3 s and carried an `opens` tag, an answer line (`replies_to` contains that tag) is strongly preferred (section 5).
2. **Whole line.** Every authored line that passes its `when` is a candidate. A line's score is **specificity** (how many facets it names, each weighted) times **ladder fit** (the rung, section 6) times **novelty** (section 7) times a small seeded jitter. A **topic cooldown** stops two taunts in a row from reacting to the same facet, so a fighter does not talk about the crater five times. A **generic floor** (20%) lets an unreactive line win now and then, so reactions do not become a tic.
3. **Composed line.** When the best whole line scores low, or the tempo is paced and a longer taunt fits, the director builds a line from parts (section 8).

A milestone (section 6) overrides all three on its exact count.

### 4.3 Tempo: mashing and pacing

- **Mashed** (the gap since the last taunt under 1.4 s): only short forms of 3 words or fewer, or a one-part hook or jab. Fast presses get fast quips, and nothing gets cut off.
- **Paced** (2.4 s or more): any whole line or composed line, up to about 12 words.
- In between: either, whichever scores better, with a one-part composed line preferred.

## 5. Call and answer

Each line may carry an **`opens`** tag (what it offers) and an **`replies_to`** list (what it answers). The tags are few and plain: `dare`, `needle`, `pity`, `stall` (and `boast`, `wager` later).

- When A taunts, the line's `opens` tag goes into a 3-second window. If B taunts inside the window, B's pick is made from lines whose `replies_to` has that tag. If there is none, the director falls back: `stall` and `boast` count as `needle`.
- **Answers are authored per fighter**, in that fighter's way. Three per fighter in the batch (`dare`, `needle`, `pity`). A matchup can add its own pair-specific answer later, which beats a generic one.
- A thread lasts up to **4 beats** (A, B, A, B), then drops back to the ladder with the streak intact, so the exchange never swallows the stand-off.
- **The face cut-in alternates** with the speaker, so the player sees the two faces trade.
- An answer is never forced. If B does not taunt, nothing is lost.
- If B is the AI, the AI director decides whether to answer and how fast (a request to the AI lane, not a rule here).

**An example** (Protagonist against the Anti-hero, all lines from the batch):

> Protagonist (`dare`): "Come on. I've got all day."
> Anti-hero (answer to `dare`): "I do not come when called. I arrive."
> Protagonist (`needle`): "Still smiling. Still here."
> Anti-hero (answer to `needle`): "Insult me better. You were better."

And the Cyborg against the Empress: "Welcome. Do take a seat. Any seat." (`dare`), then "We do not go to petitioners. Petitioners come to us."

## 6. Escalation ladders

A repeated taunt should not stay in one voice. Each fighter climbs a ladder as the stand-off goes on, and the pool of lines changes with the rung.

| Rung | `streak` | The register |
|---|---|---|
| 1 | 1 | An invitation: easy, in character. |
| 2-3 | 2 to 3 | Needling: the first sign of impatience. |
| 4-6 | 4 to 6 | Theatrical: the fighter plays to the crowd and the guard. |
| 7-12 | 7 to 12 | Weary and meta: the stand-off itself is the joke. |
| 13+ | 13 and up | A very long stand-off: the fighter is now part of the scenery. |

**Milestones** are one-off treats at `standoff_count` 10, 25, 50, 100, 250 and 500 (an authored line per fighter at each, once per stand-off, and once per match). They are what an all-day player earns: a line that is only ever heard by someone who kept going. The batch has 10, 25, 50 and 100; 250 and 500 come after Orb's pass.

**Reset.** An exchange (any hit landed, either way) ends the stand-off and resets `streak` and `standoff_count` to zero. A second stand-off in the same match starts from rung 1, but the director remembers it: a few lines react to `standoff_number` ("Back to talking?"), so a long match is not an endless first date.

**Being taunted back does not reset the ladder.** Two fighters trading taunts climb together, and the rungs are by each fighter's own streak, so the two rarely sit on the same rung. That makes the pair sound uneven in a natural way.

## 7. The no-repeat memory

The director keeps three layers, each cheap.

1. **The match ring.** The last 40 taunt ids are not eligible. A composed line's parts have their own cooldowns: a **jab** is out for 25 taunts, a **hook** for 12, a **tag** for 3.
2. **The topic cooldown** (section 4): the last 2 reaction facets are not eligible again.
3. **Cross-match seen memory** (`dialogue-director.md` section 3.3, the same local file): a line's score is multiplied by 1 / (1 + seen_count), and half the penalty fades after about 30 matches. Milestones and answers are never suppressed when they are the only fit.

**When the pool runs dry** (every eligible line was used recently), the director does not repeat a line. It moves *up the ladder* to the next rung's pool, then to the composed tier, and finally to a **fatigue** line (an admission that the fighter has run out of material, like the Empress's "We have run out of insults. A first. File it."; the batch has a few on the 7-12 and 13+ rungs, and Orb's pass will say if they are wanted). A fighter who admits he has run out of material is a fresh line, and it makes the repetition part of the character. After a fatigue line, the cooldowns are halved for 10 taunts, so a few lines can return.

## 8. Combinable parts

A composed line has up to three parts: **hook + jab + tag**.

| Part | What it does | Example |
|---|---|---|
| **hook** | Reacts to the moment. One short, complete sentence, often a facet (a crater, a guard). | "That was a nice crater." |
| **jab** | The fighter's voiced barb or invitation. It works after any hook. | "Do you want a turn?" |
| **tag** | An optional sign-off, one or two words, in the fighter's habit. Used about half the time. | "Friend." / "Filth." / "Petitioner." |

Joined with a space: *"That was a nice crater. Do you want a turn? Friend."*

**Rules that keep it from reading as assembled:**

- Every part is a **complete sentence** (or one word, for a tag) so any join is grammatical.
- A part declares its `register` (warm, contempt, polite, boast, pity). A jab and hook only combine if their registers are compatible, so a warm jab never follows a contemptuous hook.
- **Voice rules are in the parts**, never in the joiner: the Anti-hero's parts have no contractions, the Empress's use the royal "we".
- A hook that is tied to a facet only appears when that facet is true (the crater hook needs a crater), so the hook is where the reaction lives.
- At most one part per line with an ellipsis, and none that end on the same word as the previous part.

**The count** (an honest estimate). At ship, per fighter, I would aim for about 16 hooks, 18 jabs and 8 tags, so 16 x 18 x about 0.6 compatible = about 170 two-part lines, and with tags about 860. Add about 230 whole lines (the ladder, the reactions, the answers, the milestones, the short forms): **about 1,100 distinct strings per fighter**. The first batch has only 3 hooks, 3 jabs and 2 tags per fighter, which is enough to show the mechanism and nothing more.

Players notice a *jab* returning long before a whole string, so jabs and hooks are what a writer should add first.

## 9. The data shape (deterministic)

The full draft is `taunts.draft.json`. A line:

```json
{
  "id": "tnt-ant-017",
  "fighter": "ANTIHERO",
  "tier": "whole",
  "family": "react",
  "text": "A fine hole. You dug it. You will lie in it.",
  "words": 11,
  "when": { "event": "crater" }
}
```

A ladder line that offers a call adds `"opens": ["dare"]`, and an answer line carries `"replies_to": ["dare"]` and `"when": { "taunted_back": true }`.

- `tier` is `whole`, `hook`, `jab` or `tag`. `when` holds the facets above (a rung is `"4-6"`, a count is `"standoff_count": 25`).
- The file also carries the tunables: the ladder rungs and milestones, tempo thresholds, cooldown lengths and score weights, so Orb or Game Design can retune without code.

**Determinism.** The director uses its **own seeded stream** (the match seed plus the taunt's index), the same rule as `dialogue-director.md` section 5, and reads only sim events and state. A replay shows the same taunts. In online play each client picks its own lines; the stand-off counters are derived from the shared event stream, so they match.

## 10. Will it stay fresh all day?

**Honestly: no system with authored lines lasts forever, and I will not claim it does.** One taunt is about 2.4 s when paced, so an hour of pure taunting is about 1,500 lines against about 1,100 strings per fighter. What the design promises:

- **No repeat inside 40 taunts**, no jab inside 25, which is several minutes of continuous taunting before a player could notice a line returning.
- **Reactions change the line** even when the jab is the same, because the hook is new.
- **The ladder keeps moving**, so a long stand-off sounds different at minute 5 than at minute 1.
- **Milestones** at 10, 25, 50, 100, 250 and 500 reward the player who keeps going, and the 13+ rung and the fatigue lines make the repetition part of the joke.
- **Across matches** the seen memory pushes the director toward lines the player has not met.

A day-long marathon will hear repeats; they will be spaced, wrapped in new hooks and, at the end, acknowledged by the fighter. Writing more hooks and jabs is the cheapest way to raise the number.

## 11. What I need from others

- **Simulation:** `taunt_start` and `taunt_end` events carrying `actor` (and `kind`: `finished` or `takeoff`), so the director can count a stand-off and play the `takeoff` line. The hit events it already sends end a stand-off.
- **Game Design (controls):** confirm that a taunt takes about 1 s and that a press during it does nothing, and that holding attack through it ends in a take-off. Whether a taunt feeds meters.
- **UI:** a face cut-in per taunt (priority 3), alternating between the two faces in an exchange. No counter is needed; if Orb wants a visible tally of taunts, that is a UI question.
- **AI (director AI):** an AI fighter may taunt and answer on the same ladder; its pacing is the AI lane's.
- **Audio:** the short forms are one-clip lines; tell Audio's babble that a taunt line is about 1.2 s.
- **Legal:** an exact-phrase search on the batch once Orb's edits are in; no line tells the opponent to beckon, and no franchise phrases.

## 12. Questions for Orb (short)

1. Is the **stand-off being the joke** (weary and fatigue lines, "I have nothing left") what you want, or do you want the fighters to stay in their usual voice however long it goes?
2. **Milestones at 10, 25, 50, 100**: a nice reward, or too cute?
3. Should answers be **automatic** when the other fighter taunts, or optional (the current design)?
4. Do you want a **visible count** of taunts, or only the lines?
5. When a hit lands, should the **stand-off reset completely**, or should the fighters carry some of it into the fight (they do a little now: a few lines remember it)?

## 13. The first batch

`voice-lab/taunts-draft.csv`, 160 lines (40 per fighter for the four launch fighters; KAI and VORR are placeholders and are skipped). Same columns as the rest of the packet. Each line's `situation` starts with the mechanism it shows:

| Prefix | What it shows | Per fighter |
|---|---|---|
| LADDER 1 to 13+ | the escalation ladder | 10 |
| MILESTONE | the one-off treats | 4 |
| REACTS TO | the facets: standing, crater, collateral, wounds, tier, biome or guard, and the opponent | 11 |
| ANSWER | call and answer (to a dare, a needle, a pity) | 3 |
| TAKEOFF | the take-off line | 1 |
| MASHED | short forms for fast presses | 3 |
| PART hook, jab, tag | combinable parts | 8 |

The existing taunt lines in each fighter's own CSV (the four they say in the gesture second) are the base pool; these do not replace them. Edit these as you would the rest, and tell us which mechanism you like and which is too clever.
