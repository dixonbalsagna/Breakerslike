# The launch pair: what each fighter ships with

Owner: Combat and Choreography. Date: 2026-10-02. Status: a go-live plan with parked data (`pending/launch-pair.json`). No live data and no code. Game Design's plan (`docs/design/launch-pair-plan.md` section 8) adopted the energy split, ships Blow for Blow with the framework and asked for one finisher per fighter (section 6). Legal cleared the plan (RL-063 to RL-065); its two tweaks are written in.

**Orb's next update** (`docs/ep/vision.md`, last section): two fighters, the Protagonist and the rival (the Anti-hero), replace the KAI and VORR placeholders; the expanded energy blasts; the framework of the alchemy layer. Orb supplies the names.

**The rule for this plan:** ship the least that makes each fighter feel like himself in every exchange, then grow by data. Counts are authored sketches; Animation's tools generate the wind-ups, follow-throughs and variants (wave 1: 23 sketches became 117 poses, about 25 minutes of Orb's review). Every new pose is authored inside `docs/animation/joint-limits.md`.

---

## 1. What is posed today

| Set | For | Poses | What it holds |
| :--- | :--- | ---: | :--- |
| `poses.json` | both | 103 | the base: stances, flight, guard, the six placeholder key sets, the elbow, knee and headbutt sets, reactions |
| wave 1 | the Anti-hero | 120 | his 34 strikes (the 4 tail strikes wait on the tail) |
| wave 2 | the Anti-hero | 62 | his 15 entries |
| step 3 | both | 32 | perfect block, reversal, dodge-cancel, burst, the staggers |
| agency 1 | both | 12 | the two charges and the feint's stop, the three knock-backs, the far taunt, staying in a crater |
| energy 1 | both | 8 | laying a mine, the spray cone's kick, the swat |
| ground 1 | both | 16 | bounces, get-ups, the tech flip, the lip launch, the tumble brace |
| intro 1 | both | 11 | the entrance and the staredown |
| last stand 1 | both, by shape | 15 | the last stand's rise for each shape, and the slump |

**So the shared layer is already there.** Both fighters can guard, block, dodge, burst, charge, slide, tumble, get up, enter and stand their last stand today. What tells them apart is their blows, their entries, their energy and their own moves, and only the Anti-hero has any of those posed.

## 2. The Anti-hero

### 2.1 Ships in this update (the minimum that makes him himself)
| Piece | Status | New sketches |
| :--- | :--- | ---: |
| **His 34 strikes** (wave 1) | posed. They play through the alchemist's pieces when the framework is in, and through go-live step 1's pick lists until then. The body ram, re-posed shoulder first, sits at 38 u (at 34 the heads met) | 1: the body ram, redesigned |
| **His 11 straight entries** (wave 2) | posed. The arc dive, the skid and the spiral wait for curved flight; the lane step for fight lanes | 0 |
| **His energy, the barrage** (wave 6, the part this update needs) | the 13 strikes that emit reuse their wave 1 poses. New: the six hands, the charged brace (two), the kiting turn | 9 |
| **His two energy kinds:** rain and the splitting shot (section 4) | the splitting shot leaves from the charged brace; the rain needs its upward throw | 1 |
| **On the Chin** (section 5) | his own move, which Orb picked | 6 |
| **Blow for Blow** | ships with the alchemy framework (Game Design); the set piece Orb asked for (`alchemist-recipes.md` section 2) | 3 |
| **His base finisher, by hand** (section 6) | | 3 |
| **Total** | | **23** |

### 2.2 Later, in this order
1. **The clashes and the beam answers** (wave 5): when the pulse is in. The live game already has the heavy clash.
2. **The ping-pong** (wave 3) and the three curved entries: when curved flight is in.
3. **Grabs and throws** (wave 4): when the held state is in. With them, the grip and drag special.
4. **His first kit** (wave 7): the specials when they have their button; the showcases when the director picks pieces; the sweeping line when Orb decides on beams ("I want the energy combat system to be implemented before I make any more decisions on energy beams").
5. **The rest:** the other kit, his taunts' meter, the finishers, the form cinematics, the tail pieces after Orb's ruling.

