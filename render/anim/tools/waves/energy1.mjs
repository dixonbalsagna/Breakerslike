// Orb's energy direction as parked poses (docs/design/agency-pass.md section 15; Legal: docs/legal/agency-pass-screen.md, RL-060 to RL-062). Nothing fires these
// cues yet: the wave is loaded only with --waves (the tools), never in a live match. Three moments:
//   swat  (15.2) a shot knocked wild: the plated forearm does it. No open palm held out, no casual backhand flick, no line shouted (RL-060).
//   mine  (15.5) laying a mine, the energy held plus the context button: one hand sets a hexagonal plate down. No two hands cupped, no sphere forming between palms,
//         no hands drawn back to one hip and thrust forward, nothing raised overhead (RL-061 and the two-hand channel rule); not a crouch with the fists at his sides.
//   spray (15.4) rapid bolts in a cone: one lead arm, a short kick for every bolt. No both-palms-pumping, no open-mouth scream (RL-060); no pointing finger.
// Each pose has an _orig line; the legal lists are checked by pose_lint.
const OPEN = { hands: { r: 'open', l: 'open' } };

export const sequences = {
  // the swat: the near forearm, held out low with the elbow at the ribs, is swung up through the shot's line about the elbow: a short, hard chop with the hips turning
  // behind it, not a flick of the hand. The fist stays closed and the wrist locked, so it is the forearm plate that meets the shot.
  swat: { dur: 16, legal: ['no_fist_punched_ahead', 'no_cross_hold'], phases: [
    { id: 'set', ticks: 5, sketch: { family: 'upright', lean: 4, hips: [-2, -6, 0], spine: { lean: 2, twist: 16 }, head: { pitch: 4, yaw: 8 }, hand_r: [24, 46, 14], pole_hand_r: [0, 40, 24],
        hand_l: [10, 52, -8], foot_r: [-12, 2.5, 9], foot_l: [10, 2.5, -7], hands: { r: 'fist', l: 'relaxed' } },
      orig: 'sighting the shot: the near forearm held out low in front of him, the elbow tucked at the ribs, the plate turned up, the other hand back at the chest' },
    { id: 'chop', ticks: 4, sketch: { family: 'upright', lean: -2, hips: [-4, -4, 0], spine: { lean: -2, twist: -22 }, head: { pitch: 2, yaw: 10 }, hand_r: [14, 67, 16], pole_hand_r: [2, 46, 24],
        hand_l: [4, 46, -12], foot_r: [-14, 2.5, 9], foot_l: [12, 2.5, -7], hands: { r: 'fist', l: 'relaxed' } },
      orig: 'the swat: the elbow a hinge at the ribs and the forearm swung up through the line of the shot in one chop, the hips turning with it, the fist closed, the plate meeting the shot and sending it wild' },
    { id: 'recover', ticks: 7, from: 'stance.aggressive', over: { lean: 4, hips: [-2, -4, 0], spine: { twist: -6 }, head: { yaw: 6 } },
      orig: 'dropping back to guard, the arm coming down, the eyes following the shot' },
  ] },
  // laying a mine: he pays and sets it down. One hand lowers a hexagonal plate to where he is (hanging in the air or on the ground), the knees giving a little; the
  // other hand is held out open for balance. The hands are far apart (one low, one high), never cupped, and never drawn to a hip.
  mine: { dur: 22, legal: ['wrists_apart', 'not_at_hip', 'no_held_raise'], phases: [
    { id: 'reach', ticks: 7, sketch: { family: 'upright', lean: 10, hips: [2, -10, 0], spine: { lean: 8, twist: 12 }, head: { pitch: 14, yaw: 6 }, hand_r: [30, 32, 16], pole_hand_r: [4, 34, 24],
        hand_l: [10, 60, -16], foot_r: [-10, 2.5, 9], foot_l: [10, 2.5, -7], hands: { r: 'open', l: 'open' } },
      orig: 'bringing the near hand out and down in front of him, the eyes on it, the knees giving a little; the other hand open at shoulder height for balance' },
    { id: 'lay', ticks: 8, sketch: { family: 'upright', lean: 16, hips: [4, -12, 0], spine: { lean: 12, twist: 14 }, head: { pitch: 20, yaw: 6 }, hand_r: [26, 32, 14], pole_hand_r: [4, 30, 24],
        hand_l: [6, 54, -18], foot_r: [-12, 2.5, 9], foot_l: [10, 2.5, -7], hands: { r: 'open', l: 'open' } },
      orig: 'the hand low and a little ahead, the palm down, setting the plate where it hangs; the head bowed over it' },
    { id: 'rise', ticks: 7, from: 'stance.aggressive', over: { lean: 8, hips: [0, -6, 0], head: { pitch: 8 }, ...OPEN },
      orig: 'standing up out of it, the hand coming back, a glance at the plate' },
  ] },
  // one bolt of a spray: the lead arm kicks up and back with the shot and settles. The sim fires one every 6 ticks at the fastest, so one beat is 6 ticks and a
  // run of bolts replays it. The arm's aim wanders inside the cone a little between the bolts (the spread is the sim's); the body stays square.
  spray: { dur: 6, legal: ['no_fist_punched_ahead'], phases: [
    { id: 'kick', ticks: 2, sketch: { family: 'upright', lean: 2, hips: [-6, -10, 0], spine: { lean: -10, twist: 14 }, head: { pitch: -4, yaw: 6 }, hand_r: [24, 70.5, 11.7], pole_hand_r: [8, 62, 22],
        hand_l: [2, 52, -22], foot_r: [-14, 2.5, 10], foot_l: [12, 2.5, -9], hands: { r: 'claw', l: 'open' } },
      orig: 'the bolt leaving: the lead arm kicked up a little and the shoulder rocking back with it, the rear hand thrown out wide for balance' },
    { id: 'settle', ticks: 4, sketch: { family: 'upright', lean: 8, hips: [-2, -10, 0], spine: { lean: 4, twist: 16 }, head: { pitch: 4, yaw: 6 }, hand_r: [32, 62, 12], pole_hand_r: [10, 56, 22],
        hand_l: [2, 52, -22], foot_r: [-14, 2.5, 10], foot_l: [12, 2.5, -9], hands: { r: 'claw', l: 'open' } },
      orig: 'back on the line: the lead arm level and out, the loose clawed hand aimed along it, the feet planted wide, the head down along the arm' },
  ] },
};

export const holds = {};   // (the spray's firing stance is the settle pose of the spray beat: held between bolts and under the beats)

export const cues = {};
