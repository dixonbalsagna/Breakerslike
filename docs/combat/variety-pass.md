# Variety pass

Owner: Combat and Choreography. Implementation: Encounter Systems. Numbers: Game Design. Date: 2026-09-30. Status: design, with data in `data/combat/styles.json` (not read by the sim until Encounter's style slice).

**Orb** (`docs/ep/vision.md`, questionnaire 4): "I liked the faster fight pace. Now I want to see cleaner combos, more teleport clashing, stylistic flying combat, heavy ground combat, energy blasts, more varied beam struggles."

**The control split** (questionnaire 4, pillar 2):
- **The player chooses:** stance, movement, attack weight (light, heavy or signature, queued), charging, transformations and specials.
- **The director chooses:** *when* to attack, the combo, the tactics and every timing outcome. Parry and the finisher struggle are no longer player presses; Game Design is redesigning them as director rolls.

This pass is written for that split. The player's intent picks the template and its outcome (`stance-matrix.md`, `exchange-templates.md`); the director picks *how it looks*.

---

## 1. The shape of the change: styles over outcomes

**Templates stay the judge.** Stance × attack kind × defender state picks the template, and its selector picks the branch: who wins, what is decisive, which windows open. Nothing in this pass changes an outcome, a tag or a selector's draws.

**A style is the choreography chosen for that outcome.** After the branch is chosen, the director scores the styles whose gates pass (section 3) and applies one. A style is a small **overlay** on the branch's `dynamic` beats:

| Slot | What a style can change | Example |
| :--- | :--- | :--- |
| `approach` | the first rush: its path (straight, arc, along the ground, a blink) | aerial: an arcing dive; blink: vanish and reappear |
| `contacts` | every strike: extra `o` flags and a cue | ground: double knockback with a skid cue |
| `between` | beats inserted between contacts | aerial: a swoop to the other side; blink: a vanish-reappear |
| `decider` | the strike just before the branch's launch | ground: a stomp that dents the ground |
| `prelude` | beats that replace everything between the approach and the decider; later beats shift to fit | blink clash: three mid-air meets before the decisive one |
| `launch` | a hint to the launch planner (Encounter scores it) | ground: a short slam or a throw along the ground |
| `pursuit` | the chase after the launch | aerial: a cross-sky arc |

Each style is the same small set of authored parts, reused across every template it applies to. That is procedural-moves stage 2 in practice: styles are the first generative slot, and parts are still authored.

---

## 2. The six asks

### 2.1 Cleaner combos
**The problem today.** Every chain link is the same shape (a 0.24 s rush, a strike, a launch, a window), at a random cadence: the AI presses 0.12 to 0.35 s into the window. A long chain reads as launch, catch, launch: mush.

**The design: a chain is a phrase.** It has an opener, links on a fixed beat, and one ender.
- **Planned by the director.** At the first chain window, the director decides the chain's length, with one draw. It uses the mood's aggression (section 3): cool 1 to 2 links, warm 2 to 3, heated 3 to 4. It is also capped by ki (6 per link) and at 5 hits in all. No press is needed.
- **A fixed rhythm.** Links land 18 ticks (0.3 s) apart, so the player hears and sees the count.
- **Distinct links.** Each link's strike cycles a shape cue (`link_knee`, `link_elbow`, `link_kick`), so no two consecutive links look alike. Styles can swap the pursuit, for example an aerial *relay* that overtakes the flying body and strikes back.
- **One ender.** The last link is the chain's finishing blow: a heavier strike (`chainStrike` with `ender`), a long-only launch (`breakLaunch`), the `chain_ender` cue and the CHAIN ×N banner (Narrative's label). Every chain ends on a clear full stop.

