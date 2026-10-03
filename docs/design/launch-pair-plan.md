# The launch pair: two fighters for the next big update

Owner: Game Design. Orb's next big update (`docs/ep/vision.md`, last section) has three parts: the expanded energy blasts, **two fighters** (the Protagonist and the rival, the Anti-hero, replacing the KAI and VORR placeholders), and the framework of the alchemy layer. This page says what "two fighters" means, by owner, and in what order. It points at the rules that already exist. The little new design it needs is marked **new**.

## 1. Who they are in play

Orb's picture is that both are solid all-rounders (`pitches.md` §7). Pillar 5 is what tells them apart: the hero is pressured by collateral, and the rival feeds on it.

| | **The Protagonist** (the hero) | **The Anti-hero** (the rival) |
| :--- | :--- | :--- |
| **Replaces** | KAI | VORR |
| **Toward towns** | Avoids them. Planner care is positive: the AI lures the fight to empty ground, arcs over roofs instead of ploughing (`balance-targets.md` §16), and swats beams at the sky | Seeks them. Planner care is negative: the AI prowls toward settlements, ploughs through buildings, and swats beams at them |
| **His meter** | Anguish, which is mostly emotional: a ki regen cut of 0.01 × anguish (`balance-targets.md` §13). It drives his voice and posture | **Pride** (`spec-wounds.md` §3, the Heavy Crown). It replaces menace and its buffs, which are retired with VORR |
| **Feeding on collateral** | Collateral costs him: anguish rises, at +0.9 for each casualty he causes and +0.5 for each the rival causes | **New:** a building he levels gives **+2 Pride**. Under the Heavy Crown, more Pride means less damage until Apex, so feeding on a town pushes him through his weak middle faster. It is a show of ego, not a free buff. That is the lesson of the KAI gap |
| **His wound profile** | Rolls with it: 25% of each hit's wear spreads over his other regions (`spec-wounds.md` §3) | The Proud front, Humbled and Drop the Act (`spec-wounds.md` §3) |
| **His Rally** | Second Wind: surviving the finisher contest | Spite: a decisive exchange won by hand |
| **His taunt** | Feeds his power, +5, until his heat track exists. After that it is heat +10 | Pride +6 |
| **His signature move** | None beyond the shared kit in this update | **On the Chin** (`spec-wounds.md` §3) |

**Balance.** Every pairing stays inside 45 to 55%. The placeholder `dmgMul` values (0.95 and 1.02) go: QA re-centres with each fighter's own numbers. The rival also has his situational bands: he wins under 45% of the matches that end before Apex, and over 60% of those that reach it (`pitches.md` §7).

## 2. Stats and forms

- **Base stats are the same for both,** since both are all-rounders: today's placeholder speed, damage, ki and wear numbers. Their differences come from the rows above, not from base stats.
- **Each takes three forms,** at the pace in `spec-wounds.md` §8b: the first at about 1:30, the second at about 3:15 and the third at about 5:00.
  - **The Protagonist** keeps the shared power ladder: his three tier-ups are his forms, taken by the transform hold. His heat track and his final form, Open Hand, come in a later update.
  - **The Anti-hero's forms are his Pride,** as Orb picked: Regalia at 60, Sovereign at 80 and Apex at 95. **New:** for him each form is also his tier-up, so tier 2 is Regalia, tier 3 Sovereign and tier 4 Apex. The power ladder doesn't apply to him.
- **The staging** of every form is `moveset-rules.md` §10.8. The top-tier speed curve is still held (`agency-pass.md` §8).

## 3. Movesets

Combat is writing which waves go live for each fighter (`docs/combat/launch-pair-movesets.md`). The rival's full plan is `docs/combat/m0-rich.md`. Game Design's minimum for each fighter at launch:

| Need | Why |
| :--- | :--- |
| Enough key strikes for the three styles (blur, combo, power), with every limb covered when one is broken | The alchemist (`agency-pass.md` §2) and the broken-limb rule (`spec-wounds.md` §1d) |
| A knock-back ender and launch enders, for each style | The four earners and the knock-backs (`agency-pass.md` §3 and §13) |
| The energy family (§4) | The expanded blasts |
| A close taunt and the far challenge | `agency-pass.md` §1 and §3 |
| One finisher, which can also start from range | `agency-pass.md` §17 |
| One place signature, and one form signature | `moveset-rules.md` §2 |
| The rival's On the Chin (6 poses) | His identity |

