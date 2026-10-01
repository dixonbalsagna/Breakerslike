# Wave 7: the first kit

Owner: Combat and Choreography. Date: 2026-10-01. Status: parked specs for Animation. Nothing here is loaded or hashed, and no live data changed. The data is `kit.antihero.wave7.json` in this folder. Plan: `../m0-rich.md` section 9 (wave 6 in its table).

**What is here.** The first things that are his alone: 3 specials (his default loadout), his 2 first place signatures, and 6 showcases. They need 24 authored sketches (7 for the specials, 6 for the signatures, 11 for the showcases); Animation generates the rest. Almost all of it is built from waves 1 to 6, so each piece adds an entrance, a held moment or an exit, not a new set of blows. The tail whip showcase is specified but held, so the coil and strike stands in as the sixth.

## 1. The rules they follow
- **Specials** (`docs/design/moveset-rules.md` section 1). A loadout of 3. The power trigger and a face button queue one, and a funded press fires at the next exchange boundary. 15 to 30 ki and a 25 s cooldown each. The director picks the variant from the place, the distance and his form; the player never does.
- **Signatures** (sections 2 and 11(a)). 45 ki, a shared 120 s cooldown, a 48-tick charge that is the tell. Which one fires: the unrestrained state's, then a revealed one, then his current form's, then these two place signatures.
- **Showcases** (`../moveset-system.md` section 2). At most 12 in 100 exchanges, not the same one twice within about 2 minutes, never two running. Each is fitted to its template's contact tick, so a showcase never moves a hit.
- **Names.** He shouts a special's or a signature's name once, short; there is no name card. Every label here is a working label for Narrative and Legal.
- **Legal.** The lines below are Combat's proposals, except where they repeat an earlier verdict. The stacking rule applies to every charge and every crouch.

## 2. The three specials

### Barrage volley

Both arms open through a half turn of the body and a fan of shards leaves along the sweep.

| | |
| :--- | :--- |
| **Mode** | energy |
| **Ki** | 20 (proposal) |
| **The rival's answers** | a heavy blast: a perfect block in the last 10 of its 20-tick gather deflects the whole fan; a guard takes it at the guard's rate; a dodge slips it |
| **Limbs** | 2 arms; with one arm: a one-arm sweep, 5 shards, x0.8 |

| Phase | Ticks | What happens |
| :--- | :--- | :--- |
| Gather | 20 | the wind-up: both arms drawn to one side at shoulder height, the body coiled away, the forearm plates lit |
| Sweep | 18 | the arms open through the half turn; a shard leaves every 2 ticks: 9 in all |
| Hold | 6 | side-on, both arms in one line |
| Recover | 12 |  |

- **By range:** under 300 u: a tight fan that ends in the ring; 300 to 1,200 u: the full fan of shards; over 1,200 u: darts in place of shards, in a narrower fan.
- **By situation:** air: the fan's plane tilts to the rival's height; ground: the fan skims the ground; wall: one arm, braced off the surface; water: the fan cuts a line of spray.
- **By form:** Regalia: two fans, one behind the other; Sovereign and Apex: the shards that circle him join it, and his arms sweep half as far.
- **By direction:** toward: fired on the advance; neutral: planted; away: backing off.
- **Builds on:** the shard shape, the volley shape, the burst shape.
- **Sketches (3):** gather: coiled away, both hands at shoulder height on one side; mid-sweep: arms wide, chest open, head following the leading hand; end: side-on, one line through both arms.
- **Legal:** the volley's rules: one sweep, never both palms pumping forward in turn, no shouted barrage with an open mouth; the hands are never wrists together and never drawn to a hip; the name is shouted once, before the sweep.
- **Proposal for Game Design:** the count grows with Pride like the poke: 9, 11, 13, 15, for the same total, counted as one landed strike.

### Cutting step

A sudden change of level, up or down, and a wide cutting blow as he arrives.

