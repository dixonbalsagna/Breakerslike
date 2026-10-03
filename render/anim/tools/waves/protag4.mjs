// The Protagonist's finisher, the flight version (docs/combat/launch-pair-movesets.md section 6.2; docs/design/launch-pair-plan.md section 8; Legal RL-063 to RL-065).
// Parked (--waves). Four poses: his arrival at each side of the loser, the gather above him, the blast, the held pose as the smoke clears.
// Legal: he is drawn the whole way, no vanish and no afterimage that hides him. The blast is one hand: never a two-hand push from the chest, never a sphere growing in a palm,
// never hands at a hip. No roar. The flurry's strikes are his own (protag1); `turn` is the arrival between them.
const OPEN = { hands: { r: 'open', l: 'open' } };

export const holds = {
  turn: { sketch: { family: 'airborne_neutral', lean: 10, hips: [6, 4, 0], spine: { lean: 4, twist: 30 }, head: { pitch: 4, yaw: 6 }, hand_r: [14, 58, 16], pole_hand_r: [-4, 50, 22], hand_l: [26, 56, -8],
      foot_r: [4, 24, 6], foot_l: [-4, 20, -6], ...OPEN, _legal: ['hands_open_or_claw', 'not_at_hip'] },
    orig: 'arriving at a new side of the loser: turned to him in the air, the striking arm loaded and open, the other hand forward, the whole of him in sight' },
  gather: { sketch: { family: 'airborne_neutral', lean: 4, hips: [0, 6, 0], spine: { lean: 2 }, head: { pitch: 16 }, hand_r: [21.4, 48.6, 23.6], pole_hand_r: [-2, 34, 28], hand_l: [23.3, 50.6, -23.6], pole_hand_l: [-2, 36, -28],
      foot_r: [2, 22, 7], foot_l: [-2, 20, -7], ...OPEN, _legal: ['wrists_apart', 'hands_open_or_claw', 'not_at_hip'] },
    orig: 'above the loser: upright in the air with both open hands out and well apart at his sides, the head bowed to look down at him, nothing between the hands' },
  blast: { sketch: { family: 'airborne_neutral', lean: 24, hips: [6, 2, 0], spine: { lean: 10, twist: 22 }, head: { pitch: 20 }, hand_r: [40, 40, 8], pole_hand_r: [6, 36, 14], hand_l: [-14, 56, -16],
      foot_r: [-14, 20, 6], foot_l: [-18, 18, -6], ...OPEN, _legal: ['hands_open_or_claw', 'not_at_hip'] },
    orig: 'the blast at point blank: one open hand thrust from the shoulder down toward the loser, the other open behind him for balance, the body leaning into it' },
  after: { sketch: { family: 'airborne_neutral', lean: -4, hips: [0, 4, 0], spine: { lean: -2 }, head: { pitch: 8 }, hand_r: [16, 37, 15], hand_l: [16, 42, -12],
      foot_r: [2, 22, 6], foot_l: [-2, 20, -6], ...OPEN, _legal: ['hands_open_or_claw', 'not_at_hip'] },
    orig: 'as the smoke clears: upright in the air, the throwing arm lowered, the head bowed, still' },
};

// the four poses as one run, for the review reel: an arrival, the gather above him, the blast, the smoke clearing
export const sequences = {
  finisher: { dur: 78, legal: ['hands_open_or_claw'], phases: [
    { id: 'turn', ticks: 14, sketch: holds.turn.sketch, orig: holds.turn.orig },
    { id: 'gather', ticks: 22, sketch: holds.gather.sketch, orig: holds.gather.orig },
    { id: 'blast', ticks: 10, sketch: holds.blast.sketch, orig: holds.blast.orig },
    { id: 'after', ticks: 32, sketch: holds.after.sketch, orig: holds.after.orig },
  ] },
};

export const cues = {};
