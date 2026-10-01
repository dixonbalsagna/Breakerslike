# Hair, topknot, cloth and the Anti-hero's tail: what the rig needs

Owner: Animation. Date: 2026-10-01. Answers the EP's question after Art's close-ups (docs/art/closeup-directions.md): each fighter has a signature head shape (the Anti-hero's long tail of hair, the Protagonist's swept tuft, the Empress's topknot and diadem; the Cyborg has a box head and no hair) and the Anti-hero may keep a body tail. Nothing here is built yet; it is the spec and the cost.

## 1. What exists

Rig R1 has 27 bones. Hair is one static mass on the head (`hair` part). Cloth is five independent one-axis springs on `x_pack` and the four `x_sash` bones (`AnimFighter._spring_tick`, one step per sim tick, two sub-steps): each swings about z (the side view) toward a goal set by the fighter's velocity, its acceleration and a flutter at speed. About 6 microseconds a solve for the lot. They do not whip (each tracks its own goal, so the tip does not lag the root) and they do not hear the head or a blow.

## 2. The four head and body shapes

| Fighter | Shape | What streams or whips | Bones | Spring |
| :--- | :--- | :--- | ---: | :--- |
| Anti-hero | Long tied tail of hair, a second strand (Art's finer faces) | Streams back in flight, whips on a hit, swings with a turn | 4 + 3 | soft: stiff 30 falling to 14 along the chain |
| Protagonist | Swept tuft, short and hooked | Streams in flight, bobs on each step, flicks on a hit | 2 | stiff: 70 and 90 |
| Empress | Topknot (heavy, high), diadem, and the mantle with its long train | Topknot bobs and lags (no streaming); the train is cloth and streams and billows | 2 + 5 | topknot stiff 120, train soft |
| Cyborg | Box head, back unit, looping cables | Cables swing on the body, a little; nothing on the head | 3 + 3 | cable: stiff 60, damped |
| Anti-hero's body tail (if kept) | A braided cable of hair-or-metal segments (Legal: not furred, not reptilian) | Counter-swings the body, carried by stance, whips in strikes | 6 | medium, two axes |

## 3. Attachment bones

One superset skeleton "R2" for all four fighters, so a fighter's mesh just skins to the slots it uses and the rest stay unused (an unused bone costs a quaternion multiply, no skinning): 

| Bones | Parent and offset (model units) | Length | Used by |
| :--- | :--- | ---: | :--- |
| `hair_a1` to `hair_a4` | head, back and top: (-4, 5, 0) | 6 each, 24 | Anti-hero's tail (4), Protagonist's tuft (a1, a2: front-top, (2, 7, 0)), Empress's topknot (a1, a2) |
| `hair_b1` to `hair_b3` | head, (-4, 4, 1.5) | 6 each | the Anti-hero's second strand |
| `tail_1` to `tail_6` | pelvis, back: (-4, -2, 0) | 6 each, 36 | the body tail, or the Empress's train spine |
| `cable_l1` to `cable_l3`, `cable_r1` to `cable_r3` | spine_2, either side of the back unit | 6 each | the Cyborg's cables |

That is 19 bones: R2 has 46, FK about +1.5 microseconds a solve. The diadem is a rigid mesh part on `head` (no bone). Art skins the meshes; Rendering's body builder needs the bone list extended and a per-palette part map (a half-day on their side).

## 4. The spring chains

A chain is data (`data/anim/appendages.json`): root bone, bone list, per-bone stiffness and damping, drive weights, hit-whip gain, rest curve per stance. Four things change relative to today's cloth:

1. **Follow the leader.** Each segment's goal is the world angle of the segment before it, delayed (a coupled chain), so a wave runs down it: the tip lags and whips. Today's independent springs cannot.
2. **Driven by the head, not only the body.** The root of a hair chain is pushed by the head's angular velocity (the ragdoll's head degree of freedom) and the body's acceleration, so a head snap on a hit throws the hair the other way and a turn-around swings it through.
3. **Hit whip.** The damage event kicks the root's angular velocity by the blow's force along its push (the same `force` the hit-reaction table uses), so heavy blows whip the tail and light ones flick it.
4. **Ground and body.** A tail (and a long tail of hair on a downed fighter) must not pass through the ground: clamp each segment's y to the ground line given by the foot-ground sampler we already have. Self-collision with the body is skipped (the chain is always behind the body in the side view); a fighter facing away shows it in front, which is the camera's business.

Axes: hair and cloth swing about z (the side view) plus a small about-x term for a lateral wave, visible in the cheat-out view and in turns. The body tail has two full axes and a rest curl per pose: a new pose key `tail: {lift: deg, curl: deg}` baked into the pose (raised and curled in the aggressive stance, low and trailing in the defensive stance, thrown back with the body in a lunge), so the key poses aim it and the spring only adds the lag.

Cost: 13 chain bones plus the 6-bone tail, two sub-steps each, about 3 microseconds a fighter a tick on this machine. They sit under the existing `cloth` quality layer: at low the chains hold the pose's rest curve (no springs); reduced motion scales the amplitude to 0.35 as the cloth does. Replay-safe: sim ticks only, as the cloth is.

## 5. What the tail needs if Orb keeps it

- The six `tail_*` bones and a two-axis chain with a rest curve per stance and per pose (above); the tail strikes (`tail_jab`, `tail_sweep`, `tail_whip`, `tail_spike`) then need a `tail` limb in the socket table: an aim-limb of reach 36 (six segments) from the pelvis, and a pose key that lays the chain straight along the blow (a pose-driven lash, not the spring's, so the contact is exact).
- A contact solve for a chain: aim the chain's first four bones so the tip is on the target (FABRIK is overkill; a distributed aim over the segments is cheap), about 4 microseconds on contact frames only.
- Ragdoll: the tail goes loose with the body (chain bones are driven by the spring, never the ragdoll DOFs); in a launch it streams back, on the ground it rests along it.
- Legal: hair, cloth or metal segments, matte, plain braid or cable; no fur, no scales, no reptilian spine plates. The strikes' reach (90 u in Combat's wave 1): 36 u of tail from the pelvis, plus the lunge and step (about 11 and 14), is an estimate of about 60 u at best, so Combat's 70 u contact band for them is optimistic and 90 u is not reachable; I would measure it with `socket_check` when R3 exists.

## 6. Cost and order

| Unit | What | Mine | Others |
| :--- | :--- | :--- | :--- |
| R1 | The chain solver and `appendages.json` (generic, any chain), the follow-the-leader spring, the head and hit drives, the ground clamp, tests | 1 unit | |
| R2 | R2 skeleton (19 slots) and the tail's pose key | 0.5 unit | Rendering: bone list in the body builder; Art: skinned parts per fighter |
| R3 | The tail as a socket limb, if kept | 0.5 unit | Combat: the tail strikes |

Until Art's meshes exist the chains can be proven on stand-in capsules in a lab, the way the first ragdoll was. The decision needed from Orb is only whether the tail stays (it changes R2 from 13 to 19 bones and adds R3); the hair chains do not depend on it. The Protagonist's tuft and the Empress's topknot are the cheapest and show the whole mechanism first.
