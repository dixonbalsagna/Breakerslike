# Wave 5: the pulse clashes and the three beam answers

Owner: Combat and Choreography. Date: 2026-10-01. Status: parked specs for Animation. Nothing here is loaded or hashed, and no live data changed. The data is `clashes.antihero.wave5.json` in this folder. Plan: `../m0-rich.md` sections 6 and 7 (waves 4 and 7 in its table). Rules: `docs/design/rule-of-cool.md` section 2 and `moveset-rules.md` section 11(c).

**What is here.** Three clashes decided on the pulse (the fist clash, the blur exchange, the grapple lock) and the three looks of a perfect block against a signature (swat, split, walk through). 9 new poses for the clashes and 9 for the answers. The clashes are composed from the wave 1 strikes and the wave 4 grabs, so two of them rarely look alike.

## 1. The pulse (Game Design's rule)
- **3 pulses.** Each has an 8-tick window (10 on touch). A press on the pulse is a surge, +10. A press off it misses that pulse and locks the next press out for 20 ticks.
- **The score** starts from state, as the clash does today. The pulses swing it by up to 30.
- **A tie** is a difference under 10: both are thrown back, nobody wins, and the mood gains 8.
- **The AI** hits 40, 65 or 85 pulses in 100.
- **The budget:** one big set piece every 20 s. A second inside it plays as its ordinary version.

## 2. The three clashes

### Fist clash

| | |
| :--- | :--- |
| **Trigger** | a heavy meets a heavy (the HEAVY CLASH template), when the set-piece budget allows |
| **Without the budget** | today's HEAVY CLASH: won, countered or the shockwave, with no pulses |
| **Ticks from the meet** | pulses at 24, 48, 72; resolves at 84 |
| **Distance** | the longer of the two heavies' contact distances (wave 1); each striking limb is solved onto the other's striking limb |
| **Composed: opens** | each fighter's own heavy opener: 10 to choose from |
| **Composed: resolves** | the winner's blow goes through as an ender (the same piece, at full blow weight) and launches by its hint |
| **Between pulses** | the strain: Animation blends pressing and giving by the running score; each surge drives the pair up to 6 u toward the loser's side |
| **On a pulse** | a ring from the meeting point; from tier 3 it damages structures, inside the collateral budgets |
| **Legal** | no cracked-sky or shattered-space effect; the lock is a strain in motion, never a freeze frame on two locked fists |

| New pose | Look |
| :--- | :--- |
| `lock` | The two blows have met and stopped: his limb straight behind the point of contact, shoulder and back leg in one line with it, the other arm wide for balance. Derives from the heavy's own contact pose. |
| `pressing` | Winning: his weight is over the front leg, the limb driving through, his head lowered past the meeting point. |
| `giving` | Losing: bent back at the waist, the front knee folding, the limb collapsing toward his own chest. |

### Blur exchange

| | |
| :--- | :--- |
| **Trigger** | both attacking with strings queued, in Tense or Frenzied, at tier 2 or above, when the budget allows |
| **Without the budget** | the two strings resolve as ordinary exchanges, one after the other |
| **Ticks from the meet** | three bursts with blows at 6, 12 and 18; pulses at 24, 48, 72; resolves at 84 |
| **Distance** | each blow at its own contact distance; the pair travels about 6 bh a burst along a level line clear of structures |
| **Composed: blows** | nine alternating lights (five for the one who started, four for the other) and three pulse blows each, all from the light pool: 16 to choose from, no key strike twice |
| **Composed: resolves** | the winner's ender lands at 84, after a 12-tick wind-up, and launches |
| **Between pulses** | the alternating lights; on each pulse both strike at once and the press decides whose blow gets through |
| **On a pulse** | the blow that got through snaps the other's head or body by the computed reaction; no ring |
| **Damage** | each traded light does x0.5 of a light (Game Design, moveset-rules.md 11(h)); they are mid-string hits with no perfect-block window |
| **Legal** | the bodies stay readable: every blow is a drawn contact pose held 4 ticks or more; never invisible fighters with only shock rings; no freeze on locked fists; no cut to an onlooker who cannot follow |

| New pose | Look |
| :--- | :--- |
| `blur_advance` | Travelling forward while striking: hips square to the line of travel, the body leaning into it, the rear leg trailing straight. |
| `blur_retreat` | Travelling backward while striking: weight on the back hip, the chin tucked, the lead arm already returning to guard. |

### Grapple lock

