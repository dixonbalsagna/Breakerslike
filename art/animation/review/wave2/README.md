# wave2: the pack for Orb

Machine pass first (see exceptions.md): **0 errors, 2 for review, 19 notes** over 62 poses of 15 entries. Then what Orb sees:

1. **The reel** `wave2-reel.gif`: every entry, in order, played into the strike it favours, against a dummy defender. The lab moves him along a simple path (the sim owns the real one) and compresses the distance: a real rush covers 650 to 1,700 u, the reel shows 170.
2. **The sheet** `wave2-sheet.png`: three frames of each entry (the start, the middle, the arrival).
3. **The exceptions** `exceptions.md` and `exceptions-sheet.png`; and `flow-table.md`, how each arrival flows into the wind-ups of the strikes it favours.
4. **5 A/B pairs**, each a choice between two versions of one entry, to be answered with a letter:

   - `ab-dash.gif`: A is the entry as drawn; B is "the shoulder rolled lower, the guard tucked tight".
   - `ab-arc_dive.gif`: A is the entry as drawn; B is "tucked at the top, the knees drawn to the chest".
   - `ab-skid.gif`: A is the entry as drawn; B is "sitting further back, the free leg higher".
   - `ab-spiral.gif`: A is the entry as drawn; B is "a steeper bank, the lead arm trailing".
   - `ab-plant_coil.gif`: A is the entry as drawn; B is "the eyes level on the rival, the spine straighter".

## What changed since the first pack (2026-10-02)

This pack was rebuilt on the rig with joint limits (docs/animation/joint-limits.md): no knee or elbow can be bent past its end or the wrong way, from any source. **Orb's earlier letters refer to the old look; answer these on what is shown here.**

- **What moved:** the entries are the same sketches; the poses changed where an arm or a leg was past a limit. Most visible: the dash and skid arms, the arc dive's arrival, the skid's sitting leg (legal knees and hips), and the spiral's lead arm. The B variants are the same idea at a different amount.
- **For review (2 rows):** `w2.skid~b.slide` and `w2.coil_spring.start` each put a foot under the floor by 2 and 0.5 units (the sitting pose reaches the floor a little further than a hip can).
