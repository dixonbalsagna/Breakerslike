# Rule of cool: the art side

Owner: Art Director. 2026-10-01. Orb's rule-of-cool picks (`docs/ep/vision.md`, questionnaires 11 and 12), as concept sheets and data. Working labels, pending Legal review. Read with `docs/design/rule-of-cool.md` (rule 9, the stacking rule, and 3b), `docs/legal/rule-of-cool-screen.md`, `docs/ui/hud-spec.md` section 29 and `docs/design/moveset-rules.md` section 10.8.

| Item | Sheet | Data |
|---|---|---|
| 1. Face cut-in portraits | `art/concepts/faces/faces-1-anti-hero.svg`, `faces-2-others.svg`, and 16 squares in `art/concepts/faces/portraits/` | none (UI's `ui/data/faces.json` takes the final texture paths) |
| 2. Battle damage, three stages | `art/concepts/damage/damage-stages.svg` | `data/art/damage.json` |
| 3. The Anti-hero's aura colour and forms | `art/concepts/forms/anti-hero-forms.svg` | `data/art/auras.json` |
| 4. The stacking-rule check | section D of the forms sheet, and the fix to `ma-3-staging.svg` | none |

Regenerate: `node art/concepts/faces/gen.mjs`, `node art/concepts/damage/gen.mjs`, `node art/concepts/forms/gen.mjs`. All deterministic, no packages.

## 1. Face cut-in portraits

UI shows the speaker's face at the side of the screen for every spoken line (`UiFaces`). Four expressions per fighter (neutral, smirk, strain, hurt) for `protagonist`, `anti_hero`, `empress` and `cyborg`: 16 portraits, each a 512-unit square with the face centred and the shoulders cropped by the frame. The Anti-hero is first (his own sheet, at 420 px, 200 px and 120 px, in colour and greyscale); the other three share the second sheet. KAI and VORR can use the protagonist's and the anti-hero's portraits as stand-ins until their own art exists.

- **The masks have no face, so the head, the sigil and the frame carry the line.** Neutral: head level, the sigil upright. Smirk: chin up and back, the sigil tilted and low (the same flick as the taunt). Strain: head forward and low, the sigil flared and lit. Hurt: head down and turned away, the sigil dim with a gap. These read at 200 px, and the four still differ at 100 px and in greyscale.
- **Our own frame (Legal: no green codec look).** A chamfered square (two opposite corners cut, so it is an angular facet and not a rounded screen), a flat lane-colour ground with a few large flat shapes in the fighter's own shape family (circles, blades, wedges, steps), a thin inner keyline and one short accent bar. No scanlines, no static, no green tint, no portrait layout copied from a known game. Pale masks sit on a dark lane ground and dark masks on a light one, so the mask always separates.
- **Direction.** The art faces right. UI mirrors it for the right-hand speaker.
- **How final textures are made under zero budget.** The 16 SVGs are the final art. Godot imports an SVG as a texture, so UI can point `faces.json` `art` paths at them (`res://art/faces/<id>_<expression>.svg` once they move out of the ignored concept folder), or the same generator can write 512 and 1024 pixel PNGs with the headless Chrome recipe we already use for checks. Nothing needs a painting tool or a paid asset, and a change to a mask or a sigil regenerates all 16 in a second. A later hand-painted pass is possible but not needed.

## 2. Battle damage that stays and builds

Orb picked torn clothing, scuffs and bruises, a broken limb that hangs or drags, the aura flickering when worn, and heavy breathing and stagger, and said it stays and keeps building through a transformation. Three stages per outfit, mapped onto the existing wear stages (bruised 30 to 59, battered 60 to 89, broken 90 and above):

| Stage | Orb's pick | What shows |
|---|---|---|
| 1 scuffed | scuffs and bruises | Scuffs on gear, a bruise tint on an arm and the neck, quick breathing, a steady aura |
| 2 torn | torn clothing | A torn hem, a torn shoulder, a chip at the mask corner, a frayed or cracked outfit piece, heavy breathing, a light stagger, the aura flickering (a shape change) |
| 3 ruined | a broken limb that hangs | The near arm hangs, the near leg drags, a large rip, a piece missing or hanging, one crack across the mask, ragged breathing, a heavy stagger, the aura gapping. The silhouette change is at least 10 percent of a body height, so it reads at 20 px |

Each fighter's outfit has its own pieces: the Protagonist's tunic, apron and wraps; the Anti-hero's jacket skirts, forearm guards and spine plates (plates crack, then two go missing); the Empress's mantle, tabard and blades (a notch, then a wide tear and a hanging strip); the Cyborg's mail apron, plating, hatches and cables (holes, a dented hatch, a hanging cable).

- **Persistence.** The wear is a property of the body, not the form, so a new form adds its regalia above the damage and the torn parts stay torn on it. Nothing resets on a transformation, only the end of a match. For the Anti-hero, losing a form when Pride crashes keeps the damage too.
- **Neutral by default.** The damage is scuffs, tint, torn cloth and a hanging limb. The kit's blood decals stay behind the graphic dial and are separate layers.
- **For Rendering:** decals are shader layers keyed by wear stage, geometry rows are small mesh swaps merged at equip (the cosmetics rules in `cosmetics-plan.md`), and silhouette rows change the body. **For Animation:** the stage table in `damage.json` gives breath rates (1.3, 1.7 and 2.2 times the rest rate), chest rise (1, 2 and 3 percent of a body height), stagger and the limb pose, all proposals. Layer ids are in `data/art/damage.json`.

## 3. The Anti-hero's aura, flashes and glow, by form

Legal's range is hue 260 to 320, a lighter tint of the same hue for the core, never pure white, and no red, orange, gold or yellow. His forms, as the EP folded them: Regalia, Sovereign and Apex (the pieces are in section 10.8: the collar and guards at Regalia, the crest and floating plates at Sovereign, and at Apex the guards fall away and the sound cuts out). The aura is a thin outline of the whole silhouette in the form's colour, with a few thin rings, only while charging or attacking, never at rest.

| Form | Hue | Aura rim | Core (a tint) | Shadow | Keyline | Sigil glow |
|---|---:|---|---|---|---|---|
| **Regalia** | 266 (the deep violet base) | `#9664d8` | `#d3baf2` | `#52327b` | `#301a4d` | `#d8bff7` |
| **Sovereign** | 290 (toward magenta) | `#bf60d2` | `#e7bdef` | `#6b3276` | `#431b4b` | `#edc1f6` |
| **Apex** | 272 (colder, quieter) | `#8d51c2` | `#ceb1e7` | `#4e2f6a` | `#2f1943` | `#ddc2f4` |

The **flashes** take the same rim as their mid step and the core as their light step, with the shadow as the info keyline and a pale tint (`#eee5fa`, `#f6e6fa`, `#f0e7f9`) as the info core. The flash shapes, pulses and keep-out zone never change with the form, only the colour. The values are in `data/art/auras.json`.

- **Preference for Orb** (deep violet is on the form): the recommended set above is deep violet that warms to a magenta-violet at Sovereign and cools to a quiet blue-violet at Apex, so each form is a distinct colour mass at 12 px. The alternatives: (a) one hue, 266, in three intensities (consistent and quiet, but the forms read apart only by the shapes); or (b) magenta-forward, 280, 300 and 290 (louder, closer to Legal's upper edge). Orb picks; none leaves the range.
- **A small correction to flag.** The Anti-hero's current flash accent (`#9a80d8`) is at hue 258, just under Legal's 260. The Regalia set (266) is inside the range. If Orb takes the recommendation, `flashes.json` `accents.A` takes the Regalia rim, core and shadow. I have not changed it yet.
- **Checks.** All three are inside 260 to 320 and none is white (the lightest core is L* 82) or mid blue or teal. The rim alone is mid-value, so it reads by its thin dark keyline and the two-tone edge, as the body does; the deutan numbers against five backdrops are on the sheet.

## 4. The stacking rule

No single moment may show more than two of the seven marks. Checked, and the audit is on the forms sheet:
- **The new transformation staging** (rise out of the crouch, still, one flick, regalia locks, settle) shows at most mark 4 in part (the ground cracks at the break, only if he stands on it): one mark.
- **One real fix.** `ma-3-staging.svg` moment 3 drew the Anti-hero's surge as arms thrown wide with the head back, which 10.8 forbids. It now uses the upright, composed pose: chin lifted, still, one hand palm-up. Its crest is the low, wide, up-and-back pulse of shapes, with two small shards at the feet (part of mark 4).
- **Everything else** is clear: the head flashes carry no flame, no flash of gold, white or red and no shouted form name; the aura is a thin outline and rings only while charging or attacking, and the staging keeps the crouch and the scream out, so it never stacks with them. The retired round-3 "Aura" variant had a standing aura of slabs and is not in use.

## Needs from others (through the EP)

- **Tools:** schemas for `data/art/damage.json` and `data/art/auras.json` (new files, shape in the files, no schema yet: `validate.js` warns "no schema").
- **UI:** point `faces.json` `art` at the portraits when they move out of the concept folder; mirror for the right-hand speaker.
- **Rendering and Animation:** the damage stages and breath numbers; the form pieces for the Anti-hero (collar, guards, crest, plates).
- **Legal:** the frame, the aura colours and the three forms.
- **Orb:** the aura colour preference (recommended set, one hue, or magenta-forward).