## 3. The Protagonist

He has nothing of his own posed. KAI's blows today are the six placeholder key sets.

**Who he is, for the pieces** (`docs/ep/vision.md`, the four fighters; `moveset-rules.md` section 10.4): an earnest martial artist with a huge hand-to-hand repertoire; heat that builds to Boiling, then Open Hand, his transformation; an all-out energy finisher; Art's shape family for him is circles, capsules and ring arcs, and Animation's shape for him is P, the rolled ball. Where the Anti-hero's lines are blades, his are arcs: round kicks, open hands, blows that come round rather than straight.

### 3.1 How he gets a full set cheaply
- **The grammar is shared.** The alchemist's styles, the trade beats, the endings, the charges and Blow for Blow are fighter-neutral; each fighter fills them from his own pieces.
- **Wave 1's 34 strike slots are re-posed for his body,** as deltas: the same blows with open hands and rounder arcs, played on his profile (bouncy, open). Animation's estimate for a further fighter is about 30 deltas. I count 12 that must change silhouette to read as his (the hand strikes and the round kicks); the rest re-use the rival's contact with his profile.
- **8 strikes of his own** give him an identity core no one else has. Their full rows (range, ticks, classes, the `sends` and `ends` tags) are in `pending/strikes.launchpair.json`, replacing the rows Animation borrowed from wave 1 slots:

| His strike | Limb to target | Weight | Sends | Look | Inside the joint limits |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Palm push | hand to chest | heavy | across | one open hand driven from the shoulder, the other hand open at his own chest | the elbow short of 160 degrees |
| Ridge hand | hand to head | light | turned | the edge of the open hand swung round in an arc | the upper arm's twist inside 100 degrees |
| Rising palm | hand to jaw | heavy | up | the heel of an open hand lifted under the jaw, the body rising behind it | no leap; the arm lowers at once |
| Knife-hand chop | hand to the arm (`arm_r`) | light | down | a short downward chop with a flat hand | the elbow bent through the chop |
| Hammer-fist | hand to head | light | down | the bottom of the fist brought down: a return blow that sends down, which the juggle needs | no arm straight back in the load |
| Crescent kick | foot to chest | heavy | turned | a straight leg swept round from the inside out | the hip inside 105 degrees out |
| Hook kick | foot to chest | light | turned | the heel hooked back round from beyond the target | the knee folds one way, to 155 degrees |
| Spinning back kick | foot to gut | heavy | across | one turn and a straight kick with the heel | a single turn; the thigh at most 45 degrees back in the turn's load |

- **Kicks stay at chest height and below,** as wave 1's do: Animation measured that a foot cannot reach a head from a neutral stance.
- **Entries:** wave 2's 15 slots as deltas (about 6 change silhouette), and 2 of his own: an air roll and a cartwheel step on the ground. Both read as circles. The air roll has a rush's timing (4 ticks to start, the travel by distance, 4 to arrive); the cartwheel step has 18 ticks of travel and 4 to arrive. **The air roll** (Legal) is a tumble that opens into the blow, limbs extended, at most one revolution: never a tight spinning ball.

### 3.2 Ships in this update
| Piece | New sketches |
| :--- | ---: |
| 8 own strikes | 8 |
| Strike deltas that must change silhouette | 12 |
| 2 own entries, and entry deltas | 8 |
| His energy: two hands of his own (an open palm thrust from the shoulder; a ring hand, the fingers curled round an arc) and his charged brace | 4 |
| His energy kind: the curving shot (section 4) | 1 |
| His finisher, the flight version (section 6) | 4 |
| **Total** | **37** |

