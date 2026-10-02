# Joint limits: no knee or elbow can bend the wrong way

Owner: Animation. Status: built and passing (2026-10-01). Brief: Orb saw limbs bent unnaturally in stills and GIFs ("knees bending the wrong way during kicks, elbows turning inward") and asked for it to be made impossible in the rig, so it cannot reach the launch fighters. Render only: nothing here reads or writes the sim, the gameplay hash is unchanged.

Code: `render/anim/anim_joints.gd` (the rules), `anim_joint_lint.gd` and `tools/joint_scan.gd` (the lint), `anim_pose.gd` (`ik_limb`, the bake and the blends), `anim_ragdoll.gd` (the ragdoll's hinges), `anim_fighter.gd` (the solve's last pass). Data: `data/anim/joints.json`.

## 1. The cause

A bend is wrong when the hinge below a joint folds the wrong way. The knee and the elbow are hinges (they turn about one axis, one way), and which way a hinge folds in the picture is decided by the **twist** of the bone above it (the thigh or the upper arm turning about its own axis). Twist the thigh 170 degrees and the knee folds forward. Nothing in R1 limited that twist, and four sources could set it freely:

| Source | What it did | Evidence (all current data, before the fix) |
|---|---|---|
| **The IK bend plane** (`ik2` + `hinge_fix`) | The elbow or knee goes toward a "pole" point that is a fixed place in the world (a default of 10 units forward for a leg, down-back-out for an arm). `hinge_fix` then twists the bone above to whatever the plane needs, with no limit. A straight limb has no real plane at all (its tiny bend could point anywhere), so the twist was noise: `strike.kick.contact` had its thigh twisted 172 degrees, `strike.round.contact` 167. The foot comes out turned over and the first bend of the leg folds forward. | 150 of 359 authored poses (poses.json 39 of 177, ground 9, intro 3, wave 1 70 of 120, wave 2 29 of 62) had a bone past its limit, most with a thigh or an upper arm twisted 100 to 180 degrees. Kicks are the worst: the kick, roundhouse, sweep, stomp and axe kick poses. |
| **Authored targets** | Hands and feet are authored in model space. A hand asked for behind its own shoulder (the body is leaned forward 20 degrees, the hand target was not) has only reverse-fold solutions: `strike.jab.contact` had the rear arm folded 149 degrees *backward* through the upper arm. | The same 150 poses. |
| **Blends** | A plain slerp between two legal rotations of a hip or shoulder can pass through a frame twisted 150 degrees, or swing out through the back of the body, for a few frames. | 492 of 1,470 played sequence frames (18 of 46 sequences: the landings, the bounce, the tumble flip, wave 2's skids and dives). |
| **The ragdoll** | Its springs add up to 103 degrees to an elbow and 115 to a knee on top of the pose, with nothing about what the pose already had, so a knee already folded 120 was pushed to 235 (wraps to a bend the wrong way) and a thigh pushed through the pole of the hip. | 2,028 live frames first went past a limit in the ragdoll stage; 600+ with a hinge bent the wrong way by up to 177 degrees. |

Not sources: the facing flip (`vface` only mirrors the drawing; the far-side pose is the exact mirror image, which keeps every hinge axis), the 2.5D projection (the camera is side-on and the solver works in model space), and the contact solve itself (it kept the plane the pose had; it inherited the bad ones).

Live-match count before the fix, the old hinge-only last pass included (`joint_scan --head`, four seeded matches, 24,000 fighter-frames): **7,754 frames (32%) had a joint past its limit on screen**: upper-arm twist past the range in 10,830 arm-frames, thigh swing or twist in 2,540 leg-frames, a head, spine or shoulder swing past its cone in 47. (The old pass already clamped elbows and knees locally, which is why the twist, not the hinge, is the count that mattered: a hinge can be "in range" and still fold the wrong way when the bone above it is flipped.)

## 2. The rule

Every jointed bone of the rig is in `data/anim/joints.json`, and one module (`AnimJoints`) decides what it may do. Two kinds of joint:

- **Hinge** (elbow, knee). Turns about its own z axis only, one way: the elbow from -2.8 to 160 degrees of flexion, the knee (the other way) from -2.8 to 155. No sideways component. Nothing can fold it the other way.
- **Ball joint** (shoulder, hip, clavicle, lower and upper spine, neck, head, ankle, wrist). Split into a **swing** (where the bone points: a cone about its rest axis, narrower toward the back of a hip) and a **twist** (the turn about its own axis, a range, mirrored for the left side). A shoulder over a nearly straight elbow may twist further (a straight arm hides its twist) and the range closes to its normal value by 45 degrees of flexion.

| Bone | Swing | Twist (right side; the left mirrors) |
|---|---|---|
| Shoulder (upper arm) | 175 degrees (155 across the chest), plus the old shoulder's blind spot (no arm straight back along the body) | -100 to 100 bent; -175 to 175 straight |
| Hip (thigh) | 170 forward, 45 back, 105 out, 60 in (an ellipse) | -70 to 70 bent; -85 to 85 straight |
| Clavicle | 60 | -30 to 30 |
| Lower spine, upper spine | 45, 55 | -30 to 30, -40 to 40 |
| Neck, head | 50, 70 | -50 to 50 |
| Ankle, wrist | 70, 90 | -30 to 30, -90 to 90 |

Per-shape scales (P, A, E, C) are in the same file (`shapes`: a multiplier on swing, twist and the hinge's end). All four are 1.0 today; if a shape's body wants a tighter hip or a freer shoulder, the number goes there, not in code.

### Where it is enforced

1. **The pose bake** (`AnimPose.bake`): the limb solves are `ik_limb`, and a last `enforce` pass runs until it changes nothing, so no authored pose can leave its sketch outside the limits (an `fk` bone override included).
2. **The limb solves** (`AnimPose.ik_limb`, used by the bake, the contact solve and the foot-on-slope solve): the end goes exactly where asked; the only free choice, the plane the elbow or knee bends in, is made so the bone above is inside its range. The pose's own plane is kept when legal; an illegal one moves the shortest way to a legal plane; a near-straight limb takes the neutral plane (knee forward, elbow behind). A hinge never folds past its end: a target nearer than the limb can fold is met as near as it can (the limb ends inside the defender, not short of him). The bake alone may also slide a hand target forward up to 12 units when no comfortable bend (twist under 75 degrees) reaches it (a hand behind its own shoulder).
3. **The blender** (`AnimPose.mix`, `mix_lag`, the base smoothing, the contact blend): shoulders and hips blend as swing and twist (twist as an angle, swing as a turn vector through the rest pose), so two legal rotations never blend through a frame past the range.
4. **The ragdoll** (`AnimRagdoll.apply`): every turn it adds (elbow, knee, shoulder, hip, spine, head) is cut to the largest share that stays inside the joint's range, a pure function of the pose so replays agree; a shoulder's lift and sweep are made as one turn about the axis between them, which adds no twist. In four seeded matches this took the ragdoll stage from 752 frames that first broke a limit to 194, and corrections over 30 degrees from 117 to 35.
5. **The last pass of every solve** (`AnimJoints.enforce`, after every layer): anything still outside is put back. A source that respects the limits makes no correction (the fast path costs a few float tests per bone, no trig). This is the guarantee: whatever a layer does, what reaches the screen is inside the limits.

Cost: the solve went from about 92 to about 128 microseconds a fighter on a loaded machine (4,200-tick match; budget 1.0 ms mean for all of animation).

## 3. The lint

`tools/joint_scan.gd` (headless; `godot --headless --path . -s res://render/anim/tools/joint_scan.gd -- [--strict] [--json=out.json]`) measures every knee, elbow, hip, shoulder, spine, neck and head against `joints.json` in four sources, naming the pose, sequence, tick, state and blow of each hit:

- every authored pose, near and far side, at each shape's scale (poses.json and every wave: 1, 2, step 3, ground, intro, last stand);
- every sequence frame, played through the real entry layer, after the solve's last pass;
- a sample of live seeded matches (`--seeds`, `--ticks`), every fighter-frame, the ragdoll included, with the stage that first took a joint past its limit (A: pose data, blends, sequences; B: the contact solve; C: the ragdoll; D: the later layers), the size of what the last pass had to fix, and the worst cases;
- the ragdoll's own range data against the hinges.

`--head` runs it as the game shipped (only the old hinge pass), `--legacy` with no limit at all, `--nopass` with only the limited IK. `tools/anim_check.gd` has the gate (`_test_joints`): every pose and sequence frame of every wave, a flipped thigh being brought in, the IK on kicks at three body leans, the ragdoll at its extremes, and one live match, all failing on a single frame past a limit. Run with `--no-ik-limits --no-joint-pass` it fails six checks (the negative control). `render/anim/tools/review.mjs wave` runs `joint_scan` with the other match-level checks, and a finding is an error.

### Counts, all current data (every wave; four seeded matches of up to 3,000 ticks)

| | As shipped (`--head`) | Limited IK only, no passes | Now (everything on) |
|---|---|---|---|
| Authored poses past a limit (359, near and far, 5 shapes) | 150 poses, 1,500 frames | 25 poses, 250 frames | **0** |
| of which poses.json / ground / intro / last stand / step 3 / wave 1 / wave 2 | 390 / 90 / 30 / 0 / 0 / 700 / 290 frames | 40 / 40 / 10 / 0 / 0 / 90 / 70 | **0 / 0 / 0 / 0 / 0 / 0 / 0** |
| Sequence frames past a limit on screen (1,470 frames, 46 sequences) | 474 (18 sequences) | 81 | **0** |
| Sequence frames the sources alone leave past a limit (before the last pass) | 492 | 81 | 11 |
| Live frames past a limit on screen (24,000) | 7,754 | 2,171 (no last pass) | **0** |
| Live frames the last pass has to fix by more than half a degree | n/a | n/a | 1,005 (874 ragdoll, 125 contact, 6 layers) |
| of those, corrections over 30 degrees | n/a | n/a | 117 frames (0.5% of frames; mostly the left arm of a launched fighter, the ragdoll's flail) |

## 4. What changed on screen

Where a bend was impossible the pose changed; where it was legal it did not. Of 355 baked poses, 172 changed by more than half a unit at an elbow, knee, hand or foot, and 51 by more than 6 (the legs of the tucks and the skid, kicks, the rear hand of the jabs, hooks and hammers). `art/animation/records/joint-limits.md` lists them. Before and after, the same seeded match: `art/animation/joint-limits/*-before-after.gif` (two front kicks, two roundhouses; the knee that folded the wrong way in the chamber now folds the right way), and `art/animation/tumble-broken-arm-before-after.gif` for the broken arm.

### Re-aimed targets and the tucks (2026-10-02)

Where the limits turned an authored pose worse (an elbow-high guard from a hand authored behind its own shoulder, a tuck whose feet no hip can reach), the targets were re-authored, not the limits loosened: `data/anim/targets.json` holds 30 re-aimed rear-hand targets (never the limb that lands a blow), made with `render/anim/tools/retarget_suggest.gd`, and the four tucks (`launch.tuck`, `gc.tech_flip.tuck`, `gc.tech_flip.spin`, `gc.hold.brace_tumble`) have feet and knee poles that a legal hip and knee reach. Old against new for the 51 poses that moved by more than 6 units: `art/animation/joint-limits/changed-poses-1.png` to `-5.png`.

## 5. What a new fighter's rig must declare

The launch fighters share R1, but a new rig (a different bone list, a different proportion) must add its entry to `data/anim/joints.json` before it is allowed into a build:

1. **Every jointed bone is named** in `hinges` (a bone that folds one way) or `balls` (any other jointed bone), with its limits. A bone in neither list is unconstrained and the lint will not see it: the pelvis, the root and loose cloth are the only bones that may be left out.
2. **Every hinge** declares its `sign` (+1 flexes the lower bone toward +x like an elbow, -1 toward -x like a knee), `min_deg` (a few degrees of give) and `max_deg`.
3. **Every ball joint** declares `swing_deg` (or the four directional ones for a hip), `twist_deg` (right side; the left is mirrored by the bone's name suffix), `axis` if the bone does not lie along y, and `straight_twist_deg` if a hinge hangs below it.
4. **Every shape** (`shapes`) has a row, even if all 1.0.
5. **The bone naming** keeps the suffixes `_l` and `_r` (the mirror of a pose swaps them) and keeps the hinge's child directly after its parent in the bone list (`upper_arm`, `forearm`).
6. **The lint has to pass**: `joint_scan --strict` (all poses, sequences, a live sample) and `anim_check` (it runs the gate). A new pose or sequence, a new wave, a new fighter: same command, no extra step.

Tools needs a schema for `data/anim/joints.json` (`anim.joints/1`); a draft is in `docs/animation/schema-drafts/anim-joints.schema.json`.

## 6. Tuning notes

- A limit that is too tight shows up as the final pass making large corrections (`joint_scan` prints them by size and names the worst); a limit too loose lets an odd bend through. The comfortable twist (75 degrees) and the 12-unit slide are the two numbers that decide how far the bake moves an authored hand.
- A pose that wants a bend the limits forbid (an arm raised behind the head with a straight elbow) is told so by the lint, with the joint and the number of degrees. Author the pose inside, or change the number in `joints.json` with a reason.
- The contact solve keeps the end on the target whenever a legal bend can; a target nearer than the elbow can fold ends inside the defender (never short), and a target behind the shoulder takes the elbow-up plane.
