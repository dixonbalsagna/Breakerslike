// Poses both fighters of the launch pair share and nothing posed yet (the coverage audit, docs/animation/launch-pair-coverage.md): the two checks and the clash's recoil of
// Combat's brawl templates (docs/combat/pending/templates.brawl.json: trade.check_and_reply, the clash recoil). Parked (--waves). Legal: the stacking rule, no crossed arms held.
const OPEN = { hands: { r: 'open', l: 'open' } };

export const holds = {
  // a blow stopped on the forearm: the arm raised and the plate turned out to meet it, the other hand back, the weight set
  check_forearm: { sketch: { family: 'upright', lean: -4, hips: [-4, -6, 0], spine: { lean: -2, twist: 10 }, head: { pitch: 6 }, hand_r: [22, 64, 14], pole_hand_r: [2, 58, 22], hand_l: [12, 52, -8],
      foot_r: [-12, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN, _legal: ['hands_open_or_claw', 'no_cross_hold'] },
    orig: 'checking a blow on the forearm: the near arm raised with the plate turned out to meet it, the elbow bent, the other hand back at his chest, the weight set on the rear foot' },
  // a kick stopped on the shin: the knee raised and the shin turned out
  check_shin: { sketch: { family: 'upright', lean: 4, hips: [2, -4, 0], spine: { lean: 4, twist: 8 }, head: { pitch: 6 }, hand_r: [14, 56, 12], hand_l: [18, 54, -8],
      foot_r: [18, 22, 8], foot_l: [4, 2.5, -7], ...OPEN, _legal: ['hands_open_or_claw'] },
    orig: 'checking a kick on the shin: the near knee lifted and the shin turned out to meet it, the hands up, the standing leg firm' },
  // two limbs meeting: both thrown back by it, the arms out a little
  clash_recoil: { sketch: { family: 'upright', lean: -12, hips: [-6, -6, 0], spine: { lean: -8, twist: 6 }, head: { pitch: -2 }, hand_r: [8, 56, 20], hand_l: [4, 54, -18],
      foot_r: [-16, 2.5, 9], foot_l: [4, 2.5, -8], ...OPEN, _legal: ['hands_open_or_claw', 'not_at_hip'] },
    orig: 'thrown back by a clash of limb on limb: the weight on the heels, the arms out a little for balance, the head level' },
};

// the clash run: the recoil and back to the stance
export const sequences = {
  clash: { dur: 20, legal: ['hands_open_or_claw'], phases: [
    { id: 'recoil', ticks: 8, sketch: holds.clash_recoil.sketch, orig: holds.clash_recoil.orig },
    { id: 'settle', ticks: 12, from: 'stance.aggressive', over: { lean: 4, ...OPEN }, orig: 'back to the stance' },
  ] },
};

export const cues = {};
