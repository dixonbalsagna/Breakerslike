# Variety pass: how the priority-1 cues read on screen

Rendering's plan for Combat's variety pass (`docs/combat/variety-pass.md` section 4, `data/combat/styles.json`). Status: plan only (2026-09-30). There is no code until the sim emits these events (Encounter's Q4).

## Rules

- **Render only.** Everything here consumes fx and `cue` events and reads `S.game.clash`. It never writes the sim. `cue_check` already proves the gameplay hash is the same with the poses on and off; it will fire every new cue and prove that again. A new `clash_sheet` tool will draw each beam shape at its keyframes.
- **Reuse, don't add.** Poses are rows in `RenderLook.CUE_POSES`, blended by the fighter rig as today. Bursts are instances in the particle MultiMesh, which already has camera-facing `ring`, flat `ripple` and `shock` shapes, and an `after` afterimage shape. Head-flash glyphs are rows in Art's `data/art/flashes.json`. Beam shapes reuse `BeamView`'s three-cylinder segment and its flare quad. There are no new shaders and no new node kinds.
- **Seam-safe.** A clash polyline is laid out from its tail's camera-relative x, as beams are today.

## What each cue needs from the sim

| Cue | Event and fields |
| :--- | :--- |
| `tell_light`, `tell_heavy` | the existing `attack` event: attacker, kind |
| `finisher_tell_launch`, `_melee`, `_beam` | `finisher_start.kind`, the finisher and the target |
| `struggle_hold`, `struggle_slip` | a `cue` per pulse: the actor, and the pulse index (1 to 3) |
| `blink_out`, `blink_in` | fighter, x, y at departure or arrival, in the tick the position jumps |
| `blink_meet` | both fighters, and the contact point (x, y) |
| `chain_ender` | attacker, contact point, chain count N |
| the clash shapes | `game.clash.shape`, plus its keyframes: the reversal times (seesaw), the deflect time and direction, the split time and angle, the detonation time (mutual) |

## How each reads

| Cue | On screen | Reuses |
| :--- | :--- | :--- |
| `tell_light` | A quick, compact start: a short forward lean, fists tucked, a small spark at the lead hand. It reads as fast rather than big. | pose row, particle spark |
| `tell_heavy` | A wind-up: the rear fist drawn far back, a crouch, the chest flare, and a slow tremble in the lead arm. VFX's trail runs thicker through the approach. The contrast with the light tell is size and time: 0.5 s against 0.25 s. | pose row (`flare`, `tremble`); a trail-strength hook for VFX |
| `finisher_tell_launch` | A low scooping crouch, both hands low, and an up-chevron info flash over the head | pose row; a new flash glyph (Art) |
| `finisher_tell_melee` | Fists up, guard glow, and a spark on both fists; the info flash is a fist-burst glyph | pose row; flash glyph (Art) |
| `finisher_tell_beam` | Palms together forward, the existing charge orb between them, and a ring-glyph info flash | pose row, charge orb; flash glyph (Art) |
| `struggle_hold` | Per pulse: a braced push (crouch, arms locked), a flare pulse, and a camera-facing ring out from the chest. Three pulses read as holding on. | `holds_on` variant row, `ring` particle |
| `struggle_slip` | Per pulse: a step back and a head drop, the flare fading, and dust at the feet. It reads as losing ground. | `breaks_hold`/`recoil` variant row, `dust` particles |
| `blink_out` | The body vanishes; an `after` silhouette in the fighter's aura colour stays for 0.2 s, and a `ring` ripple expands from the chest. | particles only; the fighter view hides for the gap |
| `blink_in` | A `ring` ripple at the arrival point, then the body scales in from 0.8 over 0.08 s. Render interpolation snaps that fighter for the tick, so it never slides across the screen. | particle `ring`; one flag in SimHost's interpolation |
| `blink_meet` | Both fighters snap to a meet pose: fist out against a raised forearm. A white star at the contact (the flare quad, 0.1 s) and a spark burst. | pose row, flare quad, sparks |
| `chain_ender` | A heavier impact: the flare quad at 1.6 times a hit's size, a `shock` ring, and twice the sparks. The CHAIN ×N banner is UI's (Narrative's label). | flare quad, particles |

### The beam-clash shapes

The meeting point `m` lies on the line between the two fighters at a fraction `p(t)` from the middle toward the loser. Today `p` is linear.

- **Overpower** (today): `p` is linear over the clash.
- **Breakthrough**: `p` eases in over the sim's 0.8 s (slow, then a rush). The loser's beam thins to half its width and whitens as it fails, and the flare bursts at the loser.
- **Seesaw**: `p` passes smoothly through the sim's reversal times: toward the loser, back past the middle, then through. The flare pulses at each reversal.
- **Deflect**: the push is normal up to the deflect time. Then the loser's beam bends at `m`: a second segment grows from `m` along the deflect direction (skyward, or into the settlement) and hands over, colour and width matched, to the beam the sim fires on that path. The winner's beam swings through the deflect angle.
- **Split**: at the split time both beams bend at `m` by plus and minus the split angle, and a second segment grows and hands over to the two veering beams the sim fires. Their trenches are the sim's scorch and craters, which are drawn already.
- **Mutual blast**: both beams retract into `m` over 0.2 s. The flare swells to three times its size, white-cored, over 0.15 s, capped at 60% of the screen height, then fades. The sim's own explosion, crater and shake do the rest.

## Cost, and old laptops

Measured today on desktop: about 154 draw calls with one view (232 at the split's 95th percentile), and 3.4 ms mean on the web. An old laptop's CPU is projected at 2.6 to 3.9 times slower (`docs/architecture/determinism.md`). Minimum-spec hardware has not been measured.

| Part | Draw calls | CPU per frame (desktop, then old laptop) | GPU |
| :--- | ---: | :--- | :--- |
| Tells, struggle, blink-meet poses | +0 (rows in the existing rig) | under 5 µs, then under 20 µs | none |
| Finisher-kind flashes | +0 (the flash MultiMesh) | under 5 µs | one quad each |
| Blink ripples and afterimages, sparks, rings, the chain-ender burst | +0 (the particle MultiMesh; at most about 30 more instances against its cap of 1,200) | under 10 µs, then under 40 µs | small additive quads |
| Deflect and split segments | +3 per bent beam, +6 at most, during a clash only | under 5 µs | thin additive cylinders |
| Mutual-blast flare | +0 (the existing flare) | none | one additive quad up to 60% of the screen for 0.15 s. That is the one fill spike an integrated GPU would notice, hence the cap. |

**Total:** at most +6 draw calls, only during a split or deflect clash, and under 0.05 ms of CPU a frame on desktop (under 0.2 ms projected on an old laptop). Every cue is also safe at low quality: the particles honour VFX's quality level and reduced motion (ripples and the flare swell are halved under reduced motion).

## Order and checks

1. When Encounter's events land: the tells, the struggle pulses and `chain_ender` (poses and particles only).
2. Blink (the interpolation snap, then the particles), with Camera and VFX's hooks below.
3. The beam shapes, one at a time, in the priority order above. `clash_sheet` draws each shape at its keyframes, and `seam_sweep` covers a clash across the seam.
4. Each step: `cue_check` (the hash with and without, every new cue fired), `determinism`, `pane_check`, and the desktop and web bench against these numbers.

## Needs from others (through the EP)

- **Encounter:** the fields in the table above, above all the blink position in the same tick the fighter moves, and `game.clash`'s keyframes.
- **VFX:** break a fighter's motion trail at a blink, so no streak draws across the teleport, and take a trail-strength factor for the heavy tell.
- **Art:** three info-flash glyphs for the finisher kinds (launch, melee, beam) in `flashes.json`.
- **Camera:** how the view follows a blink (a cut or a quick ease), and whether a blink clash may open the split.
- **UI:** the CHAIN ×N banner on `chain_ender`.
- **Audio:** separate from this plan.
