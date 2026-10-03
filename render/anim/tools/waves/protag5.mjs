// The Protagonist's gaps found by the launch-pair coverage audit (docs/animation/launch-pair-coverage.md): the free blast presses (a bolt from the palm thrust, a fan of arcs from the
// ring hand, a lobbed shot, a charged shot released from the brace, a shot down into a crater), the spray with open hands (the shared spray's lead hand is a claw, which his profile
// bans), and his far taunts and close taunt. Parked (--waves). Legal: RL-060 to RL-065: his hands are open or flat, a palm released still, never a finger or a sweep for the curving shot,
// no glow in the pose, no scream, no aura, no beckoning, no crossed arms, nothing held up after a fist.
const OPEN = { hands: { r: 'open', l: 'open' } };
const STAND = { foot_r: [-10, 2.5, 9], foot_l: [12, 2.5, -8] };

export const sequences = {
  // ---- the free blast presses
  bolt: { dur: 12, legal: ['hands_open_or_claw', 'not_at_hip'], phases: [
    { id: 'wind', ticks: 4, sketch: { family: 'upright', lean: 8, hips: [2, -6, 0], spine: { lean: 2, twist: 14 }, head: { pitch: 0, yaw: 4 }, hand_r: [30, 58, 10], pole_hand_r: [2, 52, 20], hand_l: [14, 52, -8], ...STAND, ...OPEN },
      orig: 'a bolt readied: the open palm brought up to the chest with the fingers together, the other hand open beside it' },
    { id: 'fire', ticks: 2, sketch: { family: 'upright', lean: 10, hips: [4, -6, 0], spine: { lean: 2, twist: 18 }, head: { pitch: 0, yaw: 4 }, hand_r: [46, 62, 8], pole_hand_r: [2, 56, 18], hand_l: [14, 52, -8], ...STAND, ...OPEN },
      orig: 'the palm thrust from the shoulder as the bolt leaves, the arm stopped at full length' },
    { id: 'settle', ticks: 6, from: 'stance.aggressive', over: { lean: 8, ...OPEN }, orig: 'back to the stance' },
  ] },
  // a fan of arcs from the ring hand: the arm carried round in one wide curve, the fingers loosely curled (the rig's relaxed hand)
  volley_arc: { dur: 14, legal: ['not_at_hip'], phases: [
    { id: 'set', ticks: 4, sketch: { family: 'upright', lean: 8, hips: [2, -6, 0], spine: { lean: 2, twist: -16 }, head: { pitch: 0, yaw: 4 }, hand_r: [24, 40, 14], pole_hand_r: [2, 34, 22], hand_l: [14, 52, -8], ...STAND, hands: { r: 'relaxed', l: 'open' } },
      orig: 'the ring hand drawn back low, the fingers loosely curled round an arc, the other hand open at his chest' },
    { id: 'sweep', ticks: 4, sketch: { family: 'upright', lean: 8, hips: [4, -6, 0], spine: { lean: 2, twist: 22 }, head: { pitch: -2, yaw: 4 }, hand_r: [42, 72, 16], pole_hand_r: [4, 58, 22], hand_l: [14, 52, -8], ...STAND, hands: { r: 'relaxed', l: 'open' } },
      orig: 'the sweep: the arm carried round and up in one wide curve, the arcs leaving it in a fan along the line it draws' },
    { id: 'settle', ticks: 6, from: 'stance.aggressive', over: { lean: 8, ...OPEN }, orig: 'back to the stance' },
  ] },
  lob: { dur: 16, legal: ['hands_open_or_claw', 'not_at_hip', 'no_held_raise'], phases: [
    { id: 'wind', ticks: 5, sketch: { family: 'upright', lean: 10, hips: [0, -10, 0], spine: { lean: 6, twist: -10 }, head: { pitch: 6 }, hand_r: [16, 22, 14], pole_hand_r: [-6, 24, 20], hand_l: [14, 54, -8], ...STAND, ...OPEN },
      orig: 'the throwing hand swung back low with the knees bent, the other hand open at his chest' },
    { id: 'throw', ticks: 4, sketch: { family: 'upright', lean: 4, hips: [4, -6, 0], spine: { lean: -2, twist: 18 }, head: { pitch: -8 }, hand_r: [38, 66, 10], pole_hand_r: [4, 48, 18], hand_l: [12, 52, -8], ...STAND, ...OPEN },
      orig: 'the lob: the arm swung up and forward from low with the open hand under the shot as it leaves, the eyes following the arc; one hand only' },
    { id: 'settle', ticks: 7, from: 'stance.aggressive', over: { lean: 6, head: { pitch: -4 }, ...OPEN }, orig: 'back to the stance, watching it come down' },
  ] },
  // a charged shot released from the brace (pn.hold.brace_hold): the forward hand is thrust from the shoulder as a flat palm, never swept
  charged: { dur: 34, legal: ['wrists_apart', 'hands_open_or_claw', 'not_at_hip'], phases: [
    { id: 'charge', w: 4, sketch: { family: 'upright', lean: 12, hips: [2, -12, 0], spine: { lean: 4, twist: 14 }, head: { pitch: 0, yaw: 4 }, hand_r: [40, 60, 12], pole_hand_r: [4, 52, 22], hand_l: [-8.3, 23.1, -18.8], pole_hand_l: [-8, 22, -24],
        foot_r: [-14, 2.5, 11], foot_l: [16, 2.5, -9], ...OPEN },
      orig: 'at full charge: one open hand forward at the shoulder, still, the other low and out behind him, the stance wide and steady' },
    { id: 'release', ticks: 8, sketch: { family: 'upright_lunge', lean: 14, hips: [8, -6, 0], spine: { lean: 4, twist: 22 }, head: { pitch: 0, yaw: 4 }, hand_r: [51.7, 61.5, 8], pole_hand_r: [-2, 0, 8], hand_l: [15, 52.6, -10.3],
        foot_r: [-6, 2.5, 9], foot_l: [20, 2.5, -7], ...OPEN },
      orig: 'the release: the palm thrust from the shoulder, the arm at full length and the fingers up, the other hand drawn in to his chest' },
  ] },
  // the shared spray (en.spray) with open hands: his lead hand is never a claw
  spray: { dur: 6, legal: ['no_fist_punched_ahead'], phases: [
    { id: 'kick', ticks: 2, sketch: { family: 'upright', lean: 2, hips: [-6, -10, 0], spine: { lean: -10, twist: 14 }, head: { pitch: -4, yaw: 6 }, hand_r: [24, 70.5, 11.7], pole_hand_r: [8, 62, 22], hand_l: [2, 52, -22],
        foot_r: [-14, 2.5, 10], foot_l: [12, 2.5, -9], ...OPEN },
      orig: 'the bolt leaving: the lead arm kicked up a little with the open palm out, the shoulder rocking back, the rear hand thrown out wide for balance' },
    { id: 'settle', ticks: 4, sketch: { family: 'upright', lean: 8, hips: [-2, -10, 0], spine: { lean: 4, twist: 16 }, head: { pitch: 4, yaw: 6 }, hand_r: [32, 62, 12], pole_hand_r: [10, 56, 22], hand_l: [2, 52, -22],
        foot_r: [-14, 2.5, 10], foot_l: [12, 2.5, -9], ...OPEN },
      orig: 'back on the line: the lead arm level and out with the palm open and flat, the feet planted wide, the head down along the arm' },
  ] },

  // ---- the far taunts (45 ticks over the flight) and the close taunt (60 ticks, he can be hit). He is earnest: a nod, a bounce, a respectful tap of fist to palm; never a beckon
  taunt_nod: { dur: 45, legal: ['hands_open_or_claw'], phases: [
    { id: 'lift', ticks: 12, sketch: { family: 'upright', lean: 2, hips: [0, -4, 0], spine: { lean: 0 }, head: { pitch: -8 }, hand_r: [16, 46, 16], hand_l: [14, 46, -16], ...STAND, ...OPEN },
      orig: 'the chin lifted and the open hands loose at his sides, a calm look at the rival' },
    { id: 'nod', ticks: 14, sketch: { family: 'upright', lean: 4, hips: [0, -6, 0], spine: { lean: 4 }, head: { pitch: 14 }, hand_r: [16, 46, 16], hand_l: [14, 46, -16], ...STAND, ...OPEN },
      orig: 'a slow nod, the chin dipping and the shoulders easing: "come on, then"; a small bow of acknowledgement' },
    { id: 'settle', ticks: 19, from: 'stance.aggressive', over: { lean: 6, ...OPEN }, orig: 'settling into the stance, eyes up' },
  ] },
  taunt_bounce: { dur: 45, legal: ['hands_open_or_claw'], phases: [
    { id: 'down', ticks: 10, sketch: { family: 'upright', lean: 6, hips: [0, -10, 0], spine: { lean: 4 }, head: { pitch: 0 }, hand_r: [22, 54, 14], hand_l: [20, 54, -10], ...STAND, ...OPEN },
      orig: 'sinking on the knees with the open hands up in front, light on his feet' },
    { id: 'up', ticks: 10, sketch: { family: 'upright', lean: 2, hips: [0, 2, 0], spine: { lean: 0 }, head: { pitch: -4 }, hand_r: [22, 56, 14], hand_l: [20, 56, -10], foot_r: [-8, 8, 8], foot_l: [10, 8, -7], ...OPEN },
      orig: 'springing up onto the toes, the hands open and up, the chin level' },
    { id: 'down2', ticks: 10, sketch: { family: 'upright', lean: 6, hips: [0, -10, 0], spine: { lean: 4 }, head: { pitch: 0 }, hand_r: [22, 54, 14], hand_l: [20, 54, -10], ...STAND, ...OPEN },
      orig: 'and down again: a bounce on the spot, the earnest bounce of a fighter who is enjoying it' },
    { id: 'settle', ticks: 15, from: 'stance.aggressive', over: { lean: 6, ...OPEN }, orig: 'into the stance' },
  ] },
  taunt_fist_palm: { dur: 45, phases: [
    { id: 'raise', ticks: 10, sketch: { family: 'upright', lean: 2, hips: [0, -4, 0], spine: { lean: 0 }, head: { pitch: 4 }, hand_r: [22, 52, 16], pole_hand_r: [2, 44, 22], hand_l: [22, 50, -8], pole_hand_l: [2, 42, -14], ...STAND, hands: { r: 'fist', l: 'open' } },
      orig: 'the fist and the open palm brought up in front of the chest a hand apart' },
    { id: 'tap', ticks: 8, sketch: { family: 'upright', lean: 4, hips: [0, -4, 0], spine: { lean: 2 }, head: { pitch: 8 }, hand_r: [18, 52, 6], pole_hand_r: [2, 44, 16], hand_l: [18, 50, -2], pole_hand_l: [2, 42, -12], ...STAND, hands: { r: 'fist', l: 'open' } },
      orig: 'the fist tapped into the open palm and the head dipped: a martial courtesy, held no longer than a breath' },
    { id: 'settle', ticks: 27, from: 'stance.aggressive', over: { lean: 6, ...OPEN }, orig: 'both hands released to the stance, a smile in the shoulders' },
  ] },
  taunt_close: { dur: 60, phases: [
    { id: 'bounce', ticks: 16, sketch: { family: 'upright', lean: 6, hips: [0, -10, 0], spine: { lean: 4 }, head: { pitch: 0 }, hand_r: [22, 54, 14], hand_l: [20, 54, -10], ...STAND, ...OPEN },
      orig: 'a light bounce on the knees with the open hands up in front' },
    { id: 'tap', ticks: 14, sketch: { family: 'upright', lean: 4, hips: [0, -4, 0], spine: { lean: 2 }, head: { pitch: 8 }, hand_r: [18, 52, 6], pole_hand_r: [2, 44, 16], hand_l: [18, 50, -2], pole_hand_l: [2, 42, -12], ...STAND, hands: { r: 'fist', l: 'open' } },
      orig: 'the fist tapped into the open palm with a dip of the head' },
    { id: 'nod', ticks: 14, sketch: { family: 'upright', lean: 2, hips: [0, -4, 0], spine: { lean: 0 }, head: { pitch: -6 }, hand_r: [16, 46, 16], hand_l: [14, 46, -16], ...STAND, ...OPEN },
      orig: 'then the chin lifted: ready when you are' },
    { id: 'settle', ticks: 16, from: 'stance.aggressive', over: { lean: 6, ...OPEN }, orig: 'into the stance' },
  ] },
};

