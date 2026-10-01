# Wave 1: the Anti-hero's key strikes, as specs to pose from

Owner: Combat and Choreography. Date: 2026-10-01. Status: parked specs for Animation. Nothing here is loaded or hashed, and no live data changed. The data is `strikes.antihero.wave1.json` in this folder; this sheet is the same content for reading. Plan: `../m0-rich.md` (wave 1 of ten).

**What is here.** 38 key strikes. 34 can be posed now: 11 derive from a family Animation has, and 23 need one contact pose of their own. The 4 tail strikes are held until Orb rules on the tail.

## 1. How to read a row
- **Base.** The key-set family the strike derives from (jab, cross, hook, upper, kick, round). "New pose" means it has a silhouette of its own and needs its contact pose; the chamber and the follow-through come from Animation's weight scaling.
- **Limb to target.** The striking part and the socket it lands on, as `data/anim/sockets.json` names them. The side is not authored: the mirror is free, and with a broken limb the good side plays it.
- **Weight; fills.** Light or heavy, and the strike classes it can fill (opener, mid, ender, return).
- **Reach / contact at.** Reach is Animation's envelope for that limb and socket. "Contact at" is the centre-to-centre distance the sim brings him to for this strike (section 3).
- **Load, follow, recover** in ticks. Load is the piece's shortest anticipation; a template's wind-up stretches it (opener 15 light or 20 heavy, ender 18, mid and return 6), up to twice its length. Follow is the hold after contact. Recover overlaps the next strike's load in a string.
- **Uses.** The limb tags the broken-limb filter reads (section 5).

## 2. Shape language and limits
- **Blades.** At contact the striking limb and the opposite limb make one long straight line through the body. Joints are sharp angles. The torso stays narrow and side-on. Hands are open blades or claws unless the look says a fist. One dominant diagonal per pose, readable at 40 px.
- **Posture.** From the crouch he strikes upward and outward. From Regalia he stands taller and the lines lengthen.
- **Legal's stacking rule** (`docs/design/rule-of-cool.md` section 1, rule 9): no chamber holds clenched fists at his sides in the crouch. Chambers keep the hands open and forward, or one arm drawn back at shoulder height. Animation's stacking lint reads this from the pose.
- **No franchise poses.** Legal screened these specs and they are GO (`docs/legal/rule-of-cool-screen.md`, the wave 1 section). Its conditions are the Legal lines in the rows: the uppercut, the two spins, the double palm, the double hammer, the palm heel, the cross-arm ram and the tail. Every authored pose keeps its `_orig` line and provenance record.

## 3. The contact distance is per strike
Animation's socket table gives each limb its own reach, so one 58 u for every blow no longer fits: an elbow lands at 44 to 50 u at most.

**Height limits the joints.** An elbow, a knee or the head is aimed, not reached with: it cannot rise to a head at its own height (Animation's test key sets, `pose-pipeline.md` section 9.13). So elbows go to the chest or the jaw, never the head's centre, and the headbutt goes to the jaw, bending from the waist.

**The rule.** A strike's contact distance is the smaller of 58 and (its reach minus the limb's step). So the blow lands with the hip lunge and no extra step.

| Band | Contact at | Strikes | Which |
| :--- | ---: | ---: | :--- |
| Long | 58 u | 9 | a hand to the head or chest |
| Mid | 50 to 54 u | 14 | a hand to the gut, every kick, the two-arm thrusts |
| Close | 32 to 38 u | 11 | elbows, knees, the headbutt, the shoulder and the forearm ram |

