# Terrain deformation audit (Orb's playtest 8: "weird unexpected behaviour")

Owner: World and Environment. Status: findings and proposed fixes, docs only (2026-09-30). No sim edits; the fixes land in my next window. Tool: `sim/world/tools/terrain_audit.gd` (`godot --headless --path . --script res://sim/world/tools/terrain_audit.gd -- <firstSeed> <count> <everyTicks>`): it plays AI-vs-AI matches and, every N ticks and at the KO, scans the ground, water and buildings for steep new steps, isolated spikes and pits, clamped deformation, water that does not meet itself, buildings on tilted ground and fighters inside the ground. 12 matches (seeds 1 to 12, 6 to 8 snapshots each) were played.

## What the numbers say

| Thing Orb could be seeing | Result over 12 matches | Verdict |
| :--- | :--- | :--- |
| Rubble walls: steep steps between neighbouring columns (over 1 bh) | 0 to 3 early; **20 to 43 in a match that has levelled its downtown** (seed 1: 43, seed 5: 21 to 30, seed 4: 22); worst step 390 to 492 units (5 to 6 bh) between adjacent 32-unit columns | **Main cause** |
| Buildings on tilted ground (ground varying over half a bh across a standing building's footprint) | 0 to 2 early, **10 to 40 in a late match** (up to 252 units, 3.3 bh, across one building) | **Main cause** (a building floats at one edge or is half buried) |
| Shafts: single-column pits inside raised ground | 0 to 4 a match; seed 1 has a column at ground level (-26) inside a 372 to 450 unit heap; seed 12 has a -385 column beside -150 neighbours | Real, rare, ugly |
| Spikes and W-shaped bowls | 0 to 4 a match, 35 to 63 units tall | Minor |
| Clamped (flat-topped) deformation | 0 columns at `DEFORM_CEIL` or `DEFORM_FLOOR` in any snapshot | Not an issue |
| Water: holes in the lake, perched pools, cliffs between wet columns | 0 holes, 0 perched; 1 transient cliff (163 against 108) while a settling window was open | **Clean** |
| Fighters inside the ground | 1 sample in about 80 | Transient |

So the water model and the crater law are behaving; the weirdness is **rubble** and **trenches carved through raised ground**, plus buildings that do not follow either.

## Causes (read from `structures.gd` and `crater.gd`)

1. **Rubble heaps are walls, and they stack across depth rows.** `_heap` adds `H * (1 - u^2)^2` over a base of `2 * 0.6 * w`, with `H = 0.10 * h` clamped to 0.5 to 6 bh. A downtown tower of 100 bh leaves a heap 6 bh (450 units) tall on a base 1.2 widths across: a slope of about 2 to 1. The heap is added to `S.deform`, which is **one heightfield for the whole planet**, and `_heap` never looks at the building's depth row. Rows 1, 2 and 3 are 18 to 46 bh apart in depth but share x, so three collapsed towers at the same x stack three heaps on **the fighter plane**: a 12 bh wall (the ceiling `DEFORM_CEIL` is 12.8 bh) that appears there because of buildings 38 bh behind it. Seed 1's profile at x 43,968: eleven columns at 370 to 450 units, a flat-topped rubble plateau.
2. **Beam grooves and slide trenches use an absolute target.** `scorch` and `carveSegment` set `deform = -depth` wherever `-depth < deform`. On flat ground that is a groove; on a rim, a heap or an apron (deform above 0) it replaces a 400 unit mound with a shaft down to the original ground in one step. That is the "-26 inside 372 and 348" column in seed 1.
3. **A building's footing ignores its footprint.** `groundY(S, b.x)` is read at the centre, so a heap or a rim that raises one side of a standing building tilts nothing in the sim but leaves it half buried or hanging over a hollow (and the brunt's hit window uses that centre ground). Rendering draws footings from the highest ground under the footprint, so the sim and the picture can disagree by up to 3 bh.
4. **No slope limit anywhere.** Nothing relaxes a column that is steeper than loose material could be; every bowl, rim, heap and groove is written exactly and stays exactly.

## Fixes (proposed; one golden regeneration, in my next sim window)

| Fix | What | Cost | Effect |
| :--- | :--- | :--- | :--- |
| **T1 Heaps only where the fighters are** | A collapsed building deposits a sim heap only if its row is 0 or 1 (within `Z_REACH` of the fighter plane); deeper rows keep their cosmetic heap (the `building_fall.rubble` event already carries it, Rendering draws it at the row's depth). Heap shape: base `1.6 w` instead of `1.2 w`, crest 0.06 h (cap 4 bh) so the slope is at most 1 to 1. The heap skips columns under standing buildings. | A few lines in `_heap`; no new state | Removes the stacked plateau and the walls at the plane; buildings keep dry footings |
| **T2 Angle of repose** | After any deform change (heap, rim, bowl, groove, trench), run a bounded relaxation over the touched window: where the step between neighbouring columns exceeds `REPOSE` (1 bh per 32-unit column, a 67 degree slope) move the excess to the lower neighbour, a fixed number of passes, volume conserving, rubble and deform adjusted together. Deterministic, windowed like the water. | One pass per event over at most a few hundred columns; the tick is unchanged (it runs inside the dig, not per tick); a new constant block and a probe | Kills spikes, pits and walls from every source, including future ones |
| **T3 Carve relative to the natural ground** | `scorch` and `carveSegment` take their target from the column's natural ground (`deform - rubble`) minus the groove, so a groove clears the heap down to the ground and no further and never cuts a shaft below it; T2 softens the cut face | A line in each function | No shafts in heaps or rims |
| **T4 Footings take the highest ground under the footprint** | A building's base is the highest ground over its footprint (as Rendering draws it), in `curH`, brunt hit height and `flightTo`'s top; a building whose footprint is buried by more than 0.5 bh is damaged by the burial | `curH` and one helper; Rendering already agrees | Sim and picture agree; no floating or half-buried towers |

Order: T1 and T3 are tiny and certain. T2 is the real cure and the part with a tuning cost (the repose constant decides how soft the crater rims look; I would keep the rim crest exact and relax only below it). T4 needs Rendering to confirm their footing rule. Probe checks to add: no step over `REPOSE` after any dig, heap or groove (1000 random events on flat, rim and heap ground), no deform column below the natural ground inside a heap, volume conserved by the relaxation, no standing building with ground varying by more than 0.5 bh across its footprint, the rubble sum unchanged by the relaxation. The audit tool is the acceptance run: the late-match counts of steep steps, shafts and tilted buildings go to zero.

## What I did not find

Water oddities (no holes, no perched pools, no stuck windows), clamped deformation, or fighters buried by terrain. If Orb saw water weirdness it is Rendering's drawn shore (their diagnosis in the fixes slice) rather than the sim's state. A screenshot or a seed and tick from Orb's play would pin down anything the audit does not show; the audit's worst-case lines print the x and the tick.
