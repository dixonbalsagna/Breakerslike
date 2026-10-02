// Ground contact (World's switch-on: docs/world/ground-contact.md section 4, sim/world/contact.gd) as held poses and short sequences, played by
// AnimFighter.on_ground_event over the active ragdoll (the ragdoll keeps its own motion on top). The events: left_ground (cause lip, ridge, cliff, crest,
// heap or bounce), bounce, land (skid, tumble, slam), tumble_end (stop, recover, air), journey_end. Sequences here are played by the entry layer; the
// held brace of a tumble is one pose. A weight scales the sequence by the event's speed (data/anim/ground.json). Originality: no franchise pose; each
// pose has an _orig line.
const OPEN = { hands: { r: 'open', l: 'open' } };

export const sequences = {
  bounce: { dur: 10, phases: [
    { id: 'fold', ticks: 3, sketch: { family: 'tumble', lean: 40, hips: [0, -4, 0], spine: { lean: 28 }, head: { pitch: 20 }, hand_r: [16, 34, 12], hand_l: [16, 32, -10],
        foot_r: [10, 26, 8], foot_l: [6, 22, -6], ...OPEN },
      orig: 'the body folding on the ground: the knees drawn up and the arms thrown in front to take the blow' },
    { id: 'rebound', ticks: 7, sketch: { family: 'tumble', lean: -10, hips: [0, 2, 0], spine: { lean: -14 }, head: { pitch: -14 }, hand_r: [-10, 70, 26], hand_l: [-8, 66, -24],
        foot_r: [-12, 10, 10], foot_l: [-14, 6, -8], ...OPEN },
      orig: 'thrown back up: the arms flung out and up, the legs trailing, the head back' },
  ] },
  lip_launch: { dur: 24, phases: [
    { id: 'kick', ticks: 3, sketch: { family: 'airborne_extended', lean: -24, spine: { lean: -14 }, head: { pitch: -12 }, hand_r: [-12, 72, 20], hand_l: [-10, 68, -18],
        foot_r: [-6, 8, 6], foot_l: [-10, 4, -6], ...OPEN },
      orig: 'thrown off the crest: the body arching, the arms flung up and back, the legs trailing' },
    { id: 'stream', sketch: { family: 'airborne_extended', lean: 16, spine: { lean: 6 }, head: { pitch: -8 }, hand_r: [-14, 48, 12], hand_l: [-14, 46, -10],
        foot_r: [-26, 14, 5], foot_l: [-28, 10, -5], ...OPEN },
      orig: 'in the air off the lip: stretched along the arc, the arms and legs streaming behind' },
  ] },
  tech_flip: { dur: 21, phases: [
    { id: 'tuck', ticks: 5, sketch: { family: 'tumble', lean: 70, hips: [0, -6, 0], spine: { lean: 40 }, head: { pitch: 34 }, hand_r: [20, 40, 12], hand_l: [18, 38, -8],
        foot_r: [-1.4, 20.5, 5], foot_l: [-1.4, 20.5, -5], pole_foot_r: [16.6, -3.5, 0], pole_foot_l: [16.6, -3.5, 0], ...OPEN },
      orig: 'the recovery: the body tucking in tight, the knees to the chest' },
    { id: 'spin', sketch: { family: 'tumble', lean: 90, hips: [0, -6, 0], spine: { lean: 50, twist: 10 }, head: { pitch: 40 }, hand_r: [18, 36, 12], hand_l: [16, 34, -8],
        foot_r: [-4.0, 22.0, 5], foot_l: [-4.0, 22.0, -5], pole_foot_r: [15.0, -8.0, 0], pole_foot_l: [15.0, -8.0, 0], ...OPEN },
      orig: 'a tight flip: the body one ball turning over' },
    { id: 'open', ticks: 6, sketch: { family: 'airborne_neutral', lean: 8, hips: [0, -2, 0], spine: { lean: 2 }, head: { pitch: 4 }, hand_r: [14, 60, 26], hand_l: [14, 60, -24],
        foot_r: [4, 6, 8], foot_l: [-4, 4, -7], ...OPEN },
      orig: 'opening out of the flip: the feet reaching down, the arms thrown wide for balance' },
    { id: 'land', ticks: 4, sketch: { family: 'crouched', lean: 14, hips: [0, -14, 0], spine: { lean: 10 }, head: { pitch: 6 }, hand_r: [20, 48, 12], hand_l: [20, 46, -8],
        foot_r: [-8, 2.5, 9], foot_l: [10, 2.5, -7], ...OPEN },
      orig: 'landing in a low crouch, the guard coming up' },
  ] },
  getup_quick: { dur: 18, phases: [
    { id: 'push', ticks: 4, from: 'getup.push', orig: 'the hands pushing off the ground' },
    { id: 'kip', ticks: 5, sketch: { family: 'crouched', lean: 40, hips: [0, -18, 0], spine: { lean: 24 }, head: { pitch: 14 }, hand_l: [20, 4, -8], hand_r: [16, 40, 10],
        foot_r: [-4, 2.5, 9], foot_l: [10, 2.5, -7], ...OPEN },
      orig: 'the hips kicked up and the feet under him, one hand still down' },
    { id: 'rise', from: 'stance.aggressive', over: { hips: [0, -8, 0], hand_r: [18, 54, 12], hand_l: [22, 52, -8], ...OPEN }, orig: 'up into a low stance, the guard coming up' },
  ] },
  getup_slow: { dur: 54, phases: [
    { id: 'roll', w: 1, sketch: { family: 'kneel', lean: 24, hips: [0, -26, 0], spine: { lean: 20 }, head: { pitch: 18 }, hand_l: [16, 4, -8], hand_r: [20, 24, 12],
        foot_r: [-14, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN },
      orig: 'up onto one knee, a hand on the ground, the other on the thigh' },
    { id: 'kneel', w: 2, sketch: { family: 'kneel', lean: 30, hips: [0, -22, 0], spine: { lean: 24 }, head: { pitch: 16 }, hand_r: [14, 28, 12], hand_l: [10, 24, -8],
        foot_r: [-12, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN },
      orig: 'a breath on one knee, the hand pressing the thigh' },
    { id: 'rise', w: 2, sketch: { family: 'crouched', lean: 30, hips: [0, -14, 0], spine: { lean: 22 }, head: { pitch: 14 }, hand_r: [14, 30, 12], hand_l: [12, 36, -8],
        foot_r: [-10, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN },
      orig: 'rising hunched, one hand on the knee' },
    { id: 'settle', ticks: 6, from: 'stance.aggressive', over: { hips: [0, -6, 0], lean: 14, ...OPEN }, orig: 'upright at last, the guard slow to come back up' },
  ] },
};

// held poses (not sequences): a pose id that AnimFighter mixes for as long as the journey says
export const holds = {
  brace_tumble: { sketch: { family: 'tumble', lean: 52, hips: [0, -6, 0], spine: { lean: 30 }, head: { pitch: 28 }, hand_r: [14, 56, 12], pole_hand_r: [10, 4, 8], hand_l: [14, 54, -10],
      foot_r: [0.4, 14.5, 5], foot_l: [0.4, 14.5, -5], pole_foot_r: [16.3, -5.0, 0], pole_foot_l: [16.3, -5.0, 0], ...OPEN },
    orig: 'braced in a roll: chin tucked, the forearms drawn in front of the face, the knees up' },
};

export const cues = {};
