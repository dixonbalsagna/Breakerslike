# District looks, building shapes and landmarks: the visual brief

Owner: Art Director. 2026-09-30. For World's D1 (`docs/world/districts-plan.md`, `data/biomes/settlements.json`). Draft, pending Legal review. Every design here is original: generic building types in our faceted style, no real landmark, no franchise. Palette values come from `style-guide.md` section 8.1 (the world owns L* 35 to 75, and a building never uses a fighter's hue lane as a mass).

**Faceted rule for every shape.** A building is a prism or a stack of prisms with at most three roof facets. No curves: a chimney or a lighthouse is an octagonal prism with a tapered cap, never a cylinder. Three facade tones per look (light, mid, shadow) and one window pattern. At far range a building is two flat value bands and its top silhouette (`style-guide.md` section 2).

## 1. The `shapes` list: what to change

The shape is a render-only hint, so changes are cheap and never touch the sim hash. The current 14 are good bones. Proposed:

| Change | Shape | Why |
|---|---|---|
| **Rename** | `tower` to `shaft` | `tower` is also the sim's kind name (`kind: tower`), so `shape: tower` is confusing in the file. `shaft` is a plain tall prism |
| **Add** | `crown` | A tower with a chamfered, faceted top (a flat-topped cut at 45 degrees). It gives downtown a third skyline silhouette next to `shaft` and `stepped` without more spires |
| **Add** | `terrace` | A house stepping up a slope in two or three stone stages: the hill village's look (`style-guide.md` 8.1, "dry-stone terraces stepping up a slope") |
| **Add** | `sawtooth` | A long low building with a saw-toothed roof (three or four teeth): the workshop village and the industrial district |
| **Add** | `thatch` | A house with a steep, deep-eaved roof (about 55 degrees): the hill village's roofline |
| **Add** | `quay` | A long, low, flat platform at the water's edge with post stubs: the harbour district's ground line (it was in World's first list) |
| **Add** | `mast` | A thin pole with a faceted yard arm, 10 to 14 bh: the harbour's vertical rhythm, next to `crane` |
| Keep | `stepped`, `spire`, `slab`, `block`, `warehouse`, `chimney`, `house`, `shop`, `hall`, `shed`, `crane`, `lighthouse`, `chapel` | See the one-line meanings below |

That is 20 shapes: the 13 kept, `shaft` (renamed) and six new. Only `shaft` needs a data change now; the new ones are unused until a district names them (section 2).

**One line each (the silhouette Rendering builds).**
- `shaft`: a plain tall prism, flat roof with a low plant box.
- `stepped`: a prism with two or three setbacks, the top tier about 60 percent of the base width.
- `crown`: a prism whose top corners are chamfered in one facet, reading as a cut gem.
- `spire`: a shaft topped by a four- or eight-sided pyramid taller than a storey. Rare, and never a needle (Legal: nothing reads as an antenna).
- `slab`: a wide, flat-fronted mid-rise, long side to the street.
- `block`: a near-square mid-rise with a roof plant box and a parapet.
- `warehouse`: a long low box with a shallow gable, big door panels.
- `sawtooth`: as `warehouse` but the roof is a run of saw teeth.
- `chimney`: a tall octagonal stack, tapered, with a wider flared cap.
- `house`: a box with a 35 to 40 degree gable.
- `thatch`: as `house`, steeper (about 55 degrees) with deep eaves.
- `terrace`: a `house` in two or three stone steps up a slope.
- `shop`: a `house` with a wide ground-floor front and a flat awning facet.
- `shed`: a lean-to, one roof facet.
- `hall`: a long gable with a stepped porch.
- `chapel`: a gable with a small three-sided belfry at one end.
- `quay`: a long low platform with post stubs.
- `crane`: a mast with a long faceted jib, always a little off centre.
- `mast`: a thin pole with a yard arm.
- `lighthouse`: an octagonal tapering tower with a faceted lantern room under a cone.

## 2. Looks: one short brief each

Looks in the data today: harbour, village, suburb, industrial, mid_rise, downtown. **Split `village` into three** (`village_harbour`, `village_workshop`, `village_hill`): Netmend's core, the outskirts and the far village share `look: village` now, but the style guide makes the three villages readable by hue, roofline and rhythm, so they need their own looks. Palettes are the style guide's; windows give the near and mid looks.

| Look | Silhouette | Window pattern | Palette lane | Roofline |
|---|---|---|---|---|
| **downtown** | Tall and uneven: `shaft`, `stepped`, `crown`, a rare `spire`, rising toward the middle | Continuous vertical glass bands between pale piers, a floor line every band; at mid range, a striped band pattern | Facade `#b8c0cc` `#7f8896` `#4a5261`, glass `#6aa0c0` and `#2c4a63` | Flat with plant boxes, setbacks on `stepped`, a chamfer on `crown` |
| **mid_rise** | A wall of slabs with regular gaps, about a third of downtown's height | Horizontal window strips, two per storey, pale sills | Same facade lane, one step lighter; glass `#6aa0c0` | Flat with a parapet and one plant box |
| **suburb** | Low, small, rhythmic: repeated `house` gables with small gaps | A grid of small windows, two or three per facade, a door | Warm plaster `#d9cfc0` `#b9ac8f`, slate roofs `#5b6474` and timber `#7a5a3c`; no saturated orange | Gables at 35 to 40 degrees, all one direction per block |
| **industrial** | Long and low, broken by tall `chimney` stacks | A clerestory strip under the roof, big door panels, almost no other windows | Concrete `#8a8f98`, soot `#2f2a2a`, corrugated `#6b7280`, brick stack `#8a5a48` | Sawtooth or shallow gable, with chimneys as the vertical accent |
| **harbour** | Low sheds along a `quay`, with `crane` and `mast` verticals and one lighthouse | Few windows: shutters and wide doors, a tall loft hatch | Walls `#eee6d6`, roofs `#4c6f8e`, timber `#7a5a3c`, ground `#b9ac8f` | Low single-facet sheds, lean-tos, a pole line |
| **village_harbour** (Netmend's core) | Cool white cottages stepping down to the quay | Small square windows with blue shutters | Walls `#eee6d6`, roofs `#4c6f8e`, timber `#7a5a3c` | Low gables, quay posts and masts, a horizontal rhythm |
| **village_workshop** (the outskirts) | Brick and soot, with `sawtooth` sheds and kiln `chimney` stacks | Small square windows, dark frames, a big door | Brick `#a5533f`, soot `#2f2a2a`, sawtooth roofs `#4a4a4f`, clay `#a07d55` | Sawtooth teeth, repeated verticals with smoke |
| **village_hill** (the far village) | Stone and straw on a slope, stepped diagonals | Tiny windows in thick walls | Stone `#8a8f7a`, thatch `#c9a55a`, turf `#6f8a4a` | Steep `thatch` (55 degrees) and `terrace` steps, a stepped diagonal |

The three villages read apart by **hue** (cool white and blue; brick red and soot; straw and stone-green), **roofline** (low gables and masts; sawtooth and stacks; steep thatch) and **rhythm** (a horizontal quay; repeated verticals with smoke; stepped diagonals). Settlements must also read apart from the fighters: no teal, orchid, moss or coral mass on any building, and no mid-blue mass, which belongs to water.

## 3. The five landmarks: one original idea each

Each is a faceted silhouette with no real counterpart: no clock face with numerals, no known tower, lighthouse or church.

- **bell_tower** (`spire`, 150 bh): *the Gatebell*, a stone shaft with an open belfry of four pointed arches, a dark faceted bell cone visible inside, and an eight-sided spire; one small stair bump on one side so it is never symmetric. No clock face.
- **chimney_stack** (`chimney`, 45 bh): an octagonal stack in three pale and soot bands, with a wide flared cap and a short side flue, taller than anything else in the industrial district.
- **lighthouse** (`lighthouse`, 40 bh): an octagonal tapering tower in two wide bands (pale stone, slate), with a faceted lantern room of pale cyan glass under a low cone roof. No beam geometry, no stripe like a real light.
- **village_hall** (`hall`, 8 bh wide): a long timber hall with a steep central gable, a stepped porch, and a small faceted lantern on the ridge, painted in its village's palette.
- **hill_chapel** (`chapel`, 14 bh tall): a stone chapel set on a terrace step with a steep thatch roof and a small three-sided belfry at one end; the belfry bell is one dark facet.

## Needs from others

- **World:** rename `tower` to `shaft` in the shape list and data; add the six shapes; split the `village` look into three. The schema's shape list and the validator's look check (Tools) follow.
- **Rendering:** the shape builders from section 1. The first pass can draw `shaft`, `stepped`, `crown`, `slab`, `block`, `house`, `warehouse` and `sawtooth` (eight prisms); the rest are cosmetic detail.
- **Legal:** a screen of the landmark ideas, the same as the fighter sheets.

I can draw a one-sheet silhouette chart of the 20 shapes and the eight looks for World and Rendering if useful.
