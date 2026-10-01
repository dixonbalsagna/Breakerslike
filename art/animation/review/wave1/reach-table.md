# wave1: the reach table

Measured by `strike_lab.gd --measure --sweep`: each strike played against a dummy defender at every distance from 20 to 98 u. **Hips alone** is the farthest distance the blow lands at with the pose's own lunge and no step-in; **with step-in** adds the contact solve's whole-body slide (the limb's `step_max` or the key set's). **Clear from** is the nearest distance at which no other part of the body passes more than 6 u into the defender. Combat's rule (docs/combat/pending/wave1-strikes.md section 3) is that a strike's contact distance is its reach minus the step, so the blow lands with the hip lunge alone: the verdict column checks it.

| Strike | Combat contact | Combat reach | Hips alone | With step-in | Clear from | Verdict |
| :--- | ---: | ---: | ---: | ---: | ---: | :--- |
| jab | 58 | 72 | 76 | 98 | 44 | lands on the hips alone |
| cross | 58 | 74 | 86 | 98 | 48 | lands on the hips alone |
| hook | 58 | 72 | 76 | 98 | 44 | lands on the hips alone |
| backfist | 58 | 72 | 74 | 88 | 40 | lands on the hips alone |
| palm_heel | 58 | 74 | 84 | 98 | 46 | lands on the hips alone |
| spear_hand | 52 | 66 | 84 | 98 | 40 | lands on the hips alone |
| uppercut | 58 | 72 | 58 | 98 | 38 | lands on the hips alone |
| hammer | 58 | 72 | 56 | 86 | 44 | needs a step-in of 2 u |
| overhand | 58 | 72 | 62 | 86 | 46 | lands on the hips alone |
| haymaker | 58 | 72 | 62 | 98 | 42 | lands on the hips alone |
| short_elbow | 34 | 46 | 44 | 64 | 26 | lands on the hips alone |
| rising_elbow | 34 | 46 | 44 | 64 | 24 | lands on the hips alone |
| spinning_elbow | 34 | 46 | 34 | 62 | 30 | lands on the hips alone |
| dropping_elbow | 38 | 50 | 40 | 72 | 28 | lands on the hips alone |
| twin_spear | 52 | 66 | 80 | 98 | 44 | lands on the hips alone |
| double_palm | 52 | 66 | 68 | 98 | 40 | lands on the hips alone |
| double_hammer | 50 | 64 | 60 | 84 | 44 | lands on the hips alone |
| cross_arm_ram | 38 | 50 | 46 | 70 | 28 | lands on the hips alone |
| front_kick | 54 | 64 | 64 | 82 | 40 | lands on the hips alone |
| side_kick | 50 | 60 | 56 | 70 | 34 | lands on the hips alone |
| low_kick | 50 | 60 | 64 | 76 | 34 | lands on the hips alone |
| snap_round | 50 | 60 | 58 | 72 | 36 | lands on the hips alone |
| roundhouse | 50 | 60 | 50 | 78 | 40 | lands on the hips alone |
| axe_kick | 50 | 60 | 48 | 66 | 26 | needs a step-in of 2 u |
| spinning_heel | 50 | 60 | 50 | 70 | 22 | lands on the hips alone |
| stomp | 54 | 64 | 58 | 76 | 30 | lands on the hips alone |
| sweep | 50 | 60 | 52 | 72 | 36 | lands on the hips alone |
| drop_kick | 50 | 60 | 50 | 64 | 20 | lands on the hips alone |
| short_knee | 32 | 42 | 28 | 48 | 22 | needs a step-in of 4 u |
| rising_knee | 32 | 42 | 32 | 54 | 20 | lands on the hips alone |
| driving_knee | 32 | 42 | 28 | 54 | 20 | needs a step-in of 4 u |
| headbutt | 34 | 44 | 38 | 58 | 34 | lands on the hips alone |
| shoulder_check | 34 | 44 | 42 | 60 | 26 | lands on the hips alone |
| body_ram | 34 | 44 | 42 | 68 | 24 | lands on the hips alone |