| | |
| :--- | :--- |
| **Mode** | physical |
| **Ki** | 15 (proposal) |
| **The rival's answers** | a heavy opener: a perfect block in the last 10 ticks before contact; a guard blocks it; a dodge avoids it |
| **Limbs** | the cut's own limbs; on the ground the step needs both legs, so with a broken leg he takes off first |

| Phase | Ticks | What happens |
| :--- | :--- | :--- |
| Tell | 15 | the heavy tell; he sinks or lifts a fraction |
| Step | 6 | about 1 bh up or down, drawn the whole way, ending at the cut's contact distance on his own side |
| Cut | contact at 21 | an across heavy he can still throw: haymaker, roundhouse, spinning heel, spinning elbow or the tail whip |
| Launch | 3 after | across |
| Recover | 12 |  |

- **By range:** in reach: tell, step, cut; out of reach: a dash, with the step in its last 6 ticks; over 1,200 u: an arc or a spiral first, once the rush has paths.
- **By situation:** air: up or down, whichever side has more room; ground: a hop over a low line or a drop under a high one; wall: he kicks off the surface, so the step is out from the wall; water: he breaks the surface upward.
- **By form:** Regalia: the cut is the edge of the forearm plate; Sovereign and Apex: upright, and the step is a glide.
- **Builds on:** `haymaker`, `roundhouse`, `spinning_heel`, `spinning_elbow`, `tail_whip`, `dash`.
- **Sketches (2):** the fold: mid-step, the body compact, knees drawn up, arms tight to the chest; the arrival: a low wide base, the cutting limb loaded behind him.
- **Legal:** he is drawn the whole way: no vanish and no afterimage that hides him; a spinning cut is a single turn.
- **Proposal for Game Design:** what makes it a special: the step takes him off the line, so a strike already coming at him misses. It beats an attack in progress, where an ordinary heavy trades.

### Grip and drag

A grab at speed, a drag along the ground on the rival's back, and a throw.

| | |
| :--- | :--- |
| **Mode** | physical (a grab) |
| **Ki** | 25 (proposal) |
| **The rival's answers** | the grab rule: it beats Guard, Neutral and Power; an attack in progress stuffs it; a dodge makes it whiff, with 30 ticks of recovery |
| **Limbs** | 1 arm; with a broken arm it still works, at x0.8 |

| Phase | Ticks | What happens |
| :--- | :--- | :--- |
| Lunge | 10 | the reach, inside the last 10 ticks of the rush |
| Hold | 4 | the grip sets |
| Pull-down | 12 | he hauls the rival down to the ground, from up to 4 bh |
| Drag | 30 to 48 | along the ground, the rival on their back: World's slide, and a trench by tier |
| Throw | 1 | the sling or the spike; a launch at x0.8 of a heavy |
| Recover | 12 |  |

- **By range:** in reach: straight to the reach; out of reach: a dash, or a skid on the ground.
- **By situation:** ground: as above; air, the ground within 4 bh: the pull-down, then the drag; air, higher: no drag: a 20-tick dive carrying the rival, then the spike; wall: the drag runs along the wall's face, then he throws off it; water: along the surface, skipping.
- **By form:** Regalia: upright, one-handed, not looking back; Sovereign and Apex: he glides above the ground while the rival trails on it.
- **Builds on:** `lunge`, `hold`, `sling`, `spike`, `dive_spike`, `dash`, `skid`.
- **Sketches (2):** the pull-down: turned away, the gripping arm hauling down past his knee; the drag: a low run, the gripping arm straight behind him, the rival on their back.
- **Legal:** Legal's grab rules: the grip is on the collar or an arm, never the throat, the face or the hair. The rival is dragged on their back: never face down along the ground or a wall, and never by a tail.
- **Needs:** the held state (wave 4); World's slide and trench; ground contact.

## 3. The two place signatures

### Sweeping line

His beam is a thin flat blade of light swept across the rival like a stroke, not a column he holds.

