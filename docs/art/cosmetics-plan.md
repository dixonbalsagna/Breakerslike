# Cosmetics plan: a vast unlock set, by data

Owner: Art Director. 2026-09-30. A plan for Orb's "a vast assortment of cosmetics players unlock through play" (`docs/ep/vision.md`, last section). Draft for the EP, Orb, Animation, Rendering, Tools and Legal. Nothing here is built.

**The rule above all rules: cosmetics are render-only.** They are ids in a loadout file that the renderer reads. The sim never reads them, so the gameplay hash is the same with any loadout (fairness online, and `cue_check` style hash checks prove it). In an online match each player sends only ids; a peer that lacks an id draws the default. Originality rules (`originality-rules.md`, `q3-screen.md`, `style-guide.md` 3.4) apply to every item, and each pack gets a Legal screen and an origin row.

## 1. Categories that fit our style

| Category | What changes | How it is made |
|---|---|---|
| **Palettes** | Body, gear and accent colours | Three palette slots (data). The same mesh takes any set |
| **Mask finishes** | The mask's surface: polished, matte, glazed, cracked glaze, stamped pattern, inked edge. The sigil's own tone inside its lane | Shader parameters on the mask slot. Mask shape and tone class are fixed |
| **Outfit and regalia parts** | Belt, sash, wraps or guards, back piece (knot, plates, mantle hem, backpack cover), boots trim, collar | Small swappable meshes inside a fixed envelope, plus a pattern id |
| **Patterns** | Stripes, bands, chevrons, scales, weave on cloth and plating | A procedural pattern in the shader, chosen by id (no textures, `style-guide.md` section 1) |
| **Accessories** | Charms, pins, badges, cords, a small scarf, a belt pouch | Sockets on existing bones (below). Never above the head |
| **Trails, beam tints, flash tints** | Trail style and colour; the beam's accent; the emotion flashes' accent. Never the info flashes | `data/art/effects.json` lanes and `flashes.json` accents, per loadout |
| **Poses and taunts** | Taunt gestures, victory poses, knockout reactions, showcase poses | Rows in the animation rig, blended as today |
| **Victory scenes** | A short post-win staging: a camera move, a backdrop tint in the biome's own range, one prop | Camera and a data preset. No new models |
| **Marks and banners** (UI) | Titles, portrait frames, nameplates, the HUD crown's arc style | UI owns the drawing, Art the palette roles |
| **Original extras** | Weather-worn variants (wear tints), a tier-glow sigil colour, footstep dust tints | Data on existing systems |

## 2. What keeps each fighter readable

A cosmetic is accepted only if it keeps all of these. Tools' validator checks the data ones; Art reviews the mesh ones.

