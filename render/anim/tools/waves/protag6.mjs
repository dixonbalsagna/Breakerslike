// The Protagonist's body hook (the coverage audit, docs/animation/launch-pair-coverage.md): Blow for Blow's ribs place (docs/combat/alchemist-recipes.md section 2.2) has the rival's body
// hook only, and each fighter takes and gives the blows his own way (Legal rule 2). His is a round hook with the open hand dug in along the ribs, the hip turned through. Parked (--waves).
// Range and ticks are borrowed from the haymaker's row until Combat's land.
const OPEN = { hands: { r: 'open', l: 'open' } };
export function rows(wave1) {
  const b = wave1.find(r => r.id === 'strike.haymaker');
  return [{ ...b, id: 'strike.body_hook', target: 'gut', weight: 'heavy', look: 'A round hook with the open hand dug in along the ribs, the elbow bent and the hip turned through.', _estimate: 'range and ticks borrowed from strike.haymaker' }];
}
export const strikes = {
  body_hook: { kind: 'hand', legal: ['hands_open_or_claw'],
    contact: { family: 'upright_lunge', lean: 22, hips: [16, -6, 0], spine: { lean: 10, twist: 50, bend: -8 }, head: { pitch: 8 }, hand_r: [46, 46, 16], pole_hand_r: [0, -6, 18], hand_l: [20, 56, -4],
      foot_r: [-6, 2.5, 9], foot_l: [22, 2.5, -7], ...OPEN },
    orig: 'a round hook with the open hand dug in along the ribs, the elbow bent and the hip turned through, the other open hand up at his cheek' },
};