### 3.3 Later
His heat beats and the Open Hand cinematic (with the forms system), his specials and signatures, his finisher, his showcases, his gathering of fragments (the fold). **Two open points for Orb, through the EP:**
- **Teleports.** Orb's concept gives him "strategic teleports mid-attack", and teleporting is on hold until Orb decides whether it belongs to one fighter. He is the natural owner. Nothing here uses a teleport.
- **His finisher** flies for now (section 6); a teleported flurry can be a variant later.

## 4. Each fighter's energy kinds

Game Design's first three (`docs/design/agency-pass.md` section 15.5) are the splitting shot, the rain and the curving shot. Mines and the spray cone belong to everyone.

| Fighter | Kind | Why him |
| :--- | :--- | :--- |
| **Anti-hero** | **Rain** (first) | He bombards until the rival submits: a spread falling on a marked patch tells the rival where he may not stand, which is his hierarchy made playable |
| **Anti-hero** | **Splitting shot** (second) | His barrage in one press: one charged shot bursts into five shards, punishing a dodge made late, which suits his patience and his contempt |
| **Protagonist** | **Curving shot** (first) | A martial artist's precision: he sets the side with the stick and bends the shot round cover or round the front of a guard, and it draws his arcs in the air |
| **Protagonist** | **Ricochet shot** (later, Legal: GO) | A bank shot off the ground or a wall: the craftsman's version of the same idea |

**Legal's rules for these** (`docs/legal/agency-pass-screen.md`, RL-062), as the poses must follow them:
- **Rain:** the upward throw is one arm with the plates lit, never both hands raised overhead holding a growing orb. It falls from above and never encloses the rival.
- **Splitting shot:** five bolts in a cone, from a charged shot. No hands spread wide as the cue: the split is the shot's, not a gesture.
- **Curving shot:** steered by the stick only, never by a finger or a sweep of the hand. Nothing surrounds the rival or closes in on command. So his release is a still, flat palm, and the curve shows in the shot.
- **For all three:** the shot's core stays in the shooter's lane colour; the explosion may be fire-coloured; no shouted name.
- **Not assigned:** the burning wake and the shield orb are conditional with Legal, and neither fighter needs them for this update.

## 5. On the Chin, as a staged piece

