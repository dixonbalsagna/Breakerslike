// The rival's three new strikes of the launch update (docs/combat/launch-pair-movesets.md section 2.1; docs/combat/alchemist-recipes.md section 2.4; Legal RL-063 to RL-065):
// the body ram, redesigned, and Blow for Blow's body hook and rib shot. Parked (--waves). Range and ticks are borrowed from the nearest wave 1 slot until Combat's rows land.
//   body_ram   a short step and the plated shoulder into the chest, the chin tucked behind it, the forearm guards close: shoulder first, not the back of the shoulder
//   body_hook  a heavy hook dug in along the ribs: the elbow at a right angle, the hip turned through, the other forearm plate across his own chest (a blow, not a held cross)
//   rib_shot   a straight heavy blow to the chest from a low shoulder: arm, spine and rear leg one line
const OPEN = { hands: { r: 'open', l: 'open' } };
const NEW = {
  body_ram: { like: 'body_ram', look: 'Redesigned: a short step and the plated shoulder driven into the chest, the chin tucked behind it, the forearm guards close.' },
  body_hook: { like: 'haymaker', limb: 'hand', target: 'gut', weight: 'heavy', look: 'A heavy hook dug in along the ribs, the elbow a right angle, the hip turned through, the other forearm plate across his own chest.' },
  rib_shot: { like: 'spear_hand', limb: 'hand', target: 'chest', weight: 'heavy', look: 'A straight heavy blow to the chest from a low shoulder: arm, spine and rear leg one line.' },
};
export function rows(wave1, launchPair) {
  const own = Object.fromEntries((launchPair?.rival?.strikes || []).map(r => [r.id.replace('strike.', ''), r]));
  const by = Object.fromEntries(wave1.map(r => [r.id.replace('strike.', ''), r]));
  return Object.entries(NEW).map(([n, o]) => {
    const b = by[o.like];
    if (own[n]) return { ...b, ...own[n], range: { ...b.range, ...own[n].range, lunge: b.range.lunge, clear: b.range.clear } };   // Combat's own row
    return { ...b, id: 'strike.' + n, ...(o.limb ? { limb: o.limb } : {}), ...(o.target ? { target: o.target } : {}), ...(o.weight ? { weight: o.weight } : {}), look: o.look,
      ...(n === 'body_ram' ? {} : { _estimate: 'range and ticks borrowed from strike.' + o.like }) };
  });
}

export const strikes = {
  body_ram: { kind: 'shoulder', legal: ['no_cross_hold'],
    contact: { family: 'upright_lunge', lean: 20, hips: [6, -6, 0], spine: { lean: 6, twist: -16 }, head: { pitch: 4, yaw: 8 }, hand_r: [20, 52, 6], pole_hand_r: [-6, 4, 10], hand_l: [18, 50, -6], pole_hand_l: [-6, 2, -10],
      foot_r: [-6, 2.5, 9], foot_l: [24, 2.5, -7], ...OPEN },
    orig: 'a short step and the plated shoulder driven into the chest, the chin tucked behind it, the forearm guards close against the ribs: shoulder first' },
  body_hook: { kind: 'hand',
    contact: { family: 'upright_lunge', lean: 24, hips: [18, -8, 0], spine: { lean: 12, twist: 44, bend: -8 }, head: { pitch: 12 }, hand_r: [48, 46, 14], pole_hand_r: [0, -6, 16], hand_l: [15.6, 53.6, -4],
      foot_r: [-6, 2.5, 9], foot_l: [24, 2.5, -7], ...OPEN },
    orig: 'a heavy hook dug in along the ribs, the elbow a right angle and the hip turned through, the other forearm plate across his own chest' },
  rib_shot: { kind: 'hand',
    contact: { family: 'upright_lunge', lean: 30, hips: [14, -12, 0], spine: { lean: 10, twist: 20 }, head: { pitch: 2 }, hand_r: [56, 52, 8], hand_l: [10.7, 45, -9],
      foot_r: [-10, 2.5, 9], foot_l: [26, 2.5, -7], ...OPEN },
    orig: 'a straight heavy blow to the chest from a low shoulder: the arm, the spine and the rear leg one long line' },
};
