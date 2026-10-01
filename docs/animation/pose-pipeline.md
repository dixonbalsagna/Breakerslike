# Pose pipeline: hand-made key poses, procedural in-betweens

Owner: Animation. Status: design plan, no code, for P2 onward. Date: 2026-09-30. Asked for by the EP after Orb's questionnaire 6.

**Orb's pick** (`docs/ep/vision.md`, questionnaire 6): hundreds to thousands of basic attacks per fighter, built from a smaller set of hand-made pieces; a fighter's style shifts with mood, injury and form; animation is "hand-made key poses with procedural in-betweens"; the move-building system comes first and content after.

**Built on:** `docs/combat/procedural-moves.md` (parts, slots, scoring, schema sketch), `move-grammar.md`, `variety-pass.md`, `data-fields.md`; `docs/architecture/fx-events.md`, `determinism.md`, `mood-style.md`; `docs/art/style-guide.md`, `marked-aura.md` and the four turnarounds; `docs/design/spec-wounds.md` and `pitches.md` §5; `docs/rendering/README.md`; `research/engine-spike/RESULT.md`; `docs/art/ai-prompt-policy.md`; `docs/legal/originality-rules.md`.

**Not landed yet:** Combat's `docs/combat/moveset-system.md`. Until it does, I build on `procedural-moves.md`, and **every timing and field name here is provisional until Combat's moveset system**. "Part" is Combat's word. "Piece" is Orb's.

**Assumed, because Orb already decided it:** 2.5D side-on with real low-poly 3D geometry, cel-shaded, staged three-quarter ("cheat out"), Godot 4.7 with GDScript, the Compatibility renderer, the browser and old laptops as targets (`vision.md`, ADR 0001, `style-guide.md`). That closes the 2D against 2.5D against 3D question the wave-1 brief asked. §2.7 says what would change if Orb reverses it.

---

## 0. The plan on one page

1. **What people author: key poses and key sets.** A *pose* is one static skeleton configuration plus a few effector pins. A *key set* is two to five poses with timing roles (load, contact, follow-through) and a handful of style numbers. A Combat part points at a key set. Nobody authors a clip.
2. **What the machine generates:** everything between the keys. Timing curves, arcs, limb lag, overshoot, IK to the contact point and the ground, secondary motion, impact reactions, style drift and situation adaptation.
3. **Sell the pose, not the in-between.** Orb's feel reference is choreographed flash animation: held poses, snaps, smear and impact frames (`style-guide.md` §1). Staccato timing is the target look, not a compromise. That is what makes procedural in-betweens viable for a team this size.
4. **Sizes.** Rig R1: a 22-bone core plus 3 to 10 extras per fighter. The first fighter's composed library is about 170 poses (range 130 to 210), then about 100 showcase poses later. Each further fighter adds about 50 own poses, about 30 deltas and a profile, plus a showcase set. About 700 poses across four fighters, 170 of them shared. **Thousands of attacks come from multiplying renditions, not from thousands of poses** (§3.5).
5. **Cost.** A text-authored pose is about 20 minutes at the planning level (L1); a Blender pose about 30. The first fighter's core library is 60 to 80 hours with review. The full pipeline is about 200 engineering hours, and the first useful slice about 60 (§6).
6. **Budget (proposal for Performance).** At most 1.0 ms mean and 2.5 ms p99 per frame for two full-rate fighters, in the browser on the reference old laptop, with a four-step degrade ladder. Expect to need the first step down on the slowest machines (§7).
7. **The sim hash never moves.** Animation owns no sim-read field. Pose data lives outside the hashed data, animation state advances on sim ticks and only reads, and a pose edit cannot change a golden (§8).
8. **People.** Directors (Claude sessions) author every pose, showcase poses included; Orb reviews and steers (ADR 0007, which dropped the human-authorship requirement). Provenance records and the originality notes stay (§6.6).

**Deliberately not doing:** mocap; runtime machine-learned motion; full-body or iterative IK on the critical path; ragdoll physics; a facial rig; cloth simulation beyond spring chains; a bespoke pose editor before the text and Blender paths prove too slow; a different skeleton per fighter.

### Decisions I am making (rig and retarget standards are mine, per the charter)

| Decision | Choice | Who can overrule |
| :--- | :--- | :--- |
| Skeleton | One topology, R1 (§2.2) | Art (bone additions), Orb |
| Binding | One rigid-skinned mesh per fighter, after a spike (§2.3) | Rendering, Art |
| Pose form | Forward-kinematic rotations plus effector pins, text first (§3.1) | Tools (schema) |
| Retarget | Shared pose space, a build profile, three override levels (§2.4) | Orb (roster look) |
| Time base | Sim ticks; solve once per displayed frame (§8.5) | Simulation |
| IK | Own closed-form two-bone; no iterative solver (§4.4) | Rendering |
| Springs | Own tick-stepped chains, not Godot's spring node (§4.5) | Rendering |
| Style drift | A clamped modifier stack driven by sim state (§5) | Game Design, Narrative |
| Data location | `data/anim/`, outside the sim's data hash (§8.4) | EP, Tools |

---

## 1. Terms

| Term | Meaning |
| :--- | :--- |
| **Pose** | One static skeleton configuration: joint rotations, effector pins, hand shapes, a look mode, tags |
| **Key set** | An ordered list of two to five poses with roles and style numbers. A part's `anim.keySet` (renamed from Combat's `anim.clip`, §12) |
| **Part** | Combat's data record for one unit of a phrase: tick timing, reach, tags, in-state and out-state |
| **Piece** | Orb's word for a hand-made building block. In practice a part plus its key set |
| **Rendition** | One visible realisation of a key set, from the variation channels: side, height, tempo, situation, style |
| **Effector pin** | A hand, foot or the head that must reach a place: a socket on the defender, the ground, a wall |
| **Socket** | A named point on a rig, such as `hand_r_strike`, `hit_torso`, `head_flash_anchor` |
| **Modifier** | A small data record that bends poses by sim state: posture, tempo, amplitude, limits (§5) |
| **Profile** | A fighter's global animation numbers: build, posture offsets, timing style, spring settings |
| **Family** | A symbolic pose class (upright, crouched, prone, airborne extended and so on) that Combat's joining rule reads as `poseIn` and `poseOut` |

---

## 2. The rig (item 1)

### 2.1 What a blank-headed fighter needs

| # | Need | Why | Rig answer |
| :--- | :--- | :--- | :--- |
| 1 | No face rig | Masks carry a sigil and have no eye or mouth slots (`style-guide.md` §3.6); the Coil's mask is a blank wedge with a sigil decal slot and no face rig (`coil-turnaround.md`) | No facial bones and no blend shapes. Expression comes from head and neck pose, shoulders, posture and the sigil channel |
| 2 | A strong head read | With no eyes, where a fighter "looks" is the mask's orientation. A head turn of 15 degrees or more is what reads at 38 px | Neck and head bones; look-at with limits (yaw 70, pitch 40 degrees); the head leads the body's turn by 12 degrees (Rendering's `TURN_HEAD`); glances are authored beats (Combat's `glance`, `turn_read`, `glance_back`, `last_look`), never gaze |
| 3 | A sigil channel | The sigil "bends with emotion": lean, scale, brightness, a gap (`marked-aura.md`) | Four render-only floats on the pose. The default comes from state (mood, wear); a pose may key it for an authored beat. It drives a shader, not a bone |
| 4 | Torso and shoulder turn | Three-quarter staging, mirrored when the facing flips, the back never shown (`rendering/README.md` "Staging") | Two spine bones and two clavicles. Every pose is authored facing right with the near side toward the camera; mirroring flips the whole skeleton |
| 5 | Readable hands | A hand is a few pixels at play zoom, but it carries the strike read | A palm bone plus one finger-slab bone per hand. Fist to open is one rotation, so hand shape is a pose channel with four presets (fist, open, claw, relaxed) and not a mesh swap. Art confirms the hand mesh; this is two extra bones |
| 6 | Secondary chains | Hair tuft, sashes, the Empress's mantle, the Cyborg's cables, the Coil's tail (turnarounds) | Named spring chains. Each has a `drive` weight from 0 (pure spring) to 1 (keyed), so the Empress's mantle can be lashed like a tail and the Coil's tail can be posed |
| 7 | Foot and hand IK | Contact accuracy, slopes, walls, water | Two-bone limbs with pole vectors and effector pins (§4.4, §4.8) |
| 8 | Sockets for other directors | VFX wants sparks at the striking limb, Camera wants anchors, Audio wants a whoosh at peak speed | Named sockets, queryable each frame (§2.2, §8.2) |
| 9 | Damage as a geometry toggle | Regalia have intact and broken variants; the pole top can hang | Art's meshes swap. The rig only needs bones for both variants |
| 10 | Independence from the sim | The sim owns position, spin and launch | Two frames. The **sim frame** is `FighterView`'s pivot (position, `rot`, stance lean). The **skeleton root** sits under it and takes only a cosmetic offset of at most 0.3 body height, which the sim never reads |

### 2.2 Skeleton R1

**Core, 22 bones:** `root`, `pelvis`, `spine_1`, `spine_2`, `neck`, `head`; per side (`_l`, `_r`): `clavicle`, `upper_arm`, `forearm`, `hand`, `fingers`, `thigh`, `shin`, `foot`. This is Art's 20-bone humanoid core (turnarounds) plus the two finger slabs.

**Extras** are prefixed `x_` and come from each fighter's turnaround:

