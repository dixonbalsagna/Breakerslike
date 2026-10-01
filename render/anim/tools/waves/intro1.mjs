// The opening (docs/architecture/intro-phase.md, docs/camera/rule-of-cool-shots.md row 7): each fighter falls 6,000 units, lands in his crater, and the two
// stare until the clock. Played by AnimFighter._intro_layer from the sim's events (intro_start, entrance_fall, entrance_land, staredown_start, clock_start) on the
// sim's tick (the clock is frozen before the match starts). Legal: no wind-blown cape or silhouette reveal; the landing crouch reads from the low angle and
// rises into the stance with the hands open and the head UP (no fist to the ground with the head bowed); the staredown is not a duel pose. Hands open or
// relaxed throughout. Each pose has an _orig line.
const OPEN = { hands: { r: 'open', l: 'open' } };
const REL = { hands: { r: 'relaxed', l: 'relaxed' } };

export const sequences = {
  land: { dur: 60, legal: ['hands_open_or_claw'], phases: [
    { id: 'compress', ticks: 6, sketch: { family: 'crouched', lean: 30, hips: [2, -30, 0], spine: { lean: 22 }, head: { pitch: -16 }, hand_l: [24, 3, -10], hand_r: [2, 48, 14],
        foot_r: [-14, 3, 10], foot_l: [14, 2.5, -8], ...OPEN },
      orig: 'the touchdown: a deep compression, one open hand flat on the ground, the other arm back for balance, the head up and looking ahead' },
    { id: 'hold', sketch: { family: 'crouched', lean: 26, hips: [2, -26, 0], spine: { lean: 18 }, head: { pitch: -12 }, hand_l: [22, 4, -10], hand_r: [2, 46, 14],
        foot_r: [-12, 3, 10], foot_l: [14, 2.5, -8], ...OPEN },
      orig: 'held low in the crater: still, the chest rising, the head up' },
    { id: 'rise', ticks: 30, sketch: { family: 'crouched', lean: 18, hips: [0, -14, 0], spine: { lean: 12 }, head: { pitch: -8 }, hand_l: [18, 24, -8], hand_r: [12, 40, 12],
        foot_r: [-10, 2.5, 9], foot_l: [10, 2.5, -7], ...OPEN },
      orig: 'rising through a half crouch toward the stance, the hand lifting off the ground, the head still up' },
  ] },
  cuff: { dur: 36, legal: [], phases: [
    { id: 'lift', ticks: 8, sketch: { family: 'upright', lean: 2, hips: [0, -2, 0], spine: { lean: 2 }, head: { pitch: -2 }, hand_r: [14, 46, -2], hand_l: [12, 48, -10],
        foot_r: [-4, 2.5, 8], foot_l: [6, 2.5, -7], ...REL },
      orig: 'a small adjustment: one hand rising to the other cuff, the head and eyes staying on the rival' },
    { id: 'hold', sketch: { family: 'upright', lean: 2, hips: [0, -2, 0], spine: { lean: 2 }, head: { pitch: -2 }, hand_r: [15, 47, -4], hand_l: [13, 49, -10],
        foot_r: [-4, 2.5, 8], foot_l: [6, 2.5, -7], ...REL },
      orig: 'the cuff set straight, unhurried' },
    { id: 'drop', ticks: 8, sketch: { family: 'upright', lean: 2, hips: [0, -2, 0], spine: { lean: 2 }, head: { pitch: -2 }, hand_r: [4, 40, 11], hand_l: [4, 38, -9],
        foot_r: [-4, 2.5, 8], foot_l: [6, 2.5, -7], ...REL },
      orig: 'the arms loose again' },
  ] },
  roll: { dur: 36, legal: [], phases: [
    { id: 'lift', ticks: 10, sketch: { family: 'upright', lean: 4, hips: [0, -2, 0], spine: { lean: 4, twist: 12 }, head: { pitch: -2, roll: 4 }, hand_r: [8, 44, 12], hand_l: [6, 40, -9],
        foot_r: [-4, 2.5, 8], foot_l: [6, 2.5, -7], ...REL },
      orig: 'the shoulders rolled once: a slow turn of the chest and a tilt of the head, the eyes staying on the rival' },
    { id: 'drop', ticks: 12, sketch: { family: 'upright', lean: 2, hips: [0, -2, 0], spine: { lean: 2, twist: -4 }, head: { pitch: -2 }, hand_r: [4, 40, 11], hand_l: [4, 38, -9],
        foot_r: [-4, 2.5, 8], foot_l: [6, 2.5, -7], ...REL },
      orig: 'settling again, the arms loose' },
  ] },
};

export const holds = {
  fall: { sketch: { family: 'airborne_extended', lean: 165, spine: { lean: 0 }, head: { pitch: 0 }, hand_r: [-1, 39, 9], hand_l: [-1, 38, -8],
      foot_r: [-6, 68, 4], foot_l: [-6, 66, -4], ...OPEN },
    orig: 'falling head first: the body one narrow line, the arms tight along the sides, the legs together, the head up to look at where he will land' },
  set: { sketch: { family: 'upright', lean: 2, hips: [0, -2, 0], spine: { lean: 2 }, head: { pitch: -2 }, hand_r: [4, 40, 11], hand_l: [4, 38, -9],
      foot_r: [-4, 2.5, 8], foot_l: [6, 2.5, -7], ...REL },
    orig: 'the staredown set: upright, the weight even, the arms loose, the chin level, the eyes on the rival' },
  tense: { sketch: { family: 'upright', lean: 8, hips: [3, -4, 0], spine: { lean: 6 }, head: { pitch: 6 }, hand_r: [12, 50, 12], hand_l: [14, 48, -8],
      foot_r: [-6, 2.5, 8], foot_l: [8, 2.5, -7], ...OPEN },
    orig: 'the tension: the weight coming forward, the hands rising a little, the chin down a touch, the face set for the close-up' },
};

export const cues = {};