### 2.2 Teleport clashes
**The blink clash:** a style for HEAVY CLASH and aerial TRADE BLOWS.
- **Heavy clash.** Both fighters vanish from the approach and reappear meeting in mid-air. Fists and forearms meet (`blink_meet`: a spark, no damage), they vanish again and reappear at a new angle (above, behind, below). After three meets, the decisive meet plays the branch's outcome: WON, COUNTERED or SHOCKWAVE.
- **Trade blows.** Each of the four exchanged blows lands at a new blink position (a vanish-reappear trade), then the fighters meet for the decider.
- **Every blink shows the air-ripple tell** at departure and arrival (`blink_out`, `blink_in`). It is canon for the Protagonist and is kept for everyone, so blinks always read.
- **Gates:** both fighters airborne (low or high air), and not underwater. **Weights:** higher when both are AGGRESSIVE, when the mood is heated, and for fighters with the `blink` trait (the Protagonist; the KAI placeholder has it).

### 2.3 Flying combat style
**Aerial:** a style for every melee template when both fighters are airborne.
- **Approach:** an arcing dive (`rush` with `arc`), coming in from above when the attacker is higher.
- **Between contacts:** a swoop to the far side or above (`rush` with an arc and a vertical offset), so blows come from new angles.
- **Decider:** a dive strike (`dive` cue).
- **Launch hint:** across or up.
- **Pursuit:** a cross-sky arc (0.5 s, a high arc) instead of the straight chase. In chains, the *relay*.

