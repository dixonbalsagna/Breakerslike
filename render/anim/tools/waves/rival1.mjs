// The rival's (the Anti-hero's) launch pieces that are poses, not strikes (docs/combat/launch-pair-movesets.md sections 2, 5 and 6; docs/combat/alchemist-recipes.md section 2.4;
// docs/combat/pending/wave6-energy.md; Legal RL-063 to RL-065). Parked: nothing fires them yet, and the wave loads only with --waves.
//   On the Chin    on_the_chin (plant, lift, done), chin_beam (beam in, beam out, bravado): his arms open a little forward of the body line and slightly below shoulder height
//                  (never a flat cross, never behind him), the chin level or lifted a few degrees (never thrown back), eyes open, no scream, no aura, no rubble ring
//   Blow for Blow  hold bfb_brace: his own brace (the forearm plates tight against his ribs); the arms-open stance is never used there
//   the finisher   fin_walk, fin_stop, fin_held (his base finisher, by hand)
//   the barrage    the six emitting hands (open palm, pinch, clawed palm, fist glow, blade hand, crossed forearms), the channel's charge and release (the charged brace), the kiting turn
//   rain           the upward throw: one arm, never both hands raised overhead
// Legal's lines: hands open or claw (never a pointing finger), never at the hip, hands a shoulder width apart or one high and one low on a channel, nothing held crossed.
const OPEN = { hands: { r: 'open', l: 'open' } };
const WIDE = { foot_r: [-14, 2.5, 10], foot_l: [14, 2.5, -9] };

export const sequences = {
  // the plant, one acknowledged hit, and the absorb completed
  on_the_chin: { dur: 36, legal: ['hands_open_or_claw', 'wrists_apart'], phases: [
    { id: 'plant', ticks: 12, sketch: { family: 'upright', lean: 2, hips: [0, -6, 0], spine: { lean: 0 }, head: { pitch: 0 }, hand_r: [14, 50, 26], hand_l: [14, 50, -26], ...WIDE, ...OPEN },
      orig: 'planting: the feet set wide with the front knee bent, the arms open a little forward and slightly below the shoulders, the palms open, the chin level and the eyes on the rival; he stands tall' },
    { id: 'lift', ticks: 6, sketch: { family: 'upright', lean: 2, hips: [0, -6, 0], spine: { lean: 0 }, head: { pitch: -5 }, hand_r: [14, 50, 26], hand_l: [14, 50, -26], ...WIDE, ...OPEN },
      orig: 'the acknowledgement: the same stance, the chin lifted a few degrees, never thrown back' },
    { id: 'done', ticks: 18, sketch: { family: 'upright', lean: 2, hips: [0, -4, 0], spine: { lean: 0, twist: 8 }, head: { pitch: 2 }, hand_r: [18, 34, 20], hand_l: [18, 34, -20], foot_r: [-10, 2.5, 9], foot_l: [10, 2.5, -8], ...OPEN },
      orig: 'done with it: the arms coming down and the shoulders rolling, the stance easing' },
  ] },
  // a signature absorbed: the beam breaks on his chest, smoke, one line of bravado
  chin_beam: { dur: 90, legal: ['hands_open_or_claw', 'wrists_apart'], phases: [
    { id: 'beam_in', ticks: 30, sketch: { family: 'upright', lean: 12, hips: [4, -8, 0], spine: { lean: 8 }, head: { pitch: 4 }, hand_r: [14, 50, 26], hand_l: [14, 50, -26], foot_r: [-14, 2.5, 10], foot_l: [16, 2.5, -9], ...OPEN },
      orig: 'braced into the beam: the chest forward, the arms still open, the feet wide, the spine inside its range' },
    { id: 'beam_out', ticks: 30, sketch: { family: 'upright', lean: 2, hips: [0, -6, 0], spine: { lean: 0 }, head: { pitch: 4 }, hand_r: [12, 44, 24], hand_l: [12, 44, -24], ...WIDE, ...OPEN },
      orig: 'upright again with the plates smoking, the arms a little lower' },
    { id: 'bravado', ticks: 30, sketch: { family: 'upright', lean: 2, hips: [0, -6, 0], spine: { lean: 0, twist: 10 }, head: { pitch: -3, yaw: 22 }, hand_r: [16, 52, 26], hand_l: [12, 32, -20], ...WIDE, ...OPEN },
      orig: 'the head turned to the rival for his one line, one arm still out and the other lowered' },
  ] },
};

