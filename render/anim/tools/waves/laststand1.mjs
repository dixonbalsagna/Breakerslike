// The last stand (docs/architecture/last-stand.md): the first time a fighter reaches the brink his signature is free for 20 s. Events: last_stand_ready {actor, dur},
// last_stand_end {actor, kind: used | expired}. The body cue: on ready, a steadying beat in his own shape (the hurt body gathering itself: a breath, the head
// up, the chest open), then a held resolve while the window is open, and a slump if it expires (a used window hands over to the signature's own animation).
// Played by AnimFighter.on_last_stand over the wounded stance. Hands open throughout; no crossed arms, no clenched fists at the sides, no scream, no aura
// (the stacking rule: this is a pose, not an effect). Each pose has an _orig line.
const OPEN = { hands: { r: 'open', l: 'open' } };
const LEG = ['hands_open_or_claw', 'no_cross_hold'];

function ready(shape, brace, rise, settle, orig) {
  return { dur: 40, legal: LEG, shape, phases: [
    { id: 'brace', ticks: 10, sketch: { ...brace, ...OPEN }, orig: orig.brace },
    { id: 'rise', sketch: { ...rise, ...OPEN }, orig: orig.rise },
    { id: 'settle', ticks: 8, sketch: { ...settle, ...OPEN }, orig: orig.settle },
  ] };
}

export const sequences = {
  ready_p: ready('P',
    { family: 'crouched', lean: 18, hips: [0, -10, 0], spine: { lean: 14 }, head: { pitch: 14 }, hand_r: [10, 34, 12], hand_l: [10, 32, -10], foot_r: [-8, 2.5, 9], foot_l: [8, 2.5, -7] },
    { family: 'upright', lean: 6, hips: [0, -4, 0], spine: { lean: -4 }, head: { pitch: -6 }, hand_r: [14, 44, 18], hand_l: [14, 42, -16], foot_r: [-8, 2.5, 9], foot_l: [8, 2.5, -7] },
    { family: 'upright', lean: 8, hips: [1, -4, 0], spine: { lean: 2 }, head: { pitch: -4 }, hand_r: [16, 52, 14], hand_l: [18, 50, -10], foot_r: [-8, 2.5, 9], foot_l: [10, 2.5, -7] },
    { brace: 'at the brink: the body folding in on the hurt, the open hands low', rise: 'a deep breath: the chest opened wide, the head lifting, the open palms turned out low at his sides', settle: 'set again, the guard coming up, round and open' }),
  ready_a: ready('A',
    { family: 'crouched', lean: 20, hips: [0, -12, 0], spine: { lean: 16 }, head: { pitch: 16 }, hand_r: [8, 30, 10], hand_l: [8, 28, -8], foot_r: [-6, 2.5, 8], foot_l: [6, 2.5, -7] },
    { family: 'upright', lean: 2, hips: [0, -2, 0], spine: { lean: -2 }, head: { pitch: -8 }, hand_r: [2, 32, 10], hand_l: [2, 30, -8], foot_r: [-3, 2.5, 7], foot_l: [3, 2.5, -6] },
    { family: 'upright', lean: 6, hips: [1, -3, 0], spine: { lean: 2, twist: -8 }, head: { pitch: -2, yaw: 6 }, hand_r: [14, 54, 12], hand_l: [20, 52, -8], foot_r: [-8, 2.5, 8], foot_l: [10, 2.5, -7] },
    { brace: 'at the brink: bent narrow over the hurt, the blade hands low along the thighs', rise: 'one cold breath: drawn up tall and narrow, the chin lifted, the blade hands still at his sides', settle: 'the guard set again, the shoulders square and the eyes level' }),
  ready_e: ready('E',
    { family: 'crouched', lean: 16, hips: [0, -10, 0], spine: { lean: 12 }, head: { pitch: 12 }, hand_r: [8, 34, 14], hand_l: [8, 32, -12], foot_r: [-10, 2.5, 10], foot_l: [10, 2.5, -9] },
    { family: 'upright', lean: 2, hips: [0, -3, 0], spine: { lean: -4 }, head: { pitch: -8 }, hand_r: [10, 62, 34], hand_l: [10, 60, -32], foot_r: [-10, 2.5, 10], foot_l: [10, 2.5, -9] },
    { family: 'upright', lean: 6, hips: [1, -4, 0], spine: { lean: 2, twist: -6 }, head: { pitch: -4 }, hand_r: [14, 56, 22], hand_l: [20, 54, -16], foot_r: [-10, 2.5, 10], foot_l: [12, 2.5, -9] },
    { brace: 'at the brink: curled in over the hurt, the arms low', rise: 'the arms sweeping out wide as he rises, the chest and head lifting: the whole body opening', settle: 'the arms drawing back to a wide guard' }),
  ready_c: ready('C',
    { family: 'crouched', lean: 12, hips: [0, -10, 0], spine: { lean: 10 }, head: { pitch: 10 }, hand_r: [10, 36, 12], hand_l: [10, 34, -10], foot_r: [-8, 2.5, 11], foot_l: [8, 2.5, -9] },
    { family: 'upright', lean: 0, hips: [0, -3, 0], spine: { lean: 0 }, head: { pitch: -4 }, hand_r: [8, 40, 16], hand_l: [8, 38, -14], foot_r: [-8, 2.5, 11], foot_l: [8, 2.5, -9] },
    { family: 'upright', lean: 4, hips: [1, -4, 0], spine: { lean: 2 }, head: { pitch: -2 }, hand_r: [16, 50, 14], hand_l: [18, 48, -10], foot_r: [-8, 2.5, 11], foot_l: [10, 2.5, -9] },
    { brace: 'at the brink: a heavy body folded square over the damage', rise: 'drawn up square and level in one even motion, the feet planted wide, the hands open at the sides', settle: 'the squared guard' }),
  slump: { dur: 24, legal: LEG, phases: [
    { id: 'drop', ticks: 8, sketch: { family: 'upright', lean: 6, hips: [0, -4, 0], spine: { lean: 6 }, head: { pitch: 8 }, hand_r: [8, 40, 12], hand_l: [8, 38, -10], foot_r: [-8, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN },
      orig: 'the window closing unused: the shoulders letting go' },
    { id: 'sag', sketch: { family: 'upright', lean: 12, hips: [0, -8, 0], spine: { lean: 12 }, head: { pitch: 12 }, hand_r: [8, 36, 12], hand_l: [8, 34, -10], foot_r: [-8, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN },
      orig: 'sagging back into the hurt, the head lowering a little' },
  ] },
};

export const holds = {
  resolve: { sketch: { family: 'upright', lean: 6, hips: [1, -3, 0], spine: { lean: 0 }, head: { pitch: -4 }, hand_r: [16, 52, 13], hand_l: [20, 50, -9], foot_r: [-8, 2.5, 9], foot_l: [10, 2.5, -7], ...OPEN },
    orig: 'resolve while the window is open: the chest up, the head level, the guard set' },
};

export const cues = {};