1. **Silhouette lock.** Each fighter's one shape feature stays: the Protagonist's round, forward lean and the belt knot; the Anti-hero's spine plates and tail; the Empress's mantle and topknot; the Cyborg's boxy head and backpack. A part variant must fit its **slot envelope** (a hull per slot, about plus or minus 10 percent of the body's width or height). Nothing rises above the head. No horns, antennae, goggles, wings, halos or spikes (Legal's lists).
2. **Identity marks never change.** The mask tone class (pale or dark), the sigil's shape and place (an open arc, a leaning slash, three chevrons, a stair of squares), the fighter's shape family (circles, blades, wedges, steps), and the head flashes' shapes, pulses and keep-out zone.
3. **The colour-blind-safe flash language never changes.** Info flashes (danger, hazard, the finisher tells, found, searching) keep their pale core and thin keyline, so a palette can tint the keyline only inside the lane. Emotion flashes may take the loadout's accent, with the Protagonist's rim-over-hair rule. A cosmetic adds no standing glow, aura or flash-like trail.
4. **Value rule and lanes.** Body lightness L* 30 or less, gear 80 or more, the accent never a mid-value block on more than 10 percent of the figure. Accent hue stays within the fighter's lane (teal, orchid, moss, coral, plus about 20 degrees), never red, orange, yellow or gold for the Protagonist and the Anti-hero, and never fire's colours as a mass or a flash. Hair never gold and never changes with power.
5. **Colour-blind check on every palette.** A palette passes only if its body, gear and accent separate in greyscale and in deutan, protan and tritan simulation (the method in `effects.json` `deutan_check`), and if the fighter reads against the grass, sea and sky backdrops by value (the rim rule). Tools can run this as a validator.
6. **Match-up clash.** If both fighters in a match end up within a small colour distance (a mirror match, or two recolours), the renderer draws the opponent with its default palette. This is a render-side swap and never touches the sim.
7. **Fairness tells stay default.** Anything a player uses to read the other player (stance chips, the crown, the flashes, the sigil) is not a cosmetic.

## 3. A rough count that gets to "vast" cheaply

Per fighter, rough first targets. Only the mesh and animation rows cost real work; the rest is data.

| Category | Items per fighter | Cost |
|---|---:|---|
| Palettes | 40 | Data: Art hand-makes 8 and a generator fills 32 inside the lane rules, all validator-checked |
| Mask finishes | 12 | Shader presets |
| Outfit and regalia parts | 32 (4 slots of 8) | Small meshes of 40 to 120 triangles, shared palette and patterns |
| Patterns | 10 | Shader presets, shared across all fighters |
| Accessories | 12 | Small meshes on sockets |
| Trails, beam tints, flash tints | 30 (10 + 12 + 8) | Data on VFX's and the flashes' lanes |
| Taunts, victory poses, KO reactions | 18 (8 + 6 + 4) | Animation rows |
| Victory scenes | 6 | Camera and data presets |

About 160 items per fighter, 640 across four, with the worth of a real game in the **combinations**: 40 palettes x 12 finishes x 8 parts in each of 4 slots is over 1.9 million looks per fighter. Of the 640 items, about 250 need a mesh or an animation row (128 parts, 48 accessories and 72 pose rows), and the rest are numbers in a file. UI's titles, frames and nameplates (about 40 per account) sit on top.

## 4. What the fighter mesh needs from day one (for Animation and Rendering)

The production fighter must be built for this now, because retrofitting slots is expensive.

- **Named swappable slots**, each its own mesh instance so a variant swaps without touching the body: `mask` (shape fixed, finish by material), `hair`, `outfit` (torso), `belt`, `arm_gear` (near forearm), `back_piece`, `boots_trim`, `collar`. The Anti-hero's plates and the Empress's mantle are back pieces with an intact and a broken variant (`style-guide.md` section 5).
- **Sockets for accessories**, as named transforms on existing bones (not extra bones): `socket_back`, `socket_chest`, `socket_hip_l`, `socket_hip_r`, `socket_shoulder_l`, `socket_shoulder_r`, `socket_wrist_l`, `socket_wrist_r`. None above the head.
- **Material slots, one material per fighter**: the palette mask (vertex colour R body, G gear, B accent, A emissive) plus three uniform colours for mask, hair and skin, a `pattern_id` per slot, and a `finish_id` for the mask. Parts share the material, so a cosmetic costs no new material and no texture.
- **Envelope hulls** per slot, shipped as data for the validator and the modeller.
- **Budgets hold with cosmetics on** (`style-guide.md` 5.1): at most 32 bones and 12 draw calls per fighter. Draw calls: body 1, outline 1, up to 5 cosmetic part instances, the flash quads 2, the contact shadow 1, regalia 1, with the rest spare. Parts merge per slot, and cloth parts take at most two spring chains each from the 32-bone budget (the Empress's mantle and the Protagonist's sash tails are the cost to watch).
- **Smoothed outline normals** on every part (5.1), so a swapped part never cracks the hull outline.
- **Loadout data** in `data/art/cosmetics/` (Tools adds the schema): one file per pack with the item id, category, fighter, slot, palette or mesh reference, rarity and its unlock track, and the Legal screen status. The sim never reads this folder.

## Open questions (through the EP)

1. **Who owns the unlock tracks** (what play earns what)? Game Design. Art only supplies the categories and counts.
2. **Is a cosmetic ever shared across fighters** (a pattern, a trail, a victory scene)? Patterns, trails, beam tints and scenes are designed to be, which keeps the count cheap.
3. **Do we allow player-made palettes** later? The validator in section 2 makes that safe; it is a question of scope.