### 2.4 Heavy ground combat
**Ground brawl:** a style for every melee template when both fighters are on the ground (within 140 u of the surface) and over land.
- **Approach:** a skid along the ground (`rush` with `ground`), raising dust.
- **Contacts:** double knockback, so the struck fighter slides (World's knockback slides) with a `skid` cue.
- **Decider:** a stomp or ground slam that dents the ground (`o.crater`, small: World's crater rules keep big craters for special blows).
- **Launch hint:** a short slam into the ground, or a throw along it (slide and bounce).
- **Pursuit:** a ground dash.
- **Weights:** higher for heavy attacks, DEFENSIVE defenders (the guard shoves into slides), and fighters with the `brawler` trait.

### 2.5 Energy blasts
Small ki volleys between beams. Three uses:
- **Volley opener.** When the gap is over 1,200 u, the attacker fires 3 blasts during the approach instead of a silent pursuit flight. The approach still closes (pillar 3); the blasts land or are shrugged off as the defender's stance allows.
- **Barrage.** A style for PRESSURE (light against DEFENSIVE): the pressure string becomes a barrage of 5 blasts into the raised guard, then the guard shove.
- **Contemptuous poke.** When a fighter with the `volley` trait is in a cocky or contemptuous mood, a light at range becomes a volley-only exchange. This is the Anti-hero's style: barrage until the foe submits. Its volume scales with Pride once meters are in the roster data.

**Resolution follows the branch.** Blasts land on an attacker-favoured branch, are guarded (stance multiplier) on DEFENSIVE, and are evaded (a sidestep afterimage, no damage) on an EVASIVE win.
- **In the sim**, a blast is a scheduled impact: its arrival tick plus a strike. The projectile is render-only (an fx event with origin, target and travel ticks), so there are no new sim entities.
- **Blasts that miss** strike near the target's feet, with the ordinary area damage.

### 2.6 More varied beam struggles
The beam clash gets six shapes. The shape comes from the **margin** between the two clash scores the code already draws, plus context. There are no new draws.

| Shape | When | What happens | Favours |
| :--- | :--- | :--- | :--- |
| **Breakthrough** | margin 20 or more | the weaker beam fails fast: a 0.8 s overpower | winner |
| **Overpower** (today's) | margin 10 to 20 | the push drifts steadily to the loser; the winner's beam drives through | winner |
| **Seesaw** | margin 4 to 10, or a heated mood | the push swings back twice before resolving, over 2.4 s | winner |
| **Deflect** | margin 6 or more, the winner airborne | the winner angles away and deflects the loser's beam: skyward for a carer (`care` above 0), into the nearest settlement for a villain. The deflected beam carves where it goes; the loser is pushed back and pays ki, with no big hit | winner |
| **Split** | margin under 4, the meeting point within 300 u of the ground | the beams bend around each other and carve twin trenches to either side (Orb's friend: "love when they carve a trench"); chip damage to both | neutral |
| **Mutual blast** | margin under 4, in the air | the meeting point detonates: both fighters are launched apart and take damage; a crater if it is low | neutral |

When several shapes qualify, the first in this priority order wins: breakthrough, then deflect, split or mutual blast (by position), then seesaw, then overpower. The `game.clash` render state gains the shape and its keyframes (reversal times, the split angle), so Rendering and VFX can draw each shape.

---

## 3. Context selectors

| Selector | Source | Used by |
| :--- | :--- | :--- |
| **Altitude band** (both fighters) | submerged (over the sea, y below −60); ground (under 140 above the surface); low air (140 to 600); high air (600 and up) | aerial and blink need both fighters airborne; ground needs both on the ground over land; split needs the meeting point low |
| **Terrain and biome** | land or sea under each fighter; structures in range; slopes | ground brawl only on land; ground throws toward structures (World's brunts) |
| **Stance** | the attacker's and the defender's stance at exchange start (frozen, as for damage) | blink weight (both AGGRESSIVE); ground weight (a DEFENSIVE defender); barrage (light against DEFENSIVE) |
| **Mood aggression** | Narrative's fight-mood model: `aggression = clamp(0.6·rivalry_heat + 0.4·max(0, momentum), 0, 1)`. Bands: cool below 0.35, warm up to 0.7, heated above | chain length; blink and seesaw weights; "more blitzes when heated" (Orb) |
| **Attack weight** (queued by the player) | light, heavy, signature | ground favours heavy; volleys favour light at range; signatures lead to beam shapes |
| **Distance** | the shortest-arc gap at the request | volley opener over 1,200 u; pursuit flights over 2,500 u |
| **Fighter traits** (roster data, D1) | `blink`, `volley`, `brawler`, `aerial` | weights: the Protagonist blinks; the Anti-hero and the Empress volley; the Cyborg brawls |

**How a style is picked:**
1. Filter the styles by their gates.
2. Multiply each weight by its matching factors.
3. Make one draw from the composition stream (`procedural-moves.md` section 10: keyed by seed, exchange and slot, so adding a style changes only the exchanges it could apply to).
4. If no style passes, play the plain `dynamic` beats.

---

## 4. Cues for Rendering and VFX
These are new names in the cue vocabulary (`data/combat/finishers.json` `cues`). The render and audio consumers map them to poses and effects. They are render-only: the sim just emits them.

| Cue | Look (for Rendering, VFX and Audio to design) | Priority |
| :--- | :--- | ---: |
| `blink_out`, `blink_in` | the air ripple at departure and arrival, and a short afterimage | 1 |
| `blink_meet` | two fighters snapping together in mid-air; a fist and forearm spark | 1 |
| `chain_ender` | the chain's full stop: a heavier impact flash, the CHAIN ×N banner | 1 |
| `clash_seesaw`, `clash_split`, `clash_deflect`, `clash_mutual`, `clash_breakthrough` | the beam-struggle shapes (drawn from `game.clash.shape` and its keyframes) | 1 |
| `volley_fire`, `blast_hit`, `blast_guard`, `blast_evade` | small energy bolts: muzzle flash, impact puff, a swatted-away spark, a sidestep afterimage | 2 |
| `barrage` | the volley's sustained stance (arm or arms firing), for barrage and poke | 2 |
| `dive`, `swoop` | aerial poses: a head-down dive, a banking swoop with a trail | 2 |
| `skid`, `stomp`, `ground_slam`, `ground_throw` | ground poses: dust skid, a stamping foot, a two-handed slam, a hip throw | 2 |
| `link_knee`, `link_elbow`, `link_kick` | chain-link strike shapes (distinct silhouettes) | 3 |
| `relay` | the aerial chain's overtake-and-strike-back | 3 |

---

## 5. What Encounter must code

| # | Code | Notes |
| :--- | :--- | :--- |
| 1 | **The style applier.** After `_select`, score the styles in `styles.json` (gates, weights, one composition-stream draw) and transform the branch's `dynamic` beats by the overlay slots in section 1 | This is the one new mechanism. Slot identification: the approach is the first `rush` at tick 0; contacts are `strike`s; the decider is the last strike before a `launch` in the branch; the pursuit is the `rush` or `finRush` after it |
| 2 | **`rush` arguments:** `arc` (the height of the path's midpoint, a quadratic curve), `offY` (vertical offset at arrival), `ground` (hug the terrain and emit skid dust) | Backward-compatible: absent arguments keep today's straight path |
| 3 | **The `blink` op:** `{w, rel, dist}`. W teleports to a slot relative to the other fighter (`above`, `behind`, `below`, `front`), or both meet at the midpoint (`w: "both", rel: "meet"`), with the ripple fx at departure and arrival | No RNG: slots come from the data, cycling in order |
| 4 | **The `volley` op:** `{w, count, gapTicks, travelTicks, dmgEach, result}`. It schedules one arrival strike per blast (`result`: `land`, `guard` or `evade`), and emits the render-only projectile fx | No sim entities; blasts are not parryable |
| 5 | **`strike` `o` flags:** `kbMul` (knockback multiplier) and `crater` (`{radius, depth}` at the contact point, through World's crater rules) | Ground brawl |
| 6 | **The chain plan.** At the first window the director decides the length (mood aggression, ki, cap; one draw). Links start a fixed `linkGapTicks` after each window, with no press delay; the last link plays the `ender` beats | Replaces the AI chain-press policy for both fighters (director-owned timing, questionnaire 4) |
| 7 | **Beam-clash shapes.** `startClash` and `clashResolve` pick a shape from the score margin and context (section 2.6), set `game.clash.shape` and its keyframes, and resolve by shape: deflect fires the loser's beam on the deflected path, split fires two veering beams, mutual blast detonates at the midpoint | The draws are unchanged: the two clash scores |
| 8 | **Mood aggression as an input.** Expose Narrative's `rivalry_heat` and `momentum` to the director, read-only, or compute an equivalent from the sim's events. The dialogue director must stay read-only | Director aggression rising with heat is Orb's ask |
| 9 | Keep `cue` emission for every new beat, and add the new cue names to the fx hash map | Rendering maps them |

**Staging:**
1. Rows 1, 2 and 5: ground and aerial. They are cheap and change the most frames.
2. Rows 3 and 6: blink and clean chains.
3. Row 4: volleys.
4. Row 7: beam shapes.
5. Row 8 whenever the mood feed is ready. Until then, use `momentum` from decisive results as the stand-in.

---

## 6. How we will know it worked
QA's feel probe (`qa/godot/feel/`) plus a style census from the structured event log:
- **Variety:**
  - every style fires in its context;
  - no style is above 45% of melee exchanges in the default arm;
  - each beam shape at least 5% of clashes (breakthrough and mutual blast at least 3%).
- **Clean combos:**
  - every chain of 2 or more ends on an ender;
  - links on a fixed 18-tick rhythm;
  - no two consecutive links with the same shape cue.
- **Feel holds:** the dynamic-feel targets still pass (melee idle at most 15%, still stretch p90 at most 0.5 s).
- **Orb plays it.** "Never the same series twice" (procedural-moves T4) gets its first real test.

## 7. Open for others
- **Game Design:** volley and barrage damage (placeholders in `styles.json`); split and mutual-blast chip damage; the deflect ki cost; the director's parry and struggle rolls (their redesign).
- **Narrative:** the CHAIN ×N label is theirs; the mood model's aggression feed.
- **World:** small stomp craters within the new crater rules; ground throws that slide.
- **Tools:** a schema for `data/combat/styles.json`. A draft is in `docs/combat/schemas/combat-styles.schema.json`, for Tools to move into `tools/schemas/` and register.
