// The rival's (the Anti-hero's) gaps found by the launch-pair coverage audit (docs/animation/launch-pair-coverage.md): the free blast presses (a bolt, a fan of darts, a lobbed
// slab, a charged shot, a shot down into a crater), the charged brace of wave 6 (which rival1 had as the channel only), the energy shove, the Regalia release, his four far taunts and
// his close taunt, and the Drop the Act cinematic. Parked (--waves): nothing plays them until he lands. Legal: RL-060 to RL-065 and the rules of wave 6 (docs/combat/pending/wave6-energy.md).
//   hands: the pinch (thumb and forefinger lightly together, never a pointing finger), the blade hand (flat, edge on, never a pointed finger), the open palm (never at the hip);
//   no both-palms pumping, no open-mouth scream, no sphere or glow between the palms, nothing held crossed, the arms-open stance of On the Chin never appears outside it.
// Taunts never beckon, no crossed arms, no scream, no aura. The far taunts are played over the flight (data mixes them at about 70%), so they are upright sketches like ag.taunt.
const OPEN = { hands: { r: 'open', l: 'open' } };
const WIDE = { foot_r: [-12, 2.5, 9], foot_l: [14, 2.5, -8] };

export const sequences = {
  // ---- the free blast presses (the energy press with RB held; the sim's cues blast_windup, blast_charge, blast_full, blast_cancel)
  bolt: { dur: 12, legal: ['not_at_hip'], phases: [
    { id: 'wind', ticks: 4, sketch: { family: 'upright', lean: 6, hips: [2, -4, 0], spine: { lean: 2, twist: 12 }, head: { pitch: 2, yaw: 4 }, hand_r: [28, 60, 12], pole_hand_r: [2, 54, 20], hand_l: [14, 52, -8], ...WIDE, hands: { r: 'relaxed', l: 'open' } },
      orig: 'a bolt readied: the throwing hand brought up to the chest with the thumb and forefinger lightly together, the other hand open beside it' },
    { id: 'fire', ticks: 2, sketch: { family: 'upright', lean: 8, hips: [2, -4, 0], spine: { lean: 0, twist: 16 }, head: { pitch: 0, yaw: 4 }, hand_r: [36, 62, 12], pole_hand_r: [4, 56, 20], hand_l: [14, 52, -8], ...WIDE, hands: { r: 'relaxed', l: 'open' } },
      orig: 'the dart leaving as the fingers part, the wrist flicked and the arm stopped short' },
    { id: 'settle', ticks: 6, from: 'stance.aggressive', over: { lean: 8, ...OPEN }, orig: 'back to the stance, the hand open again' },
  ] },
  // a fan of darts from one sweep of the arm: the edge of the blade hand drawn across in a low-to-high arc, never both palms pumping
  volley_fan: { dur: 14, legal: ['hands_open_or_claw', 'not_at_hip'], phases: [
    { id: 'set', ticks: 4, sketch: { family: 'upright', lean: 6, hips: [2, -4, 0], spine: { lean: 2, twist: -14 }, head: { pitch: 2, yaw: 4 }, hand_r: [28, 44, 12], pole_hand_r: [2, 38, 22], hand_l: [14, 52, -8], ...WIDE, ...OPEN },
      orig: 'the blade hand drawn back low across the body, the other hand open at his chest' },
    { id: 'sweep', ticks: 4, sketch: { family: 'upright', lean: 8, hips: [2, -4, 0], spine: { lean: 2, twist: 20 }, head: { pitch: 0, yaw: 4 }, hand_r: [41.6, 69.2, 8], pole_hand_r: [4, 56, 18], hand_l: [14, 52, -8], ...WIDE, ...OPEN },
      orig: 'the sweep: the arm carried up and across in one arc with the edge of the hand leading, the darts running off it in a flat fan' },
    { id: 'settle', ticks: 6, from: 'stance.aggressive', over: { lean: 8, ...OPEN }, orig: 'back to the stance' },
  ] },
  // a hexagonal slab lobbed on a high arc with one hand
  lob: { dur: 16, legal: ['hands_open_or_claw', 'not_at_hip', 'no_held_raise'], phases: [
    { id: 'wind', ticks: 5, sketch: { family: 'upright', lean: 10, hips: [0, -8, 0], spine: { lean: 6, twist: -10 }, head: { pitch: 6 }, hand_r: [16, 22, 14], pole_hand_r: [-6, 24, 20], hand_l: [14, 54, -8], ...WIDE, ...OPEN },
      orig: 'the throwing hand swung back low with the knees bent, the other hand open at his chest' },
    { id: 'throw', ticks: 4, sketch: { family: 'upright', lean: 4, hips: [4, -4, 0], spine: { lean: -2, twist: 18 }, head: { pitch: -8 }, hand_r: [38, 66, 10], pole_hand_r: [4, 48, 18], hand_l: [12, 52, -8], ...WIDE, ...OPEN },
      orig: 'the lob: the arm swung up and forward from low, the flat hand open under the slab as it leaves, the eyes following the arc; one hand, never both raised overhead' },
    { id: 'settle', ticks: 7, from: 'stance.aggressive', over: { lean: 6, head: { pitch: -4 }, ...OPEN }, orig: 'back to the stance, watching it come down' },
  ] },
  // the charged brace of wave 6: side-on, the firing arm drawn back at shoulder height (never to the hip), the plates stacking along the forearm (VFX), then the arm straight
  charged_brace: { dur: 40, legal: ['hands_open_or_claw', 'not_at_hip', 'not_both_arms_back'], phases: [
    { id: 'charge', w: 4, sketch: { family: 'upright', lean: 6, hip_twist: 40, hips: [0, -8, 0], spine: { lean: 4, twist: -26 }, head: { pitch: 2, yaw: 24 }, hand_r: [4, 64, 18], pole_hand_r: [-12, 62, 22], hand_l: [4, 60, 6],
        foot_r: [-14, 2.5, 10], foot_l: [14, 2.5, -9], ...OPEN },
      orig: 'the charge: side-on to the rival with the firing arm drawn back at shoulder height, the other hand open on the firing arm\'s shoulder, the stance wide' },
    { id: 'release', ticks: 8, sketch: { family: 'upright', lean: 12, hip_twist: 20, hips: [4, -8, 0], spine: { lean: 4, twist: 14 }, head: { pitch: 0, yaw: 8 }, hand_r: [47.5, 63.2, 9.7], pole_hand_r: [6, 56, 18], hand_l: [10, 52, -10],
        foot_r: [-14, 2.5, 10], foot_l: [16, 2.5, -9], ...OPEN },
      orig: 'the release: the arm straight at the rival with the blade hand flat, the plates gone, the other hand open at his chest' },
  ] },
};

