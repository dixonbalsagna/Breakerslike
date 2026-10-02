# wave1: the pack for Orb

Machine pass first (see exceptions.md): **0 errors, 13 for review, 78 notes** over 120 poses of 34 strikes. Then what Orb sees:

1. **The reel** `wave1-reel.gif`: every strike, in order, against a dummy defender standing at the strike's own contact distance (the label gives the strike, the distance and its weight).
2. **The contact sheet** `wave1-contact-sheet.png`: the contact frame of every strike, one tile each, for a still look.
3. **The exceptions** `exceptions.md` and, when there are flagged poses, `exceptions-sheet.png`; and `reach-table.md`, the reach of every strike measured against the contact distances in the Combat rows.
4. **6 A/B pairs**, each a choice between two versions of one strike, to be answered with a letter:

   - `ab-backfist-wind-up.gif`: A is the generic wind-up of its limb, B its own family's (hand_arc).
   - `ab-uppercut.gif`: A is the strike as drawn; B is "upright and open-chested".
   - `ab-double_palm.gif`: A is the strike as drawn; B is "elbows in".
   - `ab-roundhouse.gif`: A is the strike as drawn; B is "guard stays up".
   - `ab-axe_kick.gif`: A is the strike as drawn; B is "leaning back, arms wide".
   - `ab-headbutt.gif`: A is the strike as drawn; B is "hands pulled back".

## What changed since the first pack (2026-10-02)

This pack was rebuilt on the rig with joint limits (docs/animation/joint-limits.md): no knee or elbow can be bent past its end or the wrong way, from any source. **Orb's earlier letters refer to the old look; answer these on what is shown here.**

- **What moved:** the poses are the same sketches, but where a bone was past its limit the baked pose changed. The kicks are the visible case: in the roundhouse, snap round, axe kick, stomp and low kick chambers the knee now folds the right way (the shin hangs from the knee; before, it pointed back and up). Rear hands that were authored behind their own shoulder (the jab, cross, hook, haymaker, palm heel, uppercut) are re-aimed in `data/anim/targets.json` so the elbow stays low in the guard instead of going high; the striking limb of a blow is never changed.
- **Reach, for review (13 rows, was 0):** nine rows are chamber and wind-up targets of the striking limb (the hook, haymaker, twin spear hands; the snap round, roundhouse, stomp feet) that a legal bend cannot reach as authored: the chamber ends 5 to 10 units lower or closer than the data says. Combat's contact reach is untouched; if a higher chamber is wanted, the pose has to change (a different hip angle or a longer approach), not the limit. The four strike lab rows (a neck or spine into the defender's head at 28 to 38 units) are as before the limits.
- **A/B pairs:** the A and B of the roundhouse and axe kick now both have legal knees; the headbutt, double palm and uppercut pairs differ only in the rear hand.
