# The Anti-hero, round 2: five silhouettes

Owner: Art Director. 2026-09-29. Concept art for Orb to choose from, not a locked design. He/him. Working labels. Results are **pending Legal review**. Round 1 is `anti-hero-concepts.md`; Orb picked none of A, B or C. This round has a wider range and no shedding kit (Shed Regalia is deferred).

**Sheets** (`art/concepts/anti-hero/`): `round2-overview.svg` is the sheet to open first: a silhouette, a colour thumbnail, a personality line, the form ladder and wear for each of the five. `round2-silhouettes.svg` is the flat-black test at true size (view at 100% zoom). `node art/concepts/anti-hero/round2.mjs` regenerates both.

## The five

| | Build | Posture | Defining feature | How the forms (F1 to F6) read | Personality in one line |
|---|---|---|---|---|---|
| **D. The Duelist** | Lean, tall | Upright, arrogant | Knee-length coat and one oversized gauntlet | The gauntlet gains a ring, a length and a width per form | A fencer's stillness: he does not hurry because he does not need to |
| **E. The Brawler** | Heavy, short-legged | Low, predatory | A scar across the face, bare arms | One ash-white slash scar across the chest per form (colour only), heavier aura at the shoulders | A wall that leans in, happy to be hit so he can answer |
| **F. The Coil** | Compact | Low crouch, coiled | A line of armour plates down the spine, a short tied hair tail | One spine plate per form, forearm guards from form 4 | Small, watchful, all spring |
| **G. The Mane** | Tall | Upright, aloof | Hair down to the calves, sleeveless tunic | One metal cuff on the hair per form (colour only), aura shape | Immaculate and aloof; the hair is the banner |
| **C. The Standard, revised** | Medium | Upright, arrogant | A slim spine frame with narrow dark slats (no bright flags, shorter, no harness comedy) | One slat per form | Ranks everyone and carries the ranking on his back |

Range covered: build (lean, heavy, compact, tall, medium), posture (upright and arrogant for D, G and C; low and predatory for E and F) and defining feature (coat, gauntlet, scar, armour line, hair, a frame). None wears a cape. Hair never changes colour or shape with form; the hair cuffs on G are metal, not hair.

**How forms read without a pole.** The forms are readable at 40 px in D (a growing gauntlet, a silhouette change) and in C (slat count, marginal). For E and G they read in colour only (scars, cuffs); for F the plates read in colour and only faintly in silhouette. The far-zoom read for all of them is posture, mass, the aura shape and the halo, not the form count.

**Aura shape** (VFX proposals, all in his violet ramp, no gold, red or orange): D, a tall, thin vertical blade of light with a hard edge; E, broad rounded slabs that thicken at the shoulders; F, a tight ring hugging the body that loosens per form; G, long vertical streaks that follow the hair; C, straight thin lines rising along the frame.

## Palettes

Light, mid and shadow per mass are in `concepts2.mjs` (`PALETTES2`). All are in the violet lane with the value rule (body dark, gear light). Body L* is the mid step.

| | Body | Gear | Accent | Body L* / gear L* |
|---|---|---|---|---|
| D | `#2b2140` | `#c3cde0` | `#d0508c` rose | 15 / 82 |
| E | `#30244f` | `#d6d0e6` | `#b56bd8` orchid | 18 / 85 |
| F | `#2a2043` | `#cbd3e2` | `#a36cf0` violet | 15 / 84 |
| G | `#3b2a55` | `#dcd6ea` | `#ee6ba0` rose | 21 / 87 |
| C | `#33264f` | `#d3cde3` | `#e0407f` with crimson `#7d1745` | 19 / 83 |

Contrast against the sea surface (`#2f86ad`): bodies 3.1 to 3.7, gear 2.6 to 2.9. Against the deep sea and night the bodies vanish (1.2 to 1.4), so the rim outline applies to all of them (style guide section 4). The gauntlet on D is dark with light edge lines, so it is not a white glove.

## Silhouette test

Flat black at true size, against a bystander of the same height. Body height is feet to hair. Inspected at pixel level in `round2-silhouettes.svg`. **Pending Legal review.**

| Test | D Duelist | E Brawler | F Coil | G Mane | C, revised |
|---|---|---|---|---|---|
| 40 px against the bystander | Pass. The gauntlet mass | Pass. Wide, low body | Pass. Compact crouch | Pass. The hair mass | Pass. The frame line |
| 12 px, find the fighter | Pass. A fist mass at the end of the arm | Pass. A wide low crouch | Pass. A compact crouch | Marginal. A slightly wider back | Marginal. A tick above the head |
| 5 px, find the fighter | Marginal | Marginal. A different shape | Marginal | Fail | Marginal to fail |
| F1 against F6 at 40 px | Pass. The gauntlet grows | Fail in flat black (scars are colour) | Fail in flat black (plates are faint) | Fail in flat black (cuffs are colour) | Marginal. The slat count is faint |