| | |
| :--- | :--- |
| **Trigger** | two grabs meet in the air, or a dive grab meets a grab; rare (under one a match) |
| **Without the budget** | none: two grabs that meet are always the lock |
| **Ticks from the meet** | pulses at 30, 60, 90; resolves at 102 |
| **Distance** | 36 u, the hold's distance (wave 4); each is held by the other |
| **Composed: opens** | both reaches (wave 4) |
| **Composed: resolves** | the winner throws the loser down: the drive down, or the spike with one arm |
| **Between pulses** | the strain: the pair turns a quarter turn about the grip and sinks about 1 bh over the lock |
| **On a pulse** | a wrench: the surging fighter turns the other's shoulders a step further |
| **Legal** | a collar-and-elbow tie-up only: no hands locked at all, laced or not, and no arms raised overhead in a test of strength; no sparks, glow or energy at the hands |

| New pose | Look |
| :--- | :--- |
| `tieup` | A collar-and-elbow tie-up: one hand behind the rival's neck plate, the other on the elbow, foreheads close, backs flat. |
| `tieup_over` | Winning: he has driven over the top, the rival's head under his shoulder, his hips high. |
| `tieup_under` | Losing: folded under, one knee dropping, his grip sliding from the collar to the forearm. |
| `tieup_one_arm` | With a broken arm: the forearm guard of the good arm across the collar, his shoulder set against the rival's chest. |

**Broken limbs.** The fist clash and the blur exchange draw from what he can still throw, so they follow wave 1's filter. The grapple lock has a one-arm tie-up, and its winner's throw is the spike.

## 3. The three beam answers
A perfect block against a signature is DEFLECT in the live data. The direction held on that press picks the look. All three cost no ki and take no damage, and give +8 ki with no stagger and no riposte.

**Ticks.** In: 6. Hold: as long as the beam lasts. Out: 6.

| Answer (held) | Arms | What the sim does | Poses | Legal |
| :--- | :--- | :--- | :--- | :--- |
| **Swat** (`away`) | one | the beam is turned aside and carves where the game sends it; the damage counts against the beam's tier cap and is credited to him | in: side-on, the plated forearm drawn across his chest; hold: the forearm swept out to full length, the whole body turned with it, the beam bending off the plate; out: the arm still out, the head already turned back to the rival | a plated-forearm sweep with the whole body turning: not a casual flick of one hand, and kept away from an open palm |
| **Split** (`neutral`) | none | the beam parts round him and scars the ground on both sides behind him | in: he turns side-on, the plated shoulder and spine to the beam; hold: leaning into it on the plates, head turned away, hands open at his chest; out: he straightens and turns back, plates smoking in his own violet | it parts on the shoulder and spine, with his hands open at his chest; no crossed arms |
| **Walk** (`toward`) | none | he advances through the beam and arrives at contact distance in front of the attacker, who is 20 ticks into recovery | in: upright, chin level, hands open and low; stride: one unhurried step, mirrored for the next, the beam breaking round his chest; arrive: stopped at arm's length, weight even, looking at the rival | upright, hands open and low, unhurried: no palm held out against the beam, no arms crossed, no clenched fists; no shouted line |

- **Legal, for all three** (`rule-of-cool.md` section 3b): no named technique and no borrowed hand pose; a swatted beam does not end in a mushroom cloud staged like a known scene.
- **All three work with a broken arm:** the swat uses the good arm, and the other two use none.
- **Where the swat sends the beam** is the game's pick, by personality (Game Design). His look does not change with it: he does not watch where it goes.

## 4. What this needs
| For | What |
| :--- | :--- |
| **Animation** | the 18 new poses; the strain blended by the clash score; a strike solved onto the rival's striking limb; the tie-up with both held |
| **Encounter** | a `pulse` beat op; the three clash timelines; the fist clash and the blur exchange filled from the pools; the look on the DEFLECT outcome from the direction held |
| **Simulation** | the clash score readable each tick, or an event per pulse; the `held` state both ways |
| **Controls and UI** | the pulse shown and heard (theirs already) |
| **VFX** | the pulse ring with no cracked sky; the bent, the parted and the breaking beam; afterimages that never hide a body in the blur exchange |
| **Camera** | the blur exchange's travel (about 18 bh over the three bursts) without a cut to an onlooker |
| **Game Design** | done: the traded lights are x0.5 of a light (`moveset-rules.md` section 11(h)) |
| **Legal** | done: GO (`docs/legal/rule-of-cool-screen.md`, the waves 5 and 6 section), with its lines in the rows |
| **Tools** | tempo names `pulseFist` 24, `pulseBlur` 24, `pulseGrapple` 30, `answerIn` 6, `answerOut` 6 |
