# Spec: Wounds (damage model, Variant A)

Owner: Game Design. Status: spec for P2 and P3, the input for Combat and Encounter Systems. **Scope: 1v1.** 2v2 rules are deferred (Orb). Date: 2026-09-29.

**Sources.**
- `damage-model.md`: the rationale behind this spec.
- `pitches.md`: the options Orb picked from.
- Orb's rulings in `docs/ep/vision.md`.
- Narrative's round 2 in `docs/narrative/pitches-q3.md`.

Numbers are **starting values**, which QA tunes against `balance-targets.md` (§2, §8, §10). Mechanics survive a re-skin; names are working names.

## 1. Core rules

| Rule | Spec |
| :--- | :--- |
| **Regions** | Head, core, arms and legs, for every fighter. The Tyrant adds a fifth, the **bladed mantle**, which never counts toward the brink |
| **Wear** | 0 to 100 per region, stored as fixed-point. A hit adds `wear = damage × k` to the region the director picks. `damage` is today's `hit()` value with all its multipliers (`index.html:L319-338`). Starting k = 0.08 |
| **Stages** | Fresh below 30; bruised 30 to 59; battered 60 to 89; broken at 90 or more |
| **Stage penalties** | *Head:* battered narrows the parry window by 20% and adds a 0.2 s stagger after heavies; broken dazes for 0.4 s after each exchange lost and gives −0.08 on defence rolls. *Core:* battered cuts ki regen by 30%; broken puts the fighter on the brink, and long transformations cannot start. *Arms:* battered raises the DEFENSIVE multiplier from 0.38 to 0.55; broken cuts heavies and signatures to ×0.8 and removes BRACE. *Legs:* battered sets speed ×0.85 and −0.10 on the ESCAPE slip chance; broken removes the dash and doubles the time to hide (1.8 s) |
| **Recovery** | Out of exchanges, a region below 60 fades 1 wear per second. Hidden, a battered region fades 3 per second, down to 59. Broken regions never fade (only a Rally mends them) |
| **Region choice** | Each atom lists the regions it may hit, with weights. The director multiplies each weight by (1 + wear/50), which is "go for the wound", then draws with the seeded sim RNG. Attack kind sets the family: lights go to the head and arms, heavies to the core and legs, guard hits to the arms, and beams and impacts spread |
| **Brink** | The core breaks, or any two of head, arms and legs break. The Cyborg is the exception (§3) |
| **Decisive exchange** | One that ends with the loser launched, a heavy or beam clash won, a GUARD BREAK, or an interrupted long transformation or Press |
| **Finisher** | When the opponent of a fighter on the brink wins a decisive exchange, their **fighter-specific finisher** replaces the normal ending. The fighter on the brink survives it on a contest roll: 30% base, −10 points for each Rally that fighter has used, and −10 points per minute past 8:00, with a floor of 0 |
| **The end** | A KO happens only through a finisher. Stray damage never ends a match |
| **Breaks are chapters** | A break is a 1 to 2 s set piece: a camera break shot, a bark, then a **break launch**. The break launch is long (at least 1,500 units horizontally) and chosen by the planner's distance and new-biome terms (`balance-targets.md` §10) |

## 2. Rally (approved per fighter, with looser limits)

**Shared rule.** A Rally takes a fighter off the brink and mends one broken region to **battered**, at 89 wear, one good hit from breaking again.

| Fighter | Rally | Trigger while on the brink |
| :--- | :--- | :--- |
| Protagonist | **Second Wind** | Survive the rival's finisher contest roll. His next track step is then free |
| Anti-hero | **Spite** | Win a decisive exchange by hand (melee, no signature) with help refused. His arms mend first, and his next finisher must be by hand |
| Tyrant | **Emergency revision** | Instant and safe. He mends his most-worn region, loses his next scheduled refit, and gains a visible flaw. Not available in his full-power form |
| Cyborg | **Reboot** | Dock the loose backup drive, or finish a Press within reach of civilians. It mends one chip stage, and regrowth doubles for 5 s |

**Limits after Orb's "looser" ruling:**
- **Dropped:** the once-per-match cap and the final-act lock. Instead, each region can be rallied **once**, so a fighter has at most 4 Rallies. The Tyrant's are further bounded by the refits he has left.
- **Softened:** the cooldown goes from 30 s to **15 s** after leaving the brink.
- **Kept:** the mended region returns battered.

**Why a finale still can't loop:**
1. Each Rally spends something finite: a region's one Rally, a refit, the drive or nearby civilians, the rival's finisher attempt, or refused help.
2. The mended region sits one hit from breaking again.
3. The finisher contest tilts 10 points against the fighter for every Rally and every minute past 8:00. By the third Rally, or by about 11:00, survival is at 0.