- **A floor of 32 u** (`clinch`, proposed) for a strike's own step-in. Torsos are about 13 u deep, so at 32 u there is still clear air between them.
- **The headbutt is set by its look, not the rule:** 36 u, so he can hold the rival's arms down. Its reach to the jaw is 56 u.
- **Estimates to measure:** the two-limb strikes (two arms square the shoulders, so I took 8 u off the hand's reach), and the shoulder, which has no row in the socket table yet.

## 4. The strikes

### Fist (one arm)

| Strike | Base | Limb to target | Weight; fills | Reach / contact at | Load, follow, recover | Uses | Look |
| :--- | :--- | :--- | :--- | ---: | ---: | :--- | :--- |
| `jab` | jab | hand to head | light; opener, mid, return | 72 / **58** | 6, 4, 5 | 1 arm | A straight blade hand from the lead shoulder, the arm one line with the rear leg; the body barely turns. |
| `cross` | cross | hand to chest | light; opener, mid | 74 / **58** | 6, 4, 5 | 1 arm | The rear hand driven straight through the chest, hips turned full, the lead forearm guard folded across the ribs. |
| `hook` | hook | hand to head (arm, later) | light; mid, return | 72 / **58** | 6, 4, 6 | 1 arm | A flat, tight arc at head height, the elbow a sharp right angle, the plated forearm leading the hand. |
| `backfist` | hook, new pose | hand to head (arm, later) | light; mid, return | 72 / **58** | 6, 4, 6 | 1 arm | The arm unfolds backhanded to full length, the back of the hand leading, chest opened away from the rival. |
| `palm_heel` | jab | hand to chest | light; mid | 74 / **58** | 6, 4, 5 | 1 arm | A clawed open palm pushed straight in from the ribs, fingers spread like tines, the wrist bent back. **Legal:** the hand stays open, flat or clawed, never cupped; never a hand chambered at the hip for an energy release afterwards. |
| `spear_hand` | cross | hand to gut | light; opener, mid | 68 / **54** | 6, 4, 5 | 1 arm | A low blade-hand thrust from the crouch into the gut, the spine and the arm one long diagonal. |
| `uppercut` | upper | hand to jaw | heavy; opener, ender | 72 / **58** | 10, 6, 10 | 1 arm | A closed fist rising under the chin; the rise is in the hip and shoulder, the feet stay where they are, the other arm low across the body. **Legal:** no leap and no spin: not a jumping, turning uppercut; no fist held up after it as a victory pose. |
| `hammer` | new pose | hand to head | heavy; ender | 72 / **58** | 14, 6, 12 | 1 arm | The fist comes straight down from above the head like a dropped blade, the body folding over it. |
| `overhand` | hook, new pose | hand to head | heavy; opener, ender | 72 / **58** | 10, 6, 10 | 1 arm | A looping blow over the rival's guard, the shoulder rolled high, the head ducked off the line. |
| `haymaker` | hook | hand to head | heavy; opener, ender | 72 / **58** | 12, 6, 12 | 1 arm | The widest swing he has: the arm nearly straight, the whole torso thrown round behind it. |

### Elbow (one arm, close range)

| Strike | Base | Limb to target | Weight; fills | Reach / contact at | Load, follow, recover | Uses | Look |
| :--- | :--- | :--- | :--- | ---: | ---: | :--- | :--- |
| `short_elbow` | new pose | elbow to chest | light; mid | 50 / **38** | 6, 4, 5 | 1 arm | The forearm folded shut and the point of the elbow cut across at collar height: a small, sharp triangle. |
| `rising_elbow` | new pose | elbow to jaw | light; mid, return | 50 / **38** | 6, 4, 6 | 1 arm | The elbow driven up the centre line under the jaw, the hand ending behind his own ear, the plate edge leading. |
| `spinning_elbow` | new pose | elbow to chest | heavy; ender | 50 / **38** | 14, 6, 12 | 1 arm; grounded: needs the other leg | One turn with his back shown, the elbow whipping through level at chest height at the end of it. **Legal:** a single turn; no travelling or multi-hit spin. |
| `dropping_elbow` | new pose | elbow to chest | heavy; ender | 50 / **38** | 12, 6, 10 | 1 arm | From above: the point of the elbow dropped onto the chest, the other hand pinning the rival's guard down. |

### Two arms

| Strike | Base | Limb to target | Weight; fills | Reach / contact at | Load, follow, recover | Uses | Look |
| :--- | :--- | :--- | :--- | ---: | ---: | :--- | :--- |
| `twin_spear` | new pose | both hands to chest | light; mid | 66 / **52** (est.) | 8, 4, 6 | 2 arms | Both blade hands thrust side by side, a hand apart, elbows locked: two parallel lines. |
| `double_palm` | new pose | both hands to chest | heavy; opener, ender | 66 / **52** (est.) | 10, 6, 10 | 2 arms | Both clawed palms shoved in at shoulder width, fingers up, elbows flared wide. **Legal:** a melee strike only: no light, glow or beam leaves the hands, no shouted name, no pause with the palms forward after it; never wrists together, and never chambered as cupped hands at one hip. |
| `double_hammer` | new pose | both hands to head | heavy; ender | 64 / **50** (est.) | 14, 6, 12 | 2 arms | Both forearm guards brought down side by side like a dropped bar; the hands are apart and open. **Legal:** not a two-fisted clasped overhead smash. |
| `cross_arm_ram` | new pose | both elbows to chest | heavy; opener | 50 / **38** (est.) | 10, 5, 12 | 2 arms; grounded: needs the other leg | The forearm guards crossed into a wedge and driven in behind the shoulders, head tucked behind the plates. **Legal:** a strike in motion, never a held crossed-arms power pose. |

### Foot

| Strike | Base | Limb to target | Weight; fills | Reach / contact at | Load, follow, recover | Uses | Look |
| :--- | :--- | :--- | :--- | ---: | ---: | :--- | :--- |
| `front_kick` | kick | foot to gut | light; opener, mid | 64 / **54** | 6, 4, 6 | 1 leg; grounded: needs the other leg | A straight push with the ball of the foot from a high knee, the body leaning back off the line. |
| `side_kick` | kick, new pose | foot to chest | light; mid, return | 60 / **50** | 6, 4, 6 | 1 leg; grounded: needs the other leg | Turned fully side-on, the leg and the opposite arm one horizontal line, the heel leading. |
| `low_kick` | round | foot to legs | light; mid | 60 / **50** | 6, 4, 5 | 1 leg; grounded: needs the other leg | A short chop of the shin into the thigh, his own body upright and still. |
| `snap_round` | round | foot to chest | light; mid, return | 60 / **50** | 6, 4, 6 | 1 leg; grounded: needs the other leg | A quick whip from the knee, the hips barely turned, the foot back before the rival moves. |
| `roundhouse` | round | foot to chest | heavy; opener, ender | 60 / **50** | 12, 6, 12 | 1 leg; grounded: needs the other leg | The full turn of the hips, the leg a long blade through the ribs, the arms thrown back the other way. |
| `axe_kick` | new pose | foot to chest | heavy; ender | 60 / **50** | 14, 6, 12 | 1 leg; grounded: needs the other leg | The leg lifted straight and brought down heel first onto the collar, his body a vertical line beside it. |
| `spinning_heel` | new pose | foot to chest | heavy; ender | 60 / **50** | 14, 6, 12 | 1 leg; grounded: needs the other leg | One turn with his back shown, the heel coming round at the end of a straight leg. **Legal:** a single turn; no travelling or multi-hit spin. |
| `stomp` | new pose | foot to gut | heavy; ender | 64 / **54** | 12, 6, 12 | 1 leg; grounded: needs the other leg | The knee drawn to his chest and the sole driven straight down; his arms spread for balance. |
| `sweep` | new pose | foot to legs | light; mid | 60 / **50** | 8, 4, 8 | 1 leg; ground only | Dropped onto one hand, the other leg scything flat along the ground. |
| `drop_kick` | new pose | both foots to chest | heavy; opener | 60 / **50** (est.) | 12, 5, 14 | 2 legs; air only | Both feet together with the body laid flat behind them, arms back along his sides. |

### Knee (close range)

| Strike | Base | Limb to target | Weight; fills | Reach / contact at | Load, follow, recover | Uses | Look |
| :--- | :--- | :--- | :--- | ---: | ---: | :--- | :--- |
| `short_knee` | new pose | knee to gut | light; mid | 42 / **32** | 6, 4, 5 | 1 leg; grounded: needs the other leg | A short knee from the clinch, one hand on the rival's shoulder, the standing leg straight. |
| `rising_knee` | new pose | knee to gut | heavy; opener, ender | 42 / **32** | 10, 6, 10 | 1 leg; grounded: needs the other leg | The knee driven up as he rises onto the toes, hips thrust through, both hands pulling down. |
| `driving_knee` | new pose | knee to gut | heavy; opener | 42 / **32** | 10, 5, 12 | 1 leg; grounded: needs the other leg | A knee carried in on the end of a run, the body leaning back, the trailing leg straight behind. |

### Head (close range)

| Strike | Base | Limb to target | Weight; fills | Reach / contact at | Load, follow, recover | Uses | Look |
| :--- | :--- | :--- | :--- | ---: | ---: | :--- | :--- |
| `headbutt` | new pose | head to jaw | heavy; ender | 56 / **36** | 10, 5, 10 | head | The masked brow driven into the jaw from the waist, hands holding the rival's arms down. |

### Torso (close range)

| Strike | Base | Limb to target | Weight; fills | Reach / contact at | Load, follow, recover | Uses | Look |
| :--- | :--- | :--- | :--- | ---: | ---: | :--- | :--- |
| `shoulder_check` | new pose | shoulder to chest | light; opener, mid | 44 / **34** (est.) | 6, 4, 6 | neither | A short step and the plated shoulder into the chest, chin tucked behind it, arms close. |
| `body_ram` | new pose | shoulder to chest | heavy; opener | 44 / **34** (est.) | 10, 5, 12 | neither; grounded: needs the other leg | The whole body thrown in behind the shoulder, both feet leaving the ground. |

### Own limb: the tail (held until Orb rules)

| Strike | Base | Limb to target | Weight; fills | Reach / contact at | Load, follow, recover | Uses | Look |
| :--- | :--- | :--- | :--- | ---: | ---: | :--- | :--- |
| `tail_jab` | held | own to chest | light; mid, return | 90 / **70** (est.) | 6, 4, 5 | own limb | The tail whips straight past his hip like a thrown line; his hands never move. **Legal:** a hair, cloth or metal tail, never a furred or reptilian one. |
| `tail_sweep` | held | own to legs | light; mid | 90 / **70** (est.) | 8, 4, 6 | own limb | A low flat arc of the tail under the rival's legs while he stands upright. **Legal:** a hair, cloth or metal tail, never a furred or reptilian one. |
| `tail_whip` | held | own to chest | heavy; opener, ender | 90 / **70** (est.) | 12, 6, 12 | own limb | He turns his back and the tail comes round as one driven lash at chest height. **Legal:** a hair, cloth or metal tail, never a furred or reptilian one. |
| `tail_spike` | held | own to head | heavy; ender | 90 / **70** (est.) | 14, 6, 12 | own limb | The tail rises over his shoulder and stabs down from above. **Legal:** a hair, cloth or metal tail, never a furred or reptilian one. |

## 5. The broken-limb filter
From `docs/design/spec-wounds.md` section 1d, as rules on the `uses` and `ground` tags:
- **A broken arm.** Drop every two-arm piece. A one-arm piece plays on the good arm. Never two arm strikes back to back.
- **A broken leg.** Drop every two-leg piece. In the air a one-leg piece plays on the good leg. On the ground drop every piece that needs the other leg to stand on, and every ground-only piece. Never two leg strikes back to back.
- **The side** comes from the sim's wounds state, not from a hash.

What stays after each break is in `../m0-rich.md` section 2: 12 lights and 10 heavies in the worst case (a broken leg, on the ground).

**Tests** (QA and Encounter): no blow uses a broken limb over 200 forced matches per break; no key strike twice in a string of up to 8 blows; three-strike series repeat in under 10% of strings in forced broken-limb matches.

## 6. What this changes in the contact data (a note; nothing is edited)
The contact slice is live with one distance: `profiles.dynamic.contact.offset` 58 and `reach` 68. In `data/combat/templates.json` 30 moves end at a literal 58 before 25 strike beats, and the finishers have 8 more at 58 or 48.

1. **The step-in ends at the strike's own distance.** When a strike beat names a slot (M0), the move before it and Encounter's placement on the contact tick both read the offset of the piece that fills the slot. The literal 58 stays only as `contact.offset`, the default for an unfilled slot.
2. **`contact.reach` becomes the default too.** Each piece carries its reach, and QA's band changes from "within 68 u" to "within the piece's reach".
3. **A new `contact.clinch`, 32 u.** A strike's own step-in may end that close. Every other move keeps `minSeparation` 45, and after a close blow Encounter's rule 3 moves two resting bodies back apart.
4. **The step is a range step, not only a step in.** After a close blow the next strike may be a long one, so the 6-tick step may open the distance as well as close it. The knockback (35 to 60 u) usually makes it a step in anyway.
5. **A join rule for the composer:** the range band is part of a piece's in-state and out-state, and a phrase changes band at most once. Otherwise he bobs in and out by 24 u between blows.
6. **Until M0 nothing changes in the data,** and Animation's pick lists must hold only hand and foot key sets (they do today). An elbow, knee or head key set played at 58 u would be out of reach. Kicks at 58 u land, but 2 to 6 u from the edge of their envelope; at their own 50 to 54 u they will sit better.
7. **Schema, when it lands (Tools):** `profiles.dynamic.contact.clinch`; in the M0 piece schema `range.reach` and `range.offset`; a check that the offset is at least `clinch` and at least 4 u inside Animation's envelope for that limb and socket.

## 7. Open
| For | What |
| :--- | :--- |
| **Animation** | a `shoulder` limb in the socket table (the shoulder check and the body ram); the two-limb envelopes (four two-arm strikes and the drop kick); an arm socket, so the hook and the backfist can land on an arm for arm wounds |
| **Orb, through Art** | the tail. Four strikes are held. Without an own limb the worst case falls from 12 lights and 10 heavies to 10 and 8: no strike repeats in a string, but three-strike series would repeat in about 15% of strings there, over Game Design's 10% |
| **Legal** | done: GO, with the lines now in the rows |
| **Encounter** | section 6, items 1 to 5, with the composer at M0 |