**The shape feature (not colour) that tells each apart:** D, the oversized fist. E, the wide, low crouch and heavy trunk. F, the compact crouch with a serrated back. G, the long hair mass. C, the vertical frame above the head.

**Findings beyond the designs**
1. **A low posture is the strongest small-size read.** E and F pass at 12 px on posture alone, because most bystanders stand upright. Upright bodies (G, C) need a feature that sticks out.
2. **The form count is the weak spot** for E, F and G in silhouette. If Orb wants forms readable at 40 px in silhouette, D (gauntlet) is best, then C.
3. **At 5 px nothing carries identity** for any of them. The far read is the halo, the aura and the colour mass (style guide sections 2 and 4).

**Originality checklist, item 4 (silhouette, then three flat colours, "what does this remind me of?").** Honest answers, pending Legal. I cannot run a fan-recognition check.
- **D** reminds me of a fencer or a gunslinger with one armoured arm, in a long dark coat. No specific character came up.
- **E** reminds me of a boxer or a bare-knuckle fighter with a scarred face. No specific character came up. Note the chest scars are drawn as irregular claw-like slashes, not parallel stripes.
- **F** reminds me of a sprinter's crouch, or a knight's back-plate. A stacked spine of plates can read as a backpack or a dorsal ridge; the plates are rounded slabs, not spikes. No specific character came up.
- **G** reminds me of a long-haired swordsman. Long straight dark hair with metal cuffs is generic. No specific character came up.
- **C** reminds me of a standard-bearer, a slimmer, straight-faced version of round 1.
- None has shoulder pads, white gloves and boots, flame or upswept hair, or a tail. Hair is dark and constant.

## Comparison

| | D | E | F | G | C, revised |
|---|---|---|---|---|---|
| Cost (art and rigging) | Medium: coat cloth and one growing armour part | Low to medium: bare, rigid | Low to medium | Medium: long hair chain | Low to medium |
| Readability at 12 px | Good | Good | Good | Marginal | Marginal |
| Forms at 40 px (silhouette) | Good | Colour only | Faint | Colour only | Marginal |
| Legs and arms for choreography | Legs partly hidden by the coat | Fully visible | Fully visible | Fully visible | Fully visible |
| Animation load | Medium | Low | Low to medium (hair) | Medium (hair) | Low |
| Fits the brooding, formal voice | Strongly | Less (a brawler is not formal) | Partly | Strongly | Strongly |
| Risk | Officer-uniform reading is gone, but the coat is close to round 1's A | Tone: a brawler does not rank people | Plates may read as a backpack | Weak at small zoom | Less memorable than round 1's C |

**Recommendation: D, the Duelist, with the Coil's crouch as its low posture. Orb decides.** D is the only one that reads at 12 px, shows its forms in silhouette at 40 px and fits the cold, formal voice ("a rank, then silence"). The crouch is a pose, not a body: a lean duelist can drop to a coiled stance when the front cracks, which gives the posture range Orb asked for (arrogant upright, then predatory low). E is the pick if Orb wants him physically imposing rather than formal.

## Wear and the front

All five follow the wear layers in the style guide (section 6) on their own parts: D tears the coat hem and cracks the gauntlet; E scuffs and cuts the bare arms and face; F loses plates off the spine; G frays the tunic; C's slats fray and the frame snaps at the core. The sheet shows fresh, bruised, battered and broken. The Proud front holds in the upright bodies (D, G, C) as a composed pose; for E and F the front is an unnaturally still crouch, which is a different tell (the coiled body holds, then springs).

## Questions for Orb (through the EP, three at most)

1. **How does he stand when he is winning?** Upright and still (D, G, C), or low and ready (E, F)?
2. **What is the one thing you would draw first?** An arm or hand that grows (D), a scarred face (E), a back of armour (F), the hair (G), or something on his back (C)?
3. **Wry or grim?** Should his look carry a dry joke (a frame of rank slats, a growing fist), or be all cold and plain?

## Files

`art/concepts/anti-hero/`: `round2-overview.svg`, `round2-silhouettes.svg`, `round2.mjs`, `concepts2.mjs`, plus `kit.mjs` (extended with a per-figure build: torso width and length, limb width, head, leg and arm scale). The prompt record is `art/prompts/ART-0002-anti-hero-round2.md`.
