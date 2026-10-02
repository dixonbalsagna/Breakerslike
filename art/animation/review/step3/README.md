# step3: the pack for Orb

Machine pass first (see exceptions.md): **0 errors, 0 for review, 11 notes** over 32 poses of 10 sequences. Then what Orb sees:

1. **The reel** `step3-reel.gif`: each of Encounter's step 3 cue events in turn (perfect block, reversal, dodge-cancel, burst, burst absorbed), sent through the real solver; the fighter who does it is on the right, the one it happens to on the left.
2. **The sheet** `step3-sheet.png`: three frames of each.
3. **The exceptions** `exceptions.md` and `timing.md` (each sequence as long as the sim state it dresses).
4. **3 A/B pairs**, each a choice between two versions, to be answered with a letter:

   - `ab-perfect_block.gif`: A is the perfect block as drawn; B is "the deflect swept low, from the hip up".
   - `ab-stagger_blocked.gif`: A is the stagger blocked as drawn; B is "folded forward over the blow instead of thrown back".
   - `ab-burst.gif`: A is the burst as drawn; B is "the arms thrown forward instead of wide".

## What changed since the first pack (2026-10-02)

This pack was rebuilt on the rig with joint limits (docs/animation/joint-limits.md): no knee or elbow can be bent past its end or the wrong way, from any source. **Orb's earlier letters refer to the old look; answer these on what is shown here.**

- **What moved:** nothing visible: the step 3 sequences were already inside every limit. The reel is rebuilt so the rest of the frame (the other fighter's poses and the ragdoll) matches what ships.