## 3. Per-fighter damage, and how the readout shows it

Orb picked **the aura crown with wound cards, plus the silhouette, varied per fighter**:
- **The aura crown** has four arcs, one per region. An arc flickers when battered and gaps when broken.
- **Wound cards** are 1.5 s picture-in-picture callouts, such as `ARMS: BROKEN`.
- **The silhouette** is a small body figure with pattern and tint per stage. It is on by default in `training` and as the accessibility default.

| Fighter | How damage is handled | How the readout shows it |
| :--- | :--- | :--- |
| **Protagonist**: Rolls with it | 25% of each incoming hit's wear spreads evenly over his other regions. His power stage is the **heat track** (below): big temporary boosts paid for in internal core wear | *Crown:* all arcs thin together as wear spreads, rather than one gapping early, and the core arc shimmers with heat. *Cards:* heat stage changes, internal core stages, the boil-over, and `SECOND WIND`. The stage names are Narrative's. *Silhouette:* an even wash, with the core filling from inside as internal wear builds |
| **Anti-hero**: Proud front | While Pride is at half or above, battered penalties do not apply. When Pride falls below half, every withheld penalty lands at once. **Humbled** and **Drop the Act** turn Pride into power (below). Each shame stack also darkens a notch on his crown, and Drop the Act fires its own card together with `FACADE CRACKS` | *Crown and cards:* while Pride holds, his crown stays whole and battered cards are **withheld**. Only broken cards show, and body decals still show the damage. When Pride breaks, every withheld card fires at once as `FACADE CRACKS`, and the crown drops to its true state. *Silhouette:* shows only the hairline "front" until the crack. Opponents read his visible Pride meter to predict it |
| **Tyrant**: Refit | Each revision mends one stage of his most-worn region. The mend shrinks each time, and his full-power form mends nothing. The **bladed mantle** is region 5: breaking it removes the mantle attacks and slows his next revision. His goons are single-region bodies, taken out by one break | *Silhouette:* each revision **reprints** it with the new revision number and a patch stamp on the mended region. An Emergency revision prints a flaw stamp. *Crown:* a fifth arc runs along the mantle's hem. *Cards:* styled as revision notes, for example `REV 7: LEFT ARM PATCHED` or `MANTLE: TORN` |
| **Cyborg**: Regrowth and the Rail chip | Flesh regions regrow at 8 wear per second out of exchanges and never count toward the brink. The **Rail chip** moves on a seeded schedule, about every 4 s, between four stations: head, chest, back and hip. A heavy, a GUARD BREAK, a signature hit or an interrupted **Press** opens the hatch at the chip's station for 1.5 s. While it is open, the director weights that station's region by ×3, and a hit there damages the chip. Chip stages are scratched, cracked and split, and a split chip means the brink. Chip damage never regrows | *Crown:* flesh arcs visibly crawl back after damage, so the transient state reads. *Silhouette:* shows the rail, the chip's current station and its stage marks, which are the only persistent state. *Cards:* chip events only, such as `HATCH OPEN: HIP` and `CHIP: CRACKED` |

