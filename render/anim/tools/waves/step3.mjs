// Encounter's step 3 cue events as poses (sim/director/interrupt.gd): perfect_block, reversal, dodge_cancel, burst, burst_absorbed, and the stagger of the
// fighter on the receiving end. Each sequence is played by AnimFighter._entry_layer (the same layer as wave 2's entries) when the cue arrives (--step3-cues,
// OFF by default). Times are the sim's (data/combat/templates.json): the perfect-block stagger 24 ticks and its riposte window 30, the reversal's delay 8,
// the burst's bait stagger 30. `cues` maps a cue kind to the sequence its actor plays and the one the other fighter plays.
// Originality: no franchise pose; each pose has an _orig line. Hands open (blades) throughout; no crossed-arms hold, no clasped fists.
const OPEN = { hands: { r: 'open', l: 'open' } };
const LEGAL = ['hands_open_or_claw', 'no_cross_hold'];

export const sequences = {
  perfect_block: { dur: 30, legal: LEGAL, alt: { label: 'the deflect swept low, from the hip up', over: { deflect: { hand_r: [22, 44, 12], pole_hand_r: [8, -4, 8], lean: -6, spine: { twist: 12 } } } }, phases: [
    { id: 'deflect', ticks: 3, sketch: { family: 'upright', lean: -4, hips: [-2, -6, 0], spine: { lean: 0, twist: 20 }, head: { pitch: 4, yaw: 8 }, hand_r: [20, 64, 10], pole_hand_r: [8, 4, 8],
        hand_l: [10, 56, -6], foot_r: [-12, 2.5, 9], foot_l: [10, 2.5, -7], ...OPEN },
      orig: 'the sharp deflect: one forearm swept up and across to knock the blow wide, the body turned to it, the weight set back' },
    { id: 'set', ticks: 5, sketch: { family: 'upright', lean: -8, hips: [-4, -8, 0], spine: { lean: -2, twist: 14 }, head: { pitch: 4, yaw: 8 }, hand_r: [14, 60, 12], hand_l: [18, 54, -6],
        foot_r: [-14, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN },
      orig: 'braced: the weight settled on the rear leg, the open hands up, the eyes on the staggering rival' },
    { id: 'ready', sketch: { family: 'upright', lean: 8, hips: [0, -6, 0], spine: { lean: 4, twist: -16 }, head: { pitch: 4, yaw: 6 }, hand_r: [6, 50, 14], hand_l: [26, 58, -6],
        foot_r: [-10, 2.5, 9], foot_l: [12, 2.5, -7], ...OPEN },
      orig: 'the riposte held loaded: the rear arm drawn back, the lead hand forward, the shoulders wound, ready to answer' },
  ] },
  stagger_blocked: { dur: 24, legal: LEGAL, alt: { label: 'folded forward over the blow instead of thrown back', over: { recoil: { lean: 10, hips: [-4, -8, 0], spine: { lean: 20 }, head: { pitch: 16, yaw: 8 }, hand_r: [12, 40, 20], hand_l: [10, 38, -18], foot_r: [-14, 2.5, 8] } } }, phases: [
    { id: 'recoil', ticks: 7, sketch: { family: 'upright', lean: -20, hips: [-10, -2, 0], spine: { lean: -10, twist: 25 }, head: { pitch: -12, yaw: 14 }, hand_r: [-8, 66, 24],
        hand_l: [6, 58, -20], foot_r: [-22, 2.5, 8], foot_l: [2, 2.5, -7], ...OPEN },
      orig: 'knocked off line: the striking arm flung wide and back, the chest thrown open, the chin up, the weight going back' },
    { id: 'stumble', w: 3, sketch: { family: 'upright', lean: -10, hips: [-6, -6, 0], spine: { lean: -4, twist: 14 }, head: { pitch: 4, yaw: 10 }, hand_r: [0, 52, 22], hand_l: [2, 50, -18],
        foot_r: [-16, 10, 8], foot_l: [8, 2.5, -7], ...OPEN },
      orig: 'the stumble: a foot lifting to catch the weight, the arms swinging for balance' },
    { id: 'regain', ticks: 6, sketch: { family: 'upright', lean: 2, hips: [0, -4, 0], spine: { lean: 2, twist: 6 }, head: { pitch: 4, yaw: 8 }, hand_r: [14, 54, 12], hand_l: [18, 52, -8],
        foot_r: [-10, 2.5, 9], foot_l: [10, 2.5, -7], ...OPEN },
      orig: 'finding the feet: the guard coming half back up' },
  ] },
  stagger_short: { dur: 12, legal: LEGAL, phases: [
    { id: 'recoil', ticks: 4, sketch: { family: 'upright', lean: -12, hips: [-6, -2, 0], spine: { lean: -6, twist: 14 }, head: { pitch: -4, yaw: 10 }, hand_r: [2, 60, 18], hand_l: [8, 56, -14],
        foot_r: [-16, 2.5, 8], foot_l: [4, 2.5, -7], ...OPEN },
      orig: 'a short stagger with no blow of its own: the weight rocked back, the arms swinging a little wide' },
    { id: 'stumble', sketch: { family: 'upright', lean: -6, hips: [-4, -4, 0], spine: { lean: -2, twist: 8 }, head: { pitch: 4, yaw: 8 }, hand_r: [8, 56, 18], hand_l: [12, 54, -14],
        foot_r: [-12, 6, 8], foot_l: [6, 2.5, -7], ...OPEN },
      orig: 'a step to catch the weight' },
    { id: 'regain', ticks: 4, sketch: { family: 'upright', lean: 4, hips: [0, -4, 0], spine: { lean: 2, twist: 4 }, head: { pitch: 4, yaw: 6 }, hand_r: [14, 56, 12], hand_l: [18, 54, -8],
        foot_r: [-10, 2.5, 9], foot_l: [10, 2.5, -7], ...OPEN },
      orig: 'the guard coming back up' },
  ] },
  reversal: { dur: 8, legal: LEGAL, phases: [
    { id: 'break', ticks: 3, sketch: { family: 'upright', lean: -6, hips: [-4, -4, 0], spine: { lean: -4, twist: 8 }, head: { pitch: -8, yaw: 6 }, hand_r: [10, 66, 24], hand_l: [10, 66, -24],
        foot_r: [-12, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN },
      orig: 'the guard cancelled: both arms snapped apart and up, throwing the attacker off, the head lifting' },
    { id: 'coil', sketch: { family: 'crouched', lean: 12, hips: [-6, -10, 0], spine: { lean: 6, twist: -34 }, head: { pitch: 6, yaw: 8 }, hand_r: [-6, 56, 16], hand_l: [20, 58, -8],
        foot_r: [-12, 2.5, 9], foot_l: [10, 2.5, -7], ...OPEN },
      orig: 'the turn into the counter: the weight dropping, the spine wound back, one arm loaded, the other ahead' },
  ] },
  stagger_countered: { dur: 16, legal: LEGAL, phases: [
    { id: 'open', ticks: 6, sketch: { family: 'upright', lean: -14, hips: [-8, -2, 0], spine: { lean: -6, twist: 14 }, head: { pitch: 8, yaw: 12 }, hand_r: [4, 44, 26], hand_l: [8, 44, -24],
        foot_r: [-18, 2.5, 8], foot_l: [4, 2.5, -7], ...OPEN },
      orig: 'the attack thrown off: the arms knocked wide and low, the whole front open' },
    { id: 'hold', sketch: { family: 'upright', lean: -8, hips: [-6, -4, 0], spine: { lean: -4, twist: 10 }, head: { pitch: 6, yaw: 10 }, hand_r: [10, 48, 20], hand_l: [12, 48, -18],
        foot_r: [-14, 2.5, 8], foot_l: [6, 2.5, -7], ...OPEN },
      orig: 'caught open: the arms coming back too late for the counter' },
  ] },
  dodge_cancel: { dur: 10, legal: LEGAL, phases: [
    { id: 'snap', ticks: 3, sketch: { family: 'upright', lean: -24, hips: [-8, -4, 0], spine: { lean: -6, twist: -20 }, head: { pitch: -4, yaw: 10 }, hand_r: [-12, 58, 14], hand_l: [-4, 60, -12],
        foot_r: [-20, 2.5, 8], foot_l: [4, 6, -7], ...OPEN },
      orig: 'the body whipped out of the exchange: the lean away, the arms swept back, the rear foot pushing off' },
    { id: 'slide', sketch: { family: 'airborne_neutral', lean: -16, hips: [-4, 2, 0], spine: { lean: -4, twist: -10 }, head: { pitch: 0, yaw: 8 }, hand_r: [-4, 56, 14], hand_l: [4, 58, -12],
        foot_r: [-10, 8, 8], foot_l: [2, 6, -6], ...OPEN },
      orig: 'carried clear: the body still leaning away, the feet barely touching' },
  ] },
  burst: { dur: 14, legal: LEGAL, alt: { label: 'the arms thrown forward instead of wide', over: { release: { hand_r: [36, 62, 8], hand_l: [36, 62, -8], lean: 6, spine: { lean: 4 } }, hold: { hand_r: [30, 60, 8], hand_l: [30, 60, -8] } } }, phases: [
    { id: 'gather', ticks: 3, sketch: { family: 'crouched', lean: 12, hips: [0, -10, 0], spine: { lean: 8 }, head: { pitch: 8 }, hand_r: [12, 50, 6], hand_l: [12, 50, -6],
        foot_r: [-10, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN },
      orig: 'a gather: the body hunched in on itself, the open hands drawn close to the chest' },
    { id: 'release', ticks: 5, sketch: { family: 'upright', lean: -6, hips: [0, 0, 0], spine: { lean: -6 }, head: { pitch: -10 }, hand_r: [18, 72, 30], hand_l: [18, 72, -30],
        foot_r: [-10, 2.5, 12], foot_l: [12, 2.5, -10], ...OPEN },
      orig: 'the shove all round: the arms thrown wide and up, the chest forward, the feet planted wide, the head up' },
    { id: 'hold', sketch: { family: 'upright', lean: -2, hips: [0, -3, 0], spine: { lean: -2 }, head: { pitch: -4 }, hand_r: [16, 66, 28], hand_l: [16, 66, -28],
        foot_r: [-10, 2.5, 12], foot_l: [12, 2.5, -10], ...OPEN },
      orig: 'the arms still out a beat, the body spent' },
  ] },
  shoved: { dur: 12, legal: LEGAL, phases: [
    { id: 'shove', sketch: { family: 'upright', lean: -16, hips: [-8, -2, 0], spine: { lean: -8, twist: 10 }, head: { pitch: -6, yaw: 8 }, hand_r: [15, 68, 15], hand_l: [16, 64, -13],
        foot_r: [-18, 2.5, 8], foot_l: [2, 2.5, -7], ...OPEN },
      orig: 'shoved back by the burst: the arms thrown up in front, the weight leaning away, the feet sliding' },
  ] },
  stagger_bait: { dur: 30, legal: LEGAL, phases: [
    { id: 'rebound', ticks: 6, sketch: { family: 'upright', lean: -18, hips: [-8, -2, 0], spine: { lean: -8, twist: 18 }, head: { pitch: -10, yaw: 10 }, hand_r: [-10, 60, 26], hand_l: [-6, 62, -24],
        foot_r: [-20, 2.5, 8], foot_l: [2, 2.5, -7], ...OPEN },
      orig: 'the burst thrown back at him by a guard that did not move: the arms flung wide, the body rebounding' },
    { id: 'hunch', w: 3, sketch: { family: 'crouched', lean: 28, hips: [-4, -14, 0], spine: { lean: 22 }, head: { pitch: 20 }, hand_r: [8, 26, 12], hand_l: [8, 24, -10],
        foot_r: [-12, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN },
      orig: 'bent over, winded: the open hands falling toward the knees, the head down' },
    { id: 'straighten', ticks: 8, sketch: { family: 'upright', lean: 6, hips: [0, -5, 0], spine: { lean: 4 }, head: { pitch: 6 }, hand_r: [14, 54, 12], hand_l: [18, 52, -8],
        foot_r: [-10, 2.5, 9], foot_l: [10, 2.5, -7], ...OPEN },
      orig: 'straightening, the guard coming back' },
  ] },
  absorb: { dur: 12, legal: LEGAL, phases: [
    { id: 'brace', sketch: { family: 'upright', lean: 4, hips: [-4, -10, 0], spine: { lean: 2, twist: 6 }, head: { pitch: 4 }, hand_r: [18, 62, 12], pole_hand_r: [8, 4, 8], hand_l: [20, 60, -8],
        foot_r: [-14, 2.5, 10], foot_l: [10, 2.5, -9], ...OPEN },
      orig: 'taking the burst on the guard: rooted low on wide feet, both forearms up in front, the shove sliding off' },
  ] },
};

export const cues = {
  perfect_block: { actor: 'perfect_block', other_if_stunned: 'stagger_blocked' },
  reversal: { actor: 'reversal', other_if_stunned: 'stagger_countered' },
  dodge_cancel: { actor: 'dodge_cancel' },
  burst: { actor: 'burst', other_if_shoved: 'shoved' },
  burst_absorbed: { actor: 'stagger_bait', other: 'absorb' },
};