**What it is** (Orb's own idea, `docs/design/pitches.md` section 7b): "The rival plants his feet, opens his arms and lets the opponent hit him." Orb picked it on 2026-10-01. Its rules are Game Design's (`docs/design/spec-wounds.md` section 3); this is the staging.

### 5.1 The rules it stages
- **The prompt:** Pride 60 or more, free, not guarding, not on the brink, off cooldown. **The input:** hold the context button for 12 ticks; a tap is still the ordinary context action.
- **The stance** lasts while held, 4 s at most. It absorbs up to 3 ordinary hits, or 1 signature, which ends it. Nothing launches, staggers or moves him.
- **What it costs him:** movement, guard, dodge, attacks and the burst. Letting go early costs 20 ticks of recovery. A 25 s cooldown follows.
- **What it gives him:** the blow's full damage toward Pride, only the reduced damage as wear, on his head and core.
- **The counterplay:** a grab or a tackle beats it at full damage and humbles him.

### 5.2 The beats
| Beat | Ticks | What we see | Pose |
| :--- | :--- | :--- | :--- |
| **The plant** | 12 (the hold) | his feet set wide, his arms open a little forward and slightly below shoulder height, palms open, chin level, eyes open on the rival. Not a flat cross. The crouch is gone: he stands tall for it | `chin.plant` |
| **The stance** | up to 240 | still and rigid, as his shape is, breathing through the Proud front; his eyes on the rival | `chin.plant`, with the idle and wear layers |
| **A hit absorbed** (up to 3) | 6 | the computed reaction at a fifth of its strength: the head turns a little and comes back; the feet do not move | none: computed |
| **The acknowledgement** | 6 after each hit | a small lift of the chin, never a head thrown back. Each one is a little slower than the last | `chin.lift` |
| **The absorb completed** (the third hit) | 18 | he lowers his arms and rolls his shoulders, done with it | `chin.done` |
| **A signature absorbed** | 90, from the pause bank | the beam breaks on his chest and plates, arms still open; it ends and smoke comes off the plates; a hold for one line of bravado. When the bank cannot cover it, it plays live with a camera cut | `chin.beam_in`, `chin.beam_out`, `chin.bravado` |
| **Let go early** | 20 | he drops out of it, off balance for a moment | none: blended back to his stance |
| **Thrown out of it** | as the throw | the grab beats it, and the seal break plays as he lands: the Proud front cracks | wave 7's seal break |

### 5.3 The six poses, inside the joint limits
- `chin.plant`: arms open a little forward of the body line and slightly below shoulder height, never a flat cross and never behind the body (the shoulder's blind spot); feet wide from a bent front knee, the rear thigh at most 45 degrees back; eyes open.
- `chin.lift`: the same, the chin lifted a few degrees, never the head thrown back, eyes open.
- `chin.done`: the arms coming down, the shoulders rolling inside the clavicle's 60 degrees.
- `chin.beam_in`: braced into the beam, chest forward, arms still open; the spine inside its 45 and 55 degrees.
- `chin.beam_out`: upright again, plates smoking.
- `chin.bravado`: the head turned to the rival, one arm lowered, the other still out.

Animation's `s3.absorb.brace` is a guard taking a burst, with the forearms up. It is a different move and is not reused here.

### 5.4 Camera and staging limits
- **Ordinary hits:** no change to the camera.
- **A signature absorbed:** a push in on the stance as the beam lands, then out again for the line. No freeze frame.
- **Legal** has cleared On the Chin; its line of bravado gets an exact-phrase search before it is locked. The arms-open stance is his alone and never appears in Blow for Blow.
- **The stacking rule:** no scream, and no aura, since he is neither charging nor attacking. Standing tall with open hands is not the crouch with clenched fists.
- **With a broken arm** the stance plays with that arm hanging; it is still his.

## 6. One finisher each at launch

Game Design needs one finisher per fighter for launch (`docs/design/launch-pair-plan.md` section 8). Both are written in the live finishers' form: the beats up to the contest, then the two outcomes, landed and survived (`data/combat/finishers.json`). The contest keeps its live timing: it opens, and resolves 66 ticks later. Ticks below are from the finisher's start.

### 6.1 The Anti-hero: his base finisher, by hand
The shape already in `finishers.json` ("the barrage until the loser gives way, the slow walk in, the contest, the last blow by hand"), sized.

| Ticks | Beat | Pieces |
| :--- | :--- | :--- |
| 0 | the tell; he backs off to range | the live tell cue; a short move back |
| 12, 30, 48 | three volleys of shards, 18 ticks apart; each volley's count follows his Pride, as the poke's does | the charged brace and the kiting turn, from his barrage poses that ship |
| 66 | the rival gives way | the computed reaction and the wear layers |
| 66 to 106 | the slow walk in: upright, unhurried, hands open and low | `fin.walk` |
| 106 | he stops over the rival, looking down; the contest opens | `fin.stop` |
| 172 | the contest resolves | live |
| landed: 0 to 20 | his last look, then 20 ticks of wind-up, the finisher's minimum | `fin.stop` |
| landed: 20 | **the last blow, by hand:** a heavy he can still throw (hammer, overhand, haymaker or uppercut), at full blow weight, launching by the planner's long send | wave 1 |
| landed: after | the held pose: turned half away, the arm lowered; it hands over to the winner's stand | `fin.held` |
| survived | the rival breaks his hold and they separate, as the live finishers do | live |

- **About 192 ticks to the last blow,** 3.2 s, inside the 3 to 8 s set pieces may take.
- **3 sketches:** `fin.walk`, `fin.stop`, `fin.held`. They are the same as wave 7's hand finish showcase, which then needs no more.
- **Broken limbs:** the last blow is drawn from the heavies he can still throw.

### 6.2 The Protagonist: the flight version
The shape in `finishers.json` ("the catch, a flurry, rise and gather, the contest, a point-blank all-out energy blast"), with the flurry flown, not teleported, as Game Design ruled.

| Ticks | Beat | Pieces |
| :--- | :--- | :--- |
| 0 to 20 | the tell and the catch | the live tell cue; the catch |
| 20 to 92 | **the flurry:** 3 to 5 strikes (4 shown here). Each follows a spiral flight of 18 ticks round the loser on the ping-pong's path, arriving from a new side, and lands on arrival | his own strikes, a different one each time: palm push, crescent kick, spinning back kick, rising palm, hammer-fist; `fin.turn` on each arrival |
| 92 to 104 | he rises above the rival | a move up |
| 104 | the gather; the contest opens | `fin.gather` |
| 170 | the contest resolves | live |
| landed: 20 | **the blast:** one open hand thrust from the shoulder at point blank, the other open behind him for balance | `fin.blast` |
| landed: after | the held pose as the smoke clears | `fin.after` |
| survived | the rival breaks the hold and they separate | live |

- **About 190 ticks to the blast,** 3.2 s.
- **How many strikes (proposal for Game Design):** 3 at Heated, 4 at Simmering, 5 at Boiling, so his heat shows in his finisher. Each extra strike adds 18 ticks.
- **The sides** come from the terrain and where the loser is: in front, above, behind, below. Each flight goes round the loser and never through him, so the pair changes sides on purpose, as a dodge does.
- **It needs curved flight,** the spiral on the rush. Until Encounter has it, each flight is two straight legs round the loser, which reads less well but never passes through him.
- **4 sketches:** `fin.turn` (his arrival, turned to the loser, the striking limb loaded), `fin.gather`, `fin.blast`, `fin.after`.
- **Legal, written in:** he is drawn the whole way, with no vanish and no afterimage that hides him. The blast is one hand: never a two-hand push from the chest, never a sphere growing in a palm, never hands at a hip. The explosion is a local column in proportion, never a pillar into the sky or a darkening sky, no mushroom cloud, no planet-scale sphere, and no name shouted with it. The finisher's scale is Orb's 7 of 10: it wrecks a block at the low tiers and a district at tier 4, and never scars the planet. No roar, even at Boiling.
- **If Orb gives him teleporting,** the flurry can return to a teleported version as a variant.

## 7. The counts, together

| | Ships in this update | Already posed that he uses |
| :--- | ---: | :--- |
| **Anti-hero** | 23 sketches | waves 1 and 2, and all the shared sets |
| **Protagonist** | 37 sketches | the shared sets |
| **Both** | **60** | |

At wave 1's rate that is about three packs for Orb, about 25 minutes each.

## 8. What this needs

| For | What |
| :--- | :--- |
| **Game Design** | the Protagonist's finisher strike count by heat (section 6.2) |
| **Animation** | the 60 sketches; the Protagonist's profile and his deltas of waves 1 and 2; his shape P for the shared sets |
| **Encounter** | the alchemist's pieces for both fighters; On the Chin's stance; rain and the splitting shot for one, the curving shot for the other; the two finishers, and curved flight for the Protagonist's |
| **VFX** | each fighter's shots in his own family: the Anti-hero's blades and hexagons in violet, the Protagonist's capsules and ring arcs in teal |
| **Narrative** | both names (Orb's); On the Chin's line; the Protagonist's identity strikes may want names only if they show on screen |
| **Legal** | the Protagonist's eight strikes and two entries against the originality rules; the six On the Chin poses |
| **Orb, through the EP** | the Protagonist and teleports; the Anti-hero's tail |