| | |
| :--- | :--- |
| **Mode** | energy |
| **Ki** | 45, on the shared 120 s cooldown |
| **The rival's answers** | every beam answer: a beam for a struggle on the pulse, a heavy blast at -10, a perfect block (swat, split or walk), guard, dodge, the escape gamble |
| **Limbs** | 1 arm; with a broken arm, x0.8 |

| Phase | Ticks | What happens |
| :--- | :--- | :--- |
| Charge | 48 | the tell: side-on, the firing arm drawn back at shoulder height, plates stacking along the forearm and lit down the spine; the name once, short |
| Stroke | the beam's life | the line starts off the rival and sweeps through about 35 degrees across them |
| After | 12 | he holds the end of the stroke while the line fades from his hand outward |

- **By place:** ocean (HORIZON CLEAVE): a level stroke along the sea; the water closes; city (BOULEVARD RAZE): the stroke runs down a street; forest (FIRESTORM): a low stroke, the canopy burning behind it; mountains (RIDGE BORE): an upward stroke that bores the ridge; desert (GLASS TRENCH): a downward stroke that leaves glass; elsewhere (MERIDIAN SCAR): a level stroke.
- **By altitude:** high: the stroke comes down onto the ground; low: level; on the ground: it starts along the ground and rises.
- **By outcome:** hit: it carries the rival along the stroke and launches them at its end; guard: the line splits on the guard and pushes back; dodge: it carves on behind.
- **Builds on:** `charged_brace`.
- **Sketches (3):** stroke start: the arm forward and low, blade hand, the body still coiled; stroke end: the arm swept through, the whole body turned after it; after: the arm half lowered, his head still on the rival.
- **Legal:** one blade hand at shoulder height: never cupped hands, never at a hip, no ball of light in a palm; the name is never drawn out over the charge; the aura is a thin outline in his violet, with no flame and no lightning; no more than two marks in the charge.

### Ground shatter

He drives the plated forearm into the ground and a line of shards erupts along it to the rival.

| | |
| :--- | :--- |
| **Mode** | energy |
| **Ki** | 45, on the shared 120 s cooldown |
| **The rival's answers** | as any signature. A perfect block here plays the split, since there is no beam to swat or walk through (a question for Game Design) |
| **Limbs** | 1 arm; with a broken arm, x0.8 |
| **Offered** | only when the rival is within 4 bh of the ground and he is within 12 bh of it; otherwise the sweeping line |

| Phase | Ticks | What happens |
| :--- | :--- | :--- |
| Charge | 48 | the tell: he rises a body length, or dives to the ground from the air, the forearm plate lit along its edge |
| Slam | at 48 | the edge of the forearm driven into the ground: the hammer's blow, one arm |
| Wave | 45 at most | shards erupt in a line along the ground toward the rival and come up under them |
| After | 12 | he stays over the blow, then straightens |

- **By place:** the shared material table: rock splits, sand fountains, a street lifts its paving, water throws a line of spouts.
- **By altitude:** he is on the ground: the slam where he stands; he is up to 4 bh up: a drop and the slam; he is 4 to 12 bh up: a dive during the charge, then the slam.
- **By outcome:** the rival in the air: the eruption lofts them; the rival on the ground: it throws them across.
- **Builds on:** `hammer`, the shard shape, `arc_dive`.
- **Sketches (3):** charge: risen, side-on, the forearm raised with its lit edge down; slam: the forearm's edge in the ground, both feet planted wide, the other arm a straight line behind him; after: still bent over the blow, head up toward the rival.
- **Legal:** not a landing on one knee and one fist with the head bowed; the cracks run away from him in a line: no ring of rubble rising round him, no lightning, no scream held over the charge.
- **Needs:** World: the crack line and the eruptions by material; the arc on the rush, for the dive.

## 4. The six showcases, and the one that is held

### Dismissive backhand

He looks away and lands the backhand without watching it.

| | |
| :--- | :--- |
| **Where it plays** | the last blow of a light exchange he wins cleanly |
| **Gates** | Pride 50 or more, or a Calm mood; the rival not on the brink |
| **Contact at** | 58 u (the backfist) |
| **Limbs** | 1 arm |

