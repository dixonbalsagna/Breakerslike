# Blank, five ways

Owner: Art Director. 2026-09-29. Round 3 of the character look. Orb picked Blank as the closest direction, dropped Poster (the colour scheme was too jarring), asked for a unique style, and asked for the face question to be pitched. Five variations of Blank, not new directions. Concept art for Orb to choose from. Working labels and placeholder looks. Results are **pending Legal review**.

**Sheets** (`art/concepts/blank/`): `blank-comparison.svg` first, then one sheet per variation: `blank-1-seam.svg`, `blank-2-porcelain.svg`, `blank-3-marked.svg`, `blank-4-inked.svg`, `blank-5-aura.svg`. Each sheet shows the four fighters together at showcase size, 40 px and 12 px reads in colour and flat black with a civilian, a five-panel expression strip for each fighter (neutral, taunt, hurt, rage, triumph, with a head close-up inset), and a mock-up of the fighters in the greybox scene. `node art/concepts/blank/gen.mjs` regenerates all six.

## Two changes since round 2

1. **Three-quarter staging.** Orb's staging rule (`docs/ep/vision.md`, "Staging the fighters"): fighters are not in strict profile. They cheat out toward the camera by about 25 to 40 degrees, mirrored when they swap sides so the front always faces the camera. Every figure on these sheets is drawn at 32 degrees. The figure kit gained a yaw: the torso widens, the near arm and leg slide toward the camera side and the far ones away, forward extents shorten, and the mask face moves toward the middle of the head. It is a 2D approximation of the real model, but it shows what the front and the chest now have to do. Front features (the Protagonist's V-neck, the Cyborg's chest rail, hatches and chip) are drawn on the front surface, and the mask is the main face read.
2. **Calmer colour.** The accents are muted and related: teal `#4fb9a8`, violet `#9a80d8`, moss `#b8c96a`, brick `#d8705f`. Backdrops are the soft neutral of the sheets and the real greybox scene. Nothing jarring, and the value rule still holds (dark bodies, light gear).

## The fighters

The same four fighters as `directions.md`: Protagonist (teal, circles), Anti-hero (the Coil, violet), Empress (bladed cape-train, guard of honour), Cyborg (square, chain-mail, chest rail with hatches). Each mask has a designed shape: a smooth dome, a swept wedge, a tall crowned oval, a box with one visor slot. No mask is grey and round, and none has drawn eyes.

## The five variations

Each answers the face question: how emotion, one-liners, hurt and transformation read.

| | 1. Seam | 2. Porcelain | 3. Marked | 4. Inked Blank | 5. Aura |
|---|---|---|---|---|---|
| The idea | A dark matte mask with one glowing seam in the fighter's lane colour | A glazed porcelain mask that acts through shadow, as a carved theatre mask does | A bold sigil on a pale mask, one per fighter (ring, slash, chevrons, grid) | A blank body drawn with a heavy brush line, a dry edge and an ink shadow, one brush stroke for a face | A plain blank mask; the aura around the head is the face |
| Emotion | The seam is the face: a flat line, a slant and a smirk arc, dim dashes, a hard slash with a jagged mouth, two joyful arcs | Shadow shapes: soft brow, heavy brow and cheek light, drooping brow and a tear crack, a hard V shadow, a lifted brow and bright cheek | The sigil bends: clean, tilted and slid, shrunk and cracked, swollen with spikes, brightened with rays | One brush stroke: level, raised with a flick, drooping with a drip, thick slash, arch | Aura shape: calm ring, lopsided curl, broken arcs, spiked flare, fan of rays |
| One-liners | The seam pulses on stressed syllables, and a mouth seam appears while speaking | The highlight sweeps and the mask tilts a few degrees on each beat | The sigil pulses with the line | The stroke twitches and a mouth stroke appears | The aura pulses on the beat of the line |
| Hurt | The seam breaks into dim dashes | Hairline cracks that stay and spread with wear | The sigil dims and cracks (the head wear readout) | The stroke droops and a drip falls | The ring breaks into arcs |
| Transformation | The seam thickens and splits per form | The glaze cracks and lane light shows through | The sigil grows and body bands spread per form | The line and ink shadow thicken per form | The aura gains layers per form |
| Builds in Godot | Cheapest: an emissive seam strip driven by an expression uniform | A carved relief mask, a two-band cel, shadow-shape mesh, crack decals | A sigil decal with an expression uniform and body-band decals | Blank plus the Ink pipeline (noise-width hull, offset hull, noise edge): most fill | An aura quad behind the head, shared with the aura crown |
| Main risk | A glowing visor can read as a robot or another game's masked character; overlaps the Protagonist's heat seams | Subtle at 12 px and fragile-looking | Marks can read as symbols with unintended meaning; each needs a Legal check | The murkiest at small sizes and nearest to a generic heavy-outline look | Overlaps the aura crown wound readout, and fails when the aura is hidden |

