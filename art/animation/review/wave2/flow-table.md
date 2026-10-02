# wave2: the flow table

Each entry's last pose against the wind-up of every wave 1 strike it favours (Combat's `favours`): the mean turn of the eight limb bones in radians. Under 0.8 the join is nearly free, 0.8 to 1.3 it is a visible change the inertialisation smooths, over 1.3 the strike starts from a different shape (the pelvis and spine are the body's orientation, which the sim's rotation carries in flight, so only the limbs are compared).

| Entry | Last pose | Strikes it favours (mean limb turn, rad) |
| :--- | :--- | :--- |
| dash | w2.dash.arrive | jab 0.48, cross 0.59, haymaker 0.63, front_kick 0.71, shoulder_check 0.56, driving_knee 0.57 |
| arc_dive | w2.arc_dive.arrive | hammer 1.35, dropping_elbow 1.06, axe_kick 1.17, stomp 1.06, double_hammer 1.56 |
| rising | w2.rising.arrive | uppercut 0.54, rising_elbow 0.39, rising_knee 0.51, spear_hand 0.65, headbutt 0.43 |
| skid | w2.skid.arrive | sweep 1.13, low_kick 1.28, spear_hand 1.42, rising_knee 1.32 |
| spiral | w2.spiral.arrive | hook 0.49, backfist 0.49, snap_round 0.84, side_kick 0.88, spinning_heel 1.25 |
| coil_spring | w2.coil_spring.arrive | spear_hand 1, twin_spear 1.19, shoulder_check 1.2, body_ram 1.14, driving_knee 1.2, cross_arm_ram 0.86 |
| step_in | w2.step_in.arrive | jab 0.23, cross 0.36, palm_heel 0.23, front_kick 0.86, short_elbow 0.42, short_knee 1.02 |
| pivot | w2.pivot.arrive | hook 0.58, backfist 0.58, snap_round 1.02, roundhouse 1.03, spinning_elbow 1.04, spinning_heel 1.45 |
| plant_coil | w2.plant_coil.arrive | uppercut 1.08, rising_elbow 1.11, spear_hand 1.3, rising_knee 1.07, headbutt 1.38 |
| lane_step | w2.lane_step.arrive | side_kick 0.98, hook 0.55, low_kick 0.86, short_elbow 0.62 |
| rooted | w2.rooted.start | jab 0.46, cross 0.43, palm_heel 0.46, headbutt 0.55, hammer 1.13 |
| backstep_counter | w2.backstep_counter.arrive | cross 0.26, front_kick 0.88, side_kick 0.89, overhand 0.3 |
| fade | w2.fade.arrive | uppercut 0.53, hook 0.32, rising_elbow 0.37, short_knee 1.03, headbutt 0.63 |
| hop_back | w2.hop_back.arrive | front_kick 0.96, side_kick 0.98, axe_kick 1.14 |
| drop_back | w2.drop_back.arrive | sweep 0.52, spear_hand 1.11, rising_knee 0.78, uppercut 0.81 |
