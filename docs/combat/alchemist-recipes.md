# The alchemist's recipes, the traded-blows set piece and the charges at range

Owner: Combat and Choreography. Date: 2026-10-02. Status: content mapping and parked data. No live data and no code. Data: `pending/recipes.alchemist.json` (section 1) and `pending/templates.agency.json` (sections 2 and 3). It follows `alchemist-content.md`; where the two differ, this one is current.

**Sources.** The rules are Game Design's (`docs/design/agency-pass.md` sections 1 to 3), built on Orb's picks (`docs/ep/vision.md`). The press reading is Controls' (`docs/controls/agency-input.md`). The staging of the set piece follows Legal's twelve rules (`docs/legal/agency-pass-screen.md`). This note says which pieces each rule calls, and what has to be authored.

---

## 1. The recipe mapping: five presses, a base and a timed version of each style

### 1.1 The three styles, and what each calls
The number of heavies among the last five presses sets the style (Game Design). Each works by feel at its base level, and timing lifts it.

| Style | Heavies in five | Base | With timing | Pieces |
| :--- | :--- | :--- | :--- | :--- |
| **Blur** | none | **Mashing:** a ragged run, one small strike a press at the presses' own uneven spacing, with no ender | **A steady mash** (presses evenly spaced, within 3 ticks of the beat) is **a perfect blur:** one blur pattern of five lights at the string's cadence (7 to 10 ticks, section 6.2), every strike clean, then its own ender, a burst that knocks the rival back | base: the 12 long and mid-range lights, or the 4 close ones when toward is held. Timed: a blur pattern (1.3), then one of 8 enders that send across, or the energy burst |
| **Combo** | one to three | **Presses in any rhythm:** one link a light press and one accent a heavy press | **Taps in time** (each within 4 ticks of a blow landing) land **clean and hard:** 15% more, at full blow weight, and the showcase gates open | links: the 18 lights. Accents: heavies that send across first, since an accent pushes the rival back |
| **Power** | four or five | **A held blow:** the charge pose, then the blow with more damage and a longer wind-up | **Released on the flash** (within 6 ticks of it, at full charge): **a guard-breaking blow.** Against a guard it breaks it; unguarded it earns a launch | the 20 heavies; the 16 enders as the last blow; 1 new pose, the charge |

