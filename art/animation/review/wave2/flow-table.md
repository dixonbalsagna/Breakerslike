# wave2: the flow table

Each entry's last pose against the wind-up of every wave 1 strike it favours (Combat's `favours`): the mean turn of the eight limb bones in radians. Under 0.8 the join is nearly free, 0.8 to 1.3 it is a visible change the inertialisation smooths, over 1.3 the strike starts from a different shape (the pelvis and spine are the body's orientation, which the sim's rotation carries in flight, so only the limbs are compared).

| Entry | Last pose | Strikes it favours (mean limb turn, rad) |
| :--- | :--- | :--- |
| dash | w2.dash.arrive | jab 0.49, cross 0.6, haymaker 0.62, front_kick 0.71, shoulder_check 0.56, driving_knee 0.63 |
| arc_dive | w2.arc_dive.arrive | hammer 1.48, dropping_elbow 1.15, axe_kick 1.73, stomp 1.43, double_hammer 1.5 |
| rising | w2.rising.arrive | uppercut 0.54, rising_elbow 0.39, rising_knee 0.51, spear_hand 0.65, headbutt 0.43 |
| skid | w2.skid.arrive | sweep 1.07, low_kick 1.3, spear_hand 1.49, rising_knee 1.34 |
| spiral | w2.spiral.arrive | hook 0.55, backfist 0.55, snap_round 1.04, side_kick 0.98, spinning_heel 1.35 |
| coil_spring | w2.coil_spring.arrive | spear_hand 0.98, twin_spear 1.17, shoulder_check 1.23, body_ram 1.12, driving_knee 1.18, cross_arm_ram 0.82 |
| step_in | w2.step_in.arrive | jab 0.24, cross 0.37, palm_heel 0.24, front_kick 0.85, short_elbow 0.42, short_knee 1.02 |
| pivot | w2.pivot.arrive | hook 0.58, backfist 0.58, snap_round 1.11, roundhouse 1.02, spinning_elbow 1.04, spinning_heel 1.45 |
| plant_coil | w2.plant_coil.arrive | uppercut 1.1, rising_elbow 1.15, spear_hand 1.19, rising_knee 1.08, headbutt 1.39 |
| lane_step | w2.lane_step.arrive | side_kick 0.99, hook 0.55, low_kick 0.86, short_elbow 0.62 |
| rooted | w2.rooted.start | jab 0.47, cross 0.43, palm_heel 0.47, headbutt 0.55, hammer 1.1 |
| backstep_counter | w2.backstep_counter.arrive | cross 0.27, front_kick 0.88, side_kick 0.89, overhand 0.32 |
| fade | w2.fade.arrive | uppercut 0.53, hook 0.32, rising_elbow 0.37, short_knee 1.03, headbutt 0.63 |
| hop_back | w2.hop_back.arrive | front_kick 0.96, side_kick 0.99, axe_kick 1.21 |
| drop_back | w2.drop_back.arrive | sweep 0.51, spear_hand 1.16, rising_knee 0.81, uppercut 0.84 |
