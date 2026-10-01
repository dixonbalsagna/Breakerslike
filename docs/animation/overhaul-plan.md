# Animation overhaul plan: maximally dynamic on the 27-bone mannequin

Status: plan, with units A to H built (results in pose-pipeline.md §9.8 to §9.10), 2026-10-02, from Orb's direction ("an optimistic overhaul: maximise the dynamic animations, overhaul the ragdolls, fine tune the physics model"). Render only. The sim owns every position and velocity; animation owns how the body moves along that path. Parent plan: `pose-pipeline.md`.

## 1. What "maximally dynamic" means here

The A1 to A2 system is key poses plus in-betweens. It reads well in a fight and badly in flight: a launched body is three blended poses, so it does not flop, tuck, brace or crumple. "Dynamic" means the body's motion is a *response* to the sim's motion, not a clip chosen by state. We get there with small physical layers on top of the poses, all of them deterministic from sim state and tick:

| # | Layer | What it does | Cost | Needs from the sim |
| ---: | :--- | :--- | :--- | :--- |
| 1 | **Active ragdoll** (the main build) | 12 angular degrees of freedom (head, spine, each upper arm in two axes, each forearm, each thigh and shin) on springs around the posed target. The stiffness is the pose's authority: stiff when braced or fighting, loose when launched. Driven by the body's own velocity and acceleration (streamer drag, inertia), stepped once per sim tick | about 15 us a tick a fighter, plus 12 quaternion writes a frame only while active | the events that exist today; `left_ground`, `bounce`, `land`, `tumble_end` when they arrive (a stub meanwhile) |
| 2 | **Tuck, brace, crumple, skid, skip** | The ragdoll's targets and impulses: the body tucks in a tumble (spin above about 5 rad/s), braces in the last 0.3 s before a contact (arms out ahead, chin down), crumples on a slam, skids on its back or front with an arm trailing, skips on water | poses (4) | `f.spin`, `f.rot`, `f.slide`, `f.bounces`, the `skim` event |
| 3 | **Hit reactions from the blow** | Direction and force from the damage event and the striker's position: a head snap, a torso fold or arch, a step, scaled by the blow's weight and the victim's wear, with a deterministic variant per hit so none repeat | a few impulses a hit | `damage` (amount, region, kind, attacker); the striker's x and y (read) |
| 4 | **Lean into velocity and acceleration** (flight, hover, movement) | The spine and pelvis lean into acceleration and velocity in the free state too, so a stop, a start and a turn read | one DOF drive a tick | none |
| 5 | **Anticipation and follow-through by weight** | Already built in A1 (profiles, overshoot, lag); extended so the heavier the blow the longer the load and the deeper the overshoot, per blow | data | `strike` beat args (dmg, big) |
| 6 | **Secondary motion** | Spring chains on the pack and sashes exist; the ragdoll adds trailing limbs; cloth-like pieces stay with Art's attachments | exists | none |
| 7 | **Look-at and aim** | The head turns to the opponent (done in a small way through the visual facing); a real look-at needs the head's yaw DOF in the ragdoll, now available | one DOF | none |
| 8 | **Breathing and weight shift** | Built in the wear layers (§9.7) | built | none |
| 9 | **Foot and hand contact on uneven ground** | Feet planted on the slope under a standing fighter (pelvis height and foot pitch from the column heights under him); hands reaching crater walls in a skid | 2 ground reads a solve, only when grounded and near a slope | `WorldTerrain.groundY` (a read, not a write); depth lanes later |
| 10 | **The contact catch** | A fast striker (Encounter's contact slice moves him far in one tick) is shown travelling: the body is smeared across the jump over 4 ticks (a render-only offset that decays), leaning into the travel, so it reads as a catch and not a pop | one offset | none: it reads the anchor's per-tick jump |

**Budget.** The rule from A1 stands: a body pays for what it does. The ragdoll integrates only while a fighter is launched, down, sliding, recently hit or flying fast; a standing fighter in a fight pays nothing but the existing layers. Targets: under 25 us a solve on the native bench, under +0.6 ms at CPU x4 on /bench/ (measured at the end of each unit). Reduced motion (`RenderAnim.reduced_motion`) scales every ragdoll amplitude to 35% and turns off the smear. Both gates are tested.

**Constraints that hold.** Render only: nothing writes the sim, the gameplay hash is identical with the layer on and off (`anim_check`). No random stream: variation is an integer hash of (tick, slot, event count). One integration step per sim tick, so the picture is the same in a replay at any frame rate. Legal's stacking rule (rule-of-cool §1.9): the crumple, tuck and brace poses are an ordinary launched body; none of them is a clenched-fist crouch, a scream, an upward flame, a rising-rubble ring, lightning, rising hair or a gold flash, so they add no marks to a moment. Originality: poses are ours, each with an `_orig` line.

## 2. Build order and what each unit delivers

| Unit | Contents | Evidence |
| :--- | :--- | :--- |
| A. Ragdoll overhaul | the ragdoll core, tuck, brace, crumple, skid, water skip, the ground-event stub | before and after GIF of a launch; `anim_check` hash, determinism across frame rates, cost |
| B. Dynamic hit reactions | the blow-driven reaction (direction, force, wear, variants) | before and after GIF of a string of hits |
| C. Polish | transitions, the get-ups (quick and slow), hover and flight leans, the contact catch | before and after GIFs |

## 3. What I want from World and Simulation (the physics model)

The ragdoll is only as good as the motion it follows, so most of "fine tune the physics model" is the sim's. The wishes, specifically:

1. **Ground-contact events** (World's G3, `docs/world/ground-contact.md` §4), with these fields and no others needed: `left_ground` (actor, x, y, vx, vy, cause), `bounce` (actor, k, vn, vt, keep, surface), `land` (actor, kind skid, tumble, slam or stop; sin_a; surface), `tumble_end` (actor, how). I build against that shape now with a stub.
2. **The surface normal and slope at the contact** in `bounce` and `land` (the secant slope `s` World already computes): the brace and the crumple orient to the surface, not to the horizontal.
3. **`spin` and `rot` as ticked, hashed, smooth state with the bounce's spin** (World's `spin = dir x vt / BODY_R`, halving every 0.5 s in the air): a body that spins up on a bounce is the best ragdoll input there is. At 60 Hz, `rot` must not jump: the tumble's `rot` free of the kinematic skid's 0.
4. **A launch's start**: `launch` carries `amount` (speed) and `face`; add `ux`, `uy` (the launch direction) so the first-frame whip points the right way. Today the first tick's velocity gives it, one tick late.
5. **A per-tick `contact` record for the striker when the catch moves him more than 120 u in a tick** (Encounter's contact slice): `catch` (actor, dx, dy, n). Without it the animator infers it from the anchor's jump, which works but costs a read every tick.
6. **Rates.** Physical constants the ragdoll uses and the sim should keep stable so the picture stays tuned: gravity 1000 u/s², spin cap 18 rad/s (3 turns a second), a launch's flight time 0.3 to 2 s. If any of them changes, say so; the ragdoll's stiffness table is in data (`data/anim/ragdoll.json`).
7. **Ground lanes' depth `z`** (L0): the ragdoll will tilt toward the camera on a skid in the rows only if `z` moves smoothly; nothing else needed.

## 4. Risks

- A body that wobbles without a cause reads as cheap: the ragdoll is weighted by state and decays to zero at rest, and the pose layer always wins at contact.
- Replays at different frame rates: one step a tick, tested.
- Web cost: only while active, measured; a switch (`RenderAnim.ragdoll_enabled`) turns it off for the A/B.