| Phase | Ticks | What happens |
| :--- | :--- | :--- |
| Glance | 6 | his head turns away from the rival |
| The blow | on the template's contact tick | the backfist lands without his looking |
| Pause | 12 | he stays turned away, the arm still out: he cannot act, and a riposte lands |
| Recover | 6 |  |

- **By form:** Regalia and up: he is upright, and the pause is longer by 6.
- **Builds on:** `backfist`.
- **Sketches (2):** contact: the backfist at full length, his face turned the other way; the pause: the arm lowering, chin up.
- **Legal:** no beckoning, no arms crossed, and not a flick of one finger.

### Seal break

The Proud front gives way in one beat: his posture drops and the wear shows.

| | |
| :--- | :--- |
| **Where it plays** | a reaction: the hit that humbles him while the Proud front is up |
| **Gates** | once each time the front breaks |
| **Contact at** | none: he is the one struck |
| **Limbs** | none |

| Phase | Ticks | What happens |
| :--- | :--- | :--- |
| Struck | 6 | the computed reaction at full strength |
| The drop | 12 | he falls from his carriage into the crouch, one hand reaching for the ground |
| The look up | 12 | crouched, shoulders heaving, the head rising to the rival; the wear layers come on at once |

- **By form:** from an upright form the drop is further and reads more.
- **Sketches (2):** the drop: mid-fall, one hand reaching down; the look up: crouched, head raised, breathing hard.
- **Legal:** no glowing-blood look, no scream, and none of the crouch's banned effects (ground-crack, rising rubble); the sigil dims, it does not flare.

### Overhead hammer

He rises over the rival and drops the hammer, then stays folded over the blow as they go.

| | |
| :--- | :--- |
| **Where it plays** | an ender or a deciding blow whose launch is down (the drive) |
| **Gates** | a heavy or an ender; the hammer still open to him |
| **Contact at** | 56 u (the hammer) |
| **Limbs** | 1 arm |

| Phase | Ticks | What happens |
| :--- | :--- | :--- |
| Rise | 4 | half a body above the rival's line |
| The blow | on the template's contact tick | the hammer at full blow weight |
| Hold | 8 | folded over the blow, the arm pointing down the line the rival left on |
| Recover | 10 |  |

- **By situation:** near the ground: the hold is over the crater's edge.
- **Builds on:** `hammer`.
- **Sketches (2):** the rise: above the rival, the fist high behind his head, the body arched; the hold: folded over, the arm straight down the launch line.
- **Legal:** one fist, never two clasped; no fist held up afterwards.

### Rising spear

A blade hand driven up under the ribs carries the rival upward before the loft.

| | |
| :--- | :--- |
| **Where it plays** | a chain's ender when the launch is up |
| **Gates** | an ender; a clear 3 bh above |
| **Contact at** | 54 u (the spear hand), then carried at it |
| **Limbs** | 1 arm |

| Phase | Ticks | What happens |
| :--- | :--- | :--- |
| The blow | on the template's contact tick | the spear hand to the gut |
| Carry | 12 | he rises 3 bh with the rival on the hand |
| Release | 1 | the arm straightens and the loft begins |
| Lower | 8 | he stops and the arm comes down |

- **By situation:** under a ceiling of cloud or the flight limit: the carry shortens.
- **Builds on:** `spear_hand`.
- **Sketches (2):** the carry: his body a vertical line under the rival, the blade hand above his head; the release: the arm at full length, then lowering.
- **Legal:** a blade hand and a straight rise: no spin, no leap with a fist; the arm lowers at once: no pose held with the arm up.
- **Needs:** a carried pair: the held state, or a move that takes both fighters up together.

### Tail whip (held: the tail)

He turns his back and the tail comes round as one driven lash.

| | |
| :--- | :--- |
| **Where it plays** | an ender whose launch is across |
| **Gates** | an ender |
| **Contact at** | about 70 u (estimated) |
| **Limbs** | the own limb |