## What the checks showed

Inspected in the rendered sheets and zoomed crops.
1. **The three-quarter view helps every variation.** With the torso and mask turned toward the camera, the mask face has room: the seam wraps the front of the mask, the sigil sits near the middle of the face and the shadows appear on both sides. The Cyborg's chest rail and open chip hatch now read on the front, and the Protagonist's V-neck and belt read as a chest design.
2. **Expression at 12 to 40 px:** only the pale masks with a strong shape carry it (Marked, Porcelain), and only as a small mark. At 40 px the Seam's bright line reads best, but a dark mask disappears at 12 px. The head close-up insets show what the real close-up cameras and cinematics will read.
3. **Pale masks are a head beacon at 40 px, and only a hint at 12 px.** In the 40 px chips the pale masks (Porcelain, Marked, Inked) leave a clear light spot on a dark body for the Protagonist, Anti-hero and Cyborg. At 12 px the mask is one or two pixels and does not carry on its own. Seam masks are dark, so their heads vanish at 40 px unless the seam glows. The far beacon (a halo in the lane colour) is still needed at 12 px for every variation.
4. **Inked Blank is the murkiest.** At 92 px and below the heavy line swallows the brush-stroke face, so the expression is lost. It is also the highest-fill option.
5. **Aura is the most variable.** The aura reads clearly at large sizes and disappears at 12 px, and it collides with the aura crown.

## Legal guardrail

Nothing is borrowed from the feel reference's look or from any franchise. The masks are designed, coloured shapes (never grey and round), with no cross-mark or dot eyes and no shared line style. The Protagonist's mask is a smooth dome with hair, which is the closest to a plain blank head, so Legal should look at it first. Inked Blank carries Ink's line-style risk, so it needs the most care. The Marked sigils need a check against real symbols.

## Comparison

| | Seam | Porcelain | Marked | Inked Blank | Aura |
|---|---|---|---|---|---|
| Unique | Medium (a glowing slit is common) | High | High | Medium | Medium to high |
| Emotion at 40 px | Good | Fair | Fair to good | Poor | Fair |
| Head read at 40 px | Weak (dark mask) | Good (pale) | Good (pale) | Fair | Weak |
| Form-by-form identity | Fair | Fair | Best (the sigil and bands grow) | Fair | Good |
| Godot cost | Lowest | Low | Low | Highest | Low |
| Animation load | Lowest | Low | Low | Low | Lowest |
| Legal risk | Medium (visor look) | Low | Medium (symbols) | Highest | Low |
| Works in cinematics | Yes | Best (close-ups) | Yes | Yes | Yes |

## Recommendation: Marked, with a glowing sigil at rage and transformation. Orb decides.

Why:
1. It is the most identity-rich: each fighter is recognisable by shape, colour and a mark of their own, and the mark grows with form. Nothing else does that.
2. The pale mask is a head beacon at 40 px (a hint at 12 px, where the far beacon still has to do the work), which helps the gameplay-size read.
3. Expression is a small, cheap animation of the sigil (tilt, shrink and crack, swell and spike, ray), plus head tilt and posture. It reads in the close-up and in the three-quarter view, and it costs one decal.
4. It borrows the Seam's glow where it is needed most: the sigil lights up in the lane colour on rage and at each transformation, and the glow spreads across the body bands.

What could go wrong: each sigil needs a Legal check, and a pale mask reads as a beacon but also as a mannequin if the sigil is too small. The fallback is Seam, which is the cheapest and reads best at 40 px.

## Questions for Orb (through the EP, two at most)

1. **Which of the five is closest,** or which pairing (for example Marked with a glowing sigil, or Porcelain with a lit seam)?
2. **Pale or dark masks?** Pale masks make each head a small beacon at 40 px and read on the sea and sky. Dark masks with a glow feel more menacing but vanish at distance.

## Files

`art/concepts/blank/`: `blank-comparison.svg`, `blank-1-seam.svg`, `blank-2-porcelain.svg`, `blank-3-marked.svg`, `blank-4-inked.svg`, `blank-5-aura.svg`, `gen.mjs`, `README.md`. The figure kit (`art/concepts/anti-hero/kit.mjs`) gained a three-quarter yaw and expression-aware blank heads. `art/concepts/directions/fighters.mjs` now draws front features on the front surface. The mock-up embeds `docs/rendering/img/civilians-after.png` by reference. The prompt record is `art/prompts/ART-0004-blank-variations.md`.
