# Wave 6: the energy family

Owner: Combat and Choreography. Date: 2026-10-01. Status: parked specs for Animation and VFX. Nothing here is loaded or hashed, and no live data changed. The data is `energy.antihero.wave6.json` in this folder. Plan: `../m0-rich.md` section 4 (wave 5 in its table).

**What is here.** 7 emission shapes, 6 hands, 13 strikes that also emit, and 5 energy poses. Together they make 31 energy strikes (16 light, 15 heavy), each an emitter and a shape. They need 7 new body poses and the 6 hands; the 13 emitting strikes reuse their wave 1 poses.

## 1. The rules they follow
- **Energy mode swaps the piece family** (ADR 0008): the same entries and body poses, with a hand and an emission on top. The entries' fire is in `wave2-entries.md`.
- **The shape sets the weight.** Bolt, volley and shard are lights. Arc, burst, lob and charged are heavies.
- **Class `blast`.** A wind-up of 15 ticks for a light and 20 for a heavy, from the live data. A perfect block in its window deflects it. A held Guard at range may deflect one for 10 ki.
- **Damage.** The shape carries the strike's damage and never adds to it. A volley or the shards split it (Game Design's barrage ruling). The volley opener and his poke are 3 at 4 each.
- **In the sim** a blast is a scheduled impact: its arrival tick and a strike. The projectile is render-only: an event with the origin, the target, the travel ticks, the shape and the count. A miss strikes near the target's feet.
- **The aura** shows only while charging or attacking: a thin outline or rings in his violet. No flame, no lightning, no gold, white or red.

## 2. The seven shapes (VFX)
His family is blades and hexagons. Travel speeds and ranges are Combat's proposals.

| Shape | Weight | Count | Range | Travel | Look |
| :--- | :--- | ---: | :--- | :--- | :--- |
| **bolt** | light | 1 | any | 60 u a tick | one thin dart, blade-shaped |
| **volley** | light | 3 | any | 60 u a tick | three darts in a flat fan. **Legal:** a fan from one sweep of the arm or one flick of the hand: never both palms pumping forward in turn. |
| **shard** | light | 5 | up to 1,200 u | 50 u a tick | five hexagonal flakes that tumble and spread: his barrage |
| **arc** | heavy | 1 | any | 45 u a tick | a crescent thrown off a limb that is already swinging; it is wide and crosses the lane. **Legal:** it leaves a limb in motion: no held pose before it. |
| **burst** | heavy | 1 | up to 150 u | none | a flat hexagonal ring that opens at the point of contact and pushes |
| **lob** | heavy | 1 | 300 to 1,500 u | a fixed 36-tick arc | a hexagonal slab lobbed on a high arc; it lands with an area. **Legal:** a slab, never a sphere; thrown with one hand, never raised overhead in two. |
| **charged** | heavy | 1 | any | 90 u a tick | one long lance after a visible charge. **Legal:** the charge is plates stacking along the forearm, never a ball of light growing in a palm; the arm is drawn back at shoulder height, never to the hip. |

## 3. The six hands
| Hand | Look |
| :--- | :--- |
| `open_palm` | flat, fingers together, the arm out at chest height. **Legal:** never at the hip; no palm-forward charge pose with a scream. |
| `pinch` | thumb to forefinger; the dart leaves as they part. **Legal:** no pointing finger and no two-finger point. |
| `clawed_palm` | fingers spread and hooked like tines |
| `fist_glow` | a closed fist with the forearm plates lit along their edges. **Legal:** lit plate edges, not a ball of light round the fist. |
| `blade_hand` | a flat knife hand; darts run off its edge |
| `crossed_forearms` | the two forearm guards brought together, plates outward. **Legal:** in motion, never a held crossed-arms pose. |

Legal's verdict on the hands (`docs/legal/rule-of-cool-screen.md`): the two-finger point is out, and so is any pointing finger; the pinch replaced it.

## 4. The 13 strikes that also emit
Each plays its wave 1 poses. The emission leaves on the strike's contact tick, from the striking limb.

| Emitter | Hand | Shapes | Uses | Look |
| :--- | :--- | :--- | :--- | :--- |
| `backfist` | `blade_hand` | arc, volley | 1 arm | The backhand's sweep throws the crescent off the forearm plate, or scatters the fan along its arc. |
| `palm_heel` | `clawed_palm` | bolt, burst | 1 arm | The palm stops a hand short of the rival and the dart leaves it; at point-blank the same push ends in the ring. |
| `spear_hand` | `blade_hand` | bolt, volley, shard | 1 arm | The thrust becomes the line the darts follow, running off the edge of the hand. |
| `uppercut` | `fist_glow` | arc, lob | 1 arm | The rising fist drags a crescent up from below, or scoops the slab up to fall on the rival. |
| `hammer` | `fist_glow` | arc, burst | 1 arm | The downward chop cuts a crescent straight down; struck into the ground, it is the ring. |
| `overhand` | `clawed_palm` | lob, burst | 1 arm | The looping arm lets the slab go at the top of its arc; up close, the same loop ends in the ring. |
| `twin_spear` | `blade_hand` | volley, shard | 2 arms | Both blade hands thrust a hand apart, and the darts or flakes leave from the two edges together. |
| `double_hammer` | `crossed_forearms` | burst | 2 arms | Both forearm guards come down side by side and the ring opens where they land. |
| `roundhouse` | none | arc | 1 leg; grounded: both legs | The crescent leaves the shin at the widest point of the kick. |
| `axe_kick` | none | arc | 1 leg; grounded: both legs | The heel's drop cuts a crescent downward. |
| `rising_knee` | none | burst | 1 leg; grounded: both legs | The ring opens at the knee as it lands. |
| `tail_jab` (held: the tail) | none | bolt, shard | own limb | The tail's tip flicks a dart, or sheds flakes, without his hands moving. |
| `tail_whip` (held: the tail) | none | arc, volley | own limb | The lash throws a crescent, or a fan, off its end. |