export const holds = {
  // a charged shot fired down into a crater (the buried rival's free blow): the arm down at him, the body leaning over it
  blast_down: { sketch: { family: 'upright', lean: 20, hips: [4, -8, 0], spine: { lean: 10, twist: 12 }, head: { pitch: 24 }, hand_r: [34, 32, 10], pole_hand_r: [4, 40, 18], hand_l: [9.6, 49.6, -10.6],
      foot_r: [-12, 2.5, 9], foot_l: [14, 2.5, -8], ...OPEN, _legal: ['hands_open_or_claw', 'not_at_hip'] },
    orig: 'firing down into the crater: the arm out and down at the rival lying in it, the open hand flat, the body leaning over it, the other hand open at his chest' },
  // the energy shove (the context button at close range with the energy family held): a flat palm at chest height on a straight arm, side-on
  energy_shove: { sketch: { family: 'upright_lunge', lean: 12, hip_twist: 36, hips: [10, -4, 0], spine: { lean: 4, twist: 22 }, head: { pitch: 2, yaw: 6 }, hand_r: [55.7, 61.6, 7.6], pole_hand_r: [-2, 0, 8], hand_l: [8, 56, -14],
      foot_r: [-6, 2.5, 9], foot_l: [20, 2.5, -7], ...OPEN, _legal: ['hands_open_or_claw', 'not_at_hip'] },
    orig: 'the shove: a flat palm at chest height on a straight arm, the body side-on behind it, the other hand open out behind him for balance' },
  // the Regalia release: the shards that circle his shoulders fire on their own and he does not raise a hand
  crown_release: { sketch: { family: 'upright', lean: 0, hips: [0, -2, 0], spine: { lean: 0 }, head: { pitch: -8 }, hand_r: [18, 34, 18], hand_l: [16, 34, -18], foot_r: [-8, 2.5, 8], foot_l: [8, 2.5, -7], ...OPEN, _legal: ['hands_open_or_claw'] },
    orig: 'standing upright with the chin up and the hands open and low while the shards leave their ring round his shoulders one after another; he raises nothing' },
};

