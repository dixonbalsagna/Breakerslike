# Style guide v1: faceted cel, Marked plus flashes

Owner: Art Director. Version 1, 2026-09-29 (v0 the same day; v1 adds the character style Orb picked, Marked plus flashes: masks, sigils and head flashes in place of a standing aura, with Legal's conditions applied). Draft for the EP and Orb. Nothing here is implemented, and nothing is locked. Every hex value is a proposal that Rendering, VFX, UI and Accessibility can push back on through the EP.

**Sources.** `docs/ep/vision.md` (Orb's answers), `docs/world/scale.md` (life-size scale), `docs/design/spec-wounds.md` (regions, stages, the Proud front), `docs/legal/originality-rules.md`, `fighter-concepts-review.md` and `q3-screen.md` (design conditions), `docs/rendering/README.md` (what the greybox draws today), `docs/narrative/glossary.md` (tier and stance names).

**Decided by Orb:** 2.5D side-on, cel-shaded plus low-poly (Art pitches), procedural assets, AI-generated assets allowed, tone mature, graphic, funny and sincere, feel of brutal, readable, choreographed flash-animation fights, life-size world, hobby-pace budget of zero, old laptops as the minimum hardware.
**Proposed here:** everything else.

## Status by section

| # | Section | Status |
|---|---|---|
| 1 | The look in one page | draft |
| 2 | Scale and readability at gameplay zoom | draft, measured on the Anti-hero concepts |
| 3 | Silhouette, value and palette rules (3.6 masks, sigils and expression is new in v1) | draft |
| 4 | Line and outline | draft |
| 5 | Cel shading: what Rendering needs | draft, open to Rendering |
| 6 | Bodies: wear and damage | draft, follows `spec-wounds.md` |
| 7 | Head flashes, tiers and effect colours (was Aura, tiers and effect colours) | v1 draft, VFX owns the effects, Rendering owns the flash prototype |
| 8 | The world: biome palettes and damage states | draft |
| 9 | Budgets | open, Performance owns the numbers |
| 10 | How to verify | draft |

## 1. The look in one page

**The pitch: faceted cel.** Real 3D geometry seen by a side-on perspective camera, as in the greybox. Every form is a low-poly solid with hard planes. Shading is three flat bands from one fixed key light, with a confident dark outline. Nothing is textured except by shader: colour comes from a per-object palette, and wear, cracks and grime come from procedural masks.

**What that buys us**
- **Reads fast.** Three bands and a line survive small sizes and motion blur. The eye sees shape first, which is the whole point of the fighter identity work.
- **Cheap.** One material per fighter and per building family, no lighting passes, no post effects required. That fits an old laptop, the browser build and a phone, and matches the greybox (unshaded, one fixed fake light).
- **Procedural friendly.** Meshes come from generators and palettes are data, so one mesh serves any palette. Mirror matches, procedural planets and mods are palette swaps.
- **Honest to the feel Orb described.** Choreographed flash-animation fights are held key poses, hard cuts, smear frames and impact frames. Flat shapes and hard edges carry those better than soft realism.

**Presentation levers that are presentation only** (they never touch the sim; VFX, Animation and Camera own the work)
- Smear: stretch a fighter's mesh along its velocity for one or two frames on a hard hit or a dash.
- Impact frame: one frame of flat, inverted contrast on a decisive exchange.
- Held hit: a short freeze on the frame of contact (the sim's hit-stop time stays in the sim; the render only holds the pose).
- Line weight swells on impact (section 4).

**The character style: Marked plus flashes** (Orb's pick, round 4; `docs/art/marked-aura.md`). Fighters have designed masks and no drawn faces. Each has a **sigil** on the mask that says who they are and shows a small flick of how they feel, and a **head flash**: a brief, iconic pop at the head (a "!", a "?", a spike of anger) that says what they sense or feel for under a second and then is gone. At rest there is nothing around a fighter, no standing aura. Only a transformation surge lasts, for the length of its cinematic. Colour is calm and harmonious, and shape lanes and hue lanes keep the four fighters apart.

**What we do not do:** photoreal materials, textures beyond one shared ramp and one noise map, soft shadows, real-time global illumination, dependence on bloom or HDR, soft additive particles as the main effect look. Effects are hard-edged cut-out shapes with two or three value steps.

## 2. Scale and readability at gameplay zoom

A fighter is one body height (1 bh, 75 units in the sim). The reference camera's zoom runs from 0.06 to 1.15 pixels per unit (`sim/core/view/camera.gd`) and Camera may raise the floor. Real fights sit at 0.3 to 0.7.

| Zoom | Fighter height | Band | What it is |
|---:|---:|---|---|
| 0.06 | 4.5 px | Far | The widest a fight can be framed |
| 0.10 | 7.5 px | Far | |
| 0.16 | 12 px | Far and Play meet | |
| 0.30 | 22 px | Play | Most real fights |
| 0.50 | 38 px | Play | |
| 0.70 | 52 px | Play | |
| 1.15 | 86 px | Close | The tightest gameplay zoom. Cinematics go closer |

**What each band must carry**

| Band | Height | The fighter must show | Everything else |
|---|---|---|---|
| Far | up to 12 px | A mass and a colour. Silhouette shape only if it is at least 20% of body height in its smaller dimension. A rim halo (section 4) so it never vanishes on a mid-value backdrop | Hidden |
| Play | 13 to 60 px | The shape feature, three colour masses, the outline, posture, the form (regalia count), the sigil and the head flash | Detail smaller than 4% of body height is a shader decal, not geometry |
| Close | over 60 px | Face and expression, regalia detail, wear decals, hair strands | Full detail. Budgets still apply |

**Rules that follow**
1. **One shape feature, one value feature, one colour feature per fighter.** The shape feature works at 12 px, the value feature at 5 px, the colour feature at 20 px. The Anti-hero test (`docs/art/anti-hero-concepts.md`) is the worked example.
2. **Fighters stand out from bystanders.** Civilians are one body height (`scale.md`), so a fighter at 5 to 20 px looks like a person. The silhouette lineup test includes a bystander (section 10).
3. **The value rule.** Fighter masses live at CIE lightness L* of 30 or less, or 80 or more. The world owns L* 35 to 75. Evidence: the sea surface is L* 53, and a mid-value accent (hot pink at L* 53) measured 1.01:1 against it, invisible in luminance. Most of a fight is over the sea (`qa/baseline-p0.md`: fighters spend about 65% of their time there), so this rule is not optional. An accent may sit at mid value only if it is under 10% of the figure and outlined.
4. **Detail thresholds.** A feature of 20% of body height or more can be a silhouette feature. 4% or more is geometry. Under 4% it is a shader decal or nothing.
5. **Facades have three looks** (life-size buildings, section 8): near (window and floor geometry), mid (a procedural window-band pattern) and far (flat value bands and a strong top silhouette).

## 3. Silhouette, value and palette rules

### 3.1 The tests every fighter design must pass

Run in this order. Each test is recorded with pass or fail, the shape feature that carries it (never colour), and Legal's answer to checklist item 4 (`originality-rules.md`).

1. **Silhouette lineup.** Flat black, true size, at 5, 12, 20 and 40 px, with a bystander and all other fighters. Each fighter must be told apart from the others and from the bystander at 40 and 20 px by a shape feature. At 12 and 5 px the test records what is left (usually a mass).
2. **Posture and form.** Proud, hurt and enraged postures, and the first and last forms, must differ in silhouette at 40 px.
3. **Three flat colours.** Snap every colour to the nearest of the three masses (body, gear, accent) and ask "what does this remind me of?" If a specific character comes up, redo it (checklist item 4).
4. **Greyscale value order.** The three masses are separable in greyscale, and the fighter is separable from every backdrop in section 8 by the two-tone edge in section 4.
5. **Colour-vision simulation.** Protanopia, deuteranopia and tritanopia (the Machado matrices used in the sheets' SVG filters). Meaning that depends on hue alone fails.
6. **Backdrop sheet.** Proud and enraged over each backdrop in section 8. The night and deep-sea cases use the rim outline.

### 3.2 Palette architecture

Each fighter has three masses and three shared extras.

| Slot | Share of the figure | Steps | Notes |
|---|---|---|---|
| Body base | about 60% | light, mid, shadow | Dark by the value rule |
| Gear | about 30% | light, mid, shadow | Regalia and metal. Light by the value rule |
| Accent | about 10% | light, mid, shadow | One pop. Never a mid-value block |
| Skin | | light, mid, shadow | Shared by all forms |
| Hair | | light, mid | Never changes. Never gold. Never a power cue |
| Line | | one | A tinted near-black, never pure black (`#000` is for the silhouette test only) |

**Ramp rule.** The shadow step is darker by about 20 L* and its hue turns about 12 degrees toward blue-violet. The light step is lighter by about 15 L* and its hue turns toward warm. Shadows are never plain darkened copies.

### 3.3 Lanes: shape, hue and value

So the four fighters are readable at any zoom, each gets a lane. These are proposals for Orb; the four turnarounds (`docs/art/*-turnaround.md`) draw them.

| Fighter | Shape language | Hue lane | Value | Reserved by |
|---|---|---|---|---|
| Protagonist | Round, open, forward-leaning (circles) | Teal `#4fb9a8` (the teal hair is QA's placeholder) | Dark body, light gear, pale mask | Heat seams: never red, never gold (`q3-screen.md`) |
| Anti-hero | Vertical, rigid (blades, a slash) | Violet, with an orchid accent `#9a80d8` | Dark body, light gear, dark mask | Regalia break: no gold, no red glow |
| Empress | Wide, sweeping, asymmetric (wedges, chevrons) | Olive with a moss accent `#b8c96a` | Dark body, light gear, pale bone mask | No pale-and-purple, no horns (revision 9 to 12 rule) |
| Cyborg | Heavy, blocky, hatches and rails (squares, steps) | Dark red, with a coral accent `#d8705f` and chain-mail texture | Dark body, light gear, dark mask | No horn-and-antenna silhouette; not black-and-red |

**Fire owns orange and yellow.** Fire, explosions, embers and hot ground use them (`HEAT_LO`, `HEAT_HI` in `render/core/look.gd`). No fighter uses orange, yellow or gold as a mass, an aura or a seam. That keeps destruction readable against a fighter's colours, and it keeps us clear of the genre's best-known hair and aura colours by construction.
**Blood owns red.** Wounds use one flat red (section 6). The Cyborg's dark red body is a different value (dark, desaturated) from blood (bright, saturated).
**Water owns mid blue.** Fighters do not use mid blue as a mass.

### 3.4 Do-not-draw list (design conditions from Legal, restated)

Every item is in `originality-rules.md`, `fighter-concepts-review.md` or `q3-screen.md`. Art applies them at concept time.

- Hair: no gold, no spiky upswept shape, no flame-shaped hair, no colour change on power-up. Tiers show through silhouette, markings, regalia and the light of the sigil, never a body aura or the hair.
- Uniform: no shoulder-pad armour with white gloves and boots. No orange-and-blue martial-arts outfit.
- Appendages and heads: no reptilian or furred tail, no pale horned emperor, no pale slender humanoid with a purple accent and horns.
- Glow: no red or gold aura, no red or red-orange seam on the Protagonist, no coloured multiplier aura, no glow that reads as an "x" number, no red, red-orange or gold head flash for the Protagonist or the Anti-hero.
- Masks and sigils (`q3-screen.md`, Marked plus Aura): a mask is a designed shape, never a plain egg or a grey faceless head, with no eye or mouth slots or dots and no goggles; the sigil is never an eye or a mouth. The ring is single (no concentric rings, no centre dot, never four linked, never with the slash, never centred on the forehead); the slash never crosses another stroke into an X, on the face or on the chest; chevrons are an odd count, of different sizes or offset, never a tidy double chevron and never in a car or oil brand's colours; the grid is lit steps, never a line grid, a cross or a 2 by 2 block; no rays around a sigil.
- Flashes: danger sense is directional (above or behind the head), never a ring of short lines around the head and never wavy; no yellow or red-orange "!" with a thick black outline; no tall pointed upswept shape (the Anti-hero's upward flashes are round-tipped, the Empress's are a wide, low crest); no alert sting and no chirp in the sound pairing.
- Poses: no cupped hands at the hip then thrust forward, no two fingers to the forehead, no arms raised for a giant orb. Fusion (if built): no synchronised or mirrored poses, no halo above the head, no accessory in the trigger.
- Orbs and fragments: irregular molten or crystalline pieces, never uniform smooth spheres, no stars or numerals, never laid out in a row, never a fixed set.
- UI: no scanner overlay, no numeric "power level".

### 3.5 Semantic colour roles

Colour is never the only carrier of meaning. Shape, pattern and position come first (Accessibility). Owners can override the hexes.

| Role | Where it comes from | Rule |
|---|---|---|
| Fighter identity | The lane table above | Body, gear and accent per fighter |
| Head flashes | Emotion: the fighter's accent, a rim and a lighter core, translucent. Info: a pale core inside a thin keyline in the lane's dark step (the Cyborg's are steel), solid | Never yellow or red-orange. Info against emotion is solid against soft |
| Barrage and beam | The fighter's accent, with a near-white core | The beam core is the brightest thing on screen |
| Danger and collateral | World: dust in the biome's ground colour, smoke grey `#5c5760`, fire `HEAT_LO` to `HEAT_HI` | Never a fighter colour |
| Wound stages | Pattern first: steady, flicker, gap. Tint second | Stage tints are neutral, not fighter colours |
| Blood | One flat red `#b3202f`, with a `#7d1420` shadow step | A decal, never a mesh. Off or neutral under the graphic dial (section 6) |
| Ego meters (proposal) | Each meter uses its owner's accent: Respect (Protagonist teal), Pride (Anti-hero violet), Wrath (Empress chartreuse), Hunger (Cyborg red) | So a meter says whose it is |
| UI accent | UI and UX decide. Keep it out of every fighter lane | |

### 3.6 Masks, sigils and expression (new in v1)

Sources: `docs/art/marked-aura.md`, `art/concepts/shared/marks.mjs`, `art/concepts/marked-aura/ma-1-style.svg` and `ma-5-legal-checks.svg`. Orb approved the tones.

| Fighter | Mask | Sigil | Where |
|---|---|---|---|
| Protagonist | Pale `#e8f1ee`, a designed faceted dome: brow ridge, jaw plane, crown seam, high hairline | One open arc (a "C"), teal, painted | Off-centre at the temple, above the brow ridge |
| Anti-hero | Dark `#2b2444`, a wedge | A leaning slash and a dot, orchid, emissive | Mid-face |
| Empress | Pale bone `#e6e0c4`, polished | Three chevrons of three sizes, offset, moss, painted | The brow, under the headband |
| Cyborg | Dark `#34313d`, a boxy display face | A diagonal stair of four lit squares, coral, emissive | Mid-face, plus a head hatch bar |

- **Expression comes from three places, not a drawn face.** The head tilt and posture (Animation), the sigil's small flick (rest, pride, taunt, hurt, brink, rage, triumph: a lean, a scale, a brightness, and in hurt and brink a gap in the sigil), and the head flash (section 7). Nothing is drawn as an eye, a brow or a mouth.
- **Dark masks carry an emissive sigil, pale masks a painted one.** The sigil is the alpha-emissive channel of the palette mask (section 5). It is the only part of a fighter that glows at rest, and only a little.
- **Readable at play sizes.** The mask tone is a value feature: at 40 px the pale masks are a small beacon over dark bodies, and the dark masks sit inside a dark silhouette and are told by the sigil. At 12 px only the mask tone and the shape survive. The checks sheet (`ma-5-legal-checks.svg`) runs each mask in three flat colours and as a silhouette.
- **At three-quarter the sigil sits on a narrow sliver of the mask** in the 2D concept sheets. On the real model it lies on the face plane and is foreshortened by the turn, so its width should be judged on the model.

## 4. Line and outline

**Method.** An inverted hull (a back-face shell pushed out along the normals in the vertex shader), as the greybox already does for civilians. An edge post effect is an optional upgrade on high-end hardware only.

**Width, in screen pixels**
- Fighters: `clamp(0.04 x fighter_px, 0, 3.0)`. 3 px at 75 px tall, 1.5 px at 38 px, none below 10 px.
- Props and buildings: 0.6 times the fighter width, fading out below a 6 px storey.
- Terrain: no outline. A darker edge band on the lit side of each crater rim and cliff.
- Effects: no outline. A hot core and a darker rim.
- Impact: the line swells by 50% for four frames on the fighter that was hit.

**Colour.** The fighter's line colour (a tinted near-black). Never pure black.

**Two-tone edge.** A fighter reads on both bright and dark backdrops because its edge has two tones: the dark outline outside, and a light rim on the lit side inside. The light rim colour is the gear light step.
**Rim rule.** Where the backdrop is darker than L* 35 (deep sea, night, inside a cave), the outline colour flips to the rim colour. The concept sheets show it. Rim colour for the Anti-hero: `#b9a9e6`.
**Far beacon.** Below 14 px, the outline is replaced by a 1 px halo in the fighter's accent light colour at 60% opacity, so a mid-value backdrop never swallows the figure. Tested: without it, a dark violet figure at 5 to 12 px vanishes on the sea.

## 5. Cel shading: what Rendering needs

Target renderer: Godot 4.7 Compatibility, as in the greybox. Nothing here needs HDR, bloom, SSAO or dynamic shadows. If Compatibility gains glow that works, it is a bonus and never a dependency.

| # | Feature | Spec | Priority |
|---|---|---|---|
| 1 | **Three-band ramp** | Bands by `N.L` against one key light: lit at 0.55 and above, mid from 0.18 to 0.55, shadow below 0.18. Band edges use a `smoothstep` about 0.02 wide, so they anti-alias. Per-material ramp colours come from uniforms (no ramp texture required; an optional 256 x 8 shared ramp texture is allowed). Metal (gear) adds one hard highlight band | Must |
| 2 | **One key light and one ambient** | A fixed direction from the upper front (as the greybox's fake light). Time of day moves the direction and tints the ramp. No point lights on fighters | Must |
| 3 | **Palette masking** | Vertex colour channels select palette slots: R is body, G is gear, B is accent, A is the emissive mask. One mesh takes any palette (mirror matches, modding, procedural planets). In Compatibility, instance colours are linear (`docs/rendering/README.md`), so use custom data where needed | Must |
| 4 | **Inverted-hull outline** | Section 4. Colour and width as uniforms. A second pass, one extra draw per fighter | Must |
| 5 | **Rim** | A one-step fresnel band on the lit side. The colour is the ramp's light step | Must |
| 6 | **Wear masks** | Five floats per fighter (head, core, arms, legs, crown), each 0 to 1. The fragment shader draws grime, scuffs, bruise tint, cracks and blood decals from a region id stored in vertex colour or UV, using one shared 128 x 128 noise map. The stage (fresh, bruised, battered, broken) also swaps geometry (section 6) | Must |
| 7 | **Regalia as separate meshes** | Each regalia piece is its own mesh with an intact and a broken variant, toggled by form and by wear. No skinning tricks | Must |
| 8 | **Emissive seams** | An emissive mask on cracks and veins in the fighter's own colour. Without bloom it reads as a bright flat band, which is right for the look | Should |
| 9 | **Hit flash** | A uniform blends the palette toward white for 0.12 s (the greybox does this) | Should |
| 10 | **Hidden fade** | Dither, not alpha blending: a screen-door fade, so the fighter keeps a hard cel look while hidden | Should |
| 11 | **Depth haze** | Aerial perspective by depth behind the fighter plane, in the biome's horizon colour. The fighter plane (about 60 units either side of z = 0) is exempt, as the greybox's bend weight already is | Must |
| 12 | **Contact shadow** | A hard-edged dark ellipse decal on the ground under a fighter, scaled by height, cut off when the ground is far. It is the altitude cue at long zoom | Should |
| 13 | **Smear** | A vertex stretch along velocity for one or two frames, driven by an event | Could |
| 14 | **Impact frame** | A one-frame flat high-contrast palette override on a decisive exchange | Could |
| 15 | **Time-of-day grade** | Ramp uniforms per time of day (section 8) applied to palettes, so a night pass needs no extra render pass | Should |

**Ramp values worked example** (Anti-hero concept C, body base): lit `#55427a`, mid `#33264f`, shadow `#1f1633`. Gear: lit `#efeaf6`, mid `#d3cde3`, shadow `#8d86a8`.

## 6. Bodies: wear and damage

Regions come from `spec-wounds.md`: head, core, arms and legs, plus UI's HUD wear crown. The Empress adds the mantle. Wear is 0 to 100 per region. Stages: fresh below 30, bruised 30 to 59, battered 60 to 89, broken 90 and above.

**Four layers, added stage by stage.** Each stage adds one layer and keeps the ones below.

| Stage | Layer added | What it is |
|---|---|---|
| Fresh | none | Clean palette |
| Bruised | Surface | Scuffs on gear, a bruise tint patch on skin, sweat sheen. A shader decal only |
| Battered | Geometry | Cracked or chipped regalia, torn hems, loosened straps, cuts with blood runs. Regalia meshes swap to a damaged variant |
| Broken | Silhouette and animation | A piece missing or hanging, a limb held wrongly, a bare wound. Animation changes (limp, dropped guard, head hanging, no dash pose). The silhouette changes by at least 10% of body height, so it reads at 20 px |

**What each region shows**

| Region | Bruised | Battered | Broken |
|---|---|---|---|
| Head | Bruise at the cheek | Split lip, brow cut, hair strands loosen | Half the face masked in blood, one eye shut, head hangs |
| Core | Scuffs on the jacket or harness | Torn hem, a stain, regalia on the back cracks | Cloth torn open over a bare wound, back regalia snapped |
| Arms | Scuffs on guards or bindings | Guards crack or bindings trail, cuts | The arm hangs, guards gone, the hand cannot close |
| Legs | Scuffs at the knee | Trouser hem torn, boot scuffed | A limp, a bare cut, no dash pose |
| Aura crown | Steady | An arc flickers (a shape change, not just a colour) | An arc gaps |

**The Anti-hero's Proud front** (`spec-wounds.md` section 3): while Pride is half or more, the animation holds the composed posture and face whatever the wear, the crown stays whole and battered cards are withheld. Body decals and regalia damage still show, because they are part of the model. When Pride breaks, the withheld cues land in one beat: posture collapses, the face changes, hair falls loose, breath shows and the crown drops to its true state. `docs/art/anti-hero-concepts.md` draws it.

**Graphic dial.** Orb's tone is mature and graphic. The look supports three settings: Full (blood, cuts, torn cloth), Reduced (blood becomes a dark neutral wound colour, cuts stay) and Off (bruise and cloth damage only). Store content ratings for the graphic beats are not checked (Legal); the dial is cheap insurance and an accessibility option.

**Style of wounds.** Flat, cel and graphic in shape (a clean gash, a hard-edged blood run), not photoreal. Wounds are decals and small geometry swaps. Never gore meshes.

## 7. Head flashes, tiers and effect colours

VFX and Rendering own the effects. Art sets the palette, the shape language and the timing. The full design is `docs/art/marked-aura.md`, the data is `data/art/flashes.json`, and the in-engine prototype is specified in `docs/art/flash-prototype-spec.md`.

- **No standing aura.** At rest there is nothing around a fighter. A power stage never draws a full-body aura: the Protagonist's heat is steam and veins on the body, the Anti-hero's is regalia and the sigil's light. The one exception is the transformation **surge**, held for the length of its cinematic (up to 3 s) and then faded in 1.2 s.
- **A head flash** is a brief, iconic pop at and above the head, behind it, never over the mask, the sigil or the chest. Thirteen flashes (danger sense, hazard, found, searching, fear, rage, hurt, resolve, triumph, pride, respect, taunt, surge; Brink is cut, and Winded, Smug, Bored and Primed are held); the pitch that led here is `ma-6-flash-pitch.svg`. Each pulses two or three times in 0.4 to 0.8 s (the surge 1.85 s) and is gone, is about half the size it was first drawn (Orb's playtest), sits up and back of the head and never covers a torso or a face, has a priority and a per-fighter cooldown.
- **Shape families.** Circles for the Protagonist, blades for the Anti-hero, wedges for the Empress, steps for the Cyborg, so a flash is recognisably ours and the four stay apart. The "!" and "?" are drawn in the family's own shapes, not a font.
- **Two classes.** **Info flashes** (danger sense, found, searching) are solid, with a pale core and a thin keyline in the lane colour, so they read on any backdrop. **Emotion flashes** are translucent, a rim and a lighter core, at 34 to 55% opacity. Info flashes are a setting, on by default.
- **Colour** is the fighter's accent for emotion and the pale core with a keyline for info (steel for the Cyborg). Never gold, yellow, red or orange for the Protagonist or the Anti-hero, and no thick black outline.
- **Shape conditions from Legal.** Danger sense is a pointer train of three growing shapes on one ray above and behind the head, turned to the threat's bearing. The Anti-hero's upward flashes are round-tipped. The Empress's upward flashes, and the Anti-hero's surge, are a wide, low crest behind the head. Nothing tall and pointed stands above a head.
- **One channel per fighter.** A flash and UI's HUD crown are never up together. The crown owns wear (a stage change, brink, Rally, facade crack, boil-over), thin arcs in neutral role colours on the HUD layer. A flash owns emotion and sense. Arbitration and priority are in `marked-aura.md` and in the prototype spec.
- **Tiers never change hair.** A tier adds one silhouette-level feature (for the Anti-hero, one regalia piece), one marking-level feature (a seam or line pattern) and a brighter sigil. Tiers are named and shown as pips (`glossary.md`), never as numbers.
- **Beams** are the fighter's accent with a near-white core. Scorch, glow and trail colours on the ground come from the world's heat ramp, not the fighter.

## 8. The world: biome palettes and damage states

The world is a set that gets wrecked. Its palette is mid-value (L* 35 to 75) so fighters and effects sit above it (the value rule). Each biome has a three-step ground ramp, a strata stack (what a crater reveals), materials and cover cues. Values are day. Names of places are Narrative's proposals and are not used here.

### 8.1 Biome palettes

| Biome | Ground or surface ramp (light, base, shadow) | Strata (top, middle, deep) | Materials and flora | Cover cue |
|---|---|---|---|---|
| Ocean | `#59b4d1` `#2f86ad` `#1d5b80`; deep `#123f5e`; foam `#e6f6fa`; shallows `#6fc9c4` | Sand `#d9c89a`, silt `#8c8266`, rock `#4a4a55` | Wave crest bands in the ramp's light step, a flat horizon line, no reflections | Submerged: the surface line closes over the fighter, the fighter goes to the deep ramp |
| Plains | `#9cc95a` `#6da043` `#3f6e34`; field stripes alternate base and `#8cb04d` | Topsoil `#5a4530`, subsoil `#8a6a45`, rock `#6b6f78` | Low hedges, field stripes, a few lone trees | None |
| City | Facade `#b8c0cc` `#7f8896` `#4a5261`; glass `#6aa0c0` and `#2c4a63`; road `#3a3f47`; roof `#2b2f36` | Fill `#6b6f78`, concrete `#8a8f98`, rock `#5b5f68` | Three facade tones only, glass bands, roof plant, no rooftop cover | Rubble heaps after collapse: 0.5 bh for a house up to 6 bh for a skyscraper (`docs/world/buildings-in-depth.md`) |
| Forest | Canopy `#4f9a4a` `#2e6a35` `#17421f`; trunk `#5b3d28`; litter `#6b4b2c` | Humus `#3d2f22`, subsoil `#6b4b2c`, rock `#5b5f68` | Tall trunks (5 to 14 bh), clumped canopy masses | Canopy: the fighter drops behind a canopy mass |
| Desert | Sand `#ecca86` `#cfa85c` `#96733a`; hardpan `#b98b52`; red bedrock `#8e4b34` | Sand, hardpan, red bedrock | Wind-cut dune crests as light lines, rock outcrops, fused glass `#7fd2c0` where beams have passed | None |
| Mountains | Rock `#b0a793` `#7e766a` `#4b463f`; scree `#9a9182`; snow `#f2f5f8` and `#b9c6d6` above the snow line | Scree, rock, deep rock `#3b3833` | Big planar faces, ridge lines, snow caps | Ridge: the fighter tucks behind a ridge line |
| Village, harbour type | Walls `#eee6d6`, roofs `#4c6f8e`, timber `#7a5a3c`, ground `#b9ac8f` | Pebble, sand, rock | Low gables, quay posts, masts, net-drying frames | None |
| Village, workshop type | Brick `#a5533f`, soot `#2f2a2a`, sawtooth roofs `#4a4a4f`, clay `#a07d55` | Clay, brick fill, rock | Sawtooth roofs, bottle kilns, smoke plumes | None |
| Village, hill type | Stone `#8a8f7a`, thatch `#c9a55a`, turf `#6f8a4a` | Turf, stone, rock | Steep thatch, dry-stone terraces stepping up a slope | None |
| Proving ground | Bone-stone `#d9d4c8` `#b7b0a2` `#837c70`; fault seams `#5d574d`; sky `#e9edf2` over `#b9c9dc` | One bone-stone stack | Shattered flat plates, low domed hummocks, a tightly curved horizon. No spires (Legal's note). The sky pales and never darkens | None |

**The three villages are told apart three ways:** hue (cool white and blue, brick red and soot, straw and stone-green), roofline (low gables and masts, sawtooth and kiln stacks, steep thatch on terraces) and rhythm (horizontal quay, repeated verticals with smoke, stepped diagonals).

**Sky and haze (day).** Zenith `#4a86c9`, horizon `#cfe6f0`. The haze colour is the horizon colour. The sea and sky are where most of the fight happens, so the sky is the biggest art asset: a flat gradient with hard-edged cloud shapes in two value steps, and a curved limb visible from altitude.

### 8.2 Dusk, night and weather

| Time | Key light | Ambient | Sky (zenith, horizon) | Notes |
|---|---|---|---|---|
| Day | `#fff6e8` | `#b9c9dc` | `#4a86c9`, `#cfe6f0` | The reference |
| Dusk | `#ffb07a` | `#4a3f8f` | `#34407f`, `#f3a77a` | Warm light side, violet shadows. Rim rule on for dark-value fighters |
| Night | `#a9c1ff` at half strength | `#24365f` | `#0d1430`, `#24365f` | Windows and fires are the light: windows `#ffe2a0`, fire `HEAT_LO` to `HEAT_HI`. Rim rule on |

Weather slots (design only): rain (desaturate 20%, more haze, a streak layer), dust storm (haze in the biome's dust colour, double density), ash (world tint). In every case the fighter plane keeps its contrast: haze never applies to it (section 5, item 11).

### 8.3 Damage states at long zoom

Each state must change the silhouette or the value of a structure by at least L* 12 over at least a quarter of its facade, so it reads at zoom 0.1.

| State | House (4 to 6 bh) | Tower (13 to 30 bh) | Skyscraper (60 to 150 bh) |
|---|---|---|---|
| Intact | Clean palette | Clean palette | Clean palette |
| Scarred | Scorch patches at value minus 15%, lost windows as dark rectangles | The same, plus a soot stripe running up from the strike | The same on the struck floors only |
| Breached | Holes through walls, a roof plane missing, exposed floors | A notch cut through the profile, floor slabs hanging, a smoke plume as tall as the building | A floor-high gap, the crown leaning, a long smoke column |
| Collapsing | The roofline drops | The top third slides, dust in the biome's ground colour | Floors pancake in sequence |
| Levelled | A heap of about 0.5 bh, foundation outline, char | A heap of about 2.7 bh | A heap up to 6 bh, wider, a dust cloud that settles over about 4 s |

Blast-levelled buildings implode into their own footprint and leave a heap (`docs/world/buildings-in-depth.md`, heap height 10% of the building's height, 0.5 to 6 bh), so the levelled silhouette is a mound on the old footprint. A heap at least one fighter high is cover from tier 3 (Game Design, `living-destruction-numbers.md`). Rendering tints the heap from the building's own facade colours so a levelled tower is recognisably that tower.

**Craters.** Round bowls with raised rims and ejecta (Orb). Rim height rises with impact hardness. The rim's lit side is the biome's light step mixed toward the subsoil colour. Ejecta is a mix of the strata colours, so a deep crater shows bands of the layers it cut through. Timeline: fresh (heat ramp at the rim, about 5 s), cooling (char and scorch ring), settled (dust-filled, rim softened by 30%). `render/core/impact_fx.gd` already does the heat part.

**Civilians.** One body height, so they are people. At Play zoom they are readable figures in the eight shirt colours the greybox uses. Casualty marks are the graphic dial's business.

### 8.4 Procedural and alien planets

Palettes are generated from the seed under these constraints:
- The ground ramp keeps the fixed value structure (light L* about 72, base about 52, shadow about 30), so fighters read the same on every planet.
- Ground hue comes from a set of allowed wedges per biome. Chroma stays between 0.05 and 0.16.
- Any generated ground base within 60 degrees of a fighter's accent hue must differ from it by at least 25 L*, or the biome is re-drawn.
- Alien biomes are named by look, not by name: ash plain, crystal steppe, coral shelf, salt flat, glass dunes, fungal forest, lava field.
- Fire hues stay reserved for fire.

## 9. Budgets (proposals for Performance to confirm)

| Item | Budget |
|---|---|
| Fighter, near (over 30 px) | 2,500 triangles, one material, one outline pass |
| Fighter, mid (12 to 30 px) | 900 triangles, regalia simplified |
| Fighter, far (under 12 px) | 250 triangles, no regalia pieces, halo instead of outline |
| Regalia piece | 250 triangles at most |
| Building archetype, near | 800 triangles, facade from parameters, no per-building texture |
| Textures | One shared ramp (256 x 8), one noise map (128 x 128), one atlas per UI. No other textures |
| Draw calls | The greybox is about 80. The look adds about 40 (outlines, regalia, contact shadows) |
| Shader cost | No loops, no texture reads beyond the two shared maps in fighter and prop shaders |

## 10. How to verify

The silhouette and palette tests are reproducible from the repo (Node and a Chromium browser):

```bash
node art/concepts/anti-hero/gen.mjs           # writes the concept sheets and the silhouette test
node art/concepts/anti-hero/gen.mjs contrast  # prints palette-versus-backdrop contrast
```

To see the flat-black test at true size, open `art/concepts/anti-hero/silhouette-test.svg` in a browser at 100% zoom. The sheets also embed the three-colour, greyscale and colour-vision tests.

The Marked plus flashes checks and the turnarounds:

```bash
node art/concepts/marked-aura/gen.mjs         # writes ma-1 to ma-6, and data/art/flashes.json
node art/concepts/turnaround/gen.mjs          # the Coil turnaround
node art/concepts/turnaround/gen-fighters.mjs # the Protagonist, Empress and Cyborg turnarounds
```

Open `art/concepts/marked-aura/ma-5-legal-checks.svg` for the mask silhouette and three-flat-colour tests, each sigil beside the generic patterns to avoid, and the flashes beside the two patterns to avoid.

## Needs from others (through the EP)

- **Rendering and Technical Art:** the feature list in section 5, in priority order, and a view on the outline method and the far beacon. First check whether Compatibility's glow works on the web export.
- **Camera:** the zoom floor. The far band is only meaningful if 0.06 stays.
- **Performance:** the budgets in section 9.
- **VFX:** the beam colour rules and the surge (section 7), and the smear and impact-frame levers.
- **Rendering:** the head-flash prototype (`flash-prototype-spec.md`), which reads `data/art/flashes.json`.
- **Audio:** a cue for each flash, described in words in `flashes.json`: original only, no alert sting, no chirp.
- **UI and UX and Accessibility:** the ego-meter colour proposal, the crown staying down for the surge, the info-flash setting, and the colour-vision test.
- **Animation:** the Proud front as a held posture, the facade crack as one beat, and the regalia and pole as a spring chain (`anti-hero-concepts.md`).
- **World:** the strata stack, the levelled-building look, and the proving ground's look.
- **Legal:** the do-not-draw list in 3.4, and the origin rows for the generator (`art/concepts/anti-hero/README.md`).