The double palm does not emit: Legal made it a melee strike only.

## 5. The five energy poses
| Pose | Hand | Shapes | Uses | New poses | Look |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `charged_brace` | `blade_hand` | charged, bolt | 1 arm | charge: side-on, the firing arm drawn back at shoulder height, hexagonal plates stacking along the forearm, the other hand open on the firing arm's shoulder; release: the arm straight at the rival, blade hand, the plates gone | One arm, one shot: the plates stack along the forearm and leave as a lance, or a single quick dart with no charge. |
| `channel` | `open_palm` | charged | 2 arms | charge: one forearm high and one low, plates facing each other across a body-length gap, hexagonal plates stacking along the line between them; release: the arms torn apart, the lance leaving along that line | Two arms: the lance forms along the line between a high forearm and a low one, and leaves when he tears them apart. **Legal:** hands at least a shoulder width apart, or one high and one low, never wrists together; never cupped at either hip, never drawn back to one hip and thrust forward; no sphere or glow forming between facing palms, and no hands overhead holding a growing orb; no palms-forward double thrust from the chest as the release; the stacking rule applies while he channels. |
| `kiting_turn` | `pinch` | bolt, volley, shard | 1 arm | the turn: three-quarters away, looking back over the shoulder, the hand flicking behind him | He is already leaving; the darts are flicked back over his shoulder without a full turn. |
| `crown_release` (from Regalia) | none | shard, volley | no limb | the release: upright, chin up, hands open and low, the flat shards leaving their ring one after another | The shards that circle him fire on their own: he does not raise a hand. **Legal:** flat shards on a slow tilted ring: no halo of light behind the head and no orbiting spheres; the stacking rule applies. |
| `shove` | `open_palm` | burst (no damage) | 1 arm | the shove: a flat palm at chest height, the arm at full length, body side-on behind it | A push with no damage: the ring opens off the flat palm and the rival slides back. **Legal:** the palm is at chest height on a straight arm, never at the hip. |

## 6. Enough at every range, and with a broken limb
Lights / heavies on offer, from the parked list. The floor is 8 lights and 4 heavies, as for the physical strikes.

| Range | Healthy | A broken arm | A broken leg, on the ground |
| :--- | ---: | ---: | ---: |
| point-blank (under 150 u) | 16 / 13 | 14 / 11 | 16 / 10 |
| near (150 to 300 u) | 16 / 8 | 14 / 7 | 16 / 6 |
| mid (300 to 1,200 u) | 16 / 10 | 14 / 9 | 16 / 8 |
| long (1,200 to 1,500 u) | 11 / 10 | 10 / 9 | 11 / 8 |
| far (over 1,500 u) | 11 / 8 | 10 / 7 | 11 / 6 |

- **Pillar 3 holds:** bolts, volleys, arcs and the charged shot reach at any range.
- **I made the arc reach at any range for this.** With a short arc, the far band would have had two heavies, both the charged shot.
- **A broken arm** drops the two-arm emitters (the twin spear, the double hammer, the channel). The good hand plays the rest.

## 7. Mixing the two families
- A phrase may change mode once: a volley into a rush, a false charge into a point-blank ring, a scatter and then one charged shot.
- **His poke** (`../variety-pass.md` section 2.5): a light at range becomes a volley-only exchange. I propose its count grows with Pride (3, then 5 shards at Regalia, 7 at Sovereign, 9 at Apex) for the same total damage. That is Game Design's to rule.

## 8. What this needs
| For | What |
| :--- | :--- |
| **VFX** | the 7 shapes in his violet, as blades and hexagons; the plates stacking for a charge; the shard ring; each shape's reduced version |
| **Animation** | the 7 poses and 6 hands; the aim layer turning the arm to the target |
| **Encounter** | the blast as a scheduled impact with the event; the shape's range as a gate on the composer's choice; one mode change in a phrase |
| **Game Design** | the travel speeds and ranges in section 2; the poke's count by Pride |
| **Legal** | a screen of the lines marked Legal in sections 2, 3 and 5 that are Combat's proposals: the volley, the arc, the lob, the charged shot, the lit fist, the crown release and the shove. The channel's line and the hands' are Legal's own |
| **Tools** | the shape and hand lists in the M0 piece schema; a check that every range band keeps 8 lights and 4 heavies |
