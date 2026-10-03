// The Protagonist's entries (docs/combat/launch-pair-movesets.md section 3.1; Legal RL-063 to RL-065): how he gets to the blow. Wave 2's 15 slots are the base:
//   redo   six slots whose silhouette changes to read as his (below): authored here
//   reuse  the other nine: the rival's phases with his profile applied (wave_gen.mjs, `reuse`)
//   own    two entries only he has (Combat's list): the air roll and the cartwheel step. Both read as circles.
// The flights keep the rival's poses (a narrow line with a shoulder or arm leading is the dash rule, Legal's, and it reads the same on him); the six that change are the
// ground and crouch entries, where the rival coils, drops and plants like a blade and he bounces, stays taller and keeps his hands up and open:
//   coil_spring, plant_coil, skid, drop_back, rooted, hop_back
// Legal: the air roll is a tumble that opens into the blow, the limbs extended through it, at most one revolution, never a tight spinning ball; hands open or flat, never
// clenched at the sides in a crouch; no scream, no ground-crack; rooted: hands low or at the chest and open, no beckoning, no crossed arms.
const OPEN = { hands: { r: 'open', l: 'open' } };

const REDO = ['coil_spring', 'plant_coil', 'skid', 'drop_back', 'rooted', 'hop_back'];
const OWN = {
  air_roll: { like: 'arc_dive', direction: 'rush', ground: 'ok', when: 'closing a gap; a roll over the guard', favours: ['haymaker', 'overhand', 'roundhouse', 'rising_palm', 'axe_kick', 'hammer_fist'], ticks: { travel: 'c', start: 4, arrive: 4 }, look: 'A forward roll in the air that opens into the blow: the limbs extended through the roll, one revolution at most.' },
  cartwheel_step: { like: 'step_in', direction: 'stand', ground: 'ok', when: 'in reach; a step that turns into a circle', favours: ['hook', 'snap_round', 'ridge_hand', 'crescent_kick', 'hook_kick', 'spinning_heel'], ticks: { travel: 18, start: 2, arrive: 4 }, look: 'A cartwheel step on the ground: the hands to the floor, the legs over, up into the stance.' },
};
export function rows(wave2) {
  const by = Object.fromEntries(wave2.map(r => [r.id.replace('entry.', ''), r]));
  const out = REDO.map(n => ({ ...by[n], look: 'His version (taller, bouncier, hands up): ' + by[n].look }));
  for (const [n, o] of Object.entries(OWN)) {
    const b = by[o.like];
    out.push({ ...b, id: 'entry.' + n, direction: o.direction, ground: o.ground, when: o.when, favours: o.favours, look: o.look, ticks: o.ticks || b.ticks, _estimate: 'sim borrowed from entry.' + o.like + (o.ticks ? '; the ticks are an ask from Animation (a roll or a cartwheel does not read in the six ticks of a step)' : '; ticks borrowed too'), _legal: 'a tumble that opens into the blow, the limbs extended, one revolution at most' });
  }
  return out;
}
export const reuse = 'auto';

// the air roll's poses: a diving roll about the hips, the head leading, the arms ahead of it and the legs behind it, both stretched (never a tight ball). th is the pitch
// in degrees (0 upright, 90 head forward and level, 180 upside down, 270 head back); the limbs are placed along the body's own axis from the pelvis
const PX = 0, PY = 36;
function roll(th, arm = 38, leg = 34, spread = 12) {
  const a = th * Math.PI / 180, dx = Math.sin(a), dy = Math.cos(a), r1 = v => Math.round(v * 2) / 2;
  const at = (k, z) => [r1(PX + dx * k), r1(PY + dy * k), z];
  return { family: 'tumble', lean: th, hips: [0, 0, 0], spine: { lean: 0 }, head: { pitch: 0 },
    hand_r: at(arm, 12), hand_l: at(arm - 4, -12), foot_r: at(-leg, 4), foot_l: at(-leg - 2, -4), ...OPEN };
}