Blow for Blow, the full showcase sets and the rest of the signatures can follow in later waves.

## 4. Energy kinds

Both get the shared base: the bolt, the volley, the charged shot and the mine (`agency-pass.md` §15). **New:** each adds the kinds that fit him.

| | The Protagonist | The Anti-hero |
| :--- | :--- | :--- |
| **His way with energy** | Precision. His spread builds 20% more slowly, so his measured bolts stay accurate a little longer | Volume. His shard spread grows with Pride: 3, 5, 7 and 9 pieces (`moveset-rules.md` §11) |
| **His extra kinds** (as amended in §8) | The **curving shot**, and later the ricochet shot | **Rain** and the **splitting shot**, with the shard spread and his barrage volley special |

The three first kinds Game Design proposed (`agency-pass.md` §15.5) are split between them, so each fighter shows one at launch.

## 5. What changes, by owner

| Owner | What |
| :--- | :--- |
| **Simulation** | Two fighter folders replace `data/fighters/KAI` and `VORR` (fighter, ladder, meters, wounds), with working ids until Orb names them. `roster.json` lists the two. Pride as a meter, with its Heavy Crown numbers. The rival's forms on Pride thresholds. Anguish stays for the hero. Menace is retired. The fighters' shot kinds |
| **Encounter** | Each fighter's care in the planner and the AI's personality (the lure, the prowl). On the Chin as a held stance. The rival's Pride sources, including +2 for a building levelled. Each fighter's finisher. The alchemy framework: the window, the styles, the timing grades and the flow (`agency-pass.md` §2) |
| **Combat** | The two movesets, wave by wave (§3), and each fighter's energy pieces |
| **World** | Nothing new for the fighters. The expanded blasts against buildings are already World's (`agency-pass.md` §15.3) |
| **Art** | The refine sheets wait on Orb. Until they land, the build uses each fighter's current palette and silhouette features on today's bodies. The masks are parked |
| **Animation** | The two per-fighter shapes already exist, P and A (`docs/animation/pose-pipeline.md` §9.9). Each fighter's form looks, battle damage that keeps building through forms, and the rival's On the Chin poses |
| **UI** | The two names, the face cut-ins and portraits, each fighter's meter (Pride for the rival, anguish and power for the hero), character select for two, the band icon and the recipe strip |
| **Audio** | Each fighter's babble voice (Orb: close, needs tweaks), a theme for each on transformation, and the voice packet once Orb has edited it |
| **QA** | A baseline for the pair: 45 to 55% overall, the rival's situational bands, and every agency band |
| **Legal** | The two names and the final staging of the new pieces |

## 6. What Orb supplies

1. **The two names.** The build uses working ids until then.
2. **The voice packet,** which Orb is editing now in `docs/narrative/voice-lab`. Nobody else touches it.
3. **A look at Art's refine sheets** when they're ready. The build doesn't wait for them.
4. **A yes or no on one new rule:** the rival gains Pride from the buildings he levels (§1). It is the smallest way to make "he feeds on towns" true for a fighter who has no menace.

## 7. The order

| # | Step | Playable when it lands |
| ---: | :--- | :--- |
| 1 | **The split.** Two fighter folders replace KAI and VORR, with working ids, their care, meters, wound profiles, Rallies and taunts. QA re-centres the balance | Yes: two different fighters on today's kit |
| 2 | **The alchemy framework.** The press window, styles, timing grades and flow | Yes |
| 3 | **The expanded blasts.** Explosions, wild deflects, shots against buildings, the spray, mines, and each fighter's extra kinds (`agency-pass.md` §15 to §17) | Yes |
| 4 | **The rival's kit.** The Heavy Crown, his forms on Pride, Pride from collateral, and On the Chin | Yes |
| 5 | **The movesets, waves by Combat,** dressed with the P and A shapes, the form looks and battle damage | Wave by wave |
| 6 | **Names, faces, voices and themes,** as Orb supplies them | Yes |
| 7 | **QA's baseline for the pair,** then the balance pass | — |

Steps 2 and 3 can run alongside each other. Step 4 needs step 1. Step 6 runs whenever Orb's material is ready.

