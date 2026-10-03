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
| **His extra kinds** | The **splitting shot**, and later the curving shot | The **shard spread** and **rain**, and his barrage volley special |

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
