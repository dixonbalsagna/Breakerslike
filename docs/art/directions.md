# Character art directions

Owner: Art Director. 2026-09-29. Four proposals for the overall character look, each drawn with all four fighters. Concept art for Orb to choose from, not a locked design. Working labels and placeholder looks. Results are **pending Legal review**. Orb's reaction to round 2 was that the Coil is a good start, that the designs need to be more striking and recognizable, and that blank heads are an allowed style choice.

**Sheets** (`art/concepts/directions/`): `directions-comparison.svg` first, then one sheet per direction: `dir-1-blank.svg`, `dir-2-ink.svg`, `dir-3-toy.svg`, `dir-4-poster.svg`. Each direction sheet shows, for the four fighters, a showcase figure in colour, its silhouette, a civilian of the same height, 40 px and 12 px versions in colour and in flat black over sky and sea, and a strip of three postures (proud, hurt, enraged) that tests direction and emotion. `node art/concepts/directions/gen.mjs` regenerates all five.

## The four fighters, shared by every direction

The bodies are the same in all four directions. Only the rendering style changes, so the comparison is about style and not about design.

| Fighter | Lane | Shape language | Signature feature | Built from |
|---|---|---|---|---|
| Protagonist | Teal (the teal hair is QA's placeholder) | Circles | Round wrapped fists, a big round belt knot, a swept-back rounded hair mass, an open forward-leaning stance | New |
| Anti-hero | Violet | A crouched wedge | The Coil: low crouch, a spine of armour plates, a short tied hair tail | Round 2, F |
| Empress | Chartreuse | A triangle | The bladed mantle worn as a cape-train: a stiff crescent behind the head, a long train, a hem of blades. A guard of honour beside her (plumed helm, spear) | New |
| Cyborg | Dark red | Squares | A square body and backpack unit, dark red plating and chain-mail, a rail down the chest with four hatches (head, chest, back, hip) and the chip showing in the open chest hatch, looping cables | New |

All four follow the value rule (dark bodies, light gear), the two-tone edge and the far beacon from the style guide. The Anti-hero keeps every Legal condition (no shoulder pads with white gloves and boots, no flame or upswept hair, no hair-colour change, no gold or red glow, no cape). The Empress has no horns, is not pale and has no purple. The Cyborg has no horn-and-antenna silhouette and no sphere core: the chip sits in a hatch.

## The four directions

### 1. Blank: faceless masks

Heads are blank masks, each a designed shape and never grey or round: a smooth dome (Protagonist), a wedge with a swept forward chin (Anti-hero), a tall oval with a crown band (Empress), a square box with one visor slot (Cyborg). Identity comes from head shape, silhouette, colour and one signature feature.

| | |
|---|---|
| Striking | Four shapes, four colours, no faces. Nothing else looks like it, and it reads at any speed |
| Recognizable | At 12 px the head shape and the posture carry it: a dome, a wedge, a tall oval, a box. The Empress's mantle and the Cyborg's block read at once. Direction reads from the forward chin and the visor slot. Emotion reads from head tilt and spine (the posture strip shows proud, hurt and enraged) |
| Godot | Lowest cost. A mask mesh per fighter, the standard three-band cel, inverted-hull outline and palette masks. No face rig, no eye or mouth animation, no lip sync |
| Risks | Blank faces can read as lifeless, or as other faceless-figure work. Emotion depends on authored head tilt. One-liners lose the face beat, so voice and grunts carry more |

### 2. Ink: heavy brush line

A thick, tapered brush outline that swells on impact, a dry broken edge from noise displacement, an offset ink shadow, and hatched shadow shapes at showcase size. Fills stay in the fighter's palette.

| | |
|---|---|
| Striking | A hand-painted look the genre does not have. It looks made by a person |
| Recognizable | Line weight and edge roughness are the signature, and the shape lanes still work under it. At 12 px the ink shadow gives a strong dark mass. The heavy line eats faces at showcase size, which is the honest cost |
| Godot | Inverted hull with per-vertex width from a noise map (brush taper), an offset dark hull for the ink shadow, and a noise-cut alpha edge for the dry brush. One 128 x 128 noise map. Two extra passes per fighter, so the most fill of the four |
| Risks | Nearest to a generic heavy-black-outline cartoon, so it needs the most care and Legal should screen it hardest: tinted inks per fighter, tapered variable strokes and coloured fills, never a uniform black outline on flat figures. Line work competes with destruction effects |

### 3. Toy: sculpted and chunky

Vinyl-toy proportions: heads 1.5 times larger, thick limbs, short legs, rounded solids, ball joints at shoulders, elbows and knees, and a hard glossy highlight. Faces stay.

| | |
|---|---|
| Striking | The most lovable and the easiest to merchandise. It pairs violence with charm, which suits the funny and sincere tone |
| Recognizable | Proportion is the identity, and it gives the strongest colour and mass at 12 px (the teal helmet and the red and white Cyborg show up as spots). Faces stay, so emotion is direct |
| Godot | Rounded meshes with smooth normals (about 30% more triangles), a two-band cel with a soft terminator, a hard specular band, and ball-joint meshes. The rig shows its joints |
| Risks | It can undercut a mature, graphic tone: wounds on toys read as either comic or disturbing. Big heads squeeze regalia and armour. Avoid the look of any specific toy brand |

### 4. Poster: stark two-tone print

Ink, cream and one spot colour per fighter (teal, violet, chartreuse, red). Bodies are ink, gear and skin are cream, accents are the spot colour, edges are a cream line, and showcase backgrounds are the spot colour.

| | |
|---|---|
| Striking | The boldest. It looks like a screen print or a stencil, and it makes destruction and effects pop |
| Recognizable | The spot colour makes each fighter unmistakable, and the ink and cream split works over sea, sky and night. At 12 px the cream reads as light flecks on the sea |
| Godot | A palette-lookup shader: ink, paper and spot. Hard shadow threshold, a white-line outline pass, no ramp. The cheapest fill of the four. The world must be limited to a few colours too, or figures will not sit in it |
| Risks | It commits the whole game, world and effects to a restricted palette, which is a large decision. Wounds and blood lose their colour language. Procedural planets need a two-tone version |

## How each direction stays clear of borrowed looks

Nothing is borrowed from the feel reference's look or from any franchise. Specifically:
- **Blank** has designed, shaped, coloured heads. There are no grey round heads, no cross-marked or dot eyes, and no features drawn on the mask.
- **Ink** is the closest to any heavy-outline look. It is tinted (no pure black), tapered, rough-edged and drawn over coloured, shaded, fully anatomical figures. It still needs Legal's eye.
- **Toy** and **Poster** use styles from print and toy design, not from any character.

## Findings from the 12 px and pose checks

Inspected in zoomed crops of the sheets.
1. **The Empress reads at 12 px in every direction.** The mantle wedge is the strongest single shape in the set.
2. **The Cyborg reads as a square block with a red fleck in every direction,** and the Anti-hero's crouch separates it from the upright civilian.
3. **Colour identity at 12 px is weakest in Blank and Ink** because their bodies are dark on a mid-blue sea. The teal and violet spots are about one pixel. Toy and Poster carry colour better (bigger heads, cream gear). In Blank and Ink the far beacon (a halo in the fighter's accent colour, style guide section 4) must carry the lane colour.
4. **Posture and head tilt read direction and emotion in every direction,** including with no face. The Protagonist's open stance reads as facing right, the Coil's crouch reads as a coil, and the enraged and hurt states differ clearly from the proud state in the blank heads.

## Comparison

| | 1. Blank | 2. Ink | 3. Toy | 4. Poster |
|---|---|---|---|---|
| Striking | High | High, but faces are lost | High, charming | Highest |
| Recognizable at 12 px | Good (shape), weak colour | Good (mass), weak colour | Best (mass and colour) | Good (value), spot colour visible |
| Godot cost | Lowest | Highest fill (three passes) | Medium (about 30% more triangles) | Low (palette shader) |
| Animation load | Lowest (no face rig) | Same as Blank plus face | Medium (visible joints, faces) | Same as Blank plus face |
| World fit | Works with the biome palettes as written | Works, but line work competes with effects | Works, softer world | Needs a two-tone world and effects |
| Fits the mature, graphic tone | Yes | Yes | Weakest | Yes |
| Legal risk | Low if heads stay designed | Highest (line style) | Low | Low |
| Reversible | Yes: masks can gain faces later | Partly | Partly | No: the whole palette is committed |

## Recommendation: Direction 1, Blank. Orb decides.

Why:
1. It is Orb's own idea, and the designed heads mean no fighter needs a face to be recognized. Shape lanes (circle, wedge, triangle, square) do the work.
2. It is the cheapest to build and animate (no face rig) and it keeps every readability rule and the biome palettes as written.
3. It is the most reversible: a mask can be given a face later, or the style can be pushed toward Poster.
4. Its weak spot, colour identity at 12 px, is already covered by the far beacon in the fighter's spot colour.

The most striking option is **Poster**. I suggest using it for key art, the fighter select screen and marketing while Blank runs in the game, so Orb gets the boldest look where it sells the game, without committing the world to two tones. If Orb wants the game itself to look like Poster, that is a decision about the biomes, effects and blood, and it should be made deliberately.

## Questions for Orb (through the EP, three at most)

1. **Which of the four feels like your game** when you look at the four fighters together?
2. **Faceless or not?** Blank heads (Direction 1) cost the least and remove the face beat from fights. Would you accept fighters who never show a face, even in cinematics?
3. **Should the boldest look (Poster) be the whole game or only the key art?**

## Files

`art/concepts/directions/`: `directions-comparison.svg`, `dir-1-blank.svg`, `dir-2-ink.svg`, `dir-3-toy.svg`, `dir-4-poster.svg`, `gen.mjs`, `fighters.mjs`. `art/concepts/anti-hero/kit.mjs` gained style hooks (a sculpted mode, faceless heads with designed shapes, hatched shadow fill). The prompt record is `art/prompts/ART-0003-character-directions.md`.
