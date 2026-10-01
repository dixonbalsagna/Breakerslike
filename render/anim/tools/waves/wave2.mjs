// Wave 2: the Anti-hero's entries (docs/combat/pending/wave2-entries.md, entries.antihero.wave2.json): how he gets to the blow. Each entry is a
// sequence of poses (start, travel, arrive; a few have more) played over the entry's time by AnimFighter._entry_layer: a phase with `ticks` holds
// that long, the others share the rest by `w`. `from` derives a phase from an existing pose with `over` overrides; `sketch` is a new one.
// Blades: in flight he is one narrow line led by a shoulder or a forearm guard; turns are banked; the crouch is a coiled line with one hand down.
// `lab` is how the lab moves him for the reel (the real path is the sim's: Encounter, wave3-pingpong.md section 2): d0 the start distance (u),
// shape straight, arc, ground, spiral, rising, none, back or hop. Originality: no franchise pose; each pose has an _orig line.
const OPEN = { hands: { r: 'open', l: 'open' } };
const GUARD_LEAD = { hand_r: [10, 62, 14], pole_hand_r: [10, 4, 8] };   // a forearm guard held up in front of the shoulder, the elbow forward

export const entries = {
  // ---- rush (toward)
  dash: {
    alt: { label: 'the shoulder rolled lower, the guard tucked tight', over: { start: { lean: 40 }, travel: { lean: 70, spine: { lean: -8, twist: 18 }, hand_r: [16, 56, 12], pole_hand_r: [10, 2, 8] } } },
    lab: { d0: 170, shape: 'straight' }, legal: ['not_both_arms_back', 'no_fist_punched_ahead'],
    phases: [
      { id: 'start', ticks: 3, from: 'approach.launch',
        over: { lean: 34, hips: [-2, -8, 0], spine: { lean: 8, twist: 14 }, ...GUARD_LEAD, hand_l: [8, 50, -6], ...OPEN },
        orig: 'the take-off: low, the lead shoulder dropped and its forearm guard up, the other arm folded to the chest' },
      { id: 'travel', sketch: { family: 'airborne_extended', lean: 66, spine: { lean: -10, twist: 18 }, head: { pitch: -20 }, hand_r: [8, 58, 14], pole_hand_r: [10, 2, 10],
          hand_l: [2, 46, -6], foot_r: [-30, 26, 3], foot_l: [-30, 24, -3], ...OPEN },
        orig: 'one narrow blade: the shoulder and its forearm guard lead, the other arm folded to the chest, the legs together behind' },
      { id: 'arrive', ticks: 3, sketch: { family: 'upright', lean: -6, hips: [2, -6, 0], spine: { lean: 4, twist: 10 }, head: { pitch: 4 }, hand_r: [24, 56, 12], hand_l: [18, 54, -8],
          foot_r: [-4, 4, 8], foot_l: [12, 4, -7], ...OPEN },
        orig: 'the arrival: the speed scrubbed off, the open hands already forward where the blow begins' },
    ],
  },
  arc_dive: {
    alt: { label: 'tucked at the top, the knees drawn to the chest', over: { top: { lean: 30, spine: { lean: 20 }, foot_r: [10, 30, 5], foot_l: [6, 28, -5] } } },
    lab: { d0: 170, shape: 'arc', apex: 60 },
    phases: [
      { id: 'start', ticks: 4, sketch: { family: 'airborne_extended', lean: -20, spine: { lean: -16 }, head: { pitch: -14 }, hand_r: [-10, 52, 14], hand_l: [-12, 50, -12],
          foot_r: [16, 38, 6], foot_l: [-8, 20, -6], ...OPEN },
        orig: 'a kick upward off nothing, the back arched and the arms swept behind' },
      { id: 'climb', w: 3, from: 'move.ascend', over: { lean: 30, spine: { lean: 4, twist: 10 }, head: { pitch: -10 }, ...OPEN },
        orig: 'the climb: the body one line pitched up, the arms trailing low' },
      { id: 'top', w: 1, sketch: { family: 'airborne_extended', lean: 20, hips: [0, 4, 0], spine: { lean: 12 }, head: { pitch: 6 }, hand_r: [14, 84, 10], hand_l: [4, 52, -8],
          foot_r: [-14, 34, 5], foot_l: [-18, 30, -5], ...OPEN },
        orig: 'the fold at the top: the body bending over, the striking arm swinging up and over' },
      { id: 'arrive', ticks: 5, sketch: { family: 'airborne_extended', lean: 100, spine: { lean: 10 }, head: { pitch: 24 }, hand_r: [31, 57, 8], pole_hand_r: [-6, 10, 8], hand_l: [14, 40, -8],
          foot_r: [-14, 16, 4], foot_l: [-16, 12, -4], ...OPEN },
        orig: 'coming down head first over the rival, the striking limb already raised, the body a dropped blade' },
    ],
  },
  rising: {
    lab: { d0: 120, shape: 'rising' },
    phases: [
      { id: 'start', ticks: 3, from: 'stance.air', over: { lean: 0, spine: { lean: 0, twist: 0 }, hand_r: [2, 30, 12], hand_l: [2, 30, -10], foot_r: [-2, 10, 5], foot_l: [-4, 6, -5], ...OPEN },
        orig: 'the push off: the body upright, the open hands flat along the thighs' },
      { id: 'travel', sketch: { family: 'airborne_extended', lean: 4, spine: { lean: 0 }, head: { pitch: -8 }, hand_r: [2, 30, 12], hand_l: [2, 30, -10], foot_r: [-4, 8, 4], foot_l: [-6, 6, -4], ...OPEN },
        orig: 'straight up from below: the body one vertical line, the open hands flat along the thighs, the feet together' },
      { id: 'arrive', ticks: 4, sketch: { family: 'upright', lean: 4, hips: [0, -4, 0], spine: { lean: 2, twist: -14 }, head: { pitch: -10 }, hand_r: [12, 36, 12], hand_l: [20, 54, -6],
          foot_r: [-6, 6, 8], foot_l: [4, 4, -7], ...OPEN },
        orig: 'under the rival: the body a vertical line, the striking arm low and loaded, the other hand up' },
    ],
  },
  skid: {
    alt: { label: 'sitting further back, the free leg higher', over: { arrive: { lean: 36, foot_r: [28, 20, 8] }, slide: { lean: 40 } } },
    lab: { d0: 200, shape: 'ground' },
    phases: [
      { id: 'run', w: 7, from: 'move.sprint', over: { family: 'upright', lean: 34, spine: { lean: 10 }, head: { pitch: -10 }, hand_r: [14, 52, 12], hand_l: [-8, 50, -8], foot_r: [-14, 2.5, 8], foot_l: [10, 2.5, -7], ...OPEN },
        orig: 'the run: flat out and low, one arm forward, one back' },
      { id: 'drop', ticks: 4, sketch: { family: 'crouched', lean: 40, hips: [-4, -24, 0], spine: { lean: 14 }, head: { pitch: 12 }, hand_l: [24, 4, -10], hand_r: [6, 46, 10],
          foot_r: [-12, 4, 9], foot_l: [14, 6, -7], ...OPEN },
        orig: 'the drop onto one hip and one hand, the other arm held up and back' },
      { id: 'slide', w: 3, sketch: { family: 'crouched', lean: 46, hips: [-2, -26, 0], spine: { lean: 16 }, head: { pitch: 10 }, hand_l: [22, 3, -10], hand_r: [2, 44, 10],
          foot_r: [-14, 5, 9], foot_l: [10, 4, -7], ...OPEN },
        orig: 'the slide: low on a hip and a hand, the free leg trailing' },
      { id: 'arrive', ticks: 6, sketch: { family: 'crouched', lean: 50, hips: [-2, -26, 0], spine: { lean: 18 }, head: { pitch: 12 }, hand_l: [20, 3, -10], hand_r: [4, 44, 10],
          foot_l: [-6, 3, -8], foot_r: [30, 10, 8], ...OPEN },
        orig: 'braking on the hand and the outside foot, the other leg swung free toward the rival' },
    ],
  },
  spiral: {
    alt: { label: 'a steeper bank, the lead arm trailing', over: { start: { spine: { bend: 22 } }, travel: { spine: { bend: 40 }, hand_r: [-6, 52, 24] } } },
    lab: { d0: 190, shape: 'spiral' },
    phases: [
      { id: 'start', ticks: 4, sketch: { family: 'airborne_extended', lean: 40, hip_twist: -30, spine: { lean: -4, twist: -30, bend: 14 }, head: { pitch: -10, yaw: 20 },
          hand_r: [20, 52, 26], pole_hand_r: [4, 0, 14], hand_l: [-2, 46, -6], foot_r: [-24, 26, 4], foot_l: [-26, 22, -4], ...OPEN },
        orig: 'a banked turn away from the rival, one arm leading the curve' },
      { id: 'travel', sketch: { family: 'airborne_extended', lean: 56, spine: { lean: -6, twist: 14, bend: 26 }, head: { pitch: -16, yaw: 14 }, hand_r: [14, 58, 24],
          pole_hand_r: [6, 0, 14], hand_l: [0, 46, -6], foot_r: [-28, 26, 4], foot_l: [-30, 22, -4], ...OPEN },
        orig: 'banked like a blade on edge: the whole body leaning into the curve, the lead arm out along it' },
      { id: 'arrive', ticks: 6, sketch: { family: 'upright', lean: 12, hip_twist: 20, hips: [2, -4, 0], spine: { lean: 4, twist: 24 }, head: { pitch: 4, yaw: -10 },
          hand_r: [22, 58, 14], hand_l: [16, 52, -8], foot_r: [-4, 4, 9], foot_l: [10, 4, -7], ...OPEN },
        orig: 'arriving from the side: the body swung round to face the rival, the hands open and forward' },
    ],
  },
  coil_spring: {
    lab: { d0: 150, shape: 'ground' }, legal: ['hands_open_or_claw'],
    phases: [
      { id: 'start', ticks: 6, sketch: { family: 'crouched', lean: 54, hips: [-6, -26, 0], spine: { lean: 22 }, head: { pitch: 20 }, hand_l: [20, 3, -10], hand_r: [8, 40, 10],
          foot_r: [-10, 2.5, 9], foot_l: [0, 2.5, -7], ...OPEN },
        orig: 'the deepest crouch: one hand on the ground, the hips above the head, the whole body a coiled line' },
      { id: 'travel', sketch: { family: 'airborne_extended', lean: 78, spine: { lean: -10 }, head: { pitch: -24 }, hand_r: [26, 40, 8], hand_l: [26, 40, -8],
          foot_r: [-31, 19, 5], foot_l: [-31, 18, -5], ...OPEN },
        orig: 'uncoiled flat and low: the body level, the open hands forward, the legs streaming behind' },
      { id: 'arrive', ticks: 3, sketch: { family: 'crouched', lean: 40, hips: [8, -14, 0], spine: { lean: 12 }, head: { pitch: 8 }, hand_r: [30, 46, 10], hand_l: [30, 46, -10],
          foot_r: [-6, 3, 9], foot_l: [14, 3, -7], ...OPEN },
        orig: 'landing low at the rival middle, the open hands forward' },
    ],
  },

  // ---- stand (neutral)
  step_in: {
    lab: { d0: 70, shape: 'none', advance: 10 },
    phases: [
      { id: 'start', ticks: 2, from: 'stance.aggressive', over: { ...OPEN }, orig: 'the stance, the hands open where the strike starts' },
      { id: 'travel', from: 'move.step_f', over: { head: { pitch: 0 }, hand_r: [26, 58, 12], hand_l: [22, 56, -8], ...OPEN }, orig: 'one short flat step, the head level, the hands already forward' },
      { id: 'arrive', ticks: 2, from: 'stance.aggressive', over: { hips: [6, -4, 0], hand_r: [26, 58, 12], hand_l: [22, 56, -8], ...OPEN }, orig: 'the step landed, the weight forward, the hands ready' },
    ],
  },
  pivot: {
    lab: { d0: 70, shape: 'none' },
    phases: [
      { id: 'start', ticks: 2, from: 'stance.aggressive', over: { ...OPEN }, orig: 'the stance' },
      { id: 'travel', sketch: { family: 'upright', lean: 6, hip_twist: 44, hips: [2, -4, 0], spine: { lean: 4, twist: -14 }, head: { pitch: 4, yaw: 10 },
          hand_r: [10, 58, 14], hand_l: [22, 56, -8], foot_l: [12, 2.5, -7], foot_r: [-2, 8, 12], ...OPEN },
        orig: 'the pivot: the weight on the lead foot, the rear hip swinging round, the shoulders a beat behind the hips' },
      { id: 'arrive', ticks: 2, sketch: { family: 'upright', lean: 8, hip_twist: 16, hips: [2, -4, 0], spine: { lean: 4, twist: 8 }, head: { pitch: 4, yaw: 6 },
          hand_r: [14, 58, 13], hand_l: [24, 56, -6], foot_r: [-8, 2.5, 9], foot_l: [12, 2.5, -7], ...OPEN },
        orig: 'out of the turn: the hips squared, the shoulders catching up, the hands ready' },
    ],
  },
  plant_coil: {
    alt: { label: 'the eyes level on the rival, the spine straighter', over: { travel: { lean: 14, spine: { lean: 10 }, head: { pitch: 6 } }, arrive: { spine: { lean: 12 }, head: { pitch: 6 } } } },
    lab: { d0: 70, shape: 'none' }, legal: ['hands_open_or_claw'],
    phases: [
      { id: 'start', ticks: 2, from: 'stance.aggressive', over: { ...OPEN }, orig: 'the stance' },
      { id: 'travel', w: 1, sketch: { family: 'crouched', lean: 24, hips: [0, -16, 0], spine: { lean: 20 }, head: { pitch: -16 }, hand_r: [20, 50, 12], hand_l: [17, 10, -8],
          foot_r: [-10, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN },
        orig: 'the drop into the crouch on the spot: the spine curled, the eyes up, one hand braced on the ground, the other open and forward' },
      { id: 'arrive', ticks: 3, sketch: { family: 'crouched', lean: 28, hips: [0, -18, 0], spine: { lean: 22 }, head: { pitch: -18 }, hand_r: [16, 44, 12], hand_l: [17, 8, -8],
          foot_r: [-10, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN },
        orig: 'held coiled: lower by a hand, the loaded arm drawn back a little' },
    ],
  },
  lane_step: {
    lab: { d0: 70, shape: 'none' },
    phases: [
      { id: 'start', ticks: 2, from: 'stance.aggressive', over: { ...OPEN }, orig: 'the stance' },
      { id: 'travel', sketch: { family: 'upright', lean: 6, hip_twist: 36, hips: [2, -4, 6], spine: { lean: 4, twist: -10 }, head: { pitch: 4, yaw: 16 },
          hand_r: [14, 58, 20], hand_l: [20, 56, 4], foot_r: [4, 2.5, 24], foot_l: [8, 2.5, 2], ...OPEN },
        orig: 'a sidestep toward the camera: the body turned a quarter, the near foot reaching across and out' },
      { id: 'arrive', ticks: 2, sketch: { family: 'upright', lean: 8, hip_twist: 14, hips: [2, -4, 8], spine: { lean: 4, twist: 4 }, head: { pitch: 4, yaw: 8 },
          hand_r: [16, 58, 22], hand_l: [24, 56, 6], foot_r: [-4, 2.5, 22], foot_l: [10, 2.5, 6], ...OPEN },
        orig: 'set on the new line, the shoulders square again and the hands ready' },
    ],
  },
  rooted: {
    lab: { d0: 60, shape: 'none' }, legal: ['hands_open_or_claw', 'no_cross_hold'],
    phases: [
      { id: 'start', from: 'stance.aggressive', over: { lean: 6, hips: [0, -6, 0], hand_r: [10, 46, 13], hand_l: [14, 46, -6], ...OPEN },
        orig: 'he does not move his feet: low and settled, the hands low and open while he waits' },
    ],
  },

  // ---- retreat (away)
  backstep_counter: {
    lab: { d0: 60, shape: 'back' },
    phases: [
      { id: 'start', ticks: 2, from: 'stance.aggressive', over: { ...OPEN }, orig: 'the stance' },
      { id: 'travel', from: 'move.step_b', over: { hand_r: [14, 58, 12], hand_l: [18, 56, -8], ...OPEN }, orig: 'one step back with the weight on the rear leg, the open hands up' },
      { id: 'arrive', ticks: 3, from: 'stance.aggressive', over: { lean: 14, hips: [6, -5, 0], hand_r: [22, 58, 12], hand_l: [26, 56, -8], ...OPEN },
        orig: 'the weight shifted forward again: ready to step straight back in as the rival follows' },
    ],
  },
  fade: {
    lab: { d0: 60, shape: 'none' }, legal: ['lean_max'],
    phases: [
      { id: 'start', ticks: 2, from: 'stance.aggressive', over: { ...OPEN }, orig: 'the stance' },
      { id: 'travel', sketch: { family: 'upright', lean: -22, hips: [-2, -3, 0], spine: { lean: -6, twist: -8 }, head: { pitch: -4, yaw: 8 }, hand_r: [8, 58, 13], hand_l: [12, 56, -6],
          foot_r: [-9, 2.5, 8], foot_l: [11, 2.5, -7], ...OPEN },
        orig: 'the lean away: the head and chest slipping back out of range from the hips, the feet planted' },
      { id: 'arrive', ticks: 2, from: 'stance.aggressive', over: { lean: 14, hips: [5, -5, 0], hand_r: [20, 58, 12], hand_l: [24, 56, -8], ...OPEN }, orig: 'coming forward again with the counter' },
    ],
  },
  hop_back: {
    lab: { d0: 60, shape: 'hop' },
    phases: [
      { id: 'start', ticks: 2, from: 'stance.aggressive', over: { ...OPEN }, orig: 'the stance, the knees bending' },
      { id: 'travel', sketch: { family: 'airborne_neutral', lean: 10, hips: [-2, 8, 0], spine: { lean: 6 }, head: { pitch: 4 }, hand_r: [18, 56, 14], hand_l: [20, 54, -8],
          foot_r: [8, 30, 8], foot_l: [4, 26, -7], ...OPEN },
        orig: 'the hop: both knees drawn up, the body leaning in toward the rival' },
      { id: 'arrive', ticks: 3, sketch: { family: 'crouched', lean: 16, hips: [4, -12, 0], spine: { lean: 8 }, head: { pitch: 4 }, hand_r: [22, 54, 12], hand_l: [24, 52, -8],
          foot_r: [-8, 2.5, 9], foot_l: [10, 2.5, -7], ...OPEN },
        orig: 'landing in a low crouch, ready to spring back in' },
    ],
  },
  drop_back: {
    lab: { d0: 60, shape: 'back' }, legal: ['hands_open_or_claw'],
    phases: [
      { id: 'start', ticks: 2, from: 'stance.aggressive', over: { ...OPEN }, orig: 'the stance' },
      { id: 'travel', sketch: { family: 'crouched', lean: 10, hips: [-8, -18, 0], spine: { lean: 14 }, head: { pitch: -6 }, hand_r: [22, 50, 12], hand_l: [16, 14, -8],
          foot_r: [-18, 2.5, 9], foot_l: [2, 2.5, -7], ...OPEN },
        orig: 'giving ground downward: back and down into the crouch, under the line of the blow, one hand reaching for the ground' },
      { id: 'arrive', ticks: 3, sketch: { family: 'crouched', lean: 14, hips: [-6, -20, 0], spine: { lean: 16 }, head: { pitch: -8 }, hand_r: [18, 46, 12], hand_l: [16, 10, -8],
          foot_r: [-16, 2.5, 9], foot_l: [4, 2.5, -7], ...OPEN },
        orig: 'held low under the blow, loaded to come up through the rival middle' },
    ],
  },
};
