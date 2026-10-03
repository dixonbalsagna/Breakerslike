// The Protagonist's energy poses (docs/combat/launch-pair-movesets.md sections 3.2 and 4; docs/design/agency-pass.md section 15; Legal RL-063 to RL-065): his two hands of
// his own, his charged brace and the curving shot's release. Parked: nothing fires them yet, and the wave loads only with --waves.
//   palm_thrust   an open palm thrust from the shoulder: the arm out, the fingers together and up, the other hand open at his own chest
//   ring_hand     the fingers curled loosely round an arc (the loose half-curl, not a claw), the arm raised and rounded, the other hand low and open
//   brace_load    the charged brace's gather: the feet planted wide, the hands out and apart at his sides, open, the chin level
//   brace_hold    the brace at full charge: one open hand forward at the shoulder, the other low and out behind, still
//   curve_release the curving shot's release: from a still flat palm held out at the chest, never a finger or a sweep of the hand; the stick sets the side
// Legal: hands at least a shoulder width apart or one high and one low, never wrists together, never cupped at either hip, no glow leaving the hand in the pose, no
// sphere forming between the palms, no hands raised overhead holding an orb; no scream, no flame aura, no rubble ring while he channels.
const OPEN = { hands: { r: 'open', l: 'open' } };

export const sequences = {
  // the curving shot: the brace's forward hand comes to a still flat palm at the chest, holds it for the release, and settles
  curve: { dur: 22, legal: ['hands_open_or_claw', 'not_at_hip', 'no_cross_hold'], phases: [
    { id: 'set', ticks: 6, sketch: { family: 'upright', lean: 10, hips: [0, -8, 0], spine: { lean: 4, twist: 14 }, head: { pitch: 0, yaw: 6 }, hand_r: [34, 58, 12], pole_hand_r: [4, 52, 22],
        hand_l: [16, 52, -10], foot_r: [-12, 2.5, 9], foot_l: [14, 2.5, -7], ...OPEN },
      orig: 'setting the shot: the throwing hand coming up to the chest with the palm turned out, the other hand open beside it, the feet planted' },
    { id: 'release', ticks: 6, sketch: { family: 'upright', lean: 12, hips: [2, -8, 0], spine: { lean: 4, twist: 18 }, head: { pitch: 0, yaw: 6 }, hand_r: [40, 60, 12], pole_hand_r: [6, 54, 22],
        hand_l: [14, 50, -10], foot_r: [-12, 2.5, 9], foot_l: [14, 2.5, -7], ...OPEN },
      orig: 'the release: the arm out at the chest with a flat palm held still, the fingers up, nothing swept, the eyes on the shot' },
    { id: 'settle', ticks: 10, from: 'stance.aggressive', over: { lean: 8, head: { pitch: 0, yaw: 6 }, ...OPEN },
      orig: 'dropping back to the stance, the eyes following the shot round' },
  ] },
};

export const holds = {
  palm_thrust: { sketch: { family: 'upright_lunge', lean: 14, hips: [12, -4, 0], spine: { lean: 4, twist: 24 }, head: { pitch: 0, yaw: 4 }, hand_r: [50, 62, 8], pole_hand_r: [-2, 0, 8],
      hand_l: [19, 55, -8], foot_r: [-6, 2.5, 9], foot_l: [20, 2.5, -7], ...OPEN, _legal: ['hands_open_or_claw', 'not_at_hip', 'no_cross_hold'] },
    orig: 'an open palm thrust from the shoulder with the fingers together and up, the other hand open at his own chest, the weight behind the palm' },
  ring_hand: { sketch: { family: 'upright', lean: 10, hips: [4, -6, 0], spine: { lean: 4, twist: 20 }, head: { pitch: -2, yaw: 4 }, hand_r: [40, 72, 10], pole_hand_r: [4, 14, 10],
      hand_l: [12, 46, -10], foot_r: [-10, 2.5, 9], foot_l: [14, 2.5, -7], hands: { r: 'relaxed', l: 'open' }, _legal: ['not_at_hip', 'no_held_raise'] },
    orig: 'the hand raised and rounded with the fingers loosely curled round an arc, the elbow soft, the other hand low and open' },
  brace_load: { sketch: { family: 'upright', lean: 8, hips: [0, -12, 0], spine: { lean: 4 }, head: { pitch: 0 }, hand_r: [16, 44, 24], pole_hand_r: [-2, 30, 28], hand_l: [12, 48, -24], pole_hand_l: [-2, 34, -28],
      foot_r: [-14, 2.5, 11], foot_l: [14, 2.5, -9], ...OPEN, _legal: ['wrists_apart', 'hands_open_or_claw', 'not_at_hip'] },
    orig: 'gathering: the feet planted wide and the knees bent, both open hands out at his sides well apart, the chin level and the shoulders down' },
  brace_hold: { sketch: { family: 'upright', lean: 12, hips: [2, -12, 0], spine: { lean: 4, twist: 14 }, head: { pitch: 0, yaw: 4 }, hand_r: [40, 60, 12], pole_hand_r: [4, 52, 22], hand_l: [-8.3, 23.1, -18.8], pole_hand_l: [-8, 22, -24],
      foot_r: [-14, 2.5, 11], foot_l: [16, 2.5, -9], ...OPEN, _legal: ['wrists_apart', 'hands_open_or_claw', 'not_at_hip'] },
    orig: 'at full charge: one open hand forward at the shoulder, still, the other low and out behind him, the stance wide and steady' },
  curve_release: { sketch: { family: 'upright', lean: 12, hips: [2, -8, 0], spine: { lean: 4, twist: 18 }, head: { pitch: 0, yaw: 6 }, hand_r: [40, 60, 12], pole_hand_r: [6, 54, 22],
      hand_l: [14, 50, -10], foot_r: [-12, 2.5, 9], foot_l: [14, 2.5, -7], ...OPEN, _legal: ['hands_open_or_claw', 'not_at_hip', 'no_cross_hold'] },
    orig: 'the curving shot leaving a still flat palm held out at the chest, the fingers up, nothing swept, the other hand open beside it' },
};

export const cues = {};