**Fighter mechanics that touch wear:**
- **The heat track (the Protagonist's power stage).** Orb: "his blood goes from heated to simmering to boiling, causing internal damage that adds up but gives big temporary boosts." Narrative names it and Legal screens the look (no red for the Protagonist); this section defines the mechanics only.

  **Heat.** A hidden value from 0 to 100, read through the readout below.
  - *Stoking.* He raises heat by holding a stoke input while free: +25 per second. Controls assigns the input; the default proposal is a variant of the charge input. Stoking gives no ki. It is exposed exactly like charging, so an attack on him is a CHARGE INTERRUPT (`index.html:L435-438`).
  - *Respect sparks.* When his rival commits fully (the Respect trigger in `economy.md` §4.2), he gains +10 heat, even without stoking.
  - *Cooling.* −4 per second while he is not stoking, and −10 per second while hidden.

  **Stages, with temporary boosts.** Each boost lasts only while he is in the stage. A stage exits 5 below its floor, to prevent flicker.

  | Stage | Enters at | Damage | Speed | Outcome rolls | Internal wear to the core |
  | :--- | :--- | :--- | :--- | :--- | :--- |
  | Heated | 25 | +10% | +5% | none | 1 per second |
  | Simmering | 55 | +25% | +15% | +0.05 | 3 per second |
  | Boiling | 85 | +45% | +25% | +0.10, and launch force +20% | 6 per second |

  **Internal damage.** Heat adds wear to the core as its own *internal* part.
  - Internal wear never fades, not even when hidden, and it does not spread through Rolls with it.
  - It does not feed Respect.
  - It counts fully toward the core's stages. An internally broken core puts him on the brink like any other broken core.
  - Heat therefore spends his future. A full climb and 6 s boil that ends in a boil-over costs about 55 internal wear, so two of them break his core with no help from his rival.

  **Limits and boiling over.**
  - Boiling lasts at most 6 s. If heat reaches 100, or Boiling reaches 6 s, he **boils over**:
    - a burst like a clash shockwave knocks the rival back, and causes collateral scaled by tier;
    - then he vents: heat drops to 0, the core takes 15 internal wear in one lump, he staggers for 1.0 s, and he cannot climb above Heated for 45 s.
  - A boil-over is not a decisive exchange, so it can never start a finisher.
  - A Respect spark while he is boiling can push him over. A rival who transforms at the right moment forces the boil-over, and that is counterplay.
  - Stopping stoking before 100 is the safe exit. Cooling out of Boiling from 90 down to 80 takes 2.5 s, and the Boiling wear rate applies until he is out.

  **Rally and finishers.**
  - **No finisher can start while he is Boiling.** The bill lands first, which is the same rule the region-loan version used.
  - Heated and Simmering finishers are allowed.
  - On the brink he may stoke. Boiling adds +10 points to his finisher-contest survival roll, and that stacks with the tilts in §2. It is a defiant gamble.
  - **Second Wind** mends the core to battered if internal wear broke it, but leaves the internal wear at 89. It also sets heat to Heated with no internal wear for 5 s. His next track step is still free.

  **Readout** (the Protagonist's row above):
  - the core arc shimmers and thickens by stage;
  - the silhouette fills the core from the inside with a distinct "internal" pattern, separate from surface wear;
  - wound cards announce each stage change, each internal core stage, and the boil-over;
  - audio adds a heartbeat and a rising boil. The colour is Narrative's and Art's call, and not red.
- **The region loan (the previous Overcommit), kept in case Orb reverts.**
  - *Mechanics:* the direction held at activation picked one region to spend: arms for damage, legs for speed, core for toughness.
  - *Rungs:* Committed was +15% at 4 self-wear per second; Overcommitted +30% on two regions at 6 per second; Overdrawn +50% on three regions for at most 4 s at 8 per second, then each spent region dropped a stage and a 45 s lockout followed.
  - *Rules:* no finisher could start while Overdrawn. Self-wear did not spread and did not feed Respect.
  - *QA bands:* Overdrawn users won 40 to 60%, with at most 1.5 uses per match.
- **The Anti-hero's pride-for-power kit** (Orb, round 4: he leans toward Drop the Act in 1v1, and Humbled). All names are placeholders.
  - **Humbled (forced, always on).**
    - *Stacks.* Each humbling he suffers gives a stack of shame, up to 3. A humbling is being parried, taking a GUARD BREAK, or having a region broken.
    - *While stacks are held:* each stack gives +8% damage and +0.03 on outcome rolls.
    - *Release.* The next decisive exchange he wins spends all his stacks in a burst: +15% damage per stack on that exchange, then the stacks clear.
    - *Cost.* Each humbling also costs 15 Pride, so humblings push him toward the facade crack.
    - Humbled suits the AI and new players, because there is nothing to decide.
  - **Drop the Act (by choice, 1v1, once per match).**
    - *When.* Available after 2:00 while his Pride is 50 or more, so he still has a front to drop.
    - *How.* He holds an input for 1 s. It is exposed like charging, so an interrupt is a decisive exchange won by the rival, and he keeps his front.
    - *Effect.* His Pride goes to 0 and the facade cracks at once: every withheld penalty lands, and the crown and cards show his true state. For the rest of the match he is **unrestrained**:
      - +30% damage and +15% speed;
      - +0.08 on outcome rolls;
      - a chain limit of 6 instead of 5.
    - *Cost.* Pride can never rebuild above 49 this match, so the Proud front is gone for good and his real wear shows and counts.
  - **Interactions.**
    - Both keep Spite, because neither involves help. Humbled stacks make Spite easier to earn on the brink, because rage feeds the comeback.
    - After Drop the Act, Humbled still stacks. Its Pride cost no longer matters, and its burst still does.
    - *Swallow It* (hold to drain Pride into a proportional surge, interruptible) is kept as the fallback if Orb drops either.
  - **Earlier rulings stand:** *Take a Knee* keeps Spite. *Hat in Hand* and *Full Circle* forfeit Spite for the match, because they accept help.
  - **Narrative's round-4 options B1 to B4** stay as notes until Orb picks: Shed Regalia, Credit Where Due, The Code, Loss of Face (`docs/narrative/pitches-q3.md`, Round 4 §2). Each would plug into the same Pride and Proud-front rules.
  - **QA bands**, per Anti-hero match:
    - he wins 45 to 55% of each pairing;
    - in 1v1, the AI drops the act in 40 to 80% of matches, at a median of 3:00 to 6:00;
    - matches where he drops the act are won 45 to 60% of the time;
    - Humbled bursts fire 1 to 3 times per match;
    - the facade cracks in 60 to 90% of matches.
- **Press (the Cyborg's food).** His plates clamp shut around nearby civilians; this is slow and interruptible, like a charge. An interrupt pops the hatch at the chip's current station, which rewards the punish.

## 4. What the sim needs (Simulation, Tools)

- **Per-fighter data:**
  - regions and thresholds;
  - penalty keys;
  - recovery rates;
  - the damage profile: spread, pride mask, refit table, regrowth, chip rail;
  - Rally rule;
  - finisher template ids per form tier.
- **Per-atom data:** region weights, wear multiplier, impact class, and whether it opens the hatch.
- **Per-fighter state:** wear per region, stage, brink flag, Rallied regions, hatch timer, chip station and stage, commit rung, Pride mask.
- **Events** into the fx stream (commit `9ac1ea9`): `region_stage`, `region_broken`, `brink_enter`, `brink_exit`, `rally`, `hatch_open`, `chip_stage`, `heat_stage`, `boil_over`, `facade_crack`, `shame_stack`, `drop_act`, `revision_reprint`, `finisher_start`, `finisher_contest`, `ko`, plus the fold events in §7.
- **Rendering and randomness.** Render reads state and events and never writes them. Region draws use the sim RNG only.

## 5. Acceptance tests

**QA harness** (seeded batches, 1,000 or more matches per arm, measured from events):
1. **Determinism.** The same seed and inputs give an identical event hash across runs and ports (JS and GDScript).
2. **No KO without a finisher.** 100% of KOs follow the loser's `brink_enter` and a `finisher_start`. There are no KOs from stray damage.
3. **Length and chapters.** 4 to 6 region breaks per 1v1 (median). Median time to first brink 4:30 to 7:00. Match length median 6:00 to 8:00, p90 at most 10:00, p99 at most 12:00 (`balance-targets.md` §2).
4. **No loops.**
   - Rallies per match average 0.5 to 2.0.
   - No fighter rallies the same region twice.
   - The finisher survival chance reaches 0 after a fighter's third Rally, or once the tilt past 8:00 has taken it to 0.
5. **Spread.** No region takes more than 45% of all wear across a batch. Each of head, arms and legs is the first region broken in at least 10% of matches.
6. **Profiles.**
   - The Cyborg's chip takes 0 damage while the hatch is closed.
   - The Anti-hero's battered penalties are inactive while Pride is at half or above, and all apply within one tick of the facade crack.
   - Refit mends shrink with each revision.
   - No finisher starts while the Protagonist is Boiling, and no boil-over is ever counted as a decisive exchange.
   - The Protagonist's internal core wear never decreases, except through Second Wind.
7. **Balance.** Every pairing wins 45 to 55%. The pacing bands in `balance-targets.md` §10 still pass. **Heat-track bands**, per Protagonist match:
   - he reaches Boiling in 40 to 80% of matches;
   - Boiling fills at most 5% of match time;
   - boil-overs average at most 0.5 per match;
   - matches with a boil-over are won 35 to 55% of the time, so the gamble is real;
   - internal wear causes 10 to 35% of his brinks, so it matters without dominating.

**Playtest and review:**

8. After one match, 80% of new players say correctly who was closer to losing at the midpoint.
9. 90% can name the region most recently broken on their opponent.
10. At the widest zoom, the crown's arcs and stages can be told apart in a screenshot review, including in a colour-blind simulation (Art, Accessibility).
11. With the silhouette on, a new player predicts the Anti-hero's facade crack after a humbling, and the Cyborg's open hatch, in a scripted `training` scenario.

## 6. Hand-offs (routed by the EP)

- **Combat:**
  - region weights per atom;
  - break-launch and chase set pieces;
  - finisher templates per fighter and form tier;
  - the heat-track stoking and boil-over beats, and the Swallow It beats;
  - the Press interrupt.
- **Encounter Systems:**
  - region choice (go for the wound) and the decisive-exchange rule;
  - the finisher contest;
  - the AI's use of Rally, the heat track, Swallow It and Press.
- **Simulation:** state, data and events in §4, with fixed-point wear.
- **UI and UX:** the crown, the cards and the silhouette, per fighter.
- **Animation, VFX, Audio, Camera:** the channels in `damage-model.md` §3.
- **Narrative:** card text and barks.
- **QA:** tests 1 to 7.

## 7. The fold: fragments and the proving ground (the Protagonist)

Orb (round 4): **space folds inward** toward the Protagonist and the planet vanishes around them, for an in-world reason. Narrative's fiction and storyboard are in `docs/narrative/pitches-q3.md`, Round 4 §3.
- **The fiction.** The fragments are the planet's bare bone. Held close, they let him draw that lifeless ground over the fight.
- **Legal's rules apply** (`docs/legal/q3-screen.md` §a):
  - no fixed count;
  - no search, no sensor and no wish;
  - only the fighters speak or appear;
  - no column of light and no darkening sky.

This section is binding and replaces the relocation rules in `systems-sketch.md` §4 and `pitches.md` §4. Names are placeholders.

| Rule | Spec |
| :--- | :--- |
| **Fragments** | Shed by planet damage (region-break launches, beam hits, ground tier-ups, clash shockwaves) as irregular pieces whose mass runs from 1 to 5, drawn with a seed. Anyone can grab one for a charge surge. Only the Protagonist can **hold** them, and they orbit his body |
| **Threshold** | A total held mass of **12** (starting value). Any mix of sizes works, and there is never a count to complete. As his mass nears 12, the orbit tightens and hums. At 12 the ring closes: the tell |
| **Time floor** | **Kept at 4:00.** No fold before it. It protects act 1 and 2 pacing, and gives the Cyborg his populated planet for at least the first half of the match |
| **Folding** | With the ring closed and the floor passed, he holds an input for 1.5 s: the lead-in, with his line and the rival's reply. He is exposed like charging during the hold. An interrupt counts as a decisive exchange won by the rival, and knocks one fragment loose. Once the hold completes, the fold is a set piece of up to 6 s (Orb allows cinematics longer than 3 s) |
| **Who comes** | In 1v1, both fighters, always, so the rival is never out of range (pillar 3). 2v2 rules are **deferred** (Orb: focus on 1v1 for now) |
| **The proving ground** | A small wrapped planetoid, about a third of the planet's circumference, of barren craterable stone. No civilians, no structures and no cover |
| **What the proving ground changes** | No casualties, so no collateral-fed gain: the prototype's menace and anguish stop. **The denial is the Protagonist's intended counter to the Cyborg**, softened by one relief valve:
- the Cyborg keeps his Hunger;
- he may **Press a loose fragment** lying on the ground. That gives him half the Hunger of a civilian, and destroys the fragment, which feeds the unfold.

His best play is to break the fold, and that is the matchup's story. The backup drive stays on the planet. There is no hiding, because there is no cover. Ego meters, forms, wear and heat carry over unchanged. The Protagonist's **final form unlocks** here, and only here |
| **Fragility** | While folded, the fragments still orbit him. A heavy, a GUARD BREAK, a signature hit or a region break on him knocks one loose, with a seeded pick weighted to the largest. It lands on the barren ground, and anyone can grab it: the rival gets a surge and denies the mass. Each loss makes the horizon **flicker**: a `FOLD FLICKERS` card, and the planet's edge ghosts back in |
| **Unfolding** | If his held mass stays below 12 for **3 s**, the planet returns. In those 3 s he can grab back mass and hold the fold, a scramble set piece. On the unfold, everyone returns to where they left. His final form ends and he drops to his previous form, keeping his promise. He cannot fold again for **60 s** |
| **Finishers** | These work normally in the proving ground, which is the natural stage for the finale. A finisher that starts during the unfold countdown completes before the planet returns |
| **Events** | `fragment_shed`, `fragment_grab`, `fragment_lost`, `ring_closed`, `fold_start`, `fold_flicker`, `unfold` |

**QA bands**, per Protagonist match:
- a fold happens in 30 to 60% of matches;
- no fold before 4:00 (0 cases);
- median fold time 4:30 to 6:30;
- 20 to 50% of folds collapse back to the planet, so fragility matters without dominating;
- 50 to 80% of matches with a fold end in the proving ground;
- no casualties are recorded while folded (0 cases);
- the Protagonist still wins 45 to 55% of each pairing;
- against the Cyborg specifically: the Cyborg wins 40 to 55% of the matches that include a fold, and 30 to 60% of folds collapse.

**Settled or deferred:**
- The rival's reply varies by matchup and stakes (Narrative's matchup matrix).
- Who the fold takes in 2v2 is **deferred** with all 2v2 rules. The recommendation on record is everyone.