// ---- the far taunts (45 ticks, played over the flight; no beckoning) and the close taunt (60 ticks, he can be hit)
const SETTLE = { from: 'stance.aggressive', over: { lean: 6, ...OPEN } };
sequences.taunt_head_tilt = { dur: 45, legal: ['hands_open_or_claw'], phases: [
  { id: 'tilt', ticks: 14, sketch: { family: 'upright', lean: 2, hips: [0, -2, 0], spine: { lean: 0, twist: 6 }, head: { pitch: -4, yaw: 10, roll: 18 }, hand_r: [14, 40, 18], hand_l: [12, 40, -18], foot_r: [-8, 2.5, 8], foot_l: [8, 2.5, -7], ...OPEN },
    orig: 'the head slowly tilted to one side with the chin lifted and the open hands low at his sides: "that is it?"' },
  { id: 'hold', ticks: 18, sketch: { family: 'upright', lean: 0, hips: [0, -2, 0], spine: { lean: 0, twist: 8 }, head: { pitch: -6, yaw: 12, roll: 22 }, hand_r: [14, 40, 18], hand_l: [12, 40, -18], foot_r: [-8, 2.5, 8], foot_l: [8, 2.5, -7], ...OPEN },
    orig: 'held a beat, unhurried' },
  { id: 'settle', ticks: 13, ...SETTLE, orig: 'dropping back to the stance' },
] };
sequences.taunt_back_turned = { dur: 45, legal: ['hands_open_or_claw'], phases: [
  { id: 'turn', ticks: 16, sketch: { family: 'upright', lean: 0, hip_twist: 70, hips: [0, -2, 0], spine: { lean: 0, twist: -50 }, head: { pitch: 0, yaw: -10 }, hand_r: [12, 38, 18], hand_l: [10, 40, -16], foot_r: [-8, 2.5, 8], foot_l: [8, 2.5, -7], ...OPEN },
    orig: 'turning his back on the rival, the shoulders and hips round and the head only half turned, the hands open at his sides: dismissal' },
  { id: 'hold', ticks: 14, sketch: { family: 'upright', lean: 0, hip_twist: 78, hips: [0, -2, 0], spine: { lean: 0, twist: -56 }, head: { pitch: 0, yaw: -14 }, hand_r: [12, 38, 18], hand_l: [10, 40, -16], foot_r: [-8, 2.5, 8], foot_l: [8, 2.5, -7], ...OPEN },
    orig: 'held with his back to him' },
  { id: 'settle', ticks: 15, ...SETTLE, orig: 'turning back to the stance' },
] };
sequences.taunt_dust_plate = { dur: 45, legal: ['hands_open_or_claw'], phases: [
  { id: 'lift', ticks: 12, sketch: { family: 'upright', lean: 2, hips: [0, -2, 0], spine: { lean: 2, twist: 10 }, head: { pitch: 8, yaw: 6 }, hand_r: [14, 48, 26], pole_hand_r: [-4, 42, 28], hand_l: [14, 50, 14], foot_r: [-8, 2.5, 8], foot_l: [8, 2.5, -7], ...OPEN },
    orig: 'one arm held out to the side with the plate turned up, the other hand brought to it' },
  { id: 'brush', ticks: 20, sketch: { family: 'upright', lean: 2, hips: [0, -2, 0], spine: { lean: 2, twist: 10 }, head: { pitch: 10, yaw: 6 }, hand_r: [14, 48, 26], pole_hand_r: [-4, 42, 28], hand_l: [18.6, 47, 14.1], foot_r: [-8, 2.5, 8], foot_l: [8, 2.5, -7], ...OPEN },
    orig: 'brushing the dust off the forearm plate with the flat of the other hand, eyes down on the plate and not on the rival' },
  { id: 'settle', ticks: 13, ...SETTLE, orig: 'dropping the arm back to the stance' },
] };
sequences.taunt_stillness = { dur: 45, legal: ['hands_open_or_claw'], phases: [
  { id: 'still', ticks: 45, sketch: { family: 'upright', lean: 0, hips: [0, -2, 0], spine: { lean: 0 }, head: { pitch: -2 }, hand_r: [12, 38, 16], hand_l: [10, 38, -16], foot_r: [-8, 2.5, 8], foot_l: [8, 2.5, -7], ...OPEN },
    orig: 'doing nothing at all: upright and perfectly still with the hands open at his sides and the chin level, which is the insult' },
] };
sequences.taunt_close = { dur: 60, legal: ['hands_open_or_claw'], phases: [
  { id: 'dust', ticks: 24, sketch: { family: 'upright', lean: 2, hips: [0, -2, 0], spine: { lean: 2, twist: 10 }, head: { pitch: 8, yaw: 6 }, hand_r: [14, 48, 26], pole_hand_r: [-4, 42, 28], hand_l: [18.6, 47, 14.1], foot_r: [-8, 2.5, 8], foot_l: [8, 2.5, -7], ...OPEN },
    orig: 'brushing the dust off his forearm plate with the rival in front of him, unhurried' },
  { id: 'tilt', ticks: 24, sketch: { family: 'upright', lean: 0, hips: [0, -2, 0], spine: { lean: 0, twist: 6 }, head: { pitch: -6, yaw: 10, roll: 20 }, hand_r: [14, 40, 18], hand_l: [12, 40, -18], foot_r: [-8, 2.5, 8], foot_l: [8, 2.5, -7], ...OPEN },
    orig: 'then the head slowly tilted, the chin lifted, the hands open and low' },
  { id: 'settle', ticks: 12, ...SETTLE, orig: 'back to the stance' },
] };
// Drop the Act (spec-wounds.md section 3): the facade cracks in a 1.5 s cinematic, respected like a transformation: stiff and proud, then loose; no scream, no aura, no rubble
sequences.drop_the_act = { dur: 90, legal: ['hands_open_or_claw'], phases: [
  { id: 'stiff', ticks: 30, sketch: { family: 'upright', lean: 0, hips: [0, -2, 0], spine: { lean: 0 }, head: { pitch: -4 }, hand_r: [10, 38, 14], hand_l: [8, 38, -14], foot_r: [-8, 2.5, 8], foot_l: [8, 2.5, -7], ...OPEN },
    orig: 'the proud front: upright and rigid, the chin lifted, the hands open and still at his sides' },
  { id: 'crack', ticks: 30, sketch: { family: 'upright', lean: 6, hips: [0, -6, 0], spine: { lean: 6, twist: -8 }, head: { pitch: 10, roll: 8 }, hand_r: [16, 32, 20], hand_l: [14, 34, -20], foot_r: [-10, 2.5, 9], foot_l: [10, 2.5, -8], ...OPEN },
    orig: 'the front cracking: the shoulders dropping and the head rolling forward, the arms hanging loose, the weight coming down into the legs' },
  { id: 'loose', ticks: 30, sketch: { family: 'upright', lean: 8, hips: [2, -8, 0], spine: { lean: 6, twist: 10 }, head: { pitch: 4, yaw: 8 }, hand_r: [18, 46, 20], hand_l: [16, 48, -18], foot_r: [-12, 2.5, 10], foot_l: [14, 2.5, -9], ...OPEN },
    orig: 'unrestrained: a wide loose stance with the hands up and open, the head level, rolling the shoulders, ready' },
] };

export const cues = {};