export const entries = {
  coil_spring: { lab: { d0: 170, shape: 'straight' }, legal: ['hands_open_or_claw'],
    phases: [
      { id: 'start', ticks: 6, sketch: { family: 'upright', lean: 30, hips: [-4, -14, 0], spine: { lean: 14 }, head: { pitch: 4 }, hand_r: [28, 44, 12], pole_hand_r: [4, 38, 22], hand_l: [26, 38, -10],
          foot_r: [-8, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN },
        orig: 'a bounce: the knees bent, the weight low and forward, both open hands out ahead of the chest, ready to spring' },
      { id: 'travel', sketch: { family: 'airborne_extended', lean: 72, spine: { lean: -8 }, head: { pitch: -18 }, hand_r: [26, 42, 8], hand_l: [14, 45, -10], foot_r: [-30, 22, 4], foot_l: [-30, 20, -4], ...OPEN },
        orig: 'sprung into a long flat line, the lead arm out ahead with the palm open and the other folded in, the legs together behind' },
      { id: 'arrive', ticks: 3, sketch: { family: 'upright_lunge', lean: 26, hips: [10, -6, 0], spine: { lean: 8 }, head: { pitch: 2 }, hand_r: [30, 52, 10], hand_l: [24.5, 48, -10],
          foot_r: [-4, 2.5, 9], foot_l: [18, 2.5, -7], ...OPEN },
        orig: 'landed in a lunge, the hands open and up in front of him' },
    ] },
  plant_coil: { lab: { d0: 70, shape: 'none' }, legal: ['hands_open_or_claw'],
    phases: [
      { id: 'start', ticks: 2, from: 'stance.aggressive', over: { ...OPEN }, orig: 'the stance, the hands open' },
      { id: 'travel', w: 1, sketch: { family: 'upright', lean: 16, hips: [0, -10, 0], spine: { lean: 10 }, head: { pitch: 0 }, hand_r: [24, 50, 12], hand_l: [22, 34, -8],
          foot_r: [-9, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN },
        orig: 'a spring of the knees without a step: one hand up at the face, one low, the weight forward' },
      { id: 'arrive', ticks: 3, sketch: { family: 'upright', lean: 18, hips: [2, -12, 0], spine: { lean: 12 }, head: { pitch: 0 }, hand_r: [28, 52, 12], hand_l: [22, 30, -8],
          foot_r: [-9, 2.5, 9], foot_l: [8, 2.5, -7], ...OPEN },
        orig: 'sprung and set: the hands open, one high and one low, the head up' },
    ] },
  skid: { lab: { d0: 200, shape: 'ground' },
    phases: [
      { id: 'run', w: 7, sketch: { family: 'upright', lean: 26, spine: { lean: 8 }, head: { pitch: -4 }, hand_r: [18, 56, 12], hand_l: [-1.2, 53, -14.8], foot_r: [-14, 2.5, 8], foot_l: [10, 2.5, -7], ...OPEN },
        orig: 'a quick run, the arms pumping loosely and open' },
      { id: 'drop', ticks: 4, sketch: { family: 'crouched', lean: 32, hips: [-4, -16, 0], spine: { lean: 12 }, head: { pitch: 6 }, hand_l: [24, 20, -10], hand_r: [10, 52, 10], foot_r: [-12, 4, 9], foot_l: [14, 6, -7], ...OPEN },
        orig: 'dropping into the slide on the heels, one hand reaching down for balance' },
      { id: 'slide', w: 3, sketch: { family: 'crouched', lean: 36, hips: [-2, -18, 0], spine: { lean: 14 }, head: { pitch: 6 }, hand_l: [22, 16, -10], hand_r: [8, 50, 10], foot_r: [-14, 5, 9], foot_l: [10, 4, -7], ...OPEN },
        orig: 'sliding on the heels, the weight held a little higher than the blade of the rival' },
      { id: 'arrive', ticks: 6, sketch: { family: 'crouched', lean: 38, hips: [-2, -18, 0], spine: { lean: 16 }, head: { pitch: 6 }, hand_l: [20, 16, -10], hand_r: [10, 50, 10], foot_l: [-6, 3, -8], foot_r: [30, 10, 8], ...OPEN },
        orig: 'the slide ending in a wide low stance, one hand down, one up' },
    ] },
  drop_back: { lab: { d0: 60, shape: 'back' }, legal: ['hands_open_or_claw'],
    phases: [
      { id: 'start', ticks: 2, from: 'stance.aggressive', over: { ...OPEN }, orig: 'the stance, the hands open' },
      { id: 'travel', sketch: { family: 'upright', lean: 6, hips: [-8, -14, 0], spine: { lean: 8 }, head: { pitch: 0 }, hand_r: [24, 60, 12], hand_l: [22, 58, -8], foot_r: [-16, 2.5, 9], foot_l: [2, 2.5, -7], ...OPEN },
        orig: 'dropping back a step with the knees bent and the hands kept up and open, the eyes on him' },
      { id: 'arrive', ticks: 3, sketch: { family: 'upright', lean: 8, hips: [-6, -14, 0], spine: { lean: 10 }, head: { pitch: 0 }, hand_r: [22, 58, 12], hand_l: [20, 56, -8], foot_r: [-14, 2.5, 9], foot_l: [4, 2.5, -7], ...OPEN },
        orig: 'set again a step back, still springy, the hands up' },
    ] },
  rooted: { lab: { d0: 60, shape: 'none' }, legal: ['hands_open_or_claw', 'no_cross_hold'],
    phases: [
      { id: 'start', sketch: { family: 'upright', lean: 4, hips: [0, -6, 0], spine: { lean: 4, twist: -8 }, head: { pitch: 0, yaw: 6 }, hand_r: [18, 52, 13], hand_l: [24, 54, -6], foot_r: [-9, 2.5, 8], foot_l: [11, 2.5, -7], ...OPEN },
        orig: 'he does not move his feet: a springy stand with the open hands up at the chest and the blow coming out of it' },
    ] },
  hop_back: { lab: { d0: 60, shape: 'hop' },
    phases: [
      { id: 'start', ticks: 2, from: 'stance.aggressive', over: { ...OPEN }, orig: 'the stance, the hands open' },
      { id: 'travel', sketch: { family: 'airborne_neutral', lean: 8, hips: [-2, 12, 0], spine: { lean: 4 }, head: { pitch: 2 }, hand_r: [20, 58, 14], hand_l: [22, 56, -8], foot_r: [10, 34, 8], foot_l: [6, 30, -7], ...OPEN },
        orig: 'a light hop back with the knees up and the hands kept open and forward' },
      { id: 'arrive', ticks: 3, sketch: { family: 'upright', lean: 8, hips: [2, -8, 0], spine: { lean: 6 }, head: { pitch: 2 }, hand_r: [22, 56, 12], hand_l: [24, 54, -8], foot_r: [-8, 2.5, 9], foot_l: [10, 2.5, -7], ...OPEN },
        orig: 'landed springy, the hands up and open, the eyes on him' },
    ] },

  // ---- the two of his own
  air_roll: { lab: { d0: 170, shape: 'straight' }, legal: ['no_fist_punched_ahead'],
    phases: [
      { id: 'start', ticks: 4, sketch: { family: 'airborne_extended', lean: 20, spine: { lean: -10 }, head: { pitch: -8 }, hand_r: [12, 74, 16], hand_l: [12, 70, -16], foot_r: [-6, 20, 6], foot_l: [-8, 16, -6], ...OPEN },
        orig: 'springing off into the roll: the body arched and the arms flung up and open, the legs trailing' },
      { id: 'over', w: 1, sketch: roll(110),
        orig: 'going over: the body one stretched line pitched past level, the arms reaching ahead of the head and the legs stretched out behind, never a ball' },
      { id: 'inverted', w: 1, sketch: roll(200),
        orig: 'upside down at the top of the roll, still one long line: the arms stretched toward the ground, the legs up' },
      { id: 'under', w: 1, sketch: roll(290),
        orig: 'coming round: the head back and the arms and legs still long, the line a quarter turn from where it began' },
      { id: 'open', ticks: 4, sketch: { family: 'airborne_extended', lean: 66, spine: { lean: -6 }, head: { pitch: -14 }, hand_r: [26, 56, 10], pole_hand_r: [-4, 8, 10], hand_l: [16, 44, -8], foot_r: [-28, 24, 4], foot_l: [-30, 22, -4], ...OPEN },
        orig: 'out of the roll into a long flat line, one arm cocked and the other open ahead: the blow comes next' },
    ] },
  cartwheel_step: { lab: { d0: 70, shape: 'none', advance: 18 }, legal: ['hands_open_or_claw'],
    phases: [
      { id: 'start', ticks: 2, from: 'stance.aggressive', over: { ...OPEN }, orig: 'the stance, the hands open' },
      { id: 'reach', ticks: 3, sketch: { family: 'crouched', lean: 60, hips: [10, -22, 0], spine: { lean: 22 }, head: { pitch: 14 }, hand_r: [30, 4, 10], hand_l: [22, 6, -10], foot_r: [-8, 2.5, 9], foot_l: [6, 2.5, -7], ...OPEN },
        orig: 'the weight thrown forward and both open hands reaching for the ground' },
      { id: 'over', w: 1, sketch: { family: 'tumble', lean: 180, hips: [0, 0, 0], spine: { lean: 0 }, head: { pitch: 0 }, hand_r: [26, 4, 10], hand_l: [24, 4, -10], foot_r: [0, 71, 13], foot_l: [0, 71, -13], ...OPEN },
        orig: 'over on the hands: the body upside down and straight, the legs high and apart, a circle through the air' },
      { id: 'land', ticks: 4, sketch: { family: 'upright_lunge', lean: 16, hips: [8, -8, 0], spine: { lean: 6 }, head: { pitch: 2 }, hand_r: [26, 52, 10], hand_l: [22, 54, -10], foot_r: [-4, 2.5, 9], foot_l: [16, 2.5, -7], ...OPEN },
        orig: 'landed in the stance on the far side of the circle, the hands up and open' },
    ] },
};