| Fighter | Extras (Art's turnarounds) | Bones |
| :--- | :--- | ---: |
| Protagonist | Hair tuft 3 (spring), two sash tails of 2 (spring) | 29 |
| Anti-hero (the Coil) | Tail 3 (spring); the six spine plates are rigid on the spine bones | 25 |
| Empress | Topknot 1, mantle 6 (two chains of 3) | 29 |
| Cyborg | Backpack 1, four cable bones (two chains of 2) | 27 |

Cap: 32 bones per fighter. A fifth fighter or a mod that needs more asks the EP.

**Sockets** (points, not bones; positions are fixed offsets on a bone, set per build profile):
- strike points: `hand_l_strike`, `hand_r_strike`, `forearm_l_guard`, `forearm_r_guard`, `foot_l_strike`, `foot_r_strike`, `knee_l`, `knee_r`, `elbow_l`, `elbow_r`, `head_strike`, `x_tail_tip` where a tail exists;
- hit targets (they map to Combat's `location` hint and the Wounds regions head, core, arms, legs): `hit_head`, `hit_torso`, `hit_arm_l`, `hit_arm_r`, `hit_leg_l`, `hit_leg_r`;
- emitters and anchors: `emit_hand_l`, `emit_hand_r`, `emit_chest`, `head_flash_anchor`, `chest_front`, `back`, `ground_l`, `ground_r`;
- **cosmetic attachment points** (§2.8): `att_head_top`, `att_head_brow`, `att_head_back`, `att_neck`, `att_shoulder_l`, `att_shoulder_r`, `att_back_upper`, `att_back_lower`, `att_chest`, `att_belt`, `att_wrist_l`, `att_wrist_r`, `att_ankle_l`, `att_ankle_r`.

**Naming:** lower snake case, side suffix `_l` or `_r`, one name per bone across all fighters, so retargeting is by name.

### 2.3 Binding and draw calls (a recommendation, and a spike to prove it)

The style is faceted low poly with hard planes (`style-guide.md` §1), so smooth skin weights buy little and cost a lot of labour. I recommend **one mesh per fighter, rigid-skinned**: each part of the body is modelled as a solid, assigned 100% to one bone, and the parts are merged into one mesh. There is no weight painting; a belt or collar piece hides the gap at each joint.

Why it matters more than it looks: the greybox is already about 80 draw calls and about 186 with the split screen and Art's look (`rendering/README.md`). A puppet of separate meshes at 25 to 30 parts a fighter, times two fighters, times two panes, would add over 100 calls, which is a real cost on an old laptop in a browser. One skinned mesh plus the outline pass is 2 calls.

**Proposed draw-call budget per fighter** (for Rendering and Performance to confirm): near at most 12 (body 1, outline 1, regalia at most 8, head flash 1), mid at most 4, far at most 2.

**Spike before anything else (done, 2026-09-30: `render/anim/spike/`, results in §7.8; the plan stands):** (original brief, kept for the record) one fighter, 27 bones, 2,500 triangles (Art's near budget), single mesh, one Compatibility-renderer scene. Acceptance: at most 3 draw calls including the outline; skinning cost on the integrated-GPU web build within budget (§7); the inverted-hull outline stays clean under skinning. **Verify in the spike:** Compatibility-renderer skinning cost on the web; whether the built-in skeleton API or our own bone writes are cheaper for 27 bones (I expect the latter to be fine at this count).

### 2.4 Build profiles and the retarget standard (four fighters, and more later)

One topology, **N build profiles**. A build profile is data:
- segment length ratios (torso, upper arm, forearm, thigh, shin, head, neck) against the neutral;
- widths and volume capsules (used by self-collision-lite and the silhouette lint);
- mass class (light, medium, heavy: sets spring stiffness, lag and overshoot defaults);
- joint-limit scale;
- socket offsets;
- the fighter's height in body-height units (one body height is 75 sim units, `style-guide.md` §2; the Coil's pole and the Empress's mantle are extras, not height).

**Poses are stored in a proportion-independent space.** Joint rotations transfer between builds unchanged. Only end effectors move, so effector pins are stored as fractions of limb length, or in body-height units relative to the chest (hands) or pelvis (feet). Retargeting a pose to a build is four steps:
1. Copy the joint rotations.
2. Re-solve the pinned effectors against the build's limb lengths (two-bone IK). Pins that were not authored as contact or plant pins are free and keep the copied rotations.
3. Push out any elbow, knee or hand that enters the build's torso capsule (self-collision-lite; needed for the Cyborg's blocky chest and the Empress's tabard).
4. Apply the profile's posture offsets (§2.5, level 1).

Error budget: a contact pin is within 0.05 body height of its target after retarget, or the validator flags the pose for that build.

### 2.5 Personality overrides: three levels

| Level | What | Size | Example |
| :--- | :--- | :--- | :--- |
| **L1 Profile** | Global numbers that apply to every pose of the fighter | About 40 numbers | Posture offsets per family (chin, lean, hip height, guard height), timing style, overshoot scale, arc bias, hold bias, spring settings |
| **L2 Pose delta** | A small additive change to one shared pose | 8 bones or fewer per delta; 20 to 40 per fighter | The Anti-hero's cross-punch contact with a flourish: a raised chin and a flicked off-hand |
| **L3 Own piece** | A pose or key set only that fighter has | 35 to 60 poses per fighter | Tail and mantle lashes, portal approaches, consume beats, the Protagonist's ripple-step |

Resolution order: **own piece, then L2 delta, then L1 profile, then the shared pose.**

Combat's style weights choose *what* a fighter does (which part). The profile changes *how* that part looks. The two axes stay separate, so a "brutal" part looks different on the Protagonist than on the Anti-hero without any new part.

| Fighter | Shape language (Art) | Timing style (L1, proposal) | What reads |
| :--- | :--- | :--- | :--- |
| Protagonist | Round, open, forward-leaning | Flowing arcs, generous follow-through, open hands | Circular limb paths; weight forward |
| Anti-hero | Vertical, rigid | Economical, then a flourish; a held pose before the snap ("toying") | Straight lines, a lifted chin, a flick |
| Empress | Wide, sweeping, asymmetric | Long arcs, deliberate; the mantle trails and lashes | Sweeping silhouettes, wide stance |
| Cyborg | Heavy, blocky, steps | The fastest; snappy, quantised timing (a "steps" feel), short holds | Hard angles, low hunch |

Narrative and Art co-own a short per-fighter animation style guide (`docs/animation/style-<fighter>.md`, charter duty). Not written yet: it needs the roster's locked looks.

### 2.6 Who moves what

- The **sim** moves the fighter: position, `rot` for launch spin, state, stance. Animation reads them.
- **Animation** moves the skeleton *under* that frame: pose, cosmetic root offset (a lunge, a recoil, at most 0.3 body height, back to zero by the part's end tick and never read by the sim), springs.
- Contact accuracy is done by IK to the defender's socket, not by moving the sim positions (§4.4).

### 2.7 If Orb changes the presentation

- **2D skeletal sprites:** the pose format and the modifier engine survive unchanged (they are joint-space data). The rig becomes a cut-out puppet with about 16 layers per fighter, poses are authored per facing with no cheat-out turn, and IK stays two-bone in 2D. The draw-call and skinning worry goes away; the turnarounds must be redrawn as cut-out sheets.
- **Full 3D:** the rig survives. The cheat-out staging and hybrid projection stop mattering, the silhouette rules must hold from a moving camera, and view-dependent review triples. This conflicts with the browser and old-laptop targets in either engine (`RESULT.md`).
- Both are **Orb decides.** My default is the assumption above.

### 2.8 Room for unlockable cosmetics (Orb, 2026-09-30)

Orb wants a vast set of unlockable cosmetics; Art is planning the categories. R1 leaves room in three ways, and the draw-call cost of each is stated, because the near budget is 12 draws a fighter (§2.3) and a fighter is 2 today (body plus outline).

**1. Attachment points.** The `att_*` sockets in §2.2 cover the head (top, brow, back), neck, shoulders, upper and lower back, chest, belt, wrists and ankles. A cosmetic is a small mesh in the bone's space plus the socket it sits on; nothing about a pose changes when one is worn. Sockets are fixed offsets per build profile (§2.4), so a hat fits the four builds by name.

**2. Swappable part meshes on the same skeleton.** A cosmetic binds 100% to an existing bone (rigid, like the body) and so needs no new bone. Two ways to draw it, chosen per cosmetic:

| Way | Draw calls | Use for | Cost |
| :--- | :--- | :--- | :--- |
| **Merge at equip** (default): the body and every worn cosmetic are built into one mesh, baked with the outline (`OutlineBake`) and cached by the loadout's key | **No change: 2 a fighter** however many are worn | Everything rigid: hats, masks' trim, shoulder pieces, belts, bracers, back plates | A mesh build and outline bake at loadout change (tens of milliseconds, done at match start or in the locker, never mid-fight); triangles add to the body's |
| **Separate mesh** on the bone | **+2 each** (itself and its outline) | A cosmetic that must be toggled or animated independently in a match: a damage variant, a glowing part | Counts against the 12 |

**3. Per-part material slots, without extra draws.** Recolour and finish by the vertex-colour palette, not by extra materials: the body already carries seven palette slots (body, legs, arms, skin, gear, accent, hair, §2.3 and `anim_rig.gd`), and a cosmetic takes a slot or adds up to two more (`cosmetic_a`, `cosmetic_b`) in the same vertex-colour data. One surface, one material, **no extra draw call**, however many palettes. A second surface or a second material on the same mesh (for a translucent or emissive cosmetic) **is another draw call each**; if Art wants glass or glow, prefer an emissive channel in the vertex alpha over a second material, and count any real exception against the 12.

What else the cosmetics touch:
- **Bones.** The cap stays 32 (§2.2). A cosmetic that moves on its own (a cape, a long scarf, tassels) needs spring bones; the core plus a fighter's extras is 25 to 29, so there are **3 to 7 spare**, and I propose a budget of **4 cosmetic chain bones a fighter** at once. More needs the EP (and a check of the skinning cost).
- **Triangles.** Art's near budget is 2,500 (§2.3 of the style guide); the A1 body is 2,664. Proposed: a body of about 2,000 and at most **500 triangles of cosmetics** at near LOD (a piece 250 at most, as Art's regalia rule), dropped entirely at far LOD.
- **Mirroring.** A cosmetic on one side flips with the fighter; a left-only badge is a right-only badge when facing left. Art decides whether that is acceptable or an asymmetric cosmetic needs a flip-safe design.
- **Poses.** None change. A cosmetic can collide with a pose (a tall hat and an uppercut): the pose sheet renders a worn-cosmetic variant, and a cosmetic declares a clearance volume so the lint can flag it (A3).
- **Modding.** A cosmetic is data: a mesh, a socket, palette slots, a clearance volume and a provenance record.

**Conditions on merge-at-equip (Rendering approved it with these, 2026-09-30):**
1. **Never build mid-fight.** Build at match start or in menus. A mid-fight change would need the bake spread over frames, because the web has no worker threads. The web cost is about 0.15 to 0.2 s a build on the old-laptop proxy.
2. **A cache with an LRU.** `AnimRig._meshes` keeps the last 6 loadout meshes (about 330 KB of GPU memory each) and evicts the least recently used; it was never evicted before. Done (`MESH_CACHE` in `anim_rig.gd`).
3. **Bake once, after the merge, and cosmetics must not use UV2.** `OutlineBake` writes each vertex's reach into UV2.x, so a cosmetic mesh is authored without UV2 and baked only as part of the merged mesh, never on its own.

**Flagged for the EP:** the separate-mesh way is the only one that costs draw calls; the default merge costs none but moves the cost to a bake at loadout change, which Rendering should confirm on the web (the bake runs on the main thread). Also flagged for Art: the triangle split and the mirror rule.

---

## 3. The key-pose library (item 2)

### 3.1 What a pose holds

| Channel | Content | Read by |
| :--- | :--- | :--- |
| `fk` | Local rotations of the core bones, in degrees against the neutral pose. Omitted bones keep neutral | render |
| `pins` | Effector pins: which limb, its target (a socket on the other fighter, the ground, a wall, a world offset), reach as a fraction, an elbow or knee pole hint, a plant flag, a weight | render |
| `hands` | Left and right hand shape (fist, open, claw, relaxed) | render |
| `look` | Mode (opponent, contact, free, down) and weight | render |
| `sigil` | Optional deltas: lean, scale, brightness, gap | render |
| `chains` | Optional `drive` weights per extras chain | render |
| `family`, `band`, `dir`, `mirror` | The symbolic pose family, height band, direction of action, whether it may be mirrored | validation (and see §8.7) |
| `tags` | Limb, weight, style, location hint (the part's own tags win) | validation |
| `_note`, `_orig` | A one-line note and the originality note (§3.7) | reviewers |

Shape only. Tools owns the schema and the names.

```json
// data/anim/poses/common/strike.hook_r.contact.json
{ "id": "common/strike.hook_r.contact", "family": "upright_lunge", "band": "low", "dir": "across", "mirror": true,
  "fk":   { "spine_1": [0, -14, 6], "spine_2": [0, -22, 4], "upper_arm_r": [10, 80, -20], "forearm_r": [0, 0, 88] },
  "pins": [ { "eff": "hand_r", "to": "target.hit_head", "reach": 0.62, "pole": "elbow_out", "w": 1.0 },
            { "eff": "foot_l", "to": "ground", "plant": true, "w": 1.0 } ],
  "hands": { "l": "fist", "r": "fist" }, "look": { "mode": "contact", "w": 0.8 },
  "_orig": "reads as a swung hook; nothing at the hip, nothing at the forehead" }

// data/anim/keysets/strike.hook_r.json
{ "id": "keys/strike.hook_r",
  "keys": [ { "role": "load",    "pose": "common/strike.hook_r.chamber", "end": "anticipation" },
            { "role": "contact", "pose": "common/strike.hook_r.contact", "at": "contact" },
            { "role": "follow",  "pose": "common/strike.hook_r.follow",  "at": "contact+active" } ],
  "style": { "arc": 0.35, "lag": [1, 2, 3, 4], "overshoot": 0.12, "smear": 2, "snap": "strong" },
  "reach": { "min": 0.45, "max": 0.75 },
  "variation": { "height": [-0.25, 0.25], "sides": ["near", "far"], "tempo": [0.85, 1.2] } }
```

Combat's part carries the ticks (anticipation, active, recovery, contact) and the stretch range. The key set carries only *shape*; where a role lands in time comes from the part.

### 3.2 Piece types, and the poses each needs (first fighter)

Counts follow Combat's first-fighter vocabulary (`procedural-moves.md` §1 and §12): about 12 approaches, 30 strike shapes, 10 reaction classes, 14 launch vectors, 8 follow-ups, and 30 to 40 parts at stage 3.

| Piece type (Combat's slot) | Combat count | What is authored | Poses |
| :--- | ---: | :--- | ---: |
| **Foundation** (no slot; every fighter needs it) | | Stance idles (4 stances), flight (hover, dash forward, dash back, ascend, descend, glide), charge and tier-up burst, guard set (high, low, brace), down and get-up (3), hurt hold (2), emotes (taunt, glance, dismay, victory), KO (2) | 26 |
| **Approach** | 12 | Launch-off pose per approach (12), arrival brace for four families (straight, arc, dive, ground) | 16 |
| **Setup and feint** | 6 | Shoulder check, low probe, two feint reversals. Feints reuse strike chambers at reduced amplitude | 4 |
| **Key strike** | 30 | 30 contact poses; 18 authored chambers (the other 12 are derived, §3.3); 12 authored follow-through or extreme variants (aerial, low) | 60 |
| **Guard, parry, clash** | | Guard hit (light, heavy), deflect (2), clash meet (3), guard-break stagger (2), evade (lean, duck, sidestep, blink-out) | 12 |
| **Reaction** | 10 classes | A peak pose for a hit from the front and from behind, per class | 20 |
| **Launch flight and landing** | 14 vectors | Flight tumbles (6); landings: slide brake, crater embed, wall embed, water skim, water entry, bounce, crumple, get-up from slide | 14 |
| **Follow-up** | 8 | Pursue, relay overtake, pin, taunt pause, disengage, beam follow-up and two more | 10 |
| **Out-state families** | | The families other poses recover into (§3.3) | 8 |
| | | **Total** | **170** |
| **Control-scheme poses (ADR 0008, §3.9)** | | Energy mode, guard and perfect block, dodge, sprint, burst, power hold, the context actions | **+87** |

Range 130 to 210. Fewer strike shapes or more derived chambers pull it toward 130. Mirroring is free, so left and right hands are one pose.

**Showcase set** (later; Orb: "content after"): about 100 poses for the first fighter. Four specials at about 8 keys (32), the signature (16 for the charge and release family; variants come from adaptation), a finisher (14), transformation cinematics for six or more stages (about 36 at six keys each), and the break beats (below). These are the "hand-made showcase moves"; directors author them and Orb reviews (ADR 0007, §6.6).

**Break beats.** Game Design's crippling moment is "a respected 1.5 s set piece" with a push-in, a crack and a long launch (`pitches.md` §5, option A). Each limb needs a one-off beat (arm, leg) plus the core's brink drop. Three showcase key sets of about 6 keys.

### 3.3 Derived poses and families

- **Chambers are derived by default.** A generic wind-up is computed from the contact pose: the striking limb retracts along its own axis to 60%, the torso counter-rotates, the hips dip. An author writes a chamber only where the generic one fails (a feint, a spinning strike, a two-hand hammer). That is why the table authors 18 chambers for 30 strikes.
- **Recovery is derived.** The follow-through key relaxes toward the part's out-state family pose, so out-states are the only recovery poses authored.
- **Mirroring is free.** `mirror: true` poses flip the near and far sides. Pose review covers both (§3.6).
- **Families** are the symbolic vocabulary of Combat's joining rule (`poseIn` and `poseOut`, `procedural-moves.md` §2.2). Starting set: `upright`, `upright_lunge`, `crouched`, `kneel`, `prone`, `airborne_neutral`, `airborne_extended`, `tumble`, `backpedal`, `slide_brake`, `embedded`. **Animation owns this list and a can-follow table** (which out-family may precede which in-family, and the blend ticks). The validator checks that any two poses in two families that may follow each other are within a blend distance; otherwise the transition is flagged. This gives Combat's symbolic joins a physical backing.

### 3.4 Per-fighter and roster totals

| Set | Poses | Who |
| :--- | ---: | :--- |
| Shared core, authored once on the neutral build | 170 | the first fighter's library *is* the shared library |
| Own pieces, per further fighter | 35 to 60 | Empress mantle lashes, Cyborg portal approaches and consume beats, Protagonist ripple-steps |
| L2 deltas, per fighter | 20 to 40 (small) | |
| Showcase, per fighter | about 100 | specials, signature, finisher, transformations, break beats |
| **Four fighters at 1.0** | **about 700** | 170 shared, 150 own, 400 showcase, plus deltas |

The showcase set is the big lever on total cost. A fighter's transformation ladder (six or more stages, the Empress's ten or more "revisions") is mostly **profile deltas**: a revision costs about a dozen numbers, not a set of poses. Only the cinematic moment of each stage is authored.

### 3.5 From poses to thousands of attacks

Orb's differentiators for basic attacks (q6) are: the limb or body part, the situation, the impact and reaction, and the rhythm and speed. Each is a *variation channel* that changes a rendition without a new pose:

| Channel | Values | Visible at 38 px? |
| :--- | ---: | :--- |
| Side (near or far limb; mirror) | 2 | Yes. The cheat-out makes the two sides read differently |
| Height (IK target height, ±0.25 body height) | 3 | Yes. A limb at the head, chest or knee |
| Tempo (stretch 0.85 to 1.2, and the anticipation and overshoot that come with it) | 3 | As rhythm, and as a smear length |
| Situation (§4.8: ground, air, wall, water) | up to 4 | Yes. Foot plant, splay, drag |

One strike shape therefore has **2 × 3 × 3 = 18 renditions** by itself, and up to about 72 with situation. Thirty shapes give **540 distinct strike looks before any approach, reaction or launch is chosen, and about 2,000 with situation.** Combat's fingerprint then multiplies them by approach, reaction and launch class (`procedural-moves.md` §6).

That is a claim, so we measure it: **test A6** (§10) counts distinct renditions actually seen over 1,000 seeded matches, where two renditions are distinct if their contact frames differ by at least 12 degrees mean joint angle or 8% silhouette area.

### 3.6 Pose review rules

Every pose is reviewed at the sizes and views it will be seen in:
- **Sizes:** 22, 38 and 52 px tall (real fights are 22 to 52 px, `style-guide.md` §2), plus one large view for detail.
- **Views:** the staged cheat-out view (about 30 degrees toward the camera, near side toward the camera), its mirror, and pure profile. A strike must read in all three.
- **Silhouette first.** Flat black at each size. The action limb is extended by at least 20% of body height beyond the torso outline, or the pose is redrawn (the same threshold Art uses for a silhouette feature).
- **Action in the picture plane.** Key silhouettes move across the body plane, within about 35 degrees of it. Punches toward or away from the camera foreshorten and are not used as a key silhouette. Motion in depth is left to the in-betweens, the camera and VFX.
- **Value and colour.** Poses are judged on the three-colour and greyscale views Art already uses, so a pose that hides the mask or the sigil behind an arm is flagged.
- **Joint limits and self-intersection.** No hyperextended elbow or knee; no limb inside the torso capsule (numeric lint, §6.2).
- **Foot contact.** A grounded pose puts its planted foot on the ground plane within 0.02 body height.
- **Reach.** A contact pose's reach envelope covers its part's `reach` (§8.7).

### 3.7 Originality: the pose gate

`originality-rules.md` lists three iconic poses we must not build (cupped hands at the hip then thrust forward, two fingers to the forehead, arms raised for a giant orb) and asks for "original charge and fire poses". Every pose in a sensitive family carries an `_orig` line in its file and passes checklist item 4 (silhouette, three flat colours, "what does this remind me of?"). Poses are built from our own atoms and are never traced from footage or from another game.

| Sensitive pose family | Our pose, in words | One-line originality check |
| :--- | :--- | :--- |
| Power charge (hold Q) | A low, wide crouch, one fist pressed to the breastbone, the other arm hanging, head bowed, a tremble; the sigil brightens | Fist to chest with a bowed head is a vow or a brace, not cupped hands at the hip, and no orb is formed. Never both fists clenched at the sides with the head thrown back in a scream (RL-038) |
| Beam release (signature) | **Revised after Legal (RL-038, CONDITIONAL).** The lead arm straight along the shoulder line with a **closed fist**, the rear forearm braced **up under the lead elbow** (not gripping the wrist), feet staggered, weight leaning into it | The energy leaves the fist, not an open palm, and no hand grips a wrist; a braced fist reads as a heavy-weapon brace. Nothing at the hip |
| Teleport step | The torso folds forward and one hand sweeps a flat horizontal arc in front of the body as the fighter vanishes; the tell is the air ripple (VFX) | No hand ever goes to the head; the sweep ends at the hip line |
| Transformation rise | Down on one knee with a fist on the ground, then a slow rise with the head last; the sigil lights on the rise | A kneel-and-rise is a generic hero beat; no screamed pose with both fists clenched at the sides and the head thrown back (RL-038) |
| Taunt | A slow head tilt and a dismissive backhand flick at waist height | Generic contempt; no beckoning fingers |
| Finisher launch | A two-step lunge into an upward two-handed strike with the hips driving under it | A martial-arts uppercut chain; no raised arms held overhead |

The reference rules follow Legal's clean process (`docs/legal/animation-data-rule.md`, RL-038): no reference footage from any franchise or game. Self-shot reference (a contributor filming themself doing a punch, with consent) is allowed as private reference for timing and weight, never shipped, with the origin recorded (§6.1). Legal screened this table: charge, teleport, transformation rise, taunt and finisher launch are GO; beam release was CONDITIONAL and is revised above.

### 3.8 The first fighter's lean showcase list (plan; drafts wait for Combat's M0 and the part cue)

Orb confirmed Lean for the first fighter: 3 specials, 4 signatures, 6 showcases, growing by data. The first real fighter, the Lean proof, is the Anti-hero (Orb confirmed, 2026-09-30): brutal and showy; barrages; finishes by hand; Drop the Act; the Proud front. The list below is **a plan, not content**: names are working labels (Narrative names what shows on screen, Legal screens it), the moves are Combat's and Game Design's to set (`moveset-system.md`, `moveset-rules.md`), and **no draft is written until Combat's M0 grammar and the part cue exist**, because the pieces' joins, anchors and weight classes come from them. Every pose keeps an `_orig` line where it is in a sensitive family (§3.7) and a provenance record (§6.6).

| # | Kind | Working label | What it is (for the pose draft) | Poses |
| :--- | :--- | :--- | :--- | ---: |
| S1 | Special | Barrage volley | Both hands fan a spread of bolts in a long arc, torso turning through; variants by range and form (Game Design's barrage +20% in the storm) | 16 |
| S2 | Special | Cutting step | A short vertical dash-through ending in a sweeping strike, advanced footwork | 16 |
| S3 | Special | Grip and drag | A grab at speed and a drag along the ground into a throw (slides and craters are World's) | 16 |
| G1 | Signature | Sweeping line | The place-variant beam signature: charge (`beam.charge`) and release (`beam.fire`) with a biome-specific follow-up | 14 |
| G2 | Signature | Ground-shatter barrage | A slam that sends a wave of bolts along the ground; altitude variants | 14 |
| G3 | Signature | The unrestrained state | The form-tied signature of Drop the Act: a respected cinematic, then the attack | 14 |
| G4 | Signature | Revealed signature | An ordinary story-revealed signature (not a secret weapon), settled by Game Design (`moveset-rules.md` §10): revealed the first time he takes Apex, on the cinematic's held pose with its name on screen, and it replaces his place signatures for the rest of the match. Not Abdicate (G3 is Abdicate's form-tied signature). Planned as a signature skeleton | 14 |
| W1 | Showcase | Dismissive backhand | A toying strike with a taunt pause (`emote.taunt` family) | 7 |
| W2 | Showcase | Seal break | The Proud front collapsing in one beat: posture drops, breath shows | 7 |
| W3 | Showcase | Overhead hammer | The SLAM DOWN send-off: a hammer follow key with a crater embed | 7 |
| W4 | Showcase | Rising spear | The UPPERCUT chain-ender, a long rising launch | 7 |
| W5 | Showcase | Tail whip | The Coil's tail as a driven chain (`drive` 1), one lash | 7 |
| W6 | Showcase | The hand finish | The finisher by hand: a slow closing walk, the last blow and a held pose | 7 |
| F | Fixed | Finisher, transformation cinematics (six stages), break beats | The 68 poses that every scope needs | 68 |
| | | **Total showcase-grade poses** | | **214** |

Review format (confirmed by Orb, 2026-09-30): **contact sheets of 12 poses plus one motion reel per showcase** (§6.5). A showcase's reel is cut at the part's real timing and in the profile its weight class picks (§9.2).

### 3.9 The control scheme's delta (ADR 0008, 2026-09-30)

ADR 0008 turns stances into held states (Guard, Dodge, sprint), adds a mode (physical or energy), a power layer and a context button. **The delta is about 87 new poses on top of the 170-pose basic set (257 in all), plus a mode layer in the modifier stack that costs no poses.** Almost all of it is shared basic-set work that every fighter reuses; the Anti-hero's own part is about 10 poses. It is a plan: nothing is drafted until Combat's grammar and the part cue exist, and the grab, lift and tackle poses also need A2's IK to a socket (a hand must follow the other fighter or an object).

| Group | What it needs from Animation | New poses |
| :--- | :--- | ---: |
| **Energy mode** (the mode swaps the piece family; "mostly hand, aura and effect changes on shared poses") | A **mode layer**: an additive pose set over the shared poses (open or claw hands, palms forward, a lifted guard, a floating stance), weighted by the fighter's mode, with no new key set per piece. The aura and effects are VFX's. Plus the energy piece family Combat adds: light and heavy blast, palm shove, point-blank volley, charged blast (no pose with the arms raised over the head, §3.7) | 10 mode deltas, 14 blast poses: **24** |
| **Guard and perfect block** | Guard high and low (the held state; `stance.defensive` stays the base), a perfect-block deflect (high, mid, low) with the attacker's recoil, guard-hit absorb (light, heavy), the brace | **10** |
| **Dodge and sprint, burst, power hold** | Dodge by direction (back, up, down, side), sprint (forward, away), the burst (coil, push-out, recover), the power-hold channel with the specials ready, the two-trigger transform start | **14** |
| **Context actions** | Grab and throw (reach, hold, three throws, the grabbed fighter's three poses: 13), lift an object (reach, lift, hold, throw: 4), reversal with the afterimage backstep (the reversal strike, the step: 5), tackle (3 plus the victim's 2), dive grab (carry in the air: 5), the civilians action (2), provoke or feint (2), the ranged deflect (3) | **39** |
| **Total** | | **87** |

How each fits the plan:
- **Held states keep the stance poses.** `stance.aggressive`, `.defensive`, `.evasive` and `.escape` map to Press, Guard, Dodge and sprint; the runtime reads the held state instead of the stance number. The base-pose smoothing already covers the switch.
- **A perfect block is a window the sim opens during a visible wind-up** (ADR 0008 §2). The deflect pose lands on the block's tick like any contact key; a mistimed tap still blocks, so it shows the guard-hit pose.
- **A dodge or burst cancels anything mid-exchange.** That is an interrupt (§4.7): the running part drops and the dodge's first key is inertialised in within 6 ticks. The afterimage is VFX's.
- **Grab, lift and tackle bind two bodies.** The sim moves the grabbed fighter; animation attaches the hand to the other's socket (IK, A2) and plays the victim's pose. Both fighters' sockets must be readable each frame.
- **The mode layer joins the style modifier stack** (§5) as one more modifier, weighted by mode, so energy mode costs one record and no key sets.

**What it costs.** Director usage about 0.4 to 0.8 M tokens and Orb's review about 4 to 5 hours (3 minutes a pose with the second look), once, for the shared set. The scope table below includes it.

**Needs from the sim and Combat (to add to §12):** the fighter's mode and held state (guard, sprint) as render-readable state; events for a perfect block, a dodge, a burst and a context action (kind and target slot); the grab's hold state; and the liftable object's position and attach point.

---

## 4. In-betweening (item 3)

### 4.1 The layer stack

Each layer reads the one before it and never writes the sim. Order matters:

| # | Layer | What it does |
| :--- | :--- | :--- |
| 1 | **Key blend** | Poses from the part's key set, timed by the part's ticks: load, contact, follow-through, recovery |
| 2 | **Arc and lag** | Curved effector paths; delayed distal joints (§4.3) |
| 3 | **Transition** | Inertialised blend from the previous part's actual pose and velocity (§4.7) |
| 4 | **Style modifiers** | Posture, tempo shape, amplitude, form (§5) |
| 5 | **Injury constraints** | Joint limits, IK weights, slack chains (§5) |
| 6 | **Situation** | Foot plant, wall splay, water drag (§4.8) |
| 7 | **Secondary motion** | Spring chains on sim ticks (§4.5) |
| 8 | **Impact reaction** | Additive, on the struck fighter, highest priority (§4.6) |
| 9 | **Final clamp** | Joint limits, torso capsule push-out, ground clamp on hands and feet |
| 10 | **Apply** | Write bone poses once per displayed frame, interpolating between the last two tick states |

Layers with zero weight are skipped, and a held pose with no live layers costs no solve (§7).

### 4.2 Timing: what the in-betweener may and may not do

**The anchors belong to the sim.** A part's ticks (anticipation, active, recovery, contact, stretch) come from Combat's part. The in-betweener works inside them.

| Segment | Range | Curve | Notes |
| :--- | :--- | :--- | :--- |
| **Load** | Part start to the chamber key | Ease in | A small counter-motion first for heavy weights |
| **Strike** | Chamber to the contact key | Snap: accelerating, peak speed in the last two ticks | The last one to two ticks carry a smear mark |
| **Impact hold** | The sim's hit-stop ticks | Frozen | Only the shiver and slow springs move (§4.5). Hit-stop is Controls' and Combat's, not ours (`data/combat/templates.json`: light 0.07 s, heavy 0.12 s, finisher 0.3 s are proposed floors) |
| **Follow-through** | Contact to the follow key | Overshoot 5 to 15% along the strike, critically damped settle | Overshoot scales with weight |
| **Recovery** | Follow key to the out-state family | Ease out | May overlap the next part's load (§4.7) |

Rules that keep animation from touching gameplay timing:
1. The contact key is reached exactly at the contact tick, so the contact pose is shown no later than the frame that shows that tick.
2. Nothing runs past the part's end tick.
3. Animation may **redistribute time inside a segment** (hold longer, then snap) but never move an anchor.
4. **Readability floor:** a key pose must be on screen for at least 4 ticks (about 67 ms) to register at 60 Hz, and an anticipation pose for at least 6 ticks on a light attack and 10 on a heavy one. These are my input to Combat's readability minimums, which Combat decides.
5. **Window safety.** Parry and chain windows (`window_open` events) open during visible motion, not during a full hold. **Moving holds** (breathing, micro-noise, spring drift) keep the still-stretch targets of `dynamic-feel.md` §3 (median at most 0.25 s, p90 at most 0.5 s) true even when a pose is held for style.
6. **Stretch.** A part stretched within its range (0.85 to 1.2) plays the same key set faster or slower. Outside the range the composer does not offer the pairing (Combat: "a part that cannot fit is not a candidate").

### 4.3 Arcs and overlap

- **Arcs.** A striking effector's path bulges away from the straight line between its chamber and contact positions, by `arc` times the chord length: straight 0.05, hook 0.35, uppercut 0.25, roundhouse 0.4 (starting values). The arc is enforced on the striking effector inside the active window only, by an IK correction of the elbow or knee within its limits.
- **Overlap and lag.** Joints lag their driver along the chain. On a strike the order is pelvis, spine 1, spine 2, clavicle, upper arm, forearm, hand, with delays of about 0, 1, 2, 3, 4, 5 and 6 ticks that the motion catches up by the contact tick. Heavier mass classes lag more, so a heavy blow whips. The `lag` array in the key set overrides it.
- **Anticipation and exaggeration.** Anticipation depth scales with weight (light, heavy, special, finisher). Exaggeration scales with the act (`mood-style.md`): about 5% more amplitude per act.
- **Smear and impact frames** are marks, not geometry: the animation emits `smear` and `impact_freeze` marks (§8.2) and Rendering applies the vertex stretch and the one-frame contrast flip (`style-guide.md` §5, features 13 and 14).
- **Squash and stretch** is limited to a torso scale of about 3% on heavy impacts. The rig is rigid-skinned and faceted, so more would break the look.

### 4.4 IK

Solved: two-bone limbs (arms, legs) with a pole vector, head look-at, and the spine's bend shared between two bones (40% low, 60% high). Not solved: fingers (one slab), cloth (springs), whole-body IK. **An iterative solver (FABRIK, CCD) is not on the critical path.** A closed-form two-bone solve is a few dozen operations and its cost is fixed. (Godot 4.7 ships skeleton modifier nodes for IK: **verify** the set in 4.7.2 and their web cost. Ours is small enough to write and to keep on sim time.)

Pins the runtime uses:

| Pin | Target | When |
| :--- | :--- | :--- |
| Contact | The defender's hit socket for the part's region (`hit_head`, `hit_torso`, `hit_arm_*`, `hit_leg_*`) | From the chamber to the follow key; full weight at the contact tick |
| Plant | The ground under the foot | Any grounded pose, and `landing` and `slide_brake` families |
| Wall | A point on a surface with a normal | Wall-embed and bracing poses (§4.8) |
| Guard | The defender's own forearm socket in a guard pose | Guard families |
| Look | The opponent's `head` socket or the contact point | `look` channel |

**Reach fudge.** The sim's contact standoff is fixed (the rush stops 58 u short in the prototype), so a target is normally within the pose's reach. If it is out by 15% or less, the **pelvis and spine lunge** (a cosmetic root offset) absorb it. Beyond 15% the validator rejects the pairing at data time. At run time the fallback is a clamped reach: the hand goes as far as it can and the strike still counts. The prototype has no hit volumes, so every strike connects on its beat (`data-fields.md`); IK is what stops that looking like an air punch.

### 4.5 Secondary motion

- **Spring chains on sim ticks** (own code): hair, sashes, the Empress's mantle, the Cyborg's cables, the Coil's tail. Each link is a damped spring with stiffness, damping and a drag coefficient from the mass class and the fighter's profile, stepped once per tick. It therefore holds in hit-stop and pause and is identical on every machine's replay.
- **Hit-stop:** key-driven motion holds; springs advance at 0.1 of a tick, matching the particles (`fx-events.md`: `tick` with `frozen`). The frame does not look dead.
- **KO slow motion:** the `tick` event's `dt` is already 0.35; springs use the event's `dt`.
- **Godot's spring node** (`SpringBoneSimulator3D`, which Art's Anti-hero notes named as likely) steps on the render frame and would not hold in hit-stop or match `--fixed-fps` screenshots. I would use it only if a measurement shows ours costs more. **Verify** before dropping ours.
- **Drive weight.** A chain's `drive` (0 to 1) blends between spring and keyed, so a lash is a posed chain and a snapped pole top hangs on a slack one.

### 4.6 Impact reactions

Combat picks the **reaction class** (flinch, stagger, spin-out, crumple, fold, knock-away, embed, bounce; `procedural-moves.md` §2.1). Animation renders it from three inputs the sim already emits:

| Input | Source | Used for |
| :--- | :--- | :--- |
| Force | The `damage` event's `amount`, normalised by tier; the `launch` event's `amount` for launches | Amplitude of the wave and the recoil |
| Region | `damage.region` (head, core, arms, legs) | Which bones react |
| Kind | `damage.kind` (light, heavy, guard, guard_break, beam, impact) | Guard reactions, beam reactions and landings |

What is authored is a **peak pose** per class and facing (§3.2). What is generated:
1. **An impact wave.** An impulse along the force direction at the hit socket, propagated up the chain with delay and damping (about 6 to 10 Hz, damping ratio 0.4 to 0.7), amplitude clamped.
2. **Recoil.** A cosmetic root offset of at most 0.15 body height along the force, settling back to zero.
3. **The hold.** Frozen at the peak through the sim's hit-stop, then released into a critically damped recovery.
4. **Region flavour.** A head hit snaps the head back along the force (the mask reads it); a torso hit folds the spine; an arm hit recoils the shoulder; a leg hit buckles the knee.
5. **A hit-shiver** during hit-stop, a few pixels at most, keyed to `S.tick` (which counts frozen ticks) so it is repeatable. Reduced motion turns it off.

Launched bodies: the sim owns position and `rot`. Animation picks a flight key set from the launch vector class and blends by speed (spread and stiff at high speed), with limbs trailing by drag lag. On `slide`, `skim`, `crater` and `building_hit` events it moves into the matching landing family.

### 4.7 Transitions, cancels and interrupts

**Inertialisation** joins two parts without a pop. When a new part starts, the difference between the current pose and velocity and the new first key is stored as an offset that decays under a critically damped spring over the part's load window (3 to 6 ticks). It costs one offset per bone and needs no cross-fade of two full poses. Combat's family joins mean the offset is small.

| Interrupt | Sim signal | Animation response |
| :--- | :--- | :--- |
| Parry | `parry` event; the exchange's later beats are cancelled | Defender: deflect pose. Attacker: recoil pose; inertialise within 6 ticks |
| Guard hit | `damage` kind guard | Guard reaction (arms absorb) |
| Hit during a wind-up | `damage` on a fighter mid-part | Abort the part, inertialise into the reaction, no contact pose |
| Launch | `launch` | Flight family; the rush is cleared |
| KO or finisher takeover | `ko`, `finisher_start` | The finisher key set replaces the running one |

### 4.8 Situation adaptation: air, ground, wall, water

Combat *selects* parts by context (its altitude bands, `variety-pass.md` §3). Animation *adapts* the chosen part. The bands are shared: submerged (over the sea, y below -60), ground (within 140 u of the surface), low air (140 to 600 u), high air (600 u and up).

| Situation | Sim signals | What adapts |
| :--- | :--- | :--- |
| **Ground** | Ground band; ground height at the feet | Foot plant IK; pelvis height from the lower supporting foot; ankles align to the ground normal (limit 35 degrees); dust marks on plants |
| **Low air** | Low-air band | Weight fades: foot pins ramp out; "pre-landing reach" ramps in within 0.6 body height of the ground |
| **High air** | High-air band | Pure flight: pitch to velocity (clamped to 60 degrees, eased over 3 to 6 ticks), limbs trail, no plant |
| **Wall and surface** | `building_hit`, `slide`, launches into a mountainside; a building's face at `b.x ± w/2`; the ground slope | An embed pose splayed against the surface normal: feet flat against it, hands spread, torso pressed. A wall pin per limb; VFX draws the crack |
| **Water** | Submerged band; `skim` (x, y, speed, n); the fighter's `wet` state | **Submerged:** limb lag ×1.5, overshoot ×0.6, springs stiffer and more damped, the sim's own 0.55 speed factor for water is read for the lean. **Skimming:** a compress-and-extend pulse at each skip, body flat to the surface. **Half in:** the submerged effect is weighted per bone by how far below the waterline that bone is |

**Foot plant on slopes, including across the seam.**
- The ground under a foot is the sim's ground height read through the shortest-arc helpers, piecewise linear between terrain columns (32 u wide at the current world scale; a foot is about 19 u). The foot's normal comes from the two columns it straddles; the pelvis reads a wider two-column average.
- **A planted foot is pinned in the fighter's local frame, as an offset from the root along the shortest arc, never as an absolute x.** A fighter crossing the seam changes absolute x by the planet's circumference. An absolute pin would jump by that amount and read as a slide. An offset does not care.
- A pin holds until its pose lifts the foot or the leg would stretch past 100%; then the foot **re-plants** (a step). It never stretches or slides.
- Crater rims are the steep case: ankle limit 35 degrees, pelvis drop at most 0.15 body height; beyond that the foot re-plants on the nearest supporting point.
- **Allowed slide:** the `slide_brake` family and a broken leg's drag (§5) let the foot travel along the ground on purpose. That is the knockback slide Orb likes; the dust and trench are VFX and World's.

**Test A3** (§10): planted-foot drift while pinned at most 0.02 body height, on slopes up to 45 degrees and across the seam.

**Approach warp, in one paragraph.** The sim moves the root along the rush. The pose is **time-normalised**, not fixed-length: launch-off held for the smaller of 4 ticks and 25% of the duration, flight blended with a path-following lean, the arrival brace starting at 75% and complete on the arrival tick (the `rush` event carries it as `n`). It therefore serves any duration and distance; at the shortest duration the segments compress, at the longest the flight pose holds. The prototype's rush runs 0.18 to 0.65 s and the dynamic profile is at least 0.25 s: **verify against Combat**, since this is parameterised on duration and distance, not on those constants. `warping-rules.md` (wave 1, not yet written) would hold the min and max tables.

---

## 5. Style drift as pose modifiers (item 4)

### 5.1 What animation may read (state, never written)

| Input | Source | Range |
| :--- | :--- | :--- |
| Wear and stage per region (head, core, arms, legs) | Wounds state and `region_stage`, `region_broken` | 0 to 100; fresh, bruised, battered, broken |
| Brink, Rally, second breath | `brink_enter`, `brink_exit`, `rally`, a region falling a stage | Flags and events |
| Mood band and act | `S.mood.band`, `S.mood.act` (`mood-style.md`) | Calm, Tense, Frenzied; 1 to 4 |
| Style label | `f.style.label` | turtle, rusher, runner, charger, sniper, mixer, or none |
| Form or transformation stage, meter-fed state | Form data and meters (F1) | Discrete stage; continuous 0 to 1 |
| Ego meters | Roster meters (Respect, Pride, Wrath, Hunger) | 0 to 100 |
| Stance, tier, state | Fighter state | Existing |
| Pride break and the Proud front | `drop_act`, `facade_crack` (Wounds events) | Events |

Some of these are not yet on the renderer's read list in `fx-events.md`. Simulation confirms the names (§12).

### 5.2 The modifier model

A modifier is data: **a trigger** (a sim value and a curve to a weight from 0 to 1), **an effect** (channels it changes), **a clamp**, **a blend time** and **a priority**. Shape only:

```json
{ "id": "mod.wear.arms.broken", "when": { "wear.arms": "stage>=3", "side": "worst" },
  "does": { "chain.arm_x": { "ik_w": 0, "spring": "slack" }, "clavicle_x": [0, 0, -10], "hand_x": "relaxed" },
  "clamp": { "maxDeg": 45 }, "blend": { "inTicks": 18, "outTicks": 30 }, "priority": 60 }
```

Rules:
1. **Modifiers change amplitude and posture, not anchors.** They may move time around inside a segment; they never move a part's contact tick (§4.2).
2. **Clamped.** The stack adds at most 25 degrees to any bone, except injury holds (up to 45).
3. **Smoothed on sim ticks.** Weights pass a low-pass filter with time constants per source (mood 90 ticks, wear stage 30, brink or pride break 24), so style drifts and never pops, and it is identical on every machine and in every replay.
4. **Linted at the extremes.** Every key set is rendered through every modifier at maximum and through the worst-case stack; the silhouette lint, joint limits and self-intersection tests must pass, or the modifier's clamp tightens (test A9).
5. **Recognisability is not the goal** (Orb: 3 of 10) but **fighter identity is**: a modifier never replaces a fighter's profile, it moves around it.

### 5.3 Catalogue (starting numbers, all proposals for Art, Game Design and Narrative)

**Wear, by region and stage** (`spec-wounds.md`; Art's body table, `style-guide.md` §6). At broken, the silhouette must change by at least 10% of body height so it reads at 20 px.

| Region | Bruised (30 to 59) | Battered (60 to 89) | Broken (90 and up) |
| :--- | :--- | :--- | :--- |
| Head | Nothing in the pose (decals are Art's) | Carriage drops 6 degrees; the head lags body turns by 2 extra ticks | The head hangs 25 degrees; look-at range halved; no head-strike parts (Combat's gate) |
| Core | Breath depth ×1.3 | 8 degrees of hunch; the guard hand drifts toward the ribs | A hand pressed to the core; 15 degrees of flex; hips 6% lower |
| Arms | Guard 4% lower | The injured side's guard 12 degrees lower; its strike amplitude ×0.9 (visual only); Combat favours the other arm | **The arm hangs**: IK weight 0, slack spring, shoulder 0.06 body height lower, hand open and limp |
| Legs | Stance 5% narrower | Weight shifts 60 to 40 onto the good leg; uneven stride | **A limp** on the ground (hip 0.05 body height lower on that side, the foot may drag); in flight the leg trails slack |

**The broken limb, as Game Design pitched it** (`pitches.md` §5, option A). This is the "dramatic swing" Orb asked for, and it is mostly a posture change:
- **A broken arm turns the fighter feral.** The posture mode drops to a hunch, the injured arm is tucked or hangs, the good arm leads, the sigil holds its rage state, breath is heavy. Animation supplies limp-arm guards, one-armed strikes and head and knee variants in the vocabulary (pieces flagged `one_arm`); Combat's gating chooses them.
- **Broken legs make the fighter plant.** A wide, low, squared stance and a strong guard set. The dash-lean approach poses are replaced by a lower flight lean; the sim removes the dash (Game Design).
- **The break beat** is a showcase key set (§3.2), and the post-break posture is a modifier held until a Rally steps it down.

**Mood band and act:**

| Band | Lean | Hips | Breath | Micro-noise | Anticipation | Overshoot |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| Calm | 0 | 0 | ×1.0 | ×1.0 | ×1.0 | ×1.0 |
| Tense | +3 degrees | -3% | ×1.3 | ×1.5 | ×1.0 | ×1.1 |
| Frenzied | +7 degrees | -7% | ×1.8 | ×2.5 | ×0.85 (never under the readability floor) | ×1.25 |

Micro-noise is cosmetic, from the animation random stream (§8.3).

**Style labels** (turtle, rusher, runner, charger, sniper, mixer) are a **habit tint** of at most 4 degrees: rusher weight forward with the lead hand low; turtle guard 6% higher and compact; runner a light bounce; charger a wide coiled stance; sniper still with the off hand extended; mixer none. They colour the posture; Combat's parts do the choosing.

**Form and meter-fed states** (Orb's forms ladder, meter states and "shedding power to go faster"):
- **Ladder of forms:** a form index selects a profile delta (height, four stance-idle variants, spring stiffness ×0.8 for looser cloth and hair on power, tempo style) and Art's regalia toggle. The transformation cinematic is authored.
- **Meter-fed state that drains:** the weight follows the meter continuously. The Protagonist's heat stages (heated, simmering, boiling) raise the shoulders 0, 3, 6 degrees, deepen the breath and add tremor; steam and veins are VFX. As the meter drains, the posture slumps back.
- **Shedding power to go faster:** a *negative* modifier: a lighter mass class (lag down, stiffness up), a forward lean, a longer stride.

**Ego meters:** Pride (chin up 6 degrees, chest out, showy tempo; the Anti-hero's held posture); Wrath (shoulders up 5, fists tight, head lowered 4); Hunger (a forward hunch of 6 for the Cyborg); Respect (squared, upright, formal guard).

**The Proud front** (`spec-wounds.md` §3): while Pride is half or more, the head, core and arms wear modifiers are multiplied by zero, so the composed posture holds whatever the wear; decals and regalia damage still show because they are Art's. On the pride break, the withheld modifiers release over 24 ticks and one showcase beat plays: posture collapses, hair falls loose, breath shows.

**Brink, second breath and Rally:** the brink is a global hunch with a visible breath; second breath is one exhale pulse when a region drops a stage; Rally lifts the chest and shoulders (Resolve's posture) as the modifier steps down.

### 5.4 How many

About 25 modifier records cover the first fighter (12 wear, 3 mood, 5 labels, 1 Proud front, 1 brink, 3 form or meter). A second fighter adds a profile and a few own modifiers. One small engine interprets them all: per-bone additive rotation offsets, IK weights, and timing-shape parameters.

---

## 6. Authoring tools and the cost per pose (item 5)

### 6.1 Four ways to make a pose

| Path | Who | How | Cost per pose (L1) | Ceiling |
| :--- | :--- | :--- | :--- | :--- |
| **A. Text** (default) | A coder, or a Claude session | Write the FK values and pins in the pose file; render a contact sheet; fix; repeat | About 20 min, mostly review | Good silhouettes; limited nuance in spine curve and shoulders unless FK is tuned |
| **B. Blender** | An artist or contributor | Pose an R1 armature with IK handles from a template; save as a pose; an add-on exports the JSON | About 30 min | Highest; needs Blender skills |
| **C. Self-shot reference** | Anyone with a phone | Film a friend or oneself doing the motion; use stills as reference for A or B | +10 to 20 min | Better mechanics and weight. Private, never shipped, consent and origin recorded |
| **D. AI-assisted sketch** | Any approved tool | Explore silhouettes and ideas, then re-author by A or B | Tool-dependent | Exploration only. Not approved until Legal reads the tool's terms (`ai-prompt-policy.md`) |

All four end in the **same JSON**, which is what makes the pipeline open to a contributor who arrives later and keeps it diff-friendly in git.

Blender is free and open source. **The exporter add-on needs its own licence check before it is added** (Blender's Python add-ons are generally treated as needing a GPL-compatible licence, so it may need its own licence header instead of the repo's default; check Blender's licence FAQ) and its own row in `docs/legal/licence-register.md`. The `.blend` template is content. Reference footage: none from any franchise or game; self-shot reference is private, with consent, never shipped, origin recorded (`docs/legal/animation-data-rule.md`).

### 6.2 Tools

| Tool | What it does | Where | Status | Cost |
| :--- | :--- | :--- | :--- | ---: |
| Pose and key-set format and schema | Human-diffable JSON, closed schema, `_` comment keys | Tools owns the schema; I write the field list | Design here | 12 h |
| **Pose sheet** | Dependency-free Node script (as Art's `gen.mjs`): forward kinematics on R1 with capsule bodies, silhouettes at 22, 38 and 52 px, three views, mirrored, a modifier grid; writes SVG and numbers. Runs with no engine and no GPU, so a Claude session and CI can both run it | `art/animation/tools/` (mine) | Design here | 16 h |
| **Pose lint** (part of the sheet) | Joint limits, torso-capsule intersection, extension against body height, foot-ground contact, reach against a part's `reach`, mirror symmetry | same | Design here | in the 16 h |
| Pose validator rules | Added to `tools/validate.js`: key set has a contact key; contact tick equals the part's contact tick; reach fits the part; anticipation is at least the floor; family and can-follow table; sockets exist | Tools | Design here | 12 h |
| **Motion reel** | A headless Godot script that plays one part on the mannequin and writes a 12-frame filmstrip and a slow-motion loop. Extends `render/tools/shots.gd` and `cue_sheet.gd` | `render/tools/` (Rendering's) | Spec only | 8 h |
| Blender template and exporter | The R1 armature with sockets and IK handles, and an export add-on | `art/animation/blender/` | Optional | 20 h |
| In-engine pose editor | Gizmos in a Godot tool scene | | **Deferred** until A and B prove too slow | 60 h or more |

### 6.3 Cost per pose by level

| Level | What it is | Text | Blender |
| :--- | :--- | ---: | ---: |
| **L0 sketch** | Pins and tags; the lint passes; enough for blockout and tests | 10 min | 15 min |
| **L1 blocked** | Reviewed at three sizes and three views, mirror and limits checked, originality line written. **The planning unit** | 20 min | 30 min |
| **L2 polished** | Hand-tuned FK, spine curve, hand shape, a personality delta. For showcase poses | +20 min | +25 min |
| Review overhead | A 12-pose contact sheet, notes, one rework loop | about 4 min a pose | same |

### 6.4 What the first fighter costs

| Item | Hours (estimate) |
| :--- | ---: |
| Core library, 170 poses at L1 by text (20 min each) | 57 |
| Review and one rework loop (+30%) | 17 |
| **Core library total** | **60 to 80** |
| Same by Blender (30 min each, +30%) | about 110 |
| Showcase, about 100 poses at L2 (40 min each) | about 67 |
| Each further fighter: 50 own poses at L1 (17 h), deltas and profile (11 h), showcase (67 h) | about 95 |
| **Roster of four at 1.0** | **about 425** |

At a hobby pace of 10 hours a week that is a long road, and the honest levers are scope: fewer strike shapes (20 instead of 30 saves about 15 poses), more derived chambers, profiles instead of deltas, and above all the size of the showcase set. Orb's ordering (system first, content after) already points the same way.

**Scope choice for Orb, revised for ADR 0007 (2026-09-30).** The roster row above counted only about 100 showcase poses a fighter. Combat's moveset plan (`docs/combat/moveset-system.md`) has about 10 special skeletons, 11 to 15 signature skeletons and about 20 showcases at launch size. Orb has since dropped the human-authorship requirement (ADR 0007): directors author these poses and Orb reviews. So the cost is no longer a human's hours at the pose. It is **director usage (tokens, in usage windows) plus Orb's review time**. The table lets Orb pick the scope. It assumes: a special skeleton is about 16 poses (4 pieces of 4 keys), a signature skeleton about 14, a showcase about 7, the finisher, transformation cinematics and break beats about 68 poses whatever the scope, and the basic set 170 poses. Both costs are estimates.

- **Authoring (director usage):** about 3 to 6 thousand tokens a pose including the sheet reviews (A1's 57 poses and sheets ran at the low end of that), times 1.5 for the rework after Orb's notes. Batches of 12 poses to a sheet keep it there (ADR 0005).
- **Orb's review:** about 2 minutes a pose (a contact sheet for the shape, the motion reel for the timing), times 1.5 for a second look at what he sends back.

| | Lean | Middle | Full (Combat's launch size) |
| :--- | ---: | ---: | ---: |
| Specials in the pool (skeletons) | 3 | 6 | 10 |
| Signatures (skeletons) | 4 | 8 | 12 |
| Showcases | 6 | 12 | 20 |
| Special poses | 48 | 96 | 160 |
| Signature poses | 56 | 112 | 168 |
| Showcase poses | 42 | 84 | 140 |
| Finisher, transformations, break beats | 68 | 68 | 68 |
| **Showcase-grade poses** | **214** | **360** | **536** |
| Basic set (shared), with the ADR 0008 delta | 257 | 257 | 257 |
| **Poses, first fighter** | **471** | **617** | **793** |
| Director usage, first fighter (tokens, with rework) | about 2.1 to 4.3 M | about 2.8 to 5.6 M | about 3.6 to 7.1 M |
| **Orb's review, first fighter** | **about 24 hours** | **about 31 hours** | **about 40 hours** |
| Director usage, four fighters (tokens) | about 6.5 to 13 M | about 8.5 to 18 M | about 11.5 to 23 M |
| Orb's review, four fighters | about 64 hours | about 95 hours | about 128 hours |

The four-fighter rows charge every fighter in full, without sharing, so they are the pessimistic case. Tokens are spread over usage windows (ADR 0005); the window limit, not the tooling, sets how fast a fighter finishes.

What moves the numbers, in order of size:
1. **The count of specials, signatures and showcases**, which is Orb's and Game Design's choice. Each special skeleton is about 16 poses, each signature skeleton about 14, each showcase about 7.
2. **Sharing across fighters.** A special or signature skeleton re-posed on another fighter's build with an L2 delta costs a fraction of a fresh one.
3. **Transformations as profile deltas.** Only each stage's cinematic moment is authored; the Empress's ten or more "revisions" cost about a dozen numbers each, not poses.
4. **Review load.** Orb's time scales with poses and with how often a batch comes back. Reviewing by motion reel per part, not per pose, and approving in batches, cuts it.

**Orb's pick is effectively lean first, grow by data** (system first, content after): about 2.1 to 4.3 M tokens and 24 hours of review for the first fighter (with the ADR 0008 delta of §3.9), and every added special, signature or showcase is a data drop after that. I recommend exactly that.

**Tokens are the budget for a Claude author** (ADR 0005): batch 12 poses to one sheet, lint by numbers before looking at any picture, keep pose files short, and use images only for the final review of a batch.

**Engineering** (runtime and tools; Rendering, Tools and I split it): rig spike 16 h; runtime v0 (pose apply, key blend, hit-stop, part cue) 28 h; IK and foot plant 24 h; spring chains 12 h; reactions and inertialisation 24 h; the modifier engine with 10 modifiers 24 h; situation adaptation 24 h; pose sheet 16 h; validator 12 h; motion reel 8 h. **About 200 hours in all; the first useful slice (stage A1, §9) is about 60.** These are Animation's estimates; owners re-estimate.

### 6.5 The review loop

1. The author renders a **pose sheet** (numbers first, then one image of the batch).
2. A person reviews it. Poses are judged at 38 px in the staged view, not at poster size.
3. Once a part's key set exists, the **motion reel** plays it on the mannequin and Orb judges it **in motion, in slow motion**. Orb said he wants to judge the aura "in motion" (`vision.md`); the same applies here. A held key reads very differently from a still.
4. Notes go back as pose edits. Nothing is locked until Orb has seen it in motion.

### 6.6 Who authors what

**Ruled by Orb (ADR 0007, 2026-09-30), superseding the human-authorship part of Legal's RL-038 (`docs/legal/animation-data-rule.md`).** A human author is no longer required for any pose class. Directors author poses, showcase poses included, and Orb reviews and steers. Purely AI-made parts may not be protected by copyright, and Orb has accepted that; the concern is liability, not ownership. What stays mandatory:
1. **Provenance records** for every AI-assisted pose set: a franchise-free brief (the session's brief *is* the prompt: no franchise names, footage, screenshots or "in the style of" anything named), the tool, the model and the date. Records live in `art/animation/records/` in the form of `art/prompts/TEMPLATE.md`; Legal writes the origin row in `asset-origins.md`. They also feed the store's AI-content disclosure. The "what a human changed" line is now whatever Orb changed, if anything.
2. **The originality rules and Legal's screens.** Sensitive pose families carry an `_orig` line and pass the checklist (§3.7); Legal's screen of the six families stands (RL-038's table).
3. **Reference footage:** none from any franchise or game. Self-shot reference is private, with consent, never shipped, origin recorded.
4. **Third-party licences:** the Blender add-on (if it is ever built) needs its own licence check.
5. **Status:** showcase poses are no longer held as drafts for want of an author. They lock when Orb has reviewed them.

---

## 7. Budgets for old laptops and the browser (item 6)

These are **proposals for Performance** (`docs/perf/budgets.md`), from measurements other directors made. I have measured nothing yet.

**Reference machine.** The old-laptop stand-in from the engine spike: an i5-7200U or i3-5005U class CPU with an integrated GPU, single-threaded CPU 2.6 to 3.9 times slower than the 9800X3D (PassMark 1,728 and 1,128 against 4,420). In a browser, GDScript compiled to WebAssembly ran about 1.85 times slower than native in the spike (0.037 against 0.020 ms).

### 7.1 Frame budget

| | Two full-rate fighters, dev desktop | Reference laptop, native (×3.9) | Reference laptop, browser (×3.9 ×1.85) |
| :--- | ---: | ---: | ---: |
| Mean per frame | at most 0.12 ms | 0.47 ms | 0.87 ms |
| p99 per frame | at most 0.30 ms | 1.2 ms | 2.2 ms |
| **Proposed limit** | | | **at most 1.0 ms mean, 2.5 ms p99** (6% and 15% of 16.7 ms) |
| Stateful tick step (springs, filters, smoothers) | at most 0.02 ms a fighter | | |

**My first expectation was wrong, and the A0 spike corrected it.** I estimated 0.05 to 0.10 ms a fighter on the desktop, which projects to 0.35 to 0.7 ms a fighter in the old-laptop browser. Measured (§7.8): a full stack of bone layers costs about 0.02 ms a fighter on the desktop and about 0.16 ms in the browser with the CPU throttled 4 times, so **two full-rate fighters in a split screen cost about 0.34 ms mean and 0.5 ms p99 there**, inside the proposed limit with about 3 times headroom. That headroom is for the real runtime's extra work (sim reads, data lookups, ground and contact queries), which the spike does not have. The degrade ladder stays, but as headroom, not as a necessity for two fighters.

### 7.2 The degrade ladder

Use one governor, not two: VFX already drops a quality level below 42 fps for 2 s and returns at 57 fps for 8 s (`effect-budgets.md`). Animation should follow the same signal, which Performance owns.

| Level | What changes | Saves |
| :--- | :--- | :--- |
| **L0 Full** | 60 Hz solve, all layers | |
| **L1** | 30 Hz solve (interpolated), IK on contact and plant pins only, springs on hair and tails only, modifiers at 10 Hz | about half |
| **L2** | Key blend only, no IK or reaction waves, pose updated on part and event boundaries (hold and snap) | most of the solve |
| **L3 Far** (fighter under 12 px, Art's far band) | No solve: blend among about 9 pre-baked silhouette poses (stance, strike, guard, hit, launch, prone, charge, beam, dodge) at 15 Hz | nearly all |

Held poses cost nothing at any level. A 30 Hz solve is also close to the classic flash-animation "on twos" look, so L1 is a style the game already wants.

### 7.3 LOD tie-in

Art's ladder is near over 30 px (2,500 triangles), mid 12 to 30 px (900), far under 12 px (250, no regalia). Animation follows it: L0 or L1 at near, L1 at mid, L3 at far. Solve once per fighter and **apply per pane**: in the split screen each pane owns its skeleton nodes (`rendering/README.md`, "Panes"), so the apply is done twice and the solve once.

### 7.4 Memory, download and load

A pose is about 32 bones of half-precision quaternions plus pins and tags, roughly 350 bytes. Seven hundred poses are under 0.5 MB packed, against a 10.1 MB gzipped web build. Key sets, profiles and modifiers are small text. Load is a decode into packed arrays at start and is not measurable next to the shader compile (about 215 ms on the web, Rendering's).

### 7.5 More than two fighters

Four fighters (2v2) and the Empress's three guard: full rate for the two nearest the cameras, L1 for the others, minions on a small shared vocabulary at L1 always (Combat: cheap to author and quick to read).

### 7.6 What to measure first (done as A0; see §7.8)

The spike, in this order: (1) skinning cost of one 27-bone fighter on the integrated GPU in the web build; (2) the layer stack on the mannequin with the placeholder rig's 15 cue poses migrated; (3) IK and springs. Each result becomes a row in Performance's table. If GDScript misses the budget, the fallback is the one ADR 0001 already names for the sim, a C++ extension, which the web export handles with its dlink template.

### 7.7 The proposed numbers, after the spike

| Item | Proposal |
| :--- | :--- |
| Bone layers, two full-rate fighters, split screen, browser on the reference old laptop | at most 1.0 ms mean and 2.5 ms p99. Spike: 0.34 ms mean, about 0.5 ms p99 with the CPU throttled 4 times |
| Draw calls per fighter | near at most 12. Spike: 2 (body plus outline) |
| Bones | at most 32 |
| Triangles, near | 2,500 (spike: 2,664) |

### 7.8 A0 spike results (2026-09-30)

**What was built** (`render/anim/spike/`, a standalone Godot project the game ignores; it never touches the sim, the game scenes or the gameplay hash): a 27-bone fighter (R1 core of 22 plus 5 extras) of 2,664 faceted triangles, built five ways: one static mesh, one rigid-skinned mesh with the outline as a second pass (`next_pass` inverted hull), the same with separate hand meshes, and a puppet of 26 per-bone meshes. A representative layer stack in GDScript: key blend with per-bone lag, inertialisation, modifiers, forward kinematics, closed-form two-bone IK on four limbs, five spring links, an impact wave and a joint clamp, each a bit of a mask so it can be timed alone.

**How it was run.** 1280×720; two panes, each its own SubViewport and World3D (as the split screen has), two fighters a pane (four instances; "p2f2"); each fighter 300 px tall, the near worst case for fill; 600 frames after 90 warm-up; vsync off. Profiles:
- **desktop GL:** Windows release, Compatibility renderer, RTX 5070 Ti (driver default);
- **desktop iGPU:** the Radeon iGPU through Vulkan Mobile (`--gpu-index 1`), the spike's proxy;
- **web dGPU** and **web iGPU:** single-threaded Web export in Chrome 154 (ANGLE, D3D11), forced with `--force_high_performance_gpu` and `--force_low_power_gpu`;
- **web iGPU ×4:** the same with Chrome's CPU throttle at 4 (`Emulation.setCPUThrottlingRate`), standing in for an i3-5005U-class CPU (PassMark 3.9 times slower).

**Caveats.** The machine was a Ryzen 7 9800X3D with other sessions running (CPU 42% at one snapshot, Ultimate Performance power plan), so treat differences under about 0.1 ms as noise. No real old laptop was tested. The throttle slows the browser's main thread only; the GPU is the real Radeon iGPU. The scene has only fighters, so the frame times are the fighters' share, not the game's frame. The solve is synthetic: it has no sim reads, data lookups, contact or ground queries. There is no hybrid-projection shader.

**1. Draw calls.** Per frame for the four instances (p2f2), which includes the two canvas draws for the panes:

| Rig | Draw calls | Per fighter |
| :--- | ---: | ---: |
| One static mesh, outline | 10 | 2 |
| **One rigid-skinned mesh, outline** | **10** | **2** |
| Rigid-skinned, no outline | 6 | 1 |
| Rigid-skinned, hand meshes swapped in (outline on all) | 26 | 6 |
| Puppet of 26 per-bone meshes, outline | 210 | 52 |

**2. Frame time, mean / p99 ms, no animation solve** (four instances):

| Rig | Desktop GL | Desktop iGPU | Web dGPU | Web iGPU | Web iGPU ×4 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Static | 0.30 / 0.56 | 0.93 / 1.09 | 0.68 / 1.63 | 1.61 / 2.23 | 2.09 / 2.86 |
| **Rigid-skinned** | **0.30 / 0.70** | **0.93 / 1.09** | **0.67 / 1.04** | **1.63 / 2.13** | **2.10 / 2.84** |
| Skinned, hand swap | 0.32 / 0.62 | 0.93 / 1.10 | 0.73 / 0.99 | 1.63 / 2.31 | 2.19 / 2.88 |
| Puppet | 0.42 / 0.72 | 0.96 / 1.13 | 1.02 / 1.50 | 1.60 / 2.17 | **3.22 / 4.08** |

At sixteen fighters in one pane (17 to 33 draw calls skinned, 417 to 833 puppet): skinned 1.24 desktop iGPU, 2.36 web iGPU, 2.14 web iGPU ×4; static 1.22, 2.30, 2.07; puppet 1.24, 2.21, **5.90**.

Reading it:
- **Skinning costs nothing measurable.** Skinned against static: at most 0.07 ms at sixteen fighters on the iGPU. Twenty-seven bones and 2,664 triangles are not a load for the Compatibility renderer on the web.
- **The outline works under skinning.** The inverted hull follows the posed body (`art/animation/a0/hull-outline.png`). Hard-edged faces leave hairline cracks in it, so the production mesh needs smoothed outline normals (Rendering and Art).
- **The puppet's cost is CPU draw-call overhead, and it only shows on a slow CPU.** On a fast CPU it is invisible. At 4 times slower it is about 5.5 µs a draw call: +1.1 ms a frame for the split-screen four (200 extra calls), +3.8 ms for sixteen. That would be 7% of the frame in an ordinary fight, so the puppet is out.

**3. The layer stack on the CPU** (GDScript, µs per fighter, solve plus the write to the skeleton; the in-scene mean divided by the four instances):

| Level | Desktop | Web dGPU | Web iGPU | Web iGPU ×4 |
| :--- | ---: | ---: | ---: | ---: |
| L2 key blend only | 8 | 10 | 11 | 46 |
| L1 (inertia, IK on two limbs, three springs) | 14 | 22 | 26 | 117 |
| **L0 full stack** | **20** | **28** | **34** | **161** |
| L0, p99 | 27 | 45 | 55 | 249 |
| L0 solved every second frame (a 30 Hz solve) | 10 | 14 | 17 | 82 |

Where the desktop time goes, in µs per solve: key blend (27 slerps) 6.1; inertia +1.2; modifiers +1.9; FK and IK on two limbs +2.9; IK on all four +4.7; springs +0.4 to 0.7; impact wave and clamp +1.3; total 16.7; the write to the skeleton 0.7. The key blend is the biggest single item, so skipping bones whose keys are identical is the first optimisation.

The engine-side skeleton update shows up as frame time, not in these numbers. Adding the full stack raised the desktop frame by 0.14 ms against 0.08 ms of solve, so the engine's share is about 0.06 ms. In the browser the frame rose by about what the solve cost.

**4. Against the proposed budget.** The spike solved every instance (the game solves each fighter once and writes it to each pane). Solving two fighters once and writing four skeletons at ×4 in the browser is about 2 × 154 + 4 × 7 = **0.34 ms mean and about 0.5 ms p99**, against the proposed 1.0 ms and 2.5 ms. Sixteen fighters at full rate would be 2.3 ms at ×4, which is what the degrade ladder is for. The measured L0 cost per fighter is 5 to 10 times below my first estimate.

**5. Hands: settled as a palm plus one finger slab** (`art/animation/a0/hands.png`, left fighter fist, right open).
- The finger slab is one bone per hand, one rotation from open to fist, and costs no draw call.
- The mesh-swap alternative adds 4 draw calls a fighter (26 against 10 for four instances) and about +0.09 ms at ×4, plus a swap state to animate. It also needs the swap to line up with the pose in the same frame.
- At Play zoom a hand is 2 to 4 px (Art: under 4% of body height is a decal), so fist against open only reads in close-ups and cinematics. That is another reason to keep it cheap.
- Art confirms the hand mesh (the slab needs a palm and a finger block that meet cleanly).

**6. What the spike settles, and what it does not.**
- **Settled:** one rigid-skinned mesh per fighter with a second outline pass, two draw calls, no measurable skinning cost; the puppet rig is rejected; hands are a finger slab; the proposed bone-layer budget holds with about 3 times headroom.
- **Not settled:** the real runtime's overhead (sim reads, data lookups, foot plant against the ground, contact sockets); a real old laptop; the game's own frame around the fighters; the hybrid-projection shader on a skinned mesh; blend shapes (not tried).

Raw results for all 86 runs are in `art/animation/a0/results.json` and the tables in `art/animation/a0/summary.md`. The game's determinism check (`render/tools/determinism.gd`) passed with the spike in the tree. Reproduce: `render/anim/spike/README.md`.

---

## 8. Keeping it render-only, so the sim hash never changes (item 7)

### 8.1 The one-way valve

**Animation reads the sim and never writes it.** Everything it needs already arrives as state or as events:

| Reads | From |
| :--- | :--- |
| Fighter position, facing, `rot`, state, stance, tier, wear, stage, meters, mood, style, form | `S`, read freely (`fx-events.md`, "What the renderer reads from the sim directly") |
| Ground height, slope, water depth, buildings' faces, `S.slides`, `S.craters` | `S` |
| What is happening now | `S.out.fx` events: `damage`, `launch`, `parry`, `window_open`, `rush`, `slide`, `skim`, `crater`, `building_hit`, `region_stage`, `cue` and the rest |
| Which part is playing and its tick anchors | A part cue from Combat's composer (§8.2) |

**Animation emits nothing into the sim.** No root motion, no hit volumes (reserved in `data-fields.md`, and not adopted here), no IK result the sim reads. `anim.rootMotion` stays a presentation offset.

### 8.2 What the sim must send, and what animation sends onward

**A part cue.** For each part it schedules, the composer emits one render-only cue at the part's start tick, carrying: the part id, the start, contact and end ticks (integers), the stretch in permille, the target fighter slot and region, the side and the weight class. The existing `cue` event ({actor, kind, text, source}) can carry it as kind `part` with the ticks in `text`, at no schema cost, or Simulation can add a typed `part` event. Either is emitted by the sim from data it already has and is part of the golden stream (a one-off regenerate when it lands, like any new event). **Combat and Simulation decide the form; I ask for the content.**

**Cancel and interrupt** signals are already there (`parry`, `damage`, `launch`, `ko`, `finisher_start`; §4.7). Animation must also read the running exchange's `cancel` flag.

**Marks animation emits on the render side** (never hashed, never in `S.out.fx`): `contact`, `smear`, `plant`, `whoosh`, `impact_freeze`, each with a slot and a socket. VFX places sparks at the actual striking socket instead of the sim's approximate point; Audio times the swing whoosh to the peak speed; Camera reads the impact freeze. A **socket query** (`socket_world(slot, name)`, valid after the frame's solve) gives them positions. This is render to render, which is allowed.

### 8.3 Randomness

The sim's random streams are off limits. Cosmetic variation (micro-noise, which of two equivalent renditions, shiver direction) draws from an animation stream derived from the match seed and an id, the way every other cosmetic consumer does (`fx-events.md`, "Cosmetic random streams"): proposed ids `anim` and `anim.<slot>`, integer-only derivation. Draws are keyed by (seed, slot, event tick), so a replay looks the same and adding a modifier shifts no other random number.

### 8.4 Where the data lives, and what is hashed

- **Poses, key sets, profiles and modifiers are not part of the sim's canonical data hash.** They live in `data/anim/` and are excluded, so editing a pose or tuning a modifier cannot change a golden or a QA baseline. A part's `anim.keySet` field is a render-only reference and is excluded too. (Combat's schema already separates `sim` and `render` blocks.)
- This needs an **EP and Tools ruling** on two things: `data/anim/` and its schemas (my owned paths are `art/animation/` and `docs/animation/`), and that the hash skips `anim/` and the `render` blocks.

### 8.5 Ticks, interpolation and frame rate

- All animation state advances on **sim ticks**: springs, smoothers, inertialisation offsets, the animation random streams. The pose solve runs **once per displayed frame** from the latest tick state, interpolating between the last two ticks (as Rendering already does for fighter position). The cheap stateful work runs every tick; the expensive bone work runs per frame.
- Consequences: animation is identical at 30, 60 or 144 fps; it holds in hit-stop and pause and follows the KO slow motion for free; `--fixed-fps 60` screenshots and replay videos are exact; and if a slow machine runs several ticks in one frame, only the last one is solved.

### 8.6 Verification

| Check | How | Existing tool to extend |
| :--- | :--- | :--- |
| Gameplay hash unchanged with animation on, off and stubbed | Run seeded matches through the full scene; compare hashes at every checkpoint | `render/tools/determinism.gd`; `cue_check.gd` already does this for poses |
| Negative control | Nudge a fighter from the animation layer once; the check must fail | `determinism.gd --negative-control` |
| No writes | A static check that nothing under `render/anim/` or `art/animation/` assigns to `S.*` | A small Tools script in CI |
| Hash independent of pose data | Edit a pose, regenerate the data hash; unchanged | `tools/validate.js` canonical hash |

### 8.7 The only values that cross the boundary

Animation authors **no sim-read field**. Three things touch sim-read data, and each has a rule:

| Value | Who authors it | Rule |
| :--- | :--- | :--- |
| **Family vocabulary and the can-follow table** (`poseIn`, `poseOut`) | I propose; Combat records them in its parts | Symbolic tags. A change alters what the composer may join, so **it is a sim change and re-baselines QA's golden hashes** |
| **Silhouette-clarity flag** on a part (a composition-time filter, `procedural-moves.md` §2.2) | The lint reports; Combat records | Set once, frozen. A change is a sim change |
| **Contact tick, reach and timing** | Combat only | I *validate* against them (contact key on the contact tick, reach inside the pose's envelope). If animation cannot meet them I file a **Combat request through the EP**; I never change them |

---

## 9. Stages, against Combat's plan (`procedural-moves.md` §12)

| Combat stage | Animation slice | New poses | Exit |
| :--- | :--- | ---: | :--- |
| 0 Measure, 1 Parity as data | **A0 Formats and spike (the spike is done, §7.8; formats and tools remain).** Pose and key-set schema, pose sheet and lint, validator rules, the rig spike, the 15 existing cue poses migrated into the pose format | 15 | Validator and sheet run; spike numbers recorded in Performance's table |
| 2 One slot generative (6 or more strikes, 8 or more launch vectors) | **A1 Mannequin runtime.** Pose apply, key blend, hit-stop, the part cue, no IK. Foundation set, 6 strike key sets, 8 flight poses | about 50 | Hash unchanged on and off; contact key on the contact tick 100%; frame cost recorded |
| 3 Full phrase grammar (30 to 40 parts) | **A2 The vocabulary.** All 170 core poses, IK, arcs, lag, reactions, inertialisation, and the timing profile chosen per part by weight class (§9.2) | 170 in all | Silhouette lint 100%; anticipation at or above the floor; no pops at joins (A8) |
| 4 Context bends | **A3 Situation and drift.** Slope, wall and water adaptation; modifiers v1 (wear, mood) | about 10 | Foot-plant test A3; wall and water scenes; modifier extremes lint A9 |
| 5 Specials, signature, a second fighter as data | **A4 Retarget.** A profile, deltas and own poses for fighter two; showcase for specials and the signature | about 100 | Second fighter with no code change; distinguishable from the first (Combat's T3) |
| 6 Finisher | **A5 Set pieces.** Finisher, break beats, transformation cinematics | about 60 | Every finisher plays; Orb reviews in motion |
| 7 Polish | **A6.** Timing polish, smear and impact marks, LOD tuning, motion reels for Orb | | Budgets met on the reference machine |

The smallest useful thing is **A1**: it replaces the placeholder cue poses with the real pipeline and proves the hash and the budget before any library is written.

### 9.1 A1 results (2026-09-30)

**What runs.** The mannequin (`render/anim/`) is in the game: `--noanim` brings the placeholder boxes back. Each fighter is one skinned mesh with the outline pass, 27 bones, about 2,700 triangles, in the game's own flat look and hybrid projection. Its pose is solved once a frame by `RenderAnim.solve` and written to every pane's copy. The pipeline:

| Piece | File | What it does |
| :--- | :--- | :--- |
| Rig and mesh | `anim_rig.gd` | R1's 27 bones and the faceted body from a palette (the fighter's own colours) |
| Poses | `anim_pose.gd`, `data/anim/poses.json` | 57 poses in sketch form (lean, twist, head turn, hand and foot targets, per-bone overrides), baked once at load by forward kinematics and closed-form two-bone IK; mirrored variants made on demand |
| Data | `anim_data.gd`, `data/anim/{keysets,profiles,cues}.json` | Six strike key sets, two timing profiles (snappy, fluid), Combat's 15 cues mapped to key poses |
| Solver | `anim_fighter.gd` | Layers: state and stance base (smoothed), cue pose, approach and strike parts from the running exchange, beam, reactions, moving hold, hit-stop shiver, spring chains on the extras |
| Hub | `render_anim.gd` | One solver per fighter, fed by the per-tick events, solved once a frame |
| Body | `anim_body.gd` | Skeleton and skinned mesh, baked by Rendering's `OutlineBake`, drawn with `RenderMats.fighter_body` and its `fighter_hull` outline (`OUTLINE_PX`); hit flash. Hidden fade is dropped until a fighter can hide |
| Tools | `tools/` | `pose_sheet.gd` (contact sheets), `anim_strip.gd` (filmstrip of a real exchange), `anim_reel.gd` and `gif.mjs` (motion reels), `anim_check.gd` (the checks) |

**The provisional part cue.** Simulation does not emit one yet, so the solver reads the running exchange straight from `S.dirS.ex.beats`. Every beat is scheduled before it fires, so a `strike` beat says exactly when a blow lands and who throws it, and a `rush` beat when a fighter closes; the wind-up starts early enough because of that. A strike's contact pose is reached on the beat's own time, within the profile's snap window. Blows are picked from the six key sets by a render-side integer hash of the exchange index, the blow's ordinal and the slot, so a replay looks the same and no sim random number is used.

**Changes to Rendering's files** (small hooks; Rendering reviews): `render/core/fighter_view.gd` builds the mannequin next to the placeholder (which stays, hidden, so the arm and head anchors keep working), skips the placeholder's cue pose and stance lean when the mannequin is on, and passes the anchor, hit flash and zoom; `render/core/main.gd` adds one line, `RenderAnim.consume(host.S, events)`, to the drained handler. The flare, spark, guard, badge and ring of the cues stay where they were.

**Checks** (`render/anim/tools/anim_check.gd`, 2 seeds, 4,200 ticks, both timing styles):
- the gameplay hash is identical with the mannequin off, snappy and fluid (seeds 4 and 12345);
- 164 and 128 blows reached their contact frame per match, and on each one the solved pose was the contact key to within 0.0014 rad (about 0.08 degrees);
- no NaN rotation; no line under `render/anim/` assigns to the sim state (static scan);
- the game's `determinism`, `cue_check`, `pane_check` and `flash_check` all pass with the mannequin on.

**Cost.** The solve is about 40 µs a fighter on the desktop editor binary (the spike's synthetic stack was 20 µs; this one reads the sim and bakes sockets). In the real game the view update rose from 0.660 to 0.773 ms and the frame from 1.87 to 2.03 ms mean (desktop, 1280×720, one pane, seed 4, 3,000 frames), with the same p99. At the spike's browser-at-4× ratios two fighters cost about 0.5 ms, inside the proposed 1.0 ms.

**What A1 does not do yet:** IK to the defender's socket and the ground (contact reach is authored into the poses: the lunge is in the hips), foot plant, situation adaptation, the style modifier stack, inertialisation across parts (the base pose is smoothed, which is a first version), interpolation between tick states (a pose steps with the sim tick), Combat's real part cue. The 57 poses are a first mannequin-quality pass, reviewed on the sheets at 22, 38 and 52 px; some (the extremes of the reactions and the hook) need a second pass.

**Fields I need from Simulation and Combat** (through the EP, to replace the provisional cue):

| # | Need | Why |
| :--- | :--- | :--- |
| 1 | A part cue per composed part: actor, part id, key-set id, start tick, contact tick and end tick, stretch (permille), target slot and region, side, weight class. `cue` with kind `part` and the ticks in `text` is enough; a typed `part` event is cleaner | The solver would stop inferring from beats; chain links, showcases and specials need it (they are not beats of a template) |
| 2 | A cancel or interrupt signal per part (parry, launch, KO, finisher takeover), or an explicit `part_end` | Today it reads `ex.cancel` and the beats' `done` flags |
| 3 | The part's `reach` and height band | To place the contact target (A2 IK) and to validate the contact key |
| 4 | Combat's readability minima by weight (anticipation ticks) | The profiles' load lengths are provisional |
| 5 | The render read list: wear and stage per region, brink, meters, form, Pride state | The style modifiers (A3) |
| 6 | The `damage` event's region for every hit, the launch vector class on `launch` | Reactions and flight poses |
| 7 | Animation stream ids `anim` and `anim.<slot>` in `fx-events.md` | Cosmetic variation beyond the integer hash |

### 9.2 A profile per part (Orb, 2026-09-30, after the reels)

Orb watched the two reels: snappy "would work well in attack rushes", fluid "would work well with power strikes". So the timing profile is no longer one global choice. **It is chosen per part by weight class, from data,** in A2:

| Part or weight class | Profile |
| :--- | :--- |
| Approach and rush (every `rush`, `rush.chain`, `rush.far`) | snappy |
| Light strikes and chain links | snappy |
| Heavy strikes, power strikes (`o.big`, heavy weight), heavy clash | fluid |
| Launches (the striker's send-off and the flight that follows) | fluid |
| Everything else (base pose, cues, reactions) | the fighter's default |

How it is built:
- `data/anim/profiles.json` gains a `by_part` table (weight class to profile name) next to `default`. A fighter's profile (personality override L1, §2.5) can replace any row, so the Cyborg's heavy strikes can stay snappy. No constant lives in code.
- The solver reads the profile of the part it is playing (today it reads one for the whole fighter). The weight class comes from the part's own tag once Combat's part cue carries it (`weight`: light, heavy, special, finisher); until then from the exchange kind and the strike's `o.big`.
- **Blending at a change of profile.** A rush (snappy) into a heavy strike (fluid) changes profile inside one exchange. The in-betweener already inertialises between parts (A2), so the hand-over has no pop; the profile's numbers apply from the next part's first tick, and the contact tick never moves.
- **Hit-pause.** The shiver follows the striking part's profile (0.9 u snappy, 0.4 u fluid), so a fluid power strike gets the gentler hold.
- **Test.** Extend `anim_check.gd`: a forced exchange with a rush into a heavy strike must show snappy load and snap lengths on the rush and fluid ones on the strike, and the gameplay hash must not change.
- The reels will be re-cut in the mixed setting for Orb after A2. (The mix itself landed in the A2 first pass, §9.3.)

### 9.3 A2 first pass: facing, joints, contact (Orb's playtest, 2026-10-01)

Orb's playtest found four faults: fighters sometimes face backwards, elbows bend the wrong way or an arm points straight behind the body, one fighter passes through the other with both facing away, and hits do not always touch. All four were measured first (`render/anim/tools/face_scan.gd`, `limb_scan.gd`, seeds 4, 12345, 7, 99, 3000 ticks each), then fixed on the render side only. The gameplay hash is unchanged with the mannequin off, on, snappy, fluid and mixed (`anim_check`, `determinism`, `pane_check`, `flash_check` pass).

**1. Facing.** The sim's `face` goes stale: after a dodge's warp (the defender lands 74 u behind the attacker) and in trade-blow swaps (26 to 35 u), `face` still points the old way while the fighters are `locked`. The mannequin now draws `vface` (`AnimFighter.update_face`):
- in an exchange, locked or charging: toward the opponent on the shortest arc (nothing changes inside 14 u, where the opponent gives no side);
- free and running faster than 250 u/s: the travel direction, except that backing away from a close opponent keeps the face on him (the retreat pose);
- otherwise the sim's `face`, except that an idle free fighter within 900 u looks at the opponent (not in the escape stance).
A new side must hold 0.03 s before the turn starts, and the turn is the existing 0.16 s eased turn through front-on. The hook is one line in `fighter_view.gd` (`_turn = move_toward(_turn, RenderAnim.face_for(S, f), ...)`). Before and after (4 seeds, 3000 ticks, 24000 fighter-frames): ticks facing away from the opponent in an exchange 944 to 140 (the 140 are the 2 to 7 ticks of a side swap before the turn starts), ticks running backwards 1043 to 83 (the 83 are the retreat pose).

**2. Joint limits.** Two layers.
- *Bake.* `ik2` solved the elbow and knee in any plane, so the forearm's rotation was not a hinge. `AnimPose.hinge_fix` now twists the upper bone about its own axis so the joint is a pure hinge (elbow bends toward +x of the bone's frame, knee toward -x). The joint and the end do not move; the pole only decides which way the elbow points. Blends of pure hinges stay hinges.
- *Runtime.* `AnimPose.limit_limbs` (after every layer, before the sockets): elbow 0 to 150 degrees, knee the other way, 3 degrees of give, any sideways component removed, and an upper arm may not point straight back along the body (its last 0.2 of the backward axis is squeezed into 0.1, continuous). `limb_scan` with the pass off then on, 24000 fighter-frames: elbow or knee hyperextension 0 and 0 (the bake fix did it; the A1 build had 12547 elbow and 613 knee frames beyond range and 24325 frames with a sideways elbow), arm straight back 38 to 0.

**3. Contact.** Each key set names the striking `limb` and the `target` region (head, chest, gut). From the beat's contact tick the striking hand or foot is IK'd (`_contact_ik`) to the defender's actual socket (his last solved pose, his visual facing, the shortest-arc offset), minus the fist and the body's surface, blended in over the snap, full at the contact tick and through half the follow-through, out over the recovery. What the arm cannot reach is made up by the hips' lunge (up to 11 u for a hand, 7 for a foot) and then a step-in of the whole body (14 u, 10 u): that is render-only and the anchor does not move. The authored pose is still the look and its contact-tick fidelity is still checked before the solve (worst error 0.0014 rad). The defender's reaction starts on the damage event of the same tick (as before) and now also recoils: a root push of up to 6 u decaying over 0.07 s. `anim_check` asserts that every blow within reach ends within 1 unit of the defender (it ends within 0.00).
What the check also found (Combat's and Encounter's, not fixable in render): of the blows that hit (damage above 0) in seeds 4 and 12345, 41 percent (27 of 66) land with the fighters farther apart, or at another height, than an arm, the lunge and the step-in can reach (about 68 u centre to centre at the same height). They are concentrated in TRADE BLOWS (125 to 215 u), GUARD BREAK (78 to 137 u) and PRESSURE - GUARD HOLDS (95 to 125 u). A strike beat whose damage is 0 (a miss, e.g. heavy DODGE & READ, tick 1079, seed 4) is left to its authored pose.

**4. Pass-through (the sim's).** Inside an exchange the two fighters swap sides, with the shortest-arc offset changing sign, 45 times in the 4 seeds above. Two signatures: DODGE & READ and DODGE & COUNTER (the defender is placed 74 u behind the attacker, then 9 u apart as the counter closes: seed 4 ticks 87, 360 and 368, 572, 1027 and 1034, 1229 and 1236, 1384) and TRADE BLOWS (the pair swaps at 4 to 16 u: seed 4 ticks 934 and 951). Combat's no-pass-through rule should cover both. The visual facing keeps the swap readable (both always face each other) but cannot stop the bodies crossing.

**5. The profile mix (§9.2, done).** `profiles.json` has `by_part`: light, rush and chain snappy; heavy, power and launch fluid. Each blow keeps its own kind's profile (load, snap, follow and recover lengths, overshoot, lag); a launch or a charge moves on the fluid base smoothing. A forced style (`--anim-style`, tools) overrides it for every part. `anim_check` runs a fourth mode, `mix`.

**Cost.** Web bench (`tools/bench-web.mjs`, CPU x4, 5 runs each, alternating, the machine shared with other sessions): mean frame 16.0 ms before and 16.4 ms after (median of the run means; runs scatter between 15.2 and 20.0), draw calls identical (192.9). Native solve cost 34 to 55 us a solve (mix, snappy, fluid). The contact solve runs only in a blow's window.

### 9.4 A2 second pass: inertialisation, defence and clash poses, the mixed reels (2026-10-01)

**Inertialisation** (`AnimFighter._inertialise`). A bone that turns more than 0.5 rad between two solves is a join (a part starting or ending, a cue, a reaction, a mirrored key set). The jump is taken as an offset from what was drawn last solve, and it settles by itself on an eased 0.1 s (snappy) or 0.18 s (fluid) curve, in tick time, so a hit-stop still lets it finish at half speed. A join announced close to a blow settles before the contact tick, so the contact key stays exact. `pop_scan.gd` (4 seeds x 3000 ticks, 18000 fighter-frames, bone turns above 0.6 rad in one tick): 493 before, 230 after, worst 3.12 rad before, 1.40 rad after. The 230 left are eased swings (a 2.8 rad arm settling in six ticks), not jumps. The settle times are `inertia_s` in `data/anim/profiles.json` (0.1 snappy, 0.18 fluid; the schema field arrived in bf8f941).
**The contact solve's pole** is now the authored pose's own elbow or knee, so the solved limb is its neighbour and the blend does not turn the upper arm through a hinge twist.
**What it found for Combat.** Blows announced to the animator fewer than 4 ticks before they land cannot be wound up. In seeds 4 and 12345 only TRADE BLOWS does it: 7 or 8 of 78 blows (both fighters' counter strikes appear in the beat list on the tick they land). Those blows still pop to their contact pose (the offset smooths the rest). (Combat traced them to a parried string, not to TRADE BLOWS scheduling; fixed on the render side in §9.6.)

**Vocabulary: nine poses, 57 to 66** (`art/animation/a2-vocab-sheet.png`, record `art/animation/records/A2-poses.md`). Driven by the beats the sim already runs, so no new sim data:
| Beat or event | Who | Pose | Window |
| :--- | :--- | :--- | :--- |
| wind | defender | def.parry_ready | from the beat to the parryable blow, out 0.1 s after |
| wind, parried (ex.cancel) | defender / attacker | def.parry / react.rebuff | the blow's tick, 0.3 s |
| slip | defender | def.slip | 0.35 s |
| dodge (the blink) | defender | def.blink_in | 0.3 s |
| guardBreak | defender | def.guard_break | 0.5 s |
| clashWave | both | clash.push | 0.4 s |
| damage with kind "guard" | victim | def.guard_hit (replaces the flinch and the region wave) | the reaction's own |
| KO, 0.8 s after, the winner | winner | emote.victory | held |
The ground-contact poses (braced tumble, bounce, lip launch, tech flip, quick and slow get-ups) and On the Chin are held for World's events (`left_ground`, `bounce`, `land`, `tumble_end`, docs/world/ground-contact.md) and his first moveset.

**Mixed reels for Orb.** `art/animation/reel-mixed.gif` (the 735-tick exchange of seed 4 in Orb's mix) and `art/animation/reel-mixed-vs-snappy.gif` (snappy only on the left, the mix on the right): light blows and rushes keep their snap, heavy blows get the fluid wind-up and overshoot.

### 9.5 A2 third pass: idle and movement variants, KO, the parry test (2026-10-01)

**Six poses, 66 to 72** (`art/animation/a2-vocab2-sheet.png`, record `art/animation/records/A2-poses.md`), all chosen in `_target_base` from state the sim already has, blended through the base smoothing:
| Pose | When |
| :--- | :--- |
| stance.air | free, more than about 50 u above the ground (the feet hang instead of standing on air); 36 to 129 times a match |
| move.ascend, move.descend | in the air and not dashing, climbing or diving faster than 150 u/s |
| idle.winded | free on the ground with ki under 6 |
| idle.relaxed | free on the ground, aggressive or defensive stance, more than 700 u from the opponent and nearly still (blended at 0.8) |
| down.ko | down and `S.game.ko` is this fighter: flat on the back, never the get-up |
`emote.victory` (§9.4) is checked too: with the KO forced, the winner reaches it (0.63 rad over 27 bones) and the loser reaches down.ko (0.02). Seeded AI matches rarely reach a KO (HP no longer ends a match), so that check was a one-off with the state set by hand, not part of `anim_check`.

**The forced-parry test.** `anim_check` now runs the defensive and clash beats on a stub exchange (wind, a parryable blow, slip, dodge, guardBreak, clashWave) with the parry forced by setting `cancel`: 13 cases, each layer must pull the pose toward its own key and leave the other fighter alone. It found a real bug in the second pass: the parried attacker never played react.rebuff (the wind branch returned for the attacker). Fixed.

Transformation poses (3 s, 1.5 s, 0.8 s, from the new `version` on the transform event) are not started: they need a design brief and Combat's cue.

### 9.6 A2 fourth pass: movement variants, the transformation, the parried string (2026-10-01)

**Movement variants, three poses (72 to 75)** (`art/animation/a2-vocab3-sheet.png`). Free fighters never move in depth (`z` is non-zero only in building launches), so a strafe has no sim motion to follow; the guarded steps stand in for it:
| Pose | When |
| :--- | :--- |
| move.step_f | on the ground, 50 to about 450 u/s toward the opponent: a guarded advance, fading into the dash as it speeds up |
| move.step_b | the same going back (the retreat pose takes over above about 300 u/s) |
| move.sprint | above 1000 u/s, blended over the dash to full at 2200: body almost level, arms swept back |
In seeds 99 and 12345 (7000 ticks): 1205 to 1602 step blends and 64 to 270 sprint blends a match.

**The transformation, placeholder poses for all three versions** (`data/anim/forms.json`, `art/animation/a2-form-sheet.png`). Keyed to the sim's `transform` event and its `version`, with the beats of moveset-rules §10.8 in ticks (full 60, 30, 90; short 24, 18, 48; live 10, 14, 24):
- *gather*: form.gather (the charge pose compressed: knees bent, feet together, hands drawn in to the breastbone, head down), eased in; a live one is a flinch inward at 0.6;
- *break*: one snap to form.break (full height, chest open, arms out and down, open hands, chin up) on the first tick of the beat, a little overshoot, then it eases toward form.settle: the silhouette changes here and nowhere else;
- *settle*: form.settle (a taller idle) holds for 45 ticks (full) or 30 (short) and then eases back into the fight; live fades from the first tick (the upper body holds while he drifts back).
The clock is the pause's own ticks (`S.pause.left` counts them down, and the beats add up to the pause's 180 and 90 ticks): the sim is frozen, so sim time does not move. Live has no pause and runs on sim time. A transformation's frames skip inertialisation (no ticks to settle on); the way back into the fight is inertialised when the ticks run again. No scream, no fists at the hips, no hair change; the burst, the ring, the crater and the aura swap are VFX's and the camera's. `anim_check` tests all three versions at the gather, the break, the settle and the end without a match (12 checks), and a real full transformation played in seed 99 with no NaN. The size step of a tier is the view's.

**A parried string.** Combat traced the 'late' blows (the 7 or 8 of 78) to the leftover strike beats of parried exchanges: the sim keeps listing them and fires them later, and the animator drew each one when it was done. In a parried exchange only the blows timed before the parry are drawn now (the exchange time at the first sight of `cancel` is remembered). Blows announced under 4 ticks ahead, 4 seeds: 7 or 8 of 78 before, 0 after. Encounter will end the string in the sim later.

### 9.7 A2 fifth pass: battle damage (rule-of-cool feature 1) (2026-10-01)

All read from the wounds state the sim already has (`f.wear`, `f.stage`, `SimWounds.brinkProgress`), render only, on sim time only (so it replays). Three poses (78 to 81): wound.arm_limp, wound.leg_favour, wound.sag (`art/animation/records/A2-poses.md`).
| What | Source | Effect |
| :--- | :--- | :--- |
| Heavy breathing | average wear of the four regions (about 60% of the broken threshold on average is the maximum) | the chest rocks and the shoulders heave, faster (0.8 to 2.2 Hz) and deeper as wear rises; the head gets heavy. Idle and movement, not in the air |
| Stagger | brink progress from 0.45 | a slow irregular sway of the pelvis (about 4 degrees at the brink) and a little give in the hips |
| The stance sags | brink progress from 0.35, up to 70% | wound.sag blended into the free base pose: hunched, head heavy, knees soft |
| A broken arm hangs | arms stage 3 | the arm's bones go to wound.arm_limp at 92% (50% in the air), the hand slack; blows use the other arm: where a key set strikes with a hand the animator picks the mirror side |
| A broken leg is favoured | legs stage 3 | the leg's bones and half the pelvis go to wound.leg_favour (85%; 50% in a blow), the weight on the good leg and a dip on each step; kicks use the other leg |

The hanging arm and the favoured leg are chosen by a hash of the fighter's slot (the sim has one arms region and one legs region, so no side). It stays through transformations (the layers run after the form pose). `anim_check` tests it on a match with the wear set by hand: the arm hung on 216 of 216 calm frames, no blow used a broken limb, the stance sagged toward the brink and the worn chest moved 0.52 against 0.36 for the fresh one. `anim_reel.gd --wound=0:arms+legs,1:brink` shows it (`art/animation/a2-wounds-fresh-vs-hurt.gif`).

**What the sim would need for a broken arm to stop being used in strikes** (Encounter's and Combat's). Today the broken arm still throws every arm blow at `armsBrokenMul` damage, and the director does not know a side.
1. A side per limb region (which arm is broken) in the wounds state, so the presentation and the rules agree instead of the animator picking by hash.
2. The strike atoms for an arm blow with a broken arm pick the other arm, or a kick, a headbutt or an energy blast: the director's template choice excludes the broken limb's atoms.
3. Guard and perfect-block windows lose the broken arm's side (a one-handed guard: a narrower window, which `armsGuardMul` approximates).
4. For legs: kicks by the other leg only, and a stance that cannot kick off a broken leg, matching the animator's choice.

**Set pieces, planned not built:** `docs/animation/set-pieces-plan.md` (the crater-landing entrance, the staredown, the winner in the wreckage: 6 new poses, about 0.5 reviewer-hour, and the events each waits for).

### 9.8 The overhaul, units A to C (2026-10-01): the active ragdoll, blow-driven reactions, polish

Plan and the wishes for World and Simulation: `docs/animation/overhaul-plan.md`. Four new poses: skid.back, skid.front, skip.water, getup.push (`art/animation/records/A2-poses.md`).

**A. The active ragdoll** (`render/anim/anim_ragdoll.gd`, `data/anim/ragdoll.json`). Twelve degrees of freedom (head, spine, each upper arm in two axes, each forearm, each thigh and shin) on springs around the solved pose. Stepped once per sim tick in `AnimFighter._rd_tick` from the fighter's own state (the sim's velocity, the acceleration from its change, `rot`, `spin`, `slide`, `state`), in the body frame (rotated by `rot`, mirrored by the visual facing), so the picture is the same at any frame rate. What it does:
| Move | Source | Effect |
| :--- | :--- | :--- |
| Flop and trail | launched | limbs stream opposite the velocity (drag) and whip with acceleration (inertia); the looseness ramps to 85% in about 0.05 s |
| Tuck | spin above 4 rad/s (the sim's launches spin at 8 to 16) | the body tucks, breathing between a ball and open limbs with the spin angle (up to 70%) |
| Brace | descending, the ground within 0.3 s (from the predicted contact time) | arms up and forward, chin down, knees soft; not for a building hit |
| Crumple | flight to down, or flight to skid | an impulse folds the spine, snaps the head, flings the limbs, scaled by the speed it came in at |
| Skid | the slide: on the back if he moves away from the way he faces, face down otherwise | skid.back / skid.front, the near arm trailing and dragging, the ragdoll loose at 55% |
| Water skip | the `skim` event (no actor: matched to the launched fighter at that x) | an arch (skip.water, 0.35 s) and a kick |
| Ground events | `left_ground`, `bounce`, `land`, `tumble_end` (World's plan, a stub in the planned shape until they exist) | a bounce whips by the normal speed, a slam folds, a skid whips, the end of a tumble lets go |
Determinism: one step per tick, no random draw; `anim_check` runs the same match at one and at two ticks a frame and requires the same ragdoll state (it does). Reduced motion (`RenderAnim.reduced_motion`) scales the drive, the targets and the impulses to 35% and turns the catch smear off (tested: 10.9 against 17.1). `--noragdoll` switches every overhaul layer off for A/B. Cost: 7 to 12 us a tick a fighter (most ticks a standing fighter returns at once), 12 quaternion writes a solve while active.

**B. Hit reactions from the blow** (`AnimFighter.on_hit`). The direction is the blow's push in the body frame (attacker to victim, mirrored by the facing), the force the damage over 60. Head snap (toward the push, with an uppercut lifting it), a torso fold from the front for a gut blow and an arch for a head blow, arms and legs thrown by the push with an asymmetry, a root push that decays in 0.07 s plus a vertical lift for an uppercut, and a stagger sway for a heavy blow. All scaled by wear and the brink (a worn fighter reacts about 1.9 times as much: 42.7 against 22.5) and by a deterministic per-hit variant (a hash of the tick, the slot and the hit count): two identical hits in a row differ, the same hit at the same tick is the same. The flinch pose stays at 55% so the silhouette holds. Guarded blows are 40%. `anim_check` tests direction, force scaling (0.3 to 1.2 gives 8 to 27), wear, variant, replay equality and reduced motion.

**C. Polish.** (1) The get-up is three stages (prone, the push-up, the kneel) and, when worn or on the brink, the rise out of the kneel takes up to 0.8 s after the sim says he is free (a slow get-up). (2) The lean into acceleration while free (a start leans forward, a stop back: up to 20 degrees), and a hover bob in the air. (3) The contact catch: a striker carried more than 160 u in one tick and more than 1.5 times the last tick's jump is drawn up to 24 u behind the anchor and caught up in 3 ticks; the contact solve reaches that far, so the contact tick stays exact. Today's sim has no such jump in the seeds (the rush is a smooth run of 120 to 850 u ticks), so it is built and unit-tested but unseen in play until Encounter's contact slice lands.

**Cost, on the exported HEAD plus these files.** Native: 7 to 12 us a tick a fighter for the ragdoll, solve 50 to 56 us each (A2 end: 41 to 51). The web bench is in the report.

### 9.9 The overhaul, unit D: Orb's tuning, per-fighter shapes, slopes, aim, weight and cloth (2026-10-02)

**D1. Flail, then tuck, per fighter; the hit kicks as data.** Orb: "ragdolled: favour limbs flailing early in a launch, tucking only at high spin". A launch now flails first: every limb follows its own slow oscillation (a phase per joint, a clock from sim time, nothing random) for the first 0.35 to 1.2 s (`flail` in `data/anim/ragdoll_motion.json`), and the body tucks only at a spin of 10 to 15 rad/s (the sim's launches spin at 8 to 16) and not before 0.25 to 0.6 s, at most 70%. The shapes the body tucks, braces, skids and crumples into are each fighter's own, converted from Art's silhouette reference (`art/concepts/silhouettes/gen.mjs`): P circles (a rolled ball), A blades (long limbs thrown out), E wedges, C steps (square quarter-turns), one angle per degree of freedom. Until the four fighters exist the roster ids map to shapes by a placeholder table (`fighters`: KAI to P, VORR to A; the default is P). The hit-reaction kicks are now data: `hit` in the same file gives, per degree of freedom and region hit, the kick as gain x force x (kx x dx x (1 + vx x v) + ky x dy + kc x w); the numbers of unit B are in it unchanged (the tests give the same values). A forearm's `hi` limit was lifted from 1.6 to 1.8 so its tuck target is not clipped (Tools' limit check).

**D2. Feet and hands on the ground.** A standing fighter on a slope has one foot higher than the other: `_ground_feet` reads the ground under him (one terrain read a solve, the slope reads only while he stands or slides, cached within 3 units), moves the pelvis to the mean and solves each leg to its own foot's ground (two-bone IK, the knee where the pose has it) before the contact solve, so a blow reaches from the new stance. A skid is pitched to the slope along its way (the body tilted by the ground's slope, eased). On a crater wall the ankle height error was 4.2 u without it and 0.03 u with it (`anim_check`, 26 foot samples; `ragdoll_lab.gd --slope` shows it). Not done: foot pitch (the toes following the slope) and hands reaching the wall of a crater in a skid; both need the contact points, which wait for World's `land`/`bounce` events.

**D3. Look, aim, weight, cloth.**
| Layer | What it does |
| :--- | :--- |
| Look-at | the head (55%), the neck (30%) and the chest (10%) pitch toward the opponent's head, up or down, eased over 0.12 s, in an exchange or when he is within 1200 u ahead; not when launched, down or charging a beam |
| Aim | a beam is thrown along its own line: the arms (and a quarter of that on the chest) turn to the beam's direction once it is fired, and to the opponent's direction while it charges (the fire pose's forward is fixed) |
| Weight | every blow is weighed continuously, damage over 70 (a chain link counts as 1): the load stretches (x0.82 to 1.24), the follow-through (x0.9 to 1.2), the recovery (x0.94 to 1.18) and the overshoot (x0.76 to 1.72) with it; a heavy blow winds up longer and swings through further, a light one is quick. The contact tick never moves (anim_check: contact error 0.0014 rad, as before) |
| Cloth | the sash and pack chains are stepped once per sim tick now, never per frame (a replay shows the same cloth), driven by the velocity, the acceleration (a start flings them back, a stop forward) and a flutter at speed (4.5 Hz, at most 7 degrees) |
`anim_check` tests: the same match at one and at two ticks a frame ends with the same ragdoll, cloth and look state; the blow weights rise with the damage; the aim turns the arms by the aim; the feet; the head looks at the opponent in play. `--noragdoll` switches D1 to D3 and A to C off together for the before.

**Cost.** `render/anim/tools/solve_bench.gd` (the same seeded match, alternating configurations): the whole overhaul is about 14 us more a solve than with it off (66 against 56), of which the ground feet about 2. Reading it: 14 us x 2 fighters x 60 a second is under 2 ms a second of native CPU; the web number is in the report.

### 9.10 The overhaul, units E to H (2026-10-02)

Poses: move.burst and move.brake (`art/animation/records/A2-poses.md`). Data: `data/anim/personality.json` (F), `data/anim/quality.json` (H). Everything is behind `--noragdoll` (and the quality levels), render only, and deterministic (sim time and tick state only). The write-ups below give the numbers from `anim_check`, `solve_bench` and the GIFs in `art/animation/overhaul-*.gif`.

**E. The defender's side and the fighters' own flinch.**
- *The flinch keys.* A hit pulls the victim toward his own shapes (the fighter's brace shape for a light blow, his crumple shape for a heavy one, from Art's silhouettes), weighted by how hard and decaying over 0.3 to 0.7 s (longer when worn), on top of the blow-driven kicks of unit B. A disc-shaped fighter curls, a blade-shaped one throws his limbs: two shapes flinch 0.37 rad apart in total after the same blow (the test), and the GIF shows both.
- *Anticipation.* The attacker's blows are in the beat list ahead of time. In the last 0.25 s before a heavy blow lands the defender braces (arms up, chin down, in his own brace shape, 70% for a heavy blow, 25% for a light one, and 30% less if he is not in the defensive stance); the near-miss flinch (a blow with no damage that he did not evade) is a small head-back kick. In seeds 4 and 12345 the brace played 114 to 156 ticks a fighter in 3000; a near miss without a dodge or slip beat never occurred (the misses in play are all dodged).
- `_next_blow` and `_has_evade` are tested on a stub exchange.

**F. Transitions and idles with personality** (`personality.json`).
| What | Effect |
| :--- | :--- |
| Weight shift | a slow sway of the pelvis and a little shift of the hips, per stance (evasive 2.4, aggressive 1.6, escape 1.0, defensive 0.7) |
| Knee bounce, heel lift | a hop on the toes at the stance's rate (evasive 2 units at 3 Hz; defensive almost still) |
| Breath | per stance, and by form: a higher tier breathes slower and deeper (tier 4 at 70% the rate and 140% the depth; tested 0.0168 against 0.0120 rad) |
| The guard comes up and goes down | the arms are kicked toward the new guard when the stance changes to or from defensive, and the base pose lets the arms follow the torso a little later (the base smoothing is per bone, by the bone's lag) |
| A turn-around is a step | when the visual facing flips: the weight dips, one foot swings through, the hips twist toward the new side and the shoulders against it, over 0.22 s, with the view's turn through front-on |
Only while standing still or nearly (the sway fades out as he moves), never in a blow, and the sway is capped by reduced motion at 35%.

**G. Flight.**
- *Bank:* a roll into a turn (the shoulders tilt toward the camera with the lateral acceleration, up to 17 degrees), in flight and when fast.
- *Burst and brake:* a hard push from nearly still is a coil (move.burst, 0.22 s) before the dash; a hard slowdown from a run is a brake (move.brake, 0.3 s): leaning back, feet and arms thrown forward. They fire once per move.
- *Cloth:* the streaming is now also driven by a vertical fall (a fall lifts the sashes). The mannequin has no hair bones; the cloth chains (pack and sashes) are what streams. Per-fighter hair is Art's attachments.
- *Nearby impacts:* the sim's crater event shakes a fighter within 700 u: a damped hover shudder (1.6 u, 3.2 Hz, 0.5 s) and a startle in the arms, scaled by the crater's energy and the distance.
- The ground-event handler no longer breaks on the sim's event type (the fields are read through `get`, so World's events can add theirs).

**H. The quality switch.** `RenderAnim.set_quality(level)`, or `--anim-quality=NAME`, with the levels of `data/anim/quality.json`; the host should call it from the web's quality setting (a line for Rendering, in the report). Layers: ragdoll, feet, look, aim, personality, transitions, defender, flight, cloth, lean (one call, `RenderAnim.layer(name)`, at each site; `--noragdoll` is the master). `solve_bench.gd` alternates configurations round by round and reports the minimum; on this machine (loaded, so read the order and the rough sizes, not the decimals):
| Layer off | Saves, us a solve |
| :--- | ---: |
| ragdoll | 16 |
| feet | 15 (about 5 of it when standing on flat ground; the leg solve runs every second tick) |
| look | 6 |
| transitions | 6 |
| cloth | 6 |
| lean | 4 |
| flight | 3 |
| defender | 2 |
| personality | 2 |
| aim | 0 (it only runs while a beam charges or fires) |
| the whole overhaul | 27 (53 to 80 us a solve) |
Levels, mean us a solve: high 86, medium 75 (drops look, feet, personality), low 68 (also transitions, defender, flight, cloth, lean, aim: keeps the ragdoll, the hit reactions and the launches), minimal 64 (the ragdoll too: the A2 behaviour). **Drop first:** feet, then look, then transitions and cloth; keep the ragdoll for the launches and the hits as long as possible (it is what Orb asked for most). The gameplay hash is identical at every level (`anim_check`).

**Also fixed.** Placing a skid's pitch no longer stops once it settles; the ground-feet cache; and the catch smear's trigger (unit D). The catch smear still waits for Encounter's contact slice.

### 9.11 Units I to L: Encounter's contact slice re-tested, the dodge, the winner, the showcase reel (2026-10-02)

**I. On Encounter's contact slice (1b8b671).** Re-tested on seeds 4, 12345 and 7:
- *Contact at 58 u.* Every damaging blow now lands within reach: 59 contacts in 6000 ticks, **0 beyond reach** (it was 41%), worst gap 0.00 units, contact-pose error still 0.0014 rad, blows announced under 4 ticks ahead 0. The sheets show the fist meeting the chest with the step-in (`art/animation/overhaul-i-contact-at-58u.gif`).
- *The catch smear.* A striker moves over 250 u on the tick his blow lands about once in 2000 ticks a fighter here (3 in 3000 ticks of seed 12345; 4 in seed 7; the last ticks of a rush grow geometrically, 220, 360, 630, 850 u). The smear (the body drawn up to 10 u behind the anchor, caught up in 3 ticks, the contact solve reaching that far) now triggers on those ticks. The earlier trigger (a jump over 1.5 times the last tick's) never could: the sim has no discontinuity, the run is smooth. What read as a pop was the pose, not the position: the dash weight faded out over the last 22% of a rush, so the fastest ticks were drawn standing. It now holds to the last tick (the strike's own load takes over at the contact), and the rush ends in a streak.
- *The step-around dodge.* Every dodge in play is now `side: cross`: two moves of about 4 ticks, up and over the attacker, then down behind him. The defender gets def.hop (knees up, arms tucked, rolling over the blow) and def.drop (legs reaching, arms out), each timed from the beat's own length, with the inertialisation held off so a four-tick pose shows (`overhaul-i-step-around-dodge.gif`).
- *Strings ending on the parry.* No parried exchange occurred in the seeds, so this was tested only on the stub exchange (it still passes: the beat test); the render-side workaround (draw only the blows timed before the parry) stays, it costs nothing and cannot hurt now that the sim ends the string itself.

**J. The dodge itself, not the near miss.** The near-miss flinch never fired because every miss is dodged, so it is retargeted. The defender leans away (head and chest back, arms back, the weight on the heels) in the 0.14 s before his dodge or slip beat; the attacker, who finds nothing where the defender was, over-commits (chest and head forward, arms with it, carried a step past, 7 u of root travel); and a blocked blow (the sim's damage event of kind guard) bounces the attacker's arms back with a small step back. In seeds 4 and 12345 the lean-away played 5 to 6 times a match and the block recoil 2 to 8 (`overhaul-j-dodge-lean-away.gif`, `overhaul-j-dodge-overcommit.gif`).

**K. The winner in the wreckage and the KO's fall** (`data/anim/winner.json`). After a KO: 0.8 s later the winner stands spent (win.stand, arms slack, the chest heaving with his real wear) for 1 s; then he looks over what the fight made for 2.5 s (win.survey, the head and neck sweeping across the scene, 0.8 rad, the shoulders still); then it ends by his shape key: the hero holds the survey, the Anti-hero takes emote.victory (a data choice). The loser falls: a stagger (react.stagger) and then flat on the back over 0.5 s, with the ragdoll's crumple and a head snap on the first tick down, instead of an instant flat. Tested on stub fighters (the beats and the fall). The GIFs are a look test (`ragdoll_lab.gd --ko=N` tells a running match a KO has happened): `overhaul-k-winner-in-the-wreckage.gif`, `overhaul-k-ko-fall.gif`.

**L. The showcase reel** (`art/animation/overhaul-L-showcase-reel.gif`): 16 seconds of seed 4 from tick 1800, the match camera cropped close on both fighters, before the overhaul on the left (`--noragdoll`) and after on the right. The same seed and sim: the left and right are the same fight, frame for frame. It shows hits, a launch, blocks and a dodge in one cut; the fighters' reactions, idle motion, brace and flight differ throughout. (A 20 second cut ran to a stretch where the match camera had gone with a launched fighter, so it stops at 16.)

### 9.12 Units M to P: the review pipeline, the clavicle hunch and the socket table (2026-10-01)

Built to make the rich moveset affordable (docs/animation/review-plan.md): the machines do the first pass, Orb sees the exceptions.

**M. The silhouette lint** (`render/anim/tools/silhouette_lint.gd`, headless). Each pose is rebuilt by forward kinematics and its limbs rasterised as thick segments in the side view on a 160 x 140 unit grid (feet on the floor, centred on the pelvis); every pair is compared by overlap (intersection over union). Two poses that read alike are flagged: across families at 0.85, inside a family at 0.95 (a chamber that is the contact pose is a key that does nothing). Per pose it also gives area, width and height. `data/anim/lint_allow.json` lists the pairs that are meant to look alike (with the reason) and the overlay prefixes (`wound.`, `react.`: layered over another pose, never shown alone). On the 82 poses there are now: 0 pairs over the defaults, so the review wave uses a lower line (0.80 / 0.92) to show candidates.

**N. The stacking lint** (`stacking_lint.gd`, from Legal's seven marks in rule-of-cool.md section 1 rule 9). Mark 1 (a crouch with the fists at the sides) is read from the pose itself; the other six are about effects and voice, so each system that makes a moment declares its marks in `data/anim/moments.json` (8 moments now: the transformation's three beats, the power-up burst, the signature charge, the tier-3 world reaction, the winner's survey, the last stand). A moment with more than two marks is a FAIL, two is a warning (no room left). Today: 0 over, and the lint found a real one: `move.burst` had fists at its sides in a low lean, so its hands are open now.

**O. The exceptions collector** (`render/anim/tools/review.mjs`, Node, no dependencies). `wave` runs `pose_lint` (new: hand or foot targets the IK cannot reach, with the clamped position; elbows and knees out of human range; an arm straight back; a foot below the floor; pelvis height; NaN), the two lints, and (unless `--no-match`) `limb_scan`, `pop_scan` and `anim_check` (now with `--json=` / `--report=`, so the contact error, gap and solve cost come out as data). It merges them into `art/animation/review/<wave>/`: `exceptions.md` (errors the director fixes first, rows for Orb, logged notes; each with a suggested action), `summary.json`, `exceptions-sheet.png` (a contact sheet of the flagged poses) and the raw tool output. `reel` makes the wave's reel (a seeded match window, before the overhaul left, after right) and `ab` an A/B pair (the same window under two argument sets), both as GIFs; `fix-reach` rewrites unreachable targets to where the limb ends up. `window_scan.gd` finds the reel windows (launches, and the share of frames the camera holds both fighters).
*Proved on the 94 poses in the file:* first run 16 for review and 47 notes (the sheet is `review/poses-first-run/`); 28 unreachable targets moved to the limb's real end by `fix-reach` (strike poses left alone, the contact slice reads their reach; the silhouette of 15 poses changes by under 25 cells of a few thousand); second run 0 errors, 0 for review, 36 notes (`review/poses/`). The elbows and knees that author a fold past 150 degrees (the runtime limb pass trims them) are logged as notes. A whole wave pass is about 40 s for the poses and 2 minutes with the matches.

**P. The clavicle hunch and the socket table.**
- *Hunch* (`AnimPose.hunch`, `data/anim/effectors.json`): the shoulder is carried by turning the clavicle (forward and up, in model units), so a punch rolls the shoulder into the blow and a guard shrugs it. Automatic at bake for any hand target past the arm's reach (up to 2.5 forward, 2 up); authored per pose and side in effectors.json (brace, hurt.hold, win.stand, emote.victory so far); the contact solve adds up to 2.5 more (the hand's reach on the chest goes from 72 to 74 u). `--nohunch` turns all of it off for an A/B.
- *Sockets* (`data/anim/sockets.json`): the table the contact solve reads instead of constants. Regions (head, chest, gut and a new `legs`): the bone, an offset and the skin's distance. Limbs: hand and foot (two-bone IK as before) and three new aim-only ones: elbow, knee and head, where one bone is turned so a joint points at the target. Key sets name them as `limb: "elbow_r"`, `"knee_l"`, `"head"` and `target: "legs"`. `socket_check.gd` prints each blow's reach envelope (the farthest centre distance it lands at, within 1 unit):

| blow | head | chest | gut | legs |
| :--- | ---: | ---: | ---: | ---: |
| hand | 72 | 74 | 66 | none |
| foot | none | 60 | 64 | 60 |
| elbow | 46 | 50 | none | none |
| knee | none | none | 42 | 36 |
| head | 44 | 58 | 54 | none |

"None" is a height the part cannot reach from a neutral stance (a hand at the legs, a knee at the chest): the pose has to bring the part there (a crouch for a low hand, a rise for a high knee). The elbow, knee and head blows are close-range: the sim has to bring the fighters inside about 50 u for them, where the hand and the foot work at the contact slice's 58.
The checks: `anim_check` has a hunch test (the shoulder moves by what it is told on both sides; a reach hunch brings it 2.4 u forward; every limb and region a key set names is in the table). Contact error is still 0.0014 rad, 0 contacts beyond reach, and the gameplay hash is the same (`fa69ecb9c62ecfaf` at tick 600).

**The second showcase reel** (`art/animation/review/showcase2/showcase2-reel.gif`): 20 seconds of seed 12345 from tick 1845 with a launch at 2085, the camera holding both fighters for 84% of the window (`window_scan.gd`: of 4 seeds the two best windows were 83% and 84%); before the overhaul on the left, after on the right. 3.7 MB: a real wide window at game scale. `overhaul-P-clavicle-hunch-before-after.gif` shows the hunch off (left) and on (right).

### 9.13 Units Q to S: a first elbow, knee and headbutt, the hair question, per-shape idles and flinches (2026-10-01)

**Q. Elbow, knee and headbutt key sets** (`strike.elbow`, `strike.knee`, `strike.headbutt`: nine poses and three key sets, none in `picks`, so no live match plays them; `--keyset=strike.elbow` makes every blow of a lab run play one). `art/animation/overhaul-Q-elbow-knee-headbutt.gif` is the three in a real seed 4 window, side by side. What the test taught:
- *An aim-only limb is limited by height, not only distance.* The first elbow aimed at the head and the first headbutt at the head's centre were 0 and 5 of 29 contacts within reach: the shoulder (or the waist) cannot rise to a head at the same height whatever the lunge. The elbow now goes to the chest and the headbutt to a new `jaw` region (the head's centre 7 u lower), the head aiming from `spine_1` (the waist) instead of `spine_2`. Result at the live spacing: **29 of 29 elbows, knees and headbutts within reach on seed 4** (the elbow also 38 of 38 on seed 12345; the headbutt misses two guard-break blows the sim lands at 82 u), worst gap 0.00, contact error under 0.0025 rad, gameplay hash unchanged.
- *A key set may carry its own step-in limit* (`step_max`, model units; elbow 20, knee 18, headbutt 18) over the limb's default in `sockets.json`. At the sim's 58 u spacing those blows need the attacker to slide 18 to 20 u in about four ticks, which reads as a lunge; at their own envelope (46 to 56 u) they land with the hip lunge alone. This is the per-strike step-in distance Combat needs: it should author the spacing per strike (the socket table's envelope gives the numbers) rather than leave it all to the render.
- Reach envelope now (socket_check): elbow head 44, jaw 50, chest 50; knee gut 42, legs 36; head head 46, jaw 56, chest 66, gut 66, legs 56; hand 72 to 74 on head, jaw and chest, 68 gut; foot 60 chest, 64 gut, 60 legs.
- The forced-keyset runs fail one unrelated check in `anim_check` (the wound test compares chest motion and the headbutt changes it): that is a lab artefact, the unforced run passes.

**R. Hair and the tail.** `docs/animation/hair-and-tail.md`: the 19 attachment bones (R2: 46 bones), the follow-the-leader spring chains driven by the head and by the damage event, the ground clamp, a `tail` pose key, three units of work (1, 0.5, 0.5) and what is Rendering's and Art's. The decision Orb has to make is only whether the tail stays; the hair chains do not depend on it.

**S. Per-fighter idle and flinch** (`data/anim/shapes.json`, keyed by the shape key of a roster id: P circles, A the crouched wedge, E wedges and sweeps, C squares). Idle: multipliers on the stance's sway, rate, bounce, heel and breath, plus `sweep` (arms drifting out and in: the Empress 0.08 rad, the Protagonist 0.03) and `servo` (a quick head glance that holds and returns every 2.6 s: the Cyborg). The Protagonist is bouncy and open (sway 1.25, bounce 1.3), the Anti-hero still and rigid (0.55, 0.5), the Empress slow and wide (1.6 at 0.6 of the rate), the Cyborg nearly planted (0.3) with its glance. Flinch: multipliers on the hit-reaction kicks per body part, from one number each for the head, spine, arms and legs. The same blow gives head and arm flinch of **P 16.4 and 51.5, A 10.4 and 34.0, E 13.0 and 59.6, C 6.6 and 25.3** (rad/s): the heavy build takes it, the sweeping build throws its arms, the rigid build moves least in the spine. `anim_check` has a shape test. The two shapes in play today are KAI (P) and VORR (A); the reels (`overhaul-S-idle-four-shapes.gif`, `overhaul-S-flinch-four-shapes.gif`) force each shape on both fighters of a real window (`anim_reel --shape=E`) to compare. The idle in a match is mostly hover and step, so the differences are small by design; the flinch shows more.

---

## 10. How we will know it works

| Test | What it checks | Target |
| :--- | :--- | :--- |
| **A1 Silhouette** | Every pose passes the lint at 22, 38 and 52 px in three views, and mirrored | 100% |
| **A2 Contact accuracy** | Over 100 seeded matches, the striking effector is within 0.06 body height of the defender's socket at every contact tick (headless solve, no drawing) | 99% |
| **A3 Foot plant** | Planted-foot drift while pinned, on slopes to 45 degrees and across the seam | at most 0.02 body height |
| **A4 Hash** | The gameplay hash with animation on, off and stubbed, seeds 12345 and 4 and more | identical, and the negative control fails |
| **A5 Budget** | Frame cost on the integrated-GPU web build, two full-rate fighters | inside §7.1, or the ladder engages |
| **A6 Rendition census** | Distinct contact renditions per fighter over 1,000 seeded matches (distinct means at least 12 degrees mean joint angle or 8% silhouette area) | at least 500 for the first fighter |
| **A7 Timing fidelity** | The contact key on the contact tick; nothing past the end tick; anticipation at or above the floor | 100% by static check |
| **A8 No pops** | Maximum joint angular velocity across part joins, and the visual root offset back to zero at each end tick | under the threshold set at A1 |
| **A9 Modifier bounds** | Silhouette, limits and self-intersection with every modifier at maximum and with the worst-case stack | 100% |

QA owns the harness; the targets are mine to propose. A1, A7 and A9 are static and can run in CI without an engine, through the pose sheet's lint.

---

## 11. Risks

| Risk | Why | Mitigation |
| :--- | :--- | :--- |
| **Procedural motion looks floaty or robotic** | The in-between is the part nobody authors | Sell the pose: strong holds, snaps, smear, impact frames, moving holds. Orb reviews in motion at A1, before the library is written |
| **The old-laptop browser budget** | GDScript is slow; the frame is already tight; my estimate is at the limit (§7.1) | Spike first; the degrade ladder; own IK and springs kept small; a C++ extension as the named fallback |
| **Authoring capacity** | 425 hours across the roster at hobby pace | Derived chambers, profiles over deltas, a text path a Claude session can drive, and a Blender path for contributors; the showcase set is the lever |
| **Authorship and copyright** | Purely AI-made poses may not be protected (ADR 0007) | Orb accepted it; protection rests on the title mark, Orb's direction and selection, and the game as a whole. Provenance records and the originality screens stay |
| **Skinning and draw calls on Compatibility** | Unverified on the web and the iGPU | The §2.3 spike; rigid-skinned single mesh as the plan |
| **Modifier stacks make ugly poses** | Injury, mood and form can combine | Clamps, the worst-case lint (A9), smoothing on ticks |
| **Cheat-out and mirroring** | Near-side strikes read; far-side and depth-axis ones may not | Pose review in three views (§3.6); the author picks the near limb for the key read |
| **Facade and building contacts at depth** | Buildings stand at depth rows; a launch through one is scripted | Animation supports surface normals in the x-y plane; the staging of a facade hit needs Camera and World (§12) |
| **A late Combat contract** | `moveset-system.md` is not written; every timing is provisional | Design against `procedural-moves.md`; keep field names in one place; re-check when it lands |

---

## 12. Needs from others (through the EP)

| # | Need | From |
| :--- | :--- | :--- |
| 1 | The composer's part record: is `anim.keySet` (renamed from `anim.clip`) and `anim.contactKey` acceptable; the readability minimum by weight; how a cancelled part is signalled; a part cue with its anchor ticks (§8.2) | Combat, Simulation |
| 2 | **Ruled by the EP (2026-09-30):** this plan supersedes the wave-1 documents. `clip-list.md` and `warping-rules.md` are written (2026-09-30), after Combat's `moveset-system.md` (landed, 24af9c1) | EP |
| 3 | **Ruled:** I own `data/anim/` and `art/animation/`. Tools writes the schemas, and the sim's data hash skips `data/anim/` | EP, Tools |
| 4 | **Ruled:** the runtime lives in `render/anim/`. I own it; Rendering reviews | EP, Rendering |
| 5 | **A0 spike done** (`render/anim/spike/`, numbers in §7.8): skinning cost and draw calls on the web and the iGPU; the draw-call budget; hands settled as palm plus finger slab; rigid-skinned single mesh confirmed. Art and Rendering still confirm the hand mesh | Rendering, Art, Performance |
| 6 | Confirm the renderer's read list includes wear and stage, meters, form and pride state (§5.1) | Simulation |
| 7 | **Answered** (ADR 0007): no named human is required; provenance records and originality screens stay (§6.6). Still open: the Blender add-on's licence check if it is built | Legal |
| 8 | The staging of a facade hit at depth (a launch into a building at row 1 to 3) | Camera, World |
| 9 | A per-fighter animation style guide, once the roster's looks lock | Narrative, Art |
| 10 | The animation stream ids (`anim`, `anim.<slot>`) in `fx-events.md`'s table | Simulation |

## 13. Open questions

| Question | Owner |
| :--- | :--- |
| How staccato do you want it? Held poses and hard snaps, or more fluid? It is one number in the fighter's profile. I would show two motion reels at A1 and let Orb pick. | Orb |
| How does Orb want to review showcase-grade poses: contact sheets in batches of 12, motion reels per part, or both? (§6.4 assumes about 2 minutes a pose) | Orb |
| Are hands a palm plus a finger slab, and is the body rigid-skinned faceted parts? Both are cheap and look right for the style, and both are Art's to confirm. | Art |
| Is the animation layer's proposed budget acceptable, and which governor sets the degrade level? | Performance |
| What does the Combat contract look like when `moveset-system.md` lands: part fields, cancels, the part cue? | Combat |