export const holds = {
  // ---- Blow for Blow
  bfb_brace: { sketch: { family: 'upright', lean: -4, hips: [-2, -6, 0], spine: { lean: 0, twist: -10 }, head: { pitch: 6, yaw: 8 }, hand_r: [14, 52, 12], pole_hand_r: [-4, 40, 16], hand_l: [12, 50, -10], pole_hand_l: [-4, 38, -14],
      foot_r: [-12, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN, _legal: ['no_cross_hold'] },
    orig: 'his own brace: both forearm plates drawn tight against his ribs, the lead shoulder rolled forward and the chin behind it, the spine upright, giving ground on his heels without folding' },
  // ---- the base finisher, by hand
  fin_walk: { sketch: { family: 'upright', lean: 2, hips: [0, -2, 0], spine: { lean: 0 }, head: { pitch: 2 }, hand_r: [18, 38, 18], hand_l: [16, 38, -18], foot_r: [-8, 2.5, 8], foot_l: [8, 2.5, -7], ...OPEN, _legal: ['hands_open_or_claw'] },
    orig: 'the slow walk in: upright and unhurried, the hands open and low at his sides' },
  fin_stop: { sketch: { family: 'upright', lean: 4, hips: [0, -4, 0], spine: { lean: 2 }, head: { pitch: 20 }, hand_r: [18, 36, 18], hand_l: [16, 36, -18], foot_r: [-6, 2.5, 9], foot_l: [10, 2.5, -7], ...OPEN, _legal: ['hands_open_or_claw'] },
    orig: 'standing over the rival, looking down at him, the hands open and low, the weight settled' },
  fin_held: { sketch: { family: 'upright', lean: 0, hip_twist: 40, hips: [0, -2, 0], spine: { lean: 0, twist: -20 }, head: { pitch: 6, yaw: -30 }, hand_r: [14, 30, 18], hand_l: [8, 36, -14], foot_r: [-8, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN, _legal: ['hands_open_or_claw'] },
    orig: 'after the last blow: turned half away, the head turned, the striking arm lowered, done with him' },
  // ---- the barrage: the six emitting hands, each at the moment the shot leaves
  hand_open_palm: { sketch: { family: 'upright_lunge', lean: 10, hips: [10, -4, 0], spine: { lean: 4, twist: 16 }, head: { pitch: 2, yaw: 4 }, hand_r: [46, 60, 10], pole_hand_r: [-2, 0, 8], hand_l: [16, 52, -8],
      foot_r: [-6, 2.5, 9], foot_l: [20, 2.5, -7], ...OPEN, _legal: ['hands_open_or_claw', 'not_at_hip'] },
    orig: 'the open palm: flat with the fingers together, the arm out at chest height, the other hand open at his chest; never at the hip' },
  hand_pinch: { sketch: { family: 'upright_lunge', lean: 8, hips: [8, -4, 0], spine: { lean: 4, twist: 14 }, head: { pitch: 2, yaw: 4 }, hand_r: [34, 62, 12], pole_hand_r: [2, 2, 14], hand_l: [16, 52, -8],
      foot_r: [-6, 2.5, 9], foot_l: [18, 2.5, -7], hands: { r: 'relaxed', l: 'open' }, _legal: ['not_at_hip'] },
    orig: 'the pinch: the thumb and forefinger drawn lightly together as the dart leaves, the elbow bent, no pointing finger' },
  hand_clawed_palm: { sketch: { family: 'upright_lunge', lean: 10, hips: [10, -4, 0], spine: { lean: 4, twist: 16 }, head: { pitch: 2, yaw: 4 }, hand_r: [48, 64, 10], pole_hand_r: [-2, 0, 8], hand_l: [16, 52, -8],
      foot_r: [-6, 2.5, 9], foot_l: [20, 2.5, -7], hands: { r: 'claw', l: 'open' }, _legal: ['hands_open_or_claw', 'not_at_hip'] },
    orig: 'the clawed palm: the fingers spread like tines, the wrist bent back, the arm out at chest height' },
  hand_fist_glow: { sketch: { family: 'upright_lunge', lean: 10, hips: [10, -4, 0], spine: { lean: 4, twist: 16 }, head: { pitch: 2, yaw: 4 }, hand_r: [29, 62, 10], pole_hand_r: [-2, 4, 8], hand_l: [16, 52, -8],
      foot_r: [-6, 2.5, 9], foot_l: [20, 2.5, -7], hands: { r: 'fist', l: 'open' }, _legal: ['no_fist_punched_ahead'] },
    orig: 'the glowing fist: a closed fist held at chest height with the forearm plate lit along its edge (the light is VFX), the arm not fully out' },
  hand_blade_hand: { sketch: { family: 'upright_lunge', lean: 10, hips: [10, -4, 0], spine: { lean: 4, twist: 16 }, head: { pitch: 2, yaw: 4 }, hand_r: [44, 60, 10], pole_hand_r: [-2, 0, 8], hand_l: [16, 52, -8],
      foot_r: [-6, 2.5, 9], foot_l: [20, 2.5, -7], ...OPEN, _legal: ['hands_open_or_claw', 'not_at_hip'] },
    orig: 'the blade hand: a flat knife hand held edge on, the darts running off the edge, never a pointed finger' },
  // crossed forearms, in motion only: the moment the two guards meet on the way to a blow, never held
  hand_crossed_forearms: { sketch: { family: 'upright_lunge', lean: 14, hips: [10, -4, 0], spine: { lean: 6 }, head: { pitch: 8 }, hand_r: [30, 62, -2], pole_hand_r: [6, 6, 12], hand_l: [30, 58, 6], pole_hand_l: [6, 2, -12],
      foot_r: [-6, 2.5, 9], foot_l: [20, 2.5, -7], ...OPEN, _note: 'in motion only: the moment the guards meet on the way to a blow; never a held pose' },
    orig: 'the forearm guards brought together plates outward for a moment on the way to a blow, the head tucked behind them' },
  // ---- the channel (his charged brace): one forearm high and one low across a body-length gap, torn apart to release
  channel_charge: { sketch: { family: 'crouched', lean: 12, hips: [0, -12, 0], spine: { lean: 8 }, head: { pitch: 4 }, hand_r: [24, 80, 10], pole_hand_r: [4, 70, 18], hand_l: [23, 20, -10], pole_hand_l: [4, 22, -16],
      foot_r: [-14, 2.5, 10], foot_l: [14, 2.5, -9], ...OPEN, _legal: ['wrists_apart', 'hands_open_or_claw', 'not_at_hip'] },
    orig: 'the charge: one forearm high and one low, the plates facing each other across a body-length gap, the stance wide and low, nothing between the hands' },
  channel_release: { sketch: { family: 'crouched', lean: 14, hips: [2, -12, 0], spine: { lean: 8, twist: 12 }, head: { pitch: 2 }, hand_r: [12, 80.4, 19], pole_hand_r: [-4, 70, 24], hand_l: [25, 21, -14], pole_hand_l: [10, 20, -20],
      foot_r: [-14, 2.5, 10], foot_l: [16, 2.5, -9], ...OPEN, _legal: ['wrists_apart', 'hands_open_or_claw', 'not_at_hip'] },
    orig: 'the release: the arms torn apart, one up and back and one low and out ahead, the lance leaving along the line between them' },
  // ---- the kiting turn and the rain's throw
  kiting_turn: { sketch: { family: 'upright', lean: -6, hip_twist: 50, hips: [-2, -4, 0], spine: { lean: -2, twist: -40 }, head: { pitch: 2, yaw: -50 }, hand_r: [-18, 56, 18], hand_l: [14, 50, -8],
      foot_r: [-12, 2.5, 8], foot_l: [10, 2.5, -7], hands: { r: 'relaxed', l: 'open' }, _legal: ['not_both_arms_back'] },
    orig: 'already leaving: turned three-quarters away and looking back over the shoulder, one hand flicking a dart behind him, the other open at his side' },
  rain_throw: { sketch: { family: 'upright', lean: -8, hips: [-2, -4, 0], spine: { lean: -6, twist: 14 }, head: { pitch: -10 }, hand_r: [22.6, 79, 9.7], pole_hand_r: [2, 66, 20], hand_l: [6, 40, -14],
      foot_r: [-12, 2.5, 9], foot_l: [10, 2.5, -7], ...OPEN, _legal: ['hands_open_or_claw'] },
    orig: 'the upward throw: one arm thrown up and forward with the plates lit, the other hand low, the head back to follow the shot; never both hands overhead' },
};

export const cues = {};