| Phase | Ticks | What happens |
| :--- | :--- | :--- |
| Turn | 8 | he shows his back |
| The blow | on the template's contact tick | the tail whip |
| Hold | 6 | back still turned, the tail settling |

- **Builds on:** `tail_whip`.
- **Sketches (2):** the turn: back shown, the tail drawn out behind; the hold: looking back over his shoulder.
- **Legal:** a hair, cloth or metal tail, never a furred or reptilian one; no more than half a turn.

### Hand finish

The finisher's last blow: he walks in, unhurried, and ends it by hand.

| | |
| :--- | :--- |
| **Where it plays** | the finisher called the verdict, after the contest is won |
| **Gates** | a finisher only |
| **Contact at** | the chosen blow's own distance |
| **Limbs** | the chosen blow's limbs |

| Phase | Ticks | What happens |
| :--- | :--- | :--- |
| The walk | 40 to 90 | upright, hands open and low, straight at the rival |
| The stop | 20 | in front of the rival, looking down: the finisher's anticipation |
| The blow | 1 | a heavy he can still throw, by hand or elbow, never a beam |
| The held pose | open | the arm lowered, turned half away; it hands over to the winner's stand |

- **By form:** Apex: the walk is replaced by a long stillness (the single blow shape).
- **Builds on:** `walk`, `hammer`, `haymaker`, `overhand`, `dropping_elbow`.
- **Sketches (2):** the stop: looking down at the rival, weight even; the held pose: turned half away, the striking arm lowered.
- **Legal:** no speech with a body aura; no fist held up; the held pose is not arms crossed.

### Coil and strike

The deepest crouch, a beat of perfect stillness, then one uncoiling blow.

| | |
| :--- | :--- |
| **Where it plays** | the opener of the first exchange after a transformation or at the start of a new act |
| **Gates** | on the ground or a wall; both legs |
| **Contact at** | the blow's own distance |
| **Limbs** | both legs for the spring |

| Phase | Ticks | What happens |
| :--- | :--- | :--- |
| Coil | 12 | the crouch, held perfectly still |
| Spring | the approach | flat and low at the rival's middle |
| The blow | on the template's contact tick | the spear hand or the shoulder check |

- **By form:** Sovereign and Apex: he lowers himself into it from the float, which reads as a choice.
- **Builds on:** `coil_spring`, `spear_hand`, `shoulder_check`.
- **Sketches (1):** the arrival: one line from the back foot to the fingertips.
- **Legal:** the crouch keeps one hand on the ground and the other open: never clenched fists at his sides; no scream, ground-crack or rising rubble.

## 5. Broken limbs
- **A broken arm:** the barrage becomes a one-arm sweep of 5; the cutting step and the hand finish pick a blow he can still throw; the grip and drag and both signatures are one-armed already, at x0.8. The dismissive backhand, the overhead hammer and the rising spear play on the good arm.
- **A broken leg:** nothing changes in the air. On the ground the cutting step starts with the slow take-off, and the coil and strike is not offered.

## 6. What this needs
| For | What |
| :--- | :--- |
| **Animation** | the 24 sketches; a head turned away on cue (the dismissive backhand); the wear layers switched on at a beat (the seal break) |
| **Encounter** | the special queue firing a phrase at the exchange boundary; variant choice by range, place and form; showcases fitted to the contact tick with their gates; a carried pair for the rising spear |
| **Simulation and World** | the held state; the slide and trench under the drag; the crack line and eruptions for the ground shatter |
| **Game Design** | the three ki costs (20, 15, 25); the barrage's count by Pride; whether the cutting step beats an attack in progress; the perfect block's look against the ground shatter |
| **VFX** | the swept line and its fade; the erupting shard line by material; the dimming sigil |
| **Narrative** | names for the three specials and two signatures |
| **Legal** | a screen of this sheet's lines |
| **Orb, through Art** | the tail (the tail whip showcase and one of the cutting step's cuts) |