## 8. Reconciling with Combat's plan (`docs/combat/launch-pair-movesets.md`)

Combat wrote its plan before this one landed. Four points are settled here.

**1. Energy kinds: Combat's assignment is adopted.** It fits each fighter better than §4 did, so §4 is amended.

| Fighter | Kinds | Why |
| :--- | :--- | :--- |
| **The Protagonist** | **The curving shot.** The ricochet shot comes later | A martial artist's precision. He sets the side with the stick and bends the shot round cover. It goes with his slower spread build-up |
| **The Anti-hero** | **Rain** and **the splitting shot,** with his shard spread by Pride and his barrage volley special | Rain marks where the rival may not stand, which is his hierarchy made playable. The splitting shot is his barrage in one press |

Legal's notes in Combat's plan hold for all three.

**2. Blow for Blow ships with the alchemy framework.** It is the one moment that makes the timing grades visible between two people, and Orb asked for it by name. It costs 3 sketches. Legal's twelve staging rules apply (`agency-pass.md` §2).

**3. The counts against the minimum in §3.**

| | Combat's count | Against the minimum |
| :--- | :--- | :--- |
| **The Anti-hero** | 17 sketches, or 20 with Blow for Blow | Covers the strike pool, the endings, the energy kinds, the taunts and On the Chin. **Add his base finisher** (by hand) for launch. His form finishers can follow |
| **The Protagonist** | 33 sketches: wave 1's 34 slots with 12 silhouette changes, 8 strikes of his own, 2 entries and the curving shot | Covers the strike pool, the endings and the energy kind. **Add his finisher** in the flight version (point 4) for launch |

- **Signatures at launch:** each uses the shared signature poses with his own beam style, which is VFX's work and needs no new sketches. His form signatures follow his forms.
- **The total** is about 53 sketches plus the two finishers. Combat sizes the finishers.

**4. The Protagonist's finisher, without teleports.** Teleports stay on hold, so his finisher in `data/combat/finishers.json` flies.

| Beat | The flight version |
| :--- | :--- |
| The catch | As written |
| **The flurry** | 3 to 5 strikes, each arriving from a new side after a short spiral flight round the loser: the ping-pong's path (`control-rules.md` §11). Each flight takes 16 to 20 ticks. He is drawn the whole way: no vanishing and no afterimage that hides him. The sides come from the terrain and where the loser is, as the teleport angles did |
| Rise and gather; the contest | As written |
| The end | A point-blank, all-out energy blast, as written |

If Orb later gives teleporting to him, the flurry can go back to the ripple-step version as a variant.

## 9. Numbers for the three launch energy kinds

For `data/fight/shots.json`, answering Simulation's plan (`docs/architecture/pending/shots-events-and-kinds.md`). **Every number is a starting value for QA.** For scale, in today's data a light does 26 and a heavy 66; a bolt does 13 and costs 1 ki; a full charged shot does 82.5 and costs 8.

**Any one kind can be dropped.** Each kind is its own block of data, and a fighter fires only the kinds his list names. Orb hasn't picked which extra kinds ship, and nothing below depends on another kind being there.

**How they are sized.** QA measures blasts at about 11% of match damage, in a band of 10 to 25%. A full charged shot gives about 10 damage per ki. Each new kind gives less than that when it lands, and pays in something else: reach round a guard, a late dodger caught, or ground denied. So they widen what energy can do without making it the better way to deal damage.

### The curving shot (the Protagonist)

| Key | Value | Reason |
| :--- | :--- | :--- |
| Ki | 8 | A heavy energy press, like the arc and the charged shot |
| `dmg` | 52.8 (×0.8 of a heavy) | The arc's damage. It is 6.6 per ki, under the charged shot's 10 |
| `power` | 2 | It eats two bolts, like the arc |
| `speed` | 40 units a tick | Slower than every straight shot, which is its price |
| Arrival | Within 60 ticks, not 45 | So "slower" still holds at long range |
| `curve.bow` | 0.35 of the distance at the fire | Simulation's value, confirmed |
| `curve.bowMax` | 900 units (12 bh) | So a far shot doesn't bow off the screen |
| `curve.bowMin` | 150 units (2 bh) | **New.** So a close shot still visibly bends |
| **Does a guard stop it?** | **Half.** A held guard takes ×0.6 of it, where it takes ×0.38 of a straight shot | It comes round the front of the guard, which is the point of it. A full bypass would make guarding worthless |
| Perfect block and dodge | Both work as against any heavy shot: a 10-tick window, and a deflect sends it wild | The timing answers stay whole |
| Buildings and ground | They stop it, as Simulation plans | That is what makes the bend mean something |
| The underside near the ground | The director doesn't offer the side that would put the bow underground | Simulation's open point 2: the director decides, not the core |
| Structure damage | 40, before the tier factor | The arc's row (`agency-pass.md` §15.3) |
| Knock-back | None | Only a full charged shot knocks back |

