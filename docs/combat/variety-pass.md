# Variety pass

Owner: Combat and Choreography. Implementation: Encounter Systems. Numbers: Game Design. Date: 2026-09-30. Status: design, with data in `data/combat/styles.json` (not read by the sim until Encounter's style slice). Section 9 lists what the control scheme in ADR 0008 changes. Folds in Game Design's Q4 redesign (`stance-matrix.md` R4, R5 and R9; `spec-wounds.md` sections 1 and 9) and Encounter's Q4 plan (`docs/director/q4-director-control-plan.md`).

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
- **Decided by the director at each window** (R9, Encounter's Q4 plan). One draw against `chainP` replaces the attacker's press. `chainP` comes from the stance and the mood band (`styles.json` `chains.chainP`):
  - AGGRESSIVE: Calm 0.55, Tense 0.7, Frenzied 0.85;
  - DEFENSIVE: 0.25, 0.35, 0.5;
  - EVASIVE: 0.3, 0.45, 0.55;
  - ESCAPE never chains (R2 hit and run).

  Then −0.15 per link already landed, +0.1 at the Protagonist's Boiling heat, and zero under 6 ki.
- **A blitz is a fast chain.** Chosen at the first window in Tense or Frenzied (25% or 50%, +10% per act above 1): at least 3 links at a 10-tick gap. Game Design tunes it toward 2 to 6 blitzes a minute.
- **A fixed rhythm.** Links land 18 ticks (0.3 s) apart, so the player hears and sees the count.
- **Distinct links.** Each link's strike cycles a shape cue (`link_knee`, `link_elbow`, `link_kick`), so no two consecutive links look alike. Styles can swap the pursuit, for example an aerial *relay* that overtakes the flying body and strikes back.
- **One ender.** When the draw says stop, or the cap is next, the director plays the ender instead of a link: a heavier strike (`chainStrike` with `ender`), a long-only launch (`breakLaunch`), the `chain_ender` cue and the CHAIN ×N banner (Narrative's label). Links only juggle (a small pop), and only the ender sends the body away. Every chain ends on a clear full stop.

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
| **Mood** | Game Design's fight mood (`spec-wounds.md` section 9), a director value 0 to 100: Calm below 30, Tense 30 to 70, Frenzied above 70 | `chainP`; blitz chance; blink-clash weight (×1.5 Tense, ×2.5 Frenzied); seesaw beam shapes (Frenzied); "more blitzes when heated" (Orb) |
| **Act** | 1 + region breaks + transformations, capped at 4 (`spec-wounds.md` section 9) | raises blitz, blink-clash, long-launch and beam-struggle weights (+0.3 per act on blink clashes; long shapes favoured from act 3) |
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

**Telegraphs** (players now play by reads, R9):
- **The attacker's weight** shows through every approach: `tell_light` or `tell_heavy`, driven by the existing `attack` fx event, which carries the kind. Every template's approach starts at tick 0, so no data beat is needed.
- **The finisher's kind** shows in its wind-up: `finisher_tell_launch`, `_melee` or `_beam`, driven by `finisher_start.kind` (Encounter adds it from each finisher's `kind`).
- **The struggle's three pulses** show `struggle_hold` or `struggle_slip`.
- **A director parry** (R5) keeps its wind-up tell and flash.

| Cue | Look (for Rendering, VFX and Audio to design) | Priority |
| :--- | :--- | ---: |
| `tell_light`, `tell_heavy` | the attacker's weight, shown through the approach | 1 |
| `finisher_tell_launch`, `finisher_tell_melee`, `finisher_tell_beam` | the finisher's kind in its wind-up | 1 |
| `struggle_hold`, `struggle_slip` | the three pulses of the struggle | 1 |
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
| 6 | **Chains by `chainP`.** At each window, one draw against `chainP` (`styles.json`): continue with a link, or play the ender. Blitz is chosen at the first window. Links start a fixed `linkGap` or `blitzGap` after the last, with no press delay; no window opens after the ender | Replaces the chain press for both fighters (R9) |
| 7 | **Beam-clash shapes.** `startClash` and `clashResolve` pick a shape from the score margin and context (section 2.6), set `game.clash.shape` and its keyframes, and resolve by shape: deflect fires the loser's beam on the deflected path, split fires two veering beams, mutual blast detonates at the midpoint | The draws are unchanged: the two clash scores |
| 8 | **Mood and act as selector inputs.** Game Design's mood value (band) and act index are director state (Encounter's Q4 plan, section D); styles, `chainP`, blitz and beam shapes read them | The dialogue director stays read-only |
| 10 | **The R4 counter from data.** Read `selectorByProfile[profile]` before `selector`, and supply `defHeld` (S.T − D.stanceT) in the plan context | Parked edit 3, section 6 |
| 11 | **The finisher kind.** Copy `finishers.json` `kind` into `finisher_start`; draw the struggle once at `contestOpen` by `contest.struggle.byState`; emit the pulses at `beatTicks` | Parked edits 1 and 2, section 6 |
| 12 | **The clash score from data.** In the dynamic profile, read `styles.json` `beamClash.score`: tier 10, ki 0.35, a 0 to 16 draw, and the meter term by fighter. The CLASH rule stays the state rule in `templates.json` (AGGRESSIVE with 40 ki or more) | R9 answer 2 |
| 9 | Keep `cue` emission for every new beat, and add the new cue names to the fx hash map | Rendering maps them |

**Staging:**
1. Rows 1, 2 and 5: ground and aerial. They are cheap and change the most frames.
2. Rows 3 and 6: blink and clean chains.
3. Row 4: volleys.
4. Row 7: beam shapes.
5. Row 8 whenever the mood feed is ready. Until then, use `momentum` from decisive results as the stand-in.

---

## 6. Parked data edits (land after World's slice, with Tools' schemas)
These edits change `templates.json` and `finishers.json`, and therefore the data hash and the goldens. They land after World's slice and the dynamic slice, in one commit with Tools' schema changes and Encounter's Q4 loader work (EP-approved). The finished copies are with Combat.

| # | File | Edit | Schema change for Tools |
| :--- | :--- | :--- | :--- |
| 1 | `finishers.json` | `"kind"` on every finisher: `generic.placeholder` launch, `generic` launch, `kai` beam, `vorr` launch | `$defs.finisher.properties.kind`: enum `launch`, `melee`, `beam` |
| 2 | `finishers.json` | `contest.struggle.byState`: base 0.15; stance read +0.15 on a match (launch: DEFENSIVE; melee: EVASIVE; beam: AGGRESSIVE with 40 ki), +0.05 otherwise; +0.05 at 50 ki or more; −0.10 per Rally; −0.10 per minute past 8:00; fighter-state hooks | `contest.struggle.properties.byState` (object). Later, drop the press fields `halfWidthTicks`, `assistHalfWidthTicks`, `debounceTicks`, `inputs`, `aiHitChance` and the press `scoring` from `required` |
| 3 | `templates.json` | PRESSURE `selectorByProfile.dynamic`: the R4 counter (50% after 2 s held DEFENSIVE with more than 25 ki, 20% otherwise; one draw) | template `properties.selectorByProfile`: an object of profile name to selector (same shape as `selector`); the condition variable `defHeld` |
| 4 | `finishers.json` | about 30 new cue names in `cues` | none (`cues` takes any string keys) |
| 5 | `styles.json` (in the tree, not loaded) | the whole file | done: Tools' `combat-styles.schema.json` is mapped, and the file validates |

## 7. How we will know it worked
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

## 8. Open for others
- **Game Design:** volley and barrage damage (placeholders in `styles.json`); split and mutual-blast chip damage; the deflect ki cost; the director's parry and struggle rolls (their redesign).
- **Narrative:** the CHAIN ×N label is theirs; the lines keyed to mood and stance history.
- **World:** small stomp craters within the new crater rules; ground throws that slide.
- **Tools:** the schema changes for parked edits 1 to 3 (section 6). `styles.json` already has its schema.

---

## 9. What ADR 0008 changes here

Plan only; no data changes until Orb gives the go on the control scheme (`docs/decisions/0008-control-scheme.md`). The styles, the chain structure and the clash shapes all stay. What changes is who chooses.

| Part of this pass | Before | With ADR 0008 |
| :--- | :--- | :--- |
| **Energy blasts** (2.5) | a director style, weighted by a `volley` trait | the player's **energy mode**: a piece family (`moveset-system.md` section 9.1). `volley_barrage` and `volley_opener` become the energy versions of PRESSURE and of the approach. The trait weights apply only where the director picks the mode: the AI and the Simple layout |
| **Direction** | not an input | the held direction picks the entry (rush, stand, retreat). Styles keep choosing *how* that entry looks: aerial arcs, ground skids, blinks |
| **Chains** (2.1) | the director draws `chainP` at each window | **queued presses** set the length. The director still times the links on the fixed rhythm and plays the ender on the last one. `chainP` and the blitz chance remain for the AI and the Simple layout. The defender's answer is the **burst**, replacing the break-out window |
| **Parry** (section 4, R5) | a director roll by state | a **perfect block**: a timed tap during the visible wind-up; a mistimed tap still blocks. The clean-parry reward in the `parry` data block is its reward. The R5 roll remains for the AI and the Simple layout |
| **Beam struggles** (2.6) | CLASH whenever the defender is AGGRESSIVE with 40 ki or more | a struggle starts only when a beam is **answered by a beam**. The six shapes and the margin rule are unchanged. A perfect block against a beam is a DEFLECT outcome, separate from the *deflect* clash shape |
| **Telegraphs** (section 4) | weight and finisher kind | unchanged, and more important: the wind-up tell is now the perfect-block window, and the mode shows as a tell too (`tell_energy`: the hands light) |
| **New in-exchange windows** | parry and chain only | perfect block, dodge cancel, burst and reversal (`moveset-system.md` section 9.5). Each template branch will list them as data |
| **Context actions** | none | grab and throw, pick-up, the civilians action, provoke or feint, energy shove, reversal, deflect, tackle and dive grab get their own small template family (`moveset-system.md` section 9.3) |

**The parked Q4 batch (section 6) under ADR 0008:**

| # | Edit | Still valid? |
| :--- | :--- | :--- |
| 1 | finisher `kind` | **Yes.** The read against the kind moves from stances to held states (Guard, Dodge, Press with a beam in hand) |
| 2 | `contest.struggle.byState` | **Yes, with two updates on merge:** the base becomes Game Design's current value (0.23 since `6be4c3a`; the parked copy says 0.15), and the stance labels become held states |
| 3 | PRESSURE's R4 counter as `selectorByProfile.dynamic` | **Hold.** With a perfect block in the player's hands, Game Design needs to re-rule R4. It may become "a perfect block opens the counter; a plain held guard counters only for the AI and the Simple layout" |
| 4 | the new cue names | **Yes.** More will follow (the mode tell, the context actions) |

**A future edit, not in the batch:** `templates.json` `beam.outcome` drops the automatic CLASH rule in favour of the answered-beam rule. It lands with Encounter's revised Q4 plan.
