# The plan: a pre-match upgrade draft

Owner: Game Design. Orb picked option C from `pitches.md` §6 (questionnaire 10): each player drafts three picks before the match, and they switch on by stage. "The plan" is a working name for Narrative. It is not in the next build: it needs the transform and the acts first.

## 1. How it works

1. **When.** At match setup, after the fighter and loadout are chosen.
2. **Three rounds, pick one of three.** Each round shows three cards, and each player picks one.
3. **The same three cards for both players.** The offer is shared, and both players may pick the same card. That makes the draft fair by construction, and it fits one screen in local play.
4. **Rounds 1 and 2** offer stat and movement cards. **Round 3** offers the rarer special cards.
5. **Switching on.** The round-1 pick comes online at act 2, the round-2 pick at act 3 and the round-3 pick at act 4. Acts follow the transformations (`spec-wounds.md` §8b), so the picks arrive at about 1:30, 3:15 and 5:00: short early phases building to the peak. Both players' picks come online at the same moment.
6. **Open information.** Both plans are shown before the match starts, and as icons under each portrait during it.

## 2. The pool

A starting list. The cards are data (`data/fight/plan.json`), and each fighter can add cards of their own later.

| Kind | Card (working name) | Effect |
| :--- | :--- | :--- |
| **Stat** | Might | +8% damage |
| | Reserve | +15 to the ki cap |
| | Wellspring | +1 ki a second |
| | Thick Skin | A held guard takes 10% less |
| | Iron Core | The core takes 8% less wear |
| | Deep Breath | Second breath starts 1 s sooner |
| **Movement** | Tempo | +6% speed |
| | Slip | Dodge-cancel cooldown 3 s down to 2 s |
| | Quick Break | Burst cooldown 8 s down to 6 s |
| | Afterburn | Sprint 15% faster |
| | Closer | A rush closes 15% faster |
| | Anchor | Knockback slides 20% shorter |
| **Special** (round 3 only) | Fourth Slot | A fourth special from the fighter's pool, for this match |
| | Short Fuse | Signature cooldown 120 s down to 90 s |
| | Cheap Burst | A burst costs 20 ki, not 30 |
| | Grudge | After surviving a finisher: +10% damage for 15 s |
| | Sharp Read | The riposte window after a perfect block is 45 ticks, not 30 |

The offer for each round is drawn from the match seed, so replays and online play agree. Round 1 always shows at least one stat and one movement card.

## 3. The limits

- **Small.** No card is worth more than +10% of a stat, or more than one rule tweak.
- **No stacking.** A player can't take two cards on the same stat.
- **Off limits.** No card touches the wear stages, the brink, the finisher contest, Rally, the perfect-block window, or collateral.
- **Balance.** Every pairing stays inside 45 to 55% with the plan on and with it off. QA runs both.
- **Nothing is locked.** Every card is in the pool from the start (questionnaire 3). Cards are never unlocks.
- **Optional.** A "Plan: on or off" switch at match setup. It is on by default against the AI and in Arcade, and it is the players' choice in Versus.

## 4. The screen flow

1. **The plan screen** follows the loadout screen. It shows the round number, the three cards (a name, an icon and one line each), and an 8 s timer.
2. **Both players pick at once,** each with their own cursor. A pick locks when made, and the round ends when both have picked or the timer runs out. A timeout takes the first card.
3. **A strip under each fighter** fills with three icons as the rounds go. The whole draft takes 25 s at most.
4. **"Quick plan"** picks all three for a player at once, using the AI's choice for that fighter. The AI opponent always drafts this way.
5. **Before the fight starts,** both strips show side by side for 2 s.
6. **In the match,** the three icons sit under the portrait, dimmed. At each act change the next icon lights with a short sting and a one-line call-out. It runs live, with no pause.
7. **The pause menu** lists both plans with their text.
8. **On touch,** cards are tapped. The layout is one column of three.

The picks are stored in the replay header with the match seed.