### The splitting shot (the rival)

It is the charged shot with a second press. Without the press it is an ordinary charged shot.

| Key | Value | Reason |
| :--- | :--- | :--- |
| Ki | 8 for the charged shot, and nothing more for the split | The split gives up the knock-back, which is its cost |
| `split.count` | 5 | As ruled |
| `split.kind` | `shard` | Combat's sheet. A shard lives 24 ticks, so the pieces reach about 16 bh from the split |
| `split.spread` | 0.32 (about 18 degrees each side) | Simulation's value, confirmed. It matches the spray cone at full spread |
| **Damage share** | **Each piece does 16% of the parent's damage at the split, so 80% in all** | From a full charge that is 13.2 a piece, about a bolt. One or two usually land on a late dodger: 13 to 26, well under the 82.5 he dodged. All five at point-blank is 66, a heavy |
| When the press works | From 6 ticks after the fire until the shot arrives | So it can't split in his own hand |
| `power` of each piece | 1 | A shard's |
| Counting | The five share one group, and count as **one** landed bolt toward the barrage's ender | So one split can't knock back by itself (`agency-pass.md` §16) |
| No room under the cap | The parent flies on, unsplit | Simulation's open point 3, confirmed. Fewer pieces would make the cone lopsided |
| Structure damage | 12 a piece, before the tier factor | The bolt's row |

### Rain (the rival)

| Key | Value | Reason |
| :--- | :--- | :--- |
| Ki | 10 | A heavy energy press plus 2. It can't be deflected back, and it takes ground away |
| `rain.count` | 6 | Simulation's value, confirmed |
| `rain.kind` | `bolt` | |
| **Damage of each** | **10.4 (0.4 of a light)** | A fighter who stays in the patch takes one or two: 10 to 21 for 10 ki. All six is 62, under a heavy. It is the weakest kind per ki, because its job is to move the rival, not to hurt him |
| `rain.width` | 450 units (6 bh) | As ruled |
| `rain.height` | **900 units** (12 bh), not 1,500 | With the rise below, the first bolt lands a second after the throw, as ruled. From 1,500 it would be 1.4 s |
| `rain.riseTicks` | **45**, not 60 | The same reason: 45 up and 15 down |
| `rain.gap` | **120 units**, not 40 | The bolts land 2 ticks apart, over about 10 ticks, so it reads as rain and not as one flash |
| The mark | Shown for the whole 60 ticks before the first landing | The warning is the rule |
| Where the patch goes | The rival's position at the throw, or up to 6 bh from it by the stick | The director's pick |
| **Can it hit its thrower?** | **Yes, at full damage.** The falling bolts hit whoever is under them | It makes the patch real ground. He can't rain on a clinch for free, and it matches the blast rule, where a shooter is hurt by his own explosion |
| **Rain over a tower** | **It lands on the roof, and that is right.** The mark is drawn on the roof | Shots meet buildings. A fighter under a roof is sheltered, so cover matters, and the roof takes 12 a bolt before the tier factor |
| How often | One rain in the air per fighter, and 6 s between throws | So he can't carpet the lane |
| Counting | The six share one group: one landed bolt toward the barrage's ender | As for the split |
| The carrier | It meets nothing on the way up, as Simulation plans | It is a throw, not a shot at someone |

### What QA checks first

- Blasts stay inside 10 to 25% of match damage with all three on.
- Each kind's share of energy damage. None should pass a third of it.
- The curving shot against a held guard: the guard should still be worth holding, so the curving shot lands for less than a clean charged shot does.
- Rain: how often the thrower is hit by his own (it should be rare, under 5% of rains), and structures lost on roofs at tiers 1 and 2 against the per-tier rates.