- **Base is never a failure.** A beginner's mash, taps and hold all work.
- **The perfect blur's ender is not pressed.** It is the reward for the steady mash, and it is a knock-back.
- **The flash** is his forearm plates lighting along their edges, in his violet. It is never gold, white or red and never a ball of light (Legal's rules for a charge).

### 1.2 Timing earns the ending: the flow count
Game Design's rule: each timed press adds 1 to the fighter's flow, up to 5; a press off the beat, or 90 ticks without one, sets it to 0.

| Flow | What a heavy ender is | Pieces |
| :--- | :--- | :--- |
| Under 3 | a knock-back | the knock-back endings in `pending/brawl-endings-and-trades.md` |
| 3 or 4 | a launch | one of the 16 enders, picked by the stick through the `sends` tag |
| 5 | a launch with the panel and 20% more impact wear | a showcase ender when its gates pass: the overhead hammer down, the rising spear up |

A string that ends on a light stays a brawl: one of the three level endings.

### 1.3 The blur patterns (data)
Every blur string draws a pattern at its first blow (Game Design, section 6.3 below); the first six are here and two more are in section 6.3. A pattern fixes the order of limbs and targets; the composer fills each step from the lights that fit, with no key strike twice. Each pattern can be filled from wave 1's lights (checked against the parked list).

| Pattern | Limb to target, in order | Reads as |
| :--- | :--- | :--- |
| Ladder | hand to gut, hand to chest, hand to head, foot to chest, hand to head | climbing the body |
| Pendulum | hand to head twice, foot to chest twice, hand to chest | side to side |
| Drill | hand to head, chest, gut, chest, head | one straight line |
| Weave | hand to head, foot to gut, hand to chest, foot to legs, hand to head | hands and feet in turn |
| Undercut | foot to legs, foot to gut, hand to gut, hand to chest, hand to head | from the ground up |
| Inside | elbow to jaw, knee to gut, elbow to jaw, shoulder to chest, hand to chest | the close band; offered when toward is held |

## 2. The traded-blows set piece (in-house label: Blow for Blow)

Orb asked for it by description: both players hit the timing on their power blows, and they trade heavy blows in turn, neither giving way, until one misses the beat. The label is in-house only, never a title, tag or logo; Narrative picks the player-facing name. The staging below is ours.

### 2.1 Game Design's rules
| Part | Rule |
| :--- | :--- |
| Trigger | both fighters release a power blow on the flash in the same exchange |
| A turn | a heavy press on the beat, inside an 8-tick window. The blow is ×0.7 of a heavy. The other takes it and stays up; then it is his turn |
| The beat | 40 ticks between blows at first, 4 shorter each turn, never under 24: 40, 36, 32, 28, 24, 24, 24, 24 |
| The end | the first to miss the beat, or to guard or dodge, gives way. The other lands the last blow as an earned launch, with the panel and 25% more impact wear |
| Limits | at most 8 turns, then both slide apart with no winner. One big set piece per 20 s |

At most 232 ticks, a little under 4 s. A fighter who lasts to the end has taken four blows.

### 2.2 A different strike and a different place each turn
Legal's rule 3: each turn differs from the last in both the strike and the place it lands, with elbows, knees and kicks among them, and never two blows to the stomach running. All of these are his own heavies.

| Place | Wear goes to | His heavies for it |
| :--- | :--- | :--- |
| Ribs | core | body hook (new) |
| Flank | core | roundhouse |
| Shoulder plate | arms | dropping elbow, hammer |
| Chest | core | rib shot (new), double palm |
| Hip | legs | rising knee, spinning heel |
| Thigh | legs | stomp |

- No fighter repeats a strike in one set piece, and limb families alternate: never two hand blows to the ribs or flank running.
- **This changes one of Game Design's lines.** Its rule sends every blow "to the core". With a place per turn, the wear goes to that place's region: core, arms or legs.
- **Broken limbs.** With a broken arm he loses the double palm and keeps all six places. With a broken leg on the ground he keeps the ribs, the shoulder plate and the chest: enough for four turns that each differ from the last.
- Wave 1 had no heavy punch to the body: its four one-arm fist heavies go to the head or the jaw. The body hook and the rib shot are new, and can join the pool afterwards.

### 2.3 They travel
Legal's rule 10: the pair never stands still. Each blow drives both along the ground. The taker gives the distance on his feet, the striker follows through it, and the answer drives them back the other way, further each time: 40, 48, 56, 64, 72, 80, 88 and 96 u over the eight turns.

- **On the ground** they plough one lengthening furrow, there and back. World cuts it by tier. This is the slide destruction Orb wants at the centre of the game.
- **In the air** the same drive, with a ring leaving each blow. No cracked sky.

| Ticks from a blow | What happens |
| :--- | :--- |
| 0 | the striker's blow lands, on the beat |
| 0 to 10 | both travel the turn's drive; the taker is in his brace, on his feet |
| by 14 | the taker is set again, and the roles swap |
| the last 10 of the beat | the wind-up of his answer |

### 2.4 Poses (3 sketches, all inside Animation's joint limits)
| Pose | Look | The limit it respects |
| :--- | :--- | :--- |
| `bfb.brace` | his own brace: both forearm plates drawn tight against his ribs, the lead shoulder rolled forward and the chin behind it, the spine upright. He gives ground on his heels and does not fold | elbows bent inside 160 degrees; the rear thigh at most 45 degrees behind the hip; no arm straight back |
| `strike.body_hook` | a heavy hook dug in along the ribs: the elbow at a right angle, the hip turned through, the other forearm plate across his own chest | the upper arm's twist inside 100 degrees with the elbow bent |
| `strike.rib_shot` | a straight heavy blow to the chest from a low shoulder: arm, spine and rear leg one line | the elbow short of 160 degrees; the rear thigh at most 45 back |

**Reused:** the slide on the feet for the taker's travel; the over-commit for a blow that missed its beat; the computed reaction at low strength over the brace; the wear layers for the one who gives way; wave 1's heavies, aimed at the turn's place.

### 2.5 Camera notes
- The director's wide shot: both bodies, their feet and the furrow in frame.
- It tracks the pair as they travel. It does not cut back and forth between them.
- One push-in after the third blow and one after the sixth, no more.
- No freeze on a hit, and no close-up of a straining face.
- On the last blow it widens along the launch.

### 2.6 Legal's twelve rules, and where each is met
| Rule | Where |
| :--- | :--- |
| 1. It starts from the exchange, never from an invitation | the trigger is two power blows released on the flash |
| 2. Each takes the blow in his own way | `bfb.brace`; the On the Chin stance is not used here |
| 3. A different strike and place each turn | section 2.2 |
| 4. No fixed alternating camera, no freeze | section 2.5 |
| 5. At most one short line per fighter | Narrative's, from his own bank |
| 6. The world answers by biome | the furrow, a crack under a blow; no rising ring of rubble, no lightning |
| 7. The ending is the fighter's own | his wear stage and computed reaction, then the launch |
| 8. Original sound | Audio's |
| 9. No folding over | the brace is upright; he gives a step and takes it back |
| 10. They travel | section 2.3 |
| 11. No strain close-ups | section 2.5 |
| 12. The stacking rule | no scream, no flame aura, at most two marks in any moment |

## 3. The charges at range, and the meeting in the middle

Game Design's bands: close within 3 bh, mid from 3 to 12, far beyond 12. A strike never exists at range.

- **Mid: a short lunge** of 20 ticks at most, then the wind-up. The stick picks the entry, and wave 2 has them: toward, the dash, the rising entry or the coil spring; level, the step-in, the pivot or rooted; away, the backstep counter or the hop back. Nothing new.
- **Far: tap to taunt, hold to charge.** The far taunt is 45 ticks: his taunt gestures at three quarters of their close length, played while he keeps flying. No beckoning.

| | **The light charge** (held light) | **The heavy charge** (held heavy) |
| :--- | :--- | :--- |
| **Before he goes** (Game Design) | 12 ticks | 24 ticks |
| **The flight** (Game Design) | 30 to 90 ticks by distance | 48 to 120 ticks |
| **Changing his mind** | releasing the button stops it at no cost: the feint | committed; only a dodge-cancel stops it |
| **Blasts on the way** | any blast that lands stops him | light blasts and volleys do half damage and do not stop him; a charged shot or a beam does |
| **How he arrives** | a light opener, into a brawl | a charged heavy; landing clean, it earns a launch |
| **The gather** | he drops a shoulder toward the rival; derives from the dash's launch-off | the charge pose, the forearm plates lighting |
| **Entries** | dash, rising; the arc dive and the spiral once the rush has paths | dash |
| **Arrival blows** | jab, cross, spear hand, front kick, shoulder check | cross-arm ram, driving knee, body ram, drop kick, haymaker, double palm, roundhouse |
| **New pose** | `charge.peel`, the stop of a feint: side-on to the line, braking, the leading arm swung wide, one knee up | `charge.heavy_lead`, the flight: both forearm plates side by side ahead of him, never crossed, head tucked behind them, the body one low line |

- **The shrug** of the heavy charge is the computed reaction at low strength over the flight pose. No new pose.
- **Legal:** both charges follow the dash rule: not both arms trailed straight back, not one fist punched ahead, and he is drawn the whole way with no vanish.
- **Joint limits:** the peel's raised thigh is inside the hip's 170 degrees forward; the heavy lead keeps both elbows bent and no arm straight back.

### 3.1 The meeting in the middle
Game Design's rule: a far taunt is a challenge. If the rival presses attack during it, both rush and meet: a fist clash if either pressed heavy, otherwise a blur exchange, on the pulse.

| | |
| :--- | :--- |
| **How** | each covers half the distance on a straight dash, and they arrive on the same tick, at the midpoint, at contact distance |
| **The blur opener** | the first beat is a cross-counter: both land. Then wave 5's blur exchange |
| **The clash opener** | the two blows meet limb on limb. Then wave 5's fist clash, or the traded-blows set piece when both released on the flash |
| **Poses** | none new: the dash's launch-off and the strikes' own chambers |
| **Camera** | from the taunt's face cut-in to a wide shot that holds both; it tightens evenly as they close, with the meeting at the centre of the frame; no cut at the meeting |

## 4. What this adds, and what it needs

**Sketches:** 5 new here (the body hook, the rib shot, `bfb.brace`, `charge.peel`, `charge.heavy_lead`), plus the charge pose already counted in `alchemist-content.md`. Everything else is data and reuse.

| For | What |
| :--- | :--- |
| **Game Design** | the set piece's wear by place, not always to the core (section 2.2); the drive distances per turn (section 2.3) |
| **Controls** | the steady mash and the flash as outputs of the classifier; a press window per turn in the set piece |
| **Encounter** | the style and the timing picking pieces; blur patterns; the set piece's turns, places and travel; the two charges, the feint and the meeting; a blow that lands on a fighter who stays on his feet |
| **Animation** | the 5 sketches, inside the joint limits; more sockets for the places (ribs, flank, shoulder plate, hip, thigh), or offsets on the ones it has; the reaction at low strength over a pose |
| **Camera** | sections 2.5 and 3.1 |
| **VFX** | the flash on the forearm plates; the ring in the air with no cracked sky |
| **World** | the furrow under the set piece, by tier |
| **Narrative** | the player-facing name; at most one short line per fighter; taunt lines that read as a challenge |
| **QA** | Orb asked for balance tests: consistent timing should give a substantial edge. Compare base against timed in each style |

## 5. The recipes as live data (live since `08a6002`)

`pending/recipes.alchemist.json` is now in the form Encounter's slice A2 asks for (`docs/director/alchemy-plan.md`): it becomes `data/combat/recipes.json` as it stands, with `"schema": "combat.recipes/1"`. It is not moved yet.

**What changed from the draft.** The pools are per fighter, as queries over each fighter's pieces, and every piece carries its status:

| Status | Meaning | Anti-hero | Protagonist |
| :--- | :--- | ---: | ---: |
| `live` | plays in live matches today | 0 | 0 |
| `posed` | posed in Animation's packs and parked; it plays when its fighter lands | 36 of 40 (wave 1 and rival2) | 43 of 43 (protag1, and protag6 for his body hook) |
| `waiting` | not posed yet | 4: the tail strikes, held for Orb's ruling | 0 |

Nothing is live because KAI and VORR still draw on the placeholder key sets, and go-live step 1 is a flag, off. Each blur pattern is checked against both fighters' lights. The director's own numbers (the window, the flow's thresholds, the multipliers) stay out of this file: they belong in Encounter's `data/director/alchemy.json`.

**Schema keys for Tools** (`tools/schemas/combat-recipes.schema.json`, closed, with `^_` keys as notes):

| Key | Shape |
| :--- | :--- |
| `schema` | the constant `combat.recipes/1` |
| `styles` | three objects: `id` (blur, combo or power), `heaviesInFive` (two integers), `base` and `timed` (each with `read`, a string, and pool names: `pool`, `towardPool`, `linkPool`, `accentPool`, `lastPool`, `ender`; `timed` also `plays` and `endsIn`) |
| `flow`, `direction` | objects of strings |
| `blurPatterns` | name to five `[limb, target]` pairs. Limb: hand, foot, elbow, knee, shoulder, head or own. Target: one of Animation's sockets |
| `patternRule` | a string |
| `lastPress` | `light` and `heavy`, each a list of ending ids |
| `pools` | fighter to pool name to a list of `{id, status}`; `status` is live, posed or waiting. The fighter keys are the working ids `rival` and `protagonist` (2026-10-03; the first was `antihero`) |
| `showcase` | new on 2026-10-03, optional: fighter to a list of `{id, strike, sends, clearAboveBh, status}`. The flow's top ending as data, for Encounter's slice 11: a row is open when its strike is the string's ender, the launch goes its way and, where given, that much air is clear above. The rival has two rows (the overhead hammer down, the rising spear up), both waiting on wave 7's sketches; the Protagonist has none yet |

**Cross-checks for Tools:** the styles' `heaviesInFive` cover 0 to 5 with no overlap; every pool a style names exists for every fighter; every pool id is one of that fighter's pieces; every blur step can be filled from that fighter's lights; the `lastPress` ids exist in the templates once the endings land.

## 6. For slice 11: each piece's limb and target, and the cadence (parked, 2026-10-03)

`data/combat/recipes.json` is live since `08a6002` (section 5's draft, as it stood). The next version is parked as `pending/recipes.slice11.json`, built on the live file at `ba91c14`. It adds `pieces`, two patterns and `patternGates`, and rewrites the blur style's two forms and `patternRule` (sections 6.1 to 6.4). Nothing in the tree is edited yet.

### 6.1 `pieces`: the limb and the target of every pool strike
The pools carry ids and statuses only, and the director cannot read Animation's manifests (they are render data, outside the sim's hash). So the blur patterns' steps had nothing to match against.

- **Shape:** a new top-level block, one row per strike id: `"strike.jab": {"limb": "hand", "target": "head"}`. 48 rows: every id that any pool or showcase row names, the four waiting tail strikes included (limb `own`).
- **One row for both fighters.** A strike id has one limb and one target whoever throws it; each fighter's own key set plays it. All 80 manifest rows at HEAD agree with the table.
- **Not in the pool rows,** because a strike sits in several pools and the two copies could drift.

**Keys for Tools** (`combat-recipes.schema.json`):

| Key | Shape |
| :--- | :--- |
| `pieces` | required. An object: `_` keys are notes; every other key is a piece id, and its value is closed: `limb` (hand, foot, elbow, knee, shoulder, head or own) and `target` (a socket name), both required |

**Cross-checks for Tools:**
- Every id in a pool, and every showcase row's `strike`, has a `pieces` row. A row that nothing names is a warning.
- A `target` is a socket of `data/anim/sockets.json`.
- A posed piece's limb and target equal its manifest rows' (the manifest's limb without `_l` or `_r`).
- `recipes-blur` reads `pieces` and no longer the manifests, and counts repeats: for each fighter, a step that a pattern uses twice needs two pieces of `blur.base` or `blur.toward` that are not waiting, since no key strike plays twice in a string.

**How the patterns fill** (checked by script, both fighters, all eight patterns): every step fills, and every blur light has a step in some pattern. Many steps have only as many pieces as they need: one piece for the hand to the gut, the foot to the gut, the legs or the shins, the knee, the shoulder and the chop to the arm; exactly two for the rival's foot to the chest in `pendulum` and for the elbow to the jaw in `inside`. Wherever that is so, the pattern wins over the director's rule of stepping past his last two picks.

### 6.2 What the cadence changes (Game Design, `agency-pass.md` section 20)
A blur string now lands its blows 7, 8, 9 or 10 ticks apart, drawn when the string starts, in place of a fixed spacing.

- **The six patterns do not change.** A pattern is an order of limbs and targets and has never carried ticks.
- **The one fixed spacing was in the wording.** The blur's timed `plays` said "five lights at 6 ticks" (and section 1 above said "exactly 6 ticks"). It now says "at the string's cadence". `patternRule` gains a sentence: a pattern carries no ticks, and the gap is the director's number.
- **The cadence set is not in the recipes.** It is the director's number, so it belongs in Encounter's `data/director/alchemy.json`.
- **No strike row changes.** Every blur light winds up in 6 ticks, under the shortest cadence, except the twin spear and the sweep at 8. Those two lose one tick of wind-up at a cadence of 7 and play whole from 8 up. That is Animation's to shorten, as it already does at chain speed.

**Ruled by Game Design** (`agency-pass.md` section 20, amended): every blur string draws a pattern together with its cadence at its first blow. The first two blows show both: which limbs, and how fast. The perfect blur is only known at the fourth on-beat press, so the pattern cannot belong to it alone.

### 6.3 Two more patterns, and the gates
Two blur lights fitted no pattern: the sweep, and the Protagonist's knife-hand chop. Each now has one.

| Pattern | Limb to target, in order | Reads as | Open when |
| :--- | :--- | :--- | :--- |
| **Reap** | hand to head, hand to chest, foot to shins, hand to chest, hand to head | high, middle, then the feet taken, and back up as he staggers | both fighters are on the ground (the sweep needs it) |
| **Breach** | hand to arm, hand to head, foot to chest, hand to head, hand to chest | the chop knocks the guard arm down and the blows come round through the gap | the Protagonist's strings only (the chop is his) |

**`patternGates`** (new, optional) says when a pattern may be drawn, read at the string's first blow. A pattern with no row is always open.

| Key | Meaning |
| :--- | :--- |
| `stick` | `toward`. With the stick toward, the draw is among the patterns gated to toward; without it they are closed. `inside` has it: the rule that was a sentence in `patternRule` is now data |
| `ground` | `true`: both fighters are on the ground. `reap` has it |
| `fighters` | a list of the pools' fighter keys: only their strings draw it. `breach` has `["protagonist"]` |

**For Tools:** `patternGates` is an object; `_` keys are notes; every other key names a pattern of `blurPatterns`, and its value is closed with at least one of `stick` (the constant `toward`), `ground` (the constant true) and `fighters` (a non-empty list of keys of `pools`). `recipes-blur` checks a pattern only for the fighters it is for. `blurPatterns` keeps its shape, with eight patterns.

**The closing blow.** `patternRule` now says where the pattern's own closing blow comes from: the ender pool, landing where the string's last light landed when a piece of that pool does, and any piece of it otherwise. With `pieces` the director can do that with no new key. Checked: for every pattern but `weave` (whose fourth light goes to the legs) both fighters have such a piece.

### 6.4 The plain blur and the perfect blur, as the data carries them
Both forms are in the blur's style row (`styles`, id `blur`). The numbers stay where they live, in the director's `data/director/launch.json`; the row names those keys.

| | Plain blur (`base`, read `mashing`) | Perfect blur (`timed`, read `steady`) |
| :--- | :--- | :--- |
| **From** | any mash off the beat | the fourth press in a row that is evenly spaced and within 2 ticks of a blow landing |
| **Strikes** | x0.8 of a light (`blur.strikeMul`) | x1.0 from that press on: they land clean |
| **The ender** | the weak one: 0.6 of the tier's knock-back distance (`blur.enderDist`) and half a set-up (`setup.weight.blurPlain`) | the pattern's own closing blow: the full distance and a full set-up |
| **Flow** | none | +1 for each on-beat press |
| **The look** | the pattern, with loose contact | the same pattern locks in: full contact, a thin outline of his aura, a rising accent in the sound |
| **Launch** | never | never |

In the data: `base` gains the notes `_plays` and `_endsIn`, and its `ender` is `blur.ender` (it was null, from before the plain blur had an ender); `timed` has `plays` and `endsIn` rewritten, with the notes `_from` and `_look`. Both draw on the same pools, so the director's pool pick does not change.