export const holds = {
  // Blow for Blow's brace in his own way (Legal rule 2: each takes the blow his own way): the open hands up at the chest with the forearms close, the spine upright and tall, giving ground on the heels without folding
  bfb_brace: { sketch: { family: 'upright', lean: -4, hips: [-2, -4, 0], spine: { lean: 0, twist: -6 }, head: { pitch: 4, yaw: 6 }, hand_r: [18, 56, 12], pole_hand_r: [-2, 44, 16], hand_l: [16, 54, -8], pole_hand_l: [-2, 42, -12],
      foot_r: [-12, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN, _legal: ['hands_open_or_claw', 'no_cross_hold'] },
    orig: 'taking a blow: both open hands up close at the chest with the forearms in, the spine tall and upright, giving ground on his heels and standing back up out of it, never folding' },
  // a charged shot fired down into a crater (the buried rival's free blow): the open palm pushed down at him
  blast_down: { sketch: { family: 'upright', lean: 20, hips: [4, -8, 0], spine: { lean: 10, twist: 12 }, head: { pitch: 24 }, hand_r: [34, 32, 10], pole_hand_r: [4, 40, 18], hand_l: [9.6, 49.6, -10.6],
      foot_r: [-12, 2.5, 9], foot_l: [14, 2.5, -8], ...OPEN, _legal: ['hands_open_or_claw', 'not_at_hip'] },
    orig: 'firing down into the crater: the open palm pushed out and down at the rival lying in it, the body leaning over it, the other hand open at his chest' },
};

export const cues = {};
