# The window blow-out record (a sim record for replay seeks): plan

Owner: World and Environment. Status: plan, 2026-10-03, docs only, with a read-only measurement. Nothing here is in the sim. Rendering's ask (docs/rendering/README.md, "Windows, and windows blowing out", Limit): the facade's windows go out from VFX's `host.vfx.react.blowouts` list, which VFX prunes after 6 seconds, so a replay seek does not bring back older blow-outs. A record in the sim state fixes that.

## 1. What exists today

- VFX's `on_crater` (render/vfx/react.gd:218) fires on the sim's `crater` event when the owner is tier 3 or more and the crater's energy is at least 8 (or it is a special). It takes the standing buildings of 3 floors or more within the tier's reach (1,800 units at tier 3, 3,200 at tier 4, plus half the building's width), nearest first, at most 10 (the number scales down with quality and reduced motion, which the sim cannot see), and gives each a strength `clamp(1 - 0.6 d / reach, 0.2, 1)` and `rows = clamp(round(floors x strength x 0.6), 1, 6)` rows spread up the building at `floor((r + 0.5) / rows x floors)`. The glass flies after the shock has travelled (`d / 2,600` seconds).
- Rendering draws the building's windows as dark openings on those rows for the rest of the match (one bit a floor a building in a small data texture, 62 floors at most).
- A damaged building gets shorter, so the windows of the floors that are gone go with them (`fmask` and the standing height); the sim's `fdmg` holds the damage per floor of local hits.

## 2. What is measured

A replay of the rule in the sim from the `crater` events, 30 default-arm matches (the tree, ground contact on): **34.6 craters a match, 0.9 blow waves a match, 8.0 buildings a wave, 5.8 rows a building, and 1.2% of the window rows of the 3-floor-or-taller buildings blown at the KO.** The record is small: most matches have none (the hero keeps fights off towns), a tier-4 fight in a city has several waves.

## 3. The record

- **State:** one integer on each `SimState.Building`: `wmask`, one bit a floor (bit 0 the ground floor; 62 floors at most, the same limit as Rendering's texture; the tallest building today has far fewer), the floors whose windows are blown out. Hashed with the other building fields (`BUILDING` in hash.gd), so it takes part in replay equality and a seek that restores the state restores the windows.
- **Setting it:** one function, `WorldStructures.blowWindows(S, b, rows, strength)`, that ORs rows into `b.wmask` by the rule above (`floor((r + 0.5) / rows x floors)`, only floors still standing in `fmask`). Called from `WorldCrater.dig` right after the crater is recorded, by the same rule as VFX's (the owner's tier, the energy gate, the reach by tier, the 3-floor minimum), with the **full** building count (the limit of 10 stays in data: `maxBuildings`; the quality scaling is presentation's and only thins the glass, not the record). A beam clash blast, a heavy-clash shockwave and a landing slam are not in the rule today (VFX does not blow windows for them); the record can add them as data rows when VFX and Rendering want them.
- **No `S.rng` draws, no new events.** Everything is a function of the crater event and the standing buildings, so the record is deterministic and replay-safe. The shock's travel time is presentation: the bits are set at the impact, and Rendering shows a bit as out once VFX's own entry for that building (its `at`) has passed, or at once when there is none (a seek, a late join). I do not store the arrival tick.
- **Damage windows need no record.** The windows lost with a building's lost height, and the cracked or dented floors (`fdmg`), are functions of the state Rendering can already read (`fmask`, `fdmg`, hp over maxhp), so they are not stored again.
- **Data:** `data/biomes/windows.json` (`biomes.windows/1`): `minTier` 3, `minEnergy` 8, `reachByTier` [0, 0, 1800, 3200], `minFloors` 3, `maxBuildings` 10, `maxRows` 6, `rowShare` 0.6, `strengthMin` 0.2, `falloff` 0.6. VFX's `data/vfx/react.json` "windows" then keeps only the presentation numbers (speed, scale, keep, quality) and reads the sim's for the rest, so there is one source. The schema is Tools'.

## 4. What it costs and who changes what

| Item | Size | Whose |
| :--- | :--- | :--- |
| `WorldStructures.blowWindows`, the call in `WorldCrater.dig`, the data loader | about 60 lines | World |
| `data/biomes/windows.json`, schema, joins the replay's data hash | one file | World, Tools (schema), Simulation (the data-hash line, as for contact.json) |
| `wmask` on `Building`, one name in `hash.gd`'s `BUILDING` | 2 lines | **Simulation (a grant)** |
| Rendering reads `b.wmask` for the window texture instead of the pruned list (keeping VFX's list for the shock timing) | small | Rendering |
| VFX reads the sim's numbers and skips its own selection (or keeps it if it only draws glass) | small | VFX |
| Goldens | the hash gains the field: **one regeneration, no behaviour change** (the digests move, the results and counts do not) | Simulation, with the slice |

Memory: one integer a building (about 50 buildings today, a few hundred after D1). Per tick: nothing (it runs only at a crater).

## 5. Probe checks and acceptance

- A crater at tier 3 or more with energy at least 8 near a 6-floor building sets rows on that building and only on standing floors; below the gate, nothing; a tier-2 owner, nothing; a building under 3 floors, nothing.
- The record matches VFX's own selection for the same event (the same buildings, the same rows) on 200 seeded craters.
- Two runs of one seed give the same `wmask` everywhere; a state restored from a replay checkpoint and run on equals a straight run (the seek case).
- A fighter's whole-match digest is unchanged except through the new field (a neutral slice: everything else the same).
- Rendering's frame after a seek to the middle of a match shows the same windows out as the straight run at that tick.

## 6. Open points for the EP

1. **Which events blow windows.** Only the crater rule today. Orb's playtest asked for glass on big hits; if the beam's path, a heavy clash or a hard slam should too, they are data rows once the record exists, and VFX decides the glass.
2. **The grant** (two lines in Simulation's state.gd and hash.gd) and the golden regeneration: one commit with the slice.
3. **Who owns the numbers:** I propose the sim's data owns the selection and VFX only the presentation (§3), so the record and the glass cannot drift apart.
